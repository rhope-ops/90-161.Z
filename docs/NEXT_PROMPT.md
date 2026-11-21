# Next prompt: 90-161.Z

Updated 2026-11-20 21:45 Central (R41 built, waits for engine-v31). Full open items: [handoff detail](reviews/2026-11-18-handoff-detail.md).

## Open

1. R41 r1: PR 208; lock on engine-v31 (0be2622). Waits for RADE engine-v32 (test site marked locally). Then: manifest 12 lists + restore, pause row step, Restore steps, review; lane C (tests/run.sh). Audit after R41.
2. Lock: engine-v30 (Maintenance: Diagnose and Back up; before: v29 pause/resume, Fulcrum logo, no scripts at collect, UI standard v1). Not verified on a device: Resume and Paused cards, CAC removal text. RADE UI file split into T22 parts ui and ui2 (build_task_scripts.py split_ui).
3. T22 r13 is the window on main (kept cards, paint times). Known limits: paint time is to the first Paint only; CARDTIME later-max mixes kept opens and builds. Also open: 12th backup list (RADE), F01 log rows, T06, RADE pause and resume not verified.
