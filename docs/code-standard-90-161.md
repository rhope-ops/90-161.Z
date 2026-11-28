# Code standard: what 90-161.Z adds

Decided by the Administrator, 2026-11-17 (docs/DECISIONS.md): all code in this repo is modular, clearly commented and human inspectable, and stays so as work continues. Why: a person must be able to read any script and know what it does before they run it on the gov device; a pasted round bundle runs with that person's rights.

The core rules and the check are the kit's: [docs/code-standard.md](code-standard.md) (a kit file; a sync replaces it). The extras are RADE's: [the RADE code standard](https://github.com/rhope-ops/RADE/blob/main/docs/code-standard.md) (after RADE takes kit 2026.11.20.1, its extras move to RADE's docs/code-standard-rade.md). This file holds only what is different for this repo.

## This repo

- Check: `python3 scripts/code_standard.py` (kit file; `scripts/check.sh` runs it in both lanes). Pass = last line `CODE-STANDARD pass`.
- The strict gate (kit 11.0.0, 2026-11-23): `code-strict-gate: on` in `.check` runs the kit's `scripts/code_standard_strict.py`. It replaces this repo's former `scripts/code_standard_gate.py` (the same rules, folded into the kit: fleet v2 plan B.4). Hand-written files: 450 lines; the pasted T22 and T24 task scripts (`code-paste:`) keep 600.
- Settings: the `code-` lines of [.check](../.check): `code-c2: full` (full docs for each function longer than 10 lines), `code-c1-safety: on`, `code-max-line-chars: 200`, and `code-generated: scripts/gov/paste/*.ps1` (the round bundles; their sources get the rules). The debt list: `.check.state.json` (only shrinks).
- Shared task code lives in `scripts/gov/src/`; `scripts/build_task_scripts.py` copies it into each task script between `# >>> <name>: generated from <source>` and `# <<< <name>` markers (kit rule C5), so it is measured once, in its source.
- Gov-device PowerShell runs on Windows PowerShell 5.1 (AGENTS.md "Commands"; `scripts/lint.sh` checks the 5.1 syntax). PowerShell lives in `.ps1` files, never in a Python or JavaScript string, so the parser, the lint and the check can read it (RADE extra X2 applies to this repo's PowerShell too).
- Kit files (the list: `.check.lock`): a fix to one is made in the kit (AGENTS.md "Kit files"). They meet the strict forms (kit 2026.11.20.2), so they hold no debt here.
- Refactor plan for the debt: docs/phases.md "Code standard refactor".
