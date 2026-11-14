#!/usr/bin/env python3
"""Build the DRAFT unmanaged Power Automate solution flow/solution/90161Z-flows-solution-r1.zip from flow/solution/defs/*.json.

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
"""
import argparse, io, json, pathlib, re, sys, uuid, zipfile
from xml.sax.saxutils import escape, quoteattr

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFS, OUT = ROOT / "flow" / "solution" / "defs", ROOT / "flow" / "solution" / "90161Z-flows-solution-r1.zip"
TEST_DEFS = ROOT / "flow" / "solution" / "test-defs"
NS = uuid.UUID("6f1c2b4e-9d0a-4c5e-8b7a-90161a000001")
SCHEMA = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
STAMP = (2026, 1, 1, 0, 0, 0)
UNIQUE, PUBLISHER, PREFIX, VERSION = "PFM90161Z", "PFM", "pfm", "1.0.0.1"   # publisher PFM as in the T05 export
PLATFORM, SERVICEABILITY = "9.2.26101.188", "9.2.26101.00188"   # the R18 export (r5); T05 had 9.2.26094.172
OPTION_PREFIX = 89127   # the publisher PFM in this environment (R18 export, r5); a new environment creates PFM with it
CONNECTORS = {"shared_sharepointonline": "SharePoint", "shared_office365": "Office 365 Outlook"}
# Environment variables (type Text, 100000000). Defaults are list titles from schemas/lists; the site URL and the two day counts stay empty.
ENV = [  # (schema name, display name, default value)
    ("pfm_SiteUrl", "Site URL", ""),
    ("pfm_ListPublications", "List PFM Publications", "PFM Publications"),
    ("pfm_ListActivityLog", "List PFM Activity Log", "PFM Activity Log"),
    ("pfm_ListReviews", "List PFM Reviews", "PFM Reviews"),
    ("pfm_ListEndorsements", "List PFM Endorsements", "PFM Endorsements"),
    ("pfm_ListProductIndex", "List PFM Product Index", "PFM Product Index"),
    ("pfm_ListProcessSteps", "List PFM Process Steps", "PFM Process Steps"),
    ("pfm_ListOffices", "List PFM Offices", "PFM Offices"),
    ("pfm_ReminderLeadDays", "Reminder lead days", "5"),   # weekdays before the suspense (PFM, 2026-11-14)
    ("pfm_EscalationLagDays", "Escalation lag days", "3"),   # working days after the suspense (PFM, 2026-11-14)
    ("pfm_SharedMailbox", "Shared mailbox", ""),   # optional: F03 sends from it (Send As); empty = the flow owner's mailbox
    ("pfm_PfmEmail", "PFM e-mail", ""),   # R21: failure e-mails and test-mode e-mails go here; set at import
    ("pfm_TestMode", "Test mode", "Yes"),   # R21 (PFM D6, 14 Nov 26): Yes = every flow e-mail goes to the PFM only; set No to go live
    ("pfm_FlowsOff", "Flows off", "No"),   # R21 (QOL kill switch, 14 Nov 26): Yes = every flow stops at its first step
]
OPTIONAL = {"pfm_SharedMailbox"}   # isrequired 0: a wing without a shared mailbox leaves it empty
ENV_KEY = {s: f"{d} ({s})" for s, d, _ in ENV}
# Slice 1 (PFM, 2026-11-14: Publications + Endorsements + F05 routing + F03 reminders first): the solution R20 imports, as
# task T18. Same unique name as the full solution, so a later full import upgrades it.
# R21: r2 adds F06 (hold and resume), the test-mode, kill-switch and PFM e-mail variables.
SLICE1 = (ROOT / "flow" / "solution" / "90161Z-T18-slice1-flows-r2.zip", ("90161Z-F03-", "90161Z-F05-", "90161Z-F06-"))


def dumps(o):
    return json.dumps(o, indent=2, ensure_ascii=False) + "\n"


def conn_logical(c):
    return f"{PREFIX}_{c.replace('_', '')}_{uuid.uuid5(NS, 'connref:' + c).hex[:6]}"


def guid(kind, name):
    return str(uuid.uuid5(NS, f"{kind}:{name}")).upper()


def load(defs=DEFS):
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


def workflow_json(d, used):
    params = {"$connections": {"defaultValue": {}, "type": "Object"}, "$authentication": {"defaultValue": {}, "type": "SecureObject"}}
    for s, disp, default in ENV:
        if ENV_KEY[s] in used:
            params[ENV_KEY[s]] = {"defaultValue": default, "type": "String", "metadata": {"schemaName": s}}
    # T05: a manual flow runs on the invoker's connection; automated and scheduled flows use the owner's (embedded).
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


def build(test=None, only=None) -> bytes:
    """test: None for the flow solution, else one test def path (its own solution). only: def name prefixes (a slice)."""
    flows = load(DEFS) if test is None else [f for f in load(TEST_DEFS) if f[0] == test]
    if only:
        flows = [f for f in flows if f[0].name.startswith(only)]
    if test is None:
        unique, title = UNIQUE, "90-161.Z flows"
    else:
        v = flows[0][1]["variant"]
        unique, title = UNIQUE + "TEST" + v, "90-161.Z solution import test " + v
    used_env = {k for _, _, u in flows for k in u}
    env = ENV if test is None and not only else [e for e in ENV if ENV_KEY[e[0]] in used_env]   # a test or slice carries only what it uses
    files, wf_xml, root_components = {}, [], []
    for src, d, used in flows:
        # R21: a def may name the revision whose workflow ID it keeps ("workflowKey"), so an import replaces that flow in
        # place instead of adding a second copy next to it (R20 imported F03 r2 and F05 r1; F05 r1 is on).
        wid = guid("workflow", d.get("workflowKey", src.stem))
        fname = json_name(d["displayName"], wid)
        # R21: the flow solution and slice write each workflow JSON on one line, as Power Automate exports do (the R21 round
        # bundle stays under 300 KB); test solutions keep the indented form that R19 imported.
        files[fname[1:]] = dumps(workflow_json(d, used)) if test is not None else json.dumps(workflow_json(d, used), ensure_ascii=False, separators=(",", ":"))
        wf_xml.append(
            f"    <Workflow WorkflowId=\"{{{wid.lower()}}}\" Name={quoteattr(d['displayName'])}>\n"
            f"      <JsonFileName>{fname}</JsonFileName>\n"
            "      <Type>1</Type>\n      <Subprocess>0</Subprocess>\n      <Category>5</Category>\n      <Mode>0</Mode>\n"
            "      <Scope>4</Scope>\n      <OnDemand>0</OnDemand>\n      <TriggerOnCreate>0</TriggerOnCreate>\n"
            "      <TriggerOnDelete>0</TriggerOnDelete>\n      <AsyncAutodelete>0</AsyncAutodelete>\n"
            "      <SyncWorkflowLogOnFailure>0</SyncWorkflowLogOnFailure>\n      <StateCode>1</StateCode>\n      <StatusCode>2</StatusCode>\n"
            "      <RunAs>1</RunAs>\n      <IsTransacted>1</IsTransacted>\n      <IntroducedVersion>1.0.0.0</IntroducedVersion>\n"
            "      <IsCustomizable>1</IsCustomizable>\n      <BusinessProcessType>0</BusinessProcessType>\n"
            "      <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>\n"
            "      <ModernFlowType>0</ModernFlowType>\n      <PrimaryEntity>none</PrimaryEntity>\n"
            f"      <LocalizedNames>\n        <LocalizedName languagecode=\"1033\" description={quoteattr(d['displayName'])} />\n      </LocalizedNames>\n"
            "    </Workflow>")
        root_components.append(f'      <RootComponent type="29" id="{{{wid.lower()}}}" behavior="0" />')   # lowercase (r4)
    used_conns = sorted({c for _, d, _ in flows for c in d["connections"]})
    cr_xml = []
    for c in used_conns:
        cr_xml.append(
            f"    <connectionreference connectionreferencelogicalname=\"{conn_logical(c)}\">\n"
            f"      <connectionreferencedisplayname>{escape(CONNECTORS[c])}</connectionreferencedisplayname>\n"
            f"      <connectorid>/providers/Microsoft.PowerApps/apis/{c}</connectorid>\n"
            "      <iscustomizable>1</iscustomizable>\n      <promptingbehavior>0</promptingbehavior>\n"
            "      <statecode>0</statecode>\n      <statuscode>1</statuscode>\n    </connectionreference>")
    for s, disp, default in env:
        files[f"environmentvariabledefinitions/{s}/environmentvariabledefinition.xml"] = (
            f'<environmentvariabledefinition schemaname="{s}">\n'
            + (f"  <defaultvalue>{escape(default)}</defaultvalue>\n" if default else "") +   # no empty element; no XML declaration (r3)
            f'  <displayname default={quoteattr(disp)}>\n    <label description={quoteattr(disp)} languagecode="1033" />\n  </displayname>\n'
            "  <introducedversion>1.0</introducedversion>\n  <iscustomizable>1</iscustomizable>\n"
            f"  <isrequired>{0 if s in OPTIONAL else 1}</isrequired>\n"
            "  <secretstore>0</secretstore>\n  <type>100000000</type>\n</environmentvariabledefinition>\n")
        root_components.append(f'      <RootComponent type="380" schemaName="{s}" behavior="0" />')
    XSI = 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
    ORG = f'OrganizationVersion="{PLATFORM}" OrganizationSchemaType="Standard" CRMServerServiceabilityVersion="{SERVICEABILITY}"'
    files["customizations.xml"] = (   # no XML declaration (r5, as exported)
        f"<ImportExportXml {XSI} {ORG}>\n  <Entities></Entities>\n  <Roles></Roles>\n  <Workflows>\n" + "\n".join(wf_xml) + "\n  </Workflows>\n"
        "  <FieldSecurityProfiles></FieldSecurityProfiles>\n  <Templates />\n  <EntityMaps />\n  <EntityRelationships />\n"
        "  <OrganizationSettings />\n  <optionsets />\n  <CustomControls />\n  <EntityDataProviders />\n"
        "  <connectionreferences>\n" + "\n".join(cr_xml) + "\n  </connectionreferences>\n  <Languages>\n    <Language>1033</Language>\n  </Languages>\n"
        "</ImportExportXml>\n")
    nil = lambda tag: f'{tag} xsi:nil="true"></{tag[1:]}'   # noqa: E731
    addr_fields = ["City", "County", "Country", "Fax", "FreightTermsCode", "ImportSequenceNumber", "Latitude", "Line1", "Line2",
                   "Line3", "Longitude", "Name", "PostalCode", "PostOfficeBox", "PrimaryContactName"]
    addr_tail = ["StateOrProvince", "Telephone1", "Telephone2", "Telephone3", "TimeZoneRuleVersionNumber", "UPSZone", "UTCOffset",
                 "UTCConversionTimeZoneCode"]
    def address(n):
        return ("        <Address>\n" f"          <AddressNumber>{n}</AddressNumber>\n          <AddressTypeCode>1</AddressTypeCode>\n"
                + "".join(f"          {nil('<' + t)}>\n" for t in addr_fields) + "          <ShippingMethodCode>1</ShippingMethodCode>\n"
                + "".join(f"          {nil('<' + t)}>\n" for t in addr_tail) + "        </Address>\n")
    files["solution.xml"] = (   # no XML declaration; attributes in the exported order (r5)
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
    files["[Content_Types].xml"] = (   # one line with a byte order mark, as exported (r5)
        '\ufeff<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="xml" ContentType="application/octet-stream" /><Default Extension="json" ContentType="application/octet-stream" /></Types>')
    buf = io.BytesIO()
    # R21: the flow solution and slice are deflated, as Dataverse exports are (bundle size); test solutions stay stored as R19 imported.
    method = zipfile.ZIP_STORED if test is not None else zipfile.ZIP_DEFLATED
    with zipfile.ZipFile(buf, "w", method) as z:
        for path in sorted(files, key=lambda x: (x != "[Content_Types].xml", x)):
            info = zipfile.ZipInfo(path, STAMP)
            info.compress_type = method
            info.create_system = 3
            info.external_attr = 0o644 << 16
            z.writestr(info, exported_text(path, files[path]))
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit 1 if the committed zip differs from a fresh build")
    a = ap.parse_args()
    jobs = [(None, OUT, None), (None, SLICE1[0], SLICE1[1])] + [(d, d.parent.parent / (d.stem + ".zip"), None) for d in sorted(TEST_DEFS.glob("*.json"))]
    for test, out, only in jobs:
        data = build(test, only)
        if a.check:
            if not out.exists() or out.read_bytes() != data:
                print(f"STALE {out.relative_to(ROOT)}"); sys.exit(1)
            print(f"OK {out.relative_to(ROOT)} up to date"); continue
        out.write_bytes(data)
        print(f"BUILT {out.relative_to(ROOT)} bytes={len(data)}")


if __name__ == "__main__":
    main()
