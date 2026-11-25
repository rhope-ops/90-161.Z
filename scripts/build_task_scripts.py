#!/usr/bin/env python3
"""Write the shared blocks (scripts/gov/src/task-common.ps1, site-common.ps1) into each gov task script (PFM B3A and P3, 2026-11-13).

Each scripts/gov/90161Z-T*.ps1 that asks for a DODID holds the block between two marker lines:
    # >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)
    # <<< task-common
The text between them is the source from its first "function" line on. Edit only the source, then run this script.
A script that signs in to the site also holds the site-common block (Get-SiteAddress; PFM 15 Nov 26: the site is entered once),
between the same kind of markers; a Get-SiteAddress outside that block fails the check.
A script that waits for a flow (T18, T24) holds the wait-common block (Wait-Until; code standard S1, rule C5) between its own
markers; it is written only into a script that has them.
A script with the app-logo markers gets $AppLogoPng: the 90-161.Z logo in Fulcrum colours (PFM 20 Nov 26: "Fulcrum everywhere for now, as this
is not an endorsed product"; R11 of T22 uses it in Windows light and dark mode) as a 128 px PNG in base64 text, drawn from the master
assets/logo/90161Z-logo-fulcrum.svg by scripts/logo_draw.py (pure Python, the same bytes on every machine; scripts/logo_png.py keeps one
hash record per master; the PNGs stay uncommitted, PFM 2A). The USAF master assets/logo/90161Z-logo.svg is not used any more. The RADE runner
keeps RADE's own logo (Rho Bold) from the pinned engine.
A script with the rade-ui markers gets the RADE shared UI file (engine/rade_ui.ps1, then engine/rade_ui_text.ps1 from engine-v36,
of the same pinned commit, SHA-256 checked the
same way) as it is: the window reuses RADE's colors, fonts, buttons, card text boxes and layout self-check (T22 r2, 17 Nov 26).
Usage: python3 scripts/build_task_scripts.py [--check]
  --check: write nothing; exit 1 when a block is stale, or a task script asks for the DODID outside the block.
"""
import base64, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'scripts/gov/src/task-common.ps1'
BEGIN = '# >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)'
END = '# <<< task-common'
ASKS_DODID = "Read-Host 'DODID"
BLOCKS = [(SRC, BEGIN, END)] + [(ROOT / f'scripts/gov/src/{n}.ps1', BEGIN.replace('task-common', n), END.replace('task-common', n)) for n in ('site-common', 'wait-common')]
SITE = ROOT / 'scripts/gov/src/site-common.ps1'   # the block whose functions must not live outside it
LOGO = 'app-logo'
BLOCKS.append((LOGO, '# >>> app-logo: generated from assets/logo/90161Z-logo-fulcrum.svg by scripts/build_task_scripts.py (do not edit)', '# <<< app-logo'))
UI = 'rade-ui'
BLOCKS.append((UI, '# >>> rade-ui: generated from the pinned RADE shared UI file by scripts/build_task_scripts.py (do not edit)', '# <<< rade-ui'))
# R38 (engine-v29, 599 lines): the shared UI file is split into 2 blocks so each window part stays under the 600-line file
# cap (code standard C4); UI2 holds the second half, from the first top-level "$ui." line past the middle (ui_text).
UI2 = 'rade-ui-2'
BLOCKS.append((UI2, '# >>> rade-ui-2: generated from the pinned RADE shared UI file (second half) by scripts/build_task_scripts.py (do not edit)', '# <<< rade-ui-2'))
GENERATED = (LOGO, UI, UI2)   # blocks made from the logo master and the pinned RADE files (not from a .ps1 source here); written only into a script that has the markers
_logo = []
_ui = []


CHECK = []   # set by main: a --check run never writes the logo record


def logo_text():
    """Build the PowerShell text of the logo block, once per run.

    Returns: the text of $AppLogoPng (base64 rows), the same on every call of the run.
    """
    # The 90-161.Z logo, 128 px, in Fulcrum colours ($AppLogoPng; PFM 20 Nov 26: Fulcrum in light and dark mode): one render
    # for every script (scripts/logo_png.py).
    if not _logo:
        sys.path.insert(0, str(ROOT / 'scripts'))
        import logo_png
        text = ''
        for var, master in (('AppLogoPng', 'fulcrum'),):
            b64 = base64.b64encode(logo_png.png(128, bool(CHECK), master)).decode('ascii')
            rows = [b64[i:i + 100] for i in range(0, len(b64), 100)]
            text += '$' + var + ' = @(\n' + ',\n'.join("  '" + r + "'" for r in rows) + "\n) -join ''\n"
        _logo.append(text)
    return _logo[0]


def ui_text(part=1):
    """Read the pinned shared UI file from the locked engine, once per run, and give one of its 2 halves.

    Args:
        part: 1 = the first half, 2 = the second.
    Returns: the text of that half with LF line ends; the 2 halves join to the whole file.
    """
    # The pinned shared UI file, fetched and hash-checked by the bundle builder (one fetch for every script).
    if not _ui:
        sys.path.insert(0, str(ROOT / 'scripts'))
        import build_paste_bundles as B
        lock = json.loads(B.LOCK_FILE.read_text(encoding='utf-8'))
        # engine-v36 on: the shared UI file has a part 2, engine/rade_ui_text.ps1 ($ui.Ink to $ui.Meas); an app window copies
        # it right after engine/rade_ui.ps1, as it is (its header; the engine's own build does the same).
        root = B.fetch(lock)
        names = ['engine/rade_ui.ps1'] + (['engine/rade_ui_text.ps1'] if 'engine/rade_ui_text.ps1' in lock['files'] else [])
        text = ''.join((root / n).read_text(encoding='utf-8').replace('\r\n', '\n').rstrip('\n') + '\n' for n in names)
        _ui.extend(split_ui(text))
    return _ui[part - 1]


def split_ui(text):
    """Split the shared UI text in 2 at the first top-level "$ui." line past its middle with every brace before it closed.

    Args:
        text: the whole shared UI file.
    Returns: (first, second), which join to the text.
    Raises: SystemExit when no such line exists (the build stops).
    """
    lines = text.split('\n')
    depth = 0
    for i, line in enumerate(lines):
        if i >= len(lines) // 2 and depth == 0 and line.startswith('$ui.'):
            return '\n'.join(lines[:i]) + '\n', '\n'.join(lines[i:])
        depth += line.count('{') - line.count('}')
    sys.exit('FAIL the RADE shared UI file has no top-level $ui. line past its middle to split at (scripts/build_task_scripts.py split_ui)')


def body(src=SRC):
    """Get the text that a shared block in the task scripts must hold. Takes the source (a script file, or the LOGO or UI marker); returns text."""
    if src == LOGO:
        return logo_text()
    if src == UI:
        return ui_text(1)
    if src == UI2:
        return ui_text(2)
    text = src.read_text(encoding='utf-8').replace('\r\n', '\n')
    return text[text.index('\nfunction ') + 1:].rstrip('\n') + '\n'


def main(check):
    """Command line: refresh the shared blocks in every task script, or with check only report stale ones. Takes check; returns 1 on an unshared or stale block, else 0."""
    if check:
        CHECK.append(True)
    stale, unshared, shared = [], [], 0
    for f in sorted((ROOT / 'scripts/gov').glob('90161Z-T*.ps1')):
        text = f.read_text(encoding='utf-8')
        for src, begin, end in BLOCKS:
            block = body(src) if src not in GENERATED or begin in text else ''
            m = re.search(re.escape(begin) + r'\n(.*?)' + re.escape(end) + r'\n', text, re.S)
            outside = text if m is None else text[:m.start()] + text[m.end():]
            owned = (ASKS_DODID,) if src == SRC else ('function Get-SiteAddress', 'function Hide-Site') if src == SITE else ()
            if src not in GENERATED and any(a in outside for a in owned):
                unshared.append(f.name)
            if m is None:
                if src == SITE and 'Get-SiteAddress' in text and f.name not in unshared:
                    unshared.append(f.name)   # uses the site address without the shared block
                continue
            shared += src == SRC
            if m.group(1) != block:
                stale.append(f.name) if f.name not in stale else None
                if not check:
                    text = text[:m.start(1)] + block + text[m.end(1):]
                    f.write_text(text, encoding='utf-8')
    for n in unshared:
        print('UNSHARED ' + n + ': asks for the DODID, the site address or Hide-Site outside its shared block (use Get-TaskId, Get-SiteAddress, Hide-Site)')
    for n in stale:
        print(('STALE ' if check else 'WROTE ') + n)
    print('TASKCOMMON scripts=%d stale=%d unshared=%d' % (shared, len(stale) if check else 0, len(unshared)))
    return 1 if unshared or (check and stale) else 0


if __name__ == '__main__':
    sys.exit(main('--check' in sys.argv[1:]))
