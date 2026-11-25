#!/usr/bin/env python3
"""Test the README link check of scripts/build_readme.py (bad_links): no link to a .ps1 file or to github.io.

Prevents: a later change that weakens the check, so that a .ps1 or github.io link gets into README.md again (the PFM,
2026-11-25: such a link breaks the work computer). Each case is a Markdown text and the expected result.
Usage: python3 tests/check_readme_links.py   Pass = last line "README LINKS cases=N fails=0".
tests/run.sh runs it.
Network: none.
Writes: nothing.
Credentials: none.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
import build_readme   # noqa: E402  the module under test

# Texts that GitHub shows as a link to a .ps1 file or to a github.io page: each must be found.
BAD = [
    '[x](a.ps1)', '[x](a.PS1)', '[x](https://x.com/a%252Eps1)', 'https://x.com/a&#46;ps1', '[x](scripts/gov/paste/a.ps1)', '[x](a.ps1/)', '![i](a.ps1)',
    '[a](https://x.com/y.ps1 "t")', '[x](<https://x.com/a b.ps1>)', '[x](https://x.com/a(1).ps1)',
    '[x](https://x.com/a%2Eps1)', '[x](https://x.com/a&#46;ps1)', '[c](https://x/y.ps1#L2)',
    '[x][id]\n\n[id]: a.ps1 "t"', "[x][id]\n\n[id]: a.ps1 't'", '[x][id]\n\n[id]: <a.ps1> "t"',
    '[id]: <a b.ps1>\n\n[x][id]', '[a\\]b]: a.ps1\n\n[x][a\\]b]', '[x][id]\n\n> [id]: a.ps1',
    '[x][id]\n\n[id]: https://x.com/y.ps1',
    '<a href="a.ps1">x</a>', '<a href=a.ps1>x</a>', "<a href='https://x.com/y.ps1'>x</a>", '<img src="a.ps1">',
    '**https://x.com/a.ps1**', '_https://x.com/a.ps1_', 'https://x.com/a.ps1~', 'https://x.com/a.ps1!',
    'https://x.com:8080/a.ps1', 'http://10.0.0.1/a.ps1', '[x](http://localhost/a.ps1)', 'https://x.com/y.ps1?a=1',
    'https://x.com/a.ps1<br>', 'www.x.com/a.ps1<br>', '| https://x.com/a.ps1| c |', 'https://x.com/a.ps1&hl;',
    'Open https://rhope-ops.github.io/RADE now.', 'rhope-ops.github.io/90-161.Z', 'RHOPE-OPS.GITHUB.IO',
    '<https://github.io>', '_www.foo.github.io_', 'see _www.foo.github.io_ now',
]
# Texts that are not such a link: none may be found.
GOOD = [
    'The window file is T22\\90161Z-T22-maint-r15.ps1', '`a.ps1`', 'T22/x.ps1', '(a.ps1)', '"a.ps1"', 'see [a.ps1]',
    '[o](https://raw.githubusercontent.com/a/b.txt)', '<https://raw.githubusercontent.com/a/b.md>',
    'github.com/rhope-ops/90-161.Z', 'https://x.com/a.ps1.txt', 'https://notgithub.iox.com/a', 'evilgithub.io',
    '1. Step one: run it.',
]


def run():
    """Run every case and print one line per failed case, then the summary line.

    Returns:
        The number of failed cases.
    """
    fails = 0
    for text in BAD:
        if not build_readme.bad_links(text):
            fails += 1
            print('FAIL not found: %r' % text)
    for text in GOOD:
        found = build_readme.bad_links(text)
        if found:
            fails += 1
            print('FAIL found in a text with no such link: %r -> %s' % (text, found))
    print('README LINKS cases=%d fails=%d' % (len(BAD) + len(GOOD), fails))
    return fails


if __name__ == '__main__':
    sys.exit(1 if run() else 0)
