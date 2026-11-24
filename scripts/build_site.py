#!/usr/bin/env python3
"""Build the shared parts of the site page (index.html) from README.md, so the README is the one source of truth.

Why: a README and a site page that say the same facts in two hand-written copies drift (33-332.Z, 2026-11-20: "one
needs to be source of truth"; made a kit file 2026-11-21). Run target: any machine with Python 3 (a build tool).
What it does: README.md holds marked sections, "<!-- site:NAME -->" to "<!-- /site:NAME -->". The page declares what it
shows: each generated block "<!-- >>> site:NAME: generated from README.md by scripts/build_site.py --write (do not
edit) -->" ... "<!-- <<< site:NAME -->" in index.html is rebuilt from the README section of the same name, indented as
its start mark. Each README section needs exactly one block on the page, and each block a README section.
  intro      one paragraph                                       -> <p>
  key-facts  an HTML table of rows <tr><td><b>Label:</b></td><td>text</td></tr> (no header row; a row may end with
             "<!-- source: ... -->", which names what makes the fact true), then optional lines -> <dl class="facts">
A project adds its own kinds in scripts/build_site_local.py (not a kit file; a sync never touches it):
  BUILDERS = {"NAME": function(markdown, indent) -> html}   more section kinds; the helpers here are importable
  REQUIRE_FACT_SOURCE = True                                each key-facts row must end with its source comment
  def extra_checks(root, readme): return [finding, ...]     more checks, for example a tool text that must match
Inputs:  README.md, index.html, scripts/build_site_local.py (when present).
Outputs: with --write, index.html; then, or with --check alone, "SITE PASS" (or "SITE SKIP" when nothing is shared),
         or one line per finding and "SITE FAIL".
Usage:   python3 scripts/build_site.py --write    rebuild the site's shared parts, then check
         python3 scripts/build_site.py --check    check only (scripts/check.sh runs it when README.md has site marks)
         python3 scripts/build_site.py --test     self-test; prints SITE TEST PASS
Prevents: the site page and the README state the same fact in two hand-written copies that drift apart, so the page shows a stale or wrong fact
Network: none.
Writes: index.html with --write only (the self-test: temporary files).
Credentials: none.
"""

import argparse
import importlib.util
import re
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_site_html import (BOLD, README, build_intro, build_key_facts, fact_rows, inline,  # noqa: E402,F401
                             paragraphs, refuse_marks)

ROOT = Path(__file__).resolve().parent.parent
SITE = 'index.html'
LOCAL = 'scripts/build_site_local.py'
COMMAND = 'scripts/build_site.py --write'
# A README section and a generated block on the page; NAME is lower-case letters, digits and "-". Each end mark starts
# its own line (after the indent), so no old text can stay in front of it; the body may be empty.
SECTION = re.compile(r'<!-- site:([a-z0-9-]+) -->\n(?:(.*?)\n)?<!-- /site:\1 -->', re.S)
BLOCK = re.compile(r'^([ \t]*)<!-- >>> site:([a-z0-9-]+): generated from README\.md by scripts/build_site\.py --write '
                   r'\(do not edit\) -->\n(?:(.*?)\n)?[ \t]*<!-- <<< site:\2 -->', re.S | re.M)
# Any site mark, also a broken one (a typo in a name or an end mark): each must be used by SECTION or BLOCK (stray_marks).
README_MARK = re.compile(r'<!-- /?site:[^>]*-->')
SITE_MARK = re.compile(r'<!-- (?:>>>|<<<) site:[^>]*-->')
# A quote mark at a line's start, and a GitHub alert line; both are taken off before a section is built (unquote).
QUOTE_MARK = r'^>[ \t]?'
ALERT_LINE = r'\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]'


def readme_sections(readme):
    """Return the README's site sections by name, each without its marks and quote marks, stripped.

    Args:
        readme: the whole README.md.
    Returns:
        A dict of section name to its Markdown.
    Raises:
        ValueError: when a name is used for two sections.
    """
    found = {}
    for name, body in SECTION.findall(readme):
        if name in found:
            raise ValueError(f'{README}: two sections <!-- site:{name} -->')
        found[name] = unquote(body or '').strip()
    return found


def unquote(markdown):
    """Return Markdown with quote marks ("> ") taken off and GitHub alert lines ("[!CAUTION]") dropped.

    A README can show a line as a quote or a GitHub alert box; the site shows the same words in its own style, so the
    builder reads them as the plain text inside.

    Args:
        markdown: the text of one README section.
    Returns:
        The same text without quote marks and alert lines.
    """
    lines = [re.sub(QUOTE_MARK, '', line) for line in markdown.splitlines()]
    return '\n'.join(line for line in lines if not re.fullmatch(ALERT_LINE, line.strip()))


def load_local(root):
    """Return the project's own module scripts/build_site_local.py, or None when it is not there.

    Args:
        root: the repository folder.
    Returns:
        The loaded module, or None.
    Raises:
        ValueError: when the file is there but cannot be loaded (a broken extension must fail, not be skipped).
    """
    path = root / LOCAL
    if not path.is_file():
        return None
    try:
        spec = importlib.util.spec_from_file_location('build_site_local', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception as err:  # any error in a project's own code is a finding with its cause
        raise ValueError(f'{LOCAL}: cannot be loaded: {type(err).__name__}: {err}') from err
    return module


def builders(local):
    """Return the section builders by name: the kit's two kinds, then the project's own (which may replace them).

    Args:
        local: the project's module (load_local), or None.
    Returns:
        A dict of section name to function(markdown, indent) -> html.
    """
    need_source = bool(getattr(local, 'REQUIRE_FACT_SOURCE', False))
    found = {'intro': build_intro,
             'key-facts': lambda markdown, indent: build_key_facts(markdown, indent, need_source)}
    extra = getattr(local, 'BUILDERS', {})  # only a missing BUILDERS means none; 0, "", [] or None is a mistake
    if not isinstance(extra, dict) or not all(isinstance(k, str) and callable(v) for k, v in extra.items()):
        raise ValueError(f'{LOCAL}: BUILDERS must be a dict of section name to function(markdown, indent)')
    found.update({name: project_builder(name, build) for name, build in extra.items()})
    return found


def project_builder(name, build):
    """Return a project builder wrapped so that its own ValueError names its section (kit builders name it already).

    Args:
        name: the section name.
        build: the project's function(markdown, indent).
    Returns:
        A function with the same arguments.
    """
    def run_it(markdown, indent):
        """Run the project builder; give its ValueError the prefix "site:NAME: "."""
        try:
            return build(markdown, indent)
        except ValueError as err:
            raise ValueError(f'site:{name}: {err}') from err
    return run_it


def stray_marks(readme, site):
    """Return findings for site marks that are not the two ends of a section or block (a typo, capitals, a missing end
    mark, or a mark inside another block, which a rebuild would drop).

    Args:
        readme: the text of README.md.
        site: the text of index.html.
    Returns:
        A list of finding lines, empty when every mark belongs to a section or a block.
    """
    found = []
    for text, file, mark, pair in ((readme, README, README_MARK, SECTION), (site, SITE, SITE_MARK, BLOCK)):
        used = set()
        for pm in pair.finditer(text):  # only the first and the last mark of a match are its two ends
            ends = list(mark.finditer(pm.group(0)))
            used |= {pm.start() + ends[0].start(), pm.start() + ends[-1].start()}
        found += [f'{file}: a site mark with no pair or a name not in a-z, 0-9 and "-": {m.group(0)}'
                  for m in mark.finditer(text) if m.start() not in used]
    return found


def build_one(kinds, name, markdown, indent):
    """Return one block's HTML from its builder; a project builder's own error becomes a finding.

    Args:
        kinds: the section builders (builders).
        name: the section name.
        markdown: the README section.
        indent: the indent of the block's start mark.
    Returns:
        The HTML text.
    Raises:
        ValueError: on any error of the builder, with its name and cause.
    """
    try:
        body = kinds[name](markdown, indent)
    except ValueError:  # a kit builder names its section; a project builder's error got its name in project_builder
        raise
    except Exception as err:  # a project builder with a wrong signature or a bug: a finding, not a traceback
        raise ValueError(f'site:{name}: the builder failed: {type(err).__name__}: {err}') from err
    if not isinstance(body, str):
        raise ValueError(f'site:{name}: the builder must return text, not {type(body).__name__}')
    return body


def local_findings(local, root, readme):
    """Return the findings of the project's extra_checks; a wrong result or an error is a finding too.

    Args:
        local: the project's module (load_local), or None.
        root: the repository folder.
        readme: the text of README.md.
    Returns:
        A list of finding lines.
    """
    check = getattr(local, 'extra_checks', None)
    if check is None:
        return []
    try:
        result = check(root, readme)
    except Exception as err:  # a project's own code: a finding with its cause
        return [f'{LOCAL}: extra_checks failed: {type(err).__name__}: {err}']
    if result is None:
        return []
    if not isinstance(result, (list, tuple)) or not all(isinstance(line, str) for line in result):
        return [f'{LOCAL}: extra_checks must return a list of text lines, not {type(result).__name__}']
    return list(result)


def render(readme, site, kinds):
    """Return the site page with every shared block rebuilt from the README.

    Args:
        readme: the text of README.md.
        site: the text of index.html.
        kinds: the section builders (builders).
    Returns:
        The new text of index.html.
    Raises:
        ValueError: when a section and a block do not pair up one to one, or a section has no builder or a wrong form.
    """
    sections = readme_sections(readme)
    names = [match.group(2) for match in BLOCK.finditer(site)]
    for name in sorted(set(sections) | set(names)):
        if names.count(name) != 1:
            raise ValueError(f'{SITE}: needs exactly one generated block for site:{name} (found {names.count(name)})')
        if name not in sections:
            raise ValueError(f'{README}: no section <!-- site:{name} --> ... <!-- /site:{name} --> for the block on {SITE}')
        if name not in kinds:
            raise ValueError(f'{README}: no builder for site:{name}; the kit builds intro and key-facts, a project adds '
                             f'its own in {LOCAL}')

    def rebuild(match):
        """Return one generated block with its body built from its README section."""
        indent, name = match.group(1), match.group(2)
        start, end = match.group(0).split('\n', 1)[0], match.group(0).rsplit('\n', 1)[1]
        return f'{start}\n{build_one(kinds, name, sections[name], indent)}\n{end}'
    return BLOCK.sub(rebuild, site)


def run(root, write):
    """Check (and with write, rebuild) the site under root.

    Args:
        root: the repository folder.
        write: True to rewrite index.html first.
    Returns:
        A pair: the findings (empty when everything passes) and whether anything is shared (False: SITE SKIP).
    """
    try:
        readme = (root / README).read_text(encoding='utf-8')
        site_path = root / SITE
        site = site_path.read_text(encoding='utf-8') if site_path.is_file() else ''
        if not README_MARK.search(readme) and not SITE_MARK.search(site):
            return [], False
        stray = stray_marks(readme, site)
        if stray:
            return stray, True
        local = load_local(root)
        fresh = render(readme, site, builders(local))
        findings = local_findings(local, root, readme)
    except (OSError, ValueError) as err:
        return [str(err)], True
    if write and fresh != site:
        site_path.write_text(fresh, encoding='utf-8')
        site = fresh
    if fresh != site:
        findings.append(f'{SITE}: out of date with {README}; run: python3 {COMMAND}')
    return findings, True


def mark(name, body='old', indent='    '):
    """Return one generated block for the self-test, with the given body and indent."""
    return (f'{indent}<!-- >>> site:{name}: generated from {README} by {COMMAND} (do not edit) -->\n{body}\n'
            f'{indent}<!-- <<< site:{name} -->\n')


# The self-test's invented README and page, and its cases: (label, README edit as (old, new) or None, the page,
# the local module's text or None, the words each finding must hold (none: the case must pass), and whether the case
# rebuilds the site first).
TEST_README = ('<!-- site:intro -->\nA safe_tool & more.\n<!-- /site:intro -->\n'
               '<!-- site:key-facts -->\n<table>\n<tr><td><b>Read-only:</b></td><td>it changes nothing.</td></tr> '
               '<!-- source: docs/engine.md -->\n</table>\n\nFirst line.\nAsk & learn.\n<!-- /site:key-facts -->\n')
TEST_PAGE = '<main>\n' + mark('intro') + mark('key-facts') + '</main>\n'
UNSUPPORTED = 'unsupported Markdown'
BLOCKED_LINE = 'is not supported in a site section'
TEST_LOCAL = ('from pathlib import Path\nBUILDERS = {"note": lambda md, indent: indent + "<aside>" + md + "</aside>"}\n'
              'def extra_checks(root, readme):\n    return [] if "Ask" in readme else ["local: Ask is missing"]\n')
EMPTY_PAGE = '<main></main>\n'
NOTE = '<!-- site:note -->\nplain\n<!-- /site:note -->\n'
TEST_CASES = (
    ('a fresh build passes', None, TEST_PAGE, None, [], True),
    ('a stale site fails', None, TEST_PAGE, None, ['out of date'], False),
    ('a README section with no block fails', None, mark('key-facts'), None,
     ['exactly one generated block for site:intro'], True),
    ('a block with no README section fails', None, TEST_PAGE + mark('extra'), None, ['no section <!-- site:extra'], True),
    ('two blocks of one name fail', None, TEST_PAGE + mark('intro'), None, ['found 2'], True),
    ('two README sections of one name fail', ('<!-- site:key-facts -->', '<!-- site:intro -->\nB.\n<!-- /site:intro -->\n'
     '<!-- site:key-facts -->'), TEST_PAGE, None, ['two sections'], True),
    ('a section kind with no builder fails', ('<!-- site:intro -->', NOTE + '<!-- site:intro -->'), TEST_PAGE + mark('note'),
     None, ['no builder for site:note'], True),
    ('a local builder and its extra check work', ('<!-- site:intro -->', NOTE + '<!-- site:intro -->'),
     TEST_PAGE + mark('note'), TEST_LOCAL, [], True),
    ('a local extra check can fail', ('Ask & learn.', 'Learn.'), TEST_PAGE, TEST_LOCAL, ['local: Ask is missing'], True),
    ('a local module that cannot load fails', None, TEST_PAGE, 'raise RuntimeError("broken")\n', ['cannot be loaded'], True),
    ('a required source missing fails', (' <!-- source: docs/engine.md -->', ''), TEST_PAGE, 'REQUIRE_FACT_SOURCE = True\n',
     ['need " <!-- source'], True),
    ('a required source present passes', None, TEST_PAGE, 'REQUIRE_FACT_SOURCE = True\n', [], True),
    ('a key fact without a bold label fails', ('<b>Read-only:</b>', 'Read-only:'), TEST_PAGE, None, ['<b>Label:</b>'], True),
    ('a key fact with Markdown fails', ('changes nothing.', 'changes **nothing**.'), TEST_PAGE, None, ['<b>Label:</b>'], True),
    ('a key fact with "&" fails', ('changes nothing.', 'changes &copy nothing.'), TEST_PAGE, None, ['<b>Label:</b>'], True),
    ('text right after the key-facts table fails', ('</table>\n\nFirst line.', '</table>\nFirst line.'), TEST_PAGE, None,
     ['needs a blank line'], True),
    ('a key fact with a web address fails', ('changes nothing.', 'changes www.x.example'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('an intro of two paragraphs fails', ('A safe_tool & more.', 'One.\n\nTwo.'), TEST_PAGE, None, ['one paragraph'], True),
    ('unsupported Markdown fails', ('A safe_tool & more.', 'A *safe* tool.'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('a link fails', ('A safe_tool & more.', 'A [tool](x).'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('a list in a section fails', ('First line.', '- First line.'), TEST_PAGE, None, [BLOCKED_LINE], True),
    ('an empty list item fails', ('First line.', '1.\nFirst line.'), TEST_PAGE, None, [BLOCKED_LINE], True),
    ('an indented code block fails', ('Ask & learn.', 'Ask & learn.\n\n    code here'), TEST_PAGE, None, [BLOCKED_LINE], True),
    ('a heading underline fails', ('Ask & learn.', 'Ask & learn.\n==='), TEST_PAGE, None, [BLOCKED_LINE], True),
    ('bold with inner spaces fails', ('A safe_tool & more.', 'A ** safe ** tool.'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('bold GitHub would not close fails', ('A safe_tool & more.', 'A **tool:**now.'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('an e-mail address fails', ('Ask & learn.', 'Ask a@b.example.'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('an entity with digits fails', ('Ask & learn.', 'Ask &frac12;.'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('an emoji code fails', ('Ask & learn.', 'Ask :warning:'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('a web address of another scheme fails', ('Ask & learn.', 'See ftp://x.example'), TEST_PAGE, None, [UNSUPPORTED], True),
    ('plain times, ratios and bold in brackets or quotes pass',
     ('A safe_tool & more.', 'A safe_tool (**Microsoft Purview**), "**Stop**", **PII**-free, 09:00-17:00, 10:30:45, 1:2:3,\n'
      '2026. That year.'), TEST_PAGE, None, [], True),
    ('a quote and a GitHub alert box are read as their plain text',
     ('First line.\nAsk & learn.', '> [!NOTE]\n> First line.\n> Ask & learn.'), TEST_PAGE, None, [], True),
    ('nothing shared: a skip, not a failure', ('site:', 'x-site:'), EMPTY_PAGE, None, [], True),
    ('a README end mark with a typo fails', ('<!-- /site:intro -->', '<!-- /site:intr -->'), mark('key-facts'), None,
     ['a site mark with no pair'], True),
    ('a name in capitals fails', ('site:intro -->\nA', 'site:Intro -->\nA'), mark('key-facts'), None, ['a site mark with no pair'], True),
    ('a page start mark with no end mark fails', None, TEST_PAGE + mark('gone').split('\n')[0] + '\n', None,
     ['a site mark with no pair'], True),
    ('an empty block body is rebuilt', None, '<main>\n' + mark('intro', '').replace('-->\n\n', '-->\n') + mark('key-facts')
     + '</main>\n', None, [], True),
    ('a local builder with a wrong signature is a finding', ('<!-- site:intro -->', NOTE + '<!-- site:intro -->'),
     TEST_PAGE + mark('note'), 'BUILDERS = {"note": lambda md: md}\n', ['the builder failed: TypeError'], True),
    ('extra_checks that return text, not a list, is one finding', None, TEST_PAGE,
     'def extra_checks(root, readme):\n    return "bad"\n', ['must return a list of text lines'], True),
    ('old text in front of an end mark fails', None, TEST_PAGE.replace('old\n    <!-- <<< site:intro', 'old <!-- <<< site:intro'), None,
     ['a site mark with no pair'], True),
    ('a start mark inside another block fails', None, TEST_PAGE.replace('old\n    <!-- <<< site:intro', mark('intro').split('\n')[0]
     + '\n    <!-- <<< site:intro'), None, ['a site mark with no pair'], True),
    ('a local builder that returns no text is a finding', ('<!-- site:intro -->', NOTE + '<!-- site:intro -->'),
     TEST_PAGE + mark('note'), 'BUILDERS = {"note": lambda md, indent: None}\n', ['must return text'], True),
    ('BUILDERS that is not a dict is a finding', None, TEST_PAGE, 'BUILDERS = 5\n', ['BUILDERS must be a dict'], True),
    ('BUILDERS that is empty but not a dict is a finding', None, TEST_PAGE, 'BUILDERS = []\n', ['BUILDERS must be a dict'], True),
    ('text in front of a README end mark fails', ('more.\n<!-- /site:intro -->', 'more. <!-- /site:intro -->'), TEST_PAGE, None,
     ['a site mark with no pair'], True),
    ('an empty README section is read as empty', ('A safe_tool & more.\n', ''), TEST_PAGE, None, ['^README.md: site:intro must be one paragraph'], True),
    ('a project builder error that names another section still gets its own name', ('<!-- site:intro -->', NOTE + '<!-- site:intro -->'),
     TEST_PAGE + mark('note'), 'def bad(md, indent):\n    raise ValueError("see site:notes")\nBUILDERS = {"note": bad}\n',
     ['^site:note: see site:notes'], True))
# What the fresh build must write: the intro, a key fact without its source, two lines joined, an escaped "&", the
# block's indent kept.
TEST_BUILT = ('    <p>A safe_tool &amp; more.</p>', '      <dt>Read-only:</dt><dd>it changes nothing.</dd>',
              '    <p class="small mut">First line. Ask &amp; learn.</p>')


def test_case(edit, page, local, expect, write):
    """Run one self-test case in a temporary repository.

    Args:
        edit: an (old, new) change to the invented README (all places), or None for the README as it is.
        page: the text of the invented index.html.
        local: the text of an invented scripts/build_site_local.py, or None for none.
        expect: the words some finding must hold (a word that starts with "^": a finding must start with the rest); empty
            when the case must pass.
        write: True to rebuild the site before the check.
    Returns:
        A pair: True when the case behaved as expected, and the list of findings.
    """
    readme = TEST_README.replace(*edit) if edit else TEST_README
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / 'scripts').mkdir()
        (root / README).write_text(readme, encoding='utf-8')
        (root / SITE).write_text(page, encoding='utf-8')
        if local is not None:
            (root / LOCAL).write_text(local, encoding='utf-8')
        found, shared = run(root, write)
        if page is EMPTY_PAGE:  # the "nothing shared" case: it must skip, not pass a check
            return not found and not shared, found
        if expect:
            hit = lambda word, line: line.startswith(word[1:]) if word.startswith('^') else word in line  # "^": the finding starts so
            return bool(found) and all(any(hit(word, line) for line in found) for word in expect), found
        built = (root / SITE).read_text(encoding='utf-8')
        whole = page is TEST_PAGE and local is None and edit is None
        aside = local != TEST_LOCAL or '    <aside>plain</aside>' in built  # the local builder's block was written
        return not found and aside and (not whole or all(part in built for part in TEST_BUILT)) and 'source:' not in built, found


# Hostile key-facts text (an end tag missing or misplaced, rows that nest or repeat): each must be refused or read in
# under HOSTILE_SECONDS, because a regex with a repeated ".*" group (ReDoS) once took minutes on the first one.
HOSTILE_SECONDS = 1
HOSTILE_TABLES = (
    ('no end tag, many rows', '<table>\n' + '<tr></tr>' * 5000 + ' x' * 5000),
    ('no end tag, many lines', '<table>\n' + '<tr></tr> x\n' * 5000),
    ('end tag not at a line start', '<table>\n' + '<tr></tr>\n' * 5000 + ' </table>'),
    ('many row starts, no row end', '<table>\n' + '<tr>' * 20000 + '\n</table>'),
    ('many tables', '<table>\n<tr></tr>\n' * 5000),
)


def hostile_test():
    """Time fact_rows on each hostile table and print one line each.

    Returns:
        The number of tables that took HOSTILE_SECONDS or more.
    """
    slow = 0
    for label, text in HOSTILE_TABLES:
        start = time.monotonic()
        try:
            fact_rows(text, False)
        except ValueError:
            pass  # refused: the expected result for every hostile table
        seconds = time.monotonic() - start
        slow += seconds >= HOSTILE_SECONDS
        print(('ok   ' if seconds < HOSTILE_SECONDS else 'FAIL ') + f'a hostile key-facts table is read in under {HOSTILE_SECONDS} s: {label} ({seconds:.2f} s)')
    return slow


def self_test():
    """Run every self-test case on invented files and print one line each.

    Returns:
        0 when every case passes, else 1.
    """
    failed = 0
    for label, edit, page, local, expect, write in TEST_CASES:
        ok, found = test_case(edit, page, local, expect, write)
        failed += not ok
        print(('ok   ' if ok else 'FAIL ') + label + ('' if ok else f': {found}'))
    failed += hostile_test()
    print('SITE TEST PASS' if not failed else 'SITE TEST FAIL')
    return 1 if failed else 0


def main():
    """Parse the arguments and run the rebuild, the check or the self-test.

    Returns:
        The exit code: 0 on pass, else 1.
    """
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write', action='store_true', help='rebuild the shared parts of index.html, then check')
    mode.add_argument('--check', action='store_true', help='check only')
    mode.add_argument('--test', action='store_true', help='self-test')
    args = parser.parse_args()
    if args.test:
        return self_test()
    found, shared = run(ROOT, args.write)
    for line in found:
        print(line)
    print('SITE FAIL' if found else ('SITE PASS' if shared else 'SITE SKIP (README.md has no site sections)'))
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
