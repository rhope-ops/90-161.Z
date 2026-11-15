# Create the 90-161.Z lists with Power Automate

Decided (PFM, 2026-11-10): lists are created by a Power Automate flow, not PowerShell. The flow runs under your own sign-in and uses only the SharePoint connector ("Send an HTTP request to SharePoint"): no premium license, no admin.

Names (PFM, 2026-11-11, docs/DECISIONS.md): every list has the prefix PFM. Each list is created under its URL name without spaces, then gets its display title.

## 1. What the flow creates

| Display title | URL name | Holds | Who sees rows |
|---|---|---|---|
| PFM Offices | PFMOffices | One row per coordinating office | All site members |
| PFM Series | PFMSeries | Series numbers and titles (DAFMAN Table A2.1), 39 rows added by the flow | All site members |
| PFM Process Steps | PFMProcessSteps | The process steps with Table A5.2 target business days (draft; not seeded) | All site members |
| PFM Settings | PFMSettings | One row per setting (wing name, PFM mailbox, defaults); 7 rows added by the flow (2 with values: DAFMAN 5.2, 5.2.2 suspense days) | All site members |
| PFM Guidance | PFMGuidance | The guidance the app shows on each screen | All site members |
| PFM Publications | PFMPublications | One row per action (8 DAFMAN 1.1.4 types); points to its Product Index row | All site members; edit own rows (10A) |
| PFM Waivers | PFMWaivers | Waivers written into wing publications (DAFMAN 9.5.3) | All site members |
| PFM Activity Log | PFMActivityLog | One row per event; Created and Publication indexed | All site members |
| PFM Endorsements | PFMEndorsements | One row per coordinator per action; Coordination Stage (Privacy Review, Formal Coordination, Legal) | All site members; edit own rows (10A) |
| PFM Recommendations (DAF Form 847) | PFMRecommendations | Recommended changes to publications (DAF Form 847) | All site members |
| PFM Product Index | PFMProductIndex | The Product Index (DAFMAN 6.4.2) | All site members |
| PFM Reviews | PFMReviews | One row per periodic or special review (DAFMAN 7.4.2-7.4.4) | All site members |

Columns, views and their DAFMAN references: `schemas/lists/*.json` (one file per list, named by URL name). The payload `flow/provisioning-payload.json` is generated from them.

## 2. Import and run

Package: `flow/packages/90161Z-T02-provision-lists-r12.zip` (built by `python3 scripts/build_flow_package.py` from `flow/defs/90161Z-T02-provision-lists-r12.json`; the payload is embedded at build). r12 (R21) adds Status Reason, Held Since, Coordination Round and the Action Status choices Cancelled and Complete; a site made by r11 gets them from T19 instead (scripts/gov/90161Z-T19-list-update-r2.ps1). Steps for the gov device are in go.md, Task 2 (new site, PFM S1, 2026-11-14).

The flow asks for one input, **Site URL**: the full address of the site that will hold the lists. Paste it from the site's address bar. The site-title check was removed in r9 (PFM, 2026-11-12); check the address before you run.

Order of work:
1. **Create Lists**: 12 lists under their URL names, versioning on.
2. **Get ... ID** (Offices, Process Steps, Product Index, Publications, Series): the IDs that lookup columns need.
3. **Create Fields And Views**: columns, views and view columns, one request at a time.
4. **Add Rows**: 88 rows: 39 into PFM Series, 7 into PFM Settings, 29 into PFM Offices, 13 into PFM Process Steps.
5. **Apply Updates**: index Created on the Activity Log, rename the Title column where a list uses another label (Setting, Event, Office), then set each list's display title. This runs last because steps 1-3 find lists by URL name.
6. **Set Item Permissions** (from r11): item-level permissions on PFM Publications and PFM Endorsements (section 4). If SharePoint refuses, the run still ends and Result says NOT SET.
7. **Result** shows the counts and the permission result.

## 3. Checks after the run

| Check | Pass |
|---|---|
| Run | Succeeded; Result shows "Lists: 12, fields and views: 329, rows: 88, updates: 21. Provisioning finished. Item-level permissions: set on 2 lists." |
| Site contents | The 12 display titles in section 1 exist; PFM Series has 39 rows, PFM Settings 7, PFM Offices 29, PFM Process Steps 13 |
| List address | Open PFM Publications: the address ends in /Lists/PFMPublications |
| PFM Endorsements, Endorser column | Type Person or Group, people only |
| PFM Endorsements, Endorsement Status column | Choices: Not Started, Concur, Concur With Comment, Concur—No Response, Nonconcur, No Comment; default Not Started |
| PFM Endorsements, Coordination Stage column | Choices: Privacy Review, Formal Coordination, Legal; default Formal Coordination |
| PFM Publications, Product column | Lookup to PFM Product Index, shows Publication Number |
| PFM Publications, OPR column | List settings > OPR shows the description "The office of primary responsibility (OPR) for the action, from PFM Offices." (columns with abbreviations spell them out; docs/style-standard.md) |
| PFM Publications, Status Notes column | List settings > Status Notes shows "Append Changes to Existing Text: Yes" |

Run it once. A second run fails on lists and fields that already exist and ends red; that is expected.

If a run fails part way (any step red, Result not shown), do not run it again on top. Recover:
1. Note the failed step's name, HTTP status and error code.
2. Site contents: delete every list whose name starts with PFM (they are empty after provisioning). Some may still show their URL name (for example PFMPublications) because titles are set last.
3. Empty the site recycle bin of those lists (Recycle bin > select > Delete), so the URL names are free again.
4. Run the flow again.

If a step fails, open it and send only the HTTP status code and the error code (for example `400 / -2130575342`). Do not send URLs or names.

## 4. Permissions and site settings

Decided (PFM, 2026-11-12, 10A): all site members read all rows. On PFM Publications and PFM Endorsements, members edit only rows they created. Read access stays "Read all items", so the AO, endorsers and flows still see every row. A row a flow creates is "created by" the flow's connection owner, so customers and endorsers change those rows through the app, which runs a flow (endorser results). Site collection administrators and people with Manage Lists edit every row.

1. Leave each PFM list on the site's permissions (no unique permissions).
2. Set by the flow from r11 (PFM, 2026-11-14). By hand only if Result says NOT SET (fallback, also for wings whose flow is refused): PFM Publications and PFM Endorsements only: List settings > Advanced settings > Item-level Permissions. Read access: Read all items. Create and Edit access: Create items and edit items that were created by the user. OK. Other lists: no change.
3. Site settings > Regional settings > Time zone: (UTC-06:00) Central Time. Date-only columns (suspense, due and review dates) then show the same day for everyone.

## Change a list or column

1. Edit `schemas/lists/<URL name>.json`. Names follow the rules in docs/DECISIONS.md (2026-11-11); `tests/check_names.py` fails on a name that breaks them.
2. Run `python3 scripts/build_flow_payload.py`, then `python3 scripts/build_flow_package.py`. Never hand-edit the payload or the zip.
3. Run `tests/run.sh` (pass = `TESTS pass=N fail=0`).
4. A list that already exists on the site is not changed by a re-run. Add a new column by hand in List settings, with the same internal name, or plan a change flow.
