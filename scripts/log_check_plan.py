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
# The two forms of the Decisions table: Date | Decision | By, or Date | Scope | Decision with "By: ..." in the Decision cell.
DECISIONS_HEAD = re.compile(r"^\s*\|\s*date\s*\|\s*(?:decision\s*\|\s*by|scope\s*\|\s*decision)\s*\|", re.I)   # sync_baseline.py: the same
# A Date | Scope | Decision table has no By cell: a Decision cell that holds a role word anywhere must start with the
# role and its quoted approval: By: the Maintainer: "I approve". Anchored at the cell start; one way to match: linear.
APPROVED_START = re.compile(r'\s*\**by\b[\s:*]*(?:the\s+)?(?:maintainer|owner|administrator)\**\s*:\s*'
                            r'(?:"\s*[^"\s][^"\n]*"|“\s*[^”\s][^”\n]*”)', re.I)
NO_QUOTE = ('the By cell names the Maintainer but quotes no approval: a new decision row needs the approval of its exact '
            'text in quotes, for example "I approve the plan"')
APPROVER = re.compile(r"maintainer|owner|administrator", re.I)   # the role words a By cell can name (the sync swaps them per project)


def decisions_table(text):
    """Find the Decisions table: the first table under '## Decisions'; in a file with no such heading, the first table
    whose columns start Date, Decision, By or Date, Scope, Decision (a project file can hold it under its title).

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


def scope_missing(cell):
    """The finding of one Decision cell of a Date | Scope | Decision table, or None: a cell that holds a role word anywhere
    must start with By: <role>: "<the quoted approval>" (APPROVED_START), as a By cell with a role word needs its quote."""
    if APPROVER.search(cell) and not APPROVED_START.match(cell):
        return ('the Decision cell names the Maintainer but has no approval at its start: it must start with the quoted '
                'approval of its exact text: '
                'By: the Maintainer: "I approve the plan" (the Maintainer\'s own message, date time)')
    return None


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
        return 0, [f"{p}:1: no Decisions table (under '## Decisions', or with the columns Date | Decision | By or Date | Scope | Decision)"]
    _, header, rows = table
    cols = [c.lower() for c in header]
    if cols[:3] not in (["date", "decision", "by"], ["date", "scope", "decision"]):
        return 0, [f"{p}: Decisions columns must start with Date | Decision | By or Date | Scope | Decision"]
    dec = cols.index("decision")   # the cell the marker names
    if "by" in cols:   # a By cell: a role word in it needs a quoted approval in it
        by = cols.index("by")
        missing = lambda c: NO_QUOTE + " (the Maintainer's own message, date time)" if APPROVER.search(c[by]) and not APPROVAL_QUOTE.search(c[by]) else None
    else:   # no By cell: the Decision cell starts with "By: <who>" (scope_missing)
        missing = lambda c: scope_missing(c[dec])
    marker = EXEMPT_MARK.search(text)
    exempt_from = marker.group(1) if marker else None
    if exempt_from and not any(c[dec].startswith(exempt_from) for _, c in rows if len(c) > dec):
        return 0, [f"{p}: the marker 'approval-quote-exempt-from: {exempt_from}' matches no Decisions row"]
    checked = 0
    for no, c in rows:
        if exempt_from and len(c) > dec and c[dec].startswith(exempt_from):
            break
        checked += 1
        if len(c) < 3 or ("by" in cols and len(c) <= cols.index("by")):
            found.append(f"{p}:{no}: Decisions row has {len(c)} cells, need at least 3")
        elif missing(c):
            found.append(f"{p}:{no}: {missing(c)}")
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
# A Date | Scope | Decision table (a project form): the By is written inside the Decision cell.
SCOPE_TABLE = ('# Decisions\n\n<!-- approval-quote-exempt-from: Old text -->\n\n| Date | Scope | Decision | Replaces |\n|---|---|---|---|\n'
               '| 2026-11-25 | Kit sync | By: the Maintainer: "I approve the sync" (own message). Sync to 11.1.0. | - |\n'
               '| 2026-11-24 | Kit sync | Old text. By: the Maintainer. | - |\n')
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


def expect(name, func, text, want):
    """Run func on text as a file and print one result line: want None = no findings, else a finding that contains want.

    Args:
        name: the name of the case, for its result line.
        func: check_decisions or check_coverage.
        text: the text of the sample file.
        want: None for no findings, else a text one finding must contain.

    Returns:
        True when the case behaved as expected.
    """
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d, "F.md")
        f.write_text(text, encoding="utf-8")
        _, found = func(f)
    good = (not found) if want is None else (want in "\n".join(found))
    print(("ok   " if good else "FAIL ") + name + ("" if good else f"\n     got: {found}"))
    return good


def self_test_t6_t7():
    """Check the T6 (DECISIONS approval quote) and T7 (coverage list) cases; prints one line per case.

    Returns:
        True when every case behaved as expected.
    """
    row = '| 2026-11-24 | New row | the Maintainer: "I approve the plan" (own message, 2026-11-24 10:00) | - |'
    untitled = DECISIONS_TABLE.replace("## Decisions\n", "# Decisions: a project\n")
    cases = [
        ("T6 new row with a quoted approval passes", DECISIONS_TABLE, None),
        ("T6 new row without a quote fails", DECISIONS_TABLE.replace(row, "| 2026-11-24 | New row | the Maintainer | - |"), "quotes no approval"),
        ("T6 empty quote fails", DECISIONS_TABLE.replace('"I approve the plan"', '" "'), "quotes no approval"),
        ("T6 a row by Agent needs no quote", DECISIONS_TABLE.replace("the Maintainer:", "Agent:").replace('"I approve the plan"', "x"), None),
        ("T6 no marker: the older row is checked", DECISIONS_TABLE.replace("<!-- approval-quote-exempt-from: Old row -->", ""),
         "quotes no approval"),
        ("T6 a table under the title (no '## Decisions') is checked", untitled.replace('"I approve the plan"', "x"), "quotes no approval"),
        ("T6 no Decisions table fails", "# Decisions\n\nNo table.\n", "no Decisions table"),
        ("T6 '## Decisions' with no table under it fails (no fallback)", untitled + "\n## Decisions\n\nText.\n", "no Decisions table"),
        ("T6 marker that matches no row fails", DECISIONS_TABLE.replace("exempt-from: Old row", "exempt-from: Gone"), "matches no Decisions row"),
        ("T6 a Date | Scope | Decision table: a quoted By part passes", SCOPE_TABLE, None),
        ("T6 a Date | Scope | Decision table: a By part with no quote fails", SCOPE_TABLE.replace(': "I approve the sync" (own message)', ""),
         "no approval"),
        ("T6 a Date | Scope | Decision table: the marker names the Decision cell", SCOPE_TABLE.replace("Old text -->", "Kit sync -->"),
         "matches no Decisions row"),
        ("T6 a Date | Scope | Decision table: a quote that holds a full stop is read whole",
         SCOPE_TABLE.replace('"I approve the sync"', '"Yes. Go ahead."'), None),
        ("T6 a Date | Scope | Decision table: a quote with no closing mark is still checked",
         SCOPE_TABLE.replace('"I approve the sync" (own message). Sync', '"Yes. Sync'), "no approval at its start"),
        ("T6 a Date | Scope | Decision table: mixed quote marks are no approval quote",
         SCOPE_TABLE.replace('"I approve the sync"', '“Yes. Go ahead."'), "no approval at its start"),
        ("T6 Scope table: markup around the role fails", SCOPE_TABLE.replace("By: the Maintainer:", "By: _the_ (Maintainer)"), "no approval at its start"),
        ("T6 Scope table: a row with no role word needs no quote", SCOPE_TABLE.replace(
            'By: the Maintainer: "I approve the sync" (own message).', "By: Agent. A recommendation."), None),
        ("T6 Scope table: a role word anywhere needs the approval at the start", SCOPE_TABLE.replace(
            'By: the Maintainer: "I approve the sync" (own message).', "By: Agent. Until the Maintainer approves."), "no approval at its start"),
        ("T6 a Date | Scope | Decision table: a later quote is no approval", SCOPE_TABLE.replace(
            'By: the Maintainer: "I approve the sync" (own message).', 'By: the Maintainer. Replaces "the plan" with "x".'), "no approval at its start"),
        ("T6 a Date | Scope | Decision table: a cell that does not start with By: fails",
         SCOPE_TABLE.replace('By: the Maintainer: "I approve the sync" (own message).', 'Sync. By: the Maintainer: "Yes".'),
         "no approval at its start"),
        ("T6 a Date | Scope | Decision | By table reads its By cell", SCOPE_TABLE.replace("| Replaces |", "| By |").replace(
            '| By: the Maintainer: "I approve the sync" (own message). Sync to 11.1.0. | - |', "| Sync. | the Maintainer |"),
         "quotes no approval"),
        ("T6 a By cell with the old role word Administrator needs a quote",
         DECISIONS_TABLE.replace(row, "| 2026-11-24 | New row | the Administrator | - |"), "quotes no approval"),
    ]
    t7 = [
        ("T7 clean coverage list passes", COVERAGE_GOOD, None),
        ("T7 ask row fails", COVERAGE_GOOD.replace("| A-2 | Two | out |", "| A-2 | Two | ask |"), "is marked ask"),
        ("T7 unmarked row fails", COVERAGE_GOOD.replace("| A-2 | Two | out |", "| A-2 | Two | |"), "has no mark"),
        ("T7 unknown mark fails", COVERAGE_GOOD.replace("| A-2 | Two | out |", "| A-2 | Two | maybe |"), "has no mark"),
        ("T7 count mismatch fails", COVERAGE_GOOD.replace("| A. Items | 2 | 1 | 1 |", "| A. Items | 2 | 2 | 0 |"), "counts table row A"),
        ("T7 total mismatch fails", COVERAGE_GOOD.replace("**3** | **1** | **1** | **1**", "**4** | **1** | **1** | **2**"),
         "counts table row TOTAL"),
        ("T7 group missing from the counts fails", COVERAGE_GOOD.replace("| B2. Extra | 1 | 0 | 0 | 1 | 0 |\n", ""), "group B2 has marked rows"),
        ("T7 no counts table fails", COVERAGE_GOOD.split("## F.")[0], "no 'Group | Rows"),
    ]
    return all([expect(name, check_decisions, text, want) for name, text, want in cases]
               + [expect(name, check_coverage, text, want) for name, text, want in t7])
