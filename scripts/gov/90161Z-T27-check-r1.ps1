<#
.SYNOPSIS
  90-161.Z Task 27 r1, module "check" (round R43; the PFM, 25 Nov 26): the read-only checks after Uninstall and after the install
  from zero (parts Gone and Install), and the process step (part Step).
.DESCRIPTION
  Loaded by 90161Z-T27-lifecycle-r1.ps1 (dot-sourced from the same folder, in its scope); it does nothing when it is run alone.
  Inputs: the values and helpers of the main file and of the modules it loads (Add-Item, $lines, $OwnLists, Get-SiteList, Find-OurList,
  Get-GroupId, Get-RoleLevel, $OwnGroup, $OwnLevel). Outputs: ITEM and RESULT lines through them.
  THE PROCESS STEP (the PFM, 25 Nov 26: "Full process step"; the choice of step is the builder's, listed as open in the R43 notes):
  the move from step 1, "Request" (DAFMAN 90-161 3.1; docs/process-model.md "Stages", row 1: exit "Request saved; PFM confirms; DAF Form 673
  started"), to step 2, "Drafting with SMEs" (DAFMAN 90-161 3.2; row 2: exit "Draft uploaded", 60 target business days, Table A5.2).
  The fake publication of T26 Make starts at step 1; Step moves it to step 2, as the PFM does when the request is confirmed, and reads
  it back from the site. It proves that the installed lists take the move. It does NOT test the exit conditions of either step (no
  person and no flow acts here), so it is a move between 2 steps, not a whole step with its exit.
  The 60 days are read from the site row of step 2 (the seed of PFM Process Steps), so the part also shows that the install made the seed.
  The flows write the activity log row for the change when they are imported; this part reports the count as information only
  (a site with no flows has 0), so it does not depend on them.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection of the main file.
  Writes: Step: the process step of the fake publication of T26 (1 field of 1 row). Gone and Install write nothing.
  Credentials: none of its own (the main file signs in).
  Run: not alone.
#>

# The step the fake publication goes to (PFM Process Steps, StepNumber), and the step it starts at (T26 Make: step 1).
$StepFrom = 1
$StepTo = 2
# The title of the fake publication that T26 Make makes (scripts/gov/90161Z-T26-endorse-r2.ps1: $PubTitle; tests/ps/Test-T27.ps1 checks that they match)
# and the state file in which T26 keeps its row number (T26 folder).
$PubTitle = '90161Z TEST R41 endorse (delete me)'
$T26State = '90161Z-T26-endorse-state-r2.txt'

<#
.SYNOPSIS
  The part Gone (reads only): none of the 12 lists of 90-161.Z is on the site. The group and the level are reported as information
  (they stay when the site had them before the install).
#>
function Invoke-GonePart {
  Write-Host 'NOW Reading the lists of the site'
  $siteLists = Get-SiteList
  $left = @($OwnLists.Keys | Where-Object { Find-OurList $siteLists $_ })
  if ($left.Count) { Add-Item 'g1-lists' 'FAIL' ('lists of 90-161.Z still on the site=' + $left.Count + ' of ' + $OwnLists.Count + ': ' + (($left | ForEach-Object { $OwnLists[$_] }) -join ', ')) }
  else { Add-Item 'g1-lists' 'PASS' ('none of the ' + $OwnLists.Count + ' lists of 90-161.Z is on the site') }
  $lines.Add('ITEM g2-access INFO group ' + $OwnGroup + ' on the site=' + $(if (Get-GroupId $OwnGroup) { 'yes' } else { 'no' }) +
    '; level ' + $OwnLevel + ' on the site=' + $(if (Get-RoleLevel $OwnLevel 0) { 'yes' } else { 'no' }) + ' (kept when the site had them before the install)')
}
<#
.SYNOPSIS
  The part Install (reads only): the 12 lists are on the site under their titles, and PFM Process Steps holds the steps that the
  part Step needs.
#>
function Invoke-InstallPart {
  Write-Host 'NOW Reading the lists of the site'
  $siteLists = Get-SiteList
  $bad = @()
  foreach ($k in $OwnLists.Keys) {
    $l = Find-OurList $siteLists $k
    if (-not $l) { $bad += $OwnLists[$k] + ' (missing)' } elseif ([string]$l.Title -cne $OwnLists[$k]) { $bad += $OwnLists[$k] + ' (other title)' }
  }
  if ($bad.Count) { Add-Item 'i1-lists' 'FAIL' ('lists with a problem=' + $bad.Count + ' of ' + $OwnLists.Count + ': ' + ($bad -join ', ')) }
  else { Add-Item 'i1-lists' 'PASS' ('all ' + $OwnLists.Count + ' lists of 90-161.Z are on the site under their titles') }
  if ($bad -match 'PFM Process Steps') { Add-Item 'i2-steps' 'FAIL' 'PFM Process Steps is not usable: the seed rows cannot be read'; return }
  $steps = @(Get-StepRow)
  $have = @($StepFrom, $StepTo | Where-Object { $n = $_; @($steps | Where-Object { [int]$_['StepNumber'] -eq $n }).Count -eq 1 })
  if ($have.Count -eq 2) { Add-Item 'i2-steps' 'PASS' ('PFM Process Steps holds step ' + $StepFrom + ' and step ' + $StepTo + ' (rows in all=' + $steps.Count + ')') }
  else { Add-Item 'i2-steps' 'FAIL' ('PFM Process Steps misses step ' + $StepFrom + ' or step ' + $StepTo + ' (rows in all=' + $steps.Count + ')') }
}
# The rows of PFM Process Steps (all read; the list has 13 rows).
function Get-StepRow { return @(Get-PnPListItem -List 'PFM Process Steps' -Fields 'Title', 'StepNumber', 'TargetBusinessDays' -PageSize 500 -ErrorAction Stop) }
# The number in a lookup value (a SharePoint lookup reads back as an object with LookupId; a plain number is taken as it is); 0 when none.
function Get-LookupNumber($Value) {
  if ($null -eq $Value) { return 0 }
  if ($Value.PSObject.Properties['LookupId']) { return [int]$Value.LookupId }
  if ([string]$Value -match '^\d+$') { return [int]$Value }
  return 0
}
# The row number of the fake publication: from the T26 state file (T26 folder, next to the T27 folder), else by its exact title. 0 when none.
function Find-FakePubId([string]$Dir) {
  $state = Join-Path (Join-Path (Split-Path -Parent $Dir) 'T26') $T26State
  $rows = @(Get-PnPListItem -List 'PFM Publications' -Fields 'Title', 'ProcessStep' -PageSize 500 -ErrorAction Stop | Where-Object { ([string]$_['Title']) -ceq $PubTitle } | Sort-Object { $_.Id })
  if (-not $rows.Count) { return 0 }
  if (Test-Path -LiteralPath $state -PathType Leaf) {
    $hit = @(Get-Content -LiteralPath $state | Where-Object { ([string]$_) -match '^PubId=(\d+)$' })
    if ($hit.Count) { $id = [int](([string]$hit[0]).Substring(6)); if (@($rows | Where-Object { [int]$_.Id -eq $id }).Count) { return $id } }
  }
  return [int]$rows[0].Id
}
<#
.SYNOPSIS
  The part Step: the fake publication of T26 moves from step 1 (Request, DAFMAN 90-161 3.1) to step 2 (Drafting with SMEs, 3.2), and the move is read back.
.PARAMETER Dir
  The T27 folder (its neighbor T26 holds the T26 state file).
#>
function Invoke-StepPart([string]$Dir) {
  Write-Host 'NOW Looking for the fake publication'
  $pubId = Find-FakePubId $Dir
  if (-not $pubId) { Add-Item 's1-publication' 'FAIL' 'no fake publication on the site: run the step that makes it first'; $lines.Add('RESULT STEP FAIL no fake publication'); return }
  $steps = @(Get-StepRow)
  $to = @($steps | Where-Object { [int]$_['StepNumber'] -eq $StepTo })
  $from = @($steps | Where-Object { [int]$_['StepNumber'] -eq $StepFrom })
  if ($to.Count -ne 1 -or $from.Count -ne 1) {
    Add-Item 's1-publication' 'FAIL' ('PFM Process Steps has no single row for step ' + $StepFrom + ' or step ' + $StepTo + ' (the install did not seed it)')
    $lines.Add('RESULT STEP FAIL no step rows'); return
  }
  $now = Get-LookupNumber (@(Get-PnPListItem -List 'PFM Publications' -Fields 'Title', 'ProcessStep' -PageSize 500 -ErrorAction Stop | Where-Object { [int]$_.Id -eq $pubId })[0]['ProcessStep'])
  $at = $(if ($now -eq [int]$from[0].Id) { 'step ' + $StepFrom } elseif ($now -eq [int]$to[0].Id) { 'step ' + $StepTo } else { 'another step' })
  Add-Item 's1-publication' 'PASS' ('the fake publication is on the site and is at ' + $at)
  if ($now -eq [int]$to[0].Id) { Add-Item 's2-move' 'SKIP' ('the fake publication is at step ' + $StepTo + ' already (an earlier run moved it)') }
  else {
    Write-Host ('NOW Moving the fake publication to step ' + $StepTo)
    try { $null = Set-PnPListItem -List 'PFM Publications' -Identity $pubId -Values @{ ProcessStep = [int]$to[0].Id } -ErrorAction Stop }
    catch { Add-Item 's2-move' 'FAIL' ('the move failed: ' + (Get-ShortError $_)); $lines.Add('RESULT STEP FAIL not moved'); return }
    $back = Get-LookupNumber (@(Get-PnPListItem -List 'PFM Publications' -Fields 'Title', 'ProcessStep' -PageSize 500 -ErrorAction Stop | Where-Object { [int]$_.Id -eq $pubId })[0]['ProcessStep'])
    if ($back -ne [int]$to[0].Id) { Add-Item 's2-move' 'FAIL' ('read back: the publication is not at step ' + $StepTo); $lines.Add('RESULT STEP FAIL read back'); return }
    Add-Item 's2-move' 'PASS' ('moved from step ' + $StepFrom + ' to step ' + $StepTo + ' and read back from the site')
  }
  $days = [string]$to[0]['TargetBusinessDays']
  $logs = @(Get-PnPListItem -List 'PFM Activity Log' -PageSize 500 -ErrorAction Stop | Where-Object { (Get-LookupNumber $_['Publication']) -eq $pubId }).Count
  $lines.Add('ITEM s3-info INFO target business days of step ' + $StepTo + '=' + $days + '; activity log rows on the publication=' + $logs + ' (a flow writes them; 0 when no flow is imported)')
  $lines.Add('RESULT STEP PASS from=' + $StepFrom + ' to=' + $StepTo + ' target-days=' + $days)
}
