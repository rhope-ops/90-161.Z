---
name: deliver
description: Use when a change is ready to commit, push, merge or publish, when a push or merge is blocked, when you clean up branches or change a GitHub Actions workflow, and before you report repo work as done.
---

# Deliver a change

AGENTS.md "Delivery", "Checks" and "Fresh review" hold the rules; this file holds the steps.

## Steps

1. Commit on a branch (the branch the host requires, else `claude/<topic>`), with a noreply identity. Write a commit message that names a blocked git form (stash, restore, hooksPath, the hook-skip flag) to a file and commit with `git commit -F <file>`; the deny rules match the whole command.
2. Push. The pre-push hook runs the fast lane.
3. Open a pull request for the branch (one per branch). Name its merge lane in the text.
4. Make it green: run the full lane one time on the head commit (`scripts/check.sh`), wait for the pull-request Action, and for lanes B and C get the fresh review on that head commit.
5. Before a merge, list the repository's open pull requests; AGENTS.md "Git history" says whose pull request you may merge. Merge by lane, with a merge commit. If the base moved, update the branch by merge first; a conflict with another session's work goes to the PFM.
6. Verify: `git fetch origin main && git merge-base --is-ancestor <commit> origin/main`.
7. Republish the affected artifacts. Delete previews after they ship.
8. Clean up branches (below). Report with the states kept apart: done, published, verified.
9. In the kit repo, after a kit release merges: the kit owner (named in docs/KIT_HANDOFF.md) opens the sync pull request in each synced repo (`.claude/skills/kit-update/SKILL.md`) and updates that repo's row on the fleet page that KIT_HANDOFF names.

## Merge lanes

Take the highest lane that any file or effect of the pull request falls in.

| Lane | What | Merge |
|---|---|---|
| A | Docs that are not rules: README, docs/, handoff, reviews, decisions and log rows; other files that are not code, scripts, checks or rules | When green, no question |
| B | Code, scripts, checks and tests | When green and the fresh review has no MAJOR finding, no question |
| C | Instruction and guard files (the list in AGENTS.md "Guards and checks"); a merge with a live or irreversible effect (a deploy, a data write); a security change; a UI or design change the PFM has not approved; a MAJOR finding you cannot fix | Ask the PFM, with one question that gives the pull request link, the check result and the review result |

- A lane C pull request that changes rule text shows each changed rule in full in its text, so the PFM's merge approves the exact text.
- An approved plan can state the lane of each of its steps. A plan cannot move a lane C change to a lower lane.
- In doubt between two lanes, take the higher one.

## Check lanes

| Lane | Command | Runs | When |
|---|---|---|---|
| Fast | `scripts/check.sh --fast` | Rule caps and pointers; self-tests only of the kit scripts that changed against origin/main; the project log check; the content check; `scripts/check.local.sh --fast` | The pre-push hook, on each push |
| Full | `scripts/check.sh` | Everything: all self-tests and `scripts/check.local.sh` with no argument | Before a merge (step 4), and the pull-request Action |

- Steps of a lane run in parallel. Each run ends with a `TIME` line and a line that compares the times with their baselines. A `WARN  slower than the baseline` line (full tier) starts the `efficiency` skill; it does not fail the lane.
- A passing step can print `WARN` lines (rule lint). When rule lines changed, the full lane fails until the conflict check of `.claude/skills/rule-change/SKILL.md` has a record.
- `scripts/check.local.sh` gets `--fast` as its first argument in the fast lane. A fast project lane still checks each changed file in full and that generated files are not stale.
- A lane that passed on a clean tree leaves a stamp in `.git/`; the hook skips a repeat run on the same commit. The stamp is written by the lane only.
- The fast lane can miss a defect in a file that did not change, so the full lane is the gate for a merge.

## No project tests yet

While `scripts/check.local.sh` does not exist (check.sh says SKIP project checks), the kit checks and the fresh review are the only gate. At the first code change, propose a `scripts/check.local.sh` that runs this project's tests or a smoke test.

## Blocked steps

- If permissions block a step, give the exact commands to paste, one code block for each command.
- When the content check blocks a push: `.claude/skills/personal-data/SKILL.md`.

## Branch clean-up

Delete a remote branch when all its work is on main (`git merge-base --is-ancestor origin/<branch> origin/main`), stale ones included. A branch with unmerged work stays: list it for the PFM with a recommendation.

## GitHub Actions

Private repos share 2,000 Actions minutes a month. Trigger workflows on `pull_request` and `workflow_dispatch` only, not on `push`. Agents run the lanes in their own workspace before they report; CI is a second check, not the first. Public repos run Actions free.

## Unattended work

- A scheduled task needs a prompt that stands alone and permission to commit, push and open a pull request without a person. It merges lanes A and B; a lane C change waits for the PFM.
- Background work stops at the usage limit. Say when that can interrupt it.
- Before unattended work starts, the session makes a dry-run push to each repo it needs. If one fails, it stops at once and says which repo and why.
- A plan or brief names a required status check by the name a real check run shows (the job name), never by the workflow file's name.
