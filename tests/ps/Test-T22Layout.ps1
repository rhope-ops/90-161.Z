# Tests the look of the T22 PFM window r4 by measurement (round R30: the R29b defects V2 to V4 and the accessible names).
# Network: none.
# Writes: one temporary folder with the measure file of the window; removed at the end.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7). Windows only: elsewhere the one line "T22LAYOUT SKIP ..." and exit 0.
# Runs scripts/gov/90161Z-T22-pfm-window-r4.ps1 -Measure <file> -NoPause in a child of the same engine (the window is built
# off-screen, measured and closed; no question) and checks what it wrote: each crumb's link and rest have one font and size
# (V2), the ink gap after the link is at most 8 px at 100 % (V2), step 8 has no "See the 0 findings" link (V3), step 8's
# Action Status card ends within 2 px of the main card (V4), Full History is drawn like the other white secondary
# buttons (V4), and no button, link or text box lacks an accessible name. Each line shows the measured numbers.
# Last line: "T22LAYOUT pass=N fail=0" (tests/ps/Invoke-Ps51.ps1 runs it on the ps51 Windows job).
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { Write-Host 'T22LAYOUT SKIP not Windows: the window needs Windows Forms (the ps51 Windows job runs this test)'; exit 0 }
$script:pass = 0; $script:fail = 0
# Record one result and print PASS or FAIL with its numbers. Takes the test name, the condition and the measured numbers; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Numbers = '') {
  if ($Ok) { $script:pass++; Write-Host ('T22LAYOUT PASS ' + $Name + ': ' + $Numbers) } else { $script:fail++; Write-Host ('T22LAYOUT FAIL ' + $Name + ': ' + $Numbers) }
}
# A font of the measure file as text: name, size in points, style, height in pixels.
function Format-Font($F) { return ([string]$F.Name + ' ' + $F.Size + ' pt ' + $F.Style + ' ' + $F.Height + ' px') }
# The cards whose crumb has a link (the R29b screenshots showed V2 on these six).
$crumbCards = @('step8', 'confirm', 'sendback', 'step11', 'step12', 'remindall')
# Check the crumb of one card: one font and size for link and rest, and the ink gap after the link at most $Limit pixels.
function Test-Crumb([string]$Key, $Card, [int]$Limit) {
  $cr = $Card.Crumb
  if (-not $cr) { Test-That ($Key + ' crumb has a link') $false 'no crumb link measured'; return }
  $same = ([string]$cr.LinkFont.Name -eq [string]$cr.RestFont.Name -and [double]$cr.LinkFont.Size -eq [double]$cr.RestFont.Size -and [int]$cr.LinkFont.Height -eq [int]$cr.RestFont.Height)
  Test-That ($Key + ' crumb: one font and size') $same ('link ' + (Format-Font $cr.LinkFont) + '; rest ' + (Format-Font $cr.RestFont))
  $gapOk = ($null -ne $cr.GapInk -and [int]$cr.GapInk -ge 0 -and [int]$cr.GapInk -le $Limit)
  $nums = 'ink gap ' + $cr.GapInk + ' px, limit ' + $Limit + ' px; control gap ' + $cr.GapBounds + ' px'
  $nums += '; link ' + $cr.LinkBounds + ' last ink ' + $cr.LinkInk + ', rest ' + $cr.RestBounds + ' first ink ' + $cr.RestInk
  Test-That ($Key + ' crumb: gap after the link') $gapOk $nums
}
<#
.SYNOPSIS
Checks step 8: no link to 0 findings (V3), the Action Status card's bottom on the main card's bottom (V4), and Full
History drawn like the white secondary button "Send Back to the AO" (V4).
.PARAMETER Card
The measured step 8 card from the measure file.
#>
function Test-Step8($Card) {
  $zero = @($Card.Buttons | Where-Object { [string]$_.Text -match '0 findings' })
  Test-That 'step8: no "See the 0 findings" link' ($zero.Count -eq 0) ('links and buttons on the card: ' + @($Card.Buttons).Count + ', with "0 findings": ' + $zero.Count)
  $secs = @($Card.Sections); $side = @($secs | Where-Object { [string]$_.Cap -eq 'Action Status' }) | Select-Object -First 1
  $main = @($secs | Where-Object { [int]$_.Col -eq 0 }) | Select-Object -Last 1
  $ok = [bool]($side -and $main -and [math]::Abs([int]$side.Bottom - [int]$main.Bottom) -le 2)
  Test-That 'step8: Action Status bottom = main card bottom (+-2 px)' $ok ('Action Status bottom ' + $side.Bottom + ' px, main card bottom ' + $main.Bottom + ' px')
  $fh = @($Card.Buttons | Where-Object { [string]$_.Text -eq 'Full History' }) | Select-Object -First 1
  $ref = @($Card.Buttons | Where-Object { [string]$_.Text -eq 'Send Back to the AO' }) | Select-Object -First 1
  $ok = [bool]($fh -and $ref -and $fh.Back -eq '#FFFFFF' -and $fh.Back -eq $ref.Back -and $fh.Face -eq $ref.Face -and $fh.Edge -eq $ref.Edge)
  $nums = 'Full History back ' + $fh.Back + ' face ' + $fh.Face + ' edge ' + $fh.Edge + '; Send Back to the AO back ' + $ref.Back + ' face ' + $ref.Face + ' edge ' + $ref.Edge
  Test-That 'step8: Full History is a white secondary button' $ok $nums
}
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('t22layout-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tmp)
try {
  $file = Join-Path $tmp 'measure.json'
  $engine = (Get-Process -Id $PID).Path
  $window = Join-Path $Root 'scripts/gov/90161Z-T22-pfm-window-r4.ps1'
  $ErrorActionPreference = 'Continue'   # the child's error output is shown below, not thrown here
  $log = @(& $engine -NoProfile -ExecutionPolicy Bypass -File $window -Measure $file -NoPause 2>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE; $ErrorActionPreference = 'Stop'
  $built = ($code -eq 0 -and (Test-Path -LiteralPath $file))
  Test-That 'the window was built off-screen and measured' $built ('exit ' + $code + '; last line: ' + (@($log | Where-Object { $_.Trim() }) | Select-Object -Last 1))
  # Invoke-Ps51 shows only lines with FAIL in them: the child's STOPPED and NOTE lines are repeated as FAIL lines, so the CI log names the cause.
  if (-not $built) { @($log | Where-Object { $_ -match '^\s*(STOPPED|NOTE)' }) | ForEach-Object { Write-Host ('T22LAYOUT FAIL child: ' + $_.Trim()) }
    @($log | Select-Object -Last 15) | ForEach-Object { Write-Host ('  ' + $_) } }
  else {
    $m = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    Write-Host ('T22LAYOUT window ' + $m.Client + ' at ' + $m.Dpi + ' dpi; 8 px at 100 % = ' + $m.Sc8 + ' px; layout self-check defects: ' + @($m.LayoutDefects).Count)
    $byKey = @{}; foreach ($c in @($m.Cards)) { $byKey[[string]$c.Key] = $c }
    $broken = @($m.Cards | Where-Object { $_.Error })
    Test-That 'every card was measured' ($broken.Count -eq 0) ('cards ' + @($m.Cards).Count + ', not measured: ' + (@($broken | ForEach-Object { [string]$_.Key + ' (' + $_.Error + ')' }) -join '; '))
    foreach ($k in $crumbCards) { Test-Crumb $k $byKey[$k] ([int]$m.Sc8) }
    Test-Step8 $byKey['step8']
    $empty = @($m.EmptyNames | Where-Object { $_ })
    Test-That 'every button, link and text box has an accessible name' ($empty.Count -eq 0) ('without a name: ' + $empty.Count + $(if ($empty.Count) { ' (' + ($empty -join ', ') + ')' } else { '' }))
  }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host ('T22LAYOUT pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail -gt 0) { exit 1 }
