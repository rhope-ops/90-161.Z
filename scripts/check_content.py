#!/usr/bin/env python3
"""The content check of scripts/check.sh: blocks personal data, secrets and the Maintainer's own blocked content before
they reach the remote or leave in a tool call. One scanner for emails, phone numbers, ID-number shapes, API tokens and
private keys, names and terms from word lists kept outside the repo, and files the settings file blocks.

Usage (scripts/check.sh --content passes its arguments here):
    python3 scripts/check_content.py --all             # every tracked file (working tree)
    python3 scripts/check_content.py --range A..B      # commits in A..B: added lines, messages, author and committer
    python3 scripts/check_content.py --push            # pre-push hook mode: reads the hook's stdin lines
    python3 scripts/check_content.py FILE ...          # these files (a missing, unreadable or non-regular path fails)
    python3 scripts/check_content.py --stdin [--label NAME]  # text on stdin: a brief, PR text or message before it is sent
    python3 scripts/check_content.py --hook            # Claude Code PreToolUse hook: scans the tool call's input and the
                                                       # files it names; exit 2 blocks the call (check_content_hook.py)
    python3 scripts/check_content.py --status          # word-list sources, entry counts and fingerprints (never the words), profile
    --require-denylist                                 # fail when no name denylist is found (pre-push and the Action use it),
                                                       # or only warn when the settings file has the line `denylist: warn`
    python3 scripts/check_content.py --test            # self-test; prints CONTENT CHECK TEST PASS

Settings file: `.check` at the repo root (the old name `.pii-guard` is still read when `.check` is absent). The
pre-push hook, scripts/check.sh and the Action scan only in a repo that has it; the PreToolUse hook always scans.
One entry per line, `#` comments:
    <exact string>          allowed although it looks like a finding
    skip: <path or glob>    not scanned (for example a public reference text that quotes office contacts)
    block: <path or glob>   must not be committed or sent (a glob with no "/" matches the file name in any folder)
    denylist: warn          with no name denylist, --require-denylist warns instead of failing (starter projects)
    profile: dod            the DoD tier (below)
Only the Maintainer adds an allowed string or a skip line; agents never add one to get past a block (AGENTS.md
"Secrets and personal data").

Two tiers (the Maintainer, 2026-11-15):
    minimum    no profile line: the checks under "Checks".
    DoD        `profile: dod`: the minimum checks plus the checks under "DoD checks"; a missing denylist always
               blocks (`denylist: warn` is ignored). In the Action the settings are read from the pull-request base
               (--allow-from), so a pull request cannot lower its own tier or widen its own allow list.

Word lists (never committed): one name or word per line, `#` comments, matched whole-word, any case.
    names (personal data)   env PII_GUARD_DENYLIST (newline or comma separated; the Action reads the Actions secret
                            of the same name), else env PII_GUARD_DENYLIST_FILE, else ~/.config/pii-guard/denylist.txt
    terms (the Maintainer's own blocked words: a client, a code name; optional)
                            env CHECK_TERMS (Actions secret CHECK_TERMS), else env CHECK_TERMS_FILE, else
                            ~/.config/check/terms.txt
With no name denylist, names are not checked and the result line says so (exit code unchanged).
Fingerprint: 8 hex characters of SHA-256 over a list (lower case, no duplicates, sorted). Every copy of the same
list prints the same fingerprint, whatever its order or separators: compare the places to find a copy that differs.

Checks:
    email      any address, except *@users.noreply.github.com, noreply@ / no-reply@ addresses, and the
               reserved example domains (example.com/.org/.net, *.example, *.invalid, *.test, *.localhost)
    phone      US numbers (NNN-NNN-NNNN, (NNN) NNN-NNNN, NNN.NNN.NNNN), +country numbers
    id         SSN shape (NNN-NN-NNNN), or 9 digits next to SSN / social security
    secret     API tokens (GitHub, GitLab, AWS, Anthropic, OpenAI, Google, Slack, Stripe) and private-key headers
    name       words of the name denylist
    term       words of the terms list
    blocked    a tracked, pushed or named file that a `block:` line names
DoD checks (only with `profile: dod`):
    milhost    a host name in the US military top-level domain (also inside a URL), and the DoD cloud hosts in MILHOST
    marking    controlled-information and classification banner marks (the list: MARKING)
    dodid      10 digits next to a DoD ID keyword (the list: DODID)
    unscanned  a file the scanner cannot read: a SKIP_SUFFIX type, a binary file (Office files too) or one over
               MAX_BYTES (a `content-max-bytes: <number>` line in .check raises it; the tool-call hook keeps its
               own limit on the total of the files one call names, HOOK_MAX_BYTES in scripts/check_content_hook.py,
               which that line does not change). It blocks unless a `skip: <path or glob>` line names it.
Known limits of the DoD checks: the scanner reads one line at a time, so a keyword on one line and its number on
the next pass; a binary file that enters only through a merge resolution is found by --all, not by the commit scan;
a one-word classification alone on a line is a mark in upper case only (in title case it is an ordinary heading).
A tier line in any form other than `profile: dod`, and a settings file that is not UTF-8 text, fail the scan: a wrong
spelling or a wrong file encoding cannot lower the tier in silence. Limit: a line with both the key and the value
misspelt is not seen as a tier line; `--status` and the result line always print the tier in use.
Matches are printed masked (names, terms and secrets as a length only), so CI logs do not repeat them. Exit 1 when anything is found.
Standard library only. Needs git (except for FILE mode).
A project's own finders: a file scripts/check_content_local.py replaces or adds finders for a finding kind (the
interface: the header of check_content_scan.py). The result line and --status say when it is active; when it cannot
be loaded, every scan fails and the hook blocks. Limit: that file is the project's own trusted code, like any script
a hook runs; a file that ends the process itself while it loads (os._exit) ends the scan with its own exit code (0 lets a hooked call run).
The code is split by concern into modules next to this file: check_content_scan.py (the scans) with check_content_scan_settings.py (the word lists and the settings file),
check_content_finders.py (the patterns and finders), check_content_hook.py (--hook) and check_content_test.py (--test).
Network: none (it runs local git read commands).
Writes: none (findings go to stdout or stderr; the self-test uses temporary folders).
Credentials: none; it reads the name denylist and the terms list (environment variable or file) and never prints an entry.
"""
import argparse
import os
import subprocess
import sys

if "--hook" in sys.argv[1:]:   # before the scanner (and a project's own module) loads: a load that hangs must block
    import signal
    if hasattr(signal, "SIGALRM"):
        signal.signal(signal.SIGALRM, lambda *_: os._exit(2))   # exit 2 blocks the tool call
        # Seconds: 8, or the one character "1" to "7" that a test sets. No number is parsed, so no value can raise.
        signal.alarm({"1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7}.get(os.environ.get("CHECK_HOOK_LOAD_S"), 8))

# denylist_source and warn_mode are not used here: first_use_check.py reads them as check_content.denylist_source and
# check_content.warn_mode, so they stay attributes of this module.


def missing_part(err):
    """Stop with exit 2 when a part of the guard is missing: a copy without its parts must block, not pass (exit 2
    also blocks the PreToolUse hook)."""
    print('CONTENT CHECK FAIL: %s; copy check_content_scan.py, check_content_scan_settings.py, check_content_finders.py, check_content_hook.py and '
          'the check_content_test*.py files next to check_content.py (scripts/sync_baseline.py does this)' % err, file=sys.stderr)
    sys.exit(2)


try:
    import check_content_scan as scan   # for the state of a project's own finders (LOCAL, LOCAL_ERROR)
    from check_content_scan import (MISSING_HELP, UNKNOWN_PROFILE, WARN_OPTION, denylist_source, fingerprint, git,
                                    is_option_line, load_allow, load_denylist, load_terms, profile_of, push_revs,
                                    scan_commits, scan_files, scan_text, skipped, terms_source, warn_mode)
except ImportError as err:
    if __name__ != '__main__':
        raise   # an importer (first_use_check.py) handles it and keeps its other output
    missing_part(err)


def report(found, what, deny, dod=False, terms=()):
    """Print each finding and the PASS or FAIL line; return the exit code.

    Args:
        found: the findings, each (where, line number, kind, masked value).
        what: what was scanned, for the result line.
        deny: the names of the denylist.
        dod: True in the DoD tier.
        terms: the Maintainer's own blocked words.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    for where, n, kind, val in found:
        print(f"check: {where}:{n}: {kind}: {val}")
    names = (f"names checked ({len(deny)} denylist entries, fingerprint {fingerprint(deny)})" if deny
             else "names NOT checked (no denylist)")
    if terms:
        names += f"; {len(terms)} terms checked (fingerprint {fingerprint(terms)})"
    print(f"CONTENT CHECK {'FAIL' if found else 'PASS'}: {len(found)} finding(s) in {what}; {names}; "
          f"profile {'dod' if dod else 'minimum'}" + (f"; {scan.LOCAL}" if scan.LOCAL else ""))
    return 1 if found else 0


def parse_args():
    """Read the command line; stop with a usage error when no mode or target is given.

    Returns:
        The parsed arguments (argparse namespace).
    """
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--all", action="store_true", help="scan every tracked file")
    ap.add_argument("--range", help="scan commits in this range (A..B)")
    ap.add_argument("--push", action="store_true", help="pre-push mode: read the hook's stdin")
    ap.add_argument("--allow-from", metavar="REF", help="read the settings file from this git ref (CI: the PR base), not the tree")
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
    """--status: print the denylist source, entry count and fingerprint (never the names), and the tier.

    Returns:
        The exit code: 0 when a denylist exists and the tier line is valid, else 1.
    """
    _, src = denylist_source()
    deny = load_denylist()
    n = len(deny)
    top = repo_root()
    print(f"denylist: {n} entries from {src}; fingerprint {fingerprint(deny)}" if src and n
          else "denylist: none (" + MISSING_HELP + ")")
    terms, tsrc = load_terms(), terms_source()[1]
    if terms:
        print(f"terms: {len(terms)} entries from {tsrc}; fingerprint {fingerprint(terms)}")
    prof = profile_of(load_allow(top))
    print("profile: " + (prof if prof != "unknown" else "UNKNOWN (" + UNKNOWN_PROFILE + ")"))
    if scan.LOCAL or scan.LOCAL_ERROR:
        print("finders: " + (scan.LOCAL or "FAIL (" + scan.LOCAL_ERROR + ")"))
    return 0 if n and prof != "unknown" and not scan.LOCAL_ERROR else 1


def scan_targets(a, root, deny, allow, dod, revsets, terms=()):
    """Scan what the command line names (tracked files, files, stdin, commits); return (findings, what parts).

    Args:
        a: the parsed arguments (parse_args).
        root: the repo root (a folder path).
        deny: the names of the denylist.
        allow: the lines of the settings file (load_allow).
        dod: True in the DoD tier: also run the DoD checks.
        revsets: the git rev-list argument lists of the commits to scan.
        terms: the Maintainer's own blocked words.

    Returns:
        (findings, the list of what was scanned).
    """
    found, what = [], []
    if a.all:
        files = git("ls-files", "-z", root=root).split("\0")
        found += scan_files([f for f in files if f], root, deny, allow, dod, terms=terms)
        what.append(f"{len([f for f in files if f])} tracked files")
    if a.files:
        rel = [os.path.relpath(os.path.abspath(f), root) for f in a.files]
        # A named path that cannot be read is a finding: a wrong path must never print PASS.
        found += [(f, 0, "unscanned", "missing, unreadable or not a regular file") for f, r in zip(a.files, rel)
                  if not skipped(r, allow) and not (os.path.isfile(f) and os.access(f, os.R_OK))]
        found += scan_files(rel, root, deny, allow, dod, named=True, terms=terms)
        what.append(f"{len(a.files)} file(s)")
    if a.stdin:
        found += scan_text(sys.stdin.read(), a.label, deny, allow, dod, terms)
        what.append(a.label)
    n = 0
    for revs in revsets:
        f, k = scan_commits(revs, root, deny, allow, dod, terms)
        found += f
        n += k
    if revsets:
        what.append(f"{n} commit(s)")
    return found, what


def main():
    """Run the mode the command line asks for and return its exit code.

    Returns:
        The exit code: 0 pass, 1 fail; in hook mode 0 lets the call run and 2 blocks it.
    """
    a = parse_args()
    if a.test:
        import check_content_test  # scripts/check_content_test.py: kept apart (docs/code-standard.md C4)
        return check_content_test.run()
    if a.hook:
        try:
            import check_content_hook  # scripts/check_content_hook.py: loaded only for --hook
        except ImportError as err:
            missing_part(err)
        return check_content_hook.hook(None)
    if a.status:
        return show_status()
    if scan.LOCAL_ERROR:   # a project's own finders cannot be used: no scan runs, and none passes
        print("CONTENT CHECK FAIL: " + scan.LOCAL_ERROR)
        return 1
    root = repo_root()
    deny, terms, allow = load_denylist(), load_terms(), load_allow(root, a.allow_from)
    prof = profile_of(allow)
    if prof == "unknown":
        print("CONTENT CHECK FAIL: " + UNKNOWN_PROFILE)
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
            print("CONTENT CHECK FAIL: " + MISSING_HELP)
            return 1
        print("CONTENT CHECK WARNING: names are not checked (the settings file has 'denylist: warn'); every other check runs. "
              + MISSING_HELP)
    found, what = scan_targets(a, root, deny, allow, dod, revsets, terms)
    skips = sorted(v[5:].strip() for v in allow if v.startswith("skip:"))
    if skips:
        what.append(f"{len(skips)} skip rule(s): {', '.join(skips)}")
    return report(found, ", ".join(what) or "nothing", deny, dod, terms)


if __name__ == "__main__":
    sys.exit(main())
