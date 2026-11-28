# Roles, permissions and intake: design r1 (12 Nov 26)

Status: design from phase 2+3 rounds 1-2 (Administrator 4A 5A 6A 7A 8A+ 9A; 10A 11A 12A+ 13A 14B, 12 Nov; docs/decisions-archive.md). Items marked **REC:** are agent recommendations, open until the Administrator approves. Items marked **Test** are not proven on the tenant (docs/rights-test-plan.md). Library layout and folder permissions: docs/reviews/2026-11-12-list-design-full-scope.md section 5 (decided in batch 2).

## 1. Roles are data (Administrator 4A, 6A)

| PFM Settings key | Value | Who changes it |
|---|---|---|
| PFM | Person (sign-in address) | PFM or Alternate PFM, through the app |
| Alternate PFM | Person | PFM, through the app |
| Acting PFM | Person, empty when nobody acts | PFM or Alternate PFM (**REC:** Q11) |
| Acting Until | Date | Same as Acting PFM |

- The app shows the PFM screens to members of the SharePoint group **PFM Office** (decided 3.7B). Flows address a role ("send to Acting PFM, else PFM"), never a fixed person.
- The Acting PFM gets full Administrator rights (6A). Every change is a PFM Activity Log row.
- Flow "90-161.Z - Assign Acting PFM" (app button): adds the person to PFM Office, writes the two Settings rows, logs, e-mails the Administrator, the Alternate PFM and the new Acting PFM.
- The daily health-check flow (P5A) warns 5 weekdays before Acting Until. **REC:** Q10 for what happens on the end date.

## 2. Connections (Administrator 5A)

Service accounts are not available in practice (Administrator, 12 Nov). Flows run on the Administrator's connections, inside a solution with connection references.

- The Alternate PFM is co-owner of the solution, every flow and the app (continuity decision 2026-11-11).
- If the Administrator's account stops: the Alternate PFM opens the solution, sets each connection reference to the Alternate's own connection, turns the flows back on. Runbook step list in the handover runbook (P5A). **Test:** a co-owner can re-bind a connection reference without the original owner (add to Task 11).
- The health-check flow reports a broken connection the same day (a flow that cannot run cannot report itself: **REC:** a second, tiny flow on the Alternate's connection checks that the health-check ran).

## 3. Permission groups (Administrator 7A)

| Group | Made by | Members | Rights |
|---|---|---|---|
| PFM Office (SharePoint group) | Setup (T20 r2 makes it when missing) | PFM, Alternate PFM, Acting PFM, people who work the org box | The level "PFM Office Edit All Items" on the site: Edit plus Override List Behaviors, so its members edit every row (Administrator F2 A, 2026-11-19; docs/power-automate-provisioning.md section 4); the 90-161.Z library; only group with edit on config lists (P2A) |
| Wing access group (existing; type per P6) | Exists | All wing members | Read on the site and all lists; Contribute on the 3 intake lists only (section 7, Administrator 19 Nov 26); edit own rows only on PFM Publications and PFM Endorsements (10A); read on Published |
| Site Owners (existing) | Exists | Site owners | Unchanged; not used by the app |

- **REC:** Q13: the owner of PFM Office is PFM Office itself, so any member can add an Acting PFM when no site owner is reachable.
- A flow sets these through SharePoint REST when the installer has Manage Permissions (R5); else setup prints a checklist for the site owner.

## 4. Intake of existing data (Administrator 8A plus manual upload, 9A)

| Source | How | Result |
|---|---|---|
| Existing site groups | Setup reads the site's groups and offers them as the wing access group | Choice, nothing copied |
| Library of posted publications on the same site (9A) | Setup asks which library; a flow reads file names and file properties (Title, Modified) and matches the designator pattern | One PFM Product Index row per file, view "PFM - Imported, Not Confirmed"; the Administrator confirms each row |
| Manual upload (Administrator, 12 Nov) | App screen: upload one existing publication or form; same reading as the scan | One row, same view |
| Products CSV (3A) | Import screen | Rows, same view |
| e-Publishing index (Task 9) | Cross-check by number | Report of mismatches |

- Limit (high confidence): standard connectors cannot read the text of a PDF or .docx; AI Builder is premium. So OPR, certifier and dates come from typing, or from Q12.
- Decided 12A+ (12 Nov): the runner reads the covers; every value has a manual override. A row with Manual Override = Yes is never overwritten by a later import.
- Decided 14B (12 Nov): existing files are copied into the 90-161.Z library and sorted (section 6).

## 5. Round 2 (answered 12 Nov: 10A 11A 12A with manual override, 13A, 14B)

| Q | Question | Options | REC |
|---|---|---|---|
| Q10 | Acting PFM on the end date | A: removed from PFM Office the next weekday, logged, warning 5 weekdays before. B: reminder only; a person removes | A |
| Q11 | Who may name an Acting PFM | A: PFM or Alternate PFM. B: any PFM Office member | A |
| Q12 | Cover data of existing publications | A: a runner step on the gov device reads the covers of a folder of existing publications with Word COM (number, title, date, OPR, certifier) into the 3A CSV; real data stays on the device and in SharePoint. B: file name and properties only, the rest typed | A |
| Q13 | Owner of the PFM Office group | A: the group itself. B: site Owners | A |
| Q14 | Existing publication files | A: stay in place, the row links to them. B: copied into 90-161.Z Published | A (no broken links, no duplicates) |

## 6. The publication package: one file, one place

Problem (Administrator, 12 Nov): the same publication can sit as a list attachment, in a folder, and as an app download. Three copies drift apart.

Design:
1. **Files live only in the 90-161.Z library.** **REC:** Q16: attachments are off on every PFM list. A list attachment has no metadata, no own permissions, no place in a record set, and is a second copy.
2. **Metadata ties a file to its package, not the folder.** Library columns: Product (lookup PFM Product Index), Action (lookup PFM Publications, optional), Document Role (choice: Publication, Prescribed Form, Draft, DAF Form 673, CRM, Endorsement Evidence, Impasse Memo, Delegation Letter, Seal, Other), Edition Date, Is Current (yes/no). The package of a product = every file with that Product value, wherever its folder is.
3. **Folders exist for permissions and for people who browse.** A flow makes the folder when it is missing and sets its permissions (layout: Q15).
4. **The app reads the library.** Download = the library file's own link (one copy). "Package" panel = the files of that product the viewer may open. Download several at once: the app opens the library view filtered to the product, where SharePoint's own Download zips the selected files (medium confidence: works in SharePoint Online; no zip action in standard connectors).
5. **"Attach all documentation you have"** (setup intake, and any time in the app): the user uploads any number of files on one screen. A Power Apps flow writes each file to the library with metadata; it suggests the Document Role from the file name (designator, 673, CRM, 847, _DRAFT) and the user can change it; files it cannot place go to folder Intake, view "PFM - Intake, Needs Sorting". Manual upload straight into the library also works: the same flow runs on new files in Intake. **Test:** largest file a Power Apps flow input takes on the tenant (rights test P18, pilot). Multi-file zip download: rights test S15, go.md Task 11 check M20 (Administrator, 12 Nov: test it).

Answered 12 Nov: 15A 16A 17A 18A (with the user told the originals are theirs to keep, move or delete).

| Q | Question | Options | REC |
|---|---|---|---|
| Q15 | Folder layout | A: top-level folders by permission (Published, Record Sets, Working Files, Delegation Letters, Seals, Intake), one subfolder per product or action inside each. B: one folder per product, with Published, Record Sets and Working Files inside it | A: matches the decided permissions; about 1 unique permission scope per action, against about 2 more per product for B; members browse one Published folder. The app gives the per-product view either way |
| Q16 | List attachments | A: off on every PFM list; files only in the library. B: on, for convenience | A |
| Q17 | Document Role on upload | A: the flow suggests it from the file name, the user confirms or changes it; unknown files go to Intake. B: the user picks it for every file | A |
| Q18 | Originals after the copy (14B) | A: leave them; the Administrator sets the old library to read-only after checking the copy. B: delete originals after the check. C: leave both open | A: no data loss, no drift |

Intake screen text after the copy (18A, Administrator 12 Nov): "Your original files are not changed. 90-161.Z works from its own copies. You may keep, move or delete the originals as you see fit. Tip: set the old library to read-only so no one edits a copy that 90-161.Z does not see."

## 7. App writes: Contribute on the intake lists (Administrator 19 Nov 26)

Decision (docs/DECISIONS.md, 19 Nov 26; it replaces way C, a flow that writes with the Administrator's connection): wing users, the site's associated Visitors group, get list-level Contribute on the intake lists only. The site stays Read. The Power Apps app writes with the user's own rights, so this is what lets a wing user submit a request, an endorser entry or a DAF Form 847 recommendation.

| Intake list | Why it is an intake list | Source |
|---|---|---|
| PFM Publications | The request: the AO submits it in the app; edit own rows (10A) | docs/ARCHITECTURE.md (UI row, Process step 1, risk row on edit own rows) |
| PFM Endorsements | The endorser entry: customers enter their endorsers; edit own rows (10A) | docs/ARCHITECTURE.md (goal G3, UI row, risk row on edit own rows) |
| PFM Recommendations | DAF Form 847 intake | docs/ARCHITECTURE.md (Data row) |

Every other list (PFM Waivers, PFM Reviews, PFM Activity Log, PFM Offices, PFM Series, PFM Process Steps, PFM Settings, PFM Guidance, PFM Product Index) keeps inheriting from the site: Read for wing users, written by flows and the PFM Office.

- T20 r4 (scripts/gov/90161Z-T20-provision-lists-r4.ps1) sets it. For each intake list: if the list inherits, it gets its own permissions with the site's role assignments copied (so the PFM Office level stays); then the Visitors group gets the level Contribute on that list when it does not hold it. A second run changes nothing. It works only on this site (no other host), reads first, and never changes the site's own permissions.
- Read-back: one line per list, `ITEM W01` to `W03`: PASS when the list has its own permissions and Visitors hold Contribute on it; FAIL names the reason (no Visitors group, no Contribute level, the list inherits, the role is missing).
- "Edit own rows" is unchanged: Contribute lets a person add rows, and the list setting keeps each person to their own rows on PFM Publications and PFM Endorsements; the PFM Office level still edits every row.
- Proof on the device: T21 test T4 (a second person who is a Visitors member saves a row through the list form) expects PASS. Run T20 r4 first so the app lists have the role; the T21 probe list gets it from its Make part. R16 W11 showed that a Read-only user gets Contribute on such a list.
- Open: the wing access group may be a different group from the site's Visitors group on a site (P6). T20 r4 uses the associated Visitors group only; if the wing group is another group, name it before the round.
