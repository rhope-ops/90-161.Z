# Deliver: what 90-161.Z adds

Read with `.claude/skills/deliver/SKILL.md`; this file wins over it (AGENTS.md "Kit files"). From the "Delivery" Project rule (the PFM, 2026-11-13; 2026-11-15; names updated for kit 2026.11.20.1 on 2026-11-18).

- One pull request per round or request, never a push to main.
- Merge by hand (no auto-merge), and only when all of these pass:
  1. the full lane (`scripts/check.sh`) on the head commit;
  2. `python3 scripts/check_content.py --require-denylist --all --range origin/main..HEAD --allow-from origin/main`;
  3. the "checks" pull-request check;
  4. the fresh review finds no MAJOR finding (a MAJOR finding: ask the PFM).
- Lane C (AGENTS.md "Delivery") still asks the PFM first.
