<#
.SYNOPSIS
  90-161.Z Task 21 probe r10, module "read": the parts Run (the command row that starts the health flow) and Read (the
  results of HEALTH, T4, EDITALL and BUTTON).
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r10.ps1 (dot-sourced from the same folder); it does nothing when it is run alone. r10 (PFM 19 Nov 26): T4 expects PASS through list-level Contribute for the Visitors
  group; the FAIL text no longer points to way C (a flow), which the PFM replaced.
  Inputs: the values the main file sets ($dir, $ListTitle, $ListFolder, $WaitMinutes, $pollEvery) and the helpers of the
  module "common"; the rows of the probe list and the second person's state files (Person, Office). Outputs: result lines (counts only)
  through Add-Item and Add-Test.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection.
  Writes: Run: 1 row on the probe list. Read: nothing.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r10.ps1 -Part Run (or Read) loads it.
#>

# The part Run: adds 1 command row (RUN-HEALTH) that starts the health flow; the Read part waits for its answer.
function Invoke-RunPart {
  Write-Now 'Looking for the probe list'
  $lst = Find-ByFolder $ListFolder
  if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
  $tag = 'R29' + [guid]::NewGuid().ToString('N').Substring(0, 8)
  Write-Now 'Adding the command row that starts the health flow'
  $null = Add-PnPListItem -List $ListTitle -Values @{ Title = ('RUN-HEALTH ' + $tag) } -ErrorAction Stop
  Add-Item 'r1-command' 'INFO' ('command row made: RUN-HEALTH, tag ' + $tag + '; the health flow answers within a few minutes (the Read part waits for it)')
}

<#
.SYNOPSIS
  Read, test HEALTH: the flow "90161Z T21 Probe Health r6" of the solution "90-161.Z flows" ran on the solution's
  SharePoint connection: it writes one RESULT row after the newest command row (r7: it no longer lists flows, because the
  Power Automate Management connector is not in the solution).
.PARAMETER Rows
  The probe list rows (from Get-ListRow).
.PARAMETER HealthFloor
  The Id of the newest RUN-HEALTH command row (0 when there is none).
#>
function Add-HealthTest($Rows, [int]$HealthFloor) {
  $name = 'a health flow on the SharePoint connection of the solution='
  $h = $null
  if ($HealthFloor -gt 0) { $h = Find-Result @($Rows | Where-Object { $_.Id -gt $HealthFloor }) 'HEALTH' 'a' }
  if (-not $HealthFloor) { Add-Test 'HEALTH' @($name + 'FAIL (no command row: run the health step first)') $false }
  elseif (-not $h) {
    $why = 'no result row after the wait: the flow did not run; check that "90161Z T21 Probe Health r6" reads On in the solution "90-161.Z flows"'
    Add-Test 'HEALTH' @($name + 'FAIL (' + $why + ')') $false
  } else {
    $d = Format-Detail $h.ProbeDetail
    Add-Test 'HEALTH' @($name + $h.ProbeResult + $(if ($d) { ' (' + $d + ')' } else { '' })) ($h.ProbeResult -eq 'PASS')
  }
}

<#
.SYNOPSIS
  Read, test T4: a person who is a Visitors member writes a row through the list form (list-level Contribute on this list only; the site stays Read).
  Rows by anyone but you count; RESULT rows do not. With no state file and no row by another person the round had no
  second person (R30a: T4 passed in R29a): one NOT RUN line, no RESULT line, not counted.
.PARAMETER Rows
  The probe list rows (from Get-ListRow).
.PARAMETER MeId
  Your own site user number (0 when it cannot be read).
#>
function Add-T4Test($Rows, [int]$MeId) {
  $others = @($Rows | Where-Object { $_.Title -ne 'RESULT' -and $MeId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $MeId })
  $t4a = @($Rows | Where-Object { ([string]$_.Title).Trim() -eq 'T4a' -and $MeId -gt 0 -and (Get-AuthorId $_) -gt 0 -and (Get-AuthorId $_) -ne $MeId })
  $st = Read-State $script:dir
  if (-not $st -and $others.Count -eq 0) { $script:lines.Add('T4 NOT RUN: no second person in this round (T4 passed in R29a)'); return }
  # R35 (19 Nov 26): a second person was added for EDITALL only, and no step asked for a new row, so T4 read FAIL. T4 counts only
  # when the round asked (T4Asked=yes in the state file) or a row by another person is there.
  if ($others.Count -eq 0 -and -not ($st -and $st['T4Asked'] -eq 'yes')) { $script:lines.Add('T4 NOT RUN: this round did not ask the second person to add a row (T4 passed in R29a)'); return }
  $addedText = $(if (-not $st) { 'not tried (no state file)' } elseif ($st['WasMember'] -eq 'yes') { 'already a member' } else { 'yes' })
  $t4pass = ($others.Count -ge 1)
  $counts = '(rows=' + $others.Count + '; T4a rows=' + $t4a.Count + '; person in the Visitors group=' + $addedText + ')'
  $t4 = @('a list form by a second person (Visitors member)=' + $(if ($t4pass) { 'PASS' } else { 'FAIL' }) + ' ' + $counts)
  if (-not $t4pass) {
    $t4 += ('next: the second person opens the new row form link and saves one row; a form that says no permission means the Visitors group' +
      ' does not hold Contribute on this list (the Make part gives it; for the app lists, run T20 r4 and read ITEM W01 to W03)') }
  Add-Test 'T4' $t4 $t4pass
}

<#
.SYNOPSIS
  Read, test EDITALL (F2 B, PFM 19 Nov 26): the second person, as a PFM Office member, saved the EDITALL row that you wrote
  on the probe list, which is set to "edit own rows". With no office state file and no EDITALL row the round had no
  Office part: one NOT RUN line, no RESULT line, not counted.
.PARAMETER Rows
  The probe list rows (from Get-ListRow, with Author and Editor).
.PARAMETER MeId
  Your own site user number (0 when it cannot be read).
#>
function Add-EditAllTest($Rows, [int]$MeId) {
  $mine = @($Rows | Where-Object { ([string]$_.Title) -like 'EDITALL *' -and $MeId -gt 0 -and (Get-AuthorId $_) -eq $MeId })
  $st = Read-OfficeState; $ids = @(); if ($st) { $ids = @($st.UserIds) }   # the people the part Office added (module office)
  if (-not $ids.Count -and -not $mine.Count) { $script:lines.Add('EDITALL NOT RUN: no PFM Office test in this round'); return }
  $byOther = @($mine | Where-Object { $e = Get-EditorId $_; $e -gt 0 -and $e -ne $MeId -and (-not $ids.Count -or $ids -contains $e) })
  $pass = ($byOther.Count -ge 1)
  $counts = ' (EDITALL rows by you=' + $mine.Count + '; saved by the second person=' + $byOther.Count + ')'
  $piece = @('a PFM Office member who is not the author edits the row=' + $(if ($pass) { 'PASS' } else { 'FAIL' }) + $counts)
  if (-not $pass) { $piece += 'next: the second person opens the edit form link, changes the row and saves it; a form that will not save means the level did not give the right' }
  Add-Test 'EDITALL' $piece $pass
}

<#
.SYNOPSIS
  The part Read: waits for the health flow's row (only when there is a command row), then one test line each for
  HEALTH, T4, EDITALL and BUTTON (counts only).
#>
function Invoke-ReadPart {
  Write-Now 'Reading the rows of the probe list'
  $lst = Find-ByFolder $ListFolder
  if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
  $rf = @('Title', 'ProbeTest', 'ProbeWay', 'ProbeResult', 'ProbeDetail', 'Author', 'Editor')
  $rows = @(Get-ListRow $ListTitle $rf)
  # The health flow answers a minute or more after its command row. Wait for it (default 4 minutes) only when there is one.
  $healthFloor = [int](@($rows | Where-Object { $_.Title -like 'RUN-HEALTH *' } | ForEach-Object { $_.Id }) + 0 | Measure-Object -Maximum).Maximum
  if ($healthFloor -gt 0) {
    Write-Now ('Waiting for the health flow''s result row (up to ' + $WaitMinutes + ' minutes)')
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
  Add-EditAllTest $rows $meId
  # BUTTON: the button flow "90161Z T21 Probe Button r6", started by the view button, wrote one row titled BTN-FLOW.
  $btn = @($rows | Where-Object { ([string]$_.Title).Trim() -like 'BTN-FLOW*' })
  Add-Test 'BUTTON' @('b a view button starts a flow=' + $(if ($btn.Count) { 'PASS' } else { 'FAIL' }) + ' (rows titled BTN-FLOW=' + $btn.Count + ')') ($btn.Count -ge 1)
  $script:lines.Add('NOTE FORM and VIEW: what the screen showed is left to the answers you give in the RADE window (this script does not read them)')
}
