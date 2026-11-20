# Next prompt: 90-161.Z

Updated 2026-11-20 08:30 Central (R37 results; R38 r1 built; RADE session for pause/resume). Full open items: [handoff detail](reviews/2026-11-18-handoff-detail.md).

## Open

1. R38 r1 (13 steps; T4 by a second person first; site logo Fulcrum; window r11): the PFM runs it this afternoon (https://rhope-ops.github.io/RADE). Ask the PFM for a second person in every round until T4 passes (PFM 20 Nov 26).
2. [R37 results](reviews/2026-11-20-r37-results.md): full flow test passed; 20 steps retired ([verified.json](reviews/verified.json)). Trash the R37 e-mail once this merge is on main (PFM 20 Nov 26); R35, R36 e-mails trashed 20 Nov 26.
3. RADE engine-v29 (e503386: engine-v28 pause/resume, Fulcrum logo, no script files at collect, plus UI standard v1) is in the R38 lock (bump_lock PASS 20 Nov 26). Not verified on a device: Resume and Paused cards, CAC removal wording.
4. Lock: engine-v29. The RADE UI file is split into T22 parts ui and ui2 (scripts/build_task_scripts.py split_ui; 600-line cap). Commit each bundle with its `.sha256.json`.
5. Next rounds: [phases.md](phases.md) "Rounds from R38". Open from earlier: UI standard Step 2 (90-161.Z window to the standard), Sofia Sans in T22, F01 log rows, T06 (GenAI.mil extraction by hand).
