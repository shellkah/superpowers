# Autopilot First-Run Changes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: the handover prompt names which skill runs this plan, superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the autopilot main session's context load (slim reports, durable run records, delegated cross-part check, writer-written handovers, a run-state file) and add the feedback doc's visibility, pausing, refusal, recovery, multi-PR and dispatch changes.

**Architecture:** All changes are Markdown skill and prompt edits. The executor and part-writer prompts gain new report fields and a shared `[RUN_DIR]`; a new cross-part-check prompt moves step 4.3 into a subagent; `autopilot/SKILL.md` gains the run folder, resume rule, pre-flight, pausing, notification and multi-PR rules. Comprehension tests in `tests/claude-code/` pin the key behaviours.

**Tech Stack:** Markdown skills; bash tests driving `claude -p` through `run_claude_fork` (`tests/claude-code/test-helpers.sh`).

**Spec:** `docs/superpowers/specs/2026-10-19-autopilot-first-run-changes-design.md`

## Global Constraints

- Fork-only changes on `shellkah/superpowers`; no upstream eval evidence required.
- Write in the files' existing voice: "your human partner", short imperative sentences, Claude Code specifics in parentheses (`SendMessage in Claude Code`).
- writing-plans' normal (non-autopilot) mode is unchanged: the main session still runs the cross-part check and writes every handover prompt there.
- brainstorming is not touched.
- No change adds a review stop, except the opt-in checkpoint mode.
- Run folder: `.superpowers/autopilot/<feature>/` in the main checkout, with a self-ignoring `.gitignore` (`*`) at `.superpowers/autopilot/`.
- Ruling tags are exactly `[review]` and `[routine]`; the third executor status is exactly `PAUSED`.
- Each test question is answered "using exactly this structure", matching the existing tests' format.

## Review Focus

1. **Ruling loss at workspace deletion.** executing-plans deletes the workspace when the final review is clean; the executor prompt must order "write `[RUN_DIR]/part-N-record.md`" before that, and also before a BLOCKED or PAUSED report. Pinned by Task 1's test ("Record written before workspace deleted").
2. **Left-over reading in step 4.** Any surviving line telling the main session to run the cross-part check itself, write the handover prompt, or update the index from writer reports defeats the design. Pinned by Task 3's test ("Main session reads part file").
3. **Normal-mode regression in writing-plans.** Pinned by Task 3's test ("Cross-part check outside autopilot").
4. **PAUSED treated as a blocker.** The report format, autopilot's report handling (step 4.6) and the Pausing section must agree. Pinned by Task 6's test.
5. **Harnesses without a push channel or background notifications.** Each new mechanism says what to do without it (status line only; foreground dispatch). Pinned by Task 6's test ("Without push channel").

---

### Task 1: Executor prompt: tags, record, slim report, PAUSED, refusals

**Files:**
- Modify: `skills/autopilot/executor-prompt.md`
- Test: `tests/claude-code/test-autopilot.sh`

**Interfaces:**
- Produces: placeholder `[RUN_DIR]`; record file `[RUN_DIR]/part-N-record.md` (with several builds, `build-B-part-N-record.md`) holding all rulings with tags and cost if wrong, all deferred minors, and an `Interfaces produced:` block in the index's Cross-Part Interfaces format with `file:line`; report fields `Status: DONE | BLOCKED | PAUSED`, `Record: <path>`, `Rulings I made:` (`[review]` only) then `Routine rulings: <count>`, `Deferred minors: <count>`.

- [ ] **Step 1: Write the failing test.** Append to `test-autopilot.sh`, before the final echo:

```bash
echo "Test 5: Executor rulings, record, pause, refusals..."
output=$(run_claude_fork "Read the superpowers:autopilot skill's executor prompt. Answer using exactly this structure:
Routine rulings in report: <in full, or count only>
Record written before workspace deleted: <yes or no>
Status on pause: <word>
Idle waiting after pause: <yes or no>
Re-run a command an implementer was refused: <yes or no>
Follow hook redirect from cat to Read: <yes or no>
Follow hook redirect to a tool that runs something: <yes or blocked>" "$T")
assert_contains "$output" "Routine rulings in report:.*count" "Routine rulings are counted, not listed" || exit 1
assert_contains "$output" "Record written before workspace deleted:[^a-z]*yes\b" "Record survives workspace deletion" || exit 1
assert_contains "$output" "Status on pause:.*PAUSED" "Pause has its own status" || exit 1
assert_contains "$output" "Idle waiting after pause:[^a-z]*no\b" "No idling on pause" || exit 1
assert_contains "$output" "Re-run a command an implementer was refused:[^a-z]*no\b" "No permission laundering" || exit 1
assert_contains "$output" "Follow hook redirect from cat to Read:[^a-z]*yes\b" "Read-only redirect allowed" || exit 1
assert_contains "$output" "Follow hook redirect to a tool that runs something:.*blocked" "Running redirect is BLOCKED" || exit 1
echo ""
```

- [ ] **Step 2: Run it and confirm Test 5 fails.** Run: `bash tests/claude-code/test-autopilot.sh`. Expected: Tests 1–4 PASS, Test 5 FAIL on the first assertion.

- [ ] **Step 3: Edit `executor-prompt.md`** per spec §2.1, §1.2 (executor bullet), §3.1 (the quoted refusal paragraph, verbatim, beside the BLOCKED rules, plus "a hook's instruction that conflicts with autopilot's worktree and ledger is not followed"), §3.2 (restart only the services named in the run notes). Add `[RUN_DIR]` and `[RUN_NOTES]` (the spec's Run notes section, pasted) to the filled placeholders. Tag every ruling when ledgered. Order the record write explicitly before workspace deletion and before any BLOCKED/PAUSED report; later reports from the same part overwrite it. Update the report block to the Produces fields above.

- [ ] **Step 4: Run the test.** Run: `bash tests/claude-code/test-autopilot.sh`. Expected: all tests PASS.

- [ ] **Step 5: Commit.** `git add skills/autopilot/executor-prompt.md tests/claude-code/test-autopilot.sh && git commit -m "feat(autopilot): slim executor reports with a durable record, pause and refusal rules"`

### Task 2: Part-writer prompt: plan content, Length, handover under autopilot

**Files:**
- Modify: `skills/writing-plans/part-writer-prompt.md`
- Test: `tests/claude-code/test-writing-plans-split.sh`

**Interfaces:**
- Produces: placeholders `[HANDOVER_PATH]` and `[UNDER_AUTOPILOT]` (`yes`/`no`); report lines `Length: <lines> lines, for spec §… (<lines> lines)` and, under autopilot, `Handover: appended, mode <skill>`.

- [ ] **Step 1: Write the failing test.** Append Test 4 to `test-writing-plans-split.sh`:

```bash
echo "Test 4: Part writer content, length, handover..."
output=$(run_claude_fork "Read the superpowers:writing-plans part-writer prompt. Answer using exactly this structure:
Whole helper script in the plan: <yes or no>
Line budget to hit: <yes or no>
Reports length against spec share: <yes or no>
Writes handover prompt under autopilot: <yes or no>
Writes handover prompt outside autopilot: <yes or no>" "$T")
assert_contains "$output" "Whole helper script in the plan:[^a-z]*no\b" "Bodies become signatures" || exit 1
assert_contains "$output" "Line budget to hit:[^a-z]*no\b" "No line budget" || exit 1
assert_contains "$output" "Reports length against spec share:[^a-z]*yes\b" "Length line" || exit 1
assert_contains "$output" "Writes handover prompt under autopilot:[^a-z]*yes\b" "Writer writes handover under autopilot" || exit 1
assert_contains "$output" "Writes handover prompt outside autopilot:[^a-z]*no\b" "Main session writes it otherwise" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Run: `bash tests/claude-code/test-writing-plans-split.sh`. Expected: Test 4 FAIL.

- [ ] **Step 3: Edit `part-writer-prompt.md`** per spec §2.2 (content rule stated in the prompt with the "unless the code is itself the hard part" exception; no budget) and §4.4b (under autopilot, append the handover prompt following writing-plans' Execution Handoff to `[HANDOVER_PATH]`, creating it with that layout for part 1; outside autopilot keep "do not write handover prompts"). Add the Produces report lines.

- [ ] **Step 4: Run the test.** Expected: all PASS.

- [ ] **Step 5: Commit.** `git commit -am "feat(writing-plans): part writers keep plans lean and write handovers under autopilot"` (add the test file).

### Task 3: Cross-part check prompt and writing-plans' autopilot paragraphs

**Files:**
- Create: `skills/writing-plans/cross-part-check-prompt.md`
- Modify: `skills/writing-plans/SKILL.md` (the "Cross-part check", "Writer questions", index-update sentence under "The index", and "Under autopilot" paragraphs only)
- Test: `tests/claude-code/test-writing-plans-split.sh`

**Interfaces:**
- Consumes: Task 1's record file and `Interfaces produced:` block; Task 2's `Length:` line.
- Produces: prompt with placeholders `[SPEC_PATH]`, `[INDEX_PATH]`, `[PART_PATH]`, `[PREVIOUS_RECORD_PATH]` (`none` for part 1), `[WORKTREE_PATH]`, `[WRITER_REPORT]`, `[RUN_DIR]`; model note "a mid-tier model (Sonnet in Claude Code) by default", in the other prompts' style; report block `Fixed: <count>` / `Unsettled: <none, or one line each with a recommendation>` / `Length: <ok, or far over: ratio>`; appends one tagged line per fix to `[RUN_DIR]/main-record.md`.

- [ ] **Step 1: Write the failing test.** Append Test 5:

```bash
echo "Test 5: Cross-part check under autopilot..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill and its prompts. Answer using exactly this structure:
Cross-part check under autopilot run by: <main session or subagent>
Cross-part check outside autopilot run by: <main session or subagent>
Who updates the index from executor interfaces under autopilot: <main session or checker>
Main session reads part file under autopilot: <yes or no>" "$T")
assert_contains "$output" "Cross-part check under autopilot run by:.*subagent" "Check delegated under autopilot" || exit 1
assert_contains "$output" "Cross-part check outside autopilot run by:.*main session" "Normal mode unchanged" || exit 1
assert_contains "$output" "Who updates the index from executor interfaces under autopilot:.*checker" "Checker updates index" || exit 1
assert_contains "$output" "Main session reads part file under autopilot:[^a-z]*no\b" "Main session stays out of part files" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Expected: Test 5 FAIL.

- [ ] **Step 3: Write `cross-part-check-prompt.md`** per spec §4.3b (the three duties in order; spot-check each `file:line`; fix small mismatches in index or part; flag far-over length with a plain threshold of 3× the part's spec share, stated in the prompt; never paste part content into the report). Follow `part-writer-prompt.md`'s layout: intro, model note, fenced prompt, exact report block.

- [ ] **Step 4: Edit `writing-plans/SKILL.md`**: under autopilot, a fresh subagent runs the cross-part check with `cross-part-check-prompt.md`, and it (not the main session) updates the index from writer differences and executor interfaces; under autopilot the part writer appends each handover prompt. Normal-mode sentences stay.

- [ ] **Step 5: Run the tests.** Run: `bash tests/claude-code/test-writing-plans-split.sh && bash tests/claude-code/test-writing-plans-handover.sh`. Expected: all PASS.

- [ ] **Step 6: Commit.** `git commit -m "feat(writing-plans): delegate the cross-part check to a subagent under autopilot"` (add the new prompt and test).

### Task 4: Autopilot run folder, state file, resuming

**Files:**
- Modify: `skills/autopilot/SKILL.md`
- Test: `tests/claude-code/test-autopilot.sh`

**Interfaces:**
- Produces: `[RUN_DIR]` = absolute `.superpowers/autopilot/<feature>/` in the main checkout; `state.md` (first line `# Autopilot run — spec: <spec path>`), `main-record.md`; a "Resuming After Compaction" section.

- [ ] **Step 1: Write the failing test.** Append Test 6:

```bash
echo "Test 6: Run folder and resuming..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Run folder: <path pattern>
After compaction, read first: <file name>
Re-read executor reports to rebuild context: <yes or no>
Existing state.md naming a different spec: <reuse or replace>" "$T")
assert_contains "$output" "Run folder:.*\.superpowers/autopilot/" "Run folder location" || exit 1
assert_contains "$output" "After compaction, read first:.*state\.md" "Resume from state.md" || exit 1
assert_contains "$output" "Re-read executor reports to rebuild context:[^a-z]*no\b" "No re-reading reports" || exit 1
assert_contains "$output" "Existing state.md naming a different spec:.*replace" "Stale folder replaced" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Expected: Test 6 FAIL.

- [ ] **Step 3: Edit `autopilot/SKILL.md`** per spec §0: create the folder and self-ignoring `.gitignore` after the spec is committed (step 2), the stale rule, `state.md` contents (pointers and one-liners, rewritten at every step boundary, never appended), `main-record.md` (main session's own calls, tagged), pass `[RUN_DIR]` to every writer, checker and executor, and the resuming section (read `state.md`, trust it and `git log` over recollection).

- [ ] **Step 4: Run the test.** Expected: all PASS.

- [ ] **Step 5: Commit.** `git commit -m "feat(autopilot): run folder with a state file for cheap resumes"` (add both files).

### Task 5: Autopilot step 2 questions, run notes, pre-flight

**Files:**
- Modify: `skills/autopilot/SKILL.md`
- Test: `tests/claude-code/test-autopilot.sh`

**Interfaces:**
- Consumes: Task 4's `state.md`.
- Produces: the spec's `## Run notes` section (services and restart consent, checkpoint mode, PR plan, pre-flight outcomes); `[RUN_NOTES]` filled into each executor prompt.

- [ ] **Step 1: Write the failing test.** Append Test 7:

```bash
echo "Test 7: Up-front questions and pre-flight..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Asks whether it may restart named services: <yes or no>
Pre-flight runs: <before the index or after the index>
Probe the existing test suite: <yes or no>
Probe creating a scratch database: <yes or no>
A probe refusal before part 1: <blocker or ruling>" "$T")
assert_contains "$output" "Asks whether it may restart named services:[^a-z]*yes\b" "Restart consent asked" || exit 1
assert_contains "$output" "Pre-flight runs:.*after the index" "Pre-flight after step 3" || exit 1
assert_contains "$output" "Probe the existing test suite:[^a-z]*yes\b" "Harmless probes run" || exit 1
assert_contains "$output" "Probe creating a scratch database:[^a-z]*no\b" "Lasting effects asked, not probed" || exit 1
assert_contains "$output" "A probe refusal before part 1:.*blocker" "Refusal is a blocker" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Expected: Test 7 FAIL.

- [ ] **Step 3: Edit `autopilot/SKILL.md`** per spec §5 (fixed questions added to the builder check's "theirs" message, skipping ones the request answers; answers into a `## Run notes` section of the spec, mirrored in `state.md`), §3.2, §1.2 (checkpoint question), §4.2 (several-PRs question), and §3.1's pre-flight after step 3 (probe only no-lasting-effect commands, record pass/refused only, one blocker message for refusals and unprobed commands, no retry by another route). Add the pre-flight refusal to the Blockers list.

- [ ] **Step 4: Run the test.** Expected: all PASS.

- [ ] **Step 5: Commit.** `git commit -m "feat(autopilot): ask run consents up front and probe commands before part 1"` (add both files).

### Task 6: Autopilot step 4, pausing, notifications, dispatch rule

**Files:**
- Modify: `skills/autopilot/SKILL.md`
- Test: `tests/claude-code/test-autopilot.sh`

**Interfaces:**
- Consumes: Task 1's report fields, Task 2's handover line, Task 3's checker prompt and report.
- Produces: a "Pausing" section; step 4 sub-steps rewritten (write part → read writer report → dispatch checker → check handover appended → execute → read report with DONE/BLOCKED/PAUSED).

- [ ] **Step 1: Write the failing test.** Append Test 8:

```bash
echo "Test 8: Step 4, pausing, notifications, dispatch..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Executor reports PAUSED: <blocker or not a blocker>
Push a blocker's question when the harness has a push channel: <yes or no>
Without push channel: <what is sent>
Main session writes the handover prompt: <yes or no>
Harness only runs subagents in background: <poll, or end turn and resume on notification>
Between-parts work kept only in a temp directory: <yes or no>
Stop to show a published design: <yes or no>" "$T")
assert_contains "$output" "Executor reports PAUSED:.*not a blocker" "Pause is not a blocker" || exit 1
assert_contains "$output" "Push a blocker's question when the harness has a push channel:[^a-z]*yes\b" "Blockers notify" || exit 1
assert_contains "$output" "Without push channel:.*status line" "Falls back to the status line" || exit 1
assert_contains "$output" "Main session writes the handover prompt:[^a-z]*no\b" "Writer writes handover" || exit 1
assert_contains "$output" "Harness only runs subagents in background:.*end turn" "Resume on notification" || exit 1
assert_contains "$output" "Between-parts work kept only in a temp directory:[^a-z]*no\b" "Durable main-session work" || exit 1
assert_contains "$output" "Stop to show a published design:[^a-z]*no\b" "Publishing does not stop" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Expected: Test 8 FAIL.

- [ ] **Step 3: Edit `autopilot/SKILL.md`** per spec §1.1, §1.2 (Pausing section and checkpoint stop after each part's status line), §3.3, §3.4, §4.1, §4.3 (dispatch paragraph and its Red Flag; Fallback keeps foreground), §4.3b and §4.4b (step 4 sub-steps per Produces; main session passes writer report lines to the checker and never reads part files, the spec or code in step 4). The executor-dispatch sub-step fills `[RUN_DIR]` and `[RUN_NOTES]`. Rewrite `state.md` at each sub-step boundary.

- [ ] **Step 4: Run the test.** Expected: all PASS.

- [ ] **Step 5: Commit.** `git commit -m "feat(autopilot): pausing, notifications and a lean step 4"` (add both files).

### Task 7: Autopilot summary, PR description, several PRs, Red Flags

**Files:**
- Modify: `skills/autopilot/SKILL.md`, `README.md:355` only if its one-line description no longer fits
- Test: `tests/claude-code/test-autopilot.sh`

**Interfaces:**
- Consumes: Task 1's records, Task 4's `main-record.md`.

- [ ] **Step 1: Write the failing test.** Append Test 9:

```bash
echo "Test 9: Summary, PR description, several PRs..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Summary leads with: <which rulings>
Routine rulings in summary: <in full, or count>
PR description built by reading records into context: <yes or no>
Several PRs, default after first PR: <stop or continue>
Later build branches from: <base branch or previous build's branch>" "$T")
assert_contains "$output" "Summary leads with:.*review" "Summary leads with [review] rulings" || exit 1
assert_contains "$output" "Routine rulings in summary:.*count" "Routine rulings counted" || exit 1
assert_contains "$output" "PR description built by reading records into context:[^a-z]*no\b" "Records joined on the shell" || exit 1
assert_contains "$output" "Several PRs, default after first PR:.*stop" "Default stop after first PR" || exit 1
assert_contains "$output" "Later build branches from:.*previous" "Stacked builds" || exit 1
echo ""
```

- [ ] **Step 2: Run it.** Expected: Test 9 FAIL.

- [ ] **Step 3: Edit `autopilot/SKILL.md`** per spec §2.1 (step 6 order: `[review]` rulings, "Not yet seen by you", then today's items with counts; step 5 PR body = summary + `main-record.md` + part records joined on the shell into a `<details>` section, `gh pr create --body-file`), §4.2 (steps 3–6 loop per build; next index after previous PR opens, against its branch; stacked branches and PR targets; re-split on "continue" if acceptance changed the earlier build), and the Red Flags rows (the "ruling was small" row reworded; new rows for re-reading reports after compaction and re-running a refused command).

- [ ] **Step 4: Run the full suite.** Run: `bash tests/claude-code/test-autopilot.sh && bash tests/claude-code/test-writing-plans-split.sh && bash tests/claude-code/test-writing-plans-handover.sh`. Expected: all PASS.

- [ ] **Step 5: Read-through check** (spec, Verification): every placeholder autopilot fills (`[RUN_DIR]`, `[RUN_NOTES]`, `[HANDOVER_PATH]`, `[UNDER_AUTOPILOT]`, the checker's) is defined in its prompt; the executor report fields match what step 4.6 and step 6 read. Fix any mismatch.

- [ ] **Step 6: Commit.** `git commit -m "feat(autopilot): lean summary, full rulings in the PR, several-PR runs"` (add changed files).

### Task 8: Handover prompts as Markdown, not a text block

Not from the spec: your human partner asked for it on 2026-10-19 after seeing the handover file. The target format is `docs/superpowers/plans/2026-10-19-autopilot-first-run-changes.handover.md` as it now stands.

**Files:**
- Modify: `skills/writing-plans/SKILL.md` (Execution Handoff steps 2–4), `skills/writing-plans/part-writer-prompt.md` (the handover it appends under autopilot, from Task 2)
- Test: `tests/claude-code/test-writing-plans-handover.sh`

- [ ] **Step 1: Write the failing test.** Append a test asking: `Handover prompt in the handover file wrapped in a code block: <yes or no>` and `Paths in the prompt formatted as: <inline code or plain>`; assert `no` and `inline code`.

- [ ] **Step 2: Run it.** Run: `bash tests/claude-code/test-writing-plans-handover.sh`. Expected: the new test FAILS.

- [ ] **Step 3: Edit Execution Handoff.** Step 2's layout shows each part's prompt as Markdown under its heading: the `Execute part N of M…` sentence with paths in inline code, then bullets `**Skill:**`, `**Why this mode:**`, `**Branch:**` (split plans), `**Workspace:**` or `**Previous part:**`, `**Not the last part:**` — carrying the same content step 3 lists today. Step 3's content list stays; only its rendering changes. Step 4's closing message shows the part 1 prompt the same way (no fenced `text` block). Autopilot's `[HANDOVER_PROMPT]` filling (Task 6) still works on this format: check its wording.

- [ ] **Step 4: Run the tests.** Run: `bash tests/claude-code/test-writing-plans-handover.sh && bash tests/claude-code/test-writing-plans-split.sh`. Expected: all PASS.

- [ ] **Step 5: Commit.** `git commit -m "feat(writing-plans): write handover prompts as Markdown"` (add changed files).
