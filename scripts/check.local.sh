#!/usr/bin/env bash
# This project's tests, run by scripts/check.sh (pre-push hook and the pull-request Action; PFM, 2026-11-15).
# Usage: scripts/check.local.sh [--fast]: the fast lane (check.sh --fast) passes --fast to tests/run.sh (see its header).
# Needs pwsh 7 and, once for each engine lock, network access to raw.githubusercontent.com (docs/dev-setup.md).
# check.sh shows only the last 25 lines of a failed check, so the failed tests are listed again at the end.
set -u
cd "$(dirname "$0")/.."
# Code standard (the PFM, 2026-11-17; docs/code-standard.md): the check proves itself, then measures every source file
# against the shrink-only baseline. Both lanes (about 2 s). The same check file runs in rhope-ops/RADE.
python3 scripts/code_standard.py --test && python3 scripts/code_standard.py || exit 1
# Bundle revisions (the PFM, 2026-11-18: "raise the revision on every rebuild"): a bundle that main has never changes.
python3 scripts/bundle_revision.py --test && python3 scripts/bundle_revision.py || exit 1
log=$(mktemp)
tests/run.sh "$@" >"$log" 2>&1; rc=$?
cat "$log"
if [ "$rc" -ne 0 ]; then echo "Failed tests:"; grep '^FAIL' "$log" | cut -c1-300 | tail -n 20; fi
rm -f "$log"
exit "$rc"
