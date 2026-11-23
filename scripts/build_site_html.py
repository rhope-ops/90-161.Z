"""HTML parts of the kit's pages: the Markdown-to-HTML builders of scripts/build_site.py (moved here so that file stays
under its line cap) and the shared shell of a page the kit builds from scratch (scripts/timeline.py): a skip link, one
main landmark, theme-colour meta tags, reduced motion, and, only when the repo's `.check` has `dod-security: on`, a
Content-Security-Policy and a no-referrer meta tag (fleet v2 plan 2026-11-23: docs/reviews/2026-11-23-fleet-v2-plan.md).
Standard library only.
Network: none.
Writes: nothing.
Credentials: none.
"""
import base64
import hashlib
import html
import re
from pathlib import Path

README = 'README.md'
CHECK = '.check'
# The Fulcrum Minimal page colours (docs/brand/fulcrum.json roles "page": cream in light, ink in dark).
THEME_LIGHT, THEME_DARK = '#F3EEE4', '#15171D'
SHELL_CSS = (
    '.skip-link{position:absolute;left:8px;top:-100px;z-index:10;padding:12px 16px;background:#fff;color:#000;'
    'border:2px solid #000;border-radius:6px}.skip-link:focus{top:8px}'
    '@media (prefers-reduced-motion:reduce){*,*::before,*::after{animation-duration:.01ms !important;'
    'animation-iteration-count:1 !important;transition-duration:.01ms !important;scroll-behavior:auto !important}}')
SKIP_LINK = '<a class="skip-link" href="#main">Skip to content</a>'
def theme_meta(light, dark):
    """The 2 theme-color tags (light, dark), so the browser chrome matches the page background."""
    return (f'<meta name="theme-color" media="(prefers-color-scheme: light)" content="{light}">'
            f'<meta name="theme-color" media="(prefers-color-scheme: dark)" content="{dark}">')


def dod_security(root):
    """Return True when the `.check` of root has the line `dod-security: on`; False with no such line or with `off`.

    Args:
        root: the repository folder that holds `.check`.
    Returns:
        True only for `dod-security: on`.
    Raises:
        ValueError: for any other value or a second line (a typo must not switch a page's security off in silence).
    """
    path = Path(root) / CHECK
    text = path.read_text(encoding='utf-8-sig', errors='replace') if path.is_file() else ''
    found = [re.match(r'(?i)^dod-security\s*:\s*(.*?)\s*$', line.strip()) for line in text.splitlines()]
    values = [m.group(1) for m in found if m]
    if len(values) > 1 or any(v not in ('on', 'off') for v in values):
        raise ValueError(f'{CHECK}: `dod-security:` takes one line, `on` or `off`')
    return values == ['on']


def sha256(text):
    """Return the CSP hash source ('sha256-...') of one inline style or script body."""
    return "'sha256-" + base64.b64encode(hashlib.sha256(text.encode('utf-8')).digest()).decode('ascii') + "'"


def security_meta(style, script=''):
    """Return the DoD meta tags: a strict Content-Security-Policy that allows only the page's own inline style (and
    script) by hash, and a no-referrer policy.

    Args:
        style: the exact text of the page's one <style> element.
        script: the exact text of the page's one <script> element, or '' when it has none.
    Returns:
        The two <meta> tags.
    """
    policy = ["default-src 'none'", f'style-src {sha256(style)}', "img-src 'self' data:", "base-uri 'none'",
              "form-action 'none'"]
    if script:
        policy.insert(1, f'script-src {sha256(script)}')
    return (f'<meta http-equiv="Content-Security-Policy" content="{"; ".join(policy)}">'
            '<meta name="referrer" content="no-referrer">')


def page_head(title, style, script='', security=False, theme=(THEME_LIGHT, THEME_DARK)):
    """Return the start of a page: doctype, head (with the shell tags), skip link and the opening of main.

    Args:
        title: the page title, already HTML-escaped.
        style: the page's CSS; the shell CSS is added after it.
        script: the page's inline script text ('' for none); used for its CSP hash only.
        security: True to add the DoD meta tags (dod_security).
        theme: the page's own (light, dark) background colors, for the 2 theme-color tags.
    Returns:
        HTML up to and including <main id="main">; close it with "</main>".
    """
    css = style + SHELL_CSS
    extra = security_meta(css, script) if security else ''
    return (f"<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>{extra}"
            f"<meta name='viewport' content='width=device-width,initial-scale=1'>{theme_meta(*theme)}"
            f'<title>{title}</title><style>{css}</style></head><body>{SKIP_LINK}<main id="main">')


# Plain text in a site section may hold only these characters (an allow list): letters, digits, spaces and ordinary
# punctuation that GitHub shows as typed. Any other character (* _ at a word's edge, ` ~ [ ] < > @ # = \ | ^ and the
# like) could be Markdown that GitHub renders differently from this builder, so the check fails on it. An underscore
# inside a word is plain text on GitHub (AFI33-332_DAFGM2026-01) and is allowed.
PLAIN_TEXT = r"[A-Za-z0-9 .,;:'\"()\-/?!%+&‘’“”–—…]*"
IN_WORD_UNDERSCORE = r'(?<=[A-Za-z0-9])_(?=[A-Za-z0-9])'
# Strong text GitHub renders, in the forms this builder allows: "**" after the line start, a space, "(", a quote or
# "-", before a non-space; the closing "**" after a non-space, before the line end, a space, punctuation, a quote or
# "-". ("**x:**y" stays refused: GitHub cannot close it before a letter.)
BOLD = (r'(?:(?<=^)|(?<=[\s("\'“‘-]))\*\*(?=[^\s*`])([^*`]*?[^\s*`])\*\*'
        r'(?=$|[\s.,;:!?)"\'”’-])')
# Rendered by GitHub although every character is on the allow list: HTML entities (also with digits, &frac12;),
# emoji codes (:warning:; a name that starts with a letter, not right after a letter or digit, so 09:00-17:00 and
# 1:2:3 pass), and web addresses of any scheme or case (ftp://, HTTP://, WWW.).
ENTITY_OR_ADDRESS = (r'&(#\d+|#x[0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]*);|(?<![A-Za-z0-9]):[A-Za-z_+][A-Za-z0-9_+-]*:'
                     r'|[A-Za-z][A-Za-z0-9+.-]*://|(?i:www\.)')
# A line that starts a list (also an empty item: "+" or "1." alone), is indented (an indented code block, or a
# continuation GitHub may read differently), ends with a hard break, or underlines a heading ("===" or "---").
LIST_START = r'([-+]|\d+[.)])(\s|$)'
# Inside a paragraph, only a bullet or "1." starts a list on GitHub ("2026. That year." stays text).
LIST_INTERRUPT = r'([-+]|1[.)])(\s|$)'
INDENTED = r'[ \t]'
SETEXT_LINE = r'\s*(=+|-+)\s*'
HARD_BREAK = r'.*(  |\\)$'
# The key-facts table: plain HTML, because a Markdown table always shows a header row (33-332.Z, 2026-11-21). One row
# per line, the label bold and ending in ":"; cells hold plain text only (no tags, no Markdown), and no "&" either: in
# raw HTML a browser reads "&copy" as a symbol even without its ";", and the site would not. A row may end with a
# source comment (FACT_SOURCE), which GitHub and the site do not show.
FACT_TABLE = r'<table>\n((?:<tr>.*</tr>.*\n)+)</table>(.*)'
FACT_ROW = r'<tr><td><b>([^<>*`&]+:)</b></td><td>([^<>*`&]+)</td></tr>(?: <!-- source: ([^<>]*[^<>\s-]) -->)?'


def refuse_marks(markdown):
    """Raise ValueError unless plain text (outside `code`, **bold** marks removed) holds only allow-listed characters.

    Args:
        markdown: one line of text, without its `code` spans.
    """
    text = re.sub(IN_WORD_UNDERSCORE, 'x', re.sub(BOLD, r'\1', markdown))
    if not re.fullmatch(PLAIN_TEXT, text) or re.search(ENTITY_OR_ADDRESS, text):
        raise ValueError(f'{README}: unsupported Markdown or character in a site section; only plain text, **bold** and '
                         f'`code`: {markdown}')


def inline(markdown):
    """Turn one line of Markdown (text, **bold**, `code`) into escaped HTML; raise ValueError on any other Markdown.

    Args:
        markdown: one line of text; text inside `code` is kept as is and never made bold.
    Returns:
        The escaped HTML.
    """
    out = []
    for piece in re.split(r'(`[^`]+`)', markdown):
        if piece.startswith('`') and piece.endswith('`') and len(piece) > 1:
            out.append('<code>' + html.escape(piece[1:-1], quote=False) + '</code>')
            continue
        refuse_marks(piece)
        out.append(re.sub(BOLD, r'<strong>\1</strong>', html.escape(piece, quote=False)))
    return ''.join(out)


def paragraphs(markdown):
    """Return the paragraphs of plain Markdown text (blank lines split them; lines inside one are joined).

    Args:
        markdown: text without a table.
    Returns:
        The paragraphs, each on one line.
    Raises:
        ValueError: when a line starts a list, is indented, underlines a heading or ends with a hard break.
    """
    lines = markdown.splitlines()
    for number, line in enumerate(lines):
        starts = number == 0 or not lines[number - 1].strip()
        if (re.match(LIST_START if starts else LIST_INTERRUPT, line) or re.match(INDENTED, line)
                or re.fullmatch(SETEXT_LINE, line) or re.fullmatch(HARD_BREAK, line)):
            raise ValueError(f'{README}: a list, an indented line, a heading underline or a hard line break is not '
                             f'supported in a site section: {line}')
    return [' '.join(part.split()) for part in re.split(r'\n\s*\n', markdown) if part.strip()]


def build_intro(markdown, indent):
    """Return the site's intro paragraph.

    Args:
        markdown: the intro section: one paragraph.
        indent: the indent of the block's start mark on the page.
    Returns:
        The HTML paragraph.
    """
    parts = paragraphs(markdown)
    if len(parts) != 1:
        raise ValueError(f'{README}: site:intro must be one paragraph')
    return f'{indent}<p>{inline(parts[0])}</p>'


def fact_rows(markdown, need_source):
    """Return the key-facts rows (label, text) and the text after the table.

    Args:
        markdown: the key-facts section: an HTML table (FACT_TABLE, FACT_ROW), then optional text after a blank line.
        need_source: True when every row must end with its source comment.
    Returns:
        A pair: the rows as (label, text) and the text after the table.
    Raises:
        ValueError: when the table or a row has another form, a cell holds more than plain text, or a source is missing.
    """
    match = re.fullmatch(FACT_TABLE, markdown, re.S)
    lines = match.group(1).splitlines() if match else []
    if not match or any(not re.fullmatch(FACT_ROW, line) for line in lines):
        raise ValueError(f'{README}: site:key-facts must be <table>, then rows "<tr><td><b>Label:</b></td><td>text</td>'
                         f'</tr>" (each may end with " <!-- source: ... -->"), one per line, then </table>')
    rest = match.group(2)
    if rest.strip() and not rest.startswith('\n\n'):
        raise ValueError(f'{README}: text after the site:key-facts table needs a blank line')
    rows = [re.fullmatch(FACT_ROW, line).groups() for line in lines]
    missing = [label for label, _, source in rows if need_source and not source]
    if missing:
        raise ValueError(f'{README}: site:key-facts rows need " <!-- source: ... -->" (REQUIRE_FACT_SOURCE): '
                         f'{", ".join(missing)}')
    for cell in (cell for label, text, _ in rows for cell in (label, text)):
        refuse_marks(cell)
    return [(label, text) for label, text, _ in rows], rest


def build_key_facts(markdown, indent, need_source=False):
    """Return the site's aligned key-facts list and the lines after it.

    Args:
        markdown: the key-facts section (fact_rows).
        indent: the indent of the block's start mark on the page.
        need_source: True when every row must end with its source comment.
    Returns:
        The HTML: a definition list (label, text), then one small paragraph for each line after the table.
    """
    rows, rest = fact_rows(markdown, need_source)
    items = ''.join(f'\n{indent}  <dt>{html.escape(label.strip(), quote=False)}</dt>'
                    f'<dd>{html.escape(text.strip(), quote=False)}</dd>' for label, text in rows)
    tail = ''.join(f'\n{indent}<p class="small mut">{inline(part)}</p>' for part in paragraphs(rest))
    return f'{indent}<dl class="facts">{items}\n{indent}</dl>{tail}'
