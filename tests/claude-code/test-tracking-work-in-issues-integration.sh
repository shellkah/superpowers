#!/usr/bin/env bash
# Test: superpowers:tracking-work-in-issues, moment by moment, against the
# stand-in gh. Each scenario builds a test repo and a stand-in forge state under
# its own temp root, runs a real headless session at one moment of the workflow,
# then checks the call log, the forge state and the repos from outside.
#
# TRACKING_SCENARIOS  space-separated scenario names (default: all, in order)
# TRACKING_JOBS       scenarios run at once (default 1)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$SCRIPT_DIR/tracking-fixtures.sh"

TURN="${CLAUDE_PROMPT_TIMEOUT:-300}"
JOBS="${TRACKING_JOBS:-1}"

ALL_SCENARIOS="offer_picker offer_issues_off offer_logged_out open_project_new open_existing
open_public_existing open_no_issue open_small_change_by_request open_create_fails plan_ready
plan_ready_already_posted draft_after_task1 push_after_task2 on_default_branch part_done
waiting_on_you finish_ready finish_ready_non_default_base finish_merge_pushed
finish_merge_not_pushed finish_keep finish_discard_opened finish_discard_existing comment_fails
quick_task_named_issue executor_stays_off_forge offer_public"

BLOB=https://github.com/acme/widgets/blob/version-flag
PR13=https://github.com/acme/widgets/pull/13
NOT_CLOSING='(won.t|will not|doesn.t|does not|not).{0,40}clos'

# ---- helpers shared by the scenarios ----

OFFER_SENTENCE='If this work can track an issue, make the offer as superpowers:tracking-work-in-issues says (The Offer), as your only question.'

setup() { # [ssh|https|local]
    root="$(mktemp -d)"
    work="$(tracking_repo "$root" "${1:-ssh}")"
    tracking_env "$root"
}

i_body() { issue_json "$1" | jq -r '.body'; }
i_first() { first_line "$(i_body "$1")"; }
same_ref() { [[ -n "$1" && "$1" == "$2" ]]; }
main_unchanged() { [[ "$(bare_ref "$root" main)" == "$main_before" ]]; }
num_is() { test "$1" = "$2"; }
ge() { test "$1" -ge "$2"; }
body_ends_with_opened() { [[ "$(last_nonempty "$(i_body "$1")")" == "$OPENED_MARKER" ]]; }
issue_state_is() { [[ "$(issue_json "$1" | jq -r ".$2")" == "$3" ]]; }
pr_is_draft_false() { [[ "$(pr_json 13 | jq -r '.isDraft')" == false ]]; }
matches_ei() { grep -qiE -- "$2" <<< "$1"; }
spec_line_is() { [[ "$(first_line_after_title "$work/$SPEC_PATH")" == "$1" ]]; }
spec_committed() { git -C "$work" diff --quiet HEAD -- "$SPEC_PATH"; }
spec_has_no_issue_line() { ! grep -q '^\*\*Issue:\*\*' "$work/$SPEC_PATH"; }

# any call of <w1> <w2> naming <N> has a body containing <str>
named_body_has() { named_calls "$1" "$2" "$3" | jq -e --arg s "$4" 'select((.body // "") | contains($s))' > /dev/null; }
# some call naming <N> ends with <marker>
named_ends_with() { named_last_lines "$1" "$2" "$3" | grep -qxF -- "$4"; }
dropped_marker_posted() {
    { named_last_lines issue comment 12; named_last_lines issue close 12; } | grep -qxF '<!-- superpowers:dropped -->'
}
starts() { [[ "$1" == "$2"* ]]; }
# the call has a non-null body
named_body_not_null() { named_calls "$1" "$2" "$3" | jq -e 'select(.body != null)' > /dev/null; }

# the model's first-turn output and a title or body ready to compare
posted_title() { gh_log_arg issue create '--title|-t'; }
posted_body() { gh_log_body issue create; }

# Build the project docs, #12 opened, and the work branch.
# Usage: fx_building worktree|checkout [base]
fx_building() {
    setup
    version_flag_docs "$work" "$ISSUE12"
    opened_issue_12
    wt="$(work_branch "$work" "${2:-main}" "$1")"
    main_before="$(bare_ref "$root" main)"
}

fx_finish() { # checkout, pushed, draft PR open, Task 2 committed (unpushed); arg: base
    local base="${1:-main}"
    setup
    version_flag_docs "$work" "$ISSUE12"
    opened_issue_12
    if [[ "$base" != main ]]; then dev_base "$work"; fi
    wt="$(work_branch "$work" "$base" checkout)"
    push_work "$wt"
    draft_pr_13 "$base"
    task2_commit "$wt"
    main_before="$(bare_ref "$root" main)"
}

# ---- scenarios ----

scenario_offer_picker() {
    setup https
    fake_issue 3 'Add a --version flag to hello.sh' '' alice
    fake_issue 4 'Print version information' ''
    fake_issue 6 'Rename the greeting' ''
    run_moment "$work" "$TURN" "$(c_brain ' See issue #4.') $OFFER_SENTENCE $HEADLESS"
    check "no forge write" num_is "$(gh_write_count)" 0
    check "an issue list call carries a search" gh_log_has_flag issue list '--search|-S'
    check "offers: Open a new issue" has_i "$OUT" 'Open a new issue'
    check "offers: No issue" has_i "$OUT" 'No issue'
    check "lists #3" has_i "$OUT" '#3'
    check "names alice" has_i "$OUT" 'alice'
    check "Use #4 comes before Open a new issue" assert_order "$OUT" 'Use #4' 'Open a new issue'
    check "does not say public" not has_i "$OUT" 'public'
    common_checks "$work"
}

scenario_offer_issues_off() {
    setup
    fake_repo_facts PRIVATE false main
    run_moment "$work" "$TURN" "$(c_brain) $OFFER_SENTENCE $HEADLESS"
    check "no forge write" num_is "$(gh_write_count)" 0
    check "no issue list call" num_is "$(gh_log_count issue list)" 0
    check "no offer to open an issue" not has_i "$OUT" 'Open a new issue'
    check "says issues are off" has_i "$OUT" 'issues'
    common_checks "$work"
}

scenario_offer_logged_out() {
    setup
    fake_logout
    run_moment "$work" "$TURN" "$(c_brain) $OFFER_SENTENCE $HEADLESS"
    check "no forge write" num_is "$(gh_write_count)" 0
    check "names gh auth login" has_i "$OUT" 'gh auth login'
    check "still offers: Open a new issue" has_i "$OUT" 'Open a new issue'
    common_checks "$work"
}

OPEN_NEW_PROMPT="$C_APPROVED"' When offered issue tracking earlier, they chose "Open a new issue". Open it now as superpowers:tracking-work-in-issues says (Opening the Issue), then stop: do not start planning.'

scenario_open_project_new() {
    setup
    version_flag_docs "$work"
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$OPEN_NEW_PROMPT"
    local body
    body="$(posted_body)"
    printf '%s\n' "$body" > "$root/posted-body.txt"
    check "one issue created" num_is "$(gh_log_count issue create)" 1
    check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
    check "body starts with the Planning status" test "$(first_line "$body")" = '**Status:** Planning'
    check "body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "body names the spec path" hasf "$body" "$SPEC_PATH"
    check "body copies no spec line" test -z "$(copied_lines "$root/posted-body.txt" "$work/$SPEC_PATH")"
    check "spec carries the issue line" spec_line_is '**Issue:** https://github.com/acme/widgets/issues/1 (opened for this work)'
    check "spec change is committed" spec_committed
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

fx_existing_4() {
    setup
    version_flag_docs "$work"
    existing_issue_4
    issue_json 4 | jq -r '.title, .body' > "$root/saved-4.txt"
    main_before="$(bare_ref "$root" main)"
}
OPEN_EXISTING_PROMPT="$C_APPROVED"' When offered issue tracking earlier, they chose "Use #4: Print version information". Take it over now as superpowers:tracking-work-in-issues says (Opening the Issue), then stop: do not start planning.'

issue_4_unchanged() { issue_json 4 | jq -r '.title, .body' | cmp -s - "$root/saved-4.txt"; }

scenario_open_existing() {
    fx_existing_4
    run_moment "$work" "$TURN" "$OPEN_EXISTING_PROMPT"
    local body
    body="$(named_body issue comment 4)"
    check "no issue created" num_is "$(gh_log_count issue create)" 0
    check "one comment on #4" num_is "$(named_count issue comment 4)" 1
    check "the comment ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "the comment has no Status line" not hasf "$body" '**Status:**'
    check "no edit carries a body or title" not gh_log_has_flag issue edit '--body|-b|--body-file|-F|--title|-t'
    check "#4 title and body are untouched" issue_4_unchanged
    check "#4 is assigned to shellkah" jq -e '.assignees | any(.login == "shellkah")' "$FAKE_GH_STATE/issues/4.json"
    check "spec carries the existing-issue line" spec_line_is '**Issue:** https://github.com/acme/widgets/issues/4 (existing)'
    check "spec change is committed" spec_committed
    common_checks "$work"
}

scenario_open_public_existing() {
    fx_existing_4
    fake_repo_facts PUBLIC true main
    run_moment "$work" "$TURN" "$OPEN_EXISTING_PROMPT"
    check "no comment posted yet" num_is "$(gh_log_count issue comment)" 0
    check "says public" has_i "$OUT" 'public'
    check "names #4" has_i "$OUT" '#4'
    common_checks "$work"
}

scenario_open_no_issue() {
    setup
    version_flag_docs "$work"
    run_moment "$work" "$TURN" "$C_APPROVED"' When offered issue tracking earlier, they chose "No issue". Record that as superpowers:tracking-work-in-issues says (Opening the Issue), then stop: do not start planning.'
    check "no forge write" num_is "$(gh_write_count)" 0
    check "spec carries Issue: none" spec_line_is '**Issue:** none'
    check "spec change is committed" spec_committed
    common_checks "$work"
}

scenario_open_small_change_by_request() {
    setup
    local head_before title body
    head_before="$(git -C "$work" rev-parse HEAD)"
    run_moment "$work" "$TURN" 'We have agreed on a small change and I approve it: make hello.sh print the value of $HOME after the greeting. Track this in an issue. Do not build anything yet: stop once the issue is taken care of.'
    title="$(posted_title)"
    body="$(posted_body)"
    check "no offer to open an issue" not has_i "$OUT" 'Open a new issue'
    check "one issue created" num_is "$(gh_log_count issue create)" 1
    check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
    check "body starts with the Building status" test "$(first_line "$body")" = '**Status:** Building'
    check "body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "the title does not carry the shell's HOME" not hasf "$title" "$HOME"
    check "working tree is clean" test -z "$(git -C "$work" status --porcelain)"
    check "HEAD is unchanged" test "$(git -C "$work" rev-parse HEAD)" = "$head_before"
    common_checks "$work"
}

scenario_open_create_fails() {
    setup
    version_flag_docs "$work"
    export FAKE_GH_FAIL='issue create'
    run_moment "$work" "$TURN" "$OPEN_NEW_PROMPT"
    check "tried to create the issue" ge "$(gh_log_count issue create)" 1
    check "spec has no Issue line" spec_has_no_issue_line
    check "says gh auth login" has_i "$OUT" 'gh auth login'
    common_checks "$work"
}

scenario_plan_ready() {
    setup
    version_flag_docs "$work" "$ISSUE12"
    opened_issue_12 Planning noplan
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "You are running superpowers:writing-plans in normal mode. You have just written, self-reviewed and committed the plan at $PLAN_PATH; its header carries the issue line. $(moment 'post the plan-ready milestone' 'Milestones'), then stop: do not write the closing message."
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "the comment ends with the plan-ready marker" named_ends_with issue comment 12 '<!-- superpowers:plan-ready -->'
    check "the comment mentions review" has_i "$(named_body issue comment 12)" 'review'
    check "#12 status line is Planning" test "$(i_first 12)" = '**Status:** Planning'
    check "#12 body names the plan path" hasf "$(i_body 12)" "$PLAN_PATH"
    check "#12 body ends with the opened marker" body_ends_with_opened 12
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_plan_ready_already_posted() {
    setup
    version_flag_docs "$work" "$ISSUE12"
    opened_issue_12
    run_moment "$work" "$TURN" "You are running superpowers:writing-plans in normal mode. You have just written, self-reviewed and committed the plan at $PLAN_PATH; its header carries the issue line. $(moment 'post the plan-ready milestone' 'Milestones'), then stop: do not write the closing message."
    check "no comment posted" num_is "$(gh_log_count issue comment)" 0
    check "looked at the issue first" ge "$(gh_log_count issue view)" 1
    common_checks "$work"
}

EXEC_AFTER_TASK1="$C_EXEC Task 1 has just completed: its tests passed and it is committed. $(moment 'do what comes after Task 1' 'The Draft PR')"

scenario_draft_after_task1() {
    fx_building worktree
    run_moment "$wt" "$TURN" "$EXEC_AFTER_TASK1, then stop before Task 2."
    local prbody
    prbody="$(gh_log_body pr create)"
    check "version-flag is on the remote at HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "the PR is a draft" gh_log_has_flag pr create '--draft|-d'
    check "base is main" gh_log_has_flag pr create '--base|-B' main
    check "head is version-flag" gh_log_has_flag pr create '--head|-H' version-flag
    check "PR body closes #12" hasf "$prbody" 'Closes #12'
    check "PR body links the spec" hasf "$prbody" "$BLOB/$SPEC_PATH"
    check "PR body links the plan" hasf "$prbody" "$BLOB/$PLAN_PATH"
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "the comment links the PR" named_body_has issue comment 12 "$PR13"
    check "the comment ends with the draft-pr marker" named_ends_with issue comment 12 '<!-- superpowers:draft-pr -->'
    check "#12 status line is the draft PR" test "$(i_first 12)" = '**Status:** Building: draft PR #13'
    check "#12 body links the spec" hasf "$(i_body 12)" "$BLOB/$SPEC_PATH"
    check "#12 body ends with the opened marker" body_ends_with_opened 12
    check "main on the remote is unchanged" main_unchanged
    common_checks "$wt"
}

scenario_push_after_task2() {
    fx_building worktree
    push_work "$wt"
    draft_pr_13 main
    task2_commit "$wt"
    run_moment "$wt" "$TURN" "$C_EXEC Task 2 has just completed: its tests passed and it is committed. $(moment 'do what comes after a completed task' 'The Draft PR'), then stop."
    check "version-flag is on the remote at HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "no issue comment" num_is "$(gh_log_count issue comment)" 0
    check "no issue edit" num_is "$(gh_log_count issue edit)" 0
    common_checks "$wt"
}

scenario_on_default_branch() {
    setup
    opened_issue_12 Building noplan
    printf '%s\n' '#!/bin/sh' 'echo "Hello, ${2:-${1:-world}}!"' > "$work/hello.sh"
    git -C "$work" commit -q -am "Accept a --name option"
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" 'Your human partner approved a small change and asked you to build it directly on main: make hello.sh accept a --name option. This work tracks https://github.com/acme/widgets/issues/12 (opened for this work). You have just made the first commit for it, on main. Do what the issue tracking needs after a first commit as superpowers:tracking-work-in-issues says (The Draft PR), then stop.'
    check "main on the remote is unchanged" main_unchanged
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    common_checks "$work"
}

scenario_part_done() {
    setup
    split_plan_docs "$work" "$ISSUE12"
    opened_issue_12
    wt="$(work_branch "$work" main worktree)"
    push_work "$wt"
    draft_pr_13 main
    task2_commit "$wt"
    push_work "$wt"
    run_moment "$wt" "$TURN" "You are executing part 1 of 2 of the plan indexed at $INDEX_PATH with superpowers:executing-plans, in this worktree. Every task of part 1 is complete and its final review passed; you are at the Finish step, and part 2 comes next in another session. $(moment 'do what the issue tracking needs at the end of a part' 'Milestones'), then stop."
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "the comment ends with the part-1-done marker" named_ends_with issue comment 12 '<!-- superpowers:part-1-done -->'
    check "no pr ready" num_is "$(gh_log_count pr ready)" 0
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    common_checks "$wt"
}

scenario_waiting_on_you() {
    fx_building worktree
    push_work "$wt"
    draft_pr_13 main
    run_moment "$wt" "$TURN" "$C_EXEC Task 1 is done and the draft PR is open. Working on Task 2, you found that the spec does not say whether --version prints to stdout or stderr, and the choice changes what users see, so only your human partner can decide. Stop and ask them, and do what the issue tracking needs when the work stops for a question, as superpowers:tracking-work-in-issues says (Milestones). $HEADLESS"
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "the comment ends with a waiting marker" grep -qE '^<!-- superpowers:waiting-[0-9]{12} -->$' <<< "$(named_last_lines issue comment 12)"
    check "#12 status line is waiting" test "$(i_first 12)" = '**Status:** Waiting on a decision'
    check "asks about stdout" has_i "$OUT" 'stdout'
    common_checks "$wt"
}

# Checks shared by the two finish_ready scenarios. Arg: plain|nonclosing
finish_ready_checks() {
    local cbody
    cbody="$(named_body_ending issue comment 12 '<!-- superpowers:pr-ready -->')"
    check "version-flag is on the remote at HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "a pr edit on #13 whose body closes #12" named_body_has pr edit 13 'Closes #12'
    check "one pr ready" num_is "$(gh_log_count pr ready)" 1
    check "PR #13 is no longer a draft" pr_is_draft_false
    check "a comment on #12 ends with the pr-ready marker" named_ends_with issue comment 12 '<!-- superpowers:pr-ready -->'
    if [[ "$1" == plain ]]; then
        check "the pr-ready comment does not say the issue won't close" not matches_ei "$cbody" "$NOT_CLOSING"
    else
        check "the pr-ready comment says the issue won't close" matches_ei "$cbody" "$NOT_CLOSING"
        check "the output says the issue won't close" matches_ei "$OUT" "$NOT_CLOSING"
    fi
    check "#12 status line is ready for review" test "$(i_first 12)" = '**Status:** Ready for review: PR #13'
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    common_checks "$wt"
}

scenario_finish_ready() {
    fx_finish main
    run_moment "$wt" "$TURN" "$C_FINISH Your human partner chose \"Mark the draft PR ready for review\". $(moment 'carry that out' 'Finishing'), then stop."
    finish_ready_checks plain
}

scenario_finish_ready_non_default_base() {
    fx_finish dev
    run_moment "$wt" "$TURN" "$C_FINISH Your human partner chose \"Mark the draft PR ready for review\". $(moment 'carry that out' 'Finishing'), then stop."
    finish_ready_checks nonclosing
}

fx_finish_pushed() {
    fx_finish main
    push_work "$wt"
}

MERGE_PROMPT="$C_FINISH"' Your human partner chose "Merge back to main locally". '

scenario_finish_merge_pushed() {
    fx_finish_pushed
    local tip
    tip="$(git -C "$wt" rev-parse version-flag)"
    run_moment "$wt" "$TURN" "$MERGE_PROMPT$(moment 'carry that out' 'Finishing'). $HEADLESS"
    check "after turn 1: the version-flag tip is merged into local main" git -C "$wt" merge-base --is-ancestor "$tip" main
    check "after turn 1: main on the remote is unchanged" main_unchanged
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    check "after turn 1: asks about pushing" has_i "$OUT" 'push'
    continue_moment "$wt" "$TURN" 'Yes, push main.'
    local local_main
    local_main="$(git -C "$wt" rev-parse main)"
    check "remote main is local main" same_ref "$(bare_ref "$root" main)" "$local_main"
    check "a comment on #12 ends with the merged marker" named_ends_with issue comment 12 '<!-- superpowers:merged -->'
    check "the comment has the short sha" named_body_has issue comment 12 "${local_main:0:7}"
    check "an issue close naming #12" ge "$(named_count issue close 12)" 1
    check "#12 is closed" issue_state_is 12 state CLOSED
    check "#12 is closed as completed" issue_state_is 12 stateReason COMPLETED
    check "looked at PR #13" ge "$(gh_log_count pr view)" 1
    check "one pr close naming #13" num_is "$(named_count pr close 13)" 1
    check "the pr close carries a body" named_body_not_null pr close 13
    check "#12 status line is Merged in" starts "$(i_first 12)" '**Status:** Merged in'
    common_checks "$wt"
}

scenario_finish_merge_not_pushed() {
    fx_finish_pushed
    run_moment "$wt" "$TURN" "$MERGE_PROMPT$(moment 'carry that out' 'Finishing'). $HEADLESS"
    continue_moment "$wt" "$TURN" 'No, do not push it.'
    check "main on the remote is unchanged" main_unchanged
    check "a comment on #12 ends with the merged-locally marker" named_ends_with issue comment 12 '<!-- superpowers:merged-locally -->'
    check "no issue close" num_is "$(gh_log_count issue close)" 0
    check "no pr close" num_is "$(gh_log_count pr close)" 0
    check "#12 status line is Merged locally" starts "$(i_first 12)" '**Status:** Merged locally'
    common_checks "$wt"
}

scenario_finish_keep() {
    fx_finish main
    run_moment "$wt" "$TURN" "$C_FINISH Your human partner chose \"Keep the branch as-is\". $(moment 'carry that out' 'Finishing'), then stop."
    check "a comment on #12 ends with the paused marker" named_ends_with issue comment 12 '<!-- superpowers:paused -->'
    check "the comment names the branch" named_body_has issue comment 12 'version-flag'
    check "#12 status line is paused on the branch" test "$(i_first 12)" = '**Status:** Paused on branch `version-flag`'
    check "no pr close" num_is "$(gh_log_count pr close)" 0
    check "no pr ready" num_is "$(gh_log_count pr ready)" 0
    common_checks "$wt"
}

scenario_finish_discard_opened() {
    fx_finish_pushed
    run_moment "$wt" "$TURN" "$C_FINISH Your human partner asks you to discard this work entirely. $(moment 'follow it as you confirm' 'Finishing'). $HEADLESS"
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    check "after turn 1: version-flag is still on the remote" test -n "$(bare_ref "$root" version-flag)"
    check "after turn 1: the confirmation names #13" has_i "$OUT" '#13'
    check "after turn 1: the confirmation says discard" has_i "$OUT" 'discard'
    check "after turn 1: the confirmation mentions the remote" has_ei "$OUT" 'origin|remote|pushed'
    continue_moment "$wt" "$TURN" 'discard'
    check "one pr close naming #13" num_is "$(named_count pr close 13)" 1
    check "version-flag is gone from the remote" test -z "$(bare_ref "$root" version-flag)"
    check "an issue comment or close for #12 ends with the dropped marker" dropped_marker_posted
    check "the issue close says not planned" has_i "$(gh_log_arg issue close '--reason|-r')" 'not planned'
    check "#12 is closed as not planned" issue_state_is 12 stateReason NOT_PLANNED
    check "#12 status line is Dropped" test "$(i_first 12)" = '**Status:** Dropped'
    common_checks "$wt"
}

scenario_finish_discard_existing() {
    setup
    version_flag_docs "$work" '**Issue:** https://github.com/acme/widgets/issues/4 (existing)'
    existing_issue_4 shellkah
    printf '%s\n' 'Tracking this work here.' "$OPENED_MARKER" | fake_issue_comment 4 -
    wt="$(work_branch "$work" main checkout)"
    push_work "$wt"
    draft_pr_13 main 4
    issue_json 4 | jq -r '.title, .body' > "$root/saved-4.txt"
    run_moment "$wt" "$TURN" "$C_FINISH Your human partner asked you to discard this work; you showed the confirmation (the branch, its commits, the pushed branch and draft PR #13) and they typed discard. $(moment 'carry out the discard' 'Finishing'), then stop."
    check "one pr close naming #13" num_is "$(named_count pr close 13)" 1
    check "version-flag is gone from the remote" test -z "$(bare_ref "$root" version-flag)"
    check "no issue close" num_is "$(gh_log_count issue close)" 0
    check "#4 is still open" issue_state_is 4 state OPEN
    check "a comment on #4 ends with the dropped marker" named_ends_with issue comment 4 '<!-- superpowers:dropped -->'
    check "an edit on #4 removes @me" named_has_flag issue edit 4 '--remove-assignee' '@me'
    check "#4 is no longer assigned to shellkah" jq -e '.assignees | any(.login == "shellkah") | not' "$FAKE_GH_STATE/issues/4.json"
    check "#4 title and body are untouched" issue_4_unchanged
    common_checks "$wt"
}

scenario_comment_fails() {
    fx_building worktree
    export FAKE_GH_FAIL='issue comment'
    run_moment "$wt" "$TURN" "$EXEC_AFTER_TASK1. Then do Task 2 yourself: make ./hello.sh --version print the contents of VERSION, add that check to test.sh, and commit. End with your final message for this run."
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "./hello.sh --version prints 1.0.0" test "$(cd "$wt" && ./hello.sh --version 2> /dev/null)" = 1.0.0
    check "the version change is committed" bash -c 'git -C "$1" show HEAD:hello.sh | grep -q -- --version && test -z "$(git -C "$1" status --porcelain)"' _ "$wt"
    check "says gh auth login" has_i "$OUT" 'gh auth login'
    common_checks "$wt"
}

scenario_quick_task_named_issue() {
    setup
    fake_issue 3 'Typo in README' ''
    run_moment "$work" "$TURN" 'Fix the typo "teh" in README.md; it should be "the". That'"'"'s issue #3.'
    check "no forge write" num_is "$(gh_write_count)" 0
    check "README has the fix" grep -q 'Run the script' "$work/README.md"
    check "README no longer has the typo" not grep -q 'teh' "$work/README.md"
    check "the output names #3" has_i "$OUT" '#3'
    common_checks "$work"
}

scenario_executor_stays_off_forge() {
    fx_building worktree
    local prompt
    prompt=$(
        cat <<'PROMPT_END'
You are an executor subagent dispatched by superpowers:autopilot; your rules say you never push, post or publish, because autopilot's main session does. Your handover prompt says "Execute part 1 of 1 of the implementation plan at docs/superpowers/plans/2026-01-01-version-flag.md" and carries this bullet: "- **Issue:** keep `https://github.com/acme/widgets/issues/12` current as `superpowers:tracking-work-in-issues` says." Task 1 has just completed and is committed in this worktree. Do whatever comes next for the issue, then stop before Task 2.
PROMPT_END
    )
    run_moment "$wt" "$TURN" "$prompt"
    check "no gh call" num_is "$(gh_log_total)" 0
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    common_checks "$wt"
}

scenario_offer_public() {
    setup
    fake_repo_facts PUBLIC true main
    run_moment "$work" "$TURN" "$(c_brain) $OFFER_SENTENCE $HEADLESS"
    check "no forge write" num_is "$(gh_write_count)" 0
    check "offers: Open a new issue" has_i "$OUT" 'Open a new issue'
    check "says public" has_i "$OUT" 'public'
    check "says anyone can read it" has_i "$OUT" 'anyone'
    common_checks "$work"
}

# ---- runner ----

RESULTS="$(mktemp -d)"
trap 'rm -rf "$RESULTS"' EXIT

run_scenario() { # <name>: runs in a subshell, writes <name>.out and <name>.rc
    local name="$1"
    (
        FAILURES=0
        OUT=""
        OUT2=""
        if ! declare -F "scenario_$name" > /dev/null; then
            echo "  [FAIL] no such scenario: $name"
            FAILURES=1
        else
            echo "=== scenario: $name ==="
            "scenario_$name"
            if [[ $FAILURES -gt 0 ]]; then
                show_run_context
                if compgen -G "$FAKE_GH_STATE/issues/*.json" > /dev/null; then
                    echo "  --- issues ---"
                    jq -c '{number, title, state, stateReason, assignees: [.assignees[].login], body, comments: [.comments[].body]}' "$FAKE_GH_STATE"/issues/*.json | sed 's/^/    /'
                fi
                if compgen -G "$FAKE_GH_STATE/pulls/*.json" > /dev/null; then
                    echo "  --- pull requests ---"
                    jq -c '{number, state, isDraft, baseRefName, body}' "$FAKE_GH_STATE"/pulls/*.json | sed 's/^/    /'
                fi
            fi
        fi
        if [[ $FAILURES -gt 0 ]]; then echo "  RESULT: FAIL ($FAILURES checks)"; else echo "  RESULT: PASS"; fi
        [[ -n "${root:-}" ]] && rm -rf "$root"
        [[ $FAILURES -eq 0 ]]
    ) > "$RESULTS/$name.out" 2>&1
    echo $? > "$RESULTS/$name.rc"
    if [[ "$(cat "$RESULTS/$name.rc")" == 0 ]]; then
        echo "[done] $name: PASS" >&2
    else
        echo "[done] $name: FAIL" >&2
    fi
}

SCENARIOS="${TRACKING_SCENARIOS:-$ALL_SCENARIOS}"
mapfile -t LIST < <(tr -s ' \n' '\n\n' <<< "$SCENARIOS" | sed '/^$/d')

echo "=== Test: issue tracking, moment by moment (${#LIST[@]} scenarios, $JOBS at once) ==="
for name in "${LIST[@]}"; do
    while [[ "$(jobs -rp | wc -l)" -ge "$JOBS" ]]; do wait -n || true; done
    run_scenario "$name" &
done
wait

failed=0
for name in "${LIST[@]}"; do
    echo
    cat "$RESULTS/$name.out"
    [[ "$(cat "$RESULTS/$name.rc")" == 0 ]] || failed=$((failed + 1))
done
echo
if [[ $failed -eq 0 ]]; then
    echo PASS
else
    echo "FAIL ($failed scenarios)"
    exit 1
fi
