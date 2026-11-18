"""More cases of the self-test of scripts/check_content.py (check_content_test.py runs them; kept apart so that file
stays under the 600-line cap of docs/code-standard.md C4): a project's own finders, scripts/check_content_local.py,
and a copy of the check that lacks one of its parts.

It proves, with a sample module in a temporary folder: a module replaces the finders of a kind and adds finders; the
result line and --status say that it is active; a module that cannot be imported or has a wrong shape makes every
scan fail (never a pass on the kit's patterns, never no check) and the hook block (exit 2); a finder that fails
during a scan fails that scan; and with no module the kit's patterns are in use. A copy of check_content.py without
its parts blocks when it is run (also as the hook) and only raises ImportError when it is imported.
Input: none (samples are built at run time, so this file does not flag itself).
Output: one "ok" or "FAIL" line per case through the check() function that run() gets.
Run: python3 scripts/check_content.py --test
Network: none.
Writes: temporary folders only.
Credentials: none.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

import check_content_finders
import check_content_scan

dot = "."  # hosts are joined at run time, so this file does not flag itself
HOST = "portal" + dot + "unit" + dot + "mi" + "l"   # a sample host in the military domain
# A sample module: its own milhost finder (only hosts that start with "x-"), and one more secret finder.
SAMPLE = '''"""Sample of a project's own finders for the self-test of the content check."""
import re

OWN_HOST = re.compile(r"x-[a-z]+\\.mil\\b")
OWN_SECRET = re.compile(r"LOCALKEY-[0-9]{6}")


def own_hosts(line):
    """Yield (start, end, host) for each host of the sample pattern."""
    return ((m.start(), m.end(), m.group()) for m in OWN_HOST.finditer(line))


def own_secrets(line):
    """Yield (start, end, key) for each key of the sample pattern."""
    return ((m.start(), m.end(), m.group()) for m in OWN_SECRET.finditer(line))


REPLACE = {"milhost": [own_hosts]}
ADD = {"secret": [own_secrets]}
'''
# Modules that cannot be used, and a word of the message each must give.
BROKEN = (
    ("an import that fails", "import no_such_module_anywhere\n", "cannot be loaded"),
    ("a syntax error", "def f(:\n", "cannot be loaded"),
    ("an error when it is loaded", "REPLACE = {}\nraise RuntimeError('boom')\n", "cannot be loaded"),
    ("neither REPLACE nor ADD", "X = 1\n", "has no finder"),
    ("empty REPLACE and ADD", "REPLACE = {}\nADD = {'secret': []}\n", "has no finder"),
    ("a kind the scanner does not have", "REPLACE = {'hostname': [len]}\n", "REPLACE must be"),
    ("a REPLACE list with no finder", "REPLACE = {'milhost': []}\n", "at least one finder"),
    ("a finder that is not a function", "ADD = {'secret': ['pattern']}\n", "ADD must be"),
    ("REPLACE that is not a dict", "REPLACE = [len]\n", "REPLACE must be"),
)


def kinds_of(text, dod=True):
    """The finding kinds of one text with the finders now in use (DoD tier unless dod is False)."""
    return [k for _, _, k, _ in check_content_scan.scan_text(text, "t", [], set(), dod)]


def case_in_process(check, d):
    """The loader and scan_text in this process: a good module, each broken module, and no module.

    Args:
        check: prints one result line and remembers a failure (label, good).
        d: a temporary folder for the sample module.
    """
    path = os.path.join(d, check_content_finders.LOCAL_NAME)
    key = "LOCALKEY-" + "123456"
    try:
        with open(path, "w") as f:
            f.write(SAMPLE)
        check_content_scan.use_local(path)
        check("local module: it loads, and the note names what it replaces and adds",
              check_content_scan.LOCAL_ERROR is None and check_content_scan.LOCAL.endswith("active (replaces milhost; adds secret)"))
        check("local module: its finder replaces the kit's for that kind", kinds_of("see x-base" + dot + "mil") == ["milhost"]
              and kinds_of("see " + HOST) == [])
        check("local module: an added finder runs next to the kit's", kinds_of(key + " and gh" + "p_" + "A" * 36, False) == ["secret", "secret"])
        check("local module: a replaced DoD kind still runs only in the DoD tier", kinds_of("see x-base" + dot + "mil", False) == [])
        for label, text, why in BROKEN:
            with open(path, "w") as f:
                f.write(text)
            check_content_scan.use_local(path)
            try:
                kinds_of("clean text")
                raised = ""
            except check_content_scan.LocalError as err:
                raised = str(err)
            check(f"broken local module ({label}): every scan raises, and the message says why",
                  why in raised and why in (check_content_scan.LOCAL_ERROR or "") and check_content_scan.FINDERS is None)
        os.remove(path)
        check_content_scan.use_local(path)
        check("no local module: the kit's patterns are in use", check_content_scan.LOCAL == "" and kinds_of("see " + HOST) == ["milhost"]
              and kinds_of(key, False) == [])
    finally:
        check_content_scan.use_local(os.path.join(d, "none", check_content_finders.LOCAL_NAME))


def cli(scripts, d, args, text):
    """Run the copied check_content.py with these arguments and this stdin; return (exit code, output).

    Args:
        scripts: the folder with the copied scripts.
        d: the folder to run in.
        args: the command-line arguments.
        text: the text for stdin.

    Returns:
        (exit code, stdout and stderr).
    """
    env = {k: v for k, v in os.environ.items() if not k.startswith(("PII_GUARD_DENYLIST", "CLAUDE_PROJECT_DIR"))}
    env["PII_GUARD_DENYLIST_FILE"] = os.path.join(d, "none.txt")
    r = subprocess.run([sys.executable, os.path.join(scripts, "check_content.py"), *args], cwd=d, env=env, input=text,
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def case_load_ends(check, scripts, d, path, write):
    """A local module that ends or stalls the process while it loads: the scan fails and the hook blocks.

    Args:
        check: prints one result line and remembers a failure (label, good).
        scripts: the folder with the copied scripts.
        d: the folder to run in.
        path: the path of the local module file to write.
        write: the JSON text of a clean Write tool call for the hook.
    """
    for label, text in (("exit 0", "import sys\nsys.exit(0)\n"), ("exit 1", "import sys\nsys.exit(1)\n"),
                        ("a self-test with no main guard", "ADD = {}\nprint('LOCAL TEST PASS')\nraise SystemExit(0)\n")):
        with open(path, "w") as f:   # a file that ends the process while it loads must not end the scan with its code
            f.write(text)
        code, out = cli(scripts, d, ["--stdin"], "clean text")
        check(f"local module that exits at load ({label}): a scan fails", code == 1 and "CONTENT CHECK FAIL" in out)
        check(f"local module that exits at load ({label}): the hook blocks (exit 2)", cli(scripts, d, ["--hook"], write)[0] == 2)
    with open(path, "w") as f:   # a load that hangs: the hook's own time budget ends it with a block
        f.write("import time\ntime.sleep(20)\n")
    import time
    for value, label in (("1", "the timer ends it"), ("abc", "a bad timer value still blocks"),
                         ("\u00b2", "a superscript digit still blocks"), ("9" * 5000, "a very long number still blocks")):
        os.environ["CHECK_HOOK_LOAD_S"] = value
        try:
            t0 = time.monotonic()
            code = cli(scripts, d, ["--hook"], write)[0]
            took = time.monotonic() - t0
        finally:
            del os.environ["CHECK_HOOK_LOAD_S"]
        # with "1" the load timer must end the process long before the 20 s sleep does; with a bad value it is 8 s
        check(f"local module that hangs at load: the hook blocks, {label} (exit {code}, under {5 if value == '1' else 15} s)",
              code == 2 and took < (5 if value == "1" else 15))


def case_cli(check, d, kit_scripts):
    """The command line and the hook with a copy of the scripts and a sample module next to them.

    Args:
        check: prints one result line and remembers a failure (label, good).
        d: a temporary folder.
        kit_scripts: the folder of the scripts under test (with no local module).
    """
    scripts = os.path.join(d, "scripts")
    shutil.copytree(kit_scripts, scripts, ignore=shutil.ignore_patterns("__pycache__"))
    path = os.path.join(scripts, check_content_finders.LOCAL_NAME)
    write = json.dumps({"tool_name": "Write", "cwd": d, "tool_input": {"file_path": "a.txt", "content": "clean text"}})
    local_bash = json.dumps({"tool_name": "Bash", "cwd": d, "tool_input": {"command": "ls"}})
    code, out = cli(scripts, d, ["--stdin"], "clean text")
    check("no local module: the result line does not name one", code == 0 and "CONTENT CHECK PASS" in out and "local module" not in out)
    with open(path, "w") as f:
        f.write(SAMPLE)
    code, out = cli(scripts, d, ["--stdin"], "clean text")
    check("local module: the result line says it is active", code == 0 and out.rstrip().endswith(
        "; local module " + check_content_finders.LOCAL_NAME + " active (replaces milhost; adds secret)"))
    code, out = cli(scripts, d, ["--stdin"], "the key LOCALKEY-" + "123456")
    check("local module: its finding fails the scan, masked", code == 1 and "secret: <15 chars>" in out)
    code, out = cli(scripts, d, ["--status"], "")
    check("local module: --status names it", "finders: local module " + check_content_finders.LOCAL_NAME + " active" in out)
    check("local module: the hook lets a clean call run", cli(scripts, d, ["--hook"], write)[0] == 0)
    for label, text, why in BROKEN[:2] + BROKEN[3:4] + BROKEN[5:6]:
        with open(path, "w") as f:
            f.write(text)
        code, out = cli(scripts, d, ["--stdin"], "clean text")
        check(f"broken local module ({label}): a scan of clean text fails", code == 1 and "CONTENT CHECK FAIL" in out
              and why in out and "PASS" not in out)
        code, out = cli(scripts, d, ["--hook"], write)
        check(f"broken local module ({label}): the hook blocks a clean call (exit 2)", code == 2 and why in out)
        code, out = cli(scripts, d, ["--status"], "")
        check(f"broken local module ({label}): --status fails and says why", code == 1 and "finders: FAIL" in out and why in out)
    check("broken local module: a local Bash command is not scanned, so it can repair the file", cli(scripts, d, ["--hook"], local_bash)[0] == 0)
    case_load_ends(check, scripts, d, path, write)
    with open(path, "w") as f:   # the shape is right, but the finder fails when it runs
        f.write("def bad(line):\n    raise RuntimeError('boom')\n\n\nADD = {'email': [bad]}\n")
    code, out = cli(scripts, d, ["--stdin"], "clean text")
    check("a finder that fails during a scan: the scan fails", code not in (0, 2) and "PASS" not in out)
    check("a finder that fails during a scan: the hook blocks (exit 2)", cli(scripts, d, ["--hook"], write)[0] == 2)
    with open(path, "w") as f:   # a finder that gives a wrong shape
        f.write("ADD = {'email': [lambda line: ['x']]}\n")
    check("a finder that gives a wrong shape: the scan fails", cli(scripts, d, ["--stdin"], "clean text")[0] not in (0, 2))
    check("a finder that gives a wrong shape: the hook blocks (exit 2)", cli(scripts, d, ["--hook"], write)[0] == 2)


def case_missing_parts(check, kit_scripts):
    """A copy of check_content.py without its parts blocks when run (exit 2, also in the hook) but only raises on import.

    Args:
        check: prints one result line and remembers a failure (label, good).
        kit_scripts: the folder of the scripts under test.
    """
    with tempfile.TemporaryDirectory() as d:
        alone = os.path.join(d, "check_content.py")
        with open(os.path.join(kit_scripts, "check_content.py")) as src, open(alone, "w") as dst:
            dst.write(src.read())
        env = {k: v for k, v in os.environ.items() if k != "PYTHONPATH"}   # only the lone copy is importable
        hook = subprocess.run([sys.executable, alone, "--hook"], input="{}", capture_output=True, text=True, cwd=d,
                              env=env)
        check("missing parts: the hook blocks (exit 2)", hook.returncode == 2)
        for part in ("check_content_scan.py", "check_content_finders.py"):   # the scan parts alone: --hook still blocks
            shutil.copy(os.path.join(kit_scripts, part), d)
        hook = subprocess.run([sys.executable, alone, "--hook"], input="{}", capture_output=True, text=True, cwd=d,
                              env=env)
        check("missing hook part: the hook blocks (exit 2)", hook.returncode == 2)
        os.remove(os.path.join(d, "check_content_finders.py"))
        hook = subprocess.run([sys.executable, alone, "--hook"], input="{}", capture_output=True, text=True, cwd=d,
                              env=env)
        check("missing finders part: the hook blocks (exit 2)", hook.returncode == 2)
        os.remove(os.path.join(d, "check_content_scan.py"))
        imp = subprocess.run([sys.executable, "-c", "try:\n import check_content\nexcept ImportError:\n print('raised')"],
                             capture_output=True, text=True, cwd=d, env=env)
        check("missing parts: an importer gets ImportError, not an exit", imp.stdout.strip() == "raised")


def run(check, kit_scripts):
    """Run the cases of this file.

    Args:
        check: prints one result line and remembers a failure (label, good).
        kit_scripts: the folder of the scripts under test (with no local module).
    """
    with tempfile.TemporaryDirectory() as d:
        case_in_process(check, d)
        case_cli(check, d, kit_scripts)
    case_missing_parts(check, kit_scripts)
