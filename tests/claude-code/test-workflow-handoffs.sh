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

echo "Test 3: Rulings survive between parts outside autopilot..."
output=$(run_claude_fork "Read the superpowers:writing-plans skill and its part-writer prompt (skills/writing-plans/part-writer-prompt.md). Outside autopilot, part 1 of a 3-part split plan finishes, and its executor made rulings about what the spec means. Answer using exactly this structure:
Where part 1's rulings are kept for part 2: <the file, or not stated>
Part 2's writer reads them: <yes, no, or not stated>
$NS" "$T" --add-dir "$SKILLS_DIR")
assert_contains "$output" "kept for part 2:.*plan file" "Rulings kept in the part's plan file" || exit 1
assert_not_contains "$output" "kept for part 2:[^a-z]*not stated" "Where they are kept is stated" || exit 1
assert_contains "$output" "Part 2's writer reads them:[^a-z]*yes\b" "The next writer reads them" || exit 1
echo ""

echo "Test 4: The PR lists the rulings..."
output=$(run_claude_fork "Read the superpowers:finishing-a-development-branch skill. When you push and open a pull request for work executed from a plan, does the PR description list the rulings made during execution? Answer using exactly this structure:
PR lists rulings: <yes, no, or not stated>
$NS" "$T")
assert_contains "$output" "PR lists rulings:[^a-z]*yes\b" "PR lists rulings" || exit 1
echo ""

echo "Test 5: A small change has a defined path..."
output=$(run_claude_fork "Read the superpowers:brainstorming skill. Outside autopilot, you are on main in a software repo, and your human partner approved a small change in chat. Answer using exactly this structure:
Where it's built: <a new branch, main, or not stated>
Review before integrating: <yes, no, or not stated>
Ends with: <skill name, or not stated>
$NS" "$T")
assert_contains "$output" "Where it's built:.*new branch" "Small change on a new branch" || exit 1
assert_contains "$output" "Review before integrating:[^a-z]*yes\b" "Small change gets a review" || exit 1
assert_contains "$output" "Ends with:.*finishing" "Small change ends with finishing" || exit 1
echo ""

for skill in executing-plans subagent-driven-development; do
    echo "Test 6 ($skill): A part's final review covers its own work..."
    output=$(run_claude_fork "Read the superpowers:$skill skill. You are executing part 2 of a 3-part split plan; part 1's commits are already on the branch. Answer using exactly this structure:
Part 1's commits in this part's final review: <yes, no, or not stated>
Part 3's final review covers: <part 3 only, the whole branch, or not stated>
$NS" "$T")
    assert_contains "$output" "Part 1's commits in this part's final review:[^a-z]*no\b" "A part reviews its own range" || exit 1
    assert_contains "$output" "Part 3's final review covers:.*whole branch" "The last part reviews the whole branch" || exit 1
    echo ""
done

echo "=== All workflow handoff tests passed ==="
