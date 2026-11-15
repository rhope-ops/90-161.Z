#!/usr/bin/env python3
"""Write the Task 11 Part B rows (docs/rights-test-plan.md section 6) to scripts/gov/data/90161Z-T11-partb-rows-r1.json.

One source: the table in the plan. The RADE round's Part B form (scripts/gov/90161Z-T11-partb-form-r2.ps1) reads this
file, so the form never drifts from the plan. Never hand-edit the JSON.
Usage: python3 scripts/build_rights_rows.py [--check]   (--check: exit 1 if the JSON is out of date)
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'docs/rights-test-plan.md'
OUT = ROOT / 'scripts/gov/data/90161Z-T11-partb-rows-r1.json'


def rows():
    text = SRC.read_text(encoding='utf-8')
    sec = text[text.index('## 6. Manual checks'):]
    sec = sec[:sec.index('\n## ', 5)]
    out = []
    for line in sec.splitlines():
        m = re.match(r'^\|\s*(M\d\d)\s*\|(.*)\|(.*)\|\s*$', line)
        if m:
            out.append({'id': m.group(1), 'do': m.group(2).strip(), 'note': m.group(3).strip()})
    if not out:
        raise SystemExit('no M rows found in docs/rights-test-plan.md section 6')
    return out


def main():
    text = json.dumps({'source': 'docs/rights-test-plan.md section 6', 'rows': rows()}, indent=2, ensure_ascii=True) + '\n'
    if '--check' in sys.argv:
        ok = OUT.exists() and OUT.read_text(encoding='utf-8') == text
        print('RIGHTS rows=%d stale=%d' % (len(rows()), 0 if ok else 1))
        return 0 if ok else 1
    OUT.write_text(text, encoding='utf-8')
    print('BUILT %s rows=%d' % (OUT.relative_to(ROOT), len(rows())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
