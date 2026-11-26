<#
.SYNOPSIS
  90-161.Z Task 28 r1 (round R44; the PFM, 25 Nov 26: "a read-only list step first"): counts what the app 90-161.Z left on the
  test site, by fixed titles, and writes only counts. Windows PowerShell 5.1 (also 7), the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  WHAT IT COUNTS (fixed titles only; the titles come from the one own-name table of 90161Z-T27-made-r1.ps1, the module that Uninstall uses):
    - each of the 12 PFM lists: on the site (yes or no), its items, and its rows whose Title holds "(delete me)";
    - the group "PFM Office": on the site, and its members (a number; no member name is read);
    - the library "90-161.Z": on the site, and its items;
    - the T21 probe list "90161Z Probe" and the T21 probe library "90161Z Probe Files": on the site, and their items.
  Flows live in Power Automate, not on the site, so this step cannot count them with the site connection alone; it opens no other host
  (Project rule "No reconnaissance") and writes one NOTE line: "flows: not counted from the site".
  WHAT IT WRITES: nothing on the site (it calls no command that adds, changes or removes anything; tests/ps/Test-T28.ps1 checks this on a
  fake site). On this computer one result file in the T28 folder.
  WHAT IT NEVER PRINTS: a member name, a row title, an address. A row's Title is read only to see if it holds "(delete me)"; the number is
  all that goes into the result. Every line is masked once more (the site, the DODID) before it is shown or saved.
  Lines: COUNT <thing> <facts>; NOTE flows: not counted from the site; RESULT COUNT PASS lists=<n of 12> ...; or STOPPED: <why>.
  Last line: COUNT done: counted=<n> failed=<n>. Exit 1 when the step could not run (sign-in, missing module) or a read failed.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell, read only.
  Writes: the result file 90161Z-T28-count-r1.txt in the T28 folder (or -TestDir). Nothing on the site.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Run: powershell.exe -NoProfile -File 90161Z-T28-count-r1.ps1 (RADE does this). Not alone: it loads 90161Z-T27-made-r1.ps1 and
  90161Z-T20-helpers-r4.ps1 from its own folder (the round puts them there).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T28 folder (its parent holds the Config folder of the test).
#>
param([string]$Id, [switch]$NoPause, [string]$TestDir)
$task = 'T28'
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
$script:counted = 0; $script:failed = 0
# The things this step counts besides the 12 lists (fixed titles; tests/ps/Test-T28.ps1 checks the probe titles against the T21 script).
$AppLibrary = '90-161.Z'
$ProbeList = '90161Z Probe'
$ProbeLibrary = '90161Z Probe Files'
$Marker = '(delete me)'   # the words in a fake row's Title that mark it for removal (T24 and T26 make such rows)
$LibraryTemplate = 101    # SharePoint BaseTemplate of a document library

# Adds one "COUNT <text>" line and counts it.
function Add-Count([string]$Text) { $lines.Add('COUNT ' + $Text); $script:counted++ }
<#
.SYNOPSIS
  The lists of the site that have a fixed title (an exact, case sensitive match).
.PARAMETER SiteLists
  The lists of the site (Get-SiteList).
.PARAMETER Title
  The fixed title.
.OUTPUTS
  The lists with that title (0, 1 or more).
#>
function Get-TitledList($SiteLists, [string]$Title) { return @($SiteLists | Where-Object { [string]$_.Title -ceq $Title }) }
<#
.SYNOPSIS
  How many rows of a list have the marker "(delete me)" in their Title. Reads the Title only and keeps no text: only the number leaves.
.PARAMETER Title
  The title of the list.
.OUTPUTS
  System.Int32. The number of marked rows.
#>
function Get-MarkedCount([string]$Title) {
  $n = 0
  foreach ($r in @(Get-PnPListItem -List $Title -Fields 'Title' -PageSize 500 -ErrorAction Stop)) {
    if (([string]$r['Title']).IndexOf($Marker, [StringComparison]::Ordinal) -ge 0) { $n++ }
  }
  return $n
}
<#
.SYNOPSIS
  The number of members of a site group (a count of ids; the names are not read).
.PARAMETER GroupId
  The number of the group.
.OUTPUTS
  System.Int32. The member count.
#>
function Get-MemberCount([int]$GroupId) { return @(Get-RestValue ('_api/web/sitegroups/getbyid(' + $GroupId + ')/users?$select=Id&$top=5000')).Count }
<#
.SYNOPSIS
  Counts one thing that has a fixed title and no rows to scan (the library, the probe list, the probe library): one COUNT line.
.PARAMETER SiteLists
  The lists of the site.
.PARAMETER Kind
  The word in the line: library or list.
.PARAMETER Title
  The fixed title.
.PARAMETER Template
  The SharePoint BaseTemplate that the thing must have (101 for a library), or -1 for a list that is not a library.
.OUTPUTS
  System.Int32. The items found (0 when it is not on the site).
#>
function Add-OneCount($SiteLists, [string]$Kind, [string]$Title, [int]$Template) {
  $hit = @(Get-TitledList $SiteLists $Title | Where-Object { ($Template -ge 0 -and [int]$_.BaseTemplate -eq $Template) -or ($Template -lt 0 -and [int]$_.BaseTemplate -ne $LibraryTemplate) })
  if (-not $hit.Count) { Add-Count ($Kind + ' ' + $Title + ': on the site=no'); return 0 }
  Add-Count ($Kind + ' ' + $Title + ': on the site=yes; with this title=' + $hit.Count + '; items=' + [int]$hit[0].ItemCount)
  return [int]$hit[0].ItemCount
}
<#
.SYNOPSIS
  The whole count: the 12 lists, the group, the library, the probe list and library, the flows NOTE and the RESULT line.
#>
function Invoke-CountPart {
  Write-Host 'NOW Reading the lists of the site'
  $siteLists = Get-SiteList
  $onSite = 0; $items = 0; $marked = 0
  foreach ($k in $OwnLists.Keys) {
    $t = [string]$OwnLists[$k]; $hit = @(Get-TitledList $siteLists $t)
    if (-not $hit.Count) { Add-Count ('list ' + $t + ': on the site=no'); continue }
    $onSite++; $n = [int]$hit[0].ItemCount; $items += $n
    $m = $(if ($n -gt 0) { Write-Host ('NOW Counting the rows of ' + $t); Get-MarkedCount $t } else { 0 }); $marked += $m
    Add-Count ('list ' + $t + ': on the site=yes; with this title=' + $hit.Count + '; items=' + $n + '; rows marked ' + $Marker + '=' + $m)
  }
  Add-Count ('lists of 90-161.Z: on the site=' + $onSite + ' of ' + $OwnLists.Count + '; items in them=' + $items + '; rows marked ' + $Marker + '=' + $marked)
  Write-Host 'NOW Reading the group'
  $gid = Get-GroupId $OwnGroup
  if ($gid) { Add-Count ('group ' + $OwnGroup + ': on the site=yes; members=' + (Get-MemberCount $gid)) } else { Add-Count ('group ' + $OwnGroup + ': on the site=no') }
  $null = Add-OneCount $siteLists 'library' $AppLibrary $LibraryTemplate
  $null = Add-OneCount $siteLists 'probe list' $ProbeList -1
  $null = Add-OneCount $siteLists 'probe library' $ProbeLibrary $LibraryTemplate
  $lines.Add('NOTE flows: not counted from the site')
  $lines.Add('RESULT COUNT PASS lists=' + $onSite + ' of ' + $OwnLists.Count + ' items=' + $items + ' marked=' + $marked)
}

$fatal = $false; $site = ''; $secret = @(); $dir = ''
try {
  $ErrorActionPreference = 'Stop'
  # The modules are dot-sourced here, in this script's scope: the own-name table (the 12 titles, the group) and the SharePoint read helpers.
  foreach ($m in '90161Z-T27-made-r1.ps1', '90161Z-T20-helpers-r4.ps1') {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $m) -PathType Leaf)) { throw ('MODULE missing: ' + $m + ' is not in the folder of this script. Run the round again.') }
    . (Join-Path $PSScriptRoot $m)
  }
  $who = Get-TaskId $Id; $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 28' -Create }
  Set-Location -LiteralPath $dir
  $lines.Add('TASK T28 count ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $script:site = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config')
  # Load the newest installed PnP.PowerShell (a plain stop when none is installed), then sign in to the one site with the web login (CAC).
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'NOW Signing in to the site (if a sign-in window opens, sign in with your CAC)'
  $null = & { Connect-PnPOnline -Url $script:site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
  Invoke-CountPart
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
} catch {
  $fatal = $true; $script:failed++
  if ($script:site) { $site = $script:site }
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)) + ' (the step can be run again)')
} finally {
  if ($script:site) { $site = $script:site }
  $lines.Add('COUNT done: counted=' + $script:counted + ' failed=' + $script:failed)
  # Every line is masked once more before it is shown or saved.
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T28-count-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal -or $script:failed) { exit 1 }
exit 0
