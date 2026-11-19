<#
.SYNOPSIS
  90-161.Z Task 19 list update r4 (round R34; PFM 19 Nov 26, S3 A: the tier T-0). Windows PowerShell 5.1, the installed
  PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: brings the lists of a site that exists up to the list schemas (schemas/lists) where T20 cannot: T20 skips
  a column that is there, so a new choice of an existing column comes from this task. About 2 minutes (an estimate).
  WHAT IT CHANGES ON THE SITE (adds only; nothing is removed or renamed):
    1. PFM Publications: adds the columns Status Reason (multiple lines of text) and Held Since (date only); PFM
       Endorsements: adds the column Coordination Round (whole number) (R21, PFM 14 Nov 26).
    2. PFM Publications: adds the choices Cancelled and Complete to Action Status (R21).
    3. PFM Waivers: adds the choice T-0 to Tier (r4; PFM S3 A, 19 Nov 26: the tier of DAFMAN 90-161 Attachment 10,
       Table A10.1, that the waiver rule 4.4A names).
    4. PFM Settings: sets CoordinationSuspenseBusinessDays to 20 (PFM 14 Nov 26: 20 working days; DAFMAN 90-161 5.2).
  A column, choice or value that is there already is left as it is (PASS present), so a second run changes nothing. The
  choices are written in the order of the schema; a choice that a person added stays, after them.
  Modes:
    -PlanOnly  No sign-in, no network. One PLAN line per item, then the counts.
    -Check     Signs in and READS only: one line per item, present or what a run would add. Result:
               90161Z-T19-list-check-r4.txt.
    (none)     Adds what is missing and reads each change back. Result: 90161Z-T19-list-update-r4.txt.
  Before each action that takes time the script prints one "NOW <what it does>" line for the RADE window; a NOW line is
  not a result line, is not in the result file and is not counted.
  r2 (R22, R21 finding 1): Get-PnPField does not fill in the Choices property in PnP.PowerShell 1.12.0, and Set-PnPField
  -Values Choices had no effect; so the choices are read from the column's SchemaXml and written through CSOM
  (FieldChoice.Choices, Update, ExecuteQuery).
  Counts and column names only: no names or addresses are written. Every output line shows the site as <SITE> and the
  DODID as <DODID>.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell (none
           with -PlanOnly).
  Writes: (no mode) the columns, choices and the setting listed above on that site; on this computer the result file in
          the T19 folder and, once, Config\90161Z-site.txt when the site address is typed outside RADE. -Check and
          -PlanOnly change nothing on the site.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File 90161Z-T19-list-update-r4.ps1 (RADE does this).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -NoPause, -Check, -PlanOnly. -TestDir is
  for the tests (tests/ps/Test-T20.ps1).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER Check
  Read only: report what a run would add.
.PARAMETER PlanOnly
  No sign-in: print the items this task checks.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T19 folder.
#>
param([string]$Id, [switch]$NoPause, [switch]$Check, [switch]$PlanOnly, [string]$TestDir)
$task = 'T19'
$Rev = 'r4'

# >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)
function ConvertTo-Masked([string]$Text, [string[]]$Secret) {
  foreach ($x in $Secret) { $Text = $Text -replace [regex]::Escape($x), '<DODID>' }
  return $Text
}

function Get-TaskId([string]$Id) {
  # Returns @{ Id; Leaf (profile folder name); Secret (longest first, so a longer name is masked before a shorter one inside it) }.
  $leaf = ''
  if ($env:USERPROFILE) { $leaf = Split-Path -Leaf $env:USERPROFILE }
  $value = ([string]$Id).Trim()
  # No DODID question (PFM 13 Nov 26): the Windows profile folder name is used when -Id is not given.
  if (-not $value) { $value = $leaf }
  if ($value -notmatch '^[A-Za-z0-9._-]{4,}$') { throw 'DODID not valid: use the folder name under C:\Users (4 or more letters, digits, dot, dash or underscore).' }
  $secret = @(@($value, $leaf, $env:USERNAME) |
    Where-Object { $_ -and $_.Length -ge 4 } | Sort-Object -Unique | Sort-Object Length -Descending)
  return @{ Id = $value; Leaf = $leaf; Secret = $secret }
}

function Get-TaskDir([string]$Id, [string]$Task, [string]$Label, [switch]$Create) {
  # The task folder C:\Users\<DODID>\OneDrive - United States Air Force\RADE\90-161.Z\<Task> (PFM 14 Nov 26: RADE holds
  # the app folder). Until RADE has moved the old folder ...\90-161.Z, that one is used. -Create makes it when missing.
  $od = Join-Path (Join-Path 'C:\Users' $Id) 'OneDrive - United States Air Force'
  $app = 'RADE\90-161.Z'
  if (-not (Test-Path -LiteralPath (Join-Path $od $app) -PathType Container) -and (Test-Path -LiteralPath (Join-Path $od '90-161.Z') -PathType Container)) { $app = '90-161.Z' }
  $tail = 'OneDrive - United States Air Force\' + $app + '\' + $Task
  $dir = Join-Path (Join-Path 'C:\Users' $Id) $tail
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    if ($Create) { New-Item -ItemType Directory -Path $dir | Out-Null }
    else { throw ('FOLDER not found: C:\Users\<DODID>\' + $tail + '. Create it, save the ' + $Label + ' files into it, then run again.') }
  }
  return $dir
}

function Assert-TaskFile([string]$Dir, [string[]]$Name, [string]$Message) {
  # Throws $Message + the missing names when a file in $Name is not in $Dir.
  $missing = @($Name | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Dir $_) -PathType Leaf) })
  if ($missing.Count -gt 0) { throw ($Message + ($missing -join ', ')) }
}

function Unblock-TaskScript([string]$Dir) {
  # Files pasted into Notepad and saved locally need no unblock; a failed unblock is not an error here.
  Get-ChildItem -LiteralPath $Dir -Filter *.ps1 | ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
}

function Invoke-TaskStep([hashtable]$Step, [string]$ScriptDir, [string[]]$Secret, $Lines, [string]$Log) {
  # Runs $Step.File from $ScriptDir in a child powershell.exe with $Step.Args, masks and records its output and exit
  # code in $Lines, and saves $Lines to $Log after the step.
  Write-Host ('STEP ' + $Step.Name + ' running (Word steps can take a few minutes; do not close this window)...')
  $Lines.Add('STEP ' + $Step.Name)
  $stepArgs = $Step.Args
  $global:LASTEXITCODE = $null
  # PS 5.1: with Stop, a stderr line from the step (2>&1) would end the runner. Record it instead.
  $ErrorActionPreference = 'Continue'
  $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir $Step.File) @stepArgs 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  foreach ($o in @($out | Where-Object { $null -ne $_ })) {
    $masked = ConvertTo-Masked ([string]$o) $Secret
    $Lines.Add($masked)
    Write-Host $masked
  }
  $Lines.Add('STEP ' + $Step.Name + ' exit=' + $code)
  Write-Host ('STEP ' + $Step.Name + ' exit=' + $code)
  Set-Content -LiteralPath $Log -Value $Lines -Encoding UTF8
}
# <<< task-common
# >>> site-common: generated from scripts/gov/src/site-common.ps1 by scripts/build_task_scripts.py (do not edit)
function Get-SiteAddress([string]$ConfigDir) {
  # One entry (PFM 15 Nov 26): the address RADE holds (RADE_SITE, from its "Site address" box) is used with no question;
  # outside RADE the one saved in Config\90161Z-site.txt is used. Only when neither exists does a question open (once).
  # To change the site, use "Change the site address" in RADE. Kept only on this computer (the repo is public).
  $ok = '^https://[^/\s]+/sites/[^/\s]+'
  $v = ([string]$env:RADE_SITE).Trim()
  if ($v -match $ok) { return $v }
  $f = Join-Path $ConfigDir '90161Z-site.txt'
  if (Test-Path -LiteralPath $f -PathType Leaf) { $v = ([string](Get-Content -LiteralPath $f -TotalCount 1)).Trim(); if ($v -match $ok) { return $v } }
  # RADE runs a step with no window, so a question there would wait unseen: stop with the fix instead.
  if ($env:RADE_CONTRACT) { throw 'SITE ADDRESS not set. Complete the "Site address" box in RADE, then run this step again.' }
  $v = ([string](Read-Host 'Site address (it starts with https://; it is kept only on this computer), then press Enter')).Trim()
  if ($v -notmatch $ok) { throw 'SITE ADDRESS not given or not a site address (https://<host>/sites/<name>). Run again.' }
  if (-not (Test-Path -LiteralPath $ConfigDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $ConfigDir -Force) }
  Set-Content -LiteralPath $f -Value $v -Encoding UTF8
  return $v
}

function Hide-Site([string]$Text, [string]$Site) {
  <#
  .SYNOPSIS
  Masks e-mail addresses, the site, its host, path, name and tenant, other URLs, cloud and .mil hosts and GUIDs in a result text. Not masked: display names, office symbols, phone numbers, user ids, computer names.
  .PARAMETER Text
  The text to clean (a result line or an error message).
  .PARAMETER Site
  The site address (https://<host>/sites/<name>), or an empty text for the generic rules only.
  .OUTPUTS
  System.String. The text with each match replaced by a placeholder such as <EMAIL>, <SITE> or <GUID>.
  #>
  $Text = $Text -replace '[^\s"<>|,;()\[\]]+(@|%40)[^\s"<>|,;()\[\]]+', '<EMAIL>'   # whole address first: the host rules below would keep its name part
  if ($Site) {
    $Text = $Text -replace [regex]::Escape($Site.TrimEnd('/')), '<SITE>'
    try {
      $u = [uri]$Site; $p = $u.AbsolutePath.TrimEnd('/'); $leaf = ($p -split '/')[-1]   # $p is /sites/<name>: also in URL-encoded form
      $set = @(, @($u.Host, '<SITE-HOST>', ''))   # literal text, placeholder, word boundary (tenant and site name only, 3+ letters)
      if ($p.Length -gt 1) { $set += @($p, '<SITE-PATH>', ''), @([uri]::EscapeDataString($p), '<SITE-PATH>', ''), @($leaf, '<SITE-NAME>', '\b') }
      $set += , @(($u.Host -split '\.')[0], '<TENANT>', '\b')
      foreach ($s in $set) { if ($s[2] -eq '' -or $s[0].Length -ge 3) { $Text = $Text -replace ($s[2] + [regex]::Escape($s[0]) + $s[2]), $s[1] } }
    } catch { $null = $_ }
  }
  $g = @('https?://\S+', '<URL>', '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>', '\b[\w.-]+\.mil\b', '<HOST>', '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>')   # the GUID has no \b: guid%27<id> must be masked too
  for ($i = 0; $i -lt $g.Count; $i += 2) { $Text = $Text -replace $g[$i], $g[$i + 1] }
  return $Text
}
# <<< site-common

# ---- What the task checks. Each value comes from schemas/lists; tests/run.sh and tests/ps/Test-T20.ps1 check that they match ----
# The column XML is the provisioning XML (scripts/build_flow_payload.py field_xml from schemas/lists).
$AddFields = @(
  @{ List = 'PFM Publications'; Name = 'StatusReason'
    Xml = '<Field Name="StatusReason" StaticName="StatusReason" DisplayName="Status Reason" Required="FALSE" Type="Note" NumLines="6"></Field>' },
  @{ List = 'PFM Publications'; Name = 'HeldSince'
    Xml = '<Field Name="HeldSince" StaticName="HeldSince" DisplayName="Held Since" Required="FALSE" Type="DateTime" Format="DateOnly"></Field>' },
  @{ List = 'PFM Endorsements'; Name = 'CoordinationRound'
    Xml = '<Field Name="CoordinationRound" StaticName="CoordinationRound" DisplayName="Coordination Round" Required="FALSE" Type="Number" Decimals="0"></Field>' }
)
# The choices of a Choice column, in the order of the schema. Tier: T-0 added (PFM S3 A, 19 Nov 26; DAFMAN 90-161 Table A10.1).
$AddChoices = @(
  @{ List = 'PFM Publications'; Field = 'ActionStatus'; Choices = @('On Track', 'On Hold', 'Stalled', 'Cancelled', 'Complete') },
  @{ List = 'PFM Waivers'; Field = 'Tier'; Choices = @('T-0', 'T-1', 'T-2', 'T-3', 'Non-Tiered') }
)
# One PFM Settings row: the seed row of schemas/lists/PFMSettings.json (DAFMAN 90-161 5.2; PFM 14 Nov 26: 20 working days).
$SetRow = @{ List = 'PFM Settings'; Title = 'CoordinationSuspenseBusinessDays'; Value = '20'
  Notes = ('Working days (weekdays) a coordinator gets to respond (DAFMAN 90-161 5.2; PFM 2026-11-14: 20 working days, no holiday list). ' +
    'F03 reads it each run (an empty or missing row means 20); Guard and Reserve Applicability get at least 30 calendar days.') }

# Prints one "NOW <text>" line before an action that takes time. It goes to the screen only: it is not a result line, so it
# is not in the result file and is not counted.
function Write-Now([string]$Text) { Write-Host ('NOW ' + $Text) }

# Adds one result line "ITEM <name> <status> <text>".
function Add-Item([string]$Name, [string]$Status, [string]$Text) { $script:lines.Add('ITEM ' + $Name + ' ' + $Status + ' ' + $Text) }

# Reads the choices of a Choice column from its SchemaXml (r2: the Choices property is empty in PnP.PowerShell 1.12.0).
function Get-FieldChoice([string]$List, [string]$Field) {
  return @(([xml](Get-PnPField -List $List -Identity $Field -ErrorAction Stop).SchemaXml).SelectNodes('//CHOICES/CHOICE') | ForEach-Object { $_.InnerText })
}

# Writes the whole choice list of a Choice column through CSOM (FieldChoice.Choices, Update, ExecuteQuery; r2, R21 finding 1).
# The cast gets the .NET column itself (BaseObject), not a PowerShell wrapper around it.
function Write-FieldChoice([string]$List, [string]$Field, [string[]]$All) {
  $ctx = Get-PnPContext
  $plain = Get-PnPField -List $List -Identity $Field -ErrorAction Stop
  $choiceField = $ctx.GetType().GetMethod('CastTo').MakeGenericMethod([Microsoft.SharePoint.Client.FieldChoice]).Invoke($ctx, @($plain.PSObject.BaseObject))
  $choiceField.Choices = $All
  $choiceField.Update()
  $ctx.ExecuteQuery()
}

<#
.SYNOPSIS
  Item 1 to 3: adds a column that is missing from its XML and reads it back; a column that is there is left as it is.
.PARAMETER Item
  One entry of $AddFields (List, Name, Xml).
.PARAMETER No
  The item number for the ITEM line.
.PARAMETER Write
  $true: add a missing column; $false (-Check): only report it.
.OUTPUTS
  System.Int32. 1 when the column was added (or a run would add it), else 0.
#>
function Add-MissingField($Item, [int]$No, [bool]$Write) {
  $tag = [string]$No + '-' + $Item.Name
  $have = $null
  try { $have = Get-PnPField -List $Item.List -Identity $Item.Name -ErrorAction Stop } catch { $have = $null }
  if ($have) { Add-Item $tag 'PASS' ('present in ' + $Item.List); return 0 }
  if (-not $Write) { Add-Item $tag 'INFO' ('a run would add it to ' + $Item.List); return 1 }
  Write-Now ('Adding the column ' + $Item.Name + ' to ' + $Item.List)
  $null = Add-PnPFieldFromXml -List $Item.List -FieldXml $Item.Xml -ErrorAction Stop
  $null = Get-PnPField -List $Item.List -Identity $Item.Name -ErrorAction Stop
  Add-Item $tag 'PASS' ('added to ' + $Item.List)
  return 1
}

<#
.SYNOPSIS
  Items 4 and 5: adds the choices that a Choice column lacks, then reads them back. The schema's choices come first, in
  its order; a choice that a person added stays, after them (nothing is removed).
.PARAMETER Item
  One entry of $AddChoices (List, Field, Choices).
.PARAMETER No
  The item number for the ITEM line.
.PARAMETER Write
  $true: add the missing choices; $false (-Check): only report them.
.OUTPUTS
  System.Int32. 1 when choices were added (or a run would add them), else 0.
#>
function Add-MissingChoice($Item, [int]$No, [bool]$Write) {
  $tag = [string]$No + '-' + $Item.Field
  $have = @(Get-FieldChoice $Item.List $Item.Field)
  $missing = @($Item.Choices | Where-Object { $have -notcontains $_ })
  if (-not $missing.Count) { Add-Item $tag 'PASS' ('present in ' + $Item.List + ', choices=' + $have.Count); return 0 }
  if (-not $Write) { Add-Item $tag 'INFO' ('a run would add the choices ' + ($missing -join ', ') + ' to ' + $Item.List); return 1 }
  Write-Now ('Adding the choices ' + ($missing -join ', ') + ' to ' + $Item.Field + ' in ' + $Item.List)
  $all = [string[]](@($Item.Choices) + @($have | Where-Object { $Item.Choices -notcontains $_ }))
  Write-FieldChoice $Item.List $Item.Field $all
  $after = @(Get-FieldChoice $Item.List $Item.Field)
  $still = @($Item.Choices | Where-Object { $after -notcontains $_ })
  if ($still.Count) { Add-Item $tag 'FAIL' ('still missing: ' + ($still -join ', ')) }
  else { Add-Item $tag 'PASS' ('added choices: ' + ($missing -join ', ') + ' (choices now ' + $after.Count + ')') }
  return 1
}

<#
.SYNOPSIS
  Item 6: sets the value of one PFM Settings row when it differs; a row with the value is left as it is.
.PARAMETER Item
  $SetRow (List, Title, Value, Notes).
.PARAMETER No
  The item number for the ITEM line.
.PARAMETER Write
  $true: set the value; $false (-Check): only report it.
.OUTPUTS
  System.Int32. 1 when the value was set (or a run would set it), else 0.
#>
function Write-SettingValue($Item, [int]$No, [bool]$Write) {
  $tag = [string]$No + '-suspense-setting'
  $row = @(Get-PnPListItem -List $Item.List -Fields 'Title', 'SettingValue' -ErrorAction Stop | Where-Object { [string]$_['Title'] -eq $Item.Title })
  if (-not $row.Count) { Add-Item $tag 'FAIL' ('no ' + $Item.Title + ' row in ' + $Item.List); return 0 }
  $was = [string]$row[0]['SettingValue']
  if ($was -eq $Item.Value) { Add-Item $tag 'PASS' ('present, ' + $was); return 0 }
  if (-not $Write) { Add-Item $tag 'INFO' ('a run would set it to ' + $Item.Value + ' (now ' + $was + ')'); return 1 }
  Write-Now ('Setting ' + $Item.Title + ' to ' + $Item.Value)
  $null = Set-PnPListItem -List $Item.List -Identity $row[0].Id -Values @{ SettingValue = $Item.Value; SettingNotes = $Item.Notes } -ErrorAction Stop
  Add-Item $tag 'PASS' ('set to ' + $Item.Value + ' (was ' + $was + ')')
  return 1
}

# Prints the plan (-PlanOnly): one PLAN line per item, then the counts. No sign-in.
function Write-Plan {
  $n = 0
  foreach ($f in $AddFields) { $n++; Write-Host ('PLAN ' + $n + '-' + $f.Name + ' column in ' + $f.List) }
  foreach ($c in $AddChoices) { $n++; Write-Host ('PLAN ' + $n + '-' + $c.Field + ' choices in ' + $c.List + ': ' + ($c.Choices -join ', ')) }
  $n++; Write-Host ('PLAN ' + $n + '-suspense-setting ' + $SetRow.Title + ' = ' + $SetRow.Value + ' in ' + $SetRow.List)
  Write-Host ('PLAN columns=' + $AddFields.Count + ' choice columns=' + $AddChoices.Count + ' settings=1')
}

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
$resultName = '90161Z-T19-list-update-' + $Rev + '.txt'
if ($Check) { $resultName = '90161Z-T19-list-check-' + $Rev + '.txt' }
try {
  $ErrorActionPreference = 'Stop'
  if ($PlanOnly) { Write-Plan; exit 0 }
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 19' -Create }
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $mode = 'update'; if ($Check) { $mode = 'check (reads only)' }
  $lines.Add('TASK T19 list update ' + $Rev + ', ' + $mode + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  Write-Now 'Loading PnP.PowerShell'
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Now 'Signing in to the site (if a sign-in window opens, sign in with your CAC)'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
  $write = -not $Check
  $n = 0; $changes = 0
  Write-Now 'Reading the columns of the lists'
  foreach ($f in $AddFields) { $n++; $changes += Add-MissingField $f $n $write }
  foreach ($c in $AddChoices) { $n++; $changes += Add-MissingChoice $c $n $write }
  $n++
  Write-Now 'Reading the rows of PFM Settings'
  $changes += Write-SettingValue $SetRow $n $write
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  $nf = @($lines | Where-Object { $_ -cmatch '^ITEM \S+ FAIL\b' }).Count
  if ($Check) { $lines.Add('LISTCHECK done, changes a run would make=' + $changes + ', items with problems=' + $nf) }
  else { $lines.Add('LISTUPDATE done, changes made=' + $changes + ', items with problems=' + $nf) }
} catch {
  if ($PlanOnly) { Write-Host ('PLAN FAILED: ' + [string]$_); exit 2 }
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)) + ' (a run that stopped can be run again: it skips what is there)')
} finally {
  if (-not $PlanOnly) {
    $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
    if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir $resultName) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
    $masked | ForEach-Object { Write-Host $_ }
    if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
    if (@($masked | Where-Object { $_ -cmatch '^STOPPED|^ITEM \S+ FAIL\b' }).Count) { exit 1 }
  }
}
