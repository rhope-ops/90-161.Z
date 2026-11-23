#!/usr/bin/env python3
"""The solution.xml and customizations.xml text for scripts/build_flow_solution.py (split from it, 2026-11-23, for the 450-line
code standard cap C4; no change to the built zips).

What it holds: the publisher and platform values copied from the R18 export (r5, see the notes in build_flow_solution.py),
and the functions that write customizations.xml and solution.xml. It reads nothing and writes nothing on its own.
Usage: import build_flow_solution_xml; the builder calls customizations_xml() and solution_xml().
Network: none.
Writes: none.
Credentials: none.
Run target: Python 3.8+, standard library only.
"""
PUBLISHER, PREFIX, VERSION = "PFM", "pfm", "1.0.0.1"   # publisher PFM as in the T05 export
PLATFORM, SERVICEABILITY = "9.2.26101.188", "9.2.26101.00188"   # the R18 export (r5); T05 had 9.2.26094.172
OPTION_PREFIX = 89127   # the publisher PFM in this environment (R18 export, r5); a new environment creates PFM with it

XSI = 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
ORG = f'OrganizationVersion="{PLATFORM}" OrganizationSchemaType="Standard" CRMServerServiceabilityVersion="{SERVICEABILITY}"'
# The publisher's two empty addresses list these elements, as in the R18 export (r5): ADDR_FIELDS, the shipping method code, then ADDR_TAIL.
ADDR_FIELDS = ["City", "County", "Country", "Fax", "FreightTermsCode", "ImportSequenceNumber", "Latitude", "Line1", "Line2",
               "Line3", "Longitude", "Name", "PostalCode", "PostOfficeBox", "PrimaryContactName"]
ADDR_TAIL = ["StateOrProvince", "Telephone1", "Telephone2", "Telephone3", "TimeZoneRuleVersionNumber", "UPSZone", "UTCOffset",
             "UTCConversionTimeZoneCode"]


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
    """Build solution.xml, the manifest of the solution zip.

    Args:
        unique: the solution's unique name.
        title: the solution's display title.
        root_components: the RootComponent lines, as one text.

    Returns:
        The text of solution.xml (no XML declaration; attributes in the exported order).
    """
    return (   # no XML declaration; attributes in the exported order (r5)
        f'<ImportExportXml version="{PLATFORM}" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="CrmLive" {XSI} '
        f'OrganizationVersion="{PLATFORM}" OrganizationSchemaType="Standard" CRMServerServiceabilityVersion="{SERVICEABILITY}">\n'
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
