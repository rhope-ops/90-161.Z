# Project phases and rounds to the pilot (15 Nov 26)

Status: the PFM's phase order (12 Nov 26; [DECISIONS.md](DECISIONS.md) rows of 2026-11-12 and 2026-11-13, full text in [decisions-archive.md](decisions-archive.md); where those rows cite docs/phases.md they mean [the version of 12 Nov 26](https://github.com/rhope-ops/90-161.Z/blob/5e376e1/docs/phases.md), which also holds the options not chosen) and the roadmap the PFM asked for on 15 Nov 26: round counts, no dates, to the pilot. The PFM approved the round order on 15 Nov 26 (1A). The exit criteria and the estimate are agent recommendations (**REC:**) until the PFM approves them. Evidence for every row: [reviews/2026-11-15-roadmap-evidence.md](reviews/2026-11-15-roadmap-evidence.md).

## Phases

| # | Phase | State (15 Nov 26) | Proof | REC: exit criterion (pass or fail) |
|---|---|---|---|---|
| 1 | Deployment engine (RADE) | Install runs work: engine-v4 passed R24; engine-v6 (answers in the window, restore after minimize) first runs in R25. Not built: Diagnose, Back up, Restore, Uninstall; the install record (`marker`) | [R24](reviews/2026-11-15-r24-results.md) | A round passes each of the 5 run types, and the site holds the install record |
| 2 | Function, use, scale | Design decided (roles, backup, digest). 0 built | [roles-and-permissions.md](roles-and-permissions.md), [backup-and-restore.md](backup-and-restore.md) | The role re-assign screen passes a round; a Restore dry run shows the right counts; a co-owner re-binds a connection (P19) |
| 3 | Lists, security, intake | 12 lists and 88 rows on the test site, made by the T02 flow; rights form answered 17 of 17 (open: P18, P19, S14). Not run: lists by PnP; intake | [R12](reviews/2026-11-14-r12-results.md), [R13](reviews/2026-11-14-r13-results.md) | PnP makes the 12 lists on a clean site and a dry run then reports 0 differences from [schemas/lists](../schemas/lists) |
| 4 | App UX and text | Screen map r1 approved (25 screens); previews cancelled; palette provisional | [app/screen-map.md](app/screen-map.md) | Palette values final (Task 12) |
| 5 | Flow rules, provisioning | The T02 flow works; it retires after the PnP round. The flow and app rules of design check r7 are not built | [power-automate-provisioning.md](power-automate-provisioning.md), [NEXT_PROMPT.md](NEXT_PROMPT.md) State | T02 flow removed; provisioning and setup docs rewritten for PnP; the r7 rules are in the flows and the app |
| 6 | Flows build | Slice 1 passed end to end (F03, F05, F06). F01, F02, F04 drafted, never imported. Settings-row values not built | [R22](reviews/2026-11-15-r22-results.md), [flow/solution/README.md](../flow/solution/README.md) | The full solution imports with every flow On; each of F01 to F06 has a passed device check; 6 values come from PFM Settings rows |
| 7 | Canvas app | 0 of 25 screens built; the endorser-answer flow is not built | [app/screen-map.md](app/screen-map.md) | 25 screens built; Accessibility Checker 0 errors; a Read-only user enters data; an endorser answer is recorded |
| 8 | Pilot on the test site | Not started | [rights-test-plan.md](rights-test-plan.md) rows P18, P19 | Start: a second account with fewer rights installs from zero and takes 1 fake publication through every process step |
| 9 | Handover (how-to, kit repo, releases) | Not started; outside this roadmap | - | - |

Scale note (REC from 12 Nov 26, estimate, not measured): PFM Activity Log reaches the 5,000-item view threshold in about 2.5 years at 2,000 rows a year (50 actions x 40 events); index Created and Action ID when the list is made; a yearly archive flow.

## Rounds to the pilot (order approved by the PFM, 15 Nov 26)

A round holds only steps that test something not yet verified (PFM, 2026-11-14). Round numbers after R24 are an order, not a promise: a round that needs a fix runs again under the next number.

| Round | Phase | Proves | Needs first | If it fails |
|---|---|---|---|---|
| R24 | 6, 1 | Passed on 15 Nov 26 ([results](reviews/2026-11-15-r24-results.md)): engine-v4, import page of slice zip r5, site address entered once. Open from it: the F03 test e-mail was not found; the window did not look like the approved Polish pass | - | - |
| R25 | 3, 5, 1 | Open: R25 r1 is on main ([go.md](../go.md)). Clean install from zero: clean-site check, 12 lists by PnP (`scripts/gov/90161Z-T20-provision-lists-r1.ps1`), site setup, slice import and test on the new lists; engine-v6 (answers in the window, restore after minimize, scale line); F03 e-mail with the shared mailbox empty | The PFM deletes the old test objects by hand ([go.md](../go.md) "Clean the test site") | The T02 flow stays (worked R11 to R13) |
| R26 | 6, 1 | 6 flow values from PFM Settings rows (new F03, F05, F06); stage 6 target 25 working days; moved from R25: the health-flow probe, paste timing 500 KB and 1 MB | R25; triage of the 10 list Gap rows | Values stay environment variables |
| R27 | 6 | F01, F02, F04; the full solution with every flow On | R26; the PFM answers the open flow choices; triage of the 3 flow Gap rows; the r7 flow rules | Import the slice plus one flow at a time |
| R28 | 1, 2 | RADE Diagnose and Back up | The PFM approves the function lists in rhope-ops/RADE; an engine release; a lock move | Backup by hand per [backup-and-restore.md](backup-and-restore.md) |
| R29 | 1, 2 | RADE Restore; Uninstall, then a clean reinstall | R28 | Old solutions removed by hand |
| R30 | 7 | Canvas app imports; a Read-only user writes through the app | R27; the app build (cloud work); DEC on app writes; the r7 app rules | A flow writes with the PFM's connection |
| R31 | 7 | Endorsers answer in the app; Restart coordination | R30 | - |
| R32 | 2, 7 | PFM Office screens; role re-assign; the weekly backup flow and the disabled-account list (screens P13, P14 show them) | R31 | - |
| R33 | 4, 7 | Accessibility Checker 0 errors; final palette; site home page (preview first) and its header flow | Palette values (Task 12) | - |
| R34 | 8 | Install from zero by a second account with fewer rights | R27, R29, R33 | The documented fallback for each missing right |
| R35 | 8 | Rights rows P18 and P19; then the pilot starts | R34 | Fallbacks in [rights-test-plan.md](rights-test-plan.md) |

- Critical path: R25, R26, R27, then R30 to R35. R28 and R29 depend on the second repo and can move anywhere before R34.
- The install record (`marker`) is not in a test round: the engine allows it only in a deploy, and a deploy sends no results e-mail. It moves to the first deploy round (R34). The site address on the clipboard at the import step waits for a later engine release.
- Estimate: 12 rounds if each passes on its first run; **23 to 25 is the expected number**; 27 at the high end. Basis: 29 capabilities in R01 to R23 took a mean of 2.28 rounds each, 14 passed in their first round, and 31 device capabilities remain. **Confidence: low to medium**: no canvas app round is in the history.
- REC, not in a round before the pilot: the weekly digest, the setup intake and the Task 9 e-Publishing reader (in the pilot); the 107 "Renderer gap" and 152 Partial coverage rows (triage by the PFM, cloud work); Task 7 Part A with fake seals (drop: the real seals passed in R13); rights row S14 (after the pilot).

## The PFM's decisions the rounds wait for

| Before | Decision |
|---|---|
| The next engine change | Mark what differs on the side-by-side page of the built window and the approved Polish pass (R24 note: "old layout") |
| R26 | Which of the 39 coverage Gap rows close before the pilot ([dafman-coverage/README.md](dafman-coverage/README.md)) |
| R27 | Flow open points: F05 a to e and open choices 2, 4, 5, 7, 9 to 13, 15 ([flow/solution/README.md](../flow/solution/README.md)) |
| R28 | RADE maintenance function lists D1 to D8 and R1 to R7 (agent REC in rhope-ops/RADE docs/engine.md) |
| R30 | How the app writes: list-level Contribute or a flow ([NEXT_PROMPT.md](NEXT_PROMPT.md) item 5) |
| R33 | Palette values (Task 12) |
| The pilot | Second-look F1 to F5 and sweep items S8 to S11; which phase 2 flows run in the pilot |
