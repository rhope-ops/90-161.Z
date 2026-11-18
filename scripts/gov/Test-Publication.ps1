<#
.SYNOPSIS
  90-161.Z validator (layer L3). Checks a publication content file (JSON, schemas/publication.schema.json)
  against the rules in docs/format-rules.md. Read-only. Runs on Windows PowerShell 5.1 and pwsh 7.

.OUTPUTS
  One line per finding: "FAIL <rule> <where>: <message>" or "WARN <rule> <where>: <message>".
  Last line: "VALIDATE fails=<n> warns=<m>". Exit code 1 when fails > 0.
.DESCRIPTION
  Dot-sources Publication.Common.ps1 from the same folder (Get-Prop, the fixed statements, two spaces after a sentence).
  Run: .\Test-Publication.ps1 -Path .\mypub.json (New-Publication.ps1 runs it first).
  Network: none.
  Writes: none (read-only).
  Credentials: none.
.PARAMETER Path
  The publication content file (JSON).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$common = Join-Path $PSScriptRoot 'Publication.Common.ps1'
if (-not (Test-Path -LiteralPath $common)) { throw 'Publication.Common.ps1 is missing. Download it into the same folder as this script.' }
. $common

$script:Findings = New-Object System.Collections.Generic.List[object]
# Records one finding (FAIL or WARN) for the report.
function Add-Finding([string]$Level, [string]$Rule, [string]$Where, [string]$Message) {
  $script:Findings.Add([pscustomobject]@{ Level = $Level; Rule = $Rule; Where = $Where; Message = $Message })
}
# The text without the inline markup {i} {/i} {b} {/b} ('' for $null).
function Get-PlainText([string]$Text) {
  if ($null -eq $Text) { return '' }
  return ($Text -replace '\{/?[ib]\}', '')
}
# The sentences of a text (markup removed), for the sentence rules.
function Get-Sentence([string]$Text) {
  $plain = (Get-PlainText $Text).Trim()
  if ($plain -eq '') { return @() }
  # Split after . ? ! when followed by space and a capital letter or quote; keep tier markers with their sentence.
  return @([regex]::Split($plain, '(?<=[.?!])\s+(?=[A-Z"])') | Where-Object { $_.Trim() -ne '' })
}

$months = 'January|February|March|April|May|June|July|August|September|October|November|December'
$allText = New-Object System.Collections.Generic.List[string]
$locText = New-Object System.Collections.Generic.List[object]   # @(location, text) for the Attachment 1 report

# ---------- load ----------
try {
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  $pub = $raw | ConvertFrom-Json
} catch {
  Write-Output ("FAIL SCHEMA file: cannot read JSON: " + $_.Exception.Message)
  Write-Output 'VALIDATE fails=1 warns=0'
  exit 1
}

$meta = Get-Prop $pub 'meta'
if ($null -eq $meta) { Add-Finding 'FAIL' 'SCHEMA' 'meta' 'meta object is missing' ; $meta = [pscustomobject]@{} }
# X-001: the extraction prompt writes [[PFM: question]] where the draft lacks a value; the build stops until the PFM replaces it.
foreach ($ph in [regex]::Matches($raw, '\[\[PFM:[^\]]*\]\]')) { Add-Finding 'FAIL' 'X-001' 'placeholder' ($ph.Value + ' must be replaced before the build') }

foreach ($f in 'action', 'directive', 'byOrderOf', 'issuerLine', 'typeAndNumber', 'designator', 'date', 'seriesTitle', 'title', 'accessibility', 'releasability', 'opr', 'certifiedBy', 'certifiedByName') {
  $v = Get-Prop $meta $f
  if ($null -eq $v -or ($v -is [string] -and $v.Trim() -eq '')) { Add-Finding 'FAIL' 'SCHEMA' "meta.$f" 'required field is missing or empty' }
}

$action = [string](Get-Prop $meta 'action')
$directive = [bool](Get-Prop $meta 'directive')
$integrated = [bool](Get-Prop $meta 'integratedSupplement')

if ($action -and $action -notin @('new', 'rewrite', 'ic', 'ac')) { Add-Finding 'FAIL' 'SCHEMA' 'meta.action' "must be new, rewrite, ic or ac (found '$action')" }

# F-013 By Order line (4.5.4.1)
$bo = [string](Get-Prop $meta 'byOrderOf')
if ($bo -and $bo -notin @('SECRETARY OF THE AIR FORCE', 'COMMANDER', 'CHIEF, NATIONAL GUARD BUREAU')) {
  Add-Finding 'FAIL' 'F-013' 'meta.byOrderOf' 'must be SECRETARY OF THE AIR FORCE, COMMANDER or CHIEF, NATIONAL GUARD BUREAU (4.5.4.1)'
}

# Wing level (F-039, F-040): By Order of the Commander and an issuer line or By Order unit line naming a WING or DELTA.
$issuerText = ([string](Get-Prop $meta 'issuerLine') + ' ' + [string](Get-Prop $meta 'byOrderOfUnit')).ToUpper()
$wingLevel = ($bo -eq 'COMMANDER') -and ($issuerText -match '\b(WING|DELTA)\b')

# F-016 date placeholder (4.5.4.4)
$date = [string](Get-Prop $meta 'date')
if ($date -and $date -ne '(Date)' -and $date -notmatch "^\d{1,2} ($($months.ToUpper())) \d{4}$") {
  Add-Finding 'WARN' 'F-016' 'meta.date' 'drafts use "(Date)"; the publishing activity dates the publication on posting (4.5.4.4)'
}

# F-018 title (4.5.4.6)
$title = [string](Get-Prop $meta 'title')
if ($title) {
  if ($title -cne $title.ToUpper()) { Add-Finding 'FAIL' 'F-018' 'meta.title' 'title must be all capital letters (4.5.4.6)' }
  foreach ($w in 'POLICY', 'INSTRUCTION', 'GUIDANCE', 'HANDBOOK', 'PAMPHLET', 'CATALOG', 'GUIDE', 'BOOK') {
    if ($title.ToUpper() -match "\b$w\b") { Add-Finding 'FAIL' 'F-018' 'meta.title' "title must not contain '$w' (4.5.4.6.2)" }
  }
  foreach ($w in 'DEPARTMENT OF THE AIR FORCE', 'AIR FORCE', 'SPACE FORCE') {
    if ($title.ToUpper() -match "\b$w\b") { Add-Finding 'FAIL' 'F-018' 'meta.title' "title must not contain '$w' (4.5.4.6.2)"; break }
  }
}

# F-020 accessibility / releasability (4.5.4.8-9)
$seal = [string](Get-Prop $meta 'shieldImage')
if ($seal -and $seal -notmatch '[\\/]Prepared[\\/][^\\/]+\.png$') { Add-Finding 'FAIL' 'L-007a' 'meta.shieldImage' 'use a seal from the "Prepared" folder made by the Task 7 seal prep (360 x 360 px PNG)' }
foreach ($f in 'accessibility', 'releasability') {
  $v = [string](Get-Prop $meta $f)
  if ($v -match '^(ACCESSIBILITY|RELEASABILITY):') { Add-Finding 'FAIL' 'F-020' "meta.$f" 'give only the statement text; the renderer adds the bold label' }
}
$link = Get-Prop $meta 'accessibilityLink'
if ($null -ne $link) {
  $lt = [string](Get-Prop $link 'text'); $lu = [string](Get-Prop $link 'url')
  if (-not $lt -or -not ([string](Get-Prop $meta 'accessibility')).Contains($lt)) { Add-Finding 'FAIL' 'F-020' 'meta.accessibilityLink.text' 'the link text must appear word for word in meta.accessibility' }
  if ($lu -notmatch '^https://') { Add-Finding 'FAIL' 'F-020' 'meta.accessibilityLink.url' 'give the full https:// address of the wing site page' }
}

# F-021 OPR / Certified By: office symbols only, no names (4.5.4.10-11)
foreach ($f in 'opr', 'certifiedBy') {
  $v = [string](Get-Prop $meta $f)
  if ($v -cmatch '\b[A-Z][a-z]+\s+[A-Z][a-z]+\b' -or $v -cmatch '\b(Mr|Mrs|Ms|Dr|Col|Lt|Maj|Capt|SMSgt|MSgt|TSgt|SSgt|CMSgt)\.?\s') {
    Add-Finding 'FAIL' 'F-021' "meta.$f" 'use the organization or office symbol only, no names (4.5.4.10-11)'
  }
}

# F-022 supersedes (4.5.4.12)
$sup = @(Get-Prop $meta 'supersedes' | Where-Object { $null -ne $_ })
if ($sup.Count -gt 0 -and $action -ne 'rewrite') { Add-Finding 'FAIL' 'F-022' 'meta.supersedes' 'Supersedes applies only to a rewrite (4.5.4.12)' }
foreach ($s in $sup) {
  $d = [string](Get-Prop $s 'date')
  if ($d -notmatch "^\d{1,2} ($months) \d{4}$") { Add-Finding 'FAIL' 'F-022' 'meta.supersedes' "date '$d' must be 'D Month YYYY' with the month spelled out (4.5.4.12)" }
}

# F-024 / opening paragraph (4.5.5)
$parts = Get-Prop $pub 'openingParts'
if ($null -ne $parts) {
  if ([string](Get-Prop $parts 'antecedent') -notmatch '\{i\}') { Add-Finding 'FAIL' 'F-024' 'openingParts.antecedent' 'name the antecedent publication with its title in italics ({i}...{/i}) (4.5.5.1)' }
  if ([string](Get-Prop $parts 'supplement') -cnotin @('may', 'mayNot')) { Add-Finding 'FAIL' 'F-025' 'openingParts.supplement' "must be 'may' or 'mayNot' (4.5.5.10.1, Table 4.5)" }
  if (-not [string](Get-Prop $parts 'applicability')) { Add-Finding 'FAIL' 'F-025' 'openingParts.applicability' 'applicability statement is required (4.5.5.2)' }
}
try { $opening = [string](Get-OpeningParagraph $pub) } catch { $opening = ''; Add-Finding 'FAIL' 'F-025' 'openingParts' $_.Exception.Message }
if ($directive -and $opening.Trim() -eq '') { Add-Finding 'FAIL' 'F-024' 'opening' 'directive publications need an opening paragraph (4.5.5)' }
if ($opening) {
  $allText.Add($opening)
  $first = (Get-Sentence $opening | Select-Object -First 1)
  if ($first -and $opening -notmatch '\{i\}') { Add-Finding 'WARN' 'F-024' 'opening' 'first sentence should name the antecedent publication with its title in italics ({i}...{/i}) (4.5.5.1)' }
  if ($directive -and $opening -notmatch 'Ensure all records generated as a result of processes prescribed in this') {
    Add-Finding 'FAIL' 'F-025' 'opening' 'records management statement is missing (4.5.5.8)'
  }
  if ($directive -and $opening -notmatch 'DAF Form 847') { Add-Finding 'FAIL' 'F-025' 'opening' 'recommending-changes statement (DAF Form 847) is missing (4.5.5.9)' }
  if ($directive -and $opening -notmatch 'waive') { Add-Finding 'FAIL' 'F-025' 'opening' 'waiver authority statement is missing (4.5.5.11)' }
  if ($directive -and $opening -notmatch 'supplement') { Add-Finding 'WARN' 'F-025' 'opening' 'statement on whether the publication may be supplemented is missing (4.5.5.10)' }
  if ($opening -match 'does not imply endorsement' -and ((Get-Sentence $opening | Select-Object -Last 1) -notmatch 'does not imply endorsement')) {
    Add-Finding 'FAIL' 'F-025' 'opening' 'the trade name disclaimer must be the last sentence of the opening paragraph (4.5.5.12)'
  }
}

# F-026 summary of changes (4.5.6)
$soc = [string](Get-Prop $pub 'summaryOfChanges')
$socNeeded = $action -in @('rewrite', 'ic')
if ($socNeeded -and $soc.Trim() -eq '') { Add-Finding 'FAIL' 'F-026' 'summaryOfChanges' 'required for rewrites and interim changes (4.5.6)' }
if (-not $socNeeded -and $soc.Trim() -ne '') { Add-Finding 'FAIL' 'F-026' 'summaryOfChanges' 'new publications and administrative changes have no summary of changes (4.5.6)' }
if ($action -eq 'ic' -and ((Get-Sentence $soc | Select-Object -Last 1) -ne 'A margin bar (|) indicates newly revised material.')) {
  Add-Finding 'FAIL' 'F-026' 'summaryOfChanges' 'last sentence must be "A margin bar (|) indicates newly revised material." (4.5.6.2)'
}
if ($soc) { $allText.Add($soc); if (@(Get-Sentence $soc).Count -gt 4) { Add-Finding 'WARN' 'F-026' 'summaryOfChanges' 'keep it to a few sentences (4.5.6)' } }

# ---------- body ----------
$body = Get-Prop $pub 'body'
$chapters = @(Get-Prop $body 'chapters' | Where-Object { $null -ne $_ })
$flatParas = @(Get-Prop $body 'paragraphs' | Where-Object { $null -ne $_ })
if ($chapters.Count -eq 0 -and $flatParas.Count -eq 0) { Add-Finding 'FAIL' 'SCHEMA' 'body' 'body needs chapters or paragraphs' }
if ($chapters.Count -gt 0 -and $flatParas.Count -gt 0) { Add-Finding 'FAIL' 'SCHEMA' 'body' 'use chapters or paragraphs, not both' }

$script:RevisedCount = 0
<#
.SYNOPSIS
  Checks one numbered paragraph and, through recursion, its children: levels (F-006), headings (F-028, F-031), notes and
  exceptions (F-037), bullets (F-029), tables (F-038) and the revised flag; collects its text for the text rules.
.PARAMETER P
  The paragraph object of the content file.
.PARAMETER Number
  The paragraph number, for example "1.2.".
.PARAMETER Parts
  The number of parts of the paragraph number (its level).
.PARAMETER TopLevel
  $true for a main paragraph.
#>
function Test-Paragraph($P, [string]$Number, [int]$Parts, [bool]$TopLevel) {
  $where = "para $Number"
  if ($Parts -gt 7) { Add-Finding 'FAIL' 'F-006' $where 'more than seven paragraph levels (4.5.3.5)' }
  $t = [string](Get-Prop $P 'title')
  $x = [string](Get-Prop $P 'text')
  if ($t) { $allText.Add($t) }
  if ($x) { $allText.Add($x) }
  $extra = @(@(Get-Prop $P 'notes') + @(Get-Prop $P 'exceptions') + @(Get-Prop $P 'bullets') | Where-Object { $_ -is [string] })
  $tblObj = Get-Prop $P 'table'
  if ($null -ne $tblObj) { $extra += [string](Get-Prop $tblObj 'title'); foreach ($r in @(Get-Prop $tblObj 'rows')) { $extra += (@($r) -join ' ') } }
  $locText.Add(@($Number.TrimEnd('.'), ($t + ' ' + $x + ' ' + ($extra -join ' '))))
  if ($t -match '^\s*core content\.?\s*$') { Add-Finding 'FAIL' 'F-031' $where 'do not title a section "Core Content" (4.5.9.7)' }
  if ($TopLevel -and -not $t) { Add-Finding 'WARN' 'F-028' $where 'main paragraphs should have a bold heading (4.5.9.2)' }
  if ($t -and $t -notmatch '[.?]$') { Add-Finding 'WARN' 'F-028' $where 'headings end with a period (example "7.5. Certification of Publication as Current.") (4.5.9.2)' }
  if ($x -match '^\s*(Note|Exception)\s*:') { Add-Finding 'FAIL' 'F-037' $where 'put notes in "notes" and exceptions in "exceptions"; the renderer adds the bold label (4.6.2, 4.6.3)' }
  foreach ($n in @(Get-Prop $P 'notes') + @(Get-Prop $P 'exceptions')) {
    if ($null -ne $n) { $allText.Add([string]$n); if ([string]$n -match '^\s*(Note|Exception)\s*:') { Add-Finding 'FAIL' 'F-037' $where 'omit the "Note:" or "Exception:" label; the renderer adds it' } }
  }
  $bul = @(Get-Prop $P 'bullets' | Where-Object { $null -ne $_ })
  if ($bul.Count -gt 0) {
    if ($directive) { Add-Finding 'FAIL' 'F-029' $where 'directive publications cannot use bullets; use numbered paragraphs (4.5.9.3.1)' }
    foreach ($b in $bul) { if ($b -isnot [string]) { Add-Finding 'FAIL' 'F-029' $where 'sub-bullets are not allowed (4.5.9.3.2)' } else { $allText.Add($b) } }
  }
  if ([bool](Get-Prop $P 'revised')) { $script:RevisedCount++ }
  $tbl = Get-Prop $P 'table'
  if ($null -ne $tbl) {
    if (-not [string](Get-Prop $tbl 'title')) { Add-Finding 'FAIL' 'F-038' $where 'tables need a title (placed above the table) (4.6.4)' }
    $cols = @(Get-Prop $tbl 'columns'); $rows = @(Get-Prop $tbl 'rows')
    foreach ($r in $rows) { if (@($r).Count -ne $cols.Count) { Add-Finding 'FAIL' 'SCHEMA' $where 'table row cell count does not match the column count' } }
  }
  $fig = Get-Prop $P 'figure'
  if ($null -ne $fig -and -not [string](Get-Prop $fig 'title')) { Add-Finding 'FAIL' 'F-038' $where 'figures need a title (placed above the figure) (4.6.4)' }
  $kids = @(Get-Prop $P 'children' | Where-Object { $null -ne $_ })
  if ($kids.Count -eq 1 -and -not $integrated) { Add-Finding 'FAIL' 'F-005' $where 'a subparagraph needs at least one companion at the same level (4.5.3.4)' }
  for ($i = 0; $i -lt $kids.Count; $i++) { Test-Paragraph $kids[$i] ("$Number$($i + 1).") ($Parts + 1) $false }
}

if ($chapters.Count -gt 0) {
  for ($c = 0; $c -lt $chapters.Count; $c++) {
    $ch = $chapters[$c]; $cn = $c + 1
    $ct = [string](Get-Prop $ch 'title')
    if (-not $ct) { Add-Finding 'FAIL' 'SCHEMA' "chapter $cn" 'chapter title is missing' }
    elseif ($ct -cne $ct.ToUpper()) { Add-Finding 'FAIL' 'F-033' "chapter $cn" 'chapter titles are all capital letters (4.5.9.7.4.5)' }
    if ($ct -match '^\s*CORE CONTENT\s*$') { Add-Finding 'FAIL' 'F-031' "chapter $cn" 'do not title a section "Core Content" (4.5.9.7)' }
    $ps = @(Get-Prop $ch 'paragraphs' | Where-Object { $null -ne $_ })
    if ($ps.Count -eq 0) { Add-Finding 'FAIL' 'SCHEMA' "chapter $cn" 'chapter has no paragraphs' }
    for ($i = 0; $i -lt $ps.Count; $i++) { Test-Paragraph $ps[$i] ("$cn.$($i + 1).") 2 $true }
  }
} else {
  for ($i = 0; $i -lt $flatParas.Count; $i++) { Test-Paragraph $flatParas[$i] ("$($i + 1).") 1 $true }
}

if ($script:RevisedCount -gt 0 -and $action -ne 'ic') { Add-Finding 'WARN' 'F-026' 'body' 'margin bars ("revised") are for interim changes (4.5.6.2)' }
if ($action -eq 'ic' -and $script:RevisedCount -eq 0) { Add-Finding 'WARN' 'F-026' 'body' 'interim change has no paragraph marked "revised"' }

# F-034 signature block (4.5.10)
$sig = @(Get-Prop $pub 'signature' | Where-Object { $null -ne $_ })
if ($directive -and $sig.Count -eq 0) { Add-Finding 'FAIL' 'F-034' 'signature' 'approving official authentication block is missing (4.5.2, 4.5.10)' }

# ---------- attachments (4.5.11) ----------
$atts = @(Get-Prop $pub 'attachments' | Where-Object { $null -ne $_ })
$gloss = $null
for ($a = 0; $a -lt $atts.Count; $a++) {
  $at = $atts[$a]; $an = $a + 1
  $att = [string](Get-Prop $at 'title')
  if (-not $att) { Add-Finding 'FAIL' 'F-008' "attachment $an" 'each attachment needs a title (4.5.3.7)' }
  elseif ($att -cne $att.ToUpper()) { Add-Finding 'FAIL' 'F-033' "attachment $an" 'attachment titles are all capital letters (4.5.9.7.4.13)' }
  $g = Get-Prop $at 'glossary'
  if ($null -ne $g) {
    if ($an -ne 1) { Add-Finding 'FAIL' 'F-035' "attachment $an" 'the glossary must be Attachment 1 (4.5.11.1)' }
    if ($att -ne 'GLOSSARY OF REFERENCES AND SUPPORTING INFORMATION') { Add-Finding 'FAIL' 'F-035' 'attachment 1' 'title must be GLOSSARY OF REFERENCES AND SUPPORTING INFORMATION (4.5.11.1)' }
    $gloss = $g
  } else {
    $aps = @(Get-Prop $at 'paragraphs' | Where-Object { $null -ne $_ })
    for ($i = 0; $i -lt $aps.Count; $i++) { Test-Paragraph $aps[$i] ("A$an.$($i + 1).") 2 $true }
  }
}
$typeNum = [string](Get-Prop $meta 'typeAndNumber')
$needsGlossary = $typeNum -cmatch '\b(INSTRUCTION|MANUAL|POLICY DIRECTIVE)\b'
if ($needsGlossary -and $null -eq $gloss) { Add-Finding 'FAIL' 'F-035' 'attachments' 'Attachment 1 (glossary) is required for policy directives, instructions and manuals (4.5.11.1)' }

$abbr = @{}
$abbrKind = @{}   # term -> 'abbreviations' or 'officeSymbols'
if ($null -ne $gloss) {
  foreach ($r in @(Get-Prop $gloss 'references')) {
    if ($null -ne $r -and [string]$r -match '(https?://|www\.)') { Add-Finding 'FAIL' 'F-035' 'glossary.references' "references do not include URLs: '$r' (4.5.11.1)" }
  }
  foreach ($sec in 'abbreviations', 'officeSymbols', 'terms') {
    $items = @(Get-Prop $gloss $sec | Where-Object { $null -ne $_ })
    $names = @($items | ForEach-Object { [string](Get-Prop $_ 'term') })
    $sorted = @($names | Sort-Object)
    if (($names -join '|') -ne ($sorted -join '|')) { Add-Finding 'WARN' 'F-035' "glossary.$sec" 'list entries in alphabetical order (4.5.11.1)' }
    if ($sec -ne 'terms') { foreach ($n in $names) { $abbr[$n] = $true; $abbrKind[$n] = $sec } }
  }
}

# ---------- writing rules over all text ----------
$joined = (Get-PlainText ($allText -join "`n"))
# Cover values (OPR, Certified by, unit lines) use glossary entries too (T06 review 12 Nov 26): count them as use.
$coverText = (@(foreach ($f in 'opr', 'certifiedBy', 'byOrderOfUnit', 'issuerLine', 'title', 'typeAndNumber') { [string](Get-Prop $meta $f) }) -join "`n")
$skip = @('DAF', 'AFI', 'DAFI', 'DAFMAN', 'AFMAN', 'UCMJ', 'USC', 'DOD', 'NOTE', 'TABLE', 'A', 'I', 'II', 'III', 'IV')
foreach ($k in @($abbr.Keys)) {
  $pattern = "(?<![A-Za-z0-9/-])$([regex]::Escape($k))(?![A-Za-z0-9-])"
  $c = ([regex]::Matches($joined, $pattern)).Count
  $all = $c + ([regex]::Matches($coverText, $pattern)).Count
  if ($all -eq 0) { Add-Finding 'WARN' 'F-032' 'glossary' "'$k' is listed but not used in the text" }
  # The four-times rule is for acronyms only: not office symbols, not publication-type prefixes in references (AFI 33-322).
  elseif ($c -le 4 -and $abbrKind[$k] -eq 'abbreviations' -and $k -notin $skip) { Add-Finding 'WARN' 'F-032' 'glossary' "'$k' is used $c time(s); acronyms used four times or less should generally be spelled out (4.5.9.7.2.5)" }
}
$caps = [regex]::Matches($joined, '\b[A-Z]{2,6}\b') | ForEach-Object { $_.Value } | Sort-Object -Unique
foreach ($w in $caps) {
  if (-not $abbr.ContainsKey($w) -and $w -notin $skip -and $joined -notmatch "\($w\)") {
    Add-Finding 'WARN' 'F-032' 'text' "'$w' is not defined at first use or listed in Attachment 1 (4.5.9.7.2)"
  }
}

$pi = 0
foreach ($t in $allText) {
  $pi++
  $plain = Get-PlainText $t
  if ($plain -match '\bshall\b') { Add-Finding 'FAIL' 'W-001' "text block $pi" 'use "must", not "shall" (Table 1.1)' }
  $sent = @(Get-Sentence $t)
  if ($sent.Count -gt 7 -and $t -ne $opening) { Add-Finding 'WARN' 'W-002' "text block $pi" "paragraph has $($sent.Count) sentences; use seven or fewer (Table 1.1)" }
  foreach ($s in $sent) {
    $wc = @($s -split '\s+' | Where-Object { $_ -match '\w' -and $_ -notmatch '^\(T-[0-3]\)$' }).Count
    if ($wc -gt 20 -and $t -ne $opening) { Add-Finding 'WARN' 'W-002' "text block $pi" "sentence has $wc words; use 20 or fewer: '$($s.Substring(0, [Math]::Min(60, $s.Length)))...'" }
    # PFM 2B (2026-11-12): wing or delta statements carry no tier unless the waiver authority is above the wing, so F-039 is off there.
    # The fixed summary-of-changes sentence ("... revised and must be completely reviewed") is not a compliance statement (T06 review 12 Nov 26).
    $fixedSoc = $s -match '^\s*This (document|publication) has been (substantially )?revised and (must|should) be completely reviewed'
    if (-not $wingLevel -and -not $fixedSoc -and $s -match '\b(will|must)\b' -and $s -notmatch '\(T-[0-3]\)' -and $t -ne $opening) {
      Add-Finding 'WARN' 'F-039' "text block $pi" "possible compliance statement without a tier number: '$($s.Substring(0, [Math]::Min(60, $s.Length)))...' (4.6.5)"
    }
  }
  foreach ($m in [regex]::Matches($plain, '\b[A-Z]{7,}\b')) { Add-Finding 'WARN' 'W-003' "text block $pi" "'$($m.Value)': do not use capital letters for emphasis (Table 1.1)" }
  $opens = ([regex]::Matches($t, '\{([ib])\}')).Count; $closes = ([regex]::Matches($t, '\{/([ib])\}')).Count
  if ($opens -ne $closes) { Add-Finding 'FAIL' 'SCHEMA' "text block $pi" 'unbalanced {i}/{b} markup' }
}

# ---------- Attachment 1 tracking report (4.5.11.1): what the text uses vs what the glossary lists ----------
$listedRefs = @(); $listedForms = @()
if ($null -ne $gloss) {
  $listedRefs = @(Get-Prop $gloss 'references' | Where-Object { $null -ne $_ } | ForEach-Object { Get-PlainText ([string]$_) })
  $listedForms = @((@(Get-Prop $gloss 'prescribedForms') + @(Get-Prop $gloss 'adoptedForms')) | Where-Object { $null -ne $_ } | ForEach-Object { Get-PlainText ([string]$_) })
}
$locText.Insert(0, @('opening', $opening))
if ($soc) { $locText.Insert(1, @('summaryOfChanges', $soc)) }
$seen = @{}
foreach ($lt in $locText) {
  $where = [string]$lt[0]; $plain = Get-PlainText ([string]$lt[1])
  foreach ($m in [regex]::Matches($plain, '\(([A-Z][A-Z0-9/&-]*[A-Z][A-Za-z0-9/&-]*)\)')) {
    $k = 'ACR ' + $m.Groups[1].Value
    if ($m.Groups[1].Value -match '^T-[0-3]$') { continue }
    if (-not $seen.ContainsKey($k)) { $seen[$k] = $where; $listed = $abbr.ContainsKey($m.Groups[1].Value)
      Write-Output ("ATT1 acronym {0} first={1} listed={2}" -f $m.Groups[1].Value, $where, $(if ($listed) { 'yes' } else { 'no' })) }
  }
  foreach ($m in [regex]::Matches($plain, '\b((?:DAF|AF|DD|SF|OF|[A-Z0-9]{2,8}) Form [0-9][0-9A-Z-]*)')) {
    $k = 'FORM ' + $m.Groups[1].Value
    if (-not $seen.ContainsKey($k)) { $seen[$k] = $where; $fm = $m.Groups[1].Value; $listed = @($listedForms | Where-Object { $_ -match ('^' + [regex]::Escape($fm) + '([^0-9A-Za-z]|$)') }).Count -gt 0
      Write-Output ("ATT1 form {0} first={1} listed={2}" -f $m.Groups[1].Value, $where, $(if ($listed) { 'yes' } else { 'no' }))
      if (-not $listed) { Add-Finding 'WARN' 'F-035' $where "form '$($m.Groups[1].Value)' is used but not listed in Attachment 1 (4.5.11.1)" } }
  }
  foreach ($m in [regex]::Matches($plain, '\b(DoD[DIM]?|DAF(?:PD|I|MAN|PAM|H)|AF(?:PD|I|MAN|PAM|H)|SPF(?:PD|I|MAN))\)?\s?([0-9]{1,2}-[0-9]{2,4}(?:V[0-9]+)?)')) {
    $ref = $m.Groups[1].Value + ' ' + $m.Groups[2].Value
    $k = 'REF ' + ($ref -replace '\s', '')
    if (-not $seen.ContainsKey($k)) { $seen[$k] = $where
      $listed = @($listedRefs | Where-Object { ($_ -replace '\s', '') -like (($ref -replace '\s', '') + '*') }).Count -gt 0
      Write-Output ("ATT1 reference {0} first={1} listed={2}" -f $ref, $where, $(if ($listed) { 'yes' } else { 'no' }))
      if (-not $listed) { Add-Finding 'WARN' 'F-035' $where "reference '$ref' is cited but not listed in Attachment 1 (4.5.11.1)" } }
  }
}

# ---------- F-040 tier at the issuer's own level (Attachment 10 note 4) ----------
# The wing or delta/CC who approved a wing or delta publication is already the default waiver authority,
# so (T-3) in that publication is redundant. Wing level = By Order of the Commander and an issuer line
# (or By Order unit line) that names a WING or DELTA ($wingLevel, set after F-013).
if ($wingLevel) {
  foreach ($lt in $locText) {
    $where = [string]$lt[0]; $plain = Get-PlainText ([string]$lt[1])
    foreach ($m in [regex]::Matches($plain, '\(\s*T\s*[-\u2013]\s*3\s*\)')) {
      $start = [Math]::Max(0, $m.Index - 50)
      Add-Finding 'WARN' 'F-040' $where ("(T-3) is redundant in a wing or delta publication; the wing or delta/CC who approved it is already the waiver authority: '..." + $plain.Substring($start, $m.Index + $m.Length - $start).Trim() + "' (Attachment 10 note 4)")
    }
  }
}

# ---------- report ----------
$fails = @($script:Findings | Where-Object { $_.Level -eq 'FAIL' }).Count
$warns = @($script:Findings | Where-Object { $_.Level -eq 'WARN' }).Count
foreach ($f in $script:Findings) { Write-Output ('{0} {1} {2}: {3}' -f $f.Level, $f.Rule, $f.Where, $f.Message) }
Write-Output "VALIDATE fails=$fails warns=$warns"
if ($fails -gt 0) { exit 1 }
exit 0
