# Format and writing rules: 90-161.Z

Source: DAFMAN 90-161, 18 Oct 2023, Change 1 (14 Jul 2025), Corrective Action (1 May 2026).
Extraction status: **verified 2026-11-10** against the literal text (self-review, not independent review). Literal text: ref/dafman90-161.txt (from ref/dafman90-161.pdf, 199 pages). Rows with a date in `Verified` were checked against that text. Before any rule is used as a hard check, verify its wording against the PDF and set `Verified` to the date.

Goal (Administrator, 2026-11-10): the rules force output to look like DAFMAN 90-161 itself. AFIMPT is not used for formatting or tracking.

Context (Administrator, 2026-11-10): ANG wing. ANG wing publications are not processed by AFDPO (1.1.3.2, 6.6.3), so the renderer's `final` mode must produce the camera-ready publication, including the TOC (F-027) and manual margin bars for ICs (4.5.6 note).

## How the rules are enforced

| Layer | Mechanism | What it guarantees |
|---|---|---|
| L1 Schema | The model returns content only as structured JSON (header fields, paragraphs with level, tables, attachments). The schema has no font, size or style fields. | The model cannot change format. |
| L2 Renderer | Deterministic code builds the .docx from the JSON. Fonts, margins, numbering, bolding and header block are fixed in code. | Same input gives the same layout every time. |
| L3 Validator | Code checks each rule below and reports pass/fail per rule ID. | "Perfect" = 0 fails on `hard` rules. |

Check type: `schema` = enforced by L1; `render` = enforced by L2; `lint` = checked by L3 on the text; `human` = Administrator checks.
Severity: `hard` = blocks output; `warn` = reported only.

## Rules

| ID | Rule | Ref | Check | Sev | Verified |
|---|---|---|---|---|---|
| F-001 | Microsoft Word, Times New Roman 12 pt, 1-inch margins all sides; page numbers included | 4.5.3.1 | render | hard | 2026-11-10 |
| F-002 | Tables, figures, attachments use the same font unless another size improves readability or fit | 4.5.3.1 | render | warn | 2026-11-10 |
| F-003 | Paragraph numbers end with a period when they precede text (1.1., 1.1.1.) | 4.5.3.2 | render | hard | 2026-11-10 |
| F-004 | Subordinate paragraph numbers and titles not bold | 4.5.3.3 | render | hard | 2026-11-10 |
| F-005 | Each subparagraph has at least one companion at the same level (not for integrated supplements) | 4.5.3.4 | lint | hard | 2026-11-10 |
| F-006 | Max 7 paragraph levels | 4.5.3.5 | schema | hard | 2026-11-10 |
| F-007 | Tables not made in Word are figures | 4.5.3.6 | schema | hard | 2026-11-10 |
| F-008 | Each attachment has a title | 4.5.3.7 | schema | hard | 2026-11-10 |
| F-009 | Numbering per Table 4.1: chapters Arabic; sections capital letters with chapter prefix; paragraphs chapter-based (1.1); figures/tables chapter- or attachment-based (Figure 1.1, Figure A2.1); attachment paragraphs A3.1; supplements follow parent numbering | T4.1 | render | hard | 2026-11-10 |
| F-010 | Draft mode: header "DRAFT—NOT FOR IMPLEMENTATION OR COMPLIANCE" on every page; no watermark; no track changes or comments | 4.5.1 | render | hard | 2026-11-10 |
| F-011 | Content order: header; opening paragraph; summary of changes (if applicable); TOC (if applicable); overview/background; responsibilities; core content; approver's authentication; attachments | 4.5.2 | schema | hard | 2026-11-10 |
| F-000 | Publications not processed by AFDPO (ANG wing) are formatted by the OPR to look like an AFDPO-formatted publication: camera-ready, "use this publication as a template" | 4.5.4 | render | hard | 2026-11-10 |
| F-012 | Front header flush left, no tabs, single-spaced applies to AFDPO-processed publications; ANG wing output follows F-000 and the measured layout L-xxx | 4.5.4 | render | hard | 2026-11-10 |
| F-013 | First line "BY ORDER OF THE [SECRETARY OF THE AIR FORCE] [COMMANDER]" | 4.5.4.1 | schema | hard | 2026-11-10 |
| F-014 | Unit publications use the unit shield; integrated supplements use the seal | 4.5.4.2 | human | hard | 2026-11-10 |
| F-015 | Type and number with correct prefix (DAF / AF / SPF) | 4.5.4.3 | lint | hard | 2026-11-10 |
| F-016 | Date placeholder "(Date)" | 4.5.4.4 | render | hard | 2026-11-10 |
| F-017 | AFSC series title in italics | 4.5.4.5 | render | hard | 2026-11-10 |
| F-018 | Title all caps; no "policy, instruction, guidance, handbook, pamphlet, catalog, guide, book"; no "Department of the Air Force", "Air Force", "Space Force" | 4.5.4.6 | lint | hard | 2026-11-10 |
| F-019 | "COMPLIANCE WITH THIS PUBLICATION IS MANDATORY" for directive publications only | 4.5.4.7 | schema | hard | 2026-11-10 |
| F-020 | ACCESSIBILITY and RELEASABILITY statements from Tables 4.2 / 4.3; optional meta.accessibilityLink makes the wing site name a hyperlink (Administrator 2026-11-13; styled as the DAFMAN cover link: bold, blue #0000FF, underlined) | 4.5.4.8–9 | schema | hard | 2026-11-13 |
| F-021 | "OPR:" and "Certified By:" show office symbols, no names | 4.5.4.10–11 | lint | hard | 2026-11-10 |
| F-022 | "Supersedes:" month spelled out, entries separated by semicolons; line omitted if none | 4.5.4.12 | render | hard | 2026-11-10 |
| F-023 | "Pages:" with page count | 4.5.4.13 | render | hard | 2026-11-10 |
| F-024 | Opening paragraph: first sentence names the immediate antecedent publication in full, title italic | 4.5.5.1 | lint | hard | 2026-11-10 |
| F-025 | Opening paragraph built by code from openingParts (fixed statements verbatim: 4.5.5.8, 4.5.5.9, Table 4.5, 4.5.5.11; conditional 4.5.5.3-7, 4.5.5.12 last). Statements as applicable: applicability, Privacy Act, copyright, PRA, punitive, statutory, records, recommending changes (DAF Form 847), supplementing, waiver authority, trademark disclaimer last | 4.5.5.2–13 | schema | hard | 2026-11-10 |
| F-026 | Summary of changes: heading bold italic all caps; brief; rewrites and ICs only; IC last sentence "A margin bar (\|) indicates newly revised material." | 4.5.6 | render | hard | 2026-11-10 |
| F-027 | TOC always for ANG wing publications (4.5.8.2, T-1), built from main paragraph headings, chapters and attachments (4.5.8.3); no switch (Administrator, 2026-11-11) | 4.5.8.2–4.5.8.3 | render | hard | 2026-11-11 |
| F-028 | Main headings bold, significant words capitalized | 4.5.9.2 | render | hard | 2026-11-10 |
| F-029 | Directive publications: no bullets. Non-directive: simple, non-nested bullets only | 4.5.9.3 | schema | hard | 2026-11-10 |
| F-030 | Responsibilities assigned to positions, not individuals | 4.5.9.6 | lint | warn | 2026-11-10 |
| F-031 | No section titled "Core Content" | 4.5.9.7 | lint | hard | 2026-11-10 |
| F-032 | Acronyms and office symbols spelled out at first use, listed in Attachment 1; headings spell out then acronym; acronyms used 4 times or fewer spelled out | 4.5.9.7.2–3 | lint | warn | 2026-11-10 |
| F-033 | Bold list (chapter titles, top-level paragraph numbers/titles, table/figure numbers/titles, Note:/Exception:, tier numbers, attachment titles, Attachment 1 categories); URLs not bold | 4.5.9.7.4 | render | hard | 2026-11-10 |
| F-034 | No wet signature on the publication | 4.5.10 | schema | hard | 2026-11-10 |
| F-035 | Attachment 1 "GLOSSARY OF REFERENCES AND SUPPORTING INFORMATION": unnumbered sections References, Prescribed Forms, Adopted Forms ("None" if empty), Abbreviations and Acronyms, Office Symbols, Terms; references without URLs | 4.5.11 | schema | hard | 2026-11-10 |
| F-036 | Additional attachments numbered in sequence, paragraphs A2.1, A3.1 | 4.5.11.2 | render | hard | 2026-11-10 |
| F-037 | "Note:" and "Exception:" bold with colon | 4.6 | render | hard | 2026-11-10 |
| F-038 | Figure/table number and title directly above the item; min 8 pt | 4.6 | render | hard | 2026-11-10 |
| F-039 | Compliance statements use "will"/"must", name a responsible party, end with bold tier "(T-1)"; no blanket tiers. In a wing or delta publication the validator does not ask for a tier (Administrator 2B, 2026-11-12; see F-040) | 4.6.5 | lint | warn | 2026-11-10 |
| F-040 | Do not use a tier number at the issuer's own level: in a wing or delta publication, (T-3) is redundant because the wing or delta/CC who approved it is the default waiver authority. The validator treats a publication as wing level when `byOrderOf` is COMMANDER and `issuerLine` or `byOrderOfUnit` names a WING or DELTA (a keyword guess: the schema has no level field, so an abbreviated issuer such as WG is missed and a non-wing name with WING or DELTA is caught). A wing or delta compliance statement carries no tier, except (T-0), (T-1) or (T-2) where the waiver authority is above the wing (Administrator 2B, 2026-11-12). Severity warn (Administrator 1A, 2026-11-12) | Attachment 10 note 4; 4.6.5.3.2 | lint | warn | 2026-11-12 |
| W-001 | Use "must", not "shall" | T1.1 #5 | lint | hard | 2026-11-10 |
| W-002 | Sentences 20 words or fewer; paragraphs 7 sentences or fewer | T1.1 #2 | lint | warn | 2026-11-10 |
| W-003 | No all-caps for emphasis | T1.1 #4 | lint | warn | 2026-11-10 |
| W-004 | Active voice; plain language | T1.1 #1, 1.2.2 | lint | warn | 2026-11-10 |
| X-001 | No unresolved [[PFM: ...]] placeholder from the extraction prompt (prompts/90161Z-T06-extract-prompt-r2.txt); never invent a value (AGENTS.md) | - | lint | hard | 2026-11-11 |
| S-001 | File names without spaces (3.8.2). The rest of 3.8 (left flush template, separate figure files) is for e-Publishing submission and does not apply to ANG wing camera-ready posting | 3.8 | render | hard | 2026-11-10 |

## Open

- Literal wording for Tables 4.2–4.5 and the statements in 4.5.5 is not yet extracted. The renderer must take them from the verified text, not from this summary.
- Wing supplement rules (if any) override or add to this list.

## Layout measured from ref/dafman90-161.pdf (2026-11-10)

DAFMAN 90-161 itself is the template (4.5.4). These values are measured with pdftotext/pdftohtml bounding boxes, not guessed.

| ID | Element | Measured value | Source page |
|---|---|---|---|
| L-001 | Running header | Top at 0.507 in; bold; odd pages: designator + 2 spaces + date left, page number right; even pages: page number left, designator + date right; none on page 1 | 43, 44, 110 |
| L-002 | Paragraph indent | Main paragraph at margin; each lower level +0.25 in (1.00, 1.25, 1.50, 1.75 in); continuation lines align with the number (no hanging indent) | 43, 45 |
| L-003 | Paragraph spacing | 6 pt after each paragraph; single line spacing; body text justified | 43 |
| L-004 | Gaps | Two spaces after paragraph numbers, after headings, before each new sentence (6.55 pt vs 3.14 pt word gap, n=53), and between designator and date in the running header | 40-46 |
| L-005 | Cover statements | ACCESSIBILITY/RELEASABILITY labels bold; text at 1.5 in from margin (hanging) | 1 |
| L-006 | Signature block | Starts 4.00 in from the page edge (3.0 in from margin), about two lines below the last text | 109 |
| L-007 | Seal/shield | x 1.00 in, top 1.47 in, 1.20 in square (7 of 7 covers; see docs/reviews/2026-11-11-cover-consistency.md) | 1 + 6 pubs |
| L-007a | Seal preparation | Every seal is prepared by scripts/gov/90161Z-T07-seal-prep-r5.ps1: white (R, G, B 245 or more) and clear (alpha under 16) margins trimmed; larger side scaled to the box, shape kept; centered on a clear 360 x 360 px PNG at 300 dpi (Administrator 1A 2A). Source under 100 dpi at 1.20 in = FAIL, under 150 = WARN. Validator: path must be in a Prepared folder; renderer: 360 x 360 PNG only, placed at 1.20 x 1.20 in | Administrator 2026-11-11 |
| L-008 | Cover rules | 3 rules, 6.50 in wide, 0.75-0.80 pt: below COMPLIANCE line, below RELEASABILITY, below Supersedes/Pages (7 of 7) | 1 + 6 pubs |
| L-008a | Cover spacing | Baseline and rule gaps on DAFMAN 90-161 page 1 (in): title to compliance 0.417; compliance to rule 0.182; rule to ACCESSIBILITY 0.285; RELEASABILITY to rule 0.264; rule to OPR 0.394; Supersedes to rule 0.415; rule to opening 0.369. T01 r3 was 0.049-0.442 (Administrator report 2026-11-11) | 1 |
| L-012 | Table of contents | DAFMAN 90-161 page 2: 11 pt; chapter and attachment entries bold at 1.00 in, wrapped lines at 2.00 in; paragraph entries not bold, number at 1.50 in, text at 2.00 in; 0.202 in between lines of an entry, 0.272 in between entries; page numbers right at 7.50 in with dot leaders. Figures and tables are not listed (4.5.8.3 main paragraph headings only) | 1 |
| L-009 | Chapters | Start on a new page; "Chapter N" bold centered; title bold centered all caps on the next line | 40 |
| L-010 | Cover header | Two columns: left "BY ORDER OF ..." bold italic; right column right-aligned bold italic: issuer, type and number, date, series title, title | 1 |
| L-011 | Attachments | New page; "Attachment N" bold centered; title bold centered all caps; glossary category titles bold at margin | 110 |

Decided (Administrator, 2026-11-11): the cover reads "Certified by:" as printed on DAFMAN 90-161 and other published covers (4.5.4.11 writes "Certified By:").

Cover details L-010a..h (right-column groups, OPR/Supersedes tabs, Pages position, compliance spacing): docs/reviews/2026-11-11-cover-consistency.md.
