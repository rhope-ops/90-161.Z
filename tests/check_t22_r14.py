#!/usr/bin/env python3
"""T22 r14 checks (round R41; the PFM, 20 Nov 26: docs/reviews/2026-11-21-r41-plan.md rows 1, 3 and 4).

What it checks, on the window's text form (-PlanOnly; no window here: tests/ps/Test-T22Layout.ps1 measures the window on
the Windows job) and on the part files:
- the click-through (row 3): one WALK line per card, every card once, numbered 1 to 17 in order, each text one action
  ("Screen n of 17: select ... Pass if ... opens and looks right.") and at most 200 characters, starting on Your Work;
- the site read (row 1): the site part calls no command that adds, changes or removes anything on the site, reads each
  list with Get-PnPListItem, writes the WRITES=0 line and knows the repo's fake-data markers; the card pictures and the
  Feedback pictures ask for the marker check first;
- the grid fit (row 4, R40 finding 3): the self-check line names the open, the fit runs again after the layout settles,
  and the window notes each open for the click-through.

Network: none.
Writes: nothing (it runs pwsh on the cards part and reads the part files).
Credentials: none.
Usage: python3 tests/check_t22_r14.py   exit 0 = pass (last line T22R14 pass), 1 = a failed assertion."""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GOV = ROOT / 'scripts/gov'


def part(name):
    """The text of T22 part <name> r14. Takes the part name; returns the file text."""
    return (GOV / ('90161Z-T22-%s-r14.ps1' % name)).read_text(encoding='utf-8')


def check_walk():
    """The click-through plan of -PlanOnly. Takes nothing; raises AssertionError on a bad plan."""
    out = subprocess.run(['pwsh', '-NoProfile', '-File', str(GOV / '90161Z-T22-pfm-window-r14.ps1'), '-PlanOnly'],
                         capture_output=True, text=True, timeout=120, cwd=ROOT).stdout.splitlines()
    cards = [l.split(' | ')[0][5:] for l in out if l.startswith('CARD ')]
    pat = r'WALK (\d+) (\S+) (rail|button|link|open): (Screen (\d+) of (\d+): select .+\. Pass if .+ opens and looks right\.)$'
    wk = [re.match(pat, l) for l in out if l.startswith('WALK ')]
    assert len(wk) == len(cards) == 17 and all(wk), [l for l in out if l.startswith('WALK ')]
    assert sorted(m.group(2) for m in wk) == sorted(cards) and [int(m.group(1)) for m in wk] == list(range(1, 18)), wk
    assert all(len(m.group(4)) <= 200 and m.group(5) == m.group(1) and m.group(6) == '17' for m in wk), wk
    assert wk[0].group(2) == 'home' and all(ord(c) < 128 for m in wk for c in m.group(0)), wk[0].group(0)


def check_parts():
    """The site part reads only; pictures ask the marker check; the grid fit settles. Takes nothing; raises AssertionError."""
    site = part('site')
    assert not re.search(r'\b(Add|Set|Remove|New|Update|Clear|Move|Copy|Restore)-PnP|Invoke-PnPSPRestMethod|-Method\s+(Post|Merge|Put|Patch|Delete)', site), 'the site part must not write'
    assert "Get-PnPListItem -List $l" in site and "$lines.Add('WRITES=0')" in site, 'the site read or its WRITES=0 line'
    assert "$script:FakeMarks = @('90161Z TEST', 'XXX XXX ')" in site, 'the fake-data markers'
    for p in ('measure', 'feedback'):
        assert '$bad = Get-SiteUnmarked $Key' in part(p), 'no marker check before a picture in the %s part' % p
    w = part('window')
    for x in ("' (open: ' + $wn.OpenKind + ')'", '& $wn.FitSettled', '$wn.FitTries -lt 3', '& $wn.WalkSeen $Key'):
        assert x in w, 'the window part lacks ' + x
    main = (GOV / '90161Z-T22-pfm-window-r14.ps1').read_text(encoding='utf-8')
    assert "foreach ($l in @(& $wn.WalkLines)) { $lines.Add($l) }" in main and 'Invoke-SiteRead $siteAt' in main, 'main script'


if __name__ == '__main__':
    check_walk()
    check_parts()
    print('T22R14 pass')
    sys.exit(0)
