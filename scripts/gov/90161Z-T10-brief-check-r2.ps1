<#
.SYNOPSIS
  90-161.Z Task 10 brief check, r2. Windows PowerShell 5.1, PowerPoint 16 COM only (no modules).
.DESCRIPTION
  Opens each decision brief in the T10 folder read-only and without a window, and checks what a person would
  look for first: the file opens (no repair), the slide count, text taller than its box (overflow) and shapes
  that reach past the slide edge. One line per brief, PASS or FAIL, plus one line per problem (slide number and
  shape name). The briefs hold no personal data; the DODID and profile folder are replaced by <DODID>.
  Output: 90161Z-T10-check-r1.txt in the T10 folder (send this).
  Parameters (used by the 90-161.Z Deployer): -Id, -NoPause skip the questions.
#>
param([string]$Id, [switch]$NoPause)
$task = 'T10'
$Briefs = @('90161Z-T10-command-brief-r5.pptx', '90161Z-T10-installer-brief-r6.pptx', '90161Z-T10-adoption-brief-r2.pptx')
$SlackPt = 2            # points of rounding a text box may exceed its frame by before it counts as overflow

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

function Test-Brief($App, [string]$Path, $Lines) {
  # Returns $true when the brief opens with no overflow and nothing past the slide edge.
  $name = Split-Path -Leaf $Path
  $deck = $null
  try {
    try { $deck = $App.Presentations.Open($Path, -1, 0, 0) }   # ReadOnly, not Untitled, no window
    catch { $Lines.Add($name + ' FAIL cannot open (PowerPoint may want to repair it): ' + $_.Exception.Message); return $false }
    $w = [double]$deck.PageSetup.SlideWidth; $h = [double]$deck.PageSetup.SlideHeight
    $over = 0; $off = 0
    foreach ($slide in @($deck.Slides)) {
      foreach ($shape in @($slide.Shapes)) {
        $l = [double]$shape.Left; $t = [double]$shape.Top; $sw = [double]$shape.Width; $sh = [double]$shape.Height
        if ($l -lt -$SlackPt -or $t -lt -$SlackPt -or ($l + $sw) -gt ($w + $SlackPt) -or ($t + $sh) -gt ($h + $SlackPt)) {
          $off++; $Lines.Add('  slide ' + $slide.SlideIndex + ': "' + $shape.Name + '" reaches past the slide edge')
        }
        if ($shape.HasTextFrame -and $shape.TextFrame.HasText) {
          $r = $shape.TextFrame.TextRange
          if ([double]$r.BoundHeight -gt ($sh + $SlackPt) -or ([double]$r.BoundTop + [double]$r.BoundHeight) -gt ($h + $SlackPt)) {
            $over++; $Lines.Add('  slide ' + $slide.SlideIndex + ': text in "' + $shape.Name + '" is taller than its box')
          }
        }
      }
    }
    $ok = ($over -eq 0 -and $off -eq 0)
    $Lines.Add($name + ' ' + $(if ($ok) { 'PASS' } else { 'FAIL' }) + ' slides=' + $deck.Slides.Count + ' overflow=' + $over + ' past-edge=' + $off)
    return $ok
  } finally {
    if ($deck) { try { $deck.Close() } catch { $null = $_ } ; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($deck) }
  }
}

$secret = @()
$app = $null
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  $dir = Get-TaskDir $id $task 'Task 10' -Create
  Set-Location -LiteralPath $dir
  Assert-TaskFile $dir $Briefs 'MISSING in T10 (the round saves them; or save them from the bookmark page): '
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('TASK T10 brief check r2, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  Write-Host 'Opening PowerPoint (no window)...'
  $app = New-Object -ComObject PowerPoint.Application
  try { $app.DisplayAlerts = 1 } catch { $null = $_ }   # ppAlertsNone: no repair or save dialog can wait for a click
  $pass = 0
  foreach ($b in $Briefs) {
    Write-Host ($b + ' checking...')
    if (Test-Brief $app (Join-Path $dir $b) $lines) { $pass++ }
  }
  $lines.Add('BRIEFS total=' + $Briefs.Count + ' pass=' + $pass + ' fail=' + ($Briefs.Count - $pass))
  $masked = @($lines | ForEach-Object { ConvertTo-Masked $_ $secret })
  Set-Content -LiteralPath (Join-Path $dir '90161Z-T10-check-r1.txt') -Value $masked -Encoding UTF8
  $masked | ForEach-Object { Write-Host $_ }
  Write-Host ''
  Write-Host 'Saved: 90161Z-T10-check-r1.txt in the T10 folder. Open each brief in PowerPoint to judge the content.'
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
} finally {
  if ($app) { try { $app.Quit() } catch { $null = $_ } ; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) }
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
