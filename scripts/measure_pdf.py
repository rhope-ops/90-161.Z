#!/usr/bin/env python3
"""Measure a renderer PDF from the gov device against DAFMAN 90-161 layout values (cloud side).

Word's Range.Information(5) reads TOC 2 lines 0.50 in short (rounds R01, R02) while the PDF is right,
so horizontal TOC checks run here on the returned PDF. Values: docs/format-rules.md L-012
(TOC 2 number 1.50 in, text 2.00 in, entry pitch 0.272 in). Also reports the F-020 accessibility link.
Usage: python3 scripts/measure_pdf.py <file.pdf>   Exit 1 if a check fails. Needs pdfplumber.
"""
import re
import sys

import pdfplumber

TOL, PITCH_TOL = 0.03, 0.01
WANT = {'number': 1.50, 'text': 2.00, 'pitch': 0.272}


def line_words(page):
    """Group the words of a PDF page into text lines. Takes the page; returns a list of lines (top to bottom), each a list of words left to right."""
    rows = {}
    for w in page.extract_words(keep_blank_chars=False, use_text_flow=True):
        rows.setdefault(round(w['top'], 1), []).append(w)
    return [sorted(v, key=lambda w: w['x0']) for _, v in sorted(rows.items())]


def check(name, got, want, tol):
    """Print one measurement and whether it is within tolerance. Takes a name, the measured and wanted inches and the tolerance; returns True when it passes."""
    ok = abs(got - want) <= tol
    print(f'MEASURE {name} got={got:.3f}in want={want}in tol={tol} {"PASS" if ok else "FAIL"}')
    return ok


def main(path):
    """Measure the table of contents of a PDF (number and text left edges, line pitch) and report the first-page links. Takes the path; returns 1 when a measurement fails, else 0."""
    fails = 0
    with pdfplumber.open(path) as pdf:
        toc2, toc_tops = None, []
        for page in pdf.pages[:3]:
            for row in line_words(page):
                if re.search(r'\.{5,}', ''.join(w['text'] for w in row)):
                    toc_tops.append((page.page_number, row[0]['top'] / 72))
                    if toc2 is None and re.fullmatch(r'\d+\.\d+\.', row[0]['text']) and len(row) > 1:
                        toc2 = row
        if toc2 is None:
            print('MEASURE-ERROR L-012 no TOC 2 line found'); return 1
        fails += not check('L-012 TOC number left', toc2[0]['x0'] / 72, WANT['number'], TOL)
        fails += not check('L-012 TOC text left', toc2[1]['x0'] / 72, WANT['text'], TOL)
        pitches = [b[1] - a[1] for a, b in zip(toc_tops, toc_tops[1:]) if a[0] == b[0]]
        if pitches:
            fails += not check('L-012 TOC pitch (smallest)', min(pitches), WANT['pitch'], PITCH_TOL)
        links = [a.get('uri') for a in (pdf.pages[0].annots or []) if a.get('uri')]
        print(f'LINK page 1 count={len(links)}' + (' (F-020 accessibility link kept)' if links else ''))
    print(f'MEASURE-PDF fails={fails}')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
