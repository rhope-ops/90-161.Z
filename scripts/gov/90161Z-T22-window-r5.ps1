<#
.SYNOPSIS
  90-161.Z Task 22 r5, part "window": the rail, the cards, the check bar, the window size and place, and the window's
  events of the PFM window.
.DESCRIPTION
  $wn.Show builds one card: the head (notice, crumb, title), then its columns of sections. R4 (R30): the crumb is one
  line in one font (V2: its link is a Pfm.LinkText in the crumb's font, underlined, with no padding); the last cards of
  the columns end on one line when the card has an Action Status card (V4). $wn.Build builds every card once (layout
  self-check, grid check, the accessible-name check of the measure part) and $wn.Hook adds the window's events.
  R5 (R31): the rail logo sits on the rail's navy and the app name is centered on the logo's middle (W1, $wn.HeadParts);
  with Windows high contrast on the window paints with the system colors, also after a change while it is open (W2,
  $wn.Recolor); $wn.Build saves a picture of each card through the measure part (W4).
  The rail logo is the app-logo block below, written by scripts/build_task_scripts.py (never edit it here).
  Inputs: $form, $main, $page, $rail, $ui, $wn, $pc, $Cards, $Checks, $RailItems, $Rev, $dir, $lines.
  Outputs: the $wn members below. The window place is saved in 90161Z-T22-window-bounds.json in the task folder.
  Run: not alone; 90161Z-T22-pfm-window-r5.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: 90161Z-T22-window-bounds.json in the T22 folder (or -TestDir), when the window closes; nothing with -Measure.
  Credentials: none.
#>
# >>> app-logo: generated from assets/logo/90161Z-logo.svg by scripts/build_task_scripts.py (do not edit)
$AppLogoPng = @(
  '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'
) -join ''
# <<< app-logo
$wn.Press = {
  <#
  .SYNOPSIS
  What a card button, link or grid row does: checks what it needs, keeps its note, then opens the card it goes to.
  .DESCRIPTION
  A click in the first moments after a card changed does nothing ($ui.Settled). Need = reason: the reason box must have
  text; Need = ck: both boxes must be selected; else the card shows its error line. Go: a card key, 'back', or '@grid'
  (the selected row of the card's grid); no Go shows the same card again with the button's FAKE note.
  .PARAMETER B
  The button table: Text, Go, Note, Need.
  #>
  param($B)
  if (-not (& $ui.Settled)) { return }
  $script:presses++
  $need = [string]$B.Need
  if ($need -eq 'reason' -and -not ([string]$wn.Field.reason).Trim()) { $wn.Err = 'reason'; $wn.Notice = ''; $wn.Focus = 'reason'; & $wn.Show $wn.Cur; return }
  if ($need -eq 'ck' -and -not ($wn.Field.ck1 -and $wn.Field.ck2)) { $wn.Err = 'ck'; $wn.Notice = ''; & $wn.Show $wn.Cur; return }
  $wn.Err = ''; $wn.Notice = [string]$B.Note
  $go = [string]$B.Go
  if ($go -eq '@grid') {   # the selected row of the card's grid, else its first row
    $go = ''; $g = $wn.Gridsel
    if ($g -and @($g.Tag.Shown).Count) { $i = 0; if ($g.SelectedRows.Count) { $i = [int]$g.SelectedRows[0].Index }; $go = [string]@($g.Tag.Shown)[$i].Go } }
  if ($go -eq 'back') { $go = $wn.Prev }
  if ($go) { & $wn.Show $go } else { & $wn.Show $wn.Cur } }
# The rail is wider when the window is wide; its items follow its width.
$wn.RailLayout = {
  $wide = ($form.ClientSize.Width -ge (& $wn.Sc 1500)); $rw = $(if ($wide) { & $wn.Sc 220 } else { & $wn.Sc 200 }); $rail.Width = $rw
  foreach ($x in $wn.RailBtn) { $x.Width = $rw - 2 * (& $wn.Sc 12) } }
$wn.HeadParts = {
  <#
  .SYNOPSIS
  Builds the logo and the app name "90-161.Z" of the rail head into $Into (R31 W1).
  .DESCRIPTION
  The logo (40 x 40 at 100 %, at 16,16) sits on the rail's navy, the same color as the name, so no white box shows
  behind it. The name is placed by its middle, not its top: its middle is the logo's middle (rounded to a pixel), at
  any scale. A logo that cannot be shown is a NOTE line, not an error; the name keeps its place. The measure part
  builds the same parts into a test panel at 1.5 x to measure the centering at a second scale.
  .PARAMETER Into
  The panel the parts go into (the rail).
  .PARAMETER WordFont
  The font of the name (the RADE logo word, $ui.F.Word).
  .OUTPUTS
  @{ Logo (the picture box, or $null); Name (the label) }.
  #>
  param($Into, $WordFont)
  $out = @{ Logo = $null; Name = $null }; $top = & $wn.Sc 16; $side = & $wn.Sc 40
  try {
    $logo = New-Object System.Windows.Forms.PictureBox; $logo.Size = [Drawing.Size]::new($side, $side); $logo.SizeMode = 'Zoom'; $logo.BackColor = $pc.navy
    $logo.AccessibleName = '90-161.Z logo'; $logo.Location = [Drawing.Point]::new((& $wn.Sc 16), $top)
    $logo.Image = [Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($AppLogoPng)))); [void]$Into.Controls.Add($logo); $out.Logo = $logo
  } catch { $lines.Add('NOTE logo not shown: ' + $_.Exception.Message) }
  $nm = & $ui.Label $WordFont $ui.C.White 0; $nm.BackColor = $pc.navy; $nm.Text = '90-161.Z'; $nm.Visible = $true
  $nh = [int]$nm.PreferredSize.Height
  $nm.Location = [Drawing.Point]::new((& $wn.Sc 64), ($top + [int][math]::Round(($side - $nh) / 2.0)))
  [void]$Into.Controls.Add($nm); $out.Name = $nm
  return $out }
# The rail head: the logo and the app name ($wn.HeadParts; kept in $wn.Logo and $wn.AppName for the measure part) and the
# line under them.
$wn.RailHead = {
  $h = & $wn.HeadParts $rail $ui.F.Word; $wn.Logo = $h.Logo; $wn.AppName = $h.Name
  $sb = & $ui.Label $ui.F.Small $pc.onPrimaryMuted 0; $sb.BackColor = $pc.navy; $sb.Text = 'Publications and Forms'; $sb.Visible = $true
  $sb.Location = [Drawing.Point]::new((& $wn.Sc 16), (& $wn.Sc 66)); [void]$rail.Controls.Add($sb) }
$wn.BuildRail = {
  <#
  .SYNOPSIS
  Builds the rail: its head, one item per rail entry (Your Work has a badge) and the "FAKE data" line at the bottom.
  .DESCRIPTION
  A rail item opens its card (Ctrl+1 to Ctrl+5 do the same, $wn.Hook). Then the rail takes its width ($wn.RailLayout).
  #>
  $rail.SuspendLayout()
  & $wn.RailHead
  $y = & $wn.Sc 108
  foreach ($r in $RailItems) {
    $x = New-Object Pfm.RailItem; $x.Text = $r.Text; $x.AccessibleName = $r.Text; $x.Tag = $r.Key; $x.Font = $ui.F.Body; $x.BoldFont = $ui.F.SmallB
    $x.Back = $pc.navy; $x.OnBack = $ui.C.White; $x.Fore = $pc.onPrimaryMuted; $x.OnFore = $pc.navy; $x.HotLine = $pc.onPrimaryMuted; $x.FocusLine = $pc.accentFill
    $x.FocusOn = $pc.navy; $x.BadgeFill = $pc.accentFill; $x.BadgeText = $pc.ink
    if ($r.Badge) { $x.Badge = [string]$r.Badge; $x.AccessibleName = $r.Text + ', ' + $r.Badge + ' items need you' }
    $x.Size = [Drawing.Size]::new(((& $wn.Sc 200) - 2 * (& $wn.Sc 12)), (& $wn.Sc 44)); $x.Location = [Drawing.Point]::new((& $wn.Sc 12), $y); $y += (& $wn.Sc 48)
    $x.Add_Click({ if (& $ui.Settled) { $script:presses++; $wn.Notice = ''; $wn.Err = ''; $key = [string]$this.Tag; $go = 'home'
        foreach ($q in $RailItems) { if ($q.Key -eq $key) { $go = $q.Go } }; & $wn.Show $go } })
    [void]$rail.Controls.Add($x); $wn.RailBtn += $x }
  $ft = & $ui.Label $ui.F.Small $pc.onPrimaryMuted 0; $ft.BackColor = $pc.navy; $ft.Text = 'FAKE data' + [Environment]::NewLine + 'Preview ' + $Rev; $ft.Visible = $true; $ft.Anchor = 'Left, Bottom'
  $ft.Location = [Drawing.Point]::new((& $wn.Sc 16), ($rail.ClientSize.Height - (& $wn.Sc 56))); [void]$rail.Controls.Add($ft)
  $rail.ResumeLayout($true); & $wn.RailLayout }
$wn.Crumb = {
  <#
  .SYNOPSIS
  The crumb line of a card: its first part as a link, the rest as text, in one font and size (R30 V2).
  .DESCRIPTION
  The link is a Pfm.LinkText: the crumb's own font (the small text font) underlined, the link blue, no padding, so its
  size is its text. The rest starts with the arrow, a small gap after the link (3 px at 100 %, room for the focus ring),
  so the gap from the link's text to the arrow stays under 8 px at 100 %. A crumb with no link is one text.
  .PARAMETER C
  The card: Crumb, CrumbGo.
  .PARAMETER Cw
  The width of the page column.
  .OUTPUTS
  The text box of the crumb's rest (the card's title for the layout self-check).
  #>
  param($C, [int]$Cw)
  $cf = & $wn.Flow $page $pc.surface; $cf.Margin = & $ui.Pad 0 0 0 (& $wn.Sc 8)
  $parts = @(([string]$C.Crumb) -split [regex]::Escape(' ' + $gt + ' '))
  if (-not ($C.CrumbGo -and $parts.Count -gt 1)) { return (& $wn.Txt $cf $C.Crumb $ui.F.Small $ui.C.Gray 0 $Cw 'Where you are' $pc.surface) }
  $l = New-Object Pfm.LinkText; $l.Text = $parts[0]; $l.Font = $wn.CrumbFont; $l.ForeColor = $ui.C.Blue; $l.BackColor = $pc.surface
  $l.AutoSize = $true; $l.AutoSizeMode = 'GrowAndShrink'
  $l.MinimumSize = [Drawing.Size]::new(0, (& $wn.Sc $ui.Z.LinkH)); $l.Margin = & $ui.Pad (& $wn.Sc $ui.Z.M) (& $wn.Sc $ui.Z.M) 0 (& $wn.Sc $ui.Z.M)
  $l.AccessibleName = $parts[0]; $l.AccessibleRole = 'Link'; $l.Tag = @{ Text = $parts[0]; Go = $C.CrumbGo }
  $l.Add_Click({ & $wn.Press $this.Tag }); & $ui.Cue $l; [void]$cf.Controls.Add($l); $wn.CrumbLink = $l
  $rest = $gt + ' ' + ((@($parts | Select-Object -Skip 1)) -join (' ' + $gt + ' '))
  $t = & $wn.Txt $cf $rest $ui.F.Small $ui.C.Gray 8 ($Cw - (& $wn.Sc 160)) 'Where you are' $pc.surface
  $t.Margin = & $ui.Pad (& $wn.Sc 3) $t.Margin.Top 0 0; $wn.CrumbRest = $t
  return $t }
# The head of a card: the FAKE note of the last button, the crumb, the title and the line under it. Sets $ui.Sent and
# $ui.Kick (the title and the line the layout self-check reads).
$wn.ShowHead = { param($C, [int]$Cw)
  $title = $null
  if ($wn.Notice) {
    $nf = & $wn.Flow $page $pc.surface; $nf.Margin = & $ui.Pad 0 0 0 (& $wn.Sc 10); [void]$nf.Controls.Add((& $wn.Chip 'turn' 'NOTICE' $pc.surface))
    [void](& $wn.Txt $nf $wn.Notice $ui.F.Body $ui.C.Ink 2 ($Cw - (& $wn.Sc 120)) 'Notice' $pc.surface) }
  if ($C.Crumb) { $title = & $wn.Crumb $C $Cw }
  if ($C.Title) { $title = & $wn.Txt $page $C.Title $ui.F.Sent $ui.C.Navy 0 $Cw 'Page title' $pc.surface }
  if ($C.Sub) { $ui.Kick = & $wn.Txt $page $C.Sub $ui.F.Small $ui.C.Gray 4 $Cw 'Page line' $pc.surface } else { $ui.Kick = $title }
  $ui.Sent = $title }
$wn.ShowCols = {
  <#
  .SYNOPSIS
  The columns of a card: one column, or a main column and a side column; each section is a card with its blocks.
  .DESCRIPTION
  Each section built is kept in $wn.Secs (column number, card, caption, Stretch) for $wn.Align and the measure part.
  .PARAMETER C
  The card data.
  .PARAMETER Key
  The card key (Your Work has a wider side column).
  .PARAMETER Cw
  The width of the page column.
  .PARAMETER Wide
  True when the window is wide (WideOnly sections show, the side column of Your Work is wider).
  #>
  param($C, [string]$Key, [int]$Cw, [bool]$Wide)
  $cols = New-Object System.Windows.Forms.FlowLayoutPanel; $cols.FlowDirection = 'LeftToRight'; $cols.WrapContents = $false; $cols.AutoSize = $true; $cols.AutoSizeMode = 'GrowAndShrink'
  $cols.BackColor = $pc.surface; $cols.Margin = & $ui.Pad 0 (& $wn.Sc 12) 0 0; [void]$page.Controls.Add($cols)
  $gap = & $wn.Sc 18; $nc = @($C.Cols).Count
  $side = $(if ($nc -gt 1) { $(if ($Key -eq 'home' -or $Key -eq 'empty') { $(if ($Wide) { & $wn.Sc 420 } else { & $wn.Sc 300 }) } else { & $wn.Sc $C.Side }) } else { 0 })
  $ci = 0
  foreach ($colDef in @($C.Cols)) {
    $colW = $(if ($nc -le 1) { [math]::Min($Cw, (& $wn.Sc 1000)) } elseif ($ci -eq 0) { $Cw - $side - $gap } else { $side })
    $col = New-Object System.Windows.Forms.FlowLayoutPanel; $col.FlowDirection = 'TopDown'; $col.WrapContents = $false; $col.AutoSize = $true; $col.AutoSizeMode = 'GrowAndShrink'
    $col.BackColor = $pc.surface; $col.Margin = & $ui.Pad 0 0 $(if ($ci -eq 0 -and $nc -gt 1) { $gap } else { 0 }) 0; [void]$cols.Controls.Add($col)
    $ctx = @{ Col = $col }
    foreach ($s in @($colDef)) {
      if ($s.WideOnly -and -not $Wide) { continue }
      $px = $(if ($s.Pad) { [int]$s.Pad } else { 24 })
      $sec = & $wn.Card $colW $s.Cap $s.Top $px $pc.surface; [void]$col.Controls.Add($sec)
      $wn.Secs += @{ Col = $ci; Card = $sec; Cap = [string]$s.Cap; Stretch = [bool]$s.Stretch }
      $iw = $colW - 2 * (& $wn.Sc $px)
      foreach ($b in @($s.Blocks)) { & $wn.Block $sec $b $iw $ctx }
      $sec.PerformLayout() }
    $ci++ } }
# R30 V4: in a card with an Action Status card (Stretch), the last cards of the columns end on one line: the shorter one
# grows to the bottom of the longer one. The columns start at one top, so their bottoms compare directly.
$wn.Align = {
  if (-not @($wn.Secs | Where-Object { $_.Stretch }).Count) { return }
  $last = @{}; foreach ($s in $wn.Secs) { $last[$s.Col] = $s }
  if ($last.Count -lt 2) { return }
  $low = 0; foreach ($s in $last.Values) { $low = [math]::Max($low, $s.Card.Parent.Top + $s.Card.Bottom) }
  foreach ($s in $last.Values) { $d = $low - ($s.Card.Parent.Top + $s.Card.Bottom); if ($d -gt 0) { $s.Card.MinimumSize = [Drawing.Size]::new($s.Card.MinimumSize.Width, $s.Card.Height + $d) } }
  $page.PerformLayout() }
$wn.Show = {
  <#
  .SYNOPSIS
  Shows the card $Key: clears the page, builds the head and the columns, lines up the column bottoms and sets the focus.
  .DESCRIPTION
  A new card forgets the fields of the last one (a modal card remembers the card to go back to). The main button gets
  the focus (or the reason box after an empty reason) and the Enter key. The layout self-check runs a moment later.
  .PARAMETER Key
  The card key in $Cards; an unknown key does nothing.
  #>
  param([string]$Key)
  $c = $Cards[$Key]; if (-not $c) { return }
  if ($Key -ne $wn.Cur) { if ($c.Modal) { $wn.Prev = $wn.Cur }; $wn.Field = @{}; $wn.Err = ''; $wn.Focus = '' }
  $script:cardsOpened[$Key] = $true; $wn.Cur = $Key; $ui.View = $Key
  $wn.Primary = $null; $wn.Gridsel = $null; $wn.Gridq = $null; $wn.Reason = $null; $wn.CountBox = $null; $wn.CrumbLink = $null; $wn.CrumbRest = $null; $wn.Secs = @()
  $ui.Wrap = @{}; $ui.Boxes = @(); $ui.Hot = $null; $ui.Down = $null
  $form.SuspendLayout(); $page.SuspendLayout()
  foreach ($x in @($page.Controls)) { $page.Controls.Remove($x); $x.Dispose() }
  $wide = ($form.ClientSize.Width -ge (& $wn.Sc 1500)); $wn.Wide = $wide
  $wn.MainH = $main.ClientSize.Height; $padX = & $wn.Sc 28
  $cw = [math]::Max((& $wn.Sc 900), $main.ClientSize.Width - [Windows.Forms.SystemInformation]::VerticalScrollBarWidth - 2 * $padX)
  $page.Location = [Drawing.Point]::new($padX, (& $wn.Sc 22)); $page.Margin = & $ui.Pad 0 0 0 0; $page.Padding = & $ui.Pad 0 0 0 (& $wn.Sc 22)
  foreach ($r in $wn.RailBtn) { $r.On = ([string]$r.Tag -eq [string]$c.Rail); $r.Invalidate() }
  & $wn.ShowHead $c $cw
  $page.PerformLayout(); $wn.HeadH = [int]$page.PreferredSize.Height
  & $wn.ShowCols $c $Key $cw $wide
  $page.ResumeLayout($true); $form.ResumeLayout($true)
  & $wn.Align
  $main.AutoScrollPosition = [Drawing.Point]::new(0, 0)
  $form.AcceptButton = $wn.Primary
  $ui.CardAt = $ui.Clock.Elapsed.TotalMilliseconds
  if ($wn.Focus -eq 'reason' -and $wn.Reason) { [void]$wn.Reason.Focus(); $wn.Focus = '' } elseif ($wn.Primary) { [void]$wn.Primary.Focus() }
  if ($wn.Ready) { $wn.CheckTimer.Stop(); $wn.CheckTimer.Start() } }
# Where the window place is kept between runs (none with -Measure: no task folder).
$wn.BoundsFile = $(if ($dir) { Join-Path $dir '90161Z-T22-window-bounds.json' } else { '' })
$wn.LoadBounds = {
  <#
  .SYNOPSIS
  Puts the window where it was last closed (if that place is on a screen and big enough), else at 90 % of the screen.
  #>
  $ok = $false
  try {
    if ($wn.BoundsFile -and (Test-Path -LiteralPath $wn.BoundsFile)) {
      $j = Get-Content -LiteralPath $wn.BoundsFile -Raw | ConvertFrom-Json
      $r = New-Object System.Drawing.Rectangle([int]$j.Left, [int]$j.Top, [int]$j.Width, [int]$j.Height)
      $tl = [Drawing.Point]::new($r.X + (& $wn.Sc 40), $r.Y + (& $wn.Sc 10)); foreach ($sc in [Windows.Forms.Screen]::AllScreens) { if ($sc.WorkingArea.Contains($tl)) { $ok = $true } }
      if ($ok -and $r.Width -ge (& $wn.Sc 400) -and $r.Height -ge (& $wn.Sc 300)) {
        $form.StartPosition = 'Manual'; $form.Bounds = $r; if ([string]$j.State -eq 'Maximized') { $form.WindowState = 'Maximized' } } else { $ok = $false } }
  } catch { $ok = $false }
  if (-not $ok) {
    $wa = [Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position).WorkingArea
    $w = [int]($wa.Width * 0.9); $h = [int]($wa.Height * 0.9); $form.StartPosition = 'Manual'
    $form.Bounds = New-Object System.Drawing.Rectangle(($wa.X + [int](($wa.Width - $w) / 2)), ($wa.Y + [int](($wa.Height - $h) / 2)), $w, $h) } }
# Adds a STATE line (window state, client size, bounds) to the result.
$wn.State = { param([string]$When)
  $lines.Add('STATE ' + $When + ': WindowState=' + $form.WindowState + ' client=' + $form.ClientSize.Width + 'x' + $form.ClientSize.Height + ' bounds=' + $form.Bounds.Width + 'x' +
    $form.Bounds.Height + ' at ' + $form.Bounds.X + ',' + $form.Bounds.Y) }
# Saves the window's place and size (its normal bounds, and whether it was maximized) for the next run.
$wn.SaveBounds = {
  try {
    if (-not $wn.BoundsFile) { return }
    $r = $(if ($form.WindowState -eq 'Normal') { $form.Bounds } else { $form.RestoreBounds })
    $st = $(if ($form.WindowState -eq 'Maximized') { 'Maximized' } else { 'Normal' })
    $o = '{ "Left": ' + $r.X + ', "Top": ' + $r.Y + ', "Width": ' + $r.Width + ', "Height": ' + $r.Height + ', "State": "' + $st + '" }'
    Set-Content -LiteralPath $wn.BoundsFile -Value $o -Encoding UTF8
  } catch { $lines.Add('NOTE the window place was not saved: ' + ([string]$_.Exception.Message)) } }
# The check bar (PFM 17 Nov 26): the checks show inside the window, one at a time, with Pass and Fail; no list to remember.
# It sits at the bottom of the window and is always visible. Pass or Fail moves to the next check; the answers go to the result file.
$wn.CheckAt = 0; $wn.Answers = New-Object 'string[]' $Checks.Count
# Shows the current check (its number and text) with Pass and Fail, or the closing line when all are answered.
$wn.BarShow = {
  $i = [int]$wn.CheckAt
  if ($i -lt $Checks.Count) {
    $wn.BarNo.Text = 'Check ' + ($i + 1) + ' of ' + $Checks.Count; $wn.BarText.Text = [string]$Checks[$i].Text
    $wn.BarPass.Visible = $true; $wn.BarFail.Visible = $true }
  else {
    $wn.BarNo.Text = 'Checks'; $wn.BarText.Text = 'All checks done. Close this window with its X.'
    $wn.BarPass.Visible = $false; $wn.BarFail.Visible = $false } }
# Keeps the answer (PASS or FAIL) to the current check and shows the next one.
$wn.Answer = { param([string]$Result)
  if ($wn.CheckAt -ge $Checks.Count) { return }
  $wn.Answers[$wn.CheckAt] = $Result; $wn.CheckAt++
  & $wn.BarShow }
$wn.BarLayout = {
  <#
  .SYNOPSIS
  Lays out the check bar for the window width: the check text at the left, as tall as the longest check needs, and Pass
  and Fail at the right, centered in the bar.
  #>
  if (-not $wn.Bar) { return }
  $w = $form.ClientSize.Width; $pad = & $wn.Sc 16; $gap = & $wn.Sc 8
  $pw = [math]::Max($wn.BarPass.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.BarPass.MinimumSize.Width)
  $fw = [math]::Max($wn.BarFail.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.BarFail.MinimumSize.Width)
  $bh = [math]::Max($wn.BarPass.Height, $wn.BarFail.Height)
  $tw = [math]::Max((& $wn.Sc 200), $w - 2 * $pad - $pw - $fw - 2 * $gap)
  $th = 0; foreach ($c in $Checks) { $m = & $ui.Meas ([string]$c.Text) $ui.F.Body $tw; $th = [math]::Max($th, [int]$m.Height) }
  $th += (& $wn.Sc 6)
  $nh = [int]$wn.BarNo.PreferredSize.Height
  $wn.Bar.Height = [math]::Max($bh + 2 * $pad, $pad + $nh + (& $wn.Sc 2) + $th + $pad)
  $wn.BarNo.Location = [Drawing.Point]::new($pad, $pad)
  $wn.BarText.Location = [Drawing.Point]::new($pad, ($pad + $nh + (& $wn.Sc 2))); & $ui.SetWrap $wn.BarText $tw; $wn.BarText.Size = [Drawing.Size]::new($tw, $th)
  $by = [int](($wn.Bar.Height - $bh) / 2)
  $wn.BarPass.Location = [Drawing.Point]::new(($w - $pad - $fw - $gap - $pw), $by); $wn.BarFail.Location = [Drawing.Point]::new(($w - $pad - $fw), $by) }
$wn.BuildBar = {
  <#
  .SYNOPSIS
  Builds the check bar at the bottom of the window: a line on top, the check number, the check text, Pass and Fail.
  #>
  $bar = New-Object System.Windows.Forms.Panel; $bar.Dock = 'Bottom'; $bar.BackColor = $ui.C.White; $bar.AccessibleName = 'Check bar'
  $bar.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($pc.line, 1); $_.Graphics.DrawLine($pn, 0, 0, $this.ClientSize.Width, 0); $pn.Dispose() } catch { $null = $_ } })
  $no = & $ui.Label $ui.F.SmallB $ui.C.Gray 0; $no.Visible = $true; $no.AccessibleName = 'Check number'; [void]$bar.Controls.Add($no)
  $tx = & $ui.Text $ui.F.Body $ui.C.Ink 0 'Check'; $tx.Visible = $true; [void]$bar.Controls.Add($tx)
  foreach ($n in 'Pass', 'Fail') {
    $x = & $ui.Btn 'action'; $x.Text = $n; & $ui.Style $x ''; $x.AccessibleName = $n; $x.Tag = $n
    $x.Add_SizeChanged({ & $wn.Round $this 4 })
    $x.Add_Click({ $r = ([string]$this.Tag).ToUpperInvariant(); & $wn.Answer $r })
    [void]$bar.Controls.Add($x); if ($n -eq 'Pass') { $wn.BarPass = $x } else { $wn.BarFail = $x } }
  $wn.Bar = $bar; $wn.BarNo = $no; $wn.BarText = $tx
  $form.Controls.Add($bar); $main.BringToFront()
  & $wn.BarShow; & $wn.BarLayout }
# The layout self-check runs 350 ms after a card changed; a new size rebuilds the card 250 ms after the last size change.
$wn.Ready = $false; $wn.LastW = 0; $wn.LastH = 0
$wn.CheckTimer = New-Object System.Windows.Forms.Timer; $wn.CheckTimer.Interval = 350
$wn.CheckTimer.Add_Tick({ $wn.CheckTimer.Stop(); try { & $ui.Check; & $wn.ScrollCheck } catch { $null = $_ } })
$wn.SizeTimer = New-Object System.Windows.Forms.Timer; $wn.SizeTimer.Interval = 250
$wn.SizeTimer.Add_Tick({ $wn.SizeTimer.Stop()
    if ($form.ClientSize.Width -ne $wn.LastW -or $form.ClientSize.Height -ne $wn.LastH) {
      $wn.LastW = $form.ClientSize.Width; $wn.LastH = $form.ClientSize.Height; & $wn.RailLayout; & $wn.Show $wn.Cur } })
$ui.Trash = @($ui.Trash) + @($wn.CheckTimer, $wn.SizeTimer)
# Grid columns wider than their grid, and a main column that scrolls sideways at 1280 or wider, are layout defects; a
# card whose main column scrolls down is noted in $wn.Scrolled.
$wn.ScrollCheck = {
  $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) { foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.DataGridView]) { $sum = 0; foreach ($k in $c.Columns) { if ($k.Visible) { $sum += $k.Width } }
        if ($sum -gt $c.ClientSize.Width + 1) { $ui.LayBad.Add('LAYOUT ' + $wn.Cur + ' grid ' + $c.AccessibleName + ' columns need ' + $sum + ', the grid has ' + $c.ClientSize.Width) } }
      elseif ($c.Controls.Count) { $st.Push($c) } } }
  $logicalW = [int]($form.ClientSize.Width / ([math]::Max(0.5, $ui.Dpi / 96.0)))
  if ($logicalW -ge 1280 -and $main.HorizontalScroll.Visible) { $ui.LayBad.Add('LAYOUT ' + $wn.Cur + ' the main column scrolls sideways at ' + $form.ClientSize.Width + 'x' + $form.ClientSize.Height) }
  if ($main.VerticalScroll.Visible) { $wn.Scrolled[$wn.Cur] = 1 } }
$wn.Scrolled = @{}
$wn.Build = {
  <#
  .SYNOPSIS
  Builds the check bar, the rail and every card once, with the layout self-check, the grid check and the accessible-name
  check on each card; $Each (when given) runs after each card with its key (the -Measure run).
  .DESCRIPTION
  R31 W4: while each card is on the page, a picture of the window is saved ($wn.SavePng, measure part) when
  $wn.PngDir is set. This runs before the person sees the window (it is still clear), so nobody loses their place:
  the last card shown is Your Work, where the window starts.
  .PARAMETER Each
  A script block that gets the card key, or nothing.
  #>
  param([scriptblock]$Each)
  & $wn.BuildBar
  & $wn.BuildRail
  & $wn.State 'shown'
  $wn.LastW = $form.ClientSize.Width; $wn.LastH = $form.ClientSize.Height
  foreach ($k in $Cards.Keys) {
    $wn.Notice = ''; $wn.Err = ''; & $wn.Show $k; [Windows.Forms.Application]::DoEvents(); & $ui.Check; & $wn.ScrollCheck; & $wn.NameScan $k $page
    & $wn.SavePng $k
    if ($Each) { & $Each $k } }
  & $wn.NameScan 'rail' $rail; & $wn.NameScan 'bar' $wn.Bar
  $wn.Notice = ''; $wn.Err = ''; & $wn.Show 'home' }
$wn.Recolor = {
  <#
  .SYNOPSIS
  Paints the window in the colors for the Windows high-contrast setting (R31 W2): the system colors when it is on,
  the window's own palette when it is off.
  .DESCRIPTION
  At the start it only sets the colors (nothing is built yet). On a change while the window is open it rebuilds the
  rail, the check bar (the current check stays) and the card on the page, so every part takes the new colors; nothing
  happens when the setting did not change. Each change adds one CONTRAST line to the result.
  .PARAMETER When
  'start' or 'changed'.
  #>
  param([string]$When)
  $high = [bool][Windows.Forms.SystemInformation]::HighContrast
  if ($When -ne 'start' -and $high -eq [bool]$ui.High) { return }
  & $ui.UseColors $high; $wn.Fills = & $wn.FillsOf
  $form.BackColor = $pc.surface; $main.BackColor = $pc.surface; $page.BackColor = $pc.surface; $rail.BackColor = $pc.navy
  $lines.Add('CONTRAST ' + $When + ': high contrast ' + $(if ($high) { 'on, the window uses the system colors' } else { 'off, the window uses its own colors' }))
  if ($When -eq 'start') { return }
  $form.SuspendLayout()
  foreach ($x in @($rail.Controls)) { $rail.Controls.Remove($x); $x.Dispose() }
  $wn.RailBtn = @(); & $wn.BuildRail
  $form.Controls.Remove($wn.Bar); $wn.Bar.Dispose(); & $wn.BuildBar
  $form.ResumeLayout($true)
  & $wn.Show $wn.Cur; $form.Invalidate($true) }
$wn.Start = {
  <#
  .SYNOPSIS
  Starts the window when it is first shown: its place, its scale, its smallest size, its colors, every card once (with
  the card pictures), then Your Work.
  .DESCRIPTION
  R31 W2: a change of the Windows high-contrast setting while the window is open runs $wn.Recolor; the handler is added
  here, on the window's own thread (so the event comes back on it), and removed when the window closes ($wn.Hook).
  #>
  & $wn.LoadBounds
  & $ui.FormDpi
  $form.MinimumSize = [Drawing.Size]::new((& $wn.Sc 800), (& $wn.Sc 560))
  & $wn.Recolor 'start'
  $wn.PngDir = $dir
  & $wn.Build $null
  & $wn.PngLines
  $wn.Pref = [Microsoft.Win32.UserPreferenceChangedEventHandler]{
    try { & $wn.Recolor 'changed' } catch { $lines.Add('NOTE the colors were not re-applied: ' + ([string]$_.Exception.Message)) } }
  try { [Microsoft.Win32.SystemEvents]::add_UserPreferenceChanged($wn.Pref) } catch { $lines.Add('NOTE no high-contrast change event: ' + ([string]$_.Exception.Message)); $wn.Pref = $null }
  $wn.Ready = $true; $form.Opacity = 1
  try { $form.TopMost = $true; $form.Activate(); $form.TopMost = $false } catch { $null = $_ } }
$wn.Hook = {
  <#
  .SYNOPSIS
  Adds the window's events: start when shown, re-layout on a new size, Esc and Ctrl+1 to Ctrl+5, save the place on close,
  and remove the high-contrast handler of $wn.Start when the window has closed.
  .DESCRIPTION
  Esc opens the card's Up card (back: the card before a modal one); Ctrl+1 to Ctrl+5 open the rail items in order.
  A window that cannot be built adds a STOPPED line, sets exit code 1 and closes.
  #>
  $form.Add_Shown({ try { & $wn.Start } catch {
        $lines.Add('STOPPED: the window could not be built (' + (ConvertTo-Masked ([string]$_.Exception.Message) $who.Secret) + ')'); $script:code = 1; try { $form.Close() } catch { $null = $_ } } })
  $form.Add_SizeChanged({ if ($wn.Ready) { & $wn.BarLayout; $wn.SizeTimer.Stop(); $wn.SizeTimer.Start() } })
  $form.Add_KeyDown({
      if ($_.KeyCode -eq 'Escape') {
        $up = [string]$Cards[$wn.Cur].Up; if ($up -eq 'back') { $up = $wn.Prev }
        if ($up -and $wn.Cur -ne 'home') { $wn.Notice = ''; $wn.Err = ''; & $wn.Show $up }
        $_.Handled = $true; $_.SuppressKeyPress = $true }
      elseif ($_.Control -and $_.KeyCode -ge [Windows.Forms.Keys]::D1 -and $_.KeyCode -le [Windows.Forms.Keys]::D5) {
        $n = [int]$_.KeyCode - [int][Windows.Forms.Keys]::D1; $wn.Notice = ''; $wn.Err = ''; & $wn.Show ([string]$RailItems[$n].Go); $_.Handled = $true; $_.SuppressKeyPress = $true } })
  $form.Add_FormClosing({ & $wn.State 'close'; & $wn.SaveBounds })
  $form.Add_FormClosed({ if ($wn.Pref) { try { [Microsoft.Win32.SystemEvents]::remove_UserPreferenceChanged($wn.Pref) } catch { $null = $_ }; $wn.Pref = $null } }) }
