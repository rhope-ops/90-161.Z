// check_go_page.js: tests the go.md renderer of the bookmark page (index.html) in node, with no browser.
// Loads the page script with window.GO_TEST set, so the script exposes parse() and renderSecs() and draws nothing.
// Pass = last line "GO PAGE PASS"; exit 1 on any failure. Run: node tests/check_go_page.js
// Network: none.
// Writes: none (the page script runs in memory with fake go.md text).
// Credentials: none.
'use strict';
const fs = require('fs');
const vm = require('vm');
const path = require('path');

/** load(): runs the inline script of index.html and returns its exposed parse and renderSecs. */
function load() {
  const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  const code = html.slice(html.lastIndexOf('<script>') + 8, html.lastIndexOf('</script>'));
  const win = { GO_TEST: {} };
  vm.runInNewContext(code, { window: win, document: {}, localStorage: null, location: { hash: '' } });
  return win.GO_TEST;
}

/** count(md, t): renders go.md text md with the page functions t; returns {open count, section links (nav), cards (body)}. */
function count(md, t) {
  const r = t.renderSecs(t.parse(md).secs, {});
  return { open: r.open, nav: r.nav, body: r.body };
}

const t = load();
let fail = 0;
/** check(name, ok): prints PASS or FAIL for one case. */
function check(name, ok) { console.log((ok ? 'PASS ' : 'FAIL ') + name); if (!ok) fail++; }

// Fake go.md texts only (no real data).
const grouped = '# T\n## Open tasks\n### Round A (run first)\nx\n### Round B\ny\n## Done\n- a\n- b\n';
const empty = '# T\n## Open tasks\n\nNothing open right now.\n## Done\n- a\n';
const old = '# T\n## Round A (open, 1 Jan)\nx\n## Round Z (done, 1 Jan)\ny\n';
const other = '# T\n## Open questions\n### Q1\nz\n';
const esc = '# T\n## Open tasks\n### <b>x</b> "y"\nz\n';

check('2 "###" rounds under Open tasks count 2', count(grouped, t).open === 2);
check('each open round has its own section link', (count(grouped, t).nav.match(/is-open/g) || []).length === 2);
check('Done keeps its item count', /2 items/.test(count(grouped, t).body));
check('an Open tasks section with no "###" counts 0', count(empty, t).open === 0);
check('old "## Round (open, date)" headings still count', count(old, t).open === 1);
check('"Open questions" does not make cards open', count(other, t).open === 0);
check('heading text is escaped', !/<b>x<\/b>/.test(count(esc, t).body) && /&lt;b&gt;/.test(count(esc, t).body));
const round = '# T\n## Open tasks\n### Round A\n1. Copy the script.\nhttps://raw.githubusercontent.com/o/r/main/scripts/gov/paste/90161Z-R01-test.ps1\nhttps://example.com/notes.md\n';
check('a round script card has an Open as .txt button', (count(round, t).body.match(/data-txt=/g) || []).length === 1 && /Open as \.txt/.test(count(round, t).body));
check('a round script card has no .ps1 link and no Copy link', !/<a href="[^"]*\.ps1"/.test(count(round, t).body) && (count(round, t).body.match(/data-copy=/g) || []).length === 1);
check('the .txt name replaces .ps1', t.txtName('https://x/y/90161Z-R01-test.ps1') === '90161Z-R01-test.txt');
console.log(fail ? 'GO PAGE FAIL: ' + fail : 'GO PAGE PASS');
process.exit(fail ? 1 : 0);
