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
2. HOLDS 4 ACTIONS: more than MAX_ACTIONS (3) things to do on one screen.
3. IS LONG: more than 200 characters.

How actions are counted (kept simple on purpose):
- Text in "quotes" and in (parentheses) is not read. Text after "type:" or "paste:" is the
  exact text to enter and is not read: write formulas and other literal text there.
- An action is a lower-case verb from VERBS, or one that starts a sentence. A capitalized word
  inside a sentence is a name on the screen (select Save), not an action. A verb after a word
  such as "the", "to", "not" or "must", or at the end of a sentence, is not an action.
- A "then" with no verb after it is one more action (select Open, then Next = 2); "then wait", "then keep",
  "then remember" and a "then" at the end add none. A verb right after "then" counts, capitalized or not.
- A sentence with "if" is a fallback (If one reads Off, turn it on). The fallback with the most actions and the
  other sentences of the step may hold up to 3 actions together.
- A line with no number (the "If it fails" line of a guide) is tested for 1 and 3 only.

Limits (a pass here is not proof that a step is clear; the fresh-reader check in the rule does that):
- A menu path (A > B > C) counts as 1 action.
- Two things joined by "and" with one verb count as 1 action (tick "A" and "B").
- A value given as "Label: value" with no verb is not counted.
- An action written after the literal text of "type:" or "paste:" is not read: put it in the next step.
- "wait", "keep" and "remember" are not counted as actions.
- A verb that is not in VERBS is not counted; a pointer worded in a way POINTERS does not know is not found.
- Build words (block, way, part, item) are found only when they point (block 1, the part "X").

Runner text rules (docs/reviews/2026-11-17-runner-polish.md, the PFM, 17 Nov 26), checked on every step of the manifest
(check_step_rules): a step FAILS with no `title`, a title over 56 characters or with a code (T<NN>, r<N>, F<NN>, R<NN>)
or build word (slice, probe solution, estimate), a note with a code or build word, a guide over 10 numbered lines or a
line over 100 characters, an unnumbered line between numbered lines, a `doneText` on a step with no questions (B6, the
PFM 18 Nov 26: only a look step, one with `answers`, names what was done; at most 30 characters), the word "grey", a pick question with 4 or more choices (R41: the PFM, 20 Nov 26), a line "Return
to the RADE window" or "Select Done ...", and a card with an address whose line 1 is not `Select "Open in browser" above.`

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
MAX_ACTIONS = 3   # actions in one step, on one screen (AGENTS.md "Instructions people follow", kit 12.0.0)

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
    (r'\b(?:described|explained|listed|given|shown) in (?:the |this |that )?(?:\w+ )?(?:file|guide|document|section|readme|step|window|notes?|appendix|attachment)\b'
     r'|\b(?:do|does) the same\b|(?:^|[.;:,] |then |and )repeat\b', 'refers elsewhere'),
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
    """Count the actions in one sentence (the verbs in VERBS that start an action; see the header for the rules). Takes the sentence text; returns a number."""
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
        if plain + cond_max > MAX_ACTIONS:   # the main part and the fallback together
            out.append('holds %d actions' % (plain + cond_max))
    if len(text) > MAX_LEN:
        out.append('is %d characters (limit %d)' % (len(text), MAX_LEN))
    return out


CODE = re.compile(r'\b(?:T\d{1,2}|F\d{2}|R\d{1,2}|r\d{1,2})[a-z]?\b', re.I)   # F5 (a key) is no flow code: F + 2 digits
BUILD = re.compile(r'\b(?:slice|probe solution|estimate)\b', re.I)
TITLE_MAX, LINE_MAX, LINES_MAX = 56, 100, 10
PICK_MAX = 3   # choices of a pick question (R41, the PFM 20 Nov 26: B5 of the RADE runner)
NUMBERED = re.compile(r'\s*\d+\.\s')


def check_step_rules(s):
    """Return the runner text rule failures of one manifest step (empty = pass)."""
    out = []
    title = s.get('title')
    if not (title or '').strip():
        out.append('has no title')
    else:
        if len(title) > TITLE_MAX:
            out.append('title is %d characters (limit %d)' % (len(title), TITLE_MAX))
        if CODE.search(re.sub(r'"[^"]*"', '', title)) or BUILD.search(title):
            out.append('title has a code or build word: "%s"' % title)
    for field in ('note', 'help'):
        text = re.sub(r'"[^"]*"', '', s.get(field, ''))
        if CODE.search(text) or BUILD.search(text):
            out.append('%s has a code or build word' % field)
    shown = [title or '', s.get('note', ''), s.get('help', '')] + list(s.get('guide', []))
    for a in s.get('answers', []):
        shown += [a.get('prompt', '')] + list(a.get('choices', []))
    # R41 (the PFM, 20 Nov 26; R40 finding 5): the RADE runner shows each choice of a pick question as a button beside the
    # primary, and its rule is 3 at most (UI standard B5), so a pick question has 3 choices at most.
    for a in s.get('answers', []):
        if a.get('kind') == 'pick' and len(a.get('choices', [])) > PICK_MAX:
            out.append('pick question "%s" has %d choices (limit %d)' % (a.get('key', ''), len(a.get('choices', [])), PICK_MAX))
    if any(re.search(r'\bgrey', x, re.I) for x in shown):
        out.append('"grey": use gray')
    # B6 (the PFM, 18 Nov 26): a look step (one with questions) may name what was done; every other card keeps "Done".
    done = s.get('doneText', '')
    if done and not s.get('answers'):
        out.append('sets doneText "%s" on a step with no questions' % done)
    if len(done) > 30:
        out.append('doneText is %d characters (limit 30)' % len(done))
    guide = s.get('guide', [])
    nums = [i for i, g in enumerate(guide) if NUMBERED.match(g)]
    if len(nums) > LINES_MAX:
        out.append('guide has %d numbered lines (limit %d)' % (len(nums), LINES_MAX))
    if nums and any(not NUMBERED.match(guide[i]) for i in range(nums[0], nums[-1])):
        out.append('an unnumbered line sits between numbered lines')
    if s.get('url') and (not guide or guide[0] != '1. Select "Open in browser" above.'):
        out.append('line 1 of a card with an address is not: 1. Select "Open in browser" above.')
    for g in guide:
        if len(g) > LINE_MAX:
            out.append('line over %d characters (%d): %s' % (LINE_MAX, len(g), g[:40]))
        if re.search(r'Return to the RADE window|\bselect\s+\\?"?Done\b', g, re.I):
            out.append('line to drop (the engine prints the closing line): %s' % g[:50])
    return out


def manifest_steps():
    """Walk the steps of every bundle in scripts/paste_bundles.json. Takes nothing; yields (round / step name, step dict)."""
    for b in json.loads(BUNDLES.read_text(encoding='utf-8'))['bundles']:
        for s in b.get('steps', []):
            yield '%s / %s' % (b.get('round', '?'), s['name']), s


def bundle_steps():
    """Walk every guide line of every step in scripts/paste_bundles.json. Takes nothing; yields (round / step name, line)."""
    for b in json.loads(BUNDLES.read_text(encoding='utf-8'))['bundles']:
        for s in b.get('steps', []):
            for line in s.get('guide', []):
                yield '%s / %s' % (b.get('round', '?'), s['name']), line


def go_steps(text=None):
    """Walk the numbered lines under "Steps:" of each open round or task in go.md. Takes optional text to read instead of the file; yields (go.md / task title, line).

    A task is a "## Round ..." or "## Task ..." section, or (go.md layout since 16 Nov 26, PFM 1B 18 Nov 26) a
    "### Round ..." or "### Task ..." item under a "## " group; "Steps:" may be bold ("**Steps:**")."""
    task, on = None, False
    for line in (GO.read_text(encoding='utf-8') if text is None else text).split('\n'):
        m = re.match(r'#{2,3} ((Round|Task)\b.*)', line)
        if line.startswith('## ') or line.startswith('### '):
            if line.strip() == '## Done':
                return
            task, on = (m.group(1).strip() if m else None), False
        elif task and line.strip().strip('*') == 'Steps:':
            on = True
        elif on and re.match(r'\d+\.\s', line):
            yield 'go.md / %s' % task, line
        elif on and line.strip() and not line.startswith('http'):
            on = False


# Steps that must pass check_step (the self-test).
GOOD_STEPS = [
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
    '4. Select Save then close.',
    '5. Select Save, then Select Open.',
    '6. Select Import solution, then Browse.',
    '7. Press Ctrl+V, select Open, then Next.',
    '8. Select Save. Select Publish.',
    '9. Return to RADE and select "Done: imported".',
    '10. If it is offered: select it, open its Prompt list and look at the names.',
]

# (step, text its failure must contain) pairs that must fail check_step (the self-test).
BAD_STEPS = [
    ('1. Set the form as the part "BY HAND for block 6" in the file says, items 4 to 6 (3 short formulas).', 'points'),
    ('2. Do step 10 again for the other code.', 'points'),
    ('3. In Notepad, copy block 1.', 'points'),
    ('4. Look in Power Automate as the window says.', 'points'),
    ('5. Fill in the values. See the setup document.', 'points'),
    ('If a paste is refused: use the lines under it in the file.', 'points'),
    ('1. Paste the text from the previous step.', 'points'),
    ('2. Run the script described in the README.', 'points'),
    ('3. Do the same for the second app.', 'points'),
    ('4. Select Save, then select Open. Press Ctrl+V. Select Next.', 'holds 4'),
    ('6. Select Save. Repeat for the other files.', 'points'),
    ('7. Select the value shown in the file.', 'points'),
    ('8. Select Save and repeat for the other files.', 'points'),
    ('9. Select the code listed in Appendix B.', 'points'),
    ('10. If it is offered: select it, open its Prompt list, select Save and look at the names.', 'holds 4'),
    ('11. Click File, then New, then Save. If it fails, click Back.', 'holds 4'),
    ('12. Select Save, then Open, then Close, then Next.', 'holds 4'),
    ('11. Select the field. ' + 'The field is the one with the long name. ' * 5, 'characters'),
]

# (manifest step, text its failure must contain) pairs that must fail check_step_rules (the self-test).
BAD_RULES = [
    ({'guide': ['1. Select Run.']}, 'has no title'),
    ({'title': 'x' * 57}, 'title is 57'),
    ({'title': 'Import the T21 flow'}, 'title has a code'),
    ({'title': 'Make the probe solution'}, 'title has a code or build word'),
    ({'title': 'a', 'note': 'About 3 minutes (estimate).'}, 'note has a code'),
    ({'title': 'a', 'guide': ['%d. Select Run.' % i for i in range(1, 12)]}, '11 numbered lines'),
    ({'title': 'a', 'guide': ['1. Select ' + 'x' * 100]}, 'line over 100'),
    ({'title': 'a', 'guide': ['1. Select A.', 'If x: select B.', '2. Select C.']}, 'unnumbered line sits'),
    ({'title': 'a', 'doneText': 'Done: x'}, 'sets doneText'),
    ({'title': 'a', 'doneText': 'x' * 31, 'answers': [{'prompt': 'Is it?', 'kind': 'yesno'}]}, 'doneText is 31'),
    ({'title': 'a', 'guide': ['1. Select the Grey box.']}, '"grey"'),
    ({'title': 'a', 'note': 'The greyed box.'}, '"grey"'),
    ({'title': 'a', 'help': 'A grey box.'}, '"grey"'),
    ({'title': 'a', 'answers': [{'prompt': 'Is it grey?', 'choices': ['Yes']}]}, '"grey"'),
    ({'title': 'a', 'answers': [{'prompt': 'Is it?', 'choices': ['Grey']}]}, '"grey"'),
    ({'title': 'a', 'help': 'Send T21 results.'}, 'help has a code'),
    ({'title': 'a', 'note': 'The t21 step.'}, 'note has a code'),
    ({'title': 'Do T21a now'}, 'title has a code'),
    ({'title': 'a', 'note': 'Run F03.'}, 'note has a code'),
    ({'title': '   '}, 'has no title'),
    ({'title': 'a', 'guide': ['If it is gone: select "done".']}, 'line to drop'),
    ({'title': 'a', 'guide': ['1. Return to the RADE window.']}, 'line to drop'),
    ({'title': 'a', 'guide': ['1. Select "Done: x".']}, 'line to drop'),
    ({'title': 'a', 'guide': ['If it is gone: select "Done".']}, 'line to drop'),
    ({'title': 'a', 'url': 'https://x', 'guide': ['1. On this RADE card, select "Open in browser".']}, 'line 1 of a card'),
    ({'title': 'a', 'answers': [{'key': 'w-look', 'prompt': 'Is it?', 'kind': 'pick', 'choices': ['A', 'B', 'C', 'D']}]}, 'has 4 choices (limit 3)'),
]


def self_test_steps():
    """Run check_step on the good and bad sample steps. Takes nothing; returns a list of error messages (empty = pass)."""
    errs = []
    for s in GOOD_STEPS:
        if check_step(s):
            errs.append('good step failed: %s -> %s' % (s, check_step(s)))
    for s, want in BAD_STEPS:
        if not any(want in f for f in check_step(s)):
            errs.append('bad step not found (%s): %s -> %s' % (want, s, check_step(s)))
    return errs


def self_test_go():
    """Check that go_steps reads only the numbered lines under "Steps:" of open tasks, in both go.md layouts.

    Returns:
        A list of error messages (empty when the reader is right).
    """
    errs = []
    got = list(go_steps('## How\nSteps:\n1. no\n## Round A\nSteps:\n1. Select Run.\nhttps://x\n2. Select Done.\n\nNote\n3. no\n## Done\nSteps:\n1. no\n'))
    if [g[1] for g in got] != ['1. Select Run.', '2. Select Done.']:
        errs.append('go.md reader: %s' % got)
    # go.md layout since 16 Nov 26: "### Round" items under "## Open tasks", with a bold "**Steps:**" label.
    got = list(go_steps('## Open tasks\n### Round B\n**Steps:**\n1. Select Run.\n### Note\nSteps:\n1. no\n## Done\n'))
    if [g[1] for g in got] != ['1. Select Run.']:
        errs.append('go.md reader, "###" layout: %s' % got)
    return errs


def self_test_rules():
    """Run check_step_rules on one good and many bad sample manifest steps. Takes nothing; returns a list of error messages."""
    errs = []
    ok_step = {'name': 'R1 x', 'title': 'Remove the old flows', 'note': 'You delete 2 flows. About 4 minutes.',
               'url': 'https://x', 'guide': ['1. Select "Open in browser" above.', '2. Select "Delete".', 'If it fails: select "It failed".']}
    ok_step['help'] = 'Press F5 to run it.'
    if check_step_rules(ok_step):
        errs.append('good rules step failed: %s' % check_step_rules(ok_step))
    look = dict(ok_step, doneText='I looked at the form', answers=[{'key': 'k', 'prompt': 'Is it there?', 'kind': 'yesno'}])
    if check_step_rules(look):
        errs.append('good look step (B6 doneText) failed: %s' % check_step_rules(look))
    pick3 = dict(ok_step, answers=[{'key': 'p', 'prompt': 'Which?', 'kind': 'pick', 'choices': ['A', 'B', 'C']}])
    if check_step_rules(pick3):
        errs.append('good pick step (3 choices) failed: %s' % check_step_rules(pick3))
    for s, want in BAD_RULES:
        if not any(want in f for f in check_step_rules(s)):
            errs.append('bad rules step not found (%s): %s -> %s' % (want, s, check_step_rules(s)))
    return errs


def self_test():
    """Run all the self-tests and print the result. Takes nothing; returns 1 when any test fails, else 0."""
    errs = self_test_steps() + self_test_go() + self_test_rules()
    for e in errs:
        print('SELF-TEST FAIL ' + e)
    print('GUIDE TEXT self-test good=%d bad=%d errors=%d' % (len(GOOD_STEPS), len(BAD_STEPS), len(errs)))
    return 1 if errs else 0


def main():
    """Command line: check every step (--test self-test, --list Markdown list of failures). Prints the last line; returns 1 when a step fails, else 0."""
    if '--test' in sys.argv:
        return self_test()
    steps = list(bundle_steps()) + list(go_steps())
    failed = [(where, text, check_step(text)) for where, text in steps if check_step(text)]
    for where, s in manifest_steps():
        steps.append((where, ''))
        if check_step_rules(s):
            failed.append((where, '(step rules)', check_step_rules(s)))
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
