# Next prompt: 90-161.Z

Updated: 2026-11-14 by Claude. Keep this file at 40 lines or fewer and state only: decisions live in docs/DECISIONS.md, design in the docs it links. The current request overrides this file.

## Open now

- RADE (PFM 14 Nov): the Deployer is now RADE, the Redacted Application Deployment Engine (scripts/build_paste_bundles.py): OneDrive\RADE\90-161.Z (R17 moves the old folder in), RADE\Config (rade-mail-to.txt, rade-checks.json: PASSED checks reused 7 days), two-line rows, drawn bars, Exit. The window code is lint-clean but runs only on the gov device: R17's "Window: OK" line is its test. SharePoint admin app (PFM 14 Nov): information only, no build yet; capability report in the private doc linked from DECISIONS 14 Nov.
- Bloat audit 2 done (docs/reviews/2026-11-13-bloat-audit-2.md); P1-P4 approved and made: tests 21 s -> 12.7 s, baseline bc233b9, task-common block (scripts/build_task_scripts.py), 3 short DECISIONS lines. Next audit by 27 Nov 26.
- History clean done 13 Nov 26: names gone from all of main and gh-pages (fresh-clone scan 0 in 1,053 file versions); old branches deleted; GitHub Support purge requested by the PFM. Delivery is now by pull request (AGENTS.md); Auto-merge and auto-delete on; no main ruleset (not available; PFM 13 Nov). Kit baseline 7f2965c; projects no longer sync (2026-11-13). Pre-push check gate on.
- 14 Nov: new site exists and is CUI-approved; T02 r11 builds the 12 lists there and sets edit-own-rows (old Task 8); Tasks 11 and 14 use the new site. Hold any step that needs a PnP check (PFM). New site = separate site collection. Second-look F1-F5 wait for the PFM's go; S8-S11 open (sweep page).

## State (main)

- Cloud sessions: environment "90-161.Z" (pwsh + PSScriptAnalyzer; PII_GUARD_DENYLIST set).
- Lists: 9 PFM lists, names and columns in docs/DECISIONS.md and schemas/lists; full-scope design docs/reviews/2026-11-12-list-design-full-scope.md. Schemas for 12 lists merged (PR 10). Table A3.2 seed: docs/coordination-table-a3-2.md.
- Provisioning: flow/defs/90161Z-T02-provision-lists-r11.json -> flow/packages/90161Z-T02-provision-lists-r11.zip (12 lists, 88 rows, item-level permissions with a NOT SET fallback; ReadSecurity/WriteSecurity by REST is unverified until the run); go.md Task 2; docs/power-automate-provisioning.md.
- Design check r7 flow and app rules ("Rules for the flows and the app", https://claude.ai/artifact/X8LbHd79Zh614i1qYzhyTW) are not built yet.
- Coverage: docs/dafman-coverage/README.md (1,408 rows: Covered 384, N/A 347, Gap 39). Process: docs/process-model.md. Customer guidance r3: docs/guidance/customer-steps.md (review doc https://claude.ai/artifact/8qUeXnJNPhyEJNUYU6ShzV).
- Phases: docs/phases.md; roles docs/roles-and-permissions.md; backups docs/backup-and-restore.md; screen map docs/app/screen-map.md; setup docs/setup-and-updates.md; rights tests docs/rights-test-plan.md (results to the private log only).
- Briefs: docs/brief/*.json -> scripts/build_decision_brief.js (go.md Task 10). Plan audit: https://claude.ai/artifact/Wdvg7PB2321twKVubQbp2i. Order of work: https://claude.ai/artifact/UAKZ89DXU6xJsedi1dpt7J.

## Waiting on the PFM (go.md)

1. R17 r1 on go.md (14 Nov): T17 r3 tests A (no variable) and B (variable, no XML declaration), logo and thumbnail by hand, site setup r6 (reads the header logo; collects A and B). R16 results: docs/reviews/2026-11-14-r16-results.md. Next on the R17 e-mail: A/B tell the import cause; then the sprawl cuts not yet made (DECISIONS 14 Nov: probe mask once, one masking function, clean-up by revision rule; the logo fallbacks are gone), the flow build, T09 reader, T12 colors. Open: S2, S3, S5 3-15, S6, S7, S8-S11, F1-F4 (sweep page).
2. Task 6 prompt r2 follow-up: list AFI (validator F-032/F-039 fixed 13 Nov).
3. Seals: Claude corrected 17 unit seals (1,200 px, glow removed, 2 px feather; tool in the session scratchpad, not in the repo) and mailed them in 6 parts; R13 prepared and uploaded all 17 (library 90-161.Z, Seals and Seals/Prepared).
4. Logo r2 (PFM 14 Nov): variant A bold white on the header, bold navy thumbnail (assets/logo, scripts/build_logo.py, stroke 8); set by hand in R17 (scripts cannot set it on this site). After T11 results: design the site home page as a preview, then a page/header flow (DECISIONS 2026-11-13).
5. App writes (PFM 14 Nov: wing users Read on the site, data entry through the app): Power Apps writes with the user's own rights, so choose list-level Contribute on the app's lists (site stays Read) or a flow that writes with the PFM's connection. Agent REC: list-level Contribute on the intake lists only; R16 W11 proved a Read-only user gets Contribute on such a list.
6. Result e-mails: delete only after the PFM confirms (AGENTS.md Project rules).

## Next design (after Task 5)
0. Slice 1 first (DECISIONS 14 Nov): hold new scope until Publications + Endorsements + F05 + F03, list views only, take one fake publication from Coordination to Legal on the test site. If R17 A and B both fail: one more A/B round. After R17: RADE size in the summary, hash-pinned engine, JSON results block.
1. Flows as solution-aware flows with connection references (match the real export), not legacy packages.
2. Draft flows F01-F05 in flow/solution (F05 = routing, S5A; open points in its README). Not built: the endorser-answer app flow (endorsers answer in the app; flows only alert them).
3. Then the Power Apps canvas app (docs/app/screen-map.md); Accessibility Checker 0 errors.

## Do not

- Put government data, the wing's name, site path, DODIDs or office symbols in this repo or in Claude chats.
- Take rules from the wing files. Format comes from code and DAFMAN 90-161.
