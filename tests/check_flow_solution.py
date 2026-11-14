#!/usr/bin/env python3
"""Check the draft flow solution (flow/solution): def names, JSON, trigger and actions, list and column names against
schemas/lists, connection references, environment variables, "@" expression syntax, URL hosts. Prints one PASS line with counts."""
import json, pathlib, re, sys, zipfile
import xml.dom.minidom as minidom

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import build_flow_solution as B  # noqa: E402

errs = []
def bad(m): errs.append(m)

# Hosts allowed in any string: Logic Apps schema (as in build_flow_package.py) and the XML/OPC namespaces the solution format needs.
ALLOWED_HOSTS = {"schema.management.azure.com", "www.w3.org", "schemas.openxmlformats.org"}
BUILTIN = {"ID", "Id", "Value", "value", "Email", "Claims", "Title", "Editor", "Author", "Created", "Modified", "text"}

schemas = {}
for f in (ROOT / "schemas" / "lists").glob("*.json"):
    d = json.loads(f.read_text(encoding="utf-8"))
    schemas[d["title"]] = {x["internalName"] for x in d["fields"]}
all_cols = set().union(*schemas.values()) | BUILTIN
env_list = {B.ENV_KEY[s]: default for s, _, default in B.ENV if s.startswith("pfm_List")}
for key, title in env_list.items():
    if title not in schemas: bad(f"environment variable {key}: default '{title}' is not a list title in schemas/lists")

def walk_actions(actions):
    for name, a in actions.items():
        yield name, a
        for k in ("actions",):
            yield from walk_actions(a.get(k, {}))
        yield from walk_actions(a.get("else", {}).get("actions", {}))

def strings(o):
    if isinstance(o, dict):
        for k, v in o.items(): yield from strings(k); yield from strings(v)
    elif isinstance(o, list):
        for v in o: yield from strings(v)
    elif isinstance(o, str): yield o

def expr_ok(s, where):
    if "@@" in s: bad(f"{where}: '@@' escape in a def string")
    if s.startswith("@"):
        body = re.sub(r"''", "", s)  # '' is an escaped quote inside an expression string
        if body.count("'") % 2: bad(f"{where}: odd number of quotes: {s[:60]}")
        unq = re.sub(r"'[^']*'", "''", body)
        if unq.count("(") != unq.count(")"): bad(f"{where}: unbalanced parentheses: {s[:60]}")
        if unq.count("[") != unq.count("]"): bad(f"{where}: unbalanced brackets: {s[:60]}")
    elif "@{" in s or "@(" in s: bad(f"{where}: '@{{' or '@(' inside a non-expression string")

counts = dict(defs=0, actions=0, columns=0, strings=0)
connrefs_declared = set()
cz = ROOT / "flow" / "solution" / "90161Z-flows-solution-r1.zip"
zf = zipfile.ZipFile(cz)
for n in zf.namelist():
    if n.endswith(".xml"): minidom.parseString(zf.read(n))
cust = zf.read("customizations.xml").decode("utf-8")
declared = set(re.findall(r'connectionreferencelogicalname="([^"]+)"', cust))
declared_ids = set(re.findall(r"<connectorid>/providers/Microsoft.PowerApps/apis/(\w+)</connectorid>", cust))
for n in zf.namelist():
    for host in re.findall(r"https?://([A-Za-z0-9.-]+)", zf.read(n).decode("utf-8")):
        if host not in ALLOWED_HOSTS: bad(f"{n}: URL host {host} not allowed")

for src in sorted(B.DEFS.glob("*.json")):
    counts["defs"] += 1
    if not re.fullmatch(r"90161Z-F\d{2}-[a-z0-9-]+-r\d+", src.stem): bad(f"BAD name {src.name}: use 90161Z-F<NN>-<slug>-r<N>")
    d = json.loads(src.read_text(encoding="utf-8"))
    if not d.get("triggers") or not d.get("actions"): bad(f"{src.name}: needs a trigger and actions")
    for s in strings(d):
        counts["strings"] += 1; expr_ok(s, src.name)
    for ref in re.findall(r"parameters\('([^']+)'\)", src.read_text(encoding="utf-8")):
        if not ref.startswith("$") and ref not in B.ENV_KEY.values(): bad(f"{src.name}: unknown environment variable {ref}")
    for c in d["connections"]:
        if c not in declared_ids: bad(f"{src.name}: connection {c} not declared in customizations.xml")
    # every connector named in a host is listed in "connections", and the matching workflow file refs a declared logical name
    hosts = {x["inputs"]["host"]["connectionName"] for _, x in walk_actions(d["actions"]) if isinstance(x.get("inputs"), dict) and "host" in x["inputs"]}
    hosts |= {t["inputs"]["host"]["connectionName"] for t in d["triggers"].values() if "host" in t.get("inputs", {})}
    if hosts != set(d["connections"]): bad(f"{src.name}: hosts used {sorted(hosts)} differ from connections {d['connections']}")
    wfs = [n for n in zf.namelist() if n.startswith("Workflows/" + src.stem + "-")]
    if len(wfs) != 1: bad(f"{src.name}: expected one workflow file in the zip, found {len(wfs)}"); continue
    wf = json.loads(zf.read(wfs[0]))["properties"]
    for c, ref in wf["connectionReferences"].items():
        if ref["connection"]["connectionReferenceLogicalName"] not in declared: bad(f"{src.name}: {c} logical name not in customizations.xml")
    if set(wf["connectionReferences"]) != set(d["connections"]): bad(f"{src.name}: workflow connectionReferences differ from def")
    if not wf["definition"].get("triggers") or not wf["definition"].get("actions"): bad(f"{src.name}: zip workflow lacks trigger or actions")
    trig_and_acts = [("trigger", t) for t in d["triggers"].values()] + [(n, a) for n, a in walk_actions(d["actions"])]
    for name, a in trig_and_acts:
        if name != "trigger": counts["actions"] += 1
        if name != "trigger" and re.search(r"""\[\s*'body/""", json.dumps(a)): bad(f"{src.name} {name}: body/ path expression; use body('Action')?['key']")
        for m in re.findall(r"\?\['(\w+)'\]", json.dumps(a)):
            if m not in all_cols: bad(f"{src.name} {name}: unknown column or property '{m}'")
        p = a.get("inputs", {}).get("parameters", {}) if isinstance(a.get("inputs"), dict) else {}
        if "table" in p:
            m = re.fullmatch(r"@parameters\('([^']+)'\)", p["table"])
            title = env_list.get(m.group(1)) if m else None
            if not title: bad(f"{src.name} {name}: table is not a list environment variable"); continue
            cols = schemas[title]
            used = set()
            for k, v in p.items():
                if k.startswith("item/"): used.add(k.split("/")[1])
                if k == "$filter":
                    used |= set(re.findall(r"([A-Za-z]\w*)(?:/Id)?\s+(?:eq|ne|ge|le|gt|lt)\s", v))
                if k == "$orderby":
                    used.add(v.split()[0])
            for u in used:
                counts["columns"] += 1
                if u not in cols and u not in {"ID", "Id"}: bad(f"{src.name} {name}: column '{u}' not in {title}")

# R17: the import failed with "component {guid} of type 29 is not declared in the solution file as a root component".
# Every zip (flow solution and test solutions): each WorkflowId is a lowercase GUID and has a RootComponent type 29 with the same id.
for z in [cz] + sorted((ROOT / "flow" / "solution").glob("90161Z-T17-*.zip")):
    with zipfile.ZipFile(z) as zz:
        c, sol = zz.read("customizations.xml").decode("utf-8"), zz.read("solution.xml").decode("utf-8")
    wids = re.findall(r'WorkflowId="\{([^}]+)\}"', c)
    roots = set(re.findall(r'<RootComponent type="29" id="\{([^}]+)\}"', sol))
    if not wids: bad(f"{z.name}: no workflow")
    for w in wids:
        if w != w.lower(): bad(f"{z.name}: WorkflowId {w} is not lowercase")
        if w not in roots: bad(f"{z.name}: workflow {w} has no RootComponent type 29 with the same id")
    if roots - set(wids): bad(f"{z.name}: RootComponent type 29 without a workflow: {sorted(roots - set(wids))}")

if errs:
    print("\n".join(errs)); sys.exit(1)
print(f"PASS flow solution: defs={counts['defs']} actions={counts['actions']} columns_checked={counts['columns']} strings={counts['strings']}")
