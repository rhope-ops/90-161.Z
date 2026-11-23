#!/usr/bin/env python3
"""Self-test of scripts/bloat_check.py (run by `python3 scripts/bloat_check.py --test`; kept in its own file so the
check stays under the line cap of docs/code-standard.md C4).

It builds small sample repos in temporary folders and proves each measure: duplicates, big files, the audit due date
(also for a repo never audited, a new repo and a shallow clone), timings, the rule count by place, the caps, the
paths AGENTS.md names, the conflict gate, the rule lint, the start-read warning, --compare and --record, the settings
in `.check` and the state in `.check.state.json`, and the skills check (scripts/bloat_check_skills.py).
Input: the bloat_check module. Output: BLOAT TEST PASS, or an AssertionError naming the case. Needs git.
Network: none.
Writes: temporary repos only.
Credentials: none.
"""
import argparse
import contextlib
import datetime
import io
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

import bloat_check_skills as skills
import check_settings
from bloat_check_test_rules import (caps_and_paths_cases, conflict_gate_cases, git_in, lint_cases,  # noqa: F401
                                    readme_cases, rule_count_cases, settings, third_party_cases)

LONG = "This line is long enough to count as a duplicate when it shows up in two different files of a repo."


def sample_repo(bloat, root):
    """A repo with a duplicate line, a long handoff, a big file and settings with low budgets; returns its config.

    Args:
        bloat: the module under test.
        root: an empty temporary folder (a Path).

    Returns:
        The audit settings of the sample repo.
    """
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    (root / "AGENTS.md").write_text(f"# A\n- {LONG}\n")
    (root / "docs").mkdir()
    (root / "docs/NEXT_PROMPT.md").write_text(f"{LONG.upper()}\n" + "x\n" * 45)
    (root / "big.txt").write_text("y" * 3000)
    (root / "scripts").mkdir()
    (root / "scripts/ok.sh").write_text("exit 0\n")  # the timed commands must start with "bash scripts/"
    (root / "scripts/fail.sh").write_text("exit 1\n")
    settings(root, "audit-budget-file_kb: 2\naudit-budget-session_load_tokens: 10\n",
             audit={"last_audit": {"date": "2026-01-01"}}, timings={"t": {"cmd": "bash scripts/ok.sh", "seconds": 5}})
    subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
    return bloat.load_config(root)


def generated_block_cases(bloat, root, cfg):
    """Duplicates: the lines of a marked generated block are not counted; a line after its end marker is.

    Args:
        bloat: the module under test.
        root: the sample repo of sample_repo (a Path); it is left as it was.
        cfg: its audit settings.
    """
    gen = "x = 1\n# >>> blk: generated from src by build (do not edit)\n" + "g" * 90 + "\n# <<< blk\n"
    (root / "g1.ps1").write_text(gen)
    (root / "g2.ps1").write_text(gen + "h" * 90 + "\n")
    (root / "g3.ps1").write_text("h" * 90 + "\n")
    subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
    assert len(bloat.duplicates(root, bloat.scan_files(root, cfg))) == 2, "generated block not counted; a line after its end marker is"
    for g in ("g1.ps1", "g2.ps1", "g3.ps1"):
        (root / g).unlink()
    subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)


def metrics_cases(bloat, root, cfg):
    """Duplicates, big files, the audit due date by days, and a never-audited repo with no commits."""
    files = bloat.scan_files(root, cfg)
    assert len(bloat.duplicates(root, files)) == 1, "duplicate across files, case and bullets ignored"
    assert [f for f, _ in bloat.big_files(root, files, 2)] == ["big.txt"], "big file"
    assert "days since" in bloat.audit_due(root, cfg, datetime.date(2026, 2, 1)), "due by days"
    assert bloat.audit_due(root, cfg, datetime.date(2026, 1, 5)) == "", "not due"
    never = {**cfg, "last_audit": None}
    assert bloat.audit_due(root, never, datetime.date(2026, 1, 5)) == "never audited", "no commits: due"
    return never


def duplicate_ignore_cases(bloat, root, cfg):
    """Duplicates: a file an `audit-duplicate-ignore:` glob matches is not read by the duplicate count, and stays in
    the files the other measures read; `audit-ignore:` is a separate list.

    Args:
        bloat: the module under test.
        root: the sample repo of sample_repo (a Path); its .check is left as it was.
        cfg: its audit settings.
    """
    keep = (root / check_settings.CHECK).read_text()
    (root / check_settings.CHECK).write_text(keep + "audit-duplicate-ignore: docs/*\naudit-duplicate-ignore: x.md\n")
    got = bloat.load_config(root)
    files = bloat.scan_files(root, got)
    assert "docs/NEXT_PROMPT.md" in files and "docs/NEXT_PROMPT.md" not in bloat.dup_files(files, got), "only the count skips it"
    assert bloat.duplicates(root, bloat.dup_files(files, got)) == [] and len(bloat.duplicates(root, files)) == 1, \
        "the duplicate in the ignored file is not counted"
    assert got["ignore"] == [] and bloat.ignored("x.md", got, "duplicate_ignore"), "a list apart from audit-ignore"
    (root / check_settings.CHECK).write_text(keep)


def never_audited_cases(bloat, never):
    """A never-audited repo: not due when new, due by days or commits, and always due as a shallow clone.

    Args:
        bloat: the module under test.
        never: the audit settings of a repo with no last audit.
    """
    with tempfile.TemporaryDirectory() as n:
        subprocess.run(["git", "init", "-q", n], check=True)
        env = {**os.environ, "GIT_AUTHOR_DATE": "2026-01-01T12:00:00Z", "GIT_COMMITTER_DATE": "2026-01-01T12:00:00Z"}
        subprocess.run(["git", "-C", n, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty",
                        "-m", "first"], check=True, env=env)
        first = datetime.date(2026, 1, 1)
        assert bloat.audit_due(Path(n), never, first) == "", "never audited, new repo: not due yet"
        assert bloat.audit_due(Path(n), never, first + datetime.timedelta(days=14)).startswith("never audited;"), "due by days"
        assert bloat.audit_due(Path(n), {**never, "every_commits": 1}, first).startswith("never audited;"), "due by commits"
        subprocess.run(["git", "-C", n, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty",
                        "-m", "second"], check=True, env=env)
        s = str(Path(n).parent / (Path(n).name + "-shallow"))
        subprocess.run(["git", "clone", "-q", "--depth", "1", "file://" + n, s], check=True, capture_output=True)
        try:
            assert bloat.audit_due(Path(s), never, first) == "never audited", "shallow clone: due"
        finally:
            subprocess.run(["rm", "-rf", s], check=True)


def strict_cases(bloat, root, cfg, strict):
    """A fast timed command is ok, and --strict fails when a budget is over."""
    rows, slow = bloat.run_timings(root, cfg, record=False)
    assert not slow and "ok" in rows[0], "fast command is ok"
    with contextlib.redirect_stdout(io.StringIO()):
        assert bloat.report(root, strict, datetime.date(2026, 1, 5)) == 1, "strict fails when over budget"


def report_cases(bloat, root, cfg, strict):
    """The start-read warning, an unknown audit commit, a bad config, and --time --record.

    Args:
        bloat: the module under test.
        root: the sample repo of sample_repo (a Path).
        cfg: its audit settings.
        strict: the options of a --strict run (an argparse.Namespace).
    """
    settings(root, "audit-budget-session_load_warn_tokens: 1\n", audit={"last_audit": {"date": "2026-01-01"}})
    w = io.StringIO()
    with contextlib.redirect_stdout(w):
        bloat.report(root, argparse.Namespace(brief=True, time=False, record=False, strict=False), datetime.date(2026, 1, 5))
    assert "over warning" in w.getvalue() and "over: session load" not in w.getvalue(), "warning, not over"
    with contextlib.redirect_stdout(io.StringIO()):
        assert bloat.audit_due(root, {**cfg, "last_audit": {"date": "2026-01-01", "commit": "f" * 40}},
                            datetime.date(2026, 1, 5)) == "", "unknown commit alone is not due"
        (root / bloat.STATE).write_text("{bad")
        assert bloat.report(root, strict, datetime.date(2026, 1, 5)) == 1, "bad state file: message, no traceback"
        settings(root, "audit-budget-file_kbs: 9\n")
        assert bloat.report(root, strict, datetime.date(2026, 1, 5)) == 1, "unknown audit- key: message, no traceback"
        settings(root)
        (root / check_settings.OLD_AUDIT).write_text("{}")
        assert bloat.main_rules(root) == 1, "the old settings file fails --rules until it is migrated"
        (root / check_settings.OLD_AUDIT).unlink()
        settings(root, audit={"last_audit": {"date": "2026-01-01"}}, timings={"f": {"cmd": "bash scripts/fail.sh"}, "t": {"cmd": "bash scripts/ok.sh"}})
        bloat.report(root, argparse.Namespace(brief=True, time=True, record=True, strict=False))
    saved = check_settings.load_state(root)
    assert "seconds" not in saved["timings"]["f"] and saved["timings"]["t"]["seconds"] is not None, "record skips failed commands"
    assert saved["audit"]["last_audit"]["date"] == "2026-01-01", "--time --record keeps the other parts of the state"


def compare_cases(bloat, root):
    """--compare: within the limit, a slowdown, no baseline, --record, and --time skips a timing with no cmd.

    Args:
        bloat: the module under test.
        root: the sample repo (a Path).
    """
    tc = {"timings": {"check": {"seconds": 4.0, "steps": {"a": 2.0, "tiny": 0.1}}}}
    line, slow = bloat.compare_times(json.loads(json.dumps(tc)), [("check", 4.4), ("check:a", 2.4), ("check:tiny", 0.3)])
    assert not slow and line.startswith("TIME  baseline: 3 of 3"), "within +25%, or under 0.5 s slower: ok"
    line, slow = bloat.compare_times(json.loads(json.dumps(tc)), [("check", 5.2), ("check:a", 2.0), ("check:new", 1.0)])
    assert slow == ["check 5.2 s (baseline 4.0 s, +30%)"] and line.startswith("WARN") and "skills/audit/SKILL.md" in line, "a slowdown warns and names the skill"
    line, _ = bloat.compare_times(json.loads(json.dumps(tc)), [("check:new", 1.0)])
    assert "no baseline yet for 1 (check:new)" in line and "Record a baseline" in line, "no baseline: says how to record one"
    rec = json.loads(json.dumps(tc))
    bloat.compare_times(rec, [("check", 3.0), ("check:new", 1.0), ("other", 0.2)], record=True)
    assert rec["timings"]["check"]["seconds"] == 3.0 and rec["timings"]["check"]["steps"]["new"] == 1.0 and rec["timings"]["other"]["seconds"] == 0.2, "record stores wall, step and a new key"
    settings(root, code_standard={"debt": {}}, **tc)
    with contextlib.redirect_stdout(io.StringIO()):
        assert bloat.main_compare(root, ["check:a=9", "bad"], False) == 0, "a bad item: no failure"
        bloat.main_compare(root, ["check:a=1.25"], True)
    saved = check_settings.load_state(root)
    assert saved["timings"]["check"]["steps"]["a"] == 1.2 and saved["code_standard"] == {"debt": {}}, "--record keeps the other parts"
    assert (root / bloat.STATE).read_text() == check_settings.state_text(saved), "the state file has sorted keys and indent 1"
    rows, _ = bloat.run_timings(root, {"timings": {"nocmd": {"seconds": 1}}}, record=False)
    assert rows == [], "--time skips a timing with no cmd"
    for good in ("python3 scripts/bloat_check.py --brief", "bash scripts/check.sh", "scripts/check.sh", "tests/run.sh",
                 "bash scripts/check_project.sh"):  # the kit's and the fleet's timed commands
        assert bloat.timing_argv(good) == good.split(), f"allowed timed command: {good}"
    for bad in ("echo pwned; true", "rm -rf /", "bash scripts/x.sh && id", "python3 scripts/a.py $(id)", "python3 scripts/a.py\nid",
                "python3 scripts/../../x.py", "bash /tmp/x.sh", "curl scripts/x", "python3 -c scripts/x", ""):
        try:
            bloat.timing_argv(bad)
        except ValueError:
            continue
        raise AssertionError(f"timed command not refused: {bad!r}")


def write_skill(rs, folder, body):
    """Write .claude/skills/<folder>/SKILL.md under rs."""
    (rs / ".claude/skills" / folder).mkdir(parents=True, exist_ok=True)
    (rs / ".claude/skills" / folder / "SKILL.md").write_text(body)


def hard_rule_cases(rs):
    """SINGLE_HOME: each hard rule restated in a skill is a hit; a pointer and a hook description pass.

    Args:
        rs: the sample repo folder.

    Returns:
        None (an assert stops on a failure).
    """
    hits = ["Never force-push or rewrite published history.", "Never rebase a pushed branch.", "Never push with `--no-verify`.",
            "Never push to main directly.", "Never weaken a hook to get past a block.", "Never skip a test.",
            "Never repin an approval.", "A review finding is not approval.", "Review on a model tier no lower than the author's.",
            "Never review with a lower tier."]
    passes = ['Rules: see (AGENTS.md "Hard rules").', "| pre-push | blocks every force-push form and a push to main |",
              "Run git clean up on a scratch folder.", "The Maintainer's approval is in the pull request.",
              "Check that the hook refuses --no-verify."]
    for i, line in enumerate(hits + passes):
        write_skill(rs, f"s{i}", f"---\nname: s{i}\ndescription: Use when testing.\n---\n{line}\n")
    got = {re.search(r"skills/(s\d+)/", p).group(1) for p in skills.second_homes(rs)}
    assert got == {f"s{i}" for i in range(len(hits))}, "each hard rule restated is a hit; pointers and descriptions pass: " + str(sorted(got))


def skills_cases(rs):
    """--skills: a clean pass, each FAIL case, each WARN case, orphans and a folded description.

    Args:
        rs: an empty temporary folder for the sample skills (a Path).
    """
    (rs / "AGENTS.md").write_text("Skills: ok, nodesc, noname, wrongname, nofm, longone, warnone.\n")
    good = "---\nname: {}\ndescription: Use when testing.\n---\nbody\n"
    write_skill(rs, "ok", good.format("ok"))
    with contextlib.redirect_stdout(io.StringIO()) as w:
        assert skills.main_skills(rs) == 0, "clean skill passes"
    assert w.getvalue().strip() == "SKILLS PASS: 1 skills, 0 warnings", "clean pass line"
    write_skill(rs, "nofm", "no frontmatter\n")
    write_skill(rs, "nodesc", "---\nname: nodesc\n---\n")
    write_skill(rs, "noname", "---\ndescription: Use when x.\n---\n")
    write_skill(rs, "wrongname", "---\nname: other\ndescription: Use when x.\n---\n")
    rows, fails, _, _ = skills.skills_report(rs)
    assert fails == 4 and sum(r.startswith("FAIL") for r in rows) == 4, "each FAIL case"
    with contextlib.redirect_stdout(io.StringIO()) as w:
        assert skills.main_skills(rs) == 1, "a malformed skill fails"
    assert w.getvalue().strip().splitlines()[-1].startswith("SKILLS FAIL:"), "fail line"
    for f in ("nofm", "nodesc", "noname", "wrongname"):
        (rs / ".claude/skills" / f / "SKILL.md").unlink()
    write_skill(rs, "warnone", "---\nname: warnone\ndescription: Does things.\n---\n")
    write_skill(rs, "longone", "---\nname: longone\ndescription: Use before " + "x" * 1030 + "\n---\n" + "l\n" * 150)
    write_skill(rs, "orphan", good.format("orphan"))
    rows, fails, warns, n = skills.skills_report(rs)
    txt = "\n".join(rows)
    assert fails == 0 and n == 4 and warns == 4, "four WARN cases, no FAIL"
    assert all(r.startswith("  WARN") for r in rows), "WARN lines are indented"
    assert 'warnone/SKILL.md: description does not start' in txt, "WARN: description start"
    assert "longone/SKILL.md: description is 1041 characters" in txt and "longone/SKILL.md: 154 lines" in txt, "WARN: long description and file"
    assert "orphan/SKILL.md: orphan" in txt, "WARN: orphan"
    (rs / ".claude/skills/warnone/SKILL.md").write_text("---\nname: warnone\ndescription: Does things.\n---\nSee orphan.\n")
    assert "orphan/SKILL.md: orphan" not in "\n".join(skills.skills_report(rs)[0]), "a mention in another SKILL.md is no orphan"
    assert skills.skill_frontmatter("---\nname: f\ndescription: >\n  Use when folded.\n---\n")["description"] == "Use when folded.", "a folded description keeps no > marker"


def run(bloat):
    """Run every case against the module bloat in temporary repos; print BLOAT TEST PASS (an assert stops on a failure).

    Args:
        bloat: the module under test (scripts/bloat_check.py).

    Returns:
        The exit code 0 (an assert stops on a failure).
    """
    # The host's git config (forced signing, -c on the command line) must not change the cases.
    for k in ("GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT"):
        os.environ.pop(k, None)
    os.environ.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    strict = argparse.Namespace(brief=False, time=False, record=False, strict=True)
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        cfg = sample_repo(bloat, root)
        generated_block_cases(bloat, root, cfg)
        never_audited_cases(bloat, metrics_cases(bloat, root, cfg))
        duplicate_ignore_cases(bloat, root, cfg)
        strict_cases(bloat, root, cfg, strict)
        rule_count_cases(bloat)
        with tempfile.TemporaryDirectory() as o:
            caps = {"budgets": {**bloat.DEFAULTS["budgets"], "rules": 2, "project_rules": 1}}
            caps_and_paths_cases(bloat, Path(o), caps)
            conflict_gate_cases(bloat, Path(o), caps)
            lint_cases(bloat, Path(o))
        report_cases(bloat, root, cfg, strict)
        compare_cases(bloat, root)
    with tempfile.TemporaryDirectory() as d:
        skills_cases(Path(d))
    with tempfile.TemporaryDirectory() as d:
        hard_rule_cases(Path(d))
    print("BLOAT TEST PASS")


class BloatCheckTest(unittest.TestCase):
    """The cases of `python3 scripts/bloat_check.py --test`, for `python3 -m unittest` and pytest."""

    def test_self_test(self):
        """Every case passes on the bloat_check module; the git settings that run() changes are put back after it."""
        import bloat_check  # scripts/bloat_check.py: imported here, so a plain import of this file loads nothing
        saved = dict(os.environ)
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(saved)))
        run(bloat_check)
