#!/usr/bin/env python3
"""Check the steps that a person reads and acts on (AGENTS.md "Instructions people follow"; the steps to write them:
.claude/skills/instructions/SKILL.md). It checks only what a script can measure; the fresh-reader test checks the rest.

Inputs:  the files that the `.check` lines `audit-instructions: <glob>` name (git-tracked files; `**` matches any
         folders), or the files named on the command line; a project's own module scripts/check_instructions_local.py.
What a step is: an item of a numbered list (Markdown `1.` or `1)`, HTML `<ol><li>`) in a list where at least half the
         items start with an action verb or a condition word (a numbered list of facts is not a procedure). A step
         with its own numbered list is a lead-in: its sub-items are the actions on one screen.
Findings (FILE:LINE: message; each one fails the check):
    long       a step over STEP_WORDS words, or a sentence over SENTENCE_WORDS words (ASD-STE100: 20 in a procedure)
    actions    two or more actions in one step (a lead-in with numbered actions on one screen is allowed)
    pointer    a pointer to another file, step or section ("see step 3", "as above", a link to a local file)
    vague      a vague word ("appropriate", "as needed", "should", "some", ...)
    wait       the step names a wait but not the state to wait for ("Wait until <what the person sees>")
    next       the step does not say what the person sees next ("You see ...", "The window ... opens")
    cue        the step does not say whether to wait, go on or note a value
Text in `code`, **bold** or "quotes" (the exact thing on the screen, or the exact text to type) counts as one word
and is not read for verbs, vague words or pointers.
A project's own module (optional; a module that cannot be loaded fails the check) can define:
    ACTION_VERBS, VAGUE, POINTERS   more verbs, and more regular expressions (lower-case text) for the two lists
    LIMITS                          {"step_words": n, "sentence_words": n}: only lower than the kit's values
    steps(path, text)               the steps of a file type the kit does not read: [(line, text, kind)], kind is
                                    "step", "lead" or "action"; None = the kit's parser
    extra_checks(path, line, text)  more findings for one step, as a list of messages
Usage:   python3 scripts/check_instructions.py [FILE ...]   check the files (default: the `.check` globs)
         python3 scripts/check_instructions.py --hook       Claude Code PreToolUse hook (.claude/settings.json): blocks a
                                                            Write or Edit of a matched file until this session loaded
                                                            the instructions skill (read from the transcript)
         python3 scripts/check_instructions.py --test       self-test (cases: scripts/check_instructions_test.py)
Parts:   scripts/check_instructions_steps.py (the step reader and the step measures; its names are re-exported here).
Exit 0 and "INSTRUCTIONS PASS" when there is no finding; 1 with the findings; 2 from --hook to block.
Prevents: a step that a person follows has two actions, a vague word, a pointer or no next state, so the reader cannot do it right the first time
Network: none (it runs local git read commands).
Writes:  none; --hook without a readable transcript writes one marker file per session in .git/ (then it blocks
         only the first write of that session: a host with no transcript gets a reminder, not a proof).
Credentials: none.
"""
import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_settings  # noqa: E402 - the one reader of `.check` settings
# scripts/check_instructions_steps.py: the step reader and measures (kept apart, docs/code-standard.md C4).
from check_instructions_steps import (  # noqa: E402,F401 - every name is re-exported: other scripts read them here
    ACTION_VERBS, CLAUSES, CUE, FENCE, ITEM, LEAD_SEP, LEAD_WORDS, LOCAL_LINK, NEXT_STATE, NOT_ACTION, POINTERS, SEEN,
    SENTENCE_WORDS, SENTENCES, STEP_WORDS, SUFFIXES_HTML, TOKEN, VAGUE, WAIT_STATE, WAIT_WORDS, WORD, _ListParser,
    count_actions, first_word, html_items, markdown_items, plain, procedure_steps, step_findings)

LOCAL = "scripts/check_instructions_local.py"
SKILL = ".claude/skills/instructions/SKILL.md"


def glob_regex(pattern):
    """A regular expression for a path glob: `**/` any folders (or none), `**` anything, `*` and `?` inside a name.

    Args:
        pattern: the glob, relative to the repo root, with `/` between folders.

    Returns:
        A compiled regular expression that matches a whole path.
    """
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


def globs_of(root):
    """The `audit-instructions:` globs of the repo's `.check` (ValueError when a setting line is not valid)."""
    return check_settings.audit_settings(check_settings.pairs(check_settings.read(root, check_settings.CHECK)))["instructions"]


def matches(rel, globs):
    """True when the repo-relative path `rel` matches one of the globs."""
    return any(glob_regex(g).match(rel) for g in globs)


def tracked(root, globs):
    """The git-tracked files of the repo that match the globs, sorted.

    Args:
        root: the repo root.
        globs: the `audit-instructions:` globs.

    Returns:
        Repo-relative paths.
    """
    out = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], capture_output=True, text=True, check=True).stdout
    return sorted(p for p in out.split("\0") if p and matches(p, globs))


def load_local(root):
    """The project's own module (LOCAL), or None when it does not exist. An error in the module goes up: it fails."""
    path = root / LOCAL
    if not path.is_file():
        return None
    spec = importlib.util.spec_from_file_location("check_instructions_local", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_rules(local):
    """The lists and limits in force: the kit's, with the project's additions and lower limits.

    Args:
        local: the project's module, or None.

    Returns:
        A dict: verbs, vague, pointers, step_words, sentence_words, steps (a function or None), extra (a function or None).
    """
    limits = dict(getattr(local, "LIMITS", {}) or {})
    unknown = set(limits) - {"step_words", "sentence_words"}
    if unknown:
        raise ValueError(f"{LOCAL}: LIMITS has unknown keys: {', '.join(sorted(unknown))}")
    return {"verbs": ACTION_VERBS | set(getattr(local, "ACTION_VERBS", ())),
            "vague": VAGUE + list(getattr(local, "VAGUE", ())), "pointers": POINTERS + list(getattr(local, "POINTERS", ())),
            "step_words": min(STEP_WORDS, int(limits.get("step_words", STEP_WORDS))),
            "sentence_words": min(SENTENCE_WORDS, int(limits.get("sentence_words", SENTENCE_WORDS))),
            "steps": getattr(local, "steps", None), "extra": getattr(local, "extra_checks", None)}


def check_file(path, text, rules):
    """The findings of one file, as "PATH:LINE: message" lines.

    Args:
        path: the path to print (repo-relative).
        text: the file's text.
        rules: the lists and limits in force (load_rules).

    Returns:
        A list of finding lines.
    """
    steps = rules["steps"](path, text) if rules["steps"] else None
    if steps is None:
        items = html_items(text) if path.lower().endswith(SUFFIXES_HTML) else markdown_items(text)
        steps = procedure_steps(items, rules["verbs"])
    out = []
    for line, raw, kind in steps:
        found = step_findings(raw, kind, rules) + (list(rules["extra"](path, line, raw)) if rules["extra"] else [])
        out += [f"{path}:{line}: {msg}" for msg in found]
    return out


def run_check(root, names):
    """Check the named files, or the files the `.check` globs match. Prints the findings and a last line.

    Args:
        root: the repo root.
        names: file paths from the command line (may be empty).

    Returns:
        The exit code: 0 with no finding, 1 otherwise.
    """
    try:
        local = load_local(root)
        rules = load_rules(local)
        files = list(names) or tracked(root, globs_of(root))
    except Exception as err:  # noqa: BLE001 - a broken setting or module fails the check, never skips it
        print(f"INSTRUCTIONS FAIL: {err}")
        return 1
    if not files:
        print("INSTRUCTIONS PASS: no instruction files (name them with `audit-instructions: <glob>` lines in .check)")
        return 0
    findings = []
    for rel in files:
        findings += check_file(rel, (root / rel).read_text(encoding="utf-8", errors="replace"), rules)
    print("\n".join(findings + [f"INSTRUCTIONS {'FAIL' if findings else 'PASS'}: {len(findings)} findings in {len(files)} files"]))
    return 1 if findings else 0


def skill_loaded(transcript):
    """True when the session transcript (Claude Code JSONL) shows a load of the instructions skill after its last
    compaction: a Skill tool call for "instructions", or a Read of SKILL with no line limit.

    Args:
        transcript: the path of the transcript file.

    Returns:
        True or False; OSError when the file cannot be read.
    """
    loaded = False
    with open(transcript, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "compact_boundary" in line and '"subtype"' in line:
                loaded = False
                continue
            if "instructions" not in line or '"tool_use"' not in line:
                continue
            try:
                content = json.loads(line).get("message", {}).get("content", [])
            except (ValueError, AttributeError):
                continue
            for part in content if isinstance(content, list) else []:
                if not isinstance(part, dict) or part.get("type") != "tool_use":
                    continue
                args = part.get("input") or {}
                if part.get("name") == "Skill" and str(args.get("skill", "")).split(":")[-1] == "instructions":
                    loaded = True
                elif (part.get("name") == "Read" and str(args.get("file_path", "")).endswith(SKILL)
                      and not args.get("limit") and not args.get("offset")):
                    loaded = True
    return loaded


def hook_target(event):
    """The file that a Write, Edit, MultiEdit or NotebookEdit call changes.

    Args:
        event: the hook event (tool_name, cwd, tool_input).

    Returns:
        (repo root, repo-relative path), or None for another tool or a file outside a repo.
    """
    args = event.get("tool_input") or {}
    target = args.get("file_path") or args.get("notebook_path")
    if event.get("tool_name") not in ("Write", "Edit", "MultiEdit", "NotebookEdit") or not target:
        return None
    cwd = Path(event.get("cwd") or ".")
    top = subprocess.run(["git", "-C", str(cwd), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if top.returncode != 0:
        return None
    root = Path(top.stdout.strip()).resolve()
    path = (cwd / target).resolve()
    try:
        return root, path.relative_to(root).as_posix()
    except ValueError:
        return None


def run_hook(stream):
    """The PreToolUse hook: exit 2 (block) for a change to a matched file before the skill is loaded.

    Args:
        stream: the hook input (JSON).

    Returns:
        The exit code: 0 lets the call run, 2 blocks it (the reason goes to stderr).
    """
    try:
        event = json.load(stream)
        found = hook_target(event)
        if found is None or found[1] == check_settings.CHECK:
            return 0  # `.check` itself is never blocked here, so a broken setting line can be fixed
        root, rel = found
    except Exception as err:  # noqa: BLE001 - any error blocks: the hook fails closed
        print(f"BLOCKED by scripts/check_instructions.py --hook: {err}", file=sys.stderr)
        return 2
    try:
        globs = globs_of(root)
    except ValueError as err:  # a broken `.check` line, or a `.check` that is not UTF-8: scripts/check.sh fails on it; it must not block every write
        print(f"WARN scripts/check_instructions.py --hook: {err}", file=sys.stderr)
        return 0
    except Exception as err:  # noqa: BLE001 - `.check` cannot be read: block (fail closed)
        print(f"BLOCKED by scripts/check_instructions.py --hook: {err}", file=sys.stderr)
        return 2
    if not matches(rel, globs):
        return 0
    try:
        if skill_loaded(event.get("transcript_path") or ""):
            return 0
    except OSError:  # no transcript: block the first write of this session only, and leave a marker
        marker = root / ".git" / f"instructions-hook-{re.sub(r'[^A-Za-z0-9_-]', '', str(event.get('session_id', ''))) or 'none'}"
        if marker.exists():
            return 0
        marker.touch()
    print(f"BLOCKED: {rel} holds instructions that a person follows (.check: audit-instructions). Load the skill "
          f"`instructions` in full first: the Skill tool with skill \"instructions\", or Read {SKILL} with no line limit. "
          "Then write the text again.", file=sys.stderr)
    return 2


def main():
    """Parse the command line and run the check, the hook or the self-test.

    Returns:
        The exit code.
    """
    ap = argparse.ArgumentParser(description="Check the steps that a person follows (AGENTS.md \"Instructions people follow\").")
    ap.add_argument("files", nargs="*", help="files to check (default: the audit-instructions globs of .check)")
    ap.add_argument("--hook", action="store_true", help="the Claude Code PreToolUse hook (reads the event on stdin)")
    ap.add_argument("--test", action="store_true", help="self-test")
    args = ap.parse_args()
    if args.hook:
        return run_hook(sys.stdin)
    if args.test:
        import check_instructions_test
        return check_instructions_test.run()
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    root = Path(top.stdout.strip() or ".").resolve()
    return run_check(root, [os.path.relpath(Path(n).resolve(), root) for n in args.files])


if __name__ == "__main__":
    sys.exit(main())
