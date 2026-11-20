<#
.SYNOPSIS
  90-161.Z Task 22 r11, part "ui": the first half of the RADE shared UI file (colors, fonts, buttons, card text boxes,
  layout self-check), generated into this file, and the few names it needs from the window. Part "ui2" holds the rest.
.DESCRIPTION
  R11 (R38; PFM 20 Nov 26): engine-v29's shared UI file is split into this part and "ui2" (600-line file cap); the high
  contrast lines moved to "ui2", after the second half they use.
  The block between the rade-ui markers is written by scripts/build_task_scripts.py from the pinned RADE commit
  (scripts/rade.lock.json); never edit it here. It runs inside the main script's try block, after $ui.Form exists,
  and fills $ui. The lines above the block give it what it reads from a RADE window: $dot, $round and Test-Deploy
  (part "ui2" sets $apps). Part "ui2" chooses the colors for Windows
  high contrast (R31 W2).
  Inputs: $ui with $ui.Form (made by the main script), $pc. Outputs: the $ui members of the first half of the shared UI file.
  Run: not alone; 90161Z-T22-pfm-window-r11.ps1 dot-sources it from its own folder.
  Network: none.
  Writes: none.
  Credentials: none.
#>
Set-Variable -Name dot -Value ''; Set-Variable -Name round -Value ''
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
# <<< rade-ui
