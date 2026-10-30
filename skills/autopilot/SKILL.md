---
name: autopilot
description: Use when your human partner asks for a fully automated run ("fully automated", "autopilot", or /superpowers:autopilot)
---

# Autopilot

Your human partner answers the questions, then comes back to finished work:
a spec, a plan, the code, and an open PR. Questions still happen. Review
stops don't. Blockers always stop.

**Announce at start:** "I'm using the autopilot skill. Autopilot is driving:
I'll ask my questions first, then take this all the way to an open PR, and
stop only if something needs you."

**Autopilot is driving.** From here on, every skill you invoke runs in its
autopilot mode. When brainstorming checks whether autopilot is driving yet,
it is: carry on in brainstorming. Never invoke autopilot again from inside
the run.

Before step 1, note the branch you are on. The PR targets it.

Never start the next step without the report it needs: the builder
check's, each part writer's, each checker's, each executor's. Dispatch
those subagents in the foreground and wait (in Claude Code,
`run_in_background: false`), since a run nobody is watching can end while
you wait on a background subagent. Where the harness runs subagents only
in the background and notifies you when one finishes, end your turn and
resume on the notification. Never poll a subagent's output, and never act
on a guess of its result.

Where the harness has a push channel (`PushNotification` in Claude Code),
also send through it each part's status line, every blocker's question, a
pause taking effect, anything published for your human partner, and the
PR link. One short message each, never a report. Without a push channel,
the status line alone.

## The Run Folder

Keep one folder per run in your own checkout (not an executor's
worktree): `.superpowers/autopilot/<feature>/`, where `<feature>` is the
spec's topic slug. Create it right after you commit the spec (step 2), and
write a `.gitignore` containing `*` at `.superpowers/autopilot/` so git
ignores it. Pass its absolute path as `[RUN_DIR]` to every writer, checker
and executor.

If the folder already exists and its `state.md` names a different spec,
or a run whose PRs all opened, it is stale: replace it. Otherwise leave
the folder in place after the run.

It holds:

- **`state.md`**, the run state. Its first line is
  `# Autopilot run — spec: <spec path>`. Then: the spec, index and
  handover paths; the current build, part and step; for each finished
  part, its branch, worktree and last commit; pending items (an unanswered
  blocker, a paused executor and its agent id when the harness has one);
  the run notes (step 2); anything published but not yet seen. Pointers
  and one-liners, never reports. Rewrite it whole at every step boundary;
  never append to it.
- **`part-N-record.md`**, one per part, written by its executor: every
  ruling, every deferred minor, the interfaces it produced. With several
  builds, `build-B-part-N-record.md`.
- **`main-record.md`**: your own calls (on the builder check's minor
  questions, on writer questions, on the pre-flight), one line each,
  tagged like an executor's rulings (`[review]` or `[routine]`). The
  cross-part checker appends its fixes here too.

## Resuming After Compaction

After a compaction or a session restart, read `state.md` first and trust
it, plus `git log`, over your own recollection. Do not re-read executor
reports, records or part files to rebuild context: `state.md` says where
the run is and what is pending. Continue from there.

## The Flow

1. **Brainstorm.** Invoke superpowers:brainstorming. Ask your questions as
   usual. Skip the playback chunks. If your human partner opts out of the
   questions, ask no more and work from the request alone: for a project,
   write the spec from what they asked (step 2's builder check still runs).
   Then size the work:
   - **A quick, clear task:** do it.
   - **A small change:** describe it in chat in one message that ends
     without a question, then build it through the normal workflow without
     waiting for an answer. If it tracks an issue, open it as that message
     goes out, as superpowers:tracking-work-in-issues says (Opening the
     Issue).
   - **A project:** continue to step 2.

   Build a quick task or a small change on a new branch cut from the
   branch you noted at the start, then go on to steps 5 and 6.

2. **Spec.** Write the spec where brainstorming says and run its builder
   check. Sort the builder's questions the way brainstorming says. The
   "theirs" pile is a blocker: ask it in one message, update the spec with
   the answers, and continue. Settle the minor ones yourself and mark them
   as your calls. Add these questions to the "theirs" message, skipping
   any the request already answers, or that cannot apply (no services when
   the work needs none):
   - **Services.** Name the services the run depends on (a database, a
     container, a dev server) and ask whether you may restart them if they
     go down. The consent covers restarting those named services, nothing
     else.
   - **Checkpoints.** Ask whether they want the run to stop after each
     part. Default: no.
   - **Several PRs**, when the request names more than one: ask whether
     each later build waits for the earlier one's acceptance. Default: stop
     after the first PR, with the next build's index written.

   Put their answers in a `## Run notes` section at the end of the spec.
   If this work tracks an issue, open it as you commit the spec, as
   superpowers:tracking-work-in-issues says (Opening the Issue): its
   `**Issue:**` line goes in that commit.
   Commit the spec, then create the run folder, write `state.md`, and put
   your calls in `main-record.md`. Do not stop for a review: the request
   for a fully automated run is their approval of the spec.

3. **Split.** Invoke superpowers:writing-plans. With no split, it writes the
   one plan and its handover prompt, then returns. With a split, it writes
   only the index, then returns. Either way there is no closing message and
   no review stop.

   **Pre-flight**, once the index (or the plan) exists and before part 1 is
   written. List the commands the run will rely on (tests, linters, local
   servers, scratch databases) from the index, the spec and the repo.
   - Probe each one with no lasting effect, once: the existing test
     suite, a linter, a version check. Record only pass or refused, not
     the output.
   - Do not probe anything that creates, changes, deletes or starts
     something lasting (a database, a container, a server left running,
     `rm`). List it to ask about instead.
   - Bring every refused probe and every unprobed command to your human
     partner in one message: allow it, or say how to work around it. This
     is a blocker before part 1. A refused probe is never retried by
     another route.

   Add what the pre-flight settles to the spec's run notes and commit
   them. Mirror the run notes in `state.md`.

4. **Write, then execute, one part at a time.** With no split, the plan and
   its handover prompt already exist: skip to sub-step 5, the executor.
   With a split, for each part in order:
   1. **Write the part.** Dispatch a fresh subagent with
      `../writing-plans/part-writer-prompt.md`, on the model it names. Fill
      every placeholder. `[EARLIER_PART_PATHS]` is the part files written
      so far (`none` for part 1). `[WORKTREE_PATH]` is the worktree the
      previous executor reported (`none` for part 1). `[UNDER_AUTOPILOT]`
      is `yes`. `[HANDOVER_PATH]` is the handover file.
   2. **Read the writer's report.** An open question only your human
      partner can answer is a blocker: ask it, then send the answer back to
      the writer. Settle the other questions yourself and put each one in
      `main-record.md`. Do not edit the index: the checker does.
   3. **Check it.** Dispatch a fresh subagent with
      `../writing-plans/cross-part-check-prompt.md`, on the model it names.
      Fill every placeholder. `[PREVIOUS_RECORD_PATH]` is the previous
      part's record and `[WORKTREE_PATH]` the worktree the previous
      executor reported (`none` for both in part 1). `[WRITER_REPORT]` is the writer's report lines, pasted as
      they came. Act on its `Unsettled` lines: re-dispatch the writer for
      a part that is badly off; anything only your human partner can
      answer is a blocker. Keep a `Length` note for the summary.
   4. **Check the handover.** The writer's report says
      `Handover: appended, mode <skill>`. Confirm the part's section is in
      the handover file. Do not write it yourself.
   5. **Execute the part.** Dispatch a fresh executor subagent with
      `executor-prompt.md` in this directory, on the model it names.
      `[BRANCH]` is the index's `**Branch:**` for part 1, then the branch
      the previous executor reported; with no split, the
      `<feature>` slug from the plan's file name. `[HANDOVER_PROMPT]` is the
      part's handover prompt with every path made absolute and its
      `**Branch:**` bullet, if it has one, naming `[BRANCH]`.
      `[WORKTREE_PATH]` is `none` for part 1, then the worktree the
      previous executor reported. `[RUN_NOTES]` is the spec's run notes,
      pasted.
   6. **Read the executor's report.** BLOCKED: see Blockers. PAUSED: see
      Pausing; it is not a blocker. DONE: keep its branch, worktree,
      record path, its `[review]` rulings, its `Acceptance` line, and its
      routine-ruling and deferred-minor counts for the next part and the
      summary.

   In step 4 you read reports and `state.md`, never a part file, the spec,
   or product code: the writers, the checker and the executors read those.
   Rewrite `state.md` at each sub-step boundary.

   Pass every path to writers, checkers and executors as an absolute path:
   an executor works in its own worktree, where files written after it
   branched are not there.

   Between parts, post one status line ("Part 1 of 3 done: storage layer,
   24 tests passing.") and move to the next part without asking. In
   checkpoint mode (run notes), stop after the status line instead and
   wait for "continue".

   If this work tracks an issue (the spec's `**Issue:**` line says; `grep`
   for that line, do not read the spec), after each part's DONE report
   push its branch, open the draft PR after part 1, and post the
   part-done milestone for every part but the last, as
   superpowers:tracking-work-in-issues says (The Draft PR, Milestones).
   These pushes and posts are yours: an executor never makes them.

   Work you do yourself between parts lives in `[RUN_DIR]` (or a worktree
   of your own), never only in a temporary directory. Copy anything meant
   for the branch into the worktree and commit it only while no executor
   is running there.

   Anything the run publishes for your human partner to look at (a design,
   a document) goes out with its link through the push channel, and the
   run carries on. List it in `state.md` until the summary. Do not stop
   for it.

5. **Open a PR.** When the work is done, run
   superpowers:finishing-a-development-branch where it lives: the worktree
   the last executor reported, or your own checkout for a quick task or a
   small change. Do not show its menu; choose for your human partner:
   - **The work is on the branch you noted at the start, or on the
     remote's default branch:** never push it. Take "Keep the branch
     as-is" and say why there is no PR. This is not a blocker.
   - **The repo has a remote and a working CLI for its host** (for GitHub,
     `gh auth status` succeeds): take "Push and create a Pull Request".
     Push only the feature branch, never with force. Open a regular PR, not
     a draft, against the branch you noted at the start (for a later build,
     the previous build's branch). Follow the repo's
     PR template and conventions. The description is the step 6 summary,
     then every ruling and deferred minor: join `main-record.md` and the
     part records on the shell, inside a collapsed `<details>` section,
     into a body file (`cat` them after the summary), and pass it with
     `gh pr create --body-file` or your host's equivalent. Do not read the
     records to build it. If this work tracks an issue, do this as
     superpowers:tracking-work-in-issues says (Finishing): an open draft PR
     gets the body file as its description and is marked ready instead of a
     new PR, and the body keeps `Closes #N` (or `Part of #N`).
   - **No remote, or no working CLI:** take "Keep the branch as-is" and say
     why there is no PR. This is not a blocker.

   Never take "Merge back locally". Autopilot never merges. A rejected push
   is a blocker, not a reason to force.

6. **Summarize** in one message, in this order:
   - every `[review]` ruling made without your human partner: each
     executor's "Rulings I made", plus your own `[review]` calls
     (`grep '\[review\]'` on `main-record.md`), each with what it costs
     if wrong,
   - **Not yet seen by you:** anything published during the run that they
     have not looked at, with its link,
   - the PR link, or why there is none, with the issue link beside it when
     the run tracks one, and what the tracking could not post, as
     superpowers:tracking-work-in-issues says (Failures),
   - what was built, part by part,
   - tests and final-review outcomes for each part, and any checker
     `Length` note,
   - the acceptance check: its result, the steps for your human partner
     to try it, or that the spec named none,
   - routine rulings and deferred minors as counts, with a pointer to the
     PR description where each is listed,
   - open items,
   - where the work lives: branch and worktree.

## Runs With Several PRs

When the request names several PRs, the spec covers every build and the
run keeps one run folder. Number the builds in `state.md`. Steps 3 to 6
run once per build: each build gets its own index and handover file, its
own pre-flight, its own PR and its own summary.

- **Default: stop after the first PR.** Write the next build's index
  against the first PR's branch, notify, and wait for "continue". On
  "continue", if the acceptance changed the earlier build, re-run
  writing-plans' split for the next build first. If the run notes say
  later builds need not wait, carry on without stopping.
- **Stacked branches.** A later build branches from the previous build's
  branch, and its PR targets that branch. For its part 1, cut its branch
  in the previous build's worktree (`git -C <worktree> switch -c
  <branch>`) and pass that worktree and branch to the executor.
- **Tell each executor its build.** Add `Build B of N` to the run notes
  you paste as `[RUN_NOTES]`, so it names its record
  `build-B-part-N-record.md`.

## Blockers

A blocker stops autopilot at any stage. Stop there, without going on to
the PR or the summary, and ask your human partner: say what blocks you,
and end the message with the question they need to answer ("The
integration tests need a Stripe test key and none is set. Can you add one
to `.env`, or should I mock the API?"). Steps for them to follow are not a
question. Send the question through the push channel too, where there is
one: it is the message most worth reaching them away from the terminal.
Wait for the answer, then continue from where it stopped.

If this work tracks an issue (for a project, the spec's `**Issue:**` line
says; `grep` for that line, do not read the spec), post the waiting-on-you
milestone before you ask, and put the status back when the run resumes, as
superpowers:tracking-work-in-issues says (Milestones).

A blocker is:

- a builder-check question only they can answer,
- a part writer's open question only they can answer,
- any of the executor skills' four stop conditions: an irreversible or
  destructive operation, a security-sensitive action, an outside side
  effect such as a push, a publish or a deploy, or a plan so broken that
  every path is a guess. The exceptions are step 5's feature-branch push
  and PR and, when the run tracks an issue, step 4's pushes of that
  branch and its draft PR: your human partner pre-authorized them by
  asking for autopilot and saying yes to the issue. Asking for any
  other side effect in the request ("then deploy it") does not
  pre-authorize it: stop right before it and ask,
- an environment problem you cannot fix: missing credentials, a login, a
  service that is down and not named in the run notes as one you may
  restart,
- a refused or unprobed command from the pre-flight,
- anything where a wrong guess would be expensive to undo.

Everything else is a ruling: decide it, record it, keep going. Every
ruling goes in the PR description; every `[review]` ruling also goes in
the summary.

## Resuming After a Blocker

Relay the executor's question to your human partner, with what it needs.
Wait for the answer. Then continue the same executor with it (SendMessage
in Claude Code). If it cannot be resumed, dispatch a fresh executor with
the same handover prompt, the branch and worktree from the BLOCKED report,
and the answer, and point it at the ledger that report names. The ledger
lets it pick up where the last one stopped.

## Pausing

A pause request from your human partner is not a blocker. Honour it at
your next step boundary. If an executor is running, forward the pause to
it (SendMessage in Claude Code) and wait for its report: it finishes its
current task and reports `Status: PAUSED`. Record the pause in `state.md`
(with the executor's agent id, when the harness has one) and send a short
notice through the push channel. When they say to continue, continue the
paused executor with SendMessage, or, if it cannot be resumed, dispatch a
fresh one as Resuming After a Blocker says.

## Fallback

With no subagent tool, write each part yourself, as writing-plans says, and
run each part's handover prompt in this session with
superpowers:executing-plans, part by part. The executor prompt's limits
still hold: no finishing-a-development-branch, and no push until step 5
beyond step 4's between-part pushes when the run tracks an issue.
Step 4's rule against reading part files, the spec and code does not
apply here: you are the writer and the executor. Run writing-plans'
cross-part check yourself after each part is written, as its normal mode
describes. Tag your rulings `[review]` or `[routine]` as the executor
prompt says, and write the part's record to `[RUN_DIR]` before
executing-plans deletes the plan's workspace, so steps 5 and 6 find it.

## Red Flags

| Thought | Reality |
|---------|---------|
| "It's automated, so I'll skip the questions." | Questions still happen. Only the review stops go away. |
| "I'll guess so I don't interrupt them." | A blocker is a question. Ask it. |
| "The PR is green, I'll merge it." | Autopilot ends at an open PR. It never merges. |
| "I'll plan all the parts now and save time." | Under autopilot, each part is written after the previous one runs, against the real code. |
| "The ruling was small, I'll leave it out of the record." | Every ruling goes in a record and the PR description. Every `[review]` ruling also goes in the summary. |
| "I lost track after the compaction, I'll re-read the executor reports." | Read `state.md` and `git log`. They say where the run is. |
| "The hook refused that command, I'll have a subagent run it." | A refused command is never re-run by another agent or another route. Ask, or work around it. |
| "Brainstorming says to invoke autopilot, so I'll invoke it." | Autopilot is already driving. Carry on in brainstorming. |
| "They asked me to run the deploy, and with no key it will just fail." | Running it is the side effect, even a run you expect to fail. Stop before it and ask. |
| "I'll list the blocker under Parked and wrap up the run." | A blocker isn't parked work. Stop at it and end your message with the question. |
| "The push was rejected, I'll force it." | Never force. A rejected push is a blocker. |
| "The executor can push its own part." | Executors never push. Autopilot pushes at the end, and between parts when the run tracks an issue. |
| "The executor will take a while, so I'll background it and check its output now and then." | Never poll and never guess. Dispatch in the foreground and wait; if the harness only runs it in the background, end your turn and resume on its notification. |
