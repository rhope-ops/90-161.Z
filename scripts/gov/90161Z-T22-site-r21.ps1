<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "site": the PFM window reads the PFM lists of the test site, read-only, and fills its cards
  from them (round R41; PFM 20 Nov 26, docs/reviews/2026-11-21-r41-plan.md row 1).
.DESCRIPTION
  What it reads: the rows of 2 PFM lists, PFM Publications (the grids Who Has It Now of Your Work and of the "nothing
  needs you" card, and All Actions) and PFM Endorsements (the grid of answers on the endorsement card, so an endorser's
  answer shows here read-only, plan row 2). Only the columns a card shows: the title, the publication number, the
  action, the step, the status and the dates. No person column is read, so no name can show (Data boundary rule).
  How: PnP.PowerShell 1.12.0, your own CAC sign-in in the PnP web login window (Connect-PnPOnline -UseWebLogin), the
  one site RADE holds (the main script reads it with its site-common block and gives it here), then Get-PnPListItem on each list. Nothing on the site is
  written: this part calls no command that adds, changes or removes anything (tests/run.sh checks the text).
  Empty: a grid whose list has no rows shows its empty state, one line that the list has no rows.
  Fake-data markers (the test site holds fake rows only; PFM 20 Nov 26): a fake row's title starts with "90161Z TEST"
  (every row the round scripts T18 and T24 made) or "XXX XXX " (the window's own fake names). Each row shown on a card
  is checked before a picture of that card is saved (Get-SiteUnmarked; the measure and feedback parts ask it): a card
  with a row that has no marker gets no picture, so its data stops at the boundary.
  Offline: when the site cannot be read (no PnP.PowerShell, no site address, the sign-in or a read failed), the window
  keeps its FAKE cards; -Measure and -PlanOnly never read the site (the cards part's FAKE data is their source).
  Lines: SOURCE site or SOURCE fake (why); READ <list> rows=<n> for each list read; WRITES=0; MARKER rows checked=<n>
  without a marker=<n>. Counts only: no row text, no address.
  Inputs: $Cards, $GridQueue, $lines, $dir (the cards part and the main script). Outputs: the functions below and
  $script:SiteSource, $script:SiteShown (card key -> the titles of the site rows it shows).
  Run: not alone; 90161Z-T22-pfm-window-r21.ps1 dot-sources it from its own folder inside its try block.
  Network: the one SharePoint site given in RADE (RADE_SITE) or in Config\90161Z-site.txt, through PnP.PowerShell; read only.
  Writes: none on the site; on this computer only, once, Config\90161Z-site.txt when the site address is typed outside RADE.
  Credentials: your own CAC sign-in through the PnP web login window; nothing is stored.
#>
$script:SiteSource = 'fake'; $script:SiteShown = @{}
$script:FakeMarks = @('90161Z TEST', 'XXX XXX ')   # the repo's fake-data markers (see the header)
# The lists this window reads and the columns it reads from each (internal names, schemas/lists).
$script:SiteLists = [ordered]@{
  'PFM Publications' = @('Title', 'PublicationNumber', 'ActionType', 'ProcessStep', 'ActionStatus', 'CoordinationSuspense', 'Modified')
  'PFM Endorsements' = @('Title', 'EndorsementStatus', 'ResponseDate', 'Modified') }
# True when title $Title starts with one of the fake-data markers.
function Test-FakeRow([string]$Title) {
  foreach ($m in $script:FakeMarks) { if (([string]$Title).StartsWith($m)) { return $true } }
  return $false
}
# The number of site rows card $Key shows that have no fake-data marker (0 for a card with no site rows).
function Get-SiteUnmarked([string]$Key) { return @(@($script:SiteShown[$Key]) | Where-Object { $null -ne $_ -and -not (Test-FakeRow $_) }).Count }
# The text of field value $V: a lookup gives its shown value, a date its day as d MMM yy, $null an empty text.
function Get-SiteText($V) {
  if ($null -eq $V) { return '' }
  if ($V -is [datetime]) { return $V.ToLocalTime().ToString('d MMM yy', [Globalization.CultureInfo]::InvariantCulture) }
  if ($V.PSObject.Properties['LookupValue']) { return [string]$V.LookupValue }
  return [string]$V
}
# The weekdays from date $V to today (0 when there is no date): the age of a row on its step.
function Get-SiteAge($V) {
  if (-not ($V -is [datetime])) { return 0 }
  $d = $V.ToLocalTime().Date; $n = 0
  while ($d -lt (Get-Date).Date) { $d = $d.AddDays(1); if ($d.DayOfWeek -ne 'Saturday' -and $d.DayOfWeek -ne 'Sunday') { $n++ } }
  return $n
}
# The chip kind of an Action Status (schemas/lists/PFMPublications.json): On Track ok, On Hold soon, Stalled late, else neutral.
function Get-SiteKind([string]$Status) {
  switch ($Status) { 'On Track' { return 'ok' } 'On Hold' { return 'soon' } 'Stalled' { return 'late' } default { return 'neu' } }
}
<#
.SYNOPSIS
  Turns the PFM Publications rows into the row tables of the Your Work grid and of the All Actions grid.
.DESCRIPTION
  The same keys as the cards part's FAKE rows (ConvertTo-HomeRow, ConvertTo-QueueRow): Publication is "number|title"
  (a dash for a row with no number), With is a dash (no person column is read), the row opens the Publications card.
.PARAMETER Items
  The list items (Get-PnPListItem).
.OUTPUTS
  @{ Home = the Your Work rows; Queue = the All Actions rows; Titles = the row titles }.
#>
function ConvertTo-SitePubRow($Items) {
  $hrows = @(); $queue = @(); $titles = @()
  foreach ($it in @($Items)) {
    $t = Get-SiteText $it['Title']; $num = Get-SiteText $it['PublicationNumber']; if (-not $num) { $num = '-' }
    $st = Get-SiteText $it['ActionStatus']; $kind = Get-SiteKind $st; $age = Get-SiteAge $it['Modified']
    $due = Get-SiteText $it['CoordinationSuspense']; if (-not $due) { $due = '-' }
    $act = Get-SiteText $it['ActionType']; $step = Get-SiteText $it['ProcessStep']
    $hrows += @{ Publication = ($num + '|' + $t); Action = $act; Step = $step; With = '-'; Since = (Get-SiteText $it['Modified']); Age = ([string]$age + ' d')
      Due = $due; Status = $st; Kind = $kind; Go = 'pub' }
    $queue += @{ Publication = ($num + '|' + $t); Action = $act; Step = $step; Weekdays = [string]$age; With = '-'; Status = $st; Kind = $kind; Go = 'pub'; Me = $false }
    $titles += $t }
  return @{ Home = $hrows; Queue = $queue; Titles = $titles }
}
# Turns the PFM Endorsements rows into the rows of the answers grid (Office is the row title; no person column is read).
function ConvertTo-SiteAnswerRow($Items) {
  foreach ($it in @($Items)) {
    $a = Get-SiteText $it['EndorsementStatus']; if (-not $a) { $a = 'Not Started' }
    $sig = Get-SiteText $it['ResponseDate']; if (-not $sig) { $sig = '-' }
    $done = ($a -ne 'Not Started')
    @{ Office = (Get-SiteText $it['Title']); Answer = $a; Comments = '-'; Signature = $sig; Status = $(if ($done) { 'Answered' } else { 'Waiting' })
      Kind = $(if ($done) { 'ok' } else { 'neu' }); Go = '' } }
}
<#
.SYNOPSIS
  Puts site rows into one grid block of a card, or the empty state when there are none.
.PARAMETER Card
  The card key in $Cards.
.PARAMETER Name
  The grid's Name (its accessible name).
.PARAMETER Rows
  The row tables.
.PARAMETER List
  The list title, for the empty-state line.
.PARAMETER Titles
  The titles of the rows, kept for the marker check of the card's picture.
#>
function Merge-SiteGrid([string]$Card, [string]$Name, $Rows, [string]$List, $Titles) {
  foreach ($col in @($Cards[$Card].Cols)) { foreach ($sec in @($col)) {
      $bl = @($sec.Blocks)
      for ($i = 0; $i -lt $bl.Count; $i++) {
        if ($bl[$i].T -ne 'grid' -or $bl[$i].Name -ne $Name) { continue }
        if (@($Rows).Count) { $bl[$i].Rows = @($Rows) }
        else { $bl[$i] = @{ T = 'p'; Style = 'note'; Text = ('Nothing to show yet: the list ' + $List + ' on your site has no rows.') } }
        if ($sec.Cap -and $sec.Cap -match '^Who Has It Now') { $sec.Cap = 'Who Has It Now ' + $mid + ' ' + @($Rows).Count + ' open actions' } }
      $sec.Blocks = $bl } }
  $script:SiteShown[$Card] = @(@($script:SiteShown[$Card]) + @($Titles) | Where-Object { $null -ne $_ })
}
<#
.SYNOPSIS
  Makes the waves card say what its grid shows: the head line, the chip over it and the "Wave 1" pill are counted from the same rows.
.DESCRIPTION
  R18 (the PFM, 26 Nov 26, R45 comment 4b: the head line said "two of three offices have answered" over a grid of 1 row). Called after the
  site rows are in the grid. Counts the rows with Status "Answered" and all rows, then sets the first chips block, the first head block
  and the "Wave 1: ..." pill row of the Action Status card. The FAKE sentences of the card are the 3-row design (2 of 3); the site rows
  win. Candidate B (keep 3 FAKE rows in the grid and mark them) was not built: it would mix FAKE rows into site data.
.PARAMETER Rows
  The answer rows of the grid (Status "Answered" or "Waiting").
#>
function Sync-WaveSummary($Rows) {
  $all = @($Rows); $t = $all.Count; $n = @($all | Where-Object { $_.Status -eq 'Answered' }).Count; $w = $t - $n
  if (-not $t) {   # no rows: the grid is the empty-state note; the head line says so (R46 build, worker question 2b)
    foreach ($col in @($Cards.waves.Cols)) { foreach ($sec in @($col)) { foreach ($bl in @($sec.Blocks)) {
          if ($bl.T -eq 'chips' -and $bl.Cap -match '^STEPS 9 AND 10') { $bl.Items = @(, @('late', 'No answers yet')) }
          elseif ($bl.T -eq 'head' -and -not $bl.Small) { $bl.Text = 'Wave 1: no office has answered yet.' }
          elseif ($bl.T -eq 'rows') { $bl.Rows = @($bl.Rows | ForEach-Object { if ([string]$_[0] -like 'Wave 1:*') { , @('Wave 1: offices the AO added', '0 of 0', 'soon') } else { , $_ } }) } } } }
    return }
  $hd = 'Wave 1: ' + $n + ' of ' + $t + $(if ($t -eq 1) { ' office has' } else { ' offices have' }) + ' answered.'
  $chip = $(if ($w) { @('late', ($w.ToString() + $(if ($w -eq 1) { ' office has' } else { ' offices have' }) + ' not answered')) } else { @('ok', 'Every office has answered') })
  $pill = @('Wave 1: offices the AO added', ($n.ToString() + ' of ' + $t), $(if ($w) { 'soon' } else { 'ok' }))
  foreach ($col in @($Cards.waves.Cols)) { foreach ($sec in @($col)) { foreach ($bl in @($sec.Blocks)) {
        if ($bl.T -eq 'chips' -and $bl.Cap -match '^STEPS 9 AND 10') { $bl.Items = @(, $chip) }
        elseif ($bl.T -eq 'head' -and -not $bl.Small) { $bl.Text = $hd }
        elseif ($bl.T -eq 'rows') { $bl.Rows = @($bl.Rows | ForEach-Object { if ([string]$_[0] -like 'Wave 1:*') { , $pill } else { , $_ } }) } } } }
}
<#
.SYNOPSIS
  Reads the PFM lists of the site and fills the cards (the window's source is then "site"); on any failure the cards
  keep their FAKE data (source "fake") and the reason is one SOURCE line.
.DESCRIPTION
  Steps: load PnP.PowerShell, sign in (web login, CAC), read each list of $script:SiteLists, then put the rows into the
  grids of Your Work, the "nothing needs you" card (rows On Track), All Actions and the endorsement answers. Adds the
  SOURCE, READ, WRITES=0 and MARKER lines. Writes nothing on the site.
.PARAMETER Site
  The site address (https://<host>/sites/<name>), or '' when none is set (then the cards keep their FAKE data).
#>
function Invoke-SiteRead([string]$Site) {
  $read = [ordered]@{}
  try {
    if (-not $Site) { throw 'no site address is set in RADE' }
    $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
    if (-not $mod.Count) { throw 'PnP.PowerShell is not on this computer' }
    Write-Host 'NOW Signing in to the site to read the PFM lists (if a sign-in window opens, sign in with your CAC)'
    $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
    $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
    foreach ($l in $script:SiteLists.Keys) {
      Write-Host ('NOW Reading the list ' + $l)
      $read[$l] = @(Get-PnPListItem -List $l -Fields $script:SiteLists[$l] -PageSize 500 -ErrorAction Stop) }
    try { $null = & { Disconnect-PnPOnline -ErrorAction SilentlyContinue } *>&1 } catch { $null = $_ }
  } catch {
    $why = Hide-Site ([string]$_.Exception.Message) $Site; if ($who) { $why = ConvertTo-Masked $why $who.Secret }
    $lines.Add('SOURCE fake (the site was not read: ' + $why.Substring(0, [Math]::Min(160, $why.Length)) + ')')
    foreach ($l in $read.Keys) { $lines.Add('READ ' + $l + ' rows=' + @($read[$l]).Count) }
    $lines.Add('WRITES=0'); return }
  $pub = ConvertTo-SitePubRow $read['PFM Publications']; $ans = @(ConvertTo-SiteAnswerRow $read['PFM Endorsements'])
  $ok = @($pub.Home | Where-Object { $_.Kind -eq 'ok' })
  Merge-SiteGrid 'home' 'Who has it now' $pub.Home 'PFM Publications' $pub.Titles
  Merge-SiteGrid 'empty' 'Who has it now' $ok 'PFM Publications' @($ok | ForEach-Object { ([string]$_.Publication -split '\|', 2)[1] })
  Merge-SiteGrid 'queue' 'All actions' $pub.Queue 'PFM Publications' $pub.Titles
  Merge-SiteGrid 'waves' 'Wave 1 answers' $ans 'PFM Endorsements' @($ans | ForEach-Object { $_.Office })
  Sync-WaveSummary $ans   # R18: the head line, chip and pill are counted from the rows the grid shows
  if ($Walk.Count) { $script:Walk = @(Get-RoundWalk) }   # R18: the look step names the head line, which the site rows may have changed (r19: this round's walk)
  $script:GridQueue = @($pub.Queue)   # the All Actions filter ($wn.Refilter) reads it
  foreach ($b in @($Cards.queue.Cols[0][0].Blocks)) { if ($b.T -eq 'grid') { $b.Count = 'Showing {0} of ' + @($pub.Queue).Count + ' actions, as the site lists them' } }
  $script:SiteSource = 'site'
  $lines.Add('SOURCE site (the PFM lists of your site, read-only; ' + $read.Count + ' lists read)')
  foreach ($l in $read.Keys) { $lines.Add('READ ' + $l + ' rows=' + @($read[$l]).Count) }
  $lines.Add('WRITES=0')
  $all = @($script:SiteShown.Values | ForEach-Object { @($_) }); $bad = @($all | Where-Object { -not (Test-FakeRow $_) })
  $lines.Add('MARKER rows checked=' + $all.Count + ' without a marker=' + $bad.Count + ' (a card with one gets no picture)')
}
