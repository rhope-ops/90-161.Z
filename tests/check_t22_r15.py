#!/usr/bin/env python3
"""T22 r15 checks (round R42 T1: docs/reviews/2026-11-21-r42-plan.md; the R41 checks: docs/reviews/2026-11-21-r41-plan.md rows 1, 3, 4).

What it checks, on the window's text form (-PlanOnly; no window here: tests/ps/Test-T22Layout.ps1 measures the window on
the Windows job) and on the part files:
- the click-through (row 3): one WALK line per card, every card once, numbered 1 to 17 in order, each text one action
  ("Screen n of 17: select ... Pass if ... opens and looks right.") and at most 200 characters, starting on Your Work;
- the site read (row 1): the site part calls no command that adds, changes or removes anything on the site, reads each
  list with Get-PnPListItem, writes the WRITES=0 line and knows the repo's fake-data markers; the card pictures and the
  Feedback pictures ask for the marker check first;
- the Feedback save (review MINOR 1): a comment on a card whose site row has no marker saves the .txt only, logs
  "picture not saved" and the list names no .png; a card with marked rows saves both (a stand-in picture, no window);
- the grid fit (row 4, R40 finding 3): the self-check line names the open, the fit runs again after the layout settles,
  and the window notes each open for the click-through;
- R15 (R42 T1, R41 finding 4), the grid plan: for the 3 grids (Your Work, All Actions, Wave 1 answers), with the FAKE
  rows and with one site row, at 1920 x 1094 and 150 % (the R41 device; bar 26), at 1200 wide and 150 % and at 1280
  wide and 100 % (bar 17), and with a normal and a 1.25 x wider stand-in font: the column minimums fit beside the
  scroll bar and a kept Status chip ends a scroll bar's width before the grid edge, wherever the fill puts its column;
  the grid fit changes nothing in a grid that fits and fits one whose minimums are 42 px too wide, chip kept;
- R15, the walk path: each WALK step names a rail item, a button of the screen the step before opened (shown at every
  window size, needing nothing) or the bar's link; steps 10 and 11 open waves and step13; the bar's fallback link.

Network: none.
Writes: one temporary folder for the Feedback case and one for the grid case, each removed at the end (it runs pwsh on the cards and feedback parts).
Credentials: none.
Usage: python3 tests/check_t22_r15.py   exit 0 = pass (last line T22R15 PASS), 1 = a failed assertion."""
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GOV = ROOT / 'scripts/gov'


def need_pwsh():
    """Stop with a clear FAIL when pwsh is not installed (fleet v2: a missing tool fails the check, it never skips it).

    Takes nothing; returns nothing; exits 1 with the install pointer when pwsh is not on the PATH.
    """
    if not shutil.which('pwsh'):
        sys.exit('FAIL tests/check_t22_r15.py needs pwsh (PowerShell 7) for the walk and feedback cases; '
                 'install it (docs/dev-setup.md), then run again.')


def part(name):
    """The text of T22 part <name> r15. Takes the part name; returns the file text."""
    return (GOV / ('90161Z-T22-%s-r15.ps1' % name)).read_text(encoding='utf-8')


def check_walk():
    """The click-through plan of -PlanOnly. Takes nothing; raises AssertionError on a bad plan."""
    out = subprocess.run(['pwsh', '-NoProfile', '-File', str(GOV / '90161Z-T22-pfm-window-r15.ps1'), '-PlanOnly'],
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
    main = (GOV / '90161Z-T22-pfm-window-r15.ps1').read_text(encoding='utf-8')
    assert "foreach ($l in @(& $wn.WalkLines)) { $lines.Add($l) }" in main and 'Invoke-SiteRead $siteAt' in main, 'main script'


FEEDBACK_PS = r"""
$ErrorActionPreference = 'Stop'; $Rev = 'r15'; $dir = $args[0]; $who = $null; $lines = New-Object System.Collections.Generic.List[string]
$wn = @{ PngDir = '' }; $form = $null; $ui = @{}
function Hide-Site([string]$Text, [string]$Site) { return $Text }
function ConvertTo-Masked([string]$Text, $Secret) { return $Text }
function Get-SiteUnmarked([string]$Key) { if ($Key -eq 'home') { return 2 } else { return 0 } }
. $args[1]
$wn.PngSave = { param($Shot, [string]$Path) Set-Content -LiteralPath $Path -Value 'PNG' }; $shot = $null   # no System.Drawing off Windows
$a = & $wn.FeedbackSave 'home' 'FAKE comment one' $shot; $b = & $wn.FeedbackSave 'queue' 'FAKE comment two' $shot; & $wn.FeedbackList
$lines | ForEach-Object { 'LINE ' + $_ }
Get-ChildItem -LiteralPath $dir -Name | Sort-Object | ForEach-Object { 'FILE ' + $_ }
Get-Content -LiteralPath (Join-Path $dir '90161Z-T22-feedback-r15.txt') | ForEach-Object { 'LIST ' + $_ }
"""


def check_feedback():
    """MINOR 1: a blocked picture is not logged or listed as saved. Takes nothing; raises AssertionError."""
    import tempfile
    d = tempfile.mkdtemp()
    try:
        ps = pathlib.Path(d, 'case.ps1')
        ps.write_text(FEEDBACK_PS, encoding='utf-8')
        out = subprocess.run(['pwsh', '-NoProfile', '-File', str(ps), d, str(GOV / '90161Z-T22-feedback-r15.ps1')],
                             capture_output=True, text=True, timeout=60).stdout.splitlines()
        files = [l[5:] for l in out if l.startswith('FILE ')]
        lines = [l[5:] for l in out if l.startswith('LINE ')]
        lst = [l[5:] for l in out if l.startswith('LIST ')]
        assert 'FEEDBACK home: 90161Z-T22-feedback-home-r15.txt' in lines and 'FEEDBACK home: picture not saved (2 site rows without a fake-data marker)' in lines, out
        assert 'FEEDBACK queue: 90161Z-T22-feedback-queue-r15.txt and 90161Z-T22-feedback-queue-r15.png' in lines, out
        assert '90161Z-T22-feedback-home-r15.png' not in files and '90161Z-T22-feedback-queue-r15.png' in files and '90161Z-T22-feedback-home-r15.txt' in files, files
        assert '  90161Z-T22-feedback-home-r15.txt (picture not saved)' in lst and not any('home-r15.png' in l for l in lst + lines), lst
        assert '  90161Z-T22-feedback-queue-r15.txt and 90161Z-T22-feedback-queue-r15.png' in lst, lst
    finally:
        shutil.rmtree(d, ignore_errors=True)


# R15 (R42 T1; R41 finding 4): the column plan of the 3 grids, as arithmetic. Text widths come from a stand-in (px per
# character of the font at the dpi; Font = 'normal' or 'wide', 1.25 x), not from Windows; the grid part's own
# $wn.TextW and $wn.BarW are replaced, every other function is the grid part's. The grid widths follow the window
# part's layout ($wn.ShowCols): rail, page column, side column and section padding. Lines: PLAN and FIT (see the case).
GRID_PS = r"""
$ErrorActionPreference = 'Stop'; $Again = $false; $lines = New-Object System.Collections.Generic.List[string]
. $args[1]; . $args[2]   # the cards part (FAKE rows, columns, cards) and the site part (its row conversion)
$wn = @{}; $ui = @{ Dpi = 96.0; F = @{} }; $pc = @{}
$ui.Sc = { param([double]$Px) [int][math]::Round($Px * $ui.Dpi / 96.0) }; $wn.Sc = { param([double]$Px) & $ui.Sc $Px }
. $args[0]
$wn.TextW = { param([string]$Text, $F) return [int][math]::Ceiling($Text.Length * [double]$F) }
$script:bar = 26; $wn.BarW = { return $script:bar }
# The width of grid $Name on card $Key at client width $Client (the window part's arithmetic, $wn.ShowCols).
function Get-GridW([int]$Client, [string]$Key, [string]$Name) {
  $wide = ($Client -ge (& $ui.Sc 1500)); $rail = $(if ($wide) { & $ui.Sc 220 } else { & $ui.Sc 200 })
  $cw = [math]::Max((& $ui.Sc 900), $Client - $rail - $script:bar - 2 * (& $ui.Sc 28)); $c = $Cards[$Key]; $nc = @($c.Cols).Count
  $side = $(if ($nc -le 1) { 0 } elseif ($Key -eq 'home') { $(if ($wide) { & $ui.Sc 420 } else { & $ui.Sc 300 }) } else { & $ui.Sc $c.Side })
  $colW = $(if ($nc -le 1) { [math]::Min($cw, (& $ui.Sc 1000)) } else { $cw - $side - (& $ui.Sc 18) })
  foreach ($s in @($c.Cols[0])) { foreach ($b in @($s.Blocks)) { if ($b.T -eq 'grid' -and $b.Name -eq $Name) {
        $px = $(if ($s.Pad) { [int]$s.Pad } else { 24 }); return @{ W = $colW - 2 * (& $ui.Sc $px); B = $b } } } }
  throw ('no grid ' + $Name + ' on ' + $Key) }
$day = [datetime]'2026-11-20'
$pubIt = @{ Title = '90161Z TEST publication for the window round'; PublicationNumber = '90161Z TEST 1'; ActionType = 'Review'
  ProcessStep = '8 PFM check'; ActionStatus = 'On Track'; CoordinationSuspense = $day; Modified = $day }
$site = ConvertTo-SitePubRow @($pubIt)
$ans = @(ConvertTo-SiteAnswerRow @(@{ Title = '90161Z TEST Office 1'; EndorsementStatus = 'Concur With Comment'; ResponseDate = $day }))
$grids = @(@('home', 'Who has it now', $site.Home), @('queue', 'All actions', $site.Queue), @('waves', 'Wave 1 answers', $ans))
foreach ($case in @(@(1920, 144, 26), @(1200, 144, 26), @(1280, 96, 17))) {
  $ui.Dpi = [double]$case[1]; $script:bar = [int]$case[2]
  foreach ($font in 'normal', 'wide') {
    $k = $(if ($font -eq 'wide') { 1.25 } else { 1.0 }) * $ui.Dpi / 96.0
    $ui.F = @{ Small = 7.0 * $k; SmallB = 7.6 * $k; Link = 7.6 * $k }
    foreach ($g in $grids) { foreach ($src in 'fake', 'site') {
        $at = Get-GridW $case[0] $g[0] $g[1]; $rows = $(if ($src -eq 'site') { @($g[2]) } else { @($at.B.Rows) })
        $pw = & $wn.PubWidths $rows; $cols = & $wn.DropCols @($at.B.Cols) $at.W $pw $rows
        $p = & $wn.ColPlan $cols $at.W 0 (& $wn.PubMin $cols $pw) $rows
        $sum = 0; foreach ($v in $p.Min.Values) { $sum += $v }; $last = @($cols)[-1]
        $chip = 0; foreach ($r in $rows) { $chip = [math]::Max($chip, (& $wn.TextW ([string]$r.Status) $ui.F.SmallB)) }
        # the worst place of the chip: its column at its minimum and every column before it as wide as the fill makes it
        $end = $at.W - [int]$p.Min[[string]$last.N] + (& $ui.Sc 10) + $chip + (& $ui.Sc 20)
        'PLAN ' + $g[0] + ' ' + $case[0] + '@' + $case[1] + ' ' + $font + ' ' + $src + ' W=' + $at.W + ' bar=' + $script:bar + ' room=' + $p.Room +
          ' sum=' + $sum + ' last=' + $last.K + ' kept=' + $p.ChipKept + ' end=' + $end } } } }
# FIT: the grid fit on a stand-in grid at 1920 x 1094 and 150 % (normal font, FAKE rows): "fits" is a grid whose columns
# fill the whole grid with no bar shown (r14 took 26 px from the chip on each pass), "over" has minimums 42 px wider
# than the room (in its widest plain column).
$ui.Dpi = 144.0; $script:bar = 26; $ui.F = @{ Small = 10.5; SmallB = 11.4; Link = 11.4 }
foreach ($g in $grids) { foreach ($kind in 'fits', 'over') {
    $at = Get-GridW 1920 $g[0] $g[1]; $rows = @($at.B.Rows); $pw = & $wn.PubWidths $rows; $cols = & $wn.DropCols @($at.B.Cols) $at.W $pw $rows
    $p = & $wn.ColPlan $cols $at.W 0 (& $wn.PubMin $cols $pw) $rows
    $gc = @(); $kinds = @{}; foreach ($c in $cols) { $kinds[[string]$c.N] = [string]$c.K
      $gc += [pscustomobject]@{ Name = [string]$c.N; Visible = $true; MinimumWidth = [int]$p.Min[[string]$c.N]; Width = [int]$p.Min[[string]$c.N] } }
    $s = 0; foreach ($c in $gc) { $s += $c.Width }; $x = $at.W - 28 - $s + 42   # over: 42 px more than the room
    if ($kind -eq 'over') { $pl = @($gc | Where-Object { $kinds[$_.Name] -eq 'plain' } | Sort-Object MinimumWidth -Descending)[0]; $pl.MinimumWidth += $x; $pl.Width += $x }
    else { $gc[0].Width += $at.W - $s }   # fits: the fill gives the rest of the grid to the first column
    $grid = [pscustomobject]@{ ClientSize = @{ Width = $at.W }; Width = $at.W; Columns = $gc; Tag = @{ Kind = $kinds; Cols = $cols } }
    $chipName = [string](@($cols | Where-Object { $_.K -eq 'chip' })[0].N); $chip0 = [int](@($gc | Where-Object { $_.Name -eq $chipName })[0].MinimumWidth)
    $changed = & $wn.FitGrid $grid; $sum = 0; foreach ($c in $gc) { $sum += $c.MinimumWidth }
    $chip1 = [int](@($gc | Where-Object { $_.Name -eq $chipName })[0].MinimumWidth)
    'FIT ' + $g[0] + ' ' + $kind + ' changed=' + $changed + ' sum=' + $sum + ' room=' + ($at.W - 26 - 2) + ' chip=' + $chip0 + '>' + $chip1 } }
"""


def check_grid_plan():
    """R15 (R41 finding 4): the planned columns of the 3 grids end a scroll bar before the grid edge, and the grid fit
    keeps a grid that fits as it is and fits one that does not. Takes nothing; raises AssertionError."""
    import tempfile
    d = tempfile.mkdtemp()
    try:
        ps = pathlib.Path(d, 'grid.ps1')
        ps.write_text(GRID_PS, encoding='utf-8')
        res = subprocess.run(['pwsh', '-NoProfile', '-File', str(ps), str(GOV / '90161Z-T22-grid-r15.ps1'),
                              str(GOV / '90161Z-T22-cards-r15.ps1'), str(GOV / '90161Z-T22-site-r15.ps1')],
                             capture_output=True, text=True, timeout=120)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    out = res.stdout.splitlines()
    plan = [dict(x.split('=', 1) for x in l.split()[5:]) | {'at': l.split()[1:5]} for l in out if l.startswith('PLAN ')]
    assert len(plan) == 36, (res.stdout, res.stderr)
    # the R41 device: client 1920 x 1094 at 144 dpi gives the grid widths the window logged (961, 1428, 871)
    assert sorted({(p['at'][0], p['W']) for p in plan if p['at'][1] == '1920@144'}) == [('home', '961'), ('queue', '1428'), ('waves', '871')], plan
    for p in plan:
        w, bar, room, s, end = (int(p[k]) for k in ('W', 'bar', 'room', 'sum', 'end'))
        assert room == w - bar - 2 and s <= room, ('the column minimums need more than the room beside the scroll bar', p)
        assert p['last'] == 'chip' and p['kept'] in ('True', 'False'), p
        if p['kept'] == 'True':
            assert end <= w - bar, ('the Status chip can end under the scroll bar', p)
        if p['at'][1] == '1920@144' and p['at'][2] == 'normal':
            assert p['kept'] == 'True', ('at the R41 size the Status chip must be kept whole', p)
    fit = {tuple(l.split()[1:3]): dict(x.split('=', 1) for x in l.split()[3:]) for l in out if l.startswith('FIT ')}
    assert len(fit) == 6, res.stdout
    for (g, kind), f in fit.items():
        c0, c1 = f['chip'].split('>')
        if kind == 'fits':
            assert f['changed'] == 'False' and c0 == c1, ('the grid fit changed a grid that fits', g, f)
        else:
            assert f['changed'] == 'True' and int(f['sum']) <= int(f['room']) and c0 == c1, ('the grid fit', g, f)


def check_walk_path():
    """R15 (R41 finding 4): each walk step names a control that is on the screen shown at that step: a rail item, a
    button of the card the step before opened (not in a wide-only section, needing nothing), or the bar's own link.
    Takes nothing; raises AssertionError."""
    out = subprocess.run(['pwsh', '-NoProfile', '-File', str(GOV / '90161Z-T22-pfm-window-r15.ps1'), '-PlanOnly'],
                         capture_output=True, text=True, timeout=120, cwd=ROOT).stdout.splitlines()
    rail, buttons, key, wide = {}, {}, None, False
    for l in out:
        if l.startswith('CARD '):
            key = l.split(' | ')[0][5:]; buttons[key] = {}; wide = False
        elif l.startswith('  SECTION '):
            wide = l.endswith(' [wide only]')
        elif l.startswith('RAIL '):
            t, go = l[5:].rsplit(' -> ', 1); rail[t] = go
        elif key and not wide and l.lstrip().startswith(('BUTTON ', 'LINK ')) and ' -> ' in l and '[needs' not in l:
            t, go = l.strip().split(' ', 1)[1].rsplit(' -> ', 1)
            buttons[key][t.replace(' (blue)', '')] = go
    cur = 'home'
    for l in [l for l in out if l.startswith('WALK ')]:
        m = re.match(r'WALK (\d+) (\S+) (rail|button|link|open): Screen \d+ of 17: select (.+?)\. Pass if', l)
        n, to, via, what = m.groups()
        if via == 'rail':
            assert rail.get(what[:-len(' in the list on the left')]) == to, ('no rail item opens it', l)
        elif via == 'button':
            name = re.match(r'"([^"]+)"', what).group(1)
            assert buttons[cur].get(name) == to, ('the button is not on the screen of the step before (%s)' % cur, l)
        else:
            assert via == 'open' and what == '"Open this screen" in this bar', l
        cur = to
    assert ('waves', 'step13') == tuple(re.match(r'WALK \d+ (\S+) (\S+):', l).group(1) for l in out if l.startswith(('WALK 10 ', 'WALK 11 '))), out
    bar = part('bar')
    for x in ("[string]$Walk[$j].From -ne [string]$wn.Cur", '& $wn.OpenFail $k $_', "'NOTE the screen ' + $Key + ' did not open: '"):
        assert x in bar, 'the bar part lacks ' + x


def check_ui_names():
    """Each $ui.<Name> that a T22 part calls is defined in the T22 files (fleet v2, 2026-11-23: engine-v36 moved
    $ui.Meas into engine/rade_ui_text.ps1, and a window that copied only engine/rade_ui.ps1 stopped on Windows).
    The two copied UI blocks (-ui-, -ui2-) are left out as callers: their calls are the engine's own.
    Takes nothing; raises AssertionError with the missing names.
    """
    defined, used = set(), set()
    for f in sorted(GOV.glob('90161Z-T22-*-r15.ps1')):
        t = f.read_text(encoding='utf-8')
        defined |= set(re.findall(r'^\s*\$ui\.(\w+)\s*=', t, re.M))
        if not re.search(r'-ui2?-r15\.ps1$', f.name):
            used |= set(re.findall(r'&\s*\$ui\.(\w+)', t))
    assert not used - defined, 'T22 calls $ui names that no T22 file defines: ' + ', '.join(sorted(used - defined))

if __name__ == '__main__':
    check_ui_names()   # no pwsh needed
    need_pwsh()
    check_feedback()
    check_walk()
    check_parts()
    check_grid_plan()
    check_walk_path()
    print('T22R15 PASS')
    sys.exit(0)
