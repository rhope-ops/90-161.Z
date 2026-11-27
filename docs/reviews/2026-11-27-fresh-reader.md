# Fresh-reader test: R48 r1 go.md (2026-11-27)

Files: go.md, task "Round R48 r1" (38 steps), with the screen map of `python3 tests/check_screen_names.py --map` on the R48 bundle. Readers: two fresh `reviewer` agents (Claude, the strong tier's default for the reviewer), each given only the steps and the map.

| Round | Marked steps | Main findings | Result |
|---|---|---|---|
| 1 | 21 of 38 | 9 "write down" notes with no place to use them; "Close (Enter)" on the Done card (Close is not the main button there); no stop for "The round stopped."; vague places and times (steps 20, 24, 31, 34) | Fixed in 96d69d4: the notes go to the round's questions (step 7 says so); real button names; stop cards; time limits |
| 2 | 12 of 38 | On the Repair path the Ready card's main button is "Start Kanon", so "Install (Enter)" was wrong; Cancel timing; which buttons (step 31); "it" (step 35); "A step failed:" not a stop card; GitHub names not marked | Fixed in 169b8fc. Left: step 38 "the e-mail line of the end card" (the line text depends on the end card); "(not from the bundle)" marks stay (the screen-name check needs them) |

Checks after the fixes: INSTRUCTIONS PASS (0 findings), GUIDE TEXT steps=87 failed=0, SCREEN NAMES names=94 failed=0.
