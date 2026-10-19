#!/usr/bin/env bash
# Test: writing-plans ends with handover prompts instead of an execution question
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: writing-plans handover prompts ==="
echo ""

echo "Test 1: No execution question; handover file..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. After the plan is written and self-reviewed, does the agent ask its human partner which execution approach to use, and where are the handover prompts saved? Answer using exactly this structure:
Asks which approach: <yes or no>
Handover file: <path pattern>" "$T")
assert_contains "$output" "Asks which approach:[^a-z]*no\b" "Does not ask for an execution approach" || exit 1
assert_contains "$output" "Handover file:.*\.handover\.md" "Handover prompts saved to .handover.md" || exit 1
echo ""

echo "Test 2: Non-last parts keep the branch open..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. In the handover prompt for a part that is not the last part, should the executor run superpowers:finishing-a-development-branch when its final review passes? Answer using exactly this structure:
Finish branch on a non-last part: <yes or no>" "$T")
assert_contains "$output" "Finish branch on a non-last part:[^a-z]*no\b" "Non-last parts keep the branch open" || exit 1
echo ""

echo "Test 3: Closing message contents..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. Outside autopilot, list what the message that ends the planning session must contain, one item per line, each line starting with '- '." "$T")
assert_contains "$output" "Where to focus" "Closing message has Where to focus" || exit 1
assert_contains "$output" "handover prompt" "Closing message has a handover prompt" || exit 1
echo ""

echo "Test 4: executing-plans is named by the handover prompt..."
output=$(run_claude_fork "Read the superpowers:executing-plans skill's When to Use section. Besides having no subagent tool, what names this skill as the one to use? Answer using exactly this structure:
Named by: <what>" "$T")
assert_contains "$output" "Named by:.*handover" "executing-plans is named by the handover prompt" || exit 1
echo ""

echo "Test 5: Handover prompts as Markdown..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill's Execution Handoff. Answer using exactly this structure:
Handover prompt in the handover file wrapped in a code block: <yes or no>
Paths in the prompt formatted as: <inline code or plain>
Where the skill does not say, answer 'not stated' instead of inferring." "$T")
assert_contains "$output" "wrapped in a code block:[^a-z]*no\b" "Handover prompt is Markdown, not a code block" || exit 1
assert_contains "$output" "Paths in the prompt formatted as:.*inline code" "Paths in inline code" || exit 1
echo ""

echo "Test 6: Conditional handover bullets..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill's Execution Handoff. For part 2 of a 3-part split plan, which labelled bullets does its handover prompt carry? Answer using exactly this structure:
Workspace bullet: <yes or no>
Previous part bullet: <yes or no>
Not the last part bullet: <yes or no>
Where the skill does not say, answer 'not stated' instead of inferring." "$T")
assert_contains "$output" "Workspace bullet:[^a-z]*no\b" "Part 2 has no Workspace bullet" || exit 1
assert_contains "$output" "Previous part bullet:[^a-z]*yes\b" "Part 2 has a Previous part bullet" || exit 1
assert_contains "$output" "Not the last part bullet:[^a-z]*yes\b" "Part 2 is not the last part" || exit 1
echo ""

echo "=== All writing-plans handover tests passed ==="
