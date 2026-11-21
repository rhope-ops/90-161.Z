#!/usr/bin/env bash
# This project's tests, run by scripts/check.sh (pre-push hook and the pull-request Action; PFM, 2026-11-15).
# Usage: scripts/check.local.sh [--fast]: the fast lane (check.sh --fast) passes --fast to tests/run.sh (see its header).
# Needs pwsh 7 and, once for each engine lock, network access to raw.githubusercontent.com (docs/dev-setup.md).
# check.sh shows only the last 25 lines of a failed check, so the failed tests are listed again at the end.
set -u
cd "$(dirname "$0")/.."
# The code standard and its gate run in scripts/check.sh itself (kit 2026.11.20.1), not here.
# Bundle revisions (the PFM, 2026-11-18: "raise the revision on every rebuild"): a bundle that main has never changes.
python3 scripts/bundle_revision.py --test && python3 scripts/bundle_revision.py || exit 1
# TASKS.md is the copy of go.md for when github.io is blocked (the PFM, 2026-11-21): a stale copy fails the push.
python3 scripts/build_readme.py --check || exit 1
# In the pull-request Action only: install the test packages first (the versions in requirements.txt and
# package-lock.json; this project's own step, kept here because the kit's workflow file is locked).
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  PIP_BREAK_SYSTEM_PACKAGES=1 python3 -m pip install --quiet --user -r requirements.txt || exit 1
  npm ci --silent --ignore-scripts || exit 1
  export NODE_PATH="$PWD/node_modules"
fi
log=$(mktemp)
tests/run.sh "$@" >"$log" 2>&1; rc=$?
cat "$log"
if [ "$rc" -ne 0 ]; then echo "Failed tests:"; grep '^FAIL' "$log" | cut -c1-300 | tail -n 20; fi
rm -f "$log"
exit "$rc"
