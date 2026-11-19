<#
.SYNOPSIS
  90-161.Z Task 21 probe r10, module "office": the part Office, the device test of the PFM Office level (PFM 19 Nov 26,
  F2 B): a PFM Office member who is not a row's author can edit that row on a list set to "edit own rows".
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r10.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values the main file sets ($dir, $site, $ListTitle, $ListFolder, $OfficeGroup, $OfficeLevel,
  $OfficeStateName, $StateName, $NoLaunch) and the helpers of the module "common"; the second person is the one the part
  Person found (its state file holds the site user number), so no address is asked again. Outputs: result lines through
  Add-Item, and the OFFICE line.
  The level and the group are the ones T20 r2 makes (step 6, F2 A); this part only uses them. On the probe list it sets
  "edit own rows" (as on PFM Publications and PFM Endorsements, PFM 10A) and gives the group the level on that list (the
  list has its own permissions since Make), so the test needs no change to a PFM list.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection.
  Writes: on the probe list: "edit own rows", the PFM Office level for the group PFM Office and 1 row titled EDITALL; the
          second person in the group PFM Office; on this computer the state file 90161Z-T21-office-state-r8.txt (numbers
          only: the group Id and the user Id of each person this part added and Clean has not removed yet) and the clipboard
          (the row's edit form link). Clean removes every recorded person from the group again.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r10.ps1 -Part Office loads it.
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

# The office state file: GroupId=<n> and UserIds=<n>,<n> (each person this part added to PFM Office that Clean has not
# removed yet). Returns @{ GroupId; UserIds } or $null when there is no file. Numbers only, never an address or a name.
function Read-OfficeState {
  $f = Join-Path $script:dir $OfficeStateName
  if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { return $null }
  $h = @{ GroupId = 0; UserIds = @() }
  foreach ($l in @(Get-Content -LiteralPath $f)) {
    if ([string]$l -match '^GroupId=(\d+)$') { $h.GroupId = [int]$Matches[1] }
    if ([string]$l -match '^UserIds=([\d,]*)$') { $h.UserIds = @($Matches[1] -split ',' | Where-Object { $_ } | ForEach-Object { [int]$_ }) }
  }
  return $h
}
# Writes the office state file (the group Id and the user Ids still to remove); deletes it when no Id is left.
function Write-OfficeState([int]$GroupId, [int[]]$UserIds) {
  $f = Join-Path $script:dir $OfficeStateName
  if (-not @($UserIds).Count) { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue; return }
  Set-Content -LiteralPath $f -Value @(('GroupId=' + $GroupId), ('UserIds=' + (@($UserIds) -join ','))) -Encoding ASCII
}

<#
.SYNOPSIS
  Office, step o5: puts the second person of the part Person into the group PFM Office and reads back that the person
  can now edit every row of the probe list. A person who could do that before is not used: the test would prove nothing.
  The person's Id is added to the office state file before the change, so Clean can remove the person even if this
  stops. Every person this part adds is recorded: a person from an earlier run that Clean has not removed yet stays on
  file next to the new one, and Clean removes both (review of 19 Nov 26). A person who was a member before is not recorded.
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
  $st = Read-OfficeState
  $ids = @(); if ($st) { $ids = @($st.UserIds) }
  if (@($ids | Where-Object { $_ -ne $uid }).Count) { $script:lines.Add('NOTE o5: a person from an earlier run is still on file for PFM Office; Clean removes both') }
  if (-not $was -and $ids -notcontains $uid) { $ids += $uid }
  $mine = $ids -contains $uid
  if ($ids.Count) { Write-OfficeState $GroupId $ids }
  if (-not $was) {
    Write-Now ('Adding the second person to the group ' + $OfficeGroup)
    try { $null = Add-PnPGroupMember -LoginName $loginName -Group $GroupId -ErrorAction Stop } catch { $null = $_ }
  }
  $in = (Get-GroupMemberId $GroupId) -contains $uid
  $can = $in -and (Test-EditAll ((Invoke-Rest 'Get' $permUri '') | ConvertFrom-Json))
  $loginName = $null
  $text = 'person in PFM Office=' + $(if ($in) { 'yes' } else { 'no' }) + '; can edit every row of the probe list now=' + $(if ($can) { 'yes' } else { 'no' })
  Add-Item 'o5-person' $(if ($can) { 'PASS' } else { 'FAIL' }) $text
  return $(if (-not $mine) { 'already a member (Clean leaves the person in the group)' } elseif ($in) { 'added and listed in the group' } else { 'the add was refused' })
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
  Clean, step c1b: removes every person on the office state file from the group PFM Office again, then deletes the file
  (it keeps the Ids that are still in the group). A failure is its own FAIL line and never stops the later Clean steps.
  R35 (W8): with -Label first (the check before the test) a recorded person who is still in PFM Office is a leftover of an
  earlier test: it is a FAIL line that says what to do, and nobody is removed (the Clean at the end, -Label last, removes
  the person). The group PFM Office and its level stay: they are app setup (T20), not leftovers.
.OUTPUTS
  None.
#>
function Clear-OfficeMember {
  $st = Read-OfficeState
  if (-not $st -or -not @($st.UserIds).Count) { Add-Item 'c1b-office' 'INFO' 'no PFM Office test on file (nothing to remove)'; Write-OfficeState 0 @(); return }
  try {
    $members = Get-GroupMemberId $st.GroupId
    if ($Label -eq 'first') {
      $left = @($st.UserIds | Where-Object { $members -contains $_ })
      if ($left.Count) {
        $todo = 'What to do: go on to the last Clean step of this round, which removes them, or remove them from the group ' + $OfficeGroup + ' by hand and run this step again'
        Add-Item 'c1b-office' 'FAIL' ('leftover: ' + $left.Count + ' test person(s) from an earlier test still in the group ' + $OfficeGroup + ' (state file kept). ' + $todo)
      } else {
        Write-OfficeState $st.GroupId @()
        Add-Item 'c1b-office' 'PASS' ('no test person is left in ' + $OfficeGroup + ' (state file deleted)')
      }
      return
    }
    foreach ($uid in @($st.UserIds | Where-Object { $members -contains $_ })) {
      Write-Now ('Removing a person of this test from the group ' + $OfficeGroup)
      try { $null = Invoke-Rest 'Post' ('_api/web/sitegroups/getbyid(' + $st.GroupId + ')/users/removebyid(' + $uid + ')') '{}' } catch { $null = $_ }
    }
    $members = Get-GroupMemberId $st.GroupId
    $still = @($st.UserIds | Where-Object { $members -contains $_ })
    Write-OfficeState $st.GroupId $still
    $n = @($st.UserIds).Count
    $text = 'the people of this test are not in PFM Office (' + $n + '; state file deleted)'
    if ($still.Count) { $text = 'still in PFM Office: ' + $still.Count + ' of ' + $n + ' (state file kept; run Clean again)' }
    Add-Item 'c1b-office' $(if ($still.Count) { 'FAIL' } else { 'PASS' }) $text
  } catch { Add-Item 'c1b-office' 'FAIL' ('PFM Office could not be cleaned: ' + (Format-Detail ([string]$_.Exception.Message)) + ' (state file kept; run Clean again)') }
}
