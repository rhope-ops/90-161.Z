---
name: deliver
description: Use when a change in this repo is ready to commit, push, merge or publish, when a push or a merge is blocked, when you clean up branches, when you add or change a GitHub Actions workflow, when work must run while the PFM is away, and before you report repo work as done. Gives the delivery steps, the two check lanes, the review gate before a merge, the rule for a repo with no project tests, host limits and branch clean-up.
---

# Deliver a change

AGENTS.md "Delivery" and "Checks" point here. The rules are there; this file holds the steps.

## Steps

1. Commit on a branch (the branch the host requires, else `claude/<topic>`), with a noreply identity. Write a commit message that names a blocked git form (stash, restore, hooksPath, the hook-skip flag) to a file and commit with `git commit -F <file>`; the deny rules match the whole command.
2. Push. The pre-push hook runs the fast lane; do not run it by hand first.
3. When the work is ready to merge: run the full lane one time on the head commit (`scripts/check.sh`). A change to code, checks or scripts also needs the fresh review of AGENTS.md "Delegation" on that head commit.
4. Merge to main by merge, never rebase. Push main: the hook needs a green full lane on that commit (the run of step 3 counts when the tree is clean and the commit is the same).
5. Verify: `git fetch origin main && git merge-base --is-ancestor <commit> origin/main`.
6. Republish the affected artifacts. Delete previews after they ship.
7. Clean up branches (below). Report with the states kept apart: done, published, verified.

## Check lanes

| Lane | Command | Runs | When |
|---|---|---|---|
| Fast | `scripts/check.sh --fast` | Rule caps and pointers; self-tests only of the kit scripts that changed against origin/main; the project log check; the personal-data scan; `scripts/check.local.sh --fast` | The pre-push hook, on each push to a branch other than main |
| Full | `scripts/check.sh` | Everything: all self-tests and `scripts/check.local.sh` with no argument | Before a merge (step 3), the pre-push hook on a push to main, and the pull-request Action |

- Steps of a lane run in parallel. Each run ends with a `TIME` line (the wall time and the 3 slowest steps) and a line that compares the times with their baselines. A `WARN  slower than the baseline` line (full tier) starts the `efficiency` skill; it never fails the lane.
- A passing step can print `WARN` lines (rule lint). When rule lines changed, the full lane fails until the conflict check of `.claude/skills/rule-change/SKILL.md` has a record.
- `scripts/check.local.sh` gets `--fast` as its first argument in the fast lane. A fast project lane must still check each changed file in full and that generated files are not stale. A script that ignores the argument runs everything, which is slow but safe.
- A lane that passed on a clean tree leaves a stamp in `.git/`; the hook skips a repeat run on the same commit. Never write the stamp by hand.
- The fast lane can miss a defect in a file that did not change. The full lane before the merge is the gate: never merge on a fast-lane pass.

## No project tests yet

While `scripts/check.local.sh` does not exist (check.sh says SKIP project checks), deliver changes to code, checks or scripts through a pull request. Merge it when the full lane passes and the fresh review finds no MAJOR finding; else ask the PFM (with no project tests, the review is the only gate). At the first code change, propose a `scripts/check.local.sh` that runs this project's tests or a smoke test.

## Blocked steps and host limits

- A host limit wins: do the steps the host allows, then report each other step as blocked, with its cause and what unblocks it.
- If permissions block a step, give the exact commands to paste, one code block for each command.
- When the personal-data guard blocks a push: `.claude/skills/personal-data/SKILL.md`.

## Branch clean-up

Delete a remote branch when all its work is on main (`git merge-base --is-ancestor origin/<branch> origin/main`), stale ones included. Never delete one with unmerged work: list it for the PFM with a recommendation.

## GitHub Actions

Private repos share 2,000 Actions minutes a month. Trigger workflows on `pull_request` and `workflow_dispatch` only, never on `push`. Agents run the lanes in their own workspace before they report; CI is a second check, not the first. Public repos run Actions free.

## Unattended work

- A scheduled task needs a prompt that stands alone and permission to commit, push to main and republish without a person.
- Background work stops at the usage limit. Say when that can interrupt it.
- Before unattended work starts, the session makes a dry-run push to each repo it needs. If one fails, it stops at once and says which repo and why.
- A plan or brief names a required status check by the name a real check run shows (the job name), never by the workflow file's name.
