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
    refuses('filled path with no Z', svg(path('M 64 64 L 448 64 L 256 448')), 'must end with Z')
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


if __name__ == '__main__':
    test_good()
    test_refusals()
    print('LOGODRAW pass=%d fail=%d' % (PASS[0], FAIL[0]))
    sys.exit(1 if FAIL[0] else 0)
