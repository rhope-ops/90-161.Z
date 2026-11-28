# Tests the grid fit of T22 (round R43 T1; R42 finding 2): after the fit, the columns of a grid end before its scroll bar.
# The R42 device lines it reproduces (1920 x 1094 at 150 %, scroll bar 26 px): home and empty "Who has it now" "columns need 979,
# the grid has 961"; queue "All actions" "columns need 1442, the grid has 1428". On those grids the plan's minimums fitted
# (r15 fixed only grids whose minimums were too wide, as Wave 1 answers), but the grid's own fill laid the columns out wider than
# the grid. This test gives $wn.FitGrid a stand-in grid with those widths and checks what is left; it needs no window.
# Usage: pwsh -NoProfile -File tests/ps/Test-T22GridWidth.ps1 [-Rev r21]   (the revision of the T22 grid part to test; r15 fails)
# Last line: "T22GRIDW pass=N fail=M"; exit 1 when M is above 0.
# Stand-in text widths (px per character), the plan and the fit are the grid part's own; only the text measure and the scroll bar
# width are replaced (no System.Windows.Forms off Windows).
# Network: none.
# Writes: none.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7).
param([string]$Rev = 'r21', [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
$gov = Join-Path $Root 'scripts/gov'
$wn = @{}; $ui = @{ Dpi = 144.0; F = @{ Small = 10.5; SmallB = 11.4; Link = 11.4 } }; $Again = $false
# Stand-in: scales $Px logical pixels to the test dpi, as the UI part does on the device.
$ui.Sc = { param([double]$Px) [int][math]::Round($Px * $ui.Dpi / 96.0) }
# Stand-in: the window's scale, the same as $ui.Sc.
$wn.Sc = { param([double]$Px) & $ui.Sc $Px }
. (Join-Path $gov ('90161Z-T22-cards-' + $Rev + '.ps1'))
. (Join-Path $gov ('90161Z-T22-grid-' + $Rev + '.ps1'))   # replaces nothing below: only these two stand-ins come after it
# Stand-in: the width of $Text at $F pixels a character (no font measure off Windows).
$wn.TextW = { param([string]$Text, $F) return [int][math]::Ceiling($Text.Length * [double]$F) }
$script:bar = 26
# Stand-in: the width of the vertical scroll bar (26, as on the device in R42).
$wn.BarW = { return $script:bar }
# Stand-in: the scroll bar width that grid $G shows.
$wn.BarShown = { param($G) return [int]$G.BarShown }

# Record one result and print PASS or FAIL with its numbers. Takes the name, the condition and the numbers; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Numbers = '') {
  if ($Ok) { $script:pass++; Write-Host ('T22GRIDW PASS ' + $Name + ': ' + $Numbers) } else { $script:fail++; Write-Host ('T22GRIDW FAIL ' + $Name + ': ' + $Numbers) }
}
# The grid block $Name of card $Key (its columns and fake rows). Takes the card key and the grid name; returns the block.
function Get-GridBlock([string]$Key, [string]$Name) {
  foreach ($b in @($Cards[$Key].Cols[0].Blocks)) { if ($b.T -eq 'grid' -and $b.Name -eq $Name) { return $b } }
  foreach ($s in @($Cards[$Key].Cols[0])) { foreach ($b in @($s.Blocks)) { if ($b.T -eq 'grid' -and $b.Name -eq $Name) { return $b } } }
  throw ('no grid ' + $Name + ' on ' + $Key)
}
<#
.SYNOPSIS
  Fits one stand-in grid like the device had it in R42, and records the result.
.DESCRIPTION
  The columns get their planned minimums and the extra width goes to the widest plain column (an assumption: the
  device logged only the sum). The fit must leave the sum under the grid width less the scroll bar. Returns nothing.
.PARAMETER Key
  The card key (home, empty or queue).
.PARAMETER Name
  The grid name on that card.
.PARAMETER W
  The grid width from the R42 LAYOUT line.
.PARAMETER Need
  The width the columns summed to on the device (the R42 LAYOUT line).
#>
function Test-DeviceGrid([string]$Key, [string]$Name, [int]$W, [int]$Need) {
  $b = Get-GridBlock $Key $Name; $rows = @($b.Rows); $pw = & $wn.PubWidths $rows; $cols = & $wn.DropCols @($b.Cols) $W $pw $rows
  $p = & $wn.ColPlan $cols $W 0 (& $wn.PubMin $cols $pw) $rows
  $gc = @(); $kinds = @{}; $sum = 0
  foreach ($c in $cols) { $m = [int]$p.Min[[string]$c.N]; $kinds[[string]$c.N] = [string]$c.K; $sum += $m
    $gc += [pscustomobject]@{ Name = [string]$c.N; Visible = $true; MinimumWidth = $m; Width = $m; AutoSizeMode = 'Fill' } }
  $plain = @($gc | Where-Object { $kinds[$_.Name] -eq 'plain' } | Sort-Object MinimumWidth -Descending)[0]
  if ($Need -lt $sum) { Test-That ($Key + ' ' + $Name + ' set-up') $false ('the minimums need ' + $sum + ', more than the ' + $Need + ' of the device'); return }
  $plain.Width += $Need - $sum
  $g = [pscustomobject]@{ AccessibleName = $Name; ClientSize = @{ Width = $W }; Width = $W; Columns = $gc; BarShown = $script:bar
    Tag = @{ Kind = $kinds; Cols = $cols; Shown = $rows; ChipKept = $p.ChipKept; Reserve = $p.Reserve } }
  $null = & $wn.FitGrid $g; $left = 0; $chipOk = $true
  foreach ($k in $gc) { $left += [int]$k.Width; if ([int]$k.Width -lt [int]$k.MinimumWidth) { $chipOk = $false } }
  $again = & $wn.FitGrid $g   # a later open of the same card: nothing more to change
  $nums = 'columns need ' + $Need + ' at the start, the grid has ' + $W + ', scroll bar ' + $script:bar + '; after the fit the columns need ' + $left +
    ' (limit ' + ($W - $script:bar) + '), none under its minimum: ' + $chipOk + ', second fit changes nothing: ' + (-not $again)
  Test-That ($Key + ' ' + $Name) (($left -le $W - $script:bar) -and $chipOk -and -not $again) $nums
}
Test-DeviceGrid 'home' 'Who has it now' 961 979
Test-DeviceGrid 'empty' 'Who has it now' 961 979
Test-DeviceGrid 'queue' 'All actions' 1428 1442
# R16 review: a sum between the room (grid less the bar) and the grid width must be cut too (950: past 935, under 961).
Test-DeviceGrid 'home' 'Who has it now' 961 950
Write-Host ('T22GRIDW pass=' + $script:pass + ' fail=' + $script:fail + ' (grid part ' + $Rev + ')')
if ($script:fail -gt 0) { exit 1 }
