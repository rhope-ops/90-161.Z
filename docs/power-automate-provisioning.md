# How the 90-161.Z lists are made, and what Power Automate still does

Status (19 Nov 26): the 12 lists are made by a script (task T20), not by a flow. Round R25 proved it on a clean site (docs/reviews/2026-11-15-r25-results.md, finding 1; Administrator decision of 14 Nov 26 "Lists by PnP" in docs/DECISIONS.md). The provisioning flow of task T02 is retired. Power Automate still runs the 6 flows of the app (section 5).

Names (Administrator, 2026-11-11, docs/DECISIONS.md): every list has the prefix PFM. Each list is created under its URL name without spaces, then gets its display title.

## 1. What the script creates

| Display title | URL name | Holds | Who sees rows |
|---|---|---|---|
| PFM Offices | PFMOffices | One row per coordinating office | All site members |
| PFM Series | PFMSeries | Series numbers and titles (DAFMAN Table A2.1), 39 rows added by the script | All site members |
| PFM Process Steps | PFMProcessSteps | The process steps with Table A5.2 target business days (draft; not seeded) | All site members |
| PFM Settings | PFMSettings | One row per setting (wing name, PFM mailbox, defaults); 7 rows added by the script (2 with values: DAFMAN 5.2, 5.2.2 suspense days) | All site members |
| PFM Guidance | PFMGuidance | The guidance the app shows on each screen | All site members |
| PFM Publications | PFMPublications | One row per action (8 DAFMAN 1.1.4 types); points to its Product Index row | All site members; edit own rows (10A) |
| PFM Waivers | PFMWaivers | Waivers written into wing publications (DAFMAN 9.5.3) | All site members |
| PFM Activity Log | PFMActivityLog | One row per event; Created and Publication indexed | All site members |
| PFM Endorsements | PFMEndorsements | One row per coordinator per action; Coordination Stage (Privacy Review, Formal Coordination, Legal) | All site members; edit own rows (10A) |
| PFM Recommendations (DAF Form 847) | PFMRecommendations | Recommended changes to publications (DAF Form 847) | All site members |
| PFM Product Index | PFMProductIndex | The Product Index (DAFMAN 6.4.2) | All site members |
| PFM Reviews | PFMReviews | One row per periodic or special review (DAFMAN 7.4.2-7.4.4) | All site members |

Columns, views and their DAFMAN references: `schemas/lists/*.json` (one file per list, named by URL name). The payload `flow/provisioning-payload.json` is generated from them.

## 2. How the lists are made (task T20)

The script is `scripts/gov/90161Z-T20-provision-lists-r4.ps1`. You run it through RADE, in a round (the README, "Open the script"). It signs in to the site with PnP.PowerShell and builds the lists from `flow/provisioning-payload.json`. That file is generated from `schemas/lists/*.json`. The script header gives its modes and what it changes on the site. In short, a run on a clean site does this:
1. Creates the 12 lists under their URL names, with versioning on.
2. Adds the columns (199) and views (18).
3. Adds the 88 starting rows to PFM Offices, PFM Series, PFM Process Steps and PFM Settings.
4. Sets the display titles, column titles and indexes.
5. Sets "read all items, edit own rows" on PFM Publications and PFM Endorsements (section 4).
6. Gives the group PFM Office the permission level "PFM Office Edit All Items" on the site (section 4), and makes the group and the level when they are missing.
7. Checks every list against the payload, then reads the PFM Office level back.

The script never deletes a list, a column, a view, a row, a group or a level. A second run skips what is already there, so a run that stopped can run again. It changes only lists it created under their own URL name. A list a person made and titled like one of ours is never changed.

Modes: `-PlanOnly` (no sign-in, prints the counts), `-Check` (reads the site and reports what 90-161.Z left on it; a clean site passes) and `-DryRun` (reads the site and prints what a run would create).

## 3. Checks after the run

The round reports the script result. In R25 the pass was 15 of 15 checks: 12 lists, 199 columns, 18 views, 88 rows, edit own rows on 2 lists (docs/reviews/2026-11-15-r25-results.md). Check these by eye as well:

| Check | Pass |
|---|---|
| Round result | The T20 step reads PASSED, with 12 lists, 199 columns, 18 views and 88 rows |
| Site contents | The 12 display titles in section 1 exist; PFM Series has 39 rows, PFM Settings 7, PFM Offices 29, PFM Process Steps 13 |
| List address | Open PFM Publications: the address ends in /Lists/PFMPublications |
| PFM Endorsements, Endorser column | Type Person or Group, people only |
| PFM Endorsements, Endorsement Status column | Choices: Not Started, Concur, Concur With Comment, Concur—No Response, Nonconcur, No Comment; default Not Started |
| PFM Endorsements, Coordination Stage column | Choices: Privacy Review, Formal Coordination, Legal; default Formal Coordination |
| PFM Publications, Product column | Lookup to PFM Product Index, shows Publication Number |
| PFM Publications, OPR column | List settings > OPR shows the description "The office of primary responsibility (OPR) for the action, from PFM Offices." (columns with abbreviations spell them out; docs/style-standard.md) |
| PFM Publications, Status Notes column | List settings > Status Notes shows "Append Changes to Existing Text: Yes" |

If a run stops part way, send the result file (the script writes it into the T20 task folder). Run the script again: it skips what exists. Send only counts and list, column and view names; never the site address.

## 4. Permissions and site settings

Decided (Administrator, 2026-11-12, 10A): all site members read all rows. On PFM Publications and PFM Endorsements, members edit only rows they created. Read access stays "Read all items", so the AO, endorsers and flows still see every row. A row a flow creates is "created by" the flow's connection owner, so customers and endorsers change those rows through the app, which runs a flow (endorser results). SharePoint lets a person edit every row of such a list only with the permission Override List Behaviors, which the Edit level does not have (sweep F2, docs/reviews/2026-11-13-sweep-decisions.md). So the group PFM Office (the PFM, the Alternate and the Acting PFM) gets the permission level "PFM Office Edit All Items": the site's Edit level plus Override List Behaviors (Administrator, 2026-11-19, F2 A; T20 r2 step 6). A device test with a second person proves it (F2 B: T21 r8, part Office and test EDITALL).

1. Leave each PFM list on the site's permissions (no unique permissions).
2. Set by the T20 script. By hand only if the script reports it did not set it: PFM Publications and PFM Endorsements only: List settings > Advanced settings > Item-level Permissions. Read access: Read all items. Create and Edit access: Create items and edit items that were created by the user. OK. Other lists: no change.
3. Site settings > Regional settings > Time zone: (UTC-06:00) Central Time. Date-only columns (suspense, due and review dates) then show the same day for everyone.

## 5. What Power Automate still does

Power Automate runs the 6 flows of the solution "90-161.Z flows" (F01 activity log, F02 next review due, F03 suspense reminders, F04 status report, F05 endorsement routing, F06 hold and resume). They use the SharePoint and Office 365 Outlook standard connectors under your own sign-in.

- Source: `flow/solution/defs/*.json`. `python3 scripts/build_flow_solution.py` builds the solution zip from them (`flow/solution/90161Z-T24-full-flows-r2.zip`). Never hand-edit the zip.
- Import: a round has you import the solution (task T24). Importing it again over an older copy works as an upgrade: the flows keep their connections and the new versions replace the old. The page's message "The original workflow definition has been deactivated and replaced" is the normal upgrade message (docs/reviews/2026-11-18-r32-results.md, findings 1 and 2).
- After the import, all 6 flows read On with no connection warning (R32, finding 1).
- Not yet working: a flow made by hand and a solution that the environment has never held fail with "The connections could not be loaded" (R32, finding 3). The Administrator decided on 18 Nov 26 to put the two probe flows into the solution instead (finding 4, option A).

See also: [flow-handover.md](flow-handover.md) (co-owners, connection swap and checks when the person who imported the flows leaves).

## 6. The retired provisioning flow (task T02)

The T02 flow is no longer the way to make the lists. Do not run it on a new site. It is kept as history only:
- Definition: `flow/defs/90161Z-T02-provision-lists-r12.json`.
- Package: `flow/packages/90161Z-T02-provision-lists-r12.zip`.
- Its last runs and the decision that retired it: docs/reviews/2026-11-12-gov-results-t01-t02-t05.md and docs/DECISIONS.md (2026-11-14 "Lists by PnP").

## Change a list or column

1. Edit `schemas/lists/<URL name>.json`. Names follow the rules in docs/DECISIONS.md (2026-11-11); `tests/check_names.py` fails on a name that breaks them.
2. Run `python3 scripts/build_flow_payload.py`. Never hand-edit the payload.
3. Run `tests/run.sh` (pass = `TESTS pass=N fail=0`).
4. A list that already exists on the site is not changed by a run. Add a new column by hand in List settings, with the same internal name, or plan an update script (T19 is the model: `scripts/gov/90161Z-T19-list-update-r6.ps1`, which adds new choices to an existing column, for example the tier T-0 in r4).
