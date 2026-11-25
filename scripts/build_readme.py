#!/usr/bin/env python3
"""Write the script link and the current tasks into README.md, from go.md and the round bundle (the PFM, 2026-11-25).

README.md is the one page the PFM opens on the work computer (github.io and .ps1 links break it; the PFM, 2026-11-21 and
2026-11-25). Between two marker lines it holds, as the 33-332.Z (Ion) README does:
  - one "Open the script" link to the .txt copy of the round bundle in scripts/gov/paste/ (RADE engine-v34 or later),
    the sentence "The steps to run it are at the top of the script.", the round script name and its code (the "short"
    value of its .sha256.json, the code the RADE title bar shows). The build fails unless exactly one .txt bundle is there;
  - the current tasks: go.md from its "Updated" line to its "## Done" heading, headings two levels lower, bare
    raw.githubusercontent.com URLs as links, and a backslash at the end of a text line before another text line, so
    GitHub keeps go.md's line breaks.
go.md stays the one home of the tasks: edit go.md, then run this script. scripts/build_paste_bundles.py runs it at the
end of each round build.
The build fails when the README has a link to a .ps1 file or to github.io (the PFM, 2026-11-25), or when go.md has a
round script line (a .ps1 URL): the script link comes only from the bundle's .txt copy.
Usage: python3 scripts/build_readme.py [--check]
  --check: write nothing; exit 1 when README.md is not the text this script would write.
Network: none.
Writes: README.md (the part between the task markers); nothing with --check.
Credentials: none.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GO = ROOT / 'go.md'
README = ROOT / 'README.md'
PASTE = 'scripts/gov/paste'
BEGIN = '<!-- >>> tasks: generated from go.md and the round bundle by scripts/build_readme.py (do not edit) -->'
END = '<!-- <<< tasks -->'
sys.path.insert(0, str(ROOT / 'scripts'))
import site_config   # noqa: E402  scripts/site_config.py: the account values live in site.config.json (fleet v2 DEC 7)
U = site_config.urls()
RAW = U['raw']
BARE = re.compile(r'^(?:https://)?(raw\.githubusercontent\.com/\S*)$')
# A link target that breaks the work computer: a .ps1 file, or any github.io page (the PFM, 2026-11-25).
BAD_LINK = re.compile(r'(?:\]\(|<|href=")[^)>"\s]*(?:\.ps1(?:[)>"?#]|$)|github\.io)', re.I)


def script_lines():
    """The README lines for the round script: the "Open the script" link to its .txt copy, Ion's sentence, its name and code.

    Returns:
        A list of README lines.
    Raises:
        SystemExit: when scripts/gov/paste/ does not hold exactly one .txt bundle with its .ps1 and .sha256.json.
    """
    txts = sorted((ROOT / PASTE).glob('*.txt'))
    if len(txts) != 1:
        sys.exit('FAIL %s holds %d .txt bundles; the README links exactly one' % (PASTE, len(txts)))
    txt = txts[0]
    meta = txt.with_suffix('.ps1.sha256.json')
    if not meta.is_file():
        sys.exit('FAIL %s has no %s: the code of the round is unknown' % (txt.name, meta.name))
    code = json.loads(meta.read_text(encoding='utf-8')).get('short', '')
    return ['[**Open the script**](%s%s/%s)' % (RAW, PASTE, txt.name),
            '',
            'The steps to run it are at the top of the script.',
            '',
            '**Round script:** `%s` · **Code:** `%s`' % (txt.name, code)]


def tasks(text):
    """The README copy of go.md's current part: from the "Updated" line to the "## Done" heading.

    Args:
        text: the whole text of go.md.
    Returns:
        The README task lines, without a final empty line.
    Raises:
        SystemExit: when go.md has no "Updated" line or a round script (.ps1) line.
    """
    lines = text.split('\n')
    start = next((i for i, s in enumerate(lines) if s.startswith('Updated:')), None)
    if start is None:
        sys.exit('FAIL go.md has no "Updated:" line')
    out = []
    for line in lines[start:]:
        if line.startswith('## Done'):
            break
        s = line.strip()
        if s.endswith('.ps1'):
            sys.exit('FAIL go.md links a .ps1 file (%s): the README links only the .txt copy of the bundle' % s)
        m = BARE.match(s)
        if m:
            out.append('<https://%s>' % m.group(1))
            continue
        # GitHub reads a backslash before punctuation as an escape (Rounds\\<round> showed as Rounds<round>): double it.
        line = re.sub(r'\\(?=[!-/:-@\[-`{-~])', r'\\\\', line)
        out.append('##' + line if line.startswith('#') else line)
    return hard_breaks(out[:-1] if out and not out[-1].strip() else out)


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
        if re.match(r'^\s*(?:[-*] |\d+\. )', line) and nxt.strip() and not own.match(nxt) and not nxt.startswith(('<http', ' ')):
            out.append('')
    return out


def build():
    """README.md with its task part made again. Exits when a marker line is missing or a bad link is in the README."""
    readme = README.read_text(encoding='utf-8')
    if BEGIN not in readme or END not in readme:
        sys.exit('FAIL README.md has no task markers (%s ... %s)' % (BEGIN, END))
    head, rest = readme.split(BEGIN, 1)
    tail = rest.split(END, 1)[1]
    part = script_lines() + ['', '---', '', '### 🔺 Current tasks', ''] + tasks(GO.read_text(encoding='utf-8'))
    new = head + BEGIN + '\n' + '\n'.join(part) + '\n' + END + tail
    bad = sorted({m.group(0) for m in BAD_LINK.finditer(new)})
    if bad:
        sys.exit('FAIL README.md links a .ps1 file or github.io: %s' % ', '.join(bad))
    return new


if __name__ == '__main__':
    text = build()
    if '--check' in sys.argv[1:]:
        if text != README.read_text(encoding='utf-8'):
            sys.exit('FAIL README.md is not current: run python3 scripts/build_readme.py')
        print('README OK')
    else:
        README.write_text(text, encoding='utf-8')
        print('README written from go.md and the round bundle')
