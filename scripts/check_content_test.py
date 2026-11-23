"""Self-test of scripts/check_content.py (run by `python3 scripts/check_content.py --test`; kept in its own file so the guard
stays under the line cap of docs/code-standard.md C4).

It proves every check on built-at-run-time samples (no real address, token, host, mark or ID is in this file): the
patterns and their speed on long lines, the allow and skip lines, the tiers and the settings-file reader (under its old name .pii-guard), the denylist
sources, the CLI modes (--all, --push, --status, --stdin, files) in temporary git repos, the commit scan, and the
PreToolUse hook (in process).
Input: none (temporary folders only; the host's git config is switched off). Output: one "ok" or "FAIL" line per
case, then CONTENT CHECK TEST PASS or FAIL; run() returns the exit code 0 or 1. Needs git.
Network: none.
Writes: temporary folders only.
Credentials: none (the sample secrets are built at run time and are not real).
"""
import os
import re
import shutil
import tempfile
import time
import unittest

import check_content_scan
from check_content_scan import (OPTION_MAX, denylist_source, fingerprint, is_option_line, load_denylist, mask,
                                parse_denylist, profile_of, scan_text, skipped)
# scripts/check_content_test_cli.py: the CLI, commit and hook cases, and the result recorder (kept apart, C4).
from check_content_test_cli import (FAILED, ME, at, case_cli, case_cli_denylist, case_cli_dod_files,  # noqa: F401
                                    case_cli_profile, case_commit_merge_push, case_commit_range, case_commits,
                                    case_hook, check, commit_env, dot, guard, hook_cases, mil, run_hook_in_process, x36)


def expect(name, text, kinds, deny=(), allow=(), dod=False):
    """Scan one text and check that the finding kinds are exactly these."""
    got = sorted({k for _, _, k, _ in scan_text(text, "t", list(deny), set(allow), dod)})
    check(f"{name}: {got}", got == sorted(kinds))


def case_speed():
    """Long lines (address chains, host runs, many distinct values) scan in linear time (CPU time of this process,
    so checks that run at the same time do not count)."""
    expect("personal email", "mail jane" + at + "corp" + dot + "io", ["email"])
    t0 = time.process_time()
    chain = len(scan_text(("a" + at + "b" + dot + "cc+") * 20_000, "t", [], set()))  # 200 KB of joined addresses
    secs = time.process_time() - t0  # the first address and the "+" joined one; scan_text drops repeats
    check(f"200 KB chain of joined addresses: linear ({secs:.2f} s)", 1 <= chain <= 2 and secs < 2)
    teams = "api" + dot + "dod" + dot + "teams" + dot + "microsoft" + dot + "us"
    expect("a DoD Teams host with a subdomain", "see https://" + teams + "/x", ["milhost"], dod=True)
    for label, run in (("a.", "a." * 100_000), ("a-a.", "a-a." * 50_000), ("a.dod.", "a.dod." * 33_000)):
        t0 = time.process_time()
        scan_text(run, "t", [], set(), True)
        secs = time.process_time() - t0
        check(f"200 KB of {label!r}: MILHOST linear ({secs:.2f} s)", secs < 2)
    t0 = time.process_time()
    many = "".join("a" + str(i) + at + "b" + dot + "cc " for i in range(17_600))  # 200 KB of distinct addresses
    many += "".join("h" + str(i) + dot + "mil " for i in range(5_000)) + "Jane Doe" * 18_000  # hosts, allowed names
    scan_text(many, "t", ["jane"], {"Jane Doe"}, True)
    secs = time.process_time() - t0
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
        t0 = time.process_time()
        good = profile_of({h}) != "dod" and is_option_line(h) in (True, False) and good
        slow = max(slow, time.process_time() - t0)
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


def without_local(kit, blocks):
    """Make the cases prove the kit's own patterns, also in a project that has its own finders: copy the scripts of
    the content check, without the project's module, into `kit`, point the command line of the cases at that copy, and
    set the finders of this process to the kit's. (The project's module proves itself: its own --test.)

    Args:
        kit: an empty temporary folder.
        blocks: the module check_content_test_blocks (it has its own command line for the cases).
    """
    here = os.path.dirname(os.path.abspath(__file__))
    for name in os.listdir(here):
        if name.startswith("check_content") and name.endswith(".py") and name != check_content_scan.LOCAL_FILE.name:
            shutil.copy(os.path.join(here, name), kit)
    ME[1] = blocks.ME[1] = os.path.join(kit, "check_content.py")
    check_content_scan.use_local(os.path.join(kit, check_content_scan.LOCAL_FILE.name))   # no such file: the kit's finders


def run():
    """Run every case in order; print CONTENT CHECK TEST PASS or FAIL and return the exit code.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    # The host's git config (forced signing, -c on the command line) must not change the cases.
    for k in ("GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT"):
        os.environ.pop(k, None)
    os.environ.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    os.environ.pop("CHECK_TERMS", None)  # the host's terms list must not change the cases
    os.environ["CHECK_TERMS_FILE"] = os.path.join(tempfile.gettempdir(), "no-such-terms-file.txt")
    import check_content_test_blocks  # the cases for terms, block lines, the .check name and the write and Bash tools
    import check_content_test_local   # the cases for a project's own finders (scripts/check_content_local.py)
    with tempfile.TemporaryDirectory() as kit:
        without_local(kit, check_content_test_blocks)
        for case in (case_speed, case_minimum_patterns, case_secrets_and_masks, case_dod_patterns, case_profile_lines,
                     case_denylist_and_fingerprint, case_cli, case_commits, case_hook):
            case()
        check_content_test_blocks.run(check)
        check_content_test_local.run(check, kit)
    print("CONTENT CHECK TEST " + ("FAIL" if FAILED else "PASS"))
    return 1 if FAILED else 0


class CheckContentTest(unittest.TestCase):
    """The cases of `python3 scripts/check_content.py --test`, for `python3 -m unittest` and pytest. They run in order
    in one test: they share the copy of the kit and the finders of this process."""

    def test_self_test(self):
        """Every case passes; the environment and the finders that run() changes are put back after it."""
        saved, me = dict(os.environ), list(ME)
        self.addCleanup(check_content_scan.use_local)
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(saved), ME.__setitem__(slice(None), me)))
        self.assertEqual(run(), 0, "failed cases: %s" % FAILED)
