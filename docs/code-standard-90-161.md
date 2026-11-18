# Code standard: what 90-161.Z adds

Decided by the PFM, 2026-11-17 (docs/DECISIONS.md): all code in this repo is modular, clearly commented and human inspectable, and stays so as work continues. Why: a person must be able to read any script and know what it does before they run it on the gov device; a pasted round bundle runs with that person's rights.

The core rules and the check are the kit's: [docs/code-standard.md](code-standard.md) (a kit file; a sync replaces it). The extras are RADE's: [the RADE code standard](https://github.com/rhope-ops/RADE/blob/main/docs/code-standard.md) (after RADE takes kit 2026.11.20.1, its extras move to RADE's docs/code-standard-rade.md). This file holds only what is different for this repo.

## This repo

- Check: `python3 scripts/code_standard.py` (kit file; `scripts/check.sh` runs it in both lanes). Pass = last line `CODE-STANDARD pass (... gate code_standard_gate.py active)`.
- This repo's own gate: [scripts/code_standard_gate.py](../scripts/code_standard_gate.py) (the kit's extension point; self-test `--test`, run by `scripts/check.sh`). It adds the strict C1 safety form (`Network:`, `Writes:` and `Credentials:`, each at the start of a header line with a value; applied at `code-c1-safety: on`), the line cap (a file's longest line; present longer lines are listed debt), the owner-row test for a change of the settings or the debt (a new docs/DECISIONS.md row that names `.check`, with the PFM alone in its By cell, in a change that leaves older rows as they were), and the refusal of debt for a file that is new in a change. Same rules as rhope-ops/RADE.
- Settings: the `code-` lines of [.check](../.check): `code-c2: full` (full docs for each function longer than 10 lines), `code-c1-safety: on`, `code-max-line-chars: 200`, and `code-generated: scripts/gov/paste/*.ps1` (the round bundles; their sources get the rules). The debt list: `.check.state.json` (only shrinks).
- Shared task code lives in `scripts/gov/src/`; `scripts/build_task_scripts.py` copies it into each task script between `# >>> <name>: generated from <source>` and `# <<< <name>` markers (kit rule C5), so it is measured once, in its source.
- Gov-device PowerShell runs on Windows PowerShell 5.1 (AGENTS.md "Commands"; `scripts/lint.sh` checks the 5.1 syntax). PowerShell lives in `.ps1` files, never in a Python or JavaScript string, so the parser, the lint and the check can read it (RADE extra X2 applies to this repo's PowerShell too).
- Kit files (the list: `.check.lock`): a fix to one is made in the kit (AGENTS.md "Kit files"). Their debt here goes after the kit fixes its last 2 items and `--update` runs (docs/reviews/2026-11-18-kit-sync.md "Open").
- Refactor plan for the debt: docs/phases.md "Code standard refactor".
