# Project phases (12 Nov 26)

Status: the PFM's phase order (12 Nov, in chat) plus agent recommendations marked **REC:**. A REC is not a decision until the PFM approves it; approved items go to docs/DECISIONS.md.

## PFM's phases (12 Nov)

| # | Phase | State now |
|---|---|---|
| 1 | Build and test the PowerShell ISE deployment engine UI | Built: Stage 1 runner (WinForms window in the paste, branch ccr-2cb71415-mt9o5x, commit 4aa462b, build b60abd8b). Cloud checks on that branch: tests 50 pass / 0 fail, lint 0 findings. Not tested on the gov device: waits for Round R01 (go.md Fix first). |
| 2 | Outstanding items: function, use, scale, flexibility (for example the PFM away on deployment, roles easy to re-assign) | Partial: continuity (co-owners, how-to last), P4A sender switch, P5A handover runbook, 1.1C AO change. No role model for an acting PFM yet. |
| 3 | Lists, libraries, security settings; use existing groups; setup takes in as much existing data as possible | Partial: list design approved (14A), access group by type (P6, docs/setup-and-updates.md 4a), CSV import of products (3A), Series and Table A3.2 seeds. Rights not tested (go.md Task 11). |
| 4 | The app: UX/UI in full, all text | Inputs exist: docs/style-standard.md, customer guidance r3 (75 screens), PFM Guidance list (12A), palette (values wait for go.md Task 12). No screen map yet. |

## REC: changes to the plan

1. **DECIDED (PFM 1A, 12 Nov):** Phase 1 = runner only (test loop for gov-device code). SharePoint setup stays in Power Automate flows. Reason: the PnP sign-in failed (10 Nov), and other wings may have no PowerShell access to SharePoint (Deployable package rule), so a PowerShell installer would be a second path to keep working.
2. **DECIDED (PFM 2A, 12 Nov):** Run phases 2 and 3 as one discussion pass while R01 waits on the gov device. Role re-assignment is a permissions design question: it changes the same Settings rows and groups as phase 3.
3. **DECIDED (PFM 3A, 12 Nov):** Add the phases that follow phase 4 (they are in NEXT_PROMPT "Next design" but not in this order):
   - 5. Flow rule catalog (docs/flow-rules.md, decided 2A) and T02 r10 provisioning.
   - 6. Flows build (solution-aware, connection references).
   - 7. App build (Power Apps canvas), Accessibility Checker 0 errors.
   - 8. Pilot on the test site (requested), rights tests (Task 11) before it.
   - 9. Handover: maintainer how-to, kit repo (5A), releases.

## Phase 2 and 3 starting points (agent first take)

- Risk (high): flows run on the PFM's connections (2.2A). If the PFM's account is disabled, every flow stops; a co-owner does not move the connections. Connection references let a co-owner re-bind them in one place.
- **REC:** roles as data, not names in code: PFM Settings rows PFM, Alternate PFM, Acting PFM (with Acting Until); the app shows PFM screens to members of the PFM office SharePoint group; flows address the role, not a person. Re-assign = one screen, one flow (group membership, Settings row, Activity Log row).
- Existing groups (high confidence): SharePoint permissions can be granted to existing Entra/AD security groups, M365 groups and SharePoint groups. A flow can set them through SharePoint REST if the installer has Manage Permissions (R5); otherwise a checklist for the site owner.
- Intake of existing data, candidates: existing site groups and members (offered as choices, not copied); posted publications in an existing library (designator, title, date from file names and properties, the PFM confirms each row); the products CSV (3A); the e-Publishing index (Task 9). Org box addresses for PFM Offices are entered or loaded by CSV (org boxes are not users; directory lookup is unlikely to find them).

## Phase 2+3 round 1 (12 Nov): Q4-Q9 answered (4A 5A 6A 7A 8A plus manual upload, 9A); design and round 2 (Q10-Q14): docs/roles-and-permissions.md

| Q | Question | Options | REC |
|---|---|---|---|
| Q4 | Role model for PFM away | A: PFM, Alternate PFM, Acting PFM (+ Acting Until) as PFM Settings rows; PFM screens open to the PFM Office group; flows address the role. B: Person columns, edited by hand | A |
| Q5 | Whose connections run the flows | A: the PFM's, connection references, the alternate re-binds by runbook. B: the alternate keeps disabled backup copies. C: ask the communications squadron for a non-person service account | A (C closed: no service account, PFM 12 Nov and 14 Nov) |
| Q6 | Rights of the Acting PFM | A: full PFM rights, logged, reminder before Acting Until. B: no Settings changes | A |
| Q7 | Permission groups | A: setup makes one SharePoint group "PFM Office" (edit all PFM lists and the library; config lists edit only for it); wing access group read/contribute per P2A and 10A; existing AD groups nested where they exist. B: only the site's existing Owners/Members groups | A |
| Q8 | Intake sources in setup | A: existing site groups (as choices), scan of a library of posted publications into PFM Product Index (view "PFM - Imported, Not Confirmed"), products CSV (3A), e-Publishing index cross-check. B: CSV only | A |
| Q9 | Where posted wing publications live now | A: a library on the same site. B: a library on another site. C: mixed, or only on e-Publishing | Fact from the PFM |

Scale (REC, no question): PFM Activity Log reaches the 5,000-item view threshold in about 2.5 years at an estimated 2,000 rows a year (50 actions x 40 events; estimate, not measured). Index Created and Action ID at provisioning; views filter on indexed columns; a yearly archive flow.

## Phase 2 use and scale, round 4 (12 Nov): answered 19A weekly (Wed 0700), 20A plus chapters (docs/backup-and-restore.md), 21A

| Q | Question | Options | REC |
|---|---|---|---|
| Q19 | E-mail volume | A: one daily digest per person (weekdays) of what waits on them; immediate e-mail only for a new task and a due date reached. B: one e-mail per event | A: an AO with 10 coordinators would get 20+ e-mails per round with B |
| Q20 | Backup of list data | A: a weekly flow exports every PFM list to CSV in Record Sets/Backups, keeps 8 weeks. B: rely on the recycle bin and version history only | A: covers a wrong bulk edit or a deleted list after 93 days (risk R17) |
| Q21 | People who leave (AO, coordinator, approver) | A: a weekly flow checks the accounts named on open actions (Office 365 Users) and lists disabled or missing ones on the PFM screen. B: found by hand when an action stalls | A, if Office 365 Users passes the data-policy test (rights test D1/M03) |

## Phase 4 (13 Nov)

Step 1 screen map: docs/app/screen-map.md r1 (25 built screens). Map approved (26A-29A). Step 2 (clickable previews) cancelled by the PFM, 13 Nov.
