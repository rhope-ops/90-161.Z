# RADE runner polish pass: text rules for R28 (17 Nov 26)

Source: the PFM's answers 1A and 2A on the preview canvas https://claude.ai/artifact/RyACy8rwwzjrfAcP2GXGut (board "New text for the other long steps"). The engine part (fonts, `title`, hand-card order, hand cards may scroll) is built in rhope-ops/RADE and released as engine-v9 (28877e7; rows "Runner polish pass" and "Hand cards may scroll" in its docs/DECISIONS.md). Not applied to R27 r1: R27 is open on the gov device.

## To do in the R28 round build (scripts/paste_bundles.json, tests/check_guide_text.py)

1. Every step gets a `title` (plain words, no T<NN>, r<N>, F<NN>, R<NN> codes); `name` keeps the code for results.
2. A hand card has 10 numbered lines or fewer; a longer task becomes 2 or 3 steps, each note says "Part k of n" and its time.
   Each guide line has 100 characters or fewer (RADE decision of 17 Nov 26; engine-v9 warns above 100 and above 10 numbered lines).
3. Drop "Return to the RADE window" and "Select Done ..." lines: the engine prints a fixed closing line.
4. Line 1 of a card with an address: `Select "Open in browser" above.`
5. Every screen name in "quotes", every time; one action per line; a fallback starts with "If" and holds one action.
6. No codes or build words in a note or title ("slice", "probe solution", "estimate"); a time is "about N minutes", once, in the note.
7. No line about what is not on the screen; no unnumbered line between numbered lines.
8. US spelling (gray, license). One Done button: `doneText` is not set (the engine default "Done").
9. Seen: T18 and T21 share the same 8 opening lines; REC (agent): one shared "import a solution" part in the bundle source.

check_guide_text.py adds checks for 1, 2, 7 (unnumbered line in the list), 8 (doneText) and "Grey"; the fresh reader checks the rest.
