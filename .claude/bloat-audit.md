# Bloat, drift and assumption audit

The full periodic audit that AGENTS.md "Bloat, drift and assumptions" calls for. Claude or a person can run it. Read it only when an audit is due or asked for; it is not a start-of-session file.

Why: two audits of one project found layered bloat that made a simple operation 5x slower (116.6 s to 23.4 s after the fix). Each layer looked reasonable when an agent added it. Agents add; they seldom remove. This audit finds what to remove and proposes it.

## Rules for the auditor

- Measure first, then change. Every finding has evidence: a path and line, a count, a size or a time. No finding from impression.
- Fix the cause, then apply the same fix everywhere the pattern appears.
- Removals need the PFM's approval (kit default, 2026-11-13). Do not remove, shorten or reword code, a script, a flag, a config, a template, a doc section, a rule, a decision, a test or a feature until the PFM approves. Propose it with evidence and options (Step 5.4).
- "Nothing in the repo calls it" does not prove a thing is unused. People run tools by hand, from other repos or devices, and from pasted prompts. Agents read only the repo, so a request that lives only in chat is invisible to them.
- Exceptions (no approval), the only list: (a) files made on this audit's own branch; (b) generated files rebuilt from their source; (c) agent scratch files (debug output, "_old"/"_v2" copies) that nothing references AND whose adding commit names no request or decision; (d) exact duplicates merged into the canonical copy, text kept word for word; (e) reference text moved out of start-read files unchanged, except from instruction and guard files (AGENTS.md "Untrusted input"), where every change is a proposal. List each in the report.
- Chesterton's fence: before you propose a removal, find why the thing exists (git log -S, DECISIONS, the commit that added it) and put the reason, or "not found", in the proposal.
- Never weaken a check, hook, test or guard to make a number smaller.
- Generated files: fix the source and rebuild. Never hand-edit the output.
- One audit = one branch, small commits by category, so each removal can be reverted alone.
- The audit itself must stay cheap: budget about 1 hour of agent time for a small repo. Stop and report if the scope is larger.

## Step 1: inventory and baseline (measure before)

1. `python3 scripts/bloat_check.py --time` (full report). Copy the numbers into the report.
2. If `.bloat-audit.json` has no `timings`, add the 2–4 operations people run most (tests, build, session check-in, the main user task) and run `--time --record` once to set a baseline. Record the machine type: times compare only on the same kind of machine.
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
6. Performance regressions: compare timings with the baseline. Profile the slowest operation (`time`, `python3 -X importtime`, `-m cProfile`, `Measure-Command`) and name the top 3 costs.
7. Dependencies: unused packages, two libraries for one job, pinned versions no longer needed, vendored copies of public code.
8. Repository weight: big binaries, generated files that could be rebuilt, old releases, logs, caches committed by mistake.
9. CI and automation: workflows, hooks and scheduled jobs that no longer catch anything, run on every push when a pull request is enough, or duplicate a local check. Count minutes used against the budget.
10. Process bloat: steps a person repeats by hand that a script could do; approvals or reports nobody reads; templates with sections that are always empty.
11. Tech-debt register: write each accepted (not fixed) item to the report with an owner and a review date, so debt is visible and not forgotten.

### Agentic AI carve-outs

12. Instruction bloat: AGENTS.md, CLAUDE.md, host prompts, project instructions and personal preferences. Find rules that repeat, conflict, are already enforced by a hook or test (keep the hook, shorten the rule to a pointer), or describe one past incident. Every rule needs a reason a reader can check. Prefer one line per rule.
13. Context cost: everything loaded at session start costs tokens on every turn of every session. Move reference text (long tables, history, evidence) out of start-read files into files read on demand. Decision logs grow forever: keep the current decisions in the start-read file and move superseded ones to an archive file.
14. Rule accretion: rules added after one incident and never retired. Give each such rule a review date; at the date, propose to retire it if it caught nothing.
15. Cross-host duplication: the same rule in the repo, a claude.ai Project, personal preferences and memory. The repo is the source; other places hold a pointer only. Personal preferences hold personal style, not project rules.
16. Handoff and memory rot: NEXT_PROMPT.md, memory files and review folders that keep closed items, old links and repeated status. Keep the handoff at its line budget; archive reviews older than 90 days into a single index.
17. Agent-made helpers: one-off scripts, debug files, scratch copies, "_v2"/"_new"/"_old" files and extra wrappers left by agents. Each needs a caller or a recorded reason; if it has neither, propose its removal.
18. Defensive layering: try/except, fallbacks, retries, validation and comments added by agents "to be safe" that hide errors or duplicate a check one layer up. Keep the one check at the right layer.
19. Hooks and tools: hook run time per session and per turn (time each one), permission and allow-list sprawl, MCP servers, skills and plugins nobody uses.
20. Delegation overhead: briefs that restate AGENTS.md (point to it instead), reviews that re-run the same checks, parallel agents on work too small to split.
21. Output verbosity: reports, commit messages and docs written by agents that are longer than their content. Shorten templates at the source.

## Step 3: assumption audit

Assumptions that nobody checked are drift that has not happened yet.

1. List the key assumptions the project depends on: in plans, designs, code comments, docs, handoff and decisions. A key assumption is one that changes the design, the cost or the result if it is wrong.
2. For each, give: the assumption, where it is used (path:line), its source (a decision with a date, a document paragraph, a test, a measurement, or none), and your confidence: high (verified by a source or test), medium (consistent with sources, not verified), low (no source, or the sources disagree).
3. Untraced or low-confidence assumptions that matter go to the PFM as questions, with 2–3 options and a recommendation. Do not resolve them yourself.
4. Assumptions that a test can check get a test.
5. Find stale assumptions: true when written, no longer true (versions, access rights, limits, prices, people's roles, tool behavior).

## Step 4: fix and measure again

1. Make only the fixes in the exceptions list in "Rules for the auditor". Every other removal, shortening or rewording is a proposal for the PFM (Step 5.4); make it only after the PFM approves.
2. Run the project's checks (AGENTS.md "Commands"). All must pass as before.
3. Run `python3 scripts/bloat_check.py --time` again. Report before → after for each number.
4. Changes to code, checks or scripts get the fresh review that AGENTS.md "Delegation" requires before merge.

## Step 5: record

1. Write `docs/reviews/YYYY-MM-DD-bloat-audit.md` (or the place AGENTS.md "Project rules" names): the before/after table, findings by category with evidence, fixes made, proposals for the PFM, the assumption table, the tech-debt register.
2. Update `.bloat-audit.json`: `last_audit` (date, commit on main after the fixes, report path), new `timings` baselines (`--time --record`), and `ignore` globs for generated or reference files that the duplicate scan should skip (each new glob is a proposal: it hides files from the scan).
3. Log the audit in the project log (milestone; a breakthrough when a fix removes a blocker or saves 25%+ time).
4. Ask the PFM the open questions together, each with options and a recommendation. Group removal proposals in one table: what, where, why it exists (or "not found"), evidence it is unused, saving, risk, REC.

## Report table (minimum)

| Measure | Before | After | Budget |
|---|---|---|---|
| Start read (~tokens) | | | |
| Duplicate lines (80+ chars, 2+ files) | | | |
| Tracked files / size | | | |
| Big files | | | |
| Timing: each named operation (s) | | | |
| Removals proposed / approved / made | | | |
| Rules removed or merged | | | |
| Key assumptions: high / medium / low / untraced | | | |
