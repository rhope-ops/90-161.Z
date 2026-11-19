<#
.SYNOPSIS
  90-161.Z Task 20 list provisioning r4, module "access": step 6 (the PFM Office level), step 7 (Contribute for the Visitors
  group on the intake lists, r4) and the read-backs of the level and of the access to the 12 lists (PFM 19 Nov 26: R34 plan,
  open point 12). r4 (R36): steps 6 and 7 moved here from the main file (code standard file size cap); the code is unchanged.
.DESCRIPTION
  Loaded by 90161Z-T20-provision-lists-r4.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values and helpers of the main file ($OfficeGroup, Invoke-Rest, Get-SiteList, Write-CsomMerge,
  Get-GroupId, Get-RoleLevel, Get-WebBinding, Test-LevelPermission, Get-RestValue, Find-OurList). Outputs: one ITEM line
  from each read-back; the step functions return their counts.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection of the main file.
  Writes: step 6: the group PFM Office, its level and that level on the site, when missing; step 7: Contribute for the
          Visitors group on the 3 intake lists (own permissions), when missing. The read-backs write nothing.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T20-provision-lists-r4.ps1 loads it.
#>

# Step 6 (moved from the main file in R36): the texts of the group PFM Office (its name $OfficeGroup stays in the main file).
$OfficeGroupText = 'Publications and Forms Manager (PFM) office: the people who work the PFM organization box (90-161.Z).'
# The site's Edit level plus Override List Behaviors: Edit lacks it, and only it lets a person edit every row of a list set to
# "edit own rows" (PFM Publications and PFM Endorsements, PFM 10A), so the Alternate and the Acting PFM need it (sweep F2).
$OfficeLevel = 'PFM Office Edit All Items'
$OfficeLevelText = 'Edit, plus Override List Behaviors: edits every row, also on lists set to edit own rows (90-161.Z, PFM 2026-11-19).'
# SharePoint permission bit (SP.BasePermissions, low word): CancelCheckout 0x100 ("Override List Behaviors"); EditListItems is below.
$OverrideBit = [long]0x100
# The RoleTypeKind of the site's Edit level (SP.RoleType Editor = 6): found by kind, so a site in another language works too.
$EditRoleKind = 6
# SharePoint permission bit (SP.BasePermissions, low word): EditListItems 0x4.
$EditItemsBit = [long]0x4

<#
.SYNOPSIS
  Step 7, the read-back of step 6 (the level and the group on the site): PASS when the group holds the level on the site and the level holds Edit plus Edit Items and
  Override List Behaviors; else FAIL (typed list: PS 5.1).
.OUTPUTS
  System.String. One ITEM line.
#>
function Test-OfficeLevel {
  $gid = Get-GroupId $OfficeGroup; $level = Get-RoleLevel $OfficeLevel 0; $edit = Get-RoleLevel '' $EditRoleKind
  $bad = New-Object System.Collections.Generic.List[string]; $need = [long]($EditItemsBit -bor $OverrideBit); if ($level -and -not $edit) { $bad.Add('the site has no Edit level to compare') }
  if (-not $gid) { $bad.Add('the group ' + $OfficeGroup + ' is not on the site') }; if (-not $level) { $bad.Add('the level ' + $OfficeLevel + ' is not on the site') }
  if ($level -and $edit) { $ok = [bool](Test-LevelPermission $level $edit $need); if (-not $ok) { $bad.Add('the level lacks a permission of Edit or Override List Behaviors') } }
  if ($level -and $gid) { $held = @(Get-WebBinding $gid); if ($held -notcontains [int]$level.Id) { $bad.Add('the group does not hold the level on the site') } }
  if ($bad.Count -gt 0) { return ('ITEM P01-pfm-office FAIL ' + ($bad -join '; ') + ' (this script never changes a level that is there)') }
  return ('ITEM P01-pfm-office PASS the group "' + $OfficeGroup + '" holds the level "' + $OfficeLevel + '" on the site (Edit plus Override List Behaviors)')
}


<#
.SYNOPSIS
  The role bindings of a group on one list: the Ids of the permission levels it holds there; none when it holds none.
.PARAMETER ListId
  The list's id (the Id of a Get-SiteList entry).
.PARAMETER PrincipalId
  The group's Id.
.OUTPUTS
  System.Int32[]. The level Ids.
#>
function Get-ListBinding([string]$ListId, [int]$PrincipalId) {
  $uri = "_api/web/lists(guid'" + $ListId + "')/roleassignments/getbyprincipalid(" + $PrincipalId + ')/roledefinitionbindings?$select=Id'
  try { return @(Get-RestValue $uri | ForEach-Object { [int]$_.Id }) } catch { return @() }
}

<#
.SYNOPSIS
  Step 7, the read-back of the access to the app lists (R34 plan, open point 12): each of the lists of the plan either
  inherits its role assignments from the site (HasUniqueRoleAssignments false), or has its own and the group PFM Office holds
  the level PFM Office Edit All Items on that list; else FAIL, naming the lists. The reasons go in a typed list (PS 5.1).
.PARAMETER Plan
  The plan of the payload (Get-Plan): internal name to display title and settings.
.PARAMETER SiteLists
  The lists of the site (Get-SiteList), with HasUniqueRoleAssignments.
.OUTPUTS
  System.String. One ITEM line, with the counts.
#>
function Test-ListAccess($Plan, $SiteLists) {
  $bad = New-Object System.Collections.Generic.List[string]
  $gid = Get-GroupId $OfficeGroup; $level = Get-RoleLevel $OfficeLevel 0
  $inherit = 0; $own = 0
  foreach ($k in $Plan.Keys) {
    $name = [string]$Plan[$k].Display
    $l = Find-OurList $SiteLists $k
    if (-not $l) { $bad.Add($name + ' is not on the site'); continue }
    if (-not [bool]$l.HasUniqueRoleAssignments) { $inherit++; continue }
    $own++
    if (-not $gid -or -not $level) { $bad.Add($name + ' has its own permissions and the group or the level is not on the site'); continue }
    $held = @(Get-ListBinding ([string]$l.Id) $gid)
    if ($held -notcontains [int]$level.Id) { $bad.Add($name + ' has its own permissions and the group ' + $OfficeGroup + ' does not hold the level on it') }
  }
  if ($bad.Count -gt 0) { return ('ITEM P02-list-access FAIL lists that fail (' + $bad.Count + ' of ' + $Plan.Count + '): ' + ($bad -join '; ')) }
  $tail = ' have own permissions and the group "' + $OfficeGroup + '" holds the level "' + $OfficeLevel + '" on each'
  return ('ITEM P02-list-access PASS ' + $Plan.Count + ' lists: ' + $inherit + ' inherit from the site, ' + $own + $tail)
}

<#
.SYNOPSIS
  Step 6: the group PFM Office, the level PFM Office Edit All Items (the bits of the site's Edit level plus Override List
  Behaviors) and that level for the group on the site, each made only when it is missing (a second run changes nothing).
  A level with that name that is there is not changed.
.PARAMETER Write
  $true: make what is missing; $false (-DryRun): only count it.
.OUTPUTS
  System.Collections.Hashtable. group, level, binding: 1 when it was made (or a dry run would make it), else 0.
#>
function Grant-OfficeLevel([bool]$Write) {
  $made = @{ group = 0; level = 0; binding = 0 }
  $gid = Get-GroupId $OfficeGroup
  if (-not $gid) {
    $made.group = 1
    if ($Write) {
      Write-Host ('  Making the group ' + $OfficeGroup + ' ...')
      $null = Invoke-Rest 'Post' '_api/web/sitegroups' (@{ __metadata = @{ type = 'SP.Group' }; Title = $OfficeGroup; Description = $OfficeGroupText } | ConvertTo-Json -Compress)
      $gid = Get-GroupId $OfficeGroup
      if (-not $gid) { throw ('GROUP ' + $OfficeGroup + ' not on the site after the create step.') }
    }
  }
  $level = Get-RoleLevel $OfficeLevel 0
  if (-not $level) {
    $made.level = 1
    $edit = Get-RoleLevel '' $EditRoleKind
    if (-not $edit) { throw ('LEVEL Edit not found on the site: the level ' + $OfficeLevel + ' is made from it. The lists are done.') }
    if ($Write) {
      Write-Host ('  Making the permission level ' + $OfficeLevel + ' ...')
      $low = (ConvertTo-PermissionWord $edit.BasePermissions.Low) -bor $OverrideBit
      $bits = @{ __metadata = @{ type = 'SP.BasePermissions' }; High = [string](ConvertTo-PermissionWord $edit.BasePermissions.High); Low = [string]$low }
      $body = @{ __metadata = @{ type = 'SP.RoleDefinition' }; Name = $OfficeLevel; Description = $OfficeLevelText; BasePermissions = $bits }
      $null = Invoke-Rest 'Post' '_api/web/roledefinitions' ($body | ConvertTo-Json -Depth 5 -Compress)
      $level = Get-RoleLevel $OfficeLevel 0
      if (-not $level) { throw ('LEVEL ' + $OfficeLevel + ' not on the site after the create step.') }
    }
  }
  if (-not $gid -or -not $level) { $made.binding = 1; return $made }
  if ((Get-WebBinding $gid) -notcontains [int]$level.Id) {
    $made.binding = 1
    if ($Write) {
      Write-Host ('  Giving the level ' + $OfficeLevel + ' to the group ' + $OfficeGroup + ' ...')
      $null = Invoke-Rest 'Post' ('_api/web/roleassignments/addroleassignment(principalid=' + $gid + ',roledefid=' + [int]$level.Id + ')') '{}'
    }
  }
  return $made
}

# ---- Step 7 (r4): Contribute for the site's Visitors group on the intake lists (PFM 19 Nov 26; docs/roles-and-permissions.md section 7) ----
# The intake lists are the ones wing users write to through the app: the request (PFM Publications), the endorser entry (PFM
# Endorsements) and the DAF Form 847 intake (PFM Recommendations); docs/ARCHITECTURE.md (Data and UI rows, and the risk row on edit own rows).
$IntakeLists = @('PFMPublications', 'PFMEndorsements', 'PFMRecommendations')
# SP.RoleType Contributor = 3: found by kind, so a site in another language works too.
$ContributeRoleKind = 3

# The Id of the site's associated Visitors group (the people the site gives Read), or 0 when the site has none or it cannot be read.
function Get-VisitorGroupId {
  try { return [int]((Invoke-Rest 'Get' '_api/web/associatedvisitorgroup?$select=Id' '') | ConvertFrom-Json).Id } catch { return 0 }
}

<#
.SYNOPSIS
  Step 7: for each intake list that is on the site, makes the list's own permissions when it inherits (the site's role
  assignments are copied), then gives the Visitors group the level Contribute on that list when it does not hold it yet. Reads
  first and writes only what is missing, so a second run changes nothing. Never changes the site's own permissions.
.PARAMETER Write
  $true: make what is missing; $false (-DryRun): only count it.
.PARAMETER SiteLists
  The lists of the site (Get-SiteList). A list that is not there yet counts as one that would be made and given the role.
.OUTPUTS
  System.Collections.Hashtable. own (lists that got their own permissions) and granted (lists that got the role): counts; a dry run counts what it would do.
#>
function Grant-WingContribute([bool]$Write, $SiteLists) {
  $made = @{ own = 0; granted = 0 }
  $vid = Get-VisitorGroupId
  $level = Get-RoleLevel '' $ContributeRoleKind
  if ($Write -and ($vid -le 0 -or -not $level)) { return $made }   # the read-back names the cause
  foreach ($k in $IntakeLists) {
    $l = Find-OurList $SiteLists $k
    if (-not $l) { $made.own++; $made.granted++; continue }
    $base = "_api/web/lists(guid'" + $l.Id + "')"
    if (-not [bool]$l.HasUniqueRoleAssignments) {
      $made.own++
      # clearSubscopes=false: items that hold their own permissions keep them (R36 review).
      if ($Write) { $null = Invoke-Rest 'Post' ($base + '/breakroleinheritance(copyRoleAssignments=true,clearSubscopes=false)') '{}' }
    }
    $held = @()
    if ($vid -gt 0 -and [bool]$l.HasUniqueRoleAssignments) { $held = @(Get-ListBinding ([string]$l.Id) $vid) }
    if ($level -and $held -contains [int]$level.Id) { continue }
    $made.granted++
    if ($Write) {
      Write-Host ('  Giving Visitors Contribute on ' + $k + ' ...')
      $null = Invoke-Rest 'Post' ($base + '/roleassignments/addroleassignment(principalid=' + $vid + ',roledefid=' + [int]$level.Id + ')') '{}'
    }
  }
  return $made
}

<#
.SYNOPSIS
  Step 7, the read-back: one ITEM line per intake list. PASS when the list has its own permissions and the Visitors group holds
  Contribute on it; else FAIL, with the reason (list missing, no Visitors group, no Contribute level, inherits, role missing).
.PARAMETER SiteLists
  The lists of the site (Get-SiteList), read after step 7.
.OUTPUTS
  System.String[]. The ITEM lines, W01 to W03.
#>
function Test-WingContribute($SiteLists) {
  $vid = Get-VisitorGroupId
  $level = Get-RoleLevel '' $ContributeRoleKind
  $out = New-Object System.Collections.Generic.List[string]
  $n = 0
  foreach ($k in $IntakeLists) {
    $n++
    $tag = 'ITEM W' + $n.ToString('00') + '-' + $k
    $l = Find-OurList $SiteLists $k
    if (-not $l) { $out.Add($tag + ' FAIL the list is not on the site'); continue }
    if ($vid -le 0) { $out.Add($tag + ' FAIL the site has no associated Visitors group, so wing users cannot write to "' + $l.Title + '"'); continue }
    if (-not $level) { $out.Add($tag + ' FAIL the site has no Contribute level'); continue }
    if (-not [bool]$l.HasUniqueRoleAssignments) { $out.Add($tag + ' FAIL "' + $l.Title + '" still inherits its permissions from the site: Visitors only read'); continue }
    if (@(Get-ListBinding ([string]$l.Id) $vid) -notcontains [int]$level.Id) { $out.Add($tag + ' FAIL the Visitors group does not hold Contribute on "' + $l.Title + '"'); continue }
    $out.Add($tag + ' PASS "' + $l.Title + '": the Visitors group holds Contribute on the list (own permissions); the site stays Read')
  }
  return $out.ToArray()
}
