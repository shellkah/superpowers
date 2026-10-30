# Handover: Issue Tracking During Development

**Spec:** `docs/superpowers/specs/2026-10-28-issue-tracking-design.md`

## Part 1 of 2: The tracking skill

Execute part 1 of 2 of the implementation plan at `docs/superpowers/plans/2026-10-29-issue-tracking-part-1-tracking-skill.md` (spec: `docs/superpowers/specs/2026-10-28-issue-tracking-design.md`).

- **Skill:** use `superpowers:subagent-driven-development`.
- **Why this mode:** four tasks that each build on a strict contract (the stand-in `gh`, then the tests written against it, then the skill that must pass them), so a fresh review after each task catches a contract slip before the next task builds on it.
- **Branch:** work on branch `issue-tracking`.
- **Workspace:** set up the workspace as the skill says.
- **Not the last part:** when the final review passes, report and stop without running `superpowers:finishing-a-development-branch`; the next part continues on this branch. Before you stop, check off every task of this part in its plan file: the next part's completeness check reads those checkboxes. Before the plan's workspace is deleted, add a `## Rulings` section at the end of that file with every `Ruling:` and `minor (deferred)` line from the ledger: the next part's writer plans against them.

## Part 2 of 2: Workflow wiring

Execute part 2 of 2 of the implementation plan at `docs/superpowers/plans/2026-10-29-issue-tracking-part-2-workflow-wiring.md` (spec: `docs/superpowers/specs/2026-10-28-issue-tracking-design.md`).

- **Skill:** use `superpowers:subagent-driven-development`.
- **Why this mode:** seven tasks that each change either the test harness part 1's tests rely on or a workflow skill that every one of your human partner's sessions runs through, so a fresh review of each task before the next builds on it is worth its cost.
- **Branch:** work on branch `issue-tracking`.
- **Previous part:** continue on that branch in the worktree part 1 used. First check that part 1 is complete: every task in its plan file is checked off (its executor ticks them only after its final review passes). If it is not, stop and say so.
