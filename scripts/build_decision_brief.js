// Builds the decision briefs (PFM 2026-11-12: decisions logged, risks shown in PowerPoint; split into an installer
// brief for PFMs and a command brief for commanders). Each deck is docs/brief/<deck>.json: a list of typed slides.
// Both decks read one risk register, docs/brief/risks.json. Never hand-edit a .pptx; change the JSON and run:
//   NODE_PATH=$(npm root -g):$(npm root -g)/pptxgenjs/node_modules node scripts/build_decision_brief.js [deck ...]
// No deck names = every docs/brief/*.json except risks.json. Needs pptxgenjs 3.12.0 (npm install -g pptxgenjs@3.12.0).
const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");
const JSZip = require("jszip");

const root = path.join(__dirname, "..");
const dir = path.join(root, "docs/brief");
const ALL_RISKS = JSON.parse(fs.readFileSync(path.join(dir, "risks.json"), "utf8"));
const DECKS = fs.readdirSync(dir).filter(f => f.endsWith(".json") && f !== "risks.json").map(f => f.replace(/\.json$/, ""));
for (const r of ALL_RISKS) for (const n of r.hideIn || []) if (!DECKS.includes(n)) throw new Error(r.id + ": hideIn names unknown deck " + n);
// "{decisions}" in any slide text = dated PFM rows in docs/DECISIONS.md (column "By" starts with PFM), counted at build.
const DECISIONS = fs.readFileSync(path.join(root, "docs/DECISIONS.md"), "utf8").split("\n")
  .filter(l => /^\| 20\d\d-/.test(l) && /^PFM/.test((l.split("|")[3] || "").trim())).length;

// Colors come from docs/palette.json (PFM 1A, 12 Nov 26), the one palette for the briefs and the app theme.
const T = JSON.parse(fs.readFileSync(path.join(root, "docs/palette.json"), "utf8")).tokens;
const HEX = { navy: T.primary, red: T.red, amber: T.amber, green: T.green, slate: T.muted, grey: T.grey,
  pale: T.surface, ink: T.ink, white: T.white, mist: T.mist, line: T.line, out: T.surfaceOut,
  redT: T.redTint, amberT: T.amberTint, greenT: T.greenTint, greyT: T.greyTint,
  warning: T.warning, accent: T.accentFill, onAccent: T.onAccentFill, onNavyMuted: T.onPrimaryMuted };
const W = 13.333, M = 0.6, CW = W - 2 * M;
const lv = { L: 0, M: 1, H: 2 };
const sevColor = { H: HEX.red, M: HEX.amber, L: HEX.green };
const tone = { red: [HEX.red, HEX.redT], amber: [HEX.amber, HEX.amberT], green: [HEX.green, HEX.greenT], grey: [HEX.grey, HEX.greyT] };

// Reads one deck file docs/brief/<deckName>.json and fills in "{decisions}". Takes the deck name; returns the deck object.
function readDeck(deckName) {
  return JSON.parse(fs.readFileSync(path.join(dir, deckName + ".json"), "utf8").split("{decisions}").join(String(DECISIONS)));
}

// Defines the two slide masters (DARK for title and closing slides, CONTENT for the rest). Takes the presentation and the deck object; returns nothing.
function defineMasters(pres, B) {
  // One marking line (text B.marking, centered) at height y in the given color.
  const mark = (y, color) => ({ text: { text: B.marking, options: { x: 0, y, w: W, h: 0.3, align: "center", fontSize: 10, bold: true, color } } });
  pres.defineSlideMaster({ title: "DARK", background: { color: HEX.navy }, objects: [mark(0.05, HEX.white), mark(7.15, HEX.white),
    { placeholder: { options: { name: "title", type: "title", x: M, y: 1.9, w: CW, h: 1.7, fontFace: "Cambria", fontSize: 40, bold: true, color: HEX.white, valign: "bottom" }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: M, y: 3.8, w: CW, h: 2.9, fontSize: 18, color: HEX.onNavyMuted, valign: "top" }, text: "" } }] });
  pres.defineSlideMaster({ title: "CONTENT", background: { color: HEX.white }, margin: [0.9, M, 0.7, M], objects: [mark(0.05, HEX.ink), mark(7.15, HEX.ink),
    { placeholder: { options: { name: "title", type: "title", x: M, y: 0.4, w: CW, h: 0.9, fontFace: "Cambria", fontSize: 30, bold: true, color: HEX.navy, valign: "middle" }, text: "" } },
    { text: { text: B.footer, options: { x: M, y: 6.85, w: 8, h: 0.3, fontSize: 10, color: HEX.slate } } }],
    slideNumber: { x: W - M - 0.6, y: 6.85, w: 0.6, h: 0.3, fontSize: 10, color: HEX.slate, align: "right" } });
}

// Risk sort key: higher likelihood plus impact sorts first, impact breaks ties. Takes a risk; returns a number (smaller = earlier).
function order(r) {
  return -(lv[r.l] + lv[r.i]) * 10 - lv[r.i];
}

// Builds the drawing helpers one deck uses. Takes the presentation, the deck object, the deck's risks and the deck name;
// returns a context object (slide, txt, card, th, td, table, bullets, lead, pick, pres, RISKS, and fs = the table font size a slide may set).
function makeContext(pres, B, RISKS, deckName) {
  const ctx = { pres, RISKS, fs: 12 };
  let sec = "";
  // Adds a slide on a master, opening a new PowerPoint section when the section name changes. Returns the slide.
  ctx.slide = (master, section) => {
    if (section && section !== sec) { pres.addSection({ title: section }); sec = section; }
    return pres.addSlide({ masterName: master, sectionTitle: sec });
  };
  // Adds a text box with default font, color and margin; o overrides them.
  ctx.txt = (s, text, o) => s.addText(text, Object.assign({ isTextBox: true, fontSize: 14, color: HEX.ink, valign: "top", margin: 0.05 }, o));
  // Adds a rounded rectangle in one fill color with an object name.
  ctx.card = (s, x, y, w, h, fill, name) => s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.08, fill: { color: fill }, line: { color: fill }, objectName: name });
  // Table header cell: bold white text on navy.
  ctx.th = (t) => ({ text: t, options: { bold: true, color: HEX.white, fill: { color: HEX.navy }, fontSize: ctx.fs } });
  // Table body cell: text as a string; o overrides the default options.
  ctx.td = (t, o) => ({ text: String(t), options: Object.assign({ fontSize: ctx.fs, color: HEX.ink, valign: "top" }, o) });
  // Adds a full-width table (head cells, row cells, relative column widths colW, top y); extra overrides the table options.
  ctx.table = (s, head, rows, colW, y, extra) => s.addTable([head.map(ctx.th), ...rows], Object.assign({ x: M, y, w: CW, colW: colW.map(c => c * CW / colW.reduce((a, b) => a + b)), border: { type: "solid", color: HEX.line, pt: 0.75 }, margin: 0.05 }, extra || {}));
  // Turns a list of strings into bullet (or numbered) paragraphs for addText.
  ctx.bullets = (items, numbered) => items.map((t, k) => ({ text: t, options: { bullet: numbered ? { type: "number" } : true, breakLine: k < items.length - 1, paraSpaceAfter: 6 } }));
  // Adds the lead line under a slide title when t is given.
  ctx.lead = (s, t) => t && ctx.txt(s, t, { x: M, y: 1.3, w: CW, h: 0.5, fontSize: 14, color: HEX.slate });
  // Looks up risks by id in this deck's risks; an unknown id stops the build.
  ctx.pick = (ids) => ids.map(id => { const r = RISKS.find(x => x.id === id); if (!r) throw new Error(deckName + ": unknown risk " + id); return r; });
  return ctx;
}

// Opening slide: a dark title slide with the deck title and subtitle. Takes the deck context ctx and the slide data d.
function renderTitle(ctx, d) {
  const { slide } = ctx;
  const s = slide("DARK", d.section);
  s.addText(d.title, { placeholder: "title" });
  s.addText(d.subtitle, { placeholder: "body" });
  return s;
}

// Closing slide: a dark slide with a numbered list of next steps. Takes the deck context ctx and the slide data d.
function renderClose(ctx, d) {
  const { slide, bullets } = ctx;
  const s = slide("DARK", d.section);
  s.addText(d.title, { placeholder: "title" });
  s.addText(bullets(d.items, true), { placeholder: "body" });
  return s;
}

// Question slide: facts, then (if the slide has choices) Yes / No / Pending cards, the recommended one outlined. Takes the deck context ctx and the slide data d.
function renderAsk(ctx, d) {
  const { pres, slide, txt, bullets } = ctx;
  // One question per slide (PFM 12 Nov: 1-2 concepts per commander slide, each answered Yes, No or Pending evaluation).
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const fh = d.choices ? 2.1 : 4.6;
  s.addText(bullets(d.facts), { isTextBox: true, x: M, y: 1.45, w: CW, h: fh, fontSize: 20, color: HEX.ink, valign: "top", paraSpaceAfter: 10 });
  if (d.choices) {
    const kinds = [["Yes", HEX.green, HEX.greenT], ["No", HEX.red, HEX.redT], ["Pending evaluation", HEX.grey, HEX.greyT]];
    const cw = (CW - 0.6) / 3, y = 3.75, h = 2.75;
    kinds.forEach(([k, fg, bg], i) => {
      const x = M + i * (cw + 0.3), rec = d.rec === k;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: cw, h, rectRadius: 0.08, fill: { color: bg }, line: { color: rec ? HEX.navy : bg, width: rec ? 3 : 1 }, objectName: "choice-" + i });
      txt(s, k, { x: x + 0.25, y: y + 0.2, w: cw - 0.5, h: 0.55, fontSize: 24, bold: true, color: fg });
      txt(s, d.choices[i], { x: x + 0.25, y: y + 0.85, w: cw - 0.5, h: 1.3, fontSize: 16 });
      if (rec) txt(s, "Recommended", { x: x + 0.25, y: y + h - 0.55, w: cw - 0.5, h: 0.4, fontSize: 14, bold: true, color: HEX.navy });
    });
  }
  return s;
}

// Answer sheet: a numbered question table with empty Yes / No / Pending check boxes. Takes the deck context ctx and the slide data d.
function renderSheet(ctx, d) {
  const { slide, txt, th, td } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const box = "\u2610";
  s.addTable([["#", "Question", "Yes", "No", "Pending evaluation"].map(th), ...d.rows.map((q, i) => [td(String(i + 1), { bold: true }), td(q), td(box, { align: "center", fontSize: 20 }), td(box, { align: "center", fontSize: 20 }), td(box, { align: "center", fontSize: 20 })])],
    { x: M, y: 1.45, w: CW, colW: [0.5, 7.4, 1.1, 1.1, CW - 10.1], border: { type: "solid", color: HEX.line, pt: 0.75 }, margin: 0.06 });
  if (d.note) txt(s, d.note, { x: M, y: 6.25, w: CW, h: 0.5, fontSize: 14, color: HEX.slate, italic: true });
  return s;
}

// Number cards in a row, then a numbered list under them. Takes the deck context ctx and the slide data d.
function renderStats(ctx, d) {
  const { slide, txt, card, bullets } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const n = d.cards.length, cw = (CW - 0.3 * (n - 1)) / n;
  d.cards.forEach((c, i) => {
    const x = M + i * (cw + 0.3); card(s, x, 1.45, cw, 2.15, HEX.pale, "stat-" + i);
    txt(s, c.big, { x: x + 0.25, y: 1.6, w: cw - 0.5, h: 0.95, fontSize: c.big.length > 6 ? 34 : 48, bold: true, fontFace: "Cambria", color: HEX[c.color || "navy"] });
    txt(s, c.label, { x: x + 0.25, y: 2.55, w: cw - 0.5, h: 0.95, fontSize: 14 });
  });
  txt(s, d.listTitle, { x: M, y: 3.85, w: CW, h: 0.4, fontSize: 20, bold: true, color: HEX.navy });
  s.addText(bullets(d.list, true), { isTextBox: true, x: M, y: 4.3, w: CW, h: 2.4, fontSize: 15, color: HEX.ink, valign: "top" });
  return s;
}

// Process stages as arrows (some highlighted), a key line, then three cards. Takes the deck context ctx and the slide data d.
function renderStages(ctx, d) {
  const { pres, slide, txt, card } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  txt(s, d.lead, { x: M, y: 1.35, w: CW, h: 0.7, fontSize: 15 });
  const n = d.stages.length, gap = 0.08, cw = (CW - gap * (n - 1)) / n;
  d.stages.forEach((t, i) => {
    const x = M + i * (cw + gap);
    s.addText(String(i), { shape: pres.shapes.PENTAGON, x, y: 2.35, w: cw, h: 0.8, fill: { color: (d.highlight || []).includes(i) ? HEX.accent : HEX.navy },
      line: { color: HEX.white }, objectName: "stage-" + i, fontSize: 18, bold: true, color: (d.highlight || []).includes(i) ? HEX.onAccent : HEX.white, align: "center", valign: "middle", margin: 0 });
    txt(s, t, { x: x - 0.02, y: 3.3, w: cw + 0.04, h: 1.0, fontSize: 11, align: "center" });
  });
  txt(s, d.key, { x: M, y: 4.4, w: CW, h: 0.4, fontSize: 11, color: HEX.slate, italic: true });
  const cw2 = (CW - 0.6) / 3;
  d.cards.forEach((u, i) => {
    const x = M + i * (cw2 + 0.3); card(s, x, 4.95, cw2, 1.75, HEX.pale, "card-" + i);
    txt(s, u.head, { x: x + 0.2, y: 5.05, w: cw2 - 0.4, h: 0.4, fontSize: 16, bold: true, color: HEX.navy });
    txt(s, u.body, { x: x + 0.2, y: 5.45, w: cw2 - 0.4, h: 1.2, fontSize: 13 });
  });
  return s;
}

// Architecture picture: boxes inside the boundary on the left, boxes outside it (dashed) on the right. Takes the deck context ctx and the slide data d.
function renderArch(ctx, d) {
  const { pres, slide, txt, card } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  card(s, M, 1.4, 7.7, 5.2, HEX.pale, "zone-in");
  txt(s, d.inTitle, { x: M + 0.2, y: 1.5, w: 7.3, h: 0.4, fontSize: 15, bold: true, color: HEX.navy });
  d.inside.forEach((b, i) => {
    const x = M + 0.25 + (i % 2) * 3.65, y = 2.0 + Math.floor(i / 2) * 1.5;
    s.addShape(pres.shapes.RECTANGLE, { x, y, w: 3.45, h: 1.3, fill: { color: HEX.white }, line: { color: HEX.line, width: 1 }, objectName: "in-" + i });
    txt(s, b[0], { x: x + 0.12, y: y + 0.08, w: 3.2, h: 0.4, fontSize: 14, bold: true, color: HEX.navy });
    txt(s, b[1], { x: x + 0.12, y: y + 0.48, w: 3.2, h: 0.8, fontSize: 12 });
  });
  const ox = M + 8.0, ow = W - M - ox;
  card(s, ox, 1.4, ow, 5.2, HEX.out, "zone-out");
  txt(s, d.outTitle, { x: ox + 0.2, y: 1.5, w: ow - 0.4, h: 0.4, fontSize: 15, bold: true, color: HEX.slate });
  d.outside.forEach((b, i) => {
    const y = 2.0 + i * 1.5;
    s.addShape(pres.shapes.RECTANGLE, { x: ox + 0.2, y, w: ow - 0.4, h: 1.3, fill: { color: HEX.white }, line: { color: HEX.line, width: 1, dashType: "dash" }, objectName: "out-" + i });
    txt(s, b[0], { x: ox + 0.32, y: y + 0.08, w: ow - 0.64, h: 0.4, fontSize: 14, bold: true, color: HEX.slate });
    txt(s, b[1], { x: ox + 0.32, y: y + 0.48, w: ow - 0.64, h: 0.8, fontSize: 12 });
  });
  return s;
}

// Step cards in a row, with an optional table under them. Takes the deck context ctx and the slide data d.
function renderSteps(ctx, d) {
  const { slide, txt, card, td, table } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const n = d.steps.length, gw = (CW - 0.3 * (n - 1)) / n;
  d.steps.forEach((p, i) => {
    const x = M + i * (gw + 0.3); card(s, x, 1.45, gw, 2.3, HEX.pale, "step-" + i);
    txt(s, p[0], { x: x + 0.2, y: 1.55, w: gw - 0.4, h: 0.5, fontSize: 24, bold: true, fontFace: "Cambria", color: HEX.warning });
    txt(s, p[1], { x: x + 0.2, y: 2.05, w: gw - 0.4, h: 0.4, fontSize: 15, bold: true, color: HEX.navy });
    txt(s, p[2], { x: x + 0.2, y: 2.45, w: gw - 0.4, h: 1.25, fontSize: 12 });
  });
  if (d.table) table(s, d.table.head, d.table.rows.map(r => r.map(c => td(c))), d.table.colW, 3.95);
  return s;
}

// Two cards side by side with bullets, an optional flow strip and an optional rule line. Takes the deck context ctx and the slide data d.
function renderTwoCol(ctx, d) {
  const { pres, slide, txt, card, bullets } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const colW = (CW - 0.4) / 2;
  d.cols.forEach((c, i) => {
    const x = M + i * (colW + 0.4); card(s, x, 1.45, colW, 2.6, HEX.pale, "col-" + i);
    txt(s, c.head, { x: x + 0.25, y: 1.55, w: colW - 0.5, h: 0.45, fontSize: 18, bold: true, color: HEX[c.color || "navy"] });
    s.addText(bullets(c.items), { isTextBox: true, x: x + 0.25, y: 2.05, w: colW - 0.5, h: 1.9, fontSize: 14, color: HEX.ink, valign: "top" });
  });
  if (d.flow) {
    const n = d.flow.length, sw = (CW - 0.25 * (n - 1)) / n;
    d.flow.forEach((t, i) => {
      const x = M + i * (sw + 0.25);
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 4.35, w: sw, h: 1.25, rectRadius: 0.08, fill: { color: HEX.navy }, line: { color: HEX.navy }, objectName: "flow-" + i });
      txt(s, (i + 1) + ". " + t, { x: x + 0.12, y: 4.42, w: sw - 0.24, h: 1.12, fontSize: 13, color: HEX.white, valign: "middle" });
    });
  }
  if (d.rule) txt(s, d.rule, { x: M, y: d.flow ? 5.85 : 4.35, w: CW, h: 0.8, fontSize: 14, bold: true, color: HEX.navy });
  return s;
}

// One big number card on the left and a two-column table on the right. Takes the deck context ctx and the slide data d.
function renderStatTable(ctx, d) {
  const { slide, txt, card, th, td } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  card(s, M, 1.45, 3.2, 3.9, HEX.navy, "big");
  txt(s, d.big, { x: M + 0.25, y: 1.7, w: 2.7, h: 1.1, fontSize: 60, bold: true, fontFace: "Cambria", color: HEX.white });
  txt(s, d.bigLabel, { x: M + 0.25, y: 2.85, w: 2.7, h: 2.3, fontSize: 14, color: HEX.onNavyMuted });
  s.addTable([d.head.map(th), ...d.rows.map(r => [td(r[0], { bold: true, color: HEX.navy }), td(r[1])])],
    { x: M + 3.5, y: 1.45, w: CW - 3.5, colW: [2.1, CW - 5.6], border: { type: "solid", color: HEX.line, pt: 0.75 }, margin: 0.06 });
  return s;
}

// Plain table slide with an optional lead line and note; the first and recommended columns are bold. Takes the deck context ctx and the slide data d.
function renderTable(ctx, d) {
  const { slide, txt, td, table, lead } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" }); lead(s, d.lead);
  const rows = d.rows.map(r => r.map((c, k) => td(c, k === 0 || k === d.recCol ? { bold: true, color: HEX.navy } : {})));
  table(s, d.head, rows, d.colW, d.lead ? 1.85 : 1.4);
  if (d.note) txt(s, d.note, { x: M, y: 6.3, w: CW, h: 0.45, fontSize: 12, color: HEX.slate, italic: true });
  return s;
}

// Status table: the second column of each row picks a tone (red, amber, green, grey) that colors the status cell. Takes the deck context ctx and the slide data d.
function renderStatus(ctx, d) {
  const { slide, txt, td, table, lead } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" }); lead(s, d.lead);
  const rows = d.rows.map(r => { const [fg, bg] = tone[r[1]]; return [td(r[0], { bold: true, color: HEX.navy }), td(r[2], { bold: true, color: fg, fill: { color: bg } }), td(r[3])]; });
  table(s, d.head, rows, d.colW, d.lead ? 1.85 : 1.4);
  if (d.note) txt(s, d.note, { x: M, y: 6.3, w: CW, h: 0.45, fontSize: 12, color: HEX.slate, italic: true });
  return s;
}

// Two cards: reasons for (green) and against (red), as bullets. Takes the deck context ctx and the slide data d.
function renderProcon(ctx, d) {
  const { slide, txt, card, bullets } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const colW = (CW - 0.4) / 2;
  [["For", d.pros, "green"], ["Against", d.cons, "red"]].forEach(([h, items, col], i) => {
    const x = M + i * (colW + 0.4); card(s, x, 1.45, colW, 5.1, HEX.pale, "pc-" + i);
    txt(s, h, { x: x + 0.25, y: 1.55, w: colW - 0.5, h: 0.45, fontSize: 20, bold: true, color: HEX[col] });
    s.addText(bullets(items), { isTextBox: true, x: x + 0.25, y: 2.1, w: colW - 0.5, h: 4.3, fontSize: 14, color: HEX.ink, valign: "top" });
  });
  return s;
}

// Risk heat map: a 3 x 3 likelihood and impact grid of risk ids, with a reading key on the right. Takes the deck context ctx and the slide data d.
function renderHeat(ctx, d) {
  const { pres, slide, txt, bullets, RISKS } = ctx;
  const s = slide("CONTENT", d.section);
  s.addText(d.title.replace("{hh}", RISKS.filter(r => r.l === "H" && r.i === "H").length), { placeholder: "title" });
  const gx = M + 1.0, gy = 1.45, cw = 2.55, ch = 1.5;
  for (let li = 0; li < 3; li++) for (let ii = 0; ii < 3; ii++) {
    const x = gx + ii * cw, y = gy + (2 - li) * ch;
    s.addShape(pres.shapes.RECTANGLE, { x, y, w: cw - 0.06, h: ch - 0.06, fill: { color: li + ii >= 3 ? HEX.redT : li + ii >= 2 ? HEX.amberT : HEX.greenT }, line: { color: HEX.white }, objectName: `heat-${li}-${ii}` });
    txt(s, RISKS.filter(r => lv[r.l] === li && lv[r.i] === ii).map(r => r.id).join("  "), { x: x + 0.1, y: y + 0.1, w: cw - 0.26, h: ch - 0.26, fontSize: 13, bold: true, valign: "middle", align: "center" });
  }
  ["Low", "Medium", "High"].forEach((t, k) => {
    txt(s, t, { x: gx + k * cw, y: gy + 3 * ch + 0.02, w: cw, h: 0.3, fontSize: 12, align: "center", color: HEX.slate });
    txt(s, t, { x: M, y: gy + (2 - k) * ch + ch / 2 - 0.15, w: 0.95, h: 0.3, fontSize: 12, align: "right", color: HEX.slate });
  });
  txt(s, "Impact", { x: gx, y: gy + 3 * ch + 0.32, w: 3 * cw, h: 0.3, fontSize: 12, bold: true, align: "center", color: HEX.slate });
  txt(s, "Likelihood", { x: M, y: gy + 0.05, w: 0.95, h: 0.3, fontSize: 12, bold: true, align: "right", color: HEX.slate });
  const kx = gx + 3 * cw + 0.3, kw = W - M - kx;
  txt(s, "How to read it", { x: kx, y: gy, w: kw, h: 0.4, fontSize: 16, bold: true, color: HEX.navy });
  s.addText(bullets(d.key), { isTextBox: true, x: kx, y: gy + 0.45, w: kw, h: 4.3, fontSize: 13, color: HEX.ink, valign: "top" });
  return s;
}

// Risk table slides (several risks per slide, worst first); returns the first slide. Takes the deck context ctx and the slide data d.
function renderRisks(ctx, d) {
  const { slide, td, table, pick, RISKS } = ctx;
  const list = (d.ids ? pick(d.ids) : RISKS.slice()).sort((a, b) => order(a) - order(b));
  const per = d.per || 6; let first;
  for (let k = 0; k < list.length; k += per) {
    const s = slide("CONTENT", d.section); first = first || s;
    s.addText(list.length > per ? `${d.title} (${Math.floor(k / per) + 1} of ${Math.ceil(list.length / per)})` : d.title, { placeholder: "title" });
    const rows = list.slice(k, k + per).map(r => [td(r.id, { bold: true }), td(d.plain ? r.plain : r.risk), td(r.l, { bold: true, color: sevColor[r.l], align: "center" }),
      td(r.i, { bold: true, color: sevColor[r.i], align: "center" }), td(d.plain ? r.plainMit : r.mit), td(r.owner)]);
    table(s, ["ID", d.plain ? "What could go wrong" : "Risk", "L", "I", d.plain ? "What we do about it" : "What reduces it", "Owner"], rows, [0.6, 4.3, 0.4, 0.4, 4.4, 2.0], 1.4);
  }
  return first;
}

// Risk appendix: every risk in this deck sorted by id, eight per slide; returns nothing (no notes). Takes the deck context ctx and the slide data d.
function renderRiskAppendix(ctx, d) {
  const { slide, td, table, RISKS } = ctx;
  const byId = RISKS.slice().sort((a, b) => a.id.localeCompare(b.id)), per = 8;
  for (let k = 0; k < byId.length; k += per) {
    const s = slide("CONTENT", d.section);
    s.addText(`${d.title} (${byId[k].id}-${byId[Math.min(k + per, byId.length) - 1].id})`, { placeholder: "title" });
    table(s, ["ID", "Area", "Risk", "L", "I", "Response", "Status"], byId.slice(k, k + per).map(r => [td(r.id, { bold: true }), td(r.area), td(r.risk),
      td(r.l, { color: sevColor[r.l], bold: true, align: "center" }), td(r.i, { color: sevColor[r.i], bold: true, align: "center" }), td(r.mit), td(r.status)]),
      [0.55, 1.3, 4.0, 0.35, 0.35, 4.0, 1.0], 1.35);
  }
}

// Option cards in a row; the recommended option is dark. Takes the deck context ctx and the slide data d.
function renderOptions(ctx, d) {
  const { slide, txt, card } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const n = d.options.length, cw = (CW - 0.3 * (n - 1)) / n;
  d.options.forEach((o, i) => {
    const x = M + i * (cw + 0.3), rec = !!o.rec, fg = rec ? HEX.white : HEX.ink;
    card(s, x, 1.45, cw, 4.1, rec ? HEX.navy : HEX.pale, "opt-" + i);
    txt(s, o.name + (rec ? "  (recommended)" : ""), { x: x + 0.25, y: 1.6, w: cw - 0.5, h: 0.7, fontSize: 17, bold: true, color: rec ? HEX.white : HEX.navy });
    txt(s, o.what, { x: x + 0.25, y: 2.3, w: cw - 0.5, h: 1.0, fontSize: 13, color: fg });
    txt(s, "For: " + o.pro, { x: x + 0.25, y: 3.3, w: cw - 0.5, h: 1.0, fontSize: 13, color: fg });
    txt(s, "Against: " + o.con, { x: x + 0.25, y: 4.35, w: cw - 0.5, h: 1.1, fontSize: 13, color: fg });
  });
  if (d.note) txt(s, d.note, { x: M, y: 5.75, w: CW, h: 0.5, fontSize: 13, color: HEX.slate, italic: true });
  return s;
}

// Roadmap: a line with one milestone per phase, each with a description and a gate. Takes the deck context ctx and the slide data d.
function renderRoadmap(ctx, d) {
  const { pres, slide, txt, card } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  const n = d.phases.length, pw = (CW - 0.2 * (n - 1)) / n;
  s.addShape(pres.shapes.LINE, { x: M, y: 2.05, w: CW, h: 0, line: { color: HEX.mist, width: 2 } });
  d.phases.forEach((p, i) => {
    const x = M + i * (pw + 0.2), now = p.state === "now";
    s.addShape(pres.shapes.OVAL, { x: x + pw / 2 - 0.2, y: 1.85, w: 0.4, h: 0.4, fill: { color: now ? HEX.accent : HEX.navy }, line: { color: HEX.white, width: 2 }, objectName: "ms-" + i });
    txt(s, p.name + (now ? " (now)" : ""), { x, y: 2.4, w: pw, h: 0.75, fontSize: 15, bold: true, color: HEX.navy, align: "center" });
    card(s, x, 3.2, pw, 1.9, HEX.pale, "ph-" + i);
    txt(s, p.what, { x: x + 0.15, y: 3.3, w: pw - 0.3, h: 1.75, fontSize: 12 });
    txt(s, "Gate: " + p.gate, { x: x + 0.05, y: 5.25, w: pw - 0.1, h: 1.3, fontSize: 12, bold: true, color: HEX.warning });
  });
  return s;
}

// Sources table (record and public address) with a method note. Takes the deck context ctx and the slide data d.
function renderSources(ctx, d) {
  const { slide, txt, th, td } = ctx;
  const s = slide("CONTENT", d.section); s.addText(d.title, { placeholder: "title" });
  s.addTable([[th("Record"), th("Address (public, no government data)")], ...d.rows.map(r => [td(r[0], { bold: true }), td(r[1], { fontSize: 11 })])],
    { x: M, y: 1.4, w: CW, colW: [3.4, CW - 3.4], border: { type: "solid", color: HEX.line, pt: 0.75 }, margin: 0.06 });
  txt(s, d.method, { x: M, y: 5.0, w: CW, h: 1.6, fontSize: 12, color: HEX.slate });
  return s;
}

// Maps a slide "type" in the deck JSON to the function that draws it.
const RENDERERS = {
  title: renderTitle,
  close: renderClose,
  ask: renderAsk,
  sheet: renderSheet,
  stats: renderStats,
  stages: renderStages,
  arch: renderArch,
  steps: renderSteps,
  twoCol: renderTwoCol,
  statTable: renderStatTable,
  table: renderTable,
  status: renderStatus,
  procon: renderProcon,
  heat: renderHeat,
  risks: renderRisks,
  riskAppendix: renderRiskAppendix,
  options: renderOptions,
  roadmap: renderRoadmap,
  sources: renderSources,
};

// Drops ZIP folder entries from the written file: files with them can fail to open from SharePoint or OneDrive.
// Takes the output path; returns a promise.
async function stripZipFolders(out) {
  const zin = await JSZip.loadAsync(fs.readFileSync(out)), zout = new JSZip();
  for (const [n, f] of Object.entries(zin.files)) if (!f.dir) zout.file(n, await f.async("nodebuffer"), { createFolders: false });
  fs.writeFileSync(out, await zout.generateAsync({ type: "nodebuffer", compression: "DEFLATE", mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation" }));
}

// Builds one deck: reads docs/brief/<deckName>.json, draws every slide and writes the .pptx named in the deck's "file".
// Takes the deck name; returns a promise.
function build(deckName) {
  const B = readDeck(deckName);
  // A deck shows only the risks in its scope ("wing" deck: wing + both; "ang" deck: ang + both). Default scope = wing.
  // A risk with "hideIn": [deck names] is left out of those decks (R02 off the command brief, PFM 2026-11-12).
  const scope = B.scope || "wing";
  const RISKS = ALL_RISKS.filter(r => [scope, "both"].includes(r.scope || "wing") && !(r.hideIn || []).includes(deckName));
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 in
  pres.title = B.title; pres.subject = "Decision brief"; pres.author = "90-161.Z project";
  pres.theme = { headFontFace: "Cambria", bodyFontFace: "Calibri" };
  defineMasters(pres, B);
  const ctx = makeContext(pres, B, RISKS, deckName);
  B.slides.forEach((d, i) => {
    if (!RENDERERS[d.type]) throw new Error(`${deckName}: slide ${i + 1} has unknown type ${d.type}`);
    ctx.fs = d.fs || 12;
    const s = RENDERERS[d.type](ctx, d);
    if (s && d.notes) s.addNotes(d.notes);
  });
  const out = path.join(root, B.file);
  return pres.writeFile({ fileName: out }).then(async () => {
    await stripZipFolders(out);
    console.log("wrote " + B.file);
  });
}

// Entry point: builds the decks named on the command line, or every deck when none is named.
(async () => {
  const names = process.argv.slice(2).length ? process.argv.slice(2)
    : fs.readdirSync(dir).filter(f => f.endsWith(".json") && f !== "risks.json").map(f => f.replace(/\.json$/, ""));
  for (const n of names) await build(n);
})().catch(e => { console.error(e.message); process.exit(1); });
