#!/usr/bin/env bash
# Session check-in: run at the start and the end of each session.
# Prevents: a session starts with the git hooks path unset, a stale origin/main, or an unseen kit, denylist or audit notice, so a guard is off
# Self-test of the hooks-path setup (temporary repos, no network): bash scripts/session_checkin.sh --test
# Network: the git remote "origin" (one fetch of origin/main) and, with the token log hook installed, one ls-remote of
# its private log repo; none in the self-test.
# Writes: the git config key core.hooksPath of this clone (the kit's hooks folder); the self-test: temporary repos.
# Credentials: none itself; the fetch uses the credentials git already has for origin.
set -uo pipefail
t0=$(date +%s%N 2>/dev/null)  # nanoseconds where date has %N (GNU); the run's time is compared with its baseline below

# Git hooks for every agent (scripts/git-hooks/pre-push blocks force-pushes). Set when no hooks path is set, when it is the
# old relative value, or when it names a scripts/git-hooks folder that is gone (a moved clone). The path is absolute, in
# the main clone (not a linked worktree that can be removed): git looks for a relative path in the folder a command runs
# in, so "git --git-dir=<repo>/.git push" from another folder would find no hook. Another hooks path is kept.
# core.hooksPath hides .git/hooks; our pre-push chains to an old .git/hooks/pre-push (Git LFS). Other old hooks: warned below.
want_hooks() {  # the absolute scripts/git-hooks of the main clone (of this worktree when the main clone has none)
  local common want
  common=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
  want="$(dirname "$common")/scripts/git-hooks"
  [ "$(basename "$common")" = .git ] && [ -d "$want" ] || want="$(git rev-parse --show-toplevel)/scripts/git-hooks"
  printf '%s' "$want"
}
# sets core.hooksPath where the rule above says; prints the path, and " (installed now)" when it set one
fix_hooks() {
  local hooks want fix=0
  hooks=$(git config --get core.hooksPath || true)
  want=$(want_hooks)
  case "$hooks" in
    ''|scripts/git-hooks) fix=1 ;;
    */scripts/git-hooks) [ -d "$hooks" ] || fix=1 ;;
  esac
  if [ "$fix" = 1 ] && [ -d "$want" ] && git config core.hooksPath "$want"; then
    printf '%s (installed now)' "$want"
  else
    printf '%s' "${hooks:-none}"
  fi
}

# Session names (AGENTS.md "Start of session"; steps: .claude/skills/handoff/SKILL.md "Session names").
# header_value FILE KEY: the value of the "- KEY: value" line in FILE, or nothing; a {{PLACEHOLDER}} counts as nothing
header_value() {
  local v
  v=$({ tr -d '\r' < "$1"; } 2>/dev/null | sed -n "s/^- $2: *\(.*[^[:space:]]\)[[:space:]]*\$/\1/p" | head -n 1)  # no CR, no end spaces
  case "$v" in '{{'*) v= ;; esac
  printf '%s' "$v"
}
# title_lines FILE: print the TITLE and SESSIONS lines from the AGENTS.md header in FILE. The short name is the
# "- Short name:" value, else the first word of the project name, else "Kit" (the kit clone keeps its placeholders).
title_lines() {
  local short name tz day tag
  short=$(header_value "$1" "Short name")
  name=$(sed -n 's/^# \(.*\): agent instructions$/\1/p' "$1" 2>/dev/null | head -n 1)
  case "$name" in '{{'*) name= ;; esac
  [ -n "$short" ] || short=${name%% *}
  [ -n "$short" ] || short=Kit
  tz=$(header_value "$1" "Time zone")
  day=$(TZ="${tz:-UTC}" date +%F)
  tag="project:$(printf '%s' "$short" | tr '[:upper:]' '[:lower:]')"
  echo "TITLE:       $short · <task, 2-6 words> · $day (tag $tag); keep a title that already has this form; steps: .claude/skills/handoff/SKILL.md \"Session names\""
  echo "SESSIONS:    where the session tools exist, list the sessions tagged $tag that wait on the Maintainer"
}

# kit_line: in package mode a fresh clone lacks the kit scripts that .check.lock lists (scripts/check.sh --kit-install
# writes them); without them the check-in lines below skip with no word. Prints one KIT line with the count, or nothing.
kit_line() {
  [ -f .check.lock ] || return 0
  python3 -c 'import json, os, sys
f = [p for p in json.load(open(".check.lock")).get("files", {}) if p.startswith("scripts/") and not os.path.exists(p)]
f and print("KIT:         %d kit scripts that .check.lock lists are missing (a fresh clone in package mode): run "
            "scripts/check.sh --kit-install, then this check-in again" % len(f))' 2>/dev/null || echo "KIT:         .check.lock cannot be read"
}

# token_log_line HOOKS_DIR: the TOKEN LOG lines of the installed token log hook (scripts/token_log.py) in HOOKS_DIR:
# the private log repo ("token_log_repo" of its kit.config.json, or TOKEN_LOG_REPO) when this session cannot reach it,
# so the agent attaches it and the log stays private, and the newest ALARM line of its push.log (TOKEN_LOG_HOME).
# Nothing when no hook is installed or TOKEN_LOG=off.
token_log_line() {
  local d="$1" url name alarm
  [ -f "$d/token_log.py" ] && [ "${TOKEN_LOG:-}" != off ] || return 0
  url=${TOKEN_LOG_REPO:-$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("token_log_repo") or "")' \
    "$d/kit.config.json" 2>/dev/null)}
  case "$url" in -*) url="" ;; esac
  local tmo=""; command -v timeout >/dev/null && tmo="timeout 30"  # macOS has no timeout
  if [ -n "$url" ] && ! GIT_TERMINAL_PROMPT=0 $tmo git ls-remote --heads "$url" >/dev/null 2>&1; then
    name=${url%/}; name=${name%.git}; name=${name#https://github.com/}
    echo "TOKEN LOG:   the private log repo $name is not reachable: attach it read and write (add_repo $name) so this session's token log stays private; if that is refused, say so to the Maintainer"
  fi
  alarm=$(grep ' ALARM: the session log' "${TOKEN_LOG_HOME:-$HOME/.claude/token-log}/push.log" 2>/dev/null | tail -n 1)
  [ -n "$alarm" ] && echo "TOKEN LOG:   $alarm"
  return 0
}

if [ "${1:-}" = "--test" ]; then
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1  # the host's git config must not change the cases
  unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
  # A failed mktemp must stop here: "cd ''" succeeds, and the trap below would then delete the current folder.
  t=$(mktemp -d) && [ -n "$t" ] || { echo "CHECKIN TEST FAIL: no temporary folder"; exit 1; }
  t=$(cd "$t" && pwd -P) && [ -n "$t" ] || { echo "CHECKIN TEST FAIL: no temporary folder"; exit 1; }
  trap 'rm -rf "$t"' EXIT
  fails=0
  # eq NAME GOT WANT: print ok or FAIL, and remember a failure
  eq() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got '$2', want '$3')"; fails=1; fi; }
  # hp REPO: the core.hooksPath set in that repo
  hp() { git -C "$1" config --get core.hooksPath; }
  git init -q -b main "$t/r"; mkdir -p "$t/r/scripts/git-hooks"; echo '#!/bin/sh' > "$t/r/scripts/git-hooks/pre-push"
  git -C "$t/r" add -A; git -C "$t/r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m a
  eq "no hooks path: set to the absolute path" "$(cd "$t/r" && fix_hooks)" "$t/r/scripts/git-hooks (installed now)"
  eq "  stored" "$(hp "$t/r")" "$t/r/scripts/git-hooks"
  eq "already right: kept, not set again" "$(cd "$t/r" && fix_hooks)" "$t/r/scripts/git-hooks"
  git -C "$t/r" config core.hooksPath scripts/git-hooks
  eq "the old relative value: made absolute" "$(cd "$t/r" && fix_hooks >/dev/null; hp "$t/r")" "$t/r/scripts/git-hooks"
  git -C "$t/r" config core.hooksPath "$t/gone/scripts/git-hooks"
  eq "a moved clone (the path is gone): repaired" "$(cd "$t/r/scripts" && fix_hooks >/dev/null; hp "$t/r")" "$t/r/scripts/git-hooks"
  git -C "$t/r" config core.hooksPath .husky
  eq "another hooks path: kept" "$(cd "$t/r" && fix_hooks; echo " $(hp "$t/r")")" ".husky .husky"
  mkdir -p "$t/other/scripts/git-hooks"; git -C "$t/r" config core.hooksPath "$t/other/scripts/git-hooks"
  eq "another existing scripts/git-hooks: kept" "$(cd "$t/r" && fix_hooks >/dev/null; hp "$t/r")" "$t/other/scripts/git-hooks"
  git -C "$t/r" config --unset core.hooksPath
  git -C "$t/r" worktree add -q -b wtb "$t/wt"
  eq "a linked worktree: the main clone's path" "$(cd "$t/wt" && fix_hooks >/dev/null; hp "$t/r")" "$t/r/scripts/git-hooks"
  git init -q -b main "$t/bare-of-hooks"
  eq "no scripts/git-hooks folder: nothing set" "$(cd "$t/bare-of-hooks" && fix_hooks; echo " $(hp "$t/bare-of-hooks")")" "none "
  # Session names: the TITLE line takes the short name, else the project name's first word, else "Kit"
  today=$(TZ=UTC date +%F)
  printf '# RADE: agent instructions\n\n- Time zone: UTC\n- Short name: RADE\n' > "$t/a1.md"
  eq "TITLE: the short name" "$(title_lines "$t/a1.md" | head -n 1)" \
    "TITLE:       RADE · <task, 2-6 words> · $today (tag project:rade); keep a title that already has this form; steps: .claude/skills/handoff/SKILL.md \"Session names\""
  printf '# ICF Companion: agent instructions\n\n- Time zone: UTC\n- Short name: {{SHORT_NAME}}\n' > "$t/a2.md"
  eq "TITLE: a placeholder falls back to the name" "$(title_lines "$t/a2.md" | grep -c '^TITLE:       ICF · ')" "1"
  printf '# R: agent instructions\r\n\r\n- Time zone: UTC\r\n- Short name: RADE  \r\n' > "$t/a4.md"
  eq "TITLE: CRLF and end spaces trimmed" "$(title_lines "$t/a4.md" | grep -c '(tag project:rade);')" "1"
  printf '# {{PROJECT_NAME}}: agent instructions\n\n- Time zone: {{TIMEZONE}}\n- Short name: {{SHORT_NAME}}\n' > "$t/a3.md"
  eq "TITLE: the kit clone is Kit" "$(title_lines "$t/a3.md" | tail -n 1 | grep -o 'project:kit')" "project:kit"
  # The KIT line: a lock-listed kit script missing on disk is named; all present, or no lock: no line
  mkdir -p "$t/k/scripts"; printf '{"commit": "x", "files": {"scripts/a.py": "1", "scripts/b.py": "2", "AGENTS.md": "3"}}' > "$t/k/.check.lock"
  touch "$t/k/scripts/a.py"
  eq "KIT: a missing kit script is counted" "$(cd "$t/k" && kit_line | grep -c '^KIT:         1 kit scripts that .check.lock lists are missing')" "1"
  touch "$t/k/scripts/b.py"
  eq "KIT: all kit scripts present: no line" "$(cd "$t/k" && kit_line)" ""
  rm "$t/k/.check.lock"; eq "KIT: no lock: no line" "$(cd "$t/k" && kit_line)" ""
  # TOKEN LOG: an installed hook whose private log repo cannot be reached, then can; an ALARM line in push.log
  unset TOKEN_LOG TOKEN_LOG_REPO  # the host's settings must not change the cases
  mkdir -p "$t/h"; touch "$t/h/token_log.py"; printf '{"token_log_repo": "file://%s/none.git"}' "$t" > "$t/h/kit.config.json"
  eq "TOKEN LOG: private repo not reachable: attach line" "$(TOKEN_LOG_HOME="$t/h" token_log_line "$t/h" | grep -c 'add_repo file://')" "1"
  git init -q --bare "$t/none.git"
  eq "TOKEN LOG: reachable, no alarm: no line" "$(TOKEN_LOG_HOME="$t/h" token_log_line "$t/h")" ""
  printf '%s\n' "x remote: ALARM attach evil/repo" "2026-01-01T00:00:00+00:00 s ALARM: the session log has replies" > "$t/h/push.log"
  eq "TOKEN LOG: the newest ALARM line of the hook (not a line that only names ALARM)" \
    "$(TOKEN_LOG_HOME="$t/h" token_log_line "$t/h")" "TOKEN LOG:   2026-01-01T00:00:00+00:00 s ALARM: the session log has replies"
  echo "x remote: ALARM attach evil/repo" > "$t/h/push.log"
  eq "TOKEN LOG: a push error that names ALARM: no line" "$(TOKEN_LOG_HOME="$t/h" token_log_line "$t/h")" ""
  eq "TOKEN LOG: no hook installed: no line" "$(token_log_line "$t/none")" ""
  [ "$fails" = 0 ] && echo "CHECKIN TEST PASS" || { echo "CHECKIN TEST FAIL"; exit 1; }
  exit 0
fi

top=$(git rev-parse --show-toplevel) && cd "$top" || exit 1  # paths below are repo-relative; a run from a subfolder must still find them

git fetch --quiet origin main 2>/dev/null || echo "warning: fetch of origin/main failed"

echo "hooks:       $(fix_hooks)"
hooks=$(git config --get core.hooksPath || true)
want=$(want_hooks)
if [ "$hooks" = "$want" ]; then
  for h in "$(git rev-parse --git-common-dir)"/hooks/*; do
    case "$h" in *.sample|*/pre-push) continue ;; esac
    [ -x "$h" ] && echo "warning: $(basename "$h") in .git/hooks is not run while core.hooksPath is set; copy it to scripts/git-hooks or unset core.hooksPath"
  done
fi
echo "branch:      $(git rev-parse --abbrev-ref HEAD)"
echo "head:        $(git rev-parse --short HEAD)"
echo "origin/main: $(git rev-parse --short origin/main 2>/dev/null || echo unknown)"

if counts=$(git rev-list --left-right --count HEAD...origin/main 2>/dev/null); then
  read -r ahead behind <<<"$counts"
  echo "ahead:       $ahead"
  echo "behind:      $behind"
else
  echo "ahead/behind: unknown (shallow clone or no origin/main)"
fi

uncommitted=$(git status --porcelain | wc -l | tr -d ' ')
echo "uncommitted: $uncommitted"
[ "$uncommitted" -gt 0 ] && git status --short
[ -f AGENTS.md ] && title_lines AGENTS.md

kit_line
token_log_line "$HOME/.claude/hooks"
[ -f scripts/bloat_check.py ] && python3 scripts/bloat_check.py --brief
# The last check run in this clone: lane, wall time and the 3 slowest checks (scripts/check.sh writes it).
last="$(git rev-parse --git-dir)/check-last"
[ -f "$last" ] && echo "check:       $(sed 's/^TIME  //' "$last")"
[ -f scripts/check_lock.py ] && [ -f .check.lock ] && python3 scripts/check_lock.py --status
# Content check: list source, entry count, fingerprint (compare it between places) and tier; never the names.
if { [ -f .check ] || [ -f .pii-guard ]; } && [ -f scripts/check_content.py ]; then python3 scripts/check_content.py --status || true; fi

# The kit itself keeps its placeholders on purpose (same origin rule as TEMPLATE_NAME in scripts/first_use_check.py).
origin=$(git remote get-url origin 2>/dev/null); origin=${origin%/}; origin=${origin%.git}; origin=${origin##*/}
if [ "$(printf '%s' "$origin" | tr '[:upper:]' '[:lower:]')" != "archimedes_lever" ] && [ -f scripts/check_blocks.py ] && ! python3 scripts/check_blocks.py --placeholders >/dev/null 2>&1; then
  echo "warning: template placeholders remain; run scripts/bootstrap.sh"
fi
# This run's time against the "checkin" baseline in .check.state.json (warn only; .claude/skills/audit/SKILL.md "A slow run").
case "$t0" in *N|'') ;; *) [ -f scripts/bloat_check.py ] && python3 scripts/bloat_check.py \
  --compare "checkin=$(awk -v a="$t0" -v b="$(date +%s%N)" 'BEGIN {printf "%.1f", (b - a) / 1e9}')" 2>&1 | tail -n 1 ;; esac
exit 0
