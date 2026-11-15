#!/usr/bin/env bash
# One check command for the repo (AGENTS.md "Commands": Test). Runs, in order:
#   1. the self-test of each kit script present (--test; a starter project has fewer), 2. the project log check (full tier),
#   3. the personal-data scan of all tracked files (when .pii-guard exists; in GitHub Actions the pii-guard step does it),
#   4. scripts/check.local.sh, when it exists: this project's own tests (SKIP when missing: AGENTS.md Delivery then gates main).
# Prints one PASS/FAIL/SKIP line per check, the output of each failed check, and "CHECK PASS" or "CHECK FAIL" last.
# Exit 0 only when no check failed. Needs bash, git and python3.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

pass=0 fail=0 skip=0
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

run() {  # run NAME COMMAND...
  local name="$1"; shift
  if "$@" >"$out" 2>&1; then
    echo "PASS  $name"; pass=$((pass + 1))
  else
    echo "FAIL  $name"; sed 's/^/      /' "$out" | tail -n 25; fail=$((fail + 1))
  fi
}
skip() { echo "SKIP  $1 ($2)"; skip=$((skip + 1)); }

for s in pii_guard first_use_check stop_check worker_guard log_check timeline bloat_check; do
  if [ -f "scripts/$s.py" ]; then run "$s self-test" python3 "scripts/$s.py" --test; fi  # absent: not in this tier
done
if [ -f scripts/drift.py ]; then run "drift self-test" python3 scripts/drift.py --test; fi  # kit only: projects have no sync tools
if [ -f scripts/git-hooks/pre-push ]; then run "pre-push self-test" scripts/git-hooks/pre-push --test; fi

if [ ! -f scripts/log_check.py ]; then
  :  # starter tier: no project log
elif grep -q '{{PROJECT_NAME}}' AGENTS.md 2>/dev/null && grep -q '{{PROJECT_NAME}}' docs/LOG.md 2>/dev/null; then
  skip "project log" "template placeholders: run first use"
elif [ -f docs/LOG.md ]; then
  run "project log" python3 scripts/log_check.py docs/LOG.md
else
  skip "project log" "no docs/LOG.md: the log lives in the place AGENTS.md Project rules names"
fi

if [ ! -f .pii-guard ]; then
  skip "personal-data scan" "no .pii-guard: guard off"
elif [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  skip "personal-data scan" "GitHub Actions: the pii-guard step scans with the base allow list"
else
  run "personal-data scan" python3 scripts/pii_guard.py --all
fi

if [ -f scripts/check.local.sh ]; then
  run "project checks (check.local.sh)" bash scripts/check.local.sh
else
  skip "project checks" "no scripts/check.local.sh: no project tests yet; AGENTS.md Delivery gates main"
fi

total=$((pass + fail + skip))
if [ "$fail" -eq 0 ]; then
  echo "CHECK PASS: $pass passed, $skip skipped, of $total"
else
  echo "CHECK FAIL: $fail failed, $pass passed, $skip skipped, of $total"
  exit 1
fi
