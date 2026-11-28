# App screen map r1 (13 Nov 26)

Status: phase 4, step 1 (Administrator 25A, 13 Nov): every screen, who sees it, what it does, where its text comes from. Items marked **REC:** are open until the Administrator approves. Approved 13 Nov (26A-29A). Clickable previews at 375 and 1440 px, light and dark (25A; Administrator, 15 Nov: the 13 Nov "no previews" text is withdrawn). Colors stay provisional until go.md Task 12.

## 0. Target (Administrator, 16 Nov 26)

The screens follow the Administrator's 13 steps (docs/process-model.md "Target process"). Sections 3 to 6 below describe the 13 Nov map; they are cut to the cards in this table when the first preview of the 13 steps is approved. One card = one thing, in the RADE "One thing" design.

| Step | Card | Who |
|---|---|---|
| 3 | Name the AOs | A person from the OPR's box |
| 5 | Does it need further review?; Who signs (certifier, approver, CSS boxes) | AO |
| 6 | Share the draft; Read and leave feedback | AO; anyone invited |
| 7 | Add endorsers; Fill in the DAF Form 673 | AO |
| 8 | Ready for the Administrator; Start endorsement | AO; Administrator |
| 9 | Read the draft; Add a comment; Your answer; Decide a comment | Endorser; AO |
| 10 | Give this wave more time | AO |
| 11 | Ready for signatures; Attach the signed form | Administrator; CSS or the official |
| 12 | Add related e-mail | AO |
| 13 | Change or skip; Publication and forms (read, details, summary) | Administrator; anyone |

### PFM window cards and list forms (the 16 Nov 26 front-end split; Administrator preview 2, 17 Nov 26)

The Administrator works in the RADE-style window (scripts/gov/90161Z-T22-pfm-window-r2.ps1, FAKE data until the app rounds); everyone else works in SharePoint list forms opened from an e-mail link. The window holds only the Administrator's parts of the steps; steps 2 to 7 and the endorser, AO, certifier and approver parts of 9 to 12 stay list forms.

| Where | Cards or forms |
|---|---|
| PFM window, rail | Your Work (Needs You Today, Who Has It Now, Chase with Remind), All Actions, Publications, Reviews Due, Settings |
| PFM window, by step | 1 Reviews Due; 8 review and format, privacy record, Start Endorsement (with confirm); 9 and 10 waves, answers, silent endorser; 11 final copy, then certifier, then approver; 12 Published; 13 Change or Skip (reason required, logged) |
| PFM window, states | nothing needs you, loading, failed, no permission |
| SharePoint list forms | 2 to 7 (box told, name the AOs, scope, draft, endorsers); 9 and 10 for endorsers and AOs (read, comment, answer, decide, more time); 11 and 12 for officials, CSS boxes and AOs |

Every action card in the window has the 12-dot step bar and a Change or Skip button (step 13).

#### Window size (window r9, moved to R37 (Administrator 20 Nov 26); values shipped for judging: Administrator 19 Nov 26; 1200 px cap and 75-character measure: Administrator 19 Nov 26)

The Administrator asked for less dead space, sizing from the current screen, and one stable layout at any size (R35 findings 4 and 5, docs/reviews/2026-11-19-r35-results.md). Window r9 proposes the rules below; the values live in `$LayoutRevs` of scripts/gov/90161Z-T22-pfm-window-r9.ps1, and `-LayoutPlan` prints them for r8 and r9 at the 4 test sizes.

- One layout per window size, computed when a resize ends (or 250 ms after the last size change), from the size, the scale and the fonts only; a count, a date or a status never moves or resizes a control. tests/ps/Test-T22Sizes.ps1 checks this (each card shown again with other numbers) at 956 x 1081 at 150 %, 1920 x 1080 and 2560 x 1440 at 100 %, and 3840 x 2160 at 150 %.
- Padding and gaps scale with the font, about 20 % smaller than r8: page sides 28 to 22 px at 100 %, page top and bottom 22 to 16, column gap 18 to 16, card padding 24 x 18 to 20 x 14, gap under a card 14 to 12, check bar padding 16 to 12.
- The page is as wide as the window (r8 kept at least 900 px at 100 % and scrolled sideways on half a laptop). A side column takes 32 % of the page, at least 300 px (the narrowest side column of r8) and at most its card's own width; when the main column would be under 480 px at 100 %, the columns go one under the other. The rail is 176 px under a 1100 px window, 200 up to 1500, 220 from 1500. The smallest window is 600 x 480 at 100 %.
- A grid too narrow for all its columns hides, in this order: Weekdays, Action, Signature, Comments, Step, Due, Since. Publication, With, Status, Office and Answer always show. A grid that fills the card shows more rows on a taller window.
- In a narrow list row, the button goes under the text when the text would keep less than 160 px at 100 % beside it.
- A card with a single column is at most 1200 px wide at 100 % (the Administrator, 19 Nov 26; was 1000 px). `OneColMax` in `Get-T22Layout`.
- Plain text in a card (paragraphs, notes, notices, guidance; not grids or tables) wraps at a measure of about 75 characters of the body font, or at the card width when that is less (the Administrator, 19 Nov 26). The width is 75 times the font's average character width at the current dpi (the 52 letters a to z and A to Z, measured, divided by 52): `Get-T22ProseWidth`, computed with the layout, so it changes only on a resize or a scale change. Sources: USWDS typography, prose measure default 75 characters (https://designsystem.digital.gov/components/typography/); WCAG 2.2 success criterion 1.4.8 Visual Presentation, at most 80 characters (https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation).

## 1. Rules for every screen

- One screen = one task (docs/guidance/customer-steps.md). Step screens show "Step X of Y", the due date, the heading, the instructions, "Why", and one main button.
- Instructional text comes from the PFM Guidance list by Guidance Key (12A); a missing key shows "Guidance missing, contact the PFM". 76 keys today.
- Names, dates, times and words follow docs/style-standard.md (DAFMAN terms, Title Case names, 13 Nov 26, 1708).
- Who sees what is decided from data, never from a list of names in the app (4A): PFM Office group membership; AO 1/2 Email on PFM Publications; Endorser on PFM Endorsements; CSS and leader rows on PFM Offices; certifier and approver fields on the action.
- Release gate: Power Apps Accessibility Checker 0 errors; text contrast 4.5:1, large text and controls 3:1 (WCAG AA).

## 2. Roles

| Role | How the app knows | Sees |
|---|---|---|
| Any Member | Signed in | Home, Search, Product Detail, Start, Suggest a Change, Ask for a Review, Help |
| AO (and alternate) | AO 1 or AO 2 Email on an action | + Action Steps, Package, Status |
| CSS | CSS on a PFM Offices row | + Name the AO |
| Coordinator | Endorser on an open PFM Endorsements row | + Review This Draft, Your Answer |
| Certifying / Approving Official | Named on the action | + Certify, Approve |
| PFM Office (PFM, Alternate, Acting PFM) | PFM Office group | + every PFM screen (section 5) |

## 3. Shared screens

| ID | Screen | Purpose | Text source |
|---|---|---|---|
| S01 | Home: My Work | One list of everything waiting on me, across all my roles, soonest due first (**REC:** Q28) | App labels; item lines from the action |
| S02 | Search Publications | Find any wing publication or form; filters: series, type, status, OPR | App labels |
| S03 | Product Detail | Title, number, status, effective date, next review, prescribed forms, package files (download), open actions | Product Index fields |
| S04 | Action Status | Stage stepper (only the stages its action type uses, PFM Process Steps Applies To), who has it now, due dates, history | Process Steps, Activity Log |
| S05 | Step Screen (template) | Renders any Guidance row: Step X of Y, heading, instructions, why, Done When as the button rule | PFM Guidance |
| S06 | Help Panel | "Words You Will See", "Who Must Follow It", "Which Type", "Plan Your Time" | Guidance WORD, SCOPE, TYPE, PLAN keys |
| S07 | Package | Files of a product or action by Document Role; upload; "Attach All Documentation You Have" (6.5) | App labels |
| S08 | About and Updates | Versions, Check for Updates, release notes | App labels, Releases list |

## 4. Paths that use S05 (one step at a time)

| Path | Guidance keys | Count |
|---|---|---|
| Start | START-01, START-02, START-03 | 3 |
| New publication | NEW-01 to NEW-10, NEW-04A | 11 |
| Change a publication | CHG-01, CHG-AC/IC/RW/GM/CC/RS/TR/AO/OPR-01 | 10 |
| Suggest a change (DAF Form 847) | CHG-847-01 | 1 |
| Forms | FORM-01 to FORM-06 | 6 |
| Common steps | STG-DRAFT, STG-CONTENT, STG-FORMAT, STG-PRIV, STG-COORD-01, STG-COORD-02, STG-LEGAL, STG-CERT, STG-APPR, STG-SUBMIT, STG-POST | 11 |
| Other people's tasks | CSS-01, END-01, END-02, SIGN-01, SIGN-02, REV-01, REQ-01 | 7 |
| Help panels (S06) | PLAN-01, WORD-01 to WORD-18, SCOPE-01, TYPE-01 to TYPE-07 | 27 |

Screens with input beyond Done: NEW-02 (search), NEW-04A (scope picker), NEW-05 (type), NEW-07 (series), STG-COORD-01 (coordinator picker), END-02 (answer + CRM upload), CSS-01 and CHG-AO-01 (people picker), STG-SUBMIT (3 uploads).

## 5. PFM Office screens

| ID | Screen | Purpose |
|---|---|---|
| P01 | Work Queue | Every open action: stage, owner now, days in stage (weekdays), flags (stalled, overdue, open nonconcur) |
| P02 | Action Detail | All fields, Status Notes (dated, append-only), stage override with reason, files |
| P03 | Numbers | Assign the next number in a series (4.3.8); reserve it in Product Index |
| P04 | Format Handoff | Draft ready for GenAI.mil and the renderer; mark formatted |
| P05 | Product Index | Edit products; views Not Active, Review Due, Prescribed Forms |
| P06 | Import and Intake | Rows "Imported, Not Confirmed" (confirm, override); files in Intake (sort) |
| P07 | Reviews | Periodic and special reviews, DAF Form 399 answers, no-answer rescind |
| P08 | Recommendations | DAF Form 847 inbound and outbound |
| P09 | Waivers | Waivers in wing publications, renewal due |
| P10 | Offices and Coordinators | PFM Offices rows, mandatory coordinators, Suggest When |
| P11 | Status Report | E-mail a status report to anyone, any time |
| P12 | Settings | Roles: PFM, Alternate, Acting PFM + Acting Until (4A, 10A, 11A); access group (P6); sender mode (P4A); time zone |
| P13 | Health | Flow runs, broken connections, departed accounts on open actions (21A) |
| P14 | Chapters | Backups, row counts, restore, "Delete N Old Chapters" (22A-23A) |
| P15 | Deleted | Recycle bin restore |
| P16 | First-Run Setup | Shown while Setup Complete = No (docs/setup-and-updates.md 4) |

Guidance text for the PFM screens is edited in the PFM Guidance list itself (list view), not in the app (**REC:** Q26).

## 6. Totals

8 shared screens + 1 step template that renders 49 step keys and 27 help keys + 16 PFM screens = 25 built screens (counting the template once).

## 7. Answered (13 Nov): 26A 27A 28A 29A

| Q | Question | Options | REC |
|---|---|---|---|
| Q26 | Where button labels, field labels, errors and empty-state text live | A: in the app code, checked by tests/check_names.py; all instructions in PFM Guidance. B: everything in PFM Guidance, so a wing can reword buttons | A: one word per meaning across wings; buttons rarely change |
| Q27 | Phone and desktop | A: one responsive app (containers), checked at 375 px and 1440 px. B: separate phone and tablet layouts | A: one app to maintain |
| Q28 | Home for a person with several roles | A: one My Work list, soonest due first, role shown on each line. B: one tab per role | A |
| Q29 | Status for people who are not on an action (a supervisor) | A: S04 open to every member (all rows are readable anyway, 1A). B: only the action's people and PFM Office | A |
