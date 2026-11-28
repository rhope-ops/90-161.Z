<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "keep": each card of the PFM window is built once and kept; a later open shows the kept
  card again instead of building it again (round R40; PFM 20 Nov 26, R39 finding 2).
.DESCRIPTION
  Why: in R39 every open of a card built all its controls again, 123 to 293 ms before any paint (CARDTIME), and later
  opens were no faster than first opens. A person notices a delay over about 100 ms.
  How: each card is built into its own page (a FlowLayoutPanel in the main column, $wn.NewPage). $page always names
  the page shown, so every part that reads the card on the page (layout self-check, grid fit, measure) is unchanged.
  When the window opens another card, the page shown is hidden and the kept page of that card is shown again, with
  the state the window part keeps for the card on the page ($wn.KeepLoad). A hidden page is not laid out, painted,
  checked or scrolled (Windows Forms skips controls that are not visible).
  When a card is built again (the rules, $wn.KeepSig and $wn.Show in the window part): a kept card is used only when
  it was built for the same page size (page column width and main column height), the same wide or narrow rail, the
  same scale and fonts, and the same note and error line. Showing the card that is already shown (a button note, an
  error line, a resize) always builds it again. A card whose fields the person changed (text, check boxes, choices,
  the filter) is not kept when the window leaves it ($wn.KeepLeave), so it opens clean, as a new build does. A color
  change (high contrast) or a scale pass of the measure part drops every kept card ($wn.KeepClear).
  Times (R13, R39 finding 2): for each open by the person, the build time (from the start of $wn.Show until the card
  is laid out) and the paint time (from the start of $wn.Show until the first Paint of the card's page after it); the
  CARDTIME lines at the close give both, and how many opens used a kept card.
  -Measure: $wn.MeasureKeep opens every card again after the first build and records whether the kept card was used
  and how long the open took (tests/ps/Test-T22Layout.ps1 checks it).
  Inputs: $form, $main, $page, $ui, $wn, $Cards, $lines. Outputs: the $wn members below.
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: none.
  Credentials: none.
#>
$wn.Kept = @{}   # card key -> @{ Page; Sig; Fonts; State; Grids }: the kept page of each card and what it was built for
$wn.KeepUsed = $false   # $true when the last $wn.Show used a kept card (CARDTIME kept=, -Measure)
# The state of the card on the page that the window part sets while it builds a card, kept with the card's page:
# in $wn (main button, grids, reason box, count line, crumb parts, sections, chip rows) and in $ui (the wrap widths of
# the card text boxes, the framed boxes, the title and the line under it that the layout self-check reads).
$wn.KeepWn = @('Primary', 'Gridsel', 'Gridq', 'Reason', 'CountBox', 'CountText', 'CrumbLink', 'CrumbRest', 'Secs', 'ChipRows', 'HeadH')
$wn.KeepUi = @('Wrap', 'Boxes', 'Sent', 'Kick')
$wn.Times = [ordered]@{}   # card key -> the build times in ms of each open by the person (CARDTIME first=, later-max=)
$wn.Paints = @{}           # card key -> the paint times in ms of each open, -1 until its page painted (paint-first=, paint-later-max=)
$wn.KeptN = @{}            # card key -> how many opens by the person used the kept card (kept=)
$wn.PaintWait = $null      # the open that waits for its first paint: @{ Page; Key; I (its place in Paints); T0 }
$wn.NewPage = {
  <#
  .SYNOPSIS
  Makes an empty page for one card in the main column (the settings of the first page in the main script).
  .DESCRIPTION
  A top-down flow that sizes itself to the card. Its Paint event ends the paint time of an open ($wn.Painted).
  .OUTPUTS
  The page (System.Windows.Forms.FlowLayoutPanel), added to $main.
  #>
  $p = New-Object System.Windows.Forms.FlowLayoutPanel; $p.FlowDirection = 'TopDown'; $p.WrapContents = $false; $p.AutoSize = $true
  $p.AutoSizeMode = 'GrowAndShrink'; $p.BackColor = $pc.surface
  $p.Add_Paint({ & $wn.Painted $this })
  [void]$main.Controls.Add($p)
  return $p }
# The first Paint of the page of the open that waits ($wn.PaintWait) ends its paint time; other paints do nothing.
$wn.Painted = { param($P)
  $w = $wn.PaintWait; if (-not $w -or -not [object]::ReferenceEquals($w.Page, $P)) { return }
  $wn.PaintWait = $null; $wn.Paints[$w.Key][$w.I] = [int]($ui.Clock.Elapsed.TotalMilliseconds - $w.T0) }
# What a card is built for (see the header): the page column width and main column height, wide or not, the scale,
# the note and the error line. The fonts are compared by reference ($wn.KeepFind). Takes the page column width.
$wn.KeepSig = { param([int]$Cw) return ([string]$Cw + 'x' + $wn.MainH + '|' + $wn.Wide + '|' + $ui.Dpi + '|' + $wn.Notice + '|' + $wn.Err) }
# The kept card of $Key when it was built for $Sig with the fonts in use and its page still exists, else $null.
$wn.KeepFind = { param([string]$Key, [string]$Sig)
  $e = $wn.Kept[$Key]
  if ($e -and $e.Sig -eq $Sig -and [object]::ReferenceEquals($e.Fonts, $ui.F) -and -not $e.Page.IsDisposed) { return $e }
  return $null }
$wn.KeepSave = {
  <#
  .SYNOPSIS
  Keeps the card just built on the page: the page, what it was built for, the fonts, its state and its grids.
  .PARAMETER Key
  The card key.
  .PARAMETER Sig
  What it was built for ($wn.KeepSig).
  #>
  param([string]$Key, [string]$Sig)
  $st = @{}; foreach ($n in $wn.KeepWn) { $st['wn.' + $n] = $wn[$n] }; foreach ($n in $wn.KeepUi) { $st['ui.' + $n] = $ui[$n] }
  $gs = New-Object System.Collections.Generic.List[object]; $todo = New-Object System.Collections.Stack; $todo.Push($page)
  while ($todo.Count) { foreach ($c in $todo.Pop().Controls) { if ($c -is [Windows.Forms.DataGridView]) { $gs.Add($c) } elseif ($c.Controls.Count) { $todo.Push($c) } } }
  $wn.Kept[$Key] = @{ Page = $page; Sig = $Sig; Fonts = $ui.F; State = $st; Grids = $gs.ToArray() } }
# Puts back the state of kept card $E ($wn.KeepSave) for the card on the page.
$wn.KeepLoad = { param($E)
  foreach ($n in $wn.KeepWn) { $wn[$n] = $E.State['wn.' + $n] }; foreach ($n in $wn.KeepUi) { $ui[$n] = $E.State['ui.' + $n] } }
# A kept card shown again starts as a new build does: no grid row selected, each grid at its first row.
$wn.KeepReset = { param($E)
  foreach ($g in @($E.Grids)) { try { $g.ClearSelection(); if ($g.RowCount -gt 0) { $g.FirstDisplayedScrollingRowIndex = 0 } } catch { $null = $_ } } }
# True when page $P is the page of a kept card.
$wn.IsKept = { param($P) foreach ($e in @($wn.Kept.Values)) { if ([object]::ReferenceEquals($e.Page, $P)) { return $true } }; return $false }
# Forgets the kept card of $Key. Its page goes now when it is hidden; the page shown goes when the next page replaces it
# ($wn.PageSwap), so the controls of the page shown are never disposed under it.
$wn.KeepDrop = { param([string]$Key)
  $e = $wn.Kept[$Key]; if (-not $e) { return }
  $wn.Kept.Remove($Key)
  if (-not [object]::ReferenceEquals($e.Page, $page) -and -not $e.Page.IsDisposed) { [void]$main.Controls.Remove($e.Page); $e.Page.Dispose() } }
# Forgets every kept card (a color change, a scale pass of the measure part): the next open of each card builds it.
$wn.KeepClear = { foreach ($k in @($wn.Kept.Keys)) { & $wn.KeepDrop $k } }
# The window leaves the card on the page: when the person changed one of its fields, it is not kept (it opens clean).
$wn.KeepLeave = { if ($wn.Cur -and @($wn.Field.Keys).Count) { & $wn.KeepDrop $wn.Cur } }
$wn.PageSwap = {
  <#
  .SYNOPSIS
  Shows page $New in place of the page shown: the page shown is hidden when it is kept, else removed and disposed.
  .DESCRIPTION
  $page names the page shown from here on (every part reads the card on the page through it).
  .PARAMETER New
  The page to show (a new page, or the page of a kept card).
  #>
  param($New)
  $old = $page
  if ([object]::ReferenceEquals($old, $New)) { return }
  if ($old -and -not $old.IsDisposed) {
    $old.Visible = $false
    if (-not (& $wn.IsKept $old)) { [void]$main.Controls.Remove($old); $old.Dispose() } }
  $script:page = $New; $New.Visible = $true }
$wn.KeepTime = {
  <#
  .SYNOPSIS
  Notes one open by the person: its build time now, and its paint time when its page first paints ($wn.Painted).
  .PARAMETER Key
  The card key.
  .PARAMETER T0
  When $wn.Show started ($ui.Clock, ms).
  #>
  param([string]$Key, [double]$T0)
  if (-not $wn.Times.Contains($Key)) { $wn.Times[$Key] = New-Object System.Collections.Generic.List[int]; $wn.Paints[$Key] = New-Object System.Collections.Generic.List[int]; $wn.KeptN[$Key] = 0 }
  $wn.Times[$Key].Add([int]($ui.Clock.Elapsed.TotalMilliseconds - $T0)); $wn.Paints[$Key].Add(-1)
  if ($wn.KeepUsed) { $wn.KeptN[$Key]++ }
  $wn.PaintWait = @{ Page = $page; Key = $Key; I = $wn.Paints[$Key].Count - 1; T0 = $T0 }; $page.Invalidate() }
$wn.TimeLines = {
  <#
  .SYNOPSIS
  R12 (R38 finding 3), R13 (R39 finding 2): one CARDTIME line for each card the person opened.
  .DESCRIPTION
  first= and later-max=: the build time of the first open and the slowest later open, in ms (as r12). paint-first= and
  paint-later-max=: the same for the paint time (none: the page did not paint before the next open or the close).
  opens=: the opens; kept=: the opens that showed the kept card.
  #>
  foreach ($k in @($wn.Times.Keys)) { $v = @($wn.Times[$k]); $p = @($wn.Paints[$k])
    $later = $(if ($v.Count -gt 1) { ' later-max=' + (@($v | Select-Object -Skip 1 | Measure-Object -Maximum).Maximum) } else { '' })
    $pl = @($p | Select-Object -Skip 1 | Where-Object { $_ -ge 0 })
    $pf = ' paint-first=' + $(if ($p[0] -ge 0) { $p[0] } else { 'none' })
    $plm = $(if ($v.Count -gt 1) { ' paint-later-max=' + $(if ($pl.Count) { (@($pl | Measure-Object -Maximum).Maximum) } else { 'none' }) } else { '' })
    $lines.Add('CARDTIME ' + $k + ' first=' + $v[0] + $later + $pf + $plm + ' opens=' + $v.Count + ' kept=' + $wn.KeptN[$k] +
      ' (ms from the open: build until laid out, paint until its first paint; a resize counts as an open)') }
  if (-not $wn.Times.Count) { $lines.Add('CARDTIME none (no card opened after the start)') } }
$wn.MeasureKeep = {
  <#
  .SYNOPSIS
  The -Measure run: opens every card once more after the first build and records whether its kept card was used.
  .DESCRIPTION
  Runs after $wn.Build (every card built and kept at this size). The card on the page goes last: showing the card that
  is shown builds it again (the window part's rule), so it is opened after another card, as a person opens it. Then
  Your Work is shown again.
  .OUTPUTS
  One table per card: Key, Kept (the kept card was shown), Ms (the open, from the start of $wn.Show until it returned).
  #>
  $out = New-Object System.Collections.Generic.List[object]
  foreach ($k in @(@($Cards.Keys | Where-Object { $_ -ne $wn.Cur }) + @($wn.Cur))) {
    $wn.Notice = ''; $wn.Err = ''; $t0 = $ui.Clock.Elapsed.TotalMilliseconds; & $wn.Show $k
    $r = [ordered]@{}; $r['Key'] = [string]$k; $r['Kept'] = [bool]$wn.KeepUsed; $r['Ms'] = [int]($ui.Clock.Elapsed.TotalMilliseconds - $t0); $out.Add($r)
    [Windows.Forms.Application]::DoEvents() }
  $wn.Notice = ''; $wn.Err = ''; & $wn.Show 'home'
  return $out.ToArray() }
