#!/usr/bin/env python3
"""The block lists of scripts/check.sh that are not content patterns: the git commands and file reads that
.claude/settings.json must deny, and the template placeholders that must not stay in a project.

One home for each list: .claude/settings.json holds a copy of DENY because Claude Code reads only that file, and
`--settings` (run by scripts/check.sh) fails when a rule is missing there. scripts/sync_baseline.py reads DENY for a
project's settings. The placeholder pattern serves first_use_check.py, session_checkin.sh, check.sh, bootstrap.sh
and sync_baseline.py.

Usage:
    python3 scripts/check_blocks.py --settings              # .claude/settings.json denies every rule in DENY; exit 1 if not
    python3 scripts/check_blocks.py --placeholders FILE...  # print FILE:LINE for each {{PLACEHOLDER}}; exit 1 if any
    python3 scripts/check_blocks.py --placeholders          # the same for every tracked text file (not the kit's own tools)
    python3 scripts/check_blocks.py --test                  # self-test; prints BLOCKS TEST PASS
Input: the files named, or the repo at the current folder. Output: findings on stdout. Standard library only.
Prevents: .claude/settings.json lacks a deny rule for a destructive git command or a protected file read, or a template placeholder stays in a project
Network: none.
Writes: none (the self-test writes temporary files only).
Credentials: none.
"""
import json
import pathlib
import re
import subprocess
import sys
import tempfile

# Git commands that can lose work, and reads of key files. scripts/git-hooks/pre-push blocks the push forms for
# every git client; these rules stop the local forms in Claude Code. scripts/worker_guard.py parses the same
# commands for the worker and reviewer subagents. Tags: only the Release Manager (the Maintainer, 2026-11-25).
DENY = [
    "Bash(git push --force*)", "Bash(git push -f*)", "Bash(git push * --force*)", "Bash(git push * -f*)",
    "Bash(git reset --hard*)", "Bash(git clean*)", "Bash(*--no-verify*)", "Bash(git *core.hooksPath*)",
    "Bash(git * push*--force*)", "Bash(git * push* -f*)", "Bash(git -* reset --hard*)", "Bash(git -* clean*)",
    "Bash(git stash*)", "Bash(git checkout -- *)", "Bash(git restore *)", "Bash(git branch -D*)",
    "Bash(git *hookspath*)", "Bash(git *HOOKSPATH*)", "Bash(git * stash*)", "Bash(git * restore *)",
    "Bash(git * branch -D*)", "Bash(git * checkout -- *)", "Bash(git checkout .*)", "Bash(git * checkout .*)",
    "Bash(git checkout -f*)", "Bash(git switch -f*)", "Bash(git *--discard-changes*)",
    "Bash(git *branch --delete --force*)", "Bash(git tag*)", "Bash(git *push*--follow-t*)", "Bash(git *push*--mirror*)",
    "Bash(git -* tag *)", "Bash(git *update-ref*refs/tags/*)", "Bash(git *push*--tags*)", "Bash(git *push*refs/tags/*)",
    "Read(./.env)", "Read(./.env.*)", "Read(./**/*.pem)", "Read(./**/*.key)", "Read(./**/id_rsa*)",
    "Read(./**/id_ed25519*)",
]
PLACEHOLDER = re.compile(r"\{\{[A-Z_]+\}\}")
# Kit tools and docs that name placeholders on purpose (they fill or explain them).
PLACEHOLDER_TOOLS = {"scripts/bootstrap.sh", "scripts/session_checkin.sh", "scripts/sync_baseline.py",
                     "scripts/first_use_check.py", "scripts/drift.py", "scripts/check.sh", "scripts/check_blocks.py",
                     "README.md", "docs/KIT_HANDOFF.md"}


def missing_deny(settings_path):
    """The DENY rules that this settings.json does not deny (all of them when the file is missing or broken)."""
    try:
        deny = json.loads(pathlib.Path(settings_path).read_text())["permissions"]["deny"]
    except (OSError, ValueError, KeyError, TypeError):
        return list(DENY)
    return [r for r in DENY if not isinstance(deny, list) or r not in deny]


def placeholders(paths):
    """(path, line number, placeholder) for each {{PLACEHOLDER}} in these files; a file that is not text is skipped.

    Args:
        paths: the files to read.

    Returns:
        A list of (path, line number, placeholder).
    """
    found = []
    for p in paths:
        try:
            text = pathlib.Path(p).read_text()
        except (OSError, UnicodeDecodeError):
            continue
        for n, line in enumerate(text.splitlines(), 1):
            found += [(str(p), n, m.group()) for m in PLACEHOLDER.finditer(line)]
    return found


def tracked(root="."):
    """The tracked files of the repo at root, without the kit tools that name placeholders on purpose."""
    r = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, text=True)
    return [str(pathlib.Path(root) / f) for f in r.stdout.split("\0") if f and f not in PLACEHOLDER_TOOLS]


def self_test():
    """Check the deny comparison and the placeholder scan on temporary files.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    fails = []

    def ok(label, good):
        """Print one result line and remember a failure."""
        print(("ok   " if good else "FAIL ") + label)
        if not good:
            fails.append(label)
    with tempfile.TemporaryDirectory() as d:
        s = pathlib.Path(d, "settings.json")
        ok("no settings file: every rule is missing", missing_deny(s) == DENY)
        s.write_text("{not json")
        ok("a broken settings file: every rule is missing", missing_deny(s) == DENY)
        s.write_text(json.dumps({"permissions": {"deny": DENY + ["Bash(own rule*)"]}}))
        ok("all rules and a project rule: none missing", missing_deny(s) == [])
        s.write_text(json.dumps({"permissions": {"deny": DENY[1:]}}))
        ok("one rule removed: it is reported", missing_deny(s) == DENY[:1])
        s.write_text(json.dumps({"permissions": {"deny": "x"}}))
        ok("deny of a wrong type: every rule is missing", missing_deny(s) == DENY)
        f = pathlib.Path(d, "a.md")
        f.write_text("# {" + "{PROJECT_NAME}}\nplain {" + "{...}} and {" + "{lower}}\nby {" + "{OWNER}}\n")
        ok("placeholders: found with line numbers", [(n, v) for _, n, v in placeholders([f])]
           == [(1, "{" + "{PROJECT_NAME}}"), (3, "{" + "{OWNER}}")])
        pathlib.Path(d, "b.bin").write_bytes(b"\xff\xfe\x00{" + b"{X}}")
        ok("placeholders: a file that is not text is skipped",
           placeholders([pathlib.Path(d, "b.bin"), pathlib.Path(d, "none")]) == [])
    here = pathlib.Path(__file__).resolve().parent.parent / ".claude/settings.json"
    if here.is_file():
        ok("this repo's settings.json denies every rule", missing_deny(here) == [])
    print("BLOCKS TEST " + ("FAIL" if fails else "PASS"))
    return 1 if fails else 0


def main(argv):
    """Run the mode the command line names; return the exit code.

    Args:
        argv: the command-line arguments, without the script name.

    Returns:
        The exit code: 0 pass, 1 fail, 2 for a usage error.
    """
    if argv[:1] == ["--test"]:
        return self_test()
    if argv[:1] == ["--settings"]:
        gone = missing_deny(".claude/settings.json")
        for r in gone:
            print("FAIL  .claude/settings.json does not deny: " + r)
        print(f"BLOCKS {'FAIL' if gone else 'PASS'}: {len(DENY) - len(gone)} of {len(DENY)} deny rules in "
              ".claude/settings.json")
        return 1 if gone else 0
    if argv[:1] == ["--placeholders"]:
        found = placeholders(argv[1:] or tracked())
        for path, n, val in found:
            print(f"{path}:{n}: {val}")
        return 1 if found else 0
    print(__doc__.split("Usage:")[1].split("Input:")[0], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
