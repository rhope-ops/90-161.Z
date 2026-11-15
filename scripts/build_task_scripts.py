#!/usr/bin/env python3
"""Write the shared blocks (scripts/gov/src/task-common.ps1, site-common.ps1) into each gov task script (PFM B3A and P3, 2026-11-13).

Each scripts/gov/90161Z-T*.ps1 that asks for a DODID holds the block between two marker lines:
    # >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)
    # <<< task-common
The text between them is the source from its first "function" line on. Edit only the source, then run this script.
A script that signs in to the site also holds the site-common block (Get-SiteAddress; PFM 15 Nov 26: the site is entered once),
between the same kind of markers; a Get-SiteAddress outside that block fails the check.
Usage: python3 scripts/build_task_scripts.py [--check]
  --check: write nothing; exit 1 when a block is stale, or a task script asks for the DODID outside the block.
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'scripts/gov/src/task-common.ps1'
BEGIN = '# >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)'
END = '# <<< task-common'
ASKS_DODID = "Read-Host 'DODID"
BLOCKS = [(SRC, BEGIN, END)] + [(ROOT / f'scripts/gov/src/{n}.ps1', BEGIN.replace('task-common', n), END.replace('task-common', n)) for n in ('site-common',)]


def body(src=SRC):
    text = src.read_text(encoding='utf-8').replace('\r\n', '\n')
    return text[text.index('\nfunction ') + 1:].rstrip('\n') + '\n'


def main(check):
    stale, unshared, shared = [], [], 0
    for f in sorted((ROOT / 'scripts/gov').glob('90161Z-T*.ps1')):
        text = f.read_text(encoding='utf-8')
        for src, begin, end in BLOCKS:
            block = body(src)
            m = re.search(re.escape(begin) + r'\n(.*?)' + re.escape(end) + r'\n', text, re.S)
            outside = text if m is None else text[:m.start()] + text[m.end():]
            if (ASKS_DODID if src == SRC else 'function Get-SiteAddress') in outside:
                unshared.append(f.name)
            if m is None:
                continue
            shared += src == SRC
            if m.group(1) != block:
                stale.append(f.name)
                if not check:
                    text = text[:m.start(1)] + block + text[m.end(1):]
                    f.write_text(text, encoding='utf-8')
    for n in unshared:
        print('UNSHARED ' + n + ': asks for the DODID or the site address outside its shared block (use Get-TaskId, Get-SiteAddress)')
    for n in stale:
        print(('STALE ' if check else 'WROTE ') + n)
    print('TASKCOMMON scripts=%d stale=%d unshared=%d' % (shared, len(stale) if check else 0, len(unshared)))
    return 1 if unshared or (check and stale) else 0


if __name__ == '__main__':
    sys.exit(main('--check' in sys.argv[1:]))
