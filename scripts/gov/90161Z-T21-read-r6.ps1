<#
.SYNOPSIS
  90-161.Z Task 21 probe r6, module "read": the parts Run (the command row that starts the health flow) and Read (the
  results of HEALTH, T4 and BUTTON).
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r6.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values the main file sets ($dir, $ListTitle, $ListFolder, $WaitMinutes, $pollEvery) and the helpers of the
  module "common"; the rows of the probe list and the second person's state file. Outputs: result lines (counts only)
  through Add-Item and Add-Test.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection.
  Writes: Run: 1 row on the probe list. Read: nothing.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r6.ps1 -Part Run (or Read) loads it.
#>

# The part Run: adds 1 command row (RUN-HEALTH) that starts the health flow; the Read part waits for its answer.
function Invoke-RunPart {
  $lst = Find-ByFolder $ListFolder
  if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
  $tag = 'R29' + [guid]::NewGuid().ToString('N').Substring(0, 8)
  $null = Add-PnPListItem -List $ListTitle -Values @{ Title = ('RUN-HEALTH ' + $tag) } -ErrorAction Stop
  Add-Item 'r1-command' 'INFO' ('command row made: RUN-HEALTH, tag ' + $tag + '; the health flow answers within a few minutes (the Read part waits for it)')
}

<#
.SYNOPSIS
  Read, test HEALTH: the Power Automate Management connector lists the owner's own flows (this environment only) and
  counts how many are On; the flow writes one RESULT row after the newest command row.
.PARAMETER Rows
  The probe list rows (from Get-ListRow).
.PARAMETER HealthFloor
  The Id of the newest RUN-HEALTH command row (0 when there is none).
#>
function Add-HealthTest($Rows, [int]$HealthFloor) {
  $name = 'a Power Automate Management connector, own flows only='
  $h = $null
  if ($HealthFloor -gt 0) { $h = Find-Result @($Rows | Where-Object { $_.Id -gt $HealthFloor }) 'HEALTH' 'a' }
  if (-not $HealthFloor) { Add-Test 'HEALTH' @($name + 'FAIL (no command row: run the health step first)') $false }
  elseif (-not $h) {
    $why = 'no result row after the wait: the flow did not run; if the import refused the connector or asked for a Premium licence, the import answer says so'
    Add-Test 'HEALTH' @($name + 'FAIL (' + $why + ')') $false
  } else {
    $d = Format-Detail $h.ProbeDetail
    Add-Test 'HEALTH' @($name + $h.ProbeResult + $(if ($d) { ' (' + $d + ')' } else { '' })) ($h.ProbeResult -eq 'PASS')
  }
}

<#
.SYNOPSIS
  Read, test T4: a person who is a Visitors member writes a row through the list form (Contribute on this list only).
  Rows by anyone but you count; RESULT rows do not.
.PARAMETER Rows
  The probe list rows (from Get-ListRow).
.PARAMETER MeId
  Your own site user number (0 when it cannot be read).
#>
function Add-T4Test($Rows, [int]$MeId) {
  $others = @($Rows | Where-Object { $_.Title -ne 'RESULT' -and $MeId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $MeId })
  $t4a = @($Rows | Where-Object { ([string]$_.Title).Trim() -eq 'T4a' -and $MeId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $MeId })
  $st = Read-State $script:dir
  $addedText = $(if (-not $st) { 'not tried (no state file)' } elseif ($st['WasMember'] -eq 'yes') { 'already a member' } else { 'yes' })
  $t4pass = ($others.Count -ge 1)
  $counts = '(rows=' + $others.Count + '; T4a rows=' + $t4a.Count + '; person in the Visitors group=' + $addedText + ')'
  $t4 = @('a list form by a second person (Visitors member)=' + $(if ($t4pass) { 'PASS' } else { 'FAIL' }) + ' ' + $counts)
  if (-not $t4pass) { $t4 += 'next: way C: a flow writes the row with the PFM''s connection (not built)' }
  Add-Test 'T4' $t4 $t4pass
}

<#
.SYNOPSIS
  The part Read: waits for the health flow's row (only when there is a command row), then one test line each for
  HEALTH, T4 and BUTTON (counts only).
#>
function Invoke-ReadPart {
  $lst = Find-ByFolder $ListFolder
  if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
  $rf = @('Title', 'ProbeTest', 'ProbeWay', 'ProbeResult', 'ProbeDetail', 'Author')
  $rows = @(Get-ListRow $ListTitle $rf)
  # The health flow answers a minute or more after its command row. Wait for it (default 4 minutes) only when there is one.
  $healthFloor = [int](@($rows | Where-Object { $_.Title -like 'RUN-HEALTH *' } | ForEach-Object { $_.Id }) + 0 | Measure-Object -Maximum).Maximum
  if ($healthFloor -gt 0) {
    $ok = Wait-Until {
      $rows = @(Get-ListRow $ListTitle $rf)
      [bool](Find-Result @($rows | Where-Object { $_.Id -gt $healthFloor }) 'HEALTH' 'a') } 'the health flow''s result row'
    $rows = @(Get-ListRow $ListTitle $rf)
    $script:lines.Add('WAIT health row ' + $(if ($ok) { 'there' } else { 'not there (time ran out)' }))
  } else { $script:lines.Add('WAIT none: no RUN-HEALTH row on the list') }
  $meId = 0
  try { $meId = [int]((Invoke-Rest 'Get' '_api/web/currentuser?$select=Id' '') | ConvertFrom-Json).Id } catch { $meId = 0 }
  Add-HealthTest $rows $healthFloor
  Add-T4Test $rows $meId
  # BUTTON: the hand-made flow, started by the view button, wrote one row titled BTN-HAND (its Create item action).
  $btn = @($rows | Where-Object { ([string]$_.Title).Trim() -like 'BTN-HAND*' })
  Add-Test 'BUTTON' @('b a view button starts a flow=' + $(if ($btn.Count) { 'PASS' } else { 'FAIL' }) + ' (rows titled BTN-HAND=' + $btn.Count + ')') ($btn.Count -ge 1)
  $script:lines.Add('NOTE FORM and VIEW: what the screen showed is left to the answers you give in the RADE window (this script does not read them)')
}
