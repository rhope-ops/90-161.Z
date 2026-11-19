# Tests the T22 PFM window r9 at 4 window sizes (R36 W13; R35 findings 4 and 5): the PFM's half laptop, 956 x 1081 at
# 150 %, and 1920 x 1080 at 100 %, 2560 x 1440 at 100 % and 3840 x 2160 at 150 %.
# Network: none.
# Writes: one temporary folder with the size file of the window; removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Windows only: elsewhere the one line "T22SIZES SKIP ..." and exit 0.
# Runs scripts/gov/90161Z-T22-pfm-window-r9.ps1 -SizeCheck <file> -NoPause in a child of the same engine (the window is
# built off-screen in a panel of each size, at each scale, measured and closed; no question) and checks, at each size
# with the r9 layout: 0 layout defects (the window's own layout self-check, sideways scroll included); no card whose
# main column scrolls sideways; the layout computed once for all the cards of the size; and the stability check: each
# card of the window's $SteadyCards, shown again with other numbers (every digit changed), moved no control and changed
# no size. Once: the main grid of Your Work and of All Actions shows no fewer rows at 2560 x 1440 than at 1920 x 1080.
# Each size also gives one "T22SIZES REPORT rows" line: the rows of those 2 grids that show without scrolling (of the
# grid's rows shown, of all rows), with the r8 layout and the r9 layout (tests/ps/Invoke-Ps51.ps1 prints REPORT lines).
# Last line: "T22SIZES pass=N fail=0" (tests/ps/Invoke-Ps51.ps1 runs it on the ps51 Windows job).
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { Write-Host 'T22SIZES SKIP not Windows: the window needs Windows Forms (the ps51 Windows job runs this test)'; exit 0 }
$script:pass = 0; $script:fail = 0
# Record one result and print PASS or FAIL with its numbers. Takes the test name, the condition and the measured numbers; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Numbers = '') {
  if ($Ok) { $script:pass++; Write-Host ('T22SIZES PASS ' + $Name + ': ' + $Numbers) } else { $script:fail++; Write-Host ('T22SIZES FAIL ' + $Name + ': ' + $Numbers) }
}
# The rows of card $Key in one size result $C as text: "<card> <screen>/<grid>/<total>", or "<card> none".
function Format-Row($C, [string]$Key) {
  $r = @($C.Cards | Where-Object { [string]$_.Key -eq $Key }) | Select-Object -First 1
  if (-not $r -or -not $r.Rows) { return ($Key + ' none') }
  return ($Key + ' ' + $r.Rows.Screen + '/' + $r.Rows.Grid + '/' + $r.Rows.Total)
}
<#
.SYNOPSIS
Checks one size with the r9 layout: no layout defect, no sideways scroll, one layout for the size, and the stability
check of each card it ran on.
.PARAMETER C
The size result (W, H, K, Rev, Count, Defects, Cards).
.PARAMETER At
The size as text (it starts each line).
#>
function Test-Size($C, [string]$At) {
  $bad = @($C.Defects | Where-Object { $_ })
  Test-That ($At + ': 0 layout defects') ($bad.Count -eq 0) ('defects ' + $bad.Count + $(if ($bad.Count) { ' (' + ((@($bad) | Select-Object -First 5) -join '; ') + ')' } else { '' }))
  $side = @($C.Cards | Where-Object { $_.Sideways } | ForEach-Object { [string]$_.Key })
  Test-That ($At + ': no main column scrolls sideways') ($side.Count -eq 0) ('cards ' + @($C.Cards).Count + ', sideways: ' + $side.Count + ' ' + ($side -join ', '))
  Test-That ($At + ': the layout computed once for all cards') ([int]$C.Count -eq 1) ('layouts computed ' + $C.Count + ' for ' + @($C.Cards).Count + ' cards')
  $steady = @($C.Cards | Where-Object { $_.PSObject.Properties['Moved'] })
  Test-That ($At + ': stability check ran on 4 cards') ($steady.Count -eq 4) ('cards checked ' + $steady.Count + ' (' + (@($steady | ForEach-Object { $_.Key }) -join ', ') + ')')
  foreach ($s in $steady) { $m = @($s.Moved | Where-Object { $_ })
    Test-That ($At + ' ' + $s.Key + ': other numbers move nothing') ($m.Count -eq 0) ('differences ' + $m.Count + $(if ($m.Count) { ' (' + ($m -join '; ') + ')' } else { '' })) }
}
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('t22sizes-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tmp)
try {
  $file = Join-Path $tmp 'sizes.json'
  $engine = (Get-Process -Id $PID).Path
  $window = Join-Path $Root 'scripts/gov/90161Z-T22-pfm-window-r9.ps1'
  $ErrorActionPreference = 'Continue'   # the child's error output is shown below, not thrown here
  $log = @(& $engine -NoProfile -ExecutionPolicy Bypass -File $window -SizeCheck $file -NoPause 2>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE; $ErrorActionPreference = 'Stop'
  $built = ($code -eq 0 -and (Test-Path -LiteralPath $file))
  Test-That 'the window was built off-screen at each size' $built ('exit ' + $code + '; last line: ' + (@($log | Where-Object { $_.Trim() }) | Select-Object -Last 1))
  if (-not $built) { @($log | Where-Object { $_ -match '^\s*(STOPPED|NOTE)' }) | ForEach-Object { Write-Host ('T22SIZES FAIL child: ' + $_.Trim()) } }
  else {
    $m = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    $cases = @($m.Cases); $err = @($cases | Where-Object { $_.Error })
    $why = @($err | ForEach-Object { $_.Rev + ' ' + $_.W + 'x' + $_.H + ': ' + $_.Error }) -join '; '
    Test-That 'every size was measured' ($cases.Count -eq 8 -and $err.Count -eq 0) ('sizes ' + $cases.Count + ' of 8; errors: ' + $why)
    $rows = @{}
    foreach ($c in @($cases | Where-Object { -not $_.Error })) {
      $at = [string]$c.W + ' x ' + $c.H + ' at ' + [int]([double]$c.K * 100) + ' %'
      if ([string]$c.Rev -eq 'r9') { Test-Size $c $at }
      $rows[[string]$c.Rev + ' ' + $at] = (Format-Row $c 'home') + ', ' + (Format-Row $c 'queue')
      $rows[[string]$c.Rev + '|' + $c.W] = $c }
    foreach ($k in @($rows.Keys | Where-Object { $_ -match '^r9 ' } | Sort-Object)) {
      $at = $k.Substring(3); Write-Host ('T22SIZES REPORT rows ' + $at + ' (seen/shown/all): r8 ' + $rows['r8 ' + $at] + '; r9 ' + $rows[$k]) }
    $a = $rows['r9|1920']; $b = $rows['r9|2560']
    if ($a -and $b) { foreach ($key in 'home', 'queue') {
        $ra = @($a.Cards | Where-Object { [string]$_.Key -eq $key })[0].Rows; $rb = @($b.Cards | Where-Object { [string]$_.Key -eq $key })[0].Rows
        Test-That ('r9 ' + $key + ': no fewer rows at 2560 x 1440 than at 1920 x 1080') ($ra -and $rb -and [int]$rb.Screen -ge [int]$ra.Screen) ('rows seen ' + $ra.Screen + ' and ' + $rb.Screen) } }
  }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host ('T22SIZES pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail -gt 0) { exit 1 }
