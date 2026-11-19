# Tests part 0 of scripts/gov/90161Z-T24-full-solution-test-r6.ps1 (R36, PFM 19 Nov 26: the list GUIDs go into the solution zip before
# the import) against the strict fake site of tests/fake-pnp (pwsh 7, also Windows PowerShell 5.1 through tests/ps/Invoke-Ps51.ps1).
# It uses the committed solution flow/solution/90161Z-T24-full-flows-r5.zip and proves: every placeholder is replaced by the GUID of
# its list, entries without one are copied byte for byte, a missing list or a left placeholder stops with a clear line and leaves no
# ready zip, and the zip the round saved is not changed. The real service is proved only by a gov device round.
# Last line: "T24 pass=N fail=0".
# Network: none (the site is a fake in memory; the fake address host is example.test).
# Writes: a temporary folder under the system temp folder, removed at the end.
# Credentials: none (a fake DODID only).
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T24TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T24TEST FAIL ' + $Name + ' ' + $Detail) }
}
$env:PSModulePath = (Join-Path $Root 'tests/fake-pnp') + [IO.Path]::PathSeparator + $env:PSModulePath
Import-Module PnP.PowerShell -RequiredVersion 1.12.0 -DisableNameChecking
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$work = Join-Path ([IO.Path]::GetTempPath()) ('t24-' + [guid]::NewGuid().ToString('N'))
$t24 = Join-Path $work 'T24'
$null = New-Item -ItemType Directory -Path $t24 -Force
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T24-full-solution-test-r6.ps1'
$source = Join-Path $Root 'flow/solution/90161Z-T24-full-flows-r5.zip'
$zipIn = Join-Path $t24 '90161Z-T24-full-flows-r5.zip'
$zipOut = Join-Path $t24 '90161Z-T24-full-flows-r5-ready.zip'
$titles = @('PFM Publications', 'PFM Activity Log', 'PFM Reviews', 'PFM Endorsements', 'PFM Product Index', 'PFM Process Steps', 'PFM Offices', 'PFM Settings', 'PFM Waivers')   # R36: PFM Waivers for F08

# Run part 0 against the fake site. Takes nothing; returns a hashtable with Out (lines) and Text (joined).
function Invoke-T24 {
  $out = & $script -Id 'tester01' -Part 0 -NoPause -TestDir $t24 *>&1 | ForEach-Object { [string]$_ }
  return @{ Out = @($out); Text = (@($out) -join "`n") }
}
<#
.SYNOPSIS
  Reads every entry of a zip.
.PARAMETER Path
  The zip file.
.OUTPUTS
  System.Collections.Hashtable. Names (entry names in zip order) and Bytes (name -> byte[]).
#>
function Read-Zip([string]$Path) {
  $r = @{ Names = (New-Object System.Collections.Generic.List[string]); Bytes = @{} }
  $z = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    foreach ($e in $z.Entries) {
      $ms = New-Object System.IO.MemoryStream; $s = $e.Open(); try { $s.CopyTo($ms) } finally { $s.Dispose() }
      $r.Names.Add($e.FullName); $r.Bytes[$e.FullName] = $ms.ToArray()
    }
  } finally { $z.Dispose() }
  return $r
}
# Make the fake site with the 9 PFM lists (all but the titles in $Skip). Takes the titles to leave out; returns title -> GUID text.
function New-PfmSite([string[]]$Skip = @()) {
  New-FakeSite
  $ids = @{}
  foreach ($t in $titles) { if ($Skip -notcontains $t) { $ids[$t] = (Add-FakeList $t 100 ($t -replace ' ', '')).Id } }
  return $ids
}
$utf8 = New-Object System.Text.UTF8Encoding($false)

# 1. The normal case: 9 lists, the committed r5 zip.
Copy-Item -LiteralPath $source -Destination $zipIn
$before = [IO.File]::ReadAllBytes($zipIn)
$ids = New-PfmSite
$r = Invoke-T24
Test-That 'part 0 passes' ($r.Text -match 'ITEM p0-list-guids PASS lists read by title=9 ' -and $r.Text -match 'list variables with a GUID default=9 of 9') $r.Text
Test-That 'the ready zip is written' (Test-Path -LiteralPath $zipOut)
Test-That 'the saved zip is not changed' ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($zipIn)))
Test-That 'GUIDs are masked in the output' (-not ($r.Text -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')) $r.Text
if (Test-Path -LiteralPath $zipOut) {
  $a = Read-Zip $zipIn; $b = Read-Zip $zipOut
  Test-That 'same entries in the same order' (($a.Names -join '|') -eq ($b.Names -join '|'))
  $left = @($b.Names | Where-Object { $utf8.GetString($b.Bytes[$_]).Contains('90161Z-LIST-GUID') })
  Test-That 'no placeholder left' ($left.Count -eq 0) ($left -join ', ')
  $same = @($a.Names | Where-Object { -not $utf8.GetString($a.Bytes[$_]).Contains('90161Z-LIST-GUID') } | Where-Object {
      [Convert]::ToBase64String($a.Bytes[$_]) -ne [Convert]::ToBase64String($b.Bytes[$_]) })
  Test-That 'entries without a placeholder are copied byte for byte' ($same.Count -eq 0) ($same -join ', ')
  $varOk = 0
  foreach ($n in $b.Names) {
    if ($n -match '^environmentvariabledefinitions/(pfm_List\w+)/') {
      $x = $utf8.GetString($b.Bytes[$n]); $was = $utf8.GetString($a.Bytes[$n])
      if ($was -match '<defaultvalue>90161Z-LIST-GUID\[([^\]]+)\]</defaultvalue>' -and $x.Contains('<defaultvalue>' + $ids[$Matches[1]] + '</defaultvalue>')) { $varOk++ }
    }
  }
  Test-That 'each list variable holds the GUID of its own list' ($varOk -eq 9) ('ok=' + $varOk)
  $flowOk = @($b.Names | Where-Object { $_ -like 'Workflows/*' } | Where-Object {
      $j = $utf8.GetString($b.Bytes[$_]) | ConvertFrom-Json
      $p = $j.properties.definition.parameters
      $bad = @($p.PSObject.Properties | Where-Object { $_.Value.metadata.schemaName -like 'pfm_List*' } | Where-Object { $ids.Values -notcontains $_.Value.defaultValue })
      $bad.Count -eq 0 }).Count
  $flows = @($b.Names | Where-Object { $_ -like 'Workflows/*' }).Count
  Test-That 'each flow parameter default holds a list GUID' ($flows -eq 10 -and $flowOk -eq $flows) ('flows=' + $flows + ' ok=' + $flowOk)
}
$res = Join-Path $t24 '90161Z-T24-full-test-part0-r1.txt'
Test-That 'result file written' (Test-Path -LiteralPath $res)

# 2. A missing list: a clear stop, no ready zip.
$null = New-PfmSite -Skip 'PFM Reviews'
$r = Invoke-T24
Test-That 'missing list stops with its title' ($r.Text -match 'STOPPED: LIST MISSING: no list titled "PFM Reviews"') $r.Text
Test-That 'missing list: no ready zip' (-not (Test-Path -LiteralPath $zipOut))

# 3. A placeholder the script cannot read (no closing bracket): it is left, so the ready zip is removed.
$null = New-PfmSite
$fs = [IO.File]::Open($zipIn, [IO.FileMode]::Open)
try {
  $z = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Update)
  try { $e = $z.CreateEntry('extra/broken.txt'); $w = New-Object IO.StreamWriter($e.Open()); try { $w.Write('90161Z-LIST-GUID[PFM Reviews') } finally { $w.Dispose() } } finally { $z.Dispose() }
} finally { $fs.Dispose() }
$r = Invoke-T24
Test-That 'a left placeholder stops the part' ($r.Text -match 'STOPPED: PLACEHOLDER LEFT in extra/broken.txt') $r.Text
Test-That 'left placeholder: no ready zip' (-not (Test-Path -LiteralPath $zipOut))

# 4. A zip with no placeholder (for example the ready zip saved under the round's name): a clear stop.
Copy-Item -LiteralPath $source -Destination $zipIn -Force
$null = New-PfmSite
$null = Invoke-T24
Copy-Item -LiteralPath $zipOut -Destination $zipIn -Force
$r = Invoke-T24
Test-That 'no placeholder stops the part' ($r.Text -match 'STOPPED: NO PLACEHOLDER in 90161Z-T24-full-flows-r5.zip') $r.Text
Test-That 'no placeholder: the older ready zip is removed' (-not (Test-Path -LiteralPath $zipOut))

# 5. No solution zip in the folder.
Remove-Item -LiteralPath $zipIn -Force
$r = Invoke-T24
Test-That 'no zip stops the part' ($r.Text -match 'STOPPED: SOLUTION ZIP not in the T24 folder: 90161Z-T24-full-flows-r5.zip') $r.Text

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T24 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail -gt 0) { exit 1 }
