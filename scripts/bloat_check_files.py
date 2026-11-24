#!/usr/bin/env python3
"""The repo's own files in the bloat check (`python3 scripts/bloat_check.py --rules`): the tool rows of docs/tools.md (T1), the
script lines ratchet (T2), the old role word in kit-synced text (T6) and the triggers of the fleet debt record (T5).
The rule lines of AGENTS.md are read by scripts/bloat_check_rules.py and the skills by scripts/bloat_check_skills.py; this
file reads every other file. Plan: docs/reviews/2026-11-23-tool-retirement-plan.md.

Prevents: a tool file that no one searched a standard tool for (T1), custom script lines that grow with no decision (T2), a
kit text that writes the role word of one project (T6), and a check or rule change that lands with no list of what it
fails in the fleet (T5).

Inputs:  the repo root, docs/tools.md, .check.state.json, scripts/sync_baseline.py (read as text, never run), the files it
         lists, docs/DECISIONS.md and docs/reviews/ here and on origin/main.
Outputs: lists of lines and problems for the caller (scripts/bloat_check.py prints them); rules_report is the full `--rules`
         report (scripts/bloat_check_rules.py plus these checks). The levels: FAIL in the kit, WARN or SKIP in a project.
Run:     imported by scripts/bloat_check.py; proved by `python3 scripts/bloat_check.py --test`.
Network: none (it runs local git read commands).
Writes: none.
Credentials: none.
"""
import ast
import json
import re

import bloat_check_rules as brules   # scripts/bloat_check_rules.py: git, the rule lines, the record readers
import check_settings   # scripts/check_settings.py: the reader of .check.state.json
import log_check_plan as plan   # scripts/log_check_plan.py: the DECISIONS table cells


TOOL_EXT = (".py", ".sh", ".ps1", ".psm1", ".js", ".mjs", ".cjs", ".bat", ".cmd")
TOOL_SKIP = ("node_modules/", "vendor/", "dist/")   # not the repo's own tools
TOOLS_DOC = "docs/tools.md"
STATE_KEY = "script_lines"   # in .check.state.json: {"baseline": N, "command": ..., "measured": ..., "commit": ...}
# T2: the By cell of a baseline row: "the Maintainer:", then the approval in quotes, then a date after the quote
APPROVED_BY = re.compile(r'the Maintainer:\s*(?:"[^"\S\n]*[^"\s][^"\n]*"|“[^”\S\n]*[^”\s][^”\n]*”).*?(?<!\d)\d{4}-\d\d-\d\d(?!\d)', re.I)
ROLE_WORD = re.compile(r"\bthe owner\b|\bOwner's\b")
DATED = re.compile(r"\(the owner, \d{4}-\d{2}-\d{2}")   # an attribution that records a past role word stays as written
# The files that hold the check itself name the word they look for: allowed whole (re.compile(".")).
# The lines of kit-synced text and of the files that test it that may hold the old role word: file -> one regex for each kept line.
# Never a whole file. The regexes say "the[ ]owner" so that this list does not match itself.
ROLE_ALLOW = {
    "scripts/bloat_check_files.py": [r"^ROLE_WORD = re\.compile\(", r"^DATED = re\.compile\("],   # the searched patterns
    "scripts/bloat_check_test_rules.py": [r"Never rename the[ ]owner inside this script",   # test text of the sync script
                                          r"the[ ]owner decides\\nRule",   # the test lines with the searched word
                                          r'"the[ ]owner" \\xb7 B a role'],
    "scripts/log_check_plan.py": [r"\| Old row \| the[ ]owner \|"],   # a sample DECISIONS row of its self-test
    "scripts/sync_baseline.py": [r"Never rename the[ ]owner inside this script", r'use "the[ ]owner" as an answer option'],   # lines 116-117
    "scripts/sync_baseline_cli_test.py": [r'"the[ ]owner"', r"\| the[ ]owner \|", r"the[ ]owner word"],   # the words the sync swaps
    "docs/FIRST_USE.md": [r'agents call you "the[ ]owner"', r'A "the[ ]owner" \xb7 B a role', r'Give "the[ ]owner" as the 4th argument',
                          r"\(the[ ]owner, YYYY-MM-DD\)"],   # answer options and the attribution form a user types
}
ENTRY = re.compile(r"(?:python3|bash)\s+(scripts/[\w.-]+\.(?:py|sh))|^[ \t]*(?:selftest|extension)\s+\S+\s+(scripts/[\w.-]+\.(?:py|sh))", re.M)
CAPS_FILE = "scripts/check_settings_read.py"


def is_kit(root):
    """True in the kit itself: it has kit.config.json and no `.check.lock` (a synced project has the lock)."""
    return (root / "kit.config.json").is_file() and not (root / ".check.lock").exists()


def tool_files(root):
    """The tool files the repo owns: tracked scripts of a known extension in any folder, not a vendor folder, not a kit
    file of the lock (the kit's own docs/tools.md lists those).

    Args:
        root: the repo root (a Path).

    Returns:
        The sorted repo-relative paths.
    """
    out = brules.git(root, "ls-files")
    own = {rel for rel in (out.splitlines() if out else [])
           if rel.lower().endswith(TOOL_EXT) and not any(("/" + rel).find("/" + s) >= 0 for s in TOOL_SKIP)}
    try:
        locked = json.loads((root / ".check.lock").read_text(encoding="utf-8")).get("files") or {}
    except (ValueError, OSError, AttributeError):
        locked = {}
    return sorted(own - set(locked))


def tools_rows(root):
    """The data rows of the tables in docs/tools.md; the candidates column is the one whose header has "candidate".

    Args:
        root: the repo root (a Path).

    Returns:
        A list of (text of the first cell, text of the candidates cell).
    """
    p = root / TOOLS_DOC
    rows, col = [], None
    for line in (p.read_text(encoding="utf-8", errors="replace").splitlines() if p.is_file() else []):
        if not line.lstrip().startswith("|"):
            col = None
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        hit = [i for i, c in enumerate(cells) if "candidate" in c.lower()]
        if hit:
            col = hit[0]
        elif col is not None and not re.fullmatch(r"[\s|:-]+", line):
            rows.append((cells[0], cells[col] if col < len(cells) else ""))
    return rows


def names_tool(cell, rel):
    """True when the first cell of a docs/tools.md row names the tool file: its repo path, or its base name as a whole word.

    Args:
        cell: the text of the first cell of the row.
        rel: the repo-relative path of the tool file.

    Returns:
        True when the cell names the file.
    """
    base = r"(?<![\w/.-])" + re.escape(rel.rsplit("/", 1)[-1]) + r"(?![\w-])"
    return rel in cell or bool(re.search(base, cell))


def tool_report(root):
    """T1: each tool file needs a docs/tools.md row whose first cell names it and whose candidates cell holds 3 candidates, or
    "none known" with search terms. A name in another cell (the job, the callers) does not count.

    Args:
        root: the repo root (a Path).

    Returns:
        (WARN lines, problems): a problem in the kit, a WARN line in a project (the debt: plan section 3, T5 table).
    """
    ok = [first for first, cand in tools_rows(root)
          if re.search(r"none known\W*\w", cand, re.I) or len([x for x in re.split(r"[;,]", cand) if x.strip()]) >= 3]
    bare = [f for f in tool_files(root) if not any(names_tool(first, f) for first in ok)]
    if not bare:
        return [], []
    line = (f"{len(bare)} tool file(s) have no {TOOLS_DOC} row whose first cell names them and holds 3 candidate tools, or \"none known\" "
            f"and the search terms (T1: search first), for example {', '.join(bare[:3])}")
    return ([], [line]) if is_kit(root) else ([f"WARN  {line}"], [])


def script_lines(root):
    """The newline count of scripts/*.py and scripts/*.sh: `cat scripts/*.py scripts/*.sh | wc -l` (the T2 measure)."""
    return sum(p.read_bytes().count(b"\n") for pat in ("*.py", "*.sh") for p in sorted((root / "scripts").glob(pat)))


def ratchet_report(root):
    """T2: the script lines may not pass the baseline in .check.state.json; a higher baseline than on main needs a docs/DECISIONS.md
    row By the Maintainer with the number. No baseline in the state: a problem in the kit, a SKIP line in a project (the sync sets it:
    plan P5).

    Args:
        root: the repo root (a Path).

    Returns:
        (rows, problems).
    """
    try:
        part = check_settings.load_state(root).get(STATE_KEY)
        base = part["baseline"] if isinstance(part, dict) else None
    except (ValueError, KeyError):
        return [], [f"{check_settings.STATE}: \"{STATE_KEY}\" needs a \"baseline\" number"]
    if base is None:
        if is_kit(root):
            return [], [f"{check_settings.STATE} has no \"{STATE_KEY}\" baseline: the script lines are not checked (T2)"]
        return [f"SKIP  scripts:     no \"{STATE_KEY}\" baseline in {check_settings.STATE} (the sync sets it: plan P5)"], []
    n, problems = script_lines(root), []
    if n > base:
        problems.append(f"custom script lines {n} pass the baseline {base} (+{n - base}): a higher baseline needs a docs/DECISIONS.md "
                        f"row By the Maintainer with the number {n} (T2 ratchet)")
    elif n < base:
        problems.append(f"custom script lines {n} are below the baseline {base} (-{base - n}): set \"baseline\": {n} in "
                        f"{check_settings.STATE} in this change, so the freed lines do not return with no decision (T2 ratchet)")
    ref = brules.git(root, "merge-base", "HEAD", "origin/main")
    old = brules.git(root, "show", f"{ref}:{check_settings.STATE}") if ref else None
    try:
        was = json.loads(old).get(STATE_KEY, {}).get("baseline") if old else None
    except (ValueError, AttributeError):
        was = None
    if isinstance(was, int) and base > was:
        rows = [plan.cells(r[1:]) for r in (brules.git(root, "diff", ref, "--", "docs/DECISIONS.md") or "").splitlines() if r.startswith("+|")]
        number = re.compile(rf"(?<![\w.,])(?:{base}|{base:,})(?![\w]|[.,]\d)")   # 18142 or 18,142; not 181420, 1.18142 or 18142.5
        if not any(len(c) > 2 and number.search(c[1]) and APPROVED_BY.match(c[2]) for c in rows):
            problems.append(f"the script lines baseline rose from {was} to {base} with no new docs/DECISIONS.md row that names {base}, "
                            "By the Maintainer: the approval in quotes, then its date")
    return [f"scripts:     {n} lines in scripts/*.py and *.sh (baseline {base})"], problems


def synced_files(root):
    """The kit-synced text of the kit itself: COPY_FILES and COPY_IF_MISSING of scripts/sync_baseline.py (read, never run), and AGENTS.md.

    Args:
        root: the repo root (a Path).

    Returns:
        A set of repo-relative paths.
    """
    out = {"AGENTS.md"}
    try:
        tree = ast.parse((root / "scripts/sync_baseline.py").read_text(encoding="utf-8"))
    except (OSError, SyntaxError):
        return out
    for node in tree.body:
        names = [t.id for t in getattr(node, "targets", []) if isinstance(t, ast.Name)]
        if {"COPY_FILES", "COPY_IF_MISSING"} & set(names):
            out |= set(ast.literal_eval(node.value))
    return out


def role_report(root):
    """T6, in the kit: kit-synced text says "the Maintainer", not the old role words (the sync swaps the word per project). A FAIL
    in the kit. Allowed: a dated attribution and the lines of ROLE_ALLOW. A project has no such check:
    its synced text holds that project's own role word.

    Args:
        root: the repo root (a Path).

    Returns:
        (lines to print, problems): one problem with the count and the first places.
    """
    if not is_kit(root):
        return [], []
    hits = []
    for rel in sorted(synced_files(root)):
        p = root / rel
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines() if p.is_file() else [], 1):
            if ROLE_WORD.search(DATED.sub("", line)) and not any(re.search(a, line) for a in ROLE_ALLOW.get(rel, ())):
                hits.append(f"{rel}:{n}")
    return [], [f"{len(hits)} line(s) of kit-synced text use an old role word (T6: write \"the Maintainer\"; the sync swaps it): "
                f"{', '.join(hits[:5])}{' ...' if len(hits) > 5 else ''}"] if hits else []


def caps_of(text):
    """Read KIT_CAPS and the budgets of AUDIT_DEFAULTS from a scripts/check_settings_read.py text, as literals (never run).

    Args:
        text: the text of the file.

    Returns:
        (KIT_CAPS tuple, budgets dict), or None when unreadable.
    """
    found = {}
    try:
        for node in ast.parse(text).body:
            for t in getattr(node, "targets", []):
                if isinstance(t, ast.Name) and t.id in ("KIT_CAPS", "AUDIT_DEFAULTS"):
                    found[t.id] = ast.literal_eval(node.value)
        return tuple(found["KIT_CAPS"]), found["AUDIT_DEFAULTS"]["budgets"]
    except (SyntaxError, KeyError, ValueError, TypeError):
        return None


def debt_triggers(root):
    """T5, in the kit: lines that need the fleet debt record besides the changed rule lines, against origin/main: a check entry point
    that scripts/check.sh runs now and did not, and a KIT_CAPS cap that is new or lower.

    Args:
        root: the repo root (a Path).

    Returns:
        A list of text lines, sorted (the input of the debt-check hash with the changed rule lines).
    """
    if not is_kit(root) or not (root / "scripts/check.sh").is_file():
        return []
    out, base = [], {}
    for ref in ("origin/main", "origin/master"):
        base = {f: brules.git(root, "show", f"{ref}:{f}") for f in ("scripts/check.sh", CAPS_FILE)}
        if base["scripts/check.sh"] is not None:
            break
    entries = lambda text: {a or b for a, b in ENTRY.findall(text or "")}
    if base["scripts/check.sh"] is not None:
        now = entries((root / "scripts/check.sh").read_text(encoding="utf-8", errors="replace"))
        out += [f"check entry point {e}" for e in sorted(now - entries(base["scripts/check.sh"]))]
    old, new = caps_of(base[CAPS_FILE] or ""), caps_of((root / CAPS_FILE).read_text(encoding="utf-8", errors="replace"))
    if old and new:
        out += [f"stricter kit cap {k}" for k in new[0] if k not in old[0] or new[1].get(k, 0) < old[1].get(k, 0)]
    return sorted(out)




def debt_record(root, parts, gate):
    """T5, in the kit: changed rule lines, a check entry point added to scripts/check.sh and a stricter KIT_CAPS cap need a file
    docs/reviews/*-debt.md with the line "debt-check: <hash>" (what the change fails today in every fleet repo, and its fix plan).
    The hash is the conflict-check hash for rule lines alone; debt_triggers' lines join it. As the conflict record: WARN, or in the
    full lane a problem.

    Args:
        root: the repo root (a Path).
        parts: (kit, project, every), the rule lines of AGENTS.md now.
        gate: True in the full lane.

    Returns:
        (lines to print, problems).
    """
    changed = brules.changed_lines(root, parts)
    if changed is None:
        return [], []
    added, removed = changed
    extra = debt_triggers(root)
    if not is_kit(root) or not (added or removed or extra):
        return [], []
    out = [f"  debt check: {x}" for x in extra]
    h = brules.conflict_hash(added + extra, removed)
    if brules.conflict_recorded(root, h, "debt-check", "*-debt.md"):
        return out + [f"  debt check: recorded (debt-check: {h})"], []
    need = (f"no fleet debt list for these changes (T5): list what each changed rule line, new check and stricter cap fails today in "
            f"every fleet repo, with a fix plan, and record the line \"debt-check: {h}\" in a {brules.REVIEWS}/*-debt.md file")
    return (out, [need]) if gate else (out + [f"WARN  {need} (the full lane fails without it)"], [])


def file_report(root):
    """The file checks of `--rules`: the tool rows (T1), the script lines ratchet (T2) and the role word (T6).

    Args:
        root: the repo root (a Path).

    Returns:
        (lines to print, problems).
    """
    warns, problems = tool_report(root)
    rows, found = ratchet_report(root)
    more, role = role_report(root)
    return rows + warns + more, problems + found + role


def rules_report(root, cfg, gate=False):
    """The full report of `--rules`: the rule census (scripts/bloat_check_rules.py), the file checks and the debt record, then a
    RULES FAIL line for each problem.

    Args:
        root: the repo root (a Path).
        cfg: the audit settings (its budgets are the caps).
        gate: True in the full lane: a missing conflict-check or debt record is a problem, not a WARN line.

    Returns:
        (lines to print, problems).
    """
    out, problems = brules.rules_report(root, cfg, gate)
    path = root / brules.RULES_FILE
    if path.is_file():
        rows, found = file_report(root)
        drows, dfound = debt_record(root, brules.rule_lines(path.read_text(encoding="utf-8", errors="replace")), gate)
        out, problems = out + rows + drows, problems + found + dfound
    return out + [f"RULES FAIL:  {pr}" for pr in problems], problems
