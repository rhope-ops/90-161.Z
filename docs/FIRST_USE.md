# First use

The agent runs this once, in a new repo made from the template, before any other work. `scripts/first_use_check.py` (the Claude Code SessionStart hook, or the first step of "Start of session") says when it is due: AGENTS.md still has template placeholders.

## 1. Ask the questions

Ask all questions of a round together. Use the clickable question dialog (4 questions at most per dialog); without it, a numbered list with lettered options. Mark your recommendation. A free-text answer comes through "Other".

Round 1: the project

| # | Question | Options |
|---|---|---|
| 1 | What is the project called? | Free text |
| 2 | What is it for, in one line? | Free text |
| 3 | Is the repo public or private? | A private (rec) · B public |
| 4 | What should agents call you in the repo files? | A "the owner" (rec) · B a role, for example "the maintainer" · C your first name (private repos only; with the guard on, a name on your denylist blocks every push, so choose C only with the guard off) |

Round 2: personal data and tools

| # | Question | Options |
|---|---|---|
| 5 | Turn on the personal-data guard? It blocks emails, phone numbers, .mil addresses, ID numbers and your listed names before a push. | A on (rec) · B off |
| 6 | Where will you push from? | A Claude cloud sessions · B your own computer · C both |

Rules for the asking agent:
- A public repo never uses a real name (question 4, option C is refused).
- Never ask for the names on the denylist. The owner types them only in the settings pages in step 3. If the owner pastes names into the chat, do not repeat them, and tell the owner that they are now in the chat history.

## 2. Apply the answers

1. Run `scripts/bootstrap.sh "<1>" <owner/repo from git remote get-url origin> "<2>" "<4>"`. Leave out the 4th argument for "the owner". The script deletes itself when done; keep this file, because step 3 is also what an agent shows when a session reports DENYLIST.
2. Public repo: add to AGENTS.md "Project rules" a line that names a private place for the project log (for example a private Claude doc), because the log can hold environment detail. Write the date and "(the owner, YYYY-MM-DD)".
3. Guard off (5B): delete `.pii-guard`. The hook, the merge check and the Action then skip the guard.
4. Record the answers as the owner's decisions in docs/DECISIONS.md, and add one `decision` row to the project log.
5. Commit with a noreply identity, run `scripts/session_checkin.sh` (it installs the git hooks), and push.

## 3. The denylist places (guard on)

The owner adds the names, comma or newline separated, in each place the answers need. Give the owner this list with the links filled in. The guard blocks every push and every pull request check where no denylist is found (decision 2A, 2026-11-11).

| Answer 6 | Place | Where the owner adds it |
|---|---|---|
| A or C | Each Claude cloud environment the repo uses | Environment menu in the session title bar > Edit > Environment variables: `PII_GUARD_DENYLIST=Name1,Name2,...`. A new session picks it up |
| B or C | The owner's computer | The file `~/.config/pii-guard/denylist.txt` (Windows: `C:\Users\<user>\.config\pii-guard\denylist.txt`), one name per line |
| Always | GitHub pull-request check | `https://github.com/<owner/repo>/settings/secrets/actions` > New repository secret > Name `PII_GUARD_DENYLIST` |

One master copy (the PFM, 2026-11-15): the owner keeps the list in one file in their own Google Drive and edits only that file. A computer with Drive for desktop reads it directly (set `PII_GUARD_DENYLIST_FILE` to the synced path); the cloud variable and the GitHub secret are pasted copies of it. An agent never opens the master file. To find a copy that differs, compare the fingerprint: `python3 scripts/pii_guard.py --status` in each place and the last line of the pull-request check print the same 8 characters when the lists are the same.

## 4. Verify

Run `python3 scripts/pii_guard.py --status` in each place you can reach. It prints `denylist: N entries from <source>; fingerprint <8 characters>` and the tier, never the names. Then `python3 scripts/pii_guard.py --all` must print `PII GUARD PASS`. Report both lines. A cloud environment edited during this session is verified in the next session: the SessionStart check says so if it is still missing.

Give the owner the claude.ai Project text from docs/host-prompts.md under Copy.
