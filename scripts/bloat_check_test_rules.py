#!/usr/bin/env python3
"""Self-test cases of the rule census of scripts/bloat_check.py: the rule count by place, the caps, the paths
AGENTS.md names, the README check, the third-party budget, the conflict gate and the rule lint; and the two sample
repo helpers that every case group of the bloat self-test uses.

Part of scripts/bloat_check_test.py (split out to keep each file under the line cap of docs/code-standard.md C4);
bloat_check_test.run() calls these cases.
Inputs:  the bloat_check module and temporary folders. Outputs: none; an AssertionError names a failed case.
Usage:   imported by scripts/bloat_check_test.py (run by `python3 scripts/bloat_check.py --test`); no command line.
Network: none.
Writes: temporary repos only.
Credentials: none.
"""
import contextlib
import io
import json
import subprocess

import check_settings


def git_in(folder, *args):
    """Run one git command in folder as a throwaway test user; fail the test on an error."""
    subprocess.run(["git", "-C", folder, "-c", "user.email=t@t", "-c", "user.name=t", *args], check=True,
                   capture_output=True)


def settings(root, lines="", **state):
    """Write the repo's .check (setting lines) and replace its .check.state.json with these parts."""
    (root / check_settings.CHECK).write_text(lines)
    (root / check_settings.STATE).write_text(json.dumps(state))


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
    keyed = rule_lines("## Hard rules\n\n- **Git history.** Never x.\n- **The Maintainer may change anything** here.\n- Plain.\n\n## Project rules\n\n- **Own.** P.\n", with_sections=True)
    assert [k for k, _ in keyed] == ["Git history", "The Maintainer may change anything", "Hard rules", "Own"], "a bold label is the lint key, without its dot; else the heading"
    kit, project, _ = rule_lines("## A\n\n* Star.\n1. Numbered.\n  - Nested.\nA paragraph.\n\n## Project rules\n\n+ Plus.\n  wrapped.\nA rule as a paragraph.\n")
    assert kit == ["Star.", "Numbered.", "Nested. A paragraph."] and project == ["Plus. wrapped.", "A rule as a paragraph."], \
        "every list marker counts; in the kit a line right below an item continues it, in Project rules only an indented one"
    _, project, _ = rule_lines("## Project rules\n\nRule one.\nRule two.\nRule three.\n\n- Bullet.\nAfter a bullet.\n\n#1 priority: never do X.\n")
    assert project == ["Rule one.", "Rule two.", "Rule three.", "Bullet.", "After a bullet.", "#1 priority: never do X."], "Project rules: unindented lines are rules each; '#1' is text, not a heading"
    _, project, _ = rule_lines("## Project rules\n\nRule | Why\n--- | ---\nT one | x\nT two | y\n\n| R | W |\n|---|---|\n| T three | z |\n-\n")
    assert project == ["T one | x", "T two | y", "| T three | z |"], "tables without leading pipes: one rule per row; a lone '-' removes no row"
    kit, project, every = rule_lines("## Order of authority\n\n1. The Maintainer.\n2. This file.\n- A bullet here counts.\n\n## B\n\n"
                                     "- One rule,\n  wrapped.\n~~~\n- in a tilde fence\n~~~\n* * *\n---\n### Sub\n\n"
                                     "## Project rules\n\n### Group\n\n- P one,\n  wrapped.\n\nA paragraph rule\nover two lines.\n\n---\n\n| Rule | Why |\n|---|---|\n| T one | x |\n| T two | y |\n")
    assert kit == ["A bullet here counts.", "One rule, wrapped."], "the ranking is not counted, a bullet in that section is; wraps, fences, rules and sub-headings are not rules"
    assert project == ["P one, wrapped.", "A paragraph rule", "over two lines.", "| T one | x |", "| T two | y |"], \
        "Project rules: wrapped bullet 1, an unindented paragraph line 1 each, table rows without header and separator"
    assert "The Maintainer." in every, "ranking lines are still listed when they change"


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
    assert cfg["budgets"]["session_load_tokens"] == 5500 and cfg["budgets"]["rules_file_lines"] == 50, "a project can lower a kit cap"
    assert bloat.ignored("ref/a/b.md", cfg) and not bloat.ignored("docs/a.md", cfg), "audit-ignore globs are read"
    for bad in ("audit-budget-session_load_tokens: 999999\n", "audit-budget-third_party_tokens: 1501\n", "audit-budget-rule_file_lines: 50\n", "audit-every-days: soon\n"):
        settings(ro, bad)
        with contextlib.redirect_stdout(io.StringIO()) as w:
            assert bloat.main_rules(ro) == 1 and bad.split(":")[0] in w.getvalue(), "a raised kit cap, an unknown key and a bad value fail --rules: " + bad
    (ro / check_settings.CHECK).unlink()
    (ro / check_settings.STATE).unlink()
    skill = ro / ".claude/skills/s"; skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text("---\nname: s\ndescription: " + "d" * 400 + "\n---\nAn agent never merges this.\n")
    assert bloat.start_read(ro, caps)[2] >= 100, "skill names and descriptions count in the session load"
    third_party_cases(bloat, ro, caps)
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
    readme_cases(bloat, ro, caps)


def readme_cases(bloat, ro, caps):
    """The "One home" default (README.md part): a filled Purpose needs README.md (fail) that opens with it (warn); a template skips it.

    Args:
        bloat: the module under test.
        ro: the sample repo of caps_and_paths_cases (a Path), with no README.md.
        caps: audit settings with the default budgets.
    """
    (ro / "AGENTS.md").write_text("# P: agent instructions\n\n- Purpose: {{PURPOSE}}\n\n## A\n\n- Rule.\n")
    assert bloat.rules_report(ro, caps)[1] == [], "a template Purpose skips the README check"
    (ro / "AGENTS.md").write_text("# P: agent instructions\n\n- Purpose: Track the widgets of a unit.\n\n## A\n\n- Rule.\n")
    assert any("no README.md" in p for p in bloat.rules_report(ro, caps)[1]), "a filled Purpose with no README.md fails"
    (ro / "README.md").write_text("# P\n\n![logo](a.png)\n\nSomething else entirely.\n")
    rows, problems = bloat.rules_report(ro, caps)
    assert not problems and any("does not open with" in r for r in rows), "another opening only warns"
    (ro / "README.md").write_text("# P\n\n[![b](x)](y)\n<p>x</p>\n\ntrack the widgets\nof a unit, with tools.\n\nMore.\n")
    rows, problems = bloat.rules_report(ro, caps)
    assert not problems and not any("does not open with" in r for r in rows), "an opening that starts with the purpose passes"
    (ro / "README.md").write_text("\ufeff---\nt: x\n---\nTitle\n=====\n\n> Track the **widgets** of a unit.\n")
    assert not any("does not open with" in r for r in bloat.rules_report(ro, caps)[0]), "BOM, front matter, setext, quote"
    (ro / "AGENTS.md").write_text("# P: agent instructions\n\n- Purpose: Track\n\n## A\n\n- Rule.\n")
    (ro / "README.md").write_text("# P\n\nTracker for nothing.\n")
    assert any("does not open with" in r for r in bloat.rules_report(ro, caps)[0]), "the purpose matches whole words only"
    (ro / "README.md").unlink()
    (ro / "AGENTS.md").write_text("# P: agent instructions\n\n- Purpose:\n- Owner: me\n\n## A\n\n- Rule.\n")
    assert bloat.rules_report(ro, caps)[1] == [], "an empty Purpose does not take the next line"
    (ro / "AGENTS.md").write_text("# P: agent instructions\n\n- Purpose: Track things.\n\n## A\n\n- Rule.\n")
    (ro / "readme.md").write_text("# P\n\nTrack things.\n")
    rows, problems = bloat.rules_report(ro, caps)
    assert not problems and not any("does not open" in r for r in rows), "a lower-case readme.md counts"
    (ro / "readme.md").unlink()


def third_party_cases(bloat, ro, caps):
    """The `audit-third-party` globs: a matched skill folder or agent file leaves the session load and counts
    against its own cap (the Maintainer, 2026-11-20).

    Args:
        bloat: the bloat_check module.
        ro: a temporary repo that holds the skill `s` (a 400-character description).
        caps: the default audit settings.
    """
    import bloat_check_skills
    agents = ro / ".claude/agents"; agents.mkdir(parents=True)
    (agents / "vendor-a.md").write_text("---\nname: vendor-a\ndescription: " + "e" * 200 + "\n---\nBody.\n")
    both = bloat_check_skills.listing_bytes(ro)
    assert bloat_check_skills.listing_bytes(ro, [".claude/*"])[1] == 0, "no lock (or the kit clone): nothing is third-party"
    (ro / ".check.lock").write_text("{bad json")
    assert bloat_check_skills.listing_bytes(ro, [".claude/*"])[1] == 0, "an unreadable lock fails closed"
    (ro / ".check.lock").write_text("{}")
    assert bloat_check_skills.listing_bytes(ro, [".claude/*"])[1] == 0, "a lock with no files list fails closed"
    (ro / ".check.lock").write_text(json.dumps({"files": {}}))
    assert bloat_check_skills.listing_bytes(ro, [".claude/*"])[1] == 0, "a lock with an empty files list fails closed"
    (ro / ".check.lock").write_text(json.dumps({"files": {"scripts/x.py": "x"}}))
    assert both[1] == 0 and both[0] >= 600, "without globs every skill and agent is the project's own"
    split = bloat_check_skills.listing_bytes(ro, [".claude/skills/s", ".claude/agents/vendor-*.md"])
    assert split[0] == 0 and split[1] == both[0], "a matched skill folder and agent file count apart"
    assert bloat_check_skills.listing_bytes(ro, [".claude/skills/s/"])[1] > 0, "a trailing slash matches the folder"
    (ro / ".check.lock").write_text(json.dumps({"files": {".claude/skills/s/SKILL.md": "x"}}))
    assert bloat_check_skills.listing_bytes(ro, [".claude/skills/*"])[1] == 0, "a kit-locked skill is never third-party"
    (ro / ".check.lock").write_text(json.dumps({"files": {"scripts/x.py": "x"}}))
    cfg = {**caps, "third_party": [".claude/skills/s", ".claude/agents/vendor-a.md"]}
    assert bloat.start_read(ro, cfg)[2] < bloat.start_read(ro, caps)[2], "third-party descriptions leave the session load"
    rows, problems = bloat.rules_report(ro, cfg)
    assert "third-party ~" in rows[0] and not any("third-party" in p for p in problems), "under its cap: reported only"
    assert "third-party" not in bloat.rules_report(ro, caps)[0][0], "no globs: no third-party report"
    tight = {**cfg, "budgets": {**caps["budgets"], "third_party_tokens": 10}}
    assert any("third-party skills and agents over their cap" in p for p in bloat.rules_report(ro, tight)[1]), \
        "over its own cap fails"
    (ro / ".check.lock").unlink()
    assert bloat.rules_report(ro, tight)[1] == bloat.rules_report(ro, caps)[1], "with no lock nothing leaves the load"
    (agents / "vendor-a.md").unlink(); agents.rmdir()


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


def sample_kit(d, files):
    """A sample repo in folder d with these files ({path: text}) and kit.config.json, committed and set as origin/main.

    Args:
        d: an empty temporary folder (a Path).
        files: the files to write.

    Returns:
        The folder d.
    """
    subprocess.run(["git", "init", "-q", str(d)], check=True)
    for rel, text in {"kit.config.json": "{}", **files}.items():
        (d / rel).parent.mkdir(parents=True, exist_ok=True)
        (d / rel).write_text(text)
    git_in(d, "add", "-A")
    git_in(d, "commit", "-qm", "base")
    git_in(d, "update-ref", "refs/remotes/origin/main", "HEAD")
    return d


def file_check_cases(bloat, d):
    """The file checks of --rules (scripts/bloat_check_files.py): T1 tool rows, T2 script lines ratchet, T6 role word.

    Args:
        bloat: the module under test.
        d: an empty temporary folder (a Path).
    """
    sk = bloat.bloat_check_files
    table = "| File | Job | Candidates |\n|---|---|---|\n"
    root = sample_kit(d, {"scripts/a.py": "x\n", "scripts/b.sh": "x\n", "tools/c.js": "x\n", "node_modules/v.js": "x\n"})
    assert sk.tool_files(root) == ["scripts/a.py", "scripts/b.sh", "tools/c.js"], "tool files: any folder, not vendor"
    problems = sk.tool_report(root)[1]
    assert len(problems) == 1 and "3 tool file(s)" in problems[0], "the kit: no docs/tools.md fails"
    (root / "docs").mkdir()
    (root / "docs/tools.md").write_text(table + "| scripts/a.py | a | ruff, pylint, radon |\n| `b.sh` | b | none known (searched: shell lint) |\n"
                                        "| tools/c.js | c | one, two |\n")
    problems = sk.tool_report(root)[1]
    assert len(problems) == 1 and "1 tool file(s)" in problems[0] and "tools/c.js" in problems[0], "2 candidates is not 3: %s" % problems
    (root / "docs/tools.md").write_text(table + "| a.py, b.sh, tools/c.js | all | one, two |\n| tools/c.js | c | none known |\n")
    assert "3 tool file(s)" in sk.tool_report(root)[1][0], "a files cell is not a candidates cell; none known needs search terms"
    (root / "docs/tools.md").write_text(table + "| scripts/a.py | a | x, y, z |\n| b.sh | b | none known (terms: q) |\n| tools/c.js | c | x; y; z |\n")
    assert sk.tool_report(root) == ([], []), "3 candidates, or none known with terms: every row counts"
    (root / "docs/tools.md").write_text(table + "| other.py | calls scripts/a.py and b.sh; tools/c.js too | x, y, z |\n"
                                        "| scripts/a.py | a | one, two |\n| b.sh | b | none known |\n| tools/c.js | c | x, y |\n")
    assert "3 tool file(s)" in sk.tool_report(root)[1][0], "a name in a cell that is not the first one does not count (T1)"
    (root / "docs/tools.md").unlink()
    (root / ".check.lock").write_text(json.dumps({"files": {"scripts/a.py": "h"}}))
    warns, problems = sk.tool_report(root)
    assert not problems and len(warns) == 1 and "2 tool file(s)" in warns[0], "a project: WARN, and a kit-locked file is not listed"
    (root / ".check.lock").unlink()
    ratchet_cases(sk, root)
    role_cases(sk, root)


def ratchet_cases(sk, root):
    """T2: script lines over the baseline fail; a baseline above main's needs a DECISIONS row that names it.

    Args:
        sk: the module bloat_check_files.
        root: the sample repo (a Path) with 3 script lines.
    """
    assert sk.script_lines(root) == 2, "the T2 measure"
    rows, problems = sk.ratchet_report(root)
    assert not rows and len(problems) == 1 and "no \"script_lines\" baseline" in problems[0], "the kit with no baseline fails: %s" % problems
    (root / ".check.lock").write_text("{}")
    rows, problems = sk.ratchet_report(root)
    assert not problems and len(rows) == 1 and rows[0].startswith("SKIP") and "plan P5" in rows[0], "a project with no baseline: a SKIP line"
    (root / ".check.lock").unlink()
    (root / check_settings.STATE).write_text(json.dumps({"script_lines": {"baseline": 2}}))
    assert not sk.ratchet_report(root)[1], "at the baseline: passes"
    (root / "scripts/a.py").write_text("x\nx\n")
    problems = sk.ratchet_report(root)[1]
    assert len(problems) == 1 and "pass the baseline 2 (+1)" in problems[0] and "By the Maintainer" in problems[0], problems
    git_in(root, "add", "-A")
    git_in(root, "commit", "-qm", "state")
    git_in(root, "update-ref", "refs/remotes/origin/main", "HEAD")
    (root / check_settings.STATE).write_text(json.dumps({"script_lines": {"baseline": 3}}))
    problems = sk.ratchet_report(root)[1]
    assert len(problems) == 1 and "rose from 2 to 3" in problems[0], "a higher baseline needs a row: %s" % problems
    (root / "docs").mkdir(exist_ok=True)
    good = 'the Maintainer: "Approve 3" (2026-11-23 18:10)'
    cases = [("baseline 3 \\| wc", good, True), ("baseline 3.", good, True),
             ("baseline 31", good, False), ("baseline 3.5", good, False), ("v3", good, False), ("1.3", good, False),
             ("baseline 3", "Agent: the Maintainer 3", False), ("baseline 3", "the Maintainer (2026-11-23)", False),
             ("baseline 3", 'the Maintainer: "3"', False), ("baseline 3", 'the Maintainer\'s agent: "3" 2026-11-23', False),
             ("baseline 3", 'the Maintainer-bot: "3" 2026-11-23', False), ("baseline 3", 'the Maintainer: agent wrote "3" 2026-11-23', False),
             ("baseline 3", 'the Maintainer: "2026-11-23"', False), ("baseline 3", '“Approve 3” 2026-11-23', False),
             ("baseline 3", 'The Maintainer: “Approve 3” 2026-11-23', True)]
    for decision, by, ok in cases:
        (root / "docs/DECISIONS.md").write_text(f"| 2026-11-23 | Script lines {decision} | {by} |\n")
        git_in(root, "add", "-A")
        assert (not sk.ratchet_report(root)[1]) == ok, f"T2 row ({decision} | {by}) should {'pass' if ok else 'fail'}"
    (root / check_settings.STATE).write_text(json.dumps({"script_lines": {"baseline": 4}}))
    problems = sk.ratchet_report(root)[1]
    assert any("below the baseline 4 (-1)" in x and '"baseline": 3' in x for x in problems), "freed lines lower the baseline: %s" % problems


def role_cases(sk, root):
    """T6: kit-synced text with an old role word fails in the kit; a dated attribution and the kept lines do not.

    Args:
        sk: the module bloat_check_files.
        root: the sample kit repo (a Path).
    """
    (root / "scripts/sync_baseline.py").write_text('COPY_FILES = ["docs/x.md"]\nCOPY_IF_MISSING = []\n# Never rename the owner inside this script\n')
    (root / "docs/x.md").write_text("the owner decides\nRule (the owner, 2026-11-23: ok)\nThe Owner's word\nthe Maintainer\n")
    rows, problems = sk.role_report(root)
    assert not rows and len(problems) == 1 and "2 line(s)" in problems[0] and "docs/x.md:1, docs/x.md:3" in problems[0], problems
    (root / "scripts/sync_baseline.py").write_text('COPY_FILES = ["docs/x.md", "docs/FIRST_USE.md"]\nCOPY_IF_MISSING = []\n')
    (root / "docs/x.md").write_text("the Maintainer\n")
    (root / "docs/FIRST_USE.md").write_text('| 7 | A "the owner" \xb7 B a role |\nAsk the owner.\n')
    problems = sk.role_report(root)[1]
    assert len(problems) == 1 and "1 line(s)" in problems[0] and "docs/FIRST_USE.md:2" in problems[0], "a kept line passes, the next line of the file fails: %s" % problems
    (root / "docs/FIRST_USE.md").unlink()
    (root / "scripts/sync_baseline.py").write_text('COPY_FILES = ["docs/x.md"]\nCOPY_IF_MISSING = []\n# Never rename the owner inside this script\n')
    (root / "docs/x.md").write_text("the owner decides\nRule (the owner, 2026-11-23: ok)\nThe Owner's word\nthe Maintainer\n")
    (root / ".check.lock").write_text("{}")
    assert sk.role_report(root) == ([], []), "a project keeps its own role word"
    (root / ".check.lock").unlink()
    (root / "docs/x.md").write_text("the Maintainer\n")
    assert sk.role_report(root) == ([], []), "no role word: no line"
    (root / "docs/x.md").write_text("the Administrator decides\nRule (the Administrator, 2026-11-23: ok)\n")
    problems = sk.role_report(root)[1]
    assert len(problems) == 1 and "1 line(s)" in problems[0] and "docs/x.md:1" in problems[0], "the old role word Administrator fails: %s" % problems


def debt_gate_cases(bloat, d, caps):
    """T5: in the kit, changed rule lines, a new check.sh entry point and a lower KIT_CAPS cap each need a docs/reviews/*-debt.md
    file with "debt-check: <hash>"; the hash is the conflict hash for rule lines alone; a project has no such gate.

    Args:
        bloat: the module under test.
        d: an empty temporary folder (a Path).
        caps: audit settings with the default budgets.
    """
    base = {"AGENTS.md": "## A\n\n- Old rule.\n\n## Project rules\n\n", "scripts/check.sh": "python3 scripts/a.py\n",
            "scripts/check_settings_read.py": 'KIT_CAPS = ("c1",)\nAUDIT_DEFAULTS = {"budgets": {"c1": 5, "c2": 9}}\n'}
    root = sample_kit(d, base)
    debt = lambda: [p for p in bloat.rules_report(root, caps, gate=True)[1] if "T5" in p]
    assert debt() == [] and bloat.bloat_check_files.debt_triggers(root) == [], "nothing changed: no gate"
    (root / "AGENTS.md").write_text("## A\n\n- New rule.\n\n## Project rules\n\n")
    h = bloat.conflict_hash(["New rule."], ["Old rule."])
    assert len(debt()) == 1 and f"debt-check: {h}" in debt()[0], "a changed rule line needs the record, with the conflict hash"
    (root / "docs/reviews").mkdir(parents=True)
    (root / "docs/reviews/r.md").write_text(f"debt-check: {h}\n")
    assert len(debt()) == 1, "a record outside a *-debt.md file does not count"
    (root / "docs/reviews/r-debt.md").write_text(f"debt-check: {h}\n")
    assert debt() == [], "a *-debt.md record with the hash passes"
    (root / "AGENTS.md").write_text(base["AGENTS.md"])
    (root / "scripts/check.sh").write_text("python3 scripts/a.py\nrun x python3 scripts/b.py\nselftest n scripts/c.py -- python3 scripts/c.py --test\n")
    assert bloat.bloat_check_files.debt_triggers(root) == ["check entry point scripts/b.py", "check entry point scripts/c.py"], "new entry points"
    h = bloat.conflict_hash(["check entry point scripts/b.py", "check entry point scripts/c.py"], [])
    assert len(debt()) == 1 and f"debt-check: {h}" in debt()[0], "the hash covers the entry points"
    (root / "scripts/check.sh").write_text(base["scripts/check.sh"])
    (root / "scripts/check_settings_read.py").write_text('KIT_CAPS = ("c1", "c3")\nAUDIT_DEFAULTS = {"budgets": {"c1": 4, "c2": 9, "c3": 1}}\n')
    assert bloat.bloat_check_files.debt_triggers(root) == ["stricter kit cap c1", "stricter kit cap c3"], "a lower cap and a new cap"
    (root / "scripts/check_settings_read.py").write_text('KIT_CAPS = ("c1",)\nAUDIT_DEFAULTS = {"budgets": {"c1": 6, "c2": 1}}\n')
    assert debt() == [], "a higher kit cap, or a lower cap that is not a kit cap, needs no record"
    (root / "AGENTS.md").write_text("## A\n\n- New rule.\n\n## Project rules\n\n")
    (root / "docs/reviews/r-debt.md").unlink()
    (root / "kit.config.json").unlink()
    assert debt() == [], "a project (not the kit): no debt gate"
