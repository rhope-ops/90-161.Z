"""The scanner of pii_guard.py: the patterns, the denylist and .pii-guard readers, and the scans of a text, of files
and of commits.

Inputs: text, repo-relative paths or git rev-list arguments; the denylist (environment or file) and .pii-guard.
Outputs: findings as (where, line number, kind, masked value) tuples; nothing is printed here.
Run: not run alone; pii_guard.py, pii_guard_hook.py and pii_guard_test.py import it (the checks, tiers and limits
are described in the pii_guard.py header).
"""
import bisect
import fnmatch
import hashlib
import itertools
import os
import pathlib
import re
import subprocess
import unicodedata

ZERO = re.compile(r"^0+$")
# EMAIL is the pattern; emails() finds its matches. A plain EMAIL.finditer tries every start of a long run of
# local-part characters, so its time grows with the square of the run (200 KB took 26 s, longer than the hook timeout).
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
_LOCAL = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._%+-")


def emails(line):
    """The matches of EMAIL.finditer (leftmost, non-overlapping) in linear time. A local part cannot hold an "@", so
    each match ends its local part at one "@": walk the "@" signs in order, start the local part at the start of its
    run (not before the end of the last match), and match once from there."""
    pos, at = 0, line.find("@")
    while at != -1:
        start = at
        while start > pos and line[start - 1] in _LOCAL:
            start -= 1
        m = EMAIL.match(line, start) if start < at else None
        if m:
            yield m
            pos = m.end()
            at = line.find("@", pos)
        else:
            at = line.find("@", at + 1)


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
    r"(?i)(?<![A-Za-z0-9])(?:(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+mil(?![A-Za-z0-9-]|\.[A-Za-z0-9])"   # any host under the military domain
    r"|(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*sharepoint-mil\.us\b|dod\.teams\.microsoft\.us\b)")    # DoD cloud tenant hosts
# A DNS label is 1-63 letters, digits or inside hyphens, so "word-" + ".mil" is not a host (the length cap stops runaway backtracking on long "a-a-a-" runs).
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


# MILHOST is the pattern; milhosts() finds its matches. A plain MILHOST.finditer tries every start after a "." or
# "-" and reads to the end of the run of labels, so its time grows with the square of the run ("a." * 5,000 took
# 1.2 s, 20,000 took 17.6 s). The pattern itself stays as it is (owner decision 2A, 2026-11-16).
_MIL_REGION = re.compile(r"(?i)[a-z0-9.-]+")  # a match holds only these characters, so it lies inside one run of them
_MIL_ANY = re.compile(r"(?i)mil|sharepoint-mil\.us|dod\.teams\.microsoft\.us")  # every match holds one of these
_MIL_END = re.compile(r"(?i)(?<=\.)mil(?![A-Za-z0-9-]|\.[A-Za-z0-9])")  # where the first branch can end
_MIL_SPM = re.compile(r"(?i)sharepoint-mil\.us\b")  # where the second branch can end
_MIL_DOD = re.compile(r"(?i)dod\.teams\.microsoft\.us\b")  # the third branch
_MIL_SHORT = 24  # a run this short goes to the pattern: its cost per run is small and fixed, below the model's set-up


def _milhost_model(line, r0, r1):
    """The anchors of one run of label characters (line[r0:r1]) for _milhost_walk: the segments between dots, their
    starts, the segments that stop a chain of labels, the segments where the first and second branch can end, and the
    starts and ends of matches with no label. Returns them as a tuple."""
    segs = line[r0:r1].split(".")
    n = len(segs)
    pos = list(itertools.accumulate(map((1).__add__, map(len, segs)), initial=r0))  # pos[j]: start of segment j
    # stops: the segments that are not a whole label followed by "." (the last segment never is one)
    stops = [j for j, g in enumerate(segs) if not (0 < len(g) <= 63 and g[0] != "-" and g[-1] != "-")]
    if stops[-1:] != [n - 1]:
        stops.append(n - 1)
    end1 = {bisect.bisect_right(pos, m.start()) - 1 for m in _MIL_END.finditer(line, r0, r1 + 2)}
    end2, zero_end = [], {}  # end2: segments that are "sharepoint-mil" ("us" follows); zero_end: start -> end of a match with no label
    for rx in (_MIL_SPM, _MIL_DOD):
        for m in rx.finditer(line, r0, r1 + 2):
            s = m.start()
            if s == r0 or line[s - 1] in ".-":
                zero_end[s] = m.end()
                if rx is _MIL_SPM and (s == r0 or line[s - 1] == "."):
                    end2.append(bisect.bisect_right(pos, s) - 1)
    zero = sorted(zero_end)
    chain = sorted(end1.union(end2))  # anchors a chain of labels can reach
    return segs, pos, stops, end1, end2, zero_end, zero, chain


def _milhost_walk(line, r0, model):
    """Yield the (start, end) of each match in one run, leftmost first, from the anchors _milhost_model gives."""
    segs, pos, stops, end1, end2, zero_end, zero, chain = model
    p, ci, zi = r0, 0, 0
    while True:
        best = None
        while ci < len(chain):  # the first chain anchor after p with a start at or after p gives the leftmost start
            k = chain[ci]
            if pos[k] > p:
                j = bisect.bisect_left(stops, k)  # segments stops[j - 1] .. k - 1 reach k; stops[j] ends their run
                i = max(stops[j - 1] if j else 0, bisect.bisect_right(pos, p) - 1)
                while i < k and best is None:  # at most 3 segments: the one at p, a run start, a whole label
                    g = segs[i]
                    if g and g[-1] != "-":
                        for x in range(max(0, len(g) - 63, p - pos[i]), len(g)):
                            if g[x] != "-" and (x == 0 or g[x - 1] == "-"):
                                best = pos[i] + x
                                break
                    i += 1
                if best is not None:  # the farthest end in the run: first branch, else second branch
                    stop = stops[j]
                    if stop in end1:
                        e = pos[stop] + 3
                    elif stop - 1 in end1:
                        e = pos[stop - 1] + 3
                    else:
                        e = pos[end2[bisect.bisect_left(end2, stop) - 1] + 1] + 2
                    break
            ci += 1
        while zi < len(zero) and zero[zi] < p:
            zi += 1
        if zi < len(zero) and (best is None or zero[zi] < best):  # it starts no chain, else best would be <= it
            best = zero[zi]
            e = zero_end[best]
        if best is None:
            break
        yield best, e
        p = e


def _milhost_spans(line):
    """The spans of MILHOST.finditer(line), from a model of the pattern. A match lies in one run of label characters.
    Split the run at its dots into segments. A match starts where the look-behind allows (at a segment start or after
    a "-"); its first label is the rest of that segment, each later label is a whole segment (1-63 characters, no "-"
    at either end) followed by "."; it ends at the farthest end of the first branch it reaches (_MIL_END), else of the
    second (_MIL_SPM), else it is the third branch (_MIL_DOD). finditer takes the leftmost start at or after the end of
    the last match. Only anchors (ends) and segment indices are visited, so the time is linear in the line."""
    for region in _MIL_REGION.finditer(line):
        r0, r1 = region.span()
        if r1 - r0 <= _MIL_SHORT:
            yield from (m.span() for m in MILHOST.finditer(line, r0, r1 + 2))  # it sees the 2 characters after the run
            continue
        if _MIL_ANY.search(line, r0, r1):
            yield from _milhost_walk(line, r0, _milhost_model(line, r0, r1))


def milhosts(line):
    """The matches of MILHOST.finditer(line) in linear time: each span of _milhost_spans, confirmed by the pattern in
    a window of the span and the 2 characters its look-aheads read. If the pattern does not confirm a span, or a span
    starts before the end of the last confirmed match (no real or random line in the tests does either), the plain
    pattern finds the rest of the line from that end. It does not recover a match before that end, and it catches no
    model error that every later span passes (a skipped match, a match that starts too late, a missed last match);
    the differential tests prove the model."""
    done = 0  # the end of the last confirmed match
    for s, e in _milhost_spans(line):
        m = MILHOST.match(line, s, e + 2)
        if s < done or m is None or m.end() != e:
            yield from MILHOST.finditer(line, done)
            return
        yield m
        done = e


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
    """True when this .pii-guard line is a tier line, in any form (short lines only)."""
    return len(v) <= OPTION_MAX and bool(PROFILE_LINE.match(v))


def is_option_line(v):
    """True when this .pii-guard line is an option line (tier or denylist), never an allowed value."""
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
    """The denylist entries from the first source that has any, or []."""
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


def _inside(spans):
    """A test for "the span (s, e) lies inside one of these spans", in log time: one sort, then a binary search over
    the starts and a running maximum of the ends (spans may overlap). A plain any() was quadratic on long lines."""
    spans = sorted(spans)
    starts = [a for a, _ in spans]
    reach, best = [], -1
    for _, b in spans:
        best = max(best, b)
        reach.append(best)

    def test(s, e):
        """True when the span (s, e) lies inside one of the spans."""
        i = bisect.bisect_right(starts, s) - 1
        return i >= 0 and reach[i] >= e
    return test


def scan_text(text, where, deny, allow, dod=False):
    """Return findings (where, line_no, kind, masked) for one text. dod: also run the DoD checks."""
    found = []
    name_re = re.compile(r"(?i)(?<![A-Za-z0-9])(" + "|".join(re.escape(w) for w in deny) + r")(?![A-Za-z0-9])") if deny else None
    # Compiled once per call, used only on a line with a name hit (one finditer per allow line per line was slow).
    allow_res = [re.compile(re.escape(v), re.IGNORECASE) for v in allow if not v.startswith("skip:")] if name_re else []
    hosts_ok = {v.lower() for v in allow} if dod else set()  # a host name has no case
    for n, line in enumerate(text.splitlines(), 1):
        hits = []
        for m in emails(line):
            if not ALLOWED_EMAIL.search(m.group()):
                hits.append(("email", m.group()))
        for rx in SECRET:
            hits += [("secret", m.group()) for m in rx.finditer(line)]
        for rx in PHONE:
            hits += [("phone", m.group(m.lastindex or 0).strip(" .-")) for m in rx.finditer(line)]  # allow lines are stripped
        hits += [("id", m.group()) for m in SSN.finditer(line)]
        hits += [("id", m.group(1)) for m in SSN_KW.finditer(line)]
        if dod:
            in_mail = _inside(m.span() for m in emails(line))  # the host of a mail address is part of that finding
            hits += [("milhost", m.group()) for m in milhosts(line) if not in_mail(m.start(), m.end())]
            for rx in DODID:
                hits += [("dodid", m.group(1)) for m in rx.finditer(line)]
            for rx in MARKING:
                hits += [("marking", m.group().strip()) for m in rx.finditer(line)]
        names = list(name_re.finditer(line)) if name_re else []
        if names:
            in_allowed = _inside((s.start(), s.end()) for rx in allow_res for s in rx.finditer(line))
            hits += [("name", m.group(1)) for m in names
                     if not in_allowed(m.start(1), m.end(1))]  # inside an allowed string
        seen = set()  # values already reported on this line, of any kind (a set: a list scan was quadratic)
        for kind, val in hits:
            if val in allow or (kind == "milhost" and val.lower() in hosts_ok) or val in seen:
                continue
            seen.add(val)
            found.append((where, n, kind, mask(kind, val)))
    return found


def git(*args, root="."):
    """Run git in root and return its stdout as text; a git error raises CalledProcessError."""
    return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True,
                          errors="replace").stdout


def scan_files(paths, root, deny, allow, dod=False, named=False):
    """dod, or named (the caller named these files: FILE mode, the hook): a file that cannot be scanned is a finding
    (kind unscanned) unless a `skip:` line names it."""
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
            if dod or named:
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
        unscanned = set()  # dod: files already reported as unscanned; their patch lines are not scanned again
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
                    unscanned.add(parts[2])
                    found.append((f"commit {short} {parts[2]}", "+", "unscanned", f"larger than {MAX_BYTES} bytes"))
                elif parts[2].lower().endswith(SKIP_SUFFIX):
                    found.append((f"commit {short} {parts[2]}", "+", "unscanned", "file type is not scanned"))
                elif parts[0] == "-":
                    found.append((f"commit {short} {parts[2]}", "+", "unscanned", "binary file"))
        patch = git("-c", "core.quotepath=off", "show", "--format=", "--unified=0", "--no-color", "--no-ext-diff",
                    "--src-prefix=a/", "--dst-prefix=b/", sha, root=root)
        cur, in_header, added = "?", False, []

        def flush():  # one scan per file, not one per added line (a large file has many lines)
            if added and not cur.endswith(SKIP_SUFFIX) and cur not in unscanned and not skipped(cur, allow):
                found.extend((f"commit {short} {cur}", "+", k, v) for _, _, k, v in scan_text("\n".join(added), "", deny, allow, dod))
            added.clear()

        for line in patch.splitlines():
            # A "+++ " line names the file only in a file header (after "diff --git", before the first "@@").
            # In a hunk it is an added line that starts with "++ ", and must be scanned like any other.
            if line.startswith(("diff --git ", "diff --cc ", "diff --combined ")):  # the last two: merge commits
                flush()
                in_header = True
            elif line.startswith("@@"):
                in_header = False
            elif in_header and line.startswith("+++ "):
                name = line[4:].split("\t", 1)[0]
                if len(name) > 1 and name[0] == name[-1] == '"':
                    name = name[1:-1].replace('\\"', '"').replace("\\\\", "\\")
                cur = name[2:] if name.startswith("b/") else name
            elif line.startswith("+"):
                added.append(line[1:])
        flush()
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
