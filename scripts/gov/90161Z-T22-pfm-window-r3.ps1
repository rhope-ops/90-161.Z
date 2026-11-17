<#
.SYNOPSIS
  90-161.Z Task 22: the PFM window, test window r3 (round R29). Windows PowerShell 5.1 and Windows Forms only (no module).
.DESCRIPTION
  The PFM's window of the 13-step process with FAKE data (design "preview 2", PFM 17 Nov 26): Your Work, All Actions, Reviews Due,
  steps 8 to 13, a publication, Settings and the states. Nothing is read, saved or sent. The look comes from the RADE shared UI
  file (rade-ui block, generated from the pinned RADE commit). The window keeps the size and place you give it; below 1280 x 720
  (at 100 %) the main column scrolls. Esc goes back one card. Close it with its X.
  WHAT R3 CHANGES (R28 results): the layout self-check no longer stops on every card; the window is DPI aware like RADE (one
  line "SCALE dpi-aware=yes|no"); every grid fits its columns to its own width and wraps its cells; a check bar at the bottom shows
  12 checks one at a time with Pass and Fail (PFM 17 Nov 26), so no list has to be read or remembered; each layout defect is
  one line "FAIL LAYOUT ..." and "PASS layout" is one line when there is none (the runner counts these words).
  WHAT IT CHANGES: 90161Z-T22-window-r3.txt (state, size, scale, cards opened, layout self-check, check answers) and
  90161Z-T22-window-bounds.json (last size and place) in the T22 folder.
  Parameters: -Id, -NoPause (RADE). -PlanOnly prints the cards and the 12 checks as text and opens no window; -TestDir writes the files elsewhere.
  Last line: WINDOW done: cards=<opened> buttons=<selected> defects=<n> checks failed=<n>. Exit 1 when no window can open.
#>
param([string]$Id, [switch]$NoPause, [switch]$PlanOnly, [string]$TestDir)
$task = 'T22'
$Rev = 'r3'
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
# >>> rade-logo: generated from the pinned RADE logo by scripts/build_task_scripts.py (do not edit)
$RadeLogoPng = @(
  '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',
  'AG2SrHTUY27uAAAAAElFTkSuQmCC'
) -join ''
# <<< rade-logo
$PalHex=@{ ink='1B1F2A'; muted='5B6B7F'; surface='EEF1F5'; line='C9D2DC'; navy='0B2545'; onPrimaryMuted='DDE8F3'; accentFill='FFD520'
primary='00539F'; track='7F93A8'; redTint='F6D5DA'; amberTint='F8E8C4'; greenTint='D6EBDD'; white='FFFFFF' }
$mid=[string][char]0x00B7   # the dot between facts (kept out of the file text: a script file is ASCII)
$gt=[string][char]0x203A
$StepNames=@('Review due', 'Box told', 'AOs named', 'AOs told', 'Scope', 'Draft', 'Endorsers', 'PFM check', 'Answers', 'Waves', 'Signatures', 'Posted')
$HomeRows=(@(
'FAKE OI 33-101|Key Control|Review|8 PFM check|You|16 Nov|1 d|18 Nov|Your turn|turn|step8',
'FAKE OI 21-14|Vehicle Keys|Review|11 Signatures|You|13 Nov|2 d|20 Nov|Your turn|turn|step11',
'FAKE Instruction 10-201|Recall|Rewrite|10 Wave 1|FAKE Office 5|23 Oct|17 d|13 Nov|Late|late|waves',
'FAKE OI 31-3|Gate Hours|Review|10 Wave 2|FAKE Office 8|26 Oct|16 d|16 Nov|Late|late|waves',
'FAKE OI 90-1|Self-Inspection|Review|10 Wave 3, legal|FAKE Legal Office|29 Oct|13 d|19 Nov|Due soon|soon|waves',
'FAKE OI 36-2|Recognition|Change|10 Wave 1|2 offices|30 Oct|12 d|20 Nov|Due soon|soon|waves',
'FAKE OI 10-5|Recall Roster|Certify current|11 Signatures|FAKE Wing Staff CSS|12 Nov|3 d|19 Nov|On track|ok|pub',
'FAKE OI 13-4|Airfield Signs|Review|3 AOs named|FAKE Office 3 box|12 Nov|3 d|26 Nov|On track|ok|pub',
'FAKE OI 48-2|Hearing Tests|Review|9 Answers|FAKE AO 6|11 Nov|4 d|25 Nov|On track|ok|pub',
'FAKE OI 32-1|Work Orders|Review|5 Scope|FAKE AO 5|10 Nov|5 d|24 Nov|On track|ok|pub',
'FAKE OI 91-3|Ladder Safety|New|7 Endorsers|FAKE AO 7|9 Nov|6 d|1 Dec|On track|ok|pub',
'FAKE Form 12|Key Log|Form|6 Draft|FAKE AO 1|5 Nov|8 d|3 Dec|On track|ok|pub',
'FAKE OI 21-6|Tool Control|Review|6 Draft|FAKE AO 4|2 Nov|11 d|4 Dec|On track|ok|pub',
'FAKE OI 23-7|Supply Bins|Rewrite|6 Draft|FAKE AO 8|28 Oct|14 d|18 Dec|On track|ok|pub',
'FAKE OI 15-1|Weather Calls|Review|2 Box told|FAKE Office 9 box|16 Nov|1 d|30 Nov|On track|ok|pub'
) -join "`n")
$QueueRows=(@(
'FAKE OI 33-101|Key Control|Review|8 PFM check|1|You|Your turn|turn|step8|1',
'FAKE OI 21-14|Vehicle Keys|Review|11 Signatures|2|You|Due 20 Nov 26|soon|step11|1',
'FAKE Instruction 10-201|Recall|Rewrite|10 Waves, wave 1|9|Endorsers|No answer|late|waves|0',
'FAKE OI 31-3|Gate Hours|Review|9 Answers|4|Endorsers|On track|ok|waves|0',
'FAKE OI 36-2|Recognition|Change|6 Draft|12|AO|On track|ok|pub|0',
'FAKE OI 13-4|Airfield Signs|Review|3 AOs named|3|OPR box|Due 19 Nov 26|soon|pub|0',
'FAKE OI 90-1|Self-Inspection|Certify current|11 Signatures|6|Approver''s CSS|On track|ok|pub|0',
'FAKE Form 12|Key Log|Prescribed form|6 Draft|5|AO|On track|ok|pub|0',
'FAKE OI 10-5|Recall Roster|Certify current|11 Signatures|3|Wing Staff CSS|On track|ok|pub|0',
'FAKE OI 48-2|Hearing Tests|Review|9 Answers|4|FAKE AO 6|On track|ok|pub|0',
'FAKE OI 32-1|Work Orders|Review|5 Scope|5|FAKE AO 5|On track|ok|pub|0',
'FAKE OI 91-3|Ladder Safety|New|7 Endorsers|6|FAKE AO 7|On track|ok|pub|0'
) -join "`n")
function ConvertTo-HomeRow([string[]]$Lines) {
foreach ($l in $Lines) { if ($l.Trim()) { $f=$l.Split('|'); @{ Publication=($f[0] + '|' + $f[1]); Action=$f[2]; Step=$f[3]; With=$f[4]; Since=$f[5]; Age=$f[6]; Due=$f[7]; Status=$f[8]; Kind=$f[9]; Go=$f[10] } } }
}
function ConvertTo-QueueRow([string[]]$Lines) {
foreach ($l in $Lines) { if ($l.Trim()) { $f=$l.Split('|'); @{ Publication=($f[0] + '|' + $f[1]); Action=$f[2]; Step=$f[3]; Weekdays=$f[4]; With=$f[5]; Status=$f[6]; Kind=$f[7]; Go=$f[8]; Me=($f[9] -eq '1') } } }
}
$GridHome=@(ConvertTo-HomeRow ($HomeRows -split "`n"))
$GridQueue=@(ConvertTo-QueueRow ($QueueRows -split "`n"))
$ColsNarrow=@(@{ N='Publication'; W=0; K='pub' }, @{ N='Step'; W=128; K='plain' }, @{ N='With'; W=170; K='with' }, @{ N='Since'; W=64; K='since' }, @{ N='Due'; W=72; K='plain' }, @{ N='Status'; W=104; K='chip' })
$ColsWide=@(@{ N='Publication'; W=0; K='pub' }, @{ N='Action'; W=136; K='plain' }, @{ N='Step'; W=136; K='plain' }, @{ N='With'; W=184; K='with' }, @{ N='Since'; W=120; K='since' }, @{ N='Due'; W=72; K='plain' }, @{ N='Status'; W=104; K='chip' })
$ColsQueue=@(@{ N='Publication'; W=0; K='pub' }, @{ N='Action'; W=130; K='plain' }, @{ N='Step'; W=150; K='plain' }, @{ N='Weekdays'; W=86; K='plain'; H='Weekdays in step' }, @{ N='With'; W=140; K='with' }, @{ N='Status'; W=124; K='chip' })
function Get-SideStatus([string]$Title, [string]$Sub, [string]$Note, $Rows, $Buttons) {
$b=@(@{ T='head'; Text=$Title; Small=$true }, @{ T='p'; Text=$Sub; Style='note' })
if ($Note) { $b += @{ T='p'; Text=$Note; Style='box' } }
if ($Rows) { $b += @{ T='rows'; Rows=$Rows } }
if ($Buttons) { $b += @{ T='buttons'; Items=$Buttons } }
return @{ Cap='Action Status'; Pad=22; Blocks=$b }
}
$FullHistory=@(@{ Text='Full History'; Note='FAKE: the history of this action opens here. Nothing is read.' })
$OneOf="FAKE OI 33-101, Key Control"
$Checks=@(
@{ Key='card-open'; Text='Select a card in the list on the left. Pass if it opened.' },
@{ Key='first-button'; Text='On the card "Your Work", select the first button. Pass if it did something.' },
@{ Key='all-cards'; Text='Select each other card in the list on the left once. Pass if every card opened.' },
@{ Key='tab'; Text='Press Tab about 5 times. Pass if a clear outline moves from button to button.' },
@{ Key='shift-tab'; Text='Press Shift+Tab. Pass if the outline moves back.' },
@{ Key='enter'; Text='Press Enter. Pass if the button with the outline worked (all data is FAKE; nothing is sent).' },
@{ Key='narrator-on'; Text='Press Ctrl+Windows+Enter to start Narrator. Pass if Narrator started.' },
@{ Key='narrator-names'; Text='Press Tab. Pass if Narrator said the name of the control.' },
@{ Key='narrator-off'; Text='Press Ctrl+Windows+Enter to stop Narrator. Pass if it stopped.' },
@{ Key='contrast-on'; Text='Press Left Alt+Left Shift+Print Screen to turn on high contrast (if Windows asks, answer Yes). Pass if the colors changed.' },
@{ Key='contrast-read'; Text='Select 2 other cards. Pass if every text and button is readable.' },
@{ Key='contrast-off'; Text='Press Left Alt+Left Shift+Print Screen again. Pass if the window returned to its colors.' }
)
$Cards=[ordered]@{}
$Cards.home=@{ Rail='work'; Title='Your Work'; Sub="Tuesday, 17 Nov 26 $mid 2 items need you $mid 2 offices late"; Side=300
Cols=@(
@(@{ Cap='Needs You Today'; Top='primary'; Blocks=@(@{ T='list'; Rows=@(
@{ Chip=@('turn', 'Due 18 Nov 26'); Title='Review and start endorsement'; Sub="FAKE OI 33-101, Key Control $mid step 8 of 12"; Btn=@{ Text='Open'; Kind='primary'; Go='step8' } },
@{ Chip=@('turn', 'Due 20 Nov 26'); Title='Build the final copy, then send for signatures'; Sub="FAKE OI 21-14, Vehicle Keys $mid step 11 of 12"; Btn=@{ Text='Open'; Go='step11' } },
@{ Chip=@('late', '2 late'); Title='Chase 2 late offices'; Sub="Wave answers past due $mid last contact shown on the right"; Btn=@{ Text='Remind All Late'; Go='remindall' } }) }) },
@{ Cap="Who Has It Now $mid 15 open actions"; Grow=$true; Blocks=@(
@{ T='p'; Text="Since: when it reached that person $mid d: business days $mid dates in 2026"; Style='note' },
@{ T='grid'; Name='Who has it now'; Rows=$GridHome; Cols=$ColsNarrow; ColsWide=$ColsWide; Fill=$true }) }),
@(@{ Cap="Chase $mid late and due soon"; Pad=16; Blocks=@(
@{ T='p'; Text='Each reminder is logged as a contact: the good-faith record (DAFMAN 90-161, 5.4.3.1).'; Style='note' },
@{ T='list'; Narrow=$true; Rows=@(
@{ Title='FAKE Office 5'; Sub="FAKE Instruction 10-201 $mid Wave 1"; Detail="Due 13 Nov 26 (2 days late) $mid last contact: 14 Nov 26 $mid contacts: 1"; Btn=@{ Text='Remind'; Note='FAKE: a reminder to FAKE Office 5 is logged as a contact. Nothing was sent.' } },
@{ Title='FAKE Office 8'; Sub="FAKE OI 31-3 $mid Wave 2"; Detail="Due 16 Nov 26 (1 day late) $mid last contact: never $mid contacts: 0"; Btn=@{ Text='Remind'; Note='FAKE: a reminder to FAKE Office 8 is logged as a contact. Nothing was sent.' } },
@{ Title='FAKE Legal Office'; Sub="FAKE OI 90-1 $mid Wave 3, legal $mid cannot be ""Concur, No Response"""; Detail="Due 19 Nov 26 (due in 2 days) $mid last contact: never $mid contacts: 0"; Btn=@{ Text='Remind'; Note='FAKE: a reminder to the FAKE Legal Office is logged as a contact. Nothing was sent.' } },
@{ Title='FAKE Offices 2 and 4'; Sub="FAKE OI 36-2 $mid Wave 1"; Detail="Due 20 Nov 26 (due in 3 days) $mid last contact: never $mid contacts: 0"; Btn=@{ Text='Remind'; Note='FAKE: a reminder to FAKE Offices 2 and 4 is logged as a contact. Nothing was sent.' } }) }) },
@{ Cap="Selected $mid FAKE Instruction 10-201"; Pad=16; WideOnly=$true; Blocks=@(
@{ T='rows'; Rows=@(@('Wave 1 (3 offices)', '2 of 3 answered', 'soon'), @('Wave 2 (5 mandatory)', 'Waiting', 'neu'), @('Wave 3, legal', 'Waiting', 'neu'), @('Contacts with FAKE Office 5', "1 $mid 14 Nov 26 0900", '')) },
@{ T='buttons'; Items=@(@{ Text='Open the Action'; Go='waves' }, @{ Text='Change or Skip'; Go='step13' }) }) })) }
$Cards.empty=@{ Rail='work'; Title='Your Work'; Sub="Tuesday, 17 Nov 26 $mid 0 items need you"; Side=300; Up='settings'
Cols=@(
@(@{ Cap='Needs You Today'; Top='primary'; Blocks=@(
@{ T='chips'; Items=@(,@('ok', 'All clear')) },
@{ T='head'; Text='Nothing needs you today. The next due date is 19 Nov 26.'; Small=$true },
@{ T='buttons'; Items=@(@{ Text='Open All Actions'; Kind='primary'; Go='queue' }) }) },
@{ Cap="Who Has It Now $mid 9 open actions"; Grow=$true; Blocks=@(
@{ T='p'; Text="Since: when it reached that person $mid d: business days $mid dates in 2026"; Style='note' },
@{ T='grid'; Name='Who has it now'; Rows=@($GridHome | Where-Object { $_.Kind -eq 'ok' }); Cols=$ColsNarrow; ColsWide=$ColsWide; Fill=$true }) }),
@(@{ Cap="Chase $mid late and due soon"; Pad=16; Blocks=@(
@{ T='p'; Text='Each reminder is logged as a contact: the good-faith record (DAFMAN 90-161, 5.4.3.1).'; Style='note' },
@{ T='p'; Text='No office is late or due in the next 3 business days.' }) })) }
$Cards.queue=@{ Rail='queue'; Title='All Actions'; Sub="Twelve open actions $mid two need you $mid one office has not answered"; Up='home'
Cols=@(,@(@{ Cap='All Actions'; Grow=$true; Blocks=@(
@{ T='filter' },
@{ T='grid'; Name='All actions'; Rows=$GridQueue; Cols=$ColsQueue; Fill=$true; Count='Showing {0} of 12 actions, sorted by status, then due date' },
@{ T='buttons'; Items=@(@{ Text='Open the Action'; Kind='primary'; Go='@grid' }) }) }))
}
$Cards.reviews=@{ Rail='reviews'; Crumb="Step 1 of 12 $mid a publication is due for review (DAFMAN 90-161, 7.4.2, 7.4.4)"; Title='Reviews Due'; Sub='Three publications reach their review in the next 6 months, or must be reviewed now'; Up='home'
Cols=@(,@(@{ Cap='Reviews Due'; Blocks=@(
@{ T='list'; Rows=@(
@{ Title='FAKE OI 13-9, Fuel Handling'; Sub="E-mail goes to FAKE Office 3 box $mid review due 2 Feb 27 $mid 4-year review"; Btn=@{ Text='Start Review'; Kind='primary'; Note='FAKE: the review starts and one e-mail goes to the FAKE Office 3 box (step 2). Nothing was sent.' } },
@{ Title='FAKE OI 21-6, Tool Control'; Sub="E-mail goes to FAKE Office 7 box $mid review due 9 Mar 27 $mid 4-year review"; Btn=@{ Text='Start Review'; Note='FAKE: the review starts and one e-mail goes to the FAKE Office 7 box (step 2). Nothing was sent.' } },
@{ Title='FAKE OI 32-1, Work Orders'; Sub="E-mail goes to FAKE Office 2 box $mid review due now $mid higher headquarters changed its publication"; Btn=@{ Text='Start Review'; Note='FAKE: the review starts and one e-mail goes to the FAKE Office 2 box (step 2). Nothing was sent.' } }) },
@{ T='p'; Text='Start Review sends one e-mail to the OPR''s organization box (step 2). A person from the box names one or two action officers (step 3). The 6-month notice starts by itself; this list lets you start one early.'; Style='note' },
@{ T='ck'; Id='ck1'; Text='Ask for a full review, not only "certify current" (for FAKE OI 32-1: higher headquarters changed its publication)' }) }))
}
$Cards.step8=@{ Rail='work'; Crumb="Your Work $gt FAKE OI 33-101"; CrumbGo='home'; Up='home'; Side=360
Cols=@(
@(@{ Blocks=@(
@{ T='chips'; Items=@(@('turn', 'YOUR TURN'), @('soon', 'Due 18 Nov 26')); Cap="STEP 8 OF 12 $mid PFM AND PRIVACY MONITOR" },
@{ T='head'; Text='Is the draft of FAKE OI 33-101 ready for endorsement?' },
@{ T='steps'; N=8 },
@{ T='check'; Chip='Passed'; Text='The format check ran in draft mode, 17 Nov 26 0914.'; Link=@{ Text='See the 0 findings'; Note='FAKE: the format findings open here. There are none.' } },
@{ T='ck'; Id='ck1'; Text='I read the draft. It is ready for the offices.'; Link=@{ Text='Open the draft in Word for the web'; Note='FAKE: the draft opens in Word for the web. Nothing is opened.' } },
@{ T='ck'; Id='ck2'; Text='As the privacy monitor, I reviewed the draft for personal information (DAFMAN 90-161, 2.8.1).' },
@{ T='err'; Key='ck'; Text='Select both boxes first. The format check and the privacy review are your record.' },
@{ T='buttons'; Items=@(@{ Text='Start Endorsement'; Kind='primary'; Go='confirm'; Need='ck' }, @{ Text='Send Back to the AO'; Go='sendback' }, @{ Text='Change or Skip'; Go='step13' }) },
@{ T='p'; Text='Start Endorsement asks you to confirm first. Send Back asks for your reason; the AO gets it by e-mail.'; Style='note' }) }),
@((Get-SideStatus $OneOf "Review $mid step 8 of 12 $mid with you since 16 Nov 26" "Start sends wave 1 to three offices. Due 9 Dec 26: 15 business days, Thanksgiving not counted (DAFMAN 90-161, 5.2)." @(@('Wave 1: offices the AO added', '3 named', 'neu'), @('Wave 2: mandatory offices', '5 named', 'neu'), @('Wave 3: legal, last', '1 named', 'neu'), @('AO', 'FAKE AO 1', ''), @('Feedback from readers', '2 people, 28 Oct 26', '')) $FullHistory))) }
$Cards.confirm=@{ Rail='work'; Crumb="Your Work $gt FAKE OI 33-101 $gt Confirm"; CrumbGo='step8'; Up='step8'
Cols=@(,@(@{ Top='primary'; Blocks=@(
@{ T='chips'; Items=@(,@('soon', 'Confirm')); Cap="STEP 8 OF 12 $mid START ENDORSEMENT" },
@{ T='head'; Text='Start endorsement of FAKE OI 33-101?' },
@{ T='p'; Text='Three offices get an e-mail now. Due 9 Dec 26.'; Style='body' },
@{ T='rows'; Rows=@(@('Wave 1 offices', 'FAKE Office 1, FAKE Office 2, FAKE Office 3', ''), @('Due', '9 Dec 26 (15 business days)', ''), @('Waves 2 and 3', 'Open by themselves, in order', '')) },
@{ T='buttons'; Items=@(@{ Text='Start Endorsement'; Kind='primary'; Go='waves'; Note='FAKE: endorsement started. Nothing was sent.' }, @{ Text='Cancel'; Go='step8' }) }) }))
}
$Cards.sendback=@{ Rail='work'; Crumb="Your Work $gt FAKE OI 33-101 $gt Send back"; CrumbGo='home'; Modal=$true; Up='back'
Cols=@(,@(@{ Blocks=@(
@{ T='chips'; Items=@(,@('turn', 'YOUR TURN')); Cap='SEND BACK TO THE AO' },
@{ T='head'; Text='Send FAKE OI 33-101 back to the AO?' },
@{ T='p'; Text='The AO gets your reason by e-mail. The action goes back to the draft step.'; Style='body' },
@{ T='input'; Id='reason'; Label='Your reason (required)'; Multi=$true },
@{ T='err'; Key='reason'; Text='The reason box is empty. Type your reason, then select Send Back.' },
@{ T='buttons'; Items=@(@{ Text='Send Back'; Kind='primary'; Go='home'; Need='reason'; Note='FAKE: the action went back to the AO with your reason. Nothing was sent.' }, @{ Text='Cancel'; Go='back' }) }) }))
}
$Cards.waves=@{ Rail='work'; Crumb="All Actions $gt FAKE Instruction 10-201"; CrumbGo='queue'; Up='queue'; Side=360
Cols=@(
@(@{ Blocks=@(
@{ T='chips'; Items=@(,@('late', '1 office has not answered')); Cap="STEPS 9 AND 10 $mid ENDORSEMENT" },
@{ T='head'; Text='Wave 1: two of three offices have answered.' },
@{ T='steps'; N=10 },
@{ T='grid'; Name='Wave 1 answers'; Rows=@(
@{ Office='FAKE Office 1'; Answer='Concur'; Comments='0'; Signature='//SIGNED// 9 Nov 26'; Status='Answered'; Kind='ok'; Go='' },
@{ Office='FAKE Office 2'; Answer='Concur With Comment'; Comments='3'; Signature='//SIGNED// 13 Nov 26'; Status='Answered'; Kind='ok'; Go='' },
@{ Office='FAKE Office 5'; Answer='No answer yet'; Comments='-'; Signature='-'; Status='Due 25 Nov 26'; Kind='late'; Go='' })
Cols=@(@{ N='Office'; W=0; K='bold' }, @{ N='Answer'; W=150; K='plain' }, @{ N='Comments'; W=80; K='plain' }, @{ N='Signature'; W=150; K='plain' }, @{ N='Status'; W=120; K='chip' }) },
@{ T='buttons'; Items=@(@{ Text='Remind FAKE Office 5'; Kind='primary'; Note='FAKE: a reminder to FAKE Office 5 is logged as a contact. Nothing was sent.' }, @{ Text='Open the Comment Table'; Note='FAKE: the comment table opens here.' }, @{ Text='Change or Skip'; Go='step13' }) },
@{ T='p'; Text='After the due date the AO may record "Concur, No Response" with a reason; never for legal (DAFMAN 90-161, 5.4.3.2). You can skip an office at any time, with a reason (step 13).'; Style='note' }) }),
@((Get-SideStatus 'FAKE Instruction 10-201, Recall' "Rewrite $mid step 10 of 12 $mid wave 1 of 3" 'Wave 2 opens by itself when every wave 1 office has answered (PFM, 16 Nov 26).' @(@('Wave 1: offices the AO added', '2 of 3', 'soon'), @('Wave 2: mandatory offices', 'Waiting', 'neu'), @('Wave 3: legal, last', 'Waiting', 'neu'), @('Comments to decide (AO)', '3 open', ''), @('Open nonconcurs', '0', '')) $FullHistory))) }
$Cards.step11=@{ Rail='work'; Crumb="Your Work $gt FAKE OI 21-14"; CrumbGo='home'; Up='home'; Side=360
Cols=@(
@(@{ Blocks=@(
@{ T='chips'; Items=@(@('turn', 'YOUR TURN'), @('soon', 'Due 20 Nov 26')); Cap="STEP 11 OF 12 $mid SIGNATURES" },
@{ T='head'; Text='Build the final copy of FAKE OI 21-14, then send it for signatures.' },
@{ T='steps'; N=11 },
@{ T='rows'; Rows=@(
@('Final copy. Built from the format rules, with the seal and the page count.', 'Not built yet.', 'soon'),
@('Certifier signs the DAF Form 673 (DAFMAN 90-161, 5.6).', 'Waits for the final copy.', 'neu'),
@('Approver signs after the certifier (5.7).', 'Waits for the certifier.', 'neu')) },
@{ T='buttons'; Items=@(@{ Text='Build the Final Copy'; Kind='primary'; Note='FAKE: the final copy is built. Nothing was made.' }, @{ Text='Send Back to the AO'; Go='sendback' }, @{ Text='Change or Skip'; Go='step13' }) },
@{ T='p'; Text='When the final copy is built, the main button becomes "Send to the Certifier".'; Style='note' }) }),
@((Get-SideStatus 'FAKE OI 21-14, Vehicle Keys' "Review $mid step 11 of 12 $mid every endorser answered" 'Officials get no e-mail. The task goes to the CSS box of each official (PFM, 16 Nov 26).' @(@('Open nonconcurs (5.5)', '0', ''), @('Certifies', 'FAKE Group Commander', ''), @('Certifier''s CSS box', 'FAKE Group CSS', ''), @('Approves', 'FAKE Wing Commander', ''), @('Approver''s CSS box', 'FAKE Wing Staff CSS', '')) $FullHistory))) }
$Cards.step12=@{ Rail='work'; Crumb="Your Work $gt FAKE OI 21-14"; CrumbGo='home'; Up='home'
Cols=@(,@(@{ Top='primary'; Blocks=@(
@{ T='chips'; Items=@(,@('ok', 'PUBLISHED')); Cap='STEP 12 OF 12' },
@{ T='head'; Text='FAKE OI 21-14 is published.' },
@{ T='steps'; N=12 },
@{ T='rows'; Rows=@(@('Approver signed', '17 Nov 26 1342', ''), @('Posted on the wing site', '17 Nov 26 1343', ''), @('Publication list updated', '17 Nov 26 1343', ''), @('AO asked for related e-mail', 'Waiting', 'soon'), @('Next review due', '17 Nov 30', '')) },
@{ T='buttons'; Items=@(@{ Text='Open the Publication'; Kind='primary'; Go='pub' }, @{ Text='Back to Your Work'; Go='home' }) }) }))
}
$Cards.step13=@{ Rail='work'; Crumb="FAKE Instruction 10-201 $gt Change or skip"; CrumbGo='back'; Modal=$true; Up='back'; Side=360
Cols=@(
@(@{ Blocks=@(
@{ T='chips'; Items=@(,@('neu', 'ANY TIME')); Cap='STEP 13' },
@{ T='head'; Text='Change who does this step, or skip them.' },
@{ T='rows'; Rows=@(,@('Step', "Step 10 $mid wave 1 $mid FAKE Office 5", '')) },
@{ T='radio'; Id='radio'; Label='What do you want to do?'; Items=@('Give the step to another person or office', 'Skip FAKE Office 5 for this action') },
@{ T='input'; Id='reason'; Label='Your reason (required)'; Multi=$true },
@{ T='err'; Key='reason'; Text='The reason box is empty. Type your reason, then select Save Change.' },
@{ T='buttons'; Items=@(@{ Text='Save Change'; Kind='primary'; Go='back'; Need='reason'; Note='FAKE: the change is logged with your name, the date and your reason. Nothing was saved.' }, @{ Text='Cancel'; Go='back' }) },
@{ T='p'; Text='Legal cannot be marked "Concur, No Response" (DAFMAN 90-161, 5.4.3.2).'; Style='note' }) }),
@((Get-SideStatus 'FAKE Instruction 10-201, Recall' "Rewrite $mid step 10 of 12 $mid wave 1 of 3" 'Every change is logged with your name, the date and your reason. Others on the action see the change.' @(@('Changes on this action', '0', ''), @('FAKE Office 5', "Wave 1 $mid no answer", ''), @('Due', '25 Nov 26', '')) $FullHistory))) }
$Cards.pub=@{ Rail='pub'; Title='Publications'; Sub='Find a publication, read it, see its details'; Up='home'; Side=360
Cols=@(
@(@{ Blocks=@(
@{ T='input'; Id='find'; Label='Find a publication' },
@{ T='head'; Text=$OneOf; Small=$true },
@{ T='p'; Text='Summary'; Style='cap' },
@{ T='p'; Text='This FAKE instruction sets how offices issue and count vehicle keys. It names who keeps the key log and how often keys are counted.'; Style='body' },
@{ T='p'; Text='Written at the format pass (step 8); the PFM can edit it.'; Style='note' },
@{ T='buttons'; Items=@(@{ Text='Open the PDF'; Kind='primary'; Note='FAKE: the PDF opens here. Nothing is opened.' }, @{ Text='Copy the Text'; Note='FAKE: the text is copied. Nothing was copied.' }, @{ Text='Start a Change'; Note='FAKE: a change starts here. Nothing was started.' }) },
@{ T='p'; Text='Paragraphs'; Style='cap' },
@{ T='rows'; Rows=@(@('1. Purpose', 'page 1', ''), @('2. Key control', 'page 1', ''), @('3. Key count', 'page 2', '')) }) }),
@((Get-SideStatus $OneOf "In review $mid step 8 of 12" 'Open action: review, started 1 Oct 26.' @(@('OPR', 'FAKE Office 6', ''), @('Effective', '2 Feb 23', ''), @('Next review due', '2 Feb 27', ''), @('Prescribed forms', 'FAKE Form 12', ''), @('Applies to', 'Wing', '')) @(@{ Text='Open the Record'; Go='step8' })))) }
$Cards.settings=@{ Rail='settings'; Title='Settings'; Sub='Who runs the process, and how each screen looks when there is nothing to show'; Up='home'
Cols=@(,@(
@{ Cap='Settings'; Blocks=@(
@{ T='rows'; Rows=@(@('PFM', 'FAKE PFM', ''), @('Alternate PFM', 'FAKE Alternate', ''), @('Flows', 'Running', 'ok'), @('Test mode', 'Off', 'neu')) },
@{ T='buttons'; Items=@(@{ Text='Change Settings'; Kind='primary'; Note='FAKE: the settings open here. Nothing was changed.' }) }) },
@{ Cap='Look at the other states'; Blocks=@(
@{ T='p'; Text='Each button shows one card, with FAKE data.'; Style='note' },
@{ T='buttons'; Items=@(@{ Text='Nothing Needs You'; Go='empty' }, @{ Text='Loading'; Go='loading' }, @{ Text='Failed'; Go='failed' }, @{ Text='No Permission'; Go='noperm' }) }) })) }
$Cards.loading=@{ Rail='work'; Title='Loading'; Up='settings'
Cols=@(,@(@{ Blocks=@(
@{ T='chips'; Items=@(,@('neu', 'LOADING')) },
@{ T='head'; Text='Reading your site.' },
@{ T='p'; Text='Twelve lists. This takes about 10 seconds.'; Style='body' },
@{ T='progress'; Value=5; Max=12; Text='5 of 12 lists read' },
@{ T='buttons'; Items=@(@{ Text='Back to Your Work'; Kind='primary'; Go='home' }) }) }))
}
$Cards.failed=@{ Rail='work'; Title='Failed'; Up='settings'
Cols=@(,@(@{ Blocks=@(
@{ T='chips'; Items=@(,@('late', 'FAILED')) },
@{ T='head'; Text='The site did not answer.' },
@{ T='p'; Text='Your sign-in may have ended. Select Try Again; the window asks you to sign in.'; Style='body' },
@{ T='buttons'; Items=@(@{ Text='Try Again'; Kind='primary'; Go='loading' }, @{ Text='Copy Details'; Note='FAKE: the details are copied. Nothing was copied.' }) }) }))
}
$Cards.noperm=@{ Rail='work'; Title='No permission'; Up='settings'
Cols=@(,@(@{ Blocks=@(
@{ T='chips'; Items=@(,@('amber', 'NO PERMISSION')) },
@{ T='head'; Text='You cannot open the PFM lists.' },
@{ T='p'; Text='This window is for the PFM office. Ask the site owner to add you to the PFM Office group.'; Style='body' },
@{ T='buttons'; Items=@(@{ Text='Copy My Request'; Kind='primary'; Note='FAKE: your request is copied. Nothing was copied.' }) }) }))
}
$Cards.remindall=@{ Rail='work'; Crumb="Your Work $gt Remind all late offices"; CrumbGo='home'; Up='home'
Cols=@(,@(@{ Top='primary'; Blocks=@(
@{ T='chips'; Items=@(@('late', '2 late'), @('soon', 'Confirm')); Cap='CHASE' },
@{ T='head'; Text='Remind the 2 late offices now?' },
@{ T='p'; Text='Each office gets one e-mail now. Each contact is logged: the good-faith record (DAFMAN 90-161, 5.4.3.1).'; Style='body' },
@{ T='rows'; Rows=@(@('FAKE Office 5', "FAKE Instruction 10-201 $mid 2 days late", ''), @('FAKE Office 8', "FAKE OI 31-3 $mid 1 day late", '')) },
@{ T='buttons'; Items=@(@{ Text='Remind Both Offices'; Kind='primary'; Go='home'; Note='FAKE: 2 reminders are logged as contacts. Nothing was sent.' }, @{ Text='Cancel'; Go='home' }) }) }))
}
$RailItems=@(@{ Key='work'; Text='Your Work'; Go='home'; Badge='3' }, @{ Key='queue'; Text='All Actions'; Go='queue' }, @{ Key='pub'; Text='Publications'; Go='pub' },
@{ Key='reviews'; Text='Reviews Due'; Go='reviews' }, @{ Key='settings'; Text='Settings'; Go='settings' })
function ConvertTo-PlanText([string]$Text) {
return ($Text.Replace($mid, '|').Replace($gt, '>'))
}
function Get-CardPlan {
$out=@()
foreach ($k in $Cards.Keys) {
$c=$Cards[$k]
$head=$(if ($c.Title) { $c.Title } else { $c.Crumb })
$out += (ConvertTo-PlanText ('CARD ' + $k + ' | ' + $c.Rail + ' | ' + $head))
if ($c.Sub) { $out += (ConvertTo-PlanText ('  SUB ' + $c.Sub)) }
if ($c.Crumb -and $c.Title) { $out += (ConvertTo-PlanText ('  CRUMB ' + $c.Crumb)) }
foreach ($col in @($c.Cols)) {
foreach ($s in @($col)) {
$out += (ConvertTo-PlanText ('  SECTION ' + $(if ($s.Cap) { $s.Cap } else { '-' })))
foreach ($b in @($s.Blocks)) {
switch ($b.T) {
'chips' { $out += (ConvertTo-PlanText ('    CHIPS ' + (@($b.Items | ForEach-Object { $_[1] }) -join ', ') + $(if ($b.Cap) { ' | ' + $b.Cap } else { '' }))) }
'head' { $out += (ConvertTo-PlanText ('    HEAD ' + $b.Text)) }
'p' { $out += (ConvertTo-PlanText ('    P ' + $b.Text)) }
'steps' { $out += ('    STEPS ' + $b.N + ' of 12 (12 dots) | ' + $StepNames[$b.N - 1]) }
'check' { $out += (ConvertTo-PlanText ('    CHECK ' + $b.Text)); if ($b.Link) { $out += (ConvertTo-PlanText ('    LINK ' + $b.Link.Text + $(if ($b.Link.Go) { ' -> ' + $b.Link.Go } else { ' -> @note' }))) } }
'ck' { $out += (ConvertTo-PlanText ('    BOX ' + $b.Text)); if ($b.Link) { $out += (ConvertTo-PlanText ('    LINK ' + $b.Link.Text + ' -> @note')) } }
'rows' { foreach ($r in @($b.Rows)) { $out += (ConvertTo-PlanText ('    ROW ' + $r[0] + ': ' + $r[1])) } }
'list' { foreach ($r in @($b.Rows)) { $out += (ConvertTo-PlanText ('    ITEM ' + $r.Title + ' | ' + $r.Sub)); if ($r.Btn) { $out += (ConvertTo-PlanText ('    BUTTON ' + $r.Btn.Text + $(if ($r.Btn.Kind -eq 'primary') { ' (blue)' } else { '' }) + ' -> ' + $(if ($r.Btn.Go) { $r.Btn.Go } else { '@note' }))) } } }
'grid' { $out += ('    GRID ' + $b.Name + ': ' + @($b.Cols).Count + ' columns, ' + @($b.Rows).Count + ' rows'); foreach ($r in @($b.Rows)) { if ($r.Go) { $out += (ConvertTo-PlanText ('    CHOICE ' + $(if ($r.Publication) { $r.Publication } else { $r.Office }) + ' -> ' + $r.Go)) } } }
'filter' { $out += '    FILTER search and show list' }
'input' { $out += (ConvertTo-PlanText ('    INPUT ' + $b.Label + ' (' + $b.Id + ')')) }
'radio' { $out += (ConvertTo-PlanText ('    CHOICES ' + $b.Label + ': ' + (@($b.Items) -join ' / '))) }
'err' { $out += (ConvertTo-PlanText ('    ERROR ' + $b.Text)) }
'progress' { $out += (ConvertTo-PlanText ('    PROGRESS ' + $b.Text)) }
'buttons' { foreach ($x in @($b.Items)) { $out += (ConvertTo-PlanText ('    BUTTON ' + $x.Text + $(if ($x.Kind -eq 'primary') { ' (blue)' } else { '' }) + ' -> ' + $(if ($x.Go) { $x.Go } else { '@note' }) + $(if ($x.Need) { ' [needs ' + $x.Need + ']' } else { '' }))) } }
}
}
}
}
}
foreach ($r in $RailItems) { $out += ('RAIL ' + $r.Text + ' -> ' + $r.Go) }
return $out
}
$PfmCs=(@(
'using System;',
'using System.Drawing;',
'using System.Drawing.Drawing2D;',
'using System.Windows.Forms;',
'namespace Pfm {',
'public static class Gfx {',
'public static GraphicsPath Round(RectangleF r, float rad) {',
'GraphicsPath p = new GraphicsPath();',
'if (rad <= 0.5f) { p.AddRectangle(r); return p; }',
'float d = rad * 2f;',
'p.AddArc(r.X, r.Y, d, d, 180, 90);',
'p.AddArc(r.Right - d, r.Y, d, d, 270, 90);',
'p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);',
'p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);',
'p.CloseFigure();',
'return p;',
'}',
'public static void RoundRegion(Control c, int rad) {',
'if (c.Width < 4 || c.Height < 4) { return; }',
'using (GraphicsPath p = Round(new RectangleF(0, 0, c.Width, c.Height), rad)) {',
'Region old = c.Region;',
'c.Region = new Region(p);',
'if (old != null) { old.Dispose(); }',
'}',
'}',
'}',
'public class Chip : Control {',
'public Color Fill = Color.White;',
'public Chip() {',
'SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);',
'TabStop = false;',
'}',
'protected override void OnPaint(PaintEventArgs e) {',
'Graphics g = e.Graphics;',
'g.Clear(BackColor);',
'g.SmoothingMode = SmoothingMode.AntiAlias;',
'using (GraphicsPath p = Gfx.Round(new RectangleF(0, 0, Width - 1, Height - 1), Height / 2f)) {',
'using (SolidBrush b = new SolidBrush(Fill)) { g.FillPath(b, p); }',
'}',
'TextRenderer.DrawText(g, Text, Font, ClientRectangle, ForeColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);',
'}',
'}',
'public class Card : FlowLayoutPanel {',
'public Color Line = Color.Gray;',
'public Color TopFill = Color.Transparent;',
'public Color Outer = Color.White;',
'public int TopH = 0;',
'public int Radius = 6;',
'public Card() { DoubleBuffered = true; ResizeRedraw = true; }',
'protected override void OnPaint(PaintEventArgs e) {',
'base.OnPaint(e);',
'Graphics g = e.Graphics;',
'g.SmoothingMode = SmoothingMode.AntiAlias;',
'using (GraphicsPath p = Gfx.Round(new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f), Radius)) {',
'using (Region r = new Region(new Rectangle(0, 0, Width, Height))) {',
'r.Exclude(p);',
'using (SolidBrush b = new SolidBrush(Outer)) { g.FillRegion(b, r); }',
'}',
'if (TopH > 0) {',
'GraphicsState st = g.Save();',
'g.SetClip(p);',
'using (SolidBrush b = new SolidBrush(TopFill)) { g.FillRectangle(b, 0, 0, Width, TopH); }',
'g.Restore(st);',
'}',
'using (Pen pen = new Pen(Line, 1f)) { g.DrawPath(pen, p); }',
'}',
'}',
'}',
'public class Steps : Control {',
'public string[] Labels = new string[0];',
'public int Current = 1;',
'public int Dot = 26;',
'public Color DoneFill = Color.Blue, DoneText = Color.White, NowFill = Color.Yellow, NowLine = Color.Navy, NowText = Color.Black;',
'public Color TodoFill = Color.White, TodoLine = Color.Gray, TodoText = Color.Black, ConnDone = Color.Blue, ConnTodo = Color.Gray;',
'public Color LabelDone = Color.Black, LabelNow = Color.Navy, LabelTodo = Color.Gray;',
'public Font[] Fonts = new Font[0];',
'public Font[] FontsB = new Font[0];',
'public Steps() {',
'SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);',
'TabStop = false;',
'}',
'protected override void OnPaint(PaintEventArgs e) {',
'Graphics g = e.Graphics;',
'g.Clear(BackColor);',
'int n = Labels.Length;',
'if (n == 0 || Fonts.Length == 0) { return; }',
'g.SmoothingMode = SmoothingMode.AntiAlias;',
'float cell = (float)Width / n;',
'int fi = Fonts.Length - 1;',
'for (int k = 0; k < Fonts.Length; k++) {',
'bool ok = true;',
'for (int i = 0; i < n && ok; i++) {',
'Font f = (i + 1 == Current) ? FontsB[k] : Fonts[k];',
'foreach (string w in Labels[i].Split('' '')) {',
'if (TextRenderer.MeasureText(w, f, new Size(100000, 0), TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix).Width > cell - 4) { ok = false; break; }',
'}',
'}',
'if (ok) { fi = k; break; }',
'}',
'float top = 2f;',
'float cy = top + Dot / 2f;',
'for (int i = 1; i < n; i++) {',
'Color c = (i + 1 <= Current) ? ConnDone : ConnTodo;',
'using (Pen p = new Pen(c, 3f)) { g.DrawLine(p, (i - 0.5f) * cell, cy, (i + 0.5f) * cell, cy); }',
'}',
'for (int i = 0; i < n; i++) {',
'int num = i + 1;',
'float cx = (i + 0.5f) * cell;',
'RectangleF rc = new RectangleF(cx - Dot / 2f, top, Dot, Dot);',
'Color fill; Color line; Color tx; float lw;',
'if (num < Current) { fill = DoneFill; line = DoneFill; tx = DoneText; lw = 2f; }',
'else if (num == Current) { fill = NowFill; line = NowLine; tx = NowText; lw = 3f; }',
'else { fill = TodoFill; line = TodoLine; tx = TodoText; lw = 2f; }',
'using (SolidBrush b = new SolidBrush(fill)) { g.FillEllipse(b, rc); }',
'RectangleF ri = rc;',
'ri.Inflate(-lw / 2f, -lw / 2f);',
'using (Pen p = new Pen(line, lw)) { g.DrawEllipse(p, ri); }',
'TextRenderer.DrawText(g, num.ToString(), FontsB[fi], Rectangle.Round(rc), tx, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix);',
'Rectangle lr = new Rectangle((int)(i * cell) + 1, (int)(top + Dot + 4), (int)cell - 2, Height - (int)(top + Dot + 4));',
'Color lc = (num < Current) ? LabelDone : ((num == Current) ? LabelNow : LabelTodo);',
'TextRenderer.DrawText(g, Labels[i], (num == Current) ? FontsB[fi] : Fonts[fi], lr, lc, TextFormatFlags.HorizontalCenter | TextFormatFlags.Top | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix);',
'}',
'}',
'}',
'public class RailItem : Button {',
'public bool On = false;',
'public string Badge = "";',
'public Color Back = Color.Navy, OnBack = Color.White, Fore = Color.White, OnFore = Color.Navy, HotLine = Color.White, FocusLine = Color.Yellow, FocusOn = Color.Navy, BadgeFill = Color.Yellow, BadgeText = Color.Black;',
'public Font BoldFont = null;',
'private bool hot = false;',
'public RailItem() {',
'SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);',
'FlatStyle = FlatStyle.Flat;',
'TabStop = true;',
'}',
'protected override void OnMouseEnter(EventArgs e) { hot = true; Invalidate(); base.OnMouseEnter(e); }',
'protected override void OnMouseLeave(EventArgs e) { hot = false; Invalidate(); base.OnMouseLeave(e); }',
'protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }',
'protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }',
'protected override void OnPaint(PaintEventArgs e) {',
'Graphics g = e.Graphics;',
'g.Clear(Back);',
'g.SmoothingMode = SmoothingMode.AntiAlias;',
'RectangleF rc = new RectangleF(0.5f, 0.5f, Width - 2f, Height - 2f);',
'using (GraphicsPath p = Gfx.Round(rc, 4f)) {',
'if (On) { using (SolidBrush b = new SolidBrush(OnBack)) { g.FillPath(b, p); } }',
'else if (hot) { using (Pen pen = new Pen(HotLine, 1f)) { g.DrawPath(pen, p); } }',
'}',
'if (Focused) {',
'RectangleF f = rc;',
'f.Inflate(-2f, -2f);',
'using (GraphicsPath q = Gfx.Round(f, 3f)) { using (Pen pen = new Pen(On ? FocusOn : FocusLine, 2f)) { g.DrawPath(pen, q); } }',
'}',
'int right = Width - 14;',
'if (Badge.Length > 0) {',
'int d = Height / 2;',
'Rectangle br = new Rectangle(Width - 14 - d, (Height - d) / 2, d, d);',
'using (SolidBrush b = new SolidBrush(BadgeFill)) { g.FillEllipse(b, br); }',
'TextRenderer.DrawText(g, Badge, (BoldFont != null) ? BoldFont : Font, br, BadgeText, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix);',
'right = br.Left - 6;',
'}',
'Rectangle tr = new Rectangle(14, 0, Math.Max(1, right - 14), Height);',
'TextRenderer.DrawText(g, Text, (On && BoldFont != null) ? BoldFont : Font, tr, On ? OnFore : Fore, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis);',
'}',
'}',
'}'
) -join "`r`n")
$NativeCs=(@(
'using System;',
'using System.Runtime.InteropServices;',
'namespace Rade {',
'public static class Native {',
'[DllImport("user32.dll")] public static extern bool HideCaret(IntPtr hWnd);',
'}',
'}'
) -join "`r`n")
$lines=New-Object System.Collections.Generic.List[string]
$lines.Add('TASK T22 PFM window preview ' + $Rev + ', ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$code=0
$cf=0; $opened=@{}; $presses=0; $defects=New-Object System.Collections.Generic.List[string]
$dir=''
$who=$null
try {
$ErrorActionPreference='Stop'
if ($PlanOnly) { Get-CardPlan | ForEach-Object { Write-Host $_ }; for ($i=0; $i -lt $Checks.Count; $i++) { Write-Host ('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ': ' + $Checks[$i].Text) }; Write-Host ('PLAN cards=' + $Cards.Count); return }
$who=Get-TaskId $Id
if ($TestDir) { $dir=$TestDir } else { $dir=Get-TaskDir $who.Id $task 'Task 22' -Create }
# The process is DPI aware like RADE, before any form exists (R28: this window ran unscaled while RADE ran at 150 %).
$dpiAware='no'
if ($env:OS -eq 'Windows_NT') {
try {
Add-Type -Namespace T22 -Name Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -ErrorAction Stop
try { if ([T22.Native]::SetProcessDPIAware()) { $dpiAware='yes' } } catch { $null=$_ }
} catch { $null=$_ } }
$lines.Add('SCALE dpi-aware=' + $dpiAware)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
if (-not ('Pfm.Card' -as [type])) { Add-Type -ReferencedAssemblies 'System.Windows.Forms', 'System.Drawing' -TypeDefinition $PfmCs }
if (-not ('Rade.Native' -as [type])) { try { Add-Type -TypeDefinition $NativeCs } catch { $null=$_ } }
$script:native=[bool]('Rade.Native' -as [type])   # the shared UI file hides the caret of a card text box through it
$started=Get-Date
$pc=@{}
foreach ($k in $PalHex.Keys) { $pc[$k]=[Drawing.ColorTranslator]::FromHtml('#' + $PalHex[$k]) }
$ui=@{}
$form=New-Object System.Windows.Forms.Form
$form.Text='90-161.Z - Publications and Forms Management - preview ' + $Rev + ' (FAKE data)'
$form.AutoScaleDimensions=New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode='Dpi'
$form.ClientSize=[Drawing.Size]::new(1280, 720)
$form.StartPosition='CenterScreen'; $form.KeyPreview=$true; $form.ShowInTaskbar=$true
$form.Opacity=0   # shown when the cards are built, at the size and place the PFM gave it
$ui.Form=$form; $ui.Dpi=96.0; $ui.FontK=1.0; $ui.FontDpi=96.0
$apps=@(@{ Mode='test' }); Set-Variable -Name dot -Value ''; Set-Variable -Name round -Value ''
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
# Colors: one meaning each. Navy = text and focus; Air Force blue = the action and progress; yellow = RADE waits for you;
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
$ui.F = @{ Small = $ui.Form.Font; SmallB = (& $ui.Font 'Segoe UI Semibold' 10 $null); Body = (& $ui.Font 'Segoe UI' 12 $null); Sent = (& $ui.Font 'Segoe UI Semibold' 22 $null)
  Link = (& $ui.Font 'Segoe UI Semibold' 10 ([Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Underline'))); Word = (& $ui.Font 'Segoe UI' 15 $ui.Bold); Mono = (& $ui.Font 'Consolas' 9 $null) }
# Sizes, in pixels at 100 % (docs/window-design.md "Sizes"): one place for the button sizes and the gaps between the
# parts of a card. Action = a card's buttons; compact = a button beside a box and the Record's "Back"; a link is 28 high.
# Gaps are on the scale 4, 8, 12, 16, 24. A button or link has a 4 px margin (room for the 2 px focus ring), so two
# of them are 8 px apart.
$ui.Z = @{ ActionW = 132; ActionH = 40; CompactW = 110; CompactH = 30; LinkH = 28; M = 4; G1 = 4; G2 = 8; G3 = 12; G4 = 16; G6 = 24 }
$ui.Pad = { param([int]$L, [int]$T, [int]$R, [int]$B) New-Object System.Windows.Forms.Padding($L, $T, $R, $B) }
$ui.Label = { param($Font, $Color, [int]$Top) $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $true; $l.Font = $Font; $l.ForeColor = $Color; $l.BackColor = $ui.C.White; $l.UseMnemonic = $false; $l.Margin = (& $ui.Pad 0 $Top 0 0); $l.Visible = $false; $l }
# ---- Card text that can be selected (R28, the Administrator, 2026-11-17)
# The headline, the lines, the help, the notes and the questions of a card are read-only, borderless text boxes: the same look as
# a label, but the text can be highlighted and copied (Ctrl+C, or right-click: Copy, Select All). No tab stop, no caret shown.
# A text box does not size itself to its text, so $ui.Reflow gives it the size the text needs (measured as the edit control wraps:
# WordBreak, TextBoxControl) whenever its text, its font or its wrap width changes. The wrap width is $ui.Wrap[box] (set with
# $ui.SetWrap): a text box's own MaximumSize would cut the few extra pixels the edit control keeps at its edges.
$ui.Wrap = @{}
$ui.GetWrap = { param($C) if ($C -is [System.Windows.Forms.TextBox]) { return [int]$ui.Wrap[$C] }; return [int]$C.MaximumSize.Width }
$ui.SetWrap = { param($C, [int]$W) if ($C -is [System.Windows.Forms.TextBox]) { $ui.Wrap[$C] = $W; & $ui.Reflow $C } else { $C.MaximumSize = New-Object System.Drawing.Size($W, 0) } }
$ui.Reflow = { param($T)
  try { $txt = [string]$T.Text; if (-not $txt) { return }
    $sl = & $ui.Sc 4; $w = [int]$ui.Wrap[$T]; $one = & $ui.Meas $txt $T.Font 100000; $sz = $one
    if ($w -gt 0 -and $one.Width -gt $w) { $sz = & $ui.Meas $txt $T.Font $w; $bw = $w + $sl } else { $bw = $one.Width + 2 * $sl }
    $ns = New-Object System.Drawing.Size($bw, ($sz.Height + (& $ui.Sc 2))); if ($T.Width -ne $ns.Width -or $T.Height -ne $ns.Height) { $T.Size = $ns } } catch { $null = $_ } }
$ui.Menu = New-Object System.Windows.Forms.ContextMenuStrip; $ui.Menu.AccessibleName = 'Text menu'
$ui.MenuCopy = $ui.Menu.Items.Add('Copy'); $ui.MenuAll = $ui.Menu.Items.Add('Select All')
$ui.CopyText = { param($C) try { if ($C -is [System.Windows.Forms.TextBox] -and $C.SelectionLength -gt 0) { $C.Copy(); return $true } } catch { $null = $_ }; return $false }
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
# ---- Long words and one-line texts
# A word wider than the line (no space in it) is cut into pieces that fit, one per line: it wraps by character and is
# never clipped (R7 review). Only what the window shows changes; the report keeps the text.
# The width a label needs to show a text in one line: asked of a label that is never shown, with the same font and flags
# as the window's labels (R24 job: TextRenderer's default flags gave 3 to 9 px more than a label uses).
$ui.Probe = New-Object System.Windows.Forms.Label; $ui.Probe.AutoSize = $true; $ui.Probe.UseMnemonic = $false; $ui.Trash = @(@($ui.Trash) | Where-Object { $_ }) + @($ui.Probe)   # disposed when the window has closed
$ui.WordW = { param([string]$T, $F) try { $ui.Probe.Font = $F; $ui.Probe.Text = $T; return [int]$ui.Probe.PreferredSize.Width } catch { return [int][System.Windows.Forms.TextRenderer]::MeasureText($T, $F).Width } }
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
# The self-check's rule for it: a word of a text that wraps is never wider than the line the text may take (a label's
# MaximumSize, a card text box's $ui.GetWrap; else the word is cut). Not the label's own width: a wrapping label is as wide
# as its widest line by its own measure, about 1 % narrower than the probe's, so a cut piece that is the widest line would
# always seem too wide (R28 job: 591/588, 597/591, 592/588).
$ui.WordBad = { param([string]$Card, [string]$Name, [string]$Text, $F, [int]$W)
  foreach ($wd in ($Text -split '\s+')) { if ($wd) { $ww = & $ui.WordW $wd $F; if ($ww -gt $W + 1) { return ('LAYOUT ' + $Card + ' ' + $Name + ' text: the word "' + $(if ($wd.Length -gt 20) { $wd.Substring(0, 20) + '...' } else { $wd }) + '" needs ' + $ww + ', the line is ' + $W) } } }
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
  foreach ($k in 'B', 'P') { for ($i = 0; $i -lt @($ui[$k]).Count; $i++) { if ([object]::ReferenceEquals($ui[$k][$i], $C)) { return ($k + $i) } } }
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
          $nd = & $ui.TextNeed $c; if ($c.Text -and ($nd.Height -gt $c.ClientSize.Height + 1 -or $nd.Width -gt $c.ClientSize.Width + 1)) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text: needs ' + $nd.Width + 'x' + $nd.Height + ' has ' + $c.ClientSize.Width + 'x' + $c.ClientSize.Height) } }
        if ($c -is [System.Windows.Forms.CheckBox] -and $c.Text -and -not $c.AutoEllipsis) {   # a one-line check box whose text alone is wider than it is cut (the Record's step boxes before R24 fix round 3)
          $tw = [System.Windows.Forms.TextRenderer]::MeasureText([string]$c.Text, $c.Font).Width; if ($tw -gt $c.ClientSize.Width + 1) { $ui.LayBad.Add('LAYOUT ' + $card + ' ' + (& $ui.NameOf $c) + ' text cut: needs ' + $tw + ' has ' + $c.ClientSize.Width) } }
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
    foreach ($l in @(& $ui.Measure $card)) { $ui.LayBad.Add([string]$l) }
  } catch { $ui.LayBad.Add('LAYOUT ' + $card + ' the self-check stopped: ' + (ConvertTo-Masked ([string]$_.Exception.Message))) } }
# <<< rade-ui
$form.BackColor=$pc.surface
$ui.Trash=@(@($ui.Trash) | Where-Object { $_ }) + @($ui.Menu)
$ui.Clock=[System.Diagnostics.Stopwatch]::StartNew(); $ui.CardAt=0; $ui.GuardMs=400; $ui.Busy=$false; $ui.Always=@{}; $ui.Boxes=@()
$ui.B=@(); $ui.P=@()   # the generated NameOf walks these two lists; this window has none (R28: every self-check stopped on a null list)
$ui.View=''; $ui.Scrolls=$false; $ui.Scroll=$null; $ui.RecOn=$false; $ui.Picked=$false; $ui.Sent=$null; $ui.Kick=$null
$ui.Measure={ param($Card) $null=$Card; return @() }
$wn=@{}
$wn.Sc={ param([double]$Px) & $ui.Sc $Px }
$wn.Cur=''; $wn.Prev='home'; $wn.Notice=''; $wn.Err=''; $wn.Field=@{}; $wn.Gridsel=$null; $wn.Wide=$false
$wn.Txt={ param($Parent, [string]$Text, $Font, $Color, [int]$Top, [int]$W, [string]$Name, $Back)
$t=& $ui.Text $Font $Color (& $wn.Sc $Top) $Name
if ($Back) { $t.BackColor=$Back }
$t.Text=$Text; & $ui.SetWrap $t $W; $t.Visible=$true; [void]$Parent.Controls.Add($t); return $t }
$wn.Round={ param($C, [int]$Rad) try { [Pfm.Gfx]::RoundRegion($C, $Rad) } catch { $null=$_ }; return $null }
$wn.Button={ param($B, [string]$Kind)
$x=& $ui.Btn $Kind
$x.Text=[string]$B.Text; & $ui.Style $x $(if ($B.Kind -eq 'primary') { 'primary' } else { '' }); $x.AccessibleName=[string]$B.Text; $x.Tag=$B
$x.Add_SizeChanged({ & $wn.Round $this 4 })
$x.Add_Click({ & $wn.Press $this.Tag })
return $x }
$wn.Link={ param($B)
$x=& $ui.LinkBtn ([string]$B.Text); $x.AccessibleName=[string]$B.Text; $x.Tag=$B
$x.Add_Click({ & $wn.Press $this.Tag })
return $x }
$wn.Chip={ param($Kind, [string]$Text, $Back)
$fills=@{ turn=$pc.accentFill; late=$pc.redTint; soon=$pc.amberTint; ok=$pc.greenTint; amber=$pc.amberTint; neu=$pc.surface }
$c=New-Object Pfm.Chip; $c.Text=$Text; $c.Font=$ui.F.SmallB; $c.ForeColor=$pc.ink; $c.Fill=$fills[$Kind]; $c.BackColor=$Back; $c.AccessibleName=$Text
$w=[Windows.Forms.TextRenderer]::MeasureText($Text, $c.Font).Width + (& $wn.Sc 22)
$c.Size=[Drawing.Size]::new($w, (& $wn.Sc 26)); $c.Margin=& $ui.Pad 0 0 (& $wn.Sc 8) 0
return $c }
$wn.Panel={ param([int]$W, [int]$Top)
$p=New-Object System.Windows.Forms.Panel; $p.BackColor=$ui.C.White; $p.Size=[Drawing.Size]::new($W, 1); $p.Margin=& $ui.Pad 0 (& $wn.Sc $Top) 0 0
& $ui.Ring $p; return $p }
$wn.Fit={ param($P, [int]$Pad)
$h=0; foreach ($c in $P.Controls) { if ($c.Bottom -gt $h) { $h=$c.Bottom } }
$P.Height=$h + (& $wn.Sc $Pad) }
$wn.Rule={ param($Parent, [int]$W, [int]$Top)
$r=New-Object System.Windows.Forms.Panel; $r.BackColor=$pc.line; $r.Size=[Drawing.Size]::new($W, 1); $r.Margin=& $ui.Pad 0 (& $wn.Sc $Top) 0 0; $r.AccessibleName='Separator line'
[void]$Parent.Controls.Add($r) }
$wn.Flow={ param($Parent, $Back)
$f=& $ui.Flow 0; $f.BackColor=$Back; $f.Visible=$true; & $ui.Ring $f; [void]$Parent.Controls.Add($f); return $f }
$wn.Card={ param([int]$W, $Cap, $Top, [int]$PadX, $Back)
$c=New-Object Pfm.Card; $c.FlowDirection='TopDown'; $c.WrapContents=$false; $c.AutoSize=$true; $c.AutoSizeMode='GrowAndShrink'
$c.BackColor=$ui.C.White; $c.Outer=$Back; $c.Line=$pc.line; $c.MinimumSize=[Drawing.Size]::new($W, 0)
$tp=$(if ($Top) { 4 } else { 0 }); if ($Top) { $c.TopFill=$pc.primary; $c.TopH=(& $wn.Sc 4) }
$c.Padding=& $ui.Pad (& $wn.Sc $PadX) (& $wn.Sc (18 + $tp)) (& $wn.Sc $PadX) (& $wn.Sc 18); $c.Margin=& $ui.Pad 0 0 0 (& $wn.Sc 14)
& $ui.Ring $c
if ($Cap) { [void](& $wn.Txt $c (([string]$Cap).ToUpperInvariant()) $ui.F.SmallB $ui.C.Gray 0 ($W - 2 * (& $wn.Sc $PadX)) 'Section' $null) }
return $c }
$wn.Block={ param($Parent, $b, [int]$W, $Ctx)
switch ($b.T) {
'chips' {
$f=& $wn.Flow $Parent $ui.C.White; $f.Margin=& $ui.Pad 0 0 0 (& $wn.Sc 10)
foreach ($it in @($b.Items)) { [void]$f.Controls.Add((& $wn.Chip $it[0] $it[1] $ui.C.White)) }
if ($b.Cap) { [void](& $wn.Txt $f (([string]$b.Cap).ToUpperInvariant()) $ui.F.SmallB $ui.C.Gray 4 ([math]::Max((& $wn.Sc 200), $W - (& $wn.Sc 260))) 'Step line' $null) } }
'head' {
$font=$(if ($b.Small) { $ui.F.Body } else { $ui.F.Sent })
[void](& $wn.Txt $Parent $b.Text $font $ui.C.Navy 4 $W 'Heading' $null) }
'p' {
$st=[string]$b.Style
if ($st -eq 'box') {
$bx=& $wn.Panel $W 12; $bx.BackColor=$pc.surface
$t=& $wn.Txt $bx $b.Text $ui.F.Small $ui.C.Ink 0 ($W - 2 * (& $wn.Sc 12)) 'Note' $pc.surface; $t.Location=[Drawing.Point]::new((& $wn.Sc 12), (& $wn.Sc 10))
& $wn.Fit $bx 10; [void]$Parent.Controls.Add($bx) }
elseif ($st -eq 'note') { [void](& $wn.Txt $Parent $b.Text $ui.F.Small $ui.C.Gray 8 $W 'Note' $null) }
elseif ($st -eq 'cap') { [void](& $wn.Txt $Parent (([string]$b.Text).ToUpperInvariant()) $ui.F.SmallB $ui.C.Gray 14 $W 'Label' $null) }
else { [void](& $wn.Txt $Parent $b.Text $ui.F.Body $ui.C.Ink 8 $W 'Text' $null) } }
'steps' {
if (-not $wn.StepFonts) {
$wn.StepFonts=@{ A=@((& $ui.Font 'Segoe UI' 9 $null), (& $ui.Font 'Segoe UI' 8.25 $null), (& $ui.Font 'Segoe UI' 7.5 $null))
B=@((& $ui.Font 'Segoe UI Semibold' 9 $null), (& $ui.Font 'Segoe UI Semibold' 8.25 $null), (& $ui.Font 'Segoe UI Semibold' 7.5 $null)) } }
$s=New-Object Pfm.Steps; $s.BackColor=$ui.C.White; $s.Labels=[string[]]$StepNames; $s.Current=[int]$b.N; $s.Dot=& $wn.Sc 26
$s.DoneFill=$pc.primary; $s.DoneText=$ui.C.White; $s.NowFill=$pc.accentFill; $s.NowLine=$pc.navy; $s.NowText=$pc.ink
$s.TodoFill=$ui.C.White; $s.TodoLine=$pc.muted; $s.TodoText=$pc.ink; $s.ConnDone=$pc.primary; $s.ConnTodo=$pc.track
$s.LabelDone=$pc.ink; $s.LabelNow=$pc.navy; $s.LabelTodo=$pc.muted
$s.Fonts=[Drawing.Font[]]$wn.StepFonts.A; $s.FontsB=[Drawing.Font[]]$wn.StepFonts.B
$lh=[Windows.Forms.TextRenderer]::MeasureText('Ag', $wn.StepFonts.A[0]).Height
$s.Size=[Drawing.Size]::new($W, ($s.Dot + 2 * $lh + (& $wn.Sc 12))); $s.Margin=& $ui.Pad 0 (& $wn.Sc 14) 0 (& $wn.Sc 6)
$s.AccessibleName='Step ' + $b.N + ' of 12: ' + $StepNames[$b.N - 1] + '. Steps 1 to ' + ($b.N - 1) + ' are done.'
[void]$Parent.Controls.Add($s) }
'check' {
$p=& $wn.Panel $W 8
$cp=& $wn.Chip 'ok' $b.Chip $ui.C.White; $cp.Location=[Drawing.Point]::new(0, (& $wn.Sc 2)); [void]$p.Controls.Add($cp)
$x=$cp.Width + (& $wn.Sc 10)
$t=& $wn.Txt $p $b.Text $ui.F.Body $ui.C.Ink 0 ($W - $x) 'Check result' $null; $t.Location=[Drawing.Point]::new($x, 0)
if ($b.Link) { $l=& $wn.Link $b.Link; $l.Location=[Drawing.Point]::new($x, ($t.Bottom + (& $wn.Sc 2))); [void]$p.Controls.Add($l) }
& $wn.Fit $p 4; [void]$Parent.Controls.Add($p) }
'ck' {
$p=& $wn.Panel $W 8
$cb=New-Object System.Windows.Forms.CheckBox; $cb.Text=''; $cb.AutoSize=$false; $cb.Size=[Drawing.Size]::new((& $wn.Sc 24), (& $wn.Sc 24)); $cb.Location=[Drawing.Point]::new((& $wn.Sc 4), (& $wn.Sc 2))
$cb.AccessibleName=[string]$b.Text; $cb.BackColor=$ui.C.White; $cb.Tag=[string]$b.Id; $cb.Checked=[bool]$wn.Field[$b.Id]; & $ui.Cue $cb
$cb.Add_CheckedChanged({ $wn.Field[[string]$this.Tag]=[bool]$this.Checked }); [void]$p.Controls.Add($cb)
$x=& $wn.Sc 38
$t=& $wn.Txt $p $b.Text $ui.F.Body $ui.C.Ink 0 ($W - $x) 'Checkbox text' $null; $t.Location=[Drawing.Point]::new($x, 0)
if ($b.Link) { $l=& $wn.Link $b.Link; $l.Location=[Drawing.Point]::new($x, ($t.Bottom + (& $wn.Sc 2))); [void]$p.Controls.Add($l) }
& $wn.Fit $p 4; [void]$Parent.Controls.Add($p) }
'rows' {
$first=$true
foreach ($r in @($b.Rows)) {
if (-not $first) { & $wn.Rule $Parent $W 0 }
$p=& $wn.Panel $W 0
$lw=[int]($W * 0.5); $vw=$W - $lw - (& $wn.Sc 16)
$a=& $wn.Txt $p $r[0] $ui.F.Small $ui.C.Ink 0 $lw 'Label' $null; $a.Location=[Drawing.Point]::new(0, (& $wn.Sc 8))
if ($r[2]) { $v=& $wn.Chip $r[2] $r[1] $ui.C.White; $v.Location=[Drawing.Point]::new(($W - $v.Width), (& $wn.Sc 6)); [void]$p.Controls.Add($v) }
else { $v=& $wn.Txt $p $r[1] $ui.F.SmallB $ui.C.Ink 0 $vw 'Value' $null; $v.Location=[Drawing.Point]::new(($W - $v.Width), (& $wn.Sc 8)) }
& $wn.Fit $p 8; [void]$Parent.Controls.Add($p); $first=$false } }
'list' {
$first=$true
$cw=0; foreach ($it in @($b.Rows)) { if ($it.Chip) { $cw=[math]::Max($cw, [Windows.Forms.TextRenderer]::MeasureText([string]$it.Chip[1], $ui.F.SmallB).Width + (& $wn.Sc 22)) } }
$tx=$(if ($cw) { $cw + (& $wn.Sc 16) } else { 0 })
foreach ($it in @($b.Rows)) {
if (-not $first) { & $wn.Rule $Parent $W 0 }
$p=& $wn.Panel $W 0
$bw=0; $btn=$null
if ($it.Btn) { $btn=& $wn.Button $it.Btn 'compact'; $btn.AutoSize=$true; $bw=[math]::Max($btn.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $btn.MinimumSize.Width) }
$tw=$W - $tx - $bw - (& $wn.Sc 16) - (& $wn.Sc 8)
if ($it.Chip) { $cp=& $wn.Chip $it.Chip[0] $it.Chip[1] $ui.C.White; $cp.Location=[Drawing.Point]::new(0, (& $wn.Sc 12)); [void]$p.Controls.Add($cp) }
$y=& $wn.Sc 8
$t1=& $wn.Txt $p $it.Title $ui.F.SmallB $ui.C.Ink 0 $tw 'Item' $null; $t1.Location=[Drawing.Point]::new($tx, $y); $y=$t1.Bottom + (& $wn.Sc 2)
if ($it.Sub) { $t2=& $wn.Txt $p $it.Sub $ui.F.Small $ui.C.Gray 0 $tw 'Item detail' $null; $t2.Location=[Drawing.Point]::new($tx, $y); $y=$t2.Bottom + (& $wn.Sc 2) }
if ($it.Detail) { $t3=& $wn.Txt $p $it.Detail $ui.F.Small $ui.C.Gray 0 $tw 'Item detail' $null; $t3.Location=[Drawing.Point]::new($tx, $y); $y=$t3.Bottom }
if ($btn) { $btn.Size=[Drawing.Size]::new($bw, $btn.MinimumSize.Height); $btn.Location=[Drawing.Point]::new(($W - $bw - (& $wn.Sc 4)), [math]::Max((& $wn.Sc 6), [int](($y + (& $wn.Sc 8) - $btn.Height) / 2))); [void]$p.Controls.Add($btn) }
& $wn.Fit $p 8; [void]$Parent.Controls.Add($p); $first=$false } }
'grid' { & $wn.Grid $Parent $b $W $Ctx }
'filter' {
$f=& $wn.Flow $Parent $ui.C.White; $f.Margin=& $ui.Pad 0 0 0 (& $wn.Sc 10)
[void](& $wn.Txt $f 'Find a publication' $ui.F.SmallB $ui.C.Navy 8 (& $wn.Sc 140) 'Label' $null)
$tb=New-Object System.Windows.Forms.TextBox; $tb.Width=& $wn.Sc 260; $tb.Font=$ui.F.Body; $tb.AccessibleName='Find a publication'; $tb.Margin=& $ui.Pad (& $wn.Sc 4) (& $wn.Sc 4) (& $wn.Sc 16) (& $wn.Sc 4)
$tb.Text=[string]$wn.Field.find; $tb.Add_TextChanged({ $wn.Field.find=$this.Text; & $wn.Refilter }); & $ui.Cue $tb; $ui.Boxes=@($ui.Boxes) + @($tb); [void]$f.Controls.Add($tb)
[void](& $wn.Txt $f 'Show' $ui.F.SmallB $ui.C.Navy 8 (& $wn.Sc 60) 'Label' $null)
$cmb=New-Object System.Windows.Forms.ComboBox; $cmb.DropDownStyle='DropDownList'; $cmb.Font=$ui.F.Body; $cmb.Width=& $wn.Sc 230; $cmb.AccessibleName='Show'; $cmb.Margin=& $ui.Pad (& $wn.Sc 4) (& $wn.Sc 4) (& $wn.Sc 4) (& $wn.Sc 4)
foreach ($o in 'All open actions', 'Needs you', 'Late or no answer') { [void]$cmb.Items.Add($o) }
$cmb.SelectedIndex=[int]$wn.Field.show; $cmb.Add_SelectedIndexChanged({ $wn.Field.show=$this.SelectedIndex; & $wn.Refilter }); & $ui.Cue $cmb; [void]$f.Controls.Add($cmb) }
'input' {
[void](& $wn.Txt $Parent $b.Label $ui.F.SmallB $ui.C.Navy 14 $W 'Label' $null)
$tb=New-Object System.Windows.Forms.TextBox; $tb.Font=$ui.F.Body; $tb.AccessibleName=[string]$b.Label; $tb.Tag=[string]$b.Id; $tb.BorderStyle='FixedSingle'
$tb.Margin=& $ui.Pad (& $wn.Sc 4) (& $wn.Sc 6) (& $wn.Sc 4) (& $wn.Sc 4)
if ($b.Multi) { $tb.Multiline=$true; $tb.AcceptsReturn=$true; $tb.ScrollBars='Vertical'; $tb.Size=[Drawing.Size]::new(($W - (& $wn.Sc 8)), (& $wn.Sc 88)) } else { $tb.Width=[math]::Min($W - (& $wn.Sc 8), (& $wn.Sc 420)) }
$tb.Text=[string]$wn.Field[$b.Id]; $tb.Add_TextChanged({ $wn.Field[[string]$this.Tag]=$this.Text }); & $ui.Cue $tb; $ui.Boxes=@($ui.Boxes) + @($tb)
[void]$Parent.Controls.Add($tb); if ($b.Id -eq 'reason') { $wn.Reason=$tb } }
'radio' {
[void](& $wn.Txt $Parent $b.Label $ui.F.SmallB $ui.C.Navy 14 $W 'Label' $null)
$i=0
foreach ($o in @($b.Items)) {
$rb=New-Object System.Windows.Forms.RadioButton; $rb.Text=[string]$o; $rb.AutoSize=$true; $rb.Font=$ui.F.Body; $rb.BackColor=$ui.C.White; $rb.Tag=$i; $rb.AccessibleName=[string]$o
$rb.Margin=& $ui.Pad (& $wn.Sc 4) (& $wn.Sc 6) (& $wn.Sc 4) 0; $rb.Checked=([int]$wn.Field.radio -eq $i); & $ui.Cue $rb
$rb.Add_CheckedChanged({ if ($this.Checked) { $wn.Field.radio=[int]$this.Tag } }); [void]$Parent.Controls.Add($rb); $i++ } }
'err' {
if ($wn.Err -eq $b.Key) { [void](& $wn.Txt $Parent ('Error: ' + $b.Text) $ui.F.SmallB $ui.C.Red 10 $W 'Error' $null) } }
'progress' {
$pb=New-Object System.Windows.Forms.ProgressBar; $pb.Style='Continuous'; $pb.Maximum=[int]$b.Max; $pb.Value=[int]$b.Value; $pb.AccessibleName=[string]$b.Text
$pb.Size=[Drawing.Size]::new($W, (& $wn.Sc 14)); $pb.Margin=& $ui.Pad 0 (& $wn.Sc 12) 0 0; [void]$Parent.Controls.Add($pb)
[void](& $wn.Txt $Parent $b.Text $ui.F.SmallB $ui.C.Ink 6 $W 'Progress' $null) }
'buttons' {
$f=& $wn.Flow $Parent $ui.C.White; $f.WrapContents=$true; $f.MaximumSize=[Drawing.Size]::new($W, 0); $f.Margin=& $ui.Pad 0 (& $wn.Sc 14) 0 0
foreach ($it in @($b.Items)) {
$x=& $wn.Button $it 'action'; [void]$f.Controls.Add($x)
if ($it.Kind -eq 'primary' -and -not $wn.Primary) { $wn.Primary=$x } } }
} }
$wn.Fills=@{ turn=$pc.accentFill; late=$pc.redTint; soon=$pc.amberTint; ok=$pc.greenTint; amber=$pc.amberTint; neu=$pc.surface }
$wn.GridFill={ param($G, $Rows)
$G.Rows.Clear(); $G.Tag.Shown=@($Rows)
foreach ($r in @($Rows)) {
$vals=@(foreach ($c in $G.Tag.Cols) { if ($c.K -eq 'since') { $(if ($c.W -ge 100) { [string]$r.Since + ' ' + $mid + ' ' + [string]$r.Age } else { [string]$r.Age }) } else { [string]$r[$c.N] } })
[void]$G.Rows.Add([object[]]$vals) } }
$wn.Grid={ param($Parent, $b, [int]$W, $Ctx)
$cols=@($b.Cols); if ($wn.Wide -and $b.ColsWide) { $wf=0; foreach ($c in $b.ColsWide) { $wf += (& $wn.Sc $c.W) }; if ($wf + (& $wn.Sc 137) -le $W) { $cols=@($b.ColsWide) } }
$rows=@($b.Rows); $hdrH=& $wn.Sc 33; $rowH=& $wn.Sc 41
$full=$hdrH + $rowH * $rows.Count + 2; $h=$full
if ($b.Fill) {
$used=0; try { $used=[int]$Ctx.Col.PreferredSize.Height } catch { $null=$_ }
$avail=$wn.MainH - $wn.HeadH - $used - (& $wn.Sc 70); $h=[int][math]::Min($full, [math]::Max($avail, $hdrH + 6 * $rowH)) }
$g=New-Object System.Windows.Forms.DataGridView
$g.AccessibleName=[string]$b.Name; $g.Size=[Drawing.Size]::new($W, $h); $g.Margin=& $ui.Pad 0 (& $wn.Sc 8) 0 0
$g.AllowUserToAddRows=$false; $g.AllowUserToDeleteRows=$false; $g.AllowUserToResizeRows=$false; $g.AllowUserToResizeColumns=$false
$g.ReadOnly=$true; $g.RowHeadersVisible=$false; $g.MultiSelect=$false; $g.SelectionMode='FullRowSelect'; $g.EnableHeadersVisualStyles=$false
$g.ColumnHeadersHeightSizeMode='DisableResizing'; $g.ColumnHeadersHeight=$hdrH; $g.RowTemplate.Height=$rowH
$g.CellBorderStyle='None'; $g.ColumnHeadersBorderStyle='None'; $g.BorderStyle='None'; $g.BackgroundColor=$ui.C.White; $g.GridColor=$pc.line
$g.AutoSizeColumnsMode='Fill'; $g.ScrollBars='Vertical'; $g.DefaultCellStyle.WrapMode='True'; $g.AutoSizeRowsMode='AllCells'; $g.RowTemplate.MinimumHeight=$rowH
$g.DefaultCellStyle.Padding=& $ui.Pad (& $ui.Sc 10) (& $ui.Sc 8) (& $ui.Sc 10) (& $ui.Sc 8); $g.DefaultCellStyle.Font=$ui.F.Small; $g.DefaultCellStyle.ForeColor=$ui.C.Ink; $g.DefaultCellStyle.BackColor=$ui.C.White
$g.DefaultCellStyle.SelectionBackColor=$pc.surface; $g.DefaultCellStyle.SelectionForeColor=$ui.C.Ink
$g.ColumnHeadersDefaultCellStyle.BackColor=$ui.C.White; $g.ColumnHeadersDefaultCellStyle.ForeColor=$pc.muted; $g.ColumnHeadersDefaultCellStyle.Font=$ui.F.SmallB; $g.ColumnHeadersDefaultCellStyle.SelectionBackColor=$ui.C.White
# Every column fills the grid's own width: a column keeps at most its own width as its minimum, and all minimums together
# never exceed the width the grid has, so the sum of the visible columns never exceeds the client width (R28 finding 4).
$fixed=0; $open=0; foreach ($c in $cols) { if ($c.W -eq 0) { $open++ } else { $fixed += (& $wn.Sc $c.W) } }
$scroll=$(if ($full -gt $h) { [Windows.Forms.SystemInformation]::VerticalScrollBarWidth } else { 0 })
$avail=$W - $scroll - 2; $need=$fixed + $open * (& $wn.Sc 60); $k=$(if ($need -gt $avail) { [double]$avail / $need } else { 1.0 })
$kinds=@{}
foreach ($c in $cols) {
$dc=New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $dc.Name=[string]$c.N; $dc.HeaderText=$(if ($c.H) { [string]$c.H } else { [string]$c.N }); $dc.SortMode='NotSortable'
$own=$(if ($c.W -eq 0) { & $wn.Sc 60 } else { & $wn.Sc $c.W })
$dc.AutoSizeMode='Fill'; $dc.MinimumWidth=[math]::Max(2, [int][math]::Floor($own * $k)); $dc.FillWeight=[single]$(if ($c.W -eq 0) { [math]::Max(60, $W - $fixed - $scroll) } else { $c.W })
[void]$g.Columns.Add($dc); $kinds[[string]$c.N]=[string]$c.K }
$chipKind=@{}; foreach ($r in $rows) { if ($r.Status) { $chipKind[[string]$r.Status]=[string]$r.Kind } }
$g.Tag=@{ Kind=$kinds; Chip=$chipKind; Cols=$cols; Shown=$rows }
& $wn.GridFill $g $rows
$g.Add_CellPainting({ param($s, $e)
try {
$tag=$s.Tag; $kind=[string]$tag.Kind[$s.Columns[$e.ColumnIndex].Name]; $bd=$e.CellBounds; $gr=$e.Graphics; $pd=& $ui.Sc 10
$fl=[Windows.Forms.TextFormatFlags]'Left, VerticalCenter, SingleLine, NoPadding, NoPrefix, EndEllipsis'
$fw=[Windows.Forms.TextFormatFlags]'Left, VerticalCenter, WordBreak, NoPadding, NoPrefix'
$tr=New-Object System.Drawing.Rectangle(($bd.X + $pd), $bd.Y, [math]::Max(1, $bd.Width - 2 * $pd), ($bd.Height - 1))
if ($e.RowIndex -lt 0) {
$br=New-Object System.Drawing.SolidBrush($ui.C.White); $gr.FillRectangle($br, $bd); $br.Dispose()
[Windows.Forms.TextRenderer]::DrawText($gr, ([string]$e.Value).ToUpperInvariant(), $ui.F.SmallB, $tr, $pc.muted, $fl)
$pn=New-Object System.Drawing.Pen($pc.muted, 1); $gr.DrawLine($pn, $bd.X, ($bd.Bottom - 1), $bd.Right, ($bd.Bottom - 1)); $pn.Dispose()
$e.Handled=$true; return }
$bg=$(if ($s.Rows[$e.RowIndex].Selected) { $pc.surface } else { $ui.C.White })
$br=New-Object System.Drawing.SolidBrush($bg); $gr.FillRectangle($br, $bd); $br.Dispose()
$pn=New-Object System.Drawing.Pen($pc.line, 1); $gr.DrawLine($pn, $bd.X, ($bd.Bottom - 1), $bd.Right, ($bd.Bottom - 1)); $pn.Dispose()
$text=[string]$e.Value
if ($kind -eq 'pub') {
$pp=$text.Split('|')
$w1=[Windows.Forms.TextRenderer]::MeasureText($pp[0], $ui.F.Link, ([Drawing.Size]::new(100000, 0)), [Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width
$w2=0; if ($pp.Count -gt 1) { $w2=[Windows.Forms.TextRenderer]::MeasureText($pp[1], $ui.F.Small, ([Drawing.Size]::new(100000, 0)), [Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width }
$rest=New-Object System.Drawing.Rectangle(($tr.X + $w1 + (& $ui.Sc 6)), $tr.Y, ($tr.Width - $w1 - (& $ui.Sc 6)), $tr.Height)
if ($pp.Count -lt 2 -or $rest.Width -ge $w2) {
[Windows.Forms.TextRenderer]::DrawText($gr, $pp[0], $ui.F.Link, $tr, $pc.primary, $fl)
if ($pp.Count -gt 1) { [Windows.Forms.TextRenderer]::DrawText($gr, $pp[1], $ui.F.Small, $rest, $pc.muted, $fl) } }
else {   # the rest does not fit beside the name: it goes on a second line (the cell wraps)
$lh=[int][math]::Ceiling($ui.F.Link.GetHeight($gr)); $top=$tr.Y + [int](($tr.Height - 2 * $lh) / 2)
[Windows.Forms.TextRenderer]::DrawText($gr, $pp[0], $ui.F.Link, (New-Object System.Drawing.Rectangle($tr.X, $top, $tr.Width, $lh)), $pc.primary, $fl)
[Windows.Forms.TextRenderer]::DrawText($gr, $pp[1], $ui.F.Small, (New-Object System.Drawing.Rectangle($tr.X, ($top + $lh), $tr.Width, $lh)), $pc.muted, $fw) } }
elseif ($kind -eq 'with') { [Windows.Forms.TextRenderer]::DrawText($gr, $text, $ui.F.SmallB, $tr, $pc.navy, $fw) }
elseif ($kind -eq 'bold') { [Windows.Forms.TextRenderer]::DrawText($gr, $text, $ui.F.SmallB, $tr, $pc.ink, $fw) }
elseif ($kind -eq 'chip') {
$ck=[string]$tag.Chip[$text]; $cwid=[Windows.Forms.TextRenderer]::MeasureText($text, $ui.F.SmallB, ([Drawing.Size]::new(100000, 0)), [Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width + (& $ui.Sc 20)
$chh=& $ui.Sc 26; $cy=$bd.Y + [int](($bd.Height - 1 - $chh) / 2); $rc=New-Object System.Drawing.RectangleF(($bd.X + $pd), $cy, $cwid, $chh)
$gr.SmoothingMode='AntiAlias'; $path=[Pfm.Gfx]::Round($rc, ($chh / 2.0)); $br=New-Object System.Drawing.SolidBrush($wn.Fills[$ck]); $gr.FillPath($br, $path); $br.Dispose(); $path.Dispose(); $gr.SmoothingMode='Default'
[Windows.Forms.TextRenderer]::DrawText($gr, $text, $ui.F.SmallB, (New-Object System.Drawing.Rectangle(($bd.X + $pd), $cy, [int]$cwid, $chh)), $pc.ink, [Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding, NoPrefix') }
else { [Windows.Forms.TextRenderer]::DrawText($gr, $text, $ui.F.Small, $tr, $ui.C.Ink, $fw) }
$e.Handled=$true
} catch { $null=$_ } })
$g.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { & $wn.Later $s $e.RowIndex } })
$g.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Return') { $e.Handled=$true; $e.SuppressKeyPress=$true; if ($s.CurrentRow) { & $wn.Later $s $s.CurrentRow.Index } } })
[void]$Parent.Controls.Add($g); $g.ClearSelection(); $wn.Gridsel=$g
if ($b.Count) { $wn.CountText=[string]$b.Count; $wn.CountBox=& $wn.Txt $Parent ($b.Count -f $rows.Count) $ui.F.Small $ui.C.Gray 8 $W 'Count' $null; $wn.Gridq=$g } }
$wn.Later={ param($G, [int]$I) $wn.PendG=$G; $wn.PendI=$I; [void]$form.BeginInvoke([Action]{ & $wn.OpenRow $wn.PendG $wn.PendI }) }
$wn.OpenRow={ param($G, [int]$I)
$r=@($G.Tag.Shown)[$I]
if ($r -and $r.Go) { & $wn.Press @{ Go=[string]$r.Go; Text='Open' } } }
$wn.Refilter={
$g=$wn.Gridq; if (-not $g) { return }
$q=([string]$wn.Field.find).Trim(); $m=[int]$wn.Field.show
$rows=@($GridQueue | Where-Object { ($m -eq 0 -or ($m -eq 1 -and $_.Me) -or ($m -eq 2 -and $_.Kind -eq 'late')) -and (-not $q -or ([string]$_.Publication).IndexOf($q, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) })
& $wn.GridFill $g $rows; $g.ClearSelection()
if ($wn.CountBox) { $wn.CountBox.Text=([string]$wn.CountText -f $rows.Count) } }
$wn.Press={ param($B)
if (-not (& $ui.Settled)) { return }
$script:presses++
$need=[string]$B.Need
if ($need -eq 'reason' -and -not ([string]$wn.Field.reason).Trim()) { $wn.Err='reason'; $wn.Notice=''; $wn.Focus='reason'; & $wn.Show $wn.Cur; return }
if ($need -eq 'ck' -and -not ($wn.Field.ck1 -and $wn.Field.ck2)) { $wn.Err='ck'; $wn.Notice=''; & $wn.Show $wn.Cur; return }
$wn.Err=''; $wn.Notice=[string]$B.Note
$go=[string]$B.Go
if ($go -eq '@grid') { $go=''; $g=$wn.Gridsel; if ($g -and @($g.Tag.Shown).Count) { $i=0; if ($g.SelectedRows.Count) { $i=[int]$g.SelectedRows[0].Index }; $go=[string]@($g.Tag.Shown)[$i].Go } }
if ($go -eq 'back') { $go=$wn.Prev }
if ($go) { & $wn.Show $go } else { & $wn.Show $wn.Cur } }
$rail=New-Object System.Windows.Forms.Panel; $rail.Dock='Left'; $rail.BackColor=$pc.navy; $rail.AccessibleName='Main menu'
$main=New-Object System.Windows.Forms.Panel; $main.Dock='Fill'; $main.BackColor=$pc.surface; $main.AutoScroll=$true; $main.AccessibleName='Main column'
$page=New-Object System.Windows.Forms.FlowLayoutPanel; $page.FlowDirection='TopDown'; $page.WrapContents=$false; $page.AutoSize=$true; $page.AutoSizeMode='GrowAndShrink'; $page.BackColor=$pc.surface
[void]$main.Controls.Add($page)
$form.Controls.Add($main); $form.Controls.Add($rail)
$wn.RailBtn=@()
$wn.RailLayout={
$wide=($form.ClientSize.Width -ge (& $wn.Sc 1500)); $rw=$(if ($wide) { & $wn.Sc 220 } else { & $wn.Sc 200 }); $rail.Width=$rw
foreach ($x in $wn.RailBtn) { $x.Width=$rw - 2 * (& $wn.Sc 12) } }
$wn.BuildRail={
$rail.SuspendLayout()
try {
$logo=New-Object System.Windows.Forms.PictureBox; $logo.Size=[Drawing.Size]::new((& $wn.Sc 40), (& $wn.Sc 40)); $logo.SizeMode='Zoom'; $logo.BackColor=$ui.C.White; $logo.AccessibleName='RADE logo'
$logo.Location=[Drawing.Point]::new((& $wn.Sc 16), (& $wn.Sc 16))
$logo.Image=[Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($RadeLogoPng)))); [void]$rail.Controls.Add($logo)
} catch { $lines.Add('NOTE logo not shown: ' + $_.Exception.Message) }
$nm=& $ui.Label $ui.F.Word $ui.C.White 0; $nm.BackColor=$pc.navy; $nm.Text='90-161.Z'; $nm.Visible=$true; $nm.Location=[Drawing.Point]::new((& $wn.Sc 64), (& $wn.Sc 18)); [void]$rail.Controls.Add($nm)
$sb=& $ui.Label $ui.F.Small $pc.onPrimaryMuted 0; $sb.BackColor=$pc.navy; $sb.Text='Publications and Forms'; $sb.Visible=$true; $sb.Location=[Drawing.Point]::new((& $wn.Sc 16), (& $wn.Sc 66)); [void]$rail.Controls.Add($sb)
$y=& $wn.Sc 108
foreach ($r in $RailItems) {
$x=New-Object Pfm.RailItem; $x.Text=$r.Text; $x.AccessibleName=$r.Text; $x.Tag=$r.Key; $x.Font=$ui.F.Body; $x.BoldFont=$ui.F.SmallB
$x.Back=$pc.navy; $x.OnBack=$ui.C.White; $x.Fore=$pc.onPrimaryMuted; $x.OnFore=$pc.navy; $x.HotLine=$pc.onPrimaryMuted; $x.FocusLine=$pc.accentFill; $x.FocusOn=$pc.navy; $x.BadgeFill=$pc.accentFill; $x.BadgeText=$pc.ink
if ($r.Badge) { $x.Badge=[string]$r.Badge; $x.AccessibleName=$r.Text + ', ' + $r.Badge + ' items need you' }
$x.Size=[Drawing.Size]::new(((& $wn.Sc 200) - 2 * (& $wn.Sc 12)), (& $wn.Sc 44)); $x.Location=[Drawing.Point]::new((& $wn.Sc 12), $y); $y += (& $wn.Sc 48)
$x.Add_Click({ if (& $ui.Settled) { $script:presses++; $wn.Notice=''; $wn.Err=''; $key=[string]$this.Tag; $go='home'; foreach ($q in $RailItems) { if ($q.Key -eq $key) { $go=$q.Go } }; & $wn.Show $go } })
[void]$rail.Controls.Add($x); $wn.RailBtn += $x }
$ft=& $ui.Label $ui.F.Small $pc.onPrimaryMuted 0; $ft.BackColor=$pc.navy; $ft.Text='FAKE data' + [Environment]::NewLine + 'Preview ' + $Rev; $ft.Visible=$true; $ft.Anchor='Left, Bottom'
$ft.Location=[Drawing.Point]::new((& $wn.Sc 16), ($rail.ClientSize.Height - (& $wn.Sc 56))); [void]$rail.Controls.Add($ft)
$rail.ResumeLayout($true); & $wn.RailLayout }
$wn.Show={ param([string]$Key)
$c=$Cards[$Key]; if (-not $c) { return }
if ($Key -ne $wn.Cur) { if ($c.Modal) { $wn.Prev=$wn.Cur }; $wn.Field=@{}; $wn.Err=''; $wn.Focus='' }
$script:opened[$Key]=$true; $wn.Cur=$Key; $ui.View=$Key
$wn.Primary=$null; $wn.Gridsel=$null; $wn.Gridq=$null; $wn.Reason=$null; $wn.CountBox=$null
$ui.Wrap=@{}; $ui.Boxes=@(); $ui.Hot=$null; $ui.Down=$null
$form.SuspendLayout(); $page.SuspendLayout()
foreach ($x in @($page.Controls)) { $page.Controls.Remove($x); $x.Dispose() }
$wide=($form.ClientSize.Width -ge (& $wn.Sc 1500)); $wn.Wide=$wide
$wn.MainH=$main.ClientSize.Height; $padX=& $wn.Sc 28
$cw=[math]::Max((& $wn.Sc 900), $main.ClientSize.Width - [Windows.Forms.SystemInformation]::VerticalScrollBarWidth - 2 * $padX)
$page.Location=[Drawing.Point]::new($padX, (& $wn.Sc 22)); $page.Margin=& $ui.Pad 0 0 0 0; $page.Padding=& $ui.Pad 0 0 0 (& $wn.Sc 22)
foreach ($r in $wn.RailBtn) { $r.On=([string]$r.Tag -eq [string]$c.Rail); $r.Invalidate() }
$title=$null
if ($wn.Notice) {
$nf=& $wn.Flow $page $pc.surface; $nf.Margin=& $ui.Pad 0 0 0 (& $wn.Sc 10); [void]$nf.Controls.Add((& $wn.Chip 'turn' 'NOTICE' $pc.surface))
[void](& $wn.Txt $nf $wn.Notice $ui.F.Body $ui.C.Ink 2 ($cw - (& $wn.Sc 120)) 'Notice' $pc.surface) }
if ($c.Crumb) {
$cf=& $wn.Flow $page $pc.surface; $cf.Margin=& $ui.Pad 0 0 0 (& $wn.Sc 8)
$parts=@(([string]$c.Crumb) -split [regex]::Escape(' ' + $gt + ' '))
if ($c.CrumbGo -and $parts.Count -gt 1) {
$l=& $wn.Link @{ Text=$parts[0]; Go=$c.CrumbGo }; $l.BackColor=$pc.surface; try { $l.FlatAppearance.MouseOverBackColor=$pc.surface } catch { $null=$_ }; [void]$cf.Controls.Add($l)
$title=& $wn.Txt $cf (' ' + $gt + ' ' + ((@($parts | Select-Object -Skip 1)) -join (' ' + $gt + ' '))) $ui.F.Small $ui.C.Gray 8 ($cw - (& $wn.Sc 160)) 'Where you are' $pc.surface }
else { $title=& $wn.Txt $cf $c.Crumb $ui.F.Small $ui.C.Gray 0 $cw 'Where you are' $pc.surface } }
if ($c.Title) { $title=& $wn.Txt $page $c.Title $ui.F.Sent $ui.C.Navy 0 $cw 'Page title' $pc.surface }
if ($c.Sub) { $sub=& $wn.Txt $page $c.Sub $ui.F.Small $ui.C.Gray 4 $cw 'Page line' $pc.surface; $ui.Kick=$sub } else { $ui.Kick=$title }
$ui.Sent=$title
$page.PerformLayout(); $wn.HeadH=[int]$page.PreferredSize.Height
$cols=New-Object System.Windows.Forms.FlowLayoutPanel; $cols.FlowDirection='LeftToRight'; $cols.WrapContents=$false; $cols.AutoSize=$true; $cols.AutoSizeMode='GrowAndShrink'; $cols.BackColor=$pc.surface; $cols.Margin=& $ui.Pad 0 (& $wn.Sc 12) 0 0
[void]$page.Controls.Add($cols)
$gap=& $wn.Sc 18; $nc=@($c.Cols).Count
$side=$(if ($nc -gt 1) { $(if ($Key -eq 'home' -or $Key -eq 'empty') { $(if ($wide) { & $wn.Sc 420 } else { & $wn.Sc 300 }) } else { & $wn.Sc $c.Side }) } else { 0 })
$ci=0
foreach ($colDef in @($c.Cols)) {
$colW=$(if ($nc -le 1) { [math]::Min($cw, (& $wn.Sc 1000)) } elseif ($ci -eq 0) { $cw - $side - $gap } else { $side })
$col=New-Object System.Windows.Forms.FlowLayoutPanel; $col.FlowDirection='TopDown'; $col.WrapContents=$false; $col.AutoSize=$true; $col.AutoSizeMode='GrowAndShrink'; $col.BackColor=$pc.surface
$col.Margin=& $ui.Pad 0 0 $(if ($ci -eq 0 -and $nc -gt 1) { $gap } else { 0 }) 0; [void]$cols.Controls.Add($col)
$ctx=@{ Col=$col }
foreach ($s in @($colDef)) {
if ($s.WideOnly -and -not $wide) { continue }
$px=$(if ($s.Pad) { [int]$s.Pad } else { 24 })
$sec=& $wn.Card $colW $s.Cap $s.Top $px $pc.surface; [void]$col.Controls.Add($sec)
$iw=$colW - 2 * (& $wn.Sc $px)
foreach ($b in @($s.Blocks)) { & $wn.Block $sec $b $iw $ctx }
$sec.PerformLayout() }
$ci++ }
$page.ResumeLayout($true); $form.ResumeLayout($true)
$main.AutoScrollPosition=[Drawing.Point]::new(0, 0)
$form.AcceptButton=$wn.Primary
$ui.CardAt=$ui.Clock.Elapsed.TotalMilliseconds
if ($wn.Focus -eq 'reason' -and $wn.Reason) { [void]$wn.Reason.Focus(); $wn.Focus='' } elseif ($wn.Primary) { [void]$wn.Primary.Focus() }
if ($wn.Ready) { $wn.CheckTimer.Stop(); $wn.CheckTimer.Start() } }
$wn.BoundsFile=$(if ($dir) { Join-Path $dir '90161Z-T22-window-bounds.json' } else { '' })
$wn.LoadBounds={
$ok=$false
try {
if ($wn.BoundsFile -and (Test-Path -LiteralPath $wn.BoundsFile)) {
$j=Get-Content -LiteralPath $wn.BoundsFile -Raw | ConvertFrom-Json
$r=New-Object System.Drawing.Rectangle([int]$j.Left, [int]$j.Top, [int]$j.Width, [int]$j.Height)
$tl=[Drawing.Point]::new($r.X + (& $wn.Sc 40), $r.Y + (& $wn.Sc 10)); foreach ($sc in [Windows.Forms.Screen]::AllScreens) { if ($sc.WorkingArea.Contains($tl)) { $ok=$true } }
if ($ok -and $r.Width -ge (& $wn.Sc 400) -and $r.Height -ge (& $wn.Sc 300)) { $form.StartPosition='Manual'; $form.Bounds=$r; if ([string]$j.State -eq 'Maximized') { $form.WindowState='Maximized' } } else { $ok=$false } }
} catch { $ok=$false }
if (-not $ok) {
$wa=[Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position).WorkingArea
$w=[int]($wa.Width * 0.9); $h=[int]($wa.Height * 0.9); $form.StartPosition='Manual'
$form.Bounds=New-Object System.Drawing.Rectangle(($wa.X + [int](($wa.Width - $w) / 2)), ($wa.Y + [int](($wa.Height - $h) / 2)), $w, $h) } }
$wn.State={ param([string]$When)
$lines.Add('STATE ' + $When + ': WindowState=' + $form.WindowState + ' client=' + $form.ClientSize.Width + 'x' + $form.ClientSize.Height + ' bounds=' + $form.Bounds.Width + 'x' + $form.Bounds.Height + ' at ' + $form.Bounds.X + ',' + $form.Bounds.Y) }
$wn.SaveBounds={
try {
if (-not $wn.BoundsFile) { return }
$r=$(if ($form.WindowState -eq 'Normal') { $form.Bounds } else { $form.RestoreBounds })
$st=$(if ($form.WindowState -eq 'Maximized') { 'Maximized' } else { 'Normal' })
$o='{ "Left": ' + $r.X + ', "Top": ' + $r.Y + ', "Width": ' + $r.Width + ', "Height": ' + $r.Height + ', "State": "' + $st + '" }'
Set-Content -LiteralPath $wn.BoundsFile -Value $o -Encoding UTF8
} catch { $lines.Add('NOTE the window place was not saved: ' + ([string]$_.Exception.Message)) } }
# The check bar (PFM 17 Nov 26: the checks show inside the test window, one at a time, with Pass and Fail; no list to remember).
# It sits at the bottom of the window and is always visible. Pass or Fail moves to the next check; the answers go to the result file.
$wn.CheckAt=0; $wn.Answers=New-Object 'string[]' $Checks.Count
$wn.BarShow={
$i=[int]$wn.CheckAt
if ($i -lt $Checks.Count) {
$wn.BarNo.Text='Check ' + ($i + 1) + ' of ' + $Checks.Count; $wn.BarText.Text=[string]$Checks[$i].Text
$wn.BarPass.Visible=$true; $wn.BarFail.Visible=$true }
else {
$wn.BarNo.Text='Checks'; $wn.BarText.Text='All checks done. Close this window with its X.'
$wn.BarPass.Visible=$false; $wn.BarFail.Visible=$false } }
$wn.Answer={ param([string]$Result)
if ($wn.CheckAt -ge $Checks.Count) { return }
$wn.Answers[$wn.CheckAt]=$Result; $wn.CheckAt++
& $wn.BarShow }
$wn.BarLayout={
if (-not $wn.Bar) { return }
$w=$form.ClientSize.Width; $pad=& $wn.Sc 16; $gap=& $wn.Sc 8
$pw=[math]::Max($wn.BarPass.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.BarPass.MinimumSize.Width)
$fw=[math]::Max($wn.BarFail.GetPreferredSize(([Drawing.Size]::new(0, 0))).Width, $wn.BarFail.MinimumSize.Width)
$bh=[math]::Max($wn.BarPass.Height, $wn.BarFail.Height)
$tw=[math]::Max((& $wn.Sc 200), $w - 2 * $pad - $pw - $fw - 2 * $gap)
$th=0; foreach ($c in $Checks) { $m=& $ui.Meas ([string]$c.Text) $ui.F.Body $tw; $th=[math]::Max($th, [int]$m.Height) }
$th += (& $wn.Sc 6)
$nh=[int]$wn.BarNo.PreferredSize.Height
$wn.Bar.Height=[math]::Max($bh + 2 * $pad, $pad + $nh + (& $wn.Sc 2) + $th + $pad)
$wn.BarNo.Location=[Drawing.Point]::new($pad, $pad)
$wn.BarText.Location=[Drawing.Point]::new($pad, ($pad + $nh + (& $wn.Sc 2))); & $ui.SetWrap $wn.BarText $tw; $wn.BarText.Size=[Drawing.Size]::new($tw, $th)
$by=[int](($wn.Bar.Height - $bh) / 2)
$wn.BarPass.Location=[Drawing.Point]::new(($w - $pad - $fw - $gap - $pw), $by); $wn.BarFail.Location=[Drawing.Point]::new(($w - $pad - $fw), $by) }
$wn.BuildBar={
$bar=New-Object System.Windows.Forms.Panel; $bar.Dock='Bottom'; $bar.BackColor=$ui.C.White; $bar.AccessibleName='Check bar'
$bar.Add_Paint({ try { $pn=New-Object System.Drawing.Pen($pc.line, 1); $_.Graphics.DrawLine($pn, 0, 0, $this.ClientSize.Width, 0); $pn.Dispose() } catch { $null=$_ } })
$no=& $ui.Label $ui.F.SmallB $ui.C.Gray 0; $no.Visible=$true; $no.AccessibleName='Check number'; [void]$bar.Controls.Add($no)
$tx=& $ui.Text $ui.F.Body $ui.C.Ink 0 'Check'; $tx.Visible=$true; [void]$bar.Controls.Add($tx)
foreach ($n in 'Pass', 'Fail') {
$x=& $ui.Btn 'action'; $x.Text=$n; & $ui.Style $x ''; $x.AccessibleName=$n; $x.Tag=$n
$x.Add_SizeChanged({ & $wn.Round $this 4 })
$x.Add_Click({ $r=([string]$this.Tag).ToUpperInvariant(); & $wn.Answer $r })
[void]$bar.Controls.Add($x); if ($n -eq 'Pass') { $wn.BarPass=$x } else { $wn.BarFail=$x } }
$wn.Bar=$bar; $wn.BarNo=$no; $wn.BarText=$tx
$form.Controls.Add($bar); $main.BringToFront()
& $wn.BarShow; & $wn.BarLayout }
$wn.Ready=$false; $wn.LastW=0; $wn.LastH=0
$wn.CheckTimer=New-Object System.Windows.Forms.Timer; $wn.CheckTimer.Interval=350
$wn.CheckTimer.Add_Tick({ $wn.CheckTimer.Stop(); try { & $ui.Check; & $wn.ScrollCheck } catch { $null=$_ } })
$wn.SizeTimer=New-Object System.Windows.Forms.Timer; $wn.SizeTimer.Interval=250
$wn.SizeTimer.Add_Tick({ $wn.SizeTimer.Stop()
if ($form.ClientSize.Width -ne $wn.LastW -or $form.ClientSize.Height -ne $wn.LastH) { $wn.LastW=$form.ClientSize.Width; $wn.LastH=$form.ClientSize.Height; & $wn.RailLayout; & $wn.Show $wn.Cur } })
$ui.Trash=@($ui.Trash) + @($wn.CheckTimer, $wn.SizeTimer)
$wn.ScrollCheck={
$st=New-Object System.Collections.Stack; $st.Push($page)
while ($st.Count) { foreach ($c in $st.Pop().Controls) { if ($c -is [Windows.Forms.DataGridView]) { $sum=0; foreach ($k in $c.Columns) { if ($k.Visible) { $sum += $k.Width } }; if ($sum -gt $c.ClientSize.Width + 1) { $ui.LayBad.Add('LAYOUT ' + $wn.Cur + ' grid ' + $c.AccessibleName + ' columns need ' + $sum + ', the grid has ' + $c.ClientSize.Width) } } elseif ($c.Controls.Count) { $st.Push($c) } } }
$logicalW=[int]($form.ClientSize.Width / ([math]::Max(0.5, $ui.Dpi / 96.0)))
if ($logicalW -ge 1280 -and $main.HorizontalScroll.Visible) { $ui.LayBad.Add('LAYOUT ' + $wn.Cur + ' the main column scrolls sideways at ' + $form.ClientSize.Width + 'x' + $form.ClientSize.Height) }
if ($main.VerticalScroll.Visible) { $wn.Scrolled[$wn.Cur]=1 } }
$wn.Scrolled=@{}
$wn.Start={
& $wn.LoadBounds
& $ui.FormDpi
$form.MinimumSize=[Drawing.Size]::new((& $wn.Sc 800), (& $wn.Sc 560))
$form.BackColor=$pc.surface
& $wn.BuildBar
& $wn.BuildRail
& $wn.State 'shown'
$wn.LastW=$form.ClientSize.Width; $wn.LastH=$form.ClientSize.Height
foreach ($k in $Cards.Keys) { $wn.Notice=''; $wn.Err=''; & $wn.Show $k; [Windows.Forms.Application]::DoEvents(); & $ui.Check; & $wn.ScrollCheck }
$wn.Notice=''; $wn.Err=''; & $wn.Show 'home'
$wn.Ready=$true; $form.Opacity=1
try { $form.TopMost=$true; $form.Activate(); $form.TopMost=$false } catch { $null=$_ } }
$form.Add_Shown({ try { & $wn.Start } catch { $lines.Add('STOPPED: the window could not be built (' + (ConvertTo-Masked ([string]$_.Exception.Message) $who.Secret) + ')'); $script:code=1; try { $form.Close() } catch { $null=$_ } } })
$form.Add_SizeChanged({ if ($wn.Ready) { & $wn.BarLayout; $wn.SizeTimer.Stop(); $wn.SizeTimer.Start() } })
$form.Add_KeyDown({
if ($_.KeyCode -eq 'Escape') {
$up=[string]$Cards[$wn.Cur].Up; if ($up -eq 'back') { $up=$wn.Prev }
if ($up -and $wn.Cur -ne 'home') { $wn.Notice=''; $wn.Err=''; & $wn.Show $up }
$_.Handled=$true; $_.SuppressKeyPress=$true }
elseif ($_.Control -and $_.KeyCode -ge [Windows.Forms.Keys]::D1 -and $_.KeyCode -le [Windows.Forms.Keys]::D5) {
$n=[int]$_.KeyCode - [int][Windows.Forms.Keys]::D1; $wn.Notice=''; $wn.Err=''; & $wn.Show ([string]$RailItems[$n].Go); $_.Handled=$true; $_.SuppressKeyPress=$true } })
$form.Add_FormClosing({ & $wn.State 'close'; & $wn.SaveBounds })
[void]$form.ShowDialog()
$wn.Ready=$false
$dpi=96; try { $g=$form.CreateGraphics(); $dpi=[int]$g.DpiX; $g.Dispose() } catch { $null=$_ }
$lines.Add('SCALE dpi=' + $dpi + ' autoScale=' + $form.CurrentAutoScaleDimensions.Width + ' controlDpi=' + $ui.Dpi + ' fontFactor=' + $ui.FontK + ' fontDpi=' + $ui.FontDpi + ' screenDpi=' + $ui.ScreenDpi)
$lines.Add('CARDS opened: ' + $(if ($opened.Count) { (@($Cards.Keys | Where-Object { $opened[$_] }) -join ', ') } else { 'none' }) + ' (' + $opened.Count + ' of ' + $Cards.Count + ')')
$lines.Add('BUTTONS selected=' + $presses)
$lines.Add('SECONDS open=' + [int]((Get-Date) - $started).TotalSeconds)
foreach ($d in @($ui.LayBad)) { $defects.Add([string]$d) }
foreach ($d in $defects) { $lines.Add('FAIL ' + $d) }
if ($defects.Count -eq 0) { $lines.Add('PASS layout') }
$lines.Add('SCROLLS vertical: ' + $(if ($wn.Scrolled.Count) { (@($wn.Scrolled.Keys) -join ', ') } else { 'none' }))
$lines.Add('LAYOUT self-check: ' + $defects.Count + ' defects in ' + $ui.LayCards.Count + ' card views')
$cp=0; $cf=0; $cs=0
for ($i=0; $i -lt $Checks.Count; $i++) {
$a=[string]$wn.Answers[$i]
if ($a -eq 'PASS') { $cp++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' PASS') }
elseif ($a -eq 'FAIL') { $cf++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' FAIL') }
else { $cs++; $lines.Add('CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ' FAIL (not answered)') } }
$lines.Add('CHECKS passed=' + $cp + ' failed=' + $cf + ' not answered=' + $cs)
foreach ($t in @($ui.Trash)) { try { $t.Dispose() } catch { $null=$_ } }
$form.Dispose()
} catch {
$code=1
$lines.Add('STOPPED: no window (' + ([string]$_.Exception.Message).Substring(0, [Math]::Min(200, ([string]$_.Exception.Message).Length)) + ')')
} finally {
if ($PlanOnly) { exit 0 }
$lines.Add('WINDOW done: cards=' + $opened.Count + ' buttons=' + $presses + ' defects=' + $defects.Count + ' checks failed=' + $cf)
$masked=@($lines | ForEach-Object { $t=[string]$_; if ($who) { $t=ConvertTo-Masked $t $who.Secret }; $t })
if ($dir) { try { Set-Content -LiteralPath (Join-Path $dir ('90161Z-T22-window-' + $Rev + '.txt')) -Value $masked -Encoding UTF8 } catch { $null=$_ } }
$masked | ForEach-Object { Write-Host $_ }
if (-not $NoPause -and -not $env:RADE_CONTRACT -and -not $PlanOnly) { [void](Read-Host 'Press Enter to close') }
}
exit $code
