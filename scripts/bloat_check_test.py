#!/usr/bin/env python3
"""Self-test of scripts/bloat_check.py (run by `python3 scripts/bloat_check.py --test`; kept in its own file so the
check stays under the 600-line cap of docs/code-standard.md C4).

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
from pathlib import Path

import bloat_check_skills as skills
import check_settings

LONG = "This line is long enough to count as a duplicate when it shows up in two different files of a repo."


def git_in(folder, *args):
    """Run one git command in folder as a throwaway test user; fail the test on an error."""
    subprocess.run(["git", "-C", folder, "-c", "user.email=t@t", "-c", "user.name=t", *args], check=True,
                   capture_output=True)


def settings(root, lines="", **state):
    """Write the repo's .check (setting lines) and replace its .check.state.json with these parts."""
    (root / check_settings.CHECK).write_text(lines)
    (root / check_settings.STATE).write_text(json.dumps(state))


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
    settings(root, "audit-budget-file_kb: 2\naudit-budget-session_load_tokens: 10\n",
             audit={"last_audit": {"date": "2026-01-01"}}, timings={"t": {"cmd": "true", "seconds": 5}})
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


def rule_count_cases(bloat):
    """Rules: count by place; header, Commands, fences, comments, starter blocks, rankings and tables.

    Args:
        bloat: the module under test.
    """
    rule_lines = bloat.rule_lines
    sample = ("# T\n\n- Repo: x\n\n## Git safety\n\n- Rule one.\n- Rule two.\n<!-- starter -->\n- Starter only.\n"
              "<!-- /starter -->\n```\n- in a fence\n```\n\n## Commands\n\n- Build: none.\n\n## Project rules\n\n"
              "<!-- - a comment -->\n- Project rule.\n")
    kit, project, every = rule_lines(sample)
    assert kit == ["Rule one.", "Rule two."] and project == ["Project rule."], "header, Commands, fences, comments and starter blocks are not rules"
    assert "Build: none." in every, "the list of changed lines also covers sections that are not counted"
    assert rule_lines("## A\n\n- Rule start\n  continues with a | b here.\n")[0] == ["Rule start continues with a | b here."], "a continuation with a pipe stays in its rule (a change to it shows)"
    keyed = rule_lines("## Hard rules\n\n- **Git history.** Never x.\n- **The PFM may change anything** here.\n- Plain.\n\n## Project rules\n\n- **Own.** P.\n", with_sections=True)
    assert [k for k, _ in keyed] == ["Git history", "The PFM may change anything", "Hard rules", "Own"], "a bold label is the lint key, without its dot; else the heading"
    kit, project, _ = rule_lines("## A\n\n* Star.\n1. Numbered.\n  - Nested.\nA paragraph.\n\n## Project rules\n\n+ Plus.\n  wrapped.\nA rule as a paragraph.\n")
    assert kit == ["Star.", "Numbered.", "Nested. A paragraph."] and project == ["Plus. wrapped.", "A rule as a paragraph."], \
        "every list marker counts; in the kit a line right below an item continues it, in Project rules only an indented one"
    _, project, _ = rule_lines("## Project rules\n\nRule one.\nRule two.\nRule three.\n\n- Bullet.\nAfter a bullet.\n\n#1 priority: never do X.\n")
    assert project == ["Rule one.", "Rule two.", "Rule three.", "Bullet.", "After a bullet.", "#1 priority: never do X."], "Project rules: unindented lines are rules each; '#1' is text, not a heading"
    _, project, _ = rule_lines("## Project rules\n\nRule | Why\n--- | ---\nT one | x\nT two | y\n\n| R | W |\n|---|---|\n| T three | z |\n-\n")
    assert project == ["T one | x", "T two | y", "| T three | z |"], "tables without leading pipes: one rule per row; a lone '-' removes no row"
    kit, project, every = rule_lines("## Order of authority\n\n1. The PFM.\n2. This file.\n- A bullet here counts.\n\n## B\n\n"
                                     "- One rule,\n  wrapped.\n~~~\n- in a tilde fence\n~~~\n* * *\n---\n### Sub\n\n"
                                     "## Project rules\n\n### Group\n\n- P one,\n  wrapped.\n\nA paragraph rule\nover two lines.\n\n---\n\n| Rule | Why |\n|---|---|\n| T one | x |\n| T two | y |\n")
    assert kit == ["A bullet here counts.", "One rule, wrapped."], "the ranking is not counted, a bullet in that section is; wraps, fences, rules and sub-headings are not rules"
    assert project == ["P one, wrapped.", "A paragraph rule", "over two lines.", "| T one | x |", "| T two | y |"], \
        "Project rules: wrapped bullet 1, an unindented paragraph line 1 each, table rows without header and separator"
    assert "The PFM." in every, "ranking lines are still listed when they change"


def caps_and_paths_cases(bloat, ro, caps):
    """A repo with origin/main: a swap of rule lines is listed, both caps fail, missing paths fail.

    Args:
        bloat: the module under test.
        ro: an empty temporary folder for the sample repo (a Path).
        caps: audit settings with the default budgets.
    """
    o = str(ro)
    git_in(o, "init", "-q", "-b", "main")
    (ro / "AGENTS.md").write_text("## A\n\n- Old rule.\n- Kept rule.\n\n## Project rules\n\n")
    git_in(o, "add", "-A"); git_in(o, "commit", "-q", "-m", "a"); git_in(o, "update-ref", "refs/remotes/origin/main", "HEAD")
    (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n\n## Project rules\n\n- P1.\n")
    rows, problems = bloat.rules_report(ro, caps)
    assert not problems, "at the cap is not over"
    assert any(r.startswith("  + New rule.") for r in rows) and any(r.startswith("  - Old rule.") for r in rows), "a swap is listed"
    (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n- Third.\n\n## Project rules\n\n- P1.\n- P2.\n")
    rows, problems = bloat.rules_report(ro, caps)
    assert not problems and sum(r.startswith("WARN  ") and "rule bullets (guide" in r for r in rows) == 2, "the bullet counts only warn"
    tight = {"budgets": {**caps["budgets"], "rules_file_lines": 3, "session_load_tokens": 5}}
    rows, problems = bloat.rules_report(ro, tight)
    assert len(problems) == 2 and "over the line cap (10 > 3)" in problems[0] and "session load over the cap" in problems[1], "the line cap and the load cap fail"
    warned = {"budgets": {**caps["budgets"], "session_load_warn_tokens": 5}}
    assert any("over the warning" in r for r in bloat.rules_report(ro, warned)[0]) and not bloat.rules_report(ro, warned)[1], "the load warning only warns"
    settings(ro, "audit-budget-rules_file_lines: 50\naudit-ignore: ref/**\n")
    cfg = bloat.load_config(ro)
    assert cfg["budgets"]["session_load_tokens"] == 5000 and cfg["budgets"]["rules_file_lines"] == 50, "a project can lower a kit cap"
    assert bloat.ignored("ref/a/b.md", cfg) and not bloat.ignored("docs/a.md", cfg), "audit-ignore globs are read"
    for bad in ("audit-budget-session_load_tokens: 999999\n", "audit-budget-rule_file_lines: 50\n", "audit-every-days: soon\n"):
        settings(ro, bad)
        with contextlib.redirect_stdout(io.StringIO()) as w:
            assert bloat.main_rules(ro) == 1 and bad.split(":")[0] in w.getvalue(), "a raised kit cap, an unknown key and a bad value fail --rules: " + bad
    (ro / check_settings.CHECK).unlink()
    (ro / check_settings.STATE).unlink()
    skill = ro / ".claude/skills/s"; skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text("---\nname: s\ndescription: " + "d" * 400 + "\n---\nAn agent never merges this.\n")
    assert bloat.start_read(ro, caps)[2] >= 100, "skill names and descriptions count in the session load"
    import bloat_check_skills
    table = [("agents merge", r"never merges", ["AGENTS.md"])]
    assert bloat_check_skills.second_homes(ro, table) == [
        'second home of a rule: .claude/skills/s/SKILL.md:5 states "agents merge"; its home is AGENTS.md: link to it'], \
        "a rule stated again in a skill is a problem"
    assert bloat_check_skills.second_homes(ro, [("x", r"never merges", [".claude/skills/s/SKILL.md"])]) == [], "the home file may state it"
    subprocess.run(["rm", "-rf", str(ro / ".claude")], check=True)
    (ro / "AGENTS.md").write_text(
        "## A\n\n- See `.claude/skills/x/SKILL.md` and [doc](docs/gone.md), [web](https://e.example/a), `.claude/skills/<name>/`, "
        "`scripts/gone.sh --fast`, `scripts/check.local.sh`, `python3 scripts/gone2.py --test`, `scripts/tool.sh -o docs/out.html`, "
        "`scripts/gone2.py:12`, `scripts/gone.sh|tee x`, `bash -x scripts/gone3.sh`, "
        "`x --output docs/a.md --out docs/b.md --outline docs/c.md`.\n")
    rows, problems = bloat.rules_report(ro, caps)
    assert problems == ["missing paths named in AGENTS.md: .claude/skills/x/SKILL.md, docs/gone.md, scripts/gone.sh, "
                        "scripts/gone2.py, scripts/gone3.sh, scripts/tool.sh"], \
        "missing paths (also after a command word, with a line number or a pipe), not URLs, patterns, optional files or option values"
    (ro / ".claude/skills/x").mkdir(parents=True); (ro / ".claude/skills/x/SKILL.md").write_text("x")
    (ro / "docs").mkdir(); (ro / "docs/gone.md").write_text("x")
    (ro / "scripts").mkdir(); (ro / "scripts/gone.sh").write_text("x"); (ro / "scripts/gone2.py").write_text("x"); (ro / "scripts/tool.sh").write_text("x"); (ro / "scripts/gone3.sh").write_text("x")
    assert bloat.rules_report(ro, caps)[1] == [], "paths exist: pass"


def conflict_gate_cases(bloat, ro, caps):
    """Conflict gate: changed rule lines need a record that names their hash; without --gate only a WARN line.

    Args:
        bloat: the module under test.
        ro: the sample repo of caps_and_paths_cases (a Path).
        caps: audit settings with the default budgets.
    """
    (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n\n## Project rules\n\n")
    h = bloat.conflict_hash(["New rule."], ["Old rule."])
    assert h == bloat.conflict_hash(["New rule."], ["Old rule."]) != bloat.conflict_hash(["Old rule."], ["New rule."]), "the hash keeps + and - apart"
    rows, problems = bloat.rules_report(ro, caps)
    assert not problems and any(r.startswith("WARN") and h in r for r in rows), "no record, no gate: a WARN line with the hash"
    rows, problems = bloat.rules_report(ro, caps, gate=True)
    assert len(problems) == 1 and h in problems[0], "no record, gate: fails"
    (ro / "docs").mkdir(exist_ok=True); (ro / "docs/reviews").mkdir()
    (ro / "docs/reviews/r.md").write_text(f"Result: no conflict.\nrule-conflict-check: {'0' * 12}\n")
    assert bloat.rules_report(ro, caps, gate=True)[1], "a record for other lines does not count"
    (ro / "docs/reviews/r.md").write_text(f"Result: no conflict.\nrule-conflict-check: {h}\n")
    rows, problems = bloat.rules_report(ro, caps, gate=True)
    assert not problems and any("conflict check: recorded" in r for r in rows), "a record with the hash passes"
    (ro / "AGENTS.md").write_text("## A\n\n- Old rule.\n- Kept rule.\n\n## Project rules\n\n")
    assert not bloat.rules_report(ro, caps, gate=True)[1], "no changed lines: no gate"


def lint_cases(bloat, ro):
    """Lint: near-duplicates, vague words, untested rules (a section with no scenario, no script named).

    Args:
        bloat: the module under test.
        ro: the sample repo (a Path).
    """
    (ro / ".claude").mkdir(exist_ok=True)
    (ro / ".claude/rule-tests.md").write_text("| # | Rule tested | Section | Prompt |\n|---|---|---|---|\n| 1 | x | Tested; Other | p |\n")
    rules = [("Tested", "Never push to main without the full check lane passing first."),
             ("Tested", "Never push to main without the full check lane passing."),
             ("Tested", "Use the right tool where possible."),
             ("Untested", "Keep the handoff short."), ("Untested", "The hook enforces it: `scripts/x.sh`."),
             ("Other", "Run `git clean` never.")]
    flags = bloat.lint(ro, rules)
    assert sum("near-duplicate" in f for f in flags) == 1, "one near-duplicate pair"
    assert [f for f in flags if "vague" in f] == ['WARN  rule lint: vague (where possible): "Use the right tool where possible."'], "vague word; text in backticks is not read"
    assert [f for f in flags if "untested" in f] == [
        'WARN  rule lint: untested (no scenario for "Untested" in .claude/rule-tests.md, no script named): "Keep the handoff short."'], \
        "untested: no scenario and no script; a ';' list of sections counts each"
    assert bloat.lint(ro, rules, only={"Keep the handoff short."}) == [f for f in flags if "handoff" in f], "only: the changed lines"
    (ro / ".claude/rule-tests.md").unlink()
    assert not [f for f in bloat.lint(ro, rules) if "untested" in f], "no rule-tests file (starter tier): no untested flags"
    (ro / "AGENTS.md").write_text("## A\n\n- New rule.\n- Kept rule.\n\n## Project rules\n\n- See `.claude/skills/x/SKILL.md` and "
                                  "[doc](docs/gone.md), `scripts/gone.sh`, `scripts/gone2.py`, `scripts/tool.sh`.\n")
    with contextlib.redirect_stdout(io.StringIO()):
        assert bloat.main_rules(ro) == 0, "--rules passes"
        assert bloat.main_lint(ro) == 0, "--lint never fails"
        (ro / "AGENTS.md").write_text("## A\n\n" + "- r.\n" * 29)
        assert bloat.main_rules(ro) == 0, "--rules passes over the bullet guide of 28 (a warning)"
        (ro / "AGENTS.md").write_text("## A\n\n" + "- r.\n" * 199)
        assert bloat.main_rules(ro) == 1, "--rules fails over the default cap of 200 lines"


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
        settings(root, audit={"last_audit": {"date": "2026-01-01"}}, timings={"f": {"cmd": "false"}, "t": {"cmd": "true"}})
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
    assert slow == ["check 5.2 s (baseline 4.0 s, +30%)"] and line.startswith("WARN") and "efficiency" in line, "a slowdown warns and names the skill"
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


def write_skill(rs, folder, body):
    """Write .claude/skills/<folder>/SKILL.md under rs."""
    (rs / ".claude/skills" / folder).mkdir(parents=True, exist_ok=True)
    (rs / ".claude/skills" / folder / "SKILL.md").write_text(body)


def hard_rule_cases(rs):
    """SINGLE_HOME: each hard rule restated in a skill is a hit; a pointer and a hook description pass."""
    hits = ["Never force-push or rewrite published history.", "Never rebase a pushed branch.", "Never push with `--no-verify`.",
            "Never push to main directly.", "Never weaken a hook to get past a block.", "Never skip a test.",
            "Never repin an approval.", "A review finding is not approval.", "Review on a model tier no lower than the author's.",
            "Never review with a lower tier."]
    passes = ['Rules: see (AGENTS.md "Hard rules").', "| pre-push | blocks every force-push form and a push to main |",
              "Run git clean up on a scratch folder.", "The PFM's approval is in the pull request.",
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
