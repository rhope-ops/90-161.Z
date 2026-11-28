# Spike for fleet batch F6 item 6 (docs/reviews/2026-11-27-plan-f6.md): can the Kanon window (scripts/gov/90161Z-T22-types-r21.ps1)
# draw its rounded cards and route the mouse wheel with no inline C# (DEC-NIPR invariant 2: no Add-Type)?
# First finding (2026-11-27): PowerShell classes that inherit a WinForms type do not parse where WinForms is missing (the Linux
# lint of the pre-push hook: "Cannot load assembly 'System.Windows.Forms'"), so this spike tests the other way: standard
# controls with script-block event handlers (Paint, MouseWheel) and the protected DoubleBuffered flag set by reflection.
# Section 4 (R21, F6 T22) runs the real functions of scripts/gov/90161Z-T22-types-r21.ps1: chip, card, link, logo bitmaps and the wheel handlers.
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

# 0. The file the spike replaced is where the plan says.
Test-One 'the T22 types file exists' (Test-Path (Join-Path $Root 'scripts/gov/90161Z-T22-types-r21.ps1'))

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
$null = $m.Invoke($inner, [object[]]@($ev.psobject.BaseObject))   # the bare .NET object: reflection cannot take a PowerShell wrapper
Test-One 'a wheel step down scrolls the parent' ((- $host1.AutoScrollPosition.Y) -gt 0)
Test-One 'the wheel event is marked handled' ($ev.Handled)
$host1.Dispose()

# 4. The real functions of the T22 types part (the spike's way, now in the window): the drawn controls, the logo bitmap work
# (LockBits and Marshal.Copy) and the wheel handlers.

<#
.SYNOPSIS
Draw a control into a bitmap of its own size and give the bitmap back.
.PARAMETER Control
The control (its Size is set).
.OUTPUTS
System.Drawing.Bitmap (the caller disposes it).
#>
function Get-Shot($Control) {
  $bmp = New-Object System.Drawing.Bitmap $Control.Width, $Control.Height
  $Control.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle 0, 0, $Control.Width, $Control.Height))
  return , $bmp
}

<#
.SYNOPSIS
Check the drawn controls of the types part (chip, card, link): a pixel of each, and the size of the link.
#>
function Test-TypesControl {
  $white = [System.Drawing.Color]::White
  $fill = [System.Drawing.Color]::FromArgb(255, 34, 38, 49)
  $chip = Build-PfmChip; $chip.Fill = $fill; $chip.BackColor = $white; $chip.Size = New-Object System.Drawing.Size 80, 26
  $shot = Get-Shot $chip
  try { $mid = $shot.GetPixel(40, 13); $cor = $shot.GetPixel(0, 0)
    Test-One 'Build-PfmChip fills the pill in its Fill color' ($mid.R -eq 34 -and $mid.G -eq 38 -and $mid.B -eq 49)
    Test-One 'Build-PfmChip leaves the corner in the back color' ($cor.R -gt 200 -and $cor.G -gt 200) } finally { $shot.Dispose(); $chip.Dispose() }
  $card = Build-PfmCard; $card.BackColor = $white; $card.Outer = [System.Drawing.Color]::FromArgb(255, 200, 30, 30); $card.Size = New-Object System.Drawing.Size 120, 60
  $card.TopFill = [System.Drawing.Color]::FromArgb(255, 0, 83, 159); $card.TopH = 6
  $shot = Get-Shot $card
  try { $cor = $shot.GetPixel(0, 0); $top = $shot.GetPixel(60, 2); $mid = $shot.GetPixel(60, 30)
    Test-One 'Build-PfmCard paints the corner outside the edge in Outer' ($cor.R -gt 150 -and $cor.G -lt 80)
    Test-One 'Build-PfmCard paints the top bar' ($top.B -gt 120 -and $top.R -lt 40)
    Test-One 'Build-PfmCard keeps its body in the back color' ($mid.R -gt 240 -and $mid.G -gt 240) } finally { $shot.Dispose(); $card.Dispose() }
  $link = Build-PfmLinkText; $link.Text = 'Your Work'; $link.Font = New-Object System.Drawing.Font 'Segoe UI', 9
  $link.AutoSize = $true; $link.AutoSizeMode = 'GrowAndShrink'; $link.MinimumSize = New-Object System.Drawing.Size 0, 28; Resize-PfmLinkText $link
  $want = $link.GetPreferredSize([System.Drawing.Size]::Empty)
  Test-One 'a link is as high as its minimum' ($link.Height -ge 28)
  Test-One 'the preferred size of a link is not above its size (the layout self-check)' ($want.Width -le $link.Width + 1 -and $want.Height -le $link.Height + 1)
  $link.Dispose()
}

<#
.SYNOPSIS
Check the logo bitmap work of the types part on 4 pixels: no cover, white, black and half-covered yellow.
#>
function Test-TypesLogo {
  $white = [System.Drawing.Color]::White
  $src = New-Object System.Drawing.Bitmap 4, 1, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $src.SetPixel(0, 0, [System.Drawing.Color]::FromArgb(0, 0, 0, 0)); $src.SetPixel(1, 0, $white)
  $src.SetPixel(2, 0, [System.Drawing.Color]::Black); $src.SetPixel(3, 0, [System.Drawing.Color]::FromArgb(128, 255, 255, 0))
  $dark = [System.Drawing.Color]::FromArgb(255, 10, 20, 30); $light = [System.Drawing.Color]::FromArgb(255, 200, 210, 220)
  $two = ConvertTo-PfmTwoTone $src $dark $light
  try {
    $p0 = $two.GetPixel(0, 0); $p1 = $two.GetPixel(1, 0); $p2 = $two.GetPixel(2, 0); $p3 = $two.GetPixel(3, 0)
    Test-One 'TwoTone keeps a pixel with no cover clear' ($p0.A -eq 0)
    Test-One 'TwoTone gives a light pixel the light color' ($p1.A -eq 255 -and $p1.R -eq 200 -and $p1.G -eq 210 -and $p1.B -eq 220)
    Test-One 'TwoTone gives a dark pixel the dark color' ($p2.A -eq 255 -and $p2.R -eq 10 -and $p2.G -eq 20 -and $p2.B -eq 30)
    Test-One 'TwoTone keeps the cover of a half-covered pixel' ($p3.A -eq 128 -and $p3.R -eq 200)
    Test-One 'Get-PfmOtherCount finds no other color in the copy' ((Get-PfmOtherCount $two $dark $light) -eq 0)
    Test-One 'Get-PfmOtherCount counts the pixels of other colors in the source' ((Get-PfmOtherCount $src $dark $light) -eq 3)
    Test-One 'Get-PfmPixelDiff of a bitmap with itself is 0' ((Get-PfmPixelDiff $two $two) -eq 0)
    Test-One 'Get-PfmPixelDiff counts the pixels that differ' ((Get-PfmPixelDiff $src $two) -eq 3)
    $small = New-Object System.Drawing.Bitmap 2, 1
    try { Test-One 'Get-PfmPixelDiff gives -1 for sizes that differ' ((Get-PfmPixelDiff $src $small) -eq -1) } finally { $small.Dispose() }
  } finally { $two.Dispose(); $src.Dispose() }
}

<#
.SYNOPSIS
Check the wheel handlers of the types part: on the window, on a control added later and below it, and a point outside the window.
#>
function Test-TypesWheel {
  $win = New-Object System.Windows.Forms.Form; $win.ClientSize = New-Object System.Drawing.Size 300, 200
  $col = New-Object System.Windows.Forms.Panel; $col.Dock = 'Fill'; $col.AutoScroll = $true; $win.Controls.Add($col)
  Add-PfmWheel $win $col
  $late = New-Object System.Windows.Forms.Panel; $late.Size = New-Object System.Drawing.Size 100, 500; $col.Controls.Add($late)
  $deep = New-Object System.Windows.Forms.Button; $late.Controls.Add($deep)
  Test-One 'Add-PfmWheel puts the handlers on the window and its control' ($null -ne $win.PSObject.Properties['PfmWheel'] -and $null -ne $col.PSObject.Properties['PfmWheel'])
  Test-One 'a control added later gets the wheel handlers' ($null -ne $late.PSObject.Properties['PfmWheel'])
  Test-One 'a control added to a control added later gets them too' ($null -ne $deep.PSObject.Properties['PfmWheel'])
  $deep.Location = New-Object System.Drawing.Point 7, 9
  $org = Get-PfmClientOrigin $deep $win
  Test-One 'Get-PfmClientOrigin sums the Locations up to the window' ($org.X -eq 7 -and $org.Y -eq 9)
  Test-One 'a wheel turn outside the window is not routed' ($null -eq (Invoke-PfmWheelRoute $win $col ([System.Drawing.Point]::new(-5, -5)) -120))
  $win.Dispose()
}

. (Join-Path $Root 'scripts/gov/90161Z-T22-types-r21.ps1')   # at script level, like the window part that loads it
Test-TypesControl; Test-TypesLogo; Test-TypesWheel

Write-Output ('PSCLASS pass=' + $script:pass + ' fail=' + $script:fail + $script:first)
if ($script:fail -gt 0) { exit 1 }
