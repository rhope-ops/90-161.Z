<#
.SYNOPSIS
  90-161.Z Task 20 list provisioning r3, module "access": the read-backs of step 6 (the PFM Office level) and of the access to
  the 12 lists (PFM 19 Nov 26: R34 plan, open point 12).
.DESCRIPTION
  Loaded by 90161Z-T20-provision-lists-r3.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values and helpers of the main file ($OfficeGroup, $OfficeLevel, $EditRoleKind, $EditItemsBit, $OverrideBit,
  Get-GroupId, Get-RoleLevel, Get-WebBinding, Test-LevelPermission, Get-RestValue, Find-OurList). Outputs: one ITEM line
  from each function. It reads only; it never changes a list, a group or a level.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection of the main file.
  Writes: nothing (reads only).
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T20-provision-lists-r3.ps1 loads it.
#>

# SharePoint permission bit (SP.BasePermissions, low word): EditListItems 0x4 (the main file holds Override List Behaviors, 0x100).
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
