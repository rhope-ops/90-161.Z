# 90-161.Z: tasks for my work computer

Updated: 16 Nov 26 (Round R26 is open: the easy-path probe, tests T2 to T10).
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

## Round R26 r1: the easy-path probe (open, 16 Nov 26)

**For:** R26 tries the easy way for 9 parts of my 13-step process (tests T2 to T10) on the test site with fake data, so that no fallback is designed before its easy way has run once. Each test reports one PASSED or FAILED line that names what was tried. T9 is also the fix path for the F03 test e-mail that was not found in 5 rounds: 4 test e-mails go out at once and a flow reads my Inbox, my Junk folder and the Sent Items of the PFM office mailbox.
**Time:** about 75 minutes (estimate), about 55 of them at the keyboard: checks 2, probe list 2, 3 imports 16, import log check 1, AI Builder look 3, flow tests 15 (waiting), build the test app 15, app tests 10, second person 5, read 3, remove 5.
**Changes:**
- On my computer: RADE writes into T17, T21 and Rounds\R26, and moves old round files to the Recycle Bin.
- On the test site: 1 list "90161Z Probe" and 1 library "90161Z Probe Files" with fake files and rows. The site's visitors get Contribute on that list only. Both go to the site Recycle Bin at the end.
- In Power Automate and Power Apps: up to 3 small solutions ("90-161.Z probe", "90-161.Z probe Word", "90-161.Z probe Mail"; 5 flows in all), 1 plain test app "90161Z T21 Probe r1", and up to 4 new connections (OneDrive for Business, Office 365 Users, Office 365 Groups, and Word or Mail if the tenant allows them). I delete them in the last step.
- In my OneDrive: a folder "90161Z-probe" with temporary fake files (the flows delete the files).
- E-mail: up to 4 test e-mails for each run of the flow tests step, subject "[TEST] 90161Z T9", to my own address only. RADE saves one Outlook draft (never sent).

Steps:
1. Press Copy script next to this link (if it says blocked: open the link, Ctrl+A, Ctrl+C).
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R26-round-r1.ps1
2. Start menu: type ISE, open Windows PowerShell ISE. Select File > New, click in the white pane, press Ctrl+V, then F5.
3. In the RADE window, choose the application, select the button that runs the checks, then select Run.
4. RADE makes the probe list and library (about 2 minutes, estimate).
5. At each of the 3 import steps: do the steps the window lists. The Word and Mail imports can be refused on our tenant: then type the first line of the error and select "It failed". A refusal is a result.
6. At the AI Builder step: look in Power Automate as the window says and answer 1 question.
7. Wait while RADE runs the flow tests (about 15 minutes, estimate). I do not open Outlook for this.
8. At the app step: make the blank app, add 1 form and paste the 6 code blocks, as the window lists. The code file opens in Notepad.
9. At the app tests step: select 2 buttons, do 1 search, look at the draft, sign the fake PDF with my CAC and attach it. Answer 3 questions.
10. At the second-person step: a person with only Read on the test site opens the app and selects 2 buttons (about 5 minutes for that person). If nobody is free: select Skip.
11. RADE reads the results and moves the probe list and library to the site Recycle Bin.
12. At the last step: delete the solutions, the app, the OneDrive folder and the test e-mails, as the window lists.
13. Wait for DONE. RADE opens an Outlook draft. Send it as it is: every answer is already in it.

RADE does steps 4, 7 and 11 and all checks. Steps 5, 6, 8, 9, 10 and 12 need a person: Microsoft has no supported way to import a canvas app built outside Power Apps, and an import needs my connections.

**Report:** the draft itself, subject "90161Z R26". It holds the report file and the result files of T21 (make, run, app, clean), and the import log file (T17) if an import failed. The files hold field names, counts and status codes only.
**If it fails:** read the "What to do" line in the window. If a step fails, send the draft as it is: the failed line is the result. Every RADE step can be run again. If the round stops before step 11, run it again and tick only "T21 Remove the probe list and library r1", then do step 12.

## Done

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
