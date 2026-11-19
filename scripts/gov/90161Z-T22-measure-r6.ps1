<#
.SYNOPSIS
  90-161.Z Task 22 r5, part "measure": the script's own accessible-name check (the RESULT NAMES line) and the -Measure
  run, which builds every card off-screen and writes what it measured as JSON for tests/ps/Test-T22Layout.ps1.
.DESCRIPTION
  Names (R30 fallback for check 8, Narrator names): every button, link, check box, choice, text box and list of every
  card, the rail and the check bar must have an accessible name; the result is one line "RESULT NAMES PASS" or
  "RESULT NAMES FAIL (<n> controls: <card>/<type> "<text>", ...)".
  Measure (-Measure <file>): the window is built at 1280 x 720 far off the screen and never shown to a person; for each
  card it records the crumb (fonts, bounds, the ink gap after the link: R30 V2), every button (its color and the color
  of its face as drawn: V4) and every section card (its bottom: V4). R31: it also records the rail head at this scale
  and at 1.5 x (W1: the logo's middle and the name's middle, the color behind the logo) and the colors that
  Select-T22Color gives with high contrast on and off (W2). No question; no file but the given one and the card
  pictures next to it.
  Card pictures (R31 W4): $wn.SavePng saves the window as it shows a card, 90161Z-T22-card-<card>-r5.png, in
  $wn.PngDir (the T22 folder in a normal run, the folder of the measure file with -Measure); $wn.PngLines adds the
  CARDPNG lines to the result. The cards hold only FAKE data. A picture that cannot be saved is a NOTE line.
  Inputs: $form, $page, $rail, $pc, $ui, $wn, $Cards, $Rev, $lines. Outputs: $wn.NoName, $wn.NamesLine, $wn.SavePng,
  $wn.PngLines, $wn.MeasureRun and its helpers.
  Run: not alone; 90161Z-T22-pfm-window-r5.ps1 dot-sources it from its own folder inside its try block.
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
  Saves a picture of the window as it shows card $Key (R31 W4): 90161Z-T22-card-<key>-r5.png in $wn.PngDir.
  .DESCRIPTION
  Control.DrawToBitmap at the window's current size; nothing when $wn.PngDir is empty. A picture that cannot be
  saved is a NOTE line in the result, not a stop. The file name is kept in $wn.Pngs.
  .PARAMETER Key
  The card key (the card on the page).
  #>
  param([string]$Key)
  if (-not $wn.PngDir) { return }
  $name = '90161Z-T22-card-' + $Key + '-' + $Rev + '.png'
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
$wn.MeasureCard = {
  <#
  .SYNOPSIS
  What -Measure records for the card on the page: the crumb, every button and link, every section card.
  .PARAMETER Key
  The card key.
  .OUTPUTS
  A table: Key, Crumb, Buttons (Text, Link, Back, Face, Edge), Sections (Col, Cap, Stretch, Top, Bottom; page pixels).
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
  $card['Buttons'] = $btns.ToArray(); $card['Sections'] = $secs
  return $card }
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
$wn.MeasureRun = {
  <#
  .SYNOPSIS
  The -Measure run: builds the window off-screen at 1280 x 720, measures every card, writes the JSON file, closes.
  .DESCRIPTION
  The form is shown far off the screen (it is never seen) so that its controls have handles and can be drawn into
  bitmaps; it builds every card as a normal run does ($wn.Build: layout self-check, accessible names and the card
  pictures, saved next to the JSON file, included), then measures the rail head and the high-contrast color choice.
  .PARAMETER Path
  The JSON file to write.
  #>
  param([string]$Path)
  $wn.PngDir = Split-Path -Parent $Path
  $form.StartPosition = 'Manual'; $form.ShowInTaskbar = $false; $form.Location = [Drawing.Point]::new(-20000, -20000)
  $form.Show(); [Windows.Forms.Application]::DoEvents()
  & $ui.FormDpi; $form.BackColor = $pc.surface
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
  # The rail head and the color choice: a step that cannot be measured is kept as its error (the test names it).
  try { $res['Head'] = @(& $wn.MeasureHead) } catch { $res['Head'] = @(); $res['HeadError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  try { $res['Contrast'] = @(& $wn.MeasureContrast) } catch { $res['Contrast'] = @(); $res['ContrastError'] = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }
  Set-Content -LiteralPath $Path -Value ($res | ConvertTo-Json -Depth 8) -Encoding UTF8
  $form.Close() }
