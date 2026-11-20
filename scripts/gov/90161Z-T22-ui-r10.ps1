<#
.SYNOPSIS
  90-161.Z Task 22 r10, part "ui": the RADE shared UI file (colors, fonts, buttons, card text boxes, layout self-check),
  generated into this file, and the few names it needs from the window.
.DESCRIPTION
  The block between the rade-ui markers is written by scripts/build_task_scripts.py from the pinned RADE commit
  (scripts/rade.lock.json); never edit it here. It runs inside the main script's try block, after $ui.Form exists,
  and fills $ui. The lines above the block give it what it reads from a RADE window: $apps (one test application, so
  the layout self-check runs), $dot, $round and Test-Deploy. The lines after the block choose the colors for Windows
  high contrast (R31 W2): Select-T22Color and $ui.UseColors (the window part applies them: $wn.Recolor).
  Inputs: $ui with $ui.Form (made by the main script), $pc. Outputs: the $ui members of the shared UI file, $ui.HcRole,
  $ui.OwnPc, $ui.OwnC, $ui.High, $ui.UseColors and the function Select-T22Color.
  Run: not alone; 90161Z-T22-pfm-window-r10.ps1 dot-sources it from its own folder.
  Network: none.
  Writes: none.
  Credentials: none.
#>
$apps = @(@{ Mode = 'test' }); Set-Variable -Name dot -Value ''; Set-Variable -Name round -Value ''
# This window is never a deploy: the layout self-check of the shared UI file always runs.
function Test-Deploy { return $false }
# >>> rade-ui: generated from the pinned RADE shared UI file by scripts/build_task_scripts.py (do not edit)
# RADE shared UI file (engine/rade_ui.ps1): the theme tokens (colors, fonts, sizes), the builders for buttons, links and
# card text, the drawing and measuring helpers, and the layout self-check. rade_build.py puts this text into every bundle
# at its marker line (docs/engine.md "How an app gets the engine"); it runs inside the window's try block, after
# $ui.Form exists, and fills $ui. An app window can reuse it: same $ui, same names. ASCII only (a bundle is ASCII).
# Needs from the window: $ui (a hashtable), $ui.Form, the globals $apps, $dot, $round and the engine function
# ConvertTo-Masked and Test-Deploy (only the self-check uses them).

# ---- Scale and colors
# One scale source (R24: the screen dpi said 96 while Windows Forms scaled every control 1.5 x): $ui.Dpi is the dpi the
# form scales to (its auto-scale dimensions; the form's sizes are given at 96). Every size RADE sets or draws after the
# form has scaled goes through $ui.Sc. The screen dpi is only reported (the SCALE line).
try { $gx = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $ui.ScreenDpi = [double]$gx.DpiX; $gx.Dispose() } catch { $null = $_ }
$ui.FormDpi = { try { $d = [double]$ui.Form.CurrentAutoScaleDimensions.Width; if ($d -gt 0) { $ui.Dpi = $d } } catch { $null = $_ } }
$ui.Sc = { param([double]$Px) [int][math]::Round($Px * $ui.Dpi / 96.0) }   # a size at 100 % in screen pixels, for parts made or drawn after the form has scaled
# Colors: one meaning each. Navy = text and focus; Air Force blue = the action and progress; yellow = your turn;
# dark red = FAILED, NEEDS REVIEW and the one destructive action; green = passed. Contrast on white: ink 15.6, gray 5.9,
# blue 7.7, red 9.3, green word 6.4, control edge 3.7 to 1. Non-text parts (R28) are at least 3 to 1 against white: the bar track and the edge of a button that is not available are Track (#7F93A8, 3.2 to 1), the status light has a 1 px navy line.
$ui.C = @{ Navy = [System.Drawing.Color]::FromArgb(11, 37, 69); Blue = [System.Drawing.Color]::FromArgb(0, 83, 159); Yellow = [System.Drawing.Color]::FromArgb(255, 213, 32)
  Green = [System.Drawing.Color]::FromArgb(46, 133, 64); GreenInk = [System.Drawing.Color]::FromArgb(31, 107, 49); Red = [System.Drawing.Color]::FromArgb(139, 26, 26)
  Ink = [System.Drawing.Color]::FromArgb(27, 36, 48); Gray = [System.Drawing.Color]::FromArgb(90, 101, 115); Edge = [System.Drawing.Color]::FromArgb(122, 135, 148)
  Hair = [System.Drawing.Color]::FromArgb(227, 232, 238); Track = [System.Drawing.Color]::FromArgb(127, 147, 168); Off = [System.Drawing.Color]::FromArgb(233, 236, 240); OffInk = [System.Drawing.Color]::FromArgb(85, 85, 85); White = [System.Drawing.Color]::White }
# ---- Fonts, sizes and buttons
# Cosmetics never stop the window (R06: Font('Segoe UI', 10, 'Bold') failed with "Multiple ambiguous overloads"): a typed
# style and size, and the window font when a font cannot be made.
$ui.Bold = [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Bold')
# $Pt is the size at 100 % scaling; $ui.FontK (R28: text scales with the controls) makes it as much bigger as the controls are.
$ui.Font = { param([string]$Fam, [double]$Pt, $Style) try { $pk = [single]($Pt * $ui.FontK); if ($null -ne $Style) { return (New-Object System.Drawing.Font($Fam, $pk, $Style)) }; return (New-Object System.Drawing.Font($Fam, $pk)) } catch { return $ui.Form.Font } }
# FontScale: how much bigger than the screen's own text scaling the fonts must be, so that text follows the controls. A probe
# font of 100 pt Segoe UI is 177 px tall when the screen draws text at 96 dpi; its real height gives the dpi the text is drawn
# at. On the R25 device (autoScale 144, text at 96) the answer is 1.5; where Windows scales both, it is 1. The factor is
# kept to steps of 0.25 (the Windows scales); anything odd gives 1.
$ui.FontScale = { $ui.FontK = 1.0; $ui.FontDpi = 96.0
  try { $pf = New-Object System.Drawing.Font('Segoe UI', [single]100); $r = [double]$pf.Height / 177.3; try { $pf.Dispose() } catch { $null = $_ }
    if ($r -gt 0.6 -and $r -lt 4) { $k = [math]::Round(($ui.Dpi / 96.0) / $r * 4) / 4; if ($k -ge 0.5 -and $k -le 4) { $ui.FontK = [double]$k }; $ui.FontDpi = 96.0 * [math]::Max(1.0, [math]::Round($r * 4) / 4) } } catch { $null = $_ } }
& $ui.FormDpi; & $ui.FontScale; $ui.Form.Font = (& $ui.Font 'Segoe UI' 10 $null)
# Text styles (the Administrator, 2026-11-17; docs/window-design.md "Fixed parts"): one typeface, four styles and the logo
# word. Sent = headline (semibold 22); Body = paragraphs, step lines, help line (12); Small = second lines, notes, box text
# (10); SmallB = semibold 10: the line in capitals, labels, every button, key numbers, the Record's heads and result words.
# Link = SmallB underlined (a link is marked by more than color). Word = RADE in the logo line. Mono = the Record's text box only.
# Turn = Body size, bold: the "Your turn" line of a card where RADE waits for the person.
$ui.F = @{ Small = $ui.Form.Font; SmallB = (& $ui.Font 'Segoe UI Semibold' 10 $null); Body = (& $ui.Font 'Segoe UI' 12 $null); Sent = (& $ui.Font 'Segoe UI Semibold' 22 $null)
  Link = (& $ui.Font 'Segoe UI Semibold' 10 ([Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Underline'))); Word = (& $ui.Font 'Segoe UI' 15 $ui.Bold); Mono = (& $ui.Font 'Consolas' 9 $null)
  Turn = (& $ui.Font 'Segoe UI' 12 $ui.Bold) }   # Turn: "Your turn" above the headline (the Administrator, 2026-11-19: bold, in the accent color)
# Sizes, in pixels at 100 % (docs/window-design.md "Sizes"): one place for the button sizes and the gaps between the
# parts of a card. Action = a card's buttons; compact = a button beside a box and the Record's "Back"; a link is 28 high.
# Gaps are on the scale 4, 8, 12, 16, 24. A button or link has a 4 px margin (room for the 2 px focus ring), so two
# of them are 8 px apart.
$ui.Z = @{ ActionW = 132; ActionH = 40; CompactW = 110; CompactH = 30; LinkH = 28; BarTop = 11; M = 4; G1 = 4; G2 = 8; G3 = 12; G4 = 16; G6 = 24 }
$ui.Pad = { param([int]$L, [int]$T, [int]$R, [int]$B) New-Object System.Windows.Forms.Padding($L, $T, $R, $B) }
$ui.Label = { param($Font, $Color, [int]$Top) $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $true; $l.Font = $Font; $l.ForeColor = $Color; $l.BackColor = $ui.C.White; $l.UseMnemonic = $false; $l.Margin = (& $ui.Pad 0 $Top 0 0); $l.Visible = $false; $l }
# ---- Card text that can be selected (R28, the Administrator, 2026-11-17)
# The headline, the lines, the help, the notes and the questions of a card are read-only, borderless text boxes: the same look as
# a label, but the text can be highlighted and copied (Ctrl+C, or right-click: Copy, Select All). No tab stop, no caret shown.
# A text box does not size itself to its text, so $ui.Reflow gives it the size the text needs (measured as the edit control wraps:
# WordBreak, TextBoxControl) whenever its text, its font or its wrap width changes. The wrap width is $ui.Wrap[box] (set with
# $ui.SetWrap): a text box's own MaximumSize would cut the few extra pixels the edit control keeps at its edges.
$ui.Wrap = @{}
# A text box with a fixed number of lines ($ui.Hold[box] = n): $ui.Reflow makes it n lines tall whatever its text, also with no
# text, so the parts under it never move when the text changes (the Run card's now-doing line: the Administrator, 2026-11-19,
# "the cancel button jumps up and down"). Its text is cut to n lines with $ui.FitLines.
$ui.Hold = @{}
# A text box with a least number of lines ($ui.MinLines[box] = n): at least n lines tall, also with no text (the line in
# capitals: the "Your turn" line under it never moves up on a card with no line).
$ui.MinLines = @{}
# A text box that shows changing values ($ui.Range[box] = every text it can show on this card, set by $ui.SetCard): it is as
# wide and as tall as the largest of them, so a new value never moves or resizes a part of the card (the Administrator,
# 2026-11-19: "values cause fluttering and distortion as things fly around").
$ui.Range = @{}
$ui.GetWrap = { param($C) if ($C -is [System.Windows.Forms.TextBox]) { return [int]$ui.Wrap[$C] }; return [int]$C.MaximumSize.Width }
$ui.SetWrap = { param($C, [int]$W) if ($C -is [System.Windows.Forms.TextBox]) { $ui.Wrap[$C] = $W; & $ui.Reflow $C } else { $C.MaximumSize = New-Object System.Drawing.Size($W, 0) } }
$ui.Reflow = { param($T)
  try { $txt = [string]$T.Text; $n = [int]$ui.Hold[$T]
    if ($n -gt 0) {   # a fixed number of lines: as wide as its wrap width, n lines tall
      $w = [int]$ui.Wrap[$T]; $one = & $ui.Meas 'Ag' $T.Font 100000
      $ns = New-Object System.Drawing.Size($(if ($w -gt 0) { $w + (& $ui.Sc 4) } else { $one.Width }), ($n * $one.Height + (& $ui.Sc 2))); if ($T.Width -ne $ns.Width -or $T.Height -ne $ns.Height) { $T.Size = $ns }; return }
    $all = @(@($ui.Range[$T]) + @($txt) | Where-Object { $_ }); $m = [int]$ui.MinLines[$T]; if (-not $all.Count -and $m -le 0) { return }   # its text and its range
    $w = [int]$ui.Wrap[$T]; $bw = 0; $bh = 0
    foreach ($x in $all) { $s = & $ui.TextSize ([string]$x) $T.Font $w; $bw = [math]::Max($bw, $s.Width); $bh = [math]::Max($bh, $s.Height) }
    if ($m -gt 0) { $bw = [math]::Max($bw, (& $ui.Sc 4)); $bh = [math]::Max($bh, ($m * (& $ui.Meas 'Ag' $T.Font 100000).Height + (& $ui.Sc 2))) }
    $ns = New-Object System.Drawing.Size($bw, $bh); if ($T.Width -ne $ns.Width -or $T.Height -ne $ns.Height) { $T.Size = $ns } } catch { $null = $_ } }
# The size a card text box needs for one text: as the edit control wraps it at the wrap width (0: no wrap), with the few
# pixels the control keeps at its edges. Takes the text, the font and the wrap width; gives back the size.
$ui.TextSize = { param([string]$Txt, $Font, [int]$W)
  $sl = & $ui.Sc 4; $one = & $ui.Meas $Txt $Font 100000; $sz = $one
  if ($W -gt 0 -and $one.Width -gt $W) { $sz = & $ui.Meas $Txt $Font $W; $bw = $W + $sl } else { $bw = $one.Width + 2 * $sl }
  return (New-Object System.Drawing.Size($bw, ($sz.Height + (& $ui.Sc 2)))) }
$ui.Menu = New-Object System.Windows.Forms.ContextMenuStrip; $ui.Menu.AccessibleName = 'Text menu'
$ui.MenuCopy = $ui.Menu.Items.Add('Copy'); $ui.MenuAll = $ui.Menu.Items.Add('Select All')
# Copy gives the text as written (R28 N4): a word that RADE broke to fit a line is whole again (the break is a lone line feed), and the
# lines of a hand step (a rich text box) lose the tabs of their number column: "1. Open the page." on its own line.
$ui.CopyText = { param($C)
  try { if (-not ($C -is [System.Windows.Forms.TextBoxBase]) -or $C.SelectionLength -le 0) { return $false }
    $s = [string]$C.SelectedText
    if ($C -is [System.Windows.Forms.RichTextBox]) { $s = ($s -replace '\r?\n', "`n" -replace ([string][char]0x2007), '' -replace '\t', ' ') -replace "`n", "`r`n" }
    elseif (& $ui.IsCardText $C) { $s = $s -replace '(?<!\r)\n', '' }
    if ($s) { [System.Windows.Forms.Clipboard]::SetText($s); return $true } } catch { $null = $_ }
  return $false }
# R34 (the PFM: the answer box did not take a pasted block): a one-line box keeps only the first line of a paste, so a
# paste into it comes here. $ui.OneLine joins the lines of a text with one space and cuts it to the room that is left.
# Takes the text and the room (characters); gives back the text to put in.
$ui.OneLine = { param([string]$T, [int]$Room) $s = ($T -replace '\s*(\r\n|\r|\n)\s*', ' ' -replace '\t', ' ').Trim(); if ($Room -lt 0) { $Room = 0 }; if ($s.Length -gt $Room) { $s = $s.Substring(0, $Room) }; return $s }
# Pastes the clipboard text into a one-line text box as one line, in place of its selection. When the text is longer
# than the room, it is cut and the gray line under the box says how many characters did not fit (R7, the Administrator,
# 2026-11-19; docs/window-design.md "Cards"). Takes the box; gives back $true when it pasted (the key is then handled),
# $false when the clipboard has no text or the box is multi-line.
$ui.PasteLine = { param($Tb)
  try { if ($Tb.Multiline -or $Tb.ReadOnly -or -not [System.Windows.Forms.Clipboard]::ContainsText()) { return $false }
    $room = [int]$Tb.MaxLength - ([string]$Tb.Text).Length + [int]$Tb.SelectionLength
    $whole = & $ui.OneLine ([System.Windows.Forms.Clipboard]::GetText()) ([int]::MaxValue)
    $Tb.SelectedText = & $ui.OneLine $whole $room
    $lost = $whole.Length - [math]::Max(0, $room)
    $msg = $(if ($lost -gt 0) { 'The paste was too long: ' + $lost.ToString('N0', [System.Globalization.CultureInfo]::InvariantCulture) + $(if ($lost -eq 1) { ' character did' } else { ' characters did' }) + ' not fit.' } else { '' })
    if ($msg) { & $ui.Say1 $msg; $ui.PasteNote = $msg } elseif ($ui.PasteNote -and [string]$ui.Note.Text -ceq [string]$ui.PasteNote) { & $ui.Say1 ''; $ui.PasteNote = '' }   # clear only a note this paste wrote
    return $true } catch { return $false } }
$ui.MenuCopy.Add_Click({ $null = & $ui.CopyText $ui.Menu.SourceControl })
$ui.MenuAll.Add_Click({ try { $ui.Menu.SourceControl.SelectAll() } catch { $null = $_ } })
$ui.Menu.Add_Opening({ try { $ui.MenuCopy.Enabled = [bool]($ui.Menu.SourceControl.SelectionLength -gt 0) } catch { $null = $_ } })
$ui.NoCaret = { param($C) try { if ($script:native) { $null = [Rade.Native]::HideCaret($C.Handle) } } catch { $null = $_ } }
$ui.Text = { param($Font, $Color, [int]$Top, [string]$Name)
  $t = New-Object System.Windows.Forms.TextBox; $t.Multiline = $true; $t.ReadOnly = $true; $t.WordWrap = $true; $t.ScrollBars = 'None'; $t.BorderStyle = 'None'; $t.TabStop = $false; $t.AutoSize = $false
  $t.Font = $Font; $t.ForeColor = $Color; $t.BackColor = $ui.C.White; $t.Margin = (& $ui.Pad 0 $Top 0 0); $t.Visible = $false; $t.ContextMenuStrip = $ui.Menu; $t.AccessibleName = $Name
  $ui.Wrap[$t] = 0; $t.Add_TextChanged({ & $ui.Reflow $this }); $t.Add_FontChanged({ & $ui.Reflow $this })
  $t.Add_GotFocus({ & $ui.NoCaret $this }); $t.Add_MouseUp({ & $ui.NoCaret $this }); $t.Add_KeyUp({ & $ui.NoCaret $this }); $t }
$ui.InField = { $a = $ui.Form.ActiveControl; return [bool](($a -is [System.Windows.Forms.TextBox]) -and $a.TabStop) }   # a box the user types in (card text is not one)
$ui.Flow = { param([int]$Top) $f = New-Object System.Windows.Forms.FlowLayoutPanel; $f.AutoSize = $true; $f.WrapContents = $false; $f.BackColor = $ui.C.White; $f.Margin = (& $ui.Pad 0 $Top 0 0); $f.Visible = $false; $f }
# Focus is always visible: a 2 px navy ring around the control that has it, drawn by its parent ($ui.Ring), also after a
# mouse click. Each focusable control tells its parent to repaint ($ui.Cue) and keeps a 4 px margin for the ring.
$ui.Cue = { param($C) $C.Add_GotFocus({ try { $this.Parent.Invalidate() } catch { $null = $_ } }); $C.Add_LostFocus({ try { $this.Parent.Invalidate() } catch { $null = $_ } }) }
$ui.Ring = { param($P) $P.Add_Paint({ try { foreach ($c in $this.Controls) { if (($c.Focused -or ($ui.Boxes -contains $c -and $c.ContainsFocus)) -and $c.Visible) { $pn = New-Object System.Drawing.Pen($ui.C.Navy, [single](& $ui.Sc 2)); $b = $c.Bounds; $o = & $ui.Sc 2; $_.Graphics.DrawRectangle($pn, ($b.Left - $o), ($b.Top - $o), ($b.Width + 2 * $o - 1), ($b.Height + 2 * $o - 1)); $pn.Dispose() } } } catch { $null = $_ } }) }
$ui.Style = { param($B, [string]$Kind)
  # primary = Air Force blue; danger = dark red; off = not available (gray, text 6.3:1); dangeroff = the destructive
  # action while it is not available (gray, dark red text and edge, 8:1); else white with a gray edge. The colors under
  # the pointer and while pressed are set here too (Windows picks its own otherwise): a white button goes to the hair
  # and the off gray, a blue or dark red button keeps its color.
  $B.Enabled = ($Kind -notin 'off', 'dangeroff'); $B.FlatStyle = 'Flat'; $B.FlatAppearance.BorderSize = 1; $B.Font = $ui.F.SmallB; $over = $null; $down = $null
  if ($Kind -eq 'off') { $B.BackColor = $ui.C.Off; $B.ForeColor = $ui.C.OffInk; $B.FlatAppearance.BorderColor = $ui.C.Track }
  elseif ($Kind -eq 'dangeroff') { $B.BackColor = $ui.C.Off; $B.ForeColor = $ui.C.Red; $B.FlatAppearance.BorderColor = $ui.C.Red }
  elseif ($Kind -eq 'primary') { $B.BackColor = $ui.C.Blue; $B.ForeColor = $ui.C.White; $B.FlatAppearance.BorderColor = $ui.C.Blue }
  elseif ($Kind -eq 'danger') { $B.BackColor = $ui.C.Red; $B.ForeColor = $ui.C.White; $B.FlatAppearance.BorderColor = $ui.C.Red }
  else { $B.BackColor = $ui.C.White; $B.ForeColor = $ui.C.Navy; $B.FlatAppearance.BorderColor = $ui.C.Edge; $over = $ui.C.Hair; $down = $ui.C.Off }
  if (-not $over) { $over = $B.BackColor; $down = $B.BackColor }
  try { $B.FlatAppearance.MouseOverBackColor = $over; $B.FlatAppearance.MouseDownBackColor = $down } catch { $null = $_ } }
# Every button draws its own face, border and text in every state (normal, under the pointer, pressed, focused, default,
# not available), over what Windows drew: no theme border, no black default-button border, no dotted focus rectangle
# (R24: a black or gray outline on a work computer). The focus is the navy ring its parent draws ($ui.Ring).
$ui.Hot = $null; $ui.Down = $null
# A card's buttons and choices take no click in the first $ui.GuardMs (400) ms after the card changed (R2 review: the second
# click of a double-click on Done answered the first question unseen). Enter and Space click the same buttons: same guard.
# Monotonic time (a Stopwatch, not the wall clock: M1 review); a negative elapsed time never blocks a click.
$ui.Settled = { $e = $ui.Clock.Elapsed.TotalMilliseconds - [double]$ui.CardAt; ($e -ge $ui.GuardMs -or $e -lt 0) }
$ui.Face = { param($B, $G) try { if (-not $B.Text) { return }
    $w = $B.ClientSize.Width; $h = $B.ClientSize.Height; $fa = $B.FlatAppearance
    # While RADE is busy a button does nothing, so it looks like one that is not available (R28), except the ones marked to work then (Cancel).
    $busy = [bool]($ui.Busy -and -not (($B.Tag -is [int]) -and $ui.Always[[int]$B.Tag]))
    $bg = $(if ($busy -and [int]$fa.BorderSize -gt 0) { $ui.C.Off } elseif (-not $B.Enabled) { $B.BackColor } elseif ([object]::ReferenceEquals($ui.Down, $B)) { $fa.MouseDownBackColor } elseif ([object]::ReferenceEquals($ui.Hot, $B)) { $fa.MouseOverBackColor } else { $B.BackColor })
    $G.Clear($bg)
    if ([int]$fa.BorderSize -gt 0) { $pn = New-Object System.Drawing.Pen($(if ($busy) { $ui.C.Track } else { $fa.BorderColor })); $G.DrawRectangle($pn, 0, 0, ($w - 1), ($h - 1)); $pn.Dispose() }
    # A link (no edge) draws its text at the left, a button in the middle (R28: a link in a wide box started 38 px right of the card edge).
    & $ui.Word $G ([string]$B.Text) $B.Font $(if ($busy) { $ui.C.OffInk } else { $B.ForeColor }) 0 0 $w $h $(if ([int]$fa.BorderSize -gt 0) { 'HorizontalCenter, VerticalCenter, NoPrefix, SingleLine' } else { 'Left, VerticalCenter, NoPrefix, SingleLine' }) } catch { $null = $_ } }
$ui.Own = { param($B) $B.UseVisualStyleBackColor = $false; $B.Add_Paint({ & $ui.Face $this $_.Graphics })
  $B.Add_MouseEnter({ $ui.Hot = $this; $this.Invalidate() }); $B.Add_MouseLeave({ if ([object]::ReferenceEquals($ui.Hot, $this)) { $ui.Hot = $null }; $this.Invalidate() })
  $B.Add_MouseDown({ if ([string]$_.Button -eq 'Left') { $ui.Down = $this; $this.Invalidate() } }); $B.Add_MouseUp({ $ui.Down = $null; $this.Invalidate() })
  $B.Add_VisibleChanged({ if ([object]::ReferenceEquals($ui.Hot, $this)) { $ui.Hot = $null }; if ([object]::ReferenceEquals($ui.Down, $this)) { $ui.Down = $null } }) }
# $Kind: 'action' (a card's buttons) or 'compact' (beside a box; the Record's "Back"). Sizes: $ui.Z.
$ui.Btn = { param([string]$Kind) $b = New-Object System.Windows.Forms.Button; $b.AutoSize = $true; $b.AutoSizeMode = 'GrowAndShrink'   # a button that showed a long text shrinks back for the next card
  $b.MinimumSize = $(if ($Kind -eq 'compact') { New-Object System.Drawing.Size($ui.Z.CompactW, $ui.Z.CompactH) } else { New-Object System.Drawing.Size($ui.Z.ActionW, $ui.Z.ActionH) })
  $b.Padding = (& $ui.Pad 12 0 12 0); $b.Margin = (& $ui.Pad $ui.Z.M $ui.Z.M $ui.Z.M $ui.Z.M); $b.UseMnemonic = $false; & $ui.Style $b ''; & $ui.Cue $b; & $ui.Own $b; $b }
$ui.LinkBtn = { param([string]$Text) $b = New-Object System.Windows.Forms.Button; $b.Text = $Text; $b.AutoSize = $true; $b.AutoSizeMode = 'GrowAndShrink'; $b.MinimumSize = New-Object System.Drawing.Size(0, $ui.Z.LinkH); $b.Margin = (& $ui.Pad $ui.Z.M $ui.Z.M $ui.Z.M $ui.Z.M); $b.UseMnemonic = $false
  $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0; $b.BackColor = $ui.C.White; $b.ForeColor = $ui.C.Blue; $b.Font = $ui.F.Link; try { $b.FlatAppearance.MouseOverBackColor = $ui.C.White; $b.FlatAppearance.MouseDownBackColor = $ui.C.Hair } catch { $null = $_ }; & $ui.Cue $b; & $ui.Own $b; $b }   # a link: Air Force blue, semibold and underlined (not color alone), 28 high
# ---- Where ink starts
$ui.Inks = @{}
$ui.Ink = { param($C)
  if ($C -is [System.Windows.Forms.ButtonBase] -and [int]$C.FlatAppearance.BorderSize -gt 0) { return 0 }
  # R28 (the Kick fix): the control is brought to the size the layout will give it BEFORE the cache key is made. The key held
  # the width the control had before it was resized, so a text measured at one width was used for another.
  try { if ($C.AutoSize -and $C.Text) { $pz = $C.PreferredSize; if ($C.Width -ne $pz.Width -or $C.Height -ne $pz.Height) { $C.Size = $pz } } } catch { $null = $_ }
  $f = $C.Font; $k = $C.GetType().Name + '|' + $f.Name + '|' + $f.SizeInPoints + '|' + $f.Style + '|' + ([string]$C.Text).PadRight(2).Substring(0, 2) + '|' + $(if ($C -is [System.Windows.Forms.ButtonBase] -or $C -is [System.Windows.Forms.Panel]) { [string]$C.Width + 'x' + $C.Height } else { '' })
  if ($ui.Inks.ContainsKey($k)) { return [int]$ui.Inks[$k] }
  $v = [int][math]::Ceiling([double]$f.SizeInPoints * $ui.FontDpi / 72.0 / 6.0); $got = $false
  if (-not $C.Text -and -not ($C -is [System.Windows.Forms.Panel])) { return $v }   # nothing drawn: nothing to measure
  try { $w = [math]::Max(1, $C.Width); $h = [math]::Max(1, $C.Height); $bm = New-Object System.Drawing.Bitmap($w, $h)
    try { $C.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $w, $h))); $bg = $C.BackColor; $hit = -1
      for ($x = 0; $x -lt [math]::Min($w, (& $ui.Sc 40)) -and $hit -lt 0; $x++) { for ($y = 0; $y -lt $h; $y++) { $px = $bm.GetPixel($x, $y); if ([math]::Abs($px.R - $bg.R) + [math]::Abs($px.G - $bg.G) + [math]::Abs($px.B - $bg.B) -gt 90) { $hit = $x; break } } }
      if ($hit -ge 0) { $v = $hit; $got = $true } } finally { $bm.Dispose() } } catch { $null = $_ }
  if ($got) { $ui.Inks[$k] = $v }; return $v }   # only a measure is kept; the estimate is tried again next time
$ui.SetLeft = { param($C, [int]$L) $L = [math]::Max(0, $L); $m = $C.Margin; if ($m.Left -ne $L) { $C.Margin = New-Object System.Windows.Forms.Padding($L, $m.Top, $m.Right, $m.Bottom) } }
# ---- Text that RADE draws ink-tight (L2, the Administrator, 2026-11-19: the header)
# A label keeps empty room above its capitals and under its baseline (about 5 and 7 px for the word RADE), so two labels
# can never be 9 px apart ink to ink. The word RADE and the application name are panels that draw their own text and are
# exactly as tall as the ink: from the top of the capitals to the baseline (the word) or to the bottom of a "g" (a name).
# $ui.FontInk measures those rows for a font one time: "H" and "g" drawn into a bitmap by Windows. Without a bitmap (the
# test stand-ins) it gives an estimate from the text height.
$ui.FontInks = @{}
# The first and last row and column of a bitmap that hold ink (a pixel that differs from white). Takes the bitmap; gives
# back @{ Top; Bottom; Left; Right } (Bottom and Right are one past the ink), or $null when the bitmap has no ink.
$ui.InkScan = { param($Bm)
  $t = -1; $b = -1; $l = $Bm.Width; $r = -1
  for ($y = 0; $y -lt $Bm.Height; $y++) { for ($x = 0; $x -lt $Bm.Width; $x++) { $px = $Bm.GetPixel($x, $y)
      if ((255 - $px.R) + (255 - $px.G) + (255 - $px.B) -gt 90) { if ($t -lt 0) { $t = $y }; $b = $y; if ($x -lt $l) { $l = $x }; if ($x -gt $r) { $r = $x } } } }
  if ($t -lt 0) { return $null }
  return @{ Top = $t; Bottom = $b + 1; Left = $l; Right = $r + 1 } }
# Draws a text in black on a white bitmap, as $ui.InkPaint draws it (no padding, one line), and gives back its ink box
# ($ui.InkScan), or $null when nothing can be drawn (no System.Drawing bitmap). Takes the text and the font.
$ui.InkOf = { param([string]$Text, $Font)
  try { $fl = [System.Windows.Forms.TextFormatFlags]'Left, Top, NoPadding, NoPrefix, SingleLine'
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font, (New-Object System.Drawing.Size(100000, 0)), $fl)
    $bm = New-Object System.Drawing.Bitmap(([math]::Max(1, [int]$sz.Width + 4)), ([math]::Max(1, [int]$sz.Height + 4)))
    try { $g = [System.Drawing.Graphics]::FromImage($bm); $g.Clear([System.Drawing.Color]::White)
      [System.Windows.Forms.TextRenderer]::DrawText($g, $Text, $Font, (New-Object System.Drawing.Point(0, 0)), [System.Drawing.Color]::Black, [System.Drawing.Color]::White, $fl); $g.Dispose()
      return (& $ui.InkScan $bm) } finally { $bm.Dispose() } } catch { return $null } }
# The rows of a font's ink in a text cell: Top = the top of the capitals, Base = the baseline (one past the bottom of "H"),
# Bottom = one past the bottom of "g". Measured one time for each font; an estimate when it cannot be measured.
$ui.FontInk = { param($Font)
  $k = [string]$Font.Name + '|' + $Font.SizeInPoints + '|' + $Font.Style; if ($ui.FontInks.ContainsKey($k)) { return $ui.FontInks[$k] }
  $h = 18; try { $h = [int][System.Windows.Forms.TextRenderer]::MeasureText('Hg', $Font).Height } catch { $null = $_ }   # no measure: the height of the form font
  $v = @{ Top = [int][math]::Round($h * 0.27); Base = [int][math]::Round($h * 0.8); Bottom = $h }
  $a = & $ui.InkOf 'H' $Font; $d = & $ui.InkOf 'g' $Font
  if ($a -and $d) { $v = @{ Top = [int]$a.Top; Base = [int]$a.Bottom; Bottom = [int][math]::Max($a.Bottom, $d.Bottom) }; $ui.FontInks[$k] = $v }   # only a measure is kept
  return $v }
# Makes a panel that draws its own Text ink-tight. Takes the font, the color, the screen-reader name and whether the
# panel keeps room for descenders ($true: a name; $false: capitals only, the panel ends on the baseline). Gives back the
# panel; $ui.InkFit sizes it when its text changes and when the window has its scale.
$ui.InkText = { param($Font, $Color, [string]$Name, [bool]$Desc)
  $p = New-Object System.Windows.Forms.Panel; $p.Font = $Font; $p.ForeColor = $Color; $p.BackColor = $ui.C.White; $p.Margin = (& $ui.Pad 0 0 0 0); $p.Size = New-Object System.Drawing.Size(1, 1)
  $p.AccessibleRole = 'StaticText'; $p.AccessibleName = $Name; $p.Tag = @{ Desc = $Desc; Left = 0; MaxW = 0; Cut = $false }; $p.Visible = $false
  $p.Add_Paint({ & $ui.InkPaint $this $_.Graphics }); $p.Add_TextChanged({ & $ui.InkFit $this }); $p }
# Sizes an ink-tight panel to its text: as wide as the ink (at most Tag.MaxW when that is set: the text then ends with
# "...") and as tall as the font's ink rows. Does nothing before the window has its scale. Takes the panel.
$ui.InkFit = { param($P)
  if (-not $ui.Scaled) { return }
  try { $fi = & $ui.FontInk $P.Font; $h = $(if ($P.Tag.Desc) { $fi.Bottom } else { $fi.Base }) - $fi.Top; $w = 1; $P.Tag.Left = 0
    if ($P.Text) { $box = & $ui.InkOf ([string]$P.Text) $P.Font
      if ($box) { $P.Tag.Left = [int]$box.Left; $w = [int]$box.Right - [int]$box.Left }
      else { $w = [int][System.Windows.Forms.TextRenderer]::MeasureText([string]$P.Text, $P.Font).Width } }
    $P.Tag.Cut = ([int]$P.Tag.MaxW -gt 0 -and $w -gt [int]$P.Tag.MaxW)   # cut = the text is wider than its widest size: only then it ends with "..."
    if ($P.Tag.Cut) { $w = [int]$P.Tag.MaxW }
    $ns = New-Object System.Drawing.Size(([math]::Max(1, $w)), ([math]::Max(1, $h))); if ($P.Width -ne $ns.Width -or $P.Height -ne $ns.Height) { $P.Size = $ns }
    if ($P.Text) { $P.AccessibleName = [string]$P.Text }; $P.Invalidate() } catch { $null = $_ } }   # no size now: the next fit sizes it
# Draws the text of an ink-tight panel: moved left and up by the empty room of its text cell, so the ink starts at the
# panel's left and top edge; a text cut to its widest size (Tag.Cut) ends with "...". Takes the panel and its Graphics.
$ui.InkPaint = { param($P, $G)
  try { $G.Clear($P.BackColor); if (-not $P.Text) { return }
    $fi = & $ui.FontInk $P.Font; $l = [int]$P.Tag.Left
    # R32 (the Administrator, 2026-11-18: "RA..." at 150 %): the panel is as wide as the ink, and Windows needs the text's whole
    # cell (the ink and the last letter's side room, 1 or 2 px more at a large size) or it ends the text with "...". So a text
    # that is not cut gets room past the panel's edge (nothing is drawn there) and no "..." rule; a cut text keeps both.
    $room = $P.ClientSize.Width + $l; $fl = 'Left, Top, NoPadding, NoPrefix, SingleLine, EndEllipsis'
    if (-not $P.Tag.Cut) { $room += [int][math]::Max(8, $fi.Bottom); $fl = 'Left, Top, NoPadding, NoPrefix, SingleLine' }
    [System.Windows.Forms.TextRenderer]::DrawText($G, [string]$P.Text, $P.Font, (New-Object System.Drawing.Rectangle((-$l), (-[int]$fi.Top), $room, ([int]$fi.Bottom + 4))), $P.ForeColor, $P.BackColor, [System.Windows.Forms.TextFormatFlags]$fl) } catch { $null = $_ } }   # drawing never stops the window
# Where the ink of a control is, measured on what Windows drew (DrawToBitmap; the first 240 px of its width): gives back
# @{ Top; Bottom; Left; Right } in the control's own pixels, or its whole box when it cannot be measured. Takes the control.
$ui.InkBox = { param($C)
  $all = @{ Top = 0; Bottom = [int]$C.Height; Left = 0; Right = [int]$C.Width }
  try { $w = [math]::Max(1, [math]::Min([int]$C.Width, (& $ui.Sc 240))); $h = [math]::Max(1, [int]$C.Height); $bm = New-Object System.Drawing.Bitmap($w, $h)
    try { $C.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $w, $h))); $box = & $ui.InkScan $bm; if ($box) { return $box } } finally { $bm.Dispose() } } catch { $null = $_ }   # no bitmap (the test stand-ins): the whole box
  return $all }
# ---- Long words and one-line texts
# A word wider than the line (no space in it) is cut into pieces that fit, one per line: it wraps by character and is
# never clipped (R7 review). Only what the window shows changes; the report keeps the text.
# The width a label needs to show a text in one line: asked of a label that is never shown, with the same font and flags
# as the window's labels (R24 job: TextRenderer's default flags gave 3 to 9 px more than a label uses).
$ui.Probe = New-Object System.Windows.Forms.Label; $ui.Probe.AutoSize = $true; $ui.Probe.UseMnemonic = $false; $ui.Trash = @(@($ui.Trash) | Where-Object { $_ }) + @($ui.Probe)   # disposed when the window has closed
$ui.WordW = { param([string]$T, $F) try { $ui.Probe.Font = $F; $ui.Probe.Text = $T; return [int]$ui.Probe.PreferredSize.Width } catch { return [int][System.Windows.Forms.TextRenderer]::MeasureText($T, $F).Width } }
$ui.Most = @{}   # the widest values of each label of changing values ($ui.FixW)
# A label that shows changing values (a percent, a count, a time; $ui.Most[label] = the widest values it can show) keeps one
# size: as wide as the widest of them and one line tall, so nothing beside it moves when the value changes (the
# Administrator, 2026-11-19). A value wider than all of them still fits: the label grows for it. Does nothing before the
# window has its scale (Windows Forms would scale the size again). Takes the label; gives back nothing.
$ui.FixW = { param($L) if (-not $ui.Scaled) { return }
  try { $w = 0; foreach ($x in @(@($ui.Most[$L]) + @([string]$L.Text) | Where-Object { $_ })) { $w = [math]::Max($w, (& $ui.WordW ([string]$x) $L.Font)) }
    $ui.Probe.Font = $L.Font; $ui.Probe.Text = '0'; $h = [int]$ui.Probe.PreferredSize.Height; if ($L.AutoSize) { $L.AutoSize = $false }
    if ($L.Width -ne $w -or $L.Height -ne $h) { $L.Size = New-Object System.Drawing.Size($w, $h) } } catch { $null = $_ } }   # no measure: the next fit sets it
# The height of one line of text in a font, as Windows draws it (TextRenderer: on a 150 % screen it can be taller than
# what a text box gives itself; R35 "Field line cut: one line needs 32 high, has 27"). Takes the font; gives back pixels.
$ui.LineH = { param($Font) [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $Font).Height }
$ui.BreakLong = { param([string]$T, $F, [int]$W)
  if ($W -le 0 -or -not $T) { return $T }
  $parts = foreach ($ln in ($T -split '(\r?\n)')) {   # line by line; the line breaks are kept
    if ($ln -match '^\r?\n$') { $ln; continue }
    $ws = foreach ($wd in ($ln -split ' ')) {
      if ((& $ui.WordW $wd $F) -le $W) { $wd; continue }
      # by text element (M4 review): a surrogate pair or a letter with its accents is never split
      $pc = @(); $cur = ''; $en = [System.Globalization.StringInfo]::GetTextElementEnumerator($wd)
      while ($en.MoveNext()) { $ch = [string]$en.GetTextElement(); if ($cur -and (& $ui.WordW ($cur + $ch) $F) -gt $W) { $pc += $cur; $cur = '' }; $cur += $ch }
      $pc += $cur; $pc -join "`n" }
    @($ws) -join ' ' }
  return (@($parts) -join '') }
# ---- Shortened text
# A one-line text cut to fit a width with "..." at the end, measured by the control itself (M5 review: no AutoEllipsis,
# which shows a tooltip). Binary search on the number of text elements.
$ui.Shorten = { param($C, [string]$Full, [int]$W)
  $C.Text = $Full; if ($C.PreferredSize.Width -le $W) { return }
  $si = New-Object System.Globalization.StringInfo($Full); $lo = 0; $hi = $si.LengthInTextElements
  while ($lo -lt $hi) { $mid = [int][math]::Ceiling(($lo + $hi) / 2.0); $C.Text = $si.SubstringByTextElements(0, $mid).TrimEnd() + '...'; if ($C.PreferredSize.Width -le $W) { $lo = $mid } else { $hi = $mid - 1 } }
  $C.Text = $(if ($lo -gt 0) { $si.SubstringByTextElements(0, $lo).TrimEnd() } else { '' }) + '...' }
# Cuts a text to N lines with "..." (the help below).
$ui.FitLines = {
  <#
  .SYNOPSIS
  Cuts a text to at most N lines at a width, with "..." at its end when it is cut (the Administrator, 2026-11-19).
  .DESCRIPTION
  Measured as a card text box wraps ($ui.Meas). Binary search on the number of text elements, so a letter with its accents
  is never split. The text is not changed when it fits.
  .PARAMETER T
  The text.
  .PARAMETER F
  The font it shows in.
  .PARAMETER W
  The wrap width, in pixels.
  .PARAMETER N
  The most lines it may take.
  .OUTPUTS
  The text that fits, as a string.
  #>
  param([string]$T, $F, [int]$W, [int]$N)
  if (-not $T -or $W -le 0 -or $N -le 0) { return $T }
  $most = $N * (& $ui.Meas 'Ag' $F 100000).Height
  if ((& $ui.Meas $T $F $W).Height -le $most) { return $T }
  $si = New-Object System.Globalization.StringInfo($T); $lo = 0; $hi = $si.LengthInTextElements
  while ($lo -lt $hi) { $mid = [int][math]::Ceiling(($lo + $hi) / 2.0); $x = $si.SubstringByTextElements(0, $mid).TrimEnd() + '...'; if ((& $ui.Meas $x $F $W).Height -le $most) { $lo = $mid } else { $hi = $mid - 1 } }
  return ($(if ($lo -gt 0) { $si.SubstringByTextElements(0, $lo).TrimEnd() } else { '' }) + '...') }
# The self-check's rule for it: a word of a text that wraps is never wider than the line the text may take (a label's
# MaximumSize, a card text box's $ui.GetWrap; else the word is cut). Not the label's own width: a wrapping label is as wide
# as its widest line by its own measure, about 1 % narrower than the probe's, so a cut piece that is the widest line would
# always seem too wide (R28 job: 591/588, 597/591, 592/588).
$ui.WordBad = { param([string]$Card, [string]$Name, [string]$Text, $F, [int]$W)
  foreach ($wd in ($Text -split '\s+')) { if ($wd) { $ww = & $ui.WordW $wd $F; if ($ww -gt $W + 1) { return ('LAYOUT ' + $Card + ' ' + $Name + ' text: the word "' + $(if ($wd -match '[\\/]') { '<a path>' } elseif ($wd.Length -gt 20) { $wd.Substring(0, 20) + '...' } else { $wd }) + '" needs ' + $ww + ', the line is ' + $W) } } }
  return $null }
# ---- Drawing and measuring
$ui.Word = { param($G, [string]$Text, $Font, $Color, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Flags) [System.Windows.Forms.TextRenderer]::DrawText($G, $Text, $Font, (New-Object System.Drawing.Rectangle($X, $Y, [math]::Max(1, $W), $H)), $Color, [System.Windows.Forms.TextFormatFlags]$Flags) }
# The size of a text that wraps at a width (the real font; docs/window-design.md "Text lengths").
$ui.Meas = { param([string]$Text, $Font, [int]$W) [System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font, (New-Object System.Drawing.Size([math]::Max(1, $W), 0)), [System.Windows.Forms.TextFormatFlags]'WordBreak, NoPrefix, TextBoxControl') }
# ---- The layout self-check
# ---- The layout self-check (docs/window-design.md "Proof"): in a test round, and in the Windows job, RADE measures each
# card it showed: a text that needs more room than its control has, a control that a parent cuts, two parts that
# overlap. The result is one line under "Window: OK" in the results e-mail draft ("PASS layout" or the defects), so a
# cut text is found by a measure, not by a person's eye. A deploy does not run it. It reads sizes only.
$ui.LayOn = $false; $ui.LayBad = New-Object System.Collections.Generic.List[string]; $ui.LaySeen = @{}; $ui.LayCards = @{}; $ui.LayScroll = @{}
try { $ui.LayOn = [bool]([System.Windows.Forms.Application].GetMethod('SetCompatibleTextRenderingDefault') -and ($env:RADE_LAYOUT -eq '1' -or @($apps | Where-Object { [string]$_.Mode -ne 'deploy' }).Count)) } catch { $null = $_ }   # the real Windows Forms only: the test stand-ins have no layout
$ui.NameOf = { param($C)
  foreach ($k in @($ui.Keys)) { if ([object]::ReferenceEquals($ui[$k], $C)) { return [string]$k } }
  foreach ($k in 'B', 'P') { for ($i = 0; $ui[$k] -and $i -lt @($ui[$k]).Count; $i++) { if ([object]::ReferenceEquals($ui[$k][$i], $C)) { return ($k + $i) } } }
  return $C.GetType().Name }
# ---- The alignment rules
# The alignment rules (docs/window-design.md "Sizes"), on measured numbers so the tests can give them a layout:
# RowBad: the parts of an aligned row (@{ N; Top; H; Kind }) share one midpoint within 1 px, and a box and a button in
# it are as tall as each other. EdgeBad: the visible left edges of a card's parts (@{ N; X }) are within 1 px.
$ui.RowBad = { param([string]$Card, [string]$Row, $Parts)
  # A row that wraps (the test extras in a small window) has a midpoint on each line: Line = the top of a part's margin box.
  $out = @(); $byLine = [ordered]@{}; foreach ($q in @($Parts | Where-Object { $_ })) { $k = [string][int]$q.Line; if (-not $byLine.Contains($k)) { $byLine[$k] = @() }; $byLine[$k] += $q }
  if ($byLine.Count -gt 1) { foreach ($k in @($byLine.Keys)) { $out += & $ui.RowBad $Card $Row @($byLine[$k] | ForEach-Object { $c = $_.Clone(); $c.Line = 0; $c }) }; return $out }
  $tol = [math]::Max(1, (& $ui.Sc 1)); $ps = @($Parts | Where-Object { $_ }); if ($ps.Count -lt 2) { return $out }
  $m0 = $ps[0].Top + $ps[0].H / 2.0
  foreach ($q in $ps) { $m = $q.Top + $q.H / 2.0; if ([math]::Abs($m - $m0) -gt $tol) { $out += ('LAYOUT ' + $Card + ' ' + $Row + ' ' + $q.N + ' midpoint: ' + $m + ', the row midpoint is ' + $m0) } }
  $bx = @($ps | Where-Object { $_.Kind -eq 'box' }); $bt = @($ps | Where-Object { $_.Kind -eq 'button' })
  foreach ($a in $bx) { foreach ($b in $bt) { if ([math]::Abs($a.H - $b.H) -gt $tol) { $out += ('LAYOUT ' + $Card + ' ' + $Row + ' heights: box ' + $a.N + ' ' + $a.H + ', button ' + $b.N + ' ' + $b.H) } } }
  return $out }
$ui.EdgeBad = { param([string]$Card, $Edges)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1)); $es = @($Edges | Where-Object { $_ }); if ($es.Count -lt 2) { return $out }
  foreach ($e in $es) { if ([math]::Abs($e.X - $es[0].X) -gt $tol) { $out += ('LAYOUT ' + $Card + ' ' + $e.N + ' edge: starts at ' + $e.X + ', the card edge is ' + $es[0].X + ' (' + $es[0].N + ')' + $(if ($e.D) { ' [' + $e.D + ']' } else { '' })) } }
  return $out }
# HeadBad (R29b V1): the ink of the word RADE and of the line under it (@{ N; X }) start at the same x; any difference is a defect.
$ui.HeadBad = { param([string]$Card, $Title, $Sub)
  if ([int]$Title.X -eq [int]$Sub.X) { return @() }
  return @('LAYOUT ' + $Card + ' header ' + $Sub.N + ' edge: starts at ' + $Sub.X + ', ' + $Title.N + ' starts at ' + $Title.X) }
# HeadRuleBad (L2, the Administrator, 2026-11-19; it replaces the 4 px box gap of R29b V1): without an application logo,
# under the word RADE comes a gap, a thin line as wide as the word's ink and on its left edge, the same gap, then the
# capitals of the application name. Takes the card, the measured numbers @{ WordBottom; WordLeft; WordW; RuleTop;
# RuleBottom; RuleLeft; RuleW; AppTop } (AppTop $null: a name with no capital, digit or tall letter is not measured) and
# the gap it must be (4 px, scaled); the tolerance is 1 px, scaled. Gives back the defect lines.
$ui.HeadRuleBad = { param([string]$Card, $M, [int]$Want)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1))
  $g1 = [int]$M.RuleTop - [int]$M.WordBottom; if ([math]::Abs($g1 - $Want) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header gap: ' + $g1 + ' between the word RADE and the line, the gap is ' + $Want) }
  if ($null -ne $M.AppTop) { $g2 = [int]$M.AppTop - [int]$M.RuleBottom; if ([math]::Abs($g2 - $Want) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header gap: ' + $g2 + ' between the line and the application name, the gap is ' + $Want) } }
  if ([math]::Abs([int]$M.RuleW - [int]$M.WordW) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header line: ' + $M.RuleW + ' wide, the word RADE is ' + $M.WordW) }
  if ([math]::Abs([int]$M.RuleLeft - [int]$M.WordLeft) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header line: starts at ' + $M.RuleLeft + ', the word RADE starts at ' + $M.WordLeft) }
  return $out }
# AboveBad (L3, the Administrator, 2026-11-19): a label above its box. The label's bottom is not under the box's top, the
# box starts on the card's edge and it is as wide as the card's text (from the edge to the end of the text column), each
# within 1 px (scaled). Takes the card and @{ LabelBottom; BoxTop; BoxLeft; BoxW; Edge; TextW }; gives back the defect lines.
$ui.AboveBad = { param([string]$Card, $M)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1))
  if ([int]$M.BoxTop -lt [int]$M.LabelBottom) { $out += ('LAYOUT ' + $Card + ' FieldRow label: its bottom is at ' + $M.LabelBottom + ', the box starts at ' + $M.BoxTop) }
  if ([math]::Abs([int]$M.BoxLeft - [int]$M.Edge) -gt $tol) { $out += ('LAYOUT ' + $Card + ' FieldBox edge: starts at ' + $M.BoxLeft + ', the card edge is ' + $M.Edge) }
  if ([math]::Abs([int]$M.BoxW - [int]$M.TextW) -gt $tol) { $out += ('LAYOUT ' + $Card + ' FieldBox width: ' + $M.BoxW + ', the card text is ' + $M.TextW + ' wide') }
  return $out }
# FrameBad (L1, the Administrator, 2026-11-19): the card frame. The header row starts at the frame's fixed top (so it is at
# the same place on every card of one window size), and the frame is as tall as its minimum at least, each within 1 px
# (scaled). A card that had to move up to fit (Moved) is not measured. Takes the card and @{ Top; WantTop; H; MinH; Moved };
# gives back the defect lines.
$ui.FrameBad = { param([string]$Card, $M)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1)); if ($M.Moved) { return $out }
  if ([math]::Abs([int]$M.Top - [int]$M.WantTop) -gt $tol) { $out += ('LAYOUT ' + $Card + ' frame: the header row is at ' + $M.Top + ', the fixed top is ' + $M.WantTop) }
  if ([int]$M.H + $tol -lt [int]$M.MinH) { $out += ('LAYOUT ' + $Card + ' frame: ' + $M.H + ' high, the minimum is ' + $M.MinH) }
  return $out }
# TickBad (R29b N3): the step's time or count (@{ N; Top; H }) has its vertical center within 1 px of the bar's (@{ Top; H }),
# at any scale (the tolerance is not scaled).
$ui.TickBad = { param([string]$Card, $Bar, $Tick)
  $mb = $Bar.Top + $Bar.H / 2.0; $mt = $Tick.Top + $Tick.H / 2.0
  if ([math]::Abs($mt - $mb) -le 1) { return @() }
  return @('LAYOUT ' + $Card + ' StepRow ' + $Tick.N + ' midpoint: ' + $mt + ', the bar midpoint is ' + $mb) }
# ---- The self-check walk
$ui.IsCardText = { param($C) return [bool](($C -is [System.Windows.Forms.TextBox]) -and $C.ReadOnly -and -not $C.TabStop -and $ui.Wrap.ContainsKey($C)) }
# What a card text box needs, as its edit control wraps the text now (the line count it reports), else as measured.
$ui.TextNeed = { param($C)
  $w = [int](& $ui.GetWrap $C); $s = & $ui.Meas ([string]$C.Text) $C.Font $(if ($w -gt 0) { $w } else { 100000 }); $h = [int]$s.Height + (& $ui.Sc 2)
  try { $n = [int]$C.GetLineFromCharIndex([math]::Max(0, $C.Text.Length - 1)) + 1; $lh = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $C.Font).Height; if ($n -gt 0 -and $lh -gt 0) { $h = [math]::Max($h, $n * $lh) } } catch { $null = $_ }
  return (New-Object System.Drawing.Size($s.Width, $h)) }
$ui.Check = {
  if (-not $ui.LayOn -or -not $ui.View) { return }
  if ($ui.Picked -and (Test-Deploy) -and $env:RADE_LAYOUT -ne '1') { return }   # a deploy does not run it, also when the paste has a test application
  $card = $(if ($ui.RecOn) { 'record' } else { [string]$ui.View })
  try {
    if (-not $ui.Form.Visible -or [string]$ui.Form.WindowState -eq 'Minimized') { return }
    # One check for each card at each window size (R28: the check runs again after a resize).
    $key = $card + '|' + $ui.View + '|' + $ui.Sent.Text + '|' + $ui.Kick.Text; $ui.LayCards[$key] = 1
    $key += '|' + $ui.Form.ClientSize.Width + 'x' + $ui.Form.ClientSize.Height; if ($ui.LaySeen.ContainsKey($key)) { return }; $ui.LaySeen[$key] = 1
    if ($ui.Scrolls -and -not $ui.RecOn) { $ui.LayScroll[$card] = 1 }
    $todo = New-Object System.Collections.Stack; $todo.Push(@($ui.Form, $ui.Form.RectangleToScreen($ui.Form.ClientRectangle), $false))
    while ($todo.Count) {
      $it = $todo.Pop(); $par = $it[0]; $clip = $it[1]; $scroll = $it[2]
      $kids = @($par.Controls | Where-Object { $_.Visible })
      for ($i = 0; $i -lt $kids.Count; $i++) {
        $c = $kids[$i]; $r = $c.RectangleToScreen($c.ClientRectangle); if ($r.Width -le 0 -or $r.Height -le 0) { continue }
        if (-not $scroll -and -not $clip.Contains($r)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' cut: needs ' + $r.Width + 'x' + $r.Height + ' at ' + ($r.Left - $clip.Left) + ',' + ($r.Top - $clip.Top) + ' in ' + $clip.Width + 'x' + $clip.Height) }
        if ($c -is [System.Windows.Forms.Label] -and $c.AutoSize -and $c.MaximumSize.Width -gt 0 -and $c.Text) { $wb = & $ui.WordBad $card (& $ui.NameOf $c) ([string]$c.Text) $c.Font $c.MaximumSize.Width; if ($wb) { $ui.LayBad.Add($wb) } }
        if (& $ui.IsCardText $c) {   # card text boxes are measured as labels are: a word wider than the line, and text that needs more room than the box has
          if ([int](& $ui.GetWrap $c) -gt 0 -and $c.Text) { $wb = & $ui.WordBad $card (& $ui.NameOf $c) ([string]$c.Text) $c.Font ([int](& $ui.GetWrap $c)); if ($wb) { $ui.LayBad.Add($wb) } }
          $nd = & $ui.TextNeed $c; if ($c.Text -and ($nd.Height -gt $c.ClientSize.Height + 1 -or $nd.Width -gt $c.ClientSize.Width + 1)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text: needs ' + $nd.Width + 'x' + $nd.Height + ' has ' + $c.ClientSize.Width + 'x' + $c.ClientSize.Height) }
          $lh1 = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $c.Font).Height; if ($c.Text -and -not $ui.Hold.ContainsKey($c) -and $c.ClientSize.Height -gt $nd.Height + $lh1) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' dead space: has ' + $c.ClientSize.Height + ' high, the text needs ' + $nd.Height) } }   # more than one empty line under its text (a box with fixed lines keeps its room)
        if ($c -is [System.Windows.Forms.CheckBox] -and $c.Text -and -not $c.AutoEllipsis) {   # a one-line check box whose text alone is wider than it is cut (the Record's step boxes before R24 fix round 3)
          $tw = [System.Windows.Forms.TextRenderer]::MeasureText([string]$c.Text, $c.Font).Width; if ($tw -gt $c.ClientSize.Width + 1) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text cut: needs ' + $tw + ' has ' + $c.ClientSize.Width) } }
        # A cut line (R28 N9: the run card's status line was cut through its middle): a control with text is at least one line of its
        # font tall, also a label that ends with "..." by rule. A rich text box (the lines of a hand step) is as tall as its text.
        if ($c.Text -and ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.ButtonBase] -or $c -is [System.Windows.Forms.TextBoxBase])) {
          $lh = [int](& $ui.LineH $c.Font); if ($c -is [System.Windows.Forms.TextBoxBase]) { $lh = [int][math]::Floor($lh * 0.8) }   # an edit control draws a line with less padding
          if ($c.ClientSize.Height + 1 -lt $lh) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' line cut: one line needs ' + $lh + ' high, has ' + $c.ClientSize.Height) } }
        if ($c -is [System.Windows.Forms.RichTextBox] -and $ui.GuideNeed -and [object]::ReferenceEquals($c, $ui.Guide)) { $gn = [int](& $ui.GuideNeed); if ($gn -gt $c.ClientSize.Height + 1) { $ui.LayBad.Add('LAYOUT ' + $card + ' Guide text: needs ' + $gn + ' high, has ' + $c.ClientSize.Height) } }
        $isText = ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.ButtonBase])
        if ($isText -and $c.Text -and -not $c.AutoEllipsis) {   # a label or box that ends with "..." by rule is not a defect
          $want = $c.GetPreferredSize((New-Object System.Drawing.Size($c.Width, 0)))
          if ($want.Width -gt $c.Width + 1 -or $want.Height -gt $c.Height + 1) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text: needs ' + $want.Width + 'x' + $want.Height + ' has ' + $c.Width + 'x' + $c.Height) }
        }
        for ($j = $i + 1; $j -lt $kids.Count; $j++) { if ($c.Bounds.IntersectsWith($kids[$j].Bounds)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' overlaps ' + (& $ui.NameOf $kids[$j])) } }
        $sc2 = [bool]$c.AutoScroll; if ([object]::ReferenceEquals($c, $ui.Scroll)) { $sc2 = [bool]$ui.Scrolls }   # the card's text scrolls only when $ui.Squeeze says so
        if ($c.Controls.Count) { $todo.Push(@($c, [System.Drawing.Rectangle]::Intersect($clip, $r), ($scroll -or $sc2))) }
      }
    }
    # Dead space (R28 N9: a large empty area under the run card's text): the card's text panel is as tall as its text when it does not scroll.
    if ($ui.Scroll -and $ui.Body -and -not $ui.RecOn -and -not $ui.Scrolls -and $ui.Scroll.Visible) { $dead = [int]$ui.Scroll.ClientSize.Height - [int]$ui.Body.Height; if ($dead -gt (& $ui.Sc 2)) { $ui.LayBad.Add('LAYOUT ' + $card + ' Scroll dead space: ' + $dead + ' px under the text') } }
    foreach ($l in @(& $ui.Measure $card)) { $ui.LayBad.Add([string]$l) }
  } catch { $ui.LayBad.Add('LAYOUT ' + $card + ' the self-check stopped: ' + (ConvertTo-Masked ([string]$_.Exception.Message))) } }
# <<< rade-ui
# ---- High contrast (R31 W2; R30b check 10: the window kept its own colors when a contrast theme came on)
# With Windows high contrast on, the window paints with the system colors of the theme instead of its own palette.
# The role of each color: backgrounds become Window, text and lines WindowText, muted text GrayText, the action
# Highlight, a button that is not available ButtonFace. The rail turns round: navy (its background) becomes WindowText
# and its light text Window, so it stays readable. One table serves $pc and $ui.C: a hashtable key ignores case, and
# each name the two share (navy, ink, track, white) has one role in both. Yellow fills become Window: dark text on the
# theme's Highlight color can be hard to read.
$ui.HcRole = @{ ink = 'WindowText'; muted = 'GrayText'; surface = 'Window'; line = 'WindowText'; navy = 'WindowText'; onPrimaryMuted = 'Window'
  accentFill = 'Window'; primary = 'Highlight'; track = 'GrayText'; redTint = 'Window'; amberTint = 'Window'; greenTint = 'Window'; white = 'Window'
  blue = 'Highlight'; yellow = 'Window'; green = 'WindowText'; greenInk = 'WindowText'; red = 'WindowText'; gray = 'GrayText'; edge = 'WindowText'
  hair = 'GrayText'; off = 'ButtonFace'; offInk = 'GrayText' }
function Select-T22Color([bool]$High, [hashtable]$Own, [hashtable]$Role) {
  # The colors to paint with: a new table with the keys of $Own. $High false: the colors of $Own. $High true: for each
  # key the system color its role names in $Role (a key with no role gets WindowText, so no text is lost). $Own is not
  # changed. The measure part checks this choice without switching the Windows theme (tests/ps/Test-T22Layout.ps1).
  $out = @{}
  foreach ($k in @($Own.Keys)) {
    if ($High) { $r = [string]$Role[$k]; if (-not $r) { $r = 'WindowText' }; $out[$k] = [System.Drawing.SystemColors]::$r }
    else { $out[$k] = $Own[$k] } }
  return $out
}
# The window's own colors, kept before any change, and whether the system colors are in use.
$ui.OwnPc = $pc.Clone(); $ui.OwnC = $ui.C.Clone(); $ui.High = $false
# Puts the colors for $High into $pc and $ui.C in place (every builder and every paint handler reads them there).
$ui.UseColors = { param([bool]$High)
  $a = Select-T22Color $High $ui.OwnPc $ui.HcRole; foreach ($k in @($a.Keys)) { $pc[$k] = $a[$k] }
  $b = Select-T22Color $High $ui.OwnC $ui.HcRole; foreach ($k in @($b.Keys)) { $ui.C[$k] = $b[$k] }
  $ui.High = $High }
