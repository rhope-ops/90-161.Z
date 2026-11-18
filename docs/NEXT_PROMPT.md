# Next prompt: 90-161.Z

Updated 2026-11-18 (kit 1.0.1 sync; bundle revisions, PR 153; lock engine-v17, PR 157). Short by the session-load cap; full open items: [docs/reviews/2026-11-18-handoff-detail.md](reviews/2026-11-18-handoff-detail.md).

## Open

1. Kit sync PR (kit 1.0.1): merge approved by the PFM (lane C); [kit sync](reviews/2026-11-18-kit-sync.md).
2. R30 (not built): R29a Power Automate steps again; R29b r7 fallbacks and defects V2-V4 (T22 r4); V1 and the timer in a RADE session started 18 Nov; bookmark subtitle; S1 code-standard refactor ([phases](phases.md)). R29b r7 first proves the T22 C# helper.
4. Risk: a T22 r4 rename fails the code-standard gate (new file, ~1,400 lines). [Detail](reviews/2026-11-18-dependabot-and-lock.md).
3. Next change to scripts/bump_lock.py or scripts/bundle_revision.py (PFM, 18 Nov): fix the 2 MINOR review items of PR 153: test raise_bundle_revisions itself, not only a fake; limit the go.md rename to bundle links.
