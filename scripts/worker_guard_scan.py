#!/usr/bin/env python3
"""Scan a worker's branch or scratch folder for workarounds of the guards (plan P2 item (i), AUD-6; rule text S8).

Usage:
  python3 scripts/worker_guard.py --scan TARGET ...   # TARGET: a folder, or a git range such as origin/main...BRANCH
  python3 scripts/worker_guard.py --test               # the guard's self-test also runs this module's self-test

Finds two kinds, one line per finding, and exits 1 when there is any (0 when there is none):
  rebuilt   a line of code (a script or source file; prose is not code) that builds a string at run time from pieces (chr(N), a byte or unicode escape, a join of literals,
            a base64, hex or rot13 decode) whose value holds the at sign or a word the content check blocks.
  wrapped   a line of a shell script (a .sh or .bash file, or a file that starts with #!) that holds a git command
            the worker guard blocks: a command put in a file runs where the guard cannot see it.
For a folder every line of every text file is read; for a git range only the added lines. The output names the file,
the line and the kind, never the value (it can be personal data).
Prevents: a worker gets past the content check or the worker guard by rebuilding a blocked string or by putting a
blocked command in a script file, and the fresh review does not see it.
Inputs: the files, or `git diff -U0 RANGE`; the content check's word lists (environment variable or file, as it reads them).
Network: none.
Writes: none.
Credentials: none.
"""
import base64
import binascii
import codecs
import json
import re
import subprocess
import tempfile
from pathlib import Path

import check_content_scan as scan   # scripts/check_content_scan.py: scan_text and the word lists
import worker_guard as guard   # scripts/worker_guard.py: the block rules (reason)

BUILDERS = re.compile(r"chr\(\s*(?:0x[0-9A-Fa-f]+|\d+)\s*\)|\\x[0-9A-Fa-f]{2}|\\u[0-9A-Fa-f]{4}|\\[0-7]{3}|&#\d+;|"
                      r"b64decode|fromhex|unhexlify|rot_?13|\.join\(")
LITERAL = re.compile(r"(['\"])((?:\\.|(?!\1).)*)\1")
SHELL_SUFFIXES = ('.sh', '.bash')
CODE_SUFFIXES = SHELL_SUFFIXES + ('.py', '.js', '.mjs', '.cjs', '.ps1', '.psm1')


def values(line):
    """The strings a line may build at run time: the chr() characters, the literals with their escapes decoded,
    the literals joined, and each literal decoded as base64, hex and rot13 (a piece that does not decode is left out).

    Args:
        line: one line of text that matched BUILDERS.

    Returns:
        A list of candidate strings.
    """
    lits = [m.group(2) for m in LITERAL.finditer(line)]
    out = [''.join(chr(int(n, 0)) for n in re.findall(r"chr\(\s*(0x[0-9A-Fa-f]+|\d+)\s*\)", line) if int(n, 0) < 0x110000)]
    out.append(re.sub(r"&#(\d+);", lambda m: chr(int(m.group(1))) if int(m.group(1)) < 0x110000 else '', line))
    for lit in lits:
        try:
            out.append(codecs.decode(lit, 'unicode_escape'))
        except (UnicodeDecodeError, ValueError):
            pass
        out.append(codecs.decode(lit, 'rot13'))
        for decode in (lambda s: base64.b64decode(s, validate=True), bytes.fromhex):
            try:
                out.append(decode(lit).decode('utf-8'))
            except (binascii.Error, ValueError, UnicodeDecodeError):
                pass
    out.append(''.join(lits))
    return [v for v in out if v]


def rebuilt(line, deny, terms):
    """True when a line builds a string at run time whose value holds the at sign or a word the content check blocks.

    Args:
        line: one line of text.
        deny: the names of the denylist.
        terms: the Maintainer's own blocked words.

    Returns:
        True or False.
    """
    if not BUILDERS.search(line):
        return False
    return any('@' in v or scan.scan_text(v, 'built', deny, [], terms=terms) for v in values(line))


def wrapped(path, line):
    """True when a line of a shell script holds a git command that the worker guard blocks.

    Args:
        path: the file's path (a Path or text).
        line: one line of the file.

    Returns:
        True or False.
    """
    return bool(guard.reason(line.strip())) if line.strip() and not line.lstrip().startswith('#') else False


def listed(line):
    """True when a line of code holds a git command, as a list of literals (for example a subprocess call), that the
    worker guard blocks.

    Args:
        line: one line of code.

    Returns:
        True or False.
    """
    lits = [m.group(2) for m in LITERAL.finditer(line)]
    return 'git' in lits and bool(guard.reason(' '.join(lits)))


def lines_of(target):
    """Yield (path, line number, line, is shell, is code) for a folder (every line of every text file, not the
    worktrees of .claude/worktrees) or a git range (added lines).

    Args:
        target: a folder path, or a git range such as origin/main...BRANCH.
    """
    root = Path(target)
    if root.is_dir():
        for p in sorted(x for x in root.rglob('*') if x.is_file() and '.git' not in x.parts and '.claude/worktrees/' not in x.relative_to(root).as_posix()):
            try:
                text = p.read_text(encoding='utf-8', errors='replace')
            except OSError:
                continue
            shell = p.suffix in SHELL_SUFFIXES or text.startswith('#!')
            for no, line in enumerate(text.split('\n'), 1):
                yield str(p), no, line, shell, shell or p.suffix in CODE_SUFFIXES
        return
    head = re.split(r"\.\.\.?", target)[-1] or 'HEAD'
    names = git(['diff', '--name-only', '-z', '--diff-filter=d', target]).split('\0')
    for path in filter(None, names):   # one diff per file: no header parsing, any file name
        shell = path.endswith(SHELL_SUFFIXES) or git(['show', f'{head}:{path}'], check=False).startswith('#!')
        no, body = 0, False
        for line in git(['diff', '-U0', '--no-color', target, '--', path]).split('\n'):
            if line.startswith('@@'):
                no, body = int(re.search(r"\+(\d+)", line).group(1)), True
            elif body and line.startswith('+'):
                yield path, no, line[1:], shell, shell or path.endswith(CODE_SUFFIXES)
                no += 1


def git(args, check=True):
    """The output of one git command as text (bytes that are not UTF-8 are replaced).

    Args:
        args: the git arguments.
        check: True: a failing command raises CalledProcessError.

    Returns:
        The standard output.
    """
    return subprocess.run(['git', '--literal-pathspecs', *args], capture_output=True, check=check).stdout.decode('utf-8', 'replace')


def scan_targets(targets, deny=None, terms=None):
    """The findings in the targets, each (path, line number, kind).

    Args:
        targets: folders or git ranges.
        deny: the names of the denylist (None: the content check's own list).
        terms: the Maintainer's own blocked words (None: the content check's own list).

    Returns:
        A list of (path, line number, kind).
    """
    deny = scan.load_denylist() if deny is None else deny
    terms = scan.load_terms() if terms is None else terms
    found = []
    for target in targets:
        for path, no, line, shell, code in lines_of(target):
            if shell and wrapped(path, line) or code and listed(line):
                found.append((path, no, 'wrapped'))
            elif code and rebuilt(line, deny, terms):
                found.append((path, no, 'rebuilt'))
    return found


def main(targets):
    """Print one line per finding and a summary line.

    Args:
        targets: folders or git ranges.

    Returns:
        The exit code: 0 no finding, 1 a finding (a MAJOR finding for the review: the delegate skill, S8), 2 an error.
    """
    try:
        found = scan_targets(targets)
    except (subprocess.CalledProcessError, OSError) as err:
        print(f'GUARD SCAN ERROR: {err}')
        return 2
    for path, no, kind in found:
        print(f'{kind:8}  {path}:{no}')
    print(f'GUARD SCAN {"FAIL" if found else "PASS"}: {len(found)} finding(s) in {len(targets)} target(s)')
    return 1 if found else 0


def selftest():
    """Prove the scan on the sample files of scripts/worker_guard_scan_samples.json (in a temporary folder), and the
    range mode on a temporary git repo (an added line that starts with "++", a file name with a space, a byte that is
    not UTF-8). The blocked word is invented.

    Returns:
        A list of the failed cases (empty when all pass).
    """
    data = json.loads((Path(__file__).parent / 'worker_guard_scan_samples.json').read_text(encoding='utf-8'))
    word, cases, bad = data['word'], data['samples'], []
    with tempfile.TemporaryDirectory() as tmp:
        for name, (text, _) in cases.items():
            (Path(tmp) / name).write_text(text)
        kinds = {Path(p).name: k for p, _, k in scan_targets([tmp], deny=[word], terms=[])}
        bad += [f'{n}: want {w}, got {kinds.get(n)}' for n, (_, w) in cases.items() if kinds.get(n) != w]
        inner = Path(tmp) / '.claude' / 'worktrees' / 'agent-x'   # a worker's scratch folder, given as the target
        inner.mkdir(parents=True)
        (inner / 'a.py').write_text(cases['a.py'][0])
        if not scan_targets([str(inner)], deny=[word], terms=[]):
            bad.append('a target inside .claude/worktrees is scanned')
        repo = Path(tmp) / 'repo'
        run = lambda *a: subprocess.run(['git', '-C', str(repo), '-c', 'user.name=t', '-c', 'user.email=t@t.invalid', *a],
                                        capture_output=True, check=True)
        repo.mkdir()
        run('init', '-q')
        (repo / 's p.py').write_text('x = 1\n')
        run('add', '-A')
        run('commit', '-qm', 'base')
        (repo / 's p.py').write_bytes(data['range'].encode('latin-1'))   # a byte that is not UTF-8 (0xff)
        run('commit', '-qam', 'change')
        old = Path.cwd()
        try:
            import os
            os.chdir(repo)
            found = scan_targets(['HEAD~1...HEAD'], deny=[word], terms=[])
        finally:
            os.chdir(old)
        if found != [('s p.py', 4, 'rebuilt')]:
            bad.append(f'range mode: want [s p.py:4 rebuilt], got {found}')
    return bad
