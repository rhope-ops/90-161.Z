# Rule conflict check: kit port 2 (kit c523a21), 2026-11-16

Reviewer: fresh `reviewer` subagent, model tier Opus (the author's tier), given only the changed lines, AGENTS.md, docs/DECISIONS.md and the brief of `.claude/skills/rule-change/SKILL.md`.

## Changed lines (approved by the PFM, 2026-11-16, exact text)

- Handoff: "... put detailed evidence in docs/reviews/." + " Steps: `.claude/skills/handoff/SKILL.md`."
- Bloat: "one line each where possible (every line costs tokens on every task and can lower adherence)." -> "one line per rule (every line costs tokens on every task and can lower adherence); a rule that needs more lines is a procedure."
- `scripts/bloat_check.py` bullet: + " A run slower than its baseline: `.claude/skills/efficiency/SKILL.md`."

## Findings (no MAJOR, no conflict between two rules)

| # | Severity | Finding | Action |
|---|---|---|---|
| 1 | MINOR | efficiency skill cited "(the PFM, 2026-11-16)" for "warn only"; no DECISIONS row. Cause: the port renamed "the owner" of a kit decision. | Fixed: cites the kit decision. |
| 2 | MINOR | "one line per rule" vs "Order of authority" (a ranked list of 4 lines and a paragraph): an audit could move it into a skill. | Open: to the PFM (REC: keep; the list is one ranking that bloat_check does not count as rules). |
| 3 | MINOR | Handoff line "The current request overrides an older handoff." repeats Order of authority (item 1 above item 4); the handoff skill says it a third time. Sentence not changed by this port. | Open: to the PFM (REC: next audit). |
| 4 | NIT | "Start of session" and the handoff skill both say read docs/NEXT_PROMPT.md. | Noted. |
| 5 | NIT | +25% limit and "propose the audit" agree with DECISIONS rows of 2026-11-13. | OK. |

rule-conflict-check: 5a5b94a0763f
Skipped (kit port 2): rule-tests scenarios 11-15 (older than ceac0e8), docs/FILES.md, bootstrap.sh, sync_baseline.py (not in this repo).
