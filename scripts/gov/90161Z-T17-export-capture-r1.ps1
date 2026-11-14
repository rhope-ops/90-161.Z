<#
.SYNOPSIS
  90-161.Z Task 17 solution export capture, r1 (R16). Read-only. Windows PowerShell 5.1, no modules.
.DESCRIPTION
  What it is for: R15's solution import stopped with an XML error, because the test solution's layout was written from
  memory (PFM 14 Nov 26: copy a real export). This reads the small solution the PFM exported by hand in the step before,
  so the next test solution can match a real export from this environment exactly. About 1 minute (an estimate).
  It changes nothing. It reads the newest "*90161ZExportSample*.zip" from the last 4 hours in the Downloads folder or the
  T17 folder, and writes one plain text file with the structure of every XML and JSON file in the zip. Values are kept
  only by an allow list (see Protect-Value): numbers, true/false, GUIDs as <GUID-n>, one-token codes and flow
  expressions; every other value, the publisher block and all variable values become <text:N>. A value that the leak
  check (Find-Leak: e-mail, web address except public schema hosts, host name, /sites/ or /teams/ path, IP, UNC path,
  double encoding, the DODID) flags is replaced too. Zip entry names are kept only when the export format or the guide
  gives them. Other files are listed by size only. The leak check then reads the whole output; if it finds anything, no file
  is written (review R16). It also records whether each file starts with a byte-order mark (R15's error can come
  from one) and how the file names in the zip are written.
  Output: 90161Z-T17-export-capture-r1.txt in the T17 folder (send this). The zip itself stays on this computer.
  Parameters (used by the 90-161.Z Deployer): -Id, -NoPause, -Zip (a path, to read another file).
#>
param([string]$Id, [switch]$NoPause, [string]$Zip)
$task = 'T17'
$Pattern = '*90161ZExportSample*.zip'   # unique name PFM90161ZExportSample (a unique name cannot start with a digit)
$MaxAgeHours = 4
# Public schema hosts the solution format itself uses; every other web address is masked.
$KeepHosts = @('www.w3.org', 'schema.management.azure.com', 'schemas.microsoft.com', 'schemas.openxmlformats.org', 'json-schema.org')
# Host names to mask: any dotted name that ends in one of these (bare, in a URL, JSON-escaped or percent-encoded).
$HostRx = '(?i)\b[a-z0-9-]+(\.[a-z0-9-]+)*\.(mil|gov|us|com|net|org|edu|io|cloud|example)\b'

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
  # The task folder C:\Users\<DODID>\OneDrive - United States Air Force\90-161.Z\<Task>. -Create makes it when missing.
  $tail = 'OneDrive - United States Air Force\90-161.Z\' + $Task
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

# Review R16 (second pass): blocking patterns kept missing forms, so values are kept only by an allow list. The structure
# (element, attribute and key names) stays; a value stays only when it is empty, a number, true/false, a GUID (shown as
# <GUID-n>, the same n for the same GUID), one token with no spaces (codes, IDs, paths) or a flow expression (starts with
# "@"), and the leak check finds nothing in it. Every other value becomes <text:N> (N = its length). The publisher block,
# default values and every value in a variable-value file are always replaced.
$script:guids = @{}
$GuidRx = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
$Always = @('defaultvalue', 'value', 'description', 'displayname', 'connectionreferencedisplayname', 'name')   # key or attribute names whose value is always replaced

function Protect-Guid([string]$T) {
  return [regex]::Replace($T, $GuidRx, { param($m) $k = $m.Value.ToLowerInvariant(); if (-not $script:guids.ContainsKey($k)) { $script:guids[$k] = '<GUID-' + ($script:guids.Count + 1) + '>' }; $script:guids[$k] })
}

function Protect-Value([string]$V, [string]$Key, [bool]$Force) {
  if ($null -eq $V -or $V -eq '') { return $V }
  $script:values++
  $hide = { $script:hidden++; '<text:' + $V.Length + '>' }
  if ($Force -or ($Always -contains $Key.ToLowerInvariant())) { return (& $hide) }
  if ($V -match '^-?\d+(\.\d+)?$' -or $V -match '^(?i)(true|false)$') { return $V }
  if ($Key -match '(?i)version$' -and $V -match '^\d+(\.\d+){1,3}$') { return $V }   # 1.0.0.1, 9.2.26094.172: layout facts, not IPs
  $g = Protect-Guid $V
  # A path (JsonFileName, file references) gets the entry-name allow list (review R16 3: a flow's file name holds its name).
  if ($g -match '(?i)\.(json|xml)$') { return (Protect-EntryName $g) }
  if ((Find-Leak $g) -gt 0) { return (& $hide) }
  if ($g -match '^[\w.$/:\[\]()''{},?=+#<>-]{1,120}$') { return $g }
  if ($g.StartsWith('@') -and $g.Length -le 400) { return $g }
  return (& $hide)
}

function Protect-Xml([string]$T, [string]$Name) {
  $d = New-Object System.Xml.XmlDocument
  $d.XmlResolver = $null; $d.PreserveWhitespace = $false
  $rs = New-Object System.Xml.XmlReaderSettings; $rs.DtdProcessing = 'Prohibit'; $rs.XmlResolver = $null   # a DTD or entity: not shown
  $rd = [System.Xml.XmlReader]::Create((New-Object System.IO.StringReader $T), $rs)
  try { $d.Load($rd) } finally { $rd.Close() }
  foreach ($c in @($d.SelectNodes('//comment() | //processing-instruction()'))) { $null = $c.ParentNode.RemoveChild($c) }
  $all = $Name -match '(?i)environmentvariablevalue'
  foreach ($n in @($d.SelectNodes('//*'))) {
    $inPub = $all -or [bool]$n.SelectSingleNode('ancestor-or-self::*[local-name()="Publisher"]')
    $keepPrefix = @('CustomizationPrefix', 'CustomizationOptionValuePrefix') -contains $n.LocalName
    foreach ($at in @($n.Attributes)) { if ($at.Prefix -ne 'xmlns' -and $at.LocalName -ne 'xmlns') { $at.Value = Protect-Value $at.Value $at.LocalName $inPub } }
    foreach ($c in @($n.ChildNodes)) {
      if ($c.NodeType -eq 'Text' -or $c.NodeType -eq 'CDATA') { $c.Value = Protect-Value $c.Value $n.LocalName ($inPub -and -not $keepPrefix) }
    }
  }
  $sw = New-Object System.IO.StringWriter
  $xs = New-Object System.Xml.XmlWriterSettings; $xs.Indent = $true; $xs.OmitXmlDeclaration = $true
  $w = [System.Xml.XmlWriter]::Create($sw, $xs); $d.Save($w); $w.Close()
  return $sw.ToString()
}

function Protect-JsonNode($O, [string]$Key, [bool]$Force) {
  if ($null -eq $O) { return $null }
  if ($O -is [string]) { return (Protect-Value $O $Key $Force) }
  if ($O -is [System.Management.Automation.PSCustomObject]) {
    foreach ($p in @($O.PSObject.Properties)) { $p.Value = Protect-JsonNode $p.Value $p.Name $Force }
    return $O
  }
  if ($O -is [System.Collections.IEnumerable]) { return ,@(foreach ($x in $O) { Protect-JsonNode $x $Key $Force }) }
  return $O   # number or boolean
}

function Protect-Json([string]$T, [string]$Name) {
  $o = $T | ConvertFrom-Json
  $o = Protect-JsonNode $o '' ($Name -match '(?i)environmentvariablevalue')
  # JSON keys are structure, but a key could still hold a name: the leak check reads the whole output.
  return (Protect-Guid ($o | ConvertTo-Json -Depth 100))
}

function Protect-EntryName([string]$P) {
  # Entry names by allow list: the names a solution export uses, and the names the guide gives (review R16: a name
  # inside one token cannot be found by a pattern).
  $known = @('solution.xml', 'customizations.xml', '[Content_Types].xml', 'Workflows', 'environmentvariabledefinitions',
    'environmentvariabledefinition.xml', 'environmentvariablevalues.json', 'Other', 'Relationships.xml')
  $parts = foreach ($x in ($P -split '/')) {
    $g = Protect-Guid $x
    if ($g -eq '' -or $known -contains $g -or $g -match '(?i)^\w*90161Z\w*ExportSample[\w-]*?(<GUID-\d+>)?\.json$' -or $g -match '^[a-z0-9]{2,8}_SiteU[Rr][Ll]$' -or $g -match '^<GUID-\d+>$') { $g }
    else { '<name:' + $x.Length + '>' }
  }
  return ($parts -join '/')
}

function Find-Leak([string]$Text) {
  # An independent check (review R16 MAJOR): patterns the masking must have removed. Returns the number of hits.
  $n = 0
  $n += [regex]::Matches($Text, '[\w.+-]+(@|%40|\\u0040)[\w-]+\.[\w-]+').Count
  $n += [regex]::Matches($Text, '(?i)(sharepoint\.[a-z]|\.mil\b|onmicrosoft|appsplatform)').Count
  $n += [regex]::Matches($Text, '(?i)sites(/|\\/|%2F)(?!<SITE-NAME>)[\w-]').Count
  foreach ($m in [regex]::Matches($Text, '(?i)https?(://|:\\/\\/|%3A%2F%2F)[^\s"''<>]+')) {
    $u = $m.Value -replace '\\/', '/' -replace '(?i)%3A', ':' -replace '(?i)%2F', '/'
    $h = ''; try { $h = ([uri]$u).Host.ToLowerInvariant() } catch { $h = '' }
    if (-not ($KeepHosts -contains $h)) { $n++ }
  }
  foreach ($m in [regex]::Matches($Text, $HostRx)) { if (-not ($KeepHosts -contains $m.Value.ToLowerInvariant())) { $n++ } }
  $n += [regex]::Matches($Text, '(?i)(%25[0-9a-f]{2}|\\\\[\w-]+\\|\b\d{1,3}(\.\d{1,3}){3}\b|/teams/)').Count   # double-encoded, UNC, IPv4, /teams/
  foreach ($x in $secret) { if ($x -and $Text -match [regex]::Escape($x)) { $n++ } }
  return $n
}

function Find-ExportZip([string]$TaskDir) {
  $since = (Get-Date).AddHours(-$MaxAgeHours)
  $where = @()
  if ($env:USERPROFILE) { $where += (Join-Path $env:USERPROFILE 'Downloads') }
  $where += $TaskDir
  $hits = @()
  foreach ($w in $where) {
    if (Test-Path -LiteralPath $w -PathType Container) {
      $hits += @(Get-ChildItem -LiteralPath $w -File -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $since })
    }
  }
  return @($hits | Sort-Object LastWriteTime -Descending)[0]
}

$secret = @()
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $secret = $who.Secret
  $dir = Get-TaskDir $who.Id $task 'Task 17' -Create
  Set-Location -LiteralPath $dir
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('TASK T17 solution export capture r1, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $outFile = Join-Path $dir '90161Z-T17-export-capture-r1.txt'
  if (Test-Path -LiteralPath $outFile -PathType Leaf) { Remove-Item -LiteralPath $outFile -Force }   # never send an older copy
  $z = $(if ($Zip) { Get-Item -LiteralPath $Zip } else { Find-ExportZip $dir })
  if (-not $z) {
    throw ('NO EXPORT: no ' + $Pattern + ' from the last ' + $MaxAgeHours + ' hours in Downloads or the T17 folder. What to do: export the solution again (step before), or save the zip into the T17 folder, then run this round again.')
  }
  $lines.Add('ZIP ' + $z.Name + ' bytes=' + $z.Length + ' saved=' + $z.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($z.FullName)
  $script:values = 0; $script:hidden = 0; $text = 0; $other = 0
  $body = New-Object System.Collections.Generic.List[string]
  try {
    $entries = @($archive.Entries | Where-Object { $_.FullName -notmatch '/$' })
    $lines.Add('ENTRIES ' + $entries.Count + ' names-with-backslash=' + @($entries | Where-Object { $_.FullName -like '*\*' }).Count)
    foreach ($e in $entries) {
      $ext = [IO.Path]::GetExtension($e.Name).ToLowerInvariant()
      $en = Protect-EntryName $e.FullName
      $lines.Add('ENTRY ' + $en + ' bytes=' + $e.Length + ' compressed=' + $e.CompressedLength)
      if (@('.xml', '.json') -notcontains $ext) { $other++; continue }
      $s = $e.Open(); $ms = New-Object System.IO.MemoryStream
      try { $s.CopyTo($ms) } finally { $s.Dispose() }
      $bytes = $ms.ToArray()
      $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
      $t = (New-Object System.Text.UTF8Encoding $false).GetString($bytes)
      if ($bom) { $t = $t.Substring(1) }
      $decl = $(if ($t -match '^\s*(<\?xml[^>]{0,120}\?>)') { $Matches[1] } else { 'none' })
      try { $safe = $(if ($ext -eq '.xml') { Protect-Xml $t $e.FullName } else { Protect-Json $t $e.FullName }) }
      catch { $safe = '(not shown: it did not parse, ' + $_.Exception.GetType().Name + ')' }
      $text++
      $body.Add('')
      $body.Add('==== FILE ' + $en + ' bytes=' + $bytes.Length + ' bom=' + $(if ($bom) { 'yes' } else { 'no' }) + ' line-ends=' + $(if ($t -match "`r`n") { 'CRLF' } elseif ($t -match "`n") { 'LF' } else { 'none' }) + ' declaration=' + $decl + ' ====')
      $body.Add((ConvertTo-Masked $safe $secret))
    }
  } finally { $archive.Dispose() }
  $left = 0; foreach ($l in @($body)) { $left += Find-Leak $l }
  $lines.Add('CAPTURE ' + $(if ($left -eq 0) { 'PASS' } else { 'FAIL' }) + ' text-files=' + $text + ' other-files=' + $other + ' values=' + $script:values + ' replaced=' + $script:hidden + ' leaks-found=' + $left)
  $lines | ForEach-Object { Write-Host (ConvertTo-Masked $_ $secret) }
  Write-Host ''
  if ($left -gt 0) {
    # Review R16 MAJOR: on a leak no file is written, so the round has nothing to attach.
    Write-Host 'CAPTURE FAIL: a value the masking should have removed is still there. No file was written.'
    Write-Host 'What to do: send the e-mail without it; Claude changes the masking and sends a new round.'
    exit 1
  }
  $out = @($lines | ForEach-Object { ConvertTo-Masked $_ $secret }) + @($body)
  [System.IO.File]::WriteAllText($outFile, (($out -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding $false))
  Write-Host 'Saved: 90161Z-T17-export-capture-r1.txt in the T17 folder. Nothing was changed. The zip stays on this computer.'
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
  exit 1
} finally {
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
