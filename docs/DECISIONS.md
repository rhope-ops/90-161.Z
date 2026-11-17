# Decisions: 90-161.Z

Newest first. "By" = PFM for a decision. "By" = Agent for a recommendation that PFM has not approved yet.
A record that agents read on demand, not at the start of a session (the PFM, 2026-11-16): a row binds the task or thing it names; only a line in AGENTS.md binds every session (AGENTS.md "Rules and decisions").
One table (PFM C, 2026-11-13; replaces the B2A short index + archive pair): one line per decision, 200 characters or fewer; detail lives in the linked doc. Rows from before 13 Nov 26 15:30 have full text in docs/decisions-archive.md "Full text of current rows"; read it before you act on them.

| Date | Decision | By | Detail |
|---|---|---|---|
| 2026-11-17 | If R29 on the new engine is over 600 KB, split it: R29a (fixes, T21, T24) and R29b (T22 window, T4), each with its own bundle and e-mail. Scope: round R29. | PFM | docs/reviews/2026-11-17-r28-results.md |
| 2026-11-17 | Lock moves to the RADE release with the R28 fixes (N1, N4, N6, N8-N10, answer cut, logo) when it ships; R29 is built on it. Scope: round R29. | PFM | docs/reviews/2026-11-17-r28-results.md |
| 2026-11-17 | R29 = the R28 fixes (health flow checks only On, export reader, T22 window, T24 card, notes N2 N3 N6 N7) + full T24 test + logo; RADE Diagnose and Back up move to R30. | PFM | docs/reviews/2026-11-17-r28-results.md |
| 2026-11-17 | T22 checks show inside the test window, one at a time, with Pass and Fail; no list to remember (note N5). Scope: T22 window test. | PFM | docs/reviews/2026-11-17-r28-results.md |
| 2026-11-17 | T4 second-person step stays in R29: a colleague is free. Way C not built yet. Scope: round R29. | PFM | docs/reviews/2026-11-17-r28-results.md |
| 2026-11-17 | RADE install asks where to install, with the desktop path filled in; the address row shows only when a card has an address; a step shows elapsed time. Scope: RADE engine. | PFM | docs/reviews/2026-11-17-r28-results.md |
| 2026-11-17 | Logo (replaces "Rho Bold for every app"): Rho Bold (USAF-B) is RADE's logo; 90-161.Z uses it until it has its own logo (not designed). Switch in R29. Scope: RADE, 90-161.Z. | PFM | https://claude.ai/artifact/Qw7iSQaz1FMzZQtycjrZxq |
| 2026-11-17 | PFM window uses RADE's shared type scale (4 styles; engine-v9, engine/rade_ui.ps1), not the preview 2 font sizes. Scope: PFM window. | PFM | docs/reviews/2026-11-17-runner-polish.md |
| 2026-11-17 | R28 r2: a plain title on every step (runner text rule 1) before the PFM runs R28; R28 r1 had 0 of 41 (1A). Scope: round R28. | PFM | docs/reviews/2026-11-17-runner-polish.md |
| 2026-11-17 | The PFM approved every agent REC and asked for as much as possible in R28: probe retry, T4 retry and full flow solution ride along; order per 1B (16 Nov): clean-up first, final clean-up last. R28. | PFM | docs/reviews/2026-11-17-r27-results.md |
| 2026-11-16 | R28 removes the R27 test-site leftovers first (second person from Visitors, probe list and library, probe solution); not by hand (1B). Scope: round R28. | PFM | docs/reviews/2026-11-17-r27-results.md |
| 2026-11-16 | RADE lock moves to release engine-v9 (RADE 28877e7, serial 6) by scripts/bump_lock.py; bundles rebuilt. Not verified on a device. | PFM | scripts/rade.lock.json |
| 2026-11-17 | RADE runner polish: type option A, plain step titles, 10 lines per hand card, one Done button, word rules; in the R28 round build, not R27. Scope: RADE window text of 90-161.Z rounds. | PFM | docs/reviews/2026-11-17-runner-polish.md |
| 2026-11-17 | Window design approved for R28: preview 2 (https://claude.ai/artifact/12VVeBiXXD4AQjAWwgCU5H). Replaces the agent row "Your Work = ..." (not approved) below. Scope: PFM window. | PFM | docs/reviews/2026-11-17-window-ux-targets.md |
| 2026-11-17 | No timed tasks: targets U1 to U5 guide the design; proof = measured checks and the PFM's look-and-feel rating in R28. Scope: PFM window. | PFM | docs/reviews/2026-11-17-window-ux-targets.md |
| 2026-11-17 | Text in the RADE window and the 90-161.Z window is selectable (highlight, Ctrl+C, right-click Copy); same look. Engine item 3a.8; built in rhope-ops/RADE for R28. | PFM | docs/reviews/2026-11-17-window-plan.md |
| 2026-11-17 | .pii-guard skip line (added by the PFM): PNG files in a folder named spike inside a Claude session scratchpad pass the hook unscanned, so real-window spike pictures can go on the private canvas. | PFM | .pii-guard |
| 2026-11-17 | Reminder record (gap G2): one PFM Activity Log row per reminder to an office (EventType Reminder); it is the good-faith contact record of DAFMAN 90-161 5.4.3.1. Scope: PFM window, flows. | PFM | docs/reviews/2026-11-17-window-ux-targets.md |
| 2026-11-17 | RADE Start button: the agent drafts the replacement for RADE's rule "installs apps and does not start them" when the R28 engine work starts; the PFM approves the exact text. | PFM | docs/reviews/2026-11-17-window-plan.md |
| 2026-11-17 | Window size: the window keeps the size and place the PFM gives it (Snap too); works from 1280 x 720 logical (24" at 150 %) to a third of a 49" and 2560 x 1440. Replaces the 1100 px rule below. | PFM | docs/reviews/2026-11-17-window-ux-targets.md |
| 2026-11-17 | Step bar: 12 dots; step 13 (Change or Skip) is a button on each action, not a dot. Scope: PFM window. | PFM | docs/reviews/2026-11-17-window-plan.md |
| 2026-11-17 | Your Work = Needs You Today + Who Has It Now (all open actions) + Chase (late offices, logged contacts, 5.4.3.1); from the PFM's answers. Preview 2; not approved yet. | Agent | docs/reviews/2026-11-17-window-ux-targets.md |
| 2026-11-17 | PFM Settings TestMode row seeds Yes (a missing row also counts as Yes); the PFM sets No once at go-live. Replaces the 15 Nov "full solution with No" for this value. Scope: F03, F05, F06. | PFM | schemas/lists/PFMSettings.json |
| 2026-11-17 | One mailbox row: F03 and F06 will read PFMOfficeMailbox; the SharedMailbox row goes away. Built after R27 (R27 flows stay as built). Scope: PFM Settings, F03, F06. | PFM | schemas/lists/PFMSettings.json |
| 2026-11-17 | R27 Excel look probe: no macro workbook (a script that writes a macro file can set off endpoint security; Excel for the web does not run VBA). Scope: R27. | PFM | docs/phases.md |
| 2026-11-17 | Replaced (same day): Logo: Rho Bold (USAF-B) replaces logo K for every app from now on; R27 ships with logo K, the switch comes after R27 (RADE master copy, lock move, bookmark page, site logo). Scope: all apps. | PFM | https://claude.ai/artifact/Qw7iSQaz1FMzZQtycjrZxq |
| 2026-11-17 | R27 build: full scope (about 5 to 6 h, estimate); the health-flow probe is built in this repo (Management connector, own flows only); the .msapp is packed by the Power Platform CLI. Scope: R27. | PFM | docs/phases.md |
| 2026-11-17 | Window plan approved: Hybrid (busy) layout with Air Force colors; preview canvas for the PFM first, then RADE engine fixes and T22 r2 in R28; R27 unchanged. Scope: RADE frame + PFM window. | PFM | docs/reviews/2026-11-17-window-plan.md |
| 2026-11-17 | Start and icon: one desktop icon opens RADE; RADE runs checks and the update notice (RADE page); Start opens the 90-161.Z window. Needs a RADE row that replaces RADE 2026-11-14 "installs apps only". | PFM | docs/reviews/2026-11-17-window-plan.md |
| 2026-11-17 | PFM window = PFM-only cut of the Hybrid board with a 13-step bar; other people's tasks stay in SharePoint list forms. Below about 1100 logical px the side panel moves under the main column. | PFM | docs/reviews/2026-11-17-window-plan.md |
| 2026-11-17 | The 2026-11-15 row "90-161.Z stays a Power Apps canvas app ... no desktop window" is replaced by the 2026-11-16 front-end split (agent finding; the PFM's split decision wins). | Agent | docs/reviews/2026-11-17-window-plan.md |
| 2026-11-17 | (1A) The milhosts() fallback also takes over when a span starts before the end of the last confirmed match: output in order, no repeats; 2 self-tests. | PFM | scripts/pii_guard.py |
| 2026-11-17 | (1A) If a span is not confirmed, the milhosts() fallback rescans from the end of the last confirmed match (finds a match skipped before it); 2 self-tests. | PFM | scripts/pii_guard.py |
| 2026-11-17 | T4 retry in R27 (1A): a script step asks the PFM for the second person's e-mail in the RADE window (it stays on the gov device), adds that person to the test site's Visitors group with the PFM's sign-in, the person adds one row by the form link, the script reads counts only; clean-up removes the person from Visitors again (2A). If "No permission" again: way C, a flow writes the row with the PFM's connection. Scope: round R27, test T4. | PFM | docs/reviews/2026-11-16-r26-results.md |
| 2026-11-16 | (2A) pii_guard.py finds MILHOST hosts with milhosts(): linear, exactly the matches of MILHOST.finditer; the pattern stays unchanged. | PFM | scripts/pii_guard.py, milhosts() |
| 2026-11-16 | Remove the "[TEST]" subject prefix from the F03 and F06 test mode (R26 r2 T9: e-mails without it reached the Inbox at 2 minutes; the "[TEST]" e-mail came later). Scope: F03 and F06; built in the next round. | PFM | docs/reviews/2026-11-16-r26-results.md |
| 2026-11-16 | The PFM window "deep pass" is lower priority: a note for review; the PFM opens a separate chat to fix the UI. Scope: T22 window. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-16 | Guard bullet: the hook "checks the outgoing tool calls it names (list and gaps: personal-data skill)", replacing "each outgoing tool call" | PFM | docs/reviews/2026-11-16-rule-conflict-kit-port-4.md |
| 2026-11-16 | Allow list: `Bash(git diff*)` narrowed to `Bash(git diff)` + `Bash(git diff *)` (the wide entry also allowed `git difftool -x`) | PFM | rhope-ops/archimedes_lever docs/DECISIONS.md |
| 2026-11-16 | Kit round, part 2: skill line on sample addresses; `scan_text` repeat check by set, containment by binary search (same results, 200 KB 13 s -> 0.1 s) | PFM | rhope-ops/archimedes_lever docs/DECISIONS.md |
| 2026-11-16 | Agent values in the hook port, open to change: ask list, 8 MB and 8 s hook limits, Gmail to/cc/bcc exception, `--skills` thresholds (as in the kit's Agent rows) | Agent | rhope-ops/archimedes_lever docs/DECISIONS.md |
| 2026-11-16 | Port kit PII hook (archimedes_lever#27): `--hook` on outgoing tool calls, `--stdin`, linear email pattern; guard bullet names the hook (exact text approved in the kit decision) | PFM | docs/reviews/2026-11-16-rule-conflict-kit-port-3.md |
| 2026-11-16 | Deliver skill step 1: commit messages that name a blocked git form go in a file (`git commit -F <file>`), as the deny rules match the whole command. Suggest text approved as shown. | PFM | .claude/skills/deliver/SKILL.md |
| 2026-11-16 | Port the kit's 22 extra deny rules into .claude/settings.json (discard, forced and hook-bypass git forms, also with git options before the verb); adds protection only. | PFM | .claude/settings.json |
| 2026-11-16 | Kit port 2 review items: keep "one line per rule" as approved (1A); remove "The current request overrides an older handoff." from the AGENTS.md Handoff line, as Order of authority says it (2B). | PFM | docs/reviews/2026-11-16-rule-conflict-kit-port-2.md |
| 2026-11-16 | Kit port 2 by hand (kit c523a21, kit pull requests 19-25; no sync). Approved: 3 AGENTS.md line texts, port skill without sync, reviewer model inherit, new time baselines. | PFM | docs/reviews/2026-11-16-rule-conflict-kit-port-2.md |
| 2026-11-16 | Round skill `.claude/skills/round/SKILL.md` from the outline approved as shown (1a): results, task script, round definition, bundle, go.md usability bar, release order. | PFM | .claude/skills/round/SKILL.md |
| 2026-11-16 | AGENTS.md "Project rules": the 14 lines proposed in the port session, approved as shown (1a); they replace the 21 old rule items. Platform line follows the 16 Nov front-end split. | PFM | AGENTS.md |
| 2026-11-16 | Kit port by hand (no kit sync; kit ceac0e8): rule gate and caps, kit skills replace .claude/orchestration.md, bloat-audit.md and project-log.md, two check lanes (tests/run.sh --fast). One pull request, not merged by the agent. DECISIONS.md leaves the start read. | PFM | AGENTS.md |
| 2026-11-16 | Start-read budget stays at the PFM's 13 Nov values (12,000 tokens, warning 6,000), now set in .bloat-audit.json because the kit script defaults to 4,500. Scope: this port; open to change. | Agent | .bloat-audit.json |
| 2026-11-16 | R27 also tests one tiny cloud-built app file (.msapp) uploaded in 2 places in Power Apps (about 5 minutes); R26 r2 stays as built. Scope: round R27. | PFM | docs/phases.md |
| 2026-11-16 | RADE stays the frame for all projects: each script = RADE + 1 app; RADE opens first (checks, update notice that points to the RADE page), then Start opens the app in its own look. No app list to download from. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-16 | The RADE changes (Start button, desktop icon, update notice) are planned after the R26 r2 results, for the PFM's approval; engine work goes to rhope-ops/RADE. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-16 | The PFM app is its own full-screen 90-161.Z window in the RADE style, installed and updated by RADE (deploy mode); RADE and 90-161.Z stay separate repos (not merged). Other PFMs get it through RADE. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-16 | R26 r2: the T22 window preview opens at full screen. Scope: round R26. | PFM | scripts/gov/90161Z-T22-pfm-window-r1.ps1 |
| 2026-11-16 | Front end split: the PFM works in a RADE-style window (Windows PowerShell); AOs, OPR mailbox people and endorsers use SharePoint list forms from an e-mail link. Replaces Power Apps for the app (10 Nov). | PFM | docs/reviews/2026-11-16-r26-results.md |
| 2026-11-16 | No pasted Power Apps code: R26 r1 pasted 5 of 6 blocks but the result did not match the PFM's vision. | PFM | docs/reviews/2026-11-16-r26-results.md |
| 2026-11-16 | T9 next try: 2 e-mails from the PFM's own mailbox, one subject with "[TEST]" and one without (every "[TEST]" e-mail so far was lost). | PFM | docs/reviews/2026-11-16-r26-results.md |
| 2026-11-16 | R26 r2: a large round, built overnight; the PFM runs it on 16 Nov ("take as long as you need"). | PFM | docs/phases.md |
| 2026-11-16 | go.md round steps hold only the steps that start the round; the runner window holds every other step (one place per step; choice 2A). | PFM | AGENTS.md "Gov-device usability" (3) |
| 2026-11-16 | Guide steps: each names the exact thing to select and holds the exact text; none points elsewhere; tests/check_guide_text.py and a fresh-reader check run before a round ships. | PFM | AGENTS.md "Gov-device usability" (3) |
| 2026-11-16 | The R26 step text is fixed in one pass after the R26 results arrive, not before; until then its failing steps are a reported baseline (removed with R26 r2, 16 Nov 26). Scope: round R26. | PFM | docs/reviews/2026-11-16-r26-results.md |
| 2026-11-16 | R26 test app: no importable file (Microsoft Learn: no supported way outside Power Apps Studio); the PFM makes a blank app and pastes code blocks. Scope: round R26. | PFM | go.md |
| 2026-11-16 | R26 test T9: the Mail connector send (Learn: not in DoD) goes in its own small solution that an import may refuse; a refusal is the result. Scope: round R26. | PFM | go.md |
| 2026-11-16 | R26: T6 way a is a look in the flow designer with 1 question (no documented action definition without a model id); rounds after R26 move by one number. Scope: round R26. | PFM | docs/phases.md |
| 2026-11-15 | Probe round (plan approved): the easy-path probe T2 to T10 runs next, before the Settings-row values of the old R26; the F03 mail fault is test T9 (every send path at once, read back by a flow); a second person with Read does T4; build effort approved (3 workers, 1 reviewer, 3 to 5 hours, estimate). Scope: this round. | PFM | docs/reviews/2026-11-15-r25-results.md "Probe plan" |
| 2026-11-16 | Process 1: an existing publication is triggered for review by itself; the trigger may force a full review. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 2-3: the OPR's closest organization mailbox is e-mailed; a person from that box names 1 or 2 AOs in the app (address-list search). The app logs who. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 4: the AOs get one e-mail with links to the app, the last published version and a DAF Form 399. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 5: the AO answers "needs further review?" No = certify current (399 only). Yes = full process (673). The AO names certifier, approver and the CSS box of each. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 5: the AO picks boxes from a list of all known organization boxes with a summary of each. All mandatory endorsers are prefilled. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 6: the AO may share the draft with anyone. That person gets a link, reads the draft in the app and leaves feedback there. All feedback is given in the app. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 7: the AO adds as many or as few endorsers as wanted and fills in the master DAF Form 673. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 8: the AO flags the PFM when the draft is ready. The PFM reviews it, and only the PFM starts endorsement. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 9: endorsers review the final draft in the app, comment on the joint CRM and answer. "//SIGNED// name, grade" counts (5.1.4.3). Answers are transcribed to one form. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 10: mandatory endorsers unlock only when every optional endorser has an answer on record. Same steps for both. Legal is last (5.1.8.2). | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 11: everything returns to the PFM before certification and approval, then goes to the certifier, then the approver. The PFM builds the final copy at this step. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 11: a stand-in (the CSS) may do every step in the app for an official. Officials get no e-mail alerts; only the CSS box or a named CSS does. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 12: after the last signature the AO is asked to upload related e-mail for the archive, the PFM is alerted, and the publication is available at once. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 13: the PFM can change who gets any step, or skip anyone, whatever DAFMAN 90-161 says; each change is logged with a reason. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process 13: the app makes a publication and its forms easy to see, read, extract details from and summarize. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Capabilities: no platform limit is assumed unless confidence is high; every easy path is tried at least once before a fallback. Scope: 90-161.Z. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Process time: each wave has its own due time. The AO may give a wave more than the DAFMAN minimum, with a careful note that the ANG may move slower than the AO wants. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | Privacy monitor review follows DAFMAN 2.8.1. The role is data: in this wing the PFM holds it, another wing may differ. A person signs for every role they hold. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | New publications and changes the OPR starts use the same process from step 3. | PFM | docs/process-model.md "Target process" |
| 2026-11-16 | How (not approved yet): the 13 steps change the 14 Nov routing order (now 3 waves) and "no hand edits" of the suspense; the stage table and screen map change when flows and screens are built. | Agent | docs/process-model.md "Target process" |
| 2026-11-15 | P5 merged on the PFM's word (pull request 86: 2 AGENTS.md lines). Delete branch claude/exciting-planck-gfr1nu: main has a newer port of its guard work. AGENTS.md speed rules: wait for R26. | PFM | docs/reviews/2026-11-15-bloat-audit-3.md |
| 2026-11-15 | Audit 3 proposals P1 to P9 approved. Made: P1 to P4, P6 to P8. P5 is its own pull request (the PFM reads the new AGENTS.md lines first). P9 goes to the RADE audit. | PFM | docs/reviews/2026-11-15-bloat-audit-3.md |
| 2026-11-15 | Round builds: one new session for each round (P8); a `worker` on the standard tier unless the routing table says strong (P7). Scope: 90-161.Z round builds. | PFM | .claude/orchestration.md |
| 2026-11-15 | Agents do not run tests/run.sh by hand just before a push: the pre-push hook runs it (P4). | PFM | AGENTS.md Commands |
| 2026-11-15 | Round builds use the RADE release that exists; an engine change runs in its own RADE session at the same time and the round moves to it later. Scope: 90-161.Z round builds. | PFM | docs/reviews/2026-11-15-bloat-audit-3.md |
| 2026-11-15 | Reviews in round builds: the rule stays (each fix gets a fresh review); the review starts while the hosted check runs, not after it. Scope: 90-161.Z round builds. | PFM | docs/reviews/2026-11-15-bloat-audit-3.md |
| 2026-11-15 | Bloat audit 3 run on the PFM's request (tests 3 times slower than the baseline). Its proposals P1 to P9 are agent RECs until the PFM approves each. | PFM | docs/reviews/2026-11-15-bloat-audit-3.md |
| 2026-11-15 | SharePoint admin app (SPAR): a Power Apps canvas app any site owner opens by link; tick boxes and buttons, no drag and drop. Replaces the WPF part of 2026-11-14. No build yet. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-15 | 90-161.Z stays a Power Apps canvas app for all users; no desktop window replaces it. Confirms the platform decision of 2026-11-10. Scope: 90-161.Z. | PFM | docs/ARCHITECTURE.md |
| 2026-11-15 | CRM file: an Excel table in the action's Working Files folder, made when coordination starts; the app adds each comment as a row; read-only for people; it goes into the record set. Scope: 90-161.Z. | PFM | docs/process-model.md "CRM columns" |
| 2026-11-15 | Coordinators enter comments in the app, one row per comment (CRM columns, DAFMAN 5.3); the app makes the CRM file for the record set. File format and list design open. Scope: 90-161.Z. | PFM | docs/process-model.md "CRM columns" |
| 2026-11-15 | Clickable previews are back (25A step 2): app previews at 375 and 1440 px, light and dark. The 13 Nov "no previews" text was not the PFM's decision and is withdrawn. | PFM | docs/app/screen-map.md |
| 2026-11-15 | RADE lock moves to release engine-v6 (RADE 67f7681, serial 5) by scripts/bump_lock.py; bundles rebuilt. Not verified on a device. | PFM | scripts/rade.lock.json |
| 2026-11-15 | Round order after R24 approved (1A): R25 lists by PnP, R26 Settings rows, R27 all flows, R28-R29 RADE maintenance, R30-R33 app, R34-R35 pilot start. Scope: 90-161.Z. | PFM | docs/phases.md |
| 2026-11-15 | R25 clean target (2B): delete the 12 test lists, the library, the flows and solutions by hand from an exact list; RADE then checks the site (read-only) before it installs. | PFM | go.md |
| 2026-11-15 | Both 14 Nov holds are lifted: the slice 1 scope hold (slice 1 passed in R22 and R24) and the hold on steps that need a PnP check. | PFM | docs/phases.md |
| 2026-11-15 | RADE pull request 53 merged (site name on the Ready card); engine work for the R24 notes is done by the 90-161.Z session in rhope-ops/RADE under RADE's rules. | PFM | https://github.com/rhope-ops/RADE/pull/53 |
| 2026-11-15 | Newest-RADE check: fix both review findings (compare the lock commit with the tag commit; no network is a NOTE, not a PASS). | PFM | tests/run.sh |
| 2026-11-15 | How R25 is built (not approved yet): T20 replays the T02 payload by PnP REST, MERGE by CSOM; value 3 (shared mailbox) empty to split the F03 e-mail fault; T18 r4; health probe and paste timing to R26. | Agent | docs/reviews/2026-11-15-r24-results.md |
| 2026-11-15 | The install record (RADE `marker`) is not in R25: the engine allows it only in a deploy, and a deploy sends no results e-mail. It moves to the first deploy round (agent finding). | Agent | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-15 | Roadmap lives in docs/phases.md: phase states and the rounds to the pilot (phase 8); round counts, no dates. Exit criteria, round order and estimate there are agent RECs. Scope: 90-161.Z. | PFM | docs/phases.md |
| 2026-11-15 | 90-161.Z uses the newest RADE release, and a check tells when RADE has a newer one. | PFM | tests/run.sh |
| 2026-11-15 | How (not approved yet): tests/run.sh fails when the lock is behind the newest `engine-v<N>` tag (no network: not checked); R24 combines engine-v4 with the 15 Nov flow changes; bundle tests use a stand-in NIPR name. | Agent | go.md |
| 2026-11-15 | RADE lock moves to release engine-v4 (RADE 4a0fbad, serial 4) by scripts/bump_lock.py; bundles rebuilt. Not verified on a device. | PFM | scripts/rade.lock.json |
| 2026-11-15 | Personal-data guard: no DSN phone-number check (the old guard had one; the RADE guard has none). Agent REC to add it in RADE not approved. Scope: 90-161.Z. | PFM | scripts/pii_guard.py header |
| 2026-11-15 | Solution import page: the 4 values a wing sets come first with numbered labels; a test-round slice imports with Test mode Yes (full solution: No). Slice zip r5. Not seen on a device yet. | PFM | flow/solution/README.md |
| 2026-11-15 | Site address is entered once, in RADE: task scripts take it from RADE or Config and ask only when neither has one (T16 r4/r11, T18 r3, T19 r3). The import page still needs it. | PFM | scripts/gov/src/site-common.ps1 |
| 2026-11-15 | 90-161.Z runs the personal-data guard in the DoD tier. `.pii-guard`: 4 allow (CUI choice, example host), 7 binary skips; `check: mil` and the false-match allow (after RADE 5e9a639) removed. | PFM | .pii-guard |
| 2026-11-15 | Personal-data guard: two tiers in one scanner, set in `.pii-guard`: minimum (no line) and DoD (`profile: dod`: adds military hosts, marks, DoD ID numbers, unreadable files). Hand port from RADE. | PFM | scripts/pii_guard.py header; rhope-ops/RADE DECISIONS 2026-11-15 |
| 2026-11-15 | Personal-data guard, minimum tier: a push with no name denylist is blocked. The PFM's projects do not use `denylist: warn`; the DoD tier ignores it. | PFM | scripts/pii_guard.py header |
| 2026-11-15 | Name denylist: one master file in the PFM's Google Drive; other places are copies; the fingerprint (`pii_guard.py --status`) shows a copy that differs. An agent never opens the master file. | PFM | docs/FIRST_USE.md step 3 |
| 2026-11-15 | Personal-data guard: the tier line fails closed. A tier line in any form other than `profile: dod`, or a `.pii-guard` that is not UTF-8 text, fails the scan. | PFM | scripts/pii_guard.py header |
| 2026-11-15 | No automatic Gmail watch for round e-mails: search for the round subject only when the PFM says the e-mail is sent or received. Replaces 2026-11-13 "Round e-mails". | PFM | AGENTS.md Unattended work |
| 2026-11-15 | Turn summaries and "Next" lines link the RADE page https://rhope-ops.github.io/RADE, not go.md. | PFM | AGENTS.md Project rules |
| 2026-11-15 | Hosted checks only on public repos (all my projects): public repos may use free GitHub Actions; private repos review themselves locally. pii-guard.yml restored here. Replaces the row below. | PFM | AGENTS.md |
| 2026-11-15 | No outside checks, all my projects: nothing relies on GitHub Actions or hosted CI; checks run locally. pii-guard.yml and bump-lock.yml removed; merge gate = local checks. Replaced (row above). | PFM | AGENTS.md |
| 2026-11-15 | Lock moves: local script scripts/bump_lock.py (copy the release lock, serial + 1, decision row, rebuild with file trace, checks). Replaces the bump-lock workflow of the same day. | PFM | scripts/bump_lock.py |
| 2026-11-15 | Manual "bump lock" workflow (Actions, input: engine tag): copies the RADE release lock, rebuilds, runs scripts/check.sh and the PII guard itself, opens one pull request. Replaced (row above). | PFM | PR 69 |
| 2026-11-15 | R23 = one read-only step (T15 inventory r3) plus the engine-v2 shared-file self-test; the 2 bundle tests read the expected checks from the round's "needs". | PFM | tests/run.sh |
| 2026-11-15 | RADE lock moves to release engine-v2 (RADE 1a1dead, serial 3): shared files (RADE PR 42). Round bundle R23 r1; R22 r3 bundle removed (ran twice). Not verified on a device. | PFM | scripts/rade.lock.json |
| 2026-11-15 | No kit sync for this repo: the sync replaced the .mil check in scripts/pii_guard.py and project rules. Pull request 61 closed, not merged. Kit fixes are ported by hand. | PFM | AGENTS.md |
| 2026-11-15 | Clean-up of the RADE split: engine-only tests move to rhope-ops/RADE (tests here use only this repo's bundle; 79 to 77 tests); 8 Detail links of engine decisions now point to the engine in RADE. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/make-an-app.md |
| 2026-11-15 | RADE lock moves to the first signed engine release, engine-v1 (RADE ba1b64e, serial 2). Same 2 files and hashes; bundle R22 r3 unchanged. Not verified on a device. | PFM | scripts/rade.lock.json |
| 2026-11-15 | No RADE checkout: the build downloads the engine files by commit and checks each SHA-256 (lock: 2 files, serial 1). Same bundle R22 r3. scripts/check.local.sh runs the tests in CI. | PFM | docs/dev-setup.md |
| 2026-11-15 | Lock rule: only a 90-161.Z session changes scripts/rade.lock.json, on the PFM's request, one pull request, serial + 1 (test enforces). A RADE session never edits this repo. | PFM | docs/dev-setup.md |
| 2026-11-14 | RADE lock moves to the engine with the guardrails (RADE fc6990d). The rebuilt round bundle is R22 r3. Not verified on a device. | PFM | scripts/rade.lock.json |
| 2026-11-14 | Guardrail: RADE stops before any write on a classified-network domain suffix (own domain name only) and accepts a site only on the DAF SharePoint prefix. No banner read. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Guardrail: install needs Full Control (unchanged); RADE shows my own site collection admin flag but never requires it. Edit is not enough. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Guardrail: one install per site. A row on the site holds the version and date; another account is blocked; first install shows "once per wing". Starts with the first deploy app. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | .pii-guard allows the public suffix smil.mil (it is in the NIPR check inside the round bundles). | PFM | .pii-guard |
| 2026-11-14 | RADE lock moves to the "One thing" window (RADE fe32673). The rebuilt round bundle is R22 r2; R22 r1 is the file that made the recorded results. Not verified on a device. | PFM | scripts/rade.lock.json |
| 2026-11-14 | Three reads removed under the no-reconnaissance rule: the tenant search count (T16 sign-in test r3), AppLocker rule counts and the certificate count (T15 inventory r3). Both scripts stay. | PFM | scripts/gov/90161Z-T15-env-inventory-r3.ps1 |
| 2026-11-14 | Flow values move to PFM Settings rows: flows paused, test mode, reminder, escalation and suspense days, shared mailbox. Site address, alert e-mail and list names stay variables. Not built. | PFM | flow/solution/README.md |
| 2026-11-14 | RADE Maintenance screen: 5 buttons (Install, Diagnose, Back up, Restore, Uninstall). Adds Back up to the 14 Nov RADE modes row. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Lists by PnP: RADE builds the site objects from schemas/lists; the provisioning flow retires after one round proves list creation. Replaces 12 Nov 1A and 1B and 10 Nov (lists by flow). | PFM | docs/NEXT_PROMPT.md |
| 2026-11-14 | No reconnaissance, hardened: never anything malicious or that could be misconstrued as malicious. Open reads of SharePoint data with my own account are allowed. Any doubt: ask the owner first. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Tests: no change. Rounds are the Windows PowerShell 5.1 test; cloud tests stay on PowerShell 7; a 5.1 fault is fixed when a round finds it. Replaces "how to move it is open" below. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Round results e-mail: the allowed owner-only exception to the DoD365 boundary rule until the test rounds end. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Flow health: a round tests a health flow with the Power Automate Management connector (own flows only); then choose between it and heartbeat rows. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | AGENTS.md Deployable package line: PnP.PowerShell and Windows PowerShell 5.1 are on every NIPR computer; fallbacks are for rights that differ, not for PowerShell to SharePoint. | PFM | AGENTS.md |
| 2026-11-14 | Immutable rule: nothing like network reconnaissance may occur in RADE or in any app (fixed hosts, the one site given, own flows only). Cannot be changed, like the DoD365 boundary rule. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Hard rule: users cannot write data across the DoD365 boundary through any app. Inside DoD365, RADE may read and write app data where a run type needs it. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | What works on the PFM's NIPR computer works on all, PnP.PowerShell included; no special flag on the account. Windows PowerShell 5.1 is the least always available. Rights can still differ. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Tests run on Windows PowerShell 5.1 from now on. Rounds already do; tests/run.sh runs PowerShell 7 on Linux, and how to move it is open. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-14 | RADE and the app: RADE owns the computer and the run; 90-161.Z owns the product and the site (every list, flow, setting and its data). | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Maintenance: RADE offers Install, Diagnose, Restore, Uninstall and keeps its record; 90-161.Z supplies the steps for each. Refines the 14 Nov RADE modes row. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | One preflight: RADE checks replace the Setup Check flow (Part 0); a small probe flow stays for the connector data policy and Send As. | PFM | docs/setup-and-updates.md |
| 2026-11-14 | Updates: the app shows its installed version only; RADE compares versions at each run. No central Releases list. Replaces the 12 Nov update-check row. | PFM | docs/setup-and-updates.md |
| 2026-11-14 | Bundle size limit: 600 KB (614,400 bytes), up from 300 KB. The next round times a paste of 500 KB and 1 MB; the limit is then set from that. To apply: tests/run.sh. | PFM | rhope-ops/RADE docs/DECISIONS.md |
| 2026-11-15 | Round result e-mails the app drafted ("90161Z R<NN>") go to Trash without asking once their results are on main; other result e-mails still need confirmation. Replaces 2026-11-12 for app drafts. | PFM | AGENTS.md Project rules |
| 2026-11-15 | Flow state at import is per flow: a test round imports On only the flows it needs (R22: F05, F06; F03 Off); the real deployment solution imports every flow On. | PFM | flow/solution/README.md |
| 2026-11-15 | R21 visual notes go to a separate RADE session (document now, build later); RADE does not wait for R22 results tonight. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/reviews/2026-11-15-r21-window-notes.md |
| 2026-11-14 | Two R21 builds (PR 49 and PR 50) are combined into one R21 before it runs: T19 list columns, F06 hold and resume, R20 workflow IDs kept, RADE check fix. Do not run R21 until the combined build is on main. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-14 | R21 may change the test site lists (T19 adds Status Reason, Held Since, Coordination Round and two Action Status choices; adds only). | PFM | scripts/gov/90161Z-T19-list-update-r2.ps1 |
| 2026-11-14 | Hold and resume logic is built now (F06 r1 in R21), not after the app: due dates move out by the weekdays held, logged as an extension. | PFM | flow/solution/README.md |
| 2026-11-14 | RADE repository check fix goes into R21 (User-Agent and inner error kinds), in rhope-ops/RADE with its own review (RADE PR 17). | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | (1A) Failure e-mails link to the failed run: tests/check_flow_solution.py allows the DoD portal host make.powerautomate.appsplatform.us. (2A) Old round bundles leave when the next round ships. | PFM | flow/solution/README.md |
| 2026-11-14 | RADE window P1 (RADE PR 15) ships with the flow-controls round, now R21; the RADE lock moves then. R20 leaves the build; its bundle file stays as run. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-14 | RADE modes: Install (also repairs and reinstalls; keeps data), Diagnose (read-only; names the fix), Restore (from backup), Uninstall (purges all RADE added; backup first). | PFM | docs/reviews/2026-11-14-flow-controls.md |
| 2026-11-14 | Backups: JSON (for Restore) plus a CSV copy (to read). Table A5.2 stage 6 (Formal coordination) target = 25 working days (20 coordination + 5 adjudication). | PFM | docs/reviews/2026-11-14-flow-controls.md |
| 2026-11-14 | Coordination suspense = 20 working days (weekdays; no holiday list, no hand edits). Guard/Reserve Applicability rows keep at least 30 calendar days (5.2.2). Replaces 15 = 21 calendar days. | PFM | flow/solution/README.md |
| 2026-11-14 | Set and forget: no hand steps for users. Troubleshooting starts lean (failure e-mail per flow, Resubmit, F05 adds only missing rows), tested in R21 (was R20 r2); RADE maintenance modes next. | PFM | docs/reviews/2026-11-14-flow-controls.md |
| 2026-11-14 | Action Status adds Cancelled and Complete, with Status Reason and Held Since; every flow skips On Hold, Cancelled, Complete. Cancel keeps the row; hard delete only an empty draft (PFM). | PFM | docs/reviews/2026-11-14-flow-controls.md |
| 2026-11-14 | Hold: reminders stop; on Resume open due dates move out by the weekdays held, logged as an extension. Pause, Resume, Cancel: PFM Office; the AO requests in the app. | PFM | docs/reviews/2026-11-14-flow-controls.md |
| 2026-11-14 | Coordination round number on PFM Endorsements: Restart coordination makes fresh rows (old kept); Re-run routing adds only missing offices. Test mode (pfm_TestMode) goes into R21 (was R20 r2). | PFM | docs/reviews/2026-11-14-flow-controls.md |
| 2026-11-14 | R20 = slice 1: import the solution (F05 + F03, environment variables; log reader if it fails), then an end-to-end test with 1 fake publication from step 6 to Legal and step 7. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-14 | F03: reminder 5 weekdays before the suspense; escalation 3 working days after it, copied to the AO and Requester; sent from the PFM's shared mailbox (Send As; address in an environment variable, empty = flow owner's mailbox). | PFM | flow/solution/README.md (open choice 6) |
| 2026-11-14 | Rounds hold only steps that test something not yet verified. T16 site setup (verified R17-R19) leaves routine rounds; a short step collects flow results; seals upload only when new or changed. | PFM | docs/reviews/2026-11-14-r19-results.md |
| 2026-11-14 | All text the PFM sees is professional and polished: window, guides, step notes, import instructions and flow run inputs; formatted where possible. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/window-design.md |
| 2026-11-14 | Start using rhope-ops/RADE: the engine moved there (engine/rade_build.py); this repo keeps its manifest and files, pinned by scripts/rade.lock.json. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | R18: solution import test A r4 only (lowercase workflow GUID; B dropped) plus, if A fails, a working solution export in the same round. Replaces the one-more-A/B-round row. | PFM | docs/reviews/2026-11-14-r17-results.md |
| 2026-11-14 | Logo leaves the rounds: Claude e-mails logo K, the PFM sets the site logo and thumbnail by hand; site setup still reads the header logo. Replaces the R17 T14 guide step. | PFM | docs/reviews/2026-11-14-r17-results.md |
| 2026-11-14 | RADE window: the step bar fills left to right like the overall bar (no back-and-forth block); It failed button; layout B rail with logo K. All RADE UI rules: rhope-ops/RADE docs/window-design.md. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/window-design.md |
| 2026-11-14 | Logo K yellow edge 2.8 units (K+2, master in rhope-ops/RADE). R17 r3: site logo and thumbnail file 90161Z-T14-site-logo-r4.png; site setup r8. | PFM | Logo K row above (edge 1.6, R17 r2) |
| 2026-11-14 | Logo K is the official logo for every app (blue woven mark and rho on white, blue ring, thin yellow edge); master copy and build in rhope-ops/RADE assets/logo. Swapped into R17 now (R17 r2): one file (90161Z-T14-site-logo-r3.png) for the site logo and the thumbnail; site setup r7. 90-161.Z build_logo.py and render_logo.js removed. | PFM | Site logo = variant A, bold white (row 2026-11-14) |
| 2026-11-14 | RADE engine: fast checks run fresh, only slow checks keep the 7-day reuse; modes, check stages, fallback result. Replaces the 7-day-for-all row. Built with the engine move. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/engine.md |
| 2026-11-14 | Solution import: if R17 tests A and B both fail, run one more A/B round (zip compression, connection reference) before any fallback. | PFM | docs/reviews/2026-11-14-r16-results.md |
| 2026-11-14 | Slice 1 first: hold new scope until PFM Publications + Endorsements + F05 routing + F03 reminders, list views only, take one fake publication from Coordination to Legal on the test site. | PFM | docs/phases.md |
| 2026-11-14 | Endorsers answer in the app (DAFMAN 5.4 answers). The flow only alerts them to open it; no Approvals answers. | PFM | docs/ARCHITECTURE.md |
| 2026-11-14 | No service account, ever (confirms 12 Nov 5A). Agents never suggest or ask about one again. | PFM | docs/roles-and-permissions.md |
| 2026-11-14 | Bloat audit: kit wording and values in AGENTS.md (14 days or 300 commits, kit defaults). | PFM | AGENTS.md |
| 2026-11-14 | RADE: 300 KB bundle size test now (tests/run.sh); size in the summary, hash-pinned engine and JSON results block after R17 (timing: agent REC). Schema in RADE. | PFM | https://github.com/rhope-ops/RADE/blob/main/docs/DECISIONS.md |
| 2026-11-14 | AGENTS.md "Verification" points to the ui-verify and data-change skills; the 375/1440 px UI rule stays. | PFM | AGENTS.md |
| 2026-11-14 | Add the kit files 90-161.Z never had: MIT LICENSE (holder rhope-ops), docs/WORKING_WITH_AGENTS.md, .claude/skills (data-change, ui-verify), same as RADE. | PFM | LICENSE |
| 2026-11-14 | Deployer renamed RADE (Redacted Application Deployment Engine). Folder OneDrive\RADE\90-161.Z (R17 moves the old one in); RADE\Config holds engine settings. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | RADE saves PASSED checks in RADE\Config\rade-checks.json (other apps may read it); reused for 7 days, then the PFM runs them again. Failed or warned checks always rerun. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | RADE window: every row two lines high (no movement while checks run), smoother bar animation, an Exit button. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | Site logo and thumbnail: by hand (Change the look > Header) in a guide step; site setup checks the header logo. No more logo scripts. | PFM | docs/reviews/2026-11-14-r16-results.md |
| 2026-11-14 | SharePoint admin app (drag and drop membership, bulk select, permission trees, rights pass/fail): a RADE window app (WPF/PnP) if built. Now: collect what is possible only. | PFM | https://claude.ai/artifact/5KPZmF6FbJBB41wqG22C9w |
| 2026-11-14 | R16: no new export; T17 r2 uses the T05 export values (Claude's miss: T05 was not applied). Any future capture file is shown to the PFM before it is attached. | PFM | docs/reviews/2026-11-14-r15-results.md |
| 2026-11-14 | Sprawl: targeted cuts in the R17 build, not a full audit: mask once per probe run, one shared masking function, clean-up by revision rule, drop logo fallbacks R16 shows unneeded; report before/after. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-14 | App name: 90-161.Z: Publications and Forms Management (short name 90-161.Z). The Word-open check blocks a deploy (1B); other warnings do not. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | No deploy unless every check passes (FAILED or NOT RUN blocks; WARNING does not; no "deploy anyway"). Check text: sentence case, screen names in "quotes", reported values in [brackets]. | PFM | https://claude.ai/artifact/RY4rWNuBP3rwAai9v3uWD8 |
| 2026-11-14 | Plain-English sweep: go.md and Deployer step notes in R16; each flow, package and solution at its next revision. Deployer first screen stays minimal. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | All text the PFM or a user sees (Deployer window, packages, imports, descriptions, subtitles) is plain, simple English. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | Deployer window: Choose app > Check > Deploy; embedded catalog only (3A stays); two bars (PROGRESS lines, else time); checks: computer, network, site rights (PnP sign-in), Power Automate. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
| 2026-11-14 | R15: solution XML comes from a real export (PFM makes one, Deployer masks and sends the XML); site setup sets header logo and thumbnail apart; probe r5 grants the coworker's user ID. | PFM | docs/reviews/2026-11-14-r15-results.md |
| 2026-11-14 | Site logo = variant A, bold white (lines 60% thicker than r1; replaces option D's header logo). Thumbnail stays navy, same bold lines. | PFM | https://claude.ai/artifact/AZUqwxiPwSruC65eH1uhHx |
| 2026-11-14 | Wing users have only Read on the site; anyone using the app enters data through it. Open: how the app writes (list-level rights or a flow), see NEXT_PROMPT. | PFM | docs/reviews/2026-11-14-r13-results.md |
| 2026-11-14 | The Deployer delivers every file a round needs (no separate downloads) and guides steps done in another program (R13: probe flow import); its log text reads professionally. | PFM | docs/reviews/2026-11-14-r12-results.md |
| 2026-11-14 | Passed steps (T01 render test, T15 inventory) run in a round only when their files changed since the round that last passed them (hash in scripts/paste_bundles.json); still tickable by hand. | PFM | https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py |
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
| 2026-11-13 | Round e-mails: Claude watches Gmail for the round subject every 10 min for up to 2 h after a round goes live (no chat message needed). Replaced 2026-11-15. | PFM | AGENTS.md Unattended work |
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
| 2026-11-13 | Screen map: (26A) UI text in app code. (27A) one responsive app. (28A) My Work home. (29A) Action Status open to all. ("No previews" withdrawn 15 Nov.) | PFM | docs/app/screen-map.md |
| 2026-11-13 | Phase 4 (25A): screen map first (docs/app/screen-map.md). Clickable previews restored 15 Nov. | PFM | docs/app/screen-map.md |
| 2026-11-13 | Periodic bloat, drift, duplication and assumption checks in every repo; question tool for 1-4 questions. | PFM | archive |
| 2026-11-13 | Bloat audit: 14 days or 30 commits; 12,000 tokens; +25% timing (1A). Other repos (2B). Sync after check: mil (3A). Audit next (4A). | PFM | archive |
| 2026-11-13 | Gov-device usability bar for go.md and runner windows; results folder Rounds\\<round>, no zips. | PFM | archive |
| 2026-11-13 | Backups: (22A) row history, recycle bin, chapters; PFM Office rolls back. (23A) 8 weekly + 12 monthly. (24A) e-mails: new task, due date; rest weekly. | PFM | docs/backup-and-restore.md |
| 2026-11-13 | (19A) weekly digest per person, Wed 0700 Central. (20A+) weekly backup, chapters, in-app rollback. (21A) weekly disabled-account list. | PFM | docs/decisions-archive.md |
| 2026-11-13 | RADE: (R1A) code embedded. (R2A) v1: file bridge, one agent flow. (R3A) repo rade. (R4A) PFM runs v1. (R5B) no other app first. (R6A) zip by e-mail. | PFM | https://claude.ai/artifact/GLdT7Nr4aVn3EenyYnAuJF |
| 2026-11-13 | ISSM ruling: scripts without elevated credentials may be pasted and run in PowerShell ISE. No elevation, admin credentials or RunAs. | PFM | archive |
| 2026-11-13 | Logo: woven square-in-a-square mark with a serif Greek rho, white and light blue for blue backgrounds (assets/logo, built by scripts/build_logo.py). | PFM | assets/logo/ |
| 2026-11-13 | Site visuals (pages, header, list looks) by Power Automate flow, built after the T11 rights results; home page as a preview first. | PFM | docs/NEXT_PROMPT.md |
| 2026-11-12 | Package: (15A) folders by permission. (16A) attachments off; metadata ties files. (17A) Document Role suggested. (18A) originals stay. (4) test zip. | PFM (15A 16A 17A 18A+, 4 test) | docs/roles-and-permissions.md |
| 2026-11-12 | (10A) Acting PFM leaves next weekday after Acting Until. (11A) PFM or Alternate names Acting PFM. (12A) covers to CSV. (13A) PFM Office owns itself. (14B) intake. | PFM | docs/roles-and-permissions.md |
| 2026-11-12 | (4A) PFM, Alternate, Acting PFM, Acting Until in PFM Settings. (5A) connection references. (6A) Acting PFM full rights. (7A) PFM Office group. (8A) intake. (9A) library. | PFM | docs/roles-and-permissions.md |
| 2026-11-12 | Phase 1 (1A): ISE runner only runs and tests gov-device code; lists and permissions stay in flows. (1B) no PnP setup path. (2A) Phases 2 and 3 together. (3A) Phases 5-9 added. | PFM (1A, conditional; 1B 2A 3A); Agent | docs/decisions-archive.md |
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
