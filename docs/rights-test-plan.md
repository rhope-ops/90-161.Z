# Rights test plan r2 (14 Nov 26)

PFM decision (12 Nov): every assumption about rights is tested on the tenant before the design relies on it, with a fallback for each. This file lists each right the design needs, who is expected to have it, how it is tested, and the fallback. "Expected" comes from Microsoft documentation or this project's earlier tests; confidence is marked H (high), M (medium) or L (low). A row counts as proven only after a test on the DoD tenant. Results are gov-network test details, so they go in the private project log, never in this public repo (AGENTS.md Project rules); the repo records only the design rule that follows.

How it is tested:
- **Probe flow** (go.md Task 11): flow/packages/90161Z-T11-rights-probe-r3.zip, built from scripts/build_rights_probe.py. 43 SharePoint checks (R = read, W = write on TEST objects, X = cleanup) and 7 mail and people checks (U = Office 365 Users, E = Outlook; r2, PFM 14 Nov 26; E05 added in r3). It runs as the PFM and also asks SharePoint what a named coworker could do (R11, R12), so one person can test the regular-user view. E01, E03 and E04 send one test mail each to the PFM only (approved 14 Nov 26).
- **How the test mails arrived** (E05, probe r3): the Outlook COM check stopped at the Outlook address prompt (R11), so the flow does it: after a 2-minute delay it reads the test mails in the PFM's mailbox (Graph: subject, from, sender) and records for E01, E03 and E04 whether each arrived and how (from-me, sent-as-office, on-behalf-of-office, other), by comparing the from and sender addresses to the PFM's and the office address in lower case. No address is written.
- **Manual checks** (M rows): steps in Power Apps, Power Automate and the browser that the probe cannot do (they need Dataverse, the share dialogs or the browser). Each says what to click and what to write down; nothing is created that stays, and nothing is shared with Everyone.

Roles: **U** regular site member · **O** site owner (Full Control) · **A** site collection admin (the PFM) · **K** maker in the Default environment (any licensed user, by default) · **MB** rights on the office mailbox · admin roles (tenant SharePoint, Power Platform, Exchange) are outside a PFM's reach.

## 1. SharePoint site

| # | Right | Needed for | Expected | Conf | Test | Fallback |
|---|---|---|---|---|---|---|
| S1 | Read items | Everyone using the app | U, O, A | H | R11, R12 | - |
| S2 | Add and edit own items | Requests, coordinator answers; the app (wing users have Read on the site, PFM 14 Nov 26) | U after the list gives the user (r5) or their group Contribute, with item-level "own items" | H | R11, R12, C01, W11, R12b (r5: W11 grants the user ID from C01; r4 found no group) | Changes through a flow on the PFM's connection |
| S3 | Create lists, columns, views | Setup part 1, upgrades | O, A; also U when Members have "Edit" (Edit includes Manage Lists) | M | R06, R07b, R11, W01-W02 | A site owner runs setup part 1 |
| S4 | Give a list its own permissions | Settings and log read-only for members (P2) | O, A | H | W04, W05 | A site owner follows a checklist |
| S5 | Item-level permissions on a list | Edit own rows (DECISIONS 12 Nov) | O, A (Manage Lists) | H | W03, R09a, R09b | Changes through flows only |
| S6 | Create a SharePoint group | SharePoint-only group option (P6) | O, A | H | W07 | Use an existing group |
| S7 | Resolve an AD or Entra group on the site | AD group option (P6) | O, A | M | R13 (r3); G01, G03 (r4: counts by type, the AD group has no e-mail); G05, G06 (r5: every site group by type) | Add the group by hand in Site permissions |
| S8 | Give a folder its own permissions | Per-action Working Files folders | O, A | H | W08-W10 | One shared Working Files folder, PFM-only |
| S9 | Set version limits | Storage control | O, A | H | W03 | Leave defaults |
| S10 | Read a coworker's effective rights | Setup checks without a second login | O, A | M | R11, R12 | Ask a coworker to run the probe |
| S11 | Site time zone | Date-only columns | O can change | H | R08 (read) | Time zone row in PFM Settings |
| S12 | Site is group-connected (M365 group) | M365 group option (P6) | depends on site | H | R03 | - |
| S13 | Create a new site | A wing without a PFM site | Tenant setting | L | M18 | Request a site through the base process |
| S15 | Download several library files at once as one zip | Publication package download (docs/roles-and-permissions.md 6.4; PFM 12 Nov) | U | M | M20 | Download files one at a time from the app |
| S14 | Restore from the second-stage recycle bin | Recovery | A | H | Not tested (destructive) | Scheduled export (risk R17 in docs/brief/risks.json) |

## 2. Power Platform

| # | Right | Needed for | Expected | Conf | Test | Fallback |
|---|---|---|---|---|---|---|
| P1 | Create flows with SharePoint | Everything | K | H | Proven: T02 r9 ran | - |
| P2 | Use Office 365 Outlook, Office 365 Users in one flow with SharePoint | E-mails, people lookups | Data policy | M | M03 (R10), probe r2 saves | None: ask Power Platform admins |
| P3 | Use Approvals, Teams, RSS, Power Apps for Makers | Optional features | Data policy; Approvals needs Dataverse | L | M03 (R10) | Leave the feature out |
| P4 | Import a legacy package | Flows | K | H | Proven: T02 r9 imported | - |
| P5 | Create and export a solution | Solution route | K | H | Proven: T05 export | - |
| P6 | Import a solution | Solution route | K | M | M04 | Legacy package plus .msapp |
| P7 | Environment variables for the site and lists | Per-wing binding | K, in a solution | M | M05 | Site address typed at setup, stored in PFM Settings (P1B) |
| P8 | Create a canvas app | The app | K | H | M06 | - |
| P9 | Share the app with an AD or Entra security group | P6 | K | H | M07 | Named people |
| P10 | Share the app with an M365 group | P6 | K | M | M07 | Named people |
| P11 | Share the app with Everyone in the tenant | SharePoint-only group option | Tenant setting may block | L | M07 (look only; do not share) | Named people |
| P12 | Share the app with a SharePoint group | P6 | Not possible | H | M07 (confirm it is not offered) | Options above |
| P13 | Share a flow run-only and choose "use this connection" | App-started flows (G7) | K | M | M08 | App writes only rows the user owns |
| P14 | Add a co-owner to a flow and to the app | Continuity (P5A) | K | H | M09 | Export and re-import by the successor |
| P15 | Create another environment | Own environment option | Tenant setting | L | M10 (look only) | Default environment |
| P16 | See own license and request limits | Capacity | K | M | U02 | - |
| P18 | Largest file a Power Apps flow input accepts | "Attach all documentation" upload (6.5) | K | M | Pilot (phase 8): needs the app | Upload straight into the library Intake folder |
| P19 | A co-owner re-binds a connection reference to their own connection | Continuity (5A) | K | M | Pilot (phase 8): needs the solution | Co-owner rebuilds the connections by hand |
| P17 | Change the owner of a flow or app | Handover | Power Platform admin only | H | Not testable by a PFM | Runbook: co-owner rebuilds connections (P5A) |

## 3. E-mail (office mailbox)

| # | Right | Needed for | Expected | Conf | Test | Fallback |
|---|---|---|---|---|---|---|
| E1 | Send from own mailbox in a flow | All notices | K | H | E01, E05 | - |
| E2 | Open the office mailbox (Full Access) | Reading 847s, replies | MB | M | E02 | Forwarding rule set by the mailbox owner |
| E3 | Send as the office mailbox from a flow | Notices from the office (P4A) | MB Send As (Exchange admins grant) | M | E03, E05 | Send from the PFM, office box on copy and as Reply-To |
| E4 | Send on behalf of the office mailbox | Same | MB Send on Behalf | M | E04, E05 | Same as E3 |
| E5 | Start a flow when mail arrives in the office mailbox | 847 intake, result capture | MB Full Access | M | E02 (rights), M16 (trigger) | PFM forwards by hand |

## 4. Directory and groups

| # | Right | Needed for | Expected | Conf | Test | Fallback |
|---|---|---|---|---|---|---|
| D1 | Look up people (Office 365 Users) | Person pickers, AO lookup | K, data policy | M | U01 | SharePoint person fields only |
| D2 | Create an M365 group | M365 group option | Tenant setting | L | M17 (look only) | Use an existing group |
| D3 | Create or change an AD security group | AD group option | Communications squadron only | H | Not testable | Ask the squadron |
| D4 | See a group's type when picking it | Setup explanation | K | M | R13, M07; G01-G06 (r4, r5) | Setup asks the PFM |

## 5. Gov computer

| # | Right | Needed for | Expected | Conf | Test | Fallback |
|---|---|---|---|---|---|---|
| G1 | Run PowerShell 5.1 with Word | Renderer | Proven | H | T01 r5 | Format by hand |
| G2 | Run downloaded scripts as delivered | Renderer, checks | Policy | M | ISSM decision (risk R02) | Approved channel or signed scripts |

## 6. Manual checks (go.md Task 11, part B)

Write down only what each check shows (allowed, blocked, error text without names). Do not keep anything you create; delete it at the end. Done in R10 (results in the private log): M03. Done by the probe from r2 on: M11 (U02), M12 (E01), M13 (O1), M14 (E03), M15 (E04).

| # | Do | Write down |
|---|---|---|
| M04 | Power Apps: Solutions, Import solution, choose 90161Z-flows-solution-r1.zip (the round saves it in T11; the T05 sample is gone). Under Advanced settings, clear "Enable plug-in steps and flows" so its flows stay off | Imported, or the error |
| M05 | In a new solution: New, More, Environment variable, Data type Data source, Connector SharePoint, Parameter type Site | Allowed, or not offered |
| M06 | Power Apps: create a blank canvas app, save it as "90161Z TEST" | Saved |
| M07 | Share "90161Z TEST": type the wing's AD group, an M365 group name, a SharePoint group name, and look for "Everyone". Do not press Share | Which kinds show up |
| M08 | Share the flow "90161Z T11 Rights Probe r3" run-only with one coworker; open "Manage run-only permissions"; then remove them | Whether "Use this connection" is offered for SharePoint and Outlook |
| M09 | Add a coworker as co-owner of the flow "90161Z T11 Rights Probe r3" and of "90161Z TEST"; then remove them | Allowed or not |
| M10 | Power Platform admin center or the environment picker: is "New environment" or "Create developer environment" offered (do not create) | Offered or not |
| M16 | New automated flow: When a new email arrives in a shared mailbox (V2), office mailbox; save; send a test mail to the office box | Flow ran or error |
| M17 | Outlook: New, Group (look only) | Offered or not |
| M18 | SharePoint start page: Create site (look only) | Offered or not |
| M20 | SharePoint: open any document library you can read, tick 2 or 3 files, press Download | One .zip downloaded, or each file separately, or Download not offered |
| M21 | Microsoft Forms (Microsoft 365 app launcher, Forms): create a form "90161Z TEST form" with one question | Offered and saved, or error |
| M22 | Power Automate: new automated flow, trigger "When a new response is submitted" (Microsoft Forms), pick "90161Z TEST form"; save | Saved or error |
| M23 | Power Apps: Tables in the Default environment (Dataverse), and whether a Premium connector can be added to "90161Z TEST" (look only) | Tables shown or not; Premium allowed or blocked |
| M24 | Power Apps and Power Automate: is Copilot or AI Builder offered (look only) | Offered or not |
| M25 | SharePoint list PFM Publications: Integrate, Power Apps, Customize forms; Integrate, Power Automate (look only, do not save) | Each offered or not |
| M19 | Clean up: delete the M16 and M22 flows, "90161Z TEST", its solution, the solution M04 imported, and "90161Z TEST form" | Done |

## 7. Capability inventory (future projects)

PFM 14 Nov 26: the probes also record what later projects can use. All read-only; results go to the private log like the rows above.

| Where | What it records |
|---|---|
| Probe r2 R15-R26 | Site and site collection features, list and site templates offered, search, storage, app catalog, term store, content types, Site Pages, sensitivity label and sharing, list form setting |
| Probe r2 U02 | License names (shows Premium, Power Apps, Power Automate, Copilot plans) |
| T15 r2 (round) | All installed modules, PowerShell 7 and other tools, Office and Windows COM apps, WebView2, Teams, Power BI Desktop, fonts, C# compile, AppLocker rule counts, certificate count, .NET runtimes, more hosts |
| T16 r2 (round) | PnP on the new site: rights, PFM lists, storage, features, content types, site admin count, term store, search, app catalog, site designs, Power Platform environments and flows by PnP |
| M21-M25 | Microsoft Forms and its flow trigger, Dataverse and Premium, Copilot and AI Builder, list form and flow integration |

## Reading the result

The probe writes 90161Z-T11-rights-result-r<N>.json into the site's default library (r4: the Deployer's site setup copies it and masks the site address, host and path before it is attached) and shows the same list in the run's Result step. Each row: check ID, HTTP status, and either a short answer or an error. Status 200 or 201 = allowed; 403 = not allowed; 404 = the thing does not exist on that site. Permission masks (High, Low) are decoded in the cloud against SharePoint's PermissionKind values (for example ManageLists 12, ManagePermissions 26). Answers are requested without metadata, so the file holds no site address and no names, but it describes the site: e-mail it as go.md Task 11 says; it never goes into this public repository. R13 leaves the group in the site's hidden user list (harmless). Deleted TEST lists sit in the site recycle bin for 93 days. An M365 group may not resolve by e-mail address in R13; then the type is checked in M07.

## After the results

Each row gets a result (proven, blocked or partial, with the date) in the private project log. A blocked row turns its Fallback into the design, and setup (docs/setup-and-updates.md section 3) uses the same text for the instructions it shows.
