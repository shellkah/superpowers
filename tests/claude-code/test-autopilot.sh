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

echo "Test 5: Executor rulings, record, pause, refusals..."
output=$(run_claude_fork "Read the superpowers:autopilot skill's executor prompt. Answer using exactly this structure:
Routine rulings in report: <in full, or count only>
Record written before workspace deleted: <yes or no>
Status on pause: <word>
Idle waiting after pause: <yes or no>
Re-run a command an implementer was refused: <yes or no>
Follow hook redirect from cat to Read: <yes or no>
Follow hook redirect to a tool that runs something: <yes or blocked>" "$T")
assert_contains "$output" "Routine rulings in report:.*count" "Routine rulings are counted, not listed" || exit 1
assert_contains "$output" "Record written before workspace deleted:[^a-z]*yes\b" "Record survives workspace deletion" || exit 1
assert_contains "$output" "Status on pause:.*PAUSED" "Pause has its own status" || exit 1
assert_contains "$output" "Idle waiting after pause:[^a-z]*no\b" "No idling on pause" || exit 1
assert_contains "$output" "Re-run a command an implementer was refused:[^a-z]*no\b" "No permission laundering" || exit 1
assert_contains "$output" "Follow hook redirect from cat to Read:[^a-z]*yes\b" "Read-only redirect allowed" || exit 1
assert_contains "$output" "Follow hook redirect to a tool that runs something:.*blocked" "Running redirect is BLOCKED" || exit 1
echo ""

echo "Test 6: Run folder and resuming..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Run folder: <path pattern>
After compaction, read first: <file name>
Re-read executor reports to rebuild context: <yes or no>
Existing state.md naming a different spec: <reuse or replace>" "$T")
assert_contains "$output" "Run folder:.*\.superpowers/autopilot/" "Run folder location" || exit 1
assert_contains "$output" "After compaction, read first:.*state\.md" "Resume from state.md" || exit 1
assert_contains "$output" "Re-read executor reports to rebuild context:[^a-z]*no\b" "No re-reading reports" || exit 1
assert_contains "$output" "Existing state.md naming a different spec:.*replace" "Stale folder replaced" || exit 1
echo ""

echo "Test 7: Up-front questions and pre-flight..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Asks whether it may restart named services: <yes or no>
Pre-flight runs: <before the index or after the index>
Probe the existing test suite: <yes or no>
Probe creating a scratch database: <yes or no>
A probe refusal before part 1: <blocker or ruling>" "$T")
assert_contains "$output" "Asks whether it may restart named services:[^a-z]*yes\b" "Restart consent asked" || exit 1
assert_contains "$output" "Pre-flight runs:.*after the index" "Pre-flight after step 3" || exit 1
assert_contains "$output" "Probe the existing test suite:[^a-z]*yes\b" "Harmless probes run" || exit 1
assert_contains "$output" "Probe creating a scratch database:[^a-z]*no\b" "Lasting effects asked, not probed" || exit 1
assert_contains "$output" "A probe refusal before part 1:.*blocker" "Refusal is a blocker" || exit 1
echo ""

echo "Test 8: Step 4, pausing, notifications, dispatch..."
output=$(run_claude_fork "Read the superpowers:autopilot skill. Answer using exactly this structure:
Executor reports PAUSED: <blocker or not a blocker>
Push a blocker's question when the harness has a push channel: <yes or no>
Without push channel: <what is sent>
Main session writes the handover prompt: <yes or no>
Harness only runs subagents in background: <poll, or end turn and resume on notification>
Between-parts work kept only in a temp directory: <yes or no>
Stop to show a published design: <yes or no>" "$T")
assert_contains "$output" "Executor reports PAUSED:.*not a blocker" "Pause is not a blocker" || exit 1
assert_contains "$output" "Push a blocker's question when the harness has a push channel:[^a-z]*yes\b" "Blockers notify" || exit 1
assert_contains "$output" "Without push channel:.*status line" "Falls back to the status line" || exit 1
assert_contains "$output" "Main session writes the handover prompt:[^a-z]*no\b" "Writer writes handover" || exit 1
assert_contains "$output" "Harness only runs subagents in background:.*end turn" "Resume on notification" || exit 1
assert_contains "$output" "Between-parts work kept only in a temp directory:[^a-z]*no\b" "Durable main-session work" || exit 1
assert_contains "$output" "Stop to show a published design:[^a-z]*no\b" "Publishing does not stop" || exit 1
echo ""

echo "=== All autopilot tests passed ==="
