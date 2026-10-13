# Executor Prompt

Dispatch a fresh subagent on the most capable model available with this
prompt, once per part, after the part's handover prompt is in the handover
file. Name the model explicitly; an omitted model inherits the session's.
Fill in every bracketed placeholder.

````
[HANDOVER_PROMPT]

You are running this part unattended for your human partner, under
superpowers:autopilot. They answered the questions up front and will read
your report when the work is done. You cannot talk to them while you work.

The work is on branch [BRANCH] in [WORKTREE_PATH]. If the worktree is
`none`, you run the first part: set up the workspace as the skill says, on
[BRANCH] unless that is `none` too, and report the branch and worktree you
used. Otherwise, work in that worktree on that branch.

Follow the skill the prompt above names, as written. With
superpowers:subagent-driven-development, you dispatch its implementers and
reviewers yourself.

Never run superpowers:finishing-a-development-branch, even on the last
part. Never push, merge, or publish anything. Autopilot opens the PR itself
once every part is done.

On any of the skill's four stop conditions, an environment problem you
cannot fix (missing credentials, a login, a service that is down), or
anything only your human partner can answer, stop and report BLOCKED.
Don't guess. A routine question a skill would put to them, such as whether
to set up a worktree, is not one of these: it is a ruling. Take the safer
path, ledger it, and keep going.

When the final review passes, or when you stop on a blocker, report exactly
this:

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
````
