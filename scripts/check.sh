#!/usr/bin/env bash
# One check command for the repo (AGENTS.md "Commands": Test): the one front door of every check and guard.
# Prevents: a change that reaches main or a pull request with a check not run, or a check that fails and is not seen.
# Two lanes (.claude/skills/deliver/SKILL.md):
#   scripts/check.sh          full lane: everything. Before a merge, on a push to main (pre-push), in the pull-request Action (public repos).
#   scripts/check.sh --fast   fast lane: each push to another branch (pre-push). Self-tests only of the kit scripts that
#                             changed against origin/main, and scripts/check.local.sh gets --fast.
# The content check alone (scripts/check_content.py: personal data, secrets, the Maintainer's terms, blocked files):
#   scripts/check.sh --content ARGS...   for example --all, --stdin, --range A..B or file names
#   scripts/check.sh --status            the word lists (counts and fingerprints, never the words) and the tier
#   scripts/check.sh --hook              the Claude Code PreToolUse hook (.claude/settings.json); any error blocks
# The checks:
#   1. the self-test of each kit script present (--test; a starter project has fewer), the self-test of a project's
#      own extension files when they have one (scripts/check_content_local.py and scripts/code_standard_gate.py: the
#      file names --test; the full lane always, the fast lane when the file or a file it extends changed), and the
#      code standard (scripts/code_standard.py, when .check.state.json holds its baseline; settings: the `code-` lines of .check),
#   1b. the Python parse, line length and file size: ruff and pylint (ruff.toml, .pylintrc; a SKIP line when a linter is missing),
#   1c. shellcheck on the shell files the code standard covers: findings are WARN lines and never fail (a SKIP line when it is missing),
#   1d. bandit on scripts/ (full lane; the scan of .github/workflows/security.yml; a SKIP line when it is missing),
#   1e. the kit package (scripts/kit_package.py --verify), when .check.lock lists a script that git does not track
#       (scripts/check.sh --kit-install installs it at the lock commit),
#   2. the rule caps and the paths AGENTS.md names, the lint of changed rule lines (WARN lines), and in the full lane
#      the conflict-check record for changed rule lines (scripts/bloat_check.py --rules [--gate]; full tier),
#   3. the project log check (full tier),
#   4. the content check of all tracked files (when the settings file .check exists; in GitHub Actions the "checks"
#      workflow's content step does it; with --no-content the caller does it: the pre-push hook scans files and pushed
#      commits in one run),
#   5. the fleet format (scripts/fleet_harvest.py --check), when .check has the line `fleet: on`,
#   5b. the site's shared parts (scripts/build_site.py --check: index.html says what README.md's site sections say;
#      a project's own kinds in scripts/build_site_local.py), when README.md has a `<!-- site:` mark,
#   5c. the steps a person follows (scripts/check_instructions.py), both lanes, when .check has `audit-instructions:`
#      lines (else on README.md); a project's own module: scripts/check_instructions_local.py,
#   6. scripts/check.local.sh, when it exists: this project's own tests (SKIP when missing: the review gate in
#      .claude/skills/deliver/SKILL.md then guards main).
# The checks run in parallel: each one works on its own temporary files. CHECK_SERIAL=1 runs them one at a time.
# Prints one PASS/FAIL/SKIP line per check, the output of each failed check, a TIME line (wall time and the 3 slowest
# checks), a line that compares the times with the baselines in .check.state.json (scripts/bloat_check.py --compare:
# the full lane and each step; the fast lane only its steps, as its total depends on what changed; a slowdown is a
# WARN line, never a failure) and "CHECK PASS" or "CHECK FAIL" last.
# --record (full lane only): after a pass, store this run's times as the new baselines (commit the change).
# Exit 0 only when no check failed. Needs bash, git and python3.
# Network: none itself; a project's scripts/check.local.sh may use the network for its own tests.
# Writes: .git/check-pass and .git/check-last (the stamp and the last TIME line); with --record the time baselines in
#   .check.state.json; temporary folders.
# Credentials: none; the content check reads the word lists from an environment variable or a file (scripts/check_content.py).
# Stamp: a lane that passes on a clean tree writes "<lane> <commit>" to .git/check-pass. With --cached, a run on the
# same commit and a clean tree passes at once (the full stamp covers both lanes). Never write the stamp by hand.
# Self-test (temporary repos, no network): scripts/check.sh --test
set -uo pipefail
self="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
# The content check's own modes: before any "cd", so they work from any folder (the hook also runs outside a repo).
case "${1:-}" in
  --hook) python3 "$(dirname "$self")/check_content.py" --hook && exit 0; exit 2 ;;  # any failure blocks the tool call
  --status) exec python3 "$(dirname "$self")/check_content.py" --status ;;
  --content) shift; exec python3 "$(dirname "$self")/check_content.py" "$@" ;;
esac
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
  # git in the test repo, with a fixed author and no signing
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
  # ok NAME GOT WANT: print ok or FAIL, and remember a failure
  ok() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got: $2; want: $3)"; fails=1; fi; }
  # run the copied check.sh in the test repo with these arguments; stderr joins stdout
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
  c --fast --no-content >/dev/null
  ok "--no-content writes no stamp" "$( [ -f "$t/r/.git/check-pass" ] && echo stamp || echo none)" none
  c >/dev/null; touch "$t/r/fail.flag"
  c >/dev/null; ok "a failing check fails the run" "$?" 1
  ok "a failed run removes the stamp" "$( [ -f "$t/r/.git/check-pass" ] && echo stamp || echo none)" none
  rm "$t/r/fail.flag"
  g update-ref -d refs/remotes/origin/main
  ok "no default branch ref: the fast lane runs every self-test" "$(c --fast | grep -c '^PASS  stop_check self-test')" 1
  c --bogus >/dev/null 2>&1; ok "an unknown flag exits 2" "$?" 2
  # The code standard: skipped while nothing holds a baseline; run when the default branch holds one, also a large
  # one (over 64 KB), although the state file of the work tree is gone.
  printf '%s\n' 'print("CODE-STANDARD fake")' > "$t/r/scripts/code_standard.py"
  echo '{"timings": {"check": {"steps": {"code standard": 1}}}}' > "$t/r/.check.state.json"
  g add -A; g commit -q -m "state without a baseline"; g update-ref refs/remotes/origin/main HEAD
  ok "no baseline here or on the default branch: the code standard is skipped" "$(c | grep -c '^SKIP  code standard')" 1
  python3 -c 'import json; print(json.dumps({"code_standard": {"debt": {"length": {"f%d.py::main" % i: 99 for i in range(4000)}}}}, indent=1))' > "$t/r/.check.state.json"
  g add -A; g commit -q -m "a large baseline"; g update-ref refs/remotes/origin/main HEAD
  rm "$t/r/.check.state.json"
  ok "a large baseline on the default branch, state file deleted: the code standard runs" "$(c | grep -c '^PASS  code standard$')" 1
  g checkout -q .check.state.json; g update-ref -d refs/remotes/origin/main
  # The Python lint (ruff and pylint): no config files, no step; with them and a linter missing, a SKIP line that names the install, never a silent pass.
  # The PATH of the case puts, in place of each folder that holds ruff, pylint, shellcheck or bandit, a folder of links to its
  # other programs (a runner can have shellcheck in /usr/bin, next to bash and git).
  nolint=""; i=0
  while IFS= read -r d; do
    if [ -x "$d/ruff" ] || [ -x "$d/pylint" ] || [ -x "$d/shellcheck" ] || [ -x "$d/bandit" ]; then
      i=$((i+1)); mkdir -p "$t/nolint/$i"
      for f in "$d"/*; do case "${f##*/}" in ruff|pylint|shellcheck|bandit) ;; *) [ -x "$f" ] && ln -s "$f" "$t/nolint/$i/";; esac; done
      d="$t/nolint/$i"
    fi
    nolint+="${nolint:+:}$d"
  done < <(tr ':' '\n' <<<"$PATH")
  ok "no ruff.toml and .pylintrc: no Python lint step" "$(c | grep -c 'python lint')" 0
  touch "$t/r/ruff.toml" "$t/r/.pylintrc"
  ok "a missing linter is a SKIP line that names the install" \
    "$(cd "$t/r" && PATH="$nolint" bash scripts/check.sh 2>&1 | grep -c '^SKIP  python lint (ruff or pylint is missing: pip install ruff==0.17.6 pylint==4.1.4)$')" 1
  rm "$t/r/ruff.toml" "$t/r/.pylintrc"
  # The shell lint: a missing tool is a SKIP line that names the install; findings are WARN lines and the step passes.
  ok "a missing shellcheck is a SKIP line that names the install" \
    "$(cd "$t/r" && PATH="$nolint" bash scripts/check.sh 2>&1 | grep -c '^SKIP  shellcheck (shellcheck is missing: pip install shellcheck-py==0.9.0.6)$')" 1
  # bandit: full lane only; a missing bandit is a SKIP line that names the install.
  ok "a missing bandit is a SKIP line that names the install (full lane)" \
    "$(cd "$t/r" && PATH="$nolint" bash scripts/check.sh 2>&1 | grep -c '^SKIP  bandit (bandit is missing: pip install bandit==1.9.4)$')" 1
  ok "the fast lane runs no bandit" "$(cd "$t/r" && PATH="$nolint" bash scripts/check.sh --fast 2>&1 | grep -c 'bandit')" 0
  if command -v shellcheck >/dev/null; then
    printf '%s\n' '#!/bin/bash' 'echo $1' > "$t/r/bad.sh"; printf '%s\n' 'import sys' 'sys.stdout.write("bad.sh\0" if "--shell-files" in sys.argv else "")' > "$t/r/scripts/code_standard.py"
    out="$(c)"; ok "a shellcheck finding is a WARN line" "$(printf '%s\n' "$out" | grep -c '^      WARN  bad.sh:2:.*SC2086')" 1
    ok "a finding does not fail the step" "$(printf '%s\n' "$out" | grep -c '^PASS  shellcheck$')" 1
    ok "the run with a finding exits 0" "$(cd "$t/r" && bash scripts/check.sh >/dev/null 2>&1; echo $?)" 0
    rm "$t/r/bad.sh"
  else echo "SKIP the shellcheck WARN cases: shellcheck is not installed here"; fi
  printf '%s\n' 'print("CODE-STANDARD fake")' > "$t/r/scripts/code_standard.py"
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
  # nt ARGS...: run the copied check.sh with the fake mktemp; print its last line and its exit code
  nt() { { cd "$t/r" && PATH="$t/fakebin:$PATH" bash scripts/check.sh "$@" 2>&1; echo "rc=$?"; } | tail -n 2; }
  ok "a real run with no temporary folder fails at once" "$(nt)" "CHECK FAIL: no temporary folder (mktemp failed)
rc=1"
  ok "the self-test with no temporary folder fails at once" "$(nt --test)" "CHECK SELF-TEST FAIL: no temporary folder
rc=1"
  # A project's own extension files: the self-test of each runs when the file names --test (full lane: always; fast
  # lane: when the file, or a kit file it extends, changed); a file with no self-test is a SKIP line.
  g update-ref refs/remotes/origin/main HEAD
  printf '%s\n' 'import sys' 'if "--test" in sys.argv:' '    print("local self-test")' > "$t/r/scripts/check_content_local.py"
  printf '%s\n' '# --test is named only in this comment' 'print("a gate with no self-test")' > "$t/r/scripts/code_standard_gate.py"
  out="$(c)"
  ok "full lane: the self-test of a project's own finders runs" "$(printf '%s\n' "$out" | grep -c '^PASS  check_content_local self-test')" 1
  ok "an extension file with no self-test is a SKIP line" "$(printf '%s\n' "$out" | grep -c '^SKIP  code_standard_gate self-test')" 1
  ok "fast lane: a new extension file runs its self-test" "$(c --fast | grep -c '^PASS  check_content_local self-test')" 1
  g add -A; g commit -q -m "extension files"; g update-ref refs/remotes/origin/main HEAD
  ok "fast lane: an unchanged extension file is not tested again" "$(c --fast | grep -c 'check_content_local self-test')" 0
  echo "# changed" >> "$t/r/scripts/check_content_scan.py"
  ok "fast lane: a change to the kit file it extends runs it" "$(c --fast | grep -c '^PASS  check_content_local self-test')" 1
  printf '%s\n' 'import sys' 'if "--test" in sys.argv:' '    raise SystemExit(1)' > "$t/r/scripts/check_content_local.py"
  c >/dev/null; ok "a failing self-test of an extension file fails the run" "$?" 1
  # Package mode (scripts/kit_package.py): a lock-listed script that git does not track needs the installed package.
  printf '%s\n' '{"commit": "c0ffee", "files": {"scripts/gone.py": "x"}}' > "$t/r/.check.lock"
  nopkg="$t/nopkg:$(dirname "$(command -v python3)"):$(dirname "$(command -v git)"):/usr/bin:/bin"  # a PATH with no archimedes-kit
  out="$(cd "$t/r" && PATH="$nopkg" bash scripts/check.sh 2>&1)"
  ok "package mode with no package fails and names the install" "$(printf '%s\n' "$out" | grep -c -e '^FAIL  kit package' -e 'install: scripts/check.sh --kit-install')" 2
  printf '%s\n' '{"commit": "c0ffee"}' > "$t/r/.check.lock"
  ok "a lock with no file list fails the package step, never skips it" "$(cd "$t/r" && PATH="$nopkg" bash scripts/check.sh 2>&1 | grep -c '^FAIL  kit package')" 1
  printf '%s\n' '{"commit": "c0ffee", "files": {"scripts/gone.py": "x"}}' > "$t/r/.check.lock"
  mkdir -p "$t/pkgbin"; printf '#!/bin/sh\necho "KIT PACKAGE PASS: $*"\n' > "$t/pkgbin/archimedes-kit"; chmod +x "$t/pkgbin/archimedes-kit"
  ok "package mode runs the package's verify" "$(cd "$t/r" && PATH="$t/pkgbin:$PATH" bash scripts/check.sh 2>&1 | grep -c '^PASS  kit package')" 1
  # --kit-install under PEP 668: a fake python3 whose pip refuses the system Python (or fails with $PIPERR).
  mkdir -p "$t/pep668"
  cat >"$t/pep668/python3" <<EOF
#!/bin/sh
case "\$*" in
  *"-m pip install"*) echo "\$*" >>"$t/pip.log"; case "\$*" in *--user*) exit 0;; esac
    echo "error: \${PIPERR:-externally-managed-environment}" >&2; exit 1;;
  *"-m archimedes_kit.kit_package"*) shift 2; echo "KIT PACKAGE PASS: module \$*"; exit 0;;
esac
exec $(command -v python3) "\$@"
EOF
  chmod +x "$t/pep668/python3"; nokit="$t/pep668:$(dirname "$(command -v git)"):/usr/bin:/bin"  # no archimedes-kit command
  out="$(cd "$t/r" && PATH="$nokit" bash scripts/check.sh --kit-install 2>&1)"
  ok "--kit-install: pip refused by PEP 668 makes a user install" "$(grep -c -- '--user --break-system-packages' "$t/pip.log")" 1
  ok "--kit-install: with no archimedes-kit command the package module writes the scripts" \
    "$(printf '%s\n' "$out" | grep -c '^KIT PACKAGE PASS: module --install$')" 1
  ok "the package step finds the package module with no archimedes-kit command" \
    "$(cd "$t/r" && PATH="$nokit" bash scripts/check.sh 2>&1 | grep -c '^PASS  kit package')" 1
  rm "$t/pip.log"; out="$(cd "$t/r" && PIPERR="no network" PATH="$nokit" bash scripts/check.sh --kit-install 2>&1; echo "rc=$?")"
  ok "--kit-install: another pip error fails, shows it and makes no user install" "$(printf '%s\n' "$out" | grep -c -e '^error: no network$' -e '^rc=1$')$(grep -c -- '--user' "$t/pip.log")" 20
  g add -f .check.lock; printf 'x\n' > "$t/r/scripts/gone.py"; g add -f scripts/gone.py
  ok "with each locked script tracked there is no package step" "$(c | grep -c 'kit package')" 0
  ok "with each locked script tracked --kit-install does nothing" "$(c --kit-install; echo "rc=$?")" "KIT PACKAGE: not used (each kit script in .check.lock is tracked)
rc=0"
  [ "$fails" = 0 ] && echo "CHECK SELF-TEST PASS" || { echo "CHECK SELF-TEST FAIL"; exit 1; }
  exit 0
fi

lane=full cached=0 pii=1 record=0 kitinstall=0
for a in "$@"; do
  case "$a" in
    --fast) lane=fast ;;
    --cached) cached=1 ;;
    --no-content) pii=0 ;;
    --record) record=1 ;;
    --kit-install) kitinstall=1 ;;
    *) echo "usage: scripts/check.sh [--fast] [--cached] [--no-content] [--record] | --kit-install | --content ARGS... | --status | --hook" >&2; exit 2 ;;
  esac
done
[ "$record" = 1 ] && [ "$lane" = fast ] && { echo "usage: --record needs the full lane" >&2; exit 2; }

gitdir="$(git rev-parse --git-dir)"
stamp="$gitdir/check-pass"
head="$(git rev-parse HEAD 2>/dev/null || echo none)"
# true when the work tree has no changes; a git error is not "clean"
clean() { local s; s="$(git status --porcelain 2>/dev/null)" || return 1; [ -z "$s" ]; }
# Package mode (scripts/kit_package.py): .check.lock lists a script that git does not track. A lock that does not parse
# counts as package mode, so the package step runs and fails. git status cannot see the untracked kit scripts, so no cached pass.
pkg_mode() {
  [ -f .check.lock ] && python3 -c 'import json, subprocess, sys
try: f = [k for k in json.load(open(".check.lock"))["files"] if k.startswith("scripts/")]
except Exception: sys.exit(0)
sys.exit(0 if set(f) - set(subprocess.run(["git", "ls-files", "-z", "--"] + f, capture_output=True, text=True).stdout.split("\0")) else 1)'
}
# The kit package's command: archimedes-kit, else its module (a user install can put the command off PATH).
kit() { if command -v archimedes-kit >/dev/null; then archimedes-kit "$@"; else python3 -m archimedes_kit.kit_package "$@"; fi; }
# --kit-install: in package mode, install the kit package at the lock commit and write the kit scripts (the CI step, the
# SessionStart hook at startup, kit-update and a setup script that calls it use it: one home for the install command); else nothing.
if [ "$kitinstall" = 1 ]; then
  pkg_mode || { echo "KIT PACKAGE: not used (each kit script in .check.lock is tracked)"; exit 0; }
  c="$(python3 -c 'import json; print(json.load(open(".check.lock"))["commit"])')" || exit 1
  u="git+https://github.com/rhope-ops/archimedes_lever@$c"
  if ! o="$(python3 -m pip install -q --force-reinstall "$u" 2>&1)"; then
    # PEP 668: a system Python that refuses pip outside a venv gets a user install (many such systems have no venv module).
    grep -q 'externally-managed-environment' <<<"$o" || { printf '%s\n' "$o"; exit 1; }
    echo "KIT PACKAGE: pip refuses the system Python (PEP 668); it makes a user install"
    python3 -m pip install -q --user --break-system-packages --force-reinstall "$u" || exit 1
  fi
  kit --install
  exit $?
fi
if [ "$cached" = 1 ] && [ -f "$stamp" ] && clean && ! pkg_mode; then
  read -r s_lane s_head <"$stamp" || true
  if [ "${s_head:-}" = "$head" ] && { [ "${s_lane:-}" = full ] || [ "$lane" = fast ]; }; then
    echo "CHECK PASS (cached: the $s_lane lane passed on ${head:0:7}, clean tree)"
    exit 0
  fi
fi

# microseconds; whole seconds where bash has no EPOCHREALTIME (bash 3)
now() {
  if [ -n "${EPOCHREALTIME:-}" ]; then printf '%s' "${EPOCHREALTIME/[.,]/}"; else printf '%s000000' "$(date +%s)"; fi
}
# secs MICROSECONDS: print them as seconds with one decimal
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
# true when the lane is full, the base is unknown, or one of the named files (or this script) changed
touched() {
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

# run NAME COMMAND...: start the check in the background; results are collected below
run() {
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
# skip NAME REASON: record a SKIP line for the summary
skip() { skips+=("SKIP  $1 ($2)"); skip=$((skip + 1)); }
# selftest NAME FILE [MORE FILES IT DEPENDS ON...] -- COMMAND...: run a script's self-test when the lane needs it
selftest() {
  local name="$1" file="$2" deps=(); shift
  while [ "$1" != "--" ]; do deps+=("$1"); shift; done; shift
  [ -f "$file" ] || return 0  # absent: not in this tier
  if touched "${deps[@]}"; then run "$name self-test" "$@"; else untested=$((untested + 1)); fi
}

for s in stop_check worker_guard; do   # worker_guard --test also runs the scan self-test (worker_guard_scan.py)
  selftest "$s" "scripts/$s.py" scripts/worker_guard_scan.py scripts/worker_guard_scan_samples.json scripts/check_content_scan.py -- python3 "scripts/$s.py" --test
done
selftest log_check scripts/log_check.py scripts/log_check_plan.py -- python3 scripts/log_check.py --test
# A script whose cases or parts live in sibling modules lists them, so the fast lane reruns its self-test when they change.
selftest check_settings scripts/check_settings.py scripts/check_settings_test.py scripts/check_settings_read.py \
  scripts/build_site_html.py scripts/check_content_scan_settings.py scripts/check_content_scan_words.py -- python3 scripts/check_settings.py --test
selftest bloat_check scripts/bloat_check.py scripts/bloat_check_test.py scripts/bloat_check_skills.py scripts/bloat_check_rules.py \
  scripts/bloat_check_files.py scripts/bloat_check_timing.py scripts/bloat_check_test_rules.py \
  scripts/check_settings.py scripts/check_settings_read.py scripts/build_site_html.py \
    scripts/check_content_scan_settings.py scripts/check_content_scan_words.py -- python3 scripts/bloat_check.py --test
selftest token_log scripts/token_log.py scripts/token_log_rows.py scripts/token_log_report.py scripts/token_log_test.py \
  scripts/token_log_test_parts.py scripts/token_log_test_costs.py -- python3 scripts/token_log.py --test
selftest code_standard scripts/code_standard.py scripts/code_standard_test.py scripts/code_standard_docs.py \
  scripts/code_standard_parse.py scripts/check_settings.py scripts/check_settings_read.py \
    scripts/build_site_html.py scripts/check_content_scan_settings.py scripts/check_content_scan_words.py scripts/code_standard_rules.py \
  scripts/code_standard_ratchet.py scripts/code_standard_test_gate.py scripts/code_standard_test_docs.py -- python3 scripts/code_standard.py --test
selftest code_standard_strict scripts/code_standard_strict.py scripts/code_standard_strict_test.py scripts/code_standard.py \
  scripts/code_standard_test_gate.py scripts/check_settings.py scripts/check_settings_read.py scripts/build_site_html.py \
  scripts/check_content_scan_settings.py scripts/check_content_scan_words.py -- python3 scripts/code_standard_strict.py --test
selftest timeline scripts/timeline.py scripts/log_check.py -- python3 scripts/timeline.py --test  # it imports log_check
selftest check_content scripts/check_content.py scripts/check_content_scan.py scripts/check_content_finders.py \
  scripts/check_content_hook.py scripts/check_content_test.py scripts/check_content_test_blocks.py \
  scripts/check_content_test_local.py scripts/check_content_scan_settings.py scripts/check_content_scan_words.py scripts/check_content_test_cli.py -- python3 scripts/check_content.py --test
# A project's own extension files (the kit has none): each proves itself when it has a self-test. The deps are the
# file, its sibling files (for example its test cases: scripts/check_content_local_test.py) and the kit files it extends.
# extension NAME FILE [KIT FILES IT EXTENDS...]: run "python3 FILE --test" when its code names "--test" (not only a comment); else a SKIP line
extension() {
  local name="$1" file="$2"; shift 2
  [ -f "$file" ] || return 0
  if grep -Eq -- "^[^#]*[\"']--test[\"']" "$file"; then selftest "$name" "$file" "${file%.py}"*.py "$@" -- python3 "$file" --test
  else skip "$name self-test" "$file has no self-test (a file that names --test is run with it)"; fi
}
extension check_content_local scripts/check_content_local.py scripts/check_content_scan.py scripts/check_content_finders.py \
  scripts/check_content_scan_settings.py scripts/check_content_scan_words.py
extension code_standard_gate scripts/code_standard_gate.py scripts/code_standard.py scripts/code_standard_parse.py \
  scripts/code_standard_docs.py scripts/code_standard_rules.py scripts/code_standard_ratchet.py scripts/check_settings.py \
  scripts/check_settings_read.py scripts/build_site_html.py scripts/check_content_scan_settings.py scripts/check_content_scan_words.py
selftest check_instructions scripts/check_instructions.py scripts/check_instructions_test.py scripts/check_settings.py \
  scripts/check_settings_read.py scripts/build_site_html.py scripts/check_content_scan_settings.py scripts/check_content_scan_words.py \
  scripts/check_instructions_steps.py -- python3 scripts/check_instructions.py --test
extension check_instructions_local scripts/check_instructions_local.py scripts/check_instructions.py scripts/check_instructions_steps.py
selftest skill_use scripts/skill_use.py -- python3 scripts/skill_use.py --test
selftest fleet_harvest scripts/fleet_harvest.py scripts/fleet_harvest_test.py scripts/fleet_harvest_parse.py -- python3 scripts/fleet_harvest.py --test
selftest check_blocks scripts/check_blocks.py .claude/settings.json -- python3 scripts/check_blocks.py --test
selftest check_lock scripts/check_lock.py -- python3 scripts/check_lock.py --test
selftest fulcrum_palette scripts/fulcrum_palette.py docs/brand/fulcrum.json docs/brand/fulcrum.css -- python3 scripts/fulcrum_palette.py --test
selftest build_site scripts/build_site.py scripts/build_site_html.py -- python3 scripts/build_site.py --test
extension build_site_local scripts/build_site_local.py scripts/build_site.py scripts/build_site_html.py
selftest first_use_check scripts/first_use_check.py scripts/check_blocks.py scripts/check_content.py scripts/check_content_scan.py \
  scripts/check_content_scan_settings.py scripts/check_content_scan_words.py -- python3 scripts/first_use_check.py --test
# Kit only: projects have no sync tools. The drift self-test reads the kit's AGENTS.md and stop_check.py.
selftest drift scripts/drift.py scripts/sync_baseline.py scripts/sync_merge.py AGENTS.md scripts/stop_check.py \
  scripts/drift_test.py scripts/sync_baseline_repo.py scripts/sync_baseline_run.py scripts/sync_baseline_stop.py -- python3 scripts/drift.py --test
selftest pre-push scripts/git-hooks/pre-push -- scripts/git-hooks/pre-push --test
selftest session_checkin scripts/session_checkin.sh -- bash scripts/session_checkin.sh --test
[ -f kit.config.json ] && selftest kit_config scripts/kit_config.py kit.config.json -- python3 scripts/kit_config.py --test  # kit only
# Kit only: the command-line tests of the sync, drift, lock and bootstrap scripts (bootstrap deletes them in a project).
[ -f scripts/sync_baseline_cli_test.py ] && selftest cli_tests scripts/*_cli_test.py scripts/sync_baseline.py scripts/sync_baseline_repo.py \
  scripts/sync_baseline_run.py scripts/sync_baseline_stop.py scripts/sync_merge.py scripts/drift.py scripts/check_lock.py scripts/bootstrap.sh \
  scripts/check_blocks.py scripts/kit_config.py scripts/build_site_html.py \
  -- python3 -m unittest discover -s scripts -p '*_cli_test.py'
# This script's own self-test (not inside that self-test: it runs this script in temporary repos).
[ -z "${CHECK_IN_TEST:-}" ] && selftest check.sh scripts/check.sh -- bash scripts/check.sh --test
[ "$untested" -gt 0 ] && skip "$untested self-tests" "fast lane: those scripts did not change; the full lane runs them"

# The code standard (docs/code-standard.md), both lanes: it takes about 0.1 s. A repo that has not adopted it skips.
# Adopted: .check.state.json holds the "code_standard" baseline. A repo that still has the old .code-standard.json
# runs the check too: it fails there and names the migration, so the old limits are not dropped in silence.
# Also adopted: the default branch holds a baseline (a deleted state file must fail the check, not skip it).
# (The state file alone is no baseline: the time baselines and the audit write it too.)
on_main() {  # on_main FILE [TEXT]: the default branch has FILE (and FILE holds TEXT)
  local r t; for r in origin/main origin/master; do  # no pipe: with pipefail, grep -q closes a large file early
    t=$(git show "$r:$1" 2>/dev/null) && grep -q -- "${2:-}" <<<"$t" && return 0
  done; return 1
}
if [ -f scripts/code_standard.py ] && { grep -qs '"code_standard"' .check.state.json || [ -f .code-standard.json ] \
     || on_main .check.state.json '"code_standard"' || on_main .code-standard.json '"debt"'; }; then
  run "code standard" python3 scripts/code_standard.py
elif [ -f scripts/code_standard.py ]; then
  skip "code standard" "no code standard baseline in .check.state.json: adopt it with python3 scripts/code_standard.py --init (docs/code-standard.md)"
fi

# Python parse, line length and file size (docs/code-standard.md C4, C10): ruff and pylint, the configs ruff.toml and .pylintrc,
# the caps from .check. The parse and the line cap fail; the file size only warns. Never a silent pass: a missing linter is a SKIP line.
python_lint() {
  local caps cap max files=() long=() f rc=0
  caps=$(python3 -c 'import sys; sys.path.insert(0, "scripts"); import check_settings as s; c = s.code_config(".")["caps"]; print(c.get("max_line_chars") or 0, c["max_file_lines"])') || return 1
  read -r cap max <<<"$caps"
  # The files are the ones the code standard covers (include, exclude, generated). A file with a generated block is out of the line list.
  python3 scripts/code_standard.py --python-files all >"$tmp/lint.all" && python3 scripts/code_standard.py --python-files line >"$tmp/lint.line" || return 1
  while IFS= read -r -d '' f; do files+=("$f"); done <"$tmp/lint.all"
  while IFS= read -r -d '' f; do long+=("$f"); done <"$tmp/lint.line"
  [ "${#files[@]}" -gt 0 ] || return 0
  # An empty line list must not become "every file": ruff and pylint with no file name lint the whole folder.
  if [ "$cap" != 0 ] && [ "${#long[@]}" -gt 0 ]; then
    ruff check -q --config ruff.toml --select E501 --line-length "$cap" "${long[@]}" || rc=1
    pylint -sn -j 0 --rcfile .pylintrc --disable=all --enable=line-too-long --max-line-length "$cap" "${long[@]}" || rc=1
  fi
  ruff check -q --config ruff.toml "${files[@]}" || rc=1
  pylint -sn -j 0 --rcfile .pylintrc --disable=too-many-lines,line-too-long "${files[@]}" || rc=1
  pylint -sn -j 0 --rcfile .pylintrc --disable=syntax-error,line-too-long --max-module-lines "$max" \
    --msg-template='WARN  {path}: {msg}; a warning only (docs/code-standard.md C4)' "${files[@]}" | grep '^WARN '
  return $rc
}
if [ -f ruff.toml ] && [ -f .pylintrc ]; then
  if command -v ruff >/dev/null && command -v pylint >/dev/null; then run "python lint" python_lint
  else skip "python lint" "ruff or pylint is missing: pip install ruff==0.17.6 pylint==4.1.4"; fi
fi

# The shell lint on the files the code standard covers (the plan's decision 6: WARN first, so a finding never fails the step;
# a tool that fails to run is a WARN line too). Never a silent pass: a missing shellcheck is a SKIP line.
shell_lint() {
  local files=() f out rc
  python3 scripts/code_standard.py --shell-files >"$tmp/shell.all" || return 1
  while IFS= read -r -d '' f; do files+=("$f"); done <"$tmp/shell.all"
  [ "${#files[@]}" -gt 0 ] || return 0
  out="$(shellcheck -f gcc -- "${files[@]}" 2>&1)"; rc=$?
  [ "$rc" -le 1 ] || echo "WARN  shellcheck stopped with exit code $rc; a warning only"
  [ -z "$out" ] || printf '%s\n' "$out" | sed 's/^/WARN  /; s/$/; a warning only (shellcheck, docs\/code-standard.md)/'
  return 0
}
if [ -f scripts/code_standard.py ]; then
  if command -v shellcheck >/dev/null; then run "shellcheck" shell_lint
  else skip "shellcheck" "shellcheck is missing: pip install shellcheck-py==0.9.0.6"; fi
fi
# bandit (medium severity and higher) on scripts/, full lane only: the scan of .github/workflows/security.yml, which skips
# pull requests in a private repo. Never a silent pass: a missing bandit is a SKIP line that names the install.
if [ "$lane" = full ] && [ -d scripts ]; then
  if command -v bandit >/dev/null; then run "bandit" bandit -q -r scripts/ -ll
  else skip "bandit" "bandit is missing: pip install bandit==1.9.4"; fi
fi

# Rule caps, paths, the lint of changed rule lines, and (full lane) the conflict-check record for changed rule lines.
if [ -f scripts/bloat_check.py ]; then
  if [ "$lane" = full ]; then run "rule caps and pointers" python3 scripts/bloat_check.py --rules --gate
  else run "rule caps and pointers" python3 scripts/bloat_check.py --rules; fi
  run "skills well-formed" python3 scripts/bloat_check.py --skills
fi
# The git-safety and key-file deny rules (scripts/check_blocks.py) are all in .claude/settings.json.
[ -f scripts/check_blocks.py ] && [ -f .claude/settings.json ] && run "deny rules" python3 scripts/check_blocks.py --settings
# The kit files of a project are as the last sync wrote them (scripts/check_lock.py; the kit itself has no lock).
[ -f scripts/check_lock.py ] && [ -f .check.lock ] && run "kit lock" python3 scripts/check_lock.py --verify
# Package mode (scripts/kit_package.py, plan 2026-11-23 P3): .check.lock lists a script that git does not track, so the
# installed kit package must be at the lock commit and each such file must equal its copy (pkg_mode, above: from the lock
# alone, because with the package missing the untracked scripts are missing too, and their steps above skip).
kit_package() {
  kit --verify && return 0
  echo "install: scripts/check.sh --kit-install (pip installs the kit package at the commit in .check.lock)"
  return 1
}
pkg_mode && run "kit package" kit_package
# The site page says what the README says (scripts/build_site.py), when README.md has site sections.
[ -f scripts/build_site.py ] && grep -qs -- '<!-- site:' README.md && run "site from README" python3 scripts/build_site.py --check

if [ ! -f scripts/log_check.py ]; then
  :  # starter tier: no project log
elif [ -f scripts/check_blocks.py ] && ! python3 scripts/check_blocks.py --placeholders AGENTS.md >/dev/null && ! python3 scripts/check_blocks.py --placeholders docs/LOG.md >/dev/null; then
  skip "project log" "template placeholders: run first use"
elif [ -f docs/LOG.md ]; then
  run "project log" python3 scripts/log_check.py docs/LOG.md
else
  skip "project log" "no docs/LOG.md: the log lives in the place AGENTS.md Project rules names"
fi
# T6 (plan 2026-11-23): a DECISIONS row By the Maintainer quotes the approval. The kit (no .check.lock) always runs it: with no
# approval-quote-exempt-from marker every row is checked. A project runs it where docs/DECISIONS.md has the marker (its sync adds
# it) and prints a SKIP line otherwise. T7: each plan coverage list is complete.
if [ -f scripts/log_check_plan.py ]; then
  if [ ! -f .check.lock ] || grep -qs 'approval-quote-exempt-from' docs/DECISIONS.md; then
    run "decisions approval quote" python3 scripts/log_check.py --decisions
  else
    skip "decisions approval quote" "docs/DECISIONS.md has no approval-quote-exempt-from marker (a sync adds it)"
  fi
  for f in docs/reviews/*-coverage.md; do
    [ -f "$f" ] && run "plan coverage ${f##*/}" python3 scripts/log_check.py --coverage "$f"
  done
fi

if [ ! -f .check ] && [ ! -f .pii-guard ]; then
  skip "content check" "no .check file: the scan of tracked files is off"
elif [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  skip "content check" "GitHub Actions: the checks workflow's content step scans with the base settings"
elif [ "$pii" = 0 ]; then
  skip "content check" "the pre-push hook scans the files and the pushed commits next"
else
  run "content check" python3 scripts/check_content.py --all
fi

# The fleet format (docs/reviews/2026-11-19-fleet-contract.md): both lanes, only where .check has the line `fleet: on`.
if [ -f scripts/fleet_harvest.py ] && grep -Eq '^[[:space:]]*fleet: on[[:space:]]*$' .check 2>/dev/null; then
  run "fleet format" python3 scripts/fleet_harvest.py --check
fi

# The steps a person follows (AGENTS.md "Instructions people follow"): both lanes, on the files .check names.
if [ -f scripts/check_instructions.py ]; then
  if grep -Eq '^[[:space:]]*audit-instructions[[:space:]]*:' .check 2>/dev/null; then
    run "instructions" python3 scripts/check_instructions.py
  else
    run "instructions (README.md; no audit-instructions: lines in .check)" python3 scripts/check_instructions.py README.md
  fi
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
if [ -f scripts/bloat_check.py ] && [ "${#items[@]}" -gt 0 ]; then  # warn only: .claude/skills/audit/SKILL.md "A slow run"
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
