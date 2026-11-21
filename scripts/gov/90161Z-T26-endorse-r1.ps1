<#
.SYNOPSIS
  90-161.Z Task 26 r1 (round R41): an endorser answers through the SharePoint list form of PFM Endorsements, and the
  answer is read back. Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for (PFM 20 Nov 26, docs/reviews/2026-11-21-r41-plan.md row 2; the test site write of the round, approved
  by the PFM): a second person, a member of the site's Visitors group (T21 Person adds the person, T21 Clean takes the
  person out again), answers one fake endorsement in the list form of PFM Endorsements, the way R38 T4 proved a list
  form write on the probe list. PFM Endorsements is set to "read all, edit own rows" (PFM 10A; T20 step 5), so the
  answer is a new row of that person: its Title, the fake publication, and the answer in Endorsement Status. The PFM
  window (T22 r14) shows the answer read-only on its endorsement card.
  Parts (-Part):
    Make   (about 1 minute, an estimate)  Signs in. Finds the fake publication "90161Z TEST R41 endorse (delete me)" on
           PFM Publications, or makes it (Action Type New, Publication, the process step with step number 1, On Track:
           no flow routes a row at step 1). Saves its row number in the state file 90161Z-T26-endorse-state-r1.txt.
           Puts on the clipboard the link of the new row form of PFM Endorsements and the 5 steps for the second person.
    Read   (about 1 minute)  Signs in and READS only. Finds the rows of PFM Endorsements on the fake publication that
           another person saved, and prints one RESULT line: the answer on the newest one and the row count.
    Clean  (about 1 minute)  Moves the rows of PFM Endorsements and PFM Activity Log on the fake publication, then the
           fake publication itself (only when Make made it), to the site Recycle Bin (restorable for 93 days), and
           deletes the state file. It can run again.
  Fake data only: every row this task makes or asks for has a title that starts with "90161Z TEST" (the repo's
  fake-data marker, which the window checks before it saves a picture). Counts, answer values (the choices of
  schemas/lists/PFMEndorsements.json) and status words only: no names, no addresses, no row text from the site.
  WHAT IT CHANGES ON THE SITE: Make adds 1 row to PFM Publications (once; a second run reuses it); the flow F01 may log
  it in PFM Activity Log. The second person adds 1 row to PFM Endorsements. Read changes nothing. Clean recycles them.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell.
  Writes: on the site, the rows above; on this computer the T26 folder (the result file, the state file), the clipboard
          (Make) and, once, Config\90161Z-site.txt when the site address is typed outside RADE.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Output: 90161Z-T26-endorse-<part>-r1.txt in the T26 folder. Last line: ENDORSE <part> done: passed=<n> failed=<n>.
  Exit 1 only when the part could not run (sign-in, missing list or module).
  Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File 90161Z-T26-endorse-r1.ps1 -Part <part> (RADE does this).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Part
  Make, Read or Clean.
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T26 folder.
.PARAMETER NoLaunch
  Test runs only: do not use the clipboard.
#>
param([string]$Id, [ValidateSet('Make', 'Read', 'Clean')][string]$Part, [switch]$NoPause, [string]$TestDir, [switch]$NoLaunch)
$task = 'T26'
$Rev = 'r1'
$PubTitle = '90161Z TEST R41 endorse (delete me)'   # the fake publication the answer is about
$AnswerTitle = '90161Z TEST R41 answer'             # the Title the second person types
$StateName = '90161Z-T26-endorse-state-r1.txt'
$script:noLaunch = [bool]$NoLaunch   # the tests: no clipboard
$EndorseFolder = 'PFMEndorsements'                  # the folder name of PFM Endorsements (T20 makes each list under its internal name)
# The answers a row can hold (schemas/lists/PFMEndorsements.json, Endorsement Status), in ASCII: the dash of
# "Concur-No Response" is written as a hyphen here and in the result line.
$Answers = @('Not Started', 'Concur', 'Concur With Comment', 'Concur-No Response', 'Nonconcur', 'No Comment', 'Not Applicable')

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
# Adds one "ITEM <name> <status> <text>" line and counts a PASS or a FAIL.
function Add-Item([string]$Name, [string]$Status, [string]$Text) {
  $lines.Add('ITEM ' + $Name + ' ' + $Status + ' ' + $Text)
  if ($Status -eq 'PASS') { $script:passed++ } elseif ($Status -eq 'FAIL') { $script:failed++ }
}
# The state file as a hashtable (key=value lines); empty when the file is missing.
function Read-State([string]$Path) {
  $h = @{}
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    foreach ($l in (Get-Content -LiteralPath $Path)) { $i = ([string]$l).IndexOf('='); if ($i -gt 0) { $h[([string]$l).Substring(0, $i)] = ([string]$l).Substring($i + 1) } } }
  return $h
}
# Writes the state hashtable to the state file as sorted key=value lines (row numbers and flags only).
function Save-State([string]$Path, $State) { Set-Content -LiteralPath $Path -Value @($State.Keys | Sort-Object | ForEach-Object { $_ + '=' + $State[$_] }) -Encoding ASCII }
# The answer value of a row in ASCII (an unknown value is "other", so no free text from the site reaches a line).
function Get-AnswerText($V) {
  $t = ([string]$V).Replace([string][char]0x2014, '-').Trim()
  if ($Answers -contains $t) { return $t }
  return 'other'
}
# The site user number of the author of a row, or 0 when the row has none.
function Get-AuthorId($Row) { $a = $Row['Author']; if ($a -and $a.LookupId) { return [int]$a.LookupId }; return 0 }
# The rows of list $List whose lookup column $Field points at row $Id (all rows read, then filtered here).
function Get-RowsFor([string]$List, [string]$Field, [int]$Id) {
  return @(Get-PnPListItem -List $List -PageSize 500 -ErrorAction Stop | Where-Object { $v = $_[$Field]; $v -and [int]$v.LookupId -eq $Id })
}
# The fake publication rows (exact title), oldest first.
function Find-FakePub { return @(Get-PnPListItem -List 'PFM Publications' -Fields 'Title' -PageSize 500 -ErrorAction Stop | Where-Object { ([string]$_['Title']) -eq $PubTitle } | Sort-Object { $_.Id }) }
# Loads PnP.PowerShell and signs in to the one site with the web login (CAC).
function Connect-EndorseSite {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'NOW Signing in to the site (if a sign-in window opens, sign in with your CAC)'
  $null = & { Connect-PnPOnline -Url $script:site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
}
<#
.SYNOPSIS
  The part Make: the fake publication (found or made once) and, on the clipboard, the new row form link and the steps
  for the second person.
#>
function Invoke-MakePart {
  $st = Read-State $script:stateFile
  Write-Host 'NOW Looking for the fake publication'
  $pub = @(Find-FakePub)
  if ($pub.Count) { $pubId = [int]$pub[0].Id; Add-Item 'm1-publication' 'PASS' 'the fake publication is there (made by an earlier run; it is used again)' }
  else {
    $step = @(Get-PnPListItem -List 'PFM Process Steps' -Fields 'Title', 'StepNumber' -ErrorAction Stop | Where-Object { [int]$_['StepNumber'] -eq 1 })
    if (-not $step.Count) { throw 'STEP not found: PFM Process Steps has no row with step number 1 (run T20 first).' }
    Write-Host 'NOW Making the fake publication'
    $pubId = [int](Add-PnPListItem -List 'PFM Publications' -Values @{ Title = $PubTitle; ActionType = 'New'; ProductType = 'Publication'
        ProcessStep = $step[0].Id; ActionStatus = 'On Track' } -ErrorAction Stop).Id
    $st['Made'] = 'yes'; Add-Item 'm1-publication' 'PASS' 'the fake publication was made (step 1, On Track)' }
  $st['PubId'] = [string]$pubId; if (-not $st['Made']) { $st['Made'] = 'no' }
  Save-State $script:stateFile $st
  $steps = @('Open the link above.', ('In Title, type: ' + $AnswerTitle), ('In Publication, pick: ' + $PubTitle),
    'In Endorsement Status, pick your answer, for example Concur.', 'Select Save, then tell me if it saved.')
  $clip = 'no'
  if ($script:noLaunch) { $clip = 'no (test run)' } else {
    try { Set-Clipboard -Value (@($script:site.TrimEnd('/') + '/Lists/' + $EndorseFolder + '/NewForm.aspx') + $steps); $clip = 'yes' } catch { $clip = 'no' } }
  $lines.Add('ITEM m2-link INFO the link of the new row form of PFM Endorsements and the 5 steps for the second person are on the clipboard=' + $clip)
}
<#
.SYNOPSIS
  The part Read (reads only): the rows of PFM Endorsements on the fake publication that another person saved; one
  RESULT line with the answer on the newest one and the row count.
#>
function Invoke-ReadPart {
  $st = Read-State $script:stateFile
  Write-Host 'NOW Looking for the fake publication'
  $pubId = $(if ($st['PubId'] -match '^\d+$') { [int]$st['PubId'] } else { $p = @(Find-FakePub); if ($p.Count) { [int]$p[0].Id } else { 0 } })
  if (-not $pubId) { Add-Item 'r1-publication' 'FAIL' 'no fake publication: run the part Make first'; $lines.Add('RESULT ENDORSE FAIL'); return }
  $meId = 0
  try { $meId = [int]((Invoke-PnPSPRestMethod -Method Get -Url ($script:site.TrimEnd('/') + '/_api/web/currentuser?$select=Id') -Raw -ErrorAction Stop) | ConvertFrom-Json).Id } catch { $meId = 0 }
  Write-Host 'NOW Reading the answers on PFM Endorsements'
  $rows = @(Get-RowsFor 'PFM Endorsements' 'Publication' $pubId)
  $other = @($rows | Where-Object { $meId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $meId } | Sort-Object { $_.Id } -Descending)
  $answered = @($other | Where-Object { (Get-AnswerText $_['EndorsementStatus']) -ne 'Not Started' })
  $marked = @($other | Where-Object { ([string]$_['Title']).StartsWith('90161Z TEST') }).Count
  $answer = $(if ($answered.Count) { Get-AnswerText $answered[0]['EndorsementStatus'] } else { 'none' })
  $pass = ($answered.Count -ge 1)
  $lines.Add('ENDORSE rows on the fake publication=' + $rows.Count + '; by another person=' + $other.Count + '; with an answer=' + $answered.Count +
    '; with the fake-data title=' + $marked + $(if ($meId -le 0) { ' (your own user number could not be read)' } else { '' }))
  $lines.Add('RESULT ENDORSE ' + $(if ($pass) { 'PASS' } else { 'FAIL' }) + ' answer=' + $answer + ' rows=' + $answered.Count)
  if ($pass) { $script:passed++ } else {
    $script:failed++
    $lines.Add('next: the second person opens the new row form link, types the title, picks the fake publication and an answer, and selects Save; a form that says no permission means the Visitors group does not hold Contribute on PFM Endorsements (run T20 r4)') }
}
<#
.SYNOPSIS
  The part Clean: recycles the endorsement and log rows of the fake publication, then the publication when Make made
  it, and deletes the state file. Each step runs even when one fails.
#>
function Invoke-CleanPart {
  $st = Read-State $script:stateFile
  $pubId = $(if ($st['PubId'] -match '^\d+$') { [int]$st['PubId'] } else { 0 })
  if (-not $pubId) { Add-Item 'c1-rows' 'PASS' 'no fake publication on file (nothing to remove)'; return }
  $n = 0; $bad = 0
  foreach ($l in 'PFM Endorsements', 'PFM Activity Log') {
    try { foreach ($r in (Get-RowsFor $l 'Publication' $pubId)) { $null = Remove-PnPListItem -List $l -Identity $r.Id -Recycle -Force -ErrorAction Stop; $n++ } }
    catch { $bad++; $lines.Add('NOTE rows of ' + $l + ' not all removed: ' + ([string]$_.Exception.Message).Substring(0, [Math]::Min(120, ([string]$_.Exception.Message).Length))) } }
  Add-Item 'c1-rows' $(if ($bad) { 'FAIL' } else { 'PASS' }) ('rows moved to the site Recycle Bin=' + $n + $(if ($bad) { ' (run Clean again)' } else { '' }))
  if ($st['Made'] -eq 'yes') {
    try { $null = Remove-PnPListItem -List 'PFM Publications' -Identity $pubId -Recycle -Force -ErrorAction Stop; Add-Item 'c2-publication' 'PASS' 'the fake publication moved to the site Recycle Bin' }
    catch { $bad++; Add-Item 'c2-publication' 'FAIL' 'the fake publication could not be removed (run Clean again)' } }
  else { Add-Item 'c2-publication' 'PASS' 'the fake publication was not made by this task, so it stays' }
  if (-not $bad) { Remove-Item -LiteralPath $script:stateFile -ErrorAction SilentlyContinue }
}

$fatal = $false; $site = ''; $secret = @(); $dir = ''
try {
  $ErrorActionPreference = 'Stop'
  if (-not $Part) { throw 'PART not given: use -Part Make, Read or Clean.' }
  $who = Get-TaskId $Id; $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 26' -Create }
  Set-Location -LiteralPath $dir
  $script:stateFile = Join-Path $dir $StateName
  $script:site = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config')
  $lines.Add('TASK T26 endorse ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  Connect-EndorseSite
  switch ($Part) { 'Make' { Invoke-MakePart } 'Read' { Invoke-ReadPart } default { Invoke-CleanPart } }
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
} catch {
  $fatal = $true
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)) + ' (the part can be run again)')
} finally {
  $lines.Add('ENDORSE ' + $Part + ' done: passed=' + $script:passed + ' failed=' + $script:failed)
  # Every line is masked once more before it is shown or saved.
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir -and $Part) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T26-endorse-' + $Part.ToLowerInvariant() + '-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
