# RADE sign-in window size block, copied unchanged from the RADE engine (engine-v39, engine/ps/16-site-scripts.ps1 $signInSize;
# the R42 bundle holds it). A task script that opens its own window calls Start-SignInSize -SignInOnly just before
# Connect-PnPOnline and Stop-SignInSize in a finally block after it (follow-ups 2 item 10, the Maintainer, 2026-11-25).
# Copy the lines from "RADE sign-in window size (start" to "(end)" only, and change nothing between them: when the engine
# changes the block, copy the new block here. No task script holds it yet (R43 T6 only puts it in the source folder).
# Network: none. Writes: none. Credentials: none. Windows PowerShell 5.1.
# ---- RADE sign-in window size (start; engine/ps/07-checks.ps1 $signInSize; E3, the Owner, 2026-11-21)
# The CAC sign-in window of Connect-PnPOnline -UseWebLogin (PnP.PowerShell 1.12.0) opens very large. Start-SignInSize,
# called just before Connect-PnPOnline, starts a background timer that, for up to 2 minutes, finds each new visible window
# of THIS process only (the windows of its own threads: no other process and no other host is read) and makes it about
# 480 x 360 logical pixels, in the center of the work area of its screen. The window stays visible, so it can still take
# input. Copy this block unchanged between its start and end lines (an app's task scripts may hold the same copy).
# An app script that opens its own window calls Start-SignInSize -SignInOnly (follow-ups 2 item 10, the Maintainer,
# 2026-11-25): the windows that already exist are left as they are, and only the first new window (the sign-in window)
# is sized; then the watch stops. With no switch, each new window in the 2 minutes is sized (the engine's child scripts).
# Such a script also calls Stop-SignInSize when Connect-PnPOnline returns (in a finally block): a sign-in that showed no
# window then leaves no watch behind that could size the script's own next window.
# Windows PowerShell 5.1, no module. When the helper cannot be compiled (Constrained Language Mode) or the calls fail,
# nothing changes and the sign-in goes on as before.
$SignInW = 480; $SignInH = 360; $SignInWatchMs = 120000; $SignInTickMs = 100
function Start-SignInSize {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param([switch]$SignInOnly)
  if (-not $PSCmdlet.ShouldProcess('the sign-in window of this process', 'Set its size')) { return }   # -WhatIf: no timer
  if ($env:OS -ne 'Windows_NT' -and $env:RADE_SIGNIN_TEST -ne '1') { return }   # Windows only (the cloud test sets RADE_SIGNIN_TEST to compile it)
  try {
    if (-not ('RadeSignIn.Size2' -as [type])) {   # Size2: Start takes signInOnly (a process that holds the old Size keeps it)
      Add-Type -Namespace RadeSignIn -Name Size2 -ErrorAction Stop -MemberDefinition @"
public delegate bool WinProc(System.IntPtr h, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool EnumThreadWindows(uint tid, WinProc f, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsWindowVisible(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr GetWindow(System.IntPtr h, uint cmd);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr MonitorFromWindow(System.IntPtr h, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool GetMonitorInfo(System.IntPtr m, ref MonInfo i);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern uint GetDpiForWindow(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool SetWindowPos(System.IntPtr h, System.IntPtr after, int x, int y, int cx, int cy, uint flags);
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct MonInfo { public int Size; public int ML, MT, MR, MB; public int WL, WT, WR, WB; public uint Flags; }
static System.Threading.Timer timer; static WinProc each = Each, mark = Mark; static int w, h, left; static bool one;
static System.Collections.Generic.HashSet<long> seen = new System.Collections.Generic.HashSet<long>(); static object gate = new object();
// Starts the watch: every tickMs, for watchMs, each new visible top-level window of this process gets the size w x h (logical).
// signInOnly: every window of this process that exists now (shown or not) is marked as seen, and the watch stops after it
// has sized one new window, so an app's own window is never sized.
public static void Start(int width, int height, int watchMs, int tickMs, bool signInOnly) {
  Stop();   // a watch that still runs from an earlier call ends first
  lock (gate) { w = width; h = height; one = signInOnly; left = System.Math.Max(1, watchMs / System.Math.Max(1, tickMs));
    if (one) { using (System.Diagnostics.Process me = System.Diagnostics.Process.GetCurrentProcess()) {
      foreach (System.Diagnostics.ProcessThread t in me.Threads) { EnumThreadWindows((uint)t.Id, mark, System.IntPtr.Zero); } } }
    timer = new System.Threading.Timer(Tick, null, tickMs, tickMs); } }
// Ends the watch now (no more ticks). Safe to call when no watch runs.
public static void Stop() { lock (gate) { left = 0; if (timer != null) { timer.Dispose(); timer = null; } } }
// Marks one window that exists at the start (signInOnly): it is never sized.
static bool Mark(System.IntPtr hw, System.IntPtr l) { seen.Add(hw.ToInt64()); return true; }
// One tick: a tick that starts while the last one still runs is skipped (the timer can overlap), so seen has one writer.
static void Tick(object state) {
  if (!System.Threading.Monitor.TryEnter(gate)) { return; }
  try { if (--left < 0) { if (timer != null) { timer.Dispose(); timer = null; } return; }
    using (System.Diagnostics.Process me = System.Diagnostics.Process.GetCurrentProcess()) {
      foreach (System.Diagnostics.ProcessThread t in me.Threads) { EnumThreadWindows((uint)t.Id, each, System.IntPtr.Zero); } } }
  catch { }
  finally { System.Threading.Monitor.Exit(gate); } }
// One window of this process: a visible top-level window (no owner) not seen before is sized and centered once.
static bool Each(System.IntPtr hw, System.IntPtr l) {
  if (one && left <= 0) { return false; }   // signInOnly: a window is sized already (also on the other threads of this tick)
  long k = hw.ToInt64(); if (seen.Contains(k) || !IsWindowVisible(hw) || GetWindow(hw, 4) != System.IntPtr.Zero) { return true; }
  seen.Add(k);
  int dpi = 96; try { dpi = (int)GetDpiForWindow(hw); } catch { } if (dpi <= 0) { dpi = 96; }
  int cw = w * dpi / 96, ch = h * dpi / 96;
  MonInfo mi = new MonInfo(); mi.Size = System.Runtime.InteropServices.Marshal.SizeOf(typeof(MonInfo));
  if (!GetMonitorInfo(MonitorFromWindow(hw, 2), ref mi)) { return true; }
  int x = mi.WL + System.Math.Max(0, (mi.WR - mi.WL - cw) / 2), y = mi.WT + System.Math.Max(0, (mi.WB - mi.WT - ch) / 2);
  SetWindowPos(hw, System.IntPtr.Zero, x, y, cw, ch, 0x0004 | 0x0010 | 0x4000);   // no Z order change, no activate, async
  if (one) { left = 0; return false; }   // signInOnly: one window only; the next tick ends the watch
  return true; }
"@
    }
    [RadeSignIn.Size2]::Start($SignInW, $SignInH, $SignInWatchMs, $SignInTickMs, [bool]$SignInOnly)
  } catch { $null = $_ }   # no helper: the sign-in window keeps its own size
}
function Stop-SignInSize {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param()
  if (-not $PSCmdlet.ShouldProcess('the sign-in window watch of this process', 'Stop')) { return }
  try { if ('RadeSignIn.Size2' -as [type]) { [RadeSignIn.Size2]::Stop() } } catch { $null = $_ }   # no watch: nothing to stop
}
# ---- RADE sign-in window size (end)
