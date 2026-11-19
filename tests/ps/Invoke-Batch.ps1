# Test helper (agent workspace only): the small pwsh checks of tests/run.sh in ONE pwsh process; the owner approved P1 on 15 Nov 26.
# Each member runs in its own runspace (nothing shared); it writes <name>.out (all streams), <name>.rc (1 if it threw) and <name>.err.
param([Parameter(Mandatory = $true)][string]$OutDir)
$root = (Get-Location).Path
$members = [ordered]@{}
# Register one batch member. Takes its name, the script block to run and its arguments; stores them for the run loop below.
function Add-Member1([string]$Name, [scriptblock]$Code, [object[]]$Arguments = @()) { $members[$Name] = @{ Code = $Code.ToString(); Args = $Arguments } }

# Hide-Site masking is tested in tests/ps/Test-Mask.ps1 (every pattern, and one shared copy in each task script).

Add-Member1 'twospace' {
  . ./scripts/gov/Publication.Common.ps1
  ConvertTo-TwoSpaceSentence "Do this. (T-3) Then Mr. A. B. Smith signs. Use e.g. Forms. Done? Yes."
}
Add-Member1 'opening' {
  . ./scripts/gov/Publication.Common.ps1
  $p = Get-Content samples/publication.sample.json -Raw | ConvertFrom-Json
  Get-OpeningParagraph $p
}
# PFM 15 Nov 26 (enter the site once): Get-SiteAddress returns the address RADE holds, then the saved one, with no question.
Add-Member1 'siteaddr' {
  $src = Get-Content scripts/gov/src/site-common.ps1 -Raw
  Invoke-Expression ([regex]::Match($src, "(?s)function Get-SiteAddress.*?\n}\n").Value)
  # Stand-in for Read-Host: fails the test if the code under test asks a question.
  function Read-Host { throw "ASKED" }
  $d = Join-Path ([IO.Path]::GetTempPath()) ("sa" + [guid]::NewGuid().ToString("N")); $null = New-Item -ItemType Directory $d
  $env:RADE_SITE = "https://fakeco.example/sites/one"; $a = Get-SiteAddress $d
  $env:RADE_SITE = ""; Set-Content (Join-Path $d "90161Z-site.txt") "https://fakeco.example/sites/two"; $b = Get-SiteAddress $d
  Remove-Item (Join-Path $d "90161Z-site.txt")
  $c = try { Get-SiteAddress $d } catch { [string]$_.Exception.Message }
  $env:RADE_CONTRACT = "1"; $e = try { Get-SiteAddress $d } catch { ([string]$_.Exception.Message).Substring(0, 20) }
  $env:RADE_CONTRACT = ""; Remove-Item $d -Recurse -Force
  "$a|$b|$c|$e"
}
# R06 lesson: New-Object with a string for an enum argument can match two overloads and drop the RADE window to text mode.
Add-Member1 'font' {
  Add-Type -AssemblyName System.Drawing.Common
  try { $null = New-Object System.Drawing.Font("Segoe UI", 10, "Bold"); "bound" } catch { if ($_.Exception.Message -match "ambiguous") { "ambiguous" } else { "bound" } }
}
Add-Member1 'plan' {
  & ./scripts/gov/90161Z-T20-provision-lists-r2.ps1 -PlanOnly -PayloadPath flow/provisioning-payload.json
}

foreach ($name in $members.Keys) {
  $m = $members[$name]; $rc = 0
  $ps = [powershell]::Create()
  try {
    $null = $ps.AddScript("Set-Location -LiteralPath '$root'; & { $($m.Code) } @args *>&1 | ForEach-Object { [string]`$_ }")
    foreach ($a in $m.Args) { $null = $ps.AddArgument($a) }
    $lines = @($ps.Invoke())
  } catch {
    $lines = @(); $rc = 1
    Set-Content -LiteralPath (Join-Path $OutDir "$name.err") -Value ([string]$_)
  } finally { $ps.Dispose() }
  Set-Content -LiteralPath (Join-Path $OutDir "$name.out") -Value $lines
  Set-Content -LiteralPath (Join-Path $OutDir "$name.rc") -Value $rc
}
