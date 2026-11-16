---
name: run-verify
description: Use when asked to run, start, open or screenshot this project's app, and before you report that a change works ("does it work", "test it", "verified"). Takes the commands from AGENTS.md "Commands", starts the real thing and proves the change by what it does, not only by a passing test run. Covers a project whose commands are "not set yet", an app that cannot run in this workspace, and the report format.
---

# Run and verify

AGENTS.md "Verification" points here. The commands live in AGENTS.md "Commands", not in this file.

## 1. Find the commands

- Read AGENTS.md "Commands" (Build, Test, Lint, and Start when the project has that line) and use the lines as written.
- A line says "not set yet", or there is no Start line: look in README.md, then the manifest (package.json scripts, Makefile, pyproject.toml), then .github/workflows. Take only a build, test, lint or local start command, never a deploy, release, publish or data-write step. Read what the candidate runs before you run it, then run it one time. If it works, use it, and put the exact line for "Commands" in your report. Do not edit AGENTS.md unasked (AGENTS.md "Rules and decisions").
- The change has nothing to run (rules or docs only, or the repo has no app): say so, run Test, and go to "Report".

## 2. Run the checks

Run Test, and Build and Lint when they are set. Keep the result line of each (counts, PASS or FAIL). On a fail: fix it or report it. Never skip a check (AGENTS.md "Checks").

## 3. Start the real thing

| Project type | Start | Proof |
|---|---|---|
| Static page (no build step) | `python3 -m http.server 0 --bind 127.0.0.1` in its folder (port 0 = a free port; read the port from the first output line), or open the file with Playwright | Load it, do the changed action, read the result from the page; 0 console errors |
| Web server or API | The start command in the background; wait until the port answers | Request the changed route; status and body |
| Command-line tool or script | Run it with the smallest real input | Exit code and output |
| Library | A short script that imports and calls the changed function | Return value |
| Runs only somewhere else (a locked-down computer, a hosted platform) | Cannot start here | Run what can run here (syntax check, unit tests, package build). Report "not run here", what must be run there and what to send back |

Use only invented test data, never production or personal data (AGENTS.md "Personal data"). Screenshots and scratch files go in a temp folder, never the repo.

## 4. Prove the change

1. Before you run, write what you will see if the change works and what you will see if it does not.
2. Use the changed behavior itself, then one behavior next to it that must stay the same.
3. A visual change: also `.claude/skills/ui-verify/SKILL.md`. A data write: first `.claude/skills/data-change/SKILL.md`.
4. Stop each server and browser you started.

## Report

- Each command you ran, with its result line.
- What you saw (value, status, text) next to what you expected.
- "verified" only when the checks (section 2) passed and the change was proven (section 4). A change with nothing to run: verified by the checks alone, and say so. Otherwise "done, not verified", with what did not run and why.
- The proposed "Commands" lines, when a line was "not set yet" or missing.
