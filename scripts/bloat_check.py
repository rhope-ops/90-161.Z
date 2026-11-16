#!/usr/bin/env python3
"""Cheap bloat and drift metrics for a project repo, and the bloat-audit due date. Report only, unless --record.

Usage:
    python3 scripts/bloat_check.py            # full report
    python3 scripts/bloat_check.py --brief    # one line (scripts/session_checkin.sh runs this)
    python3 scripts/bloat_check.py --time     # also run each timed command in .bloat-audit.json and compare
    python3 scripts/bloat_check.py --time --record   # run them and store the new seconds as the baseline
    python3 scripts/bloat_check.py --strict   # exit 1 when a budget is over or the audit is due
    python3 scripts/bloat_check.py --rules    # rule counts against the caps, rule lines added or removed against
                                              # origin/main, and missing .claude/ paths; exit 1 when a cap is passed
                                              # or a path is missing (scripts/check.sh runs this)
    python3 scripts/bloat_check.py --rules --gate   # also fail when rule lines changed and no conflict-check
                                              # record in docs/reviews/ names their hash (scripts/check.sh full lane)
    python3 scripts/bloat_check.py --lint     # rule lint of every rule line: near-duplicates, vague words, untested
                                              # rules; report only (--rules lints the changed lines)
    python3 scripts/bloat_check.py --compare NAME=SECONDS ...   # compare times that a script measured with their
                                              # baselines; one TIME or WARN line; never fails (scripts/check.sh,
                                              # session_checkin.sh and the pre-push hook run it); --record stores them
    python3 scripts/bloat_check.py --test     # self-test; prints BLOAT TEST PASS

It measures:
    start read    lines, bytes and ~tokens (bytes / 4) of the files every session reads first
                  (AGENTS.md, CLAUDE.md, docs/NEXT_PROMPT.md, plus "start_read" in the config; docs/DECISIONS.md
                  is a record that agents read on demand, so it is not counted)
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
    handoff       docs/NEXT_PROMPT.md lines
    duplicates    normalized text lines of 80+ characters found in 2 or more tracked files
                  (lines between "# >>> ... generated from ..." and "# <<< ..." markers are not counted)
    big files     tracked files over the size budget
    audit due     days and commits on main since the last full audit (.bloat-audit.json "last_audit")
    timings       (--time) wall time of each named command against its recorded baseline; (--compare) times that
                  a script measured itself: NAME is a timings key, NAME:STEP one of its "steps". Slower means over
                  max_slowdown (default +25%) and over min_slowdown_seconds (default 0.5 s), so noise on a small step
                  does not warn. A slowdown starts .claude/skills/efficiency/SKILL.md

.bloat-audit.json (project-owned; the full audit in .claude/skills/audit/SKILL.md writes it). All keys are optional:
    {"last_audit": {"date": "YYYY-MM-DD", "commit": "<sha>", "report": "<path>"},
     "every_days": 14, "every_commits": 300,
     "budgets": {"start_read_tokens": 4500, "start_read_warn_tokens": 3500, "handoff_lines": 40, "file_kb": 500, "duplicate_lines": 20,
                 "rules": 35, "project_rules": 15},
     "start_read": [], "ignore": ["ref/**"],
     "timings": {"tests": {"cmd": "tests/run.sh", "seconds": 20.8, "max_slowdown": 0.25},
                 "check": {"cmd": "bash scripts/check.sh", "seconds": 4.5, "steps": {"pii_guard self-test": 4.1}},
                 "push-guard": {"seconds": 0.4}}}
A timing with no "cmd" is only compared (--compare), never run by --time.
start_read_warn_tokens only warns (never "over", never fails --strict); set it to the cap to turn the warning off.
A repo with no "last_audit" reports AUDIT DUE (never audited) once it is every_days or every_commits past its first
commit (a new project is not due on day one; an older project synced for the first time usually is). The first audit
creates the file. Exit 0, unless --strict and something is over (exit 1). Standard library only. Needs git.
"""
import argparse
import contextlib
import datetime
import io
import fnmatch
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

CONFIG = ".bloat-audit.json"
START_READ = ["AGENTS.md", "CLAUDE.md", "docs/NEXT_PROMPT.md"]
DEFAULTS = {"every_days": 14, "every_commits": 300,
            "budgets": {"start_read_tokens": 4500, "start_read_warn_tokens": 3500, "handoff_lines": 40, "file_kb": 500,
                        "duplicate_lines": 20, "rules": 35, "project_rules": 15}}
RULES_FILE = "AGENTS.md"
PROJECT_RULES = "## Project rules"
NOT_RULES = {"## Commands"}  # project-owned settings, not rules
RANKED = {"## Order of authority"}  # its numbered ranking of sources is not a rule count; a bullet there is
OPTIONAL = {"scripts/check.local.sh"}  # named in AGENTS.md, present only when the project has tests
TEXT_EXT = {".md", ".txt", ".py", ".sh", ".ps1", ".psm1", ".js", ".ts", ".json", ".yml", ".yaml", ".html", ".css",
            ".toml", ".ini", ".cfg", ".csv", ""}
VAGUE = ["appropriate", "appropriately", "as needed", "if needed", "when needed", "where possible", "if possible",
         "when possible", "properly", "reasonable", "be careful", "try to", "consider", "etc.", "best practice",
         "as much as", "usually", "generally", "ideally", "maybe", "might", "should"]
VALUE_OPTIONS = {"-o", "--output", "--out", "--outline"}  # options whose value is a file the command writes
NEAR_DUP = 0.6        # word overlap (Jaccard) from which two rule lines are a near-duplicate pair
RULE_TESTS = ".claude/rule-tests.md"
REVIEWS = "docs/reviews"
MIN_DUP = 80          # characters in a normalized line before it counts as a duplicate
MAX_SCAN = 1_000_000  # bytes; larger files are not scanned for duplicates


def git(root, *args):
    try:
        r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    except OSError:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def load_config(root):
    cfg = json.loads(json.dumps(DEFAULTS))
    p = root / CONFIG
    if p.exists():
        data = json.loads(p.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("top level is not an object")
        budgets = {**cfg["budgets"], **data.get("budgets", {})}
        cfg.update(data)
        cfg["budgets"] = budgets
    return cfg


def ignored(rel, cfg):
    return any(fnmatch.fnmatch(rel, g) for g in cfg.get("ignore", []))


def start_read(root, cfg):
    lines = size = 0
    files = []
    for rel in START_READ + cfg.get("start_read", []):
        p = root / rel
        if p.is_file():
            b = p.read_bytes()
            lines += b.count(b"\n")
            size += len(b)
            files.append((rel, len(b)))
    return lines, size, size // 4, sorted(files, key=lambda f: -f[1])


ITEM = re.compile(r"^\s*(?:[-*+]|(\d+)[.)])\s+(.*)$")
RULE_HR = re.compile(r"^\s*([-*_])(\s*\1){2,}\s*$")           # --- or * * *: a horizontal rule, not a rule
TABLE_SEP = re.compile(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$")  # |---|---|: the row above it is a header
HEADING = re.compile(r"^\s*#{1,6}(\s|$)")                    # "### Sub"; "#1 priority: ..." is text, not a heading
EMPTY_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s*$")         # a marker with no text


def rule_lines(text, with_sections=False):
    """Return (kit, project, every): the rule lines of an AGENTS.md text, by where they are.

    A rule line is a list item with any marker ("- ", "* ", "+ ", "1. ") at any indent; a line that follows it with
    no blank line between is its continuation, not a new rule. kit = items under a "## " heading above
    "## Project rules" (not the header, not NOT_RULES sections; in RANKED sections the numbered ranking is not
    counted, a bullet is); project = items under "## Project rules", and there also each paragraph and each table
    row (not the header row), so a rule that is not a bullet still counts; there a line continues the item above it
    only when it is indented (an unindented line is a new rule: a count may be too high, never too low); every = the
    items of all sections, for the list of changed lines. Not counted anywhere: blank lines, "###" sub-headings,
    horizontal rules, table separator rows (they contain "|"), markers with no text, lines in ``` or ~~~ fences,
    <!-- comments -->. In the kit itself the file marks tier text
    with <!-- starter --> blocks: those are dropped, so the count is the full tier.
    """
    text = re.sub(r"(?ms)^<!-- starter -->\n.*?^<!-- /starter -->\n", "", text)
    text = re.sub(r"(?s)<!--.*?-->", "", text)
    rows, sec, fenced, open_item = [], None, False, False  # rows: [section, text, counted]
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            fenced, open_item = not fenced, False
        elif fenced:
            continue
        elif line.startswith("## "):
            sec, open_item = line.rstrip(), False
        elif not sec:
            continue
        elif not line.strip() or HEADING.match(line) or RULE_HR.match(line) or EMPTY_ITEM.match(line):
            open_item = False
        elif TABLE_SEP.match(line) and "-" in line and "|" in line:
            if open_item and rows and "|" in rows[-1][1]:
                rows.pop()  # the header row of a table
            open_item = False
        else:
            m = ITEM.match(line)
            indented = line[:1] in (" ", "\t")
            if m:
                counted = sec not in NOT_RULES and not (sec in RANKED and m.group(1))
                rows.append([sec, m.group(2).strip(), counted])
                open_item = True
            elif open_item and not line.lstrip().startswith("|") and (indented or sec != PROJECT_RULES):
                rows[-1][1] += " " + line.strip()  # a wrapped line belongs to the item above it
            elif sec == PROJECT_RULES:
                rows.append([sec, line.strip(), True])
                open_item = True
    if with_sections:
        return [(s_[3:].strip(), t) for s_, t, c in rows if c]
    kit = [t for s_, t, c in rows if c and s_ != PROJECT_RULES]
    project = [t for s_, t, c in rows if c and s_ == PROJECT_RULES]
    return kit, project, [t for _, t, _ in rows]


def words(line):
    return set(re.findall(r"[a-z0-9][a-z0-9'-]{2,}", line.lower()))


def tested_sections(root):
    """Sections of AGENTS.md that have a scenario: the "Section" column of the table in .claude/rule-tests.md."""
    p = root / RULE_TESTS
    if not p.is_file():
        return None
    out, col = set(), None
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if col is None and "Section" in cells:
            col = cells.index("Section")
        elif col is not None and len(cells) > col and not TABLE_SEP.match(line):
            out |= {c.strip() for c in cells[col].split(";")}
    return out


def lint(root, rules, only=None):
    """Rule lint, warn only. rules: [(section, text)]; only: the lines to report on (None = all).
    Returns WARN lines: near-duplicate pairs, vague words, untested rules."""
    tested = tested_sections(root)
    out = []
    for i, (_, a) in enumerate(rules):
        for _, b in rules[i + 1:]:
            if only is not None and a not in only and b not in only:
                continue
            wa, wb = words(a), words(b)
            j = len(wa & wb) / len(wa | wb) if wa | wb else 0
            if j >= NEAR_DUP:
                out.append(f"WARN  rule lint: near-duplicate ({j:.0%} same words): \"{a[:70]}\" ~ \"{b[:70]}\"")
    for sec, t in rules:
        if only is not None and t not in only:
            continue
        low = " " + re.sub(r"`[^`]*`", " ", t.lower()) + " "
        hits = [v for v in VAGUE if re.search(r"(?<![a-z])" + re.escape(v) + r"(?![a-z])", low)]
        if hits:
            out.append(f"WARN  rule lint: vague ({', '.join(hits)}): \"{t[:90]}\"")
        if tested is not None and sec not in tested and not re.search(r"`scripts/[^`]+`|Enforced by", t):
            out.append(f"WARN  rule lint: untested (no scenario for \"{sec}\" in {RULE_TESTS}, no script named): \"{t[:80]}\"")
    return out


def conflict_hash(added, removed):
    """The hash a conflict-check record names: the changed rule lines, sorted, + and - kept apart."""
    import hashlib
    text = "\n".join(sorted("+" + l for l in added) + sorted("-" + l for l in removed))
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def conflict_recorded(root, h):
    d = root / REVIEWS
    return d.is_dir() and any(f"rule-conflict-check: {h}" in f.read_text(encoding="utf-8", errors="replace")
                              for f in d.rglob("*.md"))


def missing_pointers(root, text):
    """Paths that AGENTS.md names and that do not exist: each `.claude/...`, `scripts/...` and `docs/...` path
    inside backticks (also after a command word: `python3 scripts/x.py --test`), and relative link targets. Not a
    path to check: the value of an output option (`-o docs/out.html`: a file the command makes; VALUE_OPTIONS); a line number
    (`scripts/a.py:12`) and a pipe or ; or & after a path are cut off."""
    text = re.sub(r"(?ms)^<!-- starter -->\n.*?^<!-- /starter -->\n", "", text)
    names = set()
    for span in re.findall(r"`([^`\n]+)`", text):
        words = re.split(r"[\s|;&]+", span)
        for prev, w in zip([""] + words, words):
            w = re.sub(r"(:\d+)+$", "", w.rstrip(".,;:)"))
            if re.match(r"(?:\.claude|scripts|docs)/", w) and prev not in VALUE_OPTIONS:
                names.add(w)
    names -= OPTIONAL
    names |= {t.split("#")[0] for t in re.findall(r"\]\(([^)\s]+)\)", text)
              if "://" not in t and not t.startswith(("#", "mailto:"))}
    return sorted(n for n in names if n and not re.search(r"[<>*{]", n) and not (root / n).exists())


def rules_report(root, cfg, gate=False):
    """Return (lines to print, problems). Problems fail scripts/check.sh: a cap passed, a missing path, and with gate
    (the full lane) rule lines changed against origin/main with no conflict-check record in docs/reviews/."""
    p = root / RULES_FILE
    if not p.is_file():
        return [f"rules:       no {RULES_FILE}"], []
    text = p.read_text(encoding="utf-8", errors="replace")
    b = cfg["budgets"]
    kit, project, every = rule_lines(text)
    out = [f"rules:       {RULES_FILE} {len(kit)} (cap {b['rules']}) · Project rules {len(project)} (cap {b['project_rules']})"]
    problems = []
    if len(kit) > b["rules"]:
        problems.append(f"rules over the cap ({len(kit)} > {b['rules']})")
    if len(project) > b["project_rules"]:
        problems.append(f"project rules over the cap ({len(project)} > {b['project_rules']})")
    old = None
    for ref in ("origin/main", "origin/master"):
        old = git(root, "show", f"{ref}:{RULES_FILE}")
        if old is not None:
            break
    if old is not None:
        was = set(rule_lines(old)[2])
        now = set(every)
        added, removed = [l for l in every if l not in was], sorted(was - now)
        for mark, lines in (("+", added), ("-", removed)):
            out += [f"  {mark} {l}" for l in lines]  # the whole line: a change near its end must show
        if was != now:
            out.append("  (rule lines changed against the default branch: each one needs the owner's approval of its exact text)")
            h = conflict_hash(added, removed)
            if conflict_recorded(root, h):
                out.append(f"  conflict check: recorded (rule-conflict-check: {h})")
            else:
                need = (f"no fresh-context conflict check for these lines: run it (.claude/skills/rule-change/SKILL.md) "
                        f"and record the line \"rule-conflict-check: {h}\" in {REVIEWS}/")
                if gate:
                    problems.append(need)
                else:
                    out.append(f"WARN  {need} (the full lane fails without it)")
            out += lint(root, rule_lines(text, with_sections=True), only=set(added))
    gone = missing_pointers(root, text)
    if gone:
        problems.append("missing paths named in AGENTS.md: " + ", ".join(gone))
    for pr in problems:
        out.append(f"RULES FAIL:  {pr}")
    return out, problems


def norm(line):
    line = re.sub(r"^[\s>#|*\-+0-9.]+", "", line)
    return re.sub(r"\s+", " ", line).strip().lower()


def scan_files(root, cfg):
    out = git(root, "ls-files")
    return [rel for rel in (out.splitlines() if out else []) if not ignored(rel, cfg) and (root / rel).is_file()]


def duplicates(root, files):
    seen = {}
    for rel in files:
        p = root / rel
        if p.suffix.lower() not in TEXT_EXT or p.stat().st_size > MAX_SCAN:
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        generated = False
        for line in text.splitlines():
            # Text between "# >>> ... generated from ..." and "# <<< ..." is a copy a build script writes and checks
            # (90-161.Z: bloat audit 3, P2; the PFM, 2026-11-15): it is not counted, so a hand-made duplicate stays visible.
            mark = line.strip()
            if mark.startswith("# >>> ") and "generated from" in mark:
                generated = True
                continue
            if mark.startswith("# <<< "):
                generated = False
                continue
            if generated:
                continue
            n = norm(line)
            if len(n) >= MIN_DUP:
                seen.setdefault(n, set()).add(rel)
    dups = [(n, sorted(fs)) for n, fs in seen.items() if len(fs) > 1]
    return sorted(dups, key=lambda d: -len(d[1]))


def big_files(root, files, kb):
    return sorted(((rel, (root / rel).stat().st_size // 1024) for rel in files
                   if (root / rel).stat().st_size > kb * 1024), key=lambda f: -f[1])


def audit_due(root, cfg, today):
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


def run_timings(root, cfg, record):
    rows, slow = [], []
    for name, t in cfg.get("timings", {}).items():
        if not t.get("cmd"):
            continue  # measured by the script that runs it (--compare)
        t0 = time.monotonic()
        rc = subprocess.run(t["cmd"], shell=True, cwd=root, capture_output=True).returncode
        secs = round(time.monotonic() - t0, 1)
        base = t.get("seconds")
        limit = t.get("max_slowdown", 0.25)
        verdict = "FAILED" if rc else "new" if base is None else ("SLOWER" if secs > base * (1 + limit) else "ok")
        if verdict in ("SLOWER", "FAILED"):
            slow.append(name)
        rows.append(f"  {name}: {secs} s (baseline {base or '-'} s, limit +{int(limit * 100)}%, exit {rc}) {verdict}")
        if record and not rc:
            t["seconds"] = secs
    return rows, slow


def compare_times(cfg, pairs, record=False):
    """pairs: [(name, seconds)]; name is a timings key, or "key:step" for one of its "steps". Returns (line, slow).
    Warn only: a slowdown is reported, never a failure (the owner, 2026-11-16)."""
    timings = cfg.setdefault("timings", {})
    slow, new, n = [], [], 0
    for name, secs in pairs:
        key, _, step = name.partition(":")
        entry = timings.setdefault(key, {}) if record else timings.get(key, {})
        base = entry.get("steps", {}).get(step) if step else entry.get("seconds")
        limit = entry.get("max_slowdown", 0.25)
        floor = entry.get("min_slowdown_seconds", 0.5)
        if base is None:
            new.append(name)
        elif secs > base * (1 + limit) and secs - base >= floor:
            slow.append(f"{step or key} {secs} s (baseline {base} s, +{round((secs / base - 1) * 100) if base else 999}%)")
        n += 1
        if record:
            if step:
                entry.setdefault("steps", {})[step] = secs
            else:
                entry["seconds"] = secs
    if record:
        return f"TIME  baseline recorded for {n} time(s) in {CONFIG}", []
    if slow:
        return ("WARN  slower than the baseline: " + "; ".join(slow) +
                ". Next: .claude/skills/efficiency/SKILL.md (a measured slowdown starts it)"), slow
    tail = f"; no baseline yet for {len(new)} ({', '.join(new)}): .claude/skills/efficiency/SKILL.md, Record a baseline" if new else ""
    return f"TIME  baseline: {n - len(new)} of {n} within the limit{tail}", []


def main_compare(root, items, record):
    try:
        cfg = load_config(root)
        pairs = [(i.rsplit("=", 1)[0], round(float(i.rsplit("=", 1)[1]), 1)) for i in items]
    except (ValueError, TypeError, KeyError, IndexError) as e:
        print(f"TIME  baseline: not compared ({e})")
        return 0
    line, _ = compare_times(cfg, pairs, record)
    if record:
        p = root / CONFIG
        data = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
        data["timings"] = cfg["timings"]
        p.write_text(json.dumps(data, indent=2) + "\n")
    print(line)
    return 0


def report(root, args, today=None):
    today = today or datetime.date.today()
    try:
        cfg = load_config(root)
        due = audit_due(root, cfg, today)
    except (ValueError, TypeError, KeyError) as e:
        print(f"bloat:       {CONFIG} unreadable ({e}); fix it, then run scripts/bloat_check.py")
        return 1 if args.strict else 0
    b = cfg["budgets"]
    files = scan_files(root, cfg)
    s_lines, s_bytes, s_tok, s_files = start_read(root, cfg)
    hp = root / "docs/NEXT_PROMPT.md"
    h_lines = hp.read_bytes().count(b"\n") if hp.exists() else 0
    dups = duplicates(root, files)
    big = big_files(root, files, b["file_kb"])
    over = []
    if s_tok > b["start_read_tokens"]:
        over.append("start read")
    # Early warning only (never fails --strict): rule growth shows before the hard cap (kit default, 2026-11-13).
    warn = "start read over warning" if b.get("start_read_warn_tokens", 0) < s_tok <= b["start_read_tokens"] else ""
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
        data = json.loads((root / CONFIG).read_text(encoding="utf-8")) if (root / CONFIG).exists() else {}
        data["timings"] = cfg.get("timings", {})
        (root / CONFIG).write_text(json.dumps(data, indent=2) + "\n")

    tail = (f"AUDIT DUE ({due}): tell the owner and ask whether to run the audit skill (.claude/skills/audit/SKILL.md, "
            "about 1 hour of agent time); never start it unasked") if due else "audit not due"
    if args.brief:
        print(f"bloat:       start read ~{s_tok:,} tokens (budget {b['start_read_tokens']:,}) · {r_rows[0][13:]} · duplicate lines "
              f"{len(dups)} · big files {len(big)} · over: {', '.join(over) or 'none'}{' · ' + warn if warn else ''} · {tail}")
    else:
        print(f"start read:  {s_lines} lines, {s_bytes:,} bytes, ~{s_tok:,} tokens (budget {b['start_read_tokens']:,})")
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
            print(f"warning:     {warn} ({b['start_read_warn_tokens']:,} tokens); trim rules before the cap")
        print(tail)
    return 1 if args.strict and (over or due) else 0


def self_test():
    # The host's git config (forced signing, -c on the command line) must not change the cases.
    for k in ("GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT"):
        os.environ.pop(k, None)
    os.environ.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        long = "This line is long enough to count as a duplicate when it shows up in two different files of a repo."
        (root / "AGENTS.md").write_text(f"# A\n- {long}\n")
        (root / "docs").mkdir()
        (root / "docs/NEXT_PROMPT.md").write_text(f"{long.upper()}\n" + "x\n" * 45)
        (root / "big.txt").write_text("y" * 3000)
        (root / CONFIG).write_text(json.dumps({"budgets": {"file_kb": 2, "start_read_tokens": 10},
                                               "last_audit": {"date": "2026-01-01"},
                                               "timings": {"t": {"cmd": "true", "seconds": 5}}}))
        subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
        cfg = load_config(root)
        files = scan_files(root, cfg)
        assert len(duplicates(root, files)) == 1, "duplicate across files, case and bullets ignored"
        gen = "x = 1\n# >>> blk: generated from src by build (do not edit)\n" + "g" * 90 + "\n# <<< blk\n"
        (root / "g1.ps1").write_text(gen)
        (root / "g2.ps1").write_text(gen + "h" * 90 + "\n")
        (root / "g3.ps1").write_text("h" * 90 + "\n")
        subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
        assert len(duplicates(root, scan_files(root, cfg))) == 2, "generated block not counted; a line after its end marker is counted"
        for g in ("g1.ps1", "g2.ps1", "g3.ps1"):
            (root / g).unlink()
        subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
        assert [f for f, _ in big_files(root, files, 2)] == ["big.txt"], "big file"
        assert "days since" in audit_due(root, cfg, datetime.date(2026, 2, 1)), "due by days"
        assert audit_due(root, cfg, datetime.date(2026, 1, 5)) == "", "not due"
        never = {**cfg, "last_audit": None}
        assert audit_due(root, never, datetime.date(2026, 1, 5)) == "never audited", "no commits: due"
        with tempfile.TemporaryDirectory() as n:
            subprocess.run(["git", "init", "-q", n], check=True)
            env = {**os.environ, "GIT_AUTHOR_DATE": "2026-01-01T12:00:00Z", "GIT_COMMITTER_DATE": "2026-01-01T12:00:00Z"}
            subprocess.run(["git", "-C", n, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty",
                            "-m", "first"], check=True, env=env)
            first = datetime.date(2026, 1, 1)
            assert audit_due(Path(n), never, first) == "", "never audited, new repo: not due yet"
            assert audit_due(Path(n), never, first + datetime.timedelta(days=14)).startswith("never audited;"), "due by days"
            assert audit_due(Path(n), {**never, "every_commits": 1}, first).startswith("never audited;"), "due by commits"
            subprocess.run(["git", "-C", n, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty",
                            "-m", "second"], check=True, env=env)
            s = str(Path(n).parent / (Path(n).name + "-shallow"))
            subprocess.run(["git", "clone", "-q", "--depth", "1", "file://" + n, s], check=True, capture_output=True)
            try:
                assert audit_due(Path(s), never, first) == "never audited", "shallow clone: due"
            finally:
                subprocess.run(["rm", "-rf", s], check=True)
        rows, slow = run_timings(root, cfg, record=False)
        assert not slow and "ok" in rows[0], "fast command is ok"
        a = argparse.Namespace(brief=False, time=False, record=False, strict=True)
        with contextlib.redirect_stdout(io.StringIO()):
            assert report(root, a, datetime.date(2026, 1, 5)) == 1, "strict fails when over budget"
        # Rules: count by place, caps, changed lines against origin/main, and paths that must exist.
        sample = ("# T\n\n- Repo: x\n\n## Git safety\n\n- Rule one.\n- Rule two.\n<!-- starter -->\n- Starter only.\n"
                  "<!-- /starter -->\n```\n- in a fence\n```\n\n## Commands\n\n- Build: none.\n\n## Project rules\n\n"
                  "<!-- - a comment -->\n- Project rule.\n")
        kit, project, every = rule_lines(sample)
        assert kit == ["Rule one.", "Rule two."] and project == ["Project rule."], "header, Commands, fences, comments and starter blocks are not rules"
        assert "Build: none." in every, "the list of changed lines also covers sections that are not counted"
        assert rule_lines("## A\n\n- Rule start\n  continues with a | b here.\n")[0] == ["Rule start continues with a | b here."], "a continuation with a pipe stays in its rule (a change to it shows)"
        kit, project, _ = rule_lines("## A\n\n* Star.\n1. Numbered.\n  - Nested.\nA paragraph.\n\n## Project rules\n\n+ Plus.\n  wrapped.\nA rule as a paragraph.\n")
        assert kit == ["Star.", "Numbered.", "Nested. A paragraph."] and project == ["Plus. wrapped.", "A rule as a paragraph."], "every list marker counts; in the kit a line right below an item continues it, in Project rules only an indented one"
        _, project, _ = rule_lines("## Project rules\n\nRule one.\nRule two.\nRule three.\n\n- Bullet.\nAfter a bullet.\n\n#1 priority: never do X.\n")
        assert project == ["Rule one.", "Rule two.", "Rule three.", "Bullet.", "After a bullet.", "#1 priority: never do X."], "Project rules: unindented lines are rules each; '#1' is text, not a heading"
        _, project, _ = rule_lines("## Project rules\n\nRule | Why\n--- | ---\nT one | x\nT two | y\n\n| R | W |\n|---|---|\n| T three | z |\n-\n")
        assert project == ["T one | x", "T two | y", "| T three | z |"], "tables without leading pipes: one rule per row; a lone '-' removes no row"
        kit, project, every = rule_lines("## Order of authority\n\n1. The owner.\n2. This file.\n- A bullet here counts.\n\n## B\n\n- One rule,\n  wrapped.\n~~~\n- in a tilde fence\n~~~\n* * *\n---\n### Sub\n\n"
                                         "## Project rules\n\n### Group\n\n- P one,\n  wrapped.\n\nA paragraph rule\nover two lines.\n\n---\n\n| Rule | Why |\n|---|---|\n| T one | x |\n| T two | y |\n")
        assert kit == ["A bullet here counts.", "One rule, wrapped."], "the ranking is not counted, a bullet in that section is; wraps, fences, rules and sub-headings are not rules"
        assert project == ["P one, wrapped.", "A paragraph rule", "over two lines.", "| T one | x |", "| T two | y |"], "Project rules: wrapped bullet 1, an unindented paragraph line 1 each, table rows without header and separator"
        assert "The owner." in every, "ranking lines are still listed when they change"
        with tempfile.TemporaryDirectory() as o:
            g = lambda *c: subprocess.run(["git", "-C", o, "-c", "user.email=t@t", "-c", "user.name=t", *c], check=True, capture_output=True)
            g("init", "-q", "-b", "main")
            ro = Path(o)
            (ro / "AGENTS.md").write_text("## A\n\n- Old rule.\n- Kept rule.\n\n## Project rules\n\n")
            g("add", "-A"); g("commit", "-q", "-m", "a"); g("update-ref", "refs/remotes/origin/main", "HEAD")
            caps = {"budgets": {**DEFAULTS["budgets"], "rules": 2, "project_rules": 1}}
            (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n\n## Project rules\n\n- P1.\n")
            rows, problems = rules_report(ro, caps)
            assert not problems, "at the cap is not over"
            assert any(r.startswith("  + New rule.") for r in rows) and any(r.startswith("  - Old rule.") for r in rows), "a swap is listed"
            (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n- Third.\n\n## Project rules\n\n- P1.\n- P2.\n")
            rows, problems = rules_report(ro, caps)
            assert len(problems) == 2 and "rules over the cap (3 > 2)" in problems[0] and "project rules over" in problems[1], "both caps fail"
            (ro / "AGENTS.md").write_text("## A\n\n- See `.claude/skills/x/SKILL.md` and [doc](docs/gone.md), [web](https://e.example/a), `.claude/skills/<name>/`, `scripts/gone.sh --fast`, `scripts/check.local.sh`, `python3 scripts/gone2.py --test`, `scripts/tool.sh -o docs/out.html`, `scripts/gone2.py:12`, `scripts/gone.sh|tee x`, `bash -x scripts/gone3.sh`, `x --output docs/a.md --out docs/b.md --outline docs/c.md`.\n")
            rows, problems = rules_report(ro, caps)
            assert problems == ["missing paths named in AGENTS.md: .claude/skills/x/SKILL.md, docs/gone.md, scripts/gone.sh, scripts/gone2.py, scripts/gone3.sh, scripts/tool.sh"], "missing paths (also after a command word, with a line number or a pipe), not URLs, patterns, optional files or option values"
            (ro / ".claude/skills/x").mkdir(parents=True); (ro / ".claude/skills/x/SKILL.md").write_text("x")
            (ro / "docs").mkdir(); (ro / "docs/gone.md").write_text("x")
            (ro / "scripts").mkdir(); (ro / "scripts/gone.sh").write_text("x"); (ro / "scripts/gone2.py").write_text("x"); (ro / "scripts/tool.sh").write_text("x"); (ro / "scripts/gone3.sh").write_text("x")
            assert rules_report(ro, caps)[1] == [], "paths exist: pass"
            # Conflict gate: changed rule lines need a record that names their hash; without --gate only a WARN line.
            (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n\n## Project rules\n\n")
            h = conflict_hash(["New rule."], ["Old rule."])
            assert h == conflict_hash(["New rule."], ["Old rule."]) != conflict_hash(["Old rule."], ["New rule."]), "the hash keeps + and - apart"
            rows, problems = rules_report(ro, caps)
            assert not problems and any(r.startswith("WARN") and h in r for r in rows), "no record, no gate: a WARN line with the hash"
            rows, problems = rules_report(ro, caps, gate=True)
            assert len(problems) == 1 and h in problems[0], "no record, gate: fails"
            (ro / "docs").mkdir(exist_ok=True); (ro / "docs/reviews").mkdir()
            (ro / "docs/reviews/r.md").write_text(f"Result: no conflict.\nrule-conflict-check: {'0' * 12}\n")
            assert rules_report(ro, caps, gate=True)[1], "a record for other lines does not count"
            (ro / "docs/reviews/r.md").write_text(f"Result: no conflict.\nrule-conflict-check: {h}\n")
            rows, problems = rules_report(ro, caps, gate=True)
            assert not problems and any("conflict check: recorded" in r for r in rows), "a record with the hash passes"
            (ro / "AGENTS.md").write_text("## A\n\n- Old rule.\n- Kept rule.\n\n## Project rules\n\n")
            assert not rules_report(ro, caps, gate=True)[1], "no changed lines: no gate"
            # Lint: near-duplicates, vague words, untested rules (a section with no scenario, no script named).
            (ro / ".claude").mkdir(exist_ok=True)
            (ro / ".claude/rule-tests.md").write_text("| # | Rule tested | Section | Prompt |\n|---|---|---|---|\n| 1 | x | Tested; Other | p |\n")
            rules = [("Tested", "Never push to main without the full check lane passing first."),
                     ("Tested", "Never push to main without the full check lane passing."),
                     ("Tested", "Use the right tool where possible."),
                     ("Untested", "Keep the handoff short."), ("Untested", "The hook enforces it: `scripts/x.sh`."),
                     ("Other", "Run `git clean` never.")]
            flags = lint(ro, rules)
            assert sum("near-duplicate" in f for f in flags) == 1, "one near-duplicate pair"
            assert [f for f in flags if "vague" in f] == ['WARN  rule lint: vague (where possible): "Use the right tool where possible."'], "vague word; text in backticks is not read"
            assert [f for f in flags if "untested" in f] == ['WARN  rule lint: untested (no scenario for "Untested" in .claude/rule-tests.md, no script named): "Keep the handoff short."'], "untested: no scenario and no script; a ';' list of sections counts each"
            assert lint(ro, rules, only={"Keep the handoff short."}) == [f for f in flags if "handoff" in f], "only: the changed lines"
            (ro / ".claude/rule-tests.md").unlink()
            assert not [f for f in lint(ro, rules) if "untested" in f], "no rule-tests file (starter tier): no untested flags"
            (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n\n## Project rules\n\n- See `.claude/skills/x/SKILL.md` and [doc](docs/gone.md), `scripts/gone.sh`, `scripts/gone2.py`, `scripts/tool.sh`.\n")
            with contextlib.redirect_stdout(io.StringIO()):
                assert main_rules(ro) == 0, "--rules passes"
                assert main_lint(ro) == 0, "--lint never fails"
                (ro / "AGENTS.md").write_text("## A\n\n" + "- r.\n" * 36)
                assert main_rules(ro) == 1, "--rules fails over the default cap of 35"
        (root / CONFIG).write_text(json.dumps({"budgets": {"start_read_warn_tokens": 1, "start_read_tokens": 99999},
                                               "last_audit": {"date": "2026-01-01"}}))
        w = io.StringIO()
        with contextlib.redirect_stdout(w):
            report(root, argparse.Namespace(brief=True, time=False, record=False, strict=False), datetime.date(2026, 1, 5))
        assert "over warning" in w.getvalue() and "over: start read" not in w.getvalue(), "warning, not over"
        with contextlib.redirect_stdout(io.StringIO()):
            assert audit_due(root, {**cfg, "last_audit": {"date": "2026-01-01", "commit": "f" * 40}},
                             datetime.date(2026, 1, 5)) == "", "unknown commit alone is not due"
            (root / CONFIG).write_text("{bad")
            assert report(root, a, datetime.date(2026, 1, 5)) == 1, "bad config: message, no traceback"
            (root / CONFIG).write_text(json.dumps({"timings": {"f": {"cmd": "false"}, "t": {"cmd": "true"}}}))
            report(root, argparse.Namespace(brief=True, time=True, record=True, strict=False))
        saved = json.loads((root / CONFIG).read_text())["timings"]
        assert "seconds" not in saved["f"] and saved["t"]["seconds"] is not None, "record skips failed commands"
        tc = {"timings": {"check": {"seconds": 4.0, "steps": {"a": 2.0, "tiny": 0.1}}}}
        line, slow = compare_times(json.loads(json.dumps(tc)), [("check", 4.4), ("check:a", 2.4), ("check:tiny", 0.3)])
        assert not slow and line.startswith("TIME  baseline: 3 of 3"), "within +25%, or under 0.5 s slower: ok"
        line, slow = compare_times(json.loads(json.dumps(tc)), [("check", 5.2), ("check:a", 2.0), ("check:new", 1.0)])
        assert slow == ["check 5.2 s (baseline 4.0 s, +30%)"] and line.startswith("WARN") and "efficiency" in line, "a slowdown warns and names the skill"
        line, _ = compare_times(json.loads(json.dumps(tc)), [("check:new", 1.0)])
        assert "no baseline yet for 1 (check:new)" in line and "Record a baseline" in line, "no baseline: says how to record one"
        rec = json.loads(json.dumps(tc))
        compare_times(rec, [("check", 3.0), ("check:new", 1.0), ("other", 0.2)], record=True)
        assert rec["timings"]["check"]["seconds"] == 3.0 and rec["timings"]["check"]["steps"]["new"] == 1.0 and rec["timings"]["other"]["seconds"] == 0.2, "record stores wall, step and a new key"
        (root / CONFIG).write_text(json.dumps({"budgets": {}, **tc}))
        with contextlib.redirect_stdout(io.StringIO()):
            assert main_compare(root, ["check:a=9", "bad"], False) == 0, "a bad item: no failure"
            main_compare(root, ["check:a=1.25"], True)
        assert json.loads((root / CONFIG).read_text())["timings"]["check"]["steps"]["a"] == 1.2 and "budgets" in json.loads((root / CONFIG).read_text()), "--record keeps the other keys"
        rows, _ = run_timings(root, {"timings": {"nocmd": {"seconds": 1}}}, record=False)
        assert rows == [], "--time skips a timing with no cmd"
    print("BLOAT TEST PASS")


def main_lint(root):
    p = root / RULES_FILE
    rules = rule_lines(p.read_text(encoding="utf-8", errors="replace"), with_sections=True) if p.is_file() else []
    rows = lint(root, rules)
    print("\n".join(rows + [f"LINT: {len(rows)} flag(s) in {len(rules)} rule lines (warn only)"]))
    return 0


def main_rules(root, gate=False):
    try:
        cfg = load_config(root)
    except (ValueError, TypeError, KeyError) as e:
        print(f"rules:       {CONFIG} unreadable ({e}); fix it first")
        return 1
    rows, problems = rules_report(root, cfg, gate)
    print("\n".join(rows))
    print("RULES FAIL" if problems else "RULES PASS")
    return 1 if problems else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--rules", action="store_true")
    ap.add_argument("--brief", action="store_true")
    ap.add_argument("--time", action="store_true")
    ap.add_argument("--record", action="store_true")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--compare", nargs="+", metavar="NAME=SECONDS")
    ap.add_argument("--gate", action="store_true")
    ap.add_argument("--lint", action="store_true")
    ap.add_argument("--project", default=".")
    args = ap.parse_args()
    if args.test:
        self_test()
        return 0
    root = Path(git(Path(args.project), "rev-parse", "--show-toplevel") or args.project)
    if args.lint:
        return main_lint(root)
    if args.rules:
        return main_rules(root, args.gate)
    if args.compare:
        return main_compare(root, args.compare, args.record)
    return report(root, args)


if __name__ == "__main__":
    sys.exit(main())
