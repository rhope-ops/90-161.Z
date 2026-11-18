"""More cases of the self-test of scripts/check_content.py (check_content_test.py runs them; kept apart for the
600-line cap of docs/code-standard.md C4): the terms list, the `block:` lines, the settings file under its name
`.check`, its `code-` and `audit-` setting lines, and the hook for the Write, Edit, NotebookEdit and Bash tools.

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
import subprocess
import sys
import tempfile

import check_content_hook
from check_content_scan import (blocked, config_name, is_option_line, is_tier_line, load_allow, load_terms, profile_of,
                                scan_files, scan_text)

at, dot = "@", "."
ME = [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "check_content.py")]


def kinds(text, deny=(), allow=(), terms=()):
    """The sorted finding kinds of one text."""
    return sorted({k for _, _, k, _ in scan_text(text, "t", list(deny), set(allow), False, list(terms))})


def case_terms(check):
    """The PFM's terms: whole word, any case, masked, kind term; a name stays a name; an allowed string wins.

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
                ("Edit: an address only in the old text passes (the edit removes it)", "Edit", {"file_path": "a.md", "old_string": mail, "new_string": "the PFM"}, 0),
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


def run(check):
    """Run the cases of this file; check(label, good) prints and records each result."""
    for case in (case_terms, case_block_lines, case_check_file, case_setting_lines, case_hook_tools):
        case(check)
