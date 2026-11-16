---
name: rule-change
description: Use when the PFM asks to add, change or remove a rule, when you think a rule, a skill or a process change would help, when you write the Suggest part of an end-of-turn summary, when the rule cap check fails, when check.sh shows a rule lint WARN or asks for a conflict check, and before you edit AGENTS.md "Project rules". Gives where a rule belongs, the Suggest format, what counts as the PFM's approval, the conflict search, the rule lint, the fresh-context conflict check and the caps.
---

# Change a rule

AGENTS.md "Rules and decisions" points here. Rules grow fast and each one costs tokens in every session, so a rule has one gate: the PFM approves its exact text.

## Where it belongs (use the first that fits)

1. A hook, check or test can enforce it: build that, and keep at most a pointer in AGENTS.md.
2. Only some tasks need it, or it has steps: a skill in `.claude/skills/` (extend one that exists).
3. It applies to this project in every session: one line in AGENTS.md "Project rules".
4. It is personal style for every chat: the PFM's account preferences. You cannot change them; give the full text to paste.
5. It applies to one task or thing: a row in docs/DECISIONS.md. That is a record, not a rule.

## Suggest (end-of-turn summary)

- At most 3 items. Leave the part out when you have none.
- Suggest only after one of: a correction by the PFM; the same event 2 times; a measured cost (time, tokens, a failed check). A review finding alone is not a reason.
- Each item, in this form:

```text
Suggest 1 (new rule | change | retire | new skill | speed-up): <the exact text, or the exact change>
Why: <the trigger, with its evidence>. Replaces: <the line it replaces, or "nothing">. Home: <file and section>.
```

- Do not repeat an item the PFM declined in this session.

## Approval

- The PFM approves the exact text, shown in full in this turn or the turn before.
- A short answer ("ok", "1", "a") counts only when one item is open and one reading is possible. If not, show the text again and ask.
- A comment, a question, a complaint, a dialog answer on another topic, a review finding and your own recommendation are not approval.

## Before you write

1. Search AGENTS.md (all sections, and the header values such as `- Time zone:`) and docs/DECISIONS.md for the same topic. If a line or a header value exists or conflicts, show both and ask which wins (two rules that disagree make agents act at random).
2. One line, with its reason in brackets where the reason is not plain.
3. At the cap, the same change removes a line (one in, one out). Never raise a cap on your own: the caps are the PFM's decision (`budgets` in `.bloat-audit.json`).
4. Record the approval as a row in docs/DECISIONS.md (date, scope, what it replaces).
5. Full tier: run the scenario in `.claude/rule-tests.md` for the changed rule. Run all scenarios after a switch to a new Claude model family.
6. After the edit: the rule lint and the conflict check (below).

## Rule lint (warn only)

`python3 scripts/bloat_check.py --rules` lints the changed rule lines; `--lint` lints every rule (the audit uses it). A WARN line names one of:

- near-duplicate: two rule lines share most of their words. Merge them, or make each one say what the other does not.
- vague: a word such as "appropriate", "where possible" or "should". Name the condition or the number instead.
- untested: the rule's section has no scenario in `.claude/rule-tests.md` (column "Section") and the rule names no script that enforces it. Add a scenario, or enforce it with a hook or check.

Fix a flag, or say in the turn summary why it stays.

## Conflict check (fresh context)

When rule lines change against origin/main, `--rules` prints a hash, and the full lane fails until a record names it (kit decision, 2026-11-16: the author's own context does not see its conflicts).

1. Start a fresh reviewer (the `reviewer` subagent; without subagents, a new session) on a model tier no lower than yours: set the model when you start it, because the agent's default tier can be lower. Give it only: the changed lines as `--rules` lists them (`+` and `-`), the whole AGENTS.md, docs/DECISIONS.md, and this brief: "Find conflicts (two rules that give different orders for one case), overlaps (two rules that say the same), and rules that a decision row contradicts. For each: the two texts, the case, and a fix. Do not judge whether the rules are good." Do not give it your view.
2. Write its result to `docs/reviews/YYYY-MM-DD-rule-conflict.md`: the changed lines, the reviewer and model tier, the findings, and the line `rule-conflict-check: <hash>`. A record written without the review is a false pass: the same accepted risk as the check stamp, which no hook stops.
3. A finding goes to the PFM before the merge, with a recommendation. A later change of the same lines makes a new hash: run the check again.

## The caps

`python3 scripts/bloat_check.py --rules` prints the rule count of AGENTS.md (list items in the kit sections; list items, paragraphs and table rows in "Project rules", where each unindented line counts; a wrapped line belongs to its item only when it is indented) against the caps, each rule line added or removed against origin/main, and each path that AGENTS.md names but that does not exist. `scripts/check.sh` runs it and fails when a cap is passed, a path is missing, or (full lane) the conflict check of changed lines has no record. Starter tier: no script; count by hand, and run the conflict check all the same.

## Labels

Never cite a label alone (a rule or decision number, a proposal such as P5, a round such as R25). At its first mention in a turn, give its text in one line and a link.
