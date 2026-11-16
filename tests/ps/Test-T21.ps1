# Tests scripts/gov/90161Z-T21-probe-r2.ps1 (R26 r2 probe, parts Make, Run, Open, Sign, Read, Clean) against a small fake site (pwsh 7, cloud only).
# The fake PnP cmdlets are defined here (functions in this file); only an empty PnP.PowerShell 1.12.0 module is put on the
# module path so the script's "is PnP installed" check passes. It proves the script's logic and output; the real service is
# proved by the R26 round on the gov device. Last line: "T21 pass=N fail=0".
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
foreach ($n in '90161Z-T21-fake-draft-r1.docx', '90161Z-T21-fake-form-r1.html') { Copy-Item -LiteralPath (Join-Path $Root ('samples/' + $n)) -Destination $t21 }
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T21-probe-r2.ps1'

# A docx the fake "downloads" for the fake draft: custom XML holds the fake subject (demoted) or not.
function New-FakeDocx([string]$Path, [bool]$Demoted) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path }
  $z = [System.IO.Compression.ZipFile]::Open($Path, 'Create')
  try {
    foreach ($e in @(@('word/document.xml', '<w:document>FAKE DRAFT R26</w:document>'), @('customXml/item1.xml', $(if ($Demoted) { '<properties>FAKE SUBJECT R26</properties>' } else { '<properties></properties>' })))) {
      $en = $z.CreateEntry($e[0]); $sw = New-Object System.IO.StreamWriter($en.Open()); $sw.Write($e[1]); $sw.Dispose()
    }
  } finally { $z.Dispose() }
}

# ---- the fake site and its cmdlets ----
function New-Site {
  $global:F = @{ PersonMail = 'fake.person@fake.example'; Signed = $true; Lists = (New-Object System.Collections.ArrayList); Connected = $false; NextId = 1; Created = 0; Uploads = 0; Rests = 0; Recycled = (New-Object System.Collections.ArrayList); Demoted = $true; OnAdd = $null; Visitors = 7; RowId = 100 }
  $null = Add-SiteList 'Documents' 'Shared Documents' 101
  $null = Add-SiteList 'Other probe list' 'Lists/OtherProbe' 100
}
function Add-SiteList([string]$Title, [string]$Folder, [int]$Template) {
  $l = [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); Title = $Title; Folder = ($Folder -split '/')[-1]; Template = $Template; Hidden = $false
    Fields = (New-Object System.Collections.ArrayList); Files = (New-Object System.Collections.ArrayList); Items = (New-Object System.Collections.ArrayList)
    EnableAttachments = $false; Unique = $false; Roles = @{ 5 = @(1073741829); 7 = @(1073741826) } }
  $l | Add-Member -MemberType ScriptMethod -Name Update -Value { }
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
  [CmdletBinding()] param()
  $lists = [pscustomobject]@{}
  $lists | Add-Member -MemberType ScriptMethod -Name GetById -Value { param([guid]$Id) return (Get-FakeList $Id.ToString()) }
  $ctx = [pscustomobject]@{ Web = [pscustomobject]@{ Lists = $lists } }
  $ctx | Add-Member -MemberType ScriptMethod -Name ExecuteQuery -Value { }
  return $ctx
}
function Add-PnPFile {
  [CmdletBinding()] param([string]$Path, [string]$Folder)
  $lib = @($global:F.Lists | Where-Object { $_.Folder -eq $Folder })
  if (-not $lib.Count) { throw 'FAKE 404 folder' }
  $n = Split-Path -Leaf $Path
  $null = $lib[0].Files.Add($n); $global:F.Uploads++
  $global:F.RowId++
  $null = $lib[0].Items.Add(@{ Id = $global:F.RowId; FileLeafRef = $n; Title = ''; ProbeSubject = '' })
}
function Get-PnPFile {
  [CmdletBinding()] param([string]$Url, [string]$Path, [string]$FileName, [switch]$AsFile, [switch]$Force)
  $n = ($Url -split '/')[-1]
  $to = Join-Path $Path $FileName
  if ($Url -match '/Attachments/\d+/') { Set-Content -LiteralPath $to -Value $(if ($global:F.Signed) { '%PDF-1.4 /Type /Sig /ByteRange [0 10 20 30] /SubFilter /adbe.pkcs7.detached' } else { '%PDF-1.4 no signature' }); return }
  if (-not @($global:F.Lists | Where-Object { $_.Files -contains $n }).Count) { throw 'FAKE 404 file' }
  if ($n -like '*fake-draft*') { New-FakeDocx $to $global:F.Demoted } else { Set-Content -LiteralPath $to -Value 'x' }
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
      return (@{ value = @($global:F.Lists | ForEach-Object { @{ Id = $_.Id; Title = $_.Title; ItemCount = $_.Items.Count; BaseTemplate = $_.Template; Hidden = $_.Hidden; EnableAttachments = $_.EnableAttachments; HasUniqueRoleAssignments = $_.Unique; RootFolder = @{ Name = $_.Folder } } }) } | ConvertTo-Json -Depth 6 -Compress)
    }
    if ($path -eq 'web/associatedvisitorgroup') { return (@{ Id = $global:F.Visitors } | ConvertTo-Json -Compress) }
    if ($path -eq 'web/roledefinitions') { return (@{ value = @(@{ Id = 1073741827 }) } | ConvertTo-Json -Compress) }
    if ($path -eq 'web/currentuser') { return (@{ Id = 11 } | ConvertTo-Json -Compress) }
    if ($path -match '^web/siteuserinfolist/items\((\d+)\)$') {
      # The script must ask for one field at a time; the fake answers like SharePoint (an unknown field is a 400).
      $sel = ''; if ($Url -match '\$select=(\w+)$') { $sel = $Matches[1] } else { throw 'FAKE: the person read must use $select with one field' }
      $u = @{ EMail = $global:F.PersonMail; Department = ''; JobTitle = 'FAKE TITLE' }
      if (-not $u.ContainsKey($sel)) { throw ('FAKE 400: the field ' + $sel + ' does not exist') }
      return ('{"' + $sel + '":' + $(if ($null -eq $u[$sel]) { 'null' } else { '"' + $u[$sel] + '"' }) + '}')
    }
    if ($path -match "^web/lists\(guid'([^']+)'\)/items\((\d+)\)/AttachmentFiles$") {
      $l = Get-FakeList $Matches[1]; $iid = [int]$Matches[2]
      $it = @($l.Items | Where-Object { $_.Id -eq $iid })
      if (-not $it.Count) { throw 'FAKE 404 item' }
      return (@{ value = @(@($it[0].Att) | Where-Object { $_ } | ForEach-Object { @{ FileName = $_; ServerRelativeUrl = ('/sites/FakeWing/Lists/' + $l.Folder + '/Attachments/' + $iid + '/' + $_) } }) } | ConvertTo-Json -Compress -Depth 5)
    }
    if ($path -match "^web/lists\(guid'([^']+)'\)/(fields|rootfolder/files)$") {
      $l = Get-FakeList $Matches[1]
      if ($Matches[2] -eq 'fields') { return (@{ value = @($l.Fields | ForEach-Object { @{ InternalName = $_ } }) } | ConvertTo-Json -Compress) }
      return (@{ value = @($l.Files | ForEach-Object { @{ Name = $_; ServerRelativeUrl = ('/sites/FakeWing/' + $l.Folder + '/' + $_); Length = 1000 } }) } | ConvertTo-Json -Compress)
    }
    if ($path -match "^web/lists\(guid'([^']+)'\)/roleassignments/getbyprincipalid\((\d+)\)/roledefinitionbindings$") {
      $l = Get-FakeList $Matches[1]; $p = [int]$Matches[2]
      if (-not $l.Roles.ContainsKey($p)) { throw 'FAKE 404: no such principal' }
      return (@{ value = @($l.Roles[$p] | ForEach-Object { @{ Id = $_ } }) } | ConvertTo-Json -Compress)
    }
    throw ('FAKE 404 GET ' + $path)
  }
  if ($Method -ne 'Post') { throw 'FAKE: only GET and POST' }
  if ($ContentType -ne 'application/json;odata=verbose') { throw 'FAKE 415' }
  if ($Content -isnot [string]) { throw 'FAKE: the body must be a string' }
  if ($path -notmatch "^web/lists\(guid'([^']+)'\)/(.+)$") { throw ('FAKE 404 POST ' + $path) }
  $l = Get-FakeList $Matches[1]; $rest = $Matches[2]
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
  $file = Join-Path $t21 ('90161Z-T21-probe-' + $Part.ToLowerInvariant() + '-r2.txt')
  $r = @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
  if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
  return $r
}
$allText = New-Object System.Text.StringBuilder
function Note([hashtable]$R) { [void]$allText.AppendLine($R.Text); [void]$allText.AppendLine($R.File) }
function Get-Probe([string]$Folder) { return @($global:F.Lists | Where-Object { $_.Folder -eq $Folder })[0] }
function Add-Res($l, [string]$T, [string]$W, [string]$R, [string]$D) { $global:F.RowId++; $null = $l.Items.Add(@{ Id = $global:F.RowId; Title = 'RESULT'; ProbeTest = $T; ProbeWay = $W; ProbeResult = $R; ProbeDetail = $D; Author = $null }) }
function Add-Row($l, [string]$Title, [int]$Author, $Person = $null, $Att = $null) { $global:F.RowId++; $null = $l.Items.Add(@{ Id = $global:F.RowId; Title = $Title; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = $(if ($Author) { [pscustomobject]@{ LookupId = $Author } } else { $null }); ProbePerson = $Person; Att = $Att }) }
$links = Join-Path $t21 '90161Z-T21-links-r2.html'

# ---- Make ----
New-Site
$r = Invoke-T21 'Make'; Note $r
$lib = Get-Probe '90161ZProbeFiles'; $lst = Get-Probe '90161ZProbe'
Test-That 'Make: exit 0 and the last line' ($r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Make done: passed=8 failed=0') $r.Text
Test-That 'Make: 1 library and 1 list with the contract titles and folders' ($lib -and $lib.Title -eq '90161Z Probe Files' -and $lib.Template -eq 101 -and $lst -and $lst.Title -eq '90161Z Probe' -and $lst.Template -eq 100 -and $global:F.Created -eq 2)
Test-That 'Make: 2 library columns and 5 list columns (a person column)' (($lib.Fields -join ',') -eq 'ProbeSubject,ProbeOPR' -and ($lst.Fields -join ',') -eq 'ProbeTest,ProbeWay,ProbeResult,ProbeDetail,ProbePerson')
Test-That 'Make: attachments on' ($lst.EnableAttachments -eq $true -and -not $lib.EnableAttachments)
Test-That 'Make: unique permissions, Visitors keep Read and get Contribute, Full Control kept' ($lst.Unique -and (@($lst.Roles[7]) -join ',') -eq '1073741826,1073741827' -and (@($lst.Roles[5]) -join ',') -eq '1073741829')
Test-That 'Make: 2 files uploaded' ($global:F.Uploads -eq 2 -and ($lib.Files -join ',') -eq '90161Z-T21-fake-draft-r1.docx,90161Z-T21-fake-form-r1.html')
Test-That 'Make: counts line' ($r.Text -match 'MADE library=1 list=1 columns=7 attachments=1 permission changes=2 files=2')
Test-That 'Make: the other lists are untouched' (-not (Get-FakeListByTitle 'Other probe list').Unique -and (Get-FakeListByTitle 'Documents').Files.Count -eq 0)
$page = Get-Content -LiteralPath $links -Raw
Test-That 'Make: test page with 4 links to the site' ((@([regex]::Matches($page, 'class="go" href="https://fakehost\.example\.test/sites/FakeWing/')).Count -eq 4) -and $page -match 'Lists/90161ZProbe/NewForm\.aspx' -and $page -match '90161Z-T21-fake-draft-r1\.docx\?web=1' -and $page -match '90161Z-T21-T5a\.pdf' -and $r.Text -match 'm8-page PASS test page in the T21 folder, links=4') $r.Text
Test-That 'Make: the test page is ASCII and has no script' ($page -notmatch '[^\x00-\x7F]' -and $page -notmatch '<script')
$created = $global:F.Created; $up = $global:F.Uploads
$r = Invoke-T21 'Make'; Note $r
Test-That 'Make twice: changes nothing on the site' ($r.Code -eq 0 -and $r.Text -match 'MADE library=0 list=0 columns=0 attachments=0 permission changes=0 files=0' -and $global:F.Created -eq $created -and $global:F.Uploads -eq $up -and $lst.Fields.Count -eq 5 -and $lib.Fields.Count -eq 2) $r.Text
Test-That 'Make: result file written and equal to the screen lines' ($r.File -match 'PROBE Make done')

New-Site; $global:F.Visitors = 0
$r = Invoke-T21 'Make'; Note $r
Test-That 'Make without a Visitors group: NOTE line, still exit 0' ($r.Code -eq 0 -and $r.Text -match 'NOTE m5: no associated Visitors group' -and $r.Out[-1] -match 'failed=0')

$pdfPath = Join-Path $t21 '90161Z-T21-fake-sign-r1.pdf'
$pdfBytes = [IO.File]::ReadAllBytes($pdfPath)
Test-That 'Make: writes the PDF to sign from the block in the script' ((@(Get-ChildItem -LiteralPath (Join-Path $Root 'samples') -Filter *.pdf).Count -eq 0) -and [Text.Encoding]::ASCII.GetString($pdfBytes, 0, 8) -eq '%PDF-1.4' -and $pdfBytes.Length -gt 300)
(Get-Item -LiteralPath $pdfPath).LastWriteTime = [datetime]'2001-01-01'
$r = Invoke-T21 'Make'
Test-That 'Make twice: the PDF is not rewritten' ((Get-Item -LiteralPath $pdfPath).LastWriteTime -eq [datetime]'2001-01-01' -and $r.Text -match 'written now=0')
Set-Content -LiteralPath $pdfPath -Value 'broken'
$r = Invoke-T21 'Make'
Test-That 'Make: a PDF with other bytes is written again' ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($pdfPath), 0, 8) -eq '%PDF-1.4' -and $r.Text -match 'written now=1')

# ---- Open and Sign (no sign-in) ----
Remove-Item -LiteralPath $links
$global:F.Connected = $false; $rests = $global:F.Rests
$r = Invoke-T21 'Open'; Note $r
Test-That 'Open: writes the test page again, no sign-in, no result file' ($r.Code -eq 0 -and (Test-Path -LiteralPath $links) -and $global:F.Rests -eq $rests -and -not $global:F.Connected -and $r.Out[-1] -eq 'PROBE Open done: passed=2 failed=0' -and $r.File -eq '') $r.Text
$r = Invoke-T21 'Sign'; Note $r
Test-That 'Sign: no sign-in, both items PASS in a test run' ($r.Code -eq 0 -and $global:F.Rests -eq $rests -and $r.Out[-1] -eq 'PROBE Sign done: passed=2 failed=0' -and $r.Text -match 'clipboard=no \(test run\)') $r.Text
Remove-Item -LiteralPath $pdfPath
$r = Invoke-T21 'Sign'; Note $r
Test-That 'Sign without the PDF: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: PDF to sign not found') $r.Text

# ---- Run ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'; $lib = Get-Probe '90161ZProbeFiles'
$null = $lst.Items.Add(@{ Id = 50; Title = 'RESULT'; ProbeTest = 'T5'; ProbeWay = 'a'; ProbeResult = 'FAIL'; ProbeDetail = 'OLD ROW FROM AN EARLIER RUN'; Author = $null })
foreach ($n in '90161Z-T21-T5a.pdf', '90161Z-T21-T5b.pdf', '90161Z-T21-T3b.pdf', '90161Z-T21-T3c.pdf', 'unrelated.pdf') { $null = $lib.Files.Add($n) }
$global:F.OnAdd = {
  param($l, $item)
  if ($item.Title -like 'RUN-FILES *') {
    Add-Res $l 'T5' 'a' 'PASS' 'status=200; bytes=34567'
    Add-Res $l 'T5' 'b' 'FAIL' 'status=302'
    Add-Res $l 'T3' 'b' 'PASS' 'ok'
    Add-Res $l 'T3' 'c' 'FAIL' 'try jane.doe@fake.example at https://fake.example.test/x?y=1 then more text'
  }
  if ($item.Title -like 'RUN-MAIL *') {
    Add-Res $l 'T9' 'S3' 'PASS' 'sent=Succeeded; status=200'
    Add-Res $l 'T9' 'S5' 'PASS' 'sent=Succeeded; status=200'
    Add-Res $l 'T9' 'S6' 'FAIL' 'sent=no (the Shared mailbox value is empty)'
    Add-Res $l 'T9' 'READ1' 'INFO' 'S3=sent S5=sent S6=none ; http=200/200/200/skipped'
    Add-Res $l 'T9' 'READ2' 'INFO' 'S3=sent S5=inbox+sent S6=none ; http=200/200/200/skipped'
  }
  if ($item.Title -like 'RUN-APP *') {
    Add-Res $l 'T7' 'b' 'PASS' 'rows=5 displayName=5 department=0 officeLocation=0 mail=5; status=200'
    Add-Res $l 'T8' 'a' 'FAIL' 'group=none members=0 status=200'
    Add-Res $l 'T8' 'b' 'FAIL' 'tried=Graph users/<box>/mailFolders (mailbox reachable=no, status=404)'
  }
}
$lib.Items[0].Title = 'FAKE DRAFT R26'
$r = Invoke-T21 'Run' @{ WaitMinutes = 0.05; PollSeconds = 1 }; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^T\d+ (PASSED|FAILED):' })
Test-That 'Run: exit 0 and the last line' ($r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Run done: passed=4 failed=1') $r.Text
Test-That 'Run: 5 summary lines (T3, T5, T6, T8, T9)' ($tl.Count -eq 5 -and (@($tl | ForEach-Object { ($_ -split ' ')[0] }) -join ',') -eq 'T3,T5,T6,T8,T9') ($tl -join "`n")
Test-That 'Run: T5 line in the exact form' ($tl -contains 'T5 PASSED: a OneDrive Convert file=PASS (status=200; bytes=34567); b SharePoint request=FAIL (status=302)') ($tl -join "`n")
$t3 = @($tl | Where-Object { $_ -like 'T3 *' })[0]
Test-That 'Run: T3 names the r1 refusal, masks an address and a link' ($t3 -match '^T3 PASSED: a Word Online populate=not tried \(R26 r1: refused, Premium licence\)' -and $t3 -match 'c HTML through OneDrive Convert=FAIL \(try <MASKED> at <MASKED> then more text\)' -and $t3 -notmatch 'jane|fake\.example') $t3
Test-That 'Run: T6 a named, b reads the columns' (@($tl | Where-Object { $_ -match '^T6 PASSED: a AI Builder=not tried \(R26 r1: unavailable\); b library columns=PASS \(Title promoted=yes; ProbeSubject present=no\)$' }).Count -eq 1) ($tl -join "`n")
Test-That 'Run: T8 FAILED when both ways failed' (@($tl | Where-Object { $_ -match '^T8 FAILED: a Office 365 Groups members=FAIL .*; b Graph mailbox request=FAIL' }).Count -eq 1) ($tl -join "`n")
$t9 = @($tl | Where-Object { $_ -like 'T9 *' })[0]
Test-That 'Run: T9 names each send and where it was found' ($t9 -match '^T9 PASSED: S3 \(own mailbox, subject with \[TEST\]\) sent=Succeeded; status=200; found READ1=sent, READ2=sent; S5 \(own mailbox, no \[TEST\]\) .*READ2=inbox\+sent; S6 \(shared mailbox, no \[TEST\]\) sent=no') $t9
Test-That 'Run: T9 cause line (only the plain subject arrived)' ($r.Text -match 'NOTE T9 cause: only the e-mail without \[TEST\] arrived') $r.Text
Test-That 'Run: the old RESULT row of an earlier run is ignored' ($r.Text -notmatch 'OLD ROW')
Test-That 'Run: demoted yes, both places named' ($r.Text -match 'demoted=yes \(customXml holds the fake subject=yes; word/document.xml holds it=no\)')
Test-That 'Run: downloads saved' ($r.Text -match 'result files made by the flows=4; files saved to the T21 files folder=5') $r.Text
Test-That 'Run: three command rows with one tag' (@($lst.Items | Where-Object { $_.Title -match '^RUN-(FILES|MAIL|APP) R26[0-9a-f]{8}$' }).Count -eq 3 -and @($lst.Items | Where-Object { $_.Title -match '^RUN-' } | ForEach-Object { $_.Title -replace '^RUN-\w+ ', '' } | Sort-Object -Unique).Count -eq 1)

New-Site; $null = Invoke-T21 'Make'
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-T21 'Run' @{ WaitMinutes = 0.03; PollSeconds = 1 }; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^T\d+ (PASSED|FAILED):' })
Test-That 'Run, no RESULT rows: waits, then 5 FAILED lines, exit 0' ($r.Code -eq 0 -and $tl.Count -eq 5 -and @($tl | Where-Object { $_ -match ' FAILED: ' }).Count -eq 5 -and $r.Out[-1] -eq 'PROBE Run done: passed=0 failed=5' -and $sw.Elapsed.TotalSeconds -ge 1) $r.Text
Test-That 'Run, no RESULT rows: says which are missing, cause line for no arrival' ($r.Text -match 'WAIT result rows 0 of 8 needed \(time ran out' -and $r.Text -match 'a OneDrive Convert file=FAIL \(no result row after the wait\)' -and $r.Text -match 'NOTE T9 cause: neither own-mailbox e-mail arrived') $r.Text

New-Site
$r = Invoke-T21 'Run' @{ WaitMinutes = 0.02; PollSeconds = 1 }; Note $r
Test-That 'Run without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found' -and $r.Out[-1] -match '^PROBE Run done:') $r.Text

# ---- Read ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'T4a' 11; Add-Row $lst 'T4a ' 12
Add-Row $lst 'T7a' 11 ([pscustomobject]@{ LookupId = 21 })
Add-Row $lst 'T10' 11 $null @('90161Z-T21-fake-sign-r1-signed.pdf')
Add-Res $lst 'T9' 'READ3' 'INFO' 'S3=inbox S5=inbox S6=inbox ; OLDER RUN, MUST NOT COUNT'
Add-Row $lst 'RUN-MAIL R26abcdef12' 11
Add-Res $lst 'T7' 'b' 'PASS' 'rows=5 displayName=5 department=0 officeLocation=0 mail=5'
Add-Res $lst 'T10' 'a' 'PASS' 'attachments=1 byteRange=yes sig=yes'
Add-Res $lst 'T10' 'b' 'FAIL' 'tried=OneDrive Convert file on the signed PDF; status=400'
Add-Res $lst 'T9' 'S3' 'PASS' 'sent=Succeeded; status=200'
Add-Res $lst 'T9' 'S5' 'PASS' 'sent=Succeeded; status=200'
Add-Res $lst 'T9' 'READ3' 'INFO' 'S3=junk+sent S5=inbox+sent S6=none ; http=200/200/200/skipped'
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^T\d+ (PASSED|FAILED):' })
Test-That 'Read: 4 lines (T4, T7, T10, T9) and the last line' ($r.Code -eq 0 -and $tl.Count -eq 4 -and (@($tl | ForEach-Object { ($_ -split ' ')[0] }) -join ',') -eq 'T4,T7,T10,T9' -and $r.Out[-1] -eq 'PROBE Read done: passed=4 failed=0') $r.Text
Test-That 'Read: T4 counts rows and other people''s rows (a title with a space counts)' ($tl[0] -match '^T4 PASSED: a list form by a second person=PASS \(T4a rows=2; rows by a second person=1; that the person has only Read rests on your choice of person\); b flow with the owner connection=not tried') $tl[0]
Test-That 'Read: T7 a says which fields have a value, never the value' ($tl[1] -match '^T7 PASSED: a list form person box=PASS \(rows with a person=1; fields with a value: EMail=yes Department=no JobTitle=yes Office=n/a; that the box searched the address list rests on your answer\); b flow Office 365 Users search=PASS' -and $r.Text -notmatch 'FAKE PERSON|FAKE TITLE|fake\.person') $tl[1]
Test-That 'Read: T10 reads the attachment itself (way c) beside the flow ways' ($tl[2] -match '^T10 PASSED: a signature markers by the flow=PASS .*; b OneDrive Convert on the signed PDF=FAIL .*; c signature markers read here=PASS \(attachments=1 byteRange=yes sig=yes\)$') $tl[2]
Test-That 'Read: T9 uses the 25-minute read of the newest run only; junk counts as arrived' ($tl[3] -match '^T9 PASSED: .*READ3=junk\+sent' -and $tl[3] -notmatch 'OLDER' -and $r.Text -match 'NOTE T9 cause: both own-mailbox e-mails arrived' -and $tl[3] -match 'S6 \(shared mailbox, no \[TEST\]\) no result row; found READ3=none') $tl[3]
$global:F.PersonMail = ''
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: T7 a FAILS when the person has no e-mail address value' ($r.Text -match 'T7 PASSED: a list form person box=FAIL \(rows with a person=1; fields with a value: EMail=no ' ) $r.Text
$global:F.PersonMail = 'fake.person@fake.example'
Test-That 'Read: T2 is left to the window answers; the wait found the rows' ($r.Text -match 'NOTE T2: left to the answers' -and $r.Text -match 'WAIT last result rows there') $r.Text

New-Site; $null = Invoke-T21 'Make'; $global:F.Signed = $false
$lst = Get-Probe '90161ZProbe'
Add-Row $lst 'T10' 11 $null @('plain.pdf')
$global:Lst21 = $lst; $global:F.Gets = 0
$global:F.OnGet = { if ($global:F.Gets -ge 4) { $global:F.OnGet = $null; Add-Res $global:Lst21 'T10' 'a' 'FAIL' 'byteRange=no sig=no' } }
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-T21 'Read' @{ PollSeconds = 1 }; Note $r
Test-That 'Read: waits for the flow row of T10, ends early' ($r.Text -match 'WAIT last result rows there' -and $sw.Elapsed.TotalSeconds -ge 1 -and $sw.Elapsed.TotalSeconds -lt 60) $r.Text
Test-That 'Read: an unsigned attachment FAILS T10; no second person FAILS T4; no person FAILS T7 a' ($r.Text -match 'T10 FAILED: .*c signature markers read here=FAIL \(attachments=1 byteRange=no sig=no\)' -and $r.Text -match 'T4 FAILED: a list form by a second person=FAIL \(T4a rows=0' -and $r.Text -match 'T7 FAILED: a list form person box=FAIL \(rows with a person=0\)') $r.Text

New-Site; $null = Invoke-T21 'Make'
$sw.Restart(); $r = Invoke-T21 'Read' @{ PollSeconds = 1 }
Test-That 'Read: nothing to wait for, no wait' ($r.Text -match 'WAIT none' -and $sw.Elapsed.TotalSeconds -lt 20) $r.Text
New-Site; $null = Invoke-T21 'Make'

# ---- Clean ----
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: recycles exactly 2 objects, the two probe ones' ($global:F.Recycled.Count -eq 2 -and ($global:F.Recycled -join '|') -eq '90161Z Probe|90161Z Probe Files' -and $r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Clean done: passed=2 failed=0') $r.Text
Test-That 'Clean: the other lists stay' (@($global:F.Lists | ForEach-Object { $_.Title }) -join '|' -eq 'Documents|Other probe list')
Test-That 'Clean: names what is removed by hand' ($r.Text -match 'the solution "90-161.Z probe"' -and $r.Text -match '/90161Z-probe')
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean twice: nothing more recycled, still exit 0' ($global:F.Recycled.Count -eq 2 -and $r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Clean done: passed=2 failed=0')

# ---- Masking over everything printed and written ----
$all = $allText.ToString()
Test-That 'no output line or result file holds the fake site address, host, site name or DODID' ($all.Length -gt 1000 -and $all -notmatch 'fakehost|FakeWing|tester01|example\.test') ''

$src = Get-Content -LiteralPath $script -Raw
Test-That 'script: no question in RADE (Read-Host only behind RADE_CONTRACT), no permanent delete, no result file for Open and Sign' ($src -match 'if \(-not \$NoPause -and -not \$env:RADE_CONTRACT\)' -and $src -notmatch 'Remove-PnPList[^\n]*(?<!-Recycle) -Force -ErrorAction Stop\s*$' -and $src -match "-notin 'Open', 'Sign'")

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T21 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
