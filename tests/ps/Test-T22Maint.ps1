# Tests scripts/gov/90161Z-T22-maint-r12.ps1 (round R39; the PFM, 20 Nov 26): the test install step and the read-back of
# RADE's Diagnose report and Back up folder, on fake folders (FAKE data, no site).
# Network: none.
# Writes: one temporary folder per case; removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Last line: "T22MAINT pass=N fail=0" (tests/ps/Invoke-Ps51.ps1).
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
$script = Join-Path $Root 'scripts/gov/90161Z-T22-maint-r12.ps1'
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
With a Diagnose report (1 PASS, 1 FINDING with a fake URL, 1 NOTE).
.PARAMETER Csv
With the CSV copy beside the backup's JSON file.
.OUTPUTS
The T22 folder of the fake app folder.
#>
function New-Fake([bool]$Record, [bool]$Report, [bool]$Csv) {
  $t = Join-Path ([IO.Path]::GetTempPath()) ('t22m-' + [guid]::NewGuid().ToString('N')); $app = Join-Path (Join-Path $t 'RADE') '90-161.Z'
  $null = New-Item -ItemType Directory -Path (Join-Path $app 'T22') -Force
  if ($Record) { $c = Join-Path (Join-Path (Join-Path $t 'RADE') 'Config') 'installed'; $null = New-Item -ItemType Directory -Path $c -Force
    $rec = '{"schema":"rade-installed/2","key":"90-161.Z/90-161.Z","installed":{"version":"0.1.0"},"lastRun":{"state":"PASSED"},"steps":{}}'
    Set-Content -LiteralPath (Join-Path $c 'abc.json') -Value $rec }
  if ($Report) { $d = Join-Path $app 'Diagnose'; $null = New-Item -ItemType Directory -Path $d -Force
    Set-Content -LiteralPath (Join-Path $d 'diagnose-1.txt') -Value @('Diagnose of 90-161.Z 0.1.0', '1 finding(s).', 'PASS: a', 'FINDING: b at https://fake.example.com/sites/fake. What to do: c', 'NOTE: d') }
  $b = Join-Path (Join-Path $app 'Backups') 'b1'; $null = New-Item -ItemType Directory -Path $b -Force
  Set-Content -LiteralPath (Join-Path $b 'PFM Waivers.json') -Value '[{"Title":"FAKE 1"},{"Title":"FAKE 2"}]'
  if ($Csv) { Set-Content -LiteralPath (Join-Path $b 'PFM Waivers.csv') -Value '"Title"' }
  return (Join-Path $app 'T22')
}
# Run the script. Takes the T22 folder and the part; returns @{ Out; Code }.
function Invoke-Maint([string]$Dir, [string]$Part) {
  $exe = (Get-Process -Id $PID).Path
  $o = & $exe -NoProfile -File $script -Part $Part -NoPause -TestDir $Dir 2>&1; return @{ Out = (@($o) -join "`n"); Code = $LASTEXITCODE }
}
$dirs = @()
$d = New-Fake $true $true $true; $dirs += $d; $r = Invoke-Maint $d 'Read'
Test-That 'all there: 3 PASS, exit 0' ($r.Code -eq 0 -and $r.Out -match 'RESULT INSTALL PASS' -and $r.Out -match 'RESULT DIAGNOSE PASS' -and $r.Out -match 'RESULT BACKUP PASS') $r.Out
Test-That 'counts only: the rows, never a value' ($r.Out -match 'BACKUP list "PFM Waivers": rows=2 csv=yes' -and $r.Out -notmatch 'FAKE 1') $r.Out
Test-That 'a Diagnose finding is masked' ($r.Out -match 'pass=1 findings=1 notes=1' -and $r.Out -match 'FINDING: b at <URL>' -and $r.Out -notmatch 'example\.com') $r.Out
Test-That 'the result file is written' (Test-Path -LiteralPath (Join-Path $d '90161Z-T22-maint-r12.txt')) $r.Out
$d = New-Fake $false $false $false; $dirs += $d; $r = Invoke-Maint $d 'Read'
$ok = ($r.Code -eq 1 -and $r.Out -match 'RESULT INSTALL FAIL' -and $r.Out -match 'RESULT DIAGNOSE FAIL' -and $r.Out -match 'csv=no' -and $r.Out -match 'RESULT BACKUP FAIL')
Test-That 'nothing there: 3 FAIL (a backup without its csv fails), exit 1' $ok $r.Out
$r = Invoke-Maint $d 'Install'
Test-That 'install step passes and writes its file' ($r.Code -eq 0 -and $r.Out -match 'RESULT INSTALL PASS' -and (Test-Path -LiteralPath (Join-Path $d '90161Z-T22-install-r12.txt'))) $r.Out
foreach ($x in $dirs) { Remove-Item -LiteralPath (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $x))) -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host ('T22MAINT pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
