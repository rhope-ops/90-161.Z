<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "measure": the script's own accessible-name check (the RESULT NAMES line) and the -Measure
  run, which builds every card off-screen and writes what it measured as JSON for tests/ps/Test-T22Layout.ps1.
.DESCRIPTION
  R13 (R40): the measure file has Keep (each card opened again from its kept page, $wn.MeasureKeep in the keep part).
  R11 (R38; PFM 20 Nov 26): the measure file has Edges (the right edge of each grid) and one Fulcrum logo (Theme.Fulcrum, ShownDiff).
  Names (R30 fallback for check 8, Narrator names): every button, link, check box, choice, text box and list of every
  card, the rail and the check bar must have an accessible name; the result is one line "RESULT NAMES PASS" or
  "RESULT NAMES FAIL (<n> controls: <card>/<type> "<text>", ...)".
  Measure (-Measure <file>): the window is built at 1280 x 720 far off the screen and never shown to a person; for each
  card it records the crumb (fonts, bounds, the ink gap after the link: R30 V2), every button (its color and the color
  of its face as drawn: V4) and every section card (its bottom: V4). R31: it also records the rail head at this scale
  and at 1.5 x (W1: the logo's middle and the name's middle, the color behind the logo) and the colors that
  Select-T22Color gives with high contrast on and off (W2). No question; no file but the given one and the card
  pictures next to it.
  Level (R6, R31b D1 to D4): $wn.LevelFacts gives, for the card on the page, the middles of each Action Status caption
  and the main card's first line (D1), of the crumb's link and rest with their font sizes (D2), of each check chip and
  its first text line (D3), and where each pub grid drew its numbers and titles (D4). -Measure records them for every
  card at this scale and again at 1.25 x and 1.5 x ($wn.MeasureScaled); the layout self-check turns them into LAYOUT lines
  ($ui.Measure, $wn.LevelBad), so the window flags the 4 defects on the device too.
  R7 (R32 W1 to W3): the level facts also hold every chip beside text with its kind (W3) and, for each pub grid, what
  its head and each cell needed and had (W1); the self-check writes a W1 or W3 LAYOUT line for each one out of line.
  $wn.MeasureWheel turns the mouse wheel through the window's own wheel handlers with no real pointer (W2).
  R8 (R35 W7): $wn.LogoFacts and $wn.LogoBad check the rail logo's colors each time the rail is built (the window
  part calls them); $wn.MeasureLogo rebuilds the window with high contrast on and off and records the logo facts.
  Card pictures (R31 W4): $wn.SavePng saves the window as it shows a card, 90161Z-T22-card-<card>-r21.png, in
  $wn.PngDir (the T22 folder in a normal run, the folder of the measure file with -Measure); $wn.PngLines adds the
  CARDPNG lines to the result. The cards hold FAKE data or (R14) fake rows of the test site; a card with a site row that
  has no fake-data marker gets no picture. A picture that cannot be saved is a NOTE line.
  Inputs: $form, $page, $rail, $pc, $ui, $wn, $Cards, $Rev, $lines. Outputs: $wn.NoName, $wn.NamesLine, $wn.SavePng,
  $wn.PngLines, $wn.LevelFacts, $wn.LevelBad, $wn.PubCut, $ui.Measure, $wn.MeasureWheel, $wn.LogoFacts, $wn.LogoBad,
  $wn.MeasureLogo, $wn.MeasureRun and its helpers.
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: the card PNG files in $wn.PngDir (the T22 folder, or -TestDir); with -Measure: the JSON file given and the
  card PNG files in its folder (the test gives a file in its own temporary folder).
  Credentials: none.
#>
$wn.NoName = [ordered]@{}; $wn.Scanned = $false
$wn.PngDir = ''; $wn.Pngs = New-Object System.Collections.Generic.List[string]
$wn.SavePng = {
  <#
  .SYNOPSIS
  Saves a picture of the window as it shows card $Key (R31 W4): 90161Z-T22-card-<key>-r21.png in $wn.PngDir.
  .DESCRIPTION
  Control.DrawToBitmap at the window's current size; nothing when $wn.PngDir is empty. A picture that cannot be
  saved is a NOTE line in the result, not a stop. The file name is kept in $wn.Pngs.
  R14 (R41): no picture of a card that shows a site row without a fake-data marker (Get-SiteUnmarked, site part); a
  CARDPNG line says so.
  .PARAMETER Key
  The card key (the card on the page).
  #>
  param([string]$Key)
  if (-not $wn.PngDir) { return }
  $name = '90161Z-T22-card-' + $Key + '-' + $Rev + '.png'
  # R14 (R41; PFM 20 Nov 26): a card that shows a site row with no fake-data marker gets no picture (the site part)
  $bad = Get-SiteUnmarked $Key
  if ($bad -gt 0) { $lines.Add('CARDPNG ' + $Key + ' not saved: ' + $bad + ' site rows without a fake-data marker'); return }
  try {
    $bm = New-Object System.Drawing.Bitmap([math]::Max(1, $form.Width), [math]::Max(1, $form.Height))
    try {
      $form.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $bm.Width, $bm.Height)))
      $bm.Save((Join-Path $wn.PngDir $name), [System.Drawing.Imaging.ImageFormat]::Png); $wn.Pngs.Add($name)
    } finally { $bm.Dispose() }
  } catch { $lines.Add('NOTE card picture not saved: ' + $name + ' (' + ([string]$_.Exception.Message) + ')') } }
# The CARDPNG lines of the result: how many card pictures were saved of how many cards, then one line per file name.
$wn.PngLines = {
  if (-not $wn.PngDir) { return }
  $lines.Add('CARDPNG saved=' + $wn.Pngs.Count + ' of ' + $Cards.Count)
  foreach ($n in $wn.Pngs) { $lines.Add('CARDPNG ' + $n) } }
$wn.NameScan = {
  <#
  .SYNOPSIS
  Notes each button, link, check box, choice, text box and list under $Root that has no accessible name.
  .PARAMETER Card
  The card key (or rail, bar) the controls belong to; it starts each note.
  .PARAMETER Root
  The control whose children are read (the page, the rail or the check bar).
  #>
  param([string]$Card, $Root)
  if (-not $Root) { return }
  $wn.Scanned = $true; $st = New-Object System.Collections.Stack; $st.Push($Root)
  while ($st.Count) {
    foreach ($c in $st.Pop().Controls) {
      $named = ($c -is [Windows.Forms.ButtonBase] -or $c -is [Windows.Forms.TextBoxBase] -or $c -is [Windows.Forms.ComboBox])
      if ($named -and -not ([string]$c.AccessibleName).Trim()) {
        $t = ([string]$c.Text).Trim(); if ($t.Length -gt 24) { $t = $t.Substring(0, 24) + '...' }
        $wn.NoName[$Card + '/' + $c.GetType().Name + ' "' + $t + '"'] = 1 }
      if ($c.Controls.Count) { $st.Push($c) } } } }
# The RESULT NAMES line: PASS, or FAIL with the number of controls without a name and which ones.
$wn.NamesLine = {
  if ($wn.NoName.Count -eq 0) { return 'RESULT NAMES PASS' }
  return ('RESULT NAMES FAIL (' + $wn.NoName.Count + ' controls: ' + (@($wn.NoName.Keys) -join ', ') + ')') }
$wn.InkSpan = {
  <#
  .SYNOPSIS
  Where the ink of a control starts and ends, left to right, as drawn.
  .DESCRIPTION
  Draws the control into a bitmap and finds the first and the last pixel column that differs from its background by
  more than 90 (the RADE ink rule, $ui.Ink: the sum of the red, green and blue distances).
  .PARAMETER C
  The control.
  .OUTPUTS
  @{ First; Last } in the control's own pixels; -1 when nothing was drawn.
  #>
  param($C)
  $out = @{ First = -1; Last = -1 }
  try {
    $w = [math]::Max(1, $C.Width); $h = [math]::Max(1, $C.Height); $bm = New-Object System.Drawing.Bitmap($w, $h)
    try {
      $C.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $w, $h))); $bg = $C.BackColor
      for ($x = 0; $x -lt $w; $x++) {
        for ($y = 0; $y -lt $h; $y++) {
          $p = $bm.GetPixel($x, $y)
          if ([math]::Abs($p.R - $bg.R) + [math]::Abs($p.G - $bg.G) + [math]::Abs($p.B - $bg.B) -gt 90) { if ($out.First -lt 0) { $out.First = $x }; $out.Last = $x; break } } }
    } finally { $bm.Dispose() }
  } catch { $null = $_ }
  return $out }
# A color as #RRGGBB.
$wn.Hex = { param($Color) return ('#{0:X2}{1:X2}{2:X2}' -f $Color.R, $Color.G, $Color.B) }
# The color of a button's face as drawn: the pixel 6 px right of and 4 px under its top left corner (inside its edge, above its text).
$wn.FaceColor = { param($B)
  try {
    $bm = New-Object System.Drawing.Bitmap([math]::Max(1, $B.Width), [math]::Max(1, $B.Height))
    try { $B.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $bm.Width, $bm.Height))); return (& $wn.Hex $bm.GetPixel((& $wn.Sc 6), (& $wn.Sc 4))) } finally { $bm.Dispose() }
  } catch { return '' } }
# A font as a table: name, size in points, style and height in pixels.
$wn.FontFacts = { param($F) return [ordered]@{ Name = $F.Name; Size = [double]$F.SizeInPoints; Style = [string]$F.Style; Height = [int]$F.Height } }
$wn.MeasureCrumb = {
  <#
  .SYNOPSIS
  The crumb of the card on the page: its link and rest, their fonts and bounds, and the gap after the link.
  .DESCRIPTION
  GapInk: the empty pixel columns between the last ink of the link (its underline ends with its text) and the first ink
  of the rest (the arrow), as drawn. GapBounds: the distance between the two controls.
  .OUTPUTS
  A table, or $null when the card has no crumb link.
  #>
  $l = $wn.CrumbLink; $t = $wn.CrumbRest; if (-not $l -or -not $t) { return $null }
  $li = & $wn.InkSpan $l; $ti = & $wn.InkSpan $t
  $gap = $(if ($li.Last -ge 0 -and $ti.First -ge 0) { ($t.Left + $ti.First) - ($l.Left + $li.Last) - 1 } else { $null })
  return [ordered]@{ Link = [string]$l.Text; Rest = [string]$t.Text; LinkFont = (& $wn.FontFacts $l.Font); RestFont = (& $wn.FontFacts $t.Font)
    LinkBounds = [string]$l.Bounds; RestBounds = [string]$t.Bounds; LinkInk = $li.Last; RestInk = $ti.First; GapBounds = ($t.Left - $l.Right); GapInk = $gap } }
$wn.LevelPubs = {
  <#
  .SYNOPSIS
  R6 (R31b D4): where each grid with a pub column on the page drew its numbers and titles.
  .DESCRIPTION
  Each such grid is drawn once into a bitmap (so its cells are painted now, also off-screen); $wn.PaintPub keeps what
  it drew in the grid's Tag.Drawn, relative to the cell's text rectangle. Rows that are scrolled out of the grid are
  not drawn and not listed.
  R7 (R32 W1): also the head of the pub column (its text, the width it needs and has) and, per row drawn, the widths
  and heights the number and title needed and had ($wn.PaintPub).
  .OUTPUTS
  One table per grid: Grid (its name), Gap (the gap after the widest number), Rows (rows drawn), Head, HeadW, HeadHave
  and, one value per row drawn, Beside, TitleX, NumRight, NumBottom, TitleTop, NumW, NumHave, TitleW, TitleHave, NeedH
  and HaveH.
  #>
  $out = New-Object System.Collections.Generic.List[object]; $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) {
    foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.DataGridView]) {
        if (-not ($c.Tag -is [hashtable]) -or -not (@($c.Tag.Kind.Values) -contains 'pub')) { continue }
        $c.Tag.Drawn = @{}; $c.Tag.Head = $null
        try { $bm = New-Object System.Drawing.Bitmap([math]::Max(1, $c.Width), [math]::Max(1, $c.Height))
          try { $c.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $bm.Width, $bm.Height))) } finally { $bm.Dispose() } } catch { $null = $_ }
        $d = @(foreach ($k in @($c.Tag.Drawn.Keys | Sort-Object)) { $c.Tag.Drawn[$k] })
        $g = [ordered]@{}; $g['Grid'] = [string]$c.AccessibleName; $g['Gap'] = [int]$c.Tag.PubGap; $g['Rows'] = $d.Count
        $h = $c.Tag.Head; $g['Head'] = $(if ($h) { [string]$h.Text } else { '' }); $g['HeadW'] = $(if ($h) { [int]$h.W } else { 0 }); $g['HeadHave'] = $(if ($h) { [int]$h.Have } else { 0 })
        foreach ($n in 'Beside', 'TitleX', 'NumRight', 'NumBottom', 'TitleTop', 'NumW', 'NumHave', 'TitleW', 'TitleHave', 'NeedH', 'HaveH') { $g[$n] = @($d | ForEach-Object { $_[$n] }) }
        $out.Add($g) }
      elseif ($c.Controls.Count) { $st.Push($c) } } }
  return $out.ToArray() }
$wn.LevelHeads = {
  <#
  .SYNOPSIS
  R8 (R35 W7, R34 open point 5): the column heads of every grid on the page, as the grid drew them.
  .DESCRIPTION
  Each grid is drawn once into a bitmap (so its head is painted now, also off-screen); $wn.PaintCell keeps each head
  it drew in the grid's Tag.Heads: its text in capitals, the width it needs and the width its cell gave it.
  .OUTPUTS
  One table per head: Grid (its name), Col (the column name), Kind, Head (the text), W (needed) and Have.
  #>
  $out = New-Object System.Collections.Generic.List[object]; $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) {
    foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.DataGridView]) {
        if (-not ($c.Tag -is [hashtable])) { continue }
        $c.Tag.Heads = [ordered]@{}
        try { $bm = New-Object System.Drawing.Bitmap([math]::Max(1, $c.Width), [math]::Max(1, $c.Height))
          try { $c.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $bm.Width, $bm.Height))) } finally { $bm.Dispose() } } catch { $null = $_ }
        foreach ($k in @($c.Tag.Heads.Keys)) { $h = $c.Tag.Heads[$k]
          $r = [ordered]@{}; $r['Grid'] = [string]$c.AccessibleName; $r['Col'] = [string]$k; $r['Kind'] = [string]$h.Kind; $r['Head'] = [string]$h.Text
          $r['W'] = [int]$h.W; $r['Have'] = [int]$h.Have; $out.Add($r) } }
      elseif ($c.Controls.Count) { $st.Push($c) } } }
  return $out.ToArray() }
$wn.LevelEdges = {
  <#
  .SYNOPSIS
  R11 (R38): where the chips and last-column text of every grid on the page end, against the grid's right edge.
  .OUTPUTS
  One table per grid ($wn.GridEdges): Grid, Width, Bar, Edge, Col, Fits.
  #>
  $out = New-Object System.Collections.Generic.List[object]; $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) {
    foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.DataGridView]) { if ($c.Tag -is [hashtable]) { $out.Add((& $wn.GridEdges $c)) } }
      elseif ($c.Controls.Count) { $st.Push($c) } } }
  return $out.ToArray() }
$wn.LevelFacts = {
  <#
  .SYNOPSIS
  R6 (R31b D1 to D4): the alignment facts of the card on the page, in page pixels ($wn.TextMid).
  .DESCRIPTION
  Caps (D1): for each Action Status card, the middle of its caption and of the first line of the main card. Crumb (D2):
  the font size and text middle of the crumb's link and rest, or $null when the card has no crumb link. Chips (D3, R7
  W3): for each chip beside text ($wn.ChipRows: check, list, rows, chips, notice), its kind, the middle of the chip and
  of the first line of its text. Pubs (D4, R7 W1): $wn.LevelPubs. Heads (R8 W7): $wn.LevelHeads.
  .OUTPUTS
  A table: Caps, Crumb, Chips, Pubs, Heads, Edges (R11: $wn.LevelEdges).
  #>
  $mainSec = @($wn.Secs | Where-Object { $_.Col -eq 0 }) | Select-Object -First 1
  $line = $(if ($mainSec) { & $wn.FirstLine $mainSec.Card } else { $null })
  $caps = @(foreach ($s in @($wn.Secs | Where-Object { $_.Stretch -and $_.CapBox -and $line })) {
      $c = [ordered]@{}; $c['Cap'] = [string]$s.CapBox.Text; $c['CapMid'] = (& $wn.TextMid $s.CapBox); $c['Line'] = [string]$line.Text; $c['LineMid'] = (& $wn.TextMid $line); $c })
  $crumb = $null; $l = $wn.CrumbLink; $t = $wn.CrumbRest
  if ($l -and $t) { $crumb = [ordered]@{}; $crumb['LinkSize'] = [double]$l.Font.SizeInPoints; $crumb['RestSize'] = [double]$t.Font.SizeInPoints
    $crumb['LinkMid'] = (& $wn.TextMid $l); $crumb['RestMid'] = (& $wn.TextMid $t) }
  $chips = @(foreach ($r in @($wn.ChipRows)) {
      $c = [ordered]@{}; $c['Chip'] = [string]$r.Chip.Text; $c['Kind'] = [string]$r.Kind; $c['ChipMid'] = (& $wn.TextMid $r.Chip)
      # R48: a list or rows chip is compared with the middle of its row (Ref 'row'); every other chip with its text's first line.
      $c['Ref'] = $(if ($r.Row) { 'row' } else { 'first line' }); $c['Line'] = [string]$r.Text.Text
      $c['LineMid'] = $(if ($r.Row) { (& $wn.PageTop $r.Row) + $r.Row.Height / 2.0 } else { (& $wn.TextMid $r.Text) }); $c })
  $f = [ordered]@{}; $f['Caps'] = $caps; $f['Crumb'] = $crumb; $f['Chips'] = $chips; $f['Pubs'] = @(& $wn.LevelPubs); $f['Heads'] = @(& $wn.LevelHeads); $f['Edges'] = @(& $wn.LevelEdges)
  return $f }
# R7 (W1): the cut cells of one measured pub grid $P ($wn.LevelPubs), one short text per row: "row <n> number 120>96"
# when its number, title or lines needed more pixels than the cell gave; none when every cell holds its text.
$wn.PubCut = { param($P)
  $out = @(); $nw = @($P.NumW); $nh = @($P.NumHave); $tw = @($P.TitleW); $th = @($P.TitleHave); $lh = @($P.NeedH); $ch = @($P.HaveH)
  for ($i = 0; $i -lt [int]$P.Rows; $i++) {
    $bad = @(); if ([int]$nw[$i] -gt [int]$nh[$i]) { $bad += ('number ' + $nw[$i] + '>' + $nh[$i]) }
    if ([int]$tw[$i] -gt [int]$th[$i]) { $bad += ('title ' + $tw[$i] + '>' + $th[$i]) }
    if ([int]$lh[$i] -gt [int]$ch[$i]) { $bad += ('height ' + $lh[$i] + '>' + $ch[$i]) }
    if ($bad.Count) { $out += ('row ' + ($i + 1) + ' ' + ($bad -join ', ')) } }
  return $out }
$wn.LevelBad = {
  <#
  .SYNOPSIS
  The LAYOUT lines of the layout self-check for D1 to D4 (R6): each fact of $wn.LevelFacts that is out of line.
  .DESCRIPTION
  D1, D2 and D3: two middles more than $Tol apart (D2 also: two font sizes). D4: the titles of a grid start at more than
  one x, or a title in the column starts before the end of the widest number and the gap, or a title under its number
  starts above the number's bottom. A grid with no row drawn has nothing to compare.
  R7 (R32): W1: the head of a pub column needs more width than it has (it would be shortened with dots), or a pub cell
  is cut (its number or title needs more width, or its lines more height, than the cell gave). W3: the D3 rule for
  every chip beside text; the line names the chip's kind.
  R8 (R35 W7): a column head other than the pub head (W1 has that one) needs more width than it has: one line per grid
  that names each cut head.
  .PARAMETER Card
  The card key (it starts each line).
  .PARAMETER F
  The facts ($wn.LevelFacts).
  .PARAMETER Tol
  The tolerance in pixels: 1 px at 100 %, scaled.
  .OUTPUTS
  The LAYOUT lines (none when all is in line).
  #>
  param([string]$Card, $F, [double]$Tol)
  $out = @()
  foreach ($c in @($F.Caps)) { if ([math]::Abs($c.CapMid - $c.LineMid) -gt $Tol) {
      $out += ('LAYOUT ' + $Card + ' D1 caption "' + $c.Cap + '" middle ' + $c.CapMid + ', the first line of the main card ' + $c.LineMid) } }
  $k = $F.Crumb
  if ($k -and ($k.LinkSize -ne $k.RestSize -or [math]::Abs($k.LinkMid - $k.RestMid) -gt $Tol)) {
    $out += ('LAYOUT ' + $Card + ' D2 crumb: link ' + $k.LinkSize + ' pt middle ' + $k.LinkMid + ', rest ' + $k.RestSize + ' pt middle ' + $k.RestMid) }
  foreach ($c in @($F.Chips)) { if ([math]::Abs($c.ChipMid - $c.LineMid) -gt $Tol) {
      $out += ('LAYOUT ' + $Card + ' W3 chip "' + $c.Chip + '" (' + $c.Kind + ') middle ' + $c.ChipMid + ', its ' + $c.Ref + ' middle ' + $c.LineMid) } }
  foreach ($p in @($F.Pubs)) {
    if ($p.Head -and [int]$p.HeadW -gt [int]$p.HeadHave) {
      $out += ('LAYOUT ' + $Card + ' W1 grid ' + $p.Grid + ': the head "' + $p.Head + '" needs ' + $p.HeadW + ' px, has ' + $p.HeadHave) }
    $cut = @(& $wn.PubCut $p)
    if ($cut.Count) { $out += ('LAYOUT ' + $Card + ' W1 grid ' + $p.Grid + ': ' + $cut.Count + ' publication cells cut (' + ($cut -join '; ') + ')') }
    if ([int]$p.Rows -lt 1) { continue }
    $xs = @($p.TitleX | Sort-Object -Unique); $num = [int](@($p.NumRight) | Measure-Object -Maximum).Maximum
    $under = @(for ($i = 0; $i -lt [int]$p.Rows; $i++) { if (-not $p.Beside[$i] -and $p.TitleTop[$i] -lt $p.NumBottom[$i]) { $i } })
    if ($xs.Count -gt 1) { $out += ('LAYOUT ' + $Card + ' D4 grid ' + $p.Grid + ': the titles start at ' + ($xs -join ', ')) }
    elseif ((@($p.Beside) -contains $true) -and [int]$xs[0] -lt $num + [int]$p.Gap) {
      $out += ('LAYOUT ' + $Card + ' D4 grid ' + $p.Grid + ': the titles start at ' + $xs[0] + ', the widest number ends at ' + $num) }
    elseif ($under.Count) { $out += ('LAYOUT ' + $Card + ' D4 grid ' + $p.Grid + ': ' + $under.Count + ' titles start above the bottom of their number') } }
  $cut = @($F.Heads | Where-Object { $_ -and [string]$_.Kind -ne 'pub' -and [int]$_.W -gt [int]$_.Have })
  foreach ($g in @($cut | ForEach-Object { [string]$_.Grid } | Sort-Object -Unique)) {
    $list = @($cut | Where-Object { [string]$_.Grid -eq $g } | ForEach-Object { '"' + $_.Head + '" needs ' + $_.W + ' px, has ' + $_.Have })
    $out += ('LAYOUT ' + $Card + ' W7 grid ' + $g + ': ' + $list.Count + ' column heads cut (' + ($list -join '; ') + ')') }
  return $out }
# The self-check's extra lines (the rade-ui block calls $ui.Measure for each card it checks): D1 to D4, 1 px at 100 %.
$ui.Measure = { param($Card) return @(& $wn.LevelBad $Card (& $wn.LevelFacts) ([math]::Max(1.0, $ui.Dpi / 96.0))) }
$wn.MeasureCard = {
  <#
  .SYNOPSIS
  What -Measure records for the card on the page: the crumb, every button and link, every section card, and the
  alignment facts of D1 to D4 (R6).
  .PARAMETER Key
  The card key.
  .OUTPUTS
  A table: Key, Crumb, Buttons (Text, Link, Back, Face, Edge), Sections (Col, Cap, Stretch, Top, Bottom; page pixels),
  Level ($wn.LevelFacts).
  #>
  param([string]$Key)
  $btns = New-Object System.Collections.Generic.List[object]; $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) {
    foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.Button]) {
        $b = [ordered]@{}; $b['Text'] = [string]$c.Text; $b['Link'] = ([int]$c.FlatAppearance.BorderSize -eq 0)
        $b['Back'] = (& $wn.Hex $c.BackColor); $b['Face'] = (& $wn.FaceColor $c); $b['Edge'] = (& $wn.Hex $c.FlatAppearance.BorderColor)
        $btns.Add($b) }
      if ($c.Controls.Count) { $st.Push($c) } } }
  $pt = $page.RectangleToScreen($page.ClientRectangle).Top
  $secs = @(foreach ($s in $wn.Secs) { $r = $s.Card.RectangleToScreen($s.Card.ClientRectangle)
      [ordered]@{ Col = $s.Col; Cap = $s.Cap; Stretch = $s.Stretch; Top = ($r.Top - $pt); Bottom = ($r.Bottom - $pt) } })
  # One key per statement: Windows PowerShell 5.1 stops on an [ordered] literal that holds a generic list (R30 CI).
  $card = [ordered]@{}; $card['Key'] = $Key; $card['Crumb'] = (& $wn.MeasureCrumb)
  $card['Buttons'] = $btns.ToArray(); $card['Sections'] = $secs; $card['Level'] = (& $wn.LevelFacts)
  return $card }
$wn.MeasureScaled = {
  <#
  .SYNOPSIS
  Builds every card again at $K times this scale and gives back the alignment facts of D1 to D4 of each (R6).
  .DESCRIPTION
  As $wn.MeasureHead does for the rail head: the scale ($ui.Dpi), the font factor and every font of $ui.F (with the
  crumb font and the step fonts made from them) are $K times as large, as Windows makes them at that scale. Each card is
  shown and measured ($wn.LevelFacts); a card that cannot be measured keeps its error. Then the scale and the fonts come
  back, Your Work is shown again and the scaled fonts are disposed.
  .PARAMETER K
  The factor (1.5: the PFM's 150 %).
  .OUTPUTS
  A table: K, Dpi, Sc8 (8 px at 100 %, at this scale), Cards (Key, Level or Error) and (R7 W2) Wheel ($wn.MeasureWheel)
  or WheelError.
  #>
  param([double]$K)
  $keep = @{ Dpi = $ui.Dpi; FontK = $ui.FontK; F = $ui.F; Crumb = $wn.CrumbFont; Step = $wn.StepFonts }
  $made = New-Object System.Collections.Generic.List[object]; $cards = New-Object System.Collections.Generic.List[object]; $res = [ordered]@{}
  try {
    $nf = @{}; foreach ($n in @($keep.F.Keys)) { $o = $keep.F[$n]; $x = New-Object System.Drawing.Font($o.FontFamily, [single]($o.Size * $K), $o.Style); $nf[$n] = $x; $made.Add($x) }
    $ui.Dpi = $keep.Dpi * $K; $ui.FontK = $keep.FontK * $K; $ui.F = $nf; $wn.StepFonts = $null
    $wn.CrumbFont = New-Object System.Drawing.Font($nf.Small, [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Underline')); $made.Add($wn.CrumbFont)
    $res['K'] = $K; $res['Dpi'] = $ui.Dpi; $res['Sc8'] = (& $wn.Sc 8)
    foreach ($key in $Cards.Keys) {
      $c = [ordered]@{}; $c['Key'] = $key
      try { $wn.Notice = ''; $wn.Err = ''; & $wn.Show $key; [Windows.Forms.Application]::DoEvents(); $c['Level'] = (& $wn.LevelFacts); $c['Btn'] = @(& $wn.BtnLines) }
      catch { $c['Error'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
      $cards.Add($c) }
    # R7 (W2): the mouse wheel at this scale too; a wheel case that cannot run is kept as its error (the test names it).
    try { $res['Wheel'] = (& $wn.MeasureWheel) } catch { $res['Wheel'] = $null; $res['WheelError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  } finally {
    if ($wn.StepFonts -and -not [object]::ReferenceEquals($wn.StepFonts, $keep.Step)) { foreach ($x in @($wn.StepFonts.A) + @($wn.StepFonts.B)) { $made.Add($x) } }
    $ui.Dpi = $keep.Dpi; $ui.FontK = $keep.FontK; $ui.F = $keep.F; $wn.CrumbFont = $keep.Crumb; $wn.StepFonts = $keep.Step
    & $wn.KeepClear; $wn.Notice = ''; $wn.Err = ''; & $wn.Show 'home'   # R13: no kept card keeps the scaled fonts disposed below
    foreach ($x in $made) { try { $x.Dispose() } catch { $null = $_ } } }
  $res['Cards'] = $cards.ToArray()
  return $res }
# R11 (R38; UI standard v1, B1): the B1 lines ($ui.BtnBad) of every shown RADE button of the page, at the scale in use
# (the self-check runs at the window's own scale only; this one runs at 1.25 x and 1.5 x too). None when all are right.
$wn.BtnLines = {
  $out = New-Object System.Collections.Generic.List[string]; $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) { foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.Button] -and $c.Visible -and $ui.BtnKind.ContainsKey($c)) { foreach ($l in @(& $ui.BtnBad 'scaled' ([string]$c.AccessibleName) $c)) { $out.Add([string]$l) } }
      elseif ($c.Controls.Count) { $st.Push($c) } } }
  return $out.ToArray() }
$wn.LogoFacts = {
  <#
  .SYNOPSIS
  R8 (R35 W7): what the rail logo shows now, for the self-check and the measure part.
  .OUTPUTS
  A table: High (the colors in use: $ui.High), Shown (a logo is on the rail), Other (its pixels with any cover that are
  neither of the 2 system colors of $wn.LogoRole) and Diff (its pixels that differ from the logo in its own colors);
  -1 when no logo is shown.
  #>
  $f = [ordered]@{}; $f['High'] = [bool]$ui.High; $f['Shown'] = $false; $f['Other'] = -1; $f['Diff'] = -1
  $lg = $wn.Logo; if (-not $lg -or -not $lg.Image) { return $f }
  $own = & $wn.LogoImage $false; $d = [string]$wn.LogoRole.Dark; $l = [string]$wn.LogoRole.Light
  try { $f['Shown'] = $true; $f['Other'] = (Get-PfmOtherCount $lg.Image ([Drawing.SystemColors]::$d) ([Drawing.SystemColors]::$l)); $f['Diff'] = (Get-PfmPixelDiff $lg.Image $own) }
  finally { $own.Dispose() }
  return $f }
# R8 (R35 W7): the LAYOUT line for logo facts $F ($wn.LogoFacts) with the wrong colors, or none: with high contrast on,
# a pixel in another color or no change from the own colors; with it off, any pixel that differs from the own colors.
$wn.LogoBad = { param($F)
  if (-not $F.Shown) { return @() }
  if ($F.High -and ([int]$F.Other -ne 0 -or [int]$F.Diff -eq 0)) {
    return @('LAYOUT rail W7 logo: high contrast on, ' + $F.Other + ' pixels not in the system colors, ' + $F.Diff + ' pixels changed from its own colors') }
  if (-not $F.High -and [int]$F.Diff -ne 0) { return @('LAYOUT rail W7 logo: high contrast off, ' + $F.Diff + ' pixels differ from its own colors') }
  return @() }
$wn.HeadFacts = {
  <#
  .SYNOPSIS
  The facts of one rail head (R31 W1): the bounds of the logo and the name, their vertical middles and the colors
  behind the logo and behind the panel it sits on.
  .PARAMETER Logo
  The logo picture box.
  .PARAMETER Name
  The app name label.
  .PARAMETER Into
  The panel they sit on (the rail, or the test panel).
  .PARAMETER At
  The scale, as text.
  #>
  param($Logo, $Name, $Into, [string]$At)
  $f = [ordered]@{}; $f['At'] = $At; $f['Logo'] = [string]$Logo.Bounds; $f['Name'] = [string]$Name.Bounds
  $f['LogoMid'] = $Logo.Top + $Logo.Height / 2.0; $f['NameMid'] = $Name.Top + $Name.Height / 2.0
  $f['LogoBack'] = (& $wn.Hex $Logo.BackColor); $f['RailBack'] = (& $wn.Hex $Into.BackColor)
  return $f }
$wn.MeasureHead = {
  <#
  .SYNOPSIS
  The rail head at this screen's scale (the rail as built) and at 1.5 x that scale (R31 W1).
  .DESCRIPTION
  For 1.5 x, the same builder ($wn.HeadParts) runs into a navy test panel on the window with the scale ($ui.Dpi) and
  the name's font 1.5 x as large, as Windows makes them at 150 %; then the scale comes back and the panel goes.
  .OUTPUTS
  Two tables of $wn.HeadFacts.
  #>
  $res = @(& $wn.HeadFacts $wn.Logo $wn.AppName $rail ('dpi ' + $ui.Dpi))
  $dpi = $ui.Dpi; $f = $null; $p = $null
  try {
    $wf = $ui.F.Word; $f = New-Object System.Drawing.Font($wf.FontFamily, [single]($wf.Size * 1.5), $wf.Style)
    $ui.Dpi = $dpi * 1.5
    $p = New-Object System.Windows.Forms.Panel; $p.BackColor = $pc.navy; $p.Size = [Drawing.Size]::new((& $wn.Sc 200), (& $wn.Sc 100)); $form.Controls.Add($p)
    $h = & $wn.HeadParts $p $f; [Windows.Forms.Application]::DoEvents()
    $res += & $wn.HeadFacts $h.Logo $h.Name $p ('dpi ' + $ui.Dpi)
  } finally { $ui.Dpi = $dpi; if ($p) { $form.Controls.Remove($p); $p.Dispose() }; if ($f) { $f.Dispose() } }
  return $res }
$wn.MeasureContrast = {
  <#
  .SYNOPSIS
  The colors Select-T22Color gives for each palette name with high contrast on and off (R31 W2), with no change of the
  Windows theme.
  .OUTPUTS
  One table per palette name and setting: Table (pc or C), Key, High, System (a system color), Name (its color name),
  Role (the system color its role names), Hex and Own (the window's own color).
  #>
  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($t in @(@{ Name = 'pc'; Own = $ui.OwnPc }, @{ Name = 'C'; Own = $ui.OwnC })) {
    foreach ($high in $true, $false) {
      $pick = Select-T22Color $high $t.Own $ui.HcRole
      foreach ($k in @($pick.Keys | Sort-Object)) {
        $r = [ordered]@{}; $r['Table'] = $t.Name; $r['Key'] = [string]$k; $r['High'] = $high; $r['System'] = [bool]$pick[$k].IsSystemColor
        $r['Name'] = [string]$pick[$k].Name; $r['Role'] = [string]$ui.HcRole[$k]; $r['Hex'] = (& $wn.Hex $pick[$k]); $r['Own'] = (& $wn.Hex $t.Own[$k])
        $rows.Add($r) } } }
  return $rows.ToArray() }
$wn.MeasureLogo = {
  <#
  .SYNOPSIS
  R8 (R35 W7): the rail logo with high contrast on, then off, with no change of the Windows theme.
  .DESCRIPTION
  The window is recolored both ways ($wn.Recolor with -Force: the rail, the check bar and the card are rebuilt, as on a
  real change of the setting) and the logo facts are taken after each rebuild. Then the window takes the Windows
  setting again.
  .OUTPUTS
  Two tables of $wn.LogoFacts (on, then off), each with When and Bad (the LAYOUT lines of $wn.LogoBad).
  #>
  $res = @()
  try {
    foreach ($h in $true, $false) {
      & $wn.Recolor ('measure ' + $(if ($h) { 'on' } else { 'off' })) $h; [Windows.Forms.Application]::DoEvents()
      $f = & $wn.LogoFacts; $f['When'] = $(if ($h) { 'on' } else { 'off' }); $f['Bad'] = @(& $wn.LogoBad $f); $res += , $f }
  } finally { if ([bool]$ui.High -ne [bool][Windows.Forms.SystemInformation]::HighContrast) { & $wn.Recolor 'measure back' } }
  return $res }
$wn.WheelTry = {
  <#
  .SYNOPSIS
  R7 (R32 W2): turns the mouse wheel once towards you (delta -120) at point $Pt of the window, in 2 ways: through the
  window's own handlers (Add-PfmWheel: the MouseWheel event of the control that has the focus, with the pointer in its
  pixels, as Windows sends it), or straight through the routing function on the control tree.
  .PARAMETER Pt
  The pointer, in client pixels of the window ($wn.ViewMid).
  .PARAMETER Focus
  The control the message is for (Windows sends the wheel to the control with the focus).
  .PARAMETER Direct
  When set, the routing function Invoke-PfmWheelRoute is called with $Pt; no event, no screen pixels.
  .OUTPUTS
  @{ Handled (the turn was taken); Under (the control under the pointer: its type and accessible name) }.
  #>
  param($Pt, $Focus, [switch]$Direct)
  $u = Get-PfmWheelUnder $form $Pt
  if ($Direct) { $ok = ($null -ne (Invoke-PfmWheelRoute $form $main $Pt -120)) }
  else { $ok = Send-PfmWheel $Focus $form.PointToScreen($Pt) -120 }
  return @{ Handled = [bool]$ok; Under = ($u.GetType().Name + ' "' + [string]$u.AccessibleName + '"') } }
$wn.WheelCase = {
  <#
  .SYNOPSIS
  R7 (R32 W2): one wheel case on Your Work at its top: one turn on the middle of its first card ("Needs You Today"),
  then, when a grid of the card has rows out of view, the card is scrolled to the grid and one turn goes to the middle
  of the grid's part in view ($wn.WheelTry; a button has the focus).
  .PARAMETER Direct
  When set, the turns go straight to the routing function; else through the window's handlers (the Filter key of the result).
  .OUTPUTS
  A table: Scrolls, Point (the pointer, window pixels), PageTop, Under, Handled, Before, After (the main column's
  scroll position) and, when a grid can scroll,
  GridUnder, GridHandled, GridBefore, GridAfter (its first row in view) and MainBefore, MainAfter.
  #>
  param([switch]$Direct)
  $res = [ordered]@{}; $wn.Notice = ''; $wn.Err = ''; & $wn.Show 'home'
  [Windows.Forms.Application]::DoEvents(); $main.AutoScrollPosition = [Drawing.Point]::new(0, 0)
  Add-PfmWheel $form $main; $focus = $(if ($wn.Primary) { $wn.Primary } else { $form })   # the handlers of a normal run ($wn.WheelOn); a new card gets them by ControlAdded
  $sec = @($wn.Secs | Where-Object { $_.Col -eq 0 }) | Select-Object -First 1
  $res['Scrolls'] = [bool]$main.VerticalScroll.Visible; $res['Before'] = -$main.AutoScrollPosition.Y
  $pt = & $wn.ViewMid $sec.Card; $res['Point'] = [string]$pt; $res['PageTop'] = $page.Top
  $t = & $wn.WheelTry $pt $focus -Direct:$Direct
  $res['Under'] = $t.Under; $res['Handled'] = $t.Handled; $res['After'] = -$main.AutoScrollPosition.Y
  $g = @(& $wn.Grids | Where-Object { (Test-PfmGridCanScroll $_ -120) }) | Select-Object -First 1
  if ($g) {
    $main.ScrollControlIntoView($g); [Windows.Forms.Application]::DoEvents()
    $res['MainBefore'] = -$main.AutoScrollPosition.Y; $res['GridBefore'] = $g.FirstDisplayedScrollingRowIndex
    $t = & $wn.WheelTry (& $wn.ViewMid $g) $focus -Direct:$Direct
    $res['GridUnder'] = $t.Under; $res['GridHandled'] = $t.Handled; $res['GridAfter'] = $g.FirstDisplayedScrollingRowIndex; $res['MainAfter'] = -$main.AutoScrollPosition.Y }
  return $res }
$wn.MeasureWheel = {
  <#
  .SYNOPSIS
  R7 (R32 W2): proves that the mouse wheel scrolls the card from a point on the card, not on the scroll bar, while a
  button has the focus; and the grid under the pointer while that grid can still scroll.
  .DESCRIPTION
  The window is made 60 % as high so that Your Work scrolls; $wn.WheelCase runs twice: straight through the routing
  function on the control tree (Route: no screen pixels, so it holds for this window off the screen), then through the
  window's own handlers as Windows calls them (Filter). Then the size comes back and Your Work is shown again. No real
  pointer is moved.
  .OUTPUTS
  A table: Card, Route and Filter (each a $wn.WheelCase table).
  #>
  $keep = $form.ClientSize; $res = [ordered]@{}; $res['Card'] = 'home'
  try {
    $form.ClientSize = [Drawing.Size]::new($keep.Width, [int]($keep.Height * 0.6))
    $res['Route'] = (& $wn.WheelCase -Direct); $res['Filter'] = (& $wn.WheelCase)
  } finally { $form.ClientSize = $keep; $wn.Notice = ''; $wn.Err = ''; & $wn.Show 'home'; [Windows.Forms.Application]::DoEvents() }
  return $res }
# The middle of the part of control $C that the main column shows, in client pixels of the window, from the control
# tree (Get-PfmClientOrigin; no screen pixels, so it holds for a window off the screen too). It stops with the places
# when no part shows (R7: an empty overlap gave the point 0,0, on the rail, and hid the cause).
$wn.ViewMid = { param($C)
  $o = Get-PfmClientOrigin $C $form; $mo = Get-PfmClientOrigin $main $form
  $v = [Drawing.Rectangle]::Intersect((New-Object Drawing.Rectangle($o, $C.Size)), (New-Object Drawing.Rectangle($mo, $main.ClientSize)))
  if ($v.Width -lt 1 -or $v.Height -lt 1) { throw ('no part of ' + $C.GetType().Name + ' at ' + $o + ' ' + $C.Size + ' shows in the main column at ' + $mo + ' ' + $main.ClientSize) }
  return [Drawing.Point]::new(($v.Left + [int]($v.Width / 2)), ($v.Top + [int]($v.Height / 2))) }
# The grids on the page (the card shown), in the order they were built.
$wn.Grids = {
  $out = New-Object System.Collections.Generic.List[object]; $st = New-Object System.Collections.Queue; $st.Enqueue($page)
  while ($st.Count) { foreach ($c in $st.Dequeue().Controls) { if ($c -is [Windows.Forms.DataGridView]) { $out.Add($c) } elseif ($c.Controls.Count) { $st.Enqueue($c) } } }
  return $out.ToArray() }
$wn.MeasureRun = {
  <#
  .SYNOPSIS
  The -Measure run: builds the window off-screen at 1280 x 720, measures every card, writes the JSON file, closes.
  .DESCRIPTION
  The form is shown far off the screen (it is never seen) so that its controls have handles and can be drawn into
  bitmaps; it builds every card as a normal run does ($wn.Build: layout self-check, accessible names and the card
  pictures, saved next to the JSON file, included), then measures D1 to D4 of every card at 1.25 x and 1.5 x (R6,
  with W1 and W3 of R7), the mouse wheel (R7 W2), the rail head, the high-contrast color choice, (R10) the Feedback
  link with one saved comment and the two own-color logos, and (R8 W7) the logo with high contrast on and off.
  .PARAMETER Path
  The JSON file to write.
  #>
  param([string]$Path)
  $wn.PngDir = Split-Path -Parent $Path
  $form.StartPosition = 'Manual'; $form.ShowInTaskbar = $false; $form.Location = [Drawing.Point]::new(-20000, -20000)
  $form.Show(); [Windows.Forms.Application]::DoEvents()
  & $ui.FormDpi; $ui.Scaled = $true; $form.BackColor = $pc.surface   # R11: as the window part sets it
  $wn.Light = [bool](& $wn.AppsLight)   # R10: the rail logo of this computer's app mode, as $wn.Recolor 'start' sets it in a normal run
  $all = New-Object System.Collections.Generic.List[object]
  # A card that cannot be measured is kept with its error and place, and the run goes on (the test names it).
  & $wn.Build { param($k) try { $all.Add((& $wn.MeasureCard $k)) } catch { $all.Add([ordered]@{ Key = $k; Error = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }) } }
  # One key per statement: Windows PowerShell 5.1 stopped on the one-literal form ("Argument types do not match", R30 CI).
  $res = [ordered]@{}
  $res['Rev'] = $Rev
  $res['Dpi'] = $ui.Dpi
  $res['Sc8'] = (& $wn.Sc 8)
  $res['Client'] = ([string]$form.ClientSize.Width + 'x' + $form.ClientSize.Height)
  $res['Cards'] = $all.ToArray()
  $res['EmptyNames'] = @($wn.NoName.Keys | ForEach-Object { [string]$_ })
  $res['LayoutDefects'] = @($ui.LayBad)
  $res['Pngs'] = $wn.Pngs.ToArray()
  # R13 (R40): every card opened again shows its kept card (the keep part); a pass that cannot run is kept as its error.
  try { $res['Keep'] = @(& $wn.MeasureKeep) } catch { $res['Keep'] = @(); $res['KeepError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  # D1 to D4 at 1.25 x and 1.5 x (R6; the PFM works at 150 %): every card again; a pass that cannot run is kept as its error.
  try { $res['Scaled'] = @(foreach ($k in 1.25, 1.5) { & $wn.MeasureScaled $k }) }
  catch { $res['Scaled'] = @(); $res['ScaledError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  # R7 (W2): one wheel turn on the card body and one on a grid, through the window's own handlers.
  try { $res['Wheel'] = (& $wn.MeasureWheel) } catch { $res['Wheel'] = $null; $res['WheelError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  # The rail head and the color choice: a step that cannot be measured is kept as its error (the test names it).
  try { $res['Head'] = @(& $wn.MeasureHead) } catch { $res['Head'] = @(); $res['HeadError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  try { $res['Contrast'] = @(& $wn.MeasureContrast) } catch { $res['Contrast'] = @(); $res['ContrastError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  # R10 (R37): the Feedback link and one saved comment (B13); the two own-color logos by app mode.
  try { $res['Feedback'] = (& $wn.MeasureFeedback) } catch { $res['Feedback'] = $null; $res['FeedbackError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  try { $res['Theme'] = (& $wn.MeasureTheme) } catch { $res['Theme'] = $null; $res['ThemeError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  # R8 (R35 W7): the rail logo rebuilt with high contrast on and off (last: it rebuilds the rail, the bar and the card).
  try { $res['Logo'] = @(& $wn.MeasureLogo) } catch { $res['Logo'] = @(); $res['LogoError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  Set-Content -LiteralPath $Path -Value ($res | ConvertTo-Json -Depth 10) -Encoding UTF8
  $form.Close() }
