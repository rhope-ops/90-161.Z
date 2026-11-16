---
name: personal-data
description: Use when the personal-data guard (scripts/pii_guard.py) blocks a push or a pull-request check, when a session reports DENYLIST, when you must check the guard's state or tier, and before you set up or change `.pii-guard`. Gives what the guard checks, how to fix a blocked push, where the name denylist lives and what only the PFM may do.
---

# Personal-data guard

AGENTS.md "Personal data" points here. What each tier blocks, in full: the header of `scripts/pii_guard.py`.

## State

- On or off: a `.pii-guard` file at the repo root turns the guard on in the pre-push hook and the pull-request Action.
- Check it: `python3 scripts/pii_guard.py --status` prints the denylist source, a count, a fingerprint and the tier. It never prints names.
- Tiers: minimum (no option line) and DoD (the line `profile: dod` in `.pii-guard`).
- With the guard on, a push with no name denylist fails. The line `denylist: warn` in `.pii-guard` (starter tier) makes it warn and still check every other pattern.

## When the guard blocks

1. Read the masked findings. Do not copy the data into chat, a commit message or a log.
2. Remove the data from the files. If it is in an unpushed commit, fix that commit.
3. Push again. Never push with `--no-verify`.
4. A finding that is not personal data (a public reference text, an example value): tell the PFM. Only the PFM adds an allow or `skip:` entry to `.pii-guard`.

## The denylist

- The names live outside the repo. The places, and what the PFM types where: docs/FIRST_USE.md, step 4.
- Never ask for the names in chat, never commit the list, and never open the PFM's master file.
- A session that reports DENYLIST has no list: tell the PFM which place is missing.
