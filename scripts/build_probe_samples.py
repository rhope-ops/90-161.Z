#!/usr/bin/env python3
"""Build the three fake sample files for the R26 easy-path probe (Task 21), standard library only.

Output (never hand-edit; change this script and rebuild):
  samples/90161Z-T21-fake-draft-r1.docx  2 pages of fake text, core Title "FAKE DRAFT R26", two plain-text content
                                         controls ProbeSubject (w:id 916101) and ProbeOPR (w:id 916102), each data-bound
                                         without storeItemID by a local-name() XPath so SharePoint property demotion can fill them
  samples/90161Z-T21-fake-form-r1.html   one-page fake form, 4 labelled fields, fake values
  1-page PDF 1.4, hand-written, text "FAKE - 90161Z R26 - sign here": not a file in the repo (the PII guard skips no .pdf);
                                         written as base64 text into scripts/gov/90161Z-T21-probe-r2.ps1 between the fake-sign-pdf markers;
                                         part Make saves it as 90161Z-T21-fake-sign-r1.pdf in the T21 folder
All content is invented. Timestamps are fixed and the zip is stored (not deflated), so the bytes are stable.

Usage: python3 scripts/build_probe_samples.py [--check]
  --check  write nothing; exit 1 when a committed file or the PDF block in the script differs from what this script builds.
"""
import base64
import re
import sys
import zipfile
from io import BytesIO
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'samples'
STAMP = (2026, 11, 16, 0, 0, 0)
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
XPATH = "/*[local-name()='properties'][1]/*[local-name()='documentManagement'][1]/*[local-name()='%s'][1]"


def para(text):
    return '<w:p><w:r><w:t xml:space="preserve">%s</w:t></w:r></w:p>' % text


def control(name, ident, value):
    return ('<w:sdt><w:sdtPr><w:alias w:val="%s"/><w:tag w:val="%s"/><w:id w:val="%d"/><w:text/>'
            '<w:dataBinding w:xpath="%s"/></w:sdtPr>'
            '<w:sdtContent><w:p><w:r><w:t>%s</w:t></w:r></w:p></w:sdtContent></w:sdt>'
            % (name, name, ident, XPATH % name, value))


def docx():
    page1 = [para('FAKE DRAFT R26 - fake wing instruction for the 90-161.Z probe. Nothing here is real.'),
             control('ProbeSubject', 916101, 'FAKE SUBJECT PLACEHOLDER'),
             control('ProbeOPR', 916102, 'FAKE OPR PLACEHOLDER')]
    page1 += [para('Fake paragraph %d. This sentence is invented test text and has no meaning.' % i) for i in range(1, 9)]
    page1.append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
    page2 = [para('FAKE page two. Invented text for the probe, nothing else.')]
    page2 += [para('Fake paragraph %d on page two. Invented test text only.' % i) for i in range(9, 17)]
    body = ''.join(page1 + page2) + ('<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>'
                                     '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>')
    document = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<w:document xmlns:w="%s"><w:body>%s</w:body></w:document>' % (W, body))
    types = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
             '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
             '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
             '<Default Extension="xml" ContentType="application/xml"/>'
             '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
             '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>')
    rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>')
    core = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
            'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            '<dc:title>FAKE DRAFT R26</dc:title><dc:creator>FAKE</dc:creator>'
            '<dcterms:created xsi:type="dcterms:W3CDTF">2026-11-16T00:00:00Z</dcterms:created>'
            '<dcterms:modified xsi:type="dcterms:W3CDTF">2026-11-16T00:00:00Z</dcterms:modified></cp:coreProperties>')
    buf = BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as z:
        for name, data in (('[Content_Types].xml', types), ('_rels/.rels', rels), ('word/document.xml', document), ('docProps/core.xml', core)):
            info = zipfile.ZipInfo(name, STAMP)
            info.compress_type = zipfile.ZIP_STORED
            info.external_attr = 0o644 << 16
            z.writestr(info, data.encode('utf-8'))
    return buf.getvalue()


def html():
    rows = [('Fake name', 'FAKE PERSON ONE'), ('Fake office', 'FAKE/OFFICE'), ('Fake request', 'FAKE REQUEST R26'), ('Fake date', '1 Jan 2000')]
    out = ['<!DOCTYPE html>', '<html lang="en"><head><meta charset="utf-8"><title>FAKE FORM R26</title></head>', '<body>',
           '<h1>FAKE FORM - 90161Z R26</h1>', '<p>Invented form for the probe. Nothing here is real.</p>', '<form>']
    for label, value in rows:
        out.append('<p><label>%s: <input type="text" value="%s"></label></p>' % (label, value))
    out += ['</form>', '</body></html>', '']
    return '\n'.join(out).encode('utf-8')


def pdf():
    stream = b'BT /F1 18 Tf 72 700 Td (FAKE - 90161Z R26 - sign here) Tj ET'
    objs = [b'<< /Type /Catalog /Pages 2 0 R >>',
            b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
            b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
            b'<< /Length %d >>\nstream\n' % len(stream) + stream + b'\nendstream',
            b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
    out = bytearray(b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n')
    offsets = []
    for i, o in enumerate(objs, 1):
        offsets.append(len(out))
        out += b'%d 0 obj\n' % i + o + b'\nendobj\n'
    xref = len(out)
    out += b'xref\n0 %d\n0000000000 65535 f \n' % (len(objs) + 1)
    for off in offsets:
        out += b'%010d 00000 n \n' % off
    out += b'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' % (len(objs) + 1, xref)
    return bytes(out)


FILES = {'90161Z-T21-fake-draft-r1.docx': docx, '90161Z-T21-fake-form-r1.html': html}


SCRIPT = ROOT / 'scripts/gov/90161Z-T21-probe-r2.ps1'
BEGIN = '# >>> fake-sign-pdf: generated by scripts/build_probe_samples.py (do not edit)'
END = '# <<< fake-sign-pdf'


def pdf_block():
    b64 = base64.b64encode(pdf()).decode('ascii')
    rows = [b64[i:i + 100] for i in range(0, len(b64), 100)]
    # No here-string: the RADE engine embeds this script in its own here-string and refuses a line that starts with '@.
    return "$FakeSignPdfBase64 = @(\n" + ',\n'.join("  '%s'" % r for r in rows) + "\n) -join ' '\n"


def main(check):
    stale = []
    text = SCRIPT.read_text(encoding='utf-8')
    m = re.search(re.escape(BEGIN) + r'\n(.*?)' + re.escape(END), text, re.S)
    if m is None:
        stale.append(SCRIPT.name + ' (markers missing)')
    elif m.group(1) != pdf_block():
        stale.append(SCRIPT.name)
        if not check:
            SCRIPT.write_text(text[:m.start(1)] + pdf_block() + text[m.end(1):], encoding='utf-8')
            stale.pop()
    for name, make in FILES.items():
        data = make()
        path = OUT / name
        if check:
            if not path.is_file() or path.read_bytes() != data:
                stale.append(name)
        else:
            path.write_bytes(data)
    for n in stale:
        print('STALE ' + n)
    print('PROBESAMPLES files=%d pdf-block=1 stale=%d' % (len(FILES), len(stale)))
    return 1 if stale else 0


if __name__ == '__main__':
    sys.exit(main('--check' in sys.argv[1:]))
