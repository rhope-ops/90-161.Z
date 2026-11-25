// check_go_page.js: tests the bookmark page (index.html) and its page script (go.js) in node, with no browser.
// The task cards are built into index.html by scripts/build_go_page.py (its --test covers the card rules and hostile
// go.md text). This file loads go.js with window.GO_TEST set, so the script exposes its functions and wires nothing.
// Pass = last line "GO PAGE PASS"; exit 1 on any failure. Run: node tests/check_go_page.js
// Network: none.
// Writes: none.
// Credentials: none.
'use strict';
const fs = require('fs');
const vm = require('vm');
const path = require('path');

/** load(): runs go.js, the page script of index.html, and returns its exposed functions. */
function load() {
  const code = fs.readFileSync(path.join(__dirname, '..', 'go.js'), 'utf8');
  const win = { GO_TEST: {} };
  vm.runInNewContext(code, { window: win, document: {}, localStorage: null, location: { hash: '' } });
  return win.GO_TEST;
}

const t = load();
let fail = 0;
/** check(name, ok): prints PASS or FAIL for one case. */
function check(name, ok) { console.log((ok ? 'PASS ' : 'FAIL ') + name); if (!ok) fail++; }

const root = path.join(__dirname, '..');
const page = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const js = fs.readFileSync(path.join(root, 'go.js'), 'utf8');
check('the .txt name replaces .ps1', t.txtName('https://x/y/90161Z-R01-test.ps1') === '90161Z-R01-test.txt');
check('index.html loads go.js and has no inline script', /<script src="go\.js"><\/script>/.test(page) && !/<script>/.test(page));
check('go.js sets no innerHTML and makes no HTML from text', !/innerHTML|insertAdjacentHTML|DOMParser|document\.write/.test(js));
check('go.js fetches only the round scripts (one fetch call)', (js.match(/\bfetch\(/g) || []).length === 1 && /fetch\(h,/.test(js));
check('the page has the built cards', /<!-- >>> go:page: [^>]*-->\n<p class="mut">Built from go\.md\./.test(page) && /<details class="sec/.test(page));

const vs = t.validState({ 'Round A': true, x: 'yes', y: 1, __proto__: { polluted: true }, ['z'.repeat(201)]: true });
check('stored state keeps only short names with true/false values', Object.keys(vs).join() === 'Round A' && vs.polluted === undefined);
check('stored state that is not an object becomes empty', ['[]', 'null', '"x"', '3'].every(j => Object.keys(t.validState(JSON.parse(j))).length === 0));
check('a stored "__proto__" key cannot change the prototype', t.validState(JSON.parse('{"__proto__":{"a":true}}')).a === undefined);

/** fakeCard(name, open): an invented card element with the two members applyState uses. */
const fakeCard = (name, open) => ({ open, getAttribute: n => (n === 'data-name' ? name : null) });
const cards = [fakeCard('Round A', true), fakeCard('Round B', false), fakeCard('Round C', true)];
t.applyState({ querySelectorAll: () => cards }, t.validState({ 'Round A': false, 'Round B': true }));
check('remembered choices open or close their cards; others keep the built state', !cards[0].open && cards[1].open && cards[2].open);

// Master plan P4b (2026-11-24): the page fetches from one source only, the site.config.json branch folder (the build
// writes it), and each link go.md gives the page is in that source.
const cfg = JSON.parse(fs.readFileSync(path.join(root, 'site.config.json'), 'utf8'));
const base = 'https://raw.githubusercontent.com/' + cfg.owner + '/' + cfg.repo + '/' + cfg.branch + '/';
const csp = (page.match(/http-equiv="Content-Security-Policy" content="([^"]*)"/) || [])[1] || '';
const conn = ((csp.split(';').map(d => d.trim()).find(d => d.startsWith('connect-src ')) || '').split(/\s+/)).slice(1);
check('the CSP connect-src is one source: the site.config.json branch folder', conn.length === 1 && conn[0] === base);
// The build makes a bare URL line into a file card and a .ps1 URL into a Copy script button: each one must be in the source.
const md = fs.readFileSync(path.join(root, 'go.md'), 'utf8');
/** full(u): the URL with https:// in front when the go.md line has no scheme (as the build does). */
const full = u => /^[a-z]+:\/\//i.test(u) ? u : 'https://' + u;
const rawLinks = (md.match(/(?:[a-z]+:\/\/)?raw\.githubusercontent\.com\/[^\s)\]>"`]*/gi) || []).map(full);
const ps1Links = (md.match(/(?:[a-z]+:\/\/[^\s/]+|[a-z0-9-]+(?:\.[a-z0-9-]+)+)\/[^\s)\]>"`]*\.ps1\b/gi) || []).map(full);
const outside = [...new Set(rawLinks.concat(ps1Links).filter(u => !u.startsWith(base)))];
check('each raw.githubusercontent.com link and each .ps1 link in go.md is in the CSP source (same case, repo and branch)' +
  (outside.length ? ': not in it (' + outside.length + '): ' + outside.slice(0, 3).join(' ') : ''), outside.length === 0);
check('each data-script address on the page is in the CSP source', (page.match(/data-script="([^"]*)"/g) || []).every(a => a.slice(13, -1).startsWith(base)));
console.log(fail ? 'GO PAGE FAIL: ' + fail : 'GO PAGE PASS');
process.exit(fail ? 1 : 0);
