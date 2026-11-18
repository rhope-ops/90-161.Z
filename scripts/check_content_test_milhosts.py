"""This project's cases of the military-host finder (scripts/check_content_local.py --test runs them): the linear
finder milhosts() of scripts/check_content_milhosts.py (decision 2A, 2026-11-16, the same cases as rhope-ops/RADE;
the kit keeps its own pattern and has no finder).

It proves that milhosts() gives the matches of MILHOST.finditer on the pattern's edge cases and on 2,000 random lines,
that it falls back to the pattern when its model gives a wrong span, and that it runs in linear time on 200 KB runs.
Input: none (samples are built at run time, so this file does not flag itself).
Output: one "ok" or "FAIL" line per case through the check() and expect() functions that run() gets.
Network: none.
Writes: none.
Credentials: none.
Run:     python3 scripts/check_content_local.py --test (target: Python 3.8+ on Linux, the cloud workspace).
"""
import random
import time

import check_content_milhosts

at, dot = "@", "."  # addresses and hosts are joined at run time, so this file does not flag itself


def run(check, expect):
    """Run the milhosts() cases.

    Args:
        check: prints one result line and remembers a failure (label, good).
        expect: scans one text and checks its finding kinds (name, text, kinds, dod=...).
    """
    case_milhosts_edges(check, expect)
    case_milhosts_fallback(check)
    case_milhosts_random_speed(check)


def case_milhosts_edges(check, expect):
    """milhosts() gives the matches of MILHOST.finditer (RADE decision 2A, 2026-11-16) on the pattern's edge cases.

    Args:
        check: prints one result line and remembers a failure (label, good).
        expect: scans one text and checks its finding kinds (name, text, kinds, dod=...).
    """
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
        old = [m.group() for m in check_content_milhosts.MILHOST.finditer(text)]
        new = [m.group() for m in check_content_milhosts.milhosts(text)]
        check(f"milhosts: {label}: {len(new)} matches", old == new == want)
    expect("dod milhost: hyphen inside a label", "see my-base" + dot + mi, ["milhost"], dod=True)
    expect("dod milhost: after a leading hyphen", "-unit" + dot + mi, ["milhost"], dod=True)
    expect("dod: not a host: label ends in a hyphen", "Gmail-to-" + dot + mi, [], dod=True)
    expect("dod: not a host: hyphen before the dot", "a-" + dot + "unit-" + dot + mi, [], dod=True)


def case_milhosts_fallback(check):
    """With a model that gives a wrong span, milhosts() falls back to the pattern from the last good end.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    mi = "mi" + "l"
    host = "a" + dot + mi
    text = host + " x" + dot + mi + " y" + dot + mi
    real_spans = check_content_milhosts._milhost_spans
    try:
        for label, fake in (("a skipped match", [(12, 14)]), ("a wrong end after a good match", [(0, 5), (12, 14)]),
                            ("a repeated span", [(0, 5), (0, 5)])):
            check_content_milhosts._milhost_spans = lambda line, fake=fake: iter(fake)
            got = [m.span() for m in check_content_milhosts.milhosts(text)]
            want = [m.span() for m in check_content_milhosts.MILHOST.finditer(text)]
            check(f"milhosts fallback: {label}: {got}", got == want == [(0, 5), (6, 11), (12, 17)])
        check_content_milhosts._milhost_spans = lambda line: iter([(6, 11), (0, 5)])  # a span before the last: no repeat, in order
        got = [m.span() for m in check_content_milhosts.milhosts(text)]
        check(f"milhosts fallback: a span out of order: {got}", got == [(6, 11), (12, 17)])
    finally:
        check_content_milhosts._milhost_spans = real_spans


def case_milhosts_random_speed(check):
    """milhosts() matches the pattern on 2,000 random lines and runs in linear time on 200 KB runs.

    Args:
        check: prints one result line and remembers a failure (label, good).
    """
    mi = "mi" + "l"
    spm, tms = "sharepoint-" + mi + dot + "us", "dod" + dot + "teams" + dot + "microsoft" + dot + "us"
    rnd = random.Random(2)
    tokens = ["-", "--", dot, dot * 2, mi, dot + mi, mi.upper(), "a", "x-", "b" * 63, "c" * 64, spm, spm.upper(), tms, "us",
              "dod" + dot, "teams" + dot, at, "https://", " ", "_", "é", "ı", "ſ", "K", "a" + dot, "-a" + dot]
    diffs = 0
    for _ in range(2_000):
        text = "".join(rnd.choice(tokens) for _ in range(rnd.randint(1, 30)))
        diffs += [m.span() for m in check_content_milhosts.MILHOST.finditer(text)] != [m.span() for m in check_content_milhosts.milhosts(text)]
    check(f"milhosts: 2,000 random lines, same matches as the pattern ({diffs} differ)", diffs == 0)
    for label, text in (("a.", "a." * 100_000), ("a. then a host", "a." * 99_998 + mi), ("a-a. then a host", "a-a." * 49_999 + mi),
                        ("x- then a host", "x-" * 99_997 + "a" + dot + mi), ("63-character labels", ("b" * 63 + dot) * 3_125),
                        ("a. then a tenant host", "a." * 99_991 + spm), ("meeting hosts", (tms + dot) * 8_695),
                        ("hosts and empty labels", ("a" + dot + mi + dot * 2) * 28_571),
                        ("short runs", ("a.a.a.a.a.a.a.a.a." + mi + " ") * 9_090), ("short hosts", ("a" + dot + mi + " ") * 33_333),
                        ("runs at the short limit", (("a" + dot) * 10 + mi + "- ") * 7_692),
                        ("runs just over the short limit", (("a" + dot) * 10 + mi + dot + "- ") * 7_692)):
        t0 = time.process_time()   # CPU time of this process: other checks running at once do not count
        sum(1 for _ in check_content_milhosts.milhosts(text))
        took = time.process_time() - t0
        check(f"milhosts: 200 KB of {label}: linear ({took:.3f} s)", took < 0.5)
