#!/usr/bin/env python3
"""Build Power Automate import packages (.zip, "Import Package (Legacy)") from flow/defs/*.json.

Output: flow/packages/<name>.zip; def names are 90161Z-T<NN>-<slug>-r<N> (PFM 2026-11-11). Deterministic (IDs from uuid5 of the name, fixed zip timestamps, stored not deflated),
so --check can compare the committed zip with a fresh build. Never hand-edit the zip.
Connections: a def lists connector names in "connections" (e.g. ["shared_sharepointonline"]); the package then
matches the real export in tests/fixtures/real-export-sharepoint (connector + connection resources, maps,
connectionReferences). At import the PFM picks an existing connection (creationType "Existing").
Embeds: a def may map action names to repo files in "embed" (e.g. {"Payload": "flow/provisioning-payload.json"});
the build puts that file's JSON in the action's "inputs", so generated data has one source and --check sees changes.
Strings that start with "@", and "@{" anywhere, are escaped to "@@" so the flow engine reads them as text, not expressions.
"""
import argparse, io, json, pathlib, sys, uuid, zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFS, OUT = ROOT / "flow" / "defs", ROOT / "flow" / "packages"
NS = uuid.UUID("6f1c2b4e-9d0a-4c5e-8b7a-90161a000000")
SCHEMA = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
STAMP = (2026, 1, 1, 0, 0, 0)
# Values from the real export (tests/fixtures/real-export-sharepoint).
CONNECTORS = {
    "shared_sharepointonline": {
        "displayName": "SharePoint", "apiName": "sharepointonline",
        "iconUri": "https://gov.static.powerapps.us/resource/ppcr/releases/v1.0.1769/1.0.1769.4361/sharepointonline/icon.png",
    },
    # Not yet seen in a real export from the tenant (14 Nov 26): names from the public connector list, icon path by
    # the SharePoint pattern. The icon is display only; T11 probe r2 is the first package that uses them.
    "shared_office365users": {
        "displayName": "Office 365 Users", "apiName": "office365users",
        "iconUri": "https://gov.static.powerapps.us/resource/ppcr/releases/v1.0.1769/1.0.1769.4361/office365users/icon.png",
    },
    "shared_office365": {
        "displayName": "Office 365 Outlook", "apiName": "office365",
        "iconUri": "https://gov.static.powerapps.us/resource/ppcr/releases/v1.0.1769/1.0.1769.4361/office365/icon.png",
    },
}


def dumps(o):
    """Turn a value into JSON text (2-space indent, non-ASCII kept, final line end). Takes any JSON value; returns a string."""
    return json.dumps(o, indent=2, ensure_ascii=False) + "\n"


def literal(o):
    """Escape a JSON value so the flow engine treats every string as text ("@x" -> "@@x", "a @{b}" -> "a @@{b}")."""
    if isinstance(o, dict): return {k: literal(v) for k, v in o.items()}
    if isinstance(o, list): return [literal(v) for v in o]
    if isinstance(o, str):
        # Leading "@" = whole-string expression; "@{" anywhere = interpolation. Escape both.
        return "@" + o if o.startswith("@") else o.replace("@{", "@@{")
    return o


def read_flow_def(src: pathlib.Path):
    """Read one flow definition file and check it. Takes the file path; returns (definition dict, list of connector names).
    The "embed" entries are replaced by the named JSON files (as text values). A missing key or unknown connector raises ValueError."""
    d = json.loads(src.read_text(encoding="utf-8"))
    for act, rel in d.pop("embed", {}).items():
        if act not in d.get("actions", {}):
            raise ValueError(f"{src.name}: embed target '{act}' is not a top-level action")
        d["actions"][act]["inputs"] = literal(json.loads((ROOT / rel).read_text(encoding="utf-8")))
    for k in ("displayName", "triggers", "actions"):
        if k not in d:
            raise ValueError(f"{src.name}: missing '{k}'")
    conns = d.get("connections", [])
    for c in conns:
        if c not in CONNECTORS:
            raise ValueError(f"{src.name}: unknown connector {c}")
    return d, conns


def package_resources(name, d, conns, asset_id):
    """Build the manifest resources for one flow. Takes the flow name, its definition, its connectors and the asset ID.
    Returns (resources, apis_map, conns_map, conn_refs): the manifest "resources", the two map files and the flow's connection references."""
    resources = {asset_id: {
        "type": "Microsoft.Flow/flows",
        "suggestedCreationType": "New",
        "creationType": "Existing, New, Update",
        "details": {"displayName": d["displayName"]},
        "configurableBy": "User",
        "hierarchy": "Root",
        "dependsOn": [],
    }}
    apis_map, conns_map, conn_refs = {}, {}, {}
    for c in conns:
        info = CONNECTORS[c]
        api_res = str(uuid.uuid5(NS, f"api:{name}:{c}"))
        conn_res = str(uuid.uuid5(NS, f"conn:{name}:{c}"))
        resources[asset_id]["dependsOn"] += [api_res, conn_res]
        resources[api_res] = {
            "id": f"/providers/Microsoft.PowerApps/apis/{c}", "name": c, "type": "Microsoft.PowerApps/apis",
            "suggestedCreationType": "Existing",
            "details": {"displayName": info["displayName"], "iconUri": info["iconUri"]},
            "configurableBy": "System", "hierarchy": "Child", "dependsOn": [],
        }
        resources[conn_res] = {
            "type": "Microsoft.PowerApps/apis/connections", "suggestedCreationType": "Existing", "creationType": "Existing",
            "details": {"displayName": info["displayName"] + " connection", "iconUri": info["iconUri"]},
            "configurableBy": "User", "hierarchy": "Child", "dependsOn": [api_res],
        }
        apis_map[c], conns_map[c] = api_res, conn_res
        conn_refs[c] = {
            "connectionName": c.replace("_", "-")[:20] + "-" + str(uuid.uuid5(NS, f"connname:{name}:{c}")),
            "source": "Invoker", "id": f"/providers/Microsoft.PowerApps/apis/{c}", "tier": "NotSpecified",
            "apiName": info["apiName"], "isProcessSimpleApiReferenceConversionAlreadyDone": False,
        }
    return resources, apis_map, conns_map, conn_refs


def flow_definition_file(d, flow_id, conn_refs):
    """Build the content of definition.json. Takes the flow definition, the flow's own ID and its connection references; returns a dict."""
    return {
        "name": flow_id,
        "id": f"/providers/Microsoft.Flow/flows/{flow_id}",
        "type": "Microsoft.Flow/flows",
        "properties": {
            "apiId": "/providers/Microsoft.PowerApps/apis/shared_logicflows",
            "displayName": d["displayName"],
            "definition": {
                "$schema": SCHEMA,
                "contentVersion": "1.0.0.0",
                "parameters": {
                    "$connections": {"defaultValue": {}, "type": "Object"},
                    "$authentication": {"defaultValue": {}, "type": "SecureObject"},
                },
                "triggers": d["triggers"],
                "actions": d["actions"],
            },
            "connectionReferences": conn_refs,
            "flowFailureAlertSubscribed": False,
            "isManaged": False,
        },
    }


def zip_files(files):
    """Write the package files into a stored zip with fixed time stamps, so the bytes repeat. Takes {path: JSON value}; returns bytes."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        # Root manifest first, as in a real export.
        for path in sorted(files, key=lambda x: (x != "manifest.json", x)):
            info = zipfile.ZipInfo(path, STAMP)
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = 0o644 << 16
            z.writestr(info, dumps(files[path]))
    return buf.getvalue()


def build(src: pathlib.Path) -> bytes:
    """Build one importable flow package. Takes the path of a flow definition file; returns the zip as bytes."""
    d, conns = read_flow_def(src)
    name = src.stem
    # Matches a real export from the PFM's tenant (2026-11-11): the manifest resource key, the
    # assetPaths entry and the folder name are one ID (asset_id); definition.json "name" is a
    # different ID (the flow's own). A key/folder mismatch made the import hang.
    flow_id = str(uuid.uuid5(NS, "flow:" + name))
    asset_id = str(uuid.uuid5(NS, "asset:" + name))
    resources, apis_map, conns_map, conn_refs = package_resources(name, d, conns, asset_id)
    files = {
        "manifest.json": {
            "schema": "1.0",
            "details": {
                "displayName": d["displayName"],
                "description": d.get("description", ""),
                "createdTime": "2026-01-01T00:00:00.0000000Z",
                "packageTelemetryId": str(uuid.uuid5(NS, "telemetry:" + name)),
                "creator": "N/A",
                "sourceEnvironment": "",
            },
            "resources": resources,
        },
        "Microsoft.Flow/flows/manifest.json": {
            "packageSchemaVersion": "1.0",
            "flowAssets": {"assetPaths": [asset_id]},
        },
        f"Microsoft.Flow/flows/{asset_id}/definition.json": flow_definition_file(d, flow_id, conn_refs),
        f"Microsoft.Flow/flows/{asset_id}/apisMap.json": apis_map,
        f"Microsoft.Flow/flows/{asset_id}/connectionsMap.json": conns_map,
    }
    return zip_files(files)


def main():
    """Command line: build every flow package in flow/packages; with --check, list stale or orphan zips and exit 1 if any."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="fail if a committed package differs from a fresh build")
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    stale = 0
    for src in sorted(DEFS.glob("*.json")):
        data, dst = build(src), OUT / (src.stem + ".zip")
        if a.check:
            if not dst.exists() or dst.read_bytes() != data:
                print(f"STALE {dst.relative_to(ROOT)}"); stale += 1
        else:
            dst.write_bytes(data); print(f"BUILT {dst.relative_to(ROOT)} bytes={len(data)}")
    if a.check:
        names = {s.stem for s in DEFS.glob("*.json")}
        for z in sorted(OUT.glob("*.zip")):
            if z.stem not in names:
                print(f"STALE {z.relative_to(ROOT)} (no def)"); stale += 1
    sys.exit(1 if stale else 0)


if __name__ == "__main__":
    main()
