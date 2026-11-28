<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "logo": the rail logo of the PFM window: the two logo pictures and which one shows.
.DESCRIPTION
  R11 (R38; PFM 20 Nov 26): one logo, the Fulcrum one, in Windows light and dark mode (high contrast keeps the system colors).
  R11 (R38; PFM 20 Nov 26: "Fulcrum everywhere for now, as this is not an endorsed product"): one logo, the Fulcrum one, in
  Windows light and dark mode ($wn.LogoOwn); with Windows high contrast on it keeps the 2 system colors, as in r8
  ($wn.LogoImage, ConvertTo-PfmTwoTone in the types part). The picture is the app-logo block below, written by
  scripts/build_task_scripts.py from the master assets/logo/90161Z-logo-fulcrum.svg; never edit it here. (R10 had the USAF
  logo in dark mode; the USAF master assets/logo/90161Z-logo.svg is not used any more.) The Windows app mode is still read
  ($wn.AppsLight), for the THEME line only.
  Inputs: $wn, $ui. Outputs: $AppLogoPng and the $wn members below (the window part builds the rail
  head with them; the -Measure run calls $wn.MeasureTheme, below).
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Reads: the value AppsUseLightTheme under HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize (read only).
  Writes: nothing.
  Credentials: none.
#>
# >>> app-logo: generated from assets/logo/90161Z-logo-fulcrum.svg by scripts/build_task_scripts.py (do not edit)
$AppLogoPng = @(
  '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'
) -join ''
# <<< app-logo
# R8 (R35 W7): the 2 system colors of the logo with high contrast on: the dark disc and Z take Window, the light rings,
# page and arc take WindowText (the rail behind it is WindowText, so the disc stands out from the rail).
$wn.LogoRole = @{ Dark = 'Window'; Light = 'WindowText' }
# R10 (R37; PFM 19 Nov 26: the logo rule of the bookmark page): whether Windows apps use light mode: $true when the
# value AppsUseLightTheme under HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize is 1 or missing
# (also when it cannot be read), $false when it is 0. Read only; nothing is written.
$wn.AppsLight = {
  try { $v = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop
    return ([int]$v.AppsUseLightTheme -ne 0) } catch { return $true } }
# R11 (R38; PFM 20 Nov 26): the logo in its own colors: the Fulcrum logo ($AppLogoPng, the app-logo block), in Windows light
# and dark mode alike.
$wn.LogoOwn = {
  return [Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($AppLogoPng)))) }
# R8 (R35 W7): the logo picture for high contrast $High: its own colors when off (R11: the Fulcrum logo, $wn.LogoOwn);
# when on, a copy of it in the 2 system colors of $wn.LogoRole (ConvertTo-PfmTwoTone; each pixel keeps its cover), as in r8.
$wn.LogoImage = { param([bool]$High)
  if (-not $High) { return (& $wn.LogoOwn) }
  $img = & $wn.LogoOwn
  $d = [string]$wn.LogoRole.Dark; $l = [string]$wn.LogoRole.Light
  try { return (ConvertTo-PfmTwoTone $img ([Drawing.SystemColors]::$d) ([Drawing.SystemColors]::$l)) } finally { $img.Dispose() } }
$wn.MeasureTheme = {
  <#
  .SYNOPSIS
  R11 (R38): the one own-color logo (Fulcrum, in Windows light and dark mode), and the app mode of this computer, with no
  change of the Windows setting.
  .OUTPUTS
  A table: Light (the app mode read here), Fulcrum (its size) and ShownDiff (the rail logo against the Fulcrum logo; 0 =
  the right one, -1 when no rail logo is shown or high contrast is on).
  #>
  $f = [ordered]@{}; $f['Light'] = [bool](& $wn.AppsLight)
  $fu = & $wn.LogoOwn
  try { $f['Fulcrum'] = ([string]$fu.Width + 'x' + $fu.Height)
    $f['ShownDiff'] = $(if ($wn.Logo -and $wn.Logo.Image -and -not $ui.High) { (Get-PfmPixelDiff $wn.Logo.Image $fu) } else { -1 }) }
  finally { $fu.Dispose() }
  return $f }
