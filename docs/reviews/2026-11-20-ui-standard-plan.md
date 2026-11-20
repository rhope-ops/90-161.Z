<!-- Approved by the PFM on 2026-11-20 (America/Chicago), plan mode. Updated 2026-11-20 evening with the PFM's answers (font, Feedback, R37 scope). Status: Step 0 preview shown (canvas https://claude.ai/artifact/RTKkvTQPQmGq954EPwGmuo); R37 built overnight 20-21 Nov 26. -->
# Cross-app UI standard, RADE contrast, button system, screen walk, test retirement

Plan date: 2026-11-20 (America/Chicago). Deploys in the round after R37 (R38). R37 is not touched.

## Context

The PFM asked (20 Nov 26): RADE must support Windows contrast themes (90-161.Z's T22 window does, RADE does not); buttons must stop varying in width across screens; a total screen walk of both apps and a cross-app UI standard, because more apps are coming (ICF/SEC next); goal: cohesive navigation at any window size, streamlined, minimalist, informative without being busy; tests that already passed must leave the rounds. Deeper version approved with future-app adoption.

**DEC (the PFM, 20 Nov 26):** (1) buttons: fixed width set; (2) primary button last, at the right end of the action row; (3) a step leaves the rounds after 1 pass with unchanged content; (4) the standard lives in RADE.

## What the code shows (evidence; read-only exploration)

- **RADE has no contrast support:** no SystemColors or HighContrast anywhere; palette is hard-coded hex in `rade/engine/rade_ui.ps1:18-21`. Backlog item 24 "high contrast, approved, not started" (`rade/docs/NEXT_PROMPT.md:5`).
- **Why button widths vary:** `$ui.Btn` uses AutoSize GrowAndShrink with only a minimum (132×40 action, 110×30 compact; `rade_ui.ps1:48,165-167`), so every label gives a new width. In T22 the minimums are not passed through `$ui.Sc` (raw pixels at every scale: a bug). List-row buttons are 30 high next to 40-high card buttons. T09/T11 use plain WinForms buttons (80 to 140 px), no shared code.
- **Navigation is not cohesive:** RADE "Back" is a link, an action button and a compact "Back (Esc)"; "Record" is a link and a button; primary is not always first; side insets 32/28; field widths 420/240/600. T22 has a rail (5 items, Ctrl+1..5), crumbs, Esc = Up; RADE has no rail.
- **Web pages differ:** RADE `index.html` has no prefers-contrast/forced-colors and different button padding, weight and text colour; 90-161.Z `index.html` has both (local branch).
- **Tests repeat (PFM is right):** RADE's `step_default()` (`rade_build.py:63-77`) can leave a passed step unticked by file hash, but 90-161.Z never sets it; revision bumps would defeat a raw hash anyway. R36 repeats about 27 owner-minutes of hand steps that passed in R35 with unchanged content (T22 window + look 17, Power Automate connections 3, form look 3, list button 4), plus about 10 for the second-person edit. No file records which steps are verified.

## Plan

### Step 0. Preview for approval (lane C: a UI change needs a preview first)
A Design canvas artifact: 6 key screens (RADE Ready, Your turn, Fail, Record; T22 list card and step card) before and after, at 100 % and 200 %, light, dark and Windows contrast (Night sky, Desert), plus the standard's button set and the navigation frame at 3 window sizes. Fake data only. The PFM approves before any code.

### Step 1. RADE PR: the standard and its one implementation (release engine-v28)
- `docs/ui-standard.md` (new, the one home): rules B1 to B12 below, each with its pass/fail check and where it runs. `docs/window-design.md` keeps only RADE-window specifics, links to the standard, and loses its stale lines (title-bar hash, file locations).
- `engine/ui-tokens.json` (new): colour roles (light hex, dark hex, SystemColors role), sizes, gaps, type, field widths. `rade_build.py` writes `$ui.C`/`$ui.Z` from it; `index.html` CSS variables are generated from it.
- `engine/rade_ui.ps1`: `$ui.Color(role)` (token, or SystemColor when `SystemInformation.HighContrast`), `$ui.Recolor(form)` on `SystemEvents.UserPreferenceChanged` (BeginInvoke to the UI thread, detach on close); `Style`, `Face`, `Own` use only `$ui.Color`; primary text = HighlightText. Generalises T22's `Select-T22Color` / `$wn.Recolor`.
- Font: `engine/fonts/SofiaSans*.ttf` and `SofiaSansCondensed*.ttf` (OFL licence file beside them) loaded by `$ui` through a private font collection (no install, no admin); Segoe UI when the load fails; web pages load the same files.
- `$ui.Btn`: fixed width classes, all sizes through `$ui.Sc`. `$ui.Check` gains the new rules and `-Inventory` (one JSON line per control).
- RADE window (`engine/ps/window/*`): one Back pattern, primary last on the right, insets and field widths from tokens.
- `index.html`: tokens from the JSON, prefers-contrast and forced-colors blocks (pattern from 90-161.Z `index.html`), `.btn` as the window.
- `make-an-app.md`: section "Adopt the UI standard"; `apps.json` gets `"ui": "v1"` per app, checked by its test.
- `rade_hash.py --content`: content hash that strips only revision tokens and header lines (for E below).
- `.github/workflows/window.yml`: add 200 % and a contrast-theme pass, upload inventory and screenshots. A guard file: the PFM's approval of this plan is the request.

### Standard v1 (rules and checks)
| # | Rule | Check (where) |
|---|---|---|
| B1 | Buttons have fixed widths: action 160×40, wide 240×40 (long labels only), compact 96×30, link = text × 28 (100 % values). No AutoSize. | Self-check on Windows runner: width equals class; engine test: no AutoSize on buttons |
| B2 | Every size goes through `$ui.Sc`. | Self-check at 200 %: measured = 2 × token ±1 |
| B3 | Targets at least 24×24 (WCAG 2.5.8). | Self-check |
| B4 | One Back: compact "Back (Esc)" at the left of the action row; Esc = Back/Up everywhere; Record (F2) and Help (F1) are links only. | Self-check flags a second Back/Record control |
| B5 | One primary per card, last at the right end of the action row; Enter clicks it; danger never next to primary. | Self-check: one primary, rightmost |
| B6 | Gaps 4/8/12/16/24 only; one side inset token (24). | Self-check |
| B7 | Font: Sofia Sans Condensed titles, Sofia Sans text (DEC 20 Nov 26), Segoe UI fallback; 4 type styles; field widths S 240, M 420, L 600. | Engine test: no font or width outside `$ui`; Windows job: Sofia Sans loaded, fallback used when the file is missing |
| B8 | One meaning per colour role; text 4.5:1 (WCAG 1.4.3), non-text 3:1 (1.4.11) in light and dark. | Python ratio check on `ui-tokens.json` (Linux CI) |
| B9 | Contrast themes: every role maps to a SystemColors pair (Window/WindowText, Highlight/HighlightText, ButtonFace/ButtonText, GrayText, HotTrack for focus). | Windows job with a contrast theme: control colours equal the mapped pairs |
| B10 | Navigation frame at any size: status light, logo, (rail when the app has one; icons below 900 px), crumbs, card, sticky action row, links. Body scrolls, action row stays. No sideways scroll at 640×480 at 200 % (1.4.10). | Self-check at 7 sizes × 4 scales |
| B11 | Not busy: at most 1 primary + 3 other buttons per card; one status place (light + one line); no tooltips; text limits per field. | Self-check button count; existing text-limit test |
| B12 | Web pages use the generated CSS variables, prefers-contrast and forced-colors; Sofia Sans with Segoe UI fallback. | axe-core CLI + token-diff check in CI |
| B13 | Every card has "Feedback" (a link or compact button, same place on every card): a comment box; on save it writes the comment and a PNG snapshot of the app window into the results folder. Fake data only in tests. | Self-check: Feedback present on every card; Windows job: snapshot file written | axe-core CLI + token-diff check in CI |

### R37 (PFM 20 Nov 26 evening): large round, run by the PFM on 21 Nov 26
Built overnight from what does not break testing; each item only if its checks are green, else it waits for R38:
- R36 intake (results file, go.md Done) and R36 fixes: T22 cut text lines at 150 % (hand and feedback cards), T24 full test part 1 failure, T21 read failures, step 30 opens on All items (open the probe-button view).
- Test retirement now: `verified.json` ledger and the 1-pass rule; retire "second person edits", Power Automate connections, form look and list button where R36 passed them with unchanged content; keep "second person adds".
- T22 window: Delta logo (Fulcrum in light, USAF in dark), r9 sizing only if the Windows job is green, Feedback with snapshot on every card (B13), fixed button classes and primary last (B1, B5), Sofia Sans with Segoe UI fallback (B7) if the font file loads in the Windows job.
- Lock to engine-v27 (approved 20 Nov 26); engine-v28 (the RADE session) only if it is released and green before the build ends.
- Bookmark page index.html: Sofia Sans with fallback (B12).

### Step 2. 90-161.Z PR for R38 (after the R37 results; lock bump to engine-v28 on the PFM's request)
- T22 (new revision): drop `Select-T22Color`, use `$ui.Color`/`$ui.Recolor`; buttons and the rail from the standard; list-row buttons use compact consistently.
- `index.html`: CSS variables from RADE tokens (keeps Fulcrum/USAF and contrast rules).
- Screen walk: `Test-T22Layout.ps1` and RADE `tests/window_real.py` run every card at 100/125/150/200 % with `-Inventory`; `tests/ui_inventory.py` (new) turns the JSONL into the screen-walk report (every rule break, width spread per row). The first report is the screen-walk deliverable; T09/T11 are listed as non-adopters.
- Test retirement:
  - `docs/reviews/verified.json` (new, one home): step id → content hash, rounds passed, path globs without the revision.
  - `tests/backfill_verified.py` (one time): seeds it from `docs/reviews/*-results.md`, each entry citing its results row.
  - `build_paste_bundles.py` writes each step's `default: {passed, paths}` from the ledger; `--check` fails when a passed, unchanged step is still on. Runs in both check lanes.
  - Exit rule (DEC): off after 1 pass with the same content; back on with any content change or a failure; a by-hand step needs the PFM's pass in the results file.
  - First cuts (if R37 leaves their content unchanged): Power Automate connections, form look, list button, second-person edit. T22 window + look stays in R38 (R37 changes T22) and leaves after it passes there.
- Rule text (lane C, exact text shown in the PR): the round skill line "A step that passed runs again only when its files changed" becomes a pointer to `verified.json` and the `--check`.

### Step 3. R38 on the gov device
Contrast look card (a Windows contrast theme on, both apps), one real 150 % check, retired steps not offered. Results file records each.

### Step 4. Later
T09/T11 move to `$ui` (90-161.Z, R39+). ICF and SEC adopt v1 at birth via `make-an-app.md`.

## Staffing and cost (heavy work: the PFM's approval covers this)
- Orchestrator: Opus (this session). Workers: Sonnet, 2 on RADE (tokens/contrast/builders; self-check/inventory/CI), 2 on 90-161.Z (T22 + index.html; ledger + backfill). Reviewers: Opus, fresh context, one per PR and per fix. Haiku scouts for scans. 7 agents in total.
- Estimate: preview 3 h, RADE 8 to 10 h, 90-161.Z 6 to 8 h; PFM time about 1 h (preview, lock request, R38).
- Needs: push access to rhope-ops/RADE (add_repo with push) at execution.

## Verification
- Step 0: the PFM approves the canvas.
- Step 1: RADE engine test green; `window.yml` green at 7 sizes × 4 scales × normal and contrast; inventory report has 0 rule breaks; B8 ratio check passes; axe-core 0 violations; fresh review with no MAJOR.
- Step 2: `scripts/check.sh` CHECK PASS; ps51 job green; `--check` lists exactly the expected retired steps; bundle revision raised; fresh review.
- Step 3: R38 results file shows the contrast card passed and the retired steps absent; owner minutes compared with R36.

## Assumptions
- R37 ships the Delta logo and window r9 from the local branch work; this plan starts from R37's results (source: NEXT_PROMPT item 2; confidence high).
- Fake-DPI 150/200 % on the runner is close enough for the gate, with one real 150 % check in R38 (confidence medium).
- 160 px fits every action label after the text-limit test; labels that do not fit move to "wide" (confidence medium; the inventory proves it).

## GAPS
- Layout tests are not a required check (cost: a ruleset change; benefit: rule breaks cannot merge). Risk: the standard can drift. Decide at Step 2.
- No visual-regression baseline (cost: screenshot store + diff; benefit: catches paint changes the self-check misses).
- No real-DPI or per-monitor DPI test (cost: gov-device time each round; benefit: catches what faked scaling hides).
