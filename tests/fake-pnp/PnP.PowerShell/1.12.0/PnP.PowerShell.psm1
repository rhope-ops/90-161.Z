# Fake PnP.PowerShell for tests/ps/Test-T20.ps1 (cloud tests only; never goes to the gov device).
# It keeps a small site in $global:FakeSP and answers the cmdlets and REST routes that the T20 script uses.
# It is strict on purpose: a request the real SharePoint would refuse (unknown list, a column twice, a row that names
# a column the list does not have, a lookup to a list id that does not exist, a placeholder left in the XML) throws.
# It proves the script's logic and order, not the real service: the gov device round is that proof.

# Reset the fake site: an empty site with one Documents library. Takes nothing; returns nothing.
function New-FakeSite {
  $global:FakeSP = @{ Lists = (New-Object System.Collections.ArrayList); Groups = @(); Posts = 0; Gets = 0; Connected = $false; Url = ''; FailOn = ''; FailAfter = 0; Sent = (New-Object System.Collections.ArrayList) }
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

# Make one fake column from its internal name and title. Returns the column object.
function New-FakeField([string]$Internal, [string]$Title) {
  $f = [pscustomobject]@{ InternalName = $Internal; Title = $Title; Indexed = $false }
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

# Fake Get-PnPContext: returns a context whose Web.Lists.GetById(guid) finds a fake list and whose ExecuteQuery does nothing.
function Get-PnPContext {
  [CmdletBinding()] param()
  $lists = [pscustomobject]@{}
  $lists | Add-Member -MemberType ScriptMethod -Name GetById -Value { param([guid]$Id) return (Get-FakeListById $Id.ToString()) }
  $ctx = [pscustomobject]@{ Web = [pscustomobject]@{ Lists = $lists } }
  $ctx | Add-Member -MemberType ScriptMethod -Name ExecuteQuery -Value { }
  return $ctx
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
  if ($path -eq 'web/sitegroups') { return (@{ value = @($global:FakeSP.Groups | ForEach-Object { @{ Title = $_ } }) } | ConvertTo-Json -Depth 4 -Compress) }
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
    $f = New-FakeField $name ([string]$xml.Field.DisplayName)
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
  $null = $global:FakeSP.Sent.Add([string]$Content)
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

Export-ModuleMember -Function Connect-PnPOnline, Disconnect-PnPOnline, Get-PnPContext, Get-PnPList, Invoke-PnPSPRestMethod, New-FakeSite, Add-FakeList
