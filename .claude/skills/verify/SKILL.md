---
name: verify
description: Use when asked to run, start, open or screenshot the app, and before you report that a change works, is verified, or a UI change is done.
---

# Run, prove and measure

AGENTS.md "Verification" points here. The commands live in AGENTS.md "Commands", not in this file.

## 1. Find the commands

- Read AGENTS.md "Commands" (Build, Test, Lint, and Start when the project has that line) and use the lines as written.
- A line says "not set yet", or there is no Start line: look in README.md, then the manifest (package.json scripts, Makefile, pyproject.toml), then .github/workflows. Take only a build, test, lint or local start command, not a deploy, release, publish or data-write step. Read what the candidate runs before you run it, then run it one time. If it works, use it, and put the exact line for "Commands" in your report (the Maintainer approves a change of AGENTS.md).
- The change has nothing to run (rules or docs only, or the repo has no app): say so, run Test, and go to "Report".

## 2. Run the checks

Run Test, and Build and Lint when they are set. Keep the result line of each (counts, PASS or FAIL). On a fail: fix it or report it.

## 3. Start the real thing

| Project type | Start | Proof |
|---|---|---|
| Static page (no build step) | `python3 -m http.server 0 --bind 127.0.0.1` in its folder (port 0 = a free port; read the port from the first output line), or open the file with Playwright | Load it, do the changed action, read the result from the page; 0 console errors |
| Web server or API | The start command in the background; wait until the port answers | Request the changed route; status and body |
| Command-line tool or script | Run it with the smallest real input | Exit code and output |
| Library | A short script that imports and calls the changed function | Return value |
| Runs only somewhere else (a locked-down computer, a hosted platform) | Cannot start here | Run what can run here (syntax check, unit tests, package build). Report "not run here", what must be run there and what to send back |

Use invented test data only. Screenshots and scratch files go in a temp folder, not the repo.

## 4. Prove the change

1. Before you run, write what you will see if the change works and what you will see if it does not.
2. Use the changed behavior itself, then one behavior next to it that must stay the same.
3. A visual change: section 5. A data write: first `.claude/skills/data-change/SKILL.md`.
4. Stop each server and browser you started.

## 5. A visual or UI change: measure, do not judge by eye

```bash
node .claude/skills/verify/measure.mjs <url-or-html-file> [out-dir]
```

It needs Playwright (`require('playwright')` must resolve). Without an out-dir, screenshots go to a new temp folder; the script prints the paths. For each width (375, 1440 px) and scheme (light, dark) it saves a full-page screenshot and checks:

| Check | Pass |
|---|---|
| Text contrast (WCAG AA) | 4.5:1; 3:1 for large text (24 px, or 18.66 px bold) |
| Interactive targets | at least 24×24 px (a link inside a sentence is exempt, as in WCAG 2.5.8) |
| Horizontal page scroll | 0 px |

Exit 0 = all pass. Text on an image or a gradient is listed as "unchecked": check it by hand and say so.

The script does not check these. Measure them with `getBoundingClientRect()` in the page, and report the numbers:

- Spacing that the change touches: before and after, in px. A shift nobody asked for is a fail.
- Contrast of UI parts that are not text (input borders, focus ring, icons): 3:1 against the next colour.
- Focus: Tab reaches each control in order, and the focus is visible.
- Reduced motion: with `prefers-reduced-motion: reduce`, nothing moves that is not needed.

## Report

- Each command you ran, with its result line.
- What you saw (value, status, text) next to what you expected.
- A UI change: one line per width and scheme from the script, the hand checks with their numbers, and, to show the Maintainer the change, the link to an HTML artifact of the page with invented data (the content check reads HTML, not a PNG; the screenshots are for your own checks).
- "verified" only when the checks (section 2) passed and the change was proven (section 4, and section 5 for a UI change with every check passed or each fail listed with its cause). A change with nothing to run: verified by the checks alone, and say so. Otherwise "done, not verified", with what did not run and why.
- The proposed "Commands" lines, when a line was "not set yet" or missing.
