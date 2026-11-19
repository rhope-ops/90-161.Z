# Next prompt: 90-161.Z

Updated 2026-11-18 22:30 Central (R32 r1 results; R33 r2 open). Short by the session-load cap; full open items: [docs/reviews/2026-11-18-handoff-detail.md](reviews/2026-11-18-handoff-detail.md).

## Open

1. R33 r2 (1 MB paste, engine-v21) waits for the PFM; read its "Script check" line and the PFM's answers "Bypass: ran or blocked" and "console: opened or not". [R32 results](reviews/2026-11-18-r32-results.md): full flows and window r6 PASS.
2. The PFM decides the fallback for the health flow and the hand-made button flow (R32 finding 4; agent REC: A, both as flows of the solution "90-161.Z flows"). Then build the next round; R32 r2 leaves with it.
3. Lock: engine-v21 (bundle hash; v20 = hand-step buttons and look). Each bundle has `<bundle>.sha256.json` beside it: commit both together. Read in the R32 results: the line "Script check". Next change to scripts/bump_lock.py: `without_module_caches` takes only the tag `cpython-<digits>` (review of PR 170, MINOR). RADE items: [RADE brief](reviews/2026-11-18-rade-brief-r31.md).
4. Window r7 (the PFM, 18 Nov): level the label with its title in the "Needs You Today" rows and in rows blocks, with a measure line; and from the review of PR 168: grid titles under their number may be cut (row height), and the D1-D4 checks measure the layout values, not the drawn ink. One form look step stays in each round (19 Nov). Next T01 round: add Publication.Word.ps1 to T01, T06, T07.
