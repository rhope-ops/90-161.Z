![90-161.Z: Publications and Forms Management](https://repository-images.githubusercontent.com/1453511683/43db9448-2d1b-4421-85c2-eb674e43c7ee)

# 90-161.Z
<p><b>Publications and Forms Management</b></p>

<!-- site:intro -->
Track and manage DAF publications through the DAFMAN 90-161 publishing process at wing/installation level: status tracking, document cleanup and formatting, and endorsement routing. See who has each publication or form, which endorsements are in, and what is due next. The PFM works in one window on the work computer; AOs and endorsers answer in SharePoint forms from an e-mail link. It runs in your wing's own SharePoint site and Power Automate, and RADE installs it.
<!-- /site:intro -->

> [!NOTE]
> 90-161.Z is in test rounds with fake data. Parts marked (planned) are designed but not built yet.

---

### 🔺 Summary

<!-- site:key-facts -->
<table>
<tr><td><b>By the book:</b></td><td>every stage, time limit and format rule cites its DAFMAN 90-161 paragraph.</td></tr> <!-- source: AGENTS.md "Source authority" -->
<tr><td><b>Endorsements:</b></td><td>endorsers answer in waves, legal last, in their list form; flows send the reminders and escalations.</td></tr> <!-- source: docs/process-model.md target process step 10; flow F03 (reminders, escalation) -->
<tr><td><b>System of record:</b></td><td>endorsements are kept here, not in TMT.</td></tr> <!-- source: AGENTS.md "Scope" -->
<tr><td><b>Clean drafts:</b></td><td>any draft becomes a correctly formatted final; the format comes from code, never from an AI model. (planned)</td></tr> <!-- source: AGENTS.md "Source authority"; docs/ARCHITECTURE.md section 5 -->
<tr><td><b>Reviews:</b></td><td>periodic and special reviews start on their own; no answer by the due date opens a rescind action. (planned)</td></tr> <!-- source: docs/DECISIONS.md 2026-11-12 (5A) -->
<tr><td><b>Boundary:</b></td><td>nothing leaves DoD365 and GenAI.mil, except the PFM's round results e-mail until the pilot starts.</td></tr> <!-- source: AGENTS.md "Data boundary" -->
<tr><td><b>Access:</b></td><td>your own account; standard connectors; no tenant admin, no service account.</td></tr> <!-- source: AGENTS.md "Platform" -->
<tr><td><b>Install:</b></td><td>one paste through RADE; a step that needs extra rights has a tested fallback.</td></tr> <!-- source: AGENTS.md "Deployable package" -->
<tr><td><b>Verifiable:</b></td><td>read the commented code as plain text before you paste it.</td></tr> <!-- source: AGENTS.md "Code standard"; TASKS.md "Open as .txt" links -->
</table>

> Have concerns? Ask in the Teams channel **RHOPE-OPS**.
<!-- /site:key-facts -->

---

[**Install with RADE**](https://rhope-ops.github.io/RADE)

---

### 🔺 How it works

<kbd>Review due</kbd> → <kbd>AO named</kbd> → <kbd>Draft</kbd> → <kbd>PFM formats</kbd> → <kbd>Privacy review</kbd> → <kbd>Endorse</kbd> → <kbd>Legal</kbd> → <kbd>Certify</kbd> → <kbd>Approve</kbd> → <kbd><b>Publish</b></kbd>

#### Who uses what

| Person | Uses | To |
|---|---|---|
| PFM | The 90-161.Z window on the work computer | See every action and start endorsement; format drafts and change who gets a step (planned) |
| OPR mailbox | A SharePoint form from an e-mail link | Name 1 or 2 AOs |
| AO | A SharePoint form from an e-mail link | Answer "needs further review?", add endorsers, fill in the DAF Form 673 |
| Endorser | A SharePoint form from an e-mail link | Read the final draft, comment, answer |
| Certifier, approver | The PFM or their CSS records the signature | Certify and approve |

#### What it keeps

| List | One row per |
|---|---|
| PFM Publications | Action on a publication or form (new, rewrite, change, certify current, rescind, transfer) |
| PFM Endorsements | Endorser of an action: order, role, status, due date, answer |
| PFM Process Steps | Stage, with its paragraph and the action types it applies to |
| PFM Offices, PFM Series | Coordinator office; subject series (Table A2.1) |
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

---

### 🔺 Files

| File | What it does |
|---|---|
| `schemas/` | The list schemas |
| `flow/` | The Power Automate flow designs |
| `templates/`, `prompts/` | The document templates; the GenAI.mil prompts |
| `scripts/` | Build, round bundles and the gov-device scripts |
| `docs/ARCHITECTURE.md`, `docs/process-model.md` | The design; the stages and their paragraphs |
| `ref/` | The rule source: DAFMAN 90-161 |
| [TASKS.md](TASKS.md) | Test tasks for the work computer (copied from go.md) |
