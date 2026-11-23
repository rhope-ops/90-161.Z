---
name: kit-update
description: Use when a project takes a kit release or has a kit-update pull request, when drift.py or the kit lock shows a difference, to change a kit file or rule from a project, and for a first sync.
---

# Take a kit update

AGENTS.md "Kit files" points here. The kit (rhope-ops/archimedes_lever) owns the kit files and the kit text of AGENTS.md; `.check.lock` holds their hashes and the kit version, and `scripts/check.sh` fails when one differs. A project never edits them: it adds its own layer in the places below, and a kit release arrives as one pull request made by `scripts/sync_baseline.py`.

## Where a project's own text goes

| The project wants | Place (a sync does not touch it) |
|---|---|
| Its own rule | AGENTS.md "Project rules" (hard ones marked "(cannot be changed)") |
| Its build, test and lint commands | AGENTS.md "Commands" |
| Its own tests, lint or check lanes | `scripts/check.local.sh` (gets `--fast` in the fast lane) |
| Its own blocked terms, files and skips | `.check` |
| Its own finders of the content check (a pattern of its own, one more check) | `scripts/check_content_local.py`; the interface is in the header of `scripts/check_content_scan.py` |
| Its own words, limits, parser or checks for the steps a person follows | `scripts/check_instructions_local.py`; the interface is in the header of `scripts/check_instructions.py` |
| Stricter code-standard rules | `scripts/code_standard_gate.py`, with `code-` lines in `.check`; the interface is in the header of `scripts/code_standard.py` |
| Steps added to a kit skill, or a limit on it | `.claude/skills/<name>/PROJECT.md` |
| A procedure or an agent of its own | A skill with its own name in `.claude/skills/`; an agent with its own name in `.claude/agents/` (`scout`, `worker` and `reviewer` are kit files) |
| Its own hooks and permissions | Its entries in `.claude/settings.json` (a sync merges, kit entries first) |

An extension file (`scripts/*_local.py`) proves itself: give it a `--test` mode, and `scripts/check.sh` runs it.

Something that does not fit: change the kit so that it fits (below). Do not edit a locked file to make room.

## Sync steps (run in the project, with the kit cloned next to it as `../archimedes_lever`)

1. Before: `python3 ../archimedes_lever/scripts/drift.py --baseline ../archimedes_lever`, `python3 scripts/bloat_check.py --brief`, and the `TIME` line of `scripts/check.sh`. Keep the numbers.
2. Check out the release tag in the kit (`git -C ../archimedes_lever fetch origin tag v<version>`, then `git -C ../archimedes_lever checkout v<version>`; a shallow or single-branch clone has no tags until that fetch), so the lock names a released commit (each release gets its tag when it merges; no tag yet: sync from the merge commit and say so in the pull request). Read the kit's docs/CHANGELOG.md from the project's locked version to the new one: a MAJOR step means work beyond the sync (its row says what). A kit change that conflicts with a project rule or limit (a frozen spec, a protected file list, its own delivery rule): the project rule wins; name it in the pull request and ask the Maintainer when it is a hard rule.
3. Dry run, with no uncommitted changes: `python3 ../archimedes_lever/scripts/sync_baseline.py --baseline ../archimedes_lever` and read the whole diff. For each line of project text that the diff would remove, move it to its place in the table first.
4. First sync only: `python3 scripts/check_settings.py --migrate` when the project still has `.pii-guard` (then replace the old comment lines at the top of `.check` with the comment lines of the kit's `.check`; keep each setting line); replace a "No kit sync" project rule with nothing (AGENTS.md "Kit files" now holds the rule) after the Maintainer approves that removal; delete the files the sync lists as moved (`MOVED_FILES`) once their text is in the new place (a PROJECT.md in a renamed skill's folder moves to the new folder: `run-verify` and `ui-verify` to `verify`, `port` to `kit-update`).
5. Apply on a branch: the same command with `--apply`. Do not edit `.check.lock` by hand: the sync writes it.
6. After: the full lane passes (the kit checked its own rule text, so the conflict check of the rule-change skill covers only changed "Project rules" lines); `drift.py --strict` shows 0 kit items different; `python3 scripts/check_lock.py --status` shows the new version. Give the numbers of step 1 before and after.
7. Record a row in the project's docs/DECISIONS.md ("kit <version>, date; kept: ..."), and a project log row when it is a milestone. Do not copy the kit's docs/DECISIONS.md, docs/LOG.md or reviews: the project has its own.
8. Deliver it (`.claude/skills/deliver/SKILL.md`). A kit update changes instruction and guard files, so it is lane C. The pull request text lists each kit rule line that changed.

## Change the kit from a project

1. A kit file or kit rule is wrong or does not fit: make the change in the kit repo, by its own pull request, with the project named as the reason.
2. Urgent and the kit cannot change now: put the fix in the project layer (the table) and open an issue or a handoff line in the kit.
3. One kit change wanted before a release exists: check out the kit commit that holds it in `../archimedes_lever` and sync from there; the lock then names that commit.

## A project that cannot take a full sync yet

Bring one change by hand only when the Maintainer asks for it: copy the kit file as it is (never a changed copy), run `python3 scripts/check_lock.py --relock <file>` so that the lock accepts it (a relock needs the Maintainer's request, and each check run lists it as an override), and record what was skipped and why in docs/DECISIONS.md.

A kit file with code-standard debt cannot be accepted by a project: the code-standard ratchet has no adopt path for a kit file, so the project's push fails until the kit fixes the file. Report it to the kit owner (docs/KIT_HANDOFF.md names it); do not relock the file to get past the check.

## After a kit release merges (in the kit repo)

The kit owner (named in docs/KIT_HANDOFF.md) measures the session load of each synced repo with the new files first (`python3 scripts/bloat_check.py --brief` on a dry run), opens the sync pull request in each synced repo (the steps above), and updates that repo's row on the fleet page that KIT_HANDOFF names.
