# Handover prompts, split plans, and autopilot

Personal changes for the `shellkah/superpowers` fork. These are workflow
preferences, so they stay in the fork and do not go upstream (see
`AGENTS.md`). The changes build on the 7.0.0 skills in this repo.

## Why

Today the path from idea to code has three friction points:

1. **The execution choice.** After writing a plan, writing-plans asks
   "Subagent-driven or Native?" even though it already knows which one it
   recommends. Your human partner wants the recommendation acted on: a
   ready-to-paste prompt for the next session, not a question.
2. **One long plan per session.** A big project produces one long plan,
   written in one context. The context does not overflow. The worry is
   accuracy: after thousands of lines, the writer starts inventing names
   and drifting from the spec. (Some of this came from 6.4.1 putting full
   code in plans. 6.4.2+ plans hold signatures and tests only, but a big
   project can still produce a long plan.)
3. **Stopping for approvals when they want it automated.** Sometimes your
   human partner wants to answer the questions and then come back to
   finished work. Today every stage stops for review.

## Goals

- writing-plans ends with handover prompts that name the recommended
  execution mode. It does not ask which mode to use.
- writing-plans splits a big plan into parts. A fresh subagent writes each
  part, so no writer ever has more than one part in its context.
- A new `autopilot` skill runs brainstorming (questions included), then
  writes the spec and plan, executes every part through a capable
  subagent, and summarizes. It does not stop for reviews.
- Any blocker at any stage stops autopilot and goes to your human partner
  as a question.
- When the written spec is handed over for review, it comes with a short
  "where to focus" list.

## Non-goals

- No change to how brainstorming asks questions in normal mode. The
  mid-conversation playback chunks stay, as your human partner requested.
- No change to how subagent-driven-development or executing-plans run a
  plan internally (tasks, reviews, ledger, rulings).
- No upstream PR.
- No cross-harness work beyond a graceful fallback. Autopilot is designed
  for Claude Code (nested subagents were verified there on 2026-10-13: a
  general-purpose subagent has the Agent tool).

## Anti-goals

- Autopilot that pushes, merges, publishes, or opens a PR without asking.
- Autopilot that guesses past a question only your human partner can
  answer, just to keep running.
- Decisions made without your human partner that do not show up in the
  final summary.
- Large edits to the base skills that make every upstream sync a merge
  fight. Keep base-skill edits small and local. Put new behavior in new
  files where possible.

## Design

### 1. Handover prompts replace the execution question (writing-plans)

Rewrite the "Execution Handoff" section of `skills/writing-plans/SKILL.md`.

After the plan (or every part of it) is written and self-reviewed:

- For each part, pick the recommended mode using the existing criteria:
  how much the tasks depend on each other's interfaces, how many there
  are, and what a shipped mistake would cost. Give one sentence of reason.
  A plan with one part is "part 1 of 1".
- Write every handover prompt to one file next to the plan:
  `docs/superpowers/plans/YYYY-MM-DD-<feature>.handover.md`, with one
  section per part, in execution order.
- End the session with one message that contains:
  - links to the plan files,
  - **Where to focus** when reviewing the plan: 2–5 points, most
    important first (the split boundaries, rulings made on ambiguity, the
    Review Focus section, anything the spec left loose),
  - the first part's handover prompt in a code block, ready to paste,
  - one line: paste it into a fresh session once the plan looks right,
    and the rest are in the handover file.
- Do not ask which mode to use. If your human partner already named a
  mode, use that mode in every prompt instead of the recommendation.
- Under autopilot, skip the message. Return control to autopilot, which
  reads the handover file.

Each handover prompt contains:

- the plan path, "part N of M", and the spec path,
- the skill to use (`superpowers:subagent-driven-development` or
  `superpowers:executing-plans`) and the one-sentence reason,
- for a split plan, the branch all parts share (pinned in the plan index;
  see section 2),
- for part 1: set up the workspace as the skill says,
- for parts after part 1: continue on the pinned branch and worktree;
  first check that the previous part is complete (its tasks are checked
  off and its final review passed); if it is not, stop and say so,
- for every part except the last: when the final review passes, report
  and stop without running finishing-a-development-branch, because the
  next part continues on this branch.

Update the plan header's "REQUIRED SUB-SKILL" line so it says the handover
prompt names which skill to use. Update the "When to Use" wording in
executing-plans and subagent-driven-development from "chose ... at the
handoff" to "the handover prompt names this skill" (one line each).

### 2. Splitting the plan (writing-plans)

Add a "Splitting the Plan" section to `skills/writing-plans/SKILL.md`,
after "Scope Check".

**Deciding.** After reading the spec, before writing tasks, estimate the
task count with the existing Task Right-Sizing rules. If the plan needs
more than 8 tasks, split it. Each part:

- has 3–8 tasks,
- ends where the tests pass and the work so far is usable on its own,
- depends only on earlier parts.

Make as many parts as that takes. Decide without asking, and say the
split in one line ("This plan has 3 parts: ..."). Up to 8 tasks: write one
plan in this session, exactly as today.

**The index.** For a split plan, the main session writes
`docs/superpowers/plans/YYYY-MM-DD-<feature>-index.md` itself, before any
part:

- goal, spec path, and the Global Constraints (shared by all parts),
- the branch name all parts use,
- a table of parts: number, name, deliverable, rough task count, and the
  parts it depends on,
- **cross-part interfaces**: the exact names, signatures, and types each
  part produces for later parts. Writers may not change these.

**Writing the parts.** Dispatch one fresh writer subagent per part, in
order, on the most capable model available. Use a new prompt template,
`skills/writing-plans/part-writer-prompt.md`. Each writer gets:

- the spec path, the index path, and its part number,
- the paths of earlier parts (to read their Interfaces blocks, not their
  whole content),
- the instruction to write a normal plan for its part only (standard
  header plus "Part N of M" and the index path; standard task structure),
  to `docs/superpowers/plans/YYYY-MM-DD-<feature>-part-N-<name>.md`,
- the instruction to run writing-plans' own Self-Review on its part,
- the instruction to report back: the file path, its task count, and any
  question it could not settle. It must not guess on a question that
  changes what gets built.

Part file names include the feature, so the subagent-driven-development
workspace slugs (plan basename) do not collide.

**Cross-part check.** After all parts are written, the main session:

- checks every part's Interfaces blocks against the index,
- checks spec coverage across all parts together (each requirement maps to
  a task in some part),
- fixes small mismatches itself and re-dispatches the writer for a part
  that is badly off.

**Writer questions.** In normal mode, the main session settles what it
can and records each one as a call made. It brings the rest to your human
partner in the final message, under "Where to focus". Under autopilot,
a question only your human partner can answer is a blocker (section 4).

**No subagent tool.** Write the parts yourself, one at a time, and
re-read the index before each part.

### 3. Spec review: "Where to focus" (brainstorming)

Brainstorming already hands over the written design with "a short list of
the calls you made". Change that wording in `skills/brainstorming/SKILL.md`
to a **Where to focus** list: the calls you made, plus the places where a
misreading would cost the most, most important first, at most 5 items.
Ask for one review of the whole document. Do not ask for approval section
by section.

Playback chunks during questioning stay in normal mode.

### 4. Autopilot (new skill)

New skill: `skills/autopilot/SKILL.md`.

**Trigger.** The description makes it fire on `/superpowers:autopilot` and
when your human partner asks for a "fully automated" run (or says
"autopilot"). Brainstorming gets two small additions:

- a one-line pointer: if they asked for a fully automated run, use
  superpowers:autopilot, which brings you back here;
- a third exception in its HARD-GATE: under autopilot, the request for a
  fully automated run counts as approval of the written design, once the
  builder check's "theirs" questions are answered.

**Flow:**

1. **Brainstorm** with superpowers:brainstorming. Ask questions as
   usual. Skip the playback chunks. If your human partner opts out of
   questions, write the spec from the request alone.
   - A quick, clear task: do it.
   - A small change: describe it in chat in one message (no question) and
     build it through the normal workflow without waiting.
   - A project: continue.
2. **Spec.** Write it and run the builder check. "Theirs" questions are a
   blocker: ask them, update the spec, continue. Commit the spec. No
   review stop.
3. **Plan.** Run superpowers:writing-plans: split, write the parts, write
   the handover file. No review stop.
4. **Execute.** For each part in order, dispatch a fresh executor subagent
   on the most capable model available. Its prompt is the part's handover
   prompt plus an autopilot block (new template:
   `skills/autopilot/executor-prompt.md`):
   - you are running unattended for your human partner,
   - follow the named skill; with subagent-driven-development, you
     dispatch your own implementers and reviewers,
   - on a blocker, stop and report what blocked you, what you need, and
     the state of the work (branch, last commit, ledger path),
   - never run finishing-a-development-branch; never push, merge, or
     publish,
   - when the final review passes, report what was built, the test status,
     the final review outcome, and the full "Rulings I made" list.

   Between parts, post one status line ("Part 1 of 3 done: ...") and move
   on without asking.
5. **Summarize** in one message: what was built per part, tests and final
   review outcomes, every ruling made without your human partner (from the
   executors' reports), what was parked, and where the work lives (branch,
   worktree). Then run superpowers:finishing-a-development-branch, which
   asks what to do with the branch.

**Blockers** stop autopilot at any stage. Ask your human partner, then
continue from where it stopped. A blocker is:

- a builder-check question only your human partner can answer,
- a plan writer's question only they can answer,
- any of the executor skills' four stop conditions (irreversible or
  destructive operation, security-sensitive action, an outside side effect
  such as a push or publish, a plan so broken that every path is a guess),
- an environment problem the agent cannot fix (missing credentials, a
  login, a service that is down),
- anything where a wrong guess would be expensive to undo.

Everything else is a ruling: decide it, record it, keep going.

**Resuming after a blocker.** Relay the executor's question, wait for the
answer, then continue the same executor with the answer (SendMessage in
Claude Code). If it cannot be resumed, dispatch a fresh executor with the
same handover prompt plus the answer. The ledger lets it pick up where the
last one stopped.

**Fallback.** With no subagent tool, run each part's handover prompt in
this session with superpowers:executing-plans, part by part.

**Red Flags** table, in the house style, covering at least:

- "It's automated, so I'll skip the questions." Questions still happen.
- "I'll guess so I don't interrupt them." A blocker is a question.
- "The branch is done, I'll push it." Never without asking.
- "The ruling was small, I'll leave it out of the summary." Every ruling
  goes in the summary.

### 5. Docs

- README: add autopilot to the skills list and one sentence on handover
  prompts in the workflow description.

## Testing

- Use superpowers:writing-skills while editing the skills.
- Existing plugin tests still pass (`tests/claude-code/`, especially
  `test-sdd-workspace.sh` and `test-executing-plans-scripts.sh`).
- Headless scenario runs in Claude Code with the fork loaded, checking the
  transcripts:
  1. A small spec: writing-plans produces one plan and a handover file,
     and ends with the "Where to focus" list and a paste-ready prompt. It
     does not ask which mode to use.
  2. A spec large enough for 3+ parts: an index, one part file per writer
     subagent, matching interfaces, and handover prompts that chain the
     parts on one branch.
  3. `/superpowers:autopilot` on a tiny project: questions are asked, no
     playback chunks appear, then spec, plan, executor dispatch, and a
     summary with rulings. Nothing is pushed.
  4. Autopilot with a spec that needs a push or a credential: it stops and
     asks.

## Rollout

Your human partner's sessions use the official 6.4.1 plugin. To use these
changes, install the plugin from the fork's marketplace
(`.claude-plugin/marketplace.json`, named `superpowers-dev`), and disable
the official `superpowers` plugin so both don't load at once.

## Left to the builder

- Exact wording of the skill text, in the house voice ("your human
  partner", plain language, Red Flags tables).
- The exact text of the two new prompt templates.
- How the handover file is laid out, within the contents listed above.
