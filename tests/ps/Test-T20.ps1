# Tests scripts/gov/90161Z-T20-provision-lists-r3.ps1 (with its part 90161Z-T20-access-r3.ps1) and scripts/gov/90161Z-T19-list-update-r5.ps1 against the strict fake in
# tests/fake-pnp (pwsh 7, cloud only). Proves the logic: order, list ids, lookup ids, skip-what-exists, the PFM Office level
# (F2 A), the per-list access read-back (R34 plan, open point 12), the T19 choices (S3 A: T-0) and the suspense setting (15), the checks and the masking. The real service is proved only by a gov device round.
# Last line: "T20 pass=N fail=0".
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
$script = Join-Path $Root 'scripts/gov/90161Z-T20-provision-lists-r3.ps1'
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
Test-That 'check result file' (Test-Path -LiteralPath (Join-Path $t20 '90161Z-T20-clean-check-r3.txt'))

$r = Invoke-T20 'DryRun'
Test-That 'dry run: counts' ($r.Text -match 'DRYRUN would create lists=12 fields=199 views=18 view-column requests=115 rows=93; set: updates=21 permissions=2') $r.Text
Test-That 'dry run writes nothing' ($global:FakeSP.Posts -eq 0 -and (Get-Ours).Count -eq 0)
Test-That 'dry run: PFM Office would get the group, the level and the role (F2 A)' ($r.Text -match 'DRYRUN would create for PFM Office: group=1 level=1 level given to the group=1' -and @($global:FakeSP.Groups).Count -eq 0) $r.Text

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
# F2 A (PFM 19 Nov 26): the group PFM Office holds a level with the bits of Edit plus Override List Behaviors (0x100) on the site.
$lv = @($global:FakeSP.Levels | Where-Object { $_['Name'] -eq 'PFM Office Edit All Items' })
$gi = [array]::IndexOf(@($global:FakeSP.Groups), 'PFM Office') + 1
$okLevel = $lv.Count -eq 1 -and $lv[0].BasePermissions.Low -eq [string](1011030767 -bor 0x100) -and $lv[0].BasePermissions.High -eq '432'
Test-That 'create: group PFM Office, the level (Edit + Override List Behaviors) and its role on the site, read back' ($okLevel -and $gi -gt 0 -and @($global:FakeSP.WebRoles[$gi]) -contains $lv[0].Id -and $r.Text -match 'CREATED for PFM Office: group=1 level=1 level given to the group=1' -and $r.Text -match 'ITEM P01-pfm-office PASS') $r.Text
$file = Get-Content -LiteralPath (Join-Path $t20 '90161Z-T20-provision-lists-r3.txt') -Raw
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
Test-That 'second run: PFM Office: nothing made again, read back PASS' ($r.Text -match 'CREATED for PFM Office: group=0 level=0 level given to the group=0' -and $r.Text -match 'ITEM P01-pfm-office PASS' -and @($global:FakeSP.Levels).Count -eq 5) $r.Text
Test-That 'second run: same site (199 columns, 18 views with columns, 93 rows)' (((Get-Ours | ForEach-Object { $_.FieldList.Count - 6 }) | Measure-Object -Sum).Sum -eq 199 -and ((Get-Ours | ForEach-Object { $_.Items.Count }) | Measure-Object -Sum).Sum -eq 93 -and @(Get-Ours | ForEach-Object { $_.ViewList } | Where-Object { $_.Columns.Count -lt 1 }).Count -eq 0)

# ---- T19 r4 on the provisioned fake site (S3 A, PFM 19 Nov 26: the tier T-0) ----
$t19 = Join-Path $work 'T19'
$null = New-Item -ItemType Directory -Path $t19 -Force
$script19 = Join-Path $Root 'scripts/gov/90161Z-T19-list-update-r5.ps1'
# Run the T19 script against the fake site in one mode (Check, PlanOnly or empty for a real run). Returns Code, Out, Text and File.
function Invoke-T19([string]$Mode) {
  $sw = @{}; if ($Mode) { $sw[$Mode] = $true }
  $global:LASTEXITCODE = 0
  $out = & $script19 -Id 'tester01' -NoPause -TestDir $t19 @sw *>&1 | ForEach-Object { [string]$_ }
  $f = Join-Path $t19 $(if ($Mode -eq 'Check') { '90161Z-T19-list-check-r5.txt' } else { '90161Z-T19-list-update-r5.txt' })
  return @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $f) { Get-Content -LiteralPath $f -Raw } else { '' }) }
}
# The Tier column of the fake PFM Waivers list (its data holds the choices).
function Get-TierColumn { return @(@($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMWaivers' })[0].FieldList | Where-Object { $_.InternalName -eq 'Tier' })[0] }
$r = Invoke-T19 'PlanOnly'
Test-That 'T19 plan: 6 items, Tier with T-0 first, no sign-in' ($r.Code -eq 0 -and $r.Text -match 'PLAN 5-Tier choices in PFM Waivers: T-0, T-1, T-2, T-3, Non-Tiered' -and $r.Out[-1] -eq 'PLAN columns=3 choice columns=2 settings=1 steps=1' -and $r.Text -match 'PLAN 7-stage6-target step 6 = 20 in PFM Process Steps') $r.Text
Test-That 'T20 built a new site with T-0 already (the payload)' (((Get-TierColumn).Data.Choices -join ',') -eq 'T-0,T-1,T-2,T-3,Non-Tiered')
$r = Invoke-T19 'Check'
Test-That 'T19 check on a new site: nothing to change' ($r.Code -eq 0 -and $r.Text -match 'LISTCHECK done, changes a run would make=0, items with problems=0') $r.Text
# An older site: no T-0, a choice a person added, one column missing, another suspense value.
(Get-TierColumn).Data.Choices = [string[]]@('T-1', 'T-2', 'T-3', 'Non-Tiered', 'Waived Locally')
$pubs = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMPublications' })[0]
$pubs.FieldList.Remove(@($pubs.FieldList | Where-Object { $_.InternalName -eq 'HeldSince' })[0])
$setRow = @(@($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMSettings' })[0].Items | Where-Object { $_.Title -eq 'CoordinationSuspenseBusinessDays' })[0]
$setRow.SettingValue = '20'
$r = Invoke-T19 'Check'
$same = ((Get-TierColumn).Data.Choices -join ',') -eq 'T-1,T-2,T-3,Non-Tiered,Waived Locally' -and $setRow.SettingValue -eq '20'
Test-That 'T19 check on an older site: names the 3 changes and changes nothing' ($r.Code -eq 0 -and $same -and $r.Text -match 'ITEM 5-Tier INFO a run would add the choices T-0 to PFM Waivers' -and $r.Text -match 'changes a run would make=3' -and $r.File -match 'LISTCHECK done') $r.Text
$r = Invoke-T19 ''
$tier = ((Get-TierColumn).Data.Choices -join ',')
Test-That 'T19 run: T-0 added first, the other choices kept in order' ($r.Code -eq 0 -and $tier -eq 'T-0,T-1,T-2,T-3,Non-Tiered,Waived Locally' -and $r.Text -match 'ITEM 5-Tier PASS added choices: T-0 \(choices now 6\)') ($tier + "`n" + $r.Text)
$seedNotes = @((Get-Content -LiteralPath (Join-Path $Root 'schemas/lists/PFMSettings.json') -Raw | ConvertFrom-Json).seed | Where-Object { $_.Title -eq 'CoordinationSuspenseBusinessDays' })[0].SettingNotes
Test-That 'T19 run: the column and the setting (20 becomes 15, the notes of the schema seed row) are set' (@($pubs.FieldList | Where-Object { $_.InternalName -eq 'HeldSince' }).Count -eq 1 -and $setRow.SettingValue -eq '15' -and $r.Text -match 'ITEM 6-suspense-setting PASS set to 15 \(was 20\)' -and $setRow.SettingNotes -ceq $seedNotes -and $r.Text -match 'LISTUPDATE done, changes made=3, items with problems=0') $r.Text
Test-That 'T19 run: NOW lines on the screen only, result file masked' (@($r.Out | Where-Object { $_ -match '^NOW [A-Z][a-z]+ing ' }).Count -ge 5 -and $r.File -notmatch '(?m)^NOW ' -and $r.File -match 'LISTUPDATE done' -and $r.File -notmatch 'fakehost|FakeWing|tester01') $r.Text
$r = Invoke-T19 ''
Test-That 'T19 second run: changes nothing' ($r.Code -eq 0 -and $r.Text -match 'LISTUPDATE done, changes made=0, items with problems=0' -and ((Get-TierColumn).Data.Choices -join ',') -eq $tier) $r.Text
# T19 r5, item 6 (PFM 19 Nov 26: 15 business days): an empty value becomes 15; any other value (17) is left and reported; 15 stays.
$setRow.SettingValue = '17'
$r = Invoke-T19 ''
Test-That 'T19 setting: 17 is left as it is and reported' ($r.Code -eq 0 -and $setRow.SettingValue -eq '17' -and $r.Text -match 'ITEM 6-suspense-setting INFO kept, 17' -and $r.Text -match 'changes made=0, items with problems=0') $r.Text
$r = Invoke-T19 'Check'
Test-That 'T19 setting check: 17 changes nothing and is reported' ($r.Code -eq 0 -and $setRow.SettingValue -eq '17' -and $r.Text -match 'ITEM 6-suspense-setting INFO kept, 17') $r.Text
$setRow.SettingValue = ''
$r = Invoke-T19 ''
Test-That 'T19 setting: an empty value is set to 15' ($r.Code -eq 0 -and $setRow.SettingValue -eq '15' -and $r.Text -match 'ITEM 6-suspense-setting PASS set to 15') $r.Text
$r = Invoke-T19 ''
Test-That 'T19 setting: 15 is present and stays (idempotent)' ($r.Code -eq 0 -and $setRow.SettingValue -eq '15' -and $r.Text -match 'ITEM 6-suspense-setting PASS present, 15') $r.Text
# Stage 6 target (PFM 19 Nov 26: 15 + 5 = 20 business days): 25 moves to 20, any other value stays.
$stepRow = @(@($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMProcessSteps' })[0].Items | Where-Object { [string]$_.StepNumber -eq '6' })[0]
Test-That 'T19 stage 6: a new site has the seed target 20' ([string]$stepRow.TargetBusinessDays -eq '20') ([string]$stepRow.TargetBusinessDays)
$stepRow.TargetBusinessDays = 25
$r = Invoke-T19 ''
Test-That 'T19 stage 6: 25 becomes 20' ($r.Code -eq 0 -and [string]$stepRow.TargetBusinessDays -eq '20' -and $r.Text -match 'ITEM 7-stage6-target PASS set to 20 \(was 25\)') $r.Text
$stepRow.TargetBusinessDays = 23
$r = Invoke-T19 ''
Test-That 'T19 stage 6: 23 is left as it is and reported' ($r.Code -eq 0 -and [string]$stepRow.TargetBusinessDays -eq '23' -and $r.Text -match 'ITEM 7-stage6-target INFO kept, 23') $r.Text
$stepRow.TargetBusinessDays = 20
# One value: the T19 r5 setting (new value 15, old value 20), the schema seed row and the default of F03 r7 agree (PFM 19 Nov 26).
$t19Text = Get-Content -LiteralPath $script19 -Raw
$f03Text = Get-Content -LiteralPath (Join-Path $Root 'flow/solution/defs/90161Z-F03-suspense-reminders-r7.json') -Raw
$seedValue = @((Get-Content -LiteralPath (Join-Path $Root 'schemas/lists/PFMSettings.json') -Raw | ConvertFrom-Json).seed | Where-Object { $_.Title -eq 'CoordinationSuspenseBusinessDays' })[0].SettingValue
Test-That 'T19 setting, schema seed row and F03 r7 default all say 15 (T19 moves only 20)' ($seedValue -eq '15' -and $t19Text -match "Value = '15'; Old = '20'" -and $f03Text -match "'15', trim\(" -and $f03Text -notmatch "'20', trim\(")

# ---- PFM Office edge cases (F2 A): a level of that name that lacks Override List Behaviors is reported, never changed ----
# The fake keeps levels as hashtables and changes them with Set-FakeLevelBits (Windows PowerShell 5.1: a property set on a
# [pscustomobject] made inside a method call did not reach the JSON the script read). Both JSON forms: strings (as SharePoint
# writes SP.BasePermissions) and numbers.
Set-FakeLevelBits 'PFM Office Edit All Items' '432' '1011030767'
$r = Invoke-T20 ''
Test-That 'a level named PFM Office Edit All Items without Override List Behaviors: FAIL, not changed' ($r.Code -eq 1 -and $r.Text -match 'ITEM P01-pfm-office FAIL the level lacks a permission of Edit or Override List Behaviors' -and $lv[0].BasePermissions.Low -eq '1011030767') (@($r.Out) -join ' | ')
$global:FakeSP.BitsAsNumbers = $true
$r = Invoke-T20 ''
Test-That 'the same level, its bits written as JSON numbers: FAIL as well' ($r.Code -eq 1 -and $r.Text -match 'ITEM P01-pfm-office FAIL the level lacks a permission of Edit or Override List Behaviors') (@($r.Out) -join ' | ')
Set-FakeLevelBits 'PFM Office Edit All Items' 432 (1011030767 -bor 0x100)
$r = Invoke-T20 ''
Test-That 'a level with Edit plus Override List Behaviors, bits as JSON numbers: PASS' ($r.Code -eq 0 -and $r.Text -match 'ITEM P01-pfm-office PASS') (@($r.Out) -join ' | ')
$global:FakeSP.BitsAsNumbers = $false
Set-FakeLevelBits 'PFM Office Edit All Items' '432' ([string](1011030767 -bor 0x100))
$r = Invoke-T20 ''
Test-That 'the same level, bits as JSON strings again: PASS' ($r.Code -eq 0 -and $r.Text -match 'ITEM P01-pfm-office PASS') (@($r.Out) -join ' | ')

# Review of PR 173: with the level there and NO Edit level on the site, the read-back cannot compare the bits: FAIL, never PASS.
$editLv = @($global:FakeSP.Levels | Where-Object { [int]$_['RoleTypeKind'] -eq 6 })[0]; $global:FakeSP.Levels.Remove($editLv)
$r = Invoke-T20 ''
Test-That 'the level is there but the site has no Edit level: FAIL' ($r.Code -eq 1 -and $r.Text -match 'ITEM P01-pfm-office FAIL the site has no Edit level to compare') (@($r.Out) -join ' | ')
$null = $global:FakeSP.Levels.Add($editLv)

# R34 plan, open point 12: each of the 12 lists inherits from the site, or has its own permissions and the group holds the level.
$r = Invoke-T20 ''
Test-That 'list access: all 12 lists inherit from the site: PASS with the counts' ($r.Code -eq 0 -and $r.Text -match 'ITEM P02-list-access PASS 12 lists: 12 inherit from the site, 0 have own permissions') (@($r.Out) -join ' | ')
$offId = [int]@($global:FakeSP.Levels | Where-Object { $_['Name'] -eq 'PFM Office Edit All Items' })[0]['Id']
$readId = [int]@($global:FakeSP.Levels | Where-Object { $_['Name'] -eq 'Read' })[0]['Id']
$accPub = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMPublications' })[0]
$accEnd = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMEndorsements' })[0]
$accPub.HasUniqueRoleAssignments = $true; $accPub.ListRoles[$gi] = @($offId, $readId)
$r = Invoke-T20 ''
Test-That 'list access: own permissions and the group holds the level on the list: PASS' ($r.Code -eq 0 -and $r.Text -match 'ITEM P02-list-access PASS 12 lists: 11 inherit from the site, 1 have own permissions') (@($r.Out) -join ' | ')
$accEnd.HasUniqueRoleAssignments = $true
$r = Invoke-T20 ''
Test-That 'list access: own permissions and no role for the group: FAIL naming that list only' ($r.Code -eq 1 -and $r.Text -match '(?m)ITEM P02-list-access FAIL lists that fail \(1 of 12\): PFM Endorsements has its own permissions and the group PFM Office does not hold the level on it\r?$' -and $r.Text -notmatch 'FAIL lists that fail.*PFM Publications') (@($r.Out) -join ' | ')
$accEnd.ListRoles[$gi] = @($readId)
$accPub.ListRoles[$gi] = @($readId)
$r = Invoke-T20 ''
Test-That 'list access: the group holds another level only: FAIL naming both lists' ($r.Code -eq 1 -and $r.Text -match 'ITEM P02-list-access FAIL lists that fail \(2 of 12\): .*PFM Publications.*PFM Endorsements|ITEM P02-list-access FAIL lists that fail \(2 of 12\): .*PFM Endorsements.*PFM Publications') (@($r.Out) -join ' | ')
$accEnd.ListRoles[$gi] = @($offId); $accPub.ListRoles[$gi] = @($offId)
$r = Invoke-T20 ''
Test-That 'list access: the level given on both lists: PASS again, nothing written' ($r.Code -eq 0 -and $r.Text -match 'ITEM P02-list-access PASS 12 lists: 10 inherit from the site, 2 have own permissions') (@($r.Out) -join ' | ')
$accPub.HasUniqueRoleAssignments = $false; $accEnd.HasUniqueRoleAssignments = $false

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
$global:FakeSP.Groups = @('PFM Office', 'PFM Somebody Else')
$r = Invoke-T20 'Check'
Test-That 'check: the group PFM Office is named and kept, not counted with the other PFM groups' ($r.Text -match 'other groups whose name starts with PFM: 1, not made by 90-161\.Z; the group PFM Office is there=yes, kept') $r.Text

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

# PFM Office (F2 A): a group a person made before is used as it is; a site without an Edit level stops after the lists.
New-FakeSite
$global:FakeSP.Groups = @('Members', 'PFM Office')
$r = Invoke-T20 ''
Test-That 'a group PFM Office that is there: used, only the level and its role are made' ($r.Code -eq 0 -and $r.Text -match 'CREATED for PFM Office: group=0 level=1 level given to the group=1' -and @($global:FakeSP.WebRoles[2]).Count -eq 1 -and @($global:FakeSP.Groups).Count -eq 2) $r.Text
New-FakeSite
$global:FakeSP.Levels.RemoveAt(1)
$r = Invoke-T20 ''
Test-That 'a site without an Edit level: STOPPED after the lists, no level made' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LEVEL Edit not found on the site' -and (Get-Ours).Count -eq 12 -and @($global:FakeSP.Levels).Count -eq 3) $r.Text

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T20 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
