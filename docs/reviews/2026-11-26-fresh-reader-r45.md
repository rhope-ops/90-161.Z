# Fresh-reader test: R45 r1 go.md task (26 Nov 26)

Files: go.md "Round R45 r1" (28 steps), with the output of `python3 tests/check_screen_names.py --map`. Reader: `reviewer` subagent (inherit tier), given only the steps and the map.

| Pass | Marked | Fixed in the text |
|---|---|---|
| 1 | 12 of 28 | 12 and 22 (which button), 14 ("keep the folder" was no action), 15 (repair sentence removed), 25 (what happens after the 3-minute stop) |
| 2 | 8 of 28 | none: see "Left as they are" |

## Left as they are (pass 2)

- 14, 24: the box **Shortcut in** and the buttons **Run**, **Resume at step**, **Install**, **Repair** are made at run time, so the map does not list them; each text is in the R45 bundle (grep of scripts/gov/paste/90161Z-R45-round-r1.ps1).
- 26: the runner window shows every step after the start (round skill section 5: go.md holds only the steps that start the round).
- 1, 27: GitHub and Outlook names without the "(not from the bundle)" mark; the step can be done. The mark itself shows in README.md (a later item: it is the screen-name check's skip mark).
- 7, 9, 28: the same text as the R44 r2 task, which the PFM ran on the device.
