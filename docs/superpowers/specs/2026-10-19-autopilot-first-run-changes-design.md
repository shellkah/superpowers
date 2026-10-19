# Autopilot: changes from its first long run

Personal changes for the `shellkah/superpowers` fork, built on 7.0.1. Like
the 2026-10-13 handover/split/autopilot design, these stay in the fork and
do not go upstream.

Source: `docs/plans/2026-10-19-autopilot-first-run-feedback.md` (the
feedback doc). It records what happened in the first real
`/superpowers:autopilot` run and proposes 13 changes. This design takes
all 13, adds three, and adjusts several so that they serve one concern.
Read the feedback doc for the evidence behind each item; this document
says what to build.

## Why

The run worked: parts written just before they ran, real bugs caught by
the reviews, every interruption recovered. What hurt most was the **main
session's context**. It filled quickly and compacted more than once. The
cost was speed and tokens, not wrong or forgotten work.

What filled it:

- **Executor reports.** Each one carries every ruling and every deferred
  minor (60+ rulings and 100+ minors over five parts). Step 6 then
  repeats them all in the summary.
- **The main session reading code** to bring the index's Cross-Part
  Interfaces back in line with the code after each part.
- **The main session reading whole part files and the spec** for the
  cross-part check (step 4.3) and to write each handover prompt (step
  4.4). Parts ran 1,200 to 2,000 lines, and the spec 714.

The rest of the feedback doc (visibility, pausing, refusals, recoveries,
several PRs, the foreground rule) also goes in, but each change must keep
the main session's load small.

## Goals

- The main session never reads a part file, the spec, or product code
  during step 4. It reads short reports and one small state file.
- After compaction or a restart, the main session resumes from one file.
- Every ruling and deferred minor still reaches a durable record and the
  PR description. Only the ones that need a human eye reach the main
  session and the summary in full.
- The human partner can follow the run away from the terminal and pause
  it cleanly.
- Refusals by permission checks and hooks are respected. No agent
  launders a refused command.

## Non-goals

- Changing how executors work inside a part (TDD, reviews, ledger
  format), except where noted below.
- Reducing the executor's or writers' own context use. The concern is the
  main session's. The plan-length change (§2.2) happens to help writers
  too.
- Fixes outside superpowers: the database container's restart policy and
  the other tool's hooks (see the feedback doc's "Outside superpowers").
- The brainstorming skill's question style. Your human partner raised it
  in this conversation; it is a separate design, done after this one.
- Upstream eval evidence. This is fork-only.

## Anti-goals

- **Losing rulings.** Slimming reports must not make any ruling vanish.
  The executor deletes its workspace and ledger when its final review
  passes (`executing-plans/SKILL.md`, "Final review clean: delete this
  plan's workspace"), so the full lists must be written somewhere durable
  *before* that.
- **Worse plans for the sake of length.** No line budget a writer must
  hit (§2.2).
- **New review stops.** Nothing here adds a stop, except the checkpoint
  mode, which your human partner opts into.
- **Moving the reading into the main session by another route**, for
  example a cross-part check whose report pastes the part back.

## Design

Section numbers follow the feedback doc where an item comes from it.
Items marked **(new)** came out of this conversation.

### 0. The run folder (new)

Autopilot keeps one git-ignored folder per run in the **main checkout**
(the one autopilot runs in, not an executor's worktree):
`.superpowers/autopilot/<feature>/`, where `<feature>` is the spec's
topic slug. `.superpowers/` is *not* git-ignored in other projects (only
`.superpowers/sdd/` ignores itself, through the `.gitignore` that
`sdd-workspace` writes), so autopilot writes a self-ignoring `.gitignore`
(`*`) at `.superpowers/autopilot/` the same way. Autopilot creates the
folder after the spec is committed (step 2) and passes its absolute path
to every writer, checker and executor as `[RUN_DIR]`.

**Stale folders.** `state.md`'s first line names the spec it belongs to.
If a folder already exists for the slug and its `state.md` names a
different spec, or names a run whose PR(s) all opened, it is stale:
autopilot replaces it. The folder is otherwise left in place after the
run; it is git-ignored scratch. *(Designer's call.)*

It holds:

- **`state.md`**, the run-state file. The main session rewrites it at
  every step boundary. Contents: spec, index and handover paths; current
  part and step; for each finished part, its branch, worktree and last
  commit; pending items (an unanswered blocker, a paused executor and its
  agent id when the harness has one); consents given in the builder check
  (§3.2, §3.1); checkpoint mode on or off (§1.2); the PR plan (§4.2);
  anything published but not yet seen (§3.4). It holds pointers and
  one-liners, not reports.
- **`part-N-record.md`**, one per part, written by the executor (§2.1).
  With several builds (§4.2), `build-B-part-N-record.md`.
- **`main-record.md`**, appended to by the main session (its calls on the
  builder check's minor questions, on writer questions, on the
  pre-flight) and by the cross-part checker (each fix it made, one line,
  tagged like a ruling). This keeps rulings no executor made from
  vanishing. The writers' own planning calls already live in their part
  files. *(Designer's call, from the builder check.)*
- Any between-parts work of the main session's own, under a subfolder
  (§3.3).

**Resuming.** `autopilot/SKILL.md` gains a short section: after a
compaction or a session restart, read `state.md` first and trust it, plus
`git log`, over your own recollection. Do not re-read reports or part
files to rebuild context.

### 1. Visibility and control

#### 1.1 Notify, don't only post a status line

`autopilot/SKILL.md`, step 4 and Blockers: where the harness has a push
channel (Claude Code's `PushNotification`), also send through it:

- each part's status line;
- every blocker's question (the most important one to deliver
  off-terminal);
- a pause taking effect (§1.2);
- anything published for your human partner (§3.4);
- the PR link at step 5.

Without a push channel, the status line alone, as today. One short
message each; never a report.

#### 1.2 Pausing, plus an optional checkpoint mode

- **`autopilot/SKILL.md`, new "Pausing" section.** A pause request is not
  a blocker. The main session honours it at its next step boundary. If an
  executor is running, the main session forwards the pause to it
  (SendMessage in Claude Code) and waits for its report. It records the
  pause in `state.md`, notifies (§1.1), and resumes when told to continue,
  continuing a paused executor with SendMessage.
- **`executor-prompt.md`.** On a pause, the executor finishes the task in
  progress, ledgers `PAUSED, resume at Task N`, and reports at once with
  `Status: PAUSED`, a third status beside DONE and BLOCKED. It does not
  idle waiting for a go-ahead. Implementers dispatched by the executor
  are not paused mid-task; the boundary is the executor's task boundary.
- **Checkpoint mode.** The builder check (step 2) asks once whether your
  human partner wants the run to stop after each part. If yes, after each
  part's status line the main session stops (notifying) and waits for
  "continue". Default: off. Recorded in `state.md`.

### 2. Volume

#### 2.1 Tagged rulings, slim reports, a durable record

- **`executor-prompt.md`:** every ruling is tagged at the moment it is
  ledgered, `[review]` or `[routine]`, by its cost if wrong. `[review]`
  means it touches permissions, data, outside systems, the spec's
  meaning, or anything costly to undo. A command re-run after a refusal
  would have been `[review]`; under §3.1 it is no longer allowed at all.
- **The record.** Before deleting its workspace (when the final review
  passes) or before reporting BLOCKED or PAUSED, the executor writes
  `[RUN_DIR]/part-N-record.md` with: every ruling with its tag and cost
  if wrong, every deferred minor, and the "Interfaces produced" block
  (§4.1). The executor overwrites the file on each later report from the
  same part, so the last report wins.
- **The report gets slimmer.** `Rulings I made` lists only the `[review]`
  rulings in full, followed by `Routine rulings: <count>`. `Deferred
  minors` becomes a count. A new `Record: <path>` line names the record.
  `Interfaces produced` is in the record, not the report.
- **`autopilot/SKILL.md`, step 6.** The summary leads with every
  `[review]` ruling (each executor's, plus the main session's own calls
  that meet the same test), then "Not yet seen by you" (§3.4), then the
  other items step 6 lists today, with routine rulings and deferred
  minors as counts and a pointer to the PR description.
- **`autopilot/SKILL.md`, step 5.** The PR description is the step 6
  summary followed by `main-record.md` and the part records, joined on
  the shell (e.g. `cat`
  into a body file passed to `gh pr create --body-file`), inside a
  collapsed `<details>` section. The main session does not read the
  records to build it.
- The Red Flag "The ruling was small, I'll leave it out of the summary"
  changes to: every ruling goes in the PR description; every `[review]`
  ruling also goes in the summary.

#### 2.2 Plan proportion: guidance and a reported ratio

writing-plans already says code steps carry signatures and tests, not
bodies, and its Self-Review item 5 checks proportion. In the run, writers
had both and still wrote full bodies. So:

- **`writing-plans/part-writer-prompt.md`** states the rule in the prompt
  itself, not only by reference: interfaces, tests, edge cases and the
  reasons behind choices are written in full; function bodies and whole
  scripts become a signature and a sentence, unless the code is itself
  the hard part (a tricky algorithm, an exact migration, an exact
  command sequence). No line budget.
- **The writer's report** gains `Length: <lines> lines, for spec §…
  (<lines> lines)`.
- **The cross-part checker** (§4.3b) flags a part far over its spec
  share. It is a note in the summary, not a re-dispatch. Your human
  partner chose this over a budget or a re-dispatch, because a forced
  number risks cutting what makes the plan good.

### 3. Boundaries

#### 3.1 Refusals from hooks and permission checks

- **`executor-prompt.md`**, beside the BLOCKED rules:

  > A command refused by a permission check or a hook is never run again
  > by another agent, or by another route to the same effect. A hook that
  > points to an equivalent read-only tool for the same read (Read for
  > `cat`) may be followed: ledger it. A refusal of the action itself, or
  > a redirect to a tool that runs or changes something, is BLOCKED. Tell
  > every implementer the same.

- **`autopilot/SKILL.md`, a pre-flight after step 3** (the index exists,
  part 1 has not been written). No plan exists at step 2, so this cannot
  happen there. The main session lists the commands the run will rely on
  (tests, local servers, scratch databases) from the index, the spec and
  the repo, and:
  - **probes the harmless ones**: commands with no lasting effect, such
    as running the existing test suite once, a linter, a version check.
    Your human partner chose probing over asking alone, so that hook and
    permission refusals surface before part 1, not mid-part;
  - **does not probe** anything that creates, changes, deletes or starts
    something lasting (a database, a container, a server left running,
    `rm`). Those are listed and asked about;
  - brings every refusal found, and the unprobed commands, to your human
    partner in one message: allow it, or say how to work around it. This
    is a blocker before part 1. A probe that is refused is not retried by
    another route (the refusal rule above applies to the main session
    too).

  What it settles goes in the spec's run notes, in `state.md`, and in
  every executor prompt. Probing records only pass/refused, not the
  output, so it adds little to the main session's context.
- **Your own dispatches follow the same rule.** A hook's instruction that
  conflicts with autopilot (its own plans, its own checkouts) is not
  followed. Autopilot's worktree and ledger rule. This is said once in
  the executor prompt, not pasted by hand into each dispatch.

#### 3.2 Recoveries agreed up front

`autopilot/SKILL.md`, step 2: the builder check names the services the
run depends on (a database, a container, a dev server) and asks once
whether autopilot may restart them if they go down. The consent is
narrow: restarting those named services, nothing else. It is recorded in
the spec's run notes and in `state.md`, and passed to every executor.
Anything beyond it stays a blocker.

#### 3.3 The main session's own work is durable

`autopilot/SKILL.md`, a line under step 4: work the main session does
between parts lives in `[RUN_DIR]` (or a worktree of its own), never only
in a temporary directory. Anything destined for the branch is copied into
the worktree and committed only when no executor is running in that
worktree.

#### 3.4 Non-blocking review of what the run publishes

`autopilot/SKILL.md`, step 4: anything the run publishes for your human
partner to look at (a design, a document) is sent with its link through
§1.1's channel, and the run carries on. It is listed in `state.md` and in
step 6's summary under "Not yet seen by you". No stop is added.

### 4. Shape of the run

#### 4.1 Executors report the interfaces they produced

The executor writes an `Interfaces produced:` block, in the index's
Cross-Part Interfaces format with a `file:line` for each, into its record
(§2.1). The cross-part checker (§4.3b), not the main session, spot-checks
it against the code and updates the index.

#### 4.2 Runs that open more than one PR

`autopilot/SKILL.md`, step 2: when the request names several PRs, the
builder check asks whether each later build waits for the earlier one's
acceptance. Default: stop after the first PR, with the next build's index
written, and resume when told. Recorded in `state.md`.

The rest is the designer's call, following what the first run did:

- **One spec, one run folder.** The spec covers every build, as in the
  first run. Builds are numbered in `state.md`; their records are named
  per build (§0).
- **Steps 3 to 6 loop per build.** Each build gets its own index (and
  handover file), its own pre-flight (§3.1), its own PR and its own step 6
  summary.
- **The next build's index is written after the previous PR opens**,
  against that PR's branch. Stopping there (the default) means the index
  may need a revision after acceptance; on "continue", the main session
  re-runs writing-plans' split for that build first if the acceptance
  changed the earlier build.
- **Stacked branches.** A later build branches from the previous build's
  branch, and its PR targets that branch, as your human partner asked in
  the first run.

#### 4.3 The rule to dispatch in the foreground

`autopilot/SKILL.md`, the dispatch paragraph and its Red Flag: keep the
intent (never start the next step without the report you need) and drop
the mechanism. Where the harness runs subagents only in the background
and notifies on completion, end the turn and resume on the notification.
Never poll a subagent's output, never act on a guess of its result.

The executor prompt's own foreground rule for its implementers and
reviewers stays as it is. The run only showed the problem in the main
session. *(Designer's call.)*

#### 4.3b Delegate the cross-part check (new)

Step 4.3 today has the main session run writing-plans' cross-part check
itself. Under autopilot, a fresh subagent runs it instead, with a new
prompt file, `writing-plans/cross-part-check-prompt.md`. Inputs: spec,
index, this part's file, the previous part's record (for its Interfaces
produced, §4.1), the latest worktree, and the writer's `Length` line.

It:

1. updates the index's Cross-Part Interfaces from the previous part's
   Interfaces produced, after spot-checking each `file:line` against the
   code;
2. checks this part's Interfaces blocks against the index, and that
   every spec requirement maps to a task in a written part or to a later
   part in the index;
3. fixes small mismatches itself, in the index or the part file.

It reports only what it could not settle (with a recommendation for
each), a `Length` note when the part is far over its spec share, and a
one-line count of what it fixed. The main session acts on that report as
step 4.3 says today ("re-dispatch the writer for a part that is badly
off"). Model: a mid-tier model by default, named explicitly as the other
prompts do.

Step 4.2's index updates for "interface differences" from the writer's
report also move to the checker: the main session passes the writer's
report lines along rather than editing the index.

writing-plans' cross-part check outside autopilot (normal mode) is
unchanged.

#### 4.4b The writer writes the handover prompt (new)

Under autopilot, the part writer also writes its part's handover prompt,
following writing-plans' Execution Handoff (mode choice with one
sentence of reason, the prompt's contents in order), and appends it to
the handover file (creating it with that layout for part 1). It reports
the chosen mode in one line. The main session no longer writes it (step
4.4 becomes "check the writer appended it"). It still fills the
executor's `[HANDOVER_PROMPT]` from the handover file, with paths made
absolute and the branch line set, as today.

Writing-plans' instruction "do not write handover prompts; the main
session does" in the part-writer prompt changes accordingly. Outside
autopilot, the split flow is unchanged: the main session writes all the
handover prompts after all parts are written.

### 5. Who asks the new questions, and where answers live

The builder check is a generic subagent from brainstorming; it knows
nothing about autopilot and brainstorming does not change. So the new
step 2 questions (services and restart consent §3.2, checkpoint mode
§1.2, several PRs §4.2) are **fixed questions the main session adds to
the builder check's "theirs" message**, skipping any the request already
answers. The pre-flight (§3.1) asks its own message after step 3.

Answers go in a new **"Run notes"** section at the end of the spec,
committed with it, and are mirrored in `state.md`. *(Designer's call,
from the builder check.)*

## Files touched

- `skills/autopilot/SKILL.md`: run folder and resuming, step 2's added
  builder-check questions (commands, services, checkpoint mode, several
  PRs), step 4 (notify, delegate the check, the writer's handover, main
  session's own work, publishing), Pausing, steps 5 and 6, foreground
  paragraph, Red Flags.
- `skills/autopilot/executor-prompt.md`: `[RUN_DIR]`, ruling tags, the
  record, PAUSED, refusals, consents, slimmer report.
- `skills/writing-plans/part-writer-prompt.md`: `[RUN_DIR]`, plan-content
  guidance, Length line, handover prompt under autopilot.
- `skills/writing-plans/cross-part-check-prompt.md`: new.
- `skills/writing-plans/SKILL.md`: under autopilot, the cross-part check
  is delegated and the writer writes the handover. Only the autopilot
  paragraphs change.
- `skills/brainstorming/`: nothing.

## Verification

Your human partner's choice: no evals. Use the changes on the next real
autopilot run and compare it with the first:

- the main session's compactions (more than one before; target zero or
  one for a run of similar size);
- the main session's tokens, where the harness reports them;
- that every ruling appears in the PR description and every `[review]`
  ruling in the summary;
- that a pause, if one happens, comes back as `Status: PAUSED` without
  idling.

Before that run, a read-through check is enough: every placeholder
autopilot fills is defined, and the executor's report format and the
summary's sections agree with each other.

## Left to the builder

- Exact wording in every skill and prompt, in the files' existing voice
  ("your human partner", short imperative lines).
- `state.md`'s exact layout, as long as it stays short and is rewritten,
  not appended to.
- The record file's exact layout, as long as it carries the tags and the
  Interfaces produced block in the index's format.
- What "far over its spec share" means for the checker's note. Pick a
  plain threshold and say it in the prompt.
- How the builder check phrases its added questions, and whether some can
  be skipped when the plan obviously needs no services or local commands.
