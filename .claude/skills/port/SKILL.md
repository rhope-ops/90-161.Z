---
name: port
description: Use when the PFM asks to bring a change of the archimedes_lever kit (a pull request, a decision, a script or a skill) into this repo, and when scripts/drift.py of the kit shows that this repo's kit sections differ. This repo never syncs (AGENTS.md "Project rules", no kit sync); gives the port steps, the approval of rule lines, and the before and after proof.
---

# Port a kit change to a project

A port brings a kit change by hand, so this repo keeps its own text. Run it in this repo, with the kit cloned in a scratch folder (`<kit>` below). Never run the kit's `scripts/sync_baseline.py` here: it replaces project guards and rules (AGENTS.md "Project rules", no kit sync, the PFM 2026-11-15).

## Before you start

- `python3 <kit>/scripts/drift.py --project .` shows each kit section and file as same, changed or missing. Use it to plan and to prove the result, never to choose a sync.
- The last ported kit commit is in the newest "Kit port" row of docs/DECISIONS.md; port only what the kit changed after it.
- A kit file that this repo's file matches at that commit can be copied; otherwise do a 3-way merge (`git merge-file <ours> <kit at the last port> <kit now>`) and resolve each conflict by hand.

## Steps

1. Read the kit change: its rows in the kit's docs/DECISIONS.md (date, scope), the pull request diff and its "Not in this pull request" part. A kit decision whose scope does not name this project needs the PFM's approval here first. A limit of the project wins over the kit change (for example a frozen spec, a protected file list or its own delivery rule): adapt or skip that part and name the limit in the record (step 8).
2. Measure before, in the project: `python3 scripts/bloat_check.py --brief` and `--rules`, the `TIME` line of `scripts/check.sh`, and the drift report.
3. Plan each kit file: copy as is, merge by hand, or skip (with the reason). Keep the project's header values, "Commands", owner word (here "the PFM"), "Project rules" and its own tests. A file the kit moved (`MOVED_FILES` in the kit's `scripts/sync_baseline.py`) is deleted in the project only after its text is in the new place.
4. Rule lines: each changed line in a kit section of AGENTS.md and each new "Project rules" line is a rule change. Show the exact texts to the PFM in one dialog and wait for approval of each (`.claude/skills/rule-change/SKILL.md`). Then run the conflict check of that skill.
5. Copy and merge on a branch. This repo has no `.baseline` (only a sync writes one); do not add one. Never copy the kit's docs/DECISIONS.md, docs/LOG.md or reviews: the project has its own.
6. Project tests: when the port brings the two check lanes, make `scripts/check.local.sh` accept `--fast` (check each changed file in full, and that generated files are not stale). Profile before you change a test (`.claude/skills/efficiency/SKILL.md`); keep the same tests and the same PASS lines.
7. Prove it: the full lane passes; give the numbers of step 2 before and after, and the drift report after.
8. Record: a row in the project's docs/DECISIONS.md ("ported kit pull request N, date; skipped: ..."), and a project log row when it is a milestone.
9. Deliver as a pull request (`.claude/skills/deliver/SKILL.md`). A port changes guard files, so it needs the fresh review; the PFM merges.
