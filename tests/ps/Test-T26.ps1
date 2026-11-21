# Tests scripts/gov/90161Z-T26-endorse-r1.ps1 (round R41; the PFM, 20 Nov 26: docs/reviews/2026-11-21-r41-plan.md row 2)
# against a small fake site: the PnP cmdlets the script uses are fakes in this file (an empty PnP.PowerShell 1.12.0
# module in a temporary folder lets the script's module check pass). Proves the logic, not the real service: the gov
# device round is that proof.
# Cases: Make makes the fake publication once (step 1, On Track) and keeps its number; a second Make reuses it; Read with
# no answer fails; Read finds the answer of another person (not your own row), in ASCII, and counts it; an unknown
# answer reads "other"; Clean recycles the endorsement and log rows and the publication, then the state file; no line
# shows the site host; the script file is ASCII.
# Network: none.
# Writes: one temporary folder (the T26 folder of the test, the fake module); removed at the end.
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
$script = Join-Path $Root 'scripts/gov/90161Z-T26-endorse-r1.ps1'

# ---- the fake site and its cmdlets ----
# Reset the fake site: the 4 lists the script reads, the process step rows 0 to 2, you are user 11. Takes nothing; returns nothing.
function New-Site {
  $global:F = @{ RowId = 100; Recycled = 0; Lists = @{ 'PFM Publications' = (New-Object System.Collections.ArrayList); 'PFM Endorsements' = (New-Object System.Collections.ArrayList)
      'PFM Activity Log' = (New-Object System.Collections.ArrayList); 'PFM Process Steps' = (New-Object System.Collections.ArrayList) } }
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
  $global:F.RowId++; $item = @{ Id = $global:F.RowId; Author = [pscustomobject]@{ LookupId = 11 } }
  foreach ($k in $Values.Keys) { $item[$k] = $Values[$k] }
  $null = $global:F.Lists[$List].Add($item); return $item }
# Fake Remove-PnPListItem: only to the Recycle Bin (-Recycle), as the script must; counts it.
function Remove-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [switch]$Recycle, [switch]$Force)
  if (-not $Recycle) { throw 'FAKE: -Recycle only' }
  $hit = @($global:F.Lists[$List] | Where-Object { $_.Id -eq $Identity }); if (-not $hit.Count) { throw 'FAKE 404 row' }
  $global:F.Lists[$List].Remove($hit[0]); $global:F.Recycled++ }
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
# Run one part against the fake site. Takes the part name; returns @{ Code; Text (the screen output); File (the result file text) }.
function Invoke-T26([string]$Part) {
  $global:LASTEXITCODE = 0
  $out = & $script -Id 'tester01' -Part $Part -NoPause -NoLaunch -TestDir $t26 *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t26 ('90161Z-T26-endorse-' + $Part.ToLowerInvariant() + '-r1.txt')
  return @{ Code = $LASTEXITCODE; Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
}
$stateFile = Join-Path $t26 '90161Z-T26-endorse-state-r1.txt'
try {
  New-Site
  $r = Invoke-T26 'Make'
  $pubs = @($global:F.Lists['PFM Publications'])
  $ok = ($r.Code -eq 0 -and $pubs.Count -eq 1 -and $pubs[0].Title -eq '90161Z TEST R41 endorse (delete me)' -and $pubs[0].ProcessStep -eq 11 -and $pubs[0].ActionStatus -eq 'On Track')
  Test-That 'Make makes 1 fake publication at step 1, On Track' $ok $r.Text
  $st = Get-Content -LiteralPath $stateFile -Raw
  Test-That 'Make keeps the publication number in the state file (Made=yes)' ($st -match ('PubId=' + $pubs[0].Id) -and $st -match 'Made=yes') $r.Text
  Test-That 'Make writes its result file and the clipboard line' ($r.File -match 'ITEM m2-link INFO .+clipboard=no \(test run\)' -and $r.File -match 'ENDORSE Make done: passed=1 failed=0') $r.File
  $r = Invoke-T26 'Make'
  $ok = ($r.Code -eq 0 -and @($global:F.Lists['PFM Publications']).Count -eq 1 -and (Get-Content -LiteralPath $stateFile -Raw) -match 'Made=yes')
  Test-That 'a second Make reuses the fake publication (still 1; Made stays yes)' $ok $r.Text
  $pub = [int]$pubs[0].Id
  Add-Answer $pub 11 'Concur'   # your own row does not count
  $r = Invoke-T26 'Read'
  Test-That 'Read with no answer by another person: RESULT ENDORSE FAIL' ($r.Code -eq 0 -and $r.File -match '(?m)^RESULT ENDORSE FAIL answer=none rows=0') $r.File
  Add-Answer $pub 31 'Not Started'; Add-Answer $pub 31 ('Concur' + [char]0x2014 + 'No Response')
  $r = Invoke-T26 'Read'
  $ok = ($r.File -match '(?m)^RESULT ENDORSE PASS answer=Concur-No Response rows=1' -and $r.File -match 'by another person=2; with an answer=1; with the fake-data title=2')
  Test-That 'Read finds the newest answer of another person, in ASCII, and counts it' $ok $r.File
  Add-Answer $pub 31 'Something typed'
  $r = Invoke-T26 'Read'
  Test-That 'an answer that is not a choice reads "other" (no site text in a line)' ($r.File -match '(?m)^RESULT ENDORSE PASS answer=other rows=2' -and $r.File -notmatch 'Something typed') $r.File
  $global:F.RowId++; $null = $global:F.Lists['PFM Activity Log'].Add(@{ Id = $global:F.RowId; Title = 'FAKE log'; Publication = [pscustomobject]@{ LookupId = $pub } })
  $r = Invoke-T26 'Clean'
  Test-That 'Clean recycles the 4 endorsement rows, the log row and the publication, then the state file' ($r.Code -eq 0 -and $global:F.Recycled -eq 6 -and
      @($global:F.Lists['PFM Publications']).Count -eq 0 -and
      -not (Test-Path -LiteralPath $stateFile) -and $r.File -match 'rows moved to the site Recycle Bin=5') $r.File
  $r = Invoke-T26 'Clean'
  Test-That 'Clean again: nothing on file, nothing removed' ($r.Code -eq 0 -and $r.File -match 'no fake publication on file' -and $global:F.Recycled -eq 6) $r.File
  New-Site; $global:F.Lists.Remove('PFM Process Steps')
  $r = Invoke-T26 'Make'
  Test-That 'Make with no process steps: STOPPED, exit 1' ($r.Code -eq 1 -and $r.File -match '(?m)^STOPPED: ') $r.File
  $all = Get-ChildItem -LiteralPath $t26 -Filter '*.txt' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
  Test-That 'no result line shows the site host' (-not (@($all) -join "`n").Contains('fakehost')) ''
  $bytes = [IO.File]::ReadAllBytes($script); Test-That 'the script file is ASCII' (-not @($bytes | Where-Object { $_ -gt 127 }).Count) ''
} finally {
  Set-Location -LiteralPath $Root
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('T26 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
