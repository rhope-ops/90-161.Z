#!/usr/bin/env python3
"""Move scripts/rade.lock.json to a RADE engine release, locally (the PFM, 2026-11-15: no outside checks).

    python3 scripts/bump_lock.py engine-v3    # copy the release lock, rebuild, trace, check (docs/dev-setup.md "RADE engine")
    python3 scripts/bump_lock.py --test       # self-test of the release-lock checks (no network)

Steps: (1) download rade-engine.lock.json from the RADE release and check it (repo, commit = the tag's commit,
file paths, SHA-256 form); (2) write the lock with serial = main's + 1 (the build reads it from disk);
(3) give each round bundle that main already has the next revision (scripts/bundle_revision.py; the PFM, 2026-11-18:
"raise the revision on every rebuild"), then rebuild the round bundles under a trace of the files the engine opens, and fail when the trace differs from the
lock's file list; (4) run scripts/check.sh (tests/run.sh among them) and the PII guard against main's allow list;
(5) only after 3 and 4 pass, add the decision row to docs/DECISIONS.md (its By column names this script). On a failure
the old lock, round definitions, go.md and bundles are written back, new bundle files are deleted, and no row is added. Each git call to the network stops after 120 s.
It changes only the working tree: commit, push and the pull request stay with the session (AGENTS.md "Delivery").
Before you run it, check that no other open pull request changes the lock.
"""
import datetime
import json
import os
import re
import runpy
import subprocess
import sys
import urllib.request
import zoneinfo

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOCK = os.path.join(ROOT, "scripts", "rade.lock.json")
DECISIONS = os.path.join(ROOT, "docs", "DECISIONS.md")
RELEASE = "https://github.com/rhope-ops/RADE/releases/download/{tag}/rade-engine.lock.json"
TAG_RE = r"engine-v[0-9]{1,4}"
PASTE = os.path.join(ROOT, "scripts", "gov", "paste")
BUNDLES = os.path.join(ROOT, "scripts", "paste_bundles.json")   # round definitions: the raise changes bundle names here
GO = os.path.join(ROOT, "go.md")                                   # the task page: the raise changes a linked bundle name
BUNDLE_FILES = (".ps1", ".ps1.sha256.json")   # a round bundle and, from engine-v21, its stored hash file beside it
GIT_TIMEOUT = 120   # seconds a git call to the network may take
BY = "scripts/bump_lock.py (run at the PFM's request)"   # the DECISIONS "By" text: the script wrote the row


def check_release(rel, lock, tagged):
    """Return the list of problems in a release lock (empty = good)."""
    bad = []
    if rel.get("repo") != lock["repo"]:
        bad.append("repo is not " + lock["repo"])
    if not re.fullmatch(r"[0-9a-f]{40}", str(rel.get("commit", ""))):
        bad.append("commit is not a 40-hex SHA")
    elif rel["commit"] != tagged:
        bad.append("commit does not match the tag (%s)" % (tagged or "tag not found"))
    files = rel.get("files")
    if not isinstance(files, dict) or not files:
        return bad + ["no files"]
    if rel.get("engine") not in files:
        bad.append("engine file is not in files")
    for k, v in files.items():
        if not re.fullmatch(r"[A-Za-z0-9_.\-]+(/[A-Za-z0-9_.\-]+)*", k) or ".." in k.split("/"):
            bad.append("bad path " + k)
        if not re.fullmatch(r"[0-9a-f]{64}", str(v)):
            bad.append("bad SHA-256 for " + k)
    return bad


def run_git(args, what, cwd=None):
    """Run one git command with a time limit. Stops with a FAIL message when git does not answer in GIT_TIMEOUT seconds
    or exits with an error.

    Args:
        args: the git arguments.
        what: plain words for the failure message.
        cwd: the folder to run in, or None.

    Returns:
        The finished process (text output).
    """
    try:
        return subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True, check=True, timeout=GIT_TIMEOUT)
    except subprocess.TimeoutExpired:
        sys.exit("FAIL git did not answer in %d seconds (%s); check the network and run again" % (GIT_TIMEOUT, what))
    except subprocess.CalledProcessError as e:
        sys.exit("FAIL git stopped (%s): %s" % (what, (e.stderr or "").strip()[:200]))


def tag_commit(tag):
    """The commit a RADE tag names: the peeled line of an annotated tag, else the plain line.

    Args:
        tag: the release tag.

    Returns:
        The 40-hex commit, or an empty text when the tag is not found.
    """
    out = run_git(["ls-remote", "https://github.com/rhope-ops/RADE", "refs/tags/" + tag, "refs/tags/" + tag + "^{}"],
                  "looking up the tag " + tag).stdout
    refs = dict((r, s) for s, r in (line.split("\t") for line in out.splitlines() if "\t" in line))
    return refs.get("refs/tags/" + tag + "^{}") or refs.get("refs/tags/" + tag, "")


def main_serial():
    """Read the serial in scripts/rade.lock.json on origin/main (after a fetch).

    Returns:
        The serial number.
    """
    run_git(["fetch", "-q", "origin", "main"], "fetching origin/main", cwd=ROOT)
    shown = run_git(["show", "origin/main:scripts/rade.lock.json"], "reading the lock on origin/main", cwd=ROOT).stdout
    return json.loads(shown)["serial"]


def traced_build(cache_root, engine):
    """Refresh the task scripts' blocks from the newly locked engine (the shared UI file in the window script), build
    the bundles, then run the engine again in this process and return the files it opens under its cache folder. The
    build starts the engine as a child process (scripts/build_paste_bundles.py), so a trace of the build alone sees
    only the download and hash reads, not the engine's own reads.

    Args:
        cache_root: the folder that holds the locked engine files.
        engine: the engine's path under that folder.

    Returns:
        The set of files the engine opened under the cache folder.
    """
    for script, what in (("scripts/build_task_scripts.py", "task script build"), ("scripts/build_paste_bundles.py", "bundle build")):
        if subprocess.run([sys.executable, script], cwd=ROOT).returncode:
            sys.exit("FAIL the %s stopped" % what)
    seen = set()

    def hook(event, args):
        """Audit hook: record each file the engine opens under the cache folder (relative path with forward slashes)."""
        if event == "open" and isinstance(args[0], (str, os.PathLike)):
            p = os.path.abspath(os.fspath(args[0]))
            # A "__pycache__" file is Python's own copy of a module the lock already lists (engine-v21 imports
            # engine/rade_hash.py): not a source the engine reads.
            if p.startswith(cache_root + os.sep) and "__pycache__" not in p.split(os.sep):
                seen.add(os.path.relpath(p, cache_root).replace(os.sep, "/"))
    sys.addaudithook(hook)
    argv, sys.argv = sys.argv, [engine, "--app-root", ROOT]
    try:
        runpy.run_path(os.path.join(cache_root, engine), run_name="__main__")
    except SystemExit as e:
        if e.code not in (None, 0):
            sys.exit("FAIL the traced engine run stopped (exit %s)" % e.code)
    finally:
        sys.argv = argv
    return seen


def decision_row(today, tag, short, serial):
    """Build the DECISIONS table row for a lock move; its By column names this script, not the PFM alone.

    Args:
        today: the date, ISO text.
        tag: the release tag.
        short: the 7-hex RADE commit.
        serial: the new serial number.

    Returns:
        The row text (one line, ends with a newline).
    """
    return ("| %s | RADE lock moves to release %s (RADE %s, serial %d) by scripts/bump_lock.py; bundles rebuilt and checked. "
            "Not verified on a device. | %s | scripts/rade.lock.json |\n" % (today, tag, short, serial, BY))


def add_decision(row):
    """Insert a row at the top of the docs/DECISIONS.md table. Stops when the table head is not found exactly once.

    Args:
        row: the row text from decision_row.
    """
    text = open(DECISIONS).read()
    head = "|---|---|---|---|\n"
    if text.count(head) != 1:
        sys.exit("FAIL could not find the DECISIONS table head")
    with open(DECISIONS, "w") as f:
        f.write(text.replace(head, head + row))


def snapshot():
    """Read the lock, the round definitions, go.md, the round bundles and the task scripts (they hold blocks made from
    the locked engine) as they are now. A file that does not exist is left out.

    Returns:
        A dict of path to file bytes.
    """
    gov = os.path.dirname(PASTE)
    paths = [LOCK, BUNDLES, GO] + [os.path.join(d, n) for d in (PASTE, gov) for n in sorted(os.listdir(d)) if n.endswith(BUNDLE_FILES)]
    return {p: open(p, "rb").read() for p in paths if os.path.exists(p)}


def restore(snap):
    """Write back the files of a snapshot (the old lock, definitions, go.md, bundles and task scripts), and delete each
    round bundle and stored hash file that the snapshot does not hold (a raised revision the failed run made).

    Args:
        snap: the dict that snapshot() returned.
    """
    for n in os.listdir(PASTE):
        p = os.path.join(PASTE, n)
        if n.endswith(BUNDLE_FILES) and p not in snap:
            os.remove(p)
    for p, data in snap.items():
        with open(p, "wb") as f:
            f.write(data)


def run_checks():
    """Run scripts/check.sh and the content check (personal data) against main's allow list.

    Returns:
        Nothing; stops with a FAIL message on a failure.
    """
    for cmd in (["bash", "scripts/check.sh"],
                [sys.executable, "scripts/check_content.py", "--require-denylist", "--all", "--allow-from", "origin/main"]):
        if subprocess.run(cmd, cwd=ROOT).returncode:
            sys.exit("FAIL " + " ".join(cmd[1:]))


def prove(rel, build, checks):
    """Prove the new lock: the traced build (the engine opens exactly the files the lock lists), then the checks.

    Args:
        rel: the release lock.
        build: a function like traced_build.
        checks: a function like run_checks.

    Returns:
        Nothing; stops with a FAIL message on any failure.
    """
    seen = build(os.path.join(ROOT, ".rade-cache", rel["commit"]), rel["engine"])
    if seen != set(rel["files"]):
        sys.exit("FAIL trace: the engine opened %s, the lock lists %s" % (sorted(seen), sorted(rel["files"])))
    print("TRACE PASS: the engine opened the %d files the lock lists" % len(seen))
    checks()


def raise_bundle_revisions(root=None, read_main=None):
    """Give each round bundle that main already has the next revision (scripts/bundle_revision.py --raise), so the
    rebuild writes new file names and no file the work computer may hold changes.

    Args:
        root: the repository folder (None = this repository).
        read_main: a function path -> bytes on main, or None (None = read origin/main with git).

    Returns:
        The list of (old path, new path) pairs; prints one RAISED line per bundle.
    """
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import bundle_revision
    root = root or ROOT
    moved = bundle_revision.raise_revisions(root, read_main or bundle_revision.git_main_reader(root))
    for old, new in moved:
        print("RAISED %s -> %s" % (old, os.path.basename(new)))
    return moved


def apply_bump(rel, tag, lock, serial, today, build=traced_build, checks=run_checks, revise=raise_bundle_revisions):
    """Write the new lock, prove it, and only then write the DECISIONS row. The build reads the lock from disk, so the
    lock is written first; on any failure the old lock and bundles are put back and no row is written.

    Args:
        rel: the release lock (commit, engine, files).
        tag: the release tag.
        lock: the old lock, as a dict.
        serial: the new serial number.
        today: the date for the DECISIONS row (ISO text).
        build: the traced build function (replaceable for tests).
        checks: the checks function (replaceable for tests).
        revise: the revision raise before the build (replaceable for tests).

    Returns:
        Nothing; stops with a FAIL message (after the restore) on a failure.
    """
    old = snapshot()
    lock.update(commit=rel["commit"], tag=tag, serial=serial, engine=rel["engine"], files=rel["files"])
    with open(LOCK, "w") as f:
        f.write(json.dumps(lock, indent=2) + "\n")
    print("LOCK %s %s serial %d files %d (written for the build; kept only if the checks pass)" % (tag, rel["commit"][:7], serial, len(rel["files"])))
    try:
        revise()
        prove(rel, build, checks)
    except SystemExit as e:
        if e.code not in (None, 0):
            restore(old)
            print("RESTORED the old lock, round definitions, go.md and round bundles; no DECISIONS row was written.", file=sys.stderr)
        raise
    add_decision(decision_row(today, tag, rel["commit"][:7], serial))


def bump(tag):
    """Move the RADE lock to a release tag: check the release, write the lock for the build, prove it by trace and
    checks, then add the DECISIONS row.

    Args:
        tag: the release tag, engine-v<N>.

    Returns:
        Nothing; exits with a FAIL message on any failure.
    """
    if not re.fullmatch(TAG_RE, tag):
        sys.exit("FAIL tag must look like engine-v3, got: " + tag)
    lock = json.load(open(LOCK))
    with urllib.request.urlopen(RELEASE.format(tag=tag), timeout=60) as r:
        rel = json.loads(r.read().decode("utf-8"))
    bad = check_release(rel, lock, tag_commit(tag))
    if bad:
        sys.exit("FAIL release lock: " + "; ".join(bad))
    if rel["commit"] == lock["commit"]:
        sys.exit("FAIL the lock already names " + rel["commit"][:7])
    today = datetime.datetime.now(zoneinfo.ZoneInfo("America/Chicago")).date().isoformat()
    apply_bump(rel, tag, lock, main_serial() + 1, today)
    print("BUMP PASS %s: commit, push and open the pull request (AGENTS.md \"Delivery\"). Each bundle that main has got "
          "the next revision (RAISED lines above)." % tag)


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
    fails = sum(1 for rel, tagged, want in cases if bool(check_release(rel, lock, tagged)) != bool(want))
    fails += sum(1 for t in ("engine-v3", "engine-v1234") if not re.fullmatch(TAG_RE, t))
    fails += sum(1 for t in ("engine-v", "x;id", "engine-v3 ", "v3", "engine-v12345") if re.fullmatch(TAG_RE, t))
    return len(cases) + 7, fails


def order_case(name, build_ok, check_ok, rel):
    """Run one apply_bump case in the temp folder that order_cases set up (fake build, checks and revision raise).

    Args:
        name: the case name; "pass" expects success, any other a stop.
        build_ok: whether the fake build passes.
        check_ok: whether the fake checks pass.
        rel: the fake release lock.

    Returns:
        True when the case behaved as expected.
    """
    for n in os.listdir(PASTE):   # each case starts from one old bundle only
        os.remove(os.path.join(PASTE, n))
    open(LOCK, "w").write('{"commit": "old"}')
    open(os.path.join(PASTE, "b.ps1"), "w").write("old bundle")
    for p in (BUNDLES, GO):   # the raise edits these two; a failed run must put them back
        open(p, "w").write("old")
    open(DECISIONS, "w").write("| Date | What | By | Where |\n|---|---|---|---|\n")
    seen = {}

    def build(root, engine):
        """Fake traced build: records whether the new lock and no row are on disk; fakes a bundle write."""
        seen["lock"] = json.load(open(LOCK)).get("commit") == rel["commit"]
        seen["row"] = "bump_lock" in open(DECISIONS).read()
        open(os.path.join(PASTE, "c.ps1"), "w").write("new bundle")
        open(os.path.join(PASTE, "c.ps1.sha256.json"), "w").write("{}")   # engine-v21 on: the stored hash beside it
        if not build_ok:
            sys.exit("FAIL fake build")
        return set(rel["files"])

    def revise():
        """Fake revision raise: the old bundle b.ps1 leaves and the next revision c.ps1 comes."""
        os.remove(os.path.join(PASTE, "b.ps1"))
        open(os.path.join(PASTE, "c.ps1"), "w").write("raised bundle")
        for p in (BUNDLES, GO):
            open(p, "w").write("raised")

    def checks():
        """Fake checks: the row must not exist yet; fails when the case says so."""
        seen["row_at_checks"] = "bump_lock" in open(DECISIONS).read()
        if not check_ok:
            sys.exit("FAIL fake checks")

    try:
        apply_bump(rel, "engine-v9", {"commit": "old"}, 5, "2026-01-01", build, checks, revise)
        stopped = False
    except SystemExit:
        stopped = True
    row = open(DECISIONS).read().count(BY)
    kept = [open(p).read() for p in (BUNDLES, GO)]
    good = (seen.get("lock") is True and seen.get("row") is False and seen.get("row_at_checks", False) is False
            and stopped == (name != "pass"))
    if name == "pass":
        return good and row == 1 and json.load(open(LOCK))["serial"] == 5 and sorted(os.listdir(PASTE)) == ["c.ps1", "c.ps1.sha256.json"] and kept == ["raised"] * 2
    return good and row == 0 and open(LOCK).read() == '{"commit": "old"}' \
        and open(os.path.join(PASTE, "b.ps1")).read() == "old bundle" and os.listdir(PASTE) == ["b.ps1"] and kept == ["old"] * 2


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
        moved = raise_bundle_revisions(t, {old: b"built on main"}.get)
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
    global LOCK, DECISIONS, PASTE, BUNDLES, GO
    saved = (LOCK, DECISIONS, PASTE, BUNDLES, GO)
    fails, cases = 0, 0
    rel = {"commit": "d" * 40, "engine": "engine/x.py", "files": {"engine/x.py": "e" * 64}}
    with tempfile.TemporaryDirectory() as t:
        LOCK, DECISIONS, PASTE = (os.path.join(t, "lock.json"), os.path.join(t, "DECISIONS.md"), os.path.join(t, "paste"))
        BUNDLES, GO = os.path.join(t, "bundles.json"), os.path.join(t, "go.md")
        os.mkdir(PASTE)
        try:
            for name, build_ok, check_ok in (("pass", True, True), ("build fails", False, True), ("checks fail", True, False)):
                good = order_case(name, build_ok, check_ok, rel)
                print("BUMPLOCK order %s: %s" % (name, "ok" if good else "FAIL"))
                cases, fails = cases + 1, fails + (not good)
        finally:
            LOCK, DECISIONS, PASTE, BUNDLES, GO = saved
    good = raise_case()
    print("BUMPLOCK raise itself: %s" % ("ok" if good else "FAIL"))
    cases, fails = cases + 1, fails + (not good)
    return cases, fails


def text_cases():
    """Test the row text and the git time limit (a fake subprocess.run that times out).

    Returns:
        A tuple (cases, fails).
    """
    fails = 0
    row = decision_row("2026-01-01", "engine-v9", "abcdef0", 5)
    fails += not (row.count("\n") == 1 and row.count("|") == 5 and "| " + BY + " |" in row and "PFM |" not in row)
    real = subprocess.run

    def slow(*a, **k):
        """Fake subprocess.run: reports the timeout it was given as expired."""
        raise subprocess.TimeoutExpired(a[0], k.get("timeout"))
    subprocess.run = slow
    try:
        run_git(["ls-remote", "x"], "test")
        fails += 1
    except SystemExit as e:
        fails += not ("did not answer in %d seconds" % GIT_TIMEOUT in str(e.code))
    finally:
        subprocess.run = real
    seen = {}
    subprocess.run = lambda *a, **k: seen.update(k) or subprocess.CompletedProcess(a[0], 0, "", "")
    try:
        run_git(["fetch"], "test")
    finally:
        subprocess.run = real
    fails += seen.get("timeout") != GIT_TIMEOUT
    return 3, fails


def self_test():
    """Run every no-network self-test: release checks, the order of the bump steps, the row text and the git timeout.

    Returns:
        1 when any case fails, else 0 (the BUMPLOCK line is printed).
    """
    total = fails = 0
    for fn in (release_cases, order_cases, text_cases):
        n, f = fn()
        total, fails = total + n, fails + f
    print("BUMPLOCK cases=%d fails=%d" % (total, fails))
    return 1 if fails else 0


def changed_files():
    """List the changed files from git status. Takes nothing; returns the text, or "(none)"."""
    out = subprocess.run(["git", "status", "--short"], cwd=ROOT, capture_output=True, text=True).stdout
    return out.strip() or "(none)"


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        sys.exit(self_test())
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    try:
        bump(sys.argv[1])
    except SystemExit as e:
        if e.code not in (None, 0):
            # A failed run puts the old lock and bundles back and writes no row (apply_bump); other files, if any, are listed.
            # Never reset or clean (AGENTS.md "Git safety"): fix the cause and run again.
            print("Files changed so far:\n" + changed_files(), file=sys.stderr)
        raise
