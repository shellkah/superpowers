#!/usr/bin/env bash
# Test: autopilot triggers on "fully automated" and follows its flow and limits
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

T="${CLAUDE_PROMPT_TIMEOUT:-180}"

echo "=== Test: autopilot skill ==="
echo ""

echo "Test 1: Trigger..."
output=$(run_claude_fork "Do not start any work. Which superpowers skill applies first when a user says: 'Build me a URL shortener, fully automated'? Answer using exactly this structure:
Skill: <name>" "$T")
assert_contains "$output" "Skill:.*autopilot" "Fully automated triggers autopilot" || exit 1
echo ""

echo "Test 2: Flow..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Asks brainstorming questions: <yes or no>
Playback chunks: <yes or no>
Stops for spec review: <yes or no>
Part 2 written before part 1 executes: <yes or no>" "$T")
assert_contains "$output" "Asks brainstorming questions:[^a-z]*yes\b" "Questions still happen" || exit 1
assert_contains "$output" "Playback chunks:[^a-z]*no\b" "No playback chunks" || exit 1
assert_contains "$output" "Stops for spec review:[^a-z]*no\b" "No spec review stop" || exit 1
assert_contains "$output" "Part 2 written before part 1 executes:[^a-z]*no\b" "Write-then-execute per part" || exit 1
echo ""

echo "Test 3: Ending..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. At the end of a run, when the repo has a remote and a logged-in CLI for its host, answer using exactly this structure:
Merges: <yes or no>
Opens PR: <yes or no>
Draft PR: <yes or no>
Force push: <yes or no>
No remote is a blocker: <yes or no>" "$T")
assert_contains "$output" "Merges:[^a-z]*no\b" "Never merges" || exit 1
assert_contains "$output" "Opens PR:[^a-z]*yes\b" "Opens a PR" || exit 1
assert_contains "$output" "Draft PR:[^a-z]*no\b" "Regular PR, not a draft" || exit 1
assert_contains "$output" "Force push:[^a-z]*no\b" "Never force-pushes" || exit 1
assert_contains "$output" "No remote is a blocker:[^a-z]*no\b" "No remote is not a blocker" || exit 1
echo ""

echo "Test 4: Blockers and executor limits..."
output=$(run_claude_fork "Read the superpowers:autopilot skill and its executor prompt. An executor subagent finds the deploy step needs credentials it does not have. Separately: may an executor subagent push? Answer using exactly this structure:
Missing credentials: <stop and ask, or rule and continue>
Executor may push: <yes or no>" "$T")
assert_contains "$output" "Missing credentials:.*stop and ask" "Missing credentials is a blocker" || exit 1
assert_contains "$output" "Executor may push:[^a-z]*no\b" "Executors never push" || exit 1
echo ""

echo "=== All autopilot tests passed ==="
