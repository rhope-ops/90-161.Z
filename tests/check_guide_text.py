#!/usr/bin/env python3
"""Guide text check (AGENTS.md "Gov-device usability" point 3; PFM 2026-11-16).

Reads the steps a person does on the government computer:
- scripts/paste_bundles.json: every line of every `guide` list (the runner window steps);
- go.md: the numbered lines under "Steps:" of each open task (a "## Round ..." or "## Task ..." section
  above "## Done"). Other sections of go.md are not read.

A step FAILS when it:
1. POINTS ELSEWHERE: it sends the reader to another file, section or step for its content
   ("step 10", "block 1", "items 4 to 6", the part "X", "as the window lists", "in the file", "see ...").
2. HOLDS 2 ACTIONS: more than one thing to do.
3. IS LONG: more than 200 characters.

How actions are counted (kept simple on purpose):
- Text in "quotes" and in (parentheses) is not read. Text after "type:" or "paste:" is the
  exact text to enter and is not read: write formulas and other literal text there.
- An action is a lower-case verb from VERBS, or one that starts a sentence. A capitalized word
  inside a sentence is a name on the screen (select Save), not an action. A verb after a word
  such as "the", "to", "not" or "must", or at the end of a sentence, is not an action.
- A "then" with no verb after it is one more action (select Open, then Next = 2).
- A sentence with "if" is a fallback: it may hold 1 action of its own (If one reads Off, turn
  it on). The other sentences of the step may hold 1 action together.
- A line with no number (the "If it fails" line of a guide) is tested for 1 and 3 only.

Limits (a pass here is not proof that a step is clear; the fresh-reader check in the rule does that):
- A menu path (A > B > C) counts as 1 action.
- Two things joined by "and" with one verb count as 1 action (tick "A" and "B").
- A value given as "Label: value" with no verb is not counted.
- An action written after the literal text of "type:" or "paste:" is not read: put it in the next step.
- "wait", "keep" and "remember" are not counted as actions.
- A verb that is not in VERBS is not counted; a pointer worded in a way POINTERS does not know is not found.
- Build words (block, way, part, item) are found only when they point (block 1, the part "X").

Baseline: tests/check_guide_text.baseline.json lists the steps of Round R26 r1 that fail. R26 r1
shipped before this check existed and its text is rewritten in one pass after its results arrive
(PFM 2026-11-16). A listed step is REPORTED on every run and does not fail the check. An entry
matches the exact text of a step, so an edited step is checked again; an entry that matches no
failing step fails the check. Never add an entry to make a new step pass. The file is removed
when the R26 steps are rewritten.

Usage: check_guide_text.py            check; exit 1 on a failure that is not in the baseline
       check_guide_text.py --test     self-test with good and bad sample steps
       check_guide_text.py --list     Markdown list of every failing step (baseline included)
Last line: GUIDE TEXT steps=N failed=F known=K
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLES = ROOT / 'scripts/paste_bundles.json'
GO = ROOT / 'go.md'
BASELINE = ROOT / 'tests/check_guide_text.baseline.json'
MAX_LEN = 200

VERBS = ('select', 'press', 'type', 'paste', 'open', 'click', 'right-click', 'double-click', 'drag', 'tick', 'untick',
         'choose', 'copy', 'cut', 'delete', 'remove', 'close', 'save', 'sign', 'draw', 'add', 'attach', 'return', 'go',
         'turn', 'send', 'ask', 'answer', 'enter', 'import', 'download', 'upload', 'create', 'make', 'look', 'do',
         'use', 'set', 'run', 'start', 'scroll', 'rename')
NOT_AFTER = {'the', 'a', 'an', 'its', 'your', 'my', 'this', 'that', 'last', 'first', 'next', 'to', 'must', 'can',
             'cannot', 'is', 'are', 'be', 'not', 'no', 'does', 'will', 'which', 'whether', 'every', 'each', 'any'}
THING = r'(?:files?|windows?|guides?|tasks?|rounds?|documents?|sections?|notes?|readme)'
POINTERS = [
    (r'\b(?:steps?|blocks?|items?|parts?|sections?|paragraphs?|attachments?|ways?) (?:\d+|Q)', 'names a step, block, item or part'),
    (r'\b%s (?:says?|lists?|describes?|tells?|explains?)\b' % THING, 'defers to a file or window'),
    (r'\b(?:in|from|of|under) (?:the|that|this) (?:\w+ )?(?:file|guide|document|section|readme)\b(?! (?:name|path|box|explorer|menu|tab)\b)', 'defers to a file or section'),
    (r'\b(?:previous|earlier|same) steps?\b|\bsteps? (?:above|below|before)\b', 'names another step'),
    (r'\b(?:described|explained|listed|given|shown) in\b|\b(?:do|does) the same\b|\brepeat\b', 'refers elsewhere'),
    (r'(?:^|[.;:,] )see\b|\b(?:refer to|according to|as above|as below|as before|as described|same as)\b', 'refers elsewhere'),
]
WORD = re.compile(r"[A-Za-z][A-Za-z'-]*")


def strip(text):
    """Remove the step number, literal text, parentheses; replace each quoted text by Q."""
    t = re.sub(r'^\s*\d+\.\s+', '', text)
    t = re.sub(r'\b(type|paste):.*$', r'\1 Q', t, flags=re.I | re.S)
    t = re.sub(r'"[^"]*"', 'Q', t)
    return re.sub(r'\([^()]*\)', '', t)


def count_actions(sentence):
    words = WORD.findall(sentence)
    n = 0
    for i, w in enumerate(words):
        low = w.lower()
        if low == 'then' and (i == len(words) - 1 or words[i + 1] not in VERBS):
            n += 1  # "then" with no verb after it repeats the last verb (select Open, then Next)
        if low not in VERBS or (i == len(words) - 1 and words[i - 1].lower() != 'then'):
            continue
        if i and (w[0].isupper() or words[i - 1].lower() in NOT_AFTER):
            continue
        n += 1
    return n


def check_step(text):
    """Return the list of failures of one step (empty = pass)."""
    out = []
    t = strip(text)
    for rx, why in POINTERS:
        m = re.search(rx, t, re.I)
        if m:
            out.append('points elsewhere (%s: "%s")' % (why, m.group(0).replace('Q', '"..."')))
            break
    if re.match(r'\s*\d+\.\s', text):
        plain = cond_max = 0
        for s in re.split(r'(?<=[.!?])\s+', t):
            n = count_actions(s)
            if re.search(r'\bif\b', s, re.I):
                cond_max = max(cond_max, n)
            else:
                plain += n
        if plain > 1 or cond_max > 1:
            out.append('holds %d actions' % max(plain, cond_max))
    if len(text) > MAX_LEN:
        out.append('is %d characters (limit %d)' % (len(text), MAX_LEN))
    return out


def bundle_steps():
    for b in json.loads(BUNDLES.read_text(encoding='utf-8'))['bundles']:
        for s in b.get('steps', []):
            for line in s.get('guide', []):
                yield '%s / %s' % (b.get('round', '?'), s['name']), line


def go_steps(text=None):
    task, on = None, False
    for line in (GO.read_text(encoding='utf-8') if text is None else text).split('\n'):
        if line.startswith('## '):
            if line.strip() == '## Done':
                return
            task, on = (line[3:].strip() if re.match(r'## (Round|Task)\b', line) else None), False
        elif task and line.strip() == 'Steps:':
            on = True
        elif on and re.match(r'\d+\.\s', line):
            yield 'go.md / %s' % task, line
        elif on and line.strip() and not line.startswith('http'):
            on = False


def self_test():
    good = [
        '1. Select "Open in browser".',
        '2. Select Solutions.',
        '3. In the File name box, press Ctrl+V.',
        '4. Select Create > Blank app > Blank canvas app.',
        '5. In Tree view, double-click the name of the form.',
        '6. Type: frmProbe',
        '7. In the formula bar, type: Notify("T10: row saved"); NewForm(frmProbe)',
        '8. Select Save (Ctrl+S).',
        '9. Open the solution. The 3 flows must read On. If one reads Off, turn it on.',
        '10. Select the button "T4 a". A green line must say the row was written.',
        '11. Power Automate opens. Sign in with your CAC if asked.',
        '12. Keep Notepad open.',
        '13. Return to RADE.',
        '14. Tick "90161Z Probe" and "90161Z Probe Files".',
        'If something does not delete: type its name below, then select "It failed".',
        'If a button shows a red line: go on with the next step.',
    ]
    bad = [
        ('1. Set the form as the part "BY HAND for block 6" in the file says, items 4 to 6 (3 short formulas).', 'points'),
        ('2. Do step 10 again for the other code.', 'points'),
        ('3. In Notepad, copy block 1.', 'points'),
        ('4. Look in Power Automate as the window says.', 'points'),
        ('5. Fill in the values. See the setup document.', 'points'),
        ('If a paste is refused: use the lines under it in the file.', 'points'),
        ('1. Paste the text from the previous step.', 'points'),
        ('2. Run the script described in the README.', 'points'),
        ('3. Do the same for the second app.', 'points'),
        ('4. Select Save then close.', 'holds 2'),
        ('6. Select Import solution, then Browse.', 'holds 2'),
        ('7. Press Ctrl+V, select Open, then Next.', 'holds 3'),
        ('8. Select Save. Select Publish.', 'holds 2'),
        ('9. Return to RADE and select "Done: imported".', 'holds 2'),
        ('10. If it is offered: select it, open its Prompt list and look at the names.', 'holds 3'),
        ('11. Select the field. ' + 'The field is the one with the long name. ' * 5, 'characters'),
    ]
    errs = []
    for s in good:
        if check_step(s):
            errs.append('good step failed: %s -> %s' % (s, check_step(s)))
    for s, want in bad:
        if not any(want in f for f in check_step(s)):
            errs.append('bad step not found (%s): %s -> %s' % (want, s, check_step(s)))
    got = list(go_steps('## How\nSteps:\n1. no\n## Round A\nSteps:\n1. Select Run.\nhttps://x\n2. Select Done.\n\nNote\n3. no\n## Done\nSteps:\n1. no\n'))
    if [g[1] for g in got] != ['1. Select Run.', '2. Select Done.']:
        errs.append('go.md reader: %s' % got)
    for e in errs:
        print('SELF-TEST FAIL ' + e)
    print('GUIDE TEXT self-test good=%d bad=%d errors=%d' % (len(good), len(bad), len(errs)))
    return 1 if errs else 0


def main():
    if '--test' in sys.argv:
        return self_test()
    steps = list(bundle_steps()) + list(go_steps())
    known = json.loads(BASELINE.read_text(encoding='utf-8'))['steps'] if BASELINE.exists() else []
    known_set = {(k['where'], k['text']) for k in known}
    failed, new, used = [], 0, set()
    for where, text in steps:
        f = check_step(text)
        if not f:
            continue
        failed.append((where, text, f))
        if (where, text) in known_set:
            used.add((where, text))
        else:
            new += 1
    if '--list' in sys.argv:
        last = None
        for where, text, f in failed:
            if where != last:
                print('\n**%s**' % where)
                last = where
            print('- `%s`: %s' % (text if len(text) <= 70 else text[:67] + '...', '; '.join(f)))
    else:
        for where, text, f in failed:
            print('%s %s | %s | %s' % ('KNOWN' if (where, text) in known_set else 'FAIL', where, text, '; '.join(f)))
    stale = known_set - used
    for where, text in sorted(stale):
        print('STALE baseline entry (the step changed or passes; remove the entry) %s | %s' % (where, text))
    if known:
        print('NOTE %d failing steps of the shipped R26 r1 text are in the baseline: reported, not blocking.' % len(used))
    print('GUIDE TEXT steps=%d failed=%d known=%d' % (len(steps), len(failed), len(used)))
    return 1 if new or stale else 0


if __name__ == '__main__':
    sys.exit(main())
