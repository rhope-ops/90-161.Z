# Fresh-reader test, round R43 (T7)

Date: 26 Nov 26 (work done on the branch claude/r43-t7).
Files read by the person: go.md (task R43 r1, steps 1 to 21); scripts/paste_bundles.json, the guide lines of "T27 Uninstall in a second window r1" and "T27 Install again in a second window r1" (and the changed line 3 of "T27 Remove the flows by hand r1").
Bundle: scripts/gov/paste/90161Z-R43-round-r1.ps1 (engine-v41).

## Result: NOT RUN

The worker session had no `reviewer` subagent and could not start a new session (its tools: Read, Edit, Write, Bash, Grep, Glob, advisor). Per the instructions skill, a self-review is not called a fresh-reader test. The criterion "the last fresh reader marks no step" is NOT met until the Orchestrator runs the test below.

## Packet for the fresh reader

Give the reviewer only:

1. The 21 numbered steps of the R43 task in go.md, and the guide lines named above, as the person sees them.
2. The output of `python3 tests/check_screen_names.py --map` (each card and its sentence, in code order, and the button texts). Note for the reader: a button text that the code builds at run time ("Install", "Run", "Repair", "Resume at step <n> of <m>") is not in the BUTTONS line; the card code shows it.
3. The brief of the instructions skill: "For each step, say back the screen or window, the actions, the exact text to type, and any value you must note (and where you use it). Mark each step where you cannot say one of these, where you would act before you should, or where a sentence tells you nothing you need."
4. The round skill, section 5 addition: "Mark each step whose screen, button or order differs from the map."

Record each round here (date, reader, model tier, marked steps, result). Rewrite each marked step and test again with a new fresh reader until no step is marked.

## Self-check against the map (self-review, not a fresh reader)

The author compared each step with the card order of the bundle code. This is not independent.

| Steps | Code order in the bundle | Match |
|---|---|---|
| go.md 8 to 15 (Repair) | Choose row, card "Maintenance" (button "Maintenance"), card "Maintenance" of the tools (button "Repair"), "Checking this computer and your access.", "One check needs you." or "One check failed.", "Ready to install 90-161.Z 0.1.0.", "90-161.Z 0.1.0 is installed." (button "Close") | yes |
| go.md 16 to 20 (round) | Choose row "90-161.Z R43", check cards, "Ready to run round R43." (button "Run" or "Resume at step <n> of <m>") | yes |
| go.md 21 | end cards "Round R43 is done." and "The round needs review." | yes |
| Uninstall guide, lines 3 to 10 | card "Maintenance" (first button "Uninstall"), "Is the saved site a test site?" (box "Site name", button "Mark as test site"), "Uninstall 90-161.Z from the test site?" (box "Type 90-161.Z to confirm", button "Uninstall"), run card, hand card "Remove the flows of 90-161.Z in Power Automate" (Done, It failed, Skip), result card "90-161.Z is uninstalled." (button "Done", then Choose) | yes |
| Install guide, lines 2 to 8 | Choose row (the app is not installed, so no card "Maintenance"), check cards, "Ready to install 90-161.Z 0.1.0.", "90-161.Z 0.1.0 is installed." (button "Close") | yes |

Open points the reader may mark (author's view): the box "Site name" asks for "the part of its address after the last /" on the card itself; the guide says only "the site name". The hand card of the flows step shows "Skip" as well as "Done"; Skip stops Uninstall (engine rule), so guide line 3 now says "Done".
