#!/usr/bin/env python3
"""The rule table of the code standard check and the measures of one function: the debt kinds with their labels and
caps (RULE), the opt-in rules (OPT_IN), the language of each file extension, and the per-function rules C2, C2 full,
C3 and the body hash for C5.

Prevents: a function or a file that breaks the code standard unseen: the rule table, the opt-in rules and the per-function
measures that scripts/code_standard.py checks.

Part of scripts/code_standard.py (split out to keep each file under the line cap of docs/code-standard.md C4);
code_standard.py imports every name here and re-exports it, so `code_standard.<name>` keeps working. These functions
read no state of the check (no repo root, no gate): the check passes in what they need.
Inputs:  the settings, a file's text and lines, and one function as the parser gives it (scripts/code_standard_parse.py).
Outputs: violations written into the dict the caller passes; no output of its own.
Usage:   imported by scripts/code_standard.py; it has no command line.
Network: none.
Writes: none.
Credentials: none.
"""
import fnmatch
import hashlib
import re
import shutil
from pathlib import Path

import check_settings as settings   # scripts/check_settings.py: STRICT, dash, OPT_IN_CAPS
import code_standard_docs as docs   # scripts/code_standard_docs.py: rule C2 full
import code_standard_parse as parse   # scripts/code_standard_parse.py: the function finders

LINTERS = all(shutil.which(t) for t in ('ruff', 'pylint'))   # C10 for Python: the linters when both are installed, else here


LANGS = {'.py': 'python', '.ps1': 'powershell', '.psm1': 'powershell', '.js': 'js', '.mjs': 'js', '.cjs': 'js', '.sh': 'shell'}
MIN_HEADER_CHARS = 60      # a header shorter than this does not say what the file is for
SAFETY_LABELS = ('Network:', 'Writes:', 'Credentials:')   # C1 safety: what a reviewer must find before a run
# The opt-in rules: the debt kind of each and its level in a config (0 = off). Only these can be adopted later.
OPT_IN = {'docs': lambda c: int(c.get('c2') == 'full'),
          'safety': lambda c: 2 if c.get('c1_safety') == settings.STRICT else int(bool(c.get('c1_safety')))}
PREVENTS = re.compile(r'^[ \t]*Prevents:[ \t]*(?!(?:unclear|unknown|tbd|todo|none|n/?a|see|tba)\b|\?)\S+(?:[ \t]+\S+){2}', re.M | re.I)   # C1: the defect a check stops, 3+ words, no placeholder
ENTRY_FILES = ('scripts/check.sh', '.claude/settings.json')   # plus scripts/git-hooks/* and .github/workflows/*: what runs a check
MIN_DUP_LINES = 4          # a body this short (a one-line wrapper) is not counted as a duplicate


def gate_settings(config):
    """Return the `code-` lines in a config that only a gate enforces (the check fails when one is set with no gate)."""
    lines = ['code-' + settings.dash(c) for c in settings.OPT_IN_CAPS if c in config['caps']]
    return lines + (['code-c1-safety: ' + settings.STRICT] if config.get('c1_safety') == settings.STRICT else [])


def matches(rel, patterns):
    """True when the path matches one of the glob patterns (fnmatch; `*` also matches `/`)."""
    return any(fnmatch.fnmatch(rel, p) for p in patterns)


def file_functions(p, text, lang, ps):
    """Return the functions of one source file, in the shapes parse.powershell_functions() gives.

    Args:
        p: the repo-relative path.
        text: the whole file.
        lang: its language (lang_of).
        ps: the result of parse.powershell_functions() for the repo's PowerShell files.

    Returns:
        (functions, blocks, parse errors).
    """
    if lang == 'powershell':
        return ps[p]
    if lang == 'python':
        try:
            return parse.python_functions(text), [], []
        except SyntaxError as err:   # C10 for Python: ruff and pylint in scripts/check.sh; this check only without them
            return [], [], [] if LINTERS else ['line %s: %s' % (err.lineno, err.msg)]
    pattern, mark = (parse.JS_FUNC, '//') if lang == 'js' else (parse.SH_FUNC, '#')
    return parse.brace_functions(text, pattern, mark), [], []


def function_rules(v, entry, p, lines, func, extra, ctx):
    """Write the violations of one function into `v` (C2 comment, C2 full, C3 length) and note its body for C5.

    Args:
        v: the violations dict, changed in place.
        entry: the report entry of the file; its "functions" list gets this function.
        p: the repo-relative path.
        lines: the file's lines.
        func: (name, top, first line, last line, has inner comment, body text).
        extra: the PowerShell parser's doc facts for this function, or None.
        ctx: per-file facts: lang, head_last, seen (names so far), full (C2 full is on), py (python_docs or None),
            cap (the function cap) and bodies ({body hash: [keys]}, shared by all files).
    """
    name, top, start, end, inner, body = func
    key = unique_key(p, name, ctx['seen'])
    size, commented = end - start + 1, inner or parse.has_comment_above(lines, top, ctx['head_last'])
    entry['functions'].append({'name': name, 'start': start, 'lines': size, 'comment': commented})
    if not commented:
        v['comment'][key] = 1
    gaps = docs.missing(ctx['lang'], lines, func, extra, ctx['py']) if ctx['full'] else []
    if gaps:
        v['docs'][key] = 1
        entry['functions'][-1]['docs_missing'] = gaps
    if size > ctx['cap']:
        v['length'][key] = size
    norm = '\n'.join(x.strip() for x in body.split('\n') if x.strip() and not x.strip().startswith(('#', '//')))
    if norm.count('\n') + 1 >= MIN_DUP_LINES:
        ctx['bodies'].setdefault(hashlib.sha256(norm.encode()).hexdigest()[:12], []).append(key)


def unique_key(p, name, seen):
    """Return the debt key of a function: "<path>::<name>", with "#2", "#3" for the next ones of the same name."""
    seen[name] = seen.get(name, 0) + 1
    return '%s::%s' % (p, name if seen[name] == 1 else '%s#%d' % (name, seen[name]))


# Each debt kind: its label, and for a kind whose debt value is a size (it may only go down) the cap it is measured
# against (the label then holds one %d). A project's own gate may add kinds (rules()).
RULE = {'header': ('C1 no header comment', None), 'comment': ('C2 function without a comment', None),
        'length': ('C3 function longer than %d lines', 'max_function_lines'),
        'file_size': ('C4 file longer than %d lines', 'max_file_lines'),
        'prevents': ('C1 check entry point without a "Prevents: <defect>" header line', None),
        'duplicate': ('C5 same body as another function', None),
        'generated': ('C6 generated file without a GENERATED banner', None),
        'parse': ('C10 PowerShell or Python file that does not parse', None),
        'safety': ('C1 safety: header without the Network:, Writes: and Credentials: lines', None),
        'docs': ('C2 full: function without full docs (--report names the missing parts)', None)}


def is_kit(root):
    """True in the kit itself: it has kit.config.json and no `.check.lock` (a synced project has the lock)."""
    return (root / 'kit.config.json').is_file() and not (root / '.check.lock').exists()


# Debt kinds that only warn: no FAIL, not in the baseline. C4 file size (the Maintainer, 2026-11-23, decision 1 = A: a line count is
# a proxy that a split games), everywhere. C1 Prevents (AUD-1; the Maintainer, 2026-11-23): a FAIL in the kit, a WARN in a project
# until its debt is 0. The kit is told by the folder of this file, the same root as scripts/code_standard.py ROOT.
WARN_KINDS = ('file_size',) if is_kit(Path(__file__).resolve().parent.parent) else ('file_size', 'prevents')


def entry_points(root):
    """Return the check entry points of a repo: the non-test scripts (scripts/*.py and scripts/*.sh) that a file that
    runs checks names (scripts/check.sh, a git hook, a Claude Code hook setting or a workflow). A *_test file never counts.

    Args:
        root: the repo root (a Path).

    Returns:
        A set of repo-relative paths of scripts that exist.
    """
    files = [root / f for f in ENTRY_FILES] + sorted((root / 'scripts/git-hooks').glob('*')) \
        + sorted((root / '.github/workflows').glob('*.y*ml'))
    text = '\n'.join(f.read_text(encoding='utf-8', errors='replace') for f in files if f.is_file())
    named = set(re.findall(r'scripts/[\w.-]+?\.(?:py|sh)\b', text))
    return {n for n in named if (root / n).is_file() and not re.search(r'_test|^test_', n.split('/')[-1])}


def warn_lines(now, caps, limit=10):
    """Return the WARN lines of the kinds in WARN_KINDS: each file with its number (file size), at most `limit` per kind.
    The `prevents` kind is in WARN_KINDS in a project only; in the kit compare() fails it.

    Args:
        now: the violations measured now {kind: {key: value}}.
        caps: the caps of the settings.
        limit: the most files named per kind; the rest is a count.

    Returns:
        A list of WARN lines.
    """
    out = []
    for kind in WARN_KINDS:
        items = sorted(now.get(kind, {}).items(), key=lambda kv: (-kv[1], kv[0]))
        label = RULE[kind][0] % caps.get(RULE[kind][1], 0) if RULE[kind][1] else RULE[kind][0]
        out += ['WARN  %s: %s%s' % (label, k, '' if v == 1 else ' (%d)' % v) for k, v in items[:limit]]
        if len(items) > limit:
            out.append('WARN  %s: and %d more (--report lists every file)' % (label, len(items) - limit))
    return out


def summary(v):
    """One line: the count of each kind of debt."""
    return ', '.join('%s %d' % (k, len(items)) for k, items in v.items())
