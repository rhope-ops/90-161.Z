# Test-T21.Site.ps1: the fake site and its fake PnP cmdlets for tests/ps/Test-T21.ps1 (part 2 of that test).
# Run only by Test-T21.ps1, which dot-sources it (same scope: it shares $global:F, $script:pass and the paths set there). Do not run it alone.
# Network: none (the fake site lives in memory; the fake address host is example.test).
# Writes: only the fake site in memory and the files the T21 test makes in its own temporary folder, which it removes at the end.
# Credentials: none (fake DODID and fake e-mail addresses only).

# ---- the fake site and its cmdlets ----
# Reset the fake site: two lists (a library and another probe list) and all switches off. R35 (F2 B): the group PFM Office
# (Id 9, with its level made by T20 r2) and the people who can edit every row already. Takes nothing; returns nothing.
function New-Site {
  if (Test-Path -LiteralPath $state) { Remove-Item -LiteralPath $state }
  $global:F = @{ Lists = (New-Object System.Collections.ArrayList); Connected = $false; Created = 0; Uploads = 0; Rests = 0; Recycled = (New-Object System.Collections.ArrayList)
    Visitors = 7; RowId = 100; Gets = 0; OnAdd = $null; OnGet = $null; Query = ''; Groups = @{ 'PFM Office' = 9; 'Members' = 8 }; NoOfficeLevel = $false; EditAllUsers = @()
    Users = @{ 'second.person@fake.example' = 31; 'member.person@fake.example' = 32 }; GroupUsers = @{ 7 = @(3, 4); 9 = @(3) }
    CsomWorks = $true; MergeWorks = $true; AddRefused = $false; RemoveRefused = $false; Views = (New-Object System.Collections.ArrayList); ViewsMade = 0; Added = 0 }
  $null = Add-SiteList 'Documents' 'Shared Documents' 101; $null = Add-SiteList 'Other probe list' 'Lists/OtherProbe' 100
}
# Add a fake list with its content type. Takes the title, folder URL and template number (101 library, 100 list); returns the list object.
function Add-SiteList([string]$Title, [string]$Folder, [int]$Template) {
  $ct = [pscustomobject]@{ Id = '0x0100FAKE'; ClientFormCustomFormatter = '' }
  $ct | Add-Member -MemberType ScriptMethod -Name Update -Value { param($x) }
  $l = [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); Title = $Title; Folder = ($Folder -split '/')[-1]; Template = $Template; Hidden = $false
    Fields = (New-Object System.Collections.ArrayList); Files = (New-Object System.Collections.ArrayList); Items = (New-Object System.Collections.ArrayList)
    Unique = $false; Roles = @{ 5 = @(1073741829); 7 = @(1073741826) }; CT = $ct; WriteSecurity = 1 }
  $null = $global:F.Lists.Add($l); return $l
}
# Find a fake list by id. Takes the id text; returns the list or throws a 404 message.
function Get-FakeList([string]$Id) { $h = @($global:F.Lists | Where-Object { $_.Id -eq $Id }); if (-not $h.Count) { throw ('FAKE 404 list ' + $Id) }; return $h[0] }
# Find a fake list by title. Takes the title; returns the list or throws.
function Get-FakeListByTitle([string]$Title) { $h = @($global:F.Lists | Where-Object { $_.Title -eq $Title }); if (-not $h.Count) { throw ('FAKE: no list titled ' + $Title) }; return $h[0] }
# Fake Connect-PnPOnline: accepts only -UseWebLogin, as on the gov device, and records the address.
function Connect-PnPOnline { [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin) if (-not $UseWebLogin) { throw 'FAKE: -UseWebLogin only' }; $global:F.Connected = $true; $global:F.Url = $Url }
# Fake Disconnect-PnPOnline: marks the fake site as not connected.
function Disconnect-PnPOnline { [CmdletBinding()] param() $global:F.Connected = $false }
# Fake New-PnPList: creates a list or library; throws when the title or folder exists. Counts the creation.
function New-PnPList {
  [CmdletBinding()] param([string]$Title, [string]$Template, [string]$Url)
  if (@($global:F.Lists | Where-Object { $_.Title -eq $Title -or $_.Folder -eq ($Url -split '/')[-1] }).Count) { throw 'FAKE 500: list exists' }
  $global:F.Created++; $null = Add-SiteList $Title $Url $(if ($Template -eq 'DocumentLibrary') { 101 } else { 100 }) }
<#
.SYNOPSIS
  Fake Get-PnPContext: the CSOM route (GetById on lists, content types and views) that gives an object whose property can be set.
.OUTPUTS
  The fake context object, with the Lists, ContentTypes and Views the script reads.
#>
function Get-PnPContext {
  [CmdletBinding()] param()
  $lists = [pscustomobject]@{}
  $lists | Add-Member -MemberType ScriptMethod -Name GetById -Value {
    param([guid]$Id)
    $l = Get-FakeList $Id.ToString()
    $cts = [pscustomobject]@{}
    $cts | Add-Member -MemberType ScriptMethod -Name GetById -Value { param([string]$CtId) if ($global:F.CsomWorks) { return $l.CT } else { $o = [pscustomobject]@{};
      $o | Add-Member -MemberType ScriptMethod -Name Update -Value { param($x) }; return $o } }.GetNewClosure()
    $vws = [pscustomobject]@{}
    $vws | Add-Member -MemberType ScriptMethod -Name GetById -Value { param([guid]$VId)
      if ($global:F.CsomWorks) { return @($global:F.Views | Where-Object { $_.Id -eq $VId.ToString() })[0] } else { $o = [pscustomobject]@{};
      $o | Add-Member -MemberType ScriptMethod -Name Update -Value { }; return $o } }.GetNewClosure()
    # R35: WriteSecurity is set on the CSOM list object and saved by Update ("edit own rows" = 2).
    $o = [pscustomobject]@{ ContentTypes = $cts; Views = $vws; WriteSecurity = $l.WriteSecurity }
    $o | Add-Member -MemberType ScriptMethod -Name Update -Value { $l.WriteSecurity = [int]$this.WriteSecurity }.GetNewClosure()
    return $o
  }
  $ctx = [pscustomobject]@{ Web = [pscustomobject]@{ Lists = $lists } }
  $ctx | Add-Member -MemberType ScriptMethod -Name ExecuteQuery -Value { }
  return $ctx
}
# Fake Add-PnPFile: puts a file name into the library with that folder name; counts the upload.
function Add-PnPFile {
  [CmdletBinding()] param([string]$Path, [string]$Folder)
  $lib = @($global:F.Lists | Where-Object { $_.Folder -eq $Folder }); if (-not $lib.Count) { throw 'FAKE 404 folder' }
  $null = $lib[0].Files.Add((Split-Path -Leaf $Path)); $global:F.Uploads++ }
# Fake Add-PnPListItem: adds a row to a list by title and returns it; runs the OnAdd hook when set. R35: the row is yours
# (author and last editor: you are user 11).
function Add-PnPListItem {
  [CmdletBinding()] param([string]$List, [hashtable]$Values)
  $l = Get-FakeListByTitle $List; $global:F.RowId++
  $item = @{ Id = $global:F.RowId; Title = ''; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = [pscustomobject]@{ LookupId = 11 };
    Editor = [pscustomobject]@{ LookupId = 11 } }
  foreach ($k in $Values.Keys) { $item[$k] = $Values[$k] }
  $null = $l.Items.Add($item); if ($global:F.OnAdd) { & $global:F.OnAdd $l $item }
  return $item }
# Fake Get-PnPListItem: returns the rows of a list by title; counts the read and runs the OnGet hook when set.
function Get-PnPListItem {
  [CmdletBinding()] param([string]$List, [string[]]$Fields, [int]$PageSize)
  $global:F.Gets++; if ($global:F.OnGet) { & $global:F.OnGet }
  return @((Get-FakeListByTitle $List).Items) }
# Fake Add-PnPView: adds a view to a list by title and counts it.
function Add-PnPView {
  [CmdletBinding()] param([string]$List, [string]$Title, [string[]]$Fields)
  $l = Get-FakeListByTitle $List; $global:F.ViewsMade++
  $v = [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); Title = $Title; ListId = $l.Id; CustomFormatter = '' }
  $v | Add-Member -MemberType ScriptMethod -Name Update -Value { }; $null = $global:F.Views.Add($v) }
# Fake Add-PnPGroupMember: adds a known user (by login name) to a group; throws when refused or unknown.
function Add-PnPGroupMember {
  [CmdletBinding()] param([string]$LoginName, $Group)
  if ($global:F.AddRefused) { throw ('FAKE 403: access denied for ' + $LoginName + ' (getbyemail(''' + ($LoginName -replace '^.*\|', '' -replace '@', '%40') + '''))') }
  if ($LoginName -notmatch '^i:0#\.f\|membership\|(.+)$') { throw 'FAKE: the login name has the wrong form' }
  if (-not $global:F.Users.ContainsKey($Matches[1])) { throw 'FAKE 404: no such user' }
  $g = [int]$Group
  $global:F.GroupUsers[$g] = @($global:F.GroupUsers[$g]) + $global:F.Users[$Matches[1]]
  $global:F.Added++
}
# Fake Remove-PnPList: moves a list to the fake recycle bin; throws when -Recycle is missing (never a permanent delete). Like the
# real cmdlet it returns the Recycle Bin item (R29a finding 7: the script must not print it).
function Remove-PnPList {
  [CmdletBinding()] param([string]$Identity, [switch]$Recycle, [switch]$Force)
  if (-not $Recycle) { throw 'FAKE: the script must use -Recycle (never a permanent delete)' }
  $l = Get-FakeList $Identity; $global:F.Lists.Remove($l); $null = $global:F.Recycled.Add($l.Title)
  return [pscustomobject]@{ RecycleBinItemId = [guid]::NewGuid().ToString() } }
<#
.SYNOPSIS
  Answer a REST GET of the fake site.
.PARAMETER path
  The path after /_api/, with no query.
.OUTPUTS
  JSON text, or a thrown 404 message.
#>
function Get-FakeRestAnswer([string]$path) {
  if ($path -eq 'web/lists') {
    return (@{ value = @($global:F.Lists | ForEach-Object { @{ Id = $_.Id; Title = $_.Title; ItemCount = $_.Items.Count; BaseTemplate = $_.Template; Hidden = $_.Hidden;
      HasUniqueRoleAssignments = $_.Unique; RootFolder = @{ Name = $_.Folder } } }) } | ConvertTo-Json -Depth 6 -Compress)
  }
  if ($path -eq 'web/associatedvisitorgroup') { return (@{ Id = $global:F.Visitors } | ConvertTo-Json -Compress) }
  if ($path -eq 'web/roledefinitions') { return (@{ value = @(Get-FakeLevel) } | ConvertTo-Json -Compress -Depth 4) }
  if ($path -match "^web/sitegroups/getbyname\('([^']+)'\)$") { return (@{ Id = $global:F.Groups[[uri]::UnescapeDataString($Matches[1])] } | ConvertTo-Json -Compress) }
  if ($path -match '^web/getuserbyid\((\d+)\)$') { $id = [int]$Matches[1];
    return ('{"LoginName":"i:0#.f|membership|' + @($global:F.Users.Keys | Where-Object { $global:F.Users[$_] -eq $id })[0] + '"}') }
  if ($path -match "^web/lists\(guid'([^']+)'\)$") { return (@{ WriteSecurity = (Get-FakeList $Matches[1]).WriteSecurity } | ConvertTo-Json -Compress) }
  if ($path -match "^web/lists\(guid'([^']+)'\)/getusereffectivepermissions\(@u\)$") { return (Get-FakeEffective (Get-FakeList $Matches[1])) }
  if ($path -eq 'web/currentuser') { return (@{ Id = 11 } | ConvertTo-Json -Compress) }
  if ($path -match '^web/sitegroups/getbyid\((\d+)\)/users$') { if ([int]$Matches[1] -eq $global:F.FailGroupRead) { throw 'FAKE 404: no such group' };
    return (@{ value = @(@($global:F.GroupUsers[[int]$Matches[1]]) | Where-Object { $_ } | ForEach-Object { @{ Id = $_ } }) } | ConvertTo-Json -Compress) }
  if ($path -match "^web/siteusers/getbyemail\('([^']+)'\)$") {
    $a = [uri]::UnescapeDataString($Matches[1])
    if (-not $global:F.Users.ContainsKey($a) -or $global:F.NoGetByEmail) { throw ('FAKE 404 user ' + $a) }
    return ('{"Id":' + $global:F.Users[$a] + ',"LoginName":"i:0#.f|membership|' + $a + '"}')
  }
  if ($path -match "^web/lists\(guid'([^']+)'\)/(fields|rootfolder/files|contenttypes|views)$") {
    $l = Get-FakeList $Matches[1]
    switch ($Matches[2]) {
      'fields' { return (@{ value = @($l.Fields | ForEach-Object { @{ InternalName = $_ } }) } | ConvertTo-Json -Compress) }
      'contenttypes' { return (@{ value = @(@{ Id = @{ StringValue = $l.CT.Id }; Name = 'Item' }) } | ConvertTo-Json -Compress -Depth 4) }
      'views' { return (@{ value = @($global:F.Views | Where-Object { $_.ListId -eq $l.Id } | ForEach-Object { @{ Id = $_.Id; Title = $_.Title } }) } | ConvertTo-Json -Compress -Depth 4) }
      default { return (@{ value = @($l.Files | ForEach-Object { @{ Name = $_; ServerRelativeUrl = ('/sites/FakeWing/' + $l.Folder + '/' + $_); Length = 1000 } }) } | ConvertTo-Json -Compress) }
    }
  }
  if ($path -match "^web/lists\(guid'([^']+)'\)/contenttypes\('([^']+)'\)$") {
    return (@{ ClientFormCustomFormatter = (Get-FakeList $Matches[1]).CT.ClientFormCustomFormatter } | ConvertTo-Json -Compress) }
  if ($path -match "^web/lists\(guid'([^']+)'\)/views\(guid'([^']+)'\)$") {
    $vid = $Matches[2]; $v = @($global:F.Views | Where-Object { $_.Id -eq $vid })
    if (-not $v.Count) { throw 'FAKE 404 view' }
    return (@{ CustomFormatter = $v[0].CustomFormatter } | ConvertTo-Json -Compress)
  }
  if ($path -match "^web/lists\(guid'([^']+)'\)/roleassignments/getbyprincipalid\((\d+)\)/roledefinitionbindings$") {
    $l = Get-FakeList $Matches[1]; $p = [int]$Matches[2]
    if (-not $l.Roles.ContainsKey($p)) { throw 'FAKE 404: no such principal' }
    return (@{ value = @($l.Roles[$p] | ForEach-Object { @{ Id = $_ } }) } | ConvertTo-Json -Compress)
  }
  throw ('FAKE 404 GET ' + $path)
}

# The fake permission levels: Contribute first (Make takes the first one of its query), then the PFM Office level of T20 r2
# (Edit plus Override List Behaviors) unless the switch NoOfficeLevel is on. Returns the level objects.
function Get-FakeLevel {
  $lv = @(@{ Id = 1073741827; Name = 'Contribute'; BasePermissions = @{ High = '432'; Low = '1011028719' } })
  if (-not $global:F.NoOfficeLevel) { $lv += @{ Id = 1073741930; Name = 'PFM Office Edit All Items'; BasePermissions = @{ High = '432'; Low = '1011031023' } } }
  return $lv
}
# The effective permission of the person named in the query (@u) on a fake list: everything for a person in EditAllUsers;
# the PFM Office level for a member of group 9 when the list gives it that level; else Contribute or Read. Returns JSON.
function Get-FakeEffective($l) {
  if ($global:F.Query -notmatch "@u='([^']+)'") { throw 'FAKE 400: no @u' }
  $uid = $global:F.Users[([uri]::UnescapeDataString($Matches[1]) -replace '^i:0#\.f\|membership\|', '')]; $low = '138612833'
  if ($global:F.EditAllUsers -contains $uid) { $low = '4294705151' }
  elseif (@($global:F.GroupUsers[9]) -contains $uid -and @($l.Roles[9]) -contains 1073741930) { $low = '1011031023' }
  elseif (@($global:F.GroupUsers[7]) -contains $uid -and @($l.Roles[7]) -contains 1073741827) { $low = '1011028719' }
  return ('{"High":"432","Low":"' + $low + '"}')
}

# Answer a MERGE on a list (the content type or view formatter). Takes the list, the route after the list, the body text and the path; returns an empty string or throws.
function Merge-FakeRest($l, [string]$rest, [string]$Content, [string]$path) {
  if (-not $global:F.MergeWorks) { throw 'FAKE 405: merge refused' }
  $b = $Content | ConvertFrom-Json
  if ($rest -match "^contenttypes\('([^']+)'\)$" -and $b.__metadata.type -eq 'SP.ContentType') { $l.CT.ClientFormCustomFormatter = [string]$b.ClientFormCustomFormatter; return '' }
  if ($rest -match "^views\(guid'([^']+)'\)$" -and $b.__metadata.type -eq 'SP.View') { $vid = $Matches[1];
    @($global:F.Views | Where-Object { $_.Id -eq $vid })[0].CustomFormatter = [string]$b.CustomFormatter; return '' }
  throw ('FAKE 404 MERGE ' + $path)
}

<#
.SYNOPSIS
  Answer a POST on a list (create a column, break inheritance, add a role).
.PARAMETER l
  The fake list.
.PARAMETER rest
  The route after the list.
.PARAMETER Content
  The request body text.
.PARAMETER path
  The whole path, for the messages.
.OUTPUTS
  An empty string, or a thrown message.
#>
function Send-FakeListRest($l, [string]$rest, [string]$Content, [string]$path) {
  if ($rest -eq 'fields/createfieldasxml') {
    $b = $Content | ConvertFrom-Json
    $xml = [xml][string]$b.parameters.SchemaXml
    $name = $xml.Field.Name
    if ($l.Fields -contains $name) { throw ('FAKE 500: column ' + $name + ' exists') }
    $null = $l.Fields.Add($name); return ''
  }
  if ($rest -match '^breakroleinheritance\(copyRoleAssignments=true,clearSubscopes=true\)$') { $l.Unique = $true; return '' }
  if ($rest -match '^roleassignments/addroleassignment\(principalid=(\d+),roledefid=(\d+)\)$') {
    if (-not $l.Unique) { throw 'FAKE 400: the list still inherits its permissions (that would change the site)' }
    $p = [int]$Matches[1]; $d = [int]$Matches[2]
    if (-not $l.Roles.ContainsKey($p)) { $l.Roles[$p] = @() }
    $l.Roles[$p] = @($l.Roles[$p]) + $d; return ''
  }
  throw ('FAKE 404 POST ' + $path)
}

<#
.SYNOPSIS
  Answer a POST or MERGE of the fake site: ensure a user, remove a group user, or route to a list.
.PARAMETER Method
  POST or MERGE.
.PARAMETER path
  The path after /_api/.
.PARAMETER Content
  The request body text.
.OUTPUTS
  An empty string, JSON text, or a thrown message.
#>
function Send-FakeRest([string]$Method, [string]$path, [string]$Content) {
  if ($path -eq 'web/ensureuser') {
    $b = $Content | ConvertFrom-Json
    if ($b.logonName -notmatch '^i:0#\.f\|membership\|(.+)$' -or -not $global:F.Users.ContainsKey($Matches[1])) { throw 'FAKE 404: ensureuser found no one' }
    return ('{"Id":' + $global:F.Users[$Matches[1]] + ',"IsHiddenInUI":false,"LoginName":"' + $b.logonName + '","Title":"FAKE NAME","Email":"' + $Matches[1] + '"}')
  }
  if ($path -match '^web/sitegroups/getbyid\((\d+)\)/users/removebyid\((\d+)\)$') {
    if ($global:F.RemoveRefused) { throw 'FAKE 403: not allowed' }
    $g = [int]$Matches[1]; $u = [int]$Matches[2]
    $global:F.GroupUsers[$g] = @(@($global:F.GroupUsers[$g]) | Where-Object { $_ -ne $u }); return ''
  }
  if ($path -notmatch "^web/lists\(guid'([^']+)'\)/(.+)$") { throw ('FAKE 404 POST ' + $path) }
  $l = Get-FakeList $Matches[1]; $rest = $Matches[2]
  if ($Method -eq 'Merge') { return (Merge-FakeRest $l $rest $Content $path) }
  return (Send-FakeListRest $l $rest $Content $path)
}

<#
.SYNOPSIS
  Fake Invoke-PnPSPRestMethod: checks the call as the gov device needs it (connected, -Raw, address, headers), then answers a GET or routes a POST or MERGE.
.PARAMETER Method
  The HTTP verb: Get (the default), Post or Merge.
.PARAMETER Url
  The full request address.
.PARAMETER Content
  The request body text, for a POST or MERGE.
.PARAMETER ContentType
  The Content-Type header; the default is application/json.
.PARAMETER Accept
  The Accept header; the default is application/json;odata=nometadata.
.PARAMETER Raw
  Required switch: the script must ask for the raw answer.
.OUTPUTS
  The answer text of the fake route, or a thrown FAKE message.
#>
function Invoke-PnPSPRestMethod {
  [CmdletBinding()] param([string]$Method = 'Get', [string]$Url, $Content, [string]$ContentType = 'application/json', [string]$Accept = 'application/json;odata=nometadata', [switch]$Raw)
  if (-not $global:F.Connected) { throw 'FAKE: not connected' }
  if (-not $Raw) { throw 'FAKE: the script must use -Raw' }
  $prefix = $global:F.Url.TrimEnd('/') + '/_api/'
  if (-not $Url.StartsWith($prefix)) { throw 'FAKE: the address must be the site address + /_api/...' }
  $path = $Url.Substring($prefix.Length)
  $q = $path.IndexOf('?'); if ($q -ge 0) { $global:F.Query = $path.Substring($q + 1); $path = $path.Substring(0, $q) }
  $global:F.Rests++
  if ($Method -eq 'Get') { return (Get-FakeRestAnswer $path) }
  if ($Method -notin 'Post', 'Merge') { throw 'FAKE: only GET, POST and MERGE' }
  if ($ContentType -ne 'application/json;odata=verbose') { throw 'FAKE 415' }
  if ($Content -isnot [string]) { throw 'FAKE: the body must be a string' }
  return (Send-FakeRest $Method $path $Content)
}

# Run one part of the T21 probe script against the fake site. Takes the part name, extra script parameters and a label; returns a hashtable with Code (exit code), Out (lines), Text (joined)
# and File (the result file text, or empty).
function Invoke-T21([string]$Part, [hashtable]$Extra = @{}, [string]$Label = '') {
  $Extra2 = @{} + $Extra; if ($Label) { $Extra2['Label'] = $Label }
  $global:LASTEXITCODE = 0
  $out = & $script -Id 'tester01' -Part $Part -NoPause -NoLaunch -TestDir $t21 @Extra2 *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t21 ('90161Z-T21-probe-' + $Part.ToLowerInvariant() + $(if ($Label) { '-' + $Label } else { '' }) + '-r11.txt')
  $r = @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
  if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
  return $r
}
$allText = New-Object System.Text.StringBuilder
$nowParts = New-Object System.Collections.Generic.List[string]; $nowInFile = New-Object System.Collections.Generic.List[string]
# Keep the screen text and the result file of one run for the later checks, and note the NOW lines: a part that printed one,
# and a result file that holds one (it must hold none). Takes the run hashtable; returns nothing.
function Note([hashtable]$R) {
  [void]$allText.AppendLine($R.Text); [void]$allText.AppendLine($R.File)
  $p = @($R.Out | Where-Object { $_ -match '^TASK T21 probe r11, part (\w+)' } | ForEach-Object { $Matches[1] })
  if (@($R.Out | Where-Object { $_ -match '^NOW \S' }).Count -and $p.Count) { $nowParts.Add($p[0]) }
  if ($R.File -match '(?m)^NOW ') { $nowInFile.Add([string]$p) }
}
# Find a probe list or library by folder name. Takes the folder; returns the fake list.
function Get-Probe([string]$Folder) { return @($global:F.Lists | Where-Object { $_.Folder -eq $Folder })[0] }
# Add a RESULT row to a fake probe list. Takes the list and the test, way, result and detail text; returns nothing.
function Add-Res($l, [string]$T, [string]$W, [string]$R, [string]$D) { $global:F.RowId++; $null = $l.Items.Add(@{ Id = $global:F.RowId; Title = 'RESULT'; ProbeTest = $T; ProbeWay = $W;
  ProbeResult = $R; ProbeDetail = $D; Author = [pscustomobject]@{ LookupId = 11 } }) }
# Add a row with a title and an author id (0 = no author) to a fake probe list. Returns nothing.
function Add-Row($l, [string]$Title, [int]$Author) { $global:F.RowId++; $null = $l.Items.Add(@{ Id = $global:F.RowId; Title = $Title; ProbeTest = ''; ProbeWay = ''; ProbeResult = '';
  ProbeDetail = ''; Author = $(if ($Author) { [pscustomobject]@{ LookupId = $Author } } else { $null }) }) }
