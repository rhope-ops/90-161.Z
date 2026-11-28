#!/usr/bin/env bash
# 90-161.Z test runner (agent workspace). Pass = last line "TESTS pass=N fail=0", exit 0.
# Word COM and PnP cannot run here; those parts are tested on the gov device (docs/gov-test-plan.md).
# Lanes (.claude/skills/deliver/SKILL.md): tests/run.sh = full lane, every test. tests/run.sh --fast = fast lane: every
# cheap check (stale generated files: task scripts, bundles, lock, payloads, packages; JSON; names; guide text) runs
# always; a slow group (pwsh, network, lint) runs only when a file it reads changed against the merge base with
# origin/main, and lint checks only the changed PowerShell files. A change to this file or scripts/check.local.sh, or no
# merge base, runs everything. Each skipped group prints a SKIP line; the full lane before a merge runs them all.
set -uo pipefail; exec </dev/null   # no test reads the keyboard: a hidden Skip prompt waited for a key (PFM 19 Nov 26)
cd "$(git rev-parse --show-toplevel)"
pass=0; fail=0; skipped=0
ok()  { echo "PASS $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }
sk()  { echo "SKIP $1 (fast lane: the files it reads did not change)"; skipped=$((skipped+1)); }
lane=full
case "${1:-}" in --fast) lane=fast ;; '') ;; *) echo "usage: tests/run.sh [--fast]" >&2; exit 2 ;; esac
changed='*all*'
if [ "$lane" = fast ] && base=$(git merge-base HEAD origin/main 2>/dev/null); then
  changed=$( { git diff --name-only "$base"; git ls-files -o --exclude-standard; } 2>/dev/null | sort -u)
fi
need() {  # need GLOB...: true in the full lane, with no merge base, or when a changed file matches a glob (* matches /)
  [ "$changed" = '*all*' ] && return 0
  local f g
  while IFS= read -r f; do
    for g in tests/run.sh scripts/check.local.sh "$@"; do [[ $f == $g ]] && return 0; done
  done <<<"$changed"
  return 1
}
declare -A on
grp() { local n=$1; shift; if need "$@"; then on[$n]=1; else on[$n]=0; fi; }
grp val 'scripts/gov/Test-Publication.ps1' 'scripts/gov/Publication.Common.ps1' 'samples/*' 'tests/fixtures/*' \
  'tests/ps/Invoke-Validations.ps1' 'schemas/publication.schema.json'
grp seal 'scripts/gov/90161Z-T07-*' 'scripts/build_test_seals.py' 'tests/ps/Test-SealTrim.ps1' 'tests/fixtures/seal*'
grp t20 'scripts/gov/90161Z-T20-*' 'scripts/gov/90161Z-T19-*' 'scripts/gov/src/*' 'tests/ps/Test-T20.ps1' 'tests/fake-pnp/*' 'schemas/lists/*' \
  'flow/provisioning-payload.json' 'scripts/build_flow_payload.py'
grp t21 'scripts/gov/90161Z-T21-*' 'scripts/gov/90161Z-T20-*' 'scripts/gov/src/*' 'tests/ps/Test-T21.ps1' 'samples/90161Z-T21-*' 'scripts/build_probe_samples.py' 'flow/solution/90161Z-T24-*'
grp batch 'scripts/gov/*.ps1' 'scripts/gov/src/*' 'tests/ps/Invoke-Batch.ps1' 'flow/provisioning-payload.json' 'schemas/lists/*' 'samples/*'
grp bundle 'scripts/gov/paste/*' 'scripts/paste_bundles.json' 'scripts/rade.lock.json' 'scripts/build_paste_bundles.py' 'scripts/rade_newest.py'
grp t22 'scripts/gov/90161Z-T22-*'
grp mask 'scripts/gov/90161Z-T*.ps1' 'scripts/gov/src/*' 'tests/ps/Test-Mask.ps1' 'tests/ps/Test-T22Maint.ps1' 'tests/ps/Test-T26.ps1' 'tests/ps/Test-T27.ps1' 'tests/ps/Test-T30.ps1' 'scripts/paste_bundles.json'
# Lint: the full lane, or a changed scripts/lint.sh, lints every file; else only the changed PowerShell files under scripts/gov.
lintfiles=()
if [ "$changed" != '*all*' ] && ! need scripts/lint.sh; then
  while IFS= read -r f; do [[ $f == scripts/gov/*.ps1 || $f == scripts/gov/*.psm1 ]] && [ -f "$f" ] && lintfiles+=("$f"); done <<<"$changed"
  [ "${#lintfiles[@]}" -gt 0 ] && on[lint]=1 || on[lint]=0
else
  on[lint]=1
fi

python3 scripts/bloat_check.py --test >/tmp/bloat.out 2>&1 && ok "bloat_check self-test" || { cat /tmp/bloat.out; bad "bloat_check self-test"; }
# The two slowest checks (lint, T20 on the fake site) run beside the other tests (bloat audit 3, 2026-11-15: 36 s suite);
# each result is read where its PASS line is written: T20 at its old place, lint at the end.
bg=$(mktemp -d)
[ "${on[lint]}" = 1 ] && { scripts/lint.sh "${lintfiles[@]}" >"$bg/lint.out" 2>&1 & lint_pid=$!; }
[ "${on[t20]}" = 1 ] && { pwsh -NoProfile -File tests/ps/Test-T20.ps1 >"$bg/t20.out" 2>&1 & t20_pid=$!; }
[ "${on[t21]}" = 1 ] && { pwsh -NoProfile -File tests/ps/Test-T21.ps1 >"$bg/t21.out" 2>&1 & t21_pid=$!; }
# R39: T22 maint first; R41: T26; R43: T27; R47: T30 batch
maskrun() { for t in T22Maint T26 T27 T30 Mask; do pwsh -NoProfile -File "tests/ps/Test-$t.ps1" || return 1; done; }
[ "${on[mask]}" = 1 ] && { maskrun >"$bg/mask.out" 2>&1 & mask_pid=$!; }
# The small pwsh checks (Hide-Site masking, Get-SiteAddress, two-space sentences, opening paragraph, Font binding, T20 -PlanOnly)
# run in ONE more pwsh process (tests/ps/Invoke-Batch.ps1; bloat audit 3, P1, 2026-11-15), each in its own runspace, each
# writing <name>.out and <name>.rc to a fresh folder. A missing .rc (the member did not run) or an rc other than 0 = FAIL.
bd=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "${vd:-}" "${bg:-}" "${bd:-}" "${tp:-}" "${te:-}" "${sealraw:-}"' EXIT
[ "${on[batch]}" = 1 ] && { pwsh -NoProfile -File tests/ps/Invoke-Batch.ps1 -OutDir "$bd" >"$bd/batch.log" 2>&1 & batch_pid=$!; }
bout() {  # $1 = member name: print its output; fail when the member did not finish with rc 0 (after the wait below)
  [ "$(cat "$bd/$1.rc" 2>/dev/null)" = "0" ] || return 1
  cat "$bd/$1.out"
}

# All Test-Publication.ps1 runs happen in ONE pwsh process (tests/ps/Invoke-Validations.ps1; PFM P1, bloat audit 2,
# 2026-11-13): one pwsh start per input cost about 0.75 s each. Inputs are made first; each test reads vout/vrc.
vd=$(mktemp -d)
python3 - "$vd" <<'PY40'
# F-040 (Attachment 10 note 4) and PFM 2B (2026-11-12): in a wing or delta publication (T-3) warns, a higher tier such as
# the sample's (T-1) stays, and F-039 does not ask for a tier. Sample = wing with 0 (T-3). Copies add (T-3) to the 3
# untiered statements: wing and delta warn 3 times with no F-039; a non-wing issuer has no F-040 but F-039 warns.
import json, sys
d = json.load(open('samples/publication.sample.json'))
s = json.dumps(d)
for t in ('15 business days.', 'in the record set.', 'coordination is complete.'):
    assert s.count(t) == 1, t; s = s.replace(t, t + ' (T-3)')
d = json.loads(s)
json.dump(d, open(sys.argv[1] + '/wing.json', 'w'))
d['meta']['issuerLine'] = 'SAMPLE DELTA'; d['meta'].pop('byOrderOfUnit', None)
json.dump(d, open(sys.argv[1] + '/delta.json', 'w'))
d['meta']['byOrderOf'] = 'SECRETARY OF THE AIR FORCE'; d['meta']['issuerLine'] = 'SAMPLE HEADQUARTERS'
s = json.dumps(d).replace(' (T-3)', '')
json.dump(json.loads(s), open(sys.argv[1] + '/hq.json', 'w'))
# F-020 accessibility link: the link text must be in the statement and the address must be https (PFM 13 Nov).
d = json.load(open('samples/publication.sample.json'))
d['meta']['accessibilityLink']['text'] = 'NOT IN TEXT'; d['meta']['accessibilityLink']['url'] = 'http://x'
json.dump(d, open(sys.argv[1] + '/f020.json', 'w'))
PY40
printf '%s\t%s\n' sample samples/publication.sample.json wing "$vd/wing.json" delta "$vd/delta.json" hq "$vd/hq.json" \
  bad tests/fixtures/bad.publication.json f020 "$vd/f020.json" placeholder tests/fixtures/placeholder.publication.json \
  seal tests/fixtures/seal.publication.json sealok tests/fixtures/seal-ok.publication.json > "$vd/list.txt"
[ "${on[val]}" = 1 ] && pwsh -NoProfile -File tests/ps/Invoke-Validations.ps1 -List "$vd/list.txt" -OutDir "$vd"
vout() { cat "$vd/$1.out"; [ -f "$vd/$1.err" ] && cat "$vd/$1.err" >&2; true; }
vrc() { cat "$vd/$1.rc"; }

if [ "${on[val]}" = 1 ]; then
out=$(vout sample); rc=$(vrc sample)
[ $rc -eq 0 ] && echo "$out" | tail -1 | grep -q '^VALIDATE fails=0 ' && ok "sample validates ($(echo "$out" | tail -1))" || { echo "$out"; bad "sample validates"; }

# F-040 / F-039 inputs: see the batch above.
c40() { vout "$1" | grep -c "^WARN $2 "; }
s40=$(c40 sample F-040); s39=$(c40 sample F-039)
w40=$(c40 wing F-040); w39=$(c40 wing F-039); d40=$(c40 delta F-040)
h40=$(c40 hq F-040); h39=$(c40 hq F-039)
r40="sample=$s40/$s39 wing=$w40/$w39 delta=$d40 hq=$h40/$h39"
[ "$s40$s39$w40$w39$d40$h40" = "003030" ] && [ "$h39" -eq 3 ] && ok "F-040 and F-039 in wing/delta vs other issuers ($r40, F-040/F-039)" || bad "F-040/F-039 $r40 (want sample=0/0 wing=3/0 delta=3 hq=0/3)"

out=$(vout bad); rc=$(vrc bad)
got=$(echo "$out" | grep -oE '^FAIL [A-Z]+-?[0-9]*' | awk '{print $2}' | sort -u | tr '\n' ' ')
want="F-005 F-013 F-018 F-020 F-021 F-022 F-025 F-026 F-029 F-031 F-033 F-034 F-035 F-037 SCHEMA W-001 "
[ $rc -eq 1 ] && [ "$got" = "$want" ] && ok "bad fixture fails on expected rules" || { echo "got:  $got"; echo "want: $want"; bad "bad fixture"; }
else sk "sample validates"; sk "F-040 and F-039 in wing/delta vs other issuers"; sk "bad fixture fails on expected rules"; fi

for f in samples/publication.sample.json tests/fixtures/bad.publication.json schemas/publication.schema.json schemas/lists/*.json flow/provisioning-payload.json; do
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" && ok "json $f" || bad "json $f"
done

if [ "${on[val]}" = 1 ]; then
n20=$(vout f020 | grep -c "^FAIL F-020 meta.accessibilityLink")
[ "$n20" -eq 2 ] && ok "F-020 accessibility link checks (bad text and bad url: $n20 FAIL)" || bad "F-020 accessibility link checks ($n20 FAIL, want 2)"
else sk "F-020 accessibility link checks"; fi
python3 - <<'PY' && ok "sample matches JSON schema" || bad "sample matches JSON schema"
import json, sys
try:
    import jsonschema
except ImportError:
    print("jsonschema not installed"); sys.exit(1)
jsonschema.validate(json.load(open('samples/publication.sample.json')), json.load(open('schemas/publication.schema.json')))
PY

grep -q "\$nb = \$t.Replace('-', \[string\]\[char\]30)" scripts/gov/Publication.Word.ps1 && ok "tier numbers use a Word nonbreaking hyphen (T01 r4)" || bad "tier nonbreaking hyphen"
[ "$(ls scripts/gov/90161Z-T01-renderer-test-r*.ps1 | wc -l)" -eq 1 ] && ok "one T01 runner revision" || bad "more than one T01 runner"

if [ "${on[val]}" = 1 ]; then
out=$(vout placeholder); rc=$(vrc placeholder)
got=$(echo "$out" | grep -oE '^FAIL [A-Z]+-?[0-9]*' | awk '{print $2}' | sort -u | tr '\n' ' ')
[ $rc -eq 1 ] && [ "$got" = "X-001 " ] && ok "placeholder fixture fails on X-001 only" || { echo "got: $got"; bad "placeholder fixture"; }
else sk "placeholder fixture fails on X-001 only"; fi
python3 scripts/build_messy_draft.py --check && ok "T06 messy draft up to date" || bad "T06 messy draft stale"
for k in ComplianceBefore ComplianceRuleDist ReleaseRuleDist BlockRuleBefore GroupBlankLine TocFontSize; do
  grep -q "^\$$k = " scripts/gov/New-Publication.ps1 || { bad "renderer constant $k (L-008a, L-010c, L-012)"; continue; }
done && ok "renderer cover and TOC constants present (L-008a, L-010c, L-012)"

python3 scripts/build_test_seals.py --check && ok "T07 test seals up to date" || bad "T07 test seals stale"
if [ "${on[seal]}" = 1 ]; then
sealraw=$(mktemp -d); python3 scripts/build_test_seals.py --raw "$sealraw" >/dev/null
out=$(pwsh -NoProfile -File tests/ps/Test-SealTrim.ps1 -RawDir "$sealraw"); rc=$?; rm -rf "$sealraw"
[ $rc -eq 0 ] && [ "$(echo "$out" | grep -c '^PASS')" -eq 4 ] && ok "seal trim matches the reference on 4 test seals (L-007a)" || { echo "$out"; bad "seal trim"; }
else sk "seal trim matches the reference on 4 test seals (L-007a)"; fi
if [ "${on[val]}" = 1 ]; then
out=$(vout seal); rc=$(vrc seal)
got=$(echo "$out" | grep -oE '^FAIL [A-Z]+-?[0-9a-z]*' | awk '{print $2}' | sort -u | tr '\n' ' ')
[ $rc -eq 1 ] && [ "$got" = "L-007a " ] && ok "unprepared seal fails on L-007a only" || { echo "got: $got"; bad "seal fixture"; }
out=$(vout sealok); rc=$(vrc sealok)
[ $rc -eq 0 ] && echo "$out" | tail -1 | grep -q '^VALIDATE fails=0 ' && ok "prepared seal path accepted (L-007a)" || { echo "$out" | grep FAIL; bad "prepared seal path"; }
else sk "unprepared seal fails on L-007a only"; sk "prepared seal path accepted (L-007a)"; fi
grep -q '$pic.Width = \[single\]$ShieldWidth; $pic.Height = \[single\]$ShieldWidth' scripts/gov/New-Publication.ps1 && ok "renderer places seals in the 1.20 in box (L-007)" || bad "renderer seal box"
grep -q "Write-Output ('RENDER-ERROR line '" scripts/gov/New-Publication.ps1 && grep -q "exit 3 }" scripts/gov/New-Publication.ps1 && ok "renderer names the failing line and flags FORMAT-FAIL (T06/T07 cast error)" || bad "renderer error line"

python3 scripts/build_flow_payload.py --check >/dev/null && ok "flow payload up to date" || bad "flow payload stale"
python3 tests/check_palette.py >/dev/null && ok "palette contrast (WCAG AA)" || bad "palette contrast"
# Fleet v2: every scripts/build_* generator is in the rebuild order (scripts/rebuild_all.py), each dependency first.
out=$(python3 scripts/rebuild_all.py --test 2>&1); [ $? -eq 0 ] && ok "rebuild order ($out)" || { echo "$out"; bad "rebuild order"; }
python3 scripts/build_rights_probe.py --check >/dev/null && ok "rights probe def up to date" || bad "rights probe def stale"
python3 scripts/build_flow_package.py --check && ok "flow packages up to date" || bad "flow packages stale"
python3 tests/check_flow_package.py && ok "flow packages match real export shape" || bad "flow package shape"
python3 tests/check_flow_defs.py && ok "flow def names and expressions" || bad "flow def names or expressions"
python3 scripts/build_flow_solution.py --check >/dev/null && python3 tests/check_flow_solution.py >/dev/null && ok "flow solution up to date and valid" || bad "flow solution stale or invalid"
# R15-R18 (PFM 14 Nov 26): each solution import test is its own solution (PFM90161ZTEST + variant), one flow, XML valid, T05
# export values; no environmentvariabledefinition.xml has an XML declaration. R19: only A r5 (no variable, layout of the R18 export).
python3 - <<'PYEOF' && ok "solution import test zip valid (A r5: no variable, R18 export layout)" || bad "solution import test zips"
import zipfile, glob, xml.dom.minidom as md
zips = sorted(glob.glob('flow/solution/90161Z-T17-solution-test-*.zip')) + ['flow/solution/90161Z-T24-full-flows-r5.zip']
assert len(zips) == 2 and zips[0].endswith('-test-a-r5.zip'), zips
for path in zips:
    z = zipfile.ZipFile(path); n = z.namelist()
    for f in n:
        if f.endswith('.xml'): md.parseString(z.read(f))
        if f.startswith('environmentvariabledefinitions/'): assert not z.read(f).startswith(b'<?xml'), f
    if 'T17' not in path: continue
    v = path.split('-test-')[1][0].upper(); s = z.read('solution.xml').decode(); c = z.read('customizations.xml').decode()
    assert f'<UniqueName>PFM90161ZTEST{v}</UniqueName>' in s and 'OrganizationVersion="9.2.26101.188"' in s and '<UniqueName>PFM</UniqueName>' in s
    assert sum(f.startswith('Workflows/') for f in n) == 1
    assert sum(f.startswith('environmentvariabledefinitions/') for f in n) == {'A': 0, 'B': 1}[v]
    assert '<StateCode>1</StateCode>' in c and '<StatusCode>2</StatusCode>' in c and '<ModernFlowType>0</ModernFlowType>' in c
    assert '"runtimeSource": "invoker"' in z.read([f for f in n if f.startswith('Workflows/')][0]).decode()
    assert 'type="10018"' not in s, 'connection reference is not a root component in the R18 export'
PYEOF
python3 tests/check_names.py && ok "naming rules (PFM 2026-11-11)" || bad "naming rules"
out=$(python3 tests/check_readme_links.py 2>&1); [ $? -eq 0 ] && ok "README link check finds .ps1 and github.io links ($(echo "$out" | tail -1))" || { echo "$out" | grep FAIL; bad "README link check"; }
python3 scripts/check_collect.py --test >/dev/null && python3 scripts/check_collect.py >/dev/null && ok "no scripts in results: every collect name ends in a result extension (PFM 2026-11-20)" || { python3 scripts/check_collect.py; bad "no scripts in results"; }
out=$(python3 tests/check_logo_draw.py 2>&1); [ $? -eq 0 ] && ok "logo_draw: one good drawing and each clean refusal ($(echo "$out" | tail -1))" || { echo "$out" | grep FAIL; bad "logo_draw refusals"; }
for f in flow/defs/*.json; do python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" && ok "json $f" || bad "json $f"; done

python3 - <<'PY' && ok "T02 package: current payload, site address only (PFM 2026-11-12), lookups and list titles last, loops 1 at a time" || bad "T02 package payload or loop concurrency"
import json, zipfile, glob, sys
sys.path.insert(0, 'scripts'); from build_flow_package import literal
z = zipfile.ZipFile(sorted(glob.glob('flow/packages/90161Z-T02-provision-lists-r*.zip'))[-1])
d = json.loads(z.read([n for n in z.namelist() if n.endswith('/definition.json')][0]))['properties']['definition']['actions']
assert d['Payload']['inputs'] == literal(json.load(open('flow/provisioning-payload.json')))
assert literal({'a': ['@x', 'y @{z}', 'ok']}) == {'a': ['@@x', 'y @@{z}', 'ok']}
assert 'Check_Site_Title' not in d and 'Get_Site_Title' not in d
assert d['Payload']['runAfter'] == {}
p = json.load(open('flow/provisioning-payload.json'))
assert all(('Get_' + l[3:] + '_ID') in d for l in p['lookupPlaceholders']), p['lookupPlaceholders']
body = d['Create_Fields_And_Views']['actions']['Create_Field_Or_View']['inputs']['parameters']['parameters/body']
assert all(f'__{l}_ID__' in body for l in p['lookupPlaceholders'])
assert d['Add_Rows']['runAfter'] == {'Create_Fields_And_Views': ['Succeeded']} and d['Apply_Updates']['runAfter'] == {'Add_Rows': ['Succeeded']}
x = json.dumps(p)
assert x.count('MultiChoice') == 2 and x.count('UserMulti') == 1 and x.count('EnforceUniqueValues') == 2 and x.count('<And>') == 1, 'multi, unique and two-condition views reach the payload'
assert len(p['rows']) == 93  # 39 series + 12 settings + 29 offices (22 A3.2 + 7 mandatory, Q13 and 4.2A) + 13 process steps
assert 'PFMProductIndex' in p['lookupPlaceholders'] and p['listOrder'][-1] == 'PFMReviews'
lo = p['listOrder']; assert lo.index('PFMProductIndex') < lo.index('PFMPublications') < lo.index('PFMReviews'), lo
gv = [r for r in p['fields'] if r['body'].get('Title') == 'PFM - Prescribed Forms by Publication']
q = gv[0]['body']['ViewQuery']
assert q.index('<Where>') < q.index('<GroupBy') < q.index('<OrderBy>'), q
assert [r['body']['__metadata']['type'] for r in p['rows']].count('SP.Data.PFMSeriesListItem') == 39
st = {r['body']['Title']: r['body']['SettingValue'] for r in p['rows'] if r['body']['__metadata']['type'] == 'SP.Data.PFMSettingsListItem'}
assert st == {'CoordinationSuspenseBusinessDays': '15', 'GuardReserveApplicabilityCalendarDays': '30', 'PublicationsSiteName': '', 'PublicationsListUrl': '', 'PFMOfficeMailbox': '', 'EscalationWeekdays': '', 'RecordsFreeze': '', 'FlowsPaused': 'No', 'TestMode': 'Yes', 'ReminderLeadDays': '5', 'EscalationLagDays': '3', 'SharedMailbox': ''}, st
nums = [r['body']['SeriesNumber'] for r in p['rows'] if 'SeriesNumber' in r['body']]
assert len(set(nums)) == 39 and 16 in nums and 17 in nums
gets = [a for a in d if a.startswith('Get_') and a.endswith('_ID')]
assert d[gets[0]]['runAfter'] == {'Create_Lists': ['Succeeded', 'Failed']}
assert all(d[b]['runAfter'] == {a: ['Succeeded']} for a, b in zip(gets, gets[1:]))
assert d['Create_Fields_And_Views']['runAfter'] == {gets[-1]: ['Succeeded']}
assert all(u['uri'].startswith('_api/web/lists/getbytitle(') for u in p['updates'])
assert p['updates'][-len(p['listOrder']):] == [u for u in p['updates'] if u['body']['__metadata']['type'] == 'SP.List']
trig = json.loads(z.read([n for n in z.namelist() if n.endswith('/definition.json')][0]))['properties']['definition']['triggers']['manual']['inputs']['schema']
assert set(trig['required']) == {'text'} and set(trig['properties']) == {'text'}
def upstream(a, seen=()):  # every action must sit after the site-title check
    if a == 'Payload': return True
    after = list(d[a]['runAfter'])
    return bool(after) and all(upstream(x) for x in after)
assert all(upstream(a) for a in d if a != 'Payload'), 'an action runs before the payload'
reqs = p['lists'] + p['fields'] + p['rows'] + p['updates']
assert not any(' ' in r['uri'] for r in reqs), 'unencoded space in a request URI'
assert all(l['body'].get('EnableVersioning') for l in p['lists']), 'AppendOnly notes need versioning on every list'
renamed = {}
for i, r in enumerate(p['updates']):
    if r['body']['__metadata']['type'] == 'SP.List': renamed[r['uri']] = i
for i, r in enumerate(p['updates']):
    for u, j in renamed.items():
        assert not (r['uri'].startswith(u + '/') and i > j), 'request uses a list title after its rename'
for k in ('Create_Lists', 'Create_Fields_And_Views', 'Add_Rows', 'Apply_Updates', 'Set_Item_Permissions'):
    assert d[k]['runtimeConfiguration']['concurrency']['repetitions'] == 1, k
# Item-level permissions (PFM 10A, in the flow from r11): after the titles, by display title, a refusal still reaches Result
perm = p['permissions']
assert sorted(r['uri'] for r in perm) == ["_api/web/lists/getbytitle('PFM%20Endorsements')", "_api/web/lists/getbytitle('PFM%20Publications')"], perm
assert all(r['body']['ReadSecurity'] == 1 and r['body']['WriteSecurity'] == 2 for r in perm)
assert d['Set_Item_Permissions']['runAfter'] == {'Apply_Updates': ['Succeeded']} and d['Set_Item_Permissions']['foreach'] == "@outputs('Payload')?['permissions']"
assert d['Result']['runAfter'] == {'Set_Item_Permissions': ['Succeeded', 'Failed']} and 'NOT SET' in d['Result']['inputs']
PY

python3 - <<'PY' && ok "r7 schema rules (DAFMAN design check 2026-11-11)" || bad "r7 schema rules"
import json, glob
S = {json.load(open(f))['list']: json.load(open(f)) for f in glob.glob('schemas/lists/*.json')}
F = lambda l: {f['internalName']: f for f in S[l]['fields']}
pub, end, pi, rv, off = F('PFMPublications'), F('PFMEndorsements'), F('PFMProductIndex'), F('PFMReviews'), F('PFMOffices')
assert pub['ActionType']['choices'] == ['New', 'Rewrite', 'Interim Change', 'Administrative Change', 'Guidance Memorandum', 'Certify Current', 'Rescind', 'Transfer', 'Corrective Action', 'Reissue Guidance Memorandum', 'Change OPR', 'Revise']
assert pub['Product']['lookup']['list'] == 'PFMProductIndex'
assert 'Execution' not in end and not end['EndorserOrder']['required']
assert end['CoordinationStage']['choices'] == ['Privacy Review', 'Formal Coordination', 'Legal'] and end['CoordinationStage']['required']
assert end['CoordinationRole']['choices'] == off['CoordinationRole']['choices'] and 'Legal' in off['CoordinationRole']['choices']
assert 'Publication' not in pi and 'Expired' in pi['ProductStatus']['choices']
assert all(pi[k]['lookup']['list'] == 'PFMProductIndex' for k in ('SupersededBy', 'ParentPublication', 'PrescribingPublication'))
assert rv['OPRResponse']['choices'] == ['Certify Current', 'Requires Revision', 'Requires Transfer', 'Is Obsolete', 'Other', 'No Response']
assert rv['Product']['lookup']['list'] == 'PFMProductIndex' and rv['FollowUpAction']['lookup']['list'] == 'PFMPublications'
steps = S['PFMProcessSteps']['seed']
assert [s['StepNumber'] for s in steps] == list(range(0, 13)) and 'Privacy' in steps[5]['Title']
assert {s['StepNumber']: s.get('TargetBusinessDays') for s in steps if s.get('TargetBusinessDays')} == {2: 60, 6: 20, 7: 20, 8: 10, 9: 10, 11: 15}
PY

python3 - <<'PY' && ok "sample CSVs match schema columns and choices" || bad "sample CSVs"
import csv, glob, json, os
for f in glob.glob('samples/lists/*.csv'):
    S = {x['internalName']: x for x in json.load(open('schemas/lists/' + os.path.basename(f)[:-4] + '.json'))['fields']}
    rows = list(csv.DictReader(open(f, encoding='utf-8')))
    assert set(rows[0]) <= set(S), (f, set(rows[0]) - set(S))
    for r in rows:
        for k, v in r.items():
            if v and S[k]['type'] == 'Choice': assert v in S[k]['choices'], (f, k, v)
PY

python3 scripts/build_list_mockup.py /tmp/pfm-lists-mockup.html | grep -q "12 lists" && ! grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}</td>|Not started|Emailed" /tmp/pfm-lists-mockup.html && ok "list mockup builds (T&Q dates and terms)" || bad "list mockup"

python3 - <<'PY' && ok "flow payload XML parses" || bad "flow payload XML"
import json, xml.etree.ElementTree as ET
d = json.load(open('flow/provisioning-payload.json'))
for r in d['fields']:
    b = r['body']
    if 'parameters' in b: ET.fromstring(b['parameters']['SchemaXml'])
    if b.get('ViewQuery'): ET.fromstring('<Q>' + b['ViewQuery'] + '</Q>')
PY

# The checks that follow live in two part files, read in order in this same shell (header of each file).
source tests/run_probes.sh
source tests/run_rounds.sh
[ "$lane" = fast ] && echo "TESTS pass=$pass fail=$fail skip=$skipped (fast lane)" || echo "TESTS pass=$pass fail=$fail"
[ $fail -eq 0 ]
