# Handover Prompts, Split Plans, and Autopilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** writing-plans ends with handover prompts and splits big plans at natural seams; brainstorming hands specs over with a "Where to focus" list; a new autopilot skill runs questions → spec → plan → per-part write-then-execute → PR.

**Architecture:** Small, local edits to the brainstorming, writing-plans, executing-plans and subagent-driven-development skills. New behavior lives in new files: `skills/autopilot/` and `skills/writing-plans/part-writer-prompt.md`. Every skill change is driven by a headless Claude Code test that loads this repo as the plugin.

**Tech Stack:** Markdown skills, bash test scripts (`tests/claude-code/`), Claude Code CLI (`claude -p --plugin-dir`).

**Spec:** `docs/superpowers/specs/2026-10-13-handover-split-autopilot-design.md`

## Global Constraints

- Changes stay in the `shellkah/superpowers` fork. No upstream PR.
- Keep base-skill edits small and local; put new behavior in new files (the spec's anti-goal on upstream-sync conflicts).
- Write skill text with superpowers:writing-skills, in the house voice: "your human partner", plain language, Red Flags tables. Where this plan gives exact text, use it verbatim; where it gives requirements, every requirement must be covered and the wording is yours.
- Skill name `autopilot`, invoked as `/superpowers:autopilot`. New files: `skills/autopilot/SKILL.md`, `skills/autopilot/executor-prompt.md`, `skills/writing-plans/part-writer-prompt.md`.
- File names: handover `docs/superpowers/plans/YYYY-MM-DD-<feature>.handover.md`; index `docs/superpowers/plans/YYYY-MM-DD-<feature>-index.md`; parts `docs/superpowers/plans/YYYY-MM-DD-<feature>-part-N-<name>.md`.
- Every test that asks Claude about a skill uses `run_claude_fork` (Task 1), never `run_claude`, which loads the installed official 6.4.1 plugin.
- Executors never push, merge, or publish. Only autopilot pushes, at the end: the feature branch, no force, then a regular (not draft) PR against the branch the work started from.

## Review Focus

1. **The official plugin shadows the fork in test runs**, so tests pass or fail against 6.4.1 text. Pinned by Task 1 Step 2 (the fork-loaded probe) and by `run_claude_fork` disabling the official plugin.
2. **Autopilot's push permission leaks to executors.** An executor must never push. Pinned in Task 4's test ("Executor may push: no").
3. **A part writer silently changes a cross-part interface.** Pinned in Task 2's test ("Writer may change index interfaces: no").
4. **Brainstorming's HARD-GATE still blocks under autopilot**, leaving the run stuck waiting for approval. Pinned by Task 6 scenario A (spec, plan and code all exist after one headless turn).
5. **Normal mode loses its playback chunks or its single spec review.** Pinned in Task 3's test ("Playback in normal mode: yes").

---

### Task 1: Fork test helper and handover prompts in writing-plans

**Files:**
- Modify: `tests/claude-code/test-helpers.sh` (add `run_claude_fork` before the `# Export functions` comment)
- Create: `tests/claude-code/test-writing-plans-handover.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (`tests=(...)` array)
- Modify: `skills/writing-plans/SKILL.md` (Plan Document Header blockquote line; the whole `## Execution Handoff` section)
- Modify: `skills/executing-plans/SKILL.md` (frontmatter `description`; first bullet of `## When to Use`)
- Modify: `skills/subagent-driven-development/SKILL.md` (`when_to_use` digraph node `"Partner chose inline, or no subagent tool?"` and its two edges)

**Interfaces:**
- Produces: `run_claude_fork "prompt" [timeout_seconds] [extra claude args...]`. It prints Claude's output and returns claude's exit code. Tasks 2–6 use it.
- Produces: the handover file layout and the handover prompt contents (Step 5). Tasks 2 and 4 refer to them.

- [ ] **Step 1: Add `run_claude_fork` to `tests/claude-code/test-helpers.sh`**

```bash
# Run Claude Code with this repo loaded as the superpowers plugin, with the
# installed official copy disabled so it cannot shadow the fork's skills.
# Usage: run_claude_fork "prompt text" [timeout_seconds] [extra claude args...]
run_claude_fork() {
    local prompt="$1"
    local timeout="${2:-120}"
    if [ $# -ge 2 ]; then shift 2; else shift $#; fi
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    timeout "$timeout" claude -p "$prompt" \
        --plugin-dir "$repo_root" \
        --settings '{"enabledPlugins":{"superpowers@claude-plugins-official":false}}' \
        "$@" 2>&1
}
```

- [ ] **Step 2: Verify the fork is the plugin that loads**

Run:
```bash
cd tests/claude-code && source test-helpers.sh && run_claude_fork "Load the superpowers:brainstorming skill and quote, word for word, the first sentence of its body text after the title. Output only that sentence." 180
```
Expected: `You are very good at building.` (the 7.0.0 text). If it prints `Help turn ideas into fully formed designs...`, the official 6.4.1 plugin is shadowing the fork. Stop and report it: every later test would be measuring the wrong skill.

- [ ] **Step 3: Write the failing test `tests/claude-code/test-writing-plans-handover.sh`**

```bash
#!/usr/bin/env bash
# Test: writing-plans ends with handover prompts instead of an execution question
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: writing-plans handover prompts ==="
echo ""

echo "Test 1: No execution question; handover file..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. After the plan is written and self-reviewed, does the agent ask its human partner which execution approach to use, and where are the handover prompts saved? Answer using exactly this structure:
Asks which approach: <yes or no>
Handover file: <path pattern>" "$T")
assert_contains "$output" "Asks which approach:.*no" "Does not ask for an execution approach" || exit 1
assert_contains "$output" "Handover file:.*\.handover\.md" "Handover prompts saved to .handover.md" || exit 1
echo ""

echo "Test 2: Non-last parts keep the branch open..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. In the handover prompt for a part that is not the last part, should the executor run superpowers:finishing-a-development-branch when its final review passes? Answer using exactly this structure:
Finish branch on a non-last part: <yes or no>" "$T")
assert_contains "$output" "Finish branch on a non-last part:.*no" "Non-last parts keep the branch open" || exit 1
echo ""

echo "Test 3: Closing message contents..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. Outside autopilot, list what the message that ends the planning session must contain, one item per line, each line starting with '- '." "$T")
assert_contains "$output" "Where to focus" "Closing message has Where to focus" || exit 1
assert_contains "$output" "handover prompt" "Closing message has a handover prompt" || exit 1
echo ""

echo "Test 4: executing-plans is named by the handover prompt..."
output=$(run_claude_fork "Read the superpowers:executing-plans skill's When to Use section. Besides having no subagent tool, what names this skill as the one to use? Answer using exactly this structure:
Named by: <what>" "$T")
assert_contains "$output" "Named by:.*handover" "executing-plans is named by the handover prompt" || exit 1
echo ""

echo "=== All writing-plans handover tests passed ==="
```

- [ ] **Step 4: Run it to verify it fails**

Run: `bash tests/claude-code/test-writing-plans-handover.sh`
Expected: FAIL at Test 1 (`Asks which approach: yes`, since the skill still asks).

- [ ] **Step 5: Rewrite `## Execution Handoff` in `skills/writing-plans/SKILL.md`**

Replace the whole section (from `## Execution Handoff` to the end of the file). Requirements:

1. After the plan (or every part) is written and self-reviewed, pick the recommended mode for each part with the existing criteria (how much the tasks depend on each other's interfaces, how many there are, what a shipped mistake would cost), with a one-sentence reason. A plan with no split is "part 1 of 1".
2. Never ask which mode to use. If your human partner already named a mode, put that mode in every prompt instead of the recommendation.
3. Write all handover prompts to one file, `docs/superpowers/plans/YYYY-MM-DD-<feature>.handover.md`, laid out exactly like this:

   ````markdown
   # Handover: <Feature Name>

   Spec: `<spec path>`

   ## Part 1 of M: <part name>

   ```text
   <the part 1 prompt>
   ```

   ## Part 2 of M: <part name>
   ...
   ````

4. Each handover prompt contains, in this order:
   - `Execute part N of M of the implementation plan at <plan path> (spec: <spec path>).`
   - `Use superpowers:<subagent-driven-development|executing-plans>. Why this mode: <one sentence>.`
   - split plans only: `Work on branch <branch from the index>.`
   - part 1: `Set up the workspace as the skill says.`
   - parts after part 1: continue on that branch in the worktree the previous part used; first check that part N-1 is complete (its tasks are checked off and its final review passed); if not, stop and say so.
   - every part except the last: `This is not the last part. When the final review passes, report and stop without running superpowers:finishing-a-development-branch; the next part continues on this branch.`
5. Outside autopilot, end the session with one message, laid out like this:

   ````markdown
   Plan complete: `<plan path or index path>`.

   **Where to focus** when you review it:
   1. <2–5 points, most important first: split boundaries, rulings on ambiguity, the Review Focus section, anything the spec left loose, part writers' open questions>

   **Handover:** recommended mode <mode>, because <reason>. Paste this into a fresh session once the plan looks right:

   ```text
   <part 1 prompt>
   ```

   The other parts' prompts are in `<handover path>`. Run them in order, each in a fresh session.
   ````

   Drop the last line when there is one part.
6. Under autopilot (superpowers:autopilot is driving), skip the message and return control to autopilot. With a split, writing-plans stops after the index (Task 2 adds the details); autopilot writes each part and appends its handover prompt as it goes.

In the Plan Document Header template, replace the blockquote line with exactly:

```markdown
> **For agentic workers:** REQUIRED SUB-SKILL: the handover prompt names which skill runs this plan, superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.
```

- [ ] **Step 6: Point the two executing skills at the handover prompt**

In `skills/executing-plans/SKILL.md`, set the frontmatter description to exactly:

```yaml
description: Use when executing an implementation plan in the current session as the implementer yourself — the handover prompt names this skill, your human partner chose inline execution, or no subagent tool is available
```

and replace the `## When to Use` bullet "You have a plan from superpowers:writing-plans and your human partner chose inline execution at the handoff." with:

```markdown
- You have a plan from superpowers:writing-plans and its handover prompt
  names this skill, or your human partner chose inline execution.
```

In `skills/subagent-driven-development/SKILL.md`, rename the `when_to_use` digraph node `"Partner chose inline, or no subagent tool?"` to `"Handover names executing-plans, partner chose inline, or no subagent tool?"` in its declaration and in both edges that use it.

- [ ] **Step 7: Run the test to verify it passes**

Run: `bash tests/claude-code/test-writing-plans-handover.sh`
Expected: `=== All writing-plans handover tests passed ===`

- [ ] **Step 8: Register the test and commit**

Add `"test-writing-plans-handover.sh"` to the `tests=(...)` array in `tests/claude-code/run-skill-tests.sh`, after `"test-subagent-driven-development.sh"`.

```bash
git add tests/claude-code/test-helpers.sh tests/claude-code/test-writing-plans-handover.sh tests/claude-code/run-skill-tests.sh skills/writing-plans/SKILL.md skills/executing-plans/SKILL.md skills/subagent-driven-development/SKILL.md
git commit -m "feat(writing-plans): end with handover prompts instead of an execution question"
```

---

### Task 2: Splitting the plan at natural seams

**Files:**
- Create: `tests/claude-code/test-writing-plans-split.sh`
- Create: `skills/writing-plans/part-writer-prompt.md`
- Modify: `skills/writing-plans/SKILL.md` (new `## Splitting the Plan` section directly after `## Scope Check`)
- Modify: `tests/claude-code/run-skill-tests.sh` (`tests=(...)` array)

**Interfaces:**
- Consumes: `run_claude_fork` (Task 1); the handover file layout and prompt contents (Task 1, Step 5).
- Produces: the index layout (Step 3); `part-writer-prompt.md` with placeholders `[SPEC_PATH]`, `[INDEX_PATH]`, `[PART_NUMBER]`, `[PART_COUNT]`, `[EARLIER_PART_PATHS]`, `[WORKTREE_PATH]`, `[OUTPUT_PATH]`, and the writer's report format (Step 4). Task 4's autopilot dispatches this template and reads this report.

- [ ] **Step 1: Write the failing test `tests/claude-code/test-writing-plans-split.sh`**

```bash
#!/usr/bin/env bash
# Test: writing-plans splits big plans at natural seams, with one writer per part
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: writing-plans splitting ==="
echo ""

echo "Test 1: Related tasks stay together; 8 is not a cap..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. A spec needs ten tasks that all build on each other's internals, with no natural seam. How many plan parts should there be, is 8 tasks a hard cap, and may a plan end with a 2-task part that belongs with its neighbor? Answer using exactly this structure:
Parts: <number>
Hard cap at 8: <yes or no>
Stub part allowed: <yes or no>" "$T")
assert_contains "$output" "Parts:[^0-9]*1\([^0-9]\|$\)" "Ten related tasks stay in one part" || exit 1
assert_contains "$output" "Hard cap at 8:.*no" "8 is a guide, not a cap" || exit 1
assert_contains "$output" "Stub part allowed:.*no" "No stub parts" || exit 1
echo ""

echo "Test 2: Index first, one writer subagent per part, pinned interfaces..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. When a plan is split, what file does the main session write before any part, who writes each part, and may a part writer change the cross-part interfaces the index pins? Answer using exactly this structure:
First file: <path pattern>
Part author: <who>
Writer may change index interfaces: <yes or no>" "$T")
assert_contains "$output" "First file:.*-index\.md" "Index is written first" || exit 1
assert_contains "$output" "Part author:.*subagent" "A subagent writes each part" || exit 1
assert_contains "$output" "Writer may change index interfaces:.*no" "Writers cannot change pinned interfaces" || exit 1
echo ""

echo "Test 3: When parts get written..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. Outside autopilot, are all parts of a split plan written before any part executes? Under autopilot? Answer using exactly this structure:
All parts up front outside autopilot: <yes or no>
All parts up front under autopilot: <yes or no>" "$T")
assert_contains "$output" "All parts up front outside autopilot:.*yes" "Normal mode writes every part up front" || exit 1
assert_contains "$output" "All parts up front under autopilot:.*no" "Autopilot writes parts one at a time" || exit 1
echo ""

echo "=== All writing-plans split tests passed ==="
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-writing-plans-split.sh`
Expected: FAIL at Test 2 (`First file:` has no `-index.md`; the skill has no index yet).

- [ ] **Step 3: Add `## Splitting the Plan` to `skills/writing-plans/SKILL.md`, directly after `## Scope Check`**

Requirements:

1. **Deciding.** After reading the spec and before writing tasks, sketch the tasks with the Task Right-Sizing rules and look at the nature of what is being built. Split at natural seams, not at a count:
   - a seam is where the tests pass, the work so far is usable on its own, and few interfaces cross it (a subsystem, a layer that stands alone, a milestone a person could try);
   - tightly related tasks stay in the same part: ten tasks that build on each other's internals are one part, not 8 + 2;
   - never leave a stub part of one or two tasks that belongs with its neighbor: fold it in;
   - each part depends only on earlier parts.
2. Around 8 tasks is where splitting starts to pay off. It is a guide, not a cap. No natural seam means one plan. A very large plan with no clean seam is split at the seam with the fewest crossing interfaces.
3. Decide without asking, and announce the split in one line with the reason, e.g. "3 parts: storage, sync engine, UI. Each one works on its own." With no split, write one plan in this session, as today.
4. **The index.** For a split plan, the main session writes `docs/superpowers/plans/YYYY-MM-DD-<feature>-index.md` itself, before any part, with exactly these sections:

   ```markdown
   # <Feature Name> Plan Index

   **Goal:** <one sentence>
   **Spec:** `<spec path>`
   **Branch:** `<feature slug>` (every part works on this branch)

   ## Global Constraints
   <from the spec, one line each, shared by all parts>

   ## Parts

   | Part | Name | Deliverable | Tasks (rough) | Depends on |
   |------|------|-------------|---------------|------------|

   ## Cross-Part Interfaces

   ### Part 1 produces
   - `<exact name and signature>`: <what later parts use it for>
   ```

   Part writers may not change Cross-Part Interfaces. Under autopilot the code can overrule them (requirement 6); then the main session updates the index.
5. **When parts are written.** Normal mode: all parts up front in this session, in order, so your human partner can review the whole plan before anything runs. Under autopilot: writing-plans writes only the index and returns; autopilot writes each part just before executing it.
6. **Writing a part.** Dispatch one fresh subagent per part on the most capable model available, with `part-writer-prompt.md`. Part files go to `docs/superpowers/plans/YYYY-MM-DD-<feature>-part-N-<name>.md` (the feature in the name keeps subagent-driven-development workspace slugs from colliding). Each part file uses the standard Plan Document Header, plus this line directly under the title: `**Part N of M** · Index: \`<index path>\``.
7. **Cross-part check**, after all parts (normal mode) or after each part (autopilot): every part's Interfaces blocks match the index; every spec requirement maps to a task in a written part, or (under autopilot) to a later part in the index. Fix small mismatches yourself; re-dispatch the writer for a part that is badly off.
8. **Writer questions.** Normal mode: settle what you can, record each as a call you made, and bring the rest to your human partner under "Where to focus". Under autopilot, a question only they can answer is a blocker for autopilot to ask.
9. **No subagent tool:** write the parts yourself, one at a time, and re-read the index before each.

- [ ] **Step 4: Create `skills/writing-plans/part-writer-prompt.md`**

Follow the shape of `skills/brainstorming/builder-check-prompt.md`: one line on when to dispatch it, then the prompt in a fenced block with bracketed placeholders. The prompt must:

1. Name the inputs: `[SPEC_PATH]`, `[INDEX_PATH]`, part `[PART_NUMBER]` of `[PART_COUNT]`, `[EARLIER_PART_PATHS]` (read only their Interfaces blocks), `[WORKTREE_PATH]` (the code earlier parts produced, or `none`), `[OUTPUT_PATH]`.
2. Tell the writer to read and follow superpowers:writing-plans for its part only, including the Self-Review, with the `**Part N of M**` header line.
3. Forbid changing the index's Cross-Part Interfaces. If `[WORKTREE_PATH]` is not `none` and the code disagrees with the index, plan against the code and report the difference.
4. Forbid guessing on a question that changes what gets built. Report it instead.
5. Require exactly this report:

   ```text
   Part file: <path>
   Tasks: <count>
   Interface differences from index: <none, or one line each: index says X, code has Y>
   Open questions: <none, or ranked, each with why the answer changes what gets built>
   ```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/claude-code/test-writing-plans-split.sh`
Expected: `=== All writing-plans split tests passed ===`

- [ ] **Step 6: Re-run Task 1's test, then register and commit**

Run: `bash tests/claude-code/test-writing-plans-handover.sh`
Expected: `=== All writing-plans handover tests passed ===`

Add `"test-writing-plans-split.sh"` to the `tests=(...)` array after `"test-writing-plans-handover.sh"`.

```bash
git add skills/writing-plans/SKILL.md skills/writing-plans/part-writer-prompt.md tests/claude-code/test-writing-plans-split.sh tests/claude-code/run-skill-tests.sh
git commit -m "feat(writing-plans): split big plans at natural seams, one writer subagent per part"
```

---

### Task 3: Brainstorming hand-over and autopilot hooks

**Files:**
- Create: `tests/claude-code/test-brainstorming-focus.sh`
- Modify: `skills/brainstorming/SKILL.md` (end of `## First: What Do You Actually Know?`; the hand-over sentence in `## The Written Design`; the exceptions paragraph in `<HARD-GATE>`)
- Modify: `tests/claude-code/run-skill-tests.sh` (`tests=(...)` array)

**Interfaces:**
- Consumes: `run_claude_fork` (Task 1).
- Produces: brainstorming defers to `superpowers:autopilot` (built in Task 4) and allows its pre-approval.

- [ ] **Step 1: Write the failing test `tests/claude-code/test-brainstorming-focus.sh`**

```bash
#!/usr/bin/env bash
# Test: brainstorming hands over with "Where to focus" and defers to autopilot
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: brainstorming focus and autopilot hooks ==="
echo ""

echo "Test 1: Where to focus list..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. When handing over the written design for review, what list goes with it, and at most how many items does it have? Answer using exactly this structure:
List: <name>
Max items: <number>" "$T")
assert_contains "$output" "List:.*Where to focus" "Hand-over carries a Where to focus list" || exit 1
assert_contains "$output" "Max items:[^0-9]*5\([^0-9]\|$\)" "At most five items" || exit 1
echo ""

echo "Test 2: Autopilot takes over fully automated runs..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. If your human partner asks for a fully automated run, which skill drives the work? Answer using exactly this structure:
Skill: <name>" "$T")
assert_contains "$output" "Skill:.*autopilot" "Fully automated runs go to autopilot" || exit 1
echo ""

echo "Test 3: Approval and playback under autopilot vs normal mode..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Under autopilot, does the request for a fully automated run count as approval of the written design, and only after what? Are playback chunks used under autopilot? In normal mode? Answer using exactly this structure:
Counts as approval: <yes or no>
Only after: <condition>
Playback under autopilot: <yes or no>
Playback in normal mode: <yes or no>" "$T")
assert_contains "$output" "Counts as approval:.*yes" "Autopilot request approves the design" || exit 1
assert_contains "$output" "Only after:.*\(builder\|theirs\)" "Only after the builder check's questions" || exit 1
assert_contains "$output" "Playback under autopilot:.*no" "No playback under autopilot" || exit 1
assert_contains "$output" "Playback in normal mode:.*yes" "Playback stays in normal mode" || exit 1
echo ""

echo "=== All brainstorming focus tests passed ==="
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-brainstorming-focus.sh`
Expected: FAIL at Test 1 (no "Where to focus" list yet).

- [ ] **Step 3: Edit `skills/brainstorming/SKILL.md`**

a) Append this paragraph at the end of `## First: What Do You Actually Know?`, after its two bullets:

```markdown
**Fully automated?** If they asked for a fully automated run ("fully
automated", "autopilot") and superpowers:autopilot isn't driving yet,
invoke it now; it brings you back here. Under autopilot, ask your
questions as usual but skip the playback chunks.
```

b) In `## The Written Design`, replace the sentence "Update the document with their answers, then hand it over with a short list of the calls you made so they can check those while reading." with:

```markdown
Update the document with their answers, then hand it over with a **Where
to focus** list: the calls you made and the places where a misreading
would cost the most, most important first, at most five items. Ask for
one review of the whole document, not approval section by section.
```

c) In `<HARD-GATE>`, change "Two exceptions." to "Three exceptions." and add this paragraph after the spike sentence ("...comes back through this gate."):

```markdown
Under autopilot (superpowers:autopilot), the request for a fully
automated run is their approval of the written document, once the
builder check's "theirs" questions are answered. Ask those first; they
are the one stop autopilot keeps here.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/claude-code/test-brainstorming-focus.sh`
Expected: `=== All brainstorming focus tests passed ===`

- [ ] **Step 5: Register and commit**

Add `"test-brainstorming-focus.sh"` to the `tests=(...)` array after `"test-writing-plans-split.sh"`.

```bash
git add skills/brainstorming/SKILL.md tests/claude-code/test-brainstorming-focus.sh tests/claude-code/run-skill-tests.sh
git commit -m "feat(brainstorming): hand over with Where to focus; defer to autopilot"
```

---

### Task 4: The autopilot skill

**Files:**
- Create: `tests/claude-code/test-autopilot.sh`
- Create: `skills/autopilot/SKILL.md`
- Create: `skills/autopilot/executor-prompt.md`
- Modify: `README.md` (`## The Basic Workflow` step 3; skills list under `**Collaboration**`)
- Modify: `tests/claude-code/run-skill-tests.sh` (`tests=(...)` array)

**Interfaces:**
- Consumes: `run_claude_fork` (Task 1); the handover prompt contents (Task 1, Step 5); the index layout, `part-writer-prompt.md` placeholders and writer report (Task 2, Steps 3–4); brainstorming's autopilot hooks (Task 3).
- Produces: `executor-prompt.md` with placeholders `[HANDOVER_PROMPT]`, `[BRANCH]`, `[WORKTREE_PATH]`, and the executor's report format (Step 4).

- [ ] **Step 1: Write the failing test `tests/claude-code/test-autopilot.sh`**

```bash
#!/usr/bin/env bash
# Test: autopilot triggers on "fully automated" and follows its flow and limits
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: autopilot skill ==="
echo ""

echo "Test 1: Trigger..."
output=$(run_claude_fork "Do not start any work. Which superpowers skill applies first when a user says: 'Build me a URL shortener, fully automated'? Answer using exactly this structure:
Skill: <name>" "$T")
assert_contains "$output" "Skill:.*autopilot" "Fully automated triggers autopilot" || exit 1
echo ""

echo "Test 2: Flow..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Asks brainstorming questions: <yes or no>
Playback chunks: <yes or no>
Stops for spec review: <yes or no>
Part 2 written before part 1 executes: <yes or no>" "$T")
assert_contains "$output" "Asks brainstorming questions:.*yes" "Questions still happen" || exit 1
assert_contains "$output" "Playback chunks:.*no" "No playback chunks" || exit 1
assert_contains "$output" "Stops for spec review:.*no" "No spec review stop" || exit 1
assert_contains "$output" "Part 2 written before part 1 executes:.*no" "Write-then-execute per part" || exit 1
echo ""

echo "Test 3: Ending..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. At the end of a run, when the repo has a remote and a logged-in CLI for its host, answer using exactly this structure:
Merges: <yes or no>
Opens PR: <yes or no>
Draft PR: <yes or no>
Force push: <yes or no>
No remote is a blocker: <yes or no>" "$T")
assert_contains "$output" "Merges:.*no" "Never merges" || exit 1
assert_contains "$output" "Opens PR:.*yes" "Opens a PR" || exit 1
assert_contains "$output" "Draft PR:.*no" "Regular PR, not a draft" || exit 1
assert_contains "$output" "Force push:.*no" "Never force-pushes" || exit 1
assert_contains "$output" "No remote is a blocker:.*no" "No remote is not a blocker" || exit 1
echo ""

echo "Test 4: Blockers and executor limits..."
output=$(run_claude_fork "Read the superpowers:autopilot skill and its executor prompt. An executor subagent finds the deploy step needs credentials it does not have. Separately: may an executor subagent push? Answer using exactly this structure:
Missing credentials: <stop and ask, or rule and continue>
Executor may push: <yes or no>" "$T")
assert_contains "$output" "Missing credentials:.*stop and ask" "Missing credentials is a blocker" || exit 1
assert_contains "$output" "Executor may push:.*no" "Executors never push" || exit 1
echo ""

echo "=== All autopilot tests passed ==="
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-autopilot.sh`
Expected: FAIL at Test 1 (no autopilot skill exists).

- [ ] **Step 3: Create `skills/autopilot/SKILL.md`**

Frontmatter, exactly:

```yaml
---
name: autopilot
description: Use when your human partner asks for a fully automated run ("fully automated", "autopilot", or /superpowers:autopilot) - asks the brainstorming questions, then writes the spec and plan, executes every part, and opens a PR, stopping only for blockers
---
```

The body must cover, in this order (spec section 4 is the reference):

1. What it is: your human partner answers the questions, then comes back to finished work. Questions still happen; review stops don't; blockers always stop.
2. **Flow**, numbered:
   1. Brainstorm with superpowers:brainstorming: questions as usual, no playback chunks. If they opt out of questions, write the spec from the request alone. Sizes: quick, clear task → do it; small change → describe it in chat in one message (no question) and build it through the normal workflow without waiting; project → continue.
   2. Spec: write it, run the builder check. "Theirs" questions are a blocker: ask, update the spec, continue. Commit the spec. No review stop.
   3. Split: run superpowers:writing-plans. No split → it writes the one plan and its handover prompt. Split → it writes only the index. No review stop.
   4. Write, then execute, one part at a time. No split: skip to the executor. Otherwise, for each part in order: dispatch the part writer (`../writing-plans/part-writer-prompt.md`, with `[WORKTREE_PATH]` set from the previous executor's report, `none` for part 1); run the cross-part check; update the index if the code changed an interface; append the part's handover prompt to the handover file. Then dispatch a fresh executor subagent on the most capable model available with `executor-prompt.md`. Between parts, post one status line ("Part 1 of 3 done: ...") and move on without asking.
   5. Open a PR: run superpowers:finishing-a-development-branch and take "Push and create a Pull Request" without asking, when the repo has a remote and a working CLI for its host (e.g. `gh auth status` succeeds for GitHub). Push only the feature branch, never with force. Open a regular PR, not a draft, against the branch the work started from. Follow the repo's PR template and conventions; put the summary in the description. No remote or no working CLI → take "Keep as-is" and say why there is no PR. Not a blocker.
   6. Summarize in one message: the PR link (or why there is none), what was built per part, tests and final-review outcomes, every ruling made without your human partner (from the executors' "Rulings I made"), what was parked, where the work lives (branch, worktree).
3. **Blockers** (stop at any stage, ask, continue from where it stopped): a builder-check question only they can answer; a part writer's open question only they can answer; the executor skills' four stop conditions (irreversible or destructive operation, security-sensitive action, an outside side effect such as a push or publish, a plan so broken every path is a guess), with the one exception of step 5's feature-branch push and PR, which they pre-authorized by asking for autopilot; an environment problem the agent cannot fix (missing credentials, a login, a service that is down); anything where a wrong guess would be expensive to undo. Everything else is a ruling: decide it, record it, keep going.
4. **Resuming after a blocker:** relay the question, wait for the answer, continue the same executor with it (SendMessage in Claude Code). If it can't be resumed, dispatch a fresh executor with the same handover prompt plus the answer; the ledger lets it pick up where the last one stopped.
5. **Fallback:** with no subagent tool, run each part's handover prompt in this session with superpowers:executing-plans, part by part.
6. **Red Flags** table with at least these rows:

   | Thought | Reality |
   |---------|---------|
   | "It's automated, so I'll skip the questions." | Questions still happen. Only the review stops go away. |
   | "I'll guess so I don't interrupt them." | A blocker is a question. Ask it. |
   | "The PR is green, I'll merge it." | Autopilot ends at an open PR. It never merges. |
   | "I'll plan all the parts now and save time." | Under autopilot, each part is written after the previous one runs, against the real code. |
   | "The ruling was small, I'll leave it out of the summary." | Every ruling goes in the summary. |

- [ ] **Step 4: Create `skills/autopilot/executor-prompt.md`**

Same shape as `part-writer-prompt.md`. The prompt must:

1. Start with `[HANDOVER_PROMPT]` verbatim, then add: you are running unattended for your human partner; the work is on `[BRANCH]` in `[WORKTREE_PATH]` (`none` for part 1, which sets up the workspace as the skill says).
2. Say: follow the named skill; with superpowers:subagent-driven-development you dispatch your own implementers and reviewers.
3. Say: never run superpowers:finishing-a-development-branch, and never push, merge, or publish; autopilot opens the PR at the end.
4. Say: on any of the skill's stop conditions, or anything only your human partner can answer, stop and report BLOCKED; don't guess.
5. Require exactly this report:

   ```text
   Status: DONE | BLOCKED
   Branch: <name>
   Worktree: <path>
   Last commit: <sha>
   Blocker: <what blocked you and what you need; BLOCKED only>
   Built: <what this part built>
   Tests: <command and result>
   Final review: <outcome>
   Rulings I made:
   - <every ruling from the ledger, with what it costs if wrong>
   ```

- [ ] **Step 5: Update `README.md`**

In `## The Basic Workflow`, step 3 (**writing-plans**), append: "Big plans are split into parts at natural seams, each written by a fresh subagent. It ends with a paste-ready handover prompt for the next session that names the recommended execution skill." Under `**Collaboration**`, add after the `writing-plans` line:

```markdown
- **autopilot** - Fully automated runs: questions first, then spec, plan, execution part by part, and an open PR
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash tests/claude-code/test-autopilot.sh`
Expected: `=== All autopilot tests passed ===`

- [ ] **Step 7: Register and commit**

Add `"test-autopilot.sh"` to the `tests=(...)` array after `"test-brainstorming-focus.sh"`.

```bash
git add skills/autopilot/ tests/claude-code/test-autopilot.sh tests/claude-code/run-skill-tests.sh README.md
git commit -m "feat(autopilot): add fully automated questions-to-PR skill"
```

---

### Task 5: writing-plans integration scenarios

**Files:**
- Modify: `tests/claude-code/test-helpers.sh` (add `new_repo` and `latest_transcript` after `run_claude_fork`)
- Create: `tests/claude-code/test-writing-plans-integration.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (`integration_tests=(...)` array; `--help` text)

**Interfaces:**
- Consumes: `run_claude_fork` (Task 1); the handover, index and part file names (Global Constraints).
- Produces: `new_repo` (prints the path of a fresh git repo on `main` with one empty commit and `docs/superpowers/specs/`) and `latest_transcript DIR` (prints the newest session JSONL for a Claude run whose cwd was DIR, or nothing). Task 6 uses both.

- [ ] **Step 1: Add `new_repo` and `latest_transcript` to `tests/claude-code/test-helpers.sh`, after `run_claude_fork`**

```bash
# Create a fresh git repo on main with one empty commit and a specs directory
# Usage: dir=$(new_repo)
new_repo() {
    local dir
    dir=$(create_test_project)
    git -C "$dir" init -q -b main
    git -C "$dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    mkdir -p "$dir/docs/superpowers/specs"
    echo "$dir"
}

# Print the newest session transcript for a Claude run whose cwd was DIR.
# Claude names the project directory by replacing every non-alphanumeric
# character of the real cwd path with "-".
# Usage: transcript=$(latest_transcript "$dir")
latest_transcript() {
    local real
    real=$(cd "$1" && pwd -P)
    ls -t "$HOME/.claude/projects/$(echo "$real" | sed 's|[^a-zA-Z0-9]|-|g')"/*.jsonl 2>/dev/null | head -1 || true
}
```

- [ ] **Step 2: Write `tests/claude-code/test-writing-plans-integration.sh`**

```bash
#!/usr/bin/env bash
# Integration: writing-plans produces handover files, and splits a 3-subsystem spec
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Scenario 1: small spec, one plan, handover instead of a question ==="
P1=$(new_repo)
cat > "$P1/docs/superpowers/specs/2026-01-01-wordcount-design.md" <<'EOF'
# wordcount

A bash script `wc.sh FILE` that prints the number of words in FILE, and
exits 1 with "usage: wc.sh FILE" on stderr when FILE is missing or
unreadable. A `test.sh` script checks both behaviors and exits non-zero
on failure. No other features.
EOF
output=$(cd "$P1" && run_claude_fork "Use superpowers:writing-plans to write the implementation plan for docs/superpowers/specs/2026-01-01-wordcount-design.md. The spec is approved." 900 --permission-mode bypassPermissions) \
    || { echo "  [FAIL] claude run failed or timed out"; exit 1; }
[ "$(ls "$P1"/docs/superpowers/plans/*.handover.md 2>/dev/null | wc -l)" -eq 1 ] \
    && echo "  [PASS] One handover file" || { echo "  [FAIL] Expected one .handover.md"; echo "$output"; exit 1; }
grep -q "superpowers:\(subagent-driven-development\|executing-plans\)" "$P1"/docs/superpowers/plans/*.handover.md \
    && echo "  [PASS] Handover names an execution skill" || { echo "  [FAIL] Handover names no skill"; exit 1; }
[ "$(ls "$P1"/docs/superpowers/plans/*-index.md 2>/dev/null | wc -l)" -eq 0 ] \
    && echo "  [PASS] No split for a small spec" || { echo "  [FAIL] Small spec was split"; exit 1; }
assert_contains "$output" "Where to focus" "Closing message has Where to focus" || exit 1
cleanup_test_project "$P1"

echo ""
echo "=== Scenario 2: three-subsystem spec is split, one writer per part ==="
P2=$(new_repo)
cat > "$P2/docs/superpowers/specs/2026-01-01-notes-design.md" <<'EOF'
# notes

A Python 3.11 command-line notes tool, `notes`, built from three
subsystems. Each one must work and be tested on its own before the next
is built on it.

1. Storage: notes are records {id, title, body, tags, created, updated}
   kept in one JSON file with a schema version field. Add, get, update,
   delete, and list with tag filtering. Writes are atomic (temp file then
   rename). A file with an unknown schema version is refused with a clear
   error.
2. Search: a tokenizer (lowercase, strip punctuation, drop stop words),
   an inverted index persisted next to the JSON file and rebuilt when it
   is missing or stale, and ranked queries (term frequency, title matches
   weigh double) with `notes search QUERY`.
3. Export: `notes export --format md|html DEST` writes one file per note.
   HTML output escapes all note content. Exported file names are slugs of
   the titles, de-duplicated with -2, -3 suffixes.

The CLI uses argparse with subcommands add, show, edit, rm, ls, search,
export. Tests use pytest.
EOF
output=$(cd "$P2" && run_claude_fork "Use superpowers:writing-plans to write the implementation plan for docs/superpowers/specs/2026-01-01-notes-design.md. The spec is approved." 2400 --permission-mode bypassPermissions) \
    || { echo "  [FAIL] claude run failed or timed out"; exit 1; }
plans="$P2/docs/superpowers/plans"
[ "$(ls "$plans"/*-index.md 2>/dev/null | wc -l)" -eq 1 ] \
    && echo "  [PASS] Index written" || { echo "  [FAIL] No index"; echo "$output"; exit 1; }
parts=$(ls "$plans"/*-part-*.md 2>/dev/null | grep -vc '\.handover\.md$' || true)
[ "$parts" -ge 2 ] && echo "  [PASS] $parts part files" || { echo "  [FAIL] Expected >=2 part files, got $parts"; exit 1; }
sections=$(grep -c '^## Part [0-9]' "$plans"/*.handover.md || true)
[ "$sections" -eq "$parts" ] && echo "  [PASS] One handover section per part" || { echo "  [FAIL] $sections handover sections for $parts parts"; exit 1; }
transcript=$(latest_transcript "$P2")
[ -n "$transcript" ] || { echo "  [FAIL] No session transcript found"; exit 1; }
dispatches=$(grep -o '"name":"\(Agent\|Task\)"' "$transcript" | wc -l || true)
[ "$dispatches" -ge "$parts" ] && echo "  [PASS] $dispatches subagent dispatches" || { echo "  [FAIL] $dispatches dispatches for $parts parts"; exit 1; }
cleanup_test_project "$P2"

echo ""
echo "=== writing-plans integration passed ==="
```

- [ ] **Step 3: Run it**

Run: `bash tests/claude-code/test-writing-plans-integration.sh`
Expected: `=== writing-plans integration passed ===` (this takes up to about 55 minutes). A failure here is a skill-text problem in Tasks 1–2: fix the skill, not the test, then re-run.

- [ ] **Step 4: Register and commit**

Add `"test-writing-plans-integration.sh"` to `integration_tests=(...)` in `tests/claude-code/run-skill-tests.sh`, and add it to the `--help` "Integration Tests" list.

```bash
git add tests/claude-code/test-helpers.sh tests/claude-code/test-writing-plans-integration.sh tests/claude-code/run-skill-tests.sh
git commit -m "test: writing-plans handover and split integration scenarios"
```

---

### Task 6: Autopilot integration scenarios and full run

**Files:**
- Create: `tests/claude-code/test-autopilot-integration.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (`integration_tests=(...)` array; `--help` text)

**Interfaces:**
- Consumes: `run_claude_fork` (Task 1); `new_repo` and `latest_transcript` from `test-helpers.sh` (Task 5).

- [ ] **Step 1: Write `tests/claude-code/test-autopilot-integration.sh`**

Scenario B is long (a multi-part run) and runs only with `RUN_SPLIT=1`.

```bash
#!/usr/bin/env bash
# Integration: autopilot end to end with no remote, a two-part run, and a blocker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Scenario A: no remote, full run, branch kept ==="
PA=$(new_repo)
output=$(cd "$PA" && run_claude_fork "/superpowers:autopilot Build a bash todo CLI, todo.sh, with add, list and done commands, storing items in todo.txt next to the script, plus test.sh that exercises all three commands. Treat this as a project with a written design. I have nothing more to add, so skip the questions. Fully automated." 3600 --permission-mode bypassPermissions) \
    || { echo "  [FAIL] claude run failed or timed out"; exit 1; }
ls "$PA"/docs/superpowers/specs/*.md >/dev/null 2>&1 && echo "  [PASS] Spec written" || { echo "  [FAIL] No spec"; echo "$output"; exit 1; }
ls "$PA"/docs/superpowers/plans/*.handover.md >/dev/null 2>&1 && echo "  [PASS] Handover written" || { echo "  [FAIL] No handover"; exit 1; }
[ -n "$(git -C "$PA" log --all --format=%H -- todo.sh)" ] && echo "  [PASS] todo.sh committed" || { echo "  [FAIL] todo.sh never committed"; exit 1; }
git -C "$PA" cat-file -e main:todo.sh 2>/dev/null && { echo "  [FAIL] Merged into main"; exit 1; } || echo "  [PASS] Not merged into main"
[ -z "$(git -C "$PA" remote)" ] && echo "  [PASS] Still no remote" || { echo "  [FAIL] A remote appeared"; exit 1; }
assert_contains "$output" "no PR\|no pull request\|no remote" "Summary says why there is no PR" || exit 1
transcript=$(latest_transcript "$PA")
[ -n "$transcript" ] || { echo "  [FAIL] No session transcript found"; exit 1; }
grep -q '"command":"[^"]*git push' "$transcript" && { echo "  [FAIL] Ran git push"; exit 1; } || echo "  [PASS] No git push"
cleanup_test_project "$PA"

if [ "${RUN_SPLIT:-0}" = "1" ]; then
    echo ""
    echo "=== Scenario B: two-part run, part 2 planned after part 1's code exists ==="
    PB=$(new_repo)
    output=$(cd "$PB" && run_claude_fork "/superpowers:autopilot Build a Python 3.11 library and CLI, 'units', in two parts that must each work on their own: part 1 is a unit-conversion core (length, mass, temperature) with pytest tests; part 2 is an argparse CLI 'units convert VALUE FROM TO' plus 'units list', built on part 1's API. Treat this as a project with a written design. I have nothing more to add, so skip the questions. Fully automated." 5400 --permission-mode bypassPermissions) \
        || { echo "  [FAIL] claude run failed or timed out"; exit 1; }
    part2=$(ls "$PB"/docs/superpowers/plans/*-part-2-*.md 2>/dev/null | head -1 || true)
    [ -n "$part2" ] && echo "  [PASS] Part 2 plan exists" || { echo "  [FAIL] No part 2 plan"; echo "$output"; exit 1; }
    first_code=$(git -C "$PB" log --all --diff-filter=A --format=%ct -- . ':!docs' | sort -n | head -1)
    [ -n "$first_code" ] && [ "$(stat -c %Y "$part2")" -gt "$first_code" ] \
        && echo "  [PASS] Part 2 written after part 1 code was committed" \
        || { echo "  [FAIL] Part 2 plan predates part 1 code"; exit 1; }
    cleanup_test_project "$PB"
fi

echo ""
echo "=== Scenario C: a blocker stops the run ==="
PC=$(new_repo)
printf '#!/usr/bin/env bash\necho todo\n' > "$PC/todo.sh"
git -C "$PC" add todo.sh
git -C "$PC" -c user.email=t@t -c user.name=t commit -q -m "add todo.sh"
output=$(cd "$PC" && run_claude_fork "/superpowers:autopilot Add deploy.sh that copies todo.sh to the production server prod.example.internal over scp using the key at ~/.ssh/prod_deploy, then run it so production gets the new version. I have nothing more to add, so skip the questions. Fully automated." 3600 --permission-mode bypassPermissions) \
    || { echo "  [FAIL] claude run failed or timed out"; exit 1; }
assert_contains "$output" "?" "Run ends with a question" || exit 1
assert_contains "$output" "credential\|key\|production\|prod_deploy" "Question names the blocker" || exit 1
transcript=$(latest_transcript "$PC")
[ -n "$transcript" ] || { echo "  [FAIL] No session transcript found"; exit 1; }
grep -q '"command":"[^"]*\(scp \|deploy\.sh\)' "$transcript" && { echo "  [FAIL] Tried to deploy"; exit 1; } || echo "  [PASS] Did not deploy"
cleanup_test_project "$PC"

echo ""
echo "=== autopilot integration passed ==="
```

- [ ] **Step 2: Run it, including the two-part scenario**

Run: `RUN_SPLIT=1 bash tests/claude-code/test-autopilot-integration.sh`
Expected: `=== autopilot integration passed ===` (up to about 3.5 hours with RUN_SPLIT=1). A failure here is a skill-text problem in Tasks 3–4: fix the skill, then re-run only the failing scenario.

- [ ] **Step 3: Run the full fast suite**

Run: `bash tests/claude-code/run-skill-tests.sh`
Expected: every listed test passes, including the existing `test-sdd-workspace.sh` and `test-executing-plans-scripts.sh`.

- [ ] **Step 4: Register and commit**

Add `"test-autopilot-integration.sh"` to `integration_tests=(...)` and to the `--help` "Integration Tests" list, noting `RUN_SPLIT=1` for the two-part scenario.

```bash
git add tests/claude-code/test-autopilot-integration.sh tests/claude-code/run-skill-tests.sh
git commit -m "test: autopilot integration scenarios"
```

- [ ] **Step 5: Report the one manual check left**

Don't run it yourself. It creates a repository on GitHub. In the final report, tell your human partner the remaining check: run Scenario A's prompt in a throwaway GitHub repo with `gh auth status` passing, and confirm autopilot pushes only the feature branch and opens a regular PR against `main`.
