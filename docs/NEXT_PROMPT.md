# Next prompt: 90-161.Z

Updated 2026-11-19 05:35 Central (R33 and R34 results). Short by the session-load cap; full open items: [docs/reviews/2026-11-18-handoff-detail.md](reviews/2026-11-18-handoff-detail.md).

## Open

1. R33 and R34 results on main ([R33](reviews/2026-11-19-r33-results.md), [R34](reviews/2026-11-19-r34-results.md)): 1 MB paste PASS (ISE and console); test flows in the solution PASS; without Bypass = ran. Next round (R35): F05 r5 (action description 365 > 256; add a build check), the import card options (site address and e-mail boxes; "Connection References"), the second person edit again, then the F02/F04 parts. Open points 1-3, 5-9, 11-12 of the [R34 plan](reviews/2026-11-18-r34-plan.md) stay open (4 and 10 closed).
2. R35 (big round, DEC 19 Nov 26): F03 r7 = 15 business days (DAFMAN 5.2); F05 r5 every 1 minute; second person step again; window r8 (logo in high contrast; R34 plan points 5, 6).
3. Lock: engine-v23 (19 Nov 26; v22 on writes RADE\Config\rade-checks-last.txt with the check details). Each bundle has `<bundle>.sha256.json` beside it: commit both together. Read in the R32 results: the line "Script check". Next change to scripts/bump_lock.py: `without_module_caches` takes only the tag `cpython-<digits>` (review of PR 170, MINOR). RADE items: [RADE brief](reviews/2026-11-18-rade-brief-r31.md).
4. Window r8 and the test harness: R34 plan, open points 5 and 6. One form look step stays in each round. Next T01 round: add Publication.Word.ps1 to T01, T06, T07.
