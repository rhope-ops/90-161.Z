# Fresh-reader test: R42 r1 steps (24 Nov 26)

Files: go.md (the task "Round R42 r1"; TASKS.md is its copy from build_readme.py), the runner cards and questions of R42 in scripts/paste_bundles.json, and the 21 bottom-bar lines of the T22 window r15 (from `-PlanOnly`).
Reader: the `reviewer` subagent (inherits the author's tier, Opus). Each test used a new agent that read only the steps, as the person sees them.

| Test | Read | Marked | Main marks | Result |
|---|---|---|---|---|
| 1 | go.md task, cards | 16 | no step to act on the cards; the Teams address not shown again; sign-in size asked with no step to note it; two windows that start with "90-161.Z" (5 marks came from an input file that cut off 3 page sections) | rewritten |
| 2 | page section, go.md task, cards, bar lines | 15 | Run after the steps that need it; the second person not picked before the round; "Wave 1 answers" asked after the window closed; "tell Claude" with no text | rewritten |
| 3 | go.md task, cards | 12 | NOT found gate said "Go on"; sign-in size noted after the window closes; "the small window" not named; no Done step; the Restore caution after the step; the clipboard not named | rewritten |
| 4 | go.md task, cards | 4 blockers, 10 minor | the card, question and bar steps ran one time only; no Pass or Fail step; a test-site name to guess | rewritten: "Each time" steps; Pass or Fail; RADE's test-site question stops the step |
| 5 | go.md task, cards | 2 blockers, 5 minor | Pass came before the Screen 10 note; no OK in the window **90-161.Z test T4** | rewritten (below); released |

Changes after tests 3 to 5: the NOT found gate stops the task; the small window is named **90-161.Z test T4**; a step clicks **Done** on each card; the size of the CAC sign-in window is written down before the sign-in (Back up card); the Restore caution comes before **Restore**; the Teams card names the clipboard; the last step sends `R42 sent` to Claude; the **Stopped** card and the no-draft path have their own steps; the Screen 10 note comes before **Pass**; a step clicks **OK** in the window **90-161.Z test T4**.

Not changed, with the reason:
- The bar lines "Pass if ... opens and looks right" (tests 2, 3): the PFM's own judgment is the test; the same form passed in R41 (15 of 17 screens).
- The page sections "Steps to start a round", "Send a line to Claude" and "Send the results by hand" (test 2): released after the fresh-reader test of 21 Nov 26 (4 tests, 0 blockers).
- No card line says "Done" (tests 1 to 3): the runner text rule forbids it (tests/check_guide_text.py); go.md step 14 says it.
- The test site name (tests 2 to 4): RADE asks only if it has no test-site mark; R41 saved one. If it asks, the PFM closes the window and reports it (no name is typed, so no site can be marked by mistake).
- Test 5 minor points (the Teams list pick, the place of the **Stopped** step, one window name in step 5): left for the R43 redraft.

Checks on the final text: `GUIDE TEXT failed=0`; `INSTRUCTIONS PASS` on go.md, TASKS.md and scripts/paste_bundles.json. The 2 blockers of test 5 are local fixes (the order of 2 lines, and one OK click); no sixth reader ran.
