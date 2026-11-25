<#
.SYNOPSIS
  90-161.Z Task 20 list provisioning r4, module "helpers": the plan of the payload and the SharePoint helpers (REST, CSOM
  merge, groups, permission levels). Moved here from 90161Z-T20-provision-lists-r4.ps1 (code standard file size cap, C4); the code is unchanged.
.DESCRIPTION
  Loaded by 90161Z-T20-provision-lists-r4.ps1 (dot-sourced from the same folder, in its scope); it does nothing when it is run alone.
  Inputs: $site and the PnP.PowerShell connection of the main file ($script:site). Outputs: the functions Get-Plan, Invoke-Rest,
  Get-RestValue, Get-SiteList, Find-OurList, Write-CsomMerge, Get-GroupId, Get-RoleLevel, Get-WebBinding, ConvertTo-PermissionWord, Test-LevelPermission.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection of the main file (none in Get-Plan).
  Writes: Write-CsomMerge and Invoke-Rest (Post) change the site when the main file calls them in create mode; nothing on this computer.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T20-provision-lists-r4.ps1 loads it.
#>

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
  $q = '_api/web/lists?$select=Id,Title,ItemCount,EnableVersioning,BaseTemplate,Hidden,HasUniqueRoleAssignments,RootFolder/Name&$expand=RootFolder&$top=1000'
  return @(Get-RestValue $q | Where-Object { -not $_.Hidden })
}

function Find-OurList($SiteLists, [string]$Internal) {
  # Ours = created under the internal name, so its folder has that name. A list that a person made and titled
  # "PFM Settings" has another folder name: it is never matched, so nothing is added to it.
  foreach ($l in $SiteLists) { if ([string]$l.RootFolder.Name -eq $Internal) { return $l } }
  return $null
}

# Adds the line "MADE <kind>: <name>" to the output lines for one item that THIS run created (RADE engine-v40 reads it, and the Uninstall
# of 90-161.Z gets it back in RADE_MADE). Kind is a lowercase word (list, group, level). Call it only after the item is made, never in a
# dry run and never for an item that was already there. The final lines pass the mask, which keeps these product names.
function Add-MadeLine([string]$Kind, [string]$Name) { $lines.Add('MADE ' + $Kind + ': ' + $Name) }

# A MERGE of the payload, written through CSOM: every property of the body except __metadata is set, then Update.
function Write-CsomMerge([string]$ListId, [string]$FieldName, $Body) {
  $ctx = Get-PnPContext
  $target = $ctx.Web.Lists.GetById([guid]$ListId)
  if ($FieldName) { $target = $target.Fields.GetByInternalNameOrTitle($FieldName) }
  foreach ($prop in $Body.PSObject.Properties) { if ($prop.Name -ne '__metadata') { $target.($prop.Name) = $prop.Value } }
  $target.Update()
  $ctx.ExecuteQuery()
}


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
