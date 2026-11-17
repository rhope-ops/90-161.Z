# Tests scripts/gov/90161Z-T21-probe-r3.ps1 (R27 probe, parts Make, Person, Run, Look, Open, Read, Clean) against a small fake site (pwsh 7, cloud only).
# The fake PnP cmdlets are defined here (functions in this file); only an empty PnP.PowerShell 1.12.0 module is put on the
# module path so the script's "is PnP installed" check passes. It proves the script's logic and output; the real service is
# proved by the R27 round on the gov device. Last line: "T21 pass=N fail=0".
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T21TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T21TEST FAIL ' + $Name + ' ' + $Detail) }
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('t21-' + [guid]::NewGuid().ToString('N'))
$t21 = Join-Path $work 'T21'
$null = New-Item -ItemType Directory -Path $t21 -Force
$modDir = Join-Path $work 'mods/PnP.PowerShell/1.12.0'
$null = New-Item -ItemType Directory -Path $modDir -Force
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psm1') -Value '# empty on purpose: the cmdlets are fakes in tests/ps/Test-T21.ps1'
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psd1') -Value "@{ RootModule = 'PnP.PowerShell.psm1'; ModuleVersion = '1.12.0'; GUID = '0b0430ce-d799-4f3b-a565-f0dca1f31e18' }"
$env:PSModulePath = (Join-Path $work 'mods') + [IO.Path]::PathSeparator + $env:PSModulePath
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T21-probe-r3.ps1'
$fakeAddr = 'second.person@fake.example'
$buttonId = '260790dd-beca-5206-83f7-e6aab40c894e'

# ---- the fake site and its cmdlets ----
function New-Site {
  if (Test-Path -LiteralPath $state) { Remove-Item -LiteralPath $state }
  $global:F = @{ Lists = (New-Object System.Collections.ArrayList); Connected = $false; Created = 0; Uploads = 0; Rests = 0; Recycled = (New-Object System.Collections.ArrayList)
    Visitors = 7; RowId = 100; Gets = 0; OnAdd = $null; OnGet = $null
    Users = @{ 'second.person@fake.example' = 31; 'member.person@fake.example' = 32 }; GroupUsers = @{ 7 = @(3, 4) }
    CsomWorks = $true; MergeWorks = $true; AddRefused = $false; RemoveRefused = $false; Views = (New-Object System.Collections.ArrayList); ViewsMade = 0; Added = 0 }
  $null = Add-SiteList 'Documents' 'Shared Documents' 101
  $null = Add-SiteList 'Other probe list' 'Lists/OtherProbe' 100
}
function Add-SiteList([string]$Title, [string]$Folder, [int]$Template) {
  $ct = [pscustomobject]@{ Id = '0x0100FAKE'; ClientFormCustomFormatter = '' }
  $ct | Add-Member -MemberType ScriptMethod -Name Update -Value { param($x) }
  $l = [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); Title = $Title; Folder = ($Folder -split '/')[-1]; Template = $Template; Hidden = $false
    Fields = (New-Object System.Collections.ArrayList); Files = (New-Object System.Collections.ArrayList); Items = (New-Object System.Collections.ArrayList)
    Unique = $false; Roles = @{ 5 = @(1073741829); 7 = @(1073741826) }; CT = $ct }
  $null = $global:F.Lists.Add($l)
  return $l
}
function Get-FakeList([string]$Id) { $h = @($global:F.Lists | Where-Object { $_.Id -eq $Id }); if (-not $h.Count) { throw ('FAKE 404 list ' + $Id) }; return $h[0] }
function Get-FakeListByTitle([string]$Title) { $h = @($global:F.Lists | Where-Object { $_.Title -eq $Title }); if (-not $h.Count) { throw ('FAKE: no list titled ' + $Title) }; return $h[0] }
function Connect-PnPOnline { [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin) if (-not $UseWebLogin) { throw 'FAKE: -UseWebLogin only' }; $global:F.Connected = $true; $global:F.Url = $Url }
function Disconnect-PnPOnline { [CmdletBinding()] param() $global:F.Connected = $false }
function New-PnPList {
  [CmdletBinding()] param([string]$Title, [string]$Template, [string]$Url)
  if (@($global:F.Lists | Where-Object { $_.Title -eq $Title -or $_.Folder -eq ($Url -split '/')[-1] }).Count) { throw 'FAKE 500: list exists' }
  $global:F.Created++
  $null = Add-SiteList $Title $Url $(if ($Template -eq 'DocumentLibrary') { 101 } else { 100 })
}
function Get-PnPContext {
  # The CSOM route: GetById(list).ContentTypes.GetById(id) and .Views.GetById(guid) give an object whose property can be set.
  [CmdletBinding()] param()
  $lists = [pscustomobject]@{}
  $lists | Add-Member -MemberType ScriptMethod -Name GetById -Value {
    param([guid]$Id)
    $l = Get-FakeList $Id.ToString()
    $cts = [pscustomobject]@{}
    $cts | Add-Member -MemberType ScriptMethod -Name GetById -Value { param([string]$CtId) if ($global:F.CsomWorks) { return $l.CT } else { $o = [pscustomobject]@{}; $o | Add-Member -MemberType ScriptMethod -Name Update -Value { param($x) }; return $o } }.GetNewClosure()
    $vws = [pscustomobject]@{}
    $vws | Add-Member -MemberType ScriptMethod -Name GetById -Value { param([guid]$VId) if ($global:F.CsomWorks) { return @($global:F.Views | Where-Object { $_.Id -eq $VId.ToString() })[0] } else { $o = [pscustomobject]@{}; $o | Add-Member -MemberType ScriptMethod -Name Update -Value { }; return $o } }.GetNewClosure()
    return [pscustomobject]@{ ContentTypes = $cts; Views = $vws }
  }
  $ctx = [pscustomobject]@{ Web = [pscustomobject]@{ Lists = $lists } }
  $ctx | Add-Member -MemberType ScriptMethod -Name ExecuteQuery -Value { }
  return $ctx
}
function Add-PnPFile {
  [CmdletBinding()] param([string]$Path, [string]$Folder)
  $lib = @($global:F.Lists | Where-Object { $_.Folder -eq $Folder })
  if (-not $lib.Count) { throw 'FAKE 404 folder' }
  $null = $lib[0].Files.Add((Split-Path -Leaf $Path)); $global:F.Uploads++
}
function Add-PnPListItem {
  [CmdletBinding()] param([string]$List, [hashtable]$Values)
  $l = Get-FakeListByTitle $List
  $global:F.RowId++
  $item = @{ Id = $global:F.RowId; Title = ''; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = $null }
  foreach ($k in $Values.Keys) { $item[$k] = $Values[$k] }
  $null = $l.Items.Add($item)
  if ($global:F.OnAdd) { & $global:F.OnAdd $l $item }
  return $item
}
function Get-PnPListItem {
  [CmdletBinding()] param([string]$List, [string[]]$Fields, [int]$PageSize)
  $global:F.Gets++
  if ($global:F.OnGet) { & $global:F.OnGet }
  return @((Get-FakeListByTitle $List).Items)
}
function Add-PnPView {
  [CmdletBinding()] param([string]$List, [string]$Title, [string[]]$Fields)
  $l = Get-FakeListByTitle $List
  $global:F.ViewsMade++
  $v = [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); Title = $Title; ListId = $l.Id; CustomFormatter = '' }
  $v | Add-Member -MemberType ScriptMethod -Name Update -Value { }
  $null = $global:F.Views.Add($v)
}
function Add-PnPGroupMember {
  [CmdletBinding()] param([string]$LoginName, $Group)
  if ($global:F.AddRefused) { throw 'FAKE 403: access denied for a person' }
  if ($LoginName -notmatch '^i:0#\.f\|membership\|(.+)$') { throw 'FAKE: the login name has the wrong form' }
  if (-not $global:F.Users.ContainsKey($Matches[1])) { throw 'FAKE 404: no such user' }
  $g = [int]$Group
  $global:F.GroupUsers[$g] = @($global:F.GroupUsers[$g]) + $global:F.Users[$Matches[1]]
  $global:F.Added++
}
function Remove-PnPList {
  [CmdletBinding()] param([string]$Identity, [switch]$Recycle, [switch]$Force)
  if (-not $Recycle) { throw 'FAKE: the script must use -Recycle (never a permanent delete)' }
  $l = Get-FakeList $Identity
  $global:F.Lists.Remove($l); $null = $global:F.Recycled.Add($l.Title)
}
function Invoke-PnPSPRestMethod {
  [CmdletBinding()] param([string]$Method = 'Get', [string]$Url, $Content, [string]$ContentType = 'application/json', [string]$Accept = 'application/json;odata=nometadata', [switch]$Raw)
  if (-not $global:F.Connected) { throw 'FAKE: not connected' }
  if (-not $Raw) { throw 'FAKE: the script must use -Raw' }
  $prefix = $global:F.Url.TrimEnd('/') + '/_api/'
  if (-not $Url.StartsWith($prefix)) { throw 'FAKE: the address must be the site address + /_api/...' }
  $path = $Url.Substring($prefix.Length)
  $q = $path.IndexOf('?'); if ($q -ge 0) { $path = $path.Substring(0, $q) }
  $global:F.Rests++
  if ($Method -eq 'Get') {
    if ($path -eq 'web/lists') {
      return (@{ value = @($global:F.Lists | ForEach-Object { @{ Id = $_.Id; Title = $_.Title; ItemCount = $_.Items.Count; BaseTemplate = $_.Template; Hidden = $_.Hidden; HasUniqueRoleAssignments = $_.Unique; RootFolder = @{ Name = $_.Folder } } }) } | ConvertTo-Json -Depth 6 -Compress)
    }
    if ($path -eq 'web/associatedvisitorgroup') { return (@{ Id = $global:F.Visitors } | ConvertTo-Json -Compress) }
    if ($path -eq 'web/roledefinitions') { return (@{ value = @(@{ Id = 1073741827 }) } | ConvertTo-Json -Compress) }
    if ($path -eq 'web/currentuser') { return (@{ Id = 11 } | ConvertTo-Json -Compress) }
    if ($path -match '^web/sitegroups/getbyid\((\d+)\)/users$') { return (@{ value = @(@($global:F.GroupUsers[[int]$Matches[1]]) | Where-Object { $_ } | ForEach-Object { @{ Id = $_ } }) } | ConvertTo-Json -Compress) }
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
    if ($path -match "^web/lists\(guid'([^']+)'\)/contenttypes\('([^']+)'\)$") { return (@{ ClientFormCustomFormatter = (Get-FakeList $Matches[1]).CT.ClientFormCustomFormatter } | ConvertTo-Json -Compress) }
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
  if ($Method -notin 'Post', 'Merge') { throw 'FAKE: only GET, POST and MERGE' }
  if ($ContentType -ne 'application/json;odata=verbose') { throw 'FAKE 415' }
  if ($Content -isnot [string]) { throw 'FAKE: the body must be a string' }
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
  if ($Method -eq 'Merge') {
    if (-not $global:F.MergeWorks) { throw 'FAKE 405: merge refused' }
    $b = $Content | ConvertFrom-Json
    if ($rest -match "^contenttypes\('([^']+)'\)$" -and $b.__metadata.type -eq 'SP.ContentType') { $l.CT.ClientFormCustomFormatter = [string]$b.ClientFormCustomFormatter; return '' }
    if ($rest -match "^views\(guid'([^']+)'\)$" -and $b.__metadata.type -eq 'SP.View') { $vid = $Matches[1]; @($global:F.Views | Where-Object { $_.Id -eq $vid })[0].CustomFormatter = [string]$b.CustomFormatter; return '' }
    throw ('FAKE 404 MERGE ' + $path)
  }
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

function Invoke-T21([string]$Part, [hashtable]$Extra = @{}) {
  $global:LASTEXITCODE = 0
  $out = & $script -Id 'tester01' -Part $Part -NoPause -NoLaunch -TestDir $t21 @Extra *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t21 ('90161Z-T21-probe-' + $Part.ToLowerInvariant() + '-r3.txt')
  $r = @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
  if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
  return $r
}
$allText = New-Object System.Text.StringBuilder
function Note([hashtable]$R) { [void]$allText.AppendLine($R.Text); [void]$allText.AppendLine($R.File) }
function Get-Probe([string]$Folder) { return @($global:F.Lists | Where-Object { $_.Folder -eq $Folder })[0] }
function Add-Res($l, [string]$T, [string]$W, [string]$R, [string]$D) { $global:F.RowId++; $null = $l.Items.Add(@{ Id = $global:F.RowId; Title = 'RESULT'; ProbeTest = $T; ProbeWay = $W; ProbeResult = $R; ProbeDetail = $D; Author = [pscustomobject]@{ LookupId = 11 } }) }
function Add-Row($l, [string]$Title, [int]$Author) { $global:F.RowId++; $null = $l.Items.Add(@{ Id = $global:F.RowId; Title = $Title; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = $(if ($Author) { [pscustomobject]@{ LookupId = $Author } } else { $null }) }) }
$links = Join-Path $t21 '90161Z-T21-links-r3.html'
$state = Join-Path $t21 '90161Z-T21-person-state-r3.txt'

# ---- Make ----
New-Site
$r = Invoke-T21 'Make'; Note $r
$lib = Get-Probe '90161ZProbeFiles'; $lst = Get-Probe '90161ZProbe'
Test-That 'Make: exit 0 and the last line' ($r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Make done: passed=6 failed=0') $r.Text
Test-That 'Make: 1 library and 1 list with the contract titles and folders' ($lib -and $lib.Title -eq '90161Z Probe Files' -and $lib.Template -eq 101 -and $lst -and $lst.Title -eq '90161Z Probe' -and $lst.Template -eq 100 -and $global:F.Created -eq 2)
Test-That 'Make: 4 list columns, none in the library' (($lst.Fields -join ',') -eq 'ProbeTest,ProbeWay,ProbeResult,ProbeDetail' -and $lib.Fields.Count -eq 0)
Test-That 'Make: unique permissions, Visitors keep Read and get Contribute, Full Control kept' ($lst.Unique -and (@($lst.Roles[7]) -join ',') -eq '1073741826,1073741827' -and (@($lst.Roles[5]) -join ',') -eq '1073741829')
Test-That 'Make: 1 workbook uploaded, no macro workbook' ($global:F.Uploads -eq 1 -and ($lib.Files -join ',') -eq '90161Z-T21-fake-book-r1.xlsx')
Test-That 'Make: counts line' ($r.Text -match 'MADE library=1 list=1 columns=4 permission changes=2 files=1')
Test-That 'Make: the other lists are untouched' (-not (Get-FakeListByTitle 'Other probe list').Unique -and (Get-FakeListByTitle 'Documents').Files.Count -eq 0)
$page = Get-Content -LiteralPath $links -Raw
Test-That 'Make: test page with 4 links to the site' ((@([regex]::Matches($page, 'class="go" href="https://fakehost\.example\.test/sites/FakeWing/')).Count -eq 4) -and $page -match 'Lists/90161ZProbe/NewForm\.aspx' -and $page -match 'Lists/90161ZProbe/ProbeButton\.aspx' -and $page -match '90161Z-T21-fake-book-r1\.xlsx\?web=1' -and $page -notmatch '\.xlsm' -and $r.Text -match 'm6-page PASS test page in the T21 folder, links=4') $r.Text
Test-That 'Make: the test page is ASCII and has no script' ($page -notmatch '[^\x00-\x7F]' -and $page -notmatch '<script')
$created = $global:F.Created; $up = $global:F.Uploads
$r = Invoke-T21 'Make'; Note $r
Test-That 'Make twice: changes nothing on the site' ($r.Code -eq 0 -and $r.Text -match 'MADE library=0 list=0 columns=0 permission changes=0 files=0' -and $global:F.Created -eq $created -and $global:F.Uploads -eq $up -and $lst.Fields.Count -eq 4) $r.Text
Test-That 'Make: result file written and equal to the screen lines' ($r.File -match 'PROBE Make done')
New-Site; $global:F.Visitors = 0
$r = Invoke-T21 'Make'; Note $r
Test-That 'Make without a Visitors group: NOTE line, still exit 0' ($r.Code -eq 0 -and $r.Text -match 'NOTE m4: no associated Visitors group' -and $r.Out[-1] -match 'failed=0')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$bookPath = Join-Path $t21 '90161Z-T21-fake-book-r1.xlsx'
function Get-ZipNames([string]$Path) { $z = [System.IO.Compression.ZipFile]::OpenRead($Path); try { return @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() } }
Test-That 'Make: saves the workbook from the text block; it opens as a package with no VBA project' ((Test-Path -LiteralPath $bookPath) -and -not (Test-Path -LiteralPath (Join-Path $t21 '90161Z-T21-fake-macro-r1.xlsm')) -and ((Get-ZipNames $bookPath) -contains 'xl/workbook.xml') -and -not ((Get-ZipNames $bookPath) -contains 'xl/vbaProject.bin') -and $r.Text -match 'm5a-workbooks INFO fake workbook saved to the T21 folder now=0')
(Get-Item -LiteralPath $bookPath).LastWriteTime = [datetime]'2001-01-01'
$null = Invoke-T21 'Make'
Test-That 'Make twice: a workbook with the same bytes is not written again' ((Get-Item -LiteralPath $bookPath).LastWriteTime -eq [datetime]'2001-01-01')
Set-Content -LiteralPath $bookPath -Value 'broken'
$r = Invoke-T21 'Make'
Test-That 'Make: a workbook with other bytes is written again' ($r.Text -match 'now=1' -and ((Get-ZipNames $bookPath) -contains 'xl/workbook.xml'))

# ---- Open (no sign-in) ----
Remove-Item -LiteralPath $links
$global:F.Connected = $false; $rests = $global:F.Rests
$r = Invoke-T21 'Open'; Note $r
Test-That 'Open: writes the test page again, no sign-in, no result file' ($r.Code -eq 0 -and (Test-Path -LiteralPath $links) -and $global:F.Rests -eq $rests -and -not $global:F.Connected -and $r.Out[-1] -eq 'PROBE Open done: passed=2 failed=0' -and $r.File -eq '') $r.Text

# ---- Person ----
New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = $fakeAddr
$r = Invoke-T21 'Person'; Note $r
$stateText = $(if (Test-Path -LiteralPath $state) { Get-Content -LiteralPath $state -Raw } else { '' })
Test-That 'Person: added to Visitors yes, exit 0, last line' ($r.Code -eq 0 -and $r.Text -match 'VISITORS added to Visitors: yes; status: added and listed in the group' -and $r.Out[-1] -eq 'PROBE Person done: passed=3 failed=0' -and (@($global:F.GroupUsers[7]) -contains 31)) $r.Text
Test-That 'Person: the state file holds only 3 numbers or flags (no address, no name)' ($stateText -match '(?m)^UserId=31\r?$' -and $stateText -match '(?m)^GroupId=7\r?$' -and $stateText -match '(?m)^WasMember=no\r?$' -and $stateText -notmatch '@|fake|person') $stateText
Test-That 'Person: the address is not in the screen lines, the result file or the state file' ($r.Text -notmatch 'second\.person|fake\.example|@' -and $r.File -notmatch 'second\.person|fake\.example|@') $r.Text
Test-That 'Person: the clipboard step is a test-run note' ($r.Text -match 'p4-link INFO the link of the new row form is on the clipboard=no \(test run\)')
$env:T21_TEST_ADDRESS = 'member.person@fake.example'; $global:F.GroupUsers[7] = @(3, 4, 32); Remove-Item -LiteralPath $state
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: a person who is a member already is not added again and is marked' ($r.Text -match 'added to Visitors: no; status: already a member' -and $global:F.Added -eq 1 -and ((Get-Content -LiteralPath $state -Raw) -match 'WasMember=yes') -and $r.Out[-1] -eq 'PROBE Person done: passed=3 failed=0') $r.Text
$env:T21_TEST_ADDRESS = 'nobody@fake.example'; Remove-Item -LiteralPath $state
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: a person who is not found: no, no state file, no identity' ($r.Code -eq 0 -and $r.Text -match 'added to Visitors: no; status: the person was not found on this site' -and -not (Test-Path -LiteralPath $state) -and $r.Text -notmatch 'nobody') $r.Text
$global:F.NoGetByEmail = $true
$env:T21_TEST_ADDRESS = 'not an address'
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: no valid address: no' ($r.Text -match 'added to Visitors: no; status: no valid address was given' -and -not (Test-Path -LiteralPath $state)) $r.Text
$env:T21_TEST_ADDRESS = $fakeAddr; $global:F.AddRefused = $true; $global:F.GroupUsers[7] = @(3, 4)
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person: a refused add: no, status without identity, state kept for Clean' ($r.Code -eq 0 -and $r.Text -match 'added to Visitors: no; status: the add was refused: ' -and (Test-Path -LiteralPath $state) -and $r.Text -notmatch 'second\.person') $r.Text
$global:F.AddRefused = $false; Remove-Item -LiteralPath $state
$global:F.Visitors = 0
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person without a Visitors group: no' ($r.Code -eq 0 -and $r.Text -match 'added to Visitors: no; status: the site has no Visitors group') $r.Text
Remove-Item Env:T21_TEST_ADDRESS
New-Site
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found') $r.Text
New-Site; $null = Invoke-T21 'Make'
$r = Invoke-T21 'Person'; Note $r
Test-That 'Person in RADE with no window and no test address: STOPPED, nothing added' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: ADDRESS window not available|STOPPED: ' -and $global:F.Added -eq 0 -and -not (Test-Path -LiteralPath $state)) $r.Text

# ---- Run ----
New-Site; $null = Invoke-T21 'Make'
$r = Invoke-T21 'Run'; Note $r
$lst = Get-Probe '90161ZProbe'
Test-That 'Run: one RUN-HEALTH command row' ($r.Code -eq 0 -and @($lst.Items | Where-Object { $_.Title -match '^RUN-HEALTH R27[0-9a-f]{8}$' }).Count -eq 1 -and $lst.Items.Count -eq 1 -and $r.Out[-1] -eq 'PROBE Run done: passed=0 failed=0') $r.Text
New-Site
$r = Invoke-T21 'Run'
Test-That 'Run without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found') $r.Text

# ---- Look ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
$r = Invoke-T21 'Look'; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^(FORM|VIEW) (PASSED|FAILED):' })
$view = @($global:F.Views)[0]
Test-That 'Look: exit 0, the last line, 2 summary lines' ($r.Code -eq 0 -and $tl.Count -eq 2 -and $r.Out[-1] -eq 'PROBE Look done: passed=4 failed=0') $r.Text
Test-That 'Look: the form header is on the content type and read back' ($lst.CT.ClientFormCustomFormatter -match '"headerJSONFormatter"' -and $lst.CT.ClientFormCustomFormatter -match '90-161\.Z test header' -and $tl[0] -match '^FORM PASSED: a header on the list form \(form formatting set by script\)=PASS \(route=csom; read back=yes\)') $tl[0]
Test-That 'Look: one view with the button of the flow' ($global:F.ViewsMade -eq 1 -and $view.Title -eq 'ProbeButton' -and $view.CustomFormatter -match 'executeFlow' -and $view.CustomFormatter -match $buttonId -and $view.CustomFormatter -match 'view-formatting\.schema\.json' -and $tl[1] -match '^VIEW PASSED: b a view formatted by script with a button that starts a flow=PASS \(route=csom; read back=yes; flow ID known to the script=yes\)') $tl[1]
$null = $view.CustomFormatter | ConvertFrom-Json
Test-That 'Look: the view formatting is valid JSON' $true
$r = Invoke-T21 'Look'; Note $r
Test-That 'Look twice: the view is not made again' ($global:F.ViewsMade -eq 1 -and $global:F.Views.Count -eq 1 -and $r.Out[-1] -eq 'PROBE Look done: passed=4 failed=0') $r.Text
New-Site; $null = Invoke-T21 'Make'; $global:F.CsomWorks = $false
$lst = Get-Probe '90161ZProbe'
$r = Invoke-T21 'Look'; Note $r
Test-That 'Look: when the CSOM route fails, the REST merge sets both and the lines say route=rest' ($r.Text -match 'FORM PASSED: .*route=rest; read back=yes' -and $r.Text -match 'VIEW PASSED: .*route=rest; read back=yes' -and $lst.CT.ClientFormCustomFormatter -match 'test header') $r.Text
New-Site; $null = Invoke-T21 'Make'; $global:F.CsomWorks = $false; $global:F.MergeWorks = $false
$r = Invoke-T21 'Look'; Note $r
Test-That 'Look: when both routes fail, FORM and VIEW FAILED with the reason, exit 0' ($r.Code -eq 0 -and $r.Text -match 'FORM FAILED: .*route=none; read back=no' -and $r.Text -match 'VIEW FAILED: .*route=none; read back=no' -and $r.Text -match 'l1-form FAIL .*merge refused' -and $r.Out[-1] -match 'failed=4') $r.Text
New-Site
$r = Invoke-T21 'Look'
Test-That 'Look without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found') $r.Text

# ---- Read ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'T4a' 11; Add-Row $lst 'T4a ' 12; Add-Row $lst 'Other title' 13; Add-Row $lst 'RUN-HEALTH R27abcdef12' 11
Add-Res $lst 'HEALTH' 'a' 'FAIL' 'OLD ROW BEFORE THE COMMAND'
$global:F.RowId += 0
Add-Res $lst 'HEALTH' 'a' 'PASS' 'own flows read=7; probe flows=2; last runs read=2; last run failed=0; status=200'
Add-Res $lst 'BTN' 'a' 'PASS' 'the view button started this flow; selected item Id read=yes'
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^(HEALTH|T4|BUTTON) (PASSED|FAILED):' })
Test-That 'Read: 3 lines (HEALTH, T4, BUTTON) and the last line' ($r.Code -eq 0 -and $tl.Count -eq 3 -and (@($tl | ForEach-Object { ($_ -split ' ')[0] }) -join ',') -eq 'HEALTH,T4,BUTTON' -and $r.Out[-1] -eq 'PROBE Read done: passed=3 failed=0') $r.Text
Test-That 'Read: HEALTH in the exact form, from the row after the command' ($tl[0] -eq 'HEALTH PASSED: a Power Automate Management connector, own flows only=PASS (own flows read=7; probe flows=2; last runs read=2; last run failed=0; status=200)') $tl[0]
Test-That 'Read: T4 counts rows by other people (a title with a space counts; own rows do not)' ($tl[1] -eq 'T4 PASSED: a list form by a second person (Visitors member)=PASS (rows=2; T4a rows=1; person in the Visitors group=not tried (no state file))') $tl[1]
Test-That 'Read: BUTTON counts the result row' ($tl[2] -match '^BUTTON PASSED: b a view button starts a flow=PASS \(result rows=1; the view button started this flow; selected item Id read=yes\)$') $tl[2]
$env:T21_TEST_ADDRESS = $fakeAddr
$null = Invoke-T21 'Person'
Remove-Item Env:T21_TEST_ADDRESS
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: T4 names that the person was added to Visitors' ($r.Text -match 'person in the Visitors group=yes\)') $r.Text

New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'T4a' 11; Add-Row $lst 'RUN-HEALTH R27abcdef12' 11
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-T21 'Read' @{ WaitMinutes = 0.03; PollSeconds = 1 }; Note $r
Test-That 'Read, no rows by a second person, no health row, no button row: waits, then 3 FAILED lines, way C named' ($r.Code -eq 0 -and $sw.Elapsed.TotalSeconds -ge 1 -and $r.Text -match 'WAIT health row not there \(time ran out\)' -and $r.Text -match "T4 FAILED: a list form by a second person \(Visitors member\)=FAIL \(rows=0; T4a rows=0; person in the Visitors group=not tried \(no state file\)\); next: way C: a flow writes the row with the PFM's connection \(not built\)" -and $r.Text -match 'HEALTH FAILED: .*no result row after the wait' -and $r.Text -match 'Premium licence' -and $r.Text -match 'BUTTON FAILED: .*result rows=0' -and $r.Out[-1] -eq 'PROBE Read done: passed=0 failed=3') $r.Text

New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'RUN-HEALTH R27abcdef12' 11
$global:Lst21 = $lst; $global:F.Gets = 0
$global:F.OnGet = { if ($global:F.Gets -ge 4) { $global:F.OnGet = $null; Add-Res $global:Lst21 'HEALTH' 'a' 'FAIL' 'own flows read=0; probe flows=0; last runs read=0; last run failed=0; status=403' } }
$sw.Restart()
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: waits for the health row and ends early; a FAIL row gives HEALTH FAILED with its status' ($r.Text -match 'WAIT health row there' -and $sw.Elapsed.TotalSeconds -ge 1 -and $sw.Elapsed.TotalSeconds -lt 60 -and $r.Text -match 'HEALTH FAILED: a Power Automate Management connector, own flows only=FAIL \(own flows read=0;.*status=403\)') $r.Text

New-Site; $null = Invoke-T21 'Make'
$sw.Restart(); $r = Invoke-T21 'Read' @{ PollSeconds = 1 }
Test-That 'Read: no command row: no wait, HEALTH says to run the health step' ($r.Text -match 'WAIT none' -and $sw.Elapsed.TotalSeconds -lt 20 -and $r.Text -match 'HEALTH FAILED: .*no command row') $r.Text

# ---- Clean ----
New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = $fakeAddr
$null = Invoke-T21 'Person'
Remove-Item Env:T21_TEST_ADDRESS
Test-That 'Clean setup: the person is in the group and the state file exists' ((@($global:F.GroupUsers[7]) -contains 31) -and (Test-Path -LiteralPath $state))
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: removes the person by the saved number, deletes the state file, recycles the 2 objects' ($r.Code -eq 0 -and -not (@($global:F.GroupUsers[7]) -contains 31) -and (@($global:F.GroupUsers[7]) -join ',') -eq '3,4' -and -not (Test-Path -LiteralPath $state) -and ($global:F.Recycled -join '|') -eq '90161Z Probe|90161Z Probe Files' -and $r.Out[-1] -eq 'PROBE Clean done: passed=3 failed=0') $r.Text
Test-That 'Clean: the other lists stay' (@($global:F.Lists | ForEach-Object { $_.Title }) -join '|' -eq 'Documents|Other probe list')
Test-That 'Clean: names what is removed by hand' ($r.Text -match 'the solution "90-161.Z probe"')
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean twice: nothing more removed, still exit 0' ($global:F.Recycled.Count -eq 2 -and $r.Code -eq 0 -and $r.Text -match 'no second person on file' -and $r.Out[-1] -eq 'PROBE Clean done: passed=3 failed=0')

New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = $fakeAddr
$null = Invoke-T21 'Person'
Remove-Item Env:T21_TEST_ADDRESS
$global:F.RemoveRefused = $true
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: when the removal is refused, it says so, keeps the state file and still recycles both objects' ($r.Code -eq 0 -and $r.Text -match 'c1-person FAIL the second person could not be removed' -and (Test-Path -LiteralPath $state) -and $global:F.Recycled.Count -eq 2 -and (@($global:F.GroupUsers[7]) -contains 31) -and $r.Out[-1] -eq 'PROBE Clean done: passed=2 failed=1') $r.Text
$global:F.RemoveRefused = $false
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean again: removes the person and deletes the state file' ($r.Code -eq 0 -and -not (@($global:F.GroupUsers[7]) -contains 31) -and -not (Test-Path -LiteralPath $state) -and $r.Text -match 'c1-person PASS')

New-Site; $null = Invoke-T21 'Make'
$env:T21_TEST_ADDRESS = 'member.person@fake.example'; $global:F.GroupUsers[7] = @(3, 4, 32)
$null = Invoke-T21 'Person'
Remove-Item Env:T21_TEST_ADDRESS
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: a person who was a member before stays in the group' ($r.Text -match 'was a Visitors member before the test, so the person stays' -and (@($global:F.GroupUsers[7]) -contains 32) -and -not (Test-Path -LiteralPath $state))

# ---- Masking over everything printed and written ----
$all = $allText.ToString()
Test-That 'no output line or result file holds the fake site address, host, site name, DODID or any address' ($all.Length -gt 1000 -and $all -notmatch 'fakehost|FakeWing|tester01|example\.test|second\.person|member\.person|nobody@|@fake' -and $all -notmatch 'FAKE NAME') ''

# ---- The script text ----
$src = Get-Content -LiteralPath $script -Raw
Test-That 'script: no question in RADE (Read-Host only behind RADE_CONTRACT), no permanent delete, no result file for Open' ($src -match 'if \(-not \$NoPause -and -not \$env:RADE_CONTRACT\)' -and $src -notmatch 'Remove-PnPList[^\n]*(?<!-Recycle) -Force -ErrorAction Stop\s*$' -and $src -match "-ne 'Open'")
$bad = @(($src -split "`n") | Where-Object { $_ -match '\$(personAddr|loginName)\b' -and $_ -match 'Set-Content|Add-Content|Out-File|Write-Host|Write-Output|Write-Error|Write-Warning|Write-Verbose|\$lines\.Add|Add-Item|Add-Test|Tee-Object|Export-|Start-Transcript|\| Out-|>>|\bthrow\b' })
Test-That 'script: the second person''s address is never written to a file, a result line or an output stream' ($bad.Count -eq 0) ($bad -join "`n")
$mentions = @(($src -split "`n") | Where-Object { $_ -match '\$personAddr\b' -and $_ -notmatch '^\s*#' })
Test-That 'script: the address variable is used only to read, check, look up and add the person, then cleared' ($mentions.Count -ge 5 -and @($mentions | Where-Object { $_ -match 'ConvertTo-Json -Compress|EscapeDataString|Read-PersonAddress|-match|= \$null|loginName = ' }).Count -eq $mentions.Count) ($mentions -join "`n")
Test-That 'script: no e-mail, name or site path in the state file code (numbers and flags only)' ($src -match '''UserId='' \+ \$userId' -and $src -match '''GroupId='' \+ \$visitorId' -and $src -match '''WasMember=''')

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T21 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
