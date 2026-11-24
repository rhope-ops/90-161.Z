---
name: audit
description: Use when a run is slower than its baseline or said to be slow, before you add a time baseline or a repeated process, for an audit the Maintainer asks for, on AUDIT DUE, and before a release.
---

# Slow runs and the full audit

AGENTS.md "Caps and audit" points here. Two procedures: a slow run (one operation slower than its baseline: read only that section), and the full audit.

## A slow run

A slowdown that nobody looks at grows: agents add steps, and each one seems small. So each repeatable process compares its time with a baseline, and a slowdown starts this section. Warn only: a slowdown never fails a check (the Maintainer, 2026-11-16).

### Where times are compared

| Process | Compared | Baseline in `.check.state.json` |
|---|---|---|
| `scripts/check.sh` (full lane) | Wall time and each step | `timings.check.seconds`, `timings.check.steps` |
| `scripts/check.sh --fast` | Each step (its total depends on what changed) | `timings.check.steps` |
| `scripts/session_checkin.sh` | Its run time | `timings.checkin.seconds` |
| Pre-push hook | The content check run | `timings.push-guard.seconds` |
| `python3 scripts/bloat_check.py --time` | Each timing with a `cmd` | `timings.<name>.seconds` |

Slower means both: over `max_slowdown` (default +25%) and over `min_slowdown_seconds` (default 0.5 s), per timing. The second limit stops noise on a step of 0.1 s.

### Steps

1. Confirm. Get 3 runs of the slow process. A run the hook makes next counts as one: do not run a lane by hand that the hook runs next (AGENTS.md "Checks"). A slowdown in 1 of 3 runs is noise (a shared CPU): say so in the report and stop. `CHECK_SERIAL=1 scripts/check.sh` times each step alone.
2. Find the cause. List what changed since the baseline: `git log --stat <baseline commit>..HEAD -- <files of the slow step>`. Profile the slow step (`time`, `python3 -X importtime`, `python3 -m cProfile -s cumtime`) and name the top 3 costs. Compare with a scratch worktree at the baseline commit (`git worktree add <scratch dir> <commit>`).
3. Fix the cause. A skipped test, a removed check or a raised limit is not a fix (AGENTS.md "Guards and checks").
4. Prove it. Give the median of 3 runs before and after, the command and the machine (cores) in the report.
5. Record a baseline (below), in the same branch as the fix.

When the cause is spread over many files (layers of small additions), stop and propose the full audit (below) to the Maintainer.

### Record a baseline

- Check lanes: run the full lane 3 times; `scripts/check.sh --record` after the 3rd pass stores each step; then `python3 scripts/bloat_check.py --compare check=<median wall time> --record` sets the wall time to the median of the 3 runs.
- One time: `python3 scripts/bloat_check.py --compare NAME=SECONDS --record` (NAME as in the table; `check:<step>` for one step). Use the median of 3 runs.
- Commands with a `cmd`: `python3 scripts/bloat_check.py --time --record`.
- Commit the change to `.check.state.json`, with the before and after numbers, the 3 run times and the machine (`nproc` cores) in the commit message.
- Record only on a quiet machine: a run while other agents or lanes share the CPU is not a measurement. When a lane gains or loses a step, record its baseline again in the same pull request.
- A new baseline after a fix, or for a new step, is routine. A slower baseline with no fix (accepting the cost) needs the Maintainer's approval: put it under Suggest, with the numbers.

### Time a new repeatable process

- A command people or hooks run: add a timing with its `cmd` to `timings` in `.check.state.json`, then record it.
- A script that runs itself (a hook, the check-in): measure the run and call `bloat_check.py --compare NAME=SECONDS`, as `scripts/session_checkin.sh` does.
- An agent procedure (deliver, a review, an audit): write its start and end time in the report. When it runs a 2nd time, propose a script for it under Suggest.

## The full audit: bloat, drift and assumptions

The full periodic audit that AGENTS.md "Caps and audit" names. Claude or a person can run it, and only when the Maintainer asks: when the check-in says AUDIT DUE, tell the Maintainer and ask (about 1 hour of agent time).

Due: every 14 days or 300 commits to main, whichever comes first, and before a release. The Maintainer may set other values in `.check` (`audit-every-days:`, `audit-every-commits:`).

Why: two audits of one project found layered bloat that made a simple operation 5x slower (116.6 s to 23.4 s after the fix). Each layer looked reasonable when an agent added it. Agents add; they seldom remove. This audit finds what to remove and proposes it.

## Fleet audit

At each kit release, or 14 days after the last fleet audit (AUDIT DUE (fleet) at the kit check-in), report it and ask the Maintainer; when the Maintainer says yes, run the full audit for every fleet repo in a fresh session. Report per repo: kit version and lock state, caps, open branches, kit lag; and the outcome metrics: defects found per check in the last 30 days, mutant kill rate where measured, files changed per kit change, and fix-of-a-fix rate (commits that fix a commit of the last 7 days). File size and file counts are warnings only. Write the date to `fleet.last_audit` in kit.config.json. Each check, and this skill, gets a retire / shrink / keep line in docs/tools.md.

## Rules for the auditor

- Measure first, then change. Every finding has evidence: a path and line, a count, a size or a time. No finding from impression.
- Fix the cause, then apply the same fix everywhere the pattern appears.
- Removals need the Maintainer's approval. Do not remove, shorten or reword code, a script, a flag, a config, a template, a doc section, a rule, a decision, a test or a feature until the Maintainer approves. Deliver the proposals as a pull request (Step 5.4).
- Profile before you prune: a slow check is more often 1 or 2 hot spots than too many tests. Time the steps first.
- "Nothing in the repo calls it" does not prove a thing is unused. People run tools by hand, from other repos or devices, and from pasted prompts. Agents read only the repo, so a request that lives only in chat is invisible to them.
- Exceptions (no approval), the only list: (a) files made on this audit's own branch; (b) generated files rebuilt from their source; (c) agent scratch files (debug output, "_old"/"_v2" copies) that nothing references AND whose adding commit names no request or decision; (d) exact duplicates merged into the canonical copy, text kept word for word; (e) reference text moved out of start-read files unchanged, except from instruction and guard files (AGENTS.md "Rule text"), where every change is a proposal. List each in the report.
- Chesterton's fence: before you propose a removal, find why the thing exists (git log -S, DECISIONS, the commit that added it) and put the reason, or "not found", in the proposal.
- A smaller number is not a reason to change a check, hook, test or guard (AGENTS.md "Guards and checks").
- Generated files: fix the source and rebuild (AGENTS.md "Checks").
- One audit = one branch, small commits by category, so each removal can be reverted alone.
- The audit itself must stay cheap: budget about 1 hour of agent time for a small repo. Stop and report if the scope is larger.

## Step 1: inventory and baseline (measure before)

1. `python3 scripts/bloat_check.py --time` (full report) and `python3 scripts/bloat_check.py --rules` (rule counts). Copy the numbers into the report. Run `scripts/check.sh` and copy its `TIME` line (wall time and the 3 slowest steps).
2. If `.check.state.json` has no `timings`, add the 2–4 operations people run most (tests, build, session check-in, the main user task) and run `--time --record` once to set a baseline. Record the machine type: times compare only on the same kind of machine.
3. List tracked files by size and by last change (`git ls-files`, `git log -1 --format=%cs -- <file>`). Mark files with no change in 90+ days and no reference from any other file.
4. Count what every session loads: instruction files, imported files, the handoff, the decision log, host prompts, personal preferences, hook output. Express it in tokens (bytes / 4).

## Step 2: find bloat, by category

Every item below finds; it does not fix. A fix that removes, shortens, rewords, archives or condenses anything outside the exceptions in "Rules for the auditor" is a proposal (Step 5.4). For each category, list findings as: what, where (path:line), evidence (number), cost (time, tokens, files, minutes of a person), proposed fix, risk.

### General project hygiene (industry practice)

1. Duplication (DRY, single source of truth): the same fact, rule, value, list or code block in 2+ places. Keep one canonical place; others link to it. Includes copy-pasted code that should be a shared function, and docs that restate other docs.
2. Drift: copies that started equal and now differ (docs vs code, README vs AGENTS.md, a schema vs the builder, a project vs the kit it came from). Decide which copy is right from the source of authority, not from the newer date.
3. Dead code and dead files: functions, scripts, flags, configs, templates, test fixtures and branches nothing calls or reads. Check with grep for every name, and the build and test entry points.
4. Stale docs: text that describes old behavior, finished plans, closed questions, superseded revisions (r1, r2 when r5 is current), TODOs older than 30 days, broken links.
5. Layered wrappers: a script that calls a script that calls a script; checks that run the same test twice; retries around retries; config that overrides config. Draw the call chain for each common operation and time each layer.
6. Performance regressions: compare timings with the baseline. Profile the slowest operation (`time`, `python3 -X importtime`, `-m cProfile`, `Measure-Command`) and name the top 3 costs. Then look for work in series that could be shared or parallel: list the steps of the slowest operation with their times; mark the steps that share no files or state (they can run in parallel on the idle cores); count the process starts (one interpreter or shell start for each small step is a cost: batch them into one process); and count how many times one change runs the same step (by hand, in a hook, in CI).
7. Dependencies: unused packages, two libraries for one job, pinned versions no longer needed, vendored copies of public code.
8. Repository weight: big binaries, generated files that could be rebuilt, old releases, logs, caches committed by mistake.
9. CI and automation: workflows, hooks and scheduled jobs that no longer catch anything, run on every push when a pull request is enough, or duplicate a local check. Count minutes used against the budget.
10. Process bloat: steps a person repeats by hand that a script could do; approvals or reports nobody reads; templates with sections that are always empty.
11. Tech-debt register: write each accepted (not fixed) item to the report with an owner and a review date, so debt is visible and not forgotten.

### Agentic AI carve-outs

12. Instruction bloat: AGENTS.md, CLAUDE.md, host prompts, project instructions and personal preferences. Find rules that repeat, conflict, are already enforced by a hook or test (keep the hook, shorten the rule to a pointer), or describe one past incident. Every rule needs a reason a reader can check. One line per rule: AGENTS.md "Lean instructions".
13. Context cost: everything loaded at session start costs tokens on every turn of every session. Move reference text (long tables, history, evidence) out of start-read files into files read on demand. The decision log is a record, not a start-read file: check that no start-read file imports it or tells agents to read it at start, and that a decision that must bind every session is one line in "Project rules".
14. Rule census: count the rules (`bloat_check.py --rules`) and compare with the last audit. Run `bloat_check.py --lint` and put each flag (near-duplicate, vague, untested) in the census. "The rule has a reason" is not a pass: every rule has one. For each rule in AGENTS.md and "Project rules", write one of: enforced by a hook or test (shorten it to a pointer); a procedure (move it to a skill); the model does it without the rule (retire); evidence that it changed an outcome since the last audit (a log row, a review, a corrected turn: keep); no evidence (retire, or give it a review date). Report the count for each class.
15. Cross-host duplication: the same rule in the repo, a claude.ai Project, personal preferences and memory. The repo is the source; other places hold a pointer only. Personal preferences hold personal style, not project rules.
16. Handoff and memory rot: NEXT_PROMPT.md, memory files and review folders that keep closed items, old links and repeated status. Keep the handoff at its line budget; archive reviews older than 90 days into a single index.
17. Agent-made helpers: one-off scripts, debug files, scratch copies, "_v2"/"_new"/"_old" files and extra wrappers left by agents. Each needs a caller or a recorded reason; if it has neither, propose its removal.
18. Defensive layering: try/except, fallbacks, retries, validation and comments added by agents "to be safe" that hide errors or duplicate a check one layer up. Keep the one check at the right layer.
19. Hooks and tools: hook run time per session and per turn (time each one), permission and allow-list sprawl, MCP servers, skills and plugins nobody uses. Skill use, where the host has session records (a Claude cloud session: `list_events` with kinds `assistant` and `user` for the last 10 or more sessions of the project; each large result is saved to a file): `python3 scripts/skill_use.py <saved files>` prints the calls per skill, agent type and tool. A skill with 0 calls: propose a better description, a merge or its removal.
20. Delegation overhead: briefs that restate AGENTS.md (point to it instead), reviews that re-run the same checks, parallel agents on work too small to split.
21. Output verbosity: reports, commit messages and docs written by agents that are longer than their content. Shorten templates at the source.

## Step 3: assumption audit

Assumptions that nobody checked are drift that has not happened yet.

1. List the key assumptions the project depends on: in plans, designs, code comments, docs, handoff and decisions. A key assumption is one that changes the design, the cost or the result if it is wrong.
2. For each, give: the assumption, where it is used (path:line), its source (a decision with a date, a document paragraph, a test, a measurement, or none), and your confidence: high (verified by a source or test), medium (consistent with sources, not verified), low (no source, or the sources disagree).
3. Untraced or low-confidence assumptions that matter go to the Maintainer as questions, with 2–3 options and a recommendation. Do not resolve them yourself.
4. Assumptions that a test can check get a test.
5. Find stale assumptions: true when written, no longer true (versions, access rights, limits, prices, people's roles, tool behavior).

## Step 4: fix and measure again

1. Make only the fixes in the exceptions list in "Rules for the auditor". Every other removal, shortening or rewording is a proposal for the Maintainer (Step 5.4); make it only after the Maintainer approves.
2. Run the project's checks (AGENTS.md "Commands"). All must pass as before.
3. Run `python3 scripts/bloat_check.py --time` again. Report before → after for each number.
4. AGENTS.md "Delivery" and "Fresh review" say which changes need the fresh review and who merges.

## Step 5: record

1. Write `docs/reviews/YYYY-MM-DD-bloat-audit.md` (or the place AGENTS.md "Project rules" names): the before/after table, findings by category with evidence, fixes made, proposals for the Maintainer, the assumption table, the tech-debt register.
2. Update `.check.state.json`: `audit`: `last_audit` (date, commit on main after the fixes, report path) and new `timings` baselines (`--time --record`; the lanes as "Record a baseline" above says). In `.check`: `audit-duplicate-ignore:` globs for generated or reference files that only the duplicate scan should skip, `audit-ignore:` for files no audit measure should read (each new glob is a proposal: it hides files from the scan).
3. Log the audit in the project log (milestone; a breakthrough when a fix removes a blocker or saves 25%+ time).
4. Ask the Maintainer the open questions together, each with options and a recommendation. Removal proposals: make the 5 with the largest saving on a second branch and open one pull request for them, one commit for each item, with a table in its text: what, where, why it exists (or "not found"), evidence it is unused, saving, risk. Ask the Maintainer to approve each item in a question dialog, drop the commits that are not approved, then deliver it (`.claude/skills/deliver/SKILL.md`). List the other proposals in the report for the next audit; a long list is not approved, so it removes nothing.

## Report table (minimum)

| Measure | Before | After | Budget |
|---|---|---|---|
| Start read (~tokens) | | | |
| Rule bullets: AGENTS.md / Project rules | | | |
| Check lanes: fast / full (s), slowest step | | | |
| Duplicate lines (80+ chars, 2+ files) | | | |
| Tracked files / size | | | |
| Big files | | | |
| Timing: each named operation (s) | | | |
| Removals proposed / approved / made | | | |
| Rules removed or merged | | | |
| Key assumptions: high / medium / low / untraced | | | |
