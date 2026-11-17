#!/usr/bin/env python3
"""Code standard check: measures every source file of this repo against docs/code-standard.md and fails on new debt.

Why: the Administrator/PFM, 2026-11-17: all code is modular, clearly commented and human inspectable, and stays so as
work continues. A written rule alone is not always obeyed, so this check fails a push or a pull request instead.

What it measures (the rule numbers are those of docs/code-standard.md):
  C1 header      each source file starts with a header comment that says what the file is for
  C2 comment     each function has a comment: Python docstring, PowerShell comment-based help, or a comment line
                 directly above it or as the first line of its body
  C3 length      each function is at most `max_function_lines` lines long
  C4 file size   each source file is at most `max_file_lines` lines long
  C5 duplicate   no two functions in hand-written files have the same body (a copy must be generated, with a banner)
  C6 generated   each generated file says GENERATED near its top and names its source
  C10 parse      each PowerShell file parses (the PowerShell parser reports no error)
A comment that is the file header, or a divider line ("# ----", "# ===="), does not count as a function's comment.
A script block passed as an argument ($b.Add_Click({ ... })) is measured for C3 too, named by the call it is in.
The ratchet: tests/code-standard-baseline.json lists the debt that existed when the standard started. A violation that
is not in that list fails. A listed function that grew fails. A listed item that is fixed fails too, until the baseline
is lowered in the same change (`--update`), so the list can only shrink and always matches the code. The baseline
itself is compared with the one on the merge base with origin/main: an added item, a raised value or a changed
"config" fails, unless the same change adds a row to docs/DECISIONS.md that names tests/code-standard-baseline.json
(a cap or scope change is the owner's decision).

Inputs:  the files git tracks (git ls-files -z): files with a known extension, and files with no extension whose first
         line is a shell or Python shebang (for example scripts/git-hooks/pre-push); filtered by the baseline "config".
Outputs: one line per problem, then `CODE-STANDARD pass` or `CODE-STANDARD fail`; exit 0 or 1.
Usage:   python3 tests/check_code_standard.py            check (scripts/check.local.sh runs it in both lanes)
         python3 tests/check_code_standard.py --report   print every measurement (function lengths, comments)
         python3 tests/check_code_standard.py --update   lower the baseline to the debt that is left; refuses when
                                                          there is new debt (fix it instead)
         python3 tests/check_code_standard.py --self-test  prove the check on a small sample repo
Needs:   Python 3.8+, git, and pwsh 7 for the PowerShell files (the PowerShell parser gives the function list).
This file is the same in rhope-ops/RADE and rhope-ops/90-161.Z; each repo's settings are in its baseline file.
"""
import argparse
import ast
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / 'tests' / 'code-standard-baseline.json'
LANGS = {'.py': 'python', '.ps1': 'powershell', '.psm1': 'powershell', '.js': 'js', '.mjs': 'js', '.cjs': 'js', '.sh': 'shell'}
DIVIDER = re.compile(r'^\s*(#|//)\s*(-{4,}|={4,})')   # a section line, not a function's comment
MIN_HEADER_CHARS = 60      # a header shorter than this does not say what the file is for
MIN_DUP_LINES = 4          # a body this short (a one-line wrapper) is not counted as a duplicate
# A block between these two marker lines is a generated copy of a shared source (90-161.Z scripts/build_task_scripts.py):
# its functions are measured once, in the source, so C2, C3 and C5 skip them here.
BLOCK_BEGIN = re.compile(r'^\s*# >>> ([\w-]+): generated from ')
BLOCK_END = '# <<< '


# ---------------------------------------------------------------- file list -----------------------------------------

def tracked_files(config):
    """Return the repo-relative paths that the standard covers: tracked files with a known extension that match
    `include` and no `exclude` pattern. Paths that match `generated` are returned too (they get check C6 only)."""
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
    (sh or bash: shell; python: python); None for any other file."""
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


def matches(rel, patterns):
    """True when the path matches one of the glob patterns (fnmatch; `*` also matches `/`)."""
    return any(fnmatch.fnmatch(rel, p) for p in patterns)


# ---------------------------------------------------------------- headers (C1) and generated files (C6) ---------------

def header_block(lines, lang):
    """Return (text, last line number) of the comment block at the top of a file; ('', 0) when there is none."""
    i = 0
    while i < len(lines) and (lines[i].startswith('#!') or lines[i].strip() == '' or lines[i].startswith('#Requires')):
        i += 1
    if i >= len(lines):
        return '', 0
    first = lines[i].strip()
    if lang == 'python' and first[:3] in ('"""', "'''"):
        return block_until(lines, i, first[:3], first[:3])
    if lang == 'powershell' and first.startswith('<#'):
        return block_until(lines, i, '<#', '#>')
    if lang == 'js' and first.startswith('/*'):
        return block_until(lines, i, '/*', '*/')
    mark = '//' if lang == 'js' else '#'
    text = []
    while i < len(lines) and lines[i].strip().startswith(mark):
        if not DIVIDER.match(lines[i]):   # a divider line says nothing about the file
            text.append(lines[i].strip().lstrip(mark + '/').strip())
        i += 1
    return ' '.join(text), i


def block_until(lines, start, opener, closer):
    """Return (text, last line number) of a block comment or docstring that opens on line index `start` and ends at
    the first `closer`."""
    text = lines[start].strip()[len(opener):]
    if closer in text:
        return text.split(closer)[0], start + 1
    out, end = [text], len(lines)
    for k, line in enumerate(lines[start + 1:], start + 2):
        if closer in line:
            out.append(line.split(closer)[0])
            end = k
            break
        out.append(line)
    return ' '.join(x.strip() for x in out), end


def generated_blocks(lines):
    """Return the (first, last) line numbers (1-based) of each marked generated block in a file."""
    blocks, start = [], None
    for i, line in enumerate(lines, 1):
        if start is None and BLOCK_BEGIN.match(line):
            start = i
        elif start is not None and line.strip().startswith(BLOCK_END):
            blocks.append((start, i))
            start = None
    return blocks


def is_generated_ok(lines):
    """C6: a generated file says GENERATED in its first 15 lines and names a source (a path or 'from')."""
    top = '\n'.join(lines[:15])
    return 'GENERATED' in top.upper() and ('from ' in top or '/' in top)


# ---------------------------------------------------------------- functions (C2, C3, C5) -----------------------------

def python_functions(text):
    """Return [(qualified name, top line, first line, last line, has inner comment, body text)] for each def in a
    Python file. Top is the first decorator line; an inner comment is a docstring or a `#` comment on the def line or as
    the first body line (a comment above the def is checked by measure())."""
    lines = text.split('\n')
    tree = ast.parse(text)
    found = []

    def visit(node, prefix):
        """Add each def under `node` to `found`, named `prefix` + name; classes and nested defs add to the prefix."""
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                name = prefix + child.name
                top = min([child.lineno] + [d.lineno for d in child.decorator_list])
                first = child.body[0].lineno if child.body else child.lineno + 1
                lead = [x.strip() for x in lines[child.lineno:first - 1]]   # lines before the first statement
                if child.body and isinstance(child.body[0], (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                    lead = []   # a comment right above a nested def is that def's comment
                inner = bool(ast.get_docstring(child)) or any(x.startswith('#') for x in lead) \
                    or lines[child.lineno - 1].split(':', 1)[-1].strip().startswith('#')
                skip = 1 if ast.get_docstring(child) and len(child.body) > 1 else 0   # C5 compares code, not the docstring
                body = '\n'.join(lines[child.body[0].end_lineno if skip else child.lineno:child.end_lineno])
                found.append((name, top, child.lineno, child.end_lineno, inner, body))
                visit(child, name + '.')
            elif isinstance(child, ast.ClassDef):
                visit(child, prefix + child.name + '.')
    visit(tree, '')
    return found


PS_SCRIPT = r'''
$ErrorActionPreference = 'Stop'
$out = @{}
foreach ($path in [Console]::In.ReadToEnd().Split("`n")) {
  if (-not $path.Trim()) { continue }
  $tokens = $null; $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($path.Trim(), [ref]$tokens, [ref]$errors)
  $lines = @([System.IO.File]::ReadAllLines($path.Trim()))
  $comments = @{}
  $help = @()   # comment-based help blocks (.SYNOPSIS or .DESCRIPTION), by their first line
  foreach ($t in $tokens) { if ($t.Kind -eq 'Comment') { for ($l = $t.Extent.StartLineNumber; $l -le $t.Extent.EndLineNumber; $l++) { $comments[$l] = $true }; if ($t.Text -match '\.(SYNOPSIS|DESCRIPTION)') { $help += $t.Extent.StartLineNumber } } }
  $list = @(); $blocks = @()
  foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    $s = $f.Extent.StartLineNumber; $e = $f.Extent.EndLineNumber
    $brace = 0; if ($e -gt $s + 1 -and $lines[$s].Trim() -eq '{') { $brace = 1 }   # `{` on its own line after `function`
    $inside = @($help | Where-Object { $_ -gt $s -and $_ -lt $e }).Count -gt 0
    $list += @{ name = $f.Name; start = $s; end = $e; inner = $inside -or (($e -gt $s + 1 + $brace) -and [bool]$comments[$s + 1 + $brace]) }
  }
  # A script block kept in a variable or a hashtable key ($ui.Say = { ... }) is a function too: the window code uses
  # them. Any other script block (an argument, such as $b.Add_Click({ ... })) is measured for its length only.
  foreach ($b in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true)) {
    $p = $b.Parent; if ($p -is [System.Management.Automation.Language.CommandExpressionAst]) { $p = $p.Parent }
    if ($p -is [System.Management.Automation.Language.PipelineAst]) { $p = $p.Parent }
    $s = $b.Extent.StartLineNumber; $e = $b.Extent.EndLineNumber
    if ($p -is [System.Management.Automation.Language.AssignmentStatementAst]) {
      $list += @{ name = $p.Left.Extent.Text; start = $s; end = $e; inner = ($e -gt $s + 1) -and [bool]$comments[$s + 1] }
    } elseif ($e - $s -ge 2) {
      $call = ($b.Parent.Extent.Text -split "`n")[0]; $call = $call.Substring(0, [math]::Min(40, $call.Length)).Trim()
      $blocks += @{ name = '{block in ' + $call + '}'; start = $s; end = $e }
    }
  }
  $out[$path.Trim()] = @{ functions = $list; blocks = $blocks; errors = @($errors | ForEach-Object { 'line ' + $_.Extent.StartLineNumber + ': ' + $_.Message }) }
}
$out | ConvertTo-Json -Depth 5 -Compress
'''


def powershell_functions(paths):
    """Return {path: (functions, blocks, parse errors)} for PowerShell files, from the real PowerShell parser (pwsh).
    Functions are (name, top, first line, last line, has inner comment, body text): each function (nested ones too)
    and each script block assigned to a variable or a hashtable key (named by the left side, for example `$ui.Say`).
    Blocks are (name, first line, last line) of the other script blocks, named by the call they are in."""
    if not paths:
        return {}
    run = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', PS_SCRIPT],
                         input='\n'.join(str(ROOT / p) for p in paths), capture_output=True, text=True)
    if run.returncode != 0:
        raise SystemExit('CODE-STANDARD fail: the PowerShell parser did not run: ' + run.stderr.strip()[:300])
    data = json.loads(run.stdout or '{}')
    result = {}
    for p in paths:
        item = data.get(str(ROOT / p), {})
        as_list = lambda x: [x] if isinstance(x, dict) else (x or [])
        lines = (ROOT / p).read_text(encoding='utf-8-sig', errors='replace').split('\n')
        funcs = [(f['name'], f['start'], f['start'], f['end'], f['inner'], '\n'.join(lines[f['start']:f['end']]))
                 for f in as_list(item.get('functions'))]
        blocks = [(b['name'], b['start'], b['end']) for b in as_list(item.get('blocks'))]
        errors = item.get('errors') or []
        result[p] = (funcs, blocks, [errors] if isinstance(errors, str) else errors)
    return result


JS_FUNC = re.compile(r'^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)\s*\(|'
                     r'^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:function\b|\([^)]*\)\s*=>|[A-Za-z_$][\w$]*\s*=>)|'
                     r'^\s+(?:static\s+)?(?:async\s+)?(?!(?:if|for|while|switch|catch|function|return)\b)([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*\{')
SH_FUNC = re.compile(r'^\s*(?:function\s+([A-Za-z_][\w-]*)\s*(?:\(\))?|([A-Za-z_][\w-]*)\s*\(\))\s*(?:\{|$)')


def brace_functions(text, pattern, comment_mark):
    """Return functions of a JavaScript or shell file found by a line pattern, as (name, top, first line, last line,
    has inner comment, body text); the end is the line where the braces opened on the first line close again."""
    lines = text.split('\n')
    found = []
    for i, line in enumerate(lines):
        m = pattern.match(line)
        if not m:
            continue
        name = next(g for g in m.groups() if g)
        arrow = '=>' in line and m.lastindex == 2   # `const f = (...) =>`: its body must open on this line or the next
        depth, end, opened = 0, i, False
        for j in range(i, len(lines)):
            if arrow and j > i + 1 and not opened:
                break
            depth, opened = count_braces(lines[j], depth, opened, comment_mark)
            if opened and depth <= 0:
                end = j
                break
        if not opened:
            if arrow:   # an arrow with no braces (`const f = x => x + 1;`) is a one-line function
                found.append((name, i + 1, i + 1, i + 1, False, line))
            continue
        k = i + 2 if i + 1 < len(lines) and lines[i + 1].strip() == '{' else i + 1   # skip a `{` on its own line
        first = lines[k].strip() if end > k else ''   # a one-line function has no inner first line
        found.append((name, i + 1, i + 1, end + 1, first.startswith(comment_mark), '\n'.join(lines[i + 1:end + 1])))
    return found


def count_braces(line, depth, opened, comment_mark):
    """Add the `{` and `}` of one line (outside quotes and comments) to the running depth. A shell `#` starts a
    comment only at the start of a word, so `${#list[@]}` and `${name#prefix}` count as code."""
    quote = None
    k = 0
    while k < len(line):
        c = line[k]
        if quote:
            if c == '\\' and quote != "'":
                k += 1
            elif c == quote:
                quote = None
        elif line.startswith(comment_mark, k) and (comment_mark != '#' or k == 0 or line[k - 1] in ' \t;'):
            break
        elif c in '"\'`':
            quote = c
        elif c == '{':
            depth += 1
            opened = True
        elif c == '}':
            depth -= 1
        k += 1
    return depth, opened


def has_comment_above(lines, top, header_last):
    """True when the line right above line `top` (1-based) is a comment that is not part of the file header and not a
    divider line. A comment block that ends there counts (its last line is checked)."""
    if top < 2 or top - 1 <= header_last:
        return False
    above = lines[top - 2].strip()
    if DIVIDER.match(above):
        return False
    return above.startswith(('#', '//')) or above.endswith(('*/', '#>'))


# ---------------------------------------------------------------- measure ----------------------------------------------

def file_functions(p, text, lang, ps):
    """Return (functions, blocks, parse errors) of one source file, in the shapes powershell_functions() gives."""
    if lang == 'powershell':
        return ps[p]
    if lang == 'python':
        try:
            return python_functions(text), [], []
        except SyntaxError as err:
            return [], [], ['line %s: %s' % (err.lineno, err.msg)]
    pattern, mark = (JS_FUNC, '//') if lang == 'js' else (SH_FUNC, '#')
    return brace_functions(text, pattern, mark), [], []


def measure(config):
    """Measure every covered file. Returns {"files": {path: {...}}, "violations": {kind: {key: value}}}."""
    files = tracked_files(config)
    generated = [p for p in files if matches(p, config.get('generated', []))]
    source = [p for p in files if p not in generated]
    ps = powershell_functions([p for p in source if lang_of(p) == 'powershell'])
    caps = config['caps']
    report, v = {}, {k: {} for k in RULE}
    bodies = {}
    for p in generated:
        if not is_generated_ok((ROOT / p).read_text(encoding='utf-8-sig', errors='replace').split('\n')):
            v['generated'][p] = 1
    for p in source:
        text = (ROOT / p).read_text(encoding='utf-8-sig', errors='replace')
        lines, lang = text.split('\n'), lang_of(p)
        funcs, blocks, errors = file_functions(p, text, lang, ps)
        head, head_last = header_block(lines, lang)
        report[p] = {'lines': len(lines), 'header': len(head), 'functions': [], 'blocks': [], 'errors': errors}
        if errors:
            v['parse'][p] = len(errors)
        if len(head) < MIN_HEADER_CHARS:
            v['header'][p] = 1
        if len(lines) > caps['max_file_lines']:
            v['file_size'][p] = len(lines)
        skip = generated_blocks(lines)
        seen = {}
        for name, top, start, end, inner, body in funcs:
            if any(a <= start <= b for a, b in skip):
                continue
            key = unique_key(p, name, seen)
            size, commented = end - start + 1, inner or has_comment_above(lines, top, head_last)
            report[p]['functions'].append({'name': name, 'start': start, 'lines': size, 'comment': commented})
            if not commented:
                v['comment'][key] = 1
            if size > caps['max_function_lines']:
                v['length'][key] = size
            norm = '\n'.join(x.strip() for x in body.split('\n') if x.strip() and not x.strip().startswith(('#', '//')))
            if norm.count('\n') + 1 >= MIN_DUP_LINES:
                bodies.setdefault(hashlib.sha256(norm.encode()).hexdigest()[:12], []).append(key)
        for name, start, end in blocks:
            if any(a <= start <= b for a, b in skip):
                continue
            key = unique_key(p, name, seen)
            report[p]['blocks'].append({'name': name, 'start': start, 'lines': end - start + 1})
            if end - start + 1 > caps['max_function_lines']:
                v['length'][key] = end - start + 1
    for keys in bodies.values():
        if len(keys) > 1:
            for k in keys:
                v['duplicate'][k] = len(keys)
    return {'files': report, 'violations': v}


def unique_key(p, name, seen):
    """Return the debt key of a function: "<path>::<name>", with "#2", "#3" for the next ones of the same name."""
    seen[name] = seen.get(name, 0) + 1
    return '%s::%s' % (p, name if seen[name] == 1 else '%s#%d' % (name, seen[name]))


# ---------------------------------------------------------------- ratchet ----------------------------------------------

RULE = {'header': 'C1 no header comment', 'comment': 'C2 function without a comment',
        'length': 'C3 function longer than %d lines', 'file_size': 'C4 file longer than %d lines',
        'duplicate': 'C5 same body as another function', 'generated': 'C6 generated file without a GENERATED banner',
        'parse': 'C10 PowerShell or Python file that does not parse'}


def compare(now, debt, caps):
    """Return (new problems, fixed items). New: a violation not in the debt, or a debt value that grew. Fixed: a
    debt item that is gone or smaller (the baseline must be lowered in the same change)."""
    new, fixed = [], []
    for kind, items in now.items():
        label = RULE[kind] % caps['max_function_lines'] if kind == 'length' else (
            RULE[kind] % caps['max_file_lines'] if kind == 'file_size' else RULE[kind])
        old = debt.get(kind, {})
        for key, value in sorted(items.items()):
            if key not in old:
                new.append('FAIL  %s: %s%s' % (label, key, '' if value == 1 else ' (%d)' % value))
            elif value > old[key] and kind in ('length', 'file_size'):
                new.append('FAIL  %s: %s grew from %d to %d' % (label, key, old[key], value))
        for key, value in sorted(old.items()):
            if key not in items or (kind in ('length', 'file_size') and items[key] < value):
                fixed.append('FIXED %s: %s' % (label, key))
    return new, fixed


def git(*args):
    """Run git in the repo root; return the finished process (text output)."""
    return subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True, text=True)


def against_main(base):
    """Compare this baseline with the one on the merge base with origin/main. Returns (problem lines, note). An item
    added to the debt, a value raised, or a changed "config" is a problem, unless docs/DECISIONS.md gains a line that
    names tests/code-standard-baseline.json in the same change (the owner's decision)."""
    mb = git('merge-base', 'HEAD', 'origin/main')
    if mb.returncode != 0:
        if os.environ.get('CI'):
            return ['FAIL  baseline: no merge base with origin/main, so the baseline cannot be compared'], ''
        return [], 'WARN  baseline not compared with main (no origin/main here)'
    ref = mb.stdout.strip()
    shown = git('show', ref + ':tests/code-standard-baseline.json')
    if shown.returncode != 0:
        return [], 'NOTE  no baseline on main yet: this change starts it'
    old = json.loads(shown.stdout)
    decided = any(x.startswith('+') and 'code-standard-baseline.json' in x
                  for x in git('diff', ref, '--', 'docs/DECISIONS.md').stdout.split('\n'))
    problems = []
    for kind, items in base.get('debt', {}).items():
        was = old.get('debt', {}).get(kind, {})
        for key, value in sorted(items.items()):
            if key not in was:
                problems.append('FAIL  baseline: %s item added by hand: %s' % (kind, key))
            elif value > was[key]:
                problems.append('FAIL  baseline: %s value raised: %s (%d to %d)' % (kind, key, was[key], value))
    if base.get('config') != old.get('config') and not decided:
        problems.append('FAIL  baseline: "config" (caps or scope) changed with no docs/DECISIONS.md row that names '
                        'tests/code-standard-baseline.json (a cap or scope change is the owner\'s decision)')
    return problems, ''


def main():
    """Parse the arguments, measure, and check against (or lower) the baseline."""
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--report', action='store_true', help='print every measurement as JSON')
    ap.add_argument('--update', action='store_true', help='lower the baseline to the debt that is left')
    ap.add_argument('--init', action='store_true', help='write the first baseline (only when none has debt yet)')
    ap.add_argument('--self-test', action='store_true', help='prove the check on a small sample repo')
    args = ap.parse_args()
    if args.self_test:
        import check_code_standard_selftest   # tests/check_code_standard_selftest.py: kept apart (rule C4)
        return check_code_standard_selftest.run(sys.modules[__name__])
    base = json.loads(BASELINE.read_text())
    config = base['config']
    m = measure(config)
    if args.report:
        print(json.dumps(m, indent=1))
        return 0
    if args.init:
        if base.get('debt'):
            print('CODE-STANDARD fail: a baseline exists; use --update (it can only lower it)')
            return 1
        base['debt'] = m['violations']
        BASELINE.write_text(json.dumps(base, indent=1, sort_keys=True) + '\n')
        print('CODE-STANDARD baseline written: %s' % summary(m['violations']))
        return 0
    new, fixed = compare(m['violations'], base.get('debt', {}), config['caps'])
    hand, note = against_main(base)
    new += hand
    for line in new + fixed + ([note] if note else []):
        print(line)
    if args.update:
        if new:
            print('CODE-STANDARD fail: new debt cannot go into the baseline; fix it (docs/code-standard.md)')
            return 1
        base['debt'] = m['violations']
        BASELINE.write_text(json.dumps(base, indent=1, sort_keys=True) + '\n')
        print('CODE-STANDARD baseline lowered: %s' % summary(m['violations']))
        return 0
    if fixed and not new:
        print('Debt was fixed: run python3 tests/check_code_standard.py --update and commit the lower baseline.')
    print('CODE-STANDARD %s (files=%d, debt: %s)' % ('fail' if new or fixed else 'pass', len(m['files']),
                                                    summary(m['violations'])))
    return 1 if new or fixed else 0


def summary(v):
    """One line: the count of each kind of debt."""
    return ', '.join('%s %d' % (k, len(items)) for k, items in v.items())


if __name__ == '__main__':
    sys.exit(main())
