# Tests the look of the T22 PFM window r6 by measurement (round R30: the R29b defects V2 to V4 and the accessible names;
# round R31: the rail head W1, the high-contrast colors W2 and the card pictures W4).
# Network: none.
# Writes: one temporary folder with the measure file and the card pictures of the window; removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Windows only: elsewhere the one line "T22LAYOUT SKIP ..." and exit 0.
# Runs scripts/gov/90161Z-T22-pfm-window-r6.ps1 -Measure <file> -NoPause in a child of the same engine (the window is built
# off-screen, measured and closed; no question) and checks what it wrote: each crumb's link and rest have one font and size
# (V2), the ink gap after the link is at most 8 px at 100 % (V2), step 8 has no "See the 0 findings" link (V3), step 8's
# Action Status card ends within 2 px of the main card (V4), Full History is drawn like the other white secondary
# buttons (V4), and no button, link or text box lacks an accessible name. R31: the logo's middle and the app name's
# middle differ by at most 2 px at this scale and at 1.5 x, with the rail's color behind the logo (W1); the color choice
# gives system colors with high contrast on and the own palette with it off, with no change of the Windows theme (W2);
# one picture per card was saved and the first one is not blank (W4). R6 (R31b D1 to D4), at the runner's scale and at
# 1.25 x and 1.5 x: each Action Status caption is level with the main card's first line (D1), each crumb's link and rest
# have one size and one text middle (D2), each check chip is level with its first text line (D3), and the titles of each
# pub grid start in one column, after the widest number and the gap or under the number (D4); 1 px at 100 %, scaled.
# Each line shows the measured numbers.
# Last line: "T22LAYOUT pass=N fail=0" (tests/ps/Invoke-Ps51.ps1 runs it on the ps51 Windows job).
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { Write-Host 'T22LAYOUT SKIP not Windows: the window needs Windows Forms (the ps51 Windows job runs this test)'; exit 0 }
$script:pass = 0; $script:fail = 0
# Record one result and print PASS or FAIL with its numbers. Takes the test name, the condition and the measured numbers; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Numbers = '') {
  if ($Ok) { $script:pass++; Write-Host ('T22LAYOUT PASS ' + $Name + ': ' + $Numbers) } else { $script:fail++; Write-Host ('T22LAYOUT FAIL ' + $Name + ': ' + $Numbers) }
}
# A font of the measure file as text: name, size in points, style, height in pixels.
function Format-Font($F) { return ([string]$F.Name + ' ' + $F.Size + ' pt ' + $F.Style + ' ' + $F.Height + ' px') }
# The cards whose crumb has a link (the R29b screenshots showed V2 on these six).
$crumbCards = @('step8', 'confirm', 'sendback', 'step11', 'step12', 'remindall')
# Check the crumb of one card: one font and size for link and rest, and the ink gap after the link at most $Limit pixels.
function Test-Crumb([string]$Key, $Card, [int]$Limit) {
  $cr = $Card.Crumb
  if (-not $cr) { Test-That ($Key + ' crumb has a link') $false 'no crumb link measured'; return }
  $same = ([string]$cr.LinkFont.Name -eq [string]$cr.RestFont.Name -and [double]$cr.LinkFont.Size -eq [double]$cr.RestFont.Size -and [int]$cr.LinkFont.Height -eq [int]$cr.RestFont.Height)
  Test-That ($Key + ' crumb: one font and size') $same ('link ' + (Format-Font $cr.LinkFont) + '; rest ' + (Format-Font $cr.RestFont))
  $gapOk = ($null -ne $cr.GapInk -and [int]$cr.GapInk -ge 0 -and [int]$cr.GapInk -le $Limit)
  $nums = 'ink gap ' + $cr.GapInk + ' px, limit ' + $Limit + ' px; control gap ' + $cr.GapBounds + ' px'
  $nums += '; link ' + $cr.LinkBounds + ' last ink ' + $cr.LinkInk + ', rest ' + $cr.RestBounds + ' first ink ' + $cr.RestInk
  Test-That ($Key + ' crumb: gap after the link') $gapOk $nums
}
<#
.SYNOPSIS
Checks step 8: no link to 0 findings (V3), the Action Status card's bottom on the main card's bottom (V4), and Full
History drawn like the white secondary button "Send Back to the AO" (V4).
.PARAMETER Card
The measured step 8 card from the measure file.
#>
function Test-Step8($Card) {
  $zero = @($Card.Buttons | Where-Object { [string]$_.Text -match '0 findings' })
  Test-That 'step8: no "See the 0 findings" link' ($zero.Count -eq 0) ('links and buttons on the card: ' + @($Card.Buttons).Count + ', with "0 findings": ' + $zero.Count)
  $secs = @($Card.Sections); $side = @($secs | Where-Object { [string]$_.Cap -eq 'Action Status' }) | Select-Object -First 1
  $main = @($secs | Where-Object { [int]$_.Col -eq 0 }) | Select-Object -Last 1
  $ok = [bool]($side -and $main -and [math]::Abs([int]$side.Bottom - [int]$main.Bottom) -le 2)
  Test-That 'step8: Action Status bottom = main card bottom (+-2 px)' $ok ('Action Status bottom ' + $side.Bottom + ' px, main card bottom ' + $main.Bottom + ' px')
  $fh = @($Card.Buttons | Where-Object { [string]$_.Text -eq 'Full History' }) | Select-Object -First 1
  $ref = @($Card.Buttons | Where-Object { [string]$_.Text -eq 'Send Back to the AO' }) | Select-Object -First 1
  $ok = [bool]($fh -and $ref -and $fh.Back -eq '#FFFFFF' -and $fh.Back -eq $ref.Back -and $fh.Face -eq $ref.Face -and $fh.Edge -eq $ref.Edge)
  $nums = 'Full History back ' + $fh.Back + ' face ' + $fh.Face + ' edge ' + $fh.Edge + '; Send Back to the AO back ' + $ref.Back + ' face ' + $ref.Face + ' edge ' + $ref.Edge
  Test-That 'step8: Full History is a white secondary button' $ok $nums
}
<#
.SYNOPSIS
Checks the rail head at each measured scale (R31 W1): the logo's vertical middle and the app name's vertical middle
differ by at most 2 px, and the color behind the logo is the rail's color (no white box).
.PARAMETER M
The measure file (Head, HeadError).
#>
function Test-RailHead($M) {
  $heads = @($M.Head)
  Test-That 'rail head measured at 2 scales' ($heads.Count -eq 2) ('scales ' + $heads.Count + $(if ($M.HeadError) { '; error: ' + $M.HeadError } else { '' }))
  foreach ($h in $heads) {
    $d = [math]::Abs([double]$h.LogoMid - [double]$h.NameMid)
    $nums = 'logo ' + $h.Logo + ' middle ' + $h.LogoMid + '; name ' + $h.Name + ' middle ' + $h.NameMid + '; difference ' + $d + ' px'
    Test-That ('rail head ' + $h.At + ': title middle = logo middle (+-2 px)') ($d -le 2) $nums
    Test-That ('rail head ' + $h.At + ': logo back = rail back') ([string]$h.LogoBack -eq [string]$h.RailBack) ('logo back ' + $h.LogoBack + ', rail back ' + $h.RailBack) }
}
<#
.SYNOPSIS
Checks the high-contrast color choice (R31 W2), with no change of the Windows theme: with high contrast on, every
palette color is the system color its role names; with it off, every color is the window's own.
.PARAMETER M
The measure file (Contrast, ContrastError).
#>
function Test-Contrast($M) {
  $rows = @($M.Contrast); $on = @($rows | Where-Object { $_.High }); $off = @($rows | Where-Object { -not $_.High })
  $badOn = @($on | Where-Object { -not $_.System -or -not $_.Role -or [string]$_.Name -ne [string]$_.Role })
  $nums = 'colors ' + $on.Count + ', not the system color of their role: ' + $badOn.Count + ' ' + (@($badOn | ForEach-Object { $_.Table + '.' + $_.Key + '=' + $_.Name }) -join ', ')
  if ($M.ContrastError) { $nums += '; error: ' + $M.ContrastError }
  Test-That 'high contrast on: the system colors' ($on.Count -gt 0 -and $badOn.Count -eq 0) $nums
  $badOff = @($off | Where-Object { $_.System -or [string]$_.Hex -ne [string]$_.Own })
  $nums = 'colors ' + $off.Count + ', changed: ' + $badOff.Count + ' ' + (@($badOff | ForEach-Object { $_.Table + '.' + $_.Key }) -join ', ')
  Test-That 'high contrast off: the own palette' ($off.Count -eq $on.Count -and $badOff.Count -eq 0) $nums
}
<#
.SYNOPSIS
Checks the card pictures (R31 W4): one PNG file per card, named 90161Z-T22-card-<card>-r6.png, saved in the folder of
the measure file, and the first one is not blank (at least 3 colors in a 20 x 20 grid of its pixels).
.PARAMETER M
The measure file (Cards, Pngs).
.PARAMETER Dir
The folder of the measure file.
#>
function Test-CardPng($M, [string]$Dir) {
  $want = @($M.Cards | ForEach-Object { '90161Z-T22-card-' + $_.Key + '-' + $M.Rev + '.png' })
  $have = @($want | Where-Object { (Test-Path -LiteralPath (Join-Path $Dir $_) -PathType Leaf) -and (Get-Item -LiteralPath (Join-Path $Dir $_)).Length -gt 0 })
  $ok = ($want.Count -gt 0 -and $have.Count -eq $want.Count -and @($M.Pngs).Count -eq $want.Count)
  Test-That 'one picture per card' $ok ('saved ' + $have.Count + ' of ' + $want.Count + ' cards; listed ' + @($M.Pngs).Count)
  $n = 0
  if ($have.Count) {
    Add-Type -AssemblyName System.Drawing
    $bm = New-Object System.Drawing.Bitmap((Join-Path $Dir $have[0]))
    try {
      $seen = @{}
      for ($i = 0; $i -lt 20; $i++) { for ($j = 0; $j -lt 20; $j++) { $seen[$bm.GetPixel([int]($bm.Width * ($i + 0.5) / 20), [int]($bm.Height * ($j + 0.5) / 20)).ToArgb()] = 1 } }
      $n = $seen.Count
    } finally { $bm.Dispose() } }
  Test-That 'the first card picture is not blank' ($n -ge 3) ('colors in a 20 x 20 grid: ' + $n + $(if ($have.Count) { ' (' + $have[0] + ')' } else { '' }))
}
# The cards with an Action Status card (D1) and the cards with a grid of publications (D4): each must have its facts.
$levelCaps = @('step8', 'waves', 'step11', 'step13', 'pub')
$levelPubs = @('home', 'empty', 'queue')
<#
.SYNOPSIS
Checks D1 to D4 (R6, the R31b defects) on the alignment facts (Level) of every card measured at one scale.
.DESCRIPTION
D1: on each card of $levelCaps, each Action Status caption's middle is within the tolerance of the main card's first
line. D2: on each card with a crumb link (the cards of $crumbCards at least), link and rest have one font size and
their text middles are within the tolerance. D3: each check chip (step 8 has one at least) is within the tolerance of
its first text line. D4: each pub grid (one at least on each card of $levelPubs) drew 2 rows or more, all its titles
start at one x, and that x is at or after the widest number's end and the gap (titles beside) or each title starts at
or below its number's bottom (titles under). The tolerance is 1 px at 100 %: Sc8 / 8, at least 1.
.PARAMETER Cards
The measured cards (Key, Level) of one scale.
.PARAMETER Sc8
8 px at 100 %, at this scale.
.PARAMETER At
The scale, as text (it starts each line).
#>
function Test-Level($Cards, [double]$Sc8, [string]$At) {
  $tol = [math]::Max(1.0, $Sc8 / 8.0); $byKey = @{}; foreach ($c in @($Cards)) { $byKey[[string]$c.Key] = $c }
  foreach ($k in @($byKey.Keys | Sort-Object)) {
    $lv = $byKey[$k].Level; if (-not $lv) { continue }
    $caps = @($lv.Caps | Where-Object { $_ })
    if ($levelCaps -contains $k -and -not $caps.Count) { Test-That ($At + ' D1 ' + $k + ': Action Status caption measured') $false 'no caption measured' }
    foreach ($x in $caps) { $d = [math]::Abs([double]$x.CapMid - [double]$x.LineMid)
      $nums = 'caption "' + $x.Cap + '" middle ' + $x.CapMid + '; first line "' + $x.Line + '" middle ' + $x.LineMid + '; difference ' + $d + ' px'
      Test-That ($At + ' D1 ' + $k + ': caption level with the first line of the main card (+-' + $tol + ' px)') ($d -le $tol) $nums }
    $cr = $lv.Crumb
    if ($crumbCards -contains $k -and -not $cr) { Test-That ($At + ' D2 ' + $k + ': crumb link measured') $false 'no crumb link measured' }
    if ($cr) { $d = [math]::Abs([double]$cr.LinkMid - [double]$cr.RestMid); $ok = ([double]$cr.LinkSize -eq [double]$cr.RestSize -and $d -le $tol)
      $nums = 'link ' + $cr.LinkSize + ' pt middle ' + $cr.LinkMid + '; rest ' + $cr.RestSize + ' pt middle ' + $cr.RestMid + '; difference ' + $d + ' px'
      Test-That ($At + ' D2 ' + $k + ': crumb link and rest, one size and one middle (+-' + $tol + ' px)') $ok $nums }
    $chips = @($lv.Chips | Where-Object { $_ })
    if ($k -eq 'step8' -and -not $chips.Count) { Test-That ($At + ' D3 step8: chip "Passed" measured') $false 'no check chip measured' }
    foreach ($x in $chips) { $d = [math]::Abs([double]$x.ChipMid - [double]$x.LineMid)
      $nums = 'chip middle ' + $x.ChipMid + '; first line middle ' + $x.LineMid + '; difference ' + $d + ' px'
      Test-That ($At + ' D3 ' + $k + ': chip "' + $x.Chip + '" level with its first text line (+-' + $tol + ' px)') ($d -le $tol) $nums }
    $pubs = @($lv.Pubs | Where-Object { $_ })
    if ($levelPubs -contains $k -and -not $pubs.Count) { Test-That ($At + ' D4 ' + $k + ': publication grid measured') $false 'no pub grid measured' }
    foreach ($p in $pubs) {
      $n = [int]$p.Rows; $xs = @(@($p.TitleX) | Sort-Object -Unique); $beside = @($p.Beside) -contains $true
      $num = [int](@($p.NumRight) | Measure-Object -Maximum).Maximum
      $low = @(for ($i = 0; $i -lt $n; $i++) { if ([int]@($p.TitleTop)[$i] -lt [int]@($p.NumBottom)[$i]) { $i } })
      $ok = ($n -ge 2 -and $xs.Count -eq 1 -and $(if ($beside) { [int]$xs[0] -ge $num + [int]$p.Gap } else { $low.Count -eq 0 }))
      $how = $(if ($beside) { 'beside: widest number ends at ' + $num + ', gap ' + $p.Gap } else { 'under: titles above their number bottom ' + $low.Count })
      $nums = 'rows drawn ' + $n + '; title x ' + ($xs -join ', ') + '; ' + $how
      Test-That ($At + ' D4 ' + $k + ' ' + $p.Grid + ': titles start in one column') $ok $nums } }
}
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('t22layout-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tmp)
try {
  $file = Join-Path $tmp 'measure.json'
  $engine = (Get-Process -Id $PID).Path
  $window = Join-Path $Root 'scripts/gov/90161Z-T22-pfm-window-r6.ps1'
  $ErrorActionPreference = 'Continue'   # the child's error output is shown below, not thrown here
  $log = @(& $engine -NoProfile -ExecutionPolicy Bypass -File $window -Measure $file -NoPause 2>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE; $ErrorActionPreference = 'Stop'
  $built = ($code -eq 0 -and (Test-Path -LiteralPath $file))
  Test-That 'the window was built off-screen and measured' $built ('exit ' + $code + '; last line: ' + (@($log | Where-Object { $_.Trim() }) | Select-Object -Last 1))
  # Invoke-Ps51 shows only lines with FAIL in them: the child's STOPPED and NOTE lines are repeated as FAIL lines, so the CI log names the cause.
  if (-not $built) { @($log | Where-Object { $_ -match '^\s*(STOPPED|NOTE)' }) | ForEach-Object { Write-Host ('T22LAYOUT FAIL child: ' + $_.Trim()) }
    @($log | Select-Object -Last 15) | ForEach-Object { Write-Host ('  ' + $_) } }
  else {
    $m = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    Write-Host ('T22LAYOUT window ' + $m.Client + ' at ' + $m.Dpi + ' dpi; 8 px at 100 % = ' + $m.Sc8 + ' px; layout self-check defects: ' + @($m.LayoutDefects).Count)
    $byKey = @{}; foreach ($c in @($m.Cards)) { $byKey[[string]$c.Key] = $c }
    $broken = @($m.Cards | Where-Object { $_.Error })
    Test-That 'every card was measured' ($broken.Count -eq 0) ('cards ' + @($m.Cards).Count + ', not measured: ' + (@($broken | ForEach-Object { [string]$_.Key + ' (' + $_.Error + ')' }) -join '; '))
    foreach ($k in $crumbCards) { Test-Crumb $k $byKey[$k] ([int]$m.Sc8) }
    Test-Step8 $byKey['step8']
    Test-Level @($m.Cards) ([double]$m.Sc8) ('dpi ' + $m.Dpi)
    $scaled = @($m.Scaled | Where-Object { $_ }); $bad = @($scaled | ForEach-Object { @($_.Cards | Where-Object { $_.Error }) })
    $nums = 'scales ' + $scaled.Count + ' (' + (@($scaled | ForEach-Object { [string]$_.K + ' x' }) -join ', ') + '); cards not measured: ' + $bad.Count
    if ($bad.Count) { $nums += ' (' + (@($bad | ForEach-Object { [string]$_.Key + ': ' + $_.Error }) -join '; ') + ')' }
    if ($m.ScaledError) { $nums += '; error: ' + $m.ScaledError }
    Test-That 'D1 to D4 measured at 1.25 x and 1.5 x' ($scaled.Count -eq 2 -and $bad.Count -eq 0) $nums
    foreach ($s in $scaled) { Test-Level @($s.Cards) ([double]$s.Sc8) ('dpi ' + $s.Dpi + ' (' + $s.K + ' x)') }
    $empty = @($m.EmptyNames | Where-Object { $_ })
    Test-That 'every button, link and text box has an accessible name' ($empty.Count -eq 0) ('without a name: ' + $empty.Count + $(if ($empty.Count) { ' (' + ($empty -join ', ') + ')' } else { '' }))
    Test-RailHead $m
    Test-Contrast $m
    Test-CardPng $m $tmp
  }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host ('T22LAYOUT pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail -gt 0) { exit 1 }
