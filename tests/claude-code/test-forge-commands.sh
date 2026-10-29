#!/usr/bin/env bash
# Deterministic checks of skills/tracking-work-in-issues/forge-commands.md:
# structure, allowed placeholders, every gh line runs on the stand-in gh, and
# every flag exists in the real gh and glab help. The real gh and glab are only
# ever called with --help.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$SCRIPT_DIR/tracking-fixtures.sh"

FAILURES=0
DOC="$REPO_ROOT/skills/tracking-work-in-issues/forge-commands.md"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# The real CLIs, found before setup_fake_gh puts the stand-in first on PATH.
REAL_GH="$(command -v gh || true)"
REAL_GLAB="$(command -v glab || true)"

EXPECTED_HEADINGS='Detect
Login check
Repo facts
Search
Create
Comment
Edit body
View with comments
Assign and unassign
Close with reason
Draft PR create
Find PR by branch
Edit PR body
Mark ready
Close PR
PR state
Branch pushes'

ALLOWED='<owner>/<name>|<path>|<host>|<N>|<P>|<branch>|<base>|<title>|<terms>|<file>|<text>|<login>'

echo "=== Test: forge-commands.md ==="

# Lines of one forge CLI, in document order. Usage: cli_lines gh|glab
cli_lines() { grep -E "^$1 " "$DOC" || true; }

# The subcommand words: leading words before the first token starting with
# -, <, ' or a digit. Usage: subcmd_words <line>   (drops the CLI name)
subcmd_words() {
    local out=() tok first=1
    for tok in $1; do
        if [[ $first == 1 ]]; then first=0; continue; fi
        case "$tok" in -* | '<'* | "'"* | [0-9]*) break ;; esac
        out+=("$tok")
    done
    echo "${out[*]}"
}

echo "-- 1 file and note"
check "file exists" test -f "$DOC"
check "note says the glab commands are untested" grep -qi 'untested' "$DOC"

echo "-- 2 headings"
check "17 headings in order" test "$(grep '^## ' "$DOC" 2> /dev/null | sed 's/^## //')" = "$EXPECTED_HEADINGS"

echo "-- 3 commands per section"
while IFS= read -r h; do
    [[ "$h" == Detect || "$h" == "Branch pushes" ]] && continue
    sec=$(awk -v h="## $h" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$DOC" 2> /dev/null || true)
    check "$h has a gh line" grep -q '^gh ' <<< "$sec"
    check "$h has a glab line" grep -q '^glab ' <<< "$sec"
done <<< "$EXPECTED_HEADINGS"

echo "-- 4 placeholders"
bad=$( { grep -E '^(gh|glab|git) ' "$DOC" 2> /dev/null || true; } | sed 's|<owner>/<name>||g' \
    | grep -oE '<[^<>]*>' | grep -vxE "$ALLOWED" || true)
check "only allowed placeholders in command lines${bad:+ (found: $(tr '\n' ' ' <<< "$bad"))}" test -z "$bad" -a -f "$DOC"

echo "-- 5 gh lines run on the stand-in"
G="$TEST_ROOT/g"
mkdir -p "$G"
W=$(tracking_repo "$G/r")
tracking_env "$G"
fake_issue 7 'Add a --version flag' ''
fake_pr 14 topic main true ''
fake_pr 16 other main true ''
BODY="$G/body.txt"
printf 'A body.\n' > "$BODY"
pushd "$W" > /dev/null
git config user.name "Test User"
git config user.email "test@example.com"
git checkout -q -b feat
echo more >> README.md
git commit -q -am "Add more"
git push -q origin feat
git checkout -q main
popd > /dev/null
pushd "$W" > /dev/null
while IFS= read -r line; do
    cmd="${line//<owner>\/<name>/acme/widgets}"
    cmd="${cmd//<N>/7}"
    cmd="${cmd//<P>/14}"
    cmd="${cmd//<branch>/feat}"
    cmd="${cmd//<base>/main}"
    cmd="${cmd//<title>/Coverage check}"
    cmd="${cmd//<terms>/version}"
    cmd="${cmd//<file>/$BODY}"
    cmd="${cmd//<text>/Closing note}"
    got=0
    err=$(bash -c "$cmd" 2>&1 > /dev/null) || got=$?
    ok=1
    [[ $got == 0 ]] || ok=0
    grep -qE 'unknown command|Unknown JSON field' <<< "$err" && ok=0
    check "runs: $line" test "$ok" = 1
done < <(cli_lines gh)
popd > /dev/null

echo "-- 6 gh flags exist in the real gh"
if [[ -z "$REAL_GH" ]]; then
    echo "  [SKIP] real gh not installed"
else
    while IFS= read -r line; do
        words=$(subcmd_words "$line")
        help=$(GH_PROMPT_DISABLED=1 "$REAL_GH" $words --help 2>&1 || true)
        missing=""
        for f in $(grep -oE -- '--[a-z][a-z-]*' <<< "$line" | sort -u); do
            grep -qF -- "$f" <<< "$help" || missing="$missing $f"
        done
        check "gh flags real [$words]${missing:+ (missing:$missing)}" test -z "$missing" -a -n "$words"
    done < <(cli_lines gh)
fi

echo "-- 7 glab lines match glab help"
if [[ -z "$REAL_GLAB" ]]; then
    echo "  [SKIP] glab not installed"
else
    while IFS= read -r line; do
        words=$(subcmd_words "$line")
        got=0
        help=$("$REAL_GLAB" $words --help 2>&1) || got=$?
        missing=""
        for f in $(grep -oE -- '--[a-z][a-z-]*' <<< "$line" | sort -u); do
            grep -qF -- "$f" <<< "$help" || missing="$missing $f"
        done
        check "glab help [$words]${missing:+ (missing:$missing)}" test "$got" = 0 -a -z "$missing" -a -n "$words"
    done < <(cli_lines glab)
fi

echo
if [[ $FAILURES -eq 0 ]]; then
    echo "PASS"
else
    echo "FAIL: $FAILURES check(s) failed"
    exit 1
fi
