#!/usr/bin/env python3
"""Block personal data and secrets before they reach the remote: emails, phone numbers, ID-number shapes, API tokens
and private keys, names from a denylist that is kept outside the repo, and (opt-in) .mil addresses.

Usage:
    python3 scripts/pii_guard.py --all             # every tracked file (working tree)
    python3 scripts/pii_guard.py --range A..B      # commits in A..B: added lines, messages, author and committer
    python3 scripts/pii_guard.py --push            # pre-push hook mode: reads the hook's stdin lines
    python3 scripts/pii_guard.py FILE ...          # these files
    python3 scripts/pii_guard.py --status          # where the denylist comes from and how many entries (never the names)
    --require-denylist                             # fail when no denylist is found (the hook and the merge check use it)
    python3 scripts/pii_guard.py --test            # self-test; prints PII GUARD TEST PASS

Opt-in: the guard runs only in a repo with a `.pii-guard` file at its root (the hook and the merge check look for it).
That file lists exact strings that are allowed (one per line, `#` comments), and paths to skip as
`skip: <path or glob>` lines (for example a public reference text that quotes office contacts), and opt-in checks as
`check: <name>` lines (today: `check: mil`). Only the PFM adds entries;
agents never add one to get past a block (AGENTS.md "Personal data").

Name denylist (never committed): one name or word per line, `#` comments, matched whole-word, any case.
    - env PII_GUARD_DENYLIST: the list itself (newline or comma separated); the GitHub Action reads it from the
      Actions secret of the same name.
    - env PII_GUARD_DENYLIST_FILE, else ~/.config/pii-guard/denylist.txt
With no denylist, names are not checked and the guard says so (exit code unchanged).

Checks:
    email      any address, except *@users.noreply.github.com, noreply@ / no-reply@ addresses, and the
               reserved example domains (example.com/.org/.net, *.example, *.invalid, *.test, *.localhost)
    mil        any .mil address or host name (email or web); only with a `check: mil` line in .pii-guard
    phone      US numbers (NNN-NNN-NNNN, (NNN) NNN-NNNN, NNN.NNN.NNNN), +country numbers, DSN numbers
    id         SSN shape (NNN-NN-NNNN); a 10-digit number next to EDIPI / DoD ID / CAC
    secret     API tokens (GitHub, GitLab, AWS, Anthropic, OpenAI, Google, Slack, Stripe) and private-key headers
    name       denylist words
Matches are printed masked (names and secrets as a length only), so CI logs do not repeat them. Exit 1 when anything is found.
Standard library only. Needs git (except for FILE mode).
"""
import argparse
import fnmatch
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ZERO = re.compile(r"^0+$")
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
# The character before ".mil" must be a letter or digit: a domain label never ends in "-" (PFM, 2026-11-13).
MIL = re.compile(r"(?i)\b[A-Za-z0-9._%+-]*[A-Za-z0-9]\.mil\b(?![.-][A-Za-z0-9])")
PHONE = [
    re.compile(r"(?<![\w./-])\(?\d{3}\)?[-. ]\d{3}[-.]\d{4}(?![\w-])"),
    re.compile(r"(?<![\w./-])\(\d{3}\) ?\d{3}[-. ]\d{4}(?![\w-])"),
    re.compile(r"(?<![\w+])\+\d{1,3}[ -]\(?\d{1,4}\)?[ -]\d{2,4}[ -]\d{3,4}(?![\w-])"),
    re.compile(r"(?i)\bDSN:?\s*\d{3}[-. ]\d{4}\b"),
    re.compile(r"(?i)\b(?:phone|tel|cell|mobile|fax|call)\b\D{0,20}?(\+?1?[ .-]?\d{3}[ .-]?\d{3}[ .-]?\d{4})\b"),
    re.compile(r"(?<![\w+])\+1\d{10}\b"),
]
SSN = re.compile(r"(?<![\w-])\d{3}-\d{2}-\d{4}(?![\w-])")
SSN_KW = re.compile(r"(?i)\b(?:SSN|social security)\b\D{0,20}?(\d{3}[ -]?\d{2}[ -]?\d{4})\b")
EDIPI = re.compile(r"(?i)\b(?:EDIPI|DoD ?ID|DODID|CAC)\b\D{0,20}(\d{10})\b")
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
ALLOWED_EMAIL = re.compile(
    r"(?i)(@users\.noreply\.github\.com$|^(no-?reply)@|@example\.(com|org|net)$|\.(example|invalid|test|localhost)$)")
SKIP_SUFFIX = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".zip", ".gz", ".woff", ".woff2", ".ttf")
MAX_BYTES = 2_000_000


def mask(kind, s):
    """Show the kind and a length, never enough to rebuild the value (CI logs may be public)."""
    if kind in ("name", "secret"):
        return f"<{len(s)} chars>"
    if kind in ("email", "mil") and "@" in s:
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


def load_denylist():
    return parse_denylist(denylist_source()[0])


def load_allow(root, ref=None):
    """Allowed exact strings from .pii-guard (working tree, or the file at a git ref such as the PR base)."""
    if ref:
        r = subprocess.run(["git", "show", f"{ref}:.pii-guard"], cwd=root, capture_output=True, text=True)
        text = r.stdout if r.returncode == 0 else ""
    else:
        f = pathlib.Path(root) / ".pii-guard"
        text = f.read_text() if f.is_file() else ""
    # A comment starts at the line start or after whitespace, so "skip: docs/#1.txt" keeps its "#".
    vals = (re.split(r"(?:^|\s)#", l, maxsplit=1)[0].strip() for l in text.splitlines())
    return {v for v in vals if v}


def check_on(allow, name):
    """True when .pii-guard turns on the opt-in check `name` with a `check: <name>` line."""
    return any(a.startswith("check:") and a[6:].strip().lower() == name for a in allow)


def skipped(path, allow):
    """True when a `skip: <path or glob>` line in .pii-guard covers this repo-relative path."""
    globs = [a[5:].strip() for a in allow if a.startswith("skip:")]
    globs = [g for g in globs if g.strip("*/")]  # a bare "*" or "**" would switch the guard off: ignored
    return any(fnmatch.fnmatchcase(path, g) or path.startswith(g.rstrip("/") + "/") for g in globs if g)


def scan_text(text, where, deny, allow):
    """Return findings (where, line_no, kind, masked) for one text."""
    found = []
    name_re = re.compile(r"(?i)(?<![A-Za-z0-9])(" + "|".join(re.escape(w) for w in deny) + r")(?![A-Za-z0-9])") if deny else None
    for n, line in enumerate(text.splitlines(), 1):
        hits = []
        for m in EMAIL.finditer(line):
            if not ALLOWED_EMAIL.search(m.group()):
                hits.append(("email", m.group()))
        if check_on(allow, "mil"):
            hits += [("mil", m.group()) for m in MIL.finditer(line)]
        for rx in SECRET:
            hits += [("secret", m.group()) for m in rx.finditer(line)]
        for rx in PHONE:
            hits += [("phone", m.group(m.lastindex or 0)) for m in rx.finditer(line)]
        hits += [("id", m.group()) for m in SSN.finditer(line)]
        hits += [("id", m.group(1)) for m in SSN_KW.finditer(line)]
        hits += [("id", m.group(1)) for m in EDIPI.finditer(line)]
        if name_re:
            spans = [(s.start(), s.end()) for v in allow if not v.startswith(("skip:", "check:"))
                     for s in re.finditer(re.escape(v), line, re.IGNORECASE)]
            hits += [("name", m.group(1)) for m in name_re.finditer(line)
                     if not any(a <= m.start(1) and m.end(1) <= b for a, b in spans)]  # inside an allowed string
        seen = set()
        for kind, val in hits:
            if val in allow or (kind, val) in seen or any(val == v for _, v in seen):
                continue
            seen.add((kind, val))
            found.append((where, n, kind, mask(kind, val)))
    return found


def git(*args, root="."):
    return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True,
                          errors="replace").stdout


def scan_files(paths, root, deny, allow):
    found = []
    for p in paths:
        f = pathlib.Path(root) / p
        if skipped(str(p), allow) or not f.is_file() or f.suffix.lower() in SKIP_SUFFIX or f.stat().st_size > MAX_BYTES:
            continue
        data = f.read_bytes()
        if b"\0" in data[:8192]:
            continue
        found += scan_text(data.decode("utf-8", "replace"), str(p), deny, allow)
    return found


def scan_commits(revs, root, deny, allow):
    """revs: arguments for git rev-list. Scan each commit's identity, message and added lines."""
    found = []
    shas = git("rev-list", *revs, root=root).split()
    for sha in shas:
        short = sha[:7]
        meta = git("show", "-s", "--format=%an%n%ae%n%cn%n%ce%n%B", sha, root=root)
        lines = meta.split("\n")
        ident = "\n".join(lines[:4])
        found += [(f"commit {short} author/committer", n, k, v) for _, n, k, v in scan_text(ident, "", deny, allow)]
        found += [(f"commit {short} message", n, k, v) for _, n, k, v in scan_text("\n".join(lines[4:]), "", deny, allow)]
        patch = git("-c", "core.quotepath=off", "show", "--format=", "--unified=0", "--no-color", "--no-ext-diff",
                    "--src-prefix=a/", "--dst-prefix=b/", sha, root=root)
        cur = "?"
        for line in patch.splitlines():
            if line.startswith("+++ "):
                name = line[4:].split("\t", 1)[0]
                if len(name) > 1 and name[0] == name[-1] == '"':
                    name = name[1:-1].replace('\\"', '"').replace("\\\\", "\\")
                cur = name[2:] if name.startswith("b/") else name
            elif line.startswith("+") and not cur.endswith(SKIP_SUFFIX) and not skipped(cur, allow):
                found += [(f"commit {short} {cur}", "+", k, v) for _, _, k, v in scan_text(line[1:], "", deny, allow)]
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


def report(found, what, deny):
    for where, n, kind, val in found:
        print(f"pii-guard: {where}:{n}: {kind}: {val}")
    names = f"names checked ({len(deny)} denylist entries)" if deny else "names NOT checked (no denylist)"
    print(f"PII GUARD {'FAIL' if found else 'PASS'}: {len(found)} finding(s) in {what}; {names}")
    return 1 if found else 0


def self_test():
    at, dot = "@", "."
    ok = True

    def expect(name, text, kinds, deny=(), allow=()):
        nonlocal ok
        got = sorted({k for _, _, k, _ in scan_text(text, "t", list(deny), set(allow))})
        good = got == sorted(kinds)
        print(("ok   " if good else "FAIL ") + f"{name}: {got}")
        ok = ok and good

    expect("personal email", "mail jane" + at + "corp" + dot + "io", ["email"])
    expect("github noreply allowed", "123+x" + at + "users.noreply.github" + dot + "com", [])
    expect("noreply allowed", "noreply" + at + "anthropic" + dot + "com", [])
    expect("example domain allowed", "a" + at + "example" + dot + "com", [])
    expect("placeholder t@t ignored", "t" + at + "t", [])
    mil_on = ["check: mil"]
    expect(".mil off by default", "see genai" + dot + "mil today", [])
    expect(".mil email", "x" + dot + "y" + at + "us.af" + dot + "mil", ["email", "mil"], allow=mil_on)
    expect(".mil host", "see genai" + dot + "mil today", ["mil"], allow=mil_on)
    expect(".mil after a hyphen is not a host", "Gmail-to-" + dot + "mil mail is filtered", [], allow=mil_on)
    expect(".mil host with a hyphen inside", "see my-base" + dot + "mil today", ["mil"], allow=mil_on)
    expect("phone dashes", "call 555-123-" + "4567", ["phone"])
    expect("phone parens", "call (555) 123-" + "4567", ["phone"])
    expect("phone intl", "call +44 20 7946 " + "0958", ["phone"])
    expect("DSN", "DSN 312-" + "5550", ["phone"])
    expect("SSN shape", "id 123-45-" + "6789", ["id"])
    expect("EDIPI", "EDIPI: 12345" + "67890", ["id"])
    expect("date not a phone", "2026-11-11 10:00", [])
    expect("version not a phone", "v2.1.41 and 1.2.3.4", [])
    expect("unix time not an id", "ts 17312" + "34567", [])
    expect("sha not an id", "commit 0123456789abcdef0123456789abcdef01234567", [])
    expect("denylist name", "ask Alex" + "andra first", ["name"], deny=["Alexandra"])
    expect("denylist any case", "ALEX" + "ANDRA", ["name"], deny=["alexandra"])
    expect("denylist whole word", "Alexandra" + "s", [], deny=["Alexandra"])
    expect("allow list", "see genai" + dot + "mil", [], allow=["genai" + dot + "mil", "check: mil"])
    expect("skip line is not an allowed value", "see genai" + dot + "mil", ["mil"], allow=["skip: ref/x.txt", "check: mil"])
    good = not skipped("a.txt", {"skip: *"}) and not skipped("a/b.txt", {"skip: **"}) \
        and skipped("ref/x.txt", {"skip: ref/x.txt"}) and skipped("ref/a/b.txt", {"skip: ref/"}) \
        and skipped("ref/y.txt", {"skip: ref/*.txt"}) and not skipped("docs/x.txt", {"skip: ref/x.txt"})
    print(("ok   " if good else "FAIL ") + "skip: exact path, folder, glob; other paths still scanned")
    ok = ok and good
    expect("name inside an allowed host is not flagged", "https://acme" + dot + "dps" + dot + "mil/sites/x", [],
           deny=["ACME"], allow=["acme" + dot + "dps" + dot + "mil", "check: mil"])
    expect("allowed string matches in any case", "https://ACME" + dot + "DPS" + dot + "MIL/x", ["mil"],
           deny=["ACME"], allow=["acme" + dot + "dps" + dot + "mil", "check: mil"])
    expect("same name elsewhere on the line is flagged", "ACME team at acme" + dot + "dps" + dot + "mil", ["name"],
           deny=["ACME"], allow=["acme" + dot + "dps" + dot + "mil", "check: mil"])
    expect("check line is not an allowed value", "see check: mil", [], allow=["check: mil"])
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
        n = len(load_denylist())
        print(f"denylist: {n} entries from {src}" if src and n else "denylist: none (" + MISSING_HELP + ")")
        return 0 if n else 1
    if not (a.files or a.all or a.range or a.push):
        ap.error("give --all, --range, --push, --status or files")
    try:
        root = git("rev-parse", "--show-toplevel").strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        root = "."
    deny, allow = load_denylist(), load_allow(root, a.allow_from)
    revsets = [[a.range]] if a.range else []
    if a.push:
        revsets += push_revs(sys.stdin.read(), root)
    deletes_only = a.push and not revsets and not (a.all or a.files or a.range)
    if a.require_denylist and not deny and not deletes_only:
        print("PII GUARD FAIL: " + MISSING_HELP)
        return 1
    found, what = [], []
    if a.all:
        files = git("ls-files", "-z", root=root).split("\0")
        found += scan_files([f for f in files if f], root, deny, allow)
        what.append(f"{len([f for f in files if f])} tracked files")
    if a.files:
        rel = [os.path.relpath(os.path.abspath(f), root) for f in a.files]
        found += scan_files(rel, root, deny, allow)
        what.append(f"{len(a.files)} file(s)")
    n = 0
    for revs in revsets:
        f, k = scan_commits(revs, root, deny, allow)
        found += f
        n += k
    if revsets:
        what.append(f"{n} commit(s)")
    skips = sorted(a[5:].strip() for a in allow if a.startswith("skip:"))
    if skips:
        what.append(f"{len(skips)} skip rule(s): {', '.join(skips)}")
    return report(found, ", ".join(what) or "nothing", deny)


if __name__ == "__main__":
    sys.exit(main())
