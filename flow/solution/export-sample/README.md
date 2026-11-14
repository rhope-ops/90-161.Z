# Export sample (R18)

solution.xml and customizations.xml from the PFM's working export "90161ZExportSample" (Power Automate, DoD environment, 14 Nov 26), byte for byte except one masked value: the publisher's display name (it names the wing) reads `MASKED PUBLISHER NAME`. The flow JSON and the zip are not kept (the JSON holds the T11 probe flow; the repo has its source).

Use: `scripts/build_flow_solution.py` r5 copies this layout; `tests/check_flow_solution.py` checks each test zip against it (same lines apart from names, IDs and the connection reference).
