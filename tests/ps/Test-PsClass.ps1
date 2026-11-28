# Spike for fleet batch F6 item 6 (docs/reviews/2026-11-27-plan-f6.md): can the Kanon window (scripts/gov/90161Z-T22-types-r20.ps1)
# draw its rounded cards and route the mouse wheel with no inline C# (DEC-NIPR invariant 2: no Add-Type)?
# First finding (2026-11-27): PowerShell classes that inherit a WinForms type do not parse where WinForms is missing (the Linux
# lint of the pre-push hook: "Cannot load assembly 'System.Windows.Forms'"), so this spike tests the other way: standard
# controls with script-block event handlers (Paint, MouseWheel) and the protected DoubleBuffered flag set by reflection.
# Last line: "PSCLASS pass=N fail=M" ("PSCLASS SKIP <why>" off Windows). Also prints "PSCLASS REPORT ..." with the timing.
# Network: none.
# Writes: nothing (draws into bitmaps in memory).
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Pure ASCII. No Add-Type with code, no Invoke-Expression.
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0; $script:first = ''

<#
.SYNOPSIS
Count one check and print a FAIL line when it does not hold.
.PARAMETER Name
The check name.
.PARAMETER Ok
The check result.
#>
function Test-One([string]$Name, [bool]$Ok) {
  if ($Ok) { $script:pass++ } else { $script:fail++; Write-Output ('FAIL ' + $Name) }
}

if ($env:OS -ne 'Windows_NT') { Write-Output 'PSCLASS SKIP not Windows (WinForms needs Windows)'; exit 0 }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing   # loads the .NET assemblies only; no code is compiled
# An error in a part counts as one failed check; the first error text and line go on the last line, so the CI log shows it.
trap {
  $script:fail++
  if (-not $script:first) { $script:first = ' first=' + $_.Exception.GetType().Name + ' line ' + $_.InvocationInfo.ScriptLineNumber + ': ' + $_.Exception.Message }
  continue
}

<#
.SYNOPSIS
Make a closed rounded-rectangle path (as Gfx.Round in the C# of T22 types).
.PARAMETER Rect
The rectangle.
.PARAMETER Radius
The corner radius in pixels.
.OUTPUTS
System.Drawing.Drawing2D.GraphicsPath
#>
function Get-RoundPath($Rect, [float]$Radius) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $Radius * 2
  $p.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
  $p.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
  $p.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
  $p.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return , $p
}

<#
.SYNOPSIS
Make a panel that paints a rounded fill (as Card in the C# of T22 types), with no subclass.
.PARAMETER Fill
The fill color.
.OUTPUTS
System.Windows.Forms.Panel
#>
function Get-RoundCard($Fill) {
  $c = New-Object System.Windows.Forms.Panel
  # DoubleBuffered is protected; reflection sets it (no compile), so the card does not flicker when it repaints.
  $c.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance').SetValue($c, $true, $null)
  $c.Tag = $Fill
  $c.Add_Paint({
      param($s, $e)
      $g = $e.Graphics
      $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $g.Clear($s.BackColor)
      $rect = New-Object System.Drawing.RectangleF 0, 0, ($s.Width - 1), ($s.Height - 1)
      $path = Get-RoundPath $rect 10
      $brush = New-Object System.Drawing.SolidBrush $s.Tag
      try { $g.FillPath($brush, $path) } finally { $brush.Dispose(); $path.Dispose() }
    })
  return $c
}

# 0. The file this spike would replace is where the plan says.
Test-One 'the T22 types file exists' (Test-Path (Join-Path $Root 'scripts/gov/90161Z-T22-types-r20.ps1'))

# 1. Paint handler: draw the card into a bitmap and read 2 pixels.
$card = Get-RoundCard ([System.Drawing.Color]::FromArgb(255, 34, 38, 49))
$card.BackColor = [System.Drawing.Color]::White
$card.Size = New-Object System.Drawing.Size 120, 60
$bmp = New-Object System.Drawing.Bitmap 120, 60
try {
  $card.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle 0, 0, 120, 60))
  $mid = $bmp.GetPixel(60, 30); $corner = $bmp.GetPixel(0, 0)
  Test-One 'Paint handler fills the middle' ($mid.R -eq 34 -and $mid.G -eq 38 -and $mid.B -eq 49)
  Test-One 'Paint handler leaves the corner round' ($corner.R -gt 200 -and $corner.G -gt 200 -and $corner.B -gt 200)
  $db = $card.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance').GetValue($card, $null)
  Test-One 'DoubleBuffered is on' ([bool]$db)
} finally { $bmp.Dispose() }

# 2. Paint time of 40 cards (about 2 window pages), so the window stays quick without compiled code.
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$b2 = New-Object System.Drawing.Bitmap 120, 60
try { for ($i = 0; $i -lt 40; $i++) { $card.DrawToBitmap($b2, (New-Object System.Drawing.Rectangle 0, 0, 120, 60)) } } finally { $b2.Dispose() }
$sw.Stop()
$ms = [math]::Round($sw.Elapsed.TotalMilliseconds / 40, 2)
Write-Output ('PSCLASS REPORT paint ' + $ms + ' ms per card (40 cards, ' + [math]::Round($sw.Elapsed.TotalMilliseconds) + ' ms)')
Test-One 'one card paints in under 20 ms' ($ms -lt 20)
$card.Dispose()

# 3. Mouse wheel: a MouseWheel handler on a child moves the scroll of its scrolling parent (the router of T22 types, by event).
$host1 = New-Object System.Windows.Forms.Panel
$host1.AutoScroll = $true; $host1.Size = New-Object System.Drawing.Size 200, 100
$inner = New-Object System.Windows.Forms.Panel
$inner.Size = New-Object System.Drawing.Size 180, 1000
$host1.Controls.Add($inner)
$null = $host1.Handle; $null = $inner.Handle   # makes the window handles, so the scroll position takes effect off screen
$inner.Add_MouseWheel({
    param($s, $e)
    $p = $s.Parent
    $y = [math]::Max(0, - $p.AutoScrollPosition.Y - [int]($e.Delta / 120 * 40))
    $p.AutoScrollPosition = New-Object System.Drawing.Point 0, $y
    if ($e -is [System.Windows.Forms.HandledMouseEventArgs]) { $e.Handled = $true }
  })
$ev = New-Object System.Windows.Forms.HandledMouseEventArgs ([System.Windows.Forms.MouseButtons]::None), 0, 10, 10, -120
$m = $inner.GetType().GetMethod('OnMouseWheel', [System.Reflection.BindingFlags]'NonPublic,Instance')
$null = $m.Invoke($inner, @($ev))
Test-One 'a wheel step down scrolls the parent' ((- $host1.AutoScrollPosition.Y) -gt 0)
Test-One 'the wheel event is marked handled' ($ev.Handled)
$host1.Dispose()

Write-Output ('PSCLASS pass=' + $script:pass + ' fail=' + $script:fail + $script:first)
if ($script:fail -gt 0) { exit 1 }
