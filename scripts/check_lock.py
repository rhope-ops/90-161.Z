#!/usr/bin/env python3
"""The kit lock of a project: `.check.lock` records which kit version the project was synced from and a SHA-256 of
each kit-owned file, so a change to a kit file inside a project is seen at once (scripts/check.sh fails).

A project changes its own things in AGENTS.md "Project rules" and "Commands", in `.check`, in
scripts/check.local.sh and in its own files. A change to a kit file is made in the kit and arrives by a sync
(scripts/sync_baseline.py in the kit writes the lock). When the Maintainer asks for a kit file that differs in one
project, `--relock FILE` records it as an override; every --verify run lists the overrides.

Usage:
    python3 scripts/check_lock.py --verify          # compare the files with .check.lock; exit 1 on a difference
    python3 scripts/check_lock.py --status          # one line: the kit version and commit this project is pinned to
    python3 scripts/check_lock.py --relock FILE...  # only on the Maintainer's request: accept these files as they are
    python3 scripts/check_lock.py --test            # self-test; prints LOCK TEST PASS
Input: the repo at the current folder (or --project DIR). Output: PASS, FAIL and WARN lines on stdout.
Writes: .check.lock (--relock only). Standard library only.
Prevents: a kit-owned file is changed inside a project without the Maintainer, or a project runs a kit version that no one can name
Network: none.
Credentials: none.
"""
import argparse
import hashlib
import json
import pathlib
import sys
import tempfile

LOCK = ".check.lock"
RULES = "AGENTS.md"
KIT_PART = RULES + " (kit sections)"  # the lock key for the kit's part of AGENTS.md
PROJECT_HEADINGS = ("## Commands", "## Project rules")  # these sections belong to the project


def sha(text):
    """SHA-256 of a text, as hex."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def kit_sections(text):
    """The kit's part of an AGENTS.md: every `## ` section before "## Project rules" except "## Commands". The
    header above the first section holds the project's own values, so it is not part of it.

    Args:
        text: the text of an AGENTS.md.

    Returns:
        The kit sections as one text.
    """
    out, keep = [], False
    for ln in text.splitlines():
        if ln.startswith("## "):
            if ln.strip() == "## Project rules":
                break
            keep = ln.strip() not in PROJECT_HEADINGS
        if keep:
            out.append(ln.rstrip())
    return "\n".join(out).strip() + "\n"


def file_hash(root, rel):
    """The hash of one locked entry as it is in the project now, or None when the file is missing."""
    path = pathlib.Path(root) / (RULES if rel == KIT_PART else rel)
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8", errors="replace")
    return sha(kit_sections(text) if rel == KIT_PART else text)


def kit_text_locked(root):
    """True when the kit's part of this project's AGENTS.md is the text its lock records and no override covers it:
    the kit checked those lines. A relocked kit part is the project's own text again, so it is not locked."""
    try:
        data = load(root)
    except ValueError:
        return False
    return (bool(data) and KIT_PART not in data.get("overrides", [])
            and data["files"].get(KIT_PART) == file_hash(root, KIT_PART))


def build(root, files, version, commit, overrides=()):
    """The lock data for these kit files as they are in the project now."""
    entries = {rel: file_hash(root, rel) for rel in [KIT_PART, *sorted(files)]}
    return {"kit": "archimedes_lever", "version": version, "commit": commit,
            "files": {k: v for k, v in entries.items() if v}, "overrides": sorted(overrides)}


def write(root, data):
    """Write .check.lock (sorted keys, so the same state gives the same file)."""
    (pathlib.Path(root) / LOCK).write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")


def load(root):
    """The lock data, or None when the project has no lock.

    Args:
        root: the repo root (a folder path).

    Returns:
        The lock data (a dict), or None when there is no lock file.

    Raises:
        ValueError: the file is broken (no "files" object, or "overrides" is not a list).
    """
    path = pathlib.Path(root) / LOCK
    if not path.is_file():
        return None
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or not isinstance(data.get("files"), dict):
        raise ValueError("no \"files\" object")
    if not isinstance(data.get("overrides", []), list):
        raise ValueError("\"overrides\" is not a list")
    return data


def changed(root, writes=None):
    """The locked kit files that are in the project now with text that differs from the lock, or that the lock lists
    as an override (the Maintainer's approved change: a sync would still overwrite it).

    Args:
        root: the repo root (a folder path).
        writes: the paths a sync is about to write; only these count (None: every locked file).

    Returns:
        A sorted list of lock keys; empty when the project has no lock or no such file exists (a missing file is not
        listed: a sync writes it again).

    Raises:
        ValueError: the lock is broken.
    """
    data = load(root) or {}
    over = set(data.get("overrides", []))
    out = []
    for rel, want in data.get("files", {}).items():
        got = file_hash(root, rel)
        if got is not None and (writes is None or (RULES if rel == KIT_PART else rel) in writes) and (rel in over or got != want):
            out.append(rel)
    return sorted(out)


def verify(root):
    """Return (lines, failed): one FAIL line for each kit file that is missing or differs from the lock.

    Args:
        root: the repo root (a folder path).

    Returns:
        (lines to print, True when a file is missing or differs).
    """
    try:
        data = load(root)
    except ValueError as e:
        return [f"FAIL  {LOCK} is not readable ({e}): sync again from the kit"], True
    if data is None:
        return [f"LOCK SKIP: no {LOCK} (the kit itself, or a project not synced since 2026-11-18)"], False
    out = []
    for rel, want in sorted(data["files"].items()):
        got = file_hash(root, rel)
        if got != want:
            out.append(f"FAIL  kit file {'missing' if got is None else 'changed in this project'}: {rel}")
    bad = bool(out)
    if bad:
        out.append("      A kit file is changed in the kit, then synced (scripts/sync_baseline.py there). This project's "
                   "own rules go in AGENTS.md \"Project rules\", its settings in .check, its tests in scripts/check.local.sh.")
    out += [f"WARN  kit file with a project override (the Maintainer's request): {rel}" for rel in data.get("overrides", [])]
    out.append(f"LOCK {'FAIL' if bad else 'PASS'}: {len(data['files'])} kit files, kit version {data.get('version', '?')} "
               f"({str(data.get('commit', '?'))[:7]})")
    return out, bad


def relock(root, files):
    """Accept the named kit files as they are now and list them as overrides; return the exit code.

    Args:
        root: the repo root (a folder path).
        files: the repo-relative paths of the kit files to accept.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    try:
        data = load(root)
    except ValueError as e:
        print(f"FAIL  {LOCK} is not readable ({e}): sync again from the kit")
        return 1
    if data is None:
        print(f"no {LOCK}: nothing to relock")
        return 1
    unknown = [f for f in files if f not in data["files"]]
    if unknown:
        print("not a locked kit file: " + ", ".join(unknown))
        return 1
    for f in files:
        data["files"][f] = file_hash(root, f)
    data["overrides"] = sorted(set(data.get("overrides", [])) | set(files))
    write(root, data)
    print("relocked (listed as overrides at each verify): " + ", ".join(files))
    return 0


def self_test():
    """Lock a temporary project, then change, remove and relock files.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    fails = []

    def ok(label, good):
        """Print one result line and remember a failure."""
        print(("ok   " if good else "FAIL ") + label)
        if not good:
            fails.append(label)
    agents = "# P\n\n- Owner: x\n\n## Git safety\n\n- Kit rule.\n\n## Commands\n\n- Test: a\n\n## Boundaries\n\n- B.\n\n## Project rules\n\n- Mine.\n"
    ok("kit sections: no header, no Commands, no Project rules",
       kit_sections(agents) == "## Git safety\n\n- Kit rule.\n\n## Boundaries\n\n- B.\n")
    with tempfile.TemporaryDirectory() as d:
        root = pathlib.Path(d)
        ok("no lock: skip, not a failure", verify(root) == ([f"LOCK SKIP: no {LOCK} (the kit itself, or a project not synced since 2026-11-18)"], False))
        (root / "scripts").mkdir()
        (root / "scripts/a.py").write_text("print(1)\n")
        (root / RULES).write_text(agents)
        write(root, build(root, ["scripts/a.py", "scripts/absent.py"], "1", "abcdef123"))
        lines, bad = verify(root)
        ok("a fresh lock passes and counts 2 entries", not bad and lines[-1].startswith("LOCK PASS: 2 kit files, kit version 1 (abcdef1)"))
        (root / RULES).write_text(agents.replace("- Test: a", "- Test: b").replace("- Mine.", "- Mine.\n- More.").replace("Owner: x", "Owner: y"))
        ok("a change to the header, Commands or Project rules passes", not verify(root)[1])
        ok("the kit text is the locked text", kit_text_locked(root))
        (root / RULES).write_text(agents.replace("- Kit rule.", "- Kit rule, weaker."))
        lines, bad = verify(root)
        ok("a changed kit rule fails and is named", bad and lines[0] == f"FAIL  kit file changed in this project: {KIT_PART}")
        ok("a changed kit rule: the kit text is not the locked text", not kit_text_locked(root))
        (root / RULES).write_text(agents)
        (root / "scripts/a.py").write_text("print(2)\n")
        ok("a changed kit script fails", verify(root)[0][0] == "FAIL  kit file changed in this project: scripts/a.py")
        ok("changed() lists the changed script, only when written", changed(root) == ["scripts/a.py"] and changed(root, {"b"}) == [])
        ok("relock of an unknown file is refused", relock(root, ["scripts/zzz.py"]) == 1)
        ok("relock accepts the file", relock(root, ["scripts/a.py"]) == 0)
        lines, bad = verify(root)
        ok("after a relock: passes, and the override is listed", not bad and any(l.startswith("WARN  kit file with a project override") for l in lines))
        ok("a relocked kit part is not locked text", relock(root, [KIT_PART]) == 0 and not verify(root)[1] and not kit_text_locked(root))
        (root / "scripts/a.py").unlink()
        ok("a missing kit file fails", verify(root)[0][0] == "FAIL  kit file missing: scripts/a.py")
        (root / LOCK).write_text("[]")
        ok("a broken lock fails", verify(root)[1])
    print("LOCK TEST " + ("FAIL" if fails else "PASS"))
    return 1 if fails else 0


def main():
    """Run the mode the command line names; return the exit code.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0], allow_abbrev=False)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--relock", nargs="+", metavar="FILE")
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--project", default=".")
    a = ap.parse_args()
    if a.test:
        return self_test()
    if a.relock:
        return relock(a.project, a.relock)
    if a.status:
        try:
            data = load(a.project)
        except ValueError:
            data = None
        print(f"kit:         version {data.get('version', '?')} ({str(data.get('commit', '?'))[:7]}), {len(data['files'])} locked files"
              if data else "kit:         no lock (not synced since 2026-11-18)")
        return 0
    lines, bad = verify(a.project)
    print("\n".join(lines))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
