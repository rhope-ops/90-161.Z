# Next prompt: 90-161.Z

Updated 2026-11-24 Central (R42 r1 built; earlier: 2026-11-23 fleet v2 Stage 3A, 2026-11-21 R41 results and R42 plan).

## Open

1. R42 r1 is built and is on the RADE page (PR #231): T22 window r15, the CAC sign-in window at about 480 x 360 (T21 r12, T26 r2, T22 site r15), 23 redrafted steps, a Repair of 90-161.Z 0.1.0 first. Lock: engine-v37 (b645019). Not run on a device. Next: the PFM runs R42; record the results with `.claude/skills/round/SKILL.md` section 1.
2. R42 build record: PR #231 (what changed, checks) and docs/reviews/2026-11-24-fresh-reader.md (3 fresh-reader rounds).
3. Watch in the R42 results: the 3 grid LAYOUT lines (home, queue, waves), WALK 10 and 11, a "NOTE the screen ... did not open" line, the SCALE line of each RADE window (E4), `w-signin` and `b-signin` (E3), `r-bin` (pass = "X is 3 and Y is 0"; E2 has no engine fix) and the RESTORE-BIN line of T26 check.
4. RADE: the sign-in window size block holds `Start-SignInSize`, which PSScriptAnalyzer flags (PSUseShouldProcessForStateChangingFunctions) when an app holds it as live code. 90-161.Z loads it at run time from quoted lines (scripts/build_task_scripts.py). A RADE fix: a verb that does not change state, or a SuppressMessage attribute.
5. Also open: 12th backup list (RADE), F01 log rows, T06, RADE pause and resume not verified, Resume and Paused cards and CAC removal text not verified. Known limits: [detail](reviews/2026-11-21-handoff-detail.md).
