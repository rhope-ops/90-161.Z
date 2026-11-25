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

**Round script:** `90161Z-R42-round-r2.txt` · **Build:** `fb27c401` (the RADE title bar shows it) · **Code:** `df7bc454380b...63f8`

---

### 🔺 Current tasks

Updated: 25 Nov 26 (R42 r2 is ready).


#### Round R42 r2: window r15, an endorser answer, a small sign-in window and Restore

**For:** tests the R41 fixes: the 90-161.Z window r15 (room for the scroll bar; the screens Waves and Step 13 open), an endorser answer from a second person, a small CAC sign-in window for Back up and Restore, and RADE Restore of fake rows with the old row numbers.\
**Time:** about 40 minutes, with about 5 minutes of a second person from the office (an estimate).\
**Changes:** on the computer, the OneDrive folder RADE\90-161.Z: scripts and result files in T21, T22 and T26, 17 screen pictures, and one backup of the 12 test site lists. The old files of T21 r11, T22 r14 and T26 r1 go to the Recycle Bin. The Repair saves a new copy of RADE for the RADE shortcut. On the test site: a test list and library, the second person in the Visitors group, one fake publication and fake endorsement rows. The last steps of the round move them to the site Recycle Bin.\
**PFM:** the person who runs this task.\
**Keep:** the folder RADE\Config (it holds the sensitivity label for renders) and, in T07, the file `90161Z-T07-key-r1.txt`. Rounds do not touch them.\
**Steps:**
1. Ask one person in the office to help with this task, and write down the e-mail address of that person.
2. Below **Summary** on this page, click **Open the script**. The script opens as plain text.
3. On the script page, press `Ctrl+A`, then `Ctrl+C`.
4. From the Start menu, open **Windows PowerShell ISE** (not **Run as administrator**).
5. In ISE, click **File** > **New**, then press `Ctrl+V`.
6. Press `F5`. Wait until the window **RADE** opens (up to 2 minutes).
7. If no window opens, the round runs as text in ISE. It needs no clicks until a line starts with `DONE`.
8. In the window **RADE**, click the row **90-161.Z 0.1.0**, then the button **Maintenance**, then **Repair**.
9. If the card **One check needs you.** shows, click the button on the card and do what the card says.
10. If the card **One check failed.** shows, stop and post the first 10 words of the card in the Teams channel **RHOPE-OPS**.
11. On the card **Ready to install 90-161.Z 0.1.0.**, click **Install**. Wait until an end card shows (up to 5 minutes).
12. If the end card is not **90-161.Z 0.1.0 is installed.**, stop and post the first 10 words of the card in **RHOPE-OPS**.
13. Click **Close**. In ISE, press `F5`. Wait until the window **RADE** opens again.
14. Click the row **90-161.Z R42**. Wait until a card shows (up to 2 minutes).
15. If the card **One check needs you.** shows, click the button on the card and do what the card says.
16. If the card **One check failed.** or **Your OneDrive folder was not found.** shows, stop and post the first 10 words of the card in **RHOPE-OPS**.
17. On the card **Ready to run round R42.**, click **Run** (or **Resume at step**, if it shows).
18. Each time a CAC sign-in window opens, sign in. The next cards come in any order and can repeat.
19. On each card with numbered lines, do the lines, then click **Done**. On each question, click the answer.
20. On a card with a box, type one line with no names, then click **Continue**.
21. When the small window **90-161.Z test T4** asks for an e-mail address, type the address that you wrote down, then click **OK**.
22. If the second person cannot help today, click **Skip** on the card **Ask the second person to answer the endorsement**.
23. In the window **Publications and Forms Management**, do what each line of the bottom bar says, then click **Pass** or **Fail**.
24. On **Screen 10 of 17**, write down `Yes` if the grid **Wave 1 answers** shows the second person, else `No`.
25. When a card asks about **Screen 10 of 17**, click the answer that you wrote down: **Yes** or **No**.
26. When the bar shows "All checks done. Close this window with its X.", close the window **Publications and Forms Management**.
27. If the card "Insert your CAC, then select Resume." shows, insert the CAC, then click **Resume**.
28. When the round ends, wait until an Outlook draft or the results folder opens (up to 2 minutes).
29. If a draft opened and **To** is empty, type the e-mail address of the PFM. Click **Send**.
30. If no draft opened, the e-mail text is on the clipboard. In Outlook, start a new e-mail, click in the body, then press `Ctrl+V`.
31. If you started a new e-mail, type the e-mail address of the PFM in **To**. Move the first line of the body to **Subject**.
32. If you started a new e-mail, attach every file of the results folder, then click **Send**.

**Report:** the e-mail of the round, with the subject `90161Z R42 PASSED` or `90161Z R42 NEEDS REVIEW` and every file of the results folder.\
**If it fails:** on the card, do the line that starts with **What to do**. If the card **The round stopped.** shows, or red text shows in ISE, post the first 10 words in the Teams channel **RHOPE-OPS**. **Record (F2)** at the bottom of the window **RADE** shows all checks, steps and the log.
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
