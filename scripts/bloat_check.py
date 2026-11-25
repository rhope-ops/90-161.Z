#!/usr/bin/env python3
"""Cheap bloat and drift metrics for a project repo, and the audit due date. Report only, unless --record.

Prevents: the instruction files and the session load growing past their caps unseen, rule lines that change with no conflict
check, a path that AGENTS.md names and that is gone, and a skill that is malformed.

Usage:
    python3 scripts/bloat_check.py            # full report
    python3 scripts/bloat_check.py --brief    # one line (scripts/session_checkin.sh runs this)
    python3 scripts/bloat_check.py --time     # also run each timed command in .check.state.json and compare
    python3 scripts/bloat_check.py --time --record   # run them and store the new seconds as the baseline
    python3 scripts/bloat_check.py --strict   # exit 1 when a budget is over or the audit is due
    python3 scripts/bloat_check.py --rules    # rule counts against the caps, rule lines added or removed against
                                              # origin/main, and missing .claude/ paths; exit 1 when a cap is passed
                                              # or a path is missing (scripts/check.sh runs this)
    python3 scripts/bloat_check.py --rules --gate   # also fail when rule lines changed and no conflict-check
                                              # record in docs/reviews/ names their hash (scripts/check.sh full lane)
    python3 scripts/bloat_check.py --lint     # rule lint of every rule line: near-duplicates, vague words, untested
                                              # rules; report only (--rules lints the changed lines)
    python3 scripts/bloat_check.py --skills   # check each .claude/skills/*/SKILL.md: FAIL (exit 1) with no frontmatter,
                                              # no name or description, or a name that differs from its folder;
                                              # WARN (exit 0) for a description not starting "Use when"/"Use before",
                                              # over 1024 characters, a file over 150 lines, or an orphan skill
                                              # (name in neither AGENTS.md nor another SKILL.md); last line SKILLS PASS/FAIL
                                              # (code: scripts/bloat_check_skills.py)
    python3 scripts/bloat_check.py --compare NAME=SECONDS ...   # compare times that a script measured with their
                                              # baselines; one TIME or WARN line; never fails (scripts/check.sh,
                                              # session_checkin.sh and the pre-push hook run it); --record stores them
                                              # (code of --time and --compare: scripts/bloat_check_timing.py)
    python3 scripts/bloat_check.py --test     # self-test (scripts/bloat_check_test.py); prints BLOAT TEST PASS

It measures:
    session load  bytes and ~tokens (bytes / 4) of what every session loads: AGENTS.md, CLAUDE.md,
                  docs/NEXT_PROMPT.md, the `audit-start-read:` files, and the skill and agent names and descriptions.
                  Caps for every repo (KIT_CAPS; a project can lower one, never raise it): 5,500 tokens (warning at
                  5,000) and 200 lines of AGENTS.md; over a cap fails --rules
    third-party   the names and descriptions of the skills and agents that `.check` names in `audit-third-party:`
                  lines: counted apart from the session load, against their own kit cap of 1,500 tokens (the Maintainer,
                  2026-11-20); over it fails --rules
    rules         list items in AGENTS.md (any marker, any indent; a wrapped line is part of its item): the kit
                  sections (the header, "## Commands" and the numbered ranking in "## Order of authority" are not
                  counted) and "## Project rules" (there a paragraph or a table row counts too), each against its
                  cap, so rules cannot grow unseen
    rule lint     (--lint all rules; --rules the changed ones, as WARN lines) a near-duplicate pair (similar text),
                  a vague word (VAGUE), and an untested rule: its section has no scenario in .claude/rule-tests.md
                  (column "Section") and the line names no script under scripts/ that enforces it. Warn only.
    conflict gate (--rules) rule lines added or removed against origin/main need a fresh-context conflict check
                  (.claude/skills/rule-change/SKILL.md); its record in docs/reviews/ holds the line
                  "rule-conflict-check: <hash>" that --rules prints. With --gate (the full lane) a missing record fails.
    pointers      each `.claude/...`, `scripts/...` and `docs/...` path in backticks and each relative link in
                  AGENTS.md exists (text moved to a skill is not lost)
    readme        (--rules) when the AGENTS.md "- Purpose:" line is filled in: no README.md fails; a README.md whose
                  first paragraph does not open with that purpose is a WARN line (AGENTS.md "One home")
    handoff       docs/NEXT_PROMPT.md lines
    duplicates    normalized text lines of 80+ characters found in 2 or more tracked files (not counted: the lines
                  of a generated block, between the marker lines "# >>> ... generated from ..." and "# <<< ...")
    big files     tracked files over the size budget
    audit due     days and commits on main since the last full audit (.check.state.json "audit": "last_audit")
    tool rows     (--rules, T1) each tool file the repo owns has a docs/tools.md row, whose first cell names it: 3 candidate tools,
                  or "none known" and the search terms; FAIL in the kit, WARN in a project (code: scripts/bloat_check_files.py)
    script lines  (--rules, T2) the lines of scripts/*.py and *.sh against "script_lines": {"baseline": N} in the state file
                  (`cat scripts/*.py scripts/*.sh | wc -l`); over it fails, and so does a baseline above main's with no DECISIONS row; below it fails unless "cap": true; no baseline: FAIL in the kit, SKIP in a project
    role word     (--rules, T6) kit-synced text in the kit says "the Maintainer", not an old role word; FAIL in the kit, no check in a project
    debt record   (--rules --gate, T5, kit) changed rule lines, a check entry point added to scripts/check.sh and a lower
                  KIT_CAPS cap need a docs/reviews/*-debt.md file with the line "debt-check: <hash>" (the hash as the conflict gate)
    fleet audit   (kit, R3) AUDIT DUE (fleet): kit.config.json "fleet": {"last_audit": "YYYY-MM-DD"} missing, over 14 days old,
                  or older than a v* release tag at HEAD
    archive due   ARCHIVE DUE: the archivable files of docs/reviews/ reach 20 files or 200 KB, or docs/reviews/ passes 200
                  files or 1 MB (the tests and limits: archive_due in scripts/bloat_check_files.py)
    timings       (--time) wall time of each named command against its recorded baseline; (--compare) times that
                  a script measured itself: NAME is a timings key, NAME:STEP one of its "steps". Slower means over
                  max_slowdown (default +25%) and over min_slowdown_seconds (default 0.5 s), so noise on a small step
                  does not warn. A slowdown starts .claude/skills/audit/SKILL.md "A slow run"

Settings: the `audit-` lines of `.check` (scripts/check_settings.py reads them and lists the keys; all are optional,
and a line that is not valid fails --rules):
    audit-every-days: 14, audit-every-commits: 300, audit-ignore: ref/**, audit-start-read: <path>,
    audit-duplicate-ignore: data/** (not read by the duplicate count only),
    audit-budget-<name>: <number> (handoff_lines 40, file_kb 500, duplicate_lines 20, rules 28, project_rules 15)
State: `.check.state.json` (tools write it; the full audit in .claude/skills/audit/SKILL.md sets "last_audit"):
    {"audit": {"last_audit": {"date": "YYYY-MM-DD", "commit": "<sha>", "report": "<path>"}},
     "timings": {"tests": {"cmd": "tests/run.sh", "seconds": 20.8, "max_slowdown": 0.25},
                 "check": {"cmd": "bash scripts/check.sh", "seconds": 4.5, "steps": {"check_content self-test": 4.1}},
                 "push-guard": {"seconds": 0.4}}}
A timing with no "cmd" is only compared (--compare), never run by --time.
The "rules" and "project_rules" bullet counts only warn.
A repo with no "last_audit" reports AUDIT DUE (never audited) once it is every_days or every_commits past its first
commit (a new project is not due on day one; an older project synced for the first time usually is).
Exit 0, unless --strict and something is over (exit 1). Standard library only. Needs git.
Network: none (it runs local git read commands; with --time it runs the timed commands of .check.state.json, which may use it).
Writes: .check.state.json, only with --record (the time baselines).
Credentials: none.
"""
import argparse
import datetime
import fnmatch
import json
import re
import sys
from pathlib import Path

import bloat_check_files  # scripts/bloat_check_files.py: the file checks and the full --rules report (kept apart, code standard C4)
import check_settings  # scripts/check_settings.py: the reader of .check and the reader and writer of .check.state.json
# scripts/bloat_check_rules.py: the rule census (kept apart, code standard C4). The names the self-test reads are listed.
from bloat_check_files import is_kit, rules_report  # noqa: F401 - the full --rules report (rule census + file checks)
from bloat_check_rules import conflict_hash, git, lint, main_lint, rule_lines, start_read  # noqa: F401
# scripts/bloat_check_timing.py: the timed commands and the baseline comparison (kept apart, code standard C4).
from bloat_check_timing import (SHELL_CHARS, TIMING_DIRS, compare_times, run_timings, save_timings,  # noqa: F401
                                timing_argv)

STATE = check_settings.STATE
DEFAULTS = check_settings.AUDIT_DEFAULTS  # the settings when .check has no `audit-` line
TEXT_EXT = {".md", ".txt", ".py", ".sh", ".ps1", ".psm1", ".js", ".ts", ".json", ".yml", ".yaml", ".html", ".css",
            ".toml", ".ini", ".cfg", ".csv", ""}
MIN_DUP = 80          # characters in a normalized line before it counts as a duplicate
MAX_SCAN = 1_000_000  # bytes; larger files are not scanned for duplicates


def load_config(root):
    """The audit settings of .check, with "last_audit" and "timings" from .check.state.json; ValueError when a
    line is not valid or a file cannot be read (scripts/check_settings.py; KIT_CAPS budgets can only be lowered there)."""
    return check_settings.audit_config(root)


def ignored(rel, cfg, key="ignore"):
    """True when rel matches a glob of an `audit-ignore:` line (key "duplicate_ignore": `audit-duplicate-ignore:`)."""
    return any(fnmatch.fnmatch(rel, g) for g in cfg.get(key, []))


def dup_files(files, cfg):
    """The files the duplicate count reads: files without those an `audit-duplicate-ignore:` glob matches.
    Args:
        files: the repo-relative paths that scan_files gives.
        cfg: the audit settings.
    Returns:
        A list of repo-relative paths.
    """
    return [rel for rel in files if not ignored(rel, cfg, "duplicate_ignore")]


def norm(line):
    """line without list, quote, heading and table marks, whitespace made single, lower case (for duplicates)."""
    line = re.sub(r"^[\s>#|*\-+0-9.]+", "", line)
    return re.sub(r"\s+", " ", line).strip().lower()


def scan_files(root, cfg):
    """The tracked files that exist and are not ignored by the config."""
    out = git(root, "ls-files")
    return [rel for rel in (out.splitlines() if out else []) if not ignored(rel, cfg) and (root / rel).is_file()]


def duplicates(root, files):
    """Return [(normalized line, [files])] for long lines found in 2+ text files, most files first.

    Args:
        root: the repo root (a Path).
        files: the repo-relative paths to scan.

    Returns:
        A list of (normalized line, [files]).
    """
    seen = {}
    for rel in files:
        p = root / rel
        if p.suffix.lower() not in TEXT_EXT or p.stat().st_size > MAX_SCAN:
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for line in counted_lines(text):
            n = norm(line)
            if len(n) >= MIN_DUP:
                seen.setdefault(n, set()).add(rel)
    dups = [(n, sorted(fs)) for n, fs in seen.items() if len(fs) > 1]
    return sorted(dups, key=lambda d: -len(d[1]))


def counted_lines(text):
    """Yield the lines of a text that the duplicate count reads. The lines between the marker lines
    "# >>> <name>: generated from <source> ..." and "# <<< <name>" (docs/code-standard.md C5) are a copy that a build
    script writes and checks: they are not counted, so a hand-made duplicate stays visible.

    Args:
        text: the text of one file.
    """
    generated = False
    for line in text.splitlines():
        mark = line.strip()
        if mark.startswith("# >>> ") and "generated from" in mark:
            generated = True
        elif mark.startswith("# <<< "):
            generated = False
        elif not generated:
            yield line


def big_files(root, files, kb):
    """Return [(file, KB)] of the files over kb kilobytes, largest first."""
    return sorted(((rel, (root / rel).stat().st_size // 1024) for rel in files
                   if (root / rel).stat().st_size > kb * 1024), key=lambda f: -f[1])


def fleet_audit_due(root, today, every_days=14):
    """Why the fleet audit is due, or "" when it is not (the kit only: R3). Due when kit.config.json has no `fleet.last_audit`
    date, when that date is more than every_days old, or when HEAD carries a kit release tag (v*) dated after it.

    Args:
        root: the repo root (a Path).
        today: the date to count from (a datetime.date).
        every_days: the days after which the audit is due again.

    Returns:
        The reason as a text, or "".
    """
    if not is_kit(root):
        return ""
    try:
        last = datetime.date.fromisoformat(json.loads((root / "kit.config.json").read_text(encoding="utf-8"))["fleet"]["last_audit"])
    except (ValueError, KeyError, TypeError, OSError):
        return "no fleet.last_audit date in kit.config.json"
    reasons = [f"{(today - last).days} days since {last}"] if (today - last).days > every_days else []
    for tag in (git(root, "tag", "--points-at", "HEAD", "--list", "v[0-9]*", "--format=%(creatordate:short) %(refname:short)") or "").splitlines():
        if tag.split()[0] > last.isoformat():
            reasons.append(f"kit release {tag.split()[1]} is newer than {last}")
    return "; ".join(reasons)


def audit_due(root, cfg, today):
    """Why the full audit is due (days or commits since the last one, or never audited), or "" when it is not.

    Args:
        root: the repo root (a Path).
        cfg: the audit settings, with "last_audit".
        today: the date to count from (a datetime.date).

    Returns:
        The reason as a text, or "".
    """
    last = cfg.get("last_audit") or {}
    if not last.get("date"):
        # Never audited: due once the repo is every_days or every_commits past its first commit (kit default, 2026-11-13),
        # so a new project does not report AUDIT DUE on day one. No history readable, or a shallow clone (its oldest
        # commit is a cut, not the first commit): due.
        if git(root, "rev-parse", "--is-shallow-repository") == "true":
            return "never audited"
        first = git(root, "log", "--max-parents=0", "--format=%cs")
        count = git(root, "rev-list", "--count", "HEAD")
        if not first or not count:
            return "never audited"
        start = min(datetime.date.fromisoformat(d) for d in first.split())
        days = (today - start).days
        if days >= int(cfg["every_days"]) or int(count) >= int(cfg["every_commits"]):
            return f"never audited; {days} days and {count} commits since the first commit"
        return ""
    reasons = []
    days = (today - datetime.date.fromisoformat(last["date"])).days
    if days >= int(cfg["every_days"]):
        reasons.append(f"{days} days since {last['date']}")
    if last.get("commit"):
        n = git(root, "rev-list", "--count", f"{last['commit']}..HEAD")
        if n is not None and int(n) >= int(cfg["every_commits"]):
            reasons.append(f"{n} commits since {last['commit'][:7]}")
    return "; ".join(reasons)


def main_compare(root, items, record):
    """--compare: print one TIME or WARN line for NAME=SECONDS items; --record stores them. Always 0.

    Args:
        root: the repo root (a Path).
        items: the NAME=SECONDS arguments.
        record: True to store them as the new baselines.

    Returns:
        The exit code 0.
    """
    try:
        cfg = load_config(root)
        pairs = [(i.rsplit("=", 1)[0], round(float(i.rsplit("=", 1)[1]), 1)) for i in items]
    except (ValueError, TypeError, KeyError, IndexError) as e:
        print(f"TIME  baseline: not compared ({e})")
        return 0
    line, _ = compare_times(cfg, pairs, record)
    if record:
        save_timings(root, cfg["timings"])
    print(line)
    return 0


def report(root, args, today=None):
    """Print the full report (or the --brief line).

    Args:
        root: the repo root (a Path).
        args: the parsed options (brief, time, record, strict).
        today: the date to count the audit from; None = today.

    Returns:
        The exit code: 1 with --strict when something is over or the audit is due, else 0.
    """
    today = today or datetime.date.today()
    try:
        cfg = load_config(root)
        due = audit_due(root, cfg, today)
    except (ValueError, TypeError, KeyError) as e:
        print(f"bloat:       settings unreadable ({e}); fix it, then run scripts/bloat_check.py")
        return 1 if args.strict else 0
    b = cfg["budgets"]
    files = scan_files(root, cfg)
    _, s_bytes, s_tok, s_files = start_read(root, cfg)
    hp = root / "docs/NEXT_PROMPT.md"
    h_lines = hp.read_bytes().count(b"\n") if hp.exists() else 0
    dups = duplicates(root, dup_files(files, cfg))
    big = big_files(root, files, b["file_kb"])
    over = []
    # The session load cap and its warning are reported by rules_report (they fail scripts/check.sh --rules).
    warn = "session load over warning" if b.get("session_load_warn_tokens", 0) < s_tok <= b["session_load_tokens"] else ""
    if h_lines > b["handoff_lines"]:
        over.append("handoff")
    if len(dups) > b["duplicate_lines"]:
        over.append("duplicates")
    if big:
        over.append("big files")
    r_rows, r_problems = rules_report(root, cfg)
    over += r_problems
    t_rows, slow = run_timings(root, cfg, args.record) if args.time else ([], [])
    over += [f"timing {n}" for n in slow]
    if args.record and args.time:
        save_timings(root, cfg.get("timings", {}))

    tail = (f"AUDIT DUE ({due}): tell the Maintainer and ask whether to run the audit skill (.claude/skills/audit/SKILL.md, "
            "about 1 hour of agent time); never start it unasked") if due else "audit not due"
    fleet = fleet_audit_due(root, today)
    if fleet:
        tail += (f" · AUDIT DUE (fleet: {fleet}): tell the Maintainer and ask whether to run the fleet audit "
                 "(.claude/skills/audit/SKILL.md, section Fleet audit); never start it unasked")
    archive = bloat_check_files.archive_due(root, (git(root, "ls-files") or "").splitlines(), today)
    if archive:
        tail += (f" · ARCHIVE DUE ({archive}): tell the Maintainer and ask whether to run the archive step "
                 "(.claude/skills/audit/SKILL.md, section The archive step); never start it unasked")
    if args.brief:
        print(f"bloat:       {r_rows[0][13:]} · duplicate lines "
              f"{len(dups)} · big files {len(big)} · over: {', '.join(over) or 'none'}{' · ' + warn if warn else ''} · {tail}")
    else:
        print_full(b, (s_bytes, s_tok, s_files), r_rows, h_lines, dups, big, t_rows, over, warn, tail)
    return 1 if args.strict and (over or due) else 0


def print_full(b, load, r_rows, h_lines, dups, big, t_rows, over, warn, tail):
    """Print the full report from what report() measured.

    Args:
        b: the budgets of the audit settings.
        load: the session load as (bytes, ~tokens, [(file, bytes)]).
        r_rows: the lines of the rules report.
        h_lines: the line count of the handoff.
        dups: the duplicate lines, as duplicates() gives them.
        big: the big files, as big_files() gives them.
        t_rows: the timing rows (--time), or [].
        over: the names of what is over its budget.
        warn: the warning text, or "".
        tail: the audit line.
    """
    s_bytes, s_tok, s_files = load
    print(f"session load: {s_bytes:,} bytes, ~{s_tok:,} tokens (cap {b['session_load_tokens']:,})")
    for rel, size in s_files:
        print(f"  {rel}: {size:,} bytes")
    print(r_rows[0])
    moved = sum(1 for r in r_rows if r.startswith(("  + ", "  - ")))
    if moved:
        print(f"  {moved} rule line(s) added or removed against the default branch (list: --rules)")
    print(f"handoff:     docs/NEXT_PROMPT.md {h_lines} lines (budget {b['handoff_lines']})")
    print(f"duplicates:  {len(dups)} lines of {MIN_DUP}+ characters in 2+ files (budget {b['duplicate_lines']})")
    for n, fs in dups[:10]:
        print(f"  {len(fs)} files: {', '.join(fs[:4])}{' ...' if len(fs) > 4 else ''} :: {n[:70]}")
    print(f"big files:   {len(big)} over {b['file_kb']} KB" + "".join(f"\n  {r}: {k} KB" for r, k in big[:10]))
    if t_rows:
        print("timings:\n" + "\n".join(t_rows))
    print(f"over budget: {', '.join(over) or 'none'}")
    if warn:
        print(f"warning:     {warn} ({b['session_load_warn_tokens']:,} tokens); trim rules before the cap")
    print(tail)


def main_rules(root, gate=False):
    """--rules: print the rule counts, changed lines and problems, then RULES PASS or RULES FAIL; 1 on a problem.

    Args:
        root: the repo root (a Path).
        gate: True in the full lane: a missing conflict-check record fails.

    Returns:
        The exit code: 0 pass, 1 on a problem.
    """
    try:
        cfg = load_config(root)
    except (ValueError, TypeError, KeyError) as e:
        print(f"rules:       settings unreadable ({e}); fix it first")
        return 1
    rows, problems = rules_report(root, cfg, gate)
    print("\n".join(rows))
    print("RULES FAIL" if problems else "RULES PASS")
    return 1 if problems else 0


def main():
    """Parse the options and run the chosen mode; return its exit code.

    Returns:
        The exit code of the chosen mode.
    """
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0], allow_abbrev=False)
    ap.add_argument("--rules", action="store_true")
    ap.add_argument("--brief", action="store_true")
    ap.add_argument("--time", action="store_true")
    ap.add_argument("--record", action="store_true")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--compare", nargs="+", metavar="NAME=SECONDS")
    ap.add_argument("--gate", action="store_true")
    ap.add_argument("--lint", action="store_true")
    ap.add_argument("--skills", action="store_true")
    ap.add_argument("--project", default=".")
    args = ap.parse_args()
    if args.test:
        import bloat_check_test  # scripts/bloat_check_test.py: kept apart (code standard C4)
        bloat_check_test.run(sys.modules[__name__])
        return 0
    root = Path(git(Path(args.project), "rev-parse", "--show-toplevel") or args.project)
    if args.lint:
        return main_lint(root)
    if args.skills:
        import bloat_check_skills  # scripts/bloat_check_skills.py: kept apart (code standard C4)
        return bloat_check_skills.main_skills(root)
    if args.rules:
        return main_rules(root, args.gate)
    if args.compare:
        return main_compare(root, args.compare, args.record)
    return report(root, args)


if __name__ == "__main__":
    sys.exit(main())
