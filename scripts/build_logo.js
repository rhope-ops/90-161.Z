// Renders assets/logo/90161Z-logo.svg (the master copy; the PFM, 2026-11-17) to PNGs in assets/logo/build/ (git-ignored).
// Sizes: 512 (site logo and thumbnail), 192 and 128 (app and window), 64, 32 and 16 (icons). Transparent outside the disc.
// The PNGs are not committed: the personal-data guard does not scan .png files. Change the SVG, never a PNG.
// Run: node scripts/build_logo.js [out-dir]. Needs Playwright with Chromium (preinstalled in cloud sessions; no package.json).
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const SVG = path.join(__dirname, '..', 'assets', 'logo', '90161Z-logo.svg');
const OUT = process.argv[2] || path.join(__dirname, '..', 'assets', 'logo', 'build');
const SIZES = [512, 192, 128, 64, 32, 16];

(async () => {
  const svg = fs.readFileSync(SVG, 'utf8');
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ deviceScaleFactor: 1 });
    for (const n of SIZES) {
      await page.setViewportSize({ width: n, height: n });
      const html = '<!doctype html><html><body style="margin:0;background:transparent">' +
        svg.replace(/<svg /, `<svg style="display:block;width:${n}px;height:${n}px" `) + '</body></html>';
      await page.setContent(html);
      const png = await page.screenshot({ omitBackground: true, clip: { x: 0, y: 0, width: n, height: n } });
      const out = path.join(OUT, `90161Z-logo-${n}.png`);
      fs.writeFileSync(out, png);
      console.log(`wrote ${out} (${png.length} bytes)`);
    }
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(2); });
