# Tests scripts/gov/90161Z-T28-count-r1.ps1 (round R44 T2; the PFM, 25 Nov 26: "a read-only list step first") against a small fake site.
# The PnP cmdlets are fakes in this file (an empty PnP.PowerShell 1.12.0 module in a temporary folder lets the script's module check pass).
# What it proves, on the fake site:
#  - the step counts the 12 PFM lists (on the site, items, rows marked "(delete me)"), the group PFM Office (members), the library 90-161.Z,
#    the T21 probe list and the T21 probe library, by their fixed titles, and prints one NOTE line "flows: not counted from the site";
#  - it writes nothing on the site: no Add, Set, Remove or New call of any kind, and no REST call but a GET; one sign-in, to the site given;
#  - it prints no member name and no row title (the fake members and the marked rows hold a text that must never show);
#  - a list that a person made with a similar title is not counted; a site with nothing of the app counts zero and still passes;
#  - a failed read stops the step with STOPPED and exit 1; the fixed titles equal the own-name table, the T21 script and the payload.
# Proves the logic, not the real service: the gov device round is that proof.
# Network: none.
# Writes: one temporary folder (the T28 folder of the test, the fake module); removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Last line: "T28 pass=N fail=0".
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T28TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T28TEST FAIL ' + $Name + ' ' + $Detail) }
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('t28-' + [guid]::NewGuid().ToString('N'))
$t28 = Join-Path $work 'T28'
$null = New-Item -ItemType Directory -Path $t28 -Force
$modDir = Join-Path $work 'mods/PnP.PowerShell/1.12.0'; $null = New-Item -ItemType Directory -Path $modDir -Force
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psm1') -Value '# empty on purpose: the cmdlets are fakes in tests/ps/Test-T28.ps1'
$psd = "@{ RootModule = 'PnP.PowerShell.psm1'; ModuleVersion = '1.12.0'; GUID = '0b0430ce-d799-4f3b-a565-f0dca1f31e18' }"
Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psd1') -Value $psd
$env:PSModulePath = (Join-Path $work 'mods') + [IO.Path]::PathSeparator + $env:PSModulePath
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
$script = Join-Path $Root 'scripts/gov/90161Z-T28-count-r1.ps1'
$payload = Get-Content -LiteralPath (Join-Path $Root 'flow/provisioning-payload.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$SecretText = 'SECRET-FAKE-TEXT'   # in every fake member and every marked row: it must never reach a line

$global:S = @{}
<#
.SYNOPSIS
  Reset the fake site: the 12 lists of 90-161.Z with rows, the group, the library, the probe list and library, and a list of a person.
.OUTPUTS
  None. It sets the global fake site $global:S.
#>
function New-Site {
  $global:S = @{ Lists = (New-Object System.Collections.ArrayList); Calls = (New-Object System.Collections.ArrayList)
    Urls = (New-Object System.Collections.ArrayList); Connects = @(); Rows = @{}; Groups = @{ 'PFM Office' = 2; 'Site Owners' = 1 }; FailRows = '' }
  $n = 0
  foreach ($u in $payload.updates) {
    if ([string]$u.uri -notmatch "getbytitle\('([^']+)'\)$") { continue }
    $n++; $t = [string]$u.body.Title; Add-FakeList $Matches[1] $t 100 ($n + 1)
    $marked = $(if ($n -eq 1) { 2 } elseif ($n -eq 2) { 1 } else { 0 })   # 2 marked rows in the first list, 1 in the second
    $rows = New-Object System.Collections.ArrayList
    foreach ($i in 1..($n + 1)) {
      $title = $SecretText + ' row ' + $i + $(if ($i -le $marked) { ' (delete me)' } else { '' })
      $null = $rows.Add(@{ Id = $i; Title = $title })
    }
    $global:S.Rows[$t] = $rows
  }
  Add-FakeList '90-161.Z' '90-161.Z' 101 7; Add-FakeList 'Lists/Probe' '90161Z Probe' 100 3; Add-FakeList '90161Z Probe Files' '90161Z Probe Files' 101 1
  Add-FakeList 'Lists/Person' 'Budget Notes' 100 9
}
# Adds a fake list: folder name, title, BaseTemplate and item count; returns nothing.
function Add-FakeList([string]$Folder, [string]$Title, [int]$Template, [int]$Items) {
  $id = [guid]::NewGuid().ToString()
  $null = $global:S.Lists.Add(@{ Id = $id; Title = $Title; Folder = $Folder; Template = $Template; Items = $Items })
}
# Fake Connect-PnPOnline: accepts only -UseWebLogin, as on the gov device; records the address.
function Connect-PnPOnline { [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin) if (-not $UseWebLogin) { throw 'FAKE: -UseWebLogin only' }; $global:S.Connects += $Url }
# Fake Disconnect-PnPOnline: does nothing.
function Disconnect-PnPOnline { [CmdletBinding()] param() }
<#
.SYNOPSIS
  Fake Invoke-PnPSPRestMethod: a GET of the lists, the groups or the members of a group, as the REST service answers. Any other
  method is a write: it is recorded and refused.
.DESCRIPTION
  A member answers with its number only when the address asks for the number alone ($select=Id); else the answer also holds a
  title with the secret text, so a script that reads names shows them.
.PARAMETER Method
  The HTTP method; only Get is known.
.PARAMETER Url
  The request address; its path picks the answer.
.PARAMETER Content
  Not used (a read sends no body).
.PARAMETER ContentType
  Not used.
.PARAMETER Raw
  Not used (the answer is always the JSON text).
.OUTPUTS
  System.String. The JSON text of the answer, as { "value": [ ... ] }.
#>
function Invoke-PnPSPRestMethod {
  [CmdletBinding()] param([string]$Method, [string]$Url, [string]$Content, [string]$ContentType, [switch]$Raw)
  $null = $global:S.Urls.Add($Method + ' ' + $Url)
  if ($Method -ne 'Get') { $null = $global:S.Calls.Add('rest:' + $Method); throw 'FAKE: GET only' }
  if ($Url -match '/_api/web/lists\?') {
    $v = @($global:S.Lists | ForEach-Object { @{ Id = $_.Id; Title = $_.Title; ItemCount = $_.Items; EnableVersioning = $true; BaseTemplate = $_.Template
          Hidden = $false; HasUniqueRoleAssignments = $false; RootFolder = @{ Name = $_.Folder } } })
    return (@{ value = $v } | ConvertTo-Json -Depth 6 -Compress)
  }
  $names = @($global:S.Groups.Keys | Sort-Object)
  if ($Url -match '/_api/web/sitegroups/getbyid\((\d+)\)/users') {
    $count = [int]$global:S.Groups[$names[[int]$Matches[1] - 900]]
    $idOnly = $Url -match '\$select=Id(&|$)'
    $v = @(1..$count | ForEach-Object { if ($idOnly) { @{ Id = $_ } } else { @{ Id = $_; Title = $SecretText + ' member ' + $_; Email = 'secret@example.test' } } })
    return (@{ value = $v } | ConvertTo-Json -Depth 4 -Compress)
  }
  if ($Url -match '/_api/web/sitegroups') {
    $v = @($names | ForEach-Object { @{ Id = (900 + [array]::IndexOf($names, $_)); Title = $_ } })
    return (@{ value = $v } | ConvertTo-Json -Depth 4 -Compress)
  }
  throw ('FAKE: GET not known ' + $Url)
}
# A fake list item: like a real one it has an indexer by column name, and it throws for a column that was not named in -Fields.
Add-Type -TypeDefinition @'
public class FakeItem {
  private System.Collections.Generic.Dictionary<string, object> d = new System.Collections.Generic.Dictionary<string, object>();
  public int Id;
  public object this[string k] {
    get { if (!d.ContainsKey(k)) { throw new System.InvalidOperationException("FAKE: the column " + k + " was not loaded (-Fields)"); } return d[k]; }
    set { d[k] = value; }
  }
}
'@
# Fake Get-PnPListItem: the rows of a fake list (Id and Title); throws for a list that has no rows, or when a test sets FailRows.
function Get-PnPListItem {
  [CmdletBinding()] param([string]$List, [string[]]$Fields, [int]$PageSize)
  if ($global:S.FailRows -and $List -eq $global:S.FailRows) { throw 'FAKE 500: the read failed' }
  if (-not $global:S.Rows.ContainsKey($List)) { throw ('FAKE: no rows for ' + $List) }
  return @($global:S.Rows[$List] | ForEach-Object { $row = $_; $it = New-Object FakeItem; $it.Id = [int]$row.Id
      foreach ($k in $Fields) { $it[$k] = $row[$k] }
      $it })
}
# The write cmdlets a read-only step must never call: each one records the call and refuses it.
$writers = @('Add-PnPListItem', 'Set-PnPListItem', 'Remove-PnPListItem', 'Remove-PnPList', 'New-PnPList', 'Add-PnPGroupMember', 'Remove-PnPGroup',
  'New-PnPGroup', 'Add-PnPField', 'Set-PnPList', 'Remove-PnPGroupMember', 'Set-PnPGroup', 'Add-PnPFile', 'Remove-PnPFile', 'Invoke-PnPQuery')
foreach ($w in $writers) {
  $body = "param() `$null = `$global:S.Calls.Add('" + $w + "'); throw 'FAKE: a read-only step wrote'"
  Set-Item -Path ('Function:global:' + $w) -Value ([scriptblock]::Create($body))
}
# Runs the step against the fake site. Returns @{ Code; Text (the screen output); File (the result file text) }.
function Invoke-T28 {
  $global:LASTEXITCODE = 0; $global:S.Calls.Clear(); $global:S.Urls.Clear(); $global:S.Connects = @()
  $file = Join-Path $t28 '90161Z-T28-count-r1.txt'; if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
  $out = & $script -Id 'tester01' -NoPause -TestDir $t28 *>&1 | ForEach-Object { [string]$_ }
  $text = $(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' })
  return @{ Code = $LASTEXITCODE; Text = (@($out) -join "`n"); File = $text }
}
try {
  New-Site
  . (Join-Path $Root 'scripts/gov/90161Z-T27-made-r1.ps1')   # the own-name table, the one home of the 12 titles
  # ---- one home: the fixed titles ----
  $disp = @($payload.updates | Where-Object { [string]$_.uri -match "getbytitle\('[^']+'\)$" } | ForEach-Object { [string]$_.body.Title })
  $same = ((@($OwnLists.Values | Sort-Object) -join '|') -ceq (@($disp | Sort-Object) -join '|') -and $disp.Count -eq 12)
  Test-That 'the own-name table (the 12 titles that the step counts) equals the titles of the payload' $same ($disp -join ',')
  $probe = Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/90161Z-T21-probe-r12.ps1') -Raw
  $src = Get-Content -LiteralPath $script -Raw
  $l1 = [regex]::Match($probe, "(?m)^\`$script:ListTitle = '([^']+)'").Groups[1].Value
  $l2 = [regex]::Match($probe, "(?m)^\`$script:LibTitle = '([^']+)'").Groups[1].Value
  $c1 = [regex]::Match($src, "(?m)^\`$ProbeList = '([^']+)'").Groups[1].Value
  $c2 = [regex]::Match($src, "(?m)^\`$ProbeLibrary = '([^']+)'").Groups[1].Value
  Test-That 'the probe list and library titles equal the ones of the T21 script' ($l1 -and $l2 -and $l1 -ceq $c1 -and $l2 -ceq $c2) ($l1 + ' / ' + $c1 + ' ; ' + $l2 + ' / ' + $c2)
  $writes = [regex]::IsMatch($src, '\b(Add|Set|Remove|New|Move|Copy|Clear|Restore|Update)-PnP\w+')
  Test-That 'the step calls no PnP cmdlet that adds, sets, removes or creates (text check)' (-not $writes) ''

  # ---- a full count ----
  $r = Invoke-T28
  $f = $r.File
  $done = ($r.Code -eq 0 -and $f -match '(?m)^RESULT COUNT PASS lists=12 of 12 items=\d+ marked=3\r?$' -and $f -match '(?m)^COUNT done: counted=\d+ failed=0\r?$')
  Test-That 'the step passes (exit 0, RESULT COUNT PASS, the last line)' $done $f
  $itemsWant = (2..13 | Measure-Object -Sum).Sum   # the fake lists hold 2, 3, ... 13 items
  $total = '(?m)^COUNT lists of 90-161\.Z: on the site=12 of 12; items in them=' + $itemsWant + '; rows marked \(delete me\)=3\r?$'
  Test-That 'it counts the 12 lists, their items and the 3 marked rows' ($f -match $total) $f
  $each = '(?m)^COUNT list PFM .*on the site=yes; with this title=1; items=\d+; rows marked \(delete me\)=\d+'
  $first = [regex]::Match($f, '(?m)^COUNT list PFM Reviews: .*$').Value
  Test-That 'each list has its own COUNT line with its items and its marked rows' (([regex]::Matches($f, $each)).Count -eq 12 -and $first) $first
  Test-That 'it counts the group PFM Office with its 2 members' ($f -match '(?m)^COUNT group PFM Office: on the site=yes; members=2\r?$') $f
  $lib = '(?m)^COUNT library 90-161\.Z: on the site=yes; with this title=1; items=7\r?$'
  $pl = '(?m)^COUNT probe list 90161Z Probe: on the site=yes; with this title=1; items=3\r?$'
  $pb = '(?m)^COUNT probe library 90161Z Probe Files: on the site=yes; with this title=1; items=1\r?$'
  Test-That 'it counts the library 90-161.Z, the probe list and the probe library' ($f -match $lib -and $f -match $pl -and $f -match $pb) $f
  $notes = @($f -split "`n" | Where-Object { $_ -match '^NOTE ' })
  Test-That 'it prints one NOTE line: flows: not counted from the site' ($notes.Count -eq 1 -and $f -match '(?m)^NOTE flows: not counted from the site\r?$') $f
  Test-That 'it does not count the list of a person' ($f -notmatch 'Budget Notes') $f

  # ---- nothing is written, one sign-in, no name and no row text ----
  $notGet = @($global:S.Urls | Where-Object { $_ -notmatch '^Get ' })
  Test-That 'no write call: no Add, Set, Remove or New cmdlet and no REST call but a GET' ($global:S.Calls.Count -eq 0 -and $notGet.Count -eq 0) (@($global:S.Calls) -join ',')
  Test-That 'one sign-in, to the site that was given (the web login)' ($global:S.Connects.Count -eq 1 -and $global:S.Connects[0] -ceq $env:RADE_SITE) (@($global:S.Connects) -join ',')
  $users = @($global:S.Urls | Where-Object { $_ -match 'users' })
  $wide = @($users | Where-Object { $_ -notmatch '\$select=Id(&|$)' })
  Test-That 'the members are read as numbers only ($select=Id)' ($wide.Count -eq 0 -and $users.Count -eq 1) (@($global:S.Urls) -join "`n")
  $all = $r.Text + "`n" + $f
  Test-That 'no member name and no row text in the output or the result file' ($all -notmatch [regex]::Escape($SecretText) -and $all -notmatch 'secret@example') $all
  Test-That 'no site host in the output or the result file' ($all -notmatch 'fakehost') $all
  $other = @($global:S.Urls | Where-Object { $_ -match 'https?://' -and $_ -notmatch 'fakehost\.example\.test/sites/FakeWing/' })
  Test-That 'no host but the one site: every address read is a path of that site (no other URL)' ($other.Count -eq 0) (@($global:S.Urls) -join "`n")

  # ---- other sites ----
  New-Site; $global:S.Lists.Clear(); $global:S.Rows = @{}; $global:S.Groups = @{ 'Site Owners' = 1 }; Add-FakeList 'Lists/Person' 'Budget Notes' 100 9
  $r = Invoke-T28; $f = $r.File
  $zero = ($r.Code -eq 0 -and $f -match '(?m)^RESULT COUNT PASS lists=0 of 12 items=0 marked=0\r?$' -and $f -match '(?m)^COUNT group PFM Office: on the site=no\r?$' -and
    $f -match '(?m)^COUNT library 90-161\.Z: on the site=no\r?$' -and $f -match '(?m)^COUNT probe list 90161Z Probe: on the site=no\r?$')
  Test-That 'a site with nothing of the app counts zero and still passes' $zero $f
  New-Site; Add-FakeList 'Lists/ByHand' 'PFM Series (copy)' 100 5; Add-FakeList 'Lists/ByHand2' 'pfm series' 100 5; Add-FakeList 'Lists/Doclib' '90161Z Probe' 101 4
  $r = Invoke-T28; $f = $r.File
  $similar = ($r.Code -eq 0 -and $f -match '(?m)^COUNT lists of 90-161\.Z: on the site=12 of 12;' -and
    $f -match '(?m)^COUNT probe list 90161Z Probe: on the site=yes; with this title=1; items=3\r?$')
  Test-That 'a similar title (suffix, case) is not counted; a library with the probe list title is not the probe list' $similar $f
  New-Site; $global:S.FailRows = 'PFM Reviews'
  $r = Invoke-T28; $f = $r.File
  Test-That 'a failed read stops the step: STOPPED, no RESULT PASS, exit 1' ($r.Code -eq 1 -and $f -match '(?m)^STOPPED: ' -and $f -notmatch 'RESULT COUNT PASS' -and $f -match 'failed=1') $f
  $bytes = [IO.File]::ReadAllBytes($script)
  Test-That 'the script file is ASCII' (-not @($bytes | Where-Object { $_ -gt 127 }).Count) ''
} finally {
  Set-Location -LiteralPath $Root
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('T28 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
