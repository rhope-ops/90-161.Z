<#
.SYNOPSIS
  90-161.Z Task 18 slice 1 end-to-end test, r1 (R20, PFM 14 Nov 26: slice 1 = PFM Publications + PFM Endorsements + F05
  routing + F03 reminders). Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: proves on the test site that the imported slice-1 flows work end to end, with one fake publication.
  Part 1 (about 5 minutes, an estimate):
    1. Signs in to the site (CAC) and reads the process steps (6 and 7) and the offices: how many Formal Coordination
       rows and Legal rows F05 should create (active mandatory offices; Legal = CoordinateLast).
    2. Creates one fake publication "90161Z TEST R20 (delete me)" at step 6 (Formal coordination).
    3. Waits up to 10 minutes for F05 to create the Formal Coordination rows, and counts them.
  Then the PFM runs F03 once by hand (the round's guide step).
  Part 2 (about 5 minutes, an estimate):
    4. Checks that F03 set a default suspense (21 or 30 days ahead) on each Formal Coordination row.
    5. Answers each Formal Coordination row "Concur", then sets "All Comments Adjudicated" on the publication.
    6. Waits up to 10 minutes for F05 to create the Legal rows and move the publication to step 7, and counts them.
    7. Clean-up: moves every row tied to the fake publication (Activity Log, Endorsements, the publication) to the site
       Recycle Bin (restorable for 93 days). Nothing else on the site is changed.
  WHAT IT CHANGES ON THE SITE: only the fake publication and the rows the flows make for it, all removed in step 7.
  The test rows get no e-mail: a suspense 21 days ahead is outside every F03 tier. F03 also checks every other open
  coordination row on the site, so part 1 counts those that could get a reminder now (due within 7 days or past); if
  that count is above 0, skip the F03 run.
  Counts only: no names, offices or addresses are written. The site address stays in Config\90161Z-site.txt on this
  computer; every output line shows it as <SITE> and the DODID as <DODID>.
  Output: 90161Z-T18-slice1-part1-r1.txt or 90161Z-T18-slice1-part2-r1.txt in the T18 folder (send both).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part 1 or 2, -WaitMinutes (default 10), -NoPause.
#>
param([string]$Id, [ValidateSet(1, 2)][int]$Part = 1, [int]$WaitMinutes = 10, [switch]$NoPause)
$task = 'T18'
$TestTitle = '90161Z TEST R20 (delete me)'

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
  # Rows of a list whose Publication lookup points at the fake publication (CAML by lookup ID).
  $q = "<View><Query><Where><Eq><FieldRef Name='Publication' LookupId='TRUE'/><Value Type='Lookup'>" + $PubId + "</Value></Eq></Where></Query></View>"
  return @(Get-PnPListItem -List $List -Query $q -ErrorAction Stop)
}
function Get-Stage($Item) { return [string]$Item['CoordinationStage'] }
function Wait-Until([scriptblock]$Done, [string]$What) {
  # Checks every 30 seconds for up to $WaitMinutes. Returns $true when $Done returns $true.
  $end = (Get-Date).AddMinutes($WaitMinutes)
  while ($true) {
    if (& $Done) { return $true }
    if ((Get-Date) -ge $end) { return $false }
    Write-Host ('  Waiting for ' + $What + ' (checks every 30 seconds, up to ' + $WaitMinutes + ' minutes) ...')
    Start-Sleep -Seconds 30
  }
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
  $pubFile = Join-Path $dir '90161Z-T18-test-publication.txt'   # the fake publication's item ID (a number), for part 2
  $lines.Add('TASK T18 slice 1 end-to-end r1, part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ', wait-minutes=' + $WaitMinutes)
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'Connecting to the site. If a sign-in window opens, sign in with your CAC.'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')

  # 1. What F05 should create: one Formal row per active mandatory office that is not CoordinateLast; Legal rows for CoordinateLast.
  $steps = @(Get-PnPListItem -List 'PFM Process Steps' -Fields 'StepNumber' -ErrorAction Stop)
  $step6 = @($steps | Where-Object { [int]$_['StepNumber'] -eq 6 })[0]; $step7 = @($steps | Where-Object { [int]$_['StepNumber'] -eq 7 })[0]
  if (-not $step6 -or -not $step7) { throw 'PROCESS STEPS 6 and 7 not found in PFM Process Steps.' }
  $offices = @(Get-PnPListItem -List 'PFM Offices' -Fields 'MandatoryCoordinator', 'IsActive', 'CoordinateLast' -ErrorAction Stop | Where-Object { $_['IsActive'] -and $_['MandatoryCoordinator'] })
  $wantFormal = @($offices | Where-Object { -not $_['CoordinateLast'] }).Count
  $wantLegal = @($offices | Where-Object { $_['CoordinateLast'] }).Count
  Add-Line 'a-setup' $(if ($wantFormal -gt 0 -and $wantLegal -gt 0) { 'PASS' } else { 'FAIL' }) ('expected formal=' + $wantFormal + ' legal=' + $wantLegal + ' (active mandatory offices)')

  if ($Part -eq 1) {
    # 2. Remove a fake publication left by an earlier run, then create a new one at step 6.
    $old = @(Get-PnPListItem -List 'PFM Publications' -Fields 'Title' -ErrorAction Stop | Where-Object { [string]$_['Title'] -eq $TestTitle })
    foreach ($o in $old) {
      foreach ($l in 'PFM Activity Log', 'PFM Endorsements') { foreach ($r in (Get-RowsFor $l $o.Id)) { $null = Remove-PnPListItem -List $l -Identity $r.Id -Recycle -Force -ErrorAction Stop } }
      $null = Remove-PnPListItem -List 'PFM Publications' -Identity $o.Id -Recycle -Force -ErrorAction Stop
    }
    # Other open rows F03 would e-mail if run now (suspense within 7 days or past): a count only.
    $soon = (Get-Date).Date.AddDays(7)
    $others = @(Get-PnPListItem -List 'PFM Endorsements' -Fields 'EndorsementStatus', 'DueDate' -ErrorAction Stop | Where-Object { [string]$_['EndorsementStatus'] -eq 'Not Started' -and $_['DueDate'] -and ([datetime]$_['DueDate']).ToLocalTime().Date -le $soon }).Count
    Add-Line 'b2-other-rows' $(if ($others) { 'FAIL' } else { 'PASS' }) ('other open rows due within 7 days or past=' + $others + $(if ($others) { '. Skip the F03 run: those rows would get a real reminder' } else { '' }))
    if ($old.Count) { Add-Line 'b-leftovers' 'SET' ('moved ' + $old.Count + ' earlier test publication(s) and their rows to the Recycle Bin') }
    $pub = Add-PnPListItem -List 'PFM Publications' -Values @{ Title = $TestTitle; ActionType = 'New'; ProductType = 'Publication'; ProcessStep = $step6.Id; ActionStatus = 'On Track' } -ErrorAction Stop
    Set-Content -LiteralPath $pubFile -Value ([string]$pub.Id) -Encoding UTF8
    Add-Line 'c-create' 'SET' ('fake publication created at step 6, item ' + $pub.Id)
    # 3. F05 creates the Formal Coordination rows.

    $ok = Wait-Until { $script:got = @(Get-RowsFor 'PFM Endorsements' $pub.Id | Where-Object { (Get-Stage $_) -eq 'Formal Coordination' }).Count; $script:got -ge $wantFormal } 'the F05 Formal Coordination rows'
    $got = $script:got
    Add-Line 'd-f05-formal' $(if ($ok -and $got -eq $wantFormal) { 'PASS' } else { 'FAIL' }) ('formal rows=' + $got + ' expected=' + $wantFormal + $(if ($ok) { '' } else { '. If 0: check that F05 is turned on and that its run history shows a run' }))
  } else {
    if (-not (Test-Path -LiteralPath $pubFile -PathType Leaf)) { throw 'NO TEST PUBLICATION: run part 1 first.' }
    $pubId = [int]([string](Get-Content -LiteralPath $pubFile -TotalCount 1)).Trim()
    $formal = @(Get-RowsFor 'PFM Endorsements' $pubId | Where-Object { (Get-Stage $_) -eq 'Formal Coordination' })
    # 4. F03 set a default suspense: 21 days ahead (30 for Guard or Reserve Applicability).
    $today = (Get-Date).Date; $withDue = 0
    foreach ($r in $formal) { $d = $r['DueDate']; if ($d) { $days = ([datetime]$d).ToLocalTime().Date.Subtract($today).Days; if ($days -ge 19 -and $days -le 31) { $withDue++ } } }
    Add-Line 'e-f03-suspense' $(if ($formal.Count -and $withDue -eq $formal.Count) { 'PASS' } else { 'FAIL' }) ('rows with a default suspense=' + $withDue + ' of ' + $formal.Count + $(if ($withDue -lt $formal.Count) { '. Check that F03 ran (its run history)' } else { '' }))
    # 5. Answer the Formal rows, then mark the comments adjudicated (this edit starts F05's gate).
    foreach ($r in $formal) { $null = Set-PnPListItem -List 'PFM Endorsements' -Identity $r.Id -Values @{ EndorsementStatus = 'Concur' } -ErrorAction Stop }
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $pubId -Values @{ AllCommentsAdjudicated = $true } -ErrorAction Stop
    Add-Line 'f-answers' 'SET' ('formal rows answered Concur=' + $formal.Count + ', All Comments Adjudicated=Yes')
    # 6. F05 creates the Legal rows and moves the publication to step 7.
    $script:legal = 0; $script:atStep = 0
    $ok = Wait-Until {
      $script:legal = @(Get-RowsFor 'PFM Endorsements' $pubId | Where-Object { (Get-Stage $_) -eq 'Legal' }).Count
      $p = Get-PnPListItem -List 'PFM Publications' -Id $pubId -Fields 'ProcessStep' -ErrorAction Stop
      $script:atStep = $(if ($p['ProcessStep']) { [int]$p['ProcessStep'].LookupId } else { 0 })
      ($script:legal -ge $wantLegal) -and ($script:atStep -eq $step7.Id) } 'the F05 Legal rows and step 7'
    Add-Line 'g-f05-legal' $(if ($ok -and $script:legal -eq $wantLegal) { 'PASS' } else { 'FAIL' }) ('legal rows=' + $script:legal + ' expected=' + $wantLegal)
    Add-Line 'h-f05-step7' $(if ($script:atStep -eq $step7.Id) { 'PASS' } else { 'FAIL' }) $(if ($script:atStep -eq $step7.Id) { 'publication moved to step 7' } else { 'publication not at step 7' })
    $logRows = @(Get-RowsFor 'PFM Activity Log' $pubId).Count
    Add-Line 'i-activity-log' 'PASS' ('activity log rows for the test publication=' + $logRows)
    # 7. Clean-up: everything tied to the fake publication goes to the site Recycle Bin. On a FAIL the rows stay for review;
    # part 1 of the next run removes them (it finds the fake publication by its title).
    if (@($lines | Where-Object { $_ -match '^ITEM .* FAIL' }).Count) { Add-Line 'j-clean-up' 'SKIP' 'kept for review because a check failed; part 1 of the next run removes them' }
    else {
    $n = 0
    foreach ($l in 'PFM Activity Log', 'PFM Endorsements') { foreach ($r in (Get-RowsFor $l $pubId)) { $null = Remove-PnPListItem -List $l -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ } }
    $null = Remove-PnPListItem -List 'PFM Publications' -Identity $pubId -Recycle -Force -ErrorAction Stop; $n++
    Remove-Item -LiteralPath $pubFile -Force
    Add-Line 'j-clean-up' 'SET' ('rows moved to the site Recycle Bin=' + $n)
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
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T18-slice1-part' + $Part + '-r1.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
