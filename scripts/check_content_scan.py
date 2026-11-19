"""The scanner of check_content.py: the patterns, the readers of the word lists (names, terms) and of the settings
file (`.check`; the old name `.pii-guard` is still read), and the scans of a text, of files and of commits.

Inputs: text, repo-relative paths or git rev-list arguments; the word lists (environment or file) and the settings file.
Outputs: findings as (where, line number, kind, masked value) tuples; nothing is printed here.
Run: not run alone; check_content.py, check_content_hook.py and check_content_test.py import it (the checks, tiers and limits
are described in the check_content.py header). The patterns and finders of each finding kind: check_content_finders.py.

A project's own finders (the extension point): when the file scripts/check_content_local.py stands next to this one,
the scanner loads it. The kit has no such file, and the kit's own patterns stay the default. The module defines one
or both of these names (a kind is one of email, secret, phone, id, milhost, dodid, marking):
    REPLACE = {kind: [finder, ...]}   these finders take the place of the kit's finders for that kind (at least one)
    ADD     = {kind: [finder, ...]}   these finders run after the finders of that kind
    finder(line) -> an iterable of (start, end, value): the span of each match in the line of text, and the text
                    that is the finding (it is masked in the output and compared with the allowed strings)
The kinds milhost, dodid and marking run only in the DoD tier, whoever finds them. The module must not import this
scanner when it is loaded (its own self-test may); `python3 scripts/check_content_local.py --test` is that self-test,
and scripts/check.sh runs it when the file has one. A module that cannot be imported, or that has neither name in this
shape, makes every scan fail (LOCAL_ERROR; scan_text raises LocalError) and the hook block: the scanner never falls
back to the kit's patterns, and never to no check. The result line of a scan and --status say when a module is active.
Network: none (it runs local git read commands).
Writes: none.
Credentials: none; it reads the name denylist and the terms list from an environment variable or a file.
"""
import bisect
import fnmatch
import hashlib
import os
import pathlib
import re
import subprocess
import unicodedata

import check_content_finders as finders_mod   # scripts/check_content_finders.py: the patterns, the kit's finders, the loader
from check_content_finders import LocalError, emails   # noqa: F401 - LocalError is part of this module's interface

ZERO = re.compile(r"^0+$")
LOCAL_FILE = pathlib.Path(__file__).resolve().parent / finders_mod.LOCAL_NAME   # a project's own finders (see the header)
FINDERS, LOCAL, LOCAL_ERROR = None, "", None   # the finders in use, the note for the result line, why they cannot be used


def use_local(path=None):
    """Set the finders in use: the kit's, with the project's own module at `path` applied when that file exists
    (None = LOCAL_FILE). A module that cannot be used sets LOCAL_ERROR, and then every scan_text call raises."""
    global FINDERS, LOCAL, LOCAL_ERROR
    try:
        (FINDERS, LOCAL), LOCAL_ERROR = finders_mod.load_local(path or LOCAL_FILE), None
    except LocalError as err:
        FINDERS, LOCAL, LOCAL_ERROR = None, "", f"{err}. Correct or remove that file: no scan runs until then"


use_local()
SKIP_SUFFIX = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".zip", ".gz", ".woff", ".woff2", ".ttf")
MAX_BYTES = 2_000_000


def mask(kind, s):
    """Show the kind and a length, never enough to rebuild the value (CI logs may be public)."""
    if kind in ("unscanned", "blocked"):
        return s  # a reason, not a value
    if kind in ("name", "term", "secret", "milhost", "marking"):
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
    first_use_check.py imports this, so both scripts agree on what counts as a denylist.

    Returns:
        (raw text, where it came from), or ("", None).
    """
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


def terms_source():
    """Return (raw text, where it came from) for the PFM's own blocked terms (words that are not personal data:
    a client, a code name), or ("", None). Same format and places as the name denylist, under other names; optional.

    Returns:
        (raw text, where it came from), or ("", None).
    """
    raw = os.environ.get("CHECK_TERMS", "")
    if parse_denylist(raw):
        return raw, "environment variable CHECK_TERMS"
    path = os.environ.get("CHECK_TERMS_FILE") or os.path.expanduser("~/.config/check/terms.txt")
    try:
        text = pathlib.Path(path).read_text(errors="replace") if os.path.isfile(path) else ""
    except OSError:
        text = ""
    if parse_denylist(text):
        return text, "file " + path
    return "", None


def load_terms():
    """The PFM's blocked terms from the first source that has any, or []."""
    return parse_denylist(terms_source()[0])


MISSING_HELP = ("no denylist found. Add your names (comma or newline separated), never in a repo or a chat: "
                "a cloud session: environment variable PII_GUARD_DENYLIST in the cloud environment's settings; "
                "GitHub Actions: repository secret PII_GUARD_DENYLIST; your computer: ~/.config/pii-guard/denylist.txt. "
                "See docs/FIRST_USE.md.")


WARN_OPTION = "denylist: warn"  # settings option line; first_use_check.py reads it too


# A tier line, also in a wrong form. After any leading punctuation (a bullet, a quote, a bracket):
#   - the word profile, unless a character of a name follows it (profile.example.org and profile-x stay allowed values);
#   - or one word, at most one punctuation mark, and the value dod (a misspelt key such as "profil: dod").
# Every form other than `profile: dod` is unknown and fails the scan.
_TIER = r"[\W_]*(?:profile(?![A-Za-z0-9._/-])|(?!skip\b|block\b|denylist\b)[A-Za-z_-]{1,40}\s*[^\w\s.]?\s*dod[\W_]*$)"
PROFILE_LINE = re.compile(r"(?i)^" + _TIER)
# A setting of the code standard or the audit (`code-max-file-lines: 600`, `audit-ignore: ref/**`): `code-` or `audit-`,
# a key and a colon. scripts/check_settings.py reads these lines; here they are option lines and never tier lines.
SETTING_LINE = re.compile(r"(?i)^(?:code|audit)-[A-Za-z0-9_-]+\s*:")
OPTION_LINE = re.compile(r"(?i)^(?:" + _TIER + r"|denylist\s*:)")  # option lines, never allowed values
OPTION_MAX = 200  # a longer line is never an option line: the patterns above only ever see short lines (no slow match)


MAX_BYTES_LINE = re.compile(r"(?i)^content-max-bytes\s*:\s*([0-9]{1,9})\s*$")
MAX_BYTES_CEILING = 50_000_000  # a larger value is ignored: the scan of one file must stay fast


def max_bytes_of(allow):
    """The size limit of one scanned file: the `content-max-bytes: <number>` line of the settings file, else MAX_BYTES.

    A project raises it so that its large text files are scanned instead of reported as unscanned (a higher limit
    scans more, so it never weakens the check). The line is not an option line: the callers that drop option lines
    keep it, so the limit reaches the scan; as an allowed string it only allows its own text. It is never a tier line. A value below MAX_BYTES, above MAX_BYTES_CEILING or not a number is
    ignored, and MAX_BYTES applies.

    Args:
        allow: the lines of the settings file (load_allow).
    Returns:
        The limit in bytes.
    """
    for v in allow:
        m = MAX_BYTES_LINE.match(v) if len(v) <= OPTION_MAX else None
        if m and MAX_BYTES <= int(m.group(1)) <= MAX_BYTES_CEILING:
            return int(m.group(1))
    return MAX_BYTES


def is_tier_line(v):
    """True when this settings line is a tier line, in any form (short lines only; never a `code-` or `audit-` setting)."""
    return len(v) <= OPTION_MAX and bool(PROFILE_LINE.match(v)) and not SETTING_LINE.match(v)


def is_option_line(v):
    """True when this settings line is an option line (tier, denylist, or a `code-` or `audit-` setting), never an
    allowed value."""
    return len(v) <= OPTION_MAX and bool(OPTION_LINE.match(v) or SETTING_LINE.match(v))
BOTH_FILES = "profile: <both .check and .pii-guard exist>"  # load_allow adds it; it reads as an unknown tier line
UNREADABLE = "profile: <the settings file is not UTF-8 text>"  # load_allow adds it; it reads as an unknown tier line
UNKNOWN_PROFILE = ("unknown profile line in .check (or .pii-guard), or the file is not UTF-8 text: the only tier line is "
                   "`profile: dod`. Correct or remove the line, or save the file as UTF-8; if both .check and .pii-guard "
                   "exist, move the lines of .pii-guard into .check and delete it. The check does not guess a tier.")


def profile_of(allow):
    """Tier from the settings lines: "minimum" (no profile line), "dod", or "unknown" (any other value: the caller
    fails, so a wrong spelling cannot lower the tier in silence). Case, and spacing around the colon, do not matter."""
    lines = [v for v in allow if is_tier_line(v)]
    if not lines:
        return "minimum"
    return "dod" if all(re.fullmatch(r"(?i)profile\s*:\s*dod", v) for v in lines) else "unknown"


def dod_mode(root):
    """True when the settings file in the working tree has a profile line (an unknown value counts: fail closed)."""
    return profile_of(load_allow(root)) != "minimum"


def warn_mode(root):
    """True when the settings file in the working tree has the option line `denylist: warn` and no profile line."""
    allow = load_allow(root)
    return WARN_OPTION in allow and profile_of(allow) == "minimum"


def fingerprint(words):
    """8 hex characters over the normalized list: equal for every copy of the same list, and shows no entry."""
    norm = sorted({w.lower() for w in words})
    return hashlib.sha256("\n".join(norm).encode()).hexdigest()[:8]


def load_denylist():
    """The denylist entries from the first source that has any, or []."""
    return parse_denylist(denylist_source()[0])


CONFIG_NAMES = (".check", ".pii-guard")  # the settings file; the second is the name before 2026-11-18, still read


def _exists(root, name, ref=None):
    """True when the file exists in the working tree, or at the git ref."""
    if ref:
        return subprocess.run(["git", "cat-file", "-e", f"{ref}:{name}"], cwd=root, capture_output=True).returncode == 0
    return (pathlib.Path(root) / name).is_file()


def config_name(root, ref=None):
    """The name of the settings file that exists (working tree, or at a git ref), or None: the first of CONFIG_NAMES."""
    return next((name for name in CONFIG_NAMES if _exists(root, name, ref)), None)


def load_allow(root, ref=None):
    """The lines of the settings file (working tree, or the file at a git ref such as the PR base): allowed exact
    strings, and the `skip:`, `block:`, `denylist:`, `profile:`, `code-` and `audit-` lines.

    Args:
        root: the repo root (a folder path).
        ref: a git ref to read the file from; None = the working tree.

    Returns:
        The set of lines; it also holds a marker when the file cannot be read or both file names exist.
    """
    name = config_name(root, ref)
    both = name == CONFIG_NAMES[0] and _exists(root, CONFIG_NAMES[1], ref)
    if name is None:
        data = b""
    elif ref:
        r = subprocess.run(["git", "show", f"{ref}:{name}"], cwd=root, capture_output=True)
        data = r.stdout if r.returncode == 0 else b""
    else:
        data = (pathlib.Path(root) / name).read_bytes()
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
    # Both files present: the old one could hold the tier line that the new one lacks, so the scan fails.
    return {v for v in vals if v} | ({UNREADABLE} if bad else set()) | ({BOTH_FILES} if both else set())


def _covers(path, allow, key):
    """True when a `<key> <path or glob>` line covers this repo-relative path: the glob matches the whole path or
    the file name, or the line names a folder above it. A bare "*" or "**" is ignored."""
    globs = [a[len(key):].strip() for a in allow if a.startswith(key)]
    globs = [g for g in globs if g.strip("*/")]
    if key == "block:":  # a block line matches in any letter case (A.XLSX is the same file type as a.xlsx)
        path, globs = path.lower(), [g.lower() for g in globs]
    base = path.rsplit("/", 1)[-1]
    return any(fnmatch.fnmatchcase(path, g) or path.startswith(g.rstrip("/") + "/")
               or (key == "block:" and "/" not in g and fnmatch.fnmatchcase(base, g)) for g in globs)


def skipped(path, allow):
    """True when a `skip: <path or glob>` line covers this repo-relative path (a bare "*" would switch the scan off)."""
    return _covers(path, allow, "skip:")


def blocked(path, allow):
    """True when a `block: <path or glob>` line names this repo-relative path: a file that must not be committed or
    sent (a data export, a spreadsheet). A glob with no "/" also matches the file name in any folder (`block: *.xlsx`)."""
    return _covers(path, allow, "block:")


BLOCKED = "the settings file has a `block:` line for this path: this file must not be committed or sent"


def _inside(spans):
    """A test for "the span (s, e) lies inside one of these spans", in log time: one sort, then a binary search over
    the starts and a running maximum of the ends (spans may overlap). A plain any() was quadratic on long lines.

    Args:
        spans: the (start, end) spans.

    Returns:
        A function test(s, e) that gives True or False.
    """
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


def scan_text(text, where, deny, allow, dod=False, terms=()):
    """Return findings (where, line_no, kind, masked) for one text. dod: also run the DoD checks. terms: the PFM's
    own blocked words, found like the names (whole word, any case) and reported as kind term.

    Args:
        text: the text to scan.
        where: the name of its place, for the findings.
        deny: the names of the denylist.
        allow: the lines of the settings file (load_allow).
        dod: True in the DoD tier: also run the DoD checks.
        terms: the PFM's own blocked words.

    Returns:
        The findings, each (where, line number, kind, masked value).
    """
    if LOCAL_ERROR:
        raise LocalError(LOCAL_ERROR)
    found = []
    kinds = [k for k in finders_mod.KINDS if dod or k not in finders_mod.DOD_KINDS]
    words = list(deny) + list(terms)
    names_low = {w.lower() for w in deny}
    name_re = re.compile(r"(?i)(?<![A-Za-z0-9])(" + "|".join(re.escape(w) for w in words) + r")(?![A-Za-z0-9])") if words else None
    # Compiled once per call, used only on a line with a name hit (one finditer per allow line per line was slow).
    allow_res = [re.compile(re.escape(v), re.IGNORECASE) for v in allow if not v.startswith(("skip:", "block:"))] if name_re else []
    hosts_ok = {v.lower() for v in allow} if dod else set()  # a host name has no case
    for n, line in enumerate(text.splitlines(), 1):
        hits = []
        in_mail = _inside(m.span() for m in emails(line)) if dod else None  # the host of a mail address is part of that finding
        for kind in kinds:
            for find in FINDERS[kind]:
                hits += [(kind, val) for s, e, val in find(line) if kind != "milhost" or not in_mail(s, e)]
        names = list(name_re.finditer(line)) if name_re else []
        if names:
            in_allowed = _inside((s.start(), s.end()) for rx in allow_res for s in rx.finditer(line))
            hits += [("name" if m.group(1).lower() in names_low else "term", m.group(1)) for m in names
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


def scan_files(paths, root, deny, allow, dod=False, named=False, terms=()):
    """dod, or named (the caller named these files: FILE mode, the hook): a file that cannot be scanned is a finding
    (kind unscanned) unless a `skip:` line names it. A path that a `block:` line names is a finding (kind blocked).

    Args:
        paths: the repo-relative paths.
        root: the repo root (a folder path).
        deny: the names of the denylist.
        allow: the lines of the settings file (load_allow).
        dod: True in the DoD tier: also run the DoD checks.
        named: True when the caller named these files.
        terms: the PFM's own blocked words.

    Returns:
        The findings, each (where, line number, kind, masked value).
    """
    found, limit = [], max_bytes_of(allow)   # once per call, not once per file
    for p in paths:
        f = pathlib.Path(root) / p
        rel = os.path.relpath(f, root).replace(os.sep, "/") if os.path.isabs(str(p)) else str(p)
        if f.is_file() and blocked(rel, allow):
            found.append((str(p), 0, "blocked", BLOCKED))
            continue
        if skipped(str(p), allow) or not f.is_file():
            continue
        why = None
        if f.suffix.lower() in SKIP_SUFFIX:
            why = f"file type {f.suffix.lower()} is not scanned"
        elif f.stat().st_size > limit:
            why = f"larger than {limit} bytes"
        else:
            data = f.read_bytes()
            if b"\0" in data[:8192]:
                why = "binary file"
        if why:
            if dod or named:
                found.append((str(p), 0, "unscanned", why))
            continue
        found += scan_text(data.decode("utf-8", "replace"), str(p), deny, allow, dod, terms)
    return found


def commit_meta(sha, root, deny, allow, dod, terms):
    """Findings in a commit's author and committer identity and in its message."""
    lines = git("show", "-s", "--format=%an%n%ae%n%cn%n%ce%n%B", sha, root=root).split("\n")
    out = []
    for part, text in (("author/committer", "\n".join(lines[:4])), ("message", "\n".join(lines[4:]))):
        out += [(f"commit {sha[:7]} {part}", n, k, v) for _, n, k, v in scan_text(text, "", deny, allow, dod, terms)]
    return out


def blocked_in_commit(sha, root, allow):
    """Findings (kind blocked) for each file this commit adds or changes (a merge: against its first parent) that a
    `block:` line names."""
    names = git("-c", "core.quotepath=off", "show", "--format=", "--name-only", "-z", "--no-renames", "-m",
                "--first-parent", "--diff-filter=AM", sha, root=root)
    return [(f"commit {sha[:7]} {n}", "+", "blocked", BLOCKED) for n in filter(None, names.split("\0"))
            if blocked(n, allow)]


def unscanned_in_commit(sha, root, allow, unscanned):
    """DoD tier: the files one commit adds or changes that cannot be scanned (too large, a file type that is not
    scanned, binary), unless a `skip:` line names them. numstat marks a binary file with "-"; the patch has no added
    lines for it.

    Args:
        sha: the commit.
        root: the repo root.
        allow: the lines of the settings file (load_allow).
        unscanned: a set that gets the name of each file over the size limit, so its patch lines are not scanned again.

    Returns:
        The findings (where, "+", "unscanned", reason).
    """
    found, short, limit = [], sha[:7], max_bytes_of(allow)   # once per commit, not once per file
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
        if sizes.get(parts[2], 0) > limit:
            unscanned.add(parts[2])
            found.append((f"commit {short} {parts[2]}", "+", "unscanned", f"larger than {limit} bytes"))
        elif parts[2].lower().endswith(SKIP_SUFFIX):
            found.append((f"commit {short} {parts[2]}", "+", "unscanned", "file type is not scanned"))
        elif parts[0] == "-":
            found.append((f"commit {short} {parts[2]}", "+", "unscanned", "binary file"))
    return found


def scan_commits(revs, root, deny, allow, dod=False, terms=()):
    """revs: arguments for git rev-list. Scan each commit's identity, message and added lines.
    dod: an added or changed file that cannot be scanned is a finding unless a `skip:` line names it.
    A file that a commit adds or changes under a `block:` line is a finding (kind blocked).

    Args:
        revs: the arguments for git rev-list.
        root: the repo root (a folder path).
        deny: the names of the denylist.
        allow: the lines of the settings file (load_allow).
        dod: True in the DoD tier: also run the DoD checks.
        terms: the PFM's own blocked words.

    Returns:
        (findings, the number of commits scanned).
    """
    found = []
    shas = git("rev-list", *revs, root=root).split()
    has_block = any(a.startswith("block:") for a in allow)
    for sha in shas:
        short = sha[:7]
        unscanned = set()  # dod: files already reported as unscanned; their patch lines are not scanned again
        found += commit_meta(sha, root, deny, allow, dod, terms)
        if has_block:
            found += blocked_in_commit(sha, root, allow)
        if dod:
            found += unscanned_in_commit(sha, root, allow, unscanned)
        patch = git("-c", "core.quotepath=off", "show", "--format=", "--unified=0", "--no-color", "--no-ext-diff",
                    "--src-prefix=a/", "--dst-prefix=b/", sha, root=root)
        cur, in_header, added = "?", False, []

        def flush():  # one scan per file, not one per added line (a large file has many lines)
            if added and not cur.endswith(SKIP_SUFFIX) and cur not in unscanned and not skipped(cur, allow):
                found.extend((f"commit {short} {cur}", "+", k, v) for _, _, k, v in scan_text("\n".join(added), "", deny, allow, dod, terms))
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
    """Turn pre-push stdin lines into rev-list argument lists (one per pushed ref).

    Args:
        stdin_text: the lines git gives a pre-push hook on stdin.
        root: the repo root (a folder path).

    Returns:
        A list of rev-list argument lists.
    """
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
