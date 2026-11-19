#!/usr/bin/env python3
"""Newest RADE: does the lock name the newest engine release of rhope-ops/RADE, at that release's commit? (The PFM,
15 Nov 26: "there needs to be a check if RADE has upgraded every time we do a round".) tests/run.sh calls it and turns
the verdict into PASS, NOTE or FAIL.

    python3 scripts/rade_newest.py TAGS LOCK_TAG LOCK_COMMIT CHANGED

TAGS: the output of `git ls-remote --tags` on the RADE repo (may be empty: no network). CHANGED: the changed file names
against origin/main, one a line, or *all* when there is no merge base. Prints one verdict:
  OK <tag>           the lock names the newest release at its commit
  BEHIND <tag>       a newer release exists and the change touches the lock, the bundle list or a round bundle (or
                     cannot be judged): a FAIL, so a round is never built on an old engine
  BEHINDNOTE <tag>   a newer release exists, but the change touches none of those (the PFM, 19 Nov 26: a RADE release
                     blocked a docs-only pull request for hours): a NOTE; the next round build fails until the lock moves
  WRONGCOMMIT <tag>  the lock has the newest tag but another commit (review of 15 Nov 26)
  NOTCHECKED         no tags in TAGS (no answer from github.com): a NOTE, never a PASS
Network: none (the caller passes the tags).
Writes: nothing.
Credentials: none.
"""
import re
import sys

TAG_RE = re.compile(r'^([0-9a-f]{40})\s+refs/tags/(engine-v[0-9]+)(\^\{\})?$')       # a tag line; ^{} = peeled commit
ROUND_RE = re.compile(r'scripts/(rade\.lock\.json|paste_bundles\.json|gov/paste/)')  # the files a round build changes


def verdict(tags, lock_tag, lock_commit, changed):
    """Return the verdict line for one lock.

    Args:
        tags: `git ls-remote --tags` output (may be empty).
        lock_tag: the tag in scripts/rade.lock.json.
        lock_commit: the commit in scripts/rade.lock.json.
        changed: changed file names, one a line, or '*all*'.

    Returns:
        One of the verdict lines in the module docstring.
    """
    sha = {}
    for line in tags.splitlines():
        m = TAG_RE.match(line.strip())
        if m and (m.group(3) or m.group(2) not in sha):
            sha[m.group(2)] = m.group(1)
    if not sha:
        return 'NOTCHECKED'
    newest = max(sha, key=lambda t: int(t.split('v')[-1]))
    if lock_tag != newest:
        round_change = changed == '*all*' or any(ROUND_RE.match(f) for f in changed.split())
        return ('BEHIND ' if round_change else 'BEHINDNOTE ') + newest
    return ('OK ' if sha[newest] == lock_commit else 'WRONGCOMMIT ') + newest


if __name__ == '__main__':
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    print(verdict(*sys.argv[1:5]))
