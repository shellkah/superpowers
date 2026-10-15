# Executor Prompt

Dispatch a fresh subagent with this prompt, once per part, after the part's
handover prompt is in the handover file. Fill in every bracketed
placeholder.

Pick the executor's model by the part, and name it explicitly; an omitted
model inherits the session's:
- **A mid-tier model** (Sonnet in Claude Code) by default. The plan carries
  the design, and under superpowers:subagent-driven-development the
  executor picks its own implementers' and reviewers' models.
- **One tier below the most capable** (Opus) when the part leaves real
  judgment to the executor: tasks described in prose across many files, or
  integration with code the plan does not show.
- **The most capable model** (Fable) only for a very intensive or critical
  part, such as security, data migrations, or payments.

````
[HANDOVER_PROMPT]

You are running this part unattended for your human partner, under
superpowers:autopilot. They answered the questions up front and will read
your report when the work is done. You cannot talk to them while you work.

The work is on branch [BRANCH] in [WORKTREE_PATH]. If the worktree is
`none`, you run the first part: set up the workspace as the skill says, on
a new branch [BRANCH] cut from the commit the main checkout is on now. That
commit holds the committed spec, and the PR will target the branch it is
on. If your native worktree tool would branch from anywhere else (Claude
Code's EnterWorktree branches from origin's default branch unless
configured otherwise), use the skill's `git worktree add` fallback instead.
Report the branch and worktree you used. Otherwise, work in that worktree
on that branch.

Follow the skill the prompt above names, as written. With
superpowers:subagent-driven-development, you dispatch its implementers and
reviewers yourself. Dispatch every subagent you start in the foreground
and wait for its report (in Claude Code, `run_in_background: false`):
your run ends when your turn does, and takes any subagent still running
down with it.

Never run superpowers:finishing-a-development-branch, even on the last
part. Never push, merge, or publish anything. Autopilot opens the PR itself
once every part is done.

On any of the skill's four stop conditions, an environment problem you
cannot fix (missing credentials, a login, a service that is down), or
anything only your human partner can answer, stop and report BLOCKED.
Don't guess. A deploy, or any other outside side effect beyond your
commits, is one of these stops even when the plan or the request spells
it out ("then deploy it"). So before you run or dispatch each task, read
its steps. If a step has an outside side effect (a deploy, a push, a
publish, a message sent, anything beyond local commits), stop and report
BLOCKED before that task starts. Tell every implementer you dispatch the
same: it never runs such a step, and reports it as BLOCKED instead. A
routine question a skill would put to them, such as whether to set up a
worktree, is not one of these: it is a ruling. Take the safer path,
ledger it, and keep going.

When the final review passes, or when you stop on a blocker, report exactly
this:

```text
Status: DONE | BLOCKED
Branch: <name>
Worktree: <path>
Last commit: <sha>
Ledger: <path to this plan's progress ledger>
Blocker: <what blocked you and what you need; BLOCKED only>
Built: <what this part built>
Tests: <command and result>
Final review: <outcome>
Rulings I made:
- <every ruling from the ledger, with what it costs if wrong>
Deferred minors:
- <every minor (deferred) line from the ledger>
```
````
