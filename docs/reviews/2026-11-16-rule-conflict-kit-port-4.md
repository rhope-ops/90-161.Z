# Rule conflict check: 2026-11-16, the hook clause names its gaps

Fresh-context check of the rule lines changed against origin/main (`.claude/skills/rule-change/SKILL.md`, "Conflict check"). Reviewer: `reviewer` subagent, model Opus (the author's tier), given only the changed lines, AGENTS.md and the decision record.

## Changed line

- `-` "... and a PreToolUse hook (...) checks each outgoing tool call."
- `+` "... and a PreToolUse hook (`pii_guard.py --hook`, `.claude/settings.json`) checks the outgoing tool calls it names (list and gaps: `.claude/skills/personal-data/SKILL.md`)." The owner (kit decision; here: the PFM) approved this exact text on 2026-11-16, because the old clause claimed more than the hook covers (claude.ai chats, `curl`/`gh` in Bash and Google Calendar are not covered).

## Result

No conflict. Findings, both from the change: (1) the decision record still quoted the old sentence: a new row records the new text; (2) the bullet links the skill twice (in the new clause and in "When it blocks"): an overlap, kept because the approved text includes the link.

rule-conflict-check: 6e18068b66c6
