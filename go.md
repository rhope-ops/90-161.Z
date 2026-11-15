# 90-161.Z: tasks for my work computer

Updated: 15 Nov 26 (R24 passed. Open: "Clean the test site", then Round R25 r1: clean install, about 60 minutes).
rhope-ops.github.io/90-161.Z
Fallback (plain text):
raw.githubusercontent.com/rhope-ops/90-161.Z/main/go.md

Every task below has the same parts: **For** (why), **Time** (an estimate), **Changes** (what it writes or changes, before I start), **Steps**, **Report** (what to send back) and **If it fails**.
Reload this page to see new tasks (GitHub can serve a copy up to 5 minutes old).
Never send real publication content, names, site addresses or group names. Reply in the Claude chat or by e-mail.

## How a paste task (round) works

**For:** a round is one block of text I paste into PowerShell ISE. It opens the RADE window (Redacted Application Deployment Engine, formerly the 90-161.Z Deployer), saves its own files, runs the tests and makes the results e-mail. The ISSM allows this for scripts that use no elevated credentials (13 Nov 26).
**Changes:** it writes only into my own OneDrive folder RADE\90-161.Z (the window shows the full path in bold): the task folders it needs (for example T01), Config and its results folder Rounds\<round>. RADE\Config holds RADE's own settings: the results e-mail address and the saved checks (rade-checks.json: checks that passed are not run again for 7 days). From R17 on, RADE moves my old OneDrive folder 90-161.Z into RADE once, when I select Run (one folder move; every file keeps its place). It makes missing folders and replaces files of the same name. From R06 on it also moves finished files to the Recycle Bin (only files 90-161.Z made). Before Run, the window lists every file, marked New, Replace or Recycle. Every file a task needs comes inside the round: there are no separate downloads (14 Nov 26). A step marked "(needs you)" opens a small window with numbered steps for work in another program, such as a flow import.
Steps:
1. Press Copy script next to the round's link in its task below. If it says blocked: open the link, press Ctrl+A, then Ctrl+C.
2. Start menu: type ISE and open Windows PowerShell ISE as myself (not "Run as administrator").
3. File > New. Click in the white script pane. Press Ctrl+V, then F5.
4. The RADE window opens. Check the bold "Writes to" line: it shows my OneDrive RADE\90-161.Z folder, or says NOT found. The first time, type the e-mail address the results go to in "Send results to" (it is remembered).
5. Press Enter (or Run). Word steps take a few minutes each. Keep the window open until the log says DONE. Exit closes the window (it asks first while a step runs).
6. At DONE an Outlook draft opens with the address, the subject (PASSED or NEEDS REVIEW), the summary and all result files. Send it. If no draft opens, the results folder opens and the e-mail text is on the clipboard: new e-mail, Ctrl+V in the body, cut the first line into the subject, drag in all files from the folder. No zip: zips do not cross the boundary.
**If it fails:** the window shows a line that starts with "What to do" under the problem: do that. Otherwise send the line that starts with STOPPED. The report file in Rounds\<round> also holds it. Do not work around it. If no window opens, the same steps run as text in ISE and the results folder opens by itself.
The script never sends the e-mail; the draft waits in Outlook. Finished task folders are cleaned up by the rounds; a later round makes any folder it needs again. Keep T07 if it holds 90161Z-T07-key-r1.txt (rounds never touch it).
Sensitivity label: every render gets the label from Config\90161Z-label.json. Never delete the Config folder: without it, renders print "LABEL not set" and have no label. The file I labeled by hand is no longer needed. If Config is lost, run a round, then capture again from its new render (it is already labeled); label a file by hand again only if renders say LABEL FAIL.

## Clean the test site (open, 15 Nov 26; do this before Round R25)

**For:** R25 installs 90-161.Z from zero, the way another wing will. So everything the test rounds made on the test site and in Power Automate must go first. I chose to delete it by hand (15 Nov 26).
**Time:** about 20 minutes (estimate).
**Changes:** it deletes the items below, and only those. Lists and the library go to the site Recycle Bin and can be restored for 93 days. Deleted flows and solutions cannot be restored; R25 imports the flows again. Nothing on my computer changes.

Steps:
1. Power Automate > Solutions > open "90-161.Z flows". Select each of these, then Delete > "Delete from this environment", in this order: the 3 cloud flows ("90161Z F03 Suspense Reminders r5", "90161Z F05 Endorsement Routing r2", "90161Z F06 Hold and Resume r1"); the 13 environment variables (names start with pfm_); the 2 connection references ("SharePoint" and "Office 365 Outlook"). Then go back to Solutions and delete the solution "90-161.Z flows". Reason: deleting a solution alone leaves its parts behind.
2. Do the same for the solution "90-161.Z solution import test A" (its flow is "90161Z T17 Solution Import Test A r5") and for any other solution whose name starts with "90-161.Z" (for example "90-161.Z solution import test B").
3. Do the same for my two sample solutions, if they still exist: "90161ZT05SolutionSample" and "90161ZExportSample".
4. Power Automate > My flows: delete every flow whose name starts with "90161Z" (the T02 Provision Lists flows, the T11 Rights Probe flows, the T03 and T04 test flows).
5. Test site > Site contents: delete these 12 lists: PFM Offices, PFM Series, PFM Process Steps, PFM Settings, PFM Guidance, PFM Product Index, PFM Publications, PFM Waivers, PFM Activity Log, PFM Endorsements, PFM Recommendations (DAF Form 847), PFM Reviews. Delete the library "90-161.Z" too (R25 makes it again and uploads the 34 seals from my T07 folder). If a list or library named "PFMRightsProbeTEST" or "PFMRightsProbeLib" is there (left by a stopped rights probe), delete it too.
6. Test site > Documents: delete the files whose names start with "90161Z-T11-rights-result" and "90161Z-T17-solution-result".
7. Test site > Site permissions: there is no 90-161.Z group to delete. Only if a group named "PFM Rights Probe TEST" exists, delete it.
8. Keep: my connections in Power Automate, the site time zone, the site logo, and the RADE folder on my computer. Do not empty the site Recycle Bin.

**Report:** nothing to send. R25 checks the site itself and names anything that is left.
**If it fails:** if an item cannot be deleted, leave it and start R25: its check step names what is left, and I send that result.

## Round R25 r1: clean install from zero (open, 15 Nov 26)

**For:** R25 proves that RADE can install 90-161.Z on a clean site without the provisioning flow: it builds the 12 lists by PnP, sets up the site, and I import the flows and RADE tests them on the new lists. It is the first round on RADE engine-v6: questions are answered in the window (no notes in the e-mail), a minimized window comes back from the taskbar, every line of a card starts on one edge, and RADE draws its own button borders. These window fixes are proven only on my computer, so the last step asks me about them.
**Time:** about 60 minutes (estimate): checks 2, clean-up confirm 1, clean check 1, lists 5, site setup 4, import 7, import log check 1, test part 1 12, failure e-mail 4, F03 run 3, test part 2 12, e-mail question 2, window questions 2.
**Changes:**
- On my computer: RADE writes into T16, T17, T18, T20 and Rounds\R25, and moves old round files to the Recycle Bin.
- On the test site: 12 new lists with 88 seed rows; the library "90-161.Z" with the 34 seals; three fake publications and their rows, which are moved to the site Recycle Bin at the end.
- In Power Automate: the solution "90-161.Z flows" is imported (F03 r5, F05 r2, F06 r1).
- E-mail: test e-mails go only to my alert address, from my own mailbox in this round. RADE saves one Outlook draft (never sent).

Steps:
1. Do the task "Clean the test site" above first.
2. Press Copy script next to this link (if it says blocked: open the link, Ctrl+A, Ctrl+C).
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R25-round-r1.ps1
3. Start menu: type ISE, open Windows PowerShell ISE. Select File > New, click in the white pane, press Ctrl+V, then F5.
4. In the RADE window, choose the application, then select the button that runs the checks.
5. Select Run. At the first step, select "Done: site is clean" and answer its question.
6. Wait while RADE checks the site, builds the lists and sets up the site (about 10 minutes, estimate). If the check step fails, it names what is left: delete that, then start again at step 2.
7. When the window shows the import step: do the steps it lists. Leave "3 Shared mailbox" empty. Then answer its 2 questions in the window.
8. When the window shows the Resubmit step and the F03 step: do the steps each lists.
9. At the e-mail step, look for the e-mail "[TEST] Escalation" in Outlook and answer where it is.
10. At the last step, minimize the RADE window, bring it back from the taskbar, and answer its 4 questions about the window.
11. Wait for DONE. RADE opens an Outlook draft. Send it as it is: every answer is already in it.

**Report:** the draft itself, subject "90161Z R25". It holds the report file and the result files (T20 check, T20 lists, T16, T18 part 1, T18 part 2), and the import log file (T17) if the import failed.
**If it fails:** read the "What to do" line in the window. If a step fails, send the draft as it is: the failed line is the result. The list step can be run again; it skips what is there. If it stops with "already exists", empty the 12 PFM lists from the site Recycle Bin (this cannot be undone) and run the round again. The provisioning flow (Task 2 in Done) stays the fallback.

## Done

- Round R24 r1 (15 Nov 26): passed. Checks 14 of 14, list check 6 of 6, import confirmed, test part 1 7 of 7, test part 2 12 of 12, shared files 4 of 4, Window OK. First run of RADE engine-v4 on my computer. My notes (label order 1, 3, 4, 2; no answer box; minimize; window look; e-mail not found) are in the details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-15-r24-results.md
- Round R23 r1 and r2 (15 Nov 26): passed two times. Checks 9 of 9, inventory PASSED, shared-file self-test 4 of 4, Window OK. RADE engine-v2 works in Windows PowerShell 5.1 on my computer. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-15-r23-results.md
- Round R22 r3, second run (15 Nov 26): passed, every step PASSED (checks 14 of 14, T19 6 of 6, part 1 7 of 7, part 2 12 of 12, F03 confirmed, Window OK). First run of the engine-v1 guardrails on my computer. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-15-r22-results.md
- Round R22 (14 Nov 26): slice 1 passes end to end. List check 6 of 6, test part 1 7 of 7, test part 2 12 of 12, Window: OK. The F03 step was answered "failed", but the test proves the run worked (suspense 11 of 11 rows, 1 escalation); its wording gets fixed. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-15-r22-results.md

- Round R21 (14 Nov 26): needs review. Slice 1 worked end to end (routing, hold, failure e-mail and Resubmit, missing row, F06 hold, resume and cancel, Legal, step 7). Two fixes go to R22: T19 could not read the Action Status choices, and F03 set the suspense 1 working day late on a Saturday run. The F03 "error" was most likely the normal skip note. Window: NOT OK (notes for a RADE window pass). Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r21-results.md

- Round R20 (14 Nov 26): needs review. The window worked (Window: OK). The solution imported, but F03 did not turn on ("Update item" needs Title) and F05 made no Formal Coordination rows; the repository warning stays. R21 fixes F03 and checks that F05 is on. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r20-results.md

- Round R19 (14 Nov 26): passed. Test solution A r5 imported and its flow ran (connection reference OK, 7 settings rows read): solution-aware flows work here. Site setup passed for the third time and leaves routine rounds. The repository warning has a fix in R20. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r19-results.md
- Round R18 (14 Nov 26): needs review. Import test A r4 failed again (the pasted error held only the start of the log); I exported a working solution and attached its files by hand, because the export reader looked only in Downloads; site setup r9 passed (6 of 6); the window worked after the Next fix. R19 copies the export's layout. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r18-results.md
- Round R17 (14 Nov 26): needs review. RADE moved the folder and the window worked (Window: OK); both solution imports failed with "workflow not declared as a root component" (the variable is not the cause), logged as skipped because the window had no failed answer; site setup r7 passed (6 of 6). R18 fixes the import (lowercase ID) and adds the It failed button. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r17-results.md
- Round R16 (14 Nov 26): needs review. The solution import failed again with the same XML error (skipped); the probe gave the coworker's own user Contribute on a test list and it worked (list-level rights for app users are possible); the logo calls failed again, so the logo is set by hand from R17. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r16-results.md
- Round R15 (14 Nov 26): needs review. Probe r4 and site setup r4 ran; the solution import stopped with an XML error (skipped); the header logo was not set and the thumbnail got the header file; the Contribute test found no group to test. All three go into R16. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r15-results.md
- Round R13 (14 Nov 26): passed. Probe flow r3 imported and run from the Deployer window (no separate download); 17 of 17 seals prepared and uploaded with the prepared copies (34 files); site setup 0 problems. Task 11 is complete (Part A in R13, Part B in R12). The logo still needs work (only a thin white border shows). Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r13-results.md
- Round R12 (14 Nov 26): window, inventory, renderer, PnP test passed; site setup set the time zone (Central) and the logo, item-level permissions were already right, 12 lists and 88 rows counted; Task 11 Part B finished (17 of 17). Seal prep found no seal e-mails and the seals upload failed: fixed in R13. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r12-results.md
- Task 2, the 12 lists on the new site (14 Nov 26): R11 counted 12 PFM lists there. Round R12 sets "edit own rows" and the time zone by script and counts lists and rows, so I do not read the flow result.
- Task 14 and Task 7 Part B (14 Nov 26): moved into Round R12 (logo, Seals folder, upload, prep). Claude corrected the 17 seals and sent them in 6 e-mails "90161Z T07 seals r1".
- Task 10, decision briefs (14 Nov 26): R11 checked all 3 (overflow 0, past-edge 0) and I opened them in PowerPoint: they open normally. Closed.
- Round R11 (13 Nov 26): window, inventory (142 items), renderer, brief check (3 of 3), PnP on the new site (manage lists, site and permissions; 12 PFM lists) passed; the Outlook check stopped (E_ABORT, the Outlook access prompt): R12 moves it into the probe flow. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r11-results.md
- Round R10 (13 Nov 26): window, inventory, renderer, brief check (3 of 3), PnP web login passed; Task 9 pages (3 of 3) and Task 12 documents (3 of 3) received; Task 11 form worked (2 of 18 rows answered). Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r10-results.md
- Task 9, e-Publishing pages (13 Nov 26, in R10): 3 of 3 saved with the list; Claude writes the reader next.
- Task 12, color sources (13 Nov 26, in R10): 3 of 3 documents received; Claude reads the colors next.
- Round R09 (13 Nov 26): window, inventory, renderer and PnP retest passed (PnP web login connected with full list rights); downloads were blocked, Task 9 names did not match, the Task 11 form stopped: fixed in R10. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-14-r09-results.md
- Round R06, Deployer and cleanup (13 Nov 26): 4 of 4 pass; Copy script worked; cleanup recycled 4 files and 1 folder; the draft opened; the window did not (text mode), fix in R08. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-13-r06-results.md
- Round R05, Outlook draft (13 Nov 26): 4 of 4 pass; the draft opened with subject, summary and both files; the Window line came back empty (R06 uses a checkbox). Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-13-r05-results.md
- Round R04, quicker finish and DAFMAN link style (13 Nov 26): 4 of 4 pass; summary subject and clipboard worked; ACCESSIBILITY link now bold, blue, underlined like the DAFMAN cover link; seal prep r2 saved in T07. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-13-r04-results.md
- Round R03, renderer fixes (12 Nov 26): 4 of 4 pass; TOC 1.50 / 2.00 in the PDF; label set; ACCESSIBILITY link works. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-13-r03-results.md
- Round R02, automatic sensitivity label (12 Nov 26): label set by itself (PDF Uncontrolled/General); TOC positions right in the PDF (1.50 / 2.00 in), the Word read-back was wrong and is replaced by a PDF check. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-13-r02-results.md
- Round R01, renderer round 2 and fake-seal test (12 Nov 26): window, steps and results folder worked; seal top 1.472 in (want 1.47); TOC number 1.50 in and text 2.00 in in the PDF; cover gaps within 0.01 in of DAFMAN. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-13-r01-results.md
- Task 6, GenAI.mil extraction r1 (11 Nov 26): GPT and Gemini both 12 of 12 content checks; GPT had fewer errors. Grok dropped (too slow, 11 Nov 26).
- Task 2, create the lists r9 (11 Nov 26): pass on the real site. Lists: 9, fields and views: 213, rows: 41, updates: 15.
- Task 5, solution export sample (11 Nov 26): export received; Claude uses it for solution-aware flows. The flow used a SharePoint connection reference from another solution; future packages carry their own.
- Task 1, renderer test r3 (11 Nov 26): pass (checks 1-6). Fixes in r5: (T-3) line break, cover spacing, table of contents style.
- Task 2, create the lists r1 (11 Nov 26): import and run ok, four lists created, but on the wrong site and before names were agreed (r2 replaces it).
- Task 1, renderer test r2 (11 Nov 26): runner and validator ok; Word save failed (fixed in r3).
- Task 4, SharePoint connection test r2 (11 Nov 26): import ok, existing SharePoint connection ok, run passed (Item count showed items read).
- Task 3, flow import test (11 Nov 26, 0840): raw zip link, Import Package (Legacy), run passed ("Echo compose" showed the expected text).
