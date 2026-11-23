"""Helpers of tests/check_flow_solution.py (the draft flow solution check): the failure list, action and string walkers, the XML layout
flattener, the zip checks and the F05 row text. Run only by that script, which imports it; it prints nothing and exits with nothing.
Every helper reads the repo through the names below (ROOT, B = scripts/build_flow_solution.py) and records a failure with bad()."""
import json, pathlib, re, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import build_flow_solution as B  # noqa: E402

errs = []
def bad(m):
    """Record one failure message. Takes the text; returns nothing."""
    errs.append(m)

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
    look = (ROOT / "scripts" / "gov" / "90161Z-T21-look-r11.ps1").read_text(encoding="utf-8")
    bid = B.guid("workflow", "90161Z-T21-probe-button").lower()
    if f"$ButtonFlowId = '{bid}'" not in look or f'WorkflowId="{{{bid}}}"' not in cust_xml: bad(f"{zname}: the T21 look script does not name the button flow's workflow ID {bid}")

def check_list_placeholders(zz, zname):
    """R36 (README choice 11): every list variable's default is the placeholder of its list, in the variable file and in each flow's
    parameters, so the T24 task script (r7, module zip) can write the GUIDs; it finds them by the same mark and names the r5 zip.

    Args:
        zz: the open full solution zip.
        zname: the zip name for the messages.
    """
    for s, title in B.LIST_TITLES.items():
        x = zz.read(f"environmentvariabledefinitions/{s}/environmentvariabledefinition.xml").decode("utf-8")
        if f"<defaultvalue>{B.list_placeholder(title)}</defaultvalue>" not in x: bad(f"{zname} {s}: default is not the placeholder {B.list_placeholder(title)}")
    for n in zz.namelist():
        if not n.startswith("Workflows/"): continue
        for k, v in json.loads(zz.read(n).decode("utf-8"))["properties"]["definition"]["parameters"].items():
            s = v.get("metadata", {}).get("schemaName", "")
            if s in B.LIST_TITLES and v["defaultValue"] != B.list_placeholder(B.LIST_TITLES[s]): bad(f"{zname} {n}: {k} default is not the placeholder")
    t24 = (ROOT / "scripts" / "gov" / "90161Z-T24-zip-r7.ps1").read_text(encoding="utf-8")   # T24 r7, module zip (part 0)
    if f"$ListGuidMark = '{B.LIST_GUID_MARK}'" not in t24: bad(f"T24 r7 module zip: $ListGuidMark is not the builder's mark {B.LIST_GUID_MARK}")
    if f"'{zname}'" not in t24: bad(f"T24 r7 module zip does not name the solution zip {zname}")

ALL_STATUS = {"Succeeded", "Failed", "Skipped", "TimedOut"}

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

def check_action_description_limit():
    """R35: the builder finds a description over 256 characters at any depth and exits 1 naming file, path and length. Takes nothing; records failures."""
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

# Run properties of workflow() and result('Try') that the failure e-mail reads (slice r2, 14 Nov 26); not list columns.
RUNTIME = {"name", "status", "error", "code", "message", "tags", "flowDisplayName", "environmentName", "run"}
RUNTIME_ACTIONS = {"Failed_actions", "Failure_lines", "E-mail_the_failure"}   # only these may read them (review, 14 Nov 26)
# R34 (fallback A, the PFM 18 Nov 26): the T21 probe flows Health and Button are flows of the solution, on the probe list that the
# T21 Make part creates (its title and 4 columns, scripts/gov/90161Z-T21-probe-r11.ps1 and its make module).
PROBE_DEFS = {"90161Z-T21-probe-health-r6.json", "90161Z-T21-probe-button-r6.json"}
PROBE_LIST, PROBE_COLS = "90161Z Probe", {"Title", "ProbeTest", "ProbeWay", "ProbeResult", "ProbeDetail"}

def check_flow_defs(zf, declared, declared_ids, all_cols, env_list, schemas, counts):
    """Check every flow def in flow/defs against the full solution zip: name, trigger and actions, expressions, connections, workflow file,
    list and column names. Fails are recorded with bad().

    Args:
        zf: the open full solution zip.
        declared: the connection reference logical names in its customizations.xml.
        declared_ids: the connector ids in its customizations.xml.
        all_cols: every column name of schemas/lists plus the built-in ones.
        env_list: list variable name -> list title.
        schemas: list title -> set of column names.
        counts: the dict of totals (defs, actions, columns, strings); this function adds to it.
    """
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
