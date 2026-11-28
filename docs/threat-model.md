# Threat model

Scope: this repository's page (index.html, go.js), its build scripts, the round bundles it publishes and the task scripts that run on a government computer. The RADE engine has its own threat model in its repository. Written 2026-11-23 (fleet v2 Stage 3A); review it when a trust boundary changes.

## Assets

| Asset | Why it matters |
|---|---|
| Round bundles (`scripts/gov/paste/*.ps1`) | A person pastes them into PowerShell on a government computer. A changed bundle runs with that person's rights. |
| Task scripts (`scripts/gov/*.ps1`) | Embedded in the bundles; they sign in to the wing's SharePoint site with the person's own account. |
| The RADE engine lock (`scripts/rade.lock.json`) | Names the engine commit and file hashes that build every bundle. |
| The page (`index.html`, `go.js`) | Gives the person the bundle text to copy. |
| Government data | Never in this repository (AGENTS.md "Project rules", data boundary). |

## Trust boundaries

1. GitHub (this public repository, its Pages site, raw.githubusercontent.com) to the person's browser.
2. The browser clipboard to Windows PowerShell on the government computer.
3. The RADE release (another repository) to this repository's build.
4. The government computer to DoD365 (SharePoint, Power Automate), with the person's own account.

## Threats and controls

| Threat | Control | Evidence |
|---|---|---|
| A changed go.md puts script or a hostile link into the page | `scripts/build_go_page.py` builds the cards at build time with markdown-it-py (CommonMark, raw HTML off): go.md text is escaped, images are off, links keep http(s) or `#` only (no `//host`, `mailto:`, `data:` or file links) and get `rel="noopener noreferrer"`; go.js makes no HTML from text (no `innerHTML`, no `DOMParser`) | `python3 scripts/build_go_page.py --test` (hostile go.md: no script, image, event attribute, `javascript:`, `data:`, `mailto:` or `//host` link; it runs in `scripts/check.local.sh` on every push); `tests/check_go_page.js` |
| Injected script on the page | CSP `script-src 'self'` (no inline script), `default-src 'none'`, `connect-src` to one source only, this repository's branch folder on raw.githubusercontent.com (the round script the Copy script button fetches; nothing from this site; master plan P4b, 2026-11-24; the build writes the source from `site.config.json`), `base-uri 'none'`, `form-action 'none'`, `object-src 'none'` | index.html `<meta http-equiv="Content-Security-Policy">`; `tests/check_go_page.js` (connect-src is one source and equals `site.config.json`); a Chromium run (0 policy reports, cards in the page, Copy script ready, a fetch to this site blocked) |
| A tampered value in this browser's storage | `validState()` keeps only short string keys with true/false values, in an object with no prototype | `tests/check_go_page.js` |
| A link leaks the page address, or a new tab controls the page | `rel="noopener noreferrer"` on every made link; `<meta name="referrer" content="no-referrer">` | `scripts/build_go_page.py`, index.html |
| A changed RADE engine builds a bad bundle | The lock pins a commit and a SHA-256 for each engine file; `bump_lock.py` checks the release lock against the tag's commit, traces the files the build opens and runs every check before it keeps the lock | `python3 scripts/bump_lock.py --test` (38 cases) |
| The release lock is read over plain http or a redirect to http | `https_only()` and an opener that refuses a non-https redirect | `scripts/bump_lock_test.py` guard cases |
| A wrong account value enters a URL | Code reads the account values from `site.config.json`; `scripts/build_go_page.py` writes the page CSP source from them and stops when a name has a character other than letters, digits, `.`, `_` or `-`; `bump_lock.py` accepts only `owner/name` style names. The RADE manifest `scripts/paste_bundles.json` ("repo", "home") keeps its own copy until the engine-v36 rebuild. | `python3 scripts/build_go_page.py --test`; `tests/check_go_page.js`; `bump_lock.py` `REPO_RE` |
| A script turns off the PowerShell execution policy | No task script, test, generator or CI step passes the value Bypass to `-ExecutionPolicy` (DEC-EXEC, fleet v3, 2026-11-27); Group Policy on the computer governs. | `python3 scripts/nipr_guard.py` (from Kit 16.0.0) |
| Personal or government data in a commit | The content check on every push and every write tool call | `scripts/check.sh --content` |
| A round collects or sends a script file | The bundle build fails a collect pattern that can match one | `scripts/check_collect.py` |

## Known limits (accepted)

- `style-src` keeps `'unsafe-inline'`: the page has one inline `<style>` block, and no go.md text reaches CSS.
- GitHub Pages does not let this repository set HTTP headers, so the CSP is a `<meta>` tag: `frame-ancestors` and reporting are not available.
- The page shows go.md as of its last build: after a go.md change, run `python3 scripts/build_go_page.py` (the push fails while the page is stale).
- A person can still paste a bundle from another source. The page and go.md name the one source; the bundle shows its round and revision.
