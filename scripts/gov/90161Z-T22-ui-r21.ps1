<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "ui": the first half of the RADE shared UI file (colors, fonts, buttons, card text boxes,
  layout self-check), generated into this file, and the few names it needs from the window. Part "ui2" holds the rest.
.DESCRIPTION
  R11 (R38; PFM 20 Nov 26): engine-v29's shared UI file is split into this part and "ui2" (600-line file cap); the high
  contrast lines moved to "ui2", after the second half they use.
  The block between the rade-ui markers is written by scripts/build_task_scripts.py from the pinned RADE commit
  (scripts/rade.lock.json); never edit it here. It runs inside the main script's try block, after $ui.Form exists,
  and fills $ui. The lines above the block give it what it reads from a RADE window: $dot, $round, $apps and Test-Deploy
  ($apps moved here from part "ui2" with engine-v36; engine-v48 moves the line that reads it back to "ui2"). Part "ui2" chooses the colors for Windows
  high contrast (R31 W2).
  Inputs: $ui with $ui.Form (made by the main script), $pc. Outputs: the $ui members of the first half of the shared UI file.
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder.
  Network: none.
  Writes: none.
  Credentials: none.
#>
Set-Variable -Name dot -Value ''; Set-Variable -Name round -Value ''
# This window is never a deploy: the layout self-check of the shared UI file always runs.
function Test-Deploy { return $false }
# One test application, so the layout self-check of the shared UI file runs. Set-Variable: the line that reads $apps can be in
# either half of the shared UI file (engine-v48: in part "ui2"), so the lint sees no use of it in this file.
Set-Variable -Name apps -Value @(@{ Mode = 'test' })
# >>> rade-ui: generated from the pinned RADE shared UI file by scripts/build_task_scripts.py (do not edit)
# RADE shared UI file (engine/rade_ui.ps1): the theme tokens (colors, fonts, sizes), the builders for buttons, links and
# card text, the drawing and measuring helpers (part 2: engine/rade_ui_text.ps1, right after this file), and the layout self-check. rade_build.py puts this text into every bundle
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
# ---- UI tokens (UI standard v1, the Administrator, 2026-11-20; docs/ui-standard.md): written from engine/ui-tokens.json
# by python3 engine/rade_tokens.py --write. Do not edit these lines: a build stops when they differ from that file.
$ui.Standard = 'v1'
# Colors: name = @(red, green, blue, the SystemColors role it takes while a Windows contrast theme is on); uses: the file.
$ui.Tok = [ordered]@{}
$ui.Tok.White = @(255, 255, 255, 'Window'); $ui.Tok.Ink = @(27, 36, 48, 'WindowText'); $ui.Tok.Navy = @(11, 37, 69, 'WindowText')
$ui.Tok.Gray = @(90, 101, 115, 'GrayText'); $ui.Tok.Blue = @(0, 83, 159, 'Highlight'); $ui.Tok.OnBlue = @(255, 255, 255, 'HighlightText')
$ui.Tok.Link = @(0, 83, 159, 'HotTrack'); $ui.Tok.Focus = @(11, 37, 69, 'HotTrack'); $ui.Tok.Face = @(255, 255, 255, 'ButtonFace')
$ui.Tok.FaceInk = @(11, 37, 69, 'ControlText'); $ui.Tok.Edge = @(122, 135, 148, 'ControlText'); $ui.Tok.Hair = @(227, 232, 238, 'GrayText')
$ui.Tok.Track = @(127, 147, 168, 'GrayText'); $ui.Tok.Off = @(244, 246, 248, 'ButtonFace'); $ui.Tok.OffInk = @(95, 104, 116, 'GrayText')
$ui.Tok.Yellow = @(255, 205, 0, 'Highlight'); $ui.Tok.Red = @(139, 26, 26, 'WindowText'); $ui.Tok.Green = @(46, 133, 64, 'Highlight')
$ui.Tok.GreenInk = @(31, 107, 49, 'WindowText'); $ui.Tok.Band = @(8, 27, 51, 'Window'); $ui.Tok.BandInk = @(255, 255, 255, 'WindowText')
$ui.Tok.BandMuted = @(185, 199, 216, 'GrayText'); $ui.Tok.Info = @(0, 83, 159, 'Highlight'); $ui.Tok.Tint = @(242, 246, 251, 'Window')
$ui.Tok.OnYellow = @(11, 37, 69, 'HighlightText'); $ui.Tok.OffRed = @(139, 26, 26, 'GrayText')
# The dark set (plan engine-v48 D6): name = @(red, green, blue); the system role is the light one.
$ui.TokDark = [ordered]@{}
$ui.TokDark.White = @(21, 23, 29); $ui.TokDark.Ink = @(243, 238, 228); $ui.TokDark.Navy = @(243, 238, 228); $ui.TokDark.Gray = @(169, 172, 181)
$ui.TokDark.Blue = @(228, 87, 46); $ui.TokDark.OnBlue = @(21, 23, 29); $ui.TokDark.Link = @(141, 184, 240); $ui.TokDark.Focus = @(243, 238, 228)
$ui.TokDark.Face = @(30, 33, 41); $ui.TokDark.FaceInk = @(243, 238, 228); $ui.TokDark.Edge = @(122, 127, 140); $ui.TokDark.Hair = @(48, 52, 61)
$ui.TokDark.Track = @(58, 63, 74); $ui.TokDark.Off = @(38, 42, 51); $ui.TokDark.OffInk = @(149, 153, 163); $ui.TokDark.Yellow = @(212, 175, 55)
$ui.TokDark.Red = @(244, 155, 145); $ui.TokDark.Green = @(95, 208, 142); $ui.TokDark.GreenInk = @(95, 208, 142); $ui.TokDark.Band = @(14, 16, 21)
$ui.TokDark.BandInk = @(243, 238, 228); $ui.TokDark.BandMuted = @(169, 172, 181); $ui.TokDark.Info = @(141, 184, 240); $ui.TokDark.Tint = @(27, 36, 51)
$ui.TokDark.OnYellow = @(21, 23, 29); $ui.TokDark.OffRed = @(201, 143, 137)
# Sizes, gaps and field widths, in pixels at 100 % (every size set after the form has scaled goes through $ui.Sc).
$ui.Z = @{ ActionW = 160; WideW = 240; ActionH = 40; CompactW = 96; CompactH = 30; LinkH = 28; BarTop = 11; M = 4; Inset = 24; BandH = 56; BandLogo = 36; Disc = 20; LineIdle = 4; LineLoud = 8; Narrow = 700
  G1 = 4; G2 = 8; G3 = 12; G4 = 16; G6 = 24
  FieldS = 240; FieldM = 420; FieldL = 600 }
# Faces: name = @(family, the font file's name in the bundle ('' = none), the family used when the font cannot be loaded).
$ui.Faces = @{ title = @('Sofia Sans Condensed SemiBold', 'SofiaSansCondensed-SemiBold.ttf', 'Segoe UI Semibold'); text = @('Sofia Sans', 'SofiaSans-Regular.ttf', 'Segoe UI'); strong = @('Sofia Sans SemiBold', 'SofiaSans-SemiBold.ttf', 'Segoe UI Semibold'); mono = @('Consolas', '', 'Consolas') }
# Text styles: name = @(face, size in points at 100 %, font style ('' = regular)); uses: the file.
$ui.Styles = [ordered]@{}
$ui.Styles.Sent = @('title', 22, ''); $ui.Styles.Word = @('title', 15, 'Bold'); $ui.Styles.Body = @('text', 12, ''); $ui.Styles.Small = @('text', 10, '')
$ui.Styles.SmallB = @('strong', 10, ''); $ui.Styles.Link = @('strong', 10, 'Underline'); $ui.Styles.Turn = @('strong', 12, 'Bold'); $ui.Styles.Mono = @('mono', 9, '')
# ---- End of the UI tokens
# ---- Colors and Windows contrast themes (UI standard v1, the Administrator, 2026-11-20; docs/ui-standard.md B10, B11)
# One meaning each (the "use" of each token above): navy = card text, Air Force blue = the action and progress, yellow =
# your turn, dark red = FAILED, NEEDS REVIEW and the one destructive action, green = passed. Every text pair is at least
# 4.5:1 and every non-text pair 3:1 (scripts/ui_tokens.py computes them from engine/ui-tokens.json). While a Windows
# contrast theme is on (SystemInformation.HighContrast), each token is the system color of its role, so the window has
# the theme's colors; $ui.Recolor follows a theme that changes while the window is open.
$ui.HighOn = { try { return [bool][System.Windows.Forms.SystemInformation]::HighContrast } catch { return $false } }   # no answer (an old host): the own colors
# The color of one token: its own color, or while $ui.High is on the system color of its role. Takes the token name; gives
# back a Color (WindowText for a name that is not a token, so no text is ever lost).
$ui.Color = { param([string]$Role)
  $t = $ui.Tok[$Role]
  if ($ui.High) { $r = $(if ($t) { [string]$t[3] } else { 'WindowText' }); try { $sc = [System.Drawing.SystemColors]::$r; if ($null -eq $sc) { $sc = [System.Drawing.SystemColors]::WindowText }; return $sc } catch { return [System.Drawing.Color]::Black } }   # a role with no color: WindowText; no system colors: black
  if (-not $t) { return [System.Drawing.Color]::Black }
  if ($ui.Dark -and $ui.TokDark[$Role]) { $t = $ui.TokDark[$Role] }   # the dark set (plan engine-v48 D6)
  return [System.Drawing.Color]::FromArgb([int]$t[0], [int]$t[1], [int]$t[2]) }
# Puts the colors for a theme into $ui.C in place (every builder and paint handler reads them there). Takes $true for the
# system colors of a contrast theme, $false for the own colors.
$ui.UseColors = { param([bool]$High) $ui.High = $High; foreach ($k in @($ui.Tok.Keys)) { $ui.C[$k] = & $ui.Color $k } }
# The dark set is opt-in (review of PR 211): a window that wants it sets $ui.Dark before this file runs (the RADE window:
# engine/ps/window/01-setup.ps1, from the Windows app mode). An app window that copies this file has no $ui.Dark: light.
$ui.Dark = [bool]$ui.Dark; $ui.C = @{}; & $ui.UseColors (& $ui.HighOn)
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
# ---- The RADE fonts (UI standard v1, the Administrator, 2026-11-20; docs/ui-standard.md B12): Sofia Sans Condensed for
# titles and Sofia Sans for text, open fonts (engine/fonts/OFL.txt) that the bundle carries as base64 ($fontTtf). They are
# loaded for this process only (no install, no administrator): GDI+ gets them in a PrivateFontCollection (the Font objects)
# and GDI gets the same bytes as a memory font (AddFontMemResourceEx), because Windows Forms draws labels, boxes and
# buttons with GDI, which knows no GDI+ private font. A font that cannot be loaded is replaced by its face's fallback
# (Segoe UI), so the window always opens. $ui.FontNote says what was loaded (the SCALE line).
$ui.FontFam = @{}; $ui.FontMem = @(); $ui.FontNote = 'fallback (no font files)'
$ui.LoadFonts = {
  <#
  .SYNOPSIS
  Loads the fonts of $fontTtf (the bundle's base64 font files) for this process.
  .DESCRIPTION
  Each file goes into one PrivateFontCollection (GDI+) and, when the native type can be made, into GDI as a memory font.
  The memory of each file stays held while the process runs (GDI+ reads it when it draws). A bundle with no $fontTtf
  (an app window that copies this file) and any failure leave $ui.FontFam empty: every style then uses its fallback.
  .OUTPUTS
  Nothing. Fills $ui.FontFam (family name = FontFamily) and sets $ui.FontNote.
  #>
  $ttf = $null; try { $ttf = $fontTtf } catch { $null = $_ }   # no font files (an app window that copies this file; strict mode): the fallback fonts
  if (-not $ttf -or -not $ttf.Count) { return }
  $gdi = $false
  try { if (-not ('Rade.Fonts' -as [type])) { Add-Type -Namespace Rade -Name Fonts -MemberDefinition '[DllImport("gdi32.dll")] public static extern IntPtr AddFontMemResourceEx(IntPtr pbFont, uint cbFont, IntPtr pdv, ref uint pcFonts);' -ErrorAction Stop }; $gdi = $true } catch { $null = $_ }   # no GDI copy: GDI+ text still has the fonts
  try { $pfc = New-Object System.Drawing.Text.PrivateFontCollection; $n = 0
    foreach ($k in @($ttf.Keys | Sort-Object)) {
      $b = [Convert]::FromBase64String([string]$ttf[$k]); $p = [System.Runtime.InteropServices.Marshal]::AllocCoTaskMem($b.Length)
      [System.Runtime.InteropServices.Marshal]::Copy($b, 0, $p, $b.Length); $ui.FontMem += $p; $pfc.AddMemoryFont($p, $b.Length); $n++
      if ($gdi) { $c = [uint32]0; if ([Rade.Fonts]::AddFontMemResourceEx($p, [uint32]$b.Length, [IntPtr]::Zero, [ref]$c) -eq [IntPtr]::Zero) { $gdi = $false } } }   # a failed GDI load: the note says GDI+ only
    foreach ($fm in @($pfc.Families)) { $ui.FontFam[[string]$fm.Name] = $fm }
    $ui.Pfc = $pfc; $ui.FontNote = 'loaded ' + $n + ' files, ' + $ui.FontFam.Count + ' families' + $(if ($gdi) { '' } else { ' (GDI+ only)' })
  } catch { $ui.FontFam = @{}; $ui.FontNote = 'fallback (' + [string]$_.Exception.GetType().Name + ')' } }   # never stop the window for a font
# The font of one text style ($ui.Styles): its face's font when it was loaded, else the face's fallback ($ui.Font). Takes
# the style name; gives back a Font.
$ui.StyleFont = { param([string]$Name)
  $s = $ui.Styles[$Name]; $face = $ui.Faces[[string]$s[0]]; $pt = [double]$s[1]
  $st = $(if ([string]$s[2]) { [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), [string]$s[2]) } else { $null })
  $fm = $ui.FontFam[[string]$face[0]]   # no System.Drawing type names in this block: on the test stand-ins they would stop it as it is read
  if ($fm) { $gu = $null; $rg = $null; try { $rg = [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Regular'); $gu = [Enum]::Parse(('System.Drawing.GraphicsUnit' -as [type]), 'Point') } catch { $null = $_ }   # no types: the fallback below
    foreach ($fs in @(@($st, $rg) | Where-Object { $null -ne $_ })) { try { return (New-Object System.Drawing.Font($fm, [single]($pt * $ui.FontK), $fs, $gu)) } catch { $null = $_ } } }   # a style the one-weight file lacks (Bold): its own weight
  return (& $ui.Font ([string]$face[2]) $pt $st) }
& $ui.FormDpi; & $ui.FontScale; & $ui.LoadFonts; $ui.Form.Font = (& $ui.StyleFont 'Small')
# Text styles (the Administrator, 2026-11-17; faces and sizes from the UI tokens, UI standard v1): Sent = headline; Body =
# paragraphs, step lines, help line; Small = second lines, notes, box text; SmallB = the line in capitals, labels, every
# button, key numbers, the Record's heads and result words; Link = SmallB underlined (a link is marked by more than
# color); Word = the word in the band and the Run card's percent; Mono = the Record's text box only; Turn = the strong summary line of the Done card.
$ui.F = @{}; foreach ($k in @($ui.Styles.Keys)) { $ui.F[$k] = & $ui.StyleFont $k }; $ui.F.Small = $ui.Form.Font
# Sizes: the UI tokens above (gaps 4, 8, 12, 16, 24; a 4 px margin around a button or link for its focus ring).
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
$ui.Menu = New-Object System.Windows.Forms.ContextMenuStrip; $ui.Menu.AccessibleName = 'Text menu'; $ui.MenuCopy = $ui.Menu.Items.Add('Copy'); $ui.MenuAll = $ui.Menu.Items.Add('Select All')
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
$ui.Ring = { param($P) $P.Add_Paint({ try { foreach ($c in $this.Controls) { if (($c.Focused -or ($ui.Boxes -contains $c -and $c.ContainsFocus)) -and $c.Visible) {
          $pn = New-Object System.Drawing.Pen($ui.C.Focus, [single](& $ui.Sc 2)); $b = $c.Bounds; $o = & $ui.Sc 2; $_.Graphics.DrawRectangle($pn, ($b.Left - $o), ($b.Top - $o), ($b.Width + 2 * $o - 1), ($b.Height + 2 * $o - 1)); $pn.Dispose() } } } catch { $null = $_ } }) }
$ui.Style = { param($B, [string]$Kind)
  # primary = Air Force blue (dark: ember); danger = dark red (dark: an outline); dangerline = an outline in the error color; off = not available (gray, text 6.3:1); dangeroff = the destructive
  # action while it is not available (gray, dark red text and edge, 8:1); else white with a gray edge. The colors under
  # the pointer and while pressed are set here too (Windows picks its own otherwise): a white button goes to the hair
  # and the off gray, a blue or dark red button keeps its color.
  $ui.Kinds[$B] = $Kind; $B.Enabled = ($Kind -notin 'off', 'dangeroff'); $B.FlatStyle = 'Flat'; $B.FlatAppearance.BorderSize = 1; $B.Font = $ui.F.SmallB; $over = $null; $down = $null
  if ($Kind -eq 'off') { $B.BackColor = $ui.C.Off; $B.ForeColor = $ui.C.OffInk; $B.FlatAppearance.BorderColor = $ui.C.Track }
  elseif ($Kind -eq 'dangeroff') { $B.BackColor = $ui.C.Off; $B.ForeColor = $ui.C.OffRed; $B.FlatAppearance.BorderColor = $ui.C.OffRed }
  elseif ($Kind -eq 'primary') { $B.BackColor = $ui.C.Blue; $B.ForeColor = $ui.C.OnBlue; $B.FlatAppearance.BorderColor = $ui.C.Blue }
  elseif ($Kind -eq 'danger' -and -not $ui.Dark) { $B.BackColor = $ui.C.Red; $B.ForeColor = $ui.C.White; $B.FlatAppearance.BorderColor = $ui.C.Red }
  elseif ($Kind -in 'danger', 'dangerline') { $B.BackColor = $ui.C.Face; $B.ForeColor = $ui.C.Red; $B.FlatAppearance.BorderColor = $ui.C.Red }   # the error color as text and edge (Cards v2: "Stop the install"; dark: every danger button)
  else { $B.BackColor = $ui.C.Face; $B.ForeColor = $ui.C.FaceInk; $B.FlatAppearance.BorderColor = $ui.C.Edge; $over = $ui.C.Hair; $down = $ui.C.Off }
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
# Buttons have fixed sizes (UI standard v1, B1; the Administrator, 2026-11-20): no AutoSize, so a button never grows or
# shrinks with its text. $Kind: 'action' (a card's buttons: 160 x 40, or 240 x 40 when its label needs more room) or
# 'compact' (96 x 30: beside a box, "Back (Esc)", the Record's buttons; 160 x 30 when its label needs more room). A label
# that needs more than the widest size is cut, and the self-check reports it (rule B1). Sizes: $ui.Z.
$ui.BtnKind = @{}; $ui.Wide = @{}
# The size of a button of a kind for its text: at 100 % before the window has its scale (Windows Forms scales it), else scaled.
$ui.BtnSize = { param($B)
  $k = [string]$ui.BtnKind[$B]; $s = $(if ($ui.Scaled) { $ui.Sc } else { { param([double]$Px) [int]$Px } })
  $h = $(if ($k -eq 'compact') { $ui.Z.CompactH } else { $ui.Z.ActionH }); $ws = $(if ($k -eq 'compact') { @($ui.Z.CompactW, $ui.Z.ActionW) } else { @($ui.Z.ActionW, $ui.Z.WideW) })
  $need = 0; try { if ($B.Text) { $need = [int][System.Windows.Forms.TextRenderer]::MeasureText([string]$B.Text, $B.Font).Width + (& $ui.Sc (2 * $ui.Z.G2)) } } catch { $null = $_ }   # no measure: the first width
  $w = $(if ($need -le (& $ui.Sc $ws[0]) -and -not $ui.Wide[$B]) { $ws[0] } else { $ws[1] })   # $ui.Wide: the wide size for every text (a stack of buttons)
  return (New-Object System.Drawing.Size((& $s $w), (& $s $h))) }
# Gives a button the size of its kind for its text ($ui.BtnSize). Takes the button.
$ui.FitBtn = { param($B) try { $ns = & $ui.BtnSize $B; if ($B.Width -ne $ns.Width -or $B.Height -ne $ns.Height) { $B.Size = $ns } } catch { $null = $_ } }   # no size now: the next text sets it
$ui.AutoNames = @{}   # the name $ui.AutoName gave each button
# AccessibleName on every control (docs/window-design.md; fleet v2): a button whose name nobody set takes its text and
# follows it when the text changes; a name set by hand stays. Takes the button; gives back nothing.
$ui.AutoName = { param($B) if (-not [string]$B.AccessibleName -or [string]$ui.AutoNames[$B] -eq [string]$B.AccessibleName) {
    $B.AccessibleName = [string]$B.Text; $ui.AutoNames[$B] = [string]$B.Text } }
# Makes a button of a kind ('action' or 'compact'), styled, with its focus ring and own face. Takes the kind; gives back the button.
$ui.Btn = { param([string]$Kind) $b = New-Object System.Windows.Forms.Button; $b.AutoSize = $false; $ui.BtnKind[$b] = $(if ($Kind -eq 'compact') { 'compact' } else { 'action' })
  $b.Padding = (& $ui.Pad $ui.Z.G2 0 $ui.Z.G2 0); $b.Margin = (& $ui.Pad $ui.Z.M $ui.Z.M $ui.Z.M $ui.Z.M); $b.UseMnemonic = $false; & $ui.Style $b ''; & $ui.Cue $b; & $ui.Own $b
  & $ui.FitBtn $b; $b.Add_TextChanged({ & $ui.FitBtn $this; & $ui.AutoName $this }); $b }   # gives back the button
$ui.LinkBtn = { param([string]$Text) $b = New-Object System.Windows.Forms.Button; $b.Text = $Text; $b.AutoSize = $true; $b.AutoSizeMode = 'GrowAndShrink'; $b.MinimumSize = New-Object System.Drawing.Size(0, $ui.Z.LinkH); $b.Margin = (& $ui.Pad $ui.Z.M $ui.Z.M $ui.Z.M $ui.Z.M); $b.UseMnemonic = $false
  $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0; $b.BackColor = $ui.C.White; $b.ForeColor = $ui.C.Link; $b.Font = $ui.F.Link; $ui.Links += $b; try { $b.FlatAppearance.MouseOverBackColor = $ui.C.White; $b.FlatAppearance.MouseDownBackColor = $ui.C.Hair } catch { $null = $_ }; & $ui.Cue $b; & $ui.Own $b   # no hover colors: the link still works
  & $ui.AutoName $b; $b.Add_TextChanged({ & $ui.AutoName $this }); $b }   # a link: Air Force blue, semibold and underlined (not color alone), 28 high
$ui.Kinds = @{}; $ui.Links = @()   # the kind each button was last styled with; every link ($ui.Recolor styles them again)
# ---- A contrast theme that changes while the window is open (UI standard v1, B11; backlog item 24)
# The form's SystemColorsChanged event (Windows sends WM_SYSCOLORCHANGE when a contrast theme comes on or goes off) calls
# $ui.Recolor on the window's own thread: PowerShell code cannot run on the thread of SystemEvents, and the event goes with
# the form when it closes, so nothing is left to detach. $ui.Roles keeps, for each control and color property, the token
# it was painted with (found from the colors it had), so a switch back gives each part its own color again.
$ui.Roles = @{}; $ui.Recolor = {
  <#
  .SYNOPSIS
  Paints the window again in the colors of the current Windows theme (its own colors, or a contrast theme's system colors).
  .DESCRIPTION
  Does nothing when the theme did not change, unless Force is set. Each property gets the color of its token (see above).
  .PARAMETER Force
  $true to paint again also when the theme did not change.
  .OUTPUTS
  Nothing.
  #>
  param([bool]$Force)
  $hi = [bool](& $ui.HighOn); if ($hi -eq [bool]$ui.High -and -not $Force) { return }
  try { $rev = @{}; foreach ($k in @($ui.Tok.Keys)) { $a = $ui.C[$k].ToArgb(); if (-not $rev.ContainsKey($a)) { $rev[$a] = $k } }   # the colors before the change: color -> token
    $todo = New-Object System.Collections.Stack; $todo.Push($ui.Form); $all = @()
    while ($todo.Count) { $c = $todo.Pop(); $all += $c; foreach ($k in @($c.Controls)) { $todo.Push($k) } }
    foreach ($c in $all) { if (-not $ui.Roles.ContainsKey($c)) { $ui.Roles[$c] = @{} }; $r = $ui.Roles[$c]
      foreach ($pp in 'ForeColor', 'BackColor') { try { $a = $c.$pp.ToArgb(); $t0 = [string]$r[$pp]   # the token it had keeps its place while its color is still on the control
          if (-not ($t0 -and $ui.C[$t0].ToArgb() -eq $a)) { $t = $rev[$a]; if ($t) { $r[$pp] = $t } } } catch { $null = $_ } } }   # a color that is no token stays as it is
    & $ui.UseColors $hi
    foreach ($c in $all) { $r = $ui.Roles[$c]; foreach ($pp in @($r.Keys)) { try { $c.$pp = $ui.C[[string]$r[$pp]] } catch { $null = $_ } } }   # a property that cannot be set keeps its color
    foreach ($b in @($ui.Kinds.Keys)) { try { $en = $b.Enabled; & $ui.Style $b ([string]$ui.Kinds[$b]); if ([string]$ui.Kinds[$b] -notin 'off', 'dangeroff') { $b.Enabled = $en } } catch { $null = $_ } }   # a button that is gone: nothing to paint
    foreach ($b in @($ui.Links)) { try { $b.BackColor = $ui.C.White; $b.ForeColor = $ui.C.Link; $b.FlatAppearance.MouseOverBackColor = $ui.C.White; $b.FlatAppearance.MouseDownBackColor = $ui.C.Hair } catch { $null = $_ } }   # same: a link that is gone
    if ($ui.CardNow -and -not $ui.RecOn -and -not $ui.Busy -and -not $ui.Running) { $k = @([string]$ui.Field.Text, [string]$ui.ErrBox.Text, [string]$ui.Note.Text); $on = $ui.LayOn; $ui.LayOn = $false
      try { & $ui.SetCard $ui.CardNow } finally { $ui.LayOn = $on }; $ui.Field.Text = $k[0]; $ui.ErrBox.Text = $k[1]; & $ui.Say1 $k[2] }; $ui.Form.Invalidate($true) } catch { $null = $_ } }   # the card's own colors, typed text kept; never stops the window
# Where ink starts, ink-tight text, long words, shortened text, drawing and measuring ($ui.Ink to $ui.Meas): engine/rade_ui_text.ps1.
# ---- The layout self-check (docs/window-design.md "Proof"): in a test round, and in the Windows job, RADE measures each
# card it showed: a text that needs more room than its control has, a control that a parent cuts, two parts that
# overlap. The result is one line under "Window: OK" in the results e-mail draft ("PASS layout" or the defects), so a
# cut text is found by a measure, not by a person's eye. A deploy does not run it. It reads sizes only.
# <<< rade-ui
