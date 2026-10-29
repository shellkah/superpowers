#!/usr/bin/env bash
# Fixtures for the issue-tracking tests: test repos, state seeding for the
# stand-in gh, and queries over its call log. Source after test-helpers.sh.

_FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create <root>/remote.git (bare) and <root>/work (a small repo on main).
# Usage: tracking_repo <root> [ssh|https|local]   # prints <root>/work
tracking_repo() {
    local root form work remote
    [[ -n "${1:-}" ]] || { echo "tracking_repo: no root" >&2; return 1; }
    mkdir -p "$1" || return 1
    root="$(cd "$1" && pwd)"
    form="${2:-ssh}"
    work="$root/work"
    remote="$root/remote.git"
    git init -q --bare -b main "$remote"
    git init -q -b main "$work"
    (
        cd "$work" || exit 1
        git config user.name "Test User"
        git config user.email "test@example.com"
        git config commit.gpgsign false
        cat > hello.sh <<'SH'
#!/bin/sh
echo "Hello, ${1:-world}!"
SH
        chmod +x hello.sh
        cat > test.sh <<'SH'
#!/bin/sh
if [ "$(./hello.sh)" != "Hello, world!" ]; then
    echo "FAIL"
    exit 1
fi
echo "PASS"
SH
        chmod +x test.sh
        cat > README.md <<'MD'
# widgets

A tiny greeter. Run teh script with `./hello.sh`.
MD
        git add hello.sh test.sh README.md
        git commit -q -m "Add hello script, test and README"
        case "$form" in
            ssh)
                git remote add origin git@github.com:acme/widgets.git
                git config core.sshCommand "$_FIXTURES_DIR/fake-gh/fake-ssh $remote"
                git config ssh.variant simple
                git push -q -u origin main > /dev/null 2>&1
                ;;
            https)
                git remote add origin https://github.com/acme/widgets.git
                ;;
            local)
                git remote add origin "$remote"
                git push -q -u origin main > /dev/null 2>&1
                ;;
            *) echo "tracking_repo: unknown form: $form" >&2; exit 1 ;;
        esac
    ) || return 1
    echo "$work"
}

# Usage: tracking_env <root>
tracking_env() {
    setup_fake_gh "$1/gh"
    fake_login shellkah
    fake_repo_facts PRIVATE true main
    export GH_TOKEN=invalid-token-for-tests
    export GH_PROMPT_DISABLED=1
    export GIT_TERMINAL_PROMPT=0
}

fake_login() { printf '%s\n' "$1" > "$FAKE_GH_STATE/login"; }
fake_logout() { rm -f "$FAKE_GH_STATE/login"; }

# Usage: fake_repo_facts <PUBLIC|PRIVATE> <true|false> <default-branch>
fake_repo_facts() {
    local private=false
    [[ "$1" == PRIVATE ]] && private=true
    jq -n --arg vis "$1" --argjson priv "$private" --argjson issues "$2" --arg br "$3" '{
        nameWithOwner: "acme/widgets", name: "widgets", owner: {login: "acme"},
        visibility: $vis, isPrivate: $priv, hasIssuesEnabled: $issues,
        defaultBranchRef: {name: $br}, url: "https://github.com/acme/widgets", isFork: false}' \
        > "$FAKE_GH_STATE/repo.json"
}

# Copy a body argument (file path, "-" for stdin, or '' for empty) to a file.
_fake_body_file() {
    local out
    out="$(mktemp)"
    case "$1" in
        '') : > "$out" ;;
        -) cat > "$out" ;;
        *) cp "$1" "$out" ;;
    esac
    echo "$out"
}

_fake_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Usage: fake_issue <N> <title> <body> [assignee]
fake_issue() {
    local bf t
    bf="$(_fake_body_file "$3")"
    t="$(_fake_now)"
    mkdir -p "$FAKE_GH_STATE/issues"
    jq -n --argjson n "$1" --arg title "$2" --rawfile body "$bf" --arg assignee "${4:-}" --arg t "$t" '{
        number: $n, title: $title, body: $body, state: "OPEN", stateReason: null,
        author: {login: "alice"},
        assignees: (if $assignee == "" then [] else [{login: $assignee}] end),
        comments: [], url: ("https://github.com/acme/widgets/issues/" + ($n|tostring)),
        createdAt: $t, updatedAt: $t, labels: []}' > "$FAKE_GH_STATE/issues/$1.json"
    rm -f "$bf"
}

# Usage: fake_issue_comment <N> <body>
fake_issue_comment() {
    local f="$FAKE_GH_STATE/issues/$1.json" bf login
    bf="$(_fake_body_file "$2")"
    login="$(cat "$FAKE_GH_STATE/login")"
    jq --rawfile body "$bf" --arg login "$login" --arg t "$(_fake_now)" '
        .comments += [{author: {login: $login}, body: $body, createdAt: $t,
                       url: (.url + "#issuecomment-" + ((1000 + (.comments|length) + 1)|tostring))}]' \
        "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    rm -f "$bf"
}

# Usage: fake_issue_body <N> <body>
fake_issue_body() {
    local f="$FAKE_GH_STATE/issues/$1.json" bf
    bf="$(_fake_body_file "$2")"
    jq --rawfile body "$bf" '.body = $body' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    rm -f "$bf"
}

# Usage: fake_pr <P> <head> <base> <true|false> <body>
fake_pr() {
    local bf
    bf="$(_fake_body_file "$5")"
    mkdir -p "$FAKE_GH_STATE/pulls"
    jq -n --argjson n "$1" --arg head "$2" --arg base "$3" --argjson draft "$4" --rawfile body "$bf" '{
        number: $n, title: ("PR " + ($n|tostring)), body: $body, state: "OPEN", isDraft: $draft,
        headRefName: $head, baseRefName: $base,
        url: ("https://github.com/acme/widgets/pull/" + ($n|tostring)),
        mergeCommit: null, mergedAt: null, closed: false, author: {login: "alice"}, comments: []}' \
        > "$FAKE_GH_STATE/pulls/$1.json"
    rm -f "$bf"
}

issue_json() { cat "$FAKE_GH_STATE/issues/$1.json"; }
pr_json() { cat "$FAKE_GH_STATE/pulls/$1.json"; }

# Log lines whose argv starts with the given words.
# Usage: gh_log_calls <word1> [<word2>]
gh_log_calls() {
    [[ -f "${FAKE_GH_LOG:-}" ]] || return 0
    jq -R -r --arg a "$1" --arg b "${2:-}" '
        select(fromjson | .argv as $v | $v[0] == $a and ($b == "" or $v[1] == $b))' "$FAKE_GH_LOG"
}

gh_log_count() { gh_log_calls "$@" | awk 'END { print NR }'; }

gh_log_total() {
    if [[ -f "${FAKE_GH_LOG:-}" ]]; then awk 'END { print NR }' "$FAKE_GH_LOG"; else echo 0; fi
}

# Usage: gh_log_body <word1> <word2> [<n>]
gh_log_body() {
    gh_log_calls "$1" "$2" | _nth "${3:-}" | jq -r '.body // empty'
}

# n-th line of stdin (default: last)
_nth() {
    if [[ -n "${1:-}" ]]; then sed -n "${1}p"; else tail -n 1; fi
}

_GH_FLAG_JQ='def flagvals($re):
    .argv as $v
    | [range(0; $v|length) as $i | $v[$i] as $t
       | if ($t | test("^(" + $re + ")$")) then ($v[$i+1] // "")
         elif ($t | test("^(" + $re + ")=")) then ($t | sub("^[^=]*="; ""))
         else empty end];'

# Usage: gh_log_arg <word1> <word2> <flag-regex> [<n>]
gh_log_arg() {
    gh_log_calls "$1" "$2" | _nth "${4:-}" | jq -r --arg re "$3" "$_GH_FLAG_JQ"' flagvals($re)[0] // empty'
}

# Usage: gh_log_has_flag <word1> <word2> <flag-regex> [<value>]
gh_log_has_flag() {
    local hits
    hits="$(gh_log_calls "$1" "$2" | jq -r --arg re "$3" --arg val "${4-}" --argjson chk "$([[ $# -ge 4 ]] && echo true || echo false)" \
        "$_GH_FLAG_JQ"' flagvals($re) | select(length > 0 and (($chk | not) or any(.[]; . == $val))) | "hit"')"
    [[ -n "$hits" ]]
}

gh_write_count() {
    [[ -f "${FAKE_GH_LOG:-}" ]] || { echo 0; return 0; }
    jq -R -r 'fromjson | .argv[0:2] | join(" ")
        | select(. == "issue create" or . == "issue comment" or . == "issue edit" or . == "issue close"
                 or . == "pr create" or . == "pr edit" or . == "pr ready" or . == "pr close")' "$FAKE_GH_LOG" \
        | awk 'END { print NR }'
}

# Usage: assert_calls_name_repo <owner/name>
assert_calls_name_repo() {
    [[ -f "${FAKE_GH_LOG:-}" ]] || return 0
    local bad
    bad="$(jq -R -r --arg repo "$1" '
        fromjson | .argv as $v
        | select($v[0] != "--version" and $v[0] != "auth")
        | select(
            ([range(0; $v|length) as $i
              | select(($v[$i] == "--repo" or $v[$i] == "-R") and $v[$i+1] == $repo
                       or $v[$i] == "--repo=" + $repo or $v[$i] == "-R=" + $repo)] | length) == 0
            and ([$v[] | select(test("^https?://[^/]+/" + $repo + "(/|$)"))] | length) == 0
            and (($v[0] == "repo" and $v[1] == "view" and $v[2] == $repo) | not))
        | "[FAIL] gh call does not name " + $repo + ": " + ($v | join(" "))' "$FAKE_GH_LOG")"
    if [[ -n "$bad" ]]; then
        echo "$bad"
        return 1
    fi
    return 0
}

# Print the command of every Bash tool call in the sessions run from <dir>.
# Usage: session_commands <dir>
session_commands() {
    local real proj f
    real="$(cd "$1" && pwd -P)"
    proj="$HOME/.claude/projects/$(echo "$real" | sed 's|[^a-zA-Z0-9]|-|g')"
    [[ -d "$proj" ]] || return 0
    while IFS= read -r f; do
        jq -r 'try (.message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command
                    | gsub("\n"; "; ")) catch empty' "$f" 2> /dev/null
    done < <(find "$proj" -name '*.jsonl' | sort)
}

# Usage: check <description> <command> [args...]
check() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        echo "  [PASS] $desc"
    else
        echo "  [FAIL] $desc"
        FAILURES=$((FAILURES + 1))
    fi
}

# ---------------------------------------------------------------------------
# Scenario fixtures and shared checks
# ---------------------------------------------------------------------------

export ISSUE12='**Issue:** https://github.com/acme/widgets/issues/12 (opened for this work)'
SPEC_PATH=docs/superpowers/specs/2026-01-01-version-flag-design.md
PLAN_PATH=docs/superpowers/plans/2026-01-01-version-flag.md
INDEX_PATH=docs/superpowers/plans/2026-01-01-version-flag-index.md
PART_PATH=docs/superpowers/plans/2026-01-01-version-flag-part-1-core.md
OPENED_MARKER='<!-- superpowers:opened -->'

# Write the spec for the --version flag.
# Usage: _write_spec <work> [<issue-line>]
_write_spec() {
    [[ -n "${1:-}" && -d "$1" ]] || { echo "_write_spec: not a directory: ${1:-}" >&2; return 1; }
    local f="$1/$SPEC_PATH"
    mkdir -p "$(dirname "$f")"
    {
        echo '# hello.sh --version'
        echo
        if [[ -n "${2:-}" ]]; then
            echo "$2"
            echo
        fi
        echo '## Why'
        echo
        echo 'People who copy hello.sh around cannot tell which release they are running, so bug reports never say which version misbehaved.'
        echo
        echo '## Goals'
        echo
        echo '- `./hello.sh --version` prints the contents of the VERSION file and exits 0.'
        echo '- A VERSION file at the repo root holds the release number, starting at 1.0.0.'
        echo
        echo "## How we'll know it's right"
        echo
        echo '`bash test.sh` checks both the greeting and the version output.'
    } > "$f"
}

# The two tasks of the plan, as the unsplit plan and the part file list them.
_plan_tasks() {
    echo '### Task 1: VERSION file'
    echo
    echo '- [ ] Create `VERSION` containing `1.0.0`; commit.'
    echo
    echo '### Task 2: --version flag'
    echo
    echo '- [ ] Make `./hello.sh --version` print the contents of VERSION; add the check to test.sh; commit.'
}

# Usage: _commit_and_push_main <work> <message>
_commit_and_push_main() {
    [[ -n "${1:-}" && -d "$1" ]] || { echo "_commit_and_push_main: not a directory: ${1:-}" >&2; return 1; }
    git -C "$1" add -A docs
    git -C "$1" commit -q -m "$2"
    git -C "$1" push -q origin main > /dev/null 2>&1
}

# Usage: version_flag_docs <work> [<issue-line>]
version_flag_docs() {
    [[ -n "${1:-}" && -d "$1" ]] || { echo "version_flag_docs: not a directory: ${1:-}" >&2; return 1; }
    local work="$1" issue="${2:-}" f
    _write_spec "$work" "$issue"
    f="$work/$PLAN_PATH"
    mkdir -p "$(dirname "$f")"
    {
        echo '# hello.sh --version Implementation Plan'
        echo
        if [[ -n "$issue" ]]; then
            echo "$issue"
            echo
        fi
        echo '**Goal:** `./hello.sh --version` prints the release number from VERSION.'
        echo
        echo "**Spec:** \`$SPEC_PATH\`"
        echo
        _plan_tasks
    } > "$f"
    _commit_and_push_main "$work" "Add version flag spec and plan"
}

# Usage: split_plan_docs <work> <issue-line>
split_plan_docs() {
    [[ -n "${1:-}" && -d "$1" ]] || { echo "split_plan_docs: not a directory: ${1:-}" >&2; return 1; }
    local work="$1" issue="$2"
    _write_spec "$work" "$issue"
    mkdir -p "$work/docs/superpowers/plans"
    {
        echo '# hello.sh --version Implementation Plan'
        echo
        echo "$issue"
        echo
        echo '## Parts'
        echo
        echo '| # | Part | Covers |'
        echo '|---|------|--------|'
        echo '| 1 | `core` | VERSION file and `--version` |'
        echo '| 2 | `help` | a `--help` text |'
    } > "$work/$INDEX_PATH"
    {
        echo '# hello.sh --version Implementation Plan: core'
        echo
        echo "**Part 1 of 2** · Index: \`$INDEX_PATH\`"
        echo
        echo "$issue"
        echo
        echo '**Goal:** `./hello.sh --version` prints the release number from VERSION.'
        echo
        echo "**Spec:** \`$SPEC_PATH\`"
        echo
        _plan_tasks
    } > "$work/$PART_PATH"
    _commit_and_push_main "$work" "Add version flag spec and split plan"
}

# Usage: opened_issue_12 [<status>] [plan|noplan]
opened_issue_12() {
    local status="${1:-Planning}" mode="${2:-plan}"
    {
        echo "**Status:** $status"
        echo
        echo 'hello.sh will print its release number with --version, so bug reports can say which version misbehaved.'
        echo
        echo "Spec: \`$SPEC_PATH\`"
        [[ "$mode" == noplan ]] || echo "Plan: \`$PLAN_PATH\`"
        echo "$OPENED_MARKER"
    } | fake_issue 12 'Add a --version flag to hello.sh' - shellkah
    if [[ "$mode" != noplan ]]; then
        printf '%s\n' 'The plan is written and waiting for review.' '<!-- superpowers:plan-ready -->' \
            | fake_issue_comment 12 -
    fi
}

# Usage: existing_issue_4 [<assignee>]
existing_issue_4() {
    printf '%s\n' 'It would help to see which version of hello.sh is installed.' \
        | fake_issue 4 'Print version information' - "${1:-}"
}

# Cut version-flag from <base>, commit Task 1, print the directory to run in.
# Usage: work_branch <work> <base> worktree|checkout
work_branch() {
    [[ -n "${1:-}" && -d "$1" ]] || { echo "work_branch: not a directory: ${1:-}" >&2; return 1; }
    local work="$1" base="$2" mode="$3" dir
    case "$mode" in
        worktree)
            mkdir -p "$work/.git/info"
            grep -qxF '/.worktrees/' "$work/.git/info/exclude" 2> /dev/null \
                || echo '/.worktrees/' >> "$work/.git/info/exclude"
            git -C "$work" worktree add -q -b version-flag "$work/.worktrees/version-flag" "$base" > /dev/null 2>&1 || return 1
            dir="$work/.worktrees/version-flag"
            ;;
        checkout)
            git -C "$work" checkout -q -b version-flag "$base" > /dev/null 2>&1 || return 1
            dir="$work"
            ;;
        *) echo "work_branch: unknown mode: $mode" >&2; return 1 ;;
    esac
    echo '1.0.0' > "$dir/VERSION"
    git -C "$dir" add VERSION
    git -C "$dir" commit -q -m "Add VERSION file"
    echo "$dir"
}

# Usage: task2_commit <dir>
task2_commit() {
    [[ -n "${1:-}" && -d "$1" ]] || { echo "task2_commit: not a directory: ${1:-}" >&2; return 1; }
    local dir="$1"
    cat > "$dir/hello.sh" <<'SH'
#!/bin/sh
if [ "$1" = "--version" ]; then
    cat "$(dirname "$0")/VERSION"
    exit 0
fi
echo "Hello, ${1:-world}!"
SH
    cat >> "$dir/test.sh" <<'SH'
if [ "$(./hello.sh --version)" != "$(cat VERSION)" ]; then
    echo "FAIL version"
    exit 1
fi
SH
    git -C "$dir" add hello.sh test.sh
    git -C "$dir" commit -q -m "Add --version flag"
}

# Usage: push_work <dir>
push_work() { [[ -n "${1:-}" && -d "$1" ]] || return 1; git -C "$1" push -q -u origin version-flag > /dev/null 2>&1; }

# Usage: draft_pr_13 <base> [<issue>]
draft_pr_13() {
    local base="$1" issue="${2:-12}" blob=https://github.com/acme/widgets/blob/version-flag
    printf '%s\n' 'hello.sh gains a --version flag.' '' "Closes #$issue" | fake_pr 13 version-flag "$base" true -
    printf '%s\n' 'Draft pull request: https://github.com/acme/widgets/pull/13' '<!-- superpowers:draft-pr -->' \
        | fake_issue_comment "$issue" -
    if [[ "$issue" == 12 ]]; then
        issue_json 12 | jq -j '.body' \
            | sed -E -e '1s/.*/**Status:** Building: draft PR #13/' \
                -e "s#\`(docs/superpowers/[^\`]*)\`#$blob/\\1#g" \
            | fake_issue_body 12 -
    fi
}

# Usage: dev_base <work>
dev_base() {
    [[ -n "${1:-}" && -d "$1" ]] || { echo "dev_base: not a directory: ${1:-}" >&2; return 1; }
    git -C "$1" branch dev main
    git -C "$1" push -q origin dev > /dev/null 2>&1
}

# Print the sha of refs/heads/<branch> in <root>/remote.git, or nothing.
# Usage: bare_ref <root> <branch>
bare_ref() { [[ -n "${1:-}" && -d "$1/remote.git" ]] || return 0; git --git-dir="$1/remote.git" rev-parse -q --verify "refs/heads/$2" 2> /dev/null || true; }

# Usage: first_line_after_title <file>
first_line_after_title() {
    awk 'found && NF { print; exit } /^# / && !found { found = 1 }' "$1"
}

# Source lines of 40 or more characters (leading #, -, * and spaces stripped)
# that appear verbatim in the text file.
# Usage: copied_lines <text-file> <source-file>
copied_lines() {
    local line
    while IFS= read -r line; do
        line="$(sed -E 's/^[#*[:space:]-]+//' <<< "$line")"
        [[ ${#line} -ge 40 ]] || continue
        if grep -qF -- "$line" "$1"; then
            echo "$line"
        fi
    done < "$2"
}

# ---- prompt pieces ----
export HEADLESS='This is a headless run with no question tool: ask any question in plain text with numbered options, then end your turn.'
export C_APPROVED='The spec at docs/superpowers/specs/2026-01-01-version-flag-design.md is approved: your human partner just said it looks good.'
export C_EXEC='You are executing the plan at docs/superpowers/plans/2026-01-01-version-flag.md with superpowers:executing-plans, in this worktree.'
export C_FINISH='Implementation of the plan at docs/superpowers/plans/2026-01-01-version-flag.md is complete on this branch: its tests pass, and there were no rulings or deferred minors. You are in superpowers:finishing-a-development-branch.'

# Usage: c_brain [<extra>]
c_brain() {
    printf '%s' "We are in superpowers:brainstorming for this request: \"Add a --version flag to hello.sh.${1:-}\" The work is sized as a small change, and this is the last round of questions."
}

# Usage: moment <what> <Section>
moment() {
    printf '%s' "If this work tracks an issue, $1 as superpowers:tracking-work-in-issues says ($2)"
}

# Run a fixture step; a failure counts as a failed check and returns 1.
# Usage: fx <command> [args...]
fx() {
    "$@" || { check "fixture: $1 failed" false; return 1; }
}

# Run a fixture that prints a value; set <var> to it. Failure or an empty value
# counts as a failed check and returns 1.
# Usage: fxv <var> <command> [args...]
fxv() {
    local var="$1" val
    shift
    val="$("$@")" && [[ -n "$val" ]] || { check "fixture: $1 failed" false; return 1; }
    printf -v "$var" '%s' "$val"
}

# ---- running a session ----

# Sessions start only inside SESSION_ROOT (the scenario's or file's temp root).

# Run a prompt in <dir>; the output goes to the global OUT.
# Usage: run_moment <dir> <timeout> <prompt>
run_moment() { _run_session OUT "$1" "$2" "$3"; }

# Same, continuing the last session in <dir>; the output goes to OUT2.
# Usage: continue_moment <dir> <timeout> <message>
continue_moment() { _run_session OUT2 "$1" "$2" "$3" --continue; }

_run_session() {
    local var="$1" dir="$2" t="$3" prompt="$4" rc=0 out real top
    shift 4
    printf -v "$var" '%s' ""
    if [[ -z "$dir" || ! -d "$dir" || -z "${SESSION_ROOT:-}" || ! -d "${SESSION_ROOT:-}" ]]; then
        echo "  [FAIL] session not started: '$dir' is not a directory under the temp root '${SESSION_ROOT:-}'"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    real="$(cd "$dir" && pwd -P)"
    top="$(cd "$SESSION_ROOT" && pwd -P)"
    if [[ "$real" != "$top" && "$real" != "$top"/* ]]; then
        echo "  [FAIL] session not started: '$real' is outside the temp root '$top'"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    out="$(cd "$dir" && run_claude_fork "$prompt" "$t" --permission-mode bypassPermissions --strict-mcp-config "$@")" || rc=$?
    printf -v "$var" '%s' "$out"
    if [[ $rc -eq 124 ]]; then
        echo "  [FAIL] session timed out after ${t}s; output so far:"
        sed 's/^/    /' <<< "$out"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    if [[ $rc -ne 0 ]]; then
        echo "  [FAIL] session exited with status $rc; output:"
        sed 's/^/    /' <<< "$out"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    if [[ -z "$out" ]]; then
        echo "  [FAIL] session produced no output"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    if [[ -z "$(latest_transcript "$dir")" ]]; then
        echo "  [FAIL] session left no transcript for $dir"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    return 0
}

# Print the session output and the call log, for a failing test.
show_run_context() {
    echo "  --- final output ---"
    sed 's/^/    /' <<< "${OUT:-}"
    if [[ -n "${OUT2:-}" ]]; then
        echo "  --- second turn output ---"
        sed 's/^/    /' <<< "$OUT2"
    fi
    echo "  --- gh log ---"
    if [[ -s "${FAKE_GH_LOG:-}" ]]; then sed 's/^/    /' "$FAKE_GH_LOG"; else echo "    (no gh calls)"; fi
}

# ---- naming a number in a logged call ----

# jq: the first positional word of a call after its two command words.
_POS_JQ='def positional:
    .argv[2:] as $a
    | (reduce range(0; $a|length) as $i ({skip: false, pos: null};
        if .skip then .skip = false
        elif ($a[$i] | startswith("-")) then
            (if ($a[$i] | test("=")) or ($a[$i] | IN("--draft", "-d", "--comments", "--delete-branch", "--web", "-w")) then . else .skip = true end)
        elif .pos == null then .pos = $a[$i]
        else . end)).pos;'

# Logged calls whose positional is <N> or a URL ending /issues/<N> or /pull/<N>.
# Usage: named_calls <word1> <word2> <N>
named_calls() {
    gh_log_calls "$1" "$2" | jq -c --arg n "$3" "$_POS_JQ"'
        select(positional as $p | $p != null and ($p == $n or ($p | test("/(issues|pull)/" + $n + "$"))))'
}

# Usage: named_count <word1> <word2> <N>
named_count() { named_calls "$@" | awk 'END { print NR }'; }

# Body of the n-th (default last) such call.
# Usage: named_body <word1> <word2> <N> [<n>]
named_body() { named_calls "$1" "$2" "$3" | _nth "${4:-}" | jq -r '.body // empty'; }

# One line per such call: the last non-empty line of its body.
# Usage: named_last_lines <word1> <word2> <N>
named_last_lines() {
    named_calls "$@" | jq -r '(.body // "") | split("\n") | map(select(test("\\S"))) | (last // "")'
}

# Body of the last such call whose last non-empty line is <marker>.
# Usage: named_body_ending <word1> <word2> <N> <marker>
named_body_ending() {
    named_calls "$1" "$2" "$3" | jq -rs --arg m "$4" \
        'map(select((.body // "") | split("\n") | map(select(test("\\S"))) | (last // "") == $m)) | (last // {}) | (.body // "")'
}

# First value of a flag among calls naming <N> (last such call by default).
# Usage: named_arg <word1> <word2> <N> <flag-regex>
named_arg() {
    named_calls "$1" "$2" "$3" | _nth "" | jq -r --arg re "$4" "$_GH_FLAG_JQ"' flagvals($re)[0] // empty'
}

# Usage: named_has_flag <word1> <word2> <N> <flag-regex> [<value>]
named_has_flag() {
    local hits
    hits="$(named_calls "$1" "$2" "$3" | jq -r --arg re "$4" --arg val "${5-}" --argjson chk "$([[ $# -ge 5 ]] && echo true || echo false)" \
        "$_GH_FLAG_JQ"' flagvals($re) | select(length > 0 and (($chk | not) or any(.[]; . == $val))) | "hit"')"
    [[ -n "$hits" ]]
}

# ---- small text helpers ----
first_line() { sed -n '1p' <<< "$1"; }
last_nonempty() { awk 'NF { l = $0 } END { print l }' <<< "$1"; }
hasf() { grep -qF -- "$2" <<< "$1"; }
has_i() { grep -qi -- "$2" <<< "$1"; }
has_ei() { grep -qiE -- "$2" <<< "$1"; }
not() { ! "$@"; }

# Print one "[FAIL] session read the superpowers repo: <tool> <path or command>"
# line for every tool call, in any transcript of the sessions run from <dir>
# (subagents included), whose input names either superpowers checkout root
# (the repo run_claude_fork loads, and the main checkout it belongs to)
# anywhere except under <root>/skills/. So ls, git -C, cd and find on the root
# and reads of docs/ or tests/ all count; reads of the skill do not. The
# worktree sits inside the main checkout: <root>/skills/ is stripped for both
# roots first, so a worktree skills/ path is never counted through the main
# root's prefix. Returns 1 when it printed.
# Usage: session_repo_reads <dir> [<repo-root>]
session_repo_reads() {
    local real proj f root common main out skills_re roots_re hit=0 line
    real="$(cd "$1" && pwd -P)"
    proj="$HOME/.claude/projects/$(echo "$real" | sed 's|[^a-zA-Z0-9]|-|g')"
    [[ -d "$proj" ]] || return 0
    root="${2:-$(cd "$_FIXTURES_DIR/../.." && pwd -P)}"
    common="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2> /dev/null || true)"
    main="$root"
    [[ -z "$common" ]] || main="$(dirname "$common")"
    root="$(sed 's/[][\.*^$()+?{|]/\\&/g' <<< "$root")"
    main="$(sed 's/[][\.*^$()+?{|]/\\&/g' <<< "$main")"
    skills_re="($root|$main)/skills/"
    roots_re="($root|$main)(\$|[^A-Za-z0-9._-])"
    while IFS= read -r f; do
        out="$(jq -r --arg sk "$skills_re" --arg rr "$roots_re" 'try (.message.content[]? | select(.type == "tool_use") | .name as $n
            | [.input | .. | strings | select(gsub($sk; "") | test($rr))] | first // empty
            | gsub("\n"; "; ") | .[0:160] | "[FAIL] session read the superpowers repo: " + $n + " " + .) catch empty' "$f" 2> /dev/null)"
        if [[ -n "$out" ]]; then
            while IFS= read -r line; do echo "$line"; done <<< "$out"
            hit=1
        fi
    done < <(find "$proj" -name '*.jsonl' | sort)
    return $hit
}

# Count the isolation guard as one check; show what the session read.
# Usage: check_isolation <dir>
check_isolation() {
    local v
    v="$(session_repo_reads "$1")" || true
    if [[ -z "$v" ]]; then check "session did not read the superpowers docs or tests" true; else
        sed 's/^/    /' <<< "$v"
        check "session did not read the superpowers docs or tests" false
    fi
}

# ---- shared checks ----

# Everything every scenario must keep true. <dir> is where the session ran.
# Usage: common_checks <dir>
common_checks() {
    local dir="$1" v bad f n i cmd w1 w2 cmds
    v="$(assert_calls_name_repo acme/widgets)" || true
    if [[ -z "$v" ]]; then check "every gh call names acme/widgets" true; else
        sed 's/^/    /' <<< "$v"
        check "every gh call names acme/widgets" false
    fi

    bad=""
    f="$(mktemp)"
    for cmd in "issue create" "issue comment" "issue edit" "issue close" "pr create" "pr close"; do
        read -r w1 w2 <<< "$cmd"
        n="$(gh_log_count "$w1" "$w2")"
        for ((i = 1; i <= n; i++)); do
            gh_log_body "$w1" "$w2" "$i" > "$f"
            v="$(issue_text_violations "$f")"
            [[ -z "$v" ]] || bad+="$cmd #$i body: $(tr '\n' ';' <<< "$v")"$'\n'
        done
    done
    for cmd in "issue create" "pr create"; do
        read -r w1 w2 <<< "$cmd"
        n="$(gh_log_count "$w1" "$w2")"
        for ((i = 1; i <= n; i++)); do
            gh_log_arg "$w1" "$w2" '--title|-t' "$i" > "$f"
            v="$(issue_text_violations "$f")"
            [[ -z "$v" ]] || bad+="$cmd #$i title: $(tr '\n' ';' <<< "$v")"$'\n'
        done
    done
    rm -f "$f"
    if [[ -z "$bad" ]]; then check "posted texts follow the writing rules" true; else
        sed 's/^/    /' <<< "$bad"
        check "posted texts follow the writing rules" false
    fi

    check "no pr merge call" test "$(gh_log_count pr merge)" = 0
    cmds="$(session_commands "$dir")"
    check "no force push" not grep -qE -e 'git push.*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$)|[[:space:]]\+)' <<< "$cmds"
    check "no curl or api.github.com" not grep -qE -e 'curl|api\.github\.com' <<< "$cmds"
    check_isolation "$dir"
}
