<#
.SYNOPSIS
  90-161.Z Task 22 r10, part "feedback": Feedback on every card of the PFM window (UI standard B13, PFM 19 Nov 26).
.DESCRIPTION
  The window part puts the Feedback link on the check bar (the same place on every card) and calls $wn.FeedbackAsk on
  a click and $wn.FeedbackList at the close; the -Measure run calls $wn.MeasureFeedback (below), which saves one FAKE
  comment through $wn.FeedbackSave.
  Inputs: $form, $ui, $wn, $who, $dir, $Rev, $lines. Outputs: the $wn members below.
  Run: not alone; 90161Z-T22-pfm-window-r10.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Writes: per saved comment 90161Z-T22-feedback-<card>-r10.txt and .png, and at the close 90161Z-T22-feedback-r10.txt, in
  the T22 folder (or -TestDir); with -Measure in the folder of the measure file.
  Credentials: none.
#>
# R10 (R37; PFM 19 Nov 26, UI standard B13): Feedback on every card. The link opens a small comment box; Save writes the
# comment and a picture of the window as it was when the link was selected, into the T22 folder (the round sends them):
# 90161Z-T22-feedback-<card>-r10.txt and .png (a second comment on the same card: <card>-2, and so on). Each save adds a
# FEEDBACK line to the result file; at the close 90161Z-T22-feedback-r10.txt lists every comment file (or none), so the
# round always finds one feedback file. With -Measure the files go to the folder of the measure file.
$wn.FeedbackN = @{}; $wn.FeedbackAll = New-Object System.Collections.Generic.List[string]
# The link text: "Feedback", and how many comments were saved.
$wn.FeedbackText = { if ($wn.FeedbackAll.Count) { return ('Feedback (' + $wn.FeedbackAll.Count + ' saved)') }; return 'Feedback' }
# The folder the feedback files go to: the T22 folder, or the measure folder.
$wn.FeedbackDir = { if ($dir) { return $dir }; return [string]$wn.PngDir }
# The base name of comment $N on card $Key: 90161Z-T22-feedback-<card>-r10, or <card>-<N> from the second one on.
$wn.FeedbackName = { param([string]$Key, [int]$N)
  return ('90161Z-T22-feedback-' + $Key + $(if ($N -gt 1) { '-' + $N } else { '' }) + '-' + $Rev) }
# A picture of the whole window as it is now (Control.DrawToBitmap). The caller disposes it.
$wn.Snapshot = {
  $bm = New-Object System.Drawing.Bitmap([math]::Max(1, $form.Width), [math]::Max(1, $form.Height))
  $form.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $bm.Width, $bm.Height))); return $bm }
$wn.FeedbackSave = {
  <#
  .SYNOPSIS
  Saves one comment on card $Key: the text file and the window picture $Shot, in the feedback folder.
  .DESCRIPTION
  The comment is masked like every result line (the DODID shows as <DODID>). Adds a FEEDBACK line to the result and
  the base name to $wn.FeedbackAll. A save that fails is a NOTE line, not a stop.
  .PARAMETER Key
  The card key.
  .PARAMETER Text
  The comment as typed.
  .PARAMETER Shot
  The window picture (a Bitmap).
  .OUTPUTS
  The base name of the two files, or '' when nothing was saved.
  #>
  param([string]$Key, [string]$Text, $Shot)
  $into = & $wn.FeedbackDir
  if (-not $into) { $lines.Add('NOTE feedback not saved: no folder'); return '' }
  try {
    $n = 1 + [int]$wn.FeedbackN[$Key]; $wn.FeedbackN[$Key] = $n; $base = & $wn.FeedbackName $Key $n
    $Shot.Save((Join-Path $into ($base + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $t = ([string]$Text).Trim(); if ($who) { $t = ConvertTo-Masked $t $who.Secret }
    $body = @(('FEEDBACK card ' + $Key + ', window ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')), 'What does not look right:', $t)
    Set-Content -LiteralPath (Join-Path $into ($base + '.txt')) -Value $body -Encoding UTF8
    $wn.FeedbackAll.Add($base); $lines.Add('FEEDBACK ' + $Key + ': ' + $base + '.txt and ' + $base + '.png')
    return $base
  } catch { $lines.Add('NOTE feedback not saved: ' + ([string]$_.Exception.Message)); return '' } }
$wn.FeedbackAsk = {
  <#
  .SYNOPSIS
  The Feedback box for card $Key: takes the window picture first (so the box is not in it), asks "What does not look
  right?" in a multi-line box, and on Save keeps the comment ($wn.FeedbackSave). Cancel or Esc saves nothing; an empty
  comment saves nothing.
  .PARAMETER Key
  The card key (the card on the page when the link was selected).
  #>
  param([string]$Key)
  $shot = $null; $dlg = $null
  try {
    $shot = & $wn.Snapshot
    $dlg = New-Object System.Windows.Forms.Form; $dlg.Text = 'Feedback on this card'; $dlg.FormBorderStyle = 'FixedDialog'; $dlg.StartPosition = 'CenterParent'
    $dlg.MinimizeBox = $false; $dlg.MaximizeBox = $false; $dlg.ShowInTaskbar = $false; $dlg.Font = $ui.F.Body; $dlg.AutoScaleMode = 'None'
    $pad = & $wn.Sc 16; $bw = & $wn.Sc 120; $bh = & $wn.Sc 36; $tw = & $wn.Sc 460
    $lb = New-Object System.Windows.Forms.Label; $lb.Text = 'What does not look right?'; $lb.AutoSize = $true; $lb.Location = [Drawing.Point]::new($pad, $pad)
    $tb = New-Object System.Windows.Forms.TextBox; $tb.Multiline = $true; $tb.AcceptsReturn = $true; $tb.ScrollBars = 'Vertical'; $tb.WordWrap = $true
    $tb.AccessibleName = 'What does not look right?'; $tb.Size = [Drawing.Size]::new($tw, (& $wn.Sc 120))
    $tb.Location = [Drawing.Point]::new($pad, ($pad + $lb.PreferredHeight + (& $wn.Sc 8)))
    $by = $tb.Bottom + $pad
    $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'Save'; $ok.AccessibleName = 'Save the comment'; $ok.DialogResult = 'OK'; $ok.Size = [Drawing.Size]::new($bw, $bh)
    $no = New-Object System.Windows.Forms.Button; $no.Text = 'Cancel'; $no.AccessibleName = 'Cancel'; $no.DialogResult = 'Cancel'; $no.Size = [Drawing.Size]::new($bw, $bh)
    $no.Location = [Drawing.Point]::new(($pad + $tw - 2 * $bw - (& $wn.Sc 8)), $by); $ok.Location = [Drawing.Point]::new(($pad + $tw - $bw), $by)   # primary last, at the right (B5)
    $dlg.Controls.AddRange(@($lb, $tb, $no, $ok)); $dlg.CancelButton = $no
    $dlg.ClientSize = [Drawing.Size]::new(($tw + 2 * $pad), ($by + $bh + $pad))
    if ([string]$dlg.ShowDialog($form) -eq 'OK' -and ([string]$tb.Text).Trim()) {
      if (& $wn.FeedbackSave $Key $tb.Text $shot) { $wn.FbLink.Text = & $wn.FeedbackText; & $wn.BarLayout } }
  } catch { $lines.Add('NOTE the feedback box did not open: ' + ([string]$_.Exception.Message)) }
  finally { if ($dlg) { $dlg.Dispose() }; if ($shot) { $shot.Dispose() } } }
# At the close: 90161Z-T22-feedback-r10.txt lists every comment of this run (or says there is none).
$wn.FeedbackList = {
  $into = & $wn.FeedbackDir; if (-not $into) { return }
  $body = @('FEEDBACK window ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ': comments saved=' + $wn.FeedbackAll.Count)
  foreach ($b in $wn.FeedbackAll) { $body += ('  ' + $b + '.txt and ' + $b + '.png') }
  try { Set-Content -LiteralPath (Join-Path $into ('90161Z-T22-feedback-' + $Rev + '.txt')) -Value $body -Encoding UTF8 }
  catch { $lines.Add('NOTE the feedback list was not saved: ' + ([string]$_.Exception.Message)) } }
$wn.MeasureFeedback = {
  <#
  .SYNOPSIS
  R10 (R37, B13): the Feedback link on every card and one saved comment, with no question.
  .DESCRIPTION
  Shows each card and notes whether the Feedback link is on the check bar, visible, named and in one place. Then it
  saves one FAKE comment on Your Work with a window picture ($wn.FeedbackSave, the same code as the Save button) and the
  feedback list ($wn.FeedbackList), and reads the files back: the PNG signature and size, the comment in the text file,
  the base name in the list.
  .OUTPUTS
  A table: Cards, WithLink, Places, Name, Base, PngBytes, PngSig, TxtHasComment, ListHasIt, LinkText.
  #>
  $f = [ordered]@{}; $with = 0; $places = @{}
  foreach ($k in $Cards.Keys) { & $wn.Show $k; [Windows.Forms.Application]::DoEvents(); $l = $wn.FbLink
    if ($l -and $l.Visible -and [object]::ReferenceEquals($l.Parent, $wn.Bar) -and ([string]$l.Text).StartsWith('Feedback')) { $with++; $places[[string]$l.Location] = 1 } }
  & $wn.Show 'home'; [Windows.Forms.Application]::DoEvents()
  $f['Cards'] = $Cards.Count; $f['WithLink'] = $with; $f['Places'] = $places.Count; $f['Name'] = [string]$wn.FbLink.AccessibleName
  $comment = 'FAKE measure comment: the grid is too narrow'
  $shot = & $wn.Snapshot; try { $base = & $wn.FeedbackSave 'home' $comment $shot } finally { $shot.Dispose() }
  & $wn.FeedbackList
  $into = & $wn.FeedbackDir; $f['Base'] = $base; $f['PngBytes'] = 0; $f['PngSig'] = $false; $f['TxtHasComment'] = $false; $f['ListHasIt'] = $false
  if ($base) {
    $png = Join-Path $into ($base + '.png')
    if (Test-Path -LiteralPath $png -PathType Leaf) { $b = [System.IO.File]::ReadAllBytes($png); $f['PngBytes'] = $b.Length
      $f['PngSig'] = ($b.Length -gt 8 -and $b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47) }
    $txt = Join-Path $into ($base + '.txt'); if (Test-Path -LiteralPath $txt -PathType Leaf) { $f['TxtHasComment'] = ((Get-Content -LiteralPath $txt -Raw).Contains($comment)) }
    $lst = Join-Path $into ('90161Z-T22-feedback-' + $Rev + '.txt')
    if (Test-Path -LiteralPath $lst -PathType Leaf) { $f['ListHasIt'] = ((Get-Content -LiteralPath $lst -Raw).Contains($base + '.png')) } }
  $f['LinkText'] = [string]$wn.FbLink.Text
  return $f }
