# 90-161.Z: tasks for the work computer

Updated: 25 Nov 26 (R42 r2 is ready).

## Open tasks

### Round R42 r2: window r15, an endorser answer, a small sign-in window and Restore

**For:** tests the R41 fixes: the 90-161.Z window r15 (room for the scroll bar; the screens Waves and Step 13 open), an endorser answer from a second person, a small CAC sign-in window for Back up and Restore, and RADE Restore of fake rows with the old row numbers.
**Time:** about 40 minutes, with about 5 minutes of a second person from the office (an estimate).
**Changes:** on the computer, the OneDrive folder RADE\90-161.Z: scripts and result files in T21, T22 and T26, 17 screen pictures, and one backup of the 12 test site lists. The old files of T21 r11, T22 r14 and T26 r1 go to the Recycle Bin. The Repair saves a new copy of RADE for the RADE shortcut. On the test site: a test list and library, the second person in the Visitors group, one fake publication and fake endorsement rows. The last steps of the round move them to the site Recycle Bin.
**PFM:** the person who runs this task.
**Keep:** the folder RADE\Config (it holds the sensitivity label for renders) and, in T07, the file `90161Z-T07-key-r1.txt`. Rounds do not touch them.
**Steps:**
1. Ask one person in the office to help with this task, and write down the e-mail address of that person.
2. Below **Summary** on this page, click **Open the script**. The script opens as plain text.
3. On the script page, press `Ctrl+A`, then `Ctrl+C`.
4. From the Start menu, open **Windows PowerShell ISE** (not **Run as administrator**).
5. In ISE, click **File** > **New**, then press `Ctrl+V`.
6. Press `F5`. Wait until the window **RADE** opens (up to 2 minutes).
7. If no window opens and text runs in ISE, stop and post `No RADE window` in the Teams channel **RHOPE-OPS**.
8. In the window **RADE**, click the row **90-161.Z 0.1.0**, then the button **Maintenance**, then **Repair**.
9. If the card **One check needs you.** shows, click the button on the card and do what the card says.
10. If the card **One check failed.** shows, do the line that starts with **What to do**, then click **Run checks again**.
11. If the card **One check failed.** shows again, stop and post the first 10 words of the card in **RHOPE-OPS**.
12. On the card **Ready to install 90-161.Z 0.1.0.**, click **Install**. Wait until an end card shows (up to 5 minutes).
13. If the end card is not **90-161.Z 0.1.0 is installed.**, stop and post the first 10 words of the card in **RHOPE-OPS**.
14. Click **Close**. In ISE, press `F5`. Wait until the window **RADE** opens again.
15. Click the row **90-161.Z R42**. Wait until a card shows (up to 2 minutes).
16. If the card **One check needs you.** shows, click the button on the card and do what the card says.
17. If the card **One check failed.** shows, do the line that starts with **What to do**, then click **Run checks again**.
18. If the card **One check failed.** shows again, or **Your OneDrive folder was not found.** shows, stop and post the first 10 words in **RHOPE-OPS**.
19. On the card **Ready to run round R42.**, click **Run** (or **Resume at step**, if it shows).
20. Each time a CAC sign-in window opens, sign in. The next cards come in any order and can repeat.
21. Each time the card "Insert your CAC, then select Resume." shows, insert the CAC, then click **Resume**.
22. On each card with numbered lines, do the lines, then click **Done** (or **It failed**, if a line fails). On each question, click the answer.
23. On a card with a box, type one line with no names, then click **Continue**.
24. When the small window **90-161.Z test T4** asks for an e-mail address, type the address that you wrote down, then click **OK**.
25. If the second person cannot help today, click **Skip** on the card **Ask the second person to answer the endorsement**.
26. On **Screen 10 of 17**, write down `Yes` if the grid **Wave 1 answers** shows the second person, else `No`.
27. In the window **Publications and Forms Management**, do what each line of the bottom bar says, then click **Pass** or **Fail**.
28. When a card asks about **Screen 10 of 17**, click the answer that you wrote down: **Yes** or **No**.
29. When the bar shows "All checks done. Close this window with its X.", close the window **Publications and Forms Management**.
30. When the round ends, wait until an Outlook draft or the results folder opens (up to 2 minutes).
31. If a draft opened and **To** is empty, type the e-mail address of the PFM. Click **Send**.
32. If no draft opened, the e-mail text is on the clipboard. In Outlook, start a new e-mail, click in the body, then press `Ctrl+V`.
33. If you started a new e-mail, type the e-mail address of the PFM in **To**. Move the first line of the body to **Subject**.
34. If you started a new e-mail, attach every file of the results folder, then click **Send**.

**Report:** the e-mail of the round, with the subject `90161Z R42 PASSED` or `90161Z R42 NEEDS REVIEW` and every file of the results folder.
**If it fails:** on the card, do the line that starts with **What to do**. If the card **The round stopped.** shows, or red text shows in ISE, post the first 10 words in the Teams channel **RHOPE-OPS**. **Record (F2)** at the bottom of the window **RADE** shows all checks, steps and the log.

## Done

- Round R41 r1 (21 Nov 26): needs review. Checks 12 of 12, Window OK, 19 of 24 steps passed. Passed: the probe list, the second person, Back up and Restore of 4 fake rows in a second RADE window, the pause row back at No, and the clean-up. Needs work: the Recycle Bin rows got new row numbers, the window grids and 2 screens, and the answer buttons. The endorser answer was skipped.
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-21-r41-results.md

- Round R40 r1 (20 Nov 26): needs review. Checks 9 of 9, Window OK, 3 of 4 steps passed. Passed: my window r13 opens on the screen I closed it on, kept screens open with no delay (7 to 37 ms), and all 4 window checks. Needs work: one Your Work grid was 10 px too wide once, the look question has one button too many, and I still have to name the small changes:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-21-r40-results.md

- Round R39 r1 (20 Nov 26): needs review. Checks 9 of 9, Window OK, 3 of 6 steps passed. Passed: the test install 0.1 of 90-161.Z, Back up of 11 lists, and in my window r12 the RADE fonts, the Your Work status column and the taller text boxes. The window did open on the screen I closed it on (Settings, not All Actions: the check text was wrong). Needs work: screens still open with a delay, my Diagnose answer differs from its report, and the e-mail text was from my first run:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-20-r39-results.md

- Round R38 r1 (20 Nov 26): needs review. Checks 12 of 12, Window OK, 12 of 13 steps passed. Passed: the second person added a new row (first pass since R29a), the site logo and thumbnail in Fulcrum colors with the read-back, and in my window r11 the All Actions status column and the whole names. Needs work: on Your Work the status column still touches the scroll bar, 2 text boxes are too short, the first open of a card is slow, 3 RADE answer cards have too many buttons, and 1 RADE button text is cut. No script file in the results:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-20-r38-results.md

- Round R37 r1 (20 Nov 26): needs review. Checks 14 of 14, Window OK, 32 of 35 steps passed. Passed: my window r10 (18 of 18 checks, 0 layout defects, Fulcrum logo), the sample in Word, the list changes, the flow import with all 10 flows On, the health flow, the list button, and the full flow test end to end for the first time. Needs work: a script file in the results (the e-mail was blocked; fixed), the status column touches the scroll bar. Not tested: the second person row (I skipped it):
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-20-r37-results.md

- Round R36 r1 (19 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK, 28 of 40 steps passed. Passed: the sample publication with the Word helper file (plain and with 2 test seals), the Visitors access and the 2 list changes by script, the list IDs in the import file, all 10 flows On by name, the health flow and the list button (after I chose the view by hand), my window r8 with 17 of 17 cards and the contrast checks. Needs work: the full flow test stopped at its start ("The specified user could not be found"), so its 6 next steps were skipped; 1 grid in my window is 9 px too narrow; the Enter check failed. Not tested: the second person steps (I skipped them):
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-19-r36-results.md
- Round R35 r2 (19 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK. Passed: F05 makes the Legal rows within 3 minutes on every path, a PFM Office member who is not the author edits a row, the health flow and the list button, the window r8 (20 of 20). Needs work: F01 log rows (one flow was Off), a Visitors member cannot write a row (way C, not built):
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-19-r35-results.md
- Round R34 r1 (19 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK. Passed: the 2 test flows inside the app solution ran (the health flow, and the list button started the button flow); the 2 test flows were deleted again; PFM Office and its edit-all level, the tier T-0 and the form header were made; a second owner on each of the 6 app flows; my 90-161.Z window r7 passed 18 of 18 checks; the paste of 1 MB worked in ISE and in the PowerShell console. Not saved: F05, because one description in it is too long for Power Automate (365 characters, the limit is 256), so the 3 F05 checks failed and the next 5 steps were skipped. Not tested: the second person edit (I skipped that step):
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-19-r34-results.md
- Round R33 r3 (19 Nov 26): passed. One paste of 1.1 MB works in ISE. RADE can run its scripts without Bypass (ran):
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-19-r33-results.md
- Round R32 r1 (18 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK. Passed: the full flows imported and the full flow test passed in all 3 parts, the first result since R28 (F01, F02 and F04 work; the F04 e-mail came to my Inbox); all 6 flows On with no connection warning; a second owner added and removed; my 90-161.Z window r6 passed 16 of 16 checks, with the 4 alignment fixes; one paste of 812 KB worked. Failed, for the 4th round: the health flow import and the button flow I make by hand, both with "The connections could not be loaded"; this is not a service fault, because the upgrade of the full flows worked in the same sitting. Skipped: 11 steps that needed them. My notes on the RADE window went to the RADE session:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-18-r32-results.md
- Round R31a r1 (18 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK. Passed: the list form shows my test header in the side panel (the new way to open it works); the clean-up asked me to remove only what was made; the test site was clean at the start and at the end. Failed: the same 3 Power Automate steps (health flow import, button flow I make by hand, full flow import); this time the error names the SharePoint connector, which Power Automate could not load. Skipped: 19 steps that needed them. The form menu has no "Configure layout"; the app does not need it. My 3 wants for RADE went to the RADE session:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-18-r31a-results.md
- Round R31b r1 (18 Nov 26): needs review. Window checks 12 of 14: all 3 high-contrast checks pass for the first time, and 17 of 17 card pictures arrived. Failed: the "Your Work" line and the Action Status card. My 4 screenshots are 4 alignment defects, fixed in window r6 (R32):
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-18-r31b-results.md
- Round R30a r1 (18 Nov 26): needs review. Checks 14 of 14, shared files 4 of 4, Window OK. Passed: Power Automate shows my connections (new first step); the test list, library and form header were made by script; the test site was clean at the start and at the end. Failed: the same 3 Power Automate steps, again with portal errors during a Microsoft 365 fault (health flow import, button flow I make by hand, full flow import), and the form look: the link opens the new-entry page, which has no layout pencil. Skipped: 17 steps that needed them. Next round: the clean-up asks me to remove a flow only if it was made:
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-18-r30a-results.md
- Round R30b r1 (18 Nov 26): needs review. Window checks 11 of 12: Narrator names now pass; high contrast "on" fails. The "Your Work" line and the Action Status card are not judged yet (the questions came after the window was closed); the look is "close, with small changes", with 8 look notes (5 for RADE alone):
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/docs/reviews/2026-11-18-r30b-results.md
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
