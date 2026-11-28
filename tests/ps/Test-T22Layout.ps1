# R13 (R40; PFM 20 Nov 26): Test-Keep: every card opened again shows its kept card, in under 100 ms.
# R11 (R38; PFM 20 Nov 26): Test-EdgeBar: no grid chip or text ends closer to the grid's right edge than a scroll bar is wide.
# Tests the look of the T22 PFM window r21 by measurement (round R30: the R29b defects V2 to V4 and the accessible names;
# round R31: the rail head W1, the high-contrast colors W2 and the card pictures W4).
# Network: none.
# Writes: one temporary folder with the measure file and the card pictures of the window; removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Windows only: elsewhere the one line "T22LAYOUT SKIP ..." and exit 0.
# Runs scripts/gov/90161Z-T22-pfm-window-r21.ps1 -Measure <file> -NoPause in a child of the same engine (the window is built
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
# R7 (R32 W1 to W3), at the same 3 scales: no pub cell is cut (each number and title needs no more width, and its lines
# no more height, than its cell gave, beside or under) and the head of the pub column is not shortened (W1); every chip
# beside text (check, list rows, rows blocks, the chips row) is level with its first text line, with the list chips of
# Your Work and the rows chips of step 8 measured (W3). Once: a mouse-wheel turn on the middle of the first card of Your
# Work (not on the scroll bar), sent to the button with the focus, scrolls the main column; one on a grid that can
# still scroll scrolls the grid, not the main column (W2, at the 3 scales; the routing function on the control tree and
# the window's own filter are each called, no real pointer moves).
# R8 (R35 W7), at the same 3 scales (1.5 x gives the narrowest grids: the page column is never under 900 px at 100 %):
# no column head of any grid is shortened (each head needs no more width than its cell gave). Once: the rail logo,
# rebuilt with high contrast on, has only the 2 system colors and differs from its own colors; rebuilt with it off,
# it is its own colors again (no change of the Windows theme).
# R10 (R37), once: the Feedback link is on every card in one place and one saved comment writes a PNG of the window,
# the comment and the list (B13); the rail shows the Fulcrum logo in both app modes; no
# grid has columns wider than itself (R36 finding 3).
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
Checks the rail logo in high contrast (R8, R35 W7; the PFM's R34 note: the logo did not change): rebuilt with high
contrast on, every logo pixel with any cover is one of the 2 system colors and the logo differs from its own colors;
rebuilt with it off, no pixel differs from its own colors. No LAYOUT line either way.
.PARAMETER M
The measure file (Logo, LogoError).
#>
function Test-Logo($M) {
  $rows = @($M.Logo | Where-Object { $_ })
  $on = @($rows | Where-Object { [string]$_.When -eq 'on' }) | Select-Object -First 1; $off = @($rows | Where-Object { [string]$_.When -eq 'off' }) | Select-Object -First 1
  $err = $(if ($M.LogoError) { '; error: ' + $M.LogoError } else { '' })
  $ok = [bool]($on -and $on.Shown -and $on.High -and [int]$on.Other -eq 0 -and [int]$on.Diff -gt 0 -and @($on.Bad | Where-Object { $_ }).Count -eq 0)
  Test-That 'high contrast on: the logo in the 2 system colors' $ok ('shown ' + $on.Shown + '; other pixels ' + $on.Other + '; changed pixels ' + $on.Diff + $err)
  $ok = [bool]($off -and $off.Shown -and -not $off.High -and [int]$off.Diff -eq 0 -and @($off.Bad | Where-Object { $_ }).Count -eq 0)
  Test-That 'high contrast off: the logo in its own colors' $ok ('shown ' + $off.Shown + '; changed pixels ' + $off.Diff + $err)
}
<#
.SYNOPSIS
Checks Feedback (R10, R37, UI standard B13): the link is on every card, on the check bar, named and in one place; one
FAKE comment saved through the Save code wrote a real PNG picture of the window, the comment text file and the list.
.PARAMETER M
The measure file (Feedback, FeedbackError).
#>
function Test-Feedback($M) {
  $f = $M.Feedback; $err = $(if ($M.FeedbackError) { '; error: ' + $M.FeedbackError } else { '' })
  $ok = [bool]($f -and [int]$f.Cards -gt 0 -and [int]$f.WithLink -eq [int]$f.Cards -and [int]$f.Places -eq 1 -and ([string]$f.Name).Trim())
  $nums = 'cards ' + $f.Cards + ' (want more than 0), with the link ' + $f.WithLink + ' (want ' + $f.Cards + '), places ' + $f.Places + ' (want 1)'
  Test-That 'Feedback link on every card, in one place, named' $ok ($nums + ', name "' + $f.Name + '" (want a name)' + $err)
  $ok = [bool]($f -and $f.PngSig -and [int]$f.PngBytes -gt 1000 -and ([string]$f.Base) -eq ('90161Z-T22-feedback-home-' + $M.Rev))
  $nums = 'file ' + $f.Base + '.png (want 90161Z-T22-feedback-home-' + $M.Rev + '.png), ' + $f.PngBytes + ' bytes (want more than 1000)'
  Test-That 'Feedback save writes a PNG of the window' $ok ($nums + ', PNG signature ' + $f.PngSig + $err)
  $ok = [bool]($f -and $f.TxtHasComment -and $f.ListHasIt -and ([string]$f.LinkText) -eq 'Feedback (1 saved)')
  $nums = 'comment in the text file ' + $f.TxtHasComment + ', in the list ' + $f.ListHasIt
  Test-That 'Feedback save writes the comment and the list' $ok ($nums + ', link "' + $f.LinkText + '" (want "Feedback (1 saved)")' + $err)
}
<#
.SYNOPSIS
Checks the logo (R11, R38; PFM 20 Nov 26: Fulcrum in Windows light and dark mode): the Fulcrum logo is 128 x 128, and the rail
shows it whatever the app mode of this computer is.
.PARAMETER M
The measure file (Theme, ThemeError).
#>
function Test-Theme($M) {
  $t = $M.Theme; $err = $(if ($M.ThemeError) { '; error: ' + $M.ThemeError } else { '' })
  $ok = [bool]($t -and [string]$t.Fulcrum -eq '128x128')
  Test-That 'one logo: Fulcrum, in light and dark mode' $ok ('Fulcrum ' + $t.Fulcrum + $err)
  $nums = 'light mode ' + $t.Light + ', pixels that differ from the Fulcrum logo ' + $t.ShownDiff + $err
  Test-That 'the rail logo is the Fulcrum logo in this app mode' ([bool]($t -and [int]$t.ShownDiff -eq 0)) $nums
}
<#
.SYNOPSIS
R13 (R40, R39 finding 2): every card opened again after the first build shows its kept card (no build), and each such
open takes under 100 ms (the plan's target: a person notices a delay over about 100 ms).
.PARAMETER M
The measure file (Cards, Keep, KeepError).
#>
function Test-Keep($M) {
  $k = @($M.Keep | Where-Object { $_ }); $err = $(if ($M.KeepError) { '; error: ' + $M.KeepError } else { '' })
  $built = @($k | Where-Object { -not $_.Kept } | ForEach-Object { [string]$_.Key })
  $ok = ($k.Count -gt 0 -and $k.Count -eq @($M.Cards).Count -and $built.Count -eq 0)
  $again = $(if ($built.Count) { $built -join ', ' } else { 'none' })
  Test-That 'every card opened again shows its kept card' $ok ('opens ' + $k.Count + ' of ' + @($M.Cards).Count + ' cards; built again: ' + $again + $err)
  $ms = @($k | ForEach-Object { [int]$_.Ms }); $max = $(if ($ms.Count) { (@($ms | Measure-Object -Maximum).Maximum) } else { -1 })
  $slow = @($k | Where-Object { [int]$_.Ms -ge 100 } | ForEach-Object { [string]$_.Key + ' ' + $_.Ms + ' ms' })
  $nums = 'slowest ' + $max + ' ms; ' + (@($k | ForEach-Object { [string]$_.Key + '=' + $_.Ms }) -join ' ')
  if ($slow.Count) { $nums += '; 100 ms or more: ' + ($slow -join ', ') }
  Test-That 'a later open of each card is under 100 ms' ($ms.Count -gt 0 -and $slow.Count -eq 0) $nums
}
<#
.SYNOPSIS
Checks the card pictures (R31 W4): one PNG file per card, named 90161Z-T22-card-<card>-r21.png, saved in the folder of
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
# R8 (W7): the cards whose grids must have their column heads measured (the 3 pub grids and the Wave 1 answers).
$levelHeads = @('home', 'empty', 'queue', 'waves')
# R7 (W3): the kinds of chip beside text each card must have measured ("Needs You Today" is the list of Your Work).
$chipKinds = @{ home = @('list'); step8 = @('check', 'rows', 'chips'); waves = @('rows', 'chips'); step11 = @('rows', 'chips'); step12 = @('rows', 'chips'); settings = @('rows') }
<#
.SYNOPSIS
Checks the chips beside text of one card at one scale (D3 of R6; R7 W3: every kind): each chip's middle is within the
tolerance of its first text line's middle (R48: a list or rows chip: of its row's middle; the measured Ref says which), and the card has each kind of $chipKinds it must have.
.PARAMETER Key
The card key.
.PARAMETER Chips
The measured chips (Chip, Kind, ChipMid, Ref, Line, LineMid).
.PARAMETER Tol
The tolerance in pixels.
.PARAMETER At
The scale, as text (it starts each line).
#>
function Test-ChipLevel([string]$Key, $Chips, [double]$Tol, [string]$At) {
  foreach ($want in @($chipKinds[$Key])) { if (-not $want) { continue }
    $n = @($Chips | Where-Object { [string]$_.Kind -eq $want }).Count
    Test-That ($At + ' W3 ' + $Key + ': ' + $want + ' chips measured') ($n -gt 0) ('chips of this kind: ' + $n + '; all chips: ' + @($Chips).Count) }
  foreach ($x in $Chips) { $d = [math]::Abs([double]$x.ChipMid - [double]$x.LineMid)
    $nums = 'chip middle ' + $x.ChipMid + '; ' + $x.Ref + ' of "' + $x.Line + '" middle ' + $x.LineMid + '; difference ' + $d + ' px'
    Test-That ($At + ' D3/W3 ' + $Key + ': chip "' + $x.Chip + '" (' + $x.Kind + ') level with its ' + $x.Ref + ' (+-' + $Tol + ' px)') ($d -le $Tol) $nums }
}
<#
.SYNOPSIS
Checks one pub grid at one scale for cut text (R7, R32 W1): the head of the pub column was measured and needs no more
width than it had (no dots), and in every row drawn the number and the title need no more width, and their lines no
more height, than the cell gave them (beside or under).
.PARAMETER Key
The card key.
.PARAMETER P
The measured grid (Grid, Rows, Head, HeadW, HeadHave, Beside, NumW, NumHave, TitleW, TitleHave, NeedH, HaveH).
.PARAMETER At
The scale, as text (it starts each line).
#>
function Test-PubCut([string]$Key, $P, [string]$At) {
  $ok = ([string]$P.Head -ne '' -and [int]$P.HeadW -le [int]$P.HeadHave)
  Test-That ($At + ' W1 ' + $Key + ' ' + $P.Grid + ': head not shortened') $ok ('head "' + $P.Head + '" needs ' + $P.HeadW + ' px, has ' + $P.HeadHave + ' px')
  $n = [int]$P.Rows; $cut = @(); $nw = @($P.NumW); $nh = @($P.NumHave); $tw = @($P.TitleW); $th = @($P.TitleHave); $lh = @($P.NeedH); $ch = @($P.HaveH)
  for ($i = 0; $i -lt $n; $i++) {
    if ([int]$nw[$i] -gt [int]$nh[$i] -or [int]$tw[$i] -gt [int]$th[$i] -or [int]$lh[$i] -gt [int]$ch[$i]) {
      $cut += ('row ' + ($i + 1) + ': number ' + $nw[$i] + '/' + $nh[$i] + ', title ' + $tw[$i] + '/' + $th[$i] + ', height ' + $lh[$i] + '/' + $ch[$i]) } }
  $mode = $(if (@($P.Beside) -contains $true) { 'beside' } else { 'under' })
  $nums = 'rows drawn ' + $n + ' (' + $mode + '); widest number ' + [int](@($nw) | Measure-Object -Maximum).Maximum + ' px in ' + [int](@($nh) | Measure-Object -Minimum).Minimum
  $nums += ' px; tallest need ' + [int](@($lh) | Measure-Object -Maximum).Maximum + ' px in ' + [int](@($ch) | Measure-Object -Minimum).Minimum + ' px; cut: ' + $cut.Count
  if ($cut.Count) { $nums += ' (' + ($cut -join '; ') + ')' }
  Test-That ($At + ' W1 ' + $Key + ' ' + $P.Grid + ': no publication number or title cut') ($n -ge 1 -and $cut.Count -eq 0) $nums
}
<#
.SYNOPSIS
Checks the column heads of the grids of one card at one scale (R8, R35 W7): each grid's heads were measured and none
needs more width than its cell gave (no head shortened with dots), one line per grid with every head's numbers.
.PARAMETER Key
The card key.
.PARAMETER Heads
The measured heads (Grid, Col, Kind, Head, W, Have).
.PARAMETER At
The scale, as text (it starts each line).
#>
function Test-HeadCut([string]$Key, $Heads, [string]$At) {
  if ($levelHeads -contains $Key -and -not @($Heads).Count) { Test-That ($At + ' W7 ' + $Key + ': grid column heads measured') $false 'no head measured' }
  foreach ($g in @($Heads | ForEach-Object { [string]$_.Grid } | Sort-Object -Unique)) {
    $hs = @($Heads | Where-Object { [string]$_.Grid -eq $g }); $cut = @($hs | Where-Object { [int]$_.W -gt [int]$_.Have })
    $nums = 'heads ' + $hs.Count + ', cut ' + $cut.Count + ': ' + (@($hs | ForEach-Object { $_.Head + ' ' + $_.W + '/' + $_.Have }) -join ', ')
    Test-That ($At + ' W7 ' + $Key + ' ' + $g + ': no column head shortened') ($hs.Count -ge 2 -and $cut.Count -eq 0) $nums }
}
<#
.SYNOPSIS
Checks the right edge of the grids of one card at one scale (R11, R38; the PFM's R37 picture: the status chips "Due 20 Nov
26" touched the scroll bar): in each grid, the chips and the text of the last column end at least the width of a vertical
scroll bar before the grid's right edge, whether the bar shows or not. A card with a pub grid ($levelPubs) must have one.
.PARAMETER Key
The card key.
.PARAMETER Edges
The measured grids (Grid, Width, Bar, Edge, Col).
.PARAMETER At
The scale, as text (it starts each line).
#>
function Test-EdgeBar([string]$Key, $Edges, [string]$At) {
  if ($levelPubs -contains $Key -and -not @($Edges).Count) { Test-That ($At + ' R11 ' + $Key + ': grid right edge measured') $false 'no grid measured' }
  foreach ($e in @($Edges)) {
    $room = [int]$e.Width - [int]$e.Bar
    $nums = 'content of "' + $e.Col + '" ends at ' + $e.Edge + ' px; the grid is ' + $e.Width + ' wide, scroll bar ' + $e.Bar + ', so at most ' + $room + ' px'
    # Too narrow for every whole head and the chip (ps51 W7 at 100 %): the heads come first (W7 above); the edge is not judged.
    if ($e.Fits -eq $false) { Write-Host ('  T22LAYOUT INFO ' + $At + ' R11 ' + $Key + ' ' + $e.Grid + ': too narrow for every head and the chip; edge not judged (' + $nums + ')'); continue }
    Test-That ($At + ' R11 ' + $Key + ' ' + $e.Grid + ': no chip or text closer to the right edge than the scroll bar') ([int]$e.Edge -le $room) $nums }
}
<#
.SYNOPSIS
Checks D1 to D4 (R6, the R31b defects) on the alignment facts (Level) of every card measured at one scale.
.DESCRIPTION
D1: on each card of $levelCaps, each Action Status caption's middle is within the tolerance of the main card's first
line. D2: on each card with a crumb link (the cards of $crumbCards at least), link and rest have one font size and
their text middles are within the tolerance. D3: each check chip (step 8 has one at least) is within the tolerance of
its first text line. D4: each pub grid (one at least on each card of $levelPubs) drew 2 rows or more, all its titles
start at one x, and that x is at or after the widest number's end and the gap (titles beside) or each title starts at
or below its number's bottom (titles under). The tolerance is 1 px at 100 %: Sc8 / 8, at least 1. R7: the chips of
every kind (Test-ChipLevel, W3) and the cut cells and head of each pub grid (Test-PubCut, W1). R8: the column heads
of every grid (Test-HeadCut, W7).
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
    Test-ChipLevel $k @($lv.Chips | Where-Object { $_ }) $tol $At
    $pubs = @($lv.Pubs | Where-Object { $_ })
    if ($levelPubs -contains $k -and -not $pubs.Count) { Test-That ($At + ' D4 ' + $k + ': publication grid measured') $false 'no pub grid measured' }
    foreach ($p in $pubs) {
      Test-PubCut $k $p $At
      $n = [int]$p.Rows; $xs = @(@($p.TitleX) | Sort-Object -Unique); $beside = @($p.Beside) -contains $true
      $num = [int](@($p.NumRight) | Measure-Object -Maximum).Maximum
      $low = @(for ($i = 0; $i -lt $n; $i++) { if ([int]@($p.TitleTop)[$i] -lt [int]@($p.NumBottom)[$i]) { $i } })
      $ok = ($n -ge 2 -and $xs.Count -eq 1 -and $(if ($beside) { [int]$xs[0] -ge $num + [int]$p.Gap } else { $low.Count -eq 0 }))
      $how = $(if ($beside) { 'beside: widest number ends at ' + $num + ', gap ' + $p.Gap } else { 'under: titles above their number bottom ' + $low.Count })
      $nums = 'rows drawn ' + $n + '; title x ' + ($xs -join ', ') + '; ' + $how
      Test-That ($At + ' D4 ' + $k + ' ' + $p.Grid + ': titles start in one column') $ok $nums }
    Test-HeadCut $k @($lv.Heads | Where-Object { $_ }) $At
    Test-EdgeBar $k @($lv.Edges | Where-Object { $_ }) $At }
}
<#
.SYNOPSIS
Checks the mouse wheel (R7, R32 W2), in 2 ways: the routing function on the built control tree (no screen pixels, so it
holds for this window off the screen) and the window's own filter given the message as Windows sends it. In each way:
one turn towards you on the middle of the first card of Your Work (a button has the focus) scrolled the main column
down, with the pointer on a part of the card (not on the main column or its scroll bar); one turn on a grid that could
still scroll moved the grid's first row and not the main column (when the card had such a grid).
.PARAMETER M
The measure file, or one scale of it (Wheel with Route and Filter, WheelError).
.PARAMETER At
The scale, as text (it starts each line).
#>
function Test-Wheel($M, [string]$At) {
  $w = $M.Wheel
  if (-not $w) { Test-That ($At + ' wheel: measured') $false ('no wheel facts' + $(if ($M.WheelError) { '; error: ' + $M.WheelError } else { '' })); return }
  foreach ($way in @(@{ K = 'Route'; T = 'routing function on the control tree' }, @{ K = 'Filter'; T = 'window wheel handlers, MouseWheel event as Windows sends it' })) {
    $c = $w.($way.K)
    if (-not $c) { Test-That ($At + ' wheel (' + $way.T + '): measured') $false 'no facts'; continue }
    $onCard = ([string]$c.Under -and [string]$c.Under -notmatch '"Main column"$' -and [string]$c.Under -notmatch '^Form ')
    $ok = ([bool]$c.Scrolls -and [bool]$c.Handled -and $onCard -and [int]$c.After -gt [int]$c.Before)
    $nums = 'card ' + $w.Card + ' scrolls ' + $c.Scrolls + '; pointer on ' + $c.Under + ' at ' + $c.Point + ' (page top ' + $c.PageTop + ')'
    $nums += '; taken ' + $c.Handled + '; scroll position ' + $c.Before + ' -> ' + $c.After
    Test-That ($At + ' wheel (' + $way.T + '): the card scrolls from a point on the card, not the scroll bar') $ok $nums
    if ($null -eq $c.GridBefore) { Write-Host ('T22LAYOUT note ' + $At + ' wheel (' + $way.T + '): no grid on the card could still scroll'); continue }
    $ok = ([bool]$c.GridHandled -and [int]$c.GridAfter -gt [int]$c.GridBefore -and [int]$c.MainAfter -eq [int]$c.MainBefore)
    $nums = 'pointer on ' + $c.GridUnder + '; taken ' + $c.GridHandled + '; first row ' + $c.GridBefore + ' -> ' + $c.GridAfter + '; main column ' + $c.MainBefore + ' -> ' + $c.MainAfter
    Test-That ($At + ' wheel (' + $way.T + '): the grid under the pointer scrolls, the card stays') $ok $nums }
}
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('t22layout-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tmp)
try {
  $file = Join-Path $tmp 'measure.json'
  $engine = (Get-Process -Id $PID).Path
  $window = Join-Path $Root 'scripts/gov/90161Z-T22-pfm-window-r21.ps1'
  $ErrorActionPreference = 'Continue'   # the child's error output is shown below, not thrown here
  $log = @(& $engine -NoProfile -File $window -Measure $file -NoPause 2>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE; $ErrorActionPreference = 'Stop'
  $built = ($code -eq 0 -and (Test-Path -LiteralPath $file))
  Test-That 'the window was built off-screen and measured' $built ('exit ' + $code + '; last line: ' + (@($log | Where-Object { $_.Trim() }) | Select-Object -Last 1))
  # R11 (engine-v29 brought the UI standard rules): name the first 15 self-check defects, so the CI log shows their kind
  # (a REPORT line; it changes no result; "not a test failure" lets Invoke-Ps51 show it on a failed run too).
  if ($built) { try { $lay = @((Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).LayoutDefects | ForEach-Object { ([string]$_ -replace '^LAYOUT \S+ ', '' -replace '\d+', 'N') })
      $lay | Group-Object | Sort-Object Count -Descending | ForEach-Object { Write-Host ('T22LAYOUT REPORT defect (not a test failure) x' + $_.Count + ': ' + $_.Name) } } catch { $null = $_ } }
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
    foreach ($s in $scaled) { $at = 'dpi ' + $s.Dpi + ' (' + $s.K + ' x)'; Test-Level @($s.Cards) ([double]$s.Sc8) $at; Test-Wheel $s $at
      $bb = @($s.Cards | ForEach-Object { @($_.Btn | Where-Object { $_ } | ForEach-Object { [string]$_ }) })   # R11: UI standard B1 at this scale
      Test-That ($at + ' B1: every shown button has a size of the set and its whole label') ($bb.Count -eq 0) (($bb | Select-Object -First 5) -join '; ') }
    $empty = @($m.EmptyNames | Where-Object { $_ })
    Test-That 'every button, link and text box has an accessible name' ($empty.Count -eq 0) ('without a name: ' + $empty.Count + $(if ($empty.Count) { ' (' + ($empty -join ', ') + ')' } else { '' }))
    Test-Wheel $m ('dpi ' + $m.Dpi)
    Test-RailHead $m
    Test-Contrast $m
    Test-Logo $m
    Test-CardPng $m $tmp
    Test-Keep $m
    Test-Feedback $m
    Test-Theme $m
    $cut = @(@($m.LayoutDefects) | Where-Object { [string]$_ -match ' columns need ' })
    Test-That 'no grid has columns wider than itself (R36 finding 3)' ($cut.Count -eq 0) ('grids with wider columns: ' + $cut.Count + $(if ($cut.Count) { ' (' + ($cut -join '; ') + ')' } else { '' }))
  }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host ('T22LAYOUT pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail -gt 0) { exit 1 }
