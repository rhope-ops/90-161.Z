# Tests scripts/gov/90161Z-T22-maint-r21.ps1 (round R39; the PFM, 20 Nov 26): the test install step and the read-back of
# RADE's Diagnose report and Back up folder, on fake folders (FAKE data, no site). Also checks that the script's list
# count ($BackupLists) equals the "backup" titles of the deploy app in scripts/paste_bundles.json (one home).
# Network: none.
# Writes: one temporary folder per case; removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Last line: "T22MAINT pass=N fail=0" (tests/ps/Invoke-Ps51.ps1;
# tests/run.sh runs it with the masking test).
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
$script = Join-Path $Root 'scripts/gov/90161Z-T22-maint-r21.ps1'
# Record one result. Takes the name, the condition and the output; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Out) {
  if ($Ok) { $script:pass++; Write-Host ('T22MAINT PASS ' + $Name) } else { $script:fail++; Write-Host ('T22MAINT FAIL ' + $Name + ': ' + $Out) }
}
<#
.SYNOPSIS
Makes a fake RADE folder in a new temporary folder (FAKE data only).
.PARAMETER Record
With an install record of 90-161.Z 0.1.0.
.PARAMETER Report
With a Diagnose report (1 PASS, 1 FINDING with a fake URL and a fake site host, 1 NOTE).
.PARAMETER Csv
With the CSV copy beside the JSON file of PFM Waivers (the other fake lists always have theirs).
.PARAMETER Lists
How many lists the backup holds (PFM Waivers with 2 rows, then empty fake lists).
.PARAMETER Tilde
With one list file that RADE did not give its list name (~1.json and ~1.csv).
.PARAMETER BigRows
When above 0, PFM Waivers holds this many rows (a large file, for the JSON reader of Windows PowerShell 5.1).
.OUTPUTS
The T22 folder of the fake app folder.
#>
function Get-FakeRade([bool]$Record, [bool]$Report, [bool]$Csv, [int]$Lists = 12, [bool]$Tilde = $false, [int]$BigRows = 0) {
  $t = Join-Path ([IO.Path]::GetTempPath()) ('t22m-' + [guid]::NewGuid().ToString('N')); $app = Join-Path (Join-Path $t 'RADE') '90-161.Z'
  $null = New-Item -ItemType Directory -Path (Join-Path $app 'T22') -Force
  if ($Record) { $c = Join-Path (Join-Path (Join-Path $t 'RADE') 'Config') 'installed'; $null = New-Item -ItemType Directory -Path $c -Force
    $rec = '{"schema":"rade-installed/2","key":"90-161.Z/90-161.Z","installed":{"version":"0.1.0"},"lastRun":{"state":"PASSED"},"steps":{}}'
    Set-Content -LiteralPath (Join-Path $c 'abc.json') -Value $rec }
  if ($Report) { $d = Join-Path $app 'Diagnose'; $null = New-Item -ItemType Directory -Path $d -Force
    $txt = @('Diagnose of 90-161.Z 0.1.0', '2 finding(s).', 'PASS: a', 'FINDING: b at https://fake.example.com/sites/fake. What to do: c', 'FINDING: e on fakesite.example.org', 'NOTE: d')
    Set-Content -LiteralPath (Join-Path $d 'diagnose-1.txt') -Value $txt }
  $b = Join-Path (Join-Path $app 'Backups') 'b1'; $null = New-Item -ItemType Directory -Path $b -Force
  $w = '[{"Title":"FAKE 1"},{"Title":"FAKE 2"}]'
  if ($BigRows -gt 0) { $w = '[' + ((1..$BigRows | ForEach-Object { '{"Title":"FAKE row ' + $_ + ' with some longer text to make the file large"}' }) -join ',') + ']' }
  [IO.File]::WriteAllText((Join-Path $b 'PFM Waivers.json'), $w)
  # R41: the 12th list has parentheses in its title (RADE engine-v31 backs it up by that name).
  $rec = Join-Path $b 'PFM Recommendations (DAF Form 847)'
  if ($Lists -ge 2) { Set-Content -LiteralPath ($rec + '.json') -Value '[]'; Set-Content -LiteralPath ($rec + '.csv') -Value '' }
  for ($i = 3; $i -le $Lists; $i++) {
    Set-Content -LiteralPath (Join-Path $b ('FAKE List ' + $i + '.json')) -Value '[]'; Set-Content -LiteralPath (Join-Path $b ('FAKE List ' + $i + '.csv')) -Value '' }
  if ($Tilde) { Set-Content -LiteralPath (Join-Path $b '~1.json') -Value '[]'; Set-Content -LiteralPath (Join-Path $b '~1.csv') -Value '' }
  if ($Csv) { Set-Content -LiteralPath (Join-Path $b 'PFM Waivers.csv') -Value '"Title"' }
  return (Join-Path $app 'T22')
}
# Run the script. Takes the T22 folder, the part and the site RADE holds (or ''); returns @{ Out; Code }.
function Invoke-Maint([string]$Dir, [string]$Part, [string]$Site = '') {
  $exe = (Get-Process -Id $PID).Path; $old = $env:RADE_SITE; $env:RADE_SITE = $Site
  try { $o = & $exe -NoProfile -File $script -Part $Part -NoPause -TestDir $Dir 2>&1 } finally { $env:RADE_SITE = $old }
  return @{ Out = (@($o) -join "`n"); Code = $LASTEXITCODE }
}
$dirs = @()
$d = Get-FakeRade $true $true $true; $dirs += $d; $r = Invoke-Maint $d 'Read' 'https://fakesite.example.org/sites/fakepfm'
Test-That 'all there: 3 PASS, exit 0' ($r.Code -eq 0 -and $r.Out -match 'RESULT INSTALL PASS' -and $r.Out -match 'RESULT DIAGNOSE PASS' -and $r.Out -match 'RESULT BACKUP PASS') $r.Out
Test-That 'counts only: the rows, never a value' ($r.Out -match 'BACKUP list "PFM Waivers": rows=2 csv=yes' -and $r.Out -notmatch 'FAKE 1') $r.Out
$ok = ($r.Out -match 'pass=1 findings=2 notes=1' -and $r.Out -match 'FINDING: b at <URL>' -and $r.Out -notmatch 'example\.')
Test-That 'a Diagnose finding is masked (a URL, and the site host RADE holds)' $ok $r.Out
Test-That 'the result file is written' (Test-Path -LiteralPath (Join-Path $d '90161Z-T22-maint-r21.txt')) $r.Out
$d = Get-FakeRade $false $false $false; $dirs += $d; $r = Invoke-Maint $d 'Read'
$ok = ($r.Code -eq 1 -and $r.Out -match 'RESULT INSTALL FAIL' -and $r.Out -match 'RESULT DIAGNOSE FAIL' -and $r.Out -match 'csv=no' -and $r.Out -match 'RESULT BACKUP FAIL')
Test-That 'nothing there: 3 FAIL (a backup without its csv fails), exit 1' $ok $r.Out
$r = Invoke-Maint $d 'Install'
Test-That 'install step passes and writes its file' ($r.Code -eq 0 -and $r.Out -match 'RESULT INSTALL PASS' -and (Test-Path -LiteralPath (Join-Path $d '90161Z-T22-install-r21.txt'))) $r.Out
$d = Get-FakeRade $true $true $true 3; $dirs += $d; $r = Invoke-Maint $d 'Read'
Test-That 'fewer lists than the manifest names: FAIL' ($r.Code -eq 1 -and $r.Out -match 'BACKUP 3 of 12 lists saved' -and $r.Out -match 'RESULT BACKUP FAIL') $r.Out
$d = Get-FakeRade $true $true $true 12 $true; $dirs += $d; $r = Invoke-Maint $d 'Read'
Test-That 'a list file RADE did not name: FAIL' ($r.Code -eq 1 -and $r.Out -match 'BACKUP 1 list files without their list name' -and $r.Out -match 'RESULT BACKUP FAIL') $r.Out
$d = Get-FakeRade $true $true $true 12 $false 40000; $dirs += $d; $r = Invoke-Maint $d 'Read'
Test-That 'a large list file (about 3 MB) is counted' ($r.Out -match 'BACKUP list "PFM Waivers": rows=40000 csv=yes' -and $r.Out -match 'RESULT BACKUP PASS') $r.Out
# R41: -Part Backup reads only the newest backup folder (no install record, no Diagnose report needed), made after the
# T26 Rows time in the T26 state file. Set-RowsTime writes that file. Takes the T22 folder and the time; returns nothing.
function Set-RowsTime([string]$Dir, [datetime]$At) {
  $t = Join-Path (Split-Path -Parent $Dir) 'T26'; $null = New-Item -ItemType Directory -Path $t -Force
  Set-Content -LiteralPath (Join-Path $t '90161Z-T26-endorse-state-r4.txt') -Value @('PubId=50', ('RowsAt=' + $At.ToString('yyyy-MM-ddTHH:mm:ss')))
}
$d = Get-FakeRade $false $false $true; $dirs += $d; $r = Invoke-Maint $d 'Backup'
$ok = ($r.Code -eq 1 -and $r.Out -match 'BACKUP no time of the fake rows on file' -and $r.Out -match 'RESULT BACKUP FAIL')
Test-That 'Backup part with no Rows time on file: FAIL, exit 1' $ok $r.Out
Set-RowsTime $d (Get-Date).AddHours(1); $r = Invoke-Maint $d 'Backup'
$ok = ($r.Code -eq 1 -and $r.Out -match 'older than the fake rows' -and $r.Out -match 'RESULT BACKUP FAIL')
Test-That 'Backup part with a backup older than the Rows time: FAIL, exit 1' $ok $r.Out
Set-RowsTime $d (Get-Date).AddHours(-1); $r = Invoke-Maint $d 'Backup'
$ok = ($r.Code -eq 0 -and $r.Out -match 'RESULT BACKUP PASS' -and $r.Out -notmatch 'RESULT (INSTALL|DIAGNOSE)' -and $r.Out -match 'BACKUP list "PFM Recommendations \(DAF Form 847\)": rows=0 csv=yes')
Test-That 'Backup part: only RESULT BACKUP, the list with parentheses is named' ($ok -and (Test-Path -LiteralPath (Join-Path $d '90161Z-T22-backup-r21.txt'))) $r.Out
$d = Get-FakeRade $false $false $true 11; $dirs += $d; Set-RowsTime $d (Get-Date).AddHours(-1); $r = Invoke-Maint $d 'Backup'
Test-That 'Backup part with 11 of 12 lists: FAIL, exit 1' ($r.Code -eq 1 -and $r.Out -match 'BACKUP 11 of 12 lists saved' -and $r.Out -match 'RESULT BACKUP FAIL') $r.Out
# One home: the script's count equals the "backup" titles of the deploy app in the round definition.
$m = [regex]::Match((Get-Content -LiteralPath $script -Raw), '(?m)^\$BackupLists = (\d+)')
$man = Get-Content -LiteralPath (Join-Path $Root 'scripts/paste_bundles.json') -Raw | ConvertFrom-Json
$want = @(@($man.bundles | ForEach-Object { $_.apps } | Where-Object { $_.mode -eq 'deploy' }) | ForEach-Object { @($_.backup).Count })
$ok = ($m.Success -and $want.Count -eq 1 -and [int]$m.Groups[1].Value -eq $want[0])
Test-That 'the script count equals the manifest backup titles' $ok ('script ' + $m.Groups[1].Value + ', manifest ' + ($want -join ','))
foreach ($x in $dirs) { Remove-Item -LiteralPath (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $x))) -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host ('T22MAINT pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
