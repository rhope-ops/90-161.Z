<#
.SYNOPSIS
  90-161.Z Task 19 list update r2 (R21, PFM 14 Nov 26: hold, cancel and coordination rounds; r2 R22). Windows PowerShell 5.1,
  the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: adds the R21 columns to the lists that T02 r11 made on the test site, so F03 r4, F05 r2 and F06 r1 can
  use them. T02 r12 builds a new site with them already; this task updates an existing one. About 2 minutes (an estimate).
  WHAT IT CHANGES ON THE SITE (adds only; nothing is removed or renamed):
    1. PFM Publications: adds the columns Status Reason (multiple lines of text) and Held Since (date only).
    2. PFM Publications: adds the choices Cancelled and Complete to Action Status (the old choices stay).
    3. PFM Endorsements: adds the column Coordination Round (whole number).
    4. PFM Settings: sets CoordinationSuspenseBusinessDays to 20 (PFM 14 Nov 26: 20 working days).
  A column or choice that is already there is left as it is (PASS present), so a second run changes nothing.
  Counts and column names only: no names or addresses are written. The site address stays in Config\90161Z-site.txt on
  this computer; every output line shows it as <SITE> and the DODID as <DODID>.
  r2 (R22, R21 finding 1): r1 read the Action Status choices from the Choices property, which Get-PnPField does not fill in
  PnP.PowerShell 1.12.0 (all 5 read as missing, and Set-PnPField -Values Choices had no effect). r2 reads the choices from
  the field's SchemaXml and writes them through CSOM (FieldChoice.Choices, Update, ExecuteQuery).
  Output: 90161Z-T19-list-update-r2.txt in the T19 folder (send it).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -NoPause.
#>
param([string]$Id, [switch]$NoPause)
$task = 'T19'

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

function Get-SiteAddress([string]$ConfigDir) {
  # Kept only on this computer (the repo is public). Asked every run, filled in with the last address (r2: new site).
  $f = Join-Path $ConfigDir '90161Z-site.txt'
  $last = 'https://'
  if (Test-Path -LiteralPath $f -PathType Leaf) { $v = ([string](Get-Content -LiteralPath $f -TotalCount 1)).Trim(); if ($v) { $last = $v } }
  Add-Type -AssemblyName Microsoft.VisualBasic
  $v = [string][Microsoft.VisualBasic.Interaction]::InputBox('Address of the test SharePoint site (starts with https://). It is kept only on this computer.', '90-161.Z Task 19', $last)
  $v = $v.Trim()
  if ($v -notmatch '^https://[^/]+/sites/[^/]+') { throw 'SITE ADDRESS not given or not a site address (https://<host>/sites/<name>). Run again.' }
  if (-not (Test-Path -LiteralPath $ConfigDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $ConfigDir -Force) }
  Set-Content -LiteralPath $f -Value $v -Encoding UTF8
  return $v
}
function Hide-Site([string]$Text, [string]$Site) {
  # The result is e-mailed: no site, tenant or sign-in address may stay in it (review R09 T16; the same rule in T18).
  $Text = $Text -replace '[\w.+-]+@[\w.-]+', '<EMAIL>'
  $Text = $Text -replace '[\w.+-]+%40[\w.-]+', '<EMAIL>'   # URL-encoded form (a probe request address, review R15 MAJOR)   # whole address first: the host rules below keep the name part (review R12 MAJOR)
  if ($Site) {
    $Text = $Text -replace [regex]::Escape($Site.TrimEnd('/')), '<SITE>'
    try {
      $u = [uri]$Site
      $Text = $Text -replace [regex]::Escape($u.Host), '<SITE-HOST>'
      $path = $u.AbsolutePath.TrimEnd('/')   # /sites/<name>: also in server-relative and URL-encoded form
      if ($path.Length -gt 1) {
        $Text = $Text -replace [regex]::Escape($path), '<SITE-PATH>'
        $Text = $Text -replace [regex]::Escape([uri]::EscapeDataString($path)), '<SITE-PATH>'
        $leaf = ($path -split '/')[-1]
        if ($leaf.Length -ge 3) { $Text = $Text -replace ('\b' + [regex]::Escape($leaf) + '\b'), '<SITE-NAME>' }
      }
      $tenant = ($u.Host -split '\.')[0]
      if ($tenant.Length -ge 3) { $Text = $Text -replace ('\b' + [regex]::Escape($tenant) + '\b'), '<TENANT>' }
    } catch { $null = $_ }
  }
  $Text = $Text -replace 'https?://\S+', '<URL>'
  $Text = $Text -replace '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>'
  $Text = $Text -replace '\b[\w.-]+\.mil\b', '<HOST>'
  $Text = $Text -replace '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b', '<GUID>'
  return $Text
}




# The column XML is the T02 r12 provisioning XML (scripts/build_flow_payload.py field_xml from schemas/lists);
# tests/run.sh checks that each line below still matches it.
$addFields = @(
  @{ List = 'PFM Publications'; Name = 'StatusReason'; Xml = '<Field Name="StatusReason" StaticName="StatusReason" DisplayName="Status Reason" Required="FALSE" Type="Note" NumLines="6"></Field>' },
  @{ List = 'PFM Publications'; Name = 'HeldSince'; Xml = '<Field Name="HeldSince" StaticName="HeldSince" DisplayName="Held Since" Required="FALSE" Type="DateTime" Format="DateOnly"></Field>' },
  @{ List = 'PFM Endorsements'; Name = 'CoordinationRound'; Xml = '<Field Name="CoordinationRound" StaticName="CoordinationRound" DisplayName="Coordination Round" Required="FALSE" Type="Number" Decimals="0"></Field>' }
)
$statusChoices = @('On Track', 'On Hold', 'Stalled', 'Cancelled', 'Complete')

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  $dir = Get-TaskDir $id $task 'Task 19' -Create
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $lines.Add('TASK T19 list update r2, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Write-Host 'Connecting to the site. If a sign-in window opens, sign in with your CAC.'
  $null = & { Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
  $n = 0
  foreach ($f in $addFields) {
    $n++
    $have = $null
    try { $have = Get-PnPField -List $f.List -Identity $f.Name -ErrorAction Stop } catch { $have = $null }
    if ($have) { $lines.Add('ITEM ' + $n + '-' + $f.Name + ' PASS present in ' + $f.List) }
    else {
      $null = Add-PnPFieldFromXml -List $f.List -FieldXml $f.Xml -ErrorAction Stop
      $null = Get-PnPField -List $f.List -Identity $f.Name -ErrorAction Stop
      $lines.Add('ITEM ' + $n + '-' + $f.Name + ' PASS added to ' + $f.List)
    }
  }
  # r2: the choices come from SchemaXml (CHOICES/CHOICE), not from .Choices (empty on the base Field object in PnP 1.12.0).
  $readChoices = { @(([xml](Get-PnPField -List 'PFM Publications' -Identity 'ActionStatus' -ErrorAction Stop).SchemaXml).SelectNodes('//CHOICES/CHOICE') | ForEach-Object { $_.InnerText }) }
  $have = @(& $readChoices)
  $missing = @($statusChoices | Where-Object { $have -notcontains $_ })
  if ($missing.Count) {
    $all = [string[]](@($have) + $missing)
    $ctx = Get-PnPContext
    $field = Get-PnPField -List 'PFM Publications' -Identity 'ActionStatus' -ErrorAction Stop
    $choiceField = $ctx.GetType().GetMethod('CastTo').MakeGenericMethod([Microsoft.SharePoint.Client.FieldChoice]).Invoke($ctx, @($field))
    $choiceField.Choices = $all
    $choiceField.Update()
    $ctx.ExecuteQuery()
    $after = @(& $readChoices)
    $still = @($statusChoices | Where-Object { $after -notcontains $_ })
    $lines.Add('ITEM 4-ActionStatus ' + $(if ($still.Count) { 'FAIL still missing: ' + ($still -join ', ') } else { 'PASS added choices: ' + ($missing -join ', ') + ' (choices now ' + $after.Count + ')' }))
  } else { $lines.Add('ITEM 4-ActionStatus PASS present, choices=' + $have.Count) }
  $row = @(Get-PnPListItem -List 'PFM Settings' -Fields 'Title', 'SettingValue' -ErrorAction Stop | Where-Object { [string]$_['Title'] -eq 'CoordinationSuspenseBusinessDays' })
  if (-not $row.Count) { $lines.Add('ITEM 5-suspense-setting FAIL no CoordinationSuspenseBusinessDays row in PFM Settings') }
  elseif ([string]$row[0]['SettingValue'] -eq '20') { $lines.Add('ITEM 5-suspense-setting PASS present, 20') }
  else {
    $null = Set-PnPListItem -List 'PFM Settings' -Identity $row[0].Id -Values @{ SettingValue = '20'; SettingNotes = 'Working days (weekdays) a coordinator gets to respond (DAFMAN 90-161 5.2; PFM 2026-11-14: 20 working days, no holiday list). F03 sets it; Guard and Reserve Applicability get at least 30 calendar days.' } -ErrorAction Stop
    $lines.Add('ITEM 5-suspense-setting PASS set to 20 (was ' + [string]$row[0]['SettingValue'] + ')')
  }
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  $nf = @($lines | Where-Object { $_ -match '^ITEM .* FAIL' }).Count
  $lines.Add('LISTUPDATE done, items with problems=' + $nf)
} catch {
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)))
} finally {
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir '90161Z-T19-list-update-r2.txt') -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
  if (@($masked | Where-Object { $_ -match '^STOPPED|^ITEM .* FAIL' }).Count) { exit 1 }
}
