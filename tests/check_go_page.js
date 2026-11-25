// check_go_page.js: tests the go.md renderer of the bookmark page (index.html) in node, with no browser.
// Loads the page script (go.js; fleet v2 moved it out of index.html) with window.GO_TEST set, so the script exposes parse() and renderSecs() and draws nothing.
// Pass = last line "GO PAGE PASS"; exit 1 on any failure. Run: node tests/check_go_page.js
// Network: none.
// Writes: none (the page script runs in memory with fake go.md text).
// Credentials: none.
'use strict';
const fs = require('fs');
const vm = require('vm');
const path = require('path');

/** load(): runs go.js, the page script of index.html, and returns its exposed functions (parse, renderSecs, guards). */
function load() {
  const code = fs.readFileSync(path.join(__dirname, '..', 'go.js'), 'utf8');
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
// Fleet v2 guards: page wiring, stored state, config names and the attributes the safe DOM copy keeps.
const page = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
check('index.html loads go.js and has no inline script', /<script src="go\.js"[^>]*><\/script>/.test(page) && !/<script>/.test(page));
check('go.js sets no innerHTML', !/innerHTML/.test(fs.readFileSync(path.join(__dirname, '..', 'go.js'), 'utf8')));
const vs = t.validState({ 'Round A': true, x: 'yes', y: 1, __proto__: { polluted: true }, ['z'.repeat(201)]: true });
check('stored state keeps only short names with true/false values', Object.keys(vs).join() === 'Round A' && vs.polluted === undefined);
check('stored state that is not an object becomes empty', ['[]', 'null', '"x"', '3'].every(j => Object.keys(t.validState(JSON.parse(j))).length === 0));
check('a stored "__proto__" key cannot change the prototype', t.validState(JSON.parse('{"__proto__":{"a":true}}')).a === undefined);
const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'site.config.json'), 'utf8'));
check('site.config.json is valid and builds the go.md folder', t.validCfg(cfg) && t.rawBase(cfg) === 'https://raw.githubusercontent.com/' + cfg.owner + '/' + cfg.repo + '/' + cfg.branch + '/');
// Master plan P4b (2026-11-24): the page fetches from one source only, and that source and the go.js tag values are
// the site.config.json values (their one home), so a changed config cannot leave the page pointing elsewhere.
const csp = (page.match(/http-equiv="Content-Security-Policy" content="([^"]*)"/) || [])[1] || '';
const conn = ((csp.split(';').map(d => d.trim()).find(d => d.startsWith('connect-src ')) || '').split(/\s+/)).slice(1);
check('the CSP connect-src is one source: the site.config.json branch folder', conn.length === 1 && conn[0] === t.rawBase(cfg));
const tag = (page.match(/<script src="go\.js"([^>]*)>/) || [])[1] || '';
/** attr(n): the value of the data-n attribute on the go.js tag, or undefined. */
const attr = n => (tag.match(new RegExp(' data-' + n + '="([^"]*)"')) || [])[1];
check('the go.js tag owner, repo and branch equal site.config.json', ['owner', 'repo', 'branch'].every(k => attr(k) === cfg[k]));
// go.js makes a bare URL line into a file card and a .ps1 URL into a Copy button: each one must be in the CSP source.
const md = fs.readFileSync(path.join(__dirname, '..', 'go.md'), 'utf8');
/** full(u): the URL with https:// in front when the go.md line has no scheme (as go.js fileCard does). */
const full = u => /^[a-z]+:\/\//i.test(u) ? u : 'https://' + u;
const rawLinks = (md.match(/(?:[a-z]+:\/\/)?raw\.githubusercontent\.com\/[^\s)\]>"`]*/gi) || []).map(full);
const ps1Links = (md.match(/(?:[a-z]+:\/\/)?[a-z0-9.-]+\.[a-z]{2,}\/[^\s)\]>"`]*\.ps1\b/gi) || []).map(full);
check('each raw.githubusercontent.com link and each .ps1 link in go.md is in the CSP source (same case, repo and branch)',
  rawLinks.concat(ps1Links).every(u => u.startsWith(t.rawBase(cfg))));
const fakeTag = { getAttribute: n => ({ 'data-owner': 'o', 'data-repo': 'r', 'data-branch': 'b' })[n] || null };
check('tagCfg reads the three data attributes, and no tag gives null', JSON.stringify(t.tagCfg(fakeTag)) === '{"owner":"o","repo":"r","branch":"b"}' && t.tagCfg(null) === null);
check('a config name with a slash, dot path or quote is refused',
  !t.validCfg({ owner: 'a/b', repo: 'r', branch: 'main' }) && !t.validCfg({ owner: 'o', repo: '"x', branch: 'main' }) && !t.validCfg(null));
check('safe DOM keeps http(s) and # links only', t.keepAttr('href', 'https://x') && t.keepAttr('href', '#s1') && !t.keepAttr('href', 'javascript:alert(1)') && !t.keepAttr('href', 'data:text/html,x'));
check('safe DOM drops event and style attributes', !t.keepAttr('onclick', 'x') && !t.keepAttr('style', 'x') && !t.keepAttr('src', 'x'));
check('a script button keeps an https source only', t.keepAttr('data-script', 'https://x/a.ps1') && !t.keepAttr('data-script', 'http://x/a.ps1'));
console.log(fail ? 'GO PAGE FAIL: ' + fail : 'GO PAGE PASS');
process.exit(fail ? 1 : 0);
