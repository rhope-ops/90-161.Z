# R30 screen audit and the PFM's look notes (18 Nov 26)

Source: the PFM's answers in chat on 18 Nov 26 to the questions in the [R30a results](2026-11-18-r30a-results.md) and [R30b results](2026-11-18-r30b-results.md), and the bundles on main (`scripts/gov/paste/90161Z-R30a-round-r1.ps1`, `-R30b-round-r1.ps1`, RADE engine-v18). Method: every hand step ("needs you") read from the round definition; the buttons read from the engine code that draws the hand card (`$ui.VHand`), not from screenshots. This file is self-review.

## Why the wrong buttons appear (root cause)

The engine draws the same 3 buttons on every hand step: **Done**, **It failed** and **Skip**. It does not look at what the step asks. A step can rename them (`DoneText`, `NoText`, `SkipText`; the engine's own "Check Power Automate" card does this), but no step in this repo uses that, and no step can hide a button or skip the card. So:

- A step that only asks questions still shows Done, It failed and Skip first (the PFM's screenshot 18:03: "Answer each of the next 2 cards").
- A step whose questions already record a failure still shows "It failed" (2 ways to say the same thing).
- Every step shows "Skip", also when skipping makes no sense or when the step should not be shown at all.

**Confidence: high** (read from the engine code; the same 3 buttons on all 20 hand steps).

## Button rules (proposed for R31; the PFM decides)

| # | Rule | Where it is fixed |
|---|---|---|
| B1 | A card shows a button only when that button leads to a different result. | RADE engine (an option to hide a button; a step can only rename one today) |
| B2 | A step that only asks questions shows its first question at once: no Done, It failed or Skip. | RADE engine (new option) |
| B3 | 1 way to report a failure: the question loses its failure choice (this repo, now), or the card loses "It failed" (RADE option). | This repo or RADE engine |
| B4 | "Skip" only where skipping is safe and has a meaning; its text says that meaning ("Not now", "Nothing to delete"). | Rename: this repo (`SkipText`); hide: RADE engine |
| B5 | A step whose thing was never made is skipped by the round, not shown (the PFM's R30a note). | Round definitions (`After`) |
| B6 | "Done" names what the person did when the step is a look ("I looked at the form"). | Round definitions (`DoneText`) |
| B7 | A question about a screen comes while that screen is open. | T22 (questions in its check bar) or the round order |

## Every hand step in R30

"#" is the hand-step number in this audit, not the step number in the round reports.

| # | Round | Step | Buttons today | Problem | Fix (rule) |
|---|---|---|---|---|---|
| 1 | R30a | Power Automate shows your connections | Done, It failed, Skip; then Yes/No | "It failed" and "No" overlap; Skip skips the gate for all flow steps | 1 question, 3 answers: "SharePoint connection is there", "The list loaded, no SharePoint connection", "The page shows an error" (B2, B3) |
| 2 | R30a | Import the health flow: choose the file | Done, It failed, Skip | Skip has no use | Done, It failed (B4) |
| 3 | R30a | Import the health flow: connections | Done, It failed, Skip; then 2 questions | Answer "The import was refused" is the same as It failed | Remove that answer; no Skip (B3, B4) |
| 4-8 | R30a | Button flow by hand: make a solution, make the flow, site and list, action, export | Done, It failed, Skip | Skip has no use | Done, It failed (B4) |
| 9 | R30a | Look at the list form | Done, It failed, Skip; then 2 questions | The card says "select Skip" when the form is missing (that is a failure); the answers "No" and "I found no form menu" overlap with It failed | Rewrite for fallback A: Done = "I looked at the form", no It failed, no Skip; "The form did not open" becomes an answer (B3, B4, B6) |
| 10 | R30a | Use the list button | Done, It failed, Skip; then 2 questions | Answers "An error" and "No panel opened" overlap with It failed | Done = "I tried the button"; no It failed, no Skip (B3, B4, B6) |
| 11 | R30a | T24 import: choose the file | Done, It failed, Skip | Skip has no use | Done, It failed (B4) |
| 12 | R30a | T24 import: finish | Done, It failed, Skip; then 2 questions | Skip has no use | Done, It failed (B4) |
| 13 | R30a | Turn on all 6 flows | Done, It failed, Skip; then 1 question | Skip has no use | Done, It failed (B4) |
| 14, 16 | R30a | Run F02 and F04; run F02 again | Done, It failed, Skip | Skip has no use | Done, It failed (B4) |
| 15 | R30a | Find the F04 e-mail | Done, It failed, Skip; then 3 questions | Answer "Not found" overlaps with It failed; after "Not found", questions 2 and 3 (tables, To line) ask about an e-mail that is not there | Done = "I looked"; no It failed; questions 2-3 only after "Inbox" or "Junk Email" (B3, B6; the last part needs a RADE option) |
| 17 | R30a | Remove the health flow and solution | Done, It failed, Skip | Shown although the import failed (the PFM's note) | Runs only if step 3 (the import finish) passed; else SKIPPED with "nothing was made" (B5) |
| 18 | R30a | Remove the button flow and solution | Done, It failed, Skip | Must run if the empty solution was made; the flow part only if step 5 passed | 2 steps: delete the flow (after step 5), delete the solution (after step 4) (B5) |
| 19 | R30b | Answer: look and cards | Done, It failed, Skip; then 3 questions | The card has no task, only "answer the next cards" | The 3 questions at once (B2) |
| 20 | R30b | Answer: the screenshot fixes | Done, It failed, Skip; then 2 questions | Same (the PFM's screenshot); also asked after the 90-161.Z window is closed, so the card cannot be seen (the PFM's "No" answers are not valid) | Ask while the window is open, or keep the window open until the questions are answered (B2, B7) |

Count: 20 hand steps; each shows a button with no use or a doubled meaning. Possible in this repo now: B5 (`After`), B6 (`DoneText`), renamed Skip (`SkipText`), a failure choice removed from a question (B3), the question order (B7). Needs a RADE change: hiding any button (B1, B3, B4), questions at once (B2), questions that depend on an earlier answer (step 15). **Confidence: high** (step fields read in the bundle).

Not covered by this audit: the RADE start, file-list, checks and done screens, and the 17 cards of the 90-161.Z window (T22). They are drawn by code with no fixed screenshots here. Proposal: the T22 step already opens all 17 cards by script; R31 can also save a screenshot of each card (fake data only) into the results folder, and RADE can do the same for its own screens. Then the audit covers every screen from pictures, not from code alone.

## The PFM's look notes (R30b `w-change`) and the 18:03 and 17:57 screenshots: comments

| # | Note | Comment | REC | Owner |
|---|---|---|---|---|
| L1 | The card height changes and the screen jumps; fix bounds so "Step x of x" stays put | Agree; it is the main cause of the "malfunction" look. The card fits its height to each step's text. A fixed card frame (a minimum and a maximum height, the text scrolls inside) and a fixed header row for "Step x of x" stop the jump. | Fixed frame and fixed header row | RADE engine |
| L2 | "90-161.Z" too low under the RADE title; a thin line between them as wide as "RADE"; title not on the logo's midpoint; logo has a white background | Agree on all 4. The first 2 are the RADE header. The 17:57 screenshot is the rail of the 90-161.Z window (T22), not RADE: our code puts the logo in a white box on the navy rail (`$logo.BackColor = $ui.C.White`), and it places the title at 18 px while the logo's middle is at 36 px (`scripts/gov/90161Z-T22-window-r4.ps1`, `RailHead`). | RADE: title spacing and divider. This repo (T22): no white box (navy or transparent), title centered on the logo's midpoint | RADE engine and this repo |
| L3 | "Your answer" is to the left of its box | Agree. A label above the box is the usual form layout and gives the box the full width. | Label above the box | RADE engine |
| L4 | A place for free feedback at the end of a round | Agree. Today your notes go into the e-mail body (as in R30a), where the report cannot keep them. One optional last card "Anything else about this round or the app?" puts them in the report file. | Optional last card in every round | RADE engine |
| L5 | "Your turn." and "RADE is working..." instead of "RADE is waiting for you" | Agree. The card already says "your turn" at the top, so the side text repeats it in other words. 2 fixed states, the same words every time. | Use your 2 phrases | RADE engine |
| L6 | A central tutorial for RADE, and one when 90-161.Z finishes installing | Agree, but 2 sizes. RADE: a short first-run tour (4-5 cards: what a round is, your turn and RADE's turn, what Done, It failed and Skip mean, where the results go), shown once and again from a Help button. 90-161.Z: its first-open tour belongs to the real install (deploy phase), not to the test rounds. | RADE tour now; app tour at deploy | RADE engine; this repo later |
| L7 | Status text such as "Installing the lists that make 90-161.Z work..."; you like the live numbers | Agree. Each script already writes a line per item (for example `ITEM m2-list PASS list there`). RADE can show the current item as a plain sentence under the bar, and each step can carry a present-tense title for that line. **Confidence: medium** that RADE can read the lines live. | Live "now doing" line from the item lines | RADE engine and this repo (step text) |
| L8 | A smoother change when steps go by fast; the stutter looks broken or suspicious | Agree; with an ISSM watching, "suspicious" is a real risk. L1 removes most of it. Then each step stays on screen for a short minimum (about half a second), or a run of fast steps shows as one line "Checked 6 items". | L1 first, then a minimum time per step | RADE engine |
| S1 | Screenshot 18:03: "It failed" and "Skip" on a card that only asks questions | Same as steps 19-20 above (B2). | B2 | RADE engine |

## Answers the PFM gave on 18 Nov 26

1. Form look: fallback **A** (open the list, select "+ New", use the side panel with "Edit form").
2. High contrast: **yes**, the 90-161.Z window kept its own colors when the theme came on. So check 10 fails because the window ignores the Windows contrast theme, not because of the steps. A fix: the window uses the system colors when high contrast is on.
3. V2 and V4: the PFM sends a screenshot of the whole card. Later the same day, the PFM said the "No" answers were in error: the questions came after the window was closed.
4. Screenshots: the 17:57 one (the 90-161.Z window rail) shows that the title is not on the logo's midpoint and that the logo has a white background (L2); the 18:03 one shows "It failed" and "Skip" on a card with only questions (S1).
