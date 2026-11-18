"""The self-test of scripts/check_settings.py (`python3 scripts/check_settings.py --test`), kept apart so that file
stays under the 600-line cap of docs/code-standard.md C4.

What it proves: the readers of `.check` (defaults, each key, the lines that must fail, a git ref) and of
`.check.state.json`; and --migrate: the old files become lines and state, existing lines stay, a key with no place in
the layout is dropped with a NOTE line, a raised kit cap is dropped and a lowered one kept, an old kit header line is
replaced, a clash with a line that is there changes nothing, and a second run changes nothing.
Inputs:  none (each case builds its files in a temporary git repo).
Outputs: SETTINGS TEST PASS, or an AssertionError that names the case.
Run:     python3 scripts/check_settings.py --test
Network: none.
Writes: temporary repos only.
Credentials: none.
"""
import contextlib
import io
import json
import subprocess
import tempfile
from pathlib import Path

from check_settings import (AUDIT_DEFAULTS, CHECK, CODE_DEFAULTS, HEADER, KIT_CAPS, MIGRATE, NAMES_CHECK, OLD_AUDIT,
                            OLD_CHECK, OLD_CODE, OLD_HEADERS, STATE, STATE_PARTS, STRICT, audit_config, audit_from_old,
                            audit_lines, audit_settings, code_base, code_config, code_from_old, code_lines,
                            code_settings, load_state, migrate, pairs, save_part, state_text)


def fails(call, *args):
    """The message of the ValueError that call(*args) raises, or "" when it raises none."""
    try:
        call(*args)
    except ValueError as e:
        return str(e)
    return ""


def test_settings(root, git):
    """Self-test of the readers: defaults, each key, the lines that must fail, a git ref, and the state file.
    Args:
        root: a temporary git repo.
        git: runs one git command in it.
    """
    assert code_config(root) == CODE_DEFAULTS and audit_settings([]) == AUDIT_DEFAULTS, "no .check: the defaults"
    assert code_lines(CODE_DEFAULTS) == audit_lines(AUDIT_DEFAULTS) == [], "the defaults need no line"
    (root / CHECK).write_text("# c\nAllowed Name\nskip: a/*\nprofile: dod\ncode-max-file-lines: 300  # lower\n"
                              "code-exclude: vendor/*\ncode-exclude: a.py\ncode-c1-safety: on\ncode-c2: full\n"
                              "audit-every-days: 7\naudit-ignore: ref/**\naudit-start-read: docs/A.md\n"
                              "audit-budget-file_kb: 100\naudit-budget-rules_file_lines: 150\n")
    cfg = code_config(root)
    assert cfg["caps"] == {"max_file_lines": 300, "max_function_lines": 60} and cfg["exclude"] == ["a.py", "vendor/*"] \
        and cfg["include"] == ["*"] and cfg["c1_safety"] and cfg["c2"] == "full", "the code- lines are read: %s" % cfg
    aud = audit_config(root)
    assert aud["every_days"] == 7 and aud["every_commits"] == 300 and aud["ignore"] == ["ref/**"] \
        and aud["start_read"] == ["docs/A.md"] and aud["budgets"]["file_kb"] == 100 \
        and aud["budgets"]["rules_file_lines"] == 150 and aud["timings"] == {}, "the audit- lines are read: %s" % aud
    for line, why in (("code-max-file-line: 900", "unknown setting"), ("Code-max-file-lines: 900", "unknown setting"),
                      ("code-max-file-lines: many", "whole number"), ("code-max-file-lines: 0", "whole number"),
                      ("code-max-file-lines:", "no value"), ("code-c2: ful", "use full or lean"),
                      ("code-c1-safety: yes", "use on or off"), ("code-c2: full\ncode-c2: lean", "two lines"),
                      ("code-max-function-lines = 500", "looks like a setting"), ("code-exclude scripts/*", "looks like a setting"),
                      ("code_exclude: scripts/*", "looks like a setting"), ("audit_ignore: x", "looks like a setting")):
        (root / CHECK).write_text(line + "\n")
        assert why in fails(code_config, root), "a code- line that is not valid fails: " + line
    for line in ("code-name Bluebird", "audit-trail.example.org", "codeword", "Code-Maximus Ltd", "code-included in price",
                 "audit-everything GmbH", "audit-starter kit", "code-name=Bluebird"):
        (root / CHECK).write_text(line + "\n")
        assert code_config(root) == code_config(root / "none"), "an allowed string is not a setting: " + line
    for line, why in (("audit-every-day: 1", "unknown setting"), ("audit-budget-nope: 1", "unknown setting"),
                      ("audit-every-days: 1.5", "whole number"), ("audit-budget-session_load_tokens: 5001", "never raise")):
        (root / CHECK).write_text(line + "\n")
        assert why in fails(audit_config, root), "an audit- line that is not valid fails: " + line
    assert code_config(root) == CODE_DEFAULTS, "a bad audit- line does not fail the code standard"
    test_gate_keys(root)
    (root / CHECK).write_bytes(b"\xff\xfec\x00o\x00")
    assert "UTF-8" in fails(code_config, root), "a .check that is not UTF-8 fails"
    (root / CHECK).write_text("code-max-function-lines: 40\n")
    save_part(root, "code_standard", {"debt": {"length": {"a.py::f": 70}}})
    git("add", "-A"); git("commit", "-q", "-m", "base")
    (root / CHECK).write_text("code-max-function-lines: 50\n")
    save_part(root, "timings", {"check": {"seconds": 2.0}})
    save_part(root, "audit", {"last_audit": {"date": "2026-01-01"}})
    assert code_config(root, "HEAD")["caps"]["max_function_lines"] == 40 and "timings" not in load_state(root, "HEAD"), \
        "a git ref gives the files of that commit"
    assert code_base(root, "HEAD") == (code_config(root, "HEAD"), {"length": {"a.py::f": 70}}), "the baseline at a ref"
    state = load_state(root)
    assert set(state) == set(STATE_PARTS) and state["code_standard"]["debt"], "a write keeps the other parts"
    before = (root / STATE).read_bytes()
    save_part(root, "timings", {"check": {"seconds": 2.0}})
    assert (root / STATE).read_bytes() == before == state_text(state).encode(), "the same state gives the same bytes"
    for bad in ("{bad", "[]", '{"timings": 1}'):
        (root / STATE).write_text(bad)
        assert fails(load_state, root), "a state file that is not valid fails: " + bad
    assert NAMES_CHECK.search("| x | `.check` |") and NAMES_CHECK.search("see .check.") \
        and not NAMES_CHECK.search(".check.lock and .check.state.json and x.check"), "a row names .check itself"


def test_gate_keys(root):
    """Self-test of the keys a project's own gate enforces: the opt-in line cap and the strict safety level.
    Args:
        root: a temporary git repo; its `.check` is left empty at the end.
    """
    (root / CHECK).write_text("code-max-line-chars: 200\ncode-c1-safety: strict\n")
    cfg = code_config(root)
    assert cfg["caps"] == dict(CODE_DEFAULTS["caps"], max_line_chars=200) and cfg["c1_safety"] == STRICT, "the keys are read: %s" % cfg
    assert code_lines(cfg) == ["code-max-line-chars: 200", "code-c1-safety: strict"], "and written back as the same lines"
    assert "max_line_chars" not in code_settings([])["caps"], "no line: the line cap is off (no key)"
    assert code_settings(pairs(b"code-c1-safety: on\n"))["c1_safety"] is True \
        and code_settings(pairs(b"code-c1-safety: off\n")) == CODE_DEFAULTS, "on is True, off is the default"
    old = code_from_old({"caps": {"max_line_chars": 200}, "c1_safety": True})
    assert old["caps"]["max_line_chars"] == 200 and old["c1_safety"] is True and code_settings(
        [tuple(l.split(": ")) for l in code_lines(old)]) == old, "an old file with the line cap gives the same settings"
    assert [code_from_old({"c1_safety": v})["c1_safety"] for v in (2, 3, "strict", True, 1, False, 0, None)] == \
        [STRICT, STRICT, STRICT, True, True, False, False, False], "an old level of 2 or more is the strict form"
    for line, why in (("code-max-line-chars: 0", "whole number"), ("code_max_line_chars: 9", "looks like a setting"),
                      ("code-c1-safety: 2", "use on or off or strict"), ("code-c1-safety: Strict", "use on or off or strict"),
                      ("code-max-line-char: 9", "unknown setting"), ("code-max-line-chars: 9\ncode-max-line-chars: 8", "two lines")):
        (root / CHECK).write_text(line + "\n")
        assert why in fails(code_config, root), "a line that is not valid fails: " + line
    (root / CHECK).write_text("")


def migrated(root):
    """Run --migrate in the sample repo with its output caught.
    Args:
        root: the sample repo.
    Returns:
        (exit code, what it printed).
    """
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = migrate(root)
    return code, out.getvalue()


def files_of(root):
    """The name and bytes of each file at the top of the sample repo (to prove that a run changed nothing)."""
    return {p.name: p.read_bytes() for p in root.iterdir() if p.is_file()}


def test_migrate_dropped(root, git):
    """Self-test of --migrate on old keys with no place in the layout (the three cases the first ports hit): the key
    is not moved, one NOTE line names it, the last line lists it, and the rest is moved.
    Args:
        root: a temporary git repo.
        git: runs one git command in it (not used: nothing is committed).
    """
    cases = (
        ({"budgets": {"start_read_tokens": 12000, "start_read_warn_tokens": 6000}, "every_commits": 200},
         ["budgets.start_read_tokens=12000", "budgets.start_read_warn_tokens=6000"], ["audit-every-commits: 200"]),
        ({"budgets": {"rules": 30, "project_rules": 10, "rule_tokens": 4400}},
         ["budgets.rule_tokens=4400"], ["audit-budget-rules: 30", "audit-budget-project_rules: 10"]),
        ({"duplicate_ignore": ["data/*"], "start_read": ["P.md"]}, ['duplicate_ignore=["data/*"]'], ["audit-start-read: P.md"]),
        ({"budgets": {"session_load_tokens": 7000, "rules_file_lines": 150}},
         ["budgets.session_load_tokens=7000"], ["audit-budget-rules_file_lines: 150"]),
    )
    for old, dropped, lines in cases:
        (root / OLD_AUDIT).write_text(json.dumps(old))
        code, said = migrated(root)
        assert code == 0 and not (root / OLD_AUDIT).exists(), "the migration goes on: %s" % said
        for d in dropped:
            assert f"NOTE  dropped {OLD_AUDIT} {d}: " in said, "one NOTE line for %s: %s" % (d, said)
        assert said.count("NOTE  dropped") == len(dropped) and f"Dropped, not moved ({len(dropped)}): " in said.splitlines()[-1], said
        assert (root / CHECK).read_text().splitlines()[1:] == lines, "the keys that have a place are moved: " + (root / CHECK).read_text()
        assert all(v <= AUDIT_DEFAULTS["budgets"][k] for k, v in audit_config(root)["budgets"].items() if k in KIT_CAPS), "kit caps hold"
        before = files_of(root)
        assert migrated(root) == (0, "nothing to migrate: no old settings file here\n") and files_of(root) == before, "a second run changes nothing"
        (root / CHECK).unlink()
        (root / STATE).unlink()
    (root / OLD_CODE).write_text(json.dumps({"config": {"caps": {"max_words": 9, "max_line_chars": 200}, "style": "x"}, "debt": {}, "v": 2}))
    code, said = migrated(root)
    assert code == 0 and (root / CHECK).read_text().splitlines()[1:] == ["code-max-line-chars: 200"], said
    assert all(f"NOTE  dropped {OLD_CODE} {d}: " in said for d in ("config.caps.max_words=9", 'config.style="x"', "v=2")), said
    # A setting that has a place still stops the run when the result would change its meaning: all or nothing.
    (root / OLD_AUDIT).write_text(json.dumps({"budgets": {"rule_tokens": 1, "file_kb": 100}}))
    (root / CHECK).write_text("audit-budget-file_kb: 50\n")
    before = files_of(root)
    code, said = migrated(root)
    assert code == 1 and "SETTINGS MIGRATE FAIL" in said and files_of(root) == before, "a clash changes nothing: " + said


def test_migrate_header(root, git):
    """Self-test of --migrate on the first comment line of `.check`: an old kit header line becomes the current one;
    no other line changes; any other first line stays.
    Args:
        root: a temporary git repo.
        git: runs one git command in it (not used: nothing is committed).
    """
    body = "# Below: allowed strings.\n" + OLD_HEADERS[0] + "\nprofile: dod\nskip: a/*\n"
    for old in OLD_HEADERS:
        (root / OLD_CHECK).write_text(old + "\n" + body)
        (root / OLD_AUDIT).write_text(json.dumps({"every_days": 7}))
        code, said = migrated(root)
        assert code == 0 and "old kit header" in said, said
        assert (root / CHECK).read_text() == HEADER + "\n" + body + \
            "# Code standard and audit settings (the keys: the header of scripts/check_settings.py).\naudit-every-days: 7\n", \
            "only the first line is replaced (the same text on a later line stays): " + (root / CHECK).read_text()
        before = files_of(root)
        assert migrated(root)[0] == 0 and files_of(root) == before, "a second run changes nothing"
        (root / CHECK).unlink()
        (root / STATE).unlink()
    (root / CHECK).write_bytes(OLD_HEADERS[0].encode() + b"\r\nprofile: dod\r\n")   # a project that migrated before this fix
    code, said = migrated(root)
    assert code == 0 and (root / CHECK).read_bytes() == HEADER.encode() + b"\r\nprofile: dod\r\n", "the header alone is fixed: " + said
    for first in ("# My own first line names scripts/pii_guard.py.", OLD_HEADERS[0] + " Edited.", "profile: dod"):
        (root / CHECK).write_text(first + "\n" + OLD_HEADERS[0] + "\n")
        before = files_of(root)
        assert migrated(root) == (0, "nothing to migrate: no old settings file here\n") and files_of(root) == before, \
            "another first line is not touched: " + first
    kit_check = Path(__file__).resolve().parent.parent / CHECK
    if (kit_check.parent / "KIT_VERSION").is_file() and kit_check.is_file():   # in the kit clone: HEADER is its first line
        assert kit_check.read_text().splitlines()[0] == HEADER, "HEADER equals the first line of the kit's .check"


def test_migrate(root, git):
    """Self-test of --migrate: the old files become lines and state, existing lines stay, a second run changes
    nothing, the old base is still read, and a clash changes nothing.
    Args:
        root: a temporary git repo.
        git: runs one git command in it.
    """
    old_code = {"config": {"caps": {"max_file_lines": 600, "max_function_lines": 80}, "include": ["*"],
                           "exclude": ["gen/*"], "generated": [], "c2": "full"}, "debt": {"length": {"a.py::f": 90}}}
    old_audit = {"every_days": 7, "budgets": {"file_kb": 100, "session_load_tokens": 99999}, "ignore": ["ref/**"],
                 "last_audit": {"date": "2026-01-01"}, "timings": {"check": {"seconds": 4.2}}, "odd": 1}
    (root / OLD_CHECK).write_bytes(b"# old\nprofile: dod\nskip: data/*")
    (root / OLD_CODE).write_text(json.dumps(old_code))
    (root / OLD_AUDIT).write_text(json.dumps(old_audit))
    assert MIGRATE in fails(code_config, root) and MIGRATE in fails(audit_config, root), "an old file fails the readers"
    git("add", "-A"); git("commit", "-q", "-m", "old layout")
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        assert migrate(root) == 0, "the migration runs"
    text = (root / CHECK).read_text()
    assert text.startswith("# old\nprofile: dod\nskip: data/*\n# Code standard"), "the old lines stay first: " + text
    assert text.splitlines()[4:] == ["code-max-function-lines: 80", "code-exclude: gen/*", "code-c2: full",
                                     "audit-every-days: 7", "audit-budget-file_kb: 100", "audit-ignore: ref/**"], text
    assert load_state(root) == {"code_standard": {"debt": old_code["debt"]}, "audit": {"last_audit": old_audit["last_audit"]},
                                "timings": old_audit["timings"]}, "the state is moved"
    assert not any((root / n).exists() for n in (OLD_CHECK, OLD_CODE, OLD_AUDIT)), "the old files are deleted"
    said = out.getvalue()
    assert f"NOTE  dropped {OLD_AUDIT} odd=1: " in said and "SETTINGS MIGRATED" in said, said
    assert f"NOTE  dropped {OLD_AUDIT} budgets.session_load_tokens=99999: a kit cap cannot be raised" in said, said
    assert said.rstrip().splitlines()[-1].endswith(f"Dropped, not moved (2): {OLD_AUDIT} budgets.session_load_tokens, "
                                                   f"{OLD_AUDIT} odd"), "the last line lists the dropped keys: " + said
    assert code_config(root) == code_from_old(old_code["config"]) == code_base(root, "HEAD")[0], \
        "the new settings equal the old ones, and the old file at the base is still read"
    assert audit_config(root)["budgets"]["session_load_tokens"] == 5000, "a raised kit cap is not moved"
    before = {p.name: p.read_bytes() for p in root.iterdir() if p.is_file()}
    with contextlib.redirect_stdout(out):
        assert migrate(root) == 0, "a second run passes"
    assert before == {p.name: p.read_bytes() for p in root.iterdir() if p.is_file()}, "a second run changes nothing"
    (root / OLD_CODE).write_text(json.dumps({"config": {"caps": {"max_function_lines": 90}}, "debt": {}}))
    with contextlib.redirect_stdout(out):
        assert migrate(root) == 1 and (root / OLD_CODE).exists(), "a clash with a line that is there changes nothing"
    assert before == {p.name: p.read_bytes() for p in root.iterdir() if p.is_file() and p.name != OLD_CODE}, "no write"
    for name in (CHECK, STATE, OLD_CODE):
        (root / name).unlink()
    (root / OLD_CODE).write_text(json.dumps({"config": CODE_DEFAULTS, "debt": {}}))
    with contextlib.redirect_stdout(out):
        assert migrate(root) == 0 and not (root / CHECK).exists(), "defaults only: no .check is made"
    assert (root / STATE).read_text() == '{\n "code_standard": {\n  "debt": {}\n }\n}\n', "the state of a clean repo"


def run():
    """Run the cases, each in its own temporary repo; print SETTINGS TEST PASS (an assert stops on a failure).
    Returns:
        The exit code 0.
    """
    for case in (test_settings, test_migrate, test_migrate_dropped, test_migrate_header):
        with tempfile.TemporaryDirectory() as d:
            def git(*args):
                """Run one git command in the test repo as a throwaway user; fail the test on an error."""
                subprocess.run(["git", "-C", d, "-c", "user.email=t@example.invalid", "-c", "user.name=t",
                                "-c", "commit.gpgsign=false", *args], check=True, capture_output=True)
            git("init", "-q")
            case(Path(d), git)
    print("SETTINGS TEST PASS")
    return 0
