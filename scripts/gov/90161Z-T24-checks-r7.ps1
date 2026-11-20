<#
.SYNOPSIS
  90-161.Z Task 24 r7, module "checks": the F08 warning check of part 1 and the parts 2, 3 and 4 of the full-solution test
  (split from the main file in R36 to keep it under the code standard's file size cap; the code is unchanged).
.DESCRIPTION
  Loaded by 90161Z-T24-full-solution-test-r7.ps1 (dot-sourced from the same folder after the sign-in); it does nothing when it
  is run alone. Inputs: the values and helpers of the main file ($Waivers, $stateFile, $state, Add-Line, Get-RowsFor,
  Get-LocalDate, Wait-Until, Read-State, Save-State, Clear-TestPublication, Clear-TestProduct, Get-ReportLogRow,
  Restore-TestSetting). Outputs: ITEM lines through Add-Line.
  Network: the one SharePoint site of the main file, through its PnP.PowerShell connection.
  Writes: the site rows the main file's header lists (part 4 moves the fake rows to the site Recycle Bin and puts the two
          PFM Settings rows back); on this computer part 4 deletes the state file.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T24-full-solution-test-r7.ps1 -Part <1 to 4> loads it.
#>

<#
.SYNOPSIS
  R7 (R37): masks your sign-in name, and the address in it, as <YOU> in a text (a server message can name it).
.PARAMETER Text
  The text to mask.
.PARAMETER Me
  Your user from Get-MyUser, or $null.
.OUTPUTS
  System.String. The text with <YOU> for the sign-in name and its address part.
#>
function Hide-Login([string]$Text, $Me) {
  if (-not ($Me -and $Me.Login)) { return $Text }
  foreach ($x in @($Me.Login, ($Me.Login -split '\|')[-1]) | Where-Object { $_ -and $_.Length -ge 3 } | Sort-Object Length -Descending) { $Text = $Text.Replace($x, '<YOU>') }
  return $Text
}
function Get-MyUser {
  # Your own user on the site (REST web/currentuser on the one site of this task), for the Leader and Waiver Approver of the fake rows.
  # Returns @{ Id (0 when not read); Login (your sign-in name, '' when not read) }. R7 (R36 finding 2): the person fields take Login as text,
  # because a number from a function reached PnP as an empty user name. Login is never written to the output.
  $raw = [string](Invoke-PnPSPRestMethod -Method Get -Url ($site.TrimEnd('/') + '/_api/web/currentuser?$select=Id,LoginName') -Raw -ErrorAction Stop)
  $j = $raw | ConvertFrom-Json
  if ($j.PSObject.Properties['d']) { $j = $j.d }   # the verbose answer form keeps the fields under d
  $uid = 0; [void][int]::TryParse([string]$j.Id, [ref]$uid)
  return @{ Id = $uid; Login = ([string]$j.LoginName).Trim() }
}
function Get-WarningRow([int]$WaiverId) {
  # The Activity Log rows F08 wrote for one waiver (title "Waiver tier warning: W<ID>"; rule 4.4A).
  $q = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>Waiver tier warning: W" + $WaiverId + '</Value></Eq></Where></Query></View>'
  return @(Get-PnPListItem -List 'PFM Activity Log' -Query $q -ErrorAction Stop)
}
function Clear-TestWaiver([int]$WaiverId) {
  # Moves the F08 warning rows of one fake waiver, then the waiver, to the site Recycle Bin; returns the count.
  $n = 0
  foreach ($r in (Get-WarningRow $WaiverId)) { $null = Remove-PnPListItem -List 'PFM Activity Log' -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ }
  $null = Remove-PnPListItem -List 'PFM Waivers' -Identity $WaiverId -Recycle -Force -ErrorAction Stop
  return $n + 1
}
<#
.SYNOPSIS
  Part 1, w. F08 (rule 4.4A): reads the warning rows of the 3 fake waivers and adds the f08 ITEM lines.
.PARAMETER Wv
  The ids of the fake waivers by key (w1, w2, w3).
#>
function Test-F08Warning($Wv) {
  $wv = $Wv
  # w. F08 (rule 4.4A): the waivers were made before both 16-minute waits, so F08 (every 15 minutes) has checked them at least twice by now.
  Write-Host 'NOW Reading the F08 warning rows of the 3 fake waivers.'
  $warn = @{}
  foreach ($k in $Waivers.Keys) { $warn[$k] = @(Get-WarningRow $wv[$k]) }
  $d8 = $(if ($warn['w1'].Count) { [string]$warn['w1'][0]['EventDetails'] } else { '' })
  $good = $warn['w1'].Count -eq 1 -and [string]$warn['w1'][0]['EventType'] -eq 'Waiver Warning' -and $d8.StartsWith('Tier T-1; approver ') -and $d8.Contains('Table A10.1 approver: T-1: ')
  Add-Line 'f08-warns-t1' $(if ($good) { 'PASS' } else { 'FAIL' }) ('T-1 waiver with you as Waiver Approver (you lead an office row): warning rows=' + $warn['w1'].Count +
      ' expected=1 (Event Type Waiver Warning; the tier and the Table A10.1 approver in the details)' + $(if ($warn['w1'].Count) { '' } else { '. Check that F08 is On and read its run history' }))
  Add-Line 'f08-none-t3' $(if ($warn['w3'].Count -eq 0) { 'PASS' } else { 'FAIL' }) (
      'T-3 waiver with you as Waiver Approver (the wing waives T-3): warning rows=' + $warn['w3'].Count + ' expected=0')
  Add-Line 'f08-none-no-approver' $(if ($warn['w2'].Count -eq 0) { 'PASS' } else { 'FAIL' }) ('T-2 waiver with no Waiver Approver: warning rows=' + $warn['w2'].Count + ' expected=0')
  Add-Line 'f08-hand' 'INFO' 'the warning e-mail (alert address Inbox: exactly 1, subject 90-161.Z waiver tier warning: W<ID> (T-1)) is checked by you'
}
<#
.SYNOPSIS
  F02 checks (DAFMAN 90-161 7.4.2: Next Review Due = 4 years after the later of Effective Date and Certified Current Date;
  7.4.4: the review row opens 6 months before it). After the first Run: the dates and the review rows. After the second
  Run: the review rows are unchanged (not twice). Adds ITEM lines.
.PARAMETER State
  The test state (item IDs and expected dates from part 1); review1 is set after the first Run.
.PARAMETER Second
  $true for the check after the second Run.
#>
function Test-F02Row($State, [bool]$Second) {
  $nrd1 = [datetime]::ParseExact($State['nrd1'], 'yyyy-MM-dd', $null); $nrd2 = [datetime]::ParseExact($State['nrd2'], 'yyyy-MM-dd', $null)
  $p1 = [int]$State['p1']; $p2 = [int]$State['p2']; $p3 = [int]$State['p3']; $p4 = [int]$State['p4']
  $want = @{ $p1 = $nrd1; $p2 = $nrd2; $p3 = $nrd1 }
  $suffix = $(if ($Second) { '-run2' } else { '' })
  if (-not $Second) {
    $ok = Wait-Until {
      $all = $true
      foreach ($k in $want.Keys) {
        $v = Get-LocalDate (Get-PnPListItem -List 'PFM Product Index' -Id $k -Fields 'NextReviewDue' -ErrorAction Stop)['NextReviewDue']
        if ($v -ne $want[$k]) { $all = $false }
      }
      $all } 'the F02 run to set Next Review Due'
    if (-not $ok) {
      Add-Line 'f02-ran' 'FAIL' 'Next Review Due not set on A, B and C. Start F02 with Run in Power Automate, check that it is On and read its run history (Flows paused must be No)'
    }
    Start-Sleep -Seconds 30   # F02 handles the products one at a time; the review rows follow each date
    $nv = @{}
    foreach ($k in $p1, $p2, $p3, $p4) { $nv[$k] = Get-LocalDate (Get-PnPListItem -List 'PFM Product Index' -Id $k -Fields 'NextReviewDue' -ErrorAction Stop)['NextReviewDue'] }
    Add-Line 'f02-later-certified' $(if ($nv[$p1] -eq $nrd1) { 'PASS' } else { 'FAIL' }) (
      'A: Next Review Due is 4 years after the later date (Certified Current Date later; a wrong value was corrected)')
    Add-Line 'f02-later-effective' $(if ($nv[$p2] -eq $nrd2) { 'PASS' } else { 'FAIL' }) 'B: Next Review Due is 4 years after the later date (Effective Date later; the column was empty)'
    Add-Line 'f02-inactive-skipped' $(if ($null -eq $nv[$p4]) { 'PASS' } else { 'FAIL' }) 'D (Inactive): Next Review Due still empty'
  }
  $r = @{}
  foreach ($k in $p1, $p2, $p3, $p4) { $r[$k] = @(Get-RowsFor 'PFM Reviews' 'Product' $k | Where-Object { [string]$_['ReviewType'] -eq 'Periodic' }) }
  $today = (Get-Date).Date
  if (-not $Second) {
    $one = $r[$p1]
    $fine = ($one.Count -eq 1) -and ((Get-LocalDate $one[0]['ReviewOpened']) -eq $today) -and ((Get-LocalDate $one[0]['OPRResponseDue']) -eq $today.AddDays(30)) -and
        (([string]$one[0]['Title']) -like '* periodic review due *')
    Add-Line 'f02-review-opened' $(if ($fine) { 'PASS' } else { 'FAIL' }) ('A (6 months before the date): periodic review rows=' + $one.Count +
        ' expected=1; opened today and response due in 30 days=' + $fine)
    $State['review1'] = $(if ($one.Count) { [string]$one[0].Id } else { '0' })
    Add-Line 'f02-window-closed' $(if ($r[$p2].Count -eq 0) { 'PASS' } else { 'FAIL' }) ('B (window not open): periodic review rows=' + $r[$p2].Count + ' expected=0')
    Add-Line 'f02-open-kept' $(if ($r[$p3].Count -eq 1 -and [string]$r[$p3][0].Id -eq $State['premade']) { 'PASS' } else { 'FAIL' }) ('C (a review already open): periodic review rows=' +
        $r[$p3].Count + ' expected=1 (the one made here)')
    Add-Line 'f02-inactive-no-review' $(if ($r[$p4].Count -eq 0) { 'PASS' } else { 'FAIL' }) ('D (Inactive): periodic review rows=' + $r[$p4].Count + ' expected=0')
  } else {
    $same = ($r[$p1].Count -eq 1) -and ([string]$r[$p1][0].Id -eq $State['review1']) -and ($r[$p3].Count -eq 1) -and ($r[$p2].Count -eq 0) -and ($r[$p4].Count -eq 0)
    Add-Line ('f02-not-twice' + $suffix) $(if ($same) { 'PASS' } else { 'FAIL' }) ('after the second run: review rows A=' + $r[$p1].Count + ' B=' + $r[$p2].Count + ' C=' + $r[$p3].Count + ' D=' +
        $r[$p4].Count + ' expected 1, 0, 1, 0 with the same A row')
  }
}
<#
.SYNOPSIS
  Part 2: what F02 did after its first run, then what F04 logged (1 row, test mode, the count of open actions).
.PARAMETER State
  The test state of part 1 (Test-F02Row sets review1 in it; it is saved here).
#>
function Invoke-Part2($State) {
  $state = $State
  # F02 after the first run, then F04.
  Write-Host 'NOW Checking what F02 did after its first run.'
  Test-F02Row $state $false
  Save-State $stateFile $state
  Write-Host 'NOW Reading the status report log rows from F04.'
  $rowsNew = @(Get-ReportLogRow ([int]$state['reportBase']))
  $none = ($rowsNew.Count -eq 0)
  if ($none) { $none = -not (Wait-Until { @(Get-ReportLogRow ([int]$state['reportBase'])).Count -ge 1 } 'the F04 log row') }
  $rowsNew = @(Get-ReportLogRow ([int]$state['reportBase']))
  $det = $(if ($rowsNew.Count) { [string]$rowsNew[-1]['EventDetails'] } else { '' })
  Add-Line 'f04-logged' $(if ($rowsNew.Count -eq 1 -and $det.Contains('Test mode: sent to the alert address only')) { 'PASS' } else { 'FAIL' }) ('new status-report log rows=' +
      $rowsNew.Count + ' expected=1 (start F04 once; 2 or more fail); the row says test mode=' + $det.Contains('Test mode') +
          $(if ($rowsNew.Count) { '' } else { '. Start F04 with Run in Power Automate, type any address, and read its run history' }))
  Write-Host 'NOW Counting the open rows (no Closed Date) on the Publications list.'
  $nPub = @(Get-PnPListItem -List 'PFM Publications' -Fields 'Title', 'ClosedDate' -ErrorAction Stop | Where-Object { -not $_['ClosedDate'] }).Count
  $covered = $(if ($det -match 'covered (\d+) actions') { [int]$Matches[1] } else { -1 })
  Add-Line 'f04-count' $(if ($covered -eq $nPub) { 'PASS' } else { 'FAIL' }) ('the report covered ' + $covered + ' actions; Publications rows without a Closed Date now=' +
      $nPub + ' (they differ when a row was added, removed or closed after the run)')
  Add-Line 'f04-hand' 'INFO' 'the e-mail itself (alert address Inbox, 2 tables, test mode line) is checked by you in the next step'
}
<#
.SYNOPSIS
  Part 3: F02 after the second run (checks only; part 4 cleans up).
.PARAMETER State
  The test state of part 1.
#>
function Invoke-Part3($State) {
  $state = $State
  # Part 3: F02 after the second run (checks only; part 4 cleans up).
  Write-Host 'NOW Checking that F02 made no second review row.'
  if ($state.ContainsKey('p1') -and $state.ContainsKey('nrd1')) { Test-F02Row $state $true } else { Add-Line 'f02-not-twice-run2' 'SKIP' 'part 1 stopped before the F02 rows were made' }
}
<#
.SYNOPSIS
  Part 4: moves every fake row to the site Recycle Bin, puts the PFM Settings rows back and deletes the state file. The fake
  rows always go here, also after a failed check (the check lines keep the evidence). A row already gone is not an error.
.PARAMETER State
  The test state of part 1.
#>
function Invoke-Part4($State) {
  $state = $State
  # Part 4: clean-up and settings back. The fake rows always go to the Recycle Bin here, also after a failed check (the check
  # lines above keep the evidence). A row already gone is not an error.
  Write-Host 'NOW Moving the fake rows to the site Recycle Bin.'
  $n = 0; $gone = 0
  foreach ($k in 'x', 'xt', 'xs', 'xa', 'g7', 's7', 'fa', 'fb') { if ($state.ContainsKey($k)) { try { $n += Clear-TestPublication ([int]$state[$k]) } catch { $gone++ } } }
  foreach ($k in 'p1', 'p2', 'p3', 'p4') { if ($state.ContainsKey($k)) { try { $n += Clear-TestProduct ([int]$state[$k]) } catch { $gone++ } } }
  foreach ($k in $Waivers.Keys) { if ($state.ContainsKey($k)) { try { $n += Clear-TestWaiver ([int]$state[$k]) } catch { $gone++ } } }
  if ($state.ContainsKey('office')) {
    try { $null = Remove-PnPListItem -List 'PFM Offices' -Identity ([int]$state['office']) -Recycle -Force -ErrorAction Stop; $n++ } catch { $gone++ }
  }
  if ($state.ContainsKey('reportBase')) {
    foreach ($r in (Get-ReportLogRow ([int]$state['reportBase']))) { $null = Remove-PnPListItem -List 'PFM Activity Log' -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ }
  }
  Add-Line 'g-clean-up' 'SET' ('rows moved to the site Recycle Bin=' + $n + '; fake items already gone or not removable=' + $gone)
  Write-Host 'NOW Putting the two Settings rows back.'
  if ($state.ContainsKey('settingsRestored')) { $nRestored = 0; Add-Line 'h-settings-restored' 'SET' 'PFM Settings rows were put back earlier (a part stopped)' }
  else { $nRestored = Restore-TestSetting $state; Add-Line 'h-settings-restored' 'SET' ('PFM Settings rows put back to their old values=' + $nRestored) }
  $script:settingsChanged = $false
  Remove-Item -LiteralPath $stateFile -Force
}
