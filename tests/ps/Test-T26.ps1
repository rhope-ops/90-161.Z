# Tests scripts/gov/90161Z-T26-endorse-r3.ps1 (round R41; the PFM, 20 Nov 26: docs/reviews/2026-11-21-r41-plan.md row 2)
# against a small fake site: the PnP cmdlets the script uses are fakes in this file (an empty PnP.PowerShell 1.12.0
# module in a temporary folder lets the script's module check pass). Proves the logic, not the real service: the gov
# device round is that proof.
# Cases: Make makes the fake publication and the endorsement row to edit once and keeps their numbers; the publication also holds the
# 4 columns that the exit of step 1 needs (R43; the PFM, 25 Nov 26: OPR = the first office row, Applies to Level and Publication Type =
# choices of the schema, the master 673 link on example.test with the fake-data marker; the proof that the T27 Step exit conditions pass
# on it is in tests/ps/Test-T27.ps1); Make stops when PFM Offices has no row; a second Make reuses them;
# Read records ENDORSE-EDIT REFUSED (no PASS or FAIL word) until another person changed that row, then PASS; Read with
# no answer fails; Read finds the answer of another person (not your own row), in ASCII, and counts it; an unknown
# answer reads "other"; Clean recycles the endorsement and log rows and the publication, then the state file; no line
# shows the site host; the script file is ASCII.
# The RADE Restore test parts (R41; the PFM, 21 Nov 26): the test plays RADE's Restore itself (the rows of the fake
# Recycle Bin back with their old numbers, the purged row made again with a new number, a new Backups folder). Rows makes
# the pause-switch row (No) when missing, sets another value to No and fails on 2 rows; Rows makes 3 endorsement rows and
# 1 log row on the fake publication once; Change recycles 3, deletes 1 for good and adds 1, and a second Change writes
# nothing; Check fails before the played Restore and passes after it; Clean then removes every fake row; the pause values
# equal the manifest's restore.pause.
# Network: none.
# Writes: one temporary folder (the app folder of the test with T26 and Backups, the fake module); removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Last line: "T26 pass=N fail=0".
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T26TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T26TEST FAIL ' + $Name + ' ' + $Detail) }
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('t26-' + [guid]::NewGuid().ToString('N'))
$t26 = Join-Path $work 'T26'; $null = New-Item -ItemType Directory -Path $t26 -Force
$modDir = Join-Path $work 'mods/PnP.PowerShell/1.12.0'; $null = New-Item -ItemType Directory -Path $modDir -Force
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psm1') -Value '# empty on purpose: the cmdlets are fakes in tests/ps/Test-T26.ps1'
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psd1') -Value "@{ RootModule = 'PnP.PowerShell.psm1'; ModuleVersion = '1.12.0'; GUID = '0b0430ce-d799-4f3b-a565-f0dca1f31e18' }"
$env:PSModulePath = (Join-Path $work 'mods') + [IO.Path]::PathSeparator + $env:PSModulePath
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T26-endorse-r3.ps1'

# ---- the fake site and its cmdlets ----
# Reset the fake site: the 5 lists the script reads, the process step rows 0 to 2, 2 office rows (31, 32), you are user 11. Takes nothing; returns nothing.
function New-Site {
  $global:F = @{ RowId = 100; Recycled = 0; Lists = @{ 'PFM Publications' = (New-Object System.Collections.ArrayList); 'PFM Endorsements' = (New-Object System.Collections.ArrayList)
      'PFM Activity Log' = (New-Object System.Collections.ArrayList); 'PFM Process Steps' = (New-Object System.Collections.ArrayList)
      'PFM Offices' = (New-Object System.Collections.ArrayList) } }
  foreach ($n in 31, 32) { $null = $global:F.Lists['PFM Offices'].Add(@{ Id = $n; Title = ('FAKE office ' + $n) }) }   # seeded office rows: the lowest number is the OPR
  foreach ($n in 0, 1, 2) { $null = $global:F.Lists['PFM Process Steps'].Add(@{ Id = (10 + $n); Title = ('FAKE step ' + $n); StepNumber = $n }) }
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
# Fake Add-PnPListItem: adds a row to a list by title, authored by you (user 11), and returns it.
function Add-PnPListItem {
  [CmdletBinding()] param([string]$List, [hashtable]$Values)
  if ($global:FailList -and $List -eq $global:FailList) { throw ('FAKE: the write to ' + $List + ' failed') }   # set by the edit-row failure case
  $global:F.RowId++; $item = @{ Id = $global:F.RowId; Author = [pscustomobject]@{ LookupId = 11 }; Editor = [pscustomobject]@{ LookupId = 11 } }
  foreach ($k in $Values.Keys) { $item[$k] = $Values[$k] }
  if ($item['Publication'] -is [int]) { $item['Publication'] = [pscustomobject]@{ LookupId = $item['Publication'] } }   # a lookup reads back as its value object
  $null = $global:F.Lists[$List].Add($item); return $item }
# Fake Remove-PnPListItem: with -Recycle the row goes to the fake Recycle Bin and is counted; without it (only the part
# Change of the Restore test may do that) the row is gone for good and counted as purged.
function Remove-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [switch]$Recycle, [switch]$Force)
  $hit = @($global:F.Lists[$List] | Where-Object { $_.Id -eq $Identity }); if (-not $hit.Count) { throw 'FAKE 404 row' }
  $global:F.Lists[$List].Remove($hit[0])
  if ($Recycle) { $global:F.Recycled++; if ($null -ne $global:F.Bin) { $null = $global:F.Bin.Add(@{ List = $List; Row = $hit[0] }) } } else { $global:F.Purged++ } }
# Fake Set-PnPListItem: sets fields of one row.
function Set-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [hashtable]$Values)
  $hit = @($global:F.Lists[$List] | Where-Object { $_.Id -eq $Identity }); if (-not $hit.Count) { throw 'FAKE 404 row' }
  foreach ($k in $Values.Keys) { $hit[0][$k] = $Values[$k] } }
# Fake Invoke-PnPSPRestMethod: only GET of your own user (Id 11).
function Invoke-PnPSPRestMethod {
  [CmdletBinding()] param([string]$Method, [string]$Url, [switch]$Raw)
  if ($Method -ne 'Get' -or $Url -notmatch '/_api/web/currentuser') { throw 'FAKE: only GET currentuser' }
  return '{"Id":11}' }
# Add an endorsement row on publication $Pub by user $Author with answer $Answer. Returns nothing.
function Add-Answer([int]$Pub, [int]$Author, [string]$Answer) {
  $global:F.RowId++
  $null = $global:F.Lists['PFM Endorsements'].Add(@{ Id = $global:F.RowId; Title = '90161Z TEST R41 answer'; Publication = [pscustomobject]@{ LookupId = $Pub }
      EndorsementStatus = $Answer; Author = [pscustomobject]@{ LookupId = $Author } }) }
# The Restore test: a fake site with the fake publication (row 50), PFM Settings and an empty fake Recycle Bin, and no
# state file. Takes the values of the pause-switch rows to start with (none, one or more); returns nothing.
function Reset-RestoreCase([string[]]$PauseValues) {
  New-Site; $global:F.Bin = (New-Object System.Collections.ArrayList); $global:F.Purged = 0
  $global:F.Lists['PFM Settings'] = (New-Object System.Collections.ArrayList)
  $null = $global:F.Lists['PFM Publications'].Add(@{ Id = 50; Title = '90161Z TEST R41 endorse (delete me)' })
  $n = 0; foreach ($v in $PauseValues) { $n++; $null = $global:F.Lists['PFM Settings'].Add(@{ Id = (60 + $n); Title = 'FlowsPaused'; SettingValue = $v }) }
  Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
}
# Plays RADE's Restore on the fake site: every row of the fake Recycle Bin back with its number; the purged log row made
# again with a new number; a new Backups folder (the fresh backup). Takes nothing; returns nothing.
function Invoke-FakeRestore {
  foreach ($b in @($global:F.Bin)) { $null = $global:F.Lists[$b.List].Add($b.Row) }; $global:F.Bin.Clear()
  $global:F.RowId++; $log = @{ Id = $global:F.RowId; Title = '90161Z TEST R41 restore log (delete me)'; Publication = [pscustomobject]@{ LookupId = 50 } }
  $null = $global:F.Lists['PFM Activity Log'].Add($log)
  $null = New-Item -ItemType Directory -Path (Join-Path (Join-Path $work 'Backups') ('fresh-' + [guid]::NewGuid().ToString('N'))) -Force }
# Run one part against the fake site. Takes the part name; returns @{ Code; Text (the screen output); File (the result file text) }.
function Invoke-T26([string]$Part) {
  $global:LASTEXITCODE = 0
  $out = & $script -Id 'tester01' -Part $Part -NoPause -NoLaunch -TestDir $t26 *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t26 ('90161Z-T26-endorse-' + $Part.ToLowerInvariant() + '-r3.txt')
  return @{ Code = $LASTEXITCODE; Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
}
$stateFile = Join-Path $t26 '90161Z-T26-endorse-state-r3.txt'
try {
  New-Site
  $r = Invoke-T26 'Make'
  $pubs = @($global:F.Lists['PFM Publications'])
  $ok = ($r.Code -eq 0 -and $pubs.Count -eq 1 -and $pubs[0].Title -eq '90161Z TEST R41 endorse (delete me)' -and $pubs[0].ProcessStep -eq 11 -and $pubs[0].ActionStatus -eq 'On Track')
  Test-That 'Make makes 1 fake publication at step 1, On Track' $ok $r.Text
  $schema = Get-Content -LiteralPath (Join-Path $Root 'schemas/lists/PFMPublications.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $ch = @{}; foreach ($fld in $schema.fields) { if ($fld.type -eq 'Choice') { $ch[[string]$fld.internalName] = @($fld.choices) } }
  $ok = ($pubs[0].OPR -eq 31 -and $pubs[0].AppliesToLevel -cin $ch['AppliesToLevel'] -and $pubs[0].PublicationType -cin $ch['PublicationType'] -and
      [string]$pubs[0].MasterForm673Link -match '^https://example\.test/[^,\s]+, 90161Z TEST ')
  Test-That 'Make fills OPR (the first office row), Applies to Level and Publication Type (schema choices) and the 673 link (fake address, marker)' $ok $r.Text
  $st = Get-Content -LiteralPath $stateFile -Raw
  Test-That 'Make keeps the publication number in the state file (Made=yes)' ($st -match ('PubId=' + $pubs[0].Id) -and $st -match 'Made=yes') $r.Text
  Test-That 'Make writes its result file and the clipboard line' ($r.File -match 'ITEM m3-link INFO .+clipboard=no \(test run\)' -and $r.File -match 'ENDORSE Make done: passed=2 failed=0') $r.File
  $er = @($global:F.Lists['PFM Endorsements'])
  $ok = ($er.Count -eq 1 -and $er[0].Title -eq '90161Z TEST R41 edit me' -and $er[0].EndorsementStatus -eq 'Not Started' -and $er[0].Publication.LookupId -eq $pubs[0].Id)
  $ok = ($ok -and (Get-Content -LiteralPath $stateFile -Raw) -match ('EditId=' + $er[0].Id))
  Test-That 'Make makes the fake endorsement row to edit (Not Started, on the fake publication) and keeps its number' $ok $r.File
  $r = Invoke-T26 'Make'
  $ok = ($r.Code -eq 0 -and @($global:F.Lists['PFM Publications']).Count -eq 1 -and (Get-Content -LiteralPath $stateFile -Raw) -match 'Made=yes')
  Test-That 'a second Make reuses the fake publication (still 1; Made stays yes)' ($ok -and @($global:F.Lists['PFM Endorsements']).Count -eq 1) $r.Text
  $pub = [int]$pubs[0].Id
  Add-Answer $pub 11 'Concur'   # your own row does not count
  $r = Invoke-T26 'Read'
  Test-That 'Read with no answer by another person: RESULT ENDORSE FAIL' ($r.Code -eq 0 -and $r.File -match '(?m)^RESULT ENDORSE FAIL answer=none rows=0') $r.File
  $ok = ($r.File -match '(?m)^RESULT ENDORSE-EDIT REFUSED \(expected' -and $r.File -notmatch '(?m)^RESULT ENDORSE-EDIT .*\b(PASS|FAIL)\b')
  Test-That 'Read with the row to edit unchanged: RESULT ENDORSE-EDIT REFUSED, with no PASS or FAIL word' $ok $r.File
  $edit = @($global:F.Lists['PFM Endorsements'])[0]; $edit.Editor = [pscustomobject]@{ LookupId = 31 }; $edit.EndorsementStatus = 'Nonconcur'
  $r = Invoke-T26 'Read'
  Test-That 'Read after the second person changed your row: RESULT ENDORSE-EDIT PASS answer=Nonconcur' ($r.File -match '(?m)^RESULT ENDORSE-EDIT PASS answer=Nonconcur\r?$') $r.File
  Add-Answer $pub 31 'Not Started'; Add-Answer $pub 31 ('Concur' + [char]0x2014 + 'No Response')
  $r = Invoke-T26 'Read'
  $ok = ($r.File -match '(?m)^RESULT ENDORSE PASS answer=Concur-No Response rows=1' -and $r.File -match 'by another person=2; with an answer=1; with the fake-data title=2')
  Test-That 'Read finds the newest answer of another person, in ASCII, and counts it' $ok $r.File
  Add-Answer $pub 31 'Something typed'
  $r = Invoke-T26 'Read'
  Test-That 'an answer that is not a choice reads "other" (no site text in a line)' ($r.File -match '(?m)^RESULT ENDORSE PASS answer=other rows=2' -and $r.File -notmatch 'Something typed') $r.File
  $global:F.RowId++; $null = $global:F.Lists['PFM Activity Log'].Add(@{ Id = $global:F.RowId; Title = 'FAKE log'; Publication = [pscustomobject]@{ LookupId = $pub } })
  $r = Invoke-T26 'Clean'
  Test-That 'Clean recycles the 5 endorsement rows, the log row and the publication, then the state file' ($r.Code -eq 0 -and $global:F.Recycled -eq 7 -and
      @($global:F.Lists['PFM Publications']).Count -eq 0 -and
      -not (Test-Path -LiteralPath $stateFile) -and $r.File -match 'rows moved to the site Recycle Bin=6') $r.File
  $r = Invoke-T26 'Clean'
  Test-That 'Clean again: nothing on file, nothing removed' ($r.Code -eq 0 -and $r.File -match 'no fake publication on file' -and $global:F.Recycled -eq 7) $r.File
  New-Site; $global:F.Lists.Remove('PFM Process Steps')
  $r = Invoke-T26 'Make'
  Test-That 'Make with no process steps: STOPPED, exit 1' ($r.Code -eq 1 -and $r.File -match '(?m)^STOPPED: ') $r.File
  New-Site; $global:F.Lists['PFM Offices'].Clear()
  $r = Invoke-T26 'Make'
  $ok = ($r.Code -eq 1 -and $r.File -match '(?m)^STOPPED: OFFICE not found' -and @($global:F.Lists['PFM Publications']).Count -eq 0)
  Test-That 'Make with no PFM Offices row: STOPPED, exit 1, no publication made' $ok $r.File
  New-Site; $global:FailList = 'PFM Endorsements'
  $r = Invoke-T26 'Make'; $global:FailList = $null
  $st = $(if (Test-Path -LiteralPath $stateFile) { Get-Content -LiteralPath $stateFile -Raw } else { '' })
  Test-That 'Make whose edit-row write fails: exit 1, the state file still holds the publication it made (Made=yes)' ($r.Code -eq 1 -and $st -match 'PubId=\d+' -and $st -match 'Made=yes') $r.Text
  $r = Invoke-T26 'Clean'
  Test-That 'Clean after that failure removes the publication Make made' ($r.Code -eq 0 -and @($global:F.Lists['PFM Publications']).Count -eq 0 -and -not (Test-Path -LiteralPath $stateFile)) $r.File
  # ---- the RADE Restore test parts (R41) ----
  Reset-RestoreCase @()
  $r = Invoke-T26 'Rows'
  $set = @($global:F.Lists['PFM Settings'])
  $ok = ($r.Code -eq 0 -and $set.Count -eq 1 -and $set[0].SettingValue -eq 'No' -and $r.File -match '(?m)^RESULT PAUSEROW PASS row=made before=missing now=No\b')
  Test-That 'Rows with no pause-switch row: makes it with No, RESULT PAUSEROW PASS' $ok $r.File
  $e = @($global:F.Lists['PFM Endorsements']); $l = @($global:F.Lists['PFM Activity Log'])
  $bad = @($e + $l | Where-Object { $_.Publication.LookupId -ne 50 -or -not ([string]$_.Title).StartsWith('90161Z TEST') }).Count
  $ok = ($e.Count -eq 3 -and $l.Count -eq 1 -and -not $bad -and $r.File -match '(?m)^RESULT ROWS PASS made=4 found=0')
  Test-That 'Rows makes 3 endorsement rows and 1 log row on the fake publication, each with the fake-data title' $ok $r.File
  $r = Invoke-T26 'Rows'
  $ok = ($r.Code -eq 0 -and @($global:F.Lists['PFM Endorsements']).Count -eq 3 -and $r.File -match 'RESULT ROWS PASS made=0 found=4' -and $r.File -match 'row=kept before=missing now=No')
  Test-That 'a second Rows makes no second row and keeps the pause value and the value before the round (missing)' $ok $r.File
  $r = Invoke-T26 'Change'
  $ok = ($r.Code -eq 0 -and $global:F.Bin.Count -eq 3 -and $global:F.Purged -eq 1 -and @($global:F.Lists['PFM Endorsements']).Count -eq 1)
  $ok = ($ok -and @($global:F.Lists['PFM Activity Log']).Count -eq 0 -and $r.File -match '(?m)^RESULT CHANGE PASS to the Recycle Bin=3 deleted for good=1 new row=1')
  Test-That 'Change: 3 rows to the Recycle Bin, 1 deleted for good, 1 new row (RESULT CHANGE PASS)' $ok $r.File
  $r = Invoke-T26 'Change'
  $ok = ($r.Code -eq 0 -and $global:F.Bin.Count -eq 3 -and $global:F.Purged -eq 1 -and @($global:F.Lists['PFM Endorsements']).Count -eq 1)
  Test-That 'a second Change writes nothing and says so (counts 0)' ($ok -and $r.File -match '(?m)^RESULT CHANGE PASS to the Recycle Bin=0 deleted for good=0 new row=0 ') $r.File
  $r = Invoke-T26 'Check'
  $ok = ($r.File -match '(?m)^RESULT RESTORE-BIN FAIL back with the old row number=0 of 3' -and $r.File -match '(?m)^RESULT RESTORE-NEW FAIL' -and $r.File -match '(?m)^RESULT FRESH-BACKUP FAIL')
  Test-That 'Check before Restore: RESTORE-BIN, RESTORE-NEW and FRESH-BACKUP fail' $ok $r.File
  Start-Sleep -Milliseconds 1100   # the fresh backup folder must be newer than the change time (whole seconds)
  Invoke-FakeRestore
  $r = Invoke-T26 'Check'
  $ok = ($r.Code -eq 0 -and $r.File -match '(?m)^RESULT RESTORE-BIN PASS back with the old row number=3 of 3; made twice=0\r?$')
  $ok = ($ok -and $r.File -match '(?m)^RESULT RESTORE-NEW PASS log rows=1; with the old row number=0' -and $r.File -match '(?m)^RESULT RESTORE-KEEP PASS')
  $ok = ($ok -and $r.File -match '(?m)^RESULT PAUSEROW PASS now=No before Restore=No\r?$' -and $r.File -match '(?m)^RESULT FRESH-BACKUP PASS' -and $r.File -notmatch '\bFAIL\b')
  Test-That 'Check after Restore: 5 PASS (old numbers back, the purged row new, the new row kept, pause No, fresh backup)' $ok $r.File
  $global:F.Recycled = 0; $r = Invoke-T26 'Clean'
  $left = @($global:F.Lists['PFM Endorsements']).Count + @($global:F.Lists['PFM Activity Log']).Count
  Test-That 'Clean afterwards removes every fake row of the Restore test (5 rows, the re-made one too)' ($r.Code -eq 0 -and $left -eq 0 -and $global:F.Recycled -eq 5) $r.File
  Test-That 'Clean: the pause row had no value before (made by Rows), so it stays No: RESULT PAUSEROW PASS value=No' ($r.File -match '(?m)^RESULT PAUSEROW PASS value=No\r?$') $r.File
  # Rows, Change, Rows again (new rows: the old Change marks go), Change again: real counts each time.
  Reset-RestoreCase @('No')
  $null = Invoke-T26 'Rows'; $null = Invoke-T26 'Change'; $r = Invoke-T26 'Rows'
  $ok = ($r.File -match 'RESULT ROWS PASS made=4 found=0' -and $r.File -match 'row=kept before=No now=No')
  $r = Invoke-T26 'Change'
  $ok = ($ok -and $r.File -match '(?m)^RESULT CHANGE PASS to the Recycle Bin=3 deleted for good=1 new row=1 ' -and $global:F.Bin.Count -eq 6 -and $global:F.Purged -eq 2)
  Test-That 'Rows, Change, Rows again, Change again: the second Change works on the new rows (3, 1, 1)' $ok $r.File
  # Change never deletes a row on file whose title is not the fake-data title.
  Reset-RestoreCase @('No')
  $null = Invoke-T26 'Rows'; $log = @($global:F.Lists['PFM Activity Log'])[0]; $log.Title = 'FAKE other title'
  $r = Invoke-T26 'Change'
  $ok = ($global:F.Purged -eq 0 -and @($global:F.Lists['PFM Activity Log']).Count -eq 1)
  $ok = ($ok -and $r.File -match '(?m)^RESULT CHANGE FAIL to the Recycle Bin=3 deleted for good=0 new row=1 .+fake-data title=1')
  Test-That 'Change with a log row that lost its fake-data title: not deleted, RESULT CHANGE FAIL' $ok $r.File
  # Clean puts the pause row back to its value from before the round, only when it differs (the PFM, 21 Nov 26).
  Reset-RestoreCase @('Yes')
  $null = Invoke-T26 'Rows'; $r = Invoke-T26 'Clean'
  $ok = (@($global:F.Lists['PFM Settings'])[0].SettingValue -eq 'Yes' -and $r.File -match '(?m)^RESULT PAUSEROW PASS value=Yes\r?$')
  Test-That 'Clean after Rows set the pause row from Yes to No: sets it back to Yes (RESULT PAUSEROW PASS value=Yes)' $ok $r.File
  Reset-RestoreCase @('Yes')
  $null = Invoke-T26 'Rows'; $null = Invoke-T26 'Rows'; $r = Invoke-T26 'Clean'
  $ok = (@($global:F.Lists['PFM Settings'])[0].SettingValue -eq 'Yes' -and $r.File -match '(?m)^RESULT PAUSEROW PASS value=Yes\r?$')
  Test-That 'Rows twice, then Clean: the value before the round (Yes) is kept and set back' $ok $r.File
  Reset-RestoreCase @('Maybe')
  $null = Invoke-T26 'Rows'; $r = Invoke-T26 'Clean'
  $ok = (@($global:F.Lists['PFM Settings'])[0].SettingValue -eq 'No' -and $r.File -match '(?m)^RESULT PAUSEROW PASS value=No\r?$')
  Test-That 'Clean after a pause row with other text: the off value No, never the old text' $ok $r.File
  Reset-RestoreCase @('No')
  $null = Invoke-T26 'Rows'; $global:F.Lists['PFM Settings'].Clear(); $r = Invoke-T26 'Clean'
  $ok = ($r.File -match '(?m)^RESULT PAUSEROW FAIL rows named FlowsPaused=0' -and (Test-Path -LiteralPath $stateFile))
  Test-That 'Clean with no pause row on the site: RESULT PAUSEROW FAIL, the state file stays' $ok $r.File
  Reset-RestoreCase @('Yes')
  $r = Invoke-T26 'Rows'
  $ok = (@($global:F.Lists['PFM Settings'])[0].SettingValue -eq 'No' -and $r.File -match 'RESULT PAUSEROW PASS row=set before=Yes now=No')
  Test-That 'Rows with the pause switch on (Yes): sets it to No' $ok $r.File
  Reset-RestoreCase @('No', 'No')
  $r = Invoke-T26 'Rows'
  $ok = ($r.File -match '(?m)^RESULT PAUSEROW FAIL rows named FlowsPaused=2' -and @($global:F.Lists['PFM Settings']).Count -eq 2)
  Test-That 'Rows with 2 pause-switch rows: RESULT PAUSEROW FAIL, nothing changed' $ok $r.File
  Reset-RestoreCase @('No'); $global:F.Lists['PFM Publications'].Clear()
  $r = Invoke-T26 'Rows'
  Test-That 'Rows with no fake publication: RESULT ROWS FAIL, no row made' ($r.File -match '(?m)^RESULT ROWS FAIL' -and @($global:F.Lists['PFM Endorsements']).Count -eq 0) $r.File
  # One home: the pause values of the script equal the deploy app's restore.pause in the round definition.
  $txt = Get-Content -LiteralPath $script -Raw
  $m = [regex]::Match($txt, "(?m)^\`$Pause = @\{ List = '([^']+)'; Title = '([^']+)'; Field = '([^']+)'; On = '([^']+)'; Off = '([^']+)' \}\r?$")
  $man = Get-Content -LiteralPath (Join-Path $Root 'scripts/paste_bundles.json') -Raw | ConvertFrom-Json
  $p = @(@($man.bundles | ForEach-Object { $_.apps } | Where-Object { $_.mode -eq 'deploy' -and $_.restore }) | ForEach-Object { $_.restore.pause })
  $ok = ($m.Success -and $p.Count -eq 1 -and $p[0].list -eq $m.Groups[1].Value -and $p[0].title -eq $m.Groups[2].Value)
  Test-That 'the pause values of the script equal the manifest restore.pause' ($ok -and $p[0].field -eq $m.Groups[3].Value -and $p[0].on -eq $m.Groups[4].Value) ''
  $all = Get-ChildItem -LiteralPath $t26 -Filter '*.txt' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
  Test-That 'no result line shows the site host' (-not (@($all) -join "`n").Contains('fakehost')) ''
  $bytes = [IO.File]::ReadAllBytes($script); Test-That 'the script file is ASCII' (-not @($bytes | Where-Object { $_ -gt 127 }).Count) ''
} finally {
  Set-Location -LiteralPath $Root
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('T26 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
