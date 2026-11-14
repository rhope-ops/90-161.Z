#!/usr/bin/env node
// UI measurement for the ui-verify skill (.claude/skills/ui-verify/SKILL.md).
// Usage: node measure.mjs <url-or-file> [out-dir]   (default out-dir: a new folder in the system temp dir, never the repo)
// For each width (375, 1440) and scheme (light, dark): saves a screenshot and checks
//   - horizontal page scroll (scrollWidth > viewport width)
//   - text contrast against WCAG AA (4.5:1, or 3:1 for large text: >= 24px, or >= 18.66px and bold)
//   - interactive targets smaller than 24x24 px
// Prints one line per case and the worst findings; exit 1 when any check fails.
// Contrast uses the nearest opaque background colour; text on images or gradients is listed as "unchecked".
// Needs Playwright (require('playwright') must resolve).
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('playwright')); } catch {
  try { ({ chromium } = require(require.resolve('playwright', { paths: [process.cwd(), '/usr/lib/node_modules', '/usr/local/lib/node_modules'] }))); }
  catch { console.error('Playwright not found: install it, or run where require("playwright") resolves.'); process.exit(2); }
}

const [target, outDir = `${tmpdir()}/ui-verify-${Date.now()}`] = process.argv.slice(2);  // default: outside the repo
if (!target) { console.error('Usage: node measure.mjs <url-or-file> [out-dir]'); process.exit(2); }
const url = /^[a-z]+:\/\//i.test(target) ? target : pathToFileURL(resolve(target)).href;
mkdirSync(outDir, { recursive: true });

function audit() {
  // Any CSS colour (rgb, rgba, oklch, lab, ...) to [r, g, b, a in 0..1], through a 1x1 canvas.
  const cx = document.createElement('canvas').getContext('2d', { willReadFrequently: true });
  const parse = (c) => { cx.clearRect(0, 0, 1, 1); cx.fillStyle = '#000'; cx.fillStyle = c; cx.fillRect(0, 0, 1, 1);
    const d = cx.getImageData(0, 0, 1, 1).data; return [d[0], d[1], d[2], d[3] / 255]; };  // getImageData is already un-premultiplied
  const blend = (fg, bg) => [0, 1, 2].map((i) => fg[i] * fg[3] + bg[i] * (1 - fg[3]));
  const alpha = (c) => c[3];
  const meta = document.querySelector('meta[name="color-scheme"]');
  const dark = matchMedia('(prefers-color-scheme: dark)').matches &&
    (/dark/.test(getComputedStyle(document.documentElement).colorScheme) ||
     (getComputedStyle(document.documentElement).colorScheme === 'normal' && /dark/.test(meta ? meta.content : '')));  // CSS wins over the meta tag
  const canvasBg = dark ? [18, 18, 18, 1] : [255, 255, 255, 1];
  const lum = ([r, g, b]) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
  const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
  const bgOf = (el) => {
    for (let e = el; e; e = e.parentElement) {
      const s = getComputedStyle(e);
      if (s.backgroundImage && s.backgroundImage !== 'none') return null;
      const c = parse(s.backgroundColor);
      if (alpha(c) >= 0.99) return c;
    }
    return canvasBg;
  };
  const visible = (el) => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' && Number(s.opacity) > 0; };
  const name = (el) => el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).join('.') : '');

  const TEXT_BLOCKS = new Set(['P', 'LI', 'TD', 'TH', 'DD', 'DT', 'BLOCKQUOTE', 'FIGCAPTION']);
  // WCAG 2.5.8 exempts a link inside a sentence: climb inline ancestors to the nearest block; it must be a text block,
  // outside navigation, with at least 3 letters or digits outside links, script and style; never a link around an image.
  const inSentence = (a) => {
    if (getComputedStyle(a).display !== 'inline') return false;
    let b = a.parentElement;
    while (b && getComputedStyle(b).display === 'inline') b = b.parentElement;
    if (!b || !TEXT_BLOCKS.has(b.tagName) || b.closest('nav,[role=navigation],menu')) return false;
    if (a.querySelector('img,svg,picture')) return false;  // an image link is sized by the image, not the line
    const tw = document.createTreeWalker(b, NodeFilter.SHOW_TEXT);
    let txt = '';
    for (let n = tw.nextNode(); n; n = tw.nextNode()) if (!n.parentElement.closest('a,script,style')) txt += n.textContent;
    return (txt.match(/[\p{L}\p{N}]/gu) || []).length >= 3;  // letters or digits, not separators like " | " 
  };
  const contrast = [], unchecked = [], targets = [];
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const seen = new Set();
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    const el = n.parentElement;
    if (!el || seen.has(el) || !n.textContent.trim() || !visible(el)) continue;
    seen.add(el);
    const s = getComputedStyle(el);
    const bg = bgOf(el);
    if (!bg) { unchecked.push(name(el)); continue; }
    const fg = blend(parse(s.color), bg);
    const size = parseFloat(s.fontSize), bold = Number(s.fontWeight) >= 700;
    const need = size >= 24 || (size >= 18.66 && bold) ? 3 : 4.5;
    const r = ratio(fg, bg);
    if (r < need) contrast.push({ el: name(el), ratio: +r.toFixed(2), need, text: n.textContent.trim().slice(0, 30) });
  }
  for (const el of document.querySelectorAll('a[href], button, input:not([type=hidden]), select, textarea, [role=button], [tabindex]:not([tabindex="-1"])')) {
    if (!visible(el)) continue;
    if (el.tagName === 'A' && inSentence(el)) continue;
    const r = el.getBoundingClientRect();
    if (r.width < 24 || r.height < 24) targets.push({ el: name(el), w: Math.round(r.width), h: Math.round(r.height) });
  }
  const overflow = document.documentElement.scrollWidth - window.innerWidth;
  return { contrast, unchecked, targets, overflow };
}

const browser = await chromium.launch();
let failed = false;
try {
  for (const width of [375, 1440]) {
    for (const scheme of ['light', 'dark']) {
      const page = await browser.newPage({ viewport: { width, height: 900 }, colorScheme: scheme, deviceScaleFactor: 1, reducedMotion: 'reduce' });
      await page.goto(url, { waitUntil: 'load' });
      const shot = `${outDir}/${width}-${scheme}.png`;
      await page.screenshot({ path: shot, fullPage: true });
      const r = await page.evaluate(audit);
      const bad = r.contrast.length + r.targets.length + (r.overflow > 0 ? 1 : 0);
      if (bad) failed = true;
      console.log(`${bad ? 'FAIL' : 'PASS'}  ${width}px ${scheme}: contrast fails ${r.contrast.length}, small targets ${r.targets.length}, ` +
        `horizontal overflow ${Math.max(r.overflow, 0)} px, unchecked text ${r.unchecked.length} · ${shot}`);
      for (const c of r.contrast.sort((a, b) => a.ratio - b.ratio).slice(0, 5)) console.log(`      contrast ${c.ratio}:1 (need ${c.need}:1) ${c.el} "${c.text}"`);
      for (const t of r.targets.slice(0, 5)) console.log(`      target ${t.w}x${t.h} px ${t.el}`);
      for (const u of r.unchecked.slice(0, 3)) console.log(`      unchecked (image or gradient background) ${u}`);
      await page.close();
    }
  }
} finally { await browser.close(); }
console.log(failed ? 'UI MEASURE FAIL' : 'UI MEASURE PASS');
process.exit(failed ? 1 : 0);
