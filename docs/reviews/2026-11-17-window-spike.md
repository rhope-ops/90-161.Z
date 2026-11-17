# PFM window: WinForms fidelity spike (17 Nov 26)

Deeper pass, steps 4, 5 and 7 (plan: docs/reviews/2026-11-17-window-plan.md; targets: docs/reviews/2026-11-17-window-ux-targets.md). Worker (standard tier) built a throwaway spike in rhope-ops/RADE (pull request 69, closed, not merged; changed tests/ only). The RADE "window" job (windows-latest, Windows PowerShell 5.1) drew two preview-2 boards in real WinForms with fake data. Run: https://github.com/rhope-ops/RADE/actions/runs/43995640085 (job artifact "window", folder spike/, kept 14 days). Self-review of the pictures by the orchestrator; not an independent review. The 3 pictures are also on the private preview canvas, row "Real window" (boards 1b real, 1d real, 4 real), after the PFM's .pii-guard skip line of 17 Nov 26.

## Result

Both boards draw in WinForms close to the HTML boards: menu, chips with round ends, the Who Has It Now board (DataGridView with hand-painted cells, 41 px rows), the Chase column, the 12-dot step bar with the yellow current dot. The job passed; its pass rule did not change.

| Board | Size | Controls | No screen-reader name | Clipped (tool count) |
|---|---|---|---|---|
| Your Work | 1280 x 720 | 57 | 0 | 28 |
| Your Work | 1707 x 1440 | 72 | 0 | 34 |
| Step 8 | 1280 x 720 | 83 | 0 | 27 |

- "Clipped" is inflated: most are labels whose preferred height is 1 to 2 px over the set height. Real cuts seen: "Feedback from rea..." (Step 8 side panel), the Publication link without "...", step labels "Endorsers" and "Signatures" broken mid-word.
- "No screen-reader name = 0" only shows the spike set a name on every control it made; Narrator was not run.

## Differences from the HTML, and effort to close

| # | Difference | Effort |
|---|---|---|
| 1 | Square corner behind each step dot | Easy: rounded Region |
| 2 | Step labels break mid-word | Easy: wider label or 10 px |
| 3 | Check boxes are the stock 13 px glyph, not 24 px | Custom paint |
| 4 | Buttons have square corners (HTML 4 px) | Easy to moderate: Region or custom paint |
| 5 | Grid header has no letter spacing; classic grey scroll bar | Hide bar: easy; styled bar: custom paint |
| 6 | Link underline starts 1 to 2 letters early (LinkArea) | Easy |
| 7 | Logo is a placeholder square | Easy once the Rho Bold file is in the bundle |
| 8 | Real Segoe UI widths differ from the HTML fallback font | Expected; tune per label |

## Not proven by the spike

Keyboard-only paths (U6), Narrator and Windows high contrast (U7), hover and focus states, 125 % and 150 % scaling (the job draws at 100 %). These move to R28 on the gov device.

## R28 additions (plan step 7)

- LAYOUT 0 defects and a SCALE line (font scale = control scale) at the device's real scale.
- The window opens where it was last closed; client size at Shown and at close recorded.
- Screenshots of Your Work and Step 8 on the device, compared with the approved boards.
- Keyboard-only walk of the five timed tasks; Narrator reads each control; one look in Windows high contrast.
- Fix items 1, 2, 4 and 6 above in the T22 r2 build before R28.
