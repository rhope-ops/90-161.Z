# Next prompt: 90-161.Z

Updated 2026-11-19 02:25 Central (R34 on main). Short by the session-load cap; full open items: [docs/reviews/2026-11-18-handoff-detail.md](reviews/2026-11-18-handoff-detail.md).

## Open

1. R33 r3 (1 MB paste, run first) and R34 r1 (38 steps, about 1 MB) wait for the PFM. Read in the results: "Script check", "Bypass: ran or blocked", "console: opened or not", and the 12 open points in the [R34 plan](reviews/2026-11-18-r34-plan.md) "Open after R34" (DAFMAN 5.2: 15 days against 20 first).
2. [R32 results](reviews/2026-11-18-r32-results.md): full flows and window r6 PASS. If R34 does not paste: split it in 2 parts.
3. Lock: engine-v21 (bundle hash; v20 = hand-step buttons and look). Each bundle has `<bundle>.sha256.json` beside it: commit both together. Read in the R32 results: the line "Script check". Next change to scripts/bump_lock.py: `without_module_caches` takes only the tag `cpython-<digits>` (review of PR 170, MINOR). RADE items: [RADE brief](reviews/2026-11-18-rade-brief-r31.md).
4. Window r8 and the test harness: R34 plan, open points 5 and 6. One form look step stays in each round. Next T01 round: add Publication.Word.ps1 to T01, T06, T07.
