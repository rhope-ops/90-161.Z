#!/usr/bin/env python3
"""Session-start check: is this repo set up, and can the personal-data guard check names here?

Prevents: work that starts in a repo that still has template placeholders, or with no name denylist (so every push is blocked), and
a resumed session that starts a new plan review.

Usage:
    python3 scripts/first_use_check.py         # prints what the agent must do first; prints nothing when all is set
    python3 scripts/first_use_check.py --test  # self-test; prints FIRST USE TEST PASS

Claude Code runs it as a SessionStart hook (.claude/settings.json); its output goes into the session's context.
Other agents run it at the start of a session (AGENTS.md "Start of session").

It reports:
    FIRST USE       the repo still has template placeholders (a new project made from the template, not set up):
                    follow docs/FIRST_USE.md before any other work.
    KIT             the repo is the kit itself (origin named archimedes_lever), for example a plain `git clone` of it:
                    when the user asks to initiate or start a project, follow docs/FIRST_USE.md; for project
                    work, or when it is not clear, ask before changing anything.
    DENYLIST        the repo has the settings file .check but this session has no name denylist, so pushes will be blocked.
    RESUMED         the hook input says source "resume" or "compact" (a restart or a compaction, not a new session):
                    this line (plus DENYLIST when it applies) instead of KIT and FIRST USE: the agent runs the check-in and
                    continues the approved plan, without a new plan review (the owner, 2026-11-18).
The kit repo itself keeps its placeholders on purpose: it gets the KIT line, never FIRST USE.
Exit 0 always: a session-start hook informs, it never blocks. Standard library only.
Network: none (it runs local git read commands).
Writes: none (the self-test: a temporary repo).
Credentials: none; it reads whether a name denylist exists (an environment variable or a file), never its words.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

TEMPLATE_NAME = "archimedes_lever"
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from check_blocks import PLACEHOLDER  # noqa: E402 - the one placeholder pattern (scripts/check_blocks.py)


def origin_name(root):
    """The repo name of the origin remote, lower case ("" when there is no origin)."""
    r = subprocess.run(["git", "remote", "get-url", "origin"], cwd=root, capture_output=True, text=True)
    url = r.stdout.strip() if r.returncode == 0 else ""
    return re.sub(r"\.git$", "", url.rstrip("/")).rsplit("/", 1)[-1].lower()


def has_denylist():
    """Same rule as check_content.py (shared helper): the first source with at least one entry."""
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    import check_content
    return check_content.denylist_source()[1] is not None


def messages(root):
    """The session-start lines this repo needs: KIT, FIRST USE and DENYLIST, plus a note for a check that failed.

    Args:
        root: the repo root (a path).

    Returns:
        A list of lines to print.
    """
    root = pathlib.Path(root)
    out = []
    try:
        agents = root / "AGENTS.md"
        text = agents.read_text(errors="replace") if agents.is_file() else ""
        is_kit = origin_name(root) == TEMPLATE_NAME
        first_use = PLACEHOLDER.search(text) and not is_kit
    except Exception as e:  # each check on its own: one failure must not hide the other
        first_use, is_kit, text = False, False, ""
        out.append(f"first_use_check: placeholder check skipped ({e})")
    if is_kit:
        out.append("KIT: this is the archimedes_lever starter kit itself (origin is the kit repo). If the user asks to "
                   "initiate, start or set up a project, follow docs/FIRST_USE.md: it moves this clone to "
                   "the user's own repo first. If the user asks what this repo is or for your thoughts on it, give your view "
                   "and offer the two takes in README.md \"What you can take from it\" (adopt PREFERENCES.md by "
                   "interview, or set up a project). A request about the kit's own files (its rules, scripts or docs) "
                   "is work on the kit. Any other request (project work, or not clear which): before you change "
                   "anything, ask in one question whether to set up the user's own project from this clone first "
                   "(docs/FIRST_USE.md, recommended) or to work on the kit.")
    if first_use:
        out.append("FIRST USE: this repo was made from the template and is not set up yet. Before any other work, "
                   "follow docs/FIRST_USE.md: ask the Maintainer its questions (in Claude Code, with the clickable "
                   "question dialog), then run scripts/bootstrap.sh with the answers.")
    try:
        guard_without_list = ((root / ".check").is_file() or (root / ".pii-guard").is_file()) and not has_denylist()
    except Exception as e:
        guard_without_list = False
        out.append(f"first_use_check: denylist check skipped ({e})")
    if guard_without_list:
        try:
            sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
            import check_content
            warn = check_content.warn_mode(root)
        except Exception:
            warn = False
        effect = ("names are not checked (starter tier: pushes only warn)" if warn else "pushes will be blocked")
        out.append("DENYLIST: this repo has the personal-data guard on, but this session has no name denylist, so "
                   + effect + ". Ask the Maintainer to add the environment variable PII_GUARD_DENYLIST to this "
                   "cloud environment (environment menu in the session title bar > Edit > Environment variables; "
                   "names comma separated; a new session picks it up), or, on their own computer, the file "
                   "~/.config/pii-guard/denylist.txt. Never ask for the names in chat. Details: docs/FIRST_USE.md.")
    return out


RESUMED = ("RESUMED: this session restarted or its context was compacted; it is not a new session. Run "
           "scripts/session_checkin.sh for the git state, then continue the approved plan in docs/NEXT_PROMPT.md (in the kit: "
           "docs/KIT_HANDOFF.md; or the plan in the summary above) from the first step that is not done. Do not review the "
           "plan again and do not ask questions the Maintainer already answered; code reviews and checks still apply.")


def hook_source(raw):
    """The "source" field of the SessionStart hook input ("" when the input is empty or not JSON)."""
    try:
        data = json.loads(raw or "{}")
        return data.get("source", "") if isinstance(data, dict) else ""
    except ValueError:
        return ""


def read_hook_input():
    """The hook input on stdin; "" for a terminal or when nothing arrives within 2 s. Stops at 1 MB or 5 s (never hangs).

    Returns:
        The input as text, or "".
    """
    try:
        if sys.stdin is None or sys.stdin.isatty():
            return ""
        import select
        import time
        fd, chunks, wait, size, end = sys.stdin.fileno(), [], 2.0, 0, time.monotonic() + 5
        while size < 1_000_000 and time.monotonic() < end and select.select([fd], [], [], wait)[0]:  # read only what arrives: never wait for an EOF that may not come
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            wait = 0.2
        return b"".join(chunks).decode("utf-8", "replace")
    except Exception:  # no select on this stdin (for example a Windows pipe): treat as a new session
        return ""


def hook_cases(d, expect):
    """Hook-input cases in repo d: the source field, and the real hook on resume, invalid UTF-8 and 3 MB of input.

    Args:
        d: a temporary git repo.
        expect: checks one case (label, got, want).
    """
    for raw, want in (('{"source": "resume"}', "resume"), ('{"source": "compact"}', "compact"),
                      ('{"source": "startup"}', "startup"), ("", ""), ("not json", ""), ("[1]", "")):
        expect(f"hook source of {raw!r}", hook_source(raw), want)
    os.environ["PII_GUARD_DENYLIST"] = "Sam"
    run_hook = lambda data: subprocess.run([sys.executable, os.path.abspath(__file__)], cwd=d, input=data,
                                           capture_output=True, timeout=20)
    hook = lambda data: run_hook(data).stdout
    expect("hook run with source resume: RESUMED only", [l.split(b":")[0] for l in
           hook(b'{"source": "resume"}').splitlines()], [b"RESUMED"])
    expect("hook run with invalid UTF-8: a new session", hook(b"\xff\xfe").startswith(b"RESUMED"), False)
    expect("hook run with 3 MB of input: ends, exit 0", run_hook(b"x" * 3_000_000).returncode, 0)


def self_test():
    """Check the messages on a temporary repo through each state (new, kit clone, guard with and without denylist).

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    ok = True

    def expect(name, got, want):
        """Print ok or FAIL for one case and remember a failure."""
        nonlocal ok
        good = got == want
        print(("ok   " if good else "FAIL ") + f"{name}: {got}")
        ok = ok and good

    saved = {k: os.environ.pop(k, None) for k in ("PII_GUARD_DENYLIST", "PII_GUARD_DENYLIST_FILE")}
    os.environ["PII_GUARD_DENYLIST_FILE"] = os.devnull + ".missing"
    try:
        with tempfile.TemporaryDirectory() as d:
            run = lambda *a: subprocess.run(["git", *a], cwd=d, check=True, capture_output=True)
            run("init", "-q", "-b", "main")
            agents = pathlib.Path(d, "AGENTS.md")
            agents.write_text("# {{PROJECT_NAME}}: agent instructions\n")
            run("remote", "add", "origin", "https://github.com/someone/new-project.git")
            kinds = lambda: [m.split(":")[0] for m in messages(d)]
            expect("new project with placeholders", kinds(), ["FIRST USE"])
            run("remote", "set-url", "origin", "https://github.com/someone/Archimedes_Lever.git")
            expect("kit clone: KIT, not FIRST USE", kinds(), ["KIT"])
            good = any(m.startswith("KIT") and "ask in one question" in m for m in messages(d))
            print(("ok   " if good else "FAIL ") + "KIT: project work or an unclear request is asked about, not taken as kit work")
            ok = ok and good
            pathlib.Path(d, ".check").write_text("# on\n")
            expect("guard on, no denylist", kinds(), ["KIT", "DENYLIST"])
            os.environ["PII_GUARD_DENYLIST"] = "Sam"
            expect("guard on, denylist in environment", kinds(), ["KIT"])
            run("remote", "rename", "origin", "kit")
            expect("kit clone after 'git remote rename origin kit': FIRST USE", kinds(), ["FIRST USE"])
            run("remote", "add", "origin", "https://github.com/someone/Archimedes_Lever.git")
            os.environ.pop("PII_GUARD_DENYLIST")
            agents.write_text("# Demo: agent instructions\n")
            run("remote", "set-url", "origin", "https://github.com/someone/demo")
            expect("set-up project, guard on, no denylist", kinds(), ["DENYLIST"])
            pathlib.Path(d, ".check").write_text("denylist: warn\n")
            good = any("pushes only warn" in m for m in messages(d))
            print(("ok   " if good else "FAIL ") + "starter warn mode: DENYLIST says pushes only warn")
            ok = ok and good
            pathlib.Path(d, ".check").unlink()
            expect("set-up project, guard off", kinds(), [])
            hook_cases(d, expect)
    finally:
        for k, v in saved.items():
            os.environ.pop(k, None)
            if v is not None:
                os.environ[k] = v
    print("FIRST USE TEST " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def root():
    """The repo root (git), else CLAUDE_PROJECT_DIR, else the current directory."""
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else os.environ.get("CLAUDE_PROJECT_DIR", ".")


def main():
    """Print the messages for the current repo, or run --test; return the exit code.

    Returns:
        The exit code 0, or the exit code of the self-test.
    """
    if "--test" in sys.argv[1:]:
        return self_test()
    if hook_source(read_hook_input()) in ("resume", "compact"):
        print(RESUMED)
        for m in messages(root()):  # a resumed shell can lack the denylist: keep that warning
            if m.startswith("DENYLIST"):
                print(m)
        return 0
    for m in messages(root()):
        print(m)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # a session-start hook must never break the session
        print(f"first_use_check: skipped ({e})")
        sys.exit(0)
