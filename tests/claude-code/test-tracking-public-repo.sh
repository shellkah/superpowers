#!/usr/bin/env bash
# Test: in a public repo, superpowers:tracking-work-in-issues shows the exact
# issue title and body before posting, and posts what it showed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$SCRIPT_DIR/tracking-fixtures.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-240}"
FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# Collapse every whitespace run to one space and trim the ends.
collapse() { tr -s '[:space:]' ' ' <<< "$1" | sed -E 's/^ //; s/ $//'; }
body_without_marker() { grep -vxF "$OPENED_MARKER" <<< "$1"; }
contains_verbatim() { [[ -n "$2" ]] && hasf "$1" "$2"; }
contains_collapsed() { [[ -n "$2" && "$(collapse "$1")" == *"$(collapse "$2")"* ]]; }

echo "=== Test: tracking in a public repo ==="
echo ""

root="$TEST_ROOT/pub"
work="$(tracking_repo "$root")"
tracking_env "$root"
fake_repo_facts PUBLIC true main
OUT=""
OUT2=""

echo "Turn 1: the text is shown first, nothing is posted..."
run_moment "$work" "$T" 'We have agreed on a small change and I approve it: make hello.sh accept a --name option. Track this in a new issue. Do not build anything yet: stop once the issue step is done.'
check "no issue created yet" test "$(gh_log_count issue create)" = 0
check "the output mentions public" has_i "$OUT" 'public'
check "the output shows a Status line" has_i "$OUT" 'Status:'
check_isolation "$work"
echo ""

echo "Turn 2: after the go-ahead, the shown text is posted..."
continue_moment "$work" "$T" 'Looks good, post it. Then stop.'
title="$(gh_log_arg issue create '--title|-t')"
body="$(gh_log_body issue create)"
check "one issue created" test "$(gh_log_count issue create)" = 1
check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
check "the logged title appears verbatim in the text shown before posting" contains_verbatim "$OUT" "$title"
check "the logged body is a substring of the text shown before posting" contains_collapsed "$OUT" "$(body_without_marker "$body")"
check "the body's first line is the Building status" test "$(first_line "$body")" = '**Status:** Building'
check "the body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
check_isolation "$work"
common_checks "$work"
echo ""

if [[ $FAILURES -gt 0 ]]; then
    show_run_context
    echo "  --- logged title ---"
    echo "    $title"
    echo "  --- logged body ---"
    sed 's/^/    /' <<< "$body"
    echo "FAIL ($FAILURES)"
    exit 1
fi
echo PASS
