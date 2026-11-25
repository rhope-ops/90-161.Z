---
name: rule-change
description: Use when the Maintainer asks to add, change or remove a rule, when a rule or skill change would help, for Suggest in a turn summary, and on a check.sh rule line.
---

# Change a rule

AGENTS.md "Rule text" holds the gate: the Maintainer approves the exact text. This file holds the steps. Each rule costs tokens in every session, so the first question is whether it must be a rule.

## Where it belongs (use the first that fits)

1. A hook, check or test can enforce it: build that, and keep at most a pointer in AGENTS.md.
2. Only some tasks need it, or it has steps: a skill in `.claude/skills/` (extend one that exists; in a project, the skill's PROJECT.md).
3. It applies to this project in every session: one line in AGENTS.md "Project rules".
4. It is personal style for every chat: the Maintainer's account preferences. You cannot change them; give the full text to paste.
5. It applies to one task or thing: a row in docs/DECISIONS.md. That is a record, not a rule.

A change to "Hard rules" or "Defaults" is a change of the kit: make it in the kit repo (AGENTS.md "Kit files").

Before a new rule, check or stricter cap: list what it would fail today in every fleet repo, with a fix plan, in `docs/reviews/YYYY-MM-DD-<topic>-debt.md`, with the line `debt-check: <hash>` for the hash that `python3 scripts/bloat_check.py --rules` prints (T5).

## Suggest (end-of-turn summary)

- At most 3 items. Leave the part out when you have none.
- Suggest only after one of: a correction by the Maintainer; the same event 2 times; a measured cost (time, tokens, a failed check). A review finding alone is not a reason.
- Each item, in this form:

```text
Suggest 1 (new rule | change | retire | new skill | speed-up): <the exact text, or the exact change>
Why: <the trigger, with its evidence>. Replaces: <the line it replaces, or "nothing">. Home: <file and section>.
```

- Do not repeat an item the Maintainer declined in this session.

## Approval

- Show the exact text in full: in the turn, in a plan, or in the pull request text. One approval covers every text shown that way; the Maintainer's merge of a lane C pull request approves the rule texts its text shows.
- A short answer ("ok", "1", "a") counts only when one reading is possible. If not, show the text again and ask.

## Steps

1. Search AGENTS.md (all sections, and the header values such as `- Time zone:`) and docs/DECISIONS.md for the same topic. If a line or a header value exists or conflicts, show both and ask which wins (two rules that disagree make agents act at random).
2. Write one line, as a positive instruction with its reason in brackets where the reason is not plain ("Do Y (because Z)"). Keep "never" for hard rules.
3. At a cap (below), the same change removes a line (one in, one out). The caps are the Maintainer's decision (`KIT_CAPS` in `scripts/bloat_check.py`).
4. Record the approval as a row in docs/DECISIONS.md (date, scope, what it replaces).
5. Run `python3 scripts/bloat_check.py --rules` and fix or explain each lint line (below).
6. A hard rule (a line in "Hard rules", or a project rule marked "(cannot be changed)"): run its scenario in `.claude/rule-tests.md` and the conflict check (below). A default or another project rule: step 1 is the conflict check.

## Rule lint (warn only)

`python3 scripts/bloat_check.py --rules` lints the changed rule lines; `--lint` lints every rule (the audit uses it). A WARN line names one of:

- near-duplicate: two rule lines share most of their words. Merge them, or make each one say what the other does not.
- vague: a word such as "appropriate", "where possible" or "should". Name the condition or the number.
- untested: the rule's label has no scenario in `.claude/rule-tests.md` (column "Section") and the rule names no script that enforces it. Add a scenario, or enforce it with a hook or check.

## Conflict check (fresh context, hard rules)

The author's own context does not see its conflicts (the Maintainer, 2026-11-16). When rule lines change against origin/main, `--rules` prints a hash, and the full lane fails until a record names it.

1. Start a fresh reviewer (the `reviewer` subagent; without subagents, a new session) on your model tier or higher: set the model when you start it. Give it only: the changed lines as `--rules` lists them, the whole AGENTS.md, docs/DECISIONS.md, and this brief: "Find conflicts (two rules that give different orders for one case), overlaps (two rules that say the same), and rules that a decision row contradicts. For each: the two texts, the case, and a fix. Do not judge whether the rules are good." Do not give it your view.
2. Write its result to `docs/reviews/YYYY-MM-DD-rule-conflict.md`: the changed lines, the reviewer and model tier, the findings, and the line `rule-conflict-check: <hash>`. A record without the review is a false pass.
3. A MAJOR finding goes to the Maintainer before the merge, with a recommendation. Record MINOR findings; they do not change rule text again. A later change of the same lines makes a new hash: run the check again.
4. When only defaults or project rules changed, the record can be short: the changed lines, the result of step 1 of "Steps", and the hash line.

## The caps

`python3 scripts/bloat_check.py --rules` prints the line count of AGENTS.md and the session load (the start-read files plus the skill and agent names and descriptions) against their caps, the rule bullet counts (a guide: over 28 kit bullets or 15 project rules only warns), each rule line added or removed against origin/main, and each path that AGENTS.md names but that does not exist. `scripts/check.sh` runs it and fails when a cap is passed, a path is missing, a skill or agent file states a rule that has its home in AGENTS.md (`SINGLE_HOME` in `scripts/bloat_check_skills.py`), or (full lane) the conflict check of changed rule lines has no record.
