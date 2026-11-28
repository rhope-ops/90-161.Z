# Runs the repo's PowerShell tests as child processes of the engine this script runs in, and checks each one's last line.
# The workflow .github/workflows/ps51.yml starts it with Windows PowerShell 5.1 (powershell.exe) on a Windows runner. tests/run.sh
# does not start it (that file is at its listed size limit), so only that job proves the driver itself. Last line: "PS51 pass=N fail=0"; exit 1 when any test fails.
# Network: none.
# Writes: nothing in the repo (the tests write only their own temp folders and remove them).
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Pure ASCII.
# Tests run: Test-Mask.ps1 ("MASK pass=N fail=0"), Test-T20.ps1 ("T20 pass=N fail=0", uses the fake PnP module in tests/fake-pnp),
# Test-T21.ps1 ("T21 pass=N fail=0", fake cmdlets inside the test), Test-T24.ps1 ("T24 pass=N fail=0", part 0 of T24 r6 on the fake PnP module),
# Test-T22Layout.ps1 ("T22LAYOUT pass=N fail=0"; SKIP off Windows), Test-T26.ps1 ("T26 pass=N fail=0", fake cmdlets inside the test; R41),
# Test-PsClass.ps1 ("PSCLASS pass=N fail=0"; SKIP off Windows; fleet F6 spike: PowerShell classes in place of inline C#).
# A passed test's lines "<NAME> REPORT ..." are printed too (numbers a round report needs, such as the window's rows per size).
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
Each test gets no input and a time limit (Invoke-OneTest).
.PARAMETER Root
The repository root. Default: two folders above this script.
#>
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
# Name, file and pass-line pattern of each test, in run order.
$tests = @(
  @{ Name = 'Test-Mask'; File = 'tests/ps/Test-Mask.ps1'; Pattern = '^MASK pass=\d+ fail=0$' },
  @{ Name = 'Test-T20'; File = 'tests/ps/Test-T20.ps1'; Pattern = '^T20 pass=\d+ fail=0$' },
  @{ Name = 'Test-T21'; File = 'tests/ps/Test-T21.ps1'; Pattern = '^T21 pass=\d+ fail=0$' },
  @{ Name = 'Test-T24'; File = 'tests/ps/Test-T24.ps1'; Pattern = '^T24 pass=\d+ fail=0$' },
  @{ Name = 'Test-T22Maint'; File = 'tests/ps/Test-T22Maint.ps1'; Pattern = '^T22MAINT pass=\d+ fail=0$' },
  @{ Name = 'Test-T26'; File = 'tests/ps/Test-T26.ps1'; Pattern = '^T26 pass=\d+ fail=0$' },
  @{ Name = 'Test-T22Layout'; File = 'tests/ps/Test-T22Layout.ps1'; Pattern = '^T22LAYOUT (pass=\d+ fail=0|SKIP .+)$' },
  @{ Name = 'Test-PsClass'; File = 'tests/ps/Test-PsClass.ps1'; Pattern = '^PSCLASS (pass=\d+ fail=0|SKIP .+)$' }
)

<#
.SYNOPSIS
Run one test file in a child process of the current engine, with no input and a time limit.
.DESCRIPTION
Starts the same executable this script runs in, with no profile and the repository root as the test's -Root. The
child's input is an empty file, so a question in the tested code gets an empty answer at once and cannot wait for a
person (the first run on a Windows runner waited 15 minutes in Test-T21). Output goes to temporary files that are
removed afterwards. A child that runs longer than the limit is stopped and counts as failed.
.PARAMETER Engine
Full path of the running engine (powershell.exe or pwsh).
.PARAMETER Test
The hashtable of one entry of the test list (Name, File, Pattern).
.PARAMETER LimitSeconds
How long the test may run before it is stopped.
.OUTPUTS
A hashtable with Code (exit code; -1 when stopped at the limit), Last (the last non-empty output line, or an empty
string) and Lines (all non-empty output lines).
#>
function Invoke-OneTest([string]$Engine, [hashtable]$Test, [int]$LimitSeconds) {
  $file = Join-Path $Root $Test.File
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('ps51-' + [guid]::NewGuid().ToString('N'))
  [void](New-Item -ItemType Directory -Path $tmp)
  $in = Join-Path $tmp 'in.txt'; $out = Join-Path $tmp 'out.txt'; $err = Join-Path $tmp 'err.txt'
  Set-Content -LiteralPath $in -Value '' -Encoding ASCII
  $list = @('-NoProfile', '-File', ('"' + $file + '"'), '-Root', ('"' + $Root + '"'))
  $code = -1
  try {
    $p = Start-Process -FilePath $Engine -ArgumentList $list -RedirectStandardInput $in -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
    $null = $p.Handle   # Windows PowerShell 5.1 gives no ExitCode later unless the handle was read while the child ran
    if ($p.WaitForExit($LimitSeconds * 1000)) { $p.WaitForExit(); $code = $p.ExitCode }
    else { try { $p.Kill() } catch { $null = $_ }   # it ended between the wait and the stop: nothing to stop
      [void]$p.WaitForExit(5000) }
    $lines = @(Get-Content -LiteralPath $out -ErrorAction SilentlyContinue) + @(Get-Content -LiteralPath $err -ErrorAction SilentlyContinue)
  } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  $text = @($lines | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
  $last = ''
  if ($text.Count -gt 0) { $last = $text[$text.Count - 1].Trim() }
  return @{ Code = $code; Last = $last; Lines = $text }
}

$engine = (Get-Process -Id $PID).Path
Write-Host ('PS51 engine ' + $PSVersionTable.PSVersion + ' (' + $engine + ')')
$pass = 0; $fail = 0
$limit = 180   # seconds for one test: the slowest takes about 15 s; a test that waits for a person is stopped here
foreach ($t in $tests) {
  $r = Invoke-OneTest $engine $t $limit
  if ($r.Code -eq 0 -and $r.Last -match $t.Pattern) { $pass++; @($r.Lines | Where-Object { $_ -match '^\S+ REPORT ' }) | ForEach-Object { Write-Host ('  ' + $_) }
    Write-Host ('PS51 PASS ' + $t.Name + ' ' + $r.Last) }
  else {
    $fail++
    @($r.Lines | Where-Object { $_ -match 'FAIL' } | Select-Object -First 20) | ForEach-Object { Write-Host ('  ' + $_) }
    if ($r.Code -eq -1) { Write-Host ('  stopped after ' + $limit + ' s; its last lines:'); @($r.Lines | Select-Object -Last 15) | ForEach-Object { Write-Host ('  ' + $_) } }
    Write-Host ('PS51 FAIL ' + $t.Name + ' exit=' + $r.Code + ' ' + $r.Last)
  }
}
Write-Host ('PS51 pass=' + $pass + ' fail=' + $fail)
if ($fail -gt 0) { exit 1 }
