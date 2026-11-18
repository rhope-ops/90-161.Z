# Dev setup (agent workspace, Linux)

Cloud sessions (PFM, 2026-11-11): start them on the environment "RADE"; its setup script does steps 1-2 below. On any other environment, do steps 1-2 by hand.

Checks run PowerShell 7 on Linux. They check syntax and PS 5.1 compatibility only. Word COM and PnP cannot run here; those parts are verified on the gov device.

1. pwsh 7.4.6: download `https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-linux-x64.tar.gz`, extract to /opt/pwsh, link /usr/local/bin/pwsh.
2. PSScriptAnalyzer 1.23.0: download `https://github.com/PowerShell/PSScriptAnalyzer/releases/download/1.23.0/PSScriptAnalyzer.1.23.0.nupkg`, unzip to /opt/psmods/PSScriptAnalyzer. (The cloud workspace installs it from GitHub releases.)
3. Run `scripts/lint.sh`. Pass = `LINT files=N findings=0`, exit 0.
4. Run `tests/run.sh` (scripts/check.sh runs it last through scripts/check.local.sh, so the pre-push hook and the pull-request Action run it too). The tests need these packages: Python python-docx 1.2.0, Pillow 12.3.0 and jsonschema (any version); Node docx 9.7.1 (global, with NODE_PATH set to the global folder). The cloud image has them; the Action installs them (.github/workflows/pii-guard.yml).

## RADE engine (PFM, 2026-11-15)

This repo builds and tests alone: no RADE checkout.

- `scripts/rade.lock.json` names the RADE commit, the engine file to run, and every file the engine reads with its SHA-256. The file list comes from a trace of the engine's file opens, not from a search.
- `python3 scripts/build_paste_bundles.py` downloads those files from `raw.githubusercontent.com/rhope-ops/RADE/<commit>/` into `.rade-cache/<commit>/` (git-ignored). A file gets its name only after its SHA-256 matches. Each build hashes the cache again and replaces a changed file.
- Network: needed once for each lock. With a full cache the build works offline. With no network and no good cache, or with a wrong hash, the build stops with a FAIL line and writes no bundle. To start again, delete `.rade-cache`.
- `RADE_DIR=<folder>` is the one override, to try an engine that is not merged. The build prints a warning and skips the lock. Never commit a bundle built this way: `tests/run.sh` clears RADE_DIR and fails on a bundle that the pinned engine did not build.
- To change the lock: only a 90-161.Z session does it, on the PFM's request, in one pull request that holds the lock, the rebuilt bundle and the decision row. First check that no other open pull request changes the lock. Copy `commit`, `tag` and the hashes from the RADE release (its file rade-engine.lock.json), and add 1 to `serial`. `tests/run.sh` fails when `serial` is not main's + 1 or the branch lacks main's last lock commit, so two sessions cannot move the lock at once: two lock changes from the same main conflict in git on the second merge, and after that merge of main the serial test asks for the next number. A RADE session never edits this repo.
- Or run `python3 scripts/bump_lock.py engine-v<N>` (PFM, 2026-11-15; local, no Actions): it copies and checks the release lock, adds 1 to `serial`, refreshes the task scripts' blocks from the new engine, rebuilds under the file-open trace, and runs scripts/check.sh and the PII guard. Only when all pass does it write the decision row; on a failure it puts back the old lock, bundles and task scripts. Then commit and open the pull request.
- To find the file list for a new engine commit: run the engine under a Python audit hook (`sys.addaudithook`, event `open`) and list the files it opens under the RADE folder.
