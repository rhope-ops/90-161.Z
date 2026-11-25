# Fresh-reader test: R42 r1 steps (24 Nov 26)

Files: go.md (the task "Round R42 r1"; TASKS.md is its copy from build_readme.py), the runner cards and questions of R42 in scripts/paste_bundles.json, and the 21 bottom-bar lines of the T22 window r15 (from `-PlanOnly`).
Reader: the `reviewer` subagent (inherits the author's tier, Opus). Each test used a new agent that read only the steps, as the person sees them.

| Test | Read | Marked | Main marks | Result |
|---|---|---|---|---|
| 1 | go.md task, cards | 16 | no step to act on the cards; the Teams address not shown again; sign-in size asked with no step to note it; two windows that start with "90-161.Z" (5 marks came from an input file that cut off 3 page sections) | rewritten |
| 2 | page section, go.md task, cards, bar lines | 15 | Run after the steps that need it; the second person not picked before the round; "Wave 1 answers" asked after the window closed; "tell Claude" with no text | rewritten |
| 3 | go.md task, cards | 12 | NOT found gate said "Go on"; sign-in size noted after the window closes; "the small window" not named; no Done step; the Restore caution after the step; the clipboard not named | rewritten (below) |

Changes after test 3: the NOT found gate stops the task; the small window is named **90-161.Z test T4**; a step clicks **Done** on each card; the size of the CAC sign-in window is written down before the sign-in (Back up card); the Restore caution comes before **Restore**; the Teams card names the clipboard; the last step sends `R42 sent` to Claude.

Not changed, with the reason:
- The bar lines "Pass if ... opens and looks right" (tests 2, 3): the PFM's own judgment is the test; the same form passed in R41 (15 of 17 screens).
- The page sections "Steps to start a round", "Send a line to Claude" and "Send the results by hand" (test 2): released after the fresh-reader test of 21 Nov 26 (4 tests, 0 blockers).
- No card line says "Done" (tests 1 to 3): the runner text rule forbids it (tests/check_guide_text.py); go.md step 14 says it.
- The test site name (tests 2, 3): RADE asks only if it has no test-site mark; R41 saved one. The line names where to read the name.

Checks on the final text: `GUIDE TEXT failed=0`; `INSTRUCTIONS PASS` on go.md, TASKS.md and scripts/paste_bundles.json. No fourth reader ran before the release: the changes after test 3 are local to the marked lines.
