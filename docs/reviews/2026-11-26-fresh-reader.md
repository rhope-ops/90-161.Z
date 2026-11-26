# Fresh-reader test: R44 r2 go.md task (2026-11-26)

Files: go.md, task "Round R44 r2" (steps 1 to 37). Reader: the `reviewer` subagent (fresh context), same model tier as the author, 2 rounds.

## Round 1 (all steps, with the screen map of `tests/check_screen_names.py --map`)

Marked and fixed: step 9 (one sign-in named, the test has 2), step 11 (no fallback when no Outlook draft opens), step 14 ("RADE now runs inside ISE" read as a contradiction), the sign-ins inside ISE had no step, no step sent the second e-mail.
Marked, not changed: the "(not from the bundle)" markers (they are the screen-name check's own notes); the buttons Run, Repair, Install and Resume at step (the map lists only part of the buttons; tests/check_screen_names.py finds each in the bundle); steps 15 to 33 (the R44 r1 steps, unchanged since their own fresh-reader test of 2026-11-25).

## Round 2 (the changed steps 5 to 14 and 34 to 37)

Marked and fixed: step 9 and 34 now say how many sign-ins come and when; the fallback e-mail step now points to the e-mail line of the end card (that card names the open results folder and the summary on the clipboard).
Marked, not changed (minor, R44 r1 text): step 6 "text runs in ISE", step 13 "The RADE window closes.", step 35 (the actions come from the cards).

Result: `scripts/check_instructions.py go.md` INSTRUCTIONS PASS; `tests/check_screen_names.py` names=154 failed=0.
