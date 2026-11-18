"""The finders of the content check: the patterns of each finding kind, the kit's finder functions, and the loader of
a project's own finders (the extension point; its interface is in the header of scripts/check_content_scan.py).

What it gives:
  KINDS, DOD_KINDS   the finding kinds that have finders, in the order they are reported; the kinds of the DoD tier
  KIT_FINDERS        {kind: [finder]}: the kit's own finders. A finder takes one line of text and yields
                     (start, end, value) for each match: the span in the line and the text that is the finding.
  load_local(path)   the finders in use when a project's own module exists: the kit's, with the kinds the module
                     replaces and the finders it adds; LocalError when the module is broken or has a wrong shape
Inputs:  one line of text; for load_local the path of scripts/check_content_local.py.
Outputs: matches as (start, end, value) tuples; nothing is printed here.
Run:     not run alone; check_content_scan.py imports it. Proved by `python3 scripts/check_content.py --test`.
Network: none.
Writes: none.
Credentials: none.
"""
import importlib.util
import pathlib
import re

# EMAIL is the pattern; emails() finds its matches. A plain EMAIL.finditer tries every start of a long run of
# local-part characters, so its time grows with the square of the run (200 KB took 26 s, longer than the hook timeout).
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
_LOCAL = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._%+-")


def emails(line):
    """The matches of EMAIL.finditer (leftmost, non-overlapping) in linear time. A local part cannot hold an "@", so
    each match ends its local part at one "@": walk the "@" signs in order, start the local part at the start of its
    run (not before the end of the last match), and match once from there.

    Args:
        line: one line of text.
    """
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
# DoD tier (`profile: dod`). MILHOST may not start inside a host name (after "x."): a match at every label was
# quadratic ("a." * 10,000 took 0.8 s). The marks are split in the source so this file does not flag itself.
MILHOST = re.compile(
    r"(?i)(?<![A-Za-z0-9-])(?<![A-Za-z0-9-]\.)(?:(?:[a-z0-9-]+\.)+mil(?![A-Za-z0-9-]|\.[A-Za-z0-9])"   # any host under the military domain
    r"|(?:[a-z0-9-]+\.)*sharepoint-mil\.us\b|(?:[a-z0-9-]+\.)*dod\.teams\.microsoft\.us\b)")          # DoD cloud tenant hosts
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


# ---------------------------------------------------------------- the kit's finders ---------------------------------

KINDS = ("email", "secret", "phone", "id", "milhost", "dodid", "marking")   # the order of the findings of one line
DOD_KINDS = ("milhost", "dodid", "marking")                                  # run only in the DoD tier (`profile: dod`)


def find_email(line):
    """Yield (start, end, address) for each mail address that is not an allowed form (noreply, example domains)."""
    for m in emails(line):
        if not ALLOWED_EMAIL.search(m.group()):
            yield m.start(), m.end(), m.group()


def find_secret(line):
    """Yield (start, end, text) for each API token or private-key header (SECRET)."""
    for rx in SECRET:
        for m in rx.finditer(line):
            yield m.start(), m.end(), m.group()


def find_phone(line):
    """Yield (start, end, number) for each phone number (PHONE), without the punctuation around it (allow lines are
    stripped the same way)."""
    for rx in PHONE:
        for m in rx.finditer(line):
            g = m.lastindex or 0
            yield m.start(g), m.end(g), m.group(g).strip(" .-")


def find_id(line):
    """Yield (start, end, number) for each SSN shape, and each 9 digits next to an SSN keyword."""
    for m in SSN.finditer(line):
        yield m.start(), m.end(), m.group()
    for m in SSN_KW.finditer(line):
        yield m.start(1), m.end(1), m.group(1)


def find_milhost(line):
    """Yield (start, end, host) for each military or DoD cloud host name (MILHOST)."""
    for m in MILHOST.finditer(line):
        yield m.start(), m.end(), m.group()


def find_dodid(line):
    """Yield (start, end, number) for each 10 digits next to a DoD ID keyword (DODID)."""
    for rx in DODID:
        for m in rx.finditer(line):
            yield m.start(1), m.end(1), m.group(1)


def find_marking(line):
    """Yield (start, end, mark) for each controlled-information or classification mark (MARKING)."""
    for rx in MARKING:
        for m in rx.finditer(line):
            yield m.start(), m.end(), m.group().strip()


KIT_FINDERS = {"email": [find_email], "secret": [find_secret], "phone": [find_phone], "id": [find_id],
               "milhost": [find_milhost], "dodid": [find_dodid], "marking": [find_marking]}


# ---------------------------------------------------------------- a project's own finders ---------------------------

LOCAL_NAME = "check_content_local.py"   # a project's own file, next to the scanner; the kit has none


class LocalError(Exception):
    """A project's own finder module exists and cannot be used: every scan fails, and the hook blocks."""


def local_lists(mod, name, need_one):
    """The {kind: [finder]} dict a project's module gives under `name` (REPLACE or ADD), checked.

    Args:
        mod: the loaded module.
        name: "REPLACE" or "ADD".
        need_one: True when each kind must have at least one finder (an empty REPLACE list would switch a kind off).

    Returns:
        The dict ({} when the module has no such name). LocalError when it is not {kind in KINDS: [functions]}.
    """
    got = getattr(mod, name, {})
    shaped = isinstance(got, dict) and all(
        k in KINDS and isinstance(v, (list, tuple)) and all(callable(x) for x in v) and (v or not need_one)
        for k, v in got.items())
    if not shaped:
        raise LocalError(f"{LOCAL_NAME}: {name} must be a dict {{kind: [finder functions]}} with kinds from "
                         f"{', '.join(KINDS)}" + (" and at least one finder for each kind" if need_one else ""))
    return {k: list(v) for k, v in got.items()}


def load_local(path):
    """The finders in use, with a project's own module applied when its file exists.

    Args:
        path: the path of the project's module (a file named LOCAL_NAME next to the scanner).

    Returns:
        (finders, note): finders is {kind: [finder]} for each kind in KINDS; note is "" when there is no such file,
        else a text for the result line that names the kinds the module replaces and adds. LocalError when the file
        cannot be imported, or has neither REPLACE nor ADD in the documented shape: the caller fails every scan.
    """
    path = pathlib.Path(path)
    if not path.is_file():
        return dict(KIT_FINDERS), ""
    try:
        spec = importlib.util.spec_from_file_location("check_content_local", str(path))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    except BaseException as err:   # noqa: B036 - any error or exit of the project's file (a sys.exit at import too):
        # no scan runs on the kit's default in silence, and the process does not end with the file's exit code
        raise LocalError(f"{LOCAL_NAME} cannot be loaded ({err.__class__.__name__}: {err})") from None
    replace, add = local_lists(mod, "REPLACE", True), local_lists(mod, "ADD", False)
    if not replace and not any(add.values()):
        raise LocalError(f"{LOCAL_NAME} has no finder: it must define REPLACE or ADD (the interface: the header of "
                         "scripts/check_content_scan.py)")
    finders = {k: list(replace.get(k, KIT_FINDERS[k])) + add.get(k, []) for k in KINDS}
    parts = (["replaces " + ", ".join(k for k in KINDS if k in replace)] if replace else []) \
        + (["adds " + ", ".join(k for k in KINDS if add.get(k))] if any(add.values()) else [])
    return finders, f"local module {LOCAL_NAME} active ({'; '.join(parts)})"
