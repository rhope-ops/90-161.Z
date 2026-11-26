<#
.SYNOPSIS
  90-161.Z Task 21 probe, r13 (round R46: Skip in the second person window; before: r12, round R42). Windows PowerShell 5.1, PnP.PowerShell 1.12.0 (no other module).
.DESCRIPTION
  What it is for: the device side of the T21 probe. R26 settled most of the front-end tests (T2, T3, T5, T6, T7, T9, T10
  passed); R29a proved T4 (a second person writes a row). The 2 probe flows are now flows of the solution "90-161.Z flows"
  (fallback A, the PFM 18 Nov 26: a new solution and a hand-made flow failed in R29a to R32 with "The connections could
  not be loaded"; an upgrade of that solution works): "90161Z T21 Probe Health r6" answers a command row with a result row,
  and "90161Z T21 Probe Button r6" is started by a list view button. Excel is not repeated (R27: no Automate tab).
  This script makes the list and library the tests need, adds the second person to the site's Visitors group (and removes
  the person again), formats the list form and a view, starts the health flow, reads what the people and the flows wrote,
  and removes everything it made. Fake data only (the fake workbook comes from scripts/build_probe_samples.py). Counts,
  status codes and field names only: no names, addresses or text from the tenant.
  WHAT R11 CHANGES (R38; PFM 20 Nov 26): Read prints HEALTH NOT RUN and BUTTON NOT RUN when the round ran no flow step
  (both passed in R36 and R37), so a round that tests only T4 reads clean. The whole set is r13 (R46: Skip in the second person window).
  WHAT R10 CHANGED (R36; R35 finding 3): the new part Ask writes T4Asked=yes into the person state file and puts the new
  row form link on the clipboard, before the second person adds a row titled T4a; Read (module read r10) counts T4 only
  then, or when a row by another person is there. The whole set is r10, so the probe loads one revision.
  WHAT R8 CHANGED (PFM 19 Nov 26, F2 B): the new part Office and the test EDITALL prove that a PFM Office member who is not
  a row's author can edit that row on a list set to "edit own rows" (the level T20 r2 gives the group PFM Office, F2 A).
  The part lives in the new module "office"; Read prints the EDITALL line, Clean also takes the person out of PFM Office.
  WHAT R7 CHANGED: (1) the health flow writes its row without the Power Automate Management connector, so HEALTH now tests
  that the flow ran on the SharePoint connection of the solution (it no longer counts flows). (2) View takes the button
  flow's ID from the button-flow-id block of the look module, which scripts/build_flow_solution.py writes at build time
  (the ID is the same on every build); the Export part, its module and the flow ID file are gone. (3) BUTTON counts the
  rows titled BTN-FLOW that the button flow writes. (4) Before each action that takes time a part prints one line
  "NOW <what it does>" for the RADE window; a NOW line is not a result line and is not in the result file.
  WHAT R6 CHANGED: (1) the Clean part no longer prints the Recycle Bin item IDs of the list and the library (R29a finding 7:
  a raw RecycleBinItemId table reached the log). (2) The parts Form and View run the two halves of Look on their own, so the
  round can show the list form when the form header passed, whatever the view result (R29a finding 6); Look still runs both.
  (3) The script is split into modules (code standard, S1): this file holds the start, the shared blocks and the result
  file; the parts live in the files 90161Z-T21-<part>-r13.ps1 in the same folder, which this file loads by name.
  (4) Read: with no state file and no row by another person, T4 is not counted: one line "T4 NOT RUN" and no RESULT line.
  Parts (-Part):
    Make   (about 1 minute, an estimate)  Makes the library "90161Z Probe Files" and the list "90161Z Probe" (columns
           ProbeTest, ProbeWay, ProbeResult, ProbeDetail; its own permissions: the site's copied, then Contribute for the
           site's Visitors group on this list only), saves the fake workbook from a text block in the make module, uploads
           it and writes the test page 90161Z-T21-links-r5.html (4 links). Run it twice and the second run changes nothing.
    Person (about 1 minute, an estimate)  Opens a small window and asks for the e-mail address of the second person (test
           T4). The address stays in memory: it is never written to a file, to the screen or to the results. With your own
           sign-in it adds that person to the site's Visitors group and saves only the number of the site user (no address,
           no name) in the state file 90161Z-T21-person-state-r3.txt in the T21 folder, so that Clean can find the person.
           It also puts the link of the new row form on the clipboard. Prints "added to Visitors: yes" or "no" and a status.
    Office (about 1 minute, an estimate; after Person and after T20 r2)  Sets "edit own rows" on the probe list, gives
           the group PFM Office the level "PFM Office Edit All Items" on it, writes 1 row titled EDITALL (you are its
           author), puts the second person of Person into PFM Office (state file 90161Z-T21-office-state-r8.txt: numbers
           only) and reads back that the person can edit every row. The row's edit form link goes on the clipboard: the
           second person opens it, changes the row and saves it.
    Ask    (a few seconds; no sign-in; after Person)  Writes T4Asked=yes into the state file 90161Z-T21-person-state-r3.txt
           and puts the link of the new row form on the clipboard, for the second person's row T4a.
    Run    (a few seconds, an estimate)  Adds 1 command row (RUN-HEALTH) that starts the health flow "90161Z T21 Probe
           Health r6"; it answers within minutes.
    Look   (about 1 minute, an estimate)  Runs Form, then View.
    Form   (about 1 minute, an estimate)  Sets a header on the list form (the content type's form formatting) and reads it back.
    View   (about 1 minute, an estimate)  Makes the view "ProbeButton" with a button that starts the button flow "90161Z
           T21 Probe Button r6" (a view formatting with the action executeFlow; the flow's ID is in the look module).
    Open   (a few seconds; no sign-in)  Writes the test page again and opens it in the browser.
    Read   (about 1 to 5 minutes, an estimate)  Waits up to -WaitMinutes (default 4) for the health flow's row, then prints
           one line each for HEALTH, T4, EDITALL and BUTTON (counts only; the button flow's rows are the ones titled
           BTN-FLOW). EDITALL passes when the second person saved the EDITALL row that you wrote.
    Clean  (about 1 minute, an estimate)  Removes the second person from the Visitors group and from PFM Office again (found
           by the saved numbers; then deletes the state files), then moves the list and the library to the site Recycle Bin (restorable
           for 93 days). Each step runs even if an earlier one failed, and the part can be run again. The 2 probe flows
           stay in the solution "90-161.Z flows" (the part says so). The round runs it twice: first (-Label first), last
           (-Label last).
  WHAT IT CHANGES ON THE SITE: Make adds the two objects, their columns, their permissions and two files. Person adds one
  person to the Visitors group. Office sets "edit own rows" and the PFM Office level on the probe list, adds 1 row and puts
  that person into PFM Office. Run adds 1 row. Form sets one form formatting; View adds one view. Read, Open and Ask change
  nothing on the site. Clean undoes Person and recycles the two objects. On this computer: the T21 folder (the test
  page, the state file). Every output line shows the site as <SITE> and the DODID as <DODID>; the test page holds the
  site address and stays on this computer (it is not a result file).
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell; Open
           and Ask use no network (Open hands the test page to the browser).
  Writes: the site objects listed above; on this computer the T21 folder (result files, test page, state files, the fake
          workbook) and, once, Config\90161Z-site.txt when the site address is typed outside RADE.
  Credentials: your own CAC sign-in through the PnP web login window (Connect-PnPOnline -UseWebLogin); nothing is stored.
  Output: 90161Z-T21-probe-<part>-r13.txt (make, person, office, run, look, form, view, read) or -clean-<label>-r13.txt in
  the T21 folder (send them back). Each test line (HEALTH, T4, EDITALL, BUTTON, FORM, VIEW) is followed by "RESULT <test> PASS" or
  "RESULT <test> FAIL", so the RADE step counts what the part read (R28 finding 7). Last line of each part: PROBE <part>
  done: passed=<n> failed=<n>. Exit code 0 when the part ran to its end (a FAILED test is a result); exit 1 only when the
  part could not run (sign-in, missing list, missing module file).
  Run: powershell.exe -NoProfile -File 90161Z-T21-probe-r13.ps1 -Part <part> (RADE does this).
  Parameters (used by RADE, the Redacted Application Deployment Engine): -Id, -Part, -Label, -WaitMinutes, -NoPause.
  -PollSeconds, -TestDir and -NoLaunch are for the tests in tests/run.sh (tests/ps/Test-T21.ps1).
.PARAMETER Id
  The DODID (the profile folder name); empty = the profile folder of this computer.
.PARAMETER Part
  The part to run: Make, Person, Ask, Office, Run, Look, Form, View, Open, Read or Clean.
.PARAMETER Label
  For Clean: first or last (it goes into the result file name).
.PARAMETER WaitMinutes
  How long Read waits for the health flow's row (default 4 for Read).
.PARAMETER NoPause
  No "Press Enter to close" at the end.
.PARAMETER PollSeconds
  Seconds between two checks while Read waits (tests use 1).
.PARAMETER TestDir
  Test runs only: the folder to use instead of the T21 folder.
.PARAMETER NoLaunch
  Test runs only: do not open the browser or use the clipboard.
#>
param([string]$Id, [ValidateSet('Make', 'Person', 'Ask', 'Office', 'Run', 'Look', 'Form', 'View', 'Open', 'Read', 'Clean')][string]$Part,
  [ValidateSet('', 'first', 'last')][string]$Label = '', [double]$WaitMinutes = 14, [switch]$NoPause, [int]$PollSeconds = 20,
  [string]$TestDir, [switch]$NoLaunch)
$task = 'T21'
$script:pollEvery = $PollSeconds
$script:LibTitle = '90161Z Probe Files'
$script:LibFolder = '90161ZProbeFiles'
$script:ListTitle = '90161Z Probe'
$script:ListFolder = '90161ZProbe'
$script:BookName = '90161Z-T21-fake-book-r1.xlsx'
# The test page keeps its r5 name: the round's sample page (samples/90161Z-T21-links-r5.html) has that name, and no check
# ties it to the script revision.
$script:LinksName = '90161Z-T21-links-r5.html'
# The state file keeps its r3 name: Clean finds a person that an earlier round added through it.
$script:StateName = '90161Z-T21-person-state-r3.txt'
# The part Office (F2 B): the group and the level T20 r2 makes (the same names as there; tests/ps/Test-T21.ps1 checks), and
# its own state file for Clean.
$script:OfficeGroup = 'PFM Office'
$script:OfficeLevel = 'PFM Office Edit All Items'
$script:OfficeStateName = '90161Z-T21-office-state-r8.txt'   # keeps r8: same format, so a person an r8 run left is found
$script:ViewTitle = 'ProbeButton'
$script:HeaderText = '90-161.Z test header'
$Rev = 'r13'
# The modules this file loads from its own folder (round skill section 2: scripts that load each other keep fixed names).
$ModuleNames = @('common', 'make', 'person', 'office', 'look', 'read')

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

$secret = @()
$site = ''
$lines = New-Object System.Collections.Generic.List[string]
$dir = ''
$passed = 0; $failed = 0
$fatal = $false
$script:fmtError = ''
try {
  $ErrorActionPreference = 'Stop'
  if (-not $Part) { throw 'PART not given: use -Part Make, Person, Ask, Office, Run, Look, Form, View, Open, Read or Clean.' }
  # The modules are dot-sourced here, in this script's scope, so their functions see the values above.
  foreach ($moduleName in $ModuleNames) {
    $moduleFile = Join-Path $PSScriptRoot ('90161Z-T21-' + $moduleName + '-' + $Rev + '.ps1')
    if (-not (Test-Path -LiteralPath $moduleFile -PathType Leaf)) {
      throw ('MODULE missing: 90161Z-T21-' + $moduleName + '-' + $Rev + '.ps1 is not in the folder of this script. Run the round again.')
    }
    . $moduleFile
  }
  if ($Part -eq 'Read' -and -not $PSBoundParameters.ContainsKey('WaitMinutes')) { $WaitMinutes = 4 }
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  if ($TestDir) { $dir = $TestDir } else { $dir = Get-TaskDir $id $task 'Task 21' -Create }
  Set-Location -LiteralPath $dir
  $configDir = Join-Path (Split-Path -Parent $dir) 'Config'
  $site = Get-SiteAddress $configDir
  $lines.Add('TASK T21 probe ' + $Rev + ', part ' + $Part + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + $(if ($Part -eq 'Read') { ', wait-minutes=' + $WaitMinutes } else { '' }))

  # Open and Ask work on this computer only; every other part signs in first.
  if ($Part -eq 'Open') { Invoke-OpenPart } elseif ($Part -eq 'Ask') { Invoke-AskPart }
  else {
    Connect-ProbeSite
    switch ($Part) {
      'Make' { Invoke-MakePart }
      'Person' { Invoke-PersonPart }
      'Office' { Invoke-OfficePart }
      'Run' { Invoke-RunPart }
      'Look' { Invoke-FormPart; Invoke-ViewPart }
      'Form' { Invoke-FormPart }
      'View' { Invoke-ViewPart }
      'Read' { Invoke-ReadPart }
      default { Invoke-CleanPart }
    }
    try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  }
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} catch {
  $fatal = $true
  $m = ConvertTo-Masked (Hide-Site ([string]$_) $site) $secret
  $lines.Add('STOPPED: ' + $m.Substring(0, [Math]::Min(400, $m.Length)) + ' (a part that stopped can be run again: Make skips what is there, Clean finishes what is left)')
  $lines.Add('PROBE ' + $Part + ' done: passed=' + $passed + ' failed=' + $failed)
} finally {
  # Every line is masked once more before it is shown or saved; Open writes no result file.
  $masked = @($lines | ForEach-Object { ConvertTo-Masked (Hide-Site $_ $site) $secret })
  $resultName = '90161Z-T21-probe-' + ([string]$Part).ToLowerInvariant() + $(if ($Label) { '-' + $Label } else { '' }) + '-' + $Rev + '.txt'
  if ($dir -and $Part -and $Part -ne 'Open') { try { Set-Content -LiteralPath (Join-Path $dir $resultName) -Value $masked -Encoding UTF8 } catch { $null = $_ } }
  $masked | ForEach-Object { Write-Host $_ }
  if (-not $NoPause -and -not $env:RADE_CONTRACT) { [void](Read-Host 'Press Enter to close') }
}
if ($fatal) { exit 1 }
exit 0
