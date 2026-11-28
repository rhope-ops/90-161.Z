# tests/run_probes.sh: part 2 of tests/run.sh (T20 and T21 fake-site checks, masking, build and lock checks, bundle end to end).
# Run only by tests/run.sh, which sources it (same shell: it shares ok, bad, sk, on, bg, bd and the counters). Do not run it alone.
# Network: the bundle check reads the pinned RADE engine from GitHub (cached after one download); the fake sites are local.
# Writes: temporary folders (mktemp, removed at exit) and the scratch file /tmp/crm.out; nothing in the repo.
# Credentials: none (fake sample data only).

# T20 list provisioning by PnP (PFM 14 Nov 26): the plan counts come from the payload, and the script runs against a strict
# fake site (tests/fake-pnp): create, a second run that creates nothing, a repair run, the clean check, masked output.
if [ "${on[batch]}" = 1 ]; then
wait "$batch_pid"   # first use of the batch results
out=$(bout plan | tail -1)
[ "$out" = "PLAN lists=12 fields=200 views=18 rows=93 updates=21 permissions=2" ] && ok "lists plan ($out)" || bad "lists plan: $out"
else sk "lists plan"; fi
if [ "${on[t20]}" = 1 ]; then
wait "$t20_pid"; t20rc=$?; out=$(tail -1 "$bg/t20.out")
case "$t20rc $out" in "0 T20 pass="*" fail=0") ok "T20 list provisioning on the fake site ($out)";; *) grep "T20TEST FAIL" "$bg/t20.out" | cut -c1-300;
  bad "T20 list provisioning (exit $t20rc): $out";; esac
else sk "T20 list provisioning on the fake site"; fi

# R26 probe (T21): the 2 fake sample files and the fake PDF block in the script are built by code and match byte for byte; the device script runs on a small fake site.
python3 scripts/build_probe_samples.py --check && ok "T21 probe samples up to date" || bad "T21 probe samples stale (run python3 scripts/build_probe_samples.py)"
if [ "${on[t21]}" = 1 ]; then
wait "$t21_pid"; t21rc=$?; out=$(tail -1 "$bg/t21.out")
case "$t21rc $out" in "0 T21 pass="*" fail=0") ok "T21 probe script on the fake site ($out)";; *) grep "T21TEST FAIL" "$bg/t21.out" | cut -c1-300; bad "T21 probe script (exit $t21rc): $out";; esac
else sk "T21 probe script on the fake site"; fi
# Hide-Site (one masking function, scripts/gov/src/site-common.ps1): every pattern, the known limits, and one copy per task script.
if [ "${on[mask]}" = 1 ]; then
wait "$mask_pid"; maskrc=$?; out=$(tail -1 "$bg/mask.out")
case "$maskrc $out" in "0 MASK pass="*" fail=0")
  sums="$(grep '^T22MAINT pass' "$bg/mask.out"); $(grep '^T26 pass' "$bg/mask.out"); $(grep '^T30 pass' "$bg/mask.out")"
  ok "Hide-Site masking test, T22 maint read-back, T26 endorser answer and T30 batch ($sums; $out)";;
  *) grep -E "MASKTEST FAIL|T22MAINT FAIL|T26TEST FAIL|T27TEST FAIL|T30TEST FAIL" "$bg/mask.out" |
  cut -c1-300; bad "Hide-Site masking, T22 maint or T26 test (exit $maskrc): $out";; esac
else sk "Hide-Site masking test"; fi

node templates/build_crm_template.js >/tmp/crm.out 2>&1 && grep -q "tableWidthDXA=9331 columns=9" /tmp/crm.out && ok "CRM template builds ($(cat /tmp/crm.out | sed s,.*CRM_A12-1.docx,,))" ||
  bad "CRM template build"
# Build is deterministic (fixed dates): a rebuild must match the committed file byte for byte.
git diff --quiet HEAD -- templates/CRM_A12-1.docx && ok "CRM template rebuild matches committed file" ||
  bad "CRM template rebuild differs from committed file (commit the rebuild if the source changed)"

if [ "${on[batch]}" = 1 ]; then
got=$(bout twospace)
want="Do this. (T-3)  Then Mr. A. B. Smith signs.  Use e.g. Forms.  Done?  Yes."
[ "$got" = "$want" ] && ok "two-space sentences (L-004)" || { echo "got:  [$got]"; echo "want: [$want]"; bad "two-space sentences"; }

got=$(bout opening | grep -o -E "implements|Ensure all records|DAF Form 847|may be supplemented|authorities to waive" | tr '\n' ',')
[ "$got" = "implements,Ensure all records,DAF Form 847,may be supplemented,authorities to waive," ] && ok "opening paragraph order (4.5.5)" || { echo "got: $got"; bad "opening paragraph order"; }
else sk "two-space sentences (L-004)"; sk "opening paragraph order (4.5.5)"; fi

! grep -rniE "@us\.af\.mil|@mail\.mil|usaf\.dps\.mil/sites/[a-z0-9]" samples tests schemas docs scripts flow templates/build_crm_template.js >/dev/null &&
  ok "no .mil addresses in repo content" || bad "no .mil addresses"

# Rule source = the approved DAFMAN edition (docs/DECISIONS.md 2026-11-10): ref/ files must match ref/SHA256SUMS (bloat audit 2026-11-13).
out=$(cd ref && sha256sum -c --quiet SHA256SUMS 2>&1) && ok "ref files match ref/SHA256SUMS" || { echo "$out"; bad "ref files match ref/SHA256SUMS"; }

# F-032/F-039 false positives (T06 review 12 Nov 26): cover values count as use; office symbols and AFI-type prefixes skip the
# four-times rule; the fixed summary-of-changes sentence is not a compliance statement. Sample: only OPR and ANG warn.
if [ "${on[val]}" = 1 ]; then
out=$(vout sample | grep -E "^WARN F-032|^VALIDATE")
echo "$out" | grep -q "VALIDATE fails=0 warns=2" && ! echo "$out" | grep -qE "'(OPR-A|OPR-B|AFI)'" && ok "validator F-032 false positives gone (sample warns=2: OPR, ANG)" || { echo "$out";
  bad "validator F-032 false positives"; }
else sk "validator F-032 false positives gone"; fi
# B3A/P3 (PFM 2026-11-13): one source for the gov task-script block; no task script asks for the DODID outside it.
out=$(python3 scripts/build_task_scripts.py --check 2>&1); [ $? -eq 0 ] && ok "task scripts share one block ($(echo "$out" | tail -1))" || { echo "$out";
  bad "task-common block (run python3 scripts/build_task_scripts.py)"; }

# Task 11 Part B rows come from docs/rights-test-plan.md section 6 (one source; the RADE form step reads the JSON).
out=$(python3 scripts/build_rights_rows.py --check 2>&1 | tail -1); [ $? -eq 0 ] && echo "$out" | grep -q "stale=0" && ok "T11 Part B rows match the plan ($out)" ||
  bad "T11 Part B rows stale: $out (run python3 scripts/build_rights_rows.py)"
# The RADE engine is downloaded by commit and checked by SHA-256 (scripts/rade.lock.json; PFM 2026-11-15). The tests always
# use the pinned engine: RADE_DIR is cleared, so a committed bundle from an override build shows as stale. Engine
# behavior is tested in rhope-ops/RADE (tests/engine_test.sh); the tests here use only this repo's bundle and files.
unset RADE_DIR
out=$(python3 scripts/bump_lock.py --test 2>&1); [ $? -eq 0 ] && ok "bump_lock release-lock checks ($out)" || { echo "$out"; bad "bump_lock release-lock checks"; }
out=$(python3 tests/test_rade_fetch.py 2>&1); [ $? -eq 0 ] && ok "RADE engine download failure cases ($(echo "$out" | tail -1))" || { echo "$out"; bad "RADE engine download failure cases"; }
out=$(python3 scripts/build_paste_bundles.py --check 2>&1 | tail -1)
# engine-v8 on: the header names every engine code file of the lock ("<file>, sha256 <12 hex>"); each must match (the engine file itself must be in the list, or nh counts 1).
# engine-v21 on: engine/rade_hash.py, engine-v29 on: engine/rade_tokens.py, engine-v31 on: engine/rade_fields.py (build time only; PFM 21 Nov 26),
# engine-v36 on: engine/rade_parts.py (split from rade_build.py; build time only; the PFM, 2026-11-23) are in the lock but not in the header; the
# stale check above covers them.
ef=$(python3 -c "import json;l=json.load(open('scripts/rade.lock.json'));c=[k for k in l['files'] if k.endswith(('.py','.ps1')) and k not in \
 ('engine/rade_hash.py','engine/rade_tokens.py','engine/rade_fields.py','engine/rade_parts.py')];print(' '.join(k+'='+l['files'][k][:12] for k in c) if l['engine'] in c else '')")
nh=0; [ -n "$ef" ] || nh=1; for f in $ef; do
  nh=$((nh + $(grep -L "${f%%=*}, sha256 ${f#*=}[;)]" scripts/gov/paste/*.ps1 | wc -l))); done
nb=$(python3 -c "import json;print(len(json.load(open('scripts/paste_bundles.json'))['bundles']))"); [ "$out" = "PASTE bundles=$nb stale=0" ] && [ "$nh" -eq 0 ] &&
  ok "paste bundles current and built by the pinned engine ($out; bundles naming another engine: $nh)" ||
  bad "paste bundles: $out; bundles naming another engine: $nh (run python3 scripts/build_paste_bundles.py with RADE_DIR not set)"
# Lock bump (PFM 2026-11-15): a changed lock has serial = main's serial + 1 and builds on main's last lock commit, so two
# sessions that move the lock at once collide. Rule on who may change the lock: docs/dev-setup.md "RADE engine".
lb=$(python3 - <<'PYEOF'
import json, subprocess
def git(*a):
    r = subprocess.run(('git',) + a, capture_output=True, text=True); return r.returncode, r.stdout.strip()
mine = json.load(open('scripts/rade.lock.json'))
rc, base = git('show', 'origin/main:scripts/rade.lock.json')
if rc != 0:
    print('FAIL cannot read the lock on origin/main (run: git fetch origin main)'); raise SystemExit
base = json.loads(base)
if mine == base:
    print('ok same as origin/main (serial %s)' % mine.get('serial')); raise SystemExit
want = int(base.get('serial', 0)) + 1
if mine.get('serial') != want:
    print('FAIL serial is %s, must be %s (origin/main has %s)' % (mine.get('serial'), want, base.get('serial', 'none'))); raise SystemExit
rc, last = git('log', '-1', '--format=%H', 'origin/main', '--', 'scripts/rade.lock.json')
rc2, _ = git('merge-base', '--is-ancestor', last, 'HEAD')
print('ok changed, serial %s = main + 1, on top of main lock commit %s' % (want, last[:7]) if last and rc2 == 0
      else 'FAIL the branch does not hold the last lock commit on origin/main (%s): merge main, then rebuild' % last[:7])
PYEOF
)
[ "${lb%% *}" = "ok" ] && ok "RADE lock bump (${lb#ok })" || bad "RADE lock bump: ${lb#FAIL }"
# No bundle size limit (the PFM, 2026-11-18; was 600 KB): R32 and R33 find the largest paste that works.
# T16 r12 -LogoOnly (R29, PFM 17 Nov 26 logo places 1A): items a, b, d, e and f sit inside "if ($connected -and -not $LogoOnly)",
# only c-logo runs outside it, and the logo item uses read-only PnP calls (no Set-, Add-, New-, Remove- or Invoke-).
python3 - <<'PYT16' && ok "T16 r12 -LogoOnly runs only the read-only logo check" || bad "T16 r12 -LogoOnly runs more than the read-only logo check"
import re, pathlib
s = pathlib.Path('scripts/gov/90161Z-T16-site-setup-r12.ps1').read_text()
i = s.index('if ($connected -and -not $LogoOnly) {'); j = s.index("\n  if ($connected) {\n    # c. Site logo check")
inner, rest = s[i:j], s[j:s.index('Disconnect-PnPOnline', j)]
for k in ('a1-permissions-publications', 'a2-permissions-endorsements', 'b-time-zone', 'd-seals', 'e-probe-result', 'e2-solution-result-a', 'f-task2-lists'):
    assert "Add-Item '%s'" % k in inner, k
items = re.findall(r"Add-Item '([^']+)'", s)
assert [x for x in items if "Add-Item '%s'" % x not in inner] == ['c-logo'], items
assert not re.search(r'\b(Set|Add|New|Remove|Invoke)-PnP', rest), 'a write call in the logo item'
assert "$(if ($LogoOnly) { '90161Z-T16-logo-r12.txt' }" in s and "if ($LogoOnly) { $Logo = [switch]$true }" in s
PYT16
# Collected result names (R29 review: 7 T21 names kept r4 while the script wrote r5): a name -rN.txt of a step that runs a task
# script with a $Rev line must carry that $Rev, else the round reports the file missing or sends an old one.
python3 - <<'PYCOL' && ok "collected result names match the task script revisions" || bad "collected result names do not match the task script revisions"
import json, re, pathlib, sys
b = json.load(open('scripts/paste_bundles.json'))['bundles']; bad = []
for r in b:
    files = {pathlib.Path(f['src']).name: f['src'] for f in r['files']}
    by = {s['name']: s for s in r['steps']}
    for c in r['collect']:
        s = by.get(c['step']); src = files.get(s.get('file', '')) if s else None
        if src and pathlib.Path(src).name.startswith('90161Z-T30-batch'):   # R47: a batch step: the part script of the file's task (the batch table)
            t = re.match(r'90161Z-(T\d\d)-', c['name']); row = t and re.search(t.group(1) + r" = @\{ Dir = '[^']*'; File = '([^']+)'", pathlib.Path(src).read_text())
            src = files.get(row.group(1)) if row else None
            if not src: bad.append((c['name'], 'no part script of the batch table')); continue
        if not src or not src.endswith('.ps1'): continue
        m = re.search(r"^\$Rev = '(r\d+)'", pathlib.Path(src).read_text(), re.M)
        n = re.search(r'-(r\d+)\.txt$', c['name'])
        if m and n and m.group(1) != n.group(1): bad.append((c['name'], m.group(1)))
print(bad) if bad else None; sys.exit(1 if bad else 0)
PYCOL

# Round bundle end to end in pwsh (Linux, text mode: no Windows Forms): profile folder and C:\Users swapped for a temp root.
# Every written file must equal its source (text: BOM and CR removed); each step must start as a child process (on Linux
# the runner stops at Unblock-File, so its step reads CHECK); the results folder must hold the report (summary + full
# log) with no DODID. The window path (Windows Forms) cannot run here: lint only.
# needs <bundle>: the check ids the bundle's steps list in the manifest, space-separated. R48: with a second (deploy)
# application, only the steps of the first one (the test round that text mode runs): its checks are the ones it shows.
needs() { python3 -c "import json,sys;b=[b for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']==sys.argv[1]][0];a=b.get('apps') or [] \
;f=set(a[0]['steps']) if len(a)>1 else None;print(' '.join(sorted({n for s in b['steps'] if f is None or s['name'] in f for n in s.get('needs',[])})))" "$1"; }
if [ "${on[bundle]}" = 1 ]; then
pf=0; pr=0; pc=0
# R06 cleanup fixture: finished folders with our files and one file 90-161.Z did not make (must stay). R29 (two bundles):
# each bundle runs on its own fresh fixture, as each round runs on the device as if it were the first.
fixture() {
[ -n "${fx_tp:-}" ] && rm -rf "$fx_tp"; tp=$(mktemp -d); fx_tp=$tp; mkdir -p "$tp/u/test1234/OneDrive - United States Air Force"
ob="$tp/u/test1234/OneDrive - United States Air Force/90-161.Z"; mkdir -p "$ob/T02" "$ob/T13" "$ob/Rounds/R09" "$ob/T07" "$ob/T09"
touch "$ob/T02/90161Z-T02-provision-lists-r9.zip" "$ob/T02/Test-Environment.ps1" "$ob/T13/90161Z-T13-label-capture-r2.ps1" "$ob/T13/my-notes.docx" \
  "$ob/Rounds/R09/90161Z-R09-report-r1.txt" "$ob/T07/90161Z-T07-seal-test-r4.ps1" "$ob/T07/90161Z-T07-key-r1.txt" "$ob/T09/90161Z-T09-page-r1.htm"
echo "public sample" > "$tp/fx.bin"; printf '## Fix first: Round R99 r1, test (open, 1 Jan 26)\n' > "$tp/go.md"
}
# The raw file folder of this repository, from site.config.json (fleet v2 DEC 7), as the bundle names it.
raw_base=$(python3 -c "import sys;sys.path.insert(0,'scripts');import site_config;print(site_config.urls()['raw'])")
# A bad folder fails here and skips the bundle runs (they would run with the real addresses left in).
bundles=(scripts/gov/paste/*.ps1)
case "$raw_base" in https://raw.githubusercontent.com/*/) ;; *) bad "site.config.json gives no raw file folder"; bundles=();; esac
# Engine-v3 on (the PFM, 15 Nov 26: the newest RADE): RADE runs only on a computer whose own full name holds the NIPR
# domain label. The cloud has no such name, so the bundle tests give it a stand-in name, as RADE's own tests do
# (rhope-ops/RADE tests/engine_test.sh "swap"); the test after the loop proves the real guard stops this computer.
swap() { sed -e "s#Read-Host ('Type the number of the application to deploy (1 to ' + \\\$apps\\.Count + ') and press Enter')#'1'#" \
    -e 's#^function Get-OwnFqdn .*#function Get-OwnFqdn { return '"'pc01.area52.example.invalid'"' }#' \
    -e "s#^\$goUrl = '.*'#\$goUrl = 'file://$tp/go.md'#" \
    -e "s#Url = '$raw_base#Url = 'file://$PWD/#" \
    -e "s#Url = 'https://www\.[^']*'#Url = 'file://$tp/fx.bin'#" \
    -e "s#url = 'https://make\.powerautomate[^']*'#url = 'file://$tp/fx.bin'#I" \
    -e "s#Read-Host 'Press Enter to start the round, or type N and press Enter to stop with no changes'#''#" \
    -e "s#Read-Host 'Press Enter when the flow run has started, type F and Enter if it failed, or S and Enter to skip this step'#''#" \
    -e "s#\$checkGate = \$true#\$checkGate = \$false#" \
    -e "s#Read-Host 'Type the site address[^']*'#''#" \
    -e "s#Read-Host 'Did you see both[^']*'#'Y'#" \
    -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$tp/u'#" "$1"; }
for b in "${bundles[@]}"; do
  fixture; swap "$b" > "$tp/b.ps1"; USERPROFILE="$tp/u/test1234" pwsh -NoProfile -File "$tp/b.ps1" > "$tp/out.txt" 2>&1
  # Text mode runs the default steps that need no folder (the optional steps are skipped).
  n=$(grep -c "^\$steps += @{.*Default = \$true; AskParam = '';" "$b")
  # A bundle with a second (deploy) application: text mode runs only the first one's steps (every R28 step is a default step).
  na=$(python3 -c "import json;b=[x for x in json.load(open('scripts/paste_bundles.json'))['bundles'] if x['out']=='$b'][0];a=b.get('apps') or [];print(len(a[0]['steps']) if len(a)>1 else -1)")
  [ "$na" -lt 0 ] || n=$na
  r=$(python3 -c "import json;print([b['round'] for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b'][0])")
  # R17 (PFM 14 Nov 26): the run moves the old 90-161.Z folder (the fixture) into OneDrive/RADE.
  base="$tp/u/test1234/OneDrive - United States Air Force/RADE/90-161.Z"; nb="$base"
  [ -d "$base/T13" ] && [ ! -e "$ob" ] && grep -q "^Moved the folder 90-161.Z into RADE" "$tp/out.txt" || { echo "RADE folder move"; ls "$tp/u/test1234/OneDrive - United States Air Force";
    pf=$((pf+1)); }
  # Saved checks (R17): the run wrote RADE/Config/rade-checks.json with PASSED entries only and no DODID.
  ck="$tp/u/test1234/OneDrive - United States Air Force/RADE/Config/rade-checks.json"
  [ -f "$ck" ] && ! grep -q test1234 "$ck" &&
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['schema']=='rade-checks/1' and d['maxAgeDays']==7 and d['checks'] \
      and all(v['state']=='PASSED' for v in d['checks'].values()) and not ({'word','disk','write'} & set(d['checks']))" "$ck" ||
    { echo "rade-checks.json"; cat "$ck"; pf=$((pf+1)); }
  # Every default step starts. A step is SKIPPED only when the manifest says so: its "after" names a script step (a script
  # step cannot pass here: it stops at Unblock-File) or a step that is itself skipped. Every other step must end PASSED
  # or NEEDS REVIEW. The exact set is compared, so an engine fault that skips more (or fewer) steps fails this test.
  st=$(grep -c '^Step [0-9]* of [0-9]*: ' "$tp/out.txt")
  sk=$(python3 - "$b" "$tp/out.txt" <<'PYS'
import json, re, sys
bundle = [b for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out'] == sys.argv[1]][0]
steps = bundle['steps']
if bundle.get('apps'):   # text mode runs the first application (the test round); a second (deploy) entry has its own steps
    first = set(bundle['apps'][0]['steps']); steps = [s for s in steps if s['name'] in first]
kind = {s['name']: s.get('kind', 'script') for s in steps}
want = set()
for s in steps:   # in order: a later step may depend on an earlier skipped one
    # R47: text mode also skips a step with questions only (answersOnly)
    if any(kind[a] == 'script' or a in want for a in s.get('after', [])) or s.get('answersOnly'): want.add(s['name'])
got, ran, name = set(), set(), None
for line in open(sys.argv[2], encoding='utf-8', errors='replace'):
    m = re.match(r'^Step \d+ of \d+: (.+?)\s*$', line)
    if m: name = m.group(1); continue
    m = re.match(r'^  Result: (PASSED|NEEDS REVIEW|SKIPPED) \(', line)
    if m and name: (got if m.group(1) == 'SKIPPED' else ran).add(name); name = None
names = {s['name'] for s in steps}
print('OK' if got == want and ran == names - want else 'MISMATCH skipped=%s want=%s ran=%d of %d' % (sorted(got), sorted(want), len(ran), len(names - want)))
PYS
)
  [ "$st" -eq "$n" ] && [ "$sk" = "OK" ] && [ -f "$base/Rounds/$r/90161Z-$r-report-r1.txt" ] && grep -q "^Results folder: Rounds" "$base/Rounds/$r/90161Z-$r-report-r1.txt" &&
    grep -q "full log" "$base/Rounds/$r/90161Z-$r-report-r1.txt" && pr=$((pr+1)) || { echo "round steps: $sk"; cat "$tp/out.txt" | tail -20; }
  # The screen shows the real path (PFM 13 Nov); everything else, and the report, masks it.
  ! { grep -v '^Working folder: ' "$tp/out.txt" | grep -q "test1234"; } && ! grep -q "test1234" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "DODID not masked"; pf=$((pf+1)); }
  grep -q "^Working folder: $tp/u/test1234/" "$tp/out.txt" || { echo "real path not shown"; pf=$((pf+1)); }
  grep -q "^What to do: Open Outlook" "$tp/out.txt" || { echo "no plain-words help after the draft fallback"; pf=$((pf+1)); }
  grep -q "^A newer round, R99, is in the repository" "$tp/out.txt" || { echo "newer-round banner missing"; pf=$((pf+1)); }
  # Choose and Check screens (PFM 14 Nov 26): the report names the application and counts the checks; text mode cannot
  # sign in, so the sign-in check is NOT RUN, and no check line holds the DODID.
  # A round shows only the checks its steps need (manifest "needs"; R23 needs none of these, PFM 2026-11-15).
  rp="$base/Rounds/$r/90161Z-$r-report-r1.txt"; nd=$(needs "$b")
  grep -q "^Application: " "$rp" && tr -d "\r" < "$rp" | grep -qE "^Checks\. Passed: [0-9]+\. Warnings: [0-9]+\. Failed: [0-9]+\. Not run: [0-9]+\.$" \
    && { [[ " $nd " != *" site-rights "* ]] || grep -q "^  NOT RUN: You can change the site" "$rp"; } \
    && { [[ " $nd " != *" flow-guide "* ]] || grep -q "^  PASSED: You can import flows" "$tp/out.txt"; } || { echo "application or check lines missing in the report";
      grep -E "^(Application|Checks|  [A-Z])" "$rp"; pf=$((pf+1)); }
  grep -q "^Note: no window could open, so the round runs in text mode" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "report does not name the no-window cause"; pf=$((pf+1)); }
  # Downloads: repo files must match their SHA-256; public files land and are attached; the skipped step's file is not expected.
  nf=$(python3 -c "import json;print(sum(len(b.get('fetch',[])) for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b'))")
  [ "$nf" -eq 0 ] || grep -q "^Downloads: $nf saved, 0 failed" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "downloads: want Downloads: $nf saved, 0 failed";
    grep "^Downloads" "$base/Rounds/$r/90161Z-$r-report-r1.txt"; pf=$((pf+1)); }
  ! grep -q "90161Z-T11-partb-r1.txt" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "a skipped step's file was expected"; pf=$((pf+1)); }
  [ ! -e "$nb/T02" ] && [ ! -e "$nb/Rounds/R09" ] && [ ! -e "$nb/T07/90161Z-T07-seal-test-r4.ps1" ] && [ -f "$nb/T13/my-notes.docx" ] && [ ! -e "$nb/T13/90161Z-T13-label-capture-r2.ps1" ] \
    && [ -f "$nb/T07/90161Z-T07-key-r1.txt" ] && [ -f "$nb/T09/90161Z-T09-page-r1.htm" ] \
    && grep -qF "Clean-up: moved to the Recycle Bin: 5 files, 2 folders; kept (not made by 90-161.Z): 1 files; failed: 0." "$base/Rounds/$r/90161Z-$r-report-r1.txt" \
    && grep -qF "T13 1 (1 other)" "$base/Rounds/$r/90161Z-$r-report-r1.txt" && head -1 "$base/Rounds/$r/90161Z-$r-report-r1.txt" | tr -d "\r" | grep -q "90161Z $r NEEDS REVIEW$" \
    && grep -q "^\"$r\",\"ROUND\"," "$base/Config/90161Z-history.csv" && pc=$((pc+1)) || { echo "cleanup/summary";
      grep -E "^(Clean-up|Files left|90161Z)" "$base/Rounds/$r/90161Z-$r-report-r1.txt"; ls -R "$nb" | head -30; }
  # Every file of this bundle equals its source (R29: each bundle in its own fixture, so the check runs per bundle).
  while IFS=$'\t' read -r dir src; do
    got="$tp/u/test1234/OneDrive - United States Air Force/RADE/90-161.Z/${dir//\\//}/$(basename "$src")"
    case "$src" in *.png|*.pptx|*.zip|*.docx|*.html|*.ttf) cmp -s "$got" "$src" || { echo "file differs: $src"; pf=$((pf+1)); };; *) cmp -s <(tail -c +4 "$got" | tr -d '\r') <(swap "$src") ||
      { echo "file differs: $src"; pf=$((pf+1)); };; esac
  done < <(python3 -c "import json;[print(f['dir']+'\t'+f['src']) for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b' for f in b['files']]")
done
fi
