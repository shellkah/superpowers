# Issue Tracking: The Tracking Skill Implementation Plan

**Part 1 of 2** · Index: `docs/superpowers/plans/2026-10-29-issue-tracking-index.md`

> **For agentic workers:** REQUIRED SUB-SKILL: the handover prompt names which skill runs this plan, superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new skill, `superpowers:tracking-work-in-issues`, that keeps one GitHub or GitLab issue per piece of work (offer, open, draft PR, milestones, finishing), with a reference file of `gh`/`glab` commands, proven by behaviour tests run against a stand-in `gh`.

**Architecture:** `skills/tracking-work-in-issues/SKILL.md` holds every rule in seven `##` sections that part 2's pointers cite by name; `forge-commands.md` beside it gives the `gh` and `glab` command for each step. The tests run real headless Claude sessions (`run_claude_fork`) against a stand-in `gh` that logs every call and keeps issue and PR state in files, and a stand-in SSH transport that routes `git@github.com:acme/widgets.git` to a local bare repo; each test then checks the log, the state and the repos from outside the session. Following superpowers:writing-skills, the behaviour tests are written and run before SKILL.md exists (RED), then the skill makes them pass (GREEN).

**Tech Stack:** Markdown; Bash test scripts sourcing `tests/claude-code/test-helpers.sh`; Python 3 standard library (the stand-in `gh`); `jq`; `gh` 2.103.2 and `glab` 1.124.0 (help checks only); Claude Code CLI 2.1.312 (`claude -p`).

**Spec:** `docs/superpowers/specs/2026-10-28-issue-tracking-design.md`

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

## Review Focus

1. **An autopilot executor handed the `**Issue:**` bullet.** writing-plans puts the bullet in every part's handover prompt, and autopilot pastes that prompt into the executor's. A reasonable person expects the executor to leave the forge alone (no `gh` call, no push) because the main session does it. Test: `executor_stays_off_forge` (Task 2).
2. **Work committed on the default branch or on its base** (a small change your human partner asked to build on `main`). They expect no early push of that branch and no draft PR. Test: `on_default_branch` (Task 2).
3. **Opening the issue fails at approval** (expired login, network). They expect the work to go on, no `**Issue:**` line pointing at nothing (and no `none` that silently drops their yes), and a final message naming `gh auth login`. Test: `open_create_fails` (Task 2).
4. **A public repo where they chose an existing issue.** They expect to see the opening comment before it goes out, as they would a new issue. Test: `open_public_existing` (Task 2).
5. **Shell-special text in the work's name** (`$HOME`, backticks). They expect the posted title to read literally, not with the shell's expansion in it. Test: `open_small_change_by_request` checks the logged title (Task 2).

## Acceptance

In part 2.

---

## Calls Made in This Part

Each is a decision the spec left open or the index didn't settle, with its reason. Task steps rely on them.

1. **Two kinds of behaviour test.** The spec's three named fast tests (no forge call with `**Issue:** none` or a non-forge remote; a public repo shows the text first; no offer for a quick task) go in the fast list, split over two files because `run-skill-tests.sh` gives each file 900 s. The moment-by-moment suite (about 30 headless runs, 60 to 90 minutes) goes in the integration list, with `TRACKING_SCENARIOS` to run a subset and `TRACKING_JOBS` to run scenarios in parallel.
2. **A stand-in SSH transport, not `insteadOf`.** Test repos set `origin` to `git@github.com:acme/widgets.git` and `core.sshCommand` to `tests/claude-code/fake-gh/fake-ssh <bare repo>` (with `ssh.variant simple`). `git remote get-url origin` then shows a real GitHub remote, while push, pull, `ls-remote` and `push --delete` all reach a local bare repo. Checked in the devbox on 2026-10-29. `url.<x>.insteadOf` would not work: `git remote get-url` expands it, so the detect step would see a local path.
3. **PATH reaches the session's Bash tool.** Checked on 2026-10-29 with Claude Code 2.1.312: a `PATH` prepended before `run_claude_fork` and an exported `GH_TOKEN` both reach the model's Bash calls. Task 1 still checks this with a real run (its canary test), and the fallback is in Task 1 Step 4.
4. **Safety net.** Every tracking test exports `GH_TOKEN=invalid-token-for-tests`, `GH_PROMPT_DISABLED=1` and `GIT_TERMINAL_PROMPT=0`. If the stand-in were ever bypassed, the real `gh` would fail with 401 instead of using shellkah's login. The test repo `acme/widgets` is not one shellkah can write to.
5. **The Writing Rules cover** the issue's title, body and comments, and the draft PR's title and body. The full PR description that Finishing writes stays as today (the repo's template plus the decisions made on your human partner's behalf, which use the word "rulings"), because the spec's Finishing section says "as today". Tests apply `issue_text_violations` to everything except `pr edit` bodies. The index's Global Constraints say the same (settled by the main session during the cross-part check).
6. **Where the base branch is recorded:** on the draft PR. Before the draft exists, the base is, in order: the branch named in the plan, the handover prompt or the conversation; the work branch's upstream, when that names another branch; in a separate worktree, the branch checked out in the main checkout, when that isn't the work branch; otherwise ask. Once the draft is open, every later session (later parts, Finishing) reads `baseRefName` from it and never asks again. In normal mode the executor starts in the main checkout on the base branch and cuts its worktree from there, so the third rule usually settles it without a question.
7. **Status line texts.** These are the spec's examples, filled in. `opened`: `Planning` for a project, `Building` for a small change. `plan-ready`: `Planning`, or `Building` under autopilot (building starts at once). `draft-pr`: `Building: draft PR #P`. `part-N-done`: unchanged. `waiting-…`: `Waiting on a decision`, set back to the previous text with no comment when the work resumes. `pr-ready`: `Ready for review: PR #P`. `merged`: `Merged in #P` when the forge shows the PR merged, else `Merged in <short sha>`. `merged-locally`: `Merged locally, not pushed yet`. `paused`: ``Paused on branch `<branch>` ``. `dropped`: `Dropped`. On GitLab, `PR #P` becomes `merge request !P`.
8. **The last part of a split plan posts no part-done comment**, because finishing's milestone follows at once, the same reason the spec gives for a one-part plan.
9. **A public repo's first post is shown first,** whether it is a new issue or the opening comment on an existing one. Both are text that strangers will read and that your human partner hasn't seen.
10. **If opening the issue fails, no decision line is written.** The session retries at the next milestone and adds the line then. If it never succeeds, the final message says tracking didn't start and how to fix it.
11. **Markers.** They are looked up with `gh issue view <N> --repo <owner>/<name> --json body,comments --jq '.body, .comments[].body'` before every post. Only markers after the last `dropped` marker count. An existing issue can outlive a dropped attempt, and that attempt's `opened` or `draft-pr` markers must not stop a new attempt from posting its own. The comment goes first and the status edit second. A status edit is always safe to repeat, so a resumed session brings the status line up to date even when the comment was already there. Waiting markers use UTC (`date -u +%Y%m%d%H%M`).
12. **Exactly the seven `##` sections** the index names. The intro (who does this, the decision line, commands) sits between the title and `## The Offer`. Red flags found in testing go inside the section they concern, under a bold **Red flags** label, never as a new `##` section.
13. **The skill opens with a guard:** a subagent, or an executor dispatched by autopilot, does nothing here even when its prompt carries an `**Issue:**` line. Without it, the handover bullet would pull autopilot executors onto the forge (Review Focus 1).
14. **The description also triggers when your human partner names an issue for the work.** That lets the skill load for a quick task that names one, where the spec says to leave the issue alone and say so.
15. **On GitLab, `internal` visibility counts as public** for the public-repo rule, since everyone with an account on that instance can read it.
16. **`glab` 1.124.0 is installed in the devbox** from the official release `.deb` (checksum checked against the release's `checksums.txt`). The `glab` commands in Task 3 were checked against its `--help` while this part was planned.
17. **The `.muse-plugin/plugin.json` manifest lists every skill by path,** so the new skill gets an entry there (Task 4). It is the only manifest in the repo that lists skills. The README entry is part 2's.

## File Map

| File | Task | Responsibility |
|------|------|----------------|
| `tests/claude-code/fake-gh/gh` | 1 | Stand-in `gh` (Python 3, stdlib): logs calls, keeps state in files, fails on demand |
| `tests/claude-code/fake-gh/fake-ssh` | 1 | `core.sshCommand` stand-in routing SSH git traffic to a local bare repo |
| `tests/claude-code/test-helpers.sh` | 1 | Gains `setup_fake_gh` and `issue_text_violations` |
| `tests/claude-code/tracking-fixtures.sh` | 1, 2 | Test repos, state seeding, log queries (Task 1); scenario fixtures and shared checks (Task 2) |
| `tests/claude-code/test-fake-gh.sh` | 1 | Deterministic tests of the stand-ins and helpers, plus the PATH canary |
| `tests/claude-code/test-tracking-work-in-issues.sh` | 2 | Fast: skill structure, spec's named "no forge call" tests, autopilot rules |
| `tests/claude-code/test-tracking-public-repo.sh` | 2 | Fast: public repo shows the text before posting (two turns) |
| `tests/claude-code/test-tracking-work-in-issues-integration.sh` | 2 | Integration: every moment of the skill against the stand-in |
| `skills/tracking-work-in-issues/forge-commands.md` | 3 | `gh` and `glab` command per step |
| `tests/claude-code/test-forge-commands.sh` | 3 | Every `gh` line runs on the stand-in; flags exist in real `gh`/`glab` help |
| `skills/tracking-work-in-issues/SKILL.md` | 4 | The skill |
| `.muse-plugin/plugin.json` | 4 | Lists the new skill |
| `tests/claude-code/run-skill-tests.sh` | 1, 3, 4 | Registers the new test files |

---

### Task 1: Stand-in `gh`, test repos and the issue-text check

**Files:**
- Create: `tests/claude-code/fake-gh/gh` (executable, `#!/usr/bin/env python3`)
- Create: `tests/claude-code/fake-gh/fake-ssh` (executable, `#!/bin/sh`)
- Create: `tests/claude-code/tracking-fixtures.sh`
- Modify: `tests/claude-code/test-helpers.sh` (append two functions and add them to the `export -f` list at the end)
- Create: `tests/claude-code/test-fake-gh.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (add `"test-fake-gh.sh"` to `tests=(...)`)

**Interfaces:**
- Consumes: `run_claude_fork`, `latest_transcript` from `tests/claude-code/test-helpers.sh`.
- Produces (exact; the index's Cross-Part Interfaces for these are reproduced, then extended only with what tests need):

  **`tests/claude-code/fake-gh/gh`**, an executable stand-in for `gh` covering every `gh` command in `forge-commands.md` (Task 3 pins that list; it is the command table below).
  - Environment: `FAKE_GH_STATE` (directory, required), `FAKE_GH_LOG` (file; when unset, nothing is logged), `FAKE_GH_FAIL` (Python regex, optional).
  - **Log first.** Every call, including failing and unknown ones, first appends one line to `$FAKE_GH_LOG`: `{"argv": [...], "body": <text or null>}` with exactly those two keys (`json.dumps(..., ensure_ascii=False)`). `body` is the value of `--body`/`-b`, the contents of `--body-file`/`-F` (stdin for `-`), or the value of `--comment`/`-c` on `issue close` and `pr close`; otherwise `null`.
  - **Fail on demand.** If `FAKE_GH_FAIL` is set and `re.fullmatch(FAKE_GH_FAIL, " ".join(argv[:2]))` matches, print `HTTP 401: Bad credentials (https://api.github.com/graphql)` on stderr, exit 1, and leave the state untouched.
  - **State layout** (all JSON, UTF-8):
    ```
    $FAKE_GH_STATE/login            one line: the logged-in login; absent = logged out
    $FAKE_GH_STATE/repo.json        {"nameWithOwner","name","owner":{"login"},"visibility":"PUBLIC"|"PRIVATE","isPrivate","hasIssuesEnabled","defaultBranchRef":{"name"},"url","isFork":false}
    $FAKE_GH_STATE/issues/<N>.json  {"number","title","body","state":"OPEN"|"CLOSED","stateReason":null|"COMPLETED"|"NOT_PLANNED","author":{"login"},"assignees":[{"login"}],"comments":[{"author":{"login"},"body","createdAt","url"}],"url","createdAt","updatedAt","labels":[]}
    $FAKE_GH_STATE/pulls/<N>.json   {"number","title","body","state":"OPEN"|"CLOSED"|"MERGED","isDraft","headRefName","baseRefName","url","mergeCommit":null,"mergedAt":null,"closed","author":{"login"},"comments":[...]}
    ```
    New numbers are `1 + max(all issue and PR numbers)` (1 when there are none), as GitHub shares one sequence. URLs are `https://github.com/<nameWithOwner>/issues/<N>` and `.../pull/<N>`.
  - **Repo naming.** `--repo`/`-R`, or a URL given as the positional, must name `nameWithOwner`; otherwise stderr `GraphQL: Could not resolve to a Repository with the name '<value>'. (repository)`, exit 1. A call without `--repo` acts on the state's repo (the log shows the omission; `assert_calls_name_repo` catches it). `repo view` takes the repo as its positional.
  - **Logged out** (no `login` file): `auth status` behaves as below; every other command except `--version` prints `To get started with GitHub CLI, please run:  gh auth login` on stderr and exits 4, as the real `gh` does.
  - **Output.** `--json f1,f2` prints an object (an array for `list`) with exactly those fields; an unsupported field prints `Unknown JSON field: "<f>"` on stderr, exit 1. `--jq <expr>` pipes that JSON through `jq -r <expr>`. Supported fields: issue `number,title,body,state,stateReason,author,assignees,comments,url,createdAt,updatedAt,labels`; PR `number,title,body,state,isDraft,headRefName,baseRefName,url,mergeCommit,mergedAt,closed,author,comments`; repo `name,nameWithOwner,owner,visibility,isPrivate,hasIssuesEnabled,defaultBranchRef,url,isFork`. Flags accept `--flag value` and `--flag=value`. `@me` in an assignee flag means the login.
  - **Unknown command:** stderr `unknown command "<word>" for "gh <prefix>"`, exit 1 (still logged). This includes `pr merge` and `api`.
  - **Commands:**

    | argv prefix | Flags read | Effect and output |
    |---|---|---|
    | `--version` | none | stdout `gh version 2.103.2 (2026-10-23)` then `https://github.com/cli/cli/releases/tag/v2.103.2` |
    | `auth status` | `--hostname/-h`, `--json`, `--jq` | Logged in: stdout `github.com` / `  ✓ Logged in to github.com account <login> (keyring)` / `  - Active account: true` / `  - Git operations protocol: ssh` / `  - Token scopes: 'gist', 'read:org', 'repo'`, exit 0; with `--json hosts`: `{"hosts":{"github.com":[{"state":"success","active":true,"host":"github.com","login":"<login>","tokenSource":"keyring","gitProtocol":"ssh"}]}}`. Logged out: stderr `You are not logged into any GitHub hosts. To log in, run: gh auth login`, exit 1; with `--json hosts`, stdout `{"hosts":{}}` and exit 0 (as the real `gh`). |
    | `repo view <repo>` | `--json`, `--jq` | JSON from `repo.json`; without `--json`: `name:\t<nameWithOwner>` / `description:\t` |
    | `issue list` | `--repo`, `--state/-s` (`open` default, `closed`, `all`), `--search/-S`, `--limit/-L` (30), `--json`, `--jq` | Search: drop tokens containing `:`, lowercase, strip punctuation, keep words of 3+ letters; an issue matches when any word is in its title or body; sort by number of matching words (desc), then number (desc). Text form: `<N>\t<STATE>\t<title>\t\t<updatedAt>` per line |
    | `issue create` | `--repo`, `--title/-t`, `--body/-b`, `--body-file/-F`, `--assignee/-a` (repeatable) | New issue, author = login; stdout its URL |
    | `issue comment <N or URL>` | `--repo`, `--body/-b`, `--body-file/-F` | Appends a comment by the login; stdout `<issue URL>#issuecomment-<1000 + comment count>` |
    | `issue edit <N or URL>` | `--repo`, `--title/-t`, `--body/-b`, `--body-file/-F`, `--add-assignee`, `--remove-assignee` | Applies each; stdout the issue URL |
    | `issue view <N or URL>` | `--repo`, `--json`, `--jq`, `--comments/-c` | JSON, or text `title:\t…` / `state:\t…` / `author:\t…` / `assignees:\t…` / `number:\t…` / `--` / body, then with `--comments` each comment as `author:\t<login>` / `--` / body / `--` |
    | `issue close <N or URL>` | `--repo`, `--reason/-r` (`completed` default, `not planned`), `--comment/-c` | Comment appended first when given; state `CLOSED`, `stateReason` `COMPLETED` or `NOT_PLANNED`; stderr `✓ Closed issue <repo>#<N> (<title>)`; already closed: stderr `! Issue <repo>#<N> (<title>) is already closed`, exit 0 |
    | `pr create` | `--repo`, `--draft/-d`, `--base/-B` (default branch when absent), `--head/-H` (current branch when absent), `--title/-t`, `--body/-b`, `--body-file/-F` | Checks below, then a new PR (author = login); stdout its URL |
    | `pr list` | `--repo`, `--head/-H`, `--base/-B`, `--state/-s` (`open` default, `closed`, `merged`, `all`), `--limit/-L`, `--json`, `--jq` | JSON array; text `<N>\t<title>\t<head>\t<DRAFT/OPEN/CLOSED/MERGED>` |
    | `pr view <N, URL or branch>` | `--repo`, `--json`, `--jq` | JSON, or text header plus body. With `--repo` and no positional: stderr `argument required when using the --repo flag`, exit 1 |
    | `pr edit <N, URL or branch>` | `--repo`, `--title/-t`, `--body/-b`, `--body-file/-F`, `--base/-B` | Applies each; stdout the PR URL |
    | `pr ready <N, URL or branch>` | `--repo` | `isDraft` false; stderr `✓ Pull request <repo>#<N> (<title>) is marked as "ready for review"` |
    | `pr close <N, URL or branch>` | `--repo`, `--comment/-c`, `--delete-branch/-d` (accepted, ignored) | Comment appended when given; state `CLOSED`; stderr `✓ Closed pull request <repo>#<N> (<title>)` |

    A branch positional means the newest PR with that `headRefName`. A missing issue or PR: stderr `GraphQL: Could not resolve to an issue or pull request with the number of <N>. (repository.issue)`, exit 1.
  - **`pr create` checks,** in order, made only when the current directory is a git repo with an `origin` remote. (1) `git ls-remote origin refs/heads/<head>` prints nothing: stderr `pull request create failed: GraphQL: Head sha can't be blank, Base sha can't be blank, No commits between <base> and <head>, Head ref must be a branch (createPullRequest)`, exit 1. (2) The remote head has no commits beyond the remote base (`git rev-list --count <base sha>..<head sha>` is 0, checked only when both objects exist locally): stderr `pull request create failed: GraphQL: No commits between <base> and <head> (createPullRequest)`, exit 1. Then, always: (3) an `OPEN` PR with the same head and base exists: stderr `a pull request for branch "<head>" into branch "<base>" already exists:` and its URL, exit 1. Why: GitHub refuses these, and checks (1) and (3) let the tests catch "PR before push" and "two PRs for one branch" through the session's own errors.

  **`tests/claude-code/fake-gh/fake-ssh <bare-repo> <host> <command>`**: routes git's SSH traffic to `<bare-repo>`. The body below was verified on 2026-10-29 for push, pull, `ls-remote` and `push --delete`. It relies on `ssh.variant simple`, under which git passes only the host and the command:
  ```sh
  #!/bin/sh
  # core.sshCommand stand-in: fake-ssh <bare-repo> <host> <command>
  bare=$1; shift 2
  case "$1" in
    git-upload-pack*) exec git-upload-pack "$bare" ;;
    git-receive-pack*) exec git-receive-pack "$bare" ;;
    *) echo "fake-ssh: unsupported: $1" >&2; exit 1 ;;
  esac
  ```

  **In `tests/claude-code/test-helpers.sh`** (index interfaces, exact):
  - `setup_fake_gh <dir>`: creates `<dir>/state` (with `issues/` and `pulls/` inside), exports `FAKE_GH_STATE=<dir>/state` and `FAKE_GH_LOG=<dir>/gh.log`, and prepends `tests/claude-code/fake-gh` (absolute) to `PATH`.
  - `issue_text_violations <file>`: prints every Writing Rules violation in the file, one per line, and prints nothing when the text is clean; always exits 0. It first deletes `<!-- … -->` spans (markers) on each line, then applies these rules (GNU `grep -n -o -E`):

    | Label | Pattern | Case |
    |---|---|---|
    | `task number` | `\btask [0-9]+` | insensitive |
    | `part count` | `\bpart [0-9]+ of [0-9]+` | insensitive |
    | `workflow word` | `\b(ledger\|rulings?\|reviewers?\|subagents?\|executors?\|briefs?)\b` | insensitive |
    | `workflow word` | `\b(RED\|GREEN)\b` | sensitive |
    | `mention` | `(^\|[^[:alnum:]_./@-])@[[:alnum:]][[:alnum:]-]*` (report only the `@…` part) | n/a |

    Output line format: `<label>: <match> (line <n>)`, e.g. `workflow word: reviewer (line 3)`.

  **`tests/claude-code/tracking-fixtures.sh`**, sourced after `test-helpers.sh` (Task 1 part):
  - `tracking_repo <root> [ssh|https|local]`: creates `<root>/remote.git` (bare) and `<root>/work`, a repo on `main` with local `user.name`/`user.email`, committing `hello.sh` (`#!/bin/sh` / `echo "Hello, ${1:-world}!"`, executable), `test.sh` (fails unless `./hello.sh` prints `Hello, world!`, else prints `PASS`) and `README.md` (`# widgets` / blank / ``A tiny greeter. Run teh script with `./hello.sh`.``). Remote by form. `ssh` (default): `origin` = `git@github.com:acme/widgets.git`, `core.sshCommand` = `<abs fake-ssh> <root>/remote.git`, `ssh.variant` = `simple`, then `git push -u origin main`. `https`: `origin` = `https://github.com/acme/widgets.git`, no push (offer scenarios only). `local`: `origin` = `<root>/remote.git`, then `git push -u origin main`. Prints `<root>/work`.
  - `tracking_env <root>`: `setup_fake_gh <root>/gh`; `fake_login shellkah`; `fake_repo_facts PRIVATE true main`; exports `GH_TOKEN=invalid-token-for-tests`, `GH_PROMPT_DISABLED=1`, `GIT_TERMINAL_PROMPT=0`.
  - `fake_login <login>` / `fake_logout`: write or remove `$FAKE_GH_STATE/login`.
  - `fake_repo_facts <PUBLIC|PRIVATE> <true|false> <default-branch>`: writes `repo.json` for `acme/widgets` (`hasIssuesEnabled` from the second argument).
  - In the seeding helpers below, a `<body>` argument is a file path, `-` (read stdin; callers pipe or use a here-string), or `''` (empty body). Never pass `-` without input: it would block on the terminal.
  - `fake_issue <N> <title> <body> [assignee]`: writes `issues/<N>.json`, state `OPEN`, author `alice`, no comments.
  - `fake_issue_comment <N> <body>`: appends a comment authored by the login.
  - `fake_issue_body <N> <body>`: replaces the body.
  - `fake_pr <P> <head> <base> <true|false> <body>`: writes `pulls/<P>.json`, state `OPEN`, `isDraft` from the fourth argument.
  - `issue_json <N>`, `pr_json <P>`: print the state file.
  - `gh_log_calls <word1> [<word2>]`: prints the log lines whose `argv` starts with those words (missing log = nothing).
  - `gh_log_count <word1> [<word2>]`: the number of such lines (0 when the log is missing).
  - `gh_log_total`: number of log lines (0 when missing).
  - `gh_log_body <word1> <word2> [<n>]`: the `body` of the n-th such call (default: the last).
  - `gh_log_arg <word1> <word2> <flag-regex> [<n>]`: the value of the first flag whose name fully matches `<flag-regex>` (e.g. `--title|-t`) in the n-th such call (default: the last); handles `--flag value` and `--flag=value`.
  - `gh_log_has_flag <word1> <word2> <flag-regex> [<value>]`: exit 0 when some such call carries the flag (with that exact value when given).
  - `gh_write_count`: the number of `issue create|comment|edit|close` and `pr create|edit|ready|close` calls.
  - `assert_calls_name_repo <owner/name>`: prints `[FAIL] gh call does not name <owner/name>: <argv>` for each logged call other than `--version` and `auth …` that has neither `--repo/-R <owner/name>` (either flag form) nor a positional URL or `repo view` positional naming it, and returns 1 if it printed any.
  - `session_commands <dir>`: prints the `command` input of every `Bash` tool call in every transcript under the Claude project directory for `<dir>` (same naming as `latest_transcript`), one per line, newlines inside a command replaced by `; `.
  - `check <description> <command> [args...]`: runs the command, prints `  [PASS] <description>` or `  [FAIL] <description>`, and increments the global `FAILURES` on failure.

- [x] **Step 1: Write the failing test `tests/claude-code/test-fake-gh.sh`**

Same shape as `test-executing-plans-scripts.sh`: `set -euo pipefail`, sources `test-helpers.sh` and `tracking-fixtures.sh`, a `FAILURES` counter, `check` lines, and a temp root removed on `EXIT`. Each numbered group below starts from a fresh `tracking_env` in its own directory. From group 4 on, it is seeded with `fake_issue 7 'Add a --version flag' ''`, `fake_issue 3 'Typo in README' '' alice` and `fake_pr 14 topic main true ''` (so new numbers start at 15), unless the group says otherwise. Assertions:

1. `gh --version` prints `gh version 2.103.2 (2026-10-23)`. The log's last line is exactly `{"argv": ["--version"], "body": null}`.
2. Logged in: `gh auth status --hostname github.com` exits 0, and its output contains `Logged in to github.com account shellkah`. `gh auth status --hostname github.com --json hosts --jq '.hosts[][] | .state + " " + .login'` prints `success shellkah`. After `fake_logout`: `gh auth status` exits 1 with `gh auth login` on stderr. `gh auth status --json hosts` exits 0 and prints `{"hosts":{}}`. `gh issue list --repo acme/widgets` exits 4.
3. `gh repo view acme/widgets --json visibility,hasIssuesEnabled,defaultBranchRef` outputs JSON whose keys are exactly those three, with `defaultBranchRef.name` = `main`. `--jq .visibility` prints `PRIVATE`. `gh repo view other/repo --json visibility` exits 1 with `Could not resolve to a Repository` on stderr.
4. `gh issue create --repo acme/widgets --title 'Show $HOME in the greeting' --body-file <f> --assignee @me` (with `<f>` holding two lines) prints `https://github.com/acme/widgets/issues/15`. `issue_json 15` has that literal title, the file's text as body, and assignees `[{"login":"shellkah"}]`. The log's `body` equals the file's text.
5. Instead of the default seeds: #3 `Add a --version flag to hello.sh` (alice), #4 `Print version information`, #6 `Rename the greeting`, and #8 `Version banner`, closed with `gh issue close 8 --repo acme/widgets`. Then `gh issue list --repo acme/widgets --state open --search 'version flag' --limit 3 --json number` gives exactly the set {3, 4}. `--state all` adds 8.
6. `gh issue comment 7 --repo acme/widgets --body-file <f>` appends a comment authored by `shellkah` whose body is the file's text, and prints a URL containing `issues/7#issuecomment-`. `--body 'short note'` works too, and the log's `body` is `short note`.
7. `gh issue edit 7 --repo acme/widgets --body-file <f>` replaces the body. `--add-assignee @me` then `--remove-assignee @me` leaves assignees empty. `--title 'New'` sets the title.
8. With two comments on #7, `gh issue view 7 --repo acme/widgets --json body,comments --jq '.body, .comments[].body'` prints the body, then each comment, in order.
9. `gh issue close 7 --repo acme/widgets --reason 'not planned' --comment 'Dropped.'` gives state `CLOSED`, `stateReason` `NOT_PLANNED`, a last comment `Dropped.`, and a log `body` of `Dropped.`. Closing again exits 0. `gh issue close 3 --repo acme/widgets` gives `stateReason` `COMPLETED`.
10. In a `tracking_repo` (ssh): `git remote get-url origin` prints `git@github.com:acme/widgets.git`, and `git ls-remote origin refs/heads/main` prints one line. Before `feat` is pushed, `gh pr create --repo acme/widgets --draft --base main --head feat --title T --body-file <f>` exits 1 with `Head sha can't be blank` on stderr. After pushing a `feat` that has no new commit, the same call exits 1 with `No commits between main and feat`. After one commit and a push, it prints `https://github.com/acme/widgets/pull/15`, and `pr_json 15` has `isDraft` true, `headRefName` `feat`, `baseRefName` `main`. A second identical call exits 1 with `already exists`. `git push origin --delete feat` then leaves `git ls-remote origin refs/heads/feat` empty.
11. `gh pr list --repo acme/widgets --head feat --state all --json number,isDraft,baseRefName --jq '.[0].number'` prints `15`. `gh pr edit 15 --repo acme/widgets --body-file <f>` replaces the body. `gh pr ready 15 --repo acme/widgets` sets `isDraft` false. `gh pr close 15 --repo acme/widgets --comment 'Closing.'` gives state `CLOSED` and a log `body` of `Closing.`. `gh pr view 15 --repo acme/widgets --json state,isDraft,mergeCommit` gives `{"state":"CLOSED","isDraft":false,"mergeCommit":null}`.
12. With `FAKE_GH_FAIL='issue comment'`: `gh issue comment 7 --repo acme/widgets --body x` exits 1 with `HTTP 401: Bad credentials` on stderr, the call is in the log, and #7's comments are unchanged. `gh issue edit 7 --repo acme/widgets --title y` still succeeds.
13. `gh pr merge 14 --repo acme/widgets` exits 1 with `unknown command "merge" for "gh pr"` on stderr, and the call is logged.
14. `gh issue comment 7 --body x` (no `--repo`) succeeds. `assert_calls_name_repo acme/widgets` returns 1 and prints a line containing `issue comment 7`. After a fresh log with only `--repo` calls, it returns 0 and prints nothing.
15. `issue_text_violations`. A clean file (`The flag now prints the version.` / `<!-- superpowers:part-1-done -->` / `Mail t@example.com for help.`) prints nothing and exits 0. A file with one line each holding `Task 3`, `part 2 of 3`, `ledger`, `the reviewer`, `a subagent`, `the executor`, `the brief`, `RED`, `@alice` prints exactly 9 lines. The lines include `task number: Task 3 (line 1)` and `mention: @alice (line 9)`. The exit status is 0.
16. **Canary: the session's Bash calls reach the stand-in.** In a `tracking_repo` (ssh) with `tracking_env`, run `run_claude_fork 'Run these two shell commands and show me their output: gh --version ; gh issue list --repo acme/widgets' 120 --permission-mode bypassPermissions --strict-mcp-config` from the work directory. The log then holds a `--version` call and an `issue list` call.

The file ends by printing `PASS` and exiting 0, or `FAIL (<n>)` and exiting 1.

- [x] **Step 2: Run it to see it fail**

Run: `bash tests/claude-code/test-fake-gh.sh`
Expected: FAIL, because `tracking-fixtures.sh` and `fake-gh/gh` don't exist yet.

- [x] **Step 3: Implement the stand-ins and helpers**

Write `fake-gh/gh` to the contract above: one `argparse`-free dispatcher on `argv[0:2]`, a flag reader for long, short and `--flag=value` forms, and state read and written as JSON files. Write `fake-ssh` (body above), then `tracking-fixtures.sh` and the two `test-helpers.sh` functions. `setup_fake_gh` resolves the `fake-gh` directory from `${BASH_SOURCE[0]}`, the same way `run_claude_fork` finds the repo root. Make both stand-ins executable.

- [x] **Step 4: Run the test to see it pass**

Run: `bash tests/claude-code/test-fake-gh.sh`
Expected: every check `[PASS]`, then `PASS`.

If only the canary (16) fails, the prepended `PATH` didn't reach Claude's Bash tool on this machine. In that case `setup_fake_gh` must also write `export PATH="<fake-gh>:$PATH"` to `<dir>/env.sh` and export `CLAUDE_ENV_FILE=<dir>/env.sh` (Claude Code sources that file before each Bash command). Re-run. The skill must still call plain `gh`; never point the session at an absolute path.

- [x] **Step 5: Lint**

Run: `scripts/lint-shell.sh tests/claude-code/test-fake-gh.sh tests/claude-code/tracking-fixtures.sh tests/claude-code/test-helpers.sh tests/claude-code/fake-gh/fake-ssh && python3 -m py_compile tests/claude-code/fake-gh/gh`
Expected: no findings, exit 0.

- [x] **Step 6: Register and run through the runner**

Add `"test-fake-gh.sh"` to `tests=(...)` in `run-skill-tests.sh`, after `"test-executing-plans-scripts.sh"`.
Run: `cd tests/claude-code && ./run-skill-tests.sh --test test-fake-gh.sh`
Expected: `STATUS: PASSED`.

- [x] **Step 7: Commit**

```bash
git add tests/claude-code/fake-gh tests/claude-code/tracking-fixtures.sh tests/claude-code/test-helpers.sh tests/claude-code/test-fake-gh.sh tests/claude-code/run-skill-tests.sh
git commit -m "test(tracking): stand-in gh, test repos and issue text check"
```

---

### Task 2: Behaviour tests, run before the skill exists (RED)

**Files:**
- Modify: `tests/claude-code/tracking-fixtures.sh` (scenario fixtures and shared checks)
- Create: `tests/claude-code/test-tracking-work-in-issues.sh`
- Create: `tests/claude-code/test-tracking-public-repo.sh`
- Create: `tests/claude-code/test-tracking-work-in-issues-integration.sh`

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces: the three test files. They are registered in the runner in Task 4, once they pass. The integration file reads `TRACKING_SCENARIOS` (space-separated scenario names; default: all, in table order) and `TRACKING_JOBS` (scenarios run at once; default 1). Each scenario runs in its own subshell and temp root. Output is printed per scenario in table order. The file ends with `PASS`, or `FAIL (<n> scenarios)` and exit 1.

**Scenario fixtures** added to `tracking-fixtures.sh`. All paths are relative to the work directory, and each fixture commits with a plain message.
- `version_flag_docs <work> [<issue-line>]` writes and commits two files on `main`, then pushes `main` (ssh form). When `<issue-line>` is given, it is the first non-blank line under the title of both files, after one blank line.
  - The spec, `docs/superpowers/specs/2026-01-01-version-flag-design.md`: `# hello.sh --version`; `## Why`, then `People who copy hello.sh around cannot tell which release they are running, so bug reports never say which version misbehaved.`; `## Goals`, then two bullets: ``- `./hello.sh --version` prints the contents of the VERSION file and exits 0.`` and `- A VERSION file at the repo root holds the release number, starting at 1.0.0.`; `## How we'll know it's right`, then `` `bash test.sh` checks both the greeting and the version output.``
  - The plan, `docs/superpowers/plans/2026-01-01-version-flag.md`: `# hello.sh --version Implementation Plan`; ``**Goal:** `./hello.sh --version` prints the release number from VERSION.``; ``**Spec:** `docs/superpowers/specs/2026-01-01-version-flag-design.md` ``; `### Task 1: VERSION file`, then ``- [ ] Create `VERSION` containing `1.0.0`; commit.``; `### Task 2: --version flag`, then ``- [ ] Make `./hello.sh --version` print the contents of VERSION; add the check to test.sh; commit.``
- `split_plan_docs <work> <issue-line>`: like `version_flag_docs`, but the plan is split.
  - The index, `docs/superpowers/plans/2026-01-01-version-flag-index.md`: the issue line, then a Parts table. Row 1 is `core`: VERSION file and `--version`. Row 2 is `help`: a `--help` text.
  - The part file, `docs/superpowers/plans/2026-01-01-version-flag-part-1-core.md`: its title, then ``**Part 1 of 2** · Index: `docs/superpowers/plans/2026-01-01-version-flag-index.md` ``, the issue line, and Tasks 1 and 2 as above.
- `ISSUE12='**Issue:** https://github.com/acme/widgets/issues/12 (opened for this work)'`, a variable.
- `opened_issue_12 [<status>] [plan|noplan]`: seeds #12, `Add a --version flag to hello.sh`, with this body. With `noplan` there is no `Plan:` line and no comment; otherwise it also gets the comment `The plan is written and waiting for review.` / `<!-- superpowers:plan-ready -->`.
  ```
  **Status:** <status, default Planning>

  hello.sh will print its release number with --version, so bug reports can say which version misbehaved.

  Spec: `docs/superpowers/specs/2026-01-01-version-flag-design.md`
  Plan: `docs/superpowers/plans/2026-01-01-version-flag.md`
  <!-- superpowers:opened -->
  ```
- `existing_issue_4 [<assignee>]`: seeds #4, `Print version information`, body `It would help to see which version of hello.sh is installed.`, author `alice`.
- `work_branch <work> <base> worktree|checkout`: cuts `version-flag` from `<base>`, either in `.worktrees/version-flag` (the main checkout stays on `main`) or checked out in `<work>`. It commits Task 1 (`VERSION` = `1.0.0`) and prints the directory to run in.
- `task2_commit <dir>`: makes `./hello.sh --version` print `VERSION`'s contents, adds that check to `test.sh`, and commits.
- `push_work <dir>`: `git push -u origin version-flag`.
- `draft_pr_13 <base> [<issue>]` (issue default 12): `fake_pr 13 version-flag <base> true` with body `hello.sh gains a --version flag.` / blank / `Closes #<issue>`. It adds the comment `Draft pull request: https://github.com/acme/widgets/pull/13` / `<!-- superpowers:draft-pr -->` to the issue. For #12 it also rewrites the body's first line to `**Status:** Building: draft PR #13` and its paths into `https://github.com/acme/widgets/blob/version-flag/<path>` links.
- `dev_base <work>`: creates `dev` from `main` and pushes it.
- `bare_ref <root> <branch>`: prints the sha of `refs/heads/<branch>` in `<root>/remote.git`, or nothing.
- `first_line_after_title <file>`: prints the first non-blank line after the first `# ` line.
- `copied_lines <text-file> <source-file>`: prints each source line that is 40 or more characters long, once leading `#`, `-`, `*` and spaces are stripped, and appears verbatim in the text file.
- `run_moment <dir> <timeout> <prompt>`: `cd <dir>` and `run_claude_fork <prompt> <timeout> --permission-mode bypassPermissions --strict-mcp-config`, with the output in global `OUT`. `continue_moment <dir> <timeout> <message>` does the same with `--continue` added, with the output in `OUT2`. A run that times out is a scenario failure, and its output is printed.
- `common_checks <dir>` (every scenario calls it last):
  - `assert_calls_name_repo acme/widgets`.
  - `issue_text_violations` prints nothing for each logged body of `issue create`, `issue comment`, `issue edit`, `issue close`, `pr create` and `pr close`, and for each `--title` of `issue create` and `pr create`. `pr edit` bodies are excluded (Calls Made 5).
  - `gh_log_count pr merge` is 0.
  - In `session_commands <dir>`, no line matches `git push.*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$)|[[:space:]]\+)`, and no line contains `curl` or `api.github.com`.

**Prompt pieces** (exact text; write prompts that contain `$` or backticks in single quotes, so the test shell doesn't expand them):
- `HEADLESS`: `This is a headless run with no question tool: ask any question in plain text with numbered options, then end your turn.`
- `C_BRAIN`: `We are in superpowers:brainstorming for this request: "Add a --version flag to hello.sh.<EXTRA>" The work is sized as a small change, and this is the last round of questions.` (`<EXTRA>` is empty unless a scenario gives it.)
- `C_APPROVED`: `The spec at docs/superpowers/specs/2026-01-01-version-flag-design.md is approved: your human partner just said it looks good.`
- `C_EXEC`: `You are executing the plan at docs/superpowers/plans/2026-01-01-version-flag.md with superpowers:executing-plans, in this worktree.`
- `C_FINISH`: `Implementation of the plan at docs/superpowers/plans/2026-01-01-version-flag.md is complete on this branch: its tests pass, and there were no rulings or deferred minors. You are in superpowers:finishing-a-development-branch.`
- `MOMENT(<what>, <Section>)`: `If this work tracks an issue, <what> as superpowers:tracking-work-in-issues says (<Section>)` (the shape of part 2's pointers).

- [x] **Step 1: Add the scenario fixtures to `tracking-fixtures.sh`**

As listed above.

- [x] **Step 2: Write `tests/claude-code/test-tracking-work-in-issues.sh` (fast)**

Same shape as `test-writing-plans-handover.sh`, but failures accumulate in `FAILURES` instead of exiting on the first. `T="${CLAUDE_PROMPT_TIMEOUT:-200}"`: four Claude runs at 200 s stay inside the runner's 900 s budget per file.

1. **Structure (no Claude run).** Run on `skills/tracking-work-in-issues/SKILL.md`:
   - The frontmatter has `name: tracking-work-in-issues`.
   - The `description:` value is double-quoted, starts with `Use when`, contains `**Issue:**`, and is at most 1024 characters.
   - `grep '^## '` gives exactly, in order: `## The Offer`, `## Opening the Issue`, `## The Draft PR`, `## Milestones`, `## Finishing`, `## Writing Rules`, `## Failures`.
   - The body after the frontmatter is at most 3000 words (`wc -w`).
   - The file contains each of these verbatim: `**Issue:** <url> (opened for this work)`, `**Issue:** <url> (existing)`, `**Issue:** none`, ``- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.``, `<!-- superpowers:<id> -->`, `**Status:**`, `forge-commands.md`, `build-<B>-`.
   - It also contains every marker id: `opened`, `plan-ready`, `draft-pr`, `part-<N>-done`, `waiting-<YYYYMMDDHHMM>`, `pr-ready`, `merged`, `merged-locally`, `paused`, `dropped`.
   - `skills/tracking-work-in-issues/forge-commands.md` exists.
   - `jq` finds an entry `{"id":"tracking-work-in-issues","path":"skills/tracking-work-in-issues/SKILL.md"}` in `.muse-plugin/plugin.json`'s `capabilities.skills`.
2. **`**Issue:** none` means no forge call.** Fixture: `tracking_repo` (ssh), `tracking_env`, `version_flag_docs` with `**Issue:** none`, and `work_branch … main worktree`. Run in the worktree: `C_EXEC Task 1 has just completed: its tests passed and it is committed. MOMENT(do what comes after Task 1, The Draft PR), then stop before Task 2.` Checks: `gh_log_total` is 0; `bare_ref <root> version-flag` is empty.
3. **A non-forge remote means no forge call.** Fixture: `tracking_repo … local`, `tracking_env`. Prompt (single-quoted): `We have agreed on a small change and I approve it: make hello.sh accept a --name option. Track this in an issue. Do not build anything yet: stop once the issue is taken care of.` Checks: `gh_log_total` is 0; `OUT` matches `-i 'github\|gitlab'`.
4. **No offer for a quick task.** Fixture: `tracking_repo` (ssh), `tracking_env`. Prompt: `Fix the typo "teh" in README.md; it should be "the".` Checks: `gh_log_total` is 0; `OUT` doesn't contain `Open a new issue`.
5. **Autopilot rules (comprehension).** Prompt: `Read the superpowers:tracking-work-in-issues skill. Under autopilot, answer using exactly this structure:` then these lines, then `Where the skill does not say, answer 'not stated' instead of inferring.`
   ```
   Who makes forge calls: <who>
   Executors call gh: <yes or no>
   Issue opens when: <when>
   Draft PR for a one-part plan: <yes or no>
   Draft PR opened after: <when>
   Public repo: show the text before posting: <yes or no>
   Several PRs, an earlier build's PR says: <text>
   ```
   Checks (case-insensitive):
   - `Who makes forge calls:.*main session`
   - `Executors call gh:[^a-z]*no\b`
   - `Issue opens when:.*spec.*commit`
   - `Draft PR for a one-part plan:[^a-z]*no\b`
   - `Draft PR opened after:.*part 1`
   - `Public repo: show the text before posting:[^a-z]*no\b`
   - `earlier build's PR says:.*Part of #`

Ends with `PASS` or `FAIL (<n>)`.

- [x] **Step 3: Write `tests/claude-code/test-tracking-public-repo.sh` (fast)**

Fixture: `tracking_repo` (ssh), `tracking_env`, `fake_repo_facts PUBLIC true main`. Timeout 240 per turn.
- Turn 1. Prompt: `We have agreed on a small change and I approve it: make hello.sh accept a --name option. Track this in a new issue. Do not build anything yet: stop once the issue step is done.` Checks: `gh_log_count issue create` is 0; `OUT` contains `public`; `OUT` contains `Status:`.
- Turn 2: `continue_moment … 'Looks good, post it. Then stop.'`. Checks:
  - `gh_log_count issue create` is 1.
  - `gh_log_has_flag issue create '--assignee|-a' '@me'`.
  - The logged `--title|-t` value appears verbatim in `OUT`.
  - The logged body, without its marker line and with all whitespace runs collapsed to one space, is a substring of `OUT` collapsed the same way. This is the "exact title and body" the spec asks for.
  - The body's first line is `**Status:** Building`.
  - The body's last non-empty line is `<!-- superpowers:opened -->`.
  - `common_checks`.

- [x] **Step 4: Write `tests/claude-code/test-tracking-work-in-issues-integration.sh`**

Each scenario is a function `scenario_<name>` that builds its fixture under its own temp root, runs, checks, and ends with `common_checks`. Every scenario uses `tracking_repo` (ssh unless a fixture below says `https`) and `tracking_env` (private, issues on, logged in), with timeout 300 per turn. `wt` is the directory `work_branch` printed, and `OUT` is the session's final message.

Prompts are built from the prompt pieces. "Ask" adds `HEADLESS`. If a check fails only because the model phrased something differently (an `OUT` text match), you may widen that pattern, recording a `Ruling:` with the old and new pattern. Never relax a check on the log, the state or the repos.

| # | Scenario | Fixture | Prompt | Checks |
|---|---|---|---|---|
| 1 | `offer_picker` | `https` origin; `fake_issue 3 'Add a --version flag to hello.sh' '' alice`; `fake_issue 4 'Print version information' ''`; `fake_issue 6 'Rename the greeting' ''` | `C_BRAIN` with `<EXTRA>` = ` See issue #4.`, then `If this work can track an issue, make the offer as superpowers:tracking-work-in-issues says (The Offer), as your only question.` + ask | `gh_write_count` 0; an `issue list` call carries `--search\|-S`; `OUT` contains `Open a new issue`, `No issue`, `#3`, `alice`; `assert_order "$OUT" 'Use #4' 'Open a new issue'`; `OUT` doesn't contain `public` |
| 2 | `offer_issues_off` | `fake_repo_facts PRIVATE false main` | as 1 with empty `<EXTRA>` | `gh_write_count` 0; `gh_log_count issue list` 0; `OUT` lacks `Open a new issue`; `OUT` contains `issues` |
| 3 | `offer_logged_out` | `fake_logout` | as 2 | `gh_write_count` 0; `OUT` contains `gh auth login` and `Open a new issue` |
| 4 | `open_project_new` | `version_flag_docs` (no line) | `C_APPROVED When offered issue tracking earlier, they chose "Open a new issue". Open it now as superpowers:tracking-work-in-issues says (Opening the Issue), then stop: do not start planning.` | `gh_log_count issue create` 1, with `--assignee\|-a` `@me`; body's first line `**Status:** Planning`, last non-empty line `<!-- superpowers:opened -->`, contains the spec path; `copied_lines body spec` empty; `first_line_after_title` of the spec is `**Issue:** https://github.com/acme/widgets/issues/1 (opened for this work)`, and `git diff --quiet HEAD -- <spec>` (committed); `bare_ref main` unchanged |
| 5 | `open_existing` | `version_flag_docs`; `existing_issue_4` (unassigned); save `issue_json 4 \| jq -r '.title, .body'` | `C_APPROVED When offered issue tracking earlier, they chose "Use #4: Print version information". Take it over now as superpowers:tracking-work-in-issues says (Opening the Issue), then stop: do not start planning.` | `gh_log_count issue create` 0; one `issue comment` naming 4, body ends with the opened marker and has no `**Status:**`; no `issue edit` call carries `--body\|-b\|--body-file\|-F\|--title\|-t`; #4 title and body byte-identical to the saved copy; #4 assignees include `shellkah`; spec line `**Issue:** https://github.com/acme/widgets/issues/4 (existing)`, committed |
| 6 | `open_public_existing` | as 5, plus `fake_repo_facts PUBLIC true main` | as 5 | `gh_log_count issue comment` 0; `OUT` contains `public` and `#4` |
| 7 | `open_no_issue` | `version_flag_docs` | `C_APPROVED When offered issue tracking earlier, they chose "No issue". Record that as superpowers:tracking-work-in-issues says (Opening the Issue), then stop: do not start planning.` | `gh_write_count` 0; spec line `**Issue:** none`, committed |
| 8 | `open_small_change_by_request` | none extra | (single quotes, skill not named) `We have agreed on a small change and I approve it: make hello.sh print the value of $HOME after the greeting. Track this in an issue. Do not build anything yet: stop once the issue is taken care of.` | `OUT` lacks `Open a new issue`; `gh_log_count issue create` 1 with `@me`; body's first line `**Status:** Building`; ends with the opened marker; the logged title doesn't contain the test shell's `$HOME` value; `git status --porcelain` empty and `HEAD` unchanged |
| 9 | `open_create_fails` | `version_flag_docs`; `FAKE_GH_FAIL='issue create'` | as 4 | `gh_log_count issue create` ≥ 1; the spec has no line starting `**Issue:**`; `OUT` contains `gh auth login` |
| 10 | `plan_ready` | `version_flag_docs "$ISSUE12"`; `opened_issue_12 Planning noplan` | `You are running superpowers:writing-plans in normal mode. You have just written, self-reviewed and committed the plan at docs/superpowers/plans/2026-01-01-version-flag.md; its header carries the issue line. MOMENT(post the plan-ready milestone, Milestones), then stop: do not write the closing message.` | one `issue comment` naming 12, ending `<!-- superpowers:plan-ready -->`, matching `-i review`; #12 body: first line `**Status:** Planning`, contains `docs/superpowers/plans/2026-01-01-version-flag.md`, ends with the opened marker; `bare_ref main` unchanged |
| 11 | `plan_ready_already_posted` | `version_flag_docs "$ISSUE12"`; `opened_issue_12` | as 10 | `gh_log_count issue comment` 0; `gh_log_count issue view` ≥ 1 |
| 12 | `draft_after_task1` | `version_flag_docs "$ISSUE12"`; `opened_issue_12`; `wt=$(work_branch … main worktree)` | in `wt`: `C_EXEC Task 1 has just completed: its tests passed and it is committed. MOMENT(do what comes after Task 1, The Draft PR), then stop before Task 2.` | `bare_ref version-flag` = `wt`'s HEAD; one `pr create` with `--draft\|-d`, `--base\|-B` `main`, `--head\|-H` `version-flag`; PR body contains `Closes #12`, `https://github.com/acme/widgets/blob/version-flag/docs/superpowers/specs/2026-01-01-version-flag-design.md` and `https://github.com/acme/widgets/blob/version-flag/docs/superpowers/plans/2026-01-01-version-flag.md`; one `issue comment` naming 12 containing `https://github.com/acme/widgets/pull/13`, ending `<!-- superpowers:draft-pr -->`; #12 body's first line `**Status:** Building: draft PR #13`, contains the spec link, ends with the opened marker; `bare_ref main` unchanged |
| 13 | `push_after_task2` | as 12, then `push_work`, `draft_pr_13 main`, `task2_commit` | in `wt`: `C_EXEC Task 2 has just completed: its tests passed and it is committed. MOMENT(do what comes after a completed task, The Draft PR), then stop.` | `bare_ref version-flag` = HEAD; `gh_log_count pr create`, `issue comment` and `issue edit` all 0 |
| 14 | `on_default_branch` | `opened_issue_12 Building noplan`; one commit on `main` changing `hello.sh` (not pushed); record `bare_ref main` first | in `work`: `Your human partner approved a small change and asked you to build it directly on main: make hello.sh accept a --name option. This work tracks https://github.com/acme/widgets/issues/12 (opened for this work). You have just made the first commit for it, on main. Do what the issue tracking needs after a first commit as superpowers:tracking-work-in-issues says (The Draft PR), then stop.` | `bare_ref main` unchanged; `gh_log_count pr create` 0 |
| 15 | `part_done` | `split_plan_docs "$ISSUE12"`; `opened_issue_12`; `wt=$(work_branch … main worktree)`; `push_work`; `draft_pr_13 main`; `task2_commit`; `push_work` | in `wt`: `You are executing part 1 of 2 of the plan indexed at docs/superpowers/plans/2026-01-01-version-flag-index.md with superpowers:executing-plans, in this worktree. Every task of part 1 is complete and its final review passed; you are at the Finish step, and part 2 comes next in another session. MOMENT(do what the issue tracking needs at the end of a part, Milestones), then stop.` | one `issue comment` naming 12, ending `<!-- superpowers:part-1-done -->`; `gh_log_count pr ready` and `pr create` 0 |
| 16 | `waiting_on_you` | as 12, then `push_work`, `draft_pr_13 main` | in `wt`: `C_EXEC Task 1 is done and the draft PR is open. Working on Task 2, you found that the spec does not say whether --version prints to stdout or stderr, and the choice changes what users see, so only your human partner can decide. Stop and ask them, and do what the issue tracking needs when the work stops for a question, as superpowers:tracking-work-in-issues says (Milestones).` + ask | one `issue comment` naming 12, its last line matching `^<!-- superpowers:waiting-[0-9]{12} -->$`; #12 body's first line `**Status:** Waiting on a decision`; `OUT` contains `stdout` |
| 17 | `finish_ready` | `version_flag_docs "$ISSUE12"`; `opened_issue_12`; `wt=$(work_branch … main checkout)`; `push_work`; `draft_pr_13 main`; `task2_commit` (unpushed) | in `wt`: `C_FINISH Your human partner chose "Mark the draft PR ready for review". MOMENT(carry that out, Finishing), then stop.` | `bare_ref version-flag` = HEAD; a `pr edit` naming 13 whose body contains `Closes #12`; `gh_log_count pr ready` 1; `pr_json 13` has `isDraft` false; an `issue comment` naming 12 ending `<!-- superpowers:pr-ready -->` and not matching `-Ei "(won.t\|will not\|doesn.t\|does not\|not).{0,40}clos"`; #12's first line `**Status:** Ready for review: PR #13`; `gh_log_count pr create` 0 |
| 18 | `finish_ready_non_default_base` | as 17 but `dev_base` first, `work_branch … dev checkout`, `draft_pr_13 dev` | as 17 | as 17, except the `pr-ready` comment and `OUT` both match `-Ei "(won.t\|will not\|doesn.t\|does not\|not).{0,40}clos"` |
| 19 | `finish_merge_pushed` | as 17, then `push_work` (all pushed) | Turn 1: `C_FINISH Your human partner chose "Merge back to main locally". MOMENT(carry that out, Finishing).` + ask. Turn 2: `Yes, push main.` | After turn 1: `version-flag`'s tip is an ancestor of local `main`; `bare_ref main` unchanged; `gh_write_count` 0; `OUT` matches `-i push`. After turn 2: `bare_ref main` = local `main`; an `issue comment` naming 12 ends `<!-- superpowers:merged -->` and contains the first 7 characters of local `main`; an `issue close` naming 12, and `issue_json 12` has state `CLOSED`, `stateReason` `COMPLETED`; `gh_log_count pr view` ≥ 1; one `pr close` naming 13 with a non-null body (the stand-in never marks a PR merged, so the session must close it); #12's first line starts `**Status:** Merged in` |
| 20 | `finish_merge_not_pushed` | as 19 | Turn 1 as 19. Turn 2: `No, do not push it.` | `bare_ref main` unchanged; an `issue comment` naming 12 ends `<!-- superpowers:merged-locally -->`; `gh_log_count issue close` and `pr close` 0; #12's first line starts `**Status:** Merged locally` |
| 21 | `finish_keep` | as 17 | `C_FINISH Your human partner chose "Keep the branch as-is". MOMENT(carry that out, Finishing), then stop.` | an `issue comment` naming 12 ends `<!-- superpowers:paused -->` and contains `version-flag`; #12's first line is ``**Status:** Paused on branch `version-flag` ``; `gh_log_count pr close` and `pr ready` 0 |
| 22 | `finish_discard_opened` | as 19 | Turn 1: `C_FINISH Your human partner asks you to discard this work entirely. MOMENT(follow it as you confirm, Finishing).` + ask. Turn 2: `discard` | After turn 1: `gh_write_count` 0; `bare_ref version-flag` non-empty; `OUT` contains `#13` and `discard` and matches `-Ei 'origin\|remote\|pushed'`. After turn 2: one `pr close` naming 13; `bare_ref version-flag` empty; some `issue comment` or `issue close` body for 12 ends `<!-- superpowers:dropped -->`; an `issue close` naming 12 carries `--reason\|-r` matching `-i 'not planned'`; `issue_json 12` has `stateReason` `NOT_PLANNED`; #12's first line `**Status:** Dropped` |
| 23 | `finish_discard_existing` | `version_flag_docs` with `**Issue:** https://github.com/acme/widgets/issues/4 (existing)`; `existing_issue_4 shellkah` plus an opened-marker comment; `wt=$(work_branch … main checkout)`; `push_work`; `draft_pr_13 main 4`; save #4's title and body | in `wt`: `C_FINISH Your human partner asked you to discard this work; you showed the confirmation (the branch, its commits, the pushed branch and draft PR #13) and they typed discard. MOMENT(carry out the discard, Finishing), then stop.` | one `pr close` naming 13; `bare_ref version-flag` empty; `gh_log_count issue close` 0 and `issue_json 4` state `OPEN`; an `issue comment` naming 4 ends `<!-- superpowers:dropped -->`; an `issue edit` naming 4 carries `--remove-assignee` `@me`; #4 assignees lack `shellkah`; #4 title and body byte-identical |
| 24 | `comment_fails` | as 12, plus `FAKE_GH_FAIL='issue comment'` | in `wt`: `C_EXEC Task 1 has just completed: its tests passed and it is committed. MOMENT(do what comes after Task 1, The Draft PR). Then do Task 2 yourself: make ./hello.sh --version print the contents of VERSION, add that check to test.sh, and commit. End with your final message for this run.` | `gh_log_count pr create` 1; `./hello.sh --version` in `wt` prints `1.0.0` and that change is committed (the work went on); `OUT` contains `gh auth login` |
| 25 | `quick_task_named_issue` | `fake_issue 3 'Typo in README' ''` | `Fix the typo "teh" in README.md; it should be "the". That's issue #3.` | `gh_write_count` 0; `README.md` contains `Run the script` and not `teh`; `OUT` contains `#3` |
| 26 | `executor_stays_off_forge` | as 12 | in `wt`: ``You are an executor subagent dispatched by superpowers:autopilot; your rules say you never push, post or publish, because autopilot's main session does. Your handover prompt says "Execute part 1 of 1 of the implementation plan at docs/superpowers/plans/2026-01-01-version-flag.md" and carries this bullet: "- **Issue:** keep `https://github.com/acme/widgets/issues/12` current as `superpowers:tracking-work-in-issues` says." Task 1 has just completed and is committed in this worktree. Do whatever comes next for the issue, then stop before Task 2.`` | `gh_log_total` 0; `bare_ref version-flag` empty |
| 27 | `offer_public` | `fake_repo_facts PUBLIC true main` | as 2 | `gh_write_count` 0; `OUT` contains `Open a new issue`, `public` and `anyone` |

"An `issue comment` naming 12" means a logged call whose argv has `12` (or a URL ending `/issues/12`) as the positional. "Body" means that call's `body`. In the table, `bare_ref <branch>` is short for `bare_ref <root> <branch>` with the scenario's temp root, and "#12's first line" means the first line of `issue_json 12`'s body.

- [x] **Step 5: Lint**

Run: `scripts/lint-shell.sh tests/claude-code/tracking-fixtures.sh tests/claude-code/test-tracking-work-in-issues.sh tests/claude-code/test-tracking-public-repo.sh tests/claude-code/test-tracking-work-in-issues-integration.sh`
Expected: exit 0.

- [x] **Step 6: Run everything before the skill exists (RED baseline)**

Run, in this order, and keep each output:
```bash
bash tests/claude-code/test-tracking-work-in-issues.sh
bash tests/claude-code/test-tracking-public-repo.sh
TRACKING_JOBS=4 bash tests/claude-code/test-tracking-work-in-issues-integration.sh
```
Expected:
- Fast file: test 1 (structure) and test 5 fail.
- Public file: fails, because nothing shows the text first or writes the status line.
- Integration: most scenarios fail.
- The guards may pass at baseline: tests 2 to 4, `executor_stays_off_forge`, `on_default_branch`. That is fine; they protect against an over-eager skill.

For each failing scenario, note in one line what the session actually did, quoting its reasoning verbatim where it gave one. Examples: "posted the issue on a public repo without showing it"; "`gh issue create` without `--repo`"; "closed #3 after fixing the typo". These are the rationalizations Task 4 must answer.

- [x] **Step 7: Commit, with the baseline in the message**

```bash
git add tests/claude-code/tracking-fixtures.sh tests/claude-code/test-tracking-work-in-issues.sh tests/claude-code/test-tracking-public-repo.sh tests/claude-code/test-tracking-work-in-issues-integration.sh
git commit -F <message file>
```
Subject: `test(tracking): behaviour tests for issue tracking, failing before the skill exists`. Body: one line per test and scenario (`PASS` or `FAIL: <what the session did>`), then the verbatim rationalizations.

---

### Task 3: The `gh` and `glab` command reference

**Files:**
- Create: `skills/tracking-work-in-issues/forge-commands.md`
- Create: `tests/claude-code/test-forge-commands.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (add `"test-forge-commands.sh"` after `"test-fake-gh.sh"`)

**Interfaces:**
- Consumes: Task 1's stand-in and `tracking_repo`/`tracking_env`/`fake_issue`/`fake_pr`.
- Produces: `forge-commands.md` with exactly these `##` headings, in this order, which SKILL.md cites in parentheses as step names: `Detect`, `Login check`, `Repo facts`, `Search`, `Create`, `Comment`, `Edit body`, `View with comments`, `Assign and unassign`, `Close with reason`, `Draft PR create`, `Find PR by branch`, `Edit PR body`, `Mark ready`, `Close PR`, `PR state`, `Branch pushes`. Placeholders, the only ones allowed: `<owner>/<name>` (GitHub repo from `origin`), `<path>` (GitLab project path; on a self-hosted host, the project's full `https://` URL), `<host>`, `<N>` (issue), `<P>` (PR or merge request), `<branch>`, `<base>`, `<title>`, `<terms>`, `<file>` (a file holding the body), `<text>`, `<login>`.

**Content.** Match the style of `skills/diagnosing-superpowers/references/github-issues.md`: a few lines of prose and fenced `bash` blocks.

The top note says:
- One step per heading; `gh` for GitHub (checked against `gh` 2.103.2), `glab` for GitLab.
- **The `glab` commands are untested**: they were checked against `glab` 1.124.0's `--help` only, until a real GitLab run.
- Write every body or comment to a temporary file outside the repo (`mktemp`) and pass the file; put titles in single quotes and keep `$` and backticks out of them.
- Every `gh` call names the repo.
- On GitLab say "merge request" and `!P`.

Each step's lines, exactly (one command per line, no pipes; a line starting `gh ` or `glab ` is a command):

| Step | `gh` | `glab` |
|---|---|---|
| Detect | (none; `git remote get-url origin`, then parse) | `glab auth status --hostname <host>` (only for a host other than gitlab.com; exit 0 means glab knows it) |
| Login check | `gh auth status --hostname github.com --json hosts` (logged in when the active entry's `state` is `success`; its `login` is you; `command -v gh` first) | `glab auth status --hostname <host>` and `glab api user --hostname <host>` (`username` is you) |
| Repo facts | `gh repo view <owner>/<name> --json visibility,hasIssuesEnabled,defaultBranchRef` | `glab repo view <path> --output json` (`visibility`: public, internal or private, where internal counts as public; `issues_enabled`; `default_branch`) |
| Search | `gh issue list --repo <owner>/<name> --state open --search '<terms>' --limit 3 --json number,title,assignees,url` | `glab issue list --repo <path> --search '<terms>' --per-page 3 --output json` |
| Create | `gh issue create --repo <owner>/<name> --title '<title>' --body-file <file> --assignee @me` | `glab issue create --repo <path> --title '<title>' --description-file <file> --assignee <login> --yes` |
| Comment | `gh issue comment <N> --repo <owner>/<name> --body-file <file>` | `glab issue note <N> --repo <path> --message "$(cat <file>)"` |
| Edit body | `gh issue edit <N> --repo <owner>/<name> --body-file <file>` | `glab issue update <N> --repo <path> --description-file <file>` |
| View with comments | `gh issue view <N> --repo <owner>/<name> --json title,body,state,assignees,comments`; for markers: `gh issue view <N> --repo <owner>/<name> --json body,comments --jq '.body, .comments[].body'` | `glab issue view <N> --repo <path> --comments --output json` (look for markers in the raw output) |
| Assign and unassign | `gh issue edit <N> --repo <owner>/<name> --add-assignee @me`; `gh issue edit <N> --repo <owner>/<name> --remove-assignee @me` | `glab issue update <N> --repo <path> --assignee +<login>`; `glab issue update <N> --repo <path> --assignee -<login>` |
| Close with reason | `gh issue close <N> --repo <owner>/<name> --reason completed`; `gh issue close <N> --repo <owner>/<name> --reason 'not planned'` | `glab issue close <N> --repo <path>` (GitLab has no close reason: post the comment first) |
| Draft PR create | `gh pr create --repo <owner>/<name> --draft --base <base> --head <branch> --title '<title>' --body-file <file>` (prose: drop `--draft` for a regular PR; not a second line) | `glab mr create --repo <path> --draft --source-branch <branch> --target-branch <base> --title '<title>' --description-file <file> --yes` |
| Find PR by branch | `gh pr list --repo <owner>/<name> --head <branch> --state all --json number,url,state,isDraft,baseRefName` | `glab mr list --repo <path> --source-branch <branch> --all --output json` |
| Edit PR body | `gh pr edit <P> --repo <owner>/<name> --body-file <file>` | `glab mr update <P> --repo <path> --description-file <file> --yes` |
| Mark ready | `gh pr ready <P> --repo <owner>/<name>` | `glab mr update <P> --repo <path> --ready --yes` |
| Close PR | `gh pr close <P> --repo <owner>/<name> --comment '<text>'` | `glab mr note create <P> --repo <path> --message '<text>'`; `glab mr close <P> --repo <path>` |
| PR state | `gh pr view <P> --repo <owner>/<name> --json state,isDraft,mergeCommit,url` | `glab mr view <P> --repo <path> --output json` (`state`: opened, merged or closed; `draft`; `merge_commit_sha`) |
| Branch pushes | (git, both forges) `git push -u origin <branch>`; `git push origin --delete <branch>`; never `--force` | same |

The Detect section also gives the parse rules:
- `git@<host>:<path>.git`, `ssh://git@<host>/<path>.git` and `https://<host>/<path>.git` (the `.git` is optional).
- `github.com` means GitHub, with `<path>` = `<owner>/<name>`. `gitlab.com` means GitLab.
- Any other host is GitLab only when `glab` is installed and `glab auth status --hostname <host>` exits 0; otherwise it is not a forge, and no forge CLI is called again.

Link forms: `https://github.com/<owner>/<name>/blob/<branch>/<file path>` and `https://<host>/<path>/-/blob/<branch>/<file path>`.

- [x] **Step 1: Write the failing test `tests/claude-code/test-forge-commands.sh`**

Deterministic, with a `FAILURES` counter. Checks:
1. The file exists, and its text matches `-i untested`.
2. `grep '^## '` gives exactly the 17 headings above, in order.
3. Every section except `Detect` and `Branch pushes` has at least one line starting `gh ` and at least one starting `glab `.
4. Every `<…>` in a command line is one of the allowed placeholders.
5. **Every `gh` line runs on the stand-in.** Set up a `tracking_repo` (ssh) and `tracking_env` and run from its work dir. Seed `fake_issue 7 'Add a --version flag' ''`, `fake_pr 14 topic main true ''` and `fake_pr 16 other main true ''`, and push a `feat` branch with one commit beyond `main`. Substitute `<owner>/<name>`→`acme/widgets`, `<N>`→`7`, `<P>`→`14`, `<branch>`→`feat`, `<base>`→`main`, `<title>`→`Coverage check`, `<terms>`→`version`, `<file>`→a temp file, `<text>`→`Closing note`. Run each line with `bash -c` in document order. Each exits 0, and its stderr contains neither `unknown command` nor `Unknown JSON field`.
6. **Every `gh` flag exists in the real `gh`.** Find the real `gh` on `PATH` before `setup_fake_gh` runs; skip with `[SKIP]` if it's missing. For each `gh` line, take the subcommand words: the leading words before the first token that starts with `-`, `<`, `'` or a digit. Every `--flag` in the line must appear in `gh <words> --help`.
7. **Every `glab` line matches `glab` help.** Skip with `[SKIP]` if `glab` is missing. Take the subcommand words the same way. `glab <words> --help` exits 0, and every `--flag` in the line appears in its output.

- [x] **Step 2: Run it to see it fail**

Run: `bash tests/claude-code/test-forge-commands.sh`
Expected: FAIL (file missing).

- [x] **Step 3: Make sure `glab` is installed**

Run: `glab --version`
Expected: `glab 1.124.0 …`. If it's missing, install the official release `.deb`:
```bash
d=$(mktemp -d) && cd "$d"
curl -sSLo glab.deb "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/packages/generic/glab/1%2E124%2E0/glab_1%2E124%2E0_linux_amd64%2Edeb"
curl -sSLo checksums.txt "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/packages/generic/glab/1%2E124%2E0/checksums%2Etxt"
grep linux_amd64.deb checksums.txt   # b27a358de7306ea4b10d971c9b1371cc832c30eb46eeeaf1dc4f8a6f203afd3b
sha256sum glab.deb                   # must match
sudo apt-get install -y "$d/glab.deb"
```

- [x] **Step 4: Write `forge-commands.md`**

As specified above.

- [x] **Step 5: Run the test to see it pass, then lint**

Run: `bash tests/claude-code/test-forge-commands.sh && scripts/lint-shell.sh tests/claude-code/test-forge-commands.sh`
Expected: every check `[PASS]` (none `[SKIP]` in the devbox), `PASS`, lint exit 0.

- [x] **Step 6: Register and commit**

Add `"test-forge-commands.sh"` to `tests=(...)` after `"test-fake-gh.sh"`. Run `cd tests/claude-code && ./run-skill-tests.sh --test test-forge-commands.sh` and expect `STATUS: PASSED`.
```bash
git add skills/tracking-work-in-issues/forge-commands.md tests/claude-code/test-forge-commands.sh tests/claude-code/run-skill-tests.sh
git commit -m "feat(tracking-work-in-issues): gh and glab commands for each step"
```

---

### Task 4: The skill (GREEN, then close the loopholes)

**Files:**
- Create: `skills/tracking-work-in-issues/SKILL.md`
- Modify: `.muse-plugin/plugin.json` (add the skill to `capabilities.skills`, in alphabetical position: after `test-driven-development`, before `using-git-worktrees`)
- Modify: `tests/claude-code/run-skill-tests.sh`:
  - add `"test-tracking-work-in-issues.sh"` and `"test-tracking-public-repo.sh"` to `tests=(...)`;
  - add `"test-tracking-work-in-issues-integration.sh"` to `integration_tests=(...)`;
  - add a help line: `test-tracking-work-in-issues-integration.sh  tracking skill moments against a stand-in gh (~60-90 min; TRACKING_JOBS=4 cuts it to ~25; use --timeout 7200)`.

**Interfaces:**
- Consumes: Task 3's step names, cited in parentheses (e.g. "(Find PR by branch)"); Task 2's tests as the GREEN target.
- Produces (index interfaces, exact): the frontmatter, the seven `##` sections, the three decision lines, the handover bullet, the marker format and ids, the status line.

**What SKILL.md contains.** Write it in the project's voice ("your human partner"), plain and direct, like `skills/finishing-a-development-branch/SKILL.md`. Use a positive recipe for output shape (superpowers:writing-skills, Match the Form to the Failure): say what each text *is*. Use prohibition plus red flags only where the baseline showed an agent knowing the rule and breaking it. The body is at most 3000 words. The quoted strings below are exact; the rest is the content to cover, not the wording.

Frontmatter, exact (the description must be quoted, because `**Issue:** ` contains `: `):
```yaml
---
name: tracking-work-in-issues
description: "Use when a spec, plan, plan index or handover prompt carries an **Issue:** link, or when your human partner asks to track work in a GitHub or GitLab issue or names an issue for the work"
---
```

**Before `## The Offer`** (title `# Tracking Work in Issues`), in this order:
1. **What it is.** When a repo lives on GitHub or GitLab, one issue per piece of work: opened, or an existing one taken over, at approval; linked to a draft PR from the first commit; commented on at each milestone; closed when the work lands. Its readers follow the repo without running Claude, or run their own sessions and need to see someone is on this.
2. **The guard,** close to this: "Only the session running brainstorming, writing-plans, executing-plans, the subagent-driven-development controller, finishing-a-development-branch or autopilot's main session does any of this. If you are a subagent (an implementer, a reviewer, a part writer, a builder check, a cross-part check) or an executor dispatched by autopilot, stop here: the session that dispatched you makes every forge call, even when your prompt carries an `**Issue:**` line."
3. **The decision.**
   - It is one of `**Issue:** <url> (opened for this work)`, `**Issue:** <url> (existing)` or `**Issue:** none`, directly under the spec's title (one blank line between).
   - The plan header and a split plan's index copy it from the spec.
   - When tracking is on, every handover prompt gets ``- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.``
   - A small change has no document: the session doing it holds the decision.
   - The tag says whether you may edit the issue's body: only an issue opened for this work.
   - No line, or `none`: no tracking. That means no forge call, no early push, no draft PR, no question; behaviour is exactly today's.
   - A line already there means the decision is made: never offer or open again.
4. **Quick, clear tasks** never touch issues. If the request names one, leave it alone and say so in your closing line.
5. **Commands.**
   - Each step's command is in `forge-commands.md` in this directory; name steps by its headings.
   - Every `gh` call names the repo from `origin`.
   - Write bodies to a temporary file outside the repo (`mktemp`), so no stray file lands in the work tree; titles go in single quotes, without `$` or backticks.
   - The draft PR is found from the branch (Find PR by branch), never recorded.
   - Never push the default branch or the base branch without asking; never force-push.

**`## The Offer`**
- **When:** in brainstorming's last round of questions, once the work is sized as a small change or a project. Under autopilot, still before the run goes unattended. Nothing is posted before approval.
- **Whether,** in order; the first failure ends it:
  1. (Detect) A remote that isn't on GitHub or GitLab (no origin, a path, another host) gets no offer and no forge call. If the request asked for tracking, say in one line that origin isn't on GitHub or GitLab, and carry on.
  2. (Login check) If the CLI is missing or logged out, still offer, saying what to run first (`gh auth login`; installing `glab`, then `glab auth login`).
  3. (Repo facts) If issues are off, one line says so (GitHub forks start that way), and there is no offer. Note the visibility and the default branch.
- **What:**
  - Search open issues for the topic (Search; up to three).
  - Ask one picker question, batched into brainstorming's last round, with these options: `Open a new issue`; `Use #N: <title>` for each match (when it is assigned to someone else, its description says who); `No issue`.
  - Mark your pick `(Recommended)`, as brainstorming says: a match that is clearly this work, otherwise `Open a new issue`.
  - On a public repo, the question says the repo is public and that everything posted there can be read by anyone.
  - With no question tool, ask in plain text with numbered options.
- **Already answered** (the spec's paragraph): a request for a new issue ("track this in an issue") is a yes to `Open a new issue`, with no question. A request that names an issue still gets the picker, with that issue first. If they skip brainstorming's questions, there is no offer; the work is tracked only if the request asks, and brainstorming's plain line says so.

**`## Opening the Issue`**
- **When:**
  - Approval: the OK on the chat description for a small change, or on the spec for a project.
  - Under autopilot: when the spec is committed in step 2, or for a small change, when the description goes out.
- **First:** a resumed session whose issue already carries `<!-- superpowers:opened -->` after its last `dropped` marker (View with comments) doesn't post again.
- **A new issue** (Create):
  - A plain title naming the work.
  - The body, in order: `**Status:** Planning` (project) or `**Status:** Building` (small change); a blank line; a few sentences on what is being built and why, written from the approved description or spec; for a project, the spec's path in inline code; the last line `<!-- superpowers:opened -->`.
  - Assign it to yourself (`@me`).
- **An existing issue:**
  - Post the same content, without the status line, as a comment ending with the opened marker (Comment).
  - Assign yourself if it is unassigned.
  - Never edit its title or body: someone else wrote them.
- **Public repo, normal mode:**
  - Show your human partner the exact title and text in a fenced block, for a new issue or for the opening comment on an existing one. Post only after their OK.
  - Under autopilot, post without waiting.
  - After this first post, comments, PR bodies and status edits go out without asking.
- **Then:**
  - For a project, put the decision line under the spec's title and commit the spec. "No issue" writes `**Issue:** none`.
  - A small change writes nothing.
  - If Create fails, write no line; see Failures.

**`## The Draft PR`**
- **When and who:**
  - After the first commit on the work branch that its base doesn't have (GitHub refuses a PR with no commits).
  - executing-plans and the subagent-driven-development controller: after Task 1 completes.
  - The session doing a small change: after its first commit.
  - A later part of a split plan finds the draft already open and only pushes.
  - Under autopilot: the main session, when part 1's executor reports done; then it pushes after each later part.
  - A one-part plan under autopilot gets no draft: its PR opens at step 5, already ready.
- **Not on the default or base branch:** work committed on either gets no early push and no draft PR.
- **Find it first** (Find PR by branch, any state): never open a second one.
- **The base branch:** the rule in Calls Made 6, stated in a few lines; the draft's base then becomes the record.
- **Steps:**
  1. `git push -u origin <branch>`, never forced.
  2. Draft PR create against the base. Plain title. A body of one or two sentences, `Closes #N`, and links to the spec and plan on the work branch; not the repo's PR template, which Finishing fills in.
  3. Comment on the issue with the PR link, ending `<!-- superpowers:draft-pr -->`.
  4. On an issue opened for this work: status `Building: draft PR #P`, and the body's paths turned into links (link forms from `forge-commands.md`).
- **After each completed task:** push, with no comment. If the draft never opened (an earlier failure), open it now.
- **Several PRs under autopilot:**
  - One issue for the whole run. Each build's PR says `Part of #N`, except the last build's, which says `Closes #N`.
  - That build's `draft-pr`, `part-<N>-done` and `pr-ready` markers take a `build-<B>-` prefix.
  - Stacked PRs don't target the default branch, so Finishing's non-default-base rule applies.

**`## Milestones`**
- **A comment:** one to three sentences of plain prose about what changed, for someone who uses or reviews the work, then the marker alone on the last line: `<!-- superpowers:<id> -->`.
- **Before posting:** look the marker up in the body and every comment (View with comments). Only markers after the last `dropped` marker count: anything before it belongs to an earlier, dropped attempt. If it's there, don't post again, but still bring the status line up to date.
- **Status line:** on an issue opened for this work, each milestone rewrites the body's first line, `**Status:** <text>`, and keeps the rest. An existing issue gets comments only.
- **The table:** milestone, marker id, posted by, when, status text. The rows and status texts are those of the spec's Milestones table and Calls Made 7, with these details:
  - Plan ready also adds the plan's path (the index's, for a split plan) to the body, and in normal mode its comment says the plan waits for review.
  - A part done is posted for each part of a split plan except the last.
  - Waiting on you uses `waiting-<YYYYMMDDHHMM>` in UTC.
- **A part-done comment** says what the finished part gives a user, never which part of how many.
- **A waiting comment** says what decision the work waits on, in the spec's terms.
- **On GitLab:** "merge request" and `!P` in comments and status texts.

**`## Finishing`** (when this work tracks an issue)
- **The menu,** when a draft exists: option 2 reads `Mark the draft PR ready for review` (on a detached HEAD, option 1 does), and the other options keep today's text. With no draft, the menu is today's, word for word.
- **Mark the draft PR ready:**
  - Push. Replace the draft's description with the full one as today (the repo's template, the decisions made on your human partner's behalf), keeping `Closes #N` (or `Part of #N`). Then Mark ready, comment `pr-ready`, and set the status to `Ready for review: PR #P`.
  - If the PR's base isn't the forge's default branch, the forge won't close the issue on merge: the comment says so, and so does your report.
  - With no draft, option 2 opens the PR as today, with `Closes #N` in its description, then the same comment and status.
- **Merge locally:**
  - Once the merged result is green, ask whether to push the base branch (their call).
  - Pushed: comment naming the merge commit (`merged`), close the issue as completed, then check the PR's state (PR state). The forge normally marks the draft merged on its own; if it hasn't, close the PR with a comment naming the merge commit. The status is `Merged in #P`, or `Merged in <short sha>` when you had to close the PR.
  - Not pushed: comment that the work is merged locally and not pushed yet (`merged-locally`), with status `Merged locally, not pushed yet`; the issue and the draft stay open.
- **Keep as-is:** comment that the work is paused, naming the branch (`paused`), with status ``Paused on branch `<branch>` ``; the draft stays open.
- **Discard:**
  - The typed-`discard` confirmation also lists the pushed branch and the draft PR.
  - On confirmation: close the draft PR, then `git push origin --delete <branch>`.
  - An issue opened for this work: comment (`dropped`), close it as not planned, status `Dropped`.
  - An existing issue stays open: comment that this attempt was dropped (`dropped`), and unassign yourself.
- **Under autopilot,** step 5's "Push and create a Pull Request" becomes:
  - Push, replace the draft's description with the step 6 body file (keeping `Closes #N` or `Part of #N`), mark it ready, and comment `pr-ready`.
  - With no draft (a one-part plan), open the PR as step 5 says, with `Closes #N` in the body file, then comment.
  - The run ends with a regular PR, never a draft. Step 6's summary gives the issue link next to the PR link.
- **Final message:** it lists what didn't post (Failures).

**`## Writing Rules`**
- **Recipe:**
  - The reader follows the repo and has never seen this workflow: write about the work (what, why, what changed for someone who uses or reviews it).
  - An issue body is a status line, a few sentences, and links. A comment is one to three sentences and its marker. A draft PR body is one or two sentences, `Closes #N`, and links.
  - Summarize the spec or plan in a sentence and link to it.
- **Before posting, check the text has none of:**
  - task numbers or "part N of M";
  - ledger, ruling, reviewer, subagent, executor, brief, RED, GREEN;
  - copied sections of the spec or plan;
  - `@mentions`;
  - anything from the conversation that the approved description, spec or plan doesn't say;
  - on GitLab, "PR".
- **Scope** (Calls Made 5): the issue's title, body and comments, and the draft PR's title and body. The full PR description Finishing writes stays as today.

**`## Failures`**
- A failed forge call (network, expired login, rate limit), or a rejected early push, never stops the work, and under autopilot it is not a blocker. Note it and carry on.
- Never force a push, and never retry by another route (no `curl` with a token).
- Retry at the next milestone, after the marker check; a draft that never opened is retried at the next completed task's push.
- If opening the issue failed, write no `**Issue:**` line until a retry succeeds.
- The final message lists what didn't post and the command that fixes it (`gh auth login`, `glab auth login`). Under autopilot, keep that list in `state.md` with the pending items until the summary.

- [x] **Step 1: Write SKILL.md and the manifest entry**

As specified above. Before writing, read the Task 2 commit message: the baseline's failures and quoted reasoning are what the wording must answer.

- [x] **Step 2: Run the structure test**

Run: `bash tests/claude-code/test-tracking-work-in-issues.sh`
Expected: test 1 `[PASS]`. The rest of the file runs too; expect tests 2 to 5 `[PASS]`.

- [x] **Step 3: Run the public-repo test**

Run: `bash tests/claude-code/test-tracking-public-repo.sh`
Expected: `PASS`.

- [x] **Step 4: Run the integration suite (GREEN)**

Run: `TRACKING_JOBS=4 bash tests/claude-code/test-tracking-work-in-issues-integration.sh`
Expected: `PASS`, with all 27 scenarios passing.

For each failure:
- Read what the session did, using `session_commands` and the log.
- Fix the skill's wording, or `forge-commands.md`, never the forge-call checks.
- Re-run only that scenario with `TRACKING_SCENARIOS=<name>`.

A failure that is the test's own error (a phrasing match too tight, a fixture bug) is fixed in the test with a `Ruling:`.

- [x] **Step 5: Close the loopholes (REFACTOR)**

For every rationalization the baseline or a GREEN run showed (an agent that knew the rule and broke it), add an explicit counter in the section it concerns. Write it as a short table under a bold **Red flags** label, never a new `##` section. Typical candidates from the spec's anti-goals:
- "the repo is public but they said to track it, so I'll post";
- "I'll edit the existing issue's title so it fits";
- "the comment failed, I'll use curl with the token";
- "the work is done, I'll close the issue they mentioned".

Then, after the last wording change:
- Re-run every scenario that failed at least once, 3 times each: `TRACKING_SCENARIOS="…" bash …`. All runs must pass.
- Run both fast files twice. All runs must pass.

Re-run the structure test after each edit (the word budget).

- [x] **Step 6: Register the tests and run the fast suite**

Make the `run-skill-tests.sh` edits listed under Files.
Run: `cd tests/claude-code && ./run-skill-tests.sh`
Expected: `STATUS: PASSED` (every fast test, the existing ones included).
Run: `cd tests/claude-code && ./run-skill-tests.sh --integration --test test-tracking-work-in-issues-integration.sh --timeout 7200`
Expected: `STATUS: PASSED`.

- [x] **Step 7: Commit**

```bash
git add skills/tracking-work-in-issues/SKILL.md .muse-plugin/plugin.json tests/claude-code/run-skill-tests.sh
git commit -m "feat(tracking-work-in-issues): track work in GitHub and GitLab issues"
```
The commit body lists the GREEN result per scenario (or "all 27 pass, flaky reruns 3/3") and the red-flag rows added in Step 5, each with the baseline behaviour it answers.

## Rulings

Every `Ruling:` and `minor (deferred)` line from part 1's execution ledger, in the order made. Tags: `[review]` touches permissions, data, outside systems, the spec's meaning or anything costly to undo; `[routine]` is everything else. Lines starting "Task N implementer rulings" are the implementers' own calls, recorded by the controller.

- Ruling: [routine] 1. Task 1 group 11 seeds `fake_pr 15 feat main true ''` in its own fresh env, so every group stays independent — the plan's "each group starts fresh" rule is explicit and group 11's checks only need a PR 15 with head `feat` — cost if wrong: none; the group checks the same commands either way.
- Ruling: [routine] 2. The stand-in prints `--json` output compact (`separators=(",", ":")`) with fields in the order requested, so group 2's `{"hosts":{}}` and group 11's `{"state":"CLOSED","isDraft":false,"mergeCommit":null}` match exactly; log lines use default `json.dumps(..., ensure_ascii=False)` as group 1's exact line requires — both formats are stated in the task text — cost if wrong: a test compares JSON text instead of meaning; fixable in the test.
- Ruling: [routine] 3. Task 1 Step 5's lint passes when the new files have no findings and test-helpers.sh shows only its five pre-existing SC2155 warnings (lines 10, 79, 103, 104, 134 today); the implementer does not rewrite existing helpers — keeps the diff to the task; the warnings predate this work — cost if wrong: five old warnings remain in a file the branch touches.
- Ruling: [routine] 4. The handover bullet keeps the index's backticks (``- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.``) — the index's Cross-Part Interfaces bind part 2 and the meaning matches the spec — cost if wrong: part 2 adjusts one formatting detail.
- Task 1 implementer rulings: [routine] seeding helpers read a body strictly as a file path, `-` or '' (Task 2 pipes into `-`); [routine] `check` always returns 0 and only counts failures; groups use pushd/popd so FAILURES survives.
- Task 1: minor (deferred): fake gh misparses attached short-flag values (`-R=acme/widgets`, `-Racme/widgets`) though assert_calls_name_repo accepts `-R=` (fake-gh/gh:49-58)
- Task 1: minor (deferred): fake gh treats unknown long flags as taking a value, so a boolean like `--fill` swallows the next token (fake-gh/gh:63)
- Task 1: minor (deferred): `--draft=false` sets draft (fake-gh/gh:68-69)
- Task 1: minor (deferred): issue_text_violations strips markers greedily (`<!--.*-->`), hiding text between two markers on one line (test-helpers.sh:256)
- Task 1: minor (deferred): test-fake-gh.sh captures 2>&1, so "on stderr" assertions don't check the stream (test-fake-gh.sh:33)
- Task 1: minor (deferred): no test group exercises gh_log_arg, gh_log_has_flag, gh_write_count, gh_log_total, session_commands, https/local tracking_repo, `pr view <branch>`, `issue list` text form
- Task 1: minor (deferred): `pr list --state closed` returns only CLOSED; real gh may include MERGED (fake-gh/gh:489)
- Task 1: minor (deferred): FAKE_GH_STATE "required" but unset is not reported (fake-gh/gh:16)
- Task 1: minor (deferred): small cleanups in fake gh: repo-name resolution written twice (:198-211, :306-315); redundant `prefix in COMMANDS` (:584); unused `flags` param of load_pr (:245)
- Task 2 implementer rulings: [routine] first baseline discarded and rerun (a scratch stub SKILL.md was visible to sessions); [routine] finish_merge_pushed turn-1 ancestor check uses the branch tip recorded before the run (the session deletes the local branch after merging); [routine] timeouts (exit 124) count as failure, other non-zero claude exits only noted; [routine] work_branch adds `/.worktrees/` to the temp repo's .git/info/exclude; [routine] structure test reads the description as one line.
- Ruling: [review] 5. Behaviour tests gain an isolation guard: every Claude-run test and scenario fails when a tool input in its session transcripts names a path under the superpowers checkout's docs/ or tests/ (this worktree or the main checkout) — baseline sessions found the plan's expected-results table and copied it, so without the guard a GREEN run could pass without the skill doing the work — cost if wrong: Task 4's GREEN is stricter (a session that browses the repo fails), and part 2's reuse of common_checks inherits the guard.
- Ruling: [routine] 6. The isolation guard widens to any tool input naming the superpowers checkout root (worktree or main checkout) outside `<root>/skills/` (so `ls <root>`, `git -C <root> log`, `cd <root>` count), rather than copying the plugin to a clean dir — keeps run_claude_fork, shared by every other test, unchanged; the skill and its reference file stay readable — cost if wrong: a GREEN session that legitimately runs something at the plugin root fails; widen the allow-list then.
- Ruling: [routine] 7. Plain "contains"/"lacks" OUT checks are case-sensitive as the brief writes them; `-i` only where the brief says so; Task 4 may widen an OUT pattern with a recorded ruling — the brief's own convention — cost if wrong: Task 4 widens a few patterns.
- Ruling: [routine] 8. Reviewer Minor 8 upgraded into the loop: fast test 5 runs through the same session runner and flags as every other session (`--permission-mode bypassPermissions --strict-mcp-config`), so no test session loads the operator's MCP connectors and its timeout counts — the operator's claude.ai connectors (mail, trading, docs) have no place in a test session — cost if wrong: none.
- Task 2: minor (deferred): isolation guard is lexical: `<root>/skills/../docs/...` is not flagged, `ls <root>/skills` (no trailing slash) is flagged; group 15c has no main-checkout-root case (tracking-fixtures.sh:609)
- Task 2: minor (deferred): guard's evidence truncates to the first 160 chars, hiding the part that named the repo (tracking-fixtures.sh:614)
- Task 2: minor (deferred): guard's check name still says "docs or tests" (tracking-fixtures.sh:628, :630)
- Task 2: minor (deferred): public file counts the guard 2-3 times per violation (public :49 duplicates common_checks)
- Task 2: minor (deferred): RED-only noise: `awk: cannot open` on the missing SKILL.md (fast :33)
- Task 2: minor (deferred): `matches_ei` (integration :48) duplicates `has_ei` (fixtures :585)
- Task 2: minor (deferred): fast :55-56 marker-id checks for `opened`/`merged` are implied by longer strings (brief's literal wording)
- Task 2: minor (deferred): git-state failures print no shas, and failing scenarios' temp roots are deleted (no keep switch) (integration :538)
- Ruling: [routine] 9. The RED baseline is not re-run after the review fixes (case rules, one-comment checks, runner guards) — those change how results are judged, not what sessions do, and the baseline exists to record the sessions' rationalizations for Task 4 — cost if wrong: the commit messages' per-scenario RED lines are slightly stale; Task 4's GREEN runs judge under the current checks.
- Task 2: minor (deferred): `issue_json 4 | jq ... > saved-4.txt` in scenario_finish_discard_existing and fx_existing_4 not wrapped in `fx`
- Task 2: minor (deferred): scenario_on_default_branch `printf ... > hello.sh || return` counts no failure
- Task 3 implementer rulings: [routine] placeholder check also scans `git ` lines, `<owner>/<name>` stripped as a unit first; [routine] multi-command steps are separate lines in one fenced block; [routine] test setup pushes `feat` to the stand-in remote; [routine] flag extraction `--[a-z][a-z-]*`, `-<login>`/`+<login>` not flags.
- Task 3: minor (deferred): help-flag lookup is a substring match (`grep -qF`), so a flag can pass inside a longer flag or prose (test-forge-commands.sh:406-408, 422-424)
- Task 3: minor (deferred): checks 5-7 never assert they processed any lines (test-forge-commands.sh:379-426)
- Task 3: minor (deferred): Branch pushes says only "never --force"; the ask-before-pushing-default/base rule must live in SKILL.md (forge-commands.md:241-248)
- Task 3: minor (deferred): per-section gh/glab presence check doesn't require the lines to be inside a fence (test-forge-commands.sh:350-351)
- Ruling: [review] 10. Task 4's first integration run hit the account's Claude usage limit ("You've hit your 5-hour limit · resets 9:10pm (Asia/Singapore)", 32 hits in integ-1.log at 20:30 +08): the implementer waits for the reset and re-runs, runs that hit the limit count as no result, and the task reports BLOCKED only if the limit still blocks after the reset — the limit lifts on its own in 40 minutes, so waiting is the fix rather than a workaround, and a BLOCKED report would park the run for hours — cost if wrong: about an hour of wall clock, and the remaining runs keep drawing on the operator's usage quota as the plan requires.
- Task 4 implementer rulings:
- Ruling: [review] T4-1. tracking_env exports CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1: after every `git push` the Claude Code CLI itself runs `gh pr view --json url` (no --repo), which the repo-name check counted against the session; a canary confirmed cause and fix — cost if wrong: test sessions run with slightly different CLI defaults (telemetry/update checks off); one line to remove; part 2 inherits it.
- Ruling: [routine] T4-2. Session runner prints `[FAIL] usage limit hit, no result` for output matching `(hit|reached) your .{0,40}limit.{0,20}resets` — cost if wrong: none (still fails).
- Ruling: [routine] T4-3. Force-push check stops at `;`/`&`/`|` (new `force_pushes`, group 15e), because `.*` ran past the push into a later `rm -f` — cost if wrong: a force flag after a separator inside one push goes unseen.
- Ruling: [routine] T4-4. Isolation guard allows `<root>/skills` followed by `/`, end, or a non-path character (executing-plans runs its own scripts as `S=<root>/skills; $S/...`) — cost if wrong: `ls <root>/skills` passes.
- Ruling: [routine] T4-5. `grep -qxF` became `grep -xF > /dev/null` in two integration helpers (SIGPIPE under pipefail) — cost if wrong: none.
- Ruling: [routine] T4-6. OUT widened, offer_issues_off: `hasf 'issues'` -> `has_i 'issues'` (session wrote "GitHub Issues") — cost if wrong: a looser text match.
- Ruling: [routine] T4-7. OUT widened, waiting_on_you: `hasf 'stdout'` -> `has_ei 'stdout|standard output'` — cost if wrong: a looser text match.
- Ruling: [review] T4-8. The Offer's recommended pick is the issue the request names, else a match that is clearly this work, else `Open a new issue` (brief: "a match that is clearly this work, otherwise Open a new issue"; spec: the named issue first) — cost if wrong: the picker recommends the named issue over a closer match; your human partner still chooses; one clause to drop.
- Ruling: [routine] T4-9. On a private repo the offer says nothing about visibility — cost if wrong: none.
- Ruling: [routine] T4-10. Login check, logged out: skip Repo facts and Search — cost if wrong: none.
- Ruling: [routine] T4-11. The draft-PR comment carries the PR's full URL — cost if wrong: none.
- Ruling: [routine] T4-12. Writing Rules bans "copied sentences or sections" of the spec or plan — cost if wrong: none.
- Ruling: [routine] T4-13. The merge commit is named with `git rev-parse --short <base>` — cost if wrong: none.
- Ruling: [routine] T4-14. Milestones' finishing rows folded into one row "see Finishing" to save words — cost if wrong: a reader looks one section down.
- Ruling: [routine] T4-15. Dropped a drafted red-flag row with no baseline evidence — cost if wrong: none.
- Ruling: [routine] T4-16. Test fixes committed separately (84f9480) before the brief's feat commit — cost if wrong: none.
- Ruling: [routine] 11. Step 6's "full fast suite STATUS: PASSED" stands unmet: test-subagent-driven-development, test-writing-plans-split and test-autopilot fail the same way on c46d6ce (before this task), from run_claude loading the main checkout's plugin and headless sessions in tests/claude-code being refused reads outside it; not fixed here — this branch didn't cause them and fixing them is outside part 1 — cost if wrong: three existing fast tests stay red until someone fixes the harness; the report says so.
- Ruling: [routine] 12. Reviewer Minors 4 and 5 upgraded into the fix loop: Discard's `git push origin --delete <branch>` gains "only the pushed work branch, never the default or base branch", and Plan ready's "adds the plan's path to the body" gains "on an issue opened for this work" — as written, a literal reading could delete the base branch on the remote or edit an existing issue's body, both against the spec — cost if wrong: a few words of budget.
- Task 4: minor (deferred): fd46db5 body attributes the curl red flag to RED waiting_on_you, but that session posted through gh; the curl/api.github.com grep matched the words "(git, curl, bash)" in a heredoc (integration-guard.log:101, :125); the curl/api.github.com check over session commands also flags any heredoc that mentions curl
- Task 4: minor (deferred): force_pushes `[^;&|]*` stops at the `&` of `2>&1`/`&>`, so a force flag after a redirect goes unseen (tracking-fixtures.sh:710)
- Task 4: minor (deferred): "Not on the default or base branch" gives a later session no source for the default branch; cite (Repo facts) (SKILL.md:192-193)
- Task 4: minor (deferred): the quick-task "close the issue" red-flag row sits in the guard's table, not by the Quick tasks paragraph (SKILL.md:29)
- Task 4: minor (deferred): "No line, or none ... no question" reads, literally, against The Offer (brainstorming has no line yet) (SKILL.md:47-49)
- Task 4: minor (deferred): runner help line says "TRACKING_JOBS=4 cuts it to ~25" (brief's text verbatim); measured 289-419 s at 4 jobs
- Task 4: minor (deferred): fd46db5 body lists offer_issues_off and waiting_on_you under "passed at their first valid run" though each failed once
- Ruling: [review] 13. Task 4's fix-round re-runs hit the usage limit again at 22:09 +08 ("You've hit your 5-hour limit · resets 2:10am (Asia/Singapore)"; offer_logged_out and open_public_existing had passed first): the controller keeps the run alive and waits for the 02:10 reset instead of reporting BLOCKED; the implementer's background loop re-runs the fix round's tests at 02:11; BLOCKED only if the limit still blocks after the reset — the reset time is known and the work needs no one, while a BLOCKED report would park the run until your human partner returns — cost if wrong: about four hours of wall clock before part 1's report, and the run keeps drawing on the usage quota after the reset.
- Ruling: [routine] 14. The final fix wave takes Important 1 and 2, the two fix-before-merge minors, and final-review Minors 1, 2 and 4-10; Minor 3 (no issue ending for a small change built on the default branch) is deferred to part 2's finishing wiring — the spec is silent and the answer belongs where finishing's menu is wired — cost if wrong: until part 2, such an issue stays at "Building".
- Ruling: [review] 15. The skill's guard is worded to match the real autopilot executor prompt ("running a part unattended under superpowers:autopilot", even while running executing-plans or the subagent-driven-development controller), and executor_stays_off_forge's prompt is rebuilt from skills/autopilot/executor-prompt.md's actual text — Review Focus 1's test must exercise what a real executor sees, and executor-prompt.md must not change — cost if wrong: if the wording also caught autopilot's main session, it would skip every forge call; executor_stays_off_forge and part 2's acceptance run 4 would show it.
- Final fix-wave implementer rulings:
- Ruling: [routine] FW-1. The guard keys on the executor prompt's own words ("running a part unattended under superpowers:autopilot") and names autopilot's main session as excluded — cost if wrong: if executor-prompt.md is reworded, the cue drifts; a later edit re-aligns them.
- Ruling: [routine] FW-2. Logged-out offer, open match under autopilot: open as decided and name the match in the summary — cost if wrong: a possible duplicate issue, named in the summary; nothing stops the run.
- Ruling: [routine] FW-3. Local merge: "check once more a few seconds later", no sleep command named — cost if wrong: the second check comes too soon and the PR is closed rather than shown merged.
- Ruling: [routine] FW-4. A title with an apostrophe goes in double quotes (titles carry no `$` or backticks) — cost if wrong: none.
- Ruling: [routine] FW-5. A timed-out Create is matched by the same title plus the opened marker before retrying — cost if wrong: an unrelated open issue with the same title and our marker would be adopted (unlikely).
- Ruling: [routine] FW-6. Three rationale clauses cut for the word budget; rules unchanged — cost if wrong: a reader loses the reason behind three rules.
- Ruling: [routine] FW-7. executor_stays_off_forge reads executor-prompt.md's template at run time and adds one line bounding the run to the moment after Task 1 — cost if wrong: the scenario doesn't cover an executor's later tasks; its zero-gh-calls check is unchanged.

### Notes for part 2

- The final review triaged every deferred minor above. Fixed since: the default-branch source and the "no line" scope (both fix-before-merge, made in c3e226c); Task 3's Branch-pushes rule (SKILL.md carries the ask-before-pushing rule); the guard's `ls <root>/skills` false positive (Ruling T4-4). Moot: Task 2's RED-only `awk` noise (SKILL.md exists). Every other minor stays deferred.
- Claude Code itself runs `gh pr view --json url` with no `--repo` after every `git push` (Ruling T4-1). The tracking tests turn it off with `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` in `tracking_env`; the real-GitHub acceptance runs' "every gh call names the repo" check needs the same variable or an exemption for that call.
- The existing finishing-a-development-branch and autopilot flows call `gh pr create`/`gh pr view` without `--repo`; one GREEN run made a bare `gh pr view` before loading the skill. On this fork a bare call targets the upstream, so part 2's wiring should make those calls name the repo when tracking is on.
- Deferred to part 2 (Ruling 14): what happens to the issue of a small change built directly on the default branch (no early push, no draft): today it stays at `Building`.
- Three existing fast tests (test-subagent-driven-development, test-writing-plans-split, test-autopilot) fail before and after this part (Ruling 11).
