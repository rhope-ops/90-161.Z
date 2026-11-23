---
name: project-log
description: Use before you write or change a project log row, and when a decision, milestone, breakthrough or miss happens.
---

# Project log: how to write a row

AGENTS.md "Project log" points here; `python3 scripts/log_check.py` checks the format. The log records how the project got there (milestones, breakthroughs, misses, decisions) for a timeline and a narrative deck. A public repo keeps it in a private place, because entries can hold environment or security detail.

- One row per story event (the types below). Not a change log: no row per commit, merge or file change; git log holds those. Columns, in this order: # | When | Type | Arc | Topic | Raised by | What the other missed | Evidence | Result.
- When: `YYYY-MM-DD HH:MM` in the project time zone (the `- Time zone:` line at the top of AGENTS.md). A range: `YYYY-MM-DD HH:MM–HH:MM`. Mark an estimate with `~` before the date or the time.
- Type, one of:
  - `milestone`: a deliverable exists or a goal is met (first import works, v1 published).
  - `breakthrough`: a test or idea removes a blocker or changes direction.
  - `miss`: a wrong assumption, failed test or dead end. Record it honestly for both sides.
  - `decision`: the Maintainer decides, or overrules a recommendation. Also record it in docs/DECISIONS.md.
- Arc: a short kebab-case name for the narrative thread (for example `email-delivery`). Each arc has one row in the Arcs table: Arc | Span | Summary (one sentence) | Problem | Turning point | Outcome | Lesson.
- Story fields (they feed a narrative deck): Problem = why it mattered and the cost before, with a number where one exists. Turning point = the row(s) that changed direction, as #N. Outcome = the result, before → after. Lesson = what you would tell another team. Each field rests on rows or evidence in the log; write `-` until it is known, never invent. Update the arc row when its arc gets a milestone, breakthrough or miss.
- Story outline: `python3 scripts/timeline.py --outline story.md` (one section per arc, the source for a deck).
- Raised by: who first said it (the Maintainer, Claude, a named agent or person). "What the other missed": the gap on the other side, or `-`.
- Evidence: a commit, file, test or measurement. Never chat text alone.
