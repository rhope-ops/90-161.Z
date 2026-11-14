#!/usr/bin/env bash
# 90-161.Z test runner (agent workspace). Pass = last line "TESTS pass=N fail=0", exit 0.
# Word COM and PnP cannot run here; those parts are tested on the gov device (docs/gov-test-plan.md).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
pass=0; fail=0
ok()  { echo "PASS $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }

python3 scripts/bloat_check.py --test >/tmp/bloat.out 2>&1 && ok "bloat_check self-test" || { cat /tmp/bloat.out; bad "bloat_check self-test"; }

scripts/lint.sh >/tmp/lint.out 2>&1 && ok "lint ($(tail -1 /tmp/lint.out))" || { cat /tmp/lint.out; bad "lint"; }

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
pwsh -NoProfile -File tests/ps/Invoke-Validations.ps1 -List "$vd/list.txt" -OutDir "$vd"
vout() { cat "$vd/$1.out"; [ -f "$vd/$1.err" ] && cat "$vd/$1.err" >&2; true; }
vrc() { cat "$vd/$1.rc"; }

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

for f in samples/publication.sample.json tests/fixtures/bad.publication.json schemas/publication.schema.json schemas/lists/*.json flow/provisioning-payload.json; do
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" && ok "json $f" || bad "json $f"
done

n20=$(vout f020 | grep -c "^FAIL F-020 meta.accessibilityLink")
[ "$n20" -eq 2 ] && ok "F-020 accessibility link checks (bad text and bad url: $n20 FAIL)" || bad "F-020 accessibility link checks ($n20 FAIL, want 2)"
python3 - <<'PY' && ok "sample matches JSON schema" || bad "sample matches JSON schema"
import json, sys
try:
    import jsonschema
except ImportError:
    print("jsonschema not installed"); sys.exit(1)
jsonschema.validate(json.load(open('samples/publication.sample.json')), json.load(open('schemas/publication.schema.json')))
PY

grep -q "\$nb = \$t.Replace('-', \[string\]\[char\]30)" scripts/gov/New-Publication.ps1 && ok "tier numbers use a Word nonbreaking hyphen (T01 r4)" || bad "tier nonbreaking hyphen"
[ "$(ls scripts/gov/90161Z-T01-renderer-test-r*.ps1 | wc -l)" -eq 1 ] && ok "one T01 runner revision" || bad "more than one T01 runner"

out=$(vout placeholder); rc=$(vrc placeholder)
got=$(echo "$out" | grep -oE '^FAIL [A-Z]+-?[0-9]*' | awk '{print $2}' | sort -u | tr '\n' ' ')
[ $rc -eq 1 ] && [ "$got" = "X-001 " ] && ok "placeholder fixture fails on X-001 only" || { echo "got: $got"; bad "placeholder fixture"; }
python3 scripts/build_messy_draft.py --check && ok "T06 messy draft up to date" || bad "T06 messy draft stale"
for k in ComplianceBefore ComplianceRuleDist ReleaseRuleDist BlockRuleBefore GroupBlankLine TocFontSize; do
  grep -q "^\$$k = " scripts/gov/New-Publication.ps1 || { bad "renderer constant $k (L-008a, L-010c, L-012)"; continue; }
done && ok "renderer cover and TOC constants present (L-008a, L-010c, L-012)"

python3 scripts/build_test_seals.py --check && ok "T07 test seals up to date" || bad "T07 test seals stale"
sealraw=$(mktemp -d); python3 scripts/build_test_seals.py --raw "$sealraw" >/dev/null
out=$(pwsh -NoProfile -File tests/ps/Test-SealTrim.ps1 -RawDir "$sealraw"); rc=$?; rm -rf "$sealraw"
[ $rc -eq 0 ] && [ "$(echo "$out" | grep -c '^PASS')" -eq 4 ] && ok "seal trim matches the reference on 4 test seals (L-007a)" || { echo "$out"; bad "seal trim"; }
out=$(vout seal); rc=$(vrc seal)
got=$(echo "$out" | grep -oE '^FAIL [A-Z]+-?[0-9a-z]*' | awk '{print $2}' | sort -u | tr '\n' ' ')
[ $rc -eq 1 ] && [ "$got" = "L-007a " ] && ok "unprepared seal fails on L-007a only" || { echo "got: $got"; bad "seal fixture"; }
out=$(vout sealok); rc=$(vrc sealok)
[ $rc -eq 0 ] && echo "$out" | tail -1 | grep -q '^VALIDATE fails=0 ' && ok "prepared seal path accepted (L-007a)" || { echo "$out" | grep FAIL; bad "prepared seal path"; }
grep -q '$pic.Width = \[single\]$ShieldWidth; $pic.Height = \[single\]$ShieldWidth' scripts/gov/New-Publication.ps1 && ok "renderer places seals in the 1.20 in box (L-007)" || bad "renderer seal box"
grep -q "Write-Output ('RENDER-ERROR line '" scripts/gov/New-Publication.ps1 && grep -q "exit 3 }" scripts/gov/New-Publication.ps1 && ok "renderer names the failing line and flags FORMAT-FAIL (T06/T07 cast error)" || bad "renderer error line"

python3 scripts/build_flow_payload.py --check >/dev/null && ok "flow payload up to date" || bad "flow payload stale"
python3 tests/check_palette.py >/dev/null && ok "palette contrast (WCAG AA)" || bad "palette contrast"
python3 scripts/build_rights_probe.py --check >/dev/null && ok "rights probe def up to date" || bad "rights probe def stale"
python3 scripts/build_flow_package.py --check && ok "flow packages up to date" || bad "flow packages stale"
python3 tests/check_flow_package.py && ok "flow packages match real export shape" || bad "flow package shape"
python3 tests/check_flow_defs.py && ok "flow def names and expressions" || bad "flow def names or expressions"
python3 scripts/build_flow_solution.py --check >/dev/null && python3 tests/check_flow_solution.py >/dev/null && ok "flow solution up to date and valid" || bad "flow solution stale or invalid"
# R15-R17 (PFM 14 Nov 26): each solution import test is its own solution (PFM90161ZTEST + variant), one flow, XML valid, T05
# export values; r3: A has no environment variable, B has Site URL only; no environmentvariabledefinition.xml has an XML declaration.
python3 - <<'PYEOF' && ok "solution import test zips valid (A: no variable, B: 1 variable without declaration)" || bad "solution import test zips"
import zipfile, glob, xml.dom.minidom as md
zips = sorted(glob.glob('flow/solution/90161Z-T17-solution-test-*-r3.zip')) + ['flow/solution/90161Z-flows-solution-r1.zip']
assert len(zips) == 3, zips
for path in zips:
    z = zipfile.ZipFile(path); n = z.namelist()
    for f in n:
        if f.endswith('.xml'): md.parseString(z.read(f))
        if f.startswith('environmentvariabledefinitions/'): assert not z.read(f).startswith(b'<?xml'), f
    if 'T17' not in path: continue
    v = path.split('-test-')[1][0].upper(); s = z.read('solution.xml').decode(); c = z.read('customizations.xml').decode()
    assert f'<UniqueName>PFM90161ZTEST{v}</UniqueName>' in s and 'OrganizationVersion="9.2.26094.172"' in s and '<UniqueName>PFM</UniqueName>' in s
    assert sum(f.startswith('Workflows/') for f in n) == 1
    assert sum(f.startswith('environmentvariabledefinitions/') for f in n) == {'A': 0, 'B': 1}[v]
    assert '<StateCode>1</StateCode>' in c and '<StatusCode>2</StatusCode>' in c and '<ModernFlowType>0</ModernFlowType>' in c
    assert '"runtimeSource": "invoker"' in z.read([f for f in n if f.startswith('Workflows/')][0]).decode()
PYEOF
python3 tests/check_names.py && ok "naming rules (PFM 2026-11-11)" || bad "naming rules"
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
assert len(p['rows']) == 88  # 39 series + 7 settings + 29 offices (22 A3.2 + 7 mandatory, Q13 and 4.2A) + 13 process steps
assert 'PFMProductIndex' in p['lookupPlaceholders'] and p['listOrder'][-1] == 'PFMReviews'
lo = p['listOrder']; assert lo.index('PFMProductIndex') < lo.index('PFMPublications') < lo.index('PFMReviews'), lo
gv = [r for r in p['fields'] if r['body'].get('Title') == 'PFM - Prescribed Forms by Publication']
q = gv[0]['body']['ViewQuery']
assert q.index('<Where>') < q.index('<GroupBy') < q.index('<OrderBy>'), q
assert [r['body']['__metadata']['type'] for r in p['rows']].count('SP.Data.PFMSeriesListItem') == 39
st = {r['body']['Title']: r['body']['SettingValue'] for r in p['rows'] if r['body']['__metadata']['type'] == 'SP.Data.PFMSettingsListItem'}
assert st == {'CoordinationSuspenseBusinessDays': '15', 'GuardReserveApplicabilityCalendarDays': '30', 'PublicationsSiteName': '', 'PublicationsListUrl': '', 'PFMOfficeMailbox': '', 'EscalationWeekdays': '', 'RecordsFreeze': ''}, st
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

out=$(pwsh -NoProfile -File scripts/gov/Provision-Lists.ps1 -PlanOnly -SchemaPath schemas/lists 2>&1 | tail -1)
[ "$out" = "PLAN lists=12 fields=196 views=18" ] && ok "lists plan ($out)" || bad "lists plan: $out"

node templates/build_crm_template.js >/tmp/crm.out 2>&1 && grep -q "tableWidthDXA=9331 columns=9" /tmp/crm.out && ok "CRM template builds ($(cat /tmp/crm.out | sed s,.*CRM_A12-1.docx,,))" || bad "CRM template build"
# Build is deterministic (fixed dates): a rebuild must match the committed file byte for byte.
git diff --quiet HEAD -- templates/CRM_A12-1.docx && ok "CRM template rebuild matches committed file" || bad "CRM template rebuild differs from committed file (commit the rebuild if the source changed)"

got=$(pwsh -NoProfile -c '. ./scripts/gov/Publication.Common.ps1; ConvertTo-TwoSpaceSentence "Do this. (T-3) Then Mr. A. B. Smith signs. Use e.g. Forms. Done? Yes."')
want="Do this. (T-3)  Then Mr. A. B. Smith signs.  Use e.g. Forms.  Done?  Yes."
[ "$got" = "$want" ] && ok "two-space sentences (L-004)" || { echo "got:  [$got]"; echo "want: [$want]"; bad "two-space sentences"; }

got=$(pwsh -NoProfile -c '. ./scripts/gov/Publication.Common.ps1; $p = Get-Content samples/publication.sample.json -Raw | ConvertFrom-Json; Get-OpeningParagraph $p' | grep -o -E "implements|Ensure all records|DAF Form 847|may be supplemented|authorities to waive" | tr '\n' ',')
[ "$got" = "implements,Ensure all records,DAF Form 847,may be supplemented,authorities to waive," ] && ok "opening paragraph order (4.5.5)" || { echo "got: $got"; bad "opening paragraph order"; }

! grep -rniE "@us\.af\.mil|@mail\.mil|usaf\.dps\.mil/sites/[a-z0-9]" samples tests schemas docs scripts flow templates/build_crm_template.js >/dev/null && ok "no .mil addresses in repo content" || bad "no .mil addresses"

# Rule source = the approved DAFMAN edition (docs/DECISIONS.md 2026-11-10): ref/ files must match ref/SHA256SUMS (bloat audit 2026-11-13).
out=$(cd ref && sha256sum -c --quiet SHA256SUMS 2>&1) && ok "ref files match ref/SHA256SUMS" || { echo "$out"; bad "ref files match ref/SHA256SUMS"; }

# F-032/F-039 false positives (T06 review 12 Nov 26): cover values count as use; office symbols and AFI-type prefixes skip the
# four-times rule; the fixed summary-of-changes sentence is not a compliance statement. Sample: only OPR and ANG warn.
out=$(pwsh -NoProfile -File scripts/gov/Test-Publication.ps1 -Path samples/publication.sample.json 2>&1 | grep -E "^WARN F-032|^VALIDATE")
echo "$out" | grep -q "VALIDATE fails=0 warns=2" && ! echo "$out" | grep -qE "'(OPR-A|OPR-B|AFI)'" && ok "validator F-032 false positives gone (sample warns=2: OPR, ANG)" || { echo "$out"; bad "validator F-032 false positives"; }
# B3A/P3 (PFM 2026-11-13): one source for the gov task-script block; no task script asks for the DODID outside it.
out=$(python3 scripts/build_task_scripts.py --check 2>&1); [ $? -eq 0 ] && ok "task scripts share one block ($(echo "$out" | tail -1))" || { echo "$out"; bad "task-common block (run python3 scripts/build_task_scripts.py)"; }

# Task 11 Part B rows come from docs/rights-test-plan.md section 6 (one source; the Deployer form reads the JSON).
out=$(python3 scripts/build_rights_rows.py --check 2>&1 | tail -1); [ $? -eq 0 ] && echo "$out" | grep -q "stale=0" && ok "T11 Part B rows match the plan ($out)" || bad "T11 Part B rows stale: $out (run python3 scripts/build_rights_rows.py)"
out=$(python3 scripts/build_paste_bundles.py --check 2>&1 | tail -1)
[ "$out" = "PASTE bundles=1 stale=0" ] && ok "paste bundles current ($out)" || bad "paste bundles: $out (run python3 scripts/build_paste_bundles.py)"

# Round bundle end to end in pwsh (Linux, text mode: no Windows Forms): profile folder and C:\Users swapped for a temp root.
# Every written file must equal its source (text: BOM and CR removed); each step must start as a child process (on Linux
# the runner stops at Unblock-File, so its step reads CHECK); the results folder must hold the report (summary + full
# log) with no DODID. The window path (Windows Forms) cannot run here: lint only.
tp=$(mktemp -d); mkdir -p "$tp/u/test1234/OneDrive - United States Air Force"; pf=0; pr=0; pc=0
# R06 cleanup fixture: finished folders with our files and one file 90-161.Z did not make (must stay).
ob="$tp/u/test1234/OneDrive - United States Air Force/90-161.Z"; mkdir -p "$ob/T02" "$ob/T13" "$ob/Rounds/R09" "$ob/T07" "$ob/T09"
touch "$ob/T02/90161Z-T02-provision-lists-r9.zip" "$ob/T02/Provision-Lists.ps1" "$ob/T13/90161Z-T13-label-capture-r2.ps1" "$ob/T13/my-notes.docx" \
  "$ob/Rounds/R09/90161Z-R09-report-r1.txt" "$ob/T07/90161Z-T07-seal-test-r4.ps1" "$ob/T07/90161Z-T07-key-r1.txt" "$ob/T09/90161Z-T09-page-r1.htm"
echo "public sample" > "$tp/fx.bin"; printf '## Fix first: Round R99 r1, test (open, 1 Jan 26)\n' > "$tp/go.md"
swap() { sed -e "s#^\$goUrl = '.*'#\$goUrl = 'file://$tp/go.md'#" -e "s#Url = 'https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/#Url = 'file://$PWD/#" -e "s#Url = 'https://www\.[^']*'#Url = 'file://$tp/fx.bin'#" -e "s#url = 'https://make\.powerautomate[^']*'#url = 'file://$tp/fx.bin'#I" -e "s#Read-Host 'Press Enter to start the round, or type N and press Enter to stop with no changes'#''#" -e "s#Read-Host 'Press Enter when the flow run has started, or type S and press Enter to skip this step'#''#" -e "s#\$checkGate = \$true#\$checkGate = \$false#" -e "s#Read-Host 'Type the site address[^']*'#''#" -e "s#Read-Host 'Did you see both[^']*'#'Y'#" -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$tp/u'#" "$1"; }
for b in scripts/gov/paste/*.ps1; do
  swap "$b" > "$tp/b.ps1"; USERPROFILE="$tp/u/test1234" pwsh -NoProfile -File "$tp/b.ps1" > "$tp/out.txt" 2>&1
  # Text mode runs the default steps that need no folder (the optional steps are skipped).
  n=$(python3 -c "import json,pathlib;f='scripts/build_paste_bundles.py';ns={'__file__':str(pathlib.Path(f).resolve())};exec(open(f).read().split(chr(10)+'def here')[0],ns);print(sum(1 for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b' for s in b['steps'] if ns['step_default'](s) and 'ask' not in s))")
  r=$(python3 -c "import json;print([b['round'] for b in json.load(open('scripts/paste_bundles.json'))['bundles'] if b['out']=='$b'][0])")
  # R17 (PFM 14 Nov 26): the run moves the old 90-161.Z folder (the fixture) into OneDrive/RADE.
  base="$tp/u/test1234/OneDrive - United States Air Force/RADE/90-161.Z"; nb="$base"
  [ -d "$base/T13" ] && [ ! -e "$ob" ] && grep -q "^Moved the folder 90-161.Z into RADE" "$tp/out.txt" || { echo "RADE folder move"; ls "$tp/u/test1234/OneDrive - United States Air Force"; pf=$((pf+1)); }
  # Saved checks (R17): the run wrote RADE/Config/rade-checks.json with PASSED entries only and no DODID.
  ck="$tp/u/test1234/OneDrive - United States Air Force/RADE/Config/rade-checks.json"
  [ -f "$ck" ] && ! grep -q test1234 "$ck" && python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['schema']=='rade-checks/1' and d['maxAgeDays']==7 and d['checks'] and all(v['state']=='PASSED' for v in d['checks'].values())" "$ck" || { echo "rade-checks.json"; cat "$ck"; pf=$((pf+1)); }
  st=$(grep -c '^Step [0-9]* of [0-9]*: ' "$tp/out.txt"); sm=$(grep -c '^  Result: \(PASSED\|NEEDS REVIEW\) (' "$tp/out.txt")
  [ "$st" -eq "$n" ] && [ "$sm" -eq "$n" ] && [ -f "$base/Rounds/$r/90161Z-$r-report-r1.txt" ] && grep -q "^Results folder: Rounds" "$base/Rounds/$r/90161Z-$r-report-r1.txt" && grep -q "full log" "$base/Rounds/$r/90161Z-$r-report-r1.txt" && pr=$((pr+1)) || { cat "$tp/out.txt" | tail -20; }
  # The screen shows the real path (PFM 13 Nov); everything else, and the report, masks it.
  ! { grep -v '^Working folder: ' "$tp/out.txt" | grep -q "test1234"; } && ! grep -q "test1234" "$base/Rounds/$r/90161Z-$r-report-r1.txt" || { echo "DODID not masked"; pf=$((pf+1)); }
  grep -q "^Working folder: $tp/u/test1234/" "$tp/out.txt" || { echo "real path not shown"; pf=$((pf+1)); }
  grep -q "^What to do: Open Outlook" "$tp/out.txt" || { echo "no plain-words help after the draft fallback"; pf=$((pf+1)); }
  grep -q "^A newer round, R99, is in the repository" "$tp/out.txt" || { echo "newer-round banner missing"; pf=$((pf+1)); }
  # Choose and Check screens (PFM 14 Nov 26): the report names the application and counts the checks; text mode cannot
  # sign in, so the sign-in check is NOT RUN, and no check line holds the DODID.
  rp="$base/Rounds/$r/90161Z-$r-report-r1.txt"
  grep -q "^Application: " "$rp" && tr -d "\r" < "$rp" | grep -qE "^Checks\. Passed: [0-9]+\. Warnings: [0-9]+\. Failed: [0-9]+\. Not run: [0-9]+\.$" && grep -q "^  NOT RUN: You can change the site" "$rp" && grep -q "^  PASSED: You can import flows" "$tp/out.txt" || { echo "application or check lines missing in the report"; grep -E "^(Application|Checks|  [A-Z])" "$rp"; pf=$((pf+1)); }
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
done
while IFS=$'\t' read -r dir src; do
  got="$tp/u/test1234/OneDrive - United States Air Force/RADE/90-161.Z/${dir//\\//}/$(basename "$src")"
  case "$src" in *.png|*.pptx|*.zip) cmp -s "$got" "$src" || pf=$((pf+1));; *) cmp -s <(tail -c +4 "$got" | tr -d '\r') <(swap "$src") || pf=$((pf+1));; esac
done < <(python3 -c "import json;[print(f['dir']+'\t'+f['src']) for b in json.load(open('scripts/paste_bundles.json'))['bundles'] for f in b['files']]")
rm -rf "$tp"
[ $pr -eq 1 ] && [ $pf -eq 0 ] && ok "round bundle text mode: files exact, steps run, report in results folder, DODID masked, real path on screen (rounds=$pr mismatches=$pf)" || bad "round bundle: rounds ok=$pr mismatches=$pf"
[ $pc -eq 1 ] && ok "Deployer cleanup: only 90-161.Z files recycled, other files and their folder kept, summary has the clean-up line, files left, subject NEEDS REVIEW, history row" || bad "Deployer cleanup and summary (see output above)"

# Two bars (PFM 14 Nov 26): progress math and the PROGRESS line rule, from the bundle's own functions (review PR 26).
pg=$(pwsh -NoProfile -File tests/ps/Test-DeployerProgress.ps1 -Bundle scripts/gov/paste/90161Z-R17-round-r1.ps1 2>&1)
[ "$(echo $pg)" = "0.10 0.28 101 | -1 0.375 | True True False gate False True True True" ] && ok "Deployer progress math, PROGRESS lines and the check gate ($(echo $pg))" || bad "Deployer progress math: got '$pg'"

# Enter starts the run (PFM 2026-11-13): the window's AcceptButton is Run; text mode shows the plan, Enter runs, N stops with nothing written.
ab=$(grep -L 'AcceptButton = \$run' scripts/gov/paste/*.ps1 | wc -l)
te=$(mktemp -d); mkdir -p "$te/u/test1234/OneDrive - United States Air Force"; tw=0
for b in scripts/gov/paste/*.ps1; do
  sed -e "s#Read-Host 'Press Enter to start the round, or type N and press Enter to stop with no changes'#'N'#" -e "s#Read-Host 'Type the site address[^']*'#''#" -e "s#Read-Host 'Did you see both[^']*'#'Y'#" -e "s#Url = 'https://make\.powerautomate[^']*'#Url = 'file:///dev/null'#" -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$te/u'#" "$b" > "$te/b.ps1"
  # PFM 14 Nov 26: with the check gate on, a FAILED or NOT RUN check stops the deploy before anything is written.
  # R17: the checks may save RADE/Config/rade-checks.json (shown on the Check screen); nothing else may exist.
  USERPROFILE="$te/u/test1234" pwsh -NoProfile -File "$te/b.ps1" > "$te/out.txt" 2>&1; [ -e "$te/u/test1234/OneDrive - United States Air Force/90-161.Z" ] && tw=$((tw+1))
  [ "$(cd "$te/u/test1234/OneDrive - United States Air Force" && find . -type f | sort | tr '\n' ' ')" = "./RADE/Config/rade-checks.json " ] || { echo "files after N:"; find "$te/u" -type f; tw=$((tw+1)); }
  grep -q "^You cannot deploy yet: a check is FAILED or NOT RUN" "$te/out.txt" || { echo "check gate did not stop the deploy"; tw=$((tw+1)); }
  # Saved checks (R17, PFM 14 Nov 26): a second run uses the PASSED results saved by the first, and still runs the others.
  USERPROFILE="$te/u/test1234" pwsh -NoProfile -File "$te/b.ps1" > "$te/out2.txt" 2>&1
  grep -q "^  PASSED: PowerShell is version 5.1 or newer. Saved result from today" "$te/out2.txt" && grep -q "^  FAILED: The SharePoint tool" "$te/out2.txt" || { echo "saved checks not used on the second run"; grep "^  [A-Z]" "$te/out2.txt"; tw=$((tw+1)); }
done; rm -rf "$te"
[ "$ab" -eq 0 ] && [ "$tw" -eq 0 ] && ok "Enter starts the run (bundles without Enter=Run: $ab; writes after N: $tw; Enter path = round bundle test)" || bad "Enter starts the run (bundles without Enter=Run: $ab; writes after N: $tw)"

# Step default by file hash (PFM 14 Nov 26): a step with default {passed, paths} is ticked only when those files changed.
sd=$(python3 - <<'PYEOF'
import pathlib
src = pathlib.Path('scripts/build_paste_bundles.py').read_text()
ns = {'__file__': str(pathlib.Path('scripts/build_paste_bundles.py').resolve())}; exec(src.split('\ndef here')[0], ns)
p = ['samples/publication.sample.json']; h = ns['files_hash'](p)
print(ns['step_default']({'default': {'passed': h, 'paths': p}}), ns['step_default']({'default': {'passed': 'x', 'paths': p}}),
      ns['step_default']({}), ns['step_default']({'default': False}))
PYEOF
)
[ "$sd" = "False True True False" ] && ok "step default follows changed files (unchanged off, changed on)" || bad "step default by hash: $sd"
# No DODID question in rounds (PFM 2026-11-13): the profile folder is the DODID.
dq=0; for b in scripts/gov/paste/*.ps1; do sed -n '/round runner (generated/,$p' "$b" | grep -qE "Read-Host 'DODID|idBox" && dq=$((dq+1)); done
[ "$dq" -eq 0 ] && ok "rounds ask no DODID (bundles that ask: $dq)" || bad "rounds ask no DODID (bundles that ask: $dq)"
# R06 lesson: New-Object with a string for an enum argument can match two overloads ("Multiple ambiguous overloads") and
# drop the Deployer to text mode. Binding check in pwsh for every New-Object System.Drawing.Font call in the bundles.
fa=$(grep -ohE "(New-Object System\.Drawing\.Font|\[System\.Drawing\.Font\]::new)\([^)]*,[^)]*, *[\"'][A-Za-z]+[\"'] *\)" scripts/gov/paste/*.ps1 scripts/build_paste_bundles.py | wc -l)
amb=$(pwsh -NoProfile -c 'Add-Type -AssemblyName System.Drawing.Common; try { $null = New-Object System.Drawing.Font("Segoe UI", 10, "Bold"); "bound" } catch { if ($_.Exception.Message -match "ambiguous") { "ambiguous" } else { "bound" } }' 2>&1 | tail -1)
[ "$fa" -eq 0 ] && [ "$amb" = "ambiguous" ] && ok "Deployer fonts: no string enum in Font() (found: $fa; pwsh confirms the string form is $amb)" || bad "Deployer fonts: string enum in Font() found=$fa (pwsh: $amb)"
for t16 in scripts/gov/90161Z-T16-pnp-signin-test-r2.ps1 scripts/gov/90161Z-T16-site-setup-r6.ps1; do
# T16 PnP retest: the e-mailed result must hold no site, tenant, sign-in address, GUID or .mil host (review R09 T16).
hs=$(pwsh -NoProfile -c '$src = Get-Content '"$t16"' -Raw; Invoke-Expression ([regex]::Match($src, "(?s)function Hide-Site.*?\n}\n").Value); $at = [string][char]64; Hide-Site ("x jane.doe.1234567890" + $at + "fakeco.onmicrosoft.us said no; bob" + $at + "unit.example.m" + "il https://login.microsoftonline.us/0a1b2c3d-1111-2222-3333-444455556666/o fakeco.onmicrosoft.us https://fakeco.sharepoint.us/sites/pfmtest/_api fakeco-admin.sharepoint.us /sites/pfmtest/_api %2Fsites%2Fpfmtest pfmtest") "https://fakeco.sharepoint.us/sites/pfmtest"' 2>&1)
! echo "$hs" | grep -qiE "fakeco|0a1b2c3d|pfmtest|https?://|jane|bob" && ok "$(basename $t16) hides site, tenant, sign-in address and GUID" || { echo "$hs"; bad "T16 masking"; }
done
# R15 review: site setup (r5 on) masks a URL-encoded address (%40) in a fetched result.
hs=$(pwsh -NoProfile -c '$src = Get-Content scripts/gov/90161Z-T16-site-setup-r6.ps1 -Raw; Invoke-Expression ([regex]::Match($src, "(?s)function Hide-Site.*?\n}\n").Value); Hide-Site "getbyemail(@v)?@v=%27first.last.9999%40fakeco.example%27" ""' 2>&1)
! echo "$hs" | grep -qiE "first.last|fakeco" && ok "site setup r6 masks a URL-encoded e-mail address" || { echo "$hs"; bad "site setup r6 %40 masking"; }
# R16: probe r5 grants Contribute to the coworker's own user (C01 ID), not to a group found by e-mail (R15: none found).
python3 -c "
import json; a = json.load(open('flow/defs/90161Z-T11-rights-probe-r5.json'))['actions']
assert 'principalid=@{body(\'C01\')?[\'Id\']}' in a['W11']['inputs']['parameters']['parameters/uri']
assert 'getuserbyid(@{body(\'C01\')' in a['G04']['inputs']['parameters']['parameters/uri'] and 'G04_read' not in a and 'G06_counts' in a
assert list(a).index('C01') < list(a).index('G04') < list(a).index('W11')" && ok "probe r5: W11 grants the C01 user ID; G04 by user ID; G06 counts" || bad "probe r5 W11/C01/G04/G06"
# R05 (PFM 2026-11-13): every bundle makes an Outlook draft and never sends it; off Windows it falls back to folder + clipboard.
nd=$(grep -L 'ComObject Outlook.Application' scripts/gov/paste/*.ps1 | wc -l); ns=$(grep -ciE '\.Send\(|\.Send\b *$' scripts/gov/paste/*.ps1 | awk -F: '{s+=$NF} END{print s+0}')
grep -q '\$script:draftMade = (-not \$why)' scripts/build_paste_bundles.py && grep -q "Outlook draft could not be created" scripts/build_paste_bundles.py; fb=$?
[ "$nd" -eq 0 ] && [ "$ns" -eq 0 ] && [ "$fb" -eq 0 ] && ok "Outlook draft step, never sent (bundles without draft: $nd; Send calls: $ns; fallback present)" || bad "Outlook draft step (without draft: $nd; Send calls: $ns; fallback rc=$fb)"

rm -rf "$vd"
echo "TESTS pass=$pass fail=$fail"
[ $fail -eq 0 ]
