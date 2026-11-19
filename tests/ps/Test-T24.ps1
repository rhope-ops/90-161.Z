# Tests part 0 of scripts/gov/90161Z-T24-full-solution-test-r6.ps1 (R36, PFM 19 Nov 26: the list GUIDs go into the solution zip before
# the import) against the strict fake site of tests/fake-pnp (pwsh 7, also Windows PowerShell 5.1 through tests/ps/Invoke-Ps51.ps1).
# It uses the committed solution flow/solution/90161Z-T24-full-flows-r5.zip and proves: every placeholder is replaced by the GUID of
# its list, entries without one are copied byte for byte, a missing list or a left placeholder stops with a clear line and leaves no
# ready zip, and the zip the round saved is not changed. R36 also: part 1 waits one full F01 check before each F01 count (W11, with a fake
# clock) and holds the F08 test of the 4.4A design (W5). The real service is proved only by a gov device round.
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
$titles = @('PFM Publications', 'PFM Activity Log', 'PFM Reviews', 'PFM Endorsements', 'PFM Product Index', 'PFM Process Steps', 'PFM Offices', 'PFM Settings',
  'PFM Waivers')   # R36: PFM Waivers for F08

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

# 6. W11 (R35 finding 1): part 1 counts F01 rows only after one full F01 check (16 minutes after the rows were made or changed) and says how
# long it waits. Wait-FullCheck is taken from the script by its syntax tree and run with a fake clock (Get-Date and Start-Sleep below).
# The main file and its module checks (R36: the F08 check and parts 2 to 4 moved there to keep the main file under the cap).
$text = (Get-Content -LiteralPath $script -Raw) + (Get-Content -LiteralPath (Join-Path (Split-Path -Parent $script) '90161Z-T24-checks-r6.ps1') -Raw)
$ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null)
$fn = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Wait-FullCheck' }, $true))
Test-That 'Wait-FullCheck is defined once' ($fn.Count -eq 1)
$full = $(if ($text -match '(?m)^\$F01FullCheck = (\d+)\b') { [int]$Matches[1] } else { -1 })
Test-That 'the full F01 check is 16 minutes (every 15 minutes, plus 1)' ($full -eq 16) ([string]$full)
<#
.SYNOPSIS
  Runs Wait-FullCheck with a fake clock: Get-Date gives the fake time, Start-Sleep moves it on, Write-Host keeps the lines.
.PARAMETER Ago
  Minutes since the rows were made.
.OUTPUTS
  System.Collections.Hashtable. Back (the return value), Slept (fake seconds slept) and Shown (the screen lines).
#>
function Invoke-FullCheck([double]$Ago) {
  $clock = @{ Now = [datetime]'2026-11-19T14:00:00'; Slept = 0 }
  $shown = New-Object System.Collections.Generic.List[string]
  $back = & {
    # The fake clock: Get-Date gives the fake time.
    function Get-Date { return $clock.Now }
    # Start-Sleep moves the fake time on by $Seconds and counts them, with no real wait.
    function Start-Sleep([int]$Seconds) { $clock.Now = $clock.Now.AddSeconds($Seconds); $clock.Slept += $Seconds }
    # Write-Host keeps the line in $shown instead of printing it.
    function Write-Host([string]$Object) { $shown.Add($Object) }
    $F01FullCheck = $full
    . ([scriptblock]::Create($fn[0].Extent.Text))
    Wait-FullCheck $clock.Now.AddMinutes(-$Ago) 'the F01 log rows'
  }
  return @{ Back = $back; Slept = $clock.Slept; Shown = @($shown) }
}
$w = Invoke-FullCheck 5
Test-That 'rows made 5 minutes ago: waits 11 minutes and says so' ($w.Back -eq 11 -and $w.Slept -eq 660 -and
  $w.Shown[0] -eq 'NOW Waiting 11 minutes, until 14:11, so that F01 (it checks every 15 minutes) has made one full check before counting the F01 log rows. Leave this window open.' -and
  $w.Shown -contains '  1 of 11 minutes left before counting the F01 log rows ...') ($w.Shown -join "`n")
$w = Invoke-FullCheck 0
Test-That 'rows made just now: waits the full 16 minutes' ($w.Back -eq 16 -and $w.Slept -eq 960) ('back=' + $w.Back + ' slept=' + $w.Slept)
$w = Invoke-FullCheck 20
Test-That 'a full check passed already: no wait, says so' ($w.Back -eq 0 -and $w.Slept -eq 0 -and $w.Shown[0] -like 'NOW One full F01 check has passed already*') ($w.Shown -join "`n")
# Part 1 calls it before each F01 count, and counts the 8 flows F01 to F08 (W5: F08).
$p1 = $text.IndexOf("Wait-FullCheck `$made"); $c1 = $text.IndexOf("Count -lt 1 }).Count -eq 0 } 'the F01 log rows'")
$p2 = $text.IndexOf("Wait-FullCheck `$changed"); $c2 = $text.IndexOf("Count -lt 2 }).Count -eq 0 } 'the F01 log rows'")
Test-That 'part 1 waits one full F01 check before each F01 count' ($p1 -gt 0 -and $p1 -lt $c1 -and $p2 -gt $c1 -and $p2 -lt $c2) ("$p1 $c1 $p2 $c2")
Test-That 'part 1 counts the 8 flows F01 to F08' ($text.Contains('$mine.Count -eq 8 -and $on -eq 8'))

# 7. W5 (F08, rule 4.4A): the part 1 test rows are the design's (an office row with you as Leader; T-1 and T-3 with you as approver, T-2 with none),
# its result lines are the 3 checks, and part 4 removes the waivers and the office row.
Test-That 'F08 test rows as in the design' ($text -match "w1 = @\(\(\`$Prefix \+ 'F08 waiver T-1 \(delete me\)'\), 'T-1', \`$true\)" -and
  $text -match "w3 = @\(\(\`$Prefix \+ 'F08 waiver T-3 \(delete me\)'\), 'T-3', \`$true\)" -and
  $text -match "w2 = @\(\(\`$Prefix \+ 'F08 waiver T-2 no approver \(delete me\)'\), 'T-2', \`$false\)" -and
  $text.Contains("Leader = `$meId; IsActive = `$false"))
Test-That 'F08 checks: 1 warning for T-1, none for T-3, none without an approver' ($text.Contains("Add-Line 'f08-warns-t1'") -and $text.Contains("Add-Line 'f08-none-t3'") -and
  $text.Contains("Add-Line 'f08-none-no-approver'") -and $text.Contains("`$warn['w1'].Count -eq 1 -and [string]`$warn['w1'][0]['EventType'] -eq 'Waiver Warning'"))
Test-That 'part 4 removes the waivers, their warning rows and the office row' ($text.Contains("foreach (`$k in `$Waivers.Keys) { if (`$state.ContainsKey(`$k)) { try { `$n += Clear-TestWaiver") -and
  $text.Contains("Remove-PnPListItem -List 'PFM Offices' -Identity ([int]`$state['office'])"))

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('T24 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail -gt 0) { exit 1 }
