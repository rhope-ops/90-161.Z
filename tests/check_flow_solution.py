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
# make.powerautomate.appsplatform.us: the public DoD Power Automate portal, for the run link in the failure e-mail (PFM 1A, 14 Nov 26).
ALLOWED_HOSTS = {"schema.management.azure.com", "www.w3.org", "schemas.openxmlformats.org", "make.powerautomate.appsplatform.us"}
BUILTIN = {"ID", "Id", "Value", "value", "Email", "Claims", "Title", "Editor", "Author", "Created", "Modified", "text"}

schemas = {}
for f in (ROOT / "schemas" / "lists").glob("*.json"):
    d = json.loads(f.read_text(encoding="utf-8"))
    schemas[d["title"]] = {x["internalName"] for x in d["fields"]}
# Run properties of workflow() and result('Try') that the failure e-mail reads (slice r2, 14 Nov 26); not list columns.
RUNTIME = {"name", "status", "error", "code", "message", "tags", "flowDisplayName", "environmentName", "run"}
RUNTIME_ACTIONS = {"Failed_actions", "Failure_lines", "E-mail_the_failure"}   # only these may read them (review, 14 Nov 26)
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
    key = d.get("workflowKey")   # R21: the stem of the revision first imported (same flow, earlier revision)
    if key and not (re.sub(r"-r\d+$", "", key) == re.sub(r"-r\d+$", "", src.stem) and int(key.rsplit("-r", 1)[1]) < int(src.stem.rsplit("-r", 1)[1])):
        bad(f"{src.name}: workflowKey {key} is not an earlier revision of the same flow")
    wid = B.guid("workflow", key) if key else B.flow_guid(src.stem)
    wfs = [n for n in zf.namelist() if n == B.json_name(d["displayName"], wid)[1:]]
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
            if m not in all_cols and not (name in RUNTIME_ACTIONS and m in RUNTIME): bad(f"{src.name} {name}: unknown column or property '{m}'")
        p = a.get("inputs", {}).get("parameters", {}) if isinstance(a.get("inputs"), dict) else {}
        # R20 finding 1: "Update item" (PatchItem) fails flow activation without item/Title (a required column).
        if isinstance(a.get("inputs"), dict) and a["inputs"].get("host", {}).get("operationId") == "PatchItem" and "item/Title" not in p:
            bad(f"{src.name} {name}: PatchItem without item/Title (activation fails: R20 finding 1)")
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
SLICES = sorted((ROOT / "flow" / "solution").glob("90161Z-T18-*.zip"))
for z in [cz] + sorted((ROOT / "flow" / "solution").glob("90161Z-T17-*.zip")) + SLICES:
    with zipfile.ZipFile(z) as zz:
        c, sol = zz.read("customizations.xml").decode("utf-8"), zz.read("solution.xml").decode("utf-8")
    wids = re.findall(r'WorkflowId="\{([^}]+)\}"', c)
    roots = set(re.findall(r'<RootComponent type="29" id="\{([^}]+)\}"', sol))
    if not wids: bad(f"{z.name}: no workflow")
    for w in wids:
        if w != w.lower(): bad(f"{z.name}: WorkflowId {w} is not lowercase")
        if w not in roots: bad(f"{z.name}: workflow {w} has no RootComponent type 29 with the same id")
    if roots - set(wids): bad(f"{z.name}: RootComponent type 29 without a workflow: {sorted(roots - set(wids))}")

# R19 (r5): each test zip has the layout of the PFM's R18 export (flow/solution/export-sample): the same elements, attributes
# and values in the same order, apart from names, IDs and the connection reference, and the same bytes for [Content_Types].xml.
import xml.etree.ElementTree as ET  # noqa: E402
SAMPLE = ROOT / "flow" / "solution" / "export-sample"
FREE_TEXT = {"UniqueName", "JsonFileName", "connectionreferencedisplayname"}   # values that name this solution, not its layout
FREE_ATTR = {"description", "id", "WorkflowId", "Name", "connectionreferencelogicalname"}

def layout(xml_bytes):
    out = []
    def walk(e, path):
        tag = e.tag.split("}")[-1]; p = path + "/" + tag
        pub = "/Publisher/" in p + "/"   # the publisher must match the export exactly, apart from its masked display name
        attrs = tuple((k, "*" if k in FREE_ATTR and not (pub and k != "description") else v) for k, v in e.attrib.items())
        out.append((p, attrs, "*" if tag in FREE_TEXT and not pub else (e.text or "").strip()))
        for c in e: walk(c, p)
    walk(ET.fromstring(xml_bytes), ""); return out

ref_ct = None
for z in sorted((ROOT / "flow" / "solution").glob("90161Z-T17-*.zip")):
    with zipfile.ZipFile(z) as zz:
        for f in ("solution.xml", "customizations.xml"):
            got, want = zz.read(f), (SAMPLE / f).read_bytes()
            if got.startswith(b"<?xml") or got.startswith(b"\xef\xbb\xbf"): bad(f"{z.name} {f}: starts with an XML declaration or BOM; the export has neither")
            if b"\r\n" not in got or got.endswith(b"\n"): bad(f"{z.name} {f}: line ends differ from the export (CRLF, no final line end)")
            lg, lw = layout(got), layout(want)
            if lg != lw:
                diff = next(((g, w) for g, w in zip(lg, lw) if g != w), (lg[len(lw):len(lw) + 1], lw[len(lg):len(lg) + 1]))
                bad(f"{z.name} {f}: layout differs from the export sample at {diff}")
        if zz.read("[Content_Types].xml") != (ref_ct := ref_ct or "\ufeff<?xml version=\"1.0\" encoding=\"utf-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/octet-stream\" /><Default Extension=\"json\" ContentType=\"application/octet-stream\" /></Types>".encode("utf-8")):
            bad(f"{z.name}: [Content_Types].xml differs from the export")
        for n in zz.namelist():
            if n.startswith("Workflows/"):
                wf = json.loads(zz.read(n).decode("utf-8"))["properties"]["definition"]
                if "outputs" in wf: bad(f"{z.name} {n}: definition has 'outputs'; the export has none")
                if "@parameters('$authentication')" in json.dumps(wf): bad(f"{z.name} {n}: manual flow uses @parameters('$authentication'); the export uses the run token")

# R20 (slice 1, task T18): several flows, two connection references and environment variables, so the element-by-element
# comparison above does not apply. Each slice keeps the export's file rules and has one RootComponent type 380 per
# environment variable file, none with an XML declaration, and the F03 settings decided by the PFM (2026-11-14).
for z in SLICES:
    with zipfile.ZipFile(z) as zz:
        for f in ("solution.xml", "customizations.xml"):
            got = zz.read(f)
            if got.startswith(b"<?xml") or got.startswith(b"\xef\xbb\xbf"): bad(f"{z.name} {f}: starts with an XML declaration or BOM")
            if b"\r\n" not in got or got.endswith(b"\n"): bad(f"{z.name} {f}: line ends differ from the export")
        sol = zz.read("solution.xml").decode("utf-8")
        envs = [n.split("/")[1] for n in zz.namelist() if n.startswith("environmentvariabledefinitions/")]
        roots380 = set(re.findall(r'<RootComponent type="380" schemaName="([^"]+)"', sol))
        if set(envs) != roots380: bad(f"{z.name}: environment variable files {sorted(envs)} differ from type 380 roots {sorted(roots380)}")
        for n in zz.namelist():
            if n.startswith("environmentvariabledefinitions/") and zz.read(n).startswith(b"<?xml"): bad(f"{z.name} {n}: XML declaration")
        defaults = {e: re.search(r"<defaultvalue>([^<]*)</defaultvalue>", zz.read(f"environmentvariabledefinitions/{e}/environmentvariabledefinition.xml").decode()) for e in envs}
        if (defaults.get("pfm_ReminderLeadDays") or [None, None])[1] != "5" or (defaults.get("pfm_EscalationLagDays") or [None, None])[1] != "3":
            bad(f"{z.name}: F03 defaults are not 5 and 3 (PFM, 2026-11-14)")
        # PFM 15 Nov 26: the values a wing sets are first and together (file order and numbered labels); a slice imports Test mode Yes.
        first = re.findall(r'<RootComponent type="380" schemaName="([^"]+)"', sol)[:4]
        labels = [re.search(r'displayname default="([^"]+)"', zz.read(f"environmentvariabledefinitions/{e}/environmentvariabledefinition.xml").decode()).group(1) for e in first]
        if first != ["pfm_SiteUrl", "pfm_AlertEmail", "pfm_SharedMailbox", "pfm_TestMode"] or [x[:2] for x in labels] != ["1 ", "2 ", "3 ", "4 "]:
            bad(f"{z.name}: the values to set are not first, in order, with numbered labels: {first} {labels}")
        if (defaults.get("pfm_TestMode") or [None, None])[1] != "Yes": bad(f"{z.name}: a test-round slice must import with Test mode Yes")
        if b"<isrequired>0</isrequired>" not in zz.read("environmentvariabledefinitions/pfm_SharedMailbox/environmentvariabledefinition.xml"):
            bad(f"{z.name}: the shared mailbox variable must be optional")
        if len(re.findall(r'<RootComponent type="29"', sol)) != 3: bad(f"{z.name}: slice 1 must hold exactly F03, F05 and F06 (R21)")
        # R21: F03 and F05 keep the workflow IDs R20 imported (seen in the R20 import log), so the import replaces them in place.
        for wid in ("ebafde19-9c84-50b7-9f36-6d1081350355", "dcdb2f79-1310-5048-8dae-cf0144bd576e"):
            if wid not in sol: bad(f"{z.name}: R20 workflow ID {wid} missing: the import would add a second copy")

# R26 (task T21, probe flows): one unmanaged test solution built from flow/solution/test-defs/90161Z-T21-*.json:
# P (3 flows, 5 connection references; r2, 16 Nov 26: the Word and Mail solutions were refused in r1 and are gone). Same file rules as the export (no XML declaration, CRLF, root
# components), and the data boundary: no ".mil", no mail address, no site host in any file. Every runAfter name exists on the same
# level; every "@parameters('...')" resolves; each RESULT row runs after every status; a trigger condition is in the F05 shape.
T21_EXPECT = {"90161Z-T21-probe-r2.zip": (3, 5)}
ALL_STATUS = {"Succeeded", "Failed", "Skipped", "TimedOut"}
T21_HOSTS = ALLOWED_HOSTS   # Graph calls use relative URIs (/v1.0/...): the DoD tenant has its own Graph host, so no host is named

def check_levels(actions, where, outer=()):
    """runAfter names must be siblings (same level); names are unique across the flow."""
    for name, a in actions.items():
        for dep, statuses in a.get("runAfter", {}).items():
            if dep not in actions: bad(f"{where}: {name} runs after '{dep}', which is not on the same level")
            if not set(statuses) <= ALL_STATUS: bad(f"{where}: {name} has unknown run-after status {statuses}")
        p = a.get("inputs", {}).get("parameters", {}) if isinstance(a.get("inputs"), dict) else {}
        if p.get("item/Title") == "RESULT" or p.get("item/Title") in ("T2-PDF", "T4b"):
            for dep, statuses in a.get("runAfter", {}).items():
                if set(statuses) != ALL_STATUS and not (name.startswith("T4b_row") or name == "T2_pdf_row"):
                    bad(f"{where}: {name} writes a row but runs only after {dep} {statuses}; capture every status")
        for sub in (a.get("actions", {}), a.get("else", {}).get("actions", {})):
            check_levels(sub, where)

t21_zips = sorted((ROOT / "flow" / "solution").glob("90161Z-T21-*.zip"))
if sorted(z.name for z in t21_zips) != sorted(T21_EXPECT): bad(f"T21 zips found {[z.name for z in t21_zips]}, expected {sorted(T21_EXPECT)}")
t21_defs = sorted(B.TEST_DEFS.glob("90161Z-T21-*.json"))
if len(t21_defs) != 3: bad(f"expected 3 T21 test defs, found {len(t21_defs)}")
by_zip = {}
for src in t21_defs:
    d = json.loads(src.read_text(encoding="utf-8"))
    by_zip.setdefault(d["solution"]["zip"], []).append(d)
    names = set(re.findall(r"actions\('([^']+)'\)|outputs\('([^']+)'\)|body\('([^']+)'\)", json.dumps(d["actions"])))
    all_names = {n for n, _ in walk_actions(d["actions"])}
    for tup in names:
        for n in tup:
            if n and n not in all_names: bad(f"{src.name}: expression names action '{n}', which does not exist")
    check_levels(d["actions"], src.name)
    for s in strings(d): expr_ok(s, src.name)
    for ref in re.findall(r"parameters\('([^']+)'\)", src.read_text(encoding="utf-8")):
        if not ref.startswith("$") and ref not in B.ENV_KEY.values(): bad(f"{src.name}: unresolved parameter {ref}")
    hosts = {x["inputs"]["host"]["connectionName"] for _, x in walk_actions(d["actions"]) if isinstance(x.get("inputs"), dict) and "host" in x["inputs"]}
    hosts |= {t["inputs"]["host"]["connectionName"] for t in d["triggers"].values() if "host" in t.get("inputs", {})}
    if hosts != set(d["connections"]): bad(f"{src.name}: hosts used {sorted(hosts)} differ from connections {d['connections']}")
    for tn, t in d["triggers"].items():
        if t.get("kind") == "PowerAppV2":
            if "text" not in t["inputs"]["schema"]["properties"]: bad(f"{src.name}: PowerAppV2 trigger has no text input")
        else:
            c = t.get("conditions")
            if not (isinstance(c, list) and c and all(set(x) == {"expression"} and x["expression"].startswith("@") for x in c)): bad(f"{src.name}: trigger condition not in the form [{{expression}}]")
            if t["inputs"]["host"]["operationId"] != "GetOnNewItems" or t["inputs"]["parameters"].get("dataset") != "@parameters('Site URL (pfm_SiteUrl)')":
                bad(f"{src.name}: trigger is not GetOnNewItems on the Site URL variable")
    if re.search(r"\.mil\b|@[A-Za-z0-9-]+\.(com|net|org|gov|edu|us)\b|sharepoint\.(com|us)", src.read_text(encoding="utf-8")): bad(f"{src.name}: address or host text in the def")
for zname, (nwf, ncr) in T21_EXPECT.items():
    z = ROOT / "flow" / "solution" / zname
    if not z.exists(): continue
    with zipfile.ZipFile(z) as zz:
        for n in zz.namelist():
            if n.endswith(".xml"): minidom.parseString(zz.read(n))
        blob = "\n".join(zz.read(n).decode("utf-8") for n in zz.namelist())
        c, sol = zz.read("customizations.xml").decode("utf-8"), zz.read("solution.xml").decode("utf-8")
        if re.search(r"\.mil\b", blob, re.I): bad(f"{zname}: holds '.mil'")
        if re.search(r"@[A-Za-z0-9-]+\.(com|net|org|gov|edu|us|mil)\b", blob): bad(f"{zname}: holds an '@' followed by a mail domain")
        if re.search(r"sharepoint\.(com|us)|https?://[^/\s\"]*sharepoint", blob, re.I): bad(f"{zname}: holds sharepoint host text")
        for host in re.findall(r"https?://([A-Za-z0-9.-]+)", blob):
            if host not in T21_HOSTS: bad(f"{zname}: URL host {host} not allowed")
        for f in ("solution.xml", "customizations.xml"):
            got = zz.read(f)
            if got.startswith(b"<?xml") or got.startswith(b"\xef\xbb\xbf"): bad(f"{zname} {f}: starts with an XML declaration or BOM")
            if b"\r\n" not in got or got.endswith(b"\n"): bad(f"{zname} {f}: line ends differ from the export")
        if zz.read("[Content_Types].xml") != ref_ct: bad(f"{zname}: [Content_Types].xml differs from the export")
        wids = re.findall(r'WorkflowId="\{([^}]+)\}"', c)
        roots = set(re.findall(r'<RootComponent type="29" id="\{([^}]+)\}"', sol))
        if len(wids) != nwf or set(wids) != roots: bad(f"{zname}: {len(wids)} workflows, {len(roots)} roots; expected {nwf}")
        if any(w != w.lower() for w in wids): bad(f"{zname}: WorkflowId not lowercase")
        if len(re.findall(r"<connectionreference ", c)) != ncr: bad(f"{zname}: expected {ncr} connection references")
        if c.count("<StateCode>1</StateCode>") != nwf: bad(f"{zname}: every probe flow imports On (StateCode 1)")
        envs = {n.split("/")[1] for n in zz.namelist() if n.startswith("environmentvariabledefinitions/")}
        if envs != set(re.findall(r'<RootComponent type="380" schemaName="([^"]+)"', sol)): bad(f"{zname}: environment variable files differ from type 380 roots")
        want_env = set()
        for n in zz.namelist():
            if n.startswith("environmentvariabledefinitions/") and zz.read(n).startswith(b"<?xml"): bad(f"{zname} {n}: XML declaration")
            if n.startswith("Workflows/"):
                w = json.loads(zz.read(n).decode("utf-8"))["properties"]
                wf = w["definition"]
                if "outputs" in wf: bad(f"{zname} {n}: definition has 'outputs'")
                if "RunToken" in json.dumps(w) or "X-MS-APIM-Tokens" in json.dumps(w): bad(f"{zname} {n}: run-token authentication; probe flows use the owner connections")
                if {r["runtimeSource"] for r in w["connectionReferences"].values()} != {"embedded"}: bad(f"{zname} {n}: connections must be embedded")
                for r in w["connectionReferences"].values():
                    if r["connection"]["connectionReferenceLogicalName"] not in c: bad(f"{zname} {n}: logical name not in customizations.xml")
                for ref in re.findall(r"parameters\('([^']+)'\)", json.dumps(wf)):
                    if ref.startswith("$"): continue
                    if ref not in wf["parameters"]: bad(f"{zname} {n}: parameter {ref} not declared")
                    else: want_env.add(wf["parameters"][ref]["metadata"]["schemaName"])
        if envs != want_env: bad(f"{zname}: environment variables {sorted(envs)} differ from the ones the flows read {sorted(want_env)}")
    if sorted(d["displayName"] for d in by_zip.get(zname, [])) != sorted(set(d["displayName"] for d in by_zip.get(zname, []))): bad(f"{zname}: duplicate flow names")
    if len(by_zip.get(zname, [])) != nwf: bad(f"{zname}: expected {nwf} defs, found {len(by_zip.get(zname, []))}")

if errs:
    print("\n".join(errs)); sys.exit(1)
print(f"PASS flow solution: t21_zips={len(t21_zips)} t21_defs={len(t21_defs)} defs={counts['defs']} actions={counts['actions']} columns_checked={counts['columns']} strings={counts['strings']}")
