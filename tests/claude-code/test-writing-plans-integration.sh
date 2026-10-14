#!/usr/bin/env bash
# Integration: writing-plans produces handover files, splits a 3-subsystem spec,
# and keeps a seamless 10-task spec as one plan
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Scenario 1: small spec, one plan, handover instead of a question ==="
P1=$(new_repo)
echo "  Repo: $P1"
cat > "$P1/docs/superpowers/specs/2026-01-01-wordcount-design.md" <<'EOF'
# wordcount

A bash script `wc.sh FILE` that prints the number of words in FILE, and
exits 1 with "usage: wc.sh FILE" on stderr when FILE is missing or
unreadable. A `test.sh` script checks both behaviors and exits non-zero
on failure. No other features.
EOF
output=$(cd "$P1" && run_claude_fork "Use superpowers:writing-plans to write the implementation plan for docs/superpowers/specs/2026-01-01-wordcount-design.md. The spec is approved." 900 --permission-mode bypassPermissions) \
    || { echo "  [FAIL] claude run failed or timed out"; echo "$output"; exit 1; }
[ "$(ls "$P1"/docs/superpowers/plans/*.handover.md 2>/dev/null | wc -l)" -eq 1 ] \
    && echo "  [PASS] One handover file" || { echo "  [FAIL] Expected one .handover.md"; echo "$output"; exit 1; }
grep -q "superpowers:\(subagent-driven-development\|executing-plans\)" "$P1"/docs/superpowers/plans/*.handover.md \
    && echo "  [PASS] Handover names an execution skill" || { echo "  [FAIL] Handover names no skill"; exit 1; }
[ "$(ls "$P1"/docs/superpowers/plans/*-index.md 2>/dev/null | wc -l)" -eq 0 ] \
    && echo "  [PASS] No split for a small spec" || { echo "  [FAIL] Small spec was split"; exit 1; }
assert_contains "$output" "Where to focus" "Closing message has Where to focus" || exit 1
cleanup_test_project "$P1"

echo ""
echo "=== Scenario 2: three-subsystem spec is split, one writer per part ==="
P2=$(new_repo)
echo "  Repo: $P2"
cat > "$P2/docs/superpowers/specs/2026-01-01-notes-design.md" <<'EOF'
# notes

A Python 3.11 command-line notes tool, `notes`, built from three
subsystems. Each one must work and be tested on its own before the next
is built on it.

1. Storage: notes are records {id, title, body, tags, created, updated}
   kept in one JSON file with a schema version field. Add, get, update,
   delete, and list with tag filtering. Writes are atomic (temp file then
   rename). A file with an unknown schema version is refused with a clear
   error.
2. Search: a tokenizer (lowercase, strip punctuation, drop stop words),
   an inverted index persisted next to the JSON file and rebuilt when it
   is missing or stale, and ranked queries (term frequency, title matches
   weigh double) with `notes search QUERY`.
3. Export: `notes export --format md|html DEST` writes one file per note.
   HTML output escapes all note content. Exported file names are slugs of
   the titles, de-duplicated with -2, -3 suffixes.

The CLI uses argparse with subcommands add, show, edit, rm, ls, search,
export. Tests use pytest.
EOF
output=$(cd "$P2" && run_claude_fork "Use superpowers:writing-plans to write the implementation plan for docs/superpowers/specs/2026-01-01-notes-design.md. The spec is approved." 2400 --permission-mode bypassPermissions) \
    || { echo "  [FAIL] claude run failed or timed out"; echo "$output"; exit 1; }
plans="$P2/docs/superpowers/plans"
[ "$(ls "$plans"/*-index.md 2>/dev/null | wc -l)" -eq 1 ] \
    && echo "  [PASS] Index written" || { echo "  [FAIL] No index"; echo "$output"; exit 1; }
parts=$(ls "$plans"/*-part-*.md 2>/dev/null | grep -vc '\.handover\.md$' || true)
[ "$parts" -ge 2 ] && echo "  [PASS] $parts part files" || { echo "  [FAIL] Expected >=2 part files, got $parts"; exit 1; }
sections=$(grep -c '^## Part [0-9]' "$plans"/*.handover.md || true)
[ "$sections" -eq "$parts" ] && echo "  [PASS] One handover section per part" || { echo "  [FAIL] $sections handover sections for $parts parts"; exit 1; }
# Each part's prompt carries "Work on branch <branch from the index>.", the
# branch maybe in backticks; every part must name the same branch.
branches=$(grep -ho 'Work on branch [^[:space:]]*' "$plans"/*.handover.md | sed 's/^Work on branch //; s/`//g; s/[.,;:]*$//' || true)
branch_lines=$(printf '%s\n' "$branches" | grep -c . || true)
distinct=$(printf '%s\n' "$branches" | grep . | sort -u || true)
[ "$branch_lines" -eq "$parts" ] && [ "$(printf '%s\n' "$distinct" | grep -c . || true)" -eq 1 ] \
    && echo "  [PASS] All parts on one branch: $distinct" \
    || { echo "  [FAIL] Expected $parts 'Work on branch' lines naming one branch, got $branch_lines:"; printf '%s\n' "$branches" | sed 's/^/    /'; exit 1; }
transcript=$(latest_transcript "$P2")
[ -n "$transcript" ] || { echo "  [FAIL] No session transcript found"; exit 1; }
# Count tool_use blocks only: prompt_snapshot records in the transcript also
# list the tool definitions, and their "name":"Agent" is not a dispatch.
dispatches=$(grep -o '"type":"tool_use","id":"[^"]*","name":"\(Agent\|Task\)"' "$transcript" | wc -l || true)
[ "$dispatches" -ge "$parts" ] && echo "  [PASS] $dispatches subagent dispatches" || { echo "  [FAIL] $dispatches dispatches for $parts parts (transcript: $transcript)"; exit 1; }
cleanup_test_project "$P2"

echo ""
echo "=== Scenario 3: ten tightly related tasks, no natural seam, one plan ==="
P3=$(new_repo)
echo "  Repo: $P3"
cat > "$P3/docs/superpowers/specs/2026-01-01-calc-design.md" <<'EOF'
# calc

A Python 3.11 calculator module, `calc.py`, with one public function
`evaluate(expr: str, env: dict[str, float] | None = None) -> float` and a
REPL (`python calc.py`). Every feature below goes through one shared
tokenizer and one shared Pratt parser, so none of it is useful on its own
before the parser handles all of it. Build it as one unit.

1. Numbers: integers, decimals, and scientific notation (`1e-3`).
2. `+ - * /` with the usual precedence and left associativity.
3. Unary minus.
4. Parentheses.
5. `^` exponent: right associative, binding tighter than unary minus
   (`-2^2` is -4).
6. Variables looked up in `env`; unknown names raise `CalcError`.
7. Built-in functions `sqrt`, `sin`, `cos`, `log`, with arity checks.
8. `CalcError` carries the 1-based column of the offending token for every
   malformed input.
9. Division by zero raises `CalcError`, never `ZeroDivisionError`.
10. The REPL supports assignment (`x = 2 * 3`), prints each result, prints
    errors as `error at column N: message`, and exits cleanly on EOF.

Tests use pytest.
EOF
output=$(cd "$P3" && run_claude_fork "Use superpowers:writing-plans to write the implementation plan for docs/superpowers/specs/2026-01-01-calc-design.md. The spec is approved." 1800 --permission-mode bypassPermissions) \
    || { echo "  [FAIL] claude run failed or timed out"; echo "$output"; exit 1; }
plans="$P3/docs/superpowers/plans"
[ "$(ls "$plans"/*-index.md 2>/dev/null | wc -l)" -eq 0 ] \
    && echo "  [PASS] No index for a seamless spec" || { echo "  [FAIL] Seamless spec got an index"; echo "$output"; exit 1; }
[ "$(ls "$plans"/*-part-*.md 2>/dev/null | wc -l)" -eq 0 ] \
    && echo "  [PASS] No part files" || { echo "  [FAIL] Seamless spec got part files"; echo "$output"; exit 1; }
plan_files=$(ls "$plans"/*.md 2>/dev/null | grep -vc '\.handover\.md$' || true)
[ "$plan_files" -eq 1 ] && echo "  [PASS] One plan file" || { echo "  [FAIL] Expected one plan file, got $plan_files"; echo "$output"; exit 1; }
cleanup_test_project "$P3"

echo ""
echo "=== writing-plans integration passed ==="
