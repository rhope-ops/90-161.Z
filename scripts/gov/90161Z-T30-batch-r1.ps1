<#
.SYNOPSIS
  90-161.Z Task 30 r1 (round R47; the PFM, 26 Nov 26: fewer CAC sign-ins): runs several parts of the task scripts T21, T26 and T27
  in this one process, in the order given, so the parts share one CAC sign-in. Windows PowerShell 5.1 (also 7), the installed
  PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  Why: RADE runs each step in its own powershell.exe, and each step that reads the site signed in again (about 18 sign-ins in R46).
  A batch step runs its parts with the call operator in this process: the first part that needs the site signs in, and each later
  part finds that connection (Get-PnPConnection in its own connect function) and prints "SIGNIN reused" instead of a second sign-in.
  The batch sets KANON_KEEP_SIGNIN=1 while the parts run, so no part signs out; the batch signs out once at its end.
  -Run: the parts, separated by ";", each "<task>:<part>" or "<task>:<part>:<label>", for example
  T21:Clean:first;T21:Make;T21:Person. Only the parts of the table $BatchParts below can run; a task, part or label that is not
  in the table, or a script that is not in its folder, stops the batch before any part runs (no path comes from -Run).
  Each part prints its own lines (the RADE step contract: PASS, FAIL, SKIP, NOW, MADE) and writes its own result file. A part
  that ends with an exit code other than 0 does not stop the parts after it (a clean-up part must still run); the batch then
  ends with exit code 1. In RADE's Uninstall the batch runs with RADE_MODE and RADE_MADE, which the parts read as before.
  Lines of the batch itself: TASK T30 batch r1, <N> parts, <time>; NOW Part <n> of <N>: <task> <part> [<label>]; BATCH part <n> of <N>: <task> <part> [<label>], exit
  code <c>; BATCH done: parts=<N> exit-not-zero=<n>; or STOPPED: <why>. The words of the step contract are not in them.
  Network: the one SharePoint site of the parts (RADE_SITE or Config\90161Z-site.txt), only through the parts it runs.
  Writes: nothing itself; each part writes what its own script header says (site rows or lists, and its result file).
  Credentials: none itself; the first part that needs the site asks for your CAC sign-in (Connect-PnPOnline -UseWebLogin).
  Run: by RADE (powershell.exe -NoProfile -File T30\90161Z-T30-batch-r1.ps1 -Id <DODID> -NoPause -Run <parts>); the part
  scripts are in the task folders T21, T26 and T27 beside the T30 folder.
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer. Passed to each part.
.PARAMETER NoPause
  No "Press Enter to close" at the end. Each part always runs with -NoPause.
.PARAMETER Run
  The parts to run, in order (see the description).
.PARAMETER ScriptRoot
  Test runs only: one folder that holds every part script, instead of the task folders.
.PARAMETER TestRoot
  Test runs only: each part gets -TestDir <TestRoot>\<task> (and T21 and T26 get -NoLaunch).
#>
param([string]$Id, [switch]$NoPause, [Parameter(Mandatory = $true)][string]$Run, [string]$ScriptRoot, [string]$TestRoot)
$task = 'T30'
$Rev = 'r1'
# The parts a batch may run: the task, its folder, its script (the revision of this round's bundle) and the parts of that script
# that sign in to the site. tests/ps/Test-T30.ps1 checks that each script is in scripts/gov and in the R47 bundle.
$BatchParts = @{
  T21 = @{ Dir = 'T21'; File = '90161Z-T21-probe-r14.ps1'; Parts = @('Clean', 'Make', 'Person'); Labels = @('first', 'last'); NoLaunch = $true }
  T26 = @{ Dir = 'T26'; File = '90161Z-T26-endorse-r5.ps1'; Parts = @('Make', 'Rows', 'Read', 'Change', 'Check', 'Clean'); Labels = @('after'); NoLaunch = $true }
  T27 = @{ Dir = 'T27'; File = '90161Z-T27-lifecycle-r3.ps1'; Parts = @('Lists', 'Access', 'Local', 'Gone', 'Install', 'Step'); Labels = @('before', 'after'); NoLaunch = $false }
}
$BatchKeepVar = 'KANON_KEEP_SIGNIN'   # the signal to the parts' connect functions: keep the sign-in for the next part

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
  # The task folder C:\Users\<DODID>\<OneDrive>\RADE\90-161.Z\<Task>: <OneDrive> is the folder name of $env:OneDriveCommercial,
  # else 'OneDrive - United States Air Force' (fleet v2). Until RADE moves the old ...\90-161.Z, that one is used. -Create makes it.
  $odName = if ($env:OneDriveCommercial) { Split-Path -Leaf $env:OneDriveCommercial } else { 'OneDrive - United States Air Force' }; $od = Join-Path (Join-Path 'C:\Users' $Id) $odName
  $app = 'RADE\90-161.Z'
  if (-not (Test-Path -LiteralPath (Join-Path $od $app) -PathType Container) -and (Test-Path -LiteralPath (Join-Path $od '90-161.Z') -PathType Container)) { $app = '90-161.Z' }
  $tail = $odName + '\' + $app + '\' + $Task
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
  $out = & powershell.exe -NoProfile -File (Join-Path $ScriptDir $Step.File) @stepArgs 2>&1
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

<#
.SYNOPSIS
  Reads -Run into the list of parts, and finds each part's script. Throws (before any part runs) on a part that is not in
  $BatchParts or a script that is not there.
.PARAMETER Text
  The value of -Run.
.PARAMETER AppDir
  The app folder that holds the task folders.
.PARAMETER FlatDir
  Test runs only: the value of -ScriptRoot (one folder with every part script), or ''.
.OUTPUTS
  An array of @{ Task; Part; Label; Name (for the lines); File (the full path); Entry (the $BatchParts row) }.
#>
function Get-BatchPlan([string]$Text, [string]$AppDir, [string]$FlatDir) {
  $plan = @()
  foreach ($one in @(([string]$Text).Split(';') | Where-Object { $_.Trim() })) {
    $bits = @($one.Trim().Split(':'))
    if ($bits.Count -lt 2 -or $bits.Count -gt 3) { throw ('PART not valid: "' + $one.Trim() + '" (use <task>:<part> or <task>:<part>:<label>)') }
    $entry = $BatchParts[$bits[0]]
    if (-not $entry -or $entry.Parts -cnotcontains $bits[1]) { throw ('PART not in the batch table: ' + $bits[0] + ':' + $bits[1]) }
    $label = $(if ($bits.Count -eq 3) { $bits[2] } else { '' })
    if ($label -and $entry.Labels -cnotcontains $label) { throw ('LABEL not in the batch table: ' + $one.Trim()) }
    $file = $(if ($FlatDir) { Join-Path $FlatDir $entry.File } else { Join-Path (Join-Path $AppDir $entry.Dir) $entry.File })
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw ('SCRIPT missing: ' + $entry.Dir + '\' + $entry.File + ' is not there. Run the round again.') }
    $plan += @{ Task = $bits[0]; Part = $bits[1]; Label = $label; Name = ($bits[0] + ' ' + $bits[1] + $(if ($label) { ' ' + $label } else { '' })); File = $file; Entry = $entry }
  }
  if (-not $plan.Count) { throw 'PART not given: -Run names no part.' }
  return $plan
}

<#
.SYNOPSIS
  Runs one part of the plan in this process and gives back its exit code. An error that ends the part's script is shown
  (masked) and counts as exit code 1; the next part still runs.
.PARAMETER Step
  One entry of Get-BatchPlan.
.PARAMETER Who
  The Get-TaskId table (the DODID and its masks).
.PARAMETER PartTestRoot
  Test runs only: the value of -TestRoot, or ''.
.OUTPUTS
  The exit code of the part (0 when it ran to its end with no failure).
#>
function Invoke-BatchPart($Step, $Who, [string]$PartTestRoot) {
  $partArgs = @{ Id = $Who.Id; Part = $Step.Part; NoPause = $true }
  if ($Step.Label) { $partArgs.Label = $Step.Label }
  if ($PartTestRoot) { $partArgs.TestDir = Join-Path $PartTestRoot $Step.Entry.Dir; if ($Step.Entry.NoLaunch) { $partArgs.NoLaunch = $true } }
  $global:LASTEXITCODE = 0
  # A line that a part leaves on the output stream goes to the screen too, so this function gives back only the exit code.
  try { & $Step.File @partArgs | ForEach-Object { Write-Host ([string]$_) }; return [int]$LASTEXITCODE }
  catch {
    $why = ConvertTo-Masked (Hide-Site ([string]$_) ([string]$env:RADE_SITE)) $Who.Secret
    Write-Host ('STOPPED: the part ' + $Step.Name + ' did not run to its end: ' + $why.Substring(0, [Math]::Min(300, $why.Length)))
    return 1
  }
}

$batchFatal = $false; $batchBad = 0; $batchPlan = @()
try {
  $batchWho = Get-TaskId $Id
  $batchPlan = @(Get-BatchPlan $Run (Split-Path -Parent $PSScriptRoot) $ScriptRoot)
  Write-Host ('TASK ' + $task + ' batch ' + $Rev + ', ' + $batchPlan.Count + ' parts, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  Set-Item -Path ('Env:' + $BatchKeepVar) -Value '1'
  for ($batchAt = 0; $batchAt -lt $batchPlan.Count; $batchAt++) {
    $batchStep = $batchPlan[$batchAt]; $batchOf = [string]($batchAt + 1) + ' of ' + $batchPlan.Count
    Write-Host ('NOW Part ' + $batchOf + ': ' + $batchStep.Name)
    $batchCode = Invoke-BatchPart $batchStep $batchWho $TestRoot
    if ($batchCode -ne 0) { $batchBad++ }
    Write-Host ('BATCH part ' + $batchOf + ': ' + $batchStep.Name + ', exit code ' + $batchCode)
  }
} catch {
  $batchFatal = $true
  $batchWhy = ConvertTo-Masked (Hide-Site ([string]$_) ([string]$env:RADE_SITE)) $(if ($batchWho) { $batchWho.Secret } else { @() })
  Write-Host ('STOPPED: ' + $batchWhy.Substring(0, [Math]::Min(300, $batchWhy.Length)) + ' (no part ran after this)')
} finally {
  Remove-Item -Path ('Env:' + $BatchKeepVar) -ErrorAction SilentlyContinue
  # The one sign-out of the batch (the parts kept the sign-in); no PnP module loaded means no part signed in.
  if (Get-Command Disconnect-PnPOnline -ErrorAction SilentlyContinue) { try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ } }
  Write-Host ('BATCH done: parts=' + $batchPlan.Count + ' exit-not-zero=' + $batchBad)
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($batchFatal -or $batchBad) { exit 1 }
exit 0
