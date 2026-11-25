---
name: personal-data
description: Use when the content check blocks a push, pull request or tool call, before you send content the hook does not cover, on DENYLIST, and before a `.check` change.
---

# The content check (personal data, secrets, blocked terms and files)

AGENTS.md "Secrets and personal data" points here. Every pattern, tier and limit: the header of `scripts/check_content.py`.

## State

- `scripts/check.sh --status` prints each word list's source, count and fingerprint (never the words) and the tier.
- The settings file `.check` at the repo root turns on the scan of pushes (pre-push hook) and, in a public repo, of pull requests (the "checks" Action). Its lines: an allowed exact string, `skip: <path or glob>`, `block: <path or glob>` (a file that must not be committed or sent), `denylist: warn`, `profile: dod`, `content-max-bytes: <n>` (the size limit of one scanned file; the tool-call hook keeps its own total limit per call). The old name `.pii-guard` is read while `.check` is absent.
- Tiers: minimum (no profile line) and DoD (`profile: dod`).
- Word lists, both outside the repo: names (personal data; a push with no list fails, unless `.check` has `denylist: warn`) and terms (the Maintainer's own blocked words; optional).
- Private repo: the pre-push hook (every tracked file) is the gate; the Action does not run on pull requests (Actions minutes), so an edit made in the GitHub web page is not scanned until the next manual run. A binary file that enters only through a merge resolution, and content already on the base branch, are scanned only by the hook or a manual run of the Action.

## The hook

In Claude Code a PreToolUse hook (`.claude/settings.json`: `scripts/check.sh --hook`, about 50 ms) scans these calls before they run. A finding blocks the call, and so does any error in the scan (fail closed).

| Tool | What is scanned |
|---|---|
| Write, Edit, NotebookEdit | The new text (also in a file that a `skip:` line names), and the path against the `block:` lines. The old text of an edit is not scanned, so an edit can remove a finding. |
| Bash | The command, only when it can send something out: a network or publishing client, a URL, or a git verb that publishes text (the lists: `CLIENTS` and `GIT_OUT` in `scripts/check_content_hook.py`), and every command with a backslash at a line end. |
| Agent, SendMessage, task and session messages, scheduled tasks, environment scripts | Every string of the call. |
| Artifact, SendUserFile | Every string, and the files the call names (a file over 2 MB, a PDF or a binary blocks; so do named files over 8 MB in total and a `file_path` that does not exist). |
| WebFetch, WebSearch; GitHub pull-request, issue, comment, review and file calls; Gmail sends and drafts; Claude Docs; Google Docs, Drive, Sheets; Calendar writes | Every string. In a Gmail call, an address in the top-level `to`, `cc`, `bcc` is no finding. |

Not covered: claude.ai chats (no hooks), a Bash command that builds its payload at run time (a script file, a variable), and tools the matcher in `.claude/settings.json` does not name. For those, scan first: `printf '%s' "$TEXT" | scripts/check.sh --content --stdin --label brief`, or name the file: `scripts/check.sh --content <file>` (a missing or unreadable path fails).

- Commit messages and pushed files are scanned by the pre-push hook; do not scan them again by hand.
- In code, comments and tests, build a sample address from parts ("jane" + "@" + ...) or use an example.com address; never write one whole.

## When it blocks

1. Read the masked findings. Do not copy the data into chat, a commit message or a log.
2. Remove the data. If it is in an unpushed commit, fix that commit.
3. Push or call again.
4. A finding that is wrong (a public reference text, an example value): tell the Maintainer. AGENTS.md "Guards and checks" says who may add an entry to `.check`. A private repo may put its owner's real name in the `- Owner:` line of AGENTS.md.
- A block on invented test data: describe the pattern in words (for example "a 9-digit SSN with dashes"); never rebuild the string to pass the check.

## The word lists

- Where each list lives, and what the Maintainer types where: docs/FIRST_USE.md, step 4. The terms list uses the same places under the names `CHECK_TERMS` (environment variable or Actions secret) and `~/.config/check/terms.txt`.
- Never open the Maintainer's master file.
- A session that reports DENYLIST has no name list: tell the Maintainer which place is missing.
