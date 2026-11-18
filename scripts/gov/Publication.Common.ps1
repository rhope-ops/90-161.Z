# 90-161.Z shared functions, dot-sourced by Test-Publication.ps1 and New-Publication.ps1.
# Windows PowerShell 5.1 and pwsh 7. No external modules.
# Fixed statements are verbatim DAFMAN 90-161 text; paragraph numbers are given with each.
# Inputs: the publication content object of the caller. Outputs: functions (Get-Prop, Get-OpeningParagraph,
# ConvertTo-TwoSpaceSentence) and the statement texts in $script:Stmt.
# Network: none.
# Writes: none.
# Credentials: none.

$script:Stmt = @{
  # 4.5.5.8 (records management statement)
  Records    = 'Ensure all records generated as a result of processes prescribed in this publication adhere to Air Force Instruction (AFI) 33-322, {i}Records Management and Information Governance Program{/i}, and are disposed in accordance with the Air Force Records Disposition Schedule, which is located in the Air Force Records Information Management System.'
  # 4.5.5.9 (recommending changes statement, example)
  Changes    = 'Refer recommended changes and questions about this publication to the office of primary responsibility (OPR) using the DAF Form 847, {i}Recommendation for Change of Product{/i}; route DAF Forms 847 from the field through the appropriate functional chain of command.'
  # Table 4.5 item 2 / item 3 (4.5.5.10.1)
  SupplementMay    = 'This publication may be supplemented at any level, but all supplements must be routed to the OPR of this publication for coordination prior to certification and approval.'
  SupplementMayNot = 'This publication may not be supplemented or further implemented or extended.'
  # 4.5.5.11 (waiver authority statement, example)
  Waiver     = 'The authorities to waive wing, unit, or delta level requirements in this publication are identified with a tier (' + [char]0x201C + 'T-0, T-1, T-2, T-3' + [char]0x201D + ') number following the compliance statement. Submit requests for waivers through the chain of command to the appropriate tier waiver approval authority, or alternately, to the publication OPR for non-tiered compliance items.'
  # 4.5.5.4
  Copyright  = 'This publication contains copyrighted material.'
  # 4.5.5.5
  Paperwork  = 'This publication is subject to the Paperwork Reduction Act of 1995.'
  # 4.5.5.12 (must be the last sentence)
  TradeNames = 'The use of the name or mark of any specific manufacturer, commercial product, commodity, or service in this publication does not imply endorsement by the Department of the Air Force.'
}

# The value of the property $Name of an object from the content file, or $null when the object or the property is missing
# (one copy for the validator and the renderer; code standard S1, rule C5).
function Get-Prop($Obj, [string]$Name) {
  if ($null -eq $Obj) { return $null }
  $p = $Obj.PSObject.Properties[$Name]
  if ($null -eq $p) { return $null }
  return $p.Value
}

<#
.SYNOPSIS
  Returns the opening paragraph (4.5.5). Uses "openingParts" when present (fixed text from code, slots from content),
  else the free-text "opening" field. Order follows 4.5.5.1-4.5.5.12.
.PARAMETER Pub
  The publication content object.
.OUTPUTS
  System.String. The opening paragraph text.
#>
function Get-OpeningParagraph($Pub) {
  $parts = Get-Prop $Pub 'openingParts'
  if ($null -eq $parts) { return [string](Get-Prop $Pub 'opening') }
  $s = New-Object System.Collections.Generic.List[string]
  $ante = [string](Get-Prop $parts 'antecedent')
  if ($ante) { $s.Add('This publication implements ' + $ante.TrimEnd('.') + '.') }                 # 4.5.5.1
  $purpose = [string](Get-Prop $parts 'purpose')
  if ($purpose) { $s.Add($purpose) }                                                                  # 4.5.5 (what it covers)
  $appl = [string](Get-Prop $parts 'applicability')
  if ($appl) { $s.Add($appl) }                                                                        # 4.5.5.2
  $pa = Get-Prop $parts 'privacyAct'
  if ($null -ne $pa) {                                                                                # 4.5.5.3
    $s.Add('This publication requires the collection and or maintenance of information protected by the Privacy Act of 1974 authorized by ' + ([string](Get-Prop $pa 'authority')).TrimEnd('.', ' ') + '. The applicable System of Record Notice(s) (SORN) ' + ([string](Get-Prop $pa 'sorn')).TrimEnd('.', ' ') + ' is (are) available at: http://dpclo.defense.gov/Privacy/SORNs.aspx.')
  }
  if ([bool](Get-Prop $parts 'copyright')) { $s.Add($script:Stmt.Copyright) }                    # 4.5.5.4
  if ([bool](Get-Prop $parts 'paperworkReduction')) { $s.Add($script:Stmt.Paperwork) }          # 4.5.5.5
  $pun = [string](Get-Prop $parts 'punitiveScope')
  if ($pun) {                                                                                         # 4.5.5.6
    $s.Add('Failure to obey this ' + $pun + ' constitutes a violation of Article 92(1), UCMJ' + [char]0x2014 + 'failure to obey lawful order or regulation. Article 92(1) of the UCMJ does not apply to members of the ANG while in Title 32 status (that is, activated for state duty under state command), but ANG members may be subject to an equivalent article under a state military justice code.')
  }
  $stat = [string](Get-Prop $parts 'statutory')
  if ($stat) { $s.Add($stat) }                                                                        # 4.5.5.7
  $s.Add($script:Stmt.Records)                                                                        # 4.5.5.8
  $s.Add($script:Stmt.Changes)                                                                        # 4.5.5.9
  $sup = [string](Get-Prop $parts 'supplement')
  if ($sup -ceq 'mayNot') { $s.Add($script:Stmt.SupplementMayNot) }
  elseif ($sup -ceq 'may') { $s.Add($script:Stmt.SupplementMay) }
  else { throw "openingParts.supplement must be 'may' or 'mayNot' (4.5.5.10.1); found '$sup'" }   # 4.5.5.10
  $s.Add($script:Stmt.Waiver)                                                                         # 4.5.5.11
  if ([bool](Get-Prop $parts 'tradeNames')) { $s.Add($script:Stmt.TradeNames) }                 # 4.5.5.12, last
  return ($s -join ' ')
}

$script:NoBreakAbbrev = @('e.g.', 'i.e.', 'Mr.', 'Mrs.', 'Ms.', 'Dr.', 'No.', 'Nos.', 'U.S.', 'St.', 'Jr.', 'Sr.', 'vs.', 'para.', 'Vol.', 'Fig.', 'Col.', 'Lt.', 'Gen.', 'Brig.', 'Maj.', 'Capt.', 'Sgt.')

<#
.SYNOPSIS
  L-004: two spaces before each new sentence (measured in DAFMAN 90-161: 6.55 pt vs 3.14 pt word gap); one space after a
  known abbreviation or an initial, and before a tier number.
.PARAMETER Text
  The text (with inline markup).
.OUTPUTS
  System.String. The text with the sentence gaps set.
#>
function ConvertTo-TwoSpaceSentence([string]$Text) {
  if (-not $Text) { return $Text }
  $rx = [regex]('(?<end>\(T-[0-3]\)|[.?!][)"' + [char]0x201D + ']?(?:\{/[ib]\})?)(?<ws>[ ]+)(?=[A-Z0-9"(' + [char]0x201C + '{])')
  return $rx.Replace($Text, {
      param($m)
      $before = $Text.Substring(0, $m.Index + $m.Groups['end'].Length)
      foreach ($a in $script:NoBreakAbbrev) { if ($before -cmatch ('(^|[\s(])' + [regex]::Escape($a) + '$')) { return $m.Value } }
      if ($before -cmatch '(^|\s)[A-Z]\.$') { return $m.Value }              # initials, e.g. "Kimber L. Nettis"
      if ($Text.Substring($m.Index + $m.Length) -match '^\(T-[0-3]\)') { return $m.Groups['end'].Value + ' ' }   # one space before a tier number (measured: 3.08 pt, n=109)
      return $m.Groups['end'].Value + '  '
    })
}
