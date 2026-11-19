<#
.SYNOPSIS
  90-161.Z Task 22: the PFM window, test window r9 (round R36). Windows PowerShell 5.1 and Windows Forms only (no module).
.DESCRIPTION
  The PFM's window of the 13-step process with FAKE data (design "preview 2", PFM 17 Nov 26): Your Work, All Actions, Reviews Due,
  steps 8 to 13, a publication, Settings and the states. Nothing is read or sent. The look comes from the RADE shared UI
  file (rade-ui block, generated from the pinned RADE commit). The window keeps the size and place you give it, down to
  600 x 480 at 100 % (half a laptop screen). Esc goes back one card. Close it with its X. A bar at the bottom shows 18
  checks one at a time with Pass and Fail (PFM 17 Nov 26); each layout defect is one line "FAIL LAYOUT ..." and "PASS
  layout" is one line when there is none (the runner counts these words).
  WHAT R9 CHANGES (R36 plan W13: R35 findings 4 and 5, "dead space" and "fluttering"): the layout comes from the current
  window size (Get-T22Layout, $LayoutRevs): gaps a little smaller and scaled by the font; the page as wide as the window
  (r8 kept 900 px at 100 % and scrolled sideways on half a laptop); a side column 32 % of the page, the columns stacked
  when the main one would be under 480 px at 100 %; low-priority grid columns hidden in a narrow grid ($GridDrop); more
  rows in a Fill grid on a taller window. The layout is computed once per new size ($wn.Plan), never while the window
  paints, from the size, the scale and the fonts only, never from a count, a date or a status. R4 to R8 (R30 to R35):
  the part headers. This file loads its 7 parts, 90161Z-T22-<part>-r9.ps1 ($PartRev; renamed from r8 in R36, one revision
  per task), and replaces their layout blocks.
  Inputs: the 7 part files next to this file. Parameters: -Id, -NoPause (RADE). -PlanOnly prints the cards and the 18 checks as
  text and opens no window; -LayoutPlan prints the r8 and r9 layout at the 4 test sizes and opens no window; -TestDir
  writes the files elsewhere; -Measure <file> builds the window off-screen, writes what it measured to <file> as JSON
  (tests/ps/Test-T22Layout.ps1) and the card pictures next to it, and closes, with no question; -SizeCheck <file> does
  so at the 4 test sizes (r8 and r9 layout: rows seen, defects, the stability check $wn.Steady).
  -Opened opens no window: it reads 90161Z-T22-window-r9.txt of the last run and prints one line, PASS the window opened
  (N of M cards) or FAIL the window did not open (the round's look questions run only after a PASS).
  Outputs: 90161Z-T22-window-r9.txt (state, size, scale, cards opened, layout self-check, accessible names, card pictures,
  check answers), 90161Z-T22-window-bounds.json (last size and place) and 90161Z-T22-card-<card>-r9.png (one per card) in
  the T22 folder.
  Last line: WINDOW done: cards=<opened> buttons=<selected> defects=<n> checks failed=<n>. Exit 1 when no window can open.
  Run: by RADE in the round (powershell.exe -File 90161Z-T22-pfm-window-r9.ps1 -Id <DODID> -NoPause), or by hand in the T22 folder.
  Network: none.
  Writes: 90161Z-T22-window-r9.txt, 90161Z-T22-window-bounds.json and the card PNG files in the T22 folder (or -TestDir);
  with -Measure or -SizeCheck only the file given and (-Measure) the card PNG files in its folder; with -Opened or -LayoutPlan nothing.
  Credentials: none.
#>
param([string]$Id, [switch]$NoPause, [switch]$PlanOnly, [string]$TestDir, [string]$Measure, [switch]$Opened, [string]$SizeCheck, [switch]$LayoutPlan)
$task = 'T22'
$Rev = 'r9'
$PartRev = 'r9'   # the revision of the part files this window loads (r9 replaces only their layout blocks)
$Measuring = [bool]($Measure -or $SizeCheck)   # an off-screen run: no task folder, no question, no check answers
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
# ---- R9 (R36 W13): the layout, as pure functions (no window needed: -LayoutPlan runs them anywhere).
# The layout values of each revision, in pixels at 100 %. r8: window r8's, scaled by the control dpi (the size test
# reports r8's rows beside r9's). r9: gaps a little smaller, scaled by the font (FontPad); the page follows the window
# down to PageMin; a side column takes SideShare of the page, at least SideMin, at most its card's own width; columns
# stack when the main one would be under MainMin; Hide: low-priority grid columns hide; CardPadK: the share of a card's
# side padding kept; Reserve: the room under a Fill grid; SideAt: from this width a sideways scroll is a layout defect;
# FormMin: the smallest window (r9: 600 x 480, so half of a 1920 px laptop screen at 150 % fits); the rail is RailNarrow
# wide in a window under NarrowAt (r9: 176 under 1100), 200 up to 1500 and 220 from 1500 (as in r8).
$LayoutRevs = @{
  r8 = @{ PadX = 28; Top = 22; Bottom = 22; ColGap = 18; ColsTop = 12; CardY = 18; CardGap = 14; CardPadK = 1.0; BarPad = 16; Reserve = 70
    PageMin = 900; SideShare = 0.0; SideMin = 0; MainMin = 0; Hide = $false; FontPad = $false; SideAt = 1280; FormMin = @(800, 560); RailNarrow = 200; NarrowAt = 0 }
  r9 = @{ PadX = 22; Top = 16; Bottom = 16; ColGap = 16; ColsTop = 10; CardY = 14; CardGap = 12; CardPadK = 0.85; BarPad = 12; Reserve = 58
    PageMin = 320; SideShare = 0.32; SideMin = 300; MainMin = 480; Hide = $true; FontPad = $true; SideAt = 600; FormMin = @(600, 480); RailNarrow = 176; NarrowAt = 1100 } }
# The grid columns that hide first when a grid is too narrow, in this order (Publication, With, Status, Office and Answer always show).
$GridDrop = @('Weekdays', 'Action', 'Signature', 'Comments', 'Step', 'Due', 'Since')
# The sizes of the size test (-SizeCheck, -LayoutPlan): the PFM's half laptop (R35) and 3 big monitors; K = the scale.
$SizeCases = @(@{ W = 956; H = 1081; K = 1.5 }, @{ W = 1920; H = 1080; K = 1.0 }, @{ W = 2560; H = 1440; K = 1.0 }, @{ W = 3840; H = 2160; K = 1.5 })
# The cards the size test builds twice with other numbers (stability), and the cards whose main grid it counts.
$SteadyCards = @('home', 'queue', 'step8', 'waves'); $RowCards = @('home', 'queue')
# The layout of one window size: pure (only its parameters and $LayoutRevs), so one size gives one layout whatever the
# cards show. ClientW, ClientH: the window's inside; Dpi: the controls' dpi; FontS: the font's scale ($ui.FontK times
# $ui.FontDpi / 96); ScrollW: a scroll bar, always left free (a scroll bar never changes the page); LayoutRev: r9 or r8.
# Gives an ordered table of pixels and factors; a gap is its value at 100 % times S (the font's scale in r9).
function Get-T22Layout([int]$ClientW, [int]$ClientH, [double]$Dpi, [double]$FontS, [int]$ScrollW, [string]$LayoutRev) {
  $p = $LayoutRevs[$LayoutRev]; if (-not $p) { $LayoutRev = 'r9'; $p = $LayoutRevs.r9 }; $k = $Dpi / 96.0; $L = [ordered]@{}; $L['Rev'] = $LayoutRev
  $L['Client'] = [string]$ClientW + 'x' + $ClientH; $L['K'] = $k; $L['S'] = $(if ($p.FontPad) { $FontS } else { $k }); $L['Wide'] = ($ClientW -ge [int][math]::Round(1500 * $k))
  $L['RailW'] = [int]($(if ($L.Wide) { 220 } elseif ($ClientW -lt $p.NarrowAt * $k) { $p.RailNarrow } else { 200 }) * $k)
  foreach ($n in 'PadX', 'Top', 'Bottom', 'ColGap', 'ColsTop', 'BarPad', 'Reserve') { $L[$n] = [int][math]::Round($p[$n] * $L.S) }
  $L['PageW'] = [int][math]::Max([math]::Round($p.PageMin * $k), $ClientW - $L.RailW - $ScrollW - 2 * $L.PadX)
  foreach ($n in 'MainMin', 'SideMin') { $L[$n] = [int][math]::Round($p[$n] * $k) }; $L['OneColMax'] = [int][math]::Round(1000 * $k)
  foreach ($n in 'SideShare', 'CardPadK', 'CardY', 'CardGap', 'Hide', 'SideAt') { $L[$n] = $p[$n] }; $L['FormW'] = [int]($p.FormMin[0] * $k); $L['FormH'] = [int]($p.FormMin[1] * $k)
  return $L }
# The side column width at 100 % that card $Card (key $Key) asks for: Your Work 300 (420 on a wide window), else its Side.
function Get-T22Side100([string]$Key, $Card, [bool]$Wide) {
  if ($Key -eq 'home' -or $Key -eq 'empty') { return $(if ($Wide) { 420 } else { 300 }) }
  return [int]$Card.Side }
# The columns of a card at layout $L, page width $PageW, side width $Side100 asked (Get-T22Side100) and $Count columns:
# @{ Main; Side; Stacked }. One column is as wide as the page, at most 1000 px at 100 %; stacked ones are each the page.
function Get-T22ColumnPlan($L, [int]$PageW, [int]$Side100, [int]$Count) {
  if ($Count -le 1) { return @{ Main = [int][math]::Min($PageW, $L.OneColMax); Side = 0; Stacked = $false } }
  $side = [int][math]::Round($Side100 * $L.K)
  if ($L.SideShare -gt 0) { $side = [int][math]::Min($side, [math]::Max($L.SideMin, [math]::Round($PageW * $L.SideShare))) }
  $mainW = $PageW - $side - $L.ColGap
  if ($L.MainMin -gt 0 -and $mainW -lt $L.MainMin) { return @{ Main = $PageW; Side = $PageW; Stacked = $true } }
  return @{ Main = $mainW; Side = $side; Stacked = $false } }
# The grid columns of $Cols that show in $Room pixels when column i needs $Need[i]: while they need more, the next column
# of $GridDrop hides. Gives the columns that show, in their order.
function Select-T22GridColumn($Cols, [int[]]$Need, [int]$Room) {
  $all = @($Cols); $keep = @(0..($all.Count - 1)); $sum = 0; foreach ($n in $Need) { $sum += $n }
  foreach ($name in $GridDrop) {
    if ($sum -le $Room) { break }
    $i = @($keep | Where-Object { [string]$all[$_].N -eq $name }) | Select-Object -First 1
    if ($null -ne $i) { $keep = @($keep | Where-Object { $_ -ne $i }); $sum -= $Need[$i] } }
  return , @(foreach ($i in $keep) { $all[$i] }) }
# A copy of card data $Value with other numbers (the stability check): each digit d becomes (d + 5) mod 10, so every
# count, date and status keeps its length; a "{0}" place holder stays. Tables and lists are copied, other values kept.
function ConvertTo-T22Varied($Value) {
  if ($Value -is [string]) { return [regex]::Replace($Value, '(?<!\{)\d(?!\})', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) [string]((([int][string]$m.Value) + 5) % 10) }) }
  if ($Value -is [array]) { return , @(foreach ($x in $Value) { ConvertTo-T22Varied $x }) }
  if (-not ($Value -is [System.Collections.IDictionary])) { return $Value }
  $o = $(if ($Value -is [System.Collections.Specialized.OrderedDictionary]) { [ordered]@{} } else { @{} })
  foreach ($key in @($Value.Keys)) { $o[$key] = ConvertTo-T22Varied $Value[$key] }
  return $o }
# -LayoutPlan: the r8 and r9 layout at each size of the size test, with no window: one PLAN line of pixels per size and
# revision, one of the columns of each card with two. Assumed (the window measures both): fonts follow the controls, a scroll bar is 17 px at 100 %.
function Write-T22Plan {
  foreach ($c in $SizeCases) { foreach ($r in 'r8', 'r9') {
      $L = Get-T22Layout $c.W $c.H (96 * $c.K) $c.K ([int][math]::Round(17 * $c.K)) $r
      $nums = @('RailW', 'PageW', 'PadX', 'Top', 'Bottom', 'ColGap', 'ColsTop', 'BarPad', 'Reserve') | ForEach-Object { $_ + ' ' + $L[$_] }
      $card = 'card padding ' + [math]::Round(24 * $L.CardPadK * $L.S) + ' x ' + [math]::Round($L.CardY * $L.S) + ', CardGap ' + [math]::Round($L.CardGap * $L.S)
      Write-Host ('PLAN ' + $r + ' ' + $L.Client + ' at ' + [int]($c.K * 100) + ' %: ' + ($nums -join ', ') + ', ' + $card)
      $cols = @(foreach ($k in @($Cards.Keys)) { $n = @($Cards[$k].Cols).Count; if ($n -lt 2) { continue }
          $p = Get-T22ColumnPlan $L $L.PageW (Get-T22Side100 $k $Cards[$k] $L.Wide) $n; $k + ' ' + $(if ($p.Stacked) { 'stacked ' + $p.Main } else { [string]$p.Main + '+' + $p.Side }) })
      Write-Host ('PLAN ' + $r + ' ' + $L.Client + ' columns: ' + ($cols -join ', ')) } } }
# scripts that load each other by file name stay in one folder).
$Parts = @('cards', 'types', 'ui', 'parts', 'grid', 'window', 'measure')
# The full path of part $Name: 90161Z-T22-<name>-<$PartRev>.ps1 in this file's folder.
function Get-PartPath([string]$Name) { return (Join-Path $PSScriptRoot ('90161Z-T22-' + $Name + '-' + $PartRev + '.ps1')) }
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
  if ($LayoutPlan) { Write-T22Plan; return }
  if (-not $Measuring) { $who = Get-TaskId $Id }
  if ($Measuring) { $dir = '' } elseif ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 22' -Create }
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
  # The extra layout lines of the self-check ($ui.Measure: the D1 to D4 alignment) are set by the measure part.
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
  # ---- R9 (R36 W13): the layout from the current window size. The blocks below replace r8 blocks of the window and
  # grid parts (an r8 block that is kept and called is named <name>8); each one reads the layout $wn.L.
  $wn.LayoutRev = 'r9'; $wn.Host = $form; $wn.Stacked = $false; $wn.LKey = ''; $wn.LCount = 0; $wn.BarFor = $null
  # The r8 blocks that the r9 blocks below call (each r9 block of the same name wraps one).
  $wn.Card8 = $wn.Card; $wn.GridHeight8 = $wn.GridHeight; $wn.GridCols8 = $wn.GridCols; $wn.GridFill8 = $wn.GridFill
  $wn.Filter8 = $wn.Blocks.filter; $wn.LevelFacts8 = $wn.LevelFacts; $wn.Hook8 = $wn.Hook
  # The layout of the current size, scale and fonts: computed again only when one of them changed (once per new size).
  $wn.Plan = { $h = $wn.Host.ClientSize; $fs = [double]$ui.FontK * [double]$ui.FontDpi / 96.0
    $key = [string]$h.Width + 'x' + $h.Height + '|' + $ui.Dpi + '|' + $fs + '|' + $wn.LayoutRev; if ($key -eq $wn.LKey) { return }
    $wn.L = Get-T22Layout $h.Width $h.Height $ui.Dpi $fs ([Windows.Forms.SystemInformation]::VerticalScrollBarWidth) $wn.LayoutRev
    $wn.LKey = $key; $wn.LCount++ }
  # A gap of $Px pixels at 100 %, at the layout's scale (the font's in r9).
  $wn.G = { param([double]$Px) return [int][math]::Round($Px * $wn.L.S) }
  # The side padding of a section card whose card data gives $PadX (at 100 %).
  $wn.CardPad = { param([int]$PadX) return (& $wn.G ($PadX * $wn.L.CardPadK)) }
  # The rail width of the layout; the check bar is fitted first (the bar's height sets the room the main column has).
  $wn.RailLayout = { & $wn.Plan; & $wn.BarFit; $rail.Width = $wn.L.RailW; foreach ($x in $wn.RailBtn) { $x.Width = $wn.L.RailW - 2 * (& $wn.Sc 12) } }
  # A section card: the r8 card with the layout's padding (its data's PadX times CardPadK, CardY above and below) and gap under it.
  $wn.Card = { param([int]$W, $Cap, $Top, [int]$PadX, $Back)
    $c = & $wn.Card8 $W $Cap $Top $PadX $Back; $px = & $wn.CardPad $PadX; $tp = $(if ($Top) { 4 } else { 0 })
    $c.Padding = & $ui.Pad $px (& $wn.G ($wn.L.CardY + $tp)) $px (& $wn.G $wn.L.CardY); $c.Margin = & $ui.Pad 0 0 0 (& $wn.G $wn.L.CardGap)
    if ($Cap) { & $ui.SetWrap $c.Controls[0] ($W - 2 * $px) }
    return $c }
  $wn.ShowCols = {
    <#
    .SYNOPSIS
    R9: the columns of a card, side by side when the main one keeps its minimum, else stacked (Get-T22ColumnPlan; then no
    Action Status card is leveled or lined up: Stretch is off). Each section is kept in $wn.Secs, as in r8.
    .PARAMETER C
    The card data.
    .PARAMETER Key
    The card key (Get-T22Side100).
    .PARAMETER Cw
    The width of the page column.
    .PARAMETER Wide
    True when the window is wide (WideOnly sections show, the side column of Your Work is wider).
    #>
    param($C, [string]$Key, [int]$Cw, [bool]$Wide)
    $nc = @($C.Cols).Count; $plan = Get-T22ColumnPlan $wn.L $Cw (Get-T22Side100 $Key $C $Wide) $nc; $wn.Stacked = $plan.Stacked
    $cols = New-Object System.Windows.Forms.FlowLayoutPanel; $cols.FlowDirection = $(if ($plan.Stacked) { 'TopDown' } else { 'LeftToRight' })
    $cols.WrapContents = $false; $cols.AutoSize = $true; $cols.AutoSizeMode = 'GrowAndShrink'
    $cols.BackColor = $pc.surface; $cols.Margin = & $ui.Pad 0 $wn.L.ColsTop 0 0; [void]$page.Controls.Add($cols)
    $ci = 0
    foreach ($colDef in @($C.Cols)) {
      $colW = $(if ($ci -eq 0 -or $plan.Stacked) { $plan.Main } else { $plan.Side })
      $col = New-Object System.Windows.Forms.FlowLayoutPanel; $col.FlowDirection = 'TopDown'; $col.WrapContents = $false; $col.AutoSize = $true; $col.AutoSizeMode = 'GrowAndShrink'
      $col.BackColor = $pc.surface; $col.Margin = & $ui.Pad 0 0 $(if ($ci -eq 0 -and $nc -gt 1 -and -not $plan.Stacked) { $wn.L.ColGap } else { 0 }) 0; [void]$cols.Controls.Add($col)
      $ctx = @{ Col = $col }
      foreach ($s in @($colDef)) {
        if ($s.WideOnly -and -not $Wide) { continue }
        $px = $(if ($s.Pad) { [int]$s.Pad } else { 24 })
        $sec = & $wn.Card $colW $s.Cap $s.Top $px $pc.surface; [void]$col.Controls.Add($sec)
        $wn.Secs += @{ Col = $ci; Card = $sec; Cap = [string]$s.Cap; Stretch = ([bool]$s.Stretch -and -not $plan.Stacked); CapBox = $(if ($s.Cap) { $sec.Controls[0] } else { $null }) }
        foreach ($b in @($s.Blocks)) { & $wn.Block $sec $b ($colW - 2 * (& $wn.CardPad $px)) $ctx }
        $sec.PerformLayout() }
      $ci++ } }
  $wn.Show = {
    <#
    .SYNOPSIS
    R9: shows the card $Key as r8 did, with the layout of the current size ($wn.Plan).
    .DESCRIPTION
    The page is as wide as the layout says (the room for a scroll bar is always kept, so a scroll bar coming or going
    never changes it); its gaps are the layout's; the count line keeps its lines ($wn.HoldCount). The rest is r8's:
    a new card forgets the last one's fields, the head and the columns are built, the side captions are leveled (D1),
    the column bottoms lined up, the focus set, and the layout self-check runs a moment later.
    .PARAMETER Key
    The card key in $Cards; an unknown key does nothing.
    #>
    param([string]$Key)
    $c = $Cards[$Key]; if (-not $c) { return }
    & $wn.Plan; $L = $wn.L
    if ($Key -ne $wn.Cur) { if ($c.Modal) { $wn.Prev = $wn.Cur }; $wn.Field = @{}; $wn.Err = ''; $wn.Focus = '' }
    $script:cardsOpened[$Key] = $true; $wn.Cur = $Key; $ui.View = $Key
    $wn.Primary = $null; $wn.Gridsel = $null; $wn.Gridq = $null; $wn.Reason = $null; $wn.CountBox = $null; $wn.CrumbLink = $null; $wn.CrumbRest = $null; $wn.Secs = @(); $wn.ChipRows = @()
    $ui.Wrap = @{}; $ui.Hold = @{}; $ui.Boxes = @(); $ui.Hot = $null; $ui.Down = $null
    $main.AutoScrollPosition = [Drawing.Point]::new(0, 0)
    $form.SuspendLayout(); $page.SuspendLayout()
    foreach ($x in @($page.Controls)) { $page.Controls.Remove($x); $x.Dispose() }
    $wn.Wide = $L.Wide; $wn.MainH = $main.ClientSize.Height
    $page.Location = [Drawing.Point]::new($L.PadX, $L.Top); $page.Margin = & $ui.Pad 0 0 0 0; $page.Padding = & $ui.Pad 0 0 0 $L.Bottom
    foreach ($r in $wn.RailBtn) { $r.On = ([string]$r.Tag -eq [string]$c.Rail); $r.Invalidate() }
    & $wn.ShowHead $c $L.PageW
    $page.PerformLayout(); $wn.HeadH = [int]$page.PreferredSize.Height
    & $wn.ShowCols $c $Key $L.PageW $L.Wide
    $page.ResumeLayout($true); $form.ResumeLayout($true)
    & $wn.HoldCount; & $wn.LevelCaps; & $wn.Align
    $main.AutoScrollPosition = [Drawing.Point]::new(0, 0)
    $form.AcceptButton = $wn.Primary
    $ui.CardAt = $ui.Clock.Elapsed.TotalMilliseconds
    if ($wn.Focus -eq 'reason' -and $wn.Reason) { [void]$wn.Reason.Focus(); $wn.Focus = '' } elseif ($wn.Primary) { [void]$wn.Primary.Focus() }
    if ($wn.Ready) { $wn.CheckTimer.Stop(); $wn.CheckTimer.Start() } }
  $wn.ListRow = {
    <#
    .SYNOPSIS
    R9: one row of a list, as in r8 (a chip, a title, up to two gray lines, a compact button at the right), but the button
    goes under the text when the text would keep less than 160 px at 100 % beside it (a narrow window).
    .PARAMETER Parent
    The card that gets the row.
    .PARAMETER It
    The list item: Chip, Title, Sub, Detail, Btn.
    .PARAMETER W
    The width of the row.
    .PARAMETER Tx
    Where the text starts (the width of the widest chip of the list and a gap; 0 without chips).
    #>
    param($Parent, $It, [int]$W, [int]$Tx)
    $p = & $wn.Panel $W 0; $bw = 0; $btn = $null
    if ($It.Btn) { $btn = & $wn.Button $It.Btn 'compact'; $btn.AutoSize = $true; $bw = [math]::Max($btn.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $btn.MinimumSize.Width) }
    $tw = $W - $Tx - $bw - (& $wn.Sc 24); $under = ($btn -and $tw -lt (& $wn.Sc 160)); if ($under) { $tw = $W - $Tx - (& $wn.Sc 8) }
    $y = & $wn.Sc 8; $t1 = & $wn.Txt $p $It.Title $ui.F.SmallB $ui.C.Ink 0 $tw 'Item' $null
    if ($It.Chip) { $cp = & $wn.Chip $It.Chip[0] $It.Chip[1] $ui.C.White; $tops = & $wn.ChipTops $cp.Height $t1.Font $y; $y = $tops.Text
      $cp.Location = [Drawing.Point]::new(0, $tops.Chip); [void]$p.Controls.Add($cp); & $wn.KeepChip $cp $t1 'list' }
    $t1.Location = [Drawing.Point]::new($Tx, $y); $y = $t1.Bottom + (& $wn.Sc 2)
    if ($It.Sub) { $t2 = & $wn.Txt $p $It.Sub $ui.F.Small $ui.C.Gray 0 $tw 'Item detail' $null; $t2.Location = [Drawing.Point]::new($Tx, $y); $y = $t2.Bottom + (& $wn.Sc 2) }
    if ($It.Detail) { $t3 = & $wn.Txt $p $It.Detail $ui.F.Small $ui.C.Gray 0 $tw 'Item detail' $null; $t3.Location = [Drawing.Point]::new($Tx, $y); $y = $t3.Bottom }
    if ($btn) { $btn.Size = [Drawing.Size]::new($bw, $btn.MinimumSize.Height)
      $by = $(if ($under) { $y + (& $wn.Sc 4) } else { [math]::Max((& $wn.Sc 6), [int](($y + (& $wn.Sc 8) - $btn.Height) / 2)) })
      $btn.Location = [Drawing.Point]::new($(if ($under) { $Tx } else { $W - $bw - (& $wn.Sc 4) }), $by); [void]$p.Controls.Add($btn) }
    & $wn.Fit $p 8; [void]$Parent.Controls.Add($p) }
  # The count line under the All Actions grid keeps the lines its longest count needs, so a filter never moves what is under it.
  $wn.HoldCount = { $t = $wn.CountBox; if (-not $t) { return }
    $m = & $ui.Meas ([string]$wn.CountText -f 888) $t.Font ([int]$ui.Wrap[$t])
    $ui.Hold[$t] = [math]::Max(1, [int][math]::Round($m.Height / [double](& $wn.LineH $t.Font))); & $ui.Reflow $t; $page.PerformLayout() }
  # A Fill grid keeps the layout's room under it (Reserve) instead of r8's 70 px at 100 %; the rest is r8's ($wn.GridHeight8).
  $wn.GridHeight = { param($b, $Ctx) $keep = $wn.MainH; $wn.MainH = $keep + (& $wn.Sc 70) - $wn.L.Reserve
    try { return (& $wn.GridHeight8 $b $Ctx) } finally { $wn.MainH = $keep } }
  # The columns of a grid: with Hide on, the low-priority ones that do not fit hide (Select-T22GridColumn): a column needs its
  # own width or its head, the pub column its whole number and title ($PubMin). Then r8 sizes the rest ($wn.GridCols8).
  $wn.GridCols = { param($G, $Cols, [int]$W, [int]$Scroll, [int]$PubMin)
    if ($wn.L.Hide) {
      $need = @(foreach ($c in @($Cols)) { if ($c.K -eq 'pub' -and $PubMin -gt 0) { $PubMin } else { [math]::Max((& $wn.Sc $(if ($c.W) { $c.W } else { 60 })), (& $wn.HeadMin $c)) } })
      $bar = $(if ($PubMin -gt 0) { [math]::Max($Scroll, [Windows.Forms.SystemInformation]::VerticalScrollBarWidth) } else { $Scroll })
      $Cols = Select-T22GridColumn $Cols $need ($W - $bar - 2) }
    return (& $wn.GridCols8 $G $Cols $W $Scroll $PubMin) }
  # A grid's rows fill only the columns that show (a hidden column has no value).
  $wn.GridFill = { param($G, $Rows) $G.Tag.Cols = @(@($G.Tag.Cols) | Where-Object { $G.Columns.Contains([string]$_.N) }); & $wn.GridFill8 $G $Rows }
  # The search row above the All Actions grid wraps inside its card (r8: one row of fixed widths, wider than a narrow card).
  $wn.Blocks.filter = { param($Parent, $b, [int]$W) $null = $b; & $wn.Filter8 $Parent
    $f = $Parent.Controls[$Parent.Controls.Count - 1]; $f.WrapContents = $true; $f.MaximumSize = [Drawing.Size]::new($W, 0) }
  # The level facts (measure part) also say whether the card's columns were stacked (then no caption is leveled: D1).
  $wn.LevelFacts = { $f = & $wn.LevelFacts8; $f['Stacked'] = [bool]$wn.Stacked; return $f }
  $wn.BarFit = {
    <#
    .SYNOPSIS
    R9: lays out the check bar for the window width (r8's bar layout with the layout's BarPad): the check text at the
    left, as tall as the longest check needs, and Pass and Fail at the right, centered in the bar.
    #>
    if (-not $wn.Bar) { return }
    & $wn.Plan; $w = $wn.Host.ClientSize.Width; $pad = $wn.L.BarPad; $gap = & $wn.Sc 8
    $pw = [math]::Max($wn.BarPass.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.BarPass.MinimumSize.Width)
    $fw = [math]::Max($wn.BarFail.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.BarFail.MinimumSize.Width)
    $bh = [math]::Max($wn.BarPass.Height, $wn.BarFail.Height); $tw = [math]::Max((& $wn.Sc 200), $w - 2 * $pad - $pw - $fw - 2 * $gap)
    $th = 0; foreach ($c in $Checks) { $m = & $ui.Meas ([string]$c.Text) $ui.F.Body $tw; $th = [math]::Max($th, [int]$m.Height) }
    $th += (& $wn.Sc 6); $nh = [int]$wn.BarNo.PreferredSize.Height
    $wn.Bar.Height = [math]::Max($bh + 2 * $pad, $pad + $nh + (& $wn.Sc 2) + $th + $pad)
    $wn.BarNo.Location = [Drawing.Point]::new($pad, $pad)
    $wn.BarText.Location = [Drawing.Point]::new($pad, ($pad + $nh + (& $wn.Sc 2))); & $ui.SetWrap $wn.BarText $tw; $wn.BarText.Size = [Drawing.Size]::new($tw, $th)
    $by = [int](($wn.Bar.Height - $bh) / 2)
    $wn.BarPass.Location = [Drawing.Point]::new(($w - $pad - $fw - $gap - $pw), $by); $wn.BarFail.Location = [Drawing.Point]::new(($w - $pad - $fw), $by)
    $wn.BarFor = $wn.Bar }
  # r8 laid out the bar at every size event; r9 fits a new bar at once and, while the window is open, leaves the rest to
  # the end of the resize ($wn.RailLayout runs $wn.BarFit there, once).
  $wn.BarLayout = { if ($wn.Ready -and [object]::ReferenceEquals($wn.BarFor, $wn.Bar)) { return }; & $wn.BarFit }
  # Grid columns wider than their grid, and a main column that scrolls sideways from the layout's SideAt width (r9: 600
  # at 100 %, r8: 1280), are layout defects; a card whose main column scrolls down is noted in $wn.Scrolled.
  $wn.ScrollCheck = {
    $st = New-Object System.Collections.Stack; $st.Push($page)
    while ($st.Count) { foreach ($c in $st.Pop().Controls) {
        if ($c -is [Windows.Forms.DataGridView]) { $sum = 0; foreach ($k in $c.Columns) { if ($k.Visible) { $sum += $k.Width } }
          if ($sum -gt $c.ClientSize.Width + 1) { $ui.LayBad.Add('LAYOUT ' + $wn.Cur + ' grid ' + $c.AccessibleName + ' columns need ' + $sum + ', the grid has ' + $c.ClientSize.Width) } }
        elseif ($c.Controls.Count) { $st.Push($c) } } }
    $hs = $wn.Host.ClientSize; $logicalW = [int]($hs.Width / ([math]::Max(0.5, $ui.Dpi / 96.0)))
    if ($logicalW -ge $wn.L.SideAt -and $main.HorizontalScroll.Visible) { $ui.LayBad.Add('LAYOUT ' + $wn.Cur + ' the main column scrolls sideways at ' + $hs.Width + 'x' + $hs.Height) }
    if ($main.VerticalScroll.Visible) { $wn.Scrolled[$wn.Cur] = 1 } }
  $wn.Start = {
    <#
    .SYNOPSIS
    R9: starts the window when it is first shown, as r8 did, with the smallest size of the layout (600 x 480 at 100 %).
    .DESCRIPTION
    Its place, its scale, its smallest size, its colors, every card once (with the card pictures), then Your Work; the
    high-contrast handler and the mouse-wheel filter (removed when the window closes, $wn.Hook).
    #>
    & $wn.LoadBounds
    & $ui.FormDpi; & $wn.Plan
    $form.MinimumSize = [Drawing.Size]::new($wn.L.FormW, $wn.L.FormH)
    & $wn.Recolor 'start'
    $wn.PngDir = $dir
    & $wn.Build $null
    & $wn.PngLines
    $wn.Pref = [Microsoft.Win32.UserPreferenceChangedEventHandler]{
      try { & $wn.Recolor 'changed' } catch { $lines.Add('NOTE the colors were not re-applied: ' + ([string]$_.Exception.Message)) } }
    try { [Microsoft.Win32.SystemEvents]::add_UserPreferenceChanged($wn.Pref) } catch { $lines.Add('NOTE no high-contrast change event: ' + ([string]$_.Exception.Message)); $wn.Pref = $null }
    & $wn.WheelOn
    $wn.Ready = $true; $form.Opacity = 1
    try { $form.TopMost = $true; $form.Activate(); $form.TopMost = $false } catch { $null = $_ } }
  # The window's events as in r8 ($wn.Hook8), and the end of a resize lays out the window at once (no wait for the timer).
  $wn.Hook = { & $wn.Hook8; $form.Add_ResizeEnd({ if ($wn.Ready) { $wn.SizeTimer.Stop(); & $wn.Resized } }) }
  # A new size: the rail, the bar and the card, once (as the r8 size timer does after the last size change).
  $wn.Resized = { if ($form.ClientSize.Width -eq $wn.LastW -and $form.ClientSize.Height -eq $wn.LastH) { return }
    $wn.LastW = $form.ClientSize.Width; $wn.LastH = $form.ClientSize.Height; & $wn.RailLayout; & $wn.Show $wn.Cur }
  # ---- R9 (R36 W13): the size test (-SizeCheck). The window's parts sit in a host panel of the test size (a panel is
  # not held to the screen's size, as a window is), at the test scale as $wn.MeasureScaled sets it.
  # Sets the scale $K times the start scale $Base (Dpi, FontK, F, Crumb, Step), as $wn.MeasureScaled does: the dpi, the font
  # factor and every font. Gives the fonts made (the caller disposes them).
  $wn.UseScale = { param($Base, [double]$K)
    $made = New-Object System.Collections.Generic.List[object]; $ui.Dpi = $Base.Dpi * $K; $ui.FontK = $Base.FontK * $K
    $ui.F = $Base.F; $wn.CrumbFont = $Base.Crumb; $wn.StepFonts = $Base.Step; if ($K -eq 1.0) { return , $made }
    $nf = @{}; foreach ($n in @($Base.F.Keys)) { $o = $Base.F[$n]; $x = New-Object System.Drawing.Font($o.FontFamily, [single]($o.Size * $K), $o.Style); $nf[$n] = $x; $made.Add($x) }
    $ui.F = $nf; $wn.StepFonts = $null
    $wn.CrumbFont = New-Object System.Drawing.Font($nf.Small, [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Underline')); $made.Add($wn.CrumbFont)
    return , $made }
  # Builds the rail and the check bar again in the host panel $HostP, at the current scale (the bar first: the rail fits it).
  $wn.Rebuild = { param($HostP)
    foreach ($x in @($rail.Controls)) { $rail.Controls.Remove($x); $x.Dispose() }
    if ($wn.Bar) { $wn.Bar.Parent.Controls.Remove($wn.Bar); $wn.Bar.Dispose(); $wn.Bar = $null }
    & $wn.BuildBar; $form.Controls.Remove($wn.Bar); [void]$HostP.Controls.Add($wn.Bar); $main.BringToFront()
    $wn.RailBtn = @(); & $wn.BuildRail; [Windows.Forms.Application]::DoEvents() }
  # The rows of the card's main grid ($wn.Gridsel): Grid = the rows the grid shows whole; Screen = the rows that show whole
  # with the main column at its top (no scrolling); Total = all its rows.
  $wn.RowsSeen = { $g = $wn.Gridsel; if (-not $g) { return $null }
    $room = [math]::Min($g.ClientSize.Height, $main.ClientSize.Height - $page.Top - (& $wn.PageTop $g)) - $g.ColumnHeadersHeight
    $seen = 0; $y = 0; foreach ($row in $g.Rows) { $y += $row.Height; if ($y -le $room) { $seen++ } else { break } }
    return @{ Grid = [int]$g.DisplayedRowCount($false); Screen = $seen; Total = [int]$g.Rows.Count } }
  # Every control under the window's host as "path type bounds", in tree order (no text: only where things are).
  $wn.Snap = { $out = New-Object System.Collections.Generic.List[string]; $st = New-Object System.Collections.Stack; $st.Push(@($wn.Host, 'w'))
    while ($st.Count) { $it = $st.Pop(); $i = 0
      foreach ($c in $it[0].Controls) { $p = $it[1] + '/' + $i + $c.GetType().Name; $out.Add($p + ' ' + $c.Bounds); if ($c.Controls.Count) { $st.Push(@($c, $p)) }; $i++ } }
    return , $out.ToArray() }
  # The layout as one line of text (the stability check compares it).
  $wn.PlanText = { return (@($wn.L.Keys | ForEach-Object { [string]$_ + '=' + $wn.L[$_] }) -join ';') }
  # The stability check of card $Key (R35 finding 5): the card is shown again with other numbers (ConvertTo-T22Varied);
  # no control may move or change its size, nor the layout change. Gives the differences, at most 5 (none: stable).
  $wn.Steady = { param([string]$Key)
    $a = & $wn.Snap; $la = & $wn.PlanText; $keep = $Cards[$Key]; $b = @(); $lb = ''
    try { $Cards[$Key] = ConvertTo-T22Varied $keep; & $wn.Show $Key; [Windows.Forms.Application]::DoEvents(); $b = & $wn.Snap; $lb = & $wn.PlanText }
    finally { $Cards[$Key] = $keep; & $wn.Show $Key; [Windows.Forms.Application]::DoEvents() }
    $d = @(); if ($la -ne $lb) { $d += ('layout ' + $la + ' -> ' + $lb) }
    if ($a.Count -ne $b.Count) { $d += ('controls ' + $a.Count + ' -> ' + $b.Count) }
    else { for ($i = 0; $i -lt $a.Count -and $d.Count -lt 5; $i++) { if ($a[$i] -ne $b[$i]) { $d += ($a[$i] + ' -> ' + $b[$i]) } } }
    return , $d }
  # One size of the size test ($Case: W, H, K) with layout $LayoutRev in host panel $HostP: the rail and bar built again,
  # every card (r9) or those of $RowCards (r8) shown with the self-check, the rows seen, and (r9) the stability check.
  # Gives W, H, K, Rev, Layout, Count (layouts computed in this size: 1), Defects (LAYOUT lines), Cards (Key, Stacked, Sideways, Rows, Moved).
  $wn.SizeCase = { param($HostP, $Case, [string]$LayoutRev)
    $c0 = $wn.LCount; $wn.LayoutRev = $LayoutRev; $HostP.Size = [Drawing.Size]::new([int]$Case.W, [int]$Case.H); & $wn.Rebuild $HostP
    $n0 = $ui.LayBad.Count; $ui.LaySeen = @{}; $cards = New-Object System.Collections.Generic.List[object]; foreach ($k in @($Cards.Keys)) {
      if ($LayoutRev -eq 'r8' -and $RowCards -notcontains $k) { continue }
      $wn.Notice = ''; $wn.Err = ''; & $wn.Show $k; [Windows.Forms.Application]::DoEvents(); & $ui.Check; & $wn.ScrollCheck
      $r = @{ Key = $k; Stacked = [bool]$wn.Stacked; Sideways = [bool]$main.HorizontalScroll.Visible }
      if ($RowCards -contains $k) { $r['Rows'] = (& $wn.RowsSeen) }; if ($LayoutRev -eq 'r9' -and $SteadyCards -contains $k) { $r['Moved'] = & $wn.Steady $k }
      $cards.Add($r) }   # the LAYOUT lines go to the JSON file, not to this run's defects (the r8 values are not this window's)
    $bad = @($ui.LayBad | Select-Object -Skip $n0 | ForEach-Object { [string]$_ }); while ($ui.LayBad.Count -gt $n0) { $ui.LayBad.RemoveAt($n0) }
    return @{ W = $Case.W; H = $Case.H; K = $Case.K; Rev = $LayoutRev; Layout = $wn.L; Count = ($wn.LCount - $c0); Defects = $bad; Cards = $cards.ToArray() } }
  $wn.SizeRun = {
    <#
    .SYNOPSIS
    The -SizeCheck run (R36 W13): each size of $SizeCases with the r8 and the r9 layout, written to $Path as JSON.
    .DESCRIPTION
    The window is shown far off the screen (never seen); its rail, main column and bar move into a host panel, which
    the layout reads as the window ($wn.Host, and $ui.Form for the self-check). A size that cannot be measured keeps
    its error. At the end the start scale comes back, Your Work is shown, and the fonts made are disposed.
    .PARAMETER Path
    The JSON file to write.
    #>
    param([string]$Path)
    $form.StartPosition = 'Manual'; $form.ShowInTaskbar = $false; $form.Location = [Drawing.Point]::new(-20000, -20000)
    $form.Show(); [Windows.Forms.Application]::DoEvents(); & $ui.FormDpi; $form.BackColor = $pc.surface
    $hostP = New-Object System.Windows.Forms.Panel; $hostP.BackColor = $pc.surface; $hostP.AccessibleName = 'Size test'
    $form.Controls.Remove($main); $form.Controls.Remove($rail); [void]$hostP.Controls.Add($main); [void]$hostP.Controls.Add($rail); $form.Controls.Add($hostP)
    $wn.Host = $hostP; $keepForm = $ui.Form; $ui.Form = $hostP
    $base = @{ Dpi = $ui.Dpi; FontK = $ui.FontK; F = $ui.F; Crumb = $wn.CrumbFont; Step = $wn.StepFonts }
    $res = New-Object System.Collections.Generic.List[object]; $made = New-Object System.Collections.Generic.List[object]
    try {
      foreach ($case in $SizeCases) { foreach ($lr in 'r8', 'r9') {
          foreach ($x in (& $wn.UseScale $base ([double]$case.K))) { $made.Add($x) }
          try { $res.Add((& $wn.SizeCase $hostP $case $lr)) }
          catch { $res.Add(@{ W = $case.W; H = $case.H; K = $case.K; Rev = $lr; Error = ([string]$_.Exception.Message + ' at ' + (Get-ErrorPlace $_)) }) }
          if ($wn.StepFonts -and -not [object]::ReferenceEquals($wn.StepFonts, $base.Step)) { foreach ($x in @($wn.StepFonts.A) + @($wn.StepFonts.B)) { $made.Add($x) } } } }
    } finally {
      $wn.LayoutRev = 'r9'; $null = & $wn.UseScale $base 1.0; & $wn.Rebuild $hostP; $wn.Notice = ''; & $wn.Show 'home'
      $ui.Form = $keepForm; foreach ($x in $made) { try { $x.Dispose() } catch { $null = $_ } } }
    $out = @{ Rev = $Rev; Dpi = $base.Dpi; Cases = $res.ToArray() }
    Set-Content -LiteralPath $Path -Value ($out | ConvertTo-Json -Depth 8) -Encoding UTF8
    $form.Close() }
  if ($SizeCheck) { & $wn.SizeRun $SizeCheck } elseif ($Measure) { & $wn.MeasureRun $Measure } else { & $wn.Hook; [void]$form.ShowDialog() }
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
  for ($i = 0; $i -lt $Checks.Count -and -not $Measuring; $i++) {
    $a = [string]$wn.Answers[$i]
    if ($a -eq 'PASS') { $cp++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' PASS') }
    elseif ($a -eq 'FAIL') { $cf++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' FAIL') }
    else { $cs++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' FAIL (not answered)') } }
  if (-not $Measuring) { $lines.Add('CHECKS passed=' + $cp + ' failed=' + $cf + ' not answered=' + $cs) }
  foreach ($t in @($ui.Trash)) { try { $t.Dispose() } catch { $null = $_ } }
  $form.Dispose()
} catch {
  $code = 1
  $lines.Add('STOPPED: no window (' + ([string]$_.Exception.Message).Substring(0, [Math]::Min(200, ([string]$_.Exception.Message).Length)) + ') at ' + (Get-ErrorPlace $_))
} finally {
  if ($PlanOnly -or $LayoutPlan) { exit 0 }
  $lines.Add('WINDOW done: cards=' + $cardsOpened.Count + ' buttons=' + $presses + ' defects=' + $defects.Count + ' checks failed=' + $cf)
  $masked = @($lines | ForEach-Object { $t = [string]$_; if ($who) { $t = ConvertTo-Masked $t $who.Secret }; $t })
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T22-window-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT -and -not $PlanOnly -and -not $Measuring) { [void](Read-Host 'Press Enter to close') }
}
exit $code
