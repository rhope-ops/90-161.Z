# Shared wait block for the gov task scripts that wait for a flow to act (T18 slice 1, T24 full solution; code standard
# S1, rule C5: one function lives in one file). scripts/build_task_scripts.py writes the text from the first "function"
# line on between the wait-common markers of each scripts/gov/90161Z-T*.ps1 that has them. Edit only this file, then
# rebuild; never edit the copies. The T21 probe keeps its own Wait-Until (it polls every -PollSeconds and prints once a
# minute, so its tests can wait 1 second).
# Inputs: the script's $WaitMinutes (its -WaitMinutes parameter). Outputs: $true or $false, and progress lines.
# Windows PowerShell 5.1.
# Network: none of its own; the check script block it runs may read the site.
# Writes: none.
# Credentials: none.

function Wait-Until([scriptblock]$Done, [string]$What) {
  <#
  .SYNOPSIS
  Checks every 30 seconds for up to $WaitMinutes (the calling script's -WaitMinutes). A failed check (for example a
  network drop: R20 part 1 of T18 lost the site name) is retried; 3 failures in a row stop the test (R20 finding 3).
  .PARAMETER Done
  The check: a script block that returns $true when the wait is over.
  .PARAMETER What
  What is waited for, for the progress line.
  .OUTPUTS
  System.Boolean. $true when the check passed in time, $false when the time ran out.
  #>
  $end = (Get-Date).AddMinutes($WaitMinutes)
  $misses = 0
  while ($true) {
    $isDone = $false
    try { $isDone = [bool](& $Done); $misses = 0 }
    catch {
      $misses++
      if ($misses -ge 3) { throw }
      Write-Host ('  A check failed (' + $misses + ' of 3 allowed in a row); trying again in 30 seconds ...')
    }
    if ($isDone) { return $true }
    if ((Get-Date) -ge $end) { return $false }
    Write-Host ('  Waiting for ' + $What + ' (checks every 30 seconds, up to ' + $WaitMinutes + ' minutes) ...')
    Start-Sleep -Seconds 30
  }
}
