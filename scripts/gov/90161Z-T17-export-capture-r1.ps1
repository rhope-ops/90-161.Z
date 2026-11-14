<#
.SYNOPSIS
  90-161.Z Task 17 solution export capture, r1 (R16). Read-only. Windows PowerShell 5.1, no modules.
.DESCRIPTION
  What it is for: R15's solution import stopped with an XML error, because the test solution's layout was written from
  memory (PFM 14 Nov 26: copy a real export). This reads the small solution the PFM exported by hand in the step before,
  so the next test solution can match a real export from this environment exactly. About 1 minute (an estimate).
  It changes nothing. It reads the newest "90161ZExportSample*.zip" from the last 4 hours in the Downloads folder or the
  T17 folder, and writes one plain text file with every text file in the zip (XML and JSON), masked:
  e-mail addresses, web addresses (except the public schema addresses the format itself uses), /sites/ paths, the
  publisher's names, e-mail, website and postal fields, every environment variable value, and the DODID. Other files are
  listed by name and size only. It also records whether each file starts with a byte-order mark (R15's error can come
  from one) and how the file names in the zip are written.
  Output: 90161Z-T17-export-capture-r1.txt in the T17 folder (send this). The zip itself stays on this computer.
  Parameters (used by the 90-161.Z Deployer): -Id, -NoPause, -Zip (a path, to read another file).
#>
param([string]$Id, [switch]$NoPause, [string]$Zip)
$task = 'T17'
$Pattern = '90161ZExportSample*.zip'
$MaxAgeHours = 4
# Public schema hosts the solution format itself uses; every other web address is masked.
$KeepHosts = @('www.w3.org', 'schema.management.azure.com', 'schemas.microsoft.com', 'schemas.openxmlformats.org', 'json-schema.org')

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
  # The task folder C:\Users\<DODID>\OneDrive - United States Air Force\90-161.Z\<Task>. -Create makes it when missing.
  $tail = 'OneDrive - United States Air Force\90-161.Z\' + $Task
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

function Hide-Export([string]$Text, [string]$Name) {
  # Returns @{ Text; Count }: the masked text and how many values were replaced. $Name is the file's path in the zip.
  $script:hidden = 0
  $sub = { param([string]$T, [string]$Pattern, [string]$With) $script:hidden += [regex]::Matches($T, $Pattern).Count; [regex]::Replace($T, $Pattern, $With) }
  $Text = & $sub $Text '[\w.+-]+@[\w-]+(\.[\w-]+)+' '<EMAIL>'
  $Text = & $sub $Text '[\w.+-]+%40[\w-]+(\.[\w-]+)+' '<EMAIL>'
  $Text = & $sub $Text '(?i)/sites/[^\s"''<>/\\?&]+' '/sites/<SITE-NAME>'
  # The publisher block (solution.xml): its names, descriptions, e-mail, website and every postal or phone field.
  $Text = [regex]::Replace($Text, '(?is)<Publisher>.*?</Publisher>', {
    param($m)
    $p = $m.Value
    $p = & $sub $p '(?i)(<UniqueName>)[^<]+(</UniqueName>)' '$1<PUBLISHER-UNIQUE-NAME>$2'
    $p = & $sub $p '(?i)(\bdescription=")[^"]+' '$1<MASKED>'
    $p = & $sub $p '(?i)(<(EMailAddress|SupportingWebsiteUrl|Name|Line1|Line2|Line3|City|County|Country|StateOrProvince|PostalCode|PostOfficeBox|Telephone1|Telephone2|Telephone3|Fax|UPSZone|Latitude|Longitude)>)[^<]+(</\2>)' '$1<MASKED>$3'
    return $p
  })
  # Environment variable values: every value in a value file, and any default value.
  if ($Name -match '(?i)environmentvariablevalue') {
    $Text = & $sub $Text '(?i)("value"\s*:\s*")[^"]*' '$1<VALUE>'
    $Text = & $sub $Text '(?i)(<value>)[^<]+(</value>)' '$1<VALUE>$2'
  }
  $Text = & $sub $Text '(?i)(<defaultvalue>)[^<]+(</defaultvalue>)' '$1<VALUE>$2'
  # Web addresses: keep the public schema hosts, mask the rest.
  $Text = [regex]::Replace($Text, '(?i)https?://[^\s"''<>\\]+', {
    param($m)
    $h = ''; try { $h = ([uri]$m.Value).Host.ToLowerInvariant() } catch { $h = '' }
    if ($KeepHosts -contains $h) { return $m.Value }
    $script:hidden++; return '<URL>'
  })
  return @{ Text = $Text; Count = $script:hidden }
}

function Find-ExportZip([string]$TaskDir) {
  $since = (Get-Date).AddHours(-$MaxAgeHours)
  $where = @()
  if ($env:USERPROFILE) { $where += (Join-Path $env:USERPROFILE 'Downloads') }
  $where += $TaskDir
  $hits = @()
  foreach ($w in $where) {
    if (Test-Path -LiteralPath $w -PathType Container) {
      $hits += @(Get-ChildItem -LiteralPath $w -File -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $since })
    }
  }
  return @($hits | Sort-Object LastWriteTime -Descending)[0]
}

$secret = @()
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $secret = $who.Secret
  $dir = Get-TaskDir $who.Id $task 'Task 17' -Create
  Set-Location -LiteralPath $dir
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('TASK T17 solution export capture r1, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $z = $(if ($Zip) { Get-Item -LiteralPath $Zip } else { Find-ExportZip $dir })
  if (-not $z) {
    throw ('NO EXPORT: no ' + $Pattern + ' from the last ' + $MaxAgeHours + ' hours in Downloads or the T17 folder. What to do: export the solution again (step before), or save the zip into the T17 folder, then run this round again.')
  }
  $lines.Add('ZIP ' + $z.Name + ' bytes=' + $z.Length + ' saved=' + $z.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($z.FullName)
  $masked = 0; $text = 0; $other = 0
  $body = New-Object System.Collections.Generic.List[string]
  try {
    $entries = @($archive.Entries | Where-Object { $_.FullName -notmatch '/$' })
    $lines.Add('ENTRIES ' + $entries.Count + ' names-with-backslash=' + @($entries | Where-Object { $_.FullName -like '*\*' }).Count)
    foreach ($e in $entries) {
      $ext = [IO.Path]::GetExtension($e.Name).ToLowerInvariant()
      $lines.Add('ENTRY ' + $e.FullName + ' bytes=' + $e.Length + ' compressed=' + $e.CompressedLength)
      if (@('.xml', '.json', '.txt', '.yaml', '.yml', '.html', '.csv') -notcontains $ext) { $other++; continue }
      $s = $e.Open(); $ms = New-Object System.IO.MemoryStream
      try { $s.CopyTo($ms) } finally { $s.Dispose() }
      $bytes = $ms.ToArray()
      $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
      $t = (New-Object System.Text.UTF8Encoding $false).GetString($bytes)
      if ($bom) { $t = $t.Substring(1) }
      $h = Hide-Export $t $e.FullName
      $masked += $h.Count; $text++
      $body.Add('')
      $body.Add('==== FILE ' + $e.FullName + ' bytes=' + $bytes.Length + ' bom=' + $(if ($bom) { 'yes' } else { 'no' }) + ' line-ends=' + $(if ($t -match "`r`n") { 'CRLF' } elseif ($t -match "`n") { 'LF' } else { 'none' }) + ' ====')
      $body.Add((ConvertTo-Masked $h.Text $secret))
    }
  } finally { $archive.Dispose() }
  $left = @(@($body) | Where-Object { $_ -match '[\w.+-]+@[\w-]+\.[\w-]+' }).Count
  $lines.Add('CAPTURE ' + $(if ($left -eq 0) { 'PASS' } else { 'FAIL' }) + ' text-files=' + $text + ' other-files=' + $other + ' values-masked=' + $masked + ' lines-with-an-address-left=' + $left)
  $out = @($lines | ForEach-Object { ConvertTo-Masked $_ $secret }) + @($body)
  [System.IO.File]::WriteAllText((Join-Path $dir '90161Z-T17-export-capture-r1.txt'), (($out -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding $false))
  $lines | ForEach-Object { Write-Host (ConvertTo-Masked $_ $secret) }
  Write-Host ''
  Write-Host 'Saved: 90161Z-T17-export-capture-r1.txt in the T17 folder. Nothing was changed. The zip stays on this computer.'
  if ($left -gt 0) { Write-Host 'What to do: a line still holds an address. Do not send the file; send this window''s CAPTURE line instead.'; exit 1 }
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
  exit 1
} finally {
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
