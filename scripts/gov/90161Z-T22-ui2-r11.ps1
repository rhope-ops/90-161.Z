<#
.SYNOPSIS
  90-161.Z Task 22 r11, part "ui2": the second half of the RADE shared UI file, generated into this file, and the colors
  for Windows high contrast.
.DESCRIPTION
  R11 (R38; PFM 20 Nov 26): new part. engine-v29's shared UI file (599 lines) is split in 2 so each part stays under the
  600-line file cap (code standard C4); scripts/build_task_scripts.py writes the block between the rade-ui-2 markers from
  the pinned RADE commit (scripts/rade.lock.json); never edit it here. It runs right after part "ui", inside the main
  script's try block. The lines after the block choose the colors for Windows high contrast (R31 W2): Select-T22Color
  and $ui.UseColors (the window part applies them: $wn.Recolor).
  Inputs: $ui (filled by part "ui"), $pc. Outputs: the $ui members of the second half of the shared UI file, $ui.HcRole,
  $ui.OwnPc, $ui.OwnC, $ui.High, $ui.UseColors and the function Select-T22Color.
  Run: not alone; 90161Z-T22-pfm-window-r11.ps1 dot-sources it from its own folder.
  Network: none.
  Writes: none.
  Credentials: none.
#>
$apps = @(@{ Mode = 'test' })   # one test application, so the layout self-check of the shared UI file runs
# >>> rade-ui-2: generated from the pinned RADE shared UI file (second half) by scripts/build_task_scripts.py (do not edit)
$ui.InkFit = { param($P)
  if (-not $ui.Scaled) { return }
  try { $fi = & $ui.FontInk $P.Font; $h = $(if ($P.Tag.Desc) { $fi.Bottom } else { $fi.Base }) - $fi.Top; $w = 1; $P.Tag.Left = 0
    if ($P.Text) { $box = & $ui.InkOf ([string]$P.Text) $P.Font
      if ($box) { $P.Tag.Left = [int]$box.Left; $w = [int]$box.Right - [int]$box.Left }
      else { $w = [int][System.Windows.Forms.TextRenderer]::MeasureText([string]$P.Text, $P.Font).Width } }
    $P.Tag.Cut = ([int]$P.Tag.MaxW -gt 0 -and $w -gt [int]$P.Tag.MaxW)   # cut = the text is wider than its widest size: only then it ends with "..."
    if ($P.Tag.Cut) { $w = [int]$P.Tag.MaxW }
    $ns = New-Object System.Drawing.Size(([math]::Max(1, $w)), ([math]::Max(1, $h))); if ($P.Width -ne $ns.Width -or $P.Height -ne $ns.Height) { $P.Size = $ns }
    if ($P.Text) { $P.AccessibleName = [string]$P.Text }; $P.Invalidate() } catch { $null = $_ } }   # no size now: the next fit sizes it
# Draws the text of an ink-tight panel: moved left and up by the empty room of its text cell, so the ink starts at the
# panel's left and top edge; a text cut to its widest size (Tag.Cut) ends with "...". Takes the panel and its Graphics.
$ui.InkPaint = { param($P, $G)
  try { $G.Clear($P.BackColor); if (-not $P.Text) { return }
    $fi = & $ui.FontInk $P.Font; $l = [int]$P.Tag.Left
    # R32 (the Administrator, 2026-11-18: "RA..." at 150 %): the panel is as wide as the ink, and Windows needs the text's whole
    # cell (the ink and the last letter's side room, 1 or 2 px more at a large size) or it ends the text with "...". So a text
    # that is not cut gets room past the panel's edge (nothing is drawn there) and no "..." rule; a cut text keeps both.
    $room = $P.ClientSize.Width + $l; $fl = 'Left, Top, NoPadding, NoPrefix, SingleLine, EndEllipsis'
    if (-not $P.Tag.Cut) { $room += [int][math]::Max(8, $fi.Bottom); $fl = 'Left, Top, NoPadding, NoPrefix, SingleLine' }
    [System.Windows.Forms.TextRenderer]::DrawText($G, [string]$P.Text, $P.Font, (New-Object System.Drawing.Rectangle((-$l), (-[int]$fi.Top), $room, ([int]$fi.Bottom + 4))), $P.ForeColor, $P.BackColor, [System.Windows.Forms.TextFormatFlags]$fl) } catch { $null = $_ } }   # drawing never stops the window
# Where the ink of a control is, measured on what Windows drew (DrawToBitmap; the first 240 px of its width): gives back
# @{ Top; Bottom; Left; Right } in the control's own pixels, or its whole box when it cannot be measured. Takes the control.
$ui.InkBox = { param($C)
  $all = @{ Top = 0; Bottom = [int]$C.Height; Left = 0; Right = [int]$C.Width }
  try { $w = [math]::Max(1, [math]::Min([int]$C.Width, (& $ui.Sc 240))); $h = [math]::Max(1, [int]$C.Height); $bm = New-Object System.Drawing.Bitmap($w, $h)
    try { $C.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $w, $h))); $box = & $ui.InkScan $bm; if ($box) { return $box } } finally { $bm.Dispose() } } catch { $null = $_ }   # no bitmap (the test stand-ins): the whole box
  return $all }
# ---- Long words and one-line texts
# A word wider than the line (no space in it) is cut into pieces that fit, one per line: it wraps by character and is
# never clipped (R7 review). Only what the window shows changes; the report keeps the text.
# The width a label needs to show a text in one line: asked of a label that is never shown, with the same font and flags
# as the window's labels (R24 job: TextRenderer's default flags gave 3 to 9 px more than a label uses).
$ui.Probe = New-Object System.Windows.Forms.Label; $ui.Probe.AutoSize = $true; $ui.Probe.UseMnemonic = $false; $ui.Trash = @(@($ui.Trash) | Where-Object { $_ }) + @($ui.Probe)   # disposed when the window has closed
$ui.WordW = { param([string]$T, $F) try { $ui.Probe.Font = $F; $ui.Probe.Text = $T; return [int]$ui.Probe.PreferredSize.Width } catch { return [int][System.Windows.Forms.TextRenderer]::MeasureText($T, $F).Width } }
$ui.Most = @{}   # the widest values of each label of changing values ($ui.FixW)
# A label that shows changing values (a percent, a count, a time; $ui.Most[label] = the widest values it can show) keeps one
# size: as wide as the widest of them and one line tall, so nothing beside it moves when the value changes (the
# Administrator, 2026-11-19). A value wider than all of them still fits: the label grows for it. Does nothing before the
# window has its scale (Windows Forms would scale the size again). Takes the label; gives back nothing.
$ui.FixW = { param($L) if (-not $ui.Scaled) { return }
  try { $w = 0; foreach ($x in @(@($ui.Most[$L]) + @([string]$L.Text) | Where-Object { $_ })) { $w = [math]::Max($w, (& $ui.WordW ([string]$x) $L.Font)) }
    $ui.Probe.Font = $L.Font; $ui.Probe.Text = '0'; $h = [int]$ui.Probe.PreferredSize.Height; if ($L.AutoSize) { $L.AutoSize = $false }
    if ($L.Width -ne $w -or $L.Height -ne $h) { $L.Size = New-Object System.Drawing.Size($w, $h) } } catch { $null = $_ } }   # no measure: the next fit sets it
# The height of one line of text in a font, as Windows draws it (TextRenderer: on a 150 % screen it can be taller than
# what a text box gives itself; R35 "Field line cut: one line needs 32 high, has 27"). Takes the font; gives back pixels.
$ui.LineH = { param($Font) [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $Font).Height }
$ui.BreakLong = { param([string]$T, $F, [int]$W)
  if ($W -le 0 -or -not $T) { return $T }
  $parts = foreach ($ln in ($T -split '(\r?\n)')) {   # line by line; the line breaks are kept
    if ($ln -match '^\r?\n$') { $ln; continue }
    $ws = foreach ($wd in ($ln -split ' ')) {
      if ((& $ui.WordW $wd $F) -le $W) { $wd; continue }
      # by text element (M4 review): a surrogate pair or a letter with its accents is never split
      $pc = @(); $cur = ''; $en = [System.Globalization.StringInfo]::GetTextElementEnumerator($wd)
      while ($en.MoveNext()) { $ch = [string]$en.GetTextElement(); if ($cur -and (& $ui.WordW ($cur + $ch) $F) -gt $W) { $pc += $cur; $cur = '' }; $cur += $ch }
      $pc += $cur; $pc -join "`n" }
    @($ws) -join ' ' }
  return (@($parts) -join '') }
# ---- Shortened text
# A one-line text cut to fit a width with "..." at the end, measured by the control itself (M5 review: no AutoEllipsis,
# which shows a tooltip). Binary search on the number of text elements.
$ui.Shorten = { param($C, [string]$Full, [int]$W)
  $C.Text = $Full; if ($C.PreferredSize.Width -le $W) { return }
  $si = New-Object System.Globalization.StringInfo($Full); $lo = 0; $hi = $si.LengthInTextElements
  while ($lo -lt $hi) { $mid = [int][math]::Ceiling(($lo + $hi) / 2.0); $C.Text = $si.SubstringByTextElements(0, $mid).TrimEnd() + '...'; if ($C.PreferredSize.Width -le $W) { $lo = $mid } else { $hi = $mid - 1 } }
  $C.Text = $(if ($lo -gt 0) { $si.SubstringByTextElements(0, $lo).TrimEnd() } else { '' }) + '...' }
# Cuts a text to N lines with "..." (the help below).
$ui.FitLines = {
  <#
  .SYNOPSIS
  Cuts a text to at most N lines at a width, with "..." at its end when it is cut (the Administrator, 2026-11-19).
  .DESCRIPTION
  Measured as a card text box wraps ($ui.Meas). Binary search on the number of text elements, so a letter with its accents
  is never split. The text is not changed when it fits.
  .PARAMETER T
  The text.
  .PARAMETER F
  The font it shows in.
  .PARAMETER W
  The wrap width, in pixels.
  .PARAMETER N
  The most lines it may take.
  .OUTPUTS
  The text that fits, as a string.
  #>
  param([string]$T, $F, [int]$W, [int]$N)
  if (-not $T -or $W -le 0 -or $N -le 0) { return $T }
  $most = $N * (& $ui.Meas 'Ag' $F 100000).Height
  if ((& $ui.Meas $T $F $W).Height -le $most) { return $T }
  $si = New-Object System.Globalization.StringInfo($T); $lo = 0; $hi = $si.LengthInTextElements
  while ($lo -lt $hi) { $mid = [int][math]::Ceiling(($lo + $hi) / 2.0); $x = $si.SubstringByTextElements(0, $mid).TrimEnd() + '...'; if ((& $ui.Meas $x $F $W).Height -le $most) { $lo = $mid } else { $hi = $mid - 1 } }
  return ($(if ($lo -gt 0) { $si.SubstringByTextElements(0, $lo).TrimEnd() } else { '' }) + '...') }
# The self-check's rule for it: a word of a text that wraps is never wider than the line the text may take (a label's
# MaximumSize, a card text box's $ui.GetWrap; else the word is cut). Not the label's own width: a wrapping label is as wide
# as its widest line by its own measure, about 1 % narrower than the probe's, so a cut piece that is the widest line would
# always seem too wide (R28 job: 591/588, 597/591, 592/588).
$ui.WordBad = { param([string]$Card, [string]$Name, [string]$Text, $F, [int]$W)
  foreach ($wd in ($Text -split '\s+')) { if ($wd) { $ww = & $ui.WordW $wd $F; if ($ww -gt $W + 1) { return ('LAYOUT ' + $Card + ' ' + $Name + ' text: the word "' + $(if ($wd -match '[\\/]') { '<a path>' } elseif ($wd.Length -gt 20) { $wd.Substring(0, 20) + '...' } else { $wd }) + '" needs ' + $ww + ', the line is ' + $W) } } }
  return $null }
# ---- Drawing and measuring
$ui.Word = { param($G, [string]$Text, $Font, $Color, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Flags) [System.Windows.Forms.TextRenderer]::DrawText($G, $Text, $Font, (New-Object System.Drawing.Rectangle($X, $Y, [math]::Max(1, $W), $H)), $Color, [System.Windows.Forms.TextFormatFlags]$Flags) }
# The size of a text that wraps at a width (the real font; docs/window-design.md "Text lengths").
$ui.Meas = { param([string]$Text, $Font, [int]$W) [System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font, (New-Object System.Drawing.Size([math]::Max(1, $W), 0)), [System.Windows.Forms.TextFormatFlags]'WordBreak, NoPrefix, TextBoxControl') }
# ---- The layout self-check
# ---- The layout self-check (docs/window-design.md "Proof"): in a test round, and in the Windows job, RADE measures each
# card it showed: a text that needs more room than its control has, a control that a parent cuts, two parts that
# overlap. The result is one line under "Window: OK" in the results e-mail draft ("PASS layout" or the defects), so a
# cut text is found by a measure, not by a person's eye. A deploy does not run it. It reads sizes only.
$ui.LayOn = $false; $ui.LayBad = New-Object System.Collections.Generic.List[string]; $ui.LaySeen = @{}; $ui.LayCards = @{}; $ui.LayScroll = @{}
try { $ui.LayOn = [bool]([System.Windows.Forms.Application].GetMethod('SetCompatibleTextRenderingDefault') -and ($env:RADE_LAYOUT -eq '1' -or @($apps | Where-Object { [string]$_.Mode -ne 'deploy' }).Count)) } catch { $null = $_ }   # the real Windows Forms only: the test stand-ins have no layout
$ui.NameOf = { param($C)
  foreach ($k in @($ui.Keys)) { if ([object]::ReferenceEquals($ui[$k], $C)) { return [string]$k } }
  foreach ($k in 'B', 'P') { for ($i = 0; $ui[$k] -and $i -lt @($ui[$k]).Count; $i++) { if ([object]::ReferenceEquals($ui[$k][$i], $C)) { return ($k + $i) } } }
  return $C.GetType().Name }
# ---- The alignment rules
# The alignment rules (docs/window-design.md "Sizes"), on measured numbers so the tests can give them a layout:
# RowBad: the parts of an aligned row (@{ N; Top; H; Kind }) share one midpoint within 1 px, and a box and a button in
# it are as tall as each other. EdgeBad: the visible left edges of a card's parts (@{ N; X }) are within 1 px.
$ui.RowBad = { param([string]$Card, [string]$Row, $Parts)
  # A row that wraps (the test extras in a small window) has a midpoint on each line: Line = the top of a part's margin box.
  $out = @(); $byLine = [ordered]@{}; foreach ($q in @($Parts | Where-Object { $_ })) { $k = [string][int]$q.Line; if (-not $byLine.Contains($k)) { $byLine[$k] = @() }; $byLine[$k] += $q }
  if ($byLine.Count -gt 1) { foreach ($k in @($byLine.Keys)) { $out += & $ui.RowBad $Card $Row @($byLine[$k] | ForEach-Object { $c = $_.Clone(); $c.Line = 0; $c }) }; return $out }
  $tol = [math]::Max(1, (& $ui.Sc 1)); $ps = @($Parts | Where-Object { $_ }); if ($ps.Count -lt 2) { return $out }
  $m0 = $ps[0].Top + $ps[0].H / 2.0
  foreach ($q in $ps) { $m = $q.Top + $q.H / 2.0; if ([math]::Abs($m - $m0) -gt $tol) { $out += ('LAYOUT ' + $Card + ' ' + $Row + ' ' + $q.N + ' midpoint: ' + $m + ', the row midpoint is ' + $m0) } }
  $bx = @($ps | Where-Object { $_.Kind -eq 'box' }); $bt = @($ps | Where-Object { $_.Kind -eq 'button' })
  foreach ($a in $bx) { foreach ($b in $bt) { if ([math]::Abs($a.H - $b.H) -gt $tol) { $out += ('LAYOUT ' + $Card + ' ' + $Row + ' heights: box ' + $a.N + ' ' + $a.H + ', button ' + $b.N + ' ' + $b.H) } } }
  return $out }
$ui.EdgeBad = { param([string]$Card, $Edges)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1)); $es = @($Edges | Where-Object { $_ }); if ($es.Count -lt 2) { return $out }
  foreach ($e in $es) { if ([math]::Abs($e.X - $es[0].X) -gt $tol) { $out += ('LAYOUT ' + $Card + ' ' + $e.N + ' edge: starts at ' + $e.X + ', the card edge is ' + $es[0].X + ' (' + $es[0].N + ')' + $(if ($e.D) { ' [' + $e.D + ']' } else { '' })) } }
  return $out }
# HeadBad (R29b V1): the ink of the word RADE and of the line under it (@{ N; X }) start at the same x; any difference is a defect.
$ui.HeadBad = { param([string]$Card, $Title, $Sub)
  if ([int]$Title.X -eq [int]$Sub.X) { return @() }
  return @('LAYOUT ' + $Card + ' header ' + $Sub.N + ' edge: starts at ' + $Sub.X + ', ' + $Title.N + ' starts at ' + $Title.X) }
# HeadRuleBad (L2, the Administrator, 2026-11-19; it replaces the 4 px box gap of R29b V1): without an application logo,
# under the word RADE comes a gap, a thin line as wide as the word's ink and on its left edge, the same gap, then the
# capitals of the application name. Takes the card, the measured numbers @{ WordBottom; WordLeft; WordW; RuleTop;
# RuleBottom; RuleLeft; RuleW; AppTop } (AppTop $null: a name with no capital, digit or tall letter is not measured) and
# the gap it must be (4 px, scaled); the tolerance is 1 px, scaled. Gives back the defect lines.
$ui.HeadRuleBad = { param([string]$Card, $M, [int]$Want)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1))
  $g1 = [int]$M.RuleTop - [int]$M.WordBottom; if ([math]::Abs($g1 - $Want) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header gap: ' + $g1 + ' between the word RADE and the line, the gap is ' + $Want) }
  if ($null -ne $M.AppTop) { $g2 = [int]$M.AppTop - [int]$M.RuleBottom; if ([math]::Abs($g2 - $Want) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header gap: ' + $g2 + ' between the line and the application name, the gap is ' + $Want) } }
  if ([math]::Abs([int]$M.RuleW - [int]$M.WordW) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header line: ' + $M.RuleW + ' wide, the word RADE is ' + $M.WordW) }
  if ([math]::Abs([int]$M.RuleLeft - [int]$M.WordLeft) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header line: starts at ' + $M.RuleLeft + ', the word RADE starts at ' + $M.WordLeft) }
  return $out }
# AboveBad (L3, the Administrator, 2026-11-19): a label above its box. The label's bottom is not under the box's top, the
# box starts on the card's edge and it is as wide as the card's text (from the edge to the end of the text column), each
# within 1 px (scaled). Takes the card and @{ LabelBottom; BoxTop; BoxLeft; BoxW; Edge; TextW }; gives back the defect lines.
$ui.AboveBad = { param([string]$Card, $M)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1))
  if ([int]$M.BoxTop -lt [int]$M.LabelBottom) { $out += ('LAYOUT ' + $Card + ' FieldRow label: its bottom is at ' + $M.LabelBottom + ', the box starts at ' + $M.BoxTop) }
  if ([math]::Abs([int]$M.BoxLeft - [int]$M.Edge) -gt $tol) { $out += ('LAYOUT ' + $Card + ' FieldBox edge: starts at ' + $M.BoxLeft + ', the card edge is ' + $M.Edge) }
  if ([math]::Abs([int]$M.BoxW - [int]$M.TextW) -gt $tol) { $out += ('LAYOUT ' + $Card + ' FieldBox width: ' + $M.BoxW + ', the card text is ' + $M.TextW + ' wide') }
  return $out }
# FrameBad (L1, the Administrator, 2026-11-19): the card frame. The header row starts at the frame's fixed top (so it is at
# the same place on every card of one window size), and the frame is as tall as its minimum at least, each within 1 px
# (scaled). A card that had to move up to fit (Moved) is not measured. Takes the card and @{ Top; WantTop; H; MinH; Moved };
# gives back the defect lines.
$ui.FrameBad = { param([string]$Card, $M)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1)); if ($M.Moved) { return $out }
  if ([math]::Abs([int]$M.Top - [int]$M.WantTop) -gt $tol) { $out += ('LAYOUT ' + $Card + ' frame: the header row is at ' + $M.Top + ', the fixed top is ' + $M.WantTop) }
  if ([int]$M.H + $tol -lt [int]$M.MinH) { $out += ('LAYOUT ' + $Card + ' frame: ' + $M.H + ' high, the minimum is ' + $M.MinH) }
  return $out }
# TickBad (R29b N3): the step's time or count (@{ N; Top; H }) has its vertical center within 1 px of the bar's (@{ Top; H }),
# at any scale (the tolerance is not scaled).
$ui.TickBad = { param([string]$Card, $Bar, $Tick)
  $mb = $Bar.Top + $Bar.H / 2.0; $mt = $Tick.Top + $Tick.H / 2.0
  if ([math]::Abs($mt - $mb) -le 1) { return @() }
  return @('LAYOUT ' + $Card + ' StepRow ' + $Tick.N + ' midpoint: ' + $mt + ', the bar midpoint is ' + $mb) }
# ---- The self-check walk
$ui.IsCardText = { param($C) return [bool](($C -is [System.Windows.Forms.TextBox]) -and $C.ReadOnly -and -not $C.TabStop -and $ui.Wrap.ContainsKey($C)) }
# What a card text box needs, as its edit control wraps the text now (the line count it reports), else as measured.
$ui.TextNeed = { param($C)
  $w = [int](& $ui.GetWrap $C); $s = & $ui.Meas ([string]$C.Text) $C.Font $(if ($w -gt 0) { $w } else { 100000 }); $h = [int]$s.Height + (& $ui.Sc 2)
  try { $n = [int]$C.GetLineFromCharIndex([math]::Max(0, $C.Text.Length - 1)) + 1; $lh = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $C.Font).Height; if ($n -gt 0 -and $lh -gt 0) { $h = [math]::Max($h, $n * $lh) } } catch { $null = $_ }
  return (New-Object System.Drawing.Size($s.Width, $h)) }
$ui.Check = {
  if (-not $ui.LayOn -or -not $ui.View) { return }
  if ($ui.Picked -and (Test-Deploy) -and $env:RADE_LAYOUT -ne '1') { return }   # a deploy does not run it, also when the paste has a test application
  $card = $(if ($ui.RecOn) { 'record' } else { [string]$ui.View })
  try {
    if (-not $ui.Form.Visible -or [string]$ui.Form.WindowState -eq 'Minimized') { return }
    # One check for each card at each window size (R28: the check runs again after a resize).
    $key = $card + '|' + $ui.View + '|' + $ui.Sent.Text + '|' + $ui.Kick.Text; $ui.LayCards[$key] = 1
    $key += '|' + $ui.Form.ClientSize.Width + 'x' + $ui.Form.ClientSize.Height; if ($ui.LaySeen.ContainsKey($key)) { return }; $ui.LaySeen[$key] = 1
    if ($ui.Scrolls -and -not $ui.RecOn) { $ui.LayScroll[$card] = 1 }
    $todo = New-Object System.Collections.Stack; $todo.Push(@($ui.Form, $ui.Form.RectangleToScreen($ui.Form.ClientRectangle), $false))
    while ($todo.Count) {
      $it = $todo.Pop(); $par = $it[0]; $clip = $it[1]; $scroll = $it[2]
      $kids = @($par.Controls | Where-Object { $_.Visible })
      for ($i = 0; $i -lt $kids.Count; $i++) {
        $c = $kids[$i]; $r = $c.RectangleToScreen($c.ClientRectangle); if ($r.Width -le 0 -or $r.Height -le 0) { continue }
        if (-not $scroll -and -not $clip.Contains($r)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' cut: needs ' + $r.Width + 'x' + $r.Height + ' at ' + ($r.Left - $clip.Left) + ',' + ($r.Top - $clip.Top) + ' in ' + $clip.Width + 'x' + $clip.Height) }
        if ($c -is [System.Windows.Forms.Label] -and $c.AutoSize -and $c.MaximumSize.Width -gt 0 -and $c.Text) { $wb = & $ui.WordBad $card (& $ui.NameOf $c) ([string]$c.Text) $c.Font $c.MaximumSize.Width; if ($wb) { $ui.LayBad.Add($wb) } }
        if (& $ui.IsCardText $c) {   # card text boxes are measured as labels are: a word wider than the line, and text that needs more room than the box has
          if ([int](& $ui.GetWrap $c) -gt 0 -and $c.Text) { $wb = & $ui.WordBad $card (& $ui.NameOf $c) ([string]$c.Text) $c.Font ([int](& $ui.GetWrap $c)); if ($wb) { $ui.LayBad.Add($wb) } }
          $nd = & $ui.TextNeed $c; if ($c.Text -and ($nd.Height -gt $c.ClientSize.Height + 1 -or $nd.Width -gt $c.ClientSize.Width + 1)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text: needs ' + $nd.Width + 'x' + $nd.Height + ' has ' + $c.ClientSize.Width + 'x' + $c.ClientSize.Height) }
          $lh1 = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $c.Font).Height; if ($c.Text -and -not $ui.Hold.ContainsKey($c) -and $c.ClientSize.Height -gt $nd.Height + $lh1) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' dead space: has ' + $c.ClientSize.Height + ' high, the text needs ' + $nd.Height) } }   # more than one empty line under its text (a box with fixed lines keeps its room)
        if ($c -is [System.Windows.Forms.CheckBox] -and $c.Text -and -not $c.AutoEllipsis) {   # a one-line check box whose text alone is wider than it is cut (the Record's step boxes before R24 fix round 3)
          $tw = [System.Windows.Forms.TextRenderer]::MeasureText([string]$c.Text, $c.Font).Width; if ($tw -gt $c.ClientSize.Width + 1) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text cut: needs ' + $tw + ' has ' + $c.ClientSize.Width) } }
        # A cut line (R28 N9: the run card's status line was cut through its middle): a control with text is at least one line of its
        # font tall, also a label that ends with "..." by rule. A rich text box (the lines of a hand step) is as tall as its text.
        if ($c.Text -and ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.ButtonBase] -or $c -is [System.Windows.Forms.TextBoxBase])) {
          $lh = [int](& $ui.LineH $c.Font); if ($c -is [System.Windows.Forms.TextBoxBase]) { $lh = [int][math]::Floor($lh * 0.8) }   # an edit control draws a line with less padding
          if ($c.ClientSize.Height + 1 -lt $lh) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' line cut: one line needs ' + $lh + ' high, has ' + $c.ClientSize.Height) } }
        if ($c -is [System.Windows.Forms.RichTextBox] -and $ui.GuideNeed -and [object]::ReferenceEquals($c, $ui.Guide)) { $gn = [int](& $ui.GuideNeed); if ($gn -gt $c.ClientSize.Height + 1) { $ui.LayBad.Add('LAYOUT ' + $card + ' Guide text: needs ' + $gn + ' high, has ' + $c.ClientSize.Height) } }
        $isText = ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.ButtonBase])
        if ($isText -and $c.Text -and -not $c.AutoEllipsis) {   # a label or box that ends with "..." by rule is not a defect
          $want = $c.GetPreferredSize((New-Object System.Drawing.Size($c.Width, 0)))
          if ($want.Width -gt $c.Width + 1 -or $want.Height -gt $c.Height + 1) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text: needs ' + $want.Width + 'x' + $want.Height + ' has ' + $c.Width + 'x' + $c.Height) }
        }
        for ($j = $i + 1; $j -lt $kids.Count; $j++) { if ($c.Bounds.IntersectsWith($kids[$j].Bounds)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' overlaps ' + (& $ui.NameOf $kids[$j])) } }
        $sc2 = [bool]$c.AutoScroll; if ([object]::ReferenceEquals($c, $ui.Scroll)) { $sc2 = [bool]$ui.Scrolls }   # the card's text scrolls only when $ui.Squeeze says so
        if ($c.Controls.Count) { $todo.Push(@($c, [System.Drawing.Rectangle]::Intersect($clip, $r), ($scroll -or $sc2))) }
      }
    }
    # Dead space (R28 N9: a large empty area under the run card's text): the card's text panel is as tall as its text when it does not scroll.
    if ($ui.Scroll -and $ui.Body -and -not $ui.RecOn -and -not $ui.Scrolls -and $ui.Scroll.Visible) { $dead = [int]$ui.Scroll.ClientSize.Height - [int]$ui.Body.Height; if ($dead -gt (& $ui.Sc 2)) { $ui.LayBad.Add('LAYOUT ' + $card + ' Scroll dead space: ' + $dead + ' px under the text') } }
    foreach ($l in @(& $ui.Measure $card)) { $ui.LayBad.Add([string]$l) }
  } catch { $ui.LayBad.Add('LAYOUT ' + $card + ' the self-check stopped: ' + (ConvertTo-Masked ([string]$_.Exception.Message))) } }
# <<< rade-ui-2
# ---- High contrast (R31 W2; R30b check 10: the window kept its own colors when a contrast theme came on)
# With Windows high contrast on, the window paints with the system colors of the theme instead of its own palette.
# The role of each color: backgrounds become Window, text and lines WindowText, muted text GrayText, the action
# Highlight, a button that is not available ButtonFace. The rail turns round: navy (its background) becomes WindowText
# and its light text Window, so it stays readable. One table serves $pc and $ui.C: a hashtable key ignores case, and
# each name the two share (navy, ink, track, white) has one role in both. Yellow fills become Window: dark text on the
# theme's Highlight color can be hard to read.
$ui.HcRole = @{ ink = 'WindowText'; muted = 'GrayText'; surface = 'Window'; line = 'WindowText'; navy = 'WindowText'; onPrimaryMuted = 'Window'
  accentFill = 'Window'; primary = 'Highlight'; track = 'GrayText'; redTint = 'Window'; amberTint = 'Window'; greenTint = 'Window'; white = 'Window'
  blue = 'Highlight'; yellow = 'Window'; green = 'WindowText'; greenInk = 'WindowText'; red = 'WindowText'; gray = 'GrayText'; edge = 'WindowText'
  hair = 'GrayText'; off = 'ButtonFace'; offInk = 'GrayText' }
function Select-T22Color([bool]$High, [hashtable]$Own, [hashtable]$Role) {
  # The colors to paint with: a new table with the keys of $Own. $High false: the colors of $Own. $High true: for each
  # key the system color its role names in $Role (a key with no role gets WindowText, so no text is lost). $Own is not
  # changed. The measure part checks this choice without switching the Windows theme (tests/ps/Test-T22Layout.ps1).
  $out = @{}
  foreach ($k in @($Own.Keys)) {
    if ($High) { $r = [string]$Role[$k]; if (-not $r) { $r = 'WindowText' }; $out[$k] = [System.Drawing.SystemColors]::$r }
    else { $out[$k] = $Own[$k] } }
  return $out
}
# The window's own colors, kept before any change, and whether the system colors are in use.
$ui.OwnPc = $pc.Clone(); $ui.OwnC = $ui.C.Clone(); $ui.High = $false
# Puts the colors for $High into $pc and $ui.C in place (every builder and every paint handler reads them there).
$ui.UseColors = { param([bool]$High)
  $a = Select-T22Color $High $ui.OwnPc $ui.HcRole; foreach ($k in @($a.Keys)) { $pc[$k] = $a[$k] }
  $b = Select-T22Color $High $ui.OwnC $ui.HcRole; foreach ($k in @($b.Keys)) { $ui.C[$k] = $b[$k] }
  $ui.High = $High }
