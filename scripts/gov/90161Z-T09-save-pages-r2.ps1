<#
.SYNOPSIS
  90-161.Z page saver, r2 (Task 9 e-Publishing pages; Task 12 color documents). Windows PowerShell 5.1, Windows Forms only.
.DESCRIPTION
  A small window that says what to save and why, with Copy buttons for the folder and for each suggested file name (and
  Open buttons where the page may be linked), and a live list of the files already in the task folder. Any file name
  is accepted: the 90-161.Z Deployer attaches every .mhtml, .htm, .html and .pdf file in the folder (not the
  "_files" helper folders a browser makes). Nothing is downloaded or changed by this script.
  -Set T09: 3 e-Publishing list pages, so Claude can see how e-Publishing lays out publication numbers and titles
            (for the numbering index, PFM 1A 2A). e-Publishing cannot be linked here (its host is not on the repo's
            allow list), so the steps say where to click.
  -Set T12: the 3 public documents that set Air Force and ANG colors (scripts cannot download them: the sites answer 403
            to scripts, R09); the Open buttons open each in Edge.
  The DODID and profile folder are replaced by <DODID> in all output.
  Parameters (used by the 90-161.Z Deployer): -Id, -NoPause, -Set.
#>
param([string]$Id, [switch]$NoPause, [ValidateSet('T09', 'T12')][string]$Set = 'T09')
$task = $Set
$Kinds = @('.mhtml', '.mht', '.htm', '.html', '.pdf')
$Sets = @{
  T09 = @{
    Title = '90-161.Z Task 9 - save 3 e-Publishing list pages'
    Why = 'WHY: Claude is writing the part of 90-161.Z that reads publication numbers and titles from e-Publishing (for the numbering index). Claude cannot open e-Publishing from the cloud, so it needs 3 list pages saved exactly as Edge shows them. Only the page layout matters; any series is fine.'
    How = @(
      '1. In Edge, open e-Publishing (the Air Force publications website) and go to Product Index.',
      '2. Open a list of publications: Departmental, one series with many entries (for example series 33). If the list has a "Show entries" box, pick the largest number or All.',
      '3. Press Ctrl+S. In "Save as type" pick "Webpage, Single File (*.mhtml)".',
      '4. File name: press Copy name below, click the File name box, press Ctrl+V. Folder: press Copy folder, click the address bar at the top of the Save window, press Ctrl+V, Enter. Press Save.',
      '5. Do the same for an Air National Guard list (second name) and for my gaining MAJCOM list (third name).',
      'Other names or "Webpage, Complete" also work: every page file in the folder is sent. Press Done when finished.')
    Items = @(
      @{ Name = '90161Z-T09-epubs-departmental-r1.mhtml'; What = 'Departmental publications, one series'; Url = '' },
      @{ Name = '90161Z-T09-epubs-ang-r1.mhtml'; What = 'Air National Guard publications, one series'; Url = '' },
      @{ Name = '90161Z-T09-epubs-majcom-r1.mhtml'; What = 'My gaining MAJCOM publications, one series (do not type the MAJCOM name anywhere else)'; Url = '' })
  }
  T12 = @{
    Title = '90-161.Z Task 12 - save 3 color documents'
    Why = 'WHY: these 3 public documents set the official Air Force and ANG colors that the briefs and the app must use. The sites block scripts, so Edge saves them.'
    How = @(
      '1. Press Open next to a document: Edge opens it.',
      '2. In Edge press Ctrl+S (for the web page pick "Webpage, Single File (*.mhtml)").',
      '3. File name: press Copy name, click the File name box, Ctrl+V. Folder: press Copy folder, click the address bar of the Save window, Ctrl+V, Enter. Press Save.',
      '4. Do the same for the other two. Other names also work. Press Done when finished.')
    Items = @(
      @{ Name = '90161Z-T12-ang-graphics-standard-r1.pdf'; What = 'ANG Graphics Standard (PDF)'; Url = 'https://www.ang.af.mil/Portals/77/documents/ANG%20Graphics%20Standard.pdf' },
      @{ Name = '90161Z-T12-af-heraldry-guide-r1.pdf'; What = 'Guide to Air Force Heraldry (PDF)'; Url = 'https://www.dafhistory.af.mil/Portals/16/documents/Organizational-Records/GuideAirForceHeraldryJune2022.pdf' },
      @{ Name = '90161Z-T12-af-symbol-page-r1.mhtml'; What = 'Air Force Symbol (web page)'; Url = 'https://www.trademark.af.mil/Branding/Air-Force-Symbol/' })
  }
}

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

function Get-PageFile([string]$Dir) {
  @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue | Where-Object { $Kinds -contains $_.Extension.ToLowerInvariant() } | Sort-Object Name)
}

$secret = @()
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  $dir = Get-TaskDir $id $task ('Task ' + $Set.Substring(1)) -Create
  $s = $Sets[$Set]
  Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $dir + '"')

  Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $s.Title
  $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi'
  $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
  $form.ClientSize = New-Object System.Drawing.Size(860, 640); $form.StartPosition = 'CenterScreen'; $form.AutoScroll = $true
  $grid = New-Object System.Windows.Forms.TableLayoutPanel
  $grid.Dock = 'Fill'; $grid.Padding = New-Object System.Windows.Forms.Padding(10); $grid.ColumnCount = 1; $grid.AutoScroll = $true
  $wrap = New-Object System.Drawing.Size(800, 0)
  $add = { param($c) $grid.RowCount++; [void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); $grid.Controls.Add($c, 0, $grid.RowCount - 1) }
  $label = { param($t, [bool]$bold) $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $true; $l.MaximumSize = $wrap; $l.Text = $t
    if ($bold) { try { $l.Font = New-Object System.Drawing.Font($form.Font.FontFamily, [single]10, [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Bold')) } catch { $null = $_ } }
    $l.Margin = New-Object System.Windows.Forms.Padding(3, 3, 3, 6); $l }
  $copyRow = { param($caption, $value)
    $p = New-Object System.Windows.Forms.FlowLayoutPanel; $p.AutoSize = $true; $p.WrapContents = $true
    $tb = New-Object System.Windows.Forms.TextBox; $tb.ReadOnly = $true; $tb.Text = $value; $tb.Width = 560
    $b = New-Object System.Windows.Forms.Button; $b.Text = $caption; $b.AutoSize = $true; $b.MinimumSize = New-Object System.Drawing.Size(110, 30)
    $b.Add_Click({ try { [System.Windows.Forms.Clipboard]::SetText($tb.Text); $b.Text = 'Copied' } catch { $b.Text = 'Busy: again' } }.GetNewClosure())
    $p.Controls.AddRange(@($tb, $b)); $p }
  & $add (& $label $s.Why $true)
  foreach ($h in $s.How) { & $add (& $label $h $false) }
  & $add (& $label 'Folder (where every file goes):' $true)
  & $add (& $copyRow 'Copy folder' $dir)
  foreach ($it in $s.Items) {
    & $add (& $label ($it.What + ':') $true)
    $row = & $copyRow 'Copy name' $it.Name
    if ($it.Url) {
      $o = New-Object System.Windows.Forms.Button; $o.Text = 'Open'; $o.AutoSize = $true; $o.MinimumSize = New-Object System.Drawing.Size(80, 30); $o.Tag = $it.Url
      $o.Add_Click({ Start-Process -FilePath ([string]$this.Tag) })
      $row.Controls.Add($o)
    }
    & $add $row
  }
  & $add (& $label 'Files in the folder now (any name counts):' $true)
  $found = New-Object System.Windows.Forms.ListBox; $found.Width = 780; $found.Height = 110
  & $add $found
  $bar = New-Object System.Windows.Forms.FlowLayoutPanel; $bar.AutoSize = $true
  $state = New-Object System.Windows.Forms.Label; $state.AutoSize = $true; $state.Margin = New-Object System.Windows.Forms.Padding(3, 8, 12, 3)
  $done = New-Object System.Windows.Forms.Button; $done.Text = 'Done'; $done.AutoSize = $true; $done.MinimumSize = New-Object System.Drawing.Size(110, 32)
  $bar.Controls.AddRange(@($state, $done)); & $add $bar
  $form.Controls.Add($grid)
  $check = {
    $f = Get-PageFile $dir
    $found.BeginUpdate(); $found.Items.Clear(); foreach ($x in $f) { [void]$found.Items.Add($x.Name + '   (' + [Math]::Round($x.Length / 1KB) + ' KB)') }; $found.EndUpdate()
    $state.Text = [string]$f.Count + ' page file(s) in the folder'
  }
  $timer = New-Object System.Windows.Forms.Timer; $timer.Interval = 2000; $timer.Add_Tick({ & $check })
  $done.Add_Click({ $form.Close() })
  $form.Add_Shown({
    # Fit the screen (R09: 1280 x 800 at 150 % scaling is smaller than the window).
    $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $form.Width = [Math]::Min($form.Width, [int]($wa.Width * 0.95)); $form.Height = [Math]::Min($form.Height, [int]($wa.Height * 0.95))
    $form.Left = $wa.Left + [int](($wa.Width - $form.Width) / 2); $form.Top = $wa.Top + [int](($wa.Height - $form.Height) / 2)
    $form.TopMost = $true; $form.Activate(); $form.TopMost = $false; $timer.Start() })
  & $check
  [void]$form.ShowDialog()
  $timer.Stop(); $timer.Dispose()
  $files = Get-PageFile $dir
  foreach ($x in $files) { Write-Host ('PAGE ' + $x.Name + ' bytes=' + $x.Length) }
  Write-Host ('PAGES ' + $Set + ' found=' + $files.Count + ' (wanted ' + $s.Items.Count + ')' + $(if ($files.Count -ge $s.Items.Count) { ' PASS' } else { '' }))
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
} finally {
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
