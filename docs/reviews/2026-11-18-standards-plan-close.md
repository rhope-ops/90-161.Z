# Standards plan: close-out (90-161.Z)

Written 18 Nov 2026 (America/Chicago) by the session that ran the plan. The plan and the PFM's choices are in
docs/DECISIONS.md (rows of 17 Nov 26) and in rhope-ops/RADE docs/DECISIONS.md. The RADE side:
https://github.com/rhope-ops/RADE/blob/main/docs/reviews/2026-11-18-standards-plan-close.md

## Merged

| Stage | Pull request | What | Proof |
|---|---|---|---|
| 2 App fixes | 137 | One Hide-Site for the 7 task scripts; logo_draw refusals; bump_lock proves before it records; lock on engine-v14; R29a and R29b r5 | Full lane; `MASK pass=37`, `LOGODRAW pass=14`, `BUMPLOCK cases=22` |
| 3 Checker | 138 | RADE's four stricter checker files, unchanged; line cap 200 (44 files listed) | Full lane; files byte-identical to RADE main |
| 4 Repo baseline | 138 | .gitattributes, .editorconfig, SECURITY.md, Dependabot, pinned build dependencies, lint settings file | Full lane; the `scan` job ran with the pinned installs |
| 6 Windows PowerShell 5.1 | 140 | Workflow ps51: Test-Mask, Test-T20, Test-T21 | Green on 5.1.26100: `PS51 pass=3 fail=0` (37, 37, 72) |

Stage 5 (error handling) applies here by link: docs/code-standard.md points to the RADE standard, whose rule X7 says a
discarded error gives its reason. No count was made for scripts/gov: it would change the task scripts of a live round.

Device evidence: docs/reviews/2026-11-18-r29b-results.md (R29b r5 on engine-v14). R29a r5 has no result yet.

## For the PFM (GitHub settings; an agent cannot do these)

- Turn on secret scanning and push protection: https://github.com/rhope-ops/90-161.Z/settings/security_analysis
- Ruleset "protect main": require a pull request and the status check `scan` (not `ps51`: it runs only for some paths).
- Save the name denylist as a Dependabot secret `PII_GUARD_DENYLIST`, or Dependabot pull requests fail `scan`.
- Turn on private vulnerability reporting (SECURITY.md points to it).
- Confirm two versions that no document named: jszip 3.10.2 (the newest on npm) and jsonschema 4.26.0 (the installed one).

## Open points (MINOR findings of the reviews, not fixed)

- scripts/bump_lock.py restores only when a step stops with FAIL (not on another error or Ctrl-C), does not delete new files a
  failed build made, and finds the DECISIONS table head only after the checks.
- scripts/logo_draw.py still stops with a Python error on a path with too few numbers.
- Hide-Site masks the whole unbroken text around an @ (over-masking, no leak). It does not mask display names, office symbols,
  phone numbers, user ids or computer names (listed in its help and in tests/ps/Test-Mask.ps1).
- The 7 task scripts kept their revision numbers although their shared masking block changed (an agent's decision under
  delegation; the round skill says a fix adds 1).
- .editorconfig would add a final line end to 8 tracked files if an editor obeys it; four files with no extension
  (the pre-push hook among them) have no line-end rule in .gitattributes.
- scripts/build_decision_brief.js still names a global npm install in its header; no test runs that build, so the jszip pin is unproved.
- tests/run.sh does not run tests/ps/Invoke-Ps51.ps1 (the file is at its listed size limit), so only the ps51 job proves the driver.
- In Test-T21.ps1 a leaked stand-in Add-Type would not be noticed by a later case; the file's first line still says "cloud only".
- The driver stops only the child process, not a child tree, at its time limit.
- The kit (archimedes_lever) must take the four checker files at its next port.
