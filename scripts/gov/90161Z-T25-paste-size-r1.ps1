<#
.SYNOPSIS
  90-161.Z Task 25 paste-size test, r1 (R33; the PFM, 18 Nov 26: "No limit; test 1 MB too"). Read-only. Windows PowerShell 5.1, no modules.
.DESCRIPTION
  What it is for: the round bundle had a size limit of 600 KB that no test had set. Round R33 is one paste of at least
  1,048,576 bytes: the RADE engine, this script and one padding file. When this script runs, the paste worked: the text
  reached PowerShell ISE whole, RADE started and saved the files. This script then checks that the padding file is whole.
  About 1 minute (an estimate).
  It reads T25\90161Z-T25-padding-r1.txt (6,000 numbered lines of fixed text and 1 end line; no data) and writes
  T25\90161Z-T25-paste-size-r1.txt (plain text): the number of lines, the first and the last line number and the end
  line. It changes nothing else, signs in nowhere and uses no network.
  The padding file: samples/90161Z-T25-padding-r1.txt in the repo; line N is
  "FAKE padding line <N, 6 digits> for the 90-161.Z paste-size test: no data, only letters to make the paste larger. .........."
  and the last line is "END OF PADDING lines=6000".
  Output: the file above (the round collects it) and lines that start with ITEM, then PASS or FAIL.
  Network: none.
  Writes: 90161Z-T25-paste-size-r1.txt in the T25 folder.
  Credentials: none.
  Parameters (used by RADE): -Id, -NoPause.
#>
param([string]$Id, [switch]$NoPause)
$task = 'T25'
$ErrorActionPreference = 'Stop'
$PaddingName = '90161Z-T25-padding-r1.txt'      # the padding file the round saves beside this script
$ResultName = '90161Z-T25-paste-size-r1.txt'    # the result file the round collects
$PaddingLines = 6000                            # numbered lines in the padding file (the end line is 1 more)

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

function Test-Padding([string]$Path) {
  <#
  .SYNOPSIS
  Checks that the padding file is whole: every numbered line is there, in order, and the end line is last.
  .PARAMETER Path
  The full path of the padding file.
  .OUTPUTS
  A table: Ok (true when whole), Lines (lines read), Why (the first fault in plain words, or '').
  #>
  $all = @([System.IO.File]::ReadAllLines($Path) | Where-Object { $_ -ne '' })
  $why = ''
  if ($all.Count -ne ($PaddingLines + 1)) { $why = 'lines=' + $all.Count + ', expected ' + ($PaddingLines + 1) }
  elseif ($all[$all.Count - 1] -ne ('END OF PADDING lines=' + $PaddingLines)) { $why = 'the end line is missing' }
  else {
    for ($i = 0; $i -lt $PaddingLines; $i++) {
      if (-not $all[$i].StartsWith('FAKE padding line ' + ($i + 1).ToString('000000') + ' ')) { $why = 'line ' + ($i + 1) + ' is not the expected line'; break }
    }
  }
  return @{ Ok = (-not $why); Lines = $all.Count; Why = $why }
}

$code = 0
try {
  $who = Get-TaskId $Id
  $dir = Get-TaskDir $who.Id $task 'T25' -Create
  Assert-TaskFile $dir @($PaddingName) 'FILE missing in T25: '
  $path = Join-Path $dir $PaddingName
  $bytes = (Get-Item -LiteralPath $path).Length
  $test = Test-Padding $path
  $out = @('TASK T25 paste-size test r1, ' + (Get-Date).ToString('yyyy-MM-dd HH:mm'),
    ('PADDING lines=' + $test.Lines + ' bytes=' + $bytes),
    $(if ($test.Ok) { 'RESULT PASTE PASS: the padding file is whole, so a paste of this size works' } else { 'RESULT PASTE FAIL: ' + $test.Why }))
  Set-Content -LiteralPath (Join-Path $dir $ResultName) -Value $out -Encoding UTF8
  if ($test.Ok) { Write-Output ('ITEM paste-size PASS lines=' + $test.Lines + ' bytes=' + $bytes) }
  else { Write-Output ('ITEM paste-size FAIL ' + $test.Why); $code = 1 }
} catch {
  $sec = @(); if ($who -and $who.Secret) { $sec = $who.Secret }
  $msg = ConvertTo-Masked ([string]$_.Exception.Message) $sec; if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 160) }   # mask first, then cut
  Write-Output ('ITEM paste-size FAIL ' + $msg)
  $code = 1
}
if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
exit $code
