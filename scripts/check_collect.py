#!/usr/bin/env python3
"""No scripts in results (the PFM, 2026-11-20; AGENTS.md Project rules).

Why: in R37 the collect name "90161Z-T22-feedback-*" also matched the runner 90161Z-T22-feedback-r10.ps1, and the
work e-mail gateway blocked the whole results e-mail as unsafe.

What it checks: every collect name in scripts/paste_bundles.json must end in an allowed result extension
(.txt .png .pdf .csv .json .log .docx .xlsx); a name that ends in a wildcard, has no extension, or names a script
extension fails. Used by scripts/build_paste_bundles.py (before every build) and tests/run.sh.

Usage: python3 scripts/check_collect.py [--test]   exit 0 = pass, 1 = a bad collect name (each printed as FAIL)."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# Result files a round may send. Anything else (scripts, programs, shortcuts, archives) never goes in results.
ALLOWED = ('.txt', '.png', '.pdf', '.csv', '.json', '.log', '.docx', '.xlsx')


def bad_name(name):
    """Return the reason a collect name can pick up a non-result file, or '' when it is safe. Takes the name."""
    low = name.lower()
    if low.endswith(('*', '?')):
        return 'ends in a wildcard, so it can match a script'
    if not low.endswith(ALLOWED):
        return 'does not end in a result extension (' + ' '.join(ALLOWED) + ')'
    return ''


def check(manifest):
    """Check every collect name of every round in the manifest dict. Returns a list of FAIL lines (empty = pass)."""
    fails = []
    for b in manifest.get('bundles', []):
        for c in b.get('collect', []):
            why = bad_name(c.get('name', ''))
            if why:
                fails.append('FAIL %s collect "%s" %s (no scripts in results: the PFM, 2026-11-20)'
                             % (b.get('round', '?'), c.get('name'), why))
    return fails


def self_test():
    """Known good and bad names. Returns 0 when each gives the expected answer."""
    cases = {'90161Z-T22-feedback-*': True, '90161Z-T22-feedback-*.txt': False, '90161Z-T22-feedback-*.png': False,
             'x.ps1': True, 'x.PS1': True, 'x.zip': True, 'SAMPLE.pdf': False, 'x': True, 'x.tx?': True}
    wrong = [n for n, want in cases.items() if bool(bad_name(n)) != want]
    for n in wrong:
        print('FAIL self-test: %s' % n)
    return 1 if wrong else 0


if __name__ == '__main__':
    if '--test' in sys.argv[1:]:
        sys.exit(self_test())
    out = check(json.loads((ROOT / 'scripts/paste_bundles.json').read_text(encoding='utf-8')))
    for line in out:
        print(line)
    print('collect names: %d bad' % len(out))
    sys.exit(1 if out else 0)
