# Rule conflict check: 2026-11-16, the guard bullet names the hook (kit port of archimedes_lever#27)

Fresh-context check of the rule line that changed against origin/main (`.claude/skills/rule-change/SKILL.md`, "Conflict check").

## Changed line and approval

- `+` "The guard (`scripts/pii_guard.py`, on when `.pii-guard` exists) checks every push and pull request, and a PreToolUse hook (`pii_guard.py --hook`, `.claude/settings.json`) checks each outgoing tool call. When it blocks, ..." (rest unchanged)
- `-` the same bullet without the hook clause.
- The PFM approved this exact first sentence for this project on 2026-11-16 (the kit decision of that day, scope "the kit, then icf-source, RADE, 90-161.Z").

## Port detail

Kit change rhope-ops/archimedes_lever#27 (c523a21..a0b5568), ported by hand: `pii_guard.py --hook` (PreToolUse, outgoing tool calls), `--stdin`, named files that cannot be read or scanned fail, linear EMAIL pattern, per-file commit scan; `.claude/settings.json` hook, allow and ask lists; `bloat_check.py --skills`; personal-data skill "Before you send". The project keeps its own MILHOST pattern unchanged. (A first port commit added lookbehinds to make it linear; a fresh review found that they missed hosts the old pattern found, so that change was taken out. The slow case, one long line of hyphenated labels, is a known limit; the hook fails closed on its 8 s budget.)

## Reviewer

`reviewer` subagent, model set to Opus (the author's tier), given only the changed lines, AGENTS.md and docs/DECISIONS.md.

Result: no conflict, no overlap, no decision row contradicted. Note (not a rule finding): in the DoD tier the hook can block outgoing calls that name military hosts not allowed in `.pii-guard`; only the PFM adds allow entries.

rule-conflict-check: 4a0bf21828ea
