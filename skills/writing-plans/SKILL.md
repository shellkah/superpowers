---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write implementation plans for an engineer who has not seen this codebase or this spec. Assume they write idiomatic code in the project's language once they know the exact interface and the exact test, and that they will make a reasonable choice wherever the plan leaves one open. What they cannot know is what you decided: which files, which names and signatures, which values from the spec, which tests prove each task. Document those. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `superpowers:using-git-worktrees` skill at execution time.

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## Splitting the Plan

After reading the spec and before writing any task, sketch the tasks with
the Task Right-Sizing rules and look at the nature of what is being built.
Then decide whether to split. Split at natural seams, not at a count:

- A seam is where the tests pass, the work so far is usable on its own, and
  few interfaces cross it: a subsystem, a layer that stands alone, a
  milestone a person could try.
- Tightly related tasks stay in the same part. Ten tasks that build on each
  other's internals are one part, not 8 + 2.
- Never leave a stub part of one or two tasks that belongs with its
  neighbor. Fold it in.
- Each part depends only on earlier parts.

Around 8 tasks is where splitting starts to pay off. It is a guide, not a
cap. No natural seam means one plan. A very large plan with no clean seam
is split at the seam with the fewest crossing interfaces. Make as many
parts as the seams give.

Decide without asking, and announce the split in one line with the reason:
"3 parts: storage, sync engine, UI. Each one works on its own." With no
split, write one plan in this session, as the rest of this skill describes.

**The index.** For a split plan, the main session writes the index itself,
before any part: `docs/superpowers/plans/YYYY-MM-DD-<feature>-index.md`,
with exactly these sections:

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

Part writers may not change Cross-Part Interfaces. Once earlier parts
have run, the code they produced can overrule them: the writer plans
against the code and reports the difference, and the cross-part check
updates the index.

**When parts are written.** Each part is written just before it executes,
so it is planned against the code the earlier parts produced, not against
guesses about it. Never write a later part before the part ahead of it has
run: that is the failure the split exists to prevent.

- **Normal mode:** this session writes the index and part 1 only. Each
  later part is written at the start of its own handover session, as
  Writing a Later Part says, then executed in that session. Your human
  partner reviews the index and part 1 now, and each later part before it
  runs.
- **Under autopilot** (superpowers:autopilot is driving): writing-plans
  writes only the index and returns. Autopilot writes each part just before
  executing it.

**Writing a part.** Dispatch one fresh subagent per part with
`part-writer-prompt.md` in this directory, on the model it names.
Part files go to `docs/superpowers/plans/YYYY-MM-DD-<feature>-part-N-<name>.md`.
The feature in the name keeps subagent-driven-development workspace slugs
from colliding. Each part file uses the standard Plan Document Header, plus
this line directly under the title:

```markdown
**Part N of M** · Index: `<index path>`
```

**Cross-part check**, after each part is written:

- every part's Interfaces blocks match the index's Cross-Part Interfaces;
- every spec requirement maps to a task in a written part, or to a later
  part in the index.

Once earlier parts have run, first bring the index's Cross-Part Interfaces
in line with the code, from the writer's reported differences. Fix small
mismatches yourself. Re-dispatch the writer for a part that is
badly off.

Under autopilot, the main session does not run this check and does not
read part files. After each part is written, a fresh subagent runs it with
`cross-part-check-prompt.md` in this directory, on the model it names. The
checker also updates the index's Cross-Part Interfaces from the writer's
reported differences and the previous executor's interfaces produced.
The main session acts on its report: it re-dispatches the writer for a
part that is badly off.

**Writer questions.** In normal mode, settle what you can and record each
one as a call you made. Bring the rest to your human partner under "Where
to focus" in the closing message. Under autopilot, a question only your
human partner can answer is a blocker for autopilot to ask. Autopilot
passes the writer's reported interface differences to the cross-part
checker; it does not edit the index itself.

**No subagent tool:** write the part yourself, and re-read the index first.

## Writing a Later Part

Normal mode only. A handover prompt that says "Write, then execute part N"
brings you here, in a fresh session:

1. Check that part N-1 is complete: every task in its plan file is checked
   off. If it is not, stop and say so.
2. Dispatch the part writer with `part-writer-prompt.md`, as Writing a
   Part says. `[EARLIER_PART_PATHS]` is the part files written so far.
   `[WORKTREE_PATH]` is the worktree part N-1 used (`git worktree list`
   finds it). `[UNDER_AUTOPILOT]` is `no`.
3. Run the cross-part check on the part.
4. Show your human partner the part file and a **Where to focus** list,
   the writer's open questions first, and wait for their go-ahead. Then execute the part with the skill the
   handover prompt names. Do not start a new session for it.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

## Step Granularity

**Each step is one action with a checkable result:**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: the handover prompt names which skill runs this plan, superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Spec:** [path to the spec/design doc this plan implements — the plan
argues from the spec, so the spec travels with it; executors read both]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

## Review Focus

[The five input classes or failure modes the spec implies but no task's
tests exercise that are most likely to bite a person using this software
— one line each, naming the input or condition and the behavior a
reasonable person would expect, most likely first. The spec is a vision
document: it says what the software must do, not everything it will
meet, and its silence on an input is not permission for that input to
break the program. Write the list here, once, with the spec in front of
you. Then, for each line, add the test that pins it to the task that
owns the code, in that task's own step style.]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Implement `function(input: InputType) -> ResultType` in `exact/path/to/file.py`**

One line on the approach when the signature and the test leave a choice
(which library call, which data structure); a code block only for an
algorithm they do not determine.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## What a Step Contains

A step is done when the implementer can write exactly one reasonable thing
from it. That is the whole requirement: unambiguous, not complete. Each kind
of step carries what makes it unambiguous and nothing more:

- **A test step:** the test's name and its assertions, as code, with the
  spec's exact values in them.
- **A code step:** the exact signature (name, parameters, return type), the
  file it lives in, and the specific values the spec pins. The implementer
  writes the body. A body appears only for an algorithm the signature and
  tests do not determine, or for exact copy the spec fixes.
- **A verification step:** the command to run and the output that means it
  passed.
- **A reference to another task:** that task's Interfaces block says what
  to use; the plan does not repeat that task's code.

A plan is the set of decisions the implementer cannot make alone. A plan
longer than the code it describes has written the code instead. Lines that
decide nothing ("TBD", "handle edge cases", "add appropriate validation",
"write tests for the above", a type or function no task defines) are the
opposite failure, and the self-review catches both.

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Step scan:** Every step must let the implementer write exactly one reasonable thing, and no step may carry more than that: a line that decides nothing is a gap, a function body the signature and tests already determine is a transcript. Fix both.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**4. Review Focus:** For each input class or failure mode the spec implies, is there a task whose tests exercise it? The five uncovered ones most likely to bite a person go in the Review Focus section, and each line there gets its test added to the owning task. An empty section means you checked and found none, not that you skipped the check.

**5. Proportion:** Compare the plan's length to the spec's. A plan several times longer than the spec it implements is a transcript of the program, not a plan. If code blocks are most of the document, replace bodies with signatures, test names and assertions, and check that each step is still unambiguous.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Execution Handoff

Do not ask your human partner which execution approach to use. You already
know which one you recommend, so act on it: write a handover prompt for each
part and hand it over.

**1. Pick the mode for each part.** After the plan (or, for a split, the
index and part 1) is written and self-reviewed, choose the recommended mode
for each part; for a part not yet written, judge from its row in the
index:

- **superpowers:subagent-driven-development** - A fresh subagent implements each task and a fresh reviewer checks it before the next one starts, then a whole-branch review at the end. Most thorough; costs a fresh context per task and per review.
- **superpowers:executing-plans** - The executor implements every task itself in its own session, the way this harness runs work, then one fresh reviewer on the most capable model checks the whole branch. Cheapest and fastest; no independent review until the end. Runs well with a mid-tier session model, since the plan carries the design.

Weigh how much the tasks depend on each other's interfaces, how many there
are, and what a shipped mistake would cost, and give one sentence of reason.
A plan with no split is "part 1 of 1". If your human partner already named a
mode, put that mode in every prompt instead of your recommendation.

**2. Write every handover prompt to one file**,
`docs/superpowers/plans/YYYY-MM-DD-<feature>.handover.md`, one section per
part, in execution order:

````markdown
# Handover: <Feature Name>

**Spec:** `<spec path>`

## Part 1 of M: <part name>

<the part 1 prompt>

## Part 2 of M: <part name>
...
````

Write each prompt as Markdown under its heading, never inside a code
block, so it reads well in the file. The closing message is different: it
puts the part 1 prompt in a `markdown` code block (step 4).

**3. What each prompt contains,** in this order: one sentence, then a
bullet per item with a bold label. Put every path, branch and skill name in
inline code. In normal mode, a split plan's later parts are not written
yet, so their prompts open with a different sentence that names the part's
future file:

```markdown
Execute part N of M of the implementation plan at `<plan path>` (spec: `<spec path>`).
```

```markdown
Write, then execute part N of M of the plan indexed at `<index path>` (spec: `<spec path>`): use `superpowers:writing-plans` (Writing a Later Part) to write it to `<part path>` against the code earlier parts produced, wait for your human partner's go-ahead, then execute it.
```

Then the bullets:

```markdown
- **Skill:** use `superpowers:<subagent-driven-development|executing-plans>`.
- **Why this mode:** <one sentence>.
- **Branch:** work on branch `<branch from the index>`.
- **Workspace:** set up the workspace as the skill says.
- **Previous part:** continue on that branch in the worktree part N-1 used. First check that part N-1 is complete: every task in its plan file is checked off (its executor ticks them only after its final review passes). If it is not, stop and say so.
- **Not the last part:** when the final review passes, report and stop without running `superpowers:finishing-a-development-branch`; the next part continues on this branch. Before you stop, check off every task of this part in its plan file: the next part's completeness check reads those checkboxes.
```

- **Branch:** split plans only.
- **Workspace:** part 1 only.
- **Previous part:** every part after part 1.
- **Not the last part:** every part except the last.

Under autopilot every part is written before its prompt, so every prompt
opens with "Execute".

**4. End the session with one message** (skip this under autopilot, see
below): the plan link, a **Where to focus** list, and the part 1 handover
prompt, laid out like this. Keep the bold labels word for word; they are
how your human partner finds the list and the prompt:

````markdown
Plan complete: `<plan path or index path>`.

**Where to focus** when you review it:
1. <2–5 points, most important first: split boundaries, the Cross-Part Interfaces, rulings on ambiguity, the Review Focus section, anything the spec left loose, part writers' open questions>

**Handover:** recommended mode <mode>, because <reason>. Paste this into a fresh session once the plan looks right:

```markdown
<part 1 prompt>
```

The other parts' prompts are in `<handover path>`. Run them in order, each in a fresh session: each one writes its part against the code the earlier parts produced, shows it to you, then executes it.
````

The prompt goes in the code block as written in the handover file, so it
copies in one piece with its Markdown intact. Drop the last line when
there is one part. Then wait for your human partner
to review the plan. Do not start executing it.

**Under autopilot** (superpowers:autopilot is driving), skip the message and
return control to autopilot. With a split, stop after the index; autopilot
dispatches each part's writer, and the writer appends the part's handover
prompt to the handover file as it goes.
