#!/usr/bin/env python3
"""Self-test cases of scripts/check_instructions.py (run: python3 scripts/check_instructions.py --test).

Inputs:  none; each case builds its own text, or a temporary git repo with a `.check`, a project module and a
         transcript file.
Outputs: "INSTRUCTIONS TEST PASS" and exit 0, or the failed case and exit 1.
Network: none.
Writes:  temporary folders only.
Credentials: none.
"""
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import check_instructions as ci

GOOD = """# Restore the backup

1. In the window **Backup**, click **Restore**. You see the card **Restore code**. Write down the code on the card.
2. In the window **Restore**, type the code from the card **Restore code**. You see the code in the box. Go on.
3. Press **Enter**. You see **Restoring**.
   Wait until the card **Restore done** shows. Do not close the window.
4. Close the window **Backup**. The window closes. The task is complete.
"""
FACTS = """The parts:

1. The engine, which reads the files.
2. The page, which shows the result.
"""


def findings(text, path="go.md", local=None):
    """The finding lines of one text, with the kit's rules (or a project module's).

    Args:
        text: the file text.
        path: the path to print; an .html path uses the HTML parser.
        local: a project module, or None.

    Returns:
        A list of finding lines.
    """
    return ci.check_file(path, text, ci.load_rules(local))


def kinds(text, path="go.md"):
    """The finding kinds (the word before the colon) of one text, in order."""
    return [line.split(": ", 2)[1].split(":")[0] for line in findings(text, path)]


def step(body):
    """A two-step procedure whose first step is `body` and whose second step is clean."""
    return f"1. {body}\n2. Click **Close**. The window closes. The task is complete.\n"


def case_steps():
    """Each finding kind, a clean procedure, a list of facts and a lead-in with numbered actions."""
    assert findings(GOOD) == [], findings(GOOD)
    assert findings(FACTS) == [], "a numbered list of facts is not a procedure"
    assert kinds(step("Click **Open**, then type `abc`. You see the form. Go on.")) == ["actions"]
    assert kinds(step("Click **Open** and close the window. You see the form. Go on.")) == ["actions"]
    assert kinds(step("Click **Save** as described above. You see the form. Go on.")) == ["pointer"]
    assert kinds(step("Do the actions in step 3. You see the form. Go on.")) == ["pointer"]
    assert kinds(step("Open [the guide](docs/guide.md). You see the guide. Go on.")) == ["pointer"]
    assert kinds(step("Open [the page](https://example.com/a). You see the page. Go on.")) == []
    assert kinds(step("Select the appropriate file. You see the form. Go on.")) == ["vague"]
    assert kinds(step("Click **Restore**. You see the card. Wait a few minutes.")) == ["vague", "wait"]
    assert kinds(step("Click **Restore**. Wait until the card **Done** shows.")) == []
    assert kinds(step("Click **Restore**. Go on.")) == ["next"]
    assert kinds(step("Click **Restore**. You see the card **Done**.")) == ["cue"]
    long_sentence = "Click **Open** in the window that is on the left side of the screen near the top of the list of all the files."
    assert kinds(step(long_sentence + " You see it. Go on.")) == ["long"]
    lead = "1. On the screen **Sign in**, do these actions:\n   1. Type `name` in **User**.\n   2. Type `pass` in **Key**.\n" \
           "   You see the button **Sign in** turn blue. Go on.\n2. Click **Sign in**. You see the start page. The task is complete.\n"
    assert findings(lead) == [], findings(lead)
    assert kinds("1. Click **A** and click **B**. You see C. Go on.\n2. Click **D**. You see E. Go on.\n") == ["actions"]
    for seen in ("the table **Totals**", "the list of files", "the guide **Start**", "the **Backup** section",
                 "the section **Backup**", "the other steps in the panel"):
        assert kinds(step(f"Click **Report**. You see {seen}. Go on.")) == [], seen
    assert kinds(step("Click **Report**. You see 5 minutes in May. Go on.")) == []
    for told in ("See page 4.", "See the file **notes.txt**.", "Read the section **Install**.",
                 "Follow the **Install** section of the README.", "Do the earlier list again.", "See the next step.",
                 "See the next page.", "Do the next step again.", "Skip the following steps.", "Repeat that step.",
                 "Do the other steps again.", "See chapter 2.", "Click **A**, and see step 3."):
        assert kinds(step(told + " You see the form. Go on.")) == ["pointer"], told
    for run in ("Let it run for 10 minutes.", "Let it run for ten minutes.", "Let it run for 2 mins."):
        assert kinds(step(run + " You see **Done**. Go on.")) == ["wait"], run
    assert kinds(step("Click **Go**. You see the timer count for 10 minutes. Go on.")) == []
    assert kinds(step("Click **Go**. You see the form, and see step 3. Go on.")) == ["pointer"]
    assert kinds(step("Click **Go**. You see the form then see step 3. Go on.")) == ["pointer"]
    assert kinds(step("Click **Go**. You see the spinner and wait for 10 minutes. Go on.")) == ["wait"]
    assert kinds(step("Click **Go**. You see the page and it restarts. Go on.")) == ["wait"]
    for plain_ui in ("Click **A** for a second time.", "Click **A** in this list.", "Click **A** in that list.",
                     "Type the chapter name.", "Open the chapters list."):
        assert kinds(step(plain_ui + " You see the form. Go on.")) == [], plain_ui
    bad_lead = "1. Open the app and click **Settings**, then do these actions:\n   1. Type `a` in **A**.\n" \
               "   2. Type `b` in **B**.\n   You see **Saved**. Go on.\n2. Click **D**. You see E. Go on.\n"
    assert kinds(bad_lead) == ["actions"], findings(bad_lead)
    tabbed = lead.replace("   1.", "\t1.").replace("   2.", "\t2.").replace("   You", "\tYou")
    assert findings(tabbed) == [], findings(tabbed)


def case_html_and_globs():
    """The HTML parser (code and bold are one word, a local link is a pointer) and the glob form."""
    page = ("<ol><li>Click <b>Restore</b>. You see the card <code>Restore code</code>. Go on.</li>"
            "<li>Read <a href='other.html'>the notes</a>. You see the notes. Go on.</li></ol>")
    assert kinds(page, "page.html") == ["pointer"], findings(page, "page.html")
    mixed = ("<ol><li>Click <b>A</b> and click <b>B</b>. You see C. Go on.<ul><li>a note</li></ul>"
             "<li>Click <b>D</b>. You see E. Go on.</ol>")
    assert kinds(mixed, "page.html") == ["actions"], "a <ul> is no lead-in, and an <li> with no end tag ends at the next"
    rx = ci.glob_regex
    assert rx("docs/**/*.md").match("docs/a/b/go.md") and rx("docs/**/*.md").match("docs/go.md")
    assert not rx("*.md").match("docs/go.md") and rx("**/README.md").match("README.md")


def case_local(root):
    """A project module: more vague words, a lower limit, a limit above the kit's (ignored), an unknown key, a
    module that cannot be loaded.

    Args:
        root: a temporary folder (the module is written in its scripts/ folder).
    """
    (root / "scripts").mkdir(exist_ok=True)
    mod = root / ci.LOCAL
    mod.write_text("VAGUE = [r'\\bsoonish\\b']\nLIMITS = {'sentence_words': 5, 'step_words': 500}\n")
    rules = ci.load_rules(ci.load_local(root))
    assert rules["sentence_words"] == 5 and rules["step_words"] == ci.STEP_WORDS, "a project can only lower a limit"
    text = step("Click **Open** soonish. You see the form. Go on.")
    got = [line.split(": ", 2)[1].split(":")[0] for line in ci.check_file("go.md", text, rules)]
    assert got == ["vague"], got
    mod.write_text("LIMITS = {'words': 5}\n")
    assert fails(lambda: ci.load_rules(ci.load_local(root))), "an unknown limit key fails"
    mod.write_text("this is not python\n")
    assert fails(lambda: ci.load_local(root)), "a module that cannot be loaded fails"
    mod.unlink()


def fails(call):
    """True when call() raises an exception."""
    try:
        call()
    except Exception:  # noqa: BLE001 - any error counts
        return True
    return False


def git_repo(root):
    """Make `root` a git repo with a `.check` that names go.md, and the files go.md (clean) and bad.md (not named)."""
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    (root / ".check").write_text("audit-instructions: go.md\n")
    (root / "go.md").write_text(GOOD)
    (root / "bad.md").write_text(step("Select the appropriate file."))
    subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)


def case_run(root):
    """The command: the `.check` globs pick the files; a named file is checked; no glob is a pass that says so.

    Args:
        root: a temporary git repo (git_repo).
    """
    out = io.StringIO()
    real, sys.stdout = sys.stdout, out
    try:
        assert ci.run_check(root, []) == 0, "go.md is clean; bad.md is not named"
        assert ci.run_check(root, ["bad.md"]) == 1, "a named file is checked"
        (root / "sub").mkdir(exist_ok=True)
        got = subprocess.run([sys.executable, str(Path(ci.__file__).resolve()), "../go.md"], cwd=root / "sub",
                             capture_output=True, text=True)
        assert got.returncode == 0 and "INSTRUCTIONS PASS" in got.stdout, "a relative name from a subfolder: " + got.stdout + got.stderr
        (root / ".check").write_text("")
        assert ci.run_check(root, []) == 0 and "no instruction files" in out.getvalue()
        (root / ".check").write_text("audit-instructions:\n")
        assert ci.run_check(root, []) == 1, "a setting line that is not valid fails"
    finally:
        sys.stdout = real
        (root / ".check").write_text("audit-instructions: go.md\n")


def hook(root, rel, transcript="", session="s1"):
    """The exit code of the hook for a Write of `rel` in `root` (stderr is dropped)."""
    event = {"tool_name": "Write", "cwd": str(root), "tool_input": {"file_path": rel, "content": "x"},
             "transcript_path": transcript, "session_id": session}
    real, sys.stderr = sys.stderr, io.StringIO()
    try:
        return ci.run_hook(io.StringIO(json.dumps(event)))
    finally:
        sys.stderr = real


def case_hook(root):
    """The hook: blocks a matched file until the transcript shows the skill load; a compaction resets it; an
    unmatched file and `.check` pass; with no transcript it blocks the first write of the session only.

    Args:
        root: a temporary git repo (git_repo).
    """
    log = root / "t.jsonl"
    use = {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Skill", "input": {"skill": "instructions"}}]}}
    read = {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Read",
                                                          "input": {"file_path": "/r/" + ci.SKILL, "limit": 20}}]}}
    log.write_text(json.dumps(read) + "\n")
    assert hook(root, "go.md", str(log)) == 2, "a matched file before the skill (a part read is no load)"
    assert hook(root, "bad.md", str(log)) == 0 and hook(root, ".check", str(log)) == 0, "unmatched files pass"
    log.write_text(json.dumps(read) + "\n" + json.dumps(use) + "\n")
    assert hook(root, "go.md", str(log)) == 0, "after the Skill call"
    log.write_text(json.dumps(use) + "\n" + json.dumps({"type": "system", "subtype": "compact_boundary"}) + "\n")
    assert hook(root, "go.md", str(log)) == 2, "a compaction needs a new load"
    assert hook(root, "go.md", "", "s2") == 2 and hook(root, "go.md", "", "s2") == 0, "no transcript: the first write only"
    (root / ".check").write_text("audit-instructions:\n")
    assert hook(root, "src.py", str(log)) == 0, "a broken setting line does not block every write"
    real_read = ci.check_settings.read

    def refuse(*_args, **_kwargs):
        """A `.check` that cannot be read."""
        raise PermissionError("no access")
    ci.check_settings.read = refuse
    try:
        assert hook(root, "src.py", str(log)) == 2, "a .check that cannot be read blocks (fail closed)"
    finally:
        ci.check_settings.read = real_read
    (root / ".check").write_bytes(b"audit-instructions: \xff\n")
    assert hook(root, "src.py", str(log)) == 0, "a .check that is not UTF-8 is a broken setting: check.sh fails on it"
    (root / ".check").write_text("audit-instructions: go.md\n")


def run():
    """Run every case; print the result line.

    Returns:
        0 when every case passed, 1 otherwise.
    """
    try:
        case_steps()
        case_html_and_globs()
        repo_cases()
    except AssertionError as err:
        print(f"INSTRUCTIONS TEST FAIL: {err}")
        raise
    print("INSTRUCTIONS TEST PASS")
    return 0


def repo_cases():
    """The cases that share one sample git repo, in order: the project's module, a run, and the hook."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        git_repo(root)
        case_local(root)
        case_run(root)
        case_hook(root)


class CheckInstructionsTest(unittest.TestCase):
    """The cases of `python3 scripts/check_instructions.py --test`, for `python3 -m unittest` and pytest."""

    def test_steps(self):
        """The step reader and each finding on Markdown steps."""
        case_steps()

    def test_html_and_globs(self):
        """HTML lists and the path globs."""
        case_html_and_globs()

    def test_repo(self):
        """The project's own module, a run on a sample repo, and the hook."""
        repo_cases()
