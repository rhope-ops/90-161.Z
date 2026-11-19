<#
.SYNOPSIS
  90-161.Z Task 22 r7, part "grid": the grids of the PFM window (Who Has It Now, All Actions, Wave 1 answers): their
  size, their columns that always fit the grid's width, their painted cells, the filter and the row that opens a card.
.DESCRIPTION
  A grid is a read-only DataGridView with no lines but a thin rule under each row. Each cell is painted here by its
  column kind: pub (the number as a link, the title beside or under it), with and bold (semibold), chip (a status
  chip) and plain. Double-click or Enter on a row opens its card.
  R6 (R31b D4): the titles of a pub column start in one column: after the widest number of all the grid's rows and a
  fixed gap, when every title fits there, else every title goes under its number. Each painted pub cell is kept in
  the grid's Tag.Drawn for the measure part and the layout self-check.
  R7 (R32 W1): the pub column is never narrower than its widest number, title and head plus the cell padding
  ($wn.PubMin, $wn.GridCols), so no number is cut with dots and the head reads PUBLICATION; a grid with a pub column has
  rows 2 lines high at least ($wn.GridHeight); each painted pub cell and the pub head keep what they needed and had.
  Inputs: $ui, $wn, $pc, $mid, $GridQueue. Outputs: the $wn members below; nothing is read or saved.
  Run: not alone; 90161Z-T22-pfm-window-r7.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: none.
  Credentials: none.
#>
# Puts $Rows into grid $G, one value per column (Since: the date and the age when the column is wide, else the age).
$wn.GridFill = { param($G, $Rows)
  $G.Rows.Clear(); $G.Tag.Shown = @($Rows)
  foreach ($r in @($Rows)) {
    $vals = @(foreach ($c in $G.Tag.Cols) { if ($c.K -eq 'since') { $(if ($c.W -ge 100) { [string]$r.Since + ' ' + $mid + ' ' + [string]$r.Age } else { [string]$r.Age }) } else { [string]$r[$c.N] } })
    [void]$G.Rows.Add([object[]]$vals) } }
$wn.GridHeight = {
  <#
  .SYNOPSIS
  The height of a grid: all its rows, or (Fill) the room left in the window, at least 6 rows and at most all of them.
  .PARAMETER b
  The grid block: Rows, Fill.
  .PARAMETER Ctx
  The column context: Col, the column the grid is in (its height so far).
  .DESCRIPTION
  R7 (W1): a grid with a pub column has rows tall enough for 2 lines of the link font ($wn.PubLineH) and 2 px above and
  below, so a title under its number is never cut; at 100 % this is the usual 41 px.
  .OUTPUTS
  @{ H = the grid height; Full = the height with every row; Hdr = the header height; Row = the row height }.
  #>
  param($b, $Ctx)
  $rows = @($b.Rows); $hdrH = & $wn.Sc 33; $rowH = & $wn.Sc 41
  if (@($b.Cols | Where-Object { $_.K -eq 'pub' }).Count) { $rowH = [math]::Max($rowH, 2 * (& $wn.PubLineH) + (& $wn.Sc 4) + 1) }
  $full = $hdrH + $rowH * $rows.Count + 2; $h = $full
  if ($b.Fill) {
    $used = 0; try { $used = [int]$Ctx.Col.PreferredSize.Height } catch { $null = $_ }
    $avail = $wn.MainH - $wn.HeadH - $used - (& $wn.Sc 70); $h = [int][math]::Min($full, [math]::Max($avail, $hdrH + 6 * $rowH)) }
  return @{ H = $h; Full = $full; Hdr = $hdrH; Row = $rowH } }
$wn.GridNew = {
  <#
  .SYNOPSIS
  A new empty grid with the window's look: read-only, whole-row selection, no lines, wrapped cells, white header.
  .PARAMETER Name
  The accessible name of the grid.
  .PARAMETER W
  The grid width.
  .PARAMETER Hs
  The heights from $wn.GridHeight.
  .OUTPUTS
  The DataGridView.
  #>
  param([string]$Name, [int]$W, $Hs)
  $g = New-Object System.Windows.Forms.DataGridView
  $g.AccessibleName = $Name; $g.Size = [Drawing.Size]::new($W, $Hs.H); $g.Margin = & $ui.Pad 0 (& $wn.Sc 8) 0 0
  $g.AllowUserToAddRows = $false; $g.AllowUserToDeleteRows = $false; $g.AllowUserToResizeRows = $false; $g.AllowUserToResizeColumns = $false
  $g.ReadOnly = $true; $g.RowHeadersVisible = $false; $g.MultiSelect = $false; $g.SelectionMode = 'FullRowSelect'; $g.EnableHeadersVisualStyles = $false
  $g.ColumnHeadersHeightSizeMode = 'DisableResizing'; $g.ColumnHeadersHeight = $Hs.Hdr; $g.RowTemplate.Height = $Hs.Row
  $g.CellBorderStyle = 'None'; $g.ColumnHeadersBorderStyle = 'None'; $g.BorderStyle = 'None'; $g.BackgroundColor = $ui.C.White; $g.GridColor = $pc.line
  $g.AutoSizeColumnsMode='Fill'; $g.ScrollBars = 'Vertical'; $g.DefaultCellStyle.WrapMode = 'True'; $g.AutoSizeRowsMode = 'AllCells'; $g.RowTemplate.MinimumHeight = $Hs.Row
  $g.DefaultCellStyle.Padding = & $ui.Pad (& $ui.Sc 10) (& $ui.Sc 8) (& $ui.Sc 10) (& $ui.Sc 8)
  $g.DefaultCellStyle.Font = $ui.F.Small; $g.DefaultCellStyle.ForeColor = $ui.C.Ink; $g.DefaultCellStyle.BackColor = $ui.C.White
  $g.DefaultCellStyle.SelectionBackColor = $pc.surface; $g.DefaultCellStyle.SelectionForeColor = $ui.C.Ink
  $g.ColumnHeadersDefaultCellStyle.BackColor = $ui.C.White; $g.ColumnHeadersDefaultCellStyle.ForeColor = $pc.muted
  $g.ColumnHeadersDefaultCellStyle.Font = $ui.F.SmallB; $g.ColumnHeadersDefaultCellStyle.SelectionBackColor = $ui.C.White
  return $g }
$wn.GridCols = {
  <#
  .SYNOPSIS
  Adds the columns to a grid so that they always fit its own width (R28 finding 4).
  .DESCRIPTION
  Every column fills: a column keeps at most its own width as its minimum, and all minimums together never exceed the
  width the grid has, so the sum of the visible columns never exceeds the client width.
  R7 (R32 W1): a pub column keeps its whole minimum, $PubMin (its widest number, title and head plus the cell padding),
  so a number is never cut; the other columns share what is left (their text wraps).
  .PARAMETER G
  The grid.
  .PARAMETER Cols
  The column list: N, W (0 = takes the rest), K, H.
  .PARAMETER W
  The grid width.
  .PARAMETER Scroll
  The width of the vertical scroll bar when the grid scrolls, else 0.
  .PARAMETER PubMin
  The smallest width of a pub column ($wn.PubMin), or 0.
  .OUTPUTS
  The column kinds by name (@{ name = kind }).
  #>
  param($G, $Cols, [int]$W, [int]$Scroll, [int]$PubMin)
  # With a pub column the room for the scroll bar is always kept: narrower columns wrap, rows grow, and a bar may come.
  $bar = $(if ($PubMin -gt 0) { [math]::Max($Scroll, [Windows.Forms.SystemInformation]::VerticalScrollBarWidth) } else { $Scroll })
  $fixed = 0; $keep = 0; $rest = 0; $n = @($Cols).Count; $avail = $W - $bar - 2
  $pubOwn = [math]::Max(2, [math]::Min([math]::Max((& $wn.Sc 60), $PubMin), $avail - 2 * ($n - 1)))   # a pub column never leaves less than 2 px a column
  $own = @{}; foreach ($c in $Cols) {
    $o = $(if ($c.K -eq 'pub' -and $PubMin -gt 0) { $pubOwn } elseif ($c.W -eq 0) { & $wn.Sc 60 } else { & $wn.Sc $c.W }); $own[[string]$c.N] = $o
    if ($c.W -ne 0) { $fixed += $o }; if ($c.K -eq 'pub' -and $PubMin -gt 0) { $keep += $o } else { $rest += $o } }
  $k = $(if ($rest -gt 0 -and $keep + $rest -gt $avail) { [math]::Max(0.0, [double]($avail - $keep) / $rest) } else { 1.0 })
  $kinds = @{}
  foreach ($c in $Cols) {
    $dc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $dc.Name = [string]$c.N; $dc.HeaderText = $(if ($c.H) { [string]$c.H } else { [string]$c.N }); $dc.SortMode = 'NotSortable'
    $o = $own[[string]$c.N]; $min = $(if ($c.K -eq 'pub' -and $PubMin -gt 0) { $o } else { [math]::Max(2, [int][math]::Floor($o * $k)) })
    $dc.AutoSizeMode='Fill'; $dc.MinimumWidth = $min; $dc.FillWeight = [single]$(if ($c.W -eq 0) { [math]::Max(60, $W - $fixed - $Scroll) } else { $c.W })
    [void]$G.Columns.Add($dc); $kinds[[string]$c.N] = [string]$c.K }
  return $kinds }
$wn.Grid = {
  <#
  .SYNOPSIS
  A grid block: the grid with its columns, rows, painted cells and keys; with Count, the line under it that counts the rows.
  .PARAMETER Parent
  The card that gets the grid.
  .PARAMETER b
  The grid block: Name, Rows, Cols, ColsWide (used when the window is wide and they fit), Fill, Count.
  .PARAMETER W
  The grid width.
  .PARAMETER Ctx
  The column context (for Fill).
  #>
  param($Parent, $b, [int]$W, $Ctx)
  $cols = @($b.Cols)
  if ($wn.Wide -and $b.ColsWide) { $wf = 0; foreach ($c in $b.ColsWide) { $wf += (& $wn.Sc $c.W) }; if ($wf + (& $wn.Sc 137) -le $W) { $cols = @($b.ColsWide) } }
  $rows = @($b.Rows); $hs = & $wn.GridHeight $b $Ctx
  $g = & $wn.GridNew ([string]$b.Name) $W $hs
  $scroll = $(if ($hs.Full -gt $hs.H) { [Windows.Forms.SystemInformation]::VerticalScrollBarWidth } else { 0 })
  $pw = & $wn.PubWidths $rows
  $kinds = & $wn.GridCols $g $cols $W $scroll (& $wn.PubMin $cols $pw)
  $chipKind = @{}; foreach ($r in $rows) { if ($r.Status) { $chipKind[[string]$r.Status] = [string]$r.Kind } }
  $g.Tag = @{ Kind = $kinds; Chip = $chipKind; Cols = $cols; Shown = $rows; PubW = $pw.Num; PubT = $pw.Title; PubGap = (& $ui.Sc 6); Drawn = @{}; Head = $null }
  & $wn.GridFill $g $rows
  $g.Add_CellPainting({ param($s, $e) & $wn.PaintCell $s $e })
  $g.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { & $wn.Later $s $e.RowIndex } })
  $g.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Return') { $e.Handled = $true; $e.SuppressKeyPress = $true; if ($s.CurrentRow) { & $wn.Later $s $s.CurrentRow.Index } } })
  [void]$Parent.Controls.Add($g); $g.ClearSelection(); $wn.Gridsel = $g
  if ($b.Count) { $wn.CountText = [string]$b.Count; $wn.CountBox = & $wn.Txt $Parent ($b.Count -f $rows.Count) $ui.F.Small $ui.C.Gray 8 $W 'Count' $null; $wn.Gridq = $g } }
# The widest number (as a link) and the widest title of the pub values ("number|title") of $Rows, in pixels, measured as
# $wn.PaintPub draws them. All rows, not only the shown ones, so a filter does not move the title column.
$wn.PubWidths = { param($Rows)
  $fl = [Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix'; $big = [Drawing.Size]::new(100000, 0); $out = @{ Num = 0; Title = 0 }
  foreach ($r in @($Rows)) { $pp = ([string]$r.Publication).Split('|'); if ($pp.Count -lt 2) { continue }
    $out.Num = [math]::Max($out.Num, [Windows.Forms.TextRenderer]::MeasureText($pp[0], $ui.F.Link, $big, $fl).Width)
    $out.Title = [math]::Max($out.Title, [Windows.Forms.TextRenderer]::MeasureText($pp[1], $ui.F.Small, $big, $fl).Width) }
  return $out }
# The width of a one-line text $Text in font $F as the grid draws it (no padding), in pixels.
$wn.TextW = { param([string]$Text, $F)
  return [Windows.Forms.TextRenderer]::MeasureText($Text, $F, ([Drawing.Size]::new(100000, 0)), [Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width }
# The head text of grid column $C as the grid draws it: its header text (H, else its name) in capitals.
$wn.HeadText = { param($C) return ($(if ($C.H) { [string]$C.H } else { [string]$C.N })).ToUpperInvariant() }
# R7 (W1): the height of one line of a pub cell, in pixels: the larger of the link font's height and its card line height.
$wn.PubLineH = { return [math]::Max([int]$ui.F.Link.Height, (& $wn.LineH $ui.F.Link)) }
# R7 (W1): the smallest width of the pub column of $Cols: its widest number, widest title ($Pw, $wn.PubWidths) or head,
# whichever is widest, plus the cell padding at both sides and 1 px; 0 when the grid has no pub column.
$wn.PubMin = { param($Cols, $Pw)
  $c = @($Cols | Where-Object { $_.K -eq 'pub' }) | Select-Object -First 1; if (-not $c) { return 0 }
  $hw = & $wn.TextW (& $wn.HeadText $c) $ui.F.SmallB
  return ([math]::Max([math]::Max([int]$Pw.Num, [int]$Pw.Title), $hw) + 2 * (& $ui.Sc 10) + 1) }
$wn.PaintPub = {
  <#
  .SYNOPSIS
  Paints a pub cell: the number as a link and the title in the grid's title column, or under the number when the
  widest title of the grid does not fit in that column.
  .DESCRIPTION
  R6 (R31b D4): the title column starts after the grid's widest number and its gap (Tag.PubW, Tag.PubGap), so every
  title starts at one x; the choice beside or under is made once for the grid (Tag.PubT, the widest title), so a long
  title is never cut and the titles never start at two places. What was drawn goes into Tag.Drawn[row], relative to
  the text rectangle: the right end of the number, the title's x, the number's bottom and the title's top.
  R7 (R32 W1): also what each text needs and what it was given (number and title width, the height of the lines and
  of the cell), so the measure part and the layout self-check find a cut cell. A line is $wn.PubLineH high.
  .PARAMETER Gr
  The graphics of the cell.
  .PARAMETER Text
  The cell value, "number|title".
  .PARAMETER Tr
  The text rectangle of the cell (inside its padding).
  .PARAMETER Fl
  The one-line text flags.
  .PARAMETER Fw
  The wrapping text flags.
  .PARAMETER Tag
  The grid's Tag: PubW, PubT, PubGap and Drawn.
  .PARAMETER Row
  The row index (the key in Tag.Drawn).
  #>
  param($Gr, [string]$Text, $Tr, $Fl, $Fw, $Tag, [int]$Row)
  $pp = $Text.Split('|')
  $w1 = & $wn.TextW $pp[0] $ui.F.Link; $lh = & $wn.PubLineH
  $col = [int]$Tag.PubW + [int]$Tag.PubGap                 # the title column, from the left of the text rectangle
  $beside = ($pp.Count -lt 2 -or [int]$Tag.PubT -le $Tr.Width - $col)
  if ($beside) {
    [Windows.Forms.TextRenderer]::DrawText($Gr, $pp[0], $ui.F.Link, $Tr, $pc.primary, $Fl)
    $tx = $col; $ty = 0; $nb = 0; $th = $lh; $tw = $Tr.Width - $col   # one line: the title's x is the column; top and bottom are not compared
    $rest = New-Object System.Drawing.Rectangle(($Tr.X + $col), $Tr.Y, ($Tr.Width - $col), $Tr.Height)
    if ($pp.Count -gt 1) { [Windows.Forms.TextRenderer]::DrawText($Gr, $pp[1], $ui.F.Small, $rest, $pc.muted, $Fl) } }
  else {   # the widest title does not fit in the column: every title goes on a second line (the row is 2 lines high, $wn.GridHeight)
    $ny = [int](($Tr.Height - 2 * $lh) / 2); $tx = 0; $ty = $ny + $lh; $nb = $ny + $lh; $th = 2 * $lh; $tw = $Tr.Width
    [Windows.Forms.TextRenderer]::DrawText($Gr, $pp[0], $ui.F.Link, (New-Object System.Drawing.Rectangle($Tr.X, ($Tr.Y + $ny), $Tr.Width, $lh)), $pc.primary, $Fl)
    [Windows.Forms.TextRenderer]::DrawText($Gr, $pp[1], $ui.F.Small, (New-Object System.Drawing.Rectangle($Tr.X, ($Tr.Y + $ty), $Tr.Width, $lh)), $pc.muted, $Fw) }
  if ($null -eq $Tag.Drawn -or $pp.Count -lt 2) { return }
  $Tag.Drawn[$Row] = @{ NumRight = [math]::Min($w1, $Tr.Width); TitleX = $tx; NumBottom = $nb; TitleTop = $ty; Beside = $beside
    NumW = $w1; NumHave = $Tr.Width; TitleW = (& $wn.TextW $pp[1] $ui.F.Small); TitleHave = $tw; NeedH = $th; HaveH = $Tr.Height } }
# Paints a status chip cell: a rounded fill of the row's chip kind with the status in the middle. $Bd: the cell bounds; $Pd: its padding.
$wn.PaintChip = { param($Gr, [string]$Text, [string]$Kind, $Bd, [int]$Pd)
  $cwid = [Windows.Forms.TextRenderer]::MeasureText($Text, $ui.F.SmallB, ([Drawing.Size]::new(100000, 0)), [Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width + (& $ui.Sc 20)
  $chh = & $ui.Sc 26; $cy = $Bd.Y + [int](($Bd.Height - 1 - $chh) / 2); $rc = New-Object System.Drawing.RectangleF(($Bd.X + $Pd), $cy, $cwid, $chh)
  $Gr.SmoothingMode = 'AntiAlias'; $path = [Pfm.Gfx]::Round($rc, ($chh / 2.0)); $br = New-Object System.Drawing.SolidBrush($wn.Fills[$Kind]); $Gr.FillPath($br, $path); $br.Dispose(); $path.Dispose()
  $Gr.SmoothingMode = 'Default'
  $tf = [Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding, NoPrefix'
  [Windows.Forms.TextRenderer]::DrawText($Gr, $Text, $ui.F.SmallB, (New-Object System.Drawing.Rectangle(($Bd.X + $Pd), $cy, [int]$cwid, $chh)), $pc.ink, $tf) }
$wn.PaintCell = {
  <#
  .SYNOPSIS
  Paints one grid cell (the CellPainting event): the header in muted capitals with a line under it, or a row cell by its column kind.
  .PARAMETER S
  The grid.
  .PARAMETER E
  The event arguments (cell bounds, graphics, value; Handled is set).
  #>
  param($S, $E)
  try {
    $tag = $S.Tag; $kind = [string]$tag.Kind[$S.Columns[$E.ColumnIndex].Name]; $bd = $E.CellBounds; $gr = $E.Graphics; $pd = & $ui.Sc 10
    $fl = [Windows.Forms.TextFormatFlags]'Left, VerticalCenter, SingleLine, NoPadding, NoPrefix, EndEllipsis'
    $fw = [Windows.Forms.TextFormatFlags]'Left, VerticalCenter, WordBreak, NoPadding, NoPrefix'
    $tr = New-Object System.Drawing.Rectangle(($bd.X + $pd), $bd.Y, [math]::Max(1, $bd.Width - 2 * $pd), ($bd.Height - 1))
    $head = ($E.RowIndex -lt 0)
    $bg = $(if (-not $head -and $S.Rows[$E.RowIndex].Selected) { $pc.surface } else { $ui.C.White })
    $br = New-Object System.Drawing.SolidBrush($bg); $gr.FillRectangle($br, $bd); $br.Dispose()
    $pn = New-Object System.Drawing.Pen($(if ($head) { $pc.muted } else { $pc.line }), 1); $gr.DrawLine($pn, $bd.X, ($bd.Bottom - 1), $bd.Right, ($bd.Bottom - 1)); $pn.Dispose()
    $text = [string]$E.Value
    if ($head) { [Windows.Forms.TextRenderer]::DrawText($gr, $text.ToUpperInvariant(), $ui.F.SmallB, $tr, $pc.muted, $fl)
      # R7 (W1): what the head of the pub column needs and has, for the measure part and the layout self-check
      if ($kind -eq 'pub') { $tag.Head = @{ Text = $text.ToUpperInvariant(); W = (& $wn.TextW $text.ToUpperInvariant() $ui.F.SmallB); Have = $tr.Width } } }
    elseif ($kind -eq 'pub') { & $wn.PaintPub $gr $text $tr $fl $fw $tag $E.RowIndex }
    elseif ($kind -eq 'with') { [Windows.Forms.TextRenderer]::DrawText($gr, $text, $ui.F.SmallB, $tr, $pc.navy, $fw) }
    elseif ($kind -eq 'bold') { [Windows.Forms.TextRenderer]::DrawText($gr, $text, $ui.F.SmallB, $tr, $pc.ink, $fw) }
    elseif ($kind -eq 'chip') { & $wn.PaintChip $gr $text ([string]$tag.Chip[$text]) $bd $pd }
    else { [Windows.Forms.TextRenderer]::DrawText($gr, $text, $ui.F.Small, $tr, $ui.C.Ink, $fw) }
    $E.Handled = $true
  } catch { $null = $_ } }
# Opens the card of grid row $I after the current event has ended (a card change inside a grid event would dispose the grid in its own handler).
$wn.Later = { param($G, [int]$I) $wn.PendG = $G; $wn.PendI = $I; [void]$form.BeginInvoke([Action]{ & $wn.OpenRow $wn.PendG $wn.PendI }) }
# Opens the card that grid row $I goes to, as its Open button would.
$wn.OpenRow = { param($G, [int]$I)
  $r = @($G.Tag.Shown)[$I]
  if ($r -and $r.Go) { & $wn.Press @{ Go = [string]$r.Go; Text = 'Open' } } }
# Filters the All Actions grid by the search text and the "Show" choice, and updates its count line.
$wn.Refilter = {
  $g = $wn.Gridq; if (-not $g) { return }
  $q = ([string]$wn.Field.find).Trim(); $m = [int]$wn.Field.show
  $rows = @($GridQueue | Where-Object { ($m -eq 0 -or ($m -eq 1 -and $_.Me) -or ($m -eq 2 -and $_.Kind -eq 'late')) -and
      (-not $q -or ([string]$_.Publication).IndexOf($q, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) })
  & $wn.GridFill $g $rows; $g.ClearSelection()
  if ($wn.CountBox) { $wn.CountBox.Text = ([string]$wn.CountText -f $rows.Count) } }
