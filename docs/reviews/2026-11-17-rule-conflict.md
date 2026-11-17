# Rule conflict check: code standard line, 2026-11-17

Changed line (`python3 scripts/bloat_check.py --rules`):

+ Code standard (the PFM, 2026-11-17): all code is modular, clearly commented and human inspectable, per docs/code-standard.md; tests/check_code_standard.py enforces it, and its baseline may only shrink.

Reviewer: fresh `reviewer` subagent, Opus tier, given only the changed line, AGENTS.md, docs/DECISIONS.md, docs/code-standard.md and the brief of `.claude/skills/rule-change/SKILL.md`. No MAJOR finding.

1. Conflict: a kit port that adds debt (No kit sync: port kit fixes) vs the shrink-only baseline. Fixed in docs/code-standard.md "Scope": such a port waits until the kit fixes it, or the PFM decides.
2. Overlap: "its baseline may only shrink" and AGENTS.md "Checks" (no exemptions). Open: the line was approved word for word; a change needs the PFM's approval of new text.
3. Rule vs spec: the check enforces only the (check) rules; the fresh review covers the rest. Open: same as 2.
Notes: scripts/git-hooks/pre-push has no extension, so the check does not read it (Scope now says so). The rule that a change to the check is made first in rhope-ops/RADE is in docs/code-standard.md, not in the decision row (one place per fact).

rule-conflict-check: d3b38b607ef3
