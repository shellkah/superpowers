#!/usr/bin/env bash
# Test: brainstorming hands over with "Where to focus" and defers to autopilot
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: brainstorming focus and autopilot hooks ==="
echo ""

echo "Test 1: Where to focus list..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. When handing over the written design for review, what list goes with it, and at most how many items does it have? Answer using exactly this structure:
List: <name>
Max items: <number>" "$T")
assert_contains "$output" "List:.*Where to focus" "Hand-over carries a Where to focus list" || exit 1
assert_contains "$output" "Max items:[^0-9]*5\([^0-9]\|$\)" "At most five items" || exit 1
echo ""

echo "Test 2: Autopilot takes over fully automated runs..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. If your human partner asks for a fully automated run, which skill drives the work? Answer using exactly this structure:
Skill: <name>" "$T")
assert_contains "$output" "Skill:.*autopilot" "Fully automated runs go to autopilot" || exit 1
echo ""

echo "Test 3: Approval and playback under autopilot vs normal mode..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Under autopilot, does the request for a fully automated run count as approval of the written design, and only after what? Are playback chunks used under autopilot? In normal mode? Answer using exactly this structure:
Counts as approval: <yes or no>
Only after: <condition>
Playback under autopilot: <yes or no>
Playback in normal mode: <yes or no>" "$T")
assert_contains "$output" "Counts as approval:[^a-z]*yes\b" "Autopilot request approves the design" || exit 1
assert_contains "$output" "Only after:.*\(builder\|theirs\)" "Only after the builder check's questions" || exit 1
assert_contains "$output" "Playback under autopilot:[^a-z]*no\b" "No playback under autopilot" || exit 1
assert_contains "$output" "Playback in normal mode:[^a-z]*yes\b" "Playback stays in normal mode" || exit 1
echo ""

echo "=== All brainstorming focus tests passed ==="
