# First use

The agent runs this once, before any other work. It starts in one of three ways:

| Start | How the agent knows | What to do |
|---|---|---|
| The user asks to set up a project from the kit's URL (https://github.com/rhope-ops/archimedes_lever), and the agent is not in a clone of it | The user's message | Step 1, round 1. Then `git clone https://github.com/rhope-ops/archimedes_lever <name>`, where `<name>` is answer 1 in lower case with hyphens for spaces. Work inside that folder from now on and read its AGENTS.md. Then the rest of step 1, and step 2. If git is missing, tell the user how to install it (https://git-scm.com/downloads), or point to way A in README.md "Start here" |
| A plain clone of the kit, and the user says "initiate" (or start, or set up) | `scripts/first_use_check.py` says KIT. If it did not run: `git remote get-url origin` ends in `archimedes_lever` | Step 1, then step 2 |
| A repo made with GitHub's "Use this template" | `scripts/first_use_check.py` says FIRST USE: AGENTS.md still has template placeholders | Step 1, then step 3 (skip step 2) |

The check runs as the Claude Code SessionStart hook, or as the first step of AGENTS.md "Start of session" where hooks do not run (claude.ai chat).

**Cloud session in the full tier (11B) with the guard on and no denylist** (the check also says DENYLIST; in the URL start, run `python3 scripts/check_content.py --status` right after the clone): do step 4 right after step 1, before steps 2 and 3, so no work is lost.

## 1. Ask the questions

Ask the questions of a round together, in the clickable question dialog (4 questions at most per dialog); without it, a numbered list with lettered options. Explain each question in one plain sentence: the user may be new to GitHub. Mark your recommendation. A free-text answer comes through "Other".

Round 1, always:

| # | Question | Options |
|---|---|---|
| 1 | What is the project called? | Free text |
| 2 | What is it for, in one line? | Free text |
| 3 | Which time zone are you in? (for the dates and times agents give you) | A your local zone (rec): give a city or the IANA name, for example Europe/Berlin; the agent finds the IANA name · B UTC |
| 4 | Use the recommended settings for the rest? List them in the question: starter kit (the core rules, hooks and checks; the advanced parts can be added later), private repo, no license, agents call you "the owner", personal-data guard on (it only warns until you add your name list), a new GitHub repo the agent creates (for a clone). | A yes (rec) · B choose each one |

With 4A, use the "Recommended" column below for questions 5 to 12 and skip rounds 2 to 4. Exception: ask question 10 alone when the start needs a new repo and this host cannot create one (no GitHub tool and no signed-in `gh`).

Round 2, only with 4B:

| # | Question | Options | Recommended |
|---|---|---|---|
| 5 | Is the repo public or private? | A private · B public | A |
| 6 | Which license for the project? | A MIT · B Apache-2.0 · C none: all rights reserved | C for a private repo, A for a public repo |
| 7 | What should agents call you in the repo files? | A "the owner" · B a role, for example "the maintainer" · C your first name (private repos only; with the guard on, a name on your denylist blocks every push, so choose C only with the guard off) | A |
| 8 | Turn on the personal-data guard? It blocks emails, phone numbers, ID numbers, API tokens, private keys and your listed names before a push. | A on · B off | A |

Round 3, only with 4B; ask only the questions that apply:

| # | Question | When | Options | Recommended |
|---|---|---|---|---|
| 9 | Where will you work on the project? | always | A Claude cloud sessions (claude.ai/code) · B your own computer · C both | where this session runs |
| 10 | Where does the new repo go? | clone and URL starts | A I create it on GitHub now (needs a GitHub tool on this host or a signed-in `gh`) · B you create an empty repo on GitHub (no README, no license) and paste its URL · C local only for now (the Stop hook then reminds you at each turn end until a remote exists) | A |
| 11 | Starter or full kit? Starter has the core rules, safety hooks and checks, and the name guard only warns until the list exists. Full adds multi-agent orchestration, a project log for a timeline, a scheduled bloat audit and rule tests, and the name guard blocks pushes until the list exists. | always | A starter · B full | A |

Round 4, only with 4B, 5B and 11B:

| # | Question | When | Options | Recommended |
|---|---|---|---|---|
| 12 | Where does the project log go? It records how the project went and can hold environment details, so a public repo should not show it. | public repo (5B) | A a private Claude doc · B in the repo, visible to all (docs/LOG.md) · C no project log | A when this host has Claude docs, else C |

Rules for the asking agent:
- A public repo never uses a real name (question 7, option C is refused).
- Never ask for the names on the denylist. The user types them only in the places in step 4. If the user pastes names into the chat, do not repeat them, and tell the user that they are now in the chat history.

## 2. Move a clone of the kit to its own repo (clone and URL starts only)

1. `git remote rename origin kit`. The kit stays as a second remote; nothing is deleted.
2. For 10A: create the repo (public or private as in answer 5) with the host's GitHub tool, or `gh repo create <user>/<name> --private` (or `--public`); find `<user>` with the tool or `gh api user --jq .login`. Then `git remote add origin https://github.com/<user>/<name>.git`. For 10B: `git remote add origin <URL>`. For 10C: no remote; use `<user>/<name>` as planned for bootstrap's repo argument.
3. Start a fresh history, as GitHub's "Use this template" does: `git branch -m main kit-main`, then `git checkout --orphan main`. The files stay as they are; the bootstrap commit in step 3 becomes the project's first commit. Nothing is deleted: the kit's history stays on the local branch `kit-main` and the `kit` remote, and is never pushed to the new repo.
4. The folder keeps the name it was cloned as; the user can rename it after the session.

## 3. Apply the answers

1. Run `scripts/bootstrap.sh "<1>" <owner/repo from git remote get-url origin> "<2>" "<7>" "<3>" <11>`. Give "the owner" as the 4th argument when that is the answer. The 5th argument is the IANA time zone name (UTC for 3B). The 6th is `starter` (11A) or `full` (11B). The script deletes itself when done; keep this file, because step 4 is also what an agent shows when a session reports DENYLIST. It moves the kit's license to docs/archimedes_lever-LICENSE.txt: keep that file, because it covers the kit's scripts.
2. Project log (answer 12, public repos in the full tier only): for A, make a private Claude doc named "<1> project log" with the Arcs and Log tables of docs/LOG.md, delete docs/LOG.md, and add to AGENTS.md "Project rules": "Project log: <doc link> (the owner, YYYY-MM-DD)". For B, keep docs/LOG.md. For C, delete docs/LOG.md and add to "Project rules": "No project log (the owner, YYYY-MM-DD)".
3. Guard (answer 8): for B, delete `.check`: the pre-push hook and the Action then skip the scan. The tool-call hook still scans.
4. License (answer 6): for A, copy docs/archimedes_lever-LICENSE.txt to `LICENSE` and change the copyright line to the current year and the GitHub account or organization from `<owner/repo>`, unless the user names another holder (a public repo never uses a real name the user has not given). For B, save the text from https://www.apache.org/licenses/LICENSE-2.0.txt, unchanged, as `LICENSE`. For C, add no LICENSE.
5. Record the answers as the Maintainer's decisions in docs/DECISIONS.md (with 4A, one row: "Recommended settings" and the list), and add one `decision` row to the project log (full tier only; not for 12C).
6. Commit with a noreply identity, and run `scripts/session_checkin.sh` (it installs the git hooks). Do not push yet: step 4 comes first.

## 4. The denylist, then the first push

With the guard on (8A) in the full tier (11B), every push and every pull-request check fails until a name denylist exists. In the starter tier (11A), bootstrap adds `denylist: warn` to `.check`: a push with no list only warns, and every other check still runs. Ask for the list in both tiers. The user types the names, comma or newline separated: their names, username variants, employer. Run `python3 scripts/check_content.py --status`; it prints a count, never the names.

| Place | When | Where the user adds it |
|---|---|---|
| The user's computer | 9B or 9C | The file `~/.config/pii-guard/denylist.txt`, one name per line. macOS or Linux: `mkdir -p ~/.config/pii-guard && nano ~/.config/pii-guard/denylist.txt`. Windows (PowerShell): `mkdir -Force $HOME\.config\pii-guard; notepad $HOME\.config\pii-guard\denylist.txt` |
| Each Claude cloud environment the repo uses | 9A or 9C | Environment menu in the session title bar > Edit > Environment variables: `PII_GUARD_DENYLIST=Name1,Name2,...`. Only a new session reads it |
| GitHub pull-request check | always (after the first push is fine) | `https://github.com/<owner/repo>/settings/secrets/actions` > New repository secret > Name `PII_GUARD_DENYLIST` |

Optional second list, the Maintainer's own blocked terms (words that are not personal data: a client, a code name). Same format and the same three places, under other names: the file `~/.config/check/terms.txt`, the cloud environment variable `CHECK_TERMS`, and the repository secret `CHECK_TERMS`. With no terms list, nothing is missing: the check runs without it. `scripts/check.sh --status` prints the count and a fingerprint of each list, never the words.

One master copy: the user keeps the list in one file in their own Google Drive and edits only that file. A computer with Drive for desktop reads it directly (set `PII_GUARD_DENYLIST_FILE` to the synced path); the cloud variable and the GitHub secret are pasted copies of it. An agent never opens the master file. To find a copy that differs, compare the fingerprint: `python3 scripts/check_content.py --status` in each place and the last line of the pull-request check print the same 8 characters when the lists are the same.

Then:

- **`--status` shows a list:** push (`git push -u origin main`; for 10C, skip the push) and go to step 5.
- **Full tier, on the user's computer, no list:** give the user the command for their system from the table, ask them to type the names in the editor and save, and wait for "done". Run `--status` again, then push.
- **Starter tier (11A), no list:** push, then give the user the rows of the table for their places under Copy as a follow-up step, and say that names are not checked until the list exists.
- **Full tier, in a cloud session, no list:** do not bootstrap and do not push: a cloud session reads the variable only when it starts, and its unpushed work is lost when it ends. Give the user (1) the cloud row from the table with the steps, and (2) under Copy, a prompt for the new session with every answer given so far (1 to 4, and 5 to 12 after 4B), for example `Please read the repo and initiate. My first-use answers: 1: Recipe box, 2: Family recipes in one place, 3: Europe/Berlin, 4: A`. Tell the user: add the variable, start a new session on the same repo, paste the prompt. In that session, use the given answers and ask only what is missing.

## 5. Verify and hand over

1. Run `python3 scripts/check_content.py --status` and `python3 scripts/check_content.py --all` (it must print `CONTENT CHECK PASS`), then `scripts/check.sh`. Report the result lines.
2. Give the user the claude.ai Project text from docs/host-prompts.md under Copy, for use in a claude.ai Project.
3. Tell the user, in plain words: what was set up (with links to the repo and to AGENTS.md); what is left (the GitHub secret, other cloud environments); and how to go on: open the project with any agent and say what they want next; the agent reads docs/NEXT_PROMPT.md first.
