<#
.SYNOPSIS
  90-161.Z Task 24 r6, module "zip": part 0 (R36, PFM 19 Nov 26: flows find lists by GUID). Before the import it reads the GUID of
  each list that a placeholder of the solution zip names and writes them into a copy of the zip (System.IO.Compression; no module).
.DESCRIPTION
  Loaded by 90161Z-T24-full-solution-test-r6.ps1 -Part 0 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the folder the main file sets ($dir) and its Add-Line and Assert-TaskFile.
  A placeholder is '<mark>[<list title>]' (scripts/build_flow_solution.py writes it; tests/check_flow_solution.py checks the mark).
  The zip the round saved is not changed; the ready zip is removed when a list is missing or a placeholder is left.
  Network: the one SharePoint site of the main file (one Get-PnPList per list title in the zip; no list scan), through PnP.PowerShell.
  Writes: on this computer only: the ready zip in the T24 folder and its path on the clipboard. Nothing on the site.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T24-full-solution-test-r6.ps1 -Part 0 loads it.
#>
# R36: the placeholder mark of scripts/build_flow_solution.py (LIST_GUID_MARK; tests/check_flow_solution.py checks they match): '<mark>[<list title>]'.
$ListGuidMark = '90161Z-LIST-GUID'
$SolutionZip = '90161Z-T24-full-flows-r5.zip'
$ReadyZip = '90161Z-T24-full-flows-r5-ready.zip'

<#
.SYNOPSIS
  Reads every entry of a zip as bytes, in the zip's own order (System.IO.Compression; Windows PowerShell 5.1 has it).
.PARAMETER Path
  The zip file.
.OUTPUTS
  System.Object[]. One object per entry: Name, Bytes (byte[]), Time (its LastWriteTime).
#>
function Read-ZipEntry([string]$Path) {
  $all = New-Object System.Collections.Generic.List[object]
  $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    foreach ($e in $zip.Entries) {
      $ms = New-Object System.IO.MemoryStream
      $s = $e.Open()
      try { $s.CopyTo($ms) } finally { $s.Dispose() }
      $all.Add([pscustomobject]@{ Name = $e.FullName; Bytes = $ms.ToArray(); Time = $e.LastWriteTime })
    }
  } finally { $zip.Dispose() }
  return $all.ToArray()
}

<#
.SYNOPSIS
  Finds the list titles that the placeholders of the solution zip name ('<mark>[<title>]', $ListGuidMark).
.PARAMETER Entry
  The zip entries from Read-ZipEntry.
.OUTPUTS
  System.String[]. The distinct titles, sorted.
#>
function Get-PlaceholderTitle($Entry) {
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $pattern = [regex]::Escape($ListGuidMark) + '\[([^\]\r\n"<>]+)\]'
  $titles = New-Object System.Collections.Generic.List[string]
  foreach ($x in $Entry) {
    foreach ($m in [regex]::Matches($utf8.GetString($x.Bytes), $pattern)) { $titles.Add($m.Groups[1].Value) }
  }
  return @($titles | Sort-Object -Unique)
}

<#
.SYNOPSIS
  Reads the GUID of each named list on the connected site (your own site only: one Get-PnPList per title, no list scan).
.PARAMETER Title
  The list titles from Get-PlaceholderTitle.
.OUTPUTS
  System.Collections.Hashtable. Title -> GUID text (lower case, no braces, as the flow designer stores a list). Throws when a list is missing.
#>
function Get-ListGuid([string[]]$Title) {
  $map = @{}
  foreach ($t in $Title) {
    $l = $null; $why = ''
    try { $l = Get-PnPList -Identity $t -ErrorAction Stop } catch { $why = ' (' + ([string]$_.Exception.Message -replace '\s+', ' ') + ')' }
    $g = [guid]::Empty
    if ($null -eq $l -or -not [guid]::TryParse([string]$l.Id, [ref]$g)) {
      throw ('LIST MISSING: no list titled "' + $t + '" on the site' + $why + '. Make the PFM lists first (T20), then run part 0 again.')
    }
    $map[$t] = $g.ToString()
  }
  return $map
}

<#
.SYNOPSIS
  Writes a copy of the solution zip with each list placeholder replaced by its GUID. An entry with no placeholder is copied byte for
  byte; the entry order, names and times are kept. A partly written file is removed when a step fails.
.PARAMETER Entry
  The zip entries from Read-ZipEntry.
.PARAMETER Guid
  Title -> GUID text from Get-ListGuid.
.PARAMETER Target
  The zip to write (replaced when it exists).
.OUTPUTS
  System.Int32. The number of entries that held a placeholder.
#>
function Write-ReadyZip($Entry, [hashtable]$Guid, [string]$Target) {
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Force }
  $changed = 0
  $ok = $false
  $fs = [System.IO.File]::Open($Target, [System.IO.FileMode]::CreateNew)
  try {
    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
      foreach ($x in $Entry) {
        $bytes = $x.Bytes
        $text = $utf8.GetString($bytes)
        if ($text.Contains($ListGuidMark)) {
          foreach ($t in $Guid.Keys) { $text = $text.Replace($ListGuidMark + '[' + $t + ']', $Guid[$t]) }
          $bytes = $utf8.GetBytes($text)
          $changed++
        }
        $e = $zip.CreateEntry($x.Name, [System.IO.Compression.CompressionLevel]::Optimal)
        $e.LastWriteTime = $x.Time
        $w = $e.Open()
        try { $w.Write($bytes, 0, $bytes.Length) } finally { $w.Dispose() }
      }
    } finally { $zip.Dispose() }
    $ok = $true
  } finally {
    $fs.Dispose()
    if (-not $ok) { Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue }
  }
  return $changed
}

<#
.SYNOPSIS
  Checks the ready zip: no placeholder mark is left in any entry, and each list variable (pfm_List...) has a GUID as its default.
.PARAMETER Path
  The ready zip.
.OUTPUTS
  System.Collections.Hashtable. Left (entry names that still hold the mark) and Lists (count of list variables with a GUID default) and
  Variables (count of list variable files).
#>
function Test-ReadyZip([string]$Path) {
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $left = @(); $lists = 0; $vars = 0
  foreach ($x in @(Read-ZipEntry $Path)) {
    $text = $utf8.GetString($x.Bytes)
    if ($text.Contains($ListGuidMark)) { $left += $x.Name }
    if ($x.Name -match '^environmentvariabledefinitions/pfm_List[A-Za-z]+/') {
      $vars++
      if ($text -match '<defaultvalue>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}</defaultvalue>') { $lists++ }
    }
  }
  return @{ Left = $left; Lists = $lists; Variables = $vars }
}

<#
.SYNOPSIS
  Part 0: writes the ready zip and adds the p0-list-guids result line. Throws with a plain message when it cannot.
#>
function Invoke-ListGuidPart {
  # 0. R36 (PFM 19 Nov 26): the list GUIDs go into a copy of the solution zip before the import. The zip the round saved stays as it is.
  Write-Host 'NOW Reading the solution zip.'
  $readyPath = Join-Path $dir $ReadyZip
  if (Test-Path -LiteralPath $readyPath) { Remove-Item -LiteralPath $readyPath -Force }   # an older ready zip: a stopped run leaves none to import
  Assert-TaskFile $dir @($SolutionZip) 'SOLUTION ZIP not in the T24 folder: '
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $entries = @(Read-ZipEntry (Join-Path $dir $SolutionZip))
  $titles = @(Get-PlaceholderTitle $entries)
  if (-not $titles.Count) { throw ('NO PLACEHOLDER in ' + $SolutionZip + ': it is not the zip the round saved. Save the round files again, then run part 0 again.') }
  Write-Host ('NOW Reading the GUIDs of ' + $titles.Count + ' lists on your site.')
  $guids = Get-ListGuid $titles
  Write-Host ('NOW Writing ' + $ReadyZip + '.')
  $changed = Write-ReadyZip $entries $guids $readyPath
  $check = Test-ReadyZip $readyPath
  if ($check.Left.Count) {
    Remove-Item -LiteralPath $readyPath -Force
    throw ('PLACEHOLDER LEFT in ' + ($check.Left -join ', ') + ': the ready zip was removed. Send this file.')
  }
  Add-Line 'p0-list-guids' $(if ($check.Lists -eq $titles.Count -and $check.Variables -eq $titles.Count) { 'PASS' } else { 'FAIL' }) (
    'lists read by title=' + $titles.Count + ' (' + ($titles -join ', ') + '); list variables with a GUID default=' + $check.Lists + ' of ' + $check.Variables +
    '; zip entries written with GUIDs=' + $changed + '; placeholders left=0; import ' + $ReadyZip)
  # The import card (R36 round) has no file of its own: the path of the ready zip goes on the clipboard for its Browse box.
  $clip = 'no (test run)'
  if (-not $TestDir) { try { Set-Clipboard -Value $readyPath; $clip = 'yes' } catch { $clip = 'no' } }
  Add-Line 'p0-clipboard' 'INFO' ('the path of the ready zip is on the clipboard=' + $clip)
}
