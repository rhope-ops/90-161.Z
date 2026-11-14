<#
.SYNOPSIS
  90-161.Z Task 18 slice 1 end-to-end test, r2 (R21, was R20 r2; PFM 14 Nov 26: flow controls, test mode, failure e-mail, lean
  troubleshooting). Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: proves on the test site that the slice-1 flows (F05 r2 routing, F03 r3 reminders) work end to end, and
  that a failed run can be found and resumed. Needs Test mode = Yes in the solution (the import step sets it), so every
  flow e-mail goes to the alert address only.
  Part 1 (about 10 minutes, an estimate):
    1. Signs in to the site (CAC), reads process steps 6 and 7 and the offices (rows F05 should make).
    2. Creates three fake publications at step 6: A "90161Z TEST R21 A (delete me)" (On Track), H "90161Z TEST R21 H
       (delete me)" (On Hold) and F "90161Z TEST FAIL R21 (delete me)" (test mode makes F05 fail on this title).
    3. Waits for F05 to make A's Formal Coordination rows; checks that H and F have none (hold skipped, F failed).
    4. Renames F to "90161Z TEST R21 F (delete me)" and waits for its rows (a new run after the cause is fixed).
    5. Moves one of A's rows to the Recycle Bin, edits A, and waits until F05 adds back only that row.
    6. Prepares the F03 check: sets one of A's rows to a suspense 10 weekdays ago (escalation tier) and adds one row to H
       with a past suspense (H is On Hold, so F03 must skip it).
  Then the PFM checks the failure e-mail, selects Resubmit on the failed F05 run, and runs F03 once (round guide steps).
  Part 2 (about 5 minutes, an estimate):
    7. Checks that Resubmit made no duplicate rows for F.
    8. Checks F03: default suspense 20 working days (Guard or Reserve Applicability at least 30 calendar days) on the rows
       without one; an escalation logged for A's past-due row; nothing logged for H's row.
    9. Answers A's rows "Concur", marks A's comments adjudicated, and waits for the Legal rows and step 7.
   10. Clean-up: moves every row tied to the three fake publications to the site Recycle Bin (restorable for 93 days).
       On a FAIL they stay for review; part 1 of the next run removes them.
  WHAT IT CHANGES ON THE SITE: only the three fake publications and the rows the flows and this script make for them.
  E-mail: with Test mode = Yes, F03's escalation for A's row and F05's failure notice go to the alert address only.
  Counts only: no names, offices or addresses are written. The site address stays in Config\90161Z-site.txt on this
  computer; every output line shows it as <SITE> and the DODID as <DODID>.
  Output: 90161Z-T18-slice1-part1-r2.txt or 90161Z-T18-slice1-part2-r2.txt in the T18 folder (send both).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part 1 or 2, -WaitMinutes (default 10), -NoPause.
#>
param([string]$Id, [ValidateSet(1, 2)][int]$Part = 1, [int]$WaitMinutes = 10, [switch]$NoPause)
$task = 'T18'
$TitleA = '90161Z TEST R21 A (delete me)'
$TitleH = '90161Z TEST R21 H (delete me)'
$TitleFail = '90161Z TEST FAIL R21 (delete me)'
$TitleF = '90161Z TEST R21 F (delete me)'

# >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)
function ConvertTo-Masked([string]$Text, [string[]]$Secret) {
  foreach ($x in $Secret) { $Text = $Text -replace [regex]::Escape($x), '<DODID>' }
  return $Text
}

function Get-TaskId([string]$Id) {
  # Returns @{ Id; Leaf (profile folder name); Secret (longest first, so a longer name is masked before a shorter one inside it) }.
  $leaf = ''
  if ($env:USERPROFILE) { $leaf = Split-Path -Leaf $env:USERPROFILE }
  $value = ([string]$Id).Trim()
  # No DODID question (PFM 13 Nov 26): the Windows profile folder name is used when -Id is not given.
  if (-not $value) { $value = $leaf }
  if ($value -notmatch '^[A-Za-z0-9._-]{4,}$') { throw 'DODID not valid: use the folder name under C:\Users (4 or more letters, digits, dot, dash or underscore).' }
  $secret = @(@($value, $leaf, $env:USERNAME) |
    Where-Object { $_ -and $_.Length -ge 4 } | Sort-Object -Unique | Sort-Object Length -Descending)
  return @{ Id = $value; Leaf = $leaf; Secret = $secret }
}

function Get-TaskDir([string]$Id, [string]$Task, [string]$Label, [switch]$Create) {
  # The task folder C:\Users\<DODID>\OneDrive - United States Air Force\RADE\90-161.Z\<Task> (PFM 14 Nov 26: RADE holds
  # the app folder). Until RADE has moved the old folder ...\90-161.Z, that one is used. -Create makes it when missing.
  $od = Join-Path (Join-Path 'C:\Users' $Id) 'OneDrive - United States Air Force'
  $app = 'RADE\90-161.Z'
  if (-not (Test-Path -LiteralPath (Join-Path $od $app) -PathType Container) -and (Test-Path -LiteralPath (Join-Path $od '90-161.Z') -PathType Container)) { $app = '90-161.Z' }
  $tail = 'OneDrive - United States Air Force\' + $app + '\' + $Task
  $dir = Join-Path (Join-Path 'C:\Users' $Id) $tail
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    if ($Create) { New-Item -ItemType Directory -Path $dir | Out-Null }
    else { throw ('FOLDER not found: C:\Users\<DODID>\' + $tail + '. Create it, save the ' + $Label + ' files into it, then run again.') }
  }
  return $dir
}

function Assert-TaskFile([string]$Dir, [string[]]$Name, [string]$Message) {
  # Throws $Message + the missing names when a file in $Name is not in $Dir.
  $missing = @($Name | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Dir $_) -PathType Leaf) })
  if ($missing.Count -gt 0) { throw ($Message + ($missing -join ', ')) }
}

function Unblock-TaskScript([string]$Dir) {
  # Files pasted into Notepad and saved locally need no unblock; a failed unblock is not an error here.
  Get-ChildItem -LiteralPath $Dir -Filter *.ps1 | ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
}

function Invoke-TaskStep([hashtable]$Step, [string]$ScriptDir, [string[]]$Secret, $Lines, [string]$Log) {
  # Runs $Step.File from $ScriptDir in a child powershell.exe with $Step.Args, masks and records its output and exit
  # code in $Lines, and saves $Lines to $Log after the step.
  Write-Host ('STEP ' + $Step.Name + ' running (Word steps can take a few minutes; do not close this window)...')
  $Lines.Add('STEP ' + $Step.Name)
  $stepArgs = $Step.Args
  $global:LASTEXITCODE = $null
  # PS 5.1: with Stop, a stderr line from the step (2>&1) would end the runner. Record it instead.
  $ErrorActionPreference = 'Continue'
  $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir $Step.File) @stepArgs 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  foreach ($o in @($out | Where-Object { $null -ne $_ })) {
    $masked = ConvertTo-Masked ([string]$o) $Secret
    $Lines.Add($masked)
    Write-Host $masked
  }
  $Lines.Add('STEP ' + $Step.Name + ' exit=' + $code)
  Write-Host ('STEP ' + $Step.Name + ' exit=' + $code)
  Set-Content -LiteralPath $Log -Value $Lines -Encoding UTF8
}
# <<< task-common

function Get-SiteAddress([string]$ConfigDir) {
  # Kept only on this computer (the repo is public). Asked every run, filled in with the last address (r2: new site).
  $f = Join-Path $ConfigDir '90161Z-site.txt'
  $last = 'https://'
  if (Test-Path -LiteralPath $f -PathType Leaf) { $v = ([string](Get-Content -LiteralPath $f -TotalCount 1)).Trim(); if ($v) { $last = $v } }
  Add-Type -AssemblyName Microsoft.VisualBasic
  $v = [string][Microsoft.VisualBasic.Interaction]::InputBox('Address of the test SharePoint site (starts with https://). It is kept only on this computer.', '90-161.Z Task 18', $last)
  $v = $v.Trim()
  if ($v -notmatch '^https://[^/]+/sites/[^/]+') { throw 'SITE ADDRESS not given or not a site address (https://<host>/sites/<name>). Run again.' }
  if (-not (Test-Path -LiteralPath $ConfigDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $ConfigDir -Force) }
  Set-Content -LiteralPath $f -Value $v -Encoding UTF8
  return $v
}
function Hide-Site([string]$Text, [string]$Site) {
  # The result is e-mailed: no site, tenant or sign-in address may stay in it (review R09 T16; the same rule in T18).
  $Text = $Text -replace '[\w.+-]+@[\w.-]+', '<EMAIL>'
  $Text = $Text -replace '[\w.+-]+%40[\w.-]+', '<EMAIL>'   # URL-encoded form (a probe request address, review R15 MAJOR)   # whole address first: the host rules below keep the name part (review R12 MAJOR)
  if ($Site) {
    $Text = $Text -replace [regex]::Escape($Site.TrimEnd('/')), '<SITE>'
    try {
      $u = [uri]$Site
      $Text = $Text -replace [regex]::Escape($u.Host), '<SITE-HOST>'
      $path = $u.AbsolutePath.TrimEnd('/')   # /sites/<name>: also in server-relative and URL-encoded form
      if ($path.Length -gt 1) {
        $Text = $Text -replace [regex]::Escape($path), '<SITE-PATH>'
        $Text = $Text -replace [regex]::Escape([uri]::EscapeDataString($path)), '<SITE-PATH>'
        $leaf = ($path -split '/')[-1]
        if ($leaf.Length -ge 3) { $Text = $Text -replace ('\b' + [regex]::Escape($leaf) + '\b'), '<SITE-NAME>' }
      }
      $tenant = ($u.Host -split '\.')[0]
      if ($tenant.Length -ge 3) { $Text = $Text -replace ('\b' + [regex]::Escape($tenant) + '\b'), '<TENANT>' }
    } catch { $null = $_ }
  }
  $Text = $Text -replace 'https?://\S+', '<URL>'
  $Text = $Text -replace '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>'
  $Text = $Text -replace '\b[\w.-]+\.mil\b', '<HOST>'
  $Text = $Text -replace '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b', '<GUID>'
  return $Text
}

function Add-Line([string]$Name, [string]$Status, [string]$Text) {
  $script:lines.Add('ITEM ' + $Name + ' ' + $Status + $(if ($Text) { ' ' + $Text } else { '' }))
}
function Get-RowsFor([string]$List, [int]$PubId) {
  # Rows of a list whose Publication lookup points at a fake publication (CAML by lookup ID).
  $q = "<View><Query><Where><Eq><FieldRef Name='Publication' LookupId='TRUE'/><Value Type='Lookup'>" + $PubId + "</Value></Eq></Where></Query></View>"
  return @(Get-PnPListItem -List $List -Query $q -ErrorAction Stop)
}
function Get-Formal([int]$PubId) { return @(Get-RowsFor 'PFM Endorsements' $PubId | Where-Object { [string]$_['CoordinationStage'] -eq 'Formal Coordination' }) }
function Wait-Until([scriptblock]$Done, [string]$What) {
  # Checks every 30 seconds for up to $WaitMinutes. Returns $true when $Done returns $true. A failed check (for example a
  # network drop: R20 part 1 lost the site name) is retried; 3 failures in a row stop the test (R20 finding 3).
  $end = (Get-Date).AddMinutes($WaitMinutes)
  $misses = 0
  while ($true) {
    $isDone = $false
    try { $isDone = [bool](& $Done); $misses = 0 }
    catch {
      $misses++
      if ($misses -ge 3) { throw }
      Write-Host ('  A check failed (' + $misses + ' of 3 allowed in a row); trying again in 30 seconds ...')
    }
    if ($isDone) { return $true }
    if ((Get-Date) -ge $end) { return $false }
    Write-Host ('  Waiting for ' + $What + ' (checks every 30 seconds, up to ' + $WaitMinutes + ' minutes) ...')
    Start-Sleep -Seconds 30
  }
}
function Add-WorkingDay([datetime]$Day, [int]$N) {
  # Same arithmetic as F03 r3 (weekends only, no holiday list; PFM 14 Nov 26).
  $d = $Day.Date; $left = $N
  while ($left -gt 0) { $d = $d.AddDays(1); if ($d.DayOfWeek -ne 'Saturday' -and $d.DayOfWeek -ne 'Sunday') { $left-- } }
  return $d
}
function Clear-TestPublication([int]$PubId) {
  $n = 0
  foreach ($l in 'PFM Activity Log', 'PFM Endorsements') { foreach ($r in (Get-RowsFor $l $PubId)) { $null = Remove-PnPListItem -List $l -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ } }
  $null = Remove-PnPListItem -List 'PFM Publications' -Identity $PubId -Recycle -Force -ErrorAction Stop
  return $n + 1
}

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  $dir = Get-TaskDir $id $task 'Task 18' -Create
  Set-Location -LiteralPath $dir
  $root = Split-Path -Parent $dir
  $configDir = Join-Path $root 'Config'
  $site = Get-SiteAddress $configDir
  $pubFile = Join-Path $dir '90161Z-T18-test-publications-r2.txt'   # item IDs of A, H, F and the two F03 test rows, for part 2
  $lines.Add('TASK T18 slice 1 end-to-end r2, part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ', wait-minutes=' + $WaitMinutes)
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'Connecting to the site. If a sign-in window opens, sign in with your CAC.'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')

  # 1. What F05 should make: one Formal row per active mandatory office that is not CoordinateLast; Legal rows for CoordinateLast.
  $steps = @(Get-PnPListItem -List 'PFM Process Steps' -Fields 'StepNumber' -ErrorAction Stop)
  $step6 = @($steps | Where-Object { [int]$_['StepNumber'] -eq 6 })[0]; $step7 = @($steps | Where-Object { [int]$_['StepNumber'] -eq 7 })[0]
  if (-not $step6 -or -not $step7) { throw 'PROCESS STEPS 6 and 7 not found in PFM Process Steps.' }
  $offices = @(Get-PnPListItem -List 'PFM Offices' -Fields 'MandatoryCoordinator', 'IsActive', 'CoordinateLast' -ErrorAction Stop | Where-Object { $_['IsActive'] -and $_['MandatoryCoordinator'] })
  $wantFormal = @($offices | Where-Object { -not $_['CoordinateLast'] }).Count
  $wantLegal = @($offices | Where-Object { $_['CoordinateLast'] }).Count
  Add-Line 'a-setup' $(if ($wantFormal -gt 1 -and $wantLegal -gt 0) { 'PASS' } else { 'FAIL' }) ('expected formal=' + $wantFormal + ' legal=' + $wantLegal + ' (active mandatory offices; the missing-row check needs 2 or more formal)')

  if ($Part -eq 1) {
    # 2. Remove fake publications left by an earlier run (r1 or r2 titles), then create A, H and F at step 6.
    $old = @(Get-PnPListItem -List 'PFM Publications' -Fields 'Title' -ErrorAction Stop | Where-Object { ([string]$_['Title']).StartsWith('90161Z TEST') -and ([string]$_['Title']).EndsWith('(delete me)') })
    $moved = 0
    foreach ($o in $old) { $moved += Clear-TestPublication $o.Id }
    if ($old.Count) { Add-Line 'b-leftovers' 'SET' ('moved ' + $old.Count + ' earlier test publication(s) and their rows to the Recycle Bin, rows=' + $moved) }
    $soon = (Get-Date).Date.AddDays(7)
    $others = @(Get-PnPListItem -List 'PFM Endorsements' -Fields 'EndorsementStatus', 'DueDate' -ErrorAction Stop | Where-Object { [string]$_['EndorsementStatus'] -eq 'Not Started' -and $_['DueDate'] -and ([datetime]$_['DueDate']).ToLocalTime().Date -le $soon }).Count
    Add-Line 'b2-other-rows' 'INFO' ('other open rows due within 7 days or past=' + $others + '. With Test mode = Yes their F03 e-mails go to the alert address only')
    $base = @{ ActionType = 'New'; ProductType = 'Publication'; ProcessStep = $step6.Id }
    $a = Add-PnPListItem -List 'PFM Publications' -Values ($base + @{ Title = $TitleA; ActionStatus = 'On Track' }) -ErrorAction Stop
    $h = Add-PnPListItem -List 'PFM Publications' -Values ($base + @{ Title = $TitleH; ActionStatus = 'On Hold' }) -ErrorAction Stop
    $f = Add-PnPListItem -List 'PFM Publications' -Values ($base + @{ Title = $TitleFail; ActionStatus = 'On Track' }) -ErrorAction Stop
    Add-Line 'c-create' 'SET' ('fake publications at step 6: A=' + $a.Id + ' H (On Hold)=' + $h.Id + ' F (fail title)=' + $f.Id)

    # 3. F05 makes A's rows; H (On Hold) and F (forced failure) get none.
    $ok = Wait-Until { $script:got = (Get-Formal $a.Id).Count; $script:got -ge $wantFormal } 'the F05 rows for A'
    Add-Line 'd-f05-formal' $(if ($ok -and $script:got -eq $wantFormal) { 'PASS' } else { 'FAIL' }) ('A formal rows=' + $script:got + ' expected=' + $wantFormal + $(if ($ok) { '' } else { '. If 0: open F05 in Power Automate, check that it is On and read its run history (R20: F05 made no rows), and check Flows paused = No' }))
    Write-Host '  Waiting 2 minutes so F05 has handled H and F too ...'
    Start-Sleep -Seconds 120
    $hRows = (Get-Formal $h.Id).Count; $fRows = (Get-Formal $f.Id).Count
    Add-Line 'd2-hold-skipped' $(if ($hRows -eq 0) { 'PASS' } else { 'FAIL' }) ('H (On Hold) formal rows=' + $hRows + ' expected=0')
    Add-Line 'd3-forced-failure' $(if ($fRows -eq 0) { 'PASS' } else { 'FAIL' }) ('F (fail title) formal rows=' + $fRows + ' expected=0; F05 should have e-mailed the failure')

    # 4. Fix the cause (the title) and let a new run make F's rows.
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $f.Id -Values @{ Title = $TitleF } -ErrorAction Stop
    $ok = Wait-Until { $script:got = (Get-Formal $f.Id).Count; $script:got -ge $wantFormal } 'the F05 rows for F after the fix'
    Add-Line 'e-after-fix' $(if ($ok -and $script:got -eq $wantFormal) { 'PASS' } else { 'FAIL' }) ('F formal rows after the fix=' + $script:got + ' expected=' + $wantFormal)

    # 5. One missing row: F05 adds back only that one.
    $rowsA = Get-Formal $a.Id
    $gone = $rowsA[0]
    $null = Remove-PnPListItem -List 'PFM Endorsements' -Identity $gone.Id -Recycle -Force -ErrorAction Stop
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $a.Id -Values @{ ActionStatus = 'On Track' } -ErrorAction Stop
    $ok = Wait-Until { $script:got = (Get-Formal $a.Id).Count; $script:got -ge $wantFormal } 'F05 to add back the missing row'
    Start-Sleep -Seconds 60
    $after = (Get-Formal $a.Id).Count
    Add-Line 'f-missing-row' $(if ($ok -and $after -eq $wantFormal) { 'PASS' } else { 'FAIL' }) ('A formal rows after one was removed=' + $after + ' expected=' + $wantFormal + ' (more = duplicates)')

    # 6. Prepare the F03 check: one A row past due (10 weekdays ago), one H row past due (H is On Hold).
    $rowsA = Get-Formal $a.Id
    $past = (Get-Date).Date
    $back = 0; while ($back -lt 10) { $past = $past.AddDays(-1); if ($past.DayOfWeek -ne 'Saturday' -and $past.DayOfWeek -ne 'Sunday') { $back++ } }
    $null = Set-PnPListItem -List 'PFM Endorsements' -Identity $rowsA[0].Id -Values @{ DueDate = $past } -ErrorAction Stop
    $hRow = Add-PnPListItem -List 'PFM Endorsements' -Values @{ Title = ($TitleH + ' - test row'); Publication = $h.Id; CoordinationStage = 'Formal Coordination'; CoordinationRole = 'Other'; EndorsementStatus = 'Not Started'; DueDate = $past } -ErrorAction Stop
    Set-Content -LiteralPath $pubFile -Value @([string]$a.Id, [string]$h.Id, [string]$f.Id, [string]$rowsA[0].Id, [string]$hRow.Id) -Encoding UTF8
    Add-Line 'g-f03-prepared' 'SET' ('A row ' + $rowsA[0].Id + ' and H row ' + $hRow.Id + ' set to a suspense 10 weekdays ago')
  } else {
    if (-not (Test-Path -LiteralPath $pubFile -PathType Leaf)) { throw 'NO TEST PUBLICATIONS: run part 1 first.' }
    $ids = @(Get-Content -LiteralPath $pubFile | ForEach-Object { [int]([string]$_).Trim() })
    $aId, $hId, $fId, $pastRow, $hRowId = $ids[0], $ids[1], $ids[2], $ids[3], $ids[4]

    # 7. Resubmit of the failed run made no duplicates.
    $fRows = (Get-Formal $fId).Count
    Add-Line 'h-resubmit' $(if ($fRows -eq $wantFormal) { 'PASS' } else { 'FAIL' }) ('F formal rows after Resubmit=' + $fRows + ' expected=' + $wantFormal + ' (more = duplicates)')

    # 8. F03: default suspense, escalation for A's past-due row, nothing for H's row.
    $today = (Get-Date).Date
    $work = Add-WorkingDay $today 20
    $cal = $today.AddDays(30); if ($cal.DayOfWeek -eq 'Saturday') { $cal = $cal.AddDays(2) } elseif ($cal.DayOfWeek -eq 'Sunday') { $cal = $cal.AddDays(1) }
    $checked = 0; $right = 0
    foreach ($r in @(Get-Formal $aId) + @(Get-Formal $fId)) {
      if ($r.Id -eq $pastRow) { continue }
      $checked++
      $role = [string]$r['CoordinationRole']
      $want = $(if (($role -eq 'Guard Applicability' -or $role -eq 'Reserve Applicability') -and $cal -gt $work) { $cal } else { $work })
      if ($r['DueDate'] -and ([datetime]$r['DueDate']).ToLocalTime().Date -eq $want) { $right++ }
    }
    Add-Line 'i-f03-suspense' $(if ($checked -and $right -eq $checked) { 'PASS' } else { 'FAIL' }) ('rows with the 20-working-day suspense (' + $work.ToString('dd MMM yy') + ')=' + $right + ' of ' + $checked + $(if ($right -lt $checked) { '. F03 must run the same day as part 2; check its run history' } else { '' }))
    $logA = @(Get-RowsFor 'PFM Activity Log' $aId | Where-Object { ([string]$_['Title']) -eq ('[TEST] Reminder Sent: E' + $pastRow + ' Escalation') }).Count
    Add-Line 'j-f03-escalation' $(if ($logA -eq 1) { 'PASS' } else { 'FAIL' }) ('test-mode escalation logged for the past-due A row=' + $logA + ' expected=1 (0 = Test mode was not Yes, or F03 did not run)')
    $logH = @(Get-RowsFor 'PFM Activity Log' $hId | Where-Object { ([string]$_['Title']) -match ('Reminder Sent: E' + $hRowId + ' ') }).Count
    $hFormal = @(Get-Formal $hId | Where-Object { $_.Id -ne $hRowId }).Count
    Add-Line 'k2-hold-still-skipped' $(if ($hFormal -eq 0) { 'PASS' } else { 'FAIL' }) ('F05 rows for H (On Hold) at part 2=' + $hFormal + ' expected=0')
    Add-Line 'k-f03-hold' $(if ($logH -eq 0) { 'PASS' } else { 'FAIL' }) ('reminders logged for the On Hold row=' + $logH + ' expected=0')

    # 9. Answer A's rows, mark comments adjudicated; F05 makes the Legal rows and moves A to step 7.
    $formal = Get-Formal $aId
    foreach ($r in $formal) { $null = Set-PnPListItem -List 'PFM Endorsements' -Identity $r.Id -Values @{ EndorsementStatus = 'Concur' } -ErrorAction Stop }
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $aId -Values @{ AllCommentsAdjudicated = $true } -ErrorAction Stop
    Add-Line 'l-answers' 'SET' ('A formal rows answered Concur=' + $formal.Count + ', All Comments Adjudicated=Yes')
    $script:legal = 0; $script:atStep = 0
    $ok = Wait-Until {
      $script:legal = @(Get-RowsFor 'PFM Endorsements' $aId | Where-Object { [string]$_['CoordinationStage'] -eq 'Legal' }).Count
      $p = Get-PnPListItem -List 'PFM Publications' -Id $aId -Fields 'ProcessStep' -ErrorAction Stop
      $script:atStep = $(if ($p['ProcessStep']) { [int]$p['ProcessStep'].LookupId } else { 0 })
      ($script:legal -ge $wantLegal) -and ($script:atStep -eq $step7.Id) } 'the F05 Legal rows and step 7'
    Start-Sleep -Seconds 60
    $script:legal = @(Get-RowsFor 'PFM Endorsements' $aId | Where-Object { [string]$_['CoordinationStage'] -eq 'Legal' }).Count
    Add-Line 'm-f05-legal' $(if ($ok -and $script:legal -eq $wantLegal) { 'PASS' } else { 'FAIL' }) ('legal rows=' + $script:legal + ' expected=' + $wantLegal + ' (more = duplicates)')
    Add-Line 'n-f05-step7' $(if ($script:atStep -eq $step7.Id) { 'PASS' } else { 'FAIL' }) $(if ($script:atStep -eq $step7.Id) { 'publication A moved to step 7' } else { 'publication A not at step 7' })

    # 10. Clean-up. On a FAIL the rows stay for review; part 1 of the next run removes them (it finds them by title).
    if (@($lines | Where-Object { $_ -match '^ITEM .* FAIL' }).Count) { Add-Line 'o-clean-up' 'SKIP' 'kept for review because a check failed; part 1 of the next run removes them' }
    else {
      $n = 0
      foreach ($p in $aId, $hId, $fId) { $n += Clear-TestPublication $p }
      Remove-Item -LiteralPath $pubFile -Force
      Add-Line 'o-clean-up' 'SET' ('rows moved to the site Recycle Bin=' + $n)
    }
  }
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  $nf = @($lines | Where-Object { $_ -match '^ITEM .* FAIL' }).Count
  $lines.Add('SLICE1 part ' + $Part + ' done, items with problems=' + $nf)
} catch {
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)))
} finally {
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T18-slice1-part' + $Part + '-r2.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
