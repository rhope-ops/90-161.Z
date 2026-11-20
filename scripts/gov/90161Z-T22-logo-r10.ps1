<#
.SYNOPSIS
  90-161.Z Task 22 r10, part "logo": the rail logo of the PFM window: the two logo pictures and which one shows.
.DESCRIPTION
  R10 (R37; PFM 19 Nov 26: the logo rule of the bookmark page): the logo has the Fulcrum colors when Windows apps use
  light mode and the USAF colors in dark mode ($wn.AppsLight, $wn.LogoOwn); with Windows high contrast on it is drawn in
  2 system colors, as in r8 ($wn.LogoImage, Pfm.Logo in the types part). The two pictures are the app-logo block below,
  written by scripts/build_task_scripts.py from the masters assets/logo/90161Z-logo.svg (USAF) and
  90161Z-logo-fulcrum.svg (Fulcrum); never edit it here.
  Inputs: $wn, $ui. Outputs: $AppLogoPng, $AppLogoFulcrumPng and the $wn members below (the window part builds the rail
  head with them; the -Measure run calls $wn.MeasureTheme, below).
  Run: not alone; 90161Z-T22-pfm-window-r10.ps1 dot-sources it from its own folder inside its try block.
  Network: none.
  Reads: the value AppsUseLightTheme under HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize (read only).
  Writes: nothing.
  Credentials: none.
#>
# >>> app-logo: generated from assets/logo/90161Z-logo.svg and 90161Z-logo-fulcrum.svg by scripts/build_task_scripts.py (do not edit)
$AppLogoPng = @(
  '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',
  'h1qohVo+a/8H8RLOoYx5mOYAAAAASUVORK5CYII='
) -join ''
$AppLogoFulcrumPng = @(
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
# R10 (R37): the logo in its own colors for the Windows app mode $Light: Fulcrum colors ($AppLogoFulcrumPng) in light
# mode, USAF colors ($AppLogoPng) in dark mode; both from the app-logo block.
$wn.LogoOwn = { param([bool]$Light)
  $b64 = $(if ($Light) { $AppLogoFulcrumPng } else { $AppLogoPng })
  return [Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($b64)))) }
# R8 (R35 W7): the logo picture for high contrast $High: its own colors when off (R10: Fulcrum or USAF by the app mode
# in $wn.Light, $wn.LogoOwn); when on, a copy of the USAF logo in the 2 system colors of $wn.LogoRole
# (Pfm.Logo.TwoTone; each pixel keeps its cover), as in r8.
$wn.LogoImage = { param([bool]$High)
  if (-not $High) { return (& $wn.LogoOwn ([bool]$wn.Light)) }
  $img = & $wn.LogoOwn $false
  $d = [string]$wn.LogoRole.Dark; $l = [string]$wn.LogoRole.Light
  try { return [Pfm.Logo]::TwoTone($img, [Drawing.SystemColors]::$d, [Drawing.SystemColors]::$l) } finally { $img.Dispose() } }
$wn.MeasureTheme = {
  <#
  .SYNOPSIS
  R10 (R37): the two own-color logos (Fulcrum for Windows light mode, USAF for dark mode), and the app mode of this
  computer, with no change of the Windows setting.
  .OUTPUTS
  A table: Light (the app mode read here), Fulcrum and Usaf (their sizes), Diff (pixels that differ between them, -1
  when the sizes differ) and ShownDiff (the rail logo against the own logo for this app mode; 0 = the right one).
  #>
  $f = [ordered]@{}; $f['Light'] = [bool](& $wn.AppsLight)
  $fu = & $wn.LogoOwn $true; $us = & $wn.LogoOwn $false
  try { $f['Fulcrum'] = ([string]$fu.Width + 'x' + $fu.Height); $f['Usaf'] = ([string]$us.Width + 'x' + $us.Height); $f['Diff'] = [Pfm.Logo]::Diff($fu, $us)
    $f['ShownDiff'] = $(if ($wn.Logo -and $wn.Logo.Image -and -not $ui.High) { [Pfm.Logo]::Diff($wn.Logo.Image, $(if ($wn.Light) { $fu } else { $us })) } else { -1 }) }
  finally { $fu.Dispose(); $us.Dispose() }
  return $f }
