#!/usr/bin/env python3
"""The plan checks of scripts/log_check.py: T6 (--decisions) and T7 (--coverage), and their self-test cases.

Prevents: a DECISIONS row written from a dialog answer with no quoted approval of its exact text (T6), and a plan made from a
source plan that drops source items without a question (T7).

Usage: not run by itself; scripts/log_check.py imports it (`--decisions`, `--coverage`, `--test`).
Standard library only. It reads files only; it never writes.
Network: none.
Writes: none (the self-test: temporary files).
Credentials: none.
"""
import pathlib
import re
import tempfile

from log_check import cells, tables

APPROVAL_QUOTE = re.compile(r'"[^"\n]*\S[^"\n]*"|“[^”\n]*\S[^”\n]*”')
EXEMPT_MARK = re.compile(r"<!--\s*approval-quote-exempt-from:\s*(.+?)\s*-->")
MARKS = ("in", "out", "later", "ask")
GROUP_HEADING = re.compile(r"^#{2,3}\s+([A-Z][0-9]?)\.")
GROUP_CELL = re.compile(r"^\W*([A-Z][0-9]?)\.")
DECISIONS_HEAD = re.compile(r"^\s*\|\s*date\s*\|\s*decision\s*\|\s*by\s*\|", re.I)   # scripts/sync_baseline.py: the same


def decisions_table(text):
    """Find the Decisions table: the first table under '## Decisions'; in a file with no such heading, the first table
    whose columns start Date, Decision, By (a project file can hold it under its title).

    Args:
        text: the text of docs/DECISIONS.md.

    Returns:
        (header line number, header cells, [(line number, cells)]) as tables() gives them, or None.
    """
    lines = text.splitlines()
    if any(re.match(r"##\s+Decisions\s*$", line) for line in lines):
        return tables(text).get("Decisions")
    i = next((n for n, line in enumerate(lines) if DECISIONS_HEAD.match(line)), None)
    if i is None:
        return None
    no, head, rows = tables("## Decisions\n" + "\n".join(lines[i:]))["Decisions"]
    return no + i - 1, head, [(n + i - 1, c) for n, c in rows]


def check_decisions(path):
    """Check that each new DECISIONS row naming the Maintainer quotes the approval of its exact text (T6).

    Args:
        path: the path of docs/DECISIONS.md.

    Returns:
        A tuple (number of rows checked, list of finding lines).
    """
    p = pathlib.Path(path)
    text = p.read_text(encoding="utf-8")
    found = []
    table = decisions_table(text)
    if not table:
        return 0, [f"{p}:1: no Decisions table (under '## Decisions', or with the columns Date | Decision | By)"]
    _, header, rows = table
    if [c.lower() for c in header[:3]] != ["date", "decision", "by"]:
        return 0, [f"{p}: Decisions columns must start with Date | Decision | By"]
    marker = EXEMPT_MARK.search(text)
    exempt_from = marker.group(1) if marker else None
    if exempt_from and not any(c[1].startswith(exempt_from) for _, c in rows if len(c) > 1):
        return 0, [f"{p}: the marker 'approval-quote-exempt-from: {exempt_from}' matches no Decisions row"]
    checked = 0
    for no, c in rows:
        if exempt_from and len(c) > 1 and c[1].startswith(exempt_from):
            break
        checked += 1
        if len(c) < 3:
            found.append(f"{p}:{no}: Decisions row has {len(c)} cells, need at least 3")
        elif re.search(r"maintainer|owner", c[2], re.I) and not APPROVAL_QUOTE.search(c[2]):
            found.append(f"{p}:{no}: the By cell names the Maintainer but quotes no approval: a new decision row "
                         'needs the approval of its exact text in quotes, for example "I approve the plan" '
                         "(the Maintainer's own message, date time)")
    return checked, found


def check_coverage(path):
    """Check a plan coverage list: every row marked in, out or later (no ask), and the counts table equal (T7).

    Args:
        path: the path of the coverage list.

    Returns:
        A tuple (number of rows counted, list of finding lines).
    """
    p = pathlib.Path(path)
    found, counts, group, stated, cols = [], {}, None, {}, None
    for no, line in enumerate(p.read_text(encoding="utf-8").split("\n"), 1):
        m = GROUP_HEADING.match(line)
        if m:
            group = m.group(1)
        if not line.startswith("|"):
            cols = None
            continue
        c = cells(line)
        if cols is None:
            cols = [x.lower() for x in c]
            continue
        if set("".join(c)) <= set("-: "):
            continue
        if cols[:2] == ["group", "rows"]:
            row = dict(zip(cols, (x.strip("* ") for x in c)))
            key = "TOTAL" if "total" in row["group"].lower() else (GROUP_CELL.match(row["group"]) or [None, None])[1]
            if key is None or not all(row.get(k, "").isdigit() for k in cols[1:]):
                found.append(f"{p}:{no}: counts row not readable: {c[0]!r}")
            else:
                stated[key] = {k: int(row[k]) for k in cols[1:]}
        elif "mark" in cols:
            mark = c[cols.index("mark")].strip("* ").lower().split(" ")[0] if len(c) == len(cols) else ""
            if mark not in MARKS:
                found.append(f"{p}:{no}: row {c[0]!r} has no mark in, out, later or ask")
                continue
            if mark == "ask":
                found.append(f"{p}:{no}: row {c[0]!r} is marked ask: the Maintainer must mark it first")
            tally = counts.setdefault(group, dict.fromkeys(("rows",) + MARKS, 0))
            tally["rows"] += 1
            tally[mark] += 1
    total = {k: sum(t[k] for t in counts.values()) for k in ("rows",) + MARKS}
    if not stated:
        found.append(f"{p}: no 'Group | Rows | in | out | later | ask' counts table")
    for key, want in stated.items():
        got = total if key == "TOTAL" else counts.get(key)
        if got != want:
            found.append(f"{p}: counts table row {key} says {want}, the rows count {got}")
    found += [f"{p}: group {k} has marked rows and no row in the counts table" for k in counts if k not in stated]
    return total["rows"], found


DECISIONS_TABLE = """## Decisions

<!-- approval-quote-exempt-from: Old row -->

| Date | Decision | By | Replaces |
|---|---|---|---|
| 2026-11-24 | New row | the Maintainer: "I approve the plan" (own message, 2026-11-24 10:00) | - |
| 2026-11-23 | Old row | the owner | - |
"""
COVERAGE_GOOD = """# List

## A. Items (2)

| ID | Item | Mark | Reason |
|---|---|---|---|
| A-1 | One | in (added) | x |
| A-2 | Two | out | x |

### B2. Extra (1)

| ID | Item | Mark | Reason |
|---|---|---|---|
| B2-1 | Three | later | x |

## F. Counts

| Group | Rows | in | out | later | ask |
|---|---|---|---|---|---|
| A. Items | 2 | 1 | 1 | 0 | 0 |
| B2. Extra | 1 | 0 | 0 | 1 | 0 |
| **Total** | **3** | **1** | **1** | **1** | **0** |
"""


def self_test_t6_t7():
    """Check the T6 (DECISIONS approval quote) and T7 (coverage list) cases; prints one line per case.

    Returns:
        True when every case behaved as expected.
    """
    ok = True

    def expect(name, func, text, want):
        """Run func on text as a file: want None = no findings, else a finding that contains want.

        Args:
            name: the name of the case, for its result line.
            func: check_decisions or check_coverage.
            text: the text of the sample file.
            want: None for no findings, else a text one finding must contain.
        """
        nonlocal ok
        with tempfile.TemporaryDirectory() as d:
            f = pathlib.Path(d, "F.md")
            f.write_text(text, encoding="utf-8")
            _, found = func(f)
        joined = "\n".join(found)
        good = (not found) if want is None else (want in joined)
        print(("ok   " if good else "FAIL ") + name + ("" if good else f"\n     got: {found}"))
        ok = ok and good

    row = '| 2026-11-24 | New row | the Maintainer: "I approve the plan" (own message, 2026-11-24 10:00) | - |'
    expect("T6 new row with a quoted approval passes", check_decisions, DECISIONS_TABLE, None)
    expect("T6 new row without a quote fails", check_decisions, DECISIONS_TABLE.replace(row, "| 2026-11-24 | New row | the Maintainer | - |"),
           "quotes no approval")
    expect("T6 empty quote fails", check_decisions, DECISIONS_TABLE.replace('"I approve the plan"', '" "'), "quotes no approval")
    expect("T6 a row by Agent needs no quote", check_decisions, DECISIONS_TABLE.replace("the Maintainer:", "Agent:").replace('"I approve the plan"', "x"), None)
    expect("T6 no marker: the older row is checked", check_decisions, DECISIONS_TABLE.replace("<!-- approval-quote-exempt-from: Old row -->", ""),
           "quotes no approval")
    untitled = DECISIONS_TABLE.replace("## Decisions\n", "# Decisions: a project\n")
    expect("T6 a table under the title (no '## Decisions') is checked", check_decisions,
           untitled.replace('"I approve the plan"', "x"), "quotes no approval")
    expect("T6 no Decisions table fails", check_decisions, "# Decisions\n\nNo table.\n", "no Decisions table")
    expect("T6 '## Decisions' with no table under it fails (no fallback)", check_decisions,
           untitled + "\n## Decisions\n\nText.\n", "no Decisions table")
    expect("T6 marker that matches no row fails", check_decisions, DECISIONS_TABLE.replace("exempt-from: Old row", "exempt-from: Gone"), "matches no Decisions row")
    expect("T7 clean coverage list passes", check_coverage, COVERAGE_GOOD, None)
    expect("T7 ask row fails", check_coverage, COVERAGE_GOOD.replace("| A-2 | Two | out |", "| A-2 | Two | ask |"), "is marked ask")
    expect("T7 unmarked row fails", check_coverage, COVERAGE_GOOD.replace("| A-2 | Two | out |", "| A-2 | Two | |"), "has no mark")
    expect("T7 unknown mark fails", check_coverage, COVERAGE_GOOD.replace("| A-2 | Two | out |", "| A-2 | Two | maybe |"), "has no mark")
    expect("T7 count mismatch fails", check_coverage, COVERAGE_GOOD.replace("| A. Items | 2 | 1 | 1 |", "| A. Items | 2 | 2 | 0 |"), "counts table row A")
    expect("T7 total mismatch fails", check_coverage, COVERAGE_GOOD.replace("**3** | **1** | **1** | **1**", "**4** | **1** | **1** | **2**"),
           "counts table row TOTAL")
    expect("T7 group missing from the counts fails", check_coverage, COVERAGE_GOOD.replace("| B2. Extra | 1 | 0 | 0 | 1 | 0 |\n", ""),
           "group B2 has marked rows")
    expect("T7 no counts table fails", check_coverage, COVERAGE_GOOD.split("## F.")[0], "no 'Group | Rows")
    return ok
