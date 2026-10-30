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

ALL_SCENARIOS="brainstorm_offer brainstorm_no_forge brainstorm_small_change_approved brainstorm_public_small_change brainstorm_project_approved plan_tracked plan_untracked" # each task appends its scenarios, in task order

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

run_scenarios 'workflow skills reach the tracking skill' "$ALL_SCENARIOS"
