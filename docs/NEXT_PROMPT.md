# Next prompt: 90-161.Z

Updated: 2026-11-17 by Claude (R28 r2: step titles and runner text rules; lock at engine-v9). Keep this file at 40 lines or fewer and state only: decisions live in docs/DECISIONS.md, design in the docs it links. The current request overrides this file.

## Open now

- RADE and the app, open items (PFM 14 Nov; DECISIONS; full text: docs/reviews/2026-11-15-handoff-detail.md): paste-timing step (500 KB and 1 MB) and the health-flow probe in the next round that has room; R25 proved T20 (15 Nov): retire the T02 flow and rewrite power-automate-provisioning.md (not started); six flow values to PFM Settings rows (new F03, F05, F06 revisions); move `BASE_CHECKS` to the engine; rewrite setup-and-updates.md Part 0 and section 5. Engine and lock rules: docs/dev-setup.md "RADE engine". SPAR (PFM 15 Nov): a Power Apps canvas app, no build yet; a look-only check of group changes by a flow comes first (agent REC).
- Bloat audit 3 done 15 Nov 26 (docs/reviews/2026-11-15-bloat-audit-3.md): the PFM approved P1 to P9 on 15 Nov; made: P1 to P8 (P5: 2 AGENTS.md lines, pull request 86); P9 goes to the RADE audit. Branch claude/exciting-planck-gfr1nu: the PFM approved its delete (older guard port; main has a newer one); the session proxy refused the delete, so the PFM deletes it on GitHub. Open debt: T7, T8 in the report. Next audit by 29 Nov 26.
- History clean done 13 Nov 26: names gone from all of main and gh-pages (fresh-clone scan 0 in 1,053 file versions); old branches deleted; GitHub Support purge requested by the PFM. Delivery is now by pull request (AGENTS.md); Auto-merge and auto-delete on; no main ruleset (not available; PFM 13 Nov). Kit baseline 7f2965c; no kit sync (AGENTS.md Project rules, 15 Nov; pull request 61 closed). Pre-push check gate on.
- 14 Nov: new site exists and is CUI-approved; T02 r11 builds the 12 lists there and sets edit-own-rows (old Task 8); Tasks 11 and 14 use the new site. The hold on PnP steps and the slice 1 scope hold are lifted (PFM 15 Nov). New site = separate site collection. Second-look F1-F5 wait for the PFM's go; S8-S11 open (sweep page).

## State (main)

- Cloud sessions: environment "RADE" (pwsh + PSScriptAnalyzer; PII_GUARD_DENYLIST set).
- Lists: 9 PFM lists, names and columns in docs/DECISIONS.md and schemas/lists; full-scope design docs/reviews/2026-11-12-list-design-full-scope.md. Schemas for 12 lists merged (PR 10). Table A3.2 seed: docs/coordination-table-a3-2.md.
- Provisioning: flow/defs/90161Z-T02-provision-lists-r12.json -> flow/packages/90161Z-T02-provision-lists-r12.zip (12 lists, 88 rows, item-level permissions with a NOT SET fallback; ReadSecurity/WriteSecurity by REST is unverified until the run); go.md Task 2; docs/power-automate-provisioning.md.
- Design check r7 flow and app rules ("Rules for the flows and the app", https://claude.ai/artifact/X8LbHd79Zh614i1qYzhyTW) are not built yet.
- Coverage: docs/dafman-coverage/README.md (1,408 rows: Covered 384, N/A 347, Gap 39). Process: docs/process-model.md. Customer guidance r3: docs/guidance/customer-steps.md (review doc https://claude.ai/artifact/8qUeXnJNPhyEJNUYU6ShzV).
- Phases and rounds: docs/phases.md; roles docs/roles-and-permissions.md; backups docs/backup-and-restore.md; screen map docs/app/screen-map.md; setup docs/setup-and-updates.md; rights tests docs/rights-test-plan.md (results to the private log only).
- Briefs: docs/brief/*.json -> scripts/build_decision_brief.js (go.md Task 10). Plan audit: https://claude.ai/artifact/Wdvg7PB2321twKVubQbp2i. Order of work: https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J.

## Waiting on the PFM (go.md)

1. R28 r2 ready (17 Nov; r1 pull request 121, r2 adds plain step titles and runner text rules 1 to 8, PFM 1A; build notes and open review items: docs/reviews/2026-11-17-r28-build.md): R27 leftovers removed first (1B), T21 probe r4 (health flow alone; button flow by hand, trigger shape read from the export), T4 retry, T22 window r2 (preview 2), RADE Start and desktop icon (deploy entry), T24 full flow solution (F01 r2, F02 r3, F04 r2; all 6 On), clean-ups always run. Next: the PFM runs R28; then results file, fallbacks only for FAILED tests. R27 results: docs/reviews/2026-11-17-r27-results.md. After R28: F03 and F06 read PFMOfficeMailbox (DECISIONS 17 Nov); front-end plan and doc rewrites.
2. Task 6 prompt r2 follow-up: list AFI (validator F-032/F-039 fixed 13 Nov).
3. Seals: done in R13 (all 17 prepared and uploaded); detail: docs/reviews/2026-11-15-handoff-detail.md.
4. Logo (PFM 17 Nov, DECISIONS): Rho Bold (USAF-B) replaces logo K for every app after R27 (source: the Rho canvas https://claude.ai/artifact/Qw7iSQaz1FMzZQtycjrZxq). To do: RADE master copy and release (RADE session), lock move, index.html band, T16 logo check, site logo by hand. After T11 results: design the site home page as a preview, then a page/header flow (DECISIONS 2026-11-13).
5. App writes (PFM 14 Nov: wing users Read on the site, data entry through the app): Power Apps writes with the user's own rights, so choose list-level Contribute on the app's lists (site stays Read) or a flow that writes with the PFM's connection. Agent REC: list-level Contribute on the intake lists only; R16 W11 proved a Read-only user gets Contribute on such a list.
6. Result e-mails: app-drafted round e-mails go to Trash once results are on main; others need confirmation (AGENTS.md Project rules, 15 Nov).
7. Target process (PFM 16 Nov; DECISIONS): the PFM's 13 steps in docs/process-model.md "Target process"; cards in docs/app/screen-map.md section 0. Not built. Next: the fallbacks for T4 and T8 (item 1), then list changes, F05 in 3 waves, guidance r4 and a preview, each for the PFM alone to judge (no previews for other people). Ask the PFM to review when a step is stuck. App preview r2 (https://claude.ai/artifact/8DShFnoUqr5MWZAqwKKqxb) is from before the 13 steps.

## Next

- Round build speed (PFM 15 Nov): the steps are in `.claude/skills/round/SKILL.md` section 0. Agent REC, not a decision: target about 60 min for a round build with no engine change. R27 r1 (full scope, 2 Sonnet workers, 3 fresh reviews): 55 min, 00:12 to 01:07 UTC (pull request 110). Open from its reviews (MINOR): T23 --check counts parts by the same fixed format; masking misses double-encoded and full-width @; untested Person paths (kept record, person gone; different person after WasMember=yes). Time record of the R25 session: the audit 3 report, section 1.
- Roadmap (PFM 15 Nov): phase states, exit criteria and the rounds from R24 to the pilot are in docs/phases.md (round order approved by the PFM, 1A; exit criteria and estimate = agent REC; evidence docs/reviews/2026-11-15-roadmap-evidence.md). Slice 1 passed in R22; both holds of 14 Nov are lifted (PFM 15 Nov). Not built: the endorser-answer app flow.

## Do not

- Put government data, the wing's name, site path, DODIDs or office symbols in this repo or in Claude chats.
- Take rules from the wing files. Format comes from code and DAFMAN 90-161.
