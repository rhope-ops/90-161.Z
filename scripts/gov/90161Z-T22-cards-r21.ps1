<#
.SYNOPSIS
  90-161.Z Task 22 r21, part "cards": the FAKE data of the PFM window (the 17 cards, the rail, the in-window checks)
  and the plan text that -PlanOnly prints.
.DESCRIPTION
  R17 (round R44 T4; R43 finding 3): the look step after the waves card names the grid by the head line above it
  (Get-WaveHead), a line that the card shows. The grid's own name ("Wave 1 answers") is only its accessible name; no card
  shows it.
  R14 (R41; PFM 20 Nov 26, docs/reviews/2026-11-21-r41-plan.md row 3): the click-through of every screen in order
  (Get-WalkPlan: the steps after the 4 checks; -PlanOnly prints them as WALK lines).
  R13 (R40; PFM 20 Nov 26, R39 finding 1): the -Again check names the card saved at the last close, by its title
  (Get-AgainText; the main script gives it the saved card); the closing line of the check bar names no card.
  R11 (R38; PFM 20 Nov 26): the fake names start with "XXX XXX " (wide letters, to test spacing); the check bar has 3 checks
  (status chips and names on All Actions and Your Work); the Weekdays head may wrap (HW).
  Pure data and text: no window, no Windows Forms. The main script 90161Z-T22-pfm-window-r21.ps1 dot-sources this file
  from its own folder before it does anything else, so the cards exist for -PlanOnly, for -Measure and for the window.
  Inputs: none. Outputs: the variables $mid, $gt, $StepNames, $GridHome, $GridQueue, $Checks, $Cards, $RailItems, $Walk
  and the functions Get-SideStatus, Test-CheckLink, Get-CardName, Get-AgainText, Get-CardPlan, Get-CheckPlan,
  Get-WalkOpener, Get-WalkPlan and Get-WalkPlanText.
  Run: not alone; the main script loads it (round skill section 2: scripts that load each other stay in one folder).
  Network: none.
  Writes: none.
  Credentials: none.
#>
$mid = [string][char]0x00B7   # the dot between facts (kept out of the file text: a script file is ASCII)
$gt = [string][char]0x203A    # the arrow between the parts of a crumb
$StepNames = @('Review due', 'Box told', 'AOs named', 'AOs told', 'Scope', 'Draft', 'Endorsers', 'PFM check', 'Answers', 'Waves', 'Signatures', 'Posted')
# One line per row of the Your Work grid: number|title|action|step|with|since|age|due|status|kind|card.
$HomeRows = (@(
    'XXX XXX OI 33-101|Key Control|Review|8 PFM check|You|16 Nov|1 d|18 Nov|Your turn|turn|step8',
    'XXX XXX OI 21-14|Vehicle Keys|Review|11 Signatures|You|13 Nov|2 d|20 Nov|Your turn|turn|step11',
    'XXX XXX Instruction 10-201|Recall|Rewrite|10 Wave 1|XXX XXX Office 5|23 Oct|17 d|13 Nov|Late|late|waves',
    'XXX XXX OI 31-3|Gate Hours|Review|10 Wave 2|XXX XXX Office 8|26 Oct|16 d|16 Nov|Late|late|waves',
    'XXX XXX OI 90-1|Self-Inspection|Review|10 Wave 3, legal|XXX XXX Legal Office|29 Oct|13 d|19 Nov|Due soon|soon|waves',
    'XXX XXX OI 36-2|Recognition|Change|10 Wave 1|2 offices|30 Oct|12 d|20 Nov|Due soon|soon|waves',
    'XXX XXX OI 10-5|Recall Roster|Certify current|11 Signatures|XXX XXX Wing Staff CSS|12 Nov|3 d|19 Nov|On track|ok|pub',
    'XXX XXX OI 13-4|Airfield Signs|Review|3 AOs named|XXX XXX Office 3 box|12 Nov|3 d|26 Nov|On track|ok|pub',
    'XXX XXX OI 48-2|Hearing Tests|Review|9 Answers|XXX XXX AO 6|11 Nov|4 d|25 Nov|On track|ok|pub',
    'XXX XXX OI 32-1|Work Orders|Review|5 Scope|XXX XXX AO 5|10 Nov|5 d|24 Nov|On track|ok|pub',
    'XXX XXX OI 91-3|Ladder Safety|New|7 Endorsers|XXX XXX AO 7|9 Nov|6 d|1 Dec|On track|ok|pub',
    'XXX XXX Form 12|Key Log|Form|6 Draft|XXX XXX AO 1|5 Nov|8 d|3 Dec|On track|ok|pub',
    'XXX XXX OI 21-6|Tool Control|Review|6 Draft|XXX XXX AO 4|2 Nov|11 d|4 Dec|On track|ok|pub',
    'XXX XXX OI 23-7|Supply Bins|Rewrite|6 Draft|XXX XXX AO 8|28 Oct|14 d|18 Dec|On track|ok|pub',
    'XXX XXX OI 15-1|Weather Calls|Review|2 Box told|XXX XXX Office 9 box|16 Nov|1 d|30 Nov|On track|ok|pub'
  ) -join "`n")
# One line per row of the All Actions grid: number|title|action|step|weekdays|with|status|kind|card|needs you (1 or 0).
$QueueRows = (@(
    'XXX XXX OI 33-101|Key Control|Review|8 PFM check|1|You|Your turn|turn|step8|1',
    'XXX XXX OI 21-14|Vehicle Keys|Review|11 Signatures|2|You|Due 20 Nov 26|soon|step11|1',
    'XXX XXX Instruction 10-201|Recall|Rewrite|10 Waves, wave 1|9|Endorsers|No answer|late|waves|0',
    'XXX XXX OI 31-3|Gate Hours|Review|9 Answers|4|Endorsers|On track|ok|waves|0',
    'XXX XXX OI 36-2|Recognition|Change|6 Draft|12|AO|On track|ok|pub|0',
    'XXX XXX OI 13-4|Airfield Signs|Review|3 AOs named|3|OPR box|Due 19 Nov 26|soon|pub|0',
    'XXX XXX OI 90-1|Self-Inspection|Certify current|11 Signatures|6|Approver''s CSS|On track|ok|pub|0',
    'XXX XXX Form 12|Key Log|Prescribed form|6 Draft|5|AO|On track|ok|pub|0',
    'XXX XXX OI 10-5|Recall Roster|Certify current|11 Signatures|3|Wing Staff CSS|On track|ok|pub|0',
    'XXX XXX OI 48-2|Hearing Tests|Review|9 Answers|4|XXX XXX AO 6|On track|ok|pub|0',
    'XXX XXX OI 32-1|Work Orders|Review|5 Scope|5|XXX XXX AO 5|On track|ok|pub|0',
    'XXX XXX OI 91-3|Ladder Safety|New|7 Endorsers|6|XXX XXX AO 7|On track|ok|pub|0'
  ) -join "`n")
# Turns the "|" lines of the Your Work grid into row tables (Publication keeps "number|title" for the two-part cell).
function ConvertTo-HomeRow([string[]]$Lines) {
  foreach ($l in $Lines) {
    if ($l.Trim()) {
      $f = $l.Split('|')
      @{ Publication = ($f[0] + '|' + $f[1]); Action = $f[2]; Step = $f[3]; With = $f[4]; Since = $f[5]; Age = $f[6]; Due = $f[7]
        Status = $f[8]; Kind = $f[9]; Go = $f[10] }
    }
  }
}
# Turns the "|" lines of the All Actions grid into row tables; Me is true for a row that needs you.
function ConvertTo-QueueRow([string[]]$Lines) {
  foreach ($l in $Lines) {
    if ($l.Trim()) {
      $f = $l.Split('|')
      @{ Publication = ($f[0] + '|' + $f[1]); Action = $f[2]; Step = $f[3]; Weekdays = $f[4]; With = $f[5]; Status = $f[6]
        Kind = $f[7]; Go = $f[8]; Me = ($f[9] -eq '1') }
    }
  }
}
$GridHome = @(ConvertTo-HomeRow ($HomeRows -split "`n"))
$GridQueue = @(ConvertTo-QueueRow ($QueueRows -split "`n"))
# Grid columns: N = name, W = width at 100 % (0 = takes the rest; at most: R11 a short column is as wide as its values), K = how the cell is
# drawn, H = header text when not N, HW = the head may wrap to 2 lines (R11), Drop = leaves when the heads do not fit (R11; PFM 20 Nov 26).
$ColsNarrow = @(@{ N = 'Publication'; W = 0; K = 'pub' }, @{ N = 'Step'; W = 128; K = 'plain' }, @{ N = 'With'; W = 170; K = 'with' },
  @{ N = 'Since'; W = 64; K = 'since'; Drop = $true }, @{ N = 'Due'; W = 72; K = 'plain' }, @{ N = 'Status'; W = 104; K = 'chip' })
$ColsWide = @(@{ N = 'Publication'; W = 0; K = 'pub' }, @{ N = 'Action'; W = 136; K = 'plain' }, @{ N = 'Step'; W = 136; K = 'plain' },
  @{ N = 'With'; W = 184; K = 'with' }, @{ N = 'Since'; W = 120; K = 'since' }, @{ N = 'Due'; W = 72; K = 'plain' },
  @{ N = 'Status'; W = 104; K = 'chip' })
$ColsQueue = @(@{ N = 'Publication'; W = 0; K = 'pub' }, @{ N = 'Action'; W = 130; K = 'plain' }, @{ N = 'Step'; W = 150; K = 'plain' },
  @{ N = 'Weekdays'; W = 86; K = 'plain'; H = 'Weekdays in step'; HW = $true }, @{ N = 'With'; W = 140; K = 'with' }, @{ N = 'Status'; W = 124; K = 'chip' })
# The Action Status card at the right of a step card. Takes one table: Title, Sub, Note (a gray box; may be empty),
# Rows (label, value, chip kind) and Buttons. Stretch: its bottom lines up with the main card's bottom (R30 V4).
function Get-SideStatus($S) {
  $b = @(@{ T = 'head'; Text = $S.Title; Small = $true }, @{ T = 'p'; Text = $S.Sub; Style = 'note' })
  if ($S.Note) { $b += @{ T = 'p'; Text = $S.Note; Style = 'box' } }
  if ($S.Rows) { $b += @{ T = 'rows'; Rows = $S.Rows } }
  if ($S.Buttons) { $b += @{ T = 'buttons'; Items = $S.Buttons } }
  return @{ Cap = 'Action Status'; Pad = 22; Stretch = $true; Blocks = $b }
}
# True when a check or box block shows its link. A format check with 0 findings has nothing to open, so no link (R30 V3).
function Test-CheckLink($Block) {
  return [bool]($Block.Link -and -not ($null -ne $Block.Findings -and [int]$Block.Findings -eq 0))
}
$FullHistory = @(@{ Text = 'Full History'; Note = 'FAKE: the history of this action opens here. Nothing is read.' })
$OneOf = "XXX XXX OI 33-101, Key Control"
# The checks of the check bar, in order. R12 (R39; PFM 20 Nov 26): the Your Work grid (R38 finding 2), the Sofia Sans
# fonts (docs/phases.md R39), the text box height (R38 finding 2, B1) and the speed of the cards (R38 finding 3). The
# card to open is named in each text. -Again (the second run of the round): one check, that the window reopened on the
# card it was closed on (R13: Get-AgainText names that card). $ChecksDone is the bar text when all are answered; R13
# (R39 finding 1): it names no card, so the card the person closes the window on is the one the -Again check names.
$Checks = @(
  @{ Key = 'home-all'; Text = 'Select Your Work in the list on the left. Pass if no status chip touches the scroll bar and each name shows whole.' },
  @{ Key = 'font'; Text = 'Look at the RADE window behind this one. Pass if the titles and text here use the same fonts as the RADE window.' },
  @{ Key = 'box'; Text = 'Select All Actions in the list on the left. Pass if the text box "Find a publication" is not cut at the top or bottom.' },
  @{ Key = 'speed'; Text = 'Select each item in the list on the left once. Pass if each screen opens with no delay that you notice.' }
)
$script:ChecksDone = 'All checks done. Close this window with its X.'
if ($Again) { $Checks = @(@{ Key = 'reopen'; Text = '' }) }   # its text: Get-AgainText, after the cards (it reads their titles)
# The cards, in the order the window builds them. A card: Rail (the rail item it lights), Title and Sub or Crumb and
# CrumbGo, Up (the card Esc opens), Side (the right column width at 100 %), Modal, and Cols: columns of sections, each
# section a list of Blocks (T = the block type; the window module builds each type).
$Cards = [ordered]@{}
$Cards.home = @{ Rail = 'work'; Title = 'Your Work'; Sub = "Tuesday, 17 Nov 26 $mid 2 items need you $mid 2 offices late"; Side = 300
  Cols = @(
    @(@{ Cap = 'Needs You Today'; Top = 'primary'; Blocks = @(@{ T = 'list'; Rows = @(
              @{ Chip = @('turn', 'Due 18 Nov 26'); Title = 'Review and start endorsement'; Sub = "XXX XXX OI 33-101, Key Control $mid step 8 of 12"
                Btn = @{ Text = 'Open'; Kind = 'primary'; Go = 'step8' } },
              @{ Chip = @('turn', 'Due 20 Nov 26'); Title = 'Build the final copy, then send for signatures'; Sub = "XXX XXX OI 21-14, Vehicle Keys $mid step 11 of 12"
                Btn = @{ Text = 'Open'; Go = 'step11' } },
              @{ Chip = @('late', '2 late'); Title = 'Chase 2 late offices'; Sub = "Wave answers past due $mid last contact shown on the right"
                Btn = @{ Text = 'Remind All Late'; Go = 'remindall' } }) }) },
      @{ Cap = "Who Has It Now $mid 15 open actions"; Grow = $true; Blocks = @(
          @{ T = 'p'; Text = "Since: when it reached that person $mid d: business days $mid dates in 2026"; Style = 'note' },
          @{ T = 'grid'; Name = 'Who has it now'; Rows = $GridHome; Cols = $ColsNarrow; ColsWide = $ColsWide; Fill = $true }) }),
    @(@{ Cap = "Chase $mid late and due soon"; Pad = 16; Blocks = @(
          @{ T = 'p'; Text = 'Each reminder is logged as a contact: the good-faith record (DAFMAN 90-161, 5.4.3.1).'; Style = 'note' },
          @{ T = 'list'; Narrow = $true; Rows = @(
              @{ Title = 'XXX XXX Office 5'; Sub = "XXX XXX Instruction 10-201 $mid Wave 1"; Detail = "Due 13 Nov 26 (2 days late) $mid last contact: 14 Nov 26 $mid contacts: 1"
                Btn = @{ Text = 'Remind'; Note = 'FAKE: a reminder to XXX XXX Office 5 is logged as a contact. Nothing was sent.' } },
              @{ Title = 'XXX XXX Office 8'; Sub = "XXX XXX OI 31-3 $mid Wave 2"; Detail = "Due 16 Nov 26 (1 day late) $mid last contact: never $mid contacts: 0"
                Btn = @{ Text = 'Remind'; Note = 'FAKE: a reminder to XXX XXX Office 8 is logged as a contact. Nothing was sent.' } },
              @{ Title = 'XXX XXX Legal Office'; Sub = "XXX XXX OI 90-1 $mid Wave 3, legal $mid cannot be ""Concur, No Response"""
                Detail = "Due 19 Nov 26 (due in 2 days) $mid last contact: never $mid contacts: 0"
                Btn = @{ Text = 'Remind'; Note = 'FAKE: a reminder to the XXX XXX Legal Office is logged as a contact. Nothing was sent.' } },
              @{ Title = 'XXX XXX Offices 2 and 4'; Sub = "XXX XXX OI 36-2 $mid Wave 1"; Detail = "Due 20 Nov 26 (due in 3 days) $mid last contact: never $mid contacts: 0"
                Btn = @{ Text = 'Remind'; Note = 'FAKE: a reminder to XXX XXX Offices 2 and 4 is logged as a contact. Nothing was sent.' } }) }) },
      @{ Cap = "Selected $mid XXX XXX Instruction 10-201"; Pad = 16; WideOnly = $true; Blocks = @(
          @{ T = 'rows'; Rows = @(@('Wave 1 (3 offices)', '2 of 3 answered', 'soon'), @('Wave 2 (5 mandatory)', 'Waiting', 'neu'),
              @('Wave 3, legal', 'Waiting', 'neu'), @('Contacts with XXX XXX Office 5', "1 $mid 14 Nov 26 0900", '')) },
          @{ T = 'buttons'; Items = @(@{ Text = 'Open the Action'; Go = 'waves' }, @{ Text = 'Change or Skip'; Go = 'step13' }) }) })) }
$Cards.empty = @{ Rail = 'work'; Title = 'Your Work'; Sub = "Tuesday, 17 Nov 26 $mid 0 items need you"; Side = 300; Up = 'settings'
  Cols = @(
    @(@{ Cap = 'Needs You Today'; Top = 'primary'; Blocks = @(
          @{ T = 'chips'; Items = @(, @('ok', 'All clear')) },
          @{ T = 'head'; Text = 'Nothing needs you today. The next due date is 19 Nov 26.'; Small = $true },
          @{ T = 'buttons'; Items = @(@{ Text = 'Open All Actions'; Kind = 'primary'; Go = 'queue' }) }) },
      @{ Cap = "Who Has It Now $mid 9 open actions"; Grow = $true; Blocks = @(
          @{ T = 'p'; Text = "Since: when it reached that person $mid d: business days $mid dates in 2026"; Style = 'note' },
          @{ T = 'grid'; Name = 'Who has it now'; Rows = @($GridHome | Where-Object { $_.Kind -eq 'ok' }); Cols = $ColsNarrow; ColsWide = $ColsWide
            Fill = $true }) }),
    @(@{ Cap = "Chase $mid late and due soon"; Pad = 16; Blocks = @(
          @{ T = 'p'; Text = 'Each reminder is logged as a contact: the good-faith record (DAFMAN 90-161, 5.4.3.1).'; Style = 'note' },
          @{ T = 'p'; Text = 'No office is late or due in the next 3 business days.' }) })) }
$Cards.queue = @{ Rail = 'queue'; Title = 'All Actions'; Sub = "Twelve open actions $mid two need you $mid one office has not answered"; Up = 'home'
  Cols = @(, @(@{ Cap = 'All Actions'; Grow = $true; Blocks = @(
          @{ T = 'filter' },
          @{ T = 'grid'; Name = 'All actions'; Rows = $GridQueue; Cols = $ColsQueue; Fill = $true; Count = 'Showing {0} of 12 actions, sorted by status, then due date' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Open the Action'; Kind = 'primary'; Go = '@grid' }) }) }))
}
$Cards.reviews = @{ Rail = 'reviews'; Crumb = "Step 1 of 12 $mid a publication is due for review (DAFMAN 90-161, 7.4.2, 7.4.4)"; Title = 'Reviews Due'
  Sub = 'Three publications reach their review in the next 6 months, or must be reviewed now'; Up = 'home'
  Cols = @(, @(@{ Cap = 'Reviews Due'; Blocks = @(
          @{ T = 'list'; Rows = @(
              @{ Title = 'XXX XXX OI 13-9, Fuel Handling'; Sub = "E-mail goes to XXX XXX Office 3 box $mid review due 2 Feb 27 $mid 4-year review"
                Btn = @{ Text = 'Start Review'; Kind = 'primary'; Note = 'FAKE: the review starts and one e-mail goes to the XXX XXX Office 3 box (step 2). Nothing was sent.' } },
              @{ Title = 'XXX XXX OI 21-6, Tool Control'; Sub = "E-mail goes to XXX XXX Office 7 box $mid review due 9 Mar 27 $mid 4-year review"
                Btn = @{ Text = 'Start Review'; Note = 'FAKE: the review starts and one e-mail goes to the XXX XXX Office 7 box (step 2). Nothing was sent.' } },
              @{ Title = 'XXX XXX OI 32-1, Work Orders'; Sub = "E-mail goes to XXX XXX Office 2 box $mid review due now $mid higher headquarters changed its publication"
                Btn = @{ Text = 'Start Review'; Note = 'FAKE: the review starts and one e-mail goes to the XXX XXX Office 2 box (step 2). Nothing was sent.' } }) },
          @{ T = 'p'; Style = 'note'; Text = ('Start Review sends one e-mail to the OPR''s organization box (step 2). A person from the box names one or two ' +
              'action officers (step 3). The 6-month notice starts by itself; this list lets you start one early.') },
          @{ T = 'ck'; Id = 'ck1'; Text = 'Ask for a full review, not only "certify current" (for XXX XXX OI 32-1: higher headquarters changed its publication)' }) }))
}
$Cards.step8 = @{ Rail = 'work'; Crumb = "Your Work $gt XXX XXX OI 33-101"; CrumbGo = 'home'; Up = 'home'; Side = 360
  Cols = @(
    @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(@('turn', 'YOUR TURN'), @('soon', 'Due 18 Nov 26')); Cap = "STEP 8 OF 12 $mid PFM AND PRIVACY MONITOR" },
          @{ T = 'head'; Text = 'Is the draft of XXX XXX OI 33-101 ready for endorsement?' },
          @{ T = 'steps'; N = 8 },
          @{ T = 'check'; Chip = 'Passed'; Text = 'The format check ran in draft mode, 17 Nov 26 0914.'; Findings = 0
            Link = @{ Text = 'See the 0 findings'; Note = 'FAKE: the format findings open here. There are none.' } },
          @{ T = 'ck'; Id = 'ck1'; Text = 'I read the draft. It is ready for the offices.'
            Link = @{ Text = 'Open the draft in Word for the web'; Note = 'FAKE: the draft opens in Word for the web. Nothing is opened.' } },
          @{ T = 'ck'; Id = 'ck2'; Text = 'As the privacy monitor, I reviewed the draft for personal information (DAFMAN 90-161, 2.8.1).' },
          @{ T = 'err'; Key = 'ck'; Text = 'Select both boxes first. The format check and the privacy review are your record.' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Start Endorsement'; Kind = 'primary'; Go = 'confirm'; Need = 'ck' }, @{ Text = 'Send Back to the AO'; Go = 'sendback' },
              @{ Text = 'Change or Skip'; Go = 'step13' }) },
          @{ T = 'p'; Text = 'Start Endorsement asks you to confirm first. Send Back asks for your reason; the AO gets it by e-mail.'; Style = 'note' }) }),
    @((Get-SideStatus @{ Title = $OneOf; Sub = "Review $mid step 8 of 12 $mid with you since 16 Nov 26"; Buttons = $FullHistory
          Note = 'Start sends wave 1 to three offices. Due 9 Dec 26: 15 business days, Thanksgiving not counted (DAFMAN 90-161, 5.2).'
          Rows = @(@('Wave 1: offices the AO added', '3 named', 'neu'), @('Wave 2: mandatory offices', '5 named', 'neu'), @('Wave 3: legal, last', '1 named', 'neu'),
            @('AO', 'XXX XXX AO 1', ''), @('Feedback from readers', '2 people, 28 Oct 26', '')) }))) }
$Cards.confirm = @{ Rail = 'work'; Crumb = "Your Work $gt XXX XXX OI 33-101 $gt Confirm"; CrumbGo = 'step8'; Up = 'step8'
  Cols = @(, @(@{ Top = 'primary'; Blocks = @(
          @{ T = 'chips'; Items = @(, @('soon', 'Confirm')); Cap = "STEP 8 OF 12 $mid START ENDORSEMENT" },
          @{ T = 'head'; Text = 'Start endorsement of XXX XXX OI 33-101?' },
          @{ T = 'p'; Text = 'Three offices get an e-mail now. Due 9 Dec 26.'; Style = 'body' },
          @{ T = 'rows'; Rows = @(@('Wave 1 offices', 'XXX XXX Office 1, XXX XXX Office 2, XXX XXX Office 3', ''), @('Due', '9 Dec 26 (15 business days)', ''),
              @('Waves 2 and 3', 'Open by themselves, in order', '')) },
          @{ T = 'buttons'; Items = @(@{ Text = 'Start Endorsement'; Kind = 'primary'; Go = 'waves'; Note = 'FAKE: endorsement started. Nothing was sent.' },
              @{ Text = 'Cancel'; Go = 'step8' }) }) }))
}
$Cards.sendback = @{ Rail = 'work'; Crumb = "Your Work $gt XXX XXX OI 33-101 $gt Send back"; CrumbGo = 'home'; Modal = $true; Up = 'back'
  Cols = @(, @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(, @('turn', 'YOUR TURN')); Cap = 'SEND BACK TO THE AO' },
          @{ T = 'head'; Text = 'Send XXX XXX OI 33-101 back to the AO?' },
          @{ T = 'p'; Text = 'The AO gets your reason by e-mail. The action goes back to the draft step.'; Style = 'body' },
          @{ T = 'input'; Id = 'reason'; Label = 'Your reason (required)'; Multi = $true },
          @{ T = 'err'; Key = 'reason'; Text = 'The reason box is empty. Type your reason, then select Send Back.' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Send Back'; Kind = 'primary'; Go = 'home'; Need = 'reason'
                Note = 'FAKE: the action went back to the AO with your reason. Nothing was sent.' }, @{ Text = 'Cancel'; Go = 'back' }) }) }))
}
$Cards.waves = @{ Rail = 'work'; Crumb = "All Actions $gt XXX XXX Instruction 10-201"; CrumbGo = 'queue'; Up = 'queue'; Side = 360
  Cols = @(
    @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(, @('late', '1 office has not answered')); Cap = "STEPS 9 AND 10 $mid ENDORSEMENT" },
          @{ T = 'head'; Text = 'Wave 1: two of three offices have answered.' },
          @{ T = 'steps'; N = 10 },
          @{ T = 'grid'; Name = 'Wave 1 answers'; Rows = @(
              @{ Office = 'XXX XXX Office 1'; Answer = 'Concur'; Comments = '0'; Signature = '//SIGNED// 9 Nov 26'; Status = 'Answered'; Kind = 'ok'; Go = '' },
              @{ Office = 'XXX XXX Office 2'; Answer = 'Concur With Comment'; Comments = '3'; Signature = '//SIGNED// 13 Nov 26'; Status = 'Answered'; Kind = 'ok'; Go = '' },
              @{ Office = 'XXX XXX Office 5'; Answer = 'No answer yet'; Comments = '-'; Signature = '-'; Status = 'Due 25 Nov 26'; Kind = 'late'; Go = '' })
            Cols = @(@{ N = 'Office'; W = 0; K = 'bold' }, @{ N = 'Answer'; W = 150; K = 'plain' }, @{ N = 'Comments'; W = 80; K = 'plain' },
              @{ N = 'Signature'; W = 150; K = 'plain' }, @{ N = 'Status'; W = 120; K = 'chip' }) },
          @{ T = 'buttons'; Items = @(@{ Text = 'Remind XXX XXX Office 5'; Kind = 'primary'; Note = 'FAKE: a reminder to XXX XXX Office 5 is logged as a contact. Nothing was sent.' },
              @{ Text = 'Open the Comment Table'; Note = 'FAKE: the comment table opens here.' }, @{ Text = 'Change or Skip'; Go = 'step13' }) },
          @{ T = 'p'; Style = 'note'; Text = ('After the due date the AO may record "Concur, No Response" with a reason; never for legal (DAFMAN 90-161, 5.4.3.2). ' +
              'You can skip an office at any time, with a reason (step 13).') }) }),
    @((Get-SideStatus @{ Title = 'XXX XXX Instruction 10-201, Recall'; Sub = "Rewrite $mid step 10 of 12 $mid wave 1 of 3"; Buttons = $FullHistory
          Note = 'Wave 2 opens by itself when every wave 1 office has answered (PFM, 16 Nov 26).'
          Rows = @(@('Wave 1: offices the AO added', '2 of 3', 'soon'), @('Wave 2: mandatory offices', 'Waiting', 'neu'), @('Wave 3: legal, last', 'Waiting', 'neu'),
            @('Comments to decide (AO)', '3 open', ''), @('Open nonconcurs', '0', '')) }))) }
$Cards.step11 = @{ Rail = 'work'; Crumb = "Your Work $gt XXX XXX OI 21-14"; CrumbGo = 'home'; Up = 'home'; Side = 360
  Cols = @(
    @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(@('turn', 'YOUR TURN'), @('soon', 'Due 20 Nov 26')); Cap = "STEP 11 OF 12 $mid SIGNATURES" },
          @{ T = 'head'; Text = 'Build the final copy of XXX XXX OI 21-14, then send it for signatures.' },
          @{ T = 'steps'; N = 11 },
          @{ T = 'rows'; Rows = @(
              @('Final copy. Built from the format rules, with the seal and the page count.', 'Not built yet.', 'soon'),
              @('Certifier signs the DAF Form 673 (DAFMAN 90-161, 5.6).', 'Waits for the final copy.', 'neu'),
              @('Approver signs after the certifier (5.7).', 'Waits for the certifier.', 'neu')) },
          @{ T = 'buttons'; Items = @(@{ Text = 'Build the Final Copy'; Kind = 'primary'; Note = 'FAKE: the final copy is built. Nothing was made.' },
              @{ Text = 'Send Back to the AO'; Go = 'sendback' }, @{ Text = 'Change or Skip'; Go = 'step13' }) },
          @{ T = 'p'; Text = 'When the final copy is built, the main button becomes "Send to the Certifier".'; Style = 'note' }) }),
    @((Get-SideStatus @{ Title = 'XXX XXX OI 21-14, Vehicle Keys'; Sub = "Review $mid step 11 of 12 $mid every endorser answered"; Buttons = $FullHistory
          Note = 'Officials get no e-mail. The task goes to the CSS box of each official (PFM, 16 Nov 26).'
          Rows = @(@('Open nonconcurs (5.5)', '0', ''), @('Certifies', 'XXX XXX Group Commander', ''), @('Certifier''s CSS box', 'XXX XXX Group CSS', ''),
            @('Approves', 'XXX XXX Wing Commander', ''), @('Approver''s CSS box', 'XXX XXX Wing Staff CSS', '')) }))) }
$Cards.step12 = @{ Rail = 'work'; Crumb = "Your Work $gt XXX XXX OI 21-14"; CrumbGo = 'home'; Up = 'home'
  Cols = @(, @(@{ Top = 'primary'; Blocks = @(
          @{ T = 'chips'; Items = @(, @('ok', 'PUBLISHED')); Cap = 'STEP 12 OF 12' },
          @{ T = 'head'; Text = 'XXX XXX OI 21-14 is published.' },
          @{ T = 'steps'; N = 12 },
          @{ T = 'rows'; Rows = @(@('Approver signed', '17 Nov 26 1342', ''), @('Posted on the wing site', '17 Nov 26 1343', ''), @('Publication list updated', '17 Nov 26 1343', ''),
              @('AO asked for related e-mail', 'Waiting', 'soon'), @('Next review due', '17 Nov 30', '')) },
          @{ T = 'buttons'; Items = @(@{ Text = 'Open the Publication'; Kind = 'primary'; Go = 'pub' }, @{ Text = 'Back to Your Work'; Go = 'home' }) }) }))
}
$Cards.step13 = @{ Rail = 'work'; Crumb = "XXX XXX Instruction 10-201 $gt Change or skip"; CrumbGo = 'back'; Modal = $true; Up = 'back'; Side = 360
  Cols = @(
    @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(, @('neu', 'ANY TIME')); Cap = 'STEP 13' },
          @{ T = 'head'; Text = 'Change who does this step, or skip them.' },
          @{ T = 'rows'; Rows = @(, @('Step', "Step 10 $mid wave 1 $mid XXX XXX Office 5", '')) },
          @{ T = 'radio'; Id = 'radio'; Label = 'What do you want to do?'; Items = @('Give the step to another person or office', 'Skip XXX XXX Office 5 for this action') },
          @{ T = 'input'; Id = 'reason'; Label = 'Your reason (required)'; Multi = $true },
          @{ T = 'err'; Key = 'reason'; Text = 'The reason box is empty. Type your reason, then select Save Change.' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Save Change'; Kind = 'primary'; Go = 'back'; Need = 'reason'
                Note = 'FAKE: the change is logged with your name, the date and your reason. Nothing was saved.' }, @{ Text = 'Cancel'; Go = 'back' }) },
          @{ T = 'p'; Text = 'Legal cannot be marked "Concur, No Response" (DAFMAN 90-161, 5.4.3.2).'; Style = 'note' }) }),
    @((Get-SideStatus @{ Title = 'XXX XXX Instruction 10-201, Recall'; Sub = "Rewrite $mid step 10 of 12 $mid wave 1 of 3"; Buttons = $FullHistory
          Note = 'Every change is logged with your name, the date and your reason. Others on the action see the change.'
          Rows = @(@('Changes on this action', '0', ''), @('XXX XXX Office 5', "Wave 1 $mid no answer", ''), @('Due', '25 Nov 26', '')) }))) }
$Cards.pub = @{ Rail = 'pub'; Title = 'Publications'; Sub = 'Find a publication, read it, see its details'; Up = 'home'; Side = 360
  Cols = @(
    @(@{ Blocks = @(
          @{ T = 'input'; Id = 'find'; Label = 'Find a publication' },
          @{ T = 'head'; Text = $OneOf; Small = $true },
          @{ T = 'p'; Text = 'Summary'; Style = 'cap' },
          @{ T = 'p'; Style = 'body'; Text = 'This FAKE instruction sets how offices issue and count vehicle keys. It names who keeps the key log and how often keys are counted.' },
          @{ T = 'p'; Text = 'Written at the format pass (step 8); the PFM can edit it.'; Style = 'note' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Open the PDF'; Kind = 'primary'; Note = 'FAKE: the PDF opens here. Nothing is opened.' },
              @{ Text = 'Copy the Text'; Note = 'FAKE: the text is copied. Nothing was copied.' }, @{ Text = 'Start a Change'; Note = 'FAKE: a change starts here. Nothing was started.' }) },
          @{ T = 'p'; Text = 'Paragraphs'; Style = 'cap' },
          @{ T = 'rows'; Rows = @(@('1. Purpose', 'page 1', ''), @('2. Key control', 'page 1', ''), @('3. Key count', 'page 2', '')) }) }),
    @((Get-SideStatus @{ Title = $OneOf; Sub = "In review $mid step 8 of 12"; Note = 'Open action: review, started 1 Oct 26.'
          Rows = @(@('OPR', 'XXX XXX Office 6', ''), @('Effective', '2 Feb 23', ''), @('Next review due', '2 Feb 27', ''), @('Prescribed forms', 'XXX XXX Form 12', ''),
            @('Applies to', 'Wing', ''))
          Buttons = @(@{ Text = 'Open the Record'; Go = 'step8' }) }))) }
$Cards.settings = @{ Rail = 'settings'; Title = 'Settings'; Sub = 'Who runs the process, and how each screen looks when there is nothing to show'; Up = 'home'
  Cols = @(, @(
      @{ Cap = 'Settings'; Blocks = @(
          @{ T = 'rows'; Rows = @(@('PFM', 'XXX XXX PFM', ''), @('Alternate PFM', 'XXX XXX Alternate', ''), @('Flows', 'Running', 'ok'), @('Test mode', 'Off', 'neu')) },
          @{ T = 'buttons'; Items = @(@{ Text = 'Change Settings'; Kind = 'primary'; Note = 'FAKE: the settings open here. Nothing was changed.' }) }) },
      @{ Cap = 'Look at the other states'; Blocks = @(
          @{ T = 'p'; Text = 'Each button shows one card, with FAKE data.'; Style = 'note' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Nothing Needs You'; Go = 'empty' }, @{ Text = 'Loading'; Go = 'loading' }, @{ Text = 'Failed'; Go = 'failed' },
              @{ Text = 'No Permission'; Go = 'noperm' }) }) })) }
$Cards.loading = @{ Rail = 'work'; Title = 'Loading'; Up = 'settings'
  Cols = @(, @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(, @('neu', 'LOADING')) },
          @{ T = 'head'; Text = 'Reading your site.' },
          @{ T = 'p'; Text = 'Twelve lists. This takes about 10 seconds.'; Style = 'body' },
          @{ T = 'progress'; Value = 5; Max = 12; Text = '5 of 12 lists read' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Back to Your Work'; Kind = 'primary'; Go = 'home' }) }) }))
}
$Cards.failed = @{ Rail = 'work'; Title = 'Failed'; Up = 'settings'
  Cols = @(, @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(, @('late', 'FAILED')) },
          @{ T = 'head'; Text = 'The site did not answer.' },
          @{ T = 'p'; Text = 'Your sign-in may have ended. Select Try Again; the window asks you to sign in.'; Style = 'body' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Try Again'; Kind = 'primary'; Go = 'loading' }, @{ Text = 'Copy Details'; Note = 'FAKE: the details are copied. Nothing was copied.' }) }) }))
}
$Cards.noperm = @{ Rail = 'work'; Title = 'No permission'; Up = 'settings'
  Cols = @(, @(@{ Blocks = @(
          @{ T = 'chips'; Items = @(, @('amber', 'NO PERMISSION')) },
          @{ T = 'head'; Text = 'You cannot open the PFM lists.' },
          @{ T = 'p'; Text = 'This window is for the PFM office. Ask the site owner to add you to the PFM Office group.'; Style = 'body' },
          @{ T = 'buttons'; Items = @(@{ Text = 'Copy My Request'; Kind = 'primary'; Note = 'FAKE: your request is copied. Nothing was copied.' }) }) }))
}
$Cards.remindall = @{ Rail = 'work'; Crumb = "Your Work $gt Remind all late offices"; CrumbGo = 'home'; Up = 'home'
  Cols = @(, @(@{ Top = 'primary'; Blocks = @(
          @{ T = 'chips'; Items = @(@('late', '2 late'), @('soon', 'Confirm')); Cap = 'CHASE' },
          @{ T = 'head'; Text = 'Remind the 2 late offices now?' },
          @{ T = 'p'; Text = 'Each office gets one e-mail now. Each contact is logged: the good-faith record (DAFMAN 90-161, 5.4.3.1).'; Style = 'body' },
          @{ T = 'rows'; Rows = @(@('XXX XXX Office 5', "XXX XXX Instruction 10-201 $mid 2 days late", ''), @('XXX XXX Office 8', "XXX XXX OI 31-3 $mid 1 day late", '')) },
          @{ T = 'buttons'; Items = @(@{ Text = 'Remind Both Offices'; Kind = 'primary'; Go = 'home'; Note = 'FAKE: 2 reminders are logged as contacts. Nothing was sent.' },
              @{ Text = 'Cancel'; Go = 'home' }) }) }))
}
# R13 (R40): the name of card $Key as its head shows it: its title, else the last part of its crumb ('' for no card).
function Get-CardName([string]$Key) {
  $c = $Cards[$Key]; if (-not $c) { return '' }
  if ($c.Title) { return [string]$c.Title }
  return [string]@(([string]$c.Crumb) -split [regex]::Escape(' ' + $gt + ' '))[-1]
}
<#
.SYNOPSIS
R13 (R40; R39 finding 1): the text of the -Again check, which names the card saved at the last close.
.DESCRIPTION
The window opens on the card saved at the last close ($wn.OpenLast in the window part), so the check names that card
by its title: "Pass if this window opened on Settings, the screen you closed it on." With no saved card, or one the
window does not open (unknown or modal), the window opens on Your Work and the check says that no screen was saved.
.PARAMETER Key
The card key read from the saved-card file, or '' when there is none.
.OUTPUTS
System.String. The check text.
#>
function Get-AgainText([string]$Key) {
  $name = $(if ($Key -and $Cards[$Key] -and -not $Cards[$Key].Modal) { Get-CardName $Key } else { '' })
  if ($name) { return ('Pass if this window opened on ' + $name + ', the screen you closed it on.') }
  return 'No screen was saved when this window last closed. Select Fail.'
}
if ($Again) { $Checks[0].Text = Get-AgainText '' }   # until the main script has read the saved card (-PlanOnly reads none)
# The rail items, top to bottom (Ctrl+1 to Ctrl+5 open them in this order).
$RailItems = @(@{ Key = 'work'; Text = 'Your Work'; Go = 'home'; Badge = '3' }, @{ Key = 'queue'; Text = 'All Actions'; Go = 'queue' },
  @{ Key = 'pub'; Text = 'Publications'; Go = 'pub' }, @{ Key = 'reviews'; Text = 'Reviews Due'; Go = 'reviews' }, @{ Key = 'settings'; Text = 'Settings'; Go = 'settings' })
# Plain-text form of a line for -PlanOnly: the dot and the arrow become | and > (the output stays ASCII).
function ConvertTo-PlanText([string]$Text) {
  return ($Text.Replace($mid, '|').Replace($gt, '>'))
}
# The text form of one button for -PlanOnly: its text, "(blue)" for the main button, where it goes, what it needs.
function Get-ButtonPlan($Button) {
  return ('    BUTTON ' + $Button.Text + $(if ($Button.Kind -eq 'primary') { ' (blue)' } else { '' }) + ' -> ' +
    $(if ($Button.Go) { $Button.Go } else { '@note' }) + $(if ($Button.Need) { ' [needs ' + $Button.Need + ']' } else { '' }))
}
<#
.SYNOPSIS
Gives the -PlanOnly lines of one block of a card.
.DESCRIPTION
One or more lines per block type, the same words the window shows: chips, headline, text, steps, checks and boxes with
their links, rows, list items with their buttons, grid rows that open a card, boxes, choices, error, progress, buttons.
.PARAMETER Block
The block table (T = its type).
.OUTPUTS
The lines, not yet made plain (ConvertTo-PlanText runs on each).
#>
function Get-BlockPlan($Block) {
  $b = $Block
  switch ($b.T) {
    'chips' { '    CHIPS ' + (@($b.Items | ForEach-Object { $_[1] }) -join ', ') + $(if ($b.Cap) { ' | ' + $b.Cap } else { '' }) }
    'head' { '    HEAD ' + $b.Text }
    'p' { '    P ' + $b.Text }
    'steps' { '    STEPS ' + $b.N + ' of 12 (12 dots) | ' + $StepNames[$b.N - 1] }
    'check' { '    CHECK ' + $b.Text; if (Test-CheckLink $b) { '    LINK ' + $b.Link.Text + $(if ($b.Link.Go) { ' -> ' + $b.Link.Go } else { ' -> @note' }) } }
    'ck' { '    BOX ' + $b.Text; if (Test-CheckLink $b) { '    LINK ' + $b.Link.Text + ' -> @note' } }
    'rows' { foreach ($r in @($b.Rows)) { '    ROW ' + $r[0] + ': ' + $r[1] } }
    'list' { foreach ($r in @($b.Rows)) { '    ITEM ' + $r.Title + ' | ' + $r.Sub; if ($r.Btn) { Get-ButtonPlan @{ Text = $r.Btn.Text; Kind = $r.Btn.Kind; Go = $r.Btn.Go } } } }
    'grid' {
      '    GRID ' + $b.Name + ': ' + @($b.Cols).Count + ' columns, ' + @($b.Rows).Count + ' rows'
      foreach ($r in @($b.Rows)) { if ($r.Go) { '    CHOICE ' + $(if ($r.Publication) { $r.Publication } else { $r.Office }) + ' -> ' + $r.Go } } }
    'filter' { '    FILTER search and show list' }
    'input' { '    INPUT ' + $b.Label + ' (' + $b.Id + ')' }
    'radio' { '    CHOICES ' + $b.Label + ': ' + (@($b.Items) -join ' / ') }
    'err' { '    ERROR ' + $b.Text }
    'progress' { '    PROGRESS ' + $b.Text }
    'buttons' { foreach ($x in @($b.Items)) { Get-ButtonPlan $x } }
  }
}
<#
.SYNOPSIS
Gives the cards, their sections and blocks, and the rail as plain text lines (-PlanOnly; tests/run.sh reads them).
.DESCRIPTION
A CARD line per card (key, rail item, title or crumb), then SUB and CRUMB, a SECTION line per section and the block lines
of Get-BlockPlan, and at the end one RAIL line per rail item. Reads $Cards and $RailItems; changes nothing.
.OUTPUTS
An array of ASCII lines.
#>
function Get-CardPlan {
  $out = @()
  foreach ($k in $Cards.Keys) {
    $c = $Cards[$k]
    $head = $(if ($c.Title) { $c.Title } else { $c.Crumb })
    $out += (ConvertTo-PlanText ('CARD ' + $k + ' | ' + $c.Rail + ' | ' + $head))
    if ($c.Sub) { $out += (ConvertTo-PlanText ('  SUB ' + $c.Sub)) }
    if ($c.Crumb -and $c.Title) { $out += (ConvertTo-PlanText ('  CRUMB ' + $c.Crumb)) }
    foreach ($col in @($c.Cols)) {
      foreach ($s in @($col)) {
        $wide = $(if ($s.WideOnly) { ' [wide only]' } else { '' })   # R15: the click-through check skips these sections
        $out += (ConvertTo-PlanText ('  SECTION ' + $(if ($s.Cap) { $s.Cap } else { '-' }) + $wide))
        foreach ($b in @($s.Blocks)) { foreach ($l in @(Get-BlockPlan $b)) { $out += (ConvertTo-PlanText ([string]$l)) } }
      }
    }
  }
  foreach ($r in $RailItems) { $out += ('RAIL ' + $r.Text + ' -> ' + $r.Go) }
  return $out
}
# The checks as -PlanOnly lines: CHECK <n> <key>: <text> (tests/run.sh reads them).
function Get-CheckPlan {
  for ($i = 0; $i -lt $Checks.Count; $i++) { 'CHECK ' + ($i + 1) + ' ' + $Checks[$i].Key + ': ' + $Checks[$i].Text }
}
<#
.SYNOPSIS
R16 (R42 finding 3: WALK 13 step12 was answered "not opened"): the name of card $Key for a click-through step; the name of the
card, and, when another card has the same name, its step line before the dot ("step 12 of 12") so that a card that shows now
is not taken for the card of the step.
#>
function Get-WalkName([string]$Key) {
  $name = Get-CardName $Key
  $same = @($Cards.Keys | Where-Object { [string]$_ -ne $Key -and (Get-CardName ([string]$_)) -eq $name })
  if (-not $same.Count) { return $name }
  $cap = ''; foreach ($col in @($Cards[$Key].Cols)) { foreach ($sec in @($col)) { foreach ($b in @($sec.Blocks)) { if (-not $cap -and $b.T -eq 'chips' -and $b.Cap) { $cap = [string]$b.Cap } } } }
  if (-not $cap) { return $name }
  return ($name + ', ' + ([string]@($cap -split [regex]::Escape($mid))[0]).Trim().ToLowerInvariant()) }
<#
.SYNOPSIS
R14 (R41 plan row 3): how a person opens card $To from card $From with one selection that only opens a screen.
.DESCRIPTION
In this order: a rail item that opens $To (the rail shows on every card); a button of $From that goes to $To with
no need (R15, R41 finding 4: also a button with a FAKE note, such as "Start Endorsement" on Confirm: it is the real way to
the endorsement screen; a button that needs a reason or a box needs a second action); the crumb link of $From. Sections shown only in a wide window are left out, so the
opener is there at every window size. No opener: $null (the click-through then shows its own link "Open this screen").
.PARAMETER From
The card key the person is on ('' at the start: only the rail counts).
.PARAMETER To
The card key to open.
.OUTPUTS
@{ Via = 'rail', 'button' or 'link'; Text = what to select; Beside = the list row the button sits in, or '' }, or $null.
#>
function Get-WalkOpener([string]$From, [string]$To) {
  foreach ($r in $RailItems) { if ($r.Go -eq $To) { return @{ Via = 'rail'; Text = [string]$r.Text; Beside = '' } } }
  $c = $Cards[$From]; if (-not $c) { return $null }
  foreach ($col in @($c.Cols)) { foreach ($sec in @($col)) {
      if ($sec.WideOnly) { continue }
      foreach ($b in @($sec.Blocks)) {
        $btns = @(); if ($b.T -eq 'buttons') { $btns = @($b.Items | ForEach-Object { @{ B = $_; Beside = '' } }) }
        if ($b.T -eq 'list') { $btns = @($b.Rows | Where-Object { $_.Btn } | ForEach-Object { @{ B = $_.Btn; Beside = [string]$_.Title } }) }
        foreach ($x in $btns) { if ($x.B.Go -eq $To -and -not $x.B.Need) { return @{ Via = 'button'; Text = [string]$x.B.Text; Beside = $x.Beside } } } } } }
  if ($c.CrumbGo -eq $To) { return @{ Via = 'link'; Text = [string]@(([string]$c.Crumb) -split [regex]::Escape(' ' + $gt + ' '))[0]; Beside = '' } }
  return $null
}
# R17: the head line of the waves card, the first line of text above its grid. Takes nothing; returns the line.
function Get-WaveHead {
  foreach ($col in @($Cards.waves.Cols)) { foreach ($sec in @($col)) { foreach ($b in @($sec.Blocks)) { if ($b.T -eq 'head') { return [string]$b.Text } } } }
  return ''
}
<#
.SYNOPSIS
R14 (R41 plan row 3; PFM 20 Nov 26): the click-through, one step per card, every card once.
.DESCRIPTION
The order (the cards in the order the window builds them, $Cards): from the card the person is on, the next step is the
first card not yet walked that one rail item, button or crumb link opens (Get-WalkOpener); when no card has one, the
first card not yet walked, opened with the link "Open this screen" of the check bar. Each step is one action and one
Pass or Fail, in the words of the 4 checks. Pure data: no window.
.OUTPUTS
An array of @{ Key; Via (rail, button, link, open or, R16, look); Opener (what to select); Text (the bar text); From (R15: the card it starts on);
R18: Target, only on a step that names one part of the screen (the accessible name of its control; the bar frames it) }.
R16: Via look is the step after the waves card: it asks about the grid on the card the person is on.
R17 (R43 finding 3): the grid is named by the head line above it (Get-WaveHead), not by its accessible name.
.PARAMETER Only
r19: the card keys to walk (the round's walk, Get-RoundWalk); empty = every card.
#>
function Get-WalkPlan([string[]]$Only = @()) {
  # r19: with $Only, only those cards are walked (in the order of $Cards), from the card the window opens on.
  $left = New-Object System.Collections.Generic.List[string]; foreach ($k in $Cards.Keys) { if (-not $Only.Count -or $Only -contains [string]$k) { $left.Add([string]$k) } }
  $out = @(); $cur = ''; $n = $left.Count + $(if ($left.Contains('waves')) { 1 } else { 0 })   # R16: the waves card has one more step
  while ($left.Count) {
    $key = ''; $op = $null
    foreach ($k in $left) { $o = Get-WalkOpener $cur $k; if ($o) { $key = $k; $op = $o; break } }
    if (-not $key) { $key = $left[0]; $op = @{ Via = 'open'; Text = 'Open this screen'; Beside = '' } }
    [void]$left.Remove($key)
    $what = $(if ($op.Via -eq 'rail') { $op.Text + ' in the list on the left' } elseif ($op.Via -eq 'link') { 'the link "' + $op.Text + '" at the top' }
      elseif ($op.Beside) { '"' + $op.Text + '" beside "' + $op.Beside + '"' } elseif ($op.Via -eq 'open') { '"Open this screen" in this bar' } else { '"' + $op.Text + '"' })
    $text = 'Screen ' + ($out.Count + 1) + ' of ' + $n + ': select ' + $what + '. Pass if ' + (Get-WalkName $key) + ' opens and looks right.'
    $out += @{ Key = $key; Via = $op.Via; Opener = $op.Text; Text = $text; From = $cur }; $cur = $key
    # R16 (R42 finding 4; R43 T3): the step after the waves card asks about its grid, with its own Pass and Fail
    # R17 (R43 finding 3: the card shows no grid named "Wave 1 answers"): the step names the grid by the head line above it
    # R18 (the PFM, 26 Nov 26, R45 comment 6b): a step that names one part of the screen has Target, the accessible name of that
    # control; the bar draws a 2 px frame around it while the step shows (the bar part, $wn.FrameSet).
    if ($key -eq 'waves') { $head = Get-WaveHead; $out += @{ Key = $key; Via = 'look'; Opener = $head; From = 'waves'; Target = 'Wave 1 answers'
        Text = 'Screen ' + ($out.Count + 1) + ' of ' + $n + ': look at the grid under the line "' + $head + '" Pass if the grid shows the second person, or if no one helped.' } } }
  return $out
}
# r19 (the round skill, "Repeated tasks"; the PFM, 2026-11-26): the window walk opens only the screens that changed or failed
# since the last round that passed them, each with its reason. r21 (R48): R47 failed home and step12 (the PFM's notes: the
# pills not on the row's middle; the Waiting pill not in line with the dates); both changed since (R47 findings 2).
$WalkOnly = [ordered]@{ home = 'Why again: round 47 gave Fail; each pill is now on the middle of its row.'
  step12 = 'Why again: round 47 gave Fail; the pill now starts on the edge of the dates.' }
<#
.SYNOPSIS
r19: the click-through of this round: Get-WalkPlan for the cards of $WalkOnly only, each step text followed by the reason
that $WalkOnly gives for that card. Takes nothing.
.OUTPUTS
The steps, as Get-WalkPlan gives them.
#>
function Get-RoundWalk {
  $plan = @(Get-WalkPlan @($WalkOnly.Keys | ForEach-Object { [string]$_ }))
  foreach ($s in $plan) { if ($s.Via -ne 'look' -and $WalkOnly.Contains([string]$s.Key)) { $s.Text = [string]$s.Text + ' ' + [string]$WalkOnly[[string]$s.Key] } }
  return $plan
}
# The click-through as -PlanOnly lines (tests/run.sh reads them): WALK <n> <card> <via>: <text> for the steps this round
# walks, then (r19) WALKALL <n> <card> <via>: <text> for the whole plan of every card, which the path checks still read.
function Get-WalkPlanText {
  for ($i = 0; $i -lt $Walk.Count; $i++) { ConvertTo-PlanText ('WALK ' + ($i + 1) + ' ' + $Walk[$i].Key + ' ' + $Walk[$i].Via + ': ' + $Walk[$i].Text) }
  $all = @(Get-WalkPlan); for ($i = 0; $i -lt $all.Count; $i++) { ConvertTo-PlanText ('WALKALL ' + ($i + 1) + ' ' + $all[$i].Key + ' ' + $all[$i].Via + ': ' + $all[$i].Text) }
}
# R14: the click-through of this run; none with -Again (the second run of the round has its one reopen check only).
$Walk = @($(if ($Again) { @() } else { Get-RoundWalk }))   # r19: @() keeps a walk of one step an array
