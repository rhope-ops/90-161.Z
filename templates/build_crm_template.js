// Builds templates/CRM_A12-1.docx: blank Comment Resolution Matrix per DAFMAN 90-161 Figure A12.1 and para 5.3.
// Column widths measured from ref/dafman90-161.pdf page 198 (inches): 0.40 0.70 0.60 0.44 0.43 0.49 1.30 1.36 0.76.
// Resolution codes A/R/M (PFM decision 2026-11-11). Do not hand-edit the .docx; change this file and run: node templates/build_crm_template.js
const fs = require('fs');
const path = require('path');
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, AlignmentType,
        VerticalAlign, HeightRule, BorderStyle } = require('docx');

const FONT = 'Times New Roman';
const SZ = 24;            // 12 pt (DAFMAN 4.5.3.1)
const IN = 1440;
const widthsIn = [0.40, 0.70, 0.60, 0.44, 0.43, 0.49, 1.30, 1.36, 0.76];
const widths = widthsIn.map(w => Math.round(w * IN));
const total = widths.reduce((a, b) => a + b, 0);
const border = { style: BorderStyle.SINGLE, size: 4, color: '000000' };
const borders = { top: border, bottom: border, left: border, right: border };

// One text run in the document font and size. Takes the text and bold (default false); returns a TextRun.
const run = (text, bold = false) => new TextRun({ text, bold, font: FONT, size: SZ });
// One paragraph. Takes a run or a list of runs, the alignment (default left) and the space after in twips (default 0); returns a Paragraph.
const para = (runs, align = AlignmentType.LEFT, after = 0) =>
  new Paragraph({ alignment: align, spacing: { before: 0, after }, children: Array.isArray(runs) ? runs : [runs] });
// One bordered table cell. Takes the child paragraphs, the width in twips and opts (valign, span); returns a TableCell.
const cell = (children, width, opts = {}) => new TableCell({
  borders, width: { size: width, type: WidthType.DXA }, verticalAlign: opts.valign || VerticalAlign.CENTER,
  margins: { top: 0, bottom: 0, left: 60, right: 60 }, columnSpan: opts.span, children });

const headers = ['Item', 'Source', 'Type (*C/S/A)', 'Page', 'Para', 'Line #', 'Comment', 'Rationale', 'Resolution (**A/R/M)'];

const rows = [];
rows.push(new TableRow({ height: { value: Math.round(0.41 * IN), rule: HeightRule.ATLEAST }, children: [
  cell([para(run('[CLASSIFIED] [UNCLASSIFIED]', true), AlignmentType.CENTER),
        para(run('[SPFPD] [AFI] [DAFMAN] ETC', true), AlignmentType.CENTER)], total, { span: 9 })] }));
rows.push(new TableRow({ tableHeader: true, height: { value: Math.round(0.59 * IN), rule: HeightRule.ATLEAST },
  children: headers.map((h, i) => cell([para(run(h, true), AlignmentType.CENTER)], widths[i])) }));
for (let r = 0; r < 7; r++) {
  rows.push(new TableRow({ height: { value: Math.round(0.20 * IN), rule: HeightRule.ATLEAST },
    children: widths.map(w => cell([para(run(''))], w)) }));
}
const key = [
  para(run('* Comment Types:', true), AlignmentType.LEFT, 240),
  para([run('CRITICAL -- ', true), run('Critical comments address content containing violations of law or policy contradictions; content with the potential to create unnecessary risks to safety, life, limb, or DAF materiel or waste or abuse of DAF appropriations; content that imposes an unreasonable burden on DAF resources; or content raising similar issues. Critical comments result in a nonconcur.')], AlignmentType.LEFT, 240),
  para([run('SUBSTANTIVE -- ', true), run('Substantive comments address content that is unnecessary, incorrect, misleading, confusing, or inconsistent. A substantive comment is usually not sufficient justification for a nonconcur; however, several substantive comments, when taken together, may be grounds for a nonconcurrence. Coordinators nonconcurring with substantive comments alone must clearly indicate which comments are the basis for the nonconcur.')], AlignmentType.LEFT, 240),
  para([run('ADMINISTRATIVE -- ', true), run('Administrative comments address typographical, grammatical, or formatting errors.')], AlignmentType.LEFT, 240),
  para(run('** Resolution Actions:', true), AlignmentType.LEFT, 240),
  para(run('Accept/Reject/Accept with Modification (A/R/M) are to be used by the document sponsor for comment resolution/adjudication. This format will allow the document sponsor to accept, reject, or partially accept/reject or modify each comment.'), AlignmentType.LEFT, 120),
];
rows.push(new TableRow({ children: [cell(key, total, { span: 9, valign: VerticalAlign.TOP })] }));

const table = new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: widths, rows });
const note = para([run('Note: ', true), run('Source includes office symbol, first and last name, rank/grade, telephone number and e-mail address. The Resolution column is the Decision column required by DAFMAN 90-161, paragraph 5.3. (T-1)')], AlignmentType.LEFT, 0);

const doc = new Document({
  styles: { default: { document: { run: { font: FONT, size: SZ } } } },
  sections: [{ properties: { page: { size: { width: 12240, height: 15840 },
    margin: { top: IN, bottom: IN, left: IN, right: IN } } },
    children: [table, para(run(''), AlignmentType.LEFT, 120), note] }],
});
// Deterministic output: a rebuild from unchanged source is byte-identical, so tests/run.sh leaves git clean.
// One fixed instant for docProps/core.xml created/modified and every zip entry date.
// SOURCE_DATE_EPOCH (seconds, reproducible-builds.org) overrides the constant.
const FIXED_DATE = process.env.SOURCE_DATE_EPOCH
  ? new Date(Number(process.env.SOURCE_DATE_EPOCH) * 1000)
  : new Date('2026-11-11T00:00:00Z');
if (isNaN(FIXED_DATE)) { console.error(`SOURCE_DATE_EPOCH is not a number of seconds: ${process.env.SOURCE_DATE_EPOCH}`); process.exit(1); }
const STAMP = FIXED_DATE.toISOString().replace(/\.\d{3}Z$/, 'Z');

async function build() {
  // Packer.compiler.compile returns the JSZip instance that Packer.toBuffer would generate (docx 9.x).
  const zip = Packer.compiler.compile(doc);
  const core = (await zip.file('docProps/core.xml').async('string'))
    .replace(/(<dcterms:(created|modified)[^>]*>)[^<]*(<\/dcterms:\2>)/g, `$1${STAMP}$3`);
  zip.file('docProps/core.xml', core);
  for (const [name, entry] of Object.entries(zip.files)) {
    if (entry.dir) { delete zip.files[name]; continue; }   // drop folder entry only; zip.remove() would drop its files too
    entry.date = FIXED_DATE;
  }
  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE', platform: 'DOS',
    mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' });
}

const out = path.join(__dirname, 'CRM_A12-1.docx');
build().then(buf => { fs.writeFileSync(out, buf); console.log(`CRM written ${out} tableWidthDXA=${total} columns=${widths.length}`); })
  .catch(err => { console.error(err); process.exit(1); });
