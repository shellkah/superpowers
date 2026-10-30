#!/usr/bin/env bash
# Test: the workflow skills reach superpowers:tracking-work-in-issues at the
# moments the spec names, against the stand-in gh. Each scenario builds a test
# repo and a stand-in forge state under its own temp root, runs a real headless
# session, then checks the call log, the forge state and the repos from outside.
#
# TRACKING_SCENARIOS  space-separated scenario names (default: all, in order)
# TRACKING_JOBS       scenarios run at once (default 1)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$SCRIPT_DIR/tracking-fixtures.sh"

root="" work="" wt="" # set by the fixtures (fxv)
TURN="${CLAUDE_PROMPT_TIMEOUT:-300}"
LONG="${CLAUDE_LONG_TIMEOUT:-900}"

ALL_SCENARIOS="brainstorm_offer brainstorm_no_forge brainstorm_small_change_approved brainstorm_public_small_change brainstorm_project_approved plan_tracked plan_untracked exec_task1_opens_draft exec_untracked exec_stop_posts_waiting exec_part_done exec_draft_fails sdd_task1_opens_draft sdd_executor_stays_off_forge finish_menu_ready_dev finish_menu_untracked finish_menu_draft_closed finish_option1_pushed finish_option3_paused finish_discard_confirmed finish_on_default_branch autopilot_spec_commit autopilot_after_part1 autopilot_blocker autopilot_step5_ready autopilot_one_part_pr" # each task appends its scenarios, in task order

# ---- prompt pieces ----

# ---- scenarios ----

# ---- brainstorming ----
b_intro() { printf '%s' "Use superpowers:brainstorming. We are in it for this request: \"$1\""; }
B_LAST="The work is sized as a small change, and this is the last round of questions. Ask your last round of questions now, as brainstorming says. $HEADLESS"
B_SMALL_APPROVED=' The work was sized as a small change. In the last round of questions you offered to track it in an issue, and your human partner chose "Open a new issue". You then described the change in chat: `./hello.sh --name Ada` prints "Hello, Ada!", plain `./hello.sh` still prints "Hello, world!", and test.sh checks both. They just replied: "Looks good, go ahead." Carry on as brainstorming says, and stop before you write any code or test.'
# no change to hello.sh or test.sh: not in the work tree, not in any commit after the first
hello_untouched() { git -C "$work" diff --quiet -- hello.sh test.sh && test "$(git -C "$work" log --all --format=%H -- hello.sh | wc -l)" = 1; }

scenario_brainstorm_offer() {
    setup || return
    fx fake_issue 3 'Add a --version flag to hello.sh' '' alice || return
    run_moment "$work" "$TURN" "$(b_intro 'Add a --version flag to hello.sh.') $B_LAST"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "no forge write" num_is "$(gh_write_count)" 0
    check "an issue list call carries a search" gh_log_has_flag issue list '--search|-S'
    check "offers: Open a new issue" hasf "$OUT" 'Open a new issue'
    check "offers: No issue" hasf "$OUT" 'No issue'
    check "lists #3" hasf "$OUT" '#3'
    common_checks "$work"
}

scenario_brainstorm_no_forge() { # origin is a local path: no offer, no gh call
    setup local || return
    run_moment "$work" "$TURN" "$(b_intro 'Add a --version flag to hello.sh.') $B_LAST"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "no gh call" num_is "$(gh_log_total)" 0
    check "no offer to open an issue" not hasf "$OUT" 'Open a new issue'
    common_checks "$work"
}

scenario_brainstorm_small_change_approved() {
    setup || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$(b_intro 'Make hello.sh greet a name given with --name.')$B_SMALL_APPROVED"
    local body
    body="$(posted_body)"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "one issue created" num_is "$(gh_log_count issue create)" 1
    check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
    check "body starts with the Building status" test "$(first_line "$body")" = '**Status:** Building'
    check "body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "hello.sh and test.sh untouched" hello_untouched
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_brainstorm_public_small_change() {
    setup || return
    fx fake_repo_facts PUBLIC true main || return
    run_moment "$work" "$TURN" "$(b_intro 'Make hello.sh greet a name given with --name.')$B_SMALL_APPROVED"
    check "loaded brainstorming" loaded "$work" brainstorming
    check "no issue created yet" num_is "$(gh_log_count issue create)" 0
    check "says public" hasf "$OUT" 'public'
    check "shows the text, with its Status line" hasf "$OUT" 'Status:'
    check "hello.sh and test.sh untouched" hello_untouched
    common_checks "$work"
}

scenario_brainstorm_project_approved() {
    setup || return
    fx spec_only "$work" || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$(b_intro 'Add a --version flag to hello.sh.') It was sized as a project, and its written design is at $SPEC_PATH, committed; the builder check is done. In the last round of questions you offered to track it in an issue, and your human partner chose \"Open a new issue\". They just replied: \"The design looks right. Approved.\" Carry on as brainstorming says, and stop before you invoke superpowers:writing-plans."
    local body
    body="$(posted_body)"
    printf '%s\n' "$body" > "$root/posted-body.txt"
    check "loaded brainstorming" loaded "$work" brainstorming
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

# ---- writing-plans ----
P_WRITE="Use superpowers:writing-plans to write the implementation plan for $SPEC_PATH. The spec is approved."
HANDOVER_BULLET_12='- **Issue:** keep `https://github.com/acme/widgets/issues/12` current as `superpowers:tracking-work-in-issues` says.'
# The plan writing-plans wrote: the one .md under docs/superpowers/plans that is not an index, a part or a handover file.
plan_doc() { find "$work/docs/superpowers/plans" -name '*.md' ! -name '*-index.md' ! -name '*-part-*' ! -name '*.handover.md' 2> /dev/null; }
handover_doc() { find "$work/docs/superpowers/plans" -name '*.handover.md' 2> /dev/null; }
one_line() { test "$(grep -c . <<< "$1")" = 1; }

scenario_plan_tracked() {
    setup || return
    fx spec_only "$work" "$ISSUE12" || return
    fx opened_issue_12 Planning noplan || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$LONG" "$P_WRITE"
    local plan hand rel
    plan="$(plan_doc)"; hand="$(handover_doc)"; rel="${plan#"$work"/}"
    check "loaded writing-plans" loaded "$work" writing-plans
    check "one plan, not split" one_line "$plan"
    check "no index" test -z "$(find "$work/docs/superpowers/plans" -name '*-index.md')"
    check "the plan carries the spec's Issue line under its title" test "$(first_line_after_title "$plan")" = "$ISSUE12"
    check "one handover file" one_line "$hand"
    check "the handover prompt has the Issue bullet" grep -qxF -- "$HANDOVER_BULLET_12" "$hand"
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with the plan-ready marker" named_ends_with issue comment 12 '<!-- superpowers:plan-ready -->'
    check "it says the plan waits for review" has_i "$(named_body issue comment 12)" 'review'
    check "#12 status line is Planning" test "$(i_first 12)" = '**Status:** Planning'
    check "#12 body names the plan path" hasf "$(i_body 12)" "$rel"
    check "#12 body ends with the opened marker" body_ends_with_opened 12
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_plan_untracked() {
    setup || return
    fx spec_only "$work" '**Issue:** none' || return
    run_moment "$work" "$LONG" "$P_WRITE"
    local plan hand
    plan="$(plan_doc)"; hand="$(handover_doc)"
    check "loaded writing-plans" loaded "$work" writing-plans
    check "no gh call" num_is "$(gh_log_total)" 0
    check "the plan copies Issue: none" test "$(first_line_after_title "$plan")" = '**Issue:** none'
    check "the handover prompt has no Issue bullet" not grep -q '^- \*\*Issue:\*\*' "$hand"
    common_checks "$work"
}

# ---- executing-plans and the subagent-driven-development controller ----
E_TASK1="Use superpowers:executing-plans to execute the plan at $PLAN_PATH, in this worktree. Do Task 1 only, then stop before you start Task 2."

# ledger_done <dir> <plan-path> <exec|sdd> <N>...: the SDD ledger with those tasks complete.
ledger_done() {
    local dir="$1" plan="$2" kind="$3" ws base head n
    shift 3
    ws="$(cd "$dir" && bash "$SCRIPT_DIR/../../skills/subagent-driven-development/scripts/sdd-workspace" "$plan")" || return 1
    base="$(git -C "$dir" merge-base main HEAD | cut -c1-7)"
    head="$(git -C "$dir" rev-parse --short HEAD)"
    {
        echo "# SDD ledger — plan: $plan"
        for n in "$@"; do
            if [[ "$kind" = exec ]]; then
                echo "Task $n: complete (commits $base..$head, tests: bash test.sh → PASS)"
            else
                echo "Task $n: complete (commits $base..$head, review clean)"
            fi
        done
    } > "$ws/progress.md"
}

# part1_handover <work>: the handover prompt for part 1 of 2.
part1_handover() {
    local work="$1" bullet
    bullet="$(grep -m1 '^- \*\*Not the last part:\*\*' "$SCRIPT_DIR/../../skills/writing-plans/SKILL.md" | sed 's/^- \*\*Not the last part:\*\* //')"
    cat << EOF
Execute part 1 of 2 of the implementation plan at \`$work/docs/superpowers/plans/2026-01-01-version-flag-part-1-core.md\` (spec: \`$work/docs/superpowers/specs/2026-01-01-version-flag-design.md\`).

- **Skill:** use \`superpowers:executing-plans\`.
- **Why this mode:** two small tasks, done in order.
- **Branch:** work on branch \`version-flag\`.
- **Workspace:** set up the workspace as the skill says.
- **Not the last part:** $bullet
- **Issue:** keep \`https://github.com/acme/widgets/issues/12\` current as \`superpowers:tracking-work-in-issues\` says.
EOF
}

# The draft PR after Task 1, as part 1's scenario_draft_after_task1 checks it.
draft_opened_checks() {
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
}

scenario_exec_task1_opens_draft() {
    fx_building worktree || return
    fx git -C "$wt" reset -q --hard HEAD~1 || return   # Task 1 not done yet
    run_moment "$wt" "$LONG" "$E_TASK1"
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "Task 1 is committed: VERSION holds 1.0.0" test "$(git -C "$wt" show HEAD:VERSION 2> /dev/null)" = 1.0.0
    draft_opened_checks
    common_checks "$wt"
}

scenario_exec_untracked() {
    setup || return
    fx version_flag_docs "$work" '**Issue:** none' || return
    fxv wt work_branch "$work" main worktree || return
    fx git -C "$wt" reset -q --hard HEAD~1 || return
    run_moment "$wt" "$LONG" "$E_TASK1"
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "Task 1 is committed: VERSION holds 1.0.0" test "$(git -C "$wt" show HEAD:VERSION 2> /dev/null)" = 1.0.0
    check "no gh call" num_is "$(gh_log_total)" 0
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    common_checks "$wt"
}

scenario_exec_stop_posts_waiting() { # Task 3 deletes a remote branch: one of the four stops
    fx_building worktree || return
    fx push_work "$wt" || return
    fx draft_pr_13 main || return
    fx task2_commit "$wt" || return
    printf '\n%s\n\n%s\n' '### Task 3: Remove the legacy branch' \
        '- [ ] Delete the `legacy` branch on origin with `git push origin --delete legacy`: nothing uses it any more.' >> "$wt/$PLAN_PATH"
    fx git -C "$wt" commit -qam 'Plan: remove the legacy branch' || return
    fx git -C "$work" push -q origin main:refs/heads/legacy || return
    fx ledger_done "$wt" "$PLAN_PATH" exec 1 2 || return
    run_moment "$wt" "$TURN" "Use superpowers:executing-plans to execute the plan at $PLAN_PATH, in this worktree. Its ledger shows Tasks 1 and 2 complete; carry on from Task 3. $HEADLESS"
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "legacy is still on the remote" test -n "$(bare_ref "$root" legacy)"
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with a waiting marker" grep -qE '^<!-- superpowers:waiting-[0-9]{12} -->$' <<< "$(named_last_lines issue comment 12)"
    check "#12 status line is waiting" test "$(i_first 12)" = '**Status:** Waiting on a decision'
    check "asks about the legacy branch" hasf "$OUT" 'legacy'
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    common_checks "$wt"
}

scenario_exec_part_done() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 || return
    fxv wt work_branch "$work" main worktree || return
    fx push_work "$wt" || return
    fx draft_pr_13 main || return
    fx task2_commit "$wt" || return
    fx push_work "$wt" || return
    fx ledger_done "$wt" "$PART_PATH" exec 1 2 || return
    run_moment "$wt" "$TURN" "$(part1_handover "$work")

Every task of this part is complete in the ledger, and the final review passed with no findings. Carry on from the Finish step as executing-plans and this prompt say."
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with the part-1-done marker" named_ends_with issue comment 12 '<!-- superpowers:part-1-done -->'
    check "no pr ready" num_is "$(gh_log_count pr ready)" 0
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "no finishing menu" not hasf "$OUT" 'Which option?'
    common_checks "$wt"
}

scenario_exec_draft_fails() {
    fx_building worktree || return
    fx git -C "$wt" reset -q --hard HEAD~1 || return
    export FAKE_GH_FAIL='pr create'
    run_moment "$wt" "$LONG" "Use superpowers:executing-plans to execute the plan at $PLAN_PATH, in this worktree. Do Tasks 1 and 2, then stop before the final review and write your final message for this run."
    check "loaded executing-plans" loaded "$wt" executing-plans
    check "tried to open the draft" ge "$(gh_log_count pr create)" 1
    check "./hello.sh --version prints 1.0.0" test "$(cd "$wt" && ./hello.sh --version 2> /dev/null)" = 1.0.0
    check "the version change is committed" git -C "$wt" diff --quiet HEAD -- hello.sh
    check "says gh auth login" hasf "$OUT" 'gh auth login'
    common_checks "$wt"
}

scenario_sdd_task1_opens_draft() {
    fx_building worktree || return
    fx ledger_done "$wt" "$PLAN_PATH" sdd 1 || return
    run_moment "$wt" "$TURN" "Use superpowers:subagent-driven-development: you are its controller for the plan at $PLAN_PATH, in this worktree. Task 1's task review came back clean, and you have just written its completion line to the ledger. Carry on as the skill says, and stop before you dispatch Task 2's implementer."
    check "loaded subagent-driven-development" loaded "$wt" subagent-driven-development
    draft_opened_checks
    common_checks "$wt"
}

scenario_sdd_executor_stays_off_forge() {
    fx_building worktree || return
    fx mkdir -p "$root/run" || return
    local prompt
    prompt="$(executor_prompt "$work" "$wt" "$root/run" subagent-driven-development)"
    executor_prompt_ok "$prompt" || { check "fixture: executor prompt built from executor-prompt.md" false; return; }
    run_moment "$wt" "$TURN" "$prompt"
    check "no gh call" num_is "$(gh_log_total)" 0
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    common_checks "$wt"
}

# ---- finishing-a-development-branch ----
C_FINISH_USE='Implementation of the plan at docs/superpowers/plans/2026-01-01-version-flag.md is complete on this branch: its tests pass, and there were no rulings or deferred minors. Use superpowers:finishing-a-development-branch.'
menu_has() { hasf "$(tr -d '*' <<< "$OUT")" "$1"; }   # bold markup aside
close_pr() { local f="$FAKE_GH_STATE/pulls/$1.json"; jq '.state = "CLOSED" | .closed = true' "$f" > "$f.tmp" && mv "$f.tmp" "$f"; }

scenario_finish_menu_ready_dev() { # the base comes from the draft, not a question
    fx_finish dev || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "menu: option 2 marks the draft ready" menu_has '2. Mark the draft PR ready for review'
    check "menu: no Push and create a Pull Request" not menu_has 'Push and create a Pull Request'
    check "menu: option 1 names dev" menu_has '1. Merge back to dev locally'
    check "menu: option 3 keeps its text" menu_has "3. Keep the branch as-is (I'll handle it later)"
    check "does not ask for the base" not has_i "$OUT" 'is that correct'
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    continue_moment "$wt" "$TURN" '2'
    finish_ready_checks nonclosing "$OUT2"
}

scenario_finish_menu_untracked() { # no Issue line at all: today's menu, no gh call
    setup || return
    fx version_flag_docs "$work" || return
    fxv wt work_branch "$work" main checkout || return
    fx task2_commit "$wt" || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE This branch was cut from main. $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "no gh call" num_is "$(gh_log_total)" 0
    for line in '1. Merge back to main locally' '2. Push and create a Pull Request' "3. Keep the branch as-is (I'll handle it later)"; do
        check "menu has: $line" menu_has "$line"
    done
    check "no Mark the draft PR" not menu_has 'Mark the draft PR'
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    common_checks "$wt"
}

scenario_finish_menu_draft_closed() {
    fx_finish main || return
    fx close_pr 13 || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE This branch was cut from main. $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "menu: option 2 is today's" menu_has '2. Push and create a Pull Request'
    check "menu: no Mark the draft PR" not menu_has 'Mark the draft PR'
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    continue_moment "$wt" "$TURN" '2'
    check "version-flag is on the remote at HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "it is not a draft" not gh_log_has_flag pr create '--draft|-d'
    check "its base is main" gh_log_has_flag pr create '--base|-B' main
    check "its body closes #12" hasf "$(gh_log_body pr create)" 'Closes #12'
    check "a comment on #12 ends with the pr-ready marker" named_ends_with issue comment 12 '<!-- superpowers:pr-ready -->'
    check "#12 status line is ready for review on PR #14" test "$(i_first 12)" = '**Status:** Ready for review: PR #14'
    common_checks "$wt" full-pr
}

scenario_finish_option1_pushed() {
    fx_finish_pushed || return
    local tip
    tip="$(git -C "$wt" rev-parse version-flag)"
    run_moment "$wt" "$TURN" "$C_FINISH_USE Your human partner has already chosen option 1, Merge back to main locally. $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "after turn 1: the version-flag tip is merged into local main" git -C "$wt" merge-base --is-ancestor "$tip" main
    check "after turn 1: main on the remote is unchanged" main_unchanged
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    check "after turn 1: asks about pushing" has_i "$OUT" 'push'
    continue_moment "$wt" "$TURN" 'Yes, push main.'
    local local_main
    local_main="$(git -C "$wt" rev-parse main)"
    check "remote main is local main" same_ref "$(bare_ref "$root" main)" "$local_main"
    check "a comment on #12 ends with the merged marker" named_ends_with issue comment 12 '<!-- superpowers:merged -->'
    check "that comment has the short sha" hasf "$(named_body_ending issue comment 12 '<!-- superpowers:merged -->')" "${local_main:0:7}"
    check "an issue close naming #12" ge "$(named_count issue close 12)" 1
    check "#12 is closed" issue_state_is 12 state CLOSED
    check "#12 is closed as completed" issue_state_is 12 stateReason COMPLETED
    check "looked at PR #13" ge "$(gh_log_count pr view)" 1
    check "one pr close naming #13" num_is "$(named_count pr close 13)" 1
    check "the pr close carries a body" named_body_not_null pr close 13
    check "#12 status line is Merged in" starts "$(i_first 12)" '**Status:** Merged in'
    common_checks "$wt"
}

scenario_finish_option3_paused() {
    fx_finish main || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE Your human partner has already chosen option 3, Keep the branch as-is."
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "a comment on #12 ends with the paused marker" named_ends_with issue comment 12 '<!-- superpowers:paused -->'
    check "that comment names the branch" hasf "$(named_body_ending issue comment 12 '<!-- superpowers:paused -->')" 'version-flag'
    check "#12 status line is paused on the branch" test "$(i_first 12)" = '**Status:** Paused on branch `version-flag`'
    check "no pr close" num_is "$(gh_log_count pr close)" 0
    check "no pr ready" num_is "$(gh_log_count pr ready)" 0
    common_checks "$wt"
}

scenario_finish_discard_confirmed() {
    fx_finish_pushed || return
    run_moment "$wt" "$TURN" "$C_FINISH_USE Your human partner asks you to discard this work entirely. $HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$wt" finishing-a-development-branch
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    check "after turn 1: version-flag is still on the remote" test -n "$(bare_ref "$root" version-flag)"
    check "after turn 1: the confirmation names #13" hasf "$OUT" '#13'
    check "after turn 1: the confirmation says discard" hasf "$OUT" 'discard'
    check "after turn 1: the confirmation mentions the remote" has_ei "$OUT" 'origin|remote|pushed'
    continue_moment "$wt" "$TURN" 'discard'
    check "one pr close naming #13" num_is "$(named_count pr close 13)" 1
    check "version-flag is gone from the remote" test -z "$(bare_ref "$root" version-flag)"
    check "an issue comment or close for #12 ends with the dropped marker" dropped_marker_posted
    check "the issue close on #12 says not planned" has_i "$(named_arg issue close 12 '--reason|-r')" 'not planned'
    check "#12 is closed as not planned" issue_state_is 12 stateReason NOT_PLANNED
    check "#12 status line is Dropped" test "$(i_first 12)" = '**Status:** Dropped'
    check "main is still on the remote, unchanged" main_kept
    common_checks "$wt"
}

scenario_finish_on_default_branch() { # a small change built straight on main: nothing to merge
    setup || return
    fx opened_issue_12 Building noplan || return
    printf '%s\n' '#!/bin/sh' 'if [ "$1" = "--version" ]; then echo 1.0.0; exit 0; fi' 'echo "Hello, ${1:-world}!"' > "$work/hello.sh" || return
    fx git -C "$work" commit -q -am 'Add a --version flag' || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" 'Your human partner approved a small change and asked you to build it directly on main: make hello.sh print 1.0.0 for --version. It tracks https://github.com/acme/widgets/issues/12 (opened for this work). The change is committed on main, and bash test.sh passes. Use superpowers:finishing-a-development-branch. Your human partner has already chosen option 1, Merge back to main locally. '"$HEADLESS"
    check "loaded finishing-a-development-branch" loaded "$work" finishing-a-development-branch
    check "after turn 1: main on the remote is unchanged" main_unchanged
    check "after turn 1: no forge write" num_is "$(gh_write_count)" 0
    check "after turn 1: asks about pushing" has_i "$OUT" 'push'
    continue_moment "$work" "$TURN" 'Yes, push main.'
    local local_main
    local_main="$(git -C "$work" rev-parse main)"
    check "remote main is local main" same_ref "$(bare_ref "$root" main)" "$local_main"
    check "a comment on #12 ends with the merged marker" named_ends_with issue comment 12 '<!-- superpowers:merged -->'
    check "that comment has the short sha" hasf "$(named_body_ending issue comment 12 '<!-- superpowers:merged -->')" "${local_main:0:7}"
    check "#12 is closed as completed" issue_state_is 12 stateReason COMPLETED
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "no pr close" num_is "$(gh_log_count pr close)" 0
    check "#12 status line is Merged in" starts "$(i_first 12)" '**Status:** Merged in'
    common_checks "$work"
}

# ---- autopilot ----
AP_OPEN='You are the main session of a superpowers:autopilot run that is already driving: load the superpowers:autopilot skill to follow its steps (this is not a new run).'

# draft_spec <work>: the spec with its run notes, not committed.
draft_spec() {
    _write_spec "$1" || return 1
    {
        echo
        echo '## Run notes'
        echo
        echo '- **Services:** none; the work needs none.'
        echo '- **Checkpoints:** no.'
        echo '- **PRs:** one, from `version-flag` against `main`.'
    } >> "$1/$SPEC_PATH"
}

# autopilot_run_dir <work> <parts> <current> [<finished>]: the run folder; prints it.
autopilot_run_dir() {
    local work="$1" parts="$2" current="$3" finished="${4:-none}" run
    run="$work/.superpowers/autopilot/version-flag"
    mkdir -p "$run" || return 1
    echo '*' > "$work/.superpowers/autopilot/.gitignore"
    {
        echo "# Autopilot run — spec: $work/$SPEC_PATH"
        echo
        echo '- Started on branch: `main` (the PR targets it)'
        echo "- Spec: $work/$SPEC_PATH"
        if [[ "$parts" = 1 ]]; then echo "- Plan: $work/$PLAN_PATH"; else echo "- Index: $work/$INDEX_PATH"; fi
        echo "- Builds: 1. Parts: $parts."
        echo
        echo '## Current'
        echo
        echo "$current"
        echo
        echo '## Finished parts'
        echo
        echo "$finished"
        echo
        echo '## Pending'
        echo
        echo 'none'
        echo
        echo '## Run notes'
        echo
        echo '- **Services:** none; the work needs none.'
        echo '- **Checkpoints:** no.'
        echo '- **PRs:** one, from `version-flag` against `main`.'
    } > "$run/state.md"
    {
        echo '# Main session record'
        echo
        echo '- Ruling: [routine] Services question skipped: the work needs none. Cost if wrong: none.'
    } > "$run/main-record.md"
    echo "$run"
}

# part_record <run> <N>
part_record() {
    {
        echo "# Part $2 record"
        echo
        echo '- Ruling: [routine] Kept the greeting text as it is — the spec does not mention it — cost if wrong: none.'
        echo
        echo '## Interfaces produced:'
        echo
        echo '- none'
    } > "$1/part-$2-record.md"
}

# executor_report <DONE|BLOCKED> <wt> <run> <N> <last|not-last> [<blocker>]
executor_report() {
    local status="$1" wt="$2" run="$3" n="$4" pos="$5" blocker="${6:-}" built review accept
    if [[ "$n" = 1 ]]; then built='the VERSION file and ./hello.sh --version'; else built='./hello.sh --help'; fi
    if [[ "$status" = DONE ]]; then review=clean; else review='not run'; fi
    if [[ "$pos" = last ]]; then accept='steps for a person: run ./hello.sh --version and see 1.0.0.'; else accept='n/a'; fi
    echo "Status: $status"
    echo 'Branch: version-flag'
    echo "Worktree: $wt"
    echo "Last commit: $(git -C "$wt" rev-parse --short HEAD)"
    echo "Ledger: $wt/.superpowers/sdd/version-flag/progress.md"
    echo "Record: $run/part-$n-record.md"
    [[ -z "$blocker" ]] || echo "Blocker: $blocker"
    echo "Built: $built"
    echo 'Tests: bash test.sh → PASS'
    echo "Final review: $review"
    echo "Acceptance: $accept"
    echo 'Rulings I made:'
    echo '- none'
    echo 'Routine rulings: 1'
    echo 'Deferred minors: 0'
}

# help_commit <dir>: ./hello.sh --help, committed.
help_commit() {
    printf '%s\n' '#!/bin/sh' \
        'if [ "$1" = "--version" ]; then cat "$(dirname "$0")/VERSION"; exit 0; fi' \
        'if [ "$1" = "--help" ]; then echo "usage: hello.sh [--version | --help | <name>]"; exit 0; fi' \
        'echo "Hello, ${1:-world}!"' > "$1/hello.sh" || return 1
    git -C "$1" commit -q -am 'Add --help text' && (cd "$1" && bash test.sh > /dev/null)
}

run_folder_has_state() { compgen -G "$work/.superpowers/autopilot/*/state.md" > /dev/null; }
# spec_committed alone passes for a spec that was never committed (git diff ignores untracked files)
spec_in_head() { git -C "$work" cat-file -e "HEAD:$SPEC_PATH"; }
ISSUE12_URL=https://github.com/acme/widgets/issues/12

scenario_autopilot_spec_commit() {
    setup || return
    fx draft_spec "$work" || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$AP_OPEN You are in step 2 for the request \"Add a --version flag to hello.sh\": you wrote the spec at $SPEC_PATH with its run notes, and it is not committed yet. The builder check came back with no questions for your human partner. In brainstorming's last round of questions, when you offered to track the work in an issue, they chose \"Open a new issue\". Carry on with step 2 as autopilot says, then stop before step 3."
    local body
    body="$(posted_body)"
    check "loaded autopilot" loaded "$work" autopilot
    check "one issue created" num_is "$(gh_log_count issue create)" 1
    check "assigned to @me" gh_log_has_flag issue create '--assignee|-a' '@me'
    check "body starts with the Planning status" test "$(first_line "$body")" = '**Status:** Planning'
    check "body ends with the opened marker" test "$(last_nonempty "$body")" = "$OPENED_MARKER"
    check "body names the spec path" hasf "$body" "$SPEC_PATH"
    check "spec carries the issue line" spec_line_is '**Issue:** https://github.com/acme/widgets/issues/1 (opened for this work)'
    check "the spec is in HEAD" spec_in_head
    check "spec change is committed" spec_committed
    check "the run folder has a state.md" run_folder_has_state
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_autopilot_after_part1() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    fx task2_commit "$wt" || return
    local run
    fxv run autopilot_run_dir "$work" 2 "Step 4, part 1 of 2, sub-step 6: part 1's executor reported." || return
    fx part_record "$run" 1 || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$TURN" "$AP_OPEN The run folder is $run: read its state.md. In step 4, part 1's executor has just reported:

$(executor_report DONE "$wt" "$run" 1 not-last)

Carry on as autopilot says, and stop just before you would dispatch part 2's writer."
    check "loaded autopilot" loaded "$work" autopilot
    check "version-flag is on the remote at the worktree's HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "the PR is a draft" gh_log_has_flag pr create '--draft|-d'
    check "base is main" gh_log_has_flag pr create '--base|-B' main
    check "head is version-flag" gh_log_has_flag pr create '--head|-H' version-flag
    check "PR body closes #12" hasf "$(gh_log_body pr create)" 'Closes #12'
    check "a comment on #12 ends with the draft-pr marker" named_ends_with issue comment 12 '<!-- superpowers:draft-pr -->'
    check "a comment on #12 ends with the part-1-done marker" named_ends_with issue comment 12 '<!-- superpowers:part-1-done -->'
    check "#12 status line is the draft PR" test "$(i_first 12)" = '**Status:** Building: draft PR #13'
    check "no pr ready" num_is "$(gh_log_count pr ready)" 0
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_autopilot_blocker() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    local run
    fxv run autopilot_run_dir "$work" 2 "Step 4, part 1 of 2, sub-step 5: part 1's executor is running." || return
    fx part_record "$run" 1 || return
    run_moment "$work" "$TURN" "$AP_OPEN The run folder is $run: read its state.md. In step 4, part 1's executor has just reported:

$(executor_report BLOCKED "$wt" "$run" 1 not-last 'Task 2: the spec does not say whether --version prints to stdout or stderr, and the choice changes what users see. Only your human partner can decide.')

Carry on as autopilot says. $HEADLESS"
    check "loaded autopilot" loaded "$work" autopilot
    check "one comment on #12" num_is "$(named_count issue comment 12)" 1
    check "it ends with a waiting marker" grep -qE '^<!-- superpowers:waiting-[0-9]{12} -->$' <<< "$(named_last_lines issue comment 12)"
    check "#12 status line is waiting" test "$(i_first 12)" = '**Status:** Waiting on a decision'
    check "asks about stdout" has_ei "$OUT" 'stdout|standard output'
    check "version-flag is not on the remote" test -z "$(bare_ref "$root" version-flag)"
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    common_checks "$work"
}

scenario_autopilot_step5_ready() {
    setup || return
    fx split_plan_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    fx push_work "$wt" || return
    fx draft_pr_13 main || return
    fx task2_commit "$wt" || return
    fx push_work "$wt" || return
    fx help_commit "$wt" || return
    local run
    fxv run autopilot_run_dir "$work" 2 "Step 4, part 2 of 2, sub-step 6: part 2's executor reported." "- Part 1: DONE. Branch version-flag, worktree $wt. Record part-1-record.md." || return
    fx part_record "$run" 1 || return
    fx part_record "$run" 2 || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$LONG" "$AP_OPEN The run folder is $run: read its state.md. Part 2, the last part, has just reported:

$(executor_report DONE "$wt" "$run" 2 last)

Carry on with steps 5 and 6 as autopilot says."
    check "loaded autopilot" loaded "$work" autopilot
    check "version-flag is on the remote at the worktree's HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "no pr create" num_is "$(gh_log_count pr create)" 0
    check "a pr edit on #13 whose body closes #12" named_body_has pr edit 13 'Closes #12'
    check "that body carries the records in <details>" named_body_has pr edit 13 '<details>'
    check "one pr ready" num_is "$(gh_log_count pr ready)" 1
    check "PR #13 is no longer a draft" pr_is_draft_false
    check "a comment on #12 ends with the pr-ready marker" named_ends_with issue comment 12 '<!-- superpowers:pr-ready -->'
    check "#12 status line is ready for review" test "$(i_first 12)" = '**Status:** Ready for review: PR #13'
    check "the summary gives the issue link" hasf "$OUT" "$ISSUE12_URL"
    check "the summary gives the PR link" hasf "$OUT" "$PR13"
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work"
}

scenario_autopilot_one_part_pr() { # no draft: the PR opens at step 5, already ready
    setup || return
    fx version_flag_docs "$work" "$ISSUE12" || return
    fx opened_issue_12 Building || return
    fxv wt work_branch "$work" main worktree || return
    fx task2_commit "$wt" || return
    local run
    fxv run autopilot_run_dir "$work" 1 "Step 4, part 1 of 1, sub-step 6: the executor reported." || return
    fx part_record "$run" 1 || return
    main_before="$(bare_ref "$root" main)"
    run_moment "$work" "$LONG" "$AP_OPEN The run folder is $run: read its state.md. The plan has one part, and its executor has just reported:

$(executor_report DONE "$wt" "$run" 1 last)

Carry on with steps 5 and 6 as autopilot says."
    check "loaded autopilot" loaded "$work" autopilot
    check "version-flag is on the remote at the worktree's HEAD" same_ref "$(bare_ref "$root" version-flag)" "$(git -C "$wt" rev-parse HEAD)"
    check "one pr create" num_is "$(gh_log_count pr create)" 1
    check "it is not a draft" not gh_log_has_flag pr create '--draft|-d'
    check "its base is main" gh_log_has_flag pr create '--base|-B' main
    check "its body closes #12" hasf "$(gh_log_body pr create)" 'Closes #12'
    check "a comment on #12 ends with the pr-ready marker" named_ends_with issue comment 12 '<!-- superpowers:pr-ready -->'
    check "#12 status line is ready for review" test "$(i_first 12)" = '**Status:** Ready for review: PR #13'
    check "the summary gives the issue link" hasf "$OUT" "$ISSUE12_URL"
    check "the summary gives the PR link" hasf "$OUT" "$PR13"
    check "main on the remote is unchanged" main_unchanged
    common_checks "$work" full-pr
}

run_scenarios 'workflow skills reach the tracking skill' "$ALL_SCENARIOS"
