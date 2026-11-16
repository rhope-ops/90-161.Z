#!/usr/bin/env python3
"""Guide text check (AGENTS.md "Gov-device usability" point 3; PFM 2026-11-16).

Reads the steps a person does on the government computer:
- scripts/paste_bundles.json: every line of every `guide` list (the runner window steps);
- go.md: the numbered lines under "Steps:" of each open task (a "## Round ..." or "## Task ..." section
  above "## Done"). Other sections of go.md are not read.

A step FAILS when it:
1. POINTS ELSEWHERE: it sends the reader to another file, section or step for its content
   ("step 10", "block 1", "items 4 to 6", the part "X", "as the window lists", "in the file", "see ...",
   "the previous step", "described in the file", "do the same", "repeat ...").
2. HOLDS 2 ACTIONS: more than one thing to do.
3. IS LONG: more than 200 characters.

How actions are counted (kept simple on purpose):
- Text in "quotes" and in (parentheses) is not read. Text after "type:" or "paste:" is the
  exact text to enter and is not read: write formulas and other literal text there.
- An action is a lower-case verb from VERBS, or one that starts a sentence. A capitalized word
  inside a sentence is a name on the screen (select Save), not an action. A verb after a word
  such as "the", "to", "not" or "must", or at the end of a sentence, is not an action.
- A "then" with no verb after it is one more action (select Open, then Next = 2); "then wait", "then keep",
  "then remember" and a "then" at the end add none. A verb right after "then" counts, capitalized or not.
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

No baseline and no exemption: every step must pass (the R26 r1 baseline was removed with R26 r2, 16 Nov 26).

Usage: check_guide_text.py            check; exit 1 on any failing step
       check_guide_text.py --test     self-test with good and bad sample steps
       check_guide_text.py --list     Markdown list of every failing step
Last line: GUIDE TEXT steps=N failed=F
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLES = ROOT / 'scripts/paste_bundles.json'
GO = ROOT / 'go.md'
MAX_LEN = 200

VERBS = ('select', 'press', 'type', 'paste', 'open', 'click', 'right-click', 'double-click', 'drag', 'tick', 'untick',
         'choose', 'copy', 'cut', 'delete', 'remove', 'close', 'save', 'sign', 'draw', 'add', 'attach', 'return', 'go',
         'turn', 'send', 'ask', 'answer', 'enter', 'import', 'download', 'upload', 'create', 'make', 'look', 'do',
         'use', 'set', 'run', 'start', 'scroll', 'rename')
WAITS = {'wait', 'keep', 'remember'}
NOT_AFTER = {'the', 'a', 'an', 'its', 'your', 'my', 'this', 'that', 'last', 'first', 'next', 'to', 'must', 'can',
             'cannot', 'is', 'are', 'be', 'not', 'no', 'does', 'will', 'which', 'whether', 'every', 'each', 'any',
             'should', 'would', 'could', 'may', 'might'}
THING = r'(?:files?|windows?|guides?|tasks?|rounds?|documents?|sections?|notes?|readme)'
POINTERS = [
    (r'\b(?:steps?|blocks?|items?|parts?|sections?|paragraphs?|attachments?|ways?) (?:\d+|Q)', 'names a step, block, item or part'),
    (r'\b%s (?:says?|lists?|describes?|tells?|explains?)\b' % THING, 'defers to a file or window'),
    (r'\b(?:in|from|of|under) (?:the|that|this) (?:\w+ )?(?:file|guide|document|section|readme)\b(?! (?:name|path|box|explorer|menu|tab)\b)', 'defers to a file or section'),
    (r'\b(?:previous|earlier|same) steps?\b|\bsteps? (?:above|below|before)\b', 'names another step'),
    (r'\b(?:described|explained|listed|given|shown) in (?:the |this |that )?(?:\w+ )?(?:file|guide|document|section|readme|step|window|notes?)\b|\b(?:do|does) the same\b|(?:^|[.;:,] |then )repeat\b', 'refers elsewhere'),
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
        if low == 'then' and i < len(words) - 1 and words[i + 1].lower() not in VERBS and words[i + 1].lower() not in WAITS:
            n += 1  # "then" with no verb after it repeats the last verb (select Open, then Next)
        if low not in VERBS or (i == len(words) - 1 and words[i - 1].lower() != 'then'):
            continue
        if i and ((w[0].isupper() and words[i - 1].lower() != 'then') or words[i - 1].lower() in NOT_AFTER):
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
        '17. Select Open, then wait.',
        '18. Select the repeat option.',
        '19. Select the item shown in the list.',
        '20. Select Save, then.',
        '21. Look at the new tab: the draft should open in the browser.',
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
        ('5. Select Save, then Select Open.', 'holds 2'),
        ('6. Select Save. Repeat for the other files.', 'points'),
        ('7. Select the value shown in the file.', 'points'),
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
    failed = [(where, text, check_step(text)) for where, text in steps if check_step(text)]
    if '--list' in sys.argv:
        last = None
        for where, text, f in failed:
            if where != last:
                print('\n**%s**' % where)
                last = where
            print('- `%s`: %s' % (text if len(text) <= 70 else text[:67] + '...', '; '.join(f)))
    else:
        for where, text, f in failed:
            print('FAIL %s | %s | %s' % (where, text, '; '.join(f)))
    print('GUIDE TEXT steps=%d failed=%d' % (len(steps), len(failed)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
