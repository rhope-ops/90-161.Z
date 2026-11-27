![Kanon: 90-161.Z · Publications and Forms Management](docs/assets/90-161.Z-social-preview.png)

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
[**Open the script**](https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R47-round-r1.txt)

The steps to run it are at the top of the script.

**Round script:** `90161Z-R47-round-r1.txt` · **Build:** `3b696a8e` (the RADE title bar shows it) · **Code:** `81ed34a253d2...a5d8`

---

### 🔺 Current tasks

Updated: 27 Nov 26 (R47 r1).


#### Round R47 r1: fewer CAC sign-ins, the engine-v47 look, then Back up, Restore, Uninstall and a new install

**Why again:** R46 needs review: Uninstall stopped at its flow step (the test install has no flows), Back up took 31 minutes, the sign-in window waited about 100 s, 1 prompt cut its text and screen step 12 failed. Since then: one CAC sign-in for each group of site steps, no DPI call, an answer for "no flows", a shorter prompt and a walk of screen step 12 only.\
**For:** proves fewer CAC sign-ins, the engine-v47 look (taskbar button, title, text of the choices, one card Maintenance), screen step 12, Back up, Restore with its write, Uninstall with no flows and a new install. A second person is optional: in the small window, click **Skip** if nobody can help.\
**Time:** about 75 minutes (an estimate).\
**Changes:** on the computer, the OneDrive folder RADE\90-161.Z: scripts and result files in T20, T21, T22, T26, T27, T29 and T30, 1 screen picture per card, and backups of the 12 test site lists. On the test site, the round writes fake rows, and, if a second person helps, adds that person to the Visitors group. Restore writes fake rows. Uninstall moves the 12 own lists to the site Recycle Bin. The new install makes the 12 lists again. The round makes 1 fake publication and moves it from step 1 to step 2. The last steps of the round move the fake rows to the site Recycle Bin.\
**Steps:**
1. On the GitHub page github.com/rhope-ops/90-161.Z, below **Summary**, click **Open the script**. The script opens as plain text.
2. On the script page, press `Ctrl+A`, then `Ctrl+C`.
3. From the Start menu, open **Windows PowerShell ISE** (not from the bundle). Do not open **Run as administrator** (not from the bundle).
4. In ISE (not from the bundle), click **File** > **New** (not from the bundle), then press `Ctrl+V`.
5. Press `F5`. Wait until the RADE window opens (up to 2 minutes). Keep ISE open.
6. If no RADE window opens in 2 minutes, stop. Post `No RADE window` in the Teams channel **RHOPE-OPS** (not from the bundle).
7. In the RADE window, click the row **90-161.Z 0.1.0**.
8. Do not click **Uninstall** now. If the card **Maintenance** shows, click **Maintenance**.
9. If the card **Maintenance** shows again, with the rows **Diagnose**, **Back up** and **Restore**, click **Repair**.
10. If the card **One check needs you.** shows, click **Sign in and check site rights**, then sign in with your CAC.
11. If the card **One check failed.** or **checks failed. This is the first.** shows, do its line **What to do**.
12. If you did the line **What to do**, click the button it names: **Run checks again** or **Sign in and check site rights**.
13. If a check fails again, stop. Post the first 10 words of its card in **RHOPE-OPS** (not from the bundle).
14. On the card **Ready to install 90-161.Z 0.1.0.**, if the box **Shortcut in** shows, do not change the folder in it.
15. Click **Install**. Wait until an end card shows (up to 5 minutes).
16. If the end card is not **90-161.Z 0.1.0 is installed.**, stop. Post the first 10 words of the card in **RHOPE-OPS** (not from the bundle).
17. On the end card, click **Close**. The RADE window closes.
18. In ISE (not from the bundle), press `F5`. Wait until the RADE window opens again.
19. On the screen **Which application do you want to run?**, read the text under each choice.
20. Press `Windows logo key+Left arrow` (not from the bundle). The RADE window fills the left half of the screen.
21. Read the text under each choice again, then double-click the title bar of the RADE window (not from the bundle). The window fills the screen.
22. Click the row **90-161.Z R47**. Wait until a card shows (up to 2 minutes).
23. If the card **One check needs you.** shows, click **Sign in and check site rights**, then sign in with your CAC.
24. If the card **One check failed.** or **checks failed. This is the first.** shows, do its line **What to do**.
25. If you did the line **What to do**, click the button it names: **Run checks again** or **Sign in and check site rights**.
26. If a check fails again, or **Your OneDrive folder was not found.** shows, stop. Post the first 10 words in **RHOPE-OPS** (not from the bundle).
27. On the card **Ready to run round R47.**, click **Run** (or **Resume at step**, if it shows).
28. Each time a sign-in window opens, sign in with your CAC. If it does not respond, do nothing: after 3 minutes the step stops and the round goes on.
29. Do each step that a card shows. Stop when the card **Round R47 is done.** or **The round needs review.** shows.
30. In the Outlook draft with the subject that starts with `90161Z R47`, click **Send**.
31. If no Outlook draft opens, do the e-mail line of the end card.

**Report:** 1 e-mail with the subject `90161Z R47 PASSED` or `90161Z R47 NEEDS REVIEW` and every file of the results folder.\
**If it fails:** on the card, do the line that starts with **What to do**. If the card **The round stopped.** shows, or red text shows in ISE (not from the bundle), post the first 10 words in the Teams channel **RHOPE-OPS** (not from the bundle). **Details (F2)** at the bottom of the RADE window shows all checks, steps and the log.
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
