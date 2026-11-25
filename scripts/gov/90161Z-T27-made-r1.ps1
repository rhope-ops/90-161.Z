<#
.SYNOPSIS
  90-161.Z Task 27 r1, module "made" (round R43; the PFM, 25 Nov 26: RADE Uninstall): the one table of what the 90-161.Z install
  can make, and the gate that reads RADE's list of what the install made (RADE_MADE).
.DESCRIPTION
  Loaded by 90161Z-T27-lifecycle-r1.ps1 (dot-sourced from the same folder, in its scope); it does nothing when it is run alone.
  The contract (the R43 plan, "Engine facts for T5 and T7"; RADE engine-v40 is not released yet, so this is coded against the
  plan text): RADE runs an uninstall step with RADE_MODE=uninstall and RADE_MADE = the path of a JSON file of schema
  rade-made/1: { schema, app, made: [ { step, kind, name } ] }. The plan does not say which kind words RADE writes or whether
  a list name is its title or its internal name. This file is the ONE place that decides it: kind 'list', 'group', 'level' and
  'file' (the table below); a list name is accepted as its display title or its internal name. A different word makes the
  entry "refused" (nothing is removed for it). Change the table here when the real file differs.
  Safety rule (the PFM's data boundary and "delete only what the install made"): a thing is removed only when ALL of these agree:
  RADE_MODE is uninstall, the file is rade-made/1 of the app 90-161.Z, an entry names the thing, and the thing is in the own-name
  table below. The site is read last (the main file): a list must also have its internal name as its folder name.
  Network: none. Writes: none. Credentials: none.
  Run: not alone.
#>

# The app that the made list must name.
$MadeApp = '90-161.Z'
$MadeSchema = 'rade-made/1'
# The 12 lists the install makes (T20 creates each under its internal name, then sets the display title). Order: the lists that
# other lists point to by a lookup column come LAST, so Uninstall removes a list before the lists it points to
# (the reverse of the payload order in flow/provisioning-payload.json; tests/ps/Test-T27.ps1 checks the names and the order).
$OwnLists = [ordered]@{
  PFMReviews = 'PFM Reviews'; PFMRecommendations = 'PFM Recommendations (DAF Form 847)'; PFMEndorsements = 'PFM Endorsements'
  PFMActivityLog = 'PFM Activity Log'; PFMWaivers = 'PFM Waivers'; PFMPublications = 'PFM Publications'
  PFMProductIndex = 'PFM Product Index'; PFMGuidance = 'PFM Guidance'; PFMSettings = 'PFM Settings'
  PFMSeries = 'PFM Series'; PFMProcessSteps = 'PFM Process Steps'; PFMOffices = 'PFM Offices'
}
# The group and the permission level T20 step 6 makes only when the site has none (T20 access module: $OfficeLevel; main file: $OfficeGroup).
$OwnGroup = 'PFM Office'
$OwnLevel = 'PFM Office Edit All Items'
# The note file the install step writes on this computer (T22 maint -Part Install), in the T22 folder. The RADE install record is not here:
# RADE keeps it and marks it uninstalled (DECISIONS 2026-11-25), so no script of this task touches it.
$OwnNote = '^90161Z-T22-install-r\d+\.txt$'

<#
.SYNOPSIS
  Reads RADE's made list and checks it before anything is removed.
.PARAMETER Mode
  The value of RADE_MODE. Only 'uninstall' passes.
.PARAMETER Path
  The value of RADE_MADE: the path of the JSON file.
.OUTPUTS
  System.Collections.Hashtable. Ok ($true or $false), Why (the reason when not Ok, no path and no site text), Items (the entries that
  have a step, a kind and a name, as text), Dropped (the count of entries that miss one of the three).
#>
function Read-MadeFile([string]$Mode, [string]$Path) {
  $bad = { param($why) return @{ Ok = $false; Why = $why; Items = @(); Dropped = 0 } }
  if ($Mode -cne 'uninstall') { return (& $bad 'RADE_MODE is not uninstall: nothing is removed') }
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return (& $bad 'RADE_MADE is not a file: nothing is removed') }
  try { $j = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return (& $bad 'RADE_MADE is not valid JSON: nothing is removed') }
  if ([string]$j.schema -cne $MadeSchema) { return (& $bad ('RADE_MADE schema is not ' + $MadeSchema + ': nothing is removed')) }
  if ([string]$j.app -cne $MadeApp) { return (& $bad ('RADE_MADE is not for the app ' + $MadeApp + ': nothing is removed')) }
  $items = @(); $dropped = 0
  foreach ($m in @($j.made)) {
    if ($m -and $m.step -and $m.kind -and $m.name) { $items += @{ Step = [string]$m.step; Kind = [string]$m.kind; Name = [string]$m.name } } else { $dropped++ }
  }
  return @{ Ok = $true; Why = ''; Items = $items; Dropped = $dropped }
}

<#
.SYNOPSIS
  The names of one kind in the made list, without repeats.
.PARAMETER Items
  The Items of Read-MadeFile.
.PARAMETER Kind
  'list', 'group', 'level' or 'file'.
.OUTPUTS
  System.String[]. The names, in file order.
#>
function Get-MadeName($Items, [string]$Kind) {
  $seen = @{}; $out = @()
  foreach ($i in @($Items)) { if ($i.Kind -ceq $Kind -and -not $seen.ContainsKey($i.Name)) { $seen[$i.Name] = 1; $out += $i.Name } }
  return $out
}

<#
.SYNOPSIS
  The internal name of an own list, from its display title or its internal name; '' for any other name.
.PARAMETER Name
  The name in the made list.
.OUTPUTS
  System.String. The internal name (a key of $OwnLists), or ''.
#>
function Resolve-OwnList([string]$Name) {
  foreach ($k in $OwnLists.Keys) { if ($Name -ceq $k -or $Name -ceq $OwnLists[$k]) { return [string]$k } }
  return ''
}

<#
.SYNOPSIS
  Whether a name in the made list is the one fixed own name of its kind: the group, the level or the install note file.
.PARAMETER Kind
  'group', 'level' or 'file'.
.PARAMETER Name
  The name in the made list.
.OUTPUTS
  System.Boolean. $true only for the group PFM Office, the level PFM Office Edit All Items, or a plain install note file name
  (no path: a name with a folder part is refused).
#>
function Test-OwnName([string]$Kind, [string]$Name) {
  switch ($Kind) {
    'group' { return ($Name -ceq $OwnGroup) }
    'level' { return ($Name -ceq $OwnLevel) }
    'file' { return ([IO.Path]::GetFileName($Name) -ceq $Name -and $Name -cmatch $OwnNote) }
    default { return $false }
  }
}
