# Issue Tracking During Development Plan Index

**Goal:** When a repo lives on GitHub or GitLab, the superpowers workflow can keep one issue per piece of work, opened at approval, linked to a draft PR from the first commit, commented on at milestones, and closed when the work lands.
**Spec:** `docs/superpowers/specs/2026-10-28-issue-tracking-design.md`
**Branch:** `issue-tracking` (every part works on this branch; its worktree is `.worktrees/issue-tracking`)

## Global Constraints

- Personal change for the `shellkah/superpowers` fork, built on `brainstorming-deeper-not-bigger`; it does not go upstream.
- No dependency beyond the forge CLIs the workflow already uses for PRs: `gh` for GitHub, `glab` for GitLab.
- Only the session running a workflow skill (brainstorming, writing-plans, executing-plans, the subagent-driven-development controller, finishing-a-development-branch, autopilot's main session) touches the forge. Implementer, reviewer, part-writer, builder-check and cross-part-check subagents never do, and their prompts don't change.
- Under autopilot, executors never push, post or publish; autopilot's main session does every forge call. `skills/autopilot/executor-prompt.md` doesn't change.
- Every `gh` call names the repo from `origin` (`--repo <owner>/<name>`), so a fork never targets its upstream.
- Never push the default branch or the base branch without asking your human partner; never force-push.
- When tracking is off or impossible, behaviour is exactly today's: no early push, no draft PR, no new question beyond the one offer, the finishing menu word for word.
- The issue's title, body and comments, and the draft PR's title and body, follow the Writing Rules (the full PR description finishing writes stays as today): plain prose for someone who has never seen the workflow; none of `Task <n>`, `part <n> of <m>`, ledger, ruling, reviewer, subagent, executor, brief, RED/GREEN; never copies the spec or the plan; no `@mentions`; nothing from the conversation that the approved description, spec or plan doesn't already say; "merge request", not "PR", on GitLab.
- A failed forge call never stops the work and is never an autopilot blocker; the final message lists what didn't post and the command that fixes it.
- The project's voice stays ("your human partner"). The new skill is developed with `superpowers:writing-skills`, baseline first.
- `glab` commands are checked against `glab <command> --help` and marked untested until a real GitLab run.

## Acceptance

Real headless sessions against a private scratch repo, `shellkah/superpowers-issues-scratch` (created for this, holding a tiny project), using this branch's plugin (`run_claude_fork`, `--plugin-dir`). After each run, `gh` checks the result from outside the session:

1. **Small change, normal mode, new issue.** The session offers, opens the issue at approval, opens a draft PR after the first commit, and finishing option 2 marks it ready. The check then merges the PR into the default branch with `gh pr merge`, and the issue closes on its own.
2. **Small change, existing issue named in the request.** The session offers to use it, comments instead of editing, and the issue's title and body are byte-identical afterwards.
3. **Local merge with push.** The issue closes, naming the merge commit, and the draft PR shows as merged.
4. **A project under autopilot, split in two parts.** One issue; plan ready, draft PR (opened after part 1, not before), part 1 done and PR ready each posted exactly once (count the markers); part 2 updated the same issue; no executor called `gh`; the PR ends ready, not draft.

For every run: exactly one issue; assigned to shellkah; every link in the body and comments resolves; none of the Writing Rules' banned words; no `@mentions`; the status line matches the final state; the PR body has `Closes #N`.

Then a person: your human partner reads the issue from run 1 and from run 4 on their phone and says whether a collaborator who doesn't use Claude could follow the work from it. That has the final say on readability. GitLab is not run against a real server; the reference file and the final report say so.

## Parts

| Part | Name | Deliverable | Tasks (rough) | Depends on |
|------|------|-------------|---------------|------------|
| 1 | The tracking skill | `skills/tracking-work-in-issues/` (SKILL.md and `forge-commands.md`), a stand-in `gh` for tests, and behaviour tests: a session asked to track work in an issue, or handed a plan with an `**Issue:**` line, offers, opens, comments with markers, opens the draft PR, and finishes exactly as the spec says, checked against the stand-in | 4 | none |
| 2 | Workflow wiring and acceptance | Short pointers to the skill in brainstorming, writing-plans (header, index, part-writer header, handover bullet), executing-plans, subagent-driven-development, finishing-a-development-branch and autopilot; the README skills list; the four real GitHub runs and the readability check | 7 | 1 |

## Cross-Part Interfaces

### Part 1 produces

- `skills/tracking-work-in-issues/SKILL.md`: frontmatter `name: tracking-work-in-issues`, a description starting "Use when" that triggers on an `**Issue:**` link in a spec, plan, index or handover prompt, or a request to track work in an issue. It has exactly these `##` sections, which part 2's pointers cite by name: `The Offer`, `Opening the Issue`, `The Draft PR`, `Milestones`, `Finishing`, `Writing Rules`, `Failures`.
- `skills/tracking-work-in-issues/forge-commands.md`: the `gh` and `glab` command for every step the skill names (detect, repo facts, login check, search, create, comment, edit body, view with comments, assign and unassign, close with reason, draft PR create, find PR by branch, edit PR body, mark ready, close PR, PR state).
- The decision line, directly under a spec's or plan's title, one of exactly: `**Issue:** <url> (opened for this work)`, `**Issue:** <url> (existing)`, `**Issue:** none`.
- The handover bullet: ``- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.``
- Milestone markers: `<!-- superpowers:<id> -->` at the end of a comment or body, with `<id>` one of `opened`, `plan-ready`, `draft-pr`, `part-<N>-done`, `waiting-<YYYYMMDDHHMM>`, `pr-ready`, `merged`, `merged-locally`, `paused`, `dropped`; under autopilot with several builds, `draft-pr`, `part-<N>-done` and `pr-ready` take a `build-<B>-` prefix.
- The status line: the first line of the body of an issue opened for this work, `**Status:** <text>`.
- `tests/claude-code/fake-gh/gh`: an executable stand-in for `gh` covering every `gh` command in `forge-commands.md`. It reads canned state from `$FAKE_GH_STATE` (a directory), appends one JSON object per call to `$FAKE_GH_LOG` as `{"argv": [...], "body": <text of --body/--body-file/--comment, or null>}`, and exits 1 with `HTTP 401: Bad credentials` on stderr for any call whose subcommand pair (e.g. `issue comment`) matches the regex in `$FAKE_GH_FAIL`.
- In `tests/claude-code/test-helpers.sh`:
  - `setup_fake_gh <dir>`: creates `<dir>/state`, exports `FAKE_GH_STATE=<dir>/state` and `FAKE_GH_LOG=<dir>/gh.log`, and prepends `tests/claude-code/fake-gh` to `PATH`.
  - `issue_text_violations <file>`: prints every Writing Rules violation in the file, one per line, and prints nothing when the text is clean; always exits 0.
- `tests/claude-code/tracking-fixtures.sh` (sourced after `test-helpers.sh`): test repos whose `origin` reads `git@github.com:acme/widgets.git` but pushes to a local bare repo (`tracking_repo`, `tracking_env`), state seeding (`fake_issue`, `fake_pr`, …), log queries (`gh_log_count`, `gh_log_body`, …), `common_checks` and `run_moment`/`continue_moment`, as part 1's Task 1 and Task 2 Interfaces blocks give them. Part 2's wiring tests reuse these rather than building their own.
- `tests/claude-code/test-tracking-work-in-issues-integration.sh`: scenarios selectable with `TRACKING_SCENARIOS`, run in parallel with `TRACKING_JOBS`.
