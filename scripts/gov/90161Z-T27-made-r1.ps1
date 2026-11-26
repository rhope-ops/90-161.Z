<#
.SYNOPSIS
  90-161.Z Task 27 r1, module "made" (round R43; the PFM, 25 Nov 26: RADE Uninstall): the one table of what the 90-161.Z install
  can make, and the gate that reads RADE's list of what the install made (RADE_MADE).
.DESCRIPTION
  Loaded by 90161Z-T27-lifecycle-r1.ps1 (dot-sourced from the same folder, in its scope); it does nothing when it is run alone.
  The contract (RADE engine-v41; the R43 plan, "Engine facts"): RADE runs an uninstall step with RADE_MODE=uninstall and RADE_MADE = the
  path of a JSON file of schema rade-made/1: { schema, app, made: [ { step, kind, name } ] }. Each made entry comes from one line that an
  install step printed: "MADE <kind>: <name>" (T20 prints them: kind list with the display title, kind group, kind level). This file is
  the ONE table of those exact names: kind 'list' with the title of one of the 12 lists, 'group' PFM Office, 'level' PFM Office Edit
  All Items; kind 'file' (the install note of T22) stays from the first build. tests/ps/Test-T20.ps1 checks that T20 prints these names.
  Safety rule (the PFM's data boundary): a thing is removed only when ALL of these agree: RADE_MODE is uninstall, the file is rade-made/1
  of the app 90-161.Z, and the thing is in the own-name table below. The PFM's decision of 25 Nov 26: the lists are removed by their fixed
  names whether or not the made list names them (the 12 lists of the test site were made before RADE installs); the group and the level
  go only when the made list names them (a group cannot go to a Recycle Bin, so its removal cannot be undone); the made list adds
  NOTE lines for a name that is not ours. A list must also have its internal name as its folder name, and its
  fixed title (the one it has after T20 step 4) or, for a list that a stopped install left, its internal name as title.
  Network: none.
  Writes: none.
  Credentials: none.
  Run: not alone.
#>

# The app that the made list must name.
$MadeApp = '90-161.Z'
$MadeSchema = 'rade-made/1'
# The 12 lists the install makes: internal name = display title (T20 creates each under its internal name, then sets the display
# title, and prints "MADE list: <display title>"). Order: the lists that
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

# The answer of Read-MadeFile for a made list that is not accepted: not Ok, the reason, no entries.
function Get-MadeRefusal([string]$Why) { return @{ Ok = $false; Why = $Why; Items = @(); Dropped = 0 } }

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
  if ($Mode -cne 'uninstall') { return (Get-MadeRefusal 'RADE_MODE is not uninstall: nothing is removed') }
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return (Get-MadeRefusal 'RADE_MADE is not a file: nothing is removed') }
  try { $j = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return (Get-MadeRefusal 'RADE_MADE is not valid JSON: nothing is removed') }
  if ([string]$j.schema -cne $MadeSchema) { return (Get-MadeRefusal ('RADE_MADE schema is not ' + $MadeSchema + ': nothing is removed')) }
  if ([string]$j.app -cne $MadeApp) { return (Get-MadeRefusal ('RADE_MADE is not for the app ' + $MadeApp + ': nothing is removed')) }
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
  The internal name of an own list, from its display title as T20 prints it in "MADE list: <title>"; '' for any other name.
.PARAMETER Name
  The name in the made list.
.OUTPUTS
  System.String. The internal name (a key of $OwnLists), or ''. The match is case sensitive.
#>
function Resolve-OwnList([string]$Name) {
  foreach ($k in $OwnLists.Keys) { if ($Name -ceq $OwnLists[$k]) { return [string]$k } }
  return ''
}

<#
.SYNOPSIS
  The site list to remove for one own list: its folder name is the internal name AND its title is the fixed title (or the internal name,
  which a list has between T20 step 1 and step 4); $null for any other list.
.PARAMETER SiteLists
  The lists of the site (Get-SiteList).
.PARAMETER Key
  The internal name (a key of $OwnLists).
.OUTPUTS
  The site list, or $null. A list with an own title and another folder name, and a list with the own folder name and another title,
  are never returned.
#>
function Find-OwnListToRemove($SiteLists, [string]$Key) {
  $l = Find-OurList $SiteLists $Key
  if ($l -and ([string]$l.Title -ceq $OwnLists[$Key] -or [string]$l.Title -ceq $Key)) { return $l }
  return $null
}

<#
.SYNOPSIS
  The reason text for an own list that Find-OwnListToRemove did not return (nothing left, or a list that is not ours holds the title).
.PARAMETER SiteLists
  The lists of the site.
.PARAMETER Key
  The internal name.
.OUTPUTS
  System.String. The text for the SKIP line (no title of a list that is not ours).
#>
function Get-ListLeftReason($SiteLists, [string]$Key) {
  if (Find-OurList $SiteLists $Key) { return 'the list with this folder name has another title, so it is not removed' }
  if (@($SiteLists | Where-Object { [string]$_.Title -ceq $OwnLists[$Key] }).Count) { return 'a list with this title is on the site, but it is not ours (another folder name): not removed' }
  return 'the list is not on the site: nothing left to remove'
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
