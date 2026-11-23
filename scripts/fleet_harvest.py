#!/usr/bin/env python3
"""Read a project's handoff and decisions files in the fleet format, for the fleet page and its format check.

Format: docs/reviews/2026-11-19-fleet-contract.md, section 2 (the Maintainer, 2026-11-19); steps: the handoff skill.
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
Parts: scripts/fleet_harvest_parse.py (the format reader; its names are re-exported here). Standard library only.
Network: none.
Writes: --harvest FILE.<repo>.pending of --state and, with --out, one JSON file per document; --save-state the --state file (and deletes that pending file);
    --add-ids docs/DECISIONS.md; --test temporary folders.
Credentials: none.
"""
import argparse
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys

from fleet_harvest_parse import (  # noqa: F401 - scripts/fleet_harvest_parse.py: the format reader (re-exported)
    CELL_SPLIT, DATE, DECISIONS_HEAD, NEED, NEEDED, NEXT, NONE_LINE, OPT_IN, ROW, ROW_START, SUMMARY_MAX, TIMELINE,
    UPDATED, digest, handoff_path, opted_in, parse_body, parse_decisions, parse_handoff, read_project, sections,
    stray_rows, summary)


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
        print("FLEET an ID is used more than once (in DECISIONS.md rows and \"Needs the Maintainer\" together): " + ", ".join(dup))
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
    import fleet_harvest_test  # kept apart so this file stays under the line cap (docs/code-standard.md)
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
