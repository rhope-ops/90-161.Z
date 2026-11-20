#!/usr/bin/env python3
"""Read a project's handoff and decisions files in the fleet format, for the fleet page and its format check.

Format: docs/reviews/2026-11-19-fleet-contract.md, section 2 (the PFM, 2026-11-19); steps: the handoff skill.
A project turns the format on with the line `fleet: on` in `.check`. Without it, --check prints a SKIP line.

Usage:
    python3 scripts/fleet_harvest.py --check [ROOT]
        The format check (scripts/check.sh runs it when `.check` has `fleet: on`): exit 1 when a line in "Needs the
        owner", "Timeline" or a docs/DECISIONS.md row cannot be read; it prints the file, line number and reason.
    python3 scripts/fleet_harvest.py --harvest ROOT --repo NAME --url URL [--branch B] [--state FILE] [--cross FILE]
        Prints JSON {"writes": [...], "deletes": [...], "counts": {...}}: the project's repos row (always, with
        harvested_at) and the items that changed since the hashes in --state. The repo's new hashes go to
        FILE.<repo>.pending; after its page write succeeds, `--save-state FILE --repo NAME` merges them into FILE
        (a failed write is sent again on the next run, also when other repos share FILE). --cross: a JSON file {"pull_requests": [{title,
        url}], "sessions": [{title, url}]} from the scheduled session; an entry that the handoff file does not name
        becomes a "Not filed" item. Decision text on the page is the first sentence, at most 140 characters.
        --out DIR: write each document to DIR/<collection>/<doc>.json and print only the batch entries (file paths)
        and the counts; the file of a deleted document is removed from DIR,
        so the page write costs few tokens.
    python3 scripts/fleet_harvest.py --add-ids [ROOT]
        Adds the `ID` column to docs/DECISIONS.md: D1 = the oldest row. A file whose decisions table has the column, or that has no decisions table, is left as it is.
    python3 scripts/fleet_harvest.py --test
        Self-test on fixture files in a temporary folder (cases: scripts/fleet_harvest_test.py); prints FLEET TEST PASS.
Standard library only.
Network: none.
Writes: --harvest FILE.<repo>.pending of --state and, with --out, one JSON file per document; --save-state the --state file (and deletes that pending file);
    --add-ids docs/DECISIONS.md; --test temporary folders.
Credentials: none.
"""
import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import subprocess
import sys

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
NEEDED = ("Timeline", "Needs the PFM")  # handoff sections the format check requires
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
            cur = re.sub(r"\s*\(.*\)\s*$", "", ln[3:].strip())  # "Needs the PFM (2)" -> "Needs the PFM"
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
             for n, m, s in parse_body(sec.get("Needs the PFM", []), NEED, name + " Needs the PFM", unread)]
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


def check(root):
    """--check: print the format findings of a project that opted in; return the exit code (1 on a finding).

    Args:
        root: the project folder.
    Returns:
        0 when the files can be read in full or the project has not opted in, else 1.
    """
    if not opted_in(root):
        print("SKIP  fleet format (no `" + OPT_IN + "` line in .check)")
        return 0
    h, rows, unread = read_project(root)
    for name, n, why in unread:
        print("FLEET " + name + ":" + str(n) + ": " + why)
    ids = [r["id"] for r in rows] + [d["id"] for d in h["needs"]]
    dup = sorted({i for i in ids if ids.count(i) > 1})
    if dup:
        print("FLEET an ID is used more than once (in DECISIONS.md rows and \"Needs the PFM\" together): " + ", ".join(dup))
    unset = [f for f, v in (("Updated:", h["updated"]), ("Next update:", h["next_update"])) if not v]
    print("fleet: %d open, %d resolved, %d lines not read%s" % (len(h["needs"]), len(rows), len(unread),
          "; not set: " + ", ".join(unset) if unset else ""))
    return 1 if unread or dup else 0


def not_filed(cross, text):
    """The entries of the cross-check input that the handoff text does not name (by URL or by title).

    Args:
        cross: {"pull_requests": [...], "sessions": [...]}, each entry {title, url}.
        text: the handoff file text.
    Returns:
        [{text, url, source}] for the page's "Not filed" items.
    """
    out = []
    for source in ("pull_requests", "sessions"):
        for e in cross.get(source, []):
            url, title = e.get("url", ""), e.get("title", "")
            num = re.search(r"/pull/(\d+)/?$", url)
            if num:  # a pull request: its whole URL, or "#<n>" as a whole number; never its title
                named = whole(url, text, subpath=True) or re.search(r"(?<![\w/#])#" + num.group(1) + r"(?!\d)", text)
            else:  # a session: its whole URL or its whole title
                named = whole(url, text) or whole(title, text)
            if not named:
                out.append({"text": summary(title or url), "url": url, "source": source})
    return out


def whole(needle, text, subpath=False):
    """True when needle is in text as a whole: no letter, digit or slash right before it, nor right after it (see subpath).

    Args:
        needle: a URL or a title; a trailing slash is ignored.
        text: the handoff file text.
        subpath: True for a pull request URL: a "/" and a non-digit may follow (.../pull/1/files, never .../pull/1/2).
    Returns:
        True when the whole needle is found.
    """
    needle = needle.rstrip("/")
    tail = r"(?:/(?!\d)|(?![\w/]))" if subpath else r"/?(?![\w/])"
    return bool(needle) and re.search(r"(?<![\w/])" + re.escape(needle) + tail, text) is not None


def source_commit(root):
    """The short commit of the project folder (git rev-parse), or "" when it is no git checkout."""
    try:
        r = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def documents(root, repo, url, cross, branch="main"):
    """{path: data} of every page document of one project (contract section 3).

    Args:
        root: the project folder.
        repo: the project name on the page.
        url: the repo URL on GitHub, for links to lines.
        cross: the cross-check input (see not_filed), or {}.
        branch: the branch the links point at.
    Returns:
        A dict from document path (repos/<repo> and items/<repo>~<id>) to its fields.
    """
    h, rows, unread = read_project(root)
    key = repo.replace("/", "_")
    hp = handoff_path(root).relative_to(root).as_posix()
    blob = url + "/blob/" + branch + "/"
    docs = {}
    for r in rows:
        docs["items/" + key + "~" + r["id"]] = {
            "repo": repo, "id": r["id"], "kind": "resolved", "date": r["date"], "summary": summary(r["text"]),
            "by": r["by"], "approved": not r["by"].startswith("Agent"), "options": [], "rec": "",
            "url": blob + "docs/DECISIONS.md#L" + str(r["line"]), "hash": digest(r["raw"])}
    for d in h["needs"]:
        docs["items/" + key + "~" + d["id"]] = {
            "repo": repo, "id": d["id"], "kind": "open", "date": h["updated"] or "", "summary": summary(d["text"]),
            "by": "", "approved": False, "options": d["options"], "rec": d["rec"],
            "url": blob + hp + "#L" + str(d["line"]), "hash": digest(d["raw"])}
    text = (root / hp).read_text(encoding="utf-8") if (root / hp).exists() else ""
    docs["repos/" + key] = {"repo": repo, "last_update": h["updated"], "next_update": h["next_update"],
                            "timeline": h["timeline"], "open_steps": h["steps"], "open_count": len(h["needs"]),
                            "unread_lines": len(unread), "not_filed": not_filed(cross, text)}
    return docs


def harvest(root, repo, url, state_file, cross, branch="main"):
    """--harvest: the repos row and the items changed since the last run, as one JSON object.

    Args:
        root: the project folder.
        repo: the project name on the page.
        url: the repo URL on GitHub.
        state_file: a JSON file {path: hash} of the last run, or None (then every document is written). This repo's
            new hashes go to <state_file>.<repo>.pending; save_state(state_file, repo) merges them in after the page
            write succeeds.
        cross: the cross-check input, or {}.
        branch: the branch the links point at.
    Returns:
        {"writes": [{path, op, data}], "deletes": [path], "counts": {...}}. The repos row is always written, as a
        merge update with harvested_at and source_commit, so other fields there are kept and the page shows its age.
    """
    docs = documents(root, repo, url, cross, branch)
    old = json.loads(state_file.read_text(encoding="utf-8")) if state_file and state_file.exists() else {}
    new = {p: digest(json.dumps(d, sort_keys=True)) for p, d in docs.items()}
    writes = [{"path": p, "op": "update" if p.startswith("repos/") else "set", "data": docs[p]}
              for p in sorted(docs) if p.startswith("repos/") or old.get(p) != new[p]]
    for w in writes:
        if w["path"].startswith("repos/"):
            w["data"].update(harvested_at=dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                             source_commit=source_commit(root))
    deletes = sorted(p for p in old if mine(p, repo) and p not in new)
    if state_file:  # this repo's hashes only; --save-state merges them in after the page write
        pending_file(state_file, repo).write_text(json.dumps(new, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    items = sum(1 for w in writes if w["path"].startswith("items/"))
    return {"writes": writes, "deletes": deletes, "counts": {"documents": len(docs), "items_changed": items, "deleted": len(deletes)}}


def mine(path, repo):
    """True when a page document path belongs to repo (repos/<key> or items/<key>~<id>; "kit" is not "my-kit")."""
    key = repo.replace("/", "_")
    return path == "repos/" + key or path.startswith("items/" + key + "~")


def pending_file(state_file, repo):
    """The file that holds one repo's new hashes until its page write succeeds: <state_file>.<repo>.pending."""
    return pathlib.Path(str(state_file) + "." + repo.replace("/", "_") + ".pending")


def to_files(result, out):
    """--out: write each document of a harvest result to <out>/<collection>/<doc>.json; return the short form.

    Args:
        result: the harvest result.
        out: the folder for the document files.
    Returns:
        {"writes": [{op, collection, doc_id, file_path}], "deletes": [{op: "delete", collection, doc_id}], "counts"}: the entries of
        one ArtifactData batch, so the page write sends file paths, not document text (fewer tokens). The file of a
        deleted document is removed from out, so a reused folder holds no stale document.
    """
    writes = []
    for w in result["writes"]:
        collection, doc_id = w["path"].split("/", 1)
        f = out / collection / (doc_id + ".json")
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(w["data"], indent=1, sort_keys=True) + "\n", encoding="utf-8")
        writes.append({"op": w["op"], "collection": collection, "doc_id": doc_id, "file_path": str(f.resolve())})
    deletes = [dict(zip(("op", "collection", "doc_id"), ["delete"] + p.split("/", 1))) for p in result["deletes"]]
    for d in deletes:
        (out / d["collection"] / (d["doc_id"] + ".json")).unlink(missing_ok=True)
    return {"writes": writes, "deletes": deletes, "counts": result["counts"]}


def save_state(state_file, repo):
    """--save-state: after the page write of repo succeeded, put its pending hashes into state_file.

    Args:
        state_file: the shared state file.
        repo: the project name of the --harvest run.
    Returns:
        0, or 1 when that repo has no pending file. Other repos' hashes in state_file are kept as they are.
    """
    pending = pending_file(state_file, repo)
    if not pending.exists():
        print("no " + pending.name + ": run --harvest first")
        return 1
    old = json.loads(state_file.read_text(encoding="utf-8")) if state_file.exists() else {}
    keep = {p: v for p, v in old.items() if not mine(p, repo)}
    new = json.loads(pending.read_text(encoding="utf-8"))
    state_file.write_text(json.dumps({**keep, **new}, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    pending.unlink()
    return 0


def add_ids(root):
    """--add-ids: add the ID column to the decisions table of docs/DECISIONS.md (found by DECISIONS_HEAD) (D1 = the oldest row, the last one).

    Args:
        root: the project folder.
    Returns:
        The number of rows that got an ID (0 when the decisions table already has the column, or there is none). Line
        endings are kept.
    """
    f = root / "docs/DECISIONS.md"
    with open(f, encoding="utf-8", newline="") as fh:
        lines = fh.read().splitlines(keepends=True)
    head = next((i for i, ln in enumerate(lines) if DECISIONS_HEAD.match(ln)), None)
    if head is None or re.match(r"^\|\s*ID\s*\|", lines[head]):
        return 0
    end = next((i for i in range(head + 2, len(lines)) if not lines[i].startswith("|")), len(lines))
    rows = [i for i in range(head + 2, end) if re.match(r"^\|\s*" + DATE + r"\s*\|", lines[i])]
    for k, i in enumerate(reversed(rows), 1):
        lines[i] = "| D" + str(k) + " " + lines[i]
    lines[head] = "| ID " + lines[head]
    lines[head + 1] = "|---" + lines[head + 1]
    with open(f, "w", encoding="utf-8", newline="") as fh:
        fh.write("".join(lines))
    return len(rows)


def selftest():
    """--test: run the cases in scripts/fleet_harvest_test.py on this module; return the exit code."""
    import fleet_harvest_test  # kept apart so this file stays under the 600-line cap (docs/code-standard.md)
    return fleet_harvest_test.run(sys.modules[__name__])


def main(argv=None):
    """Parse the options and run the chosen mode; return its exit code.

    Args:
        argv: the arguments (default: sys.argv[1:]).
    Returns:
        The exit code.
    """
    ap = argparse.ArgumentParser(description="Fleet format check and harvest (see the file header).")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", nargs="?", const=".", metavar="ROOT")
    mode.add_argument("--harvest", metavar="ROOT")
    mode.add_argument("--add-ids", nargs="?", const=".", metavar="ROOT")
    mode.add_argument("--save-state", type=pathlib.Path, metavar="FILE")
    mode.add_argument("--test", action="store_true")
    ap.add_argument("--repo")
    ap.add_argument("--url")
    ap.add_argument("--branch", default="main")
    ap.add_argument("--out", type=pathlib.Path, help="--harvest: write each document to a file; print only the paths")
    ap.add_argument("--state", type=pathlib.Path)
    ap.add_argument("--cross", type=pathlib.Path)
    a = ap.parse_args(argv)
    if a.test:
        return selftest()
    if a.check:
        return check(pathlib.Path(a.check))
    if a.save_state:
        if not a.repo:
            ap.error("--save-state needs --repo")
        return save_state(a.save_state, a.repo)
    if a.add_ids:
        print("added IDs to %d rows" % add_ids(pathlib.Path(a.add_ids)))
        return 0
    if not (a.repo and a.url):
        ap.error("--harvest needs --repo and --url")
    cross = json.loads(a.cross.read_text(encoding="utf-8")) if a.cross else {}
    result = harvest(pathlib.Path(a.harvest), a.repo, a.url.rstrip("/"), a.state, cross, a.branch)
    print(json.dumps(to_files(result, a.out) if a.out else result, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
