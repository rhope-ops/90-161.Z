# Code standard

Decided by the Maintainer, 2026-11-17 (docs/DECISIONS.md): all code is lean, modular, commented and human-editable, and stays so as work continues. Why: a person must be able to read any script and know what it does before they run it. [scripts/code_standard.py](../scripts/code_standard.py) enforces the rules marked **(check)**; the fresh reviewer of each pull request checks the rules marked **(review)**.

The kit owns this file and the check. A project gets both by sync. It sets its own caps, scope and opt-in rules (for example full docs per function) with `code-` lines in its own `.check` (the keys: the header of [scripts/check_settings.py](../scripts/check_settings.py)), keeps stricter rules of its own in its own gate file ("A project's own gate" below) and their text in a doc of its own that links here, never in a copy of the check or of this file.

## Scope

- Every file git tracks with the extension `.py`, `.ps1`, `.psm1`, `.js`, `.mjs`, `.cjs` or `.sh`, and every file with no extension whose first line is a shell or Python shebang (for example scripts/git-hooks/pre-push).
- Shell files also get shellcheck (scripts/check.sh, on the same file list: `scripts/code_standard.py --shell-files`). Its findings are WARN lines and never fail a check; a missing shellcheck is a SKIP line. Install: `pip install shellcheck-py==0.9.0.6` (a wheel with the 0.9.0 binary; it needs no root, and the CI step installs it the same way).
- Generated files get rule C6 only (their source gets the other rules). The list is the `code-generated:` lines in [.check](../.check). For Python, ruff and pylint (scripts/check.sh) check parse, line length and file size on the same file list: no excluded or generated file; a file with a generated block is left out of the linters' line check only (they cannot skip a block), and the strict gate measures its hand-written lines instead, as for other languages.
- A script a person pastes into another tool (one file is one paste) gets every rule, with its own C4 cap. The list is the `code-paste:` lines in `.check`.

## Rules

| No. | Rule | How |
|---|---|---|
| C1 | Each source file starts with a header comment: what the file is for, its inputs, its outputs and how to run it. Python: the module docstring. A check entry point (a script that `scripts/check.sh`, a hook or a workflow names) also has a line `Prevents: <the defect it prevents>` (AUD-1; **(check)** a FAIL in the kit, a WARN in a project until its debt is 0). | **(check)** at least 60 characters; **(review)** the content |
| C1 safety | Opt-in: a project sets the line `code-c1-safety: on` in its `.check`. Then each source file's header also has the three labels `Network:` (the hosts it reaches, or "none"), `Writes:` (the files, lists or sites it changes, or "none") and `Credentials:` (what it asks for and how, or "none"), so a reviewer finds them before a run. The line `code-c1-safety: strict` asks for a stricter form that the project's own gate defines (for example: each label starts a header line and has a value on that line). | **(check)** the three labels; the strict form: the project's gate; **(review)** true |
| C2 | Each function has a comment that says what it does. One line is enough; full parameter docs are not required. Python: a docstring, or a `#` line directly above the `def` or before its first statement. Shell and JS: a comment line directly above. The file header and a divider line (`# ----`) do not count. | **(check)** present; **(review)** true and useful |
| C3 | A function is at most 60 lines long. A longer job is split into named steps, each its own function. | **(check)** |
| C4 | A file is at most 450 lines long (`code-max-file-lines`). A larger program is split into modules, one concern each. A `code-paste:` file is at most 600 lines long (`code-max-file-lines-paste`); a generated file has no line cap. Split along a seam you can name (one job per part), never only to move the number. | **(check)** warns only (decision 1 = A, docs/reviews/2026-11-23-tool-retirement-plan.md); for Python, pylint (C0302) warns |
| C5 | One function lives in one file. A copy that must also run alone is generated, between marker lines `# >>> <name>: generated from <source> ...` and `# <<< <name>`. | **(check)** same body twice fails |
| C6 | A generated file says `GENERATED` in its first 15 lines and names its source and the command that builds it. | **(check)** |
| C7 | Names say what a thing is or does: Python `snake_case`; PowerShell `Verb-Noun`; no one-letter names except loop counters and short lambdas. | **(review)** |
| C8 | A comment says why or what, in plain English, and is true. Remove a comment the code makes obsolete in the same change. | **(review)** |
| C9 | No magic values: a fixed number, path, address or limit is a named constant with a comment that says where it comes from. | **(review)** |
| C10 | Each Python and PowerShell file parses. | **(check)**: Python by ruff and pylint (`ruff.toml`, `.pylintrc`, run by `scripts/check.sh`), or by the kit's check when ruff or pylint is not installed; PowerShell by the kit's check |
| C2 full | Opt-in: a project sets the line `code-c2: full` in its `.check`. Then each function longer than 10 lines also documents each parameter and its return value, in the form its language's own help tools read. Python: a docstring with an `Args:` section that names each parameter (not `self` or `cls`) and a `Returns:` section when it returns a value (PEP 257). PowerShell: comment-based help (.SYNOPSIS or .DESCRIPTION) with one `.PARAMETER` per parameter, placed where `Get-Help` finds it (about_Comment_Based_Help). JavaScript: a `/** */` JSDoc block directly above, with one `@param` per parameter and `@returns` when it returns a value. Shell: the C2 comment only. | **(check)** [scripts/code_standard_docs.py](../scripts/code_standard_docs.py); **(review)** true and useful |
| C11 | Lean: no dead code, no unused option, no second way to do the same job; prefer the standard library over a new dependency. A change does not make a check run slower than its baseline (.claude/skills/audit/SKILL.md "A slow run"). | **(review)**; time: `scripts/check.sh` TIME line |

## The ratchet

- `.check.state.json` (`code_standard`: `debt`) lists the violations that existed when a repo adopted the standard (empty in the kit). A violation not in that list fails; a listed function or file that grows fails.
- A listed item that is fixed also fails until the same change lowers the baseline (`--update`, which refuses new debt). So the list can only shrink.
- A rule turned on later (for example `code-c2: full`): `--adopt` lists its current debt once, in the same change as a docs/DECISIONS.md row that names `.check`. The comparison with main accepts that list only when the option was off on main, so an option that is already on cannot be adopted again. A stricter level of a rule that is on (`code-c1-safety: on` to `strict`) is adopted the same way, while its level is above the one on main. It never touches the debt of a rule the ratchet already holds.
- Never add an item to the baseline by hand, raise a cap or add an `exclude` to pass (AGENTS.md "Guards and checks"). The check compares the baseline and the `code-` lines of `.check` with those on the merge base with origin/main; a cap or scope change (a `code-` line added, removed or changed) needs a docs/DECISIONS.md row that names `.check`. A `code-` key the check does not know, or a value that is not valid, fails the check.

## A project's own gate

- The extension point for a project that wants more than the rules above: a file `scripts/code_standard_gate.py` of its own, next to the check. The kit has no such file. When it exists, the check loads it and calls its five entry points (their exact form: the header of [scripts/code_standard.py](../scripts/code_standard.py)): more debt kinds (`RULES`), more opt-in kinds (`OPT_IN`), per-file rules (`file_rules`), its own test for "the Maintainer decided this change" (`decided`), and a refusal that no decision lifts (`new_debt_refusal`, for example debt for a file that is new).
- Two settings are a gate's to enforce: `code-max-line-chars: <number>` (the longest line of a hand-written file; for a Python file, ruff and pylint check it with the same cap, scripts/check.sh; when ruff or pylint is not installed, the gate measures it and skips the lines ruff's E501 lets pass: `# noqa`, a trailing pragma comment, one word, a line that ends with a URL) and `code-c1-safety: strict`. The kit reads them; with one of them set and no gate file, the check fails.
- A gate that cannot be imported, or lacks an entry point, fails the check: it is never skipped. The result line says when a gate is active.
- The gate proves itself: when the file names `--test`, `scripts/check.sh` runs `python3 scripts/code_standard_gate.py --test` (the full lane always; the fast lane when the gate or the check changed). The self-test of the kit's check runs without the gate.
- The kit files a project gets by sync meet the strict forms that projects run today: three safety label lines, each with a value; full docs for each function longer than 10 lines; lines of at most 200 characters. So a gate finds no debt in a kit file.

## The strict gate

- A project turns on the kit's strict rules with the line `code-strict-gate: on` (default `off`) in its `.check`; the rules are in [scripts/code_standard_strict.py](../scripts/code_standard_strict.py), and no copy of them is kept in a project. They are: the strict C1 safety form (each label starts a header line and has a value; at `code-c1-safety: on` and at `strict`), the C4 line cap `code-max-line-chars` (for shell, PowerShell and JavaScript; Python is for ruff and pylint, or for the gate when one of them is not installed), the Maintainer row (a new docs/DECISIONS.md row that names `.check`, with the Maintainer of the "- Owner:" line of AGENTS.md on the merge base alone in its By cell, in a change that leaves every older row as it was), and the refusal of debt for a file that is new in the change.
- A project's own `scripts/code_standard_gate.py`, when it exists, is loaded instead and the key has no effect. Open choice: the two texts in which three projects differ are the constants `SAFETY_LABEL` and `NEW_DEBT_FORMAT` of the strict file.

## Commands

- Check: `python3 scripts/code_standard.py` (scripts/check.sh runs it in both lanes). Pass = last line `CODE-STANDARD pass`.
- Every measurement: `--report`. Lower the baseline after a fix: `--update`. A project's first baseline: `--init`. A rule just turned on: `--adopt`. Prove the check: `--test`.
