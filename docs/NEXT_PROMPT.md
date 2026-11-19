# Next prompt: 90-161.Z

Updated 2026-11-19 23:45 Central (R36 r1 built, waits for the PFM). Full open items: [handoff detail](reviews/2026-11-18-handoff-detail.md).

## Open

1. R36 r1 built 19 Nov 26 (W6, W7, W9 to W13 of the [R36 plan](reviews/2026-11-19-r36-plan.md)): 40 steps, waits for the PFM to run it (go.md, https://rhope-ops.github.io/RADE). Open from R35 ([results](reviews/2026-11-19-r35-results.md)): F01 log rows (flows now read by name), T4 (new row step), window dead space; T06 has no step (needs a GenAI.mil extraction by hand).
2. R36 prep (PFM 19 Nov 26): [prep plan](reviews/2026-11-19-r36-prep-plan.md), [R36 plan draft](reviews/2026-11-19-r36-plan.md), [4.4A design](reviews/2026-11-19-r36-4.4A-design.md) approved (build in R36). Flow and list work (prep P3 to P5) stays on a branch until the R35 results.
3. From the [R34 plan](reviews/2026-11-18-r34-plan.md) (DECISIONS 19 Nov 26): R36 gets the 4.4A design (PFM approves first) and the tests/run.sh fix (lane C); F05 second trigger, Closed Date, suspense from Created, list GUIDs (flow/solution/README.md); point 3 before the pilot; point 11 accepted; F05 pilot interval after R35. RADE items: a RADE session has them (19 Nov 26).
4. Lock: engine-v25 (19 Nov 26; v25 makes the window system DPI aware in ISE: read SCALE thread= and sysDpi=). Commit each bundle with its `.sha256.json`. bump_lock.py MINOR: `without_module_caches` takes only `cpython-<digits>`.
