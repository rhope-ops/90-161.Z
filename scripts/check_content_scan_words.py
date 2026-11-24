"""The word lists of the content check: the readers of the name denylist and the terms list (environment variable or
file), and the fingerprint of a list.

Part of scripts/check_content_scan.py (split by subject: the word-list sources here, the `.check` parsing in the settings file);
check_content_scan.py imports every name here and re-exports it, so `check_content_scan.<name>` keeps working. The
settings file (`.check`) is read in check_content_scan_settings.py, which does not import this file.
Inputs: the word lists (environment or file).
Outputs: lists of words and short texts for the scans; nothing is printed here.
Run: not run alone; check_content_scan.py imports it.
Prevents: the content check reads the wrong word lists, so a listed name or term passes the scan
Network: none.
Writes: none.
Credentials: none; it reads the name denylist and the terms list (each from an environment variable or a file).
"""
import hashlib
import os
import pathlib
import re


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
    """Return (raw text, where it came from) for the Maintainer's own blocked terms (words that are not personal data:
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
    """The Maintainer's blocked terms from the first source that has any, or []."""
    return parse_denylist(terms_source()[0])


MISSING_HELP = ("no denylist found. Add your names (comma or newline separated), never in a repo or a chat: "
                "a cloud session: environment variable PII_GUARD_DENYLIST in the cloud environment's settings; "
                "GitHub Actions: repository secret PII_GUARD_DENYLIST; your computer: ~/.config/pii-guard/denylist.txt. "
                "See docs/FIRST_USE.md.")


def fingerprint(words):
    """8 hex characters over the normalized list: equal for every copy of the same list, and shows no entry."""
    norm = sorted({w.lower() for w in words})
    return hashlib.sha256("\n".join(norm).encode()).hexdigest()[:8]


def load_denylist():
    """The denylist entries from the first source that has any, or []."""
    return parse_denylist(denylist_source()[0])
