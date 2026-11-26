<#
.SYNOPSIS
  90-161.Z Task 27 r1 (round R43; the PFM, 25 Nov 26: RADE Uninstall, install from zero, 1 fake publication through 1 process step
  (a move from step 1 to step 2; see the module check); test site only): the Uninstall steps of the app 90-161.Z, and the read-only checks and the process step that follow
  them. Windows PowerShell 5.1 (also 7), the installed PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  Parts (-Part). The first 3 run in RADE's Uninstall mode (RADE engine-v41: a Back up first, then these steps). The lists are removed
  BY THEIR FIXED TITLES (the PFM, 25 Nov 26: the 12 lists of the test site were made before RADE installs, so RADE has no record of them):
  the own-name table of the module 90161Z-T27-made-r2.ps1, whether or not RADE_MADE names them. The group and the level are different
  (the PFM, 25 Nov 26): a group cannot go to a Recycle Bin, so its removal cannot be undone; they go only when RADE_MADE names them.
  Never a list, group or level whose name is not in that table. The other gates stay: RADE_MODE=uninstall, a made list (RADE_MADE) of schema
  rade-made/1 for the app 90-161.Z, the app name and the own-name table. They print one ITEM line for each thing (PASS removed, SKIP
  nothing left, FAIL) and one RESULT line (PASS, SKIP or FAIL). A second run finds nothing left and prints SKIP. Without RADE_MODE=uninstall
  and a made list of schema rade-made/1 for 90-161.Z they remove nothing and print FAIL.
    Lists   Removes each of the 12 lists of 90-161.Z to the site Recycle Bin (restorable for 93 days). A list is removed only when its
            folder name is its internal name AND its title is its fixed title (or, for a list that a stopped install left, its internal
            name): a list that a person made and titled like ours, and a list of ours that a person retitled, stay and print SKIP. A list
            that other lists point to is removed after the lists that point to it.
    Access  Removes the group PFM Office and the permission level PFM Office Edit All Items, each one only when RADE_MADE names it (the
            install made it). A group or level that RADE_MADE does not name stays and prints SKIP "not made by the install" (T20 makes
            each one only when the site has none, so one that was there before the install is not ours to remove).
    Local   Removes the install note file of this computer (T22 folder), only when the made list names it (a file is not covered by
            the decision of 25 Nov 26). RADE keeps its own install record and marks it uninstalled; this script never touches that record.
  The read-only checks and the step (a round step; they need no made list). Module: 90161Z-T27-check-r2.ps1.
    Gone    After Uninstall: none of the 12 lists is on the site.
    Install After the install from zero: the 12 lists are on the site, and the process steps the next part needs are in PFM Process Steps.
    Step    1 fake publication (made by T26 Make) moves from step 1 (Request, DAFMAN 90-161 3.1) to step 2 (Drafting with SMEs, 3.2), and
            the move is read back, but only when the exit conditions of step 1 that the lists can show hold on it
            (checked before and after the move; the list and the sources are in the module header).
  WHAT IT CHANGES ON THE SITE: Lists, Access: the removals above. Step: 1 field (the process step) of the fake publication of T26.
  Gone and Install change nothing. Local: 1 file on this computer.
  Counts, list names of this product and status words only: no names, addresses or row text. The site address stays in
  Config\90161Z-site.txt on this computer; every output line shows it as <SITE> and the DODID as <DODID>.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell (none for Local).
  Writes: on the site, the above; on this computer the T27 folder (the result file) and, for Local, 1 note file in the T22 folder.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Output: 90161Z-T27-<part>[-<label>]-r2.txt in the T27 folder. Last line: LIFECYCLE <part> done: passed=<n> skipped=<n> failed=<n>.
  Exit 1 when a part has a FAIL item or could not run (sign-in, missing list or module, made list not accepted).
  Run: powershell.exe -NoProfile -File 90161Z-T27-lifecycle-r2.ps1 -Part <part> (RADE does this).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Part
  Lists, Access or Local (Uninstall mode); Gone, Install or Step (round steps).
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T27 folder (its parent holds the T22 and T26 folders of the test).
.PARAMETER Label
  A word (lower-case letters) for the result file name, so a part that runs twice in a round keeps both files: Install with the label
  before writes 90161Z-T27-install-before-r2.txt.
#>
param([string]$Id, [Parameter(Mandatory = $true)][ValidateSet('Lists', 'Access', 'Local', 'Gone', 'Install', 'Step')][string]$Part,
  [switch]$NoPause, [string]$TestDir, [ValidatePattern('^[a-z]{0,12}$')][string]$Label = '')
$task = 'T27'
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
# R46 (the PFM, 26 Nov 26, R45 finding 2): the RADE sign-in block, for Set-SignInDpiAware (a smaller sign-in window).
# >>> rade-signin: generated from the pinned RADE sign-in block by scripts/build_task_scripts.py (do not edit)
# ---- RADE sign-in window size (start; engine/ps/07-checks.ps1 $signInSize; E3, the Owner, 2026-11-21)
# engine-v44 (the PFM, 2026-11-26): RADE never touches the CAC sign-in window of Connect-PnPOnline -UseWebLogin; it opens
# at its own size. The size watch of engine-v35 to engine-v43 (Start-SignInSize) is gone: it froze the sign-in
# (90-161.Z R44 r2, one host: watch on, 2 windows not responding at 9 s; watch off, signed in after 5 s).
# The block holds the read-only window report (Start-SignInReport, Stop-SignInReport), the DPI setting of engine-v46
# (Set-SignInDpiAware) and the one sign-in (Connect-RadeSite).
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
# engine-v46 (90-161.Z R45 finding 2; the PFM, 2026-11-26: "I want the window to be small when it appears"): before the
# sign-in, the child process becomes DPI-aware (SetProcessDPIAware). Windows then draws the PnP sign-in window at its
# own 1024 x 768 pixels; in a process that is not DPI-aware Windows stretches it 1.5 times at 150 % (1536 x 1152, taller
# than a 1920 x 1128 work area). R45 T22 signed in this way (its window is DPI-aware) and the PFM saw the small window.
# RADE does not move, size or watch the window (engine-v44). PnP draws the window on its own thread, so a per-thread
# setting would not reach it; the setting is for the whole process, and it holds for the rest of the step (a form the
# step shows later is drawn at real pixels too: it must scale itself, AutoScaleMode Dpi or Font). $env:RADE_SIGNIN_DPI
# = '0' turns it off. Prints "SIGNIN-DPI aware=<yes|was|no|off>": yes (now aware), was (already aware), no (Windows did
# not take it, or not Windows), off (turned off). Takes nothing.
function Set-SignInDpiAware {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param()
  if ($env:RADE_SIGNIN_DPI -eq '0') { return 'SIGNIN-DPI aware=off' }
  if (-not $PSCmdlet.ShouldProcess('this process', 'Make DPI-aware')) { return 'SIGNIN-DPI aware=no' }
  if ($env:OS -ne 'Windows_NT') { return 'SIGNIN-DPI aware=no' }
  try {
    if (-not ('RadeSignIn.Dpi1' -as [type])) {
      Add-Type -Namespace RadeSignIn -Name Dpi1 -ErrorAction Stop -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool IsProcessDPIAware();
"@
    }
    if ([RadeSignIn.Dpi1]::IsProcessDPIAware()) { return 'SIGNIN-DPI aware=was' }
    if ([RadeSignIn.Dpi1]::SetProcessDPIAware()) { return 'SIGNIN-DPI aware=yes' }
  } catch { $null = $_ }   # no helper (Constrained Language Mode): the sign-in goes on at Windows' size
  return 'SIGNIN-DPI aware=no'
}
# engine-v43 S1: the one sign-in of a child script. Prints "STAGE signin" (the parent stops a stage that runs too long),
# signs in with the CAC (PnP web login), prints "SIGNIN seconds=<n>" and "STAGE none" (no stage runs).
# Throws when the sign-in fails, as Connect-PnPOnline does. Takes the site address.
function Connect-RadeSite([string]$Site) {
  'STAGE signin'
  Set-SignInDpiAware   # engine-v46: the sign-in window at its real pixels (R45 finding 2)
  $t0 = Get-Date; Start-SignInReport   # engine-v44: no size watch
  try { $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1 }
  finally { Stop-SignInReport }   # no report after the sign-in
  'SIGNIN seconds=' + [int]((Get-Date) - $t0).TotalSeconds
  'STAGE none'
}
# ---- RADE sign-in window size (end)
# <<< rade-signin

$lines = New-Object System.Collections.Generic.List[string]
$script:passed = 0; $script:failed = 0; $script:skipped = 0
# The number of things this run removed so far; the stop handler prints it when a part stops after a removal.
$script:removedSoFar = 0
# Adds one "ITEM <name> <status> <text>" line and counts a PASS, a SKIP or a FAIL.
function Add-Item([string]$Name, [string]$Status, [string]$Text) {
  $lines.Add('ITEM ' + $Name + ' ' + $Status + ' ' + $Text)
  if ($Status -eq 'PASS') { $script:passed++ } elseif ($Status -eq 'FAIL') { $script:failed++ } elseif ($Status -eq 'SKIP') { $script:skipped++ }
}
# Adds the one RESULT line of an Uninstall part: FAIL when an item failed, else PASS when something was removed, else SKIP.
function Add-UninstallResult([int]$Removed) {
  $word = $(if ($script:failed) { 'FAIL' } elseif ($Removed) { 'PASS' } else { 'SKIP' })
  $lines.Add('RESULT UNINSTALL ' + $Part.ToUpperInvariant() + ' ' + $word + ' removed=' + $Removed)
}
# Loads the newest installed PnP.PowerShell; stops with a plain message when it is not installed.
function Import-PnPNewest {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { throw 'PNP not installed: PnP.PowerShell is not on this computer.' }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
}
# Signs in to the one site with the web login (CAC), after the module is loaded.
function Connect-LifecycleSite {
  Import-PnPNewest
  Write-Host 'NOW Signing in to the site (if a sign-in window opens, sign in with your CAC)'
  # R46: the sign-in window at its real size (RADE engine-v46 block); the SIGNIN-DPI line goes to the log.
  if (Get-Command Set-SignInDpiAware -ErrorAction SilentlyContinue) { Write-Host (Set-SignInDpiAware) }
  $null = & { Connect-PnPOnline -Url $script:site -UseWebLogin -ErrorAction Stop } *>&1
  $lines.Add('ROUTE web-login PASS')
}
# Cuts an error message to 120 characters, so no long site text reaches a line.
function Get-ShortError($ErrorRecord) { $m = [string]$ErrorRecord.Exception.Message; return $m.Substring(0, [Math]::Min(120, $m.Length)) }
<#
.SYNOPSIS
  The part Lists: removes each of the 12 lists of 90-161.Z by its fixed title (the own-name table), to the site Recycle Bin, whether or
  not the made list names it, and reads each back. A list is removed only when its folder name is its internal name AND its title is
  its fixed title; any other list stays.
.PARAMETER Made
  The result of Read-MadeFile (accepted). It only adds NOTE lines here: a list name in it that is not one of the 12 is refused.
#>
function Invoke-ListsPart($Made) {
  foreach ($n in (Get-MadeName $Made.Items 'list')) {
    if (-not (Resolve-OwnList $n)) { $lines.Add('NOTE refused: a list in the made list is not one of the 12 lists of 90-161.Z (not removed)') }
  }
  Connect-LifecycleSite
  Write-Host 'NOW Reading the lists of the site'
  $siteLists = Get-SiteList
  $removed = @(); $n = 0
  foreach ($k in $OwnLists.Keys) {
    $n++; $tag = 'l' + $n.ToString('00') + '-' + $k
    $l = Find-OwnListToRemove $siteLists $k
    if (-not $l) { Add-Item $tag 'SKIP' (Get-ListLeftReason $siteLists $k); continue }
    try {
      Write-Host ('NOW Removing the list ' + $OwnLists[$k])
      $null = Remove-PnPList -Identity ([string]$l.Id) -Recycle -Force -ErrorAction Stop
      $removed += $k; $script:removedSoFar++
    } catch { Add-Item $tag 'FAIL' ('the list could not be removed: ' + (Get-ShortError $_) + ' (run this step again)') }
  }
  $after = @(Get-SiteList)
  foreach ($k in $removed) {
    $tag = 'r-' + $k
    if (Find-OwnListToRemove $after $k) { Add-Item $tag 'FAIL' 'the list is still on the site after the remove (run this step again)' }
    else { Add-Item $tag 'PASS' ('the list is removed (moved to the site Recycle Bin): ' + $OwnLists[$k]) }
  }
  Add-UninstallResult $removed.Count
}
<#
.SYNOPSIS
  The part Access: removes the group PFM Office, then the permission level PFM Office Edit All Items, each only when the made list names
  it (the install made it; a group cannot go to a Recycle Bin). A name that is not named stays and prints SKIP. No other group and no
  other level is ever removed.
.PARAMETER Made
  The result of Read-MadeFile (accepted). A group or level name in it that is not ours is refused (NOTE) and never removed.
#>
function Invoke-AccessPart($Made) {
  foreach ($n in (Get-MadeName $Made.Items 'group')) {
    if (-not (Test-OwnName 'group' $n)) { $lines.Add('NOTE refused: a group in the made list is not the group of 90-161.Z (not removed)') }
  }
  foreach ($n in (Get-MadeName $Made.Items 'level')) {
    if (-not (Test-OwnName 'level' $n)) { $lines.Add('NOTE refused: a level in the made list is not the level of 90-161.Z (not removed)') }
  }
  $madeGroup = @(Get-MadeName $Made.Items 'group') -ccontains $OwnGroup
  $madeLevel = @(Get-MadeName $Made.Items 'level') -ccontains $OwnLevel
  Connect-LifecycleSite
  $removed = Invoke-OwnAccessRemoval 'a1-group' $OwnGroup $madeGroup { Get-GroupId $OwnGroup } { Remove-PnPGroup -Identity $OwnGroup -Force -ErrorAction Stop }
  $removed += Invoke-OwnAccessRemoval 'a2-level' $OwnLevel $madeLevel { Get-OwnLevelId } { Remove-PnPRoleDefinition -Identity $OwnLevel -Force -ErrorAction Stop }
  Add-UninstallResult $removed
}
# The number of the permission level PFM Office Edit All Items on the site, or 0 when it is not there.
function Get-OwnLevelId { $v = Get-RoleLevel $OwnLevel 0; if ($v) { return [int]$v.Id }; return 0 }
<#
.SYNOPSIS
  Removes one named thing of the site (the group or the level) when the made list names it and it is there, and reads it back.
.PARAMETER Tag
  The item name for the result line.
.PARAMETER Name
  The name of the thing (it is one of the 2 fixed names of the module; the caller checked it).
.PARAMETER Named
  Whether the made list names the thing (the install made it). When it does not, nothing is removed and the item is a SKIP.
.PARAMETER Find
  A script block that returns the number of the thing, or 0 when it is not on the site.
.PARAMETER Remove
  A script block that removes it.
.OUTPUTS
  System.Int32. 1 when it was removed and read back, else 0.
#>
function Invoke-OwnAccessRemoval([string]$Tag, [string]$Name, [bool]$Named, [scriptblock]$Find, [scriptblock]$Remove) {
  if (-not $Named) { Add-Item $Tag 'SKIP' ('not made by the install: ' + $Name + ' stays'); return 0 }
  if (-not (& $Find)) { Add-Item $Tag 'SKIP' ('not on the site: nothing left to remove: ' + $Name); return 0 }
  try { Write-Host ('NOW Removing ' + $Name); $null = & $Remove }
  catch { Add-Item $Tag 'FAIL' ('could not be removed: ' + (Get-ShortError $_) + ' (run this step again)'); return 0 }
  $script:removedSoFar++
  if (& $Find) { Add-Item $Tag 'FAIL' ('still on the site after the remove: ' + $Name + ' (run this step again)'); return 0 }
  Add-Item $Tag 'PASS' ('removed: ' + $Name)
  return 1
}
<#
.SYNOPSIS
  The part Local: removes the install note file (T22 folder) when the made list names it. Not the RADE install record.
.PARAMETER Made
  The result of Read-MadeFile (accepted).
.PARAMETER Dir
  The T27 folder; the T22 folder is its neighbor.
#>
function Invoke-LocalPart($Made, [string]$Dir) {
  $names = @(Get-MadeName $Made.Items 'file')
  if (-not $names.Count) { Add-Item 'f00-note' 'SKIP' 'no file is named in the made list: nothing to remove'; Add-UninstallResult 0; return }
  $removed = 0; $n = 0
  foreach ($name in $names) {
    $n++; $tag = 'f' + $n.ToString('00') + '-note'
    # Only the install note, only by its plain file name: a path, or any other file name, is refused.
    if (-not (Test-OwnName 'file' $name)) { $lines.Add('NOTE refused: a file in the made list is not the install note of 90-161.Z (not removed)'); continue }
    $path = Join-Path (Join-Path (Split-Path -Parent $Dir) 'T22') $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Item $tag 'SKIP' 'the install note is not on this computer: nothing left to remove'; continue }
    try { Remove-Item -LiteralPath $path -ErrorAction Stop } catch { Add-Item $tag 'FAIL' ('the install note could not be removed: ' + (Get-ShortError $_)); continue }
    $script:removedSoFar++
    if (Test-Path -LiteralPath $path) { Add-Item $tag 'FAIL' 'the install note is still there after the remove'; continue }
    Add-Item $tag 'PASS' 'the install note is removed'; $removed++
  }
  Add-UninstallResult $removed
}

$fatal = $false; $site = ''; $secret = @(); $dir = ''; $uninstall = $false
try {
  $ErrorActionPreference = 'Stop'
  # The modules are dot-sourced here, in this script's scope, so they see the values and helpers above (the T20 helpers give
  # Get-SiteList, Find-OurList, Get-GroupId and Get-RoleLevel; RADE saves them in this folder too).
  foreach ($m in '90161Z-T27-made-r2.ps1', '90161Z-T27-check-r2.ps1', '90161Z-T20-helpers-r4.ps1') {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $m) -PathType Leaf)) { throw ('MODULE missing: ' + $m + ' is not in the folder of this script. Run the round again.') }
    . (Join-Path $PSScriptRoot $m)
  }
  $who = Get-TaskId $Id; $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $who.Id $task 'Task 27' -Create }
  Set-Location -LiteralPath $dir
  $lines.Add('TASK T27 lifecycle ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $uninstall = $Part -in 'Lists', 'Access', 'Local'
  if ($uninstall) {
    # The gate: nothing is removed unless RADE says Uninstall and its made list is accepted.
    $made = Read-MadeFile ([string]$env:RADE_MODE) ([string]$env:RADE_MADE)
    if (-not $made.Ok) { Add-Item 'g-made' 'FAIL' $made.Why; $lines.Add('RESULT UNINSTALL ' + $Part.ToUpperInvariant() + ' FAIL removed=0'); throw 'GATE not passed.' }
    $lines.Add('MADE entries=' + @($made.Items).Count + '; without step, kind or name=' + $made.Dropped)
  }
  if ($Part -ne 'Local') { $script:site = Get-SiteAddress (Join-Path (Split-Path -Parent $dir) 'Config') }
  switch ($Part) {
    'Lists' { Invoke-ListsPart $made } 'Access' { Invoke-AccessPart $made } 'Local' { Invoke-LocalPart $made $dir }
    'Gone' { Connect-LifecycleSite; Invoke-GonePart } 'Install' { Connect-LifecycleSite; Invoke-InstallPart }
    default { Connect-LifecycleSite; Invoke-StepPart $dir }
  }
  if ($Part -notin 'Local') { try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ } }
} catch {
  $fatal = $true
  # A part that throws after a removal (a read-back, a lookup) still prints its FAIL item and its RESULT line, and counts as failed
  # (R43 review). A part that printed its RESULT line already (the gate, or a normal end) is not counted twice.
  if ($uninstall -and -not @($lines | Where-Object { $_ -cmatch '^RESULT UNINSTALL ' }).Count) {
    Add-Item 's-stopped' 'FAIL' 'the part stopped before it finished (see STOPPED); what was removed stays removed (run this step again)'
    Add-UninstallResult $script:removedSoFar
  }
  if ($script:site) { $site = $script:site }
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(300, $m.Length)) + ' (the part can be run again)')
} finally {
  if ($script:site) { $site = $script:site }
  $lines.Add('LIFECYCLE ' + $Part + ' done: passed=' + $script:passed + ' skipped=' + $script:skipped + ' failed=' + $script:failed)
  # Every line is masked once more before it is shown or saved.
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  $resultName = '90161Z-T27-' + $Part.ToLowerInvariant() + $(if ($Label) { '-' + $Label } else { '' }) + '-' + $Rev + '.txt'
  if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir $resultName) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal -or $script:failed) { exit 1 }
exit 0
