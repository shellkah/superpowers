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

echo "Test 4: Opening open, then selectable questions..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Answer using exactly this structure:
First question: <open or selectable>
Later decision questions: <open or selectable>
Batch related independent questions: <yes or no>
Picker unavailable or empty: <stall, skip, or ask in text>
Visual companion offer: <picker or plain text>
Builder check theirs questions: <picker or plain text>" "$T")
assert_contains "$output" "First question:.*open" "Opening stays open" || exit 1
assert_contains "$output" "Later decision questions:.*selectable" "Later questions selectable" || exit 1
assert_contains "$output" "Batch related independent questions:[^a-z]*yes\b" "Related questions batched" || exit 1
assert_contains "$output" "Picker unavailable or empty:.*text" "Text fallback" || exit 1
assert_contains "$output" "Visual companion offer:.*plain text" "Companion offer stays text" || exit 1
assert_contains "$output" "Builder check theirs questions:.*picker" "Theirs pile uses picker" || exit 1
echo ""

echo "Test 5: Ideas, recon, gaps..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Answer using exactly this structure:
Decision questions carry a recommended option: <yes or no>
Separate approaches round: <yes or no>
Read the project without asking: <yes or no>
Search the web without asking: <yes or no>
Share findings before they describe it: <yes or no>
Gap hunts happen: <when>" "$T")
assert_contains "$output" "Decision questions carry a recommended option:[^a-z]*yes\b" "Recommendation on each decision" || exit 1
assert_contains "$output" "Separate approaches round:[^a-z]*no\b" "No approaches round" || exit 1
assert_contains "$output" "Read the project without asking:[^a-z]*yes\b" "Project recon is free" || exit 1
assert_contains "$output" "Search the web without asking:[^a-z]*no\b" "Web still asks" || exit 1
assert_contains "$output" "Share findings before they describe it:[^a-z]*no\b" "Findings held until after the opening" || exit 1
assert_contains "$output" "Gap hunts happen:.*\(recon\|look\|read\).*\(write\|design\|description\)" "Two gap hunts" || exit 1
echo ""

echo "Test 6: Recon stays out of the opening; pickers aren't checklists..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. You read the project before your first message. Answer using exactly this structure:
First message says what you looked at: <yes or no>
Skill explicitly says a picker is not a checklist: <yes or no>" "$T")
assert_contains "$output" "First message says what you looked at:[^a-z]*no\b" "What you looked at waits for their description" || exit 1
assert_contains "$output" "Skill explicitly says a picker is not a checklist:[^a-z]*yes\b" "Picker is not a checklist" || exit 1
echo ""

echo "Test 7: Deeper, not bigger..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Answer using exactly this structure:
Extra scope a top professional would add: <add it or leave it out>
Start from: <their summary or the real material>
Tests you write yourself show it's right: <yes or no>
Written design says how you'll know it's right: <yes or no>
A small change gets the deeper pass: <none, one line, or all of it>
A quick, clear task gets the deeper pass: <yes or no>" "$T")
assert_contains "$output" "Extra scope a top professional would add:.*leave" "Deeper, not bigger" || exit 1
assert_contains "$output" "Start from:.*real" "Raw material over a summary" || exit 1
assert_contains "$output" "Tests you write yourself show it's right:[^a-z]*no\b" "The check comes from outside" || exit 1
assert_contains "$output" "Written design says how you'll know it's right:[^a-z]*yes\b" "The design names the check" || exit 1
assert_contains "$output" "A small change gets the deeper pass:.*one line" "Small change: one line" || exit 1
assert_contains "$output" "A quick, clear task gets the deeper pass:[^a-z]*no\b" "Quick task skips it" || exit 1
echo ""

echo "=== All brainstorming focus tests passed ==="
