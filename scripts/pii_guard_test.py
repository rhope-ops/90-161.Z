"""Self-test of scripts/pii_guard.py (run by `python3 scripts/pii_guard.py --test`; kept in its own file so the guard
stays under the 600-line cap of docs/code-standard.md C4).

It proves every check on built-at-run-time samples (no real address, token, host, mark or ID is in this file): the
patterns and their speed on long lines, the allow and skip lines, the tiers and the .pii-guard reader, the denylist
sources, the CLI modes (--all, --push, --status, --stdin, files) in temporary git repos, the commit scan, and the
PreToolUse hook (in process).
Input: none (temporary folders only; the host's git config is switched off). Output: one "ok" or "FAIL" line per
case, then PII GUARD TEST PASS or FAIL; run() returns the exit code 0 or 1. Needs git.
"""
import contextlib
import io
import json
import os
import random
import pathlib
import re
import subprocess
import sys
import tempfile
import time

import pii_guard_hook
import pii_guard_scan
from pii_guard_scan import (MAX_BYTES, OPTION_MAX, denylist_source, dod_mode, fingerprint, git, is_option_line,
                            load_allow, load_denylist, mask, parse_denylist, profile_of, push_revs, scan_commits,
                            scan_text, skipped, warn_mode)

at, dot = "@", "."  # addresses and hosts are joined at run time, so this file does not flag itself
x36 = "A1b2C3d4E5" * 3 + "F6g7H8"  # body of the sample secrets
mil = "portal" + dot + "unit" + dot + "mi" + "l"  # a sample host in the military domain
ME = [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "pii_guard.py")]  # the guard's CLI
FAILED = []  # labels of the cases that failed


def check(label, good):
    """Print one result line and remember a failure."""
    print(("ok   " if good else "FAIL ") + label)
    if not good:
        FAILED.append(label)


def expect(name, text, kinds, deny=(), allow=(), dod=False):
    """Scan one text and check that the finding kinds are exactly these."""
    got = sorted({k for _, _, k, _ in scan_text(text, "t", list(deny), set(allow), dod)})
    check(f"{name}: {got}", got == sorted(kinds))


def case_speed():
    """Long lines (address chains, host runs, many distinct values) scan in linear time."""
    expect("personal email", "mail jane" + at + "corp" + dot + "io", ["email"])
    t0 = time.time()
    chain = len(scan_text(("a" + at + "b" + dot + "cc+") * 20_000, "t", [], set()))  # 200 KB of joined addresses
    secs = time.time() - t0  # the first address and the "+" joined one; scan_text drops repeats
    check(f"200 KB chain of joined addresses: linear ({secs:.2f} s)", 1 <= chain <= 2 and secs < 2)
    teams = "api" + dot + "dod" + dot + "teams" + dot + "microsoft" + dot + "us"
    expect("a DoD Teams host with a subdomain", "see https://" + teams + "/x", ["milhost"], dod=True)
    for label, run in (("a.", "a." * 100_000), ("a-a.", "a-a." * 50_000), ("a.dod.", "a.dod." * 33_000)):
        t0 = time.time()
        scan_text(run, "t", [], set(), True)
        secs = time.time() - t0
        check(f"200 KB of {label!r}: MILHOST linear ({secs:.2f} s)", secs < 2)
    t0 = time.time()
    many = "".join("a" + str(i) + at + "b" + dot + "cc " for i in range(17_600))  # 200 KB of distinct addresses
    many += "".join("h" + str(i) + dot + "mil " for i in range(5_000)) + "Jane Doe" * 18_000  # hosts, allowed names
    scan_text(many, "t", ["jane"], {"Jane Doe"}, True)
    secs = time.time() - t0
    check(f"200 KB of distinct addresses, hosts and allowed names: linear ({secs:.2f} s)", secs < 2)


def case_minimum_patterns():
    """Emails, phones, IDs, names, the allow list and skip lines in the minimum tier."""
    expect("third address of a chain of allowed ones", "-" + at + "example" + dot + "com+" + at + "example" + dot + "com" + at + "example" + dot + "com" + at + "jane" + dot + "io", ["email"])
    expect("address joined to the end of an allowed one", "x" + at + "example" + dot + "com+bob" + at + "corp" + dot + "org", ["email"])
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
    check("skip: exact path, folder, glob; other paths still scanned", good)
    expect("name inside an allowed host is not flagged", "https://acme" + dot + "example" + dot + "org/sites/x", [],
           deny=["ACME"], allow=["acme" + dot + "example" + dot + "org"])
    expect("allowed string matches in any case", "https://ACME" + dot + "EXAMPLE" + dot + "ORG/x", [],
           deny=["ACME"], allow=["acme" + dot + "example" + dot + "org"])
    expect("same name elsewhere on the line is flagged", "ACME team at acme" + dot + "example" + dot + "org", ["name"],
           deny=["ACME"], allow=["acme" + dot + "example" + dot + "org"])


def case_secrets_and_masks():
    """Secret shapes and their look-alikes, more phone and ID forms, and the masks."""
    # Secret test values are built at run time, so this file holds no token shape itself.
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
    check("secrets print as a length only", mask("secret", "gh" + "p_" + x36) == f"<{len(x36) + 4} chars>")
    expect("allow list is exact", "call 555-123-" + "4567", ["phone"], allow=["call 555-123-" + "4567 now"])
    num = "555-123-" + "4567"
    expect("allowed phone after a keyword and a space", "tel " + num, [], allow=[num])
    expect("allowed phone after a keyword and a dash", "tel-" + num, [], allow=[num])
    expect("an allowed phone does not allow another", "tel " + num + ", cell 555-987-" + "6543", ["phone"], allow=[num])
    expect("URL path not a phone", "github.com/x/pull/123-456-" + "7890", [])
    expect("phone keyword, no separators", "tel: 555123" + "4567", ["phone"])
    expect("+1 packed", "+1555123" + "4567", ["phone"])
    expect("SSN keyword, no dashes", "SSN 123456" + "789", ["id"])
    expect("short name fully masked", "Sam", ["name"], deny=["Sam"])
    good = mask("name", "Sam") == "<3 chars>" and mask("email", "a" + at + "b" + dot + "io") == "***@****"
    check("masking hides names and email users", good)


def case_dod_patterns():
    """DoD tier: military hosts, banner marks and DoD IDs, and what is not one."""
    # DoD tier. Test values are built at run time, so this file holds no host, mark or ID shape itself.
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


def case_milhosts_edges():
    """milhosts() gives the matches of MILHOST.finditer (RADE decision 2A, 2026-11-16) on the pattern's edge cases."""
    mi = "mi" + "l"
    spm, tms = "sharepoint-" + mi + dot + "us", "dod" + dot + "teams" + dot + "microsoft" + dot + "us"
    for label, text, want in (
            ("start after a double hyphen", "--a" + dot + mi, ["a" + dot + mi]),
            ("start after a hyphen in a segment over 63 characters", "b" * 70 + "-c" + dot + mi, ["c" + dot + mi]),
            ("63-character label", "q" * 63 + dot + mi, ["q" * 63 + dot + mi]),
            ("64-character label", "q" * 64 + dot + mi, []),
            ("host, then a dot and a hyphen", "a" + dot + mi + dot + "-x", ["a" + dot + mi]),
            ("two meeting hosts joined by a dot", tms + dot + tms, [tms, tms]),
            ("meeting host inside a longer host", "a" + dot + tms + dot + "x" + dot + mi, ["a" + dot + tms + dot + "x" + dot + mi]),
            ("tenant host after a hyphen", "x-" + spm, [spm]),
            ("tenant hosts joined by labels", spm + dot + "x" + dot + spm, [spm + dot + "x" + dot + spm]),
            ("no host: underscore after the tenant host", spm + "_", []),
            ("dotless i (case rule of the pattern)", "a" + dot + "mıl", ["a" + dot + "mıl"]),
            ("long s (case rule of the pattern)", "sharepoint-" + mi + dot + "uſ", ["sharepoint-" + mi + dot + "uſ"])):
        old = [m.group() for m in pii_guard_scan.MILHOST.finditer(text)]
        new = [m.group() for m in pii_guard_scan.milhosts(text)]
        check(f"milhosts: {label}: {len(new)} matches", old == new == want)
    expect("dod milhost: hyphen inside a label", "see my-base" + dot + mi, ["milhost"], dod=True)
    expect("dod milhost: after a leading hyphen", "-unit" + dot + mi, ["milhost"], dod=True)
    expect("dod: not a host: label ends in a hyphen", "Gmail-to-" + dot + mi, [], dod=True)
    expect("dod: not a host: hyphen before the dot", "a-" + dot + "unit-" + dot + mi, [], dod=True)


def case_milhosts_fallback():
    """With a model that gives a wrong span, milhosts() falls back to the pattern from the last good end."""
    mi = "mi" + "l"
    host = "a" + dot + mi
    text = host + " x" + dot + mi + " y" + dot + mi
    real_spans = pii_guard_scan._milhost_spans
    try:
        for label, fake in (("a skipped match", [(12, 14)]), ("a wrong end after a good match", [(0, 5), (12, 14)]),
                            ("a repeated span", [(0, 5), (0, 5)])):
            pii_guard_scan._milhost_spans = lambda line, fake=fake: iter(fake)
            got = [m.span() for m in pii_guard_scan.milhosts(text)]
            want = [m.span() for m in pii_guard_scan.MILHOST.finditer(text)]
            check(f"milhosts fallback: {label}: {got}", got == want == [(0, 5), (6, 11), (12, 17)])
        pii_guard_scan._milhost_spans = lambda line: iter([(6, 11), (0, 5)])  # a span before the last: no repeat, in order
        got = [m.span() for m in pii_guard_scan.milhosts(text)]
        check(f"milhosts fallback: a span out of order: {got}", got == [(6, 11), (12, 17)])
    finally:
        pii_guard_scan._milhost_spans = real_spans


def case_milhosts_random_speed():
    """milhosts() matches the pattern on 2,000 random lines and runs in linear time on 200 KB runs."""
    mi = "mi" + "l"
    spm, tms = "sharepoint-" + mi + dot + "us", "dod" + dot + "teams" + dot + "microsoft" + dot + "us"
    rnd = random.Random(2)
    tokens = ["-", "--", dot, dot * 2, mi, dot + mi, mi.upper(), "a", "x-", "b" * 63, "c" * 64, spm, spm.upper(), tms, "us",
              "dod" + dot, "teams" + dot, at, "https://", " ", "_", "é", "ı", "ſ", "K", "a" + dot, "-a" + dot]
    diffs = 0
    for _ in range(2_000):
        text = "".join(rnd.choice(tokens) for _ in range(rnd.randint(1, 30)))
        diffs += [m.span() for m in pii_guard_scan.MILHOST.finditer(text)] != [m.span() for m in pii_guard_scan.milhosts(text)]
    check(f"milhosts: 2,000 random lines, same matches as the pattern ({diffs} differ)", diffs == 0)
    for label, text in (("a.", "a." * 100_000), ("a. then a host", "a." * 99_998 + mi), ("a-a. then a host", "a-a." * 49_999 + mi),
                        ("x- then a host", "x-" * 99_997 + "a" + dot + mi), ("63-character labels", ("b" * 63 + dot) * 3_125),
                        ("a. then a tenant host", "a." * 99_991 + spm), ("meeting hosts", (tms + dot) * 8_695),
                        ("hosts and empty labels", ("a" + dot + mi + dot * 2) * 28_571),
                        ("short runs", ("a.a.a.a.a.a.a.a.a." + mi + " ") * 9_090), ("short hosts", ("a" + dot + mi + " ") * 33_333),
                        ("runs at the short limit", (("a" + dot) * 10 + mi + "- ") * 7_692),
                        ("runs just over the short limit", (("a" + dot) * 10 + mi + dot + "- ") * 7_692)):
        t0 = time.perf_counter()
        sum(1 for _ in pii_guard_scan.milhosts(text))
        took = time.perf_counter() - t0
        check(f"milhosts: 200 KB of {label}: linear ({took:.3f} s)", took < 0.5)


def case_profile_lines():
    """The tier line: accepted forms, unknown forms, and no slow match on long or odd lines."""
    good = profile_of({"Profile: DoD"}) == profile_of({"profile:dod"}) == profile_of({"profile :  dod"}) == "dod" \
        and profile_of({"profile: dodd"}) == profile_of({"profile: dod", "profile: min"}) == profile_of({"profile:"}) == "unknown" \
        and profile_of({"profile: d o d"}) == profile_of({"profile = dod"}) == profile_of({"profile dod"}) == "unknown" \
        and profile_of({"profil: dod"}) == profile_of({"tier=dod"}) == profile_of({"profile"}) == "unknown" \
        and all(profile_of({v}) == "unknown" for v in ("profile：dod", "- profile: dod", "* profile: dod", '"profile: dod"',
                                                         "[profile: dod]", "$profile: dod", "profile; dod", "profile - dod",
                                                         "profile dod", "tier; dod", "'profile:dod'")) \
        and profile_of({"denylist: warn", "x", "profile.example.org", "profile-x", "profile/x", "host.dod", "a.dod",
                        "skip: a/dod", "skip: profile dod", "skip: dod", "skip:dod"}) == "minimum"
    check("profile line: any case, spacing around the colon; any other form is unknown", good)
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
    check(f"option lines: {len(hostile)} long or odd lines, the slowest read in {slow:.3f} s", good and slow < 1)
    expect("dod id: a longer word that starts like the keyword is not one", "dodidentifier 12345" + "67890", [], dod=True)


def case_denylist_and_fingerprint():
    """DoD IDs without a keyword, DoD masks, the fingerprint, and the denylist sources."""
    expect("dod: 10 digits with no keyword", "ts 17312" + "34567", [], dod=True)
    expect("minimum tier: DoD ID not checked", "EDIPI 12345" + "67890", [])
    good = mask("milhost", mil) == f"<{len(mil)} chars>" and mask("dodid", "12345" + "67890") == "********90"
    check("dod: hosts print as a length, IDs as the last 2 digits", good)
    good = fingerprint(parse_denylist("Alex, Sam,River")) == fingerprint(parse_denylist("river\nSAM\nalex\nAlex")) \
        and fingerprint(["Alex"]) != fingerprint(["Sam"]) and re.fullmatch(r"[0-9a-f]{8}", fingerprint(["Alex"]))
    check("fingerprint: same list in any order, case or separator; other list differs", bool(good))
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
    check("denylist source: none, then environment (comma and newline); <Name> wrappers dropped", good)


def guard(d, env, *args):
    """Run the guard's CLI in folder d with this environment."""
    return subprocess.run(ME + list(args), cwd=d, env=env, capture_output=True, text=True)


def case_cli_denylist(d, env):
    """CLI: the denylist file, --push with no denylist, and `denylist: warn` (minimum and DoD tier)."""
    f = pathlib.Path(d, "deny.txt")
    f.write_text("Alex\n")
    env["PII_GUARD_DENYLIST_FILE"] = str(f)
    env["PII_GUARD_DENYLIST"] = "# only a comment"
    r = subprocess.run(ME + ["--status"], env=env, capture_output=True, text=True)
    good = r.returncode == 0 and "1 entries from file" in r.stdout and "Alex" not in r.stdout
    check("comment-only env var does not shadow the file; status hides names", good)
    env["PII_GUARD_DENYLIST_FILE"] = str(f) + ".missing"
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=d, check=True, capture_output=True)
    z = "0" * 40
    r = subprocess.run(ME + ["--push", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True,
                       input=f"refs/heads/main {'1' * 40} refs/heads/main {z}\n")
    check("push with no denylist: blocked", r.returncode == 1 and "no denylist" in r.stdout)
    r = subprocess.run(ME + ["--push", "--require-denylist"], cwd=d, env=env, capture_output=True, text=True,
                       input=f"(delete) {z} refs/heads/x {'1' * 40}\n")
    check("branch delete with no denylist: passes", r.returncode == 0)
    pathlib.Path(d, ".pii-guard").write_text("# starter\ndenylist: warn\n")
    r = guard(d, env, "--all", "--require-denylist")
    good = r.returncode == 0 and "WARNING" in r.stdout and warn_mode(d)
    pathlib.Path(d, "a.txt").write_text("mail bob" + at + "corp" + dot + "io\n")
    subprocess.run(["git", "add", "a.txt"], cwd=d, check=True, capture_output=True)
    r = guard(d, env, "--all", "--require-denylist")
    check("denylist: warn: no denylist only warns; an email still blocks", good and r.returncode == 1)
    pathlib.Path(d, "a.txt").write_text("clean\n")
    pathlib.Path(d, ".pii-guard").write_text("denylist: warn\nprofile: dod\n")
    r = guard(d, env, "--all", "--require-denylist")
    good = r.returncode == 1 and "no denylist" in r.stdout and dod_mode(d) and not warn_mode(d)
    check("dod: no denylist blocks although the file says denylist: warn", good)


def case_cli_profile(d, env):
    """CLI: an unknown tier line, a byte-order mark, a wrong encoding and a zero-width space in .pii-guard."""
    env["PII_GUARD_DENYLIST"] = "Alex"
    pathlib.Path(d, ".pii-guard").write_text("profile: DOD-tier\n")
    r = guard(d, env, "--all")
    r2 = guard(d, env, "--status")
    good = r.returncode == 1 and "PII GUARD FAIL: unknown profile" in r.stdout and r2.returncode == 1 \
        and "UNKNOWN" in r2.stdout and dod_mode(d) and not warn_mode(d)
    check("unknown profile value: the scan and --status fail (no fall back to minimum)", good)
    pathlib.Path(d, ".pii-guard").write_bytes(b"\xef\xbb\xbfprofile: dod\r\n")
    r = guard(d, env, "--status")
    subprocess.run(["git", "add", ".pii-guard"], cwd=d, check=True, capture_output=True)
    staged = load_allow(d, ":0")  # the same file read through git, as --allow-from does
    good = r.returncode == 0 and "profile: dod" in r.stdout and dod_mode(d) and profile_of(staged) == "dod"
    subprocess.run(["git", "rm", "-q", "--cached", ".pii-guard"], cwd=d, check=True, capture_output=True)
    check("tier line after a byte-order mark, with CRLF: DoD tier (file and git read)", good)
    cases = {"UTF-16 with a byte-order mark": "profile: dod\n".encode("utf-16"), "UTF-16, no mark": "profile: dod\n".encode("utf-16-le"),
             "bytes that are not UTF-8": b"# note \xc3(\n", "a NUL byte": b"x\0y\n"}
    for label, raw in cases.items():
        pathlib.Path(d, ".pii-guard").write_bytes(raw)
        r = guard(d, env, "--all")
        subprocess.run(["git", "add", ".pii-guard"], cwd=d, check=True, capture_output=True)
        good = r.returncode == 1 and "PII GUARD FAIL: unknown profile" in r.stdout and "Traceback" not in r.stderr \
            and profile_of(load_allow(d, ":0")) == "unknown"
        subprocess.run(["git", "rm", "-q", "--cached", ".pii-guard"], cwd=d, check=True, capture_output=True)
        check(f".pii-guard with {label}: the scan fails (file and git read)", good)
    pathlib.Path(d, ".pii-guard").write_text("​profile: dod\n", encoding="utf-8")
    check("tier line after a zero-width space: DoD tier", profile_of(load_allow(d)) == "dod")
    pathlib.Path(d, ".pii-guard").write_text("denylist: warn\nProfile:DoD\n")
    r = guard(d, env, "--status")
    good = r.returncode == 0 and "fingerprint " + fingerprint(["alex"]) in r.stdout and "profile: dod" in r.stdout
    check("status: fingerprint and profile", good)


def case_cli_dod_files(d, env):
    """DoD tier on files and commits: a PDF, a binary file, a host and a file over the size limit block; skip clears."""
    pathlib.Path(d, "doc.pdf").write_bytes(b"%PDF-1.4 x")
    pathlib.Path(d, "blob.dat").write_bytes(b"a\0b")
    pathlib.Path(d, "notes.txt").write_text("see " + mil + "\n")
    subprocess.run(["git", "add", "a.txt", "doc.pdf", "blob.dat", "notes.txt"], cwd=d, check=True, capture_output=True)
    r = guard(d, env, "--all")
    good = r.returncode == 1 and r.stdout.count("unscanned") == 2 and "milhost" in r.stdout and "profile dod" in r.stdout \
        and mil not in r.stdout
    check("dod --all: a PDF, a binary file and a host block", good)
    pathlib.Path(d, ".pii-guard").write_text("profile: dod\nskip: doc.pdf\nskip: blob.dat\n" + mil + "\n")
    check("dod --all: skip lines and an allowed host clear them", guard(d, env, "--all").returncode == 0)
    pathlib.Path(d, ".pii-guard").write_text("# minimum\n")
    r = guard(d, env, "--all")
    check("minimum --all: the same files pass", r.returncode == 0 and "profile minimum" in r.stdout)
    idn = ["-c", "user.name=t", "-c", "user.email=1+t" + at + "users.noreply.github" + dot + "com"]
    subprocess.run(["git", *idn, "commit", "-q", "-m", "files"], cwd=d, check=True, capture_output=True)
    found, _ = scan_commits(["HEAD"], d, [], set(), dod=True)
    got = sorted((w.split()[-1], k) for w, _, k, _ in found)
    good = got == [("blob.dat", "unscanned"), ("doc.pdf", "unscanned"), ("notes.txt", "milhost")]
    found, _ = scan_commits(["HEAD"], d, [], {"skip: doc.pdf", "skip: blob.dat", mil}, dod=True)
    good = good and found == [] and scan_commits(["HEAD"], d, [], set())[0] == []
    check(f"dod commits: binary and PDF files block; skip clears; minimum passes: {got}", good)
    pathlib.Path(d, "big.txt").write_text("clean line\n" * (MAX_BYTES // 11 + 10))
    subprocess.run(["git", "add", "big.txt"], cwd=d, check=True, capture_output=True)
    subprocess.run(["git", *idn, "commit", "-q", "-m", "big"], cwd=d, check=True, capture_output=True)
    found, _ = scan_commits(["HEAD~1..HEAD"], d, [], set(), dod=True)
    good = [(w.split()[-1], k) for w, _, k, _ in found] == [("big.txt", "unscanned")] \
        and scan_commits(["HEAD~1..HEAD"], d, [], {"skip: big.txt"}, dod=True)[0] == []
    check("dod commits: a text file over the size limit blocks; skip clears", good)


def case_cli():
    """The CLI cases above, in one temporary repo (each case builds on the state the one before it left)."""
    with tempfile.TemporaryDirectory() as d:
        env = {k: v for k, v in os.environ.items() if not k.startswith(("PII_GUARD", "GIT_"))}
        case_cli_denylist(d, env)
        case_cli_profile(d, env)
        case_cli_dod_files(d, env)


def commit_env():
    """Environment for test commits: a noreply identity named Sam, and no host git settings."""
    env = {**os.environ, "GIT_AUTHOR_NAME": "Sam", "GIT_COMMITTER_NAME": "Sam",
           "GIT_AUTHOR_EMAIL": "1+s" + at + "users.noreply.github" + dot + "com",
           "GIT_COMMITTER_EMAIL": "1+s" + at + "users.noreply.github" + dot + "com"}
    for k in [k for k in env if k.startswith("GIT_") and k not in (
            "GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL")]:
        env.pop(k)
    env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    return env


def case_commit_range(d, run):
    """Commit scan: a range finds the added line and the message; an added '++ ' line is content."""
    run("init", "-q", "-b", "main")
    pathlib.Path(d, "a.txt").write_text("clean\n")
    run("add", "."); run("commit", "-q", "-m", "clean")
    base = git("rev-parse", "HEAD", root=d).strip()
    pathlib.Path(d, "a.txt").write_text("clean\nmail bob" + at + "corp" + dot + "io\n")
    run("add", "."); run("commit", "-q", "-m", "ask Alexandra")
    found, n = scan_commits([f"{base}..HEAD"], d, ["Alexandra"], set())
    kinds = sorted(k for _, _, k, _ in found)
    check(f"commit range: {n} commit(s), {kinds}", n == 1 and kinds == ["email", "name"])
    mid = git("rev-parse", "HEAD", root=d).strip()
    pathlib.Path(d, "a.txt").write_text("clean\nmail bob" + at + "corp" + dot + "io\n++ x\nmail sue" + at + "corp" + dot + "io\n")
    run("add", "."); run("commit", "-q", "-m", "plus lines")
    found, _ = scan_commits([f"{mid}..HEAD"], d, [], {"skip: x"})
    good = [k for _, _, k, _ in found] == ["email"] and all(" a.txt" in w for w, _, _, _ in found)
    check(f"added '++ ' line is content, not a file header: {[k for _, _, k, _ in found]}", good)
    return mid


def case_commit_merge_push(d, run, env, mid):
    """Commit scan: a merge commit keeps its file names, the author email is scanned, and pre-push lines parse."""
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
    check(f"merge commit (diff --cc): file name kept, skip rule applies: {len(found_skip)}, {len(found_all)}", good)
    env["GIT_AUTHOR_EMAIL"] = "me" + at + "home" + dot + "net"
    run("commit", "-q", "--allow-empty", "-m", "x")
    found, _ = scan_commits(["HEAD~1..HEAD"], d, [], set())
    check(f"author email: {[k for _, _, k, _ in found]}", [k for _, _, k, _ in found] == ["email"])
    z = "0" * 40
    head = git("rev-parse", "HEAD", root=d).strip()
    revs = push_revs(f"refs/heads/main {head} refs/heads/main {z}\n(delete) {z} refs/heads/x {head}\n", d)
    check(f"push lines: {revs}", revs == [[head, "--not", "--remotes"]])


def case_commits():
    """The commit-scan cases above, in one temporary repo."""
    with tempfile.TemporaryDirectory() as d:
        env = commit_env()
        run = lambda *a: subprocess.run(["git", *a], cwd=d, env=env, check=True, capture_output=True)
        mid = case_commit_range(d, run)
        case_commit_merge_push(d, run, env, mid)


def hook_cases(d, mail, tok):
    """The sample files and the (name, CLI args, input, wanted exit) cases for --hook, --stdin and named files."""
    pathlib.Path(d, "page.html").write_text("<p>" + mail + "</p>")
    pathlib.Path(d, "clean.html").write_text("<p>hello</p>")
    pathlib.Path(d, "a.pdf").write_bytes(b"%PDF-1.4 fake")
    pathlib.Path(d, "run.html").write_text("a1" * 100_000)  # 200 KB, one line, no "@"
    return [
        ("hook: clean Agent prompt passes", ["--hook"], {"tool_name": "Agent", "cwd": d, "tool_input": {"prompt": "fix the bug"}}, 0),
        ("hook: email in an Agent prompt blocks", ["--hook"], {"tool_name": "Agent", "cwd": d, "tool_input": {"prompt": "mail " + mail}}, 2),
        ("hook: email in a nested list blocks", ["--hook"], {"tool_name": "x", "cwd": d, "tool_input": {"a": [{"b": mail}]}}, 2),
        ("hook: file named by file_path is read", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "page.html"}}, 2),
        ("hook: clean file passes", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "clean.html"}}, 0),
        ("hook: files map source {from} is read", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "clean.html", "files": {"p/x.html": {"from": os.path.join(d, "page.html")}}}}, 2),
        ("hook: file_paths list is read", ["--hook"], {"tool_name": "SendUserFile", "cwd": d, "tool_input": {"file_paths": ["clean.html", "page.html"]}}, 2),
        ("hook: bad JSON blocks", ["--hook"], "{not json", 2),
        ("hook: the project's DoD tier holds with a cwd outside it", ["--hook"], {"tool_name": "Agent", "cwd": "/", "tool_input": {"prompt": "see " + "x" + dot + "af" + dot + "mi" + "l"}}, "dod"),
        ("hook: a crash blocks (deep nesting)", ["--hook"], '{"tool_input": {"prompt": "x", "a": ' + "[" * 3000 + "]" * 3000 + "}}", 2),
        ("hook: a crash blocks (cwd of a wrong type)", ["--hook"], {"tool_name": "Agent", "cwd": 5, "tool_input": {"prompt": "x"}}, 2),
        ("hook: mail recipients are not scanned, the body is", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d, "tool_input": {"to": [mail], "cc": mail, "subject": "hi", "body": "fix the bug"}}, 0),
        ("hook: a token in a mail recipient field blocks", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d, "tool_input": {"to": [mail, tok]}}, 2),
        ("hook: a 'to' key in a non-mail tool is scanned", ["--hook"], {"tool_name": "mcp__Claude_Docs__batch", "cwd": d, "tool_input": {"blocks": {"to": mail}}}, 2),
        ("hook: a nested 'to' key in a mail call is scanned", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d, "tool_input": {"body": {"to": mail}}}, 2),
        ("hook: a long run with no @ ends fast and passes", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "run.html"}}, 0),
        ("hook: named files over the size cap block", ["--hook"], {"tool_name": "SendUserFile", "cwd": d, "tool_input": {"file_paths": ["clean.html", "run.html"]}}, "cap"),
        ("hook: a missing file_path blocks", ["--hook"], {"tool_name": "Artifact", "cwd": d, "tool_input": {"file_path": "no-such.html"}}, 2),
        ("hook: an address in a mail body blocks", ["--hook"], {"tool_name": "mcp__Gmail__send_message", "cwd": d, "tool_input": {"to": [mail], "body": "write to " + mail}}, 2),
        ("hook: a named file it cannot scan blocks (minimum tier)", ["--hook"], {"tool_name": "SendUserFile", "cwd": d, "tool_input": {"file_paths": ["a.pdf"]}}, 2),
        ("file: a named file it cannot scan fails (minimum tier)", [os.path.join(d, "a.pdf")], "", 1),
        ("stdin: email fails", ["--stdin"], "brief: " + mail, 1),
        ("stdin: clean passes", ["--stdin"], "brief: fix the bug", 0),
        ("file: missing path fails", [os.path.join(d, "no-such.md")], "", 1),
        ("file: /dev/stdin is not a regular file: fails", ["/dev/stdin"], "x " + mail, 1),
    ]


def run_hook_in_process(d, text, want):
    """Run the hook in this process (a new Python per case would double the test time); return (exit, stderr, want).
    want "cap" lowers the size cap for the case; want "dod" makes d a DoD-tier project for the case."""
    if want == "dod":  # a DoD-tier project folder for this case only
        pathlib.Path(d, ".pii-guard").write_text("profile: dod\n")
        subprocess.run(["git", "init", "-q"], cwd=d, capture_output=True)
    cap = pii_guard_hook.HOOK_MAX_BYTES
    pii_guard_hook.HOOK_MAX_BYTES = 150_000 if want == "cap" else cap
    err, t0 = io.StringIO(), time.time()
    try:
        with contextlib.redirect_stderr(err):
            code = pii_guard_hook.hook(text)
    finally:
        pii_guard_hook.HOOK_MAX_BYTES = cap
    out = err.getvalue()
    if want == "dod":
        pathlib.Path(d, ".pii-guard").unlink()
    want = 2 if want in ("cap", "dod") else want
    if time.time() - t0 > 5:
        out += " too slow"
        code = -1
    return code, out, want


def case_hook():
    """--hook, --stdin and named files (2026-11-16): a wrong path or bad hook input must never pass."""
    with tempfile.TemporaryDirectory() as d:
        env = {k: v for k, v in os.environ.items() if not k.startswith("PII_GUARD_DENYLIST")}
        env["PII_GUARD_DENYLIST_FILE"] = os.path.join(d, "none.txt")
        mail = "jane" + at + "corp" + dot + "io"
        cases = hook_cases(d, mail, "gh" + "p_" + "A" * 36)
        saved = {k: os.environ.pop(k) for k in list(os.environ) if k.startswith("PII_GUARD_DENYLIST") or k == "CLAUDE_PROJECT_DIR"}
        os.environ["PII_GUARD_DENYLIST_FILE"] = env["PII_GUARD_DENYLIST_FILE"]
        os.environ["CLAUDE_PROJECT_DIR"] = d
        try:
            for name, args, data, want in cases:
                text = data if isinstance(data, str) else json.dumps(data)
                if args == ["--hook"]:
                    code, out, want = run_hook_in_process(d, text, want)
                else:
                    r = subprocess.run(ME + args, cwd=d, env=env, input=text, capture_output=True, text=True)
                    code, out = r.returncode, r.stdout + r.stderr
                check(f"{name} (exit {code})", code == want and mail not in out)  # findings stay masked
        finally:
            os.environ.pop("PII_GUARD_DENYLIST_FILE", None)
            os.environ.pop("CLAUDE_PROJECT_DIR", None)
            os.environ.update(saved)


def case_missing_parts():
    """A copy of pii_guard.py without its parts blocks when run (exit 2, also in the hook) but only raises on import."""
    with tempfile.TemporaryDirectory() as d:
        alone = os.path.join(d, "pii_guard.py")
        with open(ME[1]) as src, open(alone, "w") as dst:
            dst.write(src.read())
        env = {k: v for k, v in os.environ.items() if k != "PYTHONPATH"}   # only the lone copy is importable
        hook = subprocess.run([sys.executable, alone, "--hook"], input="{}", capture_output=True, text=True, cwd=d,
                              env=env)
        check("missing parts: the hook blocks (exit 2)", hook.returncode == 2)
        with open(os.path.join(d, "pii_guard_scan.py"), "w") as part:   # the scan part alone: --hook still blocks
            part.write(open(os.path.join(os.path.dirname(ME[1]), "pii_guard_scan.py")).read())
        hook = subprocess.run([sys.executable, alone, "--hook"], input="{}", capture_output=True, text=True, cwd=d,
                              env=env)
        check("missing hook part: the hook blocks (exit 2)", hook.returncode == 2)
        os.remove(os.path.join(d, "pii_guard_scan.py"))
        imp = subprocess.run([sys.executable, "-c", "try:\n import pii_guard\nexcept ImportError:\n print('raised')"],
                             capture_output=True, text=True, cwd=d, env=env)
        check("missing parts: an importer gets ImportError, not an exit", imp.stdout.strip() == "raised")


def run():
    """Run every case in order; print PII GUARD TEST PASS or FAIL and return the exit code."""
    # The host's git config (forced signing, -c on the command line) must not change the cases.
    for k in ("GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT"):
        os.environ.pop(k, None)
    os.environ.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    for case in (case_speed, case_minimum_patterns, case_secrets_and_masks, case_dod_patterns, case_milhosts_edges,
                 case_milhosts_fallback, case_milhosts_random_speed, case_profile_lines,
                 case_denylist_and_fingerprint, case_cli, case_commits, case_hook, case_missing_parts):
        case()
    print("PII GUARD TEST " + ("FAIL" if FAILED else "PASS"))
    return 1 if FAILED else 0
