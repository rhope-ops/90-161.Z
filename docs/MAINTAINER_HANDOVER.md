# Administrator handover

This page is for the person who takes over this repository. It names where each thing lives and gives the steps for the 4 common tasks. Written 2026-11-23 (fleet v2 Stage 3A).

## Where things live

| Thing | File |
|---|---|
| Account values (GitHub owner, repository, branch, Teams channel) | `site.config.json` |
| The RADE engine version and its file hashes | `scripts/rade.lock.json` |
| The round definitions | `scripts/paste_bundles.json` |
| The task page text | `go.md` (the page `index.html` and the README "Current tasks" part show it) |
| The shared PowerShell blocks of the task scripts | `scripts/gov/src/*.ps1` |
| The order of all generators | `scripts/rebuild_all.py` |
| Decisions | `docs/DECISIONS.md` |
| Security | `SECURITY.md`, `docs/threat-model.md`, `COMPLIANCE.md` |

Never edit a generated file. Edit its source, then rebuild (task 2).

## Task 1: Run all checks

1. In a terminal, in the repository folder, do these actions:
   1. Type `bash scripts/check.sh`.
   2. Press **Enter**.

   You see one line for each check. Wait until the last line shows.
2. In the terminal, read the last line. You see `CHECK PASS` or `CHECK FAIL`. If the line is `CHECK PASS`, the task is complete. Otherwise, go on.
3. In the terminal, read each line that starts with `FAIL`. You see the name of each failed check. Go on.
4. In a text editor, correct each cause in its source file. You see the changed source files. Go on.
5. In the terminal, do these actions:
   1. Type `bash scripts/check.sh`.
   2. Press **Enter**.

   You see one line for each check. Wait until `CHECK PASS` shows. The task is complete.

## Task 2: Rebuild the generated files

1. In a terminal, in the repository folder, do these actions:
   1. Type `python3 scripts/rebuild_all.py`.
   2. Press **Enter**.

   You see one line for each generator. Wait until the line `REBUILD CHECK` shows.
2. In the terminal, read the line `REBUILD CHECK`. You see `fail=0` or another number. If you see another number, correct the source that each `FAIL` line names. Go on.
3. In the terminal, do these actions:
   1. Type `git status --short`.
   2. Press **Enter**.

   You see the list of changed files. Go on.
4. In the terminal, commit the changed files on a new branch. You see the new commit. Go on.
5. On GitHub, open a pull request for the branch. You see the pull request page. The task is complete.

## Task 3: Move to a new RADE engine release

1. In a web browser, on the RADE repository page **Releases**, read the newest release name. You see a name like `engine-v36`. Write down the name.
2. In a terminal, in the repository folder, type `python3 scripts/bump_lock.py engine-v36` with the name that you wrote down. You see the command in the terminal. Go on.
3. In the terminal, press **Enter**. You see the lines `LOCK` and `TRACE`, then the check lines. Wait until a line `BUMP PASS` or a line `FAIL` shows. Do not stop the command until then.
4. In the terminal, read the last line. You see `BUMP PASS` or a line `FAIL`. If you see `BUMP PASS`, commit the changed files on a new branch. Go on.
5. If the last line starts with `FAIL`, the old lock is back. Correct the cause that the line names, and type the bump command again. You see `BUMP PASS`. Go on.
6. On GitHub, open a pull request for the branch. You see the pull request page. The task is complete.

Offline form: a computer with no access to github.com uses a RADE clone that has the release tag. Put the file `rade-engine.lock.json` from the release page in the top folder of the clone. Then type `RADE_LOCAL_DIR=/path/to/RADE` before the bump command, with your clone folder.

## Task 4: Change an account value

1. In a text editor, open `site.config.json`. You see the keys `owner`, `repo`, `branch` and `teamsChannel`. Go on.
2. In the editor, type the new value between the quotes of its key. You see the new value. Go on.

   The value can have only letters, numbers, `.`, `_` and `-`.
3. In the editor, save the file. You see the saved file. Go on.

   The old address is `raw.githubusercontent.com/<old owner>/<old repo>/<old branch>/`, with the old values. Do not type `https://` in front of it. The new address has the new value in its place. Today the address is `raw.githubusercontent.com/rhope-ops/90-161.Z/main/`.
4. For a new owner, repo or branch, open `go.md` and do these actions:
   1. Replace all the old address with the new address.
   2. Save the file.

   You see the new raw links. Go on.
5. In a terminal, in the repository folder, do these actions:
   1. Type `python3 scripts/rebuild_all.py`.
   2. Press **Enter**.

   You see the line `REBUILD CHECK` with `fail=0`. Go on.
6. In the terminal, do these actions:
   1. Type `node tests/check_go_page.js`.
   2. Press **Enter**.

   You see `GO PAGE PASS` on the last line. If you see `GO PAGE FAIL`, read the lines with `FAIL`. Correct the address or the value in `site.config.json` or `go.md`. Go on.
7. In the terminal, do these actions:
   1. Type `bash scripts/check.sh`.
   2. Press **Enter**.

   Wait until the line `CHECK PASS` shows. The task is complete.

The rebuild writes the page CSP source from `site.config.json` (`scripts/build_go_page.py`). The go.md links keep the address as typed, so `tests/check_go_page.js` fails when a link differs. If you change `owner`, the github.io page address changes too. The Python scripts read them through `scripts/site_config.py`. The Teams channel name on the page comes from `README.md`: change it there too, then rebuild. The round definitions `scripts/paste_bundles.json` keep their own "repo" and "home" values: change them too, then rebuild.
