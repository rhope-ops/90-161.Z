<#
.SYNOPSIS
  90-161.Z Task 17 import log reader, r2 (R20, PFM 14 Nov 26: r1 in R19 found an old log from an earlier round, so r2 reads only logs saved in the last 3 hours). Read-only. Windows PowerShell 5.1, no modules.
.DESCRIPTION
  What it is for: when a solution import fails, Power Automate offers "Download log file" (an Excel XML file). In R17 and
  R18 the error had to be pasted by hand and the paste held only the file's first lines. This script finds the newest
  import log and copies its error rows, so the next build sees the real error. About 1 minute (an estimate).
  It looks for the newest .xml file (changed in the last 3 hours) that is an Excel XML spreadsheet, in the T17 folder,
  Downloads, Desktop and Documents (local and OneDrive) and up to 2 folder levels below each (the browser saves where it
  saved last). From it, it writes T17\90161Z-T17-import-log-r2.txt (plain text): the column headings and every row that
  holds "fail", "error" or a 0x8 code, each cell joined with " | " (at most 80 rows). Every https address becomes <SITE>,
  every e-mail address <EMAIL> and the DODID <DODID>. No log found: one SKIP line (the import worked, or no log was
  downloaded). It changes nothing else.
  Output: the file above (the round collects it) and lines that start with PASS, SKIP or FAIL.
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
  $t = $t -replace '\b[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.(sharepoint|dynamics|crm|powerapps|appsplatform)[A-Za-z0-9.-]*', '<HOST>'   # bare host names
  return $t
}

function Test-ExcelXml([string]$Path) {
  # An Excel XML spreadsheet names its namespace in the first few KB.
  try {
    $sr = New-Object System.IO.StreamReader($Path)
    try { $buf = New-Object char[] 4096; $n = $sr.Read($buf, 0, 4096); $head = New-Object string($buf, 0, $n) } finally { $sr.Dispose() }
    return ($head -match 'urn:schemas-microsoft-com:office:spreadsheet')
  } catch { return $false }
}

$code = 0
try {
  $who = Get-TaskId $Id
  $dir = Get-TaskDir $who.Id $task 'T17' -Create
  $places = @($dir)
  $homes = @()
  if ($env:USERPROFILE) { $homes += $env:USERPROFILE }
  $homes += (Join-Path (Join-Path 'C:\Users' $who.Id) 'OneDrive - United States Air Force')
  if ($env:OneDrive) { $homes += $env:OneDrive }
  foreach ($hm in ($homes | Select-Object -Unique)) { foreach ($sub in @('Downloads', 'Desktop', 'Documents')) { $places += (Join-Path $hm $sub) } }
  $since = (Get-Date).AddHours(-3)   # r2: this round only (R19 found an old log)
  $log = $null
  foreach ($pl in ($places | Select-Object -Unique)) {   # the newest log wins, wherever it is (each folder and 2 levels below it)
    if (-not (Test-Path -LiteralPath $pl -PathType Container)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $pl -Filter '*.xml' -File -Recurse -Depth 2 -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $since } | Sort-Object LastWriteTime -Descending)) {
      if ($log -and $f.LastWriteTime -le $log.LastWriteTime) { break }
      if (Test-ExcelXml $f.FullName) { $log = $f; break }
    }
  }
  if (-not $log) {
    Write-Output 'ITEM import-log SKIP no Excel XML import log from the last 3 hours in T17, Downloads, Desktop or Documents (the import worked, or no log was downloaded)'
  } else {
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    $doc.Load($log.FullName)
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('IMPORT LOG ' + (Hide-Export $log.Name $who.Secret) + ', saved ' + $log.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
    $kept = 0; $rows = 0; $full = $false
    foreach ($ws in @($doc.SelectNodes("//*[local-name()='Worksheet']"))) {
      $wsName = ''; foreach ($a in $ws.Attributes) { if ($a.LocalName -eq 'Name') { $wsName = $a.Value } }
      $out.Add('SHEET ' + (Hide-Export $wsName $who.Secret))
      if ($full) { break }   # at most 80 rows in all
      $first = $true
      foreach ($row in @($ws.SelectNodes(".//*[local-name()='Row']"))) {
        $rows++
        $cells = @($row.SelectNodes("./*[local-name()='Cell']") | ForEach-Object { ([string]$_.InnerText).Trim() -replace '\s+', ' ' })
        $text = ($cells -join ' | ')
        if ($first -or $text -match '(?i)fail|error|0x8') {
          if ($kept -ge 80) { $full = $true; break }
          if ($text.Length -gt 600) { $text = $text.Substring(0, 600) + ' ...' }
          $out.Add((Hide-Export $text $who.Secret)); $kept++
        }
        $first = $false
      }
    }
    $file = Join-Path $dir '90161Z-T17-import-log-r2.txt'
    Set-Content -LiteralPath $file -Value $out -Encoding UTF8
    Write-Output ('ITEM import-log PASS rows=' + $rows + ' kept=' + $kept + ' copied to T17\90161Z-T17-import-log-r2.txt (addresses masked)')
  }
} catch {
  $sec = @(); if ($who -and $who.Secret) { $sec = $who.Secret }
  $msg = Hide-Export ([string]$_.Exception.Message) $sec; if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 160) }   # mask first, then cut
  Write-Output ('ITEM import-log FAIL ' + $msg)
  $code = 1
}
if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
exit $code
