#!/usr/bin/env python3
"""Screen names check (Project rule "Screen names", the PFM, 2026-11-25).

Why: the R42 r2 steps named a log with DONE, a bold "Writes to" line and a Repair button that the RADE window did not
show at that time. A step must name only what is on the screen, copied from the bundle code of that round.

Reads:
- the round bundle: the one scripts/gov/paste/90161Z-R<NN>-round-r<N>.ps1 (the engine UI code and the step manifest);
- go.md: the numbered steps above "## Done", their **bold** and "quoted" names;
- scripts/paste_bundles.json: the "guide" lines of the bundle that is in scripts/gov/paste, their "quoted" names.

A name PASSES when its fixed words are in the bundle. Values that the code builds at run time do not count as fixed
words: a round name (R42), a version or a number (0.1.0, 10), and an application name of the bundle (90-161.Z R42).
Example: "Ready to run round R42." passes because "Ready to run round" is in the code ('Ready to run round ' + $round).
A name of another program (Windows, ISE, Outlook, GitHub, Teams, the README) is in OUTSIDE and is not read.
A quoted name that is the name of a go.md "Steps ..." list ("Send a line to Claude") is a page name, not a screen name.

What it does not see: a name that is in the code but shows on another card or at another time. The fresh reader gets
the card order from the bundle for that (the round skill, section 5).

Usage:   python3 tests/check_screen_names.py          check; exit 1 on any name the bundle does not hold
         python3 tests/check_screen_names.py --test   self-test with good and bad sample names
Last line: SCREEN NAMES names=N failed=F
Network: none.
Writes: nothing.
Credentials: none.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PASTE = ROOT / 'scripts/gov/paste'

# Names on screens of other programs (not in the bundle code). Add a name here only when it is on the screen of that
# program; never to get past a RADE name.
OUTSIDE = {
    # GitHub and the README
    'rhope-ops/90-161.Z', 'Round script', 'Open the script', 'Code:',
    # Windows, ISE and File Explorer
    'Start', 'Windows PowerShell ISE', 'Run as administrator', 'File', 'New', 'Ctrl+A', 'Ctrl+C', 'Ctrl+V', 'Ctrl+X',
    # Outlook, Teams, the Claude app on the phone
    'Send', 'To', 'Subject', 'Chat', 'New chat',
}
# A value the code builds at run time: a round name, a version, a number, a file revision.
VALUE = re.compile(r'^(?:R\d+[a-z]?|r\d+|\d+(?:\.\d+)*|T\d+)$')


def bundle_path():
    """Gives back the path of the one round bundle (.ps1) in scripts/gov/paste. Exits when there is not exactly one."""
    found = sorted(p for p in PASTE.glob('90161Z-R*-round-r*.ps1'))
    if len(found) != 1:
        sys.exit('FAIL scripts/gov/paste must hold exactly one round bundle .ps1, found %d' % len(found))
    return found[0]


def screen_text(code):
    """Gives back the text of every string value in the bundle code ('...' with '' for ', and "..."), one per line.
    Comments, variable names and code words are left out, so a name matches only text the window can show."""
    out = [m.replace("''", "'") for m in re.findall(r"'((?:[^'\n]|'')*)'", code)]
    out += re.findall(r'"([^"\n]*)"', code)
    return '\n'.join(out)


def app_names(code):
    """Gives back the application names of the bundle ($apps += @{ Name = '...' }), longest first."""
    names = set(re.findall(r"\$apps \+= @\{ Name = '([^']+)'", code))
    return sorted(names, key=len, reverse=True)


def fixed_parts(name, apps):
    """Splits a name into its fixed word runs: drops the application names and the run-time values.

    Args:
        name: the bold or quoted name of a step.
        apps: the application names of the bundle, longest first.

    Returns:
        The list of fixed word runs; empty when the whole name is run-time values.
    """
    t = name
    for a in apps:
        t = t.replace(a, ' \x00 ')
    runs, cur = [], []
    for w in t.split():
        core = w.strip('.,:;!?()')
        if w == '\x00' or VALUE.match(core):
            if cur:
                runs.append(' '.join(cur))
            cur = []
        else:
            cur.append(w)
    if cur:
        runs.append(' '.join(cur))
    return [r for r in runs if r.strip('.,:;!?() ')]


def holds(code, run):
    """Says whether the bundle code holds a word run, as is or without its end mark. Takes the code and the run."""
    for v in (run, run.rstrip('.,:;!?'), run.strip('.,:;!?() ')):
        # whole words only: "Log" must not match inside "Login"
        if v and re.search(r'(?<![A-Za-z0-9])' + re.escape(v) + r'(?![A-Za-z0-9])', code):
            return True
    return False


def check_name(code, apps, name):
    """Gives back the fixed word runs of a name that the bundle does not hold (empty = pass)."""
    if name in OUTSIDE:
        return []
    return [r for r in fixed_parts(name, apps) if not holds(code, r)]


def go_names(go_text):
    """Finds each **bold** and "quoted" name in the numbered steps of go.md above "## Done".

    The quoted names of go.md's own "Steps ..." lists ("Send a line to Claude") are page names and are left out.

    Args:
        go_text: the text of go.md.

    Returns:
        A list of (line number, name).
    """
    lines = go_text.split('\n')
    end = next((i for i, l in enumerate(lines) if l.startswith('## Done')), len(lines))
    pages = ' '.join(l.lower() for l in lines[:end] if l.startswith('Steps '))
    out = []
    for i, l in enumerate(lines[:end]):
        if not re.match(r'\s*\d+\.\s', l):
            continue
        for b in re.findall(r'\*\*(.+?)\*\*', l):
            out.append((i + 1, b))
        for q in re.findall(r'"([^"]+)"', re.sub(r'\*\*.+?\*\*', '', l)):
            if q.lower() not in pages:
                out.append((i + 1, q))
    return out


def guide_names(bundles, bundle_file):
    """Finds each "quoted" name in the guide lines of the bundle that writes the bundle file.

    Args:
        bundles: the data of scripts/paste_bundles.json.
        bundle_file: the file name of the round bundle (.ps1).

    Returns:
        A list of (step title, name).
    """
    out = []
    for b in bundles.get('bundles', []):
        if Path(str(b.get('out', ''))).name != bundle_file:
            continue
        for s in b.get('steps', []):
            for g in s.get('guide', []) or []:
                for q in re.findall(r'"([^"]+)"', g):
                    out.append((s.get('title', '?'), q))
    return out


def self_test():
    """Checks the rules on sample names. Exits 1 on a wrong result."""
    code = "Sentence = ('Ready to run round ' + $round + '.'); Text = 'Maintenance'; 'One check needs you.'\n" \
           "$apps += @{ Name = '90-161.Z R42'; }\n$apps += @{ Name = '90-161.Z'; Version = '0.1.0' }\n" \
           "Text = 'Don''t stop'; BarNo.Text = 'Screen ' + ($j + 1) + ' of ' + $n"
    apps = app_names(code)
    code = screen_text(code)
    good = ['Ready to run round R42.', 'Maintenance', 'One check needs you.', '90-161.Z 0.1.0', '90-161.Z R42',
            "Don't stop", 'Screen 10 of 17', 'Send', '0.1.0']
    bad = ['Writes to NOT found', 'Log', 'Repair', 'Back up log']
    errs = [n for n in good if check_name(code, apps, n)] + [n for n in bad if not check_name(code, apps, n)]
    gt = '1. Click **Run**. Do "Send a line to Claude".\nSteps to send a line to Claude:\n## Done\n1. **Old**'
    got = [n for _, n in go_names(gt)]
    if got != ['Run']:
        errs.append('go_names: %r' % got)
    if errs:
        sys.exit('SELF-TEST FAIL: %s' % errs)
    print('SCREEN NAMES SELF-TEST PASS')


def card_map(raw):
    """Makes the RADE card map for the fresh reader (the round skill, section 5).

    One line for each card the window code makes (SetCard), in code order: its view and its fixed sentence text, with
    run-time parts as <...>. The last line lists every button text.

    Args:
        raw: the code of the round bundle.

    Returns:
        The list of map lines.
    """
    out = []
    for m in re.finditer(r"SetCard @\{ View = '([^']+)'", raw):
        view = m.group(1)
        rest = ' '.join(raw[m.end():m.end() + 1500].split('\n')[:4])   # the sentence can be on the next lines
        sent = re.search(r"Sentence = (.+?)(?:;\s*(?:P|Kicker|Buttons|Range|Field|Back|Options|StepRow|Light|Right|Tick)\s*=|$)", rest)
        s = ''
        if sent:
            parts = re.findall(r"'((?:[^']|'')*)'|(\$[\w.]+)", sent.group(1))
            s = ''.join(a.replace("''", "'") if a else '<' + b + '>' for a, b in parts)
        out.append('%s | %s' % (view, s.strip()))
    buttons = sorted(set(re.findall(r"Text = '([^']+)'; (?:Kind|Act|Always)", raw)))
    out.append('BUTTONS | ' + ' / '.join(buttons))
    return out


def main():
    """Checks every step name of go.md and of the round's guide lines against the round bundle (--test: self-test;
    --map: print the card map).

    Returns:
        None. Exits 1 when a name fails.
    """
    if '--test' in sys.argv:
        return self_test()
    bp = bundle_path()
    if '--map' in sys.argv:
        print('\n'.join(card_map(bp.read_text(encoding='utf-8'))))
        return
    raw = bp.read_text(encoding='utf-8')
    apps = app_names(raw)
    code = screen_text(raw)
    names = [('go.md:%d' % n, x) for n, x in go_names((ROOT / 'go.md').read_text(encoding='utf-8'))]
    data = json.loads((ROOT / 'scripts/paste_bundles.json').read_text(encoding='utf-8'))
    names += [('guide "%s"' % t, x) for t, x in guide_names(data, bp.name)]
    failed = 0
    for where, x in names:
        miss = check_name(code, apps, x)
        if miss:
            failed += 1
            print('FAIL %s: "%s" is not on a RADE screen (not in %s): %s' % (where, x, bp.name, '; '.join(miss)))
    print('SCREEN NAMES names=%d failed=%d' % (len(names), failed))
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
