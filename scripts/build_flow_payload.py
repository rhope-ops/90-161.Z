#!/usr/bin/env python3
"""Generate the Power Automate provisioning payload from schemas/lists/*.json.

Output: flow/provisioning-payload.json with arrays the flow sends in order:
  lists   - create each list under its URL name ("list", no spaces), versioning on (run first)
  fields  - create fields, then views (lookup list IDs are placeholders __<List>_ID__ filled in the flow)
  updates - MERGE requests, run last: index built-in columns, rename Title columns, then set each
            list's display title ("title"). Renaming the list last keeps getbytitle(<URL name>) valid
            for every earlier request (naming rule 2, PFM 2026-11-11).
  rows    - rows the flow adds after fields and views, before updates (lists with "seedOnProvision": true,
            e.g. PFM Series from DAFMAN Table A2.1)
  seed    - optional rows of other lists (Process Steps: process model is draft); not sent by the flow
  permissions - MERGE ReadSecurity/WriteSecurity on lists with "itemLevelPermissions" (PFM 10A), by display
            title, after updates in their own loop; the flow reports a refusal instead of failing (T02 r11)
Every request is a SharePoint REST call relative to the site: {"method", "uri", "body"}.
Do not hand-edit the output. Change the schemas and run: python3 scripts/build_flow_payload.py
"""
import glob, json, os, sys
from xml.sax.saxutils import escape, quoteattr

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load():
    """Read every list schema in schemas/lists. Takes nothing; returns {list name: schema dict}."""
    schemas = {}
    for f in sorted(glob.glob(os.path.join(ROOT, 'schemas', 'lists', '*.json'))):
        d = json.load(open(f, encoding='utf-8'))
        schemas[d['list']] = d
    return schemas

def order(schemas):
    """Sort the lists so a list comes after the lists it looks up (a list may look up itself). Takes the schemas; returns the list names in build order. Exits on a lookup cycle."""
    deps = {n: {f['lookup']['list'] for f in s['fields'] if f['type'] == 'Lookup'} - {n} for n, s in schemas.items()}  # a list may look up itself
    done, out = set(), []
    while len(out) < len(schemas):
        ready = sorted(n for n in schemas if n not in done and deps[n] <= done)
        if not ready:
            sys.exit('lookup cycle in schemas')
        out += ready; done |= set(ready)
    return out

def field_xml(f):
    """Build the SharePoint field XML of one schema field. Takes the field dict; returns the <Field ...> text. Exits on an unsupported type."""
    a = [f'Name={quoteattr(f["internalName"])}', f'StaticName={quoteattr(f["internalName"])}',
         f'DisplayName={quoteattr(f["displayName"])}', f'Required="{"TRUE" if f.get("required") else "FALSE"}"']
    if f.get('description'): a.append(f'Description={quoteattr(f["description"])}')  # spells out abbreviations (docs/style-standard.md)
    inner = ''
    t = f['type']
    if t == 'Note': a += ['Type="Note"', 'NumLines="6"'] + (['AppendOnly="TRUE"'] if f.get('appendOnly') else [])
    elif t == 'DateTime': a += ['Type="DateTime"', 'Format="DateOnly"']
    elif t == 'URL': a += ['Type="URL"', 'Format="Hyperlink"']
    elif t == 'Choice':
        a += ['Type="MultiChoice"' if f.get('multi') else 'Type="Choice"']
        inner = '<CHOICES>' + ''.join(f'<CHOICE>{escape(c)}</CHOICE>' for c in f['choices']) + '</CHOICES>'
    elif t == 'Lookup':
        a += ['Type="Lookup"', 'List="{__%s_ID__}"' % f['lookup']['list'],
              f'ShowField={quoteattr(f["lookup"].get("showField", "Title"))}']
    elif t == 'User': a += (['Type="UserMulti"', 'Mult="TRUE"'] if f.get('multi') else ['Type="User"']) + ['UserSelectionMode="PeopleOnly"', 'UserSelectionScope="0"']
    elif t == 'Number': a += ['Type="Number"', 'Decimals="0"']  # whole numbers: series, order, step
    elif t in ('Text', 'Boolean'): a += [f'Type="{t}"']
    else: sys.exit(f'unsupported field type {t}')
    if f.get('indexed') or f.get('unique'): a += ['Indexed="TRUE"']
    if f.get('unique'): a += ['EnforceUniqueValues="TRUE"']  # SharePoint needs the column indexed for this
    if f.get('default') not in (None, ''):
        inner += f'<Default>{escape(str(f["default"]))}</Default>'
    return '<Field ' + ' '.join(a) + '>' + inner + '</Field>'

def view_query(v):
    """Build the CAML query (filter, group, order) of one view. Takes the view dict; returns the query text (may be empty)."""
    q = ''
    def cond(w):
        """Build one CAML condition from a where entry (op, field, type, value). Returns the text."""
        return f'<{w["op"]}><FieldRef Name={quoteattr(w["field"])}/><Value Type={quoteattr(w["type"])}>{escape(str(w["value"]))}</Value></{w["op"]}>'
    w, w2 = v.get('where'), v.get('andWhere')
    if w and w2:
        q += '<Where><And>' + cond(w) + cond(w2) + '</And></Where>'
    elif w:
        q += '<Where>' + cond(w) + '</Where>'
    if v.get('groupBy'):
        q += f'<GroupBy Collapse="FALSE"><FieldRef Name={quoteattr(v["groupBy"])}/></GroupBy>'
    if v.get('orderBy'):
        q += '<OrderBy>' + ''.join(f'<FieldRef Name={quoteattr(o["field"])} Ascending="{"TRUE" if o.get("ascending", True) else "FALSE"}"/>' for o in v['orderBy']) + '</OrderBy>'
    return q

def lit(s):  # OData string literal
    return "'" + s.replace("'", "''") + "'"

def build():
    """Build the whole provisioning payload from the list schemas. Takes nothing; returns the payload dict (the batches of lists, fields, updates, rows and seed requests)."""
    schemas = load()
    lists, fields, updates, rows, seed = [], [], [], [], []
    for name in order(schemas):
        s = schemas[name]
        lists.append({'method': 'POST', 'uri': '_api/web/lists',
                      'body': {'__metadata': {'type': 'SP.List'}, 'Title': name, 'BaseTemplate': 100,
                               'Description': s.get('description', ''), 'ContentTypesEnabled': False,
                               'EnableVersioning': True}})
        base = f'_api/web/lists/getbytitle({lit(name)})'
        for f in s['fields']:
            if f.get('builtIn'):
                continue
            fields.append({'method': 'POST', 'uri': base + '/fields/createfieldasxml',
                           'body': {'parameters': {'__metadata': {'type': 'SP.XmlSchemaFieldCreationInformation'},
                                                   'SchemaXml': field_xml(f), 'Options': 24}}})  # 8 internal name hint + 16 add to default view
        for v in s.get('views', []):
            fields.append({'method': 'POST', 'uri': base + '/views',
                           'body': {'__metadata': {'type': 'SP.View'}, 'Title': v['name'], 'PersonalView': False,
                                    'ViewQuery': view_query(v), 'RowLimit': 100}})
            vb = base + f'/views/getbytitle({lit(v["name"])})/viewfields'
            fields.append({'method': 'POST', 'uri': vb + '/removeallviewfields', 'body': {}})
            for fld in v['fields']:
                fields.append({'method': 'POST', 'uri': vb + f'/addviewfield({lit("LinkTitle" if fld == "Title" else fld)})', 'body': {}})
        for b in s.get('indexBuiltIn', []):
            updates.append({'method': 'MERGE', 'uri': base + f'/fields/getbyinternalnameortitle({lit(b)})',
                            'body': {'__metadata': {'type': 'SP.Field'}, 'Indexed': True}})
        t = next((f for f in s['fields'] if f['internalName'] == 'Title'), None)
        if t and t['displayName'] != 'Title':
            updates.append({'method': 'MERGE', 'uri': base + "/fields/getbyinternalnameortitle('Title')",
                            'body': {'__metadata': {'type': 'SP.Field'}, 'Title': t['displayName']}})
        multi = {f['internalName'] for f in s['fields'] if f.get('multi') and f['type'] == 'Choice'}
        for row in s.get('seed', []) or []:
            item = {'__metadata': {'type': f'SP.Data.{name}ListItem'}}
            item.update(row)
            for k in multi & set(row):  # a multi-choice value goes as a string collection (SharePoint REST, verbose JSON)
                item[k] = {'__metadata': {'type': 'Collection(Edm.String)'}, 'results': list(row[k])}
            (rows if s.get('seedOnProvision') else seed).append({'method': 'POST', 'uri': base + '/items', 'body': item})
    for name in order(schemas):  # list titles last (see docstring)
        updates.append({'method': 'MERGE', 'uri': f'_api/web/lists/getbytitle({lit(name)})',
                        'body': {'__metadata': {'type': 'SP.List'}, 'Title': schemas[name]['title']}})
    # Item-level permissions (PFM 10A; in the flow from T02 r11): after the titles, by display title, in their own loop so a refusal does not stop the run
    permissions = [{'method': 'MERGE', 'uri': f'_api/web/lists/getbytitle({lit(schemas[n]["title"])})',
                    'body': {'__metadata': {'type': 'SP.List'}, 'ReadSecurity': schemas[n]['itemLevelPermissions']['read'],
                             'WriteSecurity': schemas[n]['itemLevelPermissions']['write']}}
                   for n in order(schemas) if 'itemLevelPermissions' in schemas[n]]
    for r in lists + fields + updates + rows + seed + permissions:  # view titles have spaces; never rely on the connector to encode them
        r['uri'] = r['uri'].replace(' ', '%20')
    return {'generatedFrom': 'schemas/lists/*.json', 'listOrder': order(schemas),
            'lookupPlaceholders': sorted({f['lookup']['list'] for s in schemas.values() for f in s['fields'] if f['type'] == 'Lookup'}),
            'lists': lists, 'fields': fields, 'rows': rows, 'updates': updates, 'seed': seed, 'permissions': permissions}

if __name__ == '__main__':
    out = build()
    path = os.path.join(ROOT, 'flow', 'provisioning-payload.json')
    # ASCII only (15 Nov 26): RADE embeds this file in a round bundle as ASCII text for T20. A character such as the
    # dash in "Concur\u2014No Response" is written as a JSON escape; every reader gets the same value.
    text = json.dumps(out, ensure_ascii=True, indent=1) + '\n'
    if '--check' in sys.argv:
        ok = os.path.exists(path) and open(path, encoding='utf-8').read() == text
        print('PAYLOAD up to date' if ok else 'PAYLOAD stale: run scripts/build_flow_payload.py'); sys.exit(0 if ok else 1)
    open(path, 'w', encoding='utf-8').write(text)
    print(f"PAYLOAD lists={len(out['lists'])} fieldsAndViews={len(out['fields'])} rows={len(out['rows'])} updates={len(out['updates'])} seed={len(out['seed'])} permissions={len(out['permissions'])} order={','.join(out['listOrder'])}")
