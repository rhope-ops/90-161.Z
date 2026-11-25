# Tests scripts/gov/90161Z-T20-provision-lists-r4.ps1 (with its part 90161Z-T20-access-r4.ps1) and scripts/gov/90161Z-T19-list-update-r6.ps1 against the strict fake in
# tests/fake-pnp (pwsh 7, cloud only). Proves the logic: order, list ids, lookup ids, skip-what-exists, the PFM Office level
# (F2 A), the per-list access read-back (R34 plan, open point 12), Contribute for the Visitors group on the intake lists (r4, PFM 19 Nov 26), the T19 choices (S3 A: T-0) and the suspense setting (15), the MADE lines (RADE engine-v40: one for each item that a run made, none otherwise), the checks and the masking. The real service is proved only by a gov device round.
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
$script = Join-Path $Root 'scripts/gov/90161Z-T20-provision-lists-r4.ps1'
# Run the T20 script against the fake site in one mode (Check, DryRun or empty for a real run). Returns a hashtable with Code (exit code), Out (lines) and Text (joined).
function Invoke-T20([string]$Mode) {
  $sw = @{}; if ($Mode) { $sw[$Mode] = $true }
  $global:LASTEXITCODE = 0
  $out = & $script -Id 'tester01' -NoPause -TestDir $t20 @sw *>&1 | ForEach-Object { [string]$_ }
  return @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n") }
}
# List the fake lists whose folder name starts with PFM (the ones the script makes). Takes nothing; returns an array.
function Get-Ours { return @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -like 'PFM*' }) }

# r4: the shared fake has no Visitors group, no breakroleinheritance and no list role route, so this test adds them in front of the
# fake module's own Invoke-PnPSPRestMethod, inside the module (the script imports the module again, so a function outside it would not be found).
$fakeModule = Get-Module PnP.PowerShell
$visitorsId = 9000   # the Id the fake gives the Visitors group (set inside the module block below)
# The test's own name for it: always the module's version above, whatever scope imported the module last.
function New-FakeSite { & $fakeModule { New-FakeSite } }
& $fakeModule {
  $script:origNewSite = ${function:New-FakeSite}
  # A new fake site with an associated Visitors group (Id 9000) that holds Read on the site. Takes nothing; returns nothing.
  function script:New-FakeSite {
    & $script:origNewSite
    $global:FakeSP.VisitorId = 9000
    $readLevel = @($global:FakeSP.Levels | Where-Object { $_['Name'] -eq 'Read' })[0]['Id']
    $global:FakeSP.WebRoles[9000] = @($readLevel)
  }
  $script:origRest = ${function:Invoke-PnPSPRestMethod}
  <#
  .SYNOPSIS
    The fake REST call with the three routes of T20 r4 added: the Visitors group, breaking inheritance (the site's roles are
    copied) and a role on a list. Every other request goes on to the fake module's own function.
  .PARAMETER Method
    Get or Post.
  .PARAMETER Url
    The full request address (site address plus _api/...).
  .PARAMETER Content
    The JSON body of a Post.
  .PARAMETER ContentType
    The content type of a Post.
  .PARAMETER Accept
    The accepted answer type.
  .PARAMETER Raw
    Switch: the answer as text.
  .OUTPUTS
    System.String. The answer text; it throws as the service would.
  #>
  function script:Invoke-PnPSPRestMethod {
    [CmdletBinding()]
    param([string]$Method = 'Get', [string]$Url, $Content, [string]$ContentType = 'application/json', [string]$Accept = 'application/json;odata=nometadata', [switch]$Raw)
    $path = ''
    if ($global:FakeSP.Url -and $Url.StartsWith($global:FakeSP.Url.TrimEnd('/') + '/_api/')) {
      $path = $Url.Substring($global:FakeSP.Url.TrimEnd('/').Length + 6); $q = $path.IndexOf('?'); if ($q -ge 0) { $path = $path.Substring(0, $q) }
    }
    if ($Method -eq 'Get' -and $path -eq 'web/associatedvisitorgroup') {
      if (-not $global:FakeSP.VisitorId) { throw 'FAKE 404: the site has no associated Visitors group' }
      return (@{ Id = [int]$global:FakeSP.VisitorId } | ConvertTo-Json -Compress)
    }
    if ($Method -eq 'Post' -and $path -match "^web/lists\(guid'([^']+)'\)/(breakroleinheritance\(copyRoleAssignments=true,clearSubscopes=false\)|roleassignments/addroleassignment\(principalid=(\d+),roledefid=(\d+)\))$") {
      $l = @($global:FakeSP.Lists | Where-Object { $_.Id -eq $Matches[1] })[0]
      if (-not $l) { throw 'FAKE 404: no such list' }
      if ($Matches[2] -like 'breakroleinheritance*') {
        if ($l.HasUniqueRoleAssignments) { throw 'FAKE 500: the list has its own permissions already' }
        $l.HasUniqueRoleAssignments = $true; $l.ListRoles = @{}
        foreach ($key in @($global:FakeSP.WebRoles.Keys)) { $l.ListRoles[[int]$key] = @($global:FakeSP.WebRoles[$key]) }
        $global:FakeSP.BreakCalls++
        return ''
      }
      $p = [int]$Matches[3]; $d = [int]$Matches[4]
      if (-not $l.HasUniqueRoleAssignments) { throw 'FAKE 500: the list inherits: break the inheritance first' }
      if (@($l.ListRoles[$p]) -contains $d) { throw 'FAKE 500: the group holds that level on the list already' }
      $l.ListRoles[$p] = @(@($l.ListRoles[$p]) | Where-Object { $_ }) + $d
      $global:FakeSP.GrantCalls++
      return ''
    }
    return (& $script:origRest @PSBoundParameters)
  }
}
# The level Ids of Read and Contribute on the fake site (the fake gives them fixed numbers).
function Get-FakeLevelId([string]$Name) { return [int]@($global:FakeSP.Levels | Where-Object { $_['Name'] -eq $Name })[0]['Id'] }
# The own-name table of T27 (what Uninstall removes) and the line that RADE engine-v40 reads (case sensitive).
. (Join-Path $Root 'scripts/gov/90161Z-T27-made-r1.ps1')
$engineMade = '^\s*MADE\s+([a-z][a-z-]{0,30}):\s+(\S.*)$'
# The MADE lines of one run (a result of Invoke-T20), as 'kind: name' texts in output order. Takes the result; returns an array.
function Get-MadeText($Run) { return @($Run.Out | Where-Object { $_ -cmatch $engineMade } | ForEach-Object { $_ -replace '^\s*MADE\s+', '' }) }
# The three intake lists of the fake site. Takes nothing; returns the list objects.
function Get-IntakeLists { return @($global:FakeSP.Lists | Where-Object { @('PFMPublications', 'PFMEndorsements', 'PFMRecommendations') -contains $_.RootFolder.Name }) }

New-FakeSite
$global:FakeSP.BreakCalls = 0; $global:FakeSP.GrantCalls = 0
$r = Invoke-T20 'Check'
Test-That 'clean site: the check passes' ($r.Code -eq 0 -and $r.Text -match 'CLEAN check done, items with problems=0') $r.Text
Test-That 'check writes nothing' ($global:FakeSP.Posts -eq 0)
Test-That 'check result file' (Test-Path -LiteralPath (Join-Path $t20 '90161Z-T20-clean-check-r4.txt'))

$r = Invoke-T20 'DryRun'
Test-That 'dry run: no MADE line (nothing is made)' (@($r.Out | Where-Object { $_ -match 'MADE' }).Count -eq 0) $r.Text
Test-That 'dry run: counts' ($r.Text -match 'DRYRUN would create lists=12 fields=200 views=18 view-column requests=115 rows=93; set: updates=21 permissions=2') $r.Text
Test-That 'dry run writes nothing' ($global:FakeSP.Posts -eq 0 -and (Get-Ours).Count -eq 0 -and $global:FakeSP.BreakCalls -eq 0 -and $global:FakeSP.GrantCalls -eq 0)
Test-That 'dry run: the 3 intake lists would get own permissions and Contribute for Visitors (r4)' ($r.Text -match 'DRYRUN would create for the intake lists: own permissions=3 Visitors given Contribute=3') $r.Text
Test-That 'dry run: PFM Office would get the group, the level and the role (F2 A)' ($r.Text -match 'DRYRUN would create for PFM Office: group=1 level=1 level given to the group=1' -and @($global:FakeSP.Groups).Count -eq 0) $r.Text

$r = Invoke-T20 ''
$ours = Get-Ours
$mt = Get-MadeText $r
$wantMade = @($OwnLists.Values | ForEach-Object { 'list: ' + $_ }) + @(('group: ' + $OwnGroup), ('level: ' + $OwnLevel))
Test-That 'create: 14 MADE lines (12 lists, the group, the level), each one the engine pattern, each line once' ($mt.Count -eq 14 -and @($r.Out | Where-Object { $_ -match '^\s*MADE' }).Count -eq 14 -and @($mt | Sort-Object -Unique).Count -eq 14) ($mt -join '|')
Test-That 'create: the MADE names are the own-name table of T27 (the 12 titles, PFM Office, PFM Office Edit All Items)' ((($mt | Sort-Object) -join '|') -ceq (($wantMade | Sort-Object) -join '|')) ($mt -join '|')
Test-That 'create: the MADE lines name the titles the site shows (every list of the site has a MADE line)' (@($ours | Where-Object { $mt -cnotcontains ('list: ' + $_.Title) }).Count -eq 0) ($mt -join '|')
Test-That 'create: exit 0 and no problems' ($r.Code -eq 0 -and $r.Text -match 'PROVISION done, items with problems=0') $r.Text
Test-That 'create: 12 list lines pass' (@($r.Out | Where-Object { $_ -match '^ITEM L\d\d-PFM\w+ PASS' }).Count -eq 12)
Test-That 'create: counts line' ($r.Text -match 'CREATED lists=12 fields=200 views=18 view-column requests=115 rows=93')
Test-That 'site: 12 lists with display titles' ($ours.Count -eq 12 -and @($ours | Where-Object { $_.Title -like 'PFM *' }).Count -eq 12)
Test-That 'site: 200 columns' ((($ours | ForEach-Object { $_.FieldList.Count - 6 }) | Measure-Object -Sum).Sum -eq 200)
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
$intake = Get-IntakeLists
$readId = Get-FakeLevelId 'Read'; $conId = Get-FakeLevelId 'Contribute'
Test-That 'create r4: the 3 intake lists (Publications, Endorsements, Recommendations) got own permissions and Visitors hold Contribute on each' ($intake.Count -eq 3 -and @($intake | Where-Object { $_.HasUniqueRoleAssignments -and @($_.ListRoles[$visitorsId]) -contains $conId }).Count -eq 3 -and $global:FakeSP.BreakCalls -eq 3 -and $global:FakeSP.GrantCalls -eq 3 -and $r.Text -match 'CREATED for the intake lists: own permissions=3 Visitors given Contribute=3') $r.Text
Test-That 'create r4: the copied roles are kept (Visitors Read, PFM Office level) and the other 9 lists still inherit' (@($intake | Where-Object { @($_.ListRoles[$visitorsId]) -contains $readId -and @($_.ListRoles[$gi]).Count -ge 1 }).Count -eq 3 -and @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -like 'PFM*' -and $_.HasUniqueRoleAssignments }).Count -eq 3)
Test-That 'create r4: the site itself stays Read for Visitors (no site role added)' (@($global:FakeSP.WebRoles[$visitorsId]).Count -eq 1 -and @($global:FakeSP.WebRoles[$visitorsId])[0] -eq $readId)
Test-That 'create r4: read-back lines W01 to W03 PASS' (@($r.Out | Where-Object { $_ -match '^ITEM W0[1-3]-PFM(Publications|Endorsements|Recommendations) PASS ' }).Count -eq 3) $r.Text
$file = Get-Content -LiteralPath (Join-Path $t20 '90161Z-T20-provision-lists-r4.txt') -Raw
Test-That 'result file: no site address, host or id' ($file -notmatch 'fakehost|FakeWing|tester01|[0-9a-f]{8}-[0-9a-f]{4}-')
# Every POST body the script sent equals the payload's body for that request, in the payload's order (list ids aside).
$pl = Get-Content -LiteralPath (Join-Path $t20 'provisioning-payload.json') -Raw | ConvertFrom-Json
$want = @(@($pl.lists) + @($pl.fields) + @($pl.rows) | ForEach-Object { (($_.body | ConvertTo-Json -Depth 20 -Compress) -replace '\{__\w+_ID__\}', '{G}') })
$got = @($global:FakeSP.Sent | ForEach-Object { ((($_ | ConvertFrom-Json) | ConvertTo-Json -Depth 20 -Compress) -replace '\{[0-9a-f]{8}-[0-9a-f-]{27}\}', '{G}') })
$diff = @(0..([Math]::Max($want.Count, $got.Count) - 1) | Where-Object { $want[$_] -cne $got[$_] })
Test-That 'every POST body equals the payload body, in order' ($want.Count -eq 438 -and $got.Count -eq 438 -and $diff.Count -eq 0) ('want ' + $want.Count + ' got ' + $got.Count + ' first diff at ' + $(if ($diff.Count) { $diff[0] } else { '-' }))

$posts = $global:FakeSP.Posts
$r = Invoke-T20 ''
Test-That 'second run: creates nothing and passes' ($r.Code -eq 0 -and $r.Text -match 'CREATED lists=0 fields=0 views=0 view-column requests=115 rows=0' -and $r.Text -match 'items with problems=0') $r.Text
Test-That 'second run: no MADE line (nothing was made)' ((Get-MadeText $r).Count -eq 0 -and @($r.Out | Where-Object { $_ -match '^\s*MADE' }).Count -eq 0) $r.Text
Test-That 'second run: only the 115 view-column requests are sent again' ($global:FakeSP.Posts -eq $posts + 115)
Test-That 'second run r4: no inheritance broken, no role given again, W01 to W03 PASS' ($global:FakeSP.BreakCalls -eq 3 -and $global:FakeSP.GrantCalls -eq 3 -and $r.Text -match 'CREATED for the intake lists: own permissions=0 Visitors given Contribute=0' -and @($r.Out | Where-Object { $_ -match '^ITEM W0[1-3]-\S+ PASS ' }).Count -eq 3) $r.Text
Test-That 'second run: PFM Office: nothing made again, read back PASS' ($r.Text -match 'CREATED for PFM Office: group=0 level=0 level given to the group=0' -and $r.Text -match 'ITEM P01-pfm-office PASS' -and @($global:FakeSP.Levels).Count -eq 5) $r.Text
Test-That 'second run: same site (200 columns, 18 views with columns, 93 rows)' (((Get-Ours | ForEach-Object { $_.FieldList.Count - 6 }) | Measure-Object -Sum).Sum -eq 200 -and ((Get-Ours | ForEach-Object { $_.Items.Count }) | Measure-Object -Sum).Sum -eq 93 -and @(Get-Ours | ForEach-Object { $_.ViewList } | Where-Object { $_.Columns.Count -lt 1 }).Count -eq 0)

# ---- T19 r6 on the provisioned fake site (S3 A, PFM 19 Nov 26: the tier T-0; R36: the Event Type choice Waiver Warning for F08) ----
$t19 = Join-Path $work 'T19'
$null = New-Item -ItemType Directory -Path $t19 -Force
$script19 = Join-Path $Root 'scripts/gov/90161Z-T19-list-update-r6.ps1'
# Run the T19 script against the fake site in one mode (Check, PlanOnly or empty for a real run). Returns Code, Out, Text and File.
function Invoke-T19([string]$Mode) {
  $sw = @{}; if ($Mode) { $sw[$Mode] = $true }
  $global:LASTEXITCODE = 0
  $out = & $script19 -Id 'tester01' -NoPause -TestDir $t19 @sw *>&1 | ForEach-Object { [string]$_ }
  $f = Join-Path $t19 $(if ($Mode -eq 'Check') { '90161Z-T19-list-check-r6.txt' } else { '90161Z-T19-list-update-r6.txt' })
  return @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $f) { Get-Content -LiteralPath $f -Raw } else { '' }) }
}
# The Tier column of the fake PFM Waivers list (its data holds the choices).
function Get-TierColumn { return @(@($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMWaivers' })[0].FieldList | Where-Object { $_.InternalName -eq 'Tier' })[0] }
# The Event Type column of the fake PFM Activity Log list (R36: F08 writes the choice Waiver Warning).
function Get-EventTypeColumn { return @(@($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMActivityLog' })[0].FieldList | Where-Object { $_.InternalName -eq 'EventType' })[0] }
$logChoices = @((Get-Content -LiteralPath (Join-Path $Root 'schemas/lists/PFMActivityLog.json') -Raw | ConvertFrom-Json).fields | Where-Object { $_.internalName -eq 'EventType' })[0].choices
$r = Invoke-T19 'PlanOnly'
Test-That 'T19 plan: 9 items, Tier with T-0 first, Event Type with Waiver Warning, no sign-in' ($r.Code -eq 0 -and $r.Text -match 'PLAN 6-Tier choices in PFM Waivers: T-0, T-1, T-2, T-3, Non-Tiered' -and
  $r.Text -match ('PLAN 7-EventType choices in PFM Activity Log: ' + [regex]::Escape($logChoices -join ', ') + '(\r?\n|$)') -and $logChoices[-1] -eq 'Waiver Warning' -and
  $r.Out[-1] -eq 'PLAN columns=4 choice columns=3 settings=1 steps=1' -and $r.Text -match 'PLAN 9-stage6-target step 6 = 20 in PFM Process Steps') $r.Text
Test-That 'T20 built a new site with T-0 already (the payload)' (((Get-TierColumn).Data.Choices -join ',') -eq 'T-0,T-1,T-2,T-3,Non-Tiered')
Test-That 'T20 built a new site with Waiver Warning already (the payload)' (((Get-EventTypeColumn).Data.Choices -join ',') -eq ($logChoices -join ','))
$r = Invoke-T19 'Check'
Test-That 'T19 check on a new site: nothing to change' ($r.Code -eq 0 -and $r.Text -match 'LISTCHECK done, changes a run would make=0, items with problems=0') $r.Text
# An older site: no T-0, a choice a person added, no Waiver Warning, one column missing, another suspense value.
(Get-TierColumn).Data.Choices = [string[]]@('T-1', 'T-2', 'T-3', 'Non-Tiered', 'Waived Locally')
(Get-EventTypeColumn).Data.Choices = [string[]](@($logChoices | Where-Object { $_ -ne 'Waiver Warning' }) + 'Local Event')
$pubs = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMPublications' })[0]
$pubs.FieldList.Remove(@($pubs.FieldList | Where-Object { $_.InternalName -eq 'HeldSince' })[0])
$pubs.FieldList.Remove(@($pubs.FieldList | Where-Object { $_.InternalName -eq 'ClosedDate' })[0])
$setRow = @(@($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMSettings' })[0].Items | Where-Object { $_.Title -eq 'CoordinationSuspenseBusinessDays' })[0]
$setRow.SettingValue = '20'
$r = Invoke-T19 'Check'
$same = ((Get-TierColumn).Data.Choices -join ',') -eq 'T-1,T-2,T-3,Non-Tiered,Waived Locally' -and $setRow.SettingValue -eq '20'
$same = $same -and -not ((Get-EventTypeColumn).Data.Choices -contains 'Waiver Warning')
Test-That 'T19 check on an older site: names the 5 changes and changes nothing' ($r.Code -eq 0 -and $same -and $r.Text -match 'ITEM 6-Tier INFO a run would add the choices T-0 to PFM Waivers' -and
  $r.Text -match 'ITEM 7-EventType INFO a run would add the choices Waiver Warning to PFM Activity Log' -and $r.Text -match 'changes a run would make=5' -and $r.File -match 'LISTCHECK done') $r.Text
$r = Invoke-T19 ''
$tier = ((Get-TierColumn).Data.Choices -join ',')
Test-That 'T19 run: T-0 added first, the other choices kept in order' ($r.Code -eq 0 -and $tier -eq 'T-0,T-1,T-2,T-3,Non-Tiered,Waived Locally' -and $r.Text -match 'ITEM 6-Tier PASS added choices: T-0 \(choices now 6\)') ($tier + "`n" + $r.Text)
$events = ((Get-EventTypeColumn).Data.Choices -join ',')
Test-That 'T19 run: Waiver Warning added in the schema order, the choice a person added kept after them' ($r.Code -eq 0 -and $events -eq (($logChoices -join ',') + ',Local Event') -and
  $r.Text -match 'ITEM 7-EventType PASS added choices: Waiver Warning \(choices now 13\)') ($events + "`n" + $r.Text)
$seedNotes = @((Get-Content -LiteralPath (Join-Path $Root 'schemas/lists/PFMSettings.json') -Raw | ConvertFrom-Json).seed | Where-Object { $_.Title -eq 'CoordinationSuspenseBusinessDays' })[0].SettingNotes
$closedAdded = @($pubs.FieldList | Where-Object { $_.InternalName -eq 'ClosedDate' }).Count -eq 1   # R36: T19 r6 adds Closed Date
Test-That 'T19 run: the column and the setting (20 becomes 15, the notes of the schema seed row) are set' (@($pubs.FieldList | Where-Object { $_.InternalName -eq 'HeldSince' }).Count -eq 1 -and $closedAdded -and $setRow.SettingValue -eq '15' -and $r.Text -match 'ITEM 8-suspense-setting PASS set to 15 \(was 20\)' -and $setRow.SettingNotes -ceq $seedNotes -and $r.Text -match 'LISTUPDATE done, changes made=5, items with problems=0') $r.Text
Test-That 'T19 run: NOW lines on the screen only, result file masked' (@($r.Out | Where-Object { $_ -match '^NOW [A-Z][a-z]+ing ' }).Count -ge 5 -and $r.File -notmatch '(?m)^NOW ' -and $r.File -match 'LISTUPDATE done' -and $r.File -notmatch 'fakehost|FakeWing|tester01') $r.Text
$r = Invoke-T19 ''
Test-That 'T19 second run: changes nothing' ($r.Code -eq 0 -and $r.Text -match 'LISTUPDATE done, changes made=0, items with problems=0' -and ((Get-TierColumn).Data.Choices -join ',') -eq $tier -and
  ((Get-EventTypeColumn).Data.Choices -join ',') -eq $events -and $r.Text -match 'ITEM 7-EventType PASS present in PFM Activity Log, choices=13') $r.Text
# T19 r5, item 8 in r6 (PFM 19 Nov 26: 15 business days): an empty value becomes 15; any other value (17) is left and reported; 15 stays.
$setRow.SettingValue = '17'
$r = Invoke-T19 ''
Test-That 'T19 setting: 17 is left as it is and reported' ($r.Code -eq 0 -and $setRow.SettingValue -eq '17' -and $r.Text -match 'ITEM 8-suspense-setting INFO kept, 17' -and $r.Text -match 'changes made=0, items with problems=0') $r.Text
$r = Invoke-T19 'Check'
Test-That 'T19 setting check: 17 changes nothing and is reported' ($r.Code -eq 0 -and $setRow.SettingValue -eq '17' -and $r.Text -match 'ITEM 8-suspense-setting INFO kept, 17') $r.Text
$setRow.SettingValue = ''
$r = Invoke-T19 ''
Test-That 'T19 setting: an empty value is set to 15' ($r.Code -eq 0 -and $setRow.SettingValue -eq '15' -and $r.Text -match 'ITEM 8-suspense-setting PASS set to 15') $r.Text
$r = Invoke-T19 ''
Test-That 'T19 setting: 15 is present and stays (idempotent)' ($r.Code -eq 0 -and $setRow.SettingValue -eq '15' -and $r.Text -match 'ITEM 8-suspense-setting PASS present, 15') $r.Text
# Stage 6 target (PFM 19 Nov 26: 15 + 5 = 20 business days): 25 moves to 20, any other value stays.
$stepRow = @(@($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMProcessSteps' })[0].Items | Where-Object { [string]$_.StepNumber -eq '6' })[0]
Test-That 'T19 stage 6: a new site has the seed target 20' ([string]$stepRow.TargetBusinessDays -eq '20') ([string]$stepRow.TargetBusinessDays)
$stepRow.TargetBusinessDays = 25
$r = Invoke-T19 ''
Test-That 'T19 stage 6: 25 becomes 20' ($r.Code -eq 0 -and [string]$stepRow.TargetBusinessDays -eq '20' -and $r.Text -match 'ITEM 9-stage6-target PASS set to 20 \(was 25\)') $r.Text
$stepRow.TargetBusinessDays = 23
$r = Invoke-T19 ''
Test-That 'T19 stage 6: 23 is left as it is and reported' ($r.Code -eq 0 -and [string]$stepRow.TargetBusinessDays -eq '23' -and $r.Text -match 'ITEM 9-stage6-target INFO kept, 23') $r.Text
$stepRow.TargetBusinessDays = 20
# One value: the T19 r5 setting (new value 15, old value 20), the schema seed row and the default of F03 r7 agree (PFM 19 Nov 26).
$t19Text = Get-Content -LiteralPath $script19 -Raw
$f03Text = Get-Content -LiteralPath (Join-Path $Root 'flow/solution/defs/90161Z-F03-suspense-reminders-r8.json') -Raw
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
Test-That 'list access: 9 lists inherit from the site, the 3 intake lists have their own (r4): PASS with the counts' ($r.Code -eq 0 -and $r.Text -match 'ITEM P02-list-access PASS 12 lists: 9 inherit from the site, 3 have own permissions') (@($r.Out) -join ' | ')
$offId = [int]@($global:FakeSP.Levels | Where-Object { $_['Name'] -eq 'PFM Office Edit All Items' })[0]['Id']
$readId = [int]@($global:FakeSP.Levels | Where-Object { $_['Name'] -eq 'Read' })[0]['Id']
$accPub = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMPublications' })[0]
$accEnd = @($global:FakeSP.Lists | Where-Object { $_.RootFolder.Name -eq 'PFMEndorsements' })[0]
$accPub.ListRoles[$gi] = @($offId, $readId)
$r = Invoke-T20 ''
Test-That 'list access: own permissions and the group holds the level on the list: PASS' ($r.Code -eq 0 -and $r.Text -match 'ITEM P02-list-access PASS 12 lists: 9 inherit from the site, 3 have own permissions') (@($r.Out) -join ' | ')
$accEnd.ListRoles.Remove($gi)
$r = Invoke-T20 ''
Test-That 'list access: own permissions and no role for the group: FAIL naming that list only' ($r.Code -eq 1 -and $r.Text -match '(?m)ITEM P02-list-access FAIL lists that fail \(1 of 12\): PFM Endorsements has its own permissions and the group PFM Office does not hold the level on it\r?$' -and $r.Text -notmatch 'FAIL lists that fail.*PFM Publications') (@($r.Out) -join ' | ')
$accEnd.ListRoles[$gi] = @($readId)
$accPub.ListRoles[$gi] = @($readId)
$r = Invoke-T20 ''
Test-That 'list access: the group holds another level only: FAIL naming both lists' ($r.Code -eq 1 -and $r.Text -match 'ITEM P02-list-access FAIL lists that fail \(2 of 12\): .*PFM Publications.*PFM Endorsements|ITEM P02-list-access FAIL lists that fail \(2 of 12\): .*PFM Endorsements.*PFM Publications') (@($r.Out) -join ' | ')
$accEnd.ListRoles[$gi] = @($offId); $accPub.ListRoles[$gi] = @($offId)
$r = Invoke-T20 ''
Test-That 'list access: the level given on both lists: PASS again, nothing written' ($r.Code -eq 0 -and $r.Text -match 'ITEM P02-list-access PASS 12 lists: 9 inherit from the site, 3 have own permissions') (@($r.Out) -join ' | ')
# r4: a list that inherits again (a person reset it) gets own permissions and Contribute again, in one run.
$accPub.HasUniqueRoleAssignments = $false; $accPub.ListRoles = @{}
$r = Invoke-T20 ''
Test-That 'r4: a list that inherits again: own permissions made, Contribute given, W01 PASS; the other two lists untouched' ($r.Code -eq 0 -and $r.Text -match 'CREATED for the intake lists: own permissions=1 Visitors given Contribute=1' -and $accPub.HasUniqueRoleAssignments -and @($accPub.ListRoles[$visitorsId]) -contains $conId -and $r.Text -match 'ITEM W01-PFMPublications PASS') $r.Text
# A list with its own permissions where Visitors hold only Read: Contribute is added without breaking anything.
$accEnd.ListRoles[$visitorsId] = @($readId)
$r = Invoke-T20 ''
Test-That 'r4: own permissions already, Visitors hold only Read: no inheritance break, Contribute added' ($r.Code -eq 0 -and $r.Text -match 'CREATED for the intake lists: own permissions=0 Visitors given Contribute=1' -and @($accEnd.ListRoles[$visitorsId]) -contains $conId -and @($accEnd.ListRoles[$visitorsId]) -contains $readId) $r.Text

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
Test-That 'repair run: one MADE line, for the one list that was made again (nothing for what was there)' ((@(Get-MadeText $r) -join '|') -ceq 'list: PFM Waivers') ((Get-MadeText $r) -join '|')

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
  $both = @(Get-MadeText $r1) + @(Get-MadeText $r2)
  Test-That ('stopped after ' + $stopAt + ' requests: the 2 runs together print each of the 14 MADE lines once') ($both.Count -eq 14 -and @($both | Sort-Object -Unique).Count -eq 14) ($both -join '|')
  Test-That ('stopped after ' + $stopAt + ' requests: the next run completes the site') ($r1.Code -eq 1 -and $r2.Code -eq 0 -and $r2.Text -match 'items with problems=0' -and $o.Count -eq 12 -and (($o | ForEach-Object { $_.Items.Count }) | Measure-Object -Sum).Sum -eq 93 -and (($o | ForEach-Object { $_.FieldList.Count - 6 }) | Measure-Object -Sum).Sum -eq 200 -and @($o | ForEach-Object { $_.ViewList } | Where-Object { $_.Columns.Count -lt 1 }).Count -eq 0) ($r1.Out[-1] + ' / ' + $r2.Out[-1])
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
Test-That 'a group PFM Office that is there: no group line, the 12 lists and the level' (@(Get-MadeText $r).Count -eq 13 -and @(Get-MadeText $r | Where-Object { $_ -like 'group:*' }).Count -eq 0 -and @(Get-MadeText $r) -ccontains ('level: ' + $OwnLevel)) ((Get-MadeText $r) -join '|')
Test-That 'a group PFM Office that is there: used, only the level and its role are made' ($r.Code -eq 0 -and $r.Text -match 'CREATED for PFM Office: group=0 level=1 level given to the group=1' -and @($global:FakeSP.WebRoles[2]).Count -eq 1 -and @($global:FakeSP.Groups).Count -eq 2) $r.Text
New-FakeSite
$global:FakeSP.Levels.RemoveAt(1)
$r = Invoke-T20 ''
Test-That 'a site without an Edit level: STOPPED after the lists, no level made' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LEVEL Edit not found on the site' -and (Get-Ours).Count -eq 12 -and @($global:FakeSP.Levels).Count -eq 3) $r.Text

# r4: a site with no associated Visitors group: no list is changed for them, and each intake list reads FAIL with the reason.
New-FakeSite
$global:FakeSP.VisitorId = 0
$r = Invoke-T20 ''
Test-That 'r4: no Visitors group on the site: W01 to W03 FAIL with the reason, exit 1, no inheritance broken' ($r.Code -eq 1 -and @($r.Out | Where-Object { $_ -match '^ITEM W0[1-3]-\S+ FAIL the site has no associated Visitors group' }).Count -eq 3 -and @(Get-IntakeLists | Where-Object { $_.HasUniqueRoleAssignments }).Count -eq 0 -and $r.Text -match 'items with problems=3') $r.Text
# r4: a site with no Contribute level: the same, with that reason.
New-FakeSite
$noContribute = @($global:FakeSP.Levels | Where-Object { [int]$_['RoleTypeKind'] -eq 3 })[0]; $global:FakeSP.Levels.Remove($noContribute)
$r = Invoke-T20 ''
Test-That 'r4: no Contribute level on the site: W01 to W03 FAIL with the reason, nothing changed' ($r.Code -eq 1 -and @($r.Out | Where-Object { $_ -match '^ITEM W0[1-3]-\S+ FAIL the site has no Contribute level' }).Count -eq 3 -and @(Get-IntakeLists | Where-Object { $_.HasUniqueRoleAssignments }).Count -eq 0) $r.Text

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T20 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
