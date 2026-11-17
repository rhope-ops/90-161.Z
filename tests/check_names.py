#!/usr/bin/env python3
"""Naming and style rules (PFM 2026-11-11; docs/DECISIONS.md, docs/style-standard.md):
- list URL name: PFM + PascalCase, no spaces; display title: "PFM " + title case;
- column internal names: PascalCase, acronyms in capitals, no spaces;
- title case (The Tongue and Quill, AFH 33-337, ch 27, titles and headings) for list titles, column names,
  choice values, view names and flow names: lowercase only articles, short conjunctions and short
  prepositions; always capitalize the first and last word and the first word after a dash or " - ";
- abbreviations in names: only those in DAFMAN 90-161 Attachment 1 (T&Q ch 26; DAFMAN 4.5.9.7.2);
  a column whose name or choices use one has a description that spells it out; a list description
  spells out each abbreviation at first use;
- terms: DAFMAN spellings (e-mail, Not Started); no informal short forms or contractions in product text;
- one meaning per label: a display name used in two lists maps to the same internal name;
- view names: "<audience> - <what>"; flow names: "90161Z T<NN> <title case words> r<N>";
- go.md: no YYYY-MM-DD dates outside URLs (T&Q ch 28)."""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SMALL = {"a", "an", "the", "and", "as", "but", "if", "or", "nor", "at", "by", "for", "in", "of", "off", "on", "out", "to", "up"}
lines = (ROOT / "ref" / "dafman90-161.txt").read_text(encoding="utf-8").split("\n")
start = lines.index("Abbreviations and Acronyms", 4000)
end = next(i for i in range(start, len(lines)) if lines[i].strip() == "Terms")
ABBR = {}
for l in lines[start:end]:
    if "—" in l:
        k, v = l.split("—", 1)
        ABBR[k.strip()] = re.sub(r"\s*\(.*\)$", "", v.strip())
BAD_TERMS = [(r"(?<![-\w])[Ee]mail", "e-mail (DAFMAN; T&Q ch 25)"), (r"\bNot started\b", "Not Started"),
             (r"\bgov device\b", "government computer"), (r"\brepo\b", "repository"),
             (r"\b\w+n't\b|\b(it's|let's|you're|we're|they're|I'm)\b", "no contractions")]
bad = []


def title_case(s, atoms=()):
    """Check that a name is in title case (the T&Q chapter 27 rules: small words lower, hyphenated parts capitalized). Takes the name and quoted choice values to ignore; returns True when it follows the rules."""
    for a in atoms:  # a choice value quoted inside a view name keeps its own capitals (whole words only)
        s = re.sub(r"(?<![\w-])" + re.escape(a) + r"(?![\w-])", "X", s)
    words = [w for w in re.split(r"( - |\u2014|: | |/)", s) if w and w not in (" ", "/")]
    ok, after_break = True, True
    for i, w in enumerate(words):
        if w in (" - ", "\u2014", ": "):
            after_break = True
            continue
        parts = w.strip("()\"'").split("-")
        for j, p in enumerate(parts):
            if not p:
                continue
            edge = (after_break and j == 0) or (i == len(words) - 1 and j == len(parts) - 1)
            if p.lower() in SMALL and not edge and j == 0:
                ok &= p == p.lower()
            else:  # T&Q ch 27 rule 4 and 5c: hyphenated parts are capitalized (Follow-Up)
                ok &= p[0].isupper() or p[0].isdigit()
        after_break = w.endswith(":")
    return ok


# Self-test of the T&Q title rule (review of r8, 2026-11-11)
for _s, _want in {"Follow-Up Action": True, "Follow-up Action": False, "Concur With Comment": True, "Stalled or On Hold": False,
                  "PFM - By Number": True, "Report: The Plan": True, "Report: the Plan": False, "Items (Date)": True,
                  "Superseded By": True, "Prescribed Forms by Publication": True}.items():
    assert title_case(_s) == _want, _s
assert title_case("PFM - Stalled or On Hold", ["On Hold"]) and not title_case("PFM - Status notes", ["No"])


def abbrs(s):
    """Find abbreviations (two or more capitals or digits) in a text. Takes the text; returns a list, leaving out plain numbers such as A5."""
    return [t for t in re.findall(r"\b[A-Z][A-Z0-9]+\b", s) if not re.fullmatch(r"[A-Z]?\d+", t)]  # A5 in "Table A5.2" is a number


def spelled_out(text, t):
    """Check that an abbreviation is spelled out once as "Full name (ABBR)". Takes the text and the abbreviation; returns a truthy value when it is."""
    exp = ABBR.get(t, "")
    return bool(exp) and re.search(re.escape(exp) + r"\s*\(" + re.escape(t) + r"\)", text, re.I)


def product_text(where, s):
    """Check one text a user sees for the banned terms in BAD_TERMS. Takes a place label and the text; appends a message to bad for each hit."""
    for rx, fix in BAD_TERMS:
        if re.search(rx, s):
            bad.append(f"{where}: {s[:60]!r} -> {fix}")


labels = {}
for f in sorted((ROOT / "schemas" / "lists").glob("*.json")):
    d = json.loads(f.read_text(encoding="utf-8"))
    if not re.fullmatch(r"PFM[A-Z][A-Za-z]+", d["list"]): bad.append(f"{f.name}: URL name {d['list']!r}")
    if f.stem != d["list"]: bad.append(f"{f.name}: file name must equal URL name")
    t = d.get("title", "")
    if not (t.startswith("PFM ") and title_case(t)): bad.append(f"{f.name}: title {t!r}")
    desc = d.get("description", "")
    product_text(f"{f.name} description", desc)
    for a in dict.fromkeys(abbrs(t) + abbrs(desc)):  # the title's PFM prefix is spelled out in the description
        if a not in ABBR:
            bad.append(f"{f.name}: abbreviation {a} not in DAFMAN Attachment 1")
            continue
        m = re.search(r"\b" + re.escape(a) + r"\b", desc)
        if not (m and desc[:m.start()].endswith("(") and re.search(re.escape(ABBR[a]) + r"\s*\($", desc[:m.start()], re.I)):
            bad.append(f"{f.name}: description must spell out {a} at first use: '{ABBR[a]} ({a})'")
    choices_all = []
    for c in d["fields"]:
        n = c["displayName"]
        if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", c["internalName"]): bad.append(f"{f.name}: internal name {c['internalName']!r}")
        if not title_case(n): bad.append(f"{f.name}: display name {n!r}")
        product_text(f"{f.name} {c['internalName']}", n + " " + c.get("description", ""))
        prev = labels.setdefault(n, c["internalName"])
        if prev != c["internalName"]: bad.append(f"{f.name}: label {n!r} means {prev} elsewhere")
        used = set(abbrs(n))
        for ch in c.get("choices", []):
            choices_all.append(ch)
            if not title_case(ch): bad.append(f"{f.name}: choice {ch!r} of {c['internalName']}")
            product_text(f"{f.name} choice", ch)
            used |= set(abbrs(ch))
        for a in sorted(used):
            if a not in ABBR: bad.append(f"{f.name}: {c['internalName']}: abbreviation {a} not in DAFMAN Attachment 1")
            elif not spelled_out(c.get("description", ""), a):
                bad.append(f"{f.name}: {c['internalName']}: description must spell out {a} as '{ABBR[a]} ({a})'")
    for v in d.get("views", []):
        m = re.fullmatch(r"([A-Z][A-Za-z]*) - (.+)", v["name"])
        if not (m and title_case(v["name"], choices_all)): bad.append(f"{f.name}: view name {v['name']!r}")
for f in sorted((ROOT / "flow" / "defs").glob("*.json")):
    d = json.loads(f.read_text(encoding="utf-8"))
    n = d["displayName"]
    m = re.fullmatch(r"90161Z T\d{2} (.+) r\d+", n)
    if not (m and title_case(m.group(1))): bad.append(f"{f.name}: flow name {n!r}")
    product_text(f"{f.name} description", d.get("description", ""))
    for msg in re.findall(r'"message": "([^"]*)"', f.read_text(encoding="utf-8")):
        product_text(f"{f.name} message", msg)
go = (ROOT / "go.md").read_text(encoding="utf-8")
for i, l in enumerate(go.split("\n"), 1):
    plain = re.sub(r"\S*://\S+|raw\.githubusercontent\.com\S*|rhope-ops\.github\.io\S*", "", l)
    if re.search(r"\b\d{4}-\d{2}-\d{2}\b", plain): bad.append(f"go.md:{i}: date as YYYY-MM-DD -> 11 Nov 26 (T&Q ch 28)")
    product_text(f"go.md:{i}", plain)
print("\n".join(bad) or "OK names")
sys.exit(1 if bad else 0)
