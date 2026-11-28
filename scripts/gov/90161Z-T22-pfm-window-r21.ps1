<#
.SYNOPSIS
  90-161.Z Task 22: the PFM window, test window r21 (round R48). Windows PowerShell 5.1, Windows Forms and, to read the
  test site, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  WHAT R21 CHANGES (F6 T22; DEC-NIPR invariant 2, no C# compiled at run time): the types part makes the drawn controls, the
  wheel router and the logo work with PowerShell functions and standard controls (Paint and MouseWheel script blocks); the
  process is no longer made DPI aware (Windows scales the window; text may look soft at 125 % or more); the caret of a card
  text box is not hidden any more (a click on card text gives the focus away again). The look and the cards stay the same.
  WHAT R18 CHANGES (the PFM, 26 Nov 26, comments of round R45): the window title (above); a text value of the Action Status card (pairs
  of label and value) starts at one left edge, and a chip row is only as tall as its text (the parts part); the waves card counts its head
  line, chip and pill from the rows its grid shows and has no stray "4" under the grid (the site and grid parts); the check bar wraps its
  sentence onto a second line and frames the part of the screen a step names (the cards part: Target; the bar part: $wn.FrameSet).
  WHAT R17 CHANGES (round R44 T4; R43 findings 3, 4 and 6; the PFM, 26 Nov 26): the look step after the waves card names the
  grid by the head line above it, a line the card shows (the cards part); the bar keeps room for its links "Open this screen"
  and "Feedback", so the step text never covers them (the bar part, tests/ps/Test-T22Bar.ps1); the first click-through step
  counts the card that shows at the start as opened (the bar part). Names: the window title is always
  "Kanon <bullet> 0.1.0 (FAKE data)" (R18, the PFM, 26 Nov 26, R45: was "90-161.Z - Kanon - 0.1.0 - R44 (FAKE data)"), and the rail head
  reads "Kanon" (the window part). The RADE window's own title, word spot and Maintenance row belong to the RADE engine.
  WHAT R14 CHANGES (round R41; PFM 20 Nov 26: docs/reviews/2026-11-21-r41-plan.md rows 1, 3 and 4): the window reads the
  PFM lists of the test site, read-only, and fills Your Work, All Actions and the endorsement answers from them (the
  site part: your CAC sign-in, a SOURCE line, a READ line per list, WRITES=0; a card picture only when every site row it
  shows has a fake-data marker); a grid whose list has no rows shows its empty state. When the site cannot be read the
  cards keep their FAKE data (SOURCE fake), as -Measure and -PlanOnly always do. After the 4 checks the check bar walks
  you through every screen in order, one Pass or Fail each (the bar part: 17 screens, from R16 18 steps, a WALK line each; Feedback on
  every screen as before). The grid fit runs again after the layout settles, and the layout self-check line names the
  open (first, kept, rebuild, resize; R40 finding 3). The parts: 13 (R14 adds bar and site).
  WHAT R19 CHANGES (round R47; the round skill, "Repeated tasks", the PFM, 2026-11-26): the check bar walks only the
  screens that changed or failed since the last round that passed them, each with its reason ($WalkOnly in the cards
  part): in R47 only step12 (R46: Fail, no comment), 1 WALK line. The other checks stay.
  WHAT R20 CHANGES (round R48; R47 findings 2): a status pill sits on the vertical middle of its row (home list rows) and a
  chip in a rows block starts on the value edge with the dates (step12; the parts part); the engine-v48 shared UI file (the
  window stays light: dark is opt-in, R49). The walk opens only home and step12 (R47: Fail), 2 WALK lines.
  WHAT R16 CHANGES (round R43 T1 to T3; R42 findings 2 to 5): a grid whose columns still end past it after the fit is cut to its
  room (the grid part, tests/ps/Test-T22GridWidth.ps1); the box next to "Find a publication" is level with the list beside
  it, a status chip in a row has the gap above it that text has, and a check box is level with its text (the parts part); a
  rail click that opens another card is not held by the 400 ms guard, and every open or click that does nothing leaves a NOTE
  line (the window and bar parts); the step after the waves card asks about the grid Wave 1 answers (the cards and bar
  parts: 18 steps, a WALK line each).
  WHAT R15 CHANGES (round R42 T1; R41 finding 4): every grid keeps the room for the scroll bar and its grid fit works on
  the column minimums, so no Status chip ends under the bar (the grid part); the click-through opens the endorsement
  screen with "Start Endorsement" on Confirm, shows "Open this screen" on any step while the screen shown is not the one
  the step starts on, and a screen that does not open adds a NOTE line (the cards and bar parts).
  WHAT R13 CHANGED (round R40; PFM 20 Nov 26: docs/reviews/2026-11-20-r40-plan.md, the R39 findings 1 and 2): each card
  is built once and kept; a later open shows the kept card again and a card is built again only when it must change
  (a new size, a field, an error line or a note, a color change: the keep part). CARDTIME lines add the paint time
  (paint-first=, paint-later-max=) and kept=. The -Again check names the card saved at the last close, by its title;
  the check bar's closing line names no card. The parts: 11 (R13 adds keep).
  WHAT R12 CHANGED (round R39; PFM 20 Nov 26: docs/phases.md R39 and the R38 findings): the Sofia Sans fonts of the RADE
  window, from the 3 font files the round puts in the T22 folder (a FONT line; Segoe UI when they are missing); the
  window opens on the card it was closed on (90161Z-T22-window-lastcard.txt; a LASTCARD line); the Your Work grid drops
  Since when its whole chips do not fit (R38 finding 2); one-line text boxes have the compact height in a frame (B1);
  a CARDTIME line per card the person opened (open time in ms, R38 finding 3). 4 checks; -Again (the round's second
  run) has 1 check: the window opened on the card it was closed on.
  R11 (R38; PFM 20 Nov 26): 3 checks, "XXX XXX " fake names, the status chips clear of the scroll bar, the Fulcrum logo in both modes.
  The PFM's window of the 13-step process with FAKE data (design "preview 2", PFM 17 Nov 26): Your Work, All Actions, Reviews Due,
  steps 8 to 13, a publication, Settings and the states. Nothing is read or sent. The look comes from the RADE shared UI
  file (rade-ui block, generated from the pinned RADE commit). The window keeps the size and place you give it; below 1280 x 720
  (at 100 %) the main column scrolls. Esc goes back one card. Close it with its X. A bar at the bottom shows 3 checks (R11; r10 had 18) one at a
  time with Pass and Fail (PFM 17 Nov 26); each layout defect is one line "FAIL LAYOUT ..." and "PASS layout" is one line when
  there is none (the runner counts these words).
  WHAT R10 CHANGES (round R37; r9 was the dynamic sizing that failed its Windows tests and is not in this revision):
  the rail logo has the Fulcrum colors when Windows apps use light mode (AppsUseLightTheme 1 or missing) and the USAF
  colors in dark mode (0), and the 2 system colors with high contrast on, as in r8 ($wn.AppsLight, $wn.LogoOwn; a THEME
  line; PFM 19 Nov 26). A grid whose columns are wider than it gives the excess back ($wn.FitGrids; R36 finding 3: the
  home grid was 9 px short). Feedback (UI standard B13, PFM 19 Nov 26): a link on the check bar, in the same place on
  every card, opens a small box "What does not look right?"; Save writes the comment and a picture of the window into
  the T22 folder as 90161Z-T22-feedback-<card>-r21.txt and .png and adds a FEEDBACK line; at the close
  90161Z-T22-feedback-r21.txt lists them (or none).
  WHAT R8 CHANGED (R35 plan W7: R34 finding 7 and open point 5): with Windows high contrast on, the rail logo is drawn
  in 2 system colors, and in its own colors again when it goes off ($wn.LogoImage, ConvertTo-PfmTwoTone); every rail build checks
  the logo's colors (a LOGO line; a W7 LAYOUT line when they are wrong). No column head of a grid is shortened with
  dots in a narrow grid: each column keeps its head's width ($wn.HeadMin); the layout self-check writes a W7 LAYOUT
  line for a cut head. The check bar keeps its 18 checks.
  WHAT R7 CHANGED (R34 plan W1, R32 finding 6, W1 to W3): a publication number is never cut and the grid head reads
  PUBLICATION (W1, grid part); the mouse wheel scrolls a card, or the grid under the pointer, from anywhere on it
  (W2, Add-PfmWheel); every chip beside text is level with its first line (W3, $wn.ChipTops). The layout self-check
  writes W1 and W3 LAYOUT lines, and the check bar has 2 more checks (wheel, pubnum).
  WHAT R6 CHANGED (R32 plan W1, R31b defects D1 to D4): the caption "ACTION STATUS" is level with the first line of the
  main card (D1); the crumb's link and rest have one size and one text middle (D2); the label "Passed" is level with
  the first line of its text (D3); the publication titles of a grid start in one column (D4). The layout self-check
  writes a LAYOUT line for each of the 4 ($ui.Measure, measure part) and the check bar has 2 more checks (chip, pubcol).
  R5 (R31): rail head, high contrast, card pictures. R4 (R30) split the script into parts: this file loads its parts
  from its own folder, 90161Z-T22-<part>-r21.ps1 (cards, types, ui, ui2, parts, grid, logo, window, keep, feedback,
  measure; R10 adds logo and feedback, R11 ui2, R13 keep, R14 bar and site).
  Inputs: the 13 part files and the font files (90161Z-SofiaSans*.ttf) next to this file; with -Again, the saved card
  (90161Z-T22-window-lastcard.txt).
  Parameters: -Id, -NoPause (RADE), -Again (R12: the reopen check only). -PlanOnly prints the cards and the 4 checks as
  text and opens no window; -TestDir writes the files elsewhere; -Measure <file> builds the window off-screen, writes what it
  measured to <file> as JSON (tests/ps/Test-T22Layout.ps1) and the card pictures next to it, and closes, with no question.
  -Opened opens no window: it reads 90161Z-T22-window-r21.txt of the last run and prints one line, PASS the window opened
  (N of M cards) or FAIL the window did not open (the round's look questions run only after a PASS).
  Outputs: 90161Z-T22-window-r21.txt (with -Again: 90161Z-T22-window-again-r21.txt) (state, size, scale, cards opened, layout self-check, accessible names, card pictures,
  feedback, check answers), 90161Z-T22-window-bounds-r21.json (last size and place), 90161Z-T22-card-<card>-r21.png (one per
  card) and the feedback files (90161Z-T22-feedback-r21.txt, and a .txt and a .png per comment) in the T22 folder.
  Last line: WINDOW done: cards=<opened> buttons=<selected> defects=<n> checks failed=<n>. Exit 1 when no window can open.
  Run: by RADE in the round (powershell.exe -File 90161Z-T22-pfm-window-r21.ps1 -Id <DODID> -NoPause), or by hand in the T22 folder.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell, read
  only (the site part; none with -PlanOnly, -Measure or -Opened).
  Writes: nothing on the site. 90161Z-T22-window-r21.txt (or -again-r21.txt), 90161Z-T22-window-bounds-r21.json, 90161Z-T22-window-lastcard.txt, the card PNG files and the feedback files in the T22
  folder (or -TestDir); with -Measure only the file given, the card PNG files and one FAKE feedback comment in its folder;
  with -Opened nothing. Reads (R10): the Windows app mode value in the registry (HKCU, read only).
  Credentials: your own CAC sign-in through the PnP web login window (the site part); nothing is stored.
#>
param([string]$Id, [switch]$NoPause, [switch]$PlanOnly, [string]$TestDir, [string]$Measure, [switch]$Opened, [switch]$Again)
$task = 'T22'
$Rev = 'r21'
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
  # The task folder C:\Users\<DODID>\<OneDrive>\RADE\90-161.Z\<Task>: <OneDrive> is the folder name of $env:OneDriveCommercial,
  # else 'OneDrive - United States Air Force' (fleet v2). Until RADE moves the old ...\90-161.Z, that one is used. -Create makes it.
  $odName = if ($env:OneDriveCommercial) { Split-Path -Leaf $env:OneDriveCommercial } else { 'OneDrive - United States Air Force' }; $od = Join-Path (Join-Path 'C:\Users' $Id) $odName
  $app = 'RADE\90-161.Z'
  if (-not (Test-Path -LiteralPath (Join-Path $od $app) -PathType Container) -and (Test-Path -LiteralPath (Join-Path $od '90-161.Z') -PathType Container)) { $app = '90-161.Z' }
  $tail = $odName + '\' + $app + '\' + $Task
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
  $out = & powershell.exe -NoProfile -File (Join-Path $ScriptDir $Step.File) @stepArgs 2>&1
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
# R10 (R37 r1): Hide-Site masks a Feedback comment like every site result line (e-mail addresses, URLs, GUIDs). This window
# never signs in and never calls Get-SiteAddress.
# >>> site-common: generated from scripts/gov/src/site-common.ps1 by scripts/build_task_scripts.py (do not edit)
function Get-SiteAddress([string]$ConfigDir) {
  # One entry (PFM 15 Nov 26): the address RADE holds (RADE_SITE, from its "Site address" box) is used with no question;
  # outside RADE the one saved in Config\90161Z-site.txt is used. Only when neither exists does a question open (once).
  # To change the site, use "Change the site address" in RADE. Kept only on this computer (the repo is public).
  $ok = '^https://[^/\s]+/sites/[^/\s]+'
  $v = ([string]$env:RADE_SITE).Trim()
  if ($v -match $ok) { return $v }
  $f = Join-Path $ConfigDir '90161Z-site.txt'
  if (Test-Path -LiteralPath $f -PathType Leaf) { $v = ([string](Get-Content -LiteralPath $f -TotalCount 1)).Trim(); if ($v -match $ok) { return $v } }
  # RADE runs a step with no window, so a question there would wait unseen: stop with the fix instead.
  if ($env:RADE_CONTRACT) { throw 'SITE ADDRESS not set. Complete the "Site address" box in RADE, then run this step again.' }
  $v = ([string](Read-Host 'Site address (it starts with https://; it is kept only on this computer), then press Enter')).Trim()
  if ($v -notmatch $ok) { throw 'SITE ADDRESS not given or not a site address (https://<host>/sites/<name>). Run again.' }
  if (-not (Test-Path -LiteralPath $ConfigDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $ConfigDir -Force) }
  Set-Content -LiteralPath $f -Value $v -Encoding UTF8
  return $v
}

function Hide-Site([string]$Text, [string]$Site) {
  <#
  .SYNOPSIS
  Masks e-mail addresses, the site, its host, path, name and tenant, other URLs, cloud and .mil hosts and GUIDs in a
  result text. Not masked: display names, office symbols, phone numbers, user ids, computer names.
  .PARAMETER Text
  The text to clean (a result line or an error message).
  .PARAMETER Site
  The site address (https://<host>/sites/<name>), or an empty text for the generic rules only.
  .OUTPUTS
  System.String. The text with each match replaced by a placeholder such as <EMAIL>, <SITE> or <GUID>.
  #>
  # The address only (name, @ or %40, host; encoded characters and an apostrophe inside the name count as part of it),
  # first: the host rules below would
  # keep its name part.
  $Text = $Text -replace '(?:[\w.+=-]|%[0-9A-Fa-f]{2}|(?<=\w)[''\u2019](?=\w))+(?:@|%40)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*(?:%[0-9A-Fa-f]{2})*', '<EMAIL>'
  if ($Site) {
    $Text = $Text -replace [regex]::Escape($Site.TrimEnd('/')), '<SITE>'
    try {
      $u = [uri]$Site; $p = $u.AbsolutePath.TrimEnd('/'); $leaf = ($p -split '/')[-1]   # $p is /sites/<name>: also in URL-encoded form
      $set = @(, @($u.Host, '<SITE-HOST>', ''))   # literal text, placeholder, word boundary (tenant and site name only, 3+ letters)
      if ($p.Length -gt 1) { $set += @($p, '<SITE-PATH>', ''), @([uri]::EscapeDataString($p), '<SITE-PATH>', ''), @($leaf, '<SITE-NAME>', '\b') }
      $set += , @(($u.Host -split '\.')[0], '<TENANT>', '\b')
      foreach ($s in $set) { if ($s[2] -eq '' -or $s[0].Length -ge 3) { $Text = $Text -replace ($s[2] + [regex]::Escape($s[0]) + $s[2]), $s[1] } }
    } catch { $null = $_ }
  }
  # Pattern and mask pairs. The GUID has no \b: guid%27<id> must be masked too.
  $g = @('https?://\S+', '<URL>', '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>',
    '\b[\w.-]+\.mil\b', '<HOST>', '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>')
  for ($i = 0; $i -lt $g.Count; $i += 2) { $Text = $Text -replace $g[$i], $g[$i + 1] }
  return $Text
}
# <<< site-common
# R12 (R39): the Sofia Sans font files next to this script (the round puts them in the T22 folder with it), as the
# RADE UI file wants them: file name -> base64. Takes the folder; returns an empty table when there are none.
function Get-FontTtf([string]$Folder) {
  $out = @{}
  try { foreach ($f in @(Get-ChildItem -LiteralPath $Folder -Filter '*SofiaSans*.ttf' -File -ErrorAction Stop)) {
      $out[$f.Name] = [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.FullName)) } } catch { $null = $_ }
  return $out
}
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
$Parts = @('cards', 'types', 'ui', 'ui2', 'parts', 'grid', 'logo', 'window', 'bar', 'keep', 'feedback', 'measure', 'site')
# The full path of part $Name: 90161Z-T22-<name>-r21.ps1 in this file's folder.
function Get-PartPath([string]$Name) { return (Join-Path $PSScriptRoot ('90161Z-T22-' + $Name + '-' + $Rev + '.ps1')) }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('TASK T22 PFM window preview ' + $Rev + $(if ($Again) { ' (again: the reopen check)' } else { '' }) + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
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
    @(Get-CardPlan) + @(Get-CheckPlan) + @(Get-WalkPlanText) | ForEach-Object { Write-Host $_ }
    Write-Host ('PLAN cards=' + $Cards.Count); return }
  if (-not $Measure) { $who = Get-TaskId $Id }
  if ($Measure) { $dir = '' } elseif ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 22' -Create }
  # R21 (F6 T22; DEC-NIPR invariant 2): the process is not made DPI aware (that call needed compiled code). Windows scales the window (text may look
  # soft at 125 % or more); the form keeps AutoScaleMode Dpi below, so its controls scale with the 96 dpi base.
  $lines.Add('SCALE dpi-aware=no (Windows scales the window)')
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [Windows.Forms.Application]::EnableVisualStyles()
  # R14 (R41 plan row 1): the cards from the PFM lists of the site, read-only; -Measure keeps the FAKE cards.
  . (Get-PartPath 'site')
  if ($Measure) { $lines.Add('SOURCE fake (-Measure builds the window from the FAKE cards; the site is not read)'); $lines.Add('WRITES=0') }
  else { $siteAt = ''; try { $siteAt = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config') } catch { $siteAt = '' }; Invoke-SiteRead $siteAt }
  . (Get-PartPath 'types')
  $script:native = $false   # R21: no HideCaret (it needed compiled code); the shared UI file then leaves the caret alone ($wn.Txt gives the focus away)
  $started = Get-Date
  # Palette tokens (docs/palette.json; tests/run.sh checks each value against it).
  $PalHex = @{ ink = '1B1F2A'; muted = '5B6B7F'; surface = 'EEF1F5'; line = 'C9D2DC'; navy = '0B2545'; onPrimaryMuted = 'DDE8F3'
    accentFill = 'FFD520'; primary = '00539F'; track = '7F93A8'; redTint = 'F6D5DA'; amberTint = 'F8E8C4'; greenTint = 'D6EBDD'; white = 'FFFFFF' }
  $pc = @{}
  foreach ($k in $PalHex.Keys) { $pc[$k] = [Drawing.ColorTranslator]::FromHtml('#' + $PalHex[$k]) }
  $ui = @{}
  $form = New-Object System.Windows.Forms.Form
  # R18 (the PFM, 26 Nov 26, R45): the test window title is "Kanon <bullet> 0.1.0 (FAKE data)"; the bullet is U+2022, built with [char]0x2022
  # so this file stays ASCII. The test window shows only fake rows (the built-in ones, or the marked fake rows of the test site),
  # so the suffix is always there (R44 review MAJOR).
  $form.Text = 'Kanon ' + [char]0x2022 + ' 0.1.0 (FAKE data)'
  $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi'
  $form.ClientSize = [Drawing.Size]::new(1280, 720)
  $form.StartPosition = 'CenterScreen'; $form.KeyPreview = $true; $form.ShowInTaskbar = $true
  $form.Opacity = 0   # shown when the cards are built, at the size and place the PFM gave it
  $ui.Form = $form; $ui.Dpi = 96.0; $ui.FontK = 1.0; $ui.FontDpi = 96.0
  $fontTtf = Get-FontTtf $PSScriptRoot   # R12: the RADE UI file loads these (its LoadFonts); none: Segoe UI
  . (Get-PartPath 'ui'); . (Get-PartPath 'ui2')   # R11: the RADE shared UI file in 2 parts (600-line cap)
  $lines.Add('FONT ' + $ui.FontNote + ' (' + @($fontTtf.Keys).Count + ' font files found)')
  $form.BackColor = $pc.surface
  $ui.Trash = @(@($ui.Trash) | Where-Object { $_ }) + @($ui.Menu)
  $ui.Clock = [System.Diagnostics.Stopwatch]::StartNew(); $ui.CardAt = 0; $ui.GuardMs = 400; $ui.Busy = $false; $ui.Always = @{}; $ui.Boxes = @()
  $ui.B = @(); $ui.P = @()   # the generated NameOf walks these two lists; this window has none (R28: every self-check stopped on a null list)
  $ui.View = ''; $ui.Scrolls = $false; $ui.Scroll = $null; $ui.RecOn = $false; $ui.Picked = $false; $ui.Sent = $null; $ui.Kick = $null
  # The extra layout lines of the self-check ($ui.Measure: the D1 to D4 alignment) are set by the measure part.
  $rail = New-Object System.Windows.Forms.Panel; $rail.Dock = 'Left'; $rail.BackColor = $pc.navy; $rail.AccessibleName = 'Main menu'
  $main = New-Object System.Windows.Forms.Panel; $main.Dock = 'Fill'; $main.BackColor = $pc.surface; $main.AutoScroll = $true; $main.AccessibleName = 'Main column'
  $page = New-Object System.Windows.Forms.FlowLayoutPanel; $page.FlowDirection = 'TopDown'; $page.WrapContents = $false; $page.AutoSize = $true; $page.AutoSizeMode = 'GrowAndShrink'
  $page.BackColor = $pc.surface; [void]$main.Controls.Add($page)
  $form.Controls.Add($main); $form.Controls.Add($rail)
  $wn = @{ Cur = ''; Prev = 'home'; Notice = ''; Err = ''; Field = @{}; Gridsel = $null; Wide = $false; RailBtn = @(); Secs = @(); Light = $true }
  # The crumb's link font (R30 V2): the crumb's own font, underlined; the same family and size as the rest of the crumb.
  try { $wn.CrumbFont = New-Object System.Drawing.Font($ui.F.Small, [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Underline'))
    $ui.Trash = @($ui.Trash) + @($wn.CrumbFont) } catch { $wn.CrumbFont = $ui.F.Small }
  foreach ($part in 'parts', 'grid', 'logo', 'window', 'bar', 'keep', 'feedback', 'measure') { . (Get-PartPath $part) }
  if ($Again) { $Checks[0].Text = Get-AgainText (& $wn.LastKey) }   # R13 (R39 finding 1): the reopen check names the card saved at the last close
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
  if (-not $Measure) { $lines.Add('CHECKS passed=' + $cp + ' failed=' + $cf + ' not answered=' + $cs); foreach ($l in @(& $wn.WalkLines)) { $lines.Add($l) } }
  foreach ($t in @($ui.Trash)) { try { $t.Dispose() } catch { $null = $_ } }
  $form.Dispose()
} catch {
  $code = 1
  $lines.Add('STOPPED: no window (' + ([string]$_.Exception.Message).Substring(0, [Math]::Min(200, ([string]$_.Exception.Message).Length)) + ') at ' + (Get-ErrorPlace $_))
} finally {
  if ($PlanOnly) { exit 0 }
  $lines.Add('WINDOW done: cards=' + $cardsOpened.Count + ' buttons=' + $presses + ' defects=' + $defects.Count + ' checks failed=' + $cf)
  $masked = @($lines | ForEach-Object { $t = [string]$_; if ($who) { $t = ConvertTo-Masked $t $who.Secret }; $t })
  $resName = $(if ($Again) { '90161Z-T22-window-again-' } else { '90161Z-T22-window-' }) + $Rev + '.txt'   # R12: the -Again run keeps the first result
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir $resName) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT -and -not $PlanOnly -and -not $Measure) { [void](Read-Host 'Press Enter to close') }
}
exit $code
