"""More cases of the self-test of scripts/check_content.py (check_content_test.py runs them; kept apart for the
line cap of docs/code-standard.md C4): the terms list, the `block:` lines, the settings file under its name
`.check`, its `code-` and `audit-` setting lines, the hook for the Write, Edit, NotebookEdit and Bash tools, and
the speed parts (the gates of check_content_finders.py and the process pool of scan_files): the same findings with
and without them.

Input: none (temporary folders; samples are built at run time, so this file does not flag itself).
Output: one "ok" or "FAIL" line per case through the check() function that run() gets. Needs git.
Network: none.
Writes: temporary folders only.
Credentials: none (the samples are built at run time and are not real).
"""
import contextlib
import io
import json
import os
import pathlib
import random
import re
import subprocess
import sys
import tempfile

import check_content_finders
import check_content_hook
import check_content_scan
from check_content_scan import (blocked, config_name, is_option_line, is_tier_line, load_allow, load_terms, profile_of,
                                scan_files, scan_text)

at, dot = "@", "."
ME = [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "check_content.py")]


def kinds(text, deny=(), allow=(), terms=()):
    """The sorted finding kinds of one text."""
    return sorted({k for _, _, k, _ in scan_text(text, "t", list(deny), set(allow), False, list(terms))})


def case_terms(check):
    """The Maintainer's terms: whole word, any case, masked, kind term; a name stays a name; an allowed string wins.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    check("term: found as a whole word, any case", kinds("the BLUEBIRD plan", terms=["bluebird"]) == ["term"])
    check("term: not inside another word", kinds("bluebirds fly", terms=["bluebird"]) == [])
    check("term and name in one line keep their kinds", kinds("Alex and Bluebird", ["Alex"], terms=["Bluebird"]) == ["name", "term"])
    check("a word in both lists is a name", kinds("Alex", ["Alex"], terms=["alex"]) == ["name"])
    check("term: inside an allowed string passes", kinds("Bluebird Cafe", allow={"Bluebird Cafe"}, terms=["Bluebird"]) == [])
    found = scan_text("the Bluebird plan", "t", [], set(), False, ["Bluebird"])
    check("term: the finding is masked", found and "Bluebird" not in found[0][3])
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d, "terms.txt")
        f.write_text("# clients\nBluebird\n")
        old = {k: os.environ.get(k) for k in ("CHECK_TERMS", "CHECK_TERMS_FILE")}
        os.environ["CHECK_TERMS_FILE"] = str(f)
        try:
            check("terms: read from the file", load_terms() == ["Bluebird"])
            os.environ["CHECK_TERMS"] = "Osprey, Kestrel"
            check("terms: the environment variable comes first", load_terms() == ["Osprey", "Kestrel"])
            env = {k: v for k, v in os.environ.items() if not k.startswith(("PII_GUARD", "GIT_"))}
            env["PII_GUARD_DENYLIST_FILE"] = str(f) + ".missing"
            r = subprocess.run(ME + ["--stdin"], input="the osprey plan", env=env, capture_output=True, text=True, cwd=d)
            check("terms: the CLI blocks a term and hides it", r.returncode == 1 and "term" in r.stdout
                  and "2 terms checked" in r.stdout and "osprey" not in r.stdout.lower().replace("the osprey plan", ""))
            env["PII_GUARD_DENYLIST"] = "Alex"
            r = subprocess.run(ME + ["--status"], env=env, capture_output=True, text=True, cwd=d)
            check("terms: --status prints the count, never the words", "terms: 2 entries" in r.stdout and "Osprey" not in r.stdout)
        finally:
            for k, v in old.items():
                os.environ.pop(k, None) if v is None else os.environ.__setitem__(k, v)


def case_block_lines(check):
    """`block:` lines: a glob, a file-name glob in any folder, a folder; bare stars are ignored; block wins over skip.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    allow = {"block: *.xlsx", "block: exports/", "block: data/raw-*.csv", "block: *", "skip: exports/"}
    for path, want in (("a.xlsx", True), ("deep/dir/b.xlsx", True), ("exports/x.txt", True), ("data/raw-1.csv", True),
                       ("data/clean.csv", False), ("notes.md", False), ("xlsx", False), ("Deep/B.XLSX", True),
                       ("EXPORTS/x.txt", True)):
        check(f"block: {path}: {'blocked' if want else 'passes'}", blocked(path, allow) is want)
    with tempfile.TemporaryDirectory() as d:
        pathlib.Path(d, "exports").mkdir()
        pathlib.Path(d, "exports", "x.txt").write_text("clean\n")
        pathlib.Path(d, "ok.txt").write_text("clean\n")
        got = [(p, k) for p, _, k, _ in scan_files(["exports/x.txt", "ok.txt"], d, [], allow)]
        check("block: a blocked file is a finding although a skip line names it", got == [("exports/x.txt", "blocked")])


def git(d, *args):
    """Run git in d with a fixed noreply identity and no host settings."""
    env = {**os.environ, "GIT_AUTHOR_NAME": "Sam", "GIT_COMMITTER_NAME": "Sam",
           "GIT_AUTHOR_EMAIL": "sam" + at + "users.noreply.github.com",
           "GIT_COMMITTER_EMAIL": "sam" + at + "users.noreply.github.com"}
    return subprocess.run(["git", "-c", "commit.gpgsign=false", *args], cwd=d, env=env, capture_output=True, text=True, check=True)


def case_check_file(check):
    """The settings file is `.check`; `.pii-guard` is read only when `.check` is absent; a commit of a blocked file fails.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    with tempfile.TemporaryDirectory() as d:
        env = {k: v for k, v in os.environ.items() if not k.startswith(("PII_GUARD", "GIT_"))}
        env["PII_GUARD_DENYLIST"] = "Alex"
        git(d, "init", "-q", "-b", "main")
        check("no settings file: none", config_name(d) is None and load_allow(d) == set())
        pathlib.Path(d, ".pii-guard").write_text("old-allowed\n")
        check("only .pii-guard: it is read", config_name(d) == ".pii-guard" and load_allow(d) == {"old-allowed"})
        pathlib.Path(d, ".check").write_text("# settings\nblock: *.xlsx\nprofile: dod\n")
        check("both files: .check is read, and the scan fails until .pii-guard is gone",
              config_name(d) == ".check" and profile_of(load_allow(d)) == "unknown")
        r = subprocess.run(ME + ["--stdin"], input="clean", env=env, capture_output=True, text=True, cwd=d)
        check("both files: the CLI fails and says what to do", r.returncode == 1 and "delete it" in r.stdout)
        pathlib.Path(d, ".pii-guard").unlink()
        check("only .check: its lines are read", load_allow(d) == {"block: *.xlsx", "profile: dod"})
        r = subprocess.run(ME + ["--status"], env=env, capture_output=True, text=True, cwd=d)
        check(".check: `block:` is no tier line; the tier line is read", "profile: dod" in r.stdout)
        pathlib.Path(d, ".check").write_text("block: *.xlsx\n")
        git(d, "add", ".check"); git(d, "commit", "-q", "-m", "settings")
        base = git(d, "rev-parse", "HEAD").stdout.strip()
        check(".check at a git ref is read", load_allow(d, base) == {"block: *.xlsx"})
        pathlib.Path(d, "sub").mkdir()
        pathlib.Path(d, "sub", "list.xlsx").write_text("not a real sheet\n")
        git(d, "add", "-A"); git(d, "commit", "-q", "-m", "add a sheet")
        r = subprocess.run(ME + ["--range", base + "..HEAD"], env=env, capture_output=True, text=True, cwd=d)
        check("a commit that adds a blocked file fails", r.returncode == 1 and "blocked" in r.stdout)
        r = subprocess.run(ME + ["--all"], env=env, capture_output=True, text=True, cwd=d)
        check("a tracked blocked file fails --all", r.returncode == 1 and "sub/list.xlsx:0: blocked" in r.stdout)
        git(d, "rm", "-q", "sub/list.xlsx"); git(d, "commit", "-q", "-m", "remove the sheet")
        r = subprocess.run(ME + ["--all"], env=env, capture_output=True, text=True, cwd=d)
        check("after its removal --all passes", r.returncode == 0)


def hook(d, tool, tool_input):
    """Run the hook in this process for one tool call in project d; return its exit code."""
    with contextlib.redirect_stderr(io.StringIO()):
        return check_content_hook.hook(json.dumps({"tool_name": tool, "cwd": d, "tool_input": tool_input}))


def case_hook_tools(check):
    """The hook for Write, Edit, NotebookEdit and Bash.
    Args:
        check: prints one result line and remembers a failure (label, good)."""
    mail = "jane" + at + "corp" + dot + "io"
    with tempfile.TemporaryDirectory() as d:
        pathlib.Path(d, ".check").write_text("block: *.xlsx\nblock: data/*.csv\nskip: ref/\n")
        os.symlink(d, d + "-link")  # the same project folder through a symlink
        saved = {k: os.environ.pop(k) for k in list(os.environ) if k.startswith("PII_GUARD_DENYLIST") or k == "CLAUDE_PROJECT_DIR"}
        os.environ["PII_GUARD_DENYLIST_FILE"] = os.path.join(d, "none.txt")
        os.environ["CLAUDE_PROJECT_DIR"] = d
        try:
            for name, tool, inp, want in (
                ("Write: clean text to a new file passes", "Write", {"file_path": "new.md", "content": "hello"}, 0),
                ("Write: an address in the content blocks", "Write", {"file_path": "new.md", "content": "mail " + mail}, 2),
                ("Write: a blocked path blocks", "Write", {"file_path": os.path.join(d, "out", "a.xlsx"), "content": "x"}, 2),
                ("Edit: an address in the new text blocks", "Edit", {"file_path": "a.md", "old_string": "x", "new_string": mail}, 2),
                ("Edit: an address only in the old text passes (the edit removes it)", "Edit", {"file_path": "a.md", "old_string": mail, "new_string": "the Maintainer"}, 0),
                ("NotebookEdit: an address in the new source blocks", "NotebookEdit", {"notebook_path": "n.ipynb", "new_source": mail}, 2),
                ("Bash: a local command with an address passes unread", "Bash", {"command": "grep -rn '" + mail + "' ."}, 0),
                ("Bash: curl with an address blocks", "Bash", {"command": "curl -d 'to=" + mail + "' https://example.com"}, 2),
                ("Bash: git commit with an address blocks", "Bash", {"command": "git -C . commit -m 'thanks " + mail + "'"}, 2),
                ("Bash: gh with a clean text passes", "Bash", {"command": "gh pr view 5"}, 0),
                ("Bash: a URL with a clean text passes", "Bash", {"command": "python3 fetch.py https://example.com/x"}, 0),
                ("Bash: a word that only holds 'gh' is local", "Bash", {"command": "echo high " + mail}, 0),
                ("Bash: a command of a wrong type is scanned and passes", "Bash", {"command": 5}, 0),
                ("Write: a path-form block line blocks", "Write", {"file_path": "data/x.csv", "content": "x"}, 2),
                ("Write: new text is scanned also under a skip line", "Write", {"file_path": "ref/a.md", "content": mail}, 2),
                ("Bash: git commit after a line continuation blocks", "Bash", {"command": "git -C /p \\\n commit -m " + mail}, 2),
                ("Bash: a client name split by a line continuation blocks", "Bash", {"command": "cu\\\nrl -d " + mail + " h; git com\\\nmit -m x"}, 2),
                ("Bash: /dev/udp blocks", "Bash", {"command": "echo " + mail + " > /dev/udp/h/1"}, 2),
                ("Bash: a comment, then a client name split over two lines, blocks", "Bash", {"command": "# x\\\ncu\\\nrl -d " + mail + " h"}, 2),
                ("Bash: a comment, then a git verb split over two lines, blocks", "Bash", {"command": "true # x\\\ngit com\\\nmit -m " + mail}, 2),
                ("Bash: a line continuation with clean text passes", "Bash", {"command": "ls \\\n -la"}, 0),
                ("Bash: wget2 and xh block", "Bash", {"command": "wget2 h?" + mail + "; xh post h a=" + mail}, 2),
                ("Bash: lftp blocks", "Bash", {"command": "lftp -e 'put " + mail + "' host"}, 2),
                ("Bash: a git verb split by a line continuation blocks", "Bash", {"command": "git com\\\nmit -m " + mail}, 2),
                ("Bash: a backslash and CR LF do not hide the next command", "Bash", {"command": "x\\\r\ncurl -d " + mail + " h"}, 2),
                ("Bash: a comment line that ends in a backslash does not hide the next command", "Bash", {"command": "# x\\\ncurl -d " + mail + " h"}, 2),
                ("Bash: rclone and /dev/tcp block", "Bash", {"command": "rclone copy x r:" + mail + "; echo " + mail + " > /dev/tcp/h/1"}, 2),
                ("Bash: a client named by its full path blocks", "Bash", {"command": "/usr/bin/curl -d " + mail + " example.org"}, 2),
                ("Bash: ./gh and sudo /bin/wget block", "Bash", {"command": "./gh issue create -b " + mail + "; sudo /bin/wget x?" + mail}, 2),
                ("Bash: git with a quoted folder, then commit, blocks", "Bash", {"command": "git -C 'my dir' commit -m '" + mail + "'"}, 2),
                ("Bash: aws with an address blocks", "Bash", {"command": "aws s3 cp - s3://b/" + mail}, 2),
                ("Bash: git status with an address is local", "Bash", {"command": "git status; grep " + mail + " notes.md"}, 0),
            ):
                code = hook(d, tool, inp)
                check(f"hook: {name} (exit {code})", code == want)
            with contextlib.redirect_stderr(io.StringIO()):
                code = check_content_hook.hook(json.dumps({"tool_name": "Write", "cwd": d + "-link", "tool_input": {"file_path": "data/x.csv", "content": "x"}}))
            check(f"hook: Write through a symlinked folder: the block line holds (exit {code})", code == 2)
            import time
            t0 = time.process_time()
            slow = check_content_hook.outgoing("git -a " * 16_000) or check_content_hook.outgoing("x /" * 40_000)
            check("hook: a long Bash command is classified in linear time", not slow and time.process_time() - t0 < 1)
        finally:
            os.environ.pop("PII_GUARD_DENYLIST_FILE", None)
            os.environ.pop("CLAUDE_PROJECT_DIR", None)
            os.environ.update(saved)
            os.unlink(d + "-link")


def case_setting_lines(check):
    """The `code-` and `audit-` lines of `.check` (scripts/check_settings.py reads them): option lines, never allowed
    values and never tier lines; every other line keeps its meaning, and the tier line still fails closed.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    settings = ["code-max-file-lines: 600", "code-exclude: Alex/*", "audit-ignore: ref/**", "audit-budget-file_kb: 100",
                "Code-C2: full", "code-c2 : dod", "audit-x: dod"]
    check("setting lines are option lines", all(is_option_line(v) for v in settings))
    check("setting lines are never tier lines", not any(is_tier_line(v) for v in settings))
    check("a setting line does not change the tier", profile_of(set(settings)) == "minimum"
          and profile_of(set(settings) | {"profile: dod"}) == "dod")
    check("a wrong tier line next to setting lines still fails closed",
          profile_of(set(settings) | {"profil: dod"}) == "unknown" and profile_of(set(settings) | {"profile: dodd"}) == "unknown")
    plain = ["code-review", "audit-trail", "codes: x", "code: dod", "the code-max: 1", "code-: 1"]
    check("a line that only looks like a setting is no setting line",
          [v for v in plain if is_option_line(v) and not is_tier_line(v)] == [])
    check("`code: dod` is still an unknown tier line", is_tier_line("code: dod") and profile_of({"code: dod"}) == "unknown")
    with tempfile.TemporaryDirectory() as d:
        env = {k: v for k, v in os.environ.items() if not k.startswith(("PII_GUARD", "GIT_"))}
        env["PII_GUARD_DENYLIST"] = "Alex"
        pathlib.Path(d, ".check").write_text("code-exclude: Alex/*\naudit-ignore: ref/**\nAlex Example\n")
        r = subprocess.run(ME + ["--stdin"], input="see code-exclude: Alex/* here", env=env, capture_output=True, text=True, cwd=d)
        check("a setting line is not an allowed value: a name in it is still found", r.returncode == 1 and "name" in r.stdout)
        r = subprocess.run(ME + ["--stdin"], input="by Alex Example", env=env, capture_output=True, text=True, cwd=d)
        check("an allowed string next to setting lines still passes", r.returncode == 0)


def gate_samples():
    """Sample lines of every finding kind, built at run time (no real value is in this file), with the letters that
    (?i) matches outside a-z (Kelvin sign, long s, dotted I), digits outside 0-9, and words that are not ASCII.

    Returns:
        The list of sample lines (case_gates, case_pool).
    """
    x36, mil = "A1b2C3d4E5" * 3 + "F6g7H8", "portal" + dot + "unit" + dot + "mi" + "l"
    arabic = "".join(chr(0x660 + int(c)) if c.isdigit() else c for c in "555-123-" + "4567")
    return [
        "mail ann" + at + "corp" + dot + "io", "x" + at + "users.noreply.github" + dot + "com",
        "gh" + "p_" + x36, "github" + "_pat_" + x36 * 2, "gl" + "pat-" + x36[:20], "AK" + "IA" + "ABCDEFGHIJ234567",
        "sk" + "-proj-" + x36, "AI" + "za" + x36[:35], "xo" + "xb-1234567890-" + x36[:12], "rk" + "_live_" + x36[:24],
        "-----BEGIN RSA " + "PRIVATE KEY-----",
        "call 555-123-" + "4567", "(555) 123-" + "4567", "+44 20 7946 " + "0958", "TEL: 555123" + "4567", "tel 555 123 " + "4567",
        "+1555123" + "4567", "phone " + arabic, "\uff15\uff15\uff15-123-" + "4567".replace("4", "\uff14"),
        "123-45-" + "6789", "SSN 123456" + "789", "Social Security: 123 45 " + "6789", "\u017f\u017fn 123456" + "789",
        "EDIPI 12345" + "67890", "12345" + "67890 (DoD ID)", "see " + mil, mil.upper(), "unit" + dot + "m\u0130" + "l",
        "x" + dot + "sharepoint-mi" + "l" + dot + "us", "dod" + dot + "teams" + dot + "microsoft" + dot + "us",
        "CU" + "I//SP", "  CU" + "I  ", "Controlled Unclassified " + "Information", "UNCLASSIFIED/" + "/FO" + "UO",
        "for official use " + "only", "NOF" + "ORN", "Top\u00a0Sec" + "ret", "TOP\tSEC" + "RET", "sec" + "ret/" + "/rel",
        "by JANE DOE", "\u212aim said", "o\u2019brien", "ZO\u00cb", "yu", "the BlueBird plan",
    ] + [w + " 555 123 " + "4567" for w in ("Phone", "tel", "CELL", "mobile", "fax", "call")] \
      + ["gh" + c + "_" + x36 for c in "pousr"] + ["xo" + "x" + c + "-" + x36[:12] for c in "abposr"]


def case_gates(check):
    """The gates skip only lines that cannot give a finding: FOLD_EXTRAS matches the regex engine, and random texts
    built from samples of every kind give the same findings with and without the gates, in both tiers.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    any_letter = re.compile("(?i)[a-z]")
    cased = [chr(c) for c in range(0x110000) if chr(c).lower() != chr(c) or chr(c).upper() != chr(c)]
    extra = {c for c in cased if not c.isascii() and (any_letter.fullmatch(c) or any(
        re.fullmatch("(?i)" + letter, c) for letter in "abcdefghijklmnopqrstuvwxyz"))}
    check(f"gates: FOLD_EXTRAS are the letters outside a-z that (?i) matches with a-z ({len(extra)})",
          extra == set(check_content_finders.FOLD_EXTRAS))
    samples = gate_samples()
    breaks = ["\n", "\r\n", "\r", "\x0b", "\x0c", "\x1c", "\x1d", "\x1e", "\x85", "\u2028", "\u2029", " ", ""]
    filler = ["plain words 12 34", "", '{"id": 123, "x": "2026-11-20"}', "caf\u00e9 top call", "a" * 300]
    rnd, deny, terms = random.Random(7), ["Jane Doe", "Kim", "O\u2019Brien", "Zo\u00eb", "Yu"], ["bluebird"]
    texts = []
    for _ in range(400):
        parts = []
        for _ in range(rnd.randint(1, 12)):
            piece = rnd.choice(samples + filler)
            if piece and rnd.random() < 0.2:   # a sample split by a line break
                cut = rnd.randrange(len(piece))
                piece = piece[:cut] + rnd.choice(breaks) + piece[cut:]
            parts.append(piece)
        texts.append("".join(p + rnd.choice(breaks) for p in parts))
    allow = {"Jane Doe Example", "call 555-123-" + "4567"}
    gated = [scan_text(t, "t", deny, allow, dod, terms) for t in texts for dod in (False, True)]
    keep = check_content_finders.candidate_lines
    check_content_finders.candidate_lines = lambda *a: None   # every line: the scan without gates
    try:
        plain = [scan_text(t, "t", deny, allow, dod, terms) for t in texts for dod in (False, True)]
    finally:
        check_content_finders.candidate_lines = keep
    check(f"gates: 400 random texts, both tiers: the same findings with and without gates ({sum(map(len, plain))})",
          gated == plain and sum(map(len, plain)) > 400)
    kinds = list(check_content_finders.KINDS)
    check("gates: a line with no gate match is skipped",
          keep("plain words\nmail ann" + at + "corp" + dot + "io\nmore", kinds, [], check_content_scan.FINDERS) == [1])
    own = dict(check_content_scan.FINDERS, phone=[lambda line: iter(())])
    check("gates: off when a kind has a project's own finders", keep("x", kinds, [], own) is None)


def case_pool(check):
    """The scan of many files in a pool of processes gives the same findings, in the same order, as in this process.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    samples = gate_samples()
    with tempfile.TemporaryDirectory() as d:
        paths = []
        for i in range(40):
            paths.append(f"f{i:02}.txt")
            pathlib.Path(d, paths[-1]).write_text("\n".join(samples[i:] + samples[:i]) + "\nfiller\n" * i, encoding="utf-8")
        pathlib.Path(d, "bin.dat").write_bytes(b"\0" * 10)
        paths.append("bin.dat")
        keep = check_content_scan.PARALLEL_BYTES
        check_content_scan.PARALLEL_BYTES = 1
        try:
            pooled = scan_files(paths, d, ["Jane Doe"], set(), True)
            job = (d, ["Jane Doe"], set(), True, False, (), check_content_scan.max_bytes_of(set()))
            ran = check_content_scan._in_parallel(paths, d, job) is not None
        finally:
            check_content_scan.PARALLEL_BYTES = keep
        serial = scan_files(paths, d, ["Jane Doe"], set(), True)
    check(f"pool: the same findings in the same order as one process ({len(serial)}; pool ran: {ran})",
          pooled == serial and len(serial) > 40 and (ran or check_content_scan.usable_cores() < 2))   # 2 or more usable cores: the pool must run


def run(check):
    """Run the cases of this file; check(label, good) prints and records each result."""
    for case in (case_terms, case_block_lines, case_check_file, case_setting_lines, case_hook_tools, case_gates,
                 case_pool):
        case(check)
