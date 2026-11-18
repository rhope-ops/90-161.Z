<#
.SYNOPSIS
  90-161.Z Task 21 probe r6, module "export": the part Export (reads the trigger of the hand-made button flow from the
  newest solution export zip on this computer).
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r6.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values the main file sets ($dir, $id, $ButtonIdName) and the helpers of the module "common"; the solution
  export zips of the last 3 hours in Downloads, Desktop, Documents (profile, OneDrive) and the T21 folder.
  Outputs: result lines (the trigger's type, kind, connector operationId and parameter NAMES only: never a value, site,
  list ID or address) and the flow ID file 90161Z-T21-button-flow-r5.txt in the T21 folder (not a result file).
  Network: none (no sign-in; it reads files on this computer).
  Writes: the flow ID file in the T21 folder.
  Credentials: none.
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r6.ps1 -Part Export loads it.
#>

# The file name of a flow JSON in a solution export ends with the flow's ID (a GUID) and .json.
$ExportGuidPattern = '([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\.json$'

<#
.SYNOPSIS
  The solution export zips of the last 3 hours: the T21 folder and Downloads, Desktop and Documents (2 levels deep) under
  the profile folder and OneDrive. Never the round's own files (names starting 90161Z-T, such as the health flow zip).
.OUTPUTS
  System.IO.FileInfo[]. The zips found (any order).
#>
function Find-ExportZip {
  $places = @($script:dir)
  $homes = @()
  if ($env:USERPROFILE) { $homes += $env:USERPROFILE }
  try { $homes += (Join-Path (Join-Path 'C:\Users' $script:id) 'OneDrive - United States Air Force') } catch { $null = $_ }
  if ($env:OneDrive) { $homes += $env:OneDrive }
  foreach ($hm in ($homes | Select-Object -Unique)) {
    foreach ($sub in @('Downloads', 'Desktop', 'Documents')) { try { $places += (Join-Path $hm $sub) } catch { $null = $_ } }
  }
  $since = (Get-Date).AddHours(-3)
  $zips = @()
  foreach ($pl in ($places | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $pl -PathType Container)) { continue }
    $zips += @(Get-ChildItem -LiteralPath $pl -Filter '*.zip' -File -Recurse -Depth 2 -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $since -and $_.Name -notlike '90161Z-T*' })
  }
  return $zips
}

<#
.SYNOPSIS
  Reads one zip entry as text.
.PARAMETER Entry
  A System.IO.Compression.ZipArchiveEntry.
.OUTPUTS
  System.String. The entry's text.
#>
function Read-ZipText($Entry) {
  $rd = New-Object System.IO.StreamReader($Entry.Open())
  try { return $rd.ReadToEnd() } finally { $rd.Dispose() }
}

<#
.SYNOPSIS
  Reads one flow of an open solution zip: the workflow JSON whose file name matches the JsonFileName of a
  <Workflow> node of customizations.xml.
.PARAMETER Zip
  The open zip (System.IO.Compression.ZipArchive).
.PARAMETER Node
  The <Workflow> node.
.PARAMETER Named
  $true when the flow was found by its name "... Probe Button ...".
.OUTPUTS
  System.Collections.Hashtable. Id (lower case), Json (the flow) and Named; $null when the JSON is not in the zip.
#>
function Read-ExportFlow($Zip, $Node, [bool]$Named) {
  $leaf = ([string]$Node.JsonFileName -split '/')[-1]
  $e = @($Zip.Entries | Where-Object { $_.FullName -match '^[Ww]orkflows/.+\.json$' -and $_.FullName -match $ExportGuidPattern -and ($_.FullName -split '/')[-1] -ieq $leaf })
  if (-not $e.Count) { return $null }
  $j = (Read-ZipText $e[0]) | ConvertFrom-Json
  $null = $e[0].FullName -match $ExportGuidPattern
  return @{ Id = $Matches[1].ToLowerInvariant(); Json = $j; Named = $Named }
}

<#
.SYNOPSIS
  Looks through the zips, newest first, for a solution export with a flow named "... Probe Button ...". R28 finding 3:
  the export of the hand-made flow did not show the name typed on the card, so the newest solution export with exactly 1
  flow is kept as the fallback; it is read only when no export names a "Probe Button" flow.
.PARAMETER Zips
  The zips from Find-ExportZip.
.OUTPUTS
  System.Collections.Hashtable. Found (from Read-ExportFlow, or $null) and FlowCount (flows read in all zips).
#>
function Find-ButtonFlow($Zips) {
  $found = $null; $flowCount = 0; $single = $null; $first = $true
  foreach ($z in @($Zips | Sort-Object LastWriteTime -Descending)) {
    $za = $null
    try {
      $za = [System.IO.Compression.ZipFile]::OpenRead($z.FullName)
      $wf = @($za.Entries | Where-Object { $_.FullName -match '^[Ww]orkflows/.+\.json$' -and $_.FullName -match $ExportGuidPattern })
      if (-not (@($za.Entries | Where-Object { $_.FullName -eq 'solution.xml' }).Count) -or -not $wf.Count) { continue }
      # A real solution export keeps the flow's name only in customizations.xml (<Workflow WorkflowId=... Name=...> with a JsonFileName).
      $ce = @($za.Entries | Where-Object { $_.FullName -eq 'customizations.xml' })
      if (-not $ce.Count) { continue }
      $xml = [xml](Read-ZipText $ce[0])
      $wnodes = @($xml.SelectNodes('//Workflow'))
      $flowCount += $wnodes.Count
      if ($first) { $first = $false; if ($wnodes.Count -eq 1) { $single = @{ Zip = $z.FullName; Node = $wnodes[0] } } }
      foreach ($w in $wnodes) {
        if ([string]$w.GetAttribute('Name') -notlike '*Probe Button*') { continue }
        $found = Read-ExportFlow $za $w $true
        if ($found) { break }
      }
    } catch { $null = $_ } finally { if ($za) { $za.Dispose() } }
    if ($found) { break }
  }
  if (-not $found -and $single) {
    $za = $null
    try {
      $za = [System.IO.Compression.ZipFile]::OpenRead($single.Zip)
      $found = Read-ExportFlow $za $single.Node $false
    } catch { $null = $_ } finally { if ($za) { $za.Dispose() } }
  }
  return @{ Found = $found; FlowCount = $flowCount }
}

<#
.SYNOPSIS
  Writes one TRIGGER line per trigger of the flow: type, kind, operationId and up to 12 parameter names, each kept only
  when it is a plain token (else <other>), never a value.
.PARAMETER Flow
  The flow JSON (from Read-ExportFlow).
.OUTPUTS
  System.Int32. The number of triggers read.
#>
function Write-TriggerLine($Flow) {
  # A name or a type as a plain token of up to 64 characters, 'none' when empty, '<other>' for anything else.
  $tok = { param($v) $t = [string]$v; if (-not $t) { 'none' } elseif ($t -match '^[A-Za-z0-9_.$/-]{1,64}$') { $t } else { '<other>' } }
  $trigs = @()
  try { $trigs = @($Flow.properties.definition.triggers.PSObject.Properties) } catch { $trigs = @() }
  $n = 0
  foreach ($t in $trigs) {
    $n++; $v = $t.Value
    $names = @(); try { $names = @($v.inputs.parameters.PSObject.Properties | ForEach-Object { & $tok $_.Name } | Select-Object -First 12) } catch { $names = @() }
    $op = ''; try { $op = [string]$v.inputs.host.operationId } catch { $op = '' }
    $names = $(if ($names.Count) { $names -join ',' } else { 'none' })
    $script:lines.Add('TRIGGER ' + $n + ' type=' + (& $tok $v.type) + '; kind=' + (& $tok $v.kind) + '; operationId=' + (& $tok $op) + '; parameter names=' + $names)
  }
  return $n
}

<#
.SYNOPSIS
  The part Export (no sign-in: it only reads a file on this computer): finds the button flow in the newest export, writes
  its trigger lines and saves its ID for the View part.
#>
function Invoke-ExportPart {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zips = @(Find-ExportZip)
  $hit = Find-ButtonFlow $zips
  $found = $hit.Found
  $named = $(if ($found -and $found.Named) { 'yes' } else { 'no' })
  $only = $(if ($found -and -not $found.Named) { 'yes' } else { 'no' })
  $text = 'solution export zips from the last 3 hours=' + $zips.Count + '; flows read=' + $hit.FlowCount + '; a flow named "Probe Button" found=' + $named
  Add-Item 'x1-export' $(if ($found) { 'PASS' } else { 'FAIL' }) ($text + '; the only flow of the newest export read=' + $only + '; name matched=' + $named)
  if (-not $found) { return }
  $n = Write-TriggerLine $found.Json
  Add-Item 'x2-trigger' $(if ($n -ge 1) { 'PASS' } else { 'FAIL' }) ('triggers read=' + $n)
  Set-Content -LiteralPath (Join-Path $script:dir $ButtonIdName) -Value $found.Id -Encoding ASCII
  Add-Item 'x3-flow-id' 'PASS' 'the flow ID is saved on this computer for the Look part (it is not in the result)'
}
