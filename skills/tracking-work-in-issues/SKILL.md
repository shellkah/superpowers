---
name: tracking-work-in-issues
description: "Use when a spec, plan, plan index or handover prompt carries an **Issue:** link, or when your human partner asks to track work in a GitHub or GitLab issue or names an issue for the work"
---

# Tracking Work in Issues

When a repo lives on GitHub or GitLab, your human partner can have each
piece of work tracked in one issue: opened (or an existing one taken over)
at approval, linked to a draft PR from the first commit, commented on at
each milestone, and closed when the work lands. Its readers follow the repo
without running Claude, or run their own sessions and need to see that
someone is on this.

**Only the session running brainstorming, writing-plans, executing-plans,
the subagent-driven-development controller, finishing-a-development-branch
or autopilot's main session does any of this.** Stop here if you are a
subagent (an implementer, a reviewer, a part writer, a builder check, a
cross-part check), or if your prompt says you are running a part
unattended under superpowers:autopilot (an autopilot executor), even while
you run executing-plans or the subagent-driven-development controller.
Autopilot's main session, which dispatches that executor, is not one. The
session that dispatched you makes every forge call, even when your prompt
carries an `**Issue:**` line. Make no `gh` or `glab` call, not even a
read, and no push. Say in your report that you left the issue to that
session.

**Red flags**

| Thought | Reality |
|---------|---------|
| "I'm running this part under autopilot, but reading the issue is harmless" | No forge call at all, reads included. The main session reads and writes. |
| "The quick fix is done, I'll close the issue they mentioned" | Quick tasks never touch issues. Leave it and say so. |

**The decision** is one line, directly under the spec's title, with one
blank line between:

- `**Issue:** <url> (opened for this work)`
- `**Issue:** <url> (existing)`
- `**Issue:** none`

The plan header and a split plan's index copy it from the spec. When
tracking is on, every handover prompt gets this bullet:

```
- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.
```

A small change has no document: the session doing it holds the decision.
The tag says whether you may edit the issue's body: only an issue opened
for this work. Once a spec or plan exists, no line, or `none`, means no
tracking: no forge call, no early push, no draft PR, no question, and the
workflow runs exactly as it does without this skill. A line already there
means the decision is made: never offer or open again.

**Quick, clear tasks** never touch issues. If the request names one, leave
it alone (no forge call) and say so in your closing line.

**Commands.**

- Each step's command, for `gh` and `glab`, is in `forge-commands.md` in
  this directory. Steps are named by its headings, in parentheses:
  (Find PR by branch). Run them as written there.
- Every `gh` call names the repo from `origin` with `--repo <owner>/<name>`,
  reads included: `gh issue view 12 --repo acme/widgets`, never a bare
  `gh issue view 12`.
- Write each body or comment to a temporary file outside the repo
  (`mktemp`) and pass the file, so no stray file lands in the work tree.
  Fill it with the Write tool or a quoted heredoc (`<<'EOF'`), so `$` and
  backticks stay literal. Titles go in single quotes, without `$` or
  backticks; a title with an apostrophe goes in double quotes instead.
- The draft PR is found from the branch (Find PR by branch), never
  recorded.
- Never push the default branch or the base branch without asking; never
  force-push.

## The Offer

**When:** in brainstorming's last round of questions, once the work is
sized as a small change or a project. Under autopilot, still before the
run goes unattended. Nothing is posted before approval.

**Whether.** Check in order; the first that fails settles it:

1. (Detect) A remote that isn't on GitHub or GitLab (no origin, a local
   path, another host) gets no offer and no forge call. If the request
   asked for tracking, say in one line that origin isn't on GitHub or
   GitLab, and carry on without it.
2. (Login check) If the CLI is missing or logged out, still offer, saying
   what to run first (`gh auth login`; for GitLab, install `glab`, then
   `glab auth login`). Skip the steps below: there is nothing to search.
3. (Repo facts) If issues are turned off, say in one line that the repo
   has issues turned off (GitHub forks start that way), and make no offer
   and no further forge call. Otherwise note the visibility and the
   default branch.

**What:**

- Search open issues for the topic (Search; up to three).
- Ask one picker question, batched into brainstorming's last round, with
  these options:
  - `Open a new issue`
  - `Use #N: <title>` for each match; when it is assigned to someone
    else, its description says who
  - `No issue`
- List your pick first, marked `(Recommended)` as brainstorming says: the
  issue the request names, else a match that is clearly this work, else
  `Open a new issue`.
- On a public repo, the question says the repo is public and that
  everything posted there can be read by anyone. On a private repo, say
  nothing about visibility.
- With no question tool, ask in plain text with numbered options.

**Already answered.** A request for a new issue ("track this in an issue")
is a yes to `Open a new issue`: no question. A request that names an issue
still gets the picker, with that issue first. If your human partner skips
brainstorming's questions, there is no offer: the work is tracked only if
the request asks, and brainstorming's one plain line says so.

**Red flags**

| Thought | Reality |
|---------|---------|
| "origin is a local path, but `gh` answers, so I'll file it there" | origin decides. Not on GitHub or GitLab: no forge call. |
| "Issues are off, but a quick search can't hurt" | One line says issues are off. No offer, no search. |

## Opening the Issue

**When:**

- At approval: your human partner's OK on the chat description for a
  small change, or on the spec for a project.
- Under autopilot: when the spec is committed in step 2, or for a small
  change, when the description goes out.

**First:**

- A resumed session whose issue already carries
  `<!-- superpowers:opened -->` after its last `dropped` marker (View with
  comments) doesn't post again.
- If the offer was made while the CLI was logged out, Repo facts and
  Search never ran: run them now. Issues off: no issue, and one line says
  so. A public repo: show the text first (below). An open match: ask the
  picker again before posting anything; under autopilot, don't ask: open
  the issue as decided and name the match in the summary.

**A new issue** (Create):

- A plain title naming the work.
- The body, in order:
  1. `**Status:** Planning` for a project, `**Status:** Building` for a
     small change;
  2. a blank line;
  3. a few sentences, in your own words, on what is being built and why,
     from the approved description or spec;
  4. for a project, the spec's path in inline code;
  5. the last line, `<!-- superpowers:opened -->`.
- Assign it to yourself (`--assignee @me`).

**An existing issue:**

- Post the same content, without the status line, as a comment ending
  with the opened marker (Comment).
- Assign yourself if it is unassigned (Assign and unassign).
- Never edit its title or body: someone else wrote them.

**Public repo, normal mode:**

- Before the first post, show your human partner the exact title and text
  in a fenced block, for a new issue or for the opening comment on an
  existing one. Say the repo is public. Post only after their OK, and post
  exactly what you showed.
- Under autopilot, post without waiting.
- After this first post, comments, PR bodies and status edits go out
  without asking.

**Then:**

- For a project, put the decision line under the spec's title and commit
  the spec. "No issue" writes `**Issue:** none`.
- A small change writes nothing.
- If Create fails, write no line; see Failures.

**Red flags**

| Thought | Reality |
|---------|---------|
| "The repo is public, but they said to track it, so I'll post" | Asking for tracking is not seeing the text. Show it and wait for their OK. |
| "I'll edit the existing issue's title so it fits" | Someone else wrote it. Comment; never edit its title or body. |

## The Draft PR

**When and who:**

- After the first commit on the work branch that its base doesn't have.
- executing-plans and the subagent-driven-development controller: after
  Task 1 completes. The session doing a small change: after its first
  commit. A later part of a split plan finds the draft already open and
  only pushes.
- Under autopilot: the main session, when part 1's executor reports done;
  then it pushes after each later part. A one-part plan under autopilot
  gets no draft: its PR opens at step 5, already ready.

**Not on the default or base branch** (the default from Repo facts): work
committed on either gets no early push and no draft PR.

**Find it first** (Find PR by branch): never open a second while one is
open; a closed or merged PR from an earlier attempt doesn't count.

**The base branch.** Before the draft exists, the base is, in order: the
branch named in the plan, the handover prompt or the conversation; the
work branch's upstream, when that names another branch; in a separate
worktree, the branch checked out in the main checkout, when that isn't the
work branch; otherwise ask. Once the draft is open, its `baseRefName` is
the record: every later session reads it and never asks again.

**Steps:**

1. `git push -u origin <branch>`, never forced.
2. Draft PR create against the base. A plain title. A body of one or two
   sentences, `Closes #N`, and links to the spec and the plan on the work
   branch (link forms in Detect); not the repo's PR template, which
   Finishing fills in.
3. Comment on the issue with the PR's full URL, ending
   `<!-- superpowers:draft-pr -->`.
4. On an issue opened for this work: status `Building: draft PR #P`, and
   the body's paths turned into links.

**After each completed task:** push, with no comment. If the draft never
opened (an earlier failure), open it now.

**Several PRs under autopilot:**

- One issue for the whole run. Each build's PR says `Part of #N`, except
  the last build's, which says `Closes #N`.
- That build's `draft-pr`, `part-<N>-done` and `pr-ready` markers take a
  `build-<B>-` prefix: `<!-- superpowers:build-2-draft-pr -->`.
- Stacked PRs don't target the default branch, so Finishing's
  non-default-base rule applies.

## Milestones

**A comment** is one to three sentences of plain prose about what changed,
for someone who uses or reviews the work, then the marker alone on the
last line: `<!-- superpowers:<id> -->`.

**Before posting,** look the marker up in the body and every comment (View
with comments). Only markers after the last `dropped` marker count. If
it's there, don't post again, but still bring the status line up to date.

**The status line.** On an issue opened for this work, each milestone
rewrites the body's first line, `**Status:** <text>`, and keeps the rest
(Edit body): the comment first, then the status edit. An existing issue
gets comments only.

| Milestone | Marker id | Posted by | When | Status text |
|-----------|-----------|-----------|------|-------------|
| Opened | `opened` | brainstorming; autopilot's main session | approval (Opening the Issue) | `Planning` (project), `Building` (small change) |
| Plan ready | `plan-ready` | writing-plans | the plan (or the index and part 1) is written | `Planning`; under autopilot `Building` |
| Draft PR open | `draft-pr` | see The Draft PR | after the first commit | `Building: draft PR #P` |
| A part done | `part-<N>-done` | executing-plans or the subagent-driven-development controller at its Finish; under autopilot, the main session between parts | each part of a split plan except the last | unchanged |
| Waiting on you | `waiting-<YYYYMMDDHHMM>` | whoever stops; under autopilot, the main session | the work stops for a question only your human partner can answer | `Waiting on a decision`; when the work resumes, the previous text again, with no comment |
| Ready, merged, paused, dropped | `pr-ready`, `merged`, `merged-locally`, `paused`, `dropped` | finishing-a-development-branch | see Finishing | see Finishing |

- **Plan ready**, on an issue opened for this work, also adds the plan's
  path (the index's, for a split plan) to the body, above the marker. In
  normal mode its comment says the plan waits for review.
- **A part done** says what the finished part gives a user, never which
  part of how many.
- **Waiting on you** says what decision the work waits on, in the spec's
  terms. The time is UTC: `date -u +%Y%m%d%H%M`.
- **On GitLab,** comments and status texts say "merge request" and `!P`.

## Finishing

When this work tracks an issue (status edits only on an issue opened for
this work; an existing issue gets the comments alone):

**The menu.** When a draft exists, option 2 reads `Mark the draft PR ready
for review` (on a detached HEAD, option 1 does), and the other options keep
today's text. With no draft, the menu is today's, word for word.

**Mark the draft PR ready:**

- Push. Replace the draft's description with the full one, as today (the
  repo's template, the decisions made on your human partner's behalf),
  keeping `Closes #N` (or `Part of #N`) (Edit PR body). Then Mark ready,
  comment `pr-ready`, and set the status to `Ready for review: PR #P`.
- If the PR's base isn't the forge's default branch, the forge won't close
  the issue on merge: the comment says so, and so does your report.
- With no draft, option 2 opens the PR as today, with `Closes #N` in its
  description, then the same comment and status.

**Merge locally:**

- Once the merged result is green, ask whether to push the base branch:
  their call.
- Pushed: comment naming the merge commit (`git rev-parse --short <base>`)
  with `merged`, close the issue as completed (Close with reason), then
  check the PR (PR state). The forge normally marks the draft merged on
  its own; if it still shows open, check once more a few seconds later,
  and only then close the PR with a comment naming the merge commit
  (Close PR). The status is `Merged in #P`, or
  `Merged in <short sha>` when you had to close the PR.
- Not pushed: comment that the work is merged locally and not pushed yet
  (`merged-locally`), with status `Merged locally, not pushed yet`. The
  issue and the draft stay open.

**Keep as-is:** comment that the work is paused, naming the branch
(`paused`), with status ``Paused on branch `<branch>` ``. The draft stays
open.

**Discard:**

- The typed-`discard` confirmation also lists the pushed branch and the
  draft PR.
- On confirmation: close the draft PR (Close PR), then delete the pushed
  work branch on the remote (`git push origin --delete <branch>`), never
  the default or base branch.
- An issue opened for this work: comment (`dropped`), close it as not
  planned, status `Dropped`.
- An existing issue stays open: comment that this attempt was dropped
  (`dropped`), and unassign yourself.

**Under autopilot,** step 5's "Push and create a Pull Request" becomes:

- Push, replace the draft's description with the step 6 body file
  (keeping `Closes #N` or `Part of #N`), mark it ready, and comment
  `pr-ready`.
- With no draft (a one-part plan), open the PR as step 5 says, with
  `Closes #N` in the body file, then comment.
- The run ends with a regular PR, never a draft. Step 6's summary gives the
  issue link next to the PR link.

**Final message:** it lists what didn't post (Failures).

## Writing Rules

The reader follows the repo and has never seen this workflow. Write about
the work: what it is, why, and what changed for someone who uses or
reviews it.

- An issue body is a status line, a few sentences, and links.
- A comment is one to three sentences and its marker.
- A draft PR body is one or two sentences, `Closes #N`, and links.
- Summarize the spec or plan in a sentence of your own and link to it.

**Before posting, check the text has none of:**

- task numbers or "part N of M";
- ledger, ruling, reviewer, subagent, executor, brief, RED, GREEN;
- copied sentences or sections of the spec or plan;
- `@mentions`;
- anything from the conversation that the approved description, spec or
  plan doesn't say;
- on GitLab, "PR".

These rules cover the issue's title, body and comments, and the draft PR's
title and body. The full PR description Finishing writes stays as today.

## Failures

- A failed forge call (network, expired login, rate limit), or a rejected
  early push, never stops the work, and under autopilot it is not a
  blocker. Note it and carry on.
- Never force a push, and never retry by another route (no `curl` with a
  token).
- Retry at the next milestone, after the marker check. A draft that never
  opened is retried at the next completed task's push.
- If opening the issue failed, write no `**Issue:**` line until a retry
  succeeds. Before retrying Create, Search for the same title: a timeout
  may have created it. An open match carrying the opened marker is yours:
  use it.
- The final message lists what didn't post and the command that fixes it
  (`gh auth login`, `glab auth login`). Under autopilot, keep that list in
  `state.md` with the pending items until the summary.

**Red flags**

| Thought | Reality |
|---------|---------|
| "The comment failed, I'll use curl with the token" | Never another route. Note it, carry on, retry at the next milestone. |
