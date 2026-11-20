#!/usr/bin/env python3
"""Build the unmanaged Power Automate solution flow/solution/90161Z-T24-full-flows-r5.zip (R28 r1: all six flows, every flow On; R29 r2: list-name
variables not required; R34 r3: F04 r3 and the 2 T21 probe flows, fallback A of the PFM, 18 Nov 26; F01 r3 checks PFM
Publications every 15 minutes, PFM 19 Nov 26 F3 C, and F05 r4 adds the missing Legal rows at step 7 by any path, F1 A; R35 r4:
F05 r5 checks every minute, PFM 19 Nov 26; R36 r5: F03 r8, F04 r4, the new F07 r1 and F08 r1, and list GUID placeholders, below) from flow/solution/defs/*.json.
R35 (R34 finding 1): the build fails (exit 1, file, action path, length) when an action description is over 256 characters.
R36 (PFM 19 Nov 26, README choice 11: flows find lists by GUID): the default of each of the 9 list variables is a placeholder
that names the list title (list_placeholder); the T24 task script reads each list's GUID from the PFM's own site and writes it
over the placeholder before the import. The r4 zip and the slice r8 zip (R35) are no longer built: they stay as committed files
until R35 has run, and --check compares only the zips built here.

Layout (Microsoft's documented unmanaged solution): [Content_Types].xml, solution.xml, customizations.xml (Workflows,
connectionreferences), Workflows/<name>-<GUID>.json (properties.connectionReferences + properties.definition),
environmentvariabledefinitions/<schema>/environmentvariabledefinition.xml. Publisher prefix pfm, unique name PFM90161Z, version 1.0.0.1.
A def holds displayName, description, connections (connector names), triggers, actions; "@parameters('<display> (<schema>)')" reads a
solution environment variable (type Text), so no site address is in the repo. Deterministic (uuid5 IDs, fixed zip timestamps, stored),
so --check can compare the committed zip with a fresh build. Never hand-edit the zip. Not imported until the PFM reviews it.
TEST (R15, PFM 14 Nov 26: test a solution import before the flow build): the same builder also writes one test solution
flow/solution/<stem>.zip for each flow/solution/test-defs/<stem>.json: unique name PFM90161ZTEST + the def's "variant",
only the environment variables its flow uses; one harmless manual flow that reads one list count and writes one result file.
r2 (R16, PFM 14 Nov 26): r1 failed to import (XML node error). Values now follow the T05 real export of this environment
(docs/reviews/2026-11-12-gov-results-t01-t02-t05.md): platform version 9.2.26094.172, publisher unique name PFM, flow
StateCode 1 / StatusCode 2 / ModernFlowType 0, runtimeSource invoker for a manual flow. The connection reference and
environment variable XML are still not seen in a real export (T05 had neither).
r3 (R17, PFM 14 Nov 26: r2 failed with the same XML node error): environmentvariabledefinition.xml has no XML declaration
(agent finding, Confidence medium: the import inserts that file into a larger XML document, where a declaration node is the
wrong type; real exports start the file with the element). Two test solutions isolate the cause: A has no environment
variable (the site address is a run input), B has the environment variable without the declaration.
r4 (R18, PFM 14 Nov 26: in R17 A and B both passed the XML stage and both failed with "component {guid} of type 29 is not
declared in the solution file as a root component", so the variable is not the cause): the workflow GUID is lowercase in
customizations.xml (WorkflowId) and in solution.xml (RootComponent), as Dataverse exports write it and as the error prints
it; the JSON file name keeps the uppercase GUID, as exports do (agent finding, Confidence medium). Only test A goes to R18;
if it fails, the PFM exports a working solution in the same round so the next build copies the real layout.
r5 (R19, PFM 14 Nov 26: A r4 failed again; the PFM exported a working solution "90161ZExportSample" in R18, masked copy in
flow/solution/export-sample/): every value the export shows is copied, not guessed. No XML declaration in solution.xml or
customizations.xml; their ImportExportXml attributes as exported (platform 9.2.26101.188, CRMServerServiceabilityVersion);
publisher PFM with the environment's option value prefix 89127 (r4 had a random 47423 for the same publisher), nil e-mail and
web site and two empty addresses; NO connection reference RootComponent (the export lists only the flow; type 10018 is an
environment-specific type code: agent finding, Confidence medium that it caused "not declared as a root component");
IntroducedVersion 1.0.0.0; no empty "outputs" in the definition; a manual (invoker) flow authenticates with the run token
(Raw), as exported; the JSON file name is the display name without spaces or punctuation plus the uppercase GUID;
[Content_Types].xml on one line with a byte order mark; CRLF line ends and no final line end, as exported.
tests/check_flow_solution.py compares each zip with the sample.
Strings that start with "@" are expressions on purpose here (build_flow_package.literal() is for static data only).
R26 (16 Nov 26, task T21 probe): a test def may hold "solution": {"variant", "title", "zip"}; all test defs with the same
variant build into ONE test solution (unique name PFM90161ZTEST + variant) with the given title and zip name. A test def
without "solution" builds as before (T17). A flow whose trigger is kind "Button" runs on the invoker's connection; every
other flow, the Power Apps (V2) trigger kind "PowerAppV2" included, runs on the owner's embedded connections and
authenticates with @parameters('$authentication').
R34 (PFM 18 Nov 26, fallback A: a new solution and a new hand-made flow fail with "The connections could not be loaded", an
upgrade of this solution works): the T21 probe flows Health and Button are defs of the flow solution (defs/90161Z-T21-*.json),
on the one SharePoint connection reference the six flows use, so the upgrade needs no new connection. The Button flow's
workflow ID (uuid5, the same on every build) goes into the T21 look script between the button-flow-id markers, so the
list view button names the flow with no export; --check fails when that block is stale.
Network: none.
Writes: the solution zips in flow/solution and the button-flow-id block of the T21 look script.
Credentials: none.
"""
import argparse, io, json, pathlib, re, sys, uuid, zipfile
from xml.sax.saxutils import escape, quoteattr

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFS, OUT = ROOT / "flow" / "solution" / "defs", ROOT / "flow" / "solution" / "90161Z-T24-full-flows-r5.zip"
# R34: the probe button flow (its workflow ID goes into the T21 look script, which names it in the list view button).
BUTTON_DEF = DEFS / "90161Z-T21-probe-button-r6.json"
LOOK_SCRIPT = ROOT / "scripts" / "gov" / "90161Z-T21-look-r11.ps1"
ID_BEGIN = "# >>> button-flow-id: generated from flow/solution/defs/90161Z-T21-probe-button-r6.json by scripts/build_flow_solution.py (do not edit)"
ID_END = "# <<< button-flow-id"
TEST_DEFS = ROOT / "flow" / "solution" / "test-defs"
NS = uuid.UUID("6f1c2b4e-9d0a-4c5e-8b7a-90161a000001")
SCHEMA = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
STAMP = (2026, 1, 1, 0, 0, 0)
UNIQUE, PUBLISHER, PREFIX, VERSION = "PFM90161Z", "PFM", "pfm", "1.0.0.1"   # publisher PFM as in the T05 export
PLATFORM, SERVICEABILITY = "9.2.26101.188", "9.2.26101.00188"   # the R18 export (r5); T05 had 9.2.26094.172
OPTION_PREFIX = 89127   # the publisher PFM in this environment (R18 export, r5); a new environment creates PFM with it
CONNECTORS = {"shared_sharepointonline": "SharePoint", "shared_office365": "Office 365 Outlook",
              "shared_onedriveforbusiness": "OneDrive for Business", "shared_office365users": "Office 365 Users",
              "shared_office365groups": "Office 365 Groups", "shared_wordonlinebusiness": "Word Online (Business)",
              "shared_sendmail": "Mail", "shared_flowmanagement": "Power Automate Management"}   # the last six: the T21 probe flows (R26, 16 Nov 26; R27: Management)
# Environment variables (type Text, 100000000). The 9 list variables hold a list GUID (R36); their default in the zip is a placeholder
# with the list title from schemas/lists, which the T24 task script replaces on the work computer. The site URL and alert e-mail stay empty.
# Order and labels (PFM 15 Nov 26: "sort the fields when importing a solution so the ones i need to modify are sequential and on
# top"): the values a wing must set come first here (the RootComponent order in solution.xml) and their import-page labels (LABEL)
# start with a number, so they are together and first whether the page keeps the file order or sorts by name (agent finding,
# Confidence medium: the page's sort rule is not documented; the next import shows it). A flow parameter key (ENV_KEY) keeps the
# plain name: flows bind a variable by its schema name.
LIST_TITLES = {   # list variable -> the list title in schemas/lists (the placeholder names it; T24 reads that list's GUID)
    "pfm_ListPublications": "PFM Publications", "pfm_ListActivityLog": "PFM Activity Log", "pfm_ListReviews": "PFM Reviews",
    "pfm_ListEndorsements": "PFM Endorsements", "pfm_ListProductIndex": "PFM Product Index", "pfm_ListProcessSteps": "PFM Process Steps",
    "pfm_ListOffices": "PFM Offices",
    "pfm_ListWaivers": "PFM Waivers",   # R36: F08 r1 (rule 4.4A, design approved by the PFM 19 Nov 26) watches this list
    "pfm_ListSettings": "PFM Settings",   # R27: the flows read their six values from rows of this list
}
# R36: the placeholder text. The T24 task script (scripts/gov/90161Z-T24-full-solution-test-r7.ps1, $ListGuidMark) finds it by this
# mark and fails when one is left after its write; tests/check_flow_solution.py checks that both use the same mark.
LIST_GUID_MARK = "90161Z-LIST-GUID"


def list_placeholder(title):
    """The default value of a list variable in the zip. Takes the list title; returns '90161Z-LIST-GUID[<title>]'."""
    return f"{LIST_GUID_MARK}[{title}]"


ENV = [  # (schema name, display name, default value)
    ("pfm_SiteUrl", "Site URL", ""),
    ("pfm_AlertEmail", "Alert e-mail", ""),   # failure e-mails and test-mode e-mails go here (PFM, 2026-11-14)
] + [(s, "List " + t, list_placeholder(t)) for s, t in LIST_TITLES.items()]
# R27 (PFM 14 Nov 26, "Flow values move"): Flows paused, Test mode, reminder lead days, escalation lag days, suspense working days and
# the shared mailbox are rows of PFM Settings (schemas/lists/PFMSettings.json), no longer environment variables here.
# F03, F05 and F06 read them once at the start of a run. tests/check_flow_solution.py fails if a def still reads one.
MOVED_ENV = ("pfm_FlowsPaused", "pfm_TestMode", "pfm_ReminderLeadDays", "pfm_EscalationLagDays", "pfm_SuspenseWorkdays", "pfm_SharedMailbox")
LABEL = {"pfm_SiteUrl": "1 Site URL (enter)", "pfm_AlertEmail": "2 Alert e-mail (enter)"}
OPTIONAL = set()   # isrequired 0 for an optional value (none since R27: the shared mailbox is a PFM Settings row)
# R29 (R28 note N7: "I had to cut and paste almost every default field to get it to unblock import"): in the full solution a
# variable with a default value (the list variables, 9 from R36) is not required, so the import page does not wait for it to be typed again;
# the flows use the default. Agent finding, Confidence low: the cause is not seen in an import log; the round asks which boxes
# still needed it. The slice and the test solutions keep isrequired 1 (they are built files of earlier rounds).
ENV_KEY = {s: f"{d} ({s})" for s, d, _ in ENV}
# R22 (PFM 14 Nov 26: "flows added by the solution default to on; i had to turn f03 off"; "ideally the flows will be imported
# on when this is ready for real deployment"): a test-round slice (SLICE1) imports every flow Off (StateCode 0 / StatusCode 1, the
# Dataverse values for a turned-off flow) except the flows the round needs On (SLICE1_ON; PFM 15 Nov 26: "if it's all or none
# import then on if it's more than 2 that need to be on. otherwise separately toggled": the state is per flow in
# customizations.xml, so each flow gets its own); the full deployment solution (OUT) and the test solutions import On (1 / 2).
OFF_STATE = "      <StateCode>0</StateCode>\n      <StatusCode>1</StatusCode>\n"
# Slice 1 (PFM, 2026-11-14; task T18, R20 to R35): F03, F05 and F06 with the same unique name as the full solution, last built as
# 90161Z-T18-slice1-flows-r8.zip (R35). R36: no longer built (the full solution r5 replaces it, and a slice would carry the list
# placeholders that only T24 replaces); build(only, on) keeps the slice form for a later test round.


XSI = 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
ORG = f'OrganizationVersion="{PLATFORM}" OrganizationSchemaType="Standard" CRMServerServiceabilityVersion="{SERVICEABILITY}"'
# The publisher's two empty addresses list these elements, as in the R18 export (r5): ADDR_FIELDS, the shipping method code, then ADDR_TAIL.
ADDR_FIELDS = ["City", "County", "Country", "Fax", "FreightTermsCode", "ImportSequenceNumber", "Latitude", "Line1", "Line2",
               "Line3", "Longitude", "Name", "PostalCode", "PostOfficeBox", "PrimaryContactName"]
ADDR_TAIL = ["StateOrProvince", "Telephone1", "Telephone2", "Telephone3", "TimeZoneRuleVersionNumber", "UPSZone", "UTCOffset",
             "UTCConversionTimeZoneCode"]


def dumps(o):
    """Turn a value into JSON text (2-space indent, non-ASCII kept, final line end). Takes any JSON value; returns a string."""
    return json.dumps(o, indent=2, ensure_ascii=False) + "\n"


def conn_logical(c):
    """Name a connection reference. Takes a connector name such as shared_office365; returns its logical name (stable, from the name)."""
    return f"{PREFIX}_{c.replace('_', '')}_{uuid.uuid5(NS, 'connref:' + c).hex[:6]}"


def guid(kind, name):
    """Make a stable upper-case GUID. Takes a kind word and a name; the same pair always gives the same GUID."""
    return str(uuid.uuid5(NS, f"{kind}:{name}")).upper()


def flow_guid(stem, test=False):
    """A solution flow keeps its ID across revisions (slice r2, 14 Nov 26), so a later import upgrades it instead of adding a copy."""
    return guid("workflow", stem if test else re.sub(r"-r\d+$", "", stem))


def load(defs=DEFS):
    """Read and check every flow definition in a folder. Takes the folder (default: the flow defs); returns a sorted list of
    (path, definition, sorted environment keys the flow uses). A missing key, unknown connector or unknown variable raises ValueError."""
    out = []
    for src in sorted(defs.glob("*.json")):
        d = json.loads(src.read_text(encoding="utf-8"))
        for k in ("displayName", "triggers", "actions", "connections"):
            if k not in d:
                raise ValueError(f"{src.name}: missing '{k}'")
        for c in d["connections"]:
            if c not in CONNECTORS:
                raise ValueError(f"{src.name}: unknown connector {c}")
        text = src.read_text(encoding="utf-8")
        used = {m for m in re.findall(r"parameters\('([^']+)'\)", text) if not m.startswith("$")}
        bad = used - set(ENV_KEY.values())
        if bad:
            raise ValueError(f"{src.name}: unknown environment variable reference {sorted(bad)}")
        out.append((src, d, sorted(used)))
    return out


# R35 (R34 finding 1): Power Automate refuses to save a flow whose action description is over 256 characters
# ("ActionDescriptionTooLong"); a flow-level description may be longer (F01 r3 with 734 imported). The build fails first.
MAX_ACTION_DESCRIPTION = 256


def long_action_descriptions(actions, path="/actions"):
    """Find the action descriptions that Power Automate would refuse.

    Args:
        actions: the "actions" object of a flow definition (action name -> action), at any depth.
        path: the JSON path of that object, used in the result (default "/actions").

    Returns:
        A list of (action path, length) for each action whose "description" is over MAX_ACTION_DESCRIPTION characters,
        searched in nested "actions" and "else"/"actions" blocks and in Switch "cases" and "default" blocks.
    """
    out = []
    for name, act in (actions or {}).items():
        if not isinstance(act, dict):
            continue
        here = f"{path}/{name}"
        if len(act.get("description") or "") > MAX_ACTION_DESCRIPTION:
            out.append((here, len(act["description"])))
        out += long_action_descriptions(act.get("actions"), here + "/actions")
        out += long_action_descriptions((act.get("else") or {}).get("actions"), here + "/else/actions")
        out += long_action_descriptions((act.get("default") or {}).get("actions"), here + "/default/actions")
        for case, block in (act.get("cases") or {}).items():
            out += long_action_descriptions((block or {}).get("actions"), f"{here}/cases/{case}/actions")
    return out


def check_action_descriptions(folders=(DEFS, TEST_DEFS)):
    """Exit 1 with a plain message when any def in the folders has an action description over the limit. Takes the folders."""
    found = [(src, p, n) for folder in folders for src in sorted(folder.glob("*.json"))
             for p, n in long_action_descriptions(json.loads(src.read_text(encoding="utf-8")).get("actions"))]
    for src, p, n in found:
        print(f"FAIL {src.relative_to(ROOT)}: action {p} has a description of {n} characters; "
              f"Power Automate allows {MAX_ACTION_DESCRIPTION} (shorten it)")
    if found:
        sys.exit(1)


def workflow_json(d, used):
    """Build the workflow JSON file of one flow. Takes the flow definition and its used environment keys; returns a dict."""
    params = {"$connections": {"defaultValue": {}, "type": "Object"}, "$authentication": {"defaultValue": {}, "type": "SecureObject"}}
    for s, disp, default in ENV:
        if ENV_KEY[s] in used:
            params[ENV_KEY[s]] = {"defaultValue": default, "type": "String", "metadata": {"schemaName": s}}
    # T05: a manual flow runs on the invoker's connection; automated and scheduled flows use the owner's (embedded).
    # R26: the Power Apps (V2) trigger (kind PowerAppV2) is not "Button": it uses the owner's connections, as automated flows do.
    src = "invoker" if any(t.get("kind") == "Button" for t in d["triggers"].values()) else "embedded"
    refs = {c: {"runtimeSource": src, "connection": {"connectionReferenceLogicalName": conn_logical(c)},
                "api": {"name": c}} for c in d["connections"]}
    return {"properties": {
        "connectionReferences": refs,
        "definition": {"$schema": SCHEMA, "contentVersion": "1.0.0.0", "parameters": params,
                       "triggers": d["triggers"], "actions": run_token(d["actions"]) if src == "invoker" else d["actions"]},
        "templateName": None}, "schemaVersion": "1.0.0.0"}


RUN_TOKEN = {"value": "@json(decodeBase64(triggerOutputs().headers['X-MS-APIM-Tokens']))['$ConnectionKey']", "type": "Raw"}


def run_token(o):
    """A manual flow in the R18 export authenticates each action with the run token, not @parameters('$authentication')."""
    if isinstance(o, dict):
        return {k: (dict(RUN_TOKEN) if k == "authentication" and v == "@parameters('$authentication')" else run_token(v)) for k, v in o.items()}
    if isinstance(o, list):
        return [run_token(v) for v in o]
    return o


def json_name(display, wid):
    """As exported: the display name with only letters and digits, a hyphen, the uppercase GUID."""
    return f"/Workflows/{re.sub(r'[^A-Za-z0-9]', '', display)}-{wid}.json"


def exported_text(path, text):
    """As in the R18 export (r5): CRLF line ends and no final line end in solution.xml, customizations.xml and the workflow JSON."""
    if path in ("solution.xml", "customizations.xml") or path.startswith("Workflows/"):
        return text.rstrip("\n").replace("\n", "\r\n")
    return text


def test_variant(d):
    """Return the variant letter of a test def (its "solution" block, else its own "variant"). Takes the definition; returns a string."""
    return d.get("solution", {}).get("variant") or d["variant"]


def test_jobs():
    """One (defs, zip path, title) per test solution: defs with a "solution" block are grouped by variant; the others stand alone."""
    jobs, groups = [], {}
    for f in load(TEST_DEFS):
        sol = f[1].get("solution")
        if sol:
            groups.setdefault(sol["variant"], []).append(f)
        else:
            jobs.append(([f[0]], TEST_DEFS.parent / (f[0].stem + ".zip")))
    for v, fl in sorted(groups.items()):
        if len({(f[1]["solution"]["title"], f[1]["solution"]["zip"]) for f in fl}) != 1:
            raise ValueError(f"variant {v}: the defs name different titles or zips")
        jobs.append(([f[0] for f in fl], TEST_DEFS.parent / fl[0][1]["solution"]["zip"]))
    return jobs


def select_flows(test, only):
    """Pick the flow definitions for one solution. Takes test (None, or a list of test def paths) and only (name prefixes or None).
    Returns (flows, unique name, title), where flows is a list of (path, definition, used environment keys)."""
    flows = load(DEFS) if test is None else [f for f in load(TEST_DEFS) if f[0] in test]
    if only:
        flows = [f for f in flows if f[0].name.startswith(only)]
    if test is None:
        unique, title = UNIQUE, "90-161.Z flows"
    else:
        v = test_variant(flows[0][1])
        unique, title = UNIQUE + "TEST" + v, flows[0][1].get("solution", {}).get("title") or "90-161.Z solution import test " + v
    return flows, unique, title


def workflow_entries(flows, test, only, on, files, root_components):
    """Add each flow to the solution. Takes the flows, test, only and on (as in build), the files dict (gets one JSON file per flow)
    and the root_components list (gets one line per flow). Returns the list of <Workflow> XML blocks for customizations.xml."""
    wf_xml = []
    for src, d, used in flows:
        # R21: "workflowKey" names the stem whose ID the flow kept when it was first imported (R20 imported F03 r2 and F05 r1,
        # with the revision in the ID), so this import replaces those flows in place; F05 r1 is on and would double the rows.
        wid = guid("workflow", d["workflowKey"]) if d.get("workflowKey") and test is None else flow_guid(src.stem, test is not None)
        fname = json_name(d["displayName"], wid)
        # Flow solutions carry the flow JSON without indents (slice r2, 14 Nov 26: keeps the R20 round under the 300 KB paste limit;
        # JSON whitespace has no meaning). The test solutions keep the indented form that R19 imported.
        files[fname[1:]] = dumps(workflow_json(d, used)) if test is not None else json.dumps(workflow_json(d, used), separators=(",", ":"), ensure_ascii=False)
        wf_xml.append(
            f"    <Workflow WorkflowId=\"{{{wid.lower()}}}\" Name={quoteattr(d['displayName'])}>\n"
            f"      <JsonFileName>{fname}</JsonFileName>\n"
            "      <Type>1</Type>\n      <Subprocess>0</Subprocess>\n      <Category>5</Category>\n      <Mode>0</Mode>\n"
            "      <Scope>4</Scope>\n      <OnDemand>0</OnDemand>\n      <TriggerOnCreate>0</TriggerOnCreate>\n"
            "      <TriggerOnDelete>0</TriggerOnDelete>\n      <AsyncAutodelete>0</AsyncAutodelete>\n"
            "      <SyncWorkflowLogOnFailure>0</SyncWorkflowLogOnFailure>\n"
            + ("      <StateCode>1</StateCode>\n      <StatusCode>2</StatusCode>\n" if test is not None or not only or src.name.startswith(on) else OFF_STATE)
            + "      <RunAs>1</RunAs>"
            "\n      <IsTransacted>1</IsTransacted>\n      <IntroducedVersion>1.0.0.0</IntroducedVersion>\n"
            "      <IsCustomizable>1</IsCustomizable>\n      <BusinessProcessType>0</BusinessProcessType>\n"
            "      <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>\n"
            "      <ModernFlowType>0</ModernFlowType>\n      <PrimaryEntity>none</PrimaryEntity>\n"
            f"      <LocalizedNames>\n        <LocalizedName languagecode=\"1033\" description={quoteattr(d['displayName'])} />\n      </LocalizedNames>\n"
            "    </Workflow>")
        root_components.append(f'      <RootComponent type="29" id="{{{wid.lower()}}}" behavior="0" />')   # lowercase (r4)
    return wf_xml


def connection_reference_xml(flows):
    """Build the <connectionreference> XML blocks. Takes the flows; returns one block per connector the flows use (sorted)."""
    used_conns = sorted({c for _, d, _ in flows for c in d["connections"]})
    cr_xml = []
    for c in used_conns:
        cr_xml.append(
            f"    <connectionreference connectionreferencelogicalname=\"{conn_logical(c)}\">\n"
            f"      <connectionreferencedisplayname>{escape(CONNECTORS[c])}</connectionreferencedisplayname>\n"
            f"      <connectorid>/providers/Microsoft.PowerApps/apis/{c}</connectorid>\n"
            "      <iscustomizable>1</iscustomizable>\n      <promptingbehavior>0</promptingbehavior>\n"
            "      <statecode>0</statecode>\n      <statuscode>1</statuscode>\n    </connectionreference>")
    return cr_xml


def env_definition_files(env, full, files, root_components):
    """Add one environment variable definition file and one root component per variable. Takes env (list of
    (schema name, display name, default)), full (True for the full flow solution) and the files and root_components to fill."""
    for s, disp, default in env:
        disp = LABEL.get(s, disp)
        files[f"environmentvariabledefinitions/{s}/environmentvariabledefinition.xml"] = (
            f'<environmentvariabledefinition schemaname="{s}">\n'
            + (f"  <defaultvalue>{escape(default)}</defaultvalue>\n" if default else "") +   # no empty element; no XML declaration (r3)
            f'  <displayname default={quoteattr(disp)}>\n    <label description={quoteattr(disp)} languagecode="1033" />\n  </displayname>\n'
            "  <introducedversion>1.0</introducedversion>\n  <iscustomizable>1</iscustomizable>\n"
            f"  <isrequired>{0 if s in OPTIONAL or (full and default) else 1}</isrequired>\n"
            "  <secretstore>0</secretstore>\n  <type>100000000</type>\n</environmentvariabledefinition>\n")
        root_components.append(f'      <RootComponent type="380" schemaName="{s}" behavior="0" />')


def customizations_xml(wf_xml, cr_xml):
    """Build customizations.xml. Takes the <Workflow> blocks and the <connectionreference> blocks; returns the text."""
    return (   # no XML declaration (r5, as exported)
        f"<ImportExportXml {XSI} {ORG}>\n  <Entities></Entities>\n  <Roles></Roles>\n  <Workflows>\n" + "\n".join(wf_xml) + "\n  </Workflows>\n"
        "  <FieldSecurityProfiles></FieldSecurityProfiles>\n  <Templates />\n  <EntityMaps />\n  <EntityRelationships />\n"
        "  <OrganizationSettings />\n  <optionsets />\n  <CustomControls />\n  <EntityDataProviders />\n"
        "  <connectionreferences>\n" + "\n".join(cr_xml) + "\n  </connectionreferences>\n  <Languages>\n    <Language>1033</Language>\n  </Languages>\n"
        "</ImportExportXml>\n")


def nil(tag):
    """Write an empty XML element marked nil. Takes the opening tag without its closing bracket, such as '<City'; returns text that
    the caller finishes with '>'."""
    return f'{tag} xsi:nil="true"></{tag[1:]}'


def address(n):
    """Build one empty <Address> block of the publisher. Takes the address number (1 or 2); returns text."""
    return ("        <Address>\n" f"          <AddressNumber>{n}</AddressNumber>\n          <AddressTypeCode>1</AddressTypeCode>\n"
            + "".join(f"          {nil('<' + t)}>\n" for t in ADDR_FIELDS) + "          <ShippingMethodCode>1</ShippingMethodCode>\n"
            + "".join(f"          {nil('<' + t)}>\n" for t in ADDR_TAIL) + "        </Address>\n")


def solution_xml(unique, title, root_components):
    """Build solution.xml. Takes the solution's unique name, its title and the RootComponent lines; returns the text."""
    return (   # no XML declaration; attributes in the exported order (r5)
        f'<ImportExportXml version="{PLATFORM}" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="CrmLive" {XSI} OrganizationVersion="{PLATFORM}" OrganizationSchemaType="Standard" CRMServerServiceabilityVersion="{SERVICEABILITY}">\n'
        f"  <SolutionManifest>\n    <UniqueName>{unique}</UniqueName>\n"
        f'    <LocalizedNames>\n      <LocalizedName description="{title}" languagecode="1033" />\n    </LocalizedNames>\n'
        "    <Descriptions />\n"
        f"    <Version>{VERSION}</Version>\n    <Managed>0</Managed>\n    <Publisher>\n      <UniqueName>{PUBLISHER}</UniqueName>\n"
        '      <LocalizedNames>\n        <LocalizedName description="90-161.Z" languagecode="1033" />\n      </LocalizedNames>\n'
        "      <Descriptions />\n"
        f"      {nil('<EMailAddress')}>\n      {nil('<SupportingWebsiteUrl')}>\n"
        f"      <CustomizationPrefix>{PREFIX}</CustomizationPrefix>\n      <CustomizationOptionValuePrefix>{OPTION_PREFIX}</CustomizationOptionValuePrefix>\n"
        "      <Addresses>\n" + address(1) + address(2) + "      </Addresses>\n"
        "    </Publisher>\n    <RootComponents>\n" + "\n".join(root_components) + "\n    </RootComponents>\n    <MissingDependencies />\n"
        "  </SolutionManifest>\n</ImportExportXml>\n")


def zip_solution(files, test):
    """Write the solution files into a zip with fixed time stamps, so the bytes repeat. Takes {path: text} and test
    (None for the flow solution and slice, which are deflated; a list for a test solution, which is stored). Returns bytes."""
    buf = io.BytesIO()
    # R21: the flow solution and slice are deflated, as Dataverse exports are (round bundle under 300 KB); test solutions stay stored as R19 imported.
    method = zipfile.ZIP_STORED if test is not None else zipfile.ZIP_DEFLATED
    with zipfile.ZipFile(buf, "w", method) as z:
        for path in sorted(files, key=lambda x: (x != "[Content_Types].xml", x)):
            info = zipfile.ZipInfo(path, STAMP)
            info.compress_type = method
            info.create_system = 3
            info.external_attr = 0o644 << 16
            z.writestr(info, exported_text(path, files[path]))
    return buf.getvalue()


def build(test=None, only=None, on=()) -> bytes:
    """test: None for the flow solution, else a list of test def paths (one test solution). only: def name prefixes (a slice).
    on: in a slice, the def name prefixes that import On; the slice's other flows import Off. Returns the solution zip as bytes."""
    flows, unique, title = select_flows(test, only)
    full = test is None and not only
    used_env = {k for _, _, u in flows for k in u}
    env = [e for e in ENV if ENV_KEY[e[0]] in used_env]   # every solution carries only the variables its flows use (R27)
    files, root_components = {}, []
    wf_xml = workflow_entries(flows, test, only, on, files, root_components)
    cr_xml = connection_reference_xml(flows)
    env_definition_files(env, full, files, root_components)
    files["customizations.xml"] = customizations_xml(wf_xml, cr_xml)
    files["solution.xml"] = solution_xml(unique, title, root_components)
    files["[Content_Types].xml"] = (   # one line with a byte order mark, as exported (r5)
        '\ufeff<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="xml" ContentType="application/octet-stream" /><Default Extension="json" ContentType="application/octet-stream" /></Types>')
    return zip_solution(files, test)


def button_flow_id():
    """The probe button flow's workflow ID (lower case, as the flow URL and the view button use it). Takes nothing; returns text."""
    return flow_guid(BUTTON_DEF.stem).lower()


def sync_button_id(check):
    """Write the button flow's ID into the T21 look script between the button-flow-id markers, or only compare it.

    Args:
        check: True to compare only (write nothing).

    Returns:
        True when the block was up to date (or is now written), False when it is stale or its markers are missing.
    """
    text = LOOK_SCRIPT.read_text(encoding="utf-8")
    m = re.search(re.escape(ID_BEGIN) + r"\n(.*?)" + re.escape(ID_END), text, re.S)
    want = f"$ButtonFlowId = '{button_flow_id()}'\n"
    if m is None:
        return False
    if m.group(1) == want:
        return True
    if not check:
        LOOK_SCRIPT.write_text(text[:m.start(1)] + want + text[m.end(1):], encoding="utf-8")
    return not check


def main():
    """Command line: build every solution zip; with --check, compare each with the committed zip and exit 1 on the first difference."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit 1 if the committed zip differs from a fresh build")
    a = ap.parse_args()
    check_action_descriptions()   # R35: before any zip is written or compared
    jobs = [(None, OUT, None, ())] + [(defs, out, None, ()) for defs, out in test_jobs()]
    for test, out, only, on in jobs:
        data = build(test, only, on)
        if a.check:
            if not out.exists() or out.read_bytes() != data:
                print(f"STALE {out.relative_to(ROOT)}"); sys.exit(1)
            print(f"OK {out.relative_to(ROOT)} up to date"); continue
        out.write_bytes(data)
        print(f"BUILT {out.relative_to(ROOT)} bytes={len(data)}")
    ok = sync_button_id(a.check)
    print(f"{'OK' if ok else 'STALE'} {LOOK_SCRIPT.relative_to(ROOT)} button-flow-id block")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
