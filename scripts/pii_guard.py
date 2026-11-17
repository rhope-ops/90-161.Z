#!/usr/bin/env python3
"""Block personal data and secrets before they reach the remote: emails, phone numbers, ID-number shapes, API tokens
and private keys, and names from a denylist that is kept outside the repo.

Usage:
    python3 scripts/pii_guard.py --all             # every tracked file (working tree)
    python3 scripts/pii_guard.py --range A..B      # commits in A..B: added lines, messages, author and committer
    python3 scripts/pii_guard.py --push            # pre-push hook mode: reads the hook's stdin lines
    python3 scripts/pii_guard.py FILE ...          # these files (a missing, unreadable or non-regular path fails)
    python3 scripts/pii_guard.py --stdin [--label NAME]  # text on stdin: a brief, PR text or message before it is sent
    python3 scripts/pii_guard.py --hook            # Claude Code PreToolUse hook: scans the tool call's input and the
                                                   # files it names (file_path, file_paths, files); exit 2 blocks the call
    python3 scripts/pii_guard.py --status          # denylist source, entry count and fingerprint (never the names), profile
    --require-denylist                             # fail when no denylist is found (the hook and the Action use it),
                                                   # or only warn when .pii-guard has the line `denylist: warn`
    python3 scripts/pii_guard.py --test            # self-test; prints PII GUARD TEST PASS

Opt-in: the guard runs only in a repo with a `.pii-guard` file at its root (the hook and the Action check for it).
That file lists exact strings that are allowed (one per line, `#` comments), and paths to skip as
`skip: <path or glob>` lines (for example a public reference text that quotes office contacts), and the option line
`denylist: warn` (starter tier; kit default since 2026-11-13): with no denylist, --require-denylist warns instead of failing. Only the PFM adds entries;
agents never add one to get past a block (AGENTS.md "Personal data").

Two tiers (the PFM, 2026-11-15), set in `.pii-guard`:
    minimum    no option line: the checks under "Checks".
    DoD        the option line `profile: dod`: the minimum checks plus the checks under "DoD checks"; a missing
               denylist always blocks (`denylist: warn` is ignored). In the Action the line is read from the
               pull-request base (--allow-from), so a pull request cannot lower its own tier.

Name denylist (never committed): one name or word per line, `#` comments, matched whole-word, any case.
    - env PII_GUARD_DENYLIST: the list itself (newline or comma separated); the GitHub Action reads it from the
      Actions secret of the same name.
    - env PII_GUARD_DENYLIST_FILE, else ~/.config/pii-guard/denylist.txt
With no denylist, names are not checked and the guard says so (exit code unchanged).
Fingerprint: 8 hex characters of SHA-256 over the list (lower case, no duplicates, sorted). Every copy of the same
list prints the same fingerprint, whatever its order or separators: compare the places to find a copy that differs.

Checks:
    email      any address, except *@users.noreply.github.com, noreply@ / no-reply@ addresses, and the
               reserved example domains (example.com/.org/.net, *.example, *.invalid, *.test, *.localhost)
    phone      US numbers (NNN-NNN-NNNN, (NNN) NNN-NNNN, NNN.NNN.NNNN), +country numbers
    id         SSN shape (NNN-NN-NNNN), or 9 digits next to SSN / social security
    secret     API tokens (GitHub, GitLab, AWS, Anthropic, OpenAI, Google, Slack, Stripe) and private-key headers
    name       denylist words
DoD checks (only with `profile: dod`):
    milhost    a host name in the US military top-level domain (also inside a URL), and the DoD cloud hosts in MILHOST
    marking    controlled-information and classification banner marks (the list: MARKING below)
    dodid      10 digits next to a DoD ID keyword (the list: DODID below)
    unscanned  a file the guard cannot read: a SKIP_SUFFIX type, a binary file (Office files too) or one over
               MAX_BYTES. It blocks unless a `skip: <path or glob>` line names it.
Known limits of the DoD checks: the scanner reads one line at a time, so a keyword on one line and its number on
the next pass; a binary file that enters only through a merge resolution is found by --all, not by the commit scan;
a one-word classification alone on a line is a mark in upper case only (in title case it is an ordinary heading).
A tier line in any form other than `profile: dod`, and a `.pii-guard` that is not UTF-8 text, fail the scan: a wrong
spelling or a wrong file encoding cannot lower the tier in silence. Limit: a line with both the key and the value
misspelt is not seen as a tier line; `--status` and the result line always print the tier in use.
Matches are printed masked (names and secrets as a length only), so CI logs do not repeat them. Exit 1 when anything is found.
Standard library only. Needs git (except for FILE mode).
The code is split by concern into modules next to this file: pii_guard_scan.py (the patterns and scans),
pii_guard_hook.py (--hook) and pii_guard_test.py (--test).
"""
import argparse
import os
import subprocess
import sys

# denylist_source and warn_mode are not used here: first_use_check.py reads them as pii_guard.denylist_source and
# pii_guard.warn_mode, so they stay attributes of this module.


def missing_part(err):
    """Stop with exit 2 when a part of the guard is missing: a copy without its parts must block, not pass (exit 2
    also blocks the PreToolUse hook)."""
    print('PII GUARD FAIL: %s; copy pii_guard_scan.py, pii_guard_hook.py and pii_guard_test.py next to '
          'pii_guard.py (scripts/sync_baseline.py does this)' % err, file=sys.stderr)
    sys.exit(2)


try:
    from pii_guard_scan import (MISSING_HELP, UNKNOWN_PROFILE, WARN_OPTION, denylist_source, fingerprint, git,
                                is_option_line, load_allow, load_denylist, profile_of, push_revs, scan_commits,
                                scan_files, scan_text, skipped, warn_mode)
except ImportError as err:
    if __name__ != '__main__':
        raise   # an importer (first_use_check.py) handles it and keeps its other output
    missing_part(err)


def report(found, what, deny, dod=False):
    """Print each finding and the PASS or FAIL line; return the exit code."""
    for where, n, kind, val in found:
        print(f"pii-guard: {where}:{n}: {kind}: {val}")
    names = (f"names checked ({len(deny)} denylist entries, fingerprint {fingerprint(deny)})" if deny
             else "names NOT checked (no denylist)")
    print(f"PII GUARD {'FAIL' if found else 'PASS'}: {len(found)} finding(s) in {what}; {names}; "
          f"profile {'dod' if dod else 'minimum'}")
    return 1 if found else 0


def parse_args():
    """Read the command line; stop with a usage error when no mode or target is given."""
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--all", action="store_true", help="scan every tracked file")
    ap.add_argument("--range", help="scan commits in this range (A..B)")
    ap.add_argument("--push", action="store_true", help="pre-push mode: read the hook's stdin")
    ap.add_argument("--allow-from", metavar="REF", help="read .pii-guard from this git ref (CI: the PR base), not the tree")
    ap.add_argument("--require-denylist", action="store_true", help="fail when no name denylist is found")
    ap.add_argument("--status", action="store_true", help="print the denylist source and entry count, never the names")
    ap.add_argument("--stdin", action="store_true", help="scan the text on stdin")
    ap.add_argument("--label", default="stdin", help="name for --stdin text in the findings")
    ap.add_argument("--hook", action="store_true", help="Claude Code PreToolUse hook mode (JSON on stdin)")
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    if not (a.test or a.hook or a.status or a.files or a.all or a.range or a.push or a.stdin):
        ap.error("give --all, --range, --push, --stdin, --hook, --status or files")
    return a


def repo_root():
    """The top folder of the git repo here, or "." outside a repo or without git."""
    try:
        return git("rev-parse", "--show-toplevel").strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "."


def show_status():
    """--status: print the denylist source, entry count and fingerprint (never the names), and the tier."""
    _, src = denylist_source()
    deny = load_denylist()
    n = len(deny)
    top = repo_root()
    print(f"denylist: {n} entries from {src}; fingerprint {fingerprint(deny)}" if src and n
          else "denylist: none (" + MISSING_HELP + ")")
    prof = profile_of(load_allow(top))
    print("profile: " + (prof if prof != "unknown" else "UNKNOWN (" + UNKNOWN_PROFILE + ")"))
    return 0 if n and prof != "unknown" else 1


def scan_targets(a, root, deny, allow, dod, revsets):
    """Scan what the command line names (tracked files, files, stdin, commits); return (findings, what parts)."""
    found, what = [], []
    if a.all:
        files = git("ls-files", "-z", root=root).split("\0")
        found += scan_files([f for f in files if f], root, deny, allow, dod)
        what.append(f"{len([f for f in files if f])} tracked files")
    if a.files:
        rel = [os.path.relpath(os.path.abspath(f), root) for f in a.files]
        # A named path that cannot be read is a finding: a wrong path must never print PASS.
        found += [(f, 0, "unscanned", "missing, unreadable or not a regular file") for f, r in zip(a.files, rel)
                  if not skipped(r, allow) and not (os.path.isfile(f) and os.access(f, os.R_OK))]
        found += scan_files(rel, root, deny, allow, dod, named=True)
        what.append(f"{len(a.files)} file(s)")
    if a.stdin:
        found += scan_text(sys.stdin.read(), a.label, deny, allow, dod)
        what.append(a.label)
    n = 0
    for revs in revsets:
        f, k = scan_commits(revs, root, deny, allow, dod)
        found += f
        n += k
    if revsets:
        what.append(f"{n} commit(s)")
    return found, what


def main():
    """Run the mode the command line asks for and return its exit code."""
    a = parse_args()
    if a.test:
        import pii_guard_test  # scripts/pii_guard_test.py: kept apart (docs/code-standard.md C4)
        return pii_guard_test.run()
    if a.hook:
        try:
            import pii_guard_hook  # scripts/pii_guard_hook.py: loaded only for --hook
        except ImportError as err:
            missing_part(err)
        return pii_guard_hook.hook(None)
    if a.status:
        return show_status()
    root = repo_root()
    deny, allow = load_denylist(), load_allow(root, a.allow_from)
    prof = profile_of(allow)
    if prof == "unknown":
        print("PII GUARD FAIL: " + UNKNOWN_PROFILE)
        return 1
    dod = prof == "dod"
    warn_only = WARN_OPTION in allow and not dod
    allow = {v for v in allow if not is_option_line(v)}
    revsets = [[a.range]] if a.range else []
    if a.push:
        revsets += push_revs(sys.stdin.read(), root)
    deletes_only = a.push and not revsets and not (a.all or a.files or a.range)
    if a.require_denylist and not deny and not deletes_only:
        if not warn_only:
            print("PII GUARD FAIL: " + MISSING_HELP)
            return 1
        print("PII GUARD WARNING: names are not checked (.pii-guard has 'denylist: warn'); every other check runs. "
              + MISSING_HELP)
    found, what = scan_targets(a, root, deny, allow, dod, revsets)
    skips = sorted(v[5:].strip() for v in allow if v.startswith("skip:"))
    if skips:
        what.append(f"{len(skips)} skip rule(s): {', '.join(skips)}")
    return report(found, ", ".join(what) or "nothing", deny, dod)


if __name__ == "__main__":
    sys.exit(main())
