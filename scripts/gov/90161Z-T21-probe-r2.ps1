<#
.SYNOPSIS
  90-161.Z Task 21 easy-path probe, r2 (round R26 r2). Windows PowerShell 5.1, the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: the device side of the R26 r2 probe. The front end is split (PFM 16 Nov 26): the PFM works in a RADE-style
  window (task T22) and everyone else uses SharePoint list forms opened from a link. This script makes the two site objects the
  tests need, starts the probe flows (solution "90-161.Z probe" r2), opens the test page and the PDF to sign, reads what the
  people and the flows wrote, and removes the two objects. Fake data only (the draft, the form and the PDF are made by code,
  scripts/build_probe_samples.py). Counts, status codes and field names only: no names, addresses or text from the tenant.
  Parts (-Part):
    Make  (about 1 minute, an estimate)  Makes the library "90161Z Probe Files" (columns ProbeSubject, ProbeOPR) and the list
          "90161Z Probe" (attachments on; columns ProbeTest, ProbeWay, ProbeResult, ProbeDetail, ProbePerson (a person column);
          its own permissions: the site's copied, then Contribute for the site's Visitors group on this list only), uploads the
          fake draft and the fake form, saves the fake PDF to sign and writes the test page 90161Z-T21-links-r2.html (4 links).
          Run it twice and the second run changes nothing on the site.
    Run   (about 16 minutes, an estimate)  Adds 3 command rows (RUN-FILES, RUN-MAIL, RUN-APP, one tag), waits up to -WaitMinutes
          (default 14) for the flows' RESULT rows, downloads the files the flows made to the T21 files folder, checks property
          demotion, and prints one line per test (T3, T5, T6, T8, T9).
    Open  (a few seconds; no sign-in)  Writes the test page again and opens it in the browser.
    Sign  (a few seconds; no sign-in)  Puts the path for the signed copy on the clipboard and opens the fake PDF in the PDF program.
    Read  (about 1 to 5 minutes, an estimate)  Reads the rows the people and the flows wrote (waits up to -WaitMinutes, default 4
          here, for the flow rows of T10 and the 25-minute mail read) and prints one line for T4, T7, T9, T10 and a note for T2.
    Clean (about 1 minute, an estimate)  Moves the list and the library to the site Recycle Bin (restorable for 93 days).
          Nothing else is removed. The solution and the OneDrive folder /90161Z-probe are removed by hand (the part says which).
  WHAT IT CHANGES ON THE SITE: Make adds the two objects, their columns, their permissions and two files. Run adds 3 rows to the
  list (the flows add more, and files to the library). Read and Open change nothing. Clean recycles the two objects. On this
  computer: the T21 folder (the PDF to sign, the test page, a files folder). Every output line shows the site as <SITE> and the
  DODID as <DODID>; the test page holds the site address and stays on this computer (it is not a result file).
  Output: 90161Z-T21-probe-make-r2.txt, -run-r2.txt, -read-r2.txt or -clean-r2.txt in the T21 folder (send them back).
  Last line of each part: PROBE <part> done: passed=<n> failed=<n>. Exit code 0 when the part ran to its end (a FAILED test is
  a result); exit 1 only when the part could not run (sign-in, missing list).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part, -WaitMinutes, -NoPause. -PollSeconds,
  -TestDir and -NoLaunch are for the tests in tests/run.sh.
#>
param([string]$Id, [ValidateSet('Make', 'Run', 'Open', 'Sign', 'Read', 'Clean')][string]$Part, [double]$WaitMinutes = 14, [switch]$NoPause, [int]$PollSeconds = 20, [string]$TestDir, [switch]$NoLaunch)
$task = 'T21'
$pollEvery = $PollSeconds
$LibTitle = '90161Z Probe Files'
$LibFolder = '90161ZProbeFiles'
$ListTitle = '90161Z Probe'
$ListFolder = '90161ZProbe'
$DraftName = '90161Z-T21-fake-draft-r1.docx'
$SignName = '90161Z-T21-fake-sign-r1.pdf'
$SignedName = '90161Z-T21-fake-sign-r1-signed.pdf'
$FormName = '90161Z-T21-fake-form-r1.html'
$LinksName = '90161Z-T21-links-r2.html'
$PdfCopyName = '90161Z-T21-T5a.pdf'
$Rev = 'r2'

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

function Get-HtmlText([string]$Text) { return [System.Net.WebUtility]::HtmlEncode($Text) }
function Write-LinksPage([string]$Dir, [string]$Site) {
  # The test page (PFM 16 Nov 26, split front end): one big link per thing to open. It holds the site address, so it stays in
  # the T21 folder on this computer; it is never a result file. Colors and font as the RADE window.
  $s = $Site.TrimEnd('/')
  $links = @(
    @('Open the fake draft', ($s + '/' + $LibFolder + '/' + $DraftName + '?web=1'), 'Test T2: the Word draft in the browser.'),
    @('Open the PDF copy', ($s + '/' + $LibFolder + '/' + $PdfCopyName), 'Test T2: the PDF a flow made from the draft.'),
    @('Open the new row form', ($s + '/Lists/' + $ListFolder + '/NewForm.aspx'), 'Tests T4, T7 and T10: the form other people use.'),
    @('Open the probe list', ($s + '/Lists/' + $ListFolder + '/AllItems.aspx'), 'The rows the tests wrote.'))
  $body = New-Object System.Text.StringBuilder
  [void]$body.Append('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>90-161.Z test page r2</title><style>')
  [void]$body.Append('body{font-family:"Segoe UI",Arial,sans-serif;color:#1b2430;background:#fff;margin:0}.light{height:6px;background:#ffd520}')
  [void]$body.Append('main{max-width:760px;padding:24px 32px}h1{font-family:"Segoe UI Semibold","Segoe UI",Arial,sans-serif;font-weight:600;font-size:29px;color:#0b2545;margin:8px 0 4px}')
  [void]$body.Append('p{font-size:15px;color:#5a6573;margin:0 0 24px}a.go{display:block;border:1px solid #00539f;background:#00539f;color:#fff;text-decoration:none;font-size:17px;font-weight:700;padding:14px 18px;margin:0 0 4px}')
  [void]$body.Append('a.go:focus{outline:2px solid #0b2545;outline-offset:2px}span.why{display:block;font-size:14px;color:#5a6573;margin:0 0 20px}</style></head><body><div class="light"></div><main>')
  [void]$body.Append('<h1>90-161.Z test page</h1><p>Round R26 r2. Fake data only. Open each link when the RADE window says so.</p>')
  foreach ($l in $links) { [void]$body.Append('<a class="go" href="' + (Get-HtmlText $l[1]) + '">' + (Get-HtmlText $l[0]) + '</a><span class="why">' + (Get-HtmlText $l[2]) + '</span>') }
  [void]$body.Append('</main></body></html>')
  Set-Content -LiteralPath (Join-Path $Dir $LinksName) -Value $body.ToString() -Encoding UTF8
  return $links.Count
}
function Get-Where([string]$Detail, [string]$Send) {
  # "S3=inbox+sent S5=none ..." -> the places for one send ('' when the read did not name it).
  if ($Detail -match ('\b' + $Send + '=([^\s;]+)')) { return $Matches[1] }
  return ''
}
function Test-Arrived([string]$Where) { return ($Where -match 'inbox|junk') }
function Get-MailLine([string]$Name, $Rows, [string[]]$Reads) {
  # One line for T9: each send, its send status and where each read found it. PASSED when one send arrived (inbox or junk).
  $sends = @(@('S3', 'own mailbox, subject with [TEST]'), @('S5', 'own mailbox, no [TEST]'), @('S6', 'shared mailbox, no [TEST]'))
  $pieces = @(); $arr = @{}
  foreach ($s in $sends) {
    $sent = Find-Result $Rows 'T9' $s[0]
    $where = @(); $arr[$s[0]] = $false
    foreach ($rd in $Reads) {
      $r = Find-Result $Rows 'T9' $rd
      if ($r) { $w = Get-Where $r.ProbeDetail $s[0]; if ($w) { $where += ($rd + '=' + $w); if (Test-Arrived $w) { $arr[$s[0]] = $true } } }
    }
    $sentText = $(if ($sent) { Format-Detail $sent.ProbeDetail } else { 'no result row' })
    $pieces += ($s[0] + ' (' + $s[1] + ') ' + $sentText + $(if ($where.Count) { '; found ' + ($where -join ', ') } else { '; found nowhere read' }))
  }
  Add-Test $Name $pieces ($arr['S3'] -or $arr['S5'] -or $arr['S6'])
  # What the two own-mailbox sends say about the cause (PFM 16 Nov 26: one subject with [TEST], one without; the body is the same).
  $cause = $(if ($arr['S5'] -and -not $arr['S3']) { 'only the e-mail without [TEST] arrived: "[TEST]" in the subject is the likely cause' }
    elseif ($arr['S5'] -and $arr['S3']) { 'both own-mailbox e-mails arrived: the subject is not the cause' }
    elseif ($arr['S3']) { 'only the e-mail with [TEST] arrived: the subject is not the cause' }
    else { 'neither own-mailbox e-mail arrived in the reads: the subject alone is not the cause, or they arrive later' })
  $script:lines.Add('NOTE ' + $Name + ' cause: ' + $cause)
}
function Get-AuthorId($Row) { $a = $Row.Item['Author']; if ($a -and $a.LookupId) { return [int]$a.LookupId }; return 0 }

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
$passed = 0; $failed = 0
$fatal = $false
try {
  $ErrorActionPreference = 'Stop'
  if (-not $Part) { throw 'PART not given: use -Part Make, Run, Open, Sign, Read or Clean.' }
  if ($Part -eq 'Read' -and -not $PSBoundParameters.ContainsKey('WaitMinutes')) { $WaitMinutes = 4 }
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 21' -Create }
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $lines.Add('TASK T21 easy-path probe ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + $(if ($Part -eq 'Run') { ', wait-minutes=' + $WaitMinutes } else { '' }))

  if ($Part -eq 'Open' -or $Part -eq 'Sign') {
    # No sign-in: these two parts only work on this computer.
    if ($Part -eq 'Open') {
      $n = Write-LinksPage $dir $site
      Add-Item 'o1-page' 'PASS' ('test page written, links=' + $n)
      if (-not $NoLaunch) { Start-Process -FilePath (Join-Path $dir $LinksName) }
      Add-Item 'o2-open' 'PASS' ('test page opened in the browser=' + $(if ($NoLaunch) { 'no (test run)' } else { 'yes' }))
    } else {
      $pdf = Join-Path $dir $SignName
      if (-not (Test-Path -LiteralPath $pdf -PathType Leaf)) { throw ('PDF to sign not found in the T21 folder: run "T21 Make the probe list and library ' + $Rev + '" first.') }
      $target = Join-Path $dir $SignedName
      $clip = 'no'
      if (-not $NoLaunch) { try { Set-Clipboard -Value $target; $clip = 'yes' } catch { $clip = 'no' } } else { $clip = 'no (test run)' }
      Add-Item 's1-clipboard' $(if ($clip -eq 'no') { 'FAIL' } else { 'PASS' }) ('path for the signed copy on the clipboard=' + $clip)
      if (-not $NoLaunch) { Start-Process -FilePath $pdf }
      Add-Item 's2-open' 'PASS' ('fake PDF opened in the PDF program=' + $(if ($NoLaunch) { 'no (test run)' } else { 'yes' }))
    }
  } else {
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

    # m3: columns (internal name = display name). ProbePerson is a person column: its box searches the address list (T7 a).
    $want = @(
      @{ List = $lib; Name = 'ProbeSubject'; Type = 'Text' }, @{ List = $lib; Name = 'ProbeOPR'; Type = 'Text' },
      @{ List = $lst; Name = 'ProbeTest'; Type = 'Text' }, @{ List = $lst; Name = 'ProbeWay'; Type = 'Text' },
      @{ List = $lst; Name = 'ProbeResult'; Type = 'Text' }, @{ List = $lst; Name = 'ProbeDetail'; Type = 'Note' },
      @{ List = $lst; Name = 'ProbePerson'; Type = 'User' })
    $have = @{}
    foreach ($l in @($lib, $lst)) { $have[[string]$l.Id] = @(Get-RestValue ("_api/web/lists(guid'" + $l.Id + "')/fields?" + '$select=InternalName&$top=2000') | ForEach-Object { [string]$_.InternalName }) }
    $bad = 0
    foreach ($c in $want) {
      if ($have[[string]$c.List.Id] -contains $c.Name) { $skip.columns++; continue }
      $extra = $(if ($c.Type -eq 'Note') { ' RichText="FALSE" NumLines="6"' } elseif ($c.Type -eq 'User') { ' List="UserInfo" ShowField="ImnName" UserSelectionMode="PeopleOnly" UserSelectionScope="0"' } else { '' })
      $xml = '<Field Name="' + $c.Name + '" StaticName="' + $c.Name + '" DisplayName="' + $c.Name + '" Required="FALSE" Type="' + $c.Type + '"' + $extra + '></Field>'
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
      $lines.Add('NOTE m5: no associated Visitors group on this site, so Contribute was not added; the T4 test needs a person who is a site visitor to write')
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
    # m8: the test page (it holds the site address: it stays in the T21 folder).
    $n = Write-LinksPage $dir $site
    Add-Item 'm8-page' 'PASS' ('test page in the T21 folder, links=' + $n)
    $lines.Add('MADE library=' + $made.library + ' list=' + $made.list + ' columns=' + $made.columns + ' attachments=' + $made.attachments + ' permission changes=' + $made.permissions + ' files=' + $made.files)
    $lines.Add('SKIPPED (already there) library=' + $skip.library + ' list=' + $skip.list + ' columns=' + $skip.columns + ' attachments=' + $skip.attachments + ' files=' + $skip.files)
  }
  elseif ($Part -eq 'Run') {
    $lib = Find-ByFolder $LibFolder
    $lst = Find-ByFolder $ListFolder
    if (-not $lib -or -not $lst) { throw 'LIST not found: run -Part Make first.' }
    $tag = 'R26' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $ids = @()
    foreach ($c in 'RUN-FILES', 'RUN-MAIL', 'RUN-APP') { $ids += [int](Add-PnPListItem -List $ListTitle -Values @{ Title = ($c + ' ' + $tag) } -ErrorAction Stop).Id }
    $floor = ($ids | Measure-Object -Minimum).Minimum
    Add-Item 'r1-commands' 'INFO' ('command rows made: RUN-FILES, RUN-MAIL and RUN-APP, tag ' + $tag)
    $fields = @('Title', 'ProbeTest', 'ProbeWay', 'ProbeResult', 'ProbeDetail')
    $need = @(@('T5', 'a'), @('T5', 'b'), @('T3', 'b'), @('T3', 'c'), @('T9', 'READ2'), @('T7', 'b'), @('T8', 'a'), @('T8', 'b'))
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

    # One line per test. Ways that R26 r1 settled are named, not tried again (docs/reviews/2026-11-16-r26-results.md).
    $t3 = @(@{ Text = 'a Word Online populate=not tried (R26 r1: refused, Premium licence)'; Pass = $false }, (Format-Way $rows 'T3' 'b' 'update properties then convert' $false), (Format-Way $rows 'T3' 'c' 'HTML through OneDrive Convert' $false))
    Add-Test 'T3' @($t3 | ForEach-Object { $_.Text }) (@($t3 | Where-Object { $_.Pass }).Count -gt 0)
    Add-WayTest 'T5' $rows @(@('T5', 'a', 'OneDrive Convert file', $false), @('T5', 'b', 'SharePoint request', $false))
    $t6 = ($titleYes -eq 'yes')
    Add-Test 'T6' @('a AI Builder=not tried (R26 r1: unavailable)', ('b library columns=' + $(if ($t6) { 'PASS' } else { 'FAIL' }) + ' (Title promoted=' + $titleYes + '; ProbeSubject present=' + $subjYes + ')')) $t6
    Add-WayTest 'T8' $rows @(@('T8', 'a', 'Office 365 Groups members', $false), @('T8', 'b', 'Graph mailbox request', $false))
    Get-MailLine 'T9' $rows @('READ1', 'READ2')
    $lines.Add('NOTE T9: the flow reads once more at 25 minutes; step "T21 Read the test results ' + $Rev + '" prints that read')
  }
  elseif ($Part -eq 'Read') {
    $lst = Find-ByFolder $ListFolder
    if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
    $rf = @('Title', 'ProbeTest', 'ProbeWay', 'ProbeResult', 'ProbeDetail', 'Author', 'ProbePerson')
    $rows = @(Get-ListRow $ListTitle $rf)
    # The files flow answers a minute or more after a T10 row; the mail flow's third read comes 25 minutes after the run.
    # Wait for them (default 4 minutes here) only when there is something to wait for.
    $hasT10 = @($rows | Where-Object { $_.Title -eq 'T10' }).Count -gt 0
    # The newest mail run only: older RUN-MAIL runs on the list must not mix in (rows after its command row).
    $mailFloor = [int](@($rows | Where-Object { $_.Title -like 'RUN-MAIL *' } | ForEach-Object { $_.Id }) + 0 | Measure-Object -Maximum).Maximum
    $hasRun = $mailFloor -gt 0
    if ($hasT10 -or $hasRun) {
      $ok = Wait-Until {
        $rows = @(Get-ListRow $ListTitle $rf)
        [bool]((-not $hasT10 -or (Find-Result $rows 'T10' 'a')) -and (-not $hasRun -or (Find-Result @($rows | Where-Object { $_.Id -gt $mailFloor }) 'T9' 'READ3'))) } 'the flows'' last result rows (T10 a, the 25-minute mail read)'
      $rows = @(Get-ListRow $ListTitle $rf)
      $lines.Add('WAIT last result rows ' + $(if ($ok) { 'there' } else { 'not all there (time ran out; the lines below say which are missing)' }))
    } else { $lines.Add('WAIT none: no T10 row and no mail run on the list') }
    $meId = 0
    try { $meId = [int]((Invoke-Rest 'Get' '_api/web/currentuser?$select=Id' '') | ConvertFrom-Json).Id } catch { $meId = 0 }

    # T4: a person with Read on the site writes a row through the list form (Contribute on this list only).
    $t4a = @($rows | Where-Object { ([string]$_.Title).Trim() -eq 'T4a' })
    $other = @($t4a | Where-Object { $meId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $meId }).Count
    Add-Test 'T4' @(('a list form by a second person=' + $(if ($other -ge 1) { 'PASS' } else { 'FAIL' }) + ' (T4a rows=' + $t4a.Count + '; rows by a second person=' + $other + '; that the person has only Read rests on your choice of person)'),
      'b flow with the owner connection=not tried (needed only when way a fails)') ($other -ge 1)

    # T7 a: the person box of the list form searches the address list. Which fields of the chosen person have a value
    # (yes or no; never the value). T7 b: the flow's Office 365 Users search.
    $withPerson = @($rows | Where-Object { $p = $_.Item['ProbePerson']; $p -and $p.LookupId })
    $aText = 'a list form person box=FAIL (rows with a person=0)'; $aPass = $false
    if ($withPerson.Count) {
      $uid = [int]$withPerson[0].Item['ProbePerson'].LookupId
      # One request per field with $select (a whole list item holds both "Id" and "ID", which Windows PowerShell 5.1's
      # ConvertFrom-Json refuses); the raw text is read with a pattern, so no JSON parser sees it. A field the list does
      # not have, or a failed request, reads as 'not read'. PASS needs the e-mail address to have a value (the easy path: office and mail).
      $present = @(); $mailYes = $false
      foreach ($f in 'EMail', 'Department', 'JobTitle', 'Office') {
        $v = 'n/a'
        try {
          $raw = Invoke-Rest 'Get' ('_api/web/siteuserinfolist/items(' + $uid + ')?$select=' + $f) ''
          if ($raw -match ('"' + $f + '"\s*:\s*"([^"]*)"')) { $v = $(if ($Matches[1]) { 'yes' } else { 'no' }) } elseif ($raw -match ('"' + $f + '"\s*:\s*null')) { $v = 'no' }
        } catch { $v = 'not read' }
        if ($f -eq 'EMail' -and $v -eq 'yes') { $mailYes = $true }
        $present += ($f + '=' + $v)
      }
      $aPass = $mailYes
      $aText = 'a list form person box=' + $(if ($aPass) { 'PASS' } else { 'FAIL' }) + ' (rows with a person=' + $withPerson.Count + '; fields with a value: ' + ($present -join ' ') + '; that the box searched the address list rests on your answer)'
    }
    $b7 = Format-Way $rows 'T7' 'b' 'flow Office 365 Users search' $false
    Add-Test 'T7' @($aText, $b7.Text) ($aPass -or $b7.Pass)

    # T10: the signed PDF attached through the list form. a and b: the files flow; c: this script reads the attachment itself.
    $t10 = @($rows | Where-Object { $_.Title -eq 'T10' } | Sort-Object { $_.Id } -Descending)
    $cText = 'c signature markers read here=FAIL (no T10 row)'; $cPass = $false
    if ($t10.Count) {
      $att = @(Get-RestValue ("_api/web/lists(guid'" + $lst.Id + "')/items(" + $t10[0].Id + ')/AttachmentFiles'))
      $byteRange = 'no'; $sig = 'no'
      if ($att.Count) {
        $filesDir = Join-Path $dir 'files'
        if (-not (Test-Path -LiteralPath $filesDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $filesDir) }
        $local = Join-Path $filesDir '90161Z-T21-T10-attachment.pdf'
        try {
          Get-PnPFile -Url ([string]$att[0].ServerRelativeUrl) -Path $filesDir -FileName '90161Z-T21-T10-attachment.pdf' -AsFile -Force -ErrorAction Stop
          $txt = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($local))
          if ($txt.Contains('/ByteRange')) { $byteRange = 'yes' }
          if ($txt -match '/Type\s*/Sig\b' -or $txt -match '/SubFilter\s*/(adbe|ETSI)') { $sig = 'yes' }
        } catch { $byteRange = 'not read' }
      }
      $cPass = ($byteRange -eq 'yes' -and $sig -eq 'yes')
      $cText = 'c signature markers read here=' + $(if ($cPass) { 'PASS' } else { 'FAIL' }) + ' (attachments=' + $att.Count + ' byteRange=' + $byteRange + ' sig=' + $sig + ')'
    }
    $a10 = Format-Way $rows 'T10' 'a' 'signature markers by the flow' $false
    $b10 = Format-Way $rows 'T10' 'b' 'OneDrive Convert on the signed PDF' $false
    Add-Test 'T10' @($a10.Text, $b10.Text, $cText) ($a10.Pass -or $cPass)

    Get-MailLine 'T9' @($rows | Where-Object { $_.Id -gt $mailFloor }) @('READ1', 'READ2', 'READ3')
    $lines.Add('NOTE T2: left to the answers you give in the RADE window (this script does not read them)')
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
    $lines.Add('NOTE by hand: delete the solution "90-161.Z probe" (Power Automate, Solutions) and the OneDrive folder /90161Z-probe. This script does not touch them')
  }
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  }
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} catch {
  $fatal = $true
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(400, $m.Length)) + ' (a part that stopped can be run again: Make skips what is there)')
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} finally {
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir -and $Part -and $Part -notin 'Open', 'Sign') { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T21-probe-' + $Part.ToLowerInvariant() + '-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
