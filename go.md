# 90-161.Z: tasks for my work computer

Updated: 14 Nov 26 (Round R16: sample solution export, rights for app users, logo and thumbnail).
rhope-ops.github.io/90-161.Z
Fallback (plain text):
raw.githubusercontent.com/rhope-ops/90-161.Z/main/go.md

Every task below has the same parts: **For** (why), **Time** (an estimate), **Changes** (what it writes or changes, before I start), **Steps**, **Report** (what to send back) and **If it fails**.
Reload this page to see new tasks (GitHub can serve a copy up to 5 minutes old).
Never send real publication content, names, site addresses or group names. Reply in the Claude chat or by e-mail.

## How a paste task (round) works

**For:** a round is one block of text I paste into PowerShell ISE. It opens the 90-161.Z Deployer window, saves its own files, runs the tests and makes the results e-mail. The ISSM allows this for scripts that use no elevated credentials (13 Nov 26).
**Changes:** it writes only into my own OneDrive folder 90-161.Z (the window shows the full path in bold): the task folders it needs (for example T01), Config and its results folder Rounds\<round>. It makes missing folders and replaces files of the same name. From R06 on it also moves finished files to the Recycle Bin (only files 90-161.Z made). Before Run, the window lists every file, marked New, Replace or Recycle. Every file a task needs comes inside the round: there are no separate downloads (14 Nov 26). A step marked "(needs you)" opens a small window with numbered steps for work in another program, such as a flow import.
Steps:
1. Press Copy script next to the round's link in its task below. If it says blocked: open the link, press Ctrl+A, then Ctrl+C.
2. Start menu: type ISE and open Windows PowerShell ISE as myself (not "Run as administrator").
3. File > New. Click in the white script pane. Press Ctrl+V, then F5.
4. The 90-161.Z Deployer window opens. Check the bold "Writes to" line: it shows my OneDrive 90-161.Z folder, or says NOT found. The first time, type the e-mail address the results go to in "Send results to" (it is remembered).
5. Press Enter (or Run). Word steps take a few minutes each. Keep the window open until the log says DONE.
6. At DONE an Outlook draft opens with the address, the subject (PASSED or NEEDS REVIEW), the summary and all result files. Send it. If no draft opens, the results folder opens and the e-mail text is on the clipboard: new e-mail, Ctrl+V in the body, cut the first line into the subject, drag in all files from the folder. No zip: zips do not cross the boundary.
**If it fails:** the window shows a line that starts with "What to do" under the problem: do that. Otherwise send the line that starts with STOPPED. The report file in Rounds\<round> also holds it. Do not work around it. If no window opens, the same steps run as text in ISE and the results folder opens by itself.
The script never sends the e-mail; the draft waits in Outlook. Finished task folders are cleaned up by the rounds; a later round makes any folder it needs again. Keep T07 if it holds 90161Z-T07-key-r1.txt (rounds never touch it).
Sensitivity label: every render gets the label from Config\90161Z-label.json. Never delete the Config folder: without it, renders print "LABEL not set" and have no label. The file I labeled by hand is no longer needed. If Config is lost, run a round, then capture again from its new render (it is already labeled); label a file by hand again only if renders say LABEL FAIL.

## Round R16 r1: sample solution export, rights for app users, logo and thumbnail (open, 14 Nov 26)

**For:** fixes R15's three open points. (1) The solution import failed because my test solution did not match a real one: you make one small solution and export it, and the round sends me its files, masked. (2) The probe gives the coworker's own user Contribute on a test list (R15 found no group to test). (3) Site setup sets the header logo (white) and the thumbnail (navy) separately and checks each one.
**Time:** about 30 minutes (estimate): the export 8, the probe import and run 5, site setup 10 plus waiting for the probe.
**Changes:** on my computer: writes into T11, T14, T16, T17 and Rounds\R16; reads the exported zip from Downloads (it stays there); moves the R15 probe, setup and test files to the Recycle Bin. In Power Automate: I make the solution "PFM 90161Z Export Sample" (one flow I do not run, one "Site URL" variable left empty) and import the flow "90161Z T11 Rights Probe r5", which I run once. On the new site: the probe creates a TEST list, library and group, gives the coworker's own user Contribute on the TEST list, reads the rights, then deletes all three; site setup uploads both logo files to Site Assets, sets the thumbnail and the header logo, and copies the probe result (site address masked). No e-mail is sent by the flow. Saves one Outlook draft (never sent).
Steps:
1. Press Copy script next to this link (if it says blocked: open the link, Ctrl+A, Ctrl+C).
https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R16-round-r1.ps1
2. Start menu: type ISE, open Windows PowerShell ISE. File > New, click in the white pane, press Ctrl+V, then F5.
3. In the Deployer window: choose the application, run the checks, then Deploy.
4. Two step windows open at the right edge of the screen, one after the other: the solution export, then the probe import. Follow each, then select its Done button. Type no names in any box.
5. Site setup asks for the site address (filled in from last time) and opens a CAC sign-in. It waits for the probe; keep the Deployer open.
6. Open the site (Ctrl+F5) and look at the header logo; then open the SharePoint start page and look at the site's card (the thumbnail). The Outlook draft opens: add "header OK, thumbnail OK" or what looks wrong, then Send.
**Report:** the draft itself, with 90161Z-T17-export-capture-r1.txt attached. Claude watches the inbox for the subject "90161Z R16".
**If it fails:** read the "What to do" line in the window. If the export capture says NO EXPORT: export the solution again, or save the zip into the T17 folder, then run the round again. If it says an address was left in a line, do not send that file. A FAIL line in site setup names the stage and the by-hand fallback (Change the look > Header).

## Done

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
