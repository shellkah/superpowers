#!/usr/bin/env bash
# Fixtures for the issue-tracking tests: test repos, state seeding for the
# stand-in gh, and queries over its call log. Source after test-helpers.sh.

_FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create <root>/remote.git (bare) and <root>/work (a small repo on main).
# Usage: tracking_repo <root> [ssh|https|local]   # prints <root>/work
tracking_repo() {
    local root form work remote
    mkdir -p "$1"
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
    if [[ -n "$1" ]]; then sed -n "${1}p"; else tail -n 1; fi
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
    for f in "$proj"/*.jsonl; do
        [[ -f "$f" ]] || continue
        jq -r 'try (.message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command
                    | gsub("\n"; "; ")) catch empty' "$f" 2> /dev/null
    done
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
