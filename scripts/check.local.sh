#!/usr/bin/env bash
# This project's tests, run by scripts/check.sh (pre-push hook and the pull-request Action; PFM, 2026-11-15).
# Usage: scripts/check.local.sh [--fast]: the fast lane (check.sh --fast) passes --fast to tests/run.sh (see its header).
# Needs pwsh 7 and, once for each engine lock, network access to raw.githubusercontent.com (docs/dev-setup.md).
# check.sh shows only the last 25 lines of a failed check, so the failed tests are listed again at the end.
set -u
cd "$(dirname "$0")/.."
log=$(mktemp)
tests/run.sh "$@" >"$log" 2>&1; rc=$?
cat "$log"
if [ "$rc" -ne 0 ]; then echo "Failed tests:"; grep '^FAIL' "$log" | cut -c1-300 | tail -n 20; fi
rm -f "$log"
exit "$rc"
