---
name: efficiency
description: Use when a check run, the check-in or a push prints "slower than the baseline" or SLOWER, when the PFM says something is slow, and before you record a time baseline or add a repeated process. Gives how to confirm, fix and prove a slowdown.
---

# Efficiency: a measured slowdown

AGENTS.md "Caps and audit" points here. A slowdown that nobody looks at grows: agents add steps, and each one seems small. So each repeatable process compares its time with a baseline, and a slowdown starts this skill. Warn only: a slowdown never fails a check (the PFM, 2026-11-16).

## Where times are compared

| Process | Compared | Baseline in `.check.state.json` |
|---|---|---|
| `scripts/check.sh` (full lane) | Wall time and each step | `timings.check.seconds`, `timings.check.steps` |
| `scripts/check.sh --fast` | Each step (its total depends on what changed) | `timings.check.steps` |
| `scripts/session_checkin.sh` | Its run time | `timings.checkin.seconds` |
| Pre-push hook | The content check run | `timings.push-guard.seconds` |
| `python3 scripts/bloat_check.py --time` | Each timing with a `cmd` | `timings.<name>.seconds` |

Slower means both: over `max_slowdown` (default +25%) and over `min_slowdown_seconds` (default 0.5 s), per timing. The second limit stops noise on a step of 0.1 s.

## Steps

1. Confirm. Get 3 runs of the slow process. A run the hook makes next counts as one: do not run a lane by hand that the hook runs next (AGENTS.md "Checks"). A slowdown in 1 of 3 runs is noise (a shared CPU): say so in the report and stop. `CHECK_SERIAL=1 scripts/check.sh` times each step alone.
2. Find the cause. List what changed since the baseline: `git log --stat <baseline commit>..HEAD -- <files of the slow step>`. Profile the slow step (`time`, `python3 -X importtime`, `python3 -m cProfile -s cumtime`) and name the top 3 costs. Compare with a scratch worktree at the baseline commit (`git worktree add <scratch dir> <commit>`).
3. Fix the cause. A skipped test, a removed check or a raised limit is not a fix (AGENTS.md "Guards and checks").
4. Prove it. Give the median of 3 runs before and after, the command and the machine (cores) in the report.
5. Record a baseline (below), in the same branch as the fix.

When the cause is spread over many files (layers of small additions), stop and propose the audit (`.claude/skills/audit/SKILL.md`) to the PFM.

## Record a baseline

- Check lanes: run the full lane 3 times; `scripts/check.sh --record` after the 3rd pass stores each step; then `python3 scripts/bloat_check.py --compare check=<median wall time> --record` sets the wall time to the median of the 3 runs.
- One time: `python3 scripts/bloat_check.py --compare NAME=SECONDS --record` (NAME as in the table; `check:<step>` for one step). Use the median of 3 runs.
- Commands with a `cmd`: `python3 scripts/bloat_check.py --time --record`.
- Commit the change to `.check.state.json`, with the before and after numbers in the commit message.
- A new baseline after a fix, or for a new step, is routine. A slower baseline with no fix (accepting the cost) needs the PFM's approval: put it under Suggest, with the numbers.

## Time a new repeatable process

- A command people or hooks run: add a timing with its `cmd` to `timings` in `.check.state.json`, then record it.
- A script that runs itself (a hook, the check-in): measure the run and call `bloat_check.py --compare NAME=SECONDS`, as `scripts/session_checkin.sh` does.
- An agent procedure (deliver, a review, an audit): write its start and end time in the report. When it runs a 2nd time, propose a script for it under Suggest.
