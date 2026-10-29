#!/usr/bin/env bash
# Test: superpowers:tracking-work-in-issues, the fast checks: the skill's
# structure, the "no forge call" guards, and its autopilot rules.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$SCRIPT_DIR/tracking-fixtures.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-200}"
FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

SKILL="$REPO_ROOT/skills/tracking-work-in-issues/SKILL.md"
START_FAILURES=0
begin_test() { START_FAILURES=$FAILURES; OUT=""; OUT2=""; }
end_test() { if [[ $FAILURES -gt $START_FAILURES ]]; then show_run_context; fi; }

frontmatter() { awk '/^---$/ { n++; next } n == 1' "$SKILL"; }
description_value() { frontmatter | grep -m1 '^description:' | sed 's/^description: //'; }
has_name() { frontmatter | grep -qx 'name: tracking-work-in-issues'; }
desc_quoted() { [[ ${#skill_desc} -ge 2 && "$skill_desc" == \"*\" ]]; }
desc_starts() { [[ "$inner" == "Use when"* ]]; }
body_ok() { [[ -f "$SKILL" ]] && [[ "$(body_words)" -le 3000 ]]; }
body_words() { awk '/^---$/ { n++; next } n >= 2' "$SKILL" | wc -w; }

echo "=== Test: tracking-work-in-issues ==="
echo ""

echo "Test 1: Structure (no Claude run)..."
skill_desc="$(description_value)"
inner="${skill_desc#\"}"
inner="${inner%\"}"
check "name is tracking-work-in-issues" has_name
check "description is double-quoted" desc_quoted
check "description starts with Use when" desc_starts
check "description contains **Issue:**" hasf "$skill_desc" '**Issue:**'
check "description is at most 1024 characters" test "${#inner}" -gt 0 -a "${#inner}" -le 1024
expected_h2=$'## The Offer\n## Opening the Issue\n## The Draft PR\n## Milestones\n## Finishing\n## Writing Rules\n## Failures'
check "the ## sections are exactly the seven, in order" test "$(grep '^## ' "$SKILL" 2> /dev/null)" = "$expected_h2"
check "body is at most 3000 words" body_ok
for s in \
    '**Issue:** <url> (opened for this work)' \
    '**Issue:** <url> (existing)' \
    '**Issue:** none' \
    '- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.' \
    '<!-- superpowers:<id> -->' \
    '**Status:**' \
    'forge-commands.md' \
    'build-<B>-'; do
    check "SKILL.md contains: $s" grep -qF -- "$s" "$SKILL"
done
for id in opened plan-ready draft-pr 'part-<N>-done' 'waiting-<YYYYMMDDHHMM>' pr-ready merged merged-locally paused dropped; do
    check "SKILL.md names marker id: $id" grep -qF -- "$id" "$SKILL"
done
check "forge-commands.md exists" test -f "$REPO_ROOT/skills/tracking-work-in-issues/forge-commands.md"
check "plugin.json lists the skill" jq -e '.capabilities.skills | any(. == {"id":"tracking-work-in-issues","path":"skills/tracking-work-in-issues/SKILL.md"})' "$REPO_ROOT/.muse-plugin/plugin.json"
echo ""

echo "Test 2: **Issue:** none means no forge call..."
begin_test
root="$TEST_ROOT/t2"
work="$(tracking_repo "$root")"
tracking_env "$root"
version_flag_docs "$work" '**Issue:** none'
wt="$(work_branch "$work" main worktree)"
run_moment "$wt" "$T" "$C_EXEC Task 1 has just completed: its tests passed and it is committed. $(moment 'do what comes after Task 1' 'The Draft PR'), then stop before Task 2."
check "no gh call" test "$(gh_log_total)" = 0
check "version-flag was not pushed" test -z "$(bare_ref "$root" version-flag)"
end_test
echo ""

echo "Test 3: A non-forge remote means no forge call..."
begin_test
root="$TEST_ROOT/t3"
work="$(tracking_repo "$root" local)"
tracking_env "$root"
run_moment "$work" "$T" 'We have agreed on a small change and I approve it: make hello.sh accept a --name option. Track this in an issue. Do not build anything yet: stop once the issue is taken care of.'
check "no gh call" test "$(gh_log_total)" = 0
check "the output mentions github or gitlab" has_i "$OUT" 'github\|gitlab'
end_test
echo ""

echo "Test 4: No offer for a quick task..."
begin_test
root="$TEST_ROOT/t4"
work="$(tracking_repo "$root")"
tracking_env "$root"
run_moment "$work" "$T" 'Fix the typo "teh" in README.md; it should be "the".'
check "no gh call" test "$(gh_log_total)" = 0
check "no offer to open an issue" not hasf "$OUT" 'Open a new issue'
end_test
echo ""

echo "Test 5: Autopilot rules (comprehension)..."
begin_test
unset FAKE_GH_LOG
OUT="$(run_claude_fork "Read the superpowers:tracking-work-in-issues skill. Under autopilot, answer using exactly this structure:
Who makes forge calls: <who>
Executors call gh: <yes or no>
Issue opens when: <when>
Draft PR for a one-part plan: <yes or no>
Draft PR opened after: <when>
Public repo: show the text before posting: <yes or no>
Several PRs, an earlier build's PR says: <text>
Where the skill does not say, answer 'not stated' instead of inferring." "$T")"
check "Who makes forge calls: the main session" has_i "$OUT" 'Who makes forge calls:.*main session'
check "Executors call gh: no" has_ei "$OUT" 'Executors call gh:[^a-z]*no\b'
check "Issue opens when: spec ... commit" has_i "$OUT" 'Issue opens when:.*spec.*commit'
check "Draft PR for a one-part plan: no" has_ei "$OUT" 'Draft PR for a one-part plan:[^a-z]*no\b'
check "Draft PR opened after: part 1" has_i "$OUT" 'Draft PR opened after:.*part 1'
check "Public repo: show the text before posting: no" has_ei "$OUT" 'Public repo: show the text before posting:[^a-z]*no\b'
check "an earlier build's PR says: Part of #" has_i "$OUT" "earlier build's PR says:.*Part of #"
end_test
echo ""

if [[ $FAILURES -eq 0 ]]; then
    echo PASS
else
    echo "FAIL ($FAILURES)"
    exit 1
fi
