#!/usr/bin/env python3
"""Generate flow/defs/90161Z-T11-rights-probe-r<N>.json from the CHECKS list below (PFM 2026-11-12: test every
assumption about rights before relying on it). Then run scripts/build_flow_package.py to make the zip.

The flow runs as the person who starts it (the PFM: site collection admin). It records, for each check, the HTTP
status and a short, name-free part of the answer. Read checks come first, then write checks on TEST objects it
creates, then cleanup of those objects. Every step runs even if the step before failed.
Coworker checks (R11, R12) answer "what can a regular member do" without a second login: SharePoint's
getusereffectivepermissions for the address the PFM types. Decoding the permission masks happens in the cloud,
from the result file (docs/rights-test-plan.md "Reading the result").
R13 (ensureuser) adds the group to the site's hidden user list; that entry stays and is harmless.
r2 (PFM 2026-11-14, automate Part B): MAIL_CHECKS add Office 365 Users and Outlook checks that replace manual rows
M11-M15: my licenses, a test mail to me from my mailbox, reading the office mailbox, and two test mails to me from the
office mailbox (shared-mailbox action; From field). The PFM approved these test mails (to the PFM only).
r3 (PFM 2026-11-14): the Outlook COM check stopped at the Outlook address prompt, so the flow now does that part: E05
waits 2 minutes, then reads the test mails in my mailbox (Graph, subject, from, sender) and records for E01, E03 and
E04 whether each arrived and how (from-me, sent-as-office, on-behalf-of-office, other) by comparing the from and sender
addresses to ME and OFFICE in lower case. Addresses are never written. Error text has the two addresses replaced.
r4 (R15, PFM 14 Nov 26): the mail checks are answered (r3) and left out, so r4 needs only the SharePoint connection
and asks only the site and a coworker. New: G01-G05 count who is in the Members and Visitors groups by principal type
(no names; the PFM: Members holds an AD security group without e-mail) and list the coworker's SharePoint group IDs;
W11 gives the coworker's first group Contribute on the TEST list (item-level "own items" from W03), and R12b reads the
coworker's rights there: the app-write model (DECISIONS 14 Nov 26) needs Add/Edit/Delete own items for Read-only users.
r5 (R16, PFM 14 Nov 26): R15 found no SharePoint group for the coworker (the site is group-connected; Members and
Visitors list 0 users), so W11 granted nobody. C01 resolves the coworker (ensureuser) and keeps the site user ID; G04
lists that user's groups by ID; G06 counts each site group's members by type (users, security groups; no names);
W11 gives Contribute on the TEST list to the coworker's own user ID, and R12b reads the coworker's rights there.
Kept error and answer text has the typed site address, its host and its path replaced (R13 kept a request address).
Results: the run's Result step, and a file 90161Z-T11-rights-result-r<N>.json in the site's default library.
The result holds no names: only status codes, permission masks, principal types, role names and license names."""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REV = 5
NAME = f"90161Z-T11-rights-probe-r{REV}"
RESULT_FILE = f"90161Z-T11-rights-result-r{REV}.json"
TEST_LIST, TEST_LIB, TEST_GROUP = "PFMRightsProbeTEST", "PFMRightsProbeLib", "PFM Rights Probe TEST"
COWORKER = "encodeUriComponent(concat('i:0#.f|membership|', triggerBody()?['text_1']))"
J = "application/json;odata=verbose"
NM = "application/json;odata=nometadata"  # answers without __metadata, so no site URL lands in the result

# (id, what it answers, method, uri, body or None, extra headers or None, keep expression or None)
CHECKS = [
    ("R01", "Am I a site collection admin", "GET", "_api/web/currentuser?$select=IsSiteAdmin", None, None, None),
    ("R02", "My permission mask on the site", "GET", "_api/web/effectiveBasePermissions", None, None, None),
    ("R03", "Site is group-connected (M365 group) or a hub", "GET", "_api/site?$select=GroupId,IsHubSite,ReadOnly", None, None, None),
    ("R04", "Site template, unique permissions", "GET", "_api/web?$select=WebTemplate,Configuration,HasUniqueRoleAssignments", None, None, None),
    ("R05", "Who has access: principal types and roles (no names)", "GET",
     "_api/web/roleassignments?$expand=Member,RoleDefinitionBindings&$select=Member/PrincipalType,RoleDefinitionBindings/Name", None, None, None),
    ("R06", "Permission levels and what each allows", "GET", "_api/web/roledefinitions?$select=Name,Hidden,BasePermissions", None, None, None),
    ("R07", "Site Members group settings", "GET", "_api/web/associatedmembergroup?$select=Id,AllowMembersEditMembership,OnlyAllowMembersViewMembership", None, None, None),
    ("R07b", "Permission level of the Members group", "GET",
     "_api/web/roleassignments/getbyprincipalid(@{body('R07')?['Id']})/roledefinitionbindings?$select=Name", None, None, None),
    ("R08", "Site time zone", "GET", "_api/web/RegionalSettings/TimeZone?$select=Description,Id", None, None, None),
    ("R09a", "PFM Publications: item-level permissions, versioning", "GET",
     "_api/web/lists/getbytitle('PFM Publications')?$select=ReadSecurity,WriteSecurity,EnableVersioning,MajorVersionLimit,ItemCount,HasUniqueRoleAssignments", None, None, None),
    ("R09b", "PFM Endorsements: item-level permissions, versioning", "GET",
     "_api/web/lists/getbytitle('PFM Endorsements')?$select=ReadSecurity,WriteSecurity,EnableVersioning,MajorVersionLimit,ItemCount,HasUniqueRoleAssignments", None, None, None),
    ("R09c", "PFM Activity Log: permissions, versioning", "GET",
     "_api/web/lists/getbytitle('PFM Activity Log')?$select=ReadSecurity,WriteSecurity,EnableVersioning,MajorVersionLimit,ItemCount,HasUniqueRoleAssignments", None, None, None),
    ("R09d", "PFM Settings: permissions", "GET",
     "_api/web/lists/getbytitle('PFM Settings')?$select=HasUniqueRoleAssignments,ItemCount", None, None, None),
    ("R10", "My permission mask on PFM Publications", "GET", "_api/web/lists/getbytitle('PFM Publications')/effectiveBasePermissions", None, None, None),
    ("R11", "Coworker (regular member) permission mask on the site", "GET",
     "_api/web/getusereffectivepermissions(@u)?@u='@{" + COWORKER + "}'", None, None, None),
    ("R12", "Coworker permission mask on PFM Publications", "GET",
     "_api/web/lists/getbytitle('PFM Publications')/getusereffectivepermissions(@u)?@u='@{" + COWORKER + "}'", None, None, None),
    ("R13", "Wing group resolves; its principal type (1 user, 4 security group, 8 SharePoint group)", "POST", "_api/web/ensureuser",
     {"logonName": "@{triggerBody()?['text_2']}"}, None, "@{body('R13')?['PrincipalType']}"),
    ("R14", "Site Owners group has a Full Control role", "GET",
     "_api/web/associatedownergroup?$select=Id,AllowMembersEditMembership", None, None, None),
    ("C01", "Coworker resolves on the site: principal type and site user ID (no name)", "POST", "_api/web/ensureuser",
     {"logonName": "@{trim(coalesce(triggerBody()?['text_1'], ''))}"}, None,
     "type=@{body('C01')?['PrincipalType']} id=@{body('C01')?['Id']}"),
    ("G01", "Members group: principal types of its members (1 user, 4 security group, counts only)", "GET",
     "_api/web/associatedmembergroup/users?$select=PrincipalType", None, None,
     "@{string(length(coalesce(body('G01')?['value'], json('[]'))))} members; types=@{join(coalesce(body('G01_types'), json('[]')), ',')}"),
    ("G02", "Visitors group ID", "GET", "_api/web/associatedvisitorgroup?$select=Id", None, None, None),
    ("G03", "Visitors group: principal types of its members (counts only)", "GET",
     "_api/web/associatedvisitorgroup/users?$select=PrincipalType", None, None,
     "@{string(length(coalesce(body('G03')?['value'], json('[]'))))} members; types=@{join(coalesce(body('G03_types'), json('[]')), ',')}"),
    ("G04", "Coworker's SharePoint group IDs, by the C01 user ID (compare with Owners R14, Members R07, Visitors G02)", "GET",
     "_api/web/getuserbyid(@{body('C01')?['Id']})/groups?$select=Id", None, None,
     "@{join(coalesce(body('G04_ids'), json('[]')), ',')}"),
    ("G05", "Site role assignments by principal ID (match with G04 and G06)", "GET",
     "_api/web/roleassignments?$expand=RoleDefinitionBindings&$select=PrincipalId,RoleDefinitionBindings/Name", None, None, None),
    ("G06", "Each site group: member counts by type (id:users/security groups; no names)", "GET",
     "_api/web/sitegroups?$expand=Users&$select=Id,Users/PrincipalType&$top=200", None, None,
     "@{join(coalesce(body('G06_counts'), json('[]')), ',')}"),
    # r2 capability inventory (PFM 2026-11-14: document more for future projects). Read-only; names of people never kept.
    ("R15", "Site features turned on (IDs only)", "GET", "_api/web/features?$select=DefinitionId", None, None, None),
    ("R16", "Site collection features turned on (IDs only)", "GET", "_api/site/features?$select=DefinitionId", None, None, None),
    ("R17", "List templates offered", "GET", "_api/web/listtemplates?$select=Name,ListTemplateTypeKind,Hidden&$filter=Hidden%20eq%20false", None, None, None),
    ("R18", "Site templates offered for subsites", "GET",
     "_api/web/getavailablewebtemplates(lcid=1033,doincludecrosslanguage=false)?$select=Name", None, None, None),
    ("R19", "Search works (one result, count only)", "GET",
     "_api/search/query?querytext='*'&rowlimit=1&selectproperties='Path'", None, None, "@{body('R19')?['PrimaryQueryResult']?['RelevantResults']?['TotalRows']}"),
    ("R20", "Storage used and quota", "GET", "_api/site/usage", None, None, None),
    ("R21", "Tenant app catalog exists (for SPFx web parts)", "GET", "_api/SP_TenantSettings_Current", None, None,
     "@{if(empty(body('R21')?['CorporateCatalogUrl']), 'no app catalog', 'app catalog exists')}"),
    ("R22", "Term store readable (managed metadata)", "GET", "_api/v2.1/termStore?$select=defaultLanguageTag", None, None,
     "@{body('R22')?['defaultLanguageTag']}"),   # keep: an OData v4 reply can carry the site URL in @odata.context
    ("R23", "Content types on the site (count)", "GET", "_api/web/contenttypes?$select=Name&$top=500", None, None,
     "@{length(coalesce(body('R23')?['value'], json('[]')))}"),
    ("R24", "Site pages library and modern pages allowed", "GET",
     "_api/web/lists/getbytitle('Site Pages')?$select=ItemCount,EnableVersioning,EnableModeration", None, None, None),
    ("R25", "Site sensitivity label and sharing", "GET", "_api/site?$select=SensitivityLabelId,ShareByEmailEnabled,ShareByLinkEnabled", None, None, None),
    ("R26", "Power Apps / Power Automate integration on a list (form and flow buttons)", "GET",
     "_api/web/lists/getbytitle('PFM Publications')?$select=DisableGridEditing,EnableAttachments,DefaultDisplayFormUrl", None, None,
     "@{if(empty(body('R26')?['DefaultDisplayFormUrl']), 'no form', 'form set')}"),
    ("W01", "Create a list", "POST", "_api/web/lists",
     {"__metadata": {"type": "SP.List"}, "BaseTemplate": 100, "Title": TEST_LIST}, None, "@{body('W01')?['Id']}"),
    ("W02", "Add a column", "POST", f"_api/web/lists/getbytitle('{TEST_LIST}')/fields",
     {"__metadata": {"type": "SP.Field"}, "FieldTypeKind": 2, "Title": "ProbeText"}, None, "@{body('W02')?['InternalName']}"),
    ("W03", "Set item-level permissions and a version limit", "POST", f"_api/web/lists/getbytitle('{TEST_LIST}')",
     {"__metadata": {"type": "SP.List"}, "ReadSecurity": 2, "WriteSecurity": 2, "EnableVersioning": True, "MajorVersionLimit": 50},
     {"X-HTTP-Method": "MERGE", "IF-MATCH": "*"}, None),
    ("W04", "Give the list its own permissions", "POST",
     f"_api/web/lists/getbytitle('{TEST_LIST}')/breakroleinheritance(copyRoleAssignments=true,clearSubscopes=true)", None, None, None),
    ("W05", "Set Members to Read on that list", "POST",
     f"_api/web/lists/getbytitle('{TEST_LIST}')/roleassignments/addroleassignment(principalid=@{{body('R07')?['Id']}},roledefid=1073741826)", None, None, None),
    ("W06", "Add an item", "POST", f"_api/web/lists/getbytitle('{TEST_LIST}')/items",
     {"__metadata": {"type": "SP.Data.PFMRightsProbeTESTListItem"}, "Title": "probe"}, None, "@{body('W06')?['Id']}"),
    ("W07", "Create a SharePoint group", "POST", "_api/web/sitegroups",
     {"__metadata": {"type": "SP.Group"}, "Title": TEST_GROUP}, None, "@{body('W07')?['Id']}"),
    ("W08", "Create a document library", "POST", "_api/web/lists",
     {"__metadata": {"type": "SP.List"}, "BaseTemplate": 101, "Title": TEST_LIB}, None, "@{body('W08')?['Id']}"),
    ("W09", "Create a folder", "POST", f"_api/web/lists/getbytitle('{TEST_LIB}')/rootfolder/folders/add(url='ProbeFolder')", None, None, None),
    ("W10", "Give the folder its own permissions (per-action Working Files)", "POST",
     f"_api/web/lists/getbytitle('{TEST_LIB}')/rootfolder/folders/getbyurl('ProbeFolder')/ListItemAllFields/breakroleinheritance(copyRoleAssignments=false,clearSubscopes=true)", None, None, None),
    ("W11", "Give the coworker's own user (C01 ID) Contribute on the TEST list", "POST",
     f"_api/web/lists/getbytitle('{TEST_LIST}')/roleassignments/addroleassignment(principalid=@{{body('C01')?['Id']}},roledefid=1073741827)", None, None,
     "granted to user id @{body('C01')?['Id']}"),
    ("R12b", "Coworker's permission mask on the TEST list after W11 (Add, Edit, Delete own items?)", "GET",
     f"_api/web/lists/getbytitle('{TEST_LIST}')/getusereffectivepermissions(@u)?@u='@{{" + COWORKER + "}'", None, None, None),
    ("X01", "Cleanup: delete the test list", "POST", f"_api/web/lists/getbytitle('{TEST_LIST}')", None,
     {"X-HTTP-Method": "DELETE", "IF-MATCH": "*"}, None),
    ("X02", "Cleanup: delete the test library", "POST", f"_api/web/lists/getbytitle('{TEST_LIB}')", None,
     {"X-HTTP-Method": "DELETE", "IF-MATCH": "*"}, None),
    ("X03", "Cleanup: delete the test group", "POST", "_api/web/sitegroups/removebyid(@{body('W07')?['Id']})", None, None, None),
]
ME = "@{body('U01')?['mail']}"
OFFICE = "@{triggerBody()?['text_3']}"
TEST_BODY = "<p>90-161.Z rights probe test mail (Task 11). Delete it after the round reads it.</p>"
# E05: Select turns each test mail into "E0n:how"; the keep expression reads arrived and how from that list. No address is kept.
_FROM = "toLower(coalesce(item()?['from']?['emailAddress']?['address'], '<none>'))"
_SENDER = "toLower(coalesce(item()?['sender']?['emailAddress']?['address'], '<none>'))"
_ME = "toLower(coalesce(body('U01')?['mail'], '<me>'))"
_OFF = "toLower(coalesce(triggerBody()?['text_3'], '<office>'))"
E05_HOW = ("concat(substring(item()?['subject'], add(indexOf(item()?['subject'], 'TEST E0'), 5), 3), ':', "
           f"if(and(equals({_FROM}, {_ME}), equals({_SENDER}, {_ME})), 'from-me', "
           f"if(and(equals({_FROM}, {_OFF}), equals({_SENDER}, {_OFF})), 'sent-as-office', "
           f"if(and(equals({_FROM}, {_OFF}), equals({_SENDER}, {_ME})), 'on-behalf-of-office', 'other'))))")
_J = "join(coalesce(body('E05_how'), json('[]')), ',')"


def _e05(tag):
    how = (f"if(contains({_J}, '{tag}:from-me'), 'from-me', if(contains({_J}, '{tag}:sent-as-office'), 'sent-as-office', "
           f"if(contains({_J}, '{tag}:on-behalf-of-office'), 'on-behalf-of-office', 'other')))")
    return f"concat('{tag} arrived=', contains({_J}, '{tag}:'), ' how=', if(contains({_J}, '{tag}:'), {how}, 'none'))"


E05_KEEP = "concat(" + ", '; ', ".join(_e05(t) for t in ("E01", "E03", "E04")) + ")"
# (id, what it answers, connector, operationId, parameters, keep expression): run after the SharePoint checks.
MAIL_CHECKS = [
    ("U01", "Office 365 Users: read my own profile (D1)", "shared_office365users", "MyProfile_V2", {},
     "@{if(empty(body('U01')?['mail']), 'no mail address', 'mail address found')}"),
    ("U02", "My license names (P16, was M11)", "shared_office365users", "HttpRequest",
     {"Uri": "/v1.0/me/licenseDetails?$select=skuPartNumber", "Method": "GET"}, "@{join(coalesce(body('U02_names'), json('[]')), ', ')}"),
    ("E01", "Send a mail from my mailbox to me (E1, was M12)", "shared_office365", "SendEmailV2",
     {"emailMessage/To": ME, "emailMessage/Subject": "90161Z TEST E01 my mailbox", "emailMessage/Body": TEST_BODY,
      "emailMessage/Importance": "Normal"}, "-"),
    ("E02", "Read the office mailbox inbox (E2, E5)", "shared_office365", "HttpRequest",
     {"Uri": "/v1.0/users/" + OFFICE + "/mailFolders/inbox/messages?$top=1&$select=receivedDateTime", "Method": "GET"}, "-"),
    ("E03", "Send from the office mailbox, shared-mailbox action (E3, was M14)", "shared_office365", "SharedMailboxSendEmailV2",
     {"emailMessage/MailboxAddress": OFFICE, "emailMessage/To": ME, "emailMessage/Subject": "90161Z TEST E03 shared mailbox action",
      "emailMessage/Body": TEST_BODY, "emailMessage/Importance": "Normal"}, "-"),
    ("E04", "Send with From = the office mailbox (E4, was M15)", "shared_office365", "SendEmailV2",
     {"emailMessage/To": ME, "emailMessage/From": OFFICE, "emailMessage/Subject": "90161Z TEST E04 from field",
      "emailMessage/Body": TEST_BODY, "emailMessage/Importance": "Normal"}, "-"),
    ("E05", "After 2 minutes: did E01, E03, E04 arrive, and how (from-me, sent-as-office, on-behalf-of-office, other)", "shared_office365", "HttpRequest",
     {"Uri": "/v1.0/me/messages?$filter=receivedDateTime%20ge%20@{trigger()?['startTime']}%20and%20startswith(subject,%2790161Z%20TEST%20E0%27)&$orderby=receivedDateTime%20desc&$select=subject,from,sender&$top=20", "Method": "GET"},
     "@{" + E05_KEEP + "}"),
]
# Error text can quote the addresses: replace both before the text is kept.
# if(empty()): replace() refuses an empty old value, and an optional field left empty can be '' or null.
# toLower first: an error can spell an address in other capitals than the one typed.
HIDE = ("replace(replace(toLower({x}), if(empty(triggerBody()?['text_3']), '<none>', toLower(triggerBody()?['text_3'])), '<OFFICE>'), "
        "if(empty(body('U01')?['mail']), '<none>', toLower(body('U01')?['mail'])), '<ME>')")
# Only the license names leave U02: the Graph reply also carries the user's object ID.
EXTRA = {"G01": ("G01_types", {"type": "Select", "inputs": {"from": "@coalesce(body('G01')?['value'], json('[]'))", "select": "@string(item()?['PrincipalType'])"}}),
         "G03": ("G03_types", {"type": "Select", "inputs": {"from": "@coalesce(body('G03')?['value'], json('[]'))", "select": "@string(item()?['PrincipalType'])"}}),
         "G04": ("G04_ids", {"type": "Select", "inputs": {"from": "@coalesce(body('G04')?['value'], json('[]'))", "select": "@item()?['Id']"}}),
         "G06": ("G06_counts", {"type": "Select", "inputs": {"from": "@coalesce(body('G06')?['value'], json('[]'))", "select":
                 "@concat(string(item()?['Id']), ':', string(sub(length(split(string(coalesce(item()?['Users'], json('[]'))), '\"PrincipalType\":1}')), 1)), '/', "
                 "string(sub(length(split(string(coalesce(item()?['Users'], json('[]'))), '\"PrincipalType\":4}')), 1)))"}}),
         "E05": ("E05_how", {"type": "Select", "inputs": {"from": "@coalesce(body('E05')?['value'], json('[]'))", "select": "@" + E05_HOW}}),
         "U02": ("U02_names", {"type": "Select", "inputs": {"from": "@coalesce(body('U02')?['value'], json('[]'))",
                                                            "select": "@item()?['skuPartNumber']"}})}
ALL = ["Succeeded", "Failed", "Skipped", "TimedOut"]
MAIL = REV <= 3   # r4: the mail checks were answered in r3
# r4: SharePoint echoes the request address in errors ("source"); replace the typed site, its path and its host.
_SITE = "trim(triggerBody()?['text'])"
_CO = "trim(coalesce(triggerBody()?['text_1'], ''))"
# Also the coworker's address, typed and URL-encoded (%40), in both cases: it is part of the R11/R12/R12b/G04 request
# addresses that SharePoint echoes (review R15 MAJOR). The path is replaced only when it is more than "/".
_PATH = f"if(or(empty({_SITE}), equals(uriPath({_SITE}), '/')), '<none>', uriPath({_SITE}))"
SITE_HIDE = (f"replace(replace(replace(replace(replace(replace(replace({{x}}, if(empty({_SITE}), '<none>', {_SITE}), '<SITE>'), "
             f"{_PATH}, '<SITE-PATH>'), if(empty({_SITE}), '<none>', uriHost({_SITE})), '<HOST>'), "
             f"if(empty({_CO}), '<none>', {_CO}), '<COWORKER>'), if(empty({_CO}), '<none>', toLower({_CO})), '<COWORKER>'), "
             f"if(empty({_CO}), '<none>', encodeUriComponent({_CO})), '<COWORKER>'), "
             f"if(empty({_CO}), '<none>', encodeUriComponent(toLower({_CO}))), '<COWORKER>')")
HOST = {"apiId": "/providers/Microsoft.PowerApps/apis/shared_sharepointonline", "connectionName": "shared_sharepointonline", "operationId": "HttpRequest"}
AUTH = {"value": "@json(decodeBase64(triggerOutputs().headers['X-MS-APIM-Tokens']))['$ConnectionKey']", "type": "Raw"}


def http(method, uri, body, headers, after):
    h = {"Accept": NM}
    if method == "POST": h["Content-Type"] = J
    h.update(headers or {})
    p = {"dataset": "@triggerBody()['text']", "parameters/method": method, "parameters/uri": uri, "parameters/headers": h}
    if body is not None: p["parameters/body"] = json.dumps(body)
    return {"runAfter": after, "type": "OpenApiConnection", "inputs": {"parameters": p, "host": HOST, "authentication": AUTH}}


def op(conn, operation, params, after):
    return {"runAfter": after, "type": "OpenApiConnection", "inputs": {"parameters": params, "host": {
        "apiId": f"/providers/Microsoft.PowerApps/apis/{conn}", "connectionName": conn, "operationId": operation}, "authentication": AUTH}}


def record(cid, what, keep, hide=False, site=False):
    err = f"if(greaterOrEquals(int(coalesce(outputs('{cid}')?['statusCode'], 0)), 400), take(string(body('{cid}')), 600), '')"
    out = f"take(string(body('{cid}')), 3000)"
    if hide: err, out = HIDE.format(x=err), HIDE.format(x=out)
    if site: err, out = SITE_HIDE.format(x=err), SITE_HIDE.format(x=out)
    return {"runAfter": {cid: ALL}, "type": "AppendToArrayVariable", "inputs": {"name": "Results", "value": {
        "id": cid, "what": what, "code": f"@{{outputs('{cid}')?['statusCode']}}",
        "out": keep or f"@{{{out}}}", "err": f"@{{{err}}}"}}}


def build():
    actions = {"Results": {"runAfter": {}, "type": "InitializeVariable",
                           "inputs": {"variables": [{"name": "Results", "type": "array", "value": []}]}}}
    prev = "Results"
    for cid, what, method, uri, body, headers, keep in CHECKS:
        if cid == "R13" and not MAIL:   # r4: no wing-group e-mail (the AD group has none); G01-G04 answer it
            continue
        actions[cid] = http(method, uri, body, headers, {prev: ALL})
        after = cid
        if cid in EXTRA:
            xname, xact = EXTRA[cid]
            actions[xname] = dict(xact, runAfter={cid: ALL})
            after = xname
        actions[f"Record_{cid}"] = record(cid, what, keep, site=True)
        actions[f"Record_{cid}"]["runAfter"] = {after: ALL}
        prev = f"Record_{cid}"
    for cid, what, conn, operation, params, keep in (MAIL_CHECKS if MAIL else []):
        if cid == "E05":   # the test mails need time to arrive
            actions["Delay_E05"] = {"runAfter": {prev: ALL}, "type": "Wait", "inputs": {"interval": {"count": 2, "unit": "Minute"}}}
            prev = "Delay_E05"
        actions[cid] = op(conn, operation, params, {prev: ALL})
        after = cid
        if cid in EXTRA:
            xname, xact = EXTRA[cid]
            actions[xname] = dict(xact, runAfter={cid: ALL})
            after = xname
        actions[f"Record_{cid}"] = record(cid, what, keep, hide=True)
        actions[f"Record_{cid}"]["runAfter"] = {after: ALL}
        prev = f"Record_{cid}"
    actions["Write_Result_File"] = http("POST", f"_api/web/DefaultDocumentLibrary/RootFolder/Files/add(url='{RESULT_FILE}',overwrite=true)",
                                        None, None, {prev: ALL})
    actions["Write_Result_File"]["inputs"]["parameters"]["parameters/body"] = "@{string(variables('Results'))}"
    actions["Result"] = {"runAfter": {"Write_Result_File": ALL}, "type": "Compose", "inputs": "@variables('Results')"}
    return {
        "displayName": f"90161Z T11 Rights Probe r{REV}",
        "description": ("Tests what the person who runs it, and an optional coworker, can do on a SharePoint site" + (", and what they can do with the office mailbox. Creates TEST objects, then deletes them; sends 3 test mails to the person who runs it, waits 2 minutes and reads how they arrived (no addresses kept)." if MAIL else ". Counts site group members by type, gives the coworker's own user Contribute on a TEST list and reads the coworker's rights there. Creates TEST objects, then deletes them; sends no e-mail.") + " Records status codes, permission masks and principal types only, no names."),
        "connections": ["shared_sharepointonline"] + (["shared_office365users", "shared_office365"] if MAIL else []),
        "triggers": {"manual": {"type": "Request", "kind": "Button", "inputs": {"schema": {"type": "object", "properties": {
            "text": {"title": "Site address", "type": "string", "x-ms-dynamically-added": True, "x-ms-content-hint": "TEXT",
                     "description": "Copy it from the browser: everything up to and including the site name"},
            "text_1": {"title": "Coworker e-mail (optional)", "type": "string", "x-ms-dynamically-added": True, "x-ms-content-hint": "TEXT",
                       "description": "A typical wing user (Read on the site). If empty, the coworker checks fail; that is expected"},
            **({} if not MAIL else {"text_2": {"title": "Wing group e-mail (optional)", "type": "string", "x-ms-dynamically-added": True, "x-ms-content-hint": "TEXT",
                       "description": "The group that gives wing members access. If empty, R13 fails; that is expected"},
            "text_3": {"title": "Office mailbox e-mail (optional)", "type": "string", "x-ms-dynamically-added": True, "x-ms-content-hint": "TEXT",
                       "description": "The office's shared mailbox. If empty, E02-E05 fail; that is expected"}})},
            "required": ["text"]}}}},
        "actions": actions,
    }


if __name__ == "__main__":
    out = ROOT / "flow" / "defs" / f"{NAME}.json"
    text = json.dumps(build(), indent=2, ensure_ascii=False) + "\n"
    if "--check" in sys.argv:
        ok = out.exists() and out.read_text(encoding="utf-8") == text
        print("OK rights probe def" if ok else f"STALE {out.name}: run scripts/build_rights_probe.py"); sys.exit(0 if ok else 1)
    out.write_text(text, encoding="utf-8"); old = ROOT / "flow" / "defs" / f"90161Z-T11-rights-probe-r{REV - 1}.json"
    if old.exists(): old.unlink()  # one live revision
    print(f"wrote {out.relative_to(ROOT)} ({len(CHECKS) + len(MAIL_CHECKS)} checks)")
