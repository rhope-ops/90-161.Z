#!/usr/bin/env python3
"""Build the DRAFT unmanaged Power Automate solution flow/solution/90161Z-flows-solution-r1.zip from flow/solution/defs/*.json.

Layout (Microsoft's documented unmanaged solution): [Content_Types].xml, solution.xml, customizations.xml (Workflows,
connectionreferences), Workflows/<name>-<GUID>.json (properties.connectionReferences + properties.definition),
environmentvariabledefinitions/<schema>/environmentvariabledefinition.xml. Publisher prefix pfm, unique name PFM90161Z, version 1.0.0.1.
A def holds displayName, description, connections (connector names), triggers, actions; "@parameters('<display> (<schema>)')" reads a
solution environment variable (type Text), so no site address is in the repo. Deterministic (uuid5 IDs, fixed zip timestamps, stored),
so --check can compare the committed zip with a fresh build. Never hand-edit the zip. Not imported until the PFM reviews it.
TEST (R15, PFM 14 Nov 26: test a solution import before the flow build): the same builder also writes
flow/solution/90161Z-T17-solution-test-r2.zip from flow/solution/test-defs/*.json: unique name PFM90161ZTEST, only the
environment variables its flows use; one harmless manual flow that reads one list count and writes one result file.
r2 (R16, PFM 14 Nov 26): r1 failed to import (XML node error). Values now follow the T05 real export of this environment
(docs/reviews/2026-11-12-gov-results-t01-t02-t05.md): platform version 9.2.26094.172, publisher unique name PFM, flow
StateCode 1 / StatusCode 2 / ModernFlowType 0, runtimeSource invoker for a manual flow. The connection reference and
environment variable XML are still not seen in a real export (T05 had neither).
Strings that start with "@" are expressions on purpose here (build_flow_package.literal() is for static data only).
"""
import argparse, io, json, pathlib, re, sys, uuid, zipfile
from xml.sax.saxutils import escape, quoteattr

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFS, OUT = ROOT / "flow" / "solution" / "defs", ROOT / "flow" / "solution" / "90161Z-flows-solution-r1.zip"
TEST_DEFS, TEST_OUT = ROOT / "flow" / "solution" / "test-defs", ROOT / "flow" / "solution" / "90161Z-T17-solution-test-r2.zip"
NS = uuid.UUID("6f1c2b4e-9d0a-4c5e-8b7a-90161a000001")
SCHEMA = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
STAMP = (2026, 1, 1, 0, 0, 0)
UNIQUE, PUBLISHER, PREFIX, VERSION = "PFM90161Z", "PFM", "pfm", "1.0.0.1"   # publisher PFM as in the T05 export
PLATFORM = "9.2.26094.172"   # OrganizationVersion of the T05 export
OPTION_PREFIX = 10000 + uuid.uuid5(NS, "optionprefix").int % 90000  # arbitrary, unique per publisher; see README open choices
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
    ("pfm_ReminderLeadDays", "Reminder lead days", ""),
    ("pfm_EscalationLagDays", "Escalation lag days", ""),
]
ENV_KEY = {s: f"{d} ({s})" for s, d, _ in ENV}


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
                       "triggers": d["triggers"], "actions": d["actions"], "outputs": {}},
        "templateName": None}, "schemaVersion": "1.0.0.0"}


def build(test=False) -> bytes:
    flows = load(TEST_DEFS if test else DEFS)
    unique, title = (UNIQUE + "TEST", "90-161.Z solution import test") if test else (UNIQUE, "90-161.Z flows")
    used_env = {k for _, _, u in flows for k in u}
    env = [e for e in ENV if ENV_KEY[e[0]] in used_env] if test else ENV   # the test solution carries only what it uses
    files, wf_xml, root_components = {}, [], []
    for src, d, used in flows:
        wid = guid("workflow", src.stem)
        fname = f"/Workflows/{src.stem}-{wid}.json"
        files[fname[1:]] = dumps(workflow_json(d, used))
        wf_xml.append(
            f"    <Workflow WorkflowId=\"{{{wid}}}\" Name={quoteattr(d['displayName'])}>\n"
            f"      <JsonFileName>{fname}</JsonFileName>\n"
            "      <Type>1</Type>\n      <Subprocess>0</Subprocess>\n      <Category>5</Category>\n      <Mode>0</Mode>\n"
            "      <Scope>4</Scope>\n      <OnDemand>0</OnDemand>\n      <TriggerOnCreate>0</TriggerOnCreate>\n"
            "      <TriggerOnDelete>0</TriggerOnDelete>\n      <AsyncAutodelete>0</AsyncAutodelete>\n"
            "      <SyncWorkflowLogOnFailure>0</SyncWorkflowLogOnFailure>\n      <StateCode>1</StateCode>\n      <StatusCode>2</StatusCode>\n"
            "      <RunAs>1</RunAs>\n      <IsTransacted>1</IsTransacted>\n      <IntroducedVersion>1.0</IntroducedVersion>\n"
            "      <IsCustomizable>1</IsCustomizable>\n      <BusinessProcessType>0</BusinessProcessType>\n"
            "      <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>\n"
            "      <ModernFlowType>0</ModernFlowType>\n      <PrimaryEntity>none</PrimaryEntity>\n"
            f"      <LocalizedNames>\n        <LocalizedName languagecode=\"1033\" description={quoteattr(d['displayName'])} />\n      </LocalizedNames>\n"
            "    </Workflow>")
        root_components.append(f'      <RootComponent type="29" id="{{{wid}}}" behavior="0" />')
    used_conns = sorted({c for _, d, _ in flows for c in d["connections"]})
    cr_xml = []
    for c in used_conns:
        cr_xml.append(
            f"    <connectionreference connectionreferencelogicalname=\"{conn_logical(c)}\">\n"
            f"      <connectionreferencedisplayname>{escape(CONNECTORS[c])}</connectionreferencedisplayname>\n"
            f"      <connectorid>/providers/Microsoft.PowerApps/apis/{c}</connectorid>\n"
            "      <iscustomizable>1</iscustomizable>\n      <promptingbehavior>0</promptingbehavior>\n"
            "      <statecode>0</statecode>\n      <statuscode>1</statuscode>\n    </connectionreference>")
        root_components.append(f'      <RootComponent type="10018" schemaName="{conn_logical(c)}" behavior="0" />')
    for s, disp, default in env:
        files[f"environmentvariabledefinitions/{s}/environmentvariabledefinition.xml"] = (
            '<?xml version="1.0" encoding="utf-8"?>\n'
            f'<environmentvariabledefinition schemaname="{s}">\n'
            + (f"  <defaultvalue>{escape(default)}</defaultvalue>\n" if default else "") +   # no empty element
            
            f'  <displayname default={quoteattr(disp)}>\n    <label description={quoteattr(disp)} languagecode="1033" />\n  </displayname>\n'
            "  <introducedversion>1.0</introducedversion>\n  <iscustomizable>1</iscustomizable>\n  <isrequired>1</isrequired>\n"
            "  <secretstore>0</secretstore>\n  <type>100000000</type>\n</environmentvariabledefinition>\n")
        root_components.append(f'      <RootComponent type="380" schemaName="{s}" behavior="0" />')
    XSI = 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
    files["customizations.xml"] = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        f"<ImportExportXml {XSI}>\n  <Entities></Entities>\n  <Roles></Roles>\n  <Workflows>\n" + "\n".join(wf_xml) + "\n  </Workflows>\n"
        "  <FieldSecurityProfiles></FieldSecurityProfiles>\n  <Templates />\n  <EntityMaps />\n  <EntityRelationships />\n"
        "  <OrganizationSettings />\n  <optionsets />\n  <CustomControls />\n  <EntityDataProviders />\n"
        "  <connectionreferences>\n" + "\n".join(cr_xml) + "\n  </connectionreferences>\n  <Languages>\n    <Language>1033</Language>\n  </Languages>\n"
        "</ImportExportXml>\n")
    files["solution.xml"] = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        f'<ImportExportXml version="{PLATFORM}" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="CrmLive" OrganizationVersion="{PLATFORM}" OrganizationSchemaType="Standard" {XSI}>\n'
        f"  <SolutionManifest>\n    <UniqueName>{unique}</UniqueName>\n"
        f'    <LocalizedNames>\n      <LocalizedName description="{title}" languagecode="1033" />\n    </LocalizedNames>\n'
        "    <Descriptions />\n"
        f"    <Version>{VERSION}</Version>\n    <Managed>0</Managed>\n    <Publisher>\n      <UniqueName>{PUBLISHER}</UniqueName>\n"
        '      <LocalizedNames>\n        <LocalizedName description="90-161.Z" languagecode="1033" />\n      </LocalizedNames>\n'
        "      <Descriptions />\n"
        f"      <CustomizationPrefix>{PREFIX}</CustomizationPrefix>\n      <CustomizationOptionValuePrefix>{OPTION_PREFIX}</CustomizationOptionValuePrefix>\n"
        "    </Publisher>\n    <RootComponents>\n" + "\n".join(root_components) + "\n    </RootComponents>\n    <MissingDependencies />\n"
        "  </SolutionManifest>\n</ImportExportXml>\n")
    files["[Content_Types].xml"] = (
        '<?xml version="1.0" encoding="utf-8"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="xml" ContentType="application/octet-stream" />\n'
        '  <Default Extension="json" ContentType="application/octet-stream" />\n</Types>\n')
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        for path in sorted(files, key=lambda x: (x != "[Content_Types].xml", x)):
            info = zipfile.ZipInfo(path, STAMP)
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = 0o644 << 16
            z.writestr(info, files[path])
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit 1 if the committed zip differs from a fresh build")
    a = ap.parse_args()
    for test, out in ((False, OUT), (True, TEST_OUT)):
        data = build(test)
        if a.check:
            if not out.exists() or out.read_bytes() != data:
                print(f"STALE {out.relative_to(ROOT)}"); sys.exit(1)
            print(f"OK {out.relative_to(ROOT)} up to date"); continue
        out.write_bytes(data)
        print(f"BUILT {out.relative_to(ROOT)} bytes={len(data)}")


if __name__ == "__main__":
    main()
