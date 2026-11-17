#!/usr/bin/env python3
"""Build the two fake workbooks for the R27 look probe (Task 21, Excel in the browser), standard library only.

Output (never hand-edit; change this script and rebuild): the repo holds no .xlsx or .xlsm (the personal-data scan cannot read a
binary file, and its skip rules are the PFM's), so both files are written as base64 text into scripts/gov/90161Z-T21-probe-r3.ps1
between the fake-workbooks markers; part Make saves them in the T21 folder and uploads them:
  90161Z-T21-fake-book-r1.xlsx   one sheet, 3 fake rows ("FAKE ... R27"); no macro
  90161Z-T21-fake-macro-r1.xlsm  the same sheet plus a tiny VBA project (xl/vbaProject.bin) that writes "FAKE MACRO RAN R27"
                                 into cell A6 when the workbook opens and holds one sub, FakeMacro, that does the same.
                                 The VBA project is built here from source text (MS-OVBA streams in an MS-CFB container);
                                 no Office program makes it, so the R27 look probe also says whether the file opens at all.
All content is invented. Timestamps are fixed and the zip is stored (not deflated), so the bytes are stable.

Usage: python3 scripts/build_probe_samples.py [--check]
  --check  write nothing; exit 1 when the blocks in the script differ from what this script builds.
"""
import base64
import re
import struct
import sys
import zipfile
from io import BytesIO
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAMP = (2026, 11, 17, 0, 0, 0)
MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
PROJECT_ID = '{9016A0B1-2B3C-4D5E-8F70-1A2B3C4D5E6F}'   # a made-up GUID (not a real project)


# ---- the workbook ----

def sheet_xml():
    rows = [('FAKE book R27', 'Invented numbers, nothing real'), ('Fake item one', '11'), ('Fake item two', '22')]
    out = []
    for i, (a, b) in enumerate(rows, 1):
        out.append('<row r="%d"><c r="A%d" t="inlineStr"><is><t>%s</t></is></c><c r="B%d" t="inlineStr"><is><t>%s</t></is></c></row>' % (i, i, a, i, b))
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<worksheet xmlns="%s"><sheetData>%s</sheetData></worksheet>' % (MAIN, ''.join(out)))


def package(macro):
    wb_type = 'application/vnd.ms-excel.sheet.macroEnabled.main+xml' if macro else 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml'
    types = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
             '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
             '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
             '<Default Extension="xml" ContentType="application/xml"/>'
             + ('<Default Extension="bin" ContentType="application/vnd.ms-office.vbaProject"/>' if macro else '') +
             '<Override PartName="/xl/workbook.xml" ContentType="%s"/>'
             '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>' % wb_type)
    rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="%s/officeDocument" Target="xl/workbook.xml"/></Relationships>' % REL)
    workbook = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                '<workbook xmlns="%s" xmlns:r="%s"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>' % (MAIN, REL))
    wb_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
               '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
               '<Relationship Id="rId1" Type="%s/worksheet" Target="worksheets/sheet1.xml"/>' % REL
               + ('<Relationship Id="rId2" Type="http://schemas.microsoft.com/office/2006/relationships/vbaProject" Target="vbaProject.bin"/>' if macro else '')
               + '</Relationships>')
    parts = [('[Content_Types].xml', types.encode()), ('_rels/.rels', rels.encode()), ('xl/workbook.xml', workbook.encode()),
             ('xl/_rels/workbook.xml.rels', wb_rels.encode()), ('xl/worksheets/sheet1.xml', sheet_xml().encode())]
    if macro:
        parts.append(('xl/vbaProject.bin', vba_project()))
    buf = BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as z:
        for name, data in parts:
            info = zipfile.ZipInfo(name, STAMP)
            info.compress_type = zipfile.ZIP_STORED
            info.external_attr = 0o644 << 16
            z.writestr(info, data)
    return buf.getvalue()


# ---- the VBA project (MS-OVBA 2.3 and 2.4) ----

def ovba_compress(data):
    """MS-OVBA 2.4.1 container with literal tokens only (valid, not small): one chunk of up to 3600 bytes."""
    assert len(data) <= 3600
    chunk = bytearray()
    for i in range(0, len(data), 8):
        group = data[i:i + 8]
        chunk.append(0)
        chunk += group
    header = ((len(chunk) + 2 - 3) & 0x0FFF) | (0b011 << 12) | 0x8000
    return b'\x01' + struct.pack('<H', header) + bytes(chunk)


def encrypt(data, project_key, seed=0x5A, ignored=1):
    """MS-OVBA 2.4.3.2 data encryption (version 2), as used for the CMG, DPB and GC values of the PROJECT stream."""
    out = bytearray([seed, seed ^ 2, seed ^ project_key])
    unenc1, enc1, enc2 = project_key, project_key, seed ^ 2
    body = bytes([0x00] * ignored) + struct.pack('<I', len(data)) + data
    res = bytearray()
    for b in body:
        e = b ^ ((enc2 + unenc1) & 0xFF)
        res.append(e)
        enc2, enc1, unenc1 = enc1, e, b
    return bytes(out) + bytes(res)


def rec(rid, payload=b''):
    return struct.pack('<HI', rid, len(payload)) + payload


MODULES = [
    ('ThisWorkbook', True, 'Attribute VB_Name = "ThisWorkbook"\r\nAttribute VB_Base = "0{00020819-0000-0000-C000-000000000046}"\r\nAttribute VB_GlobalNameSpace = False\r\n'
     'Attribute VB_Creatable = False\r\nAttribute VB_PredeclaredId = True\r\nAttribute VB_Exposed = True\r\nAttribute VB_TemplateDerived = False\r\nAttribute VB_Customizable = True\r\n'
     'Private Sub Workbook_Open()\r\n    ThisWorkbook.Worksheets(1).Range("A6").Value = "FAKE MACRO RAN R27"\r\nEnd Sub\r\n'),
    ('Sheet1', True, 'Attribute VB_Name = "Sheet1"\r\nAttribute VB_Base = "0{00020820-0000-0000-C000-000000000046}"\r\nAttribute VB_GlobalNameSpace = False\r\n'
     'Attribute VB_Creatable = False\r\nAttribute VB_PredeclaredId = True\r\nAttribute VB_Exposed = True\r\nAttribute VB_TemplateDerived = False\r\nAttribute VB_Customizable = True\r\n'),
    ('Module1', False, 'Attribute VB_Name = "Module1"\r\nSub FakeMacro()\r\n    ThisWorkbook.Worksheets(1).Range("A6").Value = "FAKE MACRO RAN R27"\r\nEnd Sub\r\n'),
]
REFERENCES = [
    ('stdole', '*\\G{00020430-0000-0000-C000-000000000046}#2.0#0#C:\\Windows\\System32\\stdole2.tlb#OLE Automation'),
    ('Office', '*\\G{2DF8D04C-5BFA-101B-BDE5-00AA0044DE52}#2.0#0#C:\\Program Files\\Common Files\\Microsoft Shared\\OFFICE16\\MSO.DLL#Microsoft Office 16.0 Object Library'),
]


def dir_stream():
    d = bytearray()
    d += rec(0x0001, struct.pack('<I', 1)) + rec(0x0002, struct.pack('<I', 0x409)) + rec(0x0014, struct.pack('<I', 0x409))
    d += rec(0x0003, struct.pack('<H', 1252)) + rec(0x0004, b'VBAProject')
    d += rec(0x0005) + rec(0x0040) + rec(0x0006) + rec(0x003D) + rec(0x0007, struct.pack('<I', 0)) + rec(0x0008, struct.pack('<I', 0))
    d += struct.pack('<HIIH', 0x0009, 4, 1, 0)
    d += rec(0x000C) + rec(0x003C)
    for name, libid in REFERENCES:
        n = name.encode('ascii')
        d += rec(0x0016, n) + rec(0x003E, name.encode('utf-16-le'))
        lib = libid.encode('ascii')
        d += rec(0x000D, struct.pack('<I', len(lib)) + lib + struct.pack('<IH', 0, 0))
    d += rec(0x000F, struct.pack('<H', len(MODULES))) + rec(0x0013, struct.pack('<H', 0xFFFF))
    for name, document, _ in MODULES:
        n = name.encode('ascii'); u = name.encode('utf-16-le')
        d += rec(0x0019, n) + rec(0x0047, u) + rec(0x001A, n) + rec(0x0032, u) + rec(0x001C) + rec(0x0048)
        d += rec(0x0031, struct.pack('<I', 0)) + rec(0x001E, struct.pack('<I', 0)) + rec(0x002C, struct.pack('<H', 0xFFFF))
        d += rec(0x0022 if document else 0x0021) + rec(0x002B)
    d += rec(0x0010)
    return bytes(d)


def project_stream():
    key = sum(PROJECT_ID.encode('ascii')) & 0xFF
    lines = ['ID="%s"' % PROJECT_ID, 'Document=ThisWorkbook/&H00000000', 'Document=Sheet1/&H00000000', 'Module=Module1', 'Name="VBAProject"',
             'HelpContextID="0"', 'VersionCompatible32="393222000"',
             'CMG="%s"' % encrypt(b'\x00\x00\x00\x00', key, 0x5A, 1).hex().upper(),
             'DPB="%s"' % encrypt(b'\x00', key, 0x5A, 2).hex().upper(),
             'GC="%s"' % encrypt(b'\xff', key, 0x5A, 1).hex().upper(), '',
             '[Host Extender Info]', '&H00000001={3832D640-CF90-11CF-8E43-00A0C911005A};VBE;&H00000000', '',
             '[Workspace]', 'ThisWorkbook=0, 0, 0, 0, C', 'Sheet1=0, 0, 0, 0, C', 'Module1=0, 0, 0, 0, C', '']
    return '\r\n'.join(lines).encode('ascii')


def projectwm_stream():
    out = bytearray()
    for name, _, _ in MODULES:
        out += name.encode('ascii') + b'\x00' + name.encode('utf-16-le') + b'\x00\x00'
    return bytes(out) + b'\x00\x00'


def cfb(entries):
    """MS-CFB version 3 file. entries: list of (path, bytes); path 'A' is a root stream, 'VBA/B' a stream in the storage VBA.
    Every stream is below 4096 bytes, so all of them live in the mini stream."""
    names = ['Root Entry']
    for p, _ in entries:
        if '/' in p and p.split('/')[0] not in names:
            names.append(p.split('/')[0])
    # directory entries: (name, type, stream bytes or None, parent storage)
    dents = [('Root Entry', 5, None, None)]
    storages = [n for n in names if n != 'Root Entry']
    for s in storages:
        dents.append((s, 1, None, 'Root Entry'))
    for p, data in entries:
        parent, leaf = p.split('/') if '/' in p else ('Root Entry', p)
        assert len(data) < 4096
        dents.append((leaf, 2, data, parent))
    # mini stream
    ministream = bytearray(); minifat = []; start = {}
    for i, (n, t, data, par) in enumerate(dents):
        if t == 2:
            start[i] = len(ministream) // 64
            nsec = max(1, (len(data) + 63) // 64) if data else 0
            if not data:
                start[i] = 0xFFFFFFFE
                continue
            ministream += data + b'\x00' * (nsec * 64 - len(data))
            minifat += [start[i] + k + 1 for k in range(nsec - 1)] + [0xFFFFFFFE]
    n_dir = (len(dents) + 3) // 4
    n_minifat = max(1, (len(minifat) * 4 + 511) // 512)
    n_mini = len(ministream) // 512 + (1 if len(ministream) % 512 else 0)
    n_fat = 1
    while n_fat * 128 < n_fat + n_dir + n_minifat + n_mini:
        n_fat += 1
    fat_start, dir_start = 0, n_fat
    minifat_start = dir_start + n_dir
    mini_start = minifat_start + n_minifat
    total = mini_start + n_mini
    fat = [0xFFFFFFFD] * n_fat
    def chain(first, count):
        return [first + k + 1 for k in range(count - 1)] + [0xFFFFFFFE]
    fat += chain(dir_start, n_dir) + chain(minifat_start, n_minifat) + (chain(mini_start, n_mini) if n_mini else [])
    fat += [0xFFFFFFFF] * (n_fat * 128 - len(fat))
    # red-black tree: all black; siblings of one storage form a balanced tree ordered by (length, upper-case name)
    key = lambda n: (len(n), n.upper())
    left = {}; right = {}; child = {}
    def build(idxs):
        if not idxs:
            return 0xFFFFFFFF
        idxs = sorted(idxs, key=lambda i: key(dents[i][0]))
        mid = len(idxs) // 2
        root = idxs[mid]
        left[root] = build(idxs[:mid]); right[root] = build(idxs[mid + 1:])
        return root
    for si, (n, t, data, par) in enumerate(dents):
        if t in (1, 5):
            kids = [i for i, d in enumerate(dents) if d[3] == n and i != si]
            child[si] = build(kids)
    out_dir = bytearray()
    for i, (n, t, data, par) in enumerate(dents):
        nm = n.encode('utf-16-le') + b'\x00\x00'
        if t == 5:
            st, size = (mini_start if n_mini else 0xFFFFFFFE), len(ministream)
        elif t == 2:
            st, size = start[i], len(data)
        else:
            st, size = 0, 0
        e = nm + b'\x00' * (64 - len(nm)) + struct.pack('<H', len(nm)) + bytes([t, 1])
        e += struct.pack('<III', left.get(i, 0xFFFFFFFF), right.get(i, 0xFFFFFFFF), child.get(i, 0xFFFFFFFF))
        e += b'\x00' * 16 + struct.pack('<I', 0) + b'\x00' * 16 + struct.pack('<IQ', st, size)
        assert len(e) == 128, len(e)
        out_dir += e
    while len(out_dir) < n_dir * 512:   # unused entries: no name, type 0, all links NOSTREAM
        out_dir += b'\x00' * 66 + bytes([0, 0]) + struct.pack('<III', 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF) + b'\x00' * 36 + struct.pack('<IQ', 0, 0)
    minifat_bytes = struct.pack('<%dI' % (n_minifat * 128), *(minifat + [0xFFFFFFFF] * (n_minifat * 128 - len(minifat))))
    header = b'\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1' + b'\x00' * 16 + struct.pack('<HHHHH', 0x3E, 3, 0xFFFE, 9, 6) + b'\x00' * 6
    header += struct.pack('<IIIIIIIII', 0, n_fat, dir_start, 0, 4096, minifat_start, n_minifat, 0xFFFFFFFE, 0)
    difat = [fat_start + k for k in range(n_fat)]
    header += struct.pack('<109I', *(difat + [0xFFFFFFFF] * (109 - len(difat))))
    body = struct.pack('<%dI' % (n_fat * 128), *fat) + bytes(out_dir) + minifat_bytes + bytes(ministream) + b'\x00' * (n_mini * 512 - len(ministream))
    assert len(body) == total * 512, (len(body), total)
    return header + body


def vba_project():
    entries = [('PROJECT', project_stream()), ('PROJECTwm', projectwm_stream()),
               ('VBA/_VBA_PROJECT', b'\xcc\x61\xff\xff\x00\x00\x00'), ('VBA/dir', ovba_compress(dir_stream()))]
    for name, _, src in MODULES:
        entries.append(('VBA/' + name, ovba_compress(src.encode('ascii'))))
    return cfb(entries)


SCRIPT = ROOT / 'scripts/gov/90161Z-T21-probe-r3.ps1'
BEGIN = '# >>> fake-workbooks: generated by scripts/build_probe_samples.py (do not edit)'
END = '# <<< fake-workbooks'
BLOCKS = (('FakeBookBase64', lambda: package(False)), ('FakeMacroBase64', lambda: package(True)))


def block():
    # No here-string: the RADE engine embeds this script in its own here-string and refuses a line that starts with '@.
    out = ''
    for name, make in BLOCKS:
        b64 = base64.b64encode(make()).decode('ascii')
        rows = [b64[i:i + 100] for i in range(0, len(b64), 100)]
        out += '$' + name + " = @(\n" + ',\n'.join("  '%s'" % r for r in rows) + "\n) -join ' '\n"
    return out


def main(check):
    stale = []
    text = SCRIPT.read_text(encoding='utf-8')
    m = re.search(re.escape(BEGIN) + r'\n(.*?)' + re.escape(END), text, re.S)
    if m is None:
        stale.append(SCRIPT.name + ' (markers missing)')
    elif m.group(1) != block():
        stale.append(SCRIPT.name)
        if not check:
            SCRIPT.write_text(text[:m.start(1)] + block() + text[m.end(1):], encoding='utf-8')
            stale.pop()
    for n in stale:
        print('STALE ' + n)
    print('PROBESAMPLES blocks=%d stale=%d' % (len(BLOCKS), len(stale)))
    return 1 if stale else 0


if __name__ == '__main__':
    sys.exit(main('--check' in sys.argv[1:]))
