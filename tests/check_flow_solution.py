#!/usr/bin/env python3
"""Check the draft flow solution (flow/solution): def names, JSON, trigger and actions, list and column names against
schemas/lists, connection references, environment variables, "@" expression syntax, URL hosts. Prints one PASS line with counts."""
import json, pathlib, re, subprocess, sys, tempfile, zipfile
import xml.dom.minidom as minidom

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import build_flow_solution as B  # noqa: E402

errs = []
def bad(m):
    """Record one failure message. Takes the text; returns nothing."""
    errs.append(m)

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
    """Walk a flow's actions depth first, including the actions inside "actions" and "else" blocks. Takes the actions dict; yields (name, action)."""
    for name, a in actions.items():
        yield name, a
        for k in ("actions",):
            yield from walk_actions(a.get(k, {}))
        yield from walk_actions(a.get("else", {}).get("actions", {}))

def strings(o):
    """Walk a JSON value. Takes any JSON value; yields every string in it, keys included."""
    if isinstance(o, dict):
        for k, v in o.items(): yield from strings(k); yield from strings(v)
    elif isinstance(o, list):
        for v in o: yield from strings(v)
    elif isinstance(o, str): yield o

def expr_ok(s, where):
    """Check one string of a flow definition: no "@@" escape, and an expression has balanced quotes, parentheses and brackets. Takes the string and a place label; reports through bad()."""
    if "@@" in s: bad(f"{where}: '@@' escape in a def string")
    if s.startswith("@"):
        body = re.sub(r"''", "", s)  # '' is an escaped quote inside an expression string
        if body.count("'") % 2: bad(f"{where}: odd number of quotes: {s[:60]}")
        unq = re.sub(r"'[^']*'", "''", body)
        if unq.count("(") != unq.count(")"): bad(f"{where}: unbalanced parentheses: {s[:60]}")
        if unq.count("[") != unq.count("]"): bad(f"{where}: unbalanced brackets: {s[:60]}")
    elif "@{" in s or "@(" in s: bad(f"{where}: '@{{' or '@(' inside a non-expression string")

counts = dict(defs=0, actions=0, columns=0, strings=0)
# R34 (fallback A, the PFM 18 Nov 26): the T21 probe flows Health and Button are flows of the solution, on the probe list that the
# T21 Make part creates (its title and 4 columns, scripts/gov/90161Z-T21-probe-r8.ps1 and its make module).
PROBE_DEFS = {"90161Z-T21-probe-health-r6.json", "90161Z-T21-probe-button-r6.json"}
PROBE_LIST, PROBE_COLS = "90161Z Probe", {"Title", "ProbeTest", "ProbeWay", "ProbeResult", "ProbeDetail"}
connrefs_declared = set()
cz = ROOT / "flow" / "solution" / "90161Z-T24-full-flows-r4.zip"
zf = zipfile.ZipFile(cz)
for n in zf.namelist():
    if n.endswith(".xml"): minidom.parseString(zf.read(n))
cust = zf.read("customizations.xml").decode("utf-8")
# R29 (note N7): in the full solution a variable with a default is not required (isrequired 0); the 2 empty ones stay required.
for n in zf.namelist():
    if n.startswith("environmentvariabledefinitions/"):
        x = zf.read(n).decode("utf-8"); req = re.search(r"<isrequired>(\d)</isrequired>", x).group(1)
        if req != ("0" if "<defaultvalue>" in x else "1"): bad(f"{n}: isrequired {req} (want 0 with a default, else 1)")
for sz in (ROOT / "flow" / "solution").glob("90161Z-T1[78]-*.zip"):
    for n in zipfile.ZipFile(sz).namelist():
        if n.startswith("environmentvariabledefinitions/") and "<isrequired>1</isrequired>" not in zipfile.ZipFile(sz).read(n).decode("utf-8"): bad(f"{sz.name} {n}: slice and test solutions keep isrequired 1")
declared = set(re.findall(r'connectionreferencelogicalname="([^"]+)"', cust))
declared_ids = set(re.findall(r"<connectorid>/providers/Microsoft.PowerApps/apis/(\w+)</connectorid>", cust))
for n in zf.namelist():
    for host in re.findall(r"https?://([A-Za-z0-9.-]+)", zf.read(n).decode("utf-8")):
        if host not in ALLOWED_HOSTS: bad(f"{n}: URL host {host} not allowed")

for src in sorted(B.DEFS.glob("*.json")):
    counts["defs"] += 1
    if not re.fullmatch(r"90161Z-(F\d{2}|T21-probe)-[a-z0-9-]+-r\d+", src.stem): bad(f"BAD name {src.name}: use 90161Z-F<NN>-<slug>-r<N> (or 90161Z-T21-probe-<slug>-r<N>)")
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
        if "table" in p and src.name in PROBE_DEFS:   # R34: a probe flow names its list (made by T21 Make), as the r5 health flow did
            if p["table"] != PROBE_LIST: bad(f"{src.name} {name}: table must be the probe list '{PROBE_LIST}'")
            for k in p:
                if k.startswith("item/") and k.split("/")[1] not in PROBE_COLS: bad(f"{src.name} {name}: column '{k}' not in the probe list")
            continue
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

# R27 (PFM 14 and 16 Nov 26): F03, F05 and F06 read the six moved values from PFM Settings rows and add no "[TEST] " prefix. Fails if a def
# (or a zip) still holds "[TEST]" or reads a moved variable; every Settings key a flow reads is a seed row; the stage 6 target is 25 (PFM 14 Nov 26).
settings_seed = {r["Title"]: r for r in json.loads((ROOT / "schemas" / "lists" / "PFMSettings.json").read_text(encoding="utf-8"))["seed"]}
MOVED_KEYS = {"FlowsPaused": "No", "TestMode": "Yes", "ReminderLeadDays": "5", "EscalationLagDays": "3", "CoordinationSuspenseBusinessDays": "20", "SharedMailbox": ""}
for k, v in MOVED_KEYS.items():
    r = settings_seed.get(k)
    if not r: bad(f"PFMSettings.json seed has no row {k}"); continue
    if r["SettingValue"] != v: bad(f"PFMSettings.json seed {k}={r['SettingValue']!r}, expected {v!r}")
    if "DAFMAN" not in r["SettingNotes"] and "PFM 2026-11-1" not in r["SettingNotes"]: bad(f"PFMSettings.json seed {k}: SettingNotes cite no source")
steps = json.loads((ROOT / "schemas" / "lists" / "PFMProcessSteps.json").read_text(encoding="utf-8"))["seed"]
if [s["TargetBusinessDays"] for s in steps if s["StepNumber"] == 6] != [25]: bad("PFMProcessSteps.json: stage 6 TargetBusinessDays must be 25 (PFM 14 Nov 26)")
# R28 (PFM 17 Nov 26): F01, F02 and F04 read PFM Settings too, so all six flows start the same way.
r27_defs = [s for s in sorted(B.DEFS.glob("*.json")) if re.match(r"90161Z-F0[1-6]-", s.name)]
if len(r27_defs) != 6: bad(f"expected the six flow defs F01 to F06, found {[s.name for s in r27_defs]}")
for src in r27_defs:
    text = src.read_text(encoding="utf-8")
    if "[TEST]" in text: bad(f"{src.name}: still holds '[TEST]' (PFM 16 Nov 26: no subject or title prefix)")
    for s_ in B.MOVED_ENV:
        if s_ in text: bad(f"{src.name}: still reads {s_}; it is a PFM Settings row now")
    if "parameters('List PFM Settings (pfm_ListSettings)')" not in text or '"Get_settings"' not in text: bad(f"{src.name}: does not read PFM Settings at the start")
    for key in set(re.findall(r"item\(\)\?\['Title'\], '(\w+)'", text)):
        if key not in settings_seed: bad(f"{src.name}: reads Settings key {key}, which is not a seed row in PFMSettings.json")
    acts = json.loads(text)["actions"]["Try"]["actions"]
    if next(iter(acts)) != "Get_settings": bad(f"{src.name}: Get_settings is not the first step of the Try scope")
    if sum(1 for n, _ in walk_actions(json.loads(text)["actions"]) if n == "Get_settings") != 1: bad(f"{src.name}: PFM Settings must be read once")
for z in [cz] + sorted((ROOT / "flow" / "solution").glob("90161Z-T18-*.zip")):
    with zipfile.ZipFile(z) as zz:
        for n in zz.namelist():
            if re.match(r"Workflows/90161ZF0[356]", n) and "[TEST]" in zz.read(n).decode("utf-8"): bad(f"{z.name} {n}: '[TEST]' in a flow of the zip")

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
    """Flatten an XML document into (path, attributes, text) rows, with the free values masked, so two files can be compared. Takes the XML bytes; returns a list."""
    out = []
    def walk(e, path):
        """Add one element and its children to the list (path of the parent, then the element)."""
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
        # R27 (PFM 14 Nov 26): the six flow values are PFM Settings rows, not variables: none in a slice or the flow solution, and the
        # Settings list name is one (default "PFM Settings"). PFM 15 Nov 26: the values a wing sets are first, with numbered labels.
        moved = sorted(set(envs) & set(B.MOVED_ENV))
        if moved: bad(f"{z.name}: environment variables that moved to PFM Settings rows: {moved}")
        if "pfm_ListSettings" not in envs: bad(f"{z.name}: no pfm_ListSettings variable")
        first = re.findall(r'<RootComponent type="380" schemaName="([^"]+)"', sol)[:2]
        labels = [re.search(r'displayname default="([^"]+)"', zz.read(f"environmentvariabledefinitions/{e}/environmentvariabledefinition.xml").decode()).group(1) for e in first]
        if first != ["pfm_SiteUrl", "pfm_AlertEmail"] or [x[:2] for x in labels] != ["1 ", "2 "]:
            bad(f"{z.name}: the values to set are not first, in order, with numbered labels: {first} {labels}")
        if len(re.findall(r'<RootComponent type="29"', sol)) != 3: bad(f"{z.name}: slice 1 must hold exactly F03, F05 and F06 (R21)")
        # R21: F03 and F05 keep the workflow IDs R20 imported (seen in the R20 import log), so the import replaces them in place.
        for wid in ("ebafde19-9c84-50b7-9f36-6d1081350355", "dcdb2f79-1310-5048-8dae-cf0144bd576e"):
            if wid not in sol: bad(f"{z.name}: R20 workflow ID {wid} missing: the import would add a second copy")

def check_probe_flows(zz, cust_xml, zname):
    """R34 (fallback A): the upgrade must need no new connection, so check the probe flows and the whole solution zip.

    Args:
        zz: the open solution zip.
        cust_xml: its customizations.xml text.
        zname: the zip name for the messages.
    """
    sp = B.conn_logical("shared_sharepointonline")
    blob = "\n".join(zz.read(n).decode("utf-8", "replace") for n in zz.namelist())
    if "shared_flowmanagement" in blob or "Power Automate Management" in blob: bad(f"{zname}: the Power Automate Management connector is in the solution")
    for n in zz.namelist():
        if not re.match(r"Workflows/90161ZT21Probe", n): continue
        w = json.loads(zz.read(n).decode("utf-8"))["properties"]
        refs = {(k, r["connection"]["connectionReferenceLogicalName"]) for k, r in w["connectionReferences"].items()}
        if refs != {("shared_sharepointonline", sp)}: bad(f"{zname} {n}: a probe flow must use only the SharePoint reference {sp}: {sorted(refs)}")
    names = set(re.findall(r'connectionreferencelogicalname="([^"]+)"', cust_xml))
    if names != {sp, B.conn_logical("shared_office365")}: bad(f"{zname}: connection references {sorted(names)}; an upgrade must add none")
    look = (ROOT / "scripts" / "gov" / "90161Z-T21-look-r8.ps1").read_text(encoding="utf-8")
    bid = B.guid("workflow", "90161Z-T21-probe-button").lower()
    if f"$ButtonFlowId = '{bid}'" not in look or f'WorkflowId="{{{bid}}}"' not in cust_xml: bad(f"{zname}: the T21 look script does not name the button flow's workflow ID {bid}")


# R28: the full solution (R28, PFM 17 Nov 26: "the full solution with every flow On") holds F01 to F06, every flow On (StateCode 1), the
# same unique name as the slice (so it upgrades it), and every environment variable its flows read.
with zipfile.ZipFile(cz) as zz:
    c, sol = zz.read("customizations.xml").decode("utf-8"), zz.read("solution.xml").decode("utf-8")
    if len(re.findall(r'<RootComponent type="29"', sol)) != 8: bad(f"{cz.name}: must hold exactly 8 flows: F01 to F06 and the 2 T21 probe flows (R34)")
    if c.count("<StateCode>1</StateCode>") != 8 or "<StateCode>0</StateCode>" in c: bad(f"{cz.name}: every flow must import On")
    if "<UniqueName>PFM90161Z</UniqueName>" not in sol: bad(f"{cz.name}: unique name must be PFM90161Z (the slice's), so the import upgrades it")
    flows_in_zip = sorted(re.findall(r"Workflows/90161ZF(\d\d)[A-Za-z0-9]+-", "\n".join(zz.namelist())))
    if flows_in_zip != ["01", "02", "03", "04", "05", "06"]: bad(f"{cz.name}: flows in the zip {flows_in_zip}")
    envs_full = {n.split("/")[1] for n in zz.namelist() if n.startswith("environmentvariabledefinitions/")}
    if envs_full != {s for s, _, _ in B.ENV}: bad(f"{cz.name}: environment variables {sorted(envs_full)} differ from the list in the builder")
    probe_in_zip = sorted(re.findall(r"Workflows/(90161ZT21Probe(?:Health|Button)r\d+)-", "\n".join(zz.namelist())))
    if probe_in_zip != ["90161ZT21ProbeButtonr6", "90161ZT21ProbeHealthr6"]: bad(f"{cz.name}: probe flows in the zip {probe_in_zip}")
    check_probe_flows(zz, c, cz.name)
    slice_sol = zipfile.ZipFile(ROOT / "flow" / "solution" / "90161Z-T18-slice1-flows-r8.zip").read("solution.xml").decode("utf-8")
    for wid in re.findall(r'<RootComponent type="29" id="\{([^}]+)\}"', slice_sol):
        if f'id="{{{wid}}}"' not in sol: bad(f"{cz.name}: slice flow {wid} is not in the full solution (the import would not upgrade it)")

# R26 (task T21, probe flows): one unmanaged test solution built from flow/solution/test-defs/90161Z-T21-*.json:
# P (r3, R27, 17 Nov 26: 2 flows, 2 connection references: Health with the Power Automate Management connector, and Button with the
# "For a selected item" trigger; the files, mail and app flows of r2 are gone, their tests passed or failed in R26). Same file rules as the export (no XML declaration, CRLF, root
# components), and the data boundary: no ".mil", no mail address, no site host in any file. Every runAfter name exists on the same
# level; every "@parameters('...')" resolves; each RESULT row runs after every status; a trigger condition is in the F05 shape.
T21_EXPECT = {"90161Z-T21-probe-r5.zip": (1, 2)}
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

# R28 (full solution, task T24): the six flow defs share one shape (Try scope, settings read, Flows paused stop, failure e-mail), every
# runAfter name is a sibling, every expression names an action that exists, and no variable is initialized inside the scope.
for src in r27_defs:
    text = src.read_text(encoding="utf-8"); top = json.loads(text)["actions"]
    for need in ("Try", "Failed_actions", "Failure_lines", "E-mail_the_failure", "End_as_failed"):
        if need not in top: bad(f"{src.name}: no top-level '{need}' (Try scope with failure e-mail)")
    if "Try" in top:
        if "If_flows_paused" not in top["Try"]["actions"]: bad(f"{src.name}: no Flows paused stop in the Try scope")
        if any(a.get("type") == "InitializeVariable" for _, a in walk_actions(top["Try"]["actions"])): bad(f"{src.name}: a variable is initialized inside the Try scope (initialize at the top level)")
    check_levels(top, src.name)
    names = {n for n, _ in walk_actions(top)}
    for m in re.findall(r"(?:outputs|body|actions|result)\('([^']+)'\)", text):
        if m not in names: bad(f"{src.name}: an expression names action '{m}', which does not exist")
# F04 (2.6.8): test mode sends the report to the alert address only and says so; F01 logs only its own rows as "last state" and nothing on a note edit
# (it reads Action Type, Process Step and Action Status only).
f04 = next(s for s in r27_defs if "-F04-" in s.name).read_text(encoding="utf-8")
if "Test_mode" not in f04 or "parameters('Alert e-mail (pfm_AlertEmail)'), triggerBody()?['text']" not in f04: bad("F04: test mode must send to the alert address")
# F04 r3 (R32 finding 9): each head sits over its column (heads and cells share one alignment) and the Number column shows the
# number (the row's own, else its Product Index row's) or a dash.
f04_try = json.loads(f04)["actions"]["Try"]["actions"]["For_each_process_step"]["actions"]["If_any_actions"]["actions"]
f04_html = f04_try["Append_stage_section"]["inputs"]["value"]
th, td = re.findall(r"'<th style=\\?\"([^\"\\]+)\\?\">'", f04_html), re.findall(r"'<td style=\\?\"([^\"\\]+)\\?\">'", f04_html)
if not (th and td and th == td and "text-align:left" in th[0]): bad(f"F04: heads and cells must share one alignment: th {th} td {td}")
if "replace(replace(body('Create_HTML_table'), '<th>'" not in f04_html: bad("F04: the table heads and cells are not styled")
num = f04_try["Create_HTML_table"]["inputs"]["columns"][0]
if num["header"] != "Number" or "'-'" not in num["value"] or "PublicationNumber" not in num["value"] or "['Product']?['Value']" not in num["value"]: bad(f"F04: the Number column must show the number or a dash: {num}")
f01 = json.loads(next(s for s in r27_defs if "-F01-" in s.name).read_text(encoding="utf-8"))
f01_state = json.dumps(f01["actions"]["Try"]["actions"]["Current_state"]["inputs"])
if sorted(re.findall(r"\['(\w+)'\]", f01_state)) != sorted(["ActionType", "ProcessStep", "ActionStatus", "Value", "Value", "Value"]): bad(f"F01: the logged state must read exactly Action Type, Process Step and Action Status: {f01_state}")
if "Own_log_rows" not in f01["actions"]["Try"]["actions"]: bad("F01: the last logged state must come from rows this flow wrote (Own_log_rows)")
# R34 (PFM 19 Nov 26, F3 C): F01 checks PFM Publications every 15 minutes (was every minute), in the def and in the zip.
# R35 (PFM 19 Nov 26): F05 checks every minute, so no action passes step 7 between 2 checks without its Legal rows.
# The other flows keep their triggers.
f05_src = next(s for s in r27_defs if "-F05-" in s.name)
f05 = json.loads(f05_src.read_text(encoding="utf-8"))
POLL = {"01": 15, "05": 1}   # minutes between checks, by flow number
for name, d in (("F01", f01), ("F05", f05)):
    trig = d["triggers"]["When_an_item_is_created_or_modified"]
    want = {"frequency": "Minute", "interval": POLL[name[1:]]}
    if trig["recurrence"] != want: bad(f"{name}: the trigger must check every {want['interval']} minute(s): {trig['recurrence']}")
    if trig["inputs"]["parameters"]["table"] != "@parameters('List PFM Publications (pfm_ListPublications)')": bad(f"{name}: the trigger must watch PFM Publications")
with zipfile.ZipFile(cz) as zz:
    for n in zz.namelist():
        m = re.match(r"Workflows/90161ZF(0[15])", n)
        if m:
            rec = json.loads(zz.read(n).decode("utf-8"))["properties"]["definition"]["triggers"]["When_an_item_is_created_or_modified"]["recurrence"]
            if rec != {"frequency": "Minute", "interval": POLL[m.group(1)]}: bad(f"{cz.name} {n}: F{m.group(1)} must check every {POLL[m.group(1)]} minute(s): {rec}")
# R34 (PFM 19 Nov 26, F1 A; DAFMAN 90-161 5.1.7: a wing GM requires local legal review, stages 1-3 then 7-11): F05 adds the missing
# Legal rows whenever it sees an open action at step 7, whatever path brought it there, and only for offices with no Legal row yet
# (check before create, so a second entry to step 7 or a second run adds none; a title cut at 250 characters still counts).
f05_open = f05["actions"]["Try"]["actions"]["If_action_open"]
f05_cond = json.dumps(f05_open["expression"])
if "ProcessStep" not in f05_cond or "'On Hold', 'Cancelled', 'Complete'" not in f05_cond: bad("F05: the step rules must run only for an open action with a process step")
s7 = f05_open["actions"].get("If_step_7", {})
if s7.get("expression") != {"equals": ["@body('Get_process_step')?['StepNumber']", 7]}: bad(f"F05: If_step_7 must test StepNumber 7: {s7.get('expression')}")
if set(s7.get("runAfter", {}).get("If_step_6", [])) != {"Succeeded", "Skipped"}: bad("F05: If_step_7 must run after If_step_6 whether it ran or was skipped")
if "5.1.7" not in s7.get("description", "") or "5.1.7" not in f05["description"]: bad("F05: the step-7 rule must cite DAFMAN 90-161 5.1.7")
s7_acts = s7.get("actions", {})
if s7_acts.get("Get_legal_offices_at_step_7", {}).get("inputs", {}).get("parameters", {}).get("$filter") != "CoordinateLast eq 1 and IsActive eq 1": bad("F05: step 7 must read the active CoordinateLast (Legal) offices")
if s7_acts.get("Create_legal_rows_at_step_7", {}).get("foreach") != "@body('Missing_legal_offices_at_step_7')": bad("F05: step 7 must create rows only for the missing offices")
legal_rows = f05_open["actions"]["Legal_rows"]["inputs"]
if legal_rows != {"from": "@body('Get_endorsement_rows')?['value']", "where": "@equals(item()?['CoordinationStage']?['Value'], 'Legal')"}: bad(f"F05: Legal_rows must be every Legal row of the action: {legal_rows}")
if f05_open["actions"]["Get_endorsement_rows"]["inputs"]["parameters"].get("$filter") != "@concat('Publication/Id eq ', string(triggerBody()?['ID']))": bad("F05: the endorsement rows must be read for this action in this run")
# R35 (R34 plan open points 7 and 9): a Formal or Legal row title cuts the publication title, never the office, so every new row
# ends with ' - <office>|' in the title list; the older full-title key (r4 rows, cut at 250) counts only for a publication title
# under 247 characters (from 247 on, that key was the same for every office, so one row hid all the others).
PUB = "coalesce(triggerBody()?['Title'], '')"


def f05_where(title_list):
    """The exists check (Query "where") that F05 r5 must use for one title list. Takes the Compose name; returns the text."""
    off = "coalesce(item()?['Title'], '')"
    new = f"contains(outputs('{title_list}'), concat(' - ', {off}, '|'))"
    old = f"and(less(length({PUB}), 247), contains(outputs('{title_list}'), concat('|', take(concat({PUB}, ' - ', {off}), 250), '|')))"
    return f"@not(or({new}, {old}))"


def f05_title(loop):
    """The row title F05 r5 must write in one Foreach loop. Takes the loop name; returns the text."""
    off = f"coalesce(items('{loop}')?['Title'], '')"
    return f"@take(concat(take({PUB}, max(0, sub(247, length({off})))), ' - ', {off}), 250)"


s6_acts = f05_open["actions"]["If_step_6"]["actions"]
ready = s6_acts["If_formal_rows_added"]["else"]["actions"]["If_ready_for_Legal"]["actions"]
for qn, q, tl in (("Missing_formal_offices", s6_acts["Missing_formal_offices"], "Formal_title_list"),
                  ("Missing_legal_offices", ready["Missing_legal_offices"], "Legal_title_list"),
                  ("Missing_legal_offices_at_step_7", s7_acts.get("Missing_legal_offices_at_step_7", {}), "Legal_title_list")):
    if q.get("inputs", {}).get("where", "") != f05_where(tl): bad(f"F05 {qn}: an office counts as done only by its ' - <office>' ending: {q.get('inputs')}")
for loop, cond, stage, rows in (("Create_formal_rows", "If_office_has_endorser_Formal", "Formal Coordination", s6_acts),
                                ("Create_legal_rows", "If_office_has_endorser_Legal", "Legal", ready),
                                ("Create_legal_rows_at_step_7", "If_office_has_endorser_Legal_7", "Legal", s7_acts)):
    br = rows[loop]["actions"][cond]
    for p in [a["inputs"]["parameters"] for a in list(br["actions"].values()) + list(br["else"]["actions"].values())]:
        if p.get("item/CoordinationStage/Value") != stage or p.get("item/Title") != f05_title(loop):
            bad(f"F05 {loop}: a {stage} row must have the title the exists check reads (office kept): {p.get('item/Title')}")
# R35 (R34 finding 1, ActionDescriptionTooLong): no action description in the flow solution is over 256 characters, and the
# builder fails (exit 1, file, action path, length) on a longer one at any depth (If else, Scope, Foreach, Switch case).
for src in sorted(B.DEFS.glob("*.json")) + sorted(B.TEST_DEFS.glob("*.json")):
    for ap_, n in B.long_action_descriptions(json.loads(src.read_text(encoding="utf-8")).get("actions")):
        bad(f"{src.name}: action {ap_} has a description of {n} characters (Power Automate allows 256)")
deep = {"If_a": {"type": "If", "actions": {}, "else": {"actions": {"Sw": {"type": "Switch", "cases": {"c1": {"actions": {"Do_c": {"description": "x" * 257}}}}}}}}}
if B.long_action_descriptions(deep) != [("/actions/If_a/else/actions/Sw/cases/c1/actions/Do_c", 257)]: bad(f"builder misses a deep description: {deep}")
deep["If_a"]["else"]["actions"]["Sw"]["cases"]["c1"]["actions"]["Do_c"]["description"] = "x" * 256
if B.long_action_descriptions(deep) != []: bad("builder refuses a description of exactly 256 characters")
with tempfile.TemporaryDirectory() as tmp:
    (pathlib.Path(tmp) / "bad.json").write_text(json.dumps({"actions": {"Try": {"actions": {"Long": {"description": "y" * 300}}}}}))
    code = (f"import sys, pathlib; sys.path.insert(0, {str(ROOT / 'scripts')!r}); import build_flow_solution as B; "
            f"B.ROOT = pathlib.Path({tmp!r}); B.check_action_descriptions((B.ROOT,))")
    r = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True)
    if r.returncode != 1 or "bad.json: action /actions/Try/actions/Long has a description of 300 characters" not in r.stdout:
        bad(f"builder must exit 1 and name the file, action path and length: {r.returncode} {r.stdout} {r.stderr}")

t21_zips = sorted((ROOT / "flow" / "solution").glob("90161Z-T21-*.zip"))
if sorted(z.name for z in t21_zips) != sorted(T21_EXPECT): bad(f"T21 zips found {[z.name for z in t21_zips]}, expected {sorted(T21_EXPECT)}")
t21_defs = sorted(B.TEST_DEFS.glob("90161Z-T21-*.json"))
if len(t21_defs) != 1: bad(f"expected 1 T21 test def (health only), found {len(t21_defs)}")
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
        elif t.get("type") == "OpenApiConnectionNotification":
            # R27: the SharePoint "For a selected item" trigger (the view button); no polling, no condition.
            if t["inputs"]["host"]["operationId"] != "OnSelectedItem" or t["inputs"]["parameters"].get("dataset") != "@parameters('Site URL (pfm_SiteUrl)')" or t["inputs"]["parameters"].get("table") != "90161Z Probe":
                bad(f"{src.name}: a selected-item trigger must be OnSelectedItem on the probe list")
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
print(f"PASS flow solution: flows_in_r4=8 t21_zips={len(t21_zips)} t21_defs={len(t21_defs)} defs={counts['defs']} actions={counts['actions']} columns_checked={counts['columns']} strings={counts['strings']}")
