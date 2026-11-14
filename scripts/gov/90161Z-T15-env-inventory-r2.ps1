<#
.SYNOPSIS
  90-161.Z Task 15 environment inventory, r2. Read-only. Windows PowerShell 5.1, no modules.
.DESCRIPTION
  Records the facts the 90-161.Z package depends on, so other wings' computers can be compared with this one
  (deployable package rule, PFM 12 Nov 26): PowerShell and .NET versions, language mode and execution policy,
  Office app versions from the registry (no Office app is started, so an open Outlook is never closed), classic
  or new Outlook, installed SharePoint modules (names and versions only), OneDrive for work, screen scaling,
  time zone, and whether the hosts the rounds use answer (status only).
  r2 (PFM 14 Nov 26: document more for future projects) adds: every installed module (names and versions), PowerShell 7,
  other tools on the path, more Office and Windows COM apps, WebView2, new Teams, Power BI Desktop, the fonts DAFMAN
  formatting uses, whether Add-Type can compile C#, AppLocker rule counts, smart-card certificate count (count only),
  .NET runtimes, and more hosts (status only). Nothing is started except COM registration lookups; no app opens.
  It changes nothing. It never writes the computer name, user name, paths or addresses: the DODID and profile
  folder are replaced by <DODID>.
  Output: 90161Z-T15-inventory-r2.txt in the T15 folder (send this).
  Parameters (used by the 90-161.Z Deployer): -Id, -NoPause.
#>
param([string]$Id, [switch]$NoPause)
$task = 'T15'
$Hosts = @('raw.githubusercontent.com', 'www.ang.af.mil', 'www.powershellgallery.com', 'login.microsoftonline.us', 'dod-graph.microsoft.us')   # status only

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

function Get-RegValue([string]$Path, [string]$Name) {
  try { return [string](Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return '' }
}
function Get-ProgIdVersion([string]$ProgId) {
  # Word.Application -> CurVer "Word.Application.16" -> "16"; '' when the app is not registered.
  $cur = Get-RegValue ('Registry::HKEY_CLASSES_ROOT\' + $ProgId + '\CurVer') '(default)'
  if (-not $cur) { return 'not found' }
  return ($cur -replace '^.*\.', '')
}
function Test-HostAnswer([string]$HostName) {
  try {
    $rq = [System.Net.WebRequest]::Create('https://' + $HostName + '/')
    $rq.Method = 'HEAD'; $rq.Timeout = 10000; $rq.UseDefaultCredentials = $true
    if ($rq.Proxy) { $rq.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials }
    $rs = $rq.GetResponse(); $code = [int]$rs.StatusCode; $rs.Close(); return ('answers ' + $code)
  } catch [System.Net.WebException] {
    if ($_.Exception.Response) { return ('answers ' + [int]$_.Exception.Response.StatusCode) }
    return ('no answer (' + $_.Exception.Status + ')')
  } catch { return 'no answer' }
}

$secret = @()
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  $dir = Get-TaskDir $id $task 'Task 15' -Create
  Set-Location -LiteralPath $dir
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('TASK T15 environment inventory r2, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $add = { param($k, $v) $lines.Add('ENV ' + $k + '=' + $v) }

  & $add 'powershell' ([string]$PSVersionTable.PSVersion + ' ' + $PSVersionTable.PSEdition)
  & $add 'clr' ([string]$PSVersionTable.CLRVersion)
  & $add 'os' ([string][Environment]::OSVersion.Version + $(if ([Environment]::Is64BitOperatingSystem) { ' 64-bit' } else { ' 32-bit' }))
  & $add 'language-mode' ([string]$ExecutionContext.SessionState.LanguageMode)
  foreach ($p in @(Get-ExecutionPolicy -List)) { & $add ('execution-policy-' + $p.Scope) ([string]$p.ExecutionPolicy) }
  & $add 'dotnet-release' (Get-RegValue 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' 'Release')

  foreach ($app in 'Word', 'Excel', 'PowerPoint', 'Outlook') { & $add ('office-' + $app.ToLowerInvariant()) (Get-ProgIdVersion ($app + '.Application')) }
  $c2r = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
  & $add 'office-build' (Get-RegValue $c2r 'VersionToReport')
  & $add 'office-platform' (Get-RegValue $c2r 'Platform')
  & $add 'office-channel' ((Get-RegValue $c2r 'UpdateChannel') -replace '^.*/', '')
  $newOl = @(Get-AppxPackage -Name 'Microsoft.OutlookForWindows' -ErrorAction SilentlyContinue).Count -gt 0
  & $add 'outlook-new-installed' ([string]$newOl)
  & $add 'outlook-new-switched-on' ((Get-RegValue 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Preferences' 'UseNewOutlook') -replace '^$', 'not set')

  foreach ($m in 'PnP.PowerShell', 'Microsoft.Online.SharePoint.PowerShell', 'ExchangeOnlineManagement', 'PSScriptAnalyzer') {
    $v = @(Get-Module -ListAvailable -Name $m -ErrorAction SilentlyContinue | ForEach-Object { [string]$_.Version } | Sort-Object -Unique)
    & $add ('module-' + $m) $(if ($v.Count) { $v -join ' ' } else { 'not installed' })
  }

  & $add 'onedrive-work' ([string][bool]$env:OneDriveCommercial)
  $od = Join-Path (Join-Path 'C:\Users' $id) 'OneDrive - United States Air Force'
  & $add 'onedrive-folder-standard-name' ([string](Test-Path -LiteralPath $od -PathType Container))
  & $add 'edge' ([string][bool](Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' '(default)'))
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    & $add 'screen' ([string]$b.Width + 'x' + $b.Height)
  } catch { & $add 'screen' 'unknown' }
  & $add 'screen-dpi' ((Get-RegValue 'HKCU:\Control Panel\Desktop\WindowMetrics' 'AppliedDPI') -replace '^$', 'not set')
  & $add 'time-zone' ([string](Get-TimeZone).Id)
  & $add 'culture' ([string](Get-Culture).Name)
  $proxied = $false
  try { $u = [uri]'https://raw.githubusercontent.com/'; $proxied = ([System.Net.WebRequest]::DefaultWebProxy.GetProxy($u) -ne $u) } catch { $null = $_ }
  & $add 'proxy-in-use' ([string]$proxied)
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { $null = $_ }
  foreach ($h in $Hosts) { & $add ('host-' + $h) (Test-HostAnswer $h) }

  # r2 capability inventory: names and versions only, never paths or user data.
  $mods = @(Get-Module -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Name, Version -Unique | ForEach-Object { $_.Name + ' ' + $_.Version })
  & $add 'modules-count' ([string]$mods.Count)
  foreach ($m in $mods) { & $add 'module' $m }
  foreach ($t in 'pwsh', 'git', 'python', 'py', 'node', 'winget', 'code', 'az', 'dotnet', 'cscript', 'curl') {
    $c = Get-Command $t -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    & $add ('tool-' + $t) $(if ($c) { 'present ' + [string]$c.Version } else { 'not found' })
  }
  foreach ($pid_ in 'Access.Application', 'Visio.Application', 'MSProject.Application', 'Publisher.Application', 'OneNote.Application', 'InfoPath.Application', 'Shell.Application', 'Scripting.FileSystemObject', 'MSXML2.XMLHTTP', 'WinHttp.WinHttpRequest.5.1') {
    & $add ('com-' + $pid_) ((Get-ProgIdVersion $pid_) -replace '^$', 'not registered')
  }
  & $add 'webview2' ((Get-RegValue 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' 'pv') -replace '^$', 'not found')
  & $add 'teams-new' ([string](@(Get-AppxPackage -Name 'MSTeams' -ErrorAction SilentlyContinue).Count -gt 0))
  & $add 'power-bi-desktop' ([string](@(Get-AppxPackage -Name '*PowerBIDesktop*' -ErrorAction SilentlyContinue).Count -gt 0 -or [bool](Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Microsoft Power BI Desktop' 'Version')))
  try {
    Add-Type -AssemblyName System.Drawing
    $fonts = @((New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name })
    foreach ($fn in 'Times New Roman', 'Arial', 'Calibri', 'Aptos', 'Courier New', 'Segoe UI') { & $add ('font-' + ($fn -replace ' ', '-')) ([string]($fonts -contains $fn)) }
  } catch { & $add 'fonts' 'unknown' }
  try {
    Add-Type -TypeDefinition 'public static class P90161Z { public static int Two() { return 2; } }' -ErrorAction Stop
    & $add 'add-type-csharp' $(if ([P90161Z]::Two() -eq 2) { 'works' } else { 'wrong result' })
  } catch { & $add 'add-type-csharp' ('blocked ' + ($_.Exception.GetType().Name -replace '(?i)fail', 'fault')) }
  try {
    $al = Get-AppLockerPolicy -Effective -ErrorAction Stop
    foreach ($rc in @($al.RuleCollections)) { & $add ('applocker-' + $rc.RuleCollectionType) ('rules=' + @($rc).Count + ' mode=' + $rc.EnforcementMode) }
    if (-not @($al.RuleCollections).Count) { & $add 'applocker' 'no rules' }
  } catch { & $add 'applocker' ('not readable ' + ($_.Exception.GetType().Name -replace '(?i)fail', 'fault')) }
  try {
    $sc = @(Get-ChildItem Cert:\CurrentUser\My -ErrorAction Stop | Where-Object { $_.HasPrivateKey }).Count
    & $add 'certificates-with-key' ([string]$sc)
  } catch { & $add 'certificates-with-key' 'unknown' }
  $rt = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue
  if ($rt) { foreach ($r in @(& dotnet --list-runtimes 2>$null)) { & $add 'dotnet-runtime' (($r -split ' \[')[0]) } }

  $lines.Add('INVENTORY PASS items=' + @($lines | Where-Object { $_ -like 'ENV *' }).Count)
  $masked = @($lines | ForEach-Object { ConvertTo-Masked $_ $secret })
  Set-Content -LiteralPath (Join-Path $dir '90161Z-T15-inventory-r2.txt') -Value $masked -Encoding UTF8
  $masked | ForEach-Object { Write-Host $_ }
  Write-Host ''
  Write-Host 'Saved: 90161Z-T15-inventory-r2.txt in the T15 folder. Nothing was changed.'
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
} finally {
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
