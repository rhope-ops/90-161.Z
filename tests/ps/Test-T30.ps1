# Tests scripts/gov/90161Z-T30-batch-r1.ps1 (round R47; the PFM, 26 Nov 26: fewer CAC sign-ins) and the sign-in reuse of the connect
# functions of T21 (Connect-ProbeSite) and T26 (Connect-EndorseSite). The T27 parts run through the batch in tests/ps/Test-T27.ps1
# (Lists, Access, Local in Uninstall mode: 1 sign-in, 1 sign-out).
# Cases: the batch runs stub parts in order, in the task folders beside its own T30 folder, with -Id, -NoPause, -Part and -Label;
# KANON_KEEP_SIGNIN is 1 while the parts run and gone after; a part that exits 1 or throws does not stop the next part, and the
# batch exits 1; a part, task or label that is not in the table, or a missing script, stops the batch before any part runs; the
# batch signs out once; the batch's own lines hold no PASS, FAIL or SKIP word. The real connect functions of T21 and T26 sign in
# once, then a second call on the same site reuses the connection ("SIGNIN reused"), and a connection to another site does not
# count; they have no DPI call. Every disconnect of T21, T26 and T27 waits for the batch's signal. Each script of the batch table
# is in scripts/gov and in the files of the R47 bundle. The T21 second person prompt fits its box (120 characters at most).
# Network: none.
# Writes: one temporary folder (the stub app folder and an empty PnP.PowerShell module); removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Last line: "T30 pass=N fail=0".
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('T30TEST PASS ' + $Name) } else { $script:fail++; Write-Host ('T30TEST FAIL ' + $Name + ' ' + $Detail) }
}
$gov = Join-Path $Root 'scripts/gov'
$batchSrc = Join-Path $gov '90161Z-T30-batch-r1.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('t30-' + [guid]::NewGuid().ToString('N'))
$env:RADE_SITE = 'https://fakehost.example.test/sites/FakeWing'
$env:RADE_CONTRACT = '1'
# The fake connection of this process (Connect-PnPOnline, Get-PnPConnection, Disconnect-PnPOnline), as PnP.PowerShell 1.12.0 keeps one.
$global:SignedInTo = ''; $global:Connects = 0; $global:SignOuts = 0
# Fake Connect-PnPOnline: only -UseWebLogin; counts the sign-ins and keeps the address.
function Connect-PnPOnline { [CmdletBinding()] param([string]$Url, [switch]$UseWebLogin) if (-not $UseWebLogin) { throw 'FAKE: -UseWebLogin only' }; $global:Connects++; $global:SignedInTo = $Url }
# Fake Get-PnPConnection: the connection, or an error when there is none.
function Get-PnPConnection { [CmdletBinding()] param() if (-not $global:SignedInTo) { throw 'FAKE: no connection' }; return [pscustomobject]@{ Url = $global:SignedInTo } }
# Fake Disconnect-PnPOnline: ends the connection and counts the sign-outs.
function Disconnect-PnPOnline { [CmdletBinding()] param() $global:SignedInTo = ''; $global:SignOuts++ }

# The text of a stub part script: it logs its arguments and the keep signal to calls.txt in the app folder, prints one line, and
# exits with the code that the file exit-<Part>.txt in the app folder holds (0 when there is none); the part Rows throws.
$stub = @'
param([string]$Id, [string]$Part, [switch]$NoPause, [string]$Label = '', [string]$TestDir, [switch]$NoLaunch)
$app = Split-Path -Parent $PSScriptRoot
$call = (Split-Path -Leaf $PSScriptRoot) + ' ' + $Part + ' ' + $Label + ' id=' + $Id + ' nopause=' + [bool]$NoPause + ' keep=' + $env:KANON_KEEP_SIGNIN
Add-Content -LiteralPath (Join-Path $app 'calls.txt') -Value $call
if ($Part -eq 'Rows') { throw 'stub part threw' }
'OUT stub ' + $Part   # a line on the output stream (not Write-Host): the batch must show it and still read exit code 0
Write-Host ('ITEM stub ' + $Part + ' PASS')
$f = Join-Path $app ('exit-' + $Part + '.txt'); if (Test-Path -LiteralPath $f) { exit ([int](Get-Content -LiteralPath $f)) }
exit 0
'@
# Make the stub app folder: T30 with the real batch script, and T21, T26, T27 with stub part scripts of the table's names. Takes nothing; returns the batch path.
function New-StubApp {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
  foreach ($d in 'T21', 'T26', 'T27', 'T30') { $null = New-Item -ItemType Directory -Path (Join-Path $work $d) -Force }
  Copy-Item -LiteralPath $batchSrc -Destination (Join-Path $work 'T30')
  foreach ($p in @(@('T21', '90161Z-T21-probe-r14.ps1'), @('T26', '90161Z-T26-endorse-r5.ps1'), @('T27', '90161Z-T27-lifecycle-r3.ps1'))) {
    Set-Content -LiteralPath (Join-Path (Join-Path $work $p[0]) $p[1]) -Value $stub -Encoding ASCII }
  return (Join-Path (Join-Path $work 'T30') '90161Z-T30-batch-r1.ps1')
}
# Run the batch. Takes the batch path and the -Run text; returns @{ Code; Out (the lines); Calls (the lines of calls.txt) }.
function Invoke-Batch([string]$Path, [string]$Run) {
  $global:LASTEXITCODE = 0; $global:SignOuts = 0
  $out = @(& $Path -Id 'tester01' -NoPause -Run $Run *>&1 | ForEach-Object { [string]$_ })
  $calls = Join-Path $work 'calls.txt'
  return @{ Code = $LASTEXITCODE; Out = $out; Calls = @($(if (Test-Path -LiteralPath $calls) { Get-Content -LiteralPath $calls; Remove-Item -LiteralPath $calls } else { @() })) }
}

try {
  # ---- the batch, on stub parts ----
  $b = New-StubApp
  $r = Invoke-Batch $b 'T21:Clean:first;T21:Make;T21:Person;T26:Make;T27:Install:before'
  $want = @('T21 Clean first id=tester01 nopause=True keep=1', 'T21 Make  id=tester01 nopause=True keep=1', 'T21 Person  id=tester01 nopause=True keep=1',
    'T26 Make  id=tester01 nopause=True keep=1', 'T27 Install before id=tester01 nopause=True keep=1')
  Test-That 'the parts run in order, in their task folders, with -Id, -NoPause, -Part, -Label and the keep signal' ($r.Code -eq 0 -and
      ($r.Calls -join '|') -ceq ($want -join '|')) (($r.Calls -join '|') + ' / ' + ($r.Out -join '|'))
  Test-That 'a line a part leaves on the output stream is shown, and the exit code stays 0' ($r.Code -eq 0 -and $r.Out -contains 'OUT stub Person') ($r.Out -join '|')
  Test-That 'the keep signal is gone after the batch; the batch signs out once' (-not $env:KANON_KEEP_SIGNIN -and $global:SignOuts -eq 1) ('signouts=' + $global:SignOuts)
  $own = @($r.Out | Where-Object { $_ -match '^(TASK T30|NOW Part|BATCH )' })
  Test-That 'the batch prints TASK, a NOW and a BATCH line per part and BATCH done; its own lines hold no PASS, FAIL or SKIP word' ($own.Count -eq 12 -and
      -not @($own | Where-Object { $_ -match '(^|\s)(PASS|FAIL|SKIP|STOPPED:)(\s|$)' }).Count -and $r.Out[-1] -ceq 'BATCH done: parts=5 exit-not-zero=0') ($r.Out -join '|')
  Set-Content -LiteralPath (Join-Path $work 'exit-Make.txt') -Value '1'
  $r = Invoke-Batch $b 'T21:Make;T26:Rows;T26:Clean'
  Test-That 'a part that exits 1 and a part that throws do not stop the next part; the batch exits 1' ($r.Code -eq 1 -and $r.Calls.Count -eq 3 -and
      $r.Calls[2] -like 'T26 Clean *' -and @($r.Out | Where-Object { $_ -like 'STOPPED: the part T26 Rows did not run to its end*' }).Count -eq 1 -and
      $r.Out[-1] -ceq 'BATCH done: parts=3 exit-not-zero=2') ($r.Out -join '|')
  Remove-Item -LiteralPath (Join-Path $work 'exit-Make.txt')
  foreach ($bad in 'T21:Make;T22:Window', 'T21:Make;T21:Open', 'T21:Make;T21:Clean:after', 'T21:Make;..\x:Make', 'T21', ';') {
    $r = Invoke-Batch $b $bad
    $stops = @($r.Out | Where-Object { $_ -like 'STOPPED: *' }).Count
    Test-That ('-Run "' + $bad + '" stops before any part runs (STOPPED, exit 1)') ($r.Code -eq 1 -and $r.Calls.Count -eq 0 -and $stops -eq 1) ($r.Out -join '|') }
  Remove-Item -LiteralPath (Join-Path (Join-Path $work 'T26') '90161Z-T26-endorse-r5.ps1')
  $r = Invoke-Batch $b 'T21:Make;T26:Make'
  Test-That 'a script that is not in its folder stops the batch before any part runs' ($r.Code -eq 1 -and $r.Calls.Count -eq 0 -and
      ($r.Out -join '|') -match 'SCRIPT missing: T26\\90161Z-T26-endorse-r5\.ps1') ($r.Out -join '|')

  # ---- the batch table: each script is in scripts/gov and in the files of the R47 bundle ----
  $tab = [regex]::Matches((Get-Content -LiteralPath $batchSrc -Raw), "File = '(90161Z-T\d\d-[a-z]+-r\d+\.ps1)'") | ForEach-Object { $_.Groups[1].Value }
  $man = Get-Content -LiteralPath (Join-Path $Root 'scripts/paste_bundles.json') -Raw | ConvertFrom-Json
  $r47 = @($man.bundles | Where-Object { $_.round -eq 'R47' })
  $src = @($r47 | ForEach-Object { $_.files } | ForEach-Object { Split-Path -Leaf ([string]$_.src) })
  Test-That 'each script of the batch table is in scripts/gov and in the R47 bundle, and so is the batch' ($tab.Count -eq 3 -and $r47.Count -eq 1 -and
      -not @($tab | Where-Object { -not (Test-Path -LiteralPath (Join-Path $gov $_)) -or $src -notcontains $_ }).Count -and $src -contains '90161Z-T30-batch-r1.ps1') ($tab -join ',')

  # ---- the connect functions of T21 and T26: the real code, taken out of each script by the parser ----
  $modDir = Join-Path $work 'mods/PnP.PowerShell/1.12.0'; $null = New-Item -ItemType Directory -Path $modDir -Force
  Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psm1') -Value '# empty on purpose: the cmdlets are fakes in tests/ps/Test-T30.ps1'
  Set-Content -LiteralPath (Join-Path $modDir 'PnP.PowerShell.psd1') -Value "@{ RootModule = 'PnP.PowerShell.psm1'; ModuleVersion = '1.12.0'; GUID = '0b0430ce-d799-4f3b-a565-f0dca1f31e19' }"
  $env:PSModulePath = (Join-Path $work 'mods') + [IO.Path]::PathSeparator + $env:PSModulePath
  # Stand-in for the NOW line helper of T21 (the T21 test covers it): prints nothing here.
  function Write-Now([string]$Text) { $null = $Text }
  # Stand-in for the list read that Connect-ProbeSite does after the sign-in: 2 fake lists.
  function Get-SiteList { return @(1, 2) }
  foreach ($c in @(@('90161Z-T21-common-r14.ps1', 'Connect-ProbeSite'), @('90161Z-T26-endorse-r5.ps1', 'Connect-EndorseSite'), @('90161Z-T27-lifecycle-r3.ps1', 'Connect-LifecycleSite'))) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $gov $c[0]), [ref]$null, [ref]$null)
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $c[1] }, $true)
    $text = [string]$fn.Extent.Text
    Test-That ($c[1] + ' has no DPI call (RADE engine-v47 turns it off)') ($text -notmatch 'Set-SignInDpiAware') $text
    if ($c[1] -eq 'Connect-LifecycleSite') { continue }   # its run: tests/ps/Test-T27.ps1 (through the batch)
    . ([scriptblock]::Create($text))
    $script:site = $env:RADE_SITE; $script:lines = New-Object System.Collections.Generic.List[string]; $lines = $script:lines
    $global:SignedInTo = ''; $global:Connects = 0
    & $c[1]; & $c[1]
    $reused = @($lines | Where-Object { $_ -ceq 'SIGNIN reused: this process is signed in to the site already' }).Count
    Test-That ($c[1] + ': one sign-in, then the second call reuses it') ($global:Connects -eq 1 -and $reused -eq 1) ($lines -join '|')
    $global:SignedInTo = 'https://fakehost.example.test/sites/Other'; $global:Connects = 0; $lines.Clear()
    & $c[1]
    Test-That ($c[1] + ': a connection to another site is not reused (it signs in)') ($global:Connects -eq 1 -and -not @($lines | Where-Object { $_ -like 'SIGNIN reused*' }).Count) ($lines -join '|')
  }
  foreach ($f in '90161Z-T21-probe-r14.ps1', '90161Z-T26-endorse-r5.ps1', '90161Z-T27-lifecycle-r3.ps1') {
    $t = Get-Content -LiteralPath (Join-Path $gov $f) -Raw
    $dis = @([regex]::Matches($t, '(?m)^\s*(?!#).*Disconnect-PnPOnline.*$') | ForEach-Object { $_.Value })
    $free = @($dis | Where-Object { $_ -notmatch "KANON_KEEP_SIGNIN -ne '1'" -and $_ -notmatch '^\s*function ' }).Count
    Test-That ($f + ': every sign-out waits for the batch signal (KANON_KEEP_SIGNIN)') ($dis.Count -ge 1 -and $free -eq 0) ($dis -join '|')
  }

  # ---- the T21 second person prompt fits its box (R46 finding 4) ----
  $m = [regex]::Match((Get-Content -LiteralPath (Join-Path $gov '90161Z-T21-person-r14.ps1') -Raw), "(?m)^\s*\`$prompt = '([^']+)'\s*$")
  Test-That 'the second person prompt is one text of 120 characters at most and keeps Skip' ($m.Success -and $m.Groups[1].Value.Length -le 120 -and $m.Groups[1].Value -match 'select Skip') $m.Value
} finally {
  Set-Location -LiteralPath $Root
  $env:KANON_KEEP_SIGNIN = $null
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('T30 pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail) { exit 1 }
