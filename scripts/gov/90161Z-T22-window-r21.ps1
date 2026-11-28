<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "window": the rail, the cards, the check bar, the window size and place, and the window's
  events of the PFM window.
.DESCRIPTION
  R17 (round R44 T4; the PFM, 26 Nov 26): the name in the rail head, at the logo, is "Kanon" ($wn.HeadParts). The line
  under it keeps its text. The RADE engine sets the titles and name of the RADE window; this part sets only this window's.
  R14 (R41; PFM 20 Nov 26, docs/reviews/2026-11-21-r41-plan.md rows 3 and 4): the check bar moved to the bar part (it
  holds the click-through too); the layout self-check line names the open (first, kept, rebuild, resize: $wn.OpenKind),
  and the check waits for the layout to settle and fits the grids again when a fit changed one (R40 finding 3).
  R13 (R40; PFM 20 Nov 26, R39 finding 2): $wn.Show shows the kept page of a card when it can, and builds the card
  ($wn.ShowBuild) only when it must change; the keep part holds the kept pages, their rules and the CARDTIME lines.
  $wn.LastKey reads the card saved at the last close (for $wn.OpenLast and the -Again check).
  R11 (R38; PFM 20 Nov 26): the layout self-check tests the grid edges against the scroll bar (R11 LAYOUT line); the logo and
  THEME lines name Fulcrum in both modes; the checks are the 3 of the cards part.
  $wn.ShowBuild builds one card: the head (notice, crumb, title), then its columns of sections. R4 (R30): the crumb is one
  line in one font (V2: its link is a Build-PfmLinkText button in the crumb's font, underlined, with no padding); the last cards of
  the columns end on one line when the card has an Action Status card (V4). $wn.Build builds every card once (layout
  self-check, grid check, the accessible-name check of the measure part) and $wn.Hook adds the window's events.
  R5 (R31): the rail logo sits on the rail's navy and the app name is centered on the logo's middle (W1, $wn.HeadParts);
  with Windows high contrast on the window paints with the system colors, also after a change while it is open (W2,
  $wn.Recolor); $wn.Build saves a picture of each card through the measure part (W4).
  R6 (R31b): the caption "ACTION STATUS" is level with the first line of the main card (D1, $wn.LevelCaps); the rest of
  the crumb has the link's text middle (D2, $wn.Crumb).
  R7 (R32): the mouse wheel scrolls a card from anywhere on it (W2, $wn.WheelOn, Add-PfmWheel in the types part); the
  NOTICE chip is level with its note (W3, $wn.ShowNotice).
  R8 (R35 W7, R34 finding 7): with high contrast on, the rail logo is drawn in 2 system colors and back in its own
  colors when it goes off ($wn.LogoImage); each rail build checks the logo it shows ($wn.LogoFacts and $wn.LogoBad in
  the measure part: a LOGO line, and a LAYOUT line when the logo has the wrong colors).
  The rail logo pictures and their choice are in the logo part (R10: $wn.LogoImage, $wn.LogoRole, $wn.AppsLight; R11: one Fulcrum logo).
  Inputs: $form, $main, $page, $rail, $ui, $wn, $pc, $Cards, $RailItems, $Rev, $dir, $lines.
  Outputs: the $wn members below. The window place is saved in 90161Z-T22-window-bounds-r21.json in the task folder.
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: 90161Z-T22-window-bounds-r21.json in the T22 folder (or -TestDir), when the window closes; nothing with -Measure.
  R10 (R37): the Feedback link on the check bar (its box and files: the feedback part); the rail logo follows the Windows
  app mode (the logo part); a grid wider than its room gives the excess back ($wn.FitGrids in the grid part).
  Credentials: none.
#>
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
  if (-not (& $ui.Settled)) { & $wn.IgnoreNote ('the button ' + [string]$B.Text); return }   # R16: a dropped click leaves a NOTE line (bar part)
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
  if (-not $go) { $go = $wn.Cur }
  try { & $wn.Show $go } catch { & $wn.OpenFail $go $_ }   # R15: a NOTE line when the open stops (bar part)
  & $wn.OpenCheck $go }   # R16: and when it returns with no error and the window stays on the old card
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
  R8 (R35 W7): the logo picture follows the high-contrast setting ($wn.LogoImage $ui.High).
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
    $logo.Image = & $wn.LogoImage ([bool]$ui.High); [void]$Into.Controls.Add($logo); $out.Logo = $logo
  } catch { $lines.Add('NOTE logo not shown: ' + $_.Exception.Message) }
  $nm = & $ui.Label $WordFont $ui.C.White 0; $nm.BackColor = $pc.navy; $nm.Text = 'Kanon'; $nm.Visible = $true
  $nh = [int]$nm.PreferredSize.Height
  $nm.Location = [Drawing.Point]::new((& $wn.Sc 64), ($top + [int][math]::Round(($side - $nh) / 2.0)))
  [void]$Into.Controls.Add($nm); $out.Name = $nm
  return $out }
# The rail head: the logo and the app name ($wn.HeadParts; kept in $wn.Logo and $wn.AppName for the measure part) and the
# line under them. R8 (R35 W7): then the logo check: one LOGO line, and a LAYOUT line when its colors are wrong.
$wn.RailHead = {
  $h = & $wn.HeadParts $rail $ui.F.Word; $wn.Logo = $h.Logo; $wn.AppName = $h.Name
  try { $lf = & $wn.LogoFacts; $bad = @(& $wn.LogoBad $lf); foreach ($x in $bad) { $ui.LayBad.Add([string]$x) }
    $own = 'high contrast off: own colors (Fulcrum, light and dark mode)'
    if ($lf.Shown) { $lines.Add('LOGO ' + $(if ($lf.High) { 'high contrast on: system colors' } else { $own }) + ', other pixels ' + $lf.Other +
        ', changed pixels ' + $lf.Diff + $(if ($bad.Count) { ' (wrong colors)' } else { ' (right colors)' })) } }
  catch { $lines.Add('NOTE the logo check stopped: ' + ([string]$_.Exception.Message)) }
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
    $x = Build-PfmRailItem; $x.Text = $r.Text; $x.AccessibleName = $r.Text; $x.Tag = $r.Key; $x.Font = $ui.F.Body; $x.BoldFont = $ui.F.SmallB
    $x.Back = $pc.navy; $x.OnBack = $ui.C.White; $x.Fore = $pc.onPrimaryMuted; $x.OnFore = $pc.navy; $x.HotLine = $pc.onPrimaryMuted; $x.FocusLine = $pc.accentFill
    $x.FocusOn = $pc.navy; $x.BadgeFill = $pc.accentFill; $x.BadgeText = $pc.ink; $x.BackColor = $x.Back; $x.ForeColor = $x.Fore   # R11 (B10)
    if ($r.Badge) { $x.Badge = [string]$r.Badge; $x.AccessibleName = $r.Text + ', ' + $r.Badge + ' items need you' }
    $x.Size = [Drawing.Size]::new(((& $wn.Sc 200) - 2 * (& $wn.Sc 12)), (& $wn.Sc 44)); $x.Location = [Drawing.Point]::new((& $wn.Sc 12), $y); $y += (& $wn.Sc 48)
    # R16 (R42 finding 5: Reviews Due sometimes needed 2 clicks): the 400 ms guard after a card changed (it stops the second click of
    # a double-click) holds a rail click only when it opens the card that shows now; a click that opens another card is not held.
    $x.Add_Click({ $key = [string]$this.Tag; $go = 'home'; foreach ($q in $RailItems) { if ($q.Key -eq $key) { $go = $q.Go } }
        if (-not (& $ui.Settled) -and $go -eq $wn.Cur) { & $wn.IgnoreNote ('the list item ' + $this.Text); return }
        $script:presses++; $wn.Notice = ''; $wn.Err = ''
        try { & $wn.Show $go } catch { & $wn.OpenFail $go $_ }
        & $wn.OpenCheck $go })
    [void]$rail.Controls.Add($x); $wn.RailBtn += $x }
  $src = $(if ($script:SiteSource -eq 'site') { 'Test site data' } else { 'FAKE data' })   # R14: the source of the cards (site part)
  $ft = & $ui.Label $ui.F.Small $pc.onPrimaryMuted 0; $ft.BackColor = $pc.navy; $ft.Text = $src + [Environment]::NewLine + 'Preview ' + $Rev; $ft.Visible = $true; $ft.Anchor = 'Left, Bottom'
  $ft.Location = [Drawing.Point]::new((& $wn.Sc 16), ($rail.ClientSize.Height - (& $wn.Sc 56))); [void]$rail.Controls.Add($ft)
  $rail.ResumeLayout($true); & $wn.RailLayout }
$wn.Crumb = {
  <#
  .SYNOPSIS
  The crumb line of a card: its first part as a link, the rest as text, in one font and size (R30 V2).
  .DESCRIPTION
  The link is a Build-PfmLinkText button: the crumb's own font (the small text font) underlined, the link blue, no padding, so its
  size is its text. The rest starts with the arrow, a small gap after the link (3 px at 100 %, room for the focus ring),
  so the gap from the link's text to the arrow stays under 8 px at 100 %. A crumb with no link is one text.
  R6 (R31b D2): the link draws its text in its vertical middle; the rest's top gap is set so that the middle of its
  line is the link's middle (within half a pixel, at any scale), so both parts sit on one line.
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
  $l = Build-PfmLinkText; $l.Text = $parts[0]; $l.Font = $wn.CrumbFont; $l.ForeColor = $ui.C.Blue; $l.BackColor = $pc.surface
  $l.AutoSize = $true; $l.AutoSizeMode = 'GrowAndShrink'
  $l.MinimumSize = [Drawing.Size]::new(0, (& $wn.Sc $ui.Z.LinkH)); Resize-PfmLinkText $l   # R21: the maximum size makes the preferred size the text's
  $l.Margin = & $ui.Pad (& $wn.Sc $ui.Z.M) (& $wn.Sc $ui.Z.M) 0 (& $wn.Sc $ui.Z.M)
  $l.AccessibleName = $parts[0]; $l.AccessibleRole = 'Link'; $l.Tag = @{ Text = $parts[0]; Go = $C.CrumbGo }
  $l.Add_Click({ & $wn.Press $this.Tag }); & $ui.Cue $l; [void]$cf.Controls.Add($l); $wn.CrumbLink = $l
  $rest = $gt + ' ' + ((@($parts | Select-Object -Skip 1)) -join (' ' + $gt + ' '))
  $t = & $wn.Txt $cf $rest $ui.F.Small $ui.C.Gray 8 ($Cw - (& $wn.Sc 160)) 'Where you are' $pc.surface
  # The link's middle from the row top: its top gap and half its height (its preferred height, as the flow sizes it).
  $mid = $l.Margin.Top + $l.GetPreferredSize([Drawing.Size]::Empty).Height / 2.0
  $top = [int][math]::Max(0, [math]::Round($mid - (& $wn.LineH $t.Font) / 2.0))
  $t.Margin = & $ui.Pad (& $wn.Sc 3) $top 0 0; $wn.CrumbRest = $t
  return $t }
# The FAKE note of the last button: the NOTICE chip and the note beside it, the chip level with the note's first line
# (R7 W3, $wn.ChipTops). $Cw: the width of the page column.
$wn.ShowNotice = { param([int]$Cw)
  $nf = & $wn.Flow $page $pc.surface; $nf.Margin = & $ui.Pad 0 0 0 (& $wn.Sc 10); $cp = & $wn.Chip 'turn' 'NOTICE' $pc.surface; [void]$nf.Controls.Add($cp)
  $nt = & $wn.Txt $nf $wn.Notice $ui.F.Body $ui.C.Ink 0 ($Cw - (& $wn.Sc 120)) 'Notice' $pc.surface
  $tops = & $wn.ChipTops $cp.Height $nt.Font 0; $nt.Margin = & $ui.Pad 0 $tops.Text 0 0; $cp.Margin = & $ui.Pad 0 $tops.Chip $cp.Margin.Right 0
  & $wn.KeepChip $cp $nt 'notice' }
# The head of a card: the FAKE note of the last button, the crumb, the title and the line under it. Sets $ui.Sent and
# $ui.Kick (the title and the line the layout self-check reads).
$wn.ShowHead = { param($C, [int]$Cw)
  $title = $null
  if ($wn.Notice) { & $wn.ShowNotice $Cw }
  if ($C.Crumb) { $title = & $wn.Crumb $C $Cw }
  if ($C.Title) { $title = & $wn.Txt $page $C.Title $ui.F.Sent $ui.C.Navy 0 $Cw 'Page title' $pc.surface }
  if ($C.Sub) { $ui.Kick = & $wn.Txt $page $C.Sub $ui.F.Small $ui.C.Gray 4 $Cw 'Page line' $pc.surface } else { $ui.Kick = $title }
  $ui.Sent = $title }
$wn.ShowCols = {
  <#
  .SYNOPSIS
  The columns of a card: one column, or a main column and a side column; each section is a card with its blocks.
  .DESCRIPTION
  Each section built is kept in $wn.Secs (column number, card, caption, Stretch, caption box) for $wn.LevelCaps,
  $wn.Align and the measure part.
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
      # CapBox: the caption text box, the card's first child when it has a caption ($wn.Card adds it first).
      $wn.Secs += @{ Col = $ci; Card = $sec; Cap = [string]$s.Cap; Stretch = [bool]$s.Stretch; CapBox = $(if ($s.Cap) { $sec.Controls[0] } else { $null }) }
      $iw = $colW - 2 * (& $wn.Sc $px)
      foreach ($b in @($s.Blocks)) { & $wn.Block $sec $b $iw $ctx }
      $sec.PerformLayout() }
    $ci++ } }
# The first line of text of a section card: the first card text box in the order its parts were added, looking inside
# a row (the chips row holds the step line). Gives back the text box, or $null.
$wn.FirstLine = { param($Sec)
  foreach ($c in $Sec.Controls) {
    if (& $ui.IsCardText $c) { return $c }
    if ($c.Controls.Count) { $in = & $wn.FirstLine $c; if ($in) { return $in } } }
  return $null }
$wn.LevelCaps = {
  <#
  .SYNOPSIS
  R6 (R31b D1): the caption of each Action Status card (Stretch) is level with the first line of the main card beside it.
  .DESCRIPTION
  The columns start at one top, so the two middles compare directly ($wn.TextMid, page pixels). The higher of the two
  moves down by the difference, rounded to a pixel: the caption by its top gap, or (when the caption is the lower one)
  the main card's first part. Then the page lays out again; $wn.Align runs after this and lines up the bottoms.
  #>
  $mainSec = @($wn.Secs | Where-Object { $_.Col -eq 0 }) | Select-Object -First 1
  if (-not $mainSec) { return }
  $line = & $wn.FirstLine $mainSec.Card; if (-not $line) { return }
  $moved = $false
  foreach ($s in @($wn.Secs | Where-Object { $_.Stretch -and $_.CapBox })) {
    $d = [int][math]::Round((& $wn.TextMid $line) - (& $wn.TextMid $s.CapBox))
    if ($d -eq 0) { continue }
    $mv = $(if ($d -gt 0) { $s.CapBox } else { $mainSec.Card.Controls[0] })
    $m = $mv.Margin; $mv.Margin = & $ui.Pad $m.Left ($m.Top + [math]::Abs($d)) $m.Right $m.Bottom
    $s.Card.PerformLayout(); $mainSec.Card.PerformLayout(); $moved = $true }
  if ($moved) { $page.PerformLayout() } }
# R30 V4: in a card with an Action Status card (Stretch), the last cards of the columns end on one line: the shorter one
# grows to the bottom of the longer one. The columns start at one top, so their bottoms compare directly.
$wn.Align = {
  if (-not @($wn.Secs | Where-Object { $_.Stretch }).Count) { return }
  $last = @{}; foreach ($s in $wn.Secs) { $last[$s.Col] = $s }
  if ($last.Count -lt 2) { return }
  $low = 0; foreach ($s in $last.Values) { $low = [math]::Max($low, $s.Card.Parent.Top + $s.Card.Bottom) }
  foreach ($s in $last.Values) { $d = $low - ($s.Card.Parent.Top + $s.Card.Bottom); if ($d -gt 0) { $s.Card.MinimumSize = [Drawing.Size]::new($s.Card.MinimumSize.Width, $s.Card.Height + $d) } }
  $page.PerformLayout() }
$wn.ShowBuild = {
  <#
  .SYNOPSIS
  Builds card $Key on a new page: the head and the columns, the side captions level (D1), the column bottoms in line.
  .DESCRIPTION
  R13 (R40): the card goes on its own new page ($wn.NewPage, keep part), which replaces the page shown; the old kept
  page of this card, if any, goes first ($wn.KeepDrop). The new page is kept ($wn.KeepSave) for the next open.
  .PARAMETER C
  The card data.
  .PARAMETER Key
  The card key.
  .PARAMETER Cw
  The width of the page column.
  .PARAMETER Sig
  What the card is built for ($wn.KeepSig).
  #>
  param($C, [string]$Key, [int]$Cw, [string]$Sig)
  $wn.Primary = $null; $wn.Gridsel = $null; $wn.Gridq = $null; $wn.Reason = $null; $wn.CountBox = $null; $wn.CrumbLink = $null; $wn.CrumbRest = $null; $wn.Secs = @(); $wn.ChipRows = @()
  $ui.Wrap = @{}; $ui.Boxes = @()
  & $wn.KeepDrop $Key
  & $wn.PageSwap (& $wn.NewPage)
  $page.SuspendLayout()
  $page.Location = [Drawing.Point]::new($wn.PadX, (& $wn.Sc 22)); $page.Margin = & $ui.Pad 0 0 0 0; $page.Padding = & $ui.Pad 0 0 0 (& $wn.Sc 22)
  & $wn.ShowHead $C $Cw
  $page.PerformLayout(); $wn.HeadH = [int]$page.PreferredSize.Height
  & $wn.ShowCols $C $Key $Cw $wn.Wide
  $page.ResumeLayout($true); $form.ResumeLayout($true)
  & $wn.LevelCaps; & $wn.Align
  $null = & $wn.FitGrids   # R10 (R37): a grid whose columns are wider than it gives the excess back
  & $wn.KeepSave $Key $Sig }
$wn.Show = {
  <#
  .SYNOPSIS
  Shows the card $Key: its kept page when that was built for this size, note and error line, else a new build.
  .DESCRIPTION
  A new card forgets the fields of the last one (a modal card remembers the card to go back to). The main button gets
  the focus (or the reason box after an empty reason) and the Enter key. The layout self-check runs a moment later.
  R13 (R40, R39 finding 2): the card already shown is always built again (a note, an error line, a resize); another
  card shows its kept page when $wn.KeepFind has one (no control is built: the open is a hide and a show), else it is
  built ($wn.ShowBuild). The rules: the keep part's header. The page column width comes from the main column's full
  width, with or without its scroll bar, so it does not depend on the card shown before (r12 measured the width that
  was left beside the last card's scroll bar).
  R14 (R41; R40 finding 3): $wn.OpenKind names the open (first, kept, rebuild, resize) for the layout self-check line.
  .PARAMETER Key
  The card key in $Cards; an unknown key does nothing.
  #>
  param([string]$Key)
  $c = $Cards[$Key]; if (-not $c) { $lines.Add('NOTE the screen ' + $Key + ' did not open: no such screen in the window'); return }   # R16: no silent return
  $t0 = $ui.Clock.Elapsed.TotalMilliseconds   # R12 (R38 finding 3): the open time of a card the person opens
  $again = ($Key -eq $wn.Cur)
  if (-not $again) { & $wn.KeepLeave; if ($c.Modal) { $wn.Prev = $wn.Cur }; $wn.Field = @{}; $wn.Err = ''; $wn.Focus = '' }
  $script:cardsOpened[$Key] = $true; $wn.Cur = $Key; $ui.View = $Key
  $ui.Hot = $null; $ui.Down = $null
  # R7 (W2): the main column goes back to its top first, so the page is placed in unscrolled pixels (placed while the
  # column was scrolled, the page kept that offset and the new card started lower, with empty space above it).
  $main.AutoScrollPosition = [Drawing.Point]::new(0, 0)
  $form.SuspendLayout()
  $wide = ($form.ClientSize.Width -ge (& $wn.Sc 1500)); $wn.Wide = $wide
  $wn.MainH = $main.ClientSize.Height; $padX = & $wn.Sc 28; $wn.PadX = $padX
  $cw = [math]::Max((& $wn.Sc 900), $main.Width - [Windows.Forms.SystemInformation]::VerticalScrollBarWidth - 2 * $padX)
  # R11 (UI standard v1, B10): ForeColor and BackColor hold the painted colors, so the contrast rule reads what shows
  foreach ($r in $wn.RailBtn) { $r.On = ([string]$r.Tag -eq [string]$c.Rail)
    $r.BackColor = $(if ($r.On) { $r.OnBack } else { $r.Back }); $r.ForeColor = $(if ($r.On) { $r.OnFore } else { $r.Fore }); $r.Invalidate() }
  $sig = & $wn.KeepSig $cw
  $kept = $(if ($again) { $null } else { & $wn.KeepFind $Key $sig }); $wn.KeepUsed = [bool]$kept
  # R14 (R41; R40 finding 3): which open this is, for the layout self-check line (first, kept, rebuild, resize)
  $wn.OpenKind = $(if ($wn.Resizing) { 'resize' } elseif ($kept) { 'kept' } elseif ($again -or $wn.Kept[$Key]) { 'rebuild' } else { 'first' }); $wn.FitTries = 0
  if ($kept) {   # R13: the kept page: its state back, the page shown in place of the last one, at the top, grids reset
    & $wn.KeepLoad $kept; & $wn.PageSwap $kept.Page
    $page.Location = [Drawing.Point]::new($padX, (& $wn.Sc 22)); & $wn.KeepReset $kept
    $form.ResumeLayout($true) }
  else { & $wn.ShowBuild $c $Key $cw $sig }
  $main.AutoScrollPosition = [Drawing.Point]::new(0, 0)
  $form.AcceptButton = $wn.Primary
  $ui.CardAt = $ui.Clock.Elapsed.TotalMilliseconds
  if ($wn.Focus -eq 'reason' -and $wn.Reason) { [void]$wn.Reason.Focus(); $wn.Focus = '' } elseif ($wn.Primary) { [void]$wn.Primary.Focus() }
  if ($wn.Ready) { $wn.CheckTimer.Stop(); $wn.CheckTimer.Start(); & $wn.KeepTime $Key $t0; & $wn.WalkSeen $Key } }   # R14: the click-through notes the open
# Where the window place is kept between runs (none with -Measure: no task folder).
# r21 (F6): new file name, so a place saved by r20 (DPI aware, physical pixels) is not read as logical pixels now.
$wn.BoundsFile = $(if ($dir) { Join-Path $dir '90161Z-T22-window-bounds-r21.json' } else { '' })
# R12 (R39; docs/phases.md): the card the window was closed on, opened again at the next start (none with -Measure).
$wn.LastFile = $(if ($dir) { Join-Path $dir '90161Z-T22-window-lastcard.txt' } else { '' })
# R13 (R40): the card key saved at the last close, or '' when there is none ($wn.OpenLast; the -Again check names it).
$wn.LastKey = {
  try { if ($wn.LastFile -and (Test-Path -LiteralPath $wn.LastFile -PathType Leaf)) { return ([string](Get-Content -LiteralPath $wn.LastFile -TotalCount 1)).Trim() } } catch { $null = $_ }
  return '' }
$wn.SaveLast = {
  <#
  .SYNOPSIS
  R12: saves the card the window shows at its close (for a modal card, the card it came from) for the next start.
  #>
  try {
    if (-not $wn.LastFile) { return }
    $k = $(if ($Cards[$wn.Cur] -and $Cards[$wn.Cur].Modal) { [string]$wn.Prev } else { [string]$wn.Cur })
    if ($Cards[$k]) { Set-Content -LiteralPath $wn.LastFile -Value $k -Encoding UTF8 }
  } catch { $lines.Add('NOTE the last card was not saved: ' + ([string]$_.Exception.Message)) } }
$wn.OpenLast = {
  <#
  .SYNOPSIS
  R12: shows the card saved at the last close, when it is a card that is not modal; else Your Work stays. Adds a
  LASTCARD line: the card opened, and where it came from.
  #>
  $k = & $wn.LastKey
  if ($k -and $Cards[$k] -and -not $Cards[$k].Modal) {
    if ($k -ne 'home') { $wn.Notice = ''; $wn.Err = ''; & $wn.Show $k }
    $lines.Add('LASTCARD opened=' + $k + ' (saved at the last close)') }
  else { $lines.Add('LASTCARD opened=home (' + $(if ($k) { 'saved card ' + $k + ' not used' } else { 'no saved card' }) + ')') } }
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
# The check bar (the checks and, R14, the click-through) is in the bar part.
# The layout self-check runs 350 ms after a card changed; a new size rebuilds the card 250 ms after the last size change.
# R14 (R41; R40 finding 3, "columns need 811, the grid has 801" after a resize or a rebuild): when the grid fit of the
# tick changed a grid, the check waits one more tick for the layout to settle and fits again (at most 3 more ticks).
$wn.Ready = $false; $wn.LastW = 0; $wn.LastH = 0; $wn.OpenKind = 'first'; $wn.FitTries = 0; $wn.Resizing = $false
$wn.CheckTimer = New-Object System.Windows.Forms.Timer; $wn.CheckTimer.Interval = 350
$wn.CheckTimer.Add_Tick({ $wn.CheckTimer.Stop(); try {
      if ((& $wn.FitGrids) -gt 0 -and $wn.FitTries -lt 3) { $wn.FitTries++; $wn.CheckTimer.Start(); return }
      $wn.FitTries = 0; & $ui.Check; & $wn.ScrollCheck } catch { $null = $_ } })
# R14: fits the grids of the card on the page until a fit changes nothing (at most 3 fits, the layout settles between).
$wn.FitSettled = { for ($i = 0; $i -lt 3; $i++) { if (-not (& $wn.FitGrids)) { break }; [Windows.Forms.Application]::DoEvents() } }
$wn.SizeTimer = New-Object System.Windows.Forms.Timer; $wn.SizeTimer.Interval = 250
$wn.SizeTimer.Add_Tick({ $wn.SizeTimer.Stop()
    if ($form.ClientSize.Width -ne $wn.LastW -or $form.ClientSize.Height -ne $wn.LastH) {
      $wn.LastW = $form.ClientSize.Width; $wn.LastH = $form.ClientSize.Height; & $wn.RailLayout
      $wn.Resizing = $true; try { & $wn.Show $wn.Cur } finally { $wn.Resizing = $false } } })
$ui.Trash = @($ui.Trash) + @($wn.CheckTimer, $wn.SizeTimer)
# Grid columns wider than their grid, and a main column that scrolls sideways at 1280 or wider, are layout defects; a
# card whose main column scrolls down is noted in $wn.Scrolled.
$wn.ScrollCheck = {
  <#
  .SYNOPSIS
  The layout self-check of the card on the page: grids wider than themselves, the content of a grid ending closer to its
  right edge than a scroll bar is wide (R11), a main column that scrolls sideways at 1280 or wider.
  .DESCRIPTION
  Adds one LAYOUT line to $ui.LayBad for each defect; a card whose main column scrolls down is noted in $wn.Scrolled.
  .OUTPUTS
  None.
  #>
  $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) { foreach ($c in $st.Pop().Controls) {
      if ($c -is [Windows.Forms.DataGridView]) { $sum = 0; $mn = 0; foreach ($k in $c.Columns) { if ($k.Visible) { $sum += $k.Width; $mn += $k.MinimumWidth } }
        # R14 (R41): which open it was; R16 (R43 T1): and the sum of the column minimums, to tell a fit that did not run from a fill that overflowed
        if ($sum -gt $c.ClientSize.Width + 1) { $ui.LayBad.Add('LAYOUT ' + $wn.Cur + ' grid ' + $c.AccessibleName + ' columns need ' + $sum + ', the grid has ' +
            $c.ClientSize.Width + ' (column minimums ' + $mn + ')' + ' (open: ' + $wn.OpenKind + ')') }
        $edge = & $wn.EdgeCheck $c $wn.Cur   # R11 (R38): no chip or text ends closer than a scroll bar's width to the grid's right edge
        if ($edge) { $ui.LayBad.Add($edge) } }
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
    $wn.Notice = ''; $wn.Err = ''; & $wn.Show $k; [Windows.Forms.Application]::DoEvents(); & $wn.FitSettled; & $ui.Check; & $wn.ScrollCheck; & $wn.NameScan $k $page
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
  'start' or 'changed' (R8: or a name the measure part gives). R10 (R37): a change of the Windows app mode (light or
  dark) adds one THEME line; R11 (R38): it no longer rebuilds, the logo is the Fulcrum one in both modes.
  .PARAMETER Force
  R8 (R35 W7): $true or $false to use instead of the Windows setting (the measure part rebuilds the window both ways
  with no change of the Windows theme); $null: the Windows setting.
  #>
  param([string]$When, $Force = $null)
  $high = $(if ($null -ne $Force) { [bool]$Force } else { [bool][Windows.Forms.SystemInformation]::HighContrast })
  $light = [bool](& $wn.AppsLight)   # R10 (R37): the logo follows the Windows app mode too
  $highNew = ($When -eq 'start' -or $high -ne [bool]$ui.High); $lightNew = ($When -eq 'start' -or $light -ne [bool]$wn.Light)
  if (-not $highNew -and -not $lightNew) { return }
  $wn.Light = $light
  & $ui.UseColors $high; $wn.Fills = & $wn.FillsOf
  $form.BackColor = $pc.surface; $main.BackColor = $pc.surface; $page.BackColor = $pc.surface; $rail.BackColor = $pc.navy
  if ($highNew) { $lines.Add('CONTRAST ' + $When + ': high contrast ' + $(if ($high) { 'on, the window uses the system colors' } else { 'off, the window uses its own colors' })) }
  if ($lightNew) { $lines.Add('THEME ' + $When + ': Windows apps use ' + $(if ($light) { 'light mode, the logo has the Fulcrum colors' } else { 'dark mode, the logo has the Fulcrum colors too' }) +
      $(if ($high) { ' (shown in the system colors while high contrast is on)' } else { '' })) }
  if ($When -eq 'start' -or -not $highNew) { return }   # R11: an app mode change alone changes no color of the window
  $form.SuspendLayout()
  foreach ($x in @($rail.Controls)) { $rail.Controls.Remove($x); $x.Dispose() }
  $wn.RailBtn = @(); & $wn.BuildRail
  $form.Controls.Remove($wn.Bar); $wn.Bar.Dispose(); & $wn.BuildBar
  $form.ResumeLayout($true)
  & $wn.KeepClear   # R13: every kept card has the old colors; each builds again at its next open
  & $wn.Show $wn.Cur; $form.Invalidate($true) }
# R7 (R32 W2; R21: MouseWheel handlers, no message filter): a wheel turn anywhere on the main column scrolls the grid under
# the pointer while that grid can still scroll, else the main column; keys and focus are not touched (Add-PfmWheel).
# Puts the handlers on the window and its controls, also on those added later; a failure is a NOTE line, not a stop.
$wn.WheelOn = {
  try { Add-PfmWheel $form $main; $lines.Add('WHEEL on: the mouse wheel scrolls what is under the pointer') }
  catch { $lines.Add('NOTE the mouse-wheel handlers did not start: ' + ([string]$_.Exception.Message)) } }
$wn.Start = {
  <#
  .SYNOPSIS
  Starts the window when it is first shown: its place, its scale, its smallest size, its colors, every card once (with
  the card pictures), then Your Work.
  .DESCRIPTION
  R31 W2: a change of the Windows high-contrast setting while the window is open runs $wn.Recolor; the handler is added
  here, on the window's own thread (so the event comes back on it), and removed when the window closes ($wn.Hook).
  R7 (R32 W2): the mouse-wheel handlers start here ($wn.WheelOn); they go with the window when it closes.
  #>
  & $wn.LoadBounds
  & $ui.FormDpi; $ui.Scaled = $true   # R11 (UI standard v1): the form has its scale now, as RADE's window sets it; button sizes follow it
  $form.MinimumSize = [Drawing.Size]::new((& $wn.Sc 800), (& $wn.Sc 560))
  & $wn.Recolor 'start'
  $wn.PngDir = $dir
  & $wn.Build $null
  & $wn.PngLines
  $wn.Pref = [Microsoft.Win32.UserPreferenceChangedEventHandler]{
    try { & $wn.Recolor 'changed' } catch { $lines.Add('NOTE the colors were not re-applied: ' + ([string]$_.Exception.Message)) } }
  try { [Microsoft.Win32.SystemEvents]::add_UserPreferenceChanged($wn.Pref) } catch { $lines.Add('NOTE no high-contrast change event: ' + ([string]$_.Exception.Message)); $wn.Pref = $null }
  & $wn.WheelOn
  & $wn.OpenLast   # R12: the card of the last close (before Ready, so its open is not counted as the person's)
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
  $form.Add_FormClosing({ & $wn.State 'close'; & $wn.SaveBounds; & $wn.SaveLast; & $wn.TimeLines; & $wn.FeedbackList })
  $form.Add_FormClosed({ if ($wn.Pref) { try { [Microsoft.Win32.SystemEvents]::remove_UserPreferenceChanged($wn.Pref) } catch { $null = $_ }; $wn.Pref = $null } }) }
