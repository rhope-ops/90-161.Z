# Tests scripts/gov/90161Z-T27-lifecycle-r3.ps1 and its 2 modules (round R43 plan item T5; the PFM, 25 Nov 26: RADE Uninstall, install from
# zero, 1 fake publication through 1 full process step) against a small fake site. The PnP cmdlets the script uses are fakes in this file
# (an empty PnP.PowerShell 1.12.0 module in a temporary folder lets the script's module check pass). Proves the logic, not the real
# service and not RADE engine-v41 (not released): the gov device round is that proof.
# Cases: the Uninstall parts (Lists, Access, Local). Lists removes each own list BY ITS FIXED TITLE (the PFM, 25 Nov 26), also on a site where
# the fake RADE_MADE file is empty or names other things (the 12 lists were made before RADE installs). Access (the PFM, 25 Nov 26: a group
# cannot go to a Recycle Bin) removes the group PFM Office and the level PFM Office Edit All Items only when RADE_MADE names them: with an
# empty made list both stay and print SKIP "not made by the install"; named, they go; a foreign group or level always stays.
# A list of another folder name with an own title stays, a list of an own folder with another title stays, a list of a
# person with a similar title (suffix, case, space) stays, a name that is not ours is refused; a second run removes nothing and prints
# SKIP; a bad gate (wrong RADE_MODE, no file, bad JSON, wrong schema, wrong app) makes no sign-in and no remove call and prints FAIL.
# The checks Gone and Install, and the process step Step (step 1 to step 2 with the exit conditions of step 1 checked before and after
# the move, on the fake publication: each condition passes, and each one that is missing stops the move). The proof for the fake publication of
# T26 Make (R43): T26 Make runs against this fake site, whose Add-PnPListItem is strict (a choice must be a choice of the schema, a lookup
# must name an existing row, the link reads back as an address), and then Step finds all 6 exit conditions of step 1 met, before and after. The own-name table equals
# flow/provisioning-payload.json; the fake publication title equals the one of T26; the required columns equal the schema.
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
$script = Join-Path $Root 'scripts/gov/90161Z-T27-lifecycle-r3.ps1'
# The fake site's helper script files live in the real scripts/gov folder: the script loads its modules from its own folder.
$global:PubSchema = Get-Content -LiteralPath (Join-Path $Root 'schemas/lists/PFMPublications.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$payload = Get-Content -LiteralPath (Join-Path $Root 'flow/provisioning-payload.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# ---- the fake site and its cmdlets ----
# The 12 lists as the payload names them: internal name and display title (the title is set by the payload's "updates").
$internal = @($payload.listOrder | ForEach-Object { [string]$_ })
$display = @{}
foreach ($u in $payload.updates) { if ([string]$u.uri -match "getbytitle\('([^']+)'\)$") { $display[$Matches[1]] = [string]$u.body.Title } }
<#
.SYNOPSIS
  Reset the fake site: the 12 lists of 90-161.Z, one list of a person, the group, the level, 13 process steps and no calls.
.OUTPUTS
  None. It sets the global fake site $global:S.
#>
function New-Site {
  $global:S = @{ RowNext = 500; Lists = (New-Object System.Collections.ArrayList); Groups = @('Site Owners', 'PFM Office'); Levels = @('Edit', 'PFM Office Edit All Items')
    Calls = (New-Object System.Collections.ArrayList); Connects = 0; Next = 100; Rows = @{ 'PFM Process Steps' = (New-Object System.Collections.ArrayList)
      'PFM Publications' = (New-Object System.Collections.ArrayList); 'PFM Activity Log' = (New-Object System.Collections.ArrayList)
      'PFM Offices' = (New-Object System.Collections.ArrayList); 'PFM Endorsements' = (New-Object System.Collections.ArrayList) } }
  foreach ($n in 301, 302) { $null = $global:S.Rows['PFM Offices'].Add(@{ Id = $n; Title = ('FAKE office ' + $n) }) }
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
# Fake Connect-PnPOnline: accepts only -UseWebLogin, as on the gov device; counts the sign-ins and keeps the address (R47).
function Connect-PnPOnline { [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin) if (-not $UseWebLogin) { throw 'FAKE: -UseWebLogin only' }; $global:S.Connects++; $global:SignedInTo = $Url }
# Fake Disconnect-PnPOnline: ends the fake connection and counts the sign-outs (R47).
function Disconnect-PnPOnline { [CmdletBinding()] param() $global:SignedInTo = ''; $global:SignOuts++ }
# Fake Get-PnPConnection (R47, the T30 batch): the connection of this process, or an error when there is none, as PnP.PowerShell 1.12.0 does.
function Get-PnPConnection { [CmdletBinding()] param() if (-not $global:SignedInTo) { throw 'FAKE: no connection' }; return [pscustomobject]@{ Url = $global:SignedInTo } }
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
  # A test hook: a read that fails once a given remove call has happened (the read-back after a removal), as a dropped connection does.
  if ($global:S.FailReadUrl -and $Url -match $global:S.FailReadUrl -and @($global:S.Calls) -contains $global:S.FailReadAfter) { throw 'FAKE 500: the read-back failed' }
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
# A fake list item: like a real one, it throws for a column that was not named in -Fields.
Add-Type -TypeDefinition @'
public class FakeItem {
  private System.Collections.Generic.Dictionary<string, object> d = new System.Collections.Generic.Dictionary<string, object>();
  public int Id;
  public object this[string k] {
    get { if (!d.ContainsKey(k)) { throw new System.InvalidOperationException("FAKE: the column " + k + " was not loaded (-Fields)"); } return d[k]; }
    set { d[k] = value; }
  }
}
'@
# Fake Get-PnPListItem: the rows of one of the 3 fake row lists as items that hold only the columns named in -Fields (all when none
# is named); throws for another list.
function Get-PnPListItem {
  [CmdletBinding()] param([string]$List, [string[]]$Fields, [int]$PageSize)
  if (-not $global:S.Rows.ContainsKey($List)) { throw ('FAKE: no list titled ' + $List) }
  return @($global:S.Rows[$List] | ForEach-Object {
      $row = $_; $it = New-Object FakeItem; $it.Id = [int]$row.Id
      $names = $(if ($Fields) { $Fields } else { @($row.Keys) })
      foreach ($k in $names) { $it[$k] = $(if ($row.ContainsKey($k)) { $row[$k] } else { $null }) }
      $it })
}
<#
.SYNOPSIS
  Fake Add-PnPListItem, strict as SharePoint is: the schema of PFM Publications decides. An unknown column, a missing required column, a
  choice that is not a choice of the schema, or a lookup number that is not a row of the target list throws.
.DESCRIPTION
  A stored lookup reads back as a value object (LookupId), a link as an object with Url. Other lists: stored as given (the publication
  lookup as a value object).
.PARAMETER List
  The title of the list.
.PARAMETER Values
  The column values (internal name to value).
.OUTPUTS
  System.Management.Automation.PSObject. The new row, with its Id.
#>
function Add-PnPListItem {
  [CmdletBinding()] param([string]$List, [hashtable]$Values)
  $global:S.RowNext++; $row = @{ Id = $global:S.RowNext }
  $cols = @{}; foreach ($fld in $global:PubSchema.fields) { $cols[[string]$fld.internalName] = $fld }
  foreach ($k in $Values.Keys) {
    $v = $Values[$k]
    if ($List -eq 'PFM Publications') {
      if (-not $cols.ContainsKey($k)) { throw ('FAKE: PFM Publications has no column ' + $k) }
      $f = $cols[$k]
      if ($f.type -eq 'Choice' -and @($f.choices) -cnotcontains [string]$v) { throw ('FAKE: ' + $k + ' is not a choice: ' + $v) }
      if ($f.type -eq 'Lookup') {
        $target = @{ PFMOffices = 'PFM Offices'; PFMProcessSteps = 'PFM Process Steps'; PFMSeries = 'PFM Series'; PFMProductIndex = 'PFM Product Index' }[[string]$f.lookup.list]
        $has = $target -and $global:S.Rows.ContainsKey($target) -and @($global:S.Rows[$target] | Where-Object { $_.Id -eq [int]$v }).Count
        if (-not $has) { throw ('FAKE: no row ' + $v + ' for the lookup ' + $k) }
        $v = [pscustomobject]@{ LookupId = [int]$v }
      }
      if ($f.type -eq 'URL') {
        if ([string]$v -notmatch '^https?://[^,\s]+(, .+)?$') { throw ('FAKE: not an address for ' + $k) }
        $v = [pscustomobject]@{ Url = ([string]$v -split ', ', 2)[0]; Description = $(if (([string]$v).Contains(', ')) { ([string]$v -split ', ', 2)[1] } else { '' }) }
      }
    } elseif ($k -eq 'Publication') { $v = [pscustomobject]@{ LookupId = [int]$v } }
    $row[$k] = $v
  }
  if ($List -eq 'PFM Publications') {
    foreach ($fld in $global:PubSchema.fields) { if ($fld.required -and -not $row.ContainsKey([string]$fld.internalName)) { throw ('FAKE: required column ' + $fld.internalName + ' missing') } }
  }
  $null = $global:S.Rows[$List].Add($row); return (New-Object psobject -Property @{ Id = $row.Id })
}
# Fake Set-PnPListItem: sets fields of one row, and logs the call.
function Set-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [hashtable]$Values)
  $hit = @($global:S.Rows[$List] | Where-Object { $_.Id -eq $Identity }); if (-not $hit.Count) { throw 'FAKE 404 row' }
  foreach ($k in $Values.Keys) { $hit[0][$k] = [pscustomobject]@{ LookupId = [int]$Values[$k] } }   # a lookup reads back as its value object
  $null = $global:S.Calls.Add('row:' + $List)
  if ($global:S.BlankOnMove) { $hit[0][$global:S.BlankOnMove] = $null }   # a test hook: a column that the move clears
}
# Run one part against the fake site. Takes the part name; returns @{ Code; Text (the screen output); File (the result file text) }.
function Invoke-T27([string]$Part) {
  $global:LASTEXITCODE = 0; $global:S.Calls.Clear(); $global:S.Connects = 0; $global:SignedInTo = ''   # each RADE step is a new process: no connection
  $out = & $script -Id 'tester01' -Part $Part -NoPause -TestDir $t27 *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t27 ('90161Z-T27-' + $Part.ToLowerInvariant() + '-r3.txt')
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
# Add a fake publication row with every exit condition of step 1 met; $Extra overrides columns (a $null value clears one). Returns nothing.
function Add-FakePub([int]$Id, [hashtable]$Extra = @{}, [string]$Title = '90161Z TEST R41 endorse (delete me)') {
  $row = @{ Id = $Id; Title = $Title; ActionType = 'New'; ProductType = 'Publication'; ProcessStep = [pscustomobject]@{ LookupId = 201 }; ActionStatus = 'On Track'
    PublicationType = 'Instruction'; Product = $null; OPR = [pscustomobject]@{ LookupId = 301 }; AppliesToLevel = 'Wing and Units Below'
    MasterForm673Link = [pscustomobject]@{ Url = 'https://example.test/fake673' } }
  foreach ($k in $Extra.Keys) { $row[$k] = $Extra[$k] }
  $null = $global:S.Rows['PFM Publications'].Add($row)
}
# The row of one fake publication. Takes its number; returns the row hashtable.
function Get-FakePub([int]$Id) { return @($global:S.Rows['PFM Publications'] | Where-Object { $_.Id -eq $Id })[0] }
try {
  New-Site
  # ---- the own-name table and the one-home checks ----
  . (Join-Path $Root 'scripts/gov/90161Z-T27-made-r2.ps1')
  $rev = @($internal); [array]::Reverse($rev)
  Test-That 'the own-list table has the 12 internal names of the payload, in reverse payload order' ((@($OwnLists.Keys) -join ',') -ceq ($rev -join ',')) ((@($OwnLists.Keys) -join ','))
  $bad = @($OwnLists.Keys | Where-Object { $OwnLists[$_] -cne $display[$_] })
  Test-That 'the own-list table has the display title of each list as the payload sets it' ($bad.Count -eq 0) ($bad -join ',')
  $man = Get-Content -LiteralPath (Join-Path $Root 'scripts/paste_bundles.json') -Raw | ConvertFrom-Json
  $back = @(@($man.bundles | ForEach-Object { $_.apps } | Where-Object { $_.mode -eq 'deploy' }) | ForEach-Object { $_.backup })
  Test-That 'the own-list titles equal the "backup" lists of the deploy app in the manifest' ((@($OwnLists.Values | Sort-Object) -join '|') -ceq (@($back | Sort-Object) -join '|')) ''
  $t26txt = Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T26-endorse-r5.ps1') -Raw
  $chk = Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T27-check-r2.ps1') -Raw
  $a = [regex]::Match($t26txt, "(?m)^\`$PubTitle = '([^']+)'").Groups[1].Value; $b = [regex]::Match($chk, "(?m)^\`$PubTitle = '([^']+)'").Groups[1].Value
  $c = [regex]::Match($t26txt, "(?m)^\`$StateName = '([^']+)'").Groups[1].Value; $d = [regex]::Match($chk, "(?m)^\`$T26State = '([^']+)'").Groups[1].Value
  . (Join-Path $Root 'scripts/gov/90161Z-T27-check-r2.ps1')
  $schema = Get-Content -LiteralPath (Join-Path $Root 'schemas/lists/PFMPublications.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $req = @($schema.fields | Where-Object { $_.required } | ForEach-Object { [string]$_.internalName })
  $sameReq = ((@($PubRequired | Sort-Object) -join ',') -ceq (@($req | Sort-Object) -join ','))
  Test-That 'the required columns of the step check equal the "required" columns of the PFM Publications schema' $sameReq ($req -join ',')
  $allCols = @($schema.fields | ForEach-Object { [string]$_.internalName })
  Test-That 'every column the step check reads is a column of the PFM Publications schema' (@($PubFields | Where-Object { $allCols -cnotcontains $_ }).Count -eq 0) ''
  Test-That 'the fake publication title and the state file name equal the ones of T26' ($a -and $a -ceq $b -and $c -and $c -ceq $d) ($a + ' / ' + $b)

  # ---- Uninstall, Lists ----
  Set-Made (Get-ListEntry $internal)
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and (Get-OwnLeft).Count -eq 0 -and @($global:S.Lists).Count -eq 1 -and $global:S.Lists[0].Title -eq 'Budget Notes')
  Test-That 'Lists removes the 12 own lists and leaves the list of a person' $ok $r.File
  $order = (@($global:S.Calls) -join ','); $want = (@($rev | ForEach-Object { 'list:' + $_ }) -join ',')
  Test-That 'Lists removes a list before the lists it points to (reverse payload order)' ($order -ceq $want) $order
  Test-That 'Lists prints RESULT UNINSTALL LISTS PASS removed=12 and 12 PASS read-backs' ($r.File -match '(?m)^RESULT UNINSTALL LISTS PASS removed=12\r?$' -and
      ([regex]::Matches($r.File, '(?m)^ITEM r-\S+ PASS')).Count -eq 12) $r.File
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and $r.File -match '(?m)^RESULT UNINSTALL LISTS SKIP removed=0\r?$' -and
      ([regex]::Matches($r.File, '(?m)^ITEM l\d\d-\S+ SKIP the list is not on the site')).Count -eq 12)
  Test-That 'a second Lists run removes nothing and prints SKIP (12 SKIP items, exit 0)' $ok $r.File

  # The 12 lists were made before RADE installs: the made list is empty (or names 2 lists, or other things), and all 12 still go, by title.
  New-Site; Set-Made @()
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and (Get-OwnLeft).Count -eq 0 -and @($global:S.Lists).Count -eq 1 -and $r.File -match '(?m)^MADE entries=0;' -and
      $r.File -match '(?m)^RESULT UNINSTALL LISTS PASS removed=12')
  Test-That 'Lists with an EMPTY made list removes the 12 own lists by title (RADE has no record of them) and keeps the list of a person' $ok $r.File
  New-Site; Set-Made (Get-ListEntry @('PFMSeries', 'PFMGuidance'))
  $r = Invoke-T27 'Lists'
  Test-That 'Lists with a made list of 2 lists still removes all 12' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and (Get-OwnLeft).Count -eq 0) $r.File
  New-Site; Set-Made @(@{ kind = 'group'; name = 'PFM Office' })
  $r = Invoke-T27 'Lists'
  Test-That 'Lists with a made list that has no list entry removes the 12 own lists' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and (Get-OwnLeft).Count -eq 0) $r.File

  # A list that is not ours stays: own title and another folder; own folder and another title; a similar title (suffix, case, space).
  New-Site; Remove-FakeList { $_.Folder -eq 'PFMSeries' }; Add-FakeList 'Lists/SeriesByHand' 'PFM Series'; Set-Made @()
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 11 -and @($global:S.Lists | Where-Object { $_.Folder -eq 'Lists/SeriesByHand' }).Count -eq 1 -and
      $r.File -match '(?m)^ITEM l\d\d-PFMSeries SKIP a list with this title is on the site, but it is not ours')
  Test-That 'a list with an own title but another folder name is never removed (SKIP, own 11 go)' $ok $r.File
  New-Site; Add-FakeList 'Lists/Copy1' 'PFM Series (copy)'; Add-FakeList 'Lists/Copy2' 'pfm series'; Add-FakeList 'Lists/Copy3' 'PFM Series '
  Add-FakeList 'Lists/Copy4' 'PFM Offices 2'; Set-Made @()
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and @($global:S.Lists | Where-Object { $_.Folder -like 'Lists/Copy*' }).Count -eq 4 -and (Get-OwnLeft).Count -eq 0)
  Test-That 'foreign lists with a similar title (suffix, other case, trailing space) stay; the 12 own lists go' $ok $r.File
  New-Site; ($global:S.Lists | Where-Object { $_.Folder -eq 'PFMSettings' }).Title = 'PFM Settings (old)'; Set-Made @()
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 11 -and @($global:S.Lists | Where-Object { $_.Folder -eq 'PFMSettings' }).Count -eq 1 -and
      $r.File -match '(?m)^ITEM l\d\d-PFMSettings SKIP the list with this folder name has another title' -and $r.File -notmatch '\(old\)')
  Test-That 'a list of an own folder whose title is not the fixed title stays (SKIP, the title is not printed)' $ok $r.File
  New-Site; ($global:S.Lists | Where-Object { $_.Folder -eq 'PFMSettings' }).Title = 'PFMSettings'; Set-Made @()
  $r = Invoke-T27 'Lists'
  Test-That 'a list that a stopped install left under its internal name as title is removed' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and (Get-OwnLeft).Count -eq 0) $r.File

  New-Site; Set-Made @(@{ kind = 'list'; name = 'Budget Notes' }, @{ kind = 'list'; name = 'Documents' }, @{ kind = 'group'; name = 'PFM Series' }, @{ kind = 'list'; name = 'PFMSeries' })
  $r = Invoke-T27 'Lists'
  $ok = ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and (Get-OwnLeft).Count -eq 0 -and @($global:S.Lists | Where-Object { $_.Title -eq 'Budget Notes' }).Count -eq 1 -and
      ([regex]::Matches($r.File, '(?m)^NOTE refused')).Count -eq 3)
  Test-That 'names in the made list that are not ours are refused (NOTE) and never removed; the 12 own lists go' $ok $r.File

  New-Site; Set-Made (Get-ListEntry @('PFMSeries', 'PFMGuidance')); $global:S.FailList = 'PFMSeries'
  $r = Invoke-T27 'Lists'; $global:S.FailList = $null
  $ok = ($r.Code -eq 1 -and $global:S.Calls.Count -eq 11 -and $r.File -match '(?m)^ITEM r-PFMGuidance PASS' -and $r.File -match '(?m)^ITEM l\d\d-PFMSeries FAIL' -and
      $r.File -match '(?m)^RESULT UNINSTALL LISTS FAIL removed=11')
  Test-That 'a list that cannot be removed: FAIL, exit 1, the other 11 are still removed' $ok $r.File
  $r = Invoke-T27 'Lists'
  Test-That 'Lists run again after that failure removes the list that is left' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 1 -and
      $r.File -match '(?m)^RESULT UNINSTALL LISTS PASS removed=1') $r.File


  # A throw after a removal (the read-back, the level lookup) is a FAIL with a RESULT line, and counts as failed (R43 review).
  New-Site; Set-Made @()
  $global:S.FailReadUrl = '/_api/web/lists\?'; $global:S.FailReadAfter = 'list:PFMReviews'
  $r = Invoke-T27 'Lists'; $global:S.FailReadUrl = $null
  $ok = ($r.Code -eq 1 -and $r.File -match '(?m)^STOPPED:' -and $r.File -match '(?m)^RESULT UNINSTALL LISTS FAIL removed=\d+' -and $r.File -match '(?m)^LIFECYCLE Lists done: .*failed=[1-9]')
  Test-That 'Lists: the read-back of the site fails after a removal: STOPPED, RESULT UNINSTALL LISTS FAIL, failed is not 0, exit 1' $ok $r.File
  New-Site; Set-Made @(@{ kind = 'group'; name = 'PFM Office' }, @{ kind = 'level'; name = 'PFM Office Edit All Items' })
  $global:S.FailReadUrl = '/_api/web/sitegroups'; $global:S.FailReadAfter = 'group:PFM Office'
  $r = Invoke-T27 'Access'; $global:S.FailReadUrl = $null
  $ok = ($r.Code -eq 1 -and $r.File -match '(?m)^STOPPED:' -and $r.File -match '(?m)^RESULT UNINSTALL ACCESS FAIL removed=\d+' -and $r.File -match '(?m)^LIFECYCLE Access done: .*failed=[1-9]')
  Test-That 'Access: the group read-back fails after the group is removed: RESULT UNINSTALL ACCESS FAIL, failed is not 0, exit 1' $ok $r.File
  New-Site; Set-Made @(@{ kind = 'level'; name = 'PFM Office Edit All Items' })
  $global:S.FailReadUrl = '/_api/web/roledefinitions'; $global:S.FailReadAfter = 'level:PFM Office Edit All Items'
  $r = Invoke-T27 'Access'; $global:S.FailReadUrl = $null
  $ok = ($r.Code -eq 1 -and $r.File -match '(?m)^RESULT UNINSTALL ACCESS FAIL removed=\d+' -and $r.File -match '(?m)^LIFECYCLE Access done: .*failed=[1-9]')
  Test-That 'Access: the level lookup fails after the level is removed: RESULT UNINSTALL ACCESS FAIL, failed is not 0, exit 1' $ok $r.File

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
  Test-That 'an entry with no step, kind or name is dropped and counted, never used (the lists go by title anyway)' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 12 -and
      $r.File -match '(?m)^MADE entries=1; without step, kind or name=2') $r.File

  # ---- Uninstall, Access: the group and the level go only when RADE_MADE names them (the PFM, 25 Nov 26) ----
  $both = 'group:PFM Office,level:PFM Office Edit All Items'
  New-Site; Set-Made @(@{ kind = 'group'; name = 'PFM Office' }, @{ kind = 'level'; name = 'PFM Office Edit All Items' })
  $r = Invoke-T27 'Access'
  $ok = ($r.Code -eq 0 -and (@($global:S.Calls) -join ',') -ceq $both -and $global:S.Groups -contains 'Site Owners' -and
      $global:S.Levels -contains 'Edit' -and $global:S.Groups.Count -eq 1)
  Test-That 'Access with both named removes the group, then the level, and not the site owners group or the Edit level' $ok $r.File
  Test-That 'Access prints RESULT UNINSTALL ACCESS PASS removed=2' ($r.File -match '(?m)^RESULT UNINSTALL ACCESS PASS removed=2\r?$') $r.File
  $r = Invoke-T27 'Access'
  Test-That 'a second Access run removes nothing and prints SKIP' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and $r.File -match '(?m)^RESULT UNINSTALL ACCESS SKIP removed=0' -and
      $r.File -match '(?m)^ITEM a1-group SKIP' -and $r.File -match '(?m)^ITEM a2-level SKIP') $r.File
  New-Site; Set-Made @()
  $r = Invoke-T27 'Access'
  Test-That 'Access with an EMPTY made list: the group and the level stay (no remove call), SKIP "not made by the install", RESULT SKIP, exit 0' ($r.Code -eq 0 -and
      $global:S.Calls.Count -eq 0 -and $global:S.Groups -contains 'PFM Office' -and $global:S.Levels -contains 'PFM Office Edit All Items' -and
      $r.File -match '(?m)^ITEM a1-group SKIP not made by the install' -and $r.File -match '(?m)^ITEM a2-level SKIP not made by the install' -and
      $r.File -match '(?m)^RESULT UNINSTALL ACCESS SKIP removed=0') $r.File
  New-Site; Set-Made (Get-ListEntry @('PFMSeries'))
  $r = Invoke-T27 'Access'
  Test-That 'Access with a made list that names only a list: the group and the level stay' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and
      $global:S.Groups -contains 'PFM Office' -and $global:S.Levels -contains 'PFM Office Edit All Items' -and $r.File -match '(?m)^RESULT UNINSTALL ACCESS SKIP removed=0') $r.File
  New-Site; Set-Made @(@{ kind = 'group'; name = 'PFM Office' })
  $r = Invoke-T27 'Access'
  Test-That 'Access with only the group named: the group goes, the level stays (SKIP)' ($r.Code -eq 0 -and (@($global:S.Calls) -join ',') -ceq 'group:PFM Office' -and
      $global:S.Levels -contains 'PFM Office Edit All Items' -and $r.File -match '(?m)^ITEM a2-level SKIP not made by the install' -and
      $r.File -match '(?m)^RESULT UNINSTALL ACCESS PASS removed=1') $r.File
  New-Site; Set-Made @(@{ kind = 'level'; name = 'PFM Office Edit All Items' })
  $r = Invoke-T27 'Access'
  Test-That 'Access with only the level named: the level goes, the group stays (SKIP)' ($r.Code -eq 0 -and (@($global:S.Calls) -join ',') -ceq 'level:PFM Office Edit All Items' -and
      $global:S.Groups -contains 'PFM Office' -and $r.File -match '(?m)^ITEM a1-group SKIP not made by the install' -and
      $r.File -match '(?m)^RESULT UNINSTALL ACCESS PASS removed=1') $r.File
  New-Site; Set-Made @(@{ kind = 'group'; name = 'Site Owners' }, @{ kind = 'level'; name = 'Edit' }, @{ kind = 'group'; name = 'pfm office' },
    @{ kind = 'level'; name = 'PFM Office Edit All Items 2' })
  $r = Invoke-T27 'Access'
  Test-That 'a group or a level that is not ours (also a near name) is refused (NOTE) and stays; our pair stays too, as it is not named' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and
      $global:S.Groups.Count -eq 2 -and $global:S.Groups -contains 'Site Owners' -and $global:S.Groups -contains 'PFM Office' -and $global:S.Levels.Count -eq 2 -and
      ([regex]::Matches($r.File, '(?m)^NOTE refused')).Count -eq 4 -and $r.File -match '(?m)^RESULT UNINSTALL ACCESS SKIP removed=0') $r.File
  New-Site; Set-Made @(@{ kind = 'group'; name = 'Site Owners' }, @{ kind = 'level'; name = 'Edit' }, @{ kind = 'group'; name = 'PFM Office' }, @{ kind = 'level'; name = 'PFM Office Edit All Items' })
  $r = Invoke-T27 'Access'
  Test-That 'a foreign group and level named next to our pair always stay; our pair goes' ($r.Code -eq 0 -and (@($global:S.Calls) -join ',') -ceq $both -and
      $global:S.Groups.Count -eq 1 -and $global:S.Groups -contains 'Site Owners' -and $global:S.Levels.Count -eq 1 -and $global:S.Levels -contains 'Edit' -and
      ([regex]::Matches($r.File, '(?m)^NOTE refused')).Count -eq 2) $r.File

  # ---- Uninstall, Local ----
  foreach ($f in '90161Z-T22-install-r21.txt', '90161Z-T22-maint-r21.txt', 'keep.txt') { Set-Content -LiteralPath (Join-Path $t22 $f) -Value 'x' }
  New-Site; Set-Made @(@{ kind = 'file'; name = '90161Z-T22-install-r21.txt' })
  $r = Invoke-T27 'Local'
  $left = @(Get-ChildItem -LiteralPath $t22 | ForEach-Object { $_.Name } | Sort-Object)
  Test-That 'Local removes only the install note named in the made file, with no sign-in' ($r.Code -eq 0 -and $global:S.Connects -eq 0 -and
      ($left -join ',') -ceq '90161Z-T22-maint-r21.txt,keep.txt' -and $r.File -match '(?m)^RESULT UNINSTALL LOCAL PASS removed=1') $r.File
  $r = Invoke-T27 'Local'
  Test-That 'a second Local run prints SKIP' ($r.Code -eq 0 -and $r.File -match '(?m)^RESULT UNINSTALL LOCAL SKIP removed=0' -and $r.File -match '(?m)^ITEM f01-note SKIP') $r.File
  Set-Made @(@{ kind = 'file'; name = 'keep.txt' }, @{ kind = 'file'; name = '..\T26\90161Z-T22-install-r1.txt' }, @{ kind = 'file'; name = '90161Z-T22-maint-r21.txt' })
  $r = Invoke-T27 'Local'
  $left = @(Get-ChildItem -LiteralPath $t22 | ForEach-Object { $_.Name } | Sort-Object)
  Test-That 'Local refuses any other file and any path: nothing else is removed' ($r.Code -eq 0 -and ($left -join ',') -ceq '90161Z-T22-maint-r21.txt,keep.txt' -and
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
  Add-FakePub 50
  Add-FakePub 51 @{ OPR = $null } 'Another publication'   # another publication, with a missing condition: it must never be read or moved
  $null = $global:S.Rows['PFM Activity Log'].Add(@{ Id = 70; Title = 'FAKE log'; Publication = [pscustomobject]@{ LookupId = 50 } })
  $r = Invoke-T27 'Step'
  $now = (Get-FakePub 50).ProcessStep.LookupId; $other = (Get-FakePub 51).ProcessStep.LookupId
  $ok = ($r.Code -eq 0 -and $now -eq 202 -and $other -eq 201 -and $global:S.Calls.Count -eq 1 -and $r.File -match '(?m)^ITEM s2-move PASS moved from step 1 to step 2' -and
      $r.File -match '(?m)^RESULT STEP PASS from=1 to=2 target-days=60')
  Test-That 'Step moves the fake publication from step 1 to step 2, reads it back, and leaves another publication alone' $ok $r.File
  $names = '1-saved', '2-product', '3-opr', '4-directive', '5-level', '6-form673'
  $okB = @($names | Where-Object { $r.File -match ('(?m)^ITEM b' + $_ + ' PASS exit condition of step 1') }).Count
  $okA = @($names | Where-Object { $r.File -match ('(?m)^ITEM a' + $_ + ' PASS exit condition of step 1') }).Count
  Test-That 'Step checks the 6 exit conditions of step 1 before the move (b) and again after it (a): all PASS' ($okB -eq 6 -and $okA -eq 6 -and
      $r.File.IndexOf('ITEM b1-saved') -lt $r.File.IndexOf('ITEM s2-move') -and $r.File.IndexOf('ITEM s2-move') -lt $r.File.IndexOf('ITEM a1-saved')) $r.File
  Test-That 'Step writes a NOTE for what the lists cannot show (PFM confirms; the actions of 3.1.2 to 3.1.8)' (
      $r.File -match '(?m)^NOTE not shown by the lists, so not checked: "PFM confirms"' -and $r.File -match '3\.1\.2 to 3\.1\.8') $r.File
  Test-That 'Step reports the target days of step 2 and the activity log rows as information' ($r.File -match 'target business days of step 2=60; activity log rows on the publication=1') $r.File
  $r = Invoke-T27 'Step'
  Test-That 'a second Step writes nothing, prints SKIP for the move and checks the conditions again' ($r.Code -eq 0 -and $global:S.Calls.Count -eq 0 -and
      $r.File -match '(?m)^ITEM s2-move SKIP' -and $r.File -match '(?m)^ITEM b6-form673 PASS' -and $r.File -match '(?m)^ITEM a6-form673 PASS') $r.File

  # An exit condition of step 1 that is not met stops the move (no write): one case for each condition and each way to miss it.
  $miss = @(
    @('1-saved', 'a required column (Action Status) is blank', @{ ActionStatus = $null }),
    @('1-saved', 'a required column (Action Type) is blank', @{ ActionType = '' }),
    @('2-product', 'the action is a Rewrite and the product is not named', @{ ActionType = 'Rewrite' }),
    @('3-opr', 'the OPR is not named', @{ OPR = $null }),
    @('3-opr', 'the OPR lookup is empty (number 0)', @{ OPR = [pscustomobject]@{ LookupId = 0 } }),
    @('4-directive', 'a publication has no publication type', @{ PublicationType = $null }),
    @('5-level', 'the scope level is blank', @{ AppliesToLevel = '  ' }),
    @('6-form673', 'the master 673 link is not set', @{ MasterForm673Link = $null }),
    @('6-form673', 'the master 673 link has no address', @{ MasterForm673Link = [pscustomobject]@{ Url = '' } }))
  foreach ($m in $miss) {
    New-Site; Add-FakePub 60 $m[2]
    $r = Invoke-T27 'Step'
    $ok = ($r.Code -eq 1 -and $global:S.Calls.Count -eq 0 -and (Get-FakePub 60).ProcessStep.LookupId -eq 201 -and $r.File -match ('(?m)^ITEM b' + $m[0] + ' FAIL exit condition of step 1 not met') -and
        $r.File -match '(?m)^RESULT STEP FAIL exit conditions of step 1 not met: no move' -and $r.File -notmatch '(?m)^ITEM s2-move')
    Test-That ('Step: ' + $m[0].Substring(2) + ' not met (' + $m[1] + '): FAIL, exit 1, no write, still at step 1') $ok $r.File
  }
  # The conditions that hold in other cases.
  New-Site; Add-FakePub 61 @{ ActionType = 'Rewrite'; Product = [pscustomobject]@{ LookupId = 5 } }
  $r = Invoke-T27 'Step'
  Test-That 'Step: a Rewrite with a named product passes the product condition and moves' ($r.Code -eq 0 -and (Get-FakePub 61).ProcessStep.LookupId -eq 202) $r.File
  New-Site; Add-FakePub 62 @{ ProductType = 'Form'; PublicationType = $null }
  $r = Invoke-T27 'Step'
  Test-That 'Step: a form needs no publication type (the directive condition passes) and moves' ($r.Code -eq 0 -and (Get-FakePub 62).ProcessStep.LookupId -eq 202) $r.File
  New-Site; Add-FakePub 63 @{ ProcessStep = [pscustomobject]@{ LookupId = 205 } }
  $r = Invoke-T27 'Step'
  Test-That 'Step: a publication at neither step 1 nor step 2 is not moved: FAIL, exit 1, no write' ($r.Code -eq 1 -and $global:S.Calls.Count -eq 0 -and
      (Get-FakePub 63).ProcessStep.LookupId -eq 205 -and
      $r.File -match '(?m)^ITEM s1-publication FAIL .*neither step 1 nor step 2' -and $r.File -match '(?m)^RESULT STEP FAIL not at step 1') $r.File
  New-Site; Add-FakePub 64; $global:S.BlankOnMove = 'OPR'
  $r = Invoke-T27 'Step'; $global:S.BlankOnMove = $null
  Test-That 'Step: a condition that no longer holds after the move (the OPR is cleared) is found: FAIL, exit 1' ($r.Code -eq 1 -and $r.File -match '(?m)^ITEM s2-move PASS' -and
      $r.File -match '(?m)^ITEM a3-opr FAIL' -and
      $r.File -match '(?m)^RESULT STEP FAIL exit conditions of step 1 no longer hold after the move') $r.File
  New-Site; Add-FakePub 65
  $r = Invoke-T27 'Step'
  Test-That 'Step reads only the columns it names in -Fields (the fake item throws for any other column): no STOPPED line' ($r.Code -eq 0 -and $r.File -notmatch '(?m)^STOPPED') $r.File
  # The fake publication of T26 Make (R43; the PFM, 25 Nov 26): the exit conditions of step 1 hold on what T26 Make really writes.
  New-Site
  $t26script = Join-Path $Root 'scripts/gov/90161Z-T26-endorse-r5.ps1'
  $global:LASTEXITCODE = 0; $null = & $t26script -Id 'tester01' -Part 'Make' -NoPause -NoLaunch -TestDir $t26 *>&1
  $made = @($global:S.Rows['PFM Publications'] | Where-Object { $_.Title -ceq $PubTitle })
  $r26 = $(if (Test-Path -LiteralPath (Join-Path $t26 '90161Z-T26-endorse-make-r5.txt')) { Get-Content -LiteralPath (Join-Path $t26 '90161Z-T26-endorse-make-r5.txt') -Raw } else { '' })
  Test-That 'T26 Make makes the fake publication on the strict fake site (the 4 columns are accepted by the schema rules)' ($LASTEXITCODE -eq 0 -and $made.Count -eq 1 -and
      $made[0].OPR.LookupId -eq 301 -and $made[0].MasterForm673Link.Url -ceq 'https://example.test/90161Z-TEST-673') $r26
  $r = Invoke-T27 'Step'
  $names = '1-saved', '2-product', '3-opr', '4-directive', '5-level', '6-form673'
  $okB = @($names | Where-Object { $r.File -match ('(?m)^ITEM b' + $_ + ' PASS exit condition of step 1') }).Count
  $okA = @($names | Where-Object { $r.File -match ('(?m)^ITEM a' + $_ + ' PASS exit condition of step 1') }).Count
  Test-That 'Step on the publication that T26 Make made: all 6 exit conditions of step 1 pass before (b) and after (a) the move, it moves, RESULT STEP PASS' ($r.Code -eq 0 -and
      $okB -eq 6 -and $okA -eq 6 -and $made[0].ProcessStep.LookupId -eq 202 -and $r.File -match '(?m)^RESULT STEP PASS from=1 to=2') $r.File
  Remove-Item -LiteralPath (Join-Path $t26 '90161Z-T26-endorse-state-r4.txt') -ErrorAction SilentlyContinue
  New-Site; Add-FakePub 66
  Remove-FakeStepRow 2
  $r = Invoke-T27 'Step'
  Test-That 'Step with no step 2 row (the install did not seed it): FAIL, exit 1' ($r.Code -eq 1 -and $r.File -match '(?m)^RESULT STEP FAIL no step rows') $r.File

  # ---- R47: the Uninstall parts Lists, Access and Local in one T30 batch step: one sign-in, then "SIGNIN reused", one sign-out ----
  Set-Content -LiteralPath (Join-Path $t22 '90161Z-T22-install-r21.txt') -Value 'x'
  $extra = @(@{ kind = 'group'; name = 'PFM Office' }, @{ kind = 'level'; name = 'PFM Office Edit All Items' }, @{ kind = 'file'; name = '90161Z-T22-install-r21.txt' })
  New-Site; Set-Made (@(Get-ListEntry $internal) + $extra)
  $global:S.Calls.Clear(); $global:S.Connects = 0; $global:SignedInTo = ''; $global:SignOuts = 0; $global:LASTEXITCODE = 0
  $batch = Join-Path $Root 'scripts/gov/90161Z-T30-batch-r1.ps1'
  $out = @(& $batch -Id 'tester01' -NoPause -Run 'T27:Lists;T27:Access;T27:Local' -ScriptRoot (Join-Path $Root 'scripts/gov') -TestRoot $work *>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE; $txt = $out -join "`n"
  $ok = ($code -eq 0 -and $global:S.Connects -eq 1 -and $global:SignOuts -eq 1 -and ([regex]::Matches($txt, '(?m)^SIGNIN reused')).Count -eq 1 -and
      (Get-OwnLeft).Count -eq 0 -and $global:S.Groups -notcontains 'PFM Office' -and -not (Test-Path -LiteralPath (Join-Path $t22 '90161Z-T22-install-r21.txt')) -and
      $txt -match '(?m)^RESULT UNINSTALL LISTS PASS removed=12' -and $txt -match '(?m)^RESULT UNINSTALL ACCESS PASS removed=2' -and
      $txt -match '(?m)^RESULT UNINSTALL LOCAL PASS removed=1' -and $txt -match '(?m)^BATCH done: parts=3 exit-not-zero=0' -and -not $env:KANON_KEEP_SIGNIN)
  Test-That 'T30 batch Lists, Access, Local in Uninstall mode: 1 sign-in, the second part reuses it, 1 sign-out at the end, all 3 parts done, exit 0' $ok $txt
  # A part that fails does not stop the parts after it, and the batch ends with exit code 1 (the made list is refused for Lists and Access).
  New-Site; Set-Made (Get-ListEntry $internal) -Mode 'install'; $global:S.Connects = 0; $global:SignedInTo = ''; $global:SignOuts = 0; $global:LASTEXITCODE = 0
  $out = @(& $batch -Id 'tester01' -NoPause -Run 'T27:Lists;T27:Install:before' -ScriptRoot (Join-Path $Root 'scripts/gov') -TestRoot $work *>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE; $txt = $out -join "`n"
  Test-That 'T30 batch: a failed part (the gate) is followed by the next part, and the batch exits 1' ($code -eq 1 -and $txt -match '(?m)^RESULT UNINSTALL LISTS FAIL' -and
      $txt -match '(?m)^BATCH part 2 of 2: T27 Install before, exit code 0' -and $txt -match '(?m)^BATCH done: parts=2 exit-not-zero=1' -and $global:S.Connects -eq 1 -and
      (Test-Path -LiteralPath (Join-Path $t27 '90161Z-T27-install-before-r3.txt'))) $txt
  $env:RADE_MADE = $null; $env:RADE_MODE = $null

  # ---- every result file ----
  $all = Get-ChildItem -LiteralPath $t27 -Filter '*.txt' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
  Test-That 'no result line shows the site host' (-not (@($all) -join "`n").Contains('fakehost')) ''
  foreach ($f in 'lifecycle-r3', 'made-r2', 'check-r2') {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $Root ('scripts/gov/90161Z-T27-' + $f + '.ps1')))
    Test-That ('the file 90161Z-T27-' + $f + '.ps1 is ASCII') (-not @($bytes | Where-Object { $_ -gt 127 }).Count) ''
  }
} finally {
  Set-Location -LiteralPath $Root
  $env:RADE_MADE = $null; $env:RADE_MODE = $null
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('T27 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
