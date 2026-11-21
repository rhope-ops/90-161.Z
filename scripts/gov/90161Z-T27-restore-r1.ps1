<#
.SYNOPSIS
  90-161.Z Task 27 r1 (round R41): the test-site rows of the RADE Restore test, and the check after Restore.
  Windows PowerShell 5.1 (also 7), the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for (docs/reviews/2026-11-21-r41-plan.md row 5; RADE engine-v31 release notes, the R41 click table): RADE's
  Maintenance > Restore puts back rows that are missing from the app's lists, from the Recycle Bin first (same row
  number), else as new rows. This task makes the fake rows that the test deletes, deletes them after the Back up, and
  checks the site after Restore. The writes are approved by the PFM (21 Nov 26: 3 rows deleted, 1 row deleted and
  purged, 1 new row, then Restore; fake rows only).
  Parts (-Part):
    Make   (about 1 minute, an estimate)  Signs in. The pause-switch row: PFM Settings "FlowsPaused" must be there with
           "No" (the manifest's restore.pause: list PFM Settings, row FlowsPaused, field SettingValue, on value Yes);
           a missing row is made, another value is set to No. RADE turns it to Yes while Restore writes and puts it
           back after. The row-writing flows read it from R42 on (the PFM, 21 Nov 26), so in R41 it pauses nothing.
           Then 3 fake rows on PFM Endorsements and 1 fake row on PFM Activity Log, each on the fake publication of T26
           ("90161Z TEST R41 endorse (delete me)"), so T26 Clean removes them, and any row Restore makes again, at the end.
    Change (about 1 minute)  After the Back up: moves the 3 endorsement rows to the site Recycle Bin, deletes the log
           row for good (not to the Recycle Bin: the same as deleting it and emptying it from the Recycle Bin), and adds
           1 new fake endorsement row. A second run changes nothing that is done already.
    Check  (about 1 minute)  After Restore. Reads only. RESULT RESTORE-BIN: the 3 endorsement rows are back with their
           old row numbers, once each. RESULT RESTORE-NEW: the log row is back with a new row number. RESULT RESTORE-KEEP:
           the new row is still there. RESULT PAUSEROW: the pause-switch row has its old value (No). RESULT FRESH-BACKUP:
           a Backups folder newer than the part Change (Restore saves a fresh backup before it writes).
  Fake data only: every row has a title that starts with "90161Z TEST". Counts, row numbers of the fake rows and the
  words Yes, No or other only: no names, no addresses, no row text from the site.
  WHAT IT CHANGES ON THE SITE: Make: at most 1 PFM Settings row (made or set to No), 3 rows on PFM Endorsements and 1 row
  on PFM Activity Log (once; a second run finds them). Change: 3 rows to the Recycle Bin, 1 row deleted for good, 1 new
  row. Check changes nothing.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell.
  Writes: on the site, the rows above; on this computer the T27 folder (the result file, the state file) and, once,
          Config\90161Z-site.txt when the site address is typed outside RADE.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Output: 90161Z-T27-restore-<part>-r1.txt in the T27 folder. Last line: RESTORE <part> done: passed=<n> failed=<n>.
  Exit 1 only when the part could not run (sign-in, missing list or module).
  Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File 90161Z-T27-restore-r1.ps1 -Part <part> (RADE does this).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Part
  Make, Change or Check.
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T27 folder (its parent is the app folder, with Backups).
#>
param([string]$Id, [ValidateSet('Make', 'Change', 'Check')][string]$Part, [switch]$NoPause, [string]$TestDir)
$task = 'T27'
$Rev = 'r1'
$PubTitle = '90161Z TEST R41 endorse (delete me)'   # the fake publication of T26 (90161Z-T26-endorse-r1.ps1)
$BinTitle = '90161Z TEST R41 restore {0} (delete me)'   # the 3 endorsement rows that go to the Recycle Bin ({0} = 1 to 3)
$LogTitle = '90161Z TEST R41 restore log (delete me)'   # the log row that is deleted for good
$NewTitle = '90161Z TEST R41 restore new (delete me)'   # the row made after the backup: Restore must leave it
$StateName = '90161Z-T27-restore-state-r1.txt'
# The pause switch: the same 4 values as "restore.pause" of the deploy app in scripts/paste_bundles.json
# (tests/ps/Test-T27.ps1 checks that they match). Off is the seed value (schemas/lists/PFMSettings.json).
$Pause = @{ List = 'PFM Settings'; Title = 'FlowsPaused'; Field = 'SettingValue'; On = 'Yes'; Off = 'No' }

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

# >>> site-common: generated from scripts/gov/src/site-common.ps1 by scripts/build_task_scripts.py (do not edit)
function Get-SiteAddress([string]$ConfigDir) {
  # One entry (PFM 15 Nov 26): the address RADE holds (RADE_SITE, from its "Site address" box) is used with no question;
  # outside RADE the one saved in Config\90161Z-site.txt is used. Only when neither exists does a question open (once).
  # To change the site, use "Change the site address" in RADE. Kept only on this computer (the repo is public).
  $ok = '^https://[^/\s]+/sites/[^/\s]+'
  $v = ([string]$env:RADE_SITE).Trim()
  if ($v -match $ok) { return $v }
  $f = Join-Path $ConfigDir '90161Z-site.txt'
  if (Test-Path -LiteralPath $f -PathType Leaf) { $v = ([string](Get-Content -LiteralPath $f -TotalCount 1)).Trim(); if ($v -match $ok) { return $v } }
  # RADE runs a step with no window, so a question there would wait unseen: stop with the fix instead.
  if ($env:RADE_CONTRACT) { throw 'SITE ADDRESS not set. Complete the "Site address" box in RADE, then run this step again.' }
  $v = ([string](Read-Host 'Site address (it starts with https://; it is kept only on this computer), then press Enter')).Trim()
  if ($v -notmatch $ok) { throw 'SITE ADDRESS not given or not a site address (https://<host>/sites/<name>). Run again.' }
  if (-not (Test-Path -LiteralPath $ConfigDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $ConfigDir -Force) }
  Set-Content -LiteralPath $f -Value $v -Encoding UTF8
  return $v
}

function Hide-Site([string]$Text, [string]$Site) {
  <#
  .SYNOPSIS
  Masks e-mail addresses, the site, its host, path, name and tenant, other URLs, cloud and .mil hosts and GUIDs in a
  result text. Not masked: display names, office symbols, phone numbers, user ids, computer names.
  .PARAMETER Text
  The text to clean (a result line or an error message).
  .PARAMETER Site
  The site address (https://<host>/sites/<name>), or an empty text for the generic rules only.
  .OUTPUTS
  System.String. The text with each match replaced by a placeholder such as <EMAIL>, <SITE> or <GUID>.
  #>
  # The address only (name, @ or %40, host; encoded characters and an apostrophe inside the name count as part of it),
  # first: the host rules below would
  # keep its name part.
  $Text = $Text -replace '(?:[\w.+=-]|%[0-9A-Fa-f]{2}|(?<=\w)[''\u2019](?=\w))+(?:@|%40)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*(?:%[0-9A-Fa-f]{2})*', '<EMAIL>'
  if ($Site) {
    $Text = $Text -replace [regex]::Escape($Site.TrimEnd('/')), '<SITE>'
    try {
      $u = [uri]$Site; $p = $u.AbsolutePath.TrimEnd('/'); $leaf = ($p -split '/')[-1]   # $p is /sites/<name>: also in URL-encoded form
      $set = @(, @($u.Host, '<SITE-HOST>', ''))   # literal text, placeholder, word boundary (tenant and site name only, 3+ letters)
      if ($p.Length -gt 1) { $set += @($p, '<SITE-PATH>', ''), @([uri]::EscapeDataString($p), '<SITE-PATH>', ''), @($leaf, '<SITE-NAME>', '\b') }
      $set += , @(($u.Host -split '\.')[0], '<TENANT>', '\b')
      foreach ($s in $set) { if ($s[2] -eq '' -or $s[0].Length -ge 3) { $Text = $Text -replace ($s[2] + [regex]::Escape($s[0]) + $s[2]), $s[1] } }
    } catch { $null = $_ }
  }
  # Pattern and mask pairs. The GUID has no \b: guid%27<id> must be masked too.
  $g = @('https?://\S+', '<URL>', '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>',
    '\b[\w.-]+\.mil\b', '<HOST>', '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>')
  for ($i = 0; $i -lt $g.Count; $i += 2) { $Text = $Text -replace $g[$i], $g[$i + 1] }
  return $Text
}
# <<< site-common

$lines = New-Object System.Collections.Generic.List[string]
$script:passed = 0; $script:failed = 0
# Adds one "RESULT <name> PASS|FAIL <text>" line and counts it.
function Add-Result([string]$Name, [bool]$Ok, [string]$Text) {
  $lines.Add('RESULT ' + $Name + ' ' + $(if ($Ok) { 'PASS' } else { 'FAIL' }) + $(if ($Text) { ' ' + $Text } else { '' }))
  if ($Ok) { $script:passed++ } else { $script:failed++ }
}
# The state file as a hashtable (key=value lines); empty when the file is missing.
function Read-State([string]$Path) {
  $h = @{}
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    foreach ($l in (Get-Content -LiteralPath $Path)) { $i = ([string]$l).IndexOf('='); if ($i -gt 0) { $h[([string]$l).Substring(0, $i)] = ([string]$l).Substring($i + 1) } } }
  return $h
}
# Writes the state hashtable to the state file as sorted key=value lines (row numbers, flags and a time only).
function Save-State([string]$Path, $State) { Set-Content -LiteralPath $Path -Value @($State.Keys | Sort-Object | ForEach-Object { $_ + '=' + $State[$_] }) -Encoding ASCII }
# A value of the pause-switch row as a word for a result line: Yes, No, empty or other (no free text from the site).
function Get-ValueWord($V) { $t = ([string]$V).Trim(); if ($t -in 'Yes', 'No') { return $t }; if (-not $t) { return 'empty' }; return 'other' }
# The rows of PFM Settings whose title is the pause-switch row.
function Get-PauseRow { return @(Get-PnPListItem -List $Pause.List -Fields 'Title', $Pause.Field -PageSize 500 -ErrorAction Stop | Where-Object { ([string]$_['Title']).Trim() -eq $Pause.Title }) }
# The rows of list $List with title $Title on the fake publication $PubId, oldest first.
function Get-FakeRow([string]$List, [string]$Title, [int]$PubId) {
  return @(Get-PnPListItem -List $List -PageSize 500 -ErrorAction Stop | Where-Object { ([string]$_['Title']) -eq $Title -and $_['Publication'] -and [int]$_['Publication'].LookupId -eq $PubId } | Sort-Object { $_.Id })
}
# Loads PnP.PowerShell and signs in to the one site with the web login (CAC).
function Connect-RestoreSite {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'NOW Signing in to the site (if a sign-in window opens, sign in with your CAC)'
  $null = & { Connect-PnPOnline -Url $script:site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
}
<#
.SYNOPSIS
  Make, the pause-switch row: there once, with the off value; then read back (RESULT PAUSEROW).
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
    $null = Add-PnPListItem -List $Pause.List -Values @{ Title = $Pause.Title; $Pause.Field = $Pause.Off } -ErrorAction Stop; $did = 'made'; $State['PauseBefore'] = 'missing' }
  else {
    $State['PauseBefore'] = Get-ValueWord $rows[0][$Pause.Field]
    if (([string]$rows[0][$Pause.Field]).Trim() -ceq $Pause.Off) { $did = 'kept' }
    else { $null = Set-PnPListItem -List $Pause.List -Identity $rows[0].Id -Values @{ $Pause.Field = $Pause.Off } -ErrorAction Stop; $did = 'set' } }
  $now = @(Get-PauseRow); $val = $(if ($now.Count -eq 1) { ([string]$now[0][$Pause.Field]).Trim() } else { '' })
  $State['PauseAfter'] = Get-ValueWord $val
  Add-Result 'PAUSEROW' ($now.Count -eq 1 -and $val -ceq $Pause.Off) ('row=' + $did + ' before=' + $State['PauseBefore'] + ' now=' + $State['PauseAfter'] + ' (RADE turns it to ' + $Pause.On + ' while Restore writes)')
}
<#
.SYNOPSIS
  The part Make: the pause-switch row, then the 3 endorsement rows and the log row on the fake publication.
.DESCRIPTION
  A row with the same title on the fake publication is used again, so a second run makes no second row. The row
  numbers go into the state file for the parts Change and Check.
.PARAMETER State
  The state hashtable (saved by the caller).
#>
function Invoke-MakePart($State) {
  Initialize-PauseRow $State; Save-State $script:stateFile $State
  Write-Host 'NOW Looking for the fake publication'
  $pub = @(Get-PnPListItem -List 'PFM Publications' -Fields 'Title' -PageSize 500 -ErrorAction Stop | Where-Object { ([string]$_['Title']) -eq $PubTitle } | Sort-Object { $_.Id })
  if (-not $pub.Count) { Add-Result 'ROWS' $false 'no fake publication: run the step that makes it first'; return }
  $pubId = [int]$pub[0].Id; $State['PubId'] = [string]$pubId; $made = 0; $found = 0
  for ($i = 1; $i -le 3; $i++) {
    $title = $BinTitle -f $i; $have = @(Get-FakeRow 'PFM Endorsements' $title $pubId)
    if ($have.Count) { $State['Bin' + $i] = [string]$have[0].Id; $found++; continue }
    $State['Bin' + $i] = [string](Add-PnPListItem -List 'PFM Endorsements' -Values @{ Title = $title; Publication = $pubId; CoordinationStage = 'Formal Coordination'
        EndorsementStatus = 'Not Started' } -ErrorAction Stop).Id; $made++
    Save-State $script:stateFile $State }
  $have = @(Get-FakeRow 'PFM Activity Log' $LogTitle $pubId)
  if ($have.Count) { $State['LogId'] = [string]$have[0].Id; $found++ }
  else { $State['LogId'] = [string](Add-PnPListItem -List 'PFM Activity Log' -Values @{ Title = $LogTitle; Publication = $pubId; EventType = 'Other' } -ErrorAction Stop).Id; $made++ }
  $lines.Add('ROWS endorsement rows=' + ((@(1, 2, 3) | ForEach-Object { $State['Bin' + $_] }) -join ',') + '; log row=' + $State['LogId'])
  Add-Result 'ROWS' $true ('made=' + $made + ' found=' + $found + ' (3 on PFM Endorsements, 1 on PFM Activity Log, all on the fake publication)')
}
<#
.SYNOPSIS
  The part Change (after the Back up): 3 rows to the Recycle Bin, 1 row deleted for good, 1 new row.
.DESCRIPTION
  Each write is marked in the state file when it is done, so a second run does only what is left. Remove-PnPListItem
  without -Recycle deletes the row for good: it never reaches the Recycle Bin, so Restore must make it again as a new row.
.PARAMETER State
  The state hashtable (saved by this part after each write).
#>
function Invoke-ChangePart($State) {
  if (-not ($State['LogId'] -match '^\d+$' -and $State['PubId'] -match '^\d+$')) { Add-Result 'CHANGE' $false 'no rows on file: run the part Make first'; return }
  $gone = 0
  for ($i = 1; $i -le 3; $i++) {
    if ($State['Gone' + $i] -ne 'yes') { $null = Remove-PnPListItem -List 'PFM Endorsements' -Identity ([int]$State['Bin' + $i]) -Recycle -Force -ErrorAction Stop
      $State['Gone' + $i] = 'yes'; Save-State $script:stateFile $State }
    $gone++ }
  if ($State['Purged'] -ne 'yes') { $null = Remove-PnPListItem -List 'PFM Activity Log' -Identity ([int]$State['LogId']) -Force -ErrorAction Stop
    $State['Purged'] = 'yes'; Save-State $script:stateFile $State }
  if ($State['NewId'] -notmatch '^\d+$') {
    $State['NewId'] = [string](Add-PnPListItem -List 'PFM Endorsements' -Values @{ Title = $NewTitle; Publication = [int]$State['PubId']; CoordinationStage = 'Formal Coordination'
        EndorsementStatus = 'Not Started' } -ErrorAction Stop).Id }
  if (-not $State['ChangedAt']) { $State['ChangedAt'] = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss') }
  Save-State $script:stateFile $State
  Add-Result 'CHANGE' $true ('to the Recycle Bin=' + $gone + ' deleted for good=1 new row=1 (new row number ' + $State['NewId'] + ')')
}
<#
.SYNOPSIS
  The part Check (after Restore; reads only): the rows Restore put back, the new row, the pause switch, the fresh backup.
.PARAMETER State
  The state hashtable (not changed).
.PARAMETER App
  The app folder (RADE\90-161.Z), which holds the Backups folder.
#>
function Invoke-CheckPart($State, [string]$App) {
  if ($State['NewId'] -notmatch '^\d+$' -or $State['PubId'] -notmatch '^\d+$') { Add-Result 'RESTORE-BIN' $false 'no change on file: run the parts Make and Change first'; return }
  $pubId = [int]$State['PubId']; $back = 0; $twice = 0
  for ($i = 1; $i -le 3; $i++) { $rows = @(Get-FakeRow 'PFM Endorsements' ($BinTitle -f $i) $pubId)
    if (@($rows | Where-Object { [int]$_.Id -eq [int]$State['Bin' + $i] }).Count) { $back++ }; if ($rows.Count -gt 1) { $twice++ } }
  Add-Result 'RESTORE-BIN' ($back -eq 3 -and -not $twice) ('back with the old row number=' + $back + ' of 3; made twice=' + $twice)
  $logs = @(Get-FakeRow 'PFM Activity Log' $LogTitle $pubId); $old = @($logs | Where-Object { [int]$_.Id -eq [int]$State['LogId'] }).Count
  Add-Result 'RESTORE-NEW' ($logs.Count -eq 1 -and -not $old) ('log rows=' + $logs.Count + '; with the old row number=' + $old + '; new row number=' + $(if ($logs.Count) { [string]$logs[0].Id } else { 'none' }))
  $keep = @(Get-PnPListItem -List 'PFM Endorsements' -PageSize 500 -ErrorAction Stop | Where-Object { [int]$_.Id -eq [int]$State['NewId'] -and ([string]$_['Title']) -eq $NewTitle }).Count
  Add-Result 'RESTORE-KEEP' ($keep -eq 1) ('the row made after the backup is there=' + $(if ($keep -eq 1) { 'yes' } else { 'no' }))
  $p = @(Get-PauseRow); $word = $(if ($p.Count -eq 1) { Get-ValueWord $p[0][$Pause.Field] } else { 'rows=' + $p.Count })
  Add-Result 'PAUSEROW' ($p.Count -eq 1 -and $word -eq $State['PauseAfter']) ('now=' + $word + ' before Restore=' + $State['PauseAfter'])
  $since = [datetime]::ParseExact($State['ChangedAt'], 'yyyy-MM-ddTHH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
  $fresh = @(Get-ChildItem -LiteralPath (Join-Path $App 'Backups') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -gt $since -and -not $_.Name.StartsWith('~') })
  Add-Result 'FRESH-BACKUP' ($fresh.Count -ge 1) ('Backups folders made after the change=' + $fresh.Count)
}

$fatal = $false; $site = ''; $secret = @(); $dir = ''
try {
  $ErrorActionPreference = 'Stop'
  if (-not $Part) { throw 'PART not given: use -Part Make, Change or Check.' }
  $who = Get-TaskId $Id; $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 27' -Create }
  Set-Location -LiteralPath $dir
  $script:stateFile = Join-Path $dir $StateName
  $script:site = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config')
  $site = $script:site
  $lines.Add('TASK T27 restore ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $state = Read-State $script:stateFile
  Connect-RestoreSite
  switch ($Part) { 'Make' { Invoke-MakePart $state; Save-State $script:stateFile $state } 'Change' { Invoke-ChangePart $state } default { Invoke-CheckPart $state (Split-Path -Parent $dir) } }
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
} catch {
  $fatal = $true
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)) + ' (the part can be run again)')
} finally {
  $lines.Add('RESTORE ' + $Part + ' done: passed=' + $script:passed + ' failed=' + $script:failed)
  # Every line is masked once more before it is shown or saved.
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir -and $Part) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T27-restore-' + $Part.ToLowerInvariant() + '-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
