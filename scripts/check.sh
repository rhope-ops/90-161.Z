#!/usr/bin/env bash
# One check command for the repo (AGENTS.md "Commands": Test), in two lanes (.claude/skills/deliver/SKILL.md):
#   scripts/check.sh          full lane: everything. Before a merge, on a push to main (pre-push), in the pull-request Action.
#   scripts/check.sh --fast   fast lane: each push to another branch (pre-push). Self-tests only of the kit scripts that
#                             changed against origin/main, and scripts/check.local.sh gets --fast.
# The checks:
#   1. the self-test of each kit script present (--test; a starter project has fewer),
#   2. the rule caps and the paths AGENTS.md names, the lint of changed rule lines (WARN lines), and in the full lane
#      the conflict-check record for changed rule lines (scripts/bloat_check.py --rules [--gate]; full tier),
#   3. the project log check (full tier),
#   4. the personal-data scan of all tracked files (when .pii-guard exists; in GitHub Actions the pii-guard step does it;
#      with --no-pii the caller does it: the pre-push hook scans files and pushed commits in one run),
#   5. scripts/check.local.sh, when it exists: this project's own tests (SKIP when missing: the review gate in
#      .claude/skills/deliver/SKILL.md then guards main).
# The checks run in parallel: each one works on its own temporary files. CHECK_SERIAL=1 runs them one at a time.
# Prints one PASS/FAIL/SKIP line per check, the output of each failed check, a TIME line (wall time and the 3 slowest
# checks), a line that compares the times with the baselines in .bloat-audit.json (scripts/bloat_check.py --compare:
# the full lane and each step; the fast lane only its steps, as its total depends on what changed; a slowdown is a
# WARN line, never a failure) and "CHECK PASS" or "CHECK FAIL" last.
# --record (full lane only): after a pass, store this run's times as the new baselines (commit the change). Exit 0 only when no check failed. Needs bash, git and python3.
# Stamp: a lane that passes on a clean tree writes "<lane> <commit>" to .git/check-pass. With --cached, a run on the
# same commit and a clean tree passes at once (the full stamp covers both lanes). Never write the stamp by hand.
# Self-test (temporary repos, no network): scripts/check.sh --test
set -uo pipefail
self="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
[ "${1:-}" = "--test" ] && { selftest_main=1; } || selftest_main=0
# Git gives a hook GIT_DIR and friends (in a linked worktree they point at the real repo). The self-tests make
# temporary repos with "git init" and "git commit": with those variables set they would write into that repo.
# Unset them first, so the top folder is found from the current folder (a hook starts at the top of its worktree).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_IMPLICIT_WORK_TREE
cd "$(git rev-parse --show-toplevel)" || exit 1
[ -f scripts/check.sh ] || { echo "CHECK FAIL: $(pwd) is not the top folder of a repo with scripts/check.sh" >&2; exit 1; }

if [ "$selftest_main" = 1 ]; then
  # Each case runs this script in a small temporary repo: a fake kit script with a --test, and a check.local.sh that
  # records its argument. CHECK_IN_TEST stops the inner runs from starting this self-test again.
  # A failed mktemp must stop here: with an empty $t the cases below would write at the top of the file system.
  t="$(mktemp -d)" && [ -d "$t" ] || { echo "CHECK SELF-TEST FAIL: no temporary folder"; exit 1; }
  trap 'rm -rf "$t"' EXIT
  export CHECK_IN_TEST=1
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1  # the host's git config (signing, templates) must not matter
  unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT  # nor "git -c ..." on the command that started this run
  g() { git -C "$t/r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
  git init -q -b main "$t/r"; mkdir -p "$t/r/scripts"
  cp "$self" "$t/r/scripts/check.sh"
  # Like the real self-tests, the fake one makes a temporary repo and commits in it.
  cat > "$t/r/scripts/stop_check.py" <<'PY'
import subprocess, tempfile
with tempfile.TemporaryDirectory() as d:
    subprocess.run(["git", "init", "-q", d], check=True)
    subprocess.run(["git", "-C", d, "-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false",
                    "commit", "-q", "--allow-empty", "-m", "stray"], check=True)
print("fake self-test")
PY
  printf '%s\n' 'print("fake self-test")' > "$t/r/scripts/log_check.py"
  # A fake bloat_check.py: its --test and --rules pass; --compare writes its arguments down.
  printf '%s\n' 'import subprocess, sys' 'if "--compare" in sys.argv:' \
    '    d = subprocess.run(["git", "rev-parse", "--git-dir"], capture_output=True, text=True).stdout.strip()' \
    '    open(d + "/compare-args", "w").write("\n".join(sys.argv[2:]) + "\n"); print("TIME  baseline: fake")' \
    'if "--rules" in sys.argv:' '    print("WARN  fake lint" + (" gate" if "--gate" in sys.argv else ""))' > "$t/r/scripts/bloat_check.py"
  cp "$t/r/scripts/log_check.py" "$t/r/scripts/timeline.py"
  printf '%s\n' 'echo "arg=${1:-none}" > "$(git rev-parse --git-dir)/local-arg"' '[ ! -f fail.flag ]' > "$t/r/scripts/check.local.sh"
  g add -A; g commit -q -m a; g update-ref refs/remotes/origin/main HEAD
  fails=0
  ok() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got: $2; want: $3)"; fails=1; fi; }
  c() { (cd "$t/r" && bash scripts/check.sh "$@" 2>&1); }
  out="$(c)"; ok "full lane passes" "$?" 0
  ok "full lane runs the self-test of an unchanged script" "$(printf '%s\n' "$out" | grep -c '^PASS  stop_check self-test')" 1
  ok "full lane: check.local.sh gets no argument" "$(cat "$t/r/.git/local-arg")" "arg=none"
  ok "a pass on a clean tree writes the full stamp" "$(cut -d' ' -f1 "$t/r/.git/check-pass")" full
  ok "a TIME line names the lane" "$(printf '%s\n' "$out" | grep -c '^TIME  full lane ')" 1
  ok "the full lane compares its wall time with the baseline" "$(grep -c '^check=' "$t/r/.git/compare-args")" 1
  ok "the full lane compares each step" "$(grep -c '^check:stop_check self-test=' "$t/r/.git/compare-args")" 1
  ok "the comparison line is printed" "$(printf '%s\n' "$out" | grep -c '^TIME  baseline: fake')" 1
  ok "a passing check shows its WARN lines; the full lane gates" "$(printf '%s\n' "$out" | grep -c '^      WARN  fake lint gate$')" 1
  ok "no --record unless asked" "$(grep -c -- '--record' "$t/r/.git/compare-args")" 0
  c --record >/dev/null; ok "--record after a full pass" "$(grep -c -- '--record' "$t/r/.git/compare-args")" 1
  c --fast --record >/dev/null 2>&1; ok "--record with --fast exits 2" "$?" 2
  ok "--cached uses the full stamp" "$(c --cached | head -n 1 | cut -c1-18)" "CHECK PASS (cached"
  ok "--cached --fast uses the full stamp" "$(c --cached --fast | head -n 1 | cut -c1-18)" "CHECK PASS (cached"
  echo x > "$t/r/new.txt"
  ok "a dirty tree is not cached" "$(c --cached | grep -c 'cached')" 0
  ok "a run on a dirty tree writes no new stamp" "$( [ -f "$t/r/.git/check-pass" ] && cut -d' ' -f2 "$t/r/.git/check-pass")" "$(g rev-parse HEAD)"
  g add -A; g commit -q -m b
  ok "a new commit is not cached" "$(c --cached --fast | grep -c 'cached')" 0
  ok "fast lane: check.local.sh gets --fast" "$(cat "$t/r/.git/local-arg")" "arg=--fast"
  ok "fast lane skips the self-test of an unchanged script" "$(c --fast | grep -c 'stop_check self-test')" 0
  ok "the fast lane does not gate" "$(c --fast | grep -c '^      WARN  fake lint$')" 1
  ok "the fast lane compares no wall time (it depends on what changed)" "$(grep -c '^check=' "$t/r/.git/compare-args")" 0
  ok "a fast stamp does not pass a full run" "$(c --cached | grep -c 'cached')" 0
  echo "# changed" >> "$t/r/scripts/stop_check.py"
  ok "fast lane runs the self-test of a changed script" "$(c --fast | grep -c '^PASS  stop_check self-test')" 1
  ok "fast lane skips timeline while log_check is unchanged" "$(c --fast | grep -c 'timeline self-test')" 0
  echo "# changed" >> "$t/r/scripts/log_check.py"
  ok "a change to log_check also runs the timeline self-test (it imports log_check)" "$(c --fast | grep -c '^PASS  timeline self-test')" 1
  g checkout -q scripts/log_check.py
  g commit -q -am c; rm -f "$t/r/.git/check-pass"
  c --fast --no-pii >/dev/null
  ok "--no-pii writes no stamp" "$( [ -f "$t/r/.git/check-pass" ] && echo stamp || echo none)" none
  c >/dev/null; touch "$t/r/fail.flag"
  c >/dev/null; ok "a failing check fails the run" "$?" 1
  ok "a failed run removes the stamp" "$( [ -f "$t/r/.git/check-pass" ] && echo stamp || echo none)" none
  rm "$t/r/fail.flag"
  g update-ref -d refs/remotes/origin/main
  ok "no default branch ref: the fast lane runs every self-test" "$(c --fast | grep -c '^PASS  stop_check self-test')" 1
  c --bogus >/dev/null 2>&1; ok "an unknown flag exits 2" "$?" 2
  # A git error is not a clean tree: with a broken index, a stamp for this commit must not be used.
  c >/dev/null; ok "a stamp exists before the index breaks" "$(cut -d' ' -f2 "$t/r/.git/check-pass")" "$(g rev-parse HEAD)"
  cp "$t/r/.git/index" "$t/index.bak"; echo broken > "$t/r/.git/index"
  ok "a git error is not treated as a clean tree" "$(c --cached 2>&1 | grep -c 'cached')" 0
  cp "$t/index.bak" "$t/r/.git/index"
  # Inside a hook git sets GIT_DIR (in a linked worktree it points at the real repo): the self-tests' "git init"
  # and "git commit" must not write into that repo.
  o="$t/other"; git init -q -b main "$o"
  git -C "$o" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m base
  want="$(git -C "$o" rev-parse HEAD) $(git -C "$o" rev-list --count HEAD) $(git -C "$o" config --get core.bare)"
  (cd "$t/r" && GIT_DIR="$o/.git" bash scripts/check.sh >/dev/null 2>&1)
  ok "a run with GIT_DIR set leaves that repo unchanged" "$(git -C "$o" rev-parse HEAD) $(git -C "$o" rev-list --count HEAD) $(git -C "$o" config --get core.bare)" "$want"
  mkdir -p "$t/r/sub"
  ok "a run from a subfolder with GIT_DIR set still runs the checks" "$(cd "$t/r/sub" && GIT_DIR="$t/r/.git" bash ../scripts/check.sh 2>&1 | grep -c '^PASS  stop_check self-test')" 1
  # The check-in self-test must not delete the folder it runs in when it cannot make a temporary folder.
  if [ -f "$(dirname "$self")/session_checkin.sh" ]; then
    mkdir -p "$t/keep"; cp "$(dirname "$self")/session_checkin.sh" "$t/keep/"; touch "$t/keep/marker"
    (cd "$t/keep" && TMPDIR="$t/no-such-dir" bash session_checkin.sh --test >/dev/null 2>&1)
    ok "check-in self-test with no temporary folder: fails, deletes nothing" "$?:$( [ -f "$t/keep/marker" ] && echo kept)" "1:kept"
  fi
  # With no temporary folder, check.sh stops at once (a real run and this self-test). A fake mktemp names a folder
  # that does not exist inside $t: if the stop ever breaks, the writes fail there, never outside this test's folder.
  mkdir -p "$t/fakebin"; printf '#!/bin/sh\necho "%s"\n' "$t/missing" > "$t/fakebin/mktemp"; chmod +x "$t/fakebin/mktemp"
  ok "a real run with no temporary folder fails at once" "$( { cd "$t/r" && PATH="$t/fakebin:$PATH" bash scripts/check.sh 2>&1; echo "rc=$?"; } | tail -n 2)" "CHECK FAIL: no temporary folder (mktemp failed)
rc=1"
  ok "the self-test with no temporary folder fails at once" "$( { cd "$t/r" && PATH="$t/fakebin:$PATH" bash scripts/check.sh --test 2>&1; echo "rc=$?"; } | tail -n 2)" "CHECK SELF-TEST FAIL: no temporary folder
rc=1"
  [ "$fails" = 0 ] && echo "CHECK SELF-TEST PASS" || { echo "CHECK SELF-TEST FAIL"; exit 1; }
  exit 0
fi

lane=full cached=0 pii=1 record=0
for a in "$@"; do
  case "$a" in
    --fast) lane=fast ;;
    --cached) cached=1 ;;
    --no-pii) pii=0 ;;
    --record) record=1 ;;
    *) echo "usage: scripts/check.sh [--fast] [--cached] [--no-pii] [--record]" >&2; exit 2 ;;
  esac
done
[ "$record" = 1 ] && [ "$lane" = fast ] && { echo "usage: --record needs the full lane" >&2; exit 2; }

gitdir="$(git rev-parse --git-dir)"
stamp="$gitdir/check-pass"
head="$(git rev-parse HEAD 2>/dev/null || echo none)"
clean() { local s; s="$(git status --porcelain 2>/dev/null)" || return 1; [ -z "$s" ]; }  # a git error is not "clean"
if [ "$cached" = 1 ] && [ -f "$stamp" ] && clean; then
  read -r s_lane s_head <"$stamp" || true
  if [ "${s_head:-}" = "$head" ] && { [ "${s_lane:-}" = full ] || [ "$lane" = fast ]; }; then
    echo "CHECK PASS (cached: the $s_lane lane passed on ${head:0:7}, clean tree)"
    exit 0
  fi
fi

now() {  # microseconds; whole seconds where bash has no EPOCHREALTIME (bash 3)
  if [ -n "${EPOCHREALTIME:-}" ]; then printf '%s' "${EPOCHREALTIME/[.,]/}"; else printf '%s000000' "$(date +%s)"; fi
}
secs() { printf '%d.%d' $(($1 / 1000000)) $((($1 % 1000000) / 100000)); }

# Fast lane: the files that differ from the merge base with the default branch, uncommitted and untracked ones included.
changed="*all*"
if [ "$lane" = fast ]; then
  for r in origin/main origin/master; do
    if base="$(git merge-base HEAD "$r" 2>/dev/null)"; then
      changed="$( { git diff --name-only "$base"; git ls-files -o --exclude-standard; } 2>/dev/null | sort -u)"
      break
    fi
  done
fi
touched() {  # true when the lane is full, the base is unknown, or one of the named files (or this script) changed
  [ "$changed" = "*all*" ] && return 0
  local p
  for p in scripts/check.sh "$@"; do printf '%s\n' "$changed" | grep -qxF -- "$p" && return 0; done
  return 1
}

tmp="$(mktemp -d)" && [ -d "$tmp" ] || { echo "CHECK FAIL: no temporary folder (mktemp failed)"; exit 1; }
trap 'rm -rf "$tmp"' EXIT
n=0 pass=0 fail=0 skip=0 untested=0
names=()
t0="$(now)"

run() {  # run NAME COMMAND...: start the check in the background; results are collected below
  local name="$1" i; shift
  n=$((n + 1)); i=$n; names[i]="$name"
  (
    s="$(now)"
    "$@" >"$tmp/$i.out" 2>&1; rc=$?
    echo "$rc $(( $(now) - s ))" >"$tmp/$i.rc"
  ) &
  [ "${CHECK_SERIAL:-}" = 1 ] && wait
  return 0
}
skips=()
skip() { skips+=("SKIP  $1 ($2)"); skip=$((skip + 1)); }
selftest() {  # selftest NAME FILE [MORE FILES IT DEPENDS ON...] -- COMMAND...
  local name="$1" file="$2" deps=(); shift
  while [ "$1" != "--" ]; do deps+=("$1"); shift; done; shift
  [ -f "$file" ] || return 0  # absent: not in this tier
  if touched "${deps[@]}"; then run "$name self-test" "$@"; else untested=$((untested + 1)); fi
}

for s in stop_check worker_guard log_check bloat_check; do
  selftest "$s" "scripts/$s.py" -- python3 "scripts/$s.py" --test
done
selftest timeline scripts/timeline.py scripts/log_check.py -- python3 scripts/timeline.py --test  # it imports log_check
selftest pii_guard scripts/pii_guard.py -- python3 scripts/pii_guard.py --test
selftest first_use_check scripts/first_use_check.py scripts/pii_guard.py -- python3 scripts/first_use_check.py --test
# Kit only: projects have no sync tools. The drift self-test reads the kit's AGENTS.md and stop_check.py.
selftest drift scripts/drift.py scripts/sync_baseline.py AGENTS.md scripts/stop_check.py -- python3 scripts/drift.py --test
selftest pre-push scripts/git-hooks/pre-push -- scripts/git-hooks/pre-push --test
selftest session_checkin scripts/session_checkin.sh -- bash scripts/session_checkin.sh --test
# This script's own self-test (not inside that self-test: it runs this script in temporary repos).
[ -z "${CHECK_IN_TEST:-}" ] && selftest check.sh scripts/check.sh -- bash scripts/check.sh --test
[ "$untested" -gt 0 ] && skip "$untested self-tests" "fast lane: those scripts did not change; the full lane runs them"

# Rule caps, paths, the lint of changed rule lines, and (full lane) the conflict-check record for changed rule lines.
if [ -f scripts/bloat_check.py ]; then
  if [ "$lane" = full ]; then run "rule caps and pointers" python3 scripts/bloat_check.py --rules --gate
  else run "rule caps and pointers" python3 scripts/bloat_check.py --rules; fi
fi

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
elif [ "$pii" = 0 ]; then
  skip "personal-data scan" "the pre-push hook scans the files and the pushed commits next"
else
  run "personal-data scan" python3 scripts/pii_guard.py --all
fi

if [ -f scripts/check.local.sh ]; then
  if [ "$lane" = fast ]; then
    run "project checks (check.local.sh --fast)" bash scripts/check.local.sh --fast
  else
    run "project checks (check.local.sh)" bash scripts/check.local.sh
  fi
else
  skip "project checks" "no scripts/check.local.sh: no project tests yet; the review gate guards main (.claude/skills/deliver/SKILL.md)"
fi

wait
times="" items=()
for ((i = 1; i <= n; i++)); do
  rc=1 us=0
  [ -f "$tmp/$i.rc" ] && read -r rc us <"$tmp/$i.rc"
  if [ "$rc" = 0 ]; then
    echo "PASS  ${names[i]}"; pass=$((pass + 1))
    grep '^WARN ' "$tmp/$i.out" 2>/dev/null | sed 's/^/      /'  # a passing check can still warn (rule lint, conflict check)
  else
    echo "FAIL  ${names[i]}"; sed 's/^/      /' "$tmp/$i.out" 2>/dev/null | tail -n 25; fail=$((fail + 1))
  fi
  times+="$us ${names[i]}"$'\n'
  items+=("check:${names[i]}=$(secs "$us")")
done
[ "${#skips[@]}" -gt 0 ] && printf '%s\n' "${skips[@]}"

slow="$(printf '%s' "$times" | sort -rn | head -n 3 | while read -r us name; do printf '%s %s s, ' "$name" "$(secs "$us")"; done)"
wall=$(( $(now) - t0 ))
timeline="TIME  $lane lane $(secs "$wall") s wall; slowest: ${slow%, }"
echo "$timeline"
[ "$lane" = full ] && items=("check=$(secs "$wall")" ${items[@]+"${items[@]}"})
if [ -f scripts/bloat_check.py ] && [ "${#items[@]}" -gt 0 ]; then  # warn only: .claude/skills/efficiency/SKILL.md
  rec=""; [ "$record" = 1 ] && [ "$fail" -eq 0 ] && rec=--record
  python3 scripts/bloat_check.py --compare "${items[@]}" $rec 2>&1 | tail -n 1
fi
echo "$timeline ($(date '+%Y-%m-%d %H:%M'), ${head:0:7})" >"$gitdir/check-last" 2>/dev/null || true

total=$((pass + fail + skip))
if [ "$fail" -eq 0 ]; then
  # The stamp says "every check of this lane passed here": not written when the caller scans personal data itself.
  if [ "$pii" = 1 ] && [ "$head" = "$(git rev-parse HEAD 2>/dev/null)" ] && clean; then echo "$lane $head" >"$stamp"; fi
  echo "CHECK PASS: $pass passed, $skip skipped, of $total"
else
  rm -f "$stamp"
  echo "CHECK FAIL: $fail failed, $pass passed, $skip skipped, of $total"
  exit 1
fi
