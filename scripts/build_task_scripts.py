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
A script with the app-logo markers gets $AppLogoPng and $AppLogoFulcrumPng: the 90-161.Z logo (PFM 17 Nov 26: logo on the T22 window, 1A; Delta since
PFM 19 Nov 26) as 128 px PNGs in base64 text, drawn from the masters assets/logo/90161Z-logo.svg (USAF colours, Windows dark mode) and, from R37,
assets/logo/90161Z-logo-fulcrum.svg (Fulcrum colours, Windows light mode; PFM 19 Nov 26) by scripts/logo_draw.py (pure Python, the
same bytes on every machine; scripts/logo_png.py keeps one hash record per master; the PNGs stay uncommitted, PFM 2A). The RADE runner keeps RADE's own logo (Rho Bold) from the pinned engine.
A script with the rade-ui markers gets the RADE shared UI file (engine/rade_ui.ps1 of the same pinned commit, SHA-256 checked the
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
BLOCKS.append((LOGO, '# >>> app-logo: generated from assets/logo/90161Z-logo.svg and 90161Z-logo-fulcrum.svg by scripts/build_task_scripts.py (do not edit)', '# <<< app-logo'))
UI = 'rade-ui'
BLOCKS.append((UI, '# >>> rade-ui: generated from the pinned RADE shared UI file by scripts/build_task_scripts.py (do not edit)', '# <<< rade-ui'))
GENERATED = (LOGO, UI)   # blocks made from the logo master and the pinned RADE files (not from a .ps1 source here); written only into a script that has the markers
_logo = []
_ui = []


CHECK = []   # set by main: a --check run never writes the logo record


def logo_text():
    """Build the PowerShell text of the logo block, once per run.

    Returns: the text of $AppLogoPng and $AppLogoFulcrumPng (base64 rows), the same on every call of the run.
    """
    # The 90-161.Z logo, 128 px, in USAF colours ($AppLogoPng) and in Fulcrum colours ($AppLogoFulcrumPng): one render of
    # each for every script (scripts/logo_png.py).
    if not _logo:
        sys.path.insert(0, str(ROOT / 'scripts'))
        import logo_png
        text = ''
        for var, master in (('AppLogoPng', 'usaf'), ('AppLogoFulcrumPng', 'fulcrum')):
            b64 = base64.b64encode(logo_png.png(128, bool(CHECK), master)).decode('ascii')
            rows = [b64[i:i + 100] for i in range(0, len(b64), 100)]
            text += '$' + var + ' = @(\n' + ',\n'.join("  '" + r + "'" for r in rows) + "\n) -join ''\n"
        _logo.append(text)
    return _logo[0]


def ui_text():
    """Read the pinned shared UI file from the locked engine, once per run. Takes nothing; returns text with LF line ends."""
    # The pinned shared UI file, fetched and hash-checked by the bundle builder (one fetch for every script).
    if not _ui:
        sys.path.insert(0, str(ROOT / 'scripts'))
        import build_paste_bundles as B
        lock = json.loads(B.LOCK_FILE.read_text(encoding='utf-8'))
        _ui.append((B.fetch(lock) / 'engine/rade_ui.ps1').read_text(encoding='utf-8').replace('\r\n', '\n').rstrip('\n') + '\n')
    return _ui[0]


def body(src=SRC):
    """Get the text that a shared block in the task scripts must hold. Takes the source (a script file, or the LOGO or UI marker); returns text."""
    if src == LOGO:
        return logo_text()
    if src == UI:
        return ui_text()
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
