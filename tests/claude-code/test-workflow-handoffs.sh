#!/usr/bin/env bash
# Test: what one workflow skill hands the next survives the handoff
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"
# Lets a session read a skill's supporting files from any working directory
SKILLS_DIR="$(cd "$SCRIPT_DIR/../../skills" && pwd)"
NS="Where the skills do not say, answer 'not stated' instead of inferring."

echo "=== Test: workflow handoffs ==="
echo ""

echo "Test 1: The spec's check from outside reaches the end..."
output=$(run_claude_fork "Read the superpowers:writing-plans and superpowers:finishing-a-development-branch skills. The spec says how you'll know the work is right. Answer using exactly this structure:
Plan section that carries the spec's check: <section name, or not stated>
Which task runs it: <which task, or not stated>
Check needs a person: <what the plan and executor do, or not stated>
Finishing runs it before the menu: <yes, no, or not stated>
$NS" "$T")
assert_contains "$output" "Plan section that carries the spec's check:.*Acceptance" "Plan has an Acceptance section" || exit 1
assert_contains "$output" "Which task runs it:.*last" "The last task runs it" || exit 1
assert_contains "$output" "Check needs a person:.*\(steps\|ready\)" "A person check is readied, steps handed over" || exit 1
assert_contains "$output" "Finishing runs it before the menu:[^a-z]*yes\b" "Finishing re-runs it" || exit 1
echo ""

echo "Test 2: Autopilot reports the acceptance check..."
output=$(run_claude_fork "Read the superpowers:autopilot skill and its executor prompt (skills/autopilot/executor-prompt.md). Answer using exactly this structure:
Executor report has an acceptance line: <yes, no, or not stated>
Summary reports the acceptance check: <yes, no, or not stated>
$NS" "$T" --add-dir "$SKILLS_DIR")
assert_contains "$output" "Executor report has an acceptance line:[^a-z]*yes\b" "Executor reports acceptance" || exit 1
assert_contains "$output" "Summary reports the acceptance check:[^a-z]*yes\b" "Summary reports acceptance" || exit 1
echo ""

echo "=== All workflow handoff tests passed ==="
