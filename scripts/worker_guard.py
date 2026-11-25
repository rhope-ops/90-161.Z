#!/usr/bin/env python3
"""PreToolUse hook for the worker and reviewer subagents (.claude/agents/): blocks git commands they must never run.

Adapted from an earlier project's worker guard (tested parser).

Usage (wired in the .claude/agents/ frontmatter `hooks:`; runs only while that subagent is active):
  python3 scripts/worker_guard.py            # reads the hook JSON on stdin
  python3 scripts/worker_guard.py --readonly # reviewer: also blocks git verbs that change the repo
  python3 scripts/worker_guard.py --test     # self-test of the block rules and the scan; prints GUARD TEST PASS
  python3 scripts/worker_guard.py --scan TARGET ...  # a worker's branch range or scratch folder: guard workarounds (worker_guard_scan.py)

Blocks Bash commands that push to main or master (also a bare push or HEAD while on one), rebase, git clean, branch deletes, force-push (--force, -f in
grouped flags, +refspec, --force-with-lease), --mirror/--all, reset --hard or delete remote branches. It parses each
simple command into words (quotes respected), so "main" inside a branch name or a commit message is not a match.
Exit 2 with the reason on stderr blocks the call; exit 0 lets the normal permission flow decide. A command string run by
eval or a shell's -c is checked too; other commands built at run time (a script file, stdin, `$(...)` output) are not
seen: it is a seat belt for honest mistakes, not a security boundary.
Prevents: a worker or reviewer subagent that pushes to main, force-pushes, rewrites history or deletes a branch by mistake.
Network: none.
Writes: none.
Credentials: none.
"""
import argparse
import json
import re
import shlex
import subprocess
import sys

SEPARATORS = {';', '&&', '||', '|', '&', '(', ')'}
GIT_OPTS_WITH_VALUE = {'-C', '-c', '--git-dir', '--work-tree', '--namespace'}
# --readonly (reviewer): also block git verbs that change the repo.
WRITE_VERBS = {'commit', 'add', 'rm', 'mv', 'merge', 'checkout', 'switch', 'restore', 'stash', 'tag', 'apply', 'am',
               'cherry-pick', 'revert', 'reset', 'push', 'pull', 'clean'}


def segments(cmd):
    """Yield the word lists of each simple command (split on newlines and ; && || | &, quotes respected).

    Args:
        cmd: the shell command text.
    """
    for line in cmd.splitlines():
        try:
            lex = shlex.shlex(line, posix=True, punctuation_chars=True)
            lex.whitespace_split = True
            words = list(lex)
        except ValueError:          # unbalanced quotes: fall back to a plain split
            words = line.split()
        seg = []
        for w in words:
            if w in SEPARATORS:
                if seg:
                    yield seg
                seg = []
            else:
                seg.append(w)
        if seg:
            yield seg


def current_branch():
    """The checked-out branch name ("HEAD" when detached, "" outside a repo)."""
    r = subprocess.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'], capture_output=True, text=True)
    return r.stdout.strip()


BRANCH_OPTS_WITH_VALUE = {'--sort', '--format', '--contains', '--no-contains', '--merged', '--no-merged', '--points-at'}


def branch_delete(rest):
    """True for any delete form of `git branch`: -d/-D alone or grouped (-rd, -df), and --delete or its prefixes
    (git accepts an unambiguous prefix such as --del). A value after --sort and the like is skipped.

    Args:
        rest: the words after `git branch`.

    Returns:
        True or False.
    """
    skip = False
    for w in rest:
        if skip:
            skip = False
            continue
        if w in BRANCH_OPTS_WITH_VALUE:
            skip = True
        elif w.startswith('--'):
            if len(w) >= 3 and '--delete'.startswith(w):
                return True
        elif w.startswith('-') and ('d' in w or 'D' in w):
            return True
    return False


def check_git(args, branch, readonly=False):
    """args: the words after `git`. Returns a reason to block, or None.

    Args:
        args: the words after `git`.
        branch: the current branch, or None when it is not known.
        readonly: True for the reviewer: also block the git verbs that change the repo.

    Returns:
        A reason to block (a text), or None.
    """
    i = 0
    while i < len(args) and args[i].startswith('-'):
        i += 2 if args[i] in GIT_OPTS_WITH_VALUE else 1
    if i >= len(args):
        return None
    sub, rest = args[i], args[i + 1:]
    if readonly and sub in WRITE_VERBS:
        return f'reviewers are read-only: no git {sub}'
    if sub == 'rebase':
        return 'no rebase; update a branch by merging (AGENTS.md "Git history")'
    if sub == 'reset' and '--hard' in rest:
        return 'no reset --hard; ask the orchestrator'
    if sub == 'clean':
        return 'no git clean; ask the orchestrator'
    if sub == 'branch' and branch_delete(rest):
        return 'no branch deletes; the orchestrator or the Maintainer deletes branches'
    if sub != 'push':
        return None
    pos, cut = [], None
    for w in rest:
        if w and set(w) <= set('<>&|'):  # a redirection such as > or >& (2>&1 splits as 2, >&, 1)
            if cut is None:
                cut = len(pos)
            continue
        if w.startswith('--'):
            if w in ('--force', '--mirror', '--all', '--delete', '--prune') or w.startswith('--force-with-lease'):
                return f'workers may not push with {w} (AGENTS.md "Git history")'
        elif w.startswith('-') and len(w) > 1:
            if 'f' in w[1:] or 'd' in w[1:]:
                return f'workers may not push with {w} (force or delete)'
        else:
            pos.append(w)
    # With a redirection, check two readings and block if either targets main: all words as refspecs (a quoted ">"
    # is a real argument), and only the words before it, minus a file-descriptor digit (`git push 2>&1` on main).
    readings = [pos]
    if cut is not None:
        before = pos[:cut]
        if before and before[-1].isdigit():
            before = before[:-1]
        readings.append(before)
    for words in readings:
        why = push_target(words, branch)
        if why:
            return why
    return None


def push_target(pos, branch):
    """pos: the push words without options; pos[0] is the remote. Returns a reason to block, or None.

    Args:
        pos: the push words without options; pos[0] is the remote.
        branch: the current branch, or None when it is not known.

    Returns:
        A reason to block (a text), or None.
    """
    refspecs = pos[1:]
    if not refspecs:
        refspecs = ['HEAD']
    for ref in refspecs:
        if ref.startswith('+'):
            return 'no force-push (+refspec)'
        src, _, dst = ref.partition(':')
        if _ and not src:
            return 'workers do not delete remote branches'
        target = dst or (branch if src == 'HEAD' else src)
        if target in ('main', 'master', 'refs/heads/main', 'refs/heads/master'):
            return 'workers never push main or master; push your own branch'
    return None


SHELLS = {'sh', 'bash', 'zsh', 'dash', 'ksh'}


def reason(cmd, branch=None, readonly=False, depth=0):
    """Why a shell command is blocked, or None; command strings run by a shell or eval are checked too.

    Args:
        cmd: the shell command text.
        branch: the current branch, or None when it is not known.
        readonly: True for the reviewer: also block the git verbs that change the repo.
        depth: how many shell or eval layers are above this text (the check stops at 3).

    Returns:
        A reason to block (a text), or None.
    """
    for seg in segments(cmd):
        for k, w in enumerate(seg):
            # A command string run by a shell (`bash -c "git checkout main"`, `eval "..."`) is checked as a command too.
            inner = None
            if w == 'eval' and depth < 3:
                inner = ' '.join(seg[k + 1:])
            elif w.rsplit('/', 1)[-1] in SHELLS and depth < 3:
                # The command string follows the first short-option group with c (-c, -xc, -lc), past long options
                # (--norc, --rcfile x) and an optional "--".
                flags = [j for j in range(k + 1, len(seg)) if re.fullmatch(r'-[A-Za-z]*c[A-Za-z]*', seg[j])]
                if flags:
                    j = flags[0] + 1
                    if j < len(seg) and seg[j] == '--':
                        j += 1
                    if j < len(seg):
                        inner = seg[j]
            if inner is not None:
                why = reason(inner, branch, readonly, depth + 1)
                if why:
                    return why
                break
            if readonly and w.rsplit('/', 1)[-1] in {'rm', 'rmdir', 'unlink', 'shred'}:
                return 'the reviewer is read-only: it never deletes files (a test copy goes in a new mktemp -d folder it leaves)'
            if w == 'git' or w.endswith('/git'):
                why = check_git(seg[k + 1:], branch if branch is not None else current_branch(), readonly)
                if why:
                    return why
                break
    return None


def selftest():
    """Check sample commands that must block and must pass; print the wrong ones and the result.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    block = ['git push origin main', 'git push -u origin HEAD:main', 'git push origin claude/x:main', 'git push --force origin claude/x',
             'git push -f', 'git push -fu origin claude/x', 'git push origin "+claude/x"', 'git push origin +claude/x',
             'git rebase origin/main', 'cd x && git rebase -i HEAD~2', 'git -C sub rebase main', 'git reset --hard origin/main',
             'git push origin --delete claude/x', 'git push origin :claude/x', 'git push --mirror origin', 'git push --all',
             'git push --force-with-lease origin claude/x', 'git status; git push origin main',
             'git push origin master', 'git clean -fd', 'git branch -D x', '(git push origin main)', 'git --no-pager -C r push --force',
             'git push --prune origin', 'git push origin ">" main', 'git push origin claude/x > /dev/null; git push origin main',
             'git branch -df x', 'git branch -rd origin/x', 'git branch --dele x', 'git branch --del x']
    allow = ['git push -u origin claude/t40-slc', 'git push -u origin claude/main-menu', 'git push origin claude/fix-main',
             'git merge origin/main', 'git status', 'python3 tools/check.py --no-perf', 'git log --oneline main..HEAD',
             'git fetch origin main', 'git commit -m "push main menu fix"', 'git commit -m "fix rebase of main"',
             'git push', 'git push origin HEAD', 'git commit -m "note; git rebase later"', 'git branch -a', 'git branch -vv',
             'git push origin claude/x 2>&1', 'git push -u origin claude/x > /dev/null', 'git branch --sort -committerdate', 'git branch --sort=-committerdate',
             'git branch -m old new', 'git branch --list']
    bad = [c for c in block if not reason(c, 'claude/x')] + [c for c in allow if reason(c, 'claude/x')]
    for c in ['git push', 'git push origin HEAD', 'git push 2>&1', 'git push > /dev/null', 'git push 2> err.txt',
              'git push origin 2>&1']:     # on main these must block
        if not reason(c, 'main'):
            bad.append(c + ' (on main)')
    for c in ['git commit -m x', 'git checkout -b y', 'git add .', 'cd a && git merge origin/main',
              'bash -c "git checkout main"', 'sh -lc \'git switch main\'', 'eval "git checkout main"', '/bin/bash -c "cd x; git commit -m y"',
              'bash --norc -c "git checkout main"', 'bash --rcfile x -c "git checkout main"', 'bash -c -- "git checkout main"',
              'ksh -c "git checkout main"', 'rm -rf x', 'cd /tmp/a && /bin/rm -r b', 'bash -c "rmdir x"']:
        if not reason(c, 'claude/x', readonly=True):
            bad.append(c + ' (readonly)')
    for c in ['git diff origin/main...HEAD', 'git log -p', 'git show HEAD:x', 'git status', 'git fetch origin',
              'bash -c "git log --oneline -3"', 'bash scripts/check.sh']:
        if reason(c, 'claude/x', readonly=True):
            bad.append(c + ' (readonly allow)')
    import worker_guard_scan   # scripts/worker_guard_scan.py (imported here: it imports this module)
    bad += worker_guard_scan.selftest()
    for c in bad:
        print('WRONG:', c)
    print('GUARD TEST PASS' if not bad else 'GUARD TEST FAIL')
    return 1 if bad else 0


def main():
    """PreToolUse hook: exit 2 with the reason when a Bash command is blocked; or run --test.

    Returns:
        The exit code: 0 lets the command run, 2 blocks it.
    """
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--test', action='store_true', help='run the self-test')
    ap.add_argument('--readonly', action='store_true', help='also block git verbs that change the repo (reviewer)')
    ap.add_argument('--scan', nargs='+', metavar='TARGET', help='scan folders or git ranges for guard workarounds')
    opts = ap.parse_args()
    if opts.test:
        return selftest()
    if opts.scan:
        import worker_guard_scan   # scripts/worker_guard_scan.py
        return worker_guard_scan.main(opts.scan)
    try:
        hook = json.load(sys.stdin)
    except ValueError:
        return 0
    if hook.get('tool_name') != 'Bash':
        return 0
    why = reason(hook.get('tool_input', {}).get('command', ''), readonly=opts.readonly)
    if why:
        print(f'Blocked by scripts/worker_guard.py: {why}. Report the need to the orchestrator instead.', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
