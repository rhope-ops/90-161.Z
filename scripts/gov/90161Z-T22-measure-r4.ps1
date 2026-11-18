<#
.SYNOPSIS
  90-161.Z Task 22 r4, part "measure": the script's own accessible-name check (the RESULT NAMES line) and the -Measure
  run, which builds every card off-screen and writes what it measured as JSON for tests/ps/Test-T22Layout.ps1.
.DESCRIPTION
  Names (R30 fallback for check 8, Narrator names): every button, link, check box, choice, text box and list of every
  card, the rail and the check bar must have an accessible name; the result is one line "RESULT NAMES PASS" or
  "RESULT NAMES FAIL (<n> controls: <card>/<type> "<text>", ...)".
  Measure (-Measure <file>): the window is built at 1280 x 720 far off the screen and never shown to a person; for each
  card it records the crumb (fonts, bounds, the ink gap after the link: R30 V2), every button (its color and the color
  of its face as drawn: V4) and every section card (its bottom: V4). No question, no file but the given one.
  Inputs: $form, $page, $ui, $wn, $Cards, $Rev. Outputs: $wn.NoName, $wn.NamesLine, $wn.MeasureRun and its helpers.
  Run: not alone; 90161Z-T22-pfm-window-r4.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: with -Measure only: the JSON file given (the test gives a file in its own temporary folder).
  Credentials: none.
#>
$wn.NoName = [ordered]@{}; $wn.Scanned = $false
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
        $btns.Add([ordered]@{ Text = [string]$c.Text; Link = ([int]$c.FlatAppearance.BorderSize -eq 0); Back = (& $wn.Hex $c.BackColor); Face = (& $wn.FaceColor $c)
            Edge = (& $wn.Hex $c.FlatAppearance.BorderColor) }) }
      if ($c.Controls.Count) { $st.Push($c) } } }
  $pt = $page.RectangleToScreen($page.ClientRectangle).Top
  $secs = @(foreach ($s in $wn.Secs) { $r = $s.Card.RectangleToScreen($s.Card.ClientRectangle)
      [ordered]@{ Col = $s.Col; Cap = $s.Cap; Stretch = $s.Stretch; Top = ($r.Top - $pt); Bottom = ($r.Bottom - $pt) } })
  return [ordered]@{ Key = $Key; Crumb = (& $wn.MeasureCrumb); Buttons = @($btns); Sections = $secs } }
$wn.MeasureRun = {
  <#
  .SYNOPSIS
  The -Measure run: builds the window off-screen at 1280 x 720, measures every card, writes the JSON file, closes.
  .DESCRIPTION
  The form is shown far off the screen (it is never seen) so that its controls have handles and can be drawn into
  bitmaps; it builds every card as a normal run does ($wn.Build: layout self-check and accessible names included).
  .PARAMETER Path
  The JSON file to write.
  #>
  param([string]$Path)
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
  Set-Content -LiteralPath $Path -Value ($res | ConvertTo-Json -Depth 8) -Encoding UTF8
  $form.Close() }
