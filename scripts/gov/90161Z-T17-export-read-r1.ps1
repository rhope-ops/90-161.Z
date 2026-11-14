<#
.SYNOPSIS
  90-161.Z Task 17 export reader, r1 (R18, PFM 14 Nov 26). Read-only on the site and in Power Automate. Windows PowerShell 5.1, no modules.
.DESCRIPTION
  What it is for: the fallback when solution import test A r4 fails. The PFM exports one working solution from Power
  Automate (round step "T17 Export a working solution"); this script reads that export so the next build copies the real
  solution layout instead of guessing it. About 1 minute (an estimate).
  It looks for the newest file 90161ZExportSample*.zip in the T17 folder, then in Downloads (OneDrive Downloads too).
  From the zip it copies only solution.xml and customizations.xml (never the flow definitions, which can hold the site
  address) to T17 as 90161Z-T17-export-solution-r1.txt and 90161Z-T17-export-customizations-r1.txt (plain text files,
  because zips do not cross the boundary). In each copy every https address becomes <SITE>, every e-mail address
  becomes <EMAIL> and the DODID becomes <DODID>. It also lists the names of the files in the zip (names only).
  No zip found: one SKIP line (test A imported, or the export step was skipped). It changes nothing else.
  Output: the two copies above (the round collects them) and lines that start with PASS, SKIP or FAIL.
  Parameters (used by RADE): -Id, -NoPause.
#>
param([string]$Id, [switch]$NoPause)
$task = 'T17'
$ErrorActionPreference = 'Stop'

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

function Hide-Export([string]$Text, [string[]]$Secret) {
  $t = ConvertTo-Masked $Text $Secret
  $t = $t -replace 'https?://[^\s"''<>]+', '<SITE>'
  $t = $t -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '<EMAIL>'
  return $t
}

$code = 0
try {
  $who = Get-TaskId $Id
  $dir = Get-TaskDir $who.Id $task 'T17' -Create
  $places = @($dir)
  if ($env:USERPROFILE) { $places += (Join-Path $env:USERPROFILE 'Downloads') }
  $places += (Join-Path (Join-Path (Join-Path 'C:\Users' $who.Id) 'OneDrive - United States Air Force') 'Downloads')
  $zip = $null
  foreach ($pl in $places) {
    if (-not (Test-Path -LiteralPath $pl -PathType Container)) { continue }
    $f = Get-ChildItem -LiteralPath $pl -Filter '90161ZExportSample*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($f -and (-not $zip -or $f.LastWriteTime -gt $zip.LastWriteTime)) { $zip = $f }
  }
  if (-not $zip) {
    Write-Output 'ITEM export-read SKIP no 90161ZExportSample*.zip in T17 or Downloads (test A imported, or the export step was skipped)'
  } else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
    try {
      $names = @($z.Entries | ForEach-Object { $_.FullName })
      Write-Output ('ITEM export-files PASS zip=' + $zip.Name + ' entries=' + $names.Count)
      foreach ($n in $names) { Write-Output ('  file ' + (Hide-Export $n $who.Secret)) }
      foreach ($pair in @(@('solution.xml', '90161Z-T17-export-solution-r1.txt'), @('customizations.xml', '90161Z-T17-export-customizations-r1.txt'))) {
        $e = $z.Entries | Where-Object { $_.FullName -eq $pair[0] } | Select-Object -First 1
        if (-not $e) { Write-Output ('ITEM export-' + $pair[0] + ' FAIL not in the zip'); $code = 1; continue }
        $sr = New-Object System.IO.StreamReader($e.Open())
        try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
        Set-Content -LiteralPath (Join-Path $dir $pair[1]) -Value (Hide-Export $text $who.Secret) -Encoding UTF8
        Write-Output ('ITEM export-' + $pair[0] + ' PASS copied to T17\' + $pair[1] + ' (addresses masked)')
      }
    } finally { $z.Dispose() }
  }
} catch {
  $msg = [string]$_.Exception.Message; if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 160) }
  Write-Output ('ITEM export-read FAIL ' + (ConvertTo-Masked $msg @()))
  $code = 1
}
if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
exit $code
