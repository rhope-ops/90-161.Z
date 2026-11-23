#!/usr/bin/env python3
"""The fleet format reader: the patterns and parsers that read a project's handoff and docs/DECISIONS.md.

Part of scripts/fleet_harvest.py (split out to keep each file under the line cap of docs/code-standard.md C4);
fleet_harvest.py imports every name here and re-exports it, so `fleet_harvest.<name>` keeps working.
Format: docs/reviews/2026-11-19-fleet-contract.md, section 2 (the Maintainer, 2026-11-19).
Inputs:  the text of docs/NEXT_PROMPT.md (or the handoff file) and docs/DECISIONS.md of a project folder.
Outputs: parsed dicts and rows, and the lines that cannot be read; no output of its own.
Usage:   imported by scripts/fleet_harvest.py; it has no command line.
Network: none.
Writes: none.
Credentials: none.
"""
import hashlib
import re


OPT_IN = "fleet: on"  # the `.check` line that turns the format on (contract section 1)
SUMMARY_MAX = 140  # characters of decision text on the page (contract section 3)
DATE = r"\d{4}-\d{2}-\d{2}"
UPDATED = re.compile(r"^Updated:\s*(" + DATE + r"(?: \d{2}:\d{2})?)")
NEXT = re.compile(r"^Next update:\s*(" + DATE + r"),\s*(.+)$")
TIMELINE = re.compile(r"^- (" + DATE + r") · (.+?) · (planned|done)\s*$")
NEED = re.compile(r"^- (D\d+) · (.+?) · Options: (.+?) · REC: (.+?)\s*$")
ROW = re.compile(r"^\|\s*(D\d+)\s*\|\s*(" + DATE + r")\s*\|(.*)\|\s*$")
ROW_START = re.compile(r"(?i)^\|\s*(D\d+\s*\||" + DATE + r"\s*\|)")  # any decision row, also one that ROW does not read
CELL_SPLIT = re.compile(r"(?<!\\)\|")  # a cell border; an escaped pipe (\|) stays inside the cell
DECISIONS_HEAD = re.compile(r"^\|\s*(ID\s*\|\s*Date|Date\s*\|\s*Decision)\s*\|")  # the decisions table header
NEEDED = ("Timeline", "Needs the Maintainer")  # handoff sections the format check requires
NONE_LINE = re.compile(r"^-?\s*(none|nothing)\.?\s*$", re.I)


def opted_in(root):
    """True when `.check` in root has the line `fleet: on`."""
    f = root / ".check"
    return f.exists() and OPT_IN in (ln.strip() for ln in f.read_text(encoding="utf-8").splitlines())


def handoff_path(root):
    """The handoff file: docs/KIT_HANDOFF.md in the kit itself, else docs/NEXT_PROMPT.md."""
    kit = root / "docs/KIT_HANDOFF.md"
    return kit if kit.exists() else root / "docs/NEXT_PROMPT.md"


def sections(lines):
    """{heading: [(line number, text)]} of the `## ` sections of a Markdown file.

    Args:
        lines: the lines of the file.
    Returns:
        A dict from each heading text (without "## ") to its body lines, with 1-based line numbers.
    """
    out, cur = {}, None
    for n, ln in enumerate(lines, 1):
        if ln.startswith("## "):
            cur = re.sub(r"\s*\(.*\)\s*$", "", ln[3:].strip())  # "Needs the Maintainer (2)" -> "Needs the Maintainer"
            cur = NEEDED[1] if cur.startswith("Needs the ") else cur  # any role word: "Needs the PFM" too
            out.setdefault(cur, [])
        elif cur is not None:
            out[cur].append((n, ln))
    return out


def summary(text):
    """The first sentence of a text, at most SUMMARY_MAX characters (an ellipsis marks a cut)."""
    first = re.split(r"(?<=[.!?])\s", text.strip(), maxsplit=1)[0]
    return first if len(first) <= SUMMARY_MAX else first[:SUMMARY_MAX - 1].rstrip() + "…"


def digest(text):
    """A short stable hash of a text (the page compares it to find a stale choice)."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def parse_body(body, pattern, name, unread):
    """The matches of pattern in the bullet lines of a section; other non-empty lines go to unread.

    Args:
        body: [(line number, text)] of one section.
        pattern: the regular expression that one line must match.
        name: the file and section name for an unread entry.
        unread: a list that gets (name, line number, reason) for each line that does not match.
    Returns:
        [(line number, match, text)] of the lines that match.
    """
    found = []
    for n, ln in body:
        s = ln.rstrip()
        if not s.strip() or NONE_LINE.match(s.strip()):
            continue
        m = pattern.match(s)
        if m:
            found.append((n, m, s))
        else:
            unread.append((name, n, "not in the fleet format"))
    return found


def parse_handoff(text, name):
    """The fleet fields of a handoff file.

    Args:
        text: the file text.
        name: the file name, for unread entries.
    Returns:
        A dict: updated, next_update ({date, text} or None), timeline, needs, steps, unread.
    """
    lines = text.splitlines()
    unread = []
    updated = next((m.group(1) for m in map(UPDATED.match, lines) if m), None)
    nxt = next((m for m in map(NEXT.match, lines) if m), None)
    sec = sections(lines)
    unread += [(name, 0, "missing section: ## " + h) for h in NEEDED if h not in sec]
    timeline = [{"date": m.group(1), "text": summary(m.group(2)), "state": m.group(3)}
                for _, m, _ in parse_body(sec.get("Timeline", []), TIMELINE, name + " Timeline", unread)]
    needs = [{"id": m.group(1), "text": m.group(2).strip(), "options": [o.strip() for o in m.group(3).split("/")],
              "rec": m.group(4).strip(), "line": n, "raw": s}
             for n, m, s in parse_body(sec.get(NEEDED[1], []), NEED, name + " " + NEEDED[1], unread)]
    steps = [summary(re.sub(r"^(\d+\.|-)\s*", "", ln.strip())) for _, ln in sec.get("Open", [])
             if re.match(r"^(\d+\.|-)\s", ln.strip())]
    return {"updated": updated, "next_update": {"date": nxt.group(1), "text": nxt.group(2).strip()} if nxt else None,
            "timeline": timeline, "needs": needs, "steps": steps, "unread": unread}


def parse_decisions(text, name):
    """The rows of a decisions table that has the ID column.

    Args:
        text: the text of docs/DECISIONS.md.
        name: the file name, for unread entries.
    Returns:
        (rows, unread): rows is [{id, date, text, by, line, raw}]; unread is [(name, line number, reason)].
    """
    rows, unread = [], []
    lines = text.splitlines()
    head = next((i for i, ln in enumerate(lines) if DECISIONS_HEAD.match(ln)), len(lines))
    end = next((i for i in range(head + 1, len(lines)) if not lines[i].startswith("|")), len(lines))
    if head == len(lines):
        unread.append((name, 0, "no decisions table: its header must start | ID | Date | or | Date | Decision |"))
    unread += [(name, n, "a decision row outside the decisions table (a blank line inside the table?)")
               for n in stray_rows(lines, range(head, end))]
    for n, ln in enumerate(lines[head + 2:end], head + 3):  # the decisions table only; other tables are not read
        if not ROW_START.match(ln):
            continue
        m = ROW.match(ln.rstrip("\r"))
        cells = CELL_SPLIT.split(m.group(3)) if m else []
        if not m or len(cells) != 3:
            unread.append((name, n, "a decision row needs 5 cells: ID | Date | Decision | By | Replaces"))
            continue
        rows.append({"id": m.group(1), "date": m.group(2), "text": cells[0].strip().replace("\\|", "|"), "by": cells[1].strip(),
                     "line": n, "raw": ln})
    return rows, unread


def stray_rows(lines, table):
    """1-based numbers of decision-shaped rows outside the decisions table that are not in a table with its own header.

    Args:
        lines: the lines of docs/DECISIONS.md.
        table: the range of line indexes of the decisions table (empty when there is none).
    Returns:
        [line number] of each such row, above or below the table (another table with a header row, for example a list
        of links, is not reported; with no decisions table, every decision-shaped row is reported).
    """
    out, headed = [], False
    for i, ln in enumerate(lines):
        if ln.startswith("|") and (i == 0 or not lines[i - 1].startswith("|")):
            headed = not ROW_START.match(ln)  # a table starts: does it start with a header row?
        if i not in table and ROW_START.match(ln) and not (headed and table):  # no decisions table: report every row
            out.append(i + 1)
    return out


def read_project(root):
    """The parsed handoff and decisions of a project folder: (handoff dict, decision rows, all unread entries)."""
    hp, dp = handoff_path(root), root / "docs/DECISIONS.md"
    h = parse_handoff(hp.read_text(encoding="utf-8") if hp.exists() else "", hp.name)
    if not hp.exists():
        h["unread"] = [(hp.name, 0, "missing file")]
    rows, bad = parse_decisions(dp.read_text(encoding="utf-8"), dp.name) if dp.exists() else ([], [])
    return h, rows, h["unread"] + bad
