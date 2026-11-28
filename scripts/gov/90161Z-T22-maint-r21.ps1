<#
.SYNOPSIS
  90-161.Z Task 22 r21, Maintenance (round R39; the PFM, 20 Nov 26): the test install of 90-161.Z 0.1, and the read-back
  of what RADE's Maintenance tools Diagnose and Back up made. Windows PowerShell 5.1 (also 7); no module.
.DESCRIPTION
  RADE shows its Maintenance screen (Diagnose, Back up) only for an app that a RADE deploy installed (RADE engine-v30,
  engine/ps/window/06-open.ps1). R39 therefore deploys 90-161.Z version 0.1.0 first.
  -Part Install: the one step of that deploy. It writes 90161Z-T22-install-r21.txt and passes; RADE keeps the install
  record (RADE\Config\installed). It installs nothing else and changes nothing on the site.
  -Part Read: reads, on this computer only, (1) the install record of 90-161.Z (version and last run state), (2) the
  newest Diagnose report (RADE\90-161.Z\Diagnose\diagnose-*.txt): its PASS, FINDING and NOTE counts and each FINDING
  line, masked, and (3) the newest Back up folder (RADE\90-161.Z\Backups\<time>): for each list, its JSON and CSV file
  and its row count. Never a row value: the backup files hold site data and stay in OneDrive (Project rule "Data
  boundary"); only counts and list titles go into the result.
  -Part Backup (round R41, the Restore test; the PFM, 21 Nov 26): reads only (3), the newest Back up folder, so the round
  knows that the Back up before the Restore test saved every list (12 from R41: the 12th is "PFM Recommendations (DAF Form
  847)", a title with parentheses that RADE engine-v31 can back up). It also needs a backup made after the T26 part
  Rows made the fake rows (RowsAt in T26\90161Z-T26-endorse-state-r4.txt): an older backup, or no Rows time, is a FAIL.
  Result lines: RESULT INSTALL, RESULT DIAGNOSE and RESULT BACKUP, each PASS or FAIL. Exit 1 when one is FAIL.
  A report or backup older than $FreshHours hours is from an earlier day and counts as missing.
  Run: by RADE (powershell.exe -File 90161Z-T22-maint-r21.ps1 -Part Install, Read or Backup -NoPause), or by hand in T22.
  Parameters: -Id (the DODID; the profile folder name when not given), -Part, -NoPause, -TestDir (the T22 folder of a
  test; its parent is the app folder and the parent of that the RADE folder).
  Network: none.
  Writes: Install: 90161Z-T22-install-r21.txt; Read: 90161Z-T22-maint-r21.txt; Backup: 90161Z-T22-backup-r21.txt, all in
          the T22 folder (or -TestDir).
  Credentials: none.
#>
param([string]$Id, [ValidateSet('Install', 'Read', 'Backup')][string]$Part = 'Read', [switch]$NoPause, [string]$TestDir)
$task = 'T22'
$Rev = 'r21'
$FreshHours = 6   # a Diagnose report or a backup older than this is not from this round
$BackupLists = 12   # the lists the R41 manifest names in "backup" (scripts/paste_bundles.json; tests/ps/Test-T22Maint.ps1 checks they match): fewer is a FAIL
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

<#
.SYNOPSIS
  The install record of 90-161.Z in RADE\Config\installed (schema rade-installed/2: key, installed, lastRun).
.PARAMETER Rade
  The RADE folder.
.OUTPUTS
  The record (a PSCustomObject) whose key is "90-161.Z/90-161.Z" (the app folder and the app name; RADE adds "@<hash>"
  only for an app with a site marker, which 90-161.Z has not), or $null.
#>
function Get-InstallRecord([string]$Rade) {
  $d = Join-Path (Join-Path $Rade 'Config') 'installed'
  if (-not (Test-Path -LiteralPath $d -PathType Container)) { return $null }
  foreach ($f in @(Get-ChildItem -LiteralPath $d -Filter '*.json' -File)) {
    try { $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json } catch { continue }   # a record of another app that is being written
    if ([string]$j.key -eq '90-161.Z/90-161.Z') { return $j } }
  return $null
}

<#
.SYNOPSIS
  The result lines of the newest Diagnose report: counts, each FINDING line (masked), and RESULT DIAGNOSE.
.PARAMETER App
  The app folder (RADE\90-161.Z).
.OUTPUTS
  The lines (strings).
#>
function Get-DiagnoseResult([string]$App) {
  $d = Join-Path $App 'Diagnose'
  $f = @(Get-ChildItem -LiteralPath $d -Filter 'diagnose-*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) | Select-Object -First 1
  if (-not $f -or $f.LastWriteTime -lt (Get-Date).AddHours(-$FreshHours)) { return @('DIAGNOSE no report from this round in the Diagnose folder', 'RESULT DIAGNOSE FAIL') }
  $text = @(Get-Content -LiteralPath $f.FullName)
  $n = @{}; foreach ($k in 'PASS', 'FINDING', 'NOTE') { $n[$k] = @($text | Where-Object { $_ -like ($k + ': *') }).Count }
  $out = @('DIAGNOSE report made ' + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ': pass=' + $n.PASS + ' findings=' + $n.FINDING + ' notes=' + $n.NOTE)
  $site = [string]$env:RADE_SITE   # the site RADE holds (no question here); empty outside RADE: the generic masks still apply
  foreach ($l in @($text | Where-Object { $_ -like 'FINDING: *' } | Select-Object -First 20)) { $out += ('DIAGNOSE ' + (Hide-Site ([string]$l) $site)) }
  return $out + @('RESULT DIAGNOSE PASS')   # the report exists: what it found is for the PFM to judge (the answers)
}

<#
.SYNOPSIS
  The result lines of the newest Back up folder: for each list, its files and row count, and RESULT BACKUP.
.PARAMETER App
  The app folder (RADE\90-161.Z).
.PARAMETER Since
  Only for -Part Backup: the newest folder must be made after this time (the T26 Rows time); $null = no such rule.
.OUTPUTS
  The lines (strings). PASS when the newest folder is from this round (and made after Since), has at least one list, and every JSON file has its
  CSV copy and can be read. The row values are never read into the result.
#>
function Get-BackupResult([string]$App, $Since = $null) {
  $root = Join-Path $App 'Backups'
  $all = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  $new = $all | Select-Object -First 1
  if (-not $new -or $new.LastWriteTime -lt (Get-Date).AddHours(-$FreshHours)) { return @('BACKUP no backup folder from this round (folders: ' + $all.Count + ')', 'RESULT BACKUP FAIL') }
  if ($null -ne $Since -and $new.CreationTime -le $Since) { return @('BACKUP the newest backup folder is older than the fake rows of the Restore test (run Back up again)', 'RESULT BACKUP FAIL') }
  $all2 = @(Get-ChildItem -LiteralPath $new.FullName -Filter '*.json' -File | Sort-Object Name)
  $json = @($all2 | Where-Object { -not $_.Name.StartsWith('~') })   # '~<n>.json': a file RADE could not give its list name
  $tilde = $all2.Count - $json.Count
  $out = @('BACKUP folders=' + $all.Count + '; the newest holds ' + $json.Count + ' lists'); $bad = $tilde
  if ($tilde) { $out += ('BACKUP ' + $tilde + ' list files without their list name (RADE did not finish naming them)') }
  foreach ($j in $json) {
    $name = [IO.Path]::GetFileNameWithoutExtension($j.Name); $csv = Test-Path -LiteralPath (Join-Path $new.FullName ($name + '.csv')) -PathType Leaf
    $rows = 'unreadable'   # RADE writes one JSON array of rows (engine-v30, 13-maintenance.ps1)
    try { $rows = [string](Get-JsonRowCount $j.FullName) } catch { $bad++ }
    if (-not $csv) { $bad++ }
    $out += ('BACKUP list "' + $name + '": rows=' + $rows + ' csv=' + $(if ($csv) { 'yes' } else { 'no' })) }
  if ($json.Count -lt $BackupLists) { $out += ('BACKUP ' + $json.Count + ' of ' + $BackupLists + ' lists saved') }
  return $out + @('RESULT BACKUP ' + $(if ($json.Count -ge $BackupLists -and -not $bad) { 'PASS' } else { 'FAIL' }))
}

# The time the T26 part Rows made the fake rows of the Restore test (RowsAt in the T26 state file), or $null. Takes the app folder.
function Get-RowsTime([string]$App) {
  $f = Join-Path (Join-Path $App 'T26') '90161Z-T26-endorse-state-r4.txt'
  $l = @(Get-Content -LiteralPath $f -ErrorAction SilentlyContinue | Where-Object { ([string]$_).StartsWith('RowsAt=') }) | Select-Object -First 1
  if (-not $l) { return $null }
  try { return [datetime]::ParseExact(([string]$l).Substring(7), 'yyyy-MM-ddTHH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) } catch { return $null }
}

<#
.SYNOPSIS
  The number of rows in one backup JSON file (one array of rows; RADE engine-v30). Reads no value into the result.
.DESCRIPTION
  Windows PowerShell 5.1 ConvertFrom-Json stops on a long text (its JSON length limit); then the .NET reader with no
  length limit counts it.
.PARAMETER Path
  The JSON file.
.OUTPUTS
  The row count.
#>
function Get-JsonRowCount([string]$Path) {
  $raw = [IO.File]::ReadAllText($Path)
  try { $v = $raw | ConvertFrom-Json; return @($v).Count } catch {   # a variable: 5.1 writes the array as one object
    Add-Type -AssemblyName System.Web.Extensions
    $s = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $s.MaxJsonLength = [int]::MaxValue
    return @($s.DeserializeObject($raw)).Count }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('TASK T22 maintenance ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$code = 0; $dir = ''; $who = $null
try {
  $ErrorActionPreference = 'Stop'
  if ($TestDir) { $dir = $TestDir } else { $who = Get-TaskId $Id; $dir = Get-TaskDir $who.Id $task 'Task 22' -Create }
  $app = Split-Path -Parent $dir; $rade = Split-Path -Parent $app
  if ($Part -eq 'Install') {
    $lines.Add('INSTALL the deploy of 90-161.Z 0.1.0 reached its step; RADE keeps the install record. Nothing else was installed; nothing on the site changed.')
    $lines.Add('RESULT INSTALL PASS') }
  elseif ($Part -eq 'Backup') {
    $since = Get-RowsTime $app
    if ($null -eq $since) { $lines.Add('BACKUP no time of the fake rows on file (run the step that makes the Restore test rows first)'); $lines.Add('RESULT BACKUP FAIL') }
    else { foreach ($l in @(Get-BackupResult $app $since)) { $lines.Add($l) } } }
  else {
    $rec = Get-InstallRecord $rade
    if ($rec -and $rec.installed) { $lines.Add('INSTALL record: version=' + [string]$rec.installed.version + ' last run=' + [string]$rec.lastRun.state); $lines.Add('RESULT INSTALL PASS') }
    else { $lines.Add('INSTALL no install record of 90-161.Z (run the deploy "90-161.Z" first)'); $lines.Add('RESULT INSTALL FAIL') }
    foreach ($l in @(Get-DiagnoseResult $app) + @(Get-BackupResult $app)) { $lines.Add($l) } }
  if (@($lines | Where-Object { $_ -match '^RESULT \S+ FAIL$' }).Count) { $code = 1 }
} catch {
  $code = 1; $lines.Add('STOPPED: ' + ([string]$_.Exception.Message))
} finally {
  $masked = @($lines | ForEach-Object { $t = [string]$_; if ($who) { $t = ConvertTo-Masked $t $who.Secret }; $t })
  $out = $(switch ($Part) { 'Install' { '90161Z-T22-install-' } 'Backup' { '90161Z-T22-backup-' } default { '90161Z-T22-maint-' } }) + $Rev + '.txt'
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir $out) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
exit $code
