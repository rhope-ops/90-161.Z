<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "bar": the check bar of the PFM window, with the in-window checks and the click-through of
  every screen (round R41; PFM 20 Nov 26, docs/reviews/2026-11-21-r41-plan.md row 3).
.DESCRIPTION
  The check bar (PFM 17 Nov 26) sits at the bottom of the window and is always visible: the checks show one at a time,
  with Pass and Fail; no list to remember. Pass or Fail moves to the next step; the answers go to the result file.
  R14 moved it here from the window part (600-line cap) and adds the click-through: after the 4 checks of the cards
  part ($Checks), one step per card ($Walk, Get-WalkPlan in the cards part), in order. Each step names the one rail
  item, button or crumb link that opens the next card from the card before it; a card that no such selection opens
  gets the link "Open this screen" on the bar, shown only on its step. The window notes each card the person opens
  while its step is shown ($wn.WalkSeen, called by $wn.Show in the window part). A step passes when the person
  selected Pass while the card had been opened on that step; Pass on a card that was not opened is a FAIL (not
  opened). Feedback (the feedback part) stays on the bar on every screen. -Again has no click-through ($Walk is empty).
  R15 (R42 T1; R41 finding 4: screens 10 and 11 did not open): "Open this screen" also shows while the screen shown is not
  the one a button step starts on ($wn.OpenShow), and an open by the person that stops adds a NOTE line ($wn.OpenFail).
  R17 (round R44 T4; R43 findings 4 and 6): the step text never reaches the links "Open this screen" and "Feedback": the text
  has the room that is left (no least width that can push it onto a link), the links are in front of it, and a text box that
  is wider than its room is cut back after each step ($wn.BarLayout, $wn.BarFit); the card that shows when the click-through
  starts counts as opened for walk step 1 ($wn.BarShow).
  Inputs: $form, $main, $ui, $wn, $pc, $Cards, $Checks, $Walk, $lines. Outputs: the $wn members below and, at the end
  of a run, the WALK lines ($wn.WalkLines; the main script adds them to the result).
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: none.
  Credentials: none.
#>
# The steps of the bar: the checks, then the click-through. $wn.CheckAt is the step shown; the answers are kept by step.
$wn.CheckAt = 0; $wn.Answers = New-Object 'string[]' $Checks.Count
$wn.WalkAns = New-Object 'string[]' $Walk.Count; $wn.WalkOpen = New-Object 'bool[]' $Walk.Count
# The number of steps on the bar.
$wn.StepCount = { return ($Checks.Count + $Walk.Count) }
# The click-through step shown ($Walk index), or -1 while a check (or the closing line) is shown.
$wn.WalkAt = { $j = [int]$wn.CheckAt - $Checks.Count; if ($j -ge 0 -and $j -lt $Walk.Count) { return $j }; return -1 }
# R14: notes that card $Key opened while its click-through step is shown (the person opened it; $wn.Show calls this).
$wn.WalkSeen = { param([string]$Key) $j = & $wn.WalkAt; if ($j -ge 0 -and [string]$Walk[$j].Key -eq $Key) { $wn.WalkOpen[$j] = $true }; & $wn.OpenShow; & $wn.FrameSet }
# R18 (the PFM, 26 Nov 26, R45 comment 6b): a step that names one part of the screen has Target (the accessible name of its control; the
# cards part, Get-WalkPlan). While that step and its card show, the control has a 2 px frame in the primary blue (docs/palette.json).
# The frame is drawn by the control's own Paint event, on its edge, so it follows the layout, the scroll and a resize and needs no extra
# control; it works for a control that paints itself through Paint (a grid, a panel), not for a text box. $wn.FrameName is the name
# framed now ('' for none); $wn.FrameCtl the control; $wn.FrameHooked the controls that already have the Paint handler.
$wn.FrameName = ''; $wn.FrameCtl = $null; $wn.FrameHooked = New-Object System.Collections.ArrayList
# Draws the frame on the control $s when it is the one named by $wn.FrameName. Paint event handler.
$wn.FramePaint = { param($s, $e)
  if (-not $wn.FrameName -or [string]$s.AccessibleName -cne [string]$wn.FrameName) { return }
  try { $pn = New-Object System.Drawing.Pen($pc.primary, [single](& $wn.Sc 2)); $pn.Alignment = [Drawing.Drawing2D.PenAlignment]::Inset
    $e.Graphics.DrawRectangle($pn, 0, 0, ($s.ClientSize.Width - 1), ($s.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } }   # a paint never stops the window
# Finds the control with accessible name $Name on the page shown. Takes the name; gives back the control or $null.
$wn.FrameFind = { param([string]$Name)
  $st = New-Object System.Collections.Stack; $st.Push($page)
  while ($st.Count) { foreach ($c in $st.Pop().Controls) { if ([string]$c.AccessibleName -ceq $Name) { return $c }; if ($c.Controls.Count) { $st.Push($c) } } }
  return $null }
# Sets the frame for the step and the card shown: on the target of the click-through step when its card shows, else off. Called
# when a step shows ($wn.BarShow) and when a card shows ($wn.WalkSeen). The frame leaves when the walk moves on.
$wn.FrameSet = {
  $j = & $wn.WalkAt; $name = ''
  if ($j -ge 0 -and $Walk[$j].Target -and [string]$Walk[$j].Key -eq [string]$wn.Cur) { $name = [string]$Walk[$j].Target }
  $wn.FrameName = $name; $new = $(if ($name) { & $wn.FrameFind $name } else { $null })
  if ($new -and -not $wn.FrameHooked.Contains($new)) { $new.Add_Paint($wn.FramePaint); [void]$wn.FrameHooked.Add($new) }
  foreach ($c in @($wn.FrameCtl, $new)) { if ($c) { $c.Invalidate() } }
  $wn.FrameCtl = $new }
# R15 (R41 finding 4: one screen that did not open left the next step on a screen without its button): the link "Open
# this screen" shows on a step that needs it, and on any step while the screen shown is not the one the step starts on.
$wn.OpenShow = { if (-not $wn.OpenLink) { return }; $j = & $wn.WalkAt
  $wn.OpenLink.Visible = ($j -ge 0 -and ([string]$Walk[$j].Via -eq 'open' -or ([string]$Walk[$j].Via -ne 'rail' -and $Walk[$j].From -and [string]$Walk[$j].From -ne [string]$wn.Cur))) }
$wn.BarShow = {
  <#
  .SYNOPSIS
  Shows the step of the bar: a check (its number and text) or a click-through screen, with Pass and Fail, or the closing
  line when all are answered. The link "Open this screen" shows only on a click-through step that needs it.
  #>
  $i = [int]$wn.CheckAt; $j = & $wn.WalkAt
  if ($i -lt $Checks.Count) {
    $wn.BarNo.Text = 'Check ' + ($i + 1) + ' of ' + $Checks.Count; $wn.BarText.Text = [string]$Checks[$i].Text
    $wn.BarPass.Visible = $true; $wn.BarFail.Visible = $true }
  elseif ($j -ge 0) {
    $wn.BarNo.Text = 'Screen ' + ($j + 1) + ' of ' + $Walk.Count; $wn.BarText.Text = [string]$Walk[$j].Text
    $wn.BarPass.Visible = $true; $wn.BarFail.Visible = $true
    # R17 (R43 finding 6: the window opens on the card of step 1, so the person cannot open it on that step and the walk counted
    # a Pass as "not opened"): the card that shows when step 1 shows counts as opened.
    if ($j -eq 0 -and [string]$wn.Cur -eq [string]$Walk[0].Key) { $wn.WalkOpen[0] = $true } }
  else {
    $wn.BarNo.Text = 'Checks'; $wn.BarText.Text = $script:ChecksDone   # R13: names no card (the -Again check names the card closed on)
    $wn.BarPass.Visible = $false; $wn.BarFail.Visible = $false }
  & $wn.BarFit; & $wn.OpenShow; & $wn.FrameSet }
# R17 (R43 finding 4): the room of the step text, set by $wn.BarLayout (0 until the first layout).
$wn.BarTw = 0
# R17: cuts the step text box back to its room. A text box takes its size from its text when the text changes (the UI part,
# a few pixels past the wrap width), so this runs after each step and after the layout.
$wn.BarFit = { if ($wn.BarTw -gt 0 -and $wn.BarText -and $wn.BarText.Width -gt $wn.BarTw) { $wn.BarText.Size = [Drawing.Size]::new($wn.BarTw, $wn.BarText.Height) } }
# Keeps the answer (PASS or FAIL) to the step shown and shows the next one.
$wn.Answer = {
  <#
  .SYNOPSIS
  Keeps the answer $Result (PASS or FAIL) for the step shown, then shows the next step.
  .DESCRIPTION
  R16: a look step counts as opened when its card shows. A click-through step answered while its card never opened
  adds a NOTE line, so the result says why the step has no open.
  .PARAMETER Result
  PASS or FAIL, from the bar buttons.
  #>
  param([string]$Result)
  if ($wn.CheckAt -ge (& $wn.StepCount)) { return }
  $j = & $wn.WalkAt
  # R16: a look step asks about the card the person is on: it counts as opened when that card shows
  if ($j -ge 0 -and [string]$Walk[$j].Via -eq 'look' -and [string]$wn.Cur -eq [string]$Walk[$j].Key) { $wn.WalkOpen[$j] = $true }
  # R16 (R42 finding 3: step12 was answered with no click, so no open failed and no line was written): an answer on a step whose card never opened leaves a NOTE
  if ($j -ge 0 -and -not $wn.WalkOpen[$j]) {
    $lines.Add('NOTE screen ' + ($j + 1) + ' of ' + $Walk.Count + ' (' + [string]$Walk[$j].Key + ') was answered ' + $Result +
      ' without an open: the window shows ' + [string]$wn.Cur) }
  if ($j -ge 0) { $wn.WalkAns[$j] = $Result } else { $wn.Answers[$wn.CheckAt] = $Result }
  $wn.CheckAt++
  & $wn.BarShow }
# R14: the link "Open this screen" opens the card of the click-through step shown, as a person's open.
$wn.OpenStep = {
  $j = & $wn.WalkAt; if ($j -lt 0) { return }
  if (-not (& $ui.Settled)) { & $wn.IgnoreNote 'the link Open this screen'; return }
  $script:presses++; $wn.Notice = ''; $wn.Err = ''; $k = [string]$Walk[$j].Key
  try { & $wn.Show $k } catch { & $wn.OpenFail $k $_ }
  & $wn.OpenCheck $k }
# R15 (R41 finding 4: 2 screens did not open, and the result did not say why): a NOTE line when an open by the person stops.
$wn.OpenFail = { param([string]$Key, $Err) $m = [string]$Err.Exception.Message
  $lines.Add('NOTE the screen ' + $Key + ' did not open: ' + $m.Substring(0, [Math]::Min(160, $m.Length))) }
# R16 (R42 finding 3: step12 did not open and the result had no CARDTIME line and no NOTE line): every way an open can fail
# leaves a NOTE. The guard that holds a click in the first $ui.GuardMs ms after a card changed returned with no line; it
# writes one now ($wn.IgnoreNote, at most 12 lines), and an open that returns with no error while the window stays on the old
# card writes one ($wn.OpenCheck). $Where names the control that was clicked; $Key the card that should show.
$wn.IgnoreN = 0
# Writes a NOTE for a click that the guard held ($Where: the control), at most 12 times in a run.
$wn.IgnoreNote = { param([string]$Where)
  if ($wn.IgnoreN -ge 12) { return }; $wn.IgnoreN++
  $ms = [int]($ui.Clock.Elapsed.TotalMilliseconds - [double]$ui.CardAt)
  $lines.Add('NOTE a click on ' + $Where + ' was not used: the card ' + [string]$wn.Cur + ' changed ' + $ms + ' ms before (the guard holds a click for ' + [int]$ui.GuardMs + ' ms)') }
# Writes a NOTE when the window does not show card $Key after an open that returned with no error.
$wn.OpenCheck = { param([string]$Key)
  if ($Key -and [string]$wn.Cur -ne $Key) { $lines.Add('NOTE the screen ' + $Key + ' did not open: the window stayed on ' + [string]$wn.Cur) } }
$wn.BarLayout = {
  <#
  .SYNOPSIS
  Lays out the check bar for the window width: the step text at the left, as tall as the longest step needs, and Pass
  and Fail at the right, centered in the bar.
  .DESCRIPTION
  R10 (R37, B13): the Feedback link sits left of Pass, in the same place on every card. R14: the link "Open this
  screen" sits left of Feedback; its room is kept on every step, so the text and Feedback never move. The height comes
  from the longest check or click-through text, so the bar keeps one height through the whole run.
  #>
  if (-not $wn.Bar) { return }
  $w = $form.ClientSize.Width; $pad = & $wn.Sc 16; $gap = & $wn.Sc 8
  $pw = [int]$wn.BarPass.Width; $fw = [int]$wn.BarFail.Width   # R11 (B1): the fixed RADE sizes
  $bh = [math]::Max($wn.BarPass.Height, $wn.BarFail.Height)
  $kw = $(if ($wn.FbLink) { [math]::Max($wn.FbLink.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.FbLink.MinimumSize.Width) + 2 * $gap } else { 0 })
  $ow = $(if ($wn.OpenLink) { [math]::Max($wn.OpenLink.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.OpenLink.MinimumSize.Width) + $gap } else { 0 })
  # R17 (R43 finding 4: the text covered the link "Open this screen"): the text has the room that is left and no more. R16 gave it
  # at least 200 px, which pushed it onto the links when the window was small or the links were wide; the bar gets taller instead.
  $tw = [math]::Max(1, $w - 2 * $pad - $pw - $fw - 2 * $gap - $kw - $ow); $wn.BarTw = $tw
  # R18 (the PFM, 26 Nov 26, R45 comment 6a: the sentence ended "...opens and" when "Open this screen" showed): a text box is as wide as its
  # wrap width plus the 4 px its edit control keeps ($ui.TextSize), and $wn.BarFit cut it back to $tw, so the edit control wrapped 4 px
  # earlier than the height was measured and the last line fell out of the box. The wrap width is now $tw less those 4 px, for the
  # height and for the box, so the box is $tw wide, as the height was measured, and a long sentence takes one more line (the bar grows).
  $ww = [math]::Max(1, $tw - 2 * (& $wn.Sc 4))   # 2 x 4 px: wrapped, the box is the wrap width + 4; on one line, its text + 8; never past $tw
  $th = 0; foreach ($c in @(@($Checks) + @($Walk))) { $m = & $ui.Meas ([string]$c.Text) $ui.F.Body $ww; $th = [math]::Max($th, [int]$m.Height) }
  $th += (& $wn.Sc 6)
  $nh = [int]$wn.BarNo.PreferredSize.Height
  $wn.Bar.Height = [math]::Max($bh + 2 * $pad, $pad + $nh + (& $wn.Sc 2) + $th + $pad)
  $wn.BarNo.Location = [Drawing.Point]::new($pad, $pad)
  $wn.BarText.Location = [Drawing.Point]::new($pad, ($pad + $nh + (& $wn.Sc 2))); & $ui.SetWrap $wn.BarText $ww; $wn.BarText.Size = [Drawing.Size]::new($tw, $th)
  $by = [int](($wn.Bar.Height - $bh) / 2)
  $wn.BarPass.Location = [Drawing.Point]::new(($w - $pad - $fw - $gap - $pw), $by); $wn.BarFail.Location = [Drawing.Point]::new(($w - $pad - $fw), $by)
  if ($wn.FbLink) { $wn.FbLink.Location = [Drawing.Point]::new(($wn.BarPass.Left - $kw + $gap), [int](($wn.Bar.Height - $wn.FbLink.Height) / 2)) }
  if ($wn.OpenLink) { $wn.OpenLink.Location = [Drawing.Point]::new(($wn.BarPass.Left - $kw - $ow + $gap), [int](($wn.Bar.Height - $wn.OpenLink.Height) / 2)) } }
$wn.BuildBar = {
  <#
  .SYNOPSIS
  Builds the check bar at the bottom of the window: a line on top, the step number, the step text, Pass and Fail, the
  Feedback link and (R14, when the run has a click-through) the link "Open this screen".
  #>
  $bar = New-Object System.Windows.Forms.Panel; $bar.Dock = 'Bottom'; $bar.BackColor = $ui.C.White; $bar.AccessibleName = 'Check bar'
  $bar.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($pc.line, 1); $_.Graphics.DrawLine($pn, 0, 0, $this.ClientSize.Width, 0); $pn.Dispose() } catch { $null = $_ } })
  $no = & $ui.Label $ui.F.SmallB $ui.C.Gray 0; $no.Visible = $true; $no.AccessibleName = 'Check number'; [void]$bar.Controls.Add($no)
  $tx = & $ui.Text $ui.F.Body $ui.C.Ink 0 'Check'; & $wn.NoCaret $tx; $tx.Visible = $true; [void]$bar.Controls.Add($tx)
  foreach ($n in 'Pass', 'Fail') {
    $x = & $ui.Btn 'action'; $x.Text = $n; & $ui.Style $x ''; $x.AccessibleName = $n; $x.Tag = $n
    $x.Add_SizeChanged({ & $wn.Round $this 4 })
    $x.Add_Click({ $r = ([string]$this.Tag).ToUpperInvariant(); & $wn.Answer $r })
    [void]$bar.Controls.Add($x); if ($n -eq 'Pass') { $wn.BarPass = $x } else { $wn.BarFail = $x } }
  # R10 (R37, B13): Feedback, a link on the bar (the same place on every card); it asks for a comment on the card shown.
  $fb = & $ui.LinkBtn (& $wn.FeedbackText); $fb.AccessibleName = 'Feedback on this card'; $fb.Visible = $true
  $fb.Add_Click({ if (& $ui.Settled) { & $wn.FeedbackAsk $wn.Cur } }); [void]$bar.Controls.Add($fb); $wn.FbLink = $fb
  $wn.OpenLink = $null
  if ($Walk.Count) {   # R14: the click-through's own opener, for a card that no rail item, button or link opens
    $op = & $ui.LinkBtn 'Open this screen'; $op.AccessibleName = 'Open this screen'; $op.Visible = $false
    $op.Add_Click({ & $wn.OpenStep }); [void]$bar.Controls.Add($op); $wn.OpenLink = $op }
  $wn.Bar = $bar; $wn.BarNo = $no; $wn.BarText = $tx
  # R17 (R43 finding 4): the links are in front of the step text, so a text that is too wide can never cover them.
  $fb.BringToFront(); if ($wn.OpenLink) { $wn.OpenLink.BringToFront() }
  $form.Controls.Add($bar); $main.BringToFront()
  & $wn.BarShow; & $wn.BarLayout }
$wn.WalkLines = {
  <#
  .SYNOPSIS
  R14: the result lines of the click-through, one WALK line per screen and one summary line.
  .DESCRIPTION
  WALK <n> of <N> <card> PASS (opened by you); FAIL (opened by you), FAIL (not opened) when Pass came on a card that was
  not opened on its step, FAIL (not answered). Then: WALK screens opened by you=<n> of <N>, passed=, failed=, not
  answered=. No lines when the run has no click-through (-Again).
  .OUTPUTS
  The lines (strings).
  #>
  if (-not $Walk.Count) { return @() }
  $out = @(); $op = 0; $ps = 0; $fl = 0; $na = 0
  for ($j = 0; $j -lt $Walk.Count; $j++) {
    $a = [string]$wn.WalkAns[$j]; $seen = [bool]$wn.WalkOpen[$j]; if ($seen) { $op++ }
    $res = $(if ($a -eq 'PASS' -and $seen) { $ps++; 'PASS (opened by you)' } elseif ($a -eq 'PASS') { $fl++; 'FAIL (not opened)' }
      elseif ($a -eq 'FAIL') { $fl++; 'FAIL (' + $(if ($seen) { 'opened by you' } else { 'not opened' }) + ')' } else { $na++; 'FAIL (not answered)' })
    $out += ('WALK ' + ($j + 1) + ' of ' + $Walk.Count + ' ' + $Walk[$j].Key + ' ' + $res) }
  $out += ('WALK screens opened by you=' + $op + ' of ' + $Walk.Count + ' passed=' + $ps + ' failed=' + $fl + ' not answered=' + $na)
  return $out }
