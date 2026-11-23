# Tests scripts/gov/90161Z-T21-probe-r11.ps1 and its modules 90161Z-T21-<part>-r11.ps1 (R34 probe, parts Make, Person, Ask, Office, Run, Look,
# Form, View, Open, Read, Clean) against a small fake site (pwsh 7, also Windows PowerShell 5.1 through tests/ps/Invoke-Ps51.ps1).
# The fake PnP cmdlets are defined here (functions in this file); only an empty PnP.PowerShell 1.12.0 module is put on the
# module path so the script's "is PnP installed" check passes. It proves the script's logic and output; the real service is
# proved by the round on the gov device. Last line: "T21 pass=N fail=0".
# Network: none (the site is a fake in memory; the fake address host is example.test).
# Writes: a temporary folder under the system temp folder, removed at the end.
# Credentials: none (a fake DODID and fake e-mail addresses only).
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T21TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T21TEST FAIL ' + $Name + ' ' + $Detail) }
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('t21-' + [guid]::NewGuid().ToString('N'))
$t21 = Join-Path $work 'T21'; $null = New-Item -ItemType Directory -Path $t21 -Force
$modDir = Join-Path $work 'mods/PnP.PowerShell/1.12.0'
$null = New-Item -ItemType Directory -Path $modDir -Force
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psm1') -Value '# empty on purpose: the cmdlets are fakes in tests/ps/Test-T21.ps1'
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psd1') -Value "@{ RootModule = 'PnP.PowerShell.psm1'; ModuleVersion = '1.12.0'; GUID = '0b0430ce-d799-4f3b-a565-f0dca1f31e18' }"
$env:PSModulePath = (Join-Path $work 'mods') + [IO.Path]::PathSeparator + $env:PSModulePath
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T21-probe-r11.ps1'
$fakeAddr = 'second.person@fake.example'
# R34: the button flow's ID is the one scripts/build_flow_solution.py writes into the look module (the flow's workflow ID in the
# solution r3); the test reads it there and checks it against the solution zip below.
$lookText = Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T21-look-r11.ps1') -Raw
$buttonId = $(if ($lookText -match "(?m)^\`$ButtonFlowId = '([0-9a-f-]{36})'") { $Matches[1] } else { '' })

# ---- the fake site and its cmdlets: in tests/ps/Test-T21.Site.ps1, read here in the same scope ----
. (Join-Path $PSScriptRoot Test-T21.Site.ps1)
$links = Join-Path $t21 '90161Z-T21-links-r5.html'
$state = Join-Path $t21 '90161Z-T21-person-state-r3.txt'

# ---- Make ----
New-Site
$r = Invoke-T21 'Make'; Note $r
$lib = Get-Probe '90161ZProbeFiles'; $lst = Get-Probe '90161ZProbe'
Test-That 'Make: exit 0 and the last line' ($r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Make done: passed=6 failed=0') $r.Text
Test-That 'Make: 1 library and 1 list with the contract titles and folders' ($lib -and $lib.Title -eq '90161Z Probe Files' -and $lib.Template -eq 101 -and $lst -and $lst.Title -eq '90161Z Probe' -and $lst.Template -eq 100 -and $global:F.Created -eq 2)
Test-That 'Make: 4 list columns, none in the library' (($lst.Fields -join ',') -eq 'ProbeTest,ProbeWay,ProbeResult,ProbeDetail' -and $lib.Fields.Count -eq 0)
Test-That 'Make: unique permissions, Visitors keep Read and get Contribute, Full Control kept' ($lst.Unique -and (@($lst.Roles[7]) -join ',') -eq '1073741826,1073741827' -and (@($lst.Roles[5]) -join ',') -eq '1073741829')
Test-That 'Make: 1 workbook uploaded, no macro workbook' ($global:F.Uploads -eq 1 -and ($lib.Files -join ',') -eq '90161Z-T21-fake-book-r1.xlsx')
Test-That 'Make: counts line' ($r.Text -match 'MADE library=1 list=1 columns=4 permission changes=2 files=1')
Test-That 'Make: the other lists are untouched' (-not (Get-FakeListByTitle 'Other probe list').Unique -and (Get-FakeListByTitle 'Documents').Files.Count -eq 0)
$page = Get-Content -LiteralPath $links -Raw
Test-That 'Make: test page with 4 links to the site' ((@([regex]::Matches($page, 'class="go" href="https://fakehost\.example\.test/sites/FakeWing/')).Count -eq 4) -and $page -match 'Lists/90161ZProbe/NewForm\.aspx' -and $page -match 'Lists/90161ZProbe/ProbeButton\.aspx' -and $page -match '90161Z-T21-fake-book-r1\.xlsx\?web=1' -and $page -notmatch '\.xlsm' -and $r.Text -match 'm6-page PASS test page in the T21 folder, links=4') $r.Text
Test-That 'Make: the test page is ASCII and has no script' ($page -notmatch '[^\x00-\x7F]' -and $page -notmatch '<script')
$created = $global:F.Created; $up = $global:F.Uploads
$r = Invoke-T21 'Make'; Note $r
Test-That 'Make twice: changes nothing on the site' ($r.Code -eq 0 -and $r.Text -match 'MADE library=0 list=0 columns=0 permission changes=0 files=0' -and $global:F.Created -eq $created -and $global:F.Uploads -eq $up -and $lst.Fields.Count -eq 4) $r.Text
Test-That 'Make: result file written and equal to the screen lines' ($r.File -match 'PROBE Make done')
New-Site; $global:F.Visitors = 0
$r = Invoke-T21 'Make'; Note $r
Test-That 'Make without a Visitors group: NOTE line, still exit 0' ($r.Code -eq 0 -and $r.Text -match 'NOTE m4: no associated Visitors group' -and $r.Out[-1] -match 'failed=0')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$bookPath = Join-Path $t21 '90161Z-T21-fake-book-r1.xlsx'
# List the entry names of a zip file. Takes the path; returns an array of names.
function Get-ZipNames([string]$Path) { $z = [System.IO.Compression.ZipFile]::OpenRead($Path); try { return @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() } }
Test-That 'Make: saves the workbook from the text block; it opens as a package with no VBA project' ((Test-Path -LiteralPath $bookPath) -and -not (Test-Path -LiteralPath (Join-Path $t21 '90161Z-T21-fake-macro-r1.xlsm')) -and ((Get-ZipNames $bookPath) -contains 'xl/workbook.xml') -and -not ((Get-ZipNames $bookPath) -contains 'xl/vbaProject.bin') -and $r.Text -match 'm5a-workbooks INFO fake workbook saved to the T21 folder now=0')
(Get-Item -LiteralPath $bookPath).LastWriteTime = [datetime]'2001-01-01'
$null = Invoke-T21 'Make'
Test-That 'Make twice: a workbook with the same bytes is not written again' ((Get-Item -LiteralPath $bookPath).LastWriteTime -eq [datetime]'2001-01-01')
Set-Content -LiteralPath $bookPath -Value 'broken'
$r = Invoke-T21 'Make'
Test-That 'Make: a workbook with other bytes is written again' ($r.Text -match 'now=1' -and ((Get-ZipNames $bookPath) -contains 'xl/workbook.xml'))

# ---- Open (no sign-in) ----
Remove-Item -LiteralPath $links
$global:F.Connected = $false; $rests = $global:F.Rests
$r = Invoke-T21 'Open'; Note $r
Test-That 'Open: writes the test page again, no sign-in, no result file' ($r.Code -eq 0 -and (Test-Path -LiteralPath $links) -and $global:F.Rests -eq $rests -and -not $global:F.Connected -and $r.Out[-1] -eq 'PROBE Open done: passed=2 failed=0' -and $r.File -eq '') $r.Text

# ---- Person ----
New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = $fakeAddr
$r = Invoke-T21 'Person'; Note $r
$stateText = $(if (Test-Path -LiteralPath $state) { Get-Content -LiteralPath $state -Raw } else { '' })
Test-That 'Person: added to Visitors yes, exit 0, last line' ($r.Code -eq 0 -and $r.Text -match 'VISITORS added to Visitors: yes; status: added and listed in the group' -and $r.Out[-1] -eq 'PROBE Person done: passed=3 failed=0' -and (@($global:F.GroupUsers[7]) -contains 31)) $r.Text
Test-That 'Person: the state file holds only 3 numbers or flags (no address, no name)' ($stateText -match '(?m)^UserId=31\r?$' -and $stateText -match '(?m)^GroupId=7\r?$' -and $stateText -match '(?m)^WasMember=no\r?$' -and $stateText -notmatch '@|fake|person') $stateText
Test-That 'Person: the address is not in the screen lines, the result file or the state file' ($r.Text -notmatch 'second\.person|fake\.example|@' -and $r.File -notmatch 'second\.person|fake\.example|@') $r.Text
Test-That 'Person: the clipboard step is a test-run note' ($r.Text -match 'p4-link INFO the link of the new row form is on the clipboard=no \(test run\)')
# Review 17 Nov 26: a second run must keep "added by this test", so Clean still removes the person.
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person run again: the state file still says WasMember=no and the person counts as added' ((Get-Content -LiteralPath $state -Raw) -match '(?m)^WasMember=no\r?$' -and $r.Text -match 'added to Visitors: yes') $r.Text
$env:T21_TEST_ADDRESS = 'member.person@fake.example'; $global:F.GroupUsers[7] = @(3, 4, 31, 32)
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person run again with another person: refused, the first record kept' ((Get-Content -LiteralPath $state -Raw) -match '(?m)^UserId=31\r?$' -and $r.Text -match 'added to Visitors: no' -and $r.Text -match 'run the Clean part first') $r.Text
$env:T21_TEST_ADDRESS = $fakeAddr; $global:F.GroupUsers[7] = @(3, 4, 31)
$env:T21_TEST_ADDRESS = 'member.person@fake.example'; $global:F.GroupUsers[7] = @(3, 4, 32); Remove-Item -LiteralPath $state
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: a person who is a member already is not added again and is marked' ($r.Text -match 'added to Visitors: no; status: already a member' -and $global:F.Added -eq 1 -and ((Get-Content -LiteralPath $state -Raw) -match 'WasMember=yes') -and $r.Out[-1] -eq 'PROBE Person done: passed=3 failed=0') $r.Text
$env:T21_TEST_ADDRESS = 'nobody@fake.example'; Remove-Item -LiteralPath $state
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: a person who is not found: no, no state file, no identity' ($r.Code -eq 0 -and $r.Text -match 'added to Visitors: no; status: the person was not found on this site' -and -not (Test-Path -LiteralPath $state) -and $r.Text -notmatch 'nobody') $r.Text
$global:F.NoGetByEmail = $true
$env:T21_TEST_ADDRESS = 'not an address'
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: no valid address: no' ($r.Text -match 'added to Visitors: no; status: no valid address was given' -and -not (Test-Path -LiteralPath $state)) $r.Text
$env:T21_TEST_ADDRESS = "odd'second.person@fake.example"; $global:F.Users["odd'second.person@fake.example"] = 31; $global:F.AddRefused = $true; $global:F.GroupUsers[7] = @(3, 4)   # an apostrophe: the masking must take the whole address (review 17 Nov 26)
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: a refused add: no, status without identity, state kept for Clean' ($r.Code -eq 0 -and $r.Text -match 'added to Visitors: no; status: the add was refused: ' -and (Test-Path -LiteralPath $state) -and $r.Text -notmatch "odd'|second\.person|fake\.example|%40|@" -and $r.File -notmatch "odd'|second\.person|fake\.example|%40|@") $r.Text
$global:F.AddRefused = $false; Remove-Item -LiteralPath $state
$global:F.Visitors = 0
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person without a Visitors group: no' ($r.Code -eq 0 -and $r.Text -match 'added to Visitors: no; status: the site has no Visitors group') $r.Text
Remove-Item Env:T21_TEST_ADDRESS
New-Site
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found') $r.Text
# The script must stop with a plain line when its address window cannot open. On Windows the window opens and waits for a
# person, so here the test stands in for a computer where it cannot: a function named Add-Type that fails hides the real
# command while this one case runs (the script runs in this process), and is removed after it. No task script is changed.
New-Site; $null = Invoke-T21 'Make'
# Stand-in for the real Add-Type during this one case: it fails, as on a computer that cannot open the window. Takes nothing.
function Add-Type { throw 'TEST: no window on this computer' }
try { $r = Invoke-T21 'Person'; Note $r } finally { Remove-Item -LiteralPath Function:\Add-Type }
Test-That 'Person in RADE with no window and no test address: STOPPED, nothing added' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: ADDRESS window not available' -and $global:F.Added -eq 0 -and -not (Test-Path -LiteralPath $state)) $r.Text

# ---- Office (R35, F2 B: a PFM Office member who is not the author edits a row) ----
$officeState = Join-Path $t21 '90161Z-T21-office-state-r8.txt'
New-Site; $null = Invoke-T21 'Make'; $env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS
$lst = Get-Probe '90161ZProbe'
$r = Invoke-T21 'Office'; Note $r
$edit = @($lst.Items | Where-Object { $_.Title -match '^EDITALL R35[0-9a-f]{8}$' }); $oText = $(if (Test-Path -LiteralPath $officeState) { Get-Content -LiteralPath $officeState -Raw } else { '' })
Test-That 'Office: exit 0, the person in PFM Office, the last line' ($r.Code -eq 0 -and $r.Text -match 'OFFICE second person in PFM Office: yes; status: added and listed in the group' -and (@($global:F.GroupUsers[9]) -contains 31) -and $r.Out[-1] -eq 'PROBE Office done: passed=5 failed=0') $r.Text
Test-That 'Office: edit own rows on the probe list, the group holds the level on it, one EDITALL row by you' ($lst.WriteSecurity -eq 2 -and (@($lst.Roles[9]) -join ',') -eq '1073741930' -and $r.Text -match 'o3-level PASS .*given now=yes' -and $edit.Count -eq 1 -and $edit[0].Author.LookupId -eq 11) $r.Text
Test-That 'Office: the read-back says the person can edit every row; the edit form link is a test-run note' ($r.Text -match 'o5-person PASS person in PFM Office=yes; can edit every row of the probe list now=yes' -and $r.Text -match 'o6-link INFO .*clipboard=no \(test run\)') $r.Text
Test-That 'Office: the office state file holds only numbers (group, the people added); no address on screen or in the file' ($oText -match '(?m)^UserIds=31\r?$' -and $oText -match '(?m)^GroupId=9\r?$' -and $oText -notmatch '@|fake|person' -and $r.Text -notmatch 'second\.person|@' -and $r.File -notmatch 'second\.person|@') ($oText + $r.Text)
$r = Invoke-T21 'Office'; Note $r
Test-That 'Office twice: no second row, no second role, the person still counts as added' ($r.Code -eq 0 -and @($lst.Items | Where-Object { $_.Title -like 'EDITALL *' }).Count -eq 1 -and @($lst.Roles[9]).Count -eq 1 -and $r.Text -match 'given now=no' -and $r.Text -match 'made now=no' -and (Get-Content -LiteralPath $officeState -Raw) -match '(?m)^UserIds=31\r?$') $r.Text
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: EDITALL FAILED while the second person has not saved your row, with the next step' ($r.Text -match 'EDITALL FAILED: a PFM Office member who is not the author edits the row=FAIL \(EDITALL rows by you=1; saved by the second person=0\); next: ' -and @($r.Out | Where-Object { $_ -eq 'RESULT EDITALL FAIL' }).Count -eq 1) $r.Text
$edit[0].Editor = [pscustomobject]@{ LookupId = 31 }; $r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: EDITALL PASSED when the second person saved your row' ($r.Text -match 'EDITALL PASSED: a PFM Office member who is not the author edits the row=PASS \(EDITALL rows by you=1; saved by the second person=1\)' -and @($r.Out | Where-Object { $_ -eq 'RESULT EDITALL PASS' }).Count -eq 1) $r.Text
$edit[0].Editor = [pscustomobject]@{ LookupId = 32 }; $r = Invoke-T21 'Read' @{ PollSeconds = 1 }
Test-That 'Read: a save by a person who is not the one on file does not count' ($r.Text -match 'EDITALL FAILED: .*saved by the second person=0') $r.Text
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: takes the person out of PFM Office and Visitors, deletes both state files' ($r.Code -eq 0 -and -not (@($global:F.GroupUsers[9]) -contains 31) -and -not (@($global:F.GroupUsers[7]) -contains 31) -and -not (Test-Path -LiteralPath $officeState) -and -not (Test-Path -LiteralPath $state) -and $r.Text -match 'c1b-office PASS' -and $r.Out[-1] -eq 'PROBE Clean done: passed=4 failed=0') $r.Text
# Review 19 Nov 26: persons A (still on file) and B are both recorded and removed; a failed c1b never stops c2 and c3.
New-Site; $null = Invoke-T21 'Make'; $env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; $null = Invoke-T21 'Office'; Remove-Item -LiteralPath $state
$env:T21_TEST_ADDRESS = 'member.person@fake.example'; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS; $r = Invoke-T21 'Office'; Note $r
Test-That 'Office with a new person while an earlier one is on file: both in the state file, a NOTE' ((Get-Content -LiteralPath $officeState -Raw) -match '(?m)^UserIds=31,32\r?$' -and $r.Text -match 'NOTE o5: a person from an earlier run is still on file' -and (@($global:F.GroupUsers[9]) -join ',') -eq '3,31,32') $r.Text; $global:F.FailGroupRead = 9; $r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: a failed read of PFM Office is a c1b FAIL; the list and library are still recycled; the state file is kept' ($r.Code -eq 0 -and $r.Text -match 'ITEM c1b-office FAIL PFM Office could not be cleaned: ' -and $global:F.Recycled.Count -eq 2 -and (Test-Path -LiteralPath $officeState)) $r.Text
$global:F.FailGroupRead = 0; $r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean again: removes both recorded people from PFM Office and deletes the state file' ($r.Text -match 'c1b-office PASS .*\(2; state file deleted\)' -and (@($global:F.GroupUsers[9]) -join ',') -eq '3' -and -not (Test-Path -LiteralPath $officeState)) $r.Text
# R35 W8: the clean check before the test counts a test person left in PFM Office as a leftover (FAIL, nobody removed); the Clean at the end removes the person.
New-Site; $null = Invoke-T21 'Make'; $env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS; $null = Invoke-T21 'Office'
$r = Invoke-T21 'Clean' @{} 'first'; Note $r; Test-That 'Clean first: a test person left in PFM Office is a leftover: c1b FAIL with what to do, the person and the state file stay' ($r.Text -match 'c1b-office FAIL leftover: 1 test person\(s\) from an earlier test still in the group PFM Office .*What to do:' -and (@($global:F.GroupUsers[9]) -contains 31) -and (Test-Path -LiteralPath $officeState)) $r.Text
$r = Invoke-T21 'Clean' @{} 'last'; Note $r; Test-That 'Clean last: removes that person from PFM Office and deletes the state file' ($r.Text -match 'c1b-office PASS' -and -not (@($global:F.GroupUsers[9]) -contains 31) -and -not (Test-Path -LiteralPath $officeState)) $r.Text
$r = Invoke-T21 'Clean' @{} 'first'; Note $r; Test-That 'Clean first: nothing left in PFM Office: no FAIL' ($r.Text -notmatch 'c1b-office FAIL' -and (@($global:F.GroupUsers[9]) -contains 3)) $r.Text
# The cases where the test cannot prove anything: no second person, no level, no group, a person who edits every row already.
New-Site; $null = Invoke-T21 'Make'; $r = Invoke-T21 'Office'; Note $r
Test-That 'Office without Person: FAIL, nobody added, no state file' ($r.Code -eq 0 -and $r.Text -match 'o5-person FAIL no second person on file: run the part Person first' -and $r.Text -match 'OFFICE second person in PFM Office: no' -and -not (Test-Path -LiteralPath $officeState)) $r.Text
New-Site; $null = Invoke-T21 'Make'; $global:F.NoOfficeLevel = $true; $lst = Get-Probe '90161ZProbe'; $r = Invoke-T21 'Office'
Test-That 'Office without the level: FAIL (run T20 r2 first), the list is not changed' ($r.Code -eq 0 -and $r.Text -match 'o1-group FAIL the level PFM Office Edit All Items is missing' -and $lst.WriteSecurity -eq 1 -and $lst.Items.Count -eq 0) $r.Text
New-Site; $null = Invoke-T21 'Make'; $global:F.Groups = @{ 'Members' = 8 }; $r = Invoke-T21 'Office'
Test-That 'Office without the group: FAIL (run T20 r2 first)' ($r.Code -eq 0 -and $r.Text -match 'o1-group FAIL the site has no group PFM Office: run T20 r2 first') $r.Text
New-Site; $null = Invoke-T21 'Make'; $env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS
$global:F.EditAllUsers = @(31); $r = Invoke-T21 'Office'
Test-That 'Office with a person who edits every row already: FAIL, not added, no state file' ($r.Text -match 'o5-person FAIL the second person can edit every row already' -and -not (@($global:F.GroupUsers[9]) -contains 31) -and -not (Test-Path -LiteralPath $officeState)) $r.Text
New-Site; $r = Invoke-T21 'Office'
Test-That 'Office without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found') $r.Text
$t20Text = (Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T20-provision-lists-r4.ps1') -Raw) + (Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T20-access-r4.ps1') -Raw); $probeText = Get-Content -LiteralPath $script -Raw
Test-That 'Office: the group and level names are the ones T20 r2 makes' ($t20Text -match "(?m)^\`$OfficeGroup = 'PFM Office'$" -and $t20Text -match "(?m)^\`$OfficeLevel = 'PFM Office Edit All Items'$" -and $probeText -match "(?m)^\`$script:OfficeGroup = 'PFM Office'$" -and $probeText -match "(?m)^\`$script:OfficeLevel = 'PFM Office Edit All Items'$")

# ---- Run ----
New-Site; $null = Invoke-T21 'Make'
$r = Invoke-T21 'Run'; Note $r
$lst = Get-Probe '90161ZProbe'
Test-That 'Run: one RUN-HEALTH command row' ($r.Code -eq 0 -and @($lst.Items | Where-Object { $_.Title -match '^RUN-HEALTH R29[0-9a-f]{8}$' }).Count -eq 1 -and $lst.Items.Count -eq 1 -and $r.Out[-1] -eq 'PROBE Run done: passed=0 failed=0') $r.Text
New-Site
$r = Invoke-T21 'Run'
Test-That 'Run without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found') $r.Text

# ---- Look ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
$r = Invoke-T21 'Look'; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^(FORM|VIEW) (PASSED|FAILED):' })
$view = @($global:F.Views)[0]
Test-That 'Look: exit 0, the last line, 2 summary lines' ($r.Code -eq 0 -and $tl.Count -eq 2 -and $r.Out[-1] -eq 'PROBE Look done: passed=4 failed=0') $r.Text
Test-That 'Look: the form header is on the content type and read back' ($lst.CT.ClientFormCustomFormatter -match '"headerJSONFormatter"' -and $lst.CT.ClientFormCustomFormatter -match '90-161\.Z test header' -and $tl[0] -match '^FORM PASSED: a header on the list form \(form formatting set by script\)=PASS \(route=csom; read back=yes\)') $tl[0]
Test-That 'Look: one view with the button of the flow' ($buttonId -and $global:F.ViewsMade -eq 1 -and $view.Title -eq 'ProbeButton' -and $view.CustomFormatter -match 'executeFlow' -and $view.CustomFormatter -match $buttonId -and $view.CustomFormatter -match 'view-formatting\.schema\.json' -and $tl[1] -match '^VIEW PASSED: b a view formatted by script with a button that starts a flow=PASS \(route=csom; read back=yes; flow ID known to the script=yes\)') $tl[1]
$null = $view.CustomFormatter | ConvertFrom-Json
Test-That 'Look: the view formatting is valid JSON' $true
$r = Invoke-T21 'Look'; Note $r
Test-That 'Look twice: the view is not made again' ($global:F.ViewsMade -eq 1 -and $global:F.Views.Count -eq 1 -and $r.Out[-1] -eq 'PROBE Look done: passed=4 failed=0') $r.Text
New-Site; $null = Invoke-T21 'Make'; $global:F.CsomWorks = $false
$lst = Get-Probe '90161ZProbe'
$r = Invoke-T21 'Look'; Note $r
Test-That 'Look: when the CSOM route fails, the REST merge sets both and the lines say route=rest' ($r.Text -match 'FORM PASSED: .*route=rest; read back=yes' -and $r.Text -match 'VIEW PASSED: .*route=rest; read back=yes' -and $lst.CT.ClientFormCustomFormatter -match 'test header') $r.Text
New-Site; $null = Invoke-T21 'Make'; $global:F.CsomWorks = $false; $global:F.MergeWorks = $false
$r = Invoke-T21 'Look'; Note $r
Test-That 'Look: when both routes fail, FORM and VIEW FAILED with the reason, exit 0' ($r.Code -eq 0 -and $r.Text -match 'FORM FAILED: .*route=none; read back=no' -and $r.Text -match 'VIEW FAILED: .*route=none; read back=no' -and $r.Text -match 'l1-form FAIL .*merge refused' -and $r.Out[-1] -match 'failed=4') $r.Text
New-Site
$r = Invoke-T21 'Look'
Test-That 'Look without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found') $r.Text
# R29a finding 6: Form and View run on their own, so the round can show the form after Form alone.
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
$r = Invoke-T21 'Form'; Note $r
Test-That 'Form alone: the header is set, no view is made, its own result file' ($r.Code -eq 0 -and $r.Text -match 'FORM PASSED: .*route=csom; read back=yes' -and $r.Text -cnotmatch 'VIEW' -and $global:F.ViewsMade -eq 0 -and $lst.CT.ClientFormCustomFormatter -match 'test header' -and $r.Out[-1] -eq 'PROBE Form done: passed=2 failed=0' -and $r.File -match 'PROBE Form done') $r.Text
$r = Invoke-T21 'View'; Note $r
Test-That 'View alone with the flow ID: VIEW PASSED and one view' ($r.Code -eq 0 -and $r.Text -match 'VIEW PASSED: .*route=csom; read back=yes' -and $global:F.ViewsMade -eq 1 -and $r.Out[-1] -eq 'PROBE View done: passed=2 failed=0') $r.Text

# ---- Read ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'T4a' 11; Add-Row $lst 'T4a ' 12; Add-Row $lst 'Other title' 13; Add-Row $lst 'RUN-HEALTH R29abcdef12' 11
Add-Res $lst 'HEALTH' 'a' 'FAIL' 'OLD ROW BEFORE THE COMMAND'
$global:F.RowId += 0
Add-Res $lst 'HEALTH' 'a' 'PASS' 'the flow ran on the SharePoint connection of the solution; command row 104'
Add-Row $lst 'BTN-FLOW' 11; Add-Row $lst 'BTN-HAND 1' 11
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^(HEALTH|T4|BUTTON) (PASSED|FAILED):' })
Test-That 'Read: 3 lines (HEALTH, T4, BUTTON) and the last line' ($r.Code -eq 0 -and $tl.Count -eq 3 -and (@($tl | ForEach-Object { ($_ -split ' ')[0] }) -join ',') -eq 'HEALTH,T4,BUTTON' -and $r.Out[-1] -eq 'PROBE Read done: passed=3 failed=0') $r.Text
Test-That 'Read: HEALTH in the exact form, from the row after the command' ($tl[0] -eq 'HEALTH PASSED: a health flow on the SharePoint connection of the solution=PASS (the flow ran on the SharePoint connection of the solution; command row 104)') $tl[0]
Test-That 'Read: T4 counts rows by other people (a title with a space counts; own rows do not)' ($tl[1] -eq 'T4 PASSED: a list form by a second person (Visitors member)=PASS (rows=2; T4a rows=1; person in the Visitors group=not tried (no state file))') $tl[1]
Test-That 'Read: BUTTON counts the rows titled BTN-FLOW (the button flow of the solution), not the old hand-made BTN-HAND' ($tl[2] -match '^BUTTON PASSED: b a view button starts a flow=PASS \(rows titled BTN-FLOW=1\)$') $tl[2]
Test-That 'Read: one RESULT line per test with the separate word PASS (the runner counts it)' ((@($r.Out | Where-Object { $_ -match '^RESULT (HEALTH|T4|BUTTON) PASS$' })).Count -eq 3) $r.Text
$env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: T4 names that the person was added to Visitors' ($r.Text -match 'person in the Visitors group=yes\)') $r.Text

New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'T4a' 11; Add-Row $lst 'RUN-HEALTH R29abcdef12' 11
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-T21 'Read' @{ WaitMinutes = 0.03; PollSeconds = 1 }; Note $r
$healthWhy = $r.Text -match 'check that "90161Z T21 Probe Health r6" reads On in the solution "90-161\.Z flows"'
Test-That 'Read, no second person, no health row, no button row: waits, then T4 NOT RUN and 2 FAILED lines' ($r.Code -eq 0 -and $sw.Elapsed.TotalSeconds -ge 1 -and $r.Text -match 'WAIT health row not there \(time ran out\)' -and $r.Text -match 'T4 NOT RUN: no second person in this round \(T4 passed in R29a\)' -and $r.Text -match 'HEALTH FAILED: .*no result row after the wait' -and $healthWhy -and $r.Text -match 'BUTTON FAILED: .*rows titled BTN-FLOW=0' -and $r.Out[-1] -eq 'PROBE Read done: passed=0 failed=2') $r.Text
Test-That 'Read: failed tests give RESULT lines with the separate word FAIL, so the runner cannot read PASSED (R28 finding 7)' ((@($r.Out | Where-Object { $_ -match '^RESULT (HEALTH|BUTTON) FAIL$' })).Count -eq 2) $r.Text
Test-That 'Read: T4 not run (no state file, no row by another person): no T4 PASSED or FAILED line and no RESULT T4 line' ((@($r.Out | Where-Object { $_ -match '^T4 (PASSED|FAILED)|^RESULT T4 ' })).Count -eq 0 -and (@($r.Out | Where-Object { $_ -eq 'T4 NOT RUN: no second person in this round (T4 passed in R29a)' })).Count -eq 1) $r.Text

New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'RUN-HEALTH R29abcdef12' 11
$global:Lst21 = $lst; $global:F.Gets = 0
# Hook run on each list read: from the fourth read of the round on, it clears itself and adds a failing HEALTH result row.
$global:F.OnGet = { if ($global:F.Gets -ge 4) { $global:F.OnGet = $null; Add-Res $global:Lst21 'HEALTH' 'a' 'FAIL' 'fake failed row; status=403' } }
$sw.Restart()
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: waits for the health row and ends early; a FAIL row gives HEALTH FAILED with its status' ($r.Text -match 'WAIT health row there' -and $sw.Elapsed.TotalSeconds -ge 1 -and $sw.Elapsed.TotalSeconds -lt 60 -and $r.Text -match 'HEALTH FAILED: a health flow on the SharePoint connection of the solution=FAIL \(fake failed row; status=403\)') $r.Text

New-Site; $null = Invoke-T21 'Make'
$sw.Restart(); $r = Invoke-T21 'Read' @{ PollSeconds = 1 }
Test-That 'Read r11 (R38): no command row and no button row: no wait, HEALTH NOT RUN and BUTTON NOT RUN, no RESULT line for either' ($r.Text -match 'WAIT none' -and $sw.Elapsed.TotalSeconds -lt 20 -and $r.Text -match '(?m)^HEALTH NOT RUN: this round did not start the health flow' -and $r.Text -match '(?m)^BUTTON NOT RUN: this round ran no flow step' -and $r.Text -notmatch '(?m)^RESULT (HEALTH|BUTTON) ') $r.Text
New-Site; $null = Invoke-T21 'Make'; Add-Row (Get-Probe '90161ZProbe') 'BTN-FLOW' 11; $r = Invoke-T21 'Read' @{ PollSeconds = 1 }
Test-That 'Read r11: a button row with no command row still reports BUTTON PASSED (only a round with no flow step skips it)' ($r.Text -match '(?m)^BUTTON PASSED: ' -and $r.Text -match '(?m)^HEALTH NOT RUN') $r.Text
# ---- Clean ----
New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS
Test-That 'Clean setup: the person is in the group and the state file exists' ((@($global:F.GroupUsers[7]) -contains 31) -and (Test-Path -LiteralPath $state))
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: removes the person by the saved number, deletes the state file, recycles the 2 objects' ($r.Code -eq 0 -and -not (@($global:F.GroupUsers[7]) -contains 31) -and (@($global:F.GroupUsers[7]) -join ',') -eq '3,4' -and -not (Test-Path -LiteralPath $state) -and ($global:F.Recycled -join '|') -eq '90161Z Probe|90161Z Probe Files' -and $r.Out[-1] -eq 'PROBE Clean done: passed=3 failed=0') $r.Text
Test-That 'Clean: the Recycle Bin item IDs are not printed (R29a finding 7)' ($r.Text -notmatch 'RecycleBinItemId' -and $r.File -notmatch 'RecycleBinItemId' -and $r.Text -notmatch '[0-9a-f]{8}-[0-9a-f]{4}-') $r.Text
Test-That 'Clean: the other lists stay' (@($global:F.Lists | ForEach-Object { $_.Title }) -join '|' -eq 'Documents|Other probe list')
Test-That 'Clean: names the probe flows and leaves flows and solutions alone' ($r.Text -match 'NOTE the probe flows "90161Z T21 Probe Health r6" and "90161Z T21 Probe Button r6" are flows of the solution "90-161\.Z flows"; this script does not touch flows or solutions')
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean twice: nothing more removed, still exit 0' ($global:F.Recycled.Count -eq 2 -and $r.Code -eq 0 -and $r.Text -match 'no second person on file' -and $r.Out[-1] -eq 'PROBE Clean done: passed=3 failed=0')

New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS
$global:F.RemoveRefused = $true
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: when the removal is refused, it says so, keeps the state file and still recycles both objects' ($r.Code -eq 0 -and $r.Text -match 'c1-person FAIL the second person could not be removed' -and (Test-Path -LiteralPath $state) -and $global:F.Recycled.Count -eq 2 -and (@($global:F.GroupUsers[7]) -contains 31) -and $r.Out[-1] -eq 'PROBE Clean done: passed=2 failed=1') $r.Text
$global:F.RemoveRefused = $false
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean again: removes the person and deletes the state file' ($r.Code -eq 0 -and -not (@($global:F.GroupUsers[7]) -contains 31) -and -not (Test-Path -LiteralPath $state) -and $r.Text -match 'c1-person PASS')

New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = 'member.person@fake.example'; $global:F.GroupUsers[7] = @(3, 4, 32)
$null = Invoke-T21 'Person'
Remove-Item Env:T21_TEST_ADDRESS
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: a person who was a member before stays in the group' ($r.Text -match 'was a Visitors member before the test, so the person stays' -and (@($global:F.GroupUsers[7]) -contains 32) -and -not (Test-Path -LiteralPath $state))

New-Site; $null = Invoke-T21 'Make'
$r = Invoke-T21 'Clean' @{} 'first'; Note $r
Test-That 'Clean with -Label first writes its own result file name' ($r.Code -eq 0 -and $r.File -match 'PROBE Clean done')
# ---- Masking over everything printed and written ----
$all = $allText.ToString()
Test-That 'no output line or result file holds the fake site address, host, site name, DODID or any address' ($all.Length -gt 1000 -and $all -notmatch 'fakehost|FakeWing|tester01|example\.test|second\.person|member\.person|nobody@|@fake' -and $all -notmatch 'FAKE NAME') ''
# ---- Read r10 (PFM 19 Nov 26): T4 through list-level Contribute; the FAIL text no longer names way C ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'T4a' 12
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read r10: a row by a second person: T4 PASSED through list-level Contribute' ($r.Text -match 'T4 PASSED: a list form by a second person \(Visitors member\)=PASS \(rows=1; T4a rows=1' -and $r.Text -match '(?m)^RESULT T4 PASS$') $r.Text
New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = $fakeAddr; $null = Invoke-T21 'Person'; Remove-Item Env:T21_TEST_ADDRESS
$r = Invoke-T21 'Read' @{ PollSeconds = 1; WaitMinutes = 0.03 }; Note $r
Test-That 'Read r10 (R35): a second person but no add-a-row step: T4 NOT RUN, no T4 RESULT line' ($r.Text -match 'T4 NOT RUN: this round did not ask the second person to add a row' -and $r.Text -notmatch '(?m)^RESULT T4 ') $r.Text
# Ask (R36): no sign-in, T4Asked=yes in the state file (the other lines kept, a second run adds no second line), the link step.
$global:F.Connected = $false; $rests = $global:F.Rests
$r = Invoke-T21 'Ask'; Note $r
$stTxt = Get-Content -LiteralPath $state -Raw
Test-That 'Ask: no sign-in, T4Asked=yes added, the 3 numbers kept, link note' ($r.Code -eq 0 -and -not $global:F.Connected -and $global:F.Rests -eq $rests -and $stTxt -match '(?m)^T4Asked=yes\r?$' -and $stTxt -match '(?m)^UserId=31\r?$' -and $stTxt -match '(?m)^WasMember=no\r?$' -and $r.Text -match 'k2-link INFO the link of the new row form is on the clipboard=no \(test run\)' -and $r.Out[-1] -eq 'PROBE Ask done: passed=1 failed=0' -and $r.File -match 'PROBE Ask done') $r.Text
$null = Invoke-T21 'Ask'
Test-That 'Ask twice: one T4Asked line' (([regex]::Matches((Get-Content -LiteralPath $state -Raw), 'T4Asked=')).Count -eq 1)
$r = Invoke-T21 'Read' @{ PollSeconds = 1; WaitMinutes = 0.03 }; Note $r
Test-That 'Read r10: no row by the second person: T4 FAILED with a plain reason about Contribute, no way C' ($r.Text -match 'T4 FAILED: .*=FAIL \(rows=0' -and $r.Text -match 'does not hold Contribute on this list' -and $r.Text -notmatch 'way C|flow writes the row') $r.Text

Remove-Item -LiteralPath $state
$r = Invoke-T21 'Ask'; Note $r
Test-That 'Ask without a second person on file: FAIL, no state file written' ($r.Code -eq 0 -and $r.Text -match 'k1-asked FAIL no second person on file: run the part Person first' -and -not (Test-Path -LiteralPath $state) -and $r.Out[-1] -eq 'PROBE Ask done: passed=0 failed=1') $r.Text
# ---- A missing module ----
# The main file loads its modules by name from its own folder; one that is missing stops the part with a plain line.
$copy = Join-Path $work 'copy'
$null = New-Item -ItemType Directory -Path $copy -Force
Get-ChildItem -LiteralPath (Split-Path -Parent $script) -Filter '90161Z-T21-*-r11.ps1' | Where-Object { $_.Name -ne '90161Z-T21-read-r11.ps1' } | Copy-Item -Destination $copy
$out = & (Join-Path $copy '90161Z-T21-probe-r11.ps1') -Id 'tester01' -Part Run -NoPause -NoLaunch -TestDir $t21 *>&1 | ForEach-Object { [string]$_ }
Test-That 'a missing module: STOPPED with its file name, exit 1' ($LASTEXITCODE -eq 1 -and (@($out) -join "`n") -match 'STOPPED: MODULE missing: 90161Z-T21-read-r11\.ps1') (@($out) -join "`n")
# ---- The button flow ID (R34: written by scripts/build_flow_solution.py, no export file) ----
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $Root 'flow/solution/90161Z-T24-full-flows-r5.zip'
$za = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try { $rd = New-Object System.IO.StreamReader(@($za.Entries | Where-Object { $_.FullName -eq 'customizations.xml' })[0].Open()); $cust = $rd.ReadToEnd(); $rd.Dispose() } finally { $za.Dispose() }
$wfName = $(if ($buttonId -and $cust -match ('WorkflowId="\{' + $buttonId + '\}" Name="([^"]+)"')) { $Matches[1] } else { '' })
Test-That 'button flow ID: the look module names the workflow "90161Z T21 Probe Button r6" of the solution r3' ($wfName -eq '90161Z T21 Probe Button r6') ('id=' + $buttonId + ' name=' + $wfName)
# A look module whose block holds no ID: View fails with a plain line and makes no view (a copy, the block emptied).
$copy2 = Join-Path $work 'copy2'
$null = New-Item -ItemType Directory -Path $copy2 -Force
Get-ChildItem -LiteralPath (Split-Path -Parent $script) -Filter '90161Z-T21-*-r11.ps1' | Copy-Item -Destination $copy2
$lk = Join-Path $copy2 '90161Z-T21-look-r11.ps1'
Set-Content -LiteralPath $lk -Value ((Get-Content -LiteralPath $lk -Raw) -replace "(?m)^\`$ButtonFlowId = '[^']*'", "`$ButtonFlowId = ''") -Encoding UTF8
New-Site; $null = Invoke-T21 'Make'
$out = @(& (Join-Path $copy2 '90161Z-T21-probe-r11.ps1') -Id 'tester01' -Part View -NoPause -NoLaunch -TestDir $t21 *>&1 | ForEach-Object { [string]$_ })
$code = $LASTEXITCODE; $txt = $out -join "`n"
$ok = $code -eq 0 -and $txt -match 'VIEW FAILED: .*flow ID known to the script=no' -and $global:F.ViewsMade -eq 0
Test-That 'View with an empty button-flow-id block: VIEW FAILED, exit 0, no view made' ($ok -and $out[-1] -eq 'PROBE View done: passed=0 failed=2') $txt
# ---- NOW lines (R34, N1): before each action that takes time; not result lines ----
$parts = @($nowParts | Sort-Object -Unique) -join ','
Test-That 'NOW: every part that signs in or writes prints NOW lines' ($parts -eq 'Ask,Clean,Form,Look,Make,Office,Open,Person,Read,Run,View') $parts
Test-That 'NOW: no result file holds a NOW line' ($nowInFile.Count -eq 0) ($nowInFile -join ',')
$r = Invoke-T21 'Run'
$nowLines = @($r.Out | Where-Object { $_ -match '^NOW ' })
$plain = $nowLines.Count -ge 3 -and @($nowLines | Where-Object { $_ -notmatch '^NOW [A-Z][a-z]+ing ' }).Count -eq 0
$first = [array]::IndexOf($r.Out, @($r.Out | Where-Object { $_ -like 'TASK T21*' })[0])
$before = [array]::IndexOf($r.Out, $nowLines[-1]) -lt $first
$uncounted = $r.Out[-1] -eq 'PROBE Run done: passed=0 failed=0' -and $r.File -notmatch 'NOW '
Test-That 'NOW: plain present-tense text, printed before the result lines, not counted' ($plain -and $before -and $uncounted) ($nowLines -join "`n")
# ---- The script text (the main file and its modules) ----
$src = (@(Get-ChildItem -LiteralPath (Split-Path -Parent $script) -Filter '90161Z-T21-*-r11.ps1' | Sort-Object Name | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw })) -join "`n"
$nFiles = @(Get-ChildItem -LiteralPath (Split-Path -Parent $script) -Filter '90161Z-T21-*-r11.ps1').Count
Test-That 'script: the main file and its 6 modules are there (no export module, R34; office module, R35)' ($nFiles -eq 7 -and $src -notmatch 'Invoke-ExportPart|button-flow-r5')
Test-That 'script: no question in RADE (Read-Host only behind RADE_CONTRACT), no permanent delete, no result file for Open' ($src -match 'if \(-not \$NoPause -and -not \$env:RADE_CONTRACT\)' -and $src -notmatch 'Remove-PnPList[^\n]*(?<!-Recycle) -Force -ErrorAction Stop\s*$' -and $src -match "-ne 'Open'")
$bad = @(($src -split "`n") | Where-Object { $_ -match '\$(personAddr|loginName)\b' -and $_ -match 'Set-Content|Add-Content|Out-File|Write-Host|Write-Output|Write-Error|Write-Warning|Write-Verbose|\$lines\.Add|Add-Item|Add-Test|Tee-Object|Export-|Start-Transcript|\| Out-|>>|\bthrow\b' })
Test-That 'script: the second person''s address is never written to a file, a result line or an output stream' ($bad.Count -eq 0) ($bad -join "`n")
$mentions = @(($src -split "`n") | Where-Object { $_ -match '\$personAddr\b' -and $_ -notmatch '^\s*#' })
Test-That 'script: the address variable is used only to read, check, look up and add the person, then cleared' ($mentions.Count -ge 5 -and @($mentions | Where-Object { $_ -match 'ConvertTo-Json -Compress|EscapeDataString|Read-PersonAddress|-match|= \$null|loginName = ' }).Count -eq $mentions.Count) ($mentions -join "`n")
Test-That 'script: no e-mail, name or site path in the state file code (numbers and flags only)' ($src -match '''UserId='' \+ \$userId' -and $src -match '''GroupId='' \+ \$visitorId' -and $src -match '''WasMember=''')
Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T21 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
