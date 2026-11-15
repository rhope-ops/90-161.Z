# Roadmap evidence (15 Nov 26)

Evidence for [docs/phases.md](../phases.md). Made by Claude on 15 Nov 26 from the 20 round results files in this folder (R01-R06, R09-R13, R15-R23; R07, R08 and R14 have none), the product files named below, and rhope-ops/RADE docs at 5e9a639. Main moved during the work: R24 r1 (engine-v4, RADE 4a0fbad) is built and open, so rows 1 to 3 are in a built round. Two Haiku scouts read the files; Claude spot-checked R13, R19, R20, the 39 Gap rows and the 12 list schemas. A fresh reviewer then checked the tables against the sources; its 8 MINOR findings are worked in (3 capability rows corrected or added, rows 36 to 42 added). Counts and step names only.

## 1. Capability history (R01 to R23)

"Rounds" = round numbers from the first try to the first full pass, both included. One capability (the Outlook mail check, R11) has no pass round: it moved into the probe flow, and it is not in the table.

| Capability | First try | Full pass | Rounds |
|---|---|---|---|
| Runner / RADE window | R01 | R09 | 9 |
| Word renderer and TOC (T01) | R01 | R03 | 3 |
| Sensitivity label (T13) | R02 | R02 | 1 |
| Accessibility link | R03 | R03 | 1 |
| Cover link style | R03 | R04 | 2 |
| Summary subject and clipboard | R04 | R04 | 1 |
| Outlook draft at the end | R05 | R05 | 1 |
| Clean-up to the Recycle Bin | R06 | R06 | 1 |
| Copy script on the bookmark page | R06 | R06 | 1 |
| Environment inventory (T15) | R09 | R09 | 1 |
| Page, brief and colour inputs (T09, T10, T12) | R09 | R10 | 2 |
| PnP web sign-in (T16) | R09 | R09 | 1 |
| Rights form (T11 Part B) | R09 | R12 | 4 |
| Probe flow, guided import (T11) | R13 | R13 | 1 |
| Seal prep (T07) | R12 | R13 | 2 |
| Seal upload | R12 | R13 | 2 |
| Site setup by PnP (T16) | R12 | R13 | 2 |
| Header logo | R12 | R17 | 6 |
| Solution import test (T17) | R15 | R19 | 5 |
| Import log reader (T17) | R19 | R19 | 1 |
| Slice 1 solution import (T18) | R20 | R21 | 2 |
| F05 routing | R20 | R21 | 2 |
| F03 suspense | R20 | R22 | 3 |
| F06 hold, resume, cancel | R21 | R21 | 1 |
| Failure e-mail and Resubmit | R21 | R21 | 1 |
| List update (T19) | R21 | R22 | 2 |
| Repository check | R16 | R21 | 6 |
| Engine guardrails (engine-v1) | R22 | R22 | 1 |
| Shared files (engine-v2) | R23 | R23 | 1 |

Command (reads the table above; run from the repo root):

```bash
python3 -c "
import re,statistics as s
t=open('docs/reviews/2026-11-15-roadmap-evidence.md').read().split('## 2.')[0]
n=[int(x) for x in re.findall(r'\| R\d\d \| R\d\d \| (\d+) \|',t)]
late=len(re.findall(r'\| R(?:1[5-9]|2\d) \| \d+ \|',t))
print('capabilities',len(n),'first-round pass',n.count(1),'mean',round(s.mean(n),2),'median',s.median(n),'max',max(n))
print('per round, R01-R23:',round(len(n)/23,2),'| passed in R15-R23:',late,'=',round(late/9,2),'per round')
"
```

Output (15 Nov 26):

```text
capabilities 29 first-round pass 14 mean 2.28 median 2 max 9
per round, R01-R23: 1.26 | passed in R15-R23: 12 = 1.33 per round
```

## 2. Remaining work to the pilot, traced to a round

"Dev" = a device capability that counts in the estimate. Sources are files in this repo unless they start with RADE.

| # | Remaining item | Dev | Round | Phase | Source |
|---|---|---|---|---|---|
| 1 | Import page: 4 values first, Test mode Yes (slice zip r5) | yes | R24 | 6 | docs/DECISIONS.md 2026-11-15 "Solution import page"; flow/solution/README.md line 11 |
| 2 | Site address entered once (T16 r4/r11, T18 r3, T19 r3) | yes | R24 | 1 | docs/DECISIONS.md 2026-11-15 "Site address is entered once" |
| 3 | F03 r5: escalation e-mail arrives; log row names the mailbox | yes | R24 | 6 | docs/NEXT_PROMPT.md "Waiting on the PFM" item 1 (the PFM's report, 15 Nov 26; no results file records it); docs/reviews/2026-11-15-r23-results.md finding 3 (F03 r5 not yet run) |
| 4 | F03 by-hand step wording (the new text is not written yet) | no | R24 | 6 | docs/reviews/2026-11-15-r22-results.md finding 2 |
| 5 | Paste timing, 500 KB and 1 MB (the step is not built; not in R24 r1) | yes | R25 | 1 | docs/DECISIONS.md 2026-11-14 "Bundle size limit" |
| 6 | 12 lists made by PnP from schemas/lists (scripts/gov/Provision-Lists.ps1 exists; not run in a round). Needs a clean target: the test site holds the 12 lists already | yes | R25 | 3, 5 | docs/DECISIONS.md 2026-11-14 "Lists by PnP" |
| 7 | One-install record (`marker` in the manifest) | yes | R25 | 1 | RADE docs/engine.md "One install per site" |
| 8 | Health-flow probe (Management connector) | yes | R25 | 6 | docs/DECISIONS.md 2026-11-14 "Flow health" |
| 9 | Step scripts: `after`, `makes`, `help`; large files to `fetch` | no | R25 | 1 | RADE docs/NEXT_PROMPT.md item 0 b |
| 10 | Retire the T02 flow; rewrite docs/power-automate-provisioning.md and docs/setup-and-updates.md (Part 0, section 5, the installed-version text) | no | after R25 | 5 | docs/DECISIONS.md 2026-11-14 "Lists by PnP", "One preflight" |
| 11 | Six flow values read from PFM Settings rows (new F03, F05, F06) | yes | R26 | 6 | docs/DECISIONS.md 2026-11-14 "Flow values move" |
| 12 | Stage 6 target = 25 working days | yes | R26 | 6 | docs/DECISIONS.md 2026-11-14 "Backups: JSON" |
| 13 | F01 activity log | yes | R27 | 6 | flow/solution/README.md line 29 |
| 14 | F02 next review due | yes | R27 | 6 | flow/solution/README.md line 30 |
| 15 | F04 status report | yes | R27 | 6 | flow/solution/README.md line 32 |
| 16 | Full solution import, every flow On | yes | R27 | 6 | docs/DECISIONS.md 2026-11-15 "Flow state at import" |
| 17 | Flow open points: F05 a-e, open choices 2, 4, 5, 7, 9-13, 15 | no | before R27 | 6 | flow/solution/README.md lines 44-67 |
| 18 | RADE Diagnose | yes | R28 | 1 | RADE docs/engine.md "Maintenance run types" (not built; function lists are an agent REC) |
| 19 | RADE Back up | yes | R28 | 1, 2 | same; docs/backup-and-restore.md |
| 20 | RADE Restore | yes | R29 | 1, 2 | same |
| 21 | RADE Uninstall, then a clean reinstall (removes the old solutions and flows) | yes | R29 | 1 | same; docs/NEXT_PROMPT.md "Waiting on the PFM" item 1 |
| 22 | Canvas app import (25 screens in docs/app/screen-map.md; 0 built) | yes | R30 | 7 | docs/app/screen-map.md line 77 |
| 23 | App writes by a Read-only user | yes | R30 | 7 | docs/DECISIONS.md 2026-11-14 "Wing users have only Read" |
| 24 | Endorsers answer in the app | yes | R31 | 7 | docs/DECISIONS.md 2026-11-14 "Endorsers answer in the app" |
| 25 | Restart coordination in the app | yes | R31 | 7 | flow/solution/README.md line 38 |
| 26 | PFM Office screens P01-P16, role re-assign (acting PFM) | yes | R32 | 2, 7 | docs/roles-and-permissions.md; docs/app/screen-map.md |
| 27 | Accessibility Checker 0 errors; final palette | yes | R33 | 4, 7 | docs/palette.json line 2; AGENTS.md "Verification" |
| 28 | Install from zero by a second account with fewer rights | yes | R34 | 8 | AGENTS.md Project rules "Deployable package" |
| 29 | Rights rows P18 (file size) and P19 (co-owner re-binds) | yes (2) | R35 | 8 | docs/rights-test-plan.md lines 52-53 |
| 30 | Weekly backup flow and disabled-account list (screens P13 and P14 show them) | yes (2) | R32 | 2 | docs/DECISIONS.md 2026-11-13 "(19A)"; docs/app/screen-map.md lines 68-69 |
| 36 | Weekly digest e-mail | no | REC: in the pilot | 2 | docs/DECISIONS.md 2026-11-13 "(19A)" |
| 31 | Setup intake: library scan, products CSV | no | REC: in the pilot | 3 | docs/decisions-archive.md "Phase 2+3 round 1" (8A) |
| 32 | 39 coverage Gap rows: 10 guidance text, 10 list column or data, 3 flow, 3 format rule, 1 screen, 12 other (training, FPL, record set) | no | triage before R25 (list rows) and R27 (flow rows) | 3-7 | docs/dafman-coverage/README.md line 27 |
| 33 | Task 7 Part A (4 fake seals) | no | REC: drop; real seals passed in R13 | - | docs/gov-test-plan.md line 65 |
| 34 | Format tables 4.2-4.5 wording; Task 6 prompt follow-up | no | not a round (cloud work) | - | docs/format-rules.md lines 73-75 |
| 35 | Rights row S14 (destructive, not tested) | no | REC: after the pilot | - | docs/rights-test-plan.md line 30 |
| 37 | RADE puts the site address on the clipboard at the import guide step | yes | the first import round after the engine release | 1 | docs/NEXT_PROMPT.md "Waiting on the PFM" item 1 |
| 38 | RADE items not verified on a device: layout self-check line, full-name domain check, site collection administrator read, the RADE page on a work computer | yes | R24 (first device run of engine-v3 and v4) | 1 | RADE docs/NEXT_PROMPT.md State, items 3 and 8; go.md Round R24 r1 |
| 39 | Design check r7 "Rules for the flows and the app": not built; no docs/flow-rules.md | no | before R27 (flows) and R30 (app) | 5 | docs/NEXT_PROMPT.md State |
| 40 | Site home page (preview first), then a page and header flow | yes | R33 | 4 | docs/NEXT_PROMPT.md "Waiting on the PFM" item 4 |
| 41 | Task 9 e-Publishing reader (paging past 100 rows); it feeds the intake cross-check | no | REC: in the pilot, with row 31 | 3 | go.md Done, Task 9; docs/reviews/2026-11-14-r10-results.md finding 1 |
| 42 | 107 "Renderer gap" rows and 152 Partial rows in the coverage (document path) | no | triage by the PFM; not a round | - | docs/dafman-coverage/README.md lines 24-26 |

The grouping of the Gap rows in item 32 is the scout's reading of each row's "Covered by" text, not a decision.

## 3. Estimate

- Device capabilities left to the pilot start: 31 (the "yes" rows; rows 29 and 30 count 2 each).
- Low end, 12 rounds: every planned round (R24 to R35) passes on its first run. History: 14 of 29 capabilities did (48%).
- Middle, 23 to 25 rounds: 31 capabilities at the measured rate (1.33 a round in R15-R23; 1.26 over all rounds).
- High end, 27 rounds: 12 planned rounds times the mean of 2.28 rounds for each capability (a rough upper mark: it treats a round like one capability).
- Limits: 23 rounds in 4 days by one tester; no canvas app round is in the history; a round is not a fixed length of time.
