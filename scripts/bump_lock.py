#!/usr/bin/env python3
"""Move scripts/rade.lock.json to a RADE engine release, locally (the PFM, 2026-11-15: no outside checks).

    python3 scripts/bump_lock.py engine-v3    # copy the release lock, rebuild, trace, check (docs/dev-setup.md "RADE engine")
    python3 scripts/bump_lock.py --test       # self-test of the release-lock checks (no network)

Steps: (1) download rade-engine.lock.json from the RADE release and check it (repo, commit = the tag's commit,
file paths, SHA-256 form); (2) write the lock with serial = main's + 1 and add the decision row to docs/DECISIONS.md;
(3) rebuild the round bundles under a trace of the files the engine opens, and fail when the trace differs from the
lock's file list; (4) run scripts/check.sh (tests/run.sh among them) and the PII guard against main's allow list.
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


def tag_commit(tag):
    """The commit a RADE tag names: the peeled line of an annotated tag, else the plain line."""
    out = subprocess.run(["git", "ls-remote", "https://github.com/rhope-ops/RADE", "refs/tags/" + tag,
                          "refs/tags/" + tag + "^{}"], capture_output=True, text=True, check=True).stdout
    refs = dict((r, s) for s, r in (line.split("\t") for line in out.splitlines() if "\t" in line))
    return refs.get("refs/tags/" + tag + "^{}") or refs.get("refs/tags/" + tag, "")


def main_serial():
    subprocess.run(["git", "fetch", "-q", "origin", "main"], cwd=ROOT, check=True)
    shown = subprocess.run(["git", "show", "origin/main:scripts/rade.lock.json"], cwd=ROOT,
                           capture_output=True, text=True, check=True).stdout
    return json.loads(shown)["serial"]


def traced_build(cache_root, engine):
    """Build the bundles, then run the engine again in this process and return the files it opens under its
    cache folder. The build starts the engine as a child process (scripts/build_paste_bundles.py), so a trace of
    the build alone sees only the download and hash reads, not the engine's own reads."""
    if subprocess.run([sys.executable, "scripts/build_paste_bundles.py"], cwd=ROOT).returncode:
        sys.exit("FAIL the bundle build stopped")
    seen = set()

    def hook(event, args):
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


def bump(tag):
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
    serial = main_serial() + 1
    lock.update(commit=rel["commit"], tag=tag, serial=serial, engine=rel["engine"], files=rel["files"])
    with open(LOCK, "w") as f:
        f.write(json.dumps(lock, indent=2) + "\n")
    short = rel["commit"][:7]
    print("LOCK %s %s serial %d files %d" % (tag, short, serial, len(rel["files"])))

    today = datetime.datetime.now(zoneinfo.ZoneInfo("America/Chicago")).date().isoformat()
    row = ("| %s | RADE lock moves to release %s (RADE %s, serial %d) by scripts/bump_lock.py; bundles rebuilt. "
           "Not verified on a device. | PFM | scripts/rade.lock.json |\n" % (today, tag, short, serial))
    text = open(DECISIONS).read()
    head = "|---|---|---|---|\n"
    if text.count(head) != 1:
        sys.exit("FAIL could not find the DECISIONS table head")
    with open(DECISIONS, "w") as f:
        f.write(text.replace(head, head + row))

    seen = traced_build(os.path.join(ROOT, ".rade-cache", rel["commit"]), rel["engine"])
    if seen != set(rel["files"]):
        sys.exit("FAIL trace: the engine opened %s, the lock lists %s" % (sorted(seen), sorted(rel["files"])))
    print("TRACE PASS: the engine opened the %d files the lock lists" % len(seen))

    for cmd in (["bash", "scripts/check.sh"],
                [sys.executable, "scripts/pii_guard.py", "--require-denylist", "--all", "--allow-from", "origin/main"]):
        if subprocess.run(cmd, cwd=ROOT).returncode:
            sys.exit("FAIL " + " ".join(cmd[1:]))
    print("BUMP PASS %s: commit, push and open the pull request (AGENTS.md \"Delivery\"). If a rebuilt bundle already "
          "went to the work computer, raise its revision in scripts/paste_bundles.json first." % tag)


def self_test():
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
    print("BUMPLOCK cases=%d fails=%d" % (len(cases) + 7, fails))
    return 1 if fails else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        sys.exit(self_test())
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    bump(sys.argv[1])
