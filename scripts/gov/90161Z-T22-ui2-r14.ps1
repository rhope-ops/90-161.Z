<#
.SYNOPSIS
  90-161.Z Task 22 r14, part "ui2": the second half of the RADE shared UI file, generated into this file, and the colors
  for Windows high contrast.
.DESCRIPTION
  R11 (R38; PFM 20 Nov 26): new part. engine-v29's shared UI file (599 lines) is split in 2 so each part stays under the
  600-line file cap (code standard C4); scripts/build_task_scripts.py writes the block between the rade-ui-2 markers from
  the pinned RADE commit (scripts/rade.lock.json); never edit it here. It runs right after part "ui", inside the main
  script's try block. The lines after the block choose the colors for Windows high contrast (R31 W2): Select-T22Color
  and $ui.UseColors (the window part applies them: $wn.Recolor).
  Inputs: $ui (filled by part "ui"), $pc. Outputs: the $ui members of the second half of the shared UI file, $ui.HcRole,
  $ui.OwnPc, $ui.OwnC, $ui.High, $ui.UseColors and the function Select-T22Color.
  Run: not alone; 90161Z-T22-pfm-window-r14.ps1 dot-sources it from its own folder.
  Network: none.
  Writes: none.
  Credentials: none.
#>
$apps = @(@{ Mode = 'test' })   # one test application, so the layout self-check of the shared UI file runs
# >>> rade-ui-2: generated from the pinned RADE shared UI file (second half) by scripts/build_task_scripts.py (do not edit)
$ui.Own = { param($B) $B.UseVisualStyleBackColor = $false; $B.Add_Paint({ & $ui.Face $this $_.Graphics })
  $B.Add_MouseEnter({ $ui.Hot = $this; $this.Invalidate() }); $B.Add_MouseLeave({ if ([object]::ReferenceEquals($ui.Hot, $this)) { $ui.Hot = $null }; $this.Invalidate() })
  $B.Add_MouseDown({ if ([string]$_.Button -eq 'Left') { $ui.Down = $this; $this.Invalidate() } }); $B.Add_MouseUp({ $ui.Down = $null; $this.Invalidate() })
  $B.Add_VisibleChanged({ if ([object]::ReferenceEquals($ui.Hot, $this)) { $ui.Hot = $null }; if ([object]::ReferenceEquals($ui.Down, $this)) { $ui.Down = $null } }) }
# Buttons have fixed sizes (UI standard v1, B1; the Administrator, 2026-11-20): no AutoSize, so a button never grows or
# shrinks with its text. $Kind: 'action' (a card's buttons: 160 x 40, or 240 x 40 when its label needs more room) or
# 'compact' (96 x 30: beside a box, "Back (Esc)", the Record's buttons; 160 x 30 when its label needs more room). A label
# that needs more than the widest size is cut, and the self-check reports it (rule B1). Sizes: $ui.Z.
$ui.BtnKind = @{}
# The size of a button of a kind for its text: at 100 % before the window has its scale (Windows Forms scales it), else scaled.
$ui.BtnSize = { param($B)
  $k = [string]$ui.BtnKind[$B]; $s = $(if ($ui.Scaled) { $ui.Sc } else { { param([double]$Px) [int]$Px } })
  $h = $(if ($k -eq 'compact') { $ui.Z.CompactH } else { $ui.Z.ActionH }); $ws = $(if ($k -eq 'compact') { @($ui.Z.CompactW, $ui.Z.ActionW) } else { @($ui.Z.ActionW, $ui.Z.WideW) })
  $need = 0; try { if ($B.Text) { $need = [int][System.Windows.Forms.TextRenderer]::MeasureText([string]$B.Text, $B.Font).Width + (& $ui.Sc (2 * $ui.Z.G2)) } } catch { $null = $_ }   # no measure: the first width
  $w = $(if ($need -le (& $ui.Sc $ws[0])) { $ws[0] } else { $ws[1] })
  return (New-Object System.Drawing.Size((& $s $w), (& $s $h))) }
# Gives a button the size of its kind for its text ($ui.BtnSize). Takes the button.
$ui.FitBtn = { param($B) try { $ns = & $ui.BtnSize $B; if ($B.Width -ne $ns.Width -or $B.Height -ne $ns.Height) { $B.Size = $ns } } catch { $null = $_ } }   # no size now: the next text sets it
$ui.AutoNames = @{}   # the name $ui.AutoName gave each button
# AccessibleName on every control (docs/window-design.md; fleet v2): a button whose name nobody set takes its text and
# follows it when the text changes; a name set by hand stays. Takes the button; gives back nothing.
$ui.AutoName = { param($B) if (-not [string]$B.AccessibleName -or [string]$ui.AutoNames[$B] -eq [string]$B.AccessibleName) {
    $B.AccessibleName = [string]$B.Text; $ui.AutoNames[$B] = [string]$B.Text } }
# Makes a button of a kind ('action' or 'compact'), styled, with its focus ring and own face. Takes the kind; gives back the button.
$ui.Btn = { param([string]$Kind) $b = New-Object System.Windows.Forms.Button; $b.AutoSize = $false; $ui.BtnKind[$b] = $(if ($Kind -eq 'compact') { 'compact' } else { 'action' })
  $b.Padding = (& $ui.Pad $ui.Z.G2 0 $ui.Z.G2 0); $b.Margin = (& $ui.Pad $ui.Z.M $ui.Z.M $ui.Z.M $ui.Z.M); $b.UseMnemonic = $false; & $ui.Style $b ''; & $ui.Cue $b; & $ui.Own $b
  & $ui.FitBtn $b; $b.Add_TextChanged({ & $ui.FitBtn $this; & $ui.AutoName $this }); $b }   # gives back the button
$ui.LinkBtn = { param([string]$Text) $b = New-Object System.Windows.Forms.Button; $b.Text = $Text; $b.AutoSize = $true; $b.AutoSizeMode = 'GrowAndShrink'; $b.MinimumSize = New-Object System.Drawing.Size(0, $ui.Z.LinkH); $b.Margin = (& $ui.Pad $ui.Z.M $ui.Z.M $ui.Z.M $ui.Z.M); $b.UseMnemonic = $false
  $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0; $b.BackColor = $ui.C.White; $b.ForeColor = $ui.C.Link; $b.Font = $ui.F.Link; $ui.Links += $b; try { $b.FlatAppearance.MouseOverBackColor = $ui.C.White; $b.FlatAppearance.MouseDownBackColor = $ui.C.Hair } catch { $null = $_ }; & $ui.Cue $b; & $ui.Own $b   # no hover colors: the link still works
  & $ui.AutoName $b; $b.Add_TextChanged({ & $ui.AutoName $this }); $b }   # a link: Air Force blue, semibold and underlined (not color alone), 28 high
$ui.Kinds = @{}; $ui.Links = @()   # the kind each button was last styled with; every link ($ui.Recolor styles them again)
# ---- A contrast theme that changes while the window is open (UI standard v1, B11; backlog item 24)
# The form's SystemColorsChanged event (Windows sends WM_SYSCOLORCHANGE when a contrast theme comes on or goes off) calls
# $ui.Recolor on the window's own thread: PowerShell code cannot run on the thread of SystemEvents, and the event goes with
# the form when it closes, so nothing is left to detach. $ui.Roles keeps, for each control and color property, the token
# it was painted with (found from the colors it had), so a switch back gives each part its own color again.
$ui.Roles = @{}; $ui.Recolor = {
  <#
  .SYNOPSIS
  Paints the window again in the colors of the current Windows theme (its own colors, or a contrast theme's system colors).
  .DESCRIPTION
  Does nothing when the theme did not change, unless Force is set. Each property gets the color of its token (see above).
  .PARAMETER Force
  $true to paint again also when the theme did not change.
  .OUTPUTS
  Nothing.
  #>
  param([bool]$Force)
  $hi = [bool](& $ui.HighOn); if ($hi -eq [bool]$ui.High -and -not $Force) { return }
  try { $rev = @{}; foreach ($k in @($ui.Tok.Keys)) { $a = $ui.C[$k].ToArgb(); if (-not $rev.ContainsKey($a)) { $rev[$a] = $k } }   # the colors before the change: color -> token
    $todo = New-Object System.Collections.Stack; $todo.Push($ui.Form); $all = @()
    while ($todo.Count) { $c = $todo.Pop(); $all += $c; foreach ($k in @($c.Controls)) { $todo.Push($k) } }
    foreach ($c in $all) { if (-not $ui.Roles.ContainsKey($c)) { $ui.Roles[$c] = @{} }; $r = $ui.Roles[$c]
      foreach ($pp in 'ForeColor', 'BackColor') { try { $a = $c.$pp.ToArgb(); $t0 = [string]$r[$pp]   # the token it had keeps its place while its color is still on the control
          if (-not ($t0 -and $ui.C[$t0].ToArgb() -eq $a)) { $t = $rev[$a]; if ($t) { $r[$pp] = $t } } } catch { $null = $_ } } }   # a color that is no token stays as it is
    & $ui.UseColors $hi
    foreach ($c in $all) { $r = $ui.Roles[$c]; foreach ($pp in @($r.Keys)) { try { $c.$pp = $ui.C[[string]$r[$pp]] } catch { $null = $_ } } }   # a property that cannot be set keeps its color
    foreach ($b in @($ui.Kinds.Keys)) { try { $en = $b.Enabled; & $ui.Style $b ([string]$ui.Kinds[$b]); if ([string]$ui.Kinds[$b] -notin 'off', 'dangeroff') { $b.Enabled = $en } } catch { $null = $_ } }   # a button that is gone: nothing to paint
    foreach ($b in @($ui.Links)) { try { $b.BackColor = $ui.C.White; $b.ForeColor = $ui.C.Link; $b.FlatAppearance.MouseOverBackColor = $ui.C.White; $b.FlatAppearance.MouseDownBackColor = $ui.C.Hair } catch { $null = $_ } }   # same: a link that is gone
    if ($ui.CardNow -and -not $ui.RecOn -and -not $ui.Busy -and -not $ui.Running) { $k = @([string]$ui.Field.Text, [string]$ui.ErrBox.Text, [string]$ui.Note.Text); $on = $ui.LayOn; $ui.LayOn = $false
      try { & $ui.SetCard $ui.CardNow } finally { $ui.LayOn = $on }; $ui.Field.Text = $k[0]; $ui.ErrBox.Text = $k[1]; & $ui.Say1 $k[2] }; $ui.Form.Invalidate($true) } catch { $null = $_ } }   # the card's own colors, typed text kept; never stops the window
# Where ink starts, ink-tight text, long words, shortened text, drawing and measuring ($ui.Ink to $ui.Meas): engine/rade_ui_text.ps1.
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
# ---- UI standard v1 rules of the self-check (the Administrator, 2026-11-20; docs/ui-standard.md, each rule's check)
# The WCAG relative luminance of a color (0 to 1). Takes the color; gives back a number.
$ui.Lum = { param($C) $v = foreach ($x in @($C.R, $C.G, $C.B)) { $f = [double]$x / 255.0; if ($f -le 0.04045) { $f / 12.92 } else { [math]::Pow(($f + 0.055) / 1.055, 2.4) } }; 0.2126 * $v[0] + 0.7152 * $v[1] + 0.0722 * $v[2] }
# The WCAG contrast ratio of two colors (1 to 21). Takes the two colors; gives back a number.
$ui.Ratio = { param($A, $B) $x = & $ui.Lum $A; $y = & $ui.Lum $B; ([math]::Max($x, $y) + 0.05) / ([math]::Min($x, $y) + 0.05) }
# B1 (fixed sizes) for one button with an edge: no AutoSize, a size of the set, and a label that fits. Takes the card,
# the button's name and the button; gives back the defect lines.
$ui.BtnBad = { param([string]$Card, [string]$Name, $B)
  $out = @(); $ws = @($ui.Z.CompactW, $ui.Z.ActionW, $ui.Z.WideW | ForEach-Object { & $ui.Sc $_ }); $hs = @($ui.Z.CompactH, $ui.Z.ActionH | ForEach-Object { & $ui.Sc $_ })
  if ($B.AutoSize) { $out += ('LAYOUT ' + $Card + ' ' + $Name + ' button: AutoSize is on (B1: fixed sizes)') }
  if ($ws -notcontains [int]$B.Width -or $hs -notcontains [int]$B.Height) { $out += ('LAYOUT ' + $Card + ' ' + $Name + ' button: ' + $B.Width + 'x' + $B.Height + ' is not a size of the set (B1)') }
  $need = [int][System.Windows.Forms.TextRenderer]::MeasureText([string]$B.Text, $B.Font).Width + (& $ui.Sc 4)
  if ($B.Text -and $need -gt [int]$B.Width) { $out += ('LAYOUT ' + $Card + ' ' + $Name + ' button text cut: needs ' + $need + ' has ' + $B.Width + ' (B1)') }
  return $out }
# B3, B4, B5 for the card's action row: at most one primary button, and it is the last one; at most 3 others ("Back (Esc)"
# is the Back pattern, not counted). Takes the card and the kinds of the shown buttons in row order; gives back the lines.
$ui.RowRuleBad = { param([string]$Card, $Kinds)
  $out = @(); $ks = @($Kinds); $main = @(for ($k = 0; $k -lt $ks.Count; $k++) { if ([string]$ks[$k] -eq 'primary') { $k } })
  if ($main.Count -gt 1) { $out += ('LAYOUT ' + $Card + ' buttons: ' + $main.Count + ' primary buttons, the rule is one (B4)') }
  if ($main.Count -eq 1 -and $main[0] -ne $ks.Count - 1) { $out += ('LAYOUT ' + $Card + ' buttons: the primary button is number ' + ($main[0] + 1) + ' of ' + $ks.Count + ', the rule is last (B3)') }
  if ($ks.Count - $main.Count -gt 3) { $out += ('LAYOUT ' + $Card + ' buttons: ' + ($ks.Count - $main.Count) + ' buttons beside the primary, the rule is 3 at most (B5)') }
  return $out }
# Inventory (RADE_INVENTORY = a file path; the Windows job): one JSON line for each control the self-check walks, with
# the card, the scale, the kind, the screen box, the colors and the accessible name (docs/ui-standard.md "Proof").
$ui.InvFile = [string]$env:RADE_INVENTORY
# Writes the inventory line of one control. Takes the card, the control and its screen box.
$ui.InvLine = { param([string]$Card, $C, $R)
  try { $o = [ordered]@{ card = $Card; scale = [int][math]::Round($ui.Dpi / 96.0 * 100); high = [bool]$ui.High; kind = $C.GetType().Name; name = (& $ui.NameOf $C)
      x = [int]$R.Left; y = [int]$R.Top; w = [int]$R.Width; h = [int]$R.Height; fore = '#{0:X6}' -f ($C.ForeColor.ToArgb() -band 0xFFFFFF); back = '#{0:X6}' -f ($C.BackColor.ToArgb() -band 0xFFFFFF)
      access = [string]$C.AccessibleName; button = [string]$ui.Kinds[$C] }
    Add-Content -LiteralPath $ui.InvFile -Value (ConvertTo-Json $o -Compress) -Encoding UTF8 -ErrorAction Stop } catch { $null = $_ } }   # the inventory is a test aid: never stop the check
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
        if ($ui.InvFile) { & $ui.InvLine $card $c $r }
        if ($c.CanSelect -and $c.TabStop -and -not [string]$c.AccessibleName) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ': no accessible name') }
        if ($ui.Boxes -contains $c -and [int]$c.Height + 1 -lt (& $ui.Sc $ui.Z.CompactH)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' box: ' + $c.Height + ' high, the rule is ' + (& $ui.Sc $ui.Z.CompactH) + ' (B1; R36: a frame that did not scale cut its line at 150 %)') }
        if ($c -is [System.Windows.Forms.Button] -and [int]$c.FlatAppearance.BorderSize -gt 0 -and $ui.BtnKind.ContainsKey($c)) { foreach ($l in @(& $ui.BtnBad $card (& $ui.NameOf $c) $c)) { $ui.LayBad.Add([string]$l) } }
        if ($c.Text -and $c.Enabled -and ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.ButtonBase] -or (& $ui.IsCardText $c))) {   # B10: text at least 4.5:1 on its own background
          $cr = & $ui.Ratio $c.ForeColor $c.BackColor; if ($cr -lt 4.5) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' contrast: ' + [math]::Round($cr, 2) + ':1, the rule is 4.5:1 (B10)') } }
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
        if ($isText -and $c.Text -and -not $c.AutoEllipsis -and -not $ui.BtnKind.ContainsKey($c)) {   # a label or box that ends with "..." by rule is not a defect; a button of fixed size: B1
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
    if (-not $ui.RecOn) { foreach ($l in @(& $ui.RowRuleBad $card @($ui.B | Where-Object { $_.Visible } | ForEach-Object { [string]$ui.Kinds[$_] }))) { $ui.LayBad.Add([string]$l) } }
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
# R11 (engine-v29: new tokens Face, FaceInk, OnBlue, Link, Focus): each RADE token this table does not name takes the
# system color RADE gives its role ($ui.Tok, 4th value), so no button loses its label with high contrast on.
foreach ($k in @($ui.Tok.Keys)) { if (-not $ui.HcRole.ContainsKey($k)) { $ui.HcRole[$k] = [string]$ui.Tok[$k][3] } }
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
# R11 (engine-v29 fills $ui.C with system colors when the window opens with high contrast on): the own colors of the
# RADE tokens come from $ui.Tok, never from the live $ui.C.
$ui.OwnPc = $pc.Clone(); $ui.OwnC = $ui.C.Clone(); $ui.High = $false
foreach ($k in @($ui.Tok.Keys)) { $t = $ui.Tok[$k]; $ui.OwnC[$k] = [System.Drawing.Color]::FromArgb([int]$t[0], [int]$t[1], [int]$t[2]) }
# Puts the colors for $High into $pc and $ui.C in place (every builder and every paint handler reads them there).
$ui.UseColors = { param([bool]$High)
  $a = Select-T22Color $High $ui.OwnPc $ui.HcRole; foreach ($k in @($a.Keys)) { $pc[$k] = $a[$k] }
  $b = Select-T22Color $High $ui.OwnC $ui.HcRole; foreach ($k in @($b.Keys)) { $ui.C[$k] = $b[$k] }
  $ui.High = $High }
