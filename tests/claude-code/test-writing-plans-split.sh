#!/usr/bin/env bash
# Test: writing-plans splits big plans at natural seams, with one writer per part
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: writing-plans splitting ==="
echo ""

echo "Test 1: Related tasks stay together; 8 is not a cap..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. A spec needs ten tasks that all build on each other's internals, with no natural seam. How many plan parts should there be, is 8 tasks a hard cap, and may a plan end with a 2-task part that belongs with its neighbor? Answer using exactly this structure:
Parts: <number>
Hard cap at 8: <yes or no>
Stub part allowed: <yes or no>" "$T")
assert_contains "$output" "Parts:[^0-9]*1\([^0-9]\|$\)" "Ten related tasks stay in one part" || exit 1
assert_contains "$output" "Hard cap at 8:[^a-z]*no\b" "8 is a guide, not a cap" || exit 1
assert_contains "$output" "Stub part allowed:[^a-z]*no\b" "No stub parts" || exit 1
echo ""

echo "Test 2: Index first, one writer subagent per part, pinned interfaces..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. When a plan is split, what file does the main session write before any part, who writes each part, and may a part writer change the cross-part interfaces the index pins? Answer using exactly this structure:
First file: <path pattern>
Part author: <who>
Writer may change index interfaces: <yes or no>" "$T")
assert_contains "$output" "First file:.*-index\.md" "Index is written first" || exit 1
assert_contains "$output" "Part author:.*subagent" "A subagent writes each part" || exit 1
assert_contains "$output" "Writer may change index interfaces:[^a-z]*no\b" "Writers cannot change pinned interfaces" || exit 1
echo ""

echo "Test 3: When parts get written..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. Outside autopilot, are all parts of a split plan written before any part executes? Under autopilot? Answer using exactly this structure:
All parts up front outside autopilot: <yes or no>
All parts up front under autopilot: <yes or no>" "$T")
assert_contains "$output" "All parts up front outside autopilot:[^a-z]*yes\b" "Normal mode writes every part up front" || exit 1
assert_contains "$output" "All parts up front under autopilot:[^a-z]*no\b" "Autopilot writes parts one at a time" || exit 1
echo ""

echo "=== All writing-plans split tests passed ==="
