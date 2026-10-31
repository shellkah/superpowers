#!/usr/bin/env bash
# Test: the workflow skills reach superpowers:tracking-work-in-issues. Fast
# checks over the shared scenario helpers and the skill files, then real
# headless sessions at the moments each skill hands over to the tracking skill.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$SCRIPT_DIR/tracking-fixtures.sh"

root="" work="" wt="" # set by the fixtures (fxv)
T="${CLAUDE_PROMPT_TIMEOUT:-200}"
FAILURES=0
TEST_ROOT="$(mktemp -d)"
SESSION_ROOT="$TEST_ROOT"
trap 'rm -rf "$TEST_ROOT"' EXIT
NS="Where the skills do not say, answer 'not stated' instead of inferring."

echo "=== Test: workflow skills reach the tracking skill ==="
echo ""

echo "Test 1: Shared scenario helpers (no Claude run)..."
fx_finish dev
check "fx_finish dev: PR 13's base is dev" test "$(pr_json 13 | jq -r .baseRefName)" = dev
check "fx_finish dev: #12's status names the draft" test "$(i_first 12)" = '**Status:** Building: draft PR #13'
check "fx_finish dev: version-flag is on the remote" test -n "$(bare_ref "$root" version-flag)"
check "main_unchanged holds before any push" main_unchanged
p="$(executor_prompt "$work" "$wt" "$root/run" subagent-driven-development)"
check "executor_prompt fills every placeholder" executor_prompt_ok "$p"
check "executor_prompt names the skill it is given" hasf "$p" 'use `superpowers:subagent-driven-development`'
check "executor_prompt defaults to executing-plans" hasf "$(executor_prompt "$work" "$wt" "$root/run")" 'use `superpowers:executing-plans`'
s="$TEST_ROOT/spec"; fxv sw tracking_repo "$s"; spec_only "$sw" "$ISSUE12"
check "spec_only commits the spec with its line" test "$(git -C "$sw" show HEAD:"$SPEC_PATH" | sed -n 3p)" = "$ISSUE12"
check "spec_only pushes main" same_ref "$(bare_ref "$s" main)" "$(git -C "$sw" rev-parse main)"
d="$TEST_ROOT/transcript-dir"; mkdir -p "$d"
proj="$HOME/.claude/projects/$(cd "$d" && pwd -P | sed 's|[^a-zA-Z0-9]|-|g')"; mkdir -p "$proj"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"superpowers:finishing-a-development-branch"}}]}}' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/skills/tracking-work-in-issues/SKILL.md"}}]}}' > "$proj/fake.jsonl"
check "session_skills reads a Skill call" loaded "$d" finishing-a-development-branch
check "session_skills reads a SKILL.md read" loaded "$d" tracking-work-in-issues
check "loaded is false for a skill not loaded" not loaded "$d" brainstorming
rm -rf "$proj"
for f in test-tracking-wiring-integration.sh test-tracking-work-in-issues-integration.sh; do
    out="$(TRACKING_SCENARIOS=no_such bash "$SCRIPT_DIR/$f" 2>&1)"; rc=$?
    check "$f: an unknown scenario fails without a session" test "$rc" = 1
    check "$f: says so" hasf "$out" '[FAIL] no such scenario: no_such'
    check "$f: and ends FAIL (1 scenarios)" hasf "$out" 'FAIL (1 scenarios)'
done
rm -rf "$root"
SESSION_ROOT="$TEST_ROOT"
echo ""

echo "Test 2: Subagent prompts leave the forge alone (no Claude run)..."
for f in skills/subagent-driven-development/implementer-prompt.md skills/subagent-driven-development/task-reviewer-prompt.md \
    skills/subagent-driven-development/re-review-prompt.md skills/writing-plans/part-writer-prompt.md \
    skills/writing-plans/cross-part-check-prompt.md skills/brainstorming/builder-check-prompt.md \
    skills/autopilot/executor-prompt.md skills/requesting-code-review/code-reviewer.md; do
    check "$f exists" test -f "$REPO_ROOT/$f"
    check "$f does not send its subagent to the tracking skill" not grep -q 'tracking-work-in-issues' "$REPO_ROOT/$f"
done
echo ""

echo "Test 3: Each wired skill cites the tracking skill's sections (no Claude run)..."
TRACKING_SKILL="$REPO_ROOT/skills/tracking-work-in-issues/SKILL.md"
declare -A EXPECT=(
    [brainstorming]='The Offer|Opening the Issue'
    [writing-plans]='Milestones'
    [executing-plans]='The Draft PR|Milestones'
    [subagent-driven-development]='The Draft PR|Milestones'
    [finishing-a-development-branch]='The Draft PR|Finishing'
    [autopilot]='Opening the Issue|The Draft PR|Milestones|Finishing|Failures'
)
# Each section a file cites as "tracking-work-in-issues says (<S>[, <S>])", one per line;
# lines are joined first, since the skills are hard-wrapped.
cited_sections() {
    tr '\n' ' ' < "$1" | tr -s ' ' | grep -oE 'tracking-work-in-issues says \([^)]*\)' \
        | sed -E 's/^tracking-work-in-issues says \((.*)\)$/\1/' | sed 's/, /\n/g'
}
headings() { grep '^## ' "$TRACKING_SKILL" | sed 's/^## //'; }
for skill in $(printf '%s\n' "${!EXPECT[@]}" | sort); do
    cites="$(cited_sections "$REPO_ROOT/skills/$skill/SKILL.md")"
    check "$skill cites only the tracking skill's ## sections" test -z "$(grep -vxF -f <(headings) <<< "$cites")"
    IFS='|' read -ra want <<< "${EXPECT[$skill]}"
    for s in "${want[@]}"; do check "$skill cites ($s)" grep -xF -- "$s" <<< "$cites"; done
done
echo ""

echo "Test 4: writing-plans carries the Issue line and the handover bullet (no Claude run)..."
W="$REPO_ROOT/skills/writing-plans/SKILL.md"
check "writing-plans has the exact handover bullet" grep -qxF -- '- **Issue:** keep `<url>` current as `superpowers:tracking-work-in-issues` says.' "$W"
check "writing-plans says where the Issue line goes" grep -qF '**Issue line.**' "$W"
echo ""

echo "Test 5: A split plan and its issue (comprehension)..."
mkdir -p "$TEST_ROOT/t5"
run_moment "$TEST_ROOT/t5" "$T" "Read the superpowers:writing-plans skill. A project's spec carries this line under its title: **Issue:** https://github.com/acme/widgets/issues/12 (opened for this work). The plan is split into 2 parts. Answer using exactly this structure:
Index carries the Issue line: <yes, no, or not stated>
In a part file, the Issue line comes right after: <the line it follows, or not stated>
Part 2's handover prompt has an Issue bullet: <yes, no, or not stated>
Plan-ready milestone posted under autopilot: <yes, no, or not stated>
With **Issue:** none in the spec instead, handover prompts have an Issue bullet: <yes, no, or not stated>
$NS"
check "the index carries the line" has_ei "$OUT" 'Index carries the Issue line:[^a-z]*yes\b'
check "in a part file it follows the Part line" has_ei "$OUT" 'comes right after:.*part'
check "part 2's prompt has the bullet" has_ei "$OUT" "Part 2's handover prompt has an Issue bullet:[^a-z]*yes\b"
check "plan ready is posted under autopilot" has_ei "$OUT" 'posted under autopilot:[^a-z]*yes\b'
check "Issue: none gets no bullet" has_ei "$OUT" 'handover prompts have an Issue bullet:[^a-z]*no\b'
check_isolation "$TEST_ROOT/t5"
echo ""

echo "Test 6: Finishing's menus stay word for word (no Claude run)..."
F="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"
for line in '1. Merge back to <base-branch> locally' '2. Push and create a Pull Request' "3. Keep the branch as-is (I'll handle it later)" \
    '1. Push as new branch and create a Pull Request' "2. Keep as-is (I'll handle it later)"; do
    check "finishing's menu keeps: $line" grep -qxF -- "$line" "$F"
done
check "finishing names the draft option" grep -qF 'Mark the draft PR ready for review' "$F"
echo ""

echo "Test 7: Autopilot's pushes and the issue (comprehension)..."
mkdir -p "$TEST_ROOT/t7"
run_moment "$TEST_ROOT/t7" "$T" "Read the superpowers:autopilot skill. A run tracks a GitHub issue, and its plan is split into 2 parts. Answer using exactly this structure:
Executors push or post: <yes, no, or not stated>
Main session pushes between parts: <yes, no, or not stated>
Draft PR opened after: <when, or not stated>
A between-part push is a blocker: <yes, no, or not stated>
Opening the issue when the spec is committed is a blocker: <yes, no, or not stated>
With a draft open, step 5 creates a new PR: <yes, no, or not stated>
Summary gives the issue link: <yes, no, or not stated>
$NS"
check "executors never push or post" has_ei "$OUT" 'Executors push or post:[^a-z]*no\b'
check "the main session pushes between parts" has_ei "$OUT" 'pushes between parts:[^a-z]*yes\b'
check "the draft opens after part 1" has_ei "$OUT" 'Draft PR opened after:.*part 1'
check "a between-part push is no blocker" has_ei "$OUT" 'between-part push is a blocker:[^a-z]*no\b'
check "opening the issue is no blocker" has_ei "$OUT" 'spec is committed is a blocker:[^a-z]*no\b'
check "step 5 marks the draft ready instead" has_ei "$OUT" 'step 5 creates a new PR:[^a-z]*no\b'
check "the summary gives the issue link" has_ei "$OUT" 'Summary gives the issue link:[^a-z]*yes\b'
check_isolation "$TEST_ROOT/t7"
echo ""

echo "Test 8: The README lists the skill (no Claude run)..."
check "README lists tracking-work-in-issues" grep -qF -- '- **tracking-work-in-issues** - ' "$REPO_ROOT/README.md"
echo ""

if [[ $FAILURES -eq 0 ]]; then
    echo PASS
else
    echo "FAIL ($FAILURES)"
    exit 1
fi
