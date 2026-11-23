#!/usr/bin/env python3
"""Build and check the Fulcrum Minimal design tokens: docs/brand/fulcrum.json is the source, docs/brand/fulcrum.css is built from it.

Usage:
    python3 scripts/fulcrum_palette.py            # check: primitives match the Logo Studies standard, every role names a
                                                 # known colour, every contrast pair meets its minimum, the CSS is current
    python3 scripts/fulcrum_palette.py --write    # rebuild docs/brand/fulcrum.css from the JSON, then check
    python3 scripts/fulcrum_palette.py --test     # self-test; prints FULCRUM TEST PASS

Inputs: docs/brand/fulcrum.json (primitives, derived colours, roles per theme, contrast pairs).
Outputs: "FULCRUM PASS" and exit 0, or one line per finding and exit 1; with --write, docs/brand/fulcrum.css.
The five primitives are pinned below to the Logo Studies standard; a change there is copied here by hand, on the Maintainer's request.
Standard library only.
Network: none.
Writes: docs/brand/fulcrum.css with --write only (the self-test: temporary files).
Credentials: none.
"""
import argparse
import json
import pathlib
import re
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = "docs/brand/fulcrum.json"
OUTPUT = "docs/brand/fulcrum.css"
# Logo Studies canvas, project/standard/rho-family-standard.json v2.9, "palettes" > "fulcrum" (disc, ring_and_symbol,
# accent, dots, gold). The marks and the UI share these five values exactly.
STANDARD_PRIMITIVES = {"ink": "#15171D", "cream": "#F3EEE4", "ember": "#E4572E", "slate": "#5A5E6A", "gold": "#D4AF37"}
THEMES = ("light", "dark")
# The keys the CSS header and the checks read.
REQUIRED_KEYS = ("name", "version", "date", "source", "primitives", "derived", "roles", "contrast")
HEX = re.compile(r"^#[0-9A-F]{6}$")
# WCAG 2.x relative luminance: the sRGB threshold and the flare term of the contrast ratio.
SRGB_LINEAR_LIMIT = 0.03928
FLARE = 0.05
# Fleet v2 plan 2026-11-23, Fulcrum Minimal 2.0.0: a text colour (a foreground on the page) needs 4.5:1; a UI colour (a
# control border, the focus ring) needs 3:1 (WCAG 1.4.11), each against the page colour of its theme. The self-test
# computes every pair from the JSON and prints it.
TEXT_ROLES = ("page-fg", "page-muted", "page-link", "page-error", "success", "warning")
UI_ROLES = ("control-line", "focus")
TEXT_MINIMUM, UI_MINIMUM = 4.5, 3.0
COMPONENTS = """
/* Components: each one is a shape from the marks (the Maintainer, 2026-11-20). */
body{background:var(--fm-page);color:var(--fm-page-fg)}
a{color:var(--fm-page-link)}
:focus-visible{outline:3px solid var(--fm-focus);outline-offset:2px}
/* The header band: ink with the gold rule, as the disc and the phrase. */
.fm-band{background:var(--fm-band);color:var(--fm-band-fg);border-bottom:3px solid var(--fm-rule)}
.fm-band .fm-muted{color:var(--fm-band-muted)}
.fm-band a{color:var(--fm-band-link)}
.fm-band .fm-error{color:var(--fm-band-error)}
/* The disc: a card drawn as the logo, an ink disc with a ring inset 5px. */
.fm-disc{background:var(--fm-disc);color:var(--fm-disc-fg);border-radius:14px;padding:22px;
  box-shadow:inset 0 0 0 5px var(--fm-disc),inset 0 0 0 6px var(--fm-disc-ring)}
.fm-disc a{color:var(--fm-disc-link)}
.fm-disc .fm-muted{color:var(--fm-disc-muted)}
.fm-disc .fm-error{color:var(--fm-disc-error)}
.fm-muted{color:var(--fm-page-muted)}
.fm-error{color:var(--fm-page-error)}
/* The dotted line: round dots, as the marks' level line (never a dash pattern). */
.fm-dots{border:0;height:4px;margin:0;background:radial-gradient(circle,var(--fm-dots) 1.5px,transparent 1.7px) 0 0/10px 4px repeat-x}
/* The fulcrum: an ember triangle before a heading. */
.fm-fulcrum{display:flex;align-items:center;gap:8px}
.fm-fulcrum::before{content:"";flex:none;width:12px;height:10px;background:var(--fm-accent);clip-path:polygon(50% 0,100% 100%,0 100%)}
/* The primary button: ember with ink text in both themes. */
.fm-btn{background:var(--fm-accent);color:var(--fm-on-accent);border:1px solid var(--fm-accent);border-radius:6px;min-height:44px;padding:0 16px;font-weight:600}
@media (forced-colors:active){.fm-disc{box-shadow:none;border:1px solid CanvasText}.fm-fulcrum::before,.fm-dots{forced-color-adjust:none}}
"""


def luminance(hex_colour):
    """Return the WCAG relative luminance of a #RRGGBB colour."""
    channels = [int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= SRGB_LINEAR_LIMIT else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(fore, back):
    """Return the WCAG contrast ratio of two #RRGGBB colours."""
    light, dark = sorted((luminance(fore), luminance(back)), reverse=True)
    return (light + FLARE) / (dark + FLARE)


def palette(tokens):
    """Return every named colour: the primitives and the derived colours."""
    return {**tokens.get("primitives", {}), **tokens.get("derived", {})}


def check_shape(tokens):
    """Return findings for missing header keys and malformed contrast entries, so later steps never crash.

    Args:
        tokens: the parsed docs/brand/fulcrum.json.
    Returns:
        A list of finding lines, empty when the file has every key and each contrast entry is [role, role, number].
    """
    found = [f"{SOURCE}: missing key {key}" for key in REQUIRED_KEYS if key not in tokens]
    for entry in tokens.get("contrast", []):
        if not (isinstance(entry, list) and len(entry) == 3 and isinstance(entry[2], (int, float))):
            found.append(f"{SOURCE}: contrast entry is not [role, role, minimum]: {entry}")
    return found


def check_colours(tokens):
    """Return findings for the primitives (pinned to the standard) and the hex form of every named colour.

    Args:
        tokens: the parsed docs/brand/fulcrum.json.
    Returns:
        A list of finding lines, empty when the colours pass.
    """
    found = []
    if tokens.get("primitives") != STANDARD_PRIMITIVES:
        found.append(f"{SOURCE}: primitives differ from the Logo Studies standard: {STANDARD_PRIMITIVES}")
    for name, value in palette(tokens).items():
        if not HEX.match(str(value)):
            found.append(f"{SOURCE}: colour {name} is not #RRGGBB in capitals: {value}")
    overlap = set(tokens.get("primitives", {})) & set(tokens.get("derived", {}))
    found += [f"{SOURCE}: {name} is both a primitive and a derived colour" for name in sorted(overlap)]
    return found


def check_roles(tokens):
    """Return findings for the roles: both themes have the same role names, and each names a known colour.

    Args:
        tokens: the parsed docs/brand/fulcrum.json.
    Returns:
        A list of finding lines, empty when the roles pass.
    """
    found, colours, roles = [], palette(tokens), tokens.get("roles", {})
    if sorted(roles) != sorted(THEMES):
        return [f"{SOURCE}: roles must have exactly the themes {list(THEMES)}"]
    if set(roles["light"]) != set(roles["dark"]):
        found.append(f"{SOURCE}: the light and dark themes name different roles")
    for theme in THEMES:
        found += [f"{SOURCE}: {theme} role {role} names an unknown colour: {name}"
                  for role, name in roles[theme].items() if name not in colours]
    used = {name for theme in THEMES for name in roles[theme].values()}
    found += [f"{SOURCE}: derived colour {name} is not used by any role" for name in tokens.get("derived", {}) if name not in used]
    return found


def check_contrast(tokens):
    """Return findings for each contrast pair, in each theme, that is under its minimum.

    Args:
        tokens: the parsed docs/brand/fulcrum.json, with valid roles.
    Returns:
        A list of finding lines, empty when every pair meets its minimum.
    """
    found, colours = [], palette(tokens)
    for theme in THEMES:
        roles = tokens["roles"][theme]
        for fore, back, minimum in tokens.get("contrast", []):
            if fore not in roles or back not in roles:
                found.append(f"{SOURCE}: contrast pair {fore}/{back} names an unknown role")
                continue
            ratio = contrast(colours[roles[fore]], colours[roles[back]])
            if ratio < minimum:
                found.append(f"{SOURCE}: {theme} {fore} on {back} is {ratio:.2f}:1, under {minimum}:1")
    return found


def page_table(tokens):
    """Return one row per theme and role: (theme, role, hex, ratio on the page, minimum), text roles then UI roles.

    Args:
        tokens: the parsed docs/brand/fulcrum.json, with valid roles.
    Returns:
        The rows; the ratio is computed from the colours, never copied.
    """
    colours, rows = palette(tokens), []
    for theme in THEMES:
        roles = tokens["roles"][theme]
        page = colours[roles["page"]]
        for role, minimum in [(r, TEXT_MINIMUM) for r in TEXT_ROLES] + [(r, UI_MINIMUM) for r in UI_ROLES]:
            value = colours[roles[role]]
            rows.append((theme, role, value, contrast(value, page), minimum))
    return rows


def role_block(tokens, theme):
    """Return the CSS custom properties of one theme's roles."""
    colours = palette(tokens)
    return "".join(f"--fm-{role}:{colours[name]};" for role, name in tokens["roles"][theme].items())


def render_css(tokens):
    """Return the whole CSS file built from the tokens.

    Args:
        tokens: the parsed docs/brand/fulcrum.json, with valid roles.
    Returns:
        The text of docs/brand/fulcrum.css.
    """
    primitives = "".join(f"--fm-{name}:{value};" for name, value in tokens["primitives"].items())
    dark = role_block(tokens, "dark") + "color-scheme:dark"
    return (f"/* GENERATED from {SOURCE} by: python3 scripts/fulcrum_palette.py --write. Do not edit by hand.\n"
            f"   {tokens['name']} {tokens['version']} ({tokens['date']}). Source of the primitives: {tokens['source']}.\n"
            "   Use: link this file, put class fm-band on the header band, fm-disc on the main card, fm-dots on dividers\n"
            "   (an <hr>), fm-fulcrum on section headings, fm-btn on the primary button, fm-error on error text. */\n"
            f":root{{{primitives}{role_block(tokens, 'light')}color-scheme:light}}\n"
            f"@media (prefers-color-scheme:dark){{:root:not([data-theme=\"light\"]){{{dark}}}}}\n"
            f":root[data-theme=\"dark\"]{{{dark}}}\n" + COMPONENTS.lstrip("\n"))


def run(root, write):
    """Check (and with write, rebuild) the tokens under root; return the list of findings.

    Args:
        root: the repository folder that holds docs/brand/.
        write: True to rebuild the CSS file before the check.
    Returns:
        The findings, empty when everything passes.
    """
    try:
        tokens = json.loads((root / SOURCE).read_text(encoding="utf-8"))
    except (OSError, ValueError) as err:
        return [f"{SOURCE}: cannot read: {err}"]
    found = check_shape(tokens)
    if found:
        return found
    found = check_colours(tokens) + check_roles(tokens)
    if found:
        return found
    found = check_contrast(tokens)
    css = render_css(tokens)
    if write:
        (root / OUTPUT).write_text(css, encoding="utf-8")
    current = (root / OUTPUT).read_text(encoding="utf-8") if (root / OUTPUT).exists() else ""
    if current != css:
        found.append(f"{OUTPUT}: out of date; run: python3 scripts/fulcrum_palette.py --write")
    return found


def self_test():
    """Run the checks on good and broken copies of the kit's own tokens, then on this repo's files.

    Returns:
        The exit code: 0 when every case passes, else 1.
    """
    good = json.loads((ROOT / SOURCE).read_text(encoding="utf-8"))
    cases = [("the kit's own tokens pass", lambda t: None, ""),
             ("a changed primitive fails", lambda t: t["primitives"].update(ember="#E4572F"), "differ from the Logo Studies"),
             ("an unknown colour name fails", lambda t: t["roles"]["dark"].update(page="night"), "unknown colour"),
             ("a missing dark role fails", lambda t: t["roles"]["dark"].pop("rule"), "different roles"),
             ("low contrast fails", lambda t: t["roles"]["light"].update({"page-muted": "hair-light"}), "under 4.5:1"),
             ("an unused derived colour fails", lambda t: t["derived"].update(spare="#123456"), "not used"),
             ("a malformed hex value fails", lambda t: t["derived"].update(mist="#a9acb5"), "not #RRGGBB"),
             ("a contrast pair with an unknown role fails", lambda t: t["contrast"].append(["nope", "page", 3]), "unknown role"),
             ("a missing header key fails", lambda t: t.pop("version"), "missing key version"),
             ("a malformed contrast entry fails", lambda t: t["contrast"].append(["page-fg", "page"]), "not [role, role"),
             ("a control line under 3:1 fails", lambda t: t["derived"].update({"control-line-light": "#DED6C8"}), "control-line on page"),
             ("a band link under 4.5:1 fails", lambda t: t["roles"]["light"].update({"band-link": "ember-deep"}), "band-link on band")]
    failed = 0
    for label, change, expect in cases:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "docs/brand").mkdir(parents=True)
            tokens = json.loads(json.dumps(good))
            change(tokens)
            (root / SOURCE).write_text(json.dumps(tokens), encoding="utf-8")
            found = run(root, write=True)
            ok = (not found) if not expect else any(expect in line for line in found)
            failed += not ok
            print(("ok   " if ok else "FAIL ") + label + ("" if ok else f": {found}"))
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        (root / "docs/brand").mkdir(parents=True)
        (root / SOURCE).write_text(json.dumps(good), encoding="utf-8")
        (root / OUTPUT).write_text("stale", encoding="utf-8")
        ok = any("out of date" in line for line in run(root, write=False))
        failed += not ok
        print(("ok   " if ok else "FAIL ") + "a stale CSS file fails")
    tokens = json.loads((ROOT / SOURCE).read_text(encoding="utf-8"))
    bad = 0
    for theme, role, value, ratio, minimum in page_table(tokens):
        bad += ratio < minimum
        print(f"     {theme:5} {role:13} {value} on page {ratio:5.2f}:1 (needs {minimum}:1)")
    failed += bool(bad)
    print(("ok   " if not bad else "FAIL ") + "every text token is 4.5:1 and every UI token 3:1 on the page, both themes")
    own = run(ROOT, write=False)
    failed += bool(own)
    print(("ok   " if not own else "FAIL ") + "this repo's tokens and CSS pass" + ("" if not own else f": {own}"))
    print("FULCRUM TEST PASS" if not failed else "FULCRUM TEST FAIL")
    return 1 if failed else 0


def main():
    """Parse the arguments and run the check, the rebuild or the self-test.

    Returns:
        The exit code: 0 on pass, else 1.
    """
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true", help="rebuild docs/brand/fulcrum.css, then check")
    parser.add_argument("--test", action="store_true", help="self-test")
    args = parser.parse_args()
    if args.test:
        return self_test()
    found = run(ROOT, args.write)
    for line in found:
        print(line)
    print("FULCRUM PASS" if not found else "FULCRUM FAIL")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
