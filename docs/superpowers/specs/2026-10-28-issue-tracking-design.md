# Issue Tracking During Development

Personal change for the `shellkah/superpowers` fork. It is built on
`brainstorming-deeper-not-bigger` (six commits ahead of `main` at
`057ba52`) and stays in the fork; it does not go upstream.

## Why

When a repo lives on GitHub or GitLab, your human partner wants each piece
of work recorded there, outside the filesystem, so collaborators can
follow it: an issue opened when the work is approved, kept current while
it runs, and closed when it lands.

The issue has two kinds of readers:

- **People who follow the repo but don't run Claude.** They read it as
  plain prose and should never need to know how the workflow runs.
- **People running their own superpowers sessions.** For them the issue
  also says "someone is on this", so two sessions don't start the same
  work.

Today nothing in the workflow touches issues (diagnosing-superpowers files
bug reports upstream, which is unrelated), and nothing is pushed until the
work finishes.

## Goals

- Ask once per piece of work whether to track it in an issue, when the
  repo can take one.
- One issue per piece of work: opened (or an existing one taken over) at
  approval, linked to a draft PR from the first commit, commented on at
  each milestone, closed when the work lands where collaborators can see
  it.
- The issue reads well to someone who has never seen the workflow, and it
  never copies the spec or the plan: a few sentences on what and why, then
  links.
- Later sessions (the next part of a split plan, a resumed autopilot run)
  keep updating the same issue without asking again.
- GitHub through `gh`, GitLab through `glab`.

## Non-goals

- Labels, milestones, project boards, sub-issues, one issue per part.
- Quick, clear tasks. They never touch issues. If the request names one,
  the closing line says it was left alone.
- Offering tracking anywhere but brainstorming. A spec written without
  brainstorming has no `**Issue:**` line and gets no tracking; your human
  partner can still ask for it, and the new skill's description covers
  that request.
- Closing issues after the session has ended, beyond what the forge's
  closing keywords do: no sweep at session start, no CI workflow in the
  repo.
- Forge calls without the CLI (no `curl` with a token).
- An issue on one repo and the PR on another (fork-to-upstream). The issue
  and the PR both live on the repo `origin` points to.
- A real GitLab run. Your human partner chose GitHub-only verification;
  GitLab support is written from `glab`'s documentation and marked
  untested.

## Anti-goals

- An issue that reads like a transcript of the workflow: task numbers,
  "part 2 of 3", ledger, ruling, reviewer verdicts, copied plan sections.
- Notification noise: a comment per task, `@mentions`.
- Tracking that slows or stops the build. A failed forge call never blocks
  the work.
- Posting what your human partner didn't agree to: no issue without their
  yes, and on a public repo no issue opened with text they haven't seen
  (autopilot excepted; see Opening the Issue). Comments, PR bodies and
  status edits after that go out without asking (their call).
- Two issues for the same work.

## Constraints

- No dependency beyond the forge CLIs the workflow already uses for PRs.
- Only the session running a workflow skill (brainstorming, writing-plans,
  executing-plans, the subagent-driven-development controller,
  finishing-a-development-branch, autopilot's main session) touches the
  forge. Implementer, reviewer, part-writer, builder-check and
  cross-part-check subagents never do, and their prompts don't change.
- Under autopilot, executors keep their rule: they never push, post or
  publish. Autopilot's main session does every forge call (your human
  partner's call). `executor-prompt.md` doesn't change.
- Every `gh` call names the repo from `origin` (`--repo`), so a fork
  never targets its upstream.
- Never push the default branch or the base branch without asking, and
  never force-push.
- When tracking is off or impossible, behaviour is exactly today's: no
  early push, no draft PR, no new question beyond the one offer, the
  finishing menu word for word.
- The project's voice stays ("your human partner"). The new skill is
  developed with superpowers:writing-skills, baseline first.

## What Gets Built

### One new skill, short pointers elsewhere (my call)

`skills/tracking-work-in-issues/SKILL.md` holds everything about issues:
when to offer, what to post, at which moment, and the writing rules. A
reference file beside it gives the `gh` and `glab` command for each step.
Each workflow skill gets a short pointer at its moment ("If this work
tracks an issue, <moment> as superpowers:tracking-work-in-issues says"),
so the rules live in one place and the workflow skills stay about as long
as they are.

The skill's description triggers when a spec, plan, index or handover
prompt carries an `**Issue:**` link, or when your human partner asks to
track work in an issue.

### Where the decision lives (my call)

- **Spec:** `**Issue:** <url> (opened for this work)`,
  `**Issue:** <url> (existing)`, or `**Issue:** none`, directly under the
  title. The tag tells later sessions whether they may edit the issue's
  body (my call).
- **Plan header and split-plan index:** the same line, copied from the
  spec.
- **Handover prompt:** when tracking is on, every part's prompt gets
  `- **Issue:** keep <url> current as superpowers:tracking-work-in-issues says.`
- **Small change:** no document; the session that does the work holds it.
- No line, or `none`: no tracking and no questions.
- The draft PR is found from the branch (`gh pr list --head <branch>` or
  the `glab` equivalent), not recorded anywhere.

### The offer (brainstorming)

**When.** In brainstorming's last round of questions, once the work is
sized as a small change or a project. Under autopilot this is still
before the run goes unattended.

**Whether.** Offer only when `origin` is on GitHub or GitLab (including a
self-hosted GitLab that `glab` knows), and the repo has issues turned on.
If issues are off (GitHub forks start that way), one line says so and
there is no offer. If the CLI is missing or logged out, the offer says
what to run first (`gh auth login`, installing `glab`).

**What.** Before asking, search open issues for the topic. The question
is one picker:

- "Open a new issue"
- "Use #N: <title>" for each of up to three matches; when a match is
  assigned to someone else, its description says who
- "No issue"

On a public repo, the question says the repo is public and that
everything posted can be read by anyone (your human partner's call).

**Already answered** (my call, settled while planning). A request that
asks for a new issue ("track this in an issue") is a yes to "Open a new
issue": no question. A request that names an issue still gets the
picker, with that issue first, so your human partner confirms it. If
they skip brainstorming's questions altogether, there is no offer: the
work is tracked only if the request asks for it, and the one plain line
brainstorming states then says so.

### Opening the issue

**When.** At approval: your human partner's OK on the chat description
for a small change, or on the spec for a project. Under autopilot, when
the spec is committed in step 2, since the request for a fully automated
run is the approval; for a small change under autopilot, when the
description goes out.

**A new issue.** A plain title naming the work. The body:

1. a status line (see Milestones);
2. a few sentences on what is being built and why, written from the
   approved description or spec, never copied sections;
3. the spec by path (and later the plan), turned into links once the
   branch is pushed.

It is assigned to the person logged in to the CLI (`--assignee @me`). On a
public repo in normal mode, show your human partner the exact title and
body and wait for their OK before posting (their call).

**An existing issue.** Post the same content as a comment. Assign it to
yourself if it is unassigned. Never edit its title or body: someone else
wrote them (my call).

Then, for a project, put the `**Issue:**` line in the spec and commit it.
A "No issue" answer writes `**Issue:** none`.

### The draft PR (your human partner's call)

- **First commit.** After the first commit on the work branch that its
  base doesn't have (GitHub refuses a PR with no commits), push the branch
  with `-u`, never with force, and open a draft PR against the base
  branch. Its body is one or two sentences, `Closes #N`, and links to the
  spec and the plan. It doesn't fill in the repo's PR template; finishing
  does that. The base branch is found as finishing-a-development-branch
  Step 3 finds it: named in the plan, the conversation or the branch's
  upstream, otherwise ask.
- **Then** comment on the issue with the PR link, and on an issue you
  opened, edit the body's paths into links to the files on the work
  branch.
- **After each completed task,** push again, with no comment, so the
  draft stays current (my call).
- **Who.** In executing-plans, after Task 1 completes. In
  subagent-driven-development, the controller after Task 1 completes. For
  a small change, the session doing it, after its first commit. A later
  part of a split plan finds the draft already open and only pushes.
- **Under autopilot** (your human partner's call): the main session
  pushes and opens the draft when part 1's executor reports done, then
  pushes after each later part. A one-part plan gets no draft: its PR
  opens at step 5, already ready.
- **Several PRs under autopilot** (my call): one issue for the whole run.
  Each build's PR says `Part of #N`, except the last build's, which says
  `Closes #N`. Stacked PRs don't target the default branch, so the
  non-default-base rule in Finishing applies.

### Milestones (your human partner's call)

A comment is one to three sentences of plain prose about what changed for
someone who uses or reviews the work. Each carries a hidden marker,
`<!-- superpowers:<milestone> -->`, so a resumed or later session can see
it was already posted and never posts it twice (my call). On an issue you
opened, each milestone also rewrites the status line at the top of the
body ("Planning", "Building: draft PR #14", "Waiting on a decision",
"Ready for review: PR #14", "Merged in #14", "Paused on branch `x`",
"Dropped"). An existing issue gets comments only.

| Milestone | Posted by | When |
|-----------|-----------|------|
| Plan ready | writing-plans | the plan (or index and part 1) is written; in normal mode it says the plan waits for review |
| Draft PR open | the executor, the session doing a small change, or autopilot's main session | see The Draft PR |
| A part done | the executor at its Finish; under autopilot, the main session between parts | each part of a split plan, not a one-part plan (the PR follows at once) |
| Waiting on you | whoever stops; under autopilot, the main session | the work stops mid-run for a question only your human partner can answer: an executor's blocker, an autopilot blocker |
| Ready / merged / paused / dropped | finishing-a-development-branch | see Finishing |

### Finishing

When a draft PR exists:

- **The menu.** Option 2 reads "Mark the draft PR ready for review"
  (detached HEAD: option 1 likewise). The other options keep today's text.
- **Option 2.** Push, replace the draft's description with the full one
  as today (the repo's template, the decisions made on your human
  partner's behalf) keeping `Closes #N`, mark it ready, comment on the
  issue. If the PR's base isn't the forge's default branch, the forge
  won't close the issue on merge: the comment says so, and so does the
  report to your human partner.
- **Option 1, local merge.** Once the merged result is green, ask whether
  to push the base branch (their call). If pushed: comment naming the
  merge commit and close the issue; the forge marks the draft PR merged
  on its own (verify; if it doesn't, close the PR with a comment). If not
  pushed: comment that it is merged locally and not pushed yet, and leave
  the issue and the draft open.
- **Option 3, keep as-is.** Comment that the work is paused, naming the
  branch. The draft stays open.
- **Discard.** The typed-`discard` confirmation also lists the pushed
  branch and the draft PR. On confirmation: close the draft PR, delete
  the remote branch, and close an issue you opened as "not planned" with
  a comment. An existing issue stays open: comment that this attempt was
  dropped, and unassign yourself (my call).

Under autopilot (its step 5), "Push and create a Pull Request" becomes:
push, replace the draft's description with the step 6 body file, mark it
ready. The run still ends with a regular PR, never a draft. Step 6's
summary gives the issue link next to the PR link.

### Writing rules (my call)

- Plain prose for someone who has never seen the workflow. None of: task
  numbers, "part N of M", ledger, ruling, reviewer, subagent, executor,
  brief, RED/GREEN.
- Never copy the spec or the plan. Summarize in a sentence and link.
- No `@mentions`.
- Nothing from the conversation that the approved description, spec or
  plan doesn't already say.
- On GitLab, say "merge request", not "PR".

### Failures (my call)

A forge call that fails (network, expired login, rate limit) never stops
the work, and under autopilot it is not a blocker. Note it, carry on, and
retry at the next milestone. The final message lists what didn't post and
the command that fixes it (`gh auth login`).

### GitHub and GitLab

The reference file gives each step's command for `gh` and for `glab`.
The `glab` commands are checked against `glab --help` (install `glab` in
the devbox; no login needed) and marked untested until a real GitLab run.

### Workflow pointers

Each gets a short pointer to the new skill, nothing more:

- **brainstorming:** the offer (last round of questions); opening the
  issue at approval; the small-change normal-workflow line says the new
  skill covers the issue.
- **writing-plans:** the `**Issue:**` line in the plan header and index;
  the handover bullet; the plan-ready milestone.
- **executing-plans, subagent-driven-development:** the draft PR after
  Task 1; a push after each completed task; waiting-on-you; the part-done
  milestone at Finish.
- **finishing-a-development-branch:** everything under Finishing.
- **autopilot:** step 2 opens the issue when it commits the spec; step 4
  pushes, opens the draft after part 1 and posts part-done and blocker
  comments between parts; step 5 and step 6 as under Finishing. The
  rules that executors never push stay as they are; the red flag, the
  blocker exception and the Fallback section only gain the main session's
  between-part pushes. `executor-prompt.md` doesn't change.
- **README:** the new skill in the skills list.

The version bump is left to the merge, as your human partner decides.

## How We'll Know It's Right

**The check from outside: real sessions against GitHub.** Create a
private scratch repo on shellkah's GitHub
(`shellkah/superpowers-issues-scratch`) with a tiny project, and run real
headless sessions with this branch's plugin (`--plugin-dir`). After each
run, `gh` checks the result from outside the session:

1. **Small change, normal mode, new issue.** The session offers, opens the
   issue at approval, opens a draft PR after the first commit, and
   finishing option 2 marks it ready. The check then merges the PR into
   the default branch with `gh pr merge`, and the issue closes on its own.
2. **Small change, existing issue named in the request.** The session
   offers to use it, comments instead of editing, and the issue's title
   and body are byte-identical afterwards.
3. **Local merge with push.** The issue closes, naming the merge commit,
   and the draft PR shows as merged.
4. **A project under autopilot, split in two parts.** One issue; plan
   ready, draft PR (opened after part 1, not before), part 1 done and PR
   ready each posted exactly once (count the markers); part 2 updated the
   same issue; no executor called `gh`; the PR ends ready, not draft.

For every run: exactly one issue; assigned to shellkah; every link in the
body and comments resolves; none of the writing rules' banned words; no
`@mentions`; the status line matches the final state; the PR body has
`Closes #N`.

**Fast tests** in `tests/claude-code/`, with a stand-in `gh` on `PATH`
that logs every call: no forge call at all when the spec says
`**Issue:** none` or the remote isn't a forge; a public repo shows the
issue text before posting; the offer doesn't appear for a quick task.

**A person.** Your human partner reads the issue from run 1 and from
run 4 on their phone and says whether a collaborator who doesn't use
Claude could follow the work from it. That has the final say on
readability.

**Not checked:** GitLab against a real server (your human partner's
call). The reference file and the final report say so.

## Left to the Builder

- Exact wording of the offer, the comments and the status line, within
  the writing rules.
- The `gh`/`glab` commands in the reference file, checked against each
  CLI's `--help`.
- How the markers are looked up before posting.
- Where each pointer sits inside each workflow skill.
- Which fast tests to add beyond the three named, and the scratch repo's
  toy project (small enough that run 4 splits into two parts).
- Where the base branch is recorded so a normal-mode executor rarely has
  to ask for it after Task 1.
- Whether to keep or delete the scratch repo afterwards: ask your human
  partner at the end. Deleting it needs the `delete_repo` scope, which
  the current login lacks; your human partner runs
  `gh auth refresh -s delete_repo` if they want it gone.

## Run notes

Settled with your human partner on 2026-10-29, when autopilot took over
the run after part 1 was written.

- **Services:** none; the work needs none.
- **Checkpoints:** no. The run goes straight through to the PR.
- **PRs:** one, from `issue-tracking` against
  `brainstorming-deeper-not-bigger` on `shellkah/superpowers` (a fork:
  every `gh pr` call passes `--repo shellkah/superpowers`).
- **Pre-flight, passed:** `gh --version`, `gh auth status` (shellkah,
  scopes `gist`, `read:org`, `repo`), `glab --version`, `claude --version`,
  `jq --version`, `python3 --version`,
  `tests/claude-code/test-executing-plans-scripts.sh`, and one headless
  `run_claude_fork` session with this branch's plugin.
- **Not yet consented:** creating `shellkah/superpowers-issues-scratch`,
  and the four acceptance sessions against it (issues, comments, pushes,
  draft PRs, `gh pr merge`). Part 1 needs neither. Until these notes say
  otherwise, stop before any step that runs them.
