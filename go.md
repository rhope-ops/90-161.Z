# 90-161.Z: tasks for my work computer

Updated: 18 Nov 26 (Round R30a and R30b are open).
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

## Open tasks

### Round R30a r1 (run first): the flow steps again, with a Power Automate check first

**For:** runs again the flow steps that failed in R29a on Power Automate errors: the health flow, the button flow I make by hand and the export reader, the list button, the import of the full flows and the full flow test. A first step checks that Power Automate shows my connections. The logo and the second person passed in R29a, so they do not run again.
**Time:** about 2 hours with waits; about 60 minutes of my own work (estimate).
**Changes:** on the test site: a probe list and library, fake rows and a list view are made and removed again at the end; the full test rows are moved to the site Recycle Bin at the end. In Power Automate: "90-161.Z probe health" is imported and "90-161.Z probe button" is made by me, and both are deleted at the end; the solution "90-161.Z flows" is upgraded and stays. On my computer: my OneDrive folder RADE\90-161.Z and one export file in Downloads. Before Run, the window lists every file.
**Steps:**
1. Press Copy script next to the link below.
2. Open the Start menu.
3. Type: ISE
4. Open Windows PowerShell ISE (not "Run as administrator").
5. Select File > New.
6. Click in the white script pane.
7. Press Ctrl+V.
8. Press F5. The RADE window opens.
9. If the window shows a button "90-161.Z: Publications and Forms Management", select it.
10. Press Run.
11. Do each step the window shows, until the log says DONE.
12. At DONE, send the Outlook draft that opens.

https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R30a-round-r1.ps1

**Report:** send the Outlook draft the round makes (subject "90161Z R30a PASSED" or "90161Z R30a NEEDS REVIEW", every file in the results folder attached). Then tell Claude the e-mail is sent.
**If it fails:** do the line that starts with "What to do". If Power Automate shows an error, wait 5 minutes, reload the page and try 1 more time; then select "It failed" and type only the line that starts with "Error".

### Round R30b r1 (run after R30a): my 90-161.Z window r4

**For:** tests the fixes from my R29b screenshots (the "Your Work" line, the "See the 0 findings" link, the Action Status card and the Full History button), high contrast through Windows Settings, and a script check that every control has a name for Narrator. Then 5 questions on its look.
**Time:** about 20 minutes (estimate).
**Changes:** nothing on the test site or in Power Automate. On my computer: the T22 folder in my OneDrive folder RADE\90-161.Z (the window scripts and their result file). For 2 checks I turn high contrast on and off again in Windows Settings. All data in the window is FAKE; nothing is read, saved or sent. Before Run, the window lists every file.
**Steps:**
1. Press Copy script next to the link below.
2. Open the Start menu.
3. Type: ISE
4. Open Windows PowerShell ISE (not "Run as administrator").
5. Select File > New.
6. Click in the white script pane.
7. Press Ctrl+V.
8. Press F5. The RADE window opens.
9. If the window shows a button "90-161.Z: Publications and Forms Management", select it.
10. Press Run.
11. Do each check in the bar at the bottom of the 90-161.Z window.
12. Close the 90-161.Z window with its X.
13. Answer the 5 questions in the RADE window (3 cards, then 2).
14. At DONE, send the Outlook draft that opens.

https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R30b-round-r1.ps1

**Report:** send the Outlook draft the round makes (subject "90161Z R30b PASSED" or "90161Z R30b NEEDS REVIEW", every file in the results folder attached). Then tell Claude the e-mail is sent.
**If it fails:** do the line that starts with "What to do". If the 90-161.Z window does not open, send the results as they are.

## Done

- Round R29a r5 (18 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK. Passed: the second person saved a row on the test list (T4, the first pass); the new 90-161.Z logo is the site logo and thumbnail; the test site was clean at the start and at the end. Failed: 3 Power Automate steps, each with a portal error about connections ("try again later"): the health flow import, the button flow I make by hand, and the full flow import. Skipped: 17 steps that needed them, the full flow test included. The flow fixes are still untested and run again in the next round:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-18-r29a-results.md
- Round R29b r6 (18 Nov 26, second run): needs review. Window checks 9 of 12 (Narrator off now passes); the same 2 contrast checks and the Narrator names check fail; my 4 screenshots are 4 look defects, fixed in R30. Details are in the same file as r5.
- Round R29b r5 (18 Nov 26): needs review. Checks 9 of 9, shared files 4 of 4, Window OK. Passed: my 90-161.Z window now scales with Windows, its self-check found 0 defects on 17 cards, and Tab, Shift+Tab, Enter and the cards work. Failed: the 2 high-contrast checks (Print Screen is a second function on my right Shift key) and 2 Narrator checks (Narrator said nothing). Skipped: the 3 look questions. My 3 notes are in the details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-18-r29b-results.md
- Round R28 r2 (17 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK. Passed: the R27 and R28 test items are all removed from the test site; the probe list 6 of 6; the second person added to Visitors; I made and exported the button flow; the form header set by script. Failed: the health flow (Power Automate has no action that lists flow runs), the export reader (it did not find the flow name), my 90-161.Z window (its self-check stopped on every card and it ran unscaled), the full flow import (the "deactivated and replaced" message is the normal upgrade message, but the card did not say so). Skipped: the second person's row (T4) and the full flow test. My 7 notes are in the details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-17-r28-results.md
- Round R27 r1 (16 Nov 26): needs review. Checks 14 of 14, flows import confirmed, slice part 1 8 of 8, part 2 14 of 14, shared files 4 of 4, Window OK. Passed: the flows read PFM Settings, test e-mails have no "[TEST]" and the F03 e-mail was in my Inbox after 1 minute. Failed: the probe flows did not save (one names a trigger SharePoint does not have), the app file ("does not contain any components"), Excel (no Automate tab). Skipped: the second person (T4) and the clean-up, so the probe list, library, solution and the second person in Visitors are still on the test site. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-17-r27-results.md
- Round R26 r2 (16 Nov 26): passed. Checks 14 of 14, probe list 8 of 8, import confirmed, clean-up 2 of 2, shared files 4 of 4, Window OK. Passed: T2 (draft in Word for the web), T3, T5, T6, T7 (person box), T9 (e-mails without "[TEST]" arrive at once), T10 (signed PDF attached). Failed: T4 (the second person saw "No permission"), T8 (a flow cannot list the people of a shared mailbox). My window: close, with small changes. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-16-r26-results.md
- Round R26 r1 (15 Nov 26): needs review. Probe list made 7 of 7, probe solution imported, flow tests ran. Passed: T3 (forms by a flow), T5 (final copy by a flow), T6 (fields to columns). Failed: T9 (3 sends worked, no e-mail seen in the Inbox). Refused: the Word solution (Premium licence), the Mail solution, AI Builder. Not run: T2, T4, T7, T8, T10, because the PDF viewer block was refused and the app steps were skipped. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-16-r26-results.md
- Round R25 r1 and "Clean the test site" (15 Nov 26): the clean install passed. Clean check 7 of 7, 12 lists by PnP 15 of 15, site setup 6 of 6, import confirmed, test part 1 7 of 7, test part 2 12 of 12, shared files 4 of 4, Window OK. Did not pass: the F03 test e-mail (not found, fifth round), the failure e-mail (it arrived late), restore after minimize, alignment on the first card. Details:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-15-r25-results.md
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
