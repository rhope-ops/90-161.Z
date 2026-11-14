<#
.SYNOPSIS
  90-161.Z Task 7 seal test runner, r3 (L-007, L-007a). Windows PowerShell 5.1.
.DESCRIPTION
  Uses this computer's profile folder as the DODID (no question), goes to the Task 7 folder
  C:\Users\<DODID>\OneDrive - United States Air Force\90-161.Z\T07, checks the 4 fake test seals in its
  TestSeals subfolder and the renderer scripts in the T01 folder, runs 90161Z-T07-seal-prep-r5.ps1 on the test
  seals, then renders the T01 sample twice (tall seal, round seal) as final .docx and PDF in the T07 folder.
  Saves the output to 90161Z-T07-test-result-r3.txt. The DODID, profile folder name and user name are replaced
  by <DODID> in all output.
  Parameters (used by the paste bundle, scripts/gov/paste): -Id skips the DODID question, -NoPause skips the final Enter.
#>
param([string]$Id, [switch]$NoPause)
$task = 'T07'
$need = @('90161Z-T07-seal-prep-r5.ps1', 'TestSeals\90161Z-T07-testseal-round-r1.png', 'TestSeals\90161Z-T07-testseal-tall-r1.png', 'TestSeals\90161Z-T07-testseal-soft-r1.png', 'TestSeals\90161Z-T07-testseal-tiny-r1.png')
$needT01 = @('Publication.Common.ps1', 'Test-Publication.ps1', 'New-Publication.ps1', 'publication.sample.json')   # Task 1 r5 files

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

try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret

  $dir = Get-TaskDir $id $task 'Task 7'
  $t01 = Join-Path (Split-Path -Parent $dir) 'T01'
  Assert-TaskFile $t01 $needT01 'MISSING in T01 folder (save the Task 1 files there first): '
  Set-Location -LiteralPath $dir
  Assert-TaskFile $dir $need ('MISSING in ' + $task + ' folder: ')
  Unblock-TaskScript $dir

  $log = Join-Path $dir '90161Z-T07-test-result-r3.txt'
  $testDir = Join-Path $dir 'TestSeals'
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('TASK ' + $task + ' seal test r5, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))

  # Step 1: seal prep on the fake test seals (no questions; it writes its own result file).
  Write-Host 'STEP 1 seal prep running...'
  $lines.Add('STEP 1 seal prep')
  $prepResult = '90161Z-T07-testprep-result-r1.txt'
  $ErrorActionPreference = 'Continue'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir '90161Z-T07-seal-prep-r5.ps1') -Id $id -SealDir $testDir -ResultName $prepResult -NoPause *> $null
  $ErrorActionPreference = 'Stop'
  $prepPath = Join-Path $dir $prepResult
  if (Test-Path -LiteralPath $prepPath) { foreach ($l in Get-Content -LiteralPath $prepPath) { $lines.Add($l) } } else { $lines.Add('STEP 1 seal prep wrote no result file') }

  # Steps 2-3: render the T01 sample with a prepared seal (tall, then round).
  $sampleJson = Get-Content -LiteralPath (Join-Path $t01 'publication.sample.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $steps = @()
  foreach ($kind in @('tall', 'round')) {
    $sealPng = Join-Path (Join-Path $testDir 'Prepared') ('90161Z-T07-testseal-' + $kind + '-r1.png')
    $sampleJson.meta.shieldImage = $sealPng
    $sampleJson.meta.designator = 'SAMPLEWINGI99-101-' + $kind.ToUpperInvariant()
    $jsonPath = Join-Path $dir ('90161Z-T07-sample-' + $kind + '-r1.json')
    $sampleJson | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $steps += @{ Name = ($(if ($kind -eq 'tall') { '2' } else { '3' }) + ' render ' + $kind + ' seal'); File = 'New-Publication.ps1'; Args = @('-Path', $jsonPath, '-Mode', 'final', '-Pdf', '-OutDir', $dir) }
  }
  foreach ($s in $steps) { Invoke-TaskStep $s $t01 $secret $lines $log }
  Write-Host ''
  Write-Host ('Saved: ' + (Split-Path -Leaf $log) + ' in the ' + $task + ' folder. Send it with the two PDFs.')
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
  Write-Host 'Result file is NOT complete. Report this STOPPED line.'
} finally {
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
