#!/usr/bin/env bash
# Deterministic tests of the stand-in gh, the stand-in SSH transport, the
# tracking fixtures and issue_text_violations, plus a canary that a real
# headless session's Bash calls reach the stand-in.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$SCRIPT_DIR/tracking-fixtures.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

N=0
fresh() { # fresh env; seeds default unless "noseed"
    N=$((N + 1))
    G="$TEST_ROOT/g$N"
    mkdir -p "$G"
    tracking_env "$G"
    if [[ "${1:-}" != noseed ]]; then
        fake_issue 7 'Add a --version flag' ''
        fake_issue 3 'Typo in README' '' alice
        fake_pr 14 topic main true ''
    fi
}
# eq <desc> <expected> <actual>
eq() { check "$1" test "$2" = "$3"; }
# rc <desc> <expected-rc> <cmd...>: exit status and combined output into $OUT
rc() {
    local desc="$1" want="$2" got=0
    shift 2
    OUT=$("$@" 2>&1) || got=$?
    check "$desc (exit $want)" test "$got" = "$want"
}
has() { check "$1" grep -qF -- "$2" <<<"$OUT"; }
jqe() { jq -r "$2" <<<"$1"; }

echo "=== Test: stand-in gh, fixtures, issue text check ==="

echo "-- 1 version"
fresh
OUT=$(gh --version)
eq "version line" 'gh version 2.103.2 (2026-10-23)' "$(head -1 <<<"$OUT")"
eq "log last line" '{"argv": ["--version"], "body": null}' "$(tail -1 "$FAKE_GH_LOG")"

echo "-- 2 auth"
fresh
rc "auth status" 0 gh auth status --hostname github.com
has "logged in text" 'Logged in to github.com account shellkah'
OUT=$(gh auth status --hostname github.com --json hosts --jq '.hosts[][] | .state + " " + .login')
eq "auth jq" 'success shellkah' "$OUT"
fake_logout
rc "logged out status" 1 gh auth status
has "login hint" 'gh auth login'
rc "logged out json" 0 gh auth status --json hosts
eq "empty hosts" '{"hosts":{}}' "$OUT"
OUT=$(gh auth status --json hosts --jq '.hosts | length')
eq "logged out jq" 0 "$OUT"
rc "logged out list" 4 gh issue list --repo acme/widgets

echo "-- 3 repo view"
fresh
OUT=$(gh repo view acme/widgets --json visibility,hasIssuesEnabled,defaultBranchRef)
eq "repo keys" 'defaultBranchRef,hasIssuesEnabled,visibility' "$(jq -r 'keys|join(",")' <<<"$OUT")"
eq "default branch" main "$(jq -r .defaultBranchRef.name <<<"$OUT")"
eq "repo jq" PRIVATE "$(gh repo view acme/widgets --json visibility --jq .visibility)"
rc "other repo" 1 gh repo view other/repo --json visibility
has "resolve error" 'Could not resolve to a Repository'

echo "-- 4 issue create"
fresh
F="$G/body.txt"
printf 'line one\nline two\n' >"$F"
OUT=$(gh issue create --repo acme/widgets --title 'Show $HOME in the greeting' --body-file "$F" --assignee @me)
eq "create url" https://github.com/acme/widgets/issues/15 "$OUT"
eq "title" 'Show $HOME in the greeting' "$(issue_json 15 | jq -r .title)"
eq "body" "$(cat "$F")" "$(issue_json 15 | jq -r .body)"
eq "assignees" '[{"login":"shellkah"}]' "$(issue_json 15 | jq -c .assignees)"
eq "log body" "$(cat "$F")" "$(gh_log_body issue create)"

echo "-- 5 search"
fresh noseed
fake_issue 3 'Add a --version flag to hello.sh' '' alice
fake_issue 4 'Print version information' ''
fake_issue 6 'Rename the greeting' ''
fake_issue 8 'Version banner' ''
gh issue close 8 --repo acme/widgets 2>/dev/null
eq "open search" 3,4 "$(gh issue list --repo acme/widgets --state open --search 'version flag' --limit 3 --json number --jq '[.[].number]|sort|join(",")')"
eq "all search" 3,4,8 "$(gh issue list --repo acme/widgets --state all --search 'version flag' --limit 3 --json number --jq '[.[].number]|sort|join(",")')"

echo "-- 6 comment"
fresh
printf 'a comment\nsecond\n' >"$G/c.txt"
OUT=$(gh issue comment 7 --repo acme/widgets --body-file "$G/c.txt")
has "comment url" 'issues/7#issuecomment-'
eq "comment author" shellkah "$(issue_json 7 | jq -r '.comments[-1].author.login')"
eq "comment body" "$(cat "$G/c.txt")" "$(issue_json 7 | jq -r '.comments[-1].body')"
gh issue comment 7 --repo acme/widgets --body 'short note' >/dev/null
eq "short body" 'short note' "$(gh_log_body issue comment)"

echo "-- 7 edit"
fresh
printf 'new body\n' >"$G/e.txt"
gh issue edit 7 --repo acme/widgets --body-file "$G/e.txt" >/dev/null
eq "edit body" "$(cat "$G/e.txt")" "$(issue_json 7 | jq -r .body)"
gh issue edit 7 --repo acme/widgets --add-assignee @me >/dev/null
eq "assigned" shellkah "$(issue_json 7 | jq -r '.assignees[0].login')"
gh issue edit 7 --repo acme/widgets --remove-assignee @me >/dev/null
eq "unassigned" '[]' "$(issue_json 7 | jq -c .assignees)"
gh issue edit 7 --repo acme/widgets --title 'New' >/dev/null
eq "edit title" New "$(issue_json 7 | jq -r .title)"

echo "-- 8 view"
fresh
printf 'the body' | fake_issue_body 7 -
printf 'first' | fake_issue_comment 7 -
printf 'second' | fake_issue_comment 7 -
OUT=$(gh issue view 7 --repo acme/widgets --json body,comments --jq '.body, .comments[].body')
eq "view order" "the body|first|second" "$(tr '\n' '|' <<<"$OUT" | sed 's/|$//')"

echo "-- 9 close"
fresh
gh issue close 7 --repo acme/widgets --reason 'not planned' --comment 'Dropped.' 2>/dev/null
eq "state" CLOSED "$(issue_json 7 | jq -r .state)"
eq "reason" NOT_PLANNED "$(issue_json 7 | jq -r .stateReason)"
eq "close comment" 'Dropped.' "$(issue_json 7 | jq -r '.comments[-1].body')"
eq "close log body" 'Dropped.' "$(gh_log_body issue close)"
rc "close again" 0 gh issue close 7 --repo acme/widgets
gh issue close 3 --repo acme/widgets 2>/dev/null
eq "completed" COMPLETED "$(issue_json 3 | jq -r .stateReason)"

echo "-- 10 pr create in an ssh repo"
fresh
W=$(tracking_repo "$G/r")
pushd "$W" >/dev/null
eq "origin" 'git@github.com:acme/widgets.git' "$(git remote get-url origin)"
eq "ls-remote main" 1 "$(git ls-remote origin refs/heads/main | wc -l | tr -d ' ')"
printf 'pr body\n' >"$G/pb.txt"
git checkout -q -b feat
rc "before push" 1 gh pr create --repo acme/widgets --draft --base main --head feat --title T --body-file "$G/pb.txt"
has "head sha blank" "Head sha can't be blank"
git push -q -u origin feat 2>/dev/null
rc "no commits" 1 gh pr create --repo acme/widgets --draft --base main --head feat --title T --body-file "$G/pb.txt"
has "no commits text" 'No commits between main and feat'
echo x >x.txt && git add x.txt && git -c commit.gpgsign=false commit -q -m x && git push -q origin feat 2>/dev/null
rc "create" 0 gh pr create --repo acme/widgets --draft --base main --head feat --title T --body-file "$G/pb.txt"
eq "pr url" https://github.com/acme/widgets/pull/15 "$OUT"
eq "isDraft" true "$(pr_json 15 | jq -r .isDraft)"
eq "head" feat "$(pr_json 15 | jq -r .headRefName)"
eq "base" main "$(pr_json 15 | jq -r .baseRefName)"
rc "duplicate" 1 gh pr create --repo acme/widgets --draft --base main --head feat --title T --body-file "$G/pb.txt"
has "already exists" 'already exists'
git push -q origin --delete feat 2>/dev/null
eq "deleted" 0 "$(git ls-remote origin refs/heads/feat | wc -l | tr -d ' ')"
popd >/dev/null

echo "-- 11 pr list/edit/ready/close/view"
fresh noseed
fake_pr 15 feat main true ''
eq "pr list" 15 "$(gh pr list --repo acme/widgets --head feat --state all --json number,isDraft,baseRefName --jq '.[0].number')"
printf 'edited\n' >"$G/pe.txt"
gh pr edit 15 --repo acme/widgets --body-file "$G/pe.txt" >/dev/null
eq "pr body" "$(cat "$G/pe.txt")" "$(pr_json 15 | jq -r .body)"
gh pr ready 15 --repo acme/widgets 2>/dev/null
eq "ready" false "$(pr_json 15 | jq -r .isDraft)"
gh pr close 15 --repo acme/widgets --comment 'Closing.' 2>/dev/null
eq "pr closed" CLOSED "$(pr_json 15 | jq -r .state)"
eq "pr close body" 'Closing.' "$(gh_log_body pr close)"
eq "pr view" '{"state":"CLOSED","isDraft":false,"mergeCommit":null}' "$(gh pr view 15 --repo acme/widgets --json state,isDraft,mergeCommit)"

echo "-- 12 fail on demand"
fresh
before=$(issue_json 7)
FAKE_GH_FAIL='issue comment' rc "forced failure" 1 gh issue comment 7 --repo acme/widgets --body x
has "401" 'HTTP 401: Bad credentials'
eq "logged" 1 "$(gh_log_count issue comment)"
eq "unchanged" "$before" "$(issue_json 7)"
FAKE_GH_FAIL='issue comment' rc "edit still works" 0 gh issue edit 7 --repo acme/widgets --title y

echo "-- 13 unknown command"
fresh
rc "pr merge" 1 gh pr merge 14 --repo acme/widgets
has "unknown" 'unknown command "merge" for "gh pr"'
eq "merge logged" 1 "$(gh_log_count pr merge)"

rc "api unknown" 1 gh api repos/acme/widgets
has "api word" 'unknown command "api" for "gh"'
rc "missing issue by url" 1 gh issue view https://github.com/acme/widgets/issues/99 --repo acme/widgets
has "number only" 'with the number of 99. (repository.issue)'
rc "missing pr by url" 1 gh pr view https://github.com/acme/widgets/pull/98 --repo acme/widgets
has "pr number only" 'with the number of 98.'

echo "-- 14 assert_calls_name_repo"
fresh
gh issue comment 7 --body x >/dev/null 2>&1 || true
check "succeeded" test "$(issue_json 7 | jq '.comments|length')" = 1
rc "missing repo" 1 assert_calls_name_repo acme/widgets
has "names the call" 'issue comment 7'
rm -f "$FAKE_GH_LOG"
gh issue view 7 --repo acme/widgets --json title >/dev/null
gh issue list -R acme/widgets >/dev/null
gh --version >/dev/null
gh auth status >/dev/null 2>&1
rc "all name repo" 0 assert_calls_name_repo acme/widgets
eq "silent" "" "$OUT"

echo "-- 15 issue_text_violations"
fresh
printf 'The flag now prints the version.\n<!-- superpowers:part-1-done -->\nMail t@example.com for help.\n' >"$G/clean.txt"
rc "clean" 0 issue_text_violations "$G/clean.txt"
eq "clean silent" "" "$OUT"
printf 'Task 3\npart 2 of 3\nledger\nthe reviewer\na subagent\nthe executor\nthe brief\nRED\n@alice\n' >"$G/dirty.txt"
rc "dirty" 0 issue_text_violations "$G/dirty.txt"
eq "nine lines" 9 "$(wc -l <<<"$OUT" | tr -d ' ')"
has "task line" 'task number: Task 3 (line 1)'
has "mention line" 'mention: @alice (line 9)'

echo "-- 15b session_commands"
fresh
SAVED_HOME=$HOME
export HOME="$G/home"
SD="$G/proj"
mkdir -p "$SD"
RP=$(cd "$SD" && pwd -P)
PD="$HOME/.claude/projects/$(echo "$RP" | sed 's|[^a-zA-Z0-9]|-|g')"
mkdir -p "$PD/sess1/subagents"
printf '%s\n' '{"message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"echo top\nline2"}},{"type":"tool_use","name":"Read","input":{"file_path":"x"}}]}}' >"$PD/sess1.jsonl"
printf '%s\n' '{"message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git push --force"}}]}}' >"$PD/sess1/subagents/agent-a.jsonl"
OUT=$(session_commands "$SD")
export HOME=$SAVED_HOME
has "top-level command" 'echo top; line2'
has "subagent command" 'git push --force'
eq "only bash calls" 2 "$(wc -l <<<"$OUT" | tr -d ' ')"

echo "-- 15c session_repo_reads"
fresh
SAVED_HOME=$HOME
export HOME="$G/home"
SD="$G/proj2"
mkdir -p "$SD"
RP=$(cd "$SD" && pwd -P)
PD="$HOME/.claude/projects/$(echo "$RP" | sed 's|[^a-zA-Z0-9]|-|g')"
mkdir -p "$PD/sess1/subagents"
REPO=$(cd "$SCRIPT_DIR/../.." && pwd -P)
jq -n -c --arg a "$REPO/skills/x/SKILL.md" --arg b "$REPO/docs/superpowers/plans/x.md" --arg d "$G/proj2/docs/superpowers/specs/y.md" \
    '{message:{content:[{type:"tool_use",name:"Read",input:{file_path:$a}},{type:"tool_use",name:"Read",input:{file_path:$b}},{type:"tool_use",name:"Read",input:{file_path:$d}}]}}' >"$PD/sess1.jsonl"
jq -n -c --arg c "cat $REPO/tests/claude-code/foo" '{message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}' >"$PD/sess1/subagents/agent-a.jsonl"
rc "reads found" 1 session_repo_reads "$SD"
export HOME=$SAVED_HOME
eq "two FAIL lines" 2 "$(grep -c '^\[FAIL\] session read the superpowers repo: ' <<<"$OUT")"
has "plan read" 'Read '"$REPO"'/docs/superpowers/plans/x.md'
has "bash read" 'Bash cat '"$REPO"'/tests/claude-code/foo'

echo "-- 16 canary"
fresh
W=$(tracking_repo "$G/r")
pushd "$W" >/dev/null
run_claude_fork 'Run these two shell commands and show me their output: gh --version ; gh issue list --repo acme/widgets' 120 --permission-mode bypassPermissions --strict-mcp-config >"$G/canary.out" || true
check "canary: --version call logged" test "$(gh_log_count --version)" -ge 1
check "canary: issue list call logged" test "$(gh_log_count issue list)" -ge 1
popd >/dev/null

echo
if [[ $FAILURES -eq 0 ]]; then
    echo PASS
else
    echo "FAIL ($FAILURES)"
    exit 1
fi
