# Compliance

Each control below names the rule it meets and the check or record that proves it. A check runs in `scripts/check.sh` unless the line says another place. Updated 2026-11-23 (fleet v2 Stage 3A).

| Control | Source | Evidence |
|---|---|---|
| Government data stays in DoD365 and GenAI.mil; fake data only in this repository | AGENTS.md "Project rules", data boundary | Content check on every push (`scripts/check.sh --content`) |
| No secrets, credentials or personal data in commits | AGENTS.md "Hard rules", secrets and personal data | Content check; scripts take credentials only through `Get-Credential` |
| Every stage, time limit and format rule cites DAFMAN 90-161 | AGENTS.md "Project rules", source authority | `ref/` copies with `ref/SHA256SUMS` (`cd ref && sha256sum -c SHA256SUMS`) |
| Color contrast meets WCAG 2.1 AA (4.5:1 text, 3:1 controls) | WCAG 2.1 SC 1.4.3, 1.4.11 | `tests/check_palette.py`: docs/palette.json pairs and the real CSS tokens of index.html and templates/list-mockup.css |
| The page has a skip link, a visible focus ring and a live region for button results | WCAG 2.1 SC 2.4.1, 2.4.7, 4.1.3 | index.html; `.claude/skills/verify/measure.mjs` (contrast, target size, overflow) |
| The page runs no inline script and loads data from one source only (this repository's branch folder on raw.githubusercontent.com) | Defense in depth (OWASP ASVS V14.4) | index.html CSP; `docs/threat-model.md` |
| Python and JavaScript code is scanned for security defects | Master plan P4b (2026-11-23) | `.github/workflows/codeql.yml` (CodeQL v4.39.5, pinned by commit; pull requests and manual runs). No PowerShell support: PSScriptAnalyzer in `scripts/lint.sh`. |
| Code is modular, commented and readable as plain text | AGENTS.md "Project rules", code standard | `scripts/code_standard.py` and `docs/code-standard-90-161.md` |
| Hand-written source files stay at 450 lines or fewer; generated files and user-paste scripts at 600 | Fleet v2 DEC 6 | `wc -l` by hand: `scripts/code_standard.py` C4 enforces 600 until the kit 11.0.0 sync. Open: `scripts/build_flow_solution.py` (482) and `scripts/logo_svg.py` (458). |
| PowerShell execution policy is not turned off by a script | DEC-EXEC (fleet v3, 2026-11-27); Group Policy governs | No file passes the value Bypass to `-ExecutionPolicy`, CI included (`.github/workflows/ps51.yml` runs under the runner policy). Check: `python3 scripts/nipr_guard.py` (from Kit 16.0.0) |
| The RADE engine is pinned and attested | AGENTS.md "Project rules", deployable package | `scripts/rade.lock.json`; `python3 scripts/bump_lock.py --test` |
| Generated files are never stale | AGENTS.md "Defaults", one home | `python3 scripts/rebuild_all.py --check` |
| No app looks like network reconnaissance | AGENTS.md "Project rules", no reconnaissance | Fixed hosts only (`site.config.json`, the one site the person types) |

Open items: a static-analysis gate (bandit 1.9.4) and a secret scan (gitleaks 8.30.1) in CI (`.github/workflows/security.yml`). It starts after two bandit findings close: `scripts/bloat_check.py:241` (a kit file; fixed by the kit 11.0.0 sync) and `scripts/logo_svg.py:45` (the PFM's choice: a reasoned `# nosec`, or the defusedxml package).
