# Decisions: 90-161.Z

Newest first. "By" = PFM for a decision. "By" = Agent for a recommendation that PFM has not approved yet.
One table (PFM C, 2026-11-13; replaces the B2A short index + archive pair): one line per decision, 200 characters or fewer; detail lives in the linked doc. Rows from before 13 Nov 26 15:30 have full text in docs/decisions-archive.md "Full text of current rows"; read it before you act on them.

| Date | Decision | By | Detail |
|---|---|---|---|
| 2026-11-14 | AGENTS.md "Verification" points to the ui-verify and data-change skills; the 375/1440 px UI rule stays. | PFM | AGENTS.md |
| 2026-11-14 | Add the kit files 90-161.Z never had: MIT LICENSE (holder rhope-ops), docs/WORKING_WITH_AGENTS.md, .claude/skills (data-change, ui-verify), same as RADE. | PFM | LICENSE |
| 2026-11-14 | Deployer renamed RADE (Redacted Application Deployment Engine). Folder OneDrive\RADE\90-161.Z (R17 moves the old one in); RADE\Config holds engine settings. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | RADE saves PASSED checks in RADE\Config\rade-checks.json (other apps may read it); reused for 7 days, then the PFM runs them again. Failed or warned checks always rerun. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | RADE window: every row two lines high (no movement while checks run), smoother bar animation, an Exit button. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | Site logo and thumbnail: by hand (Change the look > Header) in a guide step; site setup checks the header logo. No more logo scripts. | PFM | docs/reviews/2026-11-14-r16-results.md |
| 2026-11-14 | SharePoint admin app (drag and drop membership, bulk select, permission trees, rights pass/fail): a RADE window app (WPF/PnP) if built. Now: collect what is possible only. | PFM | https://claude.ai/artifact/5KPZmF6FbJBB41wqG22C9w |
| 2026-11-14 | R16: no new export; T17 r2 uses the T05 export values (Claude's miss: T05 was not applied). Any future capture file is shown to the PFM before it is attached. | PFM | docs/reviews/2026-11-14-r15-results.md |
| 2026-11-14 | Sprawl: targeted cuts in the R17 build, not a full audit: mask once per probe run, one shared masking function, clean-up by revision rule, drop logo fallbacks R16 shows unneeded; report before/after. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-14 | App name: 90-161.Z: Publications and Forms Management (short name 90-161.Z). The Word-open check blocks a deploy (1B); other warnings do not. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | No deploy unless every check passes (FAILED or NOT RUN blocks; WARNING does not; no "deploy anyway"). Check text: sentence case, screen names in "quotes", reported values in [brackets]. | PFM | https://claude.ai/artifact/RY4rWNuBP3rwAai9v3uWD8 |
| 2026-11-14 | Plain-English sweep: go.md and Deployer step notes in R16; each flow, package and solution at its next revision. Deployer first screen stays minimal. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | All text the PFM or a user sees (Deployer window, packages, imports, descriptions, subtitles) is plain, simple English. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | Deployer window: Choose app > Check > Deploy; embedded catalog only (3A stays); two bars (PROGRESS lines, else time); checks: computer, network, site rights (PnP sign-in), Power Automate. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | R15: solution XML comes from a real export (PFM makes one, Deployer masks and sends the XML); site setup sets header logo and thumbnail apart; probe r5 grants the coworker's user ID. | PFM | docs/reviews/2026-11-14-r15-results.md |
| 2026-11-14 | Site logo = variant A, bold white (lines 60% thicker than r1; replaces option D's header logo). Thumbnail stays navy, same bold lines. | PFM | https://claude.ai/artifact/AZUqwxiPwSruC65eH1uhHx |
| 2026-11-14 | Wing users have only Read on the site; anyone using the app enters data through it. Open: how the app writes (list-level rights or a flow), see NEXT_PROMPT. | PFM | docs/reviews/2026-11-14-r13-results.md |
| 2026-11-14 | The Deployer delivers every file a round needs (no separate downloads) and guides steps done in another program (R13: probe flow import); its log text reads professionally. | PFM | docs/reviews/2026-11-14-r12-results.md |
| 2026-11-14 | Passed steps (T01 render test, T15 inventory) run in a round only when their files changed since the round that last passed them (hash in scripts/paste_bundles.json); still tickable by hand. | PFM | scripts/build_paste_bundles.py |
| 2026-11-14 | Remove manual gov-device work wherever a script can do it without weaker checks (R12: PnP site setup, seal prep from T07\Seals, probe flow reads its own test mails). | PFM | docs/reviews/2026-11-14-r11-results.md |
| 2026-11-14 | Unit seals are not CUI or controlled: Claude may correct them (upscale, clean, feather) and return them by e-mail. They still never go in this repo. | PFM | docs/reviews/2026-11-14-r11-results.md |
| 2026-11-14 | Logo option D: site logo = mark r1 with no fill (blue header); thumbnail = navy mark with no fill (white cards). The blue tile is dropped. | PFM | assets/logo/ |
| 2026-11-14 | Task 10 closed: the briefs open normally in PowerPoint. | PFM | go.md Done |
| 2026-11-14 | Probes also document capabilities for future projects (PowerShell, SharePoint, Power Apps, Power Automate, Forms): read-only checks; results to the private log. | PFM | docs/rights-test-plan.md |
| 2026-11-14 | Automate T11 Part B: probe flow r2 + Outlook checks in the round; up to 3 test mails from the office mailbox, to the PFM only; probe adds the coworker as flow co-owner, then removes them. | PFM | docs/rights-test-plan.md |
| 2026-11-14 | Revisit 1B (no PnP): R09 PnP web login PASS (manage lists, manage site). Next round adds a read-only PnP test on the new site; if it passes, optional Deployer steps for lists, permissions and logo; Power Automate stays the fallback. | PFM | docs/reviews/2026-11-14-r09-results.md |
| 2026-11-14 | The new site is a separate site collection. Second-look findings F1-F5 wait for the PFM's go; S8-S11 added to the sweep page. | PFM | docs/reviews/2026-11-13-sweep-decisions.md |
| 2026-11-14 | New site exists, approved for CUI. Tasks 11, 14 use it; Task 8 (edit own rows) moves into the T02 r11 flow, by hand if it reports NOT SET. Hold any step that needs a PnP check. | PFM | docs/power-automate-provisioning.md |
| 2026-11-14 | Sweep answers: (S1) the lists go on a new site: T02 r10 builds all 12 from scratch, no upgrade flow; (S4) 33 coverage rows N/A; (S5A) a flow routes endorsements, Legal after the others; R09 goes live. S2, S3, S5 rest, S6, S7 open. | PFM | docs/reviews/2026-11-13-sweep-decisions.md |
| 2026-11-13 | Retest PnP sign-in (revisits 1B): T16 tries SPO Management Shell with the DoD and High clouds, web login, interactive; read-only, optional step in R09. | PFM | scripts/gov/90161Z-T16-pnp-signin-test-r1.ps1 |
| 2026-11-13 | Sweep while away: R09 = inventory (T15), T11 Part B form, T09 collector, task scripts drop the DODID question now; flow solution package as a draft. R09 waits for PFM review. No PnP steps (1B stands). | PFM | docs/NEXT_PROMPT.md |
| 2026-11-13 | Deployer first: every gov-device step a script can do runs in the round, now and later; R08 replaces R07 and carries Tasks 10, 12, 14, 7. | PFM | AGENTS.md Project rules |
| 2026-11-13 | Round e-mails: Claude watches Gmail for the round subject every 10 min for up to 2 h after a round goes live (no chat message needed). | PFM | AGENTS.md Unattended work |
| 2026-11-13 | Speed: (A) one docs commit and PR per round; (B) project log "Next row: N" line; (C) one decisions table. Bloat audit every 300 commits. | PFM | docs/reviews/2026-11-13-speed-analysis.md |
| 2026-11-13 | R06: Deployer name; real path on screen; To box saved in Config; cleanup of finished files to the Recycle Bin; Window-OK box; OK/CHECK subject; progress, estimates, help lines; Copy script. | PFM | docs/reviews/2026-11-13-r05-results.md |
| 2026-11-13 | Rounds ask no DODID: the runner uses the Windows profile folder (the empty-box default worked in R04). Enter or Run starts. Task scripts drop it at their next revision. | PFM | docs/reviews/2026-11-13-r04-results.md |
| 2026-11-13 | Open items closed: (3.5A) JAG answers in the app; test site = the live site on its own URL, isolated until connected (replaces 5.7B); site approved for CUI. | PFM | archive |
| 2026-11-13 | Delivery by pull request (A); details in AGENTS.md Delivery. | PFM | AGENTS.md |
| 2026-11-13 | One-time history clean: names removed from all history (supersedes 2026-11-12 "no rewrite"). | PFM | archive |
| 2026-11-13 | Bloat audit 2 answers: (P1) one pwsh process for the test validations; (P2) sync baseline bc233b9; (P3) B3A block into all 4 gov task scripts now; (P4) draft short lines. | PFM | docs/reviews/2026-11-13-bloat-audit-2.md |
| 2026-11-13 | gh-pages holds index.html only: the 64 stale copies (old owner name) were removed (PFM). | PFM | archive |
| 2026-11-13 | GitHub account renamed from the old owner name to rhope-ops. All repos now say rhope-ops, history included (PFM); briefs wait for their rebuild. Bookmark rhope-ops.github.io/90-161.Z. | PFM | archive |
| 2026-11-13 | Bloat audit: no removal, shortening or rewording without PFM approval; only audit-made, rebuilt generated and unreferenced scratch files go without it (.claude/bloat-audit.md). | PFM | archive |
| 2026-11-13 | Wing PowerPoint master: Original v2 template and Versions I-IV made; v2 e-mailed to the PFM's work address on request (one-time exception). Design record kept privately. Open: pick a version. | PFM | archive |
| 2026-11-13 | Wing PowerPoint master: all four versions (I-IV) stay open, no pick yet. The decision-brief redesign waits for the PFM's pick. Deliverables kept privately, not in this repo. | PFM | archive |
| 2026-11-13 | R05: a round's last step makes an Outlook draft (subject, body, files; To empty; never sent); fallback = R04 steps. | PFM | docs/reviews/2026-11-13-r03-results.md |
| 2026-11-13 | Enter starts the run (window: Enter after the DODID; text mode: Enter after the plan). Round summary line 1 = the e-mail subject; at DONE the summary is copied and the folder opens. | PFM | docs/reviews/2026-11-13-r03-results.md |
| 2026-11-13 | Accessibility site name and list address are Settings values set at install (PublicationsSiteName, PublicationsListUrl; ship in T02 r10). | PFM | docs/reviews/2026-11-13-r03-results.md |
| 2026-11-13 | Wing accessibility statement: "This publication is available for download on the XXX-XXX SharePoint."; "XXX-XXX SharePoint" links to the site's publications list, not the app. | PFM | docs/reviews/2026-11-13-r02-results.md |
| 2026-11-13 | Pre-push check gate on: a push is blocked while scripts/check.sh fails (baseline hook). Setup actions move to Node 24 in the other repos. | PFM | archive |
| 2026-11-13 | B2 short index approved (1B: with the PFM's edits in the review doc; the doc had none). | PFM | https://claude.ai/artifact/AtxHGVwB8hWc8utEF9KWc2 |
| 2026-11-13 | B1A "e-mail" spelling. B2A short index. B3A one gov task-script source. B4A, B5A check-in fix, PII-guard PR Action. | PFM | docs/reviews/2026-11-13-bloat-audit.md |
| 2026-11-13 | Cover gaps stay as DAFMAN page 1. The "ppt master" e-mail is this project's; leave it untouched. | PFM | docs/reviews/2026-11-13-r01-results.md |
| 2026-11-13 | Word files get the Purview label automatically from a one-time capture. Test: R02. | PFM | archive |
| 2026-11-13 | go.md and runner messages say e-mail (spelling per B1A), never the PFM's personal mail service. | PFM | archive |
| 2026-11-13 | Wing PowerPoint master kept off this repo. **Rec:** use its r2 look as the theme for the briefs and the app (not yet approved). | Agent (Rec) | archive |
| 2026-11-13 | Screen map: (26A) UI text in app code. (27A) one responsive app. (28A) My Work home. (29A) Action Status open to all. No previews. | PFM | docs/app/screen-map.md |
| 2026-11-13 | Phase 4 (25A): screen map first (docs/app/screen-map.md). The planned previews were dropped by the screen-map row (no previews). | PFM | docs/app/screen-map.md |
| 2026-11-13 | Periodic bloat, drift, duplication and assumption checks in every repo; question tool for 1-4 questions. | PFM | archive |
| 2026-11-13 | Bloat audit: 14 days or 30 commits; 12,000 tokens; +25% timing (1A). Other repos (2B). Sync after check: mil (3A). Audit next (4A). | PFM | archive |
| 2026-11-13 | Gov-device usability bar for go.md and runner windows; results folder Rounds\\<round>, no zips. | PFM | archive |
| 2026-11-13 | Backups: (22A) row history, recycle bin, chapters; PFM Office rolls back. (23A) 8 weekly + 12 monthly. (24A) e-mails: new task, due date; rest weekly. | PFM | docs/backup-and-restore.md |
| 2026-11-13 | (19A) weekly digest per person, Wed 0700 Central. (20A+) weekly backup, chapters, in-app rollback. (21A) weekly disabled-account list. | PFM | docs/phases.md |
| 2026-11-13 | RADE: (R1A) code embedded. (R2A) v1: file bridge, one agent flow. (R3A) repo rade. (R4A) PFM runs v1. (R5B) no other app first. (R6A) zip by e-mail. | PFM | https://claude.ai/artifact/GLdT7Nr4aVn3EenyYnAuJF |
| 2026-11-13 | ISSM ruling: scripts without elevated credentials may be pasted and run in PowerShell ISE. No elevation, admin credentials or RunAs. | PFM | archive |
| 2026-11-13 | Logo: woven square-in-a-square mark with a serif Greek rho, white and light blue for blue backgrounds (assets/logo, built by scripts/build_logo.py). | PFM | assets/logo/ |
| 2026-11-13 | Site visuals (pages, header, list looks) by Power Automate flow, built after the T11 rights results; home page as a preview first. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-12 | Package: (15A) folders by permission. (16A) attachments off; metadata ties files. (17A) Document Role suggested. (18A) originals stay. (4) test zip. | PFM (15A 16A 17A 18A+, 4 test) | docs/roles-and-permissions.md |
| 2026-11-12 | (10A) Acting PFM leaves next weekday after Acting Until. (11A) PFM or Alternate names Acting PFM. (12A) covers to CSV. (13A) PFM Office owns itself. (14B) intake. | PFM | docs/roles-and-permissions.md |
| 2026-11-12 | (4A) PFM, Alternate, Acting PFM, Acting Until in PFM Settings. (5A) connection references. (6A) Acting PFM full rights. (7A) PFM Office group. (8A) intake. (9A) library. | PFM | docs/roles-and-permissions.md |
| 2026-11-12 | Phase 1 (1A): ISE runner only runs and tests gov-device code; lists and permissions stay in flows. (1B) no PnP setup path. (2A) Phases 2 and 3 together. (3A) Phases 5-9 added. | PFM (1A, conditional; 1B 2A 3A); Agent | docs/phases.md |
| 2026-11-12 | (4C) Next apps: trackers and process apps. (5A) kit repo on archimedes_lever baseline; 90-161.Z is app #1. (6A) Stage 1 runner OK. | PFM | archive |
| 2026-11-12 | (1A) Pipeline tool in two stages: Stage 1 GUI runner, faster rounds; Stage 2 app generator. (3A) runner never fetches code at run time. | PFM | archive |
| 2026-11-12 | ISSM written approval for paste and run: R02 closed for this wing. | PFM | archive |
| 2026-11-12 | Paste and run for gov-device tasks (trial): one text pasted into PowerShell ISE runs the task. | PFM | archive |
| 2026-11-12 | Command brief: 1-2 concepts per slide, each a Yes, No or Pending evaluation question; plain words. | PFM | archive |
| 2026-11-12 | Command and installer briefs cover one wing; NGB and ANG-wide adoption in a third brief. | PFM | archive |
| 2026-11-12 | Network details removed from the public repo now (item 2); history keeps old text. | PFM | archive |
| 2026-11-12 | Environment setup script installs pptxgenjs 3.12.0; PFM applies it in environment settings. | PFM | archive |
| 2026-11-12 | (P2A) Members read config and log lists only; only flows write Activity Log; PFM office edits config. | PFM (3A) | archive |
| 2026-11-12 | Colors (1A): one palette file; AF ultramarine blue dominant, yellow only as fill or on blue. | PFM | docs/palette.json |
| 2026-11-12 | (2A) PII guard allows www.ang.af.mil, www.dafhistory.af.mil, www.trademark.af.mil. | PFM | archive |
| 2026-11-12 | (P1B) flows read PFM Settings. (P3A) find lists by URL; check before create. (P4A) sender: office mailbox, else PFM. (P5A) runbook, health check. | PFM | https://claude.ai/artifact/Wdvg7PB2321twKVubQbp2i |
| 2026-11-12 | (P6) Wing access group differs by wing; first-run setup asks which group; changeable in the app. | PFM | archive |
| 2026-11-12 | Rights testing: every rights assumption is tested on the tenant before use, with a fallback. | PFM | docs/rights-test-plan.md |
| 2026-11-12 | Decision brief split in two: (1) for a PFM who may install it; (2) for commanders. Plain words. | PFM | archive |
| 2026-11-12 | 90-161.Z is a product for every ANG wing; decisions logged; risks shown in PowerPoint. | PFM | docs/brief/ |
| 2026-11-12 | Initial configuration: one person sets up end to end; setup checks each right, gives how to get it and a fallback. | PFM | docs/setup-and-updates.md |
| 2026-11-12 | Updates: app checks at start and has a "Check for updates" button. | PFM | docs/setup-and-updates.md |
| 2026-11-12 | 5.1 on hold (B): round 2 first. L-012 and L-007 pass: keep Word route (A); else renderer builds .docx (5.1B). 5.2B, 5.3A stand. | PFM (5.1, B) | archive |
| 2026-11-12 | (5.1B) renderer builds the .docx; Word COM updates fields, saves PDF. (5.2B) 3 layers; GenAI.mil required. (5.3A) PowerShell 5.1, also 7. | PFM | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (4.6A) Action records go to Record Sets; Working Files drafts deleted at closeout. (5.7) test site asked, else TEST lists (5.7B). | PFM (4.6A; 5.7 update) | docs/reviews/2026-11-12-afi33-322-working-files.md |
| 2026-11-12 | (4.7) not a joint base. (5.3A), (5.4A) old recs closed. (5.5A) standard connectors, no tenant admin. (5.6A) solution-aware flows. (5.7B) TEST lists. | PFM (4.7 no; 5.3A 5.4A 5.5A 5.6A 5.7B) | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (3.2B) PFM checks AO answers N1 N6 N8 N9. (4.1A) one sequence per series. (4.2A) Privacy, Info Collections offices. (4.3A) waiver statement. | PFM | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (4.4A) warn on wing-approved T-0/1/2 waiver. (4.5A) 847 concurrence. (4.6A) working files kept to record close. (4.8A) stage recs. 4.7 open. | PFM (4.4A 4.5A 4.6A 4.8A; 4.7 open) | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (3.1A) anyone requests; PFM triages. (3.3A) AO confirms comments before Legal. (3.4A) AO may mark Concur-No Response. (3.5C) PFM asks legal. | PFM | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (3.6B) Published folder; app browse first. (3.7B) PFM Office group. 3.2 open. | PFM (3.6B 3.7B; 3.2 open) | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (2.1A) AD group = Members. (2.2A) flows on PFM connections. (2.3B) Working Files permissions by flow. (2.4A) Record Sets: PFM office, co-owners. | PFM | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (2.5B) overdue answers also e-mail the office org box. (2.6A) app shared with Members. | PFM | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (1.1C) OPR asks, PFM approves, flow changes AO. (1.2A) CSS link opener names AO. (1.3A) Org Box Email; PFM Office Mailbox sends. (1.4A) answerer per office. | PFM | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | (1.5A) Level, Parent Office, Leader fields. (1.6A) squadron commander approves flight publications. (1.7A) Delegation Letters. | PFM | https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J |
| 2026-11-12 | Review: (1A) stages 0-12 only. (2A) one AO plus one alternate. (3A) AO one column; flow writes AO 1/2 Email. | PFM | https://claude.ai/artifact/VNBoH8i4SNy7do6py58YNM |
| 2026-11-12 | (4A) scope ladder adds squadron, flight. (5A) no answer by due date: flow opens rescind action. App names approving, certifying officials. | PFM | https://claude.ai/artifact/VNBoH8i4SNy7do6py58YNM |
| 2026-11-12 | (1A) HTML e-Publishing index pages to CSV by PS 5.1 script. (2A) index departmental, ANG, gaining MAJCOM. (3A) guidance reviewed in doc. (4A) approving official approves admin change. | PFM | archive |
| 2026-11-12 | (1A) ANGMAN 1.7.9: one MFR within 90 days of commander change. (2A) wing-publication waivers only. (3A) design 3a. (4B) 8.8.6 n/a. | PFM | archive |
| 2026-11-12 | (1A) Process Steps Applies To column. (2A) flow rule catalog first. (3A) CSV load, manual edit. (4) hold until PFM says go. | PFM | docs/flow-rules.md |
| 2026-11-12 | List design approved for T02 r10. (2) AO multi-person, app stops at 2. (3) 847s to ANG functional office at NGB. (4) names DAFMAN Reference, Active. | PFM | docs/reviews/2026-11-12-list-design-full-scope.md |
| 2026-11-12 | Review 5A: no real names in this public repo, also from covers. Old commits keep names. | PFM (review 5A) | archive |
| 2026-11-12 | Review 4A: PFM Waivers stores Change Of Command Date; Renewal Due = date + 90 days. | PFM (review 4A) | archive |
| 2026-11-12 | Review 3B: overrules Q6 for Table A3.2 only: agent extracts A3.2 offices to seed PFM Offices. | PFM (review 3B) | docs/coordination-table-a3-2.md |
| 2026-11-12 | Review 2A: Form Type uses Table 8.1 types a wing issues; Prescribing Publication only for prescribed and personal-data forms. | PFM (review 2A) | archive |
| 2026-11-12 | Review 1A: Legal opens when coordinator rows are final and comments adjudicated; approval needs Open Nonconcurs = 0 or impasse memo. | PFM (review 1A) | docs/reviews/2026-11-12-independent-review.md |
| 2026-11-12 | F-040: warn (1A). No tier mark on wing compliance statements, above-wing waivers excepted (2B). Sample, T06 follow (3A). | PFM | archive |
| 2026-11-12 | Q12A: guidance in list PFM Guidance (row per text block, unique Guidance Key); missing key shows "Guidance missing". | PFM | archive |
| 2026-11-12 | Q13: mandatory coordinators JAG (last), CIO, PFM, FOIA, Records, each its own row. | PFM | archive |
| 2026-11-12 | Q14A: design and build the full DAFMAN scope now. | PFM | docs/reviews/2026-11-12-dafman-full-gap-check.md |
| 2026-11-12 | Q15A: record sets kept centrally in library 90-161.Z. | PFM | archive |
| 2026-11-12 | GPT is the GenAI.mil extractor, Gemini the fallback (1A). No Grok. Task 6 compares GPT and Gemini only. | PFM | docs/reviews/2026-11-12-gov-results-t01r5-t06-t07.md |
| 2026-11-12 | Walkthrough Q1: PFM office mailbox e-mails the CSS org box; OPR official appoints AO (1, at most 2). Q11A: e-mail links to app screen with GAL picker. | PFM | https://claude.ai/artifact/VLxDqQfhEfWSw4Ckrc52Ki |
| 2026-11-12 | Q2A: PFM's office runs GenAI.mil and the renderer; replaces AFIMPT work. | PFM | archive |
| 2026-11-12 | Q3A: Working Files folder per action. Q4A: officials sign 673 digitally. Q5A: OPR uploads final package. Q7A: Product Index for non-app users. | PFM | archive |
| 2026-11-12 | Q6: PFM enters mandatory coordinators JAG (last), CIO, PFM; OPR names its certifying and approving officials. No agent extraction of A3.1, A3.2. | PFM | archive |
| 2026-11-12 | Item-level permissions on PFM Publications, PFM Endorsements: Read all; Create and Edit own items only. | PFM (10A) | archive |
| 2026-11-12 | Seals live in a Seals folder of library 90-161.Z, no unique permissions (7B). | PFM | archive |
| 2026-11-12 | Users browse through the Power App; PFM lists not hidden. One list with lookups is the browse entry for non-app users (8); which list is open (Agent assumption: PFM Product Index). | PFM | archive |
| 2026-11-12 | No check of DAFMAN 90-161 1.1.3.2 and 6.4 against app-first browsing (9B). | PFM | archive |
| 2026-11-12 | First name in two old commits stays in history. gh-pages gets index.html as one commit (6A). | PFM | archive |
| 2026-11-12 | Task page (index.html): collapsible sections, Open/Done labels, file cards, numbered steps (3A). | PFM | https://claude.ai/artifact/4XLxCcVfpdAWQaBwotUfX2 |
| 2026-11-12 | Task-result e-mails are moved to Trash after parsing, only after the PFM confirms each. | PFM | archive |
| 2026-11-12 | Flow inputs the PFM fills in use plain words for a low-skill user. Applies to every future payload. | PFM | archive |
| 2026-11-12 | Remove the site-title check from the provisioning flow; T02 r9 asks only for the site address. | PFM | archive |
| 2026-11-11 | Seal prep and renderer check now (1A). Narrow seal centered in 1.20 in box (2A). 360 x 360 px PNG, 300 dpi; <100 fails, <150 warns. | PFM (1A 2A); Agent | archive |
| 2026-11-11 | Seals (DAFMAN 4.5.4.2): each unit's own shield (1C), no MAJCOM approval in writing, PFM accepts the risk (1B). (2A) Seal files stay in SharePoint, never in this repo (Seals folder row). | PFM | archive |
| 2026-11-11 | Build the GenAI.mil extraction prompt before the solution-aware flows (3A). Placeholders stop the build. | PFM | prompts/90161Z-T06-extract-prompt-r1.txt |
| 2026-11-11 | T02 r9 ran on the real site (4B). | PFM | archive |
| 2026-11-11 | Style rules in docs/style-standard.md approved (1A). PFM Reviews keeps OPR Response "No Response" (2A). | PFM | docs/style-standard.md |
| 2026-11-11 | Standardize IAW DAFMAN 90-161 and Tongue and Quill (1A). **Rec:** docs/style-standard.md rules. Environment allows www.govinfo.gov. | PFM (1A); Agent (Rec) | docs/style-standard.md |
| 2026-11-11 | DAFMAN check: (1A) build r7 set. (2A) 3 Coordination Stages. (3A) action links to Product Index row. (4A) PFM Reviews list. (5) none of "Left out". | PFM (1A 2A 3A 4A 5); Agent | https://claude.ai/artifact/X8LbHd79Zh614i1qYzhyTW |
| 2026-11-11 | Coordination: stages in order, same-stage parallel, Legal last (3.4, 5.1, 5.1.8.1). Coordination Stage replaces Sequential or Parallel (1A 2A). | PFM | https://claude.ai/artifact/X8LbHd79Zh614i1qYzhyTW |
| 2026-11-11 | Only directive publications tracked (types per Table A11.1); forms link to their publication. Columns: Action Type drops Supplement and OI; PFM Series list; OPR lookup; Product Status adds Inactive. | PFM; Agent | archive |
| 2026-11-11 | Records: AFRIMS RDS T 33-38 R 07, destroy when superseded or rescinded; manual destruction. Covers record set only. | PFM; Agent | archive |
| 2026-11-11 | Gap review: (1A) members read all rows. (2) test solution-aware flows. (3) no governance notice. (5A) Requester column, Central time, Accessibility gate. | PFM | https://claude.ai/artifact/Ta3utvkZGP5aKXWWeRh7vU |
| 2026-11-11 | The 15-business-day coordination period (5.2) is a measure, not a deadline; measured-tone reminders (1A). | PFM | archive |
| 2026-11-11 | .pii-guard also allows host usaf\.dps\.mil. | PFM | archive |
| 2026-11-11 | Continuity: every flow and the Power App get a co-owner; transfer steps in the maintainer how-to (1A, 2A). | PFM | archive |
| 2026-11-11 | PII guard on: skip ref/dafman90-161.txt; allow GenAI.mil and usaf.dps.mil. Pushes fail without a denylist. | PFM | archive |
| 2026-11-11 | Design goal: easy for the successor to fix; non-expert how-to included. | PFM | archive |
| 2026-11-11 | AO on PFM Publications is a Person column. Action Status (On Track, On Hold, Stalled), append-only Status Notes. | PFM; Agent | archive |
| 2026-11-11 | Title Case for every name of a thing, enforced by tests/check_names.py (8A, 9B). | PFM | archive |
| 2026-11-11 | Baseline sync to archimedes_lever 2452a16. Owner stays "the PFM". | PFM (1A) | archive |
| 2026-11-11 | Naming: app 90-161.Z; subtitle "<wing> ARW Publications and Forms" (wing on gov device only). One prefix; rules 1-8. List prefix "PFM" (Agent, under PFM delegation). | PFM (1A 2B 3A 5A 6B); Agent | https://claude.ai/artifact/WU7A3UXrmr9tFf2sy18Ptk |
| 2026-11-11 | Cloud sessions use environment "90-161.Z"; PII_GUARD_DENYLIST on every baseline environment, added by the PFM. | PFM (1A 2A) | archive |
| 2026-11-11 | Gov-device task folders: C:\Users\<DODID>\OneDrive - United States Air Force\90-161.Z\T<NN>. Scripts ask for DODID (Enter = profile folder). | PFM (2A); Agent | archive |
| 2026-11-11 | Baseline is rhope-ops/archimedes_lever; Owner line stays "the PFM". | PFM | archive |
| 2026-11-11 | Gov-device files named 90161Z-T<NN>-<slug>-r<N>; flow display names use the same prefix. | PFM (proposed by Agent) | archive |
| 2026-11-11 | Baseline sync: model-agnostic agent rules, pre-push hook, log_check, drift and timeline tools, GEMINI.md. Owner stays "the PFM". | PFM | archive |
| 2026-11-11 | Collaboration log becomes the "Project log"; stays in the private Claude doc. | PFM | archive |
| 2026-11-11 | Flows get the SharePoint site URL as a run-time input; site URL and list IDs never go in the repo. | PFM | archive |
| 2026-11-11 | Repo stays public. Gov-network test details go to the private log; the future SharePoint page gives general lessons only. | PFM | archive |
| 2026-11-11 | Collaboration log lives in private Claude doc https://claude.ai/artifact/9zLxe6e9vJPKtRQv5xSSzk. | PFM | archive |
| 2026-11-11 | Hand-off page is go.md at repo root, plain-text URLs; Pages site is the bookmark, raw go.md the fallback. | PFM | archive |
| 2026-11-11 | Build order C (renderer) > D (app) > B (getting-started doc). | PFM | archive |
| 2026-11-11 | TOC always for ANG wing publications (4.5.8.2, 4.5.8.3); no off switch. | PFM | archive |
| 2026-11-11 | Certifier name line "(Rank First Last)" under Certified by is required. | PFM | archive |
| 2026-11-11 | The app replaces the checklist, AO guide, template and Attachment 1 workbook; one short Word doc. | PFM | archive |
| 2026-11-11 | The app can e-mail a publication status report to anyone at any time. | PFM | archive |
| 2026-11-11 | Phase A route: built-in browser (done); plan order A > B > C > D. | PFM | archive |
| 2026-11-11 | DAFMAN 90-161 wins over wing files and practice; wing files shape the process only. So: indent 0.25 in per level; signature block 4.0 in; TOC 4.5.8.2; waiver wording 4.5.5.11. | PFM | archive |
| 2026-11-11 | Two spaces before each new sentence. | PFM | archive |
| 2026-11-11 | Cover line reads "Certified by:". | PFM | archive |
| 2026-11-11 | New CRM template from DAFMAN Figure A12.1: templates/CRM_A12-1.docx, replaces the old CRM. Resolution codes A/R/M, not A/R/P. | PFM | templates/CRM_A12-1.docx |
| 2026-11-11 | Endorser is a Person field. | PFM | archive |
| 2026-11-10 | Create SharePoint lists with a Power Automate flow; PnP path dropped. | PFM | docs/power-automate-provisioning.md |
| 2026-11-10 | Repo holds only the pattern https://usaf.dps.mil/sites/<your-site>; real site path stays on the gov device. | PFM | archive |
| 2026-11-10 | Build both lanes in parallel: (A) renderer + validator, (B) lists + provisioning (PnP later replaced by a flow). | PFM | archive |
| 2026-11-10 | Public repo uses "PFM", not the PFM's name. | PFM | archive |
| 2026-11-10 | Repo is public; gov device reads it without a login; no wing name, people or office symbols in it. | PFM | archive |
| 2026-11-10 | Renderer: try both A (PowerShell + Word COM) and C (Power Automate "Populate a Microsoft Word template"). | PFM | archive |
| 2026-11-10 | PFM is not a tenant admin. | PFM | archive |
| 2026-11-10 | The wing has no supplement to DAFMAN 90-161. | PFM | archive |
| 2026-11-10 | ANG wing publications post on the wing's own site, not AFIMPT/AFDPO (1.1.3.2, 6.4.1, 6.6.3). Camera-ready final. | PFM | archive |
| 2026-11-10 | PFM is a site collection administrator with PowerShell access to SharePoint. | PFM | archive |
| 2026-11-10 | Rules force output to look like DAFMAN 90-161. AFIMPT not used for formatting or tracking. | PFM | archive |
| 2026-11-10 | 90-161.Z is the system of record for endorsements (no TMT). | PFM | archive |
| 2026-11-10 | Transfer path: the PFM opens the repo on the gov device. | PFM | archive |
| 2026-11-10 | Rule source: DAFMAN 90-161, 18 Oct 2023, with Change 1 (14 Jul 2025) and Corrective Action (1 May 2026). | PFM | archive |
| 2026-11-10 | Scope: wing/installation publications. | PFM | archive |
| 2026-11-10 | Platform: SharePoint Lists + Power Automate + Power Apps in DoD365. | PFM | archive |
| 2026-11-10 | Data boundary: government data stays in DoD365/GenAI.mil only. | PFM | archive |
