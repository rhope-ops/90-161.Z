#!/usr/bin/env python3
"""Claude Code Stop hook: block the end of a turn while work is not on GitHub.

Blocks (exit 2, reason on stderr) when the checkout has uncommitted changes, or
commits that its upstream branch does not have, or a branch that was never pushed.
Passes a clean read-only checkout: no changes (untracked files included), no stash,
and HEAD is on the default branch (origin/main, else origin/master) or behind it, so
an unpushed session branch with no work of its own does not block (kit default, 2026-11-11). When the local copy
of the default branch is old (a new session clone often is), the hook fetches that one branch and compares again.
Allows the stop on the second try in a row (stop_hook_active), so a turn that must
end anyway (for example, near the usage limit, or when the Maintainer said hold) can end.
Outside a git repo, or when git fails, it allows the stop.

Configured in .claude/settings.json ("hooks" > "Stop"). Manual run:
    echo '{}' | python3 scripts/stop_check.py; echo "exit $?"
Self-test (temporary repos, no network):
    python3 scripts/stop_check.py --test
Standard library only.
Prevents: a turn ends with uncommitted or unpushed work, so the work is lost when the session or its clone is gone
Network: the git remote "origin": at most one fetch of the default branch, and only when a clean branch looks ahead of it.
Writes: none (the fetch updates the remote-tracking branch; the self-test: temporary repos).
Credentials: none itself; the fetch uses the credentials git already has for origin.
"""
import json
import os
import subprocess
import sys

REPO_DIR = None
FETCH_TIMEOUT_S = 10  # the hook timeout in .claude/settings.json is 30


def git(*args):
    """Run git in REPO_DIR; return its output, or raise RuntimeError when it fails."""
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


def on_default_branch(fetch=False):
    """True when HEAD has no commits that origin/main (or origin/master) lacks. A local copy of that branch can be
    old: with fetch, when the first comparison fails, fetch the branch once (at most FETCH_TIMEOUT_S seconds) and
    compare again.

    Args:
        fetch: True: fetch the branch once when the first comparison fails.

    Returns:
        True or False.
    """
    ref = default_ref()
    if ref is None:
        return False

    def merged():
        """True when HEAD is the ref's commit or one of its ancestors."""
        return subprocess.run(["git", "merge-base", "--is-ancestor", "HEAD", ref], cwd=REPO_DIR,
                              capture_output=True, text=True).returncode == 0
    if merged() or not fetch:
        return merged()
    try:  # no network, no remote or a slow host: keep the first answer
        subprocess.run(["git", "fetch", "--quiet", "origin", ref.split("/", 1)[1]], cwd=REPO_DIR, capture_output=True,
                       timeout=FETCH_TIMEOUT_S)
    except (subprocess.TimeoutExpired, OSError):
        return False
    return merged()


def problems():
    """Return why the turn may not end yet; empty for a clean read-only checkout or work that is on GitHub.

    Returns:
        A list of reasons (texts); empty when the turn may end.
    """
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
        # Only here a fetch is worth its time: a clean branch that was never pushed and looks ahead of an old local
        # copy of the default branch (a new session clone).
        if not found and on_default_branch(fetch=True):
            return found
        found.append(f"branch {branch} has no upstream (never pushed)")
    elif default_ref() and not on_default_branch():
        # Detached HEAD (also during a rebase that is not finished) with commits the default branch lacks
        # (kit default, 2026-11-11). With no origin/main or origin/master to compare with, the old pass stays.
        found.append(f"detached HEAD has commits not on {default_ref()}")
    return found


def main():
    """Read the Stop hook input on stdin; return 2 (reason on stderr) when work is not on GitHub, else 0.

    Returns:
        The exit code: 0 lets the turn end, 2 blocks it.
    """
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


class TestRepos:
    """Throwaway origin and work repos for the self-test, with git run under a clean environment."""

    def __init__(self, root):
        # The host's git config and GIT_ variables must not change the cases.
        self.root = root
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        self.env.update(GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t",
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")

    def run(self, cwd, *args):
        """Run one git command in cwd; fail the test on an error."""
        subprocess.run(["git", *args], cwd=cwd, env=self.env, check=True, capture_output=True, text=True)

    def commit(self, cwd, name):
        """Commit a new file called name that holds its own name."""
        write(os.path.join(cwd, name), name)
        self.run(cwd, "add", name)
        self.run(cwd, "commit", "-q", "-m", name)

    def fresh(self, name, default="main"):
        """A bare origin and a clone with one commit pushed to the default branch; returns the clone's path.

        Args:
            name: the name of the sample repo.
            default: the name of its default branch.

        Returns:
            The path of the clone.
        """
        origin = os.path.join(self.root, name + ".git")
        self.run(self.root, "init", "-q", "--bare", "-b", default, origin)
        work = os.path.join(self.root, name)
        self.run(self.root, "clone", "-q", origin, work)
        self.run(work, "checkout", "-q", "-b", default)
        self.commit(work, "a")
        self.run(work, "push", "-q", "origin", default)
        self.run(work, "fetch", "-q", "origin")
        return work

    def verdict(self, work, data="{}"):
        """Run the hook on work with data on stdin; "block" or "pass".

        Args:
            work: the path of the clone to run the hook in.
            data: the hook input (JSON text) for stdin.

        Returns:
            "block" or "pass".
        """
        import io
        global REPO_DIR
        saved_env = dict(os.environ)
        os.environ.clear(); os.environ.update(self.env); os.environ["CLAUDE_PROJECT_DIR"] = work
        saved_in, saved_err = sys.stdin, sys.stderr
        sys.stdin, sys.stderr = io.StringIO(data), io.StringIO()
        try:
            REPO_DIR = None
            return "block" if main() == 2 else "pass"
        finally:
            sys.stdin, sys.stderr = saved_in, saved_err
            os.environ.clear(); os.environ.update(saved_env)


def write(path, text):
    """Overwrite one file of a test repo."""
    with open(path, "w") as f:
        f.write(text)


def clean_cases(repos):
    """Clean checkouts that must pass: at, behind or on the default branch.

    Args:
        repos: the helper that makes the sample repos.

    Returns:
        A list of (label, verdict, wanted verdict).
    """
    run, verdict = repos.run, repos.verdict
    work = repos.fresh("readonly"); run(work, "checkout", "-q", "-b", "claude/session")
    out = [("clean session branch at origin/main, never pushed", verdict(work), "pass")]
    work = repos.fresh("behind"); repos.commit(work, "b"); run(work, "push", "-q", "origin", "main"); run(work, "checkout", "-q", "-b", "s", "HEAD~1")
    out.append(("clean branch behind origin/main, never pushed", verdict(work), "pass"))
    work = repos.fresh("master", default="master"); run(work, "checkout", "-q", "-b", "s")
    out.append(("clean branch at origin/master (no main), never pushed", verdict(work), "pass"))
    # The local origin/main is one commit old, and HEAD is the newer commit that the remote already has.
    work = repos.fresh("stale"); repos.commit(work, "b"); run(work, "push", "-q", "origin", "main")
    run(work, "update-ref", "refs/remotes/origin/main", "HEAD~1"); run(work, "checkout", "-q", "-b", "s")
    out.append(("clean branch at the remote's main while the local origin/main is old", verdict(work), "pass"))
    return out


def dirty_cases(repos):
    """Uncommitted work that must block: a modified file, an untracked file, a stash.

    Args:
        repos: the TestRepos helper.

    Returns:
        A list of (case name, verdict, wanted verdict).
    """
    run, verdict = repos.run, repos.verdict
    work = repos.fresh("modified"); run(work, "checkout", "-q", "-b", "s")
    write(os.path.join(work, "a"), "changed")
    out = [("modified file", verdict(work), "block")]
    work = repos.fresh("untracked"); run(work, "checkout", "-q", "-b", "s"); run(work, "config", "status.showUntrackedFiles", "no")
    write(os.path.join(work, "new"), "x")
    out.append(("untracked file, untracked hidden by config", verdict(work), "block"))
    work = repos.fresh("stash"); run(work, "checkout", "-q", "-b", "s")
    write(os.path.join(work, "a"), "changed")
    run(work, "stash", "-q")
    out.append(("stash on a clean branch at origin/main", verdict(work), "block"))
    return out


def commit_cases(repos):
    """Commits not on GitHub, pushed branches, detached HEAD and the second stop in a row.

    Args:
        repos: the TestRepos helper.

    Returns:
        A list of (case name, verdict, wanted verdict).
    """
    run, commit, verdict = repos.run, repos.commit, repos.verdict
    work = repos.fresh("unpushed"); run(work, "checkout", "-q", "-b", "s"); commit(work, "b")
    out = [("one unpushed commit, branch never pushed", verdict(work), "block")]
    work = repos.fresh("ahead"); run(work, "checkout", "-q", "-b", "s"); commit(work, "b"); run(work, "push", "-q", "-u", "origin", "s"); commit(work, "c")
    out.append(("pushed branch, one commit ahead of upstream", verdict(work), "block"))
    work = repos.fresh("pushed"); run(work, "checkout", "-q", "-b", "s"); commit(work, "b"); run(work, "push", "-q", "-u", "origin", "s")
    out.append(("pushed branch, upstream up to date (not on main)", verdict(work), "pass"))
    write(os.path.join(work, "b"), "changed")
    run(work, "stash", "-q")
    out.append(("pushed branch, up to date, plus a stash", verdict(work), "block"))
    work = repos.fresh("detached_ahead"); run(work, "checkout", "-q", "--detach"); commit(work, "b")
    out.append(("detached HEAD with a commit not on origin/main", verdict(work), "block"))
    work = repos.fresh("detached_on"); run(work, "checkout", "-q", "--detach")
    out.append(("detached HEAD at origin/main, clean", verdict(work), "pass"))
    work = repos.fresh("active"); run(work, "checkout", "-q", "-b", "s"); commit(work, "b")
    out.append(("unpushed commit, stop_hook_active", verdict(work, '{"stop_hook_active": true}'), "pass"))
    return out


def self_test():
    """Build throwaway repos and check each case. Prints one line per case; exit 0 = all pass.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    import shutil
    import tempfile
    root = tempfile.mkdtemp(prefix="stop_check_test_")
    repos = TestRepos(root)
    try:
        cases = clean_cases(repos) + dirty_cases(repos) + commit_cases(repos)
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
