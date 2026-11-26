# The PFM's 4 questions after R43: shortcut and icon, Kanon names, scale, test-site clean-up

Written 2026-11-25 20:40 Central by the questions session. Sources: this repository at 58327ce (main), the R43 results file ([docs/reviews/2026-11-25-r43-results.md](2026-11-25-r43-results.md), on branch `claude/r43-results` until PR 255 merges), and read-only public clones of rhope-ops/RADE at 98fd8f1 (engine-v41), rhope-ops/33-332.Z at main and rhope-ops/archimedes_lever at main. The session tool `add_repo` was refused, so the clones are public `git clone` copies in the session scratchpad. Nothing was written to a site, and no gov data was read.

Status of each answer: a fact (with its file and line) or an assumption (with a confidence label). Each fix is a recommendation (**REC**) until the PFM decides.

## 1. Shortcut and icon

**What the PFM expects:** installing 90-161.Z 0.1.0 makes a shortcut with the app's icon, named "90-161.Z - Kanon - 0.1.0".

**What was decided (facts):**

- RADE DECISIONS 2026-11-21, "Intro screens, Fulcrum palette, shortcut icon", part (4): "The shortcut belongs to the installed app: its name and icon ... one shortcut and runner copy for each app. The build waits for a preview." Scope: "the first free engine release (engine-v35 or later) and round R42". **Confidence: high.**
- The plan: RADE [docs/reviews/2026-11-21-plan-intro-fulcrum.md](https://github.com/rhope-ops/RADE/blob/main/docs/reviews/2026-11-21-plan-intro-fulcrum.md) step 7: the shortcut name is "the app's name"; the icon is `<key>.ico` (16, 32, 48, 256 px) made from `application.logo`; each app gets its own runner copy; the old `RADE.lnk` goes to the Recycle Bin. Test T6 proves it on a work computer.
- The plan names no version in the shortcut name. "90-161.Z - Kanon - 0.1.0" is a new request. **Confidence: high.**
- 90-161.Z DECISIONS 2026-11-17 (line 261): "one desktop icon opens RADE". The RADE row of 2026-11-21 replaces that row "when built".

**What the install makes today (facts, engine-v41):**

- `Add-DesktopIcon` in RADE [engine/ps/05-installed.ps1:301-322](https://github.com/rhope-ops/RADE/blob/main/engine/ps/05-installed.ps1#L301-L322) makes one shortcut `RADE.lnk`, description "Open RADE", target `powershell.exe` with the shared `rade-runner.ps1`. It sets no `IconLocation`, so Windows shows the PowerShell icon. **Confidence: high** (code); the icon shown on the device is an inference (medium).
- The 90-161.Z manifest `application` block (scripts/paste_bundles.json) has no `logo` and no `intro` field. Plan step 9 says the app adds them after the engine release. The app logo exists as `assets/logo/90161Z-logo-fulcrum.svg` (DECISIONS 2026-11-20 line 93: "each app's Fulcrum logo in every place").
- Not built: no RADE commit after the plan (8ee6329, 1c1bb4c) touches the shortcut code, and RADE has no branch for it. RADE docs/NEXT_PROMPT.md still lists "Plan: intro, Fulcrum, v35+, R42" as open. The plan waits for its preview (lane C), and engine-v35 to v41 went to the R42 and R43 items. **Confidence: high.**
- go.md and 4 runner steps of R43 say: double-click the shortcut "RADE" (scripts/paste_bundles.json lines 411, 483, 768, 812). A rename breaks these steps; the round build must change them in the same round.

**REC 1 (A):** build plan step 7 now, apart from the intro and the palette (those keep their preview): one shortcut per app, named `<display name> - <version>`, with the app's Fulcrum icon, in the next free engine release; R44 or R45 tests T6. 90-161.Z adds `application.logo` (from the Fulcrum SVG) and the display name (question 2).
B: wait for the whole intro plan (shortcut, intro cards and palette in one release, one preview).

## 2. Kanon in the window titles

**Search of docs/DECISIONS.md for "Kanon" (fact):** one row, line 49 (2026-11-21): "Product name: Kanon ... README title Kanon; the repo stays 90-161.Z. Scope: README, card." Kanon is not in any window, script or bundle today (grep of the repository: README.md only). So a title with Kanon widens that row's scope. **Confidence: high.**

**Where the titles are set today (facts):**

| Window | Code | Title today |
|---|---|---|
| RADE runner (each RADE window) | RADE [engine/ps/window/01-setup.ps1:52](https://github.com/rhope-ops/RADE/blob/main/engine/ps/window/01-setup.ps1#L52) | `Redacted Application Deployment Engine · build <buildId>` |
| RADE window, word spot | RADE engine/ps/window/02-fixed-parts.ps1:35 | `RADE`, then the chosen app's name (`application.name`, "90-161.Z") |
| RADE Maintenance list | the install record | row `90-161.Z 0.1.0` |
| 90-161.Z window (T22 r16) | scripts/gov/90161Z-T22-pfm-window-r16.ps1:282 | `90-161.Z - Publications and Forms Management - preview r16 (FAKE data)` or `(test site data)` |
| 90-161.Z window, rail head | scripts/gov/90161Z-T22-window-r16.ps1:92 and :106 | `90-161.Z`, under it `Publications and Forms` |
| Desktop shortcut | question 1 | `RADE` |

- RADE DECISIONS 2026-11-19 (line 52, "Window"): the title bar reads "Redacted Application Deployment Engine · build <buildId>", "the build value only, no round". The PFM's new request ("the Round value at the very end") replaces that row. **Confidence: high.**
- The values exist at run time: `$engineRelease = 41` and `$buildId` are in every bundle (RADE engine/rade_build.py:355); the round is in the bundle (`$round`; engine/ps/08-saved-checks.ps1:116 writes "round", "build" and "engine release" in one line).
- `application.name` ("90-161.Z") is also the install key, the RADE app folder, the record key `90-161.Z/90-161.Z` (T22-maint-r16.ps1:168) and the Uninstall confirm text ("Type 90-161.Z to confirm"). A change of that name moves the install record. So the title needs a separate display field, not a new `application.name`. **Confidence: high** (code).

**Proposed titles (REC 2):**

| Window | Proposed title |
|---|---|
| RADE runner of a test round | `RADE - engine-v41 - R44` |
| RADE runner of an install (no round) | `RADE - engine-v41` |
| 90-161.Z window of a test round | `90-161.Z - Kanon - 0.1.0 - R44` (fake data adds ` (FAKE data)`) |
| Installed 90-161.Z window | `90-161.Z - Kanon - 0.1.0` |
| Desktop shortcut | `90-161.Z - Kanon - 0.1.0` |
| RADE word spot and Maintenance row | `Kanon` with `90-161.Z 0.1.0` under it |

- A new optional manifest field `application.title` ("90-161.Z - Kanon") gives every title; `application.name` stays "90-161.Z". The round and the version come from the bundle.
- The rail head reads `Kanon`, and `90-161.Z` goes on the small line under it.
- `<buildId>` leaves the title bar and stays in the Record (F2), the log and the report (the hash is already there: RADE DECISIONS 2026-11-19). **Confidence: medium** (the PFM may want the build too).
- The go.md and runner steps that name a window by its title (R42 T3: "90-161.Z R42" and "90-161.Z 0.1.0") change in the same round (Project rule "Screen names").

## 3. Resolution and scale

**R43 evidence (results file, "SCALE of each RADE window"):** first window (ISE): `fontScale=1.5 ctlScale=1.5`; second window (the shortcut, ConsoleHost): `dpiX=144 fontScale=1 ctlScale=1.5`. Both windows scale the controls by 1.5. `fontScale` is a correction factor, not the text size: RADE makes fonts 1.5 times bigger only when Windows draws text at 96 dpi in that process ([engine/rade_ui.ps1:62-67](https://github.com/rhope-ops/RADE/blob/main/engine/rade_ui.ps1#L62-L67)). So in ISE Windows draws text at 96 dpi and RADE scales it up; in the console Windows draws it at 144 dpi. The results file holds only parts of the 2 lines (no `thread=`, `realDpi=` or `client=` of the ISE line), so the cause of the look difference is an inference. **Confidence: medium.**

**What the plans said (facts):**

- The master plan is the kit's tool retirement plan ([archimedes_lever docs/reviews/2026-11-23-tool-retirement-plan.md](https://github.com/rhope-ops/archimedes_lever/blob/main/docs/reviews/2026-11-23-tool-retirement-plan.md); 90-161.Z DECISIONS line 41). Its RADE row P4a (line 295) has "175 % DPI run (2 lines; 125, 150 and 200 % runs exist)" and "window layout: keep (already TableLayoutPanel; 42 lines of ink alignment have no standard equivalent)". Coverage row P2-6a ("TableLayoutPanel or XAML instead of manual pixel math (RADE)") ended as "keep". So the master plan counts 42 lines of ink alignment and keeps them; it counts no DPI or scale tweaks and plans no remediation of them. P4a is done (RADE PRs 179, 180). **Confidence: high** for the plan text; medium that this is the document the PFM means.
- The scale fix that was planned: 90-161.Z DECISIONS 2026-11-21 (line 52): "R42: ISE RADE window uses the shortcut window's smaller scale, with a SCALE line per window". engine-v35 (RADE d64ea35) built only the SCALE line: "The scale itself waits for R43". R42 gave no second SCALE line (Back up did not start). The R43 plan carried only the measurement (T4: "a SCALE line for the second window"). The RADE item "E4" of R43 became a different item (sign-in window watch off, deb3241). The RADE handoff (docs/NEXT_PROMPT.md) does not list the scale fix. So the fix was not dropped by a decision; it fell out of the plan between rounds. **Confidence: high.**

**The scale parts in the code today (count by this session, not from a plan):**

| # | Part | Where | Since |
|---|---|---|---|
| 1 | `SetProcessDPIAware` (native call) | RADE engine/ps/window/01-setup.ps1:17-21 | R28 |
| 2 | Thread awareness "unaware" to "system" (for ISE) | 01-setup.ps1:23-38; set back in engine/ps/10-window.ps1:18 | R34, engine-v25 |
| 3 | `AutoScaleMode = Dpi` at 96 and `$ui.Dpi` from the form | 01-setup.ps1:59; engine/rade_ui.ps1:13 | before R28 |
| 4 | Font correction probe (`FontScale`, `FontK`) | engine/rade_ui.ps1:62-67 | R28 |
| 5 | `$ui.Sc` pixel helper | engine/rade_ui.ps1:14; 78 uses in the engine | before R28 |
| 6 | Sign-in window size (480 x 360 at the window's dpi) | engine/ps/16-site-scripts.ps1:14-97 | engine-v35 |
| 7 | 90-161.Z window: its own `AutoScaleMode = Dpi`, `$ui.Dpi`, `FontK`, `$ui.Sc` (35 uses) and the measure code | scripts/gov/90161Z-T22-*-r16.ps1 | R28 to R43 |

**Confidence: medium** (a count by search; another reader can split them in another way).

**REC 3 (A):** in the next free engine release, run the ISE window in the same way as the shortcut window: from ISE, RADE starts its window in a child `powershell.exe -STA` (the host that the shortcut uses), so both windows get one dpi path; then parts 2 and 4 go if the SCALE lines prove them obsolete. Proof: two equal SCALE lines (`fontScale`, `ctlScale`, `realDpi`, `client`) in one round, and the PFM's look check. The PFM said the look can wait to near the end of testing, so the order is a PFM decision.
B: keep the code, and only stop the font correction in ISE (part 4). It is smaller, but it does not make the ISE window sharp (Windows still stretches an unaware window).
C: wait until near the end of testing; record it as an open RADE item now, so it does not fall out again.

## 4. Test-site clean-up

**What the rounds make and what removes it (facts from the step notes in scripts/paste_bundles.json and the scripts):**

| Item on the test site | Made by | Removed by | State after R43 |
|---|---|---|---|
| List "90161Z Probe", library "90161Z Probe Files", 1 fake workbook | T21 Make the probe list | T21 Remove the test list and library (Recycle Bin); T21 Check the test site is clean | Removed (PASSED 4 of 4) |
| Second person in the Visitors group | T21 Add the second person | T21 Remove (takes the person out) | Not added in R43 |
| Fake publication, endorsement and log rows | T26 Make | T26 Remove the fake rows (Recycle Bin) | Nothing to remove (PASSED 2 of 2) |
| The 12 lists "PFM ..." with columns, views and start rows | T20 Make the 12 lists (the install) | T27 Remove the 12 lists (Uninstall) | **Still there, on purpose: 12 of 12** (R43 Uninstall stopped before it removed anything) |
| Rows in "PFM Process Steps" (steps 1 and 2) | T20 start rows | with the 12 lists | Still there |
| Group "PFM Office" and its permission level | T20 | T27 Remove the group and level, only if RADE recorded that the install made them | Still there (`g2-access INFO`) |
| Install record on the site | RADE deploy | not removed by Uninstall (PFM 2A, 2026-11-25) | Stays by design |
| Items in the site Recycle Bin (each Remove step) | every clean step | SharePoint, after 93 days | Stay; the Restore tests need rows there |

Can also be there from older rounds (assumption, **confidence: low**; the PFM can see the site, this session cannot):

- Library "90-161.Z" with the folders "Seals" and "Seals/Prepared" and result files (T16 site setup r12, R12 to R29). No step removes it.
- Item-level permissions on "PFM Publications" and "PFM Endorsements", and the site time zone (T16). These are settings, not leftovers.
- The site logo and thumbnail, set by hand in R29a.
- The flows solution, imported by hand (T24, R29 to R36), and its 8 flows. T27 Remove the flows by hand is a hand card in Uninstall.
- Rows with "(delete me)" in their title (T24 r7). T24 part 4 (Clean) moves them to the Recycle Bin if it ran.

**Do you need to clean it by hand? No (REC 4).** A scripted round step is the safer path, and every delete is a data write that the PFM approves first.

- **REC 4 (A):** R44 gets 2 steps. Step 1, "Show what is on the test site", reads only and lists the fixed titles above (no member names, no row content: counts only; Project rule "No reconnaissance"). Step 2 runs the existing T27 Uninstall again after the Back up works (question 5). Older items that no step removes (the library "90-161.Z", the flows) get a new clean step only after step 1 shows them, with the PFM's approval of the exact list. Do not empty the Recycle Bin before the Restore tests.
- B: the PFM removes the items by hand in the browser (more clicks, and no record in the results).
- C: leave the 12 lists; R44 tests Restore and the endorser answer on them first, and Uninstall at the end of R44.

## 5. Uninstall stopped at "Uninstall is saving a backup." and how 33-332.Z reads SharePoint

**What RADE does (facts, engine-v41):**

- The card "Uninstall is saving a backup." shows before `Invoke-Uninstall` starts ([engine/ps/window/11-tools.ps1:231](https://github.com/rhope-ops/RADE/blob/main/engine/ps/window/11-tools.ps1#L231)). The site gate (`Test-UninstallSite`, `Test-RestoreSite`) reads only local files, so the sign-in windows come from `Invoke-Backup` (engine/ps/13-maintenance.ps1:187).
- `Invoke-Backup` runs a child `powershell.exe -NoProfile -File` with no console window (`CreateNoWindow`), engine/ps/07-checks.ps1:153-187. The child imports PnP.PowerShell 1.12.0, runs `Connect-PnPOnline -UseWebLogin`, then `Get-PnPListItem -PageSize 500` for each of the 12 lists. The whole child has a time limit of 1800 s (`$toolReadSeconds`); one SharePoint call has none. The window waits in a loop with `DoEvents` every 30 ms.
- Each child process signs in again: one sign-in window for each run. 2 runs of Uninstall in R43 fit 2 sign-in windows. **Confidence: medium.**
- Changes to the Back up child since the last Back up that passed (R41, engine-v32; diff of engine-v32 and engine-v41): (1) the sign-in window size block (engine-v35, E3), which, for 2 minutes, sizes and centers each new visible window of the child process to about 480 x 360, and the Back up script never calls `Stop-SignInSize`; (2) the child starts with no `-ExecutionPolicy Bypass` (engine-v36, DEC 3). Back up alone has not run since engine-v32.

**What 33-332.Z (Ion) does (facts, [src/SiteTarget.psm1](https://github.com/rhope-ops/33-332.Z/blob/main/src/SiteTarget.psm1)):**

| Point | 33-332.Z | RADE Back up |
|---|---|---|
| Sign-in | `Connect-PnPOnline -UseWebLogin` in the person's own PowerShell process (line 297); one sign-in for all sites on one host (33-332.Z DECISIONS 2026-11-24) | The same call, in a new hidden child process each time |
| Time limit of one call | `RequestTimeout` = 300,000 ms on the PnP context after the sign-in (lines 61, 235-244), added after "a scan hung after 50 minutes" (2026-11-23) | none; only 1800 s for the whole child |
| Site check | `Assert-ConnectedSite`: the web read must be the given site (lines 246-) | none |
| Sign-in window | no resize; the text says "If you do not see the window, press Alt+Tab" | resized to 480 x 360 for 2 minutes, each new window; no Alt+Tab text |
| Second window | probe 3 (33-332.Z docs/reviews/2026-11-24-device-probe-3.md:119): "Window 1 asked 'continue running scripts' (the IE engine of `-UseWebLogin`; answer Yes)" | not handled |
| Reads | `Get-PnPListItem -PageSize 500` (the same) | the same |

**Possible causes, not proven (confidence: low for each):**

1. A second window of the sign-in (for example the "continue running scripts" question of probe 3) opened behind the RADE window or was made small by the size block, and the sign-in waited for an answer.
2. One SharePoint call stalled with no time limit, as in the 33-332.Z hang of 2026-11-23.
3. The "not responding" window was the sign-in window, not RADE.

**REC 5 (A), for R44 (a finding to the R44 session, not yet a PFM decision):** run Back up alone in the second window before any Uninstall, once with the sign-in watch on and once with it off (`RADE_SIGNIN_WATCH=0`, as the R43 rights check pair). The engine adds, from 33-332.Z: the 300 s `RequestTimeout`, the site check, `Stop-SignInSize` right after the sign-in, the "press Alt+Tab" line on the card, and a `LIST <n>` progress line on the card for each list. Then Uninstall runs again.

## Questions for the PFM (one round)

1. Shortcut: build the app shortcut now (REC 1 A), named "90-161.Z - Kanon - 0.1.0"?
2. Titles: the titles in the REC 2 table, with a new field for the display name and no build in the title bar?
3. Scale: one window host for ISE and the shortcut (REC 3 A) in the next engine release, or wait to near the end of testing (C)?
4. Test site: a read-only list step first, then scripted clean steps you approve (REC 4 A)?

## The PFM's answers (question dialog, 2026-11-25 20:44 Central)

1. Shortcut: REC 1 A, build it now, named "90-161.Z - Kanon - 0.1.0".
2. Titles: REC 2, the titles in the table.
3. Scale: REC 3 A, one window host in the next engine release.
4. Test site: REC 4 A, a read-only list step first, then scripted clean steps on a list the PFM approves.

Recorded in docs/DECISIONS.md (4 rows of 2026-11-25) and sent to the R44 session.
