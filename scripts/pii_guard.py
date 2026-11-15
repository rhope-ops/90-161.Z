#!/usr/bin/env python3
"""Block personal data and secrets before they reach the remote: emails, phone numbers, ID-number shapes, API tokens
and private keys, and names from a denylist that is kept outside the repo.

Usage:
    python3 scripts/pii_guard.py --all             # every tracked file (working tree)
    python3 scripts/pii_guard.py --range A..B      # commits in A..B: added lines, messages, author and committer
    python3 scripts/pii_guard.py --push            # pre-push hook mode: reads the hook's stdin lines
    python3 scripts/pii_guard.py FILE ...          # these files
    python3 scripts/pii_guard.py --status          # denylist source, entry count and fingerprint (never the names), profile
    --require-denylist                             # fail when no denylist is found (the hook and the Action use it),
                                                   # or only warn when .pii-guard has the line `denylist: warn`
    python3 scripts/pii_guard.py --test            # self-test; prints PII GUARD TEST PASS

Opt-in: the guard runs only in a repo with a `.pii-guard` file at its root (the hook and the Action check for it).
That file lists exact strings that are allowed (one per line, `#` comments), and paths to skip as
`skip: <path or glob>` lines (for example a public reference text that quotes office contacts), and the option line
`denylist: warn` (starter tier; kit default since 2026-11-13): with no denylist, --require-denylist warns instead of failing. Only the Administrator adds entries;
agents never add one to get past a block (AGENTS.md "Personal data").

Two tiers (the Administrator, 2026-11-15), set in `.pii-guard`:
    minimum    no option line: the checks under "Checks".
    DoD        the option line `profile: dod`: the minimum checks plus the checks under "DoD checks"; a missing
               denylist always blocks (`denylist: warn` is ignored). In the Action the line is read from the
               pull-request base (--allow-from), so a pull request cannot lower its own tier.

Name denylist (never committed): one name or word per line, `#` comments, matched whole-word, any case.
    - env PII_GUARD_DENYLIST: the list itself (newline or comma separated); the GitHub Action reads it from the
      Actions secret of the same name.
    - env PII_GUARD_DENYLIST_FILE, else ~/.config/pii-guard/denylist.txt
With no denylist, names are not checked and the guard says so (exit code unchanged).
Fingerprint: 8 hex characters of SHA-256 over the list (lower case, no duplicates, sorted). Every copy of the same
list prints the same fingerprint, whatever its order or separators: compare the places to find a copy that differs.

Checks:
    email      any address, except *@users.noreply.github.com, noreply@ / no-reply@ addresses, and the
               reserved example domains (example.com/.org/.net, *.example, *.invalid, *.test, *.localhost)
    phone      US numbers (NNN-NNN-NNNN, (NNN) NNN-NNNN, NNN.NNN.NNNN), +country numbers
    id         SSN shape (NNN-NN-NNNN), or 9 digits next to SSN / social security
    secret     API tokens (GitHub, GitLab, AWS, Anthropic, OpenAI, Google, Slack, Stripe) and private-key headers
    name       denylist words
DoD checks (only with `profile: dod`):
    milhost    a host name in the US military top-level domain (also inside a URL), and the DoD cloud hosts in MILHOST
    marking    controlled-information and classification banner marks (the list: MARKING below)
    dodid      10 digits next to a DoD ID keyword (the list: DODID below)
    unscanned  a file the guard cannot read: a SKIP_SUFFIX type, a binary file (Office files too) or one over
               MAX_BYTES. It blocks unless a `skip: <path or glob>` line names it.
Known limits of the DoD checks: the scanner reads one line at a time, so a keyword on one line and its number on
the next pass; a binary file that enters only through a merge resolution is found by --all, not by the commit scan;
a one-word classification alone on a line is a mark in upper case only (in title case it is an ordinary heading).
A tier line in any form other than `profile: dod`, and a `.pii-guard` that is not UTF-8 text, fail the scan: a wrong
spelling or a wrong file encoding cannot lower the tier in silence. Limit: a line with both the key and the value
misspelt is not seen as a tier line; `--status` and the result line always print the tier in use.
Matches are printed masked (names and secrets as a length only), so CI logs do not repeat them. Exit 1 when anything is found.
Standard library only. Needs git (except for FILE mode).
"""
import argparse
import fnmatch
import hashlib
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import unicodedata

ZERO = re.compile(r"^0+$")
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
PHONE = [
    re.compile(r"(?<![\w./-])\(?\d{3}\)?[-. ]\d{3}[-.]\d{4}(?![\w-])"),
    re.compile(r"(?<![\w./-])\(\d{3}\) ?\d{3}[-. ]\d{4}(?![\w-])"),
    re.compile(r"(?<![\w+])\+\d{1,3}[ -]\(?\d{1,4}\)?[ -]\d{2,4}[ -]\d{3,4}(?![\w-])"),
    re.compile(r"(?i)\b(?:phone|tel|cell|mobile|fax|call)\b\D{0,20}?(\+?1?[ .-]?\d{3}[ .-]?\d{3}[ .-]?\d{4})\b"),
    re.compile(r"(?<![\w+])\+1\d{10}\b"),
]
SSN = re.compile(r"(?<![\w-])\d{3}-\d{2}-\d{4}(?![\w-])")
SSN_KW = re.compile(r"(?i)\b(?:SSN|social security)\b\D{0,20}?(\d{3}[ -]?\d{2}[ -]?\d{4})\b")
SECRET = [re.compile(r) for r in (
    r"\bgh[pousr]_[A-Za-z0-9]{36,}\b",                 # GitHub tokens
    r"\bgithub_pat_[A-Za-z0-9_]{60,}\b",               # GitHub fine-grained token
    r"\bglpat-[A-Za-z0-9_-]{20,}",                      # GitLab
    r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b",                  # AWS access key id
    r"\bsk-ant-[A-Za-z0-9_-]{20,}",                     # Anthropic
    r"\bsk-(?:proj-|svcacct-)?(?=[A-Za-z0-9_-]*[A-Z])(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]{32,}",  # OpenAI (mixed case + digit)
    r"\bAIza[0-9A-Za-z_-]{35}(?![0-9A-Za-z_-])",        # Google API key
    r"\bxox[abposr]-[A-Za-z0-9-]{10,}",                 # Slack
    r"\b[rs]k_live_[0-9A-Za-z]{24,}",                   # Stripe live key
    r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY(?: BLOCK)?-----",  # PEM, OpenSSH and PGP private keys
)]
# DoD tier (`profile: dod`). The marks are split in the source so this file does not flag itself.
MILHOST = re.compile(
    r"(?i)(?<![A-Za-z0-9-])(?:(?:[a-z0-9-]+\.)+mil(?![A-Za-z0-9-]|\.[A-Za-z0-9])"   # any host under the military domain
    r"|(?:[a-z0-9-]+\.)*sharepoint-mil\.us\b|dod\.teams\.microsoft\.us\b)")          # DoD cloud tenant hosts
MARKING = [re.compile(r) for r in (
    r"\bCUI/" r"/", r"^[^A-Za-z0-9]*CU" r"I[^A-Za-z0-9]*$", r"(?i)\bcontrolled\s+unclassified\s+" r"information\b",
    r"^[^A-Za-z0-9]*(?:SEC" r"RET|CONFID" r"ENTIAL|UNCLASS" r"IFIED)[^A-Za-z0-9]*$",  # one word alone on its line, upper case
    r"(?i)^[^A-Za-z0-9]*TOP\s+SEC" r"RET[^A-Za-z0-9]*$",                               # two words alone on a line, any case
    r"\bFO" r"UO\b", r"(?i)\bfor\s+official\s+use\s+" r"only\b", r"\bNOF" r"ORN\b",
    r"(?i)\b(?:SECRET|CONFIDENTIAL|UNCLASSIFIED)/" r"/",
)]
_DODID_KW = r"(?<![A-Za-z])(?:DOD[\s_-]*ID|EDIPI|CAC)(?![A-Za-z])"  # also dod_id, and DODID joined to the number
DODID = [re.compile(r"(?i)" + _DODID_KW + r"\D{0,20}?(\d{10})(?!\d)"),          # keyword, then the number
         re.compile(r"(?i)(?<!\d)(\d{10})(?!\d)\D{0,20}?" + _DODID_KW)]        # the number, then the keyword
ALLOWED_EMAIL = re.compile(
    r"(?i)(@users\.noreply\.github\.com$|^(no-?reply)@|@example\.(com|org|net)$|\.(example|invalid|test|localhost)$)")
SKIP_SUFFIX = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".zip", ".gz", ".woff", ".woff2", ".ttf")
MAX_BYTES = 2_000_000


def mask(kind, s):
    """Show the kind and a length, never enough to rebuild the value (CI logs may be public)."""
    if kind == "unscanned":
        return s  # a reason, not a value
    if kind in ("name", "secret", "milhost", "marking"):
        return f"<{len(s)} chars>"
    if kind == "email" and "@" in s:
        return "***@" + "*" * len(s.split("@", 1)[1])
    return "*" * (len(s) - 2) + s[-2:] if len(s) > 6 else "*" * len(s)


def _clean_entry(w):
    """Drop one wrapping pair of <> or quotes: a placeholder copied as "<Name>" must still match "Name"."""
    w = w.strip()
    if len(w) > 2 and (w[0], w[-1]) in (("<", ">"), ('"', '"'), ("'", "'")):
        w = w[1:-1].strip()
    return w


def parse_denylist(raw):
    """Entries shorter than 2 characters, or with no letter or digit, are dropped: they would flag ordinary text."""
    words = (_clean_entry(l.split("#", 1)[0]) for l in re.split(r"[\n,]", raw or ""))
    return [w for w in words if len(w) >= 2 and re.search(r"[A-Za-z0-9]", w)]


def denylist_source():
    """Return (raw text, where it came from) for the first source with at least one entry, or ("", None).
    first_use_check.py imports this, so both scripts agree on what counts as a denylist."""
    raw = os.environ.get("PII_GUARD_DENYLIST", "")
    if parse_denylist(raw):
        return raw, "environment variable PII_GUARD_DENYLIST"
    path = os.environ.get("PII_GUARD_DENYLIST_FILE") or os.path.expanduser("~/.config/pii-guard/denylist.txt")
    try:
        text = pathlib.Path(path).read_text(errors="replace") if os.path.isfile(path) else ""
    except OSError:
        text = ""
    if parse_denylist(text):
        return text, "file " + path
    return "", None


MISSING_HELP = ("no denylist found. Add your names (comma or newline separated), never in a repo or a chat: "
                "a cloud session: environment variable PII_GUARD_DENYLIST in the cloud environment's settings; "
                "GitHub Actions: repository secret PII_GUARD_DENYLIST; your computer: ~/.config/pii-guard/denylist.txt. "
                "See docs/FIRST_USE.md.")


WARN_OPTION = "denylist: warn"  # .pii-guard option line; first_use_check.py reads it too


# A tier line, also in a wrong form. After any leading punctuation (a bullet, a quote, a bracket):
#   - the word profile, unless a character of a name follows it (profile.example.org and profile-x stay allowed values);
#   - or one word, at most one punctuation mark, and the value dod (a misspelt key such as "profil: dod").
# Every form other than `profile: dod` is unknown and fails the scan.
_TIER = r"[\W_]*(?:profile(?![A-Za-z0-9._/-])|(?!skip\b|denylist\b)[A-Za-z_-]{1,40}\s*[^\w\s.]?\s*dod[\W_]*$)"
PROFILE_LINE = re.compile(r"(?i)^" + _TIER)
OPTION_LINE = re.compile(r"(?i)^(?:" + _TIER + r"|denylist\s*:)")  # option lines, never allowed values
OPTION_MAX = 200  # a longer line is never an option line: the patterns above only ever see short lines (no slow match)


def is_tier_line(v):
    return len(v) <= OPTION_MAX and bool(PROFILE_LINE.match(v))


def is_option_line(v):
    return len(v) <= OPTION_MAX and bool(OPTION_LINE.match(v))
UNREADABLE = "profile: <.pii-guard is not UTF-8 text>"  # load_allow adds it; it reads as an unknown tier line
UNKNOWN_PROFILE = ("unknown profile line in .pii-guard, or the file is not UTF-8 text: the only tier line is "
                   "`profile: dod`. Correct or remove the line, or save the file as UTF-8; the guard does not guess a tier.")


def profile_of(allow):
    """Tier from the .pii-guard lines: "minimum" (no profile line), "dod", or "unknown" (any other value: the caller
    fails, so a wrong spelling cannot lower the tier in silence). Case, and spacing around the colon, do not matter."""
    lines = [v for v in allow if is_tier_line(v)]
    if not lines:
        return "minimum"
    return "dod" if all(re.fullmatch(r"(?i)profile\s*:\s*dod", v) for v in lines) else "unknown"


def dod_mode(root):
    """True when .pii-guard in the working tree has a profile line (an unknown value counts: fail closed)."""
    return profile_of(load_allow(root)) != "minimum"


def warn_mode(root):
    """True when .pii-guard in the working tree has the option line `denylist: warn` and no profile line."""
    allow = load_allow(root)
    return WARN_OPTION in allow and profile_of(allow) == "minimum"


def fingerprint(words):
    """8 hex characters over the normalized list: equal for every copy of the same list, and shows no entry."""
    norm = sorted({w.lower() for w in words})
    return hashlib.sha256("\n".join(norm).encode()).hexdigest()[:8]


def load_denylist():
    return parse_denylist(denylist_source()[0])


def load_allow(root, ref=None):
    """Allowed exact strings from .pii-guard (working tree, or the file at a git ref such as the PR base)."""
    if ref:
        r = subprocess.run(["git", "show", f"{ref}:.pii-guard"], cwd=root, capture_output=True)
        data = r.stdout if r.returncode == 0 else b""
    else:
        f = pathlib.Path(root) / ".pii-guard"
        data = f.read_bytes() if f.is_file() else b""
    # The file must be clean UTF-8 text. Anything else (UTF-16 from a Windows shell, a NUL, bytes that do not decode)
    # could hide the tier line, so it adds UNREADABLE: profile_of then says "unknown" and the scan fails.
    bad = data.startswith((b"\xff\xfe", b"\xfe\xff")) or b"\0" in data
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        text, bad = data.decode("utf-8", "replace"), True
    # Invisible format characters (zero-width space, a second byte-order mark) are dropped: they must not hide a line.
    text = "".join(c for c in text if unicodedata.category(c) != "Cf")
    # A comment starts at the line start or after whitespace, so "skip: docs/#1.txt" keeps its "#".
    vals = (re.split(r"(?:^|\s)#", l, maxsplit=1)[0].strip() for l in text.splitlines())
    return {v for v in vals if v} | ({UNREADABLE} if bad else set())


def skipped(path, allow):
    """True when a `skip: <path or glob>` line in .pii-guard covers this repo-relative path."""
    globs = [a[5:].strip() for a in allow if a.startswith("skip:")]
    globs = [g for g in globs if g.strip("*/")]  # a bare "*" or "**" would switch the guard off: ignored
    return any(fnmatch.fnmatchcase(path, g) or path.startswith(g.rstrip("/") + "/") for g in globs if g)


def scan_text(text, where, deny, allow, dod=False):
    """Return findings (where, line_no, kind, masked) for one text. dod: also run the DoD checks."""
    found = []
    name_re = re.compile(r"(?i)(?<![A-Za-z0-9])(" + "|".join(re.escape(w) for w in deny) + r")(?![A-Za-z0-9])") if deny else None
    hosts_ok = {v.lower() for v in allow} if dod else set()  # a host name has no case
    for n, line in enumerate(text.splitlines(), 1):
        hits = []
        for m in EMAIL.finditer(line):
            if not ALLOWED_EMAIL.search(m.group()):
                hits.append(("email", m.group()))
        for rx in SECRET:
            hits += [("secret", m.group()) for m in rx.finditer(line)]
        for rx in PHONE:
            hits += [("phone", m.group(m.lastindex or 0)) for m in rx.finditer(line)]
        hits += [("id", m.group()) for m in SSN.finditer(line)]
        hits += [("id", m.group(1)) for m in SSN_KW.finditer(line)]
        if dod:
            mails = [m.span() for m in EMAIL.finditer(line)]  # the host of a mail address is part of that finding
            hits += [("milhost", m.group()) for m in MILHOST.finditer(line)
                     if not any(a <= m.start() and m.end() <= b for a, b in mails)]
            for rx in DODID:
                hits += [("dodid", m.group(1)) for m in rx.finditer(line)]
            for rx in MARKING:
                hits += [("marking", m.group().strip()) for m in rx.finditer(line)]
        if name_re:
            spans = [(s.start(), s.end()) for v in allow if not v.startswith("skip:")
                     for s in re.finditer(re.escape(v), line, re.IGNORECASE)]
            hits += [("name", m.group(1)) for m in name_re.finditer(line)
                     if not any(a <= m.start(1) and m.end(1) <= b for a, b in spans)]  # inside an allowed string
        seen = set()
        for kind, val in hits:
            if val in allow or (kind == "milhost" and val.lower() in hosts_ok) or (kind, val) in seen \
                    or any(val == v for _, v in seen):
                continue
            seen.add((kind, val))
            found.append((where, n, kind, mask(kind, val)))
    return found


def git(*args, root="."):
    return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True,
                          errors="replace").stdout


def scan_files(paths, root, deny, allow, dod=False):
    """dod: a file that cannot be scanned is a finding (kind unscanned) unless a `skip:` line names it."""
    found = []
    for p in paths:
        f = pathlib.Path(root) / p
        if skipped(str(p), allow) or not f.is_file():
            continue
        why = None
        if f.suffix.lower() in SKIP_SUFFIX:
            why = f"file type {f.suffix.lower()} is not scanned"
        elif f.stat().st_size > MAX_BYTES:
            why = f"larger than {MAX_BYTES} bytes"
        else:
            data = f.read_bytes()
            if b"\0" in data[:8192]:
                why = "binary file"
        if why:
            if dod:
                found.append((str(p), 0, "unscanned", why))
            continue
        found += scan_text(data.decode("utf-8", "replace"), str(p), deny, allow, dod)
    return found


def scan_commits(revs, root, deny, allow, dod=False):
    """revs: arguments for git rev-list. Scan each commit's identity, message and added lines.
    dod: an added or changed file that cannot be scanned is a finding unless a `skip:` line names it."""
    found = []
    shas = git("rev-list", *revs, root=root).split()
    for sha in shas:
        short = sha[:7]
        meta = git("show", "-s", "--format=%an%n%ae%n%cn%n%ce%n%B", sha, root=root)
        lines = meta.split("\n")
        ident = "\n".join(lines[:4])
        found += [(f"commit {short} author/committer", n, k, v) for _, n, k, v in scan_text(ident, "", deny, allow, dod)]
        found += [(f"commit {short} message", n, k, v) for _, n, k, v in scan_text("\n".join(lines[4:]), "", deny, allow, dod)]
        if dod:  # numstat marks a binary file with "-"; the patch below has no added lines for it
            stat = git("-c", "core.quotepath=off", "show", "--format=", "--numstat", "-z", "--no-renames",
                       "--diff-filter=AM", sha, root=root)
            sizes = {}
            for rec in filter(None, git("ls-tree", "-r", "-l", "-z", sha, root=root).split("\0")):
                info, _, name = rec.partition("\t")
                size = info.split()[-1]
                if size.isdigit():
                    sizes[name] = int(size)
            for rec in filter(None, stat.split("\0")):
                parts = rec.split("\t", 2)
                if len(parts) != 3 or skipped(parts[2], allow):
                    continue
                if sizes.get(parts[2], 0) > MAX_BYTES:
                    found.append((f"commit {short} {parts[2]}", "+", "unscanned", f"larger than {MAX_BYTES} bytes"))
                elif parts[2].lower().endswith(SKIP_SUFFIX):
                    found.append((f"commit {short} {parts[2]}", "+", "unscanned", "file type is not scanned"))
                elif parts[0] == "-":
                    found.append((f"commit {short} {parts[2]}", "+", "unscanned", "binary file"))
        patch = git("-c", "core.quotepath=off", "show", "--format=", "--unified=0", "--no-color", "--no-ext-diff",
                    "--src-prefix=a/", "--dst-prefix=b/", sha, root=root)
        cur, in_header = "?", False
        for line in patch.splitlines():
            # A "+++ " line names the file only in a file header (after "diff --git", before the first "@@").
            # In a hunk it is an added line that starts with "++ ", and must be scanned like any other.
            if line.startswith(("diff --git ", "diff --cc ", "diff --combined ")):  # the last two: merge commits
                in_header = True
            elif line.startswith("@@"):
                in_header = False
            elif in_header and line.startswith("+++ "):
                name = line[4:].split("\t", 1)[0]
                if len(name) > 1 and name[0] == name[-1] == '"':
                    name = name[1:-1].replace('\\"', '"').replace("\\\\", "\\")
                cur = name[2:] if name.startswith("b/") else name
            elif line.startswith("+") and not cur.endswith(SKIP_SUFFIX) and not skipped(cur, allow):
                found += [(f"commit {short} {cur}", "+", k, v) for _, _, k, v in scan_text(line[1:], "", deny, allow, dod)]
    return found, len(shas)


def push_revs(stdin_text, root):
    """Turn pre-push stdin lines into rev-list argument lists (one per pushed ref)."""
    out = []
    for line in stdin_text.splitlines():
        parts = line.split()
        if len(parts) != 4 or ZERO.match(parts[1]):
            continue
        lsha, rsha = parts[1], parts[3]
        known = not ZERO.match(rsha) and subprocess.run(
            ["git", "cat-file", "-e", rsha + "^{commit}"], cwd=root, capture_output=True).returncode == 0
        out.append([f"{rsha}..{lsha}"] if known else [lsha, "--not", "--remotes"])
    return out


def report(found, what, deny, dod=False):
    for where, n, kind, val in found:
        print(f"pii-guard: {where}:{n}: {kind}: {val}")
    names = (f"names checked ({len(deny)} denylist entries, fingerprint {fingerprint(deny)})" if deny
             else "names NOT checked (no denylist)")
    print(f"PII GUARD {'FAIL' if found else 'PASS'}: {len(found)} finding(s) in {what}; {names}; "
          f"profile {'dod' if dod else 'minimum'}")
    return 1 if found else 0


def self_test():
    at, dot = "@", "."
    ok = True

    def expect(name, text, kinds, deny=(), allow=(), dod=False):
        nonlocal ok
        got = sorted({k for _, _, k, _ in scan_text(text, "t", list(deny), set(allow), dod)})
        good = got == sorted(kinds)
        print(("ok   " if good else "FAIL ") + f"{name}: {got}")
        ok = ok and good

    expect("personal email", "mail jane" + at + "corp" + dot + "io", ["email"])
    expect("github noreply allowed", "123+x" + at + "users.noreply.github" + dot + "com", [])
    expect("noreply allowed", "noreply" + at + "anthropic" + dot + "com", [])
    expect("example domain allowed", "a" + at + "example" + dot + "com", [])
    expect("placeholder t@t ignored", "t" + at + "t", [])
    expect("phone dashes", "call 555-123-" + "4567", ["phone"])
    expect("phone parens", "call (555) 123-" + "4567", ["phone"])
    expect("phone intl", "call +44 20 7946 " + "0958", ["phone"])
    expect("SSN shape", "id 123-45-" + "6789", ["id"])
    expect("SSN keyword", "SSN 123 45 " + "6789", ["id"])
    expect("date not a phone", "2026-11-11 10:00", [])
    expect("version not a phone", "v2.1.41 and 1.2.3.4", [])
    expect("unix time not an id", "ts 17312" + "34567", [])
    expect("sha not an id", "commit 0123456789abcdef0123456789abcdef01234567", [])
    expect("denylist name", "ask Alex" + "andra first", ["name"], deny=["Alexandra"])
    expect("denylist any case", "ALEX" + "ANDRA", ["name"], deny=["alexandra"])
    expect("denylist whole word", "Alexandra" + "s", [], deny=["Alexandra"])
    expect("allow list", "mail jane" + at + "corp" + dot + "io", [], allow=["jane" + at + "corp" + dot + "io"])
    expect("allow list is case-exact for findings", "mail jane" + at + "CORP" + dot + "io", ["email"], allow=["jane" + at + "corp" + dot + "io"])
    expect("skip line is not an allowed value", "mail jane" + at + "corp" + dot + "io", ["email"], allow=["skip: ref/x.txt"])
    good = not skipped("a.txt", {"skip: *"}) and not skipped("a/b.txt", {"skip: **"}) \
        and skipped("ref/x.txt", {"skip: ref/x.txt"}) and skipped("ref/a/b.txt", {"skip: ref/"}) \
        and skipped("ref/y.txt", {"skip: ref/*.txt"}) and not skipped("docs/x.txt", {"skip: ref/x.txt"})
    print(("ok   " if good else "FAIL ") + "skip: exact path, folder, glob; other paths still scanned")
    ok = ok and good
    expect("name inside an allowed host is not flagged", "https://acme" + dot + "example" + dot + "org/sites/x", [],
           deny=["ACME"], allow=["acme" + dot + "example" + dot + "org"])
    expect("allowed string matches in any case", "https://ACME" + dot + "EXAMPLE" + dot + "ORG/x", [],
           deny=["ACME"], allow=["acme" + dot + "example" + dot + "org"])
    expect("same name elsewhere on the line is flagged", "ACME team at acme" + dot + "example" + dot + "org", ["name"],
           deny=["ACME"], allow=["acme" + dot + "example" + dot + "org"])
    # Secret test values are built at run time, so this file holds no token shape itself.
    x36 = "A1b2C3d4E5" * 3 + "F6g7H8"
    for label, val in (("GitHub token", "gh" + "p_" + x36), ("GitHub fine-grained", "github" + "_pat_" + x36 * 2),
                       ("GitLab", "gl" + "pat-" + x36[:20]), ("AWS key id", "AK" + "IA" + "ABCDEFGHIJ234567"),
                       ("Anthropic", "sk" + "-ant-api03-" + x36), ("OpenAI", "sk" + "-proj-" + x36),
                       ("Google", "AI" + "za" + x36[:35]), ("Slack", "xo" + "xb-1234567890-" + x36[:12]),
                       ("Stripe", "sk" + "_live_" + x36[:24]),
                       ("private key", "-----BEGIN OPENSSH " + "PRIVATE KEY-----"),
                       ("RSA private key", "-----BEGIN RSA " + "PRIVATE KEY-----")):
        expect("secret: " + label, "token = " + val, ["secret"])
    expect("not a secret: short sk- word", "sk" + "-learn and task-runner", [])
    expect("not a secret: long kebab slug", "docs/sk" + "-" + "-".join(["setup", "guide", "for", "new", "projects", "today"]), [])
    expect("not a secret: public key header", "-----BEGIN " + "PUBLIC KEY-----", [])
    good = mask("secret", "gh" + "p_" + x36) == f"<{len(x36) + 4} chars>"
    print(("ok   " if good else "FAIL ") + "secrets print as a length only")
    ok = ok and good
    expect("allow list is exact", "call 555-123-" + "4567", ["phone"], allow=["call 555-123-" + "4567 now"])
    expect("URL path not a phone", "github.com/x/pull/123-456-" + "7890", [])
    expect("phone keyword, no separators", "tel: 555123" + "4567", ["phone"])
    expect("+1 packed", "+1555123" + "4567", ["phone"])
    expect("SSN keyword, no dashes", "SSN 123456" + "789", ["id"])
    expect("short name fully masked", "Sam", ["name"], deny=["Sam"])
    good = mask("name", "Sam") == "<3 chars>" and mask("email", "a" + at + "b" + dot + "io") == "***@****"
    print(("ok   " if good else "FAIL ") + "masking hides names and email users")
    ok = ok and good
    # DoD tier. Test values are built at run time, so this file holds no host, mark or ID shape itself.
    mil = "portal" + dot + "unit" + dot + "mi" + "l"
    for label, text in (("host", "see " + mil), ("URL", "https://" + mil + "/sites/x"),
                        ("host, upper case", "see " + mil.upper()), ("host at sentence end", "open " + mil + "."),
                        ("cloud tenant host", "x" + dot + "sharepoint-mi" + "l" + dot + "us/sites/y"),
                        ("cloud meeting host", "dod" + dot + "teams" + dot + "microsoft" + dot + "us")):
        expect("dod milhost: " + label, text, ["milhost"], dod=True)
    for label, text in (("wildcard", "*" + dot + "unit" + dot + "mi" + "l"), ("leading dot", "domain=" + dot + "unit" + dot + "mi" + "l"),
                        ("handle", at + "unit" + dot + "mi" + "l team")):
        expect("dod milhost: " + label, text, ["milhost"], dod=True)
    expect("minimum tier: host not checked", "see " + mil, [])
    expect("dod: mail address is one finding, kind email", "ann" + at + "unit" + dot + "mi" + "l", ["email"], dod=True)
    expect("dod: not a host: other domain after it", "x" + dot + "mi" + "l" + dot + "example" + dot + "org", [], dod=True)
    expect("dod: not a host: the words family and mil alone", "a family of 3 mil units", [], dod=True)
    expect("dod: allowed host", "see " + mil, [], allow=[mil], dod=True)
    expect("dod: allowed host in any case", "see " + mil.upper(), [], allow=[mil], dod=True)
    expect("dod: allowed host does not allow another host", "see other" + dot + "unit" + dot + "mi" + "l", ["milhost"], allow=[mil], dod=True)
    for label, text in (("banner", "CU" + "I//SP-PRVCY"), ("lone line", "  CU" + "I  "), ("long form", "Controlled Unclassified " + "Information"),
                        ("old mark", "UNCLASSIFIED/" + "/FO" + "UO"), ("old mark, long form", "For Official Use " + "Only"),
                        ("dissemination", "NOF" + "ORN"), ("classification banner", "TOP SECRET/" + "/SI")):
        expect("dod marking: " + label, text, ["marking"], dod=True)
    for label, text in (("in brackets", "(CU" + "I)"), ("bold", "**CU" + "I**"), ("heading", "# CU" + "I"),
                        ("bare banner", "TOP SEC" + "RET"), ("bare banner, one word", "  SEC" + "RET  ")):
        expect("dod marking: " + label, text, ["marking"], dod=True)
    for label, text in (("title-case banner with slashes", "Top Sec" + "ret/" + "/SI"), ("lower-case word with slashes", "sec" + "ret/" + "/rel"),
                        ("two-word banner, title case", "Top Sec" + "ret"), ("lowest level alone on a line", "UNCLASS" + "IFIED")):
        expect("dod marking: " + label, text, ["marking"], dod=True)
    expect("dod: a one-word heading in title case is not a mark", "# Sec" + "ret", [], dod=True)
    expect("dod: the word in a sentence, upper case, is not a banner", "THE SEC" + "RET IS OUT", [], dod=True)
    expect("minimum tier: marks not checked", "CU" + "I//SP-PRVCY", [])
    expect("dod: the acronym inside a sentence is not a mark", "the CU" + "I program office", [], dod=True)
    expect("dod: the word secret alone is not a mark", "a secret in the settings", [], dod=True)
    expect("dod id: keyword and 10 digits", "DoD ID: 12345" + "67890", ["dodid"], dod=True)
    expect("dod id: EDIPI", "EDIPI 12345" + "67890", ["dodid"], dod=True)
    expect("dod id: number, then keyword", "12345" + "67890 (DoD ID)", ["dodid"], dod=True)
    for label, text in (("underscore name", "dod_id=12345" + "67890"), ("underscore name, colon", "dod_id: 12345" + "67890"),
                        ("joined to the number", "DODID12345" + "67890"), ("wide space", "DoD   ID 12345" + "67890")):
        expect("dod id: " + label, text, ["dodid"], dod=True)
    expect("dod id: 11 digits are not an ID", "EDIPI 12345" + "678901", [], dod=True)
    good = profile_of({"Profile: DoD"}) == profile_of({"profile:dod"}) == profile_of({"profile :  dod"}) == "dod" \
        and profile_of({"profile: dodd"}) == profile_of({"profile: dod", "profile: min"}) == profile_of({"profile:"}) == "unknown" \
        and profile_of({"profile: d o d"}) == profile_of({"profile = dod"}) == profile_of({"profile dod"}) == "unknown" \
        and profile_of({"profil: dod"}) == profile_of({"tier=dod"}) == profile_of({"profile"}) == "unknown" \
        and all(profile_of({v}) == "unknown" for v in ("profile\uff1adod", "- profile: dod", "* profile: dod", '"profile: dod"',
                                                         "[profile: dod]", "$profile: dod", "profile; dod", "profile - dod",
                                                         "profile dod", "tier; dod", "'profile:dod'")) \
        and profile_of({"denylist: warn", "x", "profile.example.org", "profile-x", "profile/x", "host.dod", "a.dod",
                        "skip: a/dod", "skip: profile dod", "skip: dod", "skip:dod"}) == "minimum"
    print(("ok   " if good else "FAIL ") + "profile line: any case, spacing around the colon; any other form is unknown")
    ok = ok and good
    slow = 0.0  # no line, however long or odd, may make the option-line patterns slow
    hostile = [c * 100_000 + tail for c in "-_a. \t" for tail in ("", " dod", "dod")]
    hostile += ["a" + " " * 100_000, "- " + " " * 100_000 + "x", "a" + " " * 50_000 + "dod" + " " * 50_000 + "x",
                "profile" + " " * 100_000 + ": dod", "a" * 39 + ":" + " " * 100_000 + "dod"]
    hostile += [h[:n] for h in list(hostile) for n in (OPTION_MAX, OPTION_MAX - 1)]  # the longest lines the patterns see
    good = True
    for h in hostile:
        t0 = time.monotonic()
        good = profile_of({h}) != "dod" and is_option_line(h) in (True, False) and good
        slow = max(slow, time.monotonic() - t0)
    good = good and slow < 1
    print(("ok   " if good else "FAIL ") + f"option lines: {len(hostile)} long or odd lines, the slowest read in {slow:.3f} s")
    expect("dod id: a longer word that starts like the keyword is not one", "dodidentifier 12345" + "67890", [], dod=True)
    ok = ok and good
    expect("dod: 10 digits with no keyword", "ts 17312" + "34567", [], dod=True)
    expect("minimum tier: DoD ID not checked", "EDIPI 12345" + "67890", [])
    good = mask("milhost", mil) == f"<{len(mil)} chars>" and mask("dodid", "12345" + "67890") == "********90"
    print(("ok   " if good else "FAIL ") + "dod: hosts print as a length, IDs as the last 2 digits")
    ok = ok and good
    good = fingerprint(parse_denylist("Alex, Sam,River")) == fingerprint(parse_denylist("river\nSAM\nalex\nAlex")) \
        and fingerprint(["Alex"]) != fingerprint(["Sam"]) and re.fullmatch(r"[0-9a-f]{8}", fingerprint(["Alex"]))
    print(("ok   " if good else "FAIL ") + "fingerprint: same list in any order, case or separator; other list differs")
    ok = ok and good
    saved = {k: os.environ.pop(k, None) for k in ("PII_GUARD_DENYLIST", "PII_GUARD_DENYLIST_FILE")}
    try:
        os.environ["PII_GUARD_DENYLIST_FILE"] = os.devnull + ".missing"
        good = load_denylist() == [] and denylist_source()[1] is None
        os.environ["PII_GUARD_DENYLIST"] = "Alex,  Sam\n# note\nRiver"
        good = good and load_denylist() == ["Alex", "Sam", "River"] and "environment" in denylist_source()[1]
    finally:
        for k, v in saved.items():
            os.environ.pop(k, None)
            if v is not None:
                os.environ[k] = v
    good = good and parse_denylist("<Alex>, 'Sam' ,\"River\",<>,<a>,--") == ["Alex", "Sam", "River"]
    print(("ok   " if good else "FAIL ") + "denylist source: none, then environment (comma and newline); <Name> wrappers dropped")
    ok = ok and good
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d, "deny.txt")
        f.write_text("Alex\n")
        env = {k: v for k, v in os.environ.items() if not k.startswith(("PII_GUARD", "GIT_"))}
        env["PII_GUARD_DENYLIST_FILE"] = str(f)
        env["PII_GUARD_DENYLIST"] = "# only a comment"
        me = [sys.executable, os.path.abspath(__file__)]
        r = subprocess.run(me + ["--status"], env=env, capture_output=True, text=True)
        good = r.returncode == 0 and "1 entries from file" in r.stdout and "Alex" not in r.stdout
        print(("ok   " if good else "FAIL ") + "comment-only env var does not shadow the file; status hides names")
        ok = ok and good
        env["PII_GUARD_DENYLIST_FILE"] = str(f) + ".missing"
        subprocess.run(["git", "init", "-q", "-b", "main"], cwd=d, check=True, capture_output=True)
        z = "0" * 40
        r = subprocess.run(me + ["--push", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True,
                           input=f"refs/heads/main {'1' * 40} refs/heads/main {z}\n")
        good = r.returncode == 1 and "no denylist" in r.stdout
        print(("ok   " if good else "FAIL ") + "push with no denylist: blocked")
        ok = ok and good
        r = subprocess.run(me + ["--push", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True,
                           input=f"(delete) {z} refs/heads/x {'1' * 40}\n")
        good = r.returncode == 0
        print(("ok   " if good else "FAIL ") + "branch delete with no denylist: passes")
        ok = ok and good
        pathlib.Path(d, ".pii-guard").write_text("# starter\ndenylist: warn\n")
        r = subprocess.run(me + ["--all", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True)
        good = r.returncode == 0 and "WARNING" in r.stdout and warn_mode(d)
        pathlib.Path(d, "a.txt").write_text("mail bob" + at + "corp" + dot + "io\n")
        subprocess.run(["git", "add", "a.txt"], cwd=d, check=True, capture_output=True)
        r = subprocess.run(me + ["--all", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True)
        good = good and r.returncode == 1
        print(("ok   " if good else "FAIL ") + "denylist: warn: no denylist only warns; an email still blocks")
        ok = ok and good
        pathlib.Path(d, "a.txt").write_text("clean\n")
        pathlib.Path(d, ".pii-guard").write_text("denylist: warn\nprofile: dod\n")
        r = subprocess.run(me + ["--all", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True)
        good = r.returncode == 1 and "no denylist" in r.stdout and dod_mode(d) and not warn_mode(d)
        print(("ok   " if good else "FAIL ") + "dod: no denylist blocks although the file says denylist: warn")
        ok = ok and good
        env["PII_GUARD_DENYLIST"] = "Alex"
        pathlib.Path(d, ".pii-guard").write_text("profile: DOD-tier\n")
        r = subprocess.run(me + ["--all"], cwd=d, env=env, capture_output=True, text=True)
        r2 = subprocess.run(me + ["--status"], cwd=d, env=env, capture_output=True, text=True)
        good = r.returncode == 1 and "PII GUARD FAIL: unknown profile" in r.stdout and r2.returncode == 1 \
            and "UNKNOWN" in r2.stdout and dod_mode(d) and not warn_mode(d)
        print(("ok   " if good else "FAIL ") + "unknown profile value: the scan and --status fail (no fall back to minimum)")
        ok = ok and good
        pathlib.Path(d, ".pii-guard").write_bytes(b"\xef\xbb\xbfprofile: dod\r\n")
        r = subprocess.run(me + ["--status"], cwd=d, env=env, capture_output=True, text=True)
        subprocess.run(["git", "add", ".pii-guard"], cwd=d, check=True, capture_output=True)
        staged = load_allow(d, ":0")  # the same file read through git, as --allow-from does
        good = r.returncode == 0 and "profile: dod" in r.stdout and dod_mode(d) and profile_of(staged) == "dod"
        subprocess.run(["git", "rm", "-q", "--cached", ".pii-guard"], cwd=d, check=True, capture_output=True)
        print(("ok   " if good else "FAIL ") + "tier line after a byte-order mark, with CRLF: DoD tier (file and git read)")
        ok = ok and good
        cases = {"UTF-16 with a byte-order mark": "profile: dod\n".encode("utf-16"), "UTF-16, no mark": "profile: dod\n".encode("utf-16-le"),
                 "bytes that are not UTF-8": b"# note \xc3(\n", "a NUL byte": b"x\0y\n"}
        for label, raw in cases.items():
            pathlib.Path(d, ".pii-guard").write_bytes(raw)
            r = subprocess.run(me + ["--all"], cwd=d, env=env, capture_output=True, text=True)
            subprocess.run(["git", "add", ".pii-guard"], cwd=d, check=True, capture_output=True)
            good = r.returncode == 1 and "PII GUARD FAIL: unknown profile" in r.stdout and "Traceback" not in r.stderr \
                and profile_of(load_allow(d, ":0")) == "unknown"
            subprocess.run(["git", "rm", "-q", "--cached", ".pii-guard"], cwd=d, check=True, capture_output=True)
            print(("ok   " if good else "FAIL ") + f".pii-guard with {label}: the scan fails (file and git read)")
            ok = ok and good
        pathlib.Path(d, ".pii-guard").write_text("\u200bprofile: dod\n", encoding="utf-8")
        good = profile_of(load_allow(d)) == "dod"
        print(("ok   " if good else "FAIL ") + "tier line after a zero-width space: DoD tier")
        ok = ok and good
        pathlib.Path(d, ".pii-guard").write_text("denylist: warn\nProfile:DoD\n")
        r = subprocess.run(me + ["--status"], cwd=d, env=env, capture_output=True, text=True)
        good = r.returncode == 0 and "fingerprint " + fingerprint(["alex"]) in r.stdout and "profile: dod" in r.stdout
        print(("ok   " if good else "FAIL ") + "status: fingerprint and profile")
        ok = ok and good
        pathlib.Path(d, "doc.pdf").write_bytes(b"%PDF-1.4 x")
        pathlib.Path(d, "blob.dat").write_bytes(b"a\0b")
        pathlib.Path(d, "notes.txt").write_text("see " + mil + "\n")
        subprocess.run(["git", "add", "a.txt", "doc.pdf", "blob.dat", "notes.txt"], cwd=d, check=True, capture_output=True)
        r = subprocess.run(me + ["--all"], cwd=d, env=env, capture_output=True, text=True)
        good = r.returncode == 1 and r.stdout.count("unscanned") == 2 and "milhost" in r.stdout and "profile dod" in r.stdout \
            and mil not in r.stdout
        print(("ok   " if good else "FAIL ") + "dod --all: a PDF, a binary file and a host block")
        ok = ok and good
        pathlib.Path(d, ".pii-guard").write_text("profile: dod\nskip: doc.pdf\nskip: blob.dat\n" + mil + "\n")
        r = subprocess.run(me + ["--all"], cwd=d, env=env, capture_output=True, text=True)
        good = r.returncode == 0
        print(("ok   " if good else "FAIL ") + "dod --all: skip lines and an allowed host clear them")
        ok = ok and good
        pathlib.Path(d, ".pii-guard").write_text("# minimum\n")
        r = subprocess.run(me + ["--all"], cwd=d, env=env, capture_output=True, text=True)
        good = r.returncode == 0 and "profile minimum" in r.stdout
        print(("ok   " if good else "FAIL ") + "minimum --all: the same files pass")
        ok = ok and good
        idn = ["-c", "user.name=t", "-c", "user.email=1+t" + at + "users.noreply.github" + dot + "com"]
        subprocess.run(["git", *idn, "commit", "-q", "-m", "files"], cwd=d, check=True, capture_output=True)
        found, _ = scan_commits(["HEAD"], d, [], set(), dod=True)
        got = sorted((w.split()[-1], k) for w, _, k, _ in found)
        good = got == [("blob.dat", "unscanned"), ("doc.pdf", "unscanned"), ("notes.txt", "milhost")]
        found, _ = scan_commits(["HEAD"], d, [], {"skip: doc.pdf", "skip: blob.dat", mil}, dod=True)
        good = good and found == [] and scan_commits(["HEAD"], d, [], set())[0] == []
        print(("ok   " if good else "FAIL ") + f"dod commits: binary and PDF files block; skip clears; minimum passes: {got}")
        ok = ok and good
        pathlib.Path(d, "big.txt").write_text("clean line\n" * (MAX_BYTES // 11 + 10))
        subprocess.run(["git", "add", "big.txt"], cwd=d, check=True, capture_output=True)
        subprocess.run(["git", *idn, "commit", "-q", "-m", "big"], cwd=d, check=True, capture_output=True)
        found, _ = scan_commits(["HEAD~1..HEAD"], d, [], set(), dod=True)
        good = [(w.split()[-1], k) for w, _, k, _ in found] == [("big.txt", "unscanned")] \
            and scan_commits(["HEAD~1..HEAD"], d, [], {"skip: big.txt"}, dod=True)[0] == []
        print(("ok   " if good else "FAIL ") + "dod commits: a text file over the size limit blocks; skip clears")
        ok = ok and good
    with tempfile.TemporaryDirectory() as d:
        env = {**os.environ, "GIT_AUTHOR_NAME": "Sam", "GIT_COMMITTER_NAME": "Sam",
               "GIT_AUTHOR_EMAIL": "1+s" + at + "users.noreply.github" + dot + "com",
               "GIT_COMMITTER_EMAIL": "1+s" + at + "users.noreply.github" + dot + "com"}
        for k in [k for k in env if k.startswith("GIT_") and k not in (
                "GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL")]:
            env.pop(k)
        run = lambda *a: subprocess.run(["git", *a], cwd=d, env=env, check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        pathlib.Path(d, "a.txt").write_text("clean\n")
        run("add", "."); run("commit", "-q", "-m", "clean")
        base = git("rev-parse", "HEAD", root=d).strip()
        pathlib.Path(d, "a.txt").write_text("clean\nmail bob" + at + "corp" + dot + "io\n")
        run("add", "."); run("commit", "-q", "-m", "ask Alexandra")
        found, n = scan_commits([f"{base}..HEAD"], d, ["Alexandra"], set())
        kinds = sorted(k for _, _, k, _ in found)
        good = n == 1 and kinds == ["email", "name"]
        print(("ok   " if good else "FAIL ") + f"commit range: {n} commit(s), {kinds}")
        ok = ok and good
        mid = git("rev-parse", "HEAD", root=d).strip()
        pathlib.Path(d, "a.txt").write_text("clean\nmail bob" + at + "corp" + dot + "io\n++ x\nmail sue" + at + "corp" + dot + "io\n")
        run("add", "."); run("commit", "-q", "-m", "plus lines")
        found, _ = scan_commits([f"{mid}..HEAD"], d, [], {"skip: x"})
        good = [k for _, _, k, _ in found] == ["email"] and all(" a.txt" in w for w, _, _, _ in found)
        print(("ok   " if good else "FAIL ") + f"added '++ ' line is content, not a file header: {[k for _, _, k, _ in found]}")
        ok = ok and good
        run("checkout", "-q", "-b", "side", mid)
        pathlib.Path(d, "c.txt").write_text("side\n")
        run("add", "."); run("commit", "-q", "-m", "side")
        run("checkout", "-q", "main")
        pathlib.Path(d, "c.txt").write_text("main\n")
        run("add", "."); run("commit", "-q", "-m", "main c")
        subprocess.run(["git", "merge", "-q", "side"], cwd=d, env=env, capture_output=True)
        pathlib.Path(d, "c.txt").write_text("both\nmail ann" + at + "corp" + dot + "io\n")
        run("add", "."); run("commit", "-q", "-m", "merge side")
        found_skip, _ = scan_commits(["HEAD~1..HEAD"], d, [], {"skip: c.txt"})
        found_all, _ = scan_commits(["HEAD~1..HEAD"], d, [], set())
        good = found_skip == [] and [(w.split()[-1], k) for w, _, k, _ in found_all] == [("c.txt", "email")]
        print(("ok   " if good else "FAIL ") + f"merge commit (diff --cc): file name kept, skip rule applies: {len(found_skip)}, {len(found_all)}")
        ok = ok and good
        env["GIT_AUTHOR_EMAIL"] = "me" + at + "home" + dot + "net"
        run("commit", "-q", "--allow-empty", "-m", "x")
        found, _ = scan_commits(["HEAD~1..HEAD"], d, [], set())
        good = [k for _, _, k, _ in found] == ["email"]
        print(("ok   " if good else "FAIL ") + f"author email: {[k for _, _, k, _ in found]}")
        ok = ok and good
        z = "0" * 40
        head = git("rev-parse", "HEAD", root=d).strip()
        revs = push_revs(f"refs/heads/main {head} refs/heads/main {z}\n(delete) {z} refs/heads/x {head}\n", d)
        good = revs == [[head, "--not", "--remotes"]]
        print(("ok   " if good else "FAIL ") + f"push lines: {revs}")
        ok = ok and good
    print("PII GUARD TEST " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--all", action="store_true", help="scan every tracked file")
    ap.add_argument("--range", help="scan commits in this range (A..B)")
    ap.add_argument("--push", action="store_true", help="pre-push mode: read the hook's stdin")
    ap.add_argument("--allow-from", metavar="REF", help="read .pii-guard from this git ref (CI: the PR base), not the tree")
    ap.add_argument("--require-denylist", action="store_true", help="fail when no name denylist is found")
    ap.add_argument("--status", action="store_true", help="print the denylist source and entry count, never the names")
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    if a.test:
        return self_test()
    if a.status:
        raw, src = denylist_source()
        deny = load_denylist()
        n = len(deny)
        try:
            top = git("rev-parse", "--show-toplevel").strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            top = "."
        print(f"denylist: {n} entries from {src}; fingerprint {fingerprint(deny)}" if src and n
              else "denylist: none (" + MISSING_HELP + ")")
        prof = profile_of(load_allow(top))
        print("profile: " + (prof if prof != "unknown" else "UNKNOWN (" + UNKNOWN_PROFILE + ")"))
        return 0 if n and prof != "unknown" else 1
    if not (a.files or a.all or a.range or a.push):
        ap.error("give --all, --range, --push, --status or files")
    try:
        root = git("rev-parse", "--show-toplevel").strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        root = "."
    deny, allow = load_denylist(), load_allow(root, a.allow_from)
    prof = profile_of(allow)
    if prof == "unknown":
        print("PII GUARD FAIL: " + UNKNOWN_PROFILE)
        return 1
    dod = prof == "dod"
    warn_only = WARN_OPTION in allow and not dod
    allow = {v for v in allow if not is_option_line(v)}
    revsets = [[a.range]] if a.range else []
    if a.push:
        revsets += push_revs(sys.stdin.read(), root)
    deletes_only = a.push and not revsets and not (a.all or a.files or a.range)
    if a.require_denylist and not deny and not deletes_only:
        if not warn_only:
            print("PII GUARD FAIL: " + MISSING_HELP)
            return 1
        print("PII GUARD WARNING: names are not checked (.pii-guard has 'denylist: warn'); every other check runs. "
              + MISSING_HELP)
    found, what = [], []
    if a.all:
        files = git("ls-files", "-z", root=root).split("\0")
        found += scan_files([f for f in files if f], root, deny, allow, dod)
        what.append(f"{len([f for f in files if f])} tracked files")
    if a.files:
        rel = [os.path.relpath(os.path.abspath(f), root) for f in a.files]
        found += scan_files(rel, root, deny, allow, dod)
        what.append(f"{len(a.files)} file(s)")
    n = 0
    for revs in revsets:
        f, k = scan_commits(revs, root, deny, allow, dod)
        found += f
        n += k
    if revsets:
        what.append(f"{n} commit(s)")
    skips = sorted(a[5:].strip() for a in allow if a.startswith("skip:"))
    if skips:
        what.append(f"{len(skips)} skip rule(s): {', '.join(skips)}")
    return report(found, ", ".join(what) or "nothing", deny, dod)


if __name__ == "__main__":
    sys.exit(main())
