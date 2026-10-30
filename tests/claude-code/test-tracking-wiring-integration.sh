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

ALL_SCENARIOS="" # each task appends its scenarios, in task order

# ---- prompt pieces ----

# ---- scenarios ----

run_scenarios 'workflow skills reach the tracking skill' "$ALL_SCENARIOS"
