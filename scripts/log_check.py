#!/usr/bin/env python3
"""Check a project log (docs/LOG.md) against the project log rules (AGENTS.md "Project log" and .claude/skills/project-log/SKILL.md).

Usage:
    python3 scripts/log_check.py [FILE ...]        # default: docs/LOG.md
    python3 scripts/log_check.py --decisions [FILE]  # approval quotes in docs/DECISIONS.md (T6)
    python3 scripts/log_check.py --coverage FILE   # a plan coverage list (T7)
    python3 scripts/log_check.py --test            # self-test; prints LOG CHECK TEST PASS

Checks (each failure prints FILE:LINE: message):
- A "## Arcs" table with the columns Arc | Span | Summary | Problem | Turning point | Outcome | Lesson.
  Every Arcs row has 7 cells. Turning point is "-" or names log rows as #N, and each named row exists.
- A "## Log" table with the columns # | When | Type | Arc | Topic | Raised by | What the other missed | Evidence | Result.
- Every row has 9 cells; # is a whole number, unique, and rows are in # order.
- When: YYYY-MM-DD HH:MM, or a range YYYY-MM-DD HH:MM-HH:MM (en dash or hyphen), or a range across days
  YYYY-MM-DD HH:MM-YYYY-MM-DD HH:MM; "~" before the date or a time marks an estimate. Dates and times must exist.
- Type is milestone, breakthrough, miss or decision.
- Arc is kebab-case and has a row in the Arcs table; every Arcs row is used at least once.
- Evidence is not empty and not "-" (.claude/skills/project-log/SKILL.md: never chat text alone).
--decisions (T6): a row of the "## Decisions" table whose By cell names the Maintainer (or an old word: "owner",
  "Administrator") must quote the approval of its exact text: a quoted OK in the By cell, for example the Maintainer
  "I approve the plan" (own message, date time). Rows from the row named in the marker line `<!-- approval-quote-exempt-from: TEXT -->`
  (above the table; TEXT starts that row's Decision cell) down to the end are older rows and exempt; the table is
  newest first. With no marker line, every row is checked. A table with the columns Date | Scope | Decision has no By
  cell: a Decision cell that holds a role word must start with its quoted approval (By: the Maintainer: "I approve").
  The marker names the Decision cell.
--coverage (T7): a plan coverage list. Every row of each table with a Mark column has the mark in, out, later or ask
  (first word of the cell; "in (added)" is in). A row marked ask or with no mark fails. The "Group | Rows | in | out |
  later | ask" table must equal the rows counted per group (the letter of the nearest "## A." or "### B2." heading)
  and its Total row the sums.
Exit 0 and "LOG CHECK PASS: N rows" when clean, exit 1 with the findings otherwise.
It does not judge whether a row's type or text is right; that stays a human review.
Standard library only. It reads files only; it never writes.
Prevents: a project log or a DECISIONS row is malformed or its approval quote is missing, so the story record is wrong or an approval is not shown
Network: none.
Writes: none (the self-test: temporary files).
Credentials: none.
"""
import argparse
import datetime as dt
import pathlib
import re
import sys
import tempfile

LOG_COLS = ["#", "When", "Type", "Arc", "Topic", "Raised by", "What the other missed", "Evidence", "Result"]
ARC_COLS = ["Arc", "Span", "Summary", "Problem", "Turning point", "Outcome", "Lesson"]
OLD_ARC_COLS = ["Arc", "Span", "Summary", "Outcome"]
ROW_REF = re.compile(r"#(\d+)")
TYPES = {"milestone", "breakthrough", "miss", "decision"}
ARC_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DATE = r"\d{4}-\d{2}-\d{2}"
TIME = r"~?\d{2}:\d{2}"
WHEN_RE = re.compile(rf"^~?({DATE}) ({TIME})(?:\s?[–-]\s?(?:({DATE}) )?({TIME}))?$")


def cells(line):
    """Split a Markdown table row into stripped cells (escaped pipes stay in the cell)."""
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|") and not body.endswith("\\|"):
        body = body[:-1]
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", body)]


def tables(text):
    """Return {heading: (header_line_no, header_cells, [(line_no, cells), ...])} for the first table under each ## heading.

    Args:
        text: the text of a log file.

    Returns:
        A dict {heading: (header line number, header cells, [(line number, cells)])}.
    """
    out, heading, i = {}, None, 0
    lines = text.splitlines()
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            heading = m.group(1)
        elif heading and heading not in out and line.strip().startswith("|"):
            head = cells(line)
            rows, j = [], i + 1
            if j < len(lines) and re.match(r"^\s*\|?\s*:?-{3,}", lines[j]):
                j += 1
            while j < len(lines) and lines[j].strip().startswith("|"):
                rows.append((j + 1, cells(lines[j])))
                j += 1
            out[heading] = (i + 1, head, rows)
            i = j
            continue
        i += 1
    return out


def valid_when(value):
    """True when a When cell is a real date and time, or a range that does not run backwards.

    Args:
        value: the text of a When cell.

    Returns:
        True or False.
    """
    m = WHEN_RE.match(value)
    if not m:
        return False
    d1, t1, d2, t2 = m.groups()
    try:
        start = dt.datetime.strptime(f"{d1} {t1.lstrip('~')}", "%Y-%m-%d %H:%M")
        if t2:
            end = dt.datetime.strptime(f"{d2 or d1} {t2.lstrip('~')}", "%Y-%m-%d %H:%M")
            if end < start:
                return False
    except ValueError:
        return False
    return True


def check_arcs(p, table, found):
    """Check the Arcs table; return ({arc: line_no}, [(line_no, arc, turning point)]) and add findings to found.

    Args:
        p: the path of the log file, for the findings.
        table: the Arcs table, as tables() gives it.
        found: the list of findings, added to in place.

    Returns:
        ({arc: line number}, [(line number, arc, turning point)]).
    """
    arcs, turns = {}, []
    ln, head, rows = table
    if head != ARC_COLS:
        hint = (" (add Problem, Turning point and Lesson; write - until known. A baseline project:"
                " add them by hand, or with the kit's scripts/sync_baseline.py --apply)") if head == OLD_ARC_COLS else ""
        found.append(f"{p}:{ln}: Arcs columns must be {' | '.join(ARC_COLS)}{hint}")
    for ln, c in rows:
        if head == ARC_COLS and len(c) != len(ARC_COLS):
            found.append(f"{p}:{ln}: {len(c)} cells in Arcs row, need {len(ARC_COLS)}")
        elif head == ARC_COLS:
            turns.append((ln, c[0], c[4]))
        if not c or not ARC_RE.match(c[0]):
            found.append(f"{p}:{ln}: arc name {c[0] if c else ''!r} is not kebab-case")
        elif c[0] in arcs:
            found.append(f"{p}:{ln}: arc {c[0]!r} listed twice")
        else:
            arcs[c[0]] = ln
    return arcs, turns


def check_log_rows(p, rows, arcs, found):
    """Check each Log row; return (arcs used, row numbers) and add findings to found.

    Args:
        p: the path of the log file, for the findings.
        rows: the rows of the Log table, each (line number, cells).
        arcs: the arcs of the Arcs table {arc: line number}.
        found: the list of findings, added to in place.

    Returns:
        (the set of arcs the rows use, the set of row numbers).
    """
    used, last, nums = set(), None, set()
    for ln, c in rows:
        if len(c) != len(LOG_COLS):
            if len(c) > 3:
                used.add(c[3])
            found.append(f"{p}:{ln}: {len(c)} cells, need {len(LOG_COLS)}")
            continue
        num, when, typ, arc, *_rest = c
        evidence = c[7]
        if not num.isdigit():
            found.append(f"{p}:{ln}: # {num!r} is not a whole number")
        else:
            n = int(num)
            if last is not None and n <= last:
                found.append(f"{p}:{ln}: # {n} is not after # {last} (unique, in order)")
            last = n
            nums.add(n)
        if not valid_when(when):
            found.append(f"{p}:{ln}: When {when!r} is not YYYY-MM-DD HH:MM (or a range; ~ marks an estimate)")
        if typ not in TYPES:
            found.append(f"{p}:{ln}: Type {typ!r} is not one of {', '.join(sorted(TYPES))}")
        if not ARC_RE.match(arc):
            found.append(f"{p}:{ln}: Arc {arc!r} is not kebab-case")
        elif arc not in arcs:
            found.append(f"{p}:{ln}: Arc {arc!r} has no row in the Arcs table")
        used.add(arc)
        if evidence in ("", "-"):
            found.append(f"{p}:{ln}: Evidence is empty (a commit, file, test or measurement)")
    return used, nums


def check(path):
    """Return (row_count, [finding, ...]) for one log file.

    Args:
        path: the path of the log file.

    Returns:
        (the number of Log rows, the list of findings).
    """
    p = pathlib.Path(path)
    found = []
    try:
        text = p.read_text(encoding="utf-8")
    except OSError as e:
        return 0, [f"{p}: cannot read ({e.strerror})"]
    t = tables(text)
    if "Arcs" not in t:
        found.append(f"{p}: no table under '## Arcs'")
    if "Log" not in t:
        found.append(f"{p}: no table under '## Log'")
        return 0, found
    arcs, turns = check_arcs(p, t["Arcs"], found) if "Arcs" in t else ({}, [])
    ln, head, rows = t["Log"]
    if len(head) > 1 and re.fullmatch(r"When \(.+\)", head[1]):
        head = head[:1] + ["When"] + head[2:]  # an older log names its zone in the header, for example "When (CT)"
    if head != LOG_COLS:
        found.append(f"{p}:{ln}: Log columns must be {' | '.join(LOG_COLS)}")
        return len(rows), found
    used, nums = check_log_rows(p, rows, arcs, found)
    for aln, arc, turn in turns:
        refs = ROW_REF.findall(turn)
        if turn not in ("", "-") and not refs:
            found.append(f"{p}:{aln}: arc {arc!r} Turning point must name a log row as #N, or be -")
        for r in refs:
            if int(r) not in nums:
                found.append(f"{p}:{aln}: arc {arc!r} Turning point #{r} is not a log row")
    for arc, aln in arcs.items():
        if arc not in used:
            found.append(f"{p}:{aln}: arc {arc!r} is not used by any log row")
    return len(rows), found


GOOD = """# Project log: Demo

## Arcs

| Arc | Span | Summary | Problem | Turning point | Outcome | Lesson |
|---|---|---|---|---|---|---|
| setup | 2026-11-10 | Start. | - | - | Ready | - |
| flow-import | 2026-11-11 07:39–08:36 | Import. | Manual import took 2 h. | #2 found the cause | Works | Test the import first |

## Log

| # | When | Type | Arc | Topic | Raised by | What the other missed | Evidence | Result |
|---|---|---|---|---|---|---|---|---|
| 0 | 2026-11-10 22:11 | milestone | setup | Repo | Owner | - | Commit 63ae6e2 | Made |
| 1 | 2026-11-11 ~06:40 | miss | flow-import | A \\| B | Claude | gap | Test x | ok |
| 2 | 2026-11-11 07:57–08:20 | breakthrough | flow-import | T | Owner | - | Commit 8375b2e | ok |
| 3 | 2026-11-11 23:50–2026-11-12 00:10 | decision | flow-import | T | Owner | - | Commit abc | ok |
"""


def self_test():
    """Check GOOD and one broken copy per rule; prints one line per case and LOG CHECK TEST PASS or FAIL.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    ok = True

    def expect(name, text, want):
        """Check text as a log file: want None = no findings, else a finding that contains want.

        Args:
            name: the name of the case, for its result line.
            text: the text of the sample log file.
            want: None for no findings, else a text one finding must contain.
        """
        nonlocal ok
        with tempfile.TemporaryDirectory() as d:
            f = pathlib.Path(d, "LOG.md")
            f.write_text(text, encoding="utf-8")
            _, found = check(f)
        joined = "\n".join(found)
        good = (not found) if want is None else (want in joined)
        print(("ok   " if good else "FAIL ") + name + ("" if good else f"\n     got: {found}"))
        ok = ok and good

    expect("clean log passes", GOOD, None)
    expect("bad type", GOOD.replace("| miss |", "| oops |"), "Type 'oops'")
    expect("bad time", GOOD.replace("2026-11-10 22:11", "2026-11-10 25:11"), "When '2026-11-10 25:11'")
    expect("estimate before date ok", GOOD.replace("2026-11-11 ~06:40", "~2026-11-11 06:40"), None)
    expect("no date", GOOD.replace("2026-11-11 ~06:40", "~06:40"), "When '~06:40'")
    expect("range backwards", GOOD.replace("07:57–08:20", "08:20–07:57"), "When")
    expect("unknown arc", GOOD.replace("| breakthrough | flow-import |", "| breakthrough | other |"), "Arc 'other' has no row")
    expect("unused arc", GOOD.replace("| 0 | 2026-11-10 22:11 | milestone | setup |", "| 0 | 2026-11-10 22:11 | milestone | flow-import |"), "arc 'setup' is not used")
    expect("duplicate #", GOOD.replace("| 2 | 2026", "| 1 | 2026"), "# 1 is not after # 1")
    expect("empty evidence", GOOD.replace("Commit 8375b2e", "-"), "Evidence is empty")
    expect("missing cell", GOOD.replace("| Repo | Owner | - |", "| Repo | Owner |"), "8 cells")
    expect("wrong columns", GOOD.replace("| Evidence | Result |", "| Test / evidence | Result |"), "Log columns")
    expect("older header 'When (CT)' passes", GOOD.replace("| # | When |", "| # | When (CT) |"), None)
    expect("no arcs table", GOOD.split("## Arcs")[0] + "## Log" + GOOD.split("## Log")[1], "no table under '## Arcs'")
    expect("old 4-column Arcs table", GOOD.replace("| Arc | Span | Summary | Problem | Turning point | Outcome | Lesson |",
                                                   "| Arc | Span | Summary | Outcome |"), "add Problem, Turning point and Lesson")
    expect("short Arcs row", GOOD.replace("| setup | 2026-11-10 | Start. | - | - | Ready | - |", "| setup | 2026-11-10 | Start. | Ready |"), "4 cells in Arcs row")
    expect("turning point names a missing row", GOOD.replace("#2 found", "#9 found"), "Turning point #9 is not a log row")
    expect("turning point without a row", GOOD.replace("#2 found the cause", "found the cause"), "must name a log row")
    import log_check_plan  # here, not at the top: it imports this module
    ok = log_check_plan.self_test_t6_t7() and ok
    print("LOG CHECK TEST " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    """Check each log file named (default docs/LOG.md); print the findings and LOG CHECK PASS or FAIL.

    Returns:
        The exit code: 0 pass, 1 when a log has findings.
    """
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--test", action="store_true", help="run the self-test")
    ap.add_argument("--decisions", action="store_true", help="check the files as DECISIONS tables (default docs/DECISIONS.md)")
    ap.add_argument("--coverage", action="store_true", help="check the files as plan coverage lists")
    a = ap.parse_args()
    if a.test:
        return self_test()
    if a.decisions and a.coverage:
        ap.error("use --decisions or --coverage, not both")
    if a.coverage and not a.files:
        ap.error("--coverage needs a file")
    import log_check_plan  # here, not at the top: it imports this module
    one = log_check_plan.check_decisions if a.decisions else log_check_plan.check_coverage if a.coverage else check
    files = a.files or ["docs/DECISIONS.md" if a.decisions else "docs/LOG.md"]
    total, found = 0, []
    for f in files:
        n, fs = one(f)
        total += n
        found += fs
    for f in found:
        print(f)
    if found:
        print(f"LOG CHECK FAIL: {len(found)} finding(s)")
        return 1
    print(f"LOG CHECK PASS: {total} rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
