#!/usr/bin/env python3
"""Write the task part of README.md from go.md, for a computer where rhope-ops.github.io is blocked (the PFM, 21 Nov 26).

The github.io page (index.html) shows go.md with buttons. github.com shows README.md on the repo's front page, but a README
cannot run a script, so this file gives each button as a link:
  - a round script line (a raw .../scripts/gov/paste/<name>.ps1 URL) becomes the round's code (the "short" value of its
    .sha256.json, the code the RADE title bar shows), an "Open as .txt" link (the raw file: the browser shows it as plain
    text) and a "Copy script" link (the file on github.com, where the "Copy raw file" button copies it);
  - any other bare raw URL becomes a link;
  - a text line followed by another text line ends in a backslash, so GitHub keeps go.md's line breaks, and a text line
    after a list item gets a blank line before it, so it does not join the item.
go.md stays the one home of the tasks: README.md holds a copy between two marker lines; edit go.md, then run this script.
scripts/build_paste_bundles.py runs it at the end of each round build.
Usage: python3 scripts/build_readme.py [--check]
  --check: write nothing; exit 1 when README.md is not the copy of go.md this script would write.
Network: none.
Writes: README.md (the part between the task markers); nothing with --check.
Credentials: none.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GO = ROOT / 'go.md'
README = ROOT / 'README.md'
BEGIN = '<!-- >>> tasks: generated from go.md by scripts/build_readme.py (do not edit) -->'
END = '<!-- <<< tasks -->'
RAW = 'https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/'
BLOB = 'https://github.com/rhope-ops/90-161.Z/blob/main/'
ROUND = re.compile(r'^(?:https://)?raw\.githubusercontent\.com/rhope-ops/90-161\.Z/main/(scripts/gov/paste/[^/\s]+\.ps1)$')
BARE = re.compile(r'^(?:https://)?((?:raw\.githubusercontent\.com|rhope-ops\.github\.io)/\S*)$')


def round_lines(path):
    """The README lines for one round script: its code, then the two links.

    Args:
        path: the repo path of the .ps1 file (scripts/gov/paste/<name>.ps1).
    Returns:
        A list of README lines.
    """
    name = path.rsplit('/', 1)[-1]
    code = ''
    meta = ROOT / (path + '.sha256.json')
    if meta.is_file():   # the code the RADE title bar shows (step "Write down the code")
        code = json.loads(meta.read_text(encoding='utf-8')).get('short', '')
    out = ['**Round script:** `%s`' % name]
    if code:
        out += ['', '**Code:** `%s`' % code]
    out += ['',
            '- **Open as .txt:** [%s](%s%s): the browser shows the script as plain text. Press Ctrl+A, then Ctrl+C, to copy all of it.'
            % (name, RAW, path),
            '- **Copy script:** [%s on GitHub](%s%s): press the "Copy raw file" button at the top right of the file.'
            % (name, BLOB, path)]
    return out


def tasks(text):
    """The README copy of go.md text: headings one level lower (the README has its own title), links for bare URLs.

    Args:
        text: the whole text of go.md.
    Returns:
        The README task part as one string, without a final line break.
    """
    out = []
    for line in text.splitlines():
        s = line.strip()
        m = ROUND.match(s)
        if m:
            out += round_lines(m.group(1))
            continue
        m = BARE.match(s)
        if m:
            out.append('<https://%s>' % m.group(1))
            continue
        # GitHub reads a backslash before punctuation as an escape (Rounds\\<round> showed as Rounds<round>): double it.
        line = re.sub(r'\\(?=[!-/:-@\[-`{-~])', r'\\\\', line)
        out.append('#' + line if line.startswith('#') else line)
    return '\n'.join(hard_breaks(out)).rstrip('\n')


def hard_breaks(lines):
    """Keeps go.md's line breaks: GitHub joins lines of one paragraph, so a text line followed by another text line gets
    a closing backslash (a CommonMark hard break). List items, headings and table rows keep their own lines already.

    Args:
        lines: the README task lines, in order.
    Returns:
        The same lines with the backslashes and blank lines added.
    """
    own = re.compile(r'^\s*(?:[-*] |\d+\. |#|\||<!--)')
    out = []
    for i, line in enumerate(lines):
        nxt = lines[i + 1] if i + 1 < len(lines) else ''
        if line.strip() and nxt.strip() and not own.match(line) and not own.match(nxt):
            line += '\\'
        out.append(line)
        # A text line right after a list item would join that item (a lazy continuation): a blank line ends the list first.
        # A link line stays in the item (go.md puts each results link on the line after its Done item).
        if re.match(r'^\s*(?:[-*] |\d+\. )', line) and nxt.strip() and not own.match(nxt) and not nxt.startswith(('<http', ' ')):
            out.append('')
    return out


def build():
    """README.md with its task part made again from go.md. Exits when a marker line is missing."""
    readme = README.read_text(encoding='utf-8')
    if BEGIN not in readme or END not in readme:
        sys.exit('FAIL README.md has no task markers (%s ... %s)' % (BEGIN, END))
    head, rest = readme.split(BEGIN, 1)
    tail = rest.split(END, 1)[1]
    return head + BEGIN + '\n' + tasks(GO.read_text(encoding='utf-8')) + '\n' + END + tail


if __name__ == '__main__':
    new = build()
    if '--check' in sys.argv[1:]:
        if new != README.read_text(encoding='utf-8'):
            sys.exit('FAIL README.md is not the copy of go.md: run python3 scripts/build_readme.py')
        print('README OK')
    else:
        README.write_text(new, encoding='utf-8')
        print('README written from go.md')
