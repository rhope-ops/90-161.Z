# Code standard: 90-161.Z

Decided by the PFM, 2026-11-17 (docs/DECISIONS.md): all code in this repo is modular, clearly commented and human inspectable, and stays so as work continues. This file is the spec. [tests/check_code_standard.py](../tests/check_code_standard.py) enforces the rules marked **(check)**; the fresh reviewer of each pull request checks the rules marked **(review)**.

Why: a person must be able to read any script and know what it does before they run it on the gov device. A pasted round bundle runs with that person's rights, so its code must be as easy to inspect as its text.

## Scope

- Every file git tracks with the extension `.py`, `.ps1`, `.psm1`, `.js`, `.mjs`, `.cjs` or `.sh`, and every file with no extension whose first line is a shell or Python shebang (for example scripts/git-hooks/pre-push): the gov-device scripts, the build scripts (Python and JavaScript), the tests and the kit files. The RADE engine code lives in rhope-ops/RADE and has its own copy of this standard.
- Generated files get rule C6 only (their source gets the other rules). The list is `config.generated` in [tests/code-standard-baseline.json](../tests/code-standard-baseline.json).
- Kit files (from archimedes_lever: scripts/pii_guard.py, bloat_check.py, timeline.py, log_check.py, stop_check.py, worker_guard.py, first_use_check.py, session_checkin.sh, check.sh, git-hooks/pre-push) are checked the same way. Their debt is fixed in the kit first, then ported (AGENTS.md "Project rules", no kit sync). A kit port that adds debt waits until the kit fixes it, or the PFM decides.

## Rules

| No. | Rule | How |
|---|---|---|
| C1 | Each source file starts with a header comment: what the file is for, its inputs, its outputs, how to run it, and its run target (for example Windows PowerShell 5.1). Python: the module docstring. PowerShell: comment-based help (`<# .SYNOPSIS ... #>`) or `#` lines. | **(check)** at least 60 characters; **(review)** the content |
| C2 | Each function has a comment that says what it does, what it takes and what it gives back. Python: a docstring, or a `#` comment directly above the `def` or before its first statement. PowerShell: comment-based help, or a `#` line directly above `function` (the file header and a divider line such as `# ----` do not count; leave a blank line between the header and the first function's comment) (or above a script block kept in a variable, such as `$ui.Say = { ... }`). | **(check)** present; **(review)** true and useful |
| C3 | A function is at most 60 lines long. A longer job is split into named steps, each its own function. A script block passed to a call (for example `$button.Add_Click({ ... })`) counts as a function for its length. | **(check)** |
| C4 | A file is at most 600 lines long. A larger program is split into modules, one concern each (for example: checks, steps, window, results). | **(check)** |
| C5 | One function lives in one file. Code that must also run alone (a task script, a bundle part) gets a generated copy between marker lines `# >>> <name>: generated from <source> ...` and `# <<< <name>`; the check skips that block and measures the source. | **(check)** same body twice fails |
| C6 | A generated file says `GENERATED` in its first 15 lines and names its source and the command that builds it. A generated bundle starts with a table of contents, and each part has a banner with its source file and SHA-256. Hand edits: AGENTS.md "Checks". | **(check)** banner; **(review)** table of contents |
| C7 | Names say what a thing is or does: PowerShell `Verb-Noun` with an approved verb; Python `snake_case`; no one-letter names except loop counters and short lambdas. | **(review)** |
| C8 | A comment says why or what, in plain English, and is true. A decision in a comment names who decided and the date (for example "the PFM, 2026-11-17"). Remove a comment the code makes obsolete in the same change. | **(review)** |
| C9 | No magic values: a fixed number, path, address or limit is a named constant or a manifest value, with a comment that says where it comes from. | **(review)** |
| C10 | Gov-device PowerShell runs on Windows PowerShell 5.1 (AGENTS.md "Commands"; `scripts/lint.sh` checks the 5.1 syntax). PowerShell lives in `.ps1` files, never in a Python or JavaScript string, so the PowerShell parser, the lint and this check can read it. Shared task code lives in `scripts/gov/src/` and `scripts/build_task_scripts.py` copies it between markers (C5). | **(check)** each PowerShell and Python file parses; **(review)** the 5.1 target |

## The ratchet

- [tests/code-standard-baseline.json](../tests/code-standard-baseline.json) `debt` lists every violation that existed on 2026-11-17. A violation not in that list fails the check. A listed function or file that grows fails.
- A listed item that is fixed also fails, until the same change lowers the baseline: `python3 tests/check_code_standard.py --update` (it refuses when there is new debt). So the list can only shrink.
- Never add an item to the baseline by hand, never raise a cap, and never add a path to `exclude` to make the check pass (AGENTS.md "Checks"). The check enforces this: it compares the baseline with the one on the merge base with origin/main, and an added item, a raised value or a changed `config` fails. A change to the caps or the scope is the PFM's decision: the same change adds a docs/DECISIONS.md row that names tests/code-standard-baseline.json.
- New and changed code meets every rule. When a change touches a function that is in the debt list, fix that function in the same change if it is small (except kit files: see Scope); otherwise leave it no worse.

## Commands

- Check: `python3 tests/check_code_standard.py` (scripts/check.local.sh runs it in both lanes). Pass = last line `CODE-STANDARD pass`.
- Every measurement: `python3 tests/check_code_standard.py --report`.
- Lower the baseline after a fix: `python3 tests/check_code_standard.py --update`.
- Prove the check itself: `python3 tests/check_code_standard.py --self-test`.

The same check file runs in rhope-ops/RADE, where a change to it is made first; a session of this repo ports it here by pull request.
