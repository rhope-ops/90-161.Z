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
grp mask 'scripts/gov/90161Z-T*.ps1' 'scripts/gov/src/*' 'tests/ps/Test-Mask.ps1'
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
[ "${on[mask]}" = 1 ] && { pwsh -NoProfile -File tests/ps/Test-Mask.ps1 >"$bg/mask.out" 2>&1 & mask_pid=$!; }
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

# T20 list provisioning by PnP (PFM 14 Nov 26): the plan counts come from the payload, and the script runs against a strict
# fake site (tests/fake-pnp): create, a second run that creates nothing, a repair run, the clean check, masked output.
if [ "${on[batch]}" = 1 ]; then
wait "$batch_pid"   # first use of the batch results
out=$(bout plan | tail -1)
[ "$out" = "PLAN lists=12 fields=200 views=18 rows=93 updates=21 permissions=2" ] && ok "lists plan ($out)" || bad "lists plan: $out"
else sk "lists plan"; fi
if [ "${on[t20]}" = 1 ]; then
wait "$t20_pid"; t20rc=$?; out=$(tail -1 "$bg/t20.out")
case "$t20rc $out" in "0 T20 pass="*" fail=0") ok "T20 list provisioning on the fake site ($out)";; *) grep "T20TEST FAIL" "$bg/t20.out" | cut -c1-300; bad "T20 list provisioning (exit $t20rc): $out";; esac
else sk "T20 list provisioning on the fake site"; fi

# R26 probe (T21): the 2 fake sample files and the fake PDF block in the script are built by code and match byte for byte; the device script runs on a small fake site.
python3 scripts/build_probe_samples.py --check && ok "T21 probe samples up to date" || bad "T21 probe samples stale (run python3 scripts/build_probe_samples.py)"
python3 scripts/build_test_app.py --check >/dev/null && ok "T23 app file parts match their SHA-256" || bad "T23 app file parts differ from their SHA-256 (run scripts/build_test_app.py)"
if [ "${on[t21]}" = 1 ]; then
wait "$t21_pid"; t21rc=$?; out=$(tail -1 "$bg/t21.out")
case "$t21rc $out" in "0 T21 pass="*" fail=0") ok "T21 probe script on the fake site ($out)";; *) grep "T21TEST FAIL" "$bg/t21.out" | cut -c1-300; bad "T21 probe script (exit $t21rc): $out";; esac
else sk "T21 probe script on the fake site"; fi
# Hide-Site (one masking function, scripts/gov/src/site-common.ps1): every pattern, the known limits, and one copy per task script.
if [ "${on[mask]}" = 1 ]; then
wait "$mask_pid"; maskrc=$?; out=$(tail -1 "$bg/mask.out")
case "$maskrc $out" in "0 MASK pass="*" fail=0") ok "Hide-Site masking test ($out)";; *) grep "MASKTEST FAIL" "$bg/mask.out" | cut -c1-300; bad "Hide-Site masking test (exit $maskrc): $out";; esac
else sk "Hide-Site masking test"; fi

node templates/build_crm_template.js >/tmp/crm.out 2>&1 && grep -q "tableWidthDXA=9331 columns=9" /tmp/crm.out && ok "CRM template builds ($(cat /tmp/crm.out | sed s,.*CRM_A12-1.docx,,))" || bad "CRM template build"
# Build is deterministic (fixed dates): a rebuild must match the committed file byte for byte.
git diff --quiet HEAD -- templates/CRM_A12-1.docx && ok "CRM template rebuild matches committed file" || bad "CRM template rebuild differs from committed file (commit the rebuild if the source changed)"

if [ "${on[batch]}" = 1 ]; then
got=$(bout twospace)
want="Do this. (T-3)  Then Mr. A. B. Smith signs.  Use e.g. Forms.  Done?  Yes."
[ "$got" = "$want" ] && ok "two-space sentences (L-004)" || { echo "got:  [$got]"; echo "want: [$want]"; bad "two-space sentences"; }

got=$(bout opening | grep -o -E "implements|Ensure all records|DAF Form 847|may be supplemented|authorities to waive" | tr '\n' ',')
[ "$got" = "implements,Ensure all records,DAF Form 847,may be supplemented,authorities to waive," ] && ok "opening paragraph order (4.5.5)" || { echo "got: $got"; bad "opening paragraph order"; }
else sk "two-space sentences (L-004)"; sk "opening paragraph order (4.5.5)"; fi

! grep -rniE "@us\.af\.mil|@mail\.mil|usaf\.dps\.mil/sites/[a-z0-9]" samples tests schemas docs scripts flow templates/build_crm_template.js >/dev/null && ok "no .mil addresses in repo content" || bad "no .mil addresses"

# Rule source = the approved DAFMAN edition (docs/DECISIONS.md 2026-11-10): ref/ files must match ref/SHA256SUMS (bloat audit 2026-11-13).
out=$(cd ref && sha256sum -c --quiet SHA256SUMS 2>&1) && ok "ref files match ref/SHA256SUMS" || { echo "$out"; bad "ref files match ref/SHA256SUMS"; }

# F-032/F-039 false positives (T06 review 12 Nov 26): cover values count as use; office symbols and AFI-type prefixes skip the
# four-times rule; the fixed summary-of-changes sentence is not a compliance statement. Sample: only OPR and ANG warn.
if [ "${on[val]}" = 1 ]; then
out=$(vout sample | grep -E "^WARN F-032|^VALIDATE")
echo "$out" | grep -q "VALIDATE fails=0 warns=2" && ! echo "$out" | grep -qE "'(OPR-A|OPR-B|AFI)'" && ok "validator F-032 false positives gone (sample warns=2: OPR, ANG)" || { echo "$out"; bad "validator F-032 false positives"; }
else sk "validator F-032 false positives gone"; fi
# B3A/P3 (PFM 2026-11-13): one source for the gov task-script block; no task script asks for the DODID outside it.
out=$(python3 scripts/build_task_scripts.py --check 2>&1); [ $? -eq 0 ] && ok "task scripts share one block ($(echo "$out" | tail -1))" || { echo "$out"; bad "task-common block (run python3 scripts/build_task_scripts.py)"; }

# Task 11 Part B rows come from docs/rights-test-plan.md section 6 (one source; the RADE form step reads the JSON).
out=$(python3 scripts/build_rights_rows.py --check 2>&1 | tail -1); [ $? -eq 0 ] && echo "$out" | grep -q "stale=0" && ok "T11 Part B rows match the plan ($out)" || bad "T11 Part B rows stale: $out (run python3 scripts/build_rights_rows.py)"
# The RADE engine is downloaded by commit and checked by SHA-256 (scripts/rade.lock.json; PFM 2026-11-15). The tests always
# use the pinned engine: RADE_DIR is cleared, so a committed bundle from an override build shows as stale. Engine
# behavior is tested in rhope-ops/RADE (tests/engine_test.sh); the tests here use only this repo's bundle and files.
unset RADE_DIR
out=$(python3 scripts/bump_lock.py --test 2>&1); [ $? -eq 0 ] && ok "bump_lock release-lock checks ($out)" || { echo "$out"; bad "bump_lock release-lock checks"; }
out=$(python3 tests/test_rade_fetch.py 2>&1); [ $? -eq 0 ] && ok "RADE engine download failure cases ($(echo "$out" | tail -1))" || { echo "$out"; bad "RADE engine download failure cases"; }
out=$(python3 scripts/build_paste_bundles.py --check 2>&1 | tail -1)
# engine-v8 on: the header names every engine code file of the lock ("<file>, sha256 <12 hex>"); each must match (the engine file itself must be in the list, or nh counts 1).
# engine-v21 on: engine/rade_hash.py (build time only) is in the lock but not in the header; the stale check above covers it (the bundle must equal what the locked files build).
ef=$(python3 -c "import json;l=json.load(open('scripts/rade.lock.json'));c=[k for k in l['files'] if k.endswith(('.py','.ps1')) and k != 'engine/rade_hash.py'];print(' '.join(k+'='+l['files'][k][:12] for k in c) if l['engine'] in c else '')")
nh=0; [ -n "$ef" ] || nh=1; for f in $ef; do
  nh=$((nh + $(grep -L "${f%%=*}, sha256 ${f#*=}[;)]" scripts/gov/paste/*.ps1 | wc -l))); done
nb=$(python3 -c "import json;print(len(json.load(open('scripts/paste_bundles.json'))['bundles']))"); [ "$out" = "PASTE bundles=$nb stale=0" ] && [ "$nh" -eq 0 ] && ok "paste bundles current and built by the pinned engine ($out; bundles naming another engine: $nh)" || bad "paste bundles: $out; bundles naming another engine: $nh (run python3 scripts/build_paste_bundles.py with RADE_DIR not set)"
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
# needs <bundle>: the check ids the bundle's steps list in the manifest, space-separated.
needs() { python3 -c "import json,sys;print(' '.join(sorted({n for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']==sys.argv[1] for s in b['steps'] for n in s.get('needs',[])})))" "$1"; }
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
# Engine-v3 on (the PFM, 15 Nov 26: the newest RADE): RADE runs only on a computer whose own full name holds the NIPR
# domain label. The cloud has no such name, so the bundle tests give it a stand-in name, as RADE's own tests do
# (rhope-ops/RADE tests/engine_test.sh "swap"); the test after the loop proves the real guard stops this computer.
swap() { sed -e "s#Read-Host ('Type the number of the application to deploy (1 to ' + \\\$apps\\.Count + ') and press Enter')#'1'#" -e 's#^function Get-OwnFqdn .*#function Get-OwnFqdn { return '"'pc01.area52.example.invalid'"' }#' -e "s#^\$goUrl = '.*'#\$goUrl = 'file://$tp/go.md'#" -e "s#Url = 'https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/#Url = 'file://$PWD/#" -e "s#Url = 'https://www\.[^']*'#Url = 'file://$tp/fx.bin'#" -e "s#url = 'https://make\.powerautomate[^']*'#url = 'file://$tp/fx.bin'#I" -e "s#Read-Host 'Press Enter to start the round, or type N and press Enter to stop with no changes'#''#" -e "s#Read-Host 'Press Enter when the flow run has started, type F and Enter if it failed, or S and Enter to skip this step'#''#" -e "s#\$checkGate = \$true#\$checkGate = \$false#" -e "s#Read-Host 'Type the site address[^']*'#''#" -e "s#Read-Host 'Did you see both[^']*'#'Y'#" -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$tp/u'#" "$1"; }
for b in scripts/gov/paste/*.ps1; do
  fixture; swap "$b" > "$tp/b.ps1"; USERPROFILE="$tp/u/test1234" pwsh -NoProfile -File "$tp/b.ps1" > "$tp/out.txt" 2>&1
  # Text mode runs the default steps that need no folder (the optional steps are skipped).
  n=$(grep -c "^\$steps += @{.*Default = \$true; AskParam = '';" "$b")
  # A bundle with a second (deploy) application: text mode runs only the first one's steps (every R28 step is a default step).
  na=$(python3 -c "import json;b=[x for x in json.load(open('scripts/paste_bundles.json'))['bundles'] if x['out']=='$b'][0];a=b.get('apps') or [];print(len(a[0]['steps']) if len(a)>1 else -1)")
  [ "$na" -lt 0 ] || n=$na
  r=$(python3 -c "import json;print([b['round'] for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b'][0])")
  # R17 (PFM 14 Nov 26): the run moves the old 90-161.Z folder (the fixture) into OneDrive/RADE.
  base="$tp/u/test1234/OneDrive - United States Air Force/RADE/90-161.Z"; nb="$base"
  [ -d "$base/T13" ] && [ ! -e "$ob" ] && grep -q "^Moved the folder 90-161.Z into RADE" "$tp/out.txt" || { echo "RADE folder move"; ls "$tp/u/test1234/OneDrive - United States Air Force"; pf=$((pf+1)); }
  # Saved checks (R17): the run wrote RADE/Config/rade-checks.json with PASSED entries only and no DODID.
  ck="$tp/u/test1234/OneDrive - United States Air Force/RADE/Config/rade-checks.json"
  [ -f "$ck" ] && ! grep -q test1234 "$ck" && python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['schema']=='rade-checks/1' and d['maxAgeDays']==7 and d['checks'] and all(v['state']=='PASSED' for v in d['checks'].values()) and not ({'word','disk','write'} & set(d['checks']))" "$ck" || { echo "rade-checks.json"; cat "$ck"; pf=$((pf+1)); }
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
    if any(kind[a] == 'script' or a in want for a in s.get('after', [])): want.add(s['name'])
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
  [ "$st" -eq "$n" ] && [ "$sk" = "OK" ] && [ -f "$base/Rounds/$r/90161Z-$r-report-r1.txt" ] && grep -q "^Results folder: Rounds" "$base/Rounds/$r/90161Z-$r-report-r1.txt" && grep -q "full log" "$base/Rounds/$r/90161Z-$r-report-r1.txt" && pr=$((pr+1)) || { echo "round steps: $sk"; cat "$tp/out.txt" | tail -20; }
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
    && { [[ " $nd " != *" flow-guide "* ]] || grep -q "^  PASSED: You can import flows" "$tp/out.txt"; } || { echo "application or check lines missing in the report"; grep -E "^(Application|Checks|  [A-Z])" "$rp"; pf=$((pf+1)); }
  grep -q "^Note: no window could open, so the round runs in text mode" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "report does not name the no-window cause"; pf=$((pf+1)); }
  # Downloads: repo files must match their SHA-256; public files land and are attached; the skipped step's file is not expected.
  nf=$(python3 -c "import json;print(sum(len(b.get('fetch',[])) for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b'))")
  [ "$nf" -eq 0 ] || grep -q "^Downloads: $nf saved, 0 failed" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "downloads: want Downloads: $nf saved, 0 failed"; grep "^Downloads" "$base/Rounds/$r/90161Z-$r-report-r1.txt"; pf=$((pf+1)); }
  ! grep -q "90161Z-T11-partb-r1.txt" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "a skipped step's file was expected"; pf=$((pf+1)); }
  [ ! -e "$nb/T02" ] && [ ! -e "$nb/Rounds/R09" ] && [ ! -e "$nb/T07/90161Z-T07-seal-test-r4.ps1" ] && [ -f "$nb/T13/my-notes.docx" ] && [ ! -e "$nb/T13/90161Z-T13-label-capture-r2.ps1" ] \
    && [ -f "$nb/T07/90161Z-T07-key-r1.txt" ] && [ -f "$nb/T09/90161Z-T09-page-r1.htm" ] \
    && grep -qF "Clean-up: moved to the Recycle Bin: 5 files, 2 folders; kept (not made by 90-161.Z): 1 files; failed: 0." "$base/Rounds/$r/90161Z-$r-report-r1.txt" \
    && grep -qF "T13 1 (1 other)" "$base/Rounds/$r/90161Z-$r-report-r1.txt" && head -1 "$base/Rounds/$r/90161Z-$r-report-r1.txt" | tr -d "\r" | grep -q "90161Z $r NEEDS REVIEW$" \
    && grep -q "^\"$r\",\"ROUND\"," "$base/Config/90161Z-history.csv" && pc=$((pc+1)) || { echo "cleanup/summary"; grep -E "^(Clean-up|Files left|90161Z)" "$base/Rounds/$r/90161Z-$r-report-r1.txt"; ls -R "$nb" | head -30; }
  # Every file of this bundle equals its source (R29: each bundle in its own fixture, so the check runs per bundle).
  while IFS=$'\t' read -r dir src; do
    got="$tp/u/test1234/OneDrive - United States Air Force/RADE/90-161.Z/${dir//\\//}/$(basename "$src")"
    case "$src" in *.png|*.pptx|*.zip|*.docx|*.html) cmp -s "$got" "$src" || { echo "file differs: $src"; pf=$((pf+1)); };; *) cmp -s <(tail -c +4 "$got" | tr -d '\r') <(swap "$src") || { echo "file differs: $src"; pf=$((pf+1)); };; esac
  done < <(python3 -c "import json;[print(f['dir']+'\t'+f['src']) for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b' for f in b['files']]")
done
fi
# Newest RADE: scripts/rade_newest.py gives the verdict (OK, BEHIND, BEHINDNOTE, WRONGCOMMIT, NOTCHECKED; its header says
# why each one is a PASS, FAIL or NOTE). Behind is a FAIL only for a change that touches the lock or a round bundle.
rade_lock_verdict() {  # $1 = git ls-remote --tags output, $2 = lock tag, $3 = lock commit, $4 = changed files or *all*
  python3 scripts/rade_newest.py "$1" "$2" "$3" "$4"
}
fake_tags=$(printf '%s\trefs/tags/engine-v4\n%s\trefs/tags/engine-v5\n%s\trefs/tags/engine-v10\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb cccccccccccccccccccccccccccccccccccccccc)
[ "$(rade_lock_verdict "$fake_tags" engine-v10 cccccccccccccccccccccccccccccccccccccccc '*all*')" = "OK engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v5 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb '*all*')" = "BEHIND engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v5 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb "docs/a.md scripts/gov/paste/R1.ps1")" = "BEHIND engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v5 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb "docs/a.md scripts/gov/T20.ps1")" = "BEHINDNOTE engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v10 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb '*all*')" = "WRONGCOMMIT engine-v10" ] \
  && [ "$(rade_lock_verdict "" engine-v10 cccccccccccccccccccccccccccccccccccccccc '*all*')" = "NOTCHECKED" ] \
  && ok "newest-RADE check: verdicts (newest, behind, behind with no round change, wrong commit, no network)" || bad "newest-RADE check: verdicts"
if [ "${on[bundle]}" = 1 ]; then
tags=$(timeout 30 git ls-remote --tags https://github.com/rhope-ops/RADE 'refs/tags/engine-v*' 2>/dev/null || true)
lock_tag=$(python3 -c "import json;print(json.load(open('scripts/rade.lock.json')).get('tag',''))")
lock_commit=$(python3 -c "import json;print(json.load(open('scripts/rade.lock.json')).get('commit',''))")
rb=$(git merge-base HEAD origin/main 2>/dev/null) && rf=$( { g=(git -c core.quotePath=0); "${g[@]}" diff --name-only "$rb"; "${g[@]}" ls-files -o --exclude-standard; } 2>/dev/null) || rf='*all*'
verdict=$(rade_lock_verdict "$tags" "$lock_tag" "$lock_commit" "$rf")
case "$verdict" in
  OK*) ok "RADE engine is the newest release ($lock_tag, commit matches the tag)";;
  NOTCHECKED) echo "NOTE RADE engine newest-release check NOT RUN (no answer from github.com); lock = $lock_tag";;
  BEHINDNOTE*) echo "NOTE RADE engine is behind: lock = $lock_tag, newest release = ${verdict#BEHINDNOTE } (not a FAIL: no lock or round bundle changed)";;
  BEHIND*) bad "RADE engine is behind: lock = $lock_tag, newest release = ${verdict#BEHIND }. Run: python3 scripts/bump_lock.py ${verdict#BEHIND }, then build a new round";;
  *) bad "RADE lock commit is not the commit of $lock_tag. Run: python3 scripts/bump_lock.py $lock_tag";;
esac
else sk "RADE engine is the newest release (network)"; fi
if [ "${on[bundle]}" = 1 ]; then
# NIPR-only start check (RADE engine-v3 on; the PFM, 15 Nov 26): the bundle as shipped, on this computer (not NIPR), prints
# only the stop message and writes nothing.
for b in scripts/gov/paste/*.ps1; do
  g="$tp/guard"; rm -rf "$g"; mkdir -p "$g/test1234"
  go=$(sed -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$g'#" "$b" > "$tp/g.ps1"; USERPROFILE="$g/test1234" timeout 120 pwsh -NoProfile -File "$tp/g.ps1" 2>&1 < /dev/null)
  [ "$go" = "This application cannot be installed in your environment." ] && [ -z "$(find "$g" -type f)" ] && ok "NIPR-only start check: $(basename $b) stops on a computer that is not on NIPR and writes nothing" || { echo "$go" | head -3; bad "NIPR-only start check ($(basename $b))"; }
done
rm -rf "$tp"
nb=$(python3 -c "import json;print(len(json.load(open('scripts/paste_bundles.json'))['bundles']))"); [ $pr -eq "$nb" ] && [ $pf -eq 0 ] && ok "round bundle text mode: files exact, steps run, report in results folder, DODID masked, real path on screen (rounds=$pr mismatches=$pf)" || bad "round bundle: rounds ok=$pr mismatches=$pf"
[ $pc -eq "$nb" ] && ok "RADE cleanup: only 90-161.Z files recycled, other files and their folder kept, summary has the clean-up line, files left, subject NEEDS REVIEW, history row" || bad "RADE cleanup and summary (see output above)"
else sk "NIPR-only start check"; sk "round bundle text mode"; sk "RADE cleanup"; fi


# Enter starts the run (PFM 2026-11-13): in the window Enter is the card's primary button (on "Ready" that is Install or Run;
# never on a hand step: RADE "One thing" window, 14 Nov 26); text mode shows the plan, Enter runs, N stops with nothing written.
if [ "${on[bundle]}" = 1 ]; then
ab=$(grep -L 'AcceptButton = \$(if (\$c.NoAccept) { \$null } else { \$accept })' scripts/gov/paste/*.ps1 | wc -l)
# ... and on "Ready" the primary button is Install or Run and starts the run.
# engine-v8 on (dates "d MMM yy" in the saved-checks line): Run is primary unless RADE's Start button is ($startPrimary: the app has app.start and that version
# is installed). 90-161.Z has no app.start, so Run stays the primary button on Ready in every round.
ab=$((ab + $(grep -LF -e "-and -not \$startPrimary) { 'primary' }" scripts/gov/paste/*.ps1 | wc -l)))
ab=$((ab + $(grep -LF "else { 'off' }); Act = { & \$ui.Run }" scripts/gov/paste/*.ps1 | wc -l)))
python3 -c "import json,sys;d=json.load(open('scripts/paste_bundles.json'));sys.exit(1 if d['application'].get('start') else 0)" || ab=$((ab+1))
te=$(mktemp -d); mkdir -p "$te/u/test1234/OneDrive - United States Air Force"; tw=0
for b in scripts/gov/paste/*.ps1; do
  sed -e "s#Read-Host ('Type the number of the application to deploy (1 to ' + \\\$apps\\.Count + ') and press Enter')#'1'#" -e 's#^function Get-OwnFqdn .*#function Get-OwnFqdn { return '"'pc01.area52.example.invalid'"' }#' -e "s#Read-Host 'Press Enter to start the round, or type N and press Enter to stop with no changes'#'N'#" -e "s#Read-Host 'Type the site address[^']*'#''#" -e "s#Read-Host 'Did you see both[^']*'#'Y'#" -e "s#Url = 'https://make\.powerautomate[^']*'#Url = 'file:///dev/null'#" -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$te/u'#" "$b" > "$te/b.ps1"
  # PFM 14 Nov 26: with the check gate on, a FAILED or NOT RUN check stops the deploy before anything is written.
  # R17: the checks may save RADE/Config/rade-checks.json (shown on the Check screen); engine-v22 on also rade-checks-last.txt (PFM 19 Nov 26); nothing else.
  USERPROFILE="$te/u/test1234" pwsh -NoProfile -File "$te/b.ps1" > "$te/out.txt" 2>&1; [ -e "$te/u/test1234/OneDrive - United States Air Force/90-161.Z" ] && tw=$((tw+1))
  [ "$(cd "$te/u/test1234/OneDrive - United States Air Force" && find . -type f | sort | tr '\n' ' ')" = "./RADE/Config/rade-checks-last.txt ./RADE/Config/rade-checks.json " ] || { echo "files after N:"; find "$te/u" -type f; tw=$((tw+1)); }
  # The gate test needs a check that fails here: the SharePoint tool (manifest "needs" pnp). A round without it has no gate stop.
  nd=$(needs "$b")
  [[ " $nd " != *" pnp "* ]] || grep -q "^You cannot deploy yet: a check is FAILED or NOT RUN" "$te/out.txt" || { echo "check gate did not stop the deploy"; tw=$((tw+1)); }
  # Review R17 MAJOR 1: a fresh install (no 90-161.Z folder anywhere) finds OneDrive and can write there.
  grep -q "^  PASSED: Your OneDrive folder is set up" "$te/out.txt" && grep -q "^  PASSED: Files can be saved in OneDrive" "$te/out.txt" || { echo "fresh install: OneDrive checks"; grep "OneDrive" "$te/out.txt"; tw=$((tw+1)); }
  # Saved checks (R17, PFM 14 Nov 26): a second run uses the PASSED results saved by the first (OneDrive), and still runs the others (engine-v21 on: the PowerShell version check is one).
  USERPROFILE="$te/u/test1234" pwsh -NoProfile -File "$te/b.ps1" > "$te/out2.txt" 2>&1
  grep -q "^  PASSED: Your OneDrive folder is set up. Last check: $(LC_ALL=C date +"%-d %b %y")" "$te/out2.txt" && ! grep -q "^  PASSED: PowerShell is version 5.1 or newer. Last check:" "$te/out2.txt" && { [[ " $nd " != *" pnp "* ]] || grep -q "^  FAILED: The SharePoint tool" "$te/out2.txt"; } || { echo "saved checks not used on the second run"; grep "^  [A-Z]" "$te/out2.txt"; tw=$((tw+1)); }
done; rm -rf "$te"
[ "$ab" -eq 0 ] && [ "$tw" -eq 0 ] && ok "Enter starts the run (bundles where Enter is not the primary button or Ready has no primary Run: $ab; writes after N: $tw; Enter path = round bundle test)" || bad "Enter starts the run (bundles where Enter is not the primary button or Ready has no primary Run: $ab; writes after N: $tw)"
else sk "Enter starts the run"; fi

# No DODID question in rounds (PFM 2026-11-13): the profile folder is the DODID.
dq=0; for b in scripts/gov/paste/*.ps1; do sed -n '/round runner (generated/,$p' "$b" | grep -qE "Read-Host 'DODID|idBox" && dq=$((dq+1)); done
[ "$dq" -eq 0 ] && ok "rounds ask no DODID (bundles that ask: $dq)" || bad "rounds ask no DODID (bundles that ask: $dq)"
# R06 lesson: New-Object with a string for an enum argument can match two overloads ("Multiple ambiguous overloads") and
# drop the RADE window to text mode. Binding check in pwsh for every New-Object System.Drawing.Font call in the bundles.
if [ "${on[batch]}" = 1 ]; then
fa=$(grep -ohE "(New-Object System\.Drawing\.Font|\[System\.Drawing\.Font\]::new)\([^)]*,[^)]*, *[\"'][A-Za-z]+[\"'] *\)" scripts/gov/paste/*.ps1 | wc -l)
amb=$(bout font | tail -1)
[ "$fa" -eq 0 ] && [ "$amb" = "ambiguous" ] && ok "RADE fonts in the bundles: no string enum in Font() (found: $fa; pwsh confirms the string form is $amb)" || bad "RADE fonts in the bundles: string enum in Font() found=$fa (pwsh: $amb)"
# PFM 15 Nov 26 (enter the site once): Get-SiteAddress returns the address RADE holds, then the saved one, with no question.
sa=$(bout siteaddr | tail -1)
[ "$sa" = "https://fakeco.example/sites/one|https://fakeco.example/sites/two|ASKED|SITE ADDRESS not set" ] && ok "site address: from RADE, then from Config; with neither, a question outside RADE and a stop with the fix inside RADE" || { echo "$sa"; bad "site address: one entry"; }
else sk "RADE fonts in the bundles"; sk "site address: from RADE, then from Config"; fi
# R16: probe r5 grants Contribute to the coworker's own user (C01 ID), not to a group found by e-mail (R15: none found).
python3 -c "
import json; a = json.load(open('flow/defs/90161Z-T11-rights-probe-r5.json'))['actions']
assert 'principalid=@{body(\'C01\')?[\'Id\']}' in a['W11']['inputs']['parameters']['parameters/uri']
assert 'getuserbyid(@{body(\'C01\')' in a['G04']['inputs']['parameters']['parameters/uri'] and 'G04_read' not in a and 'G06_counts' in a
assert list(a).index('C01') < list(a).index('G04') < list(a).index('W11')" && ok "probe r5: W11 grants the C01 user ID; G04 by user ID; G06 counts" || bad "probe r5 W11/C01/G04/G06"
# R05 (PFM 2026-11-13): every bundle makes an Outlook draft and never sends it; off Windows it falls back to folder + clipboard.
nd=$(grep -L 'ComObject Outlook.Application' scripts/gov/paste/*.ps1 | wc -l); ns=$(grep -ciE '\.Send\(|\.Send\b *$' scripts/gov/paste/*.ps1 | awk -F: '{s+=$NF} END{print s+0}')
fb=0; for b in scripts/gov/paste/*.ps1; do grep -q "Outlook draft could not be created" "$b" || fb=1; done
[ "$nd" -eq 0 ] && [ "$ns" -eq 0 ] && [ "$fb" -eq 0 ] && ok "Outlook draft step, never sent (bundles without draft: $nd; Send calls: $ns; fallback present)" || bad "Outlook draft step (without draft: $nd; Send calls: $ns; fallback rc=$fb)"

# T19 r4 adds to an existing site the same column XML and choices T20 builds a new site with (one source: schemas/lists; S3 A: T-0).
python3 - <<'PYEOF' && ok "T19 list update: column XML and the Action Status and Tier choices (T-0 first) match schemas/lists" || bad "T19 list update differs from schemas/lists"
import json, re, sys
sys.path.insert(0, 'scripts'); import build_flow_payload as B
s = B.load(); t = re.sub(r"' \+\s+'", '', open('scripts/gov/90161Z-T19-list-update-r6.ps1', encoding='utf-8').read())   # r6: a long XML is joined from parts
rows = re.findall(r"@\{ List = '([^']+)'; Name = '(\w+)'\s+Xml = \(?'([^']+)'\)? \}", t)
assert len(rows) == 4, rows
by_title = {v['title']: v for v in s.values()}
for title, name, xml in rows:
    assert B.field_xml([x for x in by_title[title]['fields'] if x['internalName'] == name][0]) == xml, (name, xml)
got = re.findall(r"@\{ List = '([^']+)'; Field = '(\w+)'; Choices = @\(([^)]*)\) \}", t)
assert [(a, b) for a, b, _ in got] == [('PFM Publications', 'ActionStatus'), ('PFM Waivers', 'Tier'), ('PFM Activity Log', 'EventType')] and 'T-0' in got[1][2], got
for title, name, ch in got:
    assert [c.strip().strip("'") for c in ch.split(',')] == [x for x in by_title[title]['fields'] if x['internalName'] == name][0]['choices'], ch
PYEOF
# T22 PFM window test r10 (R37; R35 W7; R34 W1; R32 defects W1 to W3): the cards and the 18 checks as text (-PlanOnly; no window here; the window: tests/ps/Test-T22Layout.ps1).
# Every button, link and grid row goes to a card that exists (or 'back', '@grid', '@note'), each card has one blue button, the text is ASCII and FAKE,
# r1 to r9 are gone, r10 is the main file and its parts (no other), no '0 findings' link (V3), the UI block is current, the colors are docs/palette.json tokens.
if [ "${on[t22]}" = 1 ]; then
python3 - <<'PYT22' && ok "T22 window preview cards (r10)" || bad "T22 window preview cards (r10)"
import json, re, subprocess, pathlib
f = 'scripts/gov/90161Z-T22-pfm-window-r10.ps1'; g = pathlib.Path('scripts/gov'); pp = lambda n: g / ('90161Z-T22-%s-r10.ps1' % n)
assert not [x.name for x in g.glob('90161Z-T22-*-r[1-9].ps1')], 'an older revision is still there'
parts = [x.strip().strip("'") for x in re.search(r"\$Parts = @\(([^)]*)\)", pathlib.Path(f).read_text()).group(1).split(',')]
out = subprocess.run(['pwsh', '-NoProfile', '-File', f, '-PlanOnly'], capture_output=True, text=True, timeout=120).stdout.splitlines()
m = re.match(r'PLAN cards=(\d+)$', out[-1] if out else ''); assert m, out[-3:]
cards = [l.split(' | ')[0][5:] for l in out if l.startswith('CARD ')]
assert len(cards) == int(m.group(1)) >= 15, cards
need = {'home', 'empty', 'queue', 'reviews', 'step8', 'confirm', 'waves', 'step11', 'step12', 'step13', 'pub', 'settings', 'loading', 'failed', 'noperm'}
assert need <= set(cards), need - set(cards)
ok_extra = {'back', '@grid', '@note'}
for l in out:
    t = re.match(r'\s+(?:BUTTON|CHOICE|LINK) .+ -> (\S+)', l) or re.match(r'RAIL .+ -> (\S+)', l)
    if t: assert t.group(1) in cards or t.group(1) in ok_extra, l
blue = [b.count('(blue)') for b in '\n'.join(out).split('\nCARD ')]; assert len(blue) == len(cards) and set(blue) == {1}, blue   # one blue button per card
text = '\n'.join(out); assert all(ord(c) < 128 for c in text)
src = ''.join(x.read_text() for x in [pp(n) for n in parts[:3]] + [pathlib.Path(f)] + [pp(n) for n in parts[3:]])   # load order
assert all(ord(c) < 128 for c in src)
assert not [i + 1 for i, l in enumerate(src.splitlines()) if l.startswith("'@")], 'a line starts with \'@ (here-string)'
for l in out:   # every publication, office and person name says FAKE
    for w in re.findall(r'(?<!FAKE )(?<!DAF )\b(OI \d\d-\d+|Instruction \d\d-\d+|Form \d+|Office \d|AO \d)\b', l): raise AssertionError(l)
assert 'FAKE' in text and 'RAIL Your Work' in text and 'RAIL Settings' in text and 'See the 0 findings' not in text and len([l for l in out if l.startswith('RAIL ')]) == 5
# the 18 in-window checks (PFM 17 Nov 26; R31 W3 adds crumb and status, R6 chip and pubcol, R7 wheel and pubnum): numbered lines in order, with their keys, each text at most 160 characters
keys = ['card-open', 'first-button', 'all-cards', 'tab', 'shift-tab', 'enter', 'narrator-on', 'narrator-names', 'narrator-off', 'contrast-on', 'contrast-read', 'contrast-off', 'crumb', 'status', 'chip', 'pubcol', 'wheel', 'pubnum']
chk = [re.match(r'CHECK (\d+) ([a-z-]+): (.+)$', l) for l in out if re.match(r'CHECK \d+ ', l)]
assert len(chk) == 18 and all(chk) and [m.group(2) for m in chk] == keys and [int(m.group(1)) for m in chk] == list(range(1, 19)), [m.group(0) for m in chk]
assert all(len(m.group(3)) <= 160 for m in chk), [len(m.group(3)) for m in chk]
# the rade-ui block is not empty, and the colors painted here are the palette tokens
assert re.search(r'# >>> rade-ui:[^\n]*\n# RADE shared UI file[\s\S]*\n\$ui\.C = ', src), 'rade-ui block missing'
after = src.split('# <<< rade-ui', 1)[1]
assert re.search(r'\$ui\.B\s*=\s*@\(\)', after) and re.search(r'\$ui\.P\s*=\s*@\(\)', after), '$ui.B and $ui.P must be set outside the rade-ui block'
assert 'SetProcessDPIAware' in src, 'the window is not DPI aware'
assert "$Rev = 'r10'" in src and sorted(x.name for x in g.glob('90161Z-T22-*-r10.ps1')) == sorted(pp(n).name for n in parts + ['pfm-window']), parts
grids = len(re.findall(r'New-Object System.Windows.Forms.DataGridView\b(?!\w)', src))
assert grids >= 1 and src.count("$g.AutoSizeColumnsMode='Fill'") == grids and src.count("$dc.AutoSizeMode='Fill'") >= 1, 'every grid fills its columns'
pal = json.loads(pathlib.Path('docs/palette.json').read_text())['tokens']
hexes = dict(re.findall(r"(\w+)\s*=\s*'([0-9A-F]{6})'", re.search(r'\$PalHex\s*=\s*@\{(.*?)\}', src, re.S).group(1)))
for k, v in hexes.items(): assert pal[k.replace('white', 'white')] == v, (k, v, pal.get(k))
# -Opened (the look questions' gate in the round): fake result files opened / not opened / STOPPED / 4 hours old; one line, no other file
import tempfile, os, time; d = tempfile.mkdtemp(); w = pathlib.Path(d, '90161Z-T22-window-r10.txt'); got = {}
for k, body in {'open': 'CARDS opened: home, step8 (17 of 17)\nPASS layout', 'none': 'CARDS opened: none (0 of 17)', 'stop': 'CARDS opened: home (1 of 17)\nSTOPPED: no window (x)', 'old': 'CARDS opened: home, step8 (17 of 17)'}.items():
    w.write_text(body + '\n'); k == 'old' and os.utime(w, (time.time() - 4 * 3600,) * 2); r = subprocess.run(['pwsh', '-NoProfile', '-File', f, '-Opened', '-TestDir', d], capture_output=True, text=True, timeout=60); got[k] = (r.stdout.strip(), r.returncode)
assert got == {'open': ('PASS the window opened (17 of 17 cards)', 0), 'none': ('FAIL the window did not open', 1), 'stop': ('FAIL the window did not open', 1), 'old': ('FAIL the window did not open (no result from this round)', 1)} and len(list(pathlib.Path(d).iterdir())) == 1, got
PYT22
else sk "T22 window preview cards (r10)"; fi
# Guide text (AGENTS.md "Gov-device usability" point 3, PFM 2026-11-16): every step passes, no baseline.
python3 tests/check_guide_text.py --test >/dev/null && ok "guide text self-test" || bad "guide text self-test"
gt=$(python3 tests/check_guide_text.py) && ok "guide text ($(echo "$gt" | tail -1))" || { echo "$gt"; bad "guide text: a step points elsewhere, holds 2 actions or is over 200 characters"; }
gp=$(node tests/check_go_page.js) && ok "bookmark page renderer ($(echo "$gp" | tail -1))" || { echo "$gp"; bad "bookmark page renderer (tests/check_go_page.js)"; }
if [ "${on[lint]}" = 1 ]; then wait "$lint_pid" && ok "lint ($(tail -1 "$bg/lint.out"))" || { cat "$bg/lint.out"; bad "lint"; }; else sk "lint"; fi
[ "$lane" = fast ] && echo "TESTS pass=$pass fail=$fail skip=$skipped (fast lane)" || echo "TESTS pass=$pass fail=$fail"
[ $fail -eq 0 ]
