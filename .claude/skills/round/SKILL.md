---
name: round
description: Use to build, revise or release a gov-device test round (R<NN>) or a task script (90161Z-T<NN>), to write or change a go.md task or a runner step the PFM reads, and to record a round's results.
---

# Build and release a round

AGENTS.md "Project rules" (Gov device, What people see, Round results) point here. The rules there win; this file holds the steps. Commands: AGENTS.md "Commands". Sources: the PFM's decisions of 11 to 16 Nov 26 in docs/DECISIONS.md.

## 0. Before you start

- Build the next round in the session that recorded the last results, right after the answers of section 1 step 7 (the PFM, 2026-11-20; replaces 'one new session for each round'); a `worker` on the standard tier unless `.claude/skills/delegate/SKILL.md` says strong (PFM, 2026-11-15).
- Use the RADE release that exists. An engine change runs in its own RADE session (rhope-ops/RADE, under RADE's rules) at the same time; the round moves to it later (PFM, 2026-11-15).
- Read the last results file (docs/reviews/<date>-r<NN>-results.md) and the DECISIONS rows for the round.
- A round holds only steps that test something not yet verified (PFM, 2026-11-14).

## 1. Results

1. When the PFM says the e-mail is sent or received, search Gmail for the subject "90161Z R<NN>". Never watch Gmail on a timer.
2. Before you record a round's results, list the open pull requests and stop if one already holds that round.
3. Write docs/reviews/YYYY-MM-DD-r<NN>-results.md in the form of the R25 file: source line (subject, time, files, build, engine), a table of checks and steps, then findings with what they mean. Counts, field names and status codes only; no session ids, names or site paths.
4. Design a fallback only for a test that FAILED; no fallback before its test has run.
5. Move the round to "Done" in go.md, with the link to the results file.
6. Once the results are on main: move an app-drafted round e-mail to Trash and list it by date, time and subject. Any other result e-mail: ask first and act only on the PFM's confirmation in that turn.
7. Next round: in the same turn as the results, show the PFM one question round for R<NN+1>: the findings to fix, the docs/phases.md row and the steps that leave. When the PFM answers, build and release the round (sections 2 to 6) without waiting for a new request (the PFM, 2026-11-20).

## 2. Task script

- File: `scripts/gov/90161Z-T<NN>-<slug>-r<N>.ps1`: 2-digit task number, revision starts at r1 and adds 1 for each fix; keep one revision. Every file the PFM downloads, and every flow display name, uses the same `90161Z-T<NN>-<slug>-r<N>` form (tests/check_flow_defs.py checks flow/defs). Exception: scripts that load each other by file name keep their names and go in one folder.
- Shared blocks come from `scripts/gov/src/` (task-common, site-common): edit the source, then `python3 scripts/build_task_scripts.py`. Never edit between the markers.
- Task folder: `C:\Users\<DODID>\OneDrive - United States Air Force\RADE\90-161.Z\T<NN>`; go.md names it in every task. The script uses the profile folder as the DODID with no question, goes to its folder itself, and writes `<DODID>` instead of the number in all output. Never commit a DODID.
- Target: Windows PowerShell 5.1 (also runs on 7), Word 16 COM, PnP.PowerShell 1.12.0; no other modules. No elevated credentials (ISSM ruling, 2026-11-13); passwords only through Get-Credential at run time.
- No reconnaissance: fixed hosts, the one site given, own flows only (Project rule).
- Lint: `scripts/lint.sh <file>`; the pre-push hook lints changed files.
- Repeated tasks (the PFM, 2026-11-26, rounds R47 and later): Each go.md task and each runner step card that repeats a task from an earlier round shows the line 'Why again: <the last round that ran it and its result>; <what changed since: a fixed finding, a changed file, a new engine, or a part not proved yet>.' A task that passed, with no change since, is not in the round. The window walk opens only the screens that changed or failed since the last round that passed them, and names the change for each screen.

## 3. Round definition

- `scripts/paste_bundles.json`: the round, its steps, `needs`, `after` and `fetch`.
- A step that passed runs again only when its files changed since the round that passed it (hash in the manifest; PFM, 2026-11-14).
- Every step a script can do (save files, download public data, run checks, collect results) runs in the round; go.md keeps only what needs a person (site and Power Automate clicks, judgment). Each task says which steps the round does.

## 4. Bundle

1. `python3 scripts/build_paste_bundles.py` regenerates `scripts/gov/paste/90161Z-R<NN>-round-r<N>.ps1`. Never hand-edit a bundle.
2. The engine comes from `scripts/rade.lock.json` (SHA-256 checked). The lock moves only on the PFM's request: `python3 scripts/bump_lock.py engine-v<N>` (docs/dev-setup.md "RADE engine").
3. No size limit (the PFM, 2026-11-18; was 600 KB): one paste for each round. The largest paste that ran is in the newest results file.
4. The old round's bundle leaves when the next one ships.
5. From R30 on, raise the revision on every rebuild (PFM, 2026-11-18): a bundle that main already has never changes. `scripts/bundle_revision.py` checks it (scripts/check.local.sh, both lanes); `--raise` raises the revision, and `scripts/bump_lock.py` runs it before its rebuild.
6. Results go back as plain files in a results folder (Rounds\<round>), attached to one e-mail; never a zip (zips do not cross the boundary).

## 5. go.md task (the usability bar)

Every update the PFM sees on go.md or in a runner window (PFM, 2026-11-13; 2026-11-16):

1. One line on what it is for, and a time estimate marked as an estimate.
2. What it writes or changes on the computer or site, shown before anything runs.
3. Numbered steps, one action each, in plain words. Each step names the exact thing to select and holds the exact text to type or paste. No step points to another file, section or step for its content. No build words (block, way, part, item) unless the screen shows them.
4. Exactly what to send back (file names, subject line).
5. What to do if it fails.

Also:

- go.md holds only the steps that start the round; the runner window holds every other step (one place per step).
- Write go.md in the PFM's voice. Open tasks go first; finished ones move to "Done".
- Link every file and every zip by its raw.githubusercontent.com URL, one per line; never a rhope-ops.github.io copy of a file or a github.com archive link. No code in go.md.
- The PFM types only the first address by hand (the bookmark github.com/rhope-ops/90-161.Z, the README); keep any address he must type short.
- Before a round ships: `python3 tests/check_guide_text.py` passes (it fails a step that points elsewhere, holds 2 actions or is over 200 characters), and a fresh agent that has not seen the build reads only the steps and says back each action. Rewrite any step it cannot say back.
- Screen names (Project rule, the PFM, 2026-11-25): copy each window, card, button, row and bar text from the round's bundle code, at the point in the flow where the code shows it; never from an older go.md or from memory. `python3 tests/check_screen_names.py` fails a bold or quoted name that no string of the bundle holds. It cannot see a real name at the wrong time, so give the fresh reader the steps plus the output of `python3 tests/check_screen_names.py --map` (each card and its sentence, in code order, and the button texts), and ask it to mark each step whose card, button or order differs from the code.

## 6. Release order

1. Build: task scripts, round definition, bundle, go.md task; then run `python3 scripts/build_go_page.py` (it writes the task cards into index.html).
2. Push the branch: the pre-push hook runs the fast lane.
3. Run the full lane once on the head commit (`scripts/check.sh`).
4. Fresh review of the code diff (AGENTS.md "Delegation"); start it while the hosted check runs.
5. One pull request for the round (one docs commit), then merge it under Project rule "Delivery".
6. Verify that origin/main has the commit.
7. Write the NEXT_PROMPT state and the DECISIONS rows. Each round's handoff records the time from start to release and the slowest step, so the next audit has data (the PFM, 2026-11-26).
8. Tell the PFM the round is ready, with the link https://github.com/rhope-ops/90-161.Z (the README; never a github.io page or a .ps1 file).
