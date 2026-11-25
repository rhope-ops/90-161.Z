#!/usr/bin/env python3
"""R42 E3 check: every task script that signs in with the CAC web login sizes the sign-in window first.

The PFM (2026-11-21, docs/reviews/2026-11-21-r42-plan.md E3): the CAC sign-in window opens at about 480 x 360, in the
center of the screen. The RADE engine gives the code as one block (engine/ps/16-site-scripts.ps1); scripts/build_task_scripts.py
copies it between the "signin-size" markers. This check, for each scripts/gov/90161Z-T*.ps1 that a bundle in
scripts/paste_bundles.json carries:
- a script with "Connect-PnPOnline ... -UseWebLogin" holds the filled signin-size block, or is dot-sourced next to a
  file of the same task that holds it (the block runs in the same scope);
- each such Connect-PnPOnline line has a "Start-SignInSize" line within the 3 lines before it;
- with pwsh on the PATH and RADE_SIGNIN_TEST=1, the block loads and Start-SignInSize compiles its helper type (no window).

Network: none. Writes: none. Credentials: none.
Usage: python3 tests/check_signin_size.py   exit 0 = pass (last line SIGNIN pass ...), 1 = a failed check."""
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BEGIN = '# >>> signin-size: generated from'
CONNECT = re.compile(r'^\s*(\$null = & \{ )?Connect-PnPOnline\b.*-UseWebLogin')   # a code line, not help text


def bundle_scripts():
    """Return the paths of the task scripts the bundles carry (the .ps1 files of every bundle's "files" list)."""
    manifest = json.loads((ROOT / 'scripts/paste_bundles.json').read_text(encoding='utf-8'))
    return sorted({ROOT / f['src'] for b in manifest['bundles'] for f in b['files'] if f['src'].endswith('.ps1')})


def check_file(path, task_has_block):
    """Return the failure lines of one script (an empty list when it passes).

    Args:
        path: the script.
        task_has_block: True when a file of the same task in the bundle holds a filled block.
    """
    lines = path.read_text(encoding='utf-8').split('\n')
    bad = []
    hits = [i for i, x in enumerate(lines) if CONNECT.search(x) and not x.lstrip().startswith('#')]
    if hits and not task_has_block:
        bad.append('%s: signs in with -UseWebLogin but its task has no filled signin-size block' % path.name)
    for i in hits:
        if not any('Start-SignInSize' in x for x in lines[max(0, i - 3):i]):
            bad.append('%s:%d: no Start-SignInSize in the 3 lines before Connect-PnPOnline' % (path.name, i + 1))
    return bad


def filled(path):
    """Return True when the script holds the signin-size block with the function in it."""
    text = path.read_text(encoding='utf-8')
    return BEGIN in text and 'function Start-SignInSize' in text and '[scriptblock]::Create($SignInSizeCode)' in text


def compile_case(path):
    """Load the block of `path` in pwsh with RADE_SIGNIN_TEST=1 and return '' when the helper type compiles, else the error."""
    text = path.read_text(encoding='utf-8')
    block = text[text.index(BEGIN):text.index('# <<< signin-size')]
    code = block + "\nif (-not (Get-Command Start-SignInSize -ErrorAction Ignore)) { 'NOT COMPILED: not loaded' }\nStart-SignInSize\nif ('RadeSignIn.Size' -as [type]) { 'COMPILED' } else { 'NOT COMPILED' }\n"
    env = dict(__import__('os').environ, RADE_SIGNIN_TEST='1')
    r = subprocess.run(['pwsh', '-NoProfile', '-Command', code], capture_output=True, text=True, env=env, timeout=120)
    return '' if 'COMPILED' in r.stdout and 'NOT COMPILED' not in r.stdout else (r.stdout + r.stderr).strip()[-300:]


def main():
    """Run the checks; print the failures and the summary line. Returns the exit code."""
    files = [p for p in bundle_scripts() if p.name.startswith('90161Z-T')]
    tasks = {}
    for p in files:
        tasks.setdefault(p.name.split('-')[1], []).append(p)
    bad, signers, holders = [], 0, [p for p in files if filled(p)]
    for p in files:
        has = any(filled(q) for q in tasks[p.name.split('-')[1]])
        found = check_file(p, has)
        bad += found
        signers += any(CONNECT.search(x) for x in p.read_text(encoding='utf-8').split('\n'))
    if not signers:
        bad.append('no bundled script signs in: the check found nothing to check')
    if holders and shutil.which('pwsh'):
        err = compile_case(holders[0])
        if err:
            bad.append('the signin-size block does not compile in pwsh: ' + err)
    for x in bad:
        print('FAIL ' + x)
    print('SIGNIN %s scripts=%d signing-in=%d blocks=%d' % ('fail' if bad else 'pass', len(files), signers, len(holders)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
