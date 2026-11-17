<#
.SYNOPSIS
  90-161.Z Task 21 probe, r3 (round R27). Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: the device side of the R27 probe. R26 settled most of the front-end tests (T2, T3, T5, T6, T7, T9, T10 passed);
  R27 keeps only what is not yet verified: T4 again (a second person writes a row), the health flow, and 3 looks (a list form with a
  header, a view with a button that starts a flow, Excel in the browser). This script makes the list and library the tests need,
  adds the second person to the site's Visitors group (and removes the person again), formats the list form and a view, starts the
  health flow, reads what the people and the flows wrote, and removes everything it made. Fake data only (the two fake workbooks come
  from scripts/build_probe_samples.py). Counts, status codes and field names only: no names, addresses or text from the tenant.
  Parts (-Part):
    Make   (about 1 minute, an estimate)  Makes the library "90161Z Probe Files" and the list "90161Z Probe" (columns ProbeTest,
           ProbeWay, ProbeResult, ProbeDetail; its own permissions: the site's copied, then Contribute for the site's Visitors group
           on this list only), saves the 2 fake workbooks from text blocks in this script, uploads them and writes the test page 90161Z-T21-links-r3.html (5 links).
           Run it twice and the second run changes nothing on the site.
    Person (about 1 minute, an estimate)  Opens a small window and asks for the e-mail address of the second person (test T4). The
           address stays in memory: it is never written to a file, to the screen or to the results. With your own sign-in it adds that
           person to the site's Visitors group and saves only the number of the site user (no address, no name) in the state file
           90161Z-T21-person-state-r3.txt in the T21 folder, so that Clean can find the person. It also puts the link of the new row
           form on the clipboard. Prints "added to Visitors: yes" or "no" and a status, never who.
    Run    (a few seconds, an estimate)  Adds 1 command row (RUN-HEALTH) that starts the health flow; the flow answers within minutes.
    Look   (about 1 minute, an estimate)  Sets a header on the list form (the content type's form formatting, reads it back) and makes
           the view "ProbeButton" with a button that starts the button flow (a view formatting with the action executeFlow).
    Open   (a few seconds; no sign-in)  Writes the test page again and opens it in the browser.
    Read   (about 1 to 5 minutes, an estimate)  Waits up to -WaitMinutes (default 4) for the health flow's row, then prints one line
           each for HEALTH, T4 and BUTTON (counts only).
    Clean  (about 1 minute, an estimate)  Removes the second person from the Visitors group again (found by the saved number; then
           deletes the state file), then moves the list and the library to the site Recycle Bin (restorable for 93 days). Each
           step runs even if an earlier one failed, and the part can be run again. The solution is removed by hand (the part says so).
  WHAT IT CHANGES ON THE SITE: Make adds the two objects, their columns, their permissions and two files. Person adds one person to
  the Visitors group. Run adds 1 row. Look sets one form formatting and adds one view. Read and Open change nothing. Clean undoes
  Person and recycles the two objects. On this computer: the T21 folder (the test page, the state file). Every output line shows the
  site as <SITE> and the DODID as <DODID>; the test page holds the site address and stays on this computer (it is not a result file).
  Output: 90161Z-T21-probe-make-r3.txt, -person-r3.txt, -run-r3.txt, -look-r3.txt, -read-r3.txt or -clean-r3.txt in the T21 folder
  (send them back). Last line of each part: PROBE <part> done: passed=<n> failed=<n>. Exit code 0 when the part ran to its end (a
  FAILED test is a result); exit 1 only when the part could not run (sign-in, missing list).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part, -WaitMinutes, -NoPause. -PollSeconds,
  -TestDir and -NoLaunch are for the tests in tests/run.sh.
#>
param([string]$Id, [ValidateSet('Make', 'Person', 'Run', 'Look', 'Open', 'Read', 'Clean')][string]$Part, [double]$WaitMinutes = 14, [switch]$NoPause, [int]$PollSeconds = 20, [string]$TestDir, [switch]$NoLaunch)
$task = 'T21'
$pollEvery = $PollSeconds
$LibTitle = '90161Z Probe Files'
$LibFolder = '90161ZProbeFiles'
$ListTitle = '90161Z Probe'
$ListFolder = '90161ZProbe'
$BookName = '90161Z-T21-fake-book-r1.xlsx'
$MacroName = '90161Z-T21-fake-macro-r1.xlsm'
$LinksName = '90161Z-T21-links-r3.html'
$StateName = '90161Z-T21-person-state-r3.txt'
$ViewTitle = 'ProbeButton'
$HeaderText = '90-161.Z test header'
# The ID of the flow "90161Z T21 Probe Button r1": a solution keeps the workflow ID (tests/check_flow_solution.py checks it against the builder).
$ButtonFlowId = '260790dd-beca-5206-83f7-e6aab40c894e'
$Rev = 'r3'

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
# <<< site-common
# >>> fake-workbooks: generated by scripts/build_probe_samples.py (do not edit)
$FakeBookBase64 = @(
  'UEsDBBQAAAAAAAAAcV3FLx19LgIAAC4CAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbDw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rp',
  'bmc9IlVURi04IiBzdGFuZGFsb25lPSJ5ZXMiPz4KPFR5cGVzIHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5v',
  'cmcvcGFja2FnZS8yMDA2L2NvbnRlbnQtdHlwZXMiPjxEZWZhdWx0IEV4dGVuc2lvbj0icmVscyIgQ29udGVudFR5cGU9ImFwcGxp',
  'Y2F0aW9uL3ZuZC5vcGVueG1sZm9ybWF0cy1wYWNrYWdlLnJlbGF0aW9uc2hpcHMreG1sIi8+PERlZmF1bHQgRXh0ZW5zaW9uPSJ4',
  'bWwiIENvbnRlbnRUeXBlPSJhcHBsaWNhdGlvbi94bWwiLz48T3ZlcnJpZGUgUGFydE5hbWU9Ii94bC93b3JrYm9vay54bWwiIENv',
  'bnRlbnRUeXBlPSJhcHBsaWNhdGlvbi92bmQub3BlbnhtbGZvcm1hdHMtb2ZmaWNlZG9jdW1lbnQuc3ByZWFkc2hlZXRtbC5zaGVl',
  'dC5tYWluK3htbCIvPjxPdmVycmlkZSBQYXJ0TmFtZT0iL3hsL3dvcmtzaGVldHMvc2hlZXQxLnhtbCIgQ29udGVudFR5cGU9ImFw',
  'cGxpY2F0aW9uL3ZuZC5vcGVueG1sZm9ybWF0cy1vZmZpY2Vkb2N1bWVudC5zcHJlYWRzaGVldG1sLndvcmtzaGVldCt4bWwiLz48',
  'L1R5cGVzPlBLAwQUAAAAAAAAAHFdBlnHgigBAAAoAQAACwAAAF9yZWxzLy5yZWxzPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGlu',
  'Zz0iVVRGLTgiIHN0YW5kYWxvbmU9InllcyI/Pgo8UmVsYXRpb25zaGlwcyB4bWxucz0iaHR0cDovL3NjaGVtYXMub3BlbnhtbGZv',
  'cm1hdHMub3JnL3BhY2thZ2UvMjAwNi9yZWxhdGlvbnNoaXBzIj48UmVsYXRpb25zaGlwIElkPSJySWQxIiBUeXBlPSJodHRwOi8v',
  'c2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvb2ZmaWNlRG9jdW1lbnQvMjAwNi9yZWxhdGlvbnNoaXBzL29mZmljZURvY3VtZW50',
  'IiBUYXJnZXQ9InhsL3dvcmtib29rLnhtbCIvPjwvUmVsYXRpb25zaGlwcz5QSwMEFAAAAAAAAABxXXdA/sQcAQAAHAEAAA8AAAB4',
  'bC93b3JrYm9vay54bWw8P3htbCB2ZXJzaW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+Cjx3b3Jr',
  'Ym9vayB4bWxucz0iaHR0cDovL3NjaGVtYXMub3BlbnhtbGZvcm1hdHMub3JnL3NwcmVhZHNoZWV0bWwvMjAwNi9tYWluIiB4bWxu',
  'czpyPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvb2ZmaWNlRG9jdW1lbnQvMjAwNi9yZWxhdGlvbnNoaXBzIj48',
  'c2hlZXRzPjxzaGVldCBuYW1lPSJTaGVldDEiIHNoZWV0SWQ9IjEiIHI6aWQ9InJJZDEiLz48L3NoZWV0cz48L3dvcmtib29rPlBL',
  'AwQUAAAAAAAAAHFdmm88fCkBAAApAQAAGgAAAHhsL19yZWxzL3dvcmtib29rLnhtbC5yZWxzPD94bWwgdmVyc2lvbj0iMS4wIiBl',
  'bmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9InllcyI/Pgo8UmVsYXRpb25zaGlwcyB4bWxucz0iaHR0cDovL3NjaGVtYXMub3Bl',
  'bnhtbGZvcm1hdHMub3JnL3BhY2thZ2UvMjAwNi9yZWxhdGlvbnNoaXBzIj48UmVsYXRpb25zaGlwIElkPSJySWQxIiBUeXBlPSJo',
  'dHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvb2ZmaWNlRG9jdW1lbnQvMjAwNi9yZWxhdGlvbnNoaXBzL3dvcmtzaGVl',
  'dCIgVGFyZ2V0PSJ3b3Jrc2hlZXRzL3NoZWV0MS54bWwiLz48L1JlbGF0aW9uc2hpcHM+UEsDBBQAAAAAAAAAcV0D7Z5uLAIAACwC',
  'AAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxv',
  'bmU9InllcyI/Pgo8d29ya3NoZWV0IHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvc3ByZWFkc2hlZXRt',
  'bC8yMDA2L21haW4iPjxzaGVldERhdGE+PHJvdyByPSIxIj48YyByPSJBMSIgdD0iaW5saW5lU3RyIj48aXM+PHQ+RkFLRSBib29r',
  'IFIyNzwvdD48L2lzPjwvYz48YyByPSJCMSIgdD0iaW5saW5lU3RyIj48aXM+PHQ+SW52ZW50ZWQgbnVtYmVycywgbm90aGluZyBy',
  'ZWFsPC90PjwvaXM+PC9jPjwvcm93Pjxyb3cgcj0iMiI+PGMgcj0iQTIiIHQ9ImlubGluZVN0ciI+PGlzPjx0PkZha2UgaXRlbSBv',
  'bmU8L3Q+PC9pcz48L2M+PGMgcj0iQjIiIHQ9ImlubGluZVN0ciI+PGlzPjx0PjExPC90PjwvaXM+PC9jPjwvcm93Pjxyb3cgcj0i',
  'MyI+PGMgcj0iQTMiIHQ9ImlubGluZVN0ciI+PGlzPjx0PkZha2UgaXRlbSB0d288L3Q+PC9pcz48L2M+PGMgcj0iQjMiIHQ9Imlu',
  'bGluZVN0ciI+PGlzPjx0PjIyPC90PjwvaXM+PC9jPjwvcm93Pjwvc2hlZXREYXRhPjwvd29ya3NoZWV0PlBLAQIUAxQAAAAAAAAA',
  'cV3FLx19LgIAAC4CAAATAAAAAAAAAAAAAACkAQAAAABbQ29udGVudF9UeXBlc10ueG1sUEsBAhQDFAAAAAAAAABxXQZZx4IoAQAA',
  'KAEAAAsAAAAAAAAAAAAAAKQBXwIAAF9yZWxzLy5yZWxzUEsBAhQDFAAAAAAAAABxXXdA/sQcAQAAHAEAAA8AAAAAAAAAAAAAAKQB',
  'sAMAAHhsL3dvcmtib29rLnhtbFBLAQIUAxQAAAAAAAAAcV2abzx8KQEAACkBAAAaAAAAAAAAAAAAAACkAfkEAAB4bC9fcmVscy93',
  'b3JrYm9vay54bWwucmVsc1BLAQIUAxQAAAAAAAAAcV0D7Z5uLAIAACwCAAAYAAAAAAAAAAAAAACkAVoGAAB4bC93b3Jrc2hlZXRz',
  'L3NoZWV0MS54bWxQSwUGAAAAAAUABQBFAQAAvAgAAAAA'
) -join ' '
$FakeMacroBase64 = @(
  'UEsDBBQAAAAAAAAAcV0Hglo7ZQIAAGUCAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbDw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rp',
  'bmc9IlVURi04IiBzdGFuZGFsb25lPSJ5ZXMiPz4KPFR5cGVzIHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5v',
  'cmcvcGFja2FnZS8yMDA2L2NvbnRlbnQtdHlwZXMiPjxEZWZhdWx0IEV4dGVuc2lvbj0icmVscyIgQ29udGVudFR5cGU9ImFwcGxp',
  'Y2F0aW9uL3ZuZC5vcGVueG1sZm9ybWF0cy1wYWNrYWdlLnJlbGF0aW9uc2hpcHMreG1sIi8+PERlZmF1bHQgRXh0ZW5zaW9uPSJ4',
  'bWwiIENvbnRlbnRUeXBlPSJhcHBsaWNhdGlvbi94bWwiLz48RGVmYXVsdCBFeHRlbnNpb249ImJpbiIgQ29udGVudFR5cGU9ImFw',
  'cGxpY2F0aW9uL3ZuZC5tcy1vZmZpY2UudmJhUHJvamVjdCIvPjxPdmVycmlkZSBQYXJ0TmFtZT0iL3hsL3dvcmtib29rLnhtbCIg',
  'Q29udGVudFR5cGU9ImFwcGxpY2F0aW9uL3ZuZC5tcy1leGNlbC5zaGVldC5tYWNyb0VuYWJsZWQubWFpbit4bWwiLz48T3ZlcnJp',
  'ZGUgUGFydE5hbWU9Ii94bC93b3Jrc2hlZXRzL3NoZWV0MS54bWwiIENvbnRlbnRUeXBlPSJhcHBsaWNhdGlvbi92bmQub3Blbnht',
  'bGZvcm1hdHMtb2ZmaWNlZG9jdW1lbnQuc3ByZWFkc2hlZXRtbC53b3Jrc2hlZXQreG1sIi8+PC9UeXBlcz5QSwMEFAAAAAAAAABx',
  'XQZZx4IoAQAAKAEAAAsAAABfcmVscy8ucmVsczw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rpbmc9IlVURi04IiBzdGFuZGFsb25l',
  'PSJ5ZXMiPz4KPFJlbGF0aW9uc2hpcHMgeG1sbnM9Imh0dHA6Ly9zY2hlbWFzLm9wZW54bWxmb3JtYXRzLm9yZy9wYWNrYWdlLzIw',
  'MDYvcmVsYXRpb25zaGlwcyI+PFJlbGF0aW9uc2hpcCBJZD0icklkMSIgVHlwZT0iaHR0cDovL3NjaGVtYXMub3BlbnhtbGZvcm1h',
  'dHMub3JnL29mZmljZURvY3VtZW50LzIwMDYvcmVsYXRpb25zaGlwcy9vZmZpY2VEb2N1bWVudCIgVGFyZ2V0PSJ4bC93b3JrYm9v',
  'ay54bWwiLz48L1JlbGF0aW9uc2hpcHM+UEsDBBQAAAAAAAAAcV13QP7EHAEAABwBAAAPAAAAeGwvd29ya2Jvb2sueG1sPD94bWwg',
  'dmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9InllcyI/Pgo8d29ya2Jvb2sgeG1sbnM9Imh0dHA6Ly9z',
  'Y2hlbWFzLm9wZW54bWxmb3JtYXRzLm9yZy9zcHJlYWRzaGVldG1sLzIwMDYvbWFpbiIgeG1sbnM6cj0iaHR0cDovL3NjaGVtYXMu',
  'b3BlbnhtbGZvcm1hdHMub3JnL29mZmljZURvY3VtZW50LzIwMDYvcmVsYXRpb25zaGlwcyI+PHNoZWV0cz48c2hlZXQgbmFtZT0i',
  'U2hlZXQxIiBzaGVldElkPSIxIiByOmlkPSJySWQxIi8+PC9zaGVldHM+PC93b3JrYm9vaz5QSwMEFAAAAAAAAABxXalvuAejAQAA',
  'owEAABoAAAB4bC9fcmVscy93b3JrYm9vay54bWwucmVsczw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rpbmc9IlVURi04IiBzdGFu',
  'ZGFsb25lPSJ5ZXMiPz4KPFJlbGF0aW9uc2hpcHMgeG1sbnM9Imh0dHA6Ly9zY2hlbWFzLm9wZW54bWxmb3JtYXRzLm9yZy9wYWNr',
  'YWdlLzIwMDYvcmVsYXRpb25zaGlwcyI+PFJlbGF0aW9uc2hpcCBJZD0icklkMSIgVHlwZT0iaHR0cDovL3NjaGVtYXMub3Blbnht',
  'bGZvcm1hdHMub3JnL29mZmljZURvY3VtZW50LzIwMDYvcmVsYXRpb25zaGlwcy93b3Jrc2hlZXQiIFRhcmdldD0id29ya3NoZWV0',
  'cy9zaGVldDEueG1sIi8+PFJlbGF0aW9uc2hpcCBJZD0icklkMiIgVHlwZT0iaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNvbS9v',
  'ZmZpY2UvMjAwNi9yZWxhdGlvbnNoaXBzL3ZiYVByb2plY3QiIFRhcmdldD0idmJhUHJvamVjdC5iaW4iLz48L1JlbGF0aW9uc2hp',
  'cHM+UEsDBBQAAAAAAAAAcV0D7Z5uLAIAACwCAAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sPD94bWwgdmVyc2lvbj0iMS4w',
  'IiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9InllcyI/Pgo8d29ya3NoZWV0IHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVu',
  'eG1sZm9ybWF0cy5vcmcvc3ByZWFkc2hlZXRtbC8yMDA2L21haW4iPjxzaGVldERhdGE+PHJvdyByPSIxIj48YyByPSJBMSIgdD0i',
  'aW5saW5lU3RyIj48aXM+PHQ+RkFLRSBib29rIFIyNzwvdD48L2lzPjwvYz48YyByPSJCMSIgdD0iaW5saW5lU3RyIj48aXM+PHQ+',
  'SW52ZW50ZWQgbnVtYmVycywgbm90aGluZyByZWFsPC90PjwvaXM+PC9jPjwvcm93Pjxyb3cgcj0iMiI+PGMgcj0iQTIiIHQ9Imlu',
  'bGluZVN0ciI+PGlzPjx0PkZha2UgaXRlbSBvbmU8L3Q+PC9pcz48L2M+PGMgcj0iQjIiIHQ9ImlubGluZVN0ciI+PGlzPjx0PjEx',
  'PC90PjwvaXM+PC9jPjwvcm93Pjxyb3cgcj0iMyI+PGMgcj0iQTMiIHQ9ImlubGluZVN0ciI+PGlzPjx0PkZha2UgaXRlbSB0d288',
  'L3Q+PC9pcz48L2M+PGMgcj0iQjMiIHQ9ImlubGluZVN0ciI+PGlzPjx0PjIyPC90PjwvaXM+PC9jPjwvcm93Pjwvc2hlZXREYXRh',
  'Pjwvd29ya3NoZWV0PlBLAwQUAAAAAAAAAHFd+TA98AAYAAAAGAAAEQAAAHhsL3ZiYVByb2plY3QuYmlu0M8R4KGxGuEAAAAAAAAA',
  'AAAAAAAAAAAAPgADAP7/CQAGAAAAAAAAAAAAAAABAAAAAQAAAAAAAAAAEAAABAAAAAEAAAD+////AAAAAAAAAAD/////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '///////////////////////////////////////////////////////////////9////AgAAAAMAAAD+/////v///wYAAAAHAAAA',
  'CAAAAAkAAAAKAAAA/v//////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '/////////////////////////////////////////////1IAbwBvAHQAIABFAG4AdAByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWAAUB//////////8CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'BQAAAAALAAAAAAAAVgBCAEEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAgAAQH//////////wgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQAFIATwBKAEUA',
  'QwBUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAACAQEAAAADAAAA/////wAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADJAQAAAAAAAFAAUgBPAEoARQBDAFQAdwBtAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUAAIB////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAACAAAAFYAAAAAAAAAXwBWAEIAQQBfAFAAUgBPAEoARQBDAFQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAABoAAgEGAAAA//////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAABwAAAAAAAABk',
  'AGkAcgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAACAf//////////',
  '/////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsAAADGAwAAAAAAAFQAaABpAHMAVwBvAHIAawBiAG8AbwBr',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaAAIB////////////////AAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAGwAAANcBAAAAAAAAUwBoAGUAZQB0ADEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAA4AAgEFAAAA//////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAjAAAA',
  'VAEAAAAAAABNAG8AZAB1AGwAZQAxAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAC',
  'AQcAAAAEAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACkAAACWAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA////////////////AAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAP///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAC',
  'AAAAAwAAAAQAAAAFAAAABgAAAAcAAAD+////CQAAAP7////+////DAAAAA0AAAAOAAAADwAAABAAAAARAAAAEgAAABMAAAAUAAAA',
  'FQAAABYAAAAXAAAAGAAAABkAAAAaAAAA/v///xwAAAAdAAAAHgAAAB8AAAAgAAAAIQAAACIAAAD+////JAAAACUAAAAmAAAAJwAA',
  'ACgAAAD+////KgAAACsAAAD+////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////////////////////////////',
  '////////////////////////////////////////////////////////////////////////////SUQ9Ins5MDE2QTBCMS0yQjND',
  'LTRENUUtOEY3MC0xQTJCM0M0RDVFNkZ9Ig0KRG9jdW1lbnQ9VGhpc1dvcmtib29rLyZIMDAwMDAwMDANCkRvY3VtZW50PVNoZWV0',
  'MS8mSDAwMDAwMDAwDQpNb2R1bGU9TW9kdWxlMQ0KTmFtZT0iVkJBUHJvamVjdCINCkhlbHBDb250ZXh0SUQ9IjAiDQpWZXJzaW9u',
  'Q29tcGF0aWJsZTMyPSIzOTMyMjIwMDAiDQpDTUc9IjVBNThCMTQzRUY0N0VGNDdFRjQ3RUY0NyINCkRQQj0iNUE1OEIxNDNFQjQy',
  'RUM0MkVDNDIiDQpHQz0iNUE1OEIxNDNFQTQ0RUE0NDE1Ig0KDQpbSG9zdCBFeHRlbmRlciBJbmZvXQ0KJkgwMDAwMDAwMT17Mzgz',
  'MkQ2NDAtQ0Y5MC0xMUNGLThFNDMtMDBBMEM5MTEwMDVBfTtWQkU7JkgwMDAwMDAwMA0KDQpbV29ya3NwYWNlXQ0KVGhpc1dvcmti',
  'b29rPTAsIDAsIDAsIDAsIEMNClNoZWV0MT0wLCAwLCAwLCAwLCBDDQpNb2R1bGUxPTAsIDAsIDAsIDAsIEMNCgAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABUaGlzV29ya2Jvb2sAVABoAGkAcwBXAG8AcgBrAGIA',
  'bwBvAGsAAABTaGVldDEAUwBoAGUAZQB0ADEAAABNb2R1bGUxAE0AbwBkAHUAbABlADEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAMxh//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAABwrMAAQAEAAAAAQAAAAACAAQAAAAACQQAABQABAAAAAAJBAAAAwAAAgAAAOQEBAAACgAAAFZCQVAAcm9qZWN0',
  'BQAAAAAAAEAAAAAAAAAGAAAAAAAAPQAAAAAABwAABAAAAAAAAAAACAAEAAAAAAAAAAAJAAQAAAAAAQAAAAAADAAAAAAAADwAAAAA',
  'AAAWAAYAAAAAc3Rkb2xlPgAADAAAAHMAdAAAZABvAGwAZQAADQBoAAAAXgAAAAAqXEd7MDAAMDIwNDMwLTAAMDAwLTAwMDAALUMw',
  'MDAtMDAAMDAwMDAwMDAANDZ9IzIuMCMAMCNDOlxXaW4AZG93c1xTeXMAdGVtMzJcc3QAZG9sZTIudGwAYiNPTEUgQXUAdG9tYXRp',
  'b24AAAAAAAAAFgAABgAAAE9mZmkAY2U+AAwAAAAATwBmAGYAaQAAYwBlAA0AngAAAACUAAAAKlwAR3syREY4RDAANEMtNUJGQS0A',
  'MTAxQi1CREUANS0wMEFBMDAANDRERTUyfSMAMi4wIzAjQzoAXFByb2dyYW0AIEZpbGVzXEMAb21tb24gRmkAbGVzXE1pY3IAb3Nv',
  'ZnQgU2gAYXJlZFxPRkYASUNFMTZcTVMATy5ETEwjTWkAY3Jvc29mdCAAT2ZmaWNlIDEANi4wIE9iamUAY3QgTGlicmEAcnkAAAAA',
  'AAAADwACAAAAAwAAEwACAAAA//8AGQAMAAAAVGgAaXNXb3JrYm8Ab2tHABgAAAAAVABoAGkAcwAAVwBvAHIAawAAYgBvAG8AawAA',
  'GgAMAAAAVGgAaXNXb3JrYm8Ab2syABgAAAAAVABoAGkAcwAAVwBvAHIAawAAYgBvAG8AawAAHAAAAAAASAAAAAAAADEABAAAAAAA',
  'AAAAHgAABAAAAAAAAAAALAACAAAA//8AIgAAAAAAKwAAAAAAABkABgAAAABTaGVldDEARwAMAAAAUwAAaABlAGUAdAAAMQAaAAYA',
  'AAAAU2hlZXQxMgAADAAAAFMAaAAAZQBlAHQAMQAAHAAAAAAASAAAAAAAADEABAAAAAAAAAAAHgAABAAAAAAAAAAALAACAAAA//8A',
  'IgAAAAAAKwAAAAAAABkABwAAAABNb2R1bGUAMUcADgAAAE0AAG8AZAB1AGwAAGUAMQAaAAcAAAAATW9kdWwAZTEyAA4AAAAATQBv',
  'AGQAdQAAbABlADEAHAAAAAAAAEgAAAAAAAAxAAQAAAAAAAAAAB4ABAAAAAAAAAAALAAAAgAAAP//IQAAAAAAACsAAAAAAAAQAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdOxAEF0dHJpYnV0AGUg',
  'VkJfTmFtAGUgPSAiVGhpAHNXb3JrYm9vAGsiDQpBdHRyAGlidXRlIFZCAF9CYXNlID0gACIwezAwMDIwADgxOS0wMDAwAC0wMDAw',
  'LUMwADAwLTAwMDAwADAwMDAwNDZ9ACINCkF0dHJpAGJ1dGUgVkJfAEdsb2JhbE5hAG1lU3BhY2UgAD0gRmFsc2UNAApBdHRyaWJ1',
  'AHRlIFZCX0NyAGVhdGFibGUgAD0gRmFsc2UNAApBdHRyaWJ1AHRlIFZCX1ByAGVkZWNsYXJlAGRJZCA9IFRyAHVlDQpBdHRyAGli',
  'dXRlIFZCAF9FeHBvc2VkACA9IFRydWUNAApBdHRyaWJ1AHRlIFZCX1RlAG1wbGF0ZURlAHJpdmVkID0gAEZhbHNlDQpBAHR0cmli',
  'dXRlACBWQl9DdXN0AG9taXphYmxlACA9IFRydWUNAApQcml2YXRlACBTdWIgV29yAGtib29rX09wAGVuKCkNCiAgACAgVGhpc1dv',
  'AHJrYm9vay5XAG9ya3NoZWV0AHMoMSkuUmFuAGdlKCJBNiIpAC5WYWx1ZSA9ACAiRkFLRSBNAEFDUk8gUkFOACBSMjciDQpFAG5k',
  'IFN1Yg0KAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABULEAQXR0cmlidXQAZSBWQl9OYW0AZSA9ICJT',
  'aGUAZXQxIg0KQXQAdHJpYnV0ZSAAVkJfQmFzZSAAPSAiMHswMDAAMjA4MjAtMDAAMDAtMDAwMC0AQzAwMC0wMDAAMDAwMDAwMDQA',
  'Nn0iDQpBdHQAcmlidXRlIFYAQl9HbG9iYWwATmFtZVNwYWMAZSA9IEZhbHMAZQ0KQXR0cmkAYnV0ZSBWQl8AQ3JlYXRhYmwAZSA9',
  'IEZhbHMAZQ0KQXR0cmkAYnV0ZSBWQl8AUHJlZGVjbGEAcmVkSWQgPSAAVHJ1ZQ0KQXQAdHJpYnV0ZSAAVkJfRXhwb3MAZWQgPSBU',
  'cnUAZQ0KQXR0cmkAYnV0ZSBWQl8AVGVtcGxhdGUARGVyaXZlZCAAPSBGYWxzZQ0ACkF0dHJpYnUAdGUgVkJfQ3UAc3RvbWl6YWIA',
  'bGUgPSBUcnUAZQ0KAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkrAAQXR0cmlidXQAZSBWQl9O',
  'YW0AZSA9ICJNb2QAdWxlMSINClMAdWIgRmFrZU0AYWNybygpDQoAICAgIFRoaXMAV29ya2Jvb2sALldvcmtzaGUAZXRzKDEpLlIA',
  'YW5nZSgiQTYAIikuVmFsdWUAID0gIkZBS0UAIE1BQ1JPIFIAQU4gUjI3Ig0ACkVuZCBTdWIADQoAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUEsBAhQDFAAAAAAAAABxXQeCWjtl',
  'AgAAZQIAABMAAAAAAAAAAAAAAKQBAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECFAMUAAAAAAAAAHFdBlnHgigBAAAoAQAACwAA',
  'AAAAAAAAAAAApAGWAgAAX3JlbHMvLnJlbHNQSwECFAMUAAAAAAAAAHFdd0D+xBwBAAAcAQAADwAAAAAAAAAAAAAApAHnAwAAeGwv',
  'd29ya2Jvb2sueG1sUEsBAhQDFAAAAAAAAABxXalvuAejAQAAowEAABoAAAAAAAAAAAAAAKQBMAUAAHhsL19yZWxzL3dvcmtib29r',
  'LnhtbC5yZWxzUEsBAhQDFAAAAAAAAABxXQPtnm4sAgAALAIAABgAAAAAAAAAAAAAAKQBCwcAAHhsL3dvcmtzaGVldHMvc2hlZXQx',
  'LnhtbFBLAQIUAxQAAAAAAAAAcV35MD3wABgAAAAYAAARAAAAAAAAAAAAAACkAW0JAAB4bC92YmFQcm9qZWN0LmJpblBLBQYAAAAA',
  'BgAGAIQBAACcIQAAAAA='
) -join ' '
# <<< fake-workbooks

function Hide-Site([string]$Text, [string]$Site) {
  # The result is e-mailed: no site, tenant or sign-in address may stay in it (the same rule as T16, T18, T19 and T20).
  # Every address is masked here, so the second person's address cannot reach a result line even through an error text.
  $Text = $Text -replace '[\w.+-]+@[\w.-]+', '<EMAIL>'
  $Text = $Text -replace '[\w.+-]+%40[\w.-]+', '<EMAIL>'
  if ($Site) {
    $Text = $Text -replace [regex]::Escape($Site.TrimEnd('/')), '<SITE>'
    try {
      $u = [uri]$Site
      $Text = $Text -replace [regex]::Escape($u.Host), '<SITE-HOST>'
      $path = $u.AbsolutePath.TrimEnd('/')
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
  # No word boundary: a GUID right after URL-encoded characters (guid%27...) must be masked too.
  $Text = $Text -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>'
  return $Text
}

function Invoke-Rest([string]$Method, [string]$Uri, [string]$Body) {
  # One SharePoint REST request through the signed-in PnP connection (the same call T20 uses). Method: Get, Post or Merge.
  $url = $script:site.TrimEnd('/') + '/' + $Uri
  if ($Method -eq 'Get') { return [string](Invoke-PnPSPRestMethod -Method Get -Url $url -Raw -ErrorAction Stop) }
  return [string](Invoke-PnPSPRestMethod -Method $Method -Url $url -Content $Body -ContentType 'application/json;odata=verbose' -Raw -ErrorAction Stop)
}
function Get-RestValue([string]$Uri) { return @(((Invoke-Rest 'Get' $Uri '') | ConvertFrom-Json).value) }
function Get-SiteList {
  # Every list on the site that is not hidden, with the folder name it was made under (the folder name never changes).
  return @(Get-RestValue ('_api/web/lists?$select=Id,Title,ItemCount,BaseTemplate,Hidden,EnableAttachments,HasUniqueRoleAssignments,RootFolder/Name&$expand=RootFolder&$top=1000') | Where-Object { -not $_.Hidden })
}
function Find-ByFolder([string]$Folder) {
  foreach ($l in (Get-SiteList)) { if ([string]$l.RootFolder.Name -eq $Folder) { return $l } }
  return $null
}
function Add-Item([string]$Name, [string]$Status, [string]$Text) {
  $script:lines.Add('ITEM ' + $Name + ' ' + $Status + $(if ($Text) { ' ' + $Text } else { '' }))
  if ($Status -eq 'PASS') { $script:passed++ } elseif ($Status -eq 'FAIL') { $script:failed++ }
}
function Add-Test([string]$Name, [string[]]$Piece, [bool]$Pass) {
  # One summary line per test: "T4 PASSED: a ...; next ...".
  $script:lines.Add($Name + ' ' + $(if ($Pass) { 'PASSED' } else { 'FAILED' }) + ': ' + ($Piece -join '; '))
  if ($Pass) { $script:passed++ } else { $script:failed++ }
}
function Format-Detail([string]$Text) {
  # The flow's ProbeDetail (or an error text) for a line: one line, anything that looks like an address or a link masked, cut to 160.
  $t = ($Text -replace '\s+', ' ').Trim()
  $t = $t -replace '[\w.+-]+@[\w.-]+', '<MASKED>'
  $t = $t -replace '[\w.+-]+%40[\w.-]+', '<MASKED>'
  $t = $t -replace 'https?://\S+', '<MASKED>'
  if ($t.Length -gt 160) { $t = $t.Substring(0, 160) }
  return $t
}
function Get-ListRow([string]$Title, [string[]]$Fields) {
  # Plain rows (Id and the named fields as text); only counts and flags are written from them.
  $rows = @(Get-PnPListItem -List $Title -Fields $Fields -PageSize 500 -ErrorAction Stop)
  return @($rows | ForEach-Object {
    $o = @{ Id = [int]$_.Id; Item = $_ }
    foreach ($f in $Fields) { $o[$f] = [string]$_[$f] }
    $o
  })
}
function Find-Result($Rows, [string]$Test, [string]$Way) {
  # The newest RESULT row for a test and way, or $null.
  $hit = @($Rows | Where-Object { $_.Title -eq 'RESULT' -and $_.ProbeTest -eq $Test -and $_.ProbeWay -eq $Way } | Sort-Object { $_.Id } -Descending)
  if ($hit.Count) { return $hit[0] }
  return $null
}
function Wait-Until([scriptblock]$Done, [string]$What) {
  # Checks every $PollSeconds for up to $WaitMinutes; a progress line a minute. A failed check is retried; 3 in a row stop the part.
  $start = Get-Date
  $end = $start.AddMinutes($WaitMinutes)
  $misses = 0; $nextNote = $start.AddMinutes(1)
  while ($true) {
    $isDone = $false
    try { $isDone = [bool](& $Done); $misses = 0 }
    catch {
      $misses++
      if ($misses -ge 3) { throw }
      Write-Host ('  A check failed (' + $misses + ' of 3 allowed in a row); trying again ...')
    }
    if ($isDone) { return $true }
    $now = Get-Date
    if ($now -ge $end) { return $false }
    if ($now -ge $nextNote) {
      Write-Host ('  Waiting for ' + $What + ' (' + [int]($now - $start).TotalMinutes + ' of ' + $WaitMinutes + ' minutes) ...')
      $nextNote = $nextNote.AddMinutes(1)
    }
    Start-Sleep -Seconds $pollEvery
  }
}

function Get-HtmlText([string]$Text) { return [System.Net.WebUtility]::HtmlEncode($Text) }
function Write-LinksPage([string]$Dir, [string]$Site) {
  # The test page: one big link per thing to open. It holds the site address, so it stays in the T21 folder on this computer;
  # it is never a result file. Colors and font as the RADE window.
  $s = $Site.TrimEnd('/')
  $links = @(
    @('Open the new row form', ($s + '/Lists/' + $ListFolder + '/NewForm.aspx'), 'Tests T4 and the list form look: the form other people use.'),
    @('Open the probe list', ($s + '/Lists/' + $ListFolder + '/AllItems.aspx'), 'The rows the tests wrote.'),
    @('Open the list with the button', ($s + '/Lists/' + $ListFolder + '/' + $ViewTitle + '.aspx'), 'The view look: a button that starts a flow.'),
    @('Open the fake workbook', ($s + '/' + $LibFolder + '/' + $BookName + '?web=1'), 'The Excel look: a workbook in Excel for the web.'),
    @('Open the fake macro workbook', ($s + '/' + $LibFolder + '/' + $MacroName + '?web=1'), 'The Excel look: a workbook that holds a macro.'))
  $body = New-Object System.Text.StringBuilder
  [void]$body.Append('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>90-161.Z test page r3</title><style>')
  [void]$body.Append('body{font-family:"Segoe UI",Arial,sans-serif;color:#1b2430;background:#fff;margin:0}.light{height:6px;background:#ffd520}')
  [void]$body.Append('main{max-width:760px;padding:24px 32px}h1{font-family:"Segoe UI Semibold","Segoe UI",Arial,sans-serif;font-weight:600;font-size:29px;color:#0b2545;margin:8px 0 4px}')
  [void]$body.Append('p{font-size:15px;color:#5a6573;margin:0 0 24px}a.go{display:block;border:1px solid #00539f;background:#00539f;color:#fff;text-decoration:none;font-size:17px;font-weight:700;padding:14px 18px;margin:0 0 4px}')
  [void]$body.Append('a.go:focus{outline:2px solid #0b2545;outline-offset:2px}span.why{display:block;font-size:14px;color:#5a6573;margin:0 0 20px}</style></head><body><div class="light"></div><main>')
  [void]$body.Append('<h1>90-161.Z test page</h1><p>Round R27. Fake data only. Open each link when the RADE window says so.</p>')
  foreach ($l in $links) { [void]$body.Append('<a class="go" href="' + (Get-HtmlText $l[1]) + '">' + (Get-HtmlText $l[0]) + '</a><span class="why">' + (Get-HtmlText $l[2]) + '</span>') }
  [void]$body.Append('</main></body></html>')
  Set-Content -LiteralPath (Join-Path $Dir $LinksName) -Value $body.ToString() -Encoding UTF8
  return $links.Count
}
function Get-AuthorId($Row) { $a = $Row.Item['Author']; if ($a -and $a.LookupId) { return [int]$a.LookupId }; return 0 }

function Read-PersonAddress {
  # The second person's address, typed by the PFM in a small window. It is returned to the caller and used in memory only; this
  # function writes nothing. In a test run (-TestDir) a fake address may come from the test.
  if ($TestDir -and $env:T21_TEST_ADDRESS) { return ([string]$env:T21_TEST_ADDRESS).Trim() }
  $prompt = 'Type the e-mail address of the second person for test T4 (a person who is not you), then select OK. It is used once, stays on this computer and is not saved or sent.'
  try {
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
    return ([string][Microsoft.VisualBasic.Interaction]::InputBox($prompt, '90-161.Z test T4', '')).Trim()
  } catch {
    if ($env:RADE_CONTRACT) { throw 'ADDRESS window not available: the window for the second person could not open on this computer.' }
    return ([string](Read-Host 'E-mail address of the second person (it is not saved), then press Enter')).Trim()
  }
}
function Get-GroupMemberId([int]$GroupId) {
  return @(Get-RestValue ('_api/web/sitegroups/getbyid(' + $GroupId + ')/users?$select=Id&$top=5000') | ForEach-Object { [int]$_.Id })
}
function Read-State([string]$Dir) {
  # The saved numbers of the second person (site user Id, group Id, whether the person was a member before): no address, no name.
  $f = Join-Path $Dir $StateName
  if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { return $null }
  $h = @{}
  foreach ($l in @(Get-Content -LiteralPath $f)) { if ([string]$l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() } }
  if ($h['UserId'] -notmatch '^\d+$') { return $null }
  return $h
}
function Send-Formatter([string]$Kind, [string]$Json, [string]$ListId, [string]$TargetId) {
  # Sets a formatting JSON on a content type (form header) or a view. Easy path first: the CSOM property; then the REST merge.
  # Returns 'csom', 'rest' or 'none' (and keeps the last error text in $script:fmtError).
  $script:fmtError = ''
  try {
    $ctx = Get-PnPContext
    $list = $ctx.Web.Lists.GetById([guid]$ListId)
    if ($Kind -eq 'form') { $t = $list.ContentTypes.GetById($TargetId); $t.ClientFormCustomFormatter = $Json; $t.Update($false) }
    else { $t = $list.Views.GetById([guid]$TargetId); $t.CustomFormatter = $Json; $t.Update() }
    $ctx.ExecuteQuery()
    return 'csom'
  } catch { $script:fmtError = [string]$_.Exception.Message }
  try {
    $lbase = "_api/web/lists(guid'" + $ListId + "')"
    if ($Kind -eq 'form') {
      $body = @{ __metadata = @{ type = 'SP.ContentType' }; ClientFormCustomFormatter = $Json } | ConvertTo-Json -Depth 5 -Compress
      $null = Invoke-Rest 'Merge' ($lbase + "/contenttypes('" + $TargetId + "')") $body
    } else {
      $body = @{ __metadata = @{ type = 'SP.View' }; CustomFormatter = $Json } | ConvertTo-Json -Depth 5 -Compress
      $null = Invoke-Rest 'Merge' ($lbase + "/views(guid'" + $TargetId + "')") $body
    }
    return 'rest'
  } catch { $script:fmtError = [string]$_.Exception.Message }
  return 'none'
}

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
$passed = 0; $failed = 0
$fatal = $false
$fmtError = ''
try {
  $ErrorActionPreference = 'Stop'
  if (-not $Part) { throw 'PART not given: use -Part Make, Person, Run, Look, Open, Read or Clean.' }
  if ($Part -eq 'Read' -and -not $PSBoundParameters.ContainsKey('WaitMinutes')) { $WaitMinutes = 4 }
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 21' -Create }
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $lines.Add('TASK T21 probe ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + $(if ($Part -eq 'Read') { ', wait-minutes=' + $WaitMinutes } else { '' }))

  if ($Part -eq 'Open') {
    # No sign-in: this part only works on this computer.
    $n = Write-LinksPage $dir $site
    Add-Item 'o1-page' 'PASS' ('test page written, links=' + $n)
    if (-not $NoLaunch) { Start-Process -FilePath (Join-Path $dir $LinksName) }
    Add-Item 'o2-open' 'PASS' ('test page opened in the browser=' + $(if ($NoLaunch) { 'no (test run)' } else { 'yes' }))
  } else {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'Connecting to the site. If a sign-in window opens, sign in with your CAC.'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
  # The first request is a read: it proves the REST route before anything is written.
  $siteLists = Get-SiteList
  $lines.Add('ITEM a-rest-read INFO lists read from the site=' + $siteLists.Count)

  if ($Part -eq 'Make') {
    $made = @{ library = 0; list = 0; columns = 0; permissions = 0; files = 0 }
    $skip = @{ library = 0; list = 0; columns = 0; permissions = 0; files = 0 }

    # m1, m2: the library and the list (the same cmdlet T16 uses for its library).
    $lib = Find-ByFolder $LibFolder
    if ($lib) { $skip.library++ } else { Write-Host ('  Making the library ' + $LibTitle + ' ...'); $null = New-PnPList -Title $LibTitle -Template DocumentLibrary -Url $LibFolder -ErrorAction Stop; $made.library++; $lib = Find-ByFolder $LibFolder }
    Add-Item 'm1-library' $(if ($lib) { 'PASS' } else { 'FAIL' }) $(if ($lib) { 'library there (made=' + $made.library + ')' } else { 'library not on the site after the create step' })
    $lst = Find-ByFolder $ListFolder
    if ($lst) { $skip.list++ } else { Write-Host ('  Making the list ' + $ListTitle + ' ...'); $null = New-PnPList -Title $ListTitle -Template GenericList -Url ('Lists/' + $ListFolder) -ErrorAction Stop; $made.list++; $lst = Find-ByFolder $ListFolder }
    Add-Item 'm2-list' $(if ($lst) { 'PASS' } else { 'FAIL' }) $(if ($lst) { 'list there (made=' + $made.list + ')' } else { 'list not on the site after the create step' })
    if (-not $lib -or -not $lst) { throw 'LIST or library missing after the create step; nothing more was done.' }

    # m3: columns (internal name = display name).
    $want = @(
      @{ List = $lst; Name = 'ProbeTest'; Type = 'Text' }, @{ List = $lst; Name = 'ProbeWay'; Type = 'Text' },
      @{ List = $lst; Name = 'ProbeResult'; Type = 'Text' }, @{ List = $lst; Name = 'ProbeDetail'; Type = 'Note' })
    $have = @{}
    foreach ($l in @($lst)) { $have[[string]$l.Id] = @(Get-RestValue ("_api/web/lists(guid'" + $l.Id + "')/fields?" + '$select=InternalName&$top=2000') | ForEach-Object { [string]$_.InternalName }) }
    $bad = 0
    foreach ($c in $want) {
      if ($have[[string]$c.List.Id] -contains $c.Name) { $skip.columns++; continue }
      $extra = $(if ($c.Type -eq 'Note') { ' RichText="FALSE" NumLines="6"' } else { '' })
      $xml = '<Field Name="' + $c.Name + '" StaticName="' + $c.Name + '" DisplayName="' + $c.Name + '" Required="FALSE" Type="' + $c.Type + '"' + $extra + '></Field>'
      $body = @{ parameters = @{ __metadata = @{ type = 'SP.XmlSchemaFieldCreationInformation' }; SchemaXml = $xml; Options = 24 } } | ConvertTo-Json -Depth 20 -Compress
      try { $null = Invoke-Rest 'Post' ("_api/web/lists(guid'" + $c.List.Id + "')/fields/createfieldasxml") $body; $made.columns++ } catch { $bad++ }
    }
    Add-Item 'm3-columns' $(if ($bad -eq 0) { 'PASS' } else { 'FAIL' }) ('columns made=' + $made.columns + ' already there=' + $skip.columns + ' refused=' + $bad)

    # m4: the list's own permissions: the site's copied, then Contribute for the associated Visitors group on this list only.
    $lst = Find-ByFolder $ListFolder
    $lbase = "_api/web/lists(guid'" + $lst.Id + "')"
    if (-not $lst.HasUniqueRoleAssignments) {
      $null = Invoke-Rest 'Post' ($lbase + '/breakroleinheritance(copyRoleAssignments=true,clearSubscopes=true)') '{}'
      $made.permissions++
    }
    $visitorId = 0
    try { $visitorId = [int]((Invoke-Rest 'Get' '_api/web/associatedvisitorgroup?$select=Id' '') | ConvertFrom-Json).Id } catch { $visitorId = 0 }
    if ($visitorId -le 0) {
      $lines.Add('NOTE m4: no associated Visitors group on this site, so Contribute was not added; the T4 test needs a Visitors group')
      Add-Item 'm4-permissions' 'PASS' ('own permissions on the list (copied now=' + $made.permissions + '); Visitors group not found')
    } else {
      $contribute = 0
      try { $contribute = [int](Get-RestValue '_api/web/roledefinitions?$filter=RoleTypeKind%20eq%203&$select=Id')[0].Id } catch { $contribute = 0 }
      if ($contribute -le 0) { throw 'ROLE Contribute not found on the site.' }
      $has = $false
      try { $has = @(Get-RestValue ($lbase + '/roleassignments/getbyprincipalid(' + $visitorId + ')/roledefinitionbindings?$select=Id') | Where-Object { [int]$_.Id -eq $contribute }).Count -gt 0 } catch { $has = $false }
      if (-not $has) { $null = Invoke-Rest 'Post' ($lbase + '/roleassignments/addroleassignment(principalid=' + $visitorId + ',roledefid=' + $contribute + ')') '{}'; $made.permissions++ }
      Add-Item 'm4-permissions' 'PASS' ('own permissions on the list, Visitors group has Contribute (changes now=' + $made.permissions + ')')
    }

    # m5: the two fake workbooks are written from the text blocks in this script (the repo holds no .xlsx or .xlsm: the personal-data
    # scan cannot read a binary file), then uploaded.
    $wrote = 0
    foreach ($w in @(@($BookName, $FakeBookBase64), @($MacroName, $FakeMacroBase64))) {
      $bytes = [Convert]::FromBase64String((([string]$w[1] -split '\s+') -join ''))
      $path = Join-Path $dir $w[0]
      $same = $false
      if (Test-Path -LiteralPath $path -PathType Leaf) { $cur = [IO.File]::ReadAllBytes($path); $same = ($cur.Length -eq $bytes.Length) -and ([Convert]::ToBase64String($cur) -eq [Convert]::ToBase64String($bytes)) }
      if (-not $same) { [IO.File]::WriteAllBytes($path, $bytes); $wrote++ }
    }
    $lines.Add('ITEM m5a-workbooks INFO fake workbooks saved to the T21 folder now=' + $wrote)
    $inLib = @(Get-RestValue ("_api/web/lists(guid'" + $lib.Id + "')/rootfolder/files?" + '$select=Name&$top=500') | ForEach-Object { [string]$_.Name })
    foreach ($n in $BookName, $MacroName) {
      if ($inLib -contains $n) { $skip.files++; continue }
      $null = Add-PnPFile -Path (Join-Path $dir $n) -Folder $LibFolder -ErrorAction Stop
      $made.files++
    }
    $inLib = @(Get-RestValue ("_api/web/lists(guid'" + $lib.Id + "')/rootfolder/files?" + '$select=Name&$top=500') | ForEach-Object { [string]$_.Name })
    $ok = ($inLib -contains $BookName) -and ($inLib -contains $MacroName)
    Add-Item 'm5-files' $(if ($ok) { 'PASS' } else { 'FAIL' }) ('files in the library: both workbooks there=' + $(if ($ok) { 'yes' } else { 'no' }) + ' (uploaded now=' + $made.files + ')')
    # m6: the test page (it holds the site address: it stays in the T21 folder).
    $n = Write-LinksPage $dir $site
    Add-Item 'm6-page' 'PASS' ('test page in the T21 folder, links=' + $n)
    $lines.Add('MADE library=' + $made.library + ' list=' + $made.list + ' columns=' + $made.columns + ' permission changes=' + $made.permissions + ' files=' + $made.files)
    $lines.Add('SKIPPED (already there) library=' + $skip.library + ' list=' + $skip.list + ' columns=' + $skip.columns + ' files=' + $skip.files)
  }
  elseif ($Part -eq 'Person') {
    # T4 retry (PFM 17 Nov 26): the second person is added to the Visitors group with your sign-in, and removed again by Clean.
    # The address is read into $personAddr, used in the next calls and cleared; it is never written, printed or saved.
    $lst = Find-ByFolder $ListFolder
    if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
    $visitorId = 0
    try { $visitorId = [int]((Invoke-Rest 'Get' '_api/web/associatedvisitorgroup?$select=Id' '') | ConvertFrom-Json).Id } catch { $visitorId = 0 }
    $state = 'no'; $why = ''
    if ($visitorId -le 0) { Add-Item 'p1-group' 'FAIL' 'the site has no Visitors group'; $why = 'the site has no Visitors group' }
    else {
      Add-Item 'p1-group' 'PASS' 'the site has a Visitors group'
      $personAddr = Read-PersonAddress
      $addrOk = ($personAddr -match '^[^@\s]+@[^@\s]+\.[^@\s]+$')
      if (-not $addrOk) { Add-Item 'p2-person' 'FAIL' 'no valid address was given in the window'; $why = 'no valid address was given' }
      else {
        $userId = 0; $loginName = ''
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
        if ($userId -le 0) { Add-Item 'p2-person' 'FAIL' 'the person was not found on this site'; $why = 'the person was not found on this site' }
        else {
          Add-Item 'p2-person' 'PASS' 'the person was found on this site (the site user number is saved in the state file, no address and no name)'
          $members = Get-GroupMemberId $visitorId
          $was = $members -contains $userId
          # The numbers are saved before the change, so Clean can find the person even if this part stops half way.
          Set-Content -LiteralPath (Join-Path $dir $StateName) -Value @(('UserId=' + $userId), ('GroupId=' + $visitorId), ('WasMember=' + $(if ($was) { 'yes' } else { 'no' }))) -Encoding ASCII
          if ($was) { $state = 'was'; $why = 'the person was already a member and stays one' }
          else {
            try {
              Add-PnPGroupMember -LoginName $loginName -Group $visitorId -ErrorAction Stop
              if ((Get-GroupMemberId $visitorId) -contains $userId) { $state = 'yes' } else { $why = 'the group does not list the person after the add' }
            } catch { $why = 'the add was refused: ' + (Format-Detail ([string]$_.Exception.Message)) }
          }
          Add-Item 'p3-visitors' $(if ($state -eq 'yes' -or $state -eq 'was') { 'PASS' } else { 'FAIL' }) ('person in the Visitors group=' + $(if ($state -eq 'no') { 'no' } else { 'yes' }) + $(if ($why) { ' (' + $why + ')' } else { '' }))
        }
      }
      $personAddr = $null; $loginName = $null; $raw = $null
    }
    $lines.Add('VISITORS added to Visitors: ' + $(if ($state -eq 'yes') { 'yes' } else { 'no' }) + '; status: ' + $(if ($state -eq 'yes') { 'added and listed in the group' } elseif ($state -eq 'was') { 'already a member (Clean leaves the person in the group)' } else { $why }))
    $clip = 'no'
    if ($NoLaunch) { $clip = 'no (test run)' } else { try { Set-Clipboard -Value ($site.TrimEnd('/') + '/Lists/' + $ListFolder + '/NewForm.aspx'); $clip = 'yes' } catch { $clip = 'no' } }
    $lines.Add('ITEM p4-link INFO the link of the new row form is on the clipboard=' + $clip)
  }
  elseif ($Part -eq 'Run') {
    $lst = Find-ByFolder $ListFolder
    if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
    $tag = 'R27' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $null = Add-PnPListItem -List $ListTitle -Values @{ Title = ('RUN-HEALTH ' + $tag) } -ErrorAction Stop
    Add-Item 'r1-command' 'INFO' ('command row made: RUN-HEALTH, tag ' + $tag + '; the health flow answers within a few minutes (the Read part waits for it)')
  }
  elseif ($Part -eq 'Look') {
    $lst = Find-ByFolder $ListFolder
    if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
    $lbase = "_api/web/lists(guid'" + $lst.Id + "')"

    # a: the header of the list form (the form formatting of the content type).
    $ctId = ''
    try { $cts = @(Get-RestValue ($lbase + '/contenttypes?$select=Id,Name')); if ($cts.Count) { $ctId = [string]$cts[0].Id.StringValue } } catch { $ctId = '' }
    $formPass = $false; $route = 'none'; $readBack = 'no'
    if (-not $ctId) { Add-Item 'l1-form' 'FAIL' 'no content type found on the list' }
    else {
      $hdr = [ordered]@{ headerJSONFormatter = [ordered]@{ elmType = 'div'; style = [ordered]@{ padding = '12px'; 'font-size' = '18px'; 'font-weight' = '600' }; txtContent = $HeaderText } }
      $route = Send-Formatter 'form' ($hdr | ConvertTo-Json -Depth 8 -Compress) ([string]$lst.Id) $ctId
      try {
        $raw = Invoke-Rest 'Get' ($lbase + "/contenttypes('" + $ctId + "')?" + '$select=ClientFormCustomFormatter') ''
        if ($raw.Contains($HeaderText)) { $readBack = 'yes' }
      } catch { $readBack = 'not read' }
      $formPass = ($readBack -eq 'yes')
      Add-Item 'l1-form' $(if ($formPass) { 'PASS' } else { 'FAIL' }) ('header formatting set (route=' + $route + ') and read back from the content type=' + $readBack + $(if ($route -eq 'none') { '; ' + (Format-Detail $script:fmtError) } else { '' }))
    }
    Add-Test 'FORM' @('a header on the list form (form formatting set by script)=' + $(if ($formPass) { 'PASS' } else { 'FAIL' }) + ' (route=' + $route + '; read back=' + $readBack + '); what the form shows is left to your answers') $formPass

    # b: a view with a button that starts the button flow (customRowAction executeFlow with the flow's ID).
    $viewId = ''
    try { $vs = @(Get-RestValue ($lbase + '/views?$select=Id,Title') | Where-Object { [string]$_.Title -eq $ViewTitle }); if ($vs.Count) { $viewId = [string]$vs[0].Id } } catch { $viewId = '' }
    $viewMade = 0
    if (-not $viewId) {
      Write-Host ('  Making the view ' + $ViewTitle + ' ...')
      $null = Add-PnPView -List $ListTitle -Title $ViewTitle -Fields @('Title', 'ProbeTest', 'ProbeResult') -ErrorAction Stop
      $viewMade++
      $vs = @(Get-RestValue ($lbase + '/views?$select=Id,Title') | Where-Object { [string]$_.Title -eq $ViewTitle }); if ($vs.Count) { $viewId = [string]$vs[0].Id }
    }
    $viewPass = $false; $vroute = 'none'; $vback = 'no'
    if (-not $viewId) { Add-Item 'l2-view' 'FAIL' 'the view is not on the list after the create step' }
    else {
      $params = '{"id":"' + $ButtonFlowId + '","headerText":"Run the test flow","runFlowButtonText":"Run"}'
      $fmt = [ordered]@{ '$schema' = 'https://developer.microsoft.com/json-schemas/sp/view-formatting.schema.json'
        rowFormatter = [ordered]@{ elmType = 'div'; style = [ordered]@{ display = 'flex'; 'align-items' = 'center'; padding = '4px' }
          children = @([ordered]@{ elmType = 'span'; style = [ordered]@{ flex = '1' }; txtContent = '[$Title]' },
            [ordered]@{ elmType = 'button'; txtContent = 'Run the test flow'; customRowAction = [ordered]@{ action = 'executeFlow'; actionParams = $params } }) } }
      $vroute = Send-Formatter 'view' ($fmt | ConvertTo-Json -Depth 10 -Compress) ([string]$lst.Id) $viewId
      try {
        $raw = Invoke-Rest 'Get' ($lbase + "/views(guid'" + $viewId + "')?" + '$select=CustomFormatter') ''
        if ($raw.Contains('executeFlow') -and $raw.Contains($ButtonFlowId)) { $vback = 'yes' }
      } catch { $vback = 'not read' }
      $viewPass = ($vback -eq 'yes')
      Add-Item 'l2-view' $(if ($viewPass) { 'PASS' } else { 'FAIL' }) ('view made now=' + $viewMade + '; formatting set (route=' + $vroute + ') and read back from the view=' + $vback + $(if ($vroute -eq 'none') { '; ' + (Format-Detail $script:fmtError) } else { '' }))
    }
    Add-Test 'VIEW' @('b a view formatted by script with a button that starts a flow=' + $(if ($viewPass) { 'PASS' } else { 'FAIL' }) + ' (route=' + $vroute + '; read back=' + $vback + '; flow ID known to the script=yes); whether the button runs is read by the Read part') $viewPass
  }
  elseif ($Part -eq 'Read') {
    $lst = Find-ByFolder $ListFolder
    if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
    $rf = @('Title', 'ProbeTest', 'ProbeWay', 'ProbeResult', 'ProbeDetail', 'Author')
    $rows = @(Get-ListRow $ListTitle $rf)
    # The health flow answers a minute or more after its command row. Wait for it (default 4 minutes) only when there is one.
    $healthFloor = [int](@($rows | Where-Object { $_.Title -like 'RUN-HEALTH *' } | ForEach-Object { $_.Id }) + 0 | Measure-Object -Maximum).Maximum
    if ($healthFloor -gt 0) {
      $ok = Wait-Until {
        $rows = @(Get-ListRow $ListTitle $rf)
        [bool](Find-Result @($rows | Where-Object { $_.Id -gt $healthFloor }) 'HEALTH' 'a') } 'the health flow''s result row'
      $rows = @(Get-ListRow $ListTitle $rf)
      $lines.Add('WAIT health row ' + $(if ($ok) { 'there' } else { 'not there (time ran out)' }))
    } else { $lines.Add('WAIT none: no RUN-HEALTH row on the list') }
    $meId = 0
    try { $meId = [int]((Invoke-Rest 'Get' '_api/web/currentuser?$select=Id' '') | ConvertFrom-Json).Id } catch { $meId = 0 }

    # HEALTH: the Power Automate Management connector lists the owner's own flows (this environment only) and reads each probe flow's last run.
    $h = $null
    if ($healthFloor -gt 0) { $h = Find-Result @($rows | Where-Object { $_.Id -gt $healthFloor }) 'HEALTH' 'a' }
    if (-not $healthFloor) { Add-Test 'HEALTH' @('a Power Automate Management connector, own flows only=FAIL (no command row: run the health step first)') $false }
    elseif (-not $h) { Add-Test 'HEALTH' @('a Power Automate Management connector, own flows only=FAIL (no result row after the wait: the flow did not run; if the import refused the connector or asked for a Premium licence, the import answer says so)') $false }
    else {
      $d = Format-Detail $h.ProbeDetail
      Add-Test 'HEALTH' @('a Power Automate Management connector, own flows only=' + $h.ProbeResult + $(if ($d) { ' (' + $d + ')' } else { '' })) ($h.ProbeResult -eq 'PASS')
    }

    # T4: a person who is a Visitors member writes a row through the list form (Contribute on this list only).
    $others = @($rows | Where-Object { $_.Title -ne 'RESULT' -and $meId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $meId })
    $t4a = @($rows | Where-Object { ([string]$_.Title).Trim() -eq 'T4a' -and $meId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $meId })
    $st = Read-State $dir
    $addedText = $(if (-not $st) { 'not tried (no state file)' } elseif ($st['WasMember'] -eq 'yes') { 'already a member' } else { 'yes' })
    $t4pass = ($others.Count -ge 1)
    $t4 = @('a list form by a second person (Visitors member)=' + $(if ($t4pass) { 'PASS' } else { 'FAIL' }) + ' (rows=' + $others.Count + '; T4a rows=' + $t4a.Count + '; person in the Visitors group=' + $addedText + ')')
    if (-not $t4pass) { $t4 += 'next: way C: a flow writes the row with the PFM''s connection (not built)' }
    Add-Test 'T4' $t4 $t4pass

    # BUTTON: the view button started the button flow (its RESULT row says it ran).
    $btn = @($rows | Where-Object { $_.Title -eq 'RESULT' -and $_.ProbeTest -eq 'BTN' })
    $bd = $(if ($btn.Count) { Format-Detail (@($btn | Sort-Object { $_.Id } -Descending)[0].ProbeDetail) } else { '' })
    Add-Test 'BUTTON' @('b a view button starts a flow=' + $(if ($btn.Count) { 'PASS' } else { 'FAIL' }) + ' (result rows=' + $btn.Count + $(if ($bd) { '; ' + $bd } else { '' }) + ')') ($btn.Count -ge 1)
    $lines.Add('NOTE FORM, VIEW and EXCEL: what the screen showed is left to the answers you give in the RADE window (this script does not read them)')
  }
  else {
    # Clean: runs each step on its own, even if an earlier one failed. First the person, then the two objects (found by their
    # folder name), to the site Recycle Bin. The person is found by the saved numbers in the state file.
    $state = Read-State $dir
    if (-not $state) { Add-Item 'c1-person' 'PASS' 'no second person on file (nothing to remove)' }
    elseif ($state['WasMember'] -eq 'yes') {
      Add-Item 'c1-person' 'PASS' 'the second person was a Visitors member before the test, so the person stays (state file deleted)'
      try { Remove-Item -LiteralPath (Join-Path $dir $StateName) -ErrorAction Stop } catch { $null = $_ }
    } else {
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
        Add-Item 'c1-person' $(if (-not $still) { 'PASS' } else { 'FAIL' }) $(if (-not $still) { 'the second person is not in the Visitors group (state file deleted)' } else { 'the second person is still in the Visitors group (state file kept; run Clean again)' })
        if (-not $still) { Remove-Item -LiteralPath (Join-Path $dir $StateName) -ErrorAction Stop }
      } catch { Add-Item 'c1-person' 'FAIL' ('the second person could not be removed: ' + (Format-Detail ([string]$_.Exception.Message)) + ' (state file kept; run Clean again)') }
    }
    foreach ($o in @(@('c2-list', $ListTitle, $ListFolder), @('c3-library', $LibTitle, $LibFolder))) {
      try {
        $x = Find-ByFolder $o[2]
        if (-not $x) { Add-Item $o[0] 'PASS' ('"' + $o[1] + '" was not on the site (nothing to remove)'); continue }
        Remove-PnPList -Identity ([string]$x.Id) -Recycle -Force -ErrorAction Stop
        $still = Find-ByFolder $o[2]
        Add-Item $o[0] $(if (-not $still) { 'PASS' } else { 'FAIL' }) ('"' + $o[1] + '" ' + $(if (-not $still) { 'moved to the site Recycle Bin (restorable for 93 days)' } else { 'is still on the site' }))
      } catch { Add-Item $o[0] 'FAIL' ('"' + $o[1] + '" could not be removed: ' + (Format-Detail ([string]$_.Exception.Message)) + ' (run Clean again)') }
    }
    $lines.Add('NOTE by hand: delete the solution "90-161.Z probe" (Power Automate, Solutions). This script does not touch it')
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
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir -and $Part -and $Part -ne 'Open') { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T21-probe-' + $Part.ToLowerInvariant() + '-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
