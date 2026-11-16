---
name: personal-data
description: Use when the personal-data guard (scripts/pii_guard.py) blocks a push, a pull-request check or a tool call, before you publish, delegate or send content (artifact, agent brief, pull-request text, doc, mail, message) that the hook does not cover, when a session reports DENYLIST, when you must check the guard's state or tier, and before you set up or change `.pii-guard`. Gives what the guard checks, what the hook scans, how to scan other content, how to fix a block, where the name denylist lives and what only the PFM may do.
---

# Personal-data guard

AGENTS.md "Personal data" points here. What each tier blocks, in full: the header of `scripts/pii_guard.py`.

## State

- On or off: a `.pii-guard` file at the repo root turns the guard on in the pre-push hook and the pull-request Action.
- Check it: `python3 scripts/pii_guard.py --status` prints the denylist source, a count, a fingerprint and the tier. It never prints names.
- Tiers: minimum (no option line) and DoD (the line `profile: dod` in `.pii-guard`).
- With the guard on, a push with no name denylist fails. The line `denylist: warn` in `.pii-guard` (starter tier) makes it warn and still check every other pattern.

## Before you send (the hook)

- In Claude Code on this repo, a PreToolUse hook (`.claude/settings.json`, `pii_guard.py --hook`, about 50 ms) scans each outgoing call before it runs: Agent briefs, Artifact pages and the files they publish, SendUserFile, WebFetch and WebSearch, GitHub pull-request, issue, comment and review calls, Gmail sends and drafts, Claude Docs and Google Docs, Drive and Sheets writes, and messages, sessions and scheduled tasks to other sessions. A finding blocks the call, and so does a named file it cannot scan (over 2 MB, a PDF, a binary) or any error in the scan (fail closed); no extra step for you. One exception: an email address in the top-level recipient fields of a Gmail call (`to`, `cc`, `bcc`) is no finding; a secret or a denylist name there still blocks. Named files over 8 MB in total, or a `file_path` that does not exist, also block. With no denylist (`--status` says none), names are not checked and the hook says nothing.
- Not covered: claude.ai chats (no hooks), Google Calendar (an invite always holds addresses), Bash commands that send data (`curl`, `gh`), and tools the matcher does not name. For those, scan the text first: `printf '%s' "$TEXT" | python3 scripts/pii_guard.py --stdin --label brief`, or name the file: `python3 scripts/pii_guard.py <file>` (a missing or unreadable path fails, never passes).
- Commit messages and the files you push are scanned by the pre-push hook; do not scan them again by hand.
- In code, comments and tests, build a sample address from parts ("jane" + "@" + ...) or use an example.com address; never write one whole.
- End-of-turn summary line: `PII: hook on; N block(s)` (plus each `--stdin` scan you ran). The hook keeps no count: N is the blocks you saw.

## When the guard blocks

1. Read the masked findings. Do not copy the data into chat, a commit message or a log.
2. Remove the data from the files. If it is in an unpushed commit, fix that commit.
3. Push or call again. Never push with `--no-verify`, and never change the hook to get past a block.
4. A finding that is not personal data (a public reference text, an example value): tell the PFM. Only the PFM adds an allow or `skip:` entry to `.pii-guard`.

## The denylist

- The names live outside the repo. The places, and what the PFM types where: docs/FIRST_USE.md, step 4.
- Never ask for the names in chat, never commit the list, and never open the PFM's master file.
- A session that reports DENYLIST has no list: tell the PFM which place is missing.
