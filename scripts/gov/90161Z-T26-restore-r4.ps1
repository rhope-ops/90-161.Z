<#
.SYNOPSIS
  90-161.Z Task 26 r3, module "restore": the parts Rows, Change and Check of the RADE Restore test (R41). Moved here from
  90161Z-T26-endorse-r4.ps1 (code standard file size cap, C4); the code is unchanged.
.DESCRIPTION
  Loaded by 90161Z-T26-endorse-r4.ps1 (dot-sourced from the same folder, in its scope); it does nothing when it is run alone.
  Inputs: the values and helpers of the main file ($lines, $Pause, $script:stateFile, Add-Item,
  Read-State, Save-State, Get-RowsFor, Find-FakePub). Outputs: RESULT lines in $lines; the part functions Invoke-RowsPart,
  Invoke-ChangePart and Invoke-CheckPart.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection of the main file.
  Writes: Rows and Change: the fake rows named in the main file (and the pause-switch row) on the site and the state file; Check writes nothing.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T26-endorse-r4.ps1 loads it.
#>
# The Restore test (R41): the fake rows on the fake publication (moved here with the parts that use them).
$BinTitle = '90161Z TEST R41 restore {0} (delete me)'   # the 3 endorsement rows that go to the Recycle Bin ({0} = 1 to 3)
$LogTitle = '90161Z TEST R41 restore log (delete me)'   # the log row that is deleted for good
$NewTitle = '90161Z TEST R41 restore new (delete me)'   # the row made after the backup: Restore must leave it
# ---- The RADE Restore test (R41): the parts Rows, Change and Check ----
# Adds one "RESULT <name> PASS|FAIL <text>" line and counts it.
function Add-Result([string]$Name, [bool]$Ok, [string]$Text) {
  $lines.Add('RESULT ' + $Name + ' ' + $(if ($Ok) { 'PASS' } else { 'FAIL' }) + $(if ($Text) { ' ' + $Text } else { '' }))
  if ($Ok) { $script:passed++ } else { $script:failed++ }
}
# A value of the pause-switch row as a word for a result line: Yes, No, empty or other (no free text from the site).
function Get-ValueWord($V) { $t = ([string]$V).Trim(); if ($t -in 'Yes', 'No') { return $t }; if (-not $t) { return 'empty' }; return 'other' }
# The rows of PFM Settings whose title is the pause-switch row.
function Get-PauseRow {
  return @(Get-PnPListItem -List $Pause.List -Fields 'Title', $Pause.Field -PageSize 500 -ErrorAction Stop | Where-Object { ([string]$_['Title']).Trim() -eq $Pause.Title })
}
# The rows of list $List with title $Title on the fake publication $PubId, oldest first.
function Get-TitledRow([string]$List, [string]$Title, [int]$PubId) { return @(Get-RowsFor $List 'Publication' $PubId | Where-Object { ([string]$_['Title']) -eq $Title } | Sort-Object { $_.Id }) }
<#
.SYNOPSIS
  Rows, the pause-switch row: there once, with the off value; then read back (RESULT PAUSEROW).
.DESCRIPTION
  A missing row is made with the off value; a row with another value is set to it; two or more rows with that title
  are a FAIL (RADE reads one row) and are not changed. The value before goes into the state file as a word.
.PARAMETER State
  The state hashtable (gets PauseBefore and PauseAfter).
#>
function Initialize-PauseRow($State) {
  $rows = @(Get-PauseRow)
  if ($rows.Count -gt 1) { Add-Result 'PAUSEROW' $false ('rows named ' + $Pause.Title + '=' + $rows.Count + ': keep one, delete the others, then run again'); return }
  if (-not $rows.Count) {
    Write-Host 'NOW Making the pause-switch row in PFM Settings'
    $null = Add-PnPListItem -List $Pause.List -Values @{ Title = $Pause.Title; $Pause.Field = $Pause.Off } -ErrorAction Stop; $did = 'made'
    if (-not $State['PauseBefore']) { $State['PauseBefore'] = 'missing' } }
  else {
    # Only the first Rows run of a round saves the value before it: a rerun would save the round's own off value (review MAJOR)
    if (-not $State['PauseBefore']) { $State['PauseBefore'] = Get-ValueWord $rows[0][$Pause.Field] }
    if (([string]$rows[0][$Pause.Field]).Trim() -ceq $Pause.Off) { $did = 'kept' }
    else { $null = Set-PnPListItem -List $Pause.List -Identity $rows[0].Id -Values @{ $Pause.Field = $Pause.Off } -ErrorAction Stop; $did = 'set' } }
  $now = @(Get-PauseRow); $val = $(if ($now.Count -eq 1) { ([string]$now[0][$Pause.Field]).Trim() } else { '' })
  $State['PauseAfter'] = Get-ValueWord $val
  $text = 'row=' + $did + ' before=' + $State['PauseBefore'] + ' now=' + $State['PauseAfter'] + ' (RADE turns it to ' + $Pause.On + ' while Restore writes)'
  Add-Result 'PAUSEROW' ($now.Count -eq 1 -and $val -ceq $Pause.Off) $text
}
<#
.SYNOPSIS
  The part Rows: the pause-switch row, then the 3 endorsement rows and the log row on the fake publication.
.DESCRIPTION
  A row with the same title on the fake publication is used again, so a second run makes no second row. The row
  numbers go into the state file for the parts Change and Check.
#>
function Invoke-RowsPart {
  $st = Read-State $script:stateFile
  Initialize-PauseRow $st; Save-State $script:stateFile $st
  Write-Host 'NOW Looking for the fake publication'
  $pubId = $(if ($st['PubId'] -match '^\d+$') { [int]$st['PubId'] } else { $p = @(Find-FakePub); if ($p.Count) { [int]$p[0].Id } else { 0 } })
  if (-not $pubId) { Add-Result 'ROWS' $false 'no fake publication: run the part Make first'; return }
  $st['PubId'] = [string]$pubId; $made = 0; $found = 0
  $old = @((@(1, 2, 3) | ForEach-Object { $st['Bin' + $_] }) + $st['LogId']) -join ','
  for ($i = 1; $i -le 3; $i++) {
    $title = $BinTitle -f $i; $have = @(Get-TitledRow 'PFM Endorsements' $title $pubId)
    if ($have.Count) { $st['Bin' + $i] = [string]$have[0].Id; $found++; continue }
    $st['Bin' + $i] = [string](Add-PnPListItem -List 'PFM Endorsements' -Values @{ Title = $title; Publication = $pubId; CoordinationStage = 'Formal Coordination'
        EndorsementStatus = 'Not Started' } -ErrorAction Stop).Id; $made++
    Save-State $script:stateFile $st }
  $have = @(Get-TitledRow 'PFM Activity Log' $LogTitle $pubId)
  if ($have.Count) { $st['LogId'] = [string]$have[0].Id; $found++ }
  else { $st['LogId'] = [string](Add-PnPListItem -List 'PFM Activity Log' -Values @{ Title = $LogTitle; Publication = $pubId; EventType = 'Other' } -ErrorAction Stop).Id; $made++ }
  # Other row numbers than on file (rows made new): the marks of an earlier Change are for the old rows, so they go.
  if ((@((@(1, 2, 3) | ForEach-Object { $st['Bin' + $_] }) + $st['LogId']) -join ',') -ne $old) { foreach ($k in 'Gone1', 'Gone2', 'Gone3', 'Purged', 'NewId', 'ChangedAt') { $st.Remove($k) } }
  $st['RowsAt'] = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  Save-State $script:stateFile $st
  $lines.Add('ROWS endorsement rows=' + ((@(1, 2, 3) | ForEach-Object { $st['Bin' + $_] }) -join ',') + '; log row=' + $st['LogId'])
  Add-Result 'ROWS' $true ('made=' + $made + ' found=' + $found + ' (3 on PFM Endorsements, 1 on PFM Activity Log, all on the fake publication)')
}
<#
.SYNOPSIS
  The part Change (after the Back up): 3 rows to the Recycle Bin, 1 row deleted for good, 1 new row.
.DESCRIPTION
  Each write is marked in the state file when it is done, so a second run does only what is left. Remove-PnPListItem
  without -Recycle deletes the row for good: it never reaches the Recycle Bin, so Restore must make it again as a new row.
#>
function Invoke-ChangePart {
  $st = Read-State $script:stateFile
  if (-not ($st['LogId'] -match '^\d+$' -and $st['PubId'] -match '^\d+$')) { Add-Result 'CHANGE' $false 'no rows on file: run the part Rows first'; return }
  $pubId = [int]$st['PubId']; $gone = 0; $purged = 0; $added = 0; $skip = 0
  for ($i = 1; $i -le 3; $i++) {
    if ($st['Gone' + $i] -eq 'yes') { continue }
    # Only a row with its fake-data title on the fake publication is deleted.
    if (-not @(Get-TitledRow 'PFM Endorsements' ($BinTitle -f $i) $pubId | Where-Object { [int]$_.Id -eq [int]$st['Bin' + $i] }).Count) { $skip++; continue }
    $null = Remove-PnPListItem -List 'PFM Endorsements' -Identity ([int]$st['Bin' + $i]) -Recycle -Force -ErrorAction Stop
    $st['Gone' + $i] = 'yes'; $gone++; Save-State $script:stateFile $st }
  if ($st['Purged'] -ne 'yes') {
    # Deleted for good only when the row on file still has the fake-data title ("90161Z TEST ...") on the fake publication.
    if (@(Get-TitledRow 'PFM Activity Log' $LogTitle $pubId | Where-Object { [int]$_.Id -eq [int]$st['LogId'] -and ([string]$_['Title']).StartsWith('90161Z TEST') }).Count) {
      $null = Remove-PnPListItem -List 'PFM Activity Log' -Identity ([int]$st['LogId']) -Force -ErrorAction Stop
      $st['Purged'] = 'yes'; $purged++; Save-State $script:stateFile $st }
    else { $skip++ } }
  if ($st['NewId'] -notmatch '^\d+$') {
    $st['NewId'] = [string](Add-PnPListItem -List 'PFM Endorsements' -Values @{ Title = $NewTitle; Publication = $pubId; CoordinationStage = 'Formal Coordination'
        EndorsementStatus = 'Not Started' } -ErrorAction Stop).Id; $added++ }
  if (-not $st['ChangedAt']) { $st['ChangedAt'] = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss') }
  Save-State $script:stateFile $st
  $text = 'to the Recycle Bin=' + $gone + ' deleted for good=' + $purged + ' new row=' + $added + ' (new row number ' + $st['NewId'] + ')'
  if ($skip) { $text += '; rows on file not found with the fake-data title=' + $skip + ' (not deleted: run the part Rows again)' }
  Add-Result 'CHANGE' (-not $skip) $text
}
<#
.SYNOPSIS
  The part Check (after Restore; reads only): the rows Restore put back, the new row, the pause switch, the fresh backup.
.PARAMETER App
  The app folder (RADE\90-161.Z), which holds the Backups folder.
#>
function Invoke-CheckPart([string]$App) {
  $st = Read-State $script:stateFile
  if ($st['NewId'] -notmatch '^\d+$' -or $st['PubId'] -notmatch '^\d+$') { Add-Result 'RESTORE-BIN' $false 'no change on file: run the parts Rows and Change first'; return }
  $pubId = [int]$st['PubId']; $back = 0; $twice = 0
  for ($i = 1; $i -le 3; $i++) { $rows = @(Get-TitledRow 'PFM Endorsements' ($BinTitle -f $i) $pubId)
    if (@($rows | Where-Object { [int]$_.Id -eq [int]$st['Bin' + $i] }).Count) { $back++ }; if ($rows.Count -gt 1) { $twice++ } }
  Add-Result 'RESTORE-BIN' ($back -eq 3 -and -not $twice) ('back with the old row number=' + $back + ' of 3; made twice=' + $twice)
  $logs = @(Get-TitledRow 'PFM Activity Log' $LogTitle $pubId); $old = @($logs | Where-Object { [int]$_.Id -eq [int]$st['LogId'] }).Count
  $newNo = $(if ($logs.Count) { [string]$logs[0].Id } else { 'none' })
  Add-Result 'RESTORE-NEW' ($logs.Count -eq 1 -and -not $old) ('log rows=' + $logs.Count + '; with the old row number=' + $old + '; new row number=' + $newNo)
  $keep = @(Get-TitledRow 'PFM Endorsements' $NewTitle $pubId | Where-Object { [int]$_.Id -eq [int]$st['NewId'] }).Count
  Add-Result 'RESTORE-KEEP' ($keep -eq 1) ('the row made after the backup is there=' + $(if ($keep -eq 1) { 'yes' } else { 'no' }))
  $p = @(Get-PauseRow); $word = $(if ($p.Count -eq 1) { Get-ValueWord $p[0][$Pause.Field] } else { 'rows=' + $p.Count })
  Add-Result 'PAUSEROW' ($p.Count -eq 1 -and $word -eq $st['PauseAfter']) ('now=' + $word + ' before Restore=' + $st['PauseAfter'])
  $since = [datetime]::ParseExact($st['ChangedAt'], 'yyyy-MM-ddTHH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
  $fresh = @(Get-ChildItem -LiteralPath (Join-Path $App 'Backups') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -gt $since -and -not $_.Name.StartsWith('~') })
  Add-Result 'FRESH-BACKUP' ($fresh.Count -ge 1) ('Backups folders made after the change=' + $fresh.Count)
}
