# Dependabot fixes and RADE lock engine-v17 (2026-11-18)

## What merged
- PR 156 (merge a7d54ea): Pillow 12.3.0 -> 13.0.0 (43 alerts) and npm override image-size 2.0.3 (2 alerts). Build/test only; nothing on the gov device changes. The alert count after the rescan is not checked yet.
- PR 157 (merge dd06091): RADE lock to engine-v17 (RADE fbaa1ec, serial 13) by scripts/bump_lock.py; bundles R29a and R29b raised r6 -> r7.
- T22 window script (scripts/gov/90161Z-T22-pfm-window-r3.ps1) shrunk by 16 hand-written lines (the PFM: shrink by hand), because engine-v17 adds 15 generated lines to its rade-ui block and the code-standard ratchet lets the file only shrink. Debt baseline lowered with `code_standard.py --update` (file 1402 -> 1401).

## Not proven
- The C# `Gfx.Begin` helper in T22 (the shared start of each OnPaint). Nothing here or in the ps51 job compiles the WinForms C#. First proof: the R29b r7 round on the gov device. If it fails to compile, the T22 window does not open.

## Risk: T22 r4
- The planned T22 r4 (defects V2-V4, R30) renames the file. The code-standard gate keys debt by file name, and debt for a file that is new in a change is refused (scripts/code_standard_gate.py, new_debt_refusal). At about 1,400 lines (cap 600), an r4 rename fails the gate. Confidence: medium (from the gate's code; not tested).
- Options: bring T22 under 600 lines before the rename (split per the S1 code-standard refactor, docs/phases.md); or a kit change so a rename keeps its debt; or keep -r3 if the PFM rules the fix needs no new revision.

## Bump with a shrink
- When a bump also lowers debt, `bump_lock.py` fails its own check on the FIXED items and restores. This time `bump()` ran with `code_standard.py --update` before its unchanged checks (driver kept outside the repo). A future fix in bump_lock.py could run `--update` itself.

## Update 2026-11-18 evening
- RADE released engine-v18 after PR 157 merged; the "RADE engine is behind" test fails on main again (lock engine-v17). A move to v18 is the PFM's call (round skill: the lock moves only on the PFM's request).
