# Fake PnP.PowerShell for tests/ps/Test-T20.ps1 (cloud tests only; never goes to the gov device).
# It keeps a small site in $global:FakeSP and answers the cmdlets and REST routes that the T20 and T19 scripts use: lists,
# columns, views, rows, site groups, permission levels and their roles on the site (T20 r2), and the column and row cmdlets
# and the CSOM choice write of T19 r4 (a small C# stand-in for the CSOM types, below).
# It is strict on purpose: a request the real SharePoint would refuse (unknown list, a column twice, a row that names
# a column the list does not have, a lookup to a list id that does not exist, a placeholder left in the XML) throws.
# It proves the script's logic and order, not the real service: the gov device round is that proof.

# The CSOM types T19 reaches through Get-PnPContext: CastTo<FieldChoice>, Choices, Update, ExecuteQuery. Store is the fake
# column's data (its Choices), so an Update shows in the next Get-PnPField.
if (-not ('Microsoft.SharePoint.Client.FakeClientContext' -as [type])) {
  Add-Type -TypeDefinition @'
namespace Microsoft.SharePoint.Client {
  public class ClientObject { public System.Collections.Hashtable Store; }
  public class Field : ClientObject { public string SchemaXml; }
  public class FieldChoice : Field { public string[] Choices; public void Update() { Store["Choices"] = Choices; } }
  public class FakeClientContext {
    public object Web;
    public T CastTo<T>(ClientObject o) where T : ClientObject, new() { T t = new T(); t.Store = o.Store; return t; }
    public void ExecuteQuery() { }
  }
}
'@
}

# One fake permission level as plain hashtables (Id, Name, RoleTypeKind, BasePermissions with High and Low). Hashtables, not
# [pscustomobject]: in Windows PowerShell 5.1 a [pscustomobject]@{} cast written inside a method call (List.Add) or nested in
# another one is not always a real PSCustomObject, and "$x.Low = ..." on such an object can add a property to its wrapper
# that ConvertTo-Json does not write (the test saw its own change; the script got the old value). A hashtable key is the
# same object on 5.1 and 7. Returns the level.
function New-FakeLevel([int]$Id, [string]$Name, [int]$Kind, $High, $Low) {
  $bits = @{ High = $High; Low = $Low }
  $level = @{ Id = $Id; Name = $Name; RoleTypeKind = $Kind; BasePermissions = $bits }
  return $level
}

# Change the permission bits of a fake level by its name (keys of its hashtable). Takes the name, High and Low (a string or
# a number, as a test needs); returns nothing.
function Set-FakeLevelBits([string]$Name, $High, $Low) {
  $hit = @($global:FakeSP.Levels | Where-Object { $_['Name'] -eq $Name })
  if (-not $hit.Count) { throw ('FAKE: no level named ' + $Name) }
  $hit[0]['BasePermissions']['High'] = $High; $hit[0]['BasePermissions']['Low'] = $Low
}

# The levels as the REST answer writes them. Real SharePoint writes SP.BasePermissions High and Low as JSON strings; with
# $global:FakeSP.BitsAsNumbers on, they are written as JSON numbers (so the script is proved for both). Returns JSON text.
function Get-FakeLevelJson {
  $out = @($global:FakeSP.Levels | ForEach-Object {
      $h = $_['BasePermissions']['High']; $l = $_['BasePermissions']['Low']
      if ($global:FakeSP.BitsAsNumbers) { $h = [long]$h; $l = [long]$l } else { $h = [string]$h; $l = [string]$l }
      @{ Id = [int]$_['Id']; Name = [string]$_['Name']; RoleTypeKind = [int]$_['RoleTypeKind']; BasePermissions = @{ High = $h; Low = $l } } })
  return (@{ value = $out } | ConvertTo-Json -Depth 5 -Compress)
}

# Reset the fake site: an empty site with one Documents library, no groups and the 4 standard permission levels (with the
# real permission bits of SharePoint Online). Takes nothing; returns nothing.
function New-FakeSite {
  $global:FakeSP = @{ Lists = (New-Object System.Collections.ArrayList); Groups = @(); Posts = 0; Gets = 0; Connected = $false; Url = ''; FailOn = ''; FailAfter = 0; Sent = (New-Object System.Collections.ArrayList)
    Levels = (New-Object System.Collections.ArrayList); WebRoles = @{} }
  foreach ($lv in @(@(1073741829, 'Full Control', 5, '2147483647', '4294705151'), @(1073741830, 'Edit', 6, '432', '1011030767'),
      @(1073741827, 'Contribute', 3, '432', '1011028719'), @(1073741826, 'Read', 2, '176', '138612833'))) {
    $null = $global:FakeSP.Levels.Add((New-FakeLevel $lv[0] $lv[1] $lv[2] $lv[3] $lv[4]))
  }
  $docs = Add-FakeList 'Documents' 101 'Shared Documents'
  $null = $docs
}

# Add a fake list (title, template number, root folder name) with the built-in columns and the Fields.GetByInternalNameOrTitle method. Returns the list object.
function Add-FakeList([string]$Title, [int]$Template, [string]$Folder) {
  $l = [pscustomobject]@{
    Id = [guid]::NewGuid().ToString(); Title = $Title; ItemCount = 0; EnableVersioning = $false; BaseTemplate = $Template; Hidden = $false
    RootFolder = [pscustomobject]@{ Name = $Folder }; ReadSecurity = 1; WriteSecurity = 1
    FieldList = (New-Object System.Collections.ArrayList); ViewList = (New-Object System.Collections.ArrayList)
    Items = (New-Object System.Collections.ArrayList); Files = (New-Object System.Collections.ArrayList)
  }
  foreach ($n in 'Title', 'Created', 'Modified', 'Author', 'Editor', 'ID') {
    $null = $l.FieldList.Add((New-FakeField $n $n))
  }
  $l | Add-Member -MemberType ScriptMethod -Name Update -Value { }
  $l | Add-Member -MemberType ScriptProperty -Name Fields -Value {
    $owner = $this
    $o = [pscustomobject]@{ Owner = $owner }
    $o | Add-Member -MemberType ScriptMethod -Name GetByInternalNameOrTitle -Value {
      param([string]$Name)
      $hit = @($this.Owner.FieldList | Where-Object { $_.InternalName -eq $Name -or $_.Title -eq $Name })
      if (-not $hit.Count) { throw ('FAKE: no column ' + $Name) }
      return $hit[0]
    }
    return $o
  }
  $null = $global:FakeSP.Lists.Add($l)
  return $l
}

# Make one fake column from its internal name, title and choices (none for a column that is not a Choice). Returns the column object.
function New-FakeField([string]$Internal, [string]$Title, [string[]]$Choices = $null) {
  $f = [pscustomobject]@{ InternalName = $Internal; Title = $Title; Indexed = $false; Data = @{ Choices = $Choices } }
  $f | Add-Member -MemberType ScriptMethod -Name Update -Value { }
  return $f
}

# Find a fake list by id. Takes the id text; returns the list or throws a 404 message.
function Get-FakeListById([string]$Id) {
  $hit = @($global:FakeSP.Lists | Where-Object { $_.Id -eq $Id })
  if (-not $hit.Count) { throw ('FAKE 404: no list with id ' + $Id) }
  return $hit[0]
}

# Fake Connect-PnPOnline: only -UseWebLogin is accepted, as on the gov device; records the address.
function Connect-PnPOnline {
  [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin)
  if (-not $global:FakeSP) { New-FakeSite }
  if (-not $UseWebLogin) { throw 'FAKE: the gov device signs in with -UseWebLogin only' }
  $global:FakeSP.Connected = $true; $global:FakeSP.Url = $Url
}

# Fake Disconnect-PnPOnline: marks the fake site as not connected.
function Disconnect-PnPOnline { [CmdletBinding()] param() $global:FakeSP.Connected = $false }

# Fake Get-PnPContext: a context whose Web.Lists.GetById(guid) finds a fake list, whose CastTo gives a FieldChoice and whose
# ExecuteQuery does nothing.
function Get-PnPContext {
  [CmdletBinding()] param()
  $lists = [pscustomobject]@{}
  $lists | Add-Member -MemberType ScriptMethod -Name GetById -Value { param([guid]$Id) return (Get-FakeListById $Id.ToString()) }
  $ctx = New-Object Microsoft.SharePoint.Client.FakeClientContext
  $ctx.Web = [pscustomobject]@{ Lists = $lists }
  return $ctx
}

# Find a fake column of a list by internal name or title. Takes the list title and the column name; returns it or throws.
function Get-FakeColumn([string]$List, [string]$Name) {
  $hit = @((Get-PnPList -Identity $List).FieldList | Where-Object { $_.InternalName -eq $Name -or $_.Title -eq $Name })
  if (-not $hit.Count) { throw ('FAKE: no column ' + $Name + ' in ' + $List) }
  return $hit[0]
}

# Fake Get-PnPField: the column as a base Field (as in PnP 1.12.0: Choices only in SchemaXml), or throws when it is missing.
function Get-PnPField {
  [CmdletBinding()] param([string]$List, [string]$Identity)
  $c = Get-FakeColumn $List $Identity
  $f = New-Object Microsoft.SharePoint.Client.Field
  $f.Store = $c.Data
  $inner = $(if ($null -ne $c.Data.Choices) { '<CHOICES>' + ((@($c.Data.Choices) | ForEach-Object { '<CHOICE>' + [Security.SecurityElement]::Escape($_) + '</CHOICE>' }) -join '') + '</CHOICES>' } else { '' })
  $f.SchemaXml = '<Field Name="' + $c.InternalName + '" DisplayName="' + $c.Title + '">' + $inner + '</Field>'
  return $f
}

# Fake Add-PnPFieldFromXml: adds a column from its XML, by the same strict rules as the REST route.
function Add-PnPFieldFromXml {
  [CmdletBinding()] param([string]$List, [string]$FieldXml)
  $body = [pscustomobject]@{ parameters = [pscustomobject]@{ SchemaXml = $FieldXml } }
  $null = Send-FakeListRest (Get-PnPList -Identity $List) 'fields/createfieldasxml' $body 'Add-PnPFieldFromXml'
}

# Fake Get-PnPListItem: the rows of a list as hashtables (Id = position + 1, and every value of the row).
function Get-PnPListItem {
  [CmdletBinding()] param([string]$List, [string[]]$Fields)
  $l = Get-PnPList -Identity $List; $i = 0
  return @($l.Items | ForEach-Object { $i++; $h = @{ Id = $i }; foreach ($p in $_.PSObject.Properties) { $h[$p.Name] = $p.Value }; $h })
}

# Fake Set-PnPListItem: sets values of one row (by Id from Get-PnPListItem); a column the list does not have throws.
function Set-PnPListItem {
  [CmdletBinding()] param([string]$List, [int]$Identity, [hashtable]$Values)
  $l = Get-PnPList -Identity $List
  $row = $l.Items[$Identity - 1]
  foreach ($k in $Values.Keys) { $null = Get-FakeColumn $List $k; $row | Add-Member -NotePropertyName $k -NotePropertyValue $Values[$k] -Force }
  $global:FakeSP.RowWrites++
}

# Fake Get-PnPList: finds a fake list by title or throws.
function Get-PnPList {
  [CmdletBinding()] param([string]$Identity, [string[]]$Includes)
  $hit = @($global:FakeSP.Lists | Where-Object { $_.Title -eq $Identity })
  if (-not $hit.Count) { throw ('FAKE: no list titled ' + $Identity) }
  return $hit[0]
}

# Answer a REST GET. Takes the path after /_api/ (no query); returns the JSON text of the lists, groups, columns, views, rows or files, or throws a 404 message.
function Get-FakeRestAnswer([string]$path) {
  if ($path -eq 'web/lists') {
    return (@{ value = @($global:FakeSP.Lists | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Title = $_.Title; ItemCount = $_.Items.Count; EnableVersioning = $_.EnableVersioning; BaseTemplate = $_.BaseTemplate; Hidden = $_.Hidden; RootFolder = $_.RootFolder } }) } | ConvertTo-Json -Depth 6 -Compress)
  }
  # Groups get the Id of their place in the list (1, 2, ...); levels and roles on the site (T20 r2).
  if ($path -eq 'web/sitegroups') { $i = 0; return (@{ value = @($global:FakeSP.Groups | ForEach-Object { $i++; @{ Id = $i; Title = $_ } }) } | ConvertTo-Json -Depth 4 -Compress) }
  if ($path -eq 'web/roledefinitions') { return (Get-FakeLevelJson) }
  if ($path -match '^web/roleassignments/getbyprincipalid\((\d+)\)/roledefinitionbindings$') {
    if (-not $global:FakeSP.WebRoles.ContainsKey([int]$Matches[1])) { throw 'FAKE 404: the principal holds no role on the site' }
    return (@{ value = @($global:FakeSP.WebRoles[[int]$Matches[1]] | ForEach-Object { @{ Id = $_ } }) } | ConvertTo-Json -Depth 4 -Compress)
  }
  if ($path -match "^web/lists\(guid'([^']+)'\)/(fields|views|rootfolder/files|items)$") {
    $l = Get-FakeListById $Matches[1]
    switch ($Matches[2]) {
      'fields' { return (@{ value = @($l.FieldList | ForEach-Object { @{ InternalName = $_.InternalName; Indexed = $_.Indexed } }) } | ConvertTo-Json -Depth 4 -Compress) }
      'views' { return (@{ value = @($l.ViewList | ForEach-Object { @{ Title = $_.Title } }) } | ConvertTo-Json -Depth 4 -Compress) }
      'items' { return (@{ value = @($l.Items | ForEach-Object { @{ Title = [string]$_.Title } }) } | ConvertTo-Json -Depth 4 -Compress) }
      default { return (@{ value = @($l.Files | ForEach-Object { @{ Name = $_ } }) } | ConvertTo-Json -Depth 4 -Compress) }
    }
  }
  throw ('FAKE 404 GET ' + $path)
}

# Handle a POST inside one list (columns, views, view columns, rows). Takes the list, the route after the list, the parsed body and the whole path (for the 404 message); returns an empty string or throws.
function Send-FakeListRest($l, [string]$rest, $b, [string]$path) {
  if ($rest -eq 'fields/createfieldasxml') {
    $xml = [xml][string]$b.parameters.SchemaXml
    $name = $xml.Field.Name
    if (([string]$b.parameters.SchemaXml).Contains('__')) { throw ('FAKE 400: a placeholder is left in the column XML of ' + $name) }
    if (@($l.FieldList | Where-Object { $_.InternalName -eq $name }).Count) { throw ('FAKE 500: the column ' + $name + ' exists in ' + $l.Title) }
    if ($xml.Field.Type -like 'Lookup*') { $null = Get-FakeListById ($xml.Field.List.Trim('{', '}')) }
    $choices = $null; if ($xml.Field.CHOICES) { $choices = [string[]]@($xml.Field.CHOICES.CHOICE) }
    $f = New-FakeField $name ([string]$xml.Field.DisplayName) $choices
    $f.Indexed = ($xml.Field.Indexed -eq 'TRUE')
    $null = $l.FieldList.Add($f)
    return ''
  }
  if ($rest -eq 'views') {
    if (@($l.ViewList | Where-Object { $_.Title -eq $b.Title }).Count) { throw ('FAKE 500: the view ' + $b.Title + ' exists') }
    $null = $l.ViewList.Add([pscustomobject]@{ Title = [string]$b.Title; Columns = (New-Object System.Collections.ArrayList) })
    return ''
  }
  if ($rest -match "^views/getbytitle\('([^']+)'\)/viewfields/(removeallviewfields|addviewfield\('([^']+)'\))$") {
    $vt = [uri]::UnescapeDataString($Matches[1]); $col = $Matches[3]; $all = ($Matches[2] -eq 'removeallviewfields')
    $v = @($l.ViewList | Where-Object { $_.Title -eq $vt })
    if (-not $v.Count) { throw ('FAKE 404: no view ' + $vt) }
    if ($all) { $v[0].Columns.Clear(); return '' }
    if ($col -ne 'LinkTitle' -and -not @($l.FieldList | Where-Object { $_.InternalName -eq $col }).Count) { throw ('FAKE 400: the view names a column the list does not have: ' + $col) }
    $null = $v[0].Columns.Add($col)
    return ''
  }
  if ($rest -eq 'items') {
    foreach ($prop in $b.PSObject.Properties) {
      if ($prop.Name -eq '__metadata') { continue }
      $col = $prop.Name -replace 'Id$', ''
      if (-not @($l.FieldList | Where-Object { $_.InternalName -eq $prop.Name -or $_.InternalName -eq $col }).Count) { throw ('FAKE 400: the row names a column the list does not have: ' + $prop.Name) }
    }
    $null = $l.Items.Add($b)
    return ''
  }
  throw ('FAKE 404 POST ' + $path)
}

# Handle a REST POST: count it, apply the failure switches, then create a list or pass the request to the list route. Takes the path after /_api/, the JSON body and the full address; returns an empty string or throws.
function Send-FakeRestPost([string]$path, $Content, [string]$Url) {
  $b = $Content | ConvertFrom-Json
  if ($global:FakeSP.FailOn -and $path.EndsWith($global:FakeSP.FailOn)) { throw ('FAKE 500: the service refused ' + $Url) }
  if ($global:FakeSP.FailAfter -gt 0 -and $global:FakeSP.Posts -ge $global:FakeSP.FailAfter) { throw ('FAKE 429: throttled at ' + $Url) }
  $global:FakeSP.Posts++
  if ($path -like 'web/lists*') { $null = $global:FakeSP.Sent.Add([string]$Content) }   # the payload requests only
  if ($path -like 'web/sitegroups' -or $path -like 'web/role*') { return (Send-FakeWebRest $path $b) }
  if ($path -eq 'web/lists') {
    if ($b.__metadata.type -ne 'SP.List') { throw 'FAKE 400: SP.List expected' }
    if (@($global:FakeSP.Lists | Where-Object { $_.Title -eq $b.Title }).Count) { throw ('FAKE 500: a list titled ' + $b.Title + ' exists') }
    $l = Add-FakeList ([string]$b.Title) ([int]$b.BaseTemplate) ([string]$b.Title)
    $l.EnableVersioning = [bool]$b.EnableVersioning
    return ''
  }
  if ($path -notmatch "^web/lists\(guid'([^']+)'\)/(.+)$") { throw ('FAKE 404 POST ' + $path) }
  $l = Get-FakeListById $Matches[1]; $rest = $Matches[2]
  return (Send-FakeListRest $l $rest $b $path)
}

<#
.SYNOPSIS
  Handle a POST on the site itself (T20 r2): make a group or a permission level, or give a level to a group. A name that is
  there already, an unknown group or level, or a role given twice throws, as SharePoint refuses it.
.PARAMETER path
  The path after /_api/.
.PARAMETER b
  The parsed request body.
.OUTPUTS
  System.String. An empty string.
#>
function Send-FakeWebRest([string]$path, $b) {
  if ($path -eq 'web/sitegroups') {
    if ($b.__metadata.type -ne 'SP.Group' -or $global:FakeSP.Groups -contains $b.Title) { throw ('FAKE 400: group not made: ' + $b.Title) }
    $global:FakeSP.Groups = @($global:FakeSP.Groups) + [string]$b.Title; return ''
  }
  if ($path -eq 'web/roledefinitions') {
    if ($b.__metadata.type -ne 'SP.RoleDefinition' -or $b.BasePermissions.__metadata.type -ne 'SP.BasePermissions') { throw 'FAKE 400: SP.RoleDefinition with SP.BasePermissions expected' }
    if (@($global:FakeSP.Levels | Where-Object { $_['Name'] -eq $b.Name }).Count) { throw ('FAKE 500: a level named ' + $b.Name + ' exists') }
    $id = [int](($global:FakeSP.Levels | ForEach-Object { $_['Id'] } | Measure-Object -Maximum).Maximum) + 1
    $level = New-FakeLevel $id ([string]$b.Name) 0 ([string]$b.BasePermissions.High) ([string]$b.BasePermissions.Low)
    $null = $global:FakeSP.Levels.Add($level)
    return ''
  }
  if ($path -match '^web/roleassignments/addroleassignment\(principalid=(\d+),roledefid=(\d+)\)$') {
    $p = [int]$Matches[1]; $d = [int]$Matches[2]
    if ($p -lt 1 -or $p -gt @($global:FakeSP.Groups).Count -or -not @($global:FakeSP.Levels | Where-Object { $_['Id'] -eq $d }).Count) { throw 'FAKE 404: no such group or level' }
    if (@($global:FakeSP.WebRoles[$p]) -contains $d) { throw 'FAKE 500: the group holds that level already' }
    $global:FakeSP.WebRoles[$p] = @(@($global:FakeSP.WebRoles[$p]) | Where-Object { $_ }) + $d; return ''
  }
  throw ('FAKE 404 POST ' + $path)
}

# Fake Invoke-PnPSPRestMethod: checks the call the way the gov device needs it (connected, -Raw, site address, POST headers), then answers a GET or handles a POST.
function Invoke-PnPSPRestMethod {
  [CmdletBinding()]
  param([string]$Method = 'Get', [string]$Url, $Content, [string]$ContentType = 'application/json', [string]$Accept = 'application/json;odata=nometadata', [switch]$Raw)
  if (-not $global:FakeSP.Connected) { throw 'FAKE: not connected' }
  if (-not $Raw) { throw 'FAKE: the script must use -Raw (an empty answer breaks the parsed form in PnP 1.12.0)' }
  if (-not $Url.StartsWith($global:FakeSP.Url.TrimEnd('/') + '/_api/')) { throw 'FAKE: the address must be the site address + /_api/...' }
  $path = $Url.Substring($global:FakeSP.Url.TrimEnd('/').Length + 6)
  $query = ''
  $q = $path.IndexOf('?'); if ($q -ge 0) { $query = $path.Substring($q + 1); $path = $path.Substring(0, $q) }
  $null = $query
  if ($Method -eq 'Get') {
    $global:FakeSP.Gets++
    return (Get-FakeRestAnswer $path)
  }
  if ($Method -ne 'Post') { throw ('FAKE: method ' + $Method + ' is not used by the script (MERGE goes through CSOM)') }
  if ($ContentType -ne 'application/json;odata=verbose') { throw 'FAKE 415: a POST needs application/json;odata=verbose' }
  if ($Content -isnot [string]) { throw 'FAKE: the body must be a JSON string' }
  return (Send-FakeRestPost $path $Content $Url)
}

Export-ModuleMember -Function Connect-PnPOnline, Disconnect-PnPOnline, Get-PnPContext, Get-PnPList, Invoke-PnPSPRestMethod, New-FakeSite, Add-FakeList,
  Set-FakeLevelBits, Get-PnPField, Add-PnPFieldFromXml, Get-PnPListItem, Set-PnPListItem
