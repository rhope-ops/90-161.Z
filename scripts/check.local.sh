#!/usr/bin/env bash
# This project's tests, run last by scripts/check.sh (pre-push hook and the pull-request Action; PFM, 2026-11-15).
# Needs pwsh 7 and, once for each engine lock, network access to raw.githubusercontent.com (docs/dev-setup.md).
set -u
cd "$(dirname "$0")/.."
tests/run.sh
