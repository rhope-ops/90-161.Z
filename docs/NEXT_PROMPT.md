# Next prompt: 90-161.Z

Updated 2026-11-20 05:00 Central (R37 r1 merged, PR 187; the PFM runs it). Full open items: [handoff detail](reviews/2026-11-18-handoff-detail.md).

## Open

1. R37 r1 merged 20 Nov 26 (PR 187; 35 steps; engine-v27; [R36 results](reviews/2026-11-19-r36-results.md)): the PFM runs it (https://rhope-ops.github.io/RADE).
2. Retired steps: [verified.json](reviews/verified.json). R38 candidates: T01, T07, T19, T20, form header, health (passed R36).
3. R38: add "guide": [] to the step "Answer 3 questions about the window look" (the engine schema needs it on every guide step; PFM 20 Nov 26); Sofia Sans (T22 and index.html; font files in RADE), T21 view link by ID, Enter check 6, [UI standard plan](reviews/2026-11-19-ui-standard-plan.md) Step 2.
4. Lock: engine-v27. Commit each bundle with its `.sha256.json`.
5. UI standard v1 in RADE: RADE PR 136 (a RADE session builds the Maintenance screen next); then lock bump and R38. Still open from R35: F01 log rows; T06 has no step (GenAI.mil extraction by hand).
