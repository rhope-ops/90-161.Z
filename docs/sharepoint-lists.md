# SharePoint lists by PnP

The 12 PFM lists are defined in [schemas/lists](../schemas/lists). `python3 scripts/build_flow_payload.py` makes flow/provisioning-payload.json from them: one payload for both ways to build the lists.

- By PnP (PFM, 2026-11-14): `scripts/gov/90161Z-T20-provision-lists-r1.ps1` replays the payload on the signed-in site. Its header lists the modes (plan, check, dry run, create) and what it changes. First device run: Round R25 (go.md). Cloud test: tests/ps/Test-T20.ps1 on a fake site.
- By flow (the fallback; worked in R11 to R13): [power-automate-provisioning.md](power-automate-provisioning.md).

List design and decisions: [DECISIONS.md](DECISIONS.md) and [reviews/2026-11-12-list-design-full-scope.md](reviews/2026-11-12-list-design-full-scope.md).
