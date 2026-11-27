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

**Round script:** `90161Z-R47-round-r1.txt` · **Build:** `5160e2cf` (the RADE title bar shows it) · **Code:** `cc65ae83b9e7...c4c4`

---

### 🔺 Current tasks

Updated: 26 Nov 26 (R46 r1 results).


No open task. The next round is R47.
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
