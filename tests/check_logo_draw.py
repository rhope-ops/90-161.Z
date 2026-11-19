#!/usr/bin/env python3
"""Test scripts/logo_draw.py with invented SVG text: one good drawing and each clean refusal (no pytest, standard library only).

Last line: "LOGODRAW pass=N fail=0". The PNG bytes of the real logo are checked elsewhere (tests/run.sh logo hash check).
Network: none.
Writes: none (the drawings stay in memory).
Credentials: none.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
import logo_draw as L

PASS, FAIL = [0], [0]
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'


def svg(*body):
    """Build an SVG text. Args: body (element texts). Returns: the SVG text with the 512 viewBox."""
    return HEAD + ''.join(body) + '</svg>'


def path(d, extra='fill="#ff0000"'):
    """Build a <path> element. Args: d (path data), extra (more attributes). Returns: the element text."""
    return '<path d="%s" %s/>' % (d, extra)


def check(name, ok, detail=''):
    """Count and print one result. Args: name, ok (bool), detail (text shown on a failure). Returns: nothing."""
    PASS[0] += ok
    FAIL[0] += not ok
    print(('LOGOTEST PASS ' if ok else 'LOGOTEST FAIL ') + name + ('' if ok else ' ' + detail))


def refuses(name, text, words):
    """Check that drawing `text` stops with a clean SystemExit message. Any other exception type is a failure.

    Args:
        name: the name of the case, for the result line.
        text: the SVG text to draw.
        words: a text the message must contain.
    """
    try:
        L.draw(text, 16)
        check(name, False, 'no refusal')
    except SystemExit as e:
        msg = str(e)
        check(name, msg.startswith('logo_draw:') and words in msg, msg)
    except Exception as e:   # a Python error instead of a message is the bug under test
        check(name, False, 'raised %s: %s' % (type(e).__name__, e))


def test_good():
    """One good drawing: a filled closed triangle, a filled circle and a stroked open arc path draw to a valid PNG."""
    tri = path('M 64 64 L 448 64 L 256 448 Z')
    arc = path('M 100 400 A 50 50 0 0 1 200 400', 'fill="none" stroke="#0000ff" stroke-width="8" stroke-linecap="round"')
    png = L.draw(svg(tri, '<circle cx="400" cy="400" r="40" fill="#00ff00"/>', arc), 32)
    check('good drawing: PNG signature', png[:8] == b'\x89PNG\r\n\x1a\n')
    rows = L.pixels(svg(tri), 32)
    check('good drawing: inside the triangle is red', tuple(rows[8][16 * 4:16 * 4 + 4]) == (255, 0, 0, 255))
    check('good drawing: outside is transparent', tuple(rows[30][2 * 4:2 * 4 + 4]) == (0, 0, 0, 0))
    check('good drawing: same bytes twice', png == L.draw(svg(tri, '<circle cx="400" cy="400" r="40" fill="#00ff00"/>', arc), 32))


def test_refusals():
    """Each input that used to raise a Python error (or draw nothing) now stops with a logo_draw message."""
    refuses('filled path with an arc', svg(path('M 100 100 A 50 50 0 0 1 200 100 L 150 200 Z')), 'arc')
    refuses('filled path with no Z', svg(path('M 64 64 L 448 64 L 256 448')), 'with Z')
    refuses('arc from a point to itself', svg(path('M 100 100 A 50 50 0 0 1 100 100', 'fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round"')), 'arc needs')
    refuses('unknown clip-path id', svg('<circle cx="256" cy="256" r="50" fill="#000000" clip-path="url(#nope)"/>'), '#nope')
    refuses('clip-path not url(#id)', svg('<circle cx="256" cy="256" r="50" fill="#000000" clip-path="none"/>'), 'url(#id)')
    refuses('L before M', svg(path('L 10 10 L 20 20 Z')), 'start with M')
    refuses('H before M', svg(path('H 10 Z')), 'start with M')
    refuses('empty path data', svg(path('')), 'start with M')
    refuses('too few numbers', svg(path('M 10', 'fill="none"')), 'numbers')
    refuses('L with one number at the end', svg(path('M 10 10 L 20', 'fill="none"')), 'numbers')
    refuses('L with no number at the end', svg(path('M 10 10 L', 'fill="none"')), 'numbers')
    refuses('missing d attribute', svg('<path fill="none"/>'), 'start with M')


def px_at(rows, x, y):
    """Return the RGBA tuple of one pixel. Args: rows (from L.pixels), x, y. Returns: a 4-tuple."""
    return tuple(rows[y][x * 4:x * 4 + 4])


def test_delta_features():
    """The features the Delta logo needs (the PFM, 2026-11-19): groups, transforms, lines, curves, holes, opacity."""
    ring = path('M 64 64 L 448 64 L 448 448 L 64 448 Z M 192 192 L 192 320 L 320 320 L 320 192 Z')
    rows = L.pixels(svg(ring), 32)
    check('two sub-paths: the ring is red', px_at(rows, 5, 16) == (255, 0, 0, 255))
    check('two sub-paths: the hole is empty (nonzero rule)', px_at(rows, 16, 16) == (0, 0, 0, 0))
    rows = L.pixels(svg('<g fill="#0000ff" fill-opacity="0.5"><circle cx="256" cy="256" r="200"/></g>'), 32)
    check('group: fill and fill-opacity pass to the child', px_at(rows, 16, 16) == (0, 0, 255, 128))
    rows = L.pixels(svg('<g transform="translate(256 256) rotate(90)"><path d="M 0 0 L 200 0 L 200 40 L 0 40 Z" fill="#00ff00"/></g>'), 32)
    check('transform: rotate(90) turns the bar to point down', px_at(rows, 15, 26) == (0, 255, 0, 255) and px_at(rows, 28, 17) == (0, 0, 0, 0))
    rows = L.pixels(svg('<line x1="64" y1="256" x2="448" y2="256" stroke="#000000" stroke-width="32" stroke-linecap="round" transform="scale(1 2) translate(0 -128)"/>'), 32)
    alpha = [px_at(rows, 16, y)[3] for y in range(12, 20)]   # rows 14 to 17 (y 232 to 280) lie inside 224 to 288
    check('line under scale(1 2): the stroke is 64 units tall', [a > 128 for a in alpha] == [False] * 2 + [True] * 4 + [False] * 2, str(alpha))
    rows = L.pixels(svg(path('M 64 448 Q 256 -192 448 448 Z', 'fill="#ff0000"')), 32)
    check('Q curve: the hump is filled', px_at(rows, 16, 12) == (255, 0, 0, 255) and px_at(rows, 3, 6) == (0, 0, 0, 0))
    rows = L.pixels(svg(path('M 64 448 C 64 0 448 0 448 448 Z', 'fill="#ff0000"')), 32)
    check('C curve: the arch is filled', px_at(rows, 16, 12) == (255, 0, 0, 255) and px_at(rows, 1, 1) == (0, 0, 0, 0))
    a = L.draw(svg(path('M 64 64 L 448 64 L 448 448 Z')), 32)
    b = L.draw(svg(path('M 64 64 L 448 64 448 448 Z')), 32)
    check('numbers after L repeat L, as SVG reads them', a == b)


def test_delta_refusals():
    """What the Delta drawing still does not handle stops with a logo_draw message."""
    refuses('relative command', svg(path('M 10 10 l 20 20 Z')), 'not supported')
    refuses('skewX transform', svg('<circle cx="256" cy="256" r="50" transform="skewX(10)"/>'), 'skewX')
    refuses('scale(0) flattens the shape', svg('<circle cx="256" cy="256" r="50" transform="scale(0)"/>'), 'flattens')
    refuses('unknown attribute on <g>', svg('<g opacity="0.5"><circle cx="256" cy="256" r="50"/></g>'), 'opacity')
    refuses('stroke-opacity on a shape', svg('<circle cx="256" cy="256" r="50" stroke-opacity="0.5"/>'), 'stroke-opacity')
    refuses('one open sub-path in a fill', svg(path('M 64 64 L 448 64 L 256 448 Z M 10 10 L 20 20')), 'with Z')
    refuses('a command after Z that is not M', svg(path('M 64 64 L 448 64 L 256 448 Z L 10 10')), 'after Z')
    refuses('line with a square cap', svg('<line x1="0" y1="0" x2="10" y2="10" stroke="#000000"/>'), 'linecap')
    refuses('fill-opacity above 1', svg('<circle cx="256" cy="256" r="50" fill-opacity="2"/>'), 'fill-opacity')
    refuses('bad cx number', svg('<circle cx="a" cy="256" r="50"/>'), 'cx')
    refuses('dash with a comma (review 19 Nov 26)', svg('<circle cx="256" cy="256" r="50" fill="none" stroke="#000000" stroke-dasharray="5,a" stroke-linecap="round"/>'), 'stroke-dasharray')
    refuses('dash 0 0', svg('<circle cx="256" cy="256" r="50" fill="none" stroke="#000000" stroke-dasharray="0 0" stroke-linecap="round"/>'), 'sum above 0')
    refuses('scale(inf)', svg('<circle cx="256" cy="256" r="50" transform="scale(inf)"/>'), 'bad numbers')
    refuses('matrix with nan', svg('<circle cx="256" cy="256" r="50" transform="matrix(nan 0 0 1 0 0)"/>'), 'bad numbers')
    refuses('line x1 nan', svg('<line x1="nan" y1="0" x2="10" y2="10" stroke="#000000" stroke-linecap="round"/>'), 'x1')
    refuses('path number 1e999', svg(path('M 0 0 L 1e999 0', 'fill="none" stroke="#000000" stroke-linecap="round"')), 'numbers')
    refuses('path with only M', svg(path('M 10 10', 'fill="none"')), 'at least one segment')
    refuses('not well-formed XML', '<svg', 'well-formed')


if __name__ == '__main__':
    test_good()
    test_refusals()
    test_delta_features()
    test_delta_refusals()
    print('LOGODRAW pass=%d fail=%d' % (PASS[0], FAIL[0]))
    sys.exit(1 if FAIL[0] else 0)
