# Code standard: 90-161.Z

Decided by the PFM, 2026-11-17 (docs/DECISIONS.md): all code in this repo is modular, clearly commented and human inspectable, and stays so as work continues.

**The rules live in one place: the RADE code standard, https://github.com/rhope-ops/RADE/blob/main/docs/code-standard.md** (the kit core from rhope-ops/archimedes_lever plus the RADE extras). This file holds only what is different for this repo. Why: a person must be able to read any script and know what it does before they run it on the gov device; a pasted round bundle runs with that person's rights.

## This repo

- Check: `python3 scripts/code_standard.py` (a hand port of the kit file with `code_standard_docs.py`, `code_standard_gate.py` and `code_standard_test.py`; from 17 Nov 26 the four files are RADE's stricter ones, pull request 88 there, which the kit takes at its next port; scripts/check.local.sh runs it and its `--test` in both lanes). Pass = last line `CODE-STANDARD pass`. A change to the check is made in the kit first, then ported here by pull request (AGENTS.md "Project rules", no kit sync).
- Baseline and settings: [.code-standard.json](../.code-standard.json). On: `"c2": "full"` (full docs for each function longer than 10 lines) and `"c1_safety": true` (`Network:`, `Writes:` and `Credentials:`, each at the start of a header line with a value), and the cap `max_line_chars` 200 (a file's longest line; present longer lines are listed debt). Generated: `scripts/gov/paste/*.ps1` (the round bundles; their sources get the rules).
- Shared task code lives in `scripts/gov/src/`; `scripts/build_task_scripts.py` copies it into each task script between `# >>> <name>: generated from <source>` and `# <<< <name>` markers (kit rule C5), so it is measured once, in its source.
- Gov-device PowerShell runs on Windows PowerShell 5.1 (AGENTS.md "Commands"; `scripts/lint.sh` checks the 5.1 syntax). PowerShell lives in `.ps1` files, never in a Python or JavaScript string, so the parser, the lint and the check can read it (RADE extra X2 applies to this repo's PowerShell too).
- Kit files (scripts/pii_guard.py, bloat_check.py, timeline.py, log_check.py, stop_check.py, worker_guard.py, first_use_check.py, session_checkin.sh, check.sh, git-hooks/pre-push): their debt is fixed in the kit first, then ported. A kit port that adds debt waits until the kit fixes it, or the PFM decides.
- Refactor plan for the debt: docs/phases.md "Code standard refactor".
