<#
.SYNOPSIS
  90-161.Z Task 21 probe r13, module "common": the helpers every part of the probe uses.
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r13.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values the main file sets in its own scope ($site, $dir, $lines, $passed, $failed, $WaitMinutes, $pollEvery,
  $StateName). Outputs: functions for the SharePoint REST calls, the result lines, the NOW lines, the wait loop, the
  second person's saved numbers and the sign-in.
  Network: the one SharePoint site of the main file ($site), through the PnP.PowerShell connection.
  Writes: none on the site by itself (Invoke-Rest sends what a part asks for); the result lines in memory.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-ProbeSite); nothing is stored.
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r13.ps1 -Part <part> loads it.
#>

<#
.SYNOPSIS
  Sends one SharePoint REST request through the signed-in PnP connection (the same call T20 uses).
.PARAMETER Method
  Get, Post or Merge.
.PARAMETER Uri
  The address after the site, for example _api/web/lists.
.PARAMETER Body
  The JSON body for Post and Merge (verbose form); empty for Get.
.OUTPUTS
  System.String. The raw answer text.
#>
function Invoke-Rest([string]$Method, [string]$Uri, [string]$Body) {
  $url = $script:site.TrimEnd('/') + '/' + $Uri
  if ($Method -eq 'Get') { return [string](Invoke-PnPSPRestMethod -Method Get -Url $url -Raw -ErrorAction Stop) }
  return [string](Invoke-PnPSPRestMethod -Method $Method -Url $url -Content $Body -ContentType 'application/json;odata=verbose' -Raw -ErrorAction Stop)
}
# Reads a REST collection and returns its "value" items as an array.
function Get-RestValue([string]$Uri) { return @(((Invoke-Rest 'Get' $Uri '') | ConvertFrom-Json).value) }
function Get-SiteList {
  # Every list on the site that is not hidden, with the folder name it was made under (the folder name never changes).
  $select = '$select=Id,Title,ItemCount,BaseTemplate,Hidden,EnableAttachments,HasUniqueRoleAssignments,RootFolder/Name'
  return @(Get-RestValue ('_api/web/lists?' + $select + '&$expand=RootFolder&$top=1000') | Where-Object { -not $_.Hidden })
}
# Finds a list or library by the folder name it was made under; returns it, or $null.
function Find-ByFolder([string]$Folder) {
  foreach ($l in (Get-SiteList)) { if ([string]$l.RootFolder.Name -eq $Folder) { return $l } }
  return $null
}
# Prints one "NOW <text>" line before an action that takes time (the RADE window shows it as it happens). It goes to the
# screen only: it is not a result line, so it is not added to the result lines or the result file and is not counted.
function Write-Now([string]$Text) { Write-Host ('NOW ' + $Text) }
# Adds one "ITEM <name> <status> <text>" line and counts a PASS or a FAIL.
function Add-Item([string]$Name, [string]$Status, [string]$Text) {
  $script:lines.Add('ITEM ' + $Name + ' ' + $Status + $(if ($Text) { ' ' + $Text } else { '' }))
  if ($Status -eq 'PASS') { $script:passed++ } elseif ($Status -eq 'FAIL') { $script:failed++ }
}
function Add-Test([string]$Name, [string[]]$Piece, [bool]$Pass) {
  # One summary line per test: "T4 PASSED: a ...; next ...".
  $script:lines.Add($Name + ' ' + $(if ($Pass) { 'PASSED' } else { 'FAILED' }) + ': ' + ($Piece -join '; '))
  # The runner counts a line as passed or failed only by the separate word PASS or FAIL (R28 finding 7: this part read PASSED
  # while its 3 tests failed), so each test also gets one RESULT line.
  $script:lines.Add('RESULT ' + $Name + ' ' + $(if ($Pass) { 'PASS' } else { 'FAIL' }))
  if ($Pass) { $script:passed++ } else { $script:failed++ }
}
function Format-Detail([string]$Text) {
  # The flow's ProbeDetail (or an error text) for a line: one line, anything that looks like an address or a link masked, cut to 160.
  $t = ($Text -replace '\s+', ' ').Trim()
  $t = $t -replace '[^\s"<>|,;()\[\]]+@[^\s"<>|,;()\[\]]+', '<MASKED>'
  $t = $t -replace '[^\s"<>|,;()\[\]]+%40[^\s"<>|,;()\[\]]+', '<MASKED>'
  $t = $t -replace 'https?://\S+', '<MASKED>'
  if ($t.Length -gt 160) { $t = $t.Substring(0, 160) }
  return $t
}
function Get-ListRow([string]$Title, [string[]]$Fields) {
  # Plain rows (Id and the named fields as text); only counts and flags are written from them.
  $rows = @(Get-PnPListItem -List $Title -Fields $Fields -PageSize 500 -ErrorAction Stop)
  return @($rows | ForEach-Object {
    $o = @{ Id = [int]$_.Id; Item = $_ }
    foreach ($f in $Fields) { $o[$f] = [string]$_[$f] }
    $o
  })
}
function Find-Result($Rows, [string]$Test, [string]$Way) {
  # The newest RESULT row for a test and way, or $null.
  $hit = @($Rows | Where-Object { $_.Title -eq 'RESULT' -and $_.ProbeTest -eq $Test -and $_.ProbeWay -eq $Way } | Sort-Object { $_.Id } -Descending)
  if ($hit.Count) { return $hit[0] }
  return $null
}

<#
.SYNOPSIS
  Checks every $pollEvery seconds for up to $WaitMinutes (both set by the main file); a NOW line a minute.
.DESCRIPTION
  A failed check is retried; 3 failures in a row stop the part (the error goes to the caller). This one differs from the
  shared Wait-Until of T18 and T24 (scripts/gov/src/wait-common.ps1): it takes its poll time from -PollSeconds, so the tests
  can wait 1 second, and it prints one NOW line a minute.
.PARAMETER Done
  The check: a script block that returns $true when the wait is over.
.PARAMETER What
  What is waited for, for the progress line.
.OUTPUTS
  System.Boolean. $true when the check passed in time, $false when the time ran out.
#>
function Wait-Until([scriptblock]$Done, [string]$What) {
  $start = Get-Date
  $end = $start.AddMinutes($WaitMinutes)
  $misses = 0; $nextNote = $start.AddMinutes(1)
  while ($true) {
    $isDone = $false
    try { $isDone = [bool](& $Done); $misses = 0 }
    catch {
      $misses++
      if ($misses -ge 3) { throw }
      Write-Now ('Checking again (a check failed, ' + $misses + ' of 3 allowed in a row)')
    }
    if ($isDone) { return $true }
    $now = Get-Date
    if ($now -ge $end) { return $false }
    if ($now -ge $nextNote) {
      Write-Now ('Waiting for ' + $What + ' (' + [int]($now - $start).TotalMinutes + ' of ' + $WaitMinutes + ' minutes)')
      $nextNote = $nextNote.AddMinutes(1)
    }
    Start-Sleep -Seconds $pollEvery
  }
}
# The site user number of the author of a row, or 0 when the row has none.
function Get-AuthorId($Row) { $a = $Row.Item['Author']; if ($a -and $a.LookupId) { return [int]$a.LookupId }; return 0 }
# The site user number of the person who saved a row last (Modified By), or 0 when the row has none.
function Get-EditorId($Row) { $a = $Row.Item['Editor']; if ($a -and $a.LookupId) { return [int]$a.LookupId }; return 0 }
# The site user numbers of the members of one site group.
function Get-GroupMemberId([int]$GroupId) {
  return @(Get-RestValue ('_api/web/sitegroups/getbyid(' + $GroupId + ')/users?$select=Id&$top=5000') | ForEach-Object { [int]$_.Id })
}
# The Id of the site's associated Visitors group, or 0 when the site has none or it cannot be read.
function Get-VisitorGroupId {
  try { return [int]((Invoke-Rest 'Get' '_api/web/associatedvisitorgroup?$select=Id' '') | ConvertFrom-Json).Id } catch { return 0 }
}
function Read-State([string]$Dir) {
  # The saved numbers of the second person (site user Id, group Id, whether the person was a member before): no address, no name.
  $f = Join-Path $Dir $StateName
  if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { return $null }
  $h = @{}
  foreach ($l in @(Get-Content -LiteralPath $f)) { if ([string]$l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() } }
  if ($h['UserId'] -notmatch '^\d+$') { return $null }
  return $h
}
<#
.SYNOPSIS
  Loads PnP.PowerShell, signs in to the site with the web login (CAC) and reads the lists once, so the REST route is
  proved by a read before anything is written. Adds the lines ROUTE and ITEM a-rest-read.
#>
function Connect-ProbeSite {
  Write-Now 'Loading PnP.PowerShell'
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Now 'Signing in to the site (if a sign-in window opens, sign in with your CAC)'
  if (Get-Command Set-SignInDpiAware -ErrorAction SilentlyContinue) { $null = Set-SignInDpiAware }   # R46: the sign-in window at its real size (RADE engine-v46 block)
  $null = & { Connect-PnPOnline -Url $script:site -UseWebLogin -ErrorAction Stop } *>&1
  $script:lines.Add('ROUTE web-login PASS')
  Write-Now 'Reading the lists of the site'
  $siteLists = Get-SiteList
  $script:lines.Add('ITEM a-rest-read INFO lists read from the site=' + $siteLists.Count)
}
