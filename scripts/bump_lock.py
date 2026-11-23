#!/usr/bin/env python3
"""Move scripts/rade.lock.json to a RADE engine release, locally (the PFM, 2026-11-15: no outside checks).

    python3 scripts/bump_lock.py engine-v3    # copy the release lock, rebuild, trace, check (docs/dev-setup.md "RADE engine")
    python3 scripts/bump_lock.py --test       # self-test of the release-lock checks (no network; scripts/bump_lock_test.py)
    RADE_LOCAL_DIR=<folder> python3 scripts/bump_lock.py engine-v3   # offline: see release_lock() below

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
import urllib.parse
import urllib.request
import zoneinfo

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOCK = os.path.join(ROOT, "scripts", "rade.lock.json")
DECISIONS = os.path.join(ROOT, "docs", "DECISIONS.md")
# The engine repository comes from scripts/rade.lock.json "repo" (the attested release subject; fleet v2 DEC 7).
RELEASE = "https://github.com/{repo}/releases/download/{tag}/rade-engine.lock.json"
REPO_RE = r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"   # owner/name: nothing else may enter a URL
RELEASE_FILE = "rade-engine.lock.json"   # the release lock file name, also in a RADE_LOCAL_DIR folder
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


def https_only(url):
    """Stop unless a URL uses https (fleet v2: no plain-http download of the release lock, CWE-319).

    Args:
        url: the URL to open, or a redirect target.

    Returns:
        The URL unchanged; exits with a FAIL message for any other scheme or an empty host.
    """
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or not parts.netloc:
        sys.exit("FAIL only https URLs may be opened, got: " + url[:120])
    return url


class HttpsRedirects(urllib.request.HTTPRedirectHandler):
    """Follow a redirect only to an https URL (a GitHub release download redirects once to its file host)."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        """Check the redirect target with https_only, then follow it as urllib does. Returns the new request."""
        return super().redirect_request(req, fp, code, msg, headers, https_only(newurl))


def release_lock(tag, repo):
    """Read the release lock of a tag: from RADE_LOCAL_DIR when it is set (offline), else download it over https.

    RADE_LOCAL_DIR names a local clone of rhope-ops/RADE that has the tag, with the release file rade-engine.lock.json
    (downloaded by hand from the release page) in the clone's top folder. The checks of check_release still run.

    Args:
        tag: the release tag, engine-v<N>.
        repo: the engine repository, owner/name (the lock's "repo").

    Returns:
        The release lock (a dict).
    """
    local = os.environ.get("RADE_LOCAL_DIR")
    if local:
        path = os.path.join(local, RELEASE_FILE)
        if not os.path.isfile(path):
            sys.exit("FAIL RADE_LOCAL_DIR is set but %s does not exist" % path)
        print("OFFLINE the release lock comes from %s (RADE_LOCAL_DIR)" % path)
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    opener = urllib.request.build_opener(HttpsRedirects)
    with opener.open(https_only(RELEASE.format(repo=repo, tag=tag)), timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def tag_commit(tag, repo):
    """The commit a RADE tag names: the peeled line of an annotated tag, else the plain line.

    Args:
        tag: the release tag.
        repo: the engine repository, owner/name (the lock's "repo"); not used offline (RADE_LOCAL_DIR).

    Returns:
        The 40-hex commit, or an empty text when the tag is not found.
    """
    local = os.environ.get("RADE_LOCAL_DIR")
    if local:   # offline: the tag in the local RADE clone (release_lock)
        out = subprocess.run(["git", "-C", local, "rev-parse", "--verify", "-q", "refs/tags/" + tag + "^{commit}"],
                             capture_output=True, text=True, timeout=GIT_TIMEOUT).stdout.strip()
        return out if re.fullmatch(r"[0-9a-f]{40}", out) else ""
    out = run_git(["ls-remote", "https://github.com/" + repo, "refs/tags/" + tag, "refs/tags/" + tag + "^{}"],
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
            if p.startswith(cache_root + os.sep):
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
    round bundle, task script and stored hash file that the snapshot does not hold (a file the failed run made).

    Args:
        snap: the dict that snapshot() returned.
    """
    for d in (PASTE, os.path.dirname(PASTE)):   # round bundles, and the task scripts beside them
        for n in os.listdir(d):
            p = os.path.join(d, n)
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


def without_module_caches(seen, files):
    """Take Python's own cache copies of listed modules out of a trace. Engine-v21 imports engine/rade_hash.py, and
    Python then opens engine/__pycache__/rade_hash.cpython-<N>.pyc (and a temporary name of it while it writes). Only
    the cache of a module the lock lists is taken out; any other file under a __pycache__ folder stays and fails the trace.

    Args:
        seen: the set of relative paths the engine opened.
        files: the lock's file list (relative paths).

    Returns:
        The set without those cache copies.
    """
    keep = set()
    for path in seen:
        m = re.fullmatch(r"(?:(.*)/)?__pycache__/([^/.]+)\.[A-Za-z0-9_-]+\.pyc(?:\.[0-9]+)?", path)
        if not (m and ((m.group(1) + "/" if m.group(1) else "") + m.group(2) + ".py") in files):
            keep.add(path)
    return keep


def prove(rel, build, checks):
    """Prove the new lock: the traced build (the engine opens exactly the files the lock lists), then the checks.

    Args:
        rel: the release lock.
        build: a function like traced_build.
        checks: a function like run_checks.

    Returns:
        Nothing; stops with a FAIL message on any failure.
    """
    seen = without_module_caches(build(os.path.join(ROOT, ".rade-cache", rel["commit"]), rel["engine"]), rel["files"])
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
        Nothing; stops with a FAIL message (after the restore) on a failure; any other error or Ctrl-C restores too,
        then goes on up.
    """
    old = snapshot()
    lock.update(commit=rel["commit"], tag=tag, serial=serial, engine=rel["engine"], files=rel["files"])
    with open(LOCK, "w") as f:
        f.write(json.dumps(lock, indent=2) + "\n")
    print("LOCK %s %s serial %d files %d (written for the build; kept only if the checks pass)" % (tag, rel["commit"][:7], serial, len(rel["files"])))
    try:
        revise()
        prove(rel, build, checks)
    except BaseException as e:   # a FAIL stop, any other error and Ctrl-C all put the files back
        if not (isinstance(e, SystemExit) and e.code in (None, 0)):
            restore(old)
            print("RESTORED the old lock, round definitions, go.md, round bundles and task scripts; no DECISIONS row was written.", file=sys.stderr)
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
    if not re.fullmatch(REPO_RE, lock.get("repo", "")):
        sys.exit("FAIL scripts/rade.lock.json \"repo\" must look like owner/name")
    rel = release_lock(tag, lock["repo"])
    bad = check_release(rel, lock, tag_commit(tag, lock["repo"]))
    if bad:
        sys.exit("FAIL release lock: " + "; ".join(bad))
    if rel["commit"] == lock["commit"]:
        sys.exit("FAIL the lock already names " + rel["commit"][:7])
    today = datetime.datetime.now(zoneinfo.ZoneInfo("America/Chicago")).date().isoformat()
    apply_bump(rel, tag, lock, main_serial() + 1, today)
    print("BUMP PASS %s: commit, push and open the pull request (AGENTS.md \"Delivery\"). Each bundle that main has got "
          "the next revision (RAISED lines above)." % tag)


def changed_files():
    """List the changed files from git status. Takes nothing; returns the text, or "(none)"."""
    out = subprocess.run(["git", "status", "--short"], cwd=ROOT, capture_output=True, text=True).stdout
    return out.strip() or "(none)"


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        import bump_lock_test   # scripts/bump_lock_test.py: the self-test cases, kept apart (450-line cap)
        sys.exit(bump_lock_test.run(sys.modules[__name__]))
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
