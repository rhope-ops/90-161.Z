<#
.SYNOPSIS
  90-161.Z Task 21 probe r13, module "person": the parts Person (the second person for test T4), Ask (the round asks that
  person for a new row, R36) and Clean (removes the person, the list and the library again).
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r14.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values the main file sets ($site, $dir, $StateName, $ListTitle, $ListFolder, $LibTitle, $LibFolder,
  $TestDir, $NoLaunch) and the helpers of the module "common". Outputs: result lines through Add-Item.
  The second person's e-mail address is read in a small window and used in memory only: it is never written to a file,
  a result line or an output stream (tests/ps/Test-T21.ps1 checks this text).
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection.
  Writes: Person: adds one person to the site's Visitors group; on this computer the state file (3 numbers or flags) and
          the clipboard (the new row form link). Ask: the line T4Asked=yes in that state file and the clipboard (the new
          row form link); nothing on the site. Clean: removes that person from Visitors and PFM Office again, moves the probe list
          and library to the site Recycle Bin, deletes the state file.
  Credentials: none of its own (the main file signs in); no password is asked for.
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r14.ps1 -Part Person (or Ask, or Clean) loads it.
#>

function Read-PersonAddress {
  # The second person's address, typed by the PFM in a small window. It is returned to the caller and used in memory only; this
  # function writes nothing. In a test run (-TestDir) a fake address may come from the test.
  # r13 (the PFM, 26 Nov 26, R45: "maybe i should have the option to say skip"): the window has OK and Skip. Skip, an
  # empty box or closing the window gives '' (the caller then gives SKIP, not FAIL). The window scales itself
  # (AutoScaleMode Dpi): after the engine-v46 sign-in block the process is DPI-aware.
  if ($TestDir -and $null -ne $env:T21_TEST_ADDRESS) { return ([string]$env:T21_TEST_ADDRESS).Trim() }
  $prompt = 'Type the e-mail address of the second person for test T4 (a person who is not you), then select OK. ' +
    'It is used once, stays on this computer and is not saved or sent. If nobody can help today, select Skip.'
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop; Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $f = New-Object System.Windows.Forms.Form
    $f.Text = '90-161.Z test T4'; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterScreen'; $f.TopMost = $true; $f.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $f.AutoScaleMode = 'Dpi'; $f.ClientSize = New-Object System.Drawing.Size(420, 170)
    $l = New-Object System.Windows.Forms.Label; $l.Text = $prompt; $l.SetBounds(12, 12, 396, 70)
    $t = New-Object System.Windows.Forms.TextBox; $t.SetBounds(12, 88, 396, 24)
    $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'OK'; $ok.SetBounds(232, 128, 84, 30); $ok.DialogResult = 'OK'
    $sk = New-Object System.Windows.Forms.Button; $sk.Text = 'Skip'; $sk.SetBounds(324, 128, 84, 30); $sk.DialogResult = 'Cancel'
    $f.Controls.AddRange(@($l, $t, $ok, $sk)); $f.AcceptButton = $ok; $f.CancelButton = $sk
    $r = $f.ShowDialog(); $v = [string]$t.Text; $f.Dispose()
    if ($r -ne 'OK') { return '' }   # Skip or the window's X: nobody can help today
    return $v.Trim()
  } catch {
    if ($env:RADE_CONTRACT) { throw 'ADDRESS window not available: the window for the second person could not open on this computer.' }
    return ([string](Read-Host 'E-mail address of the second person (it is not saved; press Enter with no text to skip)')).Trim()
  }
}

<#
.SYNOPSIS
  Person, step p3: puts the found person into the Visitors group, unless the person is a member already. The numbers are
  saved in the state file before the change, so Clean can find the person even if this part stops half way.
.DESCRIPTION
  A state file from an earlier run of this part that added a person is kept (review, 17 Nov 26): a second run must not
  turn "added by this test" into "was a member before", or Clean would leave the person in Visitors.
.PARAMETER VisitorId
  The Id of the site's Visitors group.
.PARAMETER UserId
  The site user number of the person.
.PARAMETER LoginName
  The person's login name for Add-PnPGroupMember (used in memory only).
.OUTPUTS
  System.Collections.Hashtable. State ('yes', 'was', 'no' or 'other') and Why (the status text, no identity).
#>
function Add-VisitorMember([int]$VisitorId, [int]$UserId, [string]$LoginName) {
  $state = 'no'; $why = ''
  $was = (Get-GroupMemberId $VisitorId) -contains $UserId
  $old = Read-State $script:dir
  $keep = ($old -and $old['WasMember'] -eq 'no')
  if ($keep -and [int]$old['UserId'] -ne $UserId) {
    $state = 'other'; $why = 'a person added by an earlier run is still on file: run the Clean part first, then this part again'
  } else {
    if ($keep) { $was = $false }
    else {
      $stateLines = @(('UserId=' + $UserId), ('GroupId=' + $VisitorId), ('WasMember=' + $(if ($was) { 'yes' } else { 'no' })))
      Set-Content -LiteralPath (Join-Path $script:dir $StateName) -Value $stateLines -Encoding ASCII
    }
  }
  if ($state -eq 'other') { $null = $state }
  elseif ($was) { $state = 'was'; $why = 'the person was already a member and stays one' }
  elseif ($keep -and ((Get-GroupMemberId $VisitorId) -contains $UserId)) { $state = 'yes'; $why = 'added by an earlier run of this part; Clean removes the person' }
  else {
    try {
      $null = Add-PnPGroupMember -LoginName $LoginName -Group $VisitorId -ErrorAction Stop
      if ((Get-GroupMemberId $VisitorId) -contains $UserId) { $state = 'yes' } else { $why = 'the group does not list the person after the add' }
    } catch { $why = 'the add was refused: ' + (Format-Detail ([string]$_.Exception.Message)) }
  }
  return @{ State = $state; Why = $why }
}

<#
.SYNOPSIS
  Person, steps p2 and p3: asks for the address, finds the person on the site and adds the person to Visitors. The
  address is read into one variable, used in the next calls and cleared; it is never written, printed or saved.
.PARAMETER VisitorId
  The Id of the site's Visitors group.
.OUTPUTS
  System.Collections.Hashtable. State ('yes', 'was', 'no' or 'other') and Why (the status text, no identity).
#>
function Add-SecondPerson([int]$VisitorId) {
  $result = @{ State = 'no'; Why = '' }
  Write-Now 'Asking for the address of the second person in a small window'
  $personAddr = Read-PersonAddress
  $addrOk = ($personAddr -match '^[^@\s]+@[^@\s]+\.[^@\s]+$'); $addrNone = -not ($personAddr -match '\S')   # r13: nothing typed (Skip)
  if ($addrNone) { Add-Item 'p2-person' 'SKIP' 'nobody could help today (Skip, or no address)'; $result.Why = 'skipped: nobody could help today' }   # r13: Skip is not a failure
  elseif (-not $addrOk) { Add-Item 'p2-person' 'FAIL' 'the text in the window is not an e-mail address'; $result.Why = 'the text is not an e-mail address' }
  else {
    $userId = 0; $loginName = ''
    Write-Now 'Looking for the second person on the site'
    try {
      $raw = Invoke-Rest 'Post' '_api/web/ensureuser' (@{ logonName = ('i:0#.f|membership|' + $personAddr) } | ConvertTo-Json -Compress)
      if ($raw -match '"Id"\s*:\s*(\d+)') { $userId = [int]$Matches[1] }
      if ($raw -match '"LoginName"\s*:\s*"([^"]+)"') { $loginName = $Matches[1] }
    } catch { $userId = 0 }
    if ($userId -le 0) {
      try {
        $raw = Invoke-Rest 'Get' ("_api/web/siteusers/getbyemail('" + [uri]::EscapeDataString($personAddr) + "')?" + '$select=Id,LoginName') ''
        if ($raw -match '"Id"\s*:\s*(\d+)') { $userId = [int]$Matches[1] }
        if ($raw -match '"LoginName"\s*:\s*"([^"]+)"') { $loginName = $Matches[1] }
      } catch { $userId = 0 }
    }
    if (-not $loginName) { $loginName = 'i:0#.f|membership|' + $personAddr }
    if ($userId -le 0) { Add-Item 'p2-person' 'FAIL' 'the person was not found on this site'; $result.Why = 'the person was not found on this site' }
    else {
      Add-Item 'p2-person' 'PASS' 'the person was found on this site (the site user number is saved in the state file, no address and no name)'
      Write-Now 'Adding the second person to the Visitors group'
      $result = Add-VisitorMember $VisitorId $userId $loginName
      $isIn = ($result.State -eq 'yes' -or $result.State -eq 'was')
      $inText = $(if ($result.State -eq 'no' -or $result.State -eq 'other') { 'no' } else { 'yes' })
      Add-Item 'p3-visitors' $(if ($isIn) { 'PASS' } else { 'FAIL' }) ('person in the Visitors group=' + $inText + $(if ($result.Why) { ' (' + $result.Why + ')' } else { '' }))
    }
  }
  $personAddr = $null; $loginName = $null; $raw = $null
  return $result
}

<#
.SYNOPSIS
  The part Person (T4 retry, PFM 17 Nov 26): the second person is added to the Visitors group with your sign-in, and
  removed again by Clean. Prints "added to Visitors: yes" or "no" and a status, never who; puts the form link on the
  clipboard.
#>
function Invoke-PersonPart {
  Write-Now 'Looking for the probe list and the Visitors group'
  $lst = Find-ByFolder $ListFolder
  if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
  $visitorId = Get-VisitorGroupId
  $result = @{ State = 'no'; Why = '' }
  if ($visitorId -le 0) { Add-Item 'p1-group' 'FAIL' 'the site has no Visitors group'; $result.Why = 'the site has no Visitors group' }
  else {
    Add-Item 'p1-group' 'PASS' 'the site has a Visitors group'
    $result = Add-SecondPerson $visitorId
  }
  $state = $result.State
  $status = $(if ($state -eq 'yes') { 'added and listed in the group' } elseif ($state -eq 'was') { 'already a member (Clean leaves the person in the group)' } else { $result.Why })
  $script:lines.Add('VISITORS added to Visitors: ' + $(if ($state -eq 'yes') { 'yes' } else { 'no' }) + '; status: ' + $status)
  $clip = 'no'
  if ($NoLaunch) { $clip = 'no (test run)' } else {
    try { Set-Clipboard -Value ($script:site.TrimEnd('/') + '/Lists/' + $ListFolder + '/NewForm.aspx'); $clip = 'yes' } catch { $clip = 'no' }
  }
  $script:lines.Add('ITEM p4-link INFO the link of the new row form is on the clipboard=' + $clip)
}

<#
.SYNOPSIS
  The part Ask (R36; on this computer only, no sign-in): the round asks the second person to add one new row titled T4a
  through the new row form. Writes T4Asked=yes into the state file of Person (the other lines stay), so Read counts T4
  even when no row came (R35: T4 read FAIL when no step had asked), and puts the link of the new row form on the
  clipboard. With no second person on file it writes nothing and fails.
#>
function Invoke-AskPart {
  Write-Now 'Reading the state file of the second person'
  $st = Read-State $script:dir
  if (-not $st) { Add-Item 'k1-asked' 'FAIL' 'no second person on file: run the part Person first'; return }
  $f = Join-Path $script:dir $StateName
  $keep = @(Get-Content -LiteralPath $f | Where-Object { [string]$_ -notmatch '^T4Asked=' })
  Set-Content -LiteralPath $f -Value (@($keep) + 'T4Asked=yes') -Encoding ASCII
  $ok = ((Read-State $script:dir)['T4Asked'] -eq 'yes')
  Add-Item 'k1-asked' $(if ($ok) { 'PASS' } else { 'FAIL' }) ('T4Asked=yes in the state file (Read now counts T4)=' + $(if ($ok) { 'yes' } else { 'no' }))
  $clip = 'no'
  if ($NoLaunch) { $clip = 'no (test run)' } else {
    try { Set-Clipboard -Value ($script:site.TrimEnd('/') + '/Lists/' + $ListFolder + '/NewForm.aspx'); $clip = 'yes' } catch { $clip = 'no' }
  }
  $script:lines.Add('ITEM k2-link INFO the link of the new row form is on the clipboard=' + $clip)
}

<#
.SYNOPSIS
  Clean, step c1: removes the second person from the Visitors group again (found by the saved numbers in the state file),
  then deletes the state file. A person who was a member before the test stays. Adds one ITEM line.
#>
function Clear-SecondPerson {
  $state = Read-State $script:dir
  if (-not $state) { Add-Item 'c1-person' 'PASS' 'no second person on file (nothing to remove)'; return }
  if ($state['WasMember'] -eq 'yes') {
    Add-Item 'c1-person' 'PASS' 'the second person was a Visitors member before the test, so the person stays (state file deleted)'
    try { Remove-Item -LiteralPath (Join-Path $script:dir $StateName) -ErrorAction Stop } catch { $null = $_ }
    return
  }
  Write-Now 'Removing the second person from the Visitors group'
  try {
    $uid = [int]$state['UserId']; $gid = 0
    if ($state['GroupId'] -match '^\d+$') { $gid = [int]$state['GroupId'] }
    if ($gid -le 0) { $gid = [int]((Invoke-Rest 'Get' '_api/web/associatedvisitorgroup?$select=Id' '') | ConvertFrom-Json).Id }
    $members = Get-GroupMemberId $gid
    if ($members -contains $uid) {
      $null = Invoke-Rest 'Post' ('_api/web/sitegroups/getbyid(' + $gid + ')/users/removebyid(' + $uid + ')') '{}'
      $members = Get-GroupMemberId $gid
    }
    $still = $members -contains $uid
    $text = $(if (-not $still) { 'the second person is not in the Visitors group (state file deleted)' } else { 'the second person is still in the Visitors group (state file kept; run Clean again)' })
    Add-Item 'c1-person' $(if (-not $still) { 'PASS' } else { 'FAIL' }) $text
    if (-not $still) { Remove-Item -LiteralPath (Join-Path $script:dir $StateName) -ErrorAction Stop }
  } catch { Add-Item 'c1-person' 'FAIL' ('the second person could not be removed: ' + (Format-Detail ([string]$_.Exception.Message)) + ' (state file kept; run Clean again)') }
}

<#
.SYNOPSIS
  The part Clean: runs each step on its own, even if an earlier one failed. First the person (Visitors, then PFM Office:
  module "office"), then the two objects (found
  by their folder name), to the site Recycle Bin (restorable for 93 days). The probe flows stay in the solution.
#>
function Invoke-CleanPart {
  Write-Now 'Looking for a second person on file'
  Clear-SecondPerson
  Clear-OfficeMember
  foreach ($o in @(@('c2-list', $ListTitle, $ListFolder), @('c3-library', $LibTitle, $LibFolder))) {
    try {
      $x = Find-ByFolder $o[2]
      if (-not $x) { Add-Item $o[0] 'PASS' ('"' + $o[1] + '" was not on the site (nothing to remove)'); continue }
      Write-Now ('Moving ' + $o[1] + ' to the site Recycle Bin')
      # R29a finding 7: the command returns the Recycle Bin item ID; it is not shown (it reached the log as a raw table).
      $null = Remove-PnPList -Identity ([string]$x.Id) -Recycle -Force -ErrorAction Stop
      $still = Find-ByFolder $o[2]
      $text = $(if (-not $still) { 'moved to the site Recycle Bin (restorable for 93 days)' } else { 'is still on the site' })
      Add-Item $o[0] $(if (-not $still) { 'PASS' } else { 'FAIL' }) ('"' + $o[1] + '" ' + $text)
    } catch { Add-Item $o[0] 'FAIL' ('"' + $o[1] + '" could not be removed: ' + (Format-Detail ([string]$_.Exception.Message)) + ' (run Clean again)') }
  }
  $flows = '"90161Z T21 Probe Health r6" and "90161Z T21 Probe Button r6"'
  $script:lines.Add('NOTE the probe flows ' + $flows + ' are flows of the solution "90-161.Z flows"; this script does not touch flows or solutions')
}
