<#
.SYNOPSIS
  90-161.Z Task 6 runner, r2: GenAI.mil extraction test (docs/gov-test-plan.md, Task 6). Windows PowerShell 5.1.
.DESCRIPTION
  Uses this computer's profile folder as the DODID (no question), goes to the Task 6 folder
  C:\Users\<DODID>\OneDrive - United States Air Force\90-161.Z\T06, checks that 90161Z-T06-extracted-r1.json
  is there and that the Task 1 folder (T01) holds the renderer scripts, runs the validator and the final
  render with PDF on the extracted JSON, and saves the output to 90161Z-T06-result-r2.txt in the T06 folder.
  The renderer writes the .docx and .pdf into the T06 folder. The DODID, profile folder name and user name
  are replaced by <DODID> in all output. Start it with right-click > Run with PowerShell (no -File path typed).
  The window always waits for Enter before it closes, also after an unexpected error.
#>
$task = 'T06'
$need = @('90161Z-T06-extracted-r1.json')
$needT01 = @('Publication.Common.ps1', 'Test-Publication.ps1', 'New-Publication.ps1')   # Task 1 r5 files

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
  $who = Get-TaskId ""
  $id = $who.Id
  $secret = $who.Secret

  $dir = Get-TaskDir $id $task 'Task 6'
  $t01 = Join-Path (Split-Path -Parent $dir) 'T01'
  Assert-TaskFile $t01 $needT01 'MISSING in T01 folder (do Task 1 r5 first): '
  Set-Location -LiteralPath $dir
  Assert-TaskFile $dir $need ('MISSING in ' + $task + ' folder: ')
  Unblock-TaskScript $dir

  $log = Join-Path $dir ('90161Z-' + $task + '-result-r2.txt')
  $sample = Join-Path $dir '90161Z-T06-extracted-r1.json'
  $steps = @(
    @{ Name = '1 validate'; File = 'Test-Publication.ps1'; Args = @('-Path', $sample) },
    @{ Name = '2 final'; File = 'New-Publication.ps1'; Args = @('-Path', $sample, '-Mode', 'final', '-Pdf', '-OutDir', $dir) }
  )
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('TASK ' + $task + ' extraction test r2, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  foreach ($s in $steps) { Invoke-TaskStep $s $t01 $secret $lines $log }
  Write-Host ''
  Write-Host ('Saved: ' + (Split-Path -Leaf $log) + ' in the ' + $task + ' folder. Report the RENDER, VALIDATE and exit lines.')
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
  Write-Host 'Result file is NOT complete. Report this STOPPED line.'
} finally {
  [void](Read-Host 'Press Enter to close')
}
