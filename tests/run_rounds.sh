# tests/run_rounds.sh: part 3 of tests/run.sh (newest RADE verdict, NIPR start check, Enter and window checks, T19, T22 cards, guide text, lint result).
# Run only by tests/run.sh, which sources it (same shell: it shares ok, bad, sk, on, bg, bd and the counters). Do not run it alone.
# Network: one read of the public tag list of the RADE repository (git ls-remote, 30 second limit); everything else is local.
# Writes: only temporary folders (made with mktemp, removed at exit); nothing in the repo.
# Credentials: none (fake sample data only).

# Newest RADE: scripts/rade_newest.py gives the verdict (OK, BEHIND, BEHINDNOTE, WRONGCOMMIT, NOTCHECKED; its header says
# why each one is a PASS, FAIL or NOTE). Behind is a FAIL only for a change that touches the lock or a round bundle.
rade_lock_verdict() {  # $1 = git ls-remote --tags output, $2 = lock tag, $3 = lock commit, $4 = changed files or *all*
  python3 scripts/rade_newest.py "$1" "$2" "$3" "$4"
}
fake_tags=$(printf '%s\trefs/tags/engine-v4\n%s\trefs/tags/engine-v5\n%s\trefs/tags/engine-v10\n' \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb cccccccccccccccccccccccccccccccccccccccc)
[ "$(rade_lock_verdict "$fake_tags" engine-v10 cccccccccccccccccccccccccccccccccccccccc '*all*')" = "OK engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v5 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb '*all*')" = "BEHIND engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v5 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb "docs/a.md scripts/gov/paste/R1.ps1")" = "BEHIND engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v5 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb "docs/a.md scripts/gov/T20.ps1")" = "BEHINDNOTE engine-v10" ] \
  && [ "$(rade_lock_verdict "$fake_tags" engine-v10 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb '*all*')" = "WRONGCOMMIT engine-v10" ] \
  && [ "$(rade_lock_verdict "" engine-v10 cccccccccccccccccccccccccccccccccccccccc '*all*')" = "NOTCHECKED" ] \
  && ok "newest-RADE check: verdicts (newest, behind, behind with no round change, wrong commit, no network)" || bad "newest-RADE check: verdicts"
if [ "${on[bundle]}" = 1 ]; then
# The engine repository: scripts/rade.lock.json "repo" (fleet v2 DEC 7; owner/name only).
rade_repo=$(python3 -c "import json,re;r=json.load(open('scripts/rade.lock.json'))['repo'];print(r if re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',r) else '')")
tags=$(timeout 30 git ls-remote --tags "https://github.com/$rade_repo" 'refs/tags/engine-v*' 2>/dev/null || true)
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
  [ "$go" = "This application cannot be installed in your environment." ] && [ -z "$(find "$g" -type f)" ] &&
    ok "NIPR-only start check: $(basename $b) stops on a computer that is not on NIPR and writes nothing" || { echo "$go" | head -3; bad "NIPR-only start check ($(basename $b))"; }
done
rm -rf "$tp"
nb=$(python3 -c "import json;print(len(json.load(open('scripts/paste_bundles.json'))['bundles']))"); [ $pr -eq "$nb" ] && [ $pf -eq 0 ] &&
  ok "round bundle text mode: files exact, steps run, report in results folder, DODID masked, real path on screen (rounds=$pr mismatches=$pf)" || bad "round bundle: rounds ok=$pr mismatches=$pf"
[ $pc -eq "$nb" ] && ok "RADE cleanup: only 90-161.Z files recycled, other files and their folder kept, summary has the clean-up line, files left, subject NEEDS REVIEW, history row" ||
  bad "RADE cleanup and summary (see output above)"
else sk "NIPR-only start check"; sk "round bundle text mode"; sk "RADE cleanup"; fi


# Enter starts the run (PFM 2026-11-13): in the window Enter is the card's primary button (on "Ready" that is Install or Run;
# engine-v48: Enter = the main button on every card that does not say NoAccept, and the main button's text ends with
# "(Enter)" when it fits); text mode shows the plan, Enter runs, N stops with nothing written.
if [ "${on[bundle]}" = 1 ]; then
ab=$(grep -L 'AcceptButton = \$(if (\$C.NoAccept) { \$null } else { \$ui.Accept })' scripts/gov/paste/*.ps1 | wc -l)
ab=$((ab + $(grep -LF "\$main = ([string]\$bs[\$k].Kind -eq 'primary'); \$key = \$(if (\$main -and -not \$C.NoAccept" scripts/gov/paste/*.ps1 | wc -l)))
# ... and on "Ready" the primary button is Install or Run and starts the run.
# engine-v8 on (dates "d MMM yy" in the saved-checks line): Run is primary unless RADE's Start button is ($startPrimary: the app has app.start and that version
# is installed). 90-161.Z has no app.start, so Run stays the primary button on Ready in every round.
ab=$((ab + $(grep -LF -e "-and -not \$startPrimary) { 'primary' }" scripts/gov/paste/*.ps1 | wc -l)))
ab=$((ab + $(grep -LF "else { 'off' }); Act = { & \$ui.Run }" scripts/gov/paste/*.ps1 | wc -l)))
python3 -c "import json,sys;d=json.load(open('scripts/paste_bundles.json'));sys.exit(1 if d['application'].get('start') else 0)" || ab=$((ab+1))
te=$(mktemp -d); mkdir -p "$te/u/test1234/OneDrive - United States Air Force"; tw=0
for b in scripts/gov/paste/*.ps1; do
  sed -e "s#Read-Host ('Type the number of the application to deploy (1 to ' + \\\$apps\\.Count + ') and press Enter')#'1'#" \
    -e 's#^function Get-OwnFqdn .*#function Get-OwnFqdn { return '"'pc01.area52.example.invalid'"' }#' \
    -e "s#Read-Host 'Press Enter to start the round, or type N and press Enter to stop with no changes'#'N'#" \
    -e "s#Read-Host 'Type the site address[^']*'#''#" \
    -e "s#Read-Host 'Did you see both[^']*'#'Y'#" \
    -e "s#Url = 'https://make\.powerautomate[^']*'#Url = 'file:///dev/null'#" \
    -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$te/u'#" "$b" > "$te/b.ps1"
  # PFM 14 Nov 26: with the check gate on, a FAILED or NOT RUN check stops the deploy before anything is written.
  # R17: the checks may save RADE/Config/rade-checks.json (shown on the Check screen); engine-v22 on also rade-checks-last.txt (PFM 19 Nov 26); nothing else.
  USERPROFILE="$te/u/test1234" pwsh -NoProfile -File "$te/b.ps1" > "$te/out.txt" 2>&1; [ -e "$te/u/test1234/OneDrive - United States Air Force/90-161.Z" ] && tw=$((tw+1))
  [ "$(cd "$te/u/test1234/OneDrive - United States Air Force" && find . -type f | sort | tr '\n' ' ')" = "./RADE/Config/rade-checks-last.txt ./RADE/Config/rade-checks.json " ] ||
    { echo "files after N:"; find "$te/u" -type f; tw=$((tw+1)); }
  # The gate test needs a check that fails here: the SharePoint tool (manifest "needs" pnp). A round without it has no gate stop.
  nd=$(needs "$b")
  [[ " $nd " != *" pnp "* ]] || grep -q "^You cannot deploy yet: a check is FAILED or NOT RUN" "$te/out.txt" || { echo "check gate did not stop the deploy"; tw=$((tw+1)); }
  # Review R17 MAJOR 1: a fresh install (no 90-161.Z folder anywhere) finds OneDrive and can write there.
  grep -q "^  PASSED: Your OneDrive folder is set up" "$te/out.txt" && grep -q "^  PASSED: Files can be saved in OneDrive" "$te/out.txt" || { echo "fresh install: OneDrive checks";
    grep "OneDrive" "$te/out.txt"; tw=$((tw+1)); }
  # Saved checks (R17, PFM 14 Nov 26): a second run uses the PASSED results saved by the first (OneDrive), and still runs the others (engine-v21 on: the PowerShell version check is one).
  USERPROFILE="$te/u/test1234" pwsh -NoProfile -File "$te/b.ps1" > "$te/out2.txt" 2>&1
  grep -q "^  PASSED: Your OneDrive folder is set up. Last check: $(LC_ALL=C date +"%-d %b %y")" "$te/out2.txt" &&
    ! grep -q "^  PASSED: PowerShell is version 5.1 or newer. Last check:" "$te/out2.txt" && { [[ " $nd " != *" pnp "* ]] || grep -q "^  FAILED: The SharePoint tool" "$te/out2.txt"; } ||
    { echo "saved checks not used on the second run"; grep "^  [A-Z]" "$te/out2.txt"; tw=$((tw+1)); }
done; rm -rf "$te"
[ "$ab" -eq 0 ] && [ "$tw" -eq 0 ] &&
  ok "Enter starts the run (bundles where Enter is not the primary button or Ready has no primary Run: $ab; writes after N: $tw; Enter path = round bundle test)" ||
  bad "Enter starts the run (bundles where Enter is not the primary button or Ready has no primary Run: $ab; writes after N: $tw)"
else sk "Enter starts the run"; fi

# No DODID question in rounds (PFM 2026-11-13): the profile folder is the DODID.
dq=0; for b in scripts/gov/paste/*.ps1; do sed -n '/round runner (generated/,$p' "$b" | grep -qE "Read-Host 'DODID|idBox" && dq=$((dq+1)); done
[ "$dq" -eq 0 ] && ok "rounds ask no DODID (bundles that ask: $dq)" || bad "rounds ask no DODID (bundles that ask: $dq)"
# R06 lesson: New-Object with a string for an enum argument can match two overloads ("Multiple ambiguous overloads") and
# drop the RADE window to text mode. Binding check in pwsh for every New-Object System.Drawing.Font call in the bundles.
if [ "${on[batch]}" = 1 ]; then
fa=$(grep -ohE "(New-Object System\.Drawing\.Font|\[System\.Drawing\.Font\]::new)\([^)]*,[^)]*, *[\"'][A-Za-z]+[\"'] *\)" scripts/gov/paste/*.ps1 | wc -l)
amb=$(bout font | tail -1)
[ "$fa" -eq 0 ] && [ "$amb" = "ambiguous" ] && ok "RADE fonts in the bundles: no string enum in Font() (found: $fa; pwsh confirms the string form is $amb)" ||
  bad "RADE fonts in the bundles: string enum in Font() found=$fa (pwsh: $amb)"
# PFM 15 Nov 26 (enter the site once): Get-SiteAddress returns the address RADE holds, then the saved one, with no question.
sa=$(bout siteaddr | tail -1)
[ "$sa" = "https://fakeco.example/sites/one|https://fakeco.example/sites/two|ASKED|SITE ADDRESS not set" ] &&
  ok "site address: from RADE, then from Config; with neither, a question outside RADE and a stop with the fix inside RADE" || { echo "$sa"; bad "site address: one entry"; }
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
[ "$nd" -eq 0 ] && [ "$ns" -eq 0 ] && [ "$fb" -eq 0 ] && ok "Outlook draft step, never sent (bundles without draft: $nd; Send calls: $ns; fallback present)" ||
  bad "Outlook draft step (without draft: $nd; Send calls: $ns; fallback rc=$fb)"

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
# T22 PFM window test r21 (R44 T4; R40: the reopen check names the saved card, kept cards, paint times; R39: 4 checks, -Again 1, font files; R38; R35 W7; R34 W1; R32 defects W1 to W3): the cards and
# the 4 checks as text (-PlanOnly; no window here; the window: tests/ps/Test-T22Layout.ps1).
# Every button, link and grid row goes to a card that exists (or 'back', '@grid', '@note'), one blue button a card, ASCII and FAKE text (R11: XXX XXX names); r1 to r20 gone, r21 and its
# parts only, no '0 findings' link (V3), UI block current, palette tokens.
if [ "${on[t22]}" = 1 ]; then
python3 - <<'PYT22' && python3 tests/check_t22_r21.py && ok "T22 window preview cards (r21; R42: grid room for the scroll bar, walk path)" || bad "T22 window preview cards (r21)"
import json, re, subprocess, pathlib
f = 'scripts/gov/90161Z-T22-pfm-window-r21.ps1'; g = pathlib.Path('scripts/gov'); pp = lambda n: g / ('90161Z-T22-%s-r21.ps1' % n)
old = [x.name for x in g.glob('90161Z-T22-*-r[1-9].ps1')] + [x.name for x in g.glob('90161Z-T22-*-r1[0-9].ps1')]
assert not old + [x.name for x in g.glob('90161Z-T22-*-r20.ps1')], 'an older revision is still there'
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
for l in out:   # every publication, office and person name says XXX XXX (R11, R38: wide letters; was FAKE)
    for w in re.findall(r'(?<!XXX XXX )(?<!DAF )\b(OI \d\d-\d+|Instruction \d\d-\d+|Form \d+|Office \d|AO \d)\b', l): raise AssertionError(l)
assert 'FAKE' in text and 'FAKE OI' not in text and 'XXX XXX OI 33-101' in text and 'RAIL Your Work' in text \
    and 'RAIL Settings' in text and 'See the 0 findings' not in text and len([l for l in out if l.startswith('RAIL ')]) == 5
# the 4 in-window checks (R12, R39; PFM 20 Nov 26): numbered lines in order, with their keys, each text one action and at most 200 characters
keys = ['home-all', 'font', 'box', 'speed']; chk = [re.match(r'CHECK (\d+) ([a-z-]+): (.+)$', l) for l in out if re.match(r'CHECK \d+ ', l)]
assert len(chk) == 4 and all(chk) and all(len(m.group(3)) <= 200 for m in chk) and [m.group(2) for m in chk] == keys and [int(m.group(1)) for m in chk] == list(range(1, 5)), [m.group(0) for m in chk]
ag = subprocess.run(['pwsh', '-NoProfile', '-Command',
    "$Again = $true; . ./" + str(pp('cards')) + "; Get-CheckPlan; foreach ($k in 'settings', 'step8', 'sendback') { $Checks[0].Text = Get-AgainText $k; Get-CheckPlan }"],
    capture_output=True, text=True, timeout=60).stdout.split('\n')   # R12: -Again = 1 reopen check; fonts
assert [l for l in ag if l.startswith('CHECK ')] == ['CHECK 1 reopen: No screen was saved when this window last closed. Select Fail.',
    'CHECK 1 reopen: Pass if this window opened on Settings, the screen you closed it on.',
    'CHECK 1 reopen: Pass if this window opened on XXX XXX OI 33-101, the screen you closed it on.',
    'CHECK 1 reopen: No screen was saved when this window last closed. Select Fail.'] \
    and "Get-FontTtf $PSScriptRoot" in src and "-Filter '*SofiaSans*.ttf'" in src, ag
assert "if ($Again) { $Checks[0].Text = Get-AgainText (& $wn.LastKey) }" in src \
    and "$script:ChecksDone = 'All checks done. Close this window with its X.'" in src and 'select All Actions' not in src, 'the again check or the closing line'
assert all(x in src for x in ("' paint-first='", "' paint-later-max='", "' kept='", '$wn.KeepFind $Key $sig', '& $wn.KeepClear')), 'keep part or CARDTIME'
# R13: reopen names the saved card; kept cards; paint times
# the rade-ui block is not empty, and the colors painted here are the palette tokens
assert re.search(r'# >>> rade-ui:[^\n]*\n# RADE shared UI file[\s\S]*\n[^\n]*\$ui\.C = @\{\}', src), 'rade-ui block missing'   # engine-v48: "$ui.Dark = [bool]$ui.Dark; $ui.C = @{}" (dark is opt-in)
assert re.findall(r'\$ui\.Dark\s*=(?!=)[^;\n]*', src) == ['$ui.Dark = [bool]$ui.Dark'], 'the Kanon window stays light until R49 (DECISIONS 2026-11-27): only the engine line writes $ui.Dark'
after = src.split('# <<< rade-ui', 1)[1]
assert re.search(r'\$ui\.B\s*=\s*@\(\)', after) and re.search(r'\$ui\.P\s*=\s*@\(\)', after), '$ui.B and $ui.P must be set outside the rade-ui block'
assert 'SetProcessDPIAware' not in src and "$form.AutoScaleMode = 'Dpi'" in src, 'F6 T22: no DPI call (Windows scales the window); the form scales by AutoScaleMode Dpi'
# F6 T22 (DEC-NIPR invariant 2): no inline C# outside the generated blocks (their C# goes with the RADE engine); no Pfm.* or Rade.Native type left
own = re.sub(r'# >>> [^\n]*\n[\s\S]*?\n# <<< [^\n]*', '', src)
bad_cs = r'Add-Type\b[^\n]*-(TypeDefinition|MemberDefinition)|Add-Type @|csc\.exe|CodeDomProvider'
bad_cs += r'|\[Pfm\.|New-Object Pfm\.|\[Rade\.Native|\[T22\.Native'
assert not re.findall(bad_cs, own), 'inline C# or a C# type is left in the T22 parts'
assert "$Rev = 'r21'" in src and sorted(x.name for x in g.glob('90161Z-T22-*-r21.ps1')) == sorted(pp(n).name for n in parts + ['pfm-window', 'maint']), parts
grids = len(re.findall(r'New-Object System.Windows.Forms.DataGridView\b(?!\w)', src))
assert grids >= 1 and src.count("$g.AutoSizeColumnsMode='Fill'") == grids and src.count("$dc.AutoSizeMode='Fill'") >= 1, 'every grid fills its columns'
pal = json.loads(pathlib.Path('docs/palette.json').read_text())['tokens']
hexes = dict(re.findall(r"(\w+)\s*=\s*'([0-9A-F]{6})'", re.search(r'\$PalHex\s*=\s*@\{(.*?)\}', src, re.S).group(1)))
for k, v in hexes.items(): assert pal[k.replace('white', 'white')] == v, (k, v, pal.get(k))
# -Opened (the look questions' gate in the round): fake result files opened / not opened / STOPPED / 4 hours old; one line, no other file
import tempfile, os, time; d = tempfile.mkdtemp(); w = pathlib.Path(d, '90161Z-T22-window-r21.txt'); got = {}
for k, body in {'open': 'CARDS opened: home, step8 (17 of 17)\nPASS layout',
             'none': 'CARDS opened: none (0 of 17)', 'stop': 'CARDS opened: home (1 of 17)\nSTOPPED: no window (x)',
             'old': 'CARDS opened: home, step8 (17 of 17)'}.items():
    w.write_text(body + '\n'); k == 'old' and os.utime(w, (time.time() - 4 * 3600,) * 2)
    r = subprocess.run(['pwsh', '-NoProfile', '-File', f, '-Opened', '-TestDir', d], capture_output=True, text=True, timeout=60)
    got[k] = (r.stdout.strip(), r.returncode)
assert got == {'open': ('PASS the window opened (17 of 17 cards)', 0),
        'none': ('FAIL the window did not open', 1), 'stop': ('FAIL the window did not open', 1),
        'old': ('FAIL the window did not open (no result from this round)', 1)} and len(list(pathlib.Path(d).iterdir())) == 1, got
PYT22
# R43 T1 (R42 finding 2): the grid fit cuts columns that end past the grid (the R42 device numbers 979 of 961 and 1442 of 1428; the r15 part fails this).
out=$(pwsh -NoProfile -File tests/ps/Test-T22GridWidth.ps1 2>&1); rc=$?
[ $rc -eq 0 ] && ok "T22 grid fit: columns end before the scroll bar ($(echo "$out" | tail -1))" ||
  { echo "$out"; bad "T22 grid fit: columns end past the grid"; }
# R44 T4 (R43 findings 3, 4, 6): the look step names a line of the waves card; the bar text never reaches its links
# (longest step text, 3 window widths, 2 dpi, wide links); walk step 1 counts the start card.
out=$(pwsh -NoProfile -File tests/ps/Test-T22Bar.ps1 2>&1); rc=$?
[ $rc -eq 0 ] && ok "T22 check bar: look step, links kept clear of the step text, first step opened ($(echo "$out" | tail -1))" ||
  { echo "$out" | grep FAIL; bad "T22 check bar: look step, links or first step"; }
else sk "T22 window preview cards (r21)"; fi
# R44 T1 (R43 finding 1: one missing hand value skipped 13 steps): only the 2 endorser answer steps wait for the second person.
rd=$(python3 tests/check_round_deps.py) && ok "round steps: only the endorser answers wait for the second person ($(echo "$rd" | tail -1))" ||
  { echo "$rd"; bad "round steps: a step that is no endorser answer waits for the second person"; }
# Guide text (AGENTS.md "Gov-device usability" point 3, PFM 2026-11-16): every step passes, no baseline.
python3 tests/check_guide_text.py --test >/dev/null && ok "guide text self-test" || bad "guide text self-test"
gt=$(python3 tests/check_guide_text.py) && ok "guide text ($(echo "$gt" | tail -1))" || { echo "$gt"; bad "guide text: a step points elsewhere, holds 2 actions or is over 200 characters"; }
# Screen names (Project rule, the PFM, 2026-11-25): every bold or quoted name in a step is screen text of the round bundle.
python3 tests/check_screen_names.py --test >/dev/null && ok "screen names self-test" || bad "screen names self-test"
sn=$(python3 tests/check_screen_names.py) && ok "screen names ($(echo "$sn" | tail -1))" || { echo "$sn"; bad "screen names: a step names text that no RADE screen shows"; }
gp=$(node tests/check_go_page.js) && ok "bookmark page renderer ($(echo "$gp" | tail -1))" || { echo "$gp"; bad "bookmark page renderer (tests/check_go_page.js)"; }
if [ "${on[lint]}" = 1 ]; then wait "$lint_pid" && ok "lint ($(tail -1 "$bg/lint.out"))" || { cat "$bg/lint.out"; bad "lint"; }; else sk "lint"; fi
