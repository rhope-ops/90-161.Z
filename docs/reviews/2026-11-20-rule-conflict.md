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

## Rerun on the revised text (approved by the PFM, 20 Nov 26)

```text
  + No scripts in results (the PFM, 2026-11-20; cannot be changed): a round never collects or sends a .ps1 or other script file; the bundle build fails a collect pattern that can match one: scripts/check_collect.py.
```

Reviewer: the `reviewer` subagent, fresh context, Opus tier. Findings 2 and 4 of the first check are closed by this text.

| # | Severity | Finding | Action |
|---|---|---|---|
| 1 | MAJOR (existing) | "No reconnaissance" still says "cannot change", not the marker "(cannot be changed)". | To the PFM: a text change of that line needs the PFM's approval. Not caused by this change. |
| 2 | MAJOR (existing) | DECISIONS rows of 2026-11-14 call the DoD365 boundary rule "cannot be changed"; AGENTS.md "Data boundary" has no marker. | To the PFM (mark it, or mark those rows replaced). Not caused by this change. |
| 3 | MINOR | The 2026-11-20 DECISIONS row named "2 hard rules, both marked cannot change". | Fixed: the row now names only this rule and its marker. |
| 4 | MINOR (existing) | "Data boundary" has no written exception for the results e-mail (DECISIONS row of 2026-11-14 allows it during test rounds). | To the PFM with item 2. |
| 5 | MINOR | Overlap with "Round results" and the round skill. | Recorded (as in the first check). |
| 6 | MINOR | This record named only the old hash. | Fixed: this section. |

rule-conflict-check: 354411cc6b38
