# Tests scripts/gov/90161Z-T27-lifecycle-r1.ps1 and its 2 modules (round R43 plan item T5; the PFM, 25 Nov 26: RADE Uninstall, install from
# zero, 1 fake publication through 1 full process step) against a small fake site. The PnP cmdlets the script uses are fakes in this file
# (an empty PnP.PowerShell 1.12.0 module in a temporary folder lets the script's module check pass). Proves the logic, not the real
# service and not RADE engine-v40 (not released): the gov device round is that proof.
# Cases: the Uninstall parts (Lists, Access, Local) remove ONLY what a fake RADE_MADE file names and the own-name table allows: a list
# that the file does not name stays; a list of another folder name with an own title stays; a name that is not ours is refused; a
# second run removes nothing and prints SKIP; a bad gate (wrong RADE_MODE, no file, bad JSON, wrong schema, wrong app) makes no
# sign-in and no remove call and prints FAIL. The checks Gone and Install, and the process step Step, on the fake site. The own-name
# table equals flow/provisioning-payload.json; the fake publication title equals the one of T26.
# Network: none.
# Writes: one temporary folder (the T22, T26 and T27 folders of the test, the fake module); removed at the end.
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
$t27 = Join-Path $work 'T27'; $t22 = Join-Path $work 'T22'; $t26 = Join-Path $work 'T26'
foreach ($d in $t27, $t22, $t26) { $null = New-Item -ItemType Directory -Path $d -Force }
$modDir = Join-Path $work 'mods/PnP.PowerShell/1.12.0'; $null = New-Item -ItemType Directory -Path $modDir -Force
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psm1') -Value '# empty on purpose: the cmdlets are fakes in tests/ps/Test-T27.ps1'
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psd1') -Value "@{ RootModule = 'PnP.PowerShell.psm1'; ModuleVersion = '1.12.0'; GUID = '0b0430ce-d799-4f3b-a565-f0dca1f31e18' }"
$env:PSModulePath = (Join-Path $work 'mods') + [IO.Path]::PathSeparator + $env:PSModulePath
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T27-lifecycle-r1.ps1'
# The fake site's helper script files live in the real scripts/gov folder: the script loads its modules from its own folder.
$payload = Get-Content -LiteralPath (Join-Path $Root 'flow/provisioning-payload.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# ---- the fake site and its cmdlets ----
# The 12 lists as the payload names them: internal name and display title (the title is set by the payload's "updates").
$internal = @($payload.listOrder | ForEach-Object { [string]$_ })
$display = @{}
foreach ($u in $payload.updates) { if ([string]$u.uri -match "getbytitle\('([^']+)'\)$") { $display[$Matches[1]] = [string]$u.body.Title } }
# Reset the fake site: the 12 lists of 90-161.Z, one list of a person, the group, the level, 13 process steps and no calls.
# Takes nothing; returns nothing.
function New-Site {
  $global:S = @{ Lists = (New-Object System.Collections.ArrayList); Groups = @('Site Owners', 'PFM Office'); Levels = @('Edit', 'PFM Office Edit All Items')
    Calls = (New-Object System.Collections.ArrayList); Connects = 0; Next = 100; Rows = @{ 'PFM Process Steps' = (New-Object System.Collections.ArrayList)
      'PFM Publications' = (New-Object System.Collections.ArrayList); 'PFM Activity Log' = (New-Object System.Collections.ArrayList) } }
  foreach ($k in $internal) { Add-FakeList $k $display[$k] }
  Add-FakeList 'Lists/Person' 'Budget Notes'
  foreach ($n in 0..12) {
    $days = $(if ($n -eq 2) { 60 } else { $null })
    $null = $global:S.Rows['PFM Process Steps'].Add(@{ Id = (200 + $n); Title = ('FAKE step ' + $n); StepNumber = $n; TargetBusinessDays = $days })
  }
}
# Add a fake list: its folder name and title; returns nothing.
function Add-FakeList([string]$Folder, [string]$Title) {
  $global:S.Next++
  $null = $global:S.Lists.Add(@{ Id = ('00000000-0000-0000-0000-' + $global:S.Next.ToString('000000000000')); Title = $Title; Folder = $Folder })
}
# Remove the fake lists for which a test script block is true (the block gets the list as $_). Returns nothing.
function Remove-FakeList([scriptblock]$Which) { foreach ($l in @($global:S.Lists | Where-Object $Which)) { $global:S.Lists.Remove($l) } }
# Remove the fake process step row with a step number. Returns nothing.
function Remove-FakeStepRow([int]$Number) { foreach ($r in @($global:S.Rows['PFM Process Steps'] | Where-Object { $_.StepNumber -eq $Number })) { $global:S.Rows['PFM Process Steps'].Remove($r) } }
# Fake Connect-PnPOnline: accepts only -UseWebLogin, as on the gov device; counts the sign-ins.
function Connect-PnPOnline { [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin) if (-not $UseWebLogin) { throw 'FAKE: -UseWebLogin only' }; $global:S.Connects++ }
# Fake Disconnect-PnPOnline: does nothing.
function Disconnect-PnPOnline { [CmdletBinding()] param() }
<#
.SYNOPSIS
  Fake Invoke-PnPSPRestMethod: GET of the lists, groups and permission levels of the fake site, as the REST service answers.
.PARAMETER Method
  The HTTP method; only Get is known.
.PARAMETER Url
  The request address; its path picks the lists, the groups or the permission levels.
.PARAMETER Content
  Not used (the script sends no body in a read).
.PARAMETER ContentType
  Not used.
.PARAMETER Raw
  Not used (the answer is always the JSON text).
.OUTPUTS
  System.String. The JSON text of the answer, as { "value": [ ... ] }.
#>
function Invoke-PnPSPRestMethod {
  [CmdletBinding()] param([string]$Method, [string]$Url, [string]$Content, [string]$ContentType, [switch]$Raw)
  if ($Method -ne 'Get') { throw 'FAKE: GET only' }
  if ($Url -match '/_api/web/lists\?') {
    $v = @($global:S.Lists | ForEach-Object {
        @{ Id = $_.Id; Title = $_.Title; ItemCount = 1; EnableVersioning = $true; BaseTemplate = 100; Hidden = $false
          HasUniqueRoleAssignments = $false; RootFolder = @{ Name = $_.Folder } } })
    return (@{ value = $v } | ConvertTo-Json -Depth 6 -Compress)
  }
  if ($Url -match '/_api/web/sitegroups') {
    $v = @($global:S.Groups | ForEach-Object { @{ Id = (900 + [array]::IndexOf($global:S.Groups, $_)); Title = $_ } })
    return (@{ value = $v } | ConvertTo-Json -Depth 4 -Compress)
  }
  if ($Url -match '/_api/web/roledefinitions') {
    $v = @($global:S.Levels | ForEach-Object {
        @{ Id = (800 + [array]::IndexOf($global:S.Levels, $_)); Name = $_; RoleTypeKind = 0; BasePermissions = @{ Low = '1'; High = '1' } } })
    return (@{ value = $v } | ConvertTo-Json -Depth 4 -Compress)
  }
  throw ('FAKE: GET not known ' + $Url)
}
# Fake Remove-PnPList: removes the list with that Id and logs the call (-Recycle and -Force are required, as the script sets them).
function Remove-PnPList {
  [CmdletBinding()] param([string]$Identity, [switch]$Recycle, [switch]$Force)
  if (-not $Recycle -or -not $Force) { throw 'FAKE: the script must use -Recycle -Force' }
  $hit = @($global:S.Lists | Where-Object { $_.Id -eq $Identity })
  if (-not $hit.Count) { throw 'FAKE 404 list' }
  if ($global:S.FailList -and $hit[0].Folder -eq $global:S.FailList) { throw 'FAKE: this list cannot be removed' }
  $null = $global:S.Calls.Add('list:' + $hit[0].Folder); $global:S.Lists.Remove($hit[0])
}
# Fake Remove-PnPGroup: removes a group by name and logs the call.
function Remove-PnPGroup {
  [CmdletBinding()] param([string]$Identity, [switch]$Force)
  $null = $global:S.Calls.Add('group:' + $Identity); $global:S.Groups = @($global:S.Groups | Where-Object { $_ -ne $Identity })
}
# Fake Remove-PnPRoleDefinition: removes a permission level by name and logs the call.
function Remove-PnPRoleDefinition {
  [CmdletBinding()] param([string]$Identity, [switch]$Force)
  $null = $global:S.Calls.Add('level:' + $Identity); $global:S.Levels = @($global:S.Levels | Where-Object { $_ -ne $Identity })
}
# Fake Get-PnPListItem: the rows of one of the 3 fake row lists (throws for another list).
function Get-PnPListItem {
  [CmdletBinding()] param([string]$List, [string[]]$Fields, [int]$PageSize)
  if (-not $global:S.Rows.ContainsKey($List)) { throw ('FAKE: no list titled ' + $List) }
  return @($global:S.Rows[$List])
}
# Fake Set-PnPListItem: sets fields of one row, and logs the call.
function Set-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [hashtable]$Values)
  $hit = @($global:S.Rows[$List] | Where-Object { $_.Id -eq $Identity }); if (-not $hit.Count) { throw 'FAKE 404 row' }
  foreach ($k in $Values.Keys) { $hit[0][$k] = [pscustomobject]@{ LookupId = [int]$Values[$k] } }   # a lookup reads back as its value object
  $null = $global:S.Calls.Add('row:' + $List)
}
# Run one part against the fake site. Takes the part name; returns @{ Code; Text (the screen output); File (the result file text) }.
function Invoke-T27([string]$Part) {
  $global:LASTEXITCODE = 0; $global:S.Calls.Clear(); $global:S.Connects = 0
  $out = & $script -Id 'tester01' -Part $Part -NoPause -TestDir $t27 *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t27 ('90161Z-T27-' + $Part.ToLowerInvariant() + '-r1.txt')
  return @{ Code = $LASTEXITCODE; Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
}
# Write a fake RADE_MADE file and point the environment at it. Takes the entries (hashtables with kind and name; step is added) and options
# for the header; returns nothing.
function Set-Made([object[]]$Entries, [string]$Schema = 'rade-made/1', [string]$App = '90-161.Z', [string]$Mode = 'uninstall') {
  $made = @($Entries | ForEach-Object {
      $e = @{ step = 'T20 Make the 12 lists r4'; kind = $_.kind; name = $_.name }
      foreach ($x in 'step', 'kind', 'name') { if ($_.ContainsKey($x)) { $e[$x] = $_[$x] } }
      $e })
  $p = Join-Path $work 'made.json'
  Set-Content -LiteralPath $p -Value (@{ schema = $Schema; app = $App; made = $made } | ConvertTo-Json -Depth 5) -Encoding UTF8
  $env:RADE_MADE = $p; $env:RADE_MODE = $Mode
}
# The entries of the lists, by display title (even index) or internal name (odd index), so both forms are tested. Takes the internal names.
function Get-ListEntry([string[]]$Names) {
  $i = 0; return @($Names | ForEach-Object { $i++; @{ kind = 'list'; name = $(if ($i % 2) { $display[$_] } else { $_ }) } })
}
# The folder names of the own lists that are on the fake site now.
function Get-OwnLeft { return @($global:S.Lists | Where-Object { $internal -contains $_.Folder } | ForEach-Object { $_.Folder }) }
try {
  New-Site
  # ---- the own-name table and the one-home checks ----
  . (Join-Path $Root 'scripts/gov/90161Z-T27-made-r1.ps1')
  $rev = @($internal); [array]::Reverse($rev)
  Test-That 'the own-list table has the 12 internal names of the payload, in reverse payload order' ((@($OwnLists.Keys) -join ',') -ceq ($rev -join ',')) ((@($OwnLists.Keys) -join ','))
  $bad = @($OwnLists.Keys | Where-Object { $OwnLists[$_] -cne $display[$_] })
  Test-That 'the own-list table has the display title of each list as the payload sets it' ($bad.Count -eq 0) ($bad -join ',')
  $man = Get-Content -LiteralPath (Join-Path $Root 'scripts/paste_bundles.json') -Raw | ConvertFrom-Json
  $back = @(@($man.bundles | ForEach-Object { $_.apps } | Where-Object { $_.mode -eq 'deploy' }) | ForEach-Object { $_.backup })
  Test-That 'the own-list titles equal the "backup" lists of the deploy app in the manifest' ((@($OwnLists.Values | Sort-Object) -join '|') -ceq (@($back | Sort-Object) -join '|')) ''
  $t26txt = Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T26-endorse-r2.ps1') -Raw
  $chk = Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T27-check-r1.ps1') -Raw
  $a = [regex]::Match($t26txt, "(?m)^\`$PubTitle = '([^']+)'").Groups[1].Value; $b = [regex]::Match($chk, "(?m)^\`$PubTitle = '([^']+)'").Groups[1].Value
  $c = [regex]::Match($t26txt, "(?m)^\`$StateName = '([^']+)'").Groups[1].Value; $d = [regex]::Match($chk, "(?m)^\`$T26State = '([^']+)'").Groups[1].Value
  Test-That 'the fake publication title and the state file name equal the ones of T26' ($a -and $a -ceq $b -and $c -and $c -ceq $d) ($a + ' / ' + $b)

  # ---- Uninstall, Lists ----
  Set-Made (Get-ListEntry $internal)
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and (Get-OwnLeft).Count -eq 0 -and @($global:S.Lists).Count -eq 1 -and $global:S.Lists[0].Title -eq 'Budget Notes')
  Test-That 'Lists removes the 12 named lists and leaves the list of a person' $ok $r.File
  $order = (@($global:S.Calls) -join ','); $want = (@($rev | ForEach-Object { 'list:' + $_ }) -join ',')
  Test-That 'Lists removes a list before the lists it points to (reverse payload order), by title or by internal name' ($order -ceq $want) $order
  Test-That 'Lists prints RESULT UNINSTALL LISTS PASS removed=12 and 12 PASS read-backs' ($r.File -match '(?m)^RESULT UNINSTALL LISTS PASS removed=12\r?$' -and
      ([regex]::Matches($r.File, '(?m)^ITEM r-\S+ PASS')).Count -eq 12) $r.File
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and $r.File -match '(?m)^RESULT UNINSTALL LISTS SKIP removed=0\r?$' -and
      ([regex]::Matches($r.File, '(?m)^ITEM l\d\d-\S+ SKIP')).Count -eq 12)
  Test-That 'a second Lists run removes nothing and prints SKIP (12 SKIP items, exit 0)' $ok $r.File

  New-Site; Set-Made (Get-ListEntry @('PFMSeries', 'PFMGuidance'))
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 2 -and (Get-OwnLeft).Count -eq 10 -and (Get-OwnLeft) -notcontains 'PFMSeries' -and (Get-OwnLeft) -notcontains 'PFMGuidance')
  Test-That 'Lists removes only the 2 lists in the made file: the other 10 of ours stay' $ok $r.File

  New-Site; Remove-FakeList { $_.Folder -eq 'PFMSeries' }; Add-FakeList 'Lists/SeriesByHand' 'PFM Series'
  Set-Made @(@{ kind = 'list'; name = 'PFM Series' })
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and @($global:S.Lists | Where-Object { $_.Folder -eq 'Lists/SeriesByHand' }).Count -eq 1 -and
      $r.File -match '(?m)^ITEM l01-PFMSeries SKIP')
  Test-That 'a list with an own title but another folder name is never removed (SKIP)' $ok $r.File

  New-Site; Set-Made @(@{ kind = 'list'; name = 'Budget Notes' }, @{ kind = 'list'; name = 'Documents' }, @{ kind = 'group'; name = 'PFM Series' })
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and $global:S.Connects -eq 0 -and (Get-OwnLeft).Count -eq 12 -and $r.File -match '(?m)^NOTE refused' -and
      $r.File -match '(?m)^RESULT UNINSTALL LISTS SKIP removed=0')
  Test-That 'names that are not ours are refused and removed never (no sign-in, no remove call, SKIP)' $ok $r.File

  New-Site; Set-Made @(@{ kind = 'list'; name = 'PFM Offices' }, @{ kind = 'list'; name = 'PFM Reviews' }, @{ kind = 'list'; name = 'Budget Notes' })
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 2 -and (Get-OwnLeft).Count -eq 10 -and @($global:S.Lists | Where-Object { $_.Title -eq 'Budget Notes' }).Count -eq 1)
  Test-That 'an own name next to a foreign name: the own list goes, the foreign one stays' $ok $r.File

  New-Site; Set-Made (Get-ListEntry @('PFMSeries', 'PFMGuidance')); $global:S.FailList = 'PFMSeries'
  $r = Invoke-T27 'Lists'; $global:S.FailList = $null
  $ok = ($r.Code -eq 1 -and $r.File -match '(?m)^ITEM l\d\d-PFMGuidance|(?m)^ITEM r-PFMGuidance PASS' -and $r.File -match '(?m)^ITEM l\d\d-PFMSeries FAIL' -and
      $r.File -match '(?m)^RESULT UNINSTALL LISTS FAIL removed=1')
  Test-That 'a list that cannot be removed: FAIL, exit 1, the other list is still removed' $ok $r.File
  $r = Invoke-T27 'Lists'
  Test-That 'Lists run again after that failure removes the list that is left' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 1 -and
      $r.File -match '(?m)^RESULT UNINSTALL LISTS PASS removed=1') $r.File

  # ---- the gate: nothing is removed and nobody signs in ----
  New-Site
  $cases = @(
    @('RADE_MODE is install', { Set-Made (Get-ListEntry $internal) -Mode 'install' }),
    @('RADE_MODE is empty', { Set-Made (Get-ListEntry $internal) -Mode '' }),
    @('another schema', { Set-Made (Get-ListEntry $internal) -Schema 'rade-made/2' }),
    @('another app', { Set-Made (Get-ListEntry $internal) -App '33-332.Z' }),
    @('no file', { Set-Made (Get-ListEntry $internal); Remove-Item -LiteralPath $env:RADE_MADE }),
    @('RADE_MADE not set', { Set-Made (Get-ListEntry $internal); $env:RADE_MADE = $null }),
    @('bad JSON', { Set-Made (Get-ListEntry $internal); Set-Content -LiteralPath $env:RADE_MADE -Value '{ not json' }))
  foreach ($c in $cases) {
    & $c[1]
    foreach ($part in 'Lists', 'Access', 'Local') {
      $r = Invoke-T27 $part
      $ok = ($r.Code -eq 1 -and $global:S.Calls.Count -eq 0 -and $global:S.Connects -eq 0 -and (Get-OwnLeft).Count -eq 12 -and $r.File -match '(?m)^ITEM g-made FAIL ' -and
          $r.File -match ('(?m)^RESULT UNINSTALL ' + $part.ToUpperInvariant() + ' FAIL removed=0'))
      Test-That ('gate (' + $c[0] + '), part ' + $part + ': FAIL, exit 1, no sign-in, no remove') $ok $r.File
    }
  }
  Set-Made @(@{ kind = 'list'; name = $display['PFMSeries'] }, @{ step = ''; kind = 'list'; name = $display['PFMGuidance'] }, @{ kind = ''; name = 'x' })
  $r = Invoke-T27 'Lists'
  Test-That 'an entry with no step, kind or name is dropped and counted, never used' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 1 -and
      $r.File -match '(?m)^MADE entries=1; without step, kind or name=2') $r.File

  # ---- Uninstall, Access ----
  New-Site; Set-Made @(@{ kind = 'group'; name = 'PFM Office' }, @{ kind = 'level'; name = 'PFM Office Edit All Items' })
  $r = Invoke-T27 'Access'
  $ok = ($r.Code -eq 0 -and (@($global:S.Calls) -join ',') -ceq 'group:PFM Office,level:PFM Office Edit All Items' -and $global:S.Groups -contains 'Site Owners' -and
      $global:S.Levels -contains 'Edit' -and $global:S.Groups.Count -eq 1)
  Test-That 'Access removes the group, then the level, and not the site owners group or the Edit level' $ok $r.File
  Test-That 'Access prints RESULT UNINSTALL ACCESS PASS removed=2' ($r.File -match '(?m)^RESULT UNINSTALL ACCESS PASS removed=2\r?$') $r.File
  $r = Invoke-T27 'Access'
  Test-That 'a second Access run removes nothing and prints SKIP' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and $r.File -match '(?m)^RESULT UNINSTALL ACCESS SKIP removed=0' -and
      $r.File -match '(?m)^ITEM a1-group SKIP' -and $r.File -match '(?m)^ITEM a2-level SKIP') $r.File
  New-Site; Set-Made @(@{ kind = 'group'; name = 'Site Owners' }, @{ kind = 'level'; name = 'Edit' })
  $r = Invoke-T27 'Access'
  Test-That 'a group or a level that is not ours is refused and stays' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and $global:S.Groups.Count -eq 2 -and
      $global:S.Levels.Count -eq 2 -and $r.File -match '(?m)^NOTE refused') $r.File
  New-Site; Set-Made (Get-ListEntry @('PFMSeries'))
  $r = Invoke-T27 'Access'
  Test-That 'Access with no group or level in the made file removes nothing (the group of the site was there before the install)' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and
      $global:S.Connects -eq 0 -and $r.File -match '(?m)^RESULT UNINSTALL ACCESS SKIP') $r.File

  # ---- Uninstall, Local ----
  foreach ($f in '90161Z-T22-install-r16.txt', '90161Z-T22-maint-r16.txt', 'keep.txt') { Set-Content -LiteralPath (Join-Path $t22 $f) -Value 'x' }
  New-Site; Set-Made @(@{ kind = 'file'; name = '90161Z-T22-install-r16.txt' })
  $r = Invoke-T27 'Local'
  $left = @(Get-ChildItem -LiteralPath $t22 | ForEach-Object { $_.Name } | Sort-Object)
  Test-That 'Local removes only the install note named in the made file, with no sign-in' ($r.Code -eq 0 -and $global:S.Connects -eq 0 -and
      ($left -join ',') -ceq '90161Z-T22-maint-r16.txt,keep.txt' -and $r.File -match '(?m)^RESULT UNINSTALL LOCAL PASS removed=1') $r.File
  $r = Invoke-T27 'Local'
  Test-That 'a second Local run prints SKIP' ($r.Code -eq 0 -and $r.File -match '(?m)^RESULT UNINSTALL LOCAL SKIP removed=0' -and $r.File -match '(?m)^ITEM f01-note SKIP') $r.File
  Set-Made @(@{ kind = 'file'; name = 'keep.txt' }, @{ kind = 'file'; name = '..\T26\90161Z-T22-install-r1.txt' }, @{ kind = 'file'; name = '90161Z-T22-maint-r16.txt' })
  $r = Invoke-T27 'Local'
  $left = @(Get-ChildItem -LiteralPath $t22 | ForEach-Object { $_.Name } | Sort-Object)
  Test-That 'Local refuses any other file and any path: nothing else is removed' ($r.Code -eq 0 -and ($left -join ',') -ceq '90161Z-T22-maint-r16.txt,keep.txt' -and
      ([regex]::Matches($r.File, '(?m)^NOTE refused')).Count -eq 3) $r.File

  # ---- the checks and the step ----
  New-Site
  $r = Invoke-T27 'Gone'
  Test-That 'Gone with the 12 lists on the site: FAIL, exit 1' ($r.Code -eq 1 -and $r.File -match '(?m)^ITEM g1-lists FAIL .*12 of 12') $r.File
  Remove-FakeList { $_.Folder -notlike 'Lists/*' }
  $r = Invoke-T27 'Gone'
  Test-That 'Gone with no list of ours (the list of a person stays): PASS' ($r.Code -eq 0 -and $r.File -match '(?m)^ITEM g1-lists PASS' -and
      $r.File -match 'ITEM g2-access INFO group PFM Office on the site=yes') $r.File
  New-Site
  $r = Invoke-T27 'Install'
  Test-That 'Install with the 12 lists and the process steps: PASS, exit 0' ($r.Code -eq 0 -and $r.File -match '(?m)^ITEM i1-lists PASS' -and $r.File -match '(?m)^ITEM i2-steps PASS') $r.File
  Remove-FakeList { $_.Folder -eq 'PFMWaivers' }
  $r = Invoke-T27 'Install'
  Test-That 'Install with a list missing: FAIL, exit 1, names the list' ($r.Code -eq 1 -and $r.File -match '(?m)^ITEM i1-lists FAIL .*PFM Waivers \(missing\)') $r.File
  New-Site
  $r = Invoke-T27 'Step'
  Test-That 'Step with no fake publication: FAIL, exit 1, no write' ($r.Code -eq 1 -and $r.File -match '(?m)^RESULT STEP FAIL' -and $global:S.Calls.Count -eq 0) $r.File
  $null = $global:S.Rows['PFM Publications'].Add(@{ Id = 50; Title = '90161Z TEST R41 endorse (delete me)'; ProcessStep = [pscustomobject]@{ LookupId = 201 } })
  $null = $global:S.Rows['PFM Publications'].Add(@{ Id = 51; Title = 'Another publication'; ProcessStep = [pscustomobject]@{ LookupId = 201 } })
  $null = $global:S.Rows['PFM Activity Log'].Add(@{ Id = 70; Title = 'FAKE log'; Publication = [pscustomobject]@{ LookupId = 50 } })
  $r = Invoke-T27 'Step'
  $pubRows = @($global:S.Rows['PFM Publications'])
  $now = @($pubRows | Where-Object { $_.Id -eq 50 })[0].ProcessStep.LookupId; $other = @($pubRows | Where-Object { $_.Id -eq 51 })[0].ProcessStep.LookupId
  $ok = ($r.Code -eq 0 -and $now -eq 202 -and $other -eq 201 -and $global:S.Calls.Count -eq 1 -and $r.File -match '(?m)^ITEM s2-move PASS moved from step 1 to step 2' -and
      $r.File -match '(?m)^RESULT STEP PASS from=1 to=2 target-days=60')
  Test-That 'Step moves the fake publication from step 1 to step 2, reads it back, and leaves another publication alone' $ok $r.File
  Test-That 'Step reports the target days of step 2 and the activity log rows as information' ($r.File -match 'target business days of step 2=60; activity log rows on the publication=1') $r.File
  $r = Invoke-T27 'Step'
  Test-That 'a second Step writes nothing and prints SKIP for the move' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and $r.File -match '(?m)^ITEM s2-move SKIP') $r.File
  Remove-FakeStepRow 2
  $r = Invoke-T27 'Step'
  Test-That 'Step with no step 2 row (the install did not seed it): FAIL, exit 1' ($r.Code -eq 1 -and $r.File -match '(?m)^RESULT STEP FAIL no step rows') $r.File

  # ---- every result file ----
  $all = Get-ChildItem -LiteralPath $t27 -Filter '*.txt' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
  Test-That 'no result line shows the site host' (-not (@($all) -join "`n").Contains('fakehost')) ''
  foreach ($f in 'lifecycle', 'made', 'check') {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $Root ('scripts/gov/90161Z-T27-' + $f + '-r1.ps1')))
    Test-That ('the file 90161Z-T27-' + $f + '-r1.ps1 is ASCII') (-not @($bytes | Where-Object { $_ -gt 127 }).Count) ''
  }
} finally {
  Set-Location -LiteralPath $Root
  $env:RADE_MADE = $null; $env:RADE_MODE = $null
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('T27 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
