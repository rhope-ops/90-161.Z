# Rule conflict check, 2026-11-20 (No scripts in results)

Reviewer: the `reviewer` subagent, fresh context, Opus tier (same as the author). Input: the changed line below, AGENTS.md, docs/DECISIONS.md and the brief of .claude/skills/rule-change/SKILL.md.

## Changed line (`bloat_check.py --rules`)

```text
  + No scripts in results (the PFM, 2026-11-20; cannot change): a round never collects or sends a .ps1 or other script file; the bundle build fails a collect pattern that can match one.
```

## Findings

| # | Severity | Finding | Action |
|---|---|---|---|
| 1 | MAJOR | DECISIONS row of 2026-11-18 ("Session load: only No reconnaissance is hard") contradicts a second hard project rule. | Fixed: a 2026-11-20 row replaces that part. |
| 2 | MAJOR | Hard-rule marker: AGENTS.md "Hard rules" and the rule-change skill name "(cannot be changed)"; this line and "No reconnaissance" say "cannot change". No scenario in .claude/rule-tests.md (a kit-locked file). | To the PFM before the merge. REC: approve the text with "(cannot be changed)" and the pointer ": scripts/check_collect.py" (also clears MINOR 4 and the "untested" lint). |
| 3 | MINOR | Overlap with "Round results" and round skill step 6 (what a results e-mail holds). | Recorded; the round skill can point at the rule in a later guard-file change. |
| 4 | MINOR | "Lean instructions": the line does not name its check. | With finding 2. |
| 5 | MINOR | DECISIONS row of 2026-11-13 still says "(R6A) zip by e-mail". | Fixed: marked replaced (no zips). |

Checked and OK (reviewer): matches the 2026-11-20 decision row; no conflict with Data boundary, Gov device, Next-step link, Delivery or Code standard; Feedback pictures are .png (allowed); the builder skips the check only when there is no round definition.

rule-conflict-check: b2e844cf7d03
