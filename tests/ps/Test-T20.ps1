# Tests scripts/gov/90161Z-T20-provision-lists-r1.ps1 against the strict fake in tests/fake-pnp (pwsh 7, cloud only).
# Proves the logic: order, list ids, lookup ids, skip-what-exists, the checks and the masking. The real service is
# proved only by a gov device round. Last line: "T20 pass=N fail=0".
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T20TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T20TEST FAIL ' + $Name + ' ' + $Detail) }
}
$env:PSModulePath = (Join-Path $Root 'tests/fake-pnp') + [IO.Path]::PathSeparator + $env:PSModulePath
Import-Module PnP.PowerShell -RequiredVersion 1.12.0 -DisableNameChecking
$work = Join-Path ([IO.Path]::GetTempPath()) ('t20-' + [guid]::NewGuid().ToString('N'))
$t20 = Join-Path $work 'T20'
$null = New-Item -ItemType Directory -Path $t20 -Force
Copy-Item -LiteralPath (Join-Path $Root 'flow/provisioning-payload.json') -Destination (Join-Path $t20 'provisioning-payload.json')
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T20-provision-lists-r1.ps1'
# Run the T20 script against the fake site in one mode (Check, DryRun or empty for a real run). Returns a hashtable with Code (exit code), Out (lines) and Text (joined).
function Invoke-T20([string]$Mode) {
  $sw = @{}; if ($Mode) { $sw[$Mode] = $true }
  $global:LASTEXITCODE = 0
  $out = & $script -Id 'tester01' -NoPause -TestDir $t20 @sw *>&1 | ForEach-Object { [string]$_ }
  return @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n") }
}
# List the fake lists whose folder name starts with PFM (the ones the script makes). Takes nothing; returns an array.
function Get-Ours { return @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -like 'PFM*' }) }

New-FakeSite
$r = Invoke-T20 'Check'
Test-That 'clean site: the check passes' ($r.Code -eq 0 -and $r.Text -match 'CLEAN check done, items with problems=0') $r.Text
Test-That 'check writes nothing' ($global:FakeSP.Posts -eq 0)
Test-That 'check result file' (Test-Path -LiteralPath (Join-Path $t20 '90161Z-T20-clean-check-r1.txt'))

$r = Invoke-T20 'DryRun'
Test-That 'dry run: counts' ($r.Text -match 'DRYRUN would create lists=12 fields=199 views=18 view-column requests=115 rows=93; set: updates=21 permissions=2') $r.Text
Test-That 'dry run writes nothing' ($global:FakeSP.Posts -eq 0 -and (Get-Ours).Count -eq 0)

$r = Invoke-T20 ''
$ours = Get-Ours
Test-That 'create: exit 0 and no problems' ($r.Code -eq 0 -and $r.Text -match 'PROVISION done, items with problems=0') $r.Text
Test-That 'create: 12 list lines pass' (@($r.Out | Where-Object { $_ -match '^ITEM L\d\d-PFM\w+ PASS' }).Count -eq 12)
Test-That 'create: counts line' ($r.Text -match 'CREATED lists=12 fields=199 views=18 view-column requests=115 rows=93')
Test-That 'site: 12 lists with display titles' ($ours.Count -eq 12 -and @($ours | Where-Object { $_.Title -like 'PFM *' }).Count -eq 12)
Test-That 'site: 199 columns' ((($ours | ForEach-Object { $_.FieldList.Count - 6 }) | Measure-Object -Sum).Sum -eq 199)
Test-That 'site: 18 views' ((($ours | ForEach-Object { $_.ViewList.Count }) | Measure-Object -Sum).Sum -eq 18)
Test-That 'site: 93 rows' ((($ours | ForEach-Object { $_.Items.Count }) | Measure-Object -Sum).Sum -eq 93)
Test-That 'site: every view has columns' (@($ours | ForEach-Object { $_.ViewList } | Where-Object { $_.Columns.Count -lt 1 }).Count -eq 0)
$sec = @($ours | Where-Object { $_.ReadSecurity -eq 1 -and $_.WriteSecurity -eq 2 } | ForEach-Object { $_.Title } | Sort-Object)
Test-That 'site: edit own rows on 2 lists' (($sec -join '|') -eq 'PFM Endorsements|PFM Publications') ($sec -join '|')
$log = @($ours | Where-Object { $_.RootFolder.Name -eq 'PFMActivityLog' })[0]
Test-That 'site: Created is indexed on the activity log' ([bool]@($log.FieldList | Where-Object { $_.InternalName -eq 'Created' })[0].Indexed)
Test-That 'site: Title column renamed' (@(@($ours | Where-Object { $_.RootFolder.Name -eq 'PFMOffices' })[0].FieldList | Where-Object { $_.InternalName -eq 'Title' })[0].Title -eq 'Office')
Test-That 'site: versioning on' (@($ours | Where-Object { -not $_.EnableVersioning }).Count -eq 0)
$file = Get-Content -LiteralPath (Join-Path $t20 '90161Z-T20-provision-lists-r1.txt') -Raw
Test-That 'result file: no site address, host or id' ($file -notmatch 'fakehost|FakeWing|tester01|[0-9a-f]{8}-[0-9a-f]{4}-')
# Every POST body the script sent equals the payload's body for that request, in the payload's order (list ids aside).
$pl = Get-Content -LiteralPath (Join-Path $t20 'provisioning-payload.json') -Raw | ConvertFrom-Json
$want = @(@($pl.lists) + @($pl.fields) + @($pl.rows) | ForEach-Object { (($_.body | ConvertTo-Json -Depth 20 -Compress) -replace '\{__\w+_ID__\}', '{G}') })
$got = @($global:FakeSP.Sent | ForEach-Object { ((($_ | ConvertFrom-Json) | ConvertTo-Json -Depth 20 -Compress) -replace '\{[0-9a-f]{8}-[0-9a-f-]{27}\}', '{G}') })
$diff = @(0..([Math]::Max($want.Count, $got.Count) - 1) | Where-Object { $want[$_] -cne $got[$_] })
Test-That 'every POST body equals the payload body, in order' ($want.Count -eq 437 -and $got.Count -eq 437 -and $diff.Count -eq 0) ('want ' + $want.Count + ' got ' + $got.Count + ' first diff at ' + $(if ($diff.Count) { $diff[0] } else { '-' }))

$posts = $global:FakeSP.Posts
$r = Invoke-T20 ''
Test-That 'second run: creates nothing and passes' ($r.Code -eq 0 -and $r.Text -match 'CREATED lists=0 fields=0 views=0 view-column requests=115 rows=0' -and $r.Text -match 'items with problems=0') $r.Text
Test-That 'second run: only the 115 view-column requests are sent again' ($global:FakeSP.Posts -eq $posts + 115)
Test-That 'second run: same site (199 columns, 18 views with columns, 93 rows)' (((Get-Ours | ForEach-Object { $_.FieldList.Count - 6 }) | Measure-Object -Sum).Sum -eq 199 -and ((Get-Ours | ForEach-Object { $_.Items.Count }) | Measure-Object -Sum).Sum -eq 93 -and @(Get-Ours | ForEach-Object { $_.ViewList } | Where-Object { $_.Columns.Count -lt 1 }).Count -eq 0)

$r = Invoke-T20 'Check'
Test-That 'provisioned site: the check fails with 12 lists' ($r.Code -eq 1 -and $r.Text -match 'ITEM b-lists FAIL still on the site \(12\)') $r.Text

# A run that stopped half way: one list gone, one column and one view gone from another list.
$gone = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMWaivers' })[0]
$global:FakeSP.Lists.Remove($gone)
$pub = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMProductIndex' })[0]
$dropField = @($pub.FieldList | Where-Object { $_.InternalName -notin 'Title', 'Created', 'Modified', 'Author', 'Editor', 'ID' })[-1]
$pub.FieldList.Remove($dropField)
$pub.ViewList.RemoveAt(0)
$r = Invoke-T20 ''
Test-That 'repair run: fills only what is missing and passes' ($r.Code -eq 0 -and $r.Text -match 'CREATED lists=1 ' -and $r.Text -match ' views=1 ' -and $r.Text -match 'items with problems=0') $r.Text
Test-That 'repair run: 12 lists again' ((Get-Ours).Count -eq 12)

# Leftovers the check must name.
$null = Add-FakeList '90-161.Z' 101 '90-161.Z'
$docs = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'Shared Documents' })[0]
$null = $docs.Files.Add('90161Z-T11-rights-result-r5.json'); $null = $docs.Files.Add('notes.docx')
$global:FakeSP.Groups = @('PFM Rights Probe TEST', 'PFM Somebody Else', 'Members')
$r = Invoke-T20 'Check'
Test-That 'check names the library, the file and the test group' ($r.Text -match 'ITEM c-library FAIL' -and $r.Text -match 'ITEM d-files FAIL result files still in Documents \(1\): 90161Z-T11-rights-result-r5\.json' -and $r.Text -match 'ITEM e-groups FAIL') $r.Text
Test-That 'check never prints another group name' ($r.Text -notmatch 'Somebody Else|notes\.docx')

# A run that the service stops at ANY request is finished by the next run: stop after 20, 300, 351 and 400 requests
# (inside the lists, between a view and its columns, and inside the seed rows).
foreach ($stopAt in 20, 300, 351, 400) {
  New-FakeSite
  $global:FakeSP.FailAfter = $stopAt
  $r1 = Invoke-T20 ''
  $global:FakeSP.FailAfter = 0
  $r2 = Invoke-T20 ''
  $o = Get-Ours
  Test-That ('stopped after ' + $stopAt + ' requests: the next run completes the site') ($r1.Code -eq 1 -and $r2.Code -eq 0 -and $r2.Text -match 'items with problems=0' -and $o.Count -eq 12 -and (($o | ForEach-Object { $_.Items.Count }) | Measure-Object -Sum).Sum -eq 93 -and (($o | ForEach-Object { $_.FieldList.Count - 6 }) | Measure-Object -Sum).Sum -eq 199 -and @($o | ForEach-Object { $_.ViewList } | Where-Object { $_.Columns.Count -lt 1 }).Count -eq 0) ($r1.Out[-1] + ' / ' + $r2.Out[-1])
}

# A list a person made and titled like one of ours is never changed, and the check does not ask to delete it.
New-FakeSite
$mine = Add-FakeList 'PFM Settings' 100 'My own list'
$other = Add-FakeList 'PFM budget notes' 100 'PFM budget notes'
$r = Invoke-T20 'Check'
Test-That 'check: a person''s own list with a title the install needs is a title clash, not ours to delete' ($r.Code -eq 1 -and $r.Text -match 'ITEM b-lists PASS' -and $r.Text -match 'ITEM b2-title-in-use FAIL .*\(1\): PFM Settings\. .*Rename that list or delete it' -and $r.Text -notmatch 'budget') $r.Text
$global:FakeSP.Lists.Remove($mine)
$r = Invoke-T20 'Check'
Test-That 'check: other lists that start with PFM are a count only' ($r.Code -eq 0 -and $r.Text -match 'other lists whose title starts with PFM: 1' -and $r.Text -notmatch 'budget') $r.Text
$mine2 = Add-FakeList 'PFMOffices title only' 100 'Some folder'
$mine2.Title = 'PFMOffices'
$r = Invoke-T20 ''
Test-That 'create: a list that only has our title is not touched' ($mine2.FieldList.Count -eq 6 -and $mine2.Items.Count -eq 0) ''

# A request the service refuses stops the run with a line the person can send.
New-FakeSite
$global:FakeSP.FailOn = '/views'
$r = Invoke-T20 ''
Test-That 'a refused request: STOPPED and exit 1' ($r.Code -eq 1 -and @($r.Out | Where-Object { $_ -match '^STOPPED: ' }).Count -eq 1) $r.Text
Test-That 'a refused request: the message is masked' ($r.Text -match '<SITE>' -and $r.Text -notmatch 'fakehost|FakeWing|[0-9a-f]{8}-[0-9a-f]{4}-') $r.Text
$global:FakeSP.FailOn = ''
$r = Invoke-T20 ''
Test-That 'after a stop: the next run finishes the site' ($r.Code -eq 0 -and $r.Text -match 'items with problems=0' -and (Get-Ours).Count -eq 12) $r.Text

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T20 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
