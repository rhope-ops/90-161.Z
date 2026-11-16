<#
.SYNOPSIS
  90-161.Z Task 21 easy-path probe, r1 (round R26). Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: the device side of the R26 probe. The probe flows (solutions "90-161.Z probe", "90-161.Z probe Word",
  "90-161.Z probe Mail") and the test app do the trying; this script makes the two site objects they need, starts the file and
  mail flows, collects what they wrote, and removes the two objects. Fake data only (the draft, the form and the PDF are made by
  code, scripts/build_probe_samples.py). Counts, status codes and field names only: no names, addresses or text from the tenant.
  Parts (-Part):
    Make  (about 1 minute, an estimate)  Makes the library "90161Z Probe Files" (columns ProbeSubject, ProbeOPR) and the list
          "90161Z Probe" (attachments on; columns ProbeTest, ProbeWay, ProbeResult, ProbeDetail; its own permissions: the site's
          copied, then Contribute for the site's Visitors group on this list only), and uploads the fake draft and the fake form.
          Run it twice and the second run changes nothing.
    Run   (about 16 minutes, an estimate)  Adds two command rows (RUN-FILES and RUN-MAIL with a tag), waits up to -WaitMinutes
          (default 14) for the flows' RESULT rows, downloads the PDFs the flows made to the T21 folder (files), checks whether
          SharePoint wrote the fake subject into the draft's custom XML (property demotion), reads the draft's library columns,
          and prints one line per test (T3, T5, T6, T9, T2 prep).
    App   (about 1 to 5 minutes, an estimate)  Reads the rows the test app and its flow wrote (waits up to -WaitMinutes, default 4 here,
          for RESULT T10 a and T8 b when the app has written a row) and prints one line for T4, T7, T8, T10.
    Clean (about 1 minute, an estimate)  Moves the list and the library to the site Recycle Bin (restorable for 93 days).
          Nothing else is removed. The solutions, the app and the OneDrive folder /90161Z-probe are removed by hand (the part says which).
  WHAT IT CHANGES ON THE SITE: Make adds the two objects, their columns, their permissions and two files, and saves the fake PDF to sign in the T21 folder. Run adds two rows to
  the list (the flows add more, and files to the library). Clean recycles the two objects. Every output line shows the site as
  <SITE> and the DODID as <DODID>.
  Output: 90161Z-T21-probe-make-r1.txt, -run-r1.txt, -app-r1.txt or -clean-r1.txt in the T21 folder (send them back).
  Last line of each part: PROBE <part> done: passed=<n> failed=<n>. Exit code 0 when the part ran to its end (a FAILED test is
  a result); exit 1 only when the part could not run (sign-in, missing list).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part, -WaitMinutes, -NoPause. -PollSeconds and
  -TestDir are for the tests in tests/run.sh.
#>
param([string]$Id, [ValidateSet('Make', 'Run', 'App', 'Clean')][string]$Part, [double]$WaitMinutes = 14, [switch]$NoPause, [int]$PollSeconds = 20, [string]$TestDir)
$task = 'T21'
$pollEvery = $PollSeconds
$LibTitle = '90161Z Probe Files'
$LibFolder = '90161ZProbeFiles'
$ListTitle = '90161Z Probe'
$ListFolder = '90161ZProbe'
$DraftName = '90161Z-T21-fake-draft-r1.docx'
$SignName = '90161Z-T21-fake-sign-r1.pdf'
$FormName = '90161Z-T21-fake-form-r1.html'

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
# <<< site-common
# >>> fake-sign-pdf: generated by scripts/build_probe_samples.py (do not edit)
$FakeSignPdfBase64 = @(
  'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwg',
  'L1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVu',
  'dCAyIDAgUiAvTWVkaWFCb3ggWzAgMCA2MTIgNzkyXSAvQ29udGVudHMgNCAwIFIgL1Jlc291cmNlcyA8PCAvRm9udCA8PCAvRjEg',
  'NSAwIFIgPj4gPj4gPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCA2MCA+PgpzdHJlYW0KQlQgL0YxIDE4IFRmIDcyIDcwMCBU',
  'ZCAoRkFLRSAtIDkwMTYxWiBSMjYgLSBzaWduIGhlcmUpIFRqIEVUCmVuZHN0cmVhbQplbmRvYmoKNSAwIG9iago8PCAvVHlwZSAv',
  'Rm9udCAvU3VidHlwZSAvVHlwZTEgL0Jhc2VGb250IC9IZWx2ZXRpY2EgPj4KZW5kb2JqCnhyZWYKMCA2CjAwMDAwMDAwMDAgNjU1',
  'MzUgZiAKMDAwMDAwMDAxNSAwMDAwMCBuIAowMDAwMDAwMDY0IDAwMDAwIG4gCjAwMDAwMDAxMjEgMDAwMDAgbiAKMDAwMDAwMDI0',
  'NyAwMDAwMCBuIAowMDAwMDAwMzU3IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNiAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYK',
  'NDI3CiUlRU9GCg=='
) -join ' '
# <<< fake-sign-pdf

function Hide-Site([string]$Text, [string]$Site) {
  # The result is e-mailed: no site, tenant or sign-in address may stay in it (the same rule as T16, T18, T19 and T20).
  $Text = $Text -replace '[\w.+-]+@[\w.-]+', '<EMAIL>'
  $Text = $Text -replace '[\w.+-]+%40[\w.-]+', '<EMAIL>'
  if ($Site) {
    $Text = $Text -replace [regex]::Escape($Site.TrimEnd('/')), '<SITE>'
    try {
      $u = [uri]$Site
      $Text = $Text -replace [regex]::Escape($u.Host), '<SITE-HOST>'
      $path = $u.AbsolutePath.TrimEnd('/')
      if ($path.Length -gt 1) {
        $Text = $Text -replace [regex]::Escape($path), '<SITE-PATH>'
        $Text = $Text -replace [regex]::Escape([uri]::EscapeDataString($path)), '<SITE-PATH>'
        $leaf = ($path -split '/')[-1]
        if ($leaf.Length -ge 3) { $Text = $Text -replace ('\b' + [regex]::Escape($leaf) + '\b'), '<SITE-NAME>' }
      }
      $tenant = ($u.Host -split '\.')[0]
      if ($tenant.Length -ge 3) { $Text = $Text -replace ('\b' + [regex]::Escape($tenant) + '\b'), '<TENANT>' }
    } catch { $null = $_ }
  }
  $Text = $Text -replace 'https?://\S+', '<URL>'
  $Text = $Text -replace '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>'
  $Text = $Text -replace '\b[\w.-]+\.mil\b', '<HOST>'
  # No word boundary: a GUID right after URL-encoded characters (guid%27...) must be masked too.
  $Text = $Text -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>'
  return $Text
}

function Invoke-Rest([string]$Method, [string]$Uri, [string]$Body) {
  # One SharePoint REST request through the signed-in PnP connection (the same call T20 uses).
  $url = $script:site.TrimEnd('/') + '/' + $Uri
  if ($Method -eq 'Get') { return [string](Invoke-PnPSPRestMethod -Method Get -Url $url -Raw -ErrorAction Stop) }
  return [string](Invoke-PnPSPRestMethod -Method Post -Url $url -Content $Body -ContentType 'application/json;odata=verbose' -Raw -ErrorAction Stop)
}
function Get-RestValue([string]$Uri) { return @(((Invoke-Rest 'Get' $Uri '') | ConvertFrom-Json).value) }
function Get-SiteList {
  # Every list on the site that is not hidden, with the folder name it was made under (the folder name never changes).
  return @(Get-RestValue ('_api/web/lists?$select=Id,Title,ItemCount,BaseTemplate,Hidden,EnableAttachments,HasUniqueRoleAssignments,RootFolder/Name&$expand=RootFolder&$top=1000') | Where-Object { -not $_.Hidden })
}
function Find-ByFolder([string]$Folder) {
  foreach ($l in (Get-SiteList)) { if ([string]$l.RootFolder.Name -eq $Folder) { return $l } }
  return $null
}
function Add-Item([string]$Name, [string]$Status, [string]$Text) {
  $script:lines.Add('ITEM ' + $Name + ' ' + $Status + $(if ($Text) { ' ' + $Text } else { '' }))
  if ($Status -eq 'PASS') { $script:passed++ } elseif ($Status -eq 'FAIL') { $script:failed++ }
}
function Add-Test([string]$Name, [string[]]$Piece, [bool]$Pass) {
  # One summary line per test: "T5 PASSED: a ...; b ...".
  $script:lines.Add($Name + ' ' + $(if ($Pass) { 'PASSED' } else { 'FAILED' }) + ': ' + ($Piece -join '; '))
  if ($Pass) { $script:passed++ } else { $script:failed++ }
}
function Format-Detail([string]$Text) {
  # The flow's ProbeDetail for a summary line: one line, anything that looks like an address or a link masked, cut to 160.
  $t = ($Text -replace '\s+', ' ').Trim()
  $t = $t -replace '[\w.+-]+@[\w.-]+', '<MASKED>'
  $t = $t -replace '[\w.+-]+%40[\w.-]+', '<MASKED>'
  $t = $t -replace 'https?://\S+', '<MASKED>'
  if ($t.Length -gt 160) { $t = $t.Substring(0, 160) }
  return $t
}
function Get-ListRow([string]$Title, [string[]]$Fields) {
  # Plain rows (Id and the named fields as text), counts and flags only are written from them.
  $rows = @(Get-PnPListItem -List $Title -Fields $Fields -PageSize 500 -ErrorAction Stop)
  return @($rows | ForEach-Object {
    $o = @{ Id = [int]$_.Id; Item = $_ }
    foreach ($f in $Fields) { $o[$f] = [string]$_[$f] }
    $o
  })
}
function Find-Result($Rows, [string]$Test, [string]$Way) {
  # The newest RESULT row for a test and way, or $null.
  $hit = @($Rows | Where-Object { $_.Title -eq 'RESULT' -and $_.ProbeTest -eq $Test -and $_.ProbeWay -eq $Way } | Sort-Object { $_.Id } -Descending)
  if ($hit.Count) { return $hit[0] }
  return $null
}
function Format-Way($Rows, [string]$Test, [string]$Way, [string]$Label, [bool]$Optional) {
  # Returns @{ Text; Pass } for one way: "a OneDrive Convert file=PASS (status=200; bytes=34567)".
  $r = Find-Result $Rows $Test $Way
  if (-not $r) {
    if ($Optional) { return @{ Text = ($Way + ' ' + $Label + '=not run (optional: its solution may have been refused)'); Pass = $false } }
    return @{ Text = ($Way + ' ' + $Label + '=FAIL (no result row after the wait)'); Pass = $false }
  }
  $d = Format-Detail $r.ProbeDetail
  return @{ Text = ($Way + ' ' + $Label + '=' + $r.ProbeResult + $(if ($d) { ' (' + $d + ')' } else { '' })); Pass = ($r.ProbeResult -eq 'PASS') }
}
function Add-WayTest([string]$Name, $Rows, $Ways) {
  # $Ways = array of @(test, way, label, optional). PASSED when at least one way passed.
  $pieces = @(); $any = $false
  foreach ($w in $Ways) {
    $x = Format-Way $Rows $w[0] $w[1] $w[2] ([bool]$w[3])
    $pieces += $x.Text
    if ($x.Pass) { $any = $true }
  }
  Add-Test $Name $pieces $any
}
function Wait-Until([scriptblock]$Done, [string]$What) {
  # Checks every $PollSeconds for up to $WaitMinutes; a progress line a minute. A failed check is retried; 3 in a row stop the part.
  $start = Get-Date
  $end = $start.AddMinutes($WaitMinutes)
  $misses = 0; $nextNote = $start.AddMinutes(1)
  while ($true) {
    $isDone = $false
    try { $isDone = [bool](& $Done); $misses = 0 }
    catch {
      $misses++
      if ($misses -ge 3) { throw }
      Write-Host ('  A check failed (' + $misses + ' of 3 allowed in a row); trying again ...')
    }
    if ($isDone) { return $true }
    $now = Get-Date
    if ($now -ge $end) { return $false }
    if ($now -ge $nextNote) {
      Write-Host ('  Waiting for ' + $What + ' (' + [int]($now - $start).TotalMinutes + ' of ' + $WaitMinutes + ' minutes) ...')
      $nextNote = $nextNote.AddMinutes(1)
    }
    Start-Sleep -Seconds $pollEvery
  }
}

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
$passed = 0; $failed = 0
$fatal = $false
try {
  $ErrorActionPreference = 'Stop'
  if (-not $Part) { throw 'PART not given: use -Part Make, Run, App or Clean.' }
  if ($Part -eq 'App' -and -not $PSBoundParameters.ContainsKey('WaitMinutes')) { $WaitMinutes = 4 }
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 21' -Create }
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $lines.Add('TASK T21 easy-path probe r1, part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + $(if ($Part -eq 'Run') { ', wait-minutes=' + $WaitMinutes } else { '' }))
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'Connecting to the site. If a sign-in window opens, sign in with your CAC.'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
  # The first request is a read: it proves the REST route before anything is written.
  $siteLists = Get-SiteList
  $lines.Add('ITEM a-rest-read INFO lists read from the site=' + $siteLists.Count)

  if ($Part -eq 'Make') {
    Assert-TaskFile $dir @($DraftName, $FormName) 'FILES not found in the T21 folder (run the round again so RADE saves them): '
    $made = @{ library = 0; list = 0; columns = 0; attachments = 0; permissions = 0; files = 0 }
    $skip = @{ library = 0; list = 0; columns = 0; attachments = 0; permissions = 0; files = 0 }

    # m1, m2: the library and the list (the same cmdlet T16 uses for its library).
    $lib = Find-ByFolder $LibFolder
    if ($lib) { $skip.library++ } else { Write-Host ('  Making the library ' + $LibTitle + ' ...'); $null = New-PnPList -Title $LibTitle -Template DocumentLibrary -Url $LibFolder -ErrorAction Stop; $made.library++; $lib = Find-ByFolder $LibFolder }
    Add-Item 'm1-library' $(if ($lib) { 'PASS' } else { 'FAIL' }) $(if ($lib) { 'library there (made=' + $made.library + ')' } else { 'library not on the site after the create step' })
    $lst = Find-ByFolder $ListFolder
    if ($lst) { $skip.list++ } else { Write-Host ('  Making the list ' + $ListTitle + ' ...'); $null = New-PnPList -Title $ListTitle -Template GenericList -Url ('Lists/' + $ListFolder) -ErrorAction Stop; $made.list++; $lst = Find-ByFolder $ListFolder }
    Add-Item 'm2-list' $(if ($lst) { 'PASS' } else { 'FAIL' }) $(if ($lst) { 'list there (made=' + $made.list + ')' } else { 'list not on the site after the create step' })
    if (-not $lib -or -not $lst) { throw 'LIST or library missing after the create step; nothing more was done.' }

    # m3: columns (internal name = display name).
    $want = @(
      @{ List = $lib; Name = 'ProbeSubject'; Type = 'Text' }, @{ List = $lib; Name = 'ProbeOPR'; Type = 'Text' },
      @{ List = $lst; Name = 'ProbeTest'; Type = 'Text' }, @{ List = $lst; Name = 'ProbeWay'; Type = 'Text' },
      @{ List = $lst; Name = 'ProbeResult'; Type = 'Text' }, @{ List = $lst; Name = 'ProbeDetail'; Type = 'Note' })
    $have = @{}
    foreach ($l in @($lib, $lst)) { $have[[string]$l.Id] = @(Get-RestValue ("_api/web/lists(guid'" + $l.Id + "')/fields?" + '$select=InternalName&$top=2000') | ForEach-Object { [string]$_.InternalName }) }
    $bad = 0
    foreach ($c in $want) {
      if ($have[[string]$c.List.Id] -contains $c.Name) { $skip.columns++; continue }
      $xml = '<Field Name="' + $c.Name + '" StaticName="' + $c.Name + '" DisplayName="' + $c.Name + '" Required="FALSE" Type="' + $c.Type + '"' + $(if ($c.Type -eq 'Note') { ' RichText="FALSE" NumLines="6"' } else { '' }) + '></Field>'
      $body = @{ parameters = @{ __metadata = @{ type = 'SP.XmlSchemaFieldCreationInformation' }; SchemaXml = $xml; Options = 24 } } | ConvertTo-Json -Depth 20 -Compress
      try { $null = Invoke-Rest 'Post' ("_api/web/lists(guid'" + $c.List.Id + "')/fields/createfieldasxml") $body; $made.columns++ } catch { $bad++ }
    }
    Add-Item 'm3-columns' $(if ($bad -eq 0) { 'PASS' } else { 'FAIL' }) ('columns made=' + $made.columns + ' already there=' + $skip.columns + ' refused=' + $bad)

    # m4: attachments on (a CSOM write, the way T20 sets list properties).
    $lst = Find-ByFolder $ListFolder
    if ($lst.EnableAttachments) { $skip.attachments++ }
    else {
      $ctx = Get-PnPContext
      $target = $ctx.Web.Lists.GetById([guid]$lst.Id)
      $target.EnableAttachments = $true
      $target.Update()
      $ctx.ExecuteQuery()
      $made.attachments++
    }
    $lst = Find-ByFolder $ListFolder
    Add-Item 'm4-attachments' $(if ($lst.EnableAttachments) { 'PASS' } else { 'FAIL' }) ('attachments on (switched on now=' + $made.attachments + ')')

    # m5: the list's own permissions: the site's copied, then Contribute for the associated Visitors group on this list only.
    $lbase = "_api/web/lists(guid'" + $lst.Id + "')"
    if (-not $lst.HasUniqueRoleAssignments) {
      $null = Invoke-Rest 'Post' ($lbase + '/breakroleinheritance(copyRoleAssignments=true,clearSubscopes=true)') '{}'
      $made.permissions++
    }
    $visitorId = 0
    try { $visitorId = [int]((Invoke-Rest 'Get' '_api/web/associatedvisitorgroup?$select=Id' '') | ConvertFrom-Json).Id } catch { $visitorId = 0 }
    if ($visitorId -le 0) {
      $lines.Add('NOTE m5: no associated Visitors group on this site, so Contribute was not added; the T4 way a test needs a person who is a site visitor to write')
      Add-Item 'm5-permissions' 'PASS' ('own permissions on the list (copied now=' + $made.permissions + '); Visitors group not found')
    } else {
      $contribute = 0
      try { $contribute = [int](Get-RestValue '_api/web/roledefinitions?$filter=RoleTypeKind%20eq%203&$select=Id')[0].Id } catch { $contribute = 0 }
      if ($contribute -le 0) { throw 'ROLE Contribute not found on the site.' }
      $has = $false
      try { $has = @(Get-RestValue ($lbase + '/roleassignments/getbyprincipalid(' + $visitorId + ')/roledefinitionbindings?$select=Id') | Where-Object { [int]$_.Id -eq $contribute }).Count -gt 0 } catch { $has = $false }
      if (-not $has) { $null = Invoke-Rest 'Post' ($lbase + '/roleassignments/addroleassignment(principalid=' + $visitorId + ',roledefid=' + $contribute + ')') '{}'; $made.permissions++ }
      Add-Item 'm5-permissions' 'PASS' ('own permissions on the list, Visitors group has Contribute (changes now=' + $made.permissions + ')')
    }

    # m6: the two files.
    $inLib = @(Get-RestValue ("_api/web/lists(guid'" + $lib.Id + "')/rootfolder/files?" + '$select=Name&$top=500') | ForEach-Object { [string]$_.Name })
    foreach ($n in $DraftName, $FormName) {
      if ($inLib -contains $n) { $skip.files++; continue }
      $null = Add-PnPFile -Path (Join-Path $dir $n) -Folder $LibFolder -ErrorAction Stop
      $made.files++
    }
    $inLib = @(Get-RestValue ("_api/web/lists(guid'" + $lib.Id + "')/rootfolder/files?" + '$select=Name&$top=500') | ForEach-Object { [string]$_.Name })
    $ok = ($inLib -contains $DraftName) -and ($inLib -contains $FormName)
    Add-Item 'm6-files' $(if ($ok) { 'PASS' } else { 'FAIL' }) ('files in the library: draft and form there=' + $(if ($ok) { 'yes' } else { 'no' }) + ' (uploaded now=' + $made.files + ')')
    # m7: the fake PDF for the PFM to sign is written from the text block in this script (the repo holds no .pdf).
    $pdfBytes = [Convert]::FromBase64String((($FakeSignPdfBase64 -split '\s+') -join ''))
    $signPath = Join-Path $dir $SignName
    $same = $false
    if (Test-Path -LiteralPath $signPath -PathType Leaf) { $cur = [IO.File]::ReadAllBytes($signPath); $same = ($cur.Length -eq $pdfBytes.Length) -and ([Convert]::ToBase64String($cur) -eq [Convert]::ToBase64String($pdfBytes)) }
    if (-not $same) { [IO.File]::WriteAllBytes($signPath, $pdfBytes) }
    Add-Item 'm7-sign-pdf' $(if (Test-Path -LiteralPath $signPath -PathType Leaf) { 'PASS' } else { 'FAIL' }) ('PDF to sign in the T21 folder, bytes=' + $pdfBytes.Length + ' (written now=' + $(if ($same) { 0 } else { 1 }) + ')')
    $lines.Add('MADE library=' + $made.library + ' list=' + $made.list + ' columns=' + $made.columns + ' attachments=' + $made.attachments + ' permission changes=' + $made.permissions + ' files=' + $made.files)
    $lines.Add('SKIPPED (already there) library=' + $skip.library + ' list=' + $skip.list + ' columns=' + $skip.columns + ' attachments=' + $skip.attachments + ' files=' + $skip.files)
  }
  elseif ($Part -eq 'Run') {
    $lib = Find-ByFolder $LibFolder
    $lst = Find-ByFolder $ListFolder
    if (-not $lib -or -not $lst) { throw 'LIST not found: run -Part Make first.' }
    $tag = 'R26' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $c1 = Add-PnPListItem -List $ListTitle -Values @{ Title = ('RUN-FILES ' + $tag) } -ErrorAction Stop
    $c2 = Add-PnPListItem -List $ListTitle -Values @{ Title = ('RUN-MAIL ' + $tag) } -ErrorAction Stop
    $floor = [Math]::Min([int]$c1.Id, [int]$c2.Id)
    Add-Item 'r1-commands' 'INFO' ('command rows made: RUN-FILES and RUN-MAIL, tag ' + $tag)
    $fields = @('Title', 'ProbeTest', 'ProbeWay', 'ProbeResult', 'ProbeDetail')
    $need = @(@('T5', 'a'), @('T5', 'b'), @('T3', 'b'), @('T3', 'c'), @('T2', 'a'), @('T9', 'READ2'))
    $script:have = 0
    $ok = Wait-Until {
      $rows = @(Get-ListRow $ListTitle $fields | Where-Object { $_.Id -gt $floor })
      $script:have = @($need | Where-Object { Find-Result $rows $_[0] $_[1] }).Count
      $script:have -ge $need.Count } 'the flows'' result rows'
    $lines.Add('WAIT result rows ' + $script:have + ' of ' + $need.Count + ' needed' + $(if ($ok) { '' } else { ' (time ran out; the lines below say which are missing)' }))
    $rows = @(Get-ListRow $ListTitle $fields | Where-Object { $_.Id -gt $floor })

    # Downloads: the PDFs and files the flows made, and the fake draft.
    $filesDir = Join-Path $dir 'files'
    if (-not (Test-Path -LiteralPath $filesDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $filesDir) }
    $inLib = @(Get-RestValue ("_api/web/lists(guid'" + $lib.Id + "')/rootfolder/files?" + '$select=Name,ServerRelativeUrl,Length&$top=500'))
    $made = @($inLib | Where-Object { [string]$_.Name -match '^90161Z-T21-T\d[a-z]?\.(pdf|docx)$' })
    $got = 0; $notGot = 0
    foreach ($f in @($made) + @($inLib | Where-Object { [string]$_.Name -eq $DraftName })) {
      try { Get-PnPFile -Url ([string]$f.ServerRelativeUrl) -Path $filesDir -FileName ([string]$f.Name) -AsFile -Force -ErrorAction Stop; $got++ } catch { $notGot++ }
    }
    $lines.Add('ITEM r2-downloads INFO result files made by the flows=' + $made.Count + '; files saved to the T21 files folder=' + $got + '; not saved=' + $notGot)

    # Property demotion: does the draft's custom XML hold the fake subject the flow wrote into the library column?
    $needle = 'FAKE SUBJECT R26'
    $inCustom = 'no'; $inDoc = 'no'
    $draftLocal = Join-Path $filesDir $DraftName
    if (Test-Path -LiteralPath $draftLocal -PathType Leaf) {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $zip = [System.IO.Compression.ZipFile]::OpenRead($draftLocal)
      try {
        foreach ($e in $zip.Entries) {
          $isCustom = $e.FullName -like 'customXml/*.xml'
          if (-not $isCustom -and $e.FullName -ne 'word/document.xml') { continue }
          $sr = New-Object System.IO.StreamReader($e.Open())
          try { $txt = $sr.ReadToEnd() } finally { $sr.Dispose() }
          if ($txt.Contains($needle)) { if ($isCustom) { $inCustom = 'yes' } else { $inDoc = 'yes' } }
        }
      } finally { $zip.Dispose() }
      $lines.Add('ITEM r3-demotion INFO demoted=' + $inCustom + ' (customXml holds the fake subject=' + $inCustom + '; word/document.xml holds it=' + $inDoc + ')')
    } else { $lines.Add('ITEM r3-demotion INFO demoted=no (the fake draft was not saved, so it could not be opened)') }

    # T6 way b: the draft's library columns.
    $titleYes = 'no'; $subjYes = 'no'; $itemFound = $false
    $libRows = @(Get-ListRow $LibTitle @('FileLeafRef', 'Title', 'ProbeSubject'))
    $d = @($libRows | Where-Object { $_.FileLeafRef -eq $DraftName })
    if ($d.Count) { $itemFound = $true; if ($d[0].Title) { $titleYes = 'yes' }; if ($d[0].ProbeSubject) { $subjYes = 'yes' } }
    $lines.Add('ITEM r4-columns INFO Title promoted from the Word property=' + $titleYes + '; ProbeSubject present=' + $subjYes + $(if ($itemFound) { '' } else { ' (draft row not found)' }))

    # One line per test.
    Add-WayTest 'T3' $rows @(@('T3', 'a', 'Word Online populate', $true), @('T3', 'b', 'update properties then convert', $false), @('T3', 'c', 'HTML through OneDrive Convert', $false))
    Add-WayTest 'T5' $rows @(@('T5', 'a', 'OneDrive Convert file', $false), @('T5', 'b', 'SharePoint request', $false))
    $t6 = ($titleYes -eq 'yes')
    Add-Test 'T6' @('a not run by this script: see step "T21 AI Builder look"', ('b library columns=' + $(if ($t6) { 'PASS' } else { 'FAIL' }) + ' (Title promoted=' + $titleYes + '; ProbeSubject present=' + $subjYes + ')')) $t6
    # T9: each tag, where it was sent and where it was found (READ1, READ2). PASSED when at least one tag was found in the inbox.
    $pieces = @(); $inInbox = $false
    foreach ($s in 'S1', 'S2', 'S3', 'S4') {
      $sent = Find-Result $rows 'T9' $s
      $where = @()
      foreach ($rd in 'READ1', 'READ2') {
        $r = Find-Result $rows 'T9' $rd
        if ($r -and $r.ProbeDetail -match ('\b' + $s + '=([^\s;]+)')) { $where += ($rd + '=' + $Matches[1]); if ($Matches[1] -match 'inbox') { $inInbox = $true } }
      }
      $sentText = $(if ($sent) { Format-Detail $sent.ProbeDetail } else { $(if ($s -eq 'S4') { 'no result row (optional: its solution may have been refused)' } else { 'no result row' }) })
      $pieces += ($s + ' ' + $sentText + $(if ($where.Count) { '; found ' + ($where -join ', ') } else { '; found nowhere read' }))
    }
    Add-Test 'T9' $pieces $inInbox
    $t2 = Find-Result $rows 'T2' 'a'
    Add-Test 'T2 prep' @($(if ($t2) { 'a PDF row=' + $t2.ProbeResult + $(if ($t2.ProbeDetail) { ' (' + (Format-Detail $t2.ProbeDetail) + ')' } else { '' }) } else { 'a PDF row=FAIL (no result row after the wait)' })) ($t2 -and $t2.ProbeResult -ne 'FAIL')
  }
  elseif ($Part -eq 'App') {
    $lst = Find-ByFolder $ListFolder
    if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
    $appFields = @('Title', 'ProbeTest', 'ProbeWay', 'ProbeResult', 'ProbeDetail', 'Author')
    $rows = @(Get-ListRow $ListTitle $appFields)
    # The app's flow answers a minute or more after the button: when the app has written something but RESULT T10 a or T8 b is
    # not there yet, wait for them (default 4 minutes here). With no app row at all there is nothing to wait for.
    $hasApp = @($rows | Where-Object { $_.Title -eq 'T4a' -or $_.Title -eq 'T10' -or ($_.Title -eq 'RESULT' -and $_.ProbeTest -eq 'T7') }).Count -gt 0
    if ($hasApp) {
      $ok = Wait-Until {
        $rows = @(Get-ListRow $ListTitle $appFields)
        [bool]((Find-Result $rows 'T10' 'a') -and (Find-Result $rows 'T8' 'b')) } 'the app flow''s result rows (T10 a, T8 b)'
      $rows = @(Get-ListRow $ListTitle $appFields)
      $lines.Add('WAIT app result rows T10 a and T8 b ' + $(if ($ok) { 'there' } else { 'not all there (time ran out; the lines below say which are missing)' }))
    } else { $lines.Add('WAIT none: no app row on the list yet') }
    $meId = 0
    try { $meId = [int]((Invoke-Rest 'Get' '_api/web/currentuser?$select=Id' '') | ConvertFrom-Json).Id } catch { $meId = 0 }
    $t4a = @($rows | Where-Object { $_.Title -eq 'T4a' })
    $other = 0
    foreach ($r in $t4a) { $a = $r.Item['Author']; if ($meId -gt 0 -and $a -and [int]$a.LookupId -ne $meId) { $other++ } }
    # T4 needs a second person: a row the signed-in person wrote proves nothing about a person with Read only.
    $aOk = ($other -ge 1)
    $b = Find-Result $rows 'T4' 'b'
    $bDetail = $(if ($b) { Format-Detail $b.ProbeDetail } else { '' })
    if (-not $bDetail) {
      $t4b = @($rows | Where-Object { $_.Title -eq 'T4b' })
      if ($t4b.Count) { $bDetail = Format-Detail $t4b[0].ProbeDetail }
    }
    $t4bOther = @($rows | Where-Object { ($_.Title -eq 'T4b' -or ($_.Title -eq 'RESULT' -and $_.ProbeTest -eq 'T4' -and $_.ProbeWay -eq 'b')) -and ([string]$_.ProbeDetail) -match 'caller-is-owner=no' }).Count
    $bPass = ($b -and $b.ProbeResult -eq 'PASS' -and $t4bOther -ge 1)
    Add-Test 'T4' @(('a app write with own rights=' + $(if ($aOk) { 'PASS' } else { 'FAIL' }) + ' (T4a rows=' + $t4a.Count + '; rows by a second person=' + $other + ')'),
      ('b flow with the owner connection=' + $(if ($bPass) { 'PASS' } else { 'FAIL' }) + ' (runs by a second person=' + $(if ($t4bOther -ge 1) { 'yes' } else { 'no' }) + ')' + $(if ($bDetail) { ' (' + $bDetail + ')' } elseif (-not $b) { ' (no result row)' } else { '' }))) ($aOk -or $bPass)
    Add-WayTest 'T7' $rows @(@('T7', 'a', 'app Office 365 Users search', $false), @('T7', 'b', 'flow Office 365 Users search', $false))
    Add-WayTest 'T8' $rows @(@('T8', 'a', 'Office 365 Groups members', $false), @('T8', 'b', 'Graph mailbox request', $false))
    $att = @($rows | Where-Object { $_.Title -eq 'T10' }).Count
    Add-WayTest 'T10' $rows @(@('T10', 'a', 'signature markers in the attachment', $false), @('T10', 'b', 'OneDrive Convert on the signed PDF', $false))
    $lines.Add('NOTE T2: left to the answer you give in the RADE window (this script does not read it); T10 rows made by the app=' + $att)
  }
  else {
    # Clean: only the two objects of this probe (found by their folder name), to the site Recycle Bin.
    foreach ($o in @(@('c1-list', $ListTitle, $ListFolder), @('c2-library', $LibTitle, $LibFolder))) {
      $x = Find-ByFolder $o[2]
      if (-not $x) { Add-Item $o[0] 'PASS' ('"' + $o[1] + '" was not on the site (nothing to remove)'); continue }
      Remove-PnPList -Identity ([string]$x.Id) -Recycle -Force -ErrorAction Stop
      $still = Find-ByFolder $o[2]
      Add-Item $o[0] $(if (-not $still) { 'PASS' } else { 'FAIL' }) ('"' + $o[1] + '" ' + $(if (-not $still) { 'moved to the site Recycle Bin (restorable for 93 days)' } else { 'is still on the site' }))
    }
    $lines.Add('NOTE by hand: delete the solutions "90-161.Z probe", "90-161.Z probe Word" and "90-161.Z probe Mail" (Power Automate, Solutions), the test app, and the OneDrive folder /90161Z-probe. This script does not touch them')
  }
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} catch {
  $fatal = $true
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(400, $m.Length)) + ' (a part that stopped can be run again: Make skips what is there)')
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} finally {
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir -and $Part) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T21-probe-' + $Part.ToLowerInvariant() + '-r1.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
