"""The Claude Code PreToolUse hook of pii_guard.py (`python3 scripts/pii_guard.py --hook`).

Input: the hook event as JSON on stdin (tool_name, cwd, tool_input); the files the call names (file_path,
file_paths, files); .pii-guard of the project and the denylist.
Output: exit 0 lets the tool call run; exit 2 blocks it, and the masked findings go to stderr. Any error blocks.
Run: pii_guard.py imports it for --hook; not run alone.
"""
import json
import os
import signal
import subprocess
import sys

from pii_guard_scan import (UNKNOWN_PROFILE, git, is_option_line, load_allow, load_denylist, profile_of, scan_files,
                            scan_text)


HOOK_FILE_KEYS = ("file_path", "file_paths", "files")
HOOK_RECIPIENT_KEYS = ("to", "cc", "bcc")  # Gmail, top level: an address here is no finding


HOOK_MAX_BYTES = 8_000_000  # named files above this total block: the scan must end well inside the hook timeout
HOOK_BUDGET_S = 8  # seconds; the hook timeout in .claude/settings.json is 10


def hook_parts(tool_input, tool_name=""):
    """(texts, recipient texts, file paths, strict paths) of a PreToolUse tool_input. Every string value is scanned;
    the values of the file keys are also read as files (an Artifact or SendUserFile call sends a file's content).
    Recipient texts: the top-level recipient keys of a Gmail call only; they are scanned, but an email address there
    is no finding. Strict paths (file_path, file_paths) must exist: a named file the hook cannot read blocks."""
    texts, recipients, paths, strict = [], [], [], []
    mail = tool_name.startswith("mcp__Gmail__")

    def walk(v, key="", out=texts):
        """Add each string in v to out; key is the nearest named key above it (file keys win)."""
        if isinstance(v, str):
            out.append(v)
            if key in HOOK_FILE_KEYS:
                paths.append(v)
                if key != "files":
                    strict.append(v)
        elif isinstance(v, dict):  # inside a file key ({"published/path": "source" | {"from": "source"}}) keep the key
            for k, x in v.items():
                walk(x, key if key in HOOK_FILE_KEYS else k, out)
        elif isinstance(v, list):
            for x in v:
                walk(x, key, out)
    if isinstance(tool_input, dict):
        for k, x in tool_input.items():
            walk(x, k, recipients if mail and k in HOOK_RECIPIENT_KEYS else texts)
    else:
        walk(tool_input)
    return texts, recipients, paths, strict


def hook(stdin_text):
    """PreToolUse hook entry: any error blocks the call. Claude Code runs the call on any exit other than 2, so an
    exception (deep nesting, a wrong type) must not end the script with exit 1."""
    def too_slow(*_):  # exit here: an exception could escape between the except block and the finally block
        sys.stdout.flush()
        os.write(2, b"pii-guard hook: blocked: the scan took longer than its own time budget; fail closed.\n")
        os._exit(2)
    if hasattr(signal, "SIGALRM"):  # a hook timeout lets the call run: stop first, and block
        signal.signal(signal.SIGALRM, too_slow)
        signal.alarm(HOOK_BUDGET_S)
    try:
        return _hook(sys.stdin.read() if stdin_text is None else stdin_text)
    except BaseException as e:  # noqa: B036 - fail closed, whatever went wrong
        print(f"pii-guard hook: blocked: the scan failed ({e.__class__.__name__}); fail closed.", file=sys.stderr)
        return 2
    finally:
        if hasattr(signal, "SIGALRM"):
            signal.alarm(0)


def _hook(stdin_text):
    """PreToolUse hook. Exit 0 lets the call run; exit 2 blocks it and shows stderr to Claude. Bad input blocks
    (fail closed). Names are checked only when a denylist exists; the hook never blocks for a missing list."""
    try:
        event = json.loads(stdin_text)
        tool_input = event.get("tool_input", {})
        if not isinstance(tool_input, (dict, list, str)):
            raise ValueError("tool_input")
    except (ValueError, AttributeError) as e:
        print(f"pii-guard hook: blocked: cannot read the hook input ({e.__class__.__name__}); fail closed.", file=sys.stderr)
        return 2
    project = os.environ.get("CLAUDE_PROJECT_DIR") or ""
    cwd = event.get("cwd") or project or "."  # relative paths in the call resolve here
    if not isinstance(cwd, str):
        raise TypeError("cwd is not text")  # bad input blocks (hook() turns any error into exit 2)
    root = None  # the repo whose .pii-guard sets the tier: the project folder first, so a cwd outside it cannot
    for where in (project, cwd):  # drop the tier (fail-open)
        if where and os.path.isdir(where):
            try:
                root = git("rev-parse", "--show-toplevel", root=where).strip()
                break
            except (subprocess.CalledProcessError, FileNotFoundError, NotADirectoryError):
                pass
    root = root or project or cwd
    allow = load_allow(root)
    prof = profile_of(allow)
    if prof == "unknown":
        print("pii-guard hook: blocked: " + UNKNOWN_PROFILE, file=sys.stderr)
        return 2
    dod = prof == "dod"
    allow = {v for v in allow if not is_option_line(v)}
    deny = load_denylist()
    texts, recipients, paths, strict = hook_parts(tool_input, str(event.get("tool_name", "")))
    found = scan_text("\n".join(texts), "tool input", deny, allow, dod)
    found += [f for f in scan_text("\n".join(recipients), "mail recipients", deny, allow, dod) if f[2] != "email"]
    full = lambda p: os.path.join(cwd, os.path.expanduser(p))  # an absolute path stays as it is
    found += [(p, 0, "unscanned", "named file missing or unreadable") for p in strict
              if not (os.path.isfile(full(p)) and os.access(full(p), os.R_OK))]
    files = [full(p) for p in paths if os.path.isfile(full(p))]
    if sum(os.path.getsize(f) for f in files) > HOOK_MAX_BYTES:
        found.append(("named files", 0, "unscanned", f"over {HOOK_MAX_BYTES} bytes in total: send fewer files per call"))
    else:
        found += scan_files(files, root, deny, allow, dod, named=True)
    if not found:
        return 0
    tool = event.get("tool_name", "tool")
    for where, n, kind, val in found:
        print(f"pii-guard hook: {where}:{n}: {kind}: {val}", file=sys.stderr)
    print(f"pii-guard hook: blocked the {tool} call: {len(found)} finding(s) of personal data or secrets. Remove or "
          "mask them (never copy them elsewhere), then call again. A finding that is not personal data: tell the PFM; "
          "only the PFM adds an allow line to .pii-guard (.claude/skills/personal-data/SKILL.md).", file=sys.stderr)
    return 2

