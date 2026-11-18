<#
.SYNOPSIS
  90-161.Z Task 22: the PFM window, test window r4 (round R30). Windows PowerShell 5.1 and Windows Forms only (no module).
.DESCRIPTION
  The PFM's window of the 13-step process with FAKE data (design "preview 2", PFM 17 Nov 26): Your Work, All Actions, Reviews Due,
  steps 8 to 13, a publication, Settings and the states. Nothing is read, saved or sent. The look comes from the RADE shared UI
  file (rade-ui block, generated from the pinned RADE commit). The window keeps the size and place you give it; below 1280 x 720
  (at 100 %) the main column scrolls. Esc goes back one card. Close it with its X. A bar at the bottom shows 12 checks one at a
  time with Pass and Fail (PFM 17 Nov 26); each layout defect is one line "FAIL LAYOUT ..." and "PASS layout" is one line when
  there is none (the runner counts these words).
  WHAT R4 CHANGES (R29b results, R30 plan steps 1 and 3): the crumb is one line in one font and size, with a small gap after
  its link (V2); a format check with 0 findings shows no link (V3); the Action Status card ends on the main card's bottom line
  (V4); contrast on and off go through Windows Settings (Windows+U, Contrast themes), not a key chord; the script lists every
  control with no accessible name itself (one line RESULT NAMES PASS or FAIL) and the person check only confirms that Narrator
  speaks; Narrator off passes on what you can see. The script is split into parts (code standard): this file loads its 7 parts
  from its own folder, 90161Z-T22-<part>-r4.ps1 (cards, types, ui, parts, grid, window, measure). New: -Measure <file>.
  Inputs: the 7 part files next to this file. Parameters: -Id, -NoPause (RADE). -PlanOnly prints the cards and the 12 checks as
  text and opens no window; -TestDir writes the files elsewhere; -Measure <file> builds the window off-screen, writes what it
  measured to <file> as JSON (tests/ps/Test-T22Layout.ps1) and closes, with no question and no other file. -Opened opens no
  window: it reads 90161Z-T22-window-r4.txt of the last run and prints one line, PASS the window opened (N of M cards) or
  FAIL the window did not open (the round's look questions run only after a PASS).
  Outputs: 90161Z-T22-window-r4.txt (state, size, scale, cards opened, layout self-check, accessible names, check answers) and
  90161Z-T22-window-bounds.json (last size and place) in the T22 folder.
  Last line: WINDOW done: cards=<opened> buttons=<selected> defects=<n> checks failed=<n>. Exit 1 when no window can open.
  Run: by RADE in the round (powershell.exe -File 90161Z-T22-pfm-window-r4.ps1 -Id <DODID> -NoPause), or by hand in the T22 folder.
  Network: none.
  Writes: 90161Z-T22-window-r4.txt and 90161Z-T22-window-bounds.json in the T22 folder (or -TestDir); with -Measure only the file given;
  with -Opened nothing.
  Credentials: none.
#>
param([string]$Id, [switch]$NoPause, [switch]$PlanOnly, [string]$TestDir, [string]$Measure, [switch]$Opened)
$task = 'T22'
$Rev = 'r4'
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
$OpenedHours = 3   # a result file older than this is from an earlier round (review R30): -Opened does not trust it
# The -Opened line for the result file in $Dir: PASS when it was written in the last $OpenedHours hours, its last
# "CARDS opened" line counts more than 0 cards and no line starts with STOPPED:, else FAIL (also when it is missing).
function Get-OpenedLine([string]$Dir) {
  $f = Join-Path $Dir ('90161Z-T22-window-' + $Rev + '.txt')
  if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { return 'FAIL the window did not open' }
  if ((Get-Item -LiteralPath $f).LastWriteTime -lt (Get-Date).AddHours(-$OpenedHours)) { return 'FAIL the window did not open (no result from this round)' }
  $text = @(Get-Content -LiteralPath $f)
  $m = @($text | Where-Object { $_ -match '^CARDS opened: .*\((\d+) of (\d+)\)$' }) | Select-Object -Last 1
  $stopped = @($text | Where-Object { $_ -match '^STOPPED:' }).Count
  if ($m -and -not $stopped -and $m -match '\((\d+) of (\d+)\)$' -and [int]$Matches[1] -gt 0) { return ('PASS the window opened (' + $Matches[1] + ' of ' + $Matches[2] + ' cards)') }
  return 'FAIL the window did not open'
}
if ($Opened) {   # no window, no file: one line about the last run, exit 1 on FAIL
  try { $od = $(if ($TestDir) { $TestDir } else { Get-TaskDir (Get-TaskId $Id).Id $task 'Task 22' }); $ol = Get-OpenedLine $od } catch { $ol = 'FAIL the window did not open' }
  Write-Host $ol; exit $(if ($ol.StartsWith('PASS')) { 0 } else { 1 })
}
# Where an error happened, as "<file>:<line>" (the file name only: no folder, so no DODID).
function Get-ErrorPlace($Err) { return ([string](Split-Path -Leaf ([string]$Err.InvocationInfo.ScriptName)) + ':' + $Err.InvocationInfo.ScriptLineNumber) }
# The parts of this task, in load order. They are siblings of this file with fixed names (round skill section 2:
# scripts that load each other by file name stay in one folder).
$Parts = @('cards', 'types', 'ui', 'parts', 'grid', 'window', 'measure')
# The full path of part $Name: 90161Z-T22-<name>-r4.ps1 in this file's folder.
function Get-PartPath([string]$Name) { return (Join-Path $PSScriptRoot ('90161Z-T22-' + $Name + '-' + $Rev + '.ps1')) }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('TASK T22 PFM window preview ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$code = 0
$cf = 0; $cardsOpened = @{}; $presses = 0; $defects = New-Object System.Collections.Generic.List[string]
$dir = ''
$who = $null
try {
  $ErrorActionPreference = 'Stop'
  $missing = @($Parts | Where-Object { -not (Test-Path -LiteralPath (Get-PartPath $_) -PathType Leaf) })
  if ($missing.Count) { throw ('a part of this task is not in its folder: ' + (@($missing | ForEach-Object { Split-Path -Leaf (Get-PartPath $_) }) -join ', ')) }
  . (Get-PartPath 'cards')
  if ($PlanOnly) {
    @(Get-CardPlan) + @(Get-CheckPlan) | ForEach-Object { Write-Host $_ }
    Write-Host ('PLAN cards=' + $Cards.Count); return }
  if (-not $Measure) { $who = Get-TaskId $Id }
  if ($Measure) { $dir = '' } elseif ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 22' -Create }
  # The process is DPI aware like RADE, before any form exists (R28: this window ran unscaled while RADE ran at 150 %).
  $dpiAware = 'no'
  if ($env:OS -eq 'Windows_NT') {
    try {
      Add-Type -Namespace T22 -Name Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -ErrorAction Stop
      try { if ([T22.Native]::SetProcessDPIAware()) { $dpiAware = 'yes' } } catch { $null = $_ }
    } catch { $null = $_ } }
  $lines.Add('SCALE dpi-aware=' + $dpiAware)
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [Windows.Forms.Application]::EnableVisualStyles()
  . (Get-PartPath 'types')
  $script:native = [bool]('Rade.Native' -as [type])   # the shared UI file hides the caret of a card text box through it
  $started = Get-Date
  # Palette tokens (docs/palette.json; tests/run.sh checks each value against it).
  $PalHex = @{ ink = '1B1F2A'; muted = '5B6B7F'; surface = 'EEF1F5'; line = 'C9D2DC'; navy = '0B2545'; onPrimaryMuted = 'DDE8F3'
    accentFill = 'FFD520'; primary = '00539F'; track = '7F93A8'; redTint = 'F6D5DA'; amberTint = 'F8E8C4'; greenTint = 'D6EBDD'; white = 'FFFFFF' }
  $pc = @{}
  foreach ($k in $PalHex.Keys) { $pc[$k] = [Drawing.ColorTranslator]::FromHtml('#' + $PalHex[$k]) }
  $ui = @{}
  $form = New-Object System.Windows.Forms.Form
  $form.Text = '90-161.Z - Publications and Forms Management - preview ' + $Rev + ' (FAKE data)'
  $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi'
  $form.ClientSize = [Drawing.Size]::new(1280, 720)
  $form.StartPosition = 'CenterScreen'; $form.KeyPreview = $true; $form.ShowInTaskbar = $true
  $form.Opacity = 0   # shown when the cards are built, at the size and place the PFM gave it
  $ui.Form = $form; $ui.Dpi = 96.0; $ui.FontK = 1.0; $ui.FontDpi = 96.0
  . (Get-PartPath 'ui')
  $form.BackColor = $pc.surface
  $ui.Trash = @(@($ui.Trash) | Where-Object { $_ }) + @($ui.Menu)
  $ui.Clock = [System.Diagnostics.Stopwatch]::StartNew(); $ui.CardAt = 0; $ui.GuardMs = 400; $ui.Busy = $false; $ui.Always = @{}; $ui.Boxes = @()
  $ui.B = @(); $ui.P = @()   # the generated NameOf walks these two lists; this window has none (R28: every self-check stopped on a null list)
  $ui.View = ''; $ui.Scrolls = $false; $ui.Scroll = $null; $ui.RecOn = $false; $ui.Picked = $false; $ui.Sent = $null; $ui.Kick = $null
  # The RADE alignment rules have nothing to measure in this window: no extra layout lines.
  $ui.Measure = { param($Card) $null = $Card; return @() }
  $rail = New-Object System.Windows.Forms.Panel; $rail.Dock = 'Left'; $rail.BackColor = $pc.navy; $rail.AccessibleName = 'Main menu'
  $main = New-Object System.Windows.Forms.Panel; $main.Dock = 'Fill'; $main.BackColor = $pc.surface; $main.AutoScroll = $true; $main.AccessibleName = 'Main column'
  $page = New-Object System.Windows.Forms.FlowLayoutPanel; $page.FlowDirection = 'TopDown'; $page.WrapContents = $false; $page.AutoSize = $true; $page.AutoSizeMode = 'GrowAndShrink'
  $page.BackColor = $pc.surface; [void]$main.Controls.Add($page)
  $form.Controls.Add($main); $form.Controls.Add($rail)
  $wn = @{ Cur = ''; Prev = 'home'; Notice = ''; Err = ''; Field = @{}; Gridsel = $null; Wide = $false; RailBtn = @(); Secs = @() }
  # The crumb's link font (R30 V2): the crumb's own font, underlined; the same family and size as the rest of the crumb.
  try { $wn.CrumbFont = New-Object System.Drawing.Font($ui.F.Small, [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Underline'))
    $ui.Trash = @($ui.Trash) + @($wn.CrumbFont) } catch { $wn.CrumbFont = $ui.F.Small }
  foreach ($part in 'parts', 'grid', 'window', 'measure') { . (Get-PartPath $part) }
  if ($Measure) { & $wn.MeasureRun $Measure } else { & $wn.Hook; [void]$form.ShowDialog() }
  $wn.Ready = $false
  $dpi = 96; try { $g = $form.CreateGraphics(); $dpi = [int]$g.DpiX; $g.Dispose() } catch { $null = $_ }
  $lines.Add('SCALE dpi=' + $dpi + ' autoScale=' + $form.CurrentAutoScaleDimensions.Width + ' controlDpi=' + $ui.Dpi + ' fontFactor=' + $ui.FontK +
    ' fontDpi=' + $ui.FontDpi + ' screenDpi=' + $ui.ScreenDpi)
  $openedNames = $(if ($cardsOpened.Count) { (@($Cards.Keys | Where-Object { $cardsOpened[$_] }) -join ', ') } else { 'none' })
  $lines.Add('CARDS opened: ' + $openedNames + ' (' + $cardsOpened.Count + ' of ' + $Cards.Count + ')')
  $lines.Add('BUTTONS selected=' + $presses)
  $lines.Add('SECONDS open=' + [int]((Get-Date) - $started).TotalSeconds)
  foreach ($d in @($ui.LayBad)) { $defects.Add([string]$d) }
  foreach ($d in $defects) { $lines.Add('FAIL ' + $d) }
  if ($defects.Count -eq 0) { $lines.Add('PASS layout') }
  $lines.Add('SCROLLS vertical: ' + $(if ($wn.Scrolled.Count) { (@($wn.Scrolled.Keys) -join ', ') } else { 'none' }))
  $lines.Add('LAYOUT self-check: ' + $defects.Count + ' defects in ' + $ui.LayCards.Count + ' card views')
  if ($wn.Scanned) { $lines.Add((& $wn.NamesLine)) }   # R30: the accessible names, checked by the script (Narrator check 8 only confirms speech)
  $cp = 0; $cf = 0; $cs = 0
  for ($i = 0; $i -lt $Checks.Count -and -not $Measure; $i++) {
    $a = [string]$wn.Answers[$i]
    if ($a -eq 'PASS') { $cp++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' PASS') }
    elseif ($a -eq 'FAIL') { $cf++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' FAIL') }
    else { $cs++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' FAIL (not answered)') } }
  if (-not $Measure) { $lines.Add('CHECKS passed=' + $cp + ' failed=' + $cf + ' not answered=' + $cs) }
  foreach ($t in @($ui.Trash)) { try { $t.Dispose() } catch { $null = $_ } }
  $form.Dispose()
} catch {
  $code = 1
  $lines.Add('STOPPED: no window (' + ([string]$_.Exception.Message).Substring(0, [Math]::Min(200, ([string]$_.Exception.Message).Length)) + ') at ' + (Get-ErrorPlace $_))
} finally {
  if ($PlanOnly) { exit 0 }
  $lines.Add('WINDOW done: cards=' + $cardsOpened.Count + ' buttons=' + $presses + ' defects=' + $defects.Count + ' checks failed=' + $cf)
  $masked = @($lines | ForEach-Object { $t = [string]$_; if ($who) { $t = ConvertTo-Masked $t $who.Secret }; $t })
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T22-window-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT -and -not $PlanOnly -and -not $Measure) { [void](Read-Host 'Press Enter to close') }
}
exit $code
