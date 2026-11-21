# Tests scripts/gov/90161Z-T27-restore-r1.ps1 (round R41, the RADE Restore test; the PFM, 21 Nov 26) against a small fake
# site: the PnP cmdlets the script uses are fakes in this file (an empty PnP.PowerShell 1.12.0 module in a temporary
# folder lets the script's module check pass). The test plays RADE's Restore itself (3 rows back from the fake Recycle
# Bin with their old numbers, the purged row made again with a new number, a new Backups folder). Proves the logic, not
# the real service: the gov device round is that proof.
# Cases: Make makes the pause-switch row (No) when missing, sets another value to No, and fails on 2 rows; Make makes
# 3 endorsement rows and 1 log row on the fake publication once; Change recycles 3, deletes 1 for good and adds 1, and a
# second Change writes nothing; Check passes after the played Restore and fails before it; the pause values equal the
# manifest's restore.pause; no line shows the site host; the script file is ASCII.
# Network: none.
# Writes: one temporary folder (the app folder of the test with T27 and Backups, the fake module); removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Last line: "T27 pass=N fail=0".
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T27TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T27TEST FAIL ' + $Name + ' ' + $Detail) }
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('t27-' + [guid]::NewGuid().ToString('N'))
$t27 = Join-Path $work 'T27'; $null = New-Item -ItemType Directory -Path $t27 -Force
$modDir = Join-Path $work 'mods/PnP.PowerShell/1.12.0'; $null = New-Item -ItemType Directory -Path $modDir -Force
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psm1') -Value '# empty on purpose: the cmdlets are fakes in tests/ps/Test-T27.ps1'
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psd1') -Value "@{ RootModule = 'PnP.PowerShell.psm1'; ModuleVersion = '1.12.0'; GUID = '0b0430ce-d799-4f3b-a565-f0dca1f31e18' }"
$env:PSModulePath = (Join-Path $work 'mods') + [IO.Path]::PathSeparator + $env:PSModulePath
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T27-restore-r1.ps1'
$pubTitle = '90161Z TEST R41 endorse (delete me)'

# ---- the fake site and its cmdlets ----
# Reset the fake site: the 4 lists the script reads, the fake publication (row 50), an empty fake Recycle Bin. Takes
# the pause rows to start with (0, 1 or more values); returns nothing.
function New-Site([string[]]$PauseValues) {
  $global:F = @{ RowId = 100; Bin = (New-Object System.Collections.ArrayList); Purged = 0; Lists = @{ 'PFM Publications' = (New-Object System.Collections.ArrayList)
      'PFM Endorsements' = (New-Object System.Collections.ArrayList); 'PFM Activity Log' = (New-Object System.Collections.ArrayList); 'PFM Settings' = (New-Object System.Collections.ArrayList) } }
  $null = $global:F.Lists['PFM Publications'].Add(@{ Id = 50; Title = $pubTitle })
  $n = 0; foreach ($v in $PauseValues) { $n++; $null = $global:F.Lists['PFM Settings'].Add(@{ Id = (60 + $n); Title = 'FlowsPaused'; SettingValue = $v }) }
}
# Fake Connect-PnPOnline: accepts only -UseWebLogin, as on the gov device.
function Connect-PnPOnline { [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin) if (-not $UseWebLogin) { throw 'FAKE: -UseWebLogin only' } }
# Fake Disconnect-PnPOnline: does nothing.
function Disconnect-PnPOnline { [CmdletBinding()] param() }
# Fake Get-PnPListItem: the rows of a list by title (throws for a list the fake site does not have).
function Get-PnPListItem {
  [CmdletBinding()] param([string]$List, [string[]]$Fields, [int]$PageSize)
  if (-not $global:F.Lists.ContainsKey($List)) { throw ('FAKE: no list titled ' + $List) }
  return @($global:F.Lists[$List]) }
# Fake Add-PnPListItem: adds a row to a list by title and returns it; a lookup reads back as its value object.
function Add-PnPListItem {
  [CmdletBinding()] param([string]$List, [hashtable]$Values)
  $global:F.RowId++; $item = @{ Id = $global:F.RowId }
  foreach ($k in $Values.Keys) { $item[$k] = $Values[$k] }
  if ($item['Publication'] -is [int]) { $item['Publication'] = [pscustomobject]@{ LookupId = $item['Publication'] } }
  $null = $global:F.Lists[$List].Add($item); return $item }
# Fake Set-PnPListItem: sets fields of one row.
function Set-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [hashtable]$Values)
  $hit = @($global:F.Lists[$List] | Where-Object { $_.Id -eq $Identity }); if (-not $hit.Count) { throw 'FAKE 404 row' }
  foreach ($k in $Values.Keys) { $hit[0][$k] = $Values[$k] } }
# Fake Remove-PnPListItem: with -Recycle the row goes to the fake Recycle Bin; without it the row is gone for good.
function Remove-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [switch]$Recycle, [switch]$Force)
  $hit = @($global:F.Lists[$List] | Where-Object { $_.Id -eq $Identity }); if (-not $hit.Count) { throw 'FAKE 404 row' }
  $global:F.Lists[$List].Remove($hit[0])
  if ($Recycle) { $null = $global:F.Bin.Add(@{ List = $List; Row = $hit[0] }) } else { $global:F.Purged++ } }
# Plays RADE's Restore on the fake site: every row in the fake Recycle Bin back with its number; the purged log row made
# again with a new number; a new Backups folder (the fresh backup). Takes nothing; returns nothing.
function Invoke-FakeRestore {
  foreach ($b in @($global:F.Bin)) { $null = $global:F.Lists[$b.List].Add($b.Row) }; $global:F.Bin.Clear()
  $global:F.RowId++; $null = $global:F.Lists['PFM Activity Log'].Add(@{ Id = $global:F.RowId; Title = '90161Z TEST R41 restore log (delete me)'; Publication = [pscustomobject]@{ LookupId = 50 } })
  $null = New-Item -ItemType Directory -Path (Join-Path (Join-Path $work 'Backups') ('fresh-' + [guid]::NewGuid().ToString('N'))) -Force }
# Run one part against the fake site. Takes the part name; returns @{ Code; Text (the screen output); File (the result file text) }.
function Invoke-T27([string]$Part) {
  $global:LASTEXITCODE = 0
  $out = & $script -Id 'tester01' -Part $Part -NoPause -TestDir $t27 *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t27 ('90161Z-T27-restore-' + $Part.ToLowerInvariant() + '-r1.txt')
  return @{ Code = $LASTEXITCODE; Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
}
$stateFile = Join-Path $t27 '90161Z-T27-restore-state-r1.txt'
try {
  New-Site @()
  $r = Invoke-T27 'Make'
  $set = @($global:F.Lists['PFM Settings'])
  $ok = ($r.Code -eq 0 -and $set.Count -eq 1 -and $set[0].SettingValue -eq 'No' -and $r.File -match '(?m)^RESULT PAUSEROW PASS row=made before=missing now=No\b')
  Test-That 'Make with no pause-switch row: makes it with No, RESULT PAUSEROW PASS' $ok $r.File
  $e = @($global:F.Lists['PFM Endorsements']); $l = @($global:F.Lists['PFM Activity Log'])
  $ok = ($e.Count -eq 3 -and $l.Count -eq 1 -and -not @($e + $l | Where-Object { $_.Publication.LookupId -ne 50 -or -not ([string]$_.Title).StartsWith('90161Z TEST') }).Count)
  Test-That 'Make makes 3 endorsement rows and 1 log row on the fake publication, each with the fake-data title' ($ok -and $r.File -match '(?m)^RESULT ROWS PASS made=4 found=0') $r.File
  $r = Invoke-T27 'Make'
  $ok = ($r.Code -eq 0 -and @($global:F.Lists['PFM Endorsements']).Count -eq 3 -and $r.File -match 'RESULT ROWS PASS made=0 found=4' -and $r.File -match 'row=kept before=No now=No')
  Test-That 'a second Make makes no second row and keeps the pause value' $ok $r.File
  $r = Invoke-T27 'Change'
  $ok = ($r.Code -eq 0 -and $global:F.Bin.Count -eq 3 -and $global:F.Purged -eq 1 -and @($global:F.Lists['PFM Endorsements']).Count -eq 1 -and @($global:F.Lists['PFM Activity Log']).Count -eq 0)
  Test-That 'Change: 3 rows to the Recycle Bin, 1 deleted for good, 1 new row (RESULT CHANGE PASS)' ($ok -and $r.File -match '(?m)^RESULT CHANGE PASS to the Recycle Bin=3 deleted for good=1 new row=1') $r.File
  $r = Invoke-T27 'Change'
  Test-That 'a second Change writes nothing' ($r.Code -eq 0 -and $global:F.Bin.Count -eq 3 -and $global:F.Purged -eq 1 -and @($global:F.Lists['PFM Endorsements']).Count -eq 1) $r.File
  $r = Invoke-T27 'Check'
  $ok = ($r.File -match '(?m)^RESULT RESTORE-BIN FAIL back with the old row number=0 of 3' -and $r.File -match '(?m)^RESULT RESTORE-NEW FAIL' -and $r.File -match '(?m)^RESULT FRESH-BACKUP FAIL')
  Test-That 'Check before Restore: RESTORE-BIN, RESTORE-NEW and FRESH-BACKUP fail' $ok $r.File
  Start-Sleep -Milliseconds 1100   # the fresh backup folder must be newer than the change time (whole seconds)
  Invoke-FakeRestore
  $r = Invoke-T27 'Check'
  $ok = ($r.Code -eq 0 -and $r.File -match '(?m)^RESULT RESTORE-BIN PASS back with the old row number=3 of 3; made twice=0\r?$' -and $r.File -match '(?m)^RESULT RESTORE-NEW PASS log rows=1; with the old row number=0')
  $ok = ($ok -and $r.File -match '(?m)^RESULT RESTORE-KEEP PASS' -and $r.File -match '(?m)^RESULT PAUSEROW PASS now=No before Restore=No\r?$' -and $r.File -match '(?m)^RESULT FRESH-BACKUP PASS')
  Test-That 'Check after Restore: 5 PASS (bin rows back with old numbers, the purged row new, the new row kept, pause No, fresh backup)' ($ok -and $r.File -notmatch '\bFAIL\b') $r.File
  New-Site @('Yes'); Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
  $r = Invoke-T27 'Make'
  Test-That 'Make with the pause switch on (Yes): sets it to No' (@($global:F.Lists['PFM Settings'])[0].SettingValue -eq 'No' -and $r.File -match 'RESULT PAUSEROW PASS row=set before=Yes now=No') $r.File
  New-Site @('No', 'No'); Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
  $r = Invoke-T27 'Make'
  Test-That 'Make with 2 pause-switch rows: RESULT PAUSEROW FAIL, nothing changed' ($r.File -match '(?m)^RESULT PAUSEROW FAIL rows named FlowsPaused=2' -and @($global:F.Lists['PFM Settings']).Count -eq 2) $r.File
  New-Site @('No'); $global:F.Lists['PFM Publications'].Clear(); Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
  $r = Invoke-T27 'Make'
  Test-That 'Make with no fake publication: RESULT ROWS FAIL, no row made' ($r.File -match '(?m)^RESULT ROWS FAIL' -and @($global:F.Lists['PFM Endorsements']).Count -eq 0) $r.File
  # One home: the pause values of the script equal the deploy app's restore.pause in the round definition.
  $txt = Get-Content -LiteralPath $script -Raw
  $m = [regex]::Match($txt, "(?m)^\`$Pause = @\{ List = '([^']+)'; Title = '([^']+)'; Field = '([^']+)'; On = '([^']+)'; Off = '([^']+)' \}\r?$")
  $man = Get-Content -LiteralPath (Join-Path $Root 'scripts/paste_bundles.json') -Raw | ConvertFrom-Json
  $p = @(@($man.bundles | ForEach-Object { $_.apps } | Where-Object { $_.mode -eq 'deploy' -and $_.restore }) | ForEach-Object { $_.restore.pause })
  $ok = ($m.Success -and $p.Count -eq 1 -and $p[0].list -eq $m.Groups[1].Value -and $p[0].title -eq $m.Groups[2].Value -and $p[0].field -eq $m.Groups[3].Value -and $p[0].on -eq $m.Groups[4].Value)
  Test-That 'the pause values of the script equal the manifest restore.pause' $ok ''
  $all = Get-ChildItem -LiteralPath $t27 -Filter '*.txt' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
  Test-That 'no result line shows the site host' (-not (@($all) -join "`n").Contains('fakehost')) ''
  $bytes = [IO.File]::ReadAllBytes($script); Test-That 'the script file is ASCII' (-not @($bytes | Where-Object { $_ -gt 127 }).Count) ''
} finally {
  Set-Location -LiteralPath $Root
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('T27 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
