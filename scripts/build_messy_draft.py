#!/usr/bin/env python3
"""Build the fake messy draft for Task 6 (GenAI.mil extraction test).

Output: samples/90161Z-T06-messy-draft-r1.docx (never hand-edit; change this script and rebuild).
All content is fake. The draft is messy on purpose: mixed fonts and sizes, typed and wrong paragraph
numbers, "shall", tier marks in several forms, "AF Form 847", bullets in a directive publication, a typed
NOTE: label, a draft mark, and the fixed opening statements in old wording. EXPECTED lists what a correct
extraction must contain; docs/gov-test-plan.md Task 6 uses it.

Usage: python3 scripts/build_messy_draft.py [--out PATH] [--check]
  --check  rebuild into a temp file and compare the document text with the committed file.
"""
import argparse
import os
import sys
import tempfile

from docx import Document
from docx.shared import Pt, RGBColor

OUT = "samples/90161Z-T06-messy-draft-r1.docx"

# (text, font, size, bold, italic)
LINES = [
    ("BY ORDER OF THE COMMANDER          SAMPLE AIRLIFT WING INSTRUCTION 36-101", "Arial", 13, True, False),
    ("SAMPLE AIRLIFT WING", "Arial", 13, True, False),
    ("DRAFT 3 - do not distribute", "Calibri", 9, False, True),
    ("Personnel", "Calibri", 12, False, True),
    ("UNIT TRAINING FOLDER MANAGEMENT", "Times New Roman", 16, True, False),
    ("COMPLIANCE WITH THIS PUBLICATION IS MANDATORY", "Times New Roman", 12, True, False),
    ("ACCESSIBILITY: This publication is only available directly from the OPR.", "Calibri", 11, False, False),
    ("RELEASABILITY: There are no releasability restrictions on this publication", "Calibri", 11, False, False),
    ("OPR: OPR-C                              Certified by: OPR-D (Lt Col Sample B. Certifier)", "Calibri", 11, False, False),
    ("Supersedes: SAMPLEWINGI36-101, 3 March 2021                    Pages: 9", "Calibri", 11, False, False),
    ("This instruction implements Sample Parent Instruction 36-26, Sample Total Force Development. "
     "It explains how units build, keep and close unit training folders. "
     "This publication applies to all uniformed members of the sample wing, including the Air National Guard (ANG). "
     "Ensure all records created as a result of processes prescribed in this publication are maintained IAW "
     "AFI 33-322 and disposed of IAW the Air Force Records Disposition Schedule. "
     "Refer recommended changes and questions about this publication to the OPR using the AF Form 847, "
     "Recommendation for Change of Publication. "
     "This publication may be supplemented at any level. "
     "The authorities to waive wing/unit level requirements in this publication are identified with a Tier number.",
     "Courier New", 10, False, False),
    ("SUMMARY OF CHANGES", "Arial", 12, True, False),
    ("This document has been substantially revised and must be completely reviewed. "
     "Major changes include an electronic folder option.", "Arial", 11, False, False),
    ("Chapter 1 -- GENERAL", "Arial", 14, True, False),
    ("1.1. Purpose. This instruction sets the rules for unit training folders.", "Calibri", 11, False, False),
    ("1.3. Scope. Each unit shall keep one folder for each member. (T3)", "Calibri", 12, False, False),
    ("Chapter 2 - RESPONSIBILITIES", "Arial", 14, True, False),
    ("2.1. Unit Training Manager (UTM).", "Calibri", 11, True, False),
    ("2.1.1. Will open a folder within 30 days of assignment. T-3", "Calibri", 11, False, False),
    ("2.1.2. Will review each folder every 6 months. (t-3)", "Calibri", 11, False, False),
    ("2.2. Supervisor. Will sign each training entry. (T-3)", "Calibri", 11, False, False),
    ("CHAPTER 3: FOLDER CONTENTS", "Arial", 14, True, False),
    ("3.1. Contents. Each folder shall hold the items in Table 3.1.", "Calibri", 11, False, False),
]

TABLE_TITLE = "Table 3.1. Folder Contents."
TABLE = [["Item", "Required Document"], ["1", "Training record"], ["2", "Qualification checklist"], ["3", "Duty position description"]]

AFTER_TABLE = [
    ("3.2. Electronic folders. A unit may keep folders in the approved electronic system.", "Calibri", 11, False, False),
    ("NOTE: Paper folders remain valid until the member separates.", "Calibri", 10, True, False),
    ("3.3. Closing folders. When a member leaves the unit the UTM:", "Calibri", 11, False, False),
    ("- closes the folder within 10 days (T-3)", "Calibri", 11, False, False),
    ("- sends the folder to the gaining unit (T-3)", "Calibri", 11, False, False),
    ("SAMPLE C. SIGNER, Colonel, ANG", "Times New Roman", 12, False, False),
    ("Commander", "Times New Roman", 12, False, False),
    ("Attachment 1", "Arial", 12, True, False),
    ("GLOSSARY OF REFERENCES AND SUPPORTING INFORMATION", "Arial", 12, True, False),
    ("References", "Arial", 11, True, False),
    ("Sample Parent Instruction 36-26, Sample Total Force Development, 1 January 2024", "Calibri", 11, False, False),
    ("Adopted Forms", "Arial", 11, True, False),
    ("AF Form 847, Recommendation for Change of Publication", "Calibri", 11, False, False),
    ("Abbreviations and Acronyms", "Arial", 11, True, False),
    ("ANG - Air National Guard", "Calibri", 11, False, False),
    ("OPR - office of primary responsibility", "Calibri", 11, False, False),
    ("UTM - unit training manager", "Calibri", 11, False, False),
    ("Office Symbols", "Arial", 11, True, False),
    ("OPR-C - Sample Office C", "Calibri", 11, False, False),
    ("OPR-D - Sample Office D", "Calibri", 11, False, False),
]

# What a correct extraction must hold (Task 6 pass checks).
EXPECTED = {
    "meta.designator": "SAMPLEWINGI36-101",
    "meta.opr / certifiedBy / certifiedByName": "OPR-C / OPR-D / Lt Col Sample B. Certifier",
    "meta.action": "rewrite (supersedes SAMPLEWINGI36-101, 3 March 2021)",
    "chapters": "3: GENERAL, RESPONSIBILITIES, FOLDER CONTENTS",
    "paragraph titles": "Purpose., Scope., Unit Training Manager (UTM)., Supervisor., Contents., Electronic folders., Closing folders.",
    "tier marks": "0: all 6 (T-3) marks removed and each listed in part 2 (prompt r2 M8; F-040, PFM 2B 2026-11-12)",
    "shall -> must": "2 (Scope., Contents.)",
    "table": "Folder Contents., 2 columns, 3 rows",
    "notes": "1 (Electronic folders.)",
    "bullets -> children": "2 (Closing folders.)",
    "dropped fixed sentences": "4 (records, DAF Form 847, supplement, waiver)",
    "AF Form 847 -> DAF Form 847": "one adopted form entry, Recommendation for Change of Product; AFI 33-322 added to references",
}


def _run(par, text, font, size, bold, italic):
    """Add one text run to a paragraph with a font, size, bold and italic. Takes the paragraph and those values; returns the run."""
    r = par.add_run(text)
    r.font.name = font
    r.font.size = Pt(size)
    r.bold = bold
    r.italic = italic
    return r


def build(path):
    """Write the fake messy draft Word file (typed header, mixed fonts, a table). Takes the output path; returns nothing."""
    doc = Document()
    cp = doc.core_properties
    cp.author = "Sample Author"
    cp.title = "Fake messy draft for 90-161.Z Task 6"
    hdr = doc.sections[0].header.paragraphs[0]   # typed running header, as many drafts have
    _run(hdr, "SAMPLEWINGI36-101  DRAFT", "Calibri", 9, False, False)
    for text, font, size, bold, italic in LINES:
        _run(doc.add_paragraph(), text, font, size, bold, italic)
    p = doc.add_paragraph()
    r = _run(p, TABLE_TITLE, "Arial", 10, True, False)
    r.font.color.rgb = RGBColor(0x1F, 0x4E, 0x79)
    t = doc.add_table(rows=len(TABLE), cols=len(TABLE[0]))
    for i, row in enumerate(TABLE):
        for j, cell in enumerate(row):
            t.cell(i, j).text = cell
    for text, font, size, bold, italic in AFTER_TABLE:
        _run(doc.add_paragraph(), text, font, size, bold, italic)
    doc.save(path)


def text_of(path):
    """Read the text of a Word file (header, paragraphs, table rows) so two files can be compared. Takes the path; returns one string."""
    d = Document(path)
    parts = [p.text for p in d.sections[0].header.paragraphs] + [p.text for p in d.paragraphs]
    for t in d.tables:
        for row in t.rows:
            parts.append(" | ".join(c.text for c in row.cells))
    return "\n".join(parts)


def main():
    """Command line: write the draft to --out, or with --check compare a fresh build with the committed file. Returns the exit code (1 when stale)."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        with tempfile.TemporaryDirectory() as d:
            tmp = os.path.join(d, "x.docx")
            build(tmp)
            if not os.path.exists(OUT) or text_of(tmp) != text_of(OUT):
                print("messy draft stale: run python3 scripts/build_messy_draft.py")
                return 1
        return 0
    build(a.out)
    print("wrote", a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
