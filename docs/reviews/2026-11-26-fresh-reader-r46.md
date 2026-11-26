# Fresh-reader test: R46 r1 (26 Nov 26)

Files: go.md "Round R46 r1" (28 steps) and the R46 runner cards that changed (T21 note, look questions after T29, Back up, Restore, Close the second window, Uninstall, Install again), with the output of `python3 tests/check_screen_names.py --map`. Reader: `reviewer` subagent (inherit tier), given only the steps and the map; a new reader for pass 2.

| Pass | Marked | Fixed in the text |
|---|---|---|
| 1 | 28 of 88 | look card: no hint in the note, the step named in question 1, "pressed F5" in question 2, an "other" choice in questions 3 and 4; Back up step 1 says what to look for, step 5 why Alt+Tab; Restore: a repeated "keep open" line and a filler line removed; the result question names the line "Restore put back"; T21 note says Skip (it said the step fails) |
| 2 | 16 of 42 | Close note filler removed; "Do not close" line removed (the note says it); the pause question gets the choice "There is no such line" |

## Left as they are

- go.md steps 3 to 28 and the Uninstall and Install again cards: the same text as R45 r1, which the PFM ran on the device (Repair, Install, Uninstall and the new install passed).
- **Install**, **Run**, **Resume at step**, **Repair**, **Shortcut in** and **Skip** (the T21 window) are made at run time, so the map does not list them; each text is in the R46 bundle.
- A "Something else" or "No: ..." answer opens the engine's "It failed" card, which asks for the text the person saw (R45 report: "Error text: ..."), so the questions need no text box.
- Back up failure lines after step 9, and the order of the Restore cards: the same as R45, where the PFM did them.
- "(not from the bundle)" marks: the screen-name check's skip mark (R45 record, later item).
