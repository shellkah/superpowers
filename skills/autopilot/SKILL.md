---
name: autopilot
description: Use when your human partner asks for a fully automated run ("fully automated", "autopilot", or /superpowers:autopilot) - asks the brainstorming questions, then writes the spec and plan, executes every part, and opens a PR, stopping only for blockers
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

## The Flow

1. **Brainstorm.** Invoke superpowers:brainstorming. Ask your questions as
   usual. Skip the playback chunks. If your human partner opts out of the
   questions, ask no more and work from the request alone: for a project,
   write the spec from what they asked (step 2's builder check still runs).
   Then size the work:
   - **A quick, clear task:** do it, and say what you did.
   - **A small change:** describe it in chat in one message that ends
     without a question, then build it through the normal workflow without
     waiting for an answer.
   - **A project:** continue to step 2.

2. **Spec.** Write the spec where brainstorming says and run its builder
   check. Sort the builder's questions the way brainstorming says. The
   "theirs" pile is a blocker: ask it in one message, update the spec with
   the answers, and continue. Settle the minor ones yourself and mark them
   as your calls. Commit the spec. Do not stop for a review: the request
   for a fully automated run is their approval of the spec.

3. **Split.** Invoke superpowers:writing-plans. With no split, it writes the
   one plan and its handover prompt, then returns. With a split, it writes
   only the index, then returns. Either way there is no closing message and
   no review stop.

4. **Write, then execute, one part at a time.** With no split, the plan and
   its handover prompt already exist: skip to sub-step 5, the executor.
   With a split, for each part in order:
   1. **Write the part.** Dispatch a fresh subagent on the most capable
      model available with `../writing-plans/part-writer-prompt.md`. Fill
      every placeholder. `[EARLIER_PART_PATHS]` is the part files written
      so far (`none` for part 1). `[WORKTREE_PATH]` is the worktree the
      previous executor reported (`none` for part 1).
   2. **Read the writer's report.** An open question only your human
      partner can answer is a blocker: ask it, then send the answer back to
      the writer. Settle the other questions yourself and record each one
      as a ruling. For each interface difference, update the index's
      Cross-Part Interfaces to match the code.
   3. **Check it.** Run writing-plans' cross-part check on this part.
   4. **Write its handover prompt.** Pick the part's mode and write its
      prompt as writing-plans' Execution Handoff says, then append it to the
      handover file (create the file with that layout for part 1).
   5. **Execute the part.** Dispatch a fresh executor subagent on the most
      capable model available, named explicitly, with `executor-prompt.md`
      in this directory. `[HANDOVER_PROMPT]` is the part's handover prompt,
      verbatim. `[BRANCH]` is the index's `**Branch:**` for part 1, then
      the branch the previous executor reported; with no split, the
      `<feature>` slug from the plan's file name. `[WORKTREE_PATH]` is
      `none` for part 1, then the worktree the previous executor reported.
   6. **Read the executor's report.** BLOCKED: see Blockers. DONE: keep its
      branch, worktree, and "Rulings I made" for the next part and the
      summary.

   Pass every path to writers and executors as an absolute path: an
   executor works in its own worktree, where files written after it
   branched are not there.

   Dispatch every writer and executor in the foreground and wait for its
   report (in Claude Code, `run_in_background: false`). Your next step
   needs that report, and a run nobody is watching can end while you wait
   on a background subagent, taking the subagent down with it.

   Between parts, post one status line ("Part 1 of 3 done: storage layer,
   24 tests passing.") and move to the next part without asking.

5. **Open a PR.** When the last part is done, run
   superpowers:finishing-a-development-branch from the worktree the last
   executor reported. Do not show its menu; choose for your human partner:
   - **The repo has a remote and a working CLI for its host** (for GitHub,
     `gh auth status` succeeds): take "Push and create a Pull Request".
     Push only the feature branch, never with force. Open a regular PR, not
     a draft, against the branch you noted at the start. Follow the repo's
     PR template and conventions, and put the step 6 summary in the
     description.
   - **No remote, or no working CLI:** take "Keep the branch as-is" and say
     why there is no PR. This is not a blocker.

   Never take "Merge back locally". Autopilot never merges. A rejected push
   is a blocker, not a reason to force.

6. **Summarize** in one message:
   - the PR link, or why there is none,
   - what was built, part by part,
   - tests and final-review outcomes for each part,
   - every ruling made without your human partner: each executor's "Rulings
     I made", plus the calls you made yourself (builder check, writer
     questions, index updates),
   - what was parked (deferred minors, open items),
   - where the work lives: branch and worktree.

## Blockers

A blocker stops autopilot at any stage. Stop there, without going on to
the PR or the summary, and ask your human partner: say what blocks you,
and end the message with the question they need to answer ("The
integration tests need a Stripe test key and none is set. Can you add one
to `.env`, or should I mock the API?"). Steps for them to follow are not a
question. Wait for the answer, then continue from where it stopped. A
blocker is:

- a builder-check question only they can answer,
- a part writer's open question only they can answer,
- any of the executor skills' four stop conditions: an irreversible or
  destructive operation, a security-sensitive action, an outside side
  effect such as a push or a publish, or a plan so broken that every path
  is a guess. The one exception is step 5's feature-branch push and PR:
  they pre-authorized it by asking for autopilot,
- an environment problem you cannot fix: missing credentials, a login, a
  service that is down,
- anything where a wrong guess would be expensive to undo.

Everything else is a ruling: decide it, record it, keep going. Every
ruling goes in the summary.

## Resuming After a Blocker

Relay the executor's question to your human partner, with what it needs.
Wait for the answer. Then continue the same executor with it (SendMessage
in Claude Code). If it cannot be resumed, dispatch a fresh executor with
the same handover prompt, the branch and worktree from the BLOCKED report,
and the answer, and point it at the ledger that report names. The ledger
lets it pick up where the last one stopped.

## Fallback

With no subagent tool, write each part yourself, as writing-plans says, and
run each part's handover prompt in this session with
superpowers:executing-plans, part by part. The executor prompt's limits
still hold: no finishing-a-development-branch and no push until step 5.

## Red Flags

| Thought | Reality |
|---------|---------|
| "It's automated, so I'll skip the questions." | Questions still happen. Only the review stops go away. |
| "I'll guess so I don't interrupt them." | A blocker is a question. Ask it. |
| "The PR is green, I'll merge it." | Autopilot ends at an open PR. It never merges. |
| "I'll plan all the parts now and save time." | Under autopilot, each part is written after the previous one runs, against the real code. |
| "The ruling was small, I'll leave it out of the summary." | Every ruling goes in the summary. |
| "Brainstorming says to invoke autopilot, so I'll invoke it." | Autopilot is already driving. Carry on in brainstorming. |
| "I'll list the blocker under Parked and wrap up the run." | A blocker isn't parked work. Stop at it and end your message with the question. |
| "The push was rejected, I'll force it." | Never force. A rejected push is a blocker. |
| "The executor can push its own part." | Executors never push. Autopilot pushes once, at the end. |
| "The executor will take a while, so I'll background it and pick up when it reports." | Dispatch it in the foreground and wait. If you end your turn to wait, an unattended run can end with it. |
