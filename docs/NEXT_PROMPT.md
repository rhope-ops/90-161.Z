# Next prompt: 90-161.Z

Updated 2026-11-20 21:45 Central (R41 built, waits for engine-v31). Full open items: [handoff detail](reviews/2026-11-18-handoff-detail.md).

## Open

1. R41 r1 built: pull request 208 (rhope-ops/90-161.Z), head 736f674; check.sh PASS; ps51 green on ce33bf4; 3 fresh reviews, last one no MAJOR/MINOR. DO NOT MERGE until RADE engine-v31 (Restore) ships and the PFM asks for the lock move. Then: add the Restore step after 'T22 Record the test install r14' in paste_bundles.json bundles[0], Restore settings on apps[1], `python3 scripts/bump_lock.py engine-v31`, a go.md line, a new review. Plan: [r41 plan](reviews/2026-11-21-r41-plan.md). Open NITs: feedback-r14 header lines 14-21 long; T26 Made=yes kept from an old state file. Audit after R41 ships.
2. Lock: engine-v30 (Maintenance: Diagnose and Back up; before: v29 pause/resume, Fulcrum logo, no scripts at collect, UI standard v1). Not verified on a device: Resume and Paused cards, CAC removal text. RADE UI file split into T22 parts ui and ui2 (build_task_scripts.py split_ui).
3. T22 r13 is the window on main (kept cards, paint times). Known limits: paint time is to the first Paint only; CARDTIME later-max mixes kept opens and builds. Also open: 12th backup list (RADE), F01 log rows, T06, RADE pause and resume not verified.
