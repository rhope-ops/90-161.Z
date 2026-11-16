# Tests scripts/gov/90161Z-T21-probe-r1.ps1 (R26 probe, parts Make, Run, App, Clean) against a small fake site (pwsh 7, cloud only).
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
$script = Join-Path $Root 'scripts/gov/90161Z-T21-probe-r1.ps1'

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
  $global:F = @{ Lists = (New-Object System.Collections.ArrayList); Connected = $false; NextId = 1; Created = 0; Uploads = 0; Rests = 0; Recycled = (New-Object System.Collections.ArrayList); Demoted = $true; OnAdd = $null; Visitors = 7; RowId = 100 }
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
  if (-not @($global:F.Lists | Where-Object { $_.Files -contains $n }).Count) { throw 'FAKE 404 file' }
  $to = Join-Path $Path $FileName
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
  $out = & $script -Id 'tester01' -Part $Part -NoPause -TestDir $t21 @Extra *>&1 | ForEach-Object { [string]$_ }
  $file = Join-Path $t21 ('90161Z-T21-probe-' + $Part.ToLowerInvariant() + '-r1.txt')
  return @{ Code = $LASTEXITCODE; Out = @($out); Text = (@($out) -join "`n"); File = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }) }
}
$allText = New-Object System.Text.StringBuilder
function Note([hashtable]$R) { [void]$allText.AppendLine($R.Text); [void]$allText.AppendLine($R.File) }
function Get-Probe([string]$Folder) { return @($global:F.Lists | Where-Object { $_.Folder -eq $Folder })[0] }

# ---- Make ----
New-Site
$r = Invoke-T21 'Make'; Note $r
$lib = Get-Probe '90161ZProbeFiles'; $lst = Get-Probe '90161ZProbe'
Test-That 'Make: exit 0 and the last line' ($r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Make done: passed=7 failed=0') $r.Text
Test-That 'Make: 1 library and 1 list with the contract titles and folders' ($lib -and $lib.Title -eq '90161Z Probe Files' -and $lib.Template -eq 101 -and $lst -and $lst.Title -eq '90161Z Probe' -and $lst.Template -eq 100 -and $global:F.Created -eq 2)
Test-That 'Make: 2 library columns and 4 list columns' (($lib.Fields -join ',') -eq 'ProbeSubject,ProbeOPR' -and ($lst.Fields -join ',') -eq 'ProbeTest,ProbeWay,ProbeResult,ProbeDetail')
Test-That 'Make: attachments on' ($lst.EnableAttachments -eq $true -and -not $lib.EnableAttachments)
Test-That 'Make: unique permissions, Visitors keep Read and get Contribute, Full Control kept' ($lst.Unique -and (@($lst.Roles[7]) -join ',') -eq '1073741826,1073741827' -and (@($lst.Roles[5]) -join ',') -eq '1073741829')
Test-That 'Make: 2 files uploaded' ($global:F.Uploads -eq 2 -and ($lib.Files -join ',') -eq '90161Z-T21-fake-draft-r1.docx,90161Z-T21-fake-form-r1.html')
Test-That 'Make: counts line' ($r.Text -match 'MADE library=1 list=1 columns=6 attachments=1 permission changes=2 files=2')
Test-That 'Make: the other lists are untouched' (-not (Get-FakeListByTitle 'Other probe list').Unique -and (Get-FakeListByTitle 'Documents').Files.Count -eq 0)
$posts = $global:F.Rests; $created = $global:F.Created; $up = $global:F.Uploads
$r = Invoke-T21 'Make'; Note $r
Test-That 'Make twice: changes nothing' ($r.Code -eq 0 -and $r.Text -match 'MADE library=0 list=0 columns=0 attachments=0 permission changes=0 files=0' -and $global:F.Created -eq $created -and $global:F.Uploads -eq $up -and $lst.Fields.Count -eq 4 -and $lib.Fields.Count -eq 2 -and (@($lst.Roles[7]) -join ',') -eq '1073741826,1073741827' -and $r.Out[-1] -eq 'PROBE Make done: passed=7 failed=0') $r.Text
Test-That 'Make: result file written and equal to the screen lines' ($r.File -match 'PROBE Make done')

# Make with no Visitors group: a NOTE and on.
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

# ---- Run ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'; $lib = Get-Probe '90161ZProbeFiles'
$null = $lst.Items.Add(@{ Id = 50; Title = 'RESULT'; ProbeTest = 'T5'; ProbeWay = 'a'; ProbeResult = 'FAIL'; ProbeDetail = 'OLD ROW FROM AN EARLIER RUN'; Author = $null })
foreach ($n in '90161Z-T21-T5a.pdf', '90161Z-T21-T5b.pdf', '90161Z-T21-T3b.pdf', '90161Z-T21-T3c.pdf', '90161Z-T21-T3a.docx', 'unrelated.pdf') { $null = $lib.Files.Add($n) }
function Add-Res($l, [string]$T, [string]$W, [string]$R, [string]$D) { $global:F.RowId++; $null = $l.Items.Add(@{ Id = $global:F.RowId; Title = 'RESULT'; ProbeTest = $T; ProbeWay = $W; ProbeResult = $R; ProbeDetail = $D; Author = $null }) }
$global:F.OnAdd = {
  param($l, $item)
  if ($item.Title -like 'RUN-FILES *') {
    Add-Res $l 'T5' 'a' 'PASS' 'status=200; bytes=34567'
    Add-Res $l 'T5' 'b' 'FAIL' 'status=404'
    Add-Res $l 'T3' 'b' 'PASS' 'ok'
    Add-Res $l 'T3' 'c' 'FAIL' 'try jane.doe@fake.example at https://fake.example.test/x?y=1 then more text'
    Add-Res $l 'T2' 'a' 'INFO' ('pdf-row=made bytes=' + ('9' * 300))
  }
  if ($item.Title -like 'RUN-MAIL *') {
    Add-Res $l 'T9' 'S1' 'PASS' 'sent=Succeeded; status=202'
    Add-Res $l 'T9' 'S2' 'FAIL' 'sent=Failed; status=403'
    Add-Res $l 'T9' 'S3' 'PASS' 'sent=Succeeded; status=202'
    Add-Res $l 'T9' 'READ1' 'INFO' 'S1=inbox S2=none S3=junk S4=none; http=200/200/200/403'
    Add-Res $l 'T9' 'READ2' 'INFO' 'S1=inbox S2=none S3=inbox+sent S4=none; http=200/200/200/403'
  }
}
$lib.Items[0].Title = 'FAKE DRAFT R26'
$r = Invoke-T21 'Run' @{ WaitMinutes = 0.05; PollSeconds = 1 }; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^(T\d+( prep)?) (PASSED|FAILED):' })
Test-That 'Run: exit 0 and the last line' ($r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Run done: passed=5 failed=0') $r.Text
Test-That 'Run: 5 summary lines (T3, T5, T6, T9, T2 prep)' ($tl.Count -eq 5 -and (@($tl | ForEach-Object { ($_ -split ' ')[0] }) -join ',') -eq 'T3,T5,T6,T9,T2') ($tl -join "`n")
Test-That 'Run: T5 line in the exact form' ($tl -contains 'T5 PASSED: a OneDrive Convert file=PASS (status=200; bytes=34567); b SharePoint request=FAIL (status=404)') ($tl -join "`n")
$t3 = @($tl | Where-Object { $_ -like 'T3 *' })[0]
Test-That 'Run: T3 PASSED with an optional way a not run, an address and a link masked' ($t3 -match '^T3 PASSED: a Word Online populate=not run' -and $t3 -match 'c HTML through OneDrive Convert=FAIL \(try <MASKED> at <MASKED> then more text\)' -and $t3 -notmatch 'jane|fake\.example') $t3
$t2 = @($tl | Where-Object { $_ -like 'T2 prep *' })[0]
Test-That 'Run: ProbeDetail cut to 160 characters' ($t2 -match '\(pdf-row=made bytes=9{141}\)$' -and $t2 -notmatch '9{142}') $t2
Test-That 'Run: T6 a is not run here, b reads the columns' (@($tl | Where-Object { $_ -match '^T6 PASSED: a not run by this script: see step "T21 AI Builder look"; b library columns=PASS \(Title promoted=yes; ProbeSubject present=no\)$' }).Count -eq 1) ($tl -join "`n")
Test-That 'Run: T9 lists each tag and where it was found' (@($tl | Where-Object { $_ -match '^T9 PASSED: S1 sent=Succeeded; status=202; found READ1=inbox, READ2=inbox; S2 .*S3 .*READ2=inbox\+sent; S4 no result row \(optional' }).Count -eq 1) ($tl -join "`n")
Test-That 'Run: the old RESULT row of an earlier run is ignored' ($r.Text -notmatch 'OLD ROW')
Test-That 'Run: demoted yes, both places named' ($r.Text -match 'demoted=yes \(customXml holds the fake subject=yes; word/document.xml holds it=no\)')
Test-That 'Run: downloads saved' ((Get-ChildItem -LiteralPath (Join-Path $t21 'files')).Count -eq 6 -and $r.Text -match 'result files made by the flows=5; files saved to the T21 files folder=6')
Test-That 'Run: two command rows with one tag' (@($lst.Items | Where-Object { $_.Title -match '^RUN-(FILES|MAIL) R26[0-9a-f]{8}$' }).Count -eq 2 -and @($lst.Items | ForEach-Object { $_.Title -replace '^RUN-\w+ ', '' } | Where-Object { $_ -match '^R26' } | Sort-Object -Unique).Count -eq 1)
$global:F.Demoted = $false
$r = Invoke-T21 'Run' @{ WaitMinutes = 0.05; PollSeconds = 1 }; Note $r
Test-That 'Run: demoted no when the custom XML does not hold the text' ($r.Text -match 'demoted=no \(customXml holds the fake subject=no')

# Run with no RESULT rows: ends after the wait, FAILED lines, exit 0.
New-Site; $null = Invoke-T21 'Make'
$lib = Get-Probe '90161ZProbeFiles'
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-T21 'Run' @{ WaitMinutes = 0.03; PollSeconds = 1 }; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^(T\d+( prep)?) (PASSED|FAILED):' })
Test-That 'Run, no RESULT rows: waits, then 5 FAILED lines, exit 0' ($r.Code -eq 0 -and $tl.Count -eq 5 -and @($tl | Where-Object { $_ -match ' FAILED: ' }).Count -eq 5 -and $r.Out[-1] -eq 'PROBE Run done: passed=0 failed=5' -and $sw.Elapsed.TotalSeconds -ge 1.5 -and $sw.Elapsed.TotalSeconds -lt 30) ($r.Text)
Test-That 'Run, no RESULT rows: says which are missing' ($r.Text -match 'WAIT result rows 0 of 6 needed \(time ran out' -and $r.Text -match 'a OneDrive Convert file=FAIL \(no result row after the wait\)')

# Run before Make: the part cannot run.
New-Site
$r = Invoke-T21 'Run' @{ WaitMinutes = 0.02; PollSeconds = 1 }; Note $r
Test-That 'Run without the list: STOPPED and exit 1' ($r.Code -eq 1 -and $r.Text -match 'STOPPED: LIST not found' -and $r.Out[-1] -match '^PROBE Run done:') $r.Text

# ---- App ----
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
$null = $lst.Items.Add(@{ Id = 201; Title = 'T4a'; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = [pscustomobject]@{ LookupId = 11 } })
$null = $lst.Items.Add(@{ Id = 202; Title = 'T4a'; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = [pscustomobject]@{ LookupId = 12 } })
$null = $lst.Items.Add(@{ Id = 203; Title = 'T10'; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = $null })
Add-Res $lst 'T4' 'b' 'PASS' 'caller-is-owner=no'
Add-Res $lst 'T7' 'a' 'PASS' 'rows=5 displayName=5 department=0 officeLocation=0 mail=5'
Add-Res $lst 'T7' 'b' 'PASS' 'rows=5 displayName=5 department=0 officeLocation=0 mail=5'
Add-Res $lst 'T8' 'a' 'FAIL' 'group=none members=0 status=403'
Add-Res $lst 'T8' 'b' 'PASS' 'tried=Graph mailbox (mailbox reachable=yes, status=200)'
Add-Res $lst 'T10' 'a' 'PASS' 'attachments=1 byteRange=yes sig=yes'
Add-Res $lst 'T10' 'b' 'FAIL' 'tried=OneDrive Convert file on the signed PDF; status=400'
$r = Invoke-T21 'App'; Note $r
$tl = @($r.Out | Where-Object { $_ -match '^T\d+ (PASSED|FAILED):' })
Test-That 'App: 4 lines (T4, T7, T8, T10) and the last line' ($r.Code -eq 0 -and $tl.Count -eq 4 -and (@($tl | ForEach-Object { ($_ -split ' ')[0] }) -join ',') -eq 'T4,T7,T8,T10' -and $r.Out[-1] -eq 'PROBE App done: passed=4 failed=0') $r.Text
Test-That 'App: T4 counts rows and other people''s rows' ($tl[0] -match 'T4a rows=2; rows by a second person=1' -and $tl[0] -match 'b flow with the owner connection=PASS \(runs by a second person=yes\)') $tl[0]
Test-That 'App: T8 and T10 PASSED when one way passed' ($tl[2] -match '^T8 PASSED: a .*=FAIL .*; b .*=PASS' -and $tl[3] -match '^T10 PASSED: a .*=PASS \(attachments=1 byteRange=yes sig=yes\); b .*=FAIL') ($tl -join "`n")
Test-That 'App: T2 is left to the window answer' ($r.Text -match 'NOTE T2: left to the answer')

# App waits for rows the flow writes later: they appear after a few reads, so it ends early (limit 4 minutes).
New-Site; $null = Invoke-T21 'Make'
$lst = Get-Probe '90161ZProbe'
$null = $lst.Items.Add(@{ Id = 301; Title = 'T10'; ProbeTest = ''; ProbeWay = ''; ProbeResult = ''; ProbeDetail = ''; Author = $null })
$global:Lst21 = $lst
$global:F.Gets = 0
$global:F.OnGet = { if ($global:F.Gets -ge 4) { $global:F.OnGet = $null; Add-Res $global:Lst21 'T10' 'a' 'PASS' 'attachments=1'; Add-Res $global:Lst21 'T8' 'b' 'PASS' 'late' } }
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-T21 'App' @{ PollSeconds = 1 }; Note $r
Test-That 'App: waits for T10 a and T8 b, ends early when they are there' ($r.Text -match 'WAIT app result rows T10 a and T8 b there' -and $r.Text -match 'T10 PASSED: a .*=PASS \(attachments=1\)' -and $sw.Elapsed.TotalSeconds -ge 1 -and $sw.Elapsed.TotalSeconds -lt 60) $r.Text
Test-That 'App: T4 is FAILED when no second person wrote a row' ($r.Text -match 'T4 FAILED: a .*=FAIL \(T4a rows=0; rows by a second person=0\)') $r.Text
New-Site; $null = Invoke-T21 'Make'
$sw.Restart(); $r = Invoke-T21 'App' @{ PollSeconds = 1 }
Test-That 'App: no app rows, no wait' ($r.Text -match 'WAIT none' -and $sw.Elapsed.TotalSeconds -lt 20)
New-Site; $null = Invoke-T21 'Make'

# ---- Clean ----
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean: recycles exactly 2 objects, the two probe ones' ($global:F.Recycled.Count -eq 2 -and ($global:F.Recycled -join '|') -eq '90161Z Probe|90161Z Probe Files' -and $r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Clean done: passed=2 failed=0') $r.Text
Test-That 'Clean: the other lists stay' (@($global:F.Lists | ForEach-Object { $_.Title }) -join '|' -eq 'Documents|Other probe list')
Test-That 'Clean: names what is removed by hand' ($r.Text -match 'solutions "90-161.Z probe", "90-161.Z probe Word" and "90-161.Z probe Mail"' -and $r.Text -match '/90161Z-probe')
$r = Invoke-T21 'Clean'; Note $r
Test-That 'Clean twice: nothing more recycled, still exit 0' ($global:F.Recycled.Count -eq 2 -and $r.Code -eq 0 -and $r.Out[-1] -eq 'PROBE Clean done: passed=2 failed=0')

# ---- Masking over everything printed and written ----
$all = $allText.ToString()
Test-That 'no output line or result file holds the fake site address, host, site name or DODID' ($all.Length -gt 1000 -and $all -notmatch 'fakehost|FakeWing|tester01|example\.test') ''

# Script header facts that the tests above rely on.
$src = Get-Content -LiteralPath $script -Raw
Test-That 'script: no question in RADE (Read-Host only behind RADE_CONTRACT) and no permanent delete' ($src -match 'if \(-not \$NoPause -and -not \$env:RADE_CONTRACT\)' -and $src -notmatch 'Remove-PnPList[^\n]*(?<!-Recycle) -Force -ErrorAction Stop\s*$' -and $src -match 'Remove-PnPList -Identity \(\[string\]\$x\.Id\) -Recycle')

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T21 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
