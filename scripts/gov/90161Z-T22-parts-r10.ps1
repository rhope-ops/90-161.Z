<#
.SYNOPSIS
  90-161.Z Task 22 r10, part "parts": the builders of a card's parts (text, buttons, links, chips, panels, the card
  frame) and of each block type of the card data (chips, headline, text, steps, checks, boxes, rows, lists, filter,
  input, choices, error, progress, buttons).
.DESCRIPTION
  Each builder makes Windows Forms controls with the RADE look ($ui, from the ui part) and adds them to a parent.
  R4 (R30 V3): a format check with 0 findings shows no link (Test-CheckLink, in the cards part). The grid block is
  built by the grid part. R6 (R31b D3): the chip of a check block is level with the first line of its text; the
  helpers $wn.LineH, $wn.PageTop and $wn.TextMid give the text middles that the window, the measure part and the
  layout self-check compare (one rule for D1 to D3). R7 (R32 W3): every chip beside text (the check, the list rows of
  "Needs You Today", the rows blocks, the chips row with its step line, the notice) is placed by one rule,
  $wn.ChipTops, and kept in $wn.ChipRows with its text.
  Inputs: $ui, $wn, $pc and the card data. Outputs: the $wn members below; nothing is read or saved.
  Run: not alone; 90161Z-T22-pfm-window-r10.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: none.
  Credentials: none.
#>
# A size at 100 % in screen pixels (the RADE scale).
$wn.Sc = { param([double]$Px) & $ui.Sc $Px }
# The height of one line of text in font $F, in pixels (as a card text box spaces its lines).
$wn.LineH = { param($F) return [int][Windows.Forms.TextRenderer]::MeasureText('Ag', $F).Height }
# The top of control $C in the pixels of the page (the sum of the tops up to the page), from the layout alone: no handle needed.
$wn.PageTop = { param($C) $y = 0; while ($C -and -not [object]::ReferenceEquals($C, $page)) { $y += $C.Top; $C = $C.Parent }; return $y }
# The vertical middle of the first text line of control $C, in page pixels (R6, D1 to D3). A card text box draws its
# first line at its top: top + one line / 2. A chip or a crumb link draws its text in its vertical middle: top + height / 2.
$wn.TextMid = { param($C)
  if ($C -is [Windows.Forms.TextBox]) { return ((& $wn.PageTop $C) + (& $wn.LineH $C.Font) / 2.0) }
  return ((& $wn.PageTop $C) + $C.Height / 2.0) }
$wn.ChipTops = {
  <#
  .SYNOPSIS
  R7 (R32 W3): the one rule for every chip beside text: the chip's middle is the middle of the first text line.
  .DESCRIPTION
  The text keeps its top; the chip's top is the line's middle less half the chip, rounded to a pixel (so the two
  middles differ by half a pixel at most, at any scale). When that top would be above 0 (a chip taller than the
  line, with the text at the top), both move down by the same amount: the chip starts at 0 and the text lower.
  The tops are relative to the same parent top (a panel placed by hand, or the margins of a flow row).
  .PARAMETER ChipH
  The chip's height in pixels.
  .PARAMETER Font
  The font of the text beside the chip ($wn.LineH gives its line height).
  .PARAMETER TextTop
  Where the text would start, in pixels.
  .OUTPUTS
  @{ Chip = the chip's top; Text = the text's top }.
  #>
  param([int]$ChipH, $Font, [int]$TextTop)
  $c = [int][math]::Round($TextTop + (& $wn.LineH $Font) / 2.0 - $ChipH / 2.0); $t = $TextTop
  if ($c -lt 0) { $t = $TextTop - $c; $c = 0 }
  return @{ Chip = $c; Text = $t } }
# Keeps chip $Chip and the text box $Text beside it for the measure part and the layout self-check (R7 W3); $Kind
# names the block (check, list, rows, chips, notice).
$wn.KeepChip = { param($Chip, $Text, [string]$Kind) $wn.ChipRows += @{ Chip = $Chip; Text = $Text; Kind = $Kind } }
# Adds a card text box (selectable, read-only, no tab stop) with its text, font, color, top gap, wrap width and
# accessible name to $Parent; $Back is its background when it is not white. Gives back the box.
$wn.Txt = { param($Parent, [string]$Text, $Font, $Color, [int]$Top, [int]$W, [string]$Name, $Back)
  $t = & $ui.Text $Font $Color (& $wn.Sc $Top) $Name
  if ($Back) { $t.BackColor = $Back }
  $t.Text = $Text; & $ui.SetWrap $t $W; $t.Visible = $true; [void]$Parent.Controls.Add($t); return $t }
# Rounds the corners of a control ($Rad pixels).
$wn.Round = { param($C, [int]$Rad) try { [Pfm.Gfx]::RoundRegion($C, $Rad) } catch { $null = $_ }; return $null }
# A card button: the RADE action or compact button, blue for the main one, white for the others. $B: Text, Kind, Go, Note, Need.
$wn.Button = { param($B, [string]$Kind)
  $x = & $ui.Btn $Kind
  $x.Text = [string]$B.Text; & $ui.Style $x $(if ($B.Kind -eq 'primary') { 'primary' } else { '' }); $x.AccessibleName = [string]$B.Text; $x.Tag = $B
  $x.Add_SizeChanged({ & $wn.Round $this 4 })
  $x.Add_Click({ & $wn.Press $this.Tag })
  return $x }
# A link of a card (the RADE link button). $B: Text, Go, Note.
$wn.Link = { param($B)
  $x = & $ui.LinkBtn ([string]$B.Text); $x.AccessibleName = [string]$B.Text; $x.Tag = $B
  $x.Add_Click({ & $wn.Press $this.Tag })
  return $x }
# The chip colors by kind: your turn, late, due soon, done, warning, neutral. Read again from $pc when the colors change
# (R31 W2, $wn.Recolor in the window part).
$wn.FillsOf = { return @{ turn = $pc.accentFill; late = $pc.redTint; soon = $pc.amberTint; ok = $pc.greenTint; amber = $pc.amberTint; neu = $pc.surface } }
$wn.Fills = & $wn.FillsOf
# A status chip of kind $Kind with $Text, on background $Back. Gives back the chip.
$wn.Chip = { param($Kind, [string]$Text, $Back)
  $c = New-Object Pfm.Chip; $c.Text = $Text; $c.Font = $ui.F.SmallB; $c.ForeColor = $pc.ink; $c.Fill = $wn.Fills[$Kind]; $c.BackColor = $Back; $c.AccessibleName = $Text
  $w = [Windows.Forms.TextRenderer]::MeasureText($Text, $c.Font).Width + (& $wn.Sc 22)
  $c.Size = [Drawing.Size]::new($w, (& $wn.Sc 26)); $c.Margin = & $ui.Pad 0 0 (& $wn.Sc 8) 0
  return $c }
# A white panel $W wide with a top gap; its children are placed by hand and it draws their focus ring.
$wn.Panel = { param([int]$W, [int]$Top)
  $p = New-Object System.Windows.Forms.Panel; $p.BackColor = $ui.C.White; $p.Size = [Drawing.Size]::new($W, 1); $p.Margin = & $ui.Pad 0 (& $wn.Sc $Top) 0 0
  & $ui.Ring $p; return $p }
# Makes a hand-placed panel as tall as its lowest child plus $Pad.
$wn.Fit = { param($P, [int]$Pad)
  $h = 0; foreach ($c in $P.Controls) { if ($c.Bottom -gt $h) { $h = $c.Bottom } }
  $P.Height = $h + (& $wn.Sc $Pad) }
# A 1 px separator line, $W wide, in $Parent.
$wn.Rule = { param($Parent, [int]$W, [int]$Top)
  $r = New-Object System.Windows.Forms.Panel; $r.BackColor = $pc.line; $r.Size = [Drawing.Size]::new($W, 1); $r.Margin = & $ui.Pad 0 (& $wn.Sc $Top) 0 0; $r.AccessibleName = 'Separator line'
  [void]$Parent.Controls.Add($r) }
# A left-to-right flow in $Parent with background $Back; it draws its children's focus ring. Gives back the flow.
$wn.Flow = { param($Parent, $Back)
  $f = & $ui.Flow 0; $f.BackColor = $Back; $f.Visible = $true; & $ui.Ring $f; [void]$Parent.Controls.Add($f); return $f }
$wn.Card = {
  <#
  .SYNOPSIS
  A card frame: a top-down flow with a thin edge, rounded corners and an optional blue top bar and caption.
  .PARAMETER W
  The card width in pixels (its minimum width; it grows in height with its parts).
  .PARAMETER Cap
  The caption in capitals at the top, or nothing.
  .PARAMETER Top
  When set, a 4 px blue bar at the top (the card that holds the main task).
  .PARAMETER PadX
  The space left and right inside the card, at 100 %.
  .PARAMETER Back
  The color around the rounded corners (the page behind the card).
  .OUTPUTS
  The card (Pfm.Card).
  #>
  param([int]$W, $Cap, $Top, [int]$PadX, $Back)
  $c = New-Object Pfm.Card; $c.FlowDirection = 'TopDown'; $c.WrapContents = $false; $c.AutoSize = $true; $c.AutoSizeMode = 'GrowAndShrink'
  $c.BackColor = $ui.C.White; $c.Outer = $Back; $c.Line = $pc.line; $c.MinimumSize = [Drawing.Size]::new($W, 0)
  $tp = $(if ($Top) { 4 } else { 0 }); if ($Top) { $c.TopFill = $pc.primary; $c.TopH = (& $wn.Sc 4) }
  $c.Padding = & $ui.Pad (& $wn.Sc $PadX) (& $wn.Sc (18 + $tp)) (& $wn.Sc $PadX) (& $wn.Sc 18); $c.Margin = & $ui.Pad 0 0 0 (& $wn.Sc 14)
  & $ui.Ring $c
  if ($Cap) { [void](& $wn.Txt $c (([string]$Cap).ToUpperInvariant()) $ui.F.SmallB $ui.C.Gray 0 ($W - 2 * (& $wn.Sc $PadX)) 'Section' $null) }
  return $c }
# ---- The block builders: one per block type T of the card data. Each takes the parent, the block, the width and the
# column context (@{ Col }; only the grid reads it), and adds its controls to the parent. A builder declares only what it reads.
$wn.Blocks = @{}
# Chips in a row, with the step line in capitals after them; R7 (W3): the step line's middle is the chips' middle ($wn.ChipTops).
$wn.Blocks.chips = { param($Parent, $b, [int]$W)
  $f = & $wn.Flow $Parent $ui.C.White; $f.Margin = & $ui.Pad 0 0 0 (& $wn.Sc 10)
  $chips = @(foreach ($it in @($b.Items)) { $cp = & $wn.Chip $it[0] $it[1] $ui.C.White; [void]$f.Controls.Add($cp); $cp })
  if (-not $b.Cap) { return }
  $t = & $wn.Txt $f (([string]$b.Cap).ToUpperInvariant()) $ui.F.SmallB $ui.C.Gray 0 ([math]::Max((& $wn.Sc 200), $W - (& $wn.Sc 260))) 'Step line' $null
  $tops = & $wn.ChipTops $chips[0].Height $t.Font 0
  $t.Margin = & $ui.Pad $t.Margin.Left $tops.Text $t.Margin.Right $t.Margin.Bottom
  foreach ($cp in $chips) { $m = $cp.Margin; $cp.Margin = & $ui.Pad $m.Left $tops.Chip $m.Right $m.Bottom; & $wn.KeepChip $cp $t 'chips' } }
# The headline (Small: the body size).
$wn.Blocks.head = { param($Parent, $b, [int]$W)
  $font = $(if ($b.Small) { $ui.F.Body } else { $ui.F.Sent })
  [void](& $wn.Txt $Parent $b.Text $font $ui.C.Navy 4 $W 'Heading' $null) }
# A text: Style box (gray box), note (small gray), cap (a label in capitals) or body text.
$wn.Blocks.p = { param($Parent, $b, [int]$W)
  $st = [string]$b.Style
  if ($st -eq 'box') {
    $bx = & $wn.Panel $W 12; $bx.BackColor = $pc.surface
    $t = & $wn.Txt $bx $b.Text $ui.F.Small $ui.C.Ink 0 ($W - 2 * (& $wn.Sc 12)) 'Note' $pc.surface; $t.Location = [Drawing.Point]::new((& $wn.Sc 12), (& $wn.Sc 10))
    & $wn.Fit $bx 10; [void]$Parent.Controls.Add($bx) }
  elseif ($st -eq 'note') { [void](& $wn.Txt $Parent $b.Text $ui.F.Small $ui.C.Gray 8 $W 'Note' $null) }
  elseif ($st -eq 'cap') { [void](& $wn.Txt $Parent (([string]$b.Text).ToUpperInvariant()) $ui.F.SmallB $ui.C.Gray 14 $W 'Label' $null) }
  else { [void](& $wn.Txt $Parent $b.Text $ui.F.Body $ui.C.Ink 8 $W 'Text' $null) } }
$wn.Blocks.steps = {
  <#
  .SYNOPSIS
  The 12 step dots with their names; step N is the current one.
  .DESCRIPTION
  The fonts (three sizes, normal and semibold) are made once; the control picks the largest size whose words fit.
  .PARAMETER Parent
  The card that gets the dots.
  .PARAMETER b
  The block: N = the current step.
  .PARAMETER W
  The width of the dots.
  #>
  param($Parent, $b, [int]$W)
  if (-not $wn.StepFonts) {
    $wn.StepFonts = @{ A = @((& $ui.Font 'Segoe UI' 9 $null), (& $ui.Font 'Segoe UI' 8.25 $null), (& $ui.Font 'Segoe UI' 7.5 $null))
      B = @((& $ui.Font 'Segoe UI Semibold' 9 $null), (& $ui.Font 'Segoe UI Semibold' 8.25 $null), (& $ui.Font 'Segoe UI Semibold' 7.5 $null)) } }
  $s = New-Object Pfm.Steps; $s.BackColor = $ui.C.White; $s.Labels = [string[]]$StepNames; $s.Current = [int]$b.N; $s.Dot = & $wn.Sc 26
  $s.DoneFill = $pc.primary; $s.DoneText = $ui.C.White; $s.NowFill = $pc.accentFill; $s.NowLine = $pc.navy; $s.NowText = $pc.ink
  $s.TodoFill = $ui.C.White; $s.TodoLine = $pc.muted; $s.TodoText = $pc.ink; $s.ConnDone = $pc.primary; $s.ConnTodo = $pc.track
  $s.LabelDone = $pc.ink; $s.LabelNow = $pc.navy; $s.LabelTodo = $pc.muted
  $s.Fonts = [Drawing.Font[]]$wn.StepFonts.A; $s.FontsB = [Drawing.Font[]]$wn.StepFonts.B
  $lh = [Windows.Forms.TextRenderer]::MeasureText('Ag', $wn.StepFonts.A[0]).Height
  $s.Size = [Drawing.Size]::new($W, ($s.Dot + 2 * $lh + (& $wn.Sc 12))); $s.Margin = & $ui.Pad 0 (& $wn.Sc 14) 0 (& $wn.Sc 6)
  $s.AccessibleName = 'Step ' + $b.N + ' of 12: ' + $StepNames[$b.N - 1] + '. Steps 1 to ' + ($b.N - 1) + ' are done.'
  [void]$Parent.Controls.Add($s) }
$wn.Blocks.check = {
  <#
  .SYNOPSIS
  A check result: a green chip, its text and (R30 V3: only when it has something to open) its link.
  .DESCRIPTION
  R6 (R31b D3): the chip's vertical middle is the middle of the first line of the text (within half a pixel, at any
  scale). The chip is taller than a line, so the text starts lower by the difference and the chip sits at the top.
  R7 (W3): the same rule as every other chip beside text ($wn.ChipTops); each chip and its text are kept in
  $wn.ChipRows ($wn.KeepChip) for the measure part and the layout self-check.
  .PARAMETER Parent
  The card that gets the check.
  .PARAMETER b
  The block: Chip (the chip's word), Text, Findings and Link.
  .PARAMETER W
  The width of the check row.
  #>
  param($Parent, $b, [int]$W)
  $p = & $wn.Panel $W 8
  $cp = & $wn.Chip 'ok' $b.Chip $ui.C.White; [void]$p.Controls.Add($cp)
  $x = $cp.Width + (& $wn.Sc 10)
  $t = & $wn.Txt $p $b.Text $ui.F.Body $ui.C.Ink 0 ($W - $x) 'Check result' $null
  $tops = & $wn.ChipTops $cp.Height $t.Font 0   # R7: the one chip rule (the chip is taller than the line: the text starts lower)
  $cp.Location = [Drawing.Point]::new(0, $tops.Chip); $t.Location = [Drawing.Point]::new($x, $tops.Text)
  & $wn.KeepChip $cp $t 'check'
  if (Test-CheckLink $b) { $l = & $wn.Link $b.Link; $l.Location = [Drawing.Point]::new($x, ($t.Bottom + (& $wn.Sc 2))); [void]$p.Controls.Add($l) }
  & $wn.Fit $p 4; [void]$Parent.Controls.Add($p) }
$wn.Blocks.ck = {
  <#
  .SYNOPSIS
  A check box with its text and an optional link under the text; its state is kept in $wn.Field[Id].
  .PARAMETER Parent
  The card that gets the box.
  .PARAMETER b
  The block: Id, Text and Link.
  .PARAMETER W
  The width of the box row.
  #>
  param($Parent, $b, [int]$W)
  $p = & $wn.Panel $W 8
  $cb = New-Object System.Windows.Forms.CheckBox; $cb.Text = ''; $cb.AutoSize = $false; $cb.Size = [Drawing.Size]::new((& $wn.Sc 24), (& $wn.Sc 24))
  $cb.Location = [Drawing.Point]::new((& $wn.Sc 4), (& $wn.Sc 2))
  $cb.AccessibleName = [string]$b.Text; $cb.BackColor = $ui.C.White; $cb.Tag = [string]$b.Id; $cb.Checked = [bool]$wn.Field[$b.Id]; & $ui.Cue $cb
  $cb.Add_CheckedChanged({ $wn.Field[[string]$this.Tag] = [bool]$this.Checked }); [void]$p.Controls.Add($cb)
  $x = & $wn.Sc 38
  $t = & $wn.Txt $p $b.Text $ui.F.Body $ui.C.Ink 0 ($W - $x) 'Checkbox text' $null; $t.Location = [Drawing.Point]::new($x, 0)
  if (Test-CheckLink $b) { $l = & $wn.Link $b.Link; $l.Location = [Drawing.Point]::new($x, ($t.Bottom + (& $wn.Sc 2))); [void]$p.Controls.Add($l) }
  & $wn.Fit $p 4; [void]$Parent.Controls.Add($p) }
$wn.Blocks.rows = {
  <#
  .SYNOPSIS
  Label and value rows with a line between them; the value is a chip when the row names a chip kind.
  .DESCRIPTION
  R7 (R32 W3): a chip's middle is the middle of its label's first line ($wn.ChipTops; it was about 2 px lower), and
  the chip is kept with its label in $wn.ChipRows ($wn.KeepChip).
  .PARAMETER Parent
  The card that gets the rows.
  .PARAMETER b
  The block: Rows, each @(label, value, chip kind or '').
  .PARAMETER W
  The width of the rows.
  #>
  param($Parent, $b, [int]$W)
  $first = $true
  foreach ($r in @($b.Rows)) {
    if (-not $first) { & $wn.Rule $Parent $W 0 }
    $p = & $wn.Panel $W 0
    $lw = [int]($W * 0.5); $vw = $W - $lw - (& $wn.Sc 16)
    $a = & $wn.Txt $p $r[0] $ui.F.Small $ui.C.Ink 0 $lw 'Label' $null; $a.Location = [Drawing.Point]::new(0, (& $wn.Sc 8))
    if ($r[2]) { $v = & $wn.Chip $r[2] $r[1] $ui.C.White; $tops = & $wn.ChipTops $v.Height $a.Font (& $wn.Sc 8)
      $a.Location = [Drawing.Point]::new(0, $tops.Text); $v.Location = [Drawing.Point]::new(($W - $v.Width), $tops.Chip); [void]$p.Controls.Add($v); & $wn.KeepChip $v $a 'rows' }
    else { $v = & $wn.Txt $p $r[1] $ui.F.SmallB $ui.C.Ink 0 $vw 'Value' $null; $v.Location = [Drawing.Point]::new(($W - $v.Width), (& $wn.Sc 8)) }
    & $wn.Fit $p 8; [void]$Parent.Controls.Add($p); $first = $false } }
$wn.ListRow = {
  <#
  .SYNOPSIS
  One row of a list: an optional chip, a title, up to two gray lines and an optional compact button at the right.
  .PARAMETER Parent
  The card that gets the row.
  .PARAMETER It
  The list item: Chip, Title, Sub, Detail, Btn.
  .PARAMETER W
  The width of the row.
  .PARAMETER Tx
  Where the text starts (the width of the widest chip of the list and a gap; 0 without chips).
  #>
  param($Parent, $It, [int]$W, [int]$Tx)
  $p = & $wn.Panel $W 0
  $bw = 0; $btn = $null
  if ($It.Btn) { $btn = & $wn.Button $It.Btn 'compact'; $btn.AutoSize = $true; $bw = [math]::Max($btn.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $btn.MinimumSize.Width) }
  $tw = $W - $Tx - $bw - (& $wn.Sc 16) - (& $wn.Sc 8)
  $y = & $wn.Sc 8
  $t1 = & $wn.Txt $p $It.Title $ui.F.SmallB $ui.C.Ink 0 $tw 'Item' $null
  if ($It.Chip) {   # R7 (W3): the chip's middle is the title's first-line middle ($wn.ChipTops), not 7 px lower
    $cp = & $wn.Chip $It.Chip[0] $It.Chip[1] $ui.C.White; $tops = & $wn.ChipTops $cp.Height $t1.Font $y; $y = $tops.Text
    $cp.Location = [Drawing.Point]::new(0, $tops.Chip); [void]$p.Controls.Add($cp); & $wn.KeepChip $cp $t1 'list' }
  $t1.Location = [Drawing.Point]::new($Tx, $y); $y = $t1.Bottom + (& $wn.Sc 2)
  if ($It.Sub) { $t2 = & $wn.Txt $p $It.Sub $ui.F.Small $ui.C.Gray 0 $tw 'Item detail' $null; $t2.Location = [Drawing.Point]::new($Tx, $y); $y = $t2.Bottom + (& $wn.Sc 2) }
  if ($It.Detail) { $t3 = & $wn.Txt $p $It.Detail $ui.F.Small $ui.C.Gray 0 $tw 'Item detail' $null; $t3.Location = [Drawing.Point]::new($Tx, $y); $y = $t3.Bottom }
  if ($btn) {
    $btn.Size = [Drawing.Size]::new($bw, $btn.MinimumSize.Height)
    $btn.Location = [Drawing.Point]::new(($W - $bw - (& $wn.Sc 4)), [math]::Max((& $wn.Sc 6), [int](($y + (& $wn.Sc 8) - $btn.Height) / 2))); [void]$p.Controls.Add($btn) }
  & $wn.Fit $p 8; [void]$Parent.Controls.Add($p) }
# A list of rows with a line between them; the texts of all rows start after the widest chip.
$wn.Blocks.list = { param($Parent, $b, [int]$W)
  $first = $true
  $cw = 0; foreach ($it in @($b.Rows)) { if ($it.Chip) { $cw = [math]::Max($cw, [Windows.Forms.TextRenderer]::MeasureText([string]$it.Chip[1], $ui.F.SmallB).Width + (& $wn.Sc 22)) } }
  $tx = $(if ($cw) { $cw + (& $wn.Sc 16) } else { 0 })
  foreach ($it in @($b.Rows)) { if (-not $first) { & $wn.Rule $Parent $W 0 }; & $wn.ListRow $Parent $it $W $tx; $first = $false } }
# A grid (the grid part builds it).
$wn.Blocks.grid = { param($Parent, $b, [int]$W, $Ctx) & $wn.Grid $Parent $b $W $Ctx }
$wn.Blocks.filter = {
  <#
  .SYNOPSIS
  The search box and the "Show" list above the All Actions grid; a change filters the grid at once.
  .PARAMETER Parent
  The card that gets the row (the row has fixed widths; the block has no settings).
  #>
  param($Parent)
  $f = & $wn.Flow $Parent $ui.C.White; $f.Margin = & $ui.Pad 0 0 0 (& $wn.Sc 10)
  [void](& $wn.Txt $f 'Find a publication' $ui.F.SmallB $ui.C.Navy 8 (& $wn.Sc 140) 'Label' $null)
  $tb = New-Object System.Windows.Forms.TextBox; $tb.Width = & $wn.Sc 260; $tb.Font = $ui.F.Body; $tb.AccessibleName = 'Find a publication'
  $tb.Margin = & $ui.Pad (& $wn.Sc 4) (& $wn.Sc 4) (& $wn.Sc 16) (& $wn.Sc 4)
  $tb.Text = [string]$wn.Field.find; $tb.Add_TextChanged({ $wn.Field.find = $this.Text; & $wn.Refilter }); & $ui.Cue $tb; $ui.Boxes = @($ui.Boxes) + @($tb); [void]$f.Controls.Add($tb)
  [void](& $wn.Txt $f 'Show' $ui.F.SmallB $ui.C.Navy 8 (& $wn.Sc 60) 'Label' $null)
  $cmb = New-Object System.Windows.Forms.ComboBox; $cmb.DropDownStyle = 'DropDownList'; $cmb.Font = $ui.F.Body; $cmb.Width = & $wn.Sc 230; $cmb.AccessibleName = 'Show'
  $cmb.Margin = & $ui.Pad (& $wn.Sc 4) (& $wn.Sc 4) (& $wn.Sc 4) (& $wn.Sc 4)
  foreach ($o in 'All open actions', 'Needs you', 'Late or no answer') { [void]$cmb.Items.Add($o) }
  $cmb.SelectedIndex = [int]$wn.Field.show; $cmb.Add_SelectedIndexChanged({ $wn.Field.show = $this.SelectedIndex; & $wn.Refilter }); & $ui.Cue $cmb; [void]$f.Controls.Add($cmb) }
$wn.Blocks.input = {
  <#
  .SYNOPSIS
  A labeled text box (one line, or Multi: 4 lines); its text is kept in $wn.Field[Id]; the reason box is $wn.Reason.
  .PARAMETER Parent
  The card that gets the box.
  .PARAMETER b
  The block: Id, Label, Multi.
  .PARAMETER W
  The card width.
  #>
  param($Parent, $b, [int]$W)
  [void](& $wn.Txt $Parent $b.Label $ui.F.SmallB $ui.C.Navy 14 $W 'Label' $null)
  $tb = New-Object System.Windows.Forms.TextBox; $tb.Font = $ui.F.Body; $tb.AccessibleName = [string]$b.Label; $tb.Tag = [string]$b.Id; $tb.BorderStyle = 'FixedSingle'
  $tb.Margin = & $ui.Pad (& $wn.Sc 4) (& $wn.Sc 6) (& $wn.Sc 4) (& $wn.Sc 4)
  if ($b.Multi) { $tb.Multiline = $true; $tb.AcceptsReturn = $true; $tb.ScrollBars = 'Vertical'; $tb.Size = [Drawing.Size]::new(($W - (& $wn.Sc 8)), (& $wn.Sc 88)) }
  else { $tb.Width = [math]::Min($W - (& $wn.Sc 8), (& $wn.Sc 420)) }
  $tb.Text = [string]$wn.Field[$b.Id]; $tb.Add_TextChanged({ $wn.Field[[string]$this.Tag] = $this.Text }); & $ui.Cue $tb; $ui.Boxes = @($ui.Boxes) + @($tb)
  [void]$Parent.Controls.Add($tb); if ($b.Id -eq 'reason') { $wn.Reason = $tb } }
# Radio choices under a label; the choice is kept in $wn.Field.radio.
$wn.Blocks.radio = { param($Parent, $b, [int]$W)
  [void](& $wn.Txt $Parent $b.Label $ui.F.SmallB $ui.C.Navy 14 $W 'Label' $null)
  $i = 0
  foreach ($o in @($b.Items)) {
    $rb = New-Object System.Windows.Forms.RadioButton; $rb.Text = [string]$o; $rb.AutoSize = $true; $rb.Font = $ui.F.Body; $rb.BackColor = $ui.C.White; $rb.Tag = $i; $rb.AccessibleName = [string]$o
    $rb.Margin = & $ui.Pad (& $wn.Sc 4) (& $wn.Sc 6) (& $wn.Sc 4) 0; $rb.Checked = ([int]$wn.Field.radio -eq $i); & $ui.Cue $rb
    $rb.Add_CheckedChanged({ if ($this.Checked) { $wn.Field.radio = [int]$this.Tag } }); [void]$Parent.Controls.Add($rb); $i++ } }
# The error line, shown only after a button found its field empty ($wn.Err = the block's Key).
$wn.Blocks.err = { param($Parent, $b, [int]$W)
  if ($wn.Err -eq $b.Key) { [void](& $wn.Txt $Parent ('Error: ' + $b.Text) $ui.F.SmallB $ui.C.Red 10 $W 'Error' $null) } }
# A progress bar with its text under it.
$wn.Blocks.progress = { param($Parent, $b, [int]$W)
  $pb = New-Object System.Windows.Forms.ProgressBar; $pb.Style = 'Continuous'; $pb.Maximum = [int]$b.Max; $pb.Value = [int]$b.Value; $pb.AccessibleName = [string]$b.Text
  $pb.Size = [Drawing.Size]::new($W, (& $wn.Sc 14)); $pb.Margin = & $ui.Pad 0 (& $wn.Sc 12) 0 0; [void]$Parent.Controls.Add($pb)
  [void](& $wn.Txt $Parent $b.Text $ui.F.SmallB $ui.C.Ink 6 $W 'Progress' $null) }
# The card's buttons in a row that wraps; the first blue one is the card's main button ($wn.Primary, the Enter key).
$wn.Blocks.buttons = { param($Parent, $b, [int]$W)
  $f = & $wn.Flow $Parent $ui.C.White; $f.WrapContents = $true; $f.MaximumSize = [Drawing.Size]::new($W, 0); $f.Margin = & $ui.Pad 0 (& $wn.Sc 14) 0 0
  foreach ($it in @($b.Items)) {
    $x = & $wn.Button $it 'action'; [void]$f.Controls.Add($x)
    if ($it.Kind -eq 'primary' -and -not $wn.Primary) { $wn.Primary = $x } } }
# Builds one block of the card data with the builder of its type (an unknown type builds nothing).
$wn.Block = { param($Parent, $b, [int]$W, $Ctx)
  $f = $wn.Blocks[[string]$b.T]; if ($f) { & $f $Parent $b $W $Ctx } }
