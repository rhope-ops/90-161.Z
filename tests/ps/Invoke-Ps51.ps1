# Runs the repo's PowerShell tests as child processes of the engine this script runs in, and checks each one's last line.
# The workflow .github/workflows/ps51.yml starts it with Windows PowerShell 5.1 (powershell.exe) on a Windows runner; tests/run.sh
# starts it with pwsh so the driver cannot rot. Last line: "PS51 pass=N fail=0"; exit 1 when any test fails.
# Network: none.
# Writes: nothing in the repo (the tests write only their own temp folders and remove them).
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Pure ASCII.
# Tests run: Test-Mask.ps1 ("MASK pass=N fail=0"), Test-T20.ps1 ("T20 pass=N fail=0", uses the fake PnP module in tests/fake-pnp),
# Test-T21.ps1 ("T21 pass=N fail=0", fake cmdlets inside the test).
# Tests left out of the 5.1 list, with the reason:
#   Invoke-Validations.ps1  needs an input list that tests/run.sh builds with bash and python; no pass line of its own.
#   Test-SealTrim.ps1       needs raw pixel files that python (scripts/build_test_seals.py --raw) makes first.
#   Invoke-Batch.ps1        is a producer for tests/run.sh (writes .out and .rc files that bash checks); no pass line of its own.
#                           Its Font member also loads System.Drawing.Common, which Windows PowerShell 5.1 does not have.
<#
.SYNOPSIS
Run the PowerShell tests of this repo under the current engine and print one PS51 line per test.
.DESCRIPTION
Each test starts as a child process of the engine that runs this script, so powershell.exe tests Windows PowerShell 5.1
and pwsh tests PowerShell 7. A test passes when it exits 0 and its last output line matches its pass line with fail=0.
.PARAMETER Root
The repository root. Default: two folders above this script.
#>
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
# Name, file and pass-line pattern of each test, in run order.
$tests = @(
  @{ Name = 'Test-Mask'; File = 'tests/ps/Test-Mask.ps1'; Pattern = '^MASK pass=\d+ fail=0$' },
  @{ Name = 'Test-T20'; File = 'tests/ps/Test-T20.ps1'; Pattern = '^T20 pass=\d+ fail=0$' },
  @{ Name = 'Test-T21'; File = 'tests/ps/Test-T21.ps1'; Pattern = '^T21 pass=\d+ fail=0$' }
)

<#
.SYNOPSIS
Run one test file in a child process of the current engine.
.DESCRIPTION
Starts the same executable this script runs in, with no profile and the repository root as the test's -Root.
.PARAMETER Engine
Full path of the running engine (powershell.exe or pwsh).
.PARAMETER Test
The hashtable of one entry of the test list (Name, File, Pattern).
.OUTPUTS
A hashtable with Code (exit code) and Last (the last non-empty output line, or an empty string).
#>
function Invoke-OneTest([string]$Engine, [hashtable]$Test) {
  $file = Join-Path $Root $Test.File
  $args1 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $file, '-Root', $Root)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'   # Windows PowerShell 5.1 turns child stderr lines into errors under 'Stop'
  $global:LASTEXITCODE = 0
  $lines = @(& $Engine @args1 2>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $text = @($lines | Where-Object { $_.Trim() })
  $last = ''
  if ($text.Count -gt 0) { $last = $text[$text.Count - 1].Trim() }
  return @{ Code = $code; Last = $last; Lines = $text }
}

$engine = (Get-Process -Id $PID).Path
Write-Host ('PS51 engine ' + $PSVersionTable.PSVersion + ' (' + $engine + ')')
$pass = 0; $fail = 0
foreach ($t in $tests) {
  $r = Invoke-OneTest $engine $t
  if ($r.Code -eq 0 -and $r.Last -match $t.Pattern) { $pass++; Write-Host ('PS51 PASS ' + $t.Name + ' ' + $r.Last) }
  else {
    $fail++
    @($r.Lines | Where-Object { $_ -match 'FAIL' } | Select-Object -First 20) | ForEach-Object { Write-Host ('  ' + $_) }
    Write-Host ('PS51 FAIL ' + $t.Name + ' exit=' + $r.Code + ' ' + $r.Last)
  }
}
Write-Host ('PS51 pass=' + $pass + ' fail=' + $fail)
if ($fail -gt 0) { exit 1 }
