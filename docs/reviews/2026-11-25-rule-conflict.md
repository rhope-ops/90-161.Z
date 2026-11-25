# Rule conflict check: Next-step link (2026-11-25)

Changed line (project rule, not a hard rule; `python3 scripts/bloat_check.py --rules` against origin/main):

- Removed: "Next-step link (2026-11-15): to open a round or task, link https://rhope-ops.github.io/RADE, never go.md."
- Added: "Next-step link (2026-11-25): to open a round or task, link https://github.com/rhope-ops/90-161.Z (the README); never a github.io page or a .ps1 file."

Approval: the PFM approved the exact added text in the question dialog on 2026-11-25 ("Approve text").

Check: a project rule changed, so this is the short record of the rule-change skill, "Conflict check", step 4. Reviewer: the author session (step 1 of "Steps": a search of AGENTS.md and docs/DECISIONS.md for github.io, "Next-step" and "Next:" lines).

Findings:

- AGENTS.md: no other line names github.io or a next-step link. No conflict.
- docs/DECISIONS.md, rows of 2026-11-15 ("Turn summaries and Next lines link the RADE page https://rhope-ops.github.io/RADE") and 2026-11-21 (README with "Open as .txt" and "Copy script" links): the new row of 2026-11-25 names both as replaced. No open conflict.
- `.claude/skills/round/SKILL.md`, "5. go.md task" (bookmark) and "6. Release order" step 9: changed in the same pull request to github.com/rhope-ops/90-161.Z. No open conflict.
- Rule lint WARN "untested": `scripts/build_readme.py` enforces the README part (it fails on a .ps1 or github.io URL); the rule text does not name it because the PFM approved the exact text. MINOR, recorded.

rule-conflict-check: 799a021d4cdf

# Rule conflict check: Screen names (2026-11-25)

Changed line (project rule, not a hard rule; `python3 scripts/bloat_check.py --rules` against origin/main):

- Added: "Screen names (the PFM, 2026-11-25): a step names only screen text from its round's bundle, in the code's card order (tests/check_screen_names.py; the round skill's fresh reader)."

Approval: the PFM approved a longer text, then the shorter exact text above in the question dialog on 2026-11-25 ("Shorter text"), because the longer line put the session load over its cap (~5,571 > 5,500 tokens).

Check: a project rule changed, so this is the short record of the rule-change skill, "Conflict check", step 4. Reviewer: the author session (step 1 of "Steps": a search of AGENTS.md and docs/DECISIONS.md for "screen name", "screen text" and the go.md usability bar).

Findings:

- AGENTS.md "What people see" (plain English; the round skill's usability bar): the new line adds where names come from; it gives no other order. No conflict.
- AGENTS.md "Hard rules", "Instructions people follow" ("names the exact thing on the screen"): the new line names the source of that exact thing (the bundle code). No conflict.
- docs/DECISIONS.md: no row names screen names. No conflict.
- `.claude/skills/round/SKILL.md` "5. go.md task": changed in the same pull request (the steps of the rule; the description lost its list of sections to stay under the session-load cap).

rule-conflict-check: 6da16f6a29ec
