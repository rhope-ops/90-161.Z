<!-- Plan approved by the PFM on 17 Nov 26 (plan mode); revision 2 and the deeper-version task approved the same day. Self-review; not independently reviewed. -->
# Plan: RADE frame + 90-161.Z PFM window, full UI and function pass (17 Nov 26)

## Status at 17 Nov 26, night (agent)

- Done after this plan was copied here: RADE rule for Start (RADE PR 70, approved text); R28 engine items 3a.1 to 3a.8 (RADE PR 72, two fresh reviews, no MAJOR) and a lint fix (PR 73); releases engine-v7 (619c78b) and engine-v8 (f720098). The saved runner copy is replaced only by a higher engine release (the PFM, 17 Nov 26). Design approved (preview 2), no timed tasks, selectable text (DECISIONS 17 Nov).
- Stopped: the lock move. `bump_lock.py engine-v8` rebuilds every bundle, and round R27 r1 is open on the PFM's computer, so moving the lock now would change R27. With the move, two tests that grep engine text need updating ("Enter starts the run"; "paste bundles naming another engine").
- Blocked: the test "RADE engine is behind" (PFM decision 15 Nov) fails the full lane of every pull request here until the lock moves, so no pull request here can merge until the R27 results are on main and the lock has moved.
- Next session: R27 results, then the lock move to engine-v8 with the test updates, T22 r2 (Phase C), round R28 (Phase D).

## Context

R26 r2 showed the T22 PFM window preview is "close, with small changes" but needs "a deep pass"; full screen is not proven, and the RADE runner still has 4 "Kick" layout defects on hand cards. The PFM chose a start point on 17 Nov 26: the layout of board "Before · Hybrid (busy)" with the colors of board "Streamlined 1 · Air Force colors" (canvas "90-161.Z App Concepts"). Open decisions of 16 Nov (Start button, desktop icon, update notice) also wait for this plan. This plan changes nothing until the PFM approves it.

## 1. Outcome and "done"

Outcome: one RADE frame (checks, update notice, Start, desktop icon) that opens a full-screen 90-161.Z PFM window in the Hybrid layout with Air Force colors, which covers every PFM step of the 13 steps with fake data, and has no layout defect at 100 % and 150 %.

Done = all of these, each with outside proof:
1. Preview: the PFM approves a design canvas of every PFM card (Hybrid layout, AF colors) at 1920x1200 (100 %) and 1280x800 logical (150 %), and at the narrow 956 px client. Proof: the PFM's answer, recorded in docs/DECISIONS.md.
2. Cloud checks: `scripts/check.sh` last line `CHECK PASS`; `scripts/lint.sh` `findings=0`; `tests/check_palette.py` pass on every color pair used; `tests/check_guide_text.py` pass; RADE's own Windows test job draws each card at 100 % with 0 layout defects.
3. Gov-device round: RADE layout self-check reports 0 defects in all cards at 150 % (today: 4 Kick defects); the window reports `WindowState=Maximized` and its client size at Shown and again at close; a SCALE line shows font scale = control scale; the PFM opens every card and rates the look.
4. Fresh review (reviewer subagent, no lower tier than the author) of each code diff; no MAJOR finding open.

## 2. Findings by screen, ranked

Sources: scripts/gov/90161Z-T22-pfm-window-r1.ps1 (T22), rhope-ops/RADE engine/rade_build.py at e0ad467 (RADE), R26 results, design boards. Line numbers are in those files.

### A. Both windows (root causes)
1. **HIGH: text does not scale at 150 %.** Forms use `AutoScaleMode=Dpi` at 96; the device reports system dpi 96 but form scale 144 (R25 SCALE line), so boxes grow 1.5x and text stays at 100 % (RADE 1552; T22 305). Same cause explains the T22 close size 638 x 720 = 956 x 1081 / 1.5. Confidence: medium (cause fits all numbers; not proven on the device).
2. **HIGH: full screen not set or not kept.** RADE never sets `WindowState` (caps to 95 % of the work area, 2539). T22 sets Maximized once (309), keeps a Sizable border, no MinimumSize, and measures only after close (400). Confidence: high.
3. **MED: no shared UI code.** T22 copies RADE colors and a reduced self-check by hand; drift is already visible (green, ink, gray differ from docs/palette.json). Confidence: high.
4. **MED: contrast of non-text parts.** 6 px yellow light on white 1.42:1, bar track 1.23:1, disabled edge 1.23:1; state shown by color only. Fails the 3:1 bar for UI parts (screen-map "Rules for every screen"). Confidence: high.
5. **MED: keyboard.** No `CancelButton`, no `TabIndex`, mnemonics off; Esc on the T22 home card closes the window; Busy state not visible. Confidence: high.

### B. RADE frame
1. **HIGH: Kick defect on hand cards.** The "Copy file path" link button keeps `AutoSizeMode=GrowOnly` (1611) while other buttons use GrowAndShrink; its text is centered in a 1.5x-wide box, so the ink starts about 38 px right of the card edge; a negative margin is clamped to 0 (1798–1808). Second fault: the `$ui.Ink` cache key uses the width before resize (1788/1792). Confidence: medium (fits R25 and R26, same 38 px at two window sizes).
2. **HIGH: Start button conflicts with a RADE decision.** RADE DECISIONS 2026-11-14 "RADE installs apps only; it does not start them" vs 90-161.Z 2026-11-16 "RADE opens first, then Start opens the app". A new decision must replace the old row. Also 90-161.Z 2026-11-15 "90-161.Z stays a Power Apps canvas app ... no desktop window replaces it" is not marked replaced by the 16 Nov front-end split.
3. **HIGH: update notice points to the app page, not the RADE page** (`rade-release.json`, 772–788) and shows in deploy mode only; 16 Nov decision says it points to the RADE page.
4. **MED: no desktop icon** anywhere in the engine.
5. **MED: missing states:** no cancel while checking or running, no error card if boot checks throw, no card for zero applications, Maintenance buttons other than Install have no function.
6. **LOW: text.** "Redacted Application Deployment Engine" on screen, "round", "build", "fallback", "paste the block", "You look and answer, read-only", "RADE waits for you", DD-MM-YY dates, three labels for the same Record ("Steps and files", "What it made", "Record (F2)"), "Copy the log" and "Copy summary" do the same thing.

### C. 90-161.Z window (T22 r1)
1. **HIGH: content does not match the 13 steps.** Step 8 card says "6 offices in 2 waves" (3 waves in step 10); step 11 says certifier and approver get the copy at once (the process is PFM final copy, then certifier, then approver); "Change or skip" changes a review date (step 13 = change who gets a step or skip anyone, with a logged reason); no PFM review, format or privacy monitor record on step 8.
2. **HIGH: PFM steps with no card:** 1 (reviews due), 8 (review and format, privacy record), 9–10 (answers, CRM, wave status, silent endorser), 11 (build final copy, signature status), 12 (published alert), 13 (reassign or skip with reason; search, read, summarize). Steps 2–7 and the endorser, AO and CSS parts of 9–12 are SharePoint list forms (front-end split, 16 Nov) and stay out of this window.
3. **HIGH: the self-check proves little.** It runs once at Shown, never after a resize or snap; its horizontal test cannot fail by construction (card right edge at most 0.88 x width); it skips the top bar (cut at narrow widths), clipped button text and the window state; cards flash while it measures.
4. **MED: resize rebuilds the card** on every Resize event: flicker, focus jumps, "opened" count wrong.
5. **MED: missing states:** nothing needs you, loading, failed, no permission, overdue, confirm before Start or Send, reason prompt for step 13.
6. **LOW: text:** digits in sentences, spaced hyphen, "Not yet", "Change or skip", "FAKE AO (fake)", "PDF made by a flow", "preview r1" on screen; dead common code (55–86).

### D. The chosen start point (design boards)
1. **The Hybrid board is from before the split and the 13 steps.** Its rail lists every role (Search, Start a Request, Suggest a Change, Help, role chips AO/Coordinator); its stepper has the old 11 stages; "Open the CRM" is an AO action. It needs a PFM-only cut: Your work, Work queue, Publications, Reviews due, Settings.
2. **Color mapping (Streamlined-AF onto Hybrid):** pine rail #1F4D3A -> navy #0B2545; brass/orange accents #A8461F -> AF yellow #FFD520 as a fill under navy text only (never thin lines on white), primary button -> AF blue #00539F; ivory #F7F4EE -> #F3F5F8; status chips -> docs/palette.json red/amber/green with their tints (all pairs >= 4.5:1 text, 3:1 parts). Tokens come from docs/palette.json (one place); navy #0B2545 is added there.
3. **Fit:** the board is 1366x768. At 1920x1200 and 150 % the logical area is 1280x800: rail 220 + main + side panel 380 leaves about 620 px for the main column (fits). At 956 px client (half screen at 150 %, 637 logical) the side panel must move under the main column and the rail must narrow.

## 3. Proposed changes

### 3a. rhope-ops/RADE (engine; RADE's own rules, own session, own PR and review)
1. DPI: make the process DPI-aware at start (one Add-Type P/Invoke, no module, no admin) or switch to `AutoScaleMode=Font`; whichever the Windows job and one device round prove. Print font scale and control scale in the SCALE line.
2. Kick fix: `GrowAndShrink` and left-drawn text on link buttons; fix the `$ui.Ink` cache key; add link ink, width and margin to the LAYOUT line.
3. Window: open maximized, keep a MinimumSize, re-run the self-check after resize and at close, record state and size at Shown and close.
4. Start button and desktop icon (after the decision in question 1): RADE checks -> update notice -> "Start 90-161.Z" opens the installed app script from OneDrive\RADE\90-161.Z in its own process; desktop icon = a .lnk made with WScript.Shell in the user's own Desktop folder (no admin, local only, no network) that opens RADE. Update notice links https://rhope-ops.github.io/RADE.
5. Shared UI file: move theme tokens, card builder and self-check into one engine file the app bundle gets through scripts/rade.lock.json, so the app window and RADE cannot drift.
6. States and text: cancel while checking and running, boot error card, zero-applications card, visible Busy; one name for the Record; plain wording list above; dates as 17 Nov 26.
7. Non-text contrast: status light gets a 1 px navy line or a label word; bar track and disabled edge to >= 3:1.

### 3b. 90-161.Z (this repo)
1. docs/palette.json: add navy, chip tints; tests/check_palette.py covers every pair the window uses.
2. New window script `scripts/gov/90161Z-T22-pfm-window-r2.ps1` (replaces r1) on the shared UI file: Hybrid layout, AF colors, PFM-only rail, "Do this next" card, "After that" list, side "Action status" panel with waves and endorser answers, 13-step stepper (PFM steps), all with FAKE data.
3. Cards: Your work (with empty state); Work queue; Step 1 Reviews due; Step 8 Review and format + privacy record + Start endorsement (confirm); Steps 9–10 Wave status, answers, silent endorser; Step 11 Build final copy, then certifier, then approver status; Step 12 Published alert; Step 13 Change or skip (reason required, logged) and Publication read/details/summary; Settings; failed, no-permission and loading states.
4. tests/run.sh: extend the T22 test (FAKE data, every button target exists, one primary button per card, ASCII text, numbers as words in sentences).
5. Docs: rewrite docs/app/screen-map.md section 0 for the split (PFM window cards vs list forms); docs/ARCHITECTURE.md front-end part; DECISIONS rows; NEXT_PROMPT.
6. scripts/paste_bundles.json: T22 r2 step + question cards for the PFM's look rating; bump the RADE lock after the engine release (PFM request, `scripts/bump_lock.py`).

## 4. Preview step (before any build)
- A design canvas for the PFM alone (new private artifact, copy of the two boards as start): every PFM card in the Hybrid layout with AF colors, at 1366x768, 1280x800 (150 % of 1920x1200) and 637x720 logical (half screen at 150 %); plus the RADE frame cards that change (checks, update notice, Start, hand card with the fixed link).
- Measured before it is shown: ui-verify measure (contrast, 24 px targets, no horizontal scroll) on each board; fake data only; PII scan of the canvas.
- Build starts only after the PFM approves the canvas (recorded in DECISIONS).

## 5. Rounds that carry it
- R27 stays as approved (T4 retry, [TEST] removal, .msapp test). No window work in it.
- R28 (RADE maintenance round in docs/phases.md): engine release with 3a.1–3a.7, lock bump, T22 r2 window, layout self-check at 150 %, Start and desktop icon test, PFM look questions.
- R29: fixes from R28 only, if needed. App data wiring (read the lists by PnP) stays in the app rounds R30–R33.

## 6. Steps, checks, agents
| Step | Who / model | Why that model | Check |
|---|---|---|---|
| 1 Preview canvas | me (session model) | design judgment | ui-verify measure; PFM approval |
| 2 RADE engine change (own RADE session) | worker, standard tier | clear brief from this plan | RADE Windows job 0 defects, RADE check lanes |
| 3 Review of 2 | reviewer, strong tier | engine code, no lower than author | no MAJOR |
| 4 Palette + T22 r2 + tests + docs | worker, standard tier | clear brief, bounded files | check.sh, lint.sh, check_palette, check_guide_text |
| 5 Review of 4 | reviewer, strong tier | fresh context | no MAJOR |
| 6 Round R28 build (lock bump, bundle) | worker, standard tier (round skill) | routine | full lane, PII guard, fresh reader of guide text |
| 7 R28 results | me | judgment | results file docs/reviews/ |

Usage estimate (heavy work: 6 agents in total, more than 1 hour): 2 workers + 2 reviewers + 1 round worker + 1 fresh-reader agent; agent run time about 6 to 10 hours, plus the PFM's preview review and the device round; wall time 2 to 3 days. Confidence: low (engine DPI fix may need a second device round).

## 7. Assumptions
- The window stays a preview with FAKE data until the app rounds (R30–R33). Source: docs/phases.md order. Confidence: medium.
- DPI cause is font vs control scale mismatch. Source: R25 SCALE line, R26 sizes. Confidence: medium; R28 proves or disproves it.
- A .lnk on the user's own Desktop needs no admin rights and is allowed on the gov device. Source: Windows behaviour; not tested. Confidence: medium; R28 tests it with a fallback (Start from the RADE page bookmark).
- docs/palette.json is the color source; Streamlined-AF hex values that differ (#B3261E, #5A6573) yield to it. Confidence: high.

## 00. Next task (deeper version, 17 Nov 26; runs only if the PFM approves this plan)

Deeper pass on the 90-161.Z PFM window and the RADE frame (canvas https://claude.ai/artifact/12VVeBiXXD4AQjAWwgCU5H). Same deliverable: an approved canvas, then the R28 build plan.
1. One question dialog to the PFM, counts and patterns only (no real data): open actions in a busy month, first look each morning, slowest decisions, error points today, both monitors (resolution, scale). Rank top tasks (frequency x importance).
2. Measurable usability targets (e.g. see what needs me < 5 s; start endorsement <= 3 actions; all tasks by keyboard), each mapped to a DAFMAN 90-161 paragraph and to real list fields (schemas/lists).
3. Redraw the canvas for an expert daily user: density study (5, 25, 60 actions; comfortable and compact), 120-character titles, many late items, all states, documents on the second monitor; clickable links between boards. Step bar = 12 dots + "Change or Skip" button; no half-screen layout; smallest area 1280 x 720 logical.
4. Fidelity spike: RADE's Windows test job draws Your Work and the step 8 card in real WinForms (PS 5.1); pictures beside the HTML boards; list each difference.
5. Measure first: ui-verify, tests/check_palette.py, keyboard-only path per task, screen-reader name on every spike control (script), Windows high contrast on the spike.
6. 5 timed scenario tasks for the PFM on the prototype; a failed target changes the design before approval.
7. Update the R28 plan: LAYOUT 0, SCALE line, maximized on the remembered monitor, screenshots compared with the approved boards, Narrator and keyboard-only checks.
Agents: 1 worker (standard tier) for the WinForms spike in rhope-ops/RADE's test job; the rest by me. Time: about 3 to 5 hours of agent work plus the PFM's dialog and test (confidence: low).

## 0. Revision 2 (17 Nov 26, after the PFM's review of the preview canvas)

PFM answers on the canvas:
1. Step bar: A, 12 dots plus a "Change or Skip" (step 13) button on each action.
2. Canvas not approved: the half-screen board (637 x 720) is "comically narrow". Most users have 2 monitors; the window may take a whole screen.

Why the narrow board existed: the T22 r1 close size 638 x 720 was read as a half-screen snap. It is more likely the 150 % scaling fault (finding A.1: sizes reported in 100 % units). An inference became a design target. Corrected below.

Changes to this plan:
- Answer 3 of section 8 is replaced: the window opens maximized on one whole monitor; no half-screen layout and no "side panel under the list" rule. Smallest supported area = 1280 x 720 logical (a 1920 x 1080 screen at 150 %); below that the main column scrolls, nothing reflows.
- The window opens on the monitor where it was last closed (its own small settings file in OneDrive\RADE\90-161.Z), else on the monitor that shows RADE. Fallback: the primary monitor.
- Canvas: remove board 1c (half screen); add board 1c "Your work at 1280 x 720 (1920 x 1080 at 150 %)"; step 13 stays a button (answer 1). Re-measure (contrast, 24 px targets, no cut-off content at each board's size) and publish; then ask the PFM again.
- Repo (one docs pull request): DECISIONS row of 17 Nov "Below about 1100 logical px the side panel moves under the main column" is replaced by "full screen on one monitor; smallest area 1280 x 720 logical"; step-bar answer recorded; the plan file in docs/reviews updated the same way.
- R28 checks add: window opens maximized on the remembered monitor; client size at Shown equals that monitor's work area; the layout check runs at 1280 x 720 logical too.

## 8. PFM answers (17 Nov 26, question dialog; to record in docs/DECISIONS.md on approval)
1. Start and icon: one desktop icon opens RADE; RADE runs checks and the update notice; Start opens the 90-161.Z window. A new RADE decision replaces RADE 2026-11-14 "RADE installs apps only"; the 90-161.Z row of 2026-11-15 (Power Apps, no desktop window) is marked replaced by the 16 Nov split.
2. Hybrid cut: PFM-only items, 13-step bar; other people's tasks stay in SharePoint list forms.
3. ~~Narrow window: adapt the layout~~ Replaced in revision 2 (section 0): full screen on one monitor, smallest area 1280 x 720 logical.
4. Timing: preview canvas first; after approval, engine fixes and window r2 ship in R28; R27 unchanged.

## 9. Verification end to end
Cloud: check.sh `CHECK PASS`, lint `findings=0`, RADE Windows job card pictures at 100 % with 0 defects. Device (R28): LAYOUT 0 defects at 150 %, SCALE font = control, WindowState Maximized at Shown and close, each card opened, PFM rating; results in docs/reviews/<date>-r28-results.md.
