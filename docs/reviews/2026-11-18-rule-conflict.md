# Rule conflict check, 2026-11-18 (kit 2026.11.20.1 sync)

Reviewer: the `reviewer` subagent, fresh context, Opus tier (same as the author). Input: the changed lines below, AGENTS.md, docs/DECISIONS.md and the brief of .claude/skills/rule-change/SKILL.md. Scope: changed Project rules and Commands lines (the kit checks its own text).

## Changed lines (`bloat_check.py --rules`)

```text
rules:       AGENTS.md 81 lines (cap 200) · session load ~4,866 tokens (cap 5,000) · 28 rule bullets · Project rules 14
  + Data boundary (2026-11-14): government data stays in DoD365 and GenAI.mil: no real drafts, publication content, names, e-mails, office symbols or comments in this repo or a chat; no app writes data across the boundary. Use fake data.
  + Public repo (2026-11-11): never commit the wing's name or location, the site path (only `https://usaf.dps.mil/sites/<your-site>`), names, office symbols, DODIDs, seal files or gov-network test details (private log).
  + Source authority (2026-11-11): DAFMAN 90-161 (edition: docs/DECISIONS.md) is the only rule source; cite its paragraph for each stage, time limit and format rule. Wing files lose on any conflict. Format comes from code, never the model.
  + Scope (2026-11-10): ANG wing publications on the wing's own site (DAFMAN 90-161 1.1.3.2, 6.4); 90-161.Z is the system of record for endorsements (no TMT).
  + Platform (2026-11-16): SharePoint lists and Power Automate in DoD365, standard connectors, no tenant admin, never a service account: docs/ARCHITECTURE.md.
  + Deployable package (2026-11-16): other wings install it through RADE; a step that needs extra rights has a tested fallback. Assume no platform limit unless confidence is high.
  + Gov device (2026-11-13): no Claude app or e-mail there; scripts do every step they can in the RADE round, go.md only the rest: `.claude/skills/round/SKILL.md`.
  + What people see (2026-11-14): plain, professional English; go.md and runner text meet the round skill's usability bar.
  + Round results (2026-11-15): Gmail and result e-mails: only as the round skill says.
  + Next-step link (2026-11-15): to open a round or task, link https://rhope-ops.github.io/RADE, never go.md.
  + Delivery (2026-11-15): one pull request per round or request; merge by hand only through the gates in `.claude/skills/deliver/PROJECT.md`.
  + Code standard (2026-11-17): all code is modular, clearly commented and human inspectable: docs/code-standard-90-161.md.
  + Project log (2026-11-11): in the private doc https://claude.ai/artifact/9zLxe6e9vJPKtRQv5xSSzk, never in this repo.
  - Code standard (the PFM, 2026-11-17): all code is modular, clearly commented and human inspectable, per docs/code-standard.md (the kit core plus the RADE extras, full docs per function included); scripts/code_standard.py enforces it, and its baseline may only shrink.
  - Data boundary (the PFM, 2026-11-10; 2026-11-14): government data stays in DoD365 and GenAI.mil; never put real drafts, publication content, names, e-mails, office symbols or comments in this repo or a Claude chat, and no app lets users write data across the boundary. Use fake data; sanitize bug reports.
  - Delivery (the PFM, 2026-11-13; 2026-11-15): one pull request per round or request, never a push to main; merge by hand (no auto-merge) only when the full lane, `python3 scripts/pii_guard.py --require-denylist --all --range origin/main..HEAD --allow-from origin/main` and the pii-guard pull-request check pass, and the fresh review finds no MAJOR finding (MAJOR: ask the PFM).
  - Deployable package (the PFM, 2026-11-12; 2026-11-14; 2026-11-16): other wings install it through RADE; every NIPR computer has Windows PowerShell 5.1 and PnP.PowerShell, but rights differ, so a step that needs extra authority (site collection administrator, Send As, records-manager rights) has a tested fallback. Assume no platform limit unless confidence is high; try each easy path once before a fallback.
  - Gov device (the PFM, 2026-11-11; 2026-11-13): no Claude app and no e-mail to the work computer; its tasks go in go.md (bookmark rhope-ops.github.io/90-161.Z), and every step a script can do runs in the current RADE round, so go.md keeps only what needs a person. Steps: `.claude/skills/round/SKILL.md`.
  - Next-step link (the PFM, 2026-11-15): when a summary or "Next" line tells the PFM to open a round or task, link https://rhope-ops.github.io/RADE, never go.md.
  - No kit sync (the PFM, 2026-11-15): never run the kit's `sync_baseline.py` here (it replaces project guards and rules); port a kit fix by hand, one file at a time, by pull request with review.
  - Platform (the PFM, 2026-11-10; front end 2026-11-16): SharePoint lists and Power Automate in DoD365; the PFM works in a full-screen RADE-style window, other people in SharePoint list forms from an e-mail link. Standard connectors only; no tenant admin rights; no service account, ever. Design: docs/ARCHITECTURE.md, docs/process-model.md.
  - Project log (the PFM, 2026-11-11): it lives in the private Claude doc https://claude.ai/artifact/9zLxe6e9vJPKtRQv5xSSzk, never in this repo.
  - Public repo (the PFM, 2026-11-10; 2026-11-11): the gov device reads it without a login, so never commit the wing's name or location, the site path (only `https://usaf.dps.mil/sites/<your-site>`), people's names, office symbols, DODIDs, seal files or gov-network test details (those go to the private project log).
  - Round results (the PFM, 2026-11-15): do not watch Gmail; search "90161Z R<NN>" only when the PFM says the e-mail is sent or received. Once its results are on main, move an app-drafted round e-mail to Trash and list it by date, time and subject; delete any other result e-mail only after the PFM confirms it in that turn.
  - Scope (the PFM, 2026-11-10): ANG wing publications (supplements, OIs, local publications and forms), posted on the wing's own site (DAFMAN 90-161 1.1.3.2, 6.4); no wing supplement exists; 90-161.Z is the system of record for endorsements (no TMT).
  - Source authority (the PFM, 2026-11-10; 2026-11-11): DAFMAN 90-161 (edition: docs/DECISIONS.md) is the only rule source; cite the paragraph for every stage, time limit and format rule. Wing files shape the customer process only and lose on any contradiction. Format comes from code (docs/format-rules.md), never from the model; no AFIMPT for formatting or tracking.
  - What people see (the PFM, 2026-11-13; 2026-11-14): all text the PFM or a user sees is plain, professional English; every go.md or runner update meets the usability bar in `.claude/skills/round/SKILL.md` (tests/check_guide_text.py and a fresh reader check it before a round ships).
  (rule lines changed against the default branch: each one needs the PFM's approval of its exact text)
RULES PASS
```

## Findings

- MAJOR 1. Gov device "no Claude app or e-mail there" (old: "no e-mail to the work computer") reads as a ban on the round's Outlook draft on the gov device (DECISIONS 2026-11-13 "R05"; round skill: results "attached to one e-mail"). Fix proposed: "no Claude app there, and no e-mail sent to it". Goes to the PFM before the merge.
- MINOR 2. Deployable package "has a tested fallback" against the round skill "a fallback only for a test that FAILED" and DECISIONS "every easy path is tried at least once before a fallback"; the old clause "try each easy path once before a fallback" reconciled them.
- MINOR 3. DECISIONS 2026-11-15 "No kit sync" row not marked replaced. Done: the new kit-sync row says it replaces it once merged.
- MINOR 4. Data boundary, Public repo and the hard rule "Secrets and personal data" overlap (names, office symbols, e-mails).
- MINOR 5. Commands "Credentials: never store, print, log or ask for passwords in chat" overlaps the hard rule "Secrets and personal data"; "Never hand-edit a build output" repeats the Default "Checks".
- Checked, no conflict: Delivery (deliver/PROJECT.md keeps lane C), Project log, Round results, Code standard, Next-step link, Source authority, Scope, Test, Lint, Build, Gov-device code.

rule-conflict-check: 1778b79e54b1

## Second run (after the PFM's text fixes; head c3cf3cf)

Same reviewer setup (fresh `reviewer` subagent, Opus tier). Changed lines: `python3 scripts/bloat_check.py --rules` at c3cf3cf (Gov device and Deployable package texts approved; Public repo and Commands trims for approval).

- No MAJOR finding.
- MINOR 1. "Round results" points to the round skill, and the skill's step 6 points back ("ask first (Project rule "Round results")"); the old condition "delete only after the PFM confirms it in that turn" is now in neither. Proposed fix (for the PFM): round skill step 6 "Any other result e-mail: ask first and act only on the PFM's confirmation in that turn."
- MINOR 2. DECISIONS 2026-11-14 R17 row ("one more A/B round before any fallback") against "built after its easy path fails once"; that row covers R17 only.
- MINOR 3. DECISIONS 2026-11-17 row names docs/code-standard.md and .code-standard.json; now docs/code-standard-90-161.md and .check / .check.state.json (the kit-sync record lists the moves).
- MINOR 4. "no app writes data across the boundary" against the app-drafted round e-mail (fake data, sent by a person); the PFM's intent decides.
- MINOR 5. Data boundary and Public repo overlap the hard rule "Secrets and personal data" (names, e-mails, ID numbers).
- Checked, no conflict: Delivery, Next-step link, Gov device, the "No kit sync" removal, Commands, dropped clauses (still in DECISIONS and docs/ARCHITECTURE.md).

rule-conflict-check: 335d1db099c5
