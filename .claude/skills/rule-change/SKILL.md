---
name: rule-change
description: Use when the PFM asks to add, change or remove a rule, when you think a rule, a skill or a process change would help, when you write the Suggest part of an end-of-turn summary, when the rule cap check fails, and before you edit AGENTS.md "Project rules". Gives where a rule belongs, the Suggest format, what counts as the PFM's approval, the conflict search and the caps.
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

## The caps

`python3 scripts/bloat_check.py --rules` prints the rule count of AGENTS.md (list items in the kit sections; list items, paragraphs and table rows in "Project rules"; a wrapped line belongs to its item) against the caps, each rule line added or removed against origin/main, and each path that AGENTS.md names but that does not exist. `scripts/check.sh` runs it and fails when a cap is passed or a path is missing. Starter tier: no script; count by hand.

## Labels

Never cite a label alone (a rule or decision number, a proposal such as P5, a round such as R25). At its first mention in a turn, give its text in one line and a link.
