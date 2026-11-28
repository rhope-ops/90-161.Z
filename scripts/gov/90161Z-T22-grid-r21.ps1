<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "grid": the grids of the PFM window (Who Has It Now, All Actions, Wave 1 answers): their
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
  R8 (R35 W7, R34 open point 5): no column head is shortened with dots in a narrow grid: every column keeps at least
  the width of its head ($wn.HeadMin, $wn.GridCols), and every painted head keeps what it needed and had (Tag.Heads)
  for the measure part and the layout self-check.
  R11 (R38; PFM 20 Nov 26: R37 All Actions, the status chips "Due 20 Nov 26" touched the scroll bar): a column's width comes from its
  widest value ($wn.ValueMin: the measured text, a chip with its own padding, plus the cell padding); a chip column never
  shrinks below its chip ($wn.GridCols, $wn.FitGrid), a short column ("Weekdays in step" holds 1 or 2 digits) is as wide
  as its values or its head, and a head marked HW wraps to 2 lines ($wn.HeadWrap, $wn.HeadMin, $wn.GridHeight). Each grid
  can say where its content ends ($wn.GridEdges), so the layout self-check ($wn.EdgeCheck) fails a chip or text that
  ends closer to the grid's right edge than the vertical scroll bar is wide.
  R15 (R42 T1; R41 finding 4: at 1920 x 1094 and 150 % 3 Status chips ended under the 26 px bar): the column plan is pure
  arithmetic ($wn.ColPlan, run by tests/check_t22_r18.py) and keeps the scroll bar room; the grid fit ($wn.FitGrid) works
  on the column minimums against that room, so a grid that fits keeps its chip (r14 took the chip under the bar).
  R16 (R43 T1; R42 finding 2: home, empty and queue still "columns need 979, the grid has 961" and "1442, 1428"): r15 made the
  plan keep the bar room and the fit work on the column minimums; those grids' minimums already fitted (r14 kept the room
  with a pub column), so the fit had nothing to give back if the grid's own fill laid the columns wider than the grid (what
  the device lines suggest; not measured). The fit now also cuts the widths ($wn.TrimWidths); tests/ps/Test-T22GridWidth.ps1
  runs it on those numbers, and the LAYOUT line names the column minimums, so R43 shows if the fit ran.
  Inputs: $ui, $wn, $pc, $mid, $GridQueue. Outputs: the $wn members below; nothing is read or saved.
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: none.
  Credentials: none.
#>
# Puts $Rows into grid $G, one value per column (Since: the date and the age when the column is wide, else the age).
$wn.GridFill = { param($G, $Rows)
  $G.Rows.Clear(); $G.Tag.Shown = @($Rows)
  foreach ($r in @($Rows)) {
    $vals = @(foreach ($c in $G.Tag.Cols) { & $wn.CellText $c $r })
    [void]$G.Rows.Add([object[]]$vals) } }
# The text of row $R in column $C (Since: the date and the age when the column is wide, else the age).
$wn.CellText = { param($C, $R)
  if ($C.K -eq 'since') { return $(if ($C.W -ge 100) { [string]$R.Since + ' ' + $mid + ' ' + [string]$R.Age } else { [string]$R.Age }) }
  return [string]$R[$C.N] }
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
  # R11: a head that wraps to 2 lines (HW) needs one more line of the head font
  if (@(@($b.Cols) + @($b.ColsWide) | Where-Object { $_ -and $_.HW }).Count) { $hdrH += [int]$ui.F.SmallB.Height }
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
$wn.ColPlan = {
  <#
  .SYNOPSIS
  R15: the column plan of a grid, pure arithmetic: the smallest width and the fill weight of each column (R28 finding 4).
  .DESCRIPTION
  Every column fills: a column keeps at most its own width as its minimum, and all minimums together never exceed the
  room the grid has: the grid width less the vertical scroll bar ($wn.BarW; R15: kept in every grid, whether the bar
  shows or not) and 2 px, so the visible columns never end under the bar.
  R7 (R32 W1): a pub column keeps its whole minimum, $PubMin (its widest number, title and head plus the cell padding),
  so a number is never cut; the other columns share what is left (their text wraps).
  R8 (R35 W7): each other column keeps at least its head ($wn.HeadMin) when all heads fit: it wants the larger of its
  own width and its head; when all wants do not fit, each gets its head and the rest is shared by what it wanted more.
  Only when the heads alone do not fit do the columns shrink by one factor as before (the self-check names a cut head).
  R11 (R38): a column that is not the pub column wants the narrower of its declared width and its widest value, so a
  short column gives its room away; a chip column wants its widest chip (never less) and keeps it whole when the room is
  short, like the pub column; the fill weight of a column is the width it wants.
  .PARAMETER Cols
  The column list: N, W (0 = takes the rest), K, H.
  .PARAMETER W
  The grid width.
  .PARAMETER Scroll
  The width of the vertical scroll bar when the grid scrolls, else 0 (the fill weight of the column that takes the rest).
  .PARAMETER PubMin
  The smallest width of a pub column ($wn.PubMin), or 0.
  .PARAMETER Rows
  R11: all the rows of the grid, to measure each column's widest value ($wn.ValueMin); none: the declared widths.
  .OUTPUTS
  @{ Min = the smallest width by column name, in column order; Weight = the fill weight by name; Room = the room the
  minimums share; Reserve = the grid width less that room ($wn.FitGrid keeps it); ChipKept = $true or $false when the grid has a chip column (its chip kept whole), else $null }.
  #>
  param($Cols, [int]$W, [int]$Scroll, [int]$PubMin, $Rows = @())
  # R15: the room for the scroll bar is kept in every grid (r14: only with a pub column). ps51 W7 (96 dpi, narrowest page):
  # a grid with no pub column and no bar showing gives that room to its heads when only then they all fit (as r14).
  $bar = [math]::Max($Scroll, [int](& $wn.BarW)); $heads = 0; foreach ($c in $Cols) { $heads += [int](& $wn.HeadMin $c) }
  if ($PubMin -le 0 -and $Scroll -eq 0 -and $heads -gt $W - $bar - 2 -and $heads -le $W - 2) { $bar = 0 }
  $fixed = 0; $keep = 0; $rest = 0; $n = @($Cols).Count; $avail = $W - $bar - 2; $kept = $null
  $pubOwn = [math]::Max(2, [math]::Min([math]::Max((& $wn.Sc 60), $PubMin), $avail - 2 * ($n - 1)))   # a pub column never leaves less than 2 px a column
  $own = @{}; $hard = @{}; $spare = & $wn.HeadSpare $Cols $avail $PubMin $pubOwn; foreach ($c in $Cols) {   # R11: a chip is kept only while the heads fit
    $isPub = ($c.K -eq 'pub' -and $PubMin -gt 0); $vm = $(if (@($Rows).Count) { [int](& $wn.ValueMin $c $Rows) } else { 0 })
    $chipKeep = ($c.K -eq 'chip' -and $vm -gt 0 -and ($vm - [int](& $wn.HeadMin $c)) -le $spare)   # Tag.ChipKept: the edge check judges only a kept chip
    if ($c.K -eq 'chip') { $kept = $chipKeep; if ($chipKeep) { $spare -= [math]::Max(0, $vm - [int](& $wn.HeadMin $c)) } }
    $hard[[string]$c.N] = ($isPub -or $chipKeep)
    $o = $(if ($isPub) { $pubOwn } elseif ($chipKeep) { [math]::Max($vm, [int](& $wn.HeadMin $c)) } elseif ($c.W -eq 0) { & $wn.Sc 60 }
      elseif ($vm -gt 0) { [math]::Min((& $wn.Sc $c.W), $vm) } else { & $wn.Sc $c.W }); $own[[string]$c.N] = $o
    if ($c.W -ne 0) { $fixed += $o }; if ($hard[[string]$c.N]) { $keep += $o } else { $rest += $o } }
  $k = $(if ($rest -gt 0 -and $keep + $rest -gt $avail) { [math]::Max(0.0, [double]($avail - $keep) / $rest) } else { 1.0 })
  # R8 (W7): the head floor of each other column, what it wants, and the room they share ($avail less the pub column)
  $hm = @{}; $want = 0; $floor = 0; $more = 0
  foreach ($c in $Cols) { if (-not $hard[[string]$c.N]) { $f = & $wn.HeadMin $c; $hm[[string]$c.N] = $f
      $floor += $f; $want += [math]::Max($own[[string]$c.N], $f); $more += [math]::Max(0, $own[[string]$c.N] - $f) } }
  $pool = $avail - $keep
  $mins = [ordered]@{}; $wts = @{}
  foreach ($c in $Cols) {
    $o = $own[[string]$c.N]; $f = [int]$hm[[string]$c.N]
    $mins[[string]$c.N] = [int]$(if ($hard[[string]$c.N]) { $o } elseif ($want -le $pool) { [math]::Max($o, $f) }
      elseif ($floor -le $pool) { $f + $(if ($more -gt 0) { [int][math]::Floor(($pool - $floor) * [math]::Max(0, $o - $f) / [double]$more) } else { 0 }) }
      else { [math]::Max(2, [int][math]::Floor($o * $k)) })
    $wts[[string]$c.N] = [single]$(if ($c.W -eq 0) { [math]::Max(60, $W - $fixed - $Scroll) } else { [math]::Max(1, $o) }) }
  return @{ Min = $mins; Weight = $wts; Room = $avail; Reserve = $W - $avail; ChipKept = $kept } }
# Adds the columns of the plan ($wn.ColPlan; the parameters are its own) to grid $G: each fills, with its smallest width
# and its fill weight. Gives back the column kinds by name (@{ name = kind }); $wn.ChipKept is the plan's ChipKept.
$wn.GridCols = {
  param($G, $Cols, [int]$W, [int]$Scroll, [int]$PubMin, $Rows = @())
  $plan = & $wn.ColPlan $Cols $W $Scroll $PubMin $Rows; $wn.ChipKept = $plan.ChipKept; $wn.Reserve = $plan.Reserve
  $kinds = @{}
  foreach ($c in $Cols) {
    $dc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $dc.Name = [string]$c.N; $dc.HeaderText = $(if ($c.H) { [string]$c.H } else { [string]$c.N }); $dc.SortMode = 'NotSortable'
    $dc.AutoSizeMode='Fill'; $dc.MinimumWidth = [math]::Max(2, [int]$plan.Min[[string]$c.N]); $dc.FillWeight = $plan.Weight[[string]$c.N]
    [void]$G.Columns.Add($dc); $kinds[[string]$c.N] = [string]$c.K }
  return $kinds }
# R15: the width of a vertical scroll bar ($wn.BarW) and of the bar grid $G shows now, else 0 ($wn.BarShown), in px.
$wn.BarW = { return [int][Windows.Forms.SystemInformation]::VerticalScrollBarWidth }
# R15: the width of the vertical scroll bar that grid $G shows now (0 when none shows); $wn.FitGrid and $wn.EdgeCheck use it.
$wn.BarShown = { param($G) $v = @($G.Controls | Where-Object { $_ -is [Windows.Forms.VScrollBar] -and $_.Visible }); if ($v.Count) { return [int]$v[0].Width }; return 0 }
# R11 (R38; ps51 W7 at 96 dpi): the room a grid of width $Avail has above all its column heads (the pub column counts
# $PubOwn when $PubMin is above 0). $wn.GridCols keeps a status chip whole only while that room holds the chip's extra
# width, else the chip column shares the room as in r10, so a narrow window never cuts the other heads.
$wn.HeadSpare = { param($Cols, [int]$Avail, [int]$PubMin, [int]$PubOwn)
  $spare = $Avail; foreach ($c in $Cols) { $spare -= $(if ($c.K -eq 'pub' -and $PubMin -gt 0) { $PubOwn } else { [int](& $wn.HeadMin $c) }) }
  return $spare }
# R11 (R38; the PFM, 20 Nov 26: "hide Since when narrow"): the columns of a grid of width $W with each column marked Drop
# left out, last first, while the pub column's minimum ($wn.PubMin of the widths $Pw) and every other whole head do not fit
# beside the scroll bar. Wide windows keep every column.
# R12 (R38 finding 2: the Your Work grid needed 957 px and had 935 at 150 %): a chip column counts its widest chip of
# $Rows ($wn.ValueMin), not only its head, so Since leaves when the whole chips do not fit beside the other heads.
$wn.DropCols = { param($Cols, [int]$W, $Pw, $Rows = @())
  $cols = @($Cols); $avail = $W - (& $wn.BarW) - 2
  while ($true) {
    $need = [int](& $wn.PubMin $cols $Pw)
    foreach ($c in $cols) { if ($c.K -ne 'pub') { $hm = [int](& $wn.HeadMin $c)
        $sb = [math]::Max((& $ui.Sc 10), [int](& $wn.BarW))   # ValueMin keeps a scroll bar right of a chip; $avail has taken it off already
        $need += $(if ($c.K -eq 'chip' -and @($Rows).Count) { [math]::Max($hm, [int](& $wn.ValueMin $c $Rows) - $sb) } else { $hm }) } }
    $drop = @($cols | Where-Object { $_.Drop }) | Select-Object -Last 1
    if ($need -le $avail -or -not $drop) { return ,$cols }
    $cols = @($cols | Where-Object { $_ -ne $drop }) } }
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
  $rows = @($b.Rows); $pw = & $wn.PubWidths $rows; $cols = & $wn.DropCols $cols $W $pw $rows; $hs = & $wn.GridHeight $b $Ctx
  $g = & $wn.GridNew ([string]$b.Name) $W $hs
  $scroll = $(if ($hs.Full -gt $hs.H) { (& $wn.BarW) } else { 0 })
  $wn.ChipKept = $null; $kinds = & $wn.GridCols $g $cols $W $scroll (& $wn.PubMin $cols $pw) $rows
  $chipKind = @{}; foreach ($r in $rows) { if ($r.Status) { $chipKind[[string]$r.Status] = [string]$r.Kind } }
  $g.Tag = @{ Kind = $kinds; Chip = $chipKind; Cols = $cols; Shown = $rows; PubW = $pw.Num; PubT = $pw.Title; PubGap = (& $ui.Sc 6); Drawn = @{}; Head = $null
    Heads = [ordered]@{}; ChipKept = $wn.ChipKept; Reserve = $wn.Reserve }
  & $wn.GridFill $g $rows
  $g.Add_CellPainting({ param($s, $e) & $wn.PaintCell $s $e })
  $g.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { & $wn.Later $s $e.RowIndex } })
  $g.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Return') { $e.Handled = $true; $e.SuppressKeyPress = $true; if ($s.CurrentRow) { & $wn.Later $s $s.CurrentRow.Index } } })
  [void]$Parent.Controls.Add($g); $g.ClearSelection(); $wn.Gridsel = $g
  # R18 (the PFM, 26 Nov 26, R45 comment 4: a stray label "4" under the waves grid): the Count property of a hash table is its number of keys (the 4 keys
  # of the waves block), never "no Count key", so the line under the grid showed that number. The key is read by name, with an index.
  $cnt = [string]$b['Count']
  if ($cnt) { $wn.CountText = $cnt; $wn.CountBox = & $wn.Txt $Parent ($cnt -f $rows.Count) $ui.F.Small $ui.C.Gray 8 $W 'Count' $null; $wn.Gridq = $g } }
# R10 (R37; R36 finding 3: the home grid "Who has it now" columns needed 810 px, the grid had 801): after a card is laid
# out, each grid on the page whose column minimums are wider than its room gives the excess back ($wn.FitGrid). The
# layout self-check ($wn.ScrollCheck) still measures the result, so a grid that does not fit stays a defect. Gives back
# the number of grids changed.
$wn.FitGrids = {
  $n = 0; $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) { foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.DataGridView]) { if (& $wn.FitGrid $c) { $n++ } }
      elseif ($c.Controls.Count) { $st.Push($c) } } }
  return $n }
$wn.FitGrid = {
  <#
  .SYNOPSIS
  R10, R15: fits one grid (see $wn.FitGrids): lowers column minimums by the excess of the minimums over the grid's room.
  .DESCRIPTION
  R15 (R41 finding 4): the room is the client width less the plan's reserve (Tag.Reserve, $wn.ColPlan) or less the bar
  that shows now, the larger; the excess is the sum of the minimums of the visible columns less the room, so a grid
  that fits gives nothing back however its fill columns share the width. The excess comes off the columns that are not the pub column, the one with the most width above its head
  ($wn.HeadMin) first: the other columns above their heads, then the chip column above its head, then any column under
  its head (never under 2 px). When the minimums changed, or the filled columns end past the grid or under a bar that shows, the grid lays
  out its columns again (a 1 px size change makes the fill columns share the room again).
  R16 (R42 finding 2): when the columns still end past the grid, or under a bar that shows, after that layout, their widths
  are cut to the room ($wn.TrimWidths).
  R15 (R42 ps51 keep test: a later open of the Wave 1 answers card took 114 ms, 13 before): when the fit took off a bar
  that shows beyond the plan's reserve, Tag.Reserve becomes that bar and the columns keep their widths (AutoSizeMode
  None): their fill width no longer depends on the bar, and the bar no longer on the row heights the widths give, so a
  second fit, and a later open of the kept card, find nothing to do.
  .PARAMETER G
  The grid (its Tag holds the column kinds and the column list, $wn.Grid); any object with ClientSize, Width, Columns
  (Name, Visible, Width, MinimumWidth, AutoSizeMode) and that Tag (tests/check_t22_r18.py gives one off Windows).
  .OUTPUTS
  $true when it changed a column or laid the grid out again, else $false.
  #>
  param($G)
  # the plan's room (Tag.Reserve), and never under a vertical bar that shows now (rows that wrap can bring one)
  $res = $(if ($null -ne $G.Tag.Reserve) { [int]$G.Tag.Reserve } else { [int](& $wn.BarW) + 2 })
  $shown = [int](& $wn.BarShown $G); $room = [int]$G.ClientSize.Width - [math]::Max($res, $shown)
  $vis = @($G.Columns | Where-Object { $_.Visible }); $mins = 0; $sum = 0
  foreach ($k in $vis) { $mins += [int]$k.MinimumWidth; $sum += [int]$k.Width }
  $excess = $mins - $room; $stale = ($sum -gt [int]$G.ClientSize.Width - $shown + 1)   # stale: the filled widths end past the grid or under a bar that shows
  if ($excess -le 0 -and -not $stale) { return $false }
  $kinds = $G.Tag.Kind; $heads = @{}; foreach ($c in @($G.Tag.Cols)) { $heads[[string]$c.N] = [int](& $wn.HeadMin $c) }
  $free = @($vis | Where-Object { [string]$kinds[$_.Name] -ne 'pub' }); $gave = 0
  foreach ($pass in 'others above head', 'above head', 'under head') {
    $set = @($free | Where-Object { $pass -ne 'others above head' -or [string]$kinds[$_.Name] -ne 'chip' })
    foreach ($k in @($set | Sort-Object { [int]$_.MinimumWidth - [int]$heads[$_.Name] } -Descending)) {
      if ($excess -le 0) { break }
      $floor = $(if ($pass -eq 'under head') { 2 } else { [math]::Max(2, [int]$heads[$k.Name]) })
      $give = [math]::Min($excess, [int]$k.MinimumWidth - $floor); if ($give -le 0) { continue }
      $k.MinimumWidth = [int]$k.MinimumWidth - $give; $excess -= $give; $gave++ } }
  if (-not $gave -and -not $stale) { return $false }   # excess, but no column could give any width back: nothing changed
  $G.Width = $G.Width - 1; $G.Width = $G.Width + 1   # the fill columns share the room again
  # R16 (R42 finding 2: home and queue still "columns need 979, the grid has 961" and "1442, 1428"): the minimums fitted, so the
  # excess above was 0, and the layout above gave the same widths again. The widths themselves are cut to the room here.
  $null = & $wn.TrimWidths $vis $room ([int]$G.ClientSize.Width - $shown)   # R16 review: a bar that shows counts, also under the grid width
  if ($shown -gt $res) {   # R15: the grid keeps the room of the bar that shows, and its widths stop following the bar
    $G.Tag.Reserve = $shown; foreach ($k in $vis) { $k.AutoSizeMode = 'None' } }   # (no fill and row layout again on each open)
  return $true }
# R16 (R42 finding 2): after the grid laid its fill columns out, cuts their widths to $Room when they still end past the grid
# (they end past $Client: the grid width less the bar that shows, 1 px of rounding allowed): the width above its column minimum comes off, the column with the most first, and
# the columns stop filling (AutoSizeMode None), so the grid's own layout cannot give the width back. No column goes under its
# minimum, so a kept status chip keeps its whole width ($wn.ValueMin). $Cols: the visible columns (Width, MinimumWidth,
# AutoSizeMode). Gives back $true when it changed a width, else $false.
$wn.TrimWidths = { param($Cols, [int]$Room, [int]$Client)
  $sum = 0; foreach ($k in $Cols) { $sum += [int]$k.Width }
  if ($sum -le $Client + 1) { return $false }   # the widths end before the bar that shows (or the grid edge): nothing to cut
  $over = $sum - $Room; foreach ($k in $Cols) { $k.AutoSizeMode = 'None' }
  foreach ($k in @($Cols | Sort-Object { [int]$_.Width - [int]$_.MinimumWidth } -Descending)) {
    if ($over -le 0) { break }
    $give = [math]::Min($over, [int]$k.Width - [int]$k.MinimumWidth); if ($give -le 0) { continue }
    $k.Width = [int]$k.Width - $give; $over -= $give }
  return $true }
# The widest number (as a link) and the widest title of the pub values ("number|title") of $Rows, in pixels, measured as
# $wn.PaintPub draws them. All rows, not only the shown ones, so a filter does not move the title column.
$wn.PubWidths = { param($Rows)
  $out = @{ Num = 0; Title = 0 }   # R15: measured by $wn.TextW (the same flags), so the column plan runs off Windows too
  foreach ($r in @($Rows)) { $pp = ([string]$r.Publication).Split('|'); if ($pp.Count -lt 2) { continue }
    $out.Num = [math]::Max($out.Num, [int](& $wn.TextW $pp[0] $ui.F.Link))
    $out.Title = [math]::Max($out.Title, [int](& $wn.TextW $pp[1] $ui.F.Small)) }
  return $out }
# The width of a one-line text $Text in font $F as the grid draws it (no padding), in pixels.
$wn.TextW = { param([string]$Text, $F)
  return [Windows.Forms.TextRenderer]::MeasureText($Text, $F, ([Drawing.Size]::new(100000, 0)), [Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width }
# The head text of grid column $C as the grid draws it: its header text (H, else its name) in capitals.
$wn.HeadText = { param($C) return ($(if ($C.H) { [string]$C.H } else { [string]$C.N })).ToUpperInvariant() }
# R8 (R35 W7): the smallest width of grid column $C that shows its whole head: the head text in the head font, the cell
# padding at both sides ($wn.PaintCell) and 1 px, as $wn.PubMin does for the pub column.
# R11: a column marked HW has a head that may wrap to 2 lines: its head width is that of the wider of the 2 lines.
$wn.HeadMin = { param($C) return ((& $(if ($C.HW) { $wn.HeadWrap } else { $wn.HeadW1 }) $C) + 2 * (& $ui.Sc 10) + 1) }
# The width of the head of column $C on one line, in pixels.
$wn.HeadW1 = { param($C) return (& $wn.TextW (& $wn.HeadText $C) $ui.F.SmallB) }
# R11: the narrowest width the head of column $C shows in at most 2 lines, breaking between words: the best split into
# 2 lines, the width of its wider line; the one-line width when the head is one word.
$wn.HeadWrap = { param($C)
  $words = @((& $wn.HeadText $C) -split ' ' | Where-Object { $_ }); $best = & $wn.HeadW1 $C
  for ($i = 1; $i -lt $words.Count; $i++) {
    $a = & $wn.TextW (($words[0..($i - 1)]) -join ' ') $ui.F.SmallB; $b = & $wn.TextW (($words[$i..($words.Count - 1)]) -join ' ') $ui.F.SmallB
    $best = [math]::Min($best, [math]::Max($a, $b)) }
  return $best }
# R11 (R38): the width column $C needs for its widest value in $Rows: the text as the grid paints it (a chip: the text and
# the chip's own padding, as $wn.PaintChip draws it) plus the cell padding at both sides and 1 px (right of a chip: at least
# the width of a vertical scroll bar, so the chip never ends under it); 0 when no row has a value.
$wn.ValueMin = { param($C, $Rows)
  $f = $(if ($C.K -eq 'with' -or $C.K -eq 'bold' -or $C.K -eq 'chip') { $ui.F.SmallB } else { $ui.F.Small }); $w = 0
  foreach ($r in @($Rows)) { $t = & $wn.CellText $C $r; if ($t) { $w = [math]::Max($w, (& $wn.TextW $t $f)) } }
  if ($w -le 0) { return 0 }
  # a chip: its text, its own padding, the cell padding left and, right of it, at least a scroll bar's width
  if ($C.K -eq 'chip') { return ($w + (& $ui.Sc 20) + (& $ui.Sc 10) + [math]::Max((& $ui.Sc 10), [int](& $wn.BarW)) + 1) }
  return ($w + 2 * (& $ui.Sc 10) + 1) }
$wn.GridEdges = {
  <#
  .SYNOPSIS
  R11 (R38): where the content of a grid's cells ends, against the room before its vertical scroll bar.
  .DESCRIPTION
  For each visible column, from the left: a chip column ends at its cell's left, the cell padding and its widest chip; the
  last visible column of another kind at its left, the padding and the widest value (never past the cell less its
  padding); the other columns end inside the grid and are not measured. Edge is the largest of these. Bar is the width of a vertical scroll bar, always reserved (the bar shows or not).
  .PARAMETER G
  The grid ($wn.Grid).
  .OUTPUTS
  @{ Grid; Width (the client width); Bar; Edge; Col (the column that reaches it); Fits (R11: the grid has no chip column, or
  $wn.GridCols kept its chip whole (Tag.ChipKept); when it did not, the heads come first and the edge is not judged) }.
  #>
  param($G)
  $pd = & $ui.Sc 10; $left = 0; $edge = 0; $name = ''; $cols = @($G.Tag.Cols)
  $shown = @($G.Columns | Sort-Object DisplayIndex | Where-Object { $_.Visible }); $lastName = $(if ($shown.Count) { [string]$shown[-1].Name } else { '' })
  foreach ($k in $shown) {
    $c = @($cols | Where-Object { [string]$_.N -eq $k.Name }) | Select-Object -First 1
    if ($c.K -ne 'chip' -and [string]$k.Name -ne $lastName) { $left += $k.Width; continue }
    $f = $(if ($c.K -eq 'with' -or $c.K -eq 'bold' -or $c.K -eq 'chip') { $ui.F.SmallB } else { $ui.F.Small }); $w = 0
    foreach ($r in @($G.Tag.Shown)) { $w = [math]::Max($w, (& $wn.TextW (& $wn.CellText $c $r) $f)) }
    if ($c.K -eq 'chip') { if ($w -gt 0) { $w += & $ui.Sc 20 } }
    elseif ($c.K -eq 'pub') { $w = 0 }   # the pub column is checked by its own cut test (W1)
    $e = $left + $pd + $(if ($c.K -eq 'chip') { $w } else { [math]::Min($w, [math]::Max(0, $k.Width - 2 * $pd)) })
    if ($w -gt 0 -and $e -gt $edge) { $edge = $e; $name = [string]$k.Name }
    $left += $k.Width }
  $bar = [int](& $wn.BarW); $wd = [int]$G.ClientSize.Width
  return @{ Grid = [string]$G.AccessibleName; Width = $wd; Bar = $bar; Edge = [int]$edge; Col = $name; Fits = ($null -eq $G.Tag.ChipKept -or [bool]$G.Tag.ChipKept) } }
# R11 (R38): the LAYOUT line of grid $G when a chip or text ends closer than the scroll bar's width to the grid's right
# edge (none when it does not).
$wn.EdgeCheck = { param($G, [string]$Card)
  $e = & $wn.GridEdges $G
  if (-not $e.Fits) {   # too narrow for every head and the whole chip: the heads come first (Test-EdgeBar prints INFO); R15: but
    $sb = [int](& $wn.BarShown $G); $s = 0; foreach ($k in @($G.Columns)) { if ($k.Visible) { $s += [int]$k.Width } }   # never under a bar that shows
    if ($sb -gt 0 -and $s -gt $e.Width - $sb) { return ('LAYOUT ' + $Card + ' R15 grid ' + $e.Grid + ': the columns end at ' + $s + ', the grid is ' + $e.Width +
        ' wide with a scroll bar of ' + $sb + ' showing') }
    return $null }
  if ($e.Edge -gt $e.Width - $e.Bar) {
    return ('LAYOUT ' + $Card + ' R11 grid ' + $e.Grid + ': column ' + $e.Col + ' ends at ' + $e.Edge + ', the grid is ' + $e.Width + ' wide with a scroll bar of ' + $e.Bar) }
  return $null }
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
  $Gr.SmoothingMode = 'AntiAlias'; $path = Get-PfmRoundPath $rc ($chh / 2.0); $br = New-Object System.Drawing.SolidBrush($wn.Fills[$Kind]); $Gr.FillPath($br, $path); $br.Dispose(); $path.Dispose()
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
    if ($head) {
      $cd = @(@($tag.Cols) | Where-Object { [string]$_.N -eq [string]$S.Columns[$E.ColumnIndex].Name }) | Select-Object -First 1
      $wrapHead = [bool]($cd -and $cd.HW)   # R11: a head that wraps to 2 lines (WordBreak) and needs the width of its wider line
      [Windows.Forms.TextRenderer]::DrawText($gr, $text.ToUpperInvariant(), $ui.F.SmallB, $tr, $pc.muted, $(if ($wrapHead) { $fw } else { $fl }))
      # R7 (W1): what the head of the pub column needs and has, for the measure part and the layout self-check
      $hd = @{ Text = $text.ToUpperInvariant(); W = $(if ($wrapHead) { (& $wn.HeadWrap $cd) } else { (& $wn.TextW $text.ToUpperInvariant() $ui.F.SmallB) }); Have = $tr.Width; Kind = $kind }
      if ($kind -eq 'pub') { $tag.Head = $hd }
      if ($null -ne $tag.Heads) { $tag.Heads[[string]$S.Columns[$E.ColumnIndex].Name] = $hd } }   # R8 (W7): every head, for the same checks
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
