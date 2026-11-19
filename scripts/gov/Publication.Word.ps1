<#
.SYNOPSIS
  90-161.Z renderer helpers for Word (layer L2): paragraph format, inline markup, TOC fields, rules, paragraphs and tables.
.DESCRIPTION
  Dot-sourced by New-Publication.ps1 from the same folder (as Publication.Common.ps1 is); it does nothing when it is run
  alone. Windows PowerShell 5.1 and Microsoft Word 16 (COM); no external modules.
  Inputs: the renderer's values in its own scope: the Word selection and document ($script:sel, $script:doc), the format
  constants (rule and layout IDs in docs/format-rules.md: $FontName, $FontSize, $SpaceAfter, $IndentStep, $Gap,
  $RuleWidth) and the Word enum values ($wdAlignLeft, $wdAlignJustify, $wdBorderBottom, $wdBorderLeft, $wdStory).
  Outputs: text and format in the Word document; FORMAT-FAIL lines on the output, counted in $script:formatFails.
  Network: none.
  Writes: the open Word document only (no file; New-Publication.ps1 saves it).
  Credentials: none.
  Run: not alone; .\New-Publication.ps1 -Path .\mypub.json loads it.
#>

# Word True is -1 and False 0; returns the Word value of a PowerShell boolean.
function ConvertTo-WordBool([bool]$Value) { if ($Value) { return -1 } return 0 }

# T06/T07 gov runs 2026-11-11: Word stopped with "Specified cast is not valid" and no line number. Each layout step added
# after r3 runs in Use-Format: a failure prints FORMAT-FAIL with the rule and the script line, the build goes on (so the
# PDF still exists for measurement), and the exit code is 3.
function Use-Format([string]$Rule, [scriptblock]$Do) {
  try { & $Do } catch {
    $script:formatFails++
    Write-Output ('FORMAT-FAIL ' + $Rule + ' line ' + $_.InvocationInfo.ScriptLineNumber + ': ' + $_.Exception.Message)
  }
}
function Invoke-ComSet($Obj, [string]$Name, $Value) {
  # Late-bound set: bypasses the PowerShell COM adapter's type conversion.
  [void]$Obj.GetType().InvokeMember($Name, [Reflection.BindingFlags]::SetProperty, $null, $Obj, @($Value))
}

<#
.SYNOPSIS
  Sets $Values (name -> value) on $Style.ParagraphFormat and returns the route that worked: direct, a copied
  ParagraphFormat assigned back, or late-bound InvokeMember. Throws when all 3 fail (gov runs 2026-11-11, 6 of 6:
  setting LeftIndent threw "Specified cast is not valid").
.PARAMETER Style
  A Word style object.
.PARAMETER Values
  An ordered hashtable of ParagraphFormat property names and values.
.OUTPUTS
  System.String. 'direct', 'copy' or 'invoke'.
#>
function Invoke-ParaFormat($Style, $Values) {
  $errs = @()
  $k = ''
  try { $pf = $Style.ParagraphFormat; foreach ($k in $Values.Keys) { $pf.$k = $Values[$k] }; return 'direct' } catch { $errs += ('direct[' + $k + ']: ' + $_.Exception.Message) }
  try {
    $copy = $Style.ParagraphFormat.Duplicate
    foreach ($k in $Values.Keys) { $copy.$k = $Values[$k] }
    $Style.ParagraphFormat = $copy
    return 'copy'
  } catch { $errs += ('copy[' + $k + ']: ' + $_.Exception.Message) }
  try {
    $pf = $Style.GetType().InvokeMember('ParagraphFormat', [Reflection.BindingFlags]::GetProperty, $null, $Style, $null)
    foreach ($k in $Values.Keys) { $v = $Values[$k]; if ($v -is [double]) { $v = [single]$v }; Invoke-ComSet $pf $k $v }   # Word float properties
    return 'invoke'
  } catch { $errs += ('invoke[' + $k + ']: ' + $_.Exception.Message) }
  throw ($errs -join ' | ')
}

<#
.SYNOPSIS
  Sets the paragraph format of the selection for the next paragraph: alignment, indents, space after (single line
  spacing, no space before, no tabs, no borders) and plain Times New Roman 12 (F-001).
.PARAMETER Align
  Word alignment (0 left, 1 center, 2 right, 3 justify).
.PARAMETER Left
  Left indent in points.
.PARAMETER First
  First-line indent in points (negative = hanging).
.PARAMETER After
  Space after in points (default $SpaceAfter, L-003).
.PARAMETER KeepNext
  Keep with the next paragraph.
#>
function Format-Para([int]$Align = 3, [double]$Left = 0, [double]$First = 0, [double]$After = $SpaceAfter, [bool]$KeepNext = $false) {
  $pf = $script:sel.ParagraphFormat
  $pf.Alignment = $Align
  $pf.LeftIndent = $Left
  $pf.FirstLineIndent = $First
  $pf.SpaceBefore = 0
  $pf.SpaceAfter = $After
  $pf.LineSpacingRule = 0   # single
  $pf.KeepWithNext = ConvertTo-WordBool $KeepNext
  $pf.TabStops.ClearAll()
  $pf.Borders.Enable = 0
  $script:sel.Font.Bold = 0; $script:sel.Font.Italic = 0
  $script:sel.Font.Name = $FontName; $script:sel.Font.Size = $FontSize
}

<#
.SYNOPSIS
  Types a text at the selection with its inline markup: {i}..{/i}, {b}..{/b}. Tier numbers "(T-0..3)" are bold (F-039,
  4.5.9.7.4.12). Two spaces before each new sentence (L-004).
.PARAMETER Text
  The text with markup; $null types nothing.
.PARAMETER Bold
  The text is bold outside {b} markup.
.PARAMETER Italic
  The text is italic outside {i} markup.
#>
function Write-Rich([string]$Text, [bool]$Bold = $false, [bool]$Italic = $false) {
  if ($null -eq $Text) { return }
  $Text = ConvertTo-TwoSpaceSentence $Text
  $tokens = [regex]::Split($Text, '(\{/?[ib]\}|\(T-[0-3]\))')
  $b = $Bold; $i = $Italic
  foreach ($t in $tokens) {
    switch -regex ($t) {
      '^\{i\}$' { $i = $true; continue }
      '^\{/i\}$' { $i = $Italic; continue }
      '^\{b\}$' { $b = $true; continue }
      '^\{/b\}$' { $b = $Bold; continue }
      '^\(T-[0-3]\)$' {
        # Word nonbreaking hyphen (character 30): "(T-3)" never splits across two lines (T01 r3 result, 2.2).
        $script:sel.Font.Bold = -1; $script:sel.Font.Italic = (ConvertTo-WordBool $i)
        $nb = $t.Replace('-', [string][char]30)
        try { $script:sel.TypeText([string]$nb) } catch {
          $script:formatFails++
          Write-Output ('FORMAT-FAIL F-039 nonbreaking hyphen line ' + $_.InvocationInfo.ScriptLineNumber + ': ' + $_.Exception.Message)
          $script:sel.TypeText([string]$t)
        }
        continue
      }
      default {
        if ($t -ne '') { $script:sel.Font.Bold = (ConvertTo-WordBool $b); $script:sel.Font.Italic = (ConvertTo-WordBool $i); $script:sel.TypeText($t) }
      }
    }
  }
  $script:sel.Font.Bold = (ConvertTo-WordBool $Bold); $script:sel.Font.Italic = (ConvertTo-WordBool $Italic)
}
# Ends the paragraph at the selection.
function Complete-Para { $script:sel.TypeParagraph() }
function Add-TocEntry([string]$Entry, [int]$TocLevel) {
  # Hidden TC field; the TOC is built from these fields only, so entries hold headings, not body text.
  $clean = ($Entry -replace '"', "'")
  [int]$wasBold = $script:sel.Font.Bold
  if ($wasBold -ne 0 -and $wasBold -ne -1) { $wasBold = 0 }   # 9999999 = mixed
  $script:sel.Font.Bold = 0   # TOC style decides bold (L-012), not the heading run the field sits in
  $script:sel.Fields.Add($script:sel.Range, -1, ('TC "' + $clean + '" \l ' + $TocLevel), $false) | Out-Null
  $script:sel.Font.Bold = $wasBold
}
function Add-BottomRule([double]$Distance = 1) {
  # applies to the paragraph just ended; $Distance = points between the text and the rule (L-008a)
  $p = $script:doc.Paragraphs.Item($script:doc.Paragraphs.Count - 1)
  $bd = $p.Borders.Item($wdBorderBottom)
  $bd.LineStyle = 1; $bd.LineWidth = $RuleWidth
  Use-Format 'L-008a rule distance' { $p.Borders.DistanceFromBottom = [int][math]::Round($Distance) }   # Long in Word
}

<#
.SYNOPSIS
  Writes one numbered paragraph and, below it, its bullets, its table and its children (one level deeper each). Level 1 =
  main paragraph (bold number and heading, F-028/F-033, and a TOC entry); deeper levels indent 0.25 in each (L-002), not
  bold (F-004). Notes (F-037, 4.6.2) and exceptions (4.6.3) follow the text; a revised paragraph gets a margin bar (F-026).
.PARAMETER P
  The paragraph object of the content file (title, text, notes, exceptions, bullets, table, children, revised).
.PARAMETER Number
  The paragraph number, for example "1.2.".
.PARAMETER Level
  1 for a main paragraph, 2 and more for subparagraphs.
.PARAMETER Unit
  The chapter or attachment number for table numbering ('' when the publication has no chapters).
#>
function Write-Paragraph($P, [string]$Number, [int]$Level, [string]$Unit) {
  $indent = ($Level - 1) * $IndentStep
  $revised = [bool](Get-Prop $P 'revised')
  Format-Para $wdAlignJustify $indent 0 $SpaceAfter
  $isTop = ($Level -eq 1)
  Write-Rich $Number $isTop
  $t = [string](Get-Prop $P 'title')
  $x = [string](Get-Prop $P 'text')
  if ($t) { $sel.TypeText($Gap); Write-Rich $t $isTop }
  if ($isTop) { Add-TocEntry ($Number + "`t" + ($t -replace '\{/?[ib]\}', '')) 2 }   # TOC: main paragraph headings only (4.5.8.3); number at 1.50, text at 2.00 (L-012)
  if ($x) { $sel.TypeText($Gap); Write-Rich $x }
  foreach ($n in @(Get-Prop $P 'notes' | Where-Object { $null -ne $_ })) { $sel.TypeText($Gap); Write-Rich 'Note:' $true; $sel.TypeText(' '); Write-Rich ([string]$n) }        # F-037 (4.6.2)
  foreach ($e in @(Get-Prop $P 'exceptions' | Where-Object { $null -ne $_ })) { $sel.TypeText($Gap); Write-Rich 'Exception:' $true; $sel.TypeText(' '); Write-Rich ([string]$e) }  # F-037 (4.6.3)
  Complete-Para
  if ($revised) {   # F-026: manual margin bar as a left border for camera-ready ICs (4.5.6.2)
    $pp = $script:doc.Paragraphs.Item($script:doc.Paragraphs.Count - 1)
    $lb = $pp.Borders.Item($wdBorderLeft); $lb.LineStyle = 1; $lb.LineWidth = 6
  }
  foreach ($b in @(Get-Prop $P 'bullets' | Where-Object { $null -ne $_ })) {   # non-directive only (F-029)
    Format-Para $wdAlignJustify ($indent + $IndentStep) 0 $SpaceAfter
    $sel.Range.ListFormat.ApplyBulletDefault() | Out-Null
    Write-Rich ([string]$b); Complete-Para
    $sel.Range.ListFormat.RemoveNumbers() | Out-Null
  }
  $tbl = Get-Prop $P 'table'
  if ($null -ne $tbl) { Write-Table $tbl $Unit }
  $kids = @(Get-Prop $P 'children' | Where-Object { $null -ne $_ })
  for ($i = 0; $i -lt $kids.Count; $i++) { Write-Paragraph $kids[$i] ("$Number$($i + 1).") ($Level + 1) $Unit }
}

<#
.SYNOPSIS
  Writes one table: number and title directly above it, bold (F-038, 4.6.4, 4.5.9.7.4.7; numbering per Table 4.1), then
  a bordered Word table with the header row and the rows (markup removed).
.PARAMETER T
  The table object of the content file (title, columns, rows).
.PARAMETER Unit
  The chapter or attachment number ('' when the publication has no chapters).
#>
function Write-Table($T, [string]$Unit) {
  if (-not $script:tableCounter.ContainsKey($Unit)) { $script:tableCounter[$Unit] = 0 }
  $script:tableCounter[$Unit]++
  $num = $script:tableCounter[$Unit]
  if ($Unit -ne '') { $num = "$Unit.$num" }
  Format-Para $wdAlignLeft 0 0 0 $true
  Write-Rich ("Table $num." + $Gap + [string](Get-Prop $T 'title')) $true; Complete-Para
  $cols = @(Get-Prop $T 'columns'); $rows = @(Get-Prop $T 'rows')
  Format-Para $wdAlignLeft 0 0 0
  $wt = $script:doc.Tables.Add($script:sel.Range, $rows.Count + 1, $cols.Count)
  $wt.Borders.Enable = 1
  for ($c = 0; $c -lt $cols.Count; $c++) { $wt.Cell(1, $c + 1).Range.Text = (([string]$cols[$c]) -replace '\{/?[ib]\}', '') }
  for ($r = 0; $r -lt $rows.Count; $r++) {
    $cells = @($rows[$r])
    for ($c = 0; $c -lt $cols.Count; $c++) { $wt.Cell($r + 2, $c + 1).Range.Text = (([string]$cells[$c]) -replace '\{/?[ib]\}', '') }
  }
  $wt.Range.Font.Name = $FontName; $wt.Range.Font.Size = $FontSize
  $wt.Range.ParagraphFormat.SpaceAfter = 0
  $script:sel.EndKey($wdStory) | Out-Null
  Format-Para $wdAlignLeft 0 0 $SpaceAfter; Complete-Para
}
