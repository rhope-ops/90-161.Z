<#
.SYNOPSIS
  90-161.Z Task 20 list provisioning by PnP r2 (round R34; PFM 19 Nov 26, F2 A: the PFM Office level; PFM 14 Nov 26: lists
  by PnP; PFM 15 Nov 26: clean install in R25). Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: builds the 12 PFM lists on a site from the payload the retired T02 r12 flow used
  (provisioning-payload.json, generated from schemas/lists by scripts/build_flow_payload.py): lists, columns, views, seed
  rows, display titles, indexes and "edit own rows". r2 also gives the group PFM Office a permission level that edits every
  row. About 5 minutes (an estimate).
  Modes:
    -PlanOnly  No sign-in, no network. Prints the counts in the payload.
    -Check     Signs in and READS only. Reports what 90-161.Z left on the site (lists, the 90-161.Z library, result files,
               the probe's test group). A clean site passes. Result: 90161Z-T20-clean-check-r2.txt.
    -DryRun    Signs in and READS only. Prints what a run would create.
    (none)     Creates what is missing, then checks every list against the payload. Result: 90161Z-T20-provision-lists-r2.txt.
  WHAT IT CHANGES ON THE SITE (create mode only). It never deletes a list, a column, a view, a row, a group or a level. One
  thing it sets again on every run: the columns shown by its own 18 views (a column that a person added to one of these
  views is taken out again; the list's default view is not touched):
    1. Creates the lists that are missing (12 on a clean site), with versioning on.
    2. Adds the missing columns (199) and views (18) to them.
    3. Adds the seed rows (93) to PFM Offices, PFM Series, PFM Process Steps and PFM Settings: each row whose title is not
       there yet.
    4. Sets the display titles ("PFM Offices", ...), the column titles and the indexes.
    5. Sets "read all, edit own rows" on PFM Publications and PFM Endorsements (PFM 10A).
    6. r2 (PFM 19 Nov 26, F2 A): makes the group "PFM Office" when the site has none (PFM 12 Nov 26, 7A: setup makes it),
       makes the permission level "PFM Office Edit All Items" (the site's Edit level plus Override List Behaviors, the one
       permission that lets a person edit every row of a list set to "edit own rows") when it is missing, and gives that
       level to the group on the site. A level with that name that is there already is not changed; the check reports it.
  A second run skips what is there, so a run that stopped can be run again.
  How: the POST requests of the payload go through Invoke-PnPSPRestMethod (the same requests the flow sent); the 23 MERGE
  updates go through CSOM (Update, ExecuteQuery), the way T16 and T19 already write on this computer. Step 6 uses the
  SharePoint REST requests for groups, levels and role assignments, through the same cmdlet.
  Which lists are "ours": only a list that was created under the internal name (its folder has that name). A list that a
  person made and titled like one of ours is never changed.
  Counts and the list, column, view, group and level names of this product only. The site address stays on this
  computer; every output line shows it as <SITE> and the DODID as <DODID>. Other group names are never written, only a
  count. If it stops: send the result file.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell (none
           with -PlanOnly).
  Writes: (create mode) the lists, columns, views, rows and list settings above, the group PFM Office, its permission
          level and its role on that site; on this computer the result file in the T20 folder and, once,
          Config\90161Z-site.txt when the site address is typed outside RADE. -Check, -DryRun and -PlanOnly change nothing
          on the site.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File 90161Z-T20-provision-lists-r2.ps1 (RADE does this).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -NoPause. -PayloadPath and -TestDir are for
  the tests in tests/run.sh.
#>
param([string]$Id, [switch]$NoPause, [switch]$Check, [switch]$DryRun, [switch]$PlanOnly, [string]$PayloadPath, [string]$TestDir)
$task = 'T20'

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


<#
.SYNOPSIS
  What the payload asks for, per list (internal name): display title, columns, indexed columns, views, rows, versioning
  and whether "edit own rows" is set.
.PARAMETER P
  The payload (provisioning-payload.json, read with ConvertFrom-Json).
.OUTPUTS
  System.Collections.Specialized.OrderedDictionary. One entry per list, in payload order.
#>
function Get-Plan($P) {
  $plan = [ordered]@{}
  foreach ($l in $P.lists) {
    $plan[[string]$l.body.Title] = @{ Display = [string]$l.body.Title; Fields = @(); Indexed = @(); Views = @(); Rows = 0; Versioning = [bool]$l.body.EnableVersioning; Secure = $false }
  }
  foreach ($op in $P.fields) {
    if ([string]$op.uri -notmatch "getbytitle\('([^']+)'\)/(fields/createfieldasxml|views)$") { continue }
    $e = $plan[$Matches[1]]
    if ($Matches[2] -eq 'views') { $e.Views += [string]$op.body.Title; continue }
    $xml = [string]$op.body.parameters.SchemaXml
    if ($xml -notmatch '\bName="([^"]+)"') { throw ('PAYLOAD column without a name in ' + $Matches[1]) }
    $name = $Matches[1]
    $e.Fields += $name
    if ($xml -match '\bIndexed="TRUE"') { $e.Indexed += $name }
  }
  foreach ($r in $P.rows) { if ([string]$r.uri -match "getbytitle\('([^']+)'\)/items$") { $plan[$Matches[1]].Rows++ } }
  foreach ($u in $P.updates) {
    if ([string]$u.uri -match "getbytitle\('([^']+)'\)$") { $plan[$Matches[1]].Display = [string]$u.body.Title }
    elseif ([string]$u.uri -match "getbytitle\('([^']+)'\)/fields/getbyinternalnameortitle\('([^']+)'\)$" -and $u.body.Indexed) { $plan[$Matches[1]].Indexed += $Matches[2] }
  }
  foreach ($x in $P.permissions) {
    if ([string]$x.uri -notmatch "getbytitle\('([^']+)'\)$") { throw 'PAYLOAD permission request not understood' }
    $title = [uri]::UnescapeDataString($Matches[1])
    $hit = @($plan.Keys | Where-Object { $plan[$_].Display -eq $title })
    if ($hit.Count -ne 1) { throw ('PAYLOAD permission for a list that is not in the payload: ' + $title) }
    $plan[$hit[0]].Secure = $true
  }
  return $plan
}

function Invoke-Rest([string]$Method, [string]$Uri, [string]$Body) {
  # One SharePoint REST request through the signed-in PnP connection (sign-in cookies and the request digest come from PnP).
  $url = $script:site.TrimEnd('/') + '/' + $Uri
  # No -Accept: the cmdlet's own default (application/json;odata=nometadata) is what the script reads.
  if ($Method -eq 'Get') { return [string](Invoke-PnPSPRestMethod -Method Get -Url $url -Raw -ErrorAction Stop) }
  return [string](Invoke-PnPSPRestMethod -Method Post -Url $url -Content $Body -ContentType 'application/json;odata=verbose' -Raw -ErrorAction Stop)
}

# Reads a REST collection and returns its "value" items as an array.
function Get-RestValue([string]$Uri) {
  $j = (Invoke-Rest 'Get' $Uri '') | ConvertFrom-Json
  return @($j.value)
}

function Get-SiteList {
  # Every list on the site that is not hidden, with the folder name it was created under (that name does not change when
  # the title does, so it finds a list before and after its rename).
  return @(Get-RestValue ('_api/web/lists?$select=Id,Title,ItemCount,EnableVersioning,BaseTemplate,Hidden,RootFolder/Name&$expand=RootFolder&$top=1000') | Where-Object { -not $_.Hidden })
}

function Find-OurList($SiteLists, [string]$Internal) {
  # Ours = created under the internal name, so its folder has that name. A list that a person made and titled
  # "PFM Settings" has another folder name: it is never matched, so nothing is added to it.
  foreach ($l in $SiteLists) { if ([string]$l.RootFolder.Name -eq $Internal) { return $l } }
  return $null
}

# A MERGE of the payload, written through CSOM: every property of the body except __metadata is set, then Update.
function Write-CsomMerge([string]$ListId, [string]$FieldName, $Body) {
  $ctx = Get-PnPContext
  $target = $ctx.Web.Lists.GetById([guid]$ListId)
  if ($FieldName) { $target = $target.Fields.GetByInternalNameOrTitle($FieldName) }
  foreach ($prop in $Body.PSObject.Properties) { if ($prop.Name -ne '__metadata') { $target.($prop.Name) = $prop.Value } }
  $target.Update()
  $ctx.ExecuteQuery()
}

# ---- Step 6: the PFM Office level (PFM 19 Nov 26, F2 A; docs/reviews/2026-11-13-sweep-decisions.md, F2) ----
# The group the app shows the PFM screens to (PFM 12 Nov 26, 3.7B and 7A). tests/ps/Test-T21.ps1 checks that T21 uses both names.
$OfficeGroup = 'PFM Office'
$OfficeGroupText = 'Publications and Forms Manager (PFM) office: the people who work the PFM organization box (90-161.Z).'
# The site's Edit level plus Override List Behaviors: Edit lacks it, and only it lets a person edit every row of a list set to
# "edit own rows" (PFM Publications and PFM Endorsements, PFM 10A), so the Alternate and the Acting PFM need it (sweep F2).
$OfficeLevel = 'PFM Office Edit All Items'
$OfficeLevelText = 'Edit, plus Override List Behaviors: edits every row, also on lists set to edit own rows (90-161.Z, PFM 2026-11-19).'
# SharePoint permission bits (SP.BasePermissions, low word): EditListItems 0x4; CancelCheckout 0x100 ("Override List Behaviors").
$EditItemsBit = [long]0x4
$OverrideBit = [long]0x100
# The RoleTypeKind of the site's Edit level (SP.RoleType Editor = 6): found by kind, so a site in another language works too.
$EditRoleKind = 6

# Finds a site group by its name; returns its Id, or 0 when the site has no group with that name.
function Get-GroupId([string]$Name) {
  $hit = @(Get-RestValue ('_api/web/sitegroups?$select=Id,Title&$top=5000') | Where-Object { [string]$_.Title -eq $Name })
  if ($hit.Count) { return [int]$hit[0].Id }
  return 0
}

# Finds a permission level of the site by its name, or by its kind when the name is empty; returns it, or $null.
function Get-RoleLevel([string]$Name, [int]$Kind) {
  $all = @(Get-RestValue ('_api/web/roledefinitions?$select=Id,Name,RoleTypeKind,BasePermissions&$top=500'))
  $hit = @($all | Where-Object { ($Name -and [string]$_.Name -eq $Name) -or (-not $Name -and [int]$_.RoleTypeKind -eq $Kind) })
  if ($hit.Count) { return $hit[0] }
  return $null
}

# The Ids of the permission levels a group holds on the site itself; none when it holds no level there.
function Get-WebBinding([int]$PrincipalId) {
  $uri = '_api/web/roleassignments/getbyprincipalid(' + $PrincipalId + ')/roledefinitionbindings?$select=Id'
  try { return @(Get-RestValue $uri | ForEach-Object { [int]$_.Id }) } catch { return @() }
}

# One word (High or Low) of SP.BasePermissions as a number, whatever JSON type it came in: SharePoint writes a string, and on
# Windows PowerShell 5.1 ConvertFrom-Json makes a JSON number an Int32 or an Int64 by its size. Parsed from its invariant text.
function ConvertTo-PermissionWord($Value) { return [long]::Parse(([string]$Value).Trim(), [Globalization.CultureInfo]::InvariantCulture) }

# True when a level holds every permission of another level (both from Get-RoleLevel) plus the extra bits given, checked bit
# by bit in both 32-bit words.
function Test-LevelPermission($Level, $Base, [long]$Extra) {
  $have = @((ConvertTo-PermissionWord $Level.BasePermissions.Low), (ConvertTo-PermissionWord $Level.BasePermissions.High))
  $want = @(((ConvertTo-PermissionWord $Base.BasePermissions.Low) -bor $Extra), (ConvertTo-PermissionWord $Base.BasePermissions.High))
  for ($w = 0; $w -lt 2; $w++) { for ($i = 0; $i -lt 32; $i++) { $bit = [long]1 -shl $i; if (($want[$w] -band $bit) -and -not ($have[$w] -band $bit)) { return $false } } }
  return $true
}

<#
.SYNOPSIS
  Step 6: the group PFM Office, the level PFM Office Edit All Items (the bits of the site's Edit level plus Override List
  Behaviors) and that level for the group on the site, each made only when it is missing (a second run changes nothing).
  A level with that name that is there is not changed.
.PARAMETER Write
  $true: make what is missing; $false (-DryRun): only count it.
.OUTPUTS
  System.Collections.Hashtable. group, level, binding: 1 when it was made (or a dry run would make it), else 0.
#>
function Grant-OfficeLevel([bool]$Write) {
  $made = @{ group = 0; level = 0; binding = 0 }
  $gid = Get-GroupId $OfficeGroup
  if (-not $gid) {
    $made.group = 1
    if ($Write) {
      Write-Host ('  Making the group ' + $OfficeGroup + ' ...')
      $null = Invoke-Rest 'Post' '_api/web/sitegroups' (@{ __metadata = @{ type = 'SP.Group' }; Title = $OfficeGroup; Description = $OfficeGroupText } | ConvertTo-Json -Compress)
      $gid = Get-GroupId $OfficeGroup
      if (-not $gid) { throw ('GROUP ' + $OfficeGroup + ' not on the site after the create step.') }
    }
  }
  $level = Get-RoleLevel $OfficeLevel 0
  if (-not $level) {
    $made.level = 1
    $edit = Get-RoleLevel '' $EditRoleKind
    if (-not $edit) { throw ('LEVEL Edit not found on the site: the level ' + $OfficeLevel + ' is made from it. The lists are done.') }
    if ($Write) {
      Write-Host ('  Making the permission level ' + $OfficeLevel + ' ...')
      $low = (ConvertTo-PermissionWord $edit.BasePermissions.Low) -bor $OverrideBit
      $bits = @{ __metadata = @{ type = 'SP.BasePermissions' }; High = [string](ConvertTo-PermissionWord $edit.BasePermissions.High); Low = [string]$low }
      $body = @{ __metadata = @{ type = 'SP.RoleDefinition' }; Name = $OfficeLevel; Description = $OfficeLevelText; BasePermissions = $bits }
      $null = Invoke-Rest 'Post' '_api/web/roledefinitions' ($body | ConvertTo-Json -Depth 5 -Compress)
      $level = Get-RoleLevel $OfficeLevel 0
      if (-not $level) { throw ('LEVEL ' + $OfficeLevel + ' not on the site after the create step.') }
    }
  }
  if (-not $gid -or -not $level) { $made.binding = 1; return $made }
  if ((Get-WebBinding $gid) -notcontains [int]$level.Id) {
    $made.binding = 1
    if ($Write) {
      Write-Host ('  Giving the level ' + $OfficeLevel + ' to the group ' + $OfficeGroup + ' ...')
      $null = Invoke-Rest 'Post' ('_api/web/roleassignments/addroleassignment(principalid=' + $gid + ',roledefid=' + [int]$level.Id + ')') '{}'
    }
  }
  return $made
}

<#
.SYNOPSIS
  Step 7, the read-back of step 6: PASS when the group holds the level on the site and the level holds Edit plus Edit Items and Override List Behaviors; else FAIL (typed list: PS 5.1).
.OUTPUTS
  System.String. One ITEM line.
#>
function Test-OfficeLevel {
  $gid = Get-GroupId $OfficeGroup; $level = Get-RoleLevel $OfficeLevel 0; $edit = Get-RoleLevel '' $EditRoleKind
  $bad = New-Object System.Collections.Generic.List[string]; $need = [long]($EditItemsBit -bor $OverrideBit); if ($level -and -not $edit) { $bad.Add('the site has no Edit level to compare') }
  if (-not $gid) { $bad.Add('the group ' + $OfficeGroup + ' is not on the site') }; if (-not $level) { $bad.Add('the level ' + $OfficeLevel + ' is not on the site') }
  if ($level -and $edit) { $ok = [bool](Test-LevelPermission $level $edit $need); if (-not $ok) { $bad.Add('the level lacks a permission of Edit or Override List Behaviors') } }
  if ($level -and $gid) { $held = @(Get-WebBinding $gid); if ($held -notcontains [int]$level.Id) { $bad.Add('the group does not hold the level on the site') } }
  if ($bad.Count -gt 0) { return ('ITEM P01-pfm-office FAIL ' + ($bad -join '; ') + ' (this script never changes a level that is there)') }
  return ('ITEM P01-pfm-office PASS the group "' + $OfficeGroup + '" holds the level "' + $OfficeLevel + '" on the site (Edit plus Override List Behaviors)')
}

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
$Rev = 'r2'
$resultName = '90161Z-T20-provision-lists-' + $Rev + '.txt'
if ($Check) { $resultName = '90161Z-T20-clean-check-' + $Rev + '.txt' }
try {
  $ErrorActionPreference = 'Stop'
  if ($PlanOnly) {
    if (-not $PayloadPath) { $PayloadPath = Join-Path $PSScriptRoot 'provisioning-payload.json' }
    $p = Get-Content -LiteralPath $PayloadPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $plan = Get-Plan $p
    $nf = 0; $nv = 0; foreach ($k in $plan.Keys) { $nf += $plan[$k].Fields.Count; $nv += $plan[$k].Views.Count }
    Write-Host ('PLAN lists=' + $plan.Count + ' fields=' + $nf + ' views=' + $nv + ' rows=' + @($p.rows).Count + ' updates=' + @($p.updates).Count + ' permissions=' + @($p.permissions).Count)
    exit 0
  }
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 20' -Create }
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $mode = 'create'; if ($Check) { $mode = 'check (reads only)' } elseif ($DryRun) { $mode = 'dry run (reads only)' }
  $lines.Add('TASK T20 list provisioning ' + $Rev + ', ' + $mode + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  if (-not $PayloadPath) { $PayloadPath = Join-Path $dir 'provisioning-payload.json' }
  if (-not (Test-Path -LiteralPath $PayloadPath -PathType Leaf)) { throw 'PAYLOAD not found: provisioning-payload.json is not in the T20 folder. Run the round again so RADE saves it.' }
  $p = Get-Content -LiteralPath $PayloadPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $plan = Get-Plan $p
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'Connecting to the site. If a sign-in window opens, sign in with your CAC.'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')

  # The first request is a read: it proves the REST route before anything is written.
  $siteLists = Get-SiteList
  $lines.Add('ITEM a-rest-read PASS lists read from the site=' + $siteLists.Count)
  $found = @{}
  foreach ($k in $plan.Keys) { $l = Find-OurList $siteLists $k; if ($l) { $found[$k] = $l } }

  if ($Check) {
    $internal = @($plan.Keys); $display = @($plan.Keys | ForEach-Object { $plan[$_].Display })
    # A list that 90-161.Z made (by its folder name), or one the rights probe made.
    $isOurs = { param($l) ($internal -contains [string]$l.RootFolder.Name) -or ([string]$l.RootFolder.Name -like 'PFMRightsProbe*') -or ([string]$l.Title -like 'PFMRightsProbe*') }
    # A list that 90-161.Z did not make but that has a title the install needs: SharePoint allows one list per title,
    # so it blocks the install. Its title is one of our 12 product titles, so it can be named; the script never changes it.
    $isClash = { param($l) -not (& $isOurs $l) -and (($display -contains [string]$l.Title) -or ($internal -contains [string]$l.Title)) }
    $left = @($siteLists | Where-Object { & $isOurs $_ } | ForEach-Object { [string]$_.Title } | Sort-Object)
    $clash = @($siteLists | Where-Object { & $isClash $_ } | ForEach-Object { [string]$_.Title } | Sort-Object)
    $other = @($siteLists | Where-Object { -not (& $isOurs $_) -and -not (& $isClash $_) -and ([string]$_.Title -like 'PFM*') }).Count
    if ($left.Count) { $lines.Add('ITEM b-lists FAIL still on the site (' + $left.Count + '): ' + ($left -join ', ') + '. Delete them (go.md, "Clean the test site", step 5)') }
    else { $lines.Add('ITEM b-lists PASS no 90-161.Z list on the site (other lists whose title starts with PFM: ' + $other + ', not made by 90-161.Z, not touched)') }
    if ($clash.Count) {
      $lines.Add('ITEM b2-title-in-use FAIL a list that 90-161.Z did not make has a title the install needs (' + $clash.Count + '): ' + ($clash -join ', ') +
        '. The install cannot use that title. Rename that list or delete it: your decision; this script does not change it')
    }
    else { $lines.Add('ITEM b2-title-in-use PASS no other list has a title the install needs') }
    $lib = @($siteLists | Where-Object { [string]$_.Title -eq '90-161.Z' -or [string]$_.RootFolder.Name -eq '90-161.Z' })
    if ($lib.Count) { $lines.Add('ITEM c-library FAIL the library 90-161.Z is still on the site. Delete it (step 5)') }
    else { $lines.Add('ITEM c-library PASS no 90-161.Z library') }
    $docs = @($siteLists | Where-Object { $_.BaseTemplate -eq 101 -and @('Shared Documents', 'Documents') -contains [string]$_.RootFolder.Name })
    if ($docs.Count) {
      $filesUri = "_api/web/lists(guid'" + $docs[0].Id + "')/rootfolder/files?" + '$select=Name&$top=2000'
      $files = @(Get-RestValue $filesUri | ForEach-Object { [string]$_.Name } | Where-Object { $_ -like '90161Z-*' } | Sort-Object)
      if ($files.Count) { $lines.Add('ITEM d-files FAIL result files still in Documents (' + $files.Count + '): ' + ($files -join ', ') + '. Delete them (step 6)') }
      else { $lines.Add('ITEM d-files PASS no 90161Z result file in Documents') }
    } else { $lines.Add('ITEM d-files PASS no Documents library found, so no result file') }
    $groups = @(Get-RestValue ('_api/web/sitegroups?$select=Title&$top=2000') | ForEach-Object { [string]$_.Title })
    if ($groups -contains 'PFM Rights Probe TEST') { $lines.Add('ITEM e-groups FAIL the group "PFM Rights Probe TEST" is still on the site. Delete it (step 7)') }
    else {
      # r2: the group PFM Office is made by 90-161.Z (step 6) and kept: it is named, not counted with the other PFM groups.
      $otherPfm = @($groups | Where-Object { $_ -like 'PFM*' -and $_ -ne $OfficeGroup }).Count
      $isThere = $(if ($groups -contains $OfficeGroup) { 'yes, kept' } else { 'no' })
      $lines.Add('ITEM e-groups PASS no probe test group (other groups whose name starts with PFM: ' + $otherPfm + ', not made by 90-161.Z; the group ' +
        $OfficeGroup + ' is there=' + $isThere + ')')
    }
    $nf = @($lines | Where-Object { $_ -cmatch '^ITEM \S+ FAIL\b' }).Count
    $lines.Add('CLEAN check done, items with problems=' + $nf)
  } else {
    $write = -not $DryRun
    # Before any write: this PowerShell must write a list inside a request body as a JSON list ("results":[...]).
    $probe = @($p.rows | Where-Object { @($_.body.PSObject.Properties | Where-Object { $_.Value -and $_.Value.PSObject.Properties['results'] }).Count } | Select-Object -First 1)
    if ($probe.Count) {
      $pj = $probe[0].body | ConvertTo-Json -Depth 20 -Compress
      if ($pj -notmatch '"results":\[' -or $pj -match '"Count":') { throw 'JSON not written as expected by this PowerShell (a list in a request body). Nothing was changed. Send this line.' }
      $lines.Add('ITEM a2-json PASS request bodies are written as expected')
    }
    $made = @{ lists = 0; fields = 0; views = 0; viewops = 0; rows = 0; updates = 0; permissions = 0 }
    $skip = @{ lists = 0; fields = 0; views = 0; rows = 0 }
    $lines.Add('BEFORE lists on the site=' + $found.Count + ' of ' + $plan.Count)

    # 1. Lists (created under the internal name; the display title is set in step 4, as the flow does).
    foreach ($l in $p.lists) {
      $name = [string]$l.body.Title
      if ($found.ContainsKey($name)) { $skip.lists++; continue }
      if ($write) { Write-Host ('  Creating the list ' + $name + ' ...'); $null = Invoke-Rest 'Post' ([string]$l.uri) ($l.body | ConvertTo-Json -Depth 20 -Compress) }
      $made.lists++
    }
    if ($write) {
      $siteLists = Get-SiteList
      foreach ($k in $plan.Keys) { $l = Find-OurList $siteLists $k; if ($l) { $found[$k] = $l } }
      $missing = @($plan.Keys | Where-Object { -not $found.ContainsKey($_) })
      if ($missing.Count) { throw ('LISTS not on the site after the create step: ' + ($missing -join ', ')) }
    }

    # 2. Columns and views, in payload order. A lookup column gets the real id of the list it points to.
    $haveFields = @{}; $haveViews = @{}
    foreach ($k in $plan.Keys) {
      $haveFields[$k] = @(); $haveViews[$k] = @()
      if ($found.ContainsKey($k)) {
        $base = "_api/web/lists(guid'" + $found[$k].Id + "')"
        $haveFields[$k] = @(Get-RestValue ($base + '/fields?$select=InternalName&$top=2000') | ForEach-Object { [string]$_.InternalName })
        $haveViews[$k] = @(Get-RestValue ($base + '/views?$select=Title&$top=500') | ForEach-Object { [string]$_.Title })
      }
    }
    $lastList = ''
    foreach ($op in $p.fields) {
      $uri = [string]$op.uri
      if ($uri -notmatch "^_api/web/lists/getbytitle\('([^']+)'\)/(.+)$") { throw 'PAYLOAD column or view request not understood' }
      $k = $Matches[1]; $rest = $Matches[2]
      if ($write -and $k -ne $lastList) { Write-Host ('  Columns and views of ' + $k + ' ...'); $lastList = $k }
      $target = ''
      if ($found.ContainsKey($k)) { $target = "_api/web/lists(guid'" + $found[$k].Id + "')/" + $rest }
      if ($rest -eq 'fields/createfieldasxml') {
        $null = ([string]$op.body.parameters.SchemaXml) -match '\bName="([^"]+)"'
        if ($haveFields[$k] -contains $Matches[1]) { $skip.fields++; continue }
        $body = $op.body | ConvertTo-Json -Depth 20 -Compress
        foreach ($ref in $p.lookupPlaceholders) {
          $token = '{__' + [string]$ref + '_ID__}'
          if ($body.Contains($token)) {
            if ($write) { $body = $body.Replace($token, '{' + [string]$found[[string]$ref].Id + '}') }
          }
        }
        if ($write) { $null = Invoke-Rest 'Post' $target $body }
        $made.fields++
      } elseif ($rest -eq 'views') {
        $title = [string]$op.body.Title
        if ($haveViews[$k] -contains $title) { $skip.views++; continue }
        if ($write) { $null = Invoke-Rest 'Post' $target ($op.body | ConvertTo-Json -Depth 20 -Compress) }
        $made.views++
      } elseif ($rest -match "^views/getbytitle\('([^']+)'\)/viewfields/") {
        # Always sent, also for a view that was there: clear the columns, then add each one. A run that stopped between
        # the view and its columns is repaired this way; for a complete view it changes nothing.
        if ($write) { $null = Invoke-Rest 'Post' $target '{}' }
        $made.viewops++
      } else { throw ('PAYLOAD request not understood for ' + $k) }
    }

    # 3. Seed rows: each row whose Title is not in the list yet (so a run that stopped part way is repaired, and a
    # second run adds nothing).
    $lastList = ''
    $haveRows = @{}
    foreach ($r in $p.rows) {
      if ([string]$r.uri -notmatch "^_api/web/lists/getbytitle\('([^']+)'\)/items$") { throw 'PAYLOAD row request not understood' }
      $k = $Matches[1]
      if (-not $haveRows.ContainsKey($k)) {
        $haveRows[$k] = @()
        if ($found.ContainsKey($k) -and [int]$found[$k].ItemCount -gt 0) {
          $haveRows[$k] = @(Get-RestValue ("_api/web/lists(guid'" + $found[$k].Id + "')/items?" + '$select=Title&$top=5000') | ForEach-Object { [string]$_.Title })
        }
      }
      if ($haveRows[$k] -contains [string]$r.body.Title) { $skip.rows++; continue }
      if ($write) {
        if ($k -ne $lastList) { Write-Host ('  Seed rows of ' + $k + ' ...'); $lastList = $k }
        $null = Invoke-Rest 'Post' ("_api/web/lists(guid'" + $found[$k].Id + "')/items") ($r.body | ConvertTo-Json -Depth 20 -Compress)
      }
      $made.rows++
    }

    # 4. Titles and indexes, then 5. "read all, edit own rows". Setting a value that is already set changes nothing.
    foreach ($u in $p.updates) {
      if ([string]$u.uri -notmatch "^_api/web/lists/getbytitle\('([^']+)'\)(?:/fields/getbyinternalnameortitle\('([^']+)'\))?$") { throw 'PAYLOAD update request not understood' }
      if ($write) { Write-CsomMerge ([string]$found[$Matches[1]].Id) ([string]$Matches[2]) $u.body }
      $made.updates++
    }
    foreach ($x in $p.permissions) {
      $null = ([string]$x.uri) -match "getbytitle\('([^']+)'\)$"
      $title = [uri]::UnescapeDataString($Matches[1])
      $k = @($plan.Keys | Where-Object { $plan[$_].Display -eq $title })[0]
      if ($write) { Write-CsomMerge ([string]$found[$k].Id) '' $x.body }
      $made.permissions++
    }
    # 6. The PFM Office level (F2 A), after the lists, so it never stops the list steps above.
    $office = Grant-OfficeLevel $write
    $word = 'CREATED'; if (-not $write) { $word = 'DRYRUN would create' }
    $lines.Add($word + ' lists=' + $made.lists + ' fields=' + $made.fields + ' views=' + $made.views + ' view-column requests=' + $made.viewops +
      ' rows=' + $made.rows + '; set: updates=' + $made.updates + ' permissions=' + $made.permissions)
    $lines.Add($word + ' for ' + $OfficeGroup + ': group=' + $office.group + ' level=' + $office.level + ' level given to the group=' + $office.binding)
    $lines.Add('SKIPPED (already there) lists=' + $skip.lists + ' fields=' + $skip.fields + ' views=' + $skip.views + ' rows=' + $skip.rows)

    if ($write) {
      # 7. Check every list against the payload, then the PFM Office level.
      $siteLists = Get-SiteList
      $n = 0
      foreach ($k in $plan.Keys) {
        $n++
        $e = $plan[$k]
        $l = Find-OurList $siteLists $k
        $tag = 'ITEM L' + $n.ToString('00') + '-' + $k
        if (-not $l) { $lines.Add($tag + ' FAIL the list is not on the site'); continue }
        $base = "_api/web/lists(guid'" + $l.Id + "')"
        $sf = @(Get-RestValue ($base + '/fields?$select=InternalName,Indexed&$top=2000'))
        $names = @($sf | ForEach-Object { [string]$_.InternalName })
        $idx = @($sf | Where-Object { $_.Indexed } | ForEach-Object { [string]$_.InternalName })
        $views = @(Get-RestValue ($base + '/views?$select=Title&$top=500') | ForEach-Object { [string]$_.Title })
        $bad = @()
        if ([string]$l.Title -ne $e.Display) { $bad += 'title is not "' + $e.Display + '"' }
        $m = @($e.Fields | Where-Object { $names -notcontains $_ }); if ($m.Count) { $bad += 'columns missing: ' + ($m -join ', ') }
        $m = @($e.Indexed | Where-Object { $idx -notcontains $_ }); if ($m.Count) { $bad += 'not indexed: ' + ($m -join ', ') }
        $m = @($e.Views | Where-Object { $views -notcontains $_ }); if ($m.Count) { $bad += 'views missing: ' + ($m -join ', ') }
        if ($e.Versioning -and -not $l.EnableVersioning) { $bad += 'versioning is off' }
        if ([int]$l.ItemCount -lt $e.Rows) { $bad += 'rows ' + [int]$l.ItemCount + ', expected ' + $e.Rows + ' or more' }
        if ($e.Secure) {
          $sec = Get-PnPList -Identity $e.Display -Includes ReadSecurity, WriteSecurity -ErrorAction Stop
          if ([int]$sec.ReadSecurity -ne 1 -or [int]$sec.WriteSecurity -ne 2) { $bad += 'edit own rows not set (read ' + [int]$sec.ReadSecurity + ', write ' + [int]$sec.WriteSecurity + ')' }
        }
        if ($bad.Count) { $lines.Add($tag + ' FAIL ' + ($bad -join '; ')) }
        else {
          $lines.Add($tag + ' PASS "' + $e.Display + '": columns ' + $e.Fields.Count + ', indexed ' + $e.Indexed.Count + ', views ' + $e.Views.Count +
            ', rows ' + [int]$l.ItemCount + $(if ($e.Secure) { ', edit own rows set' } else { '' }))
        }
      }
      $lines.Add((Test-OfficeLevel))
      $lines.Add('AFTER lists on the site=' + @($plan.Keys | Where-Object { Find-OurList $siteLists $_ }).Count + ' of ' + $plan.Count)
    }
    $nf = @($lines | Where-Object { $_ -cmatch '^ITEM \S+ FAIL\b' }).Count
    $lines.Add('PROVISION done, items with problems=' + $nf)
  }
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
} catch {
  if ($PlanOnly) { Write-Host ('PLAN FAILED: ' + [string]$_); exit 2 }
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(400, $m.Length)) + ' (a run that stopped can be run again: it skips what is there)')
} finally {
  if (-not $PlanOnly) {
    $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
    if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir $resultName) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
    $masked | ForEach-Object { Write-Host $_ }
    if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
    if (@($masked | Where-Object { $_ -cmatch '^STOPPED|^ITEM \S+ FAIL\b' }).Count) { exit 1 }
  }
}
