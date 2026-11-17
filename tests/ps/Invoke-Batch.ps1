# Test helper (agent workspace only): the small pwsh checks of tests/run.sh in ONE pwsh process; the owner approved P1 on 15 Nov 26.
# Each member runs in its own runspace (nothing shared); it writes <name>.out (all streams), <name>.rc (1 if it threw) and <name>.err.
param([Parameter(Mandatory = $true)][string]$OutDir)
$root = (Get-Location).Path
$members = [ordered]@{}
function Add-Member1([string]$Name, [scriptblock]$Code, [object[]]$Arguments = @()) { $members[$Name] = @{ Code = $Code.ToString(); Args = $Arguments } }

# Hide-Site masking (T16 PnP retest: the e-mailed result must hold no site, tenant, sign-in address, GUID or .mil host).
$hideSite = {
  param($Path)
  $src = Get-Content $Path -Raw
  Invoke-Expression ([regex]::Match($src, "(?s)function Hide-Site.*?\n}\n").Value)
  $at = [string][char]64
  Hide-Site ("x jane.doe.1234567890" + $at + "fakeco.onmicrosoft.us said no; bob" + $at + "unit.example.m" + "il https://login.microsoftonline.us/0a1b2c3d-1111-2222-3333-444455556666/o fakeco.onmicrosoft.us https://fakeco.sharepoint.us/sites/pfmtest/_api fakeco-admin.sharepoint.us /sites/pfmtest/_api %2Fsites%2Fpfmtest pfmtest") "https://fakeco.sharepoint.us/sites/pfmtest"
}
# A list id right after URL-encoded characters (guid%27<id>%27) must be masked too.
$hideGuid = {
  param($Path)
  $src = Get-Content $Path -Raw
  Invoke-Expression ([regex]::Match($src, "(?s)function Hide-Site.*?\n}\n").Value)
  Hide-Site "lists(guid%270a1b2c3d-9999-2222-3333-444455556666%27)/items and %2F0a1b2c3d-9999-2222-3333-444455556666" "https://fakeco.sharepoint.us/sites/pfmtest"
}
$t16 = 'scripts/gov/90161Z-T16-pnp-signin-test-r4.ps1', 'scripts/gov/90161Z-T16-site-setup-r11.ps1', 'scripts/gov/90161Z-T18-slice1-test-r5.ps1', 'scripts/gov/90161Z-T19-list-update-r3.ps1', 'scripts/gov/90161Z-T20-provision-lists-r1.ps1'
for ($i = 0; $i -lt $t16.Count; $i++) { Add-Member1 "hs$i" $hideSite @($t16[$i]) }
Add-Member1 'hsg0' $hideGuid @('scripts/gov/90161Z-T18-slice1-test-r5.ps1')
Add-Member1 'hsg1' $hideGuid @('scripts/gov/90161Z-T20-provision-lists-r1.ps1')
# R15 review: site setup (r5 on) masks a URL-encoded address (%40) in a fetched result.
Add-Member1 'hsenc' {
  $src = Get-Content scripts/gov/90161Z-T16-site-setup-r11.ps1 -Raw
  Invoke-Expression ([regex]::Match($src, "(?s)function Hide-Site.*?\n}\n").Value)
  Hide-Site "getbyemail(@v)?@v=%27first.last.9999%40fakeco.example%27" ""
}

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
  & ./scripts/gov/90161Z-T20-provision-lists-r1.ps1 -PlanOnly -PayloadPath flow/provisioning-payload.json
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
