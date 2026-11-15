# Bloat, drift and assumption audit 3 (15 Nov 26)

Procedure: [.claude/bloat-audit.md](../../.claude/bloat-audit.md). Asked for by the PFM on 15 Nov 26, after the R25 build session took 3 h 53 min and `tests/run.sh` was 3 times slower than its baseline. Base commit: main d9292f3. Machine: Claude cloud session, 4 cores (times compare only on this kind of machine). Previous audit: [2026-11-13-bloat-audit-2.md](2026-11-13-bloat-audit-2.md).

Only one change was made: the test runner starts its two slowest checks beside the others (no test removed). Every other item is a proposal (section 5).

## 1. Where the R25 session's time went

Source: the event times of the session record (12:52 to 16:45 CST, 233 min). Phase minutes are estimates from slicing that timeline.

| Phase | Min | % |
|---|---|---|
| RADE engine change (question cards, layout) and its fix rounds; the session waited on the worker | 56 | 24 |
| Reviews (6, one after another) and waits for hosted checks and the release | 42 | 18 |
| Windows picture runs, preview page, comments | 29 | 13 |
| R25 in this repo: R24 results, T20 script, round definition, bundle | 29 | 12 |
| Session idle between the PFM's two requests | 22 | 10 |
| Planning and questions | 19 | 8 |
| Roadmap (the first request) | 19 | 8 |
| Review fixes, merge, report | 17 | 7 |

Measured facts behind the table:

- Engine: 5 worker rounds (about 87 min of worker time) and 5 Windows jobs, 3 of them failed (window defects found one at a time).
- Push blocked 49 min (14:07 to 14:56 CST): the lock check waited for an engine release that another session made; the bundle was built on engine-v5 and built again on engine-v6.
- Reviews: 6, strong tier, 48 min in total (13.8, 10.8, 8.9, 8.4, 3.5 and 2.4 min); 3 of them reviewed a fix commit.
- Context: about 800,000 tokens for each request at the end of the session.
- `tests/run.sh` 36 s and a push 48 s (`scripts/check.sh` runs the suite); 8 commits were pushed.

The PFM's decisions of 15 Nov 26 from this record are in [DECISIONS.md](../DECISIONS.md): engine changes in their own RADE session; reviews start while the hosted check runs.

## 2. Numbers before and after

| Measure | Before | After | Budget |
|---|---|---|---|
| Start read (~tokens) | 7,319 | 7,404 (one handoff line added for the speed decisions) | 12,000 (warning 6,000) |
| Duplicate lines (80+ chars, 2+ files) | 78 | 78 (generated copies; P2) | 20 |
| Tracked files / size | 232 / 7.25 MB (audit 2: 171 / 5.57 MB) | 233 / 7.25 MB | - |
| Big files (over 500 KB) | 0 counted (ref/ and the round bundle are ignored) | 0 | 0 |
| Timing: `tests/run.sh` | 36.0 s (baseline 12.2 s) | 27.3 s | +25 % of baseline |
| Timing: `scripts/check.sh` (each push) | 48.3 s | about 39 s (estimate: 48.3 less the 8.7 s saved in the suite; not measured again) | - |
| Timing: check-in | 0.7 s (baseline 0.5 s) | 0.7 s to 1.0 s (3 runs; baseline kept at 0.5 s) | +25 % |
| Removals proposed / approved / made | 9 / 0 / 0 | | |
| Rules removed or merged | 0 | 0 | |
| Key assumptions: high / medium / low / untraced | 4 / 5 / 6 / 0 (new since audit 2) | | |

## 3. Findings

### Performance (category 6) and layers (category 5)

`tests/run.sh` by test, 36.0 s in total (trace with a time stamp for each PASS line):

| Cost | Seconds | Cause |
|---|---|---|
| T20 on the fake site | 8.4 | New on 15 Nov: 37 checks, the script runs many times against tests/fake-pnp |
| Lint | 7.3 | PSScriptAnalyzer over 24 files, one call for each file |
| Round bundle "Enter starts the run" | 3.7 | Bundle runs in pwsh |
| Newest-RADE verdicts | 3.6 | 4 cases, each starts processes |
| All steps under 0.3 s each | 2.6 | - |
| Process starts | - | 21 `pwsh` starts (0.24 s empty, about 0.45 s with a script load) and 62 `python3` starts for each run |

- Fix made: lint and T20 start in the background at the top of `tests/run.sh`; T20 is read at its old place and lint at the end. 36.0 s to 27.3 s (2 runs: 27.3, 27.5). 86 of 86 pass. Mutation checks: a parse error in a gov script gives `FAIL lint`; a forced T20 failure gives `FAIL T20 ... (exit 1)`.
- Layer: a push runs `scripts/check.sh`, which runs 8 self-tests, the full personal-data scan and `check.local.sh`, which runs `tests/run.sh`; the pre-push hook then runs the guard on the pushed range. The suite is not run two times in this chain. An agent that runs `tests/run.sh` by hand just before `git push` does run it two times (P4).
- The baseline of 12.2 s was set before the round-bundle, RADE-lock and T20 tests existed. The suite grew by 3 pwsh-heavy groups in 2 days.

### Duplication (1), drift (2), stale docs (4), handoff (16)

- The 78 duplicate lines are generated copies: `scripts/gov/src/task-common.ps1` (22 long lines) and `site-common.ps1` (11) are written into 13 task scripts by `scripts/build_task_scripts.py`, and `--check` enforces them. Audit 2 left this open as T4.
- Fixed in the handoff: [NEXT_PROMPT.md](../NEXT_PROMPT.md) named the T02 files as r11; the tracked files are r12.
- Drift: AGENTS.md "Start of session" points to "full text in docs/decisions-archive.md"; the header of DECISIONS.md says one table replaced the pair, for rows from 13 Nov 15:30. Both are true for different rows; the archive is 67,159 bytes and has no end date (P6).
- Handoff: lines 7 and 24 of NEXT_PROMPT.md hold 2,956 of 7,382 bytes (about 740 tokens) and repeat DECISIONS, the lock file and go.md (P3). Item 3 (seals) is finished. The "Next" line still says the PFM confirms the end of the scope hold; the PFM lifted both holds on 15 Nov.
- Superseded revisions: none (one revision for each task and slug). Relative links: 31 checked, 0 broken. Dependencies: none beyond the Python standard library, pwsh and node.

### Instruction bloat (12, 13) and delegation (20)

- AGENTS.md is 21,883 bytes (about 5,470 tokens). The 5 longest rule lines (Delivery 729, gov hand-off 702, Build 592, usability 575, `.pii-guard` 509 bytes) repeat what a hook, a script header or go.md holds (P5).
- Delegation in the R25 session: 6 strong-tier reviews for 2 pull requests. `.claude/orchestration.md` routes a routine diff to the standard tier; the PFM's personal rule (never review on a lower tier than the author) made each review strong tier, because a strong-tier worker wrote the engine change (P7).
- Hooks: Stop hook and SessionStart hook only; the check-in is 0.7 s. No finding.

### Process (10)

- One session held the roadmap, an engine redesign in another repo and the round. The context reached about 800,000 tokens (P8).
- The engine release was triggered after the pull request merge, at 16:09 CST; the round bundle needs the release, so the last hour was in series (P9; the PFM's decision on engine sessions removes most of it).

## 4. Assumptions (Step 3)

New since audit 2. A round in [phases.md](../phases.md) settles most of them; no test in the cloud can.

| # | Assumption | Source | Confidence | Settled by |
|---|---|---|---|---|
| 1 | PnP REST and CSOM make the 12 lists, 199 columns and 18 views on a clean site, with edit-own-rows | T02 flow worked in R11 to R13; T20 never ran on a device | low | R25 |
| 2 | The F03 e-mail fault is at the shared mailbox step | Agent plan; 4 rounds with no e-mail | low | R25 |
| 3 | A bundle of 562 KB pastes fast enough (limit 614,400 bytes, set before the timing step ran) | DECISIONS 14 Nov | low | R25 in practice; timing in R26 |
| 4 | 23 to 25 rounds to the pilot | roadmap evidence (agent REC) | low | - |
| 5 | The canvas app imports on this tenant and passes the Accessibility Checker | none for tenant behaviour | low | R30, R33 |
| 6 | The cause of the "old layout" window is known | R24 results: cause not known | low | R25 `SCALE` line |
| 7 | Engine-v6 window fixes work on the device | RADE reviews and Windows job; not on a device | medium | R25 |
| 8 | The Management connector can run the health flow | DECISIONS 14 Nov | medium | R26 |
| 9 | A Read-only user can write through the app with list-level Contribute | R16 W11 | medium | R30 |
| 10 | The install record is allowed only in a deploy | RADE docs/engine.md | medium | R34 |
| 11 | Stage 6 target of 25 working days | PFM 14 Nov; the DAFMAN paragraph is not in the row | medium | R26 |
| 12 | Every NIPR computer has PowerShell 5.1 and PnP 1.12.0 | PFM 14 Nov; R24 | high | - |
| 13 | The lock is the newest signed RADE release | tests/run.sh | high | - |

From audit 2: "rights work as designed" moved from medium to high (17 of 17 answered; P18, P19, S14 open); "timings compare across sessions" is not confirmed: this audit's machine may differ from the one that set 12.2 s.

## 5. Proposals for the PFM (nothing here is made)

| # | What | Why it exists | Evidence | Saving | Risk | REC |
|---|---|---|---|---|---|---|
| P1 | Merge the 21 `pwsh` starts of `tests/run.sh` into 3 or 4 processes, as audit 2 did for the validator (same tests, same PASS lines) | Each test was added with its own start | 21 starts for each run; audit 2 measured 0.75 s for each start saved | Estimate 6 to 9 s of 27 s | A shared process can hide state between tests | Yes, after R25 |
| P2 | `bloat_check.py` skips text between generated-block markers (audit 2, T4) | Generated copies count as duplicates | 78 lines, about all from 2 source files | Count 78 to about 0 to 12; a true duplicate becomes visible | Kit script: port by hand | Yes |
| P3 | NEXT_PROMPT.md lines 7 and 24: one line each, detail stays in DECISIONS, the lock file and go.md; drop item 3 (seals, finished) | Handoff grew by round | 2,956 bytes of 7,382 | About 800 tokens for each session start | Low | Yes |
| P4 | Agents do not run `tests/run.sh` by hand before a push; the pre-push hook runs it | Habit | 8 pushes in the R25 session | 27 s for each push | None | Yes |
| P5 | Shorten 5 AGENTS.md rule lines to pointers (hook, script header, go.md) | Rules written before the hooks existed | 3,107 bytes | About 775 tokens for each session | Medium: instruction file | Ask: the PFM reads the new lines first |
| P6 | Say in one place which DECISIONS rows have archive text, and fix the AGENTS.md pointer | One-table decision of 13 Nov | 2 files disagree | Fewer wrong reads | Low | Yes |
| P7 | Round builds: a `worker` on the standard tier unless the routing table says strong, so the fresh review can be standard tier | Strong worker used for the engine | 6 strong reviews, 48 min | Estimate 15 to 20 min for each round | A weaker first draft | Ask |
| P8 | One new session for each round; the roadmap or an engine change never shares it | - | 800,000 tokens of context | Cost; some speed (not measured) | None | Yes (in the handoff as agent REC) |
| P9 | In rhope-ops/RADE: the Windows job reports every layout defect in one run, and a release is cut before the app session needs it | Defects came one for each run | 3 failed jobs, about 43 min of rework | Estimate 30 min for each engine change | RADE repo decision | Raise in the RADE audit (due after R25) |

### Approval (15 Nov 26, after this report)

The PFM approved P1 to P9 on 15 Nov 26. Made: P1 (see the numbers in pull request 2 of this audit), P2 (duplicates 78 to 49: the 49 are real, see T8), P3 (handoff detail moved unchanged to [2026-11-15-handoff-detail.md](2026-11-15-handoff-detail.md); start read 7,404 to about 7,070 tokens), P4 and P6 (one line each in AGENTS.md), P7 and P8 (DECISIONS and the handoff). P5 is a separate pull request that the PFM reads first. P9 is noted in the handoff for the RADE audit.

## 6. Tech-debt register

| Item | Owner | Review |
|---|---|---|
| T4 (audit 2): duplicate count includes generated copies (P2) | Claude | Closed 15 Nov (P2 made); the coverage table header (6 files) still counts as 1 line |
| T5: `tests/run.sh` 27 s against the 12.2 s of audit 2; new baseline 25.4 s recorded; P1 open | Claude | After R25 |
| T7 (review of this audit): `scripts/lint.sh` passes with 0 findings when the PSScriptAnalyzer module is missing; `tests/run.sh` has no `trap`, and each run leaves a `/tmp/t20-<guid>` folder | Claude | Proposal with P1 |
| T8: with generated blocks skipped, 49 duplicate lines remain; about 40 are the same hand-written code in 5 task scripts (Hide-Site masking, PnP module check, sign-in) | Claude | Proposal: move them into the site-common block, with new script revisions, when those scripts next change |
| T6: paste limit set before the paste timing ran (assumption 3) | PFM | R26 |

Next audit by 29 Nov 26 or 300 commits.
