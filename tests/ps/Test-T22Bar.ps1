# Tests the check bar of the T22 window (round R44 T4; R43 findings 3, 4 and 6) without a window: the real BarLayout, BarShow and
# Answer of the bar part run on stand-in controls.
#  (a) finding 3: the look step after the waves card names the grid by a line that the waves card shows (its head line);
#  (b) finding 4: for the longest step text, the text box never reaches the links "Open this screen" and "Feedback", at the
#      smallest window (800 wide at 100 %), at 1280 and at 1920, at 96 and 144 dpi, also with links wider than usual;
#  (c) finding 6: the window opens on the card of walk step 1, so that step counts as opened with no click.
# Usage: pwsh -NoProfile -File tests/ps/Test-T22Bar.ps1 [-Rev r21] [-Root <repo folder>]
# Last line: "T22BAR pass=N fail=M"; exit 1 when M is above 0.
# Stand-ins: the controls (position, size, preferred size), the text measure (7 px a character at 96 dpi, 20 px a line) and the scale.
# The cards part and the bar part are the real files; no System.Windows.Forms is used.
# Network: none.
# Writes: none.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7).
param([string]$Rev = 'r21', [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
$gov = Join-Path $Root 'scripts/gov'
$Again = $false; $lines = New-Object System.Collections.Generic.List[string]; $wn = @{}; $pc = @{}
$ui = @{ Dpi = 96.0; F = @{ Body = 'body'; SmallB = 'smallb' } }
# Stand-in: scales $Px logical pixels to the test dpi (as the UI part does on the device).
$ui.Sc = { param([double]$Px) [int][math]::Round($Px * $ui.Dpi / 96.0) }
# Stand-in: the window's scale, the same as $ui.Sc.
$wn.Sc = { param([double]$Px) & $ui.Sc $Px }
. (Join-Path $gov ('90161Z-T22-cards-' + $Rev + '.ps1'))   # $Cards, $Checks, $Walk (the real plan)
$Walk = @(Get-WalkPlan)   # r19: the bar is tested on the whole plan of every card (the round walks only home and step12: tests/check_t22_r21.py)
# Stand-in text measure: 7 px a character and 20 px a line at 96 dpi; the text wraps at the width given.
$ui.Meas = { param([string]$Text, $Font, [int]$W)
  $cw = 7.0 * $ui.Dpi / 96.0; $lh = [int][math]::Round(20 * $ui.Dpi / 96.0); $per = [math]::Max(1, [int][math]::Floor($W / $cw))
  $n = [math]::Max(1, [int][math]::Ceiling($Text.Length / $per))
  return [Drawing.Size]::new([int][math]::Min($W, $Text.Length * $cw), ($n * $lh)) }
# Stand-in: the wrap width of a text box is kept on the stand-in.
$ui.SetWrap = { param($C, [int]$W) $C.Wrap = $W }
# Stand-in: the window is always settled.
$ui.Settled = { return $true }
$Checks = @($Checks)
$script:ChecksDone = 'All checks done. Close this window with its X.'
$form = [pscustomobject]@{ ClientSize = [Drawing.Size]::new(1280, 720) }
$main = [pscustomobject]@{}
. (Join-Path $gov ('90161Z-T22-bar-' + $Rev + '.ps1'))

# Record one result and print PASS or FAIL with its numbers. Takes the name, the condition and the numbers; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Numbers = '') {
  $word = $(if ($Ok) { $script:pass++; 'PASS' } else { $script:fail++; 'FAIL' })
  Write-Host ('T22BAR ' + $word + ' ' + $Name + ': ' + $Numbers)
}
<#
.SYNOPSIS
  A stand-in control with a position, a size, a text and a preferred size (what BarLayout reads and sets).
.PARAMETER Pw
  The preferred width.
.PARAMETER Ph
  The preferred height.
.OUTPUTS
  An object with Location, Size, Left, Right, Bottom, Width, Height, Text, Visible, Wrap, MinimumSize, PreferredSize and GetPreferredSize.
#>
function New-Stub([int]$Pw, [int]$Ph) {
  $c = [pscustomobject]@{ Location = [Drawing.Point]::new(0, 0); Size = [Drawing.Size]::new($Pw, $Ph); Text = ''; Visible = $true; Wrap = 0
    MinimumSize = [Drawing.Size]::new(0, 0); PreferredSize = [Drawing.Size]::new($Pw, $Ph) }
  $c | Add-Member -MemberType ScriptProperty -Name Left -Value { $this.Location.X }
  $c | Add-Member -MemberType ScriptProperty -Name Right -Value { $this.Location.X + $this.Size.Width }
  $c | Add-Member -MemberType ScriptProperty -Name Bottom -Value { $this.Location.Y + $this.Size.Height }
  $c | Add-Member -MemberType ScriptProperty -Name Width -Value { $this.Size.Width }
  $c | Add-Member -MemberType ScriptProperty -Name Height -Value { $this.Size.Height } `
    -SecondValue { param($v) $this.Size = [Drawing.Size]::new($this.Size.Width, [int]$v) }
  $c | Add-Member -MemberType ScriptMethod -Name GetPreferredSize -Value { param($proposed) $this.PreferredSize }
  return $c
}
<#
.SYNOPSIS
  Sets up the stand-in bar for a window width, a dpi and 2 link widths, and runs the real BarLayout.
.PARAMETER W
  The client width in pixels.
.PARAMETER Dpi
  96 or 144.
.PARAMETER Fb
  The preferred width of the Feedback link at 96 dpi.
.PARAMETER Op
  The preferred width of the link "Open this screen" at 96 dpi.
#>
function Set-StubBar([int]$W, [double]$Dpi, [int]$Fb, [int]$Op) {
  $ui.Dpi = $Dpi; $k = $Dpi / 96.0
  $form.ClientSize = [Drawing.Size]::new($W, 720)
  $wn.Bar = New-Stub $W 60; $wn.BarNo = New-Stub 90 18; $wn.BarText = New-Stub 100 20
  $wn.BarPass = New-Stub ([int](100 * $k)) ([int](34 * $k)); $wn.BarFail = New-Stub ([int](100 * $k)) ([int](34 * $k))
  $wn.FbLink = New-Stub ([int]($Fb * $k)) ([int](28 * $k)); $wn.OpenLink = New-Stub ([int]($Op * $k)) ([int](28 * $k))
  & $wn.BarLayout
}
# (b) finding 4: the cases are width at 96 dpi, dpi, Feedback link width and Open link width (at 96 dpi).
$texts = @(@($Checks) + @($Walk) | ForEach-Object { [string]$_.Text })
$longest = ($texts | Sort-Object Length -Descending | Select-Object -First 1)
$cases = @(@(800, 96, 120, 150), @(800, 96, 150, 200), @(1280, 96, 120, 150), @(1920, 144, 120, 150), @(1200, 144, 150, 200), @(1920, 96, 150, 200))
foreach ($case in $cases) {
  $dpi = [double]$case[1]; $w = [int]([int]$case[0] * $dpi / 96.0)   # the client width at this dpi: 800 logical pixels
  Set-StubBar $w $dpi $case[2] $case[3]
  $gap = & $wn.Sc 8; $t = $wn.BarText; $op = $wn.OpenLink; $fb = $wn.FbLink; $pbtn = $wn.BarPass
  $tag = 'bar width ' + $w + ' at ' + $dpi + ' dpi, links ' + $case[2] + ' and ' + $case[3]
  $why = 'text ' + $t.Left + ' to ' + $t.Right + ', Open ' + $op.Left + ' to ' + $op.Right + ', Feedback ' + $fb.Left + ' to ' + $fb.Right + ', Pass ' + $pbtn.Left
  Test-That ($tag + ' text ends before Open this screen') ($t.Right + $gap -le $op.Left) $why
  $order = ($op.Right -le $fb.Left) -and ($fb.Right -le $pbtn.Left) -and ($pbtn.Right -le $wn.BarFail.Left) -and ($wn.BarFail.Right -le $w)
  Test-That ($tag + ' links in order') $order $why
  $m = & $ui.Meas $longest $ui.F.Body $t.Width
  Test-That ($tag + ' longest text fits its box') (($m.Height -le $t.Height) -and ($t.Bottom -le $wn.Bar.Height)) ('text height ' + $m.Height + ' of ' + $t.Height + ', bar ' + $wn.Bar.Height)
}

# (a) finding 3: the look step names the grid by the head line of the waves card, a line the card shows.
$head = ''
foreach ($col in @($Cards.waves.Cols)) { foreach ($s in @($col)) { foreach ($b in @($s.Blocks)) { if (-not $head -and $b.T -eq 'head') { $head = [string]$b.Text } } } }
$look = @($Walk | Where-Object { $_.Via -eq 'look' })
$named = ($look.Count -eq 1 -and $head -and $look[0].Text.Contains('"' + $head + '"') -and -not $look[0].Text.Contains('Wave 1 answers'))
Test-That 'look step names the grid by the head line of the waves card' $named ($look[0].Text)

# (c) finding 6: step 1 counts the card the window shows at the start as opened.
# Answers PASS on walk step 1 with the window on card $Cur. Takes the card key; returns the first WALK line and the NOTE count.
function Get-StepOneAnswer([string]$Cur) {
  $wn.WalkAns = New-Object 'string[]' $Walk.Count; $wn.WalkOpen = New-Object 'bool[]' $Walk.Count
  $wn.BarNo = New-Stub 90 18; $wn.BarText = New-Stub 100 20; $wn.BarPass = New-Stub 100 34; $wn.BarFail = New-Stub 100 34; $wn.OpenLink = $null
  $wn.Cur = $Cur; $wn.CheckAt = $Checks.Count; $lines.Clear()
  & $wn.BarShow; & $wn.Answer 'PASS'
  return @{ Line = [string]@(& $wn.WalkLines)[0]; Notes = @($lines | Where-Object { $_ -like 'NOTE*' }).Count }
}
$k1 = [string]$Walk[0].Key; $n = $Walk.Count
$a = Get-StepOneAnswer $k1
Test-That 'walk step 1 on the card shown at the start: PASS counts as opened, no NOTE' (($a.Line -ceq ('WALK 1 of ' + $n + ' ' + $k1 + ' PASS (opened by you)')) -and $a.Notes -eq 0) $a.Line
$a = Get-StepOneAnswer 'settings'
Test-That 'walk step 1 with another card shown: PASS stays not opened (a NOTE line says why)' (($a.Line -ceq ('WALK 1 of ' + $n + ' ' + $k1 + ' FAIL (not opened)')) -and $a.Notes -eq 1) $a.Line
$wn.WalkAns = New-Object 'string[]' $n; $wn.WalkOpen = New-Object 'bool[]' $n
$wn.Cur = [string]$Walk[1].Key; $wn.CheckAt = $Checks.Count + 1; & $wn.BarShow
Test-That 'only step 1 is counted at the start: step 2 on its own card, with no click, is not opened' (-not $wn.WalkOpen[1]) ('step 2 ' + $Walk[1].Key)

Write-Host ('T22BAR pass=' + $script:pass + ' fail=' + $script:fail + ' (bar part ' + $Rev + ')')
if ($script:fail -gt 0) { exit 1 }
