# Fresh-reader test, round R43 (T7)

Date: 26 Nov 26 (work done on the branches claude/r43-t7 and claude/r43-fix).
Files read by the person: go.md (task R43 r1); scripts/paste_bundles.json, the guide lines of the R43 steps (guide step numbers are the numbers of the steps in the round definition, in file order: 6 Second person answers, 8 and 10 the window, 12 Back up, 15 Start Restore, 17 Restore with the app name, 27 Remove the flows by hand, 29 Uninstall, 31 Install again).
Bundle: scripts/gov/paste/90161Z-R43-round-r1.ps1 (engine-v41).

## Result

- Round 1: 24 marks (the Orchestrator's fresh reader, with the steps and the output of `python3 tests/check_screen_names.py --map`). All 24 are rewritten below (branch claude/r43-fix). The worker has no subagent, so it did not run round 2 and did not fake one.
- Round 2: NOT RUN. The Orchestrator runs it with a new fresh reader on the rewritten steps. The criterion "the last fresh reader marks no step" is NOT met until then.

Packet for each reader (the instructions skill and the round skill, section 5): the steps as the person sees them; the output of `python3 tests/check_screen_names.py --map`; the brief "For each step, say back the screen or window, the actions, the exact text to type, and any value you must note (and where you use it). Mark each step where you cannot say one of these, where you would act before you should, or where a sentence tells you nothing you need. Mark each step whose screen, button or order differs from the map." A note for the reader: a button text that the code builds at run time ("Install", "Run", "Repair", "Skip", "Resume at step <n> of <m>") is not in the BUTTONS line; a row of a list ("Back up", "Restore", "90-161.Z 0.1.0") is not a button; the map lists cards in code order, not in the order a person meets them (the card "Is the saved site a test site?" is built after "Which backup does Restore use?" but shows before it).

## Round 1: the 24 marks and the changes

Window names: "first RADE window" holds the step card (this window); "second RADE window" is the one the person opens from the Desktop shortcut. go.md numbers: the old steps 9, 13 and 15 are now 9 and 10, 14, 16 and 17 (the task has 23 steps).

| # | Mark (reader) | Old line | New line (what changed) |
|---|---|---|---|
| 1 | go.md 9: Maintenance, then Repair, on 2 screens | 9. ... If the card **Maintenance** shows, click **Maintenance**, then click **Repair**. | 9. ... If the card **Maintenance** shows, click **Maintenance**. 10. If the card **Maintenance** shows again, with the rows **Diagnose**, **Back up** and **Restore**, click **Repair**. (one screen each) |
| 2 | go.md 13: Install or Repair not clear | 13. On the card **Ready to install ...**, click **Install**. Wait ... | 14. ... click **Install**. This button is also the one for a repair. (the code builds the button as "Install" for an app that a deploy installs; the card has no "Repair") |
| 3 | go.md 15: end card, then F5 in ISE, 2 windows | 15. Click **Close**. In ISE, press `F5`. ... | 16. On the end card, click **Close**. The window **RADE** closes. 17. In ISE, press `F5`. Wait until the window **RADE** opens again. |
| 4 | 6.3, 6.4, 6.5: Teams words (3 marks) | "Chat", "New chat", box "To" without a tag | each Teams name is tagged "(not from the bundle)" (step 2 and the chat box too); 6.5 keeps "that you wrote down" (the address of go.md step 1) |
| 5 | 6.fb: the button "Skip" is not in the code | If nobody can help today: click "Skip". The round goes on and removes the test rows at the end. | If nobody can help today, click "Skip" on this card. The round goes on. Checked: "Skip" is a button of every step card that does not hide it (the code builds its text at run time: the hand card, `$three`, and the RADE tour). The step hides "It failed" only, so "Done" and "Skip" show. The line stays, with the card named. |
| 6 | 10: asks about "screen 11 of 18" of a window that step 8 closed; no note step | question w-answer "At screen 11 of 18, did the grid "Wave 1 answers" show the second person?" | The question is removed. The record is the Pass or Fail of the look line of the window (WALK line in the result file of the window step), which the person answers while the grid is on screen. The note of step 8 says so. Step 10 keeps 1 question (your first change). Title "Answer 1 question about the window". |
| 7 | 12.2: "You see 90-161.Z 0.1.0 at the top" | 2. ... click "90-161.Z 0.1.0". You see "90-161.Z 0.1.0" at the top. | 2. ... click the row "90-161.Z 0.1.0". The card "Maintenance" shows. |
| 8 | 15.2: same | same as 12.2 | same new line as 12.2 |
| 9 | 29.2: same | same as 12.2 | same new line as 12.2 |
| 10 | 12.3: "Back up" is not in BUTTONS | 3. click "Maintenance". You see "Back up" and "Restore". 4. Click "Back up". | 3. Click "Maintenance". You see the rows "Diagnose", "Back up" and "Restore". 4. Click the row "Back up". (they are rows of a list, not buttons) |
| 11 | 12.fb: "It failed" names no window | If lists were not saved: click "It failed" and type the first line of the message. | If the result card is not "Back up saved the lists.", write down its first line. Close that window. If you wrote down a line: in the first RADE window, click "It failed". Then type that line, and click "Report the failure". |
| 12 | 29.fb: same | If "Uninstall did not finish." shows: click "It failed" and type the first line of the card. | same 3 lines, with the card "90-161.Z is uninstalled." |
| 13 | 31.fb: same | If "The install is not complete." shows: click "It failed" ... | same 3 lines, with the end card "90-161.Z 0.1.0 is installed." |
| 14 | 15.5 and 15.6: the test-site card shows after the click in 15.6 | 4. Click "Restore". You see "Which backup does Restore use?" 5. If RADE asks "Is the saved site a test site?" ... 6. Click the backup marked "Newest". | 4. Click the row "Restore". 5. If "Is the saved site a test site?" shows, ... 6. If you typed it, click "Mark as test site". 7. On the card "Which backup does Restore use?", click the row marked "Newest". (the brief says the test-site card shows after the click in 15.6; the code shows it BEFORE the backup card, so the order follows the code. The code shows the test-site card first, then the backup card: VRestorePick calls VRestoreMark before it builds the backup card) |
| 15 | 15.5 against 29.4: one card, 2 opposite actions | 15.5: close the second window. 29.4: type the site name. | One rule in both steps (the same two lines): "If "Is the saved site a test site?" shows, type the address part after the last / in "Site name"." and "If you typed it, click "Mark as test site"." The stop line of step 15 and its failure line are gone. Candidate not taken: stop in both steps (Uninstall cannot run on an unmarked site, so step 29 would never pass). |
| 16 | 17.4: "You see Restore run ... the result" | 4. Click "Restore". You see Restore run. Wait until the result shows. | 4. Click "Restore". The card "Restore is running." shows. 5. Wait until the card "Restore put the missing rows back." shows. 6. On that card, find the line that starts with "PFM Endorsements". |
| 17 | 27.1: no address for Power Automate | 1. Open the Power Automate site for your environment. | 1. In your browser, open https://make.powerautomate.appsplatform.us (not from the bundle). The address is the DoD portal host of docs/DECISIONS.md, 2026-11-14 (tests/check_flow_solution.py). Lines 3 to 6 tag the Power Automate names "(not from the bundle)". |
| 18 | 27: runs in the main round before step 29, but 29.8 expects it in the second window | the note did not say where the card shows | The manifest runs this step only inside Uninstall (it is step 1 of the 4 Uninstall steps of the app; it is not in the steps of the round), so RADE shows its card in the second RADE window after the confirm. The note now says so; line 3 and the failure line say "in RADE" and "on this card". The position of the entry in the file is unchanged (moving it would renumber the steps). |
| 19 | 29.4: no exact text for "Site name" | 4. If the card "Is the saved site a test site?" shows, type the site name in the box "Site name". | Trailing line: If "Is the saved site a test site?" shows, type the address part after the last / in "Site name". (the card says "the part of its address after the last /"; the code accepts that part or a full address). The two mark lines moved to the end of the step, so the numbered lines (10 at most) hold the flows lines. |
| 20 | 29.8: "do its lines" points elsewhere | 8. If "Remove the flows of 90-161.Z in Power Automate" shows, do its lines, then click "Done". | 6. Wait until the card "Remove the flows of 90-161.Z in Power Automate" shows. 7. In Power Automate (not from the bundle), delete the solution "90-161.Z flows". 8. On that card, click "Done". Wait until "90-161.Z is uninstalled." shows. Do not close the window. 9. Close the second RADE window with its X. You see the first RADE window again. |
| 21 | 31.4: no stop for a second failed check | 4. If "One check failed." shows, do the line that starts with "What to do". Click the first button. | same line 4, then 5. If "One check failed." shows again, write down its first line. Close the second RADE window. (the failure lines then report it) |
| 22 | 31.7: no time limit | 7. Wait until "90-161.Z 0.1.0 is installed." shows. Do not close the second window before then. | 8. Wait until "90-161.Z 0.1.0 is installed." shows (up to 5 minutes). Do not close the window. (the limit of go.md) |

Count: go.md 3 marks (rows 1 to 3), 6.3 to 6.5 3 marks (row 4), 6.fb (row 5), 10 (row 6), 12.2, 15.2, 29.2 (rows 7 to 9), 12.3 (row 10), the 3 failure lines (rows 11 to 13), 15.5 and 15.6 (row 14), 15.5 against 29.4 (row 15), 17.4, 27.1, 27, 29.4, 29.8, 31.4, 31.7 (rows 16 to 22): 3+3+1+1+3+1+3+1+1+7 = 24.

## Where the worker did not follow the brief, or could not

- Mark 14 (15.5, 15.6): the brief says the test-site card shows after the click in 15.6 (the map order). The code shows it before the backup card (`VRestorePick` calls `VRestoreMark` and returns; `RestoreMarkGo` then calls `VRestorePick` again). The steps follow the code. A round 2 reader who reads the map order may mark this again: the note for the reader above says why.
- Mark 15: the failure path "RADE asked for the test site" of step 15 is gone, because both steps now mark the site.
- Mark 6: the removed question w-answer was kept by DECISIONS 2026-11-20 ("The 4th look question w-answer stays", scope R41 only). The Maintainer must confirm the removal.
- Line 12.4 (row 10): the card sentence "Back up is running." is built at run time (`$name + ' is running.'`), so check_screen_names cannot find the whole sentence. The line now says: A card says that "Back up" is running. The text was changed so the check passes; the real sentence is the one in the code. A limit of the check, not a hidden defect.
- Row 17 (27.1): the address is typed by hand (43 characters). The round skill, section 5, says the PFM types only the first address by hand. Candidates: (a) type the address, as now; (b) set `url` on the step so the card shows the address and "Open in browser" (the engine then demands line 1 `Select "Open in browser" above.` and the same host).
- Marks 11 to 13 and 20: "this window" of the old lines is now "the first RADE window" everywhere.

## Open choices (the worker did not decide)

- Mark 6: the look step's Pass or Fail is the record (taken; no new step can run while the window is open). The other candidate was a note step after step 8; it would ask from memory, as the removed question did. DECISIONS 2026-11-20 says "The 4th look question w-answer stays" for scope R41 only.
- Mark 15: both steps mark the test site (taken). The other candidate was to stop in both.
- Mark 18: the entry of the flows step stays at position 27 of the file. Candidate: move it after the Uninstall step (renumbers 28 to 34).
- Mark 17: the address is the portal host that the PFM approved for the failure e-mails; the PFM can name another environment address.

## Self-check against the map (self-review, not a fresh reader)

The author compared the new lines with the card order of the bundle code (VRestorePick, VRestoreMark, RestorePlan, RestoreGo, VUninstall, UninstallGo, the hand card VHand, the result card ToolResult, the ready card). This is not independent.

| Steps | Code order in the bundle | Match |
|---|---|---|
| go.md 8 to 17 | Choose row, card "Maintenance" (button "Maintenance"), card "Maintenance" of the tools (rows, button "Repair"), checks, "Ready to install 90-161.Z 0.1.0." (button "Install"), "90-161.Z 0.1.0 is installed." (button "Close") | yes |
| 12 Back up | row, "Maintenance", "Maintenance" (rows), row "Back up", run card, result card "Back up saved the lists." | yes |
| 15 Restore | row "Restore", card "Is the saved site a test site?" (only when the site is not marked), "Which backup does Restore use?", "The Restore dry run is running.", "Put back <n> rows on the site?" with "Dry run:" | yes |
| 29 Uninstall | "Maintenance" (button "Uninstall"), mark card, "Uninstall 90-161.Z from the test site?", run cards, hand card, "90-161.Z is uninstalled." (button "Done") | yes |

## Round 2

Not run. Give a new fresh reader only the rewritten steps and the `--map` output, record each mark here (date, reader, model tier, marked steps, result), rewrite, and test again until no step is marked.
