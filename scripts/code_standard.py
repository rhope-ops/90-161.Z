#!/usr/bin/env python3
"""Code standard check: measures every source file of this repo against docs/code-standard.md and fails on new debt.

Why: the Maintainer, 2026-11-17: all code is lean, modular, commented and human-editable, and stays so as work continues.
A written rule alone is not always obeyed, so this check fails a push or a pull request instead. The kit owns this
file; a project gets it by sync, keeps its own settings in its `.check` file and its own stricter rules in its own
gate file (below), never in a copy of this file.

What it measures (the rule numbers are those of docs/code-standard.md):
  C1 header      each source file starts with a header comment that says what the file is for
  C1 safety      opt-in (`code-c1-safety: on`): the header also has the labels Network:, Writes: and Credentials:
  C2 comment     each function has a comment: a docstring, comment-based help, or a comment line directly above it
                 or as the first line of its body (one line is enough)
  C2 full        opt-in (`code-c2: full`): a function longer than 10 lines also documents each
                 parameter and its return value in its language's help form (scripts/code_standard_docs.py)
  C3 length      each function is at most `max_function_lines` lines long
  C4 file size   each source file is at most `max_file_lines` lines long; a `code-paste:` file (a script a person
                 pastes into another tool) at most `max_file_lines_paste`
  C5 duplicate   no two functions in hand-written files have the same body (a copy must be generated, with a banner)
  C6 generated   each generated file says GENERATED near its top and names its source
  C10 parse      each Python and PowerShell file parses
A comment that is the file header, or a divider line ("# ----", "# ===="), does not count as a function's comment.
A script block passed as an argument ($b.Add_Click({ ... })) is measured for C3 too, named by the call it is in.
Settings: the `code-` lines of `.check` (caps, scope, opt-in rules; read by scripts/check_settings.py, which lists
the keys; a line that is not valid fails this check).
The ratchet: `.check.state.json` ("code_standard": {"debt": ...}) lists the debt that existed when the standard
started. A violation that is not in that list fails. A listed function that grew fails. A listed item that is fixed
fails too, until the baseline is lowered in the same change (`--update`), so the list can only shrink and always
matches the code. The baseline and the settings are compared with those on the merge base with origin/main: an added
item, a raised value or a changed `code-` setting fails, unless the same change adds a row to docs/DECISIONS.md that
names `.check` (the Maintainer's decision). A merge base that still has the old .code-standard.json is compared from it.

A project's own gate (the extension point): when the file scripts/code_standard_gate.py stands next to this one, the
check loads it and calls it. The kit has no gate file. A gate that cannot be imported, or lacks one of the five names
below, fails the check; so do the settings `code-max-line-chars` and `code-c1-safety: strict` with no gate file
(they are a gate's to enforce). The kit's own gate scripts/code_standard_strict.py is that gate for a project that sets
`code-strict-gate: on` and has no gate file of its own. The self-test of this file runs without the gate; scripts/check.sh runs the gate's
own self-test (`python3 scripts/code_standard_gate.py --test`) when the gate file has one.
  RULES             {debt kind: (label, caps key or None)}: debt kinds the gate adds or relabels. With a caps key the
                    debt value is a size that may only go down, and the label holds one %d for the cap.
  OPT_IN            {debt kind: level(config) -> int}: opt-in kinds the gate adds or replaces (0 = off). A kind whose
                    level is above the one on main may list its debt once with --adopt.
  file_rules(v, path, lines, head, config, skip)   called for each source file after the kit's own per-file rules;
                    it writes its violations into v[kind][path] and may remove one the kit wrote. head is the header
                    text (one header line per text line), skip the (first, last) lines of the generated blocks.
  decided(root, ref) -> (bool, [refusal lines])    replaces the kit's test "docs/DECISIONS.md gained a line that names
                    `.check`"; ref is the merge base with origin/main. The refusal lines are printed with a failure.
  new_debt_refusal(root, ref, kind, key) -> a FAIL line or None   asked for each debt key that main's list lacks; a
                    FAIL line is a problem that no decision lifts (for example debt for a file that is new).

Inputs:  the files git tracks (git ls-files -z): files with a known extension, and files with no extension whose first
         line is a shell or Python shebang (for example scripts/git-hooks/pre-push); filtered by the settings.
Outputs: one line per problem, then `CODE-STANDARD pass` or `CODE-STANDARD fail`; exit 0 or 1.
Usage:   python3 scripts/code_standard.py            check (scripts/check.sh runs it in both lanes)
         python3 scripts/code_standard.py --report   print every measurement (function lengths, comments)
         python3 scripts/code_standard.py --update   lower the baseline to the debt that is left; refuses new debt
         python3 scripts/code_standard.py --init     write the first baseline (only when the repo has none)
         python3 scripts/code_standard.py --adopt    add the debt of a rule the baseline does not list yet (a rule just
                                                     turned on, such as `code-c2: full`); needs a DECISIONS row
         python3 scripts/code_standard.py --test     prove the check on small sample repos (scripts/code_standard_test.py)
Network: none (it runs local git read commands, and pwsh to parse PowerShell files).
Writes:  .check.state.json, only with --init, --update or --adopt (and Python's __pycache__ when it imports its modules).
Credentials: none.
Parts:   scripts/code_standard_rules.py (the rule table, the per-function measures), scripts/code_standard_ratchet.py
         (the baseline against main, --adopt), scripts/code_standard_parse.py and scripts/code_standard_docs.py.
Needs:   Python 3.8+, git, and pwsh 7 only when the repo has PowerShell files (the parser gives the function list).
"""

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

import check_settings as settings   # scripts/check_settings.py: the reader of .check and of .check.state.json
import code_standard_docs as docs   # scripts/code_standard_docs.py: the opt-in C2 full rule
import code_standard_parse as parse   # scripts/code_standard_parse.py: headers, generated blocks, function finders
import code_standard_ratchet as ratchet   # scripts/code_standard_ratchet.py: the baseline against main, and --adopt
# scripts/code_standard_rules.py: the rule table and the measures of one function (kept apart, rule C4).
from code_standard_rules import (LANGS, MIN_DUP_LINES, MIN_HEADER_CHARS, OPT_IN, RULE, SAFETY_LABELS,  # noqa: F401
                                 file_functions, function_rules, gate_settings, matches, summary, unique_key)

ROOT = Path(__file__).resolve().parent.parent
# A project's own gate (the header lists its five names). GATE is the loaded module, or None: load() sets it.
GATE_FILE = Path(__file__).resolve().parent / 'code_standard_gate.py'
STRICT_FILE = Path(__file__).resolve().parent / 'code_standard_strict.py'   # the kit's strict rules: `code-strict-gate: on`
GATE_NAMES = ('RULES', 'OPT_IN', 'file_rules', 'decided', 'new_debt_refusal')
GATE = None


# ---------------------------------------------------------------- a project's own gate ------------------------------

def load_gate(path=None):
    """Load a project's own gate module when its file exists.

    Args:
        path: the gate file; None = GATE_FILE (next to this file).

    Returns:
        The module, or None when there is no such file. ValueError when the file cannot be imported or lacks one of
        GATE_NAMES in the documented shape (the check then fails: a broken gate is never skipped).
    """
    path = Path(path or GATE_FILE)
    if not path.is_file():
        return None
    try:
        spec = importlib.util.spec_from_file_location('code_standard_gate', str(path))
        gate = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gate)
    except BaseException as err:   # noqa: B036 - any error or exit of the project's file: the check fails with its name
        raise ValueError('the gate %s cannot be loaded (%s: %s)' % (path.name, err.__class__.__name__, err)) from None
    lacks = [n for n in GATE_NAMES if not hasattr(gate, n)]
    if lacks:
        raise ValueError('the gate %s lacks %s (the entry points: the header of scripts/code_standard.py)'
                         % (path.name, ', '.join(lacks)))
    shaped = isinstance(gate.RULES, dict) and isinstance(gate.OPT_IN, dict) \
        and all(isinstance(r, tuple) and len(r) == 2 and isinstance(r[0], str) for r in gate.RULES.values()) \
        and all(callable(x) for x in list(gate.OPT_IN.values()) + [gate.file_rules, gate.decided, gate.new_debt_refusal])
    if not shaped:
        raise ValueError('the gate %s has a wrong shape: RULES is {kind: (label, caps key or None)}, OPT_IN is '
                         '{kind: function}, the three other names are functions' % path.name)
    return gate


def rules():
    """Return {debt kind: (label, caps key or None)}: the kit's rules (RULE), with those a gate adds or relabels."""
    return dict(RULE, **(GATE.RULES if GATE else {}))


def level(kind, config):
    """Return how far the opt-in rule of debt kind `kind` is adopted in `config` (0 = off or not an opt-in kind)."""
    known = dict(OPT_IN, **(GATE.OPT_IN if GATE else {}))
    return int(known[kind](config)) if kind in known else 0


# ---------------------------------------------------------------- file list -----------------------------------------

def tracked_files(config):
    """Return the repo-relative paths that the standard covers: tracked files with a known extension that match
    `include` and no `exclude` pattern. Paths that match `generated` are returned too (they get check C6 only).

    Args:
        config: the code standard settings.

    Returns:
        The sorted list of paths.
    """
    out = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '-z'], capture_output=True, text=True, check=True).stdout
    keep = []
    for rel in out.split('\0'):
        if not rel or (lang_of(rel) is None and not matches(rel, config.get('generated', []))):
            continue
        if not matches(rel, config.get('include', ['*'])) or matches(rel, config.get('exclude', [])):
            continue
        if (ROOT / rel).is_file():
            keep.append(rel)
    return sorted(keep)


def lang_of(rel):
    """Return the language of a file: by its extension, or for a file with no extension by its shebang line
    (sh or bash: shell; python: python); None for any other file.

    Args:
        rel: the repo-relative path.

    Returns:
        'python', 'powershell', 'js', 'shell' or None.
    """
    suffix = Path(rel).suffix
    if suffix:
        return LANGS.get(suffix)
    try:
        first = (ROOT / rel).read_bytes()[:80].split(b'\n')[0].decode('ascii', 'replace')
    except OSError:
        return None
    if first.startswith('#!') and re.search(r'\b(ba)?sh\b', first):
        return 'shell'
    if first.startswith('#!') and 'python' in first:
        return 'python'
    return None


# ---------------------------------------------------------------- measure ----------------------------------------------


def file_rules(v, p, lines, head, config, skip):
    """Write the per-file violations of one source file into `v`: C1 header, C1 safety and C4 file size (a `code-paste:`
    file against `max_file_lines_paste`); then a project's own gate adds its per-file rules.

    Args:
        v: the violations dict {kind: {key: value}}, changed in place.
        p: the repo-relative path.
        lines: the file's lines.
        head: the header text (parse.header_block).
        config: the code standard settings.
        skip: the (first, last) line numbers of the generated blocks.
    """
    if len(head) < MIN_HEADER_CHARS:
        v['header'][p] = 1
    if config.get('c1_safety') and not all(x in head for x in SAFETY_LABELS):
        v['safety'][p] = 1
    paste = matches(p, config.get('paste', []))   # a script a person pastes into another tool: its own cap
    if len(lines) > config['caps']['max_file_lines_paste' if paste else 'max_file_lines']:
        v['file_size'][p] = len(lines)
    if GATE:
        GATE.file_rules(v, p, lines, head, config, skip)


def measure_file(v, p, config, ps, bodies):
    """Measure one hand-written source file: its per-file rules, its functions and its script blocks.

    Args:
        v: the violations dict, changed in place.
        p: the repo-relative path.
        config: the code standard settings.
        ps: the result of parse.powershell_functions() for the repo's PowerShell files.
        bodies: {body hash: [keys]} of the functions seen so far (rule C5), changed in place.

    Returns:
        The report entry of the file.
    """
    text = (ROOT / p).read_text(encoding='utf-8-sig', errors='replace')
    lines, lang = text.split('\n'), lang_of(p)
    funcs, blocks, errors = file_functions(p, text, lang, ps)
    head, head_last = parse.header_block(lines, lang)
    entry = {'lines': len(lines), 'header': len(head), 'functions': [], 'blocks': [], 'errors': errors}
    if errors:
        v['parse'][p] = len(errors)
    skip = parse.generated_blocks(lines)
    file_rules(v, p, lines, head, config, skip)
    full = config.get('c2') == 'full' and not errors
    ctx = {'lang': lang, 'head_last': head_last, 'seen': {}, 'full': full, 'bodies': bodies,
           'py': docs.python_docs(text) if full and lang == 'python' else None, 'cap': config['caps']['max_function_lines']}
    for name, top, start, end, inner, body, *extra in funcs:
        if not any(a <= start <= b for a, b in skip):
            function_rules(v, entry, p, lines, (name, top, start, end, inner, body), extra[0] if extra else None, ctx)
    for name, start, end in blocks:
        if any(a <= start <= b for a, b in skip):
            continue
        key = unique_key(p, name, ctx['seen'])
        entry['blocks'].append({'name': name, 'start': start, 'lines': end - start + 1})
        if end - start + 1 > ctx['cap']:
            v['length'][key] = end - start + 1
    return entry


def measure(config):
    """Measure every covered file.

    Args:
        config: the code standard settings.

    Returns:
        {"files": {path: {...}}, "violations": {kind: {key: value}}}.
    """
    files = tracked_files(config)
    generated = [p for p in files if matches(p, config.get('generated', []))]
    source = [p for p in files if p not in generated]
    ps = parse.powershell_functions(ROOT, [p for p in source if lang_of(p) == 'powershell'], config.get('c2') == 'full')
    report, v = {}, {k: {} for k in rules()}
    bodies = {}
    for p in generated:
        if not parse.is_generated_ok((ROOT / p).read_text(encoding='utf-8-sig', errors='replace').split('\n')):
            v['generated'][p] = 1
    for p in source:
        report[p] = measure_file(v, p, config, ps, bodies)
    for keys in bodies.values():
        if len(keys) > 1:
            for k in keys:
                v['duplicate'][k] = len(keys)
    return {'files': report, 'violations': v}


# ---------------------------------------------------------------- ratchet ----------------------------------------------


def compare(now, debt, caps):
    """Compare the measured violations with the debt list.

    Args:
        now: the violations measured now {kind: {key: value}}.
        debt: the baseline's debt list, in the same shape.
        caps: the caps of the settings.

    Returns:
        (new problems, fixed items). New: a violation not in the debt, or a debt value that grew. Fixed: a debt item
        that is gone or smaller (the baseline must be lowered in the same change).
    """
    new, fixed = [], []
    table = rules()
    for kind, items in now.items():
        text, cap = table[kind]
        label = text % caps.get(cap, 0) if cap else text
        old = debt.get(kind, {})
        for key, value in sorted(items.items()):
            if key not in old:
                new.append('FAIL  %s: %s%s' % (label, key, '' if value == 1 else ' (%d)' % value))
            elif value > old[key] and cap:
                new.append('FAIL  %s: %s grew from %d to %d' % (label, key, old[key], value))
        for key, value in sorted(old.items()):
            if key not in items or (cap and items[key] < value):
                fixed.append('FIXED %s: %s' % (label, key))
    return new, fixed


def git(*args):
    """Run git in the repo root; return the finished process (text output)."""
    return subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True, text=True)


def decided_at(ref):
    """Return (decided, refusal lines) for this change against `ref` (scripts/code_standard_ratchet.py)."""
    return ratchet.decided_at(sys.modules[__name__], ref)


def against_main(config, debt):
    """Return (problem lines, note): the settings and the debt against main (scripts/code_standard_ratchet.py)."""
    return ratchet.against_main(sys.modules[__name__], config, debt)


def load():
    """Return (settings, debt) of this repo; debt is None when the repo has no baseline yet. It also loads a project's
    own gate into GATE. ValueError when a `code-` line of .check is not valid, the state file cannot be read, the old
    .code-standard.json is still here, the gate cannot be loaded, or a setting needs a gate and there is none.

    Returns:
        (settings dict, debt dict or None).
    """
    global GATE
    GATE = load_gate()
    config = settings.code_config(ROOT)
    if GATE is None and config.get('strict_gate'):   # a project's own gate file wins; the kit's strict rules are the fallback
        GATE = load_gate(STRICT_FILE)
        if GATE is None:
            raise ValueError('`code-strict-gate: on` in %s needs %s, and it is missing' % (settings.CHECK, STRICT_FILE.name))
    needs = gate_settings(config)
    if needs and GATE is None:
        raise ValueError('`%s` in %s is enforced by a project\'s own gate, and there is no %s: add the gate or remove '
                         'the line (docs/code-standard.md "A project\'s own gate")'
                         % ('`, `'.join(needs), settings.CHECK, GATE_FILE.name))
    part = settings.load_state(ROOT).get('code_standard')
    return config, None if part is None else part.get('debt', {})


def save(debt):
    """Write the debt list into .check.state.json (the parts of the other tools stay as they are)."""
    settings.save_part(ROOT, 'code_standard', {'debt': debt})


def parse_args():
    """Return the parsed command line (the usage: the header of this file)."""
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--report', action='store_true', help='print every measurement as JSON')
    ap.add_argument('--update', action='store_true', help='lower the baseline to the debt that is left')
    ap.add_argument('--init', action='store_true', help='write the first baseline (only when the repo has none)')
    ap.add_argument('--adopt', action='store_true', help='add the debt of a rule the baseline does not list yet')
    ap.add_argument('--test', action='store_true', help='prove the check on small sample repos')
    return ap.parse_args()


def main():
    """Parse the arguments, measure, and check against (or lower) the baseline.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    args = parse_args()
    if args.test:
        import code_standard_test   # scripts/code_standard_test.py: kept apart (rule C4)
        return code_standard_test.run(sys.modules[__name__])
    try:
        config, debt = load()
    except ValueError as err:
        print('CODE-STANDARD fail: %s' % err)
        return 1
    existed = debt is not None
    if not existed and not args.init:
        print('CODE-STANDARD fail: no code standard baseline in %s; adopt the standard with --init '
              '(docs/code-standard.md)' % settings.STATE)
        return 1
    m = measure(config)
    if args.report:
        print(json.dumps(m, indent=1))
        return 0
    if args.init:
        if existed:   # a second --init could write new debt into the list; the baseline only shrinks
            print('CODE-STANDARD fail: a baseline exists; use --update (it can only lower it)')
            return 1
        save(m['violations'])
        print('CODE-STANDARD baseline written: %s' % summary(m['violations']))
        return 0
    if args.adopt:
        return adopt(config, debt, m['violations'])
    return check(args, config, debt, m)


def check(args, config, debt, m):
    """Compare the measurement with the baseline and with main, print each problem and the result line; with
    --update, lower the baseline when there is no new debt.

    Args:
        args: the parsed command line.
        config: the code standard settings.
        debt: the baseline's debt list.
        m: the result of measure().

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    new, fixed = compare(m['violations'], debt, config['caps'])
    hand, note = against_main(config, debt)
    new += hand
    for line in new + fixed + ([note] if note else []):
        print(line)
    if args.update:
        if new:
            print('CODE-STANDARD fail: new debt cannot go into the baseline; fix it (docs/code-standard.md)')
            return 1
        save(m['violations'])
        print('CODE-STANDARD baseline lowered: %s' % summary(m['violations']))
        return 0
    if fixed and not new:
        print('Debt was fixed: run python3 scripts/code_standard.py --update and commit the lower baseline.')
    gate = ', gate %s active' % Path(GATE.__file__).name if GATE else ''
    print('CODE-STANDARD %s (files=%d, debt: %s%s)' % ('fail' if new or fixed else 'pass', len(m['files']),
                                                      summary(m['violations']), gate))
    return 1 if new or fixed else 0


def adopt(config, debt, now):
    """--adopt: list the debt of an opt-in rule just turned on; return the exit code (scripts/code_standard_ratchet.py)."""
    return ratchet.adopt(sys.modules[__name__], config, debt, now)


if __name__ == '__main__':
    sys.exit(main())
