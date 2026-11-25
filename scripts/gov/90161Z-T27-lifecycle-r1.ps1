<#
.SYNOPSIS
  90-161.Z Task 27 r1 (round R43; the PFM, 25 Nov 26: RADE Uninstall, install from zero, 1 fake publication through 1 process step
  (a move from step 1 to step 2; see the module check); test site only): the Uninstall steps of the app 90-161.Z, and the read-only checks and the process step that follow
  them. Windows PowerShell 5.1 (also 7), the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  Parts (-Part). The first 3 run in RADE's Uninstall mode (RADE engine-v40: a Back up first, then these steps). The lists are removed
  BY THEIR FIXED TITLES (the PFM, 25 Nov 26: the 12 lists of the test site were made before RADE installs, so RADE has no record of them):
  the own-name table of the module 90161Z-T27-made-r1.ps1, whether or not RADE_MADE names them. The group and the level are different
  (the PFM, 25 Nov 26): a group cannot go to a Recycle Bin, so its removal cannot be undone; they go only when RADE_MADE names them.
  Never a list, group or level whose name is not in that table. The other gates stay: RADE_MODE=uninstall, a made list (RADE_MADE) of schema
  rade-made/1 for the app 90-161.Z, the app name and the own-name table. They print one ITEM line for each thing (PASS removed, SKIP
  nothing left, FAIL) and one RESULT line (PASS, SKIP or FAIL). A second run finds nothing left and prints SKIP. Without RADE_MODE=uninstall
  and a made list of schema rade-made/1 for 90-161.Z they remove nothing and print FAIL.
    Lists   Removes each of the 12 lists of 90-161.Z to the site Recycle Bin (restorable for 93 days). A list is removed only when its
            folder name is its internal name AND its title is its fixed title (or, for a list that a stopped install left, its internal
            name): a list that a person made and titled like ours, and a list of ours that a person retitled, stay and print SKIP. A list
            that other lists point to is removed after the lists that point to it.
    Access  Removes the group PFM Office and the permission level PFM Office Edit All Items, each one only when RADE_MADE names it (the
            install made it). A group or level that RADE_MADE does not name stays and prints SKIP "not made by the install" (T20 makes
            each one only when the site has none, so one that was there before the install is not ours to remove).
    Local   Removes the install note file of this computer (T22 folder), only when the made list names it (a file is not covered by
            the decision of 25 Nov 26). RADE keeps its own install record and marks it uninstalled; this script never touches that record.
  The read-only checks and the step (a round step; they need no made list). Module: 90161Z-T27-check-r1.ps1.
    Gone    After Uninstall: none of the 12 lists is on the site.
    Install After the install from zero: the 12 lists are on the site, and the process steps the next part needs are in PFM Process Steps.
    Step    1 fake publication (made by T26 Make) moves from step 1 (Request, DAFMAN 90-161 3.1) to step 2 (Drafting with SMEs, 3.2), and
            the move is read back, but only when the exit conditions of step 1 that the lists can show hold on it
            (checked before and after the move; the list and the sources are in the module header).
  WHAT IT CHANGES ON THE SITE: Lists, Access: the removals above. Step: 1 field (the process step) of the fake publication of T26.
  Gone and Install change nothing. Local: 1 file on this computer.
  Counts, list names of this product and status words only: no names, addresses or row text. The site address stays in
  Config\90161Z-site.txt on this computer; every output line shows it as <SITE> and the DODID as <DODID>.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell (none for Local).
  Writes: on the site, the above; on this computer the T27 folder (the result file) and, for Local, 1 note file in the T22 folder.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Output: 90161Z-T27-<part>[-<label>]-r1.txt in the T27 folder. Last line: LIFECYCLE <part> done: passed=<n> skipped=<n> failed=<n>.
  Exit 1 when a part has a FAIL item or could not run (sign-in, missing list or module, made list not accepted).
  Run: powershell.exe -NoProfile -File 90161Z-T27-lifecycle-r1.ps1 -Part <part> (RADE does this).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Part
  Lists, Access or Local (Uninstall mode); Gone, Install or Step (round steps).
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T27 folder (its parent holds the T22 and T26 folders of the test).
.PARAMETER Label
  A word (lower-case letters) for the result file name, so a part that runs twice in a round keeps both files: Install with the label
  before writes 90161Z-T27-install-before-r1.txt.
#>
param([string]$Id, [Parameter(Mandatory = $true)][ValidateSet('Lists', 'Access', 'Local', 'Gone', 'Install', 'Step')][string]$Part,
  [switch]$NoPause, [string]$TestDir, [ValidatePattern('^[a-z]{0,12}$')][string]$Label = '')
$task = 'T27'
$Rev = 'r1'

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

$lines = New-Object System.Collections.Generic.List[string]
$script:passed = 0; $script:failed = 0; $script:skipped = 0
# Adds one "ITEM <name> <status> <text>" line and counts a PASS, a SKIP or a FAIL.
function Add-Item([string]$Name, [string]$Status, [string]$Text) {
  $lines.Add('ITEM ' + $Name + ' ' + $Status + ' ' + $Text)
  if ($Status -eq 'PASS') { $script:passed++ } elseif ($Status -eq 'FAIL') { $script:failed++ } elseif ($Status -eq 'SKIP') { $script:skipped++ }
}
# Adds the one RESULT line of an Uninstall part: FAIL when an item failed, else PASS when something was removed, else SKIP.
function Add-UninstallResult([int]$Removed) {
  $word = $(if ($script:failed) { 'FAIL' } elseif ($Removed) { 'PASS' } else { 'SKIP' })
  $lines.Add('RESULT UNINSTALL ' + $Part.ToUpperInvariant() + ' ' + $word + ' removed=' + $Removed)
}
# Loads the newest installed PnP.PowerShell; stops with a plain message when it is not installed.
function Import-PnPNewest {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
}
# Signs in to the one site with the web login (CAC), after the module is loaded.
function Connect-LifecycleSite {
  Import-PnPNewest
  Write-Host 'NOW Signing in to the site (if a sign-in window opens, sign in with your CAC)'
  $null = & { Connect-PnPOnline -Url $script:site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
}
# Cuts an error message to 120 characters, so no long site text reaches a line.
function Get-ShortError($ErrorRecord) { $m = [string]$ErrorRecord.Exception.Message; return $m.Substring(0, [Math]::Min(120, $m.Length)) }
<#
.SYNOPSIS
  The part Lists: removes each of the 12 lists of 90-161.Z by its fixed title (the own-name table), to the site Recycle Bin, whether or
  not the made list names it, and reads each back. A list is removed only when its folder name is its internal name AND its title is
  its fixed title; any other list stays.
.PARAMETER Made
  The result of Read-MadeFile (accepted). It only adds NOTE lines here: a list name in it that is not one of the 12 is refused.
#>
function Invoke-ListsPart($Made) {
  foreach ($n in (Get-MadeName $Made.Items 'list')) {
    if (-not (Resolve-OwnList $n)) { $lines.Add('NOTE refused: a list in the made list is not one of the 12 lists of 90-161.Z (not removed)') }
  }
  Connect-LifecycleSite
  Write-Host 'NOW Reading the lists of the site'
  $siteLists = Get-SiteList
  $removed = @(); $n = 0
  foreach ($k in $OwnLists.Keys) {
    $n++; $tag = 'l' + $n.ToString('00') + '-' + $k
    $l = Find-OwnListToRemove $siteLists $k
    if (-not $l) { Add-Item $tag 'SKIP' (Get-ListLeftReason $siteLists $k); continue }
    try {
      Write-Host ('NOW Removing the list ' + $OwnLists[$k])
      $null = Remove-PnPList -Identity ([string]$l.Id) -Recycle -Force -ErrorAction Stop
      $removed += $k
    } catch { Add-Item $tag 'FAIL' ('the list could not be removed: ' + (Get-ShortError $_) + ' (run this step again)') }
  }
  $after = @(Get-SiteList)
  foreach ($k in $removed) {
    $tag = 'r-' + $k
    if (Find-OwnListToRemove $after $k) { Add-Item $tag 'FAIL' 'the list is still on the site after the remove (run this step again)' }
    else { Add-Item $tag 'PASS' ('the list is removed (moved to the site Recycle Bin): ' + $OwnLists[$k]) }
  }
  Add-UninstallResult $removed.Count
}
<#
.SYNOPSIS
  The part Access: removes the group PFM Office, then the permission level PFM Office Edit All Items, each only when the made list names
  it (the install made it; a group cannot go to a Recycle Bin). A name that is not named stays and prints SKIP. No other group and no
  other level is ever removed.
.PARAMETER Made
  The result of Read-MadeFile (accepted). A group or level name in it that is not ours is refused (NOTE) and never removed.
#>
function Invoke-AccessPart($Made) {
  foreach ($n in (Get-MadeName $Made.Items 'group')) {
    if (-not (Test-OwnName 'group' $n)) { $lines.Add('NOTE refused: a group in the made list is not the group of 90-161.Z (not removed)') }
  }
  foreach ($n in (Get-MadeName $Made.Items 'level')) {
    if (-not (Test-OwnName 'level' $n)) { $lines.Add('NOTE refused: a level in the made list is not the level of 90-161.Z (not removed)') }
  }
  $madeGroup = @(Get-MadeName $Made.Items 'group') -ccontains $OwnGroup
  $madeLevel = @(Get-MadeName $Made.Items 'level') -ccontains $OwnLevel
  Connect-LifecycleSite
  $removed = Invoke-OwnAccessRemoval 'a1-group' $OwnGroup $madeGroup { Get-GroupId $OwnGroup } { Remove-PnPGroup -Identity $OwnGroup -Force -ErrorAction Stop }
  $removed += Invoke-OwnAccessRemoval 'a2-level' $OwnLevel $madeLevel { Get-OwnLevelId } { Remove-PnPRoleDefinition -Identity $OwnLevel -Force -ErrorAction Stop }
  Add-UninstallResult $removed
}
# The number of the permission level PFM Office Edit All Items on the site, or 0 when it is not there.
function Get-OwnLevelId { $v = Get-RoleLevel $OwnLevel 0; if ($v) { return [int]$v.Id }; return 0 }
<#
.SYNOPSIS
  Removes one named thing of the site (the group or the level) when the made list names it and it is there, and reads it back.
.PARAMETER Tag
  The item name for the result line.
.PARAMETER Name
  The name of the thing (it is one of the 2 fixed names of the module; the caller checked it).
.PARAMETER Named
  Whether the made list names the thing (the install made it). When it does not, nothing is removed and the item is a SKIP.
.PARAMETER Find
  A script block that returns the number of the thing, or 0 when it is not on the site.
.PARAMETER Remove
  A script block that removes it.
.OUTPUTS
  System.Int32. 1 when it was removed and read back, else 0.
#>
function Invoke-OwnAccessRemoval([string]$Tag, [string]$Name, [bool]$Named, [scriptblock]$Find, [scriptblock]$Remove) {
  if (-not $Named) { Add-Item $Tag 'SKIP' ('not made by the install: ' + $Name + ' stays'); return 0 }
  if (-not (& $Find)) { Add-Item $Tag 'SKIP' ('not on the site: nothing left to remove: ' + $Name); return 0 }
  try { Write-Host ('NOW Removing ' + $Name); $null = & $Remove }
  catch { Add-Item $Tag 'FAIL' ('could not be removed: ' + (Get-ShortError $_) + ' (run this step again)'); return 0 }
  if (& $Find) { Add-Item $Tag 'FAIL' ('still on the site after the remove: ' + $Name + ' (run this step again)'); return 0 }
  Add-Item $Tag 'PASS' ('removed: ' + $Name)
  return 1
}
<#
.SYNOPSIS
  The part Local: removes the install note file (T22 folder) when the made list names it. Not the RADE install record.
.PARAMETER Made
  The result of Read-MadeFile (accepted).
.PARAMETER Dir
  The T27 folder; the T22 folder is its neighbor.
#>
function Invoke-LocalPart($Made, [string]$Dir) {
  $names = @(Get-MadeName $Made.Items 'file')
  if (-not $names.Count) { Add-Item 'f00-note' 'SKIP' 'no file is named in the made list: nothing to remove'; Add-UninstallResult 0; return }
  $removed = 0; $n = 0
  foreach ($name in $names) {
    $n++; $tag = 'f' + $n.ToString('00') + '-note'
    # Only the install note, only by its plain file name: a path, or any other file name, is refused.
    if (-not (Test-OwnName 'file' $name)) { $lines.Add('NOTE refused: a file in the made list is not the install note of 90-161.Z (not removed)'); continue }
    $path = Join-Path (Join-Path (Split-Path -Parent $Dir) 'T22') $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Item $tag 'SKIP' 'the install note is not on this computer: nothing left to remove'; continue }
    try { Remove-Item -LiteralPath $path -ErrorAction Stop } catch { Add-Item $tag 'FAIL' ('the install note could not be removed: ' + (Get-ShortError $_)); continue }
    if (Test-Path -LiteralPath $path) { Add-Item $tag 'FAIL' 'the install note is still there after the remove'; continue }
    Add-Item $tag 'PASS' 'the install note is removed'; $removed++
  }
  Add-UninstallResult $removed
}

$fatal = $false; $site = ''; $secret = @(); $dir = ''
try {
  $ErrorActionPreference = 'Stop'
  # The modules are dot-sourced here, in this script's scope, so they see the values and helpers above (the T20 helpers give
  # Get-SiteList, Find-OurList, Get-GroupId and Get-RoleLevel; RADE saves them in this folder too).
  foreach ($m in '90161Z-T27-made-r1.ps1', '90161Z-T27-check-r1.ps1', '90161Z-T20-helpers-r4.ps1') {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $m) -PathType Leaf)) { throw ('MODULE missing: ' + $m + ' is not in the folder of this script. Run the round again.') }
    . (Join-Path $PSScriptRoot $m)
  }
  $who = Get-TaskId $Id; $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 27' -Create }
  Set-Location -LiteralPath $dir
  $lines.Add('TASK T27 lifecycle ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $uninstall = $Part -in 'Lists', 'Access', 'Local'
  if ($uninstall) {
    # The gate: nothing is removed unless RADE says Uninstall and its made list is accepted.
    $made = Read-MadeFile ([string]$env:RADE_MODE) ([string]$env:RADE_MADE)
    if (-not $made.Ok) { Add-Item 'g-made' 'FAIL' $made.Why; $lines.Add('RESULT UNINSTALL ' + $Part.ToUpperInvariant() + ' FAIL removed=0'); throw 'GATE not passed.' }
    $lines.Add('MADE entries=' + @($made.Items).Count + '; without step, kind or name=' + $made.Dropped)
  }
  if ($Part -ne 'Local') { $script:site = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config') }
  switch ($Part) {
    'Lists' { Invoke-ListsPart $made } 'Access' { Invoke-AccessPart $made } 'Local' { Invoke-LocalPart $made $dir }
    'Gone' { Connect-LifecycleSite; Invoke-GonePart } 'Install' { Connect-LifecycleSite; Invoke-InstallPart }
    default { Connect-LifecycleSite; Invoke-StepPart $dir }
  }
  if ($Part -notin 'Local') { try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ } }
} catch {
  $fatal = $true
  if ($script:site) { $site = $script:site }
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)) + ' (the part can be run again)')
} finally {
  if ($script:site) { $site = $script:site }
  $lines.Add('LIFECYCLE ' + $Part + ' done: passed=' + $script:passed + ' skipped=' + $script:skipped + ' failed=' + $script:failed)
  # Every line is masked once more before it is shown or saved.
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  $resultName = '90161Z-T27-' + $Part.ToLowerInvariant() + $(if ($Label) { '-' + $Label } else { '' }) + '-' + $Rev + '.txt'
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir $resultName) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal -or $script:failed) { exit 1 }
exit 0
