#!/usr/bin/env python3
"""Self-test cases of scripts/bump_lock.py, kept apart so each file stays under the 450-line cap (fleet v2 DEC 6).

Run: python3 scripts/bump_lock.py --test (it imports this file and calls run with itself; tests/run.sh runs it).
What it checks, with no network and no git: the release-lock checks, the order of the bump steps in a temp folder,
the decision row text and the git timeout.
Network: none.
Writes: a temp folder only (removed at the end).
Credentials: none.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

bl = None   # the bump_lock module under test; set by run()


def release_cases():
    """Check check_release and the tag pattern against fixed good and bad cases.

    Returns:
        A tuple (cases, fails).
    """
    lock = {"repo": "rhope-ops/RADE"}
    c, h = "a" * 40, "b" * 64
    good = {"repo": "rhope-ops/RADE", "commit": c, "engine": "engine/x.py", "files": {"engine/x.py": h}}
    cases = [
        (good, c, 0),
        (dict(good, repo="other/RADE"), c, 1),
        (good, "c" * 40, 1),
        (good, "", 1),
        (dict(good, commit="abc"), "abc", 1),
        (dict(good, engine="engine/y.py"), c, 1),
        (dict(good, files={"engine/x.py": h, "../etc/passwd": h}), c, 1),
        (dict(good, files={"engine/x.py": "zz"}), c, 1),
        (dict(good, files={}), c, 1),
    ]
    fails = sum(1 for rel, tagged, want in cases if bool(bl.check_release(rel, lock, tagged)) != bool(want))
    fails += sum(1 for t in ("engine-v3", "engine-v1234") if not re.fullmatch(bl.TAG_RE, t))
    fails += sum(1 for t in ("engine-v", "x;id", "engine-v3 ", "v3", "engine-v12345") if re.fullmatch(bl.TAG_RE, t))
    return len(cases) + 7, fails


def fake_build(rel, seen, gov, build_ok, crash):
    """Fake traced build for order_case: records the lock and row state, fakes bundle and task script writes, then fails.

    Args:
        rel: the fake release lock.
        seen: the dict that receives the "lock" and "row" observations.
        gov: the task script folder.
        build_ok: False makes the build stop with a FAIL message.
        crash: None, "error" or "interrupt".

    Returns:
        The lock's file set. Raises RuntimeError ("error"), KeyboardInterrupt ("interrupt") or SystemExit (build_ok False).
    """
    seen["lock"] = json.load(open(bl.LOCK)).get("commit") == rel["commit"]
    seen["row"] = "bump_lock" in open(bl.DECISIONS).read()
    open(os.path.join(bl.PASTE, "c.ps1"), "w").write("new bundle")
    open(os.path.join(bl.PASTE, "c.ps1.sha256.json"), "w").write("{}")   # engine-v21 on: the stored hash beside it
    open(os.path.join(gov, "t.ps1"), "w").write("new task script")   # a task script the build made
    if crash == "error":
        raise RuntimeError("fake build error")
    if crash == "interrupt":
        raise KeyboardInterrupt()
    if not build_ok:
        sys.exit("FAIL fake build")
    return set(rel["files"])


def order_case(name, build_ok, check_ok, rel, crash=None):
    """Run one apply_bump case in the temp folder that order_cases set up (fake build, checks and revision raise).

    Args:
        name: the case name; "pass" expects success, any other a stop.
        build_ok: whether the fake build passes.
        check_ok: whether the fake checks pass.
        rel: the fake release lock.
        crash: None, or "error" / "interrupt": the fake build raises a plain error or KeyboardInterrupt.

    Returns:
        True when the case behaved as expected.
    """
    gov = os.path.dirname(bl.PASTE)
    for n in os.listdir(bl.PASTE):   # each case starts from one old bundle only
        os.remove(os.path.join(bl.PASTE, n))
    for n in os.listdir(gov):   # and from no task script
        if n.endswith(".ps1"):
            os.remove(os.path.join(gov, n))
    open(bl.LOCK, "w").write('{"commit": "old"}')
    open(os.path.join(bl.PASTE, "b.ps1"), "w").write("old bundle")
    for p in (bl.BUNDLES, bl.GO):   # the raise edits these two; a failed run must put them back
        open(p, "w").write("old")
    open(bl.DECISIONS, "w").write("| Date | What | By | Where |\n|---|---|---|---|\n")
    seen = {}

    def build(root, engine):
        """Fake traced build: see fake_build."""
        return fake_build(rel, seen, gov, build_ok, crash)

    def revise():
        """Fake revision raise: the old bundle b.ps1 leaves and the next revision c.ps1 comes."""
        os.remove(os.path.join(bl.PASTE, "b.ps1"))
        open(os.path.join(bl.PASTE, "c.ps1"), "w").write("raised bundle")
        for p in (bl.BUNDLES, bl.GO):
            open(p, "w").write("raised")

    def checks():
        """Fake checks: the row must not exist yet; fails when the case says so."""
        seen["row_at_checks"] = "bump_lock" in open(bl.DECISIONS).read()
        if not check_ok:
            sys.exit("FAIL fake checks")

    try:
        bl.apply_bump(rel, "engine-v9", {"commit": "old"}, 5, "2026-01-01", build, checks, revise)
        stopped = False
    except (SystemExit, RuntimeError, KeyboardInterrupt):
        stopped = True
    row = open(bl.DECISIONS).read().count(bl.BY)
    kept = [open(p).read() for p in (bl.BUNDLES, bl.GO)]
    good = (seen.get("lock") is True and seen.get("row") is False and seen.get("row_at_checks", False) is False
            and stopped == (name != "pass"))
    return order_verdict(name, good, row, kept, gov)


def order_verdict(name, good, row, kept, gov):
    """Compare the folder after one apply_bump case with what the case name expects.

    Args:
        name: the case name ("pass" expects the new state, any other the old one).
        good: whether the order checks held.
        row: the number of DECISIONS rows written.
        kept: the contents of the bundle definitions and go.md.
        gov: the task script folder (the fake build writes t.ps1 there).

    Returns:
        True when the folder is as expected.
    """
    task = os.path.exists(os.path.join(gov, "t.ps1"))
    if name == "pass":
        return (good and row == 1 and json.load(open(bl.LOCK))["serial"] == 5 and task and kept == ["raised"] * 2
                and sorted(os.listdir(bl.PASTE)) == ["c.ps1", "c.ps1.sha256.json"])
    return (good and row == 0 and open(bl.LOCK).read() == '{"commit": "old"}' and not task and kept == ["old"] * 2
            and open(os.path.join(bl.PASTE, "b.ps1")).read() == "old bundle" and os.listdir(bl.PASTE) == ["b.ps1"])


def cache_case():
    """Test without_module_caches: the cache copy of a listed module leaves the trace (also its temporary name); the
    cache of a module the lock does not list, and any other file under __pycache__, stay.

    Returns:
        True when the case passes.
    """
    files = {"engine/a.py": "", "engine/b.py": "", "top.py": ""}
    seen = {"engine/a.py", "engine/__pycache__/b.cpython-313.pyc", "engine/__pycache__/b.cpython-313.pyc.139770291932016",
            "__pycache__/top.cpython-311.pyc", "engine/__pycache__/other.cpython-313.pyc", "engine/__pycache__/x.txt",
            "assets/__pycache__/b.cpython-313.pyc"}
    return bl.without_module_caches(seen, files) == {"engine/a.py", "engine/__pycache__/other.cpython-313.pyc",
                                                  "engine/__pycache__/x.txt", "assets/__pycache__/b.cpython-313.pyc"}


def raise_case():
    """Test raise_bundle_revisions itself (not a fake) in a temp folder with a fake main: the bundle that main has gets
    the next revision in the round definitions and in its go.md link, and its old file and stored hash file leave; the
    bare file name in other go.md text stays.

    Returns:
        True when the case passes.
    """
    import tempfile
    old, new = "scripts/gov/paste/90161Z-R01-round-r6.ps1", "scripts/gov/paste/90161Z-R01-round-r7.ps1"
    with tempfile.TemporaryDirectory() as t:
        os.makedirs(os.path.join(t, "scripts", "gov", "paste"))
        with open(os.path.join(t, "scripts", "paste_bundles.json"), "w") as f:
            json.dump({"bundles": [{"out": old, "round": "R01", "title": "Round R01 r6: on main"}]}, f, indent=2)
        for rel_path, text in ((old, "built on main"), (old + ".sha256.json", "{}"), ("go.md", "link .../%s\nDone: 90161Z-R01-round-r6.ps1 ran\n" % old)):
            with open(os.path.join(t, rel_path), "w") as f:
                f.write(text)
        moved = bl.raise_bundle_revisions(t, {old: b"built on main"}.get)
        left = sorted(os.listdir(os.path.join(t, "scripts", "gov", "paste")))
        go = open(os.path.join(t, "go.md")).read()
        out = json.load(open(os.path.join(t, "scripts", "paste_bundles.json")))["bundles"][0]
    return (moved == [(old, new)] and left == [] and out == {"out": new, "round": "R01", "title": "Round R01 r7: on main"}
            and go == "link .../%s\nDone: 90161Z-R01-round-r6.ps1 ran\n" % new)


def order_cases():
    """Test the order of apply_bump with fake build, check and raise functions in a temp folder (no network, no git).
    Cases: the lock is on disk during the build; no DECISIONS row before the checks pass; a failing build or check
    restores the old lock and bundle, deletes the raised bundle and writes no row; a pass keeps the raised bundle and
    writes one row whose By column names this script.

    Returns:
        A tuple (cases, fails).
    """
    import tempfile
    saved = (bl.LOCK, bl.DECISIONS, bl.PASTE, bl.BUNDLES, bl.GO)
    fails, cases = 0, 0
    rel = {"commit": "d" * 40, "engine": "engine/x.py", "files": {"engine/x.py": "e" * 64}}
    with tempfile.TemporaryDirectory() as t:
        bl.LOCK, bl.DECISIONS, bl.PASTE = (os.path.join(t, "lock.json"), os.path.join(t, "DECISIONS.md"), os.path.join(t, "paste"))
        bl.BUNDLES, bl.GO = os.path.join(t, "bundles.json"), os.path.join(t, "go.md")
        os.mkdir(bl.PASTE)
        try:
            for name, build_ok, check_ok, *crash in (("pass", True, True), ("build fails", False, True), ("checks fail", True, False),
                                          ("build error", True, True, "error"), ("interrupt", True, True, "interrupt")):
                good = order_case(name, build_ok, check_ok, rel, *crash)
                print("BUMPLOCK order %s: %s" % (name, "ok" if good else "FAIL"))
                cases, fails = cases + 1, fails + (not good)
        finally:
            bl.LOCK, bl.DECISIONS, bl.PASTE, bl.BUNDLES, bl.GO = saved
    for label, case in (("raise itself", raise_case), ("trace without module caches", cache_case)):
        good = case()
        print("BUMPLOCK %s: %s" % (label, "ok" if good else "FAIL"))
        cases, fails = cases + 1, fails + (not good)
    return cases, fails


def text_cases():
    """Test the row text and the git time limit (a fake subprocess.run that times out).

    Returns:
        A tuple (cases, fails).
    """
    fails = 0
    row = bl.decision_row("2026-01-01", "engine-v9", "abcdef0", 5)
    fails += not (row.count("\n") == 1 and row.count("|") == 5 and "| " + bl.BY + " |" in row and "PFM |" not in row)
    real = subprocess.run

    def slow(*a, **k):
        """Fake subprocess.run: reports the timeout it was given as expired."""
        raise subprocess.TimeoutExpired(a[0], k.get("timeout"))
    subprocess.run = slow
    try:
        bl.run_git(["ls-remote", "x"], "test")
        fails += 1
    except SystemExit as e:
        fails += not ("did not answer in %d seconds" % bl.GIT_TIMEOUT in str(e.code))
    finally:
        subprocess.run = real
    seen = {}
    subprocess.run = lambda *a, **k: seen.update(k) or subprocess.CompletedProcess(a[0], 0, "", "")
    try:
        bl.run_git(["fetch"], "test")
    finally:
        subprocess.run = real
    fails += seen.get("timeout") != bl.GIT_TIMEOUT
    return 3, fails


def guard_cases():
    """Test the https-only guard and the RADE_LOCAL_DIR offline read (a temp git clone with one tag; no network).

    Returns:
        A tuple (cases, fails).
    """
    fails = 0
    for url, ok in (("https://github.com/x", True), ("http://github.com/x", False), ("file:///etc/passwd", False),
                    ("ftp://github.com/x", False), ("https:///x", False)):
        try:
            bl.https_only(url)
            fails += not ok
        except SystemExit:
            fails += ok
    try:   # a redirect to plain http is refused before it is followed
        bl.HttpsRedirects().redirect_request(None, None, 302, "Found", {}, "http://example.invalid/x")
        fails += 1
    except SystemExit:
        pass
    old = os.environ.get("RADE_LOCAL_DIR")
    with tempfile.TemporaryDirectory() as t:
        git = ["git", "-C", t, "-c", "user.name=test", "-c", "user.email=test@example.invalid"]
        subprocess.run(["git", "init", "-q", t], check=True)
        subprocess.run(git + ["commit", "-q", "--allow-empty", "-m", "x"], check=True)
        subprocess.run(git + ["tag", "engine-v9"], check=True)
        head = subprocess.run(git + ["rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        with open(os.path.join(t, bl.RELEASE_FILE), "w", encoding="utf-8") as f:
            json.dump({"repo": "example/RADE", "commit": head}, f)
        os.environ["RADE_LOCAL_DIR"] = t
        try:
            fails += bl.tag_commit("engine-v9", "example/RADE") != head
            fails += bl.tag_commit("engine-v8", "example/RADE") != ""
            fails += bl.release_lock("engine-v9", "example/RADE").get("commit") != head
            os.remove(os.path.join(t, bl.RELEASE_FILE))
            try:
                bl.release_lock("engine-v9", "example/RADE")
                fails += 1
            except SystemExit:
                pass
        finally:
            if old is None:
                os.environ.pop("RADE_LOCAL_DIR", None)
            else:
                os.environ["RADE_LOCAL_DIR"] = old
    print("BUMPLOCK guard: %s" % ("ok" if not fails else "FAIL"))
    return 10, fails


def run(module):
    """Run every no-network self-test: release checks, the order of the bump steps, the row text and the git timeout.

    Args:
        module: the bump_lock module under test (scripts/bump_lock.py passes itself).

    Returns:
        1 when any case fails, else 0 (the BUMPLOCK line is printed).
    """
    global bl
    bl = module
    total = fails = 0
    for fn in (release_cases, order_cases, text_cases, guard_cases):
        n, f = fn()
        total, fails = total + n, fails + f
    print("BUMPLOCK cases=%d fails=%d" % (total, fails))
    return 1 if fails else 0
