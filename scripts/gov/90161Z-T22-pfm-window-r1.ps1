<#
.SYNOPSIS
  90-161.Z Task 22: the PFM window, preview r1 (round R26 r2). Windows PowerShell 5.1 and Windows Forms only (no module).
.DESCRIPTION
  What it is for: the first look at the 90-161.Z window the PFM works in (PFM 16 Nov 26: the front end is split; the PFM's part
  is a window in the RADE style). It shows 5 cards of the 13-step process with FAKE data: Your work, Start endorsement (step 8),
  Send for signatures (step 11), a publication (step 13) and Done. One card at a time, as in RADE ("One thing"). Nothing is
  read from or written to the site, and no e-mail is sent: every button only moves to another card.
  WHAT IT CHANGES: one text file in the T22 folder, 90161Z-T22-window-r1.txt: the window size and scale, which cards were
  opened, how many buttons were selected, how long the window was open, and the layout self-check (no names, no site).
  Close the window with its X (or Esc on the first card) to end the step.
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -NoPause. -PlanOnly prints the cards as text and
  opens no window, and -TestDir writes the result file to another folder (both for the tests in tests/run.sh).
  Last line: WINDOW done: cards=<opened> buttons=<selected> defects=<n>. Exit code 0 when the window opened and closed;
  exit 1 when no window can open on this computer (the result file says why).
#>
param([string]$Id, [switch]$NoPause, [switch]$PlanOnly, [string]$TestDir)
$task = 'T22'
$Rev = 'r1'

# >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)
function ConvertTo-Masked([string]$Text, [string[]]$Secret) {
  foreach ($x in $Secret) { $Text = $Text -replace [regex]::Escape($x), '<DODID>' }
  return $Text
}

function Get-TaskId([string]$Id) {
  # Returns @{ Id; Leaf (profile folder name); Secret (longest first, so a longer name is masked before a shorter one inside it) }.
  $leaf = ''
  if ($env:USERPROFILE) { $leaf = Split-Path -Leaf $env:USERPROFILE }
  $value = ([string]$Id).Trim()
  # No DODID question (PFM 13 Nov 26): the Windows profile folder name is used when -Id is not given.
  if (-not $value) { $value = $leaf }
  if ($value -notmatch '^[A-Za-z0-9._-]{4,}$') { throw 'DODID not valid: use the folder name under C:\Users (4 or more letters, digits, dot, dash or underscore).' }
  $secret = @(@($value, $leaf, $env:USERNAME) |
    Where-Object { $_ -and $_.Length -ge 4 } | Sort-Object -Unique | Sort-Object Length -Descending)
  return @{ Id = $value; Leaf = $leaf; Secret = $secret }
}

function Get-TaskDir([string]$Id, [string]$Task, [string]$Label, [switch]$Create) {
  # The task folder C:\Users\<DODID>\OneDrive - United States Air Force\RADE\90-161.Z\<Task> (PFM 14 Nov 26: RADE holds
  # the app folder). Until RADE has moved the old folder ...\90-161.Z, that one is used. -Create makes it when missing.
  $od = Join-Path (Join-Path 'C:\Users' $Id) 'OneDrive - United States Air Force'
  $app = 'RADE\90-161.Z'
  if (-not (Test-Path -LiteralPath (Join-Path $od $app) -PathType Container) -and (Test-Path -LiteralPath (Join-Path $od '90-161.Z') -PathType Container)) { $app = '90-161.Z' }
  $tail = 'OneDrive - United States Air Force\' + $app + '\' + $Task
  $dir = Join-Path (Join-Path 'C:\Users' $Id) $tail
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    if ($Create) { New-Item -ItemType Directory -Path $dir | Out-Null }
    else { throw ('FOLDER not found: C:\Users\<DODID>\' + $tail + '. Create it, save the ' + $Label + ' files into it, then run again.') }
  }
  return $dir
}

function Assert-TaskFile([string]$Dir, [string[]]$Name, [string]$Message) {
  # Throws $Message + the missing names when a file in $Name is not in $Dir.
  $missing = @($Name | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Dir $_) -PathType Leaf) })
  if ($missing.Count -gt 0) { throw ($Message + ($missing -join ', ')) }
}

function Unblock-TaskScript([string]$Dir) {
  # Files pasted into Notepad and saved locally need no unblock; a failed unblock is not an error here.
  Get-ChildItem -LiteralPath $Dir -Filter *.ps1 | ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
}

function Invoke-TaskStep([hashtable]$Step, [string]$ScriptDir, [string[]]$Secret, $Lines, [string]$Log) {
  # Runs $Step.File from $ScriptDir in a child powershell.exe with $Step.Args, masks and records its output and exit
  # code in $Lines, and saves $Lines to $Log after the step.
  Write-Host ('STEP ' + $Step.Name + ' running (Word steps can take a few minutes; do not close this window)...')
  $Lines.Add('STEP ' + $Step.Name)
  $stepArgs = $Step.Args
  $global:LASTEXITCODE = $null
  # PS 5.1: with Stop, a stderr line from the step (2>&1) would end the runner. Record it instead.
  $ErrorActionPreference = 'Continue'
  $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir $Step.File) @stepArgs 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  foreach ($o in @($out | Where-Object { $null -ne $_ })) {
    $masked = ConvertTo-Masked ([string]$o) $Secret
    $Lines.Add($masked)
    Write-Host $masked
  }
  $Lines.Add('STEP ' + $Step.Name + ' exit=' + $code)
  Write-Host ('STEP ' + $Step.Name + ' exit=' + $code)
  Set-Content -LiteralPath $Log -Value $Lines -Encoding UTF8
}
# <<< task-common
# >>> rade-logo: generated from the pinned RADE logo by scripts/build_task_scripts.py (do not edit)
$RadeLogoPng = @(
  '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',
  'AG2SrHTUY27uAAAAAElFTkSuQmCC'
) -join ''
# <<< rade-logo

# ---- The cards (fake data only). One card = one thing: a small line in capitals, one sentence, up to 4 paragraphs, up to 5
# detail rows (label and value), up to 4 choice rows (each opens a card), and up to 3 buttons, the first one blue.
$Cards = [ordered]@{
  home = @{ Kicker = 'Your work'; Light = 'you'; Sentence = '3 publications need you.'
    P = @('Fake data: this is a preview of the 90-161.Z window. Nothing is read, saved or sent.')
    Choices = @(
      @{ Text = 'FAKE OI 33-01, Records Handling'; Sub = 'Step 8: start endorsement. Due 18 Nov 26.'; Go = 'start' },
      @{ Text = 'FAKE OI 36-02, Training Records'; Sub = 'Step 11: send for signatures. Due 20 Nov 26.'; Go = 'sign' },
      @{ Text = 'FAKE OI 90-01, Publications Process'; Sub = 'Step 13: change or skip the review. Due 24 Nov 26.'; Go = 'pub' })
    Buttons = @() }
  start = @{ Kicker = 'Step 8 of 13 - your turn'; Light = 'you'; Sentence = 'Start endorsement for FAKE OI 33-01?'
    P = @('The AO marked the draft ready on 15 Nov 26.', 'Each endorser gets one e-mail with a link to the draft. Answers come back in the form.')
    Rows = @(@('Endorsers', '6 offices in 2 waves'), @('First wave', '4 offices'), @('Comments open', '0'))
    Buttons = @(@{ Text = 'Start endorsement'; Kind = 'primary'; Go = 'done' }, @{ Text = 'Send back to the AO'; Go = 'done' }, @{ Text = 'Back'; Go = 'home' }) }
  sign = @{ Kicker = 'Step 11 of 13 - your turn'; Light = 'you'; Sentence = 'Send FAKE OI 36-02 for signatures?'
    P = @('All 6 endorsers answered. No comment is open.', 'The certifier and the approver get the final copy with the DAF Form 673.')
    Rows = @(@('Certifier', 'FAKE OFFICE A'), @('Approver', 'FAKE OFFICE B'), @('Final copy', 'PDF made by a flow'))
    Buttons = @(@{ Text = 'Send for signatures'; Kind = 'primary'; Go = 'done' }, @{ Text = 'Not yet'; Go = 'home' }) }
  pub = @{ Kicker = 'Publication'; Light = 'off'; Sentence = 'FAKE OI 90-01, Publications Process'
    P = @('Review is due on 24 Nov 26. You can change the date or skip this review.')
    Rows = @(@('Status', 'Published'), @('OPR', 'FAKE OFFICE C'), @('AO', 'FAKE AO (fake)'), @('Next review', '24 Nov 26'), @('Prescribed forms', '1'))
    Buttons = @(@{ Text = 'Change or skip'; Kind = 'primary'; Go = 'done' }, @{ Text = 'Back'; Go = 'home' }) }
  done = @{ Kicker = 'Preview'; Light = 'ok'; Sentence = 'Done. Nothing was saved or sent.'
    P = @('In the real window, this card says what happened and what comes next.')
    Buttons = @(@{ Text = 'Back to your work'; Kind = 'primary'; Go = 'home' }) }
}

function Get-CardPlan {
  # The cards as text lines (for -PlanOnly and the tests): the same content the window draws.
  $out = @()
  foreach ($k in $Cards.Keys) {
    $c = $Cards[$k]
    $out += ('CARD ' + $k + ' | ' + $c.Kicker.ToUpperInvariant() + ' | ' + $c.Sentence)
    foreach ($p in @($c.P)) { $out += ('  P ' + $p) }
    foreach ($r in @($c.Rows)) { if ($r) { $out += ('  ROW ' + $r[0] + ': ' + $r[1]) } }
    foreach ($ch in @($c.Choices)) { if ($ch) { $out += ('  CHOICE ' + $ch.Text + ' -> ' + $ch.Go) } }
    foreach ($b in @($c.Buttons)) { if ($b) { $out += ('  BUTTON ' + $b.Text + $(if ($b.Kind -eq 'primary') { ' (blue)' } else { '' }) + ' -> ' + $b.Go) } }
  }
  return $out
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('TASK T22 PFM window preview ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$code = 0
$opened = @{}; $presses = 0; $defects = New-Object System.Collections.Generic.List[string]
$dir = ''
try {
  $ErrorActionPreference = 'Stop'
  if ($PlanOnly) { Get-CardPlan | ForEach-Object { Write-Host $_ }; Write-Host ('PLAN cards=' + $Cards.Count); return }
  $who = Get-TaskId $Id
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 22' -Create }
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $started = Get-Date

  # ---- Look: the RADE window's colors, fonts and sizes (the RADE engine, engine-v6; docs/window-design.md in rhope-ops/RADE).
  $ui = @{}
  $ui.C = @{ Navy = [System.Drawing.Color]::FromArgb(11, 37, 69); Blue = [System.Drawing.Color]::FromArgb(0, 83, 159); Yellow = [System.Drawing.Color]::FromArgb(255, 213, 32)
    Green = [System.Drawing.Color]::FromArgb(46, 133, 64); Ink = [System.Drawing.Color]::FromArgb(27, 36, 48); Gray = [System.Drawing.Color]::FromArgb(90, 101, 115)
    Edge = [System.Drawing.Color]::FromArgb(122, 135, 148); Hair = [System.Drawing.Color]::FromArgb(227, 232, 238); Off = [System.Drawing.Color]::FromArgb(233, 236, 240); White = [System.Drawing.Color]::White }
  $ui.Bold = [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Bold')
  $ui.Font = { param([string]$Fam, [double]$Pt, $Style) try { if ($null -ne $Style) { return (New-Object System.Drawing.Font($Fam, [single]$Pt, $Style)) }; return (New-Object System.Drawing.Font($Fam, [single]$Pt)) } catch { return (New-Object System.Drawing.Font('Segoe UI', [single]10)) } }
  $ui.F = @{ Small = (& $ui.Font 'Segoe UI' 10 $null); SmallB = (& $ui.Font 'Segoe UI' 10 $ui.Bold); Cap = (& $ui.Font 'Segoe UI' 9 $ui.Bold); Body = (& $ui.Font 'Segoe UI' 11 $null)
    BodyB = (& $ui.Font 'Segoe UI' 11 $ui.Bold); Sent = (& $ui.Font 'Segoe UI Semibold' 22 $null); Word = (& $ui.Font 'Segoe UI' 15 $ui.Bold); Opt = (& $ui.Font 'Segoe UI' 12 $ui.Bold); OptV = (& $ui.Font 'Segoe UI' 11 $null) }
  $ui.Pad = { param([int]$L, [int]$T, [int]$R, [int]$B) New-Object System.Windows.Forms.Padding($L, $T, $R, $B) }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = '90-161.Z - Publications and Forms Management - preview ' + $Rev + ' (fake data)'
  $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi'
  $form.Font = $ui.F.Small
  $form.ClientSize = New-Object System.Drawing.Size(1020, 760)
  $form.StartPosition = 'CenterScreen'; $form.KeyPreview = $true; $form.BackColor = $ui.C.White; $form.ShowInTaskbar = $true

  $light = New-Object System.Windows.Forms.Panel; $light.Dock = 'Top'; $light.Height = 6; $light.BackColor = $ui.C.White
  $top = New-Object System.Windows.Forms.FlowLayoutPanel; $top.Dock = 'Top'; $top.Height = 64; $top.WrapContents = $false; $top.Padding = (& $ui.Pad 32 12 32 0); $top.BackColor = $ui.C.White
  try {
    $logo = New-Object System.Windows.Forms.PictureBox; $logo.Size = New-Object System.Drawing.Size(40, 40); $logo.SizeMode = 'Zoom'; $logo.Margin = (& $ui.Pad 0 0 12 0); $logo.AccessibleName = 'Logo'
    $logo.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($RadeLogoPng))))
    [void]$top.Controls.Add($logo)
  } catch { $lines.Add('NOTE logo not shown: ' + $_.Exception.Message) }
  $word = New-Object System.Windows.Forms.Label; $word.AutoSize = $true; $word.Font = $ui.F.Word; $word.ForeColor = $ui.C.Navy; $word.Text = '90-161.Z'; $word.Margin = (& $ui.Pad 0 5 0 0)
  $app = New-Object System.Windows.Forms.Label; $app.AutoSize = $true; $app.Font = $ui.F.Small; $app.ForeColor = $ui.C.Gray; $app.Text = 'Publications and Forms Management   preview ' + $Rev + ', fake data'; $app.Margin = (& $ui.Pad 10 14 0 0)
  [void]$top.Controls.Add($word); [void]$top.Controls.Add($app)
  $bottom = New-Object System.Windows.Forms.Panel; $bottom.Dock = 'Bottom'; $bottom.Height = 46; $bottom.BackColor = $ui.C.White
  $foot = New-Object System.Windows.Forms.Label; $foot.AutoSize = $true; $foot.Font = $ui.F.Small; $foot.ForeColor = $ui.C.Gray; $foot.Text = 'Fake data. Close the window with its X when you have looked.'; $foot.Location = New-Object System.Drawing.Point(32, 12)
  [void]$bottom.Controls.Add($foot)
  $hair = New-Object System.Windows.Forms.Panel; $hair.Dock = 'Bottom'; $hair.Height = 1; $hair.BackColor = $ui.C.Hair
  $host1 = New-Object System.Windows.Forms.Panel; $host1.Dock = 'Fill'; $host1.BackColor = $ui.C.White; $host1.AutoScroll = $true
  $card = New-Object System.Windows.Forms.FlowLayoutPanel; $card.FlowDirection = 'TopDown'; $card.WrapContents = $false; $card.AutoSize = $true; $card.AutoSizeMode = 'GrowAndShrink'; $card.BackColor = $ui.C.White
  [void]$host1.Controls.Add($card)
  $form.Controls.Add($host1); $form.Controls.Add($hair); $form.Controls.Add($bottom); $form.Controls.Add($top); $form.Controls.Add($light)

  $ui.Place = {
    # The card's left edge at 12 % of the width, 40 % of the spare height above it (as RADE).
    $w = $host1.ClientSize.Width; $h = $host1.ClientSize.Height
    $x = [int]($w * 0.12); $y = [int][math]::Max(8, ($h - $card.Height) * 0.4)
    $card.Location = New-Object System.Drawing.Point($x, $y) }
  $ui.Width = { [int][math]::Max(320, $host1.ClientSize.Width * 0.76) }
  $ui.Label = { param([string]$Text, $Font, $Color, [int]$Top)
    $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $true; $l.MaximumSize = New-Object System.Drawing.Size((& $ui.Width), 0); $l.Font = $Font; $l.ForeColor = $Color
    $l.Text = $Text; $l.UseMnemonic = $false; $l.Margin = (& $ui.Pad 0 $Top 0 0); $l }
  $ui.Button = { param($B)
    $x = New-Object System.Windows.Forms.Button; $x.Text = [string]$B.Text; $x.AutoSize = $true; $x.MinimumSize = New-Object System.Drawing.Size(132, 40); $x.Padding = (& $ui.Pad 12 0 12 0)
    $x.Margin = (& $ui.Pad 4 4 4 4); $x.UseMnemonic = $false; $x.FlatStyle = 'Flat'; $x.FlatAppearance.BorderSize = 1; $x.UseVisualStyleBackColor = $false
    if ($B.Kind -eq 'primary') { $x.BackColor = $ui.C.Blue; $x.ForeColor = $ui.C.White; $x.FlatAppearance.BorderColor = $ui.C.Blue; $x.Font = $ui.F.SmallB; $x.FlatAppearance.MouseOverBackColor = $ui.C.Blue; $x.FlatAppearance.MouseDownBackColor = $ui.C.Navy }
    else { $x.BackColor = $ui.C.White; $x.ForeColor = $ui.C.Ink; $x.FlatAppearance.BorderColor = $ui.C.Edge; $x.Font = $ui.F.Small; $x.FlatAppearance.MouseOverBackColor = $ui.C.Hair; $x.FlatAppearance.MouseDownBackColor = $ui.C.Off }
    $x.Tag = [string]$B.Go
    $x.Add_Click({ $script:presses++; & $ui.Show ([string]$this.Tag) })
    $x }
  $ui.Choice = { param($Ch)
    # A choice row: a white button as wide as the card, the title in bold and a gray line under it.
    $x = New-Object System.Windows.Forms.Button; $x.Text = [string]$Ch.Text + "`r`n" + [string]$Ch.Sub; $x.TextAlign = 'MiddleLeft'; $x.UseMnemonic = $false
    $x.Size = New-Object System.Drawing.Size((& $ui.Width), 64); $x.Margin = (& $ui.Pad 0 8 0 0); $x.Padding = (& $ui.Pad 12 0 12 0)
    $x.FlatStyle = 'Flat'; $x.FlatAppearance.BorderSize = 1; $x.FlatAppearance.BorderColor = $ui.C.Edge; $x.UseVisualStyleBackColor = $false
    $x.BackColor = $ui.C.White; $x.ForeColor = $ui.C.Ink; $x.Font = $ui.F.OptV; $x.FlatAppearance.MouseOverBackColor = $ui.C.Hair; $x.FlatAppearance.MouseDownBackColor = $ui.C.Off
    $x.Tag = [string]$Ch.Go; $x.AccessibleName = [string]$Ch.Text + '. ' + [string]$Ch.Sub
    $x.Add_Click({ $script:presses++; & $ui.Show ([string]$this.Tag) })
    $x }
  $ui.Show = { param([string]$Key)
    $c = $Cards[$Key]; $script:opened[$Key] = $true; $ui.Key = $Key
    $card.SuspendLayout(); $card.Controls.Clear()
    $light.BackColor = $(if ($c.Light -eq 'you') { $ui.C.Yellow } elseif ($c.Light -eq 'ok') { $ui.C.Green } else { $ui.C.White })
    [void]$card.Controls.Add((& $ui.Label $c.Kicker.ToUpperInvariant() $ui.F.Cap $ui.C.Gray 0))
    [void]$card.Controls.Add((& $ui.Label $c.Sentence $ui.F.Sent $ui.C.Navy 4))
    $first = $true
    foreach ($p in @($c.P)) { if ($p) { [void]$card.Controls.Add((& $ui.Label $p $ui.F.Body $ui.C.Ink $(if ($first) { 12 } else { 8 }))); $first = $false } }
    if (@($c.Rows | Where-Object { $_ }).Count) {
      $t = New-Object System.Windows.Forms.TableLayoutPanel; $t.ColumnCount = 2; $t.AutoSize = $true; $t.Margin = (& $ui.Pad 0 16 0 0); $t.BackColor = $ui.C.White
      foreach ($cs in 1, 2) { [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) }
      $i = 0
      foreach ($r in @($c.Rows)) { $a = & $ui.Label $r[0] $ui.F.Small $ui.C.Gray 4; $a.Margin = (& $ui.Pad 0 4 24 0); $b = & $ui.Label $r[1] $ui.F.BodyB $ui.C.Ink 2; $t.Controls.Add($a, 0, $i); $t.Controls.Add($b, 1, $i); $i++ }
      [void]$card.Controls.Add($t)
    }
    foreach ($ch in @($c.Choices)) { if ($ch) { [void]$card.Controls.Add((& $ui.Choice $ch)) } }
    if (@($c.Buttons | Where-Object { $_ }).Count) {
      $row = New-Object System.Windows.Forms.FlowLayoutPanel; $row.AutoSize = $true; $row.WrapContents = $true; $row.MaximumSize = New-Object System.Drawing.Size((& $ui.Width), 0); $row.Margin = (& $ui.Pad 0 20 0 0); $row.BackColor = $ui.C.White
      $btns = @(); foreach ($b in @($c.Buttons)) { if ($b) { $x = & $ui.Button $b; [void]$row.Controls.Add($x); $btns += $x } }
      [void]$card.Controls.Add($row)
      $form.AcceptButton = $btns[0]
    } else { $form.AcceptButton = $null }
    $card.ResumeLayout(); & $ui.Place
    $focus = @($card.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] }) + @($card.Controls | Where-Object { $_ -is [System.Windows.Forms.FlowLayoutPanel] } | ForEach-Object { $_.Controls })
    if ($focus.Count) { [void]$focus[0].Focus() } }
  $ui.Check = {
    # Layout self-check (as RADE): a part of the card that ends right of the card area, or a card taller than the window.
    $w = $host1.ClientSize.Width
    foreach ($k in $Cards.Keys) {
      & $ui.Show $k
      foreach ($c in $card.Controls) { if (($card.Left + $c.Right) -gt $w) { $defects.Add('LAYOUT ' + $k + ' ' + $c.GetType().Name + ': ends at ' + ($card.Left + $c.Right) + ', the window is ' + $w) } }
      if ($card.Height -gt $host1.ClientSize.Height) { $defects.Add('LAYOUT ' + $k + ': the card is ' + $card.Height + ' high, the window ' + $host1.ClientSize.Height + ' (it scrolls)') }
    }
    $script:opened = @{} }
  $form.Add_Resize({ if ($ui.Key) { & $ui.Show $ui.Key } })
  $form.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { if ($ui.Key -ne 'home') { & $ui.Show 'home' } else { $form.Close() } } })
  $form.Add_Shown({ & $ui.Check; & $ui.Show 'home'; $form.TopMost = $true; $form.Activate(); $form.TopMost = $false })
  [void]$form.ShowDialog()
  $dpi = 96; try { $g = $form.CreateGraphics(); $dpi = [int]$g.DpiX; $g.Dispose() } catch { $null = $_ }
  $lines.Add('SCALE dpi=' + $dpi + ' autoScale=' + $form.CurrentAutoScaleDimensions.Width + ' client=' + $form.ClientSize.Width + 'x' + $form.ClientSize.Height + ' state=' + $form.WindowState)
  $lines.Add('CARDS opened: ' + $(if ($opened.Count) { (@($Cards.Keys | Where-Object { $opened[$_] }) -join ', ') } else { 'none' }) + ' (' + $opened.Count + ' of ' + $Cards.Count + ')')
  $lines.Add('BUTTONS selected=' + $presses)
  $lines.Add('SECONDS open=' + [int]((Get-Date) - $started).TotalSeconds)
  foreach ($d in $defects) { $lines.Add($d) }
  $lines.Add('LAYOUT self-check: ' + $defects.Count + ' defects in ' + $Cards.Count + ' cards')
  $form.Dispose()
} catch {
  $code = 1
  $lines.Add('STOPPED: no window (' + ([string]$_.Exception.Message).Substring(0, [Math]::Min(200, ([string]$_.Exception.Message).Length)) + ')')
} finally {
  if ($PlanOnly) { exit 0 }
  $lines.Add('WINDOW done: cards=' + $opened.Count + ' buttons=' + $presses + ' defects=' + $defects.Count)
  $masked = @($lines | ForEach-Object { $t = [string]$_; if ($who) { $t = ConvertTo-Masked $t $who.Secret }; $t })
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T22-window-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT -and -not $PlanOnly) { [void](Read-Host 'Press Enter to close') }
}
exit $code
