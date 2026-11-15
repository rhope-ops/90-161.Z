#!/usr/bin/env python3
"""Claude Code Stop hook: block the end of a turn while work is not on GitHub.

Blocks (exit 2, reason on stderr) when the checkout has uncommitted changes, or
commits that its upstream branch does not have, or a branch that was never pushed.
Passes a clean read-only checkout: no changes (untracked files included), no stash,
and HEAD is on the default branch (origin/main, else origin/master) or behind it, so
an unpushed session branch with no work of its own does not block (kit default, 2026-11-11).
Allows the stop on the second try in a row (stop_hook_active), so a turn that must
end anyway (for example, near the usage limit, or when the PFM said hold) can end.
Outside a git repo, or when git fails, it allows the stop.

Configured in .claude/settings.json ("hooks" > "Stop"). Manual run:
    echo '{}' | python3 scripts/stop_check.py; echo "exit $?"
Self-test (temporary repos, no network):
    python3 scripts/stop_check.py --test
Standard library only.
"""
import json
import os
import subprocess
import sys

REPO_DIR = None


def git(*args):
    r = subprocess.run(["git", *args], cwd=REPO_DIR, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout.strip()


def default_ref():
    """origin/main, else origin/master, else None (no default branch ref to compare with)."""
    for ref in ("origin/main", "origin/master"):
        try:
            git("rev-parse", "--verify", "--quiet", ref + "^{commit}")
            return ref
        except RuntimeError:
            continue
    return None


def on_default_branch():
    """True when HEAD has no commits that origin/main (or origin/master) lacks."""
    ref = default_ref()
    if ref is None:
        return False
    r = subprocess.run(["git", "merge-base", "--is-ancestor", "HEAD", ref], cwd=REPO_DIR,
                       capture_output=True, text=True)
    return r.returncode == 0


def problems():
    found = []
    dirty = git("status", "--porcelain", "--untracked-files=all")
    stashed = git("stash", "list")
    if not dirty and not stashed and on_default_branch():
        return found
    if dirty:
        found.append(f"{len(dirty.splitlines())} uncommitted file(s)")
    if stashed:
        found.append(f"{len(stashed.splitlines())} stash entry(ies) (lost when the container ends)")
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    try:
        upstream = git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    except RuntimeError:
        upstream = None
    if upstream:
        ahead = int(git("rev-list", "--count", f"{upstream}..HEAD") or 0)
        if ahead:
            found.append(f"{ahead} commit(s) on {branch} not pushed to {upstream}")
    elif branch != "HEAD":
        found.append(f"branch {branch} has no upstream (never pushed)")
    elif default_ref() and not on_default_branch():
        # Detached HEAD (also during a rebase that is not finished) with commits the default branch lacks
        # (kit default, 2026-11-11). With no origin/main or origin/master to compare with, the old pass stays.
        found.append(f"detached HEAD has commits not on {default_ref()}")
    return found


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        data = {}
    if not isinstance(data, dict):
        data = {}
    if data.get("stop_hook_active"):
        return 0
    global REPO_DIR
    REPO_DIR = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or None
    try:
        found = problems()
    except (RuntimeError, OSError, ValueError):
        return 0
    if not found:
        return 0
    print(
        "Work is not on GitHub: " + "; ".join(found) + ". "
        "Commit and push, or say why it must wait, then stop again.",
        file=sys.stderr,
    )
    return 2


def self_test():
    """Build throwaway repos and check each case. Prints one line per case; exit 0 = all pass."""
    import shutil
    import tempfile
    global REPO_DIR
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t",
               GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    root = tempfile.mkdtemp(prefix="stop_check_test_")

    def run(cwd, *args):
        subprocess.run(["git", *args], cwd=cwd, env=env, check=True, capture_output=True, text=True)

    def commit(cwd, name):
        with open(os.path.join(cwd, name), "w") as f:
            f.write(name)
        run(cwd, "add", name)
        run(cwd, "commit", "-q", "-m", name)

    def fresh(name, default="main"):
        origin = os.path.join(root, name + ".git")
        run(root, "init", "-q", "--bare", "-b", default, origin)
        work = os.path.join(root, name)
        run(root, "clone", "-q", origin, work)
        run(work, "checkout", "-q", "-b", default)
        commit(work, "a")
        run(work, "push", "-q", "origin", default)
        run(work, "fetch", "-q", "origin")
        return work

    def verdict(work, data="{}"):
        global REPO_DIR
        saved_env = dict(os.environ)
        os.environ.clear(); os.environ.update(env); os.environ["CLAUDE_PROJECT_DIR"] = work
        saved_in, saved_err = sys.stdin, sys.stderr
        import io
        sys.stdin, sys.stderr = io.StringIO(data), io.StringIO()
        try:
            REPO_DIR = None
            return "block" if main() == 2 else "pass"
        finally:
            sys.stdin, sys.stderr = saved_in, saved_err
            os.environ.clear(); os.environ.update(saved_env)

    cases = []
    try:
        w = fresh("readonly"); run(w, "checkout", "-q", "-b", "claude/session")
        cases.append(("clean session branch at origin/main, never pushed", verdict(w), "pass"))
        w = fresh("behind"); commit(w, "b"); run(w, "push", "-q", "origin", "main"); run(w, "checkout", "-q", "-b", "s", "HEAD~1")
        cases.append(("clean branch behind origin/main, never pushed", verdict(w), "pass"))
        w = fresh("master", default="master"); run(w, "checkout", "-q", "-b", "s")
        cases.append(("clean branch at origin/master (no main), never pushed", verdict(w), "pass"))
        w = fresh("modified"); run(w, "checkout", "-q", "-b", "s")
        with open(os.path.join(w, "a"), "w") as f:
            f.write("changed")
        cases.append(("modified file", verdict(w), "block"))
        w = fresh("untracked"); run(w, "checkout", "-q", "-b", "s"); run(w, "config", "status.showUntrackedFiles", "no")
        with open(os.path.join(w, "new"), "w") as f:
            f.write("x")
        cases.append(("untracked file, untracked hidden by config", verdict(w), "block"))
        w = fresh("stash"); run(w, "checkout", "-q", "-b", "s")
        with open(os.path.join(w, "a"), "w") as f:
            f.write("changed")
        run(w, "stash", "-q")
        cases.append(("stash on a clean branch at origin/main", verdict(w), "block"))
        w = fresh("unpushed"); run(w, "checkout", "-q", "-b", "s"); commit(w, "b")
        cases.append(("one unpushed commit, branch never pushed", verdict(w), "block"))
        w = fresh("ahead"); run(w, "checkout", "-q", "-b", "s"); commit(w, "b"); run(w, "push", "-q", "-u", "origin", "s"); commit(w, "c")
        cases.append(("pushed branch, one commit ahead of upstream", verdict(w), "block"))
        w = fresh("pushed"); run(w, "checkout", "-q", "-b", "s"); commit(w, "b"); run(w, "push", "-q", "-u", "origin", "s")
        cases.append(("pushed branch, upstream up to date (not on main)", verdict(w), "pass"))
        with open(os.path.join(w, "b"), "w") as f:
            f.write("changed")
        run(w, "stash", "-q")
        cases.append(("pushed branch, up to date, plus a stash", verdict(w), "block"))
        w = fresh("detached_ahead"); run(w, "checkout", "-q", "--detach"); commit(w, "b")
        cases.append(("detached HEAD with a commit not on origin/main", verdict(w), "block"))
        w = fresh("detached_on"); run(w, "checkout", "-q", "--detach")
        cases.append(("detached HEAD at origin/main, clean", verdict(w), "pass"))
        w = fresh("active"); run(w, "checkout", "-q", "-b", "s"); commit(w, "b")
        cases.append(("unpushed commit, stop_hook_active", verdict(w, '{"stop_hook_active": true}'), "pass"))
    finally:
        shutil.rmtree(root, ignore_errors=True)
    failed = 0
    for name, got, want in cases:
        ok = got == want
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {name}: {got} (want {want})")
    print("STOP_CHECK TEST PASS" if not failed else f"STOP_CHECK TEST FAIL ({failed} of {len(cases)})")
    return 1 if failed else 0


if __name__ == "__main__":
    if "--test" in sys.argv[1:]:
        sys.exit(self_test())
    sys.exit(main())
