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
assert_contains "$output" "All parts up front outside autopilot:[^a-z]*no\b" "Normal mode writes parts just in time" || exit 1
assert_contains "$output" "All parts up front under autopilot:[^a-z]*no\b" "Autopilot writes parts one at a time" || exit 1
echo ""

echo "Test 3b: Later parts in normal mode..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill. Outside autopilot, a plan is split into 3 parts. Which parts does the planning session write, when is part 2 written, and what does part 2's handover prompt tell the fresh session to do first? Answer using exactly this structure:
Planning session writes: <which files>
Part 2 written: <when>
Part 2 handover first step: <what>" "$T")
assert_contains "$output" "Planning session writes:.*index.*part 1" "Planning session writes the index and part 1" || exit 1
assert_contains "$output" "Part 2 written:.*\\(after\\|once\\|start\\|handover\\|own session\\)" "Part 2 is written later, in its own session" || exit 1
assert_contains "$output" "Part 2 handover first step:.*\\([Ww]rite\\|complete\\)" "Part 2's prompt writes the part first" || exit 1
echo ""

echo "Test 4: Part writer content, length, handover..."
output=$(run_claude_fork "Read the superpowers:writing-plans part-writer prompt. Answer using exactly this structure:
Whole helper script in the plan: <yes or no>
Line budget to hit: <yes or no>
Reports length against spec share: <yes or no>
Writes handover prompt under autopilot: <yes or no>
Writes handover prompt outside autopilot: <yes or no>" "$T")
assert_contains "$output" "Whole helper script in the plan:[^a-z]*no\b" "Bodies become signatures" || exit 1
assert_contains "$output" "Line budget to hit:[^a-z]*no\b" "No line budget" || exit 1
assert_contains "$output" "Reports length against spec share:[^a-z]*yes\b" "Length line" || exit 1
assert_contains "$output" "Writes handover prompt under autopilot:[^a-z]*yes\b" "Writer writes handover under autopilot" || exit 1
assert_contains "$output" "Writes handover prompt outside autopilot:[^a-z]*no\b" "Main session writes it otherwise" || exit 1
echo ""

echo "Test 5: Cross-part check under autopilot..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill and its prompts. Answer using exactly this structure:
Cross-part check under autopilot run by: <main session or subagent>
Cross-part check outside autopilot run by: <main session or subagent>
Who updates the index from executor interfaces under autopilot: <main session or checker>
Main session reads part file under autopilot: <yes or no>" "$T")
assert_contains "$output" "Cross-part check under autopilot run by:.*subagent" "Check delegated under autopilot" || exit 1
assert_contains "$output" "Cross-part check outside autopilot run by:.*main session" "Normal mode unchanged" || exit 1
assert_contains "$output" "Who updates the index from executor interfaces under autopilot:.*checker" "Checker updates index" || exit 1
assert_contains "$output" "Main session reads part file under autopilot:[^a-z]*no\b" "Main session stays out of part files" || exit 1
echo ""

echo "=== All writing-plans split tests passed ==="
