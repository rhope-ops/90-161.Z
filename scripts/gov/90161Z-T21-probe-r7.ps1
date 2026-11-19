<#
.SYNOPSIS
  90-161.Z Task 21 probe, r7 (round R34). Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: the device side of the T21 probe. R26 settled most of the front-end tests (T2, T3, T5, T6, T7, T9, T10
  passed); R29a proved T4 (a second person writes a row). The 2 probe flows are now flows of the solution "90-161.Z flows"
  (fallback A, the PFM 18 Nov 26: a new solution and a hand-made flow failed in R29a to R32 with "The connections could
  not be loaded"; an upgrade of that solution works): "90161Z T21 Probe Health r6" answers a command row with a result row,
  and "90161Z T21 Probe Button r6" is started by a list view button. Excel is not repeated (R27: no Automate tab).
  This script makes the list and library the tests need, adds the second person to the site's Visitors group (and removes
  the person again), formats the list form and a view, starts the health flow, reads what the people and the flows wrote,
  and removes everything it made. Fake data only (the fake workbook comes from scripts/build_probe_samples.py). Counts,
  status codes and field names only: no names, addresses or text from the tenant.
  WHAT R7 CHANGES: (1) the health flow writes its row without the Power Automate Management connector, so HEALTH now tests
  that the flow ran on the SharePoint connection of the solution (it no longer counts flows). (2) View takes the button
  flow's ID from the button-flow-id block of the look module, which scripts/build_flow_solution.py writes at build time
  (the ID is the same on every build); the Export part, its module and the flow ID file are gone. (3) BUTTON counts the
  rows titled BTN-FLOW that the button flow writes. (4) Before each action that takes time a part prints one line
  "NOW <what it does>" for the RADE window; a NOW line is not a result line and is not in the result file.
  WHAT R6 CHANGED: (1) the Clean part no longer prints the Recycle Bin item IDs of the list and the library (R29a finding 7:
  a raw RecycleBinItemId table reached the log). (2) The parts Form and View run the two halves of Look on their own, so the
  round can show the list form when the form header passed, whatever the view result (R29a finding 6); Look still runs both.
  (3) The script is split into modules (code standard, S1): this file holds the start, the shared blocks and the result
  file; the parts live in the files 90161Z-T21-<part>-r7.ps1 in the same folder, which this file loads by name.
  (4) Read: with no state file and no row by another person, T4 is not counted: one line "T4 NOT RUN" and no RESULT line.
  Parts (-Part):
    Make   (about 1 minute, an estimate)  Makes the library "90161Z Probe Files" and the list "90161Z Probe" (columns
           ProbeTest, ProbeWay, ProbeResult, ProbeDetail; its own permissions: the site's copied, then Contribute for the
           site's Visitors group on this list only), saves the fake workbook from a text block in the make module, uploads
           it and writes the test page 90161Z-T21-links-r5.html (4 links). Run it twice and the second run changes nothing.
    Person (about 1 minute, an estimate)  Opens a small window and asks for the e-mail address of the second person (test
           T4). The address stays in memory: it is never written to a file, to the screen or to the results. With your own
           sign-in it adds that person to the site's Visitors group and saves only the number of the site user (no address,
           no name) in the state file 90161Z-T21-person-state-r3.txt in the T21 folder, so that Clean can find the person.
           It also puts the link of the new row form on the clipboard. Prints "added to Visitors: yes" or "no" and a status.
    Run    (a few seconds, an estimate)  Adds 1 command row (RUN-HEALTH) that starts the health flow "90161Z T21 Probe
           Health r6"; it answers within minutes.
    Look   (about 1 minute, an estimate)  Runs Form, then View.
    Form   (about 1 minute, an estimate)  Sets a header on the list form (the content type's form formatting) and reads it back.
    View   (about 1 minute, an estimate)  Makes the view "ProbeButton" with a button that starts the button flow "90161Z
           T21 Probe Button r6" (a view formatting with the action executeFlow; the flow's ID is in the look module).
    Open   (a few seconds; no sign-in)  Writes the test page again and opens it in the browser.
    Read   (about 1 to 5 minutes, an estimate)  Waits up to -WaitMinutes (default 4) for the health flow's row, then prints
           one line each for HEALTH, T4 and BUTTON (counts only; the button flow's rows are the ones titled BTN-FLOW).
    Clean  (about 1 minute, an estimate)  Removes the second person from the Visitors group again (found by the saved
           number; then deletes the state file), then moves the list and the library to the site Recycle Bin (restorable
           for 93 days). Each step runs even if an earlier one failed, and the part can be run again. The 2 probe flows
           stay in the solution "90-161.Z flows" (the part says so). The round runs it twice: first (-Label first), last
           (-Label last).
  WHAT IT CHANGES ON THE SITE: Make adds the two objects, their columns, their permissions and two files. Person adds one
  person to the Visitors group. Run adds 1 row. Form sets one form formatting; View adds one view. Read and Open change
  nothing on the site. Clean undoes Person and recycles the two objects. On this computer: the T21 folder (the test
  page, the state file). Every output line shows the site as <SITE> and the DODID as <DODID>; the test page holds the
  site address and stays on this computer (it is not a result file).
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell; Open
           uses no network (it hands the test page to the browser).
  Writes: the site objects listed above; on this computer the T21 folder (result files, test page, state file, the fake
          workbook) and, once, Config\90161Z-site.txt when the site address is typed outside RADE.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Output: 90161Z-T21-probe-<part>-r7.txt (make, person, run, look, form, view, read) or -clean-<label>-r7.txt in
  the T21 folder (send them back). Each test line (HEALTH, T4, BUTTON, FORM, VIEW) is followed by "RESULT <test> PASS" or
  "RESULT <test> FAIL", so the RADE step counts what the part read (R28 finding 7). Last line of each part: PROBE <part>
  done: passed=<n> failed=<n>. Exit code 0 when the part ran to its end (a FAILED test is a result); exit 1 only when the
  part could not run (sign-in, missing list, missing module file).
  Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File 90161Z-T21-probe-r7.ps1 -Part <part> (RADE does this).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part, -Label, -WaitMinutes, -NoPause.
  -PollSeconds, -TestDir and -NoLaunch are for the tests in tests/run.sh (tests/ps/Test-T21.ps1).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Part
  The part to run: Make, Person, Run, Look, Form, View, Open, Read or Clean.
.PARAMETER Label
  For Clean: first or last (it goes into the result file name).
.PARAMETER WaitMinutes
  How long Read waits for the health flow's row (default 4 for Read).
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER PollSeconds
  Seconds between two checks while Read waits (tests use 1).
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T21 folder.
.PARAMETER NoLaunch
  Test runs only: do not open the browser or use the clipboard.
#>
param([string]$Id, [ValidateSet('Make', 'Person', 'Run', 'Look', 'Form', 'View', 'Open', 'Read', 'Clean')][string]$Part,
  [ValidateSet('', 'first', 'last')][string]$Label = '', [double]$WaitMinutes = 14, [switch]$NoPause, [int]$PollSeconds = 20,
  [string]$TestDir, [switch]$NoLaunch)
$task = 'T21'
$script:pollEvery = $PollSeconds
$script:LibTitle = '90161Z Probe Files'
$script:LibFolder = '90161ZProbeFiles'
$script:ListTitle = '90161Z Probe'
$script:ListFolder = '90161ZProbe'
$script:BookName = '90161Z-T21-fake-book-r1.xlsx'
# The test page keeps its r5 name: the round's sample page (samples/90161Z-T21-links-r5.html) has that name, and no check
# ties it to the script revision.
$script:LinksName = '90161Z-T21-links-r5.html'
# The state file keeps its r3 name: Clean finds a person that an earlier round added through it.
$script:StateName = '90161Z-T21-person-state-r3.txt'
$script:ViewTitle = 'ProbeButton'
$script:HeaderText = '90-161.Z test header'
$Rev = 'r7'
# The modules this file loads from its own folder (round skill section 2: scripts that load each other keep fixed names).
$ModuleNames = @('common', 'make', 'person', 'look', 'read')

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

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
$passed = 0; $failed = 0
$fatal = $false
$script:fmtError = ''
try {
  $ErrorActionPreference = 'Stop'
  if (-not $Part) { throw 'PART not given: use -Part Make, Person, Run, Look, Form, View, Open, Read or Clean.' }
  # The modules are dot-sourced here, in this script's scope, so their functions see the values above.
  foreach ($moduleName in $ModuleNames) {
    $moduleFile = Join-Path $PSScriptRoot ('90161Z-T21-' + $moduleName + '-' + $Rev + '.ps1')
    if (-not (Test-Path -LiteralPath $moduleFile -PathType Leaf)) {
      throw ('MODULE missing: 90161Z-T21-' + $moduleName + '-' + $Rev + '.ps1 is not in the folder of this script. Run the round again.')
    }
    . $moduleFile
  }
  if ($Part -eq 'Read' -and -not $PSBoundParameters.ContainsKey('WaitMinutes')) { $WaitMinutes = 4 }
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 21' -Create }
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $lines.Add('TASK T21 probe ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + $(if ($Part -eq 'Read') { ', wait-minutes=' + $WaitMinutes } else { '' }))

  # Open works on this computer only; every other part signs in first.
  if ($Part -eq 'Open') { Invoke-OpenPart }
  else {
    Connect-ProbeSite
    switch ($Part) {
      'Make' { Invoke-MakePart }
      'Person' { Invoke-PersonPart }
      'Run' { Invoke-RunPart }
      'Look' { Invoke-FormPart; Invoke-ViewPart }
      'Form' { Invoke-FormPart }
      'View' { Invoke-ViewPart }
      'Read' { Invoke-ReadPart }
      default { Invoke-CleanPart }
    }
    try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  }
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} catch {
  $fatal = $true
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(400, $m.Length)) + ' (a part that stopped can be run again: Make skips what is there, Clean finishes what is left)')
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} finally {
  # Every line is masked once more before it is shown or saved; Open writes no result file.
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  $resultName = '90161Z-T21-probe-' + ([string]$Part).ToLowerInvariant() + $(if ($Label) { '-' + $Label } else { '' }) + '-' + $Rev + '.txt'
  if ($dir -and $Part -and $Part -ne 'Open') { try { Set-Content -LiteralPath (Join-Path $dir $resultName) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
