"""The settings of the content check: the reader of the settings file (`.check`; the old name `.pii-guard` is still
read): its tier, option, size, `skip:` and `block:` lines.

Part of scripts/check_content_scan.py (split out to keep each file under the line cap of docs/code-standard.md C4);
check_content_scan.py imports every name here and re-exports it, so `check_content_scan.<name>` keeps working. The
word lists (denylist, terms, fingerprint) are read in check_content_scan_words.py. The tiers and limits are
described in the check_content.py header.
Inputs: the settings file (working tree, or at a git ref).
Outputs: lists, sets and flags for the scans; nothing is printed here.
Run: not run alone; check_content_scan.py imports it.
Prevents: the content check reads the wrong settings, so a listed tier, option or a blocked file passes the scan
Network: none (it runs local git read commands).
Writes: none.
Credentials: none.
"""
import fnmatch
import pathlib
import re
import subprocess
import unicodedata


MAX_BYTES = 2_000_000


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
