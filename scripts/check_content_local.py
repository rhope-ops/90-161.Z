"""This project's own finders for the kit's content check (the extension point in the header of
scripts/check_content_scan.py): the military-host kind uses this project's pattern and linear finder
(scripts/check_content_milhosts.py; decision 2A, 2026-11-16) in place of the kit's pattern.

What it gives: REPLACE = {"milhost": [find_milhost]}; find_milhost(line) yields (start, end, host) for each match.
Inputs:  one line of text (the scanner calls find_milhost); with --test, none.
Outputs: the spans of the matches; with --test, one "ok" or "FAIL" line per case and a last line
         `CHECK_CONTENT_LOCAL pass` or `CHECK_CONTENT_LOCAL fail` (exit 0 or 1).
Network: none.
Writes:  none.
Credentials: none.
Run:     not run alone; the kit's scanner loads it. Self-test: python3 scripts/check_content_local.py --test
         (scripts/check.sh runs it: the full lane always, the fast lane when this file or a file it extends changed).
         Target: Python 3.8+.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # the sibling modules, also when loaded by path

import check_content_milhosts   # noqa: E402 - scripts/check_content_milhosts.py: the pattern and the linear finder


def find_milhost(line):
    """Yield (start, end, host) for each military or DoD cloud host name, by this project's pattern.

    Args:
        line: one line of text.

    Returns:
        An iterator of (start, end, host) tuples, leftmost first.
    """
    return ((m.start(), m.end(), m.group()) for m in check_content_milhosts.milhosts(line))


REPLACE = {"milhost": [find_milhost]}   # the kit's milhost finder is replaced; every other kind stays the kit's


def self_test():
    """Run the milhost cases through the kit's scanner with this module in use, and check that the scanner uses it.

    Returns:
        0 when every case passes, else 1.
    """
    import check_content_scan   # the scanner may only be imported by the self-test (header of check_content_scan.py)
    import check_content_test_milhosts
    failed = []

    def check(label, good):
        """Print one result line and remember a failure."""
        print(("ok    " if good else "FAIL  ") + label)
        if not good:
            failed.append(label)

    def expect(name, text, kinds, dod=False):
        """Scan one text with the scanner and check that the finding kinds are exactly these."""
        got = sorted({k for _, _, k, _ in check_content_scan.scan_text(text, "t", [], set(), dod)})
        check(f"{name}: {got}", got == sorted(kinds))

    in_use = (check_content_scan.FINDERS or {}).get("milhost", [])   # the scanner loads this file as its own module
    check("the scanner uses this module's milhost finder", check_content_scan.LOCAL_ERROR is None and
          [(f.__module__, f.__name__) for f in in_use] == [("check_content_local", "find_milhost")])
    check_content_test_milhosts.run(check, expect)
    print("CHECK_CONTENT_LOCAL " + ("fail" if failed else "pass"))
    return 1 if failed else 0


if __name__ == "__main__" and "--test" in sys.argv[1:]:
    sys.exit(self_test())
