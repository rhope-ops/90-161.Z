---
name: delegate
description: Use before you delegate to a subagent, run more than one agent, write a brief, pick a model, or review and merge a worker's branch.
---

# Orchestration: more than one agent

AGENTS.md "Agents" points here. Ask each agent for concise findings with evidence paths. The Maintainer's decisions (2026-11-10): the orchestrator stays on the strongest model; models are chosen per task with the routing table below. Routing names tiers; the table below maps them to Claude models.

## Agents (.claude/agents/)

| Agent | Model | Tools | Use |
|---|---|---|---|
| `scout` | haiku | Read, Grep, Glob | Searches, file lists, summaries of test or log output |
| `worker` | sonnet | Read, Edit, Write, Bash, Grep, Glob; guard hook | One brief-ready task on its own branch |
| `reviewer` | inherit (the author's tier) | Read, Grep, Glob, Bash; guard hook | Fresh review: diff and brief only |

`scripts/worker_guard.py` (PreToolUse hook) blocks push to main or master, every force-push form, rebase, reset --hard, clean and branch deletes for `worker`; with `--readonly` it also blocks every git verb that changes the repo, for `reviewer`. It is a seat belt for honest mistakes, not a security boundary: it cannot see file writes or commands built at run time.

## Model routing

Route by tier. Pass a model on the call only where this table says "strong" for a role whose default is lower.

| Work | Role | Tier |
|---|---|---|
| Search, file lists, summaries of test or log output | `scout` | fast |
| Task from a brief | `worker` | standard |
| Worker task that failed its checks 2 times, a refactor over 5+ files, a performance fix | `worker` | strong (model on the call) |
| Fresh review of a routine diff | `reviewer` | the author's tier (inherit) |
| Fresh review of data or save migrations, git or hook tools, security, or a refactor that must not change behavior | `reviewer` | strong (model on the call) |
| Merges, conflict choices, design, artifacts, deploys | orchestrator | strong |

Tiers by host. Model names change often: when a name here is gone, use the current Claude model of that tier and update this table.

| Host | fast | standard | strong | Subagents | Hooks |
|---|---|---|---|---|---|
| Claude Code, local or cloud (claude.ai/code) | haiku | sonnet | opus | `.claude/agents/` | Stop, PreToolUse, deny list, git |
| claude.ai chat | Haiku | Sonnet | Opus | Agent tool when offered | git only |

If the routed tier is not available (not offered, usage limit): for `scout` and `worker` work use the next lower tier and say so in the report; for `reviewer` and orchestrator work use the next higher tier, or wait; the floor for a reviewer's tier is in AGENTS.md "Fresh review".

Log the model with each delegated task (in the handoff or the project's task log), so first-attempt pass rates can be compared by model.

## Fallbacks (claude.ai chat: no `.claude/agents/`, no Claude Code hooks)

| Feature | Fallback, in order |
|---|---|
| Subagent (`scout`, `worker`) | 1. The Agent tool, with the brief below. 2. Do the task yourself, one at a time. |
| Fresh `reviewer` | 1. A subagent with only the diff and the brief. 2. A new chat given only the diff and the brief. 3. Review it yourself and label it "self-review", never "independent review". |
| `worker_guard.py`, Stop hook | `scripts/git-hooks/pre-push` still blocks force-pushes and deleting main. Give each worker its own branch; check it (`git log origin/main..<branch>`, `git diff --stat`) before the merge; before the end of each turn run `echo '{}' \| python3 scripts/stop_check.py` (exit 2 = commit or push first). |

Branch per worker: the branch the host requires (Claude cloud sessions: `claude/…`), else `claude/<topic>`. Log the model with each delegated task.

## When to delegate

- Size rule: AGENTS.md "Delegation". Where the host has no subagents, do it yourself. Do other small tasks yourself.
- Keep for the orchestrator: merges, conflict choices, design and open decisions, artifacts, deploys, release versions.
- One worker at a time by default. Two only when their allowed files do not overlap. Start each worker in its own worktree (`isolation: "worktree"`; elsewhere `git worktree add ../<repo>-<topic> -b <branch>`).

## Brief (put it in the Agent prompt)

- Goal and why, with the doc sections it implements.
- Branch name (see Fallbacks: "Branch per worker") and base commit.
- Allowed files: name every file it may touch.
- Done criteria that can be measured (numbers, test names, PASS lines).
- Checks to run.
- "No design decisions: list candidates with trade-offs."
- "A blocked command or a blocked check stops the task: report it; do not run it another way and do not change the text to pass."
- "Read each skill you need in full with the Read tool, never by grep or sed."
- For a change made to pass a check: the design goal, not the metric (AGENTS.md "Fresh review").
- The tier and model, when the routing table says strong.

## Review and merge

1. Scope: `git diff --stat origin/main...origin/<branch>`. Flag files outside the brief.
2. Update by merge (AGENTS.md "Git history"): `git checkout -B review/<branch> origin/<branch> && git merge origin/main`. When intents conflict, stop and list the choice for the Maintainer.
3. Fresh review: `reviewer` with only the diff and the brief. Verify each finding before you report it. Before the review, run `python3 scripts/worker_guard.py --scan origin/main...origin/<branch> <scratch folder>` on the worker's branch and scratch folder, and give its findings to the reviewer. Any workaround of a guard (a string rebuilt to pass the content check, a command wrapped in a file to pass the worker guard), in the diff or in scratch output, is a MAJOR finding.
4. Checks: the commands in AGENTS.md "Commands". Report before and after numbers.
5. Merge: the steps of `.claude/skills/deliver/SKILL.md`.

## File areas (fill in per project, in AGENTS.md "Project rules")

| Area | Owner | Files | May push to |
|---|---|---|---|
| Orchestrator | strongest available model (default: Claude Opus) | Everything not in another lane | its own branch; merges by pull request |
| Worker | `worker` subagent | Only its brief's files | its own branch (see "Branch per worker") |
