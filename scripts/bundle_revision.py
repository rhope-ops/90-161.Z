#!/usr/bin/env python3
"""Bundle revisions: a round bundle that main already has never changes (the PFM, 2026-11-18: "raise the revision on
every rebuild"). The work computer may have any bundle on main, so a rebuilt bundle gets the next revision (r6 -> r7)
and a new file name; the old file leaves. Rule text: .claude/skills/round/SKILL.md section 4.

    python3 scripts/bundle_revision.py           # check: FAIL for each bundle on main whose bytes changed
    python3 scripts/bundle_revision.py --raise   # raise the revision of each bundle that main has (bump_lock.py uses it)
    python3 scripts/bundle_revision.py --test    # self-test with fake files (no git)

--raise changes only the working tree: in scripts/paste_bundles.json the "out" name and the "Round <id> r<N>" title
prefix, the bundle's path in its go.md link, and it deletes the old bundle file and its stored hash file. Rebuild afterwards
(python3 scripts/build_paste_bundles.py). It needs origin/main; fetch first.
Network: none (it runs local git read commands on origin/main; it does not fetch).
Writes: --raise only: scripts/paste_bundles.json, go.md, and deletes the old bundle and hash files; the check and --test write
nothing in the repo (--test uses a temp folder).
Credentials: none.
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = "scripts/paste_bundles.json"   # the round definitions; each bundle has "out", "round" and "title"
GO = "go.md"                            # the PFM's task page links an open round's bundle by file name
REV_RE = re.compile(r"-r(\d+)\.ps1$")   # the revision at the end of a bundle file name
HASH_EXT = ".sha256.json"               # the stored hash file the RADE engine writes beside a bundle (engine-v21 on)


def next_name(out):
    """Return a bundle path with its revision raised by 1.

    Args:
        out: a bundle path that ends in -r<N>.ps1, for example scripts/gov/paste/90161Z-R29a-round-r6.ps1.

    Returns:
        The same path with -r<N+1>.ps1; stops with a FAIL message when the path has no revision.
    """
    m = REV_RE.search(out)
    if not m:
        sys.exit("FAIL bundle name has no -r<N>.ps1 revision: " + out)
    return out[:m.start()] + "-r%d.ps1" % (int(m.group(1)) + 1)


def git_main_reader(root):
    """Make a reader for files on origin/main.

    Args:
        root: the repository folder.

    Returns:
        A function path -> bytes on origin/main, or None when main has no such file. Stops with a FAIL message when
        origin/main itself cannot be read (no fetch), so a missing ref never passes as "not on main".
    """
    if subprocess.run(["git", "rev-parse", "--verify", "-q", "origin/main"], cwd=root, capture_output=True).returncode:
        sys.exit("FAIL cannot read origin/main (run: git fetch origin main)")

    def read(path):
        """Return the bytes of one path on origin/main, or None when main does not have it."""
        r = subprocess.run(["git", "show", "origin/main:" + path], cwd=root, capture_output=True)
        return r.stdout if r.returncode == 0 else None
    return read


def bundles(root):
    """Read the bundle list from the round definitions.

    Args:
        root: the repository folder.

    Returns:
        The list of bundle dicts in scripts/paste_bundles.json.
    """
    return json.loads((Path(root) / CONFIG).read_text(encoding="utf-8"))["bundles"]


def changed_on_main(root, read_main):
    """Find each bundle that main has and that differs on disk (changed in place instead of a new revision).

    Args:
        root: the repository folder.
        read_main: a function path -> bytes on main, or None.

    Returns:
        A list of bundle paths that break the rule (empty = good).
    """
    bad = []
    for b in bundles(root):
        on_main = read_main(b["out"])
        disk = Path(root) / b["out"]
        if on_main is not None and (not disk.exists() or disk.read_bytes() != on_main):
            bad.append(b["out"])
    return bad


def raise_revisions(root, read_main):
    """Give every bundle that main has the next revision: new "out" name and title prefix in the round definitions,
    the new path in the bundle's go.md link, and the old bundle file and its stored hash file deleted. Text edits keep
    the files' layout.

    Args:
        root: the repository folder.
        read_main: a function path -> bytes on main, or None.

    Returns:
        A list of (old path, new path) pairs, one per raised bundle.
    """
    root = Path(root)
    cfg_text = (root / CONFIG).read_text(encoding="utf-8")
    go_path = root / GO
    go_text = go_path.read_text(encoding="utf-8") if go_path.exists() else None
    moved = []
    for b in bundles(root):
        old = b["out"]
        if read_main(old) is None:
            continue   # not on main yet: the work computer cannot have it, so it may change in place
        new = next_name(old)
        n = int(REV_RE.search(old).group(1))
        cfg_text = cfg_text.replace('"out": "%s"' % old, '"out": "%s"' % new)
        cfg_text = cfg_text.replace('"title": "Round %s r%d' % (b["round"], n), '"title": "Round %s r%d' % (b["round"], n + 1))
        if go_text is not None:
            go_text = go_text.replace(old, new)   # only the bundle's link (its path), not the bare file name in other text
        (root / old).unlink(missing_ok=True)
        (root / (old + HASH_EXT)).unlink(missing_ok=True)   # the stored hash of the old bundle leaves with it
        moved.append((old, new))
    (root / CONFIG).write_text(cfg_text, encoding="utf-8")
    if go_text is not None:
        go_path.write_text(go_text, encoding="utf-8")
    return moved


def self_test():
    """Check next_name, the check and the raise with fake files in a temp folder and a fake main (no git).

    Returns:
        1 when any case fails, else 0 (a BUNDLEREV line is printed).
    """
    fails = 0
    fails += next_name("p/90161Z-R30-round-r9.ps1") != "p/90161Z-R30-round-r10.ps1"
    with tempfile.TemporaryDirectory() as t:
        root = Path(t)
        (root / "scripts/gov/paste").mkdir(parents=True)
        cfg = {"bundles": [
            {"out": "scripts/gov/paste/90161Z-R01-round-r6.ps1", "round": "R01", "title": "Round R01 r6: on main"},
            {"out": "scripts/gov/paste/90161Z-R02-round-r1.ps1", "round": "R02", "title": "Round R02 r1: new"}]}
        (root / CONFIG).write_text(json.dumps(cfg, indent=2), encoding="utf-8")
        (root / GO).write_text("link .../scripts/gov/paste/90161Z-R01-round-r6.ps1\nDone: 90161Z-R01-round-r6.ps1 ran\n", encoding="utf-8")
        (root / ("scripts/gov/paste/90161Z-R01-round-r6.ps1" + HASH_EXT)).write_text("{}", encoding="utf-8")
        main = {"scripts/gov/paste/90161Z-R01-round-r6.ps1": b"built on main"}
        (root / "scripts/gov/paste/90161Z-R01-round-r6.ps1").write_bytes(b"built on main")
        (root / "scripts/gov/paste/90161Z-R02-round-r1.ps1").write_bytes(b"new round")
        read = main.get
        fails += changed_on_main(root, read) != []                       # same bytes as main: good
        (root / "scripts/gov/paste/90161Z-R02-round-r1.ps1").write_bytes(b"new round, changed")
        fails += changed_on_main(root, read) != []                       # a bundle main lacks may change
        (root / "scripts/gov/paste/90161Z-R01-round-r6.ps1").write_bytes(b"rebuilt in place")
        fails += changed_on_main(root, read) != ["scripts/gov/paste/90161Z-R01-round-r6.ps1"]   # the fault
        (root / "scripts/gov/paste/90161Z-R01-round-r6.ps1").unlink()
        fails += changed_on_main(root, read) != ["scripts/gov/paste/90161Z-R01-round-r6.ps1"]   # deleted: also a fault
        moved = raise_revisions(root, read)
        fails += moved != [("scripts/gov/paste/90161Z-R01-round-r6.ps1", "scripts/gov/paste/90161Z-R01-round-r7.ps1")]
        new = bundles(root)
        fails += [b["out"] for b in new] != ["scripts/gov/paste/90161Z-R01-round-r7.ps1", "scripts/gov/paste/90161Z-R02-round-r1.ps1"]
        fails += [b["title"] for b in new] != ["Round R01 r7: on main", "Round R02 r1: new"]
        # only the link changes: a bare file name in other text (a Done line) keeps the revision that ran
        fails += (root / GO).read_text(encoding="utf-8") != "link .../scripts/gov/paste/90161Z-R01-round-r7.ps1\nDone: 90161Z-R01-round-r6.ps1 ran\n"
        fails += (root / "scripts/gov/paste/90161Z-R01-round-r6.ps1").exists()
        fails += (root / ("scripts/gov/paste/90161Z-R01-round-r6.ps1" + HASH_EXT)).exists()   # its stored hash left too
        fails += changed_on_main(root, read) != []                       # after the raise: nothing on main changes
    print("BUNDLEREV cases=12 fails=%d" % fails)
    return 1 if fails else 0


def main(argv):
    """Run the mode the arguments name: check (no argument), --raise or --test.

    Args:
        argv: the command-line arguments after the script name.

    Returns:
        The exit code: 0 = pass, 1 = fail.
    """
    if argv == ["--test"]:
        return self_test()
    if argv == ["--raise"]:
        for old, new in raise_revisions(ROOT, git_main_reader(ROOT)):
            print("RAISED %s -> %s" % (old, Path(new).name))
        return 0
    if argv:
        sys.exit(__doc__)
    bad = changed_on_main(ROOT, git_main_reader(ROOT))
    for p in bad:
        print("FAIL %s is on main and changed: raise its revision (python3 scripts/bundle_revision.py --raise), "
              "then rebuild" % p)
    print("BUNDLEREV checked=%d changed-on-main=%d" % (len(bundles(ROOT)), len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
