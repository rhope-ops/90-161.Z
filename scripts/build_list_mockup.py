#!/usr/bin/env python3
"""Build the list mockup page (https://claude.ai/artifact/2CtD3ASmmmzkz1EPErgCvh) from schemas/lists/*.json,
samples/lists/*.csv (fake data) and templates/list-mockup.css. Style: docs/style-standard.md (dates 15 Jan 30,
numbers one to nine in words). Usage: python3 scripts/build_list_mockup.py <output.html>
The page is published as an artifact, not committed; never put real data in the samples."""
import json, csv, os, html, re, sys, datetime, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(tempfile.gettempdir(), 'pfm-lists-mockup.html')   # the system temp folder
CSS = open(os.path.join(ROOT, 'templates', 'list-mockup.css'), encoding='utf-8').read()
WORDS = 'zero one two three four five six seven eight nine'.split()
def num(n):
    """Write a count the T&Q ch 28 way. Takes an integer; returns the word for 0 to 9, else the digits."""
    return WORDS[n] if 0 <= n <= 9 else str(n)
sys.path.insert(0, os.path.join(ROOT, 'scripts')); from build_flow_payload import load, order
S = load(); ORD = order(S)
e = html.escape
TYPES = {'Text': 'Single line of text', 'Note': 'Multiple lines of text', 'Choice': 'Choice', 'Lookup': 'Lookup', 'User': 'Person',
         'URL': 'Hyperlink', 'DateTime': 'Date', 'Boolean': 'Yes/No', 'Number': 'Number'}
OK = {'On Track', 'Active', 'Concur', 'Concur With Comment', 'Certify Current', 'Comments Incorporated', 'Withdrawn'}
WARN = {'On Hold', 'Inactive', 'Expired', 'Requires Revision', 'Elevated'}
BAD = {'Stalled', 'Nonconcur', 'Rescinded', 'No Response', 'Is Obsolete'}
MUTED = {'Not Started', 'Superseded'}
def csvrows(n):
    """Read the sample CSV of one list (samples/lists/<n>.csv). Takes the list name; returns a list of row dicts, empty when there is no file."""
    p = os.path.join(ROOT, 'samples', 'lists', n + '.csv')
    return list(csv.DictReader(open(p, encoding='utf-8'))) if os.path.exists(p) else []
EXTRA = {
 'PFMOffices': [dict(Title='OFFICE-A', Endorser='Sample Endorser A', CoordinationRole='Functional', MandatoryCoordinator='false', CoordinateLast='false', IsActive='true'),
                dict(Title='RECORDS-X', Endorser='Sample Endorser R', CoordinationRole='Records', MandatoryCoordinator='true', CoordinateLast='false', IsActive='true'),
                dict(Title='LEGAL-X', Endorser='Sample Endorser L', CoordinationRole='Legal', MandatoryCoordinator='true', CoordinateLast='true', IsActive='true')],
 'PFMActivityLog': [dict(Title='Endorsement requested from RECORDS-X', Publication='Sample OI 99-101 IC-1', EventType='Endorsement Requested', EventBy='Flow'),
                    dict(Title='Reminder sent (day 10 of 15 weekdays)', Publication='Sample OI 99-101 IC-1', EventType='Reminder Sent', EventBy='Flow')],
}
def cell(f, v):
    """Make the HTML of one table cell. Takes the field dict and the cell value; returns HTML text (a colored pill for a choice, a dash when empty)."""
    if v in (None, ''): return '<span class="empty">&mdash;</span>'
    t = f['type']
    if t == 'Choice':
        c = 'ok' if v in OK else 'warn' if v in WARN else 'bad' if v in BAD else 'muted' if v in MUTED else ''
        return f'<span class="pill {c}">{e(v)}</span>'
    if t == 'Lookup': return f'<span class="lookup">{e(v)}</span>'
    if t == 'User': return f'<span class="person"><span class="av">{e(v[0])}</span>{e(v)}</span>'
    if t == 'URL': return '<span class="link">Link</span>'
    if t == 'Boolean': return 'Yes' if v.lower() in ('true', '1', 'yes') else 'No'
    if t == 'DateTime':
        d = datetime.date.fromisoformat(v); return f'{d.day} {d.strftime("%b %y")}'  # T&Q ch 28: 15 Jan 30
    return e(str(v))
def tq_dates(t):  # repo notes keep YYYY-MM-DD; the page shows T&Q short dates (ch 28)
    return re.sub(r"\b(\d{4})-(\d{2})-(\d{2})\b", lambda m: f"{int(m.group(3))} {datetime.date(2000, int(m.group(2)), 1).strftime('%b')} {m.group(1)[2:]}", t)
def det(f):
    """Make the detail text of a field row: the choices or the looked-up list. Takes the field dict; returns HTML text (empty for other types)."""
    if f['type'] == 'Choice':
        s = ' · '.join(e(c) for c in f['choices'])
        return s + (f' <em>(default {e(f["default"])})</em>' if f.get('default') else '')
    if f['type'] == 'Lookup':
        return f'→ {e(S[f["lookup"]["list"]]["title"])} ({e(f["lookup"].get("showField", "Title"))})'
    return ''
def flags(f):
    """Make the small flag labels (required, built-in, indexed, append-only) of a field. Takes the field dict; returns HTML text."""
    out = []
    for k, n in (('required', 'required'), ('builtIn', 'built-in'), ('indexed', 'indexed'), ('appendOnly', 'append-only')):
        if f.get(k): out.append(f'<span class=flag>{n}</span>')
    return ' '.join(out)
secs, nav = [], []
for n in ORD:
    s = S[n]; F = s['fields']
    rows = csvrows(n) or EXTRA.get(n, [])
    note = ''
    if n == 'PFMSeries':
        rows = [r for r in s['seed'] if r['SeriesNumber'] in (16, 17, 33)]
        note = f'<p class="note">The flow adds all {len(s["seed"])} series from DAFMAN 90-161 Table A2.1. Three are shown.</p>'
    if n == 'PFMSettings':
        rows = s['seed'] + [dict(Title='WingName', SettingValue='(typed on the government computer)', SettingNotes='Subtitle: <wing> ARW Publications and Forms')]
        note = f'<p class="note">The flow adds the first {num(len(s["seed"]))} rows (DAFMAN 90-161 5.2, 5.2.2). Other settings are typed on the government computer.</p>'
    if n == 'PFMProcessSteps':
        note = '<p class="note">Reference rows (draft, not verified); the flow does not add them.</p>'
    head = ''.join(f'<th>{e(f["displayName"])}</th>' for f in F)
    body = ''.join('<tr>' + ''.join(f'<td>{cell(f, r.get(f["internalName"]))}</td>' for f in F) + '</tr>' for r in rows)
    ref = ''.join(f'<tr><td class="lbl">{e(f["displayName"])}</td><td>{TYPES[f["type"]]}</td>'
                  f'<td class="det">{det(f)}{("<br><em>" + e(f["description"]) + "</em>") if f.get("description") else ""}</td>'
                  f'<td class="flags">{flags(f)}</td><td class="mono">{e(f["internalName"])}</td><td class="src">{e(tq_dates(f.get("ref", "")))}</td></tr>' for f in F)
    tabs = '<span class="vtab on">All Items</span>' + ''.join(f'<span class="vtab">{e(v["name"])}</span>' for v in s.get('views', []))
    new = ' <span class="pill ok">New in r7</span>' if n == 'PFMReviews' else ''
    secs.append(f'''<section class="list" id="{n.lower()}">
<header class="lhead"><div><h2>{e(s["title"])}{new}</h2><p class="url mono">/Lists/{n}</p></div><p class="desc">{e(s["description"])}</p></header>
<div class="mockbar">{tabs}</div>
<div class="scroll"><table class="grid"><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>{note}
<details><summary>{len(F)} columns: types, choices and sources</summary><div class="scroll"><table class="ref"><thead>\
<tr><th>Column</th><th>Type</th><th>Choices, lookup or description</th><th>Flags</th><th>Internal name</th><th>Source</th></tr></thead><tbody>{ref}</tbody></table></div></details>
</section>''')
    nav.append(f'<a href="#{n.lower()}">{e(s["title"][4:])}</a>')
page = f'''<title>PFM Lists Mockup</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&family=Archivo:wght@600;700&display=swap">
<style>
{CSS}
</style>
<div class="wrap">
<header><h1>90-161.Z SharePoint lists</h1><p class="lede">The {num(len(ORD))} lists that Task 2 r9 creates, in creation order, with every column. \
r7 added the DAFMAN 90-161 design check (eight action types, Coordination Stage, PFM Reviews, product links); \
r8 standardizes every name IAW DAFMAN 90-161 and The Tongue and Quill. \
Sample rows are fake. Open "columns" under each list for types, choices, lookup targets and the DAFMAN source of each column.</p></header>
<nav aria-label="Lists">{''.join(nav)}</nav>
{''.join(secs)}
<p class="foot">Generated from schemas/lists/*.json and samples/lists/*.csv (T02 r9). Built-in columns Created, Modified, Created By and Modified By exist on every list and are not shown.</p>
</div>
'''
open(OUT, 'w', encoding='utf-8').write(page)
print('MOCKUP', OUT, len(page), 'bytes', len(ORD), 'lists')
