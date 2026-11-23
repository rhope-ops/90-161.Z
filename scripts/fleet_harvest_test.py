#!/usr/bin/env python3
"""Self-test cases of scripts/fleet_harvest.py (run by `python3 scripts/fleet_harvest.py --test`; kept in its own file
so that file stays under the line cap of docs/code-standard.md).

Fixture projects in a temporary folder: the format check, --add-ids, --harvest with a state file shared by two repos,
--save-state, the cross-check matching and the edge cases that earlier reviews found.
Network: none.
Writes: temporary folders only.
Credentials: none.
"""
import contextlib
import io
import pathlib
import tempfile
import unittest

M = None  # the fleet_harvest module under test (set by run)


HANDOFF_OK = """# Next prompt
Updated: 2026-11-19 14:50 by a session.
Next update: 2026-11-25, the pilot result

## State
- main: abc1234

## Timeline

- 2026-11-20 · Kit pull request · done
- 2026-12-01 · Pilot · planned

## Open (in order)

1. Build the page. Then test it.

## Needs the Maintainer

- D3 · Drop the old export? · Options: yes / no · REC: yes
- D4 · Tag v4.0.0 (see #12) · Options: done / not done · REC: done
"""
DECISIONS_OLD = """# Decisions

| Date | Decision | By | Replaces |
|---|---|---|---|
| 2026-11-19 | Keep CSV. It works. | the Maintainer | - |
| 2026-11-18 | Use semantic versions. | Agent | - |
"""


def make_project(base, handoff, decisions, opt_in=True):
    """A fixture project folder under base, with the given files; returns its path."""
    root = pathlib.Path(tempfile.mkdtemp(dir=base))
    (root / "docs").mkdir()
    (root / "docs/NEXT_PROMPT.md").write_text(handoff, encoding="utf-8")
    (root / "docs/DECISIONS.md").write_text(decisions, encoding="utf-8")
    (root / ".check").write_text("code-c2: full\n" + (M.OPT_IN + "\n" if opt_in else ""), encoding="utf-8")
    return root


def quiet(fn, *args):
    """Run fn(*args) with its printed lines caught; returns (result, printed text)."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        res = fn(*args)
    return res, buf.getvalue()


def format_cases(base):
    """The self-test cases; returns a list of (name, passed).

    Args:
        base: a temporary folder for the fixture projects.
    Returns:
        [(case name, True when it passed)].
    """
    out = []
    ok = lambda name, cond: out.append((name, bool(cond)))  # noqa: E731 (one-line recorder)
    p = make_project(base, HANDOFF_OK, DECISIONS_OLD)
    ok("add-ids numbers 2 rows", M.add_ids(p) == 2)
    text = (p / "docs/DECISIONS.md").read_text(encoding="utf-8")
    ok("oldest row is D1", "| D1 | 2026-11-18 |" in text and "| D2 | 2026-11-19 |" in text and "| ID | Date |" in text)
    ok("add-ids leaves a file with IDs", M.add_ids(p) == 0)
    code, printed = quiet(M.check, p)
    ok("a valid project passes the check", code == 0 and "2 open, 2 resolved, 0 lines not read" in printed)
    h, rows, _ = M.read_project(p)
    ok("next update read", h["next_update"] == {"date": "2026-11-25", "text": "the pilot result"})
    ok("timeline read", [t["state"] for t in h["timeline"]] == ["done", "planned"])
    ok("options split", h["needs"][0]["options"] == ["yes", "no"] and h["needs"][0]["rec"] == "yes")
    ok("summary is the first sentence", M.summary("Keep CSV. It works.") == "Keep CSV.")
    ok("summary is cut at 140", len(M.summary("x" * 300)) == M.SUMMARY_MAX)
    bad = make_project(base, HANDOFF_OK.replace("- D3 · Drop", "- Drop"), DECISIONS_OLD)
    code, printed = quiet(M.check, bad)
    ok("a need without an ID fails", code == 1 and "NEXT_PROMPT.md Needs the Maintainer:" in printed)
    ok("rows without IDs fail", printed.count("DECISIONS.md:") == 2)
    off = make_project(base, "x", "y", opt_in=False)
    code, printed = quiet(M.check, off)
    ok("no opt-in: SKIP", code == 0 and printed.startswith("SKIP"))
    out += harvest_cases(base, p) + edge_cases(base)
    return out


def harvest_cases(base, p):
    """The --harvest self-test cases on the fixture project p; returns [(name, passed)].

    Args:
        base: a temporary folder for the state file.
        p: a fixture project with IDs.
    Returns:
        [(case name, True when it passed)].
    """
    out = []
    ok = lambda name, cond: out.append((name, bool(cond)))  # noqa: E731 (one-line recorder)
    state = pathlib.Path(base) / "state.json"
    cross = {"pull_requests": [{"title": "Tag", "url": "https://x/pull/12"}, {"title": "New thing", "url": "https://x/pull/13"}],
             "sessions": [{"title": "Kit · Fleet · 2026-11-19", "url": "https://s/1"}]}
    first = M.harvest(p, "demo", "https://github.com/o/demo", state, cross)
    ok("first run writes every document", first["counts"] == {"documents": 5, "items_changed": 4, "deleted": 0})
    ok("state waits for --save-state", not state.exists() and M.save_state(state, "demo") == 0 and state.exists())
    second = M.harvest(p, "demo", "https://github.com/o/demo", state, cross)
    M.save_state(state, "demo")
    ok("second run: 0 items, the repos row only", second["counts"]["items_changed"] == 0 and not second["deletes"]
       and [w["path"] for w in second["writes"]] == ["repos/demo"])
    repo = [w for w in first["writes"] if w["path"] == "repos/demo"][0]["data"]
    ok("open steps are read", repo["open_steps"] == ["Build the page."])
    short = M.to_files(first, pathlib.Path(base) / "out")
    entry = [w for w in short["writes"] if w["doc_id"] == "demo~D1"][0]
    ok("--out writes files and prints paths", entry["collection"] == "items" and pathlib.Path(entry["file_path"]).exists()
       and "data" not in entry)
    ok("repos row has its age", repo["harvested_at"].endswith("Z") and "source_commit" in repo and repo["unread_lines"] == 0)
    ok("unfiled PR and session found, filed PR not", [n["url"] for n in repo["not_filed"]] == ["https://x/pull/13", "https://s/1"])
    agent = [w["data"] for w in first["writes"] if w["path"] == "items/demo~D1"][0]
    ok("an Agent row is not approved", agent["approved"] is False and agent["kind"] == "resolved")
    ok("links point at the line", agent["url"].endswith("/blob/main/docs/DECISIONS.md#L6"))
    other = M.harvest(p, "other", "https://github.com/o/other", state, {})
    ok("a shared state file: no delete of another repo", not other["deletes"])
    M.save_state(state, "other")
    hp0 = p / "docs/NEXT_PROMPT.md"
    hp0.write_text(hp0.read_text(encoding="utf-8").replace("Drop the old export?", "Drop the old export now?"), encoding="utf-8")
    M.harvest(p, "demo", "https://github.com/o/demo", state, cross)  # its page write fails: no --save-state for demo
    M.harvest(p, "other", "https://github.com/o/other", state, {})
    M.save_state(state, "other")
    ok("a failed write is sent again (shared state)", M.harvest(p, "demo", "https://github.com/o/demo", state, cross)["counts"]["items_changed"] == 1)
    M.save_state(state, "demo")
    hp = p / "docs/NEXT_PROMPT.md"
    hp.write_text(hp.read_text(encoding="utf-8").replace("- D4 · Tag v4.0.0 (see #12) · Options: done / not done · REC: done\n", ""),
                  encoding="utf-8")
    third = M.harvest(p, "demo", "https://github.com/o/demo", state, cross)
    ok("a closed need is deleted", third["deletes"] == ["items/demo~D4"])
    gone = M.to_files(third, pathlib.Path(base) / "out")
    ok("--out lists the delete and removes its file", gone["deletes"] == [{"op": "delete", "collection": "items", "doc_id": "demo~D4"}]
       and not (pathlib.Path(base) / "out/items/demo~D4.json").exists())
    pr1 = {"pull_requests": [{"title": "Fix", "url": "https://x/pull/1"}]}
    ok("#1 is not #12", M.not_filed(pr1, "see #12. Fix") != [] and M.not_filed(pr1, "see https://x/pull/12") != [])
    ok("#1 is named", M.not_filed(pr1, "see #1.") == [] and M.not_filed(pr1, "(https://x/pull/1)") == [])
    ok("a trailing slash still names it", M.not_filed({"sessions": [{"title": "T", "url": "https://s/1/"}]}, "see https://s/1.") == []
       and M.not_filed(pr1, "see https://x/pull/1/ now") == [])
    ok("a session URL needs its end", M.not_filed({"sessions": [{"title": "T", "url": "https://s/1"}]}, "https://s/12") != [])
    return out


def edge_cases(base):
    """Self-test cases for lines the format check must fail, and --add-ids edge cases; returns [(name, passed)].

    Args:
        base: a temporary folder for the fixture projects.
    Returns:
        [(case name, True when it passed)].
    """
    out = []
    ok = lambda name, cond: out.append((name, bool(cond)))  # noqa: E731 (one-line recorder)
    rows = "| ID | Date | Decision | By | Replaces |\n|---|---|---|---|---|\n| D1 | 2026-11-18 | A. | the Maintainer | - |\n"
    dup_need = HANDOFF_OK.replace("- D4 · Tag", "- D3 · Tag")
    ok("two needs with one ID fail", quiet(M.check, make_project(base, dup_need, rows))[0] == 1)
    ok("a need with a row's ID fails", quiet(M.check, make_project(base, HANDOFF_OK.replace("- D4 ·", "- D1 ·"), rows))[0] == 1)
    bad_date = rows + "| D9 | 19.11.2026 | y | the Maintainer | - |\n| D8 | | z | the Maintainer | - |\n"
    code, printed = quiet(M.check, make_project(base, HANDOFF_OK, bad_date))
    ok("rows with a bad or empty date fail", code == 1 and printed.count("DECISIONS.md:") == 2)
    ok("an escaped pipe is shown plain", M.read_project(make_project(base, HANDOFF_OK, rows.replace("| A. |", "| A \\| B. |")))[1][0]["text"] == "A | B.")
    gap = rows + "\n| D2 | 2026-11-19 | B. | the Maintainer | - |\n"
    ok("a row after a blank line in the table fails", quiet(M.check, make_project(base, HANDOFF_OK, gap))[0] == 1)
    nohead = make_project(base, HANDOFF_OK, DECISIONS_OLD.replace("| Decision |", "| Choice |"))
    ok("a file with no decisions table header fails", quiet(M.check, nohead)[0] == 1
       and sorted(n for _, n, _ in M.read_project(nohead)[2] if n) == [5, 6])
    ok("a title before a slash is not named", M.not_filed({"sessions": [{"title": "Fleet harvest", "url": "u"}]}, "Fleet harvest/check") != [])
    idfirst = make_project(base, HANDOFF_OK, "| ID | Name |\n|---|---|\n| a | b |\n\n" + DECISIONS_OLD)
    ok("an earlier ID table does not stop add-ids", M.add_ids(idfirst) == 2 and quiet(M.check, idfirst)[0] == 0)
    above = "| D5 | 2026-11-19 | x | the Maintainer | - |\n\n" + rows
    ok("a row above the decisions table fails", quiet(M.check, make_project(base, HANDOFF_OK, above))[0] == 1)
    ok("a link to the files tab names the PR", M.not_filed({"pull_requests": [{"url": "https://x/pull/1"}]}, "https://x/pull/1/files") == [])
    ok("a lowercase ID row fails", quiet(M.check, make_project(base, HANDOFF_OK, rows + "| d4 | 2026-11-19 | x | the Maintainer | - |\n"))[0] == 1)
    ok("an escaped pipe stays in its cell", quiet(M.check, make_project(base, HANDOFF_OK, rows.replace("| A. |", "| A \\| B. |")))[0] == 0)
    ok("a missing section fails", quiet(M.check, make_project(base, HANDOFF_OK.replace("## Timeline", "## Plan"), rows))[0] == 1)
    ok("a counted heading is read", quiet(M.check, make_project(base, HANDOFF_OK.replace("## Needs the Maintainer", "## Needs the Maintainer (2)"), rows))[0] == 0)
    ok("a heading with another role word is read (a project's own handoff)",
       quiet(M.check, make_project(base, HANDOFF_OK.replace("## Needs the Maintainer", "## Needs the PFM"), rows))[0] == 0)
    crlf = ("| Date | Event |\r\n|---|---|\r\n| 2025-01-01 | y |\r\n\r\n" + DECISIONS_OLD.replace("\n", "\r\n")
            + "\r\n| Date | Other |\r\n|---|---|\r\n| 2026-01-01 | x |\r\n")
    p = make_project(base, HANDOFF_OK, crlf)
    ok("add-ids numbers only the decisions table", M.add_ids(p) == 2)
    ok("after add-ids the check passes (a second table is not read)", quiet(M.check, p)[0] == 0)
    raw = (p / "docs/DECISIONS.md").read_bytes()
    ok("add-ids keeps CRLF and the second table", b"| D1 | 2026-11-18 |" in raw and b"\r\n| 2025-01-01 | y |\r\n" in raw and b"\r\n| 2026-01-01 | x |\r\n" in raw and b"\n\n" not in raw)
    return out


def run(module):
    """Run every case against the fleet_harvest module; print each failure and FLEET TEST PASS or FAIL.

    Args:
        module: the fleet_harvest module (its functions are tested).
    Returns:
        The exit code: 0 when every case passed, else 1.
    """
    global M
    M = module
    with tempfile.TemporaryDirectory() as base:
        results = format_cases(base)
    failed = [n for n, passed in results if not passed]
    for n in failed:
        print("FAIL  " + n)
    print(("FLEET TEST PASS: %d cases" % len(results)) if not failed else "FLEET TEST FAIL: %d of %d" % (len(failed), len(results)))
    return 1 if failed else 0


class FleetHarvestTest(unittest.TestCase):
    """The cases of `python3 scripts/fleet_harvest.py --test`, for `python3 -m unittest` and pytest."""

    def test_self_test(self):
        """Every case passes on the fleet_harvest module."""
        import fleet_harvest  # scripts/fleet_harvest.py: imported here, so a plain import of this file loads nothing
        self.assertEqual(run(fleet_harvest), 0)
