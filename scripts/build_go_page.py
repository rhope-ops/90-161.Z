#!/usr/bin/env python3
"""Build the task cards of the bookmark page (index.html) from go.md at build time, with markdown-it-py.

Why: the page drew go.md in the browser with its own regex Markdown parser and fetched go.md at run time (master plan
P4b, 2026-11-23: build-time HTML with a standard Markdown library; rhope-ops/archimedes_lever
docs/reviews/2026-11-23-tool-retirement-plan.md). Now the cards are in the page itself: the page fetches only the round
scripts for the Copy script button, and go.md text never becomes HTML in the browser.
What it does: go.md is "# Title", intro lines, then "## " sections. A section with "### " sub-headings is a group: its
lines before the first "###" are the group's intro, and each "###" is one card. A section with no "###" is one card. A
card's state comes from "(open, <when>)" or "(done, <when>)" at the end of its heading, else from its group ("Open
tasks" = open, "Done" = done). The card layer (lists, file cards, folder lines, notes, sub-headings) is the same line
rules go.js had; markdown-it-py (CommonMark, raw HTML off) renders the text of each line: escaping, **bold**, `code`
and links. Links: http(s) URLs and bare raw.githubusercontent.com / <owner>.github.io URLs, as before.
It writes three parts of index.html: the block between the go:page marker lines in <main id="m">, the open count in
the header (#hc), and the CSP connect-src source (the raw folder from site.config.json, the one home of the account
values: fleet v2 DEC 7).
Usage:   python3 scripts/build_go_page.py           rebuild index.html from go.md
         python3 scripts/build_go_page.py --check   write nothing; exit 1 when index.html is not what go.md gives
         python3 scripts/build_go_page.py --test    self-test with invented go.md text; prints GO BUILD TEST PASS
Needs:   markdown-it-py 4.3.0 (requirements.txt). Without it the build stops with FAIL and the install command.
Prevents: go.md text that becomes script or a hostile link on the page, a stale page after a go.md change, and a CSP
          source that differs from site.config.json
Network: none.
Writes:  index.html (no flag only); nothing with --check or --test.
Credentials: none.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GO = ROOT / 'go.md'
PAGE = ROOT / 'index.html'
sys.path.insert(0, str(ROOT / 'scripts'))
import site_config  # noqa: E402  scripts/site_config.py reads site.config.json (fleet v2 DEC 7)

try:
    from markdown_it import MarkdownIt
except ImportError:  # a clear stop, never a skip: a stale page must not pass
    sys.exit('FAIL markdown-it-py is not installed: run python3 -m pip install -r requirements.txt')

BEGIN = '<!-- >>> go:page: generated from go.md by scripts/build_go_page.py (do not edit) -->'
END = '<!-- <<< go:page -->'
HC = re.compile(r'(<div class="count" id="hc" aria-live="polite">)(.*?)(</div>)', re.S)
CSP_SRC = re.compile(r'(connect-src )(\S+)(;)')
# The link rule of the old go.js inl(): an http(s) URL, or a bare raw.githubusercontent.com or *.github.io URL.
LINK = re.compile(r'(https?://[^\s<]+|(?:raw\.githubusercontent\.com|[a-z0-9-]+\.github\.io)/[^\s<]*)')
REL = 'noopener noreferrer'


def esc(s):
    """Escape text for HTML (&, <, >, "), as go.js esc() did."""
    return str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


class _Link:
    """One link found in a text run, in the form markdown-it-py's linkify rule reads."""

    def __init__(self, m):
        """Take one regular-expression match of LINK."""
        u = m.group(0)
        self.index, self.last_index, self.text = m.start(), m.end(), u
        self.url = u if u.startswith('http') else 'https://' + u
        self.schema = 'https:'  # never empty: markdown-it-py would put http:// in front of the text


class HostLinks:
    """The linkify object for markdown-it-py: finds the same links as go.js did, and no fuzzy domains (go.md, x.md)."""

    def pretest(self, text):
        """True when text can hold a link."""
        return bool(LINK.search(text))

    test = pretest

    def match(self, text):
        """The links in text, in order."""
        return [_Link(m) for m in LINK.finditer(text)]

    def match_at_start(self, text):
        """No link rule at the start of a run: the core linkify rule finds them all."""
        return None


def make_md():
    """The markdown-it-py renderer: CommonMark, raw HTML off, our link finder, rel on each link.

    Returns:
        A MarkdownIt object; renderInline(text) gives the HTML of one line.
    """
    md = MarkdownIt('commonmark', {'html': False, 'linkify': True}).enable('linkify')
    md.disable('linkify', ignoreInvalid=True)  # the inline rule (scheme at start); the core rule stays on
    md.core.ruler.enable('linkify')
    md.linkify = HostLinks()

    def link_open(renderer, tokens, idx, options, env):
        """Each link gets rel="noopener noreferrer": no access to the page, and no page address sent."""
        tokens[idx].attrSet('rel', REL)
        return renderer.renderToken(tokens, idx, options, env)

    md.add_render_rule('link_open', link_open)
    return md


MD = make_md()


def _plain(part):
    """Escape the Markdown signs go.md does not use, outside a code span: a backslash stays a backslash, and a single
    * or _ stays a sign (go.md has only **bold**, as go.js read it)."""
    part = part.replace('\\', '\\\\').replace('_', '\\_')
    return re.sub(r'(?<!\*)\*(?!\*)', r'\\*', part)


def inl(s):
    """The HTML of one go.md text line: escaped text, **bold**, `code` and links."""
    return MD.renderInline(''.join(p if p.startswith('`') else _plain(p) for p in re.split(r'(`[^`]+`)', s)))


def slug(s, i):
    """A page id for card i with name s."""
    return 's%d-%s' % (i, re.sub(r'^-|-$', '', re.sub(r'[^a-z0-9]+', '-', s.lower()))[:40])


def is_round(h):
    """True for a link to a round script (scripts/gov/paste/*.ps1)."""
    return bool(re.search(r'/scripts/gov/paste/[^/]+\.ps1$', h))


def txt_name(h):
    """The .txt file name of a round script link."""
    return re.sub(r'\.ps1$', '', h.split('/')[-1], flags=re.I) + '.txt'


def file_card(u):
    """The HTML of a file card for a bare URL line; a round script gets Open as .txt and Copy script (PFM 20 Nov 26).

    Args:
        u: the URL, with or without https://.

    Returns:
        The HTML text of the card: a round script has no .ps1 link and no Copy link, only its two buttons.
    """
    h = u if u.startswith('http') else 'https://' + u
    name = h.split('/')[-1]
    if is_round(h):
        return ('<div class="file"><span class="fn"><strong>%s</strong></span>'
                '<button type="button" data-txt="%s" data-label="Open as .txt" aria-label="Open as .txt: save %s to read'
                ' the script before you paste it">Open as .txt</button><button type="button" class="primary"'
                ' data-script="%s" aria-label="Copy the whole script %s">Copy script</button></div>'
                % (esc(name), esc(h), esc(txt_name(h)), esc(h), esc(name)))
    return ('<div class="file"><span class="fn"><a href="%s" rel="%s">%s</a><span class="fu">%s</span></span>'
            '<button type="button" data-copy="%s" aria-label="Copy link to %s">Copy link</button></div>'
            % (esc(h), REL, esc(name), esc(h), esc(h), esc(name)))


def folder_box(lbl, path):
    """The HTML of a folder line with a Copy button."""
    return ('<div class="folder"><span class="lbl">%s</span><code>%s</code><button type="button" data-copy="%s"'
            ' aria-label="Copy folder path">Copy</button></div>' % (esc(lbl), esc(path), esc(path)))


def render_body(lines):
    """The HTML of a card body: lists, file cards, folder lines, notes, sub-headings and paragraphs.

    Args:
        lines: the go.md lines of the card (or of a group intro, or of the page intro).

    Returns:
        The HTML text. A numbered line keeps its number (<li value="N">); a "- " line is a Done list item.
    """
    out, st = [], {'list': None, 'item': False}

    def close_item():
        """End the open list item."""
        if st['item']:
            out.append('</li>')
            st['item'] = False

    def close_list():
        """End the open list."""
        close_item()
        if st['list']:
            out.append('</%s>' % st['list'])
            st['list'] = None

    for line in lines:
        t = line.strip()
        if not t:
            continue
        if re.match(r'^(https?://|raw\.githubusercontent\.com/)\S+$', t):  # a file card stays inside the open step
            out.append(file_card(t))
            continue
        m = re.match(r'^(\d+)\.\s+(.*)$', t)
        if m:
            if st['list'] != 'ol':
                close_list()
                out.append('<ol>')
                st['list'] = 'ol'
            close_item()
            out.append('<li value="%s">%s' % (m.group(1), inl(m.group(2))))
            st['item'] = True
            continue
        m = re.match(r'^[-*]\s+(.*)$', t)
        if m:
            if st['list'] != 'ul':
                close_list()
                out.append('<ul class="done-list">')
                st['list'] = 'ul'
            close_item()
            out.append('<li>' + inl(m.group(1)))
            st['item'] = True
            continue
        close_list()
        out.append(text_line(t))
    close_list()
    return ''.join(out)


def text_line(t):
    """The HTML of a go.md line that is not a list item or a file card.

    Args:
        t: the line, stripped.

    Returns:
        A folder line with a Copy button, a note (Report, Status, Decided, FAIL, WARN), a sub-heading (a short line
        that ends in ":"), or a paragraph.
    """
    m = re.match(r'^(Folder|Bookmark[^:]*|Fallback[^:]*):\s*(.*)$', t)
    if m and re.search(r'[\\/]', m.group(2)):
        path = re.sub(r'\.\s.*$', '', m.group(2))
        rest = re.sub(r'^\.\s*', '', m.group(2)[len(path):])
        return folder_box(m.group(1) + ':', path) + ('<p>%s</p>' % inl(rest) if rest else '')
    m = re.match(r'^(Report|Status[^:]*|Decided|FAIL|WARN):\s*(.*)$', t)
    if m:
        return '<p class="note"><span class="lbl">%s:</span> %s</p>' % (esc(m.group(1)), inl(m.group(2)))
    if re.match(r'^[A-Z][^.]{2,80}:$', t) or re.match(r'^Part [A-Z]\b.*:$', t):
        return '<h3>%s</h3>' % inl(t[:-1])
    return '<p>%s</p>' % inl(t)


def parse(md):
    """Split go.md text into its title, intro, sections and cards.

    Args:
        md: the whole text of go.md.

    Returns:
        {title, intro[], secs[{h, lines[], items[{h, lines[]}]}]}: items are the "###" cards of a group section.
    """
    doc, sec, item = {'title': '', 'intro': [], 'secs': []}, None, None
    for line in md.replace('\r', '').split('\n'):
        if line.startswith('# ') and not doc['title']:
            doc['title'] = line[2:]
        elif line.startswith('## '):
            sec, item = {'h': line[3:], 'lines': [], 'items': []}, None
            doc['secs'].append(sec)
        elif line.startswith('### ') and sec:
            item = {'h': line[4:], 'lines': []}
            sec['items'].append(item)
        else:
            (item['lines'] if item else sec['lines'] if sec else doc['intro']).append(line)
    return doc


def state_of(h, fallback=''):
    """Read "(open|done, when)" from a heading: {name, state, when}."""
    m = re.match(r'^(.*?)\s*\((open|done)[,\s]*([^)]*)\)\s*$', h, re.I)
    if m:
        return {'name': m.group(1), 'state': m.group(2).lower(), 'when': m.group(3)}
    return {'name': h, 'state': fallback, 'when': ''}


def group_state(h):
    """The state a group gives its "###" cards: "Open tasks" = open, "Done" = done, else none."""
    return 'open' if re.match(r'^open tasks$', h, re.I) else 'done' if re.match(r'^done$', h, re.I) else ''


def card(info, lines, cid, extra=''):
    """One collapsible card; open when its state is open (go.js then applies this browser's remembered choice)."""
    cls = 'sec' + (' open-task' if info['state'] == 'open' else ' done-task' if info['state'] == 'done' else '')
    chip = ('<span class="chip %s">%s</span>' % (info['state'], 'Open' if info['state'] == 'open' else 'Done')
            if info['state'] else '')
    when = '<span class="when">%s</span>' % esc(info['when']) if info['when'] else ''
    return ('<details class="%s" id="%s" data-name="%s"%s><summary><span class="st">%s</span><span class="meta">%s%s%s'
            '</span></summary><div class="body">%s</div></details>'
            % (cls, cid, esc(info['name']), ' open' if info['state'] == 'open' else '', inl(info['name']), chip, when,
               extra, render_body(lines)))


def done_count(lines):
    """The "N items" label of a Done list (one item per "- " line)."""
    return '<span class="when">%d items</span>' % sum(1 for x in lines if re.match(r'^\s*-\s', x))


def render_secs(secs):
    """The section links, the cards and the open count of all sections.

    Args:
        secs: the sections from parse().

    Returns:
        {nav: the HTML of the section links, body: one HTML text for each card or group, open: the open card count}.
    """
    r, n = {'nav': '', 'body': [], 'open': 0}, 0
    for s in secs:
        gs = group_state(s['h'])
        if not s['items']:  # a plain section: one card (only "Done" gets a state without "(open|done)")
            info = state_of(s['h'], 'done' if gs == 'done' else '')
            cid, n = slug(info['name'], n), n + 1
            r['open'] += info['state'] == 'open'
            r['nav'] += '<li><a href="#%s"%s>%s</a></li>' % (cid, ' class="is-open"' if info['state'] == 'open' else '',
                                                           inl(info['name']))
            r['body'].append(card(info, s['lines'], cid, done_count(s['lines']) if re.match(r'^done$', s['h'], re.I)
                                  else ''))
            continue
        gid, n = slug(s['h'], n), n + 1
        cards, links = [], ''
        for it in s['items']:
            info = state_of(it['h'], gs)
            cid, n = slug(info['name'], n), n + 1
            if info['state'] == 'open':
                r['open'] += 1
                links += '<li><a href="#%s" class="is-open">%s</a></li>' % (cid, inl(info['name']))
            cards.append(card(info, it['lines'], cid))
        r['nav'] += '<li><a href="#%s">%s (%d)</a></li>%s' % (gid, inl(s['h']), len(s['items']), links)
        intro = '<div class="gintro">%s</div>' % render_body(s['lines']) if any(x.strip() for x in s['lines']) else ''
        r['body'].append('<section class="grp" id="%s"><h2>%s</h2>%s\n%s\n</section>' % (gid, inl(s['h']), intro,
                                                                                       '\n'.join(cards)))
    return r


def main_html(md, urls):
    """The HTML of <main>: the bar, the section links, How to use this page, the cards and the source line.

    Args:
        md: the whole text of go.md.
        urls: site_config.urls() (only "raw" is read).

    Returns:
        (html, open count).
    """
    doc = parse(md)
    r = render_secs(doc['secs'])
    src, where = urls['raw'] + 'go.md', '%s/%s' % (urls['raw'].split('/')[3], urls['raw'].split('/')[4])
    parts = [
        '<p class="mut">Built from go.md. After a change, GitHub can take up to 10 minutes to show the new page: press'
        ' Reload for the newest.</p>',
        '<div class="bar"><button type="button" id="ex">Expand all</button><button type="button" id="co">Collapse all'
        '</button><button type="button" id="rl">Reload</button></div>',
        '<nav aria-label="Sections"><ul class="toc">%s</ul></nav>' % r['nav'],
        '<details class="sec" data-name="__how"><summary><span class="st">How to use this page</span></summary>'
        '<div class="body">%s</div></details>' % render_body(doc['intro']),
    ] + r['body'] + [
        '<p class="mut foot">Source: <a href="%s" rel="%s">go.md</a> in %s. Open and closed sections are remembered in'
        ' this browser.</p>' % (esc(src), REL, esc(where))]
    return '\n'.join(parts), r['open']


def build(page, md, urls):
    """The new text of index.html.

    Args:
        page: the text of index.html.
        md: the text of go.md.
        urls: site_config.urls() (only "raw" is read).

    Returns:
        The page with the go:page block, the #hc count and the CSP connect-src source made again.

    Raises:
        ValueError: when a marker line, the count box or the CSP source is not there exactly once.
    """
    if page.count(BEGIN) != 1 or page.count(END) != 1 or page.index(BEGIN) > page.index(END):
        raise ValueError('index.html needs one %s line and one %s line after it' % (BEGIN, END))
    body, n_open = main_html(md, urls)
    a, b = page.index(BEGIN) + len(BEGIN), page.index(END)
    page = page[:a] + '\n' + body + '\n' + page[b:]
    count = '<b>%d</b>open task%s' % (n_open, '' if n_open == 1 else 's')
    if len(HC.findall(page)) != 1 or len(CSP_SRC.findall(page)) != 1:
        raise ValueError('index.html needs one #hc count box and one CSP connect-src source')
    page = HC.sub(lambda m: m.group(1) + count + m.group(3), page)
    return CSP_SRC.sub(lambda m: m.group(1) + urls['raw'] + m.group(3), page)


def self_test():
    """Invented go.md text only. Prints GO BUILD TEST PASS, or each failed case and exits 1."""
    u = {'raw': 'https://raw.githubusercontent.com/o/r/main/'}
    fails = []

    def check(name, ok):
        """Note a failed case."""
        if not ok:
            fails.append(name)

    grouped = '# T\n## Open tasks\n### Round A (run first)\nx\n### Round B\ny\n## Done\n- a\n- b\n'
    hostile = ('# T\n## Open tasks\n### <script>alert(1)</script>\n<img src=x onerror=alert(1)>\n'
               '[x](javascript:alert(1)) https://e.x/"onmouseover="alert(1)\n')
    rnd = '# T\n## Open tasks\n### R\nraw.githubusercontent.com/o/r/main/scripts/gov/paste/90161Z-R01-t.ps1\n'
    html, n = main_html(grouped, u)
    check('2 "###" rounds under Open tasks count 2', n == 2 and html.count('class="is-open"') == 2)
    check('Done keeps its item count', '2 items' in html)
    check('"Open questions" makes no open card', main_html('# T\n## Open questions\n### Q\nz\n', u)[1] == 0)
    check('an Open tasks section with no "###" counts 0', main_html('# T\n## Open tasks\n\nNothing.\n## Done\n- a\n', u)[1] == 0)
    check('old "## Round (open, date)" headings still count', main_html('# T\n## R (open, 1 Jan)\nx\n## Z (done, 1 Jan)\n', u)[1] == 1)
    h, _ = main_html(hostile, u)
    check('no script, image or event attribute from go.md', '<script' not in h and '<img' not in h
          and not re.search(r'<[^>]*\son\w+=', h))
    check('no javascript: link', 'href="javascript' not in h)
    check('each link out of the page has rel', all('rel="%s"' % REL in a for a in re.findall(r'<a href="http[^>]*>', h)))
    r, _ = main_html(rnd, u)
    check('a round script gets Open as .txt and Copy script, no .ps1 link', 'data-txt=' in r and 'data-script=' in r
          and not re.search(r'<a href="[^"]*\.ps1"', r))
    check('file names are not links', '<a' not in inl('See go.md, TASKS.md and check.sh.'))
    check('a backslash stays', 'Rounds\\&lt;round&gt;' in inl('Rounds\\<round>'))
    check('a single * or _ is no italic, also in code', inl('2*3*4 a_b_c _x_ `a_b\\c`') ==
          '2*3*4 a_b_c _x_ <code>a_b\\c</code>')
    check('bold, code and a bare raw link', inl('**b** `c` raw.githubusercontent.com/o/r/x') ==
          '<strong>b</strong> <code>c</code> <a href="https://raw.githubusercontent.com/o/r/x" rel="%s">'
          'raw.githubusercontent.com/o/r/x</a>' % REL)
    page = ('<meta content="default-src \'none\'; connect-src https://old/;"><div class="count" id="hc" '
            'aria-live="polite"></div><main>%s\n%s</main>' % (BEGIN, END))
    out = build(page, grouped, u)
    check('build writes the count and the CSP source', '<b>2</b>open tasks' in out and 'connect-src %s;' % u['raw'] in out)
    check('a second build changes nothing', build(out, grouped, u) == out)
    if fails:
        for f in fails:
            print('FAIL ' + f)
        sys.exit(1)
    print('GO BUILD TEST PASS')


def main(argv):
    """Rebuild or check index.html from go.md.

    Args:
        argv: the command-line arguments: --check, --test, or none.

    Returns:
        None; exits 1 with a FAIL line when the page is stale (--check) or cannot be built.
    """
    if '--test' in argv:
        return self_test()
    page = PAGE.read_text(encoding='utf-8')
    try:
        new = build(page, GO.read_text(encoding='utf-8'), site_config.urls())
    except ValueError as e:
        sys.exit('FAIL %s' % e)
    if '--check' in argv:
        if new != page:
            sys.exit('FAIL index.html is not the build of go.md: run python3 scripts/build_go_page.py')
        print('GO PAGE BUILD CHECK PASS')
        return None
    if new != page:
        PAGE.write_text(new, encoding='utf-8')
    print('GO PAGE BUILT: index.html from go.md')
    return None


if __name__ == '__main__':
    main(sys.argv[1:])
