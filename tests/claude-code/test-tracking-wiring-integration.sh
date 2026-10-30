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

ALL_SCENARIOS="brainstorm_offer brainstorm_no_forge brainstorm_small_change_approved brainstorm_public_small_change brainstorm_project_approved plan_tracked plan_untracked exec_task1_opens_draft exec_untracked exec_stop_posts_waiting exec_part_done exec_draft_fails sdd_task1_opens_draft sdd_executor_stays_off_forge" # each task appends its scenarios, in task order

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

run_scenarios 'workflow skills reach the tracking skill' "$ALL_SCENARIOS"
