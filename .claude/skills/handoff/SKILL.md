---
name: handoff
description: Use when a session ends or pauses with work open, before compaction or a new chat, for a handoff, resume prompt, archive or session title, and when a session continues earlier work.
---

# Handoff

AGENTS.md "Handoff" points here. The next session cannot see this chat: it reads only the repo. A fact that is only in chat is lost.

## Write a handoff

1. docs/NEXT_PROMPT.md is a shared doc: pull just before you edit it, and make small edits, not a rewrite from an older copy.
2. Update docs/NEXT_PROMPT.md, within the AGENTS.md "Handoff" cap, in its sections:
   - `Updated:` date and time (the time zone in the AGENTS.md header) and who.
   - State: what is on main (commit), open branches and pull requests (full links), what runs now and who owns it.
   - Approved plan: the plan the Maintainer approved, with the approval date; mark each step done as it lands. A plan that does not fit the 40-line cap goes in docs/reviews/, with a link here. This section is the plan's canonical place (not docs/DECISIONS.md). A plan made from a source plan first lists every source item as in, out or later, with a count table; the Maintainer approves that list before the plan; `python3 scripts/log_check.py --coverage <file>` fails on an unmarked or "ask" row or a count mismatch (T7).
   - Open (in order): the next steps, one line each, with what "done" is.
   - Needs the Maintainer: each open decision in one line, with its options and the recommendation.
   - Do not: approaches that failed, with one line of why.
   - Where `.check` has the line `fleet: on`: also "Fleet format" below.
3. Put detailed evidence (logs, tables, review findings) in its own file in the place AGENTS.md "Handoff" names (`YYYY-MM-DD-<topic>.md`), and link it.
4. A decision by the Maintainer: a row in docs/DECISIONS.md (date, scope, what it replaces). Full tier: a story event also gets a project log row (the `project-log` skill).
5. Deliver it like any change (`.claude/skills/deliver/SKILL.md`): a handoff alone is lane A.
6. In the turn summary, give a resume prompt. This step is its home; other skills point here.
   - One code block, at most 100 words, that stands alone: goal, state, approved decisions, next step, full links.
   - Its first line is the next session's title without the date and pull request number (`RADE · Build round R31`), so that session starts named and adds its own date ("Session names").
   - Each claim in it is true on origin now (a commit that is pushed, a pull request that exists): the next session checks them.
7. Before you say a session can be archived: step 6 of "Session names".

In the kit clone itself (the KIT line at start), docs/NEXT_PROMPT.md is the template that projects get: do not fill it. The kit's own handoff file is docs/KIT_HANDOFF.md, with the same sections.

## Fleet format

Only where `.check` has the line `fleet: on` (the Maintainer, 2026-11-19). `scripts/check.sh` runs the format check (`scripts/fleet_harvest.py --check`).

- Under `Updated:`, the line `Next update: YYYY-MM-DD, <what it delivers>`.
- A section `## Timeline` after State, with lines `- YYYY-MM-DD · <milestone> · planned` (or `done`).
- Each "Needs the Maintainer" line: `- D<n> · <question or action> · Options: <A> / <B> · REC: <option>` (an action: `Options: done / not done`).
- `D<n>` is the next free ID of docs/DECISIONS.md, whose rows start with an `ID` column (D1 = oldest, never reused; `python3 scripts/fleet_harvest.py --add-ids` adds the column once). The decided item keeps its ID in its DECISIONS.md row.
- Port and harvest steps: https://github.com/rhope-ops/archimedes_lever/blob/main/docs/fleet.md.

## Session names

The Maintainer finds sessions by project and task (the Maintainer, 2026-11-19). The check-in prints the TITLE and SESSIONS lines; the steps need the session tools of a Claude cloud session (`set_session_title`, `set_session_tags`, `list_sessions`, `archive_session`). Without them, skip this section.

1. Title: `<Short name> · <Task, 2-6 words> · YYYY-MM-DD`. The short name is the AGENTS.md `- Short name:` value (when it is missing: the first word of the project name; in the kit clone: `Kit`; the TITLE line prints the result); the date is the day the session started, in the header's time zone; the task says what the session does, not what it was asked ("Build round R30", "Title bar fix, engine v23"). Set it at the start. Keep a title that already has this form (a resumed session); a title from a resume prompt gets today's date.
2. Tag: `project:<short name in lower case>` (for example `project:90-161.z`), once.
3. Pull request: when the session opens its first pull request, add ` · #<number>` at the end (`RADE · Title bar fix · 2026-11-19 · #118`). Later pull requests do not change the title.
4. Child sessions: a session you create gets a title of the same form and the same tag.
5. SESSIONS: list the sessions with this project's tag; report in one line each those that wait on the Maintainer (status "blocked", or a summary that names an action of the Maintainer), with their titles.
6. Archive: never archive a session yourself. When every pull request of the session is merged (its own, and those of the agents and scheduled tasks it started), nothing waits on the Maintainer, and no agent or scheduled task it started is pending, write in the turn summary that the session is ready for the Maintainer to review and archive. Archive it only when the Maintainer asks in their own message (the Maintainer, 2026-11-20). Otherwise, leave it open.

## Start from a handoff

1. Read docs/NEXT_PROMPT.md as AGENTS.md "Start of session" says. After a restart or a compaction (the RESUMED line at start), run the check-in for the git state, then continue the approved plan from its first step that is not done. Do not review the plan again or ask approved questions again; code reviews and checks still apply.
2. Check each claim against the repo before you act on it: is the commit on origin/main, is the pull request still open, does the file exist? A claim that fails is drift: report it.
3. If the handoff and the current request conflict, say so; AGENTS.md "Order of authority" decides.
