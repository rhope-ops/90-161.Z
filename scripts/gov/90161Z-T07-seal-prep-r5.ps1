<#
.SYNOPSIS
  90-161.Z Task 7 seal prep, r5 (L-007, L-007a). Windows PowerShell 5.1, System.Drawing only (no modules).
.DESCRIPTION
  Uses this computer's profile folder as the DODID (no question). With no -SealDir it uses the T07\Seals folder; when
  that has no images it searches every folder of the default Outlook mailbox (r5, R12: the DoD gateway puts "[Non-DoD Source] "
  in front of outside subjects, PFM 14 Nov 26), last 30 days, newest first, for every mail whose subject contains
  "90161Z T07 seals" (Claude sends seals split over several mails) and saves their image attachments into T07\Seals;
  for a file name in more than one mail, the newest mail wins.
  Outlook is read by Subject and Attachments only (never sender or recipient properties, which raise the Outlook
  address prompt). It changes nothing in Outlook. Writes: files in T07\Seals, T07\Seals\Prepared, the result and key
  files. For each image in the seal folder:
    1. Trim: cut plain white (R, G and B 245 or more) and clear (alpha under 16) margins down to the emblem.
    2. Fit: scale the emblem so its larger side fills the box, keeping its shape.
    3. Center it on a clear 360 x 360 px square (1.20 in at 300 dpi) and save it as PNG in the "Prepared"
       subfolder, same base name. The renderer accepts only these files.
    4. Check: effective resolution = larger trimmed side / 1.20 in. Under 100 dpi = FAIL (no file written; an older prepared file of that seal is removed),
       under 150 dpi = WARN (file written).
  Output: 90161Z-T07-result-r1.txt in the T07 folder, one line per seal by number only (seal01, seal02 ...),
  and 90161Z-T07-key-r1.txt that maps numbers to file names. Send only the result file; the key stays local.
  The DODID, profile folder name and user name are replaced by <DODID> in all output.
  Parameters (used by the Deployer and the T07 seal test runner): -Id, -SealDir, -ResultName, -NoPause.
#>
param([string]$Id, [string]$SealDir, [string]$ResultName = '90161Z-T07-result-r1.txt', [switch]$NoPause)
$task = 'T07'
$BoxPx = 360            # L-007a: 1.20 in at 300 dpi
$BoxDpi = 300
$BoxIn = 1.2            # L-007: seal box 1.20 in square
$FailDpi = 100          # L-007a
$WarnDpi = 150          # L-007a
$WhiteMin = 245         # L-007a: R, G and B at or above this count as white margin
$ClearMax = 16          # L-007a: alpha under this counts as clear margin
$Extensions = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tif', '.tiff')

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

function Get-EmblemBox([System.Drawing.Bitmap]$Bmp) {
  # Returns @(left, top, right, bottom) of the non-margin pixels (inclusive), or $null when the image is all margin.
  $w = $Bmp.Width; $h = $Bmp.Height
  $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
  $data = $Bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
  } finally { $Bmp.UnlockBits($data) }
  return Get-EmblemBoxFromByte $bytes $stride $w $h $WhiteMin $ClearMax
}

function Get-EmblemBoxFromByte([byte[]]$bytes, [int]$stride, [int]$w, [int]$h, [int]$WhiteMin, [int]$ClearMax) {
  # Pure function (tested in tests/run.sh with raw pixels): BGRA bytes, row stride, size, white and clear limits.
  # Byte order per pixel in Format32bppArgb memory: B, G, R, A. A pixel is emblem ("ink") when it is neither clear
  # nor white; the test is written inline in each loop because a script-block call per pixel is slow in PS 5.1.
  $wm = [byte]$WhiteMin; $cm = [byte]$ClearMax
  $top = -1
  for ($y = 0; $y -lt $h -and $top -lt 0; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $w; $x++) { $i = $row + 4 * $x; if ($bytes[$i + 3] -ge $cm -and -not ($bytes[$i] -ge $wm -and $bytes[$i + 1] -ge $wm -and $bytes[$i + 2] -ge $wm)) { $top = $y; break } }
  }
  if ($top -lt 0) { return $null }
  $bottom = $top
  for ($y = $h - 1; $y -gt $top; $y--) {
    $row = $y * $stride; $hit = $false
    for ($x = 0; $x -lt $w; $x++) { $i = $row + 4 * $x; if ($bytes[$i + 3] -ge $cm -and -not ($bytes[$i] -ge $wm -and $bytes[$i + 1] -ge $wm -and $bytes[$i + 2] -ge $wm)) { $hit = $true; break } }
    if ($hit) { $bottom = $y; break }
  }
  $left = $w - 1
  for ($x = 0; $x -lt $w; $x++) {
    $hit = $false
    for ($y = $top; $y -le $bottom; $y++) { $i = $y * $stride + 4 * $x; if ($bytes[$i + 3] -ge $cm -and -not ($bytes[$i] -ge $wm -and $bytes[$i + 1] -ge $wm -and $bytes[$i + 2] -ge $wm)) { $hit = $true; break } }
    if ($hit) { $left = $x; break }
  }
  $right = $left
  for ($x = $w - 1; $x -gt $left; $x--) {
    $hit = $false
    for ($y = $top; $y -le $bottom; $y++) { $i = $y * $stride + 4 * $x; if ($bytes[$i + 3] -ge $cm -and -not ($bytes[$i] -ge $wm -and $bytes[$i + 1] -ge $wm -and $bytes[$i + 2] -ge $wm)) { $hit = $true; break } }
    if ($hit) { $right = $x; break }
  }
  return @($left, $top, $right, $bottom)
}

function Save-PreparedSeal([System.Drawing.Bitmap]$Src, [int[]]$Box, [string]$OutPath) {
  $ew = $Box[2] - $Box[0] + 1; $eh = $Box[3] - $Box[1] + 1
  $scale = $BoxPx / [double]([Math]::Max($ew, $eh))
  $dw = [int][Math]::Round($ew * $scale); $dh = [int][Math]::Round($eh * $scale)
  $dx = [int][Math]::Floor(($BoxPx - $dw) / 2); $dy = [int][Math]::Floor(($BoxPx - $dh) / 2)   # centered (PFM 2A)
  # Premultiplied alpha on both sides, so bicubic scaling does not pull dark edges in from clear pixels.
  $srcP = $Src.Clone((New-Object System.Drawing.Rectangle 0, 0, $Src.Width, $Src.Height), [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
  $out = New-Object System.Drawing.Bitmap $BoxPx, $BoxPx, ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
  $out.SetResolution($BoxDpi, $BoxDpi)
  $g = [System.Drawing.Graphics]::FromImage($out)
  try {
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)   # no gray fringe at the edges
    $dest = New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh
    $g.DrawImage($srcP, $dest, $Box[0], $Box[1], $ew, $eh, [System.Drawing.GraphicsUnit]::Pixel, $attr)
  } finally { $g.Dispose(); if ($attr) { $attr.Dispose() }; $srcP.Dispose() }
  $out.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
  return @($dw, $dh)
}

$secret = @()
try {
  $ErrorActionPreference = 'Stop'
  Add-Type -AssemblyName System.Drawing
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret

  $dir = Get-TaskDir $id $task 'Task 7' -Create
  Set-Location -LiteralPath $dir

  $lines = New-Object System.Collections.Generic.List[string]
  $sealDir = [string]$SealDir
  if (-not $sealDir) {
    $sealDir = Join-Path $dir 'Seals'
    if (-not (Test-Path -LiteralPath $sealDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $sealDir) }
    $have = @(Get-ChildItem -LiteralPath $sealDir -File -ErrorAction SilentlyContinue | Where-Object { $Extensions -contains $_.Extension.ToLowerInvariant() })
    if ($have.Count -eq 0) {
      Write-Host 'No seal images in T07\Seals. Searching every Outlook mail folder (last 30 days) for mail "90161Z T07 seals".'
      $saved = 0; $found = 0; $failed = 0; $searched = 0
      try {
        $ol = New-Object -ComObject Outlook.Application
        $ns = $ol.GetNamespace('MAPI')
        $queue = New-Object System.Collections.Queue
        # Every folder of the default mailbox (rules can file mail outside the Inbox); mail folders only (olMailItem = 0).
        try { $queue.Enqueue($ns.DefaultStore.GetRootFolder()) } catch { $queue.Enqueue($ns.GetDefaultFolder(6)) }
        $folders = @()
        while ($queue.Count) {
          $f = $queue.Dequeue()
          try { if ($f.DefaultItemType -eq 0) { $folders += $f } } catch { $null = $_ }
          try { foreach ($sub in $f.Folders) { $queue.Enqueue($sub) } } catch { $null = $_ }
        }
        $cut = (Get-Date).AddDays(-30)
        foreach ($folder in $folders) {
          $searched++
          # Filter to the last 30 days before sorting, so a large mailbox stays fast (review R13).
          try { $items = $folder.Items.Restrict("[ReceivedTime] >= '" + $cut.ToString('g') + "'") } catch { $items = $folder.Items }
          try { if ($items.Count -eq 0) { continue }; $items.Sort('[ReceivedTime]', $true) } catch { continue }
          foreach ($m in $items) {
            try {
              if ($m.Class -ne 43) { continue }
              if ($m.ReceivedTime -lt $cut) { break }
              if (([string]$m.Subject) -notlike '*90161Z T07 seals*') { continue }   # the DoD gateway puts "[Non-DoD Source] " in front (R12)
              $found++
              foreach ($att in $m.Attachments) {
                $leafName = Split-Path -Leaf ([string]$att.FileName)
                $target = Join-Path $sealDir $leafName
                if ($leafName -match '^image\d+\.') { continue }   # signature and inline pictures, not seals
                if ($Extensions -contains [System.IO.Path]::GetExtension($leafName).ToLowerInvariant() -and
                    -not (Test-Path -LiteralPath $target -PathType Leaf)) {   # newest mail wins for a file name
                  try { $att.SaveAsFile($target); $saved++ } catch { $failed++ }
                }
              }
            } catch { $null = $_ }
          }
        }
        Write-Host ('Outlook search complete: ' + $searched + ' folders searched, ' + $found + ' matching e-mails, ' + $saved + ' images saved.')
      } catch {
        Write-Host ('Outlook could not be read: ' + (ConvertTo-Masked ([string]$_.Exception.Message) $secret))
      }
      $lines.Add('OUTLOOK folders-searched=' + $searched + ' mail-found=' + $found + ' images-saved=' + $saved + ' save-failed=' + $failed)
    }
  }
  if (-not (Test-Path -LiteralPath $sealDir -PathType Container)) { throw 'SEAL FOLDER not found at the path given.' }
  $prep = Join-Path $sealDir 'Prepared'
  if (-not (Test-Path -LiteralPath $prep)) { New-Item -ItemType Directory -Path $prep | Out-Null }

  $files = @(Get-ChildItem -LiteralPath $sealDir -File | Where-Object { $Extensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object Name)
  if ($files.Count -eq 0) { throw 'NO IMAGES: T07\Seals is empty and Outlook holds no e-mail "90161Z T07 seals" with images (every mail folder searched, last 30 days). Tell Claude the seal e-mails did not arrive, or save the seal images into T07\Seals and run the round again.' }

  $log = Join-Path $dir $ResultName
  $keyFile = Join-Path $dir ([System.IO.Path]::GetFileNameWithoutExtension($ResultName) -replace 'result', 'key')
  $keyFile = $keyFile + '.txt'
  $keys = New-Object System.Collections.Generic.List[string]
  $lines.Add('TASK T07 seal prep r5, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ', box ' + $BoxPx + ' px at ' + $BoxDpi + ' dpi')
  $keys.Add('Key for 90161Z-T07-result-r1.txt. Keep this file on this computer; do not send it.')
  $n = 0; $pass = 0; $warn = 0; $fail = 0
  $outNames = @{}
  foreach ($f in $files) {
    $n++
    $tag = 'seal' + $n.ToString('00')
    $keys.Add($tag + ' = ' + $f.Name)
    Write-Host ($tag + ' working...')
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $outPath = Join-Path $prep ($base + '.png')
    if ($outNames.ContainsKey($base.ToLowerInvariant())) {   # a.png and a.jpg would write the same prepared file
      $fail++; $lines.Add("$tag FAIL same name as $($outNames[$base.ToLowerInvariant()]) with another extension: rename one file"); continue
    }
    $outNames[$base.ToLowerInvariant()] = $tag
    # A seal that fails must not leave an older prepared file the renderer would still accept.
    if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }
    $img = $null; $bmp = $null
    try {
      $img = [System.Drawing.Image]::FromFile($f.FullName)
      $bmp = New-Object System.Drawing.Bitmap $img.Width, $img.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      $gg = [System.Drawing.Graphics]::FromImage($bmp); $gg.DrawImage($img, 0, 0, $img.Width, $img.Height); $gg.Dispose()
      $box = Get-EmblemBox $bmp
      if ($null -eq $box) { $fail++; $lines.Add("$tag FAIL source=$($img.Width)x$($img.Height) the image is all white or clear"); continue }
      $ew = $box[2] - $box[0] + 1; $eh = $box[3] - $box[1] + 1
      $dpi = [int][Math]::Floor([Math]::Max($ew, $eh) / $BoxIn)
      $trimmed = ($ew -lt $img.Width -or $eh -lt $img.Height)
      $shape = 'round or square'
      $ratio = $ew / [double]$eh
      if ($ratio -lt 0.95) { $shape = 'tall' } elseif ($ratio -gt 1.05) { $shape = 'wide' }
      $info = "source=$($img.Width)x$($img.Height) emblem=${ew}x${eh} trimmed=$trimmed shape=$shape dpi=$dpi"
      if ($dpi -lt $FailDpi) { $fail++; $lines.Add("$tag FAIL $info (under $FailDpi dpi: get a larger file; nothing written)"); continue }
      $size = Save-PreparedSeal $bmp $box $outPath
      $placed = "placed=$($size[0])x$($size[1]) in ${BoxPx}x$BoxPx"
      if ($dpi -lt $WarnDpi) { $warn++; $lines.Add("$tag WARN $info $placed (under $WarnDpi dpi: may print soft)") }
      else { $pass++; $lines.Add("$tag PASS $info $placed") }
    } catch {
      $fail++; $lines.Add("$tag FAIL cannot read or write the image (details on screen only)")
      Write-Host ("$tag detail: " + (ConvertTo-Masked ([string]$_.Exception.Message) $secret))
    } finally {
      if ($bmp) { $bmp.Dispose() }
      if ($img) { $img.Dispose() }
    }
  }
  $lines.Add("SEALS total=$n pass=$pass warn=$warn fail=$fail")
  $masked = @($lines | ForEach-Object { ConvertTo-Masked $_ $secret })
  Set-Content -LiteralPath $log -Value $masked -Encoding UTF8
  Set-Content -LiteralPath $keyFile -Value $keys -Encoding UTF8
  $masked | ForEach-Object { Write-Host $_ }
  Write-Host ''
  Write-Host ('Saved: ' + $ResultName + ' (send this) and ' + (Split-Path -Leaf $keyFile) + ' (keep this) in the T07 folder.')
  Write-Host 'Prepared seals are in the "Prepared" folder inside the seal library.'
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
} finally {
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
