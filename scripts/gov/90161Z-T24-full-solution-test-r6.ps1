<#
.SYNOPSIS
  90-161.Z Task 24 full-solution test, r6. Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
  WHAT R6 CHANGES (R36, PFM 19 Nov 26): part 0 (module 90161Z-T24-zip-r6.ps1) writes the 8 list GUIDs into a copy of the solution zip before the import;
  part 1 counts the 7 flows F01 to F07 (F07 r1); part 2 counts only the Publications rows without a Closed Date (F04 r4). Files keep r1 names.
.DESCRIPTION
  What it is for: proves on the test site that F01 (activity log), F02 (next review due and periodic review task) and F04 (status report e-mail)
  work, and that the full solution imported with every flow On. It runs in parts with hand steps between them (round guide).
  Part 0 (about 1 minute, an estimate; before the import): reads the GUID of each list a placeholder of 90161Z-T24-full-flows-r5.zip names (by its
    title, on your own site only) and writes 90161Z-T24-full-flows-r5-ready.zip, the file to import; stops when a list is missing or a placeholder is left.
  Part 1 (about 35 minutes, an estimate; most of it is waiting for the 15-minute F01 checks, -PollMinutes; F05 checks every minute, -F05Minutes):
    0. Writes the PFM Settings rows Flows paused = No and Test mode = Yes (their old values are kept in a state file and put back in part 4).
    a. Reads your own flows in Power Automate and counts the 7 flows F01 to F07 that are On (one try; if it cannot be read, a hand check line).
    1. F01 (no DAFMAN paragraph; PFM design) and F05 (DAFMAN 90-161 5.1.7, 5.1.8.2): makes 6 fake publications at once: X, X type, X step and
       X status at the first step of the list, G at step 3 and S at step 7. After the first flow check: each has 1 log row (opened) and S has 1 Legal
       row per active office with Coordinate Last = Yes. Then at once: a note on X and on S, a new Action Type on X type, Process Step on X step,
       Action Status on X status, and G moved by hand to step 7. After the next check: 1 more log row each for X type, X step and X status, none for
       X (a note), G has its Legal rows and S has no second Legal row.
    2. F02 (DAFMAN 90-161 7.4.2 and 7.4.4): makes 4 fake Product Index rows (A: Certified Current Date is later, a wrong Next Review Due; B: Effective
       Date is later, the review window not open yet; C: like A with a periodic review already open; D: Inactive) and 1 review row.
    3. F04 (DAFMAN 90-161 2.6.8): makes 2 fake publications at 2 process steps and notes the newest status-report log row.
  Then you start F02 and F04 once each with Run (round guide).
  Part 2 (about 4 minutes, an estimate): checks what F02 did (Next Review Due 4 years after the later date; the review row 6 months before; none for B
    and D; the open one kept for C) and what F04 logged (1 row; test mode; the count of open actions). Then you start F02 a second time.
  Part 3 (about 2 minutes, an estimate): checks that F02's second run made no second review row. Nothing is removed here.
  Part 4 (Clean, about 3 minutes, an estimate; R28 review): moves every fake row to the site Recycle Bin (restorable for 93 days) and puts the PFM
    Settings rows back to their old values. The round runs it with no dependence on the earlier parts, so a failed or skipped part cannot leave the
    Settings changed or the fake rows on the site. It can run again: with no state file it reports that there is nothing to clean.
  WHAT IT CHANGES ON THE SITE: the fake rows (publications, product index rows, review rows, and the log and Legal rows the flows write for them), two
  PFM Settings rows (put back in part 4). With Test mode = Yes the F04 e-mail goes to the alert address only. Part 0 changes nothing on the site.
  Counts only: no names, offices or addresses are written. The site address stays in Config\90161Z-site.txt on this computer; every output
  line shows it as <SITE> and the DODID as <DODID>. Output: 90161Z-T24-full-test-part0-r1.txt to part4 in the T24 folder (send all five).
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt (part 0: the 8 lists by title only),
           and your own flows in Power Automate (part 1, one read through Get-PnPFlow), through PnP.PowerShell.
  Writes: the site rows listed under WHAT IT CHANGES ON THE SITE; on this computer the T24 folder (result files, the state file, the ready zip of
          part 0) and, once, Config\90161Z-site.txt when the site address is typed outside RADE.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File 90161Z-T24-full-solution-test-r6.ps1 -Part 0 (RADE does this).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part 0 to 4, -WaitMinutes (default 6: a flow you start with Run),
  -PollMinutes (default 17: F01 checks every 15 minutes, plus 2), -F05Minutes (default 3: every minute, plus 2), -NoPause; -TestDir: tests only.
#>
param([string]$Id, [ValidateSet(0, 1, 2, 3, 4)][int]$Part = 1, [int]$WaitMinutes = 6, [int]$PollMinutes = 17, [int]$F05Minutes = 3, [switch]$NoPause, [string]$TestDir)
$task = 'T24'
$Prefix = '90161Z TEST R28 '
$TitleX = $Prefix + 'X (delete me)'
$F05Late = 'The F05 wait ran out: check that F05 r5 is On (it checks every minute) and read its run history'
# R34 (F3 C): one fake publication per F01 change, so all changes wait for the same flow check; G and S test F05 (F1 A).
$TitleXT = $Prefix + 'X type (delete me)'
$TitleXS = $Prefix + 'X step (delete me)'
$TitleXA = $Prefix + 'X status (delete me)'
$TitleG7 = $Prefix + 'F05 G step 3 to 7 (delete me)'
$TitleS7 = $Prefix + 'F05 S made at 7 (delete me)'
$TitleF4A = $Prefix + 'F04 A (delete me)'
$TitleF4B = $Prefix + 'F04 B (delete me)'
# Seed values of the two PFM Settings rows this test writes (schemas/lists/PFMSettings.json). Part 4 puts the old values back (these when a row was missing).
$SeedSettings = [ordered]@{ FlowsPaused = 'No'; TestMode = 'Yes' }

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
  Masks e-mail addresses, the site, its host, path, name and tenant, other URLs, cloud and .mil hosts and GUIDs in a result text. Not masked: display names, office symbols, phone numbers, user ids, computer names.
  .PARAMETER Text
  The text to clean (a result line or an error message).
  .PARAMETER Site
  The site address (https://<host>/sites/<name>), or an empty text for the generic rules only.
  .OUTPUTS
  System.String. The text with each match replaced by a placeholder such as <EMAIL>, <SITE> or <GUID>.
  #>
  $Text = $Text -replace '[^\s"<>|,;()\[\]]+(@|%40)[^\s"<>|,;()\[\]]+', '<EMAIL>'   # whole address first: the host rules below would keep its name part
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
  $g = @('https?://\S+', '<URL>', '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>', '\b[\w.-]+\.mil\b', '<HOST>', '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>')   # the GUID has no \b: guid%27<id> must be masked too
  for ($i = 0; $i -lt $g.Count; $i += 2) { $Text = $Text -replace $g[$i], $g[$i + 1] }
  return $Text
}
# <<< site-common

function Add-Line([string]$Name, [string]$Status, [string]$Text) {
  # Adds one "ITEM <name> <status> <text>" result line.
  $script:lines.Add('ITEM ' + $Name + ' ' + $Status + $(if ($Text) { ' ' + $Text } else { '' }))
}
function Get-RowsFor([string]$List, [string]$Field, [int]$Key) {
  # Rows of a list whose lookup column points at an item (CAML by lookup ID).
  $q = "<View><Query><Where><Eq><FieldRef Name='" + $Field + "' LookupId='TRUE'/><Value Type='Lookup'>" + $Key + "</Value></Eq></Where></Query></View>"
  return @(Get-PnPListItem -List $List -Query $q -ErrorAction Stop)
}
function Get-OwnLogRow([int]$PubId) {
  # The Activity Log rows F01 wrote for a publication, oldest first (F06 and F05 write other titles).
  return @(Get-RowsFor 'PFM Activity Log' 'Publication' $PubId | Where-Object { ([string]$_['Title']).StartsWith('Action opened: ') -or ([string]$_['Title']).StartsWith('Action updated: ') } |
      Sort-Object Id)
}
function Get-LegalRow([int]$PubId) {
  # The Legal rows of a publication in PFM Endorsements (F05 writes them at step 7; DAFMAN 90-161 5.1.7, 5.1.8.2).
  return @(Get-RowsFor 'PFM Endorsements' 'Publication' $PubId | Where-Object { [string]$_['CoordinationStage'] -eq 'Legal' })
}
function Test-LegalOnce([int]$PubId, [string[]]$Office) {
  # Exactly 1 Legal row per office in $Office (titles of the active Coordinate Last offices; F05 titles a row "... - <office>")
  # and no other Legal row: returns 'once', else the counts for the result line.
  $rows = @(Get-LegalRow $PubId)
  $per = @($Office | ForEach-Object { $o = $_; @($rows | Where-Object { ([string]$_['Title']).EndsWith(' - ' + $o) }).Count })
  if ($Office.Count -gt 0 -and $rows.Count -eq $Office.Count -and @($per | Where-Object { $_ -ne 1 }).Count -eq 0) { return 'once' }
  return ('Legal rows=' + $rows.Count + ' expected=' + $Office.Count + ' (1 per office; per office: ' + ($per -join ',') + ')')
}
function Get-LocalDate($Value) {
  # The date part of the UTC value: the first 10 characters of the stored value, as the flows read a date-only column (README choice 7). It does not
  # depend on this computer's time zone (a Central date-only value is 05:00 or 06:00 UTC on the same day).
  if (-not $Value) { return $null }
  $d = [datetime]$Value
  if ($d.Kind -eq [System.DateTimeKind]::Local) { $d = $d.ToUniversalTime() }
  return $d.Date
}
# >>> wait-common: generated from scripts/gov/src/wait-common.ps1 by scripts/build_task_scripts.py (do not edit)
function Wait-Until([scriptblock]$Done, [string]$What) {
  <#
  .SYNOPSIS
  Checks every 30 seconds for up to $WaitMinutes (the calling script's -WaitMinutes). A failed check (for example a
  network drop: R20 part 1 of T18 lost the site name) is retried; 3 failures in a row stop the test (R20 finding 3).
  .PARAMETER Done
  The check: a script block that returns $true when the wait is over.
  .PARAMETER What
  What is waited for, for the progress line.
  .OUTPUTS
  System.Boolean. $true when the check passed in time, $false when the time ran out.
  #>
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
# <<< wait-common
function Wait-ForCheck([scriptblock]$Done, [string]$What, [int]$Minutes = $PollMinutes) {
  # Wait-Until with $Minutes instead of -WaitMinutes (Wait-Until reads $WaitMinutes from its caller): F01 checks PFM Publications
  # every 15 minutes (F3 C; -PollMinutes, the default), F05 r5 every minute (PFM 19 Nov 26; -F05Minutes), plus the run itself.
  $keep = $script:WaitMinutes
  $script:WaitMinutes = $Minutes
  try { return (Wait-Until $Done $What) } finally { $script:WaitMinutes = $keep }
}
function Get-SettingValue([string]$Key) {
  # The value of a PFM Settings row, or $null when the row is missing.
  $rows = @(Get-PnPListItem -List 'PFM Settings' -Fields 'Title', 'SettingValue' -ErrorAction Stop | Where-Object { ([string]$_['Title']).Trim() -eq $Key })
  if (-not $rows.Count) { return $null }
  return ([string]$rows[0]['SettingValue']).Trim()
}
function Save-SettingRow([string]$Key, [string]$Value) {
  # Upsert by Title in PFM Settings. Returns 'created' or 'updated'. Never writes the key or the value to the output.
  $rows = @(Get-PnPListItem -List 'PFM Settings' -Fields 'Title', 'SettingValue' -ErrorAction Stop | Where-Object { ([string]$_['Title']).Trim() -eq $Key })
  if (-not $rows.Count) { $null = Add-PnPListItem -List 'PFM Settings' -Values @{ Title = $Key; SettingValue = $Value } -ErrorAction Stop; return 'created' }
  foreach ($r in $rows) { $null = Set-PnPListItem -List 'PFM Settings' -Identity $r.Id -Values @{ SettingValue = $Value } -ErrorAction Stop }
  return 'updated'
}
function Restore-TestSetting($State) {
  # Puts each row back to the value it had before part 1 (the seed value when the row was missing).
  $n = 0
  foreach ($k in $SeedSettings.Keys) {
    $old = $State['orig' + $k]
    $null = Save-SettingRow $k $(if ($null -ne $old -and $old -ne '<missing>') { $old } else { $SeedSettings[$k] })
    $n++
  }
  return $n
}
function Read-State([string]$Path) {
  # The state file as a hashtable (key=value lines); empty when the file is missing.
  $h = @{}
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    foreach ($l in (Get-Content -LiteralPath $Path)) { $i = ([string]$l).IndexOf('='); if ($i -gt 0) { $h[([string]$l).Substring(0, $i)] = ([string]$l).Substring($i + 1) } }
  }
  return $h
}
function Save-State([string]$Path, $State) {
  # Writes the state hashtable to the state file as sorted key=value lines.
  Set-Content -LiteralPath $Path -Value @($State.Keys | Sort-Object | ForEach-Object { $_ + '=' + $State[$_] }) -Encoding UTF8
}
function Clear-TestPublication([int]$PubId) {
  # Moves the log and endorsement rows of one fake publication, then the publication, to the site Recycle Bin; returns the count.
  $n = 0
  foreach ($l in 'PFM Activity Log', 'PFM Endorsements') {
    foreach ($r in (Get-RowsFor $l 'Publication' $PubId)) { $null = Remove-PnPListItem -List $l -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ }
  }
  $null = Remove-PnPListItem -List 'PFM Publications' -Identity $PubId -Recycle -Force -ErrorAction Stop
  return $n + 1
}
function Clear-TestProduct([int]$ProductId) {
  # Moves the review rows of one fake product, then the product, to the site Recycle Bin; returns the count.
  $n = 0
  foreach ($r in (Get-RowsFor 'PFM Reviews' 'Product' $ProductId)) { $null = Remove-PnPListItem -List 'PFM Reviews' -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ }
  $null = Remove-PnPListItem -List 'PFM Product Index' -Identity $ProductId -Recycle -Force -ErrorAction Stop
  return $n + 1
}
function Get-ReportLogRow([int]$AfterId) {
  # Status-report log rows F04 wrote after the id noted in part 1 (the row has no publication).
  return @(Get-PnPListItem -List 'PFM Activity Log' -Fields 'Title', 'EventType', 'EventDetails' -ErrorAction Stop | Where-Object { [string]$_['EventType'] -eq 'Status Report E-Mailed' -and
      $_.Id -gt $AfterId } | Sort-Object Id)
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

$secret = @()
$stateFile = ''
$settingsChanged = $false
$state = @{}
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 24' -Create }
  Set-Location -LiteralPath $dir
  $root = Split-Path -Parent $dir
  $configDir = Join-Path $root 'Config'
  $site = Get-SiteAddress $configDir
  $stateFile = Join-Path $dir '90161Z-T24-test-state-r1.txt'   # item IDs and the old Settings values, for parts 2 and 3
  $lines.Add('TASK T24 full solution test r1, part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ', wait-minutes=' + $WaitMinutes)
  Write-Host 'NOW Looking for the PnP.PowerShell module.'
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'NOW Signing in to the site. A sign-in window may open.'
  Write-Host 'Connecting to the site. If a sign-in window opens, sign in with your CAC.'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')

  if ($Part -eq 0) { . (Join-Path $PSScriptRoot '90161Z-T24-zip-r6.ps1'); Invoke-ListGuidPart } elseif ($Part -eq 1) {   # 0: the module zip (R36)
    # 0. The Settings rows the flows read. Test mode Yes: the F04 e-mail goes to the alert address only. The old values are kept for part 4
    # (an earlier unfinished run keeps its first values).
    Write-Host 'NOW Reading the two Settings rows the test changes.'
    $state = Read-State $stateFile
    foreach ($k in $SeedSettings.Keys) {
      if (-not $state.ContainsKey('orig' + $k)) { $old = Get-SettingValue $k; $state['orig' + $k] = $(if ($null -eq $old) { '<missing>' } else { $old }) }
    }
    Save-State $stateFile $state
    $settingsChanged = $true
    if ($state.ContainsKey('settingsRestored')) { $state.Remove('settingsRestored'); Save-State $stateFile $state }   # an earlier stopped run put them back; they change again now
    Write-Host 'NOW Setting Flows paused to No and Test mode to Yes.'
    $made = 0; $upd = 0
    foreach ($k in $SeedSettings.Keys) { if ((Save-SettingRow $k $SeedSettings[$k]) -eq 'created') { $made++ } else { $upd++ } }
    Add-Line 'a0-settings' 'SET' ('PFM Settings rows made=' + $made + ' updated=' + $upd + '; Flows paused No; Test mode Yes')

    # a. All 7 flows On after the import: your own flows only, filtered by the 90161Z F0 names. One try; a hand check line when it cannot be read.
    Write-Host 'NOW Counting which of the 7 flows are On.'
    try {
      $envs = @(Get-PnPPowerPlatformEnvironment -ErrorAction Stop | Where-Object { $_.IsDefault })
      if ($envs.Count -ne 1) { throw [System.InvalidOperationException]::new('default environment not identified') }
      $mine = @(Get-PnPFlow -Environment $envs[0] -ErrorAction Stop | Where-Object { ([string]$_.Properties.DisplayName) -like '90161Z F0*' })
      $on = @($mine | Where-Object { ([string]$_.Properties.State) -eq 'Started' }).Count
      Add-Line 'a-flows-on' $(if ($mine.Count -eq 7 -and $on -eq 7) { 'PASS' } else { 'FAIL' }) ('flows named 90161Z F01 to F07 found=' + $mine.Count + ' expected=7; On=' + $on + ' expected=7')
    } catch {   # R34: PSInvalidOperationException from PnP (cause not proven): r5 adds its message, masked like every line, as evidence
      $why = ([string]$_.Exception.Message) -replace '\s+', ' '
      Add-Line 'a-flows-on' 'INFO' ('your flows could not be read from here (' + $_.Exception.GetType().Name + ': ' + $why.Substring(0, [Math]::Min(160, $why.Length)) +
          '). Check by hand: in the solution, all 7 flows F01 to F07 read On')
    }

    # Leftovers of an earlier run (by title), then the steps the fake rows use.
    Write-Host 'NOW Looking for fake rows left by an earlier run.'
    $oldPubs = @(Get-PnPListItem -List 'PFM Publications' -Fields 'Title' -ErrorAction Stop | Where-Object { ([string]$_['Title']).StartsWith($Prefix) -and
        ([string]$_['Title']).EndsWith('(delete me)') })
    $oldProds = @(Get-PnPListItem -List 'PFM Product Index' -Fields 'Title' -ErrorAction Stop | Where-Object { ([string]$_['Title']).StartsWith($Prefix) -and
        ([string]$_['Title']).EndsWith('(delete me)') })
    $moved = 0
    foreach ($o in $oldPubs) { $moved += Clear-TestPublication $o.Id }
    foreach ($o in $oldProds) { $moved += Clear-TestProduct $o.Id }
    if ($oldPubs.Count -or $oldProds.Count) { Add-Line 'b-leftovers' 'SET' ('moved ' + $oldPubs.Count + ' earlier test publication(s) and ' + $oldProds.Count +
        ' product row(s) and their rows to the Recycle Bin, rows=' + $moved) }
    Write-Host 'NOW Reading the process steps and the Legal offices.'
    $all = @(Get-PnPListItem -List 'PFM Process Steps' -Fields 'Title', 'StepNumber' -ErrorAction Stop)
    $steps = @($all | Where-Object { [int]$_['StepNumber'] -ne 6 -and [int]$_['StepNumber'] -ne 7 } | Sort-Object { [int]$_['StepNumber'] })
    if ($steps.Count -lt 3) { throw 'PROCESS STEPS: fewer than 3 steps besides 6 and 7 in PFM Process Steps.' }
    $titles = @($steps | ForEach-Object { [string]$_['Title'] })
    $step7 = @($all | Where-Object { [int]$_['StepNumber'] -eq 7 })
    $step3 = @($steps | Where-Object { [int]$_['StepNumber'] -eq 3 }) + @($steps[0])   # a wing GM runs stages 1-3, then 7 (DAFMAN 5.1.7)
    if (-not $step7.Count) { throw 'PROCESS STEPS: no step 7 (Legal coordination) in PFM Process Steps.' }
    $legal = @(Get-PnPListItem -List 'PFM Offices' -Fields 'Title', 'CoordinateLast', 'IsActive' -ErrorAction Stop |
        Where-Object { [bool]$_['CoordinateLast'] -and [bool]$_['IsActive'] } | ForEach-Object { [string]$_['Title'] })

    # 1. F01 (every 15 minutes, F3 C) and F05 (r5: every minute): all fake publications are made together, so F01 needs one check.
    Write-Host 'NOW Making 6 fake publications: 4 for F01 and 2 for F05.'
    $make = [ordered]@{ x = @($TitleX, $steps[0].Id); xt = @($TitleXT, $steps[0].Id); xs = @($TitleXS, $steps[0].Id); xa = @($TitleXA, $steps[0].Id)
      g7 = @($TitleG7, $step3[0].Id); s7 = @($TitleS7, $step7[0].Id) }
    $pub = @{}
    foreach ($k in $make.Keys) {
      $pub[$k] = (Add-PnPListItem -List 'PFM Publications' -Values @{ Title = $make[$k][0]; ActionType = 'New'; ProductType = 'Publication'
          ProcessStep = $make[$k][1]; ActionStatus = 'On Track' } -ErrorAction Stop).Id
      $state[$k] = [string]$pub[$k]
    }
    Save-State $stateFile $state
    Add-Line 'c-f01-created' 'SET' ('fake publications made=6 (Action Type New, On Track; 4 at step 1 of the list, G at step 3, S at step 7); Legal offices=' + $legal.Count)
    Write-Host ('NOW Waiting up to ' + $F05Minutes + ' minutes for F05 (it checks every minute) to add the Legal rows of S.')
    $okS = Wait-ForCheck { (Get-LegalRow $pub['s7']).Count -ge $legal.Count } 'the F05 Legal rows of S' $F05Minutes
    $s7 = Test-LegalOnce $pub['s7'] $legal
    Add-Line 'f05-legal-made-at-7' $(if ($s7 -eq 'once' -and $okS) { 'PASS' } else { 'FAIL' }) ('S (made at step 7), within ' + $F05Minutes + ' minutes: ' + $s7 +
        $(if ($legal.Count) { '' } else { '; no active office with Coordinate Last = Yes in PFM Offices' }) + $(if ($okS) { '' } else { '. ' + $F05Late }))
    Write-Host ('NOW Waiting up to ' + $PollMinutes + ' minutes for the next F01 check (every 15 minutes): F01 logs the 6 new rows.')
    $ok = Wait-ForCheck { @($pub.Keys | Where-Object { (Get-OwnLogRow $pub[$_]).Count -lt 1 }).Count -eq 0 } 'the F01 log rows'
    $rows = @(Get-OwnLogRow $pub['x'])
    $d0 = $(if ($rows.Count) { [string]$rows[0]['EventDetails'] } else { '' })
    $one = @($pub.Keys | Where-Object { (Get-OwnLogRow $pub[$_]).Count -eq 1 }).Count
    $good = $one -eq 6 -and $d0.StartsWith('Opened.') -and $d0.Contains('State: New | ' + $titles[0] + ' | On Track') -and ([string]$rows[0]['Title']).StartsWith('Action opened: ')
    Add-Line 'f01-open' $(if ($good) { 'PASS' } else { 'FAIL' }) ('publications with 1 log row after they were opened=' + $one + ' expected=6 (title Action opened, details Opened. and the state)' +
        $(if ($ok) { '' } else { '. The wait ran out: check that F01 is On and read its run history' }))
    $n3 = (Get-LegalRow $pub['g7']).Count
    Add-Line 'f05-none-before-7' $(if ($n3 -eq 0) { 'PASS' } else { 'FAIL' }) ('G (at step 3): Legal rows=' + $n3 + ' expected=0')

    # The changes, together (the notes first, so the check that sees the others has seen them too).
    Write-Host 'NOW Editing a note on X and S, changing X type, X step and X status, and moving G by hand to step 7.'
    foreach ($k in 'x', 's7') { $null = Set-PnPListItem -List 'PFM Publications' -Identity $pub[$k] -Values @{ StatusNotes = 'R34 test: a note edit' } -ErrorAction Stop }
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $pub['xt'] -Values @{ ActionType = 'Rewrite' } -ErrorAction Stop
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $pub['xs'] -Values @{ ProcessStep = $steps[1].Id } -ErrorAction Stop
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $pub['xa'] -Values @{ ActionStatus = 'Stalled' } -ErrorAction Stop
    $null = Set-PnPListItem -List 'PFM Publications' -Identity $pub['g7'] -Values @{ ProcessStep = $step7[0].Id } -ErrorAction Stop
    Write-Host ('NOW Waiting up to ' + $F05Minutes + ' minutes for F05 (it checks every minute) to add the Legal rows of G.')
    $okG = Wait-ForCheck { (Get-LegalRow $pub['g7']).Count -ge $legal.Count } 'the F05 Legal rows of G' $F05Minutes
    Write-Host ('NOW Waiting up to ' + $PollMinutes + ' minutes for the next F01 check (every 15 minutes): F01 logs 3 changes.')
    $ok = Wait-ForCheck { @('xt', 'xs', 'xa' | Where-Object { (Get-OwnLogRow $pub[$_]).Count -lt 2 }).Count -eq 0 } 'the F01 log rows'
    Write-Host 'NOW Waiting 2 minutes to see that F01 and F05 add no more rows.'
    Start-Sleep -Seconds 120
    # Key: item name, the changed column, the state F01 logs.
    $check = [ordered]@{ xt = @('f01-type', 'Action Type', ('State: Rewrite | ' + $titles[0] + ' | On Track'))
      xs = @('f01-step', 'Process Step', ('State: New | ' + $titles[1] + ' | On Track')); xa = @('f01-status', 'Action Status', ('State: New | ' + $titles[0] + ' | Stalled')) }
    foreach ($k in $check.Keys) {
      $rows = @(Get-OwnLogRow $pub[$k])
      $d1 = $(if ($rows.Count -ge 2) { [string]$rows[1]['EventDetails'] } else { '' })
      $good = $rows.Count -eq 2 -and $d1.StartsWith('Changed.') -and $d1.Contains($check[$k][2]) -and ([string]$rows[1]['Title']).StartsWith('Action updated: ')
      Add-Line $check[$k][0] $(if ($good) { 'PASS' } else { 'FAIL' }) ('log rows after the ' + $check[$k][1] + ' change=' + $rows.Count + ' expected=2')
    }
    $expect = [ordered]@{ x = 1; xt = 2; xs = 2; xa = 2; g7 = 2; s7 = 1 }   # G: its step change logs; X and S: a note edit logs nothing
    $got = @($expect.Keys | ForEach-Object { $_ + '=' + (Get-OwnLogRow $pub[$_]).Count }) -join ' '
    $wantText = @($expect.Keys | ForEach-Object { $_ + '=' + $expect[$_] }) -join ' '
    Add-Line 'f01-no-extra' $(if ($got -eq $wantText) { 'PASS' } else { 'FAIL' }) ('F01 log rows ' + $got + ' expected ' + $wantText + ' (the note edits on X and S none)' +
        $(if ($ok) { '' } else { '. The wait ran out: check that F01 is On and read its run history' }))
    $g7 = Test-LegalOnce $pub['g7'] $legal
    Add-Line 'f05-legal-moved-to-7' $(if ($g7 -eq 'once' -and $okG) { 'PASS' } else { 'FAIL' }) ('G (moved by hand from step 3 to step 7, as a wing GM), rows within ' +
        $F05Minutes + ' minutes=' + $okG + ': ' + $g7 + $(if ($okG) { '' } else { '. ' + $F05Late }))
    $s7 = Test-LegalOnce $pub['s7'] $legal
    Add-Line 'f05-no-duplicate' $(if ($s7 -eq 'once') { 'PASS' } else { 'FAIL' }) ('S after a second F05 run at step 7 (a note edit): ' + $s7)

    # 2. F02: 4 fake Product Index rows, 1 review row. Fixed day 15 of this month, so every date is exact (no month-end rounding).
    $today = (Get-Date).Date
    $m15 = (Get-Date -Year $today.Year -Month $today.Month -Day 15).Date
    $certA = $m15.AddYears(-4).AddMonths(3); $effA = $certA.AddYears(-1)       # later = certified; Next Review Due = 3 months ahead; window opened 3 months ago
    $effB = $m15.AddYears(-4).AddMonths(8); $certB = $effB.AddYears(-1)        # later = effective; Next Review Due = 8 months ahead; window opens in 2 months
    $nrdA = $certA.AddYears(4); $nrdB = $effB.AddYears(4)
    Write-Host 'NOW Making 4 fake product rows and 1 review row for F02.'
    $base = @{ ProductType = 'Publication'; ProductStatus = 'Active' }
    $p1 = Add-PnPListItem -List 'PFM Product Index' -Values ($base + @{ Title = $Prefix + 'P1 A (delete me)'
        PublicationNumber = 'R28-A'; EffectiveDate = $effA; CertifiedCurrentDate = $certA; NextReviewDue = $effA }) -ErrorAction Stop
    $p2 = Add-PnPListItem -List 'PFM Product Index' -Values ($base + @{ Title = $Prefix + 'P2 B (delete me)'
        PublicationNumber = 'R28-B'; EffectiveDate = $effB; CertifiedCurrentDate = $certB }) -ErrorAction Stop
    $p3 = Add-PnPListItem -List 'PFM Product Index' -Values ($base + @{ Title = $Prefix + 'P3 C (delete me)'
        PublicationNumber = 'R28-C'; EffectiveDate = $effA; CertifiedCurrentDate = $certA }) -ErrorAction Stop
    $p4 = Add-PnPListItem -List 'PFM Product Index' -Values @{ Title = $Prefix + 'P4 D (delete me)'
        PublicationNumber = 'R28-D'; ProductType = 'Publication'; ProductStatus = 'Inactive'; EffectiveDate = $effA; CertifiedCurrentDate = $certA } -ErrorAction Stop
    $pre = Add-PnPListItem -List 'PFM Reviews' -Values @{ Title = $Prefix + 'review (delete me)'
        Product = $p3.Id; ReviewType = 'Periodic'; ReviewOpened = $today; OPRResponseDue = $today.AddDays(30) } -ErrorAction Stop
    $state['p1'] = [string]$p1.Id; $state['p2'] = [string]$p2.Id; $state['p3'] = [string]$p3.Id; $state['p4'] = [string]$p4.Id; $state['premade'] = [string]$pre.Id
    $state['nrd1'] = $nrdA.ToString('yyyy-MM-dd'); $state['nrd2'] = $nrdB.ToString('yyyy-MM-dd')
    Add-Line 'd-f02-prepared' 'SET' ('product rows A,B,C,D made=4 (A: wrong Next Review Due; B: window not open; C: review already open, 1 review row made; D: Inactive)')

    # 3. F04: two fake publications at two process steps; the newest status-report log row is noted so part 2 finds only the new one.
    Write-Host 'NOW Making 2 fake publications for the F04 report.'
    $fa = Add-PnPListItem -List 'PFM Publications' -Values @{ Title = $TitleF4A; ActionType = 'New'; ProductType = 'Publication'; ProcessStep = $steps[0].Id
        ActionStatus = 'On Track' } -ErrorAction Stop
    $fb = Add-PnPListItem -List 'PFM Publications' -Values @{ Title = $TitleF4B; ActionType = 'Rewrite'; ProductType = 'Publication'; ProcessStep = $steps[1].Id
        ActionStatus = 'On Track' } -ErrorAction Stop
    $state['fa'] = [string]$fa.Id; $state['fb'] = [string]$fb.Id
    $prior = @(Get-ReportLogRow 0)
    $state['reportBase'] = $(if ($prior.Count) { [string]$prior[-1].Id } else { '0' })
    Save-State $stateFile $state
    Add-Line 'e-f04-prepared' 'SET' ('fake publications at 2 process steps made=2; status-report log rows before the run=' + $prior.Count)
  } else {
    $hasState = Test-Path -LiteralPath $stateFile -PathType Leaf
    if (-not $hasState -and $Part -ne 4) { throw 'NO TEST STATE: run part 1 first.' }
    if (-not $hasState) { Add-Line 'g-clean-up' 'SET' 'no test state file: part 1 did not run or part 4 ran before; nothing to clean' }
    $state = $(if ($hasState) { Read-State $stateFile } else { @{} })
    $settingsChanged = -not $state.ContainsKey('settingsRestored')   # part 1 changed the Settings rows; part 4, or a stop in any part, puts them back once
    if ($Part -eq 4 -and -not $hasState) { $null = $state } elseif ($Part -eq 2) {
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
    } elseif ($Part -eq 3) {
      # Part 3: F02 after the second run (checks only; part 4 cleans up).
      Write-Host 'NOW Checking that F02 made no second review row.'
      if ($state.ContainsKey('p1') -and $state.ContainsKey('nrd1')) { Test-F02Row $state $true } else { Add-Line 'f02-not-twice-run2' 'SKIP' 'part 1 stopped before the F02 rows were made' }
    } else {
      # Part 4: clean-up and settings back. The fake rows always go to the Recycle Bin here, also after a failed check (the check
      # lines above keep the evidence). A row already gone is not an error.
      Write-Host 'NOW Moving the fake rows to the site Recycle Bin.'
      $n = 0; $gone = 0
      foreach ($k in 'x', 'xt', 'xs', 'xa', 'g7', 's7', 'fa', 'fb') { if ($state.ContainsKey($k)) { try { $n += Clear-TestPublication ([int]$state[$k]) } catch { $gone++ } } }
      foreach ($k in 'p1', 'p2', 'p3', 'p4') { if ($state.ContainsKey($k)) { try { $n += Clear-TestProduct ([int]$state[$k]) } catch { $gone++ } } }
      if ($state.ContainsKey('reportBase')) {
        foreach ($r in (Get-ReportLogRow ([int]$state['reportBase']))) { $null = Remove-PnPListItem -List 'PFM Activity Log' -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ }
      }
      Add-Line 'g-clean-up' 'SET' ('rows moved to the site Recycle Bin=' + $n + '; fake items already gone or not removable=' + $gone)
      Write-Host 'NOW Putting the two Settings rows back.'
      if ($state.ContainsKey('settingsRestored')) { $nRestored = 0; Add-Line 'h-settings-restored' 'SET' 'PFM Settings rows were put back earlier (a part stopped)' }
      else { $nRestored = Restore-TestSetting $state; Add-Line 'h-settings-restored' 'SET' ('PFM Settings rows put back to their old values=' + $nRestored) }
      $settingsChanged = $false
      Remove-Item -LiteralPath $stateFile -Force
    }
  }
  Write-Host 'NOW Signing out of the site.'
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  $nf = @($lines | Where-Object { $_ -cmatch '^ITEM \S+ FAIL\b' }).Count
  $lines.Add('FULL SOLUTION part ' + $Part + ' done, items with problems=' + $nf)
} catch {
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)))
  # Any part: put the Settings rows back from the old values in the state file (once; part 4 sees the flag and does not restore again).
  if ($settingsChanged -and $state.ContainsKey('origFlowsPaused') -and $state.ContainsKey('origTestMode')) {
    try {
      $nRestored = Restore-TestSetting $state
      $state['settingsRestored'] = '1'
      if ($stateFile) { Save-State $stateFile $state }
      $lines.Add('Settings rows put back to their old values=' + $nRestored)
    } catch { $lines.Add('Settings rows NOT put back: set Test mode and Flows paused back by hand') }
  }
  if ($Part -ge 1 -and $Part -lt 4 -and $stateFile -and (Test-Path -LiteralPath $stateFile)) { $lines.Add('Run part 4 to move the fake rows to the site Recycle Bin and put the Settings back') }
} finally {
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T24-full-test-part' + $Part + '-r1.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
