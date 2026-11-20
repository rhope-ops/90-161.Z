# Next prompt: 90-161.Z

Updated 2026-11-19 18:15 Central (R36 r1 merged, PR 185; waits for the PFM). Full open items: [handoff detail](reviews/2026-11-18-handoff-detail.md).

## Open

1. R36 r1 built 19 Nov 26 (W6, W7, W9 to W13 of the [R36 plan](reviews/2026-11-19-r36-plan.md)): 40 steps, waits for the PFM to run it (go.md, https://rhope-ops.github.io/RADE). Open from R35 ([results](reviews/2026-11-19-r35-results.md)): F01 log rows (flows now read by name), T4 (new row step), window dead space; T06 has no step (needs a GenAI.mil extraction by hand).
2. R37 (PFM 20 Nov 26): window r9 (dynamic sizing; failed its first Windows tests in PR 185: values moved controls 2 to 14 px, 3 cards scrolled sideways at 956 x 1081, queue grid 27 px short; the r9 work is in main's history at f069cf8) and the lock to engine-v27 (RADE PR 131: "Your turn" above the step title, values do not move anything).
3. Done 19 Nov 26: the R34 plan points for R36 are built in R36 (DECISIONS 19 Nov 26).
4. Lock: engine-v26 (19 Nov 26, R36 W7: the R7 answer-box fix and the R1 release guard; v25 made the window system DPI aware in ISE). Commit each bundle with its `.sha256.json`. bump_lock.py MINOR: `without_module_caches` takes only `cpython-<digits>`.
5. R37 logo (DECISIONS 19 Nov 26): Delta work is on this branch. R37: T22 window r9 logo (Fulcrum light, USAF dark), bundle, by-hand site logo step.
6. R38: [UI standard plan](reviews/2026-11-19-ui-standard-plan.md) (approved 19 Nov 26); Step 0 preview next.
