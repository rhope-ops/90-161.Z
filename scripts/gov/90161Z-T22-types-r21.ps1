<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "types": the window's own drawn controls, as PowerShell functions (no compiled code).
.DESCRIPTION
  R21 (F6 T22; DEC-NIPR invariant 2: no C# at run time; docs/reviews/2026-11-27-plan-f6.md): this part held C# text that
  Add-Type compiled. Now each type is a function that makes a standard Windows Forms control, adds its settings as note
  properties (Add-Member) and draws it in a Paint script block. Protected members (DoubleBuffered, SetStyle) are set by
  reflection. The proof is tests/ps/Test-PsClass.ps1 (PowerShell classes that inherit Windows Forms types do not parse
  where Windows Forms is missing, so none is used).
  Gfx -> Get-PfmRoundPath, Add-PfmRoundRegion. Chip -> Build-PfmChip. Card -> Build-PfmCard. Steps -> Build-PfmStepBar. RailItem ->
  Build-PfmRailItem. LinkText -> Build-PfmLinkText with Resize-PfmLinkText (a plain button cannot size itself to its text).
  Wheel (R7, R32 W2) -> Add-PfmWheel: a MouseWheel handler on each control of the window, also on controls added later
  (ControlAdded); the routing functions are public so the measure part can test them with no real pointer. Logo (R8,
  R35 W7) -> ConvertTo-PfmTwoTone, Get-PfmOtherCount, Get-PfmPixelDiff (LockBits and Marshal.Copy on a byte array).
  Rade.Native (HideCaret) is gone: a card text box that a click focuses gives the focus away again (see $wn.Txt).
  Inputs: none. Outputs: the functions above.
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder, after Windows Forms and System.Drawing.
  Network: none.
  Writes: none.
  Credentials: none.
#>

<#
.SYNOPSIS
  Sets the 4 paint styles of a custom-drawn control (user paint, one paint per message, double buffer, redraw on resize).
  Takes the control.
.DESCRIPTION
  Control.SetStyle is protected, so it is called by reflection (no compile).
#>
function Initialize-PfmPaintStyle($Control) {
  $flags = [System.Windows.Forms.ControlStyles]'UserPaint, AllPaintingInWmPaint, OptimizedDoubleBuffer, ResizeRedraw'
  $m = [System.Windows.Forms.Control].GetMethod('SetStyle', [System.Reflection.BindingFlags]'NonPublic,Instance')
  [void]$m.Invoke($Control, [object[]]@($flags, $true))
}

<#
.SYNOPSIS
  Adds note properties (the settings of a drawn control) to a control. Takes the control and a table of name and start value.
#>
function Add-PfmField($Control, [hashtable]$Fields) {
  foreach ($k in $Fields.Keys) { Add-Member -InputObject $Control -MemberType NoteProperty -Name $k -Value $Fields[$k] }
}

<#
.SYNOPSIS
  A closed rounded-rectangle path (Gfx.Round); a radius of half a pixel or less gives a plain rectangle.
.PARAMETER Rect
  The rectangle (RectangleF).
.PARAMETER Radius
  The corner radius in pixels.
.OUTPUTS
  System.Drawing.Drawing2D.GraphicsPath (the caller disposes it).
#>
function Get-PfmRoundPath([System.Drawing.RectangleF]$Rect, [single]$Radius) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  if ($Radius -le 0.5) { $p.AddRectangle($Rect); return , $p }
  $d = [single]($Radius * 2)
  $p.AddArc([single]$Rect.X, [single]$Rect.Y, $d, $d, 180, 90)
  $p.AddArc([single]($Rect.Right - $d), [single]$Rect.Y, $d, $d, 270, 90)
  $p.AddArc([single]($Rect.Right - $d), [single]($Rect.Bottom - $d), $d, $d, 0, 90)
  $p.AddArc([single]$Rect.X, [single]($Rect.Bottom - $d), $d, $d, 90, 90)
  $p.CloseFigure()
  return , $p
}

<#
.SYNOPSIS
  Rounds the corners of a control with a region (Gfx.RoundRegion); a control under 4 px is left as it is. Takes the control
  and the corner radius in pixels.
#>
function Add-PfmRoundRegion($Control, [int]$Radius) {
  if ($Control.Width -lt 4 -or $Control.Height -lt 4) { return }
  $p = Get-PfmRoundPath ([System.Drawing.RectangleF]::new(0, 0, $Control.Width, $Control.Height)) $Radius
  try { $old = $Control.Region; $Control.Region = [System.Drawing.Region]::new($p); if ($old) { $old.Dispose() } } finally { $p.Dispose() }
}

<#
.SYNOPSIS
  Draws a chip: a pill in the chip's Fill color with its text in the middle (Chip.OnPaint). Takes the chip (Build-PfmChip)
  and the Graphics of the Paint event.
#>
function Write-PfmChip($Chip, $G) {
  $G.Clear($Chip.BackColor)
  $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $p = Get-PfmRoundPath ([System.Drawing.RectangleF]::new(0, 0, ($Chip.Width - 1), ($Chip.Height - 1))) ($Chip.Height / 2.0)
  $b = New-Object System.Drawing.SolidBrush $Chip.Fill
  try { $G.FillPath($b, $p) } finally { $b.Dispose(); $p.Dispose() }
  [System.Windows.Forms.TextRenderer]::DrawText($G, $Chip.Text, $Chip.Font, $Chip.ClientRectangle, $Chip.ForeColor,
    [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPrefix, NoPadding')
}

<#
.SYNOPSIS
  A rounded status chip (Pfm.Chip): a control with a Fill note property (the pill color), drawn by Write-PfmChip.
#>
function Build-PfmChip {
  $c = New-Object System.Windows.Forms.Control
  Initialize-PfmPaintStyle $c
  $c.TabStop = $false
  Add-PfmField $c @{ Fill = [System.Drawing.Color]::White }
  $c.Add_Paint({ param($s, $e) Write-PfmChip $s $e.Graphics })
  return , $c
}

<#
.SYNOPSIS
  Draws a card: the corners outside the rounded edge in Outer, an optional top bar, and a thin edge in Line (Card.OnPaint).
.PARAMETER Card
  The card (Build-PfmCard).
.PARAMETER G
  The Graphics of the Paint event.
#>
function Write-PfmCard($Card, $G) {
  $smooth = $G.SmoothingMode   # the focus ring that the card's parent draws after this uses the old setting (as with the C# card)
  $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $w = $Card.Width; $h = $Card.Height
  $p = Get-PfmRoundPath ([System.Drawing.RectangleF]::new(0.5, 0.5, ($w - 1.5), ($h - 1.5))) $Card.Radius
  $r = [System.Drawing.Region]::new([System.Drawing.Rectangle]::new(0, 0, $w, $h))
  try {
    $r.Exclude($p)
    $b = New-Object System.Drawing.SolidBrush $Card.Outer
    try { $G.FillRegion($b, $r) } finally { $b.Dispose() }
    if ($Card.TopH -gt 0) {
      $st = $G.Save(); $G.SetClip($p)
      $b = New-Object System.Drawing.SolidBrush $Card.TopFill
      try { $G.FillRectangle($b, 0, 0, $w, [int]$Card.TopH) } finally { $b.Dispose(); $G.Restore($st) }
    }
    $pen = New-Object System.Drawing.Pen($Card.Line, [single]1)
    try { $G.DrawPath($pen, $p) } finally { $pen.Dispose() }
  } finally { $r.Dispose(); $p.Dispose(); $G.SmoothingMode = $smooth }
}

<#
.SYNOPSIS
  A card (Pfm.Card): a flow panel with a thin edge, rounded corners and an optional top bar, drawn by Write-PfmCard.
.DESCRIPTION
  Note properties: Line, TopFill, Outer (the color around the corners), TopH (the bar height, 0 = none), Radius.
  DoubleBuffered is protected, so reflection sets it.
#>
function Build-PfmCard {
  $c = New-Object System.Windows.Forms.FlowLayoutPanel
  $c.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance').SetValue($c, $true, $null)
  $m = [System.Windows.Forms.Control].GetMethod('SetStyle', [System.Reflection.BindingFlags]'NonPublic,Instance')
  [void]$m.Invoke($c, [object[]]@([System.Windows.Forms.ControlStyles]::ResizeRedraw, $true))
  Add-PfmField $c @{ Line = [System.Drawing.Color]::Gray; TopFill = [System.Drawing.Color]::Transparent; Outer = [System.Drawing.Color]::White; TopH = 0; Radius = 6 }
  $c.Add_Paint({ param($s, $e) Write-PfmCard $s $e.Graphics })
  return , $c
}

<#
.SYNOPSIS
  Gives the index of the largest step font whose words all fit in one cell; the last (smallest) when none fits.
.PARAMETER Steps
  The step bar (Build-PfmStepBar).
.PARAMETER Cell
  The width of one step cell.
#>
function Get-PfmStepFont($Steps, [single]$Cell) {
  $flags = [System.Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix'
  $wide = [System.Drawing.Size]::new(100000, 0)
  $labels = @($Steps.Labels)
  for ($k = 0; $k -lt @($Steps.Fonts).Count; $k++) {
    $ok = $true
    for ($i = 0; $i -lt $labels.Count -and $ok; $i++) {
      $f = $(if ($i + 1 -eq $Steps.Current) { $Steps.FontsB[$k] } else { $Steps.Fonts[$k] })
      foreach ($w in ([string]$labels[$i]).Split(' ')) {
        if ([System.Windows.Forms.TextRenderer]::MeasureText($w, $f, $wide, $flags).Width -gt $Cell - 4) { $ok = $false; break }
      }
    }
    if ($ok) { return $k }
  }
  return (@($Steps.Fonts).Count - 1)
}

<#
.SYNOPSIS
  Draws one step: the dot in its state colors with its number, and its name under it (Steps.OnPaint, per step).
.PARAMETER Steps
  The step bar.
.PARAMETER G
  The Graphics of the Paint event.
.PARAMETER Index
  The step, counted from 0.
.PARAMETER Cell
  The width of one step cell.
.PARAMETER FontIndex
  The index of the font size chosen for the bar.
#>
function Write-PfmStep($Steps, $G, [int]$Index, [single]$Cell, [int]$FontIndex) {
  $num = $Index + 1; $cur = [int]$Steps.Current; $dot = [single]$Steps.Dot; $top = [single]2
  $rc = [System.Drawing.RectangleF]::new((($Index + 0.5) * $Cell - $dot / 2), $top, $dot, $dot)
  if ($num -lt $cur) { $fill = $Steps.DoneFill; $line = $Steps.DoneFill; $tx = $Steps.DoneText; $lw = [single]2 }
  elseif ($num -eq $cur) { $fill = $Steps.NowFill; $line = $Steps.NowLine; $tx = $Steps.NowText; $lw = [single]3 }
  else { $fill = $Steps.TodoFill; $line = $Steps.TodoLine; $tx = $Steps.TodoText; $lw = [single]2 }
  $b = New-Object System.Drawing.SolidBrush $fill
  try { $G.FillEllipse($b, $rc) } finally { $b.Dispose() }
  $ri = [System.Drawing.RectangleF]::new(($rc.X + $lw / 2), ($rc.Y + $lw / 2), ($rc.Width - $lw), ($rc.Height - $lw))
  $pen = New-Object System.Drawing.Pen($line, $lw)
  try { $G.DrawEllipse($pen, $ri) } finally { $pen.Dispose() }
  [System.Windows.Forms.TextRenderer]::DrawText($G, [string]$num, $Steps.FontsB[$FontIndex], [System.Drawing.Rectangle]::Round($rc), $tx,
    [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding, NoPrefix')
  $y = [int][math]::Truncate($top + $dot + 4)
  $lr = [System.Drawing.Rectangle]::new([int][math]::Truncate($Index * $Cell) + 1, $y, [int][math]::Truncate($Cell) - 2, $Steps.Height - $y)
  $lc = $(if ($num -lt $cur) { $Steps.LabelDone } elseif ($num -eq $cur) { $Steps.LabelNow } else { $Steps.LabelTodo })
  $lf = $(if ($num -eq $cur) { $Steps.FontsB[$FontIndex] } else { $Steps.Fonts[$FontIndex] })
  [System.Windows.Forms.TextRenderer]::DrawText($G, [string]$Steps.Labels[$Index], $lf, $lr, $lc,
    [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, Top, WordBreak, NoPadding, NoPrefix')
}

<#
.SYNOPSIS
  Draws the step bar: the connector lines between the dots, then each step (Steps.OnPaint).
.PARAMETER Steps
  The step bar (Build-PfmStepBar).
.PARAMETER G
  The Graphics of the Paint event.
#>
function Write-PfmStepBar($Steps, $G) {
  $G.Clear($Steps.BackColor)
  $n = @($Steps.Labels).Count
  if ($n -eq 0 -or @($Steps.Fonts).Count -eq 0) { return }
  $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $cell = [single]$Steps.Width / $n
  $key = [string]$Steps.Width + '/' + $Steps.Current   # the font choice depends on the width and the current step only
  if ($Steps.FitKey -ne $key) { $Steps.FitIndex = Get-PfmStepFont $Steps $cell; $Steps.FitKey = $key }
  $cy = [single](2 + $Steps.Dot / 2.0)
  for ($i = 1; $i -lt $n; $i++) {
    $pen = New-Object System.Drawing.Pen($(if ($i + 1 -le $Steps.Current) { $Steps.ConnDone } else { $Steps.ConnTodo }), [single]3)
    try { $G.DrawLine($pen, [single](($i - 0.5) * $cell), $cy, [single](($i + 0.5) * $cell), $cy) } finally { $pen.Dispose() }
  }
  for ($i = 0; $i -lt $n; $i++) { Write-PfmStep $Steps $G $i $cell $Steps.FitIndex }
}

<#
.SYNOPSIS
  The 12 step dots (Pfm.Steps): a control with the settings Labels, Current, Dot, the state colors and the font lists.
#>
function Build-PfmStepBar {
  $c = New-Object System.Windows.Forms.Control
  Initialize-PfmPaintStyle $c
  $c.TabStop = $false
  $col = [System.Drawing.Color]
  Add-PfmField $c @{ Labels = [string[]]@(); Current = 1; Dot = 26; Fonts = [System.Drawing.Font[]]@(); FontsB = [System.Drawing.Font[]]@(); FitKey = ''; FitIndex = 0
    DoneFill = $col::Blue; DoneText = $col::White; NowFill = $col::Yellow; NowLine = $col::Navy; NowText = $col::Black
    TodoFill = $col::White; TodoLine = $col::Gray; TodoText = $col::Black; ConnDone = $col::Blue; ConnTodo = $col::Gray
    LabelDone = $col::Black; LabelNow = $col::Navy; LabelTodo = $col::Gray }
  $c.Add_Paint({ param($s, $e) Write-PfmStepBar $s $e.Graphics })
  return , $c
}

<#
.SYNOPSIS
  Draws a rail item: its back (filled when on, an outline when the pointer is over it), a focus ring, the badge and the text.
.PARAMETER Item
  The rail item (Build-PfmRailItem).
.PARAMETER G
  The Graphics of the Paint event.
#>
function Write-PfmRailItem($Item, $G) {
  $tf = [System.Windows.Forms.TextFormatFlags]
  $G.Clear($Item.Back)
  $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $rc = [System.Drawing.RectangleF]::new(0.5, 0.5, ($Item.Width - 2), ($Item.Height - 2))
  $p = Get-PfmRoundPath $rc 4
  try {
    if ($Item.On) { $b = New-Object System.Drawing.SolidBrush $Item.OnBack; try { $G.FillPath($b, $p) } finally { $b.Dispose() } }
    elseif ($Item.Hot) { $pen = New-Object System.Drawing.Pen($Item.HotLine, [single]1); try { $G.DrawPath($pen, $p) } finally { $pen.Dispose() } }
  } finally { $p.Dispose() }
  if ($Item.Focused) {
    $q = Get-PfmRoundPath ([System.Drawing.RectangleF]::new(($rc.X + 2), ($rc.Y + 2), ($rc.Width - 4), ($rc.Height - 4))) 3
    $pen = New-Object System.Drawing.Pen($(if ($Item.On) { $Item.FocusOn } else { $Item.FocusLine }), [single]2)
    try { $G.DrawPath($pen, $q) } finally { $pen.Dispose(); $q.Dispose() }
  }
  $right = $Item.Width - 14
  if ($Item.Badge.Length -gt 0) {
    $d = [int][math]::Truncate($Item.Height / 2)
    $br = [System.Drawing.Rectangle]::new(($Item.Width - 14 - $d), [int][math]::Truncate(($Item.Height - $d) / 2), $d, $d)
    $b = New-Object System.Drawing.SolidBrush $Item.BadgeFill
    try { $G.FillEllipse($b, $br) } finally { $b.Dispose() }
    $bf = $(if ($Item.BoldFont) { $Item.BoldFont } else { $Item.Font })
    [System.Windows.Forms.TextRenderer]::DrawText($G, $Item.Badge, $bf, $br, $Item.BadgeText,
      $tf::HorizontalCenter -bor $tf::VerticalCenter -bor $tf::SingleLine -bor $tf::NoPadding -bor $tf::NoPrefix)
    $right = $br.Left - 6
  }
  $tr = [System.Drawing.Rectangle]::new(14, 0, [math]::Max(1, $right - 14), $Item.Height)
  $font = $(if ($Item.On -and $Item.BoldFont) { $Item.BoldFont } else { $Item.Font })
  [System.Windows.Forms.TextRenderer]::DrawText($G, $Item.Text, $font, $tr, $(if ($Item.On) { $Item.OnFore } else { $Item.Fore }),
    $tf::Left -bor $tf::VerticalCenter -bor $tf::SingleLine -bor $tf::NoPrefix -bor $tf::EndEllipsis)
}

<#
.SYNOPSIS
  A rail button (Pfm.RailItem): a flat button that Write-PfmRailItem draws; the pointer and the focus redraw it.
.DESCRIPTION
  Note properties: On, Badge, Hot, BoldFont and the colors Back, OnBack, Fore, OnFore, HotLine, FocusLine, FocusOn, BadgeFill, BadgeText.
#>
function Build-PfmRailItem {
  $c = New-Object System.Windows.Forms.Button
  Initialize-PfmPaintStyle $c
  $c.FlatStyle = 'Flat'; $c.TabStop = $true
  $col = [System.Drawing.Color]
  Add-PfmField $c @{ On = $false; Badge = ''; Hot = $false; BoldFont = $null; Back = $col::Navy; OnBack = $col::White; Fore = $col::White; OnFore = $col::Navy
    HotLine = $col::White; FocusLine = $col::Yellow; FocusOn = $col::Navy; BadgeFill = $col::Yellow; BadgeText = $col::Black }
  $c.Add_MouseEnter({ $this.Hot = $true; $this.Invalidate() })
  $c.Add_MouseLeave({ $this.Hot = $false; $this.Invalidate() })
  $c.Add_GotFocus({ $this.Invalidate() })
  $c.Add_LostFocus({ $this.Invalidate() })
  $c.Add_Paint({ param($s, $e) Write-PfmRailItem $s $e.Graphics })
  return , $c
}

<#
.SYNOPSIS
  Sizes a link to its text: as wide as the text plus 1 px, as high as the text or the minimum height (LinkText.GetPreferredSize).
  Takes the link (Build-PfmLinkText).
.DESCRIPTION
  A plain button cannot override GetPreferredSize, so the maximum size does it: Windows Forms keeps the preferred size of a
  control between its MinimumSize and its MaximumSize. The caller sets the Text, Font and MinimumSize first (and AutoSize
  on), then calls this; the layout self-check then finds the preferred size equal to the size. Call it again when the text
  or the font changes.
.PARAMETER Link
  The link button that Build-PfmLinkText made, with its Text, Font and MinimumSize set.
.OUTPUTS
  None. It sets the link's MaximumSize and Size.
#>
function Resize-PfmLinkText($Link) {
  # Measure with a screen Graphics, as the C# did: the MeasureText overload with no device context does not apply
  # NoPadding, and the link then gets about 8 px of padding after its text (ps51 run 46105124709: crumb gap 13 px).
  $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
  try {
    $t = [System.Windows.Forms.TextRenderer]::MeasureText($g, $Link.Text, $Link.Font, [System.Drawing.Size]::new(100000, 0),
      [System.Windows.Forms.TextFormatFlags]'Left, VerticalCenter, SingleLine, NoPrefix, NoPadding')
  } finally { $g.Dispose() }
  $fit = [System.Drawing.Size]::new(($t.Width + 1), [math]::Max($Link.MinimumSize.Height, $t.Height))
  $Link.MaximumSize = $fit; $Link.Size = $fit
}

<#
.SYNOPSIS
  A crumb link (Pfm.LinkText): a flat button with no border that draws its text in its own font and color, no padding.
#>
function Build-PfmLinkText {
  $c = New-Object System.Windows.Forms.Button
  Initialize-PfmPaintStyle $c
  $c.FlatStyle = 'Flat'; $c.FlatAppearance.BorderSize = 0; $c.TabStop = $true; $c.UseMnemonic = $false
  $c.Add_Paint({ param($s, $e)
      $e.Graphics.Clear($s.BackColor)
      [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $s.Text, $s.Font, $s.ClientRectangle, $s.ForeColor,
        [System.Windows.Forms.TextFormatFlags]'Left, VerticalCenter, SingleLine, NoPrefix, NoPadding') })
  return , $c
}

<#
.SYNOPSIS
  The deepest visible control of a root under a point (Wheel.Under), from the control tree, front child first. Takes the root
  (the window) and the point in its client pixels.
.DESCRIPTION
  A point outside a control's client area (its scroll bar) stops at that control.
#>
function Get-PfmWheelUnder($Root, [System.Drawing.Point]$Client) {
  $c = $Root; $p = $Client
  while ($true) {
    if (-not $c.ClientRectangle.Contains($p)) { return $c }
    $hit = $null
    foreach ($k in $c.Controls) { if ($k.Visible -and $k.Bounds.Contains($p)) { $hit = $k; break } }
    if ($null -eq $hit) { return $c }
    $p = [System.Drawing.Point]::new(($p.X - $hit.Left), ($p.Y - $hit.Top)); $c = $hit
  }
}

<#
.SYNOPSIS
  The client origin of a control in the client pixels of a root (Wheel.ClientOf): the Locations summed up the parents.
  Takes the control and the root (the window).
#>
function Get-PfmClientOrigin($Control, $Root) {
  $x = 0; $y = 0
  for ($k = $Control; $null -ne $k -and -not [object]::ReferenceEquals($k, $Root); $k = $k.Parent) { $x += $k.Left; $y += $k.Top }
  return [System.Drawing.Point]::new($x, $y)
}

<#
.SYNOPSIS
  True when a grid can scroll up (Delta above 0) or down (Wheel.GridCan). Takes the grid and the wheel delta (120 per notch,
  positive = away from you).
#>
function Test-PfmGridCanScroll($Grid, [int]$Delta) {
  if ($Grid.RowCount -eq 0 -or $Grid.FirstDisplayedScrollingRowIndex -lt 0) { return $false }
  if ($Delta -gt 0) { return ($Grid.FirstDisplayedScrollingRowIndex -gt 0) }
  return (($Grid.FirstDisplayedScrollingRowIndex + $Grid.DisplayedRowCount($false)) -lt $Grid.RowCount)
}

<#
.SYNOPSIS
  True when a scrolling panel can scroll up (Delta above 0) or down (Wheel.PanelCan). Takes the panel and the wheel delta.
#>
function Test-PfmPanelCanScroll($Panel, [int]$Delta) {
  $y = -$Panel.AutoScrollPosition.Y
  if ($Delta -gt 0) { return ($y -gt 0) }
  return ($y -lt ($Panel.DisplayRectangle.Height - $Panel.ClientSize.Height))
}

<#
.SYNOPSIS
  The first control from Under up to Stop that can still scroll that way (Wheel.Target): a grid with rows out of view, or
  a panel that scrolls (AutoScroll with its vertical bar showing). Nothing: null. Takes the control under the pointer, the last
  control to look at (the main column) and the wheel delta.
#>
function Get-PfmWheelTarget($Under, $Stop, [int]$Delta) {
  for ($c = $Under; $null -ne $c; $c = $c.Parent) {
    if ($c -is [System.Windows.Forms.DataGridView] -and (Test-PfmGridCanScroll $c $Delta)) { return $c }
    if ($c -is [System.Windows.Forms.ScrollableControl] -and $c.AutoScroll -and $c.VerticalScroll.Visible -and (Test-PfmPanelCanScroll $c $Delta)) { return $c }
    if ([object]::ReferenceEquals($c, $Stop)) { break }
  }
  return $null
}

<#
.SYNOPSIS
  Scrolls a target (Wheel.Apply): a grid by the Windows wheel lines per notch (rows), a panel by Delta pixels.
.PARAMETER Target
  The grid or scrolling panel.
.PARAMETER Delta
  The wheel delta.
#>
function Invoke-PfmWheelApply($Target, [int]$Delta) {
  if ($Target -is [System.Windows.Forms.DataGridView]) {
    $lines = [System.Windows.Forms.SystemInformation]::MouseWheelScrollLines
    if ($lines -le 0) { $lines = [math]::Max(1, $Target.DisplayedRowCount($false)) }
    $rows = [int][math]::Round(-$Delta / 120.0 * $lines)
    if ($rows -eq 0) { $rows = $(if ($Delta -gt 0) { -1 } else { 1 }) }
    $Target.FirstDisplayedScrollingRowIndex = [math]::Max(0, [math]::Min($Target.RowCount - 1, $Target.FirstDisplayedScrollingRowIndex + $rows))
    return
  }
  $Target.AutoScrollPosition = [System.Drawing.Point]::new((-$Target.AutoScrollPosition.X), (-$Target.AutoScrollPosition.Y - $Delta))
}

<#
.SYNOPSIS
  Routes one wheel turn at a point (Wheel.Route): scrolls the control that takes it and gives it back, or gives back null
  when the pointer is not on the window, is on a list or a text box with its own scroll bar, or nothing under it can scroll.
  Takes the window, the last control to look at (the main column), the pointer in client pixels of the window and the wheel delta.
#>
function Invoke-PfmWheelRoute($Root, $Stop, [System.Drawing.Point]$Client, [int]$Delta) {
  if ($Delta -eq 0 -or -not $Root.ClientRectangle.Contains($Client)) { return $null }
  $under = Get-PfmWheelUnder $Root $Client
  if ($under -is [System.Windows.Forms.ComboBox]) { return $null }
  if ($under -is [System.Windows.Forms.TextBoxBase] -and $under.Multiline -and $under.TabStop) { return $null }
  $t = Get-PfmWheelTarget $under $Stop $Delta
  if ($null -ne $t) { Invoke-PfmWheelApply $t $Delta }
  return $t
}

<#
.SYNOPSIS
  Wheel handler of one control. Windows sends the wheel to the control with the focus, so this routes the turn by the pointer
  (the event point, turned into window pixels) and marks the event handled when a control took it. Takes the control that
  has the event and the MouseWheel event arguments.
#>
function Invoke-PfmWheelEvent($Source, $E) {
  if ($E -is [System.Windows.Forms.HandledMouseEventArgs] -and $E.Handled) { return }   # a control that scrolls itself took the turn
  $form = $Source.FindForm()
  if ($null -eq $form -or $null -eq $form.PSObject.Properties['PfmStop']) { return }
  $pt = $form.PointToClient($Source.PointToScreen($E.Location))
  $t = Invoke-PfmWheelRoute $form $form.PfmStop $pt $E.Delta
  if ($null -ne $t -and $E -is [System.Windows.Forms.HandledMouseEventArgs]) { $E.Handled = $true }
}

<#
.SYNOPSIS
  Puts the wheel handler on a control and on every control under it, and on each control added to them later (ControlAdded).
  A control that has the handler already is skipped, with its children. Takes the control.
#>
function Add-PfmWheelTree($Control) {
  if ($null -ne $Control.PSObject.Properties['PfmWheel']) { return }
  Add-Member -InputObject $Control -MemberType NoteProperty -Name PfmWheel -Value $true
  $Control.Add_MouseWheel({ param($s, $e) Invoke-PfmWheelEvent $s $e })
  $Control.Add_ControlAdded({ Add-PfmWheelTree $_.Control })
  foreach ($k in @($Control.Controls)) { Add-PfmWheelTree $k }
}

<#
.SYNOPSIS
  The mouse wheel scrolls what is under the pointer, whatever control has the focus (R7, R32 W2; was the Pfm.Wheel filter).
  Takes the window and the last control to look at (the main column).
.DESCRIPTION
  A turn anywhere on the window scrolls the grid under the pointer while that grid can still scroll, else the main column;
  keys and focus are not touched.
#>
function Add-PfmWheel($Owner, $Stop) {
  if ($null -eq $Owner.PSObject.Properties['PfmStop']) { Add-Member -InputObject $Owner -MemberType NoteProperty -Name PfmStop -Value $Stop }
  Add-PfmWheelTree $Owner
}

<#
.SYNOPSIS
  Sends one wheel turn to a control the way Windows does (for the measure part): its MouseWheel event with the pointer.
  Takes the control that has the focus, the pointer in screen pixels and the wheel delta; gives back True when handled.
#>
function Send-PfmWheel($Control, [System.Drawing.Point]$Screen, [int]$Delta) {
  $pt = $Control.PointToClient($Screen)
  $ev = New-Object System.Windows.Forms.HandledMouseEventArgs ([System.Windows.Forms.MouseButtons]::None), 0, $pt.X, $pt.Y, $Delta
  $m = $Control.GetType().GetMethod('OnMouseWheel', [System.Reflection.BindingFlags]'NonPublic,Instance')
  [void]$m.Invoke($Control, [object[]]@($ev.psobject.BaseObject))   # the bare .NET object: reflection cannot take a PowerShell wrapper
  return [bool]$ev.Handled
}

<#
.SYNOPSIS
  The pixels of a bitmap as a byte array in the order blue, green, red, cover (alpha), by LockBits and Marshal.Copy. Takes the
  bitmap (read only; any format is read as 32 bits a pixel). Gives back a table: Bytes, Stride (bytes a row), Width, Height.
#>
function Get-PfmPixelData([System.Drawing.Bitmap]$Bitmap) {
  $rect = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
  $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $bytes = [byte[]]::new([math]::Abs($data.Stride) * $data.Height)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    return @{ Bytes = $bytes; Stride = [math]::Abs($data.Stride); Width = $Bitmap.Width; Height = $Bitmap.Height }
  } finally { $Bitmap.UnlockBits($data) }
}

<#
.SYNOPSIS
  A copy of a bitmap in 2 colors (Logo.TwoTone): each pixel keeps its cover (alpha); a pixel with a weighted brightness
  of 128 or more (of 255) takes Light, the others Dark. A pixel with no cover stays clear.
.PARAMETER Source
  The bitmap.
.PARAMETER Dark
  The color of the dark pixels.
.PARAMETER Light
  The color of the light pixels.
#>
function ConvertTo-PfmTwoTone([System.Drawing.Bitmap]$Source, [System.Drawing.Color]$Dark, [System.Drawing.Color]$Light) {
  $in = Get-PfmPixelData $Source
  $a = $in.Bytes; $stride = $in.Stride
  $out = [byte[]]::new($a.Length)
  for ($y = 0; $y -lt $in.Height; $y++) {
    for ($x = 0; $x -lt $in.Width; $x++) {
      $i = $y * $stride + $x * 4
      if ($a[$i + 3] -eq 0) { continue }
      $t = $(if (($a[$i + 2] * 299 + $a[$i + 1] * 587 + $a[$i] * 114) -ge 128000) { $Light } else { $Dark })
      $out[$i] = $t.B; $out[$i + 1] = $t.G; $out[$i + 2] = $t.R; $out[$i + 3] = $a[$i + 3]
    }
  }
  $o = New-Object System.Drawing.Bitmap $in.Width, $in.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $rect = [System.Drawing.Rectangle]::new(0, 0, $in.Width, $in.Height)
  $data = $o.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $rows = [math]::Abs($data.Stride)
    for ($y = 0; $y -lt $in.Height; $y++) { [System.Runtime.InteropServices.Marshal]::Copy($out, ($y * $stride), [IntPtr]($data.Scan0.ToInt64() + $y * $rows), ($in.Width * 4)) }
  } finally { $o.UnlockBits($data) }
  return , $o
}

<#
.SYNOPSIS
  The number of pixels of a bitmap with any cover whose color (cover left out) is neither P nor Q (Logo.Other).
.PARAMETER Bitmap
  The bitmap.
.PARAMETER P
  The first color that is allowed.
.PARAMETER Q
  The second color that is allowed.
#>
function Get-PfmOtherCount([System.Drawing.Bitmap]$Bitmap, [System.Drawing.Color]$P, [System.Drawing.Color]$Q) {
  $in = Get-PfmPixelData $Bitmap
  $a = $in.Bytes; $n = 0
  for ($y = 0; $y -lt $in.Height; $y++) {
    for ($x = 0; $x -lt $in.Width; $x++) {
      $i = $y * $in.Stride + $x * 4
      if ($a[$i + 3] -eq 0) { continue }
      $isP = ($a[$i + 2] -eq $P.R -and $a[$i + 1] -eq $P.G -and $a[$i] -eq $P.B)
      $isQ = ($a[$i + 2] -eq $Q.R -and $a[$i + 1] -eq $Q.G -and $a[$i] -eq $Q.B)
      if (-not $isP -and -not $isQ) { $n++ }
    }
  }
  return $n
}

<#
.SYNOPSIS
  The number of pixels whose color or cover differs between 2 bitmaps; -1 when their sizes differ (Logo.Diff).
.PARAMETER A
  The first bitmap.
.PARAMETER B
  The second bitmap.
#>
function Get-PfmPixelDiff([System.Drawing.Bitmap]$A, [System.Drawing.Bitmap]$B) {
  if ($A.Width -ne $B.Width -or $A.Height -ne $B.Height) { return -1 }
  $pa = Get-PfmPixelData $A; $pb = Get-PfmPixelData $B
  $x1 = $pa.Bytes; $x2 = $pb.Bytes; $n = 0
  for ($y = 0; $y -lt $pa.Height; $y++) {
    for ($x = 0; $x -lt $pa.Width; $x++) {
      $i = $y * $pa.Stride + $x * 4; $j = $y * $pb.Stride + $x * 4
      if ($x1[$i + 3] -ne $x2[$j + 3]) { $n++; continue }
      if ($x1[$i + 3] -ne 0 -and ($x1[$i] -ne $x2[$j] -or $x1[$i + 1] -ne $x2[$j + 1] -or $x1[$i + 2] -ne $x2[$j + 2])) { $n++ }
    }
  }
  return $n
}
