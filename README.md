![90-161.Z: Kanon · Publications and Forms Management](docs/assets/90-161.Z-social-preview.png)

# Kanon
<p><b>Publications and Forms Management</b></p>

<!-- site:intro -->
Track and manage DAF publications through the DAFMAN 90-161 publishing process at wing/installation level: status tracking, document cleanup and formatting, and endorsement routing. See who has each publication or form, which endorsements are in, and what is due next. The PFM works in one window on the work computer (first test in R41); AOs and endorsers will answer in SharePoint forms from an e-mail link (planned). It runs in your wing's own SharePoint site and Power Automate, and RADE will install it (in progress).
<!-- /site:intro -->

> [!NOTE]
> Kanon is in test rounds with fake data. Parts marked (planned) are designed but not built yet.

---

### 🔺 Summary

<!-- site:key-facts -->
<table>
<tr><td><b>By the book:</b></td><td>every stage and format rule cites its DAFMAN 90-161 paragraph; each time limit comes from DAFMAN 90-161 or a recorded PFM decision.</td></tr> <!-- source: AGENTS.md "Source authority"; docs/DECISIONS.md -->
<tr><td><b>Endorsements:</b></td><td>flows make the endorsement rows and send the reminders and escalations; the answer path for endorsers (first test in R41) and the optional wave (planned).</td></tr> <!-- source: flow F05 (rows), F03 (reminders, escalation); flow/solution/README.md open point d (answer path not built) -->
<tr><td><b>System of record:</b></td><td>endorsements are kept here, not in TMT.</td></tr> <!-- source: AGENTS.md "Scope" -->
<tr><td><b>Clean drafts:</b></td><td>any draft becomes a correctly formatted final; the format comes from code, never from an AI model. (planned)</td></tr> <!-- source: AGENTS.md "Source authority"; docs/ARCHITECTURE.md section 5 -->
<tr><td><b>Reviews:</b></td><td>periodic reviews open on their own; special reviews, and a rescind action when no answer comes by the due date (planned).</td></tr> <!-- source: flow F02 (R37 test passed); docs/DECISIONS.md 2026-11-12 (5A) -->
<tr><td><b>Boundary:</b></td><td>nothing leaves DoD365 and GenAI.mil, except the PFM's round results e-mail until the pilot starts.</td></tr> <!-- source: AGENTS.md "Data boundary" -->
<tr><td><b>Access:</b></td><td>your own account; standard connectors; no tenant admin, no service account.</td></tr> <!-- source: AGENTS.md "Platform" -->
<tr><td><b>Install:</b></td><td>in progress: one paste in RADE for the scripts and lists, the flows imported by hand, and a tested fallback for each step that needs extra rights.</td></tr> <!-- source: AGENTS.md "Deployable package"; docs/setup-and-updates.md section 2 -->
<tr><td><b>Verifiable:</b></td><td>read the commented code as plain text before you paste it.</td></tr> <!-- source: AGENTS.md "Code standard"; the "Open the script" link (a .txt file) -->
</table>

> Have concerns? Ask in the Teams channel **RHOPE-OPS**.
<!-- /site:key-facts -->

---

<!-- >>> tasks: generated from go.md and the round bundle by scripts/build_readme.py (do not edit) -->
[**Open the script**](https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R42-round-r2.txt)

The steps to run it are at the top of the script.

**Round script:** `90161Z-R42-round-r2.txt` · **Code:** `df7bc454380b...63f8`

---

### 🔺 Current tasks

Updated: 24 Nov 26 (R42 is ready).\
github.com/rhope-ops/90-161.Z

Every task below has the same parts: **For** (why), **Time** (an estimate), **Changes** (what it writes or changes, before I start), **Steps**, **Report** (what to send back) and **If it fails**.\
Reload this page to see new tasks (GitHub can serve a copy up to 5 minutes old).\
Never send real publication content, names, site addresses or group names. Reply in the Claude chat or by e-mail.

#### How a paste task (round) works

**For:** a round is one block of text I paste into PowerShell ISE. It opens the RADE window (Redacted Application Deployment Engine, formerly the 90-161.Z Deployer), saves its own files, runs the tests and makes the results e-mail. The ISSM allows this for scripts that use no elevated credentials (13 Nov 26).\
**Changes:** it writes only into my own OneDrive folder RADE\90-161.Z (the card **Ready to run round** names the folder after **Writes to**): the task folders it needs (for example T01), Config and its results folder Rounds\\<round>. RADE\Config holds RADE's own settings: the results e-mail address and the saved checks (rade-checks.json: most checks that passed are not run again for 7 days). From R17 on, RADE moves my old OneDrive folder 90-161.Z into RADE once, when I select Run (one folder move; every file keeps its place). It makes missing folders and replaces files of the same name. From R06 on it also moves finished files to the Recycle Bin (only files 90-161.Z made). Before Run, the card **Ready to run round** gives the count of new, replaced and recycled files; **Record (F2)** at the bottom of the window lists every file. Every file a task needs comes inside the round: there are no separate downloads (14 Nov 26). The .txt copy of the script (**Open the script**) is not a task file. A step marked "(needs you)" opens a small window with numbered steps for work in another program, such as a flow import.\
Steps to start a round. Do these steps when an open task on this page says "run the round". That task gives the round name, for example **R42**:
1. On GitHub, on the page **rhope-ops/90-161.Z**, find **Round script** under **Open the script**. You see the round name, for example `90161Z-R42-round-r2.txt`. Go on.
2. If the round name is not the round of the open task, do not open the script. You see the other round name next to **Round script**. Write down `README shows another round`. Send it to Claude with the steps "Send a line to Claude" on this page.
3. If the round name is right, click **Open the script**. You see the script as plain text on a new page, with the steps to run it at the top. Go on.
4. On the new page, do these actions:
   1. Press `Ctrl+A`.
   2. Press `Ctrl+C`.
   You see all the text in blue. `Ctrl+C` puts the text on the clipboard. Go on.
5. Click the Windows **Start** button. You see the search box. Go on.
6. Type `ISE`. You see **Windows PowerShell ISE** in the list. Go on.
7. Click **Windows PowerShell ISE**. Do not click **Run as administrator**. You see the window **Windows PowerShell ISE**. Go on.
8. In the window **Windows PowerShell ISE**, do these actions:
   1. Click **File**.
   2. Click **New**.
   You see a new white script pane. Go on.
9. In the white script pane, press `Ctrl+V`. You see the script text in the pane. Go on.
10. Press `F5`. You see the window **RADE**, red text in ISE, or the round steps as text in ISE. Wait until one shows (up to 2 minutes, an estimate).
11. If nothing shows after 2 minutes, write down `Nothing after F5`. Send it to Claude with the steps "Send a line to Claude" on this page. Wait until Claude answers.

Steps to send a line to Claude. Do these steps when a step on this page says "Send it to Claude":
1. On your phone, open the Claude chat of 90-161.Z. You see the chat. Go on.
2. In the chat, type the text that the step gave you. You see the text in the message box. Go on.
3. Press **Send**. You see your message in the chat. Wait until Claude answers. Do not run the round again until then.
4. Read the answer of Claude in the chat. You see the next action in the answer. Do that action. The task is complete.

Steps if the window **RADE** opens. The window shows one card at a time. **Record (F2)** at the bottom shows all checks, steps and the log; you do not need it:
1. In the window **RADE**, find the question **Which application do you want to install?** or **Which application do you want to run?** You see one row for each application. Go on.
2. Click the row with the round name of the open task. You see **Checking this computer and your access.** Wait until a new card shows (up to 2 minutes, an estimate).
3. If the card **One check needs you.** shows, click the button on the card. Do what the card says. Wait until a new card shows.
4. If the card **One check failed.** shows, write down the first 10 words under it. Send them to Claude with the steps "Send a line to Claude" on this page. The steps in this window stop here.
5. If the card **Your OneDrive folder was not found.** shows, write down `OneDrive not found`. Send it to Claude with the steps "Send a line to Claude" on this page. The steps in this window stop here.
6. When the card **Ready to run round** shows, click **Run**, or the button that starts with **Resume at step** if it shows. You see **Running round** and a progress bar. Wait until RADE shows a card that needs you, or an end card (up to 1 hour, an estimate). Do not close the window until then.
7. Each time a card shows numbered lines, do the lines on the card. You see the button **Done** on the card. Go on.
8. When the lines on the card are complete, click **Done**. You see the next card. Go on.
9. Each time a card shows a question with buttons, click your answer. You see the next card. Go on.
10. If the card **Last question** shows, type your answer in the box. You can leave the box empty. Go on.
11. On the card **Last question**, click **Continue**. You see the next card. Go on.
12. If the card "Insert your CAC, then select Resume." shows, put your CAC in the reader. Go on.
13. If your CAC is in the reader, click **Resume** on that card. You see the progress bar again. Go on.
14. If the card **The round stopped.** shows, write down the first 10 words under it. Do not write down names or site addresses. Send them to Claude with the steps "Send a line to Claude" on this page. The steps in this window stop here.
15. If an end card shows, wait until an Outlook draft or the results folder opens. The end card is **Round R42 is done.** or **The round needs review.**
16. If you see the Outlook draft and its **To** line is empty, type your own e-mail address in **To**. You see the address in **To**. Go on.
17. If you see the Outlook draft, click **Send** in the draft. The draft closes. The task is complete.
18. If you see the results folder and no draft, send the results with the steps "Send the results by hand" on this page. Go on.

Steps if ISE shows red text:
1. In the blue pane of ISE, find the first line in red. You see red text. Write down the first 10 words of that line. Do not write down names or site addresses.
2. Send the 10 words to Claude with the steps "Send a line to Claude" on this page. Wait until Claude answers. You see the answer of Claude in the chat.

Steps if the round steps show as text in ISE:
1. Look at the blue pane of ISE. You see the steps run. Wait until the pane shows `DONE` (up to 1 hour, an estimate). Do not close ISE until then.
2. When the pane shows `DONE`, you see the results folder open in File Explorer. Send the results with the steps "Send the results by hand" on this page. Go on.

Steps to send the results by hand. Do these steps when no Outlook draft opens and you see the results folder in File Explorer. RADE puts the e-mail text on the clipboard. RADE makes no zip file:
1. Put the File Explorer window of the results folder and Outlook side by side. You see both windows. Go on.
2. In Outlook, click **New**, the button that starts a new e-mail. You see a new e-mail window. Go on.
3. In **To**, type your own e-mail address. You see the address in **To**. Go on.
4. Click in the body. You see the cursor in the body. Go on.
5. Press `Ctrl+V`. You see the e-mail text in the body. Its first line is the subject, for example `90161Z R42 PASSED`. Go on.
6. Select the first line of the body with the mouse, from the first word to the end of the subject. You see the line in blue. Go on.
7. Press `Ctrl+X`. You see the first line go away. Go on.
8. Click in **Subject**. You see the cursor in **Subject**. Go on.
9. Press `Ctrl+V`. You see the subject line in **Subject**. Go on.
10. Click the File Explorer window. You see the files of the results folder. Go on.
11. Press `Ctrl+A`. You see all files in blue. Go on.
12. Drag the files into the body of the e-mail. You see the files as attachments. Go on.
13. Click **Send**. The e-mail closes. The task is complete.

**If it fails:** the card shows a line that starts with "What to do" under the problem: do that. Otherwise send the first 10 words of the card **The round stopped.** The report file in Rounds\\<round> also holds them. Do not work around it. If no window opens, the same steps run as text in ISE and the results folder opens by itself.\
The script never sends the e-mail; the draft waits in Outlook. Finished task folders are cleaned up by the rounds; a later round makes any folder it needs again. Keep T07 if it holds 90161Z-T07-key-r1.txt (rounds never touch it).\
Sensitivity label: every render gets the label from Config\90161Z-label.json. Never delete the Config folder: without it, renders print "LABEL not set" and have no label. The file I labeled by hand is no longer needed. If Config is lost, run a round, then capture again from its new render (it is already labeled); label a file by hand again only if renders say LABEL FAIL.

#### Open tasks

##### Round R42 r2: my window r15, an endorser answer, a small sign-in window and Restore

**For:** the round after R41. It tests the R41 fixes: my 90-161.Z window r15 (room for the scroll bar; the screens Waves and Step 13 open), the answer of a second person, a small CAC sign-in window for Back up and Restore, and RADE Restore of fake rows with their old row numbers. The window **RADE** lists 2 rows: **90-161.Z R42** (the round) and **90-161.Z 0.1.0** (the test install, with its **Maintenance** tools).\
**Time:** about 40 minutes, with about 5 minutes of a second person from my office (an estimate).\
**Changes:** on my computer: my OneDrive folder RADE\90-161.Z (scripts and result files in T21, T22 and T26, 17 pictures of the window screens, and one backup of the 12 test site lists). The old files of T21 r11, T22 r14 and T26 r1 go to the Recycle Bin. The Repair saves a new copy of RADE for the RADE shortcut. On the test site: a test list and library, the second person in the Visitors group, one fake publication and fake endorsement rows. The last steps of the round move them to the site Recycle Bin. Before Run, **Record (F2)** lists every file.\
**Steps:**
1. Ask one person of your office to help in this task (about 5 minutes, an estimate). You see that the person agrees. Write down the e-mail address of that person.
2. Do "Steps to start a round" on this page with the round name **R42**. Wait until you see the window **RADE**.
3. In the window **RADE**, click the row **90-161.Z 0.1.0**. Wait until you see the card **Maintenance** with the button **Maintenance**.
4. Click the button **Maintenance**. Wait until you see the rows **Diagnose**, **Back up**, **Restore** and the button **Repair**.
5. Click **Repair**. You see **Checking this computer and your access.** Wait until a new card shows (up to 2 minutes, an estimate).
6. If the card **One check needs you.** shows, click the button on the card. Do what the card says. Wait until a new card shows.
7. If the card **One check failed.** shows, do "Send a line to Claude" on this page with the first 10 words under it. The steps of this task stop here.
8. If the card **Ready to install 90-161.Z 0.1.0.** shows, click **Install**. You see **Installing 90-161.Z.** Wait until an end card shows (up to 5 minutes, an estimate).
9. If the card **The install is not complete.** or **The install stopped.** shows, do "Send a line to Claude" on this page with the first 10 words under it. The steps of this task stop here.
10. If the card **The run passed, but version 0.1.0 is not recorded as installed.** shows, do "Send a line to Claude" on this page with `Repair not recorded`. The steps of this task stop here.
11. If the card **90-161.Z 0.1.0 is installed.** shows, click **Close**. Wait until you see ISE with the script in the white pane.
12. In ISE, press `F5`. You see the window **RADE** again. Wait until the row **90-161.Z R42** shows (up to 2 minutes, an estimate).
13. In the window **RADE**, click the row **90-161.Z R42**. You see **Checking this computer and your access.** Wait until a new card shows (up to 2 minutes, an estimate).
14. If the card **One check needs you.** shows, click the button on the card. Do what the card says. Wait until a new card shows.
15. If the card **One check failed.** or **Your OneDrive folder was not found.** shows, do "Send a line to Claude" on this page with the first 10 words of the card. The steps of this task stop here.
16. If the card **Ready to run round R42.** shows **Run** or **Resume at step**, click it. Wait until you see a progress bar. The next 21 steps come in any order, often more than one time.
17. If a RADE card asks for the size of the CAC sign-in window, write down `Small` or `Large`. You see the size on paper. Go on.
18. If a CAC sign-in window opens (each time), sign in with your CAC. Wait until the sign-in window closes.
19. If the small window **90-161.Z test T4** asks for an address, type the address of the second person that you wrote down. You see the address in the box. Go on.
20. If the address is in the box of the small window **90-161.Z test T4**, click **OK**. The small window closes. Go on.
21. If a card in the window **RADE** shows numbered lines (each time), do the lines on the card. You see the button **Done**. Go on.
22. If the lines on the card are complete, click **Done**. You see the next card. Go on.
23. If the second person cannot help today, click **Skip** on the card **Ask the second person to answer the endorsement**. You see the next card. Go on.
24. If a card in the window **RADE** shows a question with buttons or rows (each time), click your answer. You see the next card. Go on.
25. If a card in the window **RADE** shows a box (each time, also **Last question**), type one line with no names. Go on.
26. If the line is in the box, click **Continue**. You see the next card. Go on.
27. If the card **What did the error say?** shows, type the error message in the box. Go on.
28. If the error line is in the box, click **Report the failure**. You see the next card. Go on.
29. If the window **Publications and Forms Management** opens, find its bottom bar. You see a line that starts with **Check 1 of**. Go on.
30. If the bottom bar shows a line (each time), do what the line says. You see the result in the window. Go on.
31. If the result is what the line says, click **Pass** in the bottom bar, else **Fail**. You see the next line. Go on.
32. If the bottom bar shows **Screen 10 of 17**, write down `Yes` if the grid **Wave 1 answers** shows the second person, else `No`. Go on.
33. If the bottom bar shows "All checks done. Close this window with its X.", click the X of the window. You see the window **RADE**. Go on.
34. If a card asks about **Screen 10 of 17** and **Wave 1 answers**, click the answer that you wrote down: **Yes** or **No**. You see the next card. Go on.
35. If the card "Insert your CAC, then select Resume." shows, put your CAC in the reader. Go on.
36. If your CAC is in the reader, click **Resume** on that card. You see the progress bar again. Go on.
37. If the card **The round stopped.** shows, do "Send a line to Claude" on this page with the first 10 words under it. The steps of this task stop here.
38. If an end card shows, wait until an Outlook draft or the results folder opens (up to 2 minutes). The end card is **Round R42 is done.** or **The round needs review.**
39. If the Outlook draft shows and its **To** line is empty, type your own e-mail address in **To**. You see the address in **To**. Go on.
40. If the Outlook draft shows, click **Send** in the draft. The draft closes. Go on.
41. If the results folder shows and no draft, do "Send the results by hand" on this page. You see the e-mail close. Go on.
42. Do "Send a line to Claude" on this page with the line `R42 sent`. You see your line in the chat. The task is complete.

**Report:** send the Outlook draft that the round makes. Its subject is `90161Z R42 PASSED` or `90161Z R42 NEEDS REVIEW`, and it has every file of the results folder.\
**If it fails:** on the card in the window **RADE**, do the line that starts with **What to do**. If the button **Repair** does not show after you click **Maintenance**, write down the text of each button on the card. Send it to Claude with the steps "Send a line to Claude" on this page. If the second person cannot help today, click **Skip** on that card. The round goes on and removes the test rows at the end.
<!-- <<< tasks -->

---

### 🔺 How it works

<kbd>Review due</kbd> → <kbd>AO named</kbd> → <kbd>Draft</kbd> → <kbd>PFM formats</kbd> → <kbd>Privacy review</kbd> → <kbd>Endorse</kbd> → <kbd>Legal</kbd> → <kbd>Certify</kbd> → <kbd>Approve</kbd> → <kbd><b>Publish</b></kbd>

Built today: Review due (periodic reviews open on their own, flow F02). In progress: Endorse and Legal (flows make the endorsement rows and send reminders; the answer path is first tested in R41). Planned: every other step.

#### Who uses what

The design; parts marked (planned) are not built yet.

| Person | Uses | To |
|---|---|---|
| PFM | The 90-161.Z window on the work computer | See every action (read-only; first test in R41); start endorsement, format drafts and change who gets a step (planned) |
| OPR mailbox | A SharePoint form from an e-mail link (planned) | Name 1 or 2 AOs (planned) |
| AO | A SharePoint form from an e-mail link (planned) | Answer "needs further review?", add endorsers, fill in the DAF Form 673 (planned) |
| Endorser | The SharePoint list form (first test in R41); an e-mail link to it (planned) | Answer the endorsement, read the final draft and comment (planned) |
| Certifier, approver | The PFM or their CSS records the signature (planned) | Certify and approve (planned) |

#### What it keeps

| List | One row per |
|---|---|
| PFM Publications | Action on a publication or form (new, rewrite, change, certify current, rescind, transfer) |
| PFM Endorsements | Endorser of an action: order, role, status, due date, answer |
| PFM Process Steps | Stage, with its paragraph and the action types it applies to |
| PFM Offices, PFM Series | Coordinator office; subject series (Table A2.1) |
| PFM Guidance, PFM Settings | Screen text and its screen path; a setting |
| PFM Reviews | Periodic or special review |
| PFM Product Index | Product (6.4.2) |
| PFM Waivers, PFM Recommendations | Waiver; DAF Form 847 |
| PFM Activity Log | Event, for the trail |

---

### 🔺 Limitations

| Not done | What to do |
|---|---|
| Publications above wing level | Out of scope (DAFMAN 90-161 1.1.3.2): use the higher level's process |
| Draft cleanup and formatting | Planned |
| Uninstall | Not built in RADE yet: ask in the Teams channel |

---

### 🔺 Safety

- **Scoped:** works only on the one site you give; lists no other sites, teams or users.
- **No stored credentials:** you sign in each run; scripts take a credential only through Get-Credential.
- **Fake data only outside DoD365:** no real draft, name or office symbol is in this repository.
- **No scripts in results:** a test round never collects or sends a script file.
- **Execution policy stays on:** no script turns off the PowerShell execution policy; your organization's Group Policy decides what runs.

---

### 🔺 Files

| File | What it does |
|---|---|
| `schemas/` | The list schemas |
| `flow/` | The Power Automate flow designs |
| `templates/`, `prompts/` | The document templates; the GenAI.mil prompts |
| `scripts/` | Build, round bundles and the gov-device scripts |
| `docs/ARCHITECTURE.md`, `docs/process-model.md` | The design; the stages and their paragraphs |
| `ref/` | Reference copies: DAFMAN 90-161 (the rule source), ANGMAN 90-161 and the forms |
| `site.config.json` | The account values (GitHub owner, repository, branch, Teams channel) that the scripts read; `scripts/build_go_page.py` writes the page's CSP source from it |
| `docs/MAINTAINER_HANDOVER.md` | Where each part lives, and the steps for the common maintainer tasks |
| `SECURITY.md`, `COMPLIANCE.md`, `docs/threat-model.md` | How to report a problem; each control and its proof; the threats and their controls |
| `go.md` | The source of "Current tasks" on this page (scripts/build_readme.py copies it here) |
