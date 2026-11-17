# Rule conflict check: 2026-11-17, Code standard line (kit checker port)

Fresh-context check of the rule line changed against origin/main (`.claude/skills/rule-change/SKILL.md`, "Conflict check"). Reviewer: `reviewer` subagent, model Opus (the author's tier), given the old and new lines, AGENTS.md, docs/DECISIONS.md and docs/code-standard.md of this repo and of rhope-ops/RADE.

## Changed line

- `-` "Code standard (the PFM, 2026-11-17): ... per docs/code-standard.md; tests/check_code_standard.py enforces it, and its baseline may only shrink."
- `+` "Code standard (the PFM, 2026-11-17): ... per docs/code-standard.md (the kit core plus the RADE extras, full docs per function included); scripts/code_standard.py enforces it, and its baseline may only shrink." The PFM approved this exact text on 2026-11-17.

## Result

No conflict between two rules. Findings and what was done:
1. The checker, `.code-standard.json` and scripts/check.local.sh had to land with the line: done in the same change.
2. The old 2026-11-17 "Code standard" row: marked "Partly replaced" by the new "Code standard, layered" row.
3. The short docs/code-standard.md must keep this repo's own rules (shared code in scripts/gov/src/ copied between markers, the gov-device 5.1 target, the generated bundles, the kit-file list): kept in its "This repo" section.
4. "Baseline may only shrink" has one owner-gated case: `--adopt` writes the first list of an opt-in rule with a DECISIONS row; refused for a rule already on at main. Overlap with AGENTS.md "Checks", not a conflict.
5. "Full docs per function" is wider than C2 full (functions longer than 10 lines): approved text kept; the RADE standard gives the exact scope.

rule-conflict-check: 0c2811549fb7
