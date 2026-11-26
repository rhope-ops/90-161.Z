<#
.SYNOPSIS
  90-161.Z Task 29 r2 (round R45; the PFM, 26 Nov 26): one CAC sign-in to the test site, the way RADE engine-v44 signs in
  (no sign-in size watch), that always ends with a result.
  Windows PowerShell 5.1 (also 7), the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  WHY: in R44 r2 the CAC sign-in froze with the RADE sign-in size watch on (2 windows not responding at 9 s) and passed in
  5 s with it off. RADE engine-v44 deletes the watch. This step signs in the way RADE does (Connect-RadeSite of the pinned
  RADE sign-in block below) and writes each line to its result file at once, so a stop keeps the lines.
  WHAT IT WRITES: nothing on the site (it signs in and out only). On this computer one result file in the T29 folder:
  90161Z-T29-signin-r2.txt.
  Lines: TASK; HOST rade=<RADE_HOST> ps=<edition and version>; STAGE signin; SIGNIN-WIN lines (the windows of this process
  only: count, owned, minimized, size, not responding, foreground; no title and no text); SIGNIN seconds=<n>;
  RESULT SIGNIN PASS or STOPPED: <why>.
  Its own time limit (-Limit, 180 s): when the sign-in has not ended by then, it writes "STOPPED: the sign-in did not
  finish in <n> seconds" and the last window state, then ends this process. Exit 1 when the sign-in did not finish.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell.
  Writes: the result file in the T29 folder (or -TestDir). Nothing on the site.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Run: powershell.exe -NoProfile -File 90161Z-T29-signin-r2.ps1 (RADE does this).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Limit
  The time limit of the sign-in, in seconds (30 to 600).
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T29 folder (its parent holds the Config folder of the test).
#>
param([string]$Id, [ValidateRange(30, 600)][int]$Limit = 180, [switch]$NoPause, [string]$TestDir)
$task = 'T29'
$Rev = 'r2'

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
  # The task folder C:\Users\<DODID>\<OneDrive>\RADE\90-161.Z\<Task>: <OneDrive> is the folder name of $env:OneDriveCommercial,
  # else 'OneDrive - United States Air Force' (fleet v2). Until RADE moves the old ...\90-161.Z, that one is used. -Create makes it.
  $odName = if ($env:OneDriveCommercial) { Split-Path -Leaf $env:OneDriveCommercial } else { 'OneDrive - United States Air Force' }; $od = Join-Path (Join-Path 'C:\Users' $Id) $odName
  $app = 'RADE\90-161.Z'
  if (-not (Test-Path -LiteralPath (Join-Path $od $app) -PathType Container) -and (Test-Path -LiteralPath (Join-Path $od '90-161.Z') -PathType Container)) { $app = '90-161.Z' }
  $tail = $odName + '\' + $app + '\' + $Task
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
  $out = & powershell.exe -NoProfile -File (Join-Path $ScriptDir $Step.File) @stepArgs 2>&1
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
  Masks e-mail addresses, the site, its host, path, name and tenant, other URLs, cloud and .mil hosts and GUIDs in a
  result text. Not masked: display names, office symbols, phone numbers, user ids, computer names.
  .PARAMETER Text
  The text to clean (a result line or an error message).
  .PARAMETER Site
  The site address (https://<host>/sites/<name>), or an empty text for the generic rules only.
  .OUTPUTS
  System.String. The text with each match replaced by a placeholder such as <EMAIL>, <SITE> or <GUID>.
  #>
  # The address only (name, @ or %40, host; encoded characters and an apostrophe inside the name count as part of it),
  # first: the host rules below would
  # keep its name part.
  $Text = $Text -replace '(?:[\w.+=-]|%[0-9A-Fa-f]{2}|(?<=\w)[''\u2019](?=\w))+(?:@|%40)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*(?:%[0-9A-Fa-f]{2})*', '<EMAIL>'
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
  # Pattern and mask pairs. The GUID has no \b: guid%27<id> must be masked too.
  $g = @('https?://\S+', '<URL>', '\b[\w.-]+\.(sharepoint|onmicrosoft|microsoftonline|windows)\.(com|us|net|mil)\b', '<TENANT-HOST>',
    '\b[\w.-]+\.mil\b', '<HOST>', '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>')
  for ($i = 0; $i -lt $g.Count; $i += 2) { $Text = $Text -replace $g[$i], $g[$i + 1] }
  return $Text
}
# <<< site-common
# >>> rade-signin: generated from the pinned RADE sign-in block by scripts/build_task_scripts.py (do not edit)
# ---- RADE sign-in window size (start; engine/ps/07-checks.ps1 $signInSize; E3, the Owner, 2026-11-21)
# engine-v44 (the PFM, 2026-11-26): RADE never touches the CAC sign-in window of Connect-PnPOnline -UseWebLogin; it opens
# at its own size. The size watch of engine-v35 to engine-v43 (Start-SignInSize) is gone: it froze the sign-in
# (90-161.Z R44 r2, one host: watch on, 2 windows not responding at 9 s; watch off, signed in after 5 s).
# The block holds the read-only window report (Start-SignInReport, Stop-SignInReport) and the one sign-in (Connect-RadeSite).
# Copy this block unchanged between its start and end lines (an app's task scripts may hold the same copy).
# Windows PowerShell 5.1, no module. When the report helper cannot be compiled (Constrained Language Mode), the sign-in
# goes on without it.
# engine-v43 S2 (the PFM, 2026-11-26: R44 r1 froze at the sign-in with no data): while Connect-PnPOnline runs, a
# background timer reads the windows of THIS process only, about every second, and prints one line at each change:
# "SIGNIN-WIN t=<seconds> windows=<visible> owned=<visible with an owner> min=<minimized> size=<largest WxH>
# hung=<not responding> front=<1 when the foreground window is one of them>". No title, no text, no other process.
# The parent reads the lines while the child runs (Invoke-ChildScript -StageSeconds), so a frozen sign-in still reports.
function Start-SignInReport {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param()
  if (-not $PSCmdlet.ShouldProcess('the windows of this process', 'Report their state')) { return }   # -WhatIf: no timer
  if ($env:OS -ne 'Windows_NT' -and $env:RADE_SIGNIN_TEST -ne '1') { return }   # Windows only (the cloud test compiles it)
  try {
    if (-not ('RadeSignIn.Report1' -as [type])) {
      Add-Type -Namespace RadeSignIn -Name Report1 -ErrorAction Stop -MemberDefinition @"
public delegate bool WinProc(System.IntPtr h, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool EnumThreadWindows(uint tid, WinProc f, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsWindowVisible(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsIconic(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsHungAppWindow(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr GetWindow(System.IntPtr h, uint cmd);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr GetForegroundWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool GetWindowRect(System.IntPtr h, out Rect r);
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct Rect { public int L, T, R, B; }
static System.Threading.Timer timer; static object gate = new object(); static System.DateTime t0; static string last = "";
static int n, owned, mins, hung, front, bw, bh; static long fg; static WinProc each = Each;
// Starts the report: one look now, then one every tickMs, until End. The timer starts outside the lock, so the first look runs.
public static void Begin(int tickMs) { End(false); lock (gate) { t0 = System.DateTime.Now; last = ""; }
  System.Threading.Timer tm = new System.Threading.Timer(Tick, null, System.Threading.Timeout.Infinite, System.Threading.Timeout.Infinite);
  lock (gate) { timer = tm; } tm.Change(0, tickMs); }
// Ends the report: waits until no tick runs, then, with final, prints one last line (the state at the end).
public static void End(bool final) {
  System.Threading.Timer tm; lock (gate) { tm = timer; timer = null; }
  // The event is closed only when the last tick has ended: a tick that runs past 2 s signals it later, and a closed event
  // would then end this process (review of PR 201). In that rare case the event is closed later by the garbage collector.
  if (tm != null) { System.Threading.ManualResetEvent done = new System.Threading.ManualResetEvent(false); if (!tm.Dispose(done) || done.WaitOne(2000)) { done.Dispose(); } }
  if (final) { lock (gate) { Look(true); } } }
// One timer tick: a tick that starts while another look runs is skipped; a tick after End prints nothing.
static void Tick(object state) {
  if (!System.Threading.Monitor.TryEnter(gate)) { return; }
  try { if (timer != null) { Look(false); } } finally { System.Threading.Monitor.Exit(gate); } }
// Reads the windows of this process and prints a line when the state changed since the last line, or when force is set.
// The caller holds gate.
static void Look(bool force) {
  try { n = 0; owned = 0; mins = 0; hung = 0; front = 0; bw = 0; bh = 0; fg = GetForegroundWindow().ToInt64();
    using (System.Diagnostics.Process me = System.Diagnostics.Process.GetCurrentProcess()) {
      foreach (System.Diagnostics.ProcessThread t in me.Threads) { EnumThreadWindows((uint)t.Id, each, System.IntPtr.Zero); } }
    string s = "windows=" + n + " owned=" + owned + " min=" + mins + " size=" + bw + "x" + bh + " hung=" + hung + " front=" + front;
    if (s != last || force) { last = s; System.Console.Out.WriteLine("SIGNIN-WIN t=" + (int)(System.DateTime.Now - t0).TotalSeconds + " " + s); System.Console.Out.Flush(); } }
  catch { } }
static bool Each(System.IntPtr hw, System.IntPtr l) {
  if (!IsWindowVisible(hw)) { return true; }
  n++; if (GetWindow(hw, 4) != System.IntPtr.Zero) { owned++; } if (IsIconic(hw)) { mins++; } if (IsHungAppWindow(hw)) { hung++; } if (hw.ToInt64() == fg) { front = 1; }
  Rect r; if (GetWindowRect(hw, out r) && (r.R - r.L) * (r.B - r.T) > bw * bh) { bw = r.R - r.L; bh = r.B - r.T; }
  return true; }
"@
    }
    [RadeSignIn.Report1]::Begin(1000)
  } catch { $null = $_ }   # no helper: the sign-in goes on without the report
}
function Stop-SignInReport {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param()
  if (-not $PSCmdlet.ShouldProcess('the window report of this process', 'Stop')) { return }
  try { if ('RadeSignIn.Report1' -as [type]) { [RadeSignIn.Report1]::End($true) } } catch { $null = $_ }   # no report: nothing to stop
}
# engine-v43 S1: the one sign-in of a child script. Prints "STAGE signin" (the parent stops a stage that runs too long),
# signs in with the CAC (PnP web login), prints "SIGNIN seconds=<n>" and "STAGE none" (no stage runs).
# Throws when the sign-in fails, as Connect-PnPOnline does. Takes the site address.
function Connect-RadeSite([string]$Site) {
  'STAGE signin'
  $t0 = Get-Date; Start-SignInReport   # engine-v44: the sign-in window opens at its own size (no size watch)
  try { $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1 }
  finally { Stop-SignInReport }   # no report after the sign-in
  'SIGNIN seconds=' + [int]((Get-Date) - $t0).TotalSeconds
  'STAGE none'
}
# ---- RADE sign-in window size (end)
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
public static void End() { lock (gate) { if (timer != null) { timer.Dispose(); timer = null; } 
  if (file != null) { if (part.Length > 0) { FileLine(part.ToString()); part.Clear(); }
    System.Console.SetOut(was); file.Dispose(); file = null; } } }
// Starts the time limit: after seconds, the line why goes out, then this process ends with exit code 1.
public static void Limit(int seconds, string why) { timer = new System.Threading.Timer(delegate(object o) {
  lock (gate) { try { if (file != null) { file.WriteLine(why); was.WriteLine(why); was.Flush(); } } catch { } }
  System.Environment.Exit(1); }, null, seconds * 1000, System.Threading.Timeout.Infinite); }
// Stops the time limit (the sign-in ended in time).
public static void Unlimit() { lock (gate) { if (timer != null) { timer.Dispose(); timer = null; } } }
// The masks of the file copy (text, placeholder): each line is masked before it reaches the file, so a stop by the time
// limit (no finally block runs) leaves no site address or DODID in the file.
static System.Collections.Generic.List<string[]> masks = new System.Collections.Generic.List<string[]>(); static System.Text.StringBuilder part = new System.Text.StringBuilder();
// Adds one mask: each later line that holds the text gets the placeholder in the file (text of 4 characters or more only).
public static void Mask(string text, string placeholder) { lock (gate) { if (text != null && text.Length >= 4) { masks.Add(new string[] { text, placeholder }); } } }
static void FileLine(string s) { foreach (string[] m in masks) { s = s.Replace(m[0], m[1]); } file.WriteLine(s); }
static void FileText(string s) { foreach (char c in s) { if (c == '\n') { FileLine(part.ToString().TrimEnd('\r')); part.Clear(); } else { part.Append(c); } } }
class Both : System.IO.TextWriter {
  public override System.Text.Encoding Encoding { get { return was.Encoding; } }
  public override void Write(char c) { lock (gate) { was.Write(c); if (file != null) { FileText(c.ToString()); } } }
  public override void Write(string s) { lock (gate) { was.Write(s); if (file != null && s != null) { FileText(s); } } }
  public override void WriteLine(string s) { lock (gate) { was.WriteLine(s); was.Flush(); if (file != null) { FileText((s ?? "") + "\n"); } } } }
"@
}

$fatal = $false; $site = ''; $secret = @(); $dir = ''; $out = ''
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id; $secret = $who.Secret
  foreach ($s in $secret) { [T29Guard.Tee]::Mask($s, '<DODID>') }   # the file copy never holds the DODID (also on a stop by the time limit)
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 29' -Create }
  Set-Location -LiteralPath $dir
  $out = Join-Path $dir ('90161Z-T29-signin-' + $Rev + '.txt')
  [T29Guard.Tee]::Begin($out)
  [T29Guard.Tee]::Line('TASK T29 signin ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  [T29Guard.Tee]::Line('HOST rade=' + $(if ($env:RADE_HOST) { $env:RADE_HOST } else { 'unknown' }) + ' ps=' + $PSVersionTable.PSEdition + ' ' + $PSVersionTable.PSVersion)
  $script:site = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config')
  [T29Guard.Tee]::Mask($script:site.TrimEnd('/'), '<SITE>'); try { [T29Guard.Tee]::Mask(([uri]$script:site).Host, '<SITE-HOST>') } catch { $null = $_ }   # no host: the site mask stays
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
