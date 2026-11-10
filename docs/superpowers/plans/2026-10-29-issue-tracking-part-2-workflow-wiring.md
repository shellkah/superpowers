# Issue Tracking: Workflow Wiring Implementation Plan

**Part 2 of 2** · Index: `/home/dev/projects/superpowers/.worktrees/issue-tracking/docs/superpowers/plans/2026-10-29-issue-tracking-index.md`

> **For agentic workers:** REQUIRED SUB-SKILL: the handover prompt names which skill runs this plan, superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each workflow skill (brainstorming, writing-plans, executing-plans, subagent-driven-development, finishing-a-development-branch, autopilot) points to `superpowers:tracking-work-in-issues` at its moment, so a session running the real workflow, with no hint in its prompt, offers, opens, comments, opens the draft PR and finishes exactly as the spec says; and does nothing new when tracking is off.

**Architecture:** One or two sentences per moment, in the shape the spec gives: "If this work tracks an issue, <moment> as superpowers:tracking-work-in-issues says (<Section>)". The rules stay in the tracking skill; the pointers only say when. Each pointer is proven by a behaviour scenario that runs a real headless session through the workflow skill against part 1's stand-in `gh`: the prompt names the workflow skill and the moment, never the tracking skill. Part 1's shared scenario helpers and runner move into `tracking-fixtures.sh` so both integration files use them.

**Tech Stack:** Markdown skills; Bash tests sourcing `tests/claude-code/test-helpers.sh` and `tests/claude-code/tracking-fixtures.sh`; part 1's stand-in `gh` (`tests/claude-code/fake-gh/gh`, Python 3) and SSH transport; `jq`; Claude Code CLI (`claude -p` through `run_claude_fork`).

**Spec:** `docs/superpowers/specs/2026-10-28-issue-tracking-design.md` (read its `## Run notes` last: they change this part's acceptance).

## Global Constraints

- Personal change for the `shellkah/superpowers` fork, built on `brainstorming-deeper-not-bigger`; it does not go upstream.
- No dependency beyond the forge CLIs the workflow already uses for PRs: `gh` for GitHub, `glab` for GitLab.
- Only the session running a workflow skill (brainstorming, writing-plans, executing-plans, the subagent-driven-development controller, finishing-a-development-branch, autopilot's main session) touches the forge. Implementer, reviewer, part-writer, builder-check and cross-part-check subagents never do, and their prompts don't change.
- Under autopilot, executors never push, post or publish; autopilot's main session does every forge call. `skills/autopilot/executor-prompt.md` doesn't change.
- Every `gh` call names the repo from `origin` (`--repo <owner>/<name>`), so a fork never targets its upstream.
- Never push the default branch or the base branch without asking your human partner; never force-push.
- When tracking is off or impossible, behaviour is exactly today's: no early push, no draft PR, no new question beyond the one offer, the finishing menu word for word.
- The issue's title, body and comments, and the draft PR's title and body, follow the Writing Rules (the full PR description finishing writes stays as today): plain prose for someone who has never seen the workflow; none of `Task <n>`, `part <n> of <m>`, ledger, ruling, reviewer, subagent, executor, brief, RED/GREEN; never copies the spec or the plan; no `@mentions`; nothing from the conversation that the approved description, spec or plan doesn't already say; "merge request", not "PR", on GitLab.
- A failed forge call never stops the work and is never an autopilot blocker; the final message lists what didn't post and the command that fixes it.
- The project's voice stays ("your human partner"). The new skill is developed with `superpowers:writing-skills`, baseline first.
- `glab` commands are checked against `glab <command> --help` and marked untested until a real GitLab run.
- Workflow pointers: "Each gets a short pointer to the new skill, nothing more" (spec, Workflow pointers). The version bump is left to the merge.
- Run notes, 2026-10-30: nothing in the run calls a real forge. Every test runs against the stand-in `gh`; no scratch repo is created; the acceptance is steps your human partner tries by hand.

## Review Focus

1. An autopilot executor running executing-plans or the subagent-driven-development controller, now that both skills carry pointers that push and post, still makes no `gh` call and no push. Tests: Task 4's `sdd_executor_stays_off_forge`, and Task 4's re-run of part 1's `executor_stays_off_forge`.
2. A public repo reached through brainstorming's approval in normal mode posts nothing until your human partner has seen the exact text. Test: Task 2's `brainstorm_public_small_change`.
3. Finishing on a branch whose open draft targets a non-default base takes the base from the draft without asking, names it in the menu, and the ready comment and the report say the issue won't close on merge. Test: Task 5's `finish_menu_ready_dev`.
4. A branch whose earlier draft PR was closed gets today's menu, and option 2 opens a new regular PR carrying `Closes #N`. Test: Task 5's `finish_menu_draft_closed`.
5. A failed forge call at a wired moment (the draft PR fails to open after Task 1) never stops the executor: it finishes Task 2, and its final message names `gh auth login`. Test: Task 4's `exec_draft_fails`.

## Acceptance

Your human partner tries the wired workflow by hand (spec `## Run notes`, 2026-10-30; this replaces the index's four real runs and its readability read). Task 7 readies it, and the executor's final message (under autopilot, its report's `Acceptance:` line) hands over these steps.

**Setup.** A GitHub repo of theirs with issues turned on, where test issues don't matter, for example `gh repo create shellkah/superpowers-issues-scratch --private --add-readme --clone` with a tiny script in it. Start each session with this branch's plugin, with the installed copy disabled:

```bash
claude --plugin-dir /home/dev/projects/superpowers/.worktrees/issue-tracking \
  --settings '{"enabledPlugins":{"superpowers@claude-plugins-official":false,"superpowers@superpowers-dev":false}}'
```

(or check out `issue-tracking` in `~/projects/superpowers`, which the installed plugin reads live).

1. **Small change, new issue.** Ask for a small change; in the last round of questions pick "Open a new issue"; approve the description. Passing: the issue opens at approval, assigned to you, first line `**Status:** Building`; after the first commit a draft PR opens with `Closes #N`, and the issue gets one comment linking it; at finishing, option 2 reads "Mark the draft PR ready for review"; choosing it marks the PR ready, and the status reads "Ready for review: PR #P"; merging the PR on GitHub closes the issue.
2. **Existing issue named in the request.** Open an issue by hand, then ask for a change that names it ("… see #N"). Passing: the picker lists it first; after approval it gets a comment, its title and body are unchanged, and it is assigned to you.
3. **Local merge with push.** Run a tracked change to finishing, pick option 1, and say yes to pushing. Passing: the issue closes with a comment naming the merge commit; the draft PR shows as merged (or is closed with a comment naming that commit).
4. **A project under autopilot, split in two parts.** Ask for a fully automated run of something small enough to split in two, and pick "Open a new issue" when offered. Passing: one issue; plan ready, draft PR (after part 1, not before), part 1 done and PR ready each commented once; the run ends with a regular PR, not a draft; the summary gives the issue link next to the PR link.

For every run: exactly one issue; every link in the body and comments resolves; none of the Writing Rules' banned words; no `@mentions`; the status line matches the final state; the PR body has `Closes #N`. Then read the issues from runs 1 and 4 on your phone: could a collaborator who doesn't use Claude follow the work? That has the final say on readability. On a failure, note the step and the issue or PR link, and ask a session to use `superpowers:diagnosing-superpowers` on that session. GitLab stays untested against a real server. Deleting the scratch repo afterwards needs `gh auth refresh -s delete_repo` first.

---

## Calls Made in This Part

1. **Pointer form.** Every pointer that cites the tracking skill's sections says "as superpowers:tracking-work-in-issues says (<Section>)" (several sections: "(<Section>, <Section>)"), so a static test can check that each cited name is one of its seven `##` headings. The exact pointer texts are given in each task. If a GREEN run shows a session missing a pointer, the fix is the pointer's wording or place, recorded as a ruling; a check changes only as item 9 allows.
2. **Subagent prompts stay unchanged** (spec Constraints). The index's "part-writer header" is delivered through writing-plans itself: the part writer already follows writing-plans' Plan Document Header and, under autopilot, its Execution Handoff, so writing-plans' new Issue-line rule and handover bullet reach every part file and part prompt without touching `part-writer-prompt.md`.
3. **Plan ready under autopilot with a split** posts when writing-plans returns after the index; part 1 is written right after, unattended. The tracking skill's table names writing-plans as the poster, and under autopilot writing-plans never sees part 1.
4. **The autopilot blocker exception gains step 4's pushes and the draft PR that opens with the first of them**, nothing more (spec: the exception "only gain[s] the main session's between-part pushes"). It does not list the issue's posts: the tracking skill already says that under autopilot they go out without waiting and that a failed one is never a blocker. `autopilot_spec_commit` and fast Test 7 check that opening the issue at step 2 is not treated as a blocker; if a GREEN run shows a session stopping there, extend the exception to the issue's posts and record it as a ruling.
5. **Tracked work committed straight onto the default branch** (part 1's Ruling 14, deferred here) ends through finishing's option 1: nothing to merge, so it starts at the push question, then the tracking skill's Merge locally rules apply (no PR to check). The rule sits in finishing's option 1 pointer, not in the tracking skill, whose body is at 2988 of its tested 3000-word cap.
6. **No change to brainstorming's opt-out line.** The spec's brainstorming pointers are a closed list ("nothing more"); the tracking skill's Already answered paragraph tells a session asked to track the work what the one plain line says.
7. **Part 1's shared scenario helpers and runner move into `tracking-fixtures.sh`**, so the new integration file reuses them (index: "Part 2's wiring tests reuse these rather than building their own"). Part 1's integration file keeps its scenarios and prompts; its output and exit status don't change.
8. **RED, then GREEN, per task.** Each task runs its tracked scenarios before its pointers exist and records each one's result in the commit message. A scenario that passes in RED reached the tracking skill another way (its description triggers on an `**Issue:**` link); that is recorded, not "fixed", and the pointer still goes in. The untracked and not-a-forge scenarios run only GREEN: they guard today's behaviour.
9. **Long runs.** Integration runs use `TRACKING_JOBS=4`, with output redirected to a log file outside the repo (`LOG="$(mktemp)"`; likewise `LOG2`, `LOG3`) and read by its tail. A scenario that prints `[FAIL] usage limit hit, no result` has no result: wait for the reset and re-run it; report BLOCKED only if the limit still blocks after the reset (part 1's Rulings 10 and 13). A scenario's text check may widen only when the session said the same thing in other words, recorded as a ruling (part 1's Ruling 7).
10. **Three fast tests fail before and after this part** (`test-subagent-driven-development.sh`, `test-writing-plans-split.sh`, `test-autopilot.sh`; part 1's Ruling 11). They use `run_claude`, which loads the main checkout's plugin, so they cannot see this branch; they are not this part's to fix.

## File Map

| File | Change |
|------|--------|
| `tests/claude-code/tracking-fixtures.sh` | Gains part 1's shared scenario helpers and runner (Task 1), `session_skills`, `loaded`, `spec_only` (Task 1), and a `full-pr` switch on `common_checks` (Task 5) |
| `tests/claude-code/test-tracking-work-in-issues-integration.sh` | Loses the moved definitions; ends with `run_scenarios` (Task 1) |
| `tests/claude-code/test-tracking-wiring-integration.sh` | New: the wiring scenarios, one group per task (Tasks 1-6) |
| `tests/claude-code/test-tracking-wiring.sh` | New: fast checks, static and comprehension (Tasks 1-7) |
| `skills/brainstorming/SKILL.md` | Offer, approval and small-change pointers (Task 2) |
| `skills/writing-plans/SKILL.md` | Issue line, handover bullet, plan ready (Task 3) |
| `skills/executing-plans/SKILL.md`, `skills/subagent-driven-development/SKILL.md` | After each task, at a stop, at Finish (Task 4) |
| `skills/finishing-a-development-branch/SKILL.md` | Base, menu, each option, discard (Task 5) |
| `skills/autopilot/SKILL.md` | Steps 1, 2, 4, 5, 6, blockers, the exception, Fallback, a red flag (Task 6) |
| `README.md`, `tests/claude-code/run-skill-tests.sh` | Skills list; test registration (Task 7) |

---

### Task 1: Shared scenario harness

**Files:**
- Modify: `tests/claude-code/tracking-fixtures.sh` (append a section `# ---- scenario helpers shared by the integration files ----`)
- Modify: `tests/claude-code/test-tracking-work-in-issues-integration.sh` (remove lines 26-28, 34-94, 342-360, 374-377, 493-525 and 550-615 as listed below)
- Create: `tests/claude-code/test-tracking-wiring-integration.sh`
- Create: `tests/claude-code/test-tracking-wiring.sh`

**Interfaces:**
- Consumes: everything part 1 put in `tracking-fixtures.sh` and `test-helpers.sh` (index, Cross-Part Interfaces).
- Produces, in `tracking-fixtures.sh`:
  - Moved unchanged from part 1's integration file: `BLOB`, `PR13`, `NOT_CLOSING` (lines 26-28); `setup [ssh|https|local]`, `i_body <N>`, `i_first <N>`, `same_ref`, `main_unchanged`, `main_kept`, `num_is`, `ge`, `body_ends_with_opened <N>`, `issue_state_is <N> <field> <value>`, `pr_is_draft_false`, `matches_ei`, `spec_line_is <line>`, `spec_committed`, `spec_has_no_issue_line`, `named_body_has`, `named_ends_with`, `dropped_marker_posted`, `starts`, `named_body_not_null`, `posted_title`, `posted_body`, `fx_building worktree|checkout [<base>]`, `fx_finish [<base>]` (lines 34-94; `OFFER_SENTENCE` at line 32 stays behind); `fx_finish_pushed` (374-377); `EXECUTOR_PROMPT_MD` (now `$_FIXTURES_DIR/../../skills/autopilot/executor-prompt.md`) and `executor_prompt_ok <text>`, with their comments (493-499, 521-525).
  - Moved with one change each:
    - `finish_ready_checks <plain|nonclosing> [<output>]` (342-360): the "output says the issue won't close" check reads `<output>`, default `$OUT`, so a two-turn scenario can pass `"$OUT2"`.
    - `executor_prompt <work> <worktree> <run dir> [<skill>]` (501-519): `<skill>` defaults to `executing-plans`; the handover's Skill bullet reads `` - **Skill:** use `superpowers:<skill>`. ``. Part 1's call is unchanged.
    - `run_scenarios <title> <default list>` (550-615, with `run_scenario` inside it): runs `TRACKING_SCENARIOS` (default `<default list>`) with `TRACKING_JOBS` at once (default 1), prints `=== Test: <title> (<n> scenarios, <jobs> at once) ===`, and keeps today's per-scenario output, failure dump, `[done]` lines, final `PASS` or `FAIL (<n> scenarios)` and exit status. It creates its results directory and EXIT trap when it is called, never when the file is sourced: five other test files source the fixtures and set their own traps.
  - New:
    - `session_skills <dir>`: prints, sorted and unique, every skill the sessions run from `<dir>` loaded (subagent transcripts included, found as `session_commands` finds them): the `input.skill` of each `Skill` tool call, with `superpowers:` prefixed when it has no `:`; and `superpowers:<name>` for each `Read` tool call whose `file_path` ends `/skills/<name>/SKILL.md`.
    - `loaded <dir> <name>`: true when `session_skills <dir>` prints `superpowers:<name>` (match with `grep -xF > /dev/null`, not `-q`: part 1's Ruling T4-5).
    - `spec_only <work> [<issue-line>]`: `_write_spec <work> [<issue-line>]`, then `_commit_and_push_main <work> "Add version flag spec"`.
- Produces, `test-tracking-wiring-integration.sh`: sources both helper files; `root="" work="" wt=""`; `TURN="${CLAUDE_PROMPT_TIMEOUT:-300}"`; `LONG="${CLAUDE_LONG_TIMEOUT:-900}"`; `ALL_SCENARIOS=""` with the comment `# each task appends its scenarios, in task order`; sections `# ---- prompt pieces ----` and `# ---- scenarios ----`; last line `run_scenarios 'workflow skills reach the tracking skill' "$ALL_SCENARIOS"`.
- Produces, `test-tracking-wiring.sh`: `set -uo pipefail`; `SCRIPT_DIR`, `REPO_ROOT`; sources both helper files; `T="${CLAUDE_PROMPT_TIMEOUT:-200}"`; `FAILURES=0`; `TEST_ROOT="$(mktemp -d)"`, `SESSION_ROOT="$TEST_ROOT"`, `trap 'rm -rf "$TEST_ROOT"' EXIT`; `NS="Where the skills do not say, answer 'not stated' instead of inferring."`; numbered `echo "Test N: ..."` groups; ends with `PASS`, or `FAIL (<n>)` and exit 1.

- [ ] **Step 1: Write the failing fast checks (Tests 1 and 2 of `test-tracking-wiring.sh`)**

```bash
echo "Test 1: Shared scenario helpers (no Claude run)..."
fx_finish dev
check "fx_finish dev: PR 13's base is dev" test "$(pr_json 13 | jq -r .baseRefName)" = dev
check "fx_finish dev: #12's status names the draft" test "$(i_first 12)" = '**Status:** Building: draft PR #13'
check "fx_finish dev: version-flag is on the remote" test -n "$(bare_ref "$root" version-flag)"
check "main_unchanged holds before any push" main_unchanged
p="$(executor_prompt "$work" "$wt" "$root/run" subagent-driven-development)"
check "executor_prompt fills every placeholder" executor_prompt_ok "$p"
check "executor_prompt names the skill it is given" hasf "$p" 'use `superpowers:subagent-driven-development`'
check "executor_prompt defaults to executing-plans" hasf "$(executor_prompt "$work" "$wt" "$root/run")" 'use `superpowers:executing-plans`'
s="$TEST_ROOT/spec"; fxv sw tracking_repo "$s"; spec_only "$sw" "$ISSUE12"
check "spec_only commits the spec with its line" test "$(git -C "$sw" show HEAD:"$SPEC_PATH" | sed -n 3p)" = "$ISSUE12"
check "spec_only pushes main" same_ref "$(bare_ref "$s" main)" "$(git -C "$sw" rev-parse main)"
d="$TEST_ROOT/transcript-dir"; mkdir -p "$d"
proj="$HOME/.claude/projects/$(cd "$d" && pwd -P | sed 's|[^a-zA-Z0-9]|-|g')"; mkdir -p "$proj"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"superpowers:finishing-a-development-branch"}}]}}' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/skills/tracking-work-in-issues/SKILL.md"}}]}}' > "$proj/fake.jsonl"
check "session_skills reads a Skill call" loaded "$d" finishing-a-development-branch
check "session_skills reads a SKILL.md read" loaded "$d" tracking-work-in-issues
check "loaded is false for a skill not loaded" not loaded "$d" brainstorming
rm -rf "$proj"
for f in test-tracking-wiring-integration.sh test-tracking-work-in-issues-integration.sh; do
    out="$(TRACKING_SCENARIOS=no_such bash "$SCRIPT_DIR/$f" 2>&1)"; rc=$?
    check "$f: an unknown scenario fails without a session" test "$rc" = 1
    check "$f: says so" hasf "$out" '[FAIL] no such scenario: no_such'
    check "$f: and ends FAIL (1 scenarios)" hasf "$out" 'FAIL (1 scenarios)'
done
echo ""

echo "Test 2: Subagent prompts leave the forge alone (no Claude run)..."
for f in skills/subagent-driven-development/implementer-prompt.md skills/subagent-driven-development/task-reviewer-prompt.md \
    skills/subagent-driven-development/re-review-prompt.md skills/writing-plans/part-writer-prompt.md \
    skills/writing-plans/cross-part-check-prompt.md skills/brainstorming/builder-check-prompt.md \
    skills/autopilot/executor-prompt.md skills/requesting-code-review/code-reviewer.md; do
    check "$f exists" test -f "$REPO_ROOT/$f"
    check "$f does not send its subagent to the tracking skill" not grep -q 'tracking-work-in-issues' "$REPO_ROOT/$f"
done
echo ""
```

`fx_finish` sets `root`, `work` and `wt` through `setup`, which makes its own temp root and sets `SESSION_ROOT`; at the end of Test 1, `rm -rf "$root"` and restore `SESSION_ROOT="$TEST_ROOT"`, so later session tests run under the file's root.

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: `FAIL`. Test 1 prints `fx_finish: command not found` and its checks fail, the unknown-scenario ones included (the new integration file does not exist yet). Test 2 passes: no subagent prompt names the skill today, and none may.

- [ ] **Step 3: Move the helpers and the runner; add the new helpers and the integration file skeleton**

Move the definitions listed under Produces into `tracking-fixtures.sh` in their current order, with the three changes named there. In part 1's integration file, the scenario prompts (`OFFER_SENTENCE`, `OPEN_NEW_PROMPT`, `OPEN_EXISTING_PROMPT`, `EXEC_AFTER_TASK1`, `MERGE_PROMPT`), `fx_existing_4` and `issue_4_unchanged` stay, and the file ends with `run_scenarios 'issue tracking, moment by moment' "$ALL_SCENARIOS"`. Write `session_skills`, `loaded` and `spec_only`, and create `test-tracking-wiring-integration.sh` as its Produces line says.

- [ ] **Step 4: Run the fast checks and the moved runner**

Run: `bash -n tests/claude-code/tracking-fixtures.sh tests/claude-code/test-tracking-work-in-issues-integration.sh tests/claude-code/test-tracking-wiring-integration.sh && bash tests/claude-code/test-tracking-wiring.sh`
Expected: no syntax error; `PASS`.

Run: `bash tests/claude-code/test-fake-gh.sh && bash tests/claude-code/test-forge-commands.sh`
Expected: both `PASS` (they source the fixtures; nothing they define may collide).

Run: `LOG="$(mktemp)"; TRACKING_SCENARIOS='offer_issues_off finish_keep' TRACKING_JOBS=2 bash tests/claude-code/test-tracking-work-in-issues-integration.sh > "$LOG" 2>&1; tail -n 40 "$LOG"`
Expected: `PASS`. Two real sessions through the moved `setup`, `fx_finish`, `common_checks` and runner.

- [ ] **Step 5: Commit**

```bash
git add tests/claude-code/tracking-fixtures.sh tests/claude-code/test-tracking-work-in-issues-integration.sh \
    tests/claude-code/test-tracking-wiring-integration.sh tests/claude-code/test-tracking-wiring.sh
git commit -m "test(tracking): share the scenario helpers and runner for the wiring tests"
```

---

### Task 2: Brainstorming offers, and opens the issue at approval

**Files:**
- Modify: `skills/brainstorming/SKILL.md:179-183` (normal workflow), insert after it, and `:277-278` (inside the HARD-GATE)
- Test: `tests/claude-code/test-tracking-wiring-integration.sh`, `tests/claude-code/test-tracking-wiring.sh` (Test 3)

**Interfaces:**
- Consumes: Task 1's helpers; part 1's `fake_issue`, `fake_repo_facts`, `copied_lines`, `common_checks`, `HEADLESS`.
- Produces: in the fast file, `TRACKING_SKILL`, `declare -A EXPECT`, `cited_sections <file>` and Test 3's loop, which Tasks 3-6 extend by adding `EXPECT` entries.

- [ ] **Step 1: Write the failing scenarios and the pointer check**

In the wiring integration file, append `brainstorm_offer brainstorm_no_forge brainstorm_small_change_approved brainstorm_public_small_change brainstorm_project_approved` to `ALL_SCENARIOS`, and add:

```bash
# ---- brainstorming ----
b_intro() { printf '%s' "Use superpowers:brainstorming. We are in it for this request: \"$1\""; }
B_LAST="The work is sized as a small change, and this is the last round of questions. Ask your last round of questions now, as brainstorming says. $HEADLESS"
B_SMALL_APPROVED=' The work was sized as a small change. In the last round of questions you offered to track it in an issue, and your human partner chose "Open a new issue". You then described the change in chat: `./hello.sh --name Ada` prints "Hello, Ada!", plain `./hello.sh` still prints "Hello, world!", and test.sh checks both. They just replied: "Looks good, go ahead." Carry on as brainstorming says, and stop before you write any code or test.'
# no change to hello.sh or test.sh: not in the work tree, not in any commit after the first
hello_untouched() { git -C "$work" diff --quiet -- hello.sh test.sh && test "$(git -C "$work" log --all --format=%H -- hello.sh | wc -l)" = 1; }

scenario_brainstorm_offer() {
    setup || return
    fx fake_issue 3 'Add a --version flag to hello.sh' '' alice || return
    run_moment "$work" "$TURN" "$(b_intro 'Add a --version flag to hello.sh.') $B_LAST"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "no forge write" num_is "$(gh_write_count)" 0
    check "an issue list call carries a search" gh_log_has_flag issue list '--search|-S'
    check "offers: Open a new issue" hasf "$OUT" 'Open a new issue'
    check "offers: No issue" hasf "$OUT" 'No issue'
    check "lists #3" hasf "$OUT" '#3'
    common_checks "$work"
}

scenario_brainstorm_no_forge() { # origin is a local path: no offer, no gh call
    setup local || return
    run_moment "$work" "$TURN" "$(b_intro 'Add a --version flag to hello.sh.') $B_LAST"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "no gh call" num_is "$(gh_log_total)" 0
    check "no offer to open an issue" not hasf "$OUT" 'Open a new issue'
    common_checks "$work"
}

scenario_brainstorm_small_change_approved() {
    setup || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$(b_intro 'Make hello.sh greet a name given with --name.')$B_SMALL_APPROVED"
    local body
    body="$(posted_body)"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "one issue created" num_is "$(gh_log_count issue create)" 1
    check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
    check "body starts with the Building status" test "$(first_line "$body")" = '**Status:** Building'
    check "body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "hello.sh and test.sh untouched" hello_untouched
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_brainstorm_public_small_change() {
    setup || return
    fx fake_repo_facts PUBLIC true main || return
    run_moment "$work" "$TURN" "$(b_intro 'Make hello.sh greet a name given with --name.')$B_SMALL_APPROVED"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "no issue created yet" num_is "$(gh_log_count issue create)" 0
    check "says public" hasf "$OUT" 'public'
    check "shows the text, with its Status line" hasf "$OUT" 'Status:'
    check "hello.sh and test.sh untouched" hello_untouched
    common_checks "$work"
}

scenario_brainstorm_project_approved() {
    setup || return
    fx spec_only "$work" || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$(b_intro 'Add a --version flag to hello.sh.') It was sized as a project, and its written design is at $SPEC_PATH, committed; the builder check is done. In the last round of questions you offered to track it in an issue, and your human partner chose \"Open a new issue\". They just replied: \"The design looks right. Approved.\" Carry on as brainstorming says, and stop before you invoke superpowers:writing-plans."
    local body
    body="$(posted_body)"
    printf '%s\n' "$body" > "$root/posted-body.txt"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "one issue created" num_is "$(gh_log_count issue create)" 1
    check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
    check "body starts with the Planning status" test "$(first_line "$body")" = '**Status:** Planning'
    check "body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "body names the spec path" hasf "$body" "$SPEC_PATH"
    check "body copies no spec line" test -z "$(copied_lines "$root/posted-body.txt" "$work/$SPEC_PATH")"
    check "spec carries the issue line" spec_line_is '**Issue:** https://github.com/acme/widgets/issues/1 (opened for this work)'
    check "spec change is committed" spec_committed
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}
```

In the fast file, add Test 3:

```bash
echo "Test 3: Each wired skill cites the tracking skill's sections (no Claude run)..."
TRACKING_SKILL="$REPO_ROOT/skills/tracking-work-in-issues/SKILL.md"
declare -A EXPECT=(
    [brainstorming]='The Offer|Opening the Issue'
)
# Each section a file cites as "tracking-work-in-issues says (<S>[, <S>])", one per line;
# lines are joined first, since the skills are hard-wrapped.
cited_sections() {
    tr '\n' ' ' < "$1" | tr -s ' ' | grep -oE 'tracking-work-in-issues says \([^)]*\)' \
        | sed -E 's/^tracking-work-in-issues says \((.*)\)$/\1/' | sed 's/, /\n/g'
}
headings() { grep '^## ' "$TRACKING_SKILL" | sed 's/^## //'; }
for skill in $(printf '%s\n' "${!EXPECT[@]}" | sort); do
    cites="$(cited_sections "$REPO_ROOT/skills/$skill/SKILL.md")"
    check "$skill cites only the tracking skill's ## sections" test -z "$(grep -vxF -f <(headings) <<< "$cites")"
    IFS='|' read -ra want <<< "${EXPECT[$skill]}"
    for s in "${want[@]}"; do check "$skill cites ($s)" grep -xF -- "$s" <<< "$cites"; done
done
echo ""
```

- [ ] **Step 2: Run them to verify they fail (RED)**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: FAIL at Test 3, `brainstorming cites (The Offer)` and `(Opening the Issue)`.

Run: `TRACKING_SCENARIOS='brainstorm_offer brainstorm_small_change_approved brainstorm_public_small_change brainstorm_project_approved' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`, then read its tail
Expected: `brainstorm_offer` FAILs (no offer, no search). Record every scenario's result, and for each failure the session's own words for what it did, for the commit message.

- [ ] **Step 3: Add the three pointers to `skills/brainstorming/SKILL.md`**

Replace the paragraph at 179-183 with:

```markdown
**The normal workflow for a small change** in software: work on a
branch, never on main or master unless they say so. Test first
(superpowers:test-driven-development), run the check its description
names, then superpowers:requesting-code-review and
superpowers:finishing-a-development-branch. If it tracks an issue, open
the issue when they approve the description, as
superpowers:tracking-work-in-issues says (Opening the Issue); that skill
then covers the issue through to finishing, starting with a draft PR
after your first commit.

**Issue tracking.** Once the work is sized as a small change or a
project, your last round of questions includes the offer to track it in
an issue, made as superpowers:tracking-work-in-issues says (The Offer).
That skill also says when there is no offer.
```

Replace the HARD-GATE's last two lines (277-278) with:

```markdown
After a project's document is approved, open the issue first if this
work tracks one, as superpowers:tracking-work-in-issues says (Opening
the Issue). Then the next step is the plan. For software, invoke
superpowers:writing-plans and no other skill.
```

Why inside the gate: "invoke superpowers:writing-plans and no other skill" would otherwise read as forbidding the tracking skill at approval.

- [ ] **Step 4: Run them to verify they pass (GREEN), and the existing brainstorming tests**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: `PASS`.

Run: `TRACKING_SCENARIOS='brainstorm_offer brainstorm_no_forge brainstorm_small_change_approved brainstorm_public_small_change brainstorm_project_approved' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `PASS`, 5 scenarios.

Run: `bash tests/claude-code/test-brainstorming-focus.sh && bash tests/claude-code/test-workflow-handoffs.sh`
Expected: both pass (`test-workflow-handoffs.sh` Test 5 still answers "Ends with: … finishing").

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/SKILL.md tests/claude-code/test-tracking-wiring-integration.sh tests/claude-code/test-tracking-wiring.sh
git commit -m "feat(brainstorming): point to issue tracking for the offer and at approval"
```

The message body lists each scenario's RED result.

---

### Task 3: Writing-plans copies the Issue line, adds the handover bullet, posts plan ready

**Files:**
- Modify: `skills/writing-plans/SKILL.md` (insert after `:227`; the bullets block `:374-381` and list `:383-386`; insert before `:391`; `:416-417`)
- Test: `tests/claude-code/test-tracking-wiring-integration.sh`, `tests/claude-code/test-tracking-wiring.sh` (Tests 4 and 5; `EXPECT` entry)

**Interfaces:**
- Consumes: Task 1's `spec_only`, `loaded`; part 1's `opened_issue_12`, `ISSUE12`, `first_line_after_title`.
- Produces: the decision line in plan, index and part-file headers, and the handover bullet, both exactly as the index's Cross-Part Interfaces give them (`` - **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says. ``).

- [ ] **Step 1: Write the failing scenarios and checks**

Append `plan_tracked plan_untracked` to `ALL_SCENARIOS`, and add:

```bash
# ---- writing-plans ----
P_WRITE="Use superpowers:writing-plans to write the implementation plan for $SPEC_PATH. The spec is approved."
HANDOVER_BULLET_12='- **Issue:** keep `https://github.com/acme/widgets/issues/12` current as `superpowers:tracking-work-in-issues` says.'
# The plan writing-plans wrote: the one .md under docs/superpowers/plans that is not an index, a part or a handover file.
plan_doc() { find "$work/docs/superpowers/plans" -name '*.md' ! -name '*-index.md' ! -name '*-part-*' ! -name '*.handover.md' 2> /dev/null; }
handover_doc() { find "$work/docs/superpowers/plans" -name '*.handover.md' 2> /dev/null; }
one_line() { test "$(grep -c . <<< "$1")" = 1; }

scenario_plan_tracked() {
    setup || return
    fx spec_only "$work" "$ISSUE12" || return
    fx opened_issue_12 Planning noplan || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$LONG" "$P_WRITE"
    local plan hand rel
    plan="$(plan_doc)"; hand="$(handover_doc)"; rel="${plan#"$work"/}"
    check "loaded writing-plans" loaded "$work" writing-plans
    check "one plan, not split" one_line "$plan"
    check "no index" test -z "$(find "$work/docs/superpowers/plans" -name '*-index.md')"
    check "the plan carries the spec's Issue line under its title" test "$(first_line_after_title "$plan")" = "$ISSUE12"
    check "one handover file" one_line "$hand"
    check "the handover prompt has the Issue bullet" grep -qxF -- "$HANDOVER_BULLET_12" "$hand"
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with the plan-ready marker" named_ends_with issue comment 12 '<!-- superpowers:plan-ready -->'
    check "it says the plan waits for review" has_i "$(named_body issue comment 12)" 'review'
    check "#12 status line is Planning" test "$(i_first 12)" = '**Status:** Planning'
    check "#12 body names the plan path" hasf "$(i_body 12)" "$rel"
    check "#12 body ends with the opened marker" body_ends_with_opened 12
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_plan_untracked() {
    setup || return
    fx spec_only "$work" '**Issue:** none' || return
    run_moment "$work" "$LONG" "$P_WRITE"
    local plan hand
    plan="$(plan_doc)"; hand="$(handover_doc)"
    check "loaded writing-plans" loaded "$work" writing-plans
    check "no gh call" num_is "$(gh_log_total)" 0
    check "the plan copies Issue: none" test "$(first_line_after_title "$plan")" = '**Issue:** none'
    check "the handover prompt has no Issue bullet" not grep -q '^- \*\*Issue:\*\*' "$hand"
    common_checks "$work"
}
```

In the fast file, add `[writing-plans]='Milestones'` to `EXPECT`, and:

```bash
echo "Test 4: writing-plans carries the Issue line and the handover bullet (no Claude run)..."
W="$REPO_ROOT/skills/writing-plans/SKILL.md"
check "writing-plans has the exact handover bullet" grep -qxF -- '- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.' "$W"
check "writing-plans says where the Issue line goes" grep -qF '**Issue line.**' "$W"
echo ""

echo "Test 5: A split plan and its issue (comprehension)..."
mkdir -p "$TEST_ROOT/t5"
run_moment "$TEST_ROOT/t5" "$T" "Read the superpowers:writing-plans skill. A project's spec carries this line under its title: **Issue:** https://github.com/acme/widgets/issues/12 (opened for this work). The plan is split into 2 parts. Answer using exactly this structure:
Index carries the Issue line: <yes, no, or not stated>
In a part file, the Issue line comes right after: <the line it follows, or not stated>
Part 2's handover prompt has an Issue bullet: <yes, no, or not stated>
Plan-ready milestone posted under autopilot: <yes, no, or not stated>
With **Issue:** none in the spec instead, handover prompts have an Issue bullet: <yes, no, or not stated>
$NS"
check "the index carries the line" has_ei "$OUT" 'Index carries the Issue line:[^a-z]*yes\b'
check "in a part file it follows the Part line" has_ei "$OUT" 'comes right after:.*part'
check "part 2's prompt has the bullet" has_ei "$OUT" "Part 2's handover prompt has an Issue bullet:[^a-z]*yes\b"
check "plan ready is posted under autopilot" has_ei "$OUT" 'posted under autopilot:[^a-z]*yes\b'
check "Issue: none gets no bullet" has_ei "$OUT" 'handover prompts have an Issue bullet:[^a-z]*no\b'
check_isolation "$TEST_ROOT/t5"
echo ""
```

- [ ] **Step 2: Run them to verify they fail (RED)**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: FAIL at Test 3 (`writing-plans cites (Milestones)`) and Test 4; Test 5 FAILs on at least the bullet and Part-line answers.

Run: `TRACKING_SCENARIOS=plan_tracked bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: FAIL, at least "the handover prompt has the Issue bullet". Record the result.

- [ ] **Step 3: Add the pointers to `skills/writing-plans/SKILL.md`**

After the Plan Document Header template's closing fence (line 227), before `## Task Structure`:

```markdown
**Issue line.** When the spec carries an `**Issue:**` line under its
title (superpowers:tracking-work-in-issues), copy it unchanged into the
plan, one blank line under the title. A split plan's index carries it
the same way, and each part file carries it one blank line under its
Part line.
```

In the bullets block of Execution Handoff step 3, add as its last line:

```markdown
- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.
```

and to the list under it, as its last item:

```markdown
- **Issue:** every part, when the spec's `**Issue:**` line has a link (not `none`); `<url>` is that link.
```

Before `**4. End the session with one message**`:

```markdown
**Plan ready.** If the plan tracks an issue, post the plan-ready
milestone as superpowers:tracking-work-in-issues says (Milestones): in
normal mode once the plan, or the index and part 1, are written, before
the closing message; under autopilot just before you return control,
once the plan or the index is written.
```

In the closing `**Under autopilot**` paragraph, "skip the message and return control to autopilot." becomes "skip the message and return control to autopilot, after Plan ready above."

- [ ] **Step 4: Run them to verify they pass (GREEN), and the existing writing-plans tests**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: `PASS`.

Run: `TRACKING_SCENARIOS='plan_tracked plan_untracked' TRACKING_JOBS=2 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `PASS`, 2 scenarios.

Run: `bash tests/claude-code/test-writing-plans-handover.sh`
Expected: passes (its Test 6 still sees no Workspace bullet for part 2).

- [ ] **Step 5: Commit**

```bash
git add skills/writing-plans/SKILL.md tests/claude-code/test-tracking-wiring-integration.sh tests/claude-code/test-tracking-wiring.sh
git commit -m "feat(writing-plans): carry the issue line and bullet, post plan ready"
```

---

### Task 4: The executors push, open the draft, and post at a stop and at a part's end

**Files:**
- Modify: `skills/executing-plans/SKILL.md:39-43` (four stops), after `:232` (Complete the task), before `:308` (Finish)
- Modify: `skills/subagent-driven-development/SKILL.md:27-31` (four stops), after `:443` (Complete the task), before `:491` (Finish)
- Test: `tests/claude-code/test-tracking-wiring-integration.sh`, `tests/claude-code/test-tracking-wiring.sh` (`EXPECT` entries)

**Interfaces:**
- Consumes: Task 1's `fx_building`, `executor_prompt <work> <worktree> <run dir> [<skill>]`, `executor_prompt_ok`, `loaded`; part 1's `version_flag_docs`, `split_plan_docs`, `opened_issue_12`, `work_branch`, `push_work`, `draft_pr_13`, `task2_commit`, `named_last_lines`, `PART_PATH`.
- Produces (wiring file only): `ledger_done <dir> <plan-path> <exec|sdd> <N>...`, `part1_handover <work>`, `draft_opened_checks`.

- [ ] **Step 1: Write the failing scenarios**

Append `exec_task1_opens_draft exec_untracked exec_stop_posts_waiting exec_part_done exec_draft_fails sdd_task1_opens_draft sdd_executor_stays_off_forge` to `ALL_SCENARIOS`, and add these fixtures:

- `ledger_done <dir> <plan-path> <exec|sdd> <N>...`: in `<dir>`, runs `$SCRIPT_DIR/../../skills/subagent-driven-development/scripts/sdd-workspace <plan-path>` (it prints the workspace and writes its `.gitignore`), then writes `<workspace>/progress.md`: the line `# SDD ledger — plan: <plan-path>`, then for each N, `Task <N>: complete (commits <base7>..<head7>, tests: bash test.sh → PASS)` (`exec`) or `Task <N>: complete (commits <base7>..<head7>, review clean)` (`sdd`), with `<base7>` the short `git merge-base main HEAD` and `<head7>` the short `HEAD`.
- `part1_handover <work>`: prints this handover prompt, `<work>` expanded:

```markdown
Execute part 1 of 2 of the implementation plan at `<work>/docs/superpowers/plans/2026-01-01-version-flag-part-1-core.md` (spec: `<work>/docs/superpowers/specs/2026-01-01-version-flag-design.md`).

- **Skill:** use `superpowers:executing-plans`.
- **Why this mode:** two small tasks, done in order.
- **Branch:** work on branch `version-flag`.
- **Workspace:** set up the workspace as the skill says.
- **Not the last part:** <writing-plans' Not the last part bullet text, verbatim from skills/writing-plans/SKILL.md:380>
- **Issue:** keep `https://github.com/acme/widgets/issues/12` current as `superpowers:tracking-work-in-issues` says.
```

Then the scenarios:

```bash
# ---- executing-plans and the subagent-driven-development controller ----
E_TASK1="Use superpowers:executing-plans to execute the plan at $PLAN_PATH, in this worktree. Do Task 1 only, then stop before you start Task 2."

# The draft PR after Task 1, as part 1's scenario_draft_after_task1 checks it.
draft_opened_checks() {
    local prbody
    prbody="$(gh_log_body pr create)"
    check "version-flag is on the remote at HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "the PR is a draft" gh_log_has_flag pr create '--draft|-d'
    check "base is main" gh_log_has_flag pr create '--base|-B' main
    check "head is version-flag" gh_log_has_flag pr create '--head|-H' version-flag
    check "PR body closes #12" hasf "$prbody" 'Closes #12'
    check "PR body links the spec" hasf "$prbody" "$BLOB/$SPEC_PATH"
    check "PR body links the plan" hasf "$prbody" "$BLOB/$PLAN_PATH"
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "the comment links the PR" named_body_has issue comment 12 "$PR13"
    check "the comment ends with the draft-pr marker" named_ends_with issue comment 12 '<!-- superpowers:draft-pr -->'
    check "#12 status line is the draft PR" test "$(i_first 12)" = '**Status:** Building: draft PR #13'
    check "#12 body links the spec" hasf "$(i_body 12)" "$BLOB/$SPEC_PATH"
    check "#12 body ends with the opened marker" body_ends_with_opened 12
    check "main on the remote is unchanged" main_unchanged
}

scenario_exec_task1_opens_draft() {
    fx_building worktree || return
    fx git -C "$wt" reset -q --hard HEAD~1 || return   # Task 1 not done yet
    run_moment "$wt" "$LONG" "$E_TASK1"
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "Task 1 is committed: VERSION holds 1.0.0" test "$(git -C "$wt" show HEAD:VERSION 2> /dev/null)" = 1.0.0
    draft_opened_checks
    common_checks "$wt"
}

scenario_exec_untracked() {
    setup || return
    fx version_flag_docs "$work" '**Issue:** none' || return
    fxv wt work_branch "$work" main worktree || return
    fx git -C "$wt" reset -q --hard HEAD~1 || return
    run_moment "$wt" "$LONG" "$E_TASK1"
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "Task 1 is committed: VERSION holds 1.0.0" test "$(git -C "$wt" show HEAD:VERSION 2> /dev/null)" = 1.0.0
    check "no gh call" num_is "$(gh_log_total)" 0
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    common_checks "$wt"
}

scenario_exec_stop_posts_waiting() { # Task 3 deletes a remote branch: one of the four stops
    fx_building worktree || return
    fx push_work "$wt" || return
    fx draft_pr_13 main || return
    fx task2_commit "$wt" || return
    printf '\n%s\n\n%s\n' '### Task 3: Remove the legacy branch' \
        '- [ ] Delete the `legacy` branch on origin with `git push origin --delete legacy`: nothing uses it any more.' >> "$wt/$PLAN_PATH"
    fx git -C "$wt" commit -qam 'Plan: remove the legacy branch' || return
    fx git -C "$work" push -q origin main:refs/heads/legacy || return
    fx ledger_done "$wt" "$PLAN_PATH" exec 1 2 || return
    run_moment "$wt" "$TURN" "Use superpowers:executing-plans to execute the plan at $PLAN_PATH, in this worktree. Its ledger shows Tasks 1 and 2 complete; carry on from Task 3. $HEADLESS"
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "legacy is still on the remote" test -n "$(bare_ref "$root" legacy)"
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with a waiting marker" grep -qE '^<!-- superpowers:waiting-[0-9]{12} -->$' <<< "$(named_last_lines issue comment 12)"
    check "#12 status line is waiting" test "$(i_first 12)" = '**Status:** Waiting on a decision'
    check "asks about the legacy branch" hasf "$OUT" 'legacy'
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    common_checks "$wt"
}

scenario_exec_part_done() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 || return
    fxv wt work_branch "$work" main worktree || return
    fx push_work "$wt" || return
    fx draft_pr_13 main || return
    fx task2_commit "$wt" || return
    fx push_work "$wt" || return
    fx ledger_done "$wt" "$PART_PATH" exec 1 2 || return
    run_moment "$wt" "$TURN" "$(part1_handover "$work")

Every task of this part is complete in the ledger, and the final review passed with no findings. Carry on from the Finish step as executing-plans and this prompt say."
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with the part-1-done marker" named_ends_with issue comment 12 '<!-- superpowers:part-1-done -->'
    check "no pr ready" num_is "$(gh_log_count pr ready)" 0
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "no finishing menu" not hasf "$OUT" 'Which option?'
    common_checks "$wt"
}

scenario_exec_draft_fails() {
    fx_building worktree || return
    fx git -C "$wt" reset -q --hard HEAD~1 || return
    export FAKE_GH_FAIL='pr create'
    run_moment "$wt" "$LONG" "Use superpowers:executing-plans to execute the plan at $PLAN_PATH, in this worktree. Do Tasks 1 and 2, then stop before the final review and write your final message for this run."
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "tried to open the draft" ge "$(gh_log_count pr create)" 1
    check "./hello.sh --version prints 1.0.0" test "$(cd "$wt" && ./hello.sh --version 2> /dev/null)" = 1.0.0
    check "the version change is committed" git -C "$wt" diff --quiet HEAD -- hello.sh
    check "says gh auth login" hasf "$OUT" 'gh auth login'
    common_checks "$wt"
}

scenario_sdd_task1_opens_draft() {
    fx_building worktree || return
    fx ledger_done "$wt" "$PLAN_PATH" sdd 1 || return
    run_moment "$wt" "$TURN" "Use superpowers:subagent-driven-development: you are its controller for the plan at $PLAN_PATH, in this worktree. Task 1's task review came back clean, and you have just written its completion line to the ledger. Carry on as the skill says, and stop before you dispatch Task 2's implementer."
    check "loaded subagent-driven-development" loaded "$wt" subagent-driven-development
    draft_opened_checks
    common_checks "$wt"
}

scenario_sdd_executor_stays_off_forge() {
    fx_building worktree || return
    fx mkdir -p "$root/run" || return
    local prompt
    prompt="$(executor_prompt "$work" "$wt" "$root/run" subagent-driven-development)"
    executor_prompt_ok "$prompt" || { check "fixture: executor prompt built from executor-prompt.md" false; return; }
    run_moment "$wt" "$TURN" "$prompt"
    check "no gh call" num_is "$(gh_log_total)" 0
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    common_checks "$wt"
}
```

In the fast file, add `[executing-plans]='The Draft PR|Milestones'` and `[subagent-driven-development]='The Draft PR|Milestones'` to `EXPECT`.

- [ ] **Step 2: Run them to verify they fail (RED)**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: FAIL at Test 3 for both skills.

Run: `TRACKING_SCENARIOS='exec_task1_opens_draft exec_stop_posts_waiting exec_part_done exec_draft_fails sdd_task1_opens_draft sdd_executor_stays_off_forge' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `exec_stop_posts_waiting` FAILs (no waiting comment); record every result. `sdd_executor_stays_off_forge` should pass here too: it guards the GREEN state.

- [ ] **Step 3: Add the pointers**

In both skills, the four-stops paragraph ends "For those, stop and ask." (executing-plans) or "For those,\nstop and ask." (subagent-driven-development). Append to it:

```markdown
If this work tracks an issue, post the waiting-on-you milestone as you
stop, as superpowers:tracking-work-in-issues says (Milestones).
```

After the paragraph that completes a task (executing-plans: "When it records, mark the todo complete and take the next task."; subagent-driven-development: the paragraph ending "parked-with-ruling at the cap."), add:

```markdown
If this work tracks an issue, push after each completed task as
superpowers:tracking-work-in-issues says (The Draft PR); after Task 1,
that also opens the draft PR. That push and that PR are the tracking
your human partner chose, not one of the four stops. Under autopilot an
executor makes none of these pushes or posts: autopilot's main session
does.
```

In `## Finish`, directly before "Use superpowers:finishing-a-development-branch.":

```markdown
If this work tracks an issue and this part is not the plan's last (its
header says Part N of M, N below M), post the part-done milestone as
superpowers:tracking-work-in-issues says (Milestones) before you stop.
```

Why "not one of the four stops": both skills list "a push to a shared branch, a publish" as a stop; without that sentence an executor asks before the draft PR, which the spec makes your human partner's standing call.

- [ ] **Step 4: Run them to verify they pass (GREEN), and the guards**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: `PASS`.

Run: `TRACKING_SCENARIOS='exec_task1_opens_draft exec_untracked exec_stop_posts_waiting exec_part_done exec_draft_fails sdd_task1_opens_draft sdd_executor_stays_off_forge' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `PASS`, 7 scenarios.

Run: `TRACKING_SCENARIOS=executor_stays_off_forge bash tests/claude-code/test-tracking-work-in-issues-integration.sh > "$LOG2" 2>&1`
Expected: `PASS`: part 1's autopilot executor, now reading executing-plans' pointers, still makes no `gh` call.

Run: `bash tests/claude-code/test-executing-plans-scripts.sh && bash tests/claude-code/test-workflow-handoffs.sh`
Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add skills/executing-plans/SKILL.md skills/subagent-driven-development/SKILL.md \
    tests/claude-code/test-tracking-wiring-integration.sh tests/claude-code/test-tracking-wiring.sh
git commit -m "feat(executing-plans, sdd): point to issue tracking after each task, at a stop, at a part's end"
```

---

### Task 5: Finishing reads the draft, changes option 2, and updates the issue for every option

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md` (after `:55`; before `:82`; before `:110`; after `:117`; after `:139`; after `:153`)
- Modify: `tests/claude-code/tracking-fixtures.sh` (`common_checks`)
- Test: `tests/claude-code/test-tracking-wiring-integration.sh`, `tests/claude-code/test-tracking-wiring.sh` (Test 6; `EXPECT` entry)

**Interfaces:**
- Consumes: Task 1's `fx_finish`, `fx_finish_pushed`, `finish_ready_checks <plain|nonclosing> [<output>]`, `loaded`; part 1's `opened_issue_12`, `version_flag_docs`, `work_branch`, `task2_commit`, `named_body_ending`.
- Produces: `common_checks <dir> [full-pr]` in `tracking-fixtures.sh`: with `full-pr`, the writing-rules check skips `pr create` bodies (they are finishing's full description, which stays as today); titles and every other body are still checked. Part 1's calls are unchanged. Wiring file only: `C_FINISH_USE`, `menu_has <text>`, `close_pr <P>`.

- [ ] **Step 1: Write the failing scenarios and checks**

Append `finish_menu_ready_dev finish_menu_untracked finish_menu_draft_closed finish_option1_pushed finish_option3_paused finish_discard_confirmed finish_on_default_branch` to `ALL_SCENARIOS`, and add:

```bash
# ---- finishing-a-development-branch ----
C_FINISH_USE='Implementation of the plan at docs/superpowers/plans/2026-01-01-version-flag.md is complete on this branch: its tests pass, and there were no rulings or deferred minors. Use superpowers:finishing-a-development-branch.'
menu_has() { hasf "$(tr -d '*' <<< "$OUT")" "$1"; }   # bold markup aside
close_pr() { local f="$FAKE_GH_STATE/pulls/$1.json"; jq '.state = "CLOSED" | .closed = true' "$f" > "$f.tmp" && mv "$f.tmp" "$f"; }

scenario_finish_menu_ready_dev() { # the base comes from the draft, not a question
    fx_finish dev || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "menu: option 2 marks the draft ready" menu_has '2. Mark the draft PR ready for review'
    check "menu: no Push and create a Pull Request" not menu_has 'Push and create a Pull Request'
    check "menu: option 1 names dev" menu_has '1. Merge back to dev locally'
    check "menu: option 3 keeps its text" menu_has "3. Keep the branch as-is (I'll handle it later)"
    check "does not ask for the base" not has_i "$OUT" 'is that correct'
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    continue_moment "$wt" "$TURN" '2'
    finish_ready_checks nonclosing "$OUT2"
}

scenario_finish_menu_untracked() { # no Issue line at all: today's menu, no gh call
    setup || return
    fx version_flag_docs "$work" || return
    fxv wt work_branch "$work" main checkout || return
    fx task2_commit "$wt" || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE This branch was cut from main. $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "no gh call" num_is "$(gh_log_total)" 0
    for line in '1. Merge back to main locally' '2. Push and create a Pull Request' "3. Keep the branch as-is (I'll handle it later)"; do
        check "menu has: $line" menu_has "$line"
    done
    check "no Mark the draft PR" not menu_has 'Mark the draft PR'
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    common_checks "$wt"
}

scenario_finish_menu_draft_closed() {
    fx_finish main || return
    fx close_pr 13 || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE This branch was cut from main. $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "menu: option 2 is today's" menu_has '2. Push and create a Pull Request'
    check "menu: no Mark the draft PR" not menu_has 'Mark the draft PR'
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    continue_moment "$wt" "$TURN" '2'
    check "version-flag is on the remote at HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "it is not a draft" not gh_log_has_flag pr create '--draft|-d'
    check "its base is main" gh_log_has_flag pr create '--base|-B' main
    check "its body closes #12" hasf "$(gh_log_body pr create)" 'Closes #12'
    check "a comment on #12 ends with the pr-ready marker" named_ends_with issue comment 12 '<!-- superpowers:pr-ready -->'
    check "#12 status line is ready for review on PR #14" test "$(i_first 12)" = '**Status:** Ready for review: PR #14'
    common_checks "$wt" full-pr
}
```

`finish_option1_pushed`, `finish_option3_paused` and `finish_discard_confirmed` are copies of part 1's `scenario_finish_merge_pushed`, `scenario_finish_keep` and `scenario_finish_discard_opened` (in its integration file), each with three changes: the first prompt is `"$C_FINISH_USE Your human partner has already chosen option 1, Merge back to main locally. $HEADLESS"`, `"$C_FINISH_USE Your human partner has already chosen option 3, Keep the branch as-is."` and `"$C_FINISH_USE Your human partner asks you to discard this work entirely. $HEADLESS"`; the first check after the first turn is `check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch`; every other check, the second turns (`'Yes, push main.'`, `'discard'`) and `common_checks "$wt"` are copied as they are.

```bash
scenario_finish_on_default_branch() { # a small change built straight on main: nothing to merge
    setup || return
    fx opened_issue_12 Building noplan || return
    printf '%s\n' '#!/bin/sh' 'if [ "$1" = "--name" ]; then echo "Hello, $2!"; exit 0; fi' 'echo "Hello, ${1:-world}!"' > "$work/hello.sh" || return
    fx git -C "$work" commit -q -am 'Accept a --name option' || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" 'Your human partner approved a small change and asked you to build it directly on main: make hello.sh accept a --name option. It tracks https://github.com/acme/widgets/issues/12 (opened for this work). The change is committed on main, and bash test.sh passes. Use superpowers:finishing-a-development-branch. Your human partner has already chosen option 1, Merge back to main locally. '"$HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$work" finishing-a-development-branch
    check "after turn 1: main on the remote is unchanged" main_unchanged
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    check "after turn 1: asks about pushing" has_i "$OUT" 'push'
    continue_moment "$work" "$TURN" 'Yes, push main.'
    local local_main
    local_main="$(git -C "$work" rev-parse main)"
    check "remote main is local main" same_ref "$(bare_ref "$root" main)" "$local_main"
    check "a comment on #12 ends with the merged marker" named_ends_with issue comment 12 '<!-- superpowers:merged -->'
    check "that comment has the short sha" hasf "$(named_body_ending issue comment 12 '<!-- superpowers:merged -->')" "${local_main:0:7}"
    check "#12 is closed as completed" issue_state_is 12 stateReason COMPLETED
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "no pr close" num_is "$(gh_log_count pr close)" 0
    check "#12 status line is Merged in" starts "$(i_first 12)" '**Status:** Merged in'
    common_checks "$work"
}
```

In the fast file, add `[finishing-a-development-branch]='The Draft PR|Finishing'` to `EXPECT`, and:

```bash
echo "Test 6: Finishing's menus stay word for word (no Claude run)..."
F="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"
for line in '1. Merge back to <base-branch> locally' '2. Push and create a Pull Request' "3. Keep the branch as-is (I'll handle it later)" \
    '1. Push as new branch and create a Pull Request' "2. Keep as-is (I'll handle it later)"; do
    check "finishing's menu keeps: $line" grep -qxF -- "$line" "$F"
done
check "finishing names the draft option" grep -qF 'Mark the draft PR ready for review' "$F"
echo ""
```

Add the `full-pr` switch to `common_checks` in `tracking-fixtures.sh`, as its Produces line says.

- [ ] **Step 2: Run them to verify they fail (RED)**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: FAIL at Test 3 (finishing) and at Test 6's "names the draft option".

Run: `TRACKING_SCENARIOS='finish_menu_ready_dev finish_menu_draft_closed finish_option1_pushed finish_option3_paused finish_discard_confirmed finish_on_default_branch' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `finish_menu_ready_dev` FAILs (today's menu, or a question about the base); record every result.

- [ ] **Step 3: Add the pointers to `skills/finishing-a-development-branch/SKILL.md`**

End of Step 3 (after "…expensive to undo."):

```markdown
If this work tracks an issue, find its draft PR first, as
superpowers:tracking-work-in-issues says (The Draft PR): while one is
open, its base is the base branch, and you don't ask.
```

Step 4, directly before "Present the menu exactly as written":

```markdown
If this work tracks an issue and its draft PR is open, option 2 reads
`Mark the draft PR ready for review` (on a detached HEAD, option 1
does), and every other option keeps its text, as
superpowers:tracking-work-in-issues says (Finishing). With no open
draft, the menu is exactly as written.
```

Option 1, directly before "Once the merged result is green: clean up the worktree":

```markdown
If this work tracks an issue, once the merged result is green, ask
whether to push <base-branch> and update the issue as
superpowers:tracking-work-in-issues says (Finishing), before cleanup.
When that work was committed straight onto <base-branch>, there is
nothing to merge: start at that question.
```

Option 2, directly under its heading:

```markdown
If this work tracks an issue, run this option as
superpowers:tracking-work-in-issues says (Finishing): an open draft PR
gets the full description below and is marked ready, instead of a new
PR.
```

Option 3, after its Report line:

```markdown
If this work tracks an issue, post the paused milestone as
superpowers:tracking-work-in-issues says (Finishing).
```

Discard, after the confirmation block and before "Wait for that exact confirmation":

```markdown
If this work tracks an issue, the confirmation also lists the pushed
branch and the draft PR, and the discard closes them and updates the
issue as superpowers:tracking-work-in-issues says (Finishing).
```

Why the option 2 pointer comes before the push: a session must load the tracking skill before its first `gh` call there, so the call names the repo (part 1's notes: a bare `gh pr view` on this fork targets the upstream).

- [ ] **Step 4: Run them to verify they pass (GREEN), and the existing finishing tests**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: `PASS`.

Run: `TRACKING_SCENARIOS='finish_menu_ready_dev finish_menu_untracked finish_menu_draft_closed finish_option1_pushed finish_option3_paused finish_discard_confirmed finish_on_default_branch' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `PASS`, 7 scenarios.

Run: `bash tests/claude-code/test-workflow-handoffs.sh`
Expected: passes (Tests 1 and 4 read finishing).

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md tests/claude-code/tracking-fixtures.sh \
    tests/claude-code/test-tracking-wiring-integration.sh tests/claude-code/test-tracking-wiring.sh
git commit -m "feat(finishing): point to issue tracking for the base, the menu and every option"
```

The message body records the default-branch call (Calls Made 5) and each scenario's RED result.

---

### Task 6: Autopilot's main session opens, pushes between parts, posts, and readies the PR

**Files:**
- Modify: `skills/autopilot/SKILL.md` (`:84-86`; `:110`; after `:187`; `:206-216`; `:230`; `:270`; `:277-278`; `:315-316`; `:339`)
- Test: `tests/claude-code/test-tracking-wiring-integration.sh`, `tests/claude-code/test-tracking-wiring.sh` (Test 7; `EXPECT` entry)

**Interfaces:**
- Consumes: Task 1's helpers; Task 5's `common_checks <dir> full-pr`; part 1's `_write_spec`, `split_plan_docs`, `version_flag_docs`, `opened_issue_12`, `work_branch`, `push_work`, `draft_pr_13`, `task2_commit`.
- Produces (wiring file only): `AP_OPEN`, `draft_spec <work>`, `autopilot_run_dir <work> <parts> <current> [<finished>]`, `part_record <run> <N>`, `executor_report <DONE|BLOCKED> <wt> <run> <N> <last|not-last> [<blocker>]`, `help_commit <dir>`.

- [ ] **Step 1: Write the failing scenarios and checks**

Append `autopilot_spec_commit autopilot_after_part1 autopilot_blocker autopilot_step5_ready autopilot_one_part_pr` to `ALL_SCENARIOS`. Fixtures:

- `AP_OPEN='You are the main session of a superpowers:autopilot run that is already driving: load the superpowers:autopilot skill to follow its steps (this is not a new run).'`
- `draft_spec <work>`: `_write_spec <work>`, then appends `## Run notes` with the three bullets `- **Services:** none; the work needs none.`, `- **Checkpoints:** no.`, ``- **PRs:** one, from `version-flag` against `main`.``; not committed.
- `autopilot_run_dir <work> <parts> <current> [<finished>]`: creates `<work>/.superpowers/autopilot/version-flag/` and `<work>/.superpowers/autopilot/.gitignore` holding `*`; writes `state.md` as autopilot's format gives it: first line `# Autopilot run — spec: <work>/<SPEC_PATH>`; bullets ``Started on branch: `main` (the PR targets it)``, `Spec: <abs>`, `Index: <abs INDEX_PATH>` (parts 2) or `Plan: <abs PLAN_PATH>` (parts 1), `Builds: 1. Parts: <parts>.`; then `## Current` (`<current>`), `## Finished parts` (`<finished>` or `none`), `## Pending` (`none`), `## Run notes` (the three bullets above); writes `main-record.md` with `# Main session record` and `- Ruling: [routine] Services question skipped: the work needs none. Cost if wrong: none.`; prints the run folder.
- `part_record <run> <N>`: writes `<run>/part-<N>-record.md`: `# Part <N> record`, `- Ruling: [routine] Kept the greeting text as it is — the spec does not mention it — cost if wrong: none.`, `## Interfaces produced:`, `- none`.
- `executor_report <DONE|BLOCKED> <wt> <run> <N> <last|not-last> [<blocker>]`: prints executor-prompt.md's report block, filled: `Branch: version-flag`, `Worktree: <wt>`, `Last commit: <short HEAD of wt>`, `Ledger: <wt>/.superpowers/sdd/version-flag/progress.md`, `Record: <run>/part-<N>-record.md`, `Blocker:` only when given, `Built:` (part 1: `the VERSION file and ./hello.sh --version`; part 2: `./hello.sh --help`), `Tests: bash test.sh → PASS`, `Final review: clean` (DONE) or `not run` (BLOCKED), `Acceptance: n/a` (not-last) or `Acceptance: steps for a person: run ./hello.sh --version and see 1.0.0.` (last), `Rulings I made:` / `- none`, `Routine rulings: 1`, `Deferred minors: 0`.
- `help_commit <dir>`: makes `./hello.sh --help` print `usage: hello.sh [--version | --help | <name>]` and exit 0, and commits `Add --help text`; `bash test.sh` still passes.

```bash
# ---- autopilot ----
run_folder_has_state() { compgen -G "$work/.superpowers/autopilot/*/state.md" > /dev/null; }
# spec_committed alone passes for a spec that was never committed (git diff ignores untracked files)
spec_in_head() { git -C "$work" cat-file -e "HEAD:$SPEC_PATH"; }
ISSUE12_URL=https://github.com/acme/widgets/issues/12

scenario_autopilot_spec_commit() {
    setup || return
    fx draft_spec "$work" || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$AP_OPEN You are in step 2 for the request \"Add a --version flag to hello.sh\": you wrote the spec at $SPEC_PATH with its run notes, and it is not committed yet. The builder check came back with no questions for your human partner. In brainstorming's last round of questions, when you offered to track the work in an issue, they chose \"Open a new issue\". Carry on with step 2 as autopilot says, then stop before step 3."
    local body
    body="$(posted_body)"
    check "loaded autopilot" loaded "$work" autopilot
    check "one issue created" num_is "$(gh_log_count issue create)" 1
    check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
    check "body starts with the Planning status" test "$(first_line "$body")" = '**Status:** Planning'
    check "body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "body names the spec path" hasf "$body" "$SPEC_PATH"
    check "spec carries the issue line" spec_line_is '**Issue:** https://github.com/acme/widgets/issues/1 (opened for this work)'
    check "the spec is in HEAD" spec_in_head
    check "spec change is committed" spec_committed
    check "the run folder has a state.md" run_folder_has_state
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_autopilot_after_part1() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    fx task2_commit "$wt" || return
    local run
    fxv run autopilot_run_dir "$work" 2 "Step 4, part 1 of 2, sub-step 6: part 1's executor reported." || return
    fx part_record "$run" 1 || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$AP_OPEN The run folder is $run: read its state.md. In step 4, part 1's executor has just reported:

$(executor_report DONE "$wt" "$run" 1 not-last)

Carry on as autopilot says, and stop just before you would dispatch part 2's writer."
    check "loaded autopilot" loaded "$work" autopilot
    check "version-flag is on the remote at the worktree's HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "the PR is a draft" gh_log_has_flag pr create '--draft|-d'
    check "base is main" gh_log_has_flag pr create '--base|-B' main
    check "head is version-flag" gh_log_has_flag pr create '--head|-H' version-flag
    check "PR body closes #12" hasf "$(gh_log_body pr create)" 'Closes #12'
    check "a comment on #12 ends with the draft-pr marker" named_ends_with issue comment 12 '<!-- superpowers:draft-pr -->'
    check "a comment on #12 ends with the part-1-done marker" named_ends_with issue comment 12 '<!-- superpowers:part-1-done -->'
    check "#12 status line is the draft PR" test "$(i_first 12)" = '**Status:** Building: draft PR #13'
    check "no pr ready" num_is "$(gh_log_count pr ready)" 0
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_autopilot_blocker() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    local run
    fxv run autopilot_run_dir "$work" 2 "Step 4, part 1 of 2, sub-step 5: part 1's executor is running." || return
    fx part_record "$run" 1 || return
    run_moment "$work" "$TURN" "$AP_OPEN The run folder is $run: read its state.md. In step 4, part 1's executor has just reported:

$(executor_report BLOCKED "$wt" "$run" 1 not-last 'Task 2: the spec does not say whether --version prints to stdout or stderr, and the choice changes what users see. Only your human partner can decide.')

Carry on as autopilot says. $HEADLESS"
    check "loaded autopilot" loaded "$work" autopilot
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with a waiting marker" grep -qE '^<!-- superpowers:waiting-[0-9]{12} -->$' <<< "$(named_last_lines issue comment 12)"
    check "#12 status line is waiting" test "$(i_first 12)" = '**Status:** Waiting on a decision'
    check "asks about stdout" has_ei "$OUT" 'stdout|standard output'
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    common_checks "$work"
}

scenario_autopilot_step5_ready() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    fx push_work "$wt" || return
    fx draft_pr_13 main || return
    fx task2_commit "$wt" || return
    fx push_work "$wt" || return
    fx help_commit "$wt" || return
    local run
    fxv run autopilot_run_dir "$work" 2 "Step 4, part 2 of 2, sub-step 6: part 2's executor reported." "- Part 1: DONE. Branch version-flag, worktree $wt. Record part-1-record.md." || return
    fx part_record "$run" 1 || return
    fx part_record "$run" 2 || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$LONG" "$AP_OPEN The run folder is $run: read its state.md. Part 2, the last part, has just reported:

$(executor_report DONE "$wt" "$run" 2 last)

Carry on with steps 5 and 6 as autopilot says."
    check "loaded autopilot" loaded "$work" autopilot
    check "version-flag is on the remote at the worktree's HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "a pr edit on #13 whose body closes #12" named_body_has pr edit 13 'Closes #12'
    check "that body carries the records in <details>" named_body_has pr edit 13 '<details>'
    check "one pr ready" num_is "$(gh_log_count pr ready)" 1
    check "PR #13 is no longer a draft" pr_is_draft_false
    check "a comment on #12 ends with the pr-ready marker" named_ends_with issue comment 12 '<!-- superpowers:pr-ready -->'
    check "#12 status line is ready for review" test "$(i_first 12)" = '**Status:** Ready for review: PR #13'
    check "the summary gives the issue link" hasf "$OUT" "$ISSUE12_URL"
    check "the summary gives the PR link" hasf "$OUT" "$PR13"
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_autopilot_one_part_pr() { # no draft: the PR opens at step 5, already ready
    setup || return
    fx version_flag_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    fx task2_commit "$wt" || return
    local run
    fxv run autopilot_run_dir "$work" 1 "Step 4, part 1 of 1, sub-step 6: the executor reported." || return
    fx part_record "$run" 1 || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$LONG" "$AP_OPEN The run folder is $run: read its state.md. The plan has one part, and its executor has just reported:

$(executor_report DONE "$wt" "$run" 1 last)

Carry on with steps 5 and 6 as autopilot says."
    check "loaded autopilot" loaded "$work" autopilot
    check "version-flag is on the remote at the worktree's HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "it is not a draft" not gh_log_has_flag pr create '--draft|-d'
    check "its base is main" gh_log_has_flag pr create '--base|-B' main
    check "its body closes #12" hasf "$(gh_log_body pr create)" 'Closes #12'
    check "a comment on #12 ends with the pr-ready marker" named_ends_with issue comment 12 '<!-- superpowers:pr-ready -->'
    check "#12 status line is ready for review" test "$(i_first 12)" = '**Status:** Ready for review: PR #13'
    check "the summary gives the issue link" hasf "$OUT" "$ISSUE12_URL"
    check "the summary gives the PR link" hasf "$OUT" "$PR13"
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work" full-pr
}
```

In the fast file, add `[autopilot]='Opening the Issue|The Draft PR|Milestones|Finishing|Failures'` to `EXPECT`, and:

```bash
echo "Test 7: Autopilot's pushes and the issue (comprehension)..."
mkdir -p "$TEST_ROOT/t7"
run_moment "$TEST_ROOT/t7" "$T" "Read the superpowers:autopilot skill. A run tracks a GitHub issue, and its plan is split into 2 parts. Answer using exactly this structure:
Executors push or post: <yes, no, or not stated>
Main session pushes between parts: <yes, no, or not stated>
Draft PR opened after: <when, or not stated>
A between-part push is a blocker: <yes, no, or not stated>
Opening the issue when the spec is committed is a blocker: <yes, no, or not stated>
With a draft open, step 5 creates a new PR: <yes, no, or not stated>
Summary gives the issue link: <yes, no, or not stated>
$NS"
check "executors never push or post" has_ei "$OUT" 'Executors push or post:[^a-z]*no\b'
check "the main session pushes between parts" has_ei "$OUT" 'pushes between parts:[^a-z]*yes\b'
check "the draft opens after part 1" has_ei "$OUT" 'Draft PR opened after:.*part 1'
check "a between-part push is no blocker" has_ei "$OUT" 'between-part push is a blocker:[^a-z]*no\b'
check "opening the issue is no blocker" has_ei "$OUT" 'spec is committed is a blocker:[^a-z]*no\b'
check "step 5 marks the draft ready instead" has_ei "$OUT" 'step 5 creates a new PR:[^a-z]*no\b'
check "the summary gives the issue link" has_ei "$OUT" 'Summary gives the issue link:[^a-z]*yes\b'
check_isolation "$TEST_ROOT/t7"
echo ""
```

- [ ] **Step 2: Run them to verify they fail (RED)**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: FAIL at Test 3 (autopilot) and Test 7 (at least the between-part answers: today autopilot pushes once, at the end).

Run: `TRACKING_SCENARIOS='autopilot_spec_commit autopilot_after_part1 autopilot_blocker autopilot_step5_ready autopilot_one_part_pr' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `autopilot_after_part1` FAILs (no push, no draft between parts); record every result.

- [ ] **Step 3: Add the pointers to `skills/autopilot/SKILL.md`**

Step 1, the small-change bullet (84-86) gains a last sentence:

```markdown
If it tracks an issue, open it as that message goes out, as
superpowers:tracking-work-in-issues says (Opening the Issue).
```

Step 2, directly before "Commit the spec, then create the run folder" (110):

```markdown
If this work tracks an issue, open it as you commit the spec, as
superpowers:tracking-work-in-issues says (Opening the Issue): its
`**Issue:**` line goes in that commit.
```

Step 4, a new paragraph after "Between parts, post one status line … wait for "continue"." (184-187):

```markdown
If this work tracks an issue, after each part's DONE report push its
branch, open the draft PR after part 1, and post the part-done milestone
for every part but the last, as superpowers:tracking-work-in-issues says
(The Draft PR, Milestones). These pushes and posts are yours: an
executor never makes them.
```

Step 5, the "repo has a remote and a working CLI" bullet (206-216) gains a last sentence:

```markdown
If this work tracks an issue, do this as
superpowers:tracking-work-in-issues says (Finishing): an open draft PR
gets the body file as its description and is marked ready instead of a
new PR, and the body keeps `Closes #N` (or `Part of #N`).
```

Step 6 (230): "- the PR link, or why there is none," becomes:

```markdown
   - the PR link, or why there is none, with the issue link beside it when
     the run tracks one, and what the tracking could not post, as
     superpowers:tracking-work-in-issues says (Failures),
```

Blockers, after "Wait for the answer, then continue from where it stopped." (270), before "A blocker is:":

```markdown
If this work tracks an issue, post the waiting-on-you milestone before
you ask, and put the status back when the run resumes, as
superpowers:tracking-work-in-issues says (Milestones).
```

The blocker exception (277-278): "The one exception is step 5's feature-branch push and PR: they pre-authorized it by asking for autopilot." becomes:

```markdown
  every path is a guess. The exceptions are step 5's feature-branch push
  and PR and, when the run tracks an issue, step 4's pushes of that
  branch and its draft PR: your human partner pre-authorized them by
  asking for autopilot and saying yes to the issue. Asking for any
```

(rewrap the bullet; the rest of it is unchanged).

Fallback (315-316): "no finishing-a-development-branch and no push until step 5." becomes "no finishing-a-development-branch, and no push until step 5 beyond step 4's between-part pushes when the run tracks an issue."

Red flags (339): "Executors never push. Autopilot pushes once, at the end." becomes "Executors never push. Autopilot pushes at the end, and between parts when the run tracks an issue."

`skills/autopilot/executor-prompt.md` does not change (Test 2 and Task 7's diff check hold it).

- [ ] **Step 4: Run them to verify they pass (GREEN), and the existing autopilot tests**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: `PASS`.

Run: `TRACKING_SCENARIOS='autopilot_spec_commit autopilot_after_part1 autopilot_blocker autopilot_step5_ready autopilot_one_part_pr' TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `PASS`, 5 scenarios.

Run: `bash tests/claude-code/test-workflow-handoffs.sh`
Expected: passes (its Test 2 reads autopilot and the executor prompt).

- [ ] **Step 5: Commit**

```bash
git add skills/autopilot/SKILL.md tests/claude-code/test-tracking-wiring-integration.sh tests/claude-code/test-tracking-wiring.sh
git commit -m "feat(autopilot): the main session opens, pushes between parts and posts for a tracked run"
```

---

### Task 7: README, test registration, full runs, and the acceptance steps

**Files:**
- Modify: `README.md:361` (the Collaboration list)
- Modify: `tests/claude-code/run-skill-tests.sh` (help lines near `:67`; fast list after `:92`; integration list after `:100`)
- Test: `tests/claude-code/test-tracking-wiring.sh` (Test 8)

**Interfaces:**
- Consumes: every earlier task's tests.
- Produces: nothing later tasks use; the Acceptance steps go to your human partner.

- [ ] **Step 1: Write the failing README check**

```bash
echo "Test 8: The README lists the skill (no Claude run)..."
check "README lists tracking-work-in-issues" grep -qF -- '- **tracking-work-in-issues** - ' "$REPO_ROOT/README.md"
echo ""
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: FAIL, only at Test 8.

- [ ] **Step 3: Add the README line and register the tests**

In README's Collaboration list, after the finishing-a-development-branch line:

```markdown
- **tracking-work-in-issues** - One GitHub or GitLab issue per piece of work: offered while brainstorming, linked to a draft PR, kept current at each milestone, closed when the work lands
```

In `run-skill-tests.sh`, add `"test-tracking-wiring.sh"` to the fast list after `"test-tracking-public-repo.sh"`, `"test-tracking-wiring-integration.sh"` to the integration list after `"test-tracking-work-in-issues-integration.sh"`, and two help lines in the same style as their neighbours: `test-tracking-wiring.sh  workflow pointers to the tracking skill: static checks and two comprehension runs` and `test-tracking-wiring-integration.sh  each workflow skill reaches the tracking skill at its moment, against a stand-in gh (~26 scenarios; TRACKING_JOBS=4; use --timeout 7200)`.

- [ ] **Step 4: Run everything**

Run: `bash tests/claude-code/test-tracking-wiring.sh`
Expected: `PASS`.

Run: `git diff --stat 057ba52 HEAD -- skills/subagent-driven-development/implementer-prompt.md skills/subagent-driven-development/task-reviewer-prompt.md skills/subagent-driven-development/re-review-prompt.md skills/writing-plans/part-writer-prompt.md skills/writing-plans/cross-part-check-prompt.md skills/brainstorming/builder-check-prompt.md skills/autopilot/executor-prompt.md skills/requesting-code-review/code-reviewer.md`
Expected: no output: no subagent prompt changed on this branch.

Run: `bash tests/claude-code/run-skill-tests.sh > "$LOG" 2>&1`
Expected: every fast test passes except `test-subagent-driven-development.sh`, `test-writing-plans-split.sh` and `test-autopilot.sh` (Calls Made 10). Any other failure is a regression of this part.

Run: `TRACKING_JOBS=4 bash tests/claude-code/test-tracking-wiring-integration.sh > "$LOG" 2>&1`
Expected: `PASS`, 26 scenarios: each scenario's second passing run (the first was its task's GREEN).

Run: `TRACKING_JOBS=4 bash tests/claude-code/test-tracking-work-in-issues-integration.sh > "$LOG2" 2>&1`
Expected: `PASS`, 27 scenarios: part 1's moments still hold through the moved harness and the wired skills.

Run: `bash tests/claude-code/test-autopilot-integration.sh > "$LOG3" 2>&1`
Expected: passes: the default runs (no remote, a blocker) are autopilot with tracking impossible, which must behave exactly as before. If it fails, run the same file from a worktree of `057ba52` (`git worktree add <scratch dir> 057ba52`); a failure there too is pre-existing and recorded as a ruling with both outputs, otherwise it is a regression of this part.

- [ ] **Step 5: Commit, and ready the acceptance**

```bash
git add README.md tests/claude-code/run-skill-tests.sh tests/claude-code/test-tracking-wiring.sh
git commit -m "docs(readme): list tracking-work-in-issues; register the wiring tests"
```

Your final message (under autopilot, the report's `Acceptance:` line) gives your human partner the plan's Acceptance section: the setup, the four runs, what passing looks like, and the readability read. Nothing in this run calls a real forge.
