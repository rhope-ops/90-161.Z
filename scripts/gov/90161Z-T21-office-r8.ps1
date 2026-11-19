<#
.SYNOPSIS
  90-161.Z Task 21 probe r8, module "office": the part Office, the device test of the PFM Office level (PFM 19 Nov 26,
  F2 B): a PFM Office member who is not a row's author can edit that row on a list set to "edit own rows".
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r8.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values the main file sets ($dir, $site, $ListTitle, $ListFolder, $OfficeGroup, $OfficeLevel,
  $OfficeStateName, $StateName, $NoLaunch) and the helpers of the module "common"; the second person is the one the part
  Person found (its state file holds the site user number), so no address is asked again. Outputs: result lines through
  Add-Item, and the OFFICE line.
  The level and the group are the ones T20 r2 makes (step 6, F2 A); this part only uses them. On the probe list it sets
  "edit own rows" (as on PFM Publications and PFM Endorsements, PFM 10A) and gives the group the level on that list (the
  list has its own permissions since Make), so the test needs no change to a PFM list.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection.
  Writes: on the probe list: "edit own rows", the PFM Office level for the group PFM Office and 1 row titled EDITALL; the
          second person in the group PFM Office; on this computer the state file 90161Z-T21-office-state-r8.txt (3 numbers or
          flags) and the clipboard (the row's edit form link). Clean removes the person from the group again.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r8.ps1 -Part Office loads it.
#>

# SharePoint permission bits (SP.BasePermissions, low word): EditListItems 0x4; CancelCheckout 0x100 ("Override List Behaviors").
$EditItemsBit = 0x4
$OverrideBit = 0x100

# True when a permission answer ({High, Low}) holds Edit Items and Override List Behaviors: the right to edit every row.
function Test-EditAll($Bits) { $low = [long]$Bits.Low; return (($low -band $EditItemsBit) -ne 0 -and ($low -band $OverrideBit) -ne 0) }

# Finds a site group by its name (one request for that group, its name encoded); returns its Id, or 0 when it is missing.
function Get-GroupIdByName([string]$Name) {
  try { return [int]((Invoke-Rest 'Get' ("_api/web/sitegroups/getbyname('" + [uri]::EscapeDataString($Name) + "')?" + '$select=Id') '') | ConvertFrom-Json).Id }
  catch { return 0 }
}

<#
.SYNOPSIS
  Office, steps o1 to o3: finds the group and the level (made by T20 r2), sets "edit own rows" on the probe list and gives
  the group the level on that list. Each change is made only when it is missing and is read back.
.PARAMETER List
  The probe list (from Find-ByFolder).
.OUTPUTS
  System.Int32. The Id of the group PFM Office, or 0 when the group or the level is missing (the part stops there).
#>
function Grant-OfficeOnProbe($List) {
  $gid = Get-GroupIdByName $OfficeGroup
  if (-not $gid) { Add-Item 'o1-group' 'FAIL' ('the site has no group ' + $OfficeGroup + ': run T20 r2 first'); return 0 }
  $level = @(Get-RestValue ('_api/web/roledefinitions?$select=Id,Name,BasePermissions&$top=500') | Where-Object { [string]$_.Name -eq $OfficeLevel })
  if (-not $level.Count -or -not (Test-EditAll $level[0].BasePermissions)) {
    Add-Item 'o1-group' 'FAIL' ('the level ' + $OfficeLevel + ' is missing or lacks Override List Behaviors: run T20 r2 first'); return 0
  }
  Add-Item 'o1-group' 'PASS' ('the group ' + $OfficeGroup + ' and the level ' + $OfficeLevel + ' (Edit plus Override List Behaviors) are on the site')
  $lbase = "_api/web/lists(guid'" + $List.Id + "')"
  Write-Now 'Setting "edit own rows" on the probe list'
  $ctx = Get-PnPContext; $l = $ctx.Web.Lists.GetById([guid]$List.Id); $l.WriteSecurity = 2; $l.Update(); $ctx.ExecuteQuery()
  $ws = [int]((Invoke-Rest 'Get' ($lbase + '?$select=WriteSecurity') '') | ConvertFrom-Json).WriteSecurity
  Add-Item 'o2-edit-own' $(if ($ws -eq 2) { 'PASS' } else { 'FAIL' }) ('the probe list lets a person edit only own rows=' + $(if ($ws -eq 2) { 'yes' } else { 'no' }))
  $has = $false
  $bindings = $lbase + '/roleassignments/getbyprincipalid(' + $gid + ')/roledefinitionbindings?$select=Id'
  try { $has = @(Get-RestValue $bindings | Where-Object { [int]$_.Id -eq [int]$level[0].Id }).Count -gt 0 } catch { $has = $false }
  if (-not $has) {
    Write-Now ('Giving the level ' + $OfficeLevel + ' to the group on the probe list')
    $null = Invoke-Rest 'Post' ($lbase + '/roleassignments/addroleassignment(principalid=' + $gid + ',roledefid=' + [int]$level[0].Id + ')') '{}'
  }
  Add-Item 'o3-level' 'PASS' ('the group holds the level on the probe list (given now=' + $(if ($has) { 'no' } else { 'yes' }) + ')')
  return $gid
}

<#
.SYNOPSIS
  Office, step o4: one row titled EDITALL that you write (so you are its author); a row from an earlier run is used again.
.OUTPUTS
  System.Int32. The row's Id.
#>
function Add-OfficeRow {
  $rows = @(Get-ListRow $ListTitle @('Title', 'Author') | Where-Object { ([string]$_.Title) -like 'EDITALL *' } | Sort-Object { $_.Id } -Descending)
  if ($rows.Count) { $id = [int]$rows[0].Id; $made = 'no' }
  else {
    Write-Now 'Adding the row the second person edits'
    $tag = 'R35' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $id = [int](Add-PnPListItem -List $ListTitle -Values @{ Title = ('EDITALL ' + $tag); ProbeTest = 'EDITALL' } -ErrorAction Stop).Id
    $made = 'yes'
  }
  Add-Item 'o4-row' 'PASS' ('the row titled EDITALL is on the probe list, you are its author (made now=' + $made + ')')
  return $id
}

<#
.SYNOPSIS
  Office, step o5: puts the second person of the part Person into the group PFM Office and reads back that the person
  can now edit every row of the probe list. A person who could do that before is not used: the test would prove nothing.
  The numbers are saved in the office state file before the change, so Clean can remove the person even if this stops.
.PARAMETER GroupId
  The Id of the group PFM Office.
.PARAMETER List
  The probe list (from Find-ByFolder).
.OUTPUTS
  System.String. The status text for the OFFICE line (no identity).
#>
function Add-OfficeMember([int]$GroupId, $List) {
  $person = Read-State $script:dir
  if (-not $person) { Add-Item 'o5-person' 'FAIL' 'no second person on file: run the part Person first'; return 'no second person on file' }
  $uid = [int]$person['UserId']
  $loginName = ''
  $raw = Invoke-Rest 'Get' ('_api/web/getuserbyid(' + $uid + ')?$select=LoginName') ''
  if ($raw -match '"LoginName"\s*:\s*"([^"]+)"') { $loginName = $Matches[1] }
  $permUri = "_api/web/lists(guid'" + $List.Id + "')/getusereffectivepermissions(@u)?@u='" + [uri]::EscapeDataString($loginName) + "'"
  $was = (Get-GroupMemberId $GroupId) -contains $uid
  if (-not $was -and (Test-EditAll ((Invoke-Rest 'Get' $permUri '') | ConvertFrom-Json))) {
    $loginName = $null
    Add-Item 'o5-person' 'FAIL' 'the second person can edit every row already, without PFM Office: use a person who is only a Visitor'
    return 'the person can edit every row already'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $script:dir $OfficeStateName) -PathType Leaf)) {
    $stateLines = @(('UserId=' + $uid), ('GroupId=' + $GroupId), ('WasMember=' + $(if ($was) { 'yes' } else { 'no' })))
    Set-Content -LiteralPath (Join-Path $script:dir $OfficeStateName) -Value $stateLines -Encoding ASCII
  }
  if (-not $was) {
    Write-Now ('Adding the second person to the group ' + $OfficeGroup)
    try { $null = Add-PnPGroupMember -LoginName $loginName -Group $GroupId -ErrorAction Stop } catch { $null = $_ }
  }
  $in = (Get-GroupMemberId $GroupId) -contains $uid
  $can = $in -and (Test-EditAll ((Invoke-Rest 'Get' $permUri '') | ConvertFrom-Json))
  $loginName = $null
  $text = 'person in PFM Office=' + $(if ($in) { 'yes' } else { 'no' }) + '; can edit every row of the probe list now=' + $(if ($can) { 'yes' } else { 'no' })
  Add-Item 'o5-person' $(if ($can) { 'PASS' } else { 'FAIL' }) $text
  return $(if ($was) { 'already a member (Clean leaves the person in the group)' } elseif ($in) { 'added and listed in the group' } else { 'the add was refused' })
}

<#
.SYNOPSIS
  The part Office (F2 B, PFM 19 Nov 26): the group PFM Office gets the level on the probe list, you write one EDITALL row,
  the second person joins the group, and the row's edit form link goes on the clipboard for that person. Read checks that
  the person saved the row (test EDITALL); Clean removes the person from the group.
#>
function Invoke-OfficePart {
  Write-Now 'Looking for the probe list, the group PFM Office and its level'
  $lst = Find-ByFolder $ListFolder
  if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
  $status = 'the group or the level is missing'
  $rowId = 0
  $gid = Grant-OfficeOnProbe $lst
  if ($gid) {
    $rowId = Add-OfficeRow
    $status = Add-OfficeMember $gid $lst
  }
  $script:lines.Add('OFFICE second person in ' + $OfficeGroup + ': ' + $(if ($status -like 'added*' -or $status -like 'already*') { 'yes' } else { 'no' }) + '; status: ' + $status)
  $clip = 'no'
  if ($NoLaunch) { $clip = 'no (test run)' } elseif ($rowId) {
    try { Set-Clipboard -Value ($script:site.TrimEnd('/') + '/Lists/' + $ListFolder + '/EditForm.aspx?ID=' + $rowId); $clip = 'yes' } catch { $clip = 'no' }
  }
  $script:lines.Add('ITEM o6-link INFO the link of the edit form of the EDITALL row is on the clipboard=' + $clip)
}

<#
.SYNOPSIS
  Clean, step c1b: removes the second person from the group PFM Office again (by the office state file), unless the person
  was a member before the test; then deletes that state file. Adds one ITEM line.
.OUTPUTS
  None.
#>
function Clear-OfficeMember {
  $f = Join-Path $script:dir $OfficeStateName
  if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { Add-Item 'c1b-office' 'INFO' 'no PFM Office test on file (nothing to remove)'; return }
  $h = @{}; foreach ($l in @(Get-Content -LiteralPath $f)) { if ([string]$l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() } }
  $uid = [int]$h['UserId']; $gid = [int]$h['GroupId']
  if ($h['WasMember'] -ne 'yes' -and (Get-GroupMemberId $gid) -contains $uid) {
    Write-Now ('Removing the second person from the group ' + $OfficeGroup)
    try { $null = Invoke-Rest 'Post' ('_api/web/sitegroups/getbyid(' + $gid + ')/users/removebyid(' + $uid + ')') '{}' } catch { $null = $_ }
  }
  $still = $h['WasMember'] -ne 'yes' -and (Get-GroupMemberId $gid) -contains $uid
  if (-not $still) { Remove-Item -LiteralPath $f -ErrorAction Stop }
  $text = $(if ($still) { 'the second person is still in PFM Office (state file kept; run Clean again)' } else { 'the second person is not in PFM Office because of this test (state file deleted)' })
  Add-Item 'c1b-office' $(if ($still) { 'FAIL' } else { 'PASS' }) $text
}
