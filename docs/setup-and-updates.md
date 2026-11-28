# Setup and updates (r2, 19 Nov 26)

Status: Part 0 and section 5 describe how a person installs and updates today, through RADE. The other parts are still design (12 Nov): items marked **Rec:** are agent recommendations, not decisions; items marked **Test** are not proven on the DoD tenant. Anything marked "not decided yet" has no source yet. Administrator decisions: docs/DECISIONS.md (2026-11-14 "One preflight" and "Updates").

## 1. Goals (Administrator, 12 Nov)

1. One person with the needed rights sets up 90-161.Z end to end.
2. Setup checks each right first. For each missing right it says whom to ask, what to ask for, and the fallback.
3. RADE checks the installed version at each run (Administrator, 14 Nov 26). The app shows its installed version only: section 5.
4. Every step works for a wing PFM with less access than this Administrator (AGENTS.md "Deployable package").

## 2. Setup sequence

The app cannot check rights before it exists, so setup has 4 parts. Each part stops with a clear message, never a half-built site.

| Part | What runs | Where | Result |
|---|---|---|---|
| 0. Preflight | The RADE checks (Part 0 below) | The RADE window on your computer | A check report in the results e-mail: each check PASSED, or what to do |
| 1. Lists | Script T20, run by RADE (docs/power-automate-provisioning.md) | RADE window, SharePoint site | The 12 lists, columns, views and starting rows |
| 2. App and flows | The solution "90-161.Z flows", imported in a step of a round; connections made by the installer | Power Automate | The 6 flows bound to the wing's site (docs/power-automate-provisioning.md section 5) |
| 3. First-run setup | Setup screen in the app, shown while PFM Settings "Setup Complete" = No | Power Apps | Wing values entered and checked; self-test; Setup Complete = Yes |

## 2a. Part 0: install through RADE

RADE is the Redacted Application Deployment Engine: https://github.com/rhope-ops/RADE. It replaces the setup-check flow (Administrator, 14 Nov 26 "One preflight"). Sources: the README "Open the script" and the open task in go.md; docs/dev-setup.md "RADE engine".

What you do:
1. Open https://github.com/rhope-ops/90-161.Z (the README). Every file a task needs comes inside the round.
2. Click **Open the script**. You see the script as plain text, with the steps to run it at the top.
3. Press Ctrl+A to select all.
4. Press Ctrl+C to copy.
5. Open the Start menu, type ISE and open Windows PowerShell ISE. Do not choose "Run as administrator".
6. Select File > New. Click in the white script pane.
7. Press Ctrl+V, then F5. The RADE window opens.
8. Look at the title bar of the RADE window. It shows "build" and a short code. The README shows the same code after **Build:**, on the **Round script** line.
9. In the RADE window, click the row of the round (for example **90-161.Z R42**). RADE runs its checks, then shows the card **Ready to run round R42.**
10. On that card, read the line that starts with "Writes to". It must show your OneDrive RADE\90-161.Z folder and the count of new, replaced and recycled files. **Record (F2)** at the bottom of the window lists every file.
11. Click **Run**. Keep the window open until the card **Round R42 is done.** or **The round needs review.** shows.
12. An Outlook draft opens with the checks, the summary and the result files. If its To line is empty, type your own e-mail address. Send it.

What RADE checks: the window runs its checks first and reports each as passed or not. Most checks that passed are not run again for 7 days. A check that fails shows a line "What to do". Do that line; do not work around it. Which checks RADE runs for another wing: not decided yet (the sources do not list them).

What RADE writes: only into your OneDrive folder RADE\90-161.Z (task folders, Config and the results folder Rounds\<round>). It never sends the e-mail itself.

What is not a RADE check: the connector data policy and Send As (R7, R9). A small probe flow stays for these (Administrator, 14 Nov 26). Its build: not decided yet.

## 3. Rights matrix

Each row: what setup needs, how Part 0 detects it, and what to do if it is missing. The request text goes into the preflight report as is, so the installer can paste it into a ticket or e-mail.

| # | Right or prerequisite | Needed for | How Part 0 detects it | If missing: ask whom, for what | Fallback |
|---|---|---|---|---|---|
| R1 | Power Apps and Power Automate in the M365 license | Everything | Implicit: Part 0 runs at all | Base communications help desk: "Power Apps and Power Automate access for my account" | None; stop |
| R2 | Maker rights in the Default environment (import, create flows and apps) | Parts 0-2 | Implicit: import of Part 0 works | Tenant Power Platform admins through the help desk | None; stop |
| R3 | Solution import in the Default environment (needs Dataverse in that environment) | Part 2 (solution route) | **Test**: try importing an empty solution | Same as R2 | Legacy package for flows plus .msapp for the app (works today for flows: the solution import of task T24) |
| R4 | A SharePoint site for the PFM office | Parts 1-3 | Installer enters the site address; Part 0 reads it | Site request through the base SharePoint/communications process | None; stop |
| R5 | Full Control (site owner) on that site: Manage Lists, Manage Permissions | Part 1, permissions | SharePoint REST `effectivebasepermissions` on the web, checked for ManageLists and ManagePermissions | The site owner or site collection admin: "add me to the site Owners group" | Part 1 can run with Manage Lists only; permission steps go to a site owner as a checklist |
| R6 | Site collection admin | Nothing required | REST `currentuser/IsSiteAdmin` (report only) | - | Not needed (Rec: design keeps it optional) |
| R7 | Standard connectors allowed together by the data policy (SharePoint, Office 365 Outlook, Office 365 Users) | Flows | **Test**: Part 0 itself uses SharePoint and Outlook; save fails on a DLP block | Tenant Power Platform admins: "allow SharePoint and Office 365 Outlook in the same data group in the Default environment" | None; stop |
| R8 | The group that gives wing members access (type differs by wing: section 4a) | Site access and app sharing | Installer picks the type and the group; Part 0 resolves it with SharePoint `ensureuser` and reports its type (probe R13) | Communications squadron for an AD group; the site owner for a SharePoint group | Section 4a fallbacks |
| R9 | Send As or Send on Behalf for the PFM office mailbox | Office-mailbox e-mails | **Test**: Part 0 sends a test from the shared mailbox; failure = missing | Exchange admins through the help desk | Send from the installer, office box on CC and Reply-To (Settings switch) |
| R10 | A second person (co-owner, alternate PFM) | Continuity | Installer enters the person; Part 0 checks the account resolves | Wing leadership names an alternate | Setup completes with a warning that stays on the PFM screen |
| R11 | (dropped, Administrator 14 Nov 26: no central Releases list) | - | - | - | - |
| R12 | Gov computer with Windows PowerShell 5.1 and Word 16 | Renderer | Gov-device task script (scripts/gov/Test-Environment.ps1) | Communications squadron | Format by hand with the DAFMAN template |
| R13 | GenAI.mil access | Draft cleanup | Manual check | Unit GenAI.mil access process | Draft cleanup by hand |

## 4. First-run setup screen (Part 3)

Values the installer enters, each checked before save:

| Value | Check |
|---|---|
| Wing display name (subtitle) | Not empty |
| Administrator, alternate Administrator (Person) | Both resolve; not the same person |
| PFM office mailbox | Valid address; R9 result decides the send mode |
| Access group type and group (section 4a) | Resolves (R8); type matches the choice |
| Time zone | One of the Windows time zones; used by every date-only flow step |

Self-test at the end: create a fake TEST publication, run one flow round trip, read back the Activity Log row, delete the test rows. Pass = Setup Complete = Yes.

## 4a. Access group (Administrator P6, 12 Nov)

Wings give members access in different ways: one AD (Entra) security group for read; SharePoint-only groups; AD groups only. Setup asks which one this wing uses and explains the best fit. The Administrator can change it later on the app's Settings screen.

Two separate things, often confused:
- **Data access** = SharePoint permissions on the site and lists. This is what protects the data.
- **App access** = who can open the app. Sharing the app grants no data access.

| Wing uses | Site access | App sharing | Fit |
|---|---|---|---|
| One AD or Entra security group of all members | Add the group to site Members (or Visitors) | Share with the same group | **Best**: one group does both; membership stays with the communications squadron |
| The site's M365 group (group-connected site, probe R03) | Group members are site members | Share with the M365 group | Good: one group does both |
| SharePoint-only groups | The SharePoint group | A SharePoint group cannot be used (rights test P12). Share with Everyone in the tenant if allowed (P11), or with named people | Works; data stays protected by the SharePoint group. Named people = upkeep at every arrival |
| AD groups nested in a SharePoint group | The SharePoint group | Share with the AD group(s) | Good |

Text the setup screen shows (plain words): "Pick the group your wing already uses to give members access to SharePoint. If you have an AD security group of all wing members, pick it: it opens both the site and the app. If you use only SharePoint groups, the app is opened to the whole tenant or to named people, and your SharePoint group still decides who sees the data."

Settings rows (PFM Settings): Access Group Type (AD Security Group, M365 Group, SharePoint Group, Nested), Access Group (sign-in name or group ID), App Share Mode (Group, Everyone, Named People).

Change later (Settings screen, Administrator and alternate only): the app calls a flow on the Administrator's connection that adds the new group to the site role and removes the old one (needs Manage Permissions: rights S4, S7). App sharing changes are a manual step the screen walks through, unless the Power Apps for Makers connector is allowed (rights P3); then a flow does it.

## 5. Updates (Administrator, 14 Nov 26: installed version only)

| Item | Today |
|---|---|
| Installed version | The app shows its installed version only. There is no "Check for updates" button and no central Releases list |
| Who compares | RADE compares versions at each run (Administrator, 14 Nov 26). How the window shows the result: not decided yet |
| How you update | Paste the current round again (Part 0 above). The window lists each file as New, Replace or Recycle before you press Run. Importing the solution "90-161.Z flows" over the older copy is an upgrade: the flows keep their connections (docs/power-automate-provisioning.md section 5) |
| Is the script the right one | Compare the build code in the window title bar with the README value after **Build:**. They must match |
| Lists | A run of T20 skips what exists. It does not change an existing column. How a list change reaches a wing that has the old list: not decided yet |
| App (Power Apps) | How a new app version is installed: not decided yet |

Rule (Rec, not decided): keep every rule that can change in list rows, not in app or flow code, so most updates change data only.

## 6. Open items

1. Test every right in docs/rights-test-plan.md (go.md Task 11) before the setup flow is built.
2. Where the "not decided yet" lines above are settled (Part 0 checks for other wings, the probe flow, list and app updates).
