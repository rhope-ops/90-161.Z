"""More cases of the self-test of scripts/check_content.py: the CLI modes (--all, --push, --status, --stdin, files) in
temporary git repos, the commit scan, and the PreToolUse hook (in process); and the result recorder (check, FAILED)
and the sample parts (at, dot, x36, mil) that every case file of check_content_test.py uses.

Part of scripts/check_content_test.py (split out to keep each file under the line cap of docs/code-standard.md C4);
check_content_test.py imports these names and its run() calls the cases. No real address, token, host, mark or ID is
in this file: the samples are built at run time.
Input: none (temporary folders only). Output: one "ok" or "FAIL" line per case (check). Needs git.
Run: not run alone; check_content_test.py imports it.
Network: none.
Writes: temporary folders only.
Credentials: none (the sample secrets are built at run time and are not real).
"""
import contextlib
import io
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time

import check_content_hook
from check_content_scan import (MAX_BYTES, dod_mode, fingerprint, git, is_tier_line, load_allow, max_bytes_of,
                                profile_of, push_revs, scan_commits, warn_mode)



at, dot = "@", "."  # addresses and hosts are joined at run time, so this file does not flag itself
x36 = "A1b2C3d4E5" * 3 + "F6g7H8"  # body of the sample secrets
mil = "portal" + dot + "unit" + dot + "mi" + "l"  # a sample host in the military domain
ME = [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "check_content.py")]  # the guard's CLI
FAILED = []  # labels of the cases that failed


def check(label, good):
    """Print one result line and remember a failure."""
    print(("ok   " if good else "FAIL ") + label)
    if not good:
        FAILED.append(label)


def guard(d, env, *args):
    """Run the guard's CLI in folder d with this environment."""
    return subprocess.run(ME + list(args), cwd=d, env=env, capture_output=True, text=True)


def case_cli_denylist(d, env):
    """CLI: the denylist file, --push with no denylist, and `denylist: warn` (minimum and DoD tier).

    Args:
        d: a temporary folder (the sample repo).
        env: the environment for the git and CLI runs.
    """
    f = pathlib.Path(d, "deny.txt")
    f.write_text("Alex\n")
    env["PII_GUARD_DENYLIST_FILE"] = str(f)
    env["PII_GUARD_DENYLIST"] = "# only a comment"
    r = subprocess.run(ME + ["--status"], env=env, capture_output=True, text=True)
    good = r.returncode == 0 and "1 entries from file" in r.stdout and "Alex" not in r.stdout
    check("comment-only env var does not shadow the file; status hides names", good)
    env["PII_GUARD_DENYLIST_FILE"] = str(f) + ".missing"
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=d, check=True, capture_output=True)
    z = "0" * 40
    r = subprocess.run(ME + ["--push", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True,
                       input=f"refs/heads/main {'1' * 40} refs/heads/main {z}\n")
    check("push with no denylist: blocked", r.returncode == 1 and "no denylist" in r.stdout)
    r = subprocess.run(ME + ["--push", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True,
                       input=f"(delete) {z} refs/heads/x {'1' * 40}\n")
    check("branch delete with no denylist: passes", r.returncode == 0)
    pathlib.Path(d, ".pii-guard").write_text("# starter\ndenylist: warn\n")
    r = guard(d, env, "--all", "--require-denylist")
    good = r.returncode == 0 and "WARNING" in r.stdout and warn_mode(d)
    pathlib.Path(d, "a.txt").write_text("mail bob" + at + "corp" + dot + "io\n")
    subprocess.run(["git", "add", "a.txt"], cwd=d, check=True, capture_output=True)
    r = guard(d, env, "--all", "--require-denylist")
    check("denylist: warn: no denylist only warns; an email still blocks", good and r.returncode == 1)
    pathlib.Path(d, "a.txt").write_text("clean\n")
    pathlib.Path(d, ".pii-guard").write_text("denylist: warn\nprofile: dod\n")
    r = guard(d, env, "--all", "--require-denylist")
    good = r.returncode == 1 and "no denylist" in r.stdout and dod_mode(d) and not warn_mode(d)
    check("dod: no denylist blocks although the file says denylist: warn", good)


def case_cli_profile(d, env):
    """CLI: an unknown tier line, a byte-order mark, a wrong encoding and a zero-width space in .pii-guard.

    Args:
        d: a temporary folder (the sample repo).
        env: the environment for the git and CLI runs.
    """
    env["PII_GUARD_DENYLIST"] = "Alex"
    pathlib.Path(d, ".pii-guard").write_text("profile: DOD-tier\n")
    r = guard(d, env, "--all")
    r2 = guard(d, env, "--status")
    good = r.returncode == 1 and "CONTENT CHECK FAIL: unknown profile" in r.stdout and r2.returncode == 1 \
        and "UNKNOWN" in r2.stdout and dod_mode(d) and not warn_mode(d)
    check("unknown profile value: the scan and --status fail (no fall back to minimum)", good)
    pathlib.Path(d, ".pii-guard").write_bytes(b"\xef\xbb\xbfprofile: dod\r\n")
    r = guard(d, env, "--status")
    subprocess.run(["git", "add", ".pii-guard"], cwd=d, check=True, capture_output=True)
    staged = load_allow(d, ":0")  # the same file read through git, as --allow-from does
    good = r.returncode == 0 and "profile: dod" in r.stdout and dod_mode(d) and profile_of(staged) == "dod"
    subprocess.run(["git", "rm", "-q", "--cached", ".pii-guard"], cwd=d, check=True, capture_output=True)
    check("tier line after a byte-order mark, with CRLF: DoD tier (file and git read)", good)
    cases = {"UTF-16 with a byte-order mark": "profile: dod\n".encode("utf-16"), "UTF-16, no mark": "profile: dod\n".encode("utf-16-le"),
             "bytes that are not UTF-8": b"# note \xc3(\n", "a NUL byte": b"x\0y\n"}
    for label, raw in cases.items():
        pathlib.Path(d, ".pii-guard").write_bytes(raw)
        r = guard(d, env, "--all")
        subprocess.run(["git", "add", ".pii-guard"], cwd=d, check=True, capture_output=True)
        good = r.returncode == 1 and "CONTENT CHECK FAIL: unknown profile" in r.stdout and "Traceback" not in r.stderr \
            and profile_of(load_allow(d, ":0")) == "unknown"
        subprocess.run(["git", "rm", "-q", "--cached", ".pii-guard"], cwd=d, check=True, capture_output=True)
        check(f".pii-guard with {label}: the scan fails (file and git read)", good)
    pathlib.Path(d, ".pii-guard").write_text("​profile: dod\n", encoding="utf-8")
    check("tier line after a zero-width space: DoD tier", profile_of(load_allow(d)) == "dod")
    pathlib.Path(d, ".pii-guard").write_text("denylist: warn\nProfile:DoD\n")
    r = guard(d, env, "--status")
    good = r.returncode == 0 and "fingerprint " + fingerprint(["alex"]) in r.stdout and "profile: dod" in r.stdout
    check("status: fingerprint and profile", good)


def case_cli_dod_files(d, env):
    """DoD tier on files and commits: a PDF, a binary file, a host and a file over the size limit block; skip clears.

    Args:
        d: a temporary folder (the sample repo).
        env: the environment for the git and CLI runs.
    """
    pathlib.Path(d, "doc.pdf").write_bytes(b"%PDF-1.4 x")
    pathlib.Path(d, "blob.dat").write_bytes(b"a\0b")
    pathlib.Path(d, "notes.txt").write_text("see " + mil + "\n")
    subprocess.run(["git", "add", "a.txt", "doc.pdf", "blob.dat", "notes.txt"], cwd=d, check=True, capture_output=True)
    r = guard(d, env, "--all")
    good = r.returncode == 1 and r.stdout.count("unscanned") == 2 and "milhost" in r.stdout and "profile dod" in r.stdout \
        and mil not in r.stdout
    check("dod --all: a PDF, a binary file and a host block", good)
    pathlib.Path(d, ".pii-guard").write_text("profile: dod\nskip: doc.pdf\nskip: blob.dat\n" + mil + "\n")
    check("dod --all: skip lines and an allowed host clear them", guard(d, env, "--all").returncode == 0)
    pathlib.Path(d, ".pii-guard").write_text("# minimum\n")
    r = guard(d, env, "--all")
    check("minimum --all: the same files pass", r.returncode == 0 and "profile minimum" in r.stdout)
    idn = ["-c", "user.name=t", "-c", "user.email=1+t" + at + "users.noreply.github" + dot + "com"]
    subprocess.run(["git", *idn, "commit", "-q", "-m", "files"], cwd=d, check=True, capture_output=True)
    found, _ = scan_commits(["HEAD"], d, [], set(), dod=True)
    got = sorted((w.split()[-1], k) for w, _, k, _ in found)
    good = got == [("blob.dat", "unscanned"), ("doc.pdf", "unscanned"), ("notes.txt", "milhost")]
    found, _ = scan_commits(["HEAD"], d, [], {"skip: doc.pdf", "skip: blob.dat", mil}, dod=True)
    good = good and found == [] and scan_commits(["HEAD"], d, [], set())[0] == []
    check(f"dod commits: binary and PDF files block; skip clears; minimum passes: {got}", good)
    pathlib.Path(d, "big.txt").write_text("clean line\n" * (MAX_BYTES // 11 + 10))
    subprocess.run(["git", "add", "big.txt"], cwd=d, check=True, capture_output=True)
    subprocess.run(["git", *idn, "commit", "-q", "-m", "big"], cwd=d, check=True, capture_output=True)
    found, _ = scan_commits(["HEAD~1..HEAD"], d, [], set(), dod=True)
    good = [(w.split()[-1], k) for w, _, k, _ in found] == [("big.txt", "unscanned")] \
        and scan_commits(["HEAD~1..HEAD"], d, [], {"skip: big.txt"}, dod=True)[0] == [] \
        and scan_commits(["HEAD~1..HEAD"], d, [], {f"content-max-bytes: {MAX_BYTES * 2}"}, dod=True)[0] == [] \
        and max_bytes_of({"content-max-bytes: 10"}) == MAX_BYTES and max_bytes_of({"content-max-bytes: x"}) == MAX_BYTES \
        and max_bytes_of({"content-max-bytes: 999999999"}) == MAX_BYTES and not is_tier_line("content-max-bytes: 8000000") \
        and profile_of({"content-x: dod"}) == "unknown"
    check("dod commits: a text file over the size limit blocks; skip or content-max-bytes clears", good)


def case_cli():
    """The CLI cases above, in one temporary repo (each case builds on the state the one before it left)."""
    with tempfile.TemporaryDirectory() as d:
        env = {k: v for k, v in os.environ.items() if not k.startswith(("PII_GUARD", "GIT_"))}
        case_cli_denylist(d, env)
        case_cli_profile(d, env)
        case_cli_dod_files(d, env)


def commit_env():
    """Environment for test commits: a noreply identity named Sam, and no host git settings."""
    env = {**os.environ, "GIT_AUTHOR_NAME": "Sam", "GIT_COMMITTER_NAME": "Sam",
           "GIT_AUTHOR_EMAIL": "1+s" + at + "users.noreply.github" + dot + "com",
           "GIT_COMMITTER_EMAIL": "1+s" + at + "users.noreply.github" + dot + "com"}
    for k in [k for k in env if k.startswith("GIT_") and k not in (
            "GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL")]:
        env.pop(k)
    env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    return env


def case_commit_range(d, run):
    """Commit scan: a range finds the added line and the message; an added '++ ' line is content.

    Args:
        d: a temporary folder (the sample repo).
        run: runs one git command in d.

    Returns:
        The commit in the middle of the sample history (a later case scans from it).
    """
    run("init", "-q", "-b", "main")
    pathlib.Path(d, "a.txt").write_text("clean\n")
    run("add", "."); run("commit", "-q", "-m", "clean")
    base = git("rev-parse", "HEAD", root=d).strip()
    pathlib.Path(d, "a.txt").write_text("clean\nmail bob" + at + "corp" + dot + "io\n")
    run("add", "."); run("commit", "-q", "-m", "ask Alexandra")
    found, n = scan_commits([f"{base}..HEAD"], d, ["Alexandra"], set())
    kinds = sorted(k for _, _, k, _ in found)
    check(f"commit range: {n} commit(s), {kinds}", n == 1 and kinds == ["email", "name"])
    mid = git("rev-parse", "HEAD", root=d).strip()
    pathlib.Path(d, "a.txt").write_text("clean\nmail bob" + at + "corp" + dot + "io\n++ x\nmail sue" + at + "corp" + dot + "io\n")
    run("add", "."); run("commit", "-q", "-m", "plus lines")
    found, _ = scan_commits([f"{mid}..HEAD"], d, [], {"skip: x"})
    good = [k for _, _, k, _ in found] == ["email"] and all(" a.txt" in w for w, _, _, _ in found)
    check(f"added '++ ' line is content, not a file header: {[k for _, _, k, _ in found]}", good)
    return mid


def case_commit_merge_push(d, run, env, mid):
    """Commit scan: a merge commit keeps its file names, the author email is scanned, and pre-push lines parse.

    Args:
        d: a temporary folder (the sample repo).
        run: runs one git command in d.
        env: the environment for the git and CLI runs.
        mid: the commit case_commit_range gives.
    """
    run("checkout", "-q", "-b", "side", mid)
    pathlib.Path(d, "c.txt").write_text("side\n")
    run("add", "."); run("commit", "-q", "-m", "side")
    run("checkout", "-q", "main")
    pathlib.Path(d, "c.txt").write_text("main\n")
    run("add", "."); run("commit", "-q", "-m", "main c")
    subprocess.run(["git", "merge", "-q", "side"], cwd=d, env=env, capture_output=True)
    pathlib.Path(d, "c.txt").write_text("both\nmail ann" + at + "corp" + dot + "io\n")
    run("add", "."); run("commit", "-q", "-m", "merge side")
    found_skip, _ = scan_commits(["HEAD~1..HEAD"], d, [], {"skip: c.txt"})
    found_all, _ = scan_commits(["HEAD~1..HEAD"], d, [], set())
    good = found_skip == [] and [(w.split()[-1], k) for w, _, k, _ in found_all] == [("c.txt", "email")]
    check(f"merge commit (diff --cc): file name kept, skip rule applies: {len(found_skip)}, {len(found_all)}", good)
    env["GIT_AUTHOR_EMAIL"] = "me" + at + "home" + dot + "net"
    run("commit", "-q", "--allow-empty", "-m", "x")
    found, _ = scan_commits(["HEAD~1..HEAD"], d, [], set())
    check(f"author email: {[k for _, _, k, _ in found]}", [k for _, _, k, _ in found] == ["email"])
    z = "0" * 40
    head = git("rev-parse", "HEAD", root=d).strip()
    revs = push_revs(f"refs/heads/main {head} refs/heads/main {z}\n(delete) {z} refs/heads/x {head}\n", d)
    check(f"push lines: {revs}", revs == [[head, "--not", "--remotes"]])


def case_commits():
    """The commit-scan cases above, in one temporary repo."""
    with tempfile.TemporaryDirectory() as d:
        env = commit_env()
        run = lambda *a: subprocess.run(["git", *a], cwd=d, env=env, check=True, capture_output=True)
        mid = case_commit_range(d, run)
        case_commit_merge_push(d, run, env, mid)


def hook_cases(d, mail, tok):
    """The sample files and the (name, CLI args, input, wanted exit) cases for --hook, --stdin and named files.

    Args:
        d: a temporary folder (the sample repo).
        mail: a sample address, built at run time.
        tok: a sample token, built at run time.

    Returns:
        The list of cases.
    """
    pathlib.Path(d, "page.html").write_text("<p>" + mail + "</p>")
    pathlib.Path(d, "clean.html").write_text("<p>hello</p>")
    pathlib.Path(d, "a.pdf").write_bytes(b"%PDF-1.4 fake")
    pathlib.Path(d, "run.html").write_text("a1" * 100_000)  # 200 KB, one line, no "@"
    return [
        ("hook: clean Agent prompt passes", ["--hook"], {"tool_name": "Agent", "cwd": d, "tool_input": {"prompt": "fix the bug"}}, 0),
        ("hook: email in an Agent prompt blocks", ["--hook"], {"tool_name": "Agent", "cwd": d, "tool_input": {"prompt": "mail " + mail}}, 2),
        ("hook: email in a nested list blocks", ["--hook"], {"tool_name": "x", "cwd": d, "tool_input": {"a": [{"b": mail}]}}, 2),
        ("hook: file named by file_path is read", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "page.html"}}, 2),
        ("hook: clean file passes", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "clean.html"}}, 0),
        ("hook: files map source {from} is read", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {
            "file_path": "clean.html", "files": {"p/x.html": {"from": os.path.join(d, "page.html")}}}}, 2),
        ("hook: file_paths list is read", ["--hook"], {"tool_name": "SendUserFile", "cwd": d, "tool_input": {"file_paths": ["clean.html", "page.html"]}}, 2),
        ("hook: bad JSON blocks", ["--hook"], "{not json", 2),
        ("hook: the project's DoD tier holds with a cwd outside it", ["--hook"], {"tool_name": "Agent", "cwd": "/", "tool_input": {"prompt": "see " + "x" + dot + "af" + dot + "mi" + "l"}}, "dod"),
        ("hook: a crash blocks (deep nesting)", ["--hook"], '{"tool_input": {"prompt": "x", "a": ' + "[" * 3000 + "]" * 3000 + "}}", 2),
        ("hook: a crash blocks (cwd of a wrong type)", ["--hook"], {"tool_name": "Agent", "cwd": 5, "tool_input": {"prompt": "x"}}, 2),
        ("hook: mail recipients are not scanned, the body is", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d,
                                                                           "tool_input": {"to": [mail], "cc": mail, "subject": "hi", "body": "fix the bug"}}, 0),
        ("hook: a token in a mail recipient field blocks", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d, "tool_input": {"to": [mail, tok]}}, 2),
        ("hook: a 'to' key in a non-mail tool is scanned", ["--hook"], {"tool_name": "mcp__Claude_Docs__batch", "cwd": d, "tool_input": {"blocks": {"to": mail}}}, 2),
        ("hook: a nested 'to' key in a mail call is scanned", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d, "tool_input": {"body": {"to": mail}}}, 2),
        ("hook: a long run with no @ ends fast and passes", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "run.html"}}, 0),
        ("hook: named files over the size cap block", ["--hook"], {"tool_name": "SendUserFile", "cwd": d, "tool_input": {"file_paths": ["clean.html", "run.html"]}}, "cap"),
        ("hook: a missing file_path blocks", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "no-such.html"}}, 2),
        ("hook: an address in a mail body blocks", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d, "tool_input": {"to": [mail], "body": "write to " + mail}}, 2),
        ("hook: a named file it cannot scan blocks (minimum tier)", ["--hook"], {"tool_name": "SendUserFile", "cwd": d, "tool_input": {"file_paths": ["a.pdf"]}}, 2),
        ("file: a named file it cannot scan fails (minimum tier)", [os.path.join(d, "a.pdf")], "", 1),
        ("stdin: email fails", ["--stdin"], "brief: " + mail, 1),
        ("stdin: clean passes", ["--stdin"], "brief: fix the bug", 0),
        ("file: missing path fails", [os.path.join(d, "no-such.md")], "", 1),
        ("file: /dev/stdin is not a regular file: fails", ["/dev/stdin"], "x " + mail, 1),
    ]


def run_hook_in_process(d, text, want):
    """Run the hook in this process (a new Python per case would double the test time); return (exit, stderr, want).
    want "cap" lowers the size cap for the case; want "dod" makes d a DoD-tier project for the case.

    Args:
        d: a temporary folder (the sample repo).
        text: the hook input.
        want: the wanted exit code, or "cap" or "dod" (see above).

    Returns:
        (exit code, stderr text, the wanted exit code).
    """
    if want == "dod":  # a DoD-tier project folder for this case only
        pathlib.Path(d, ".pii-guard").write_text("profile: dod\n")
        subprocess.run(["git", "init", "-q"], cwd=d, capture_output=True)
    cap = check_content_hook.HOOK_MAX_BYTES
    check_content_hook.HOOK_MAX_BYTES = 150_000 if want == "cap" else cap
    err, t0 = io.StringIO(), time.process_time()  # CPU time of this process, as in case_speed
    try:
        with contextlib.redirect_stderr(err):
            code = check_content_hook.hook(text)
    finally:
        check_content_hook.HOOK_MAX_BYTES = cap
    out = err.getvalue()
    if want == "dod":
        pathlib.Path(d, ".pii-guard").unlink()
    want = 2 if want in ("cap", "dod") else want
    if time.process_time() - t0 > 5:
        out += " too slow"
        code = -1
    return code, out, want


def case_hook():
    """--hook, --stdin and named files (2026-11-16): a wrong path or bad hook input must never pass."""
    with tempfile.TemporaryDirectory() as d:
        env = {k: v for k, v in os.environ.items() if not k.startswith("PII_GUARD_DENYLIST")}
        env["PII_GUARD_DENYLIST_FILE"] = os.path.join(d, "none.txt")
        mail = "jane" + at + "corp" + dot + "io"
        cases = hook_cases(d, mail, "gh" + "p_" + "A" * 36)
        saved = {k: os.environ.pop(k) for k in list(os.environ) if k.startswith("PII_GUARD_DENYLIST") or k == "CLAUDE_PROJECT_DIR"}
        os.environ["PII_GUARD_DENYLIST_FILE"] = env["PII_GUARD_DENYLIST_FILE"]
        os.environ["CLAUDE_PROJECT_DIR"] = d
        try:
            for name, args, data, want in cases:
                text = data if isinstance(data, str) else json.dumps(data)
                if args == ["--hook"]:
                    code, out, want = run_hook_in_process(d, text, want)
                else:
                    r = subprocess.run(ME + args, cwd=d, env=env, input=text, capture_output=True, text=True)
                    code, out = r.returncode, r.stdout + r.stderr
                check(f"{name} (exit {code})", code == want and mail not in out)  # findings stay masked
        finally:
            os.environ.pop("PII_GUARD_DENYLIST_FILE", None)
            os.environ.pop("CLAUDE_PROJECT_DIR", None)
            os.environ.update(saved)
