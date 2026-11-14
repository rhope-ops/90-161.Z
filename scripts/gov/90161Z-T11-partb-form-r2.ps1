<#
.SYNOPSIS
  90-161.Z Task 11 Part B form, r2. Windows PowerShell 5.1, Windows Forms only (no modules).
.DESCRIPTION
  Shows the Part B manual checks (docs/rights-test-plan.md section 6, from 90161Z-T11-partb-rows-r1.json in the T11
  folder) as one table: for each row pick Allowed, Blocked, Error, Not offered or Not done, and add a short note.
  Every change is saved at once to 90161Z-T11-partb-r1.txt in the T11 folder, and earlier answers come back when
  the form opens again, so the checks can be done over several sittings. Notes must hold no names, site
  addresses or group names (write "my AD group", "the office mailbox"). The notes go only into the result file;
  the screen output shows counts. The DODID and profile folder are replaced by <DODID>.
  Output: 90161Z-T11-partb-r1.txt in the T11 folder (send this).
  Parameters (used by the 90-161.Z Deployer): -Id, -NoPause.
#>
param([string]$Id, [switch]$NoPause)
$task = 'T11'
$RowsName = '90161Z-T11-partb-rows-r1.json'
$ResultName = '90161Z-T11-partb-r1.txt'
$Choices = @('', 'Allowed', 'Blocked', 'Error', 'Not offered', 'Not done')

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

function Read-PartBAnswer([string]$Path) {
  # Earlier answers: lines "M03 | Allowed | note". Returns a hashtable id -> @(result, note).
  $map = @{}
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    foreach ($l in @(Get-Content -LiteralPath $Path -Encoding UTF8)) {
      $p = $l -split '\s\|\s', 3
      if ($p.Count -ge 2 -and $p[0] -match '^M\d\d$') { $map[$p[0]] = @($p[1].Trim(), $(if ($p.Count -ge 3) { $p[2].Trim() } else { '' })) }
    }
  }
  return $map
}

$secret = @()
try {
  $ErrorActionPreference = 'Stop'
  $who = Get-TaskId $Id
  $id = $who.Id
  $secret = $who.Secret
  $dir = Get-TaskDir $id $task 'Task 11' -Create
  Set-Location -LiteralPath $dir
  Assert-TaskFile $dir @($RowsName) 'MISSING in T11 (the round saves it): '
  $rows = @((Get-Content -LiteralPath (Join-Path $dir $RowsName) -Raw -Encoding UTF8 | ConvertFrom-Json).rows)
  $resultPath = Join-Path $dir $ResultName
  $old = Read-PartBAnswer $resultPath

  Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $form = New-Object System.Windows.Forms.Form
  $form.Text = '90-161.Z Task 11 Part B - manual checks'
  $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi'
  $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
  $form.ClientSize = New-Object System.Drawing.Size(1100, 720); $form.StartPosition = 'CenterScreen'
  $grid = New-Object System.Windows.Forms.TableLayoutPanel
  $grid.Dock = 'Fill'; $grid.Padding = New-Object System.Windows.Forms.Padding(10); $grid.ColumnCount = 1; $grid.RowCount = 3
  foreach ($h in 'AutoSize', 'Percent', 'AutoSize') { [void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle($h, 100))) }
  $help = New-Object System.Windows.Forms.Label
  $help.AutoSize = $true; $help.MaximumSize = New-Object System.Drawing.Size(1060, 0)
  $help.Text = 'Do each row (Power Automate, Power Apps, Outlook, SharePoint), then pick the result and add a short note. ' +
    'Saved after every change; you can close and come back. NO names, site addresses or group names in notes: write "my AD group", "the office mailbox". ' +
    'Do M19 (clean up) last.'
  $dg = New-Object System.Windows.Forms.DataGridView
  $dg.Dock = 'Fill'; $dg.AllowUserToAddRows = $false; $dg.AllowUserToDeleteRows = $false; $dg.RowHeadersVisible = $false
  $dg.AutoSizeRowsMode = 'AllCells'; $dg.SelectionMode = 'CellSelect'
  $dg.DefaultCellStyle.WrapMode = 'True'
  $c1 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c1.HeaderText = '#'; $c1.ReadOnly = $true; $c1.Width = 50
  $c2 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c2.HeaderText = 'Do'; $c2.ReadOnly = $true; $c2.Width = 470
  $c3 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c3.HeaderText = 'Write down'; $c3.ReadOnly = $true; $c3.Width = 200
  $c4 = New-Object System.Windows.Forms.DataGridViewComboBoxColumn; $c4.HeaderText = 'Result'; $c4.Width = 120
  [void]$c4.Items.AddRange($Choices)
  $c5 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c5.HeaderText = 'Note (no names)'; $c5.AutoSizeMode = 'Fill'
  # Typed array: PowerShell cannot pass object[] to AddRange (R09: the form stopped here).
  [void]$dg.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@($c1, $c2, $c3, $c4, $c5))
  foreach ($r in $rows) {
    $res = ''; $note = ''
    if ($old.ContainsKey($r.id)) { $res = $old[$r.id][0]; $note = $old[$r.id][1] }
    $res = [string](@($Choices | Where-Object { $_ -eq $res }) | Select-Object -First 1)   # the list item itself (exact case), or ''
    [void]$dg.Rows.Add($r.id, $r.do, $r.note, $res, $note)
  }
  $status = New-Object System.Windows.Forms.FlowLayoutPanel
  $status.AutoSize = $true; $status.Dock = 'Fill'
  $count = New-Object System.Windows.Forms.Label; $count.AutoSize = $true; $count.Margin = New-Object System.Windows.Forms.Padding(3, 8, 12, 3)
  $done = New-Object System.Windows.Forms.Button; $done.Text = 'Save and close'; $done.AutoSize = $true; $done.MinimumSize = New-Object System.Drawing.Size(140, 32)
  $status.Controls.AddRange(@($count, $done))
  $grid.Controls.Add($help, 0, 0); $grid.Controls.Add($dg, 0, 1); $grid.Controls.Add($status, 0, 2)
  $form.Controls.Add($grid)

  $save = {
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('TASK T11 Part B r2, ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' (format: check | result | note)')
    $n = 0
    foreach ($row in $dg.Rows) {
      $res = [string]$row.Cells[3].Value; $note = ([string]$row.Cells[4].Value) -replace '[\r\n|]+', ' '
      if ($res) { $n++ }
      $out.Add([string]$row.Cells[0].Value + ' | ' + $res + ' | ' + $note.Trim())
    }
    $out.Add('PARTB answered=' + $n + ' of ' + $dg.Rows.Count)
    try {
      Set-Content -LiteralPath $resultPath -Value @($out | ForEach-Object { ConvertTo-Masked $_ $secret }) -Encoding UTF8
      $count.Text = 'Answered ' + $n + ' of ' + $dg.Rows.Count + ' - saved ' + (Get-Date -Format 'HH:mm:ss')
    } catch { $count.Text = 'NOT SAVED (the file is open or OneDrive is busy): close it; the next change saves again.' }
    $script:answered = $n
  }
  $dg.Add_CurrentCellDirtyStateChanged({ if ($dg.IsCurrentCellDirty -and $dg.CurrentCell.ColumnIndex -eq 3) { $dg.CommitEdit('CurrentCellChange') } })   # the result list saves at once; a note saves when you leave the cell
  $dg.Add_DataError({ $_.ThrowException = $false })   # a value the list does not hold shows as empty, never as an error box
  $dg.Add_CellValueChanged({ & $save })
  $done.Add_Click({ [void]$dg.EndEdit(); & $save; $form.Close() })   # a note still being typed is saved too
  $form.Add_Shown({
    # Fit the screen (R09: 1280 x 800 at 150 % scaling is smaller than the window).
    $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $form.Width = [Math]::Min($form.Width, [int]($wa.Width * 0.95)); $form.Height = [Math]::Min($form.Height, [int]($wa.Height * 0.95))
    $form.Left = $wa.Left + [int](($wa.Width - $form.Width) / 2); $form.Top = $wa.Top + [int](($wa.Height - $form.Height) / 2)
    $form.TopMost = $true; $form.Activate(); $form.TopMost = $false })
  $script:answered = 0
  & $save
  [void]$form.ShowDialog()
  [void]$dg.EndEdit()
  & $save
  $total = $dg.Rows.Count
  if ($script:answered -eq $total) { Write-Host ('PARTB PASS answered=' + $script:answered + ' of ' + $total) }
  else { Write-Host ('PARTB partial answered=' + $script:answered + ' of ' + $total + ' (send it anyway; finish the rest in the next round)') }
  Write-Host ('Saved: ' + $ResultName + ' in the T11 folder (notes are only in that file).')
} catch {
  $msg = [string]$_
  if ($secret) { $msg = ConvertTo-Masked $msg $secret }
  Write-Host ''
  Write-Host ('STOPPED: ' + $msg)
} finally {
  if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
