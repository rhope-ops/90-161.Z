<#
.SYNOPSIS
  90-161.Z Task 29 r1 (round R44 r2; the PFM, 26 Nov 26: "surely there's a way to test it both ways or determine root cause
  better"): one CAC sign-in to the test site, with the RADE sign-in size watch on or off, that always ends with a result.
  Windows PowerShell 5.1 (also 7), the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  WHY: in R44 r1 the CAC sign-in window froze in both RADE runs and the PFM had to force-close the windows, so no data came
  back. This step signs in the way RADE does (Connect-RadeSite of the pinned RADE sign-in block below) and writes each line to
  its result file at once, so a stop keeps the lines. The round runs it 4 times: RADE in its own window (host "child") and
  RADE inside ISE (host "ise"), each with the size watch on and off.
  WHAT IT WRITES: nothing on the site (it signs in and out only). On this computer one result file in the T29 folder:
  90161Z-T29-signin-<on|off>-r1.txt.
  Lines: TASK; HOST rade=<RADE_HOST> ps=<edition and version>; WATCH asked=<on|off>; STAGE signin; SIGNIN-WIN lines (the
  windows of this process only: count, owned, minimized, size, not responding, foreground; no title and no text);
  SIGNIN seconds=<n> watch=<on|off>; RESULT SIGNIN PASS or STOPPED: <why>.
  Its own time limit (-Limit, 180 s): when the sign-in has not ended by then, it writes "STOPPED: the sign-in did not
  finish in <n> seconds" and the last window state, then ends this process. Exit 1 when the sign-in did not finish.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell.
  Writes: the result file in the T29 folder (or -TestDir). Nothing on the site.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Run: powershell.exe -NoProfile -File 90161Z-T29-signin-r1.ps1 -Watch on (RADE does this).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Watch
  on = the RADE sign-in size watch runs (RADE's default); off = it does not (RADE_SIGNIN_WATCH=0).
.PARAMETER Limit
  The time limit of the sign-in, in seconds (30 to 600).
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T29 folder (its parent holds the Config folder of the test).
#>
param([string]$Id, [ValidateSet('on', 'off')][string]$Watch = 'on', [ValidateRange(30, 600)][int]$Limit = 180, [switch]$NoPause, [string]$TestDir)
$task = 'T29'
$Rev = 'r1'

# >>> task-common: generated from scripts/gov/src/task-common.ps1 by scripts/build_task_scripts.py (do not edit)
# <<< task-common
# >>> site-common: generated from scripts/gov/src/site-common.ps1 by scripts/build_task_scripts.py (do not edit)
# <<< site-common
# >>> rade-signin: generated from the pinned RADE sign-in block by scripts/build_task_scripts.py (do not edit)
# <<< rade-signin

# The guard of this step: every line goes to the result file as soon as it is written (a copy of the console output), and a
# timer ends this process when the sign-in runs past its limit, after it writes why. Windows PowerShell 5.1, no module.
if (-not ('T29Guard.Tee' -as [type])) {
  Add-Type -Namespace T29Guard -Name Tee -MemberDefinition @"
static System.IO.TextWriter was; static System.IO.StreamWriter file; static System.Threading.Timer timer; static object gate = new object();
// Starts the copy: each line written to the console also goes to the file at once (the file is made new).
public static void Begin(string path) { lock (gate) { was = System.Console.Out; file = new System.IO.StreamWriter(path, false, new System.Text.UTF8Encoding(true)); file.AutoFlush = true;
  System.Console.SetOut(new Both()); } }
// Writes one line to the console and to the file.
public static void Line(string s) { System.Console.Out.WriteLine(s); }
// Ends the copy and gives the console back; safe to call twice.
public static void End() { lock (gate) { if (timer != null) { timer.Dispose(); timer = null; } if (file != null) { System.Console.SetOut(was); file.Dispose(); file = null; } } }
// Starts the time limit: after seconds, the line why goes out, then this process ends with exit code 1.
public static void Limit(int seconds, string why) { timer = new System.Threading.Timer(delegate(object o) {
  lock (gate) { try { if (file != null) { file.WriteLine(why); was.WriteLine(why); was.Flush(); } } catch { } }
  System.Environment.Exit(1); }, null, seconds * 1000, System.Threading.Timeout.Infinite); }
// Stops the time limit (the sign-in ended in time).
public static void Unlimit() { lock (gate) { if (timer != null) { timer.Dispose(); timer = null; } } }
class Both : System.IO.TextWriter {
  public override System.Text.Encoding Encoding { get { return was.Encoding; } }
  public override void Write(char c) { lock (gate) { was.Write(c); if (file != null) { file.Write(c); } } }
  public override void Write(string s) { lock (gate) { was.Write(s); if (file != null) { file.Write(s); } } }
  public override void WriteLine(string s) { lock (gate) { was.WriteLine(s); was.Flush(); if (file != null) { file.WriteLine(s); } } } }
"@
}

$fatal = $false; $site = ''; $secret = @(); $dir = ''; $out = ''
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id; $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 29' -Create }
  Set-Location -LiteralPath $dir
  $out = Join-Path $dir ('90161Z-T29-signin-' + $Watch + '-' + $Rev + '.txt')
  [T29Guard.Tee]::Begin($out)
  [T29Guard.Tee]::Line('TASK T29 signin ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  [T29Guard.Tee]::Line('HOST rade=' + $(if ($env:RADE_HOST) { $env:RADE_HOST } else { 'unknown' }) + ' ps=' + $PSVersionTable.PSEdition + ' ' + $PSVersionTable.PSVersion)
  [T29Guard.Tee]::Line('WATCH asked=' + $Watch)
  if ($Watch -eq 'off') { $env:RADE_SIGNIN_WATCH = '0' } else { Remove-Item -LiteralPath 'Env:RADE_SIGNIN_WATCH' -ErrorAction SilentlyContinue }
  $script:site = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config')
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }   # the tested version first
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  [T29Guard.Tee]::Line('NOW Signing in to the site (if a sign-in window opens, sign in with your CAC)')
  [T29Guard.Tee]::Limit($Limit, ('STOPPED: the sign-in did not finish in ' + $Limit + ' seconds (the step can be run again)'))
  Connect-RadeSite $script:site | ForEach-Object { [T29Guard.Tee]::Line([string]$_) }
  [T29Guard.Tee]::Unlimit()
  [T29Guard.Tee]::Line('RESULT SIGNIN PASS')
  try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }   # a sign-out that fails changes nothing here
} catch {
  $fatal = $true
  try { [T29Guard.Tee]::Unlimit() } catch { $null = $_ }   # no guard: nothing to stop
  if ($script:site) { $site = $script:site }
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $line = 'STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)) + ' (the step can be run again)'
  try { [T29Guard.Tee]::Line($line) } catch { Write-Host $line }
} finally {
  try { [T29Guard.Tee]::End() } catch { $null = $_ }   # no guard: the file was not opened
  if ($script:site) { $site = $script:site }
  # Every line is masked once more (the site, the DODID) in the file that goes back.
  if ($out -and (Test-Path -LiteralPath $out -PathType Leaf)) {
    try { $masked = @(Get-Content -LiteralPath $out | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
      Set-Content -LiteralPath $out -Value $masked -Encoding UTF8 } catch { $null = $_ } }   # the file keeps its own lines
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
