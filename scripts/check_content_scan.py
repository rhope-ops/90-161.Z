"""The scanner of check_content.py: the patterns, the readers of the word lists (names, terms) and of the settings
file (`.check`; the old name `.pii-guard` is still read), and the scans of a text, of files and of commits.

Inputs: text, repo-relative paths or git rev-list arguments; the word lists (environment or file) and the settings file.
Outputs: findings as (where, line number, kind, masked value) tuples; nothing is printed here.
Run: not run alone; check_content.py, check_content_hook.py and check_content_test.py import it (the checks, tiers and limits
are described in the check_content.py header). The patterns and finders of each finding kind: check_content_finders.py.
The readers of the word lists and of the settings file: check_content_scan_settings.py (its names are re-exported here).

A project's own finders (the extension point): when the file scripts/check_content_local.py stands next to this one,
the scanner loads it. The kit has no such file, and the kit's own patterns stay the default. The module defines one
or both of these names (a kind is one of email, secret, phone, id, milhost, dodid, marking):
    REPLACE = {kind: [finder, ...]}   these finders take the place of the kit's finders for that kind (at least one)
    ADD     = {kind: [finder, ...]}   these finders run after the finders of that kind
    finder(line) -> an iterable of (start, end, value): the span of each match in the line of text, and the text
                    that is the finding (it is masked in the output and compared with the allowed strings)
The kinds milhost, dodid and marking run only in the DoD tier, whoever finds them. The module must not import this
scanner when it is loaded (its own self-test may); `python3 scripts/check_content_local.py --test` is that self-test,
and scripts/check.sh runs it when the file has one. A module that cannot be imported, or that has neither name in this
shape, makes every scan fail (LOCAL_ERROR; scan_text raises LocalError) and the hook block: the scanner never falls
back to the kit's patterns, and never to no check. The result line of a scan and --status say when a module is active.
Network: none (it runs local git read commands).
Writes: none.
Credentials: none; it reads the name denylist and the terms list from an environment variable or a file.
"""
import bisect
import os
import pathlib
import re
import subprocess
import sys

import check_content_finders as finders_mod   # scripts/check_content_finders.py: the patterns, the kit's finders, the loader
from check_content_finders import LocalError, emails   # noqa: F401 - LocalError is part of this module's interface
# scripts/check_content_scan_settings.py: the word lists and the settings file (kept apart, docs/code-standard.md C4).
from check_content_scan_settings import (  # noqa: F401 - every name is re-exported: other scripts import them from here
    _TIER, BLOCKED, BOTH_FILES, CONFIG_NAMES, MAX_BYTES, MAX_BYTES_CEILING, MAX_BYTES_LINE, MISSING_HELP, OPTION_LINE,
    OPTION_MAX, PROFILE_LINE, SETTING_LINE, UNKNOWN_PROFILE, UNREADABLE, WARN_OPTION, _clean_entry, _covers, _exists,
    blocked, config_name, denylist_source, dod_mode, fingerprint, is_option_line, is_tier_line, load_allow,
    load_denylist, load_terms, max_bytes_of, parse_denylist, profile_of, skipped, terms_source, warn_mode)

ZERO = re.compile(r"^0+$")
LOCAL_FILE = pathlib.Path(__file__).resolve().parent / finders_mod.LOCAL_NAME   # a project's own finders (see the header)
FINDERS, LOCAL, LOCAL_ERROR = None, "", None   # the finders in use, the note for the result line, why they cannot be used


def use_local(path=None):
    """Set the finders in use: the kit's, with the project's own module at `path` applied when that file exists
    (None = LOCAL_FILE). A module that cannot be used sets LOCAL_ERROR, and then every scan_text call raises."""
    global FINDERS, LOCAL, LOCAL_ERROR
    try:
        (FINDERS, LOCAL), LOCAL_ERROR = finders_mod.load_local(path or LOCAL_FILE), None
    except LocalError as err:
        FINDERS, LOCAL, LOCAL_ERROR = None, "", f"{err}. Correct or remove that file: no scan runs until then"


use_local()
SKIP_SUFFIX = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".zip", ".gz", ".woff", ".woff2", ".ttf")


def mask(kind, s):
    """Show the kind and a length, never enough to rebuild the value (CI logs may be public)."""
    if kind in ("unscanned", "blocked"):
        return s  # a reason, not a value
    if kind in ("name", "term", "secret", "milhost", "marking"):
        return f"<{len(s)} chars>"
    if kind == "email" and "@" in s:
        return "***@" + "*" * len(s.split("@", 1)[1])
    return "*" * (len(s) - 2) + s[-2:] if len(s) > 6 else "*" * len(s)


def _inside(spans):
    """A test for "the span (s, e) lies inside one of these spans", in log time: one sort, then a binary search over
    the starts and a running maximum of the ends (spans may overlap). A plain any() was quadratic on long lines.

    Args:
        spans: the (start, end) spans.

    Returns:
        A function test(s, e) that gives True or False.
    """
    spans = sorted(spans)
    starts = [a for a, _ in spans]
    reach, best = [], -1
    for _, b in spans:
        best = max(best, b)
        reach.append(best)

    def test(s, e):
        """True when the span (s, e) lies inside one of the spans."""
        i = bisect.bisect_right(starts, s) - 1
        return i >= 0 and reach[i] >= e
    return test


def scan_text(text, where, deny, allow, dod=False, terms=()):
    """Return findings (where, line_no, kind, masked) for one text. dod: also run the DoD checks. terms: the Maintainer's
    own blocked words, found like the names (whole word, any case) and reported as kind term.

    Args:
        text: the text to scan.
        where: the name of its place, for the findings.
        deny: the names of the denylist.
        allow: the lines of the settings file (load_allow).
        dod: True in the DoD tier: also run the DoD checks.
        terms: the Maintainer's own blocked words.

    Returns:
        The findings, each (where, line number, kind, masked value).
    """
    if LOCAL_ERROR:
        raise LocalError(LOCAL_ERROR)
    found = []
    kinds = [k for k in finders_mod.KINDS if dod or k not in finders_mod.DOD_KINDS]
    words = list(deny) + list(terms)
    names_low = {w.lower() for w in deny}
    name_re = re.compile(r"(?i)(?<![A-Za-z0-9])(" + "|".join(re.escape(w) for w in words) + r")(?![A-Za-z0-9])") if words else None
    rows = finders_mod.candidate_lines(text, kinds, words, FINDERS)
    if rows == []:   # no line of this text can give a finding
        return found
    # Compiled once per call, used only on a line with a name hit (one finditer per allow line per line was slow).
    allow_res = [re.compile(re.escape(v), re.IGNORECASE) for v in allow if not v.startswith(("skip:", "block:"))] if name_re else []
    hosts_ok = {v.lower() for v in allow} if dod else set()  # a host name has no case
    lines = text.splitlines()
    for i in range(len(lines)) if rows is None else rows:   # only the lines that can give a finding (candidate_lines)
        n, line = i + 1, lines[i]
        hits = []
        in_mail = _inside(m.span() for m in emails(line)) if dod else None  # the host of a mail address is part of that finding
        for kind in kinds:
            for find in FINDERS[kind]:
                hits += [(kind, val) for s, e, val in find(line) if kind != "milhost" or not in_mail(s, e)]
        names = list(name_re.finditer(line)) if name_re else []
        if names:
            in_allowed = _inside((s.start(), s.end()) for rx in allow_res for s in rx.finditer(line))
            hits += [("name" if m.group(1).lower() in names_low else "term", m.group(1)) for m in names
                     if not in_allowed(m.start(1), m.end(1))]  # inside an allowed string
        seen = set()  # values already reported on this line, of any kind (a set: a list scan was quadratic)
        for kind, val in hits:
            if val in allow or (kind == "milhost" and val.lower() in hosts_ok) or val in seen:
                continue
            seen.add(val)
            found.append((where, n, kind, mask(kind, val)))
    return found


def git(*args, root="."):
    """Run git in root and return its stdout as text; a git error raises CalledProcessError."""
    return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True,
                          errors="replace").stdout


def scan_files(paths, root, deny, allow, dod=False, named=False, terms=()):
    """dod, or named (the caller named these files: FILE mode, the hook): a file that cannot be scanned is a finding
    (kind unscanned) unless a `skip:` line names it. A path that a `block:` line names is a finding (kind blocked).

    Args:
        paths: the repo-relative paths.
        root: the repo root (a folder path).
        deny: the names of the denylist.
        allow: the lines of the settings file (load_allow).
        dod: True in the DoD tier: also run the DoD checks.
        named: True when the caller named these files.
        terms: the Maintainer's own blocked words.

    Returns:
        The findings, each (where, line number, kind, masked value).
    """
    limit = max_bytes_of(allow)   # once per call, not once per file
    job = (root, deny, allow, dod, named, terms, limit)
    parts = _in_parallel(paths, root, job) if not named else None   # named files (FILE mode, the hook): this process
    if parts is None:
        parts = [_scan_path(p, job) for p in paths]
    return [f for part in parts for f in part]


PARALLEL_BYTES = 4_000_000   # a scan of fewer bytes runs in this process: starting a pool costs more than it saves


def usable_cores():
    """The number of cores this process may use (its CPU affinity where the system has one), at least 1."""
    return len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else (os.cpu_count() or 1)


def _in_parallel(paths, root, job):
    """The findings of each path, in the order of paths, from a pool of processes (speed only; the same findings as
    the scan in this process). None when the scan is small, the machine has one core, or a pool cannot start.

    Args:
        paths: the repo-relative paths.
        root: the repo root (a folder path).
        job: the arguments of _scan_path after the path.

    Returns:
        A list with the findings of each path, or None.
    """
    try:
        cores = usable_cores()
        size = sum(os.path.getsize(f) for f in (os.path.join(root, p) for p in paths) if os.path.isfile(f))
    except OSError:
        return None
    if cores < 2 or len(paths) < 2 or size < PARALLEL_BYTES:
        return None
    import concurrent.futures
    import functools
    import multiprocessing
    try:
        ctx = multiprocessing.get_context("fork" if sys.platform.startswith("linux") else None)   # fork: no new imports
        with concurrent.futures.ProcessPoolExecutor(min(cores, 8), mp_context=ctx) as pool:
            return list(pool.map(functools.partial(_scan_path, job=job), paths, chunksize=8))
    except (OSError, concurrent.futures.process.BrokenProcessPool):   # no pool here: scan in this process
        return None


def _scan_path(p, job):
    """The findings of one path (scan_files).

    Args:
        p: the repo-relative path.
        job: (root, deny, allow, dod, named, terms, limit), as in scan_files; limit: max_bytes_of(allow).

    Returns:
        The findings, each (where, line number, kind, masked value).
    """
    root, deny, allow, dod, named, terms, limit = job
    f = pathlib.Path(root) / p
    rel = os.path.relpath(f, root).replace(os.sep, "/") if os.path.isabs(str(p)) else str(p)
    if f.is_file() and blocked(rel, allow):
        return [(str(p), 0, "blocked", BLOCKED)]
    if skipped(str(p), allow) or not f.is_file():
        return []
    why = None
    if f.suffix.lower() in SKIP_SUFFIX:
        why = f"file type {f.suffix.lower()} is not scanned"
    elif f.stat().st_size > limit:
        why = f"larger than {limit} bytes"
    else:
        data = f.read_bytes()
        if b"\0" in data[:8192]:
            why = "binary file"
    if why:
        return [(str(p), 0, "unscanned", why)] if dod or named else []
    return scan_text(data.decode("utf-8", "replace"), str(p), deny, allow, dod, terms)


def commit_meta(sha, root, deny, allow, dod, terms):
    """Findings in a commit's author and committer identity and in its message."""
    lines = git("show", "-s", "--format=%an%n%ae%n%cn%n%ce%n%B", sha, root=root).split("\n")
    out = []
    for part, text in (("author/committer", "\n".join(lines[:4])), ("message", "\n".join(lines[4:]))):
        out += [(f"commit {sha[:7]} {part}", n, k, v) for _, n, k, v in scan_text(text, "", deny, allow, dod, terms)]
    return out


def blocked_in_commit(sha, root, allow):
    """Findings (kind blocked) for each file this commit adds or changes (a merge: against its first parent) that a
    `block:` line names."""
    names = git("-c", "core.quotepath=off", "show", "--format=", "--name-only", "-z", "--no-renames", "-m",
                "--first-parent", "--diff-filter=AM", sha, root=root)
    return [(f"commit {sha[:7]} {n}", "+", "blocked", BLOCKED) for n in filter(None, names.split("\0"))
            if blocked(n, allow)]


def unscanned_in_commit(sha, root, allow, unscanned):
    """DoD tier: the files one commit adds or changes that cannot be scanned (too large, a file type that is not
    scanned, binary), unless a `skip:` line names them. numstat marks a binary file with "-"; the patch has no added
    lines for it.

    Args:
        sha: the commit.
        root: the repo root.
        allow: the lines of the settings file (load_allow).
        unscanned: a set that gets the name of each file over the size limit, so its patch lines are not scanned again.

    Returns:
        The findings (where, "+", "unscanned", reason).
    """
    found, short, limit = [], sha[:7], max_bytes_of(allow)   # once per commit, not once per file
    stat = git("-c", "core.quotepath=off", "show", "--format=", "--numstat", "-z", "--no-renames",
               "--diff-filter=AM", sha, root=root)
    sizes = {}
    for rec in filter(None, git("ls-tree", "-r", "-l", "-z", sha, root=root).split("\0")):
        info, _, name = rec.partition("\t")
        size = info.split()[-1]
        if size.isdigit():
            sizes[name] = int(size)
    for rec in filter(None, stat.split("\0")):
        parts = rec.split("\t", 2)
        if len(parts) != 3 or skipped(parts[2], allow):
            continue
        if sizes.get(parts[2], 0) > limit:
            unscanned.add(parts[2])
            found.append((f"commit {short} {parts[2]}", "+", "unscanned", f"larger than {limit} bytes"))
        elif parts[2].lower().endswith(SKIP_SUFFIX):
            found.append((f"commit {short} {parts[2]}", "+", "unscanned", "file type is not scanned"))
        elif parts[0] == "-":
            found.append((f"commit {short} {parts[2]}", "+", "unscanned", "binary file"))
    return found


def scan_commits(revs, root, deny, allow, dod=False, terms=()):
    """revs: arguments for git rev-list. Scan each commit's identity, message and added lines.
    dod: an added or changed file that cannot be scanned is a finding unless a `skip:` line names it.
    A file that a commit adds or changes under a `block:` line is a finding (kind blocked).

    Args:
        revs: the arguments for git rev-list.
        root: the repo root (a folder path).
        deny: the names of the denylist.
        allow: the lines of the settings file (load_allow).
        dod: True in the DoD tier: also run the DoD checks.
        terms: the Maintainer's own blocked words.

    Returns:
        (findings, the number of commits scanned).
    """
    found = []
    shas = git("rev-list", *revs, root=root).split()
    has_block = any(a.startswith("block:") for a in allow)
    for sha in shas:
        short = sha[:7]
        unscanned = set()  # dod: files already reported as unscanned; their patch lines are not scanned again
        found += commit_meta(sha, root, deny, allow, dod, terms)
        if has_block:
            found += blocked_in_commit(sha, root, allow)
        if dod:
            found += unscanned_in_commit(sha, root, allow, unscanned)
        patch = git("-c", "core.quotepath=off", "show", "--format=", "--unified=0", "--no-color", "--no-ext-diff",
                    "--src-prefix=a/", "--dst-prefix=b/", sha, root=root)
        cur, in_header, added = "?", False, []

        def flush():  # one scan per file, not one per added line (a large file has many lines)
            if added and not cur.endswith(SKIP_SUFFIX) and cur not in unscanned and not skipped(cur, allow):
                found.extend((f"commit {short} {cur}", "+", k, v) for _, _, k, v in scan_text("\n".join(added), "", deny, allow, dod, terms))
            added.clear()

        for line in patch.splitlines():
            # A "+++ " line names the file only in a file header (after "diff --git", before the first "@@").
            # In a hunk it is an added line that starts with "++ ", and must be scanned like any other.
            if line.startswith(("diff --git ", "diff --cc ", "diff --combined ")):  # the last two: merge commits
                flush()
                in_header = True
            elif line.startswith("@@"):
                in_header = False
            elif in_header and line.startswith("+++ "):
                name = line[4:].split("\t", 1)[0]
                if len(name) > 1 and name[0] == name[-1] == '"':
                    name = name[1:-1].replace('\\"', '"').replace("\\\\", "\\")
                cur = name[2:] if name.startswith("b/") else name
            elif line.startswith("+"):
                added.append(line[1:])
        flush()
    return found, len(shas)


def push_revs(stdin_text, root):
    """Turn pre-push stdin lines into rev-list argument lists (one per pushed ref).

    Args:
        stdin_text: the lines git gives a pre-push hook on stdin.
        root: the repo root (a folder path).

    Returns:
        A list of rev-list argument lists.
    """
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
