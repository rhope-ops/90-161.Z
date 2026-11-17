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
The ratchet: tests/code-standard-baseline.json lists the debt that existed when the standard started. A violation that
is not in that list fails. A listed function that grew fails. A listed item that is fixed fails too, until the baseline
is lowered in the same change (`--update`), so the list can only shrink and always matches the code.

Inputs:  the files git tracks (git ls-files), filtered by the "config" block of the baseline file.
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
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / 'tests' / 'code-standard-baseline.json'
LANGS = {'.py': 'python', '.ps1': 'powershell', '.psm1': 'powershell', '.js': 'js', '.sh': 'shell'}
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
    out = subprocess.run(['git', '-C', str(ROOT), 'ls-files'], capture_output=True, text=True, check=True).stdout
    keep = []
    for rel in out.splitlines():
        if Path(rel).suffix not in LANGS and not matches(rel, config.get('generated', [])):
            continue
        if not matches(rel, config.get('include', ['*'])) or matches(rel, config.get('exclude', [])):
            continue
        if (ROOT / rel).is_file():
            keep.append(rel)
    return sorted(keep)


def matches(rel, patterns):
    """True when the path matches one of the glob patterns (fnmatch; `*` also matches `/`)."""
    return any(fnmatch.fnmatch(rel, p) for p in patterns)


# ---------------------------------------------------------------- headers (C1) and generated files (C6) ---------------

def header_text(lines, lang):
    """Return the text of the comment block at the top of a file (after a shebang, `#Requires` or `set -` lines),
    or '' when the file does not start with a comment."""
    i = 0
    while i < len(lines) and (lines[i].startswith('#!') or lines[i].strip() == '' or lines[i].startswith('#Requires')):
        i += 1
    if i >= len(lines):
        return ''
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
        text.append(lines[i].strip().lstrip(mark + '/').strip())
        i += 1
    return ' '.join(text)


def block_until(lines, start, opener, closer):
    """Return the text of a block comment or docstring that opens on line `start` and ends at the first `closer`."""
    text = lines[start].strip()[len(opener):]
    if closer in text:
        return text.split(closer)[0]
    out = [text]
    for line in lines[start + 1:]:
        if closer in line:
            out.append(line.split(closer)[0])
            break
        out.append(line)
    return ' '.join(x.strip() for x in out)


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
    """Return [(qualified name, first line, last line, has comment, body text)] for each def in a Python file.
    A comment is a docstring, a `#` line directly above the def (decorators are skipped) or a `#` first body line."""
    lines = text.split('\n')
    tree = ast.parse(text)
    found = []

    def visit(node, prefix):
        """Add each def under `node` to `found`, named `prefix` + name; classes and nested defs add to the prefix."""
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                name = prefix + child.name
                top = min([child.lineno] + [d.lineno for d in child.decorator_list])
                above = lines[top - 2].strip() if top >= 2 else ''
                first_body = lines[child.body[0].lineno - 1].strip() if child.body else ''
                commented = bool(ast.get_docstring(child)) or above.startswith('#') or first_body.startswith('#') \
                    or lines[child.lineno - 1].split(':', 1)[-1].strip().startswith('#')
                body = '\n'.join(lines[child.lineno:child.end_lineno])
                found.append((name, child.lineno, child.end_lineno, commented, body))
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
  $comments = @{}
  foreach ($t in $tokens) { if ($t.Kind -eq 'Comment') { for ($l = $t.Extent.StartLineNumber; $l -le $t.Extent.EndLineNumber; $l++) { $comments[$l] = $true } } }
  $list = @()
  foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    $s = $f.Extent.StartLineNumber; $e = $f.Extent.EndLineNumber
    $help = $null -ne $f.GetHelpContent()
    $list += @{ name = $f.Name; start = $s; end = $e; help = $help; above = [bool]$comments[$s - 1]; first = [bool]$comments[$s + 1] -or [bool]$comments[$s] }
  }
  # A script block kept in a variable or a hashtable key ($ui.Say = { ... }) is a function too: the window code uses them.
  foreach ($b in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true)) {
    $p = $b.Parent; if ($p -is [System.Management.Automation.Language.CommandExpressionAst]) { $p = $p.Parent }
    if ($p -is [System.Management.Automation.Language.PipelineAst]) { $p = $p.Parent }
    if ($p -isnot [System.Management.Automation.Language.AssignmentStatementAst]) { continue }
    $s = $b.Extent.StartLineNumber; $e = $b.Extent.EndLineNumber
    $list += @{ name = $p.Left.Extent.Text; start = $s; end = $e; help = $false; above = [bool]$comments[$s - 1] -or [bool]$comments[$s]; first = [bool]$comments[$s + 1] }
  }
  $out[$path.Trim()] = @{ functions = $list; errors = @($errors).Count }
}
$out | ConvertTo-Json -Depth 5 -Compress
'''


def powershell_functions(paths):
    """Return {path: [(name, first line, last line, has comment, body text)]} for PowerShell files, from the real
    PowerShell parser (pwsh). Nested functions are listed too, under their own names, and so is each script block
    that is assigned to a variable or a hashtable key (named by the left side, for example `$ui.Say`)."""
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
        funcs = item.get('functions') or []
        if isinstance(funcs, dict):
            funcs = [funcs]
        lines = (ROOT / p).read_text(encoding='utf-8-sig', errors='replace').split('\n')
        result[p] = [(f['name'], f['start'], f['end'], f['help'] or f['above'] or f['first'],
                      '\n'.join(lines[f['start']:f['end']])) for f in funcs]
    return result


JS_FUNC = re.compile(r'^\s*(?:export\s+)?(?:async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)\s*\(|'
                     r'^\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:function\b|\([^)]*\)\s*=>|[A-Za-z_$][\w$]*\s*=>)')
SH_FUNC = re.compile(r'^\s*(?:function\s+)?([A-Za-z_][\w-]*)\s*\(\)\s*\{')


def brace_functions(text, pattern, comment_mark):
    """Return functions of a JavaScript or shell file found by a line pattern; the end is the line where the braces
    opened on the first line close again (strings and comments are skipped roughly: quotes and `//` or `#`)."""
    lines = text.split('\n')
    found = []
    for i, line in enumerate(lines):
        m = pattern.match(line)
        if not m:
            continue
        name = next(g for g in m.groups() if g)
        depth, end, opened = 0, i, False
        for j in range(i, len(lines)):
            depth, opened = count_braces(lines[j], depth, opened, comment_mark)
            if opened and depth <= 0:
                end = j
                break
        if not opened:
            continue
        above = lines[i - 1].strip() if i else ''
        first = lines[i + 1].strip() if i + 1 < len(lines) else ''
        commented = above.startswith(comment_mark) or above.endswith('*/') or first.startswith(comment_mark)
        found.append((name, i + 1, end + 1, commented, '\n'.join(lines[i + 1:end + 1])))
    return found


def count_braces(line, depth, opened, comment_mark):
    """Add the `{` and `}` of one line (outside quotes and line comments) to the running depth."""
    quote = None
    k = 0
    while k < len(line):
        c = line[k]
        if quote:
            if c == '\\':
                k += 1
            elif c == quote:
                quote = None
        elif line.startswith(comment_mark, k):
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


# ---------------------------------------------------------------- measure ----------------------------------------------

def measure(config):
    """Measure every covered file. Returns {"files": {path: {...}}, "violations": {kind: {key: value}}}."""
    files = tracked_files(config)
    generated = [p for p in files if matches(p, config.get('generated', []))]
    source = [p for p in files if p not in generated]
    ps = powershell_functions([p for p in source if LANGS.get(Path(p).suffix) == 'powershell'])
    caps = config['caps']
    report, v = {}, {'header': {}, 'comment': {}, 'length': {}, 'file_size': {}, 'duplicate': {}, 'generated': {}}
    bodies = {}
    for p in generated:
        lines = (ROOT / p).read_text(encoding='utf-8-sig', errors='replace').split('\n')
        if not is_generated_ok(lines):
            v['generated'][p] = 1
    for p in source:
        text = (ROOT / p).read_text(encoding='utf-8-sig', errors='replace')
        lines = text.split('\n')
        lang = LANGS[Path(p).suffix]
        if lang == 'python':
            funcs = python_functions(text)
        elif lang == 'powershell':
            funcs = ps[p]
        elif lang == 'js':
            funcs = brace_functions(text, JS_FUNC, '//')
        else:
            funcs = brace_functions(text, SH_FUNC, '#')
        report[p] = {'lines': len(lines), 'header': len(header_text(lines, lang)), 'functions': []}
        if len(header_text(lines, lang)) < MIN_HEADER_CHARS:
            v['header'][p] = 1
        if len(lines) > caps['max_file_lines']:
            v['file_size'][p] = len(lines)
        seen = {}
        skip = generated_blocks(lines)
        for name, start, end, commented, body in funcs:
            if any(a <= start <= b for a, b in skip):
                continue
            seen[name] = seen.get(name, 0) + 1
            key = '%s::%s' % (p, name if seen[name] == 1 else '%s#%d' % (name, seen[name]))
            size = end - start + 1
            report[p]['functions'].append({'name': name, 'start': start, 'lines': size, 'comment': commented})
            if not commented:
                v['comment'][key] = 1
            if size > caps['max_function_lines']:
                v['length'][key] = size
            norm = '\n'.join(x.strip() for x in body.split('\n') if x.strip() and not x.strip().startswith(('#', '//')))
            if norm.count('\n') + 1 >= MIN_DUP_LINES:
                bodies.setdefault(hashlib.sha256(norm.encode()).hexdigest()[:12], []).append(key)
    for h, keys in bodies.items():
        if len(keys) > 1:
            for k in keys:
                v['duplicate'][k] = len(keys)
    return {'files': report, 'violations': v}


# ---------------------------------------------------------------- ratchet ----------------------------------------------

RULE = {'header': 'C1 no header comment', 'comment': 'C2 function without a comment',
        'length': 'C3 function longer than %d lines', 'file_size': 'C4 file longer than %d lines',
        'duplicate': 'C5 same body as another function', 'generated': 'C6 generated file without a GENERATED banner'}


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


def main():
    """Parse the arguments, measure, and check against (or lower) the baseline."""
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--report', action='store_true', help='print every measurement as JSON')
    ap.add_argument('--update', action='store_true', help='lower the baseline to the debt that is left')
    ap.add_argument('--init', action='store_true', help='write the first baseline (only when none has debt yet)')
    ap.add_argument('--self-test', action='store_true', help='prove the check on a small sample repo')
    args = ap.parse_args()
    if args.self_test:
        return self_test()
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
    for line in new + fixed:
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


def self_test():
    """Prove the check on a sample repo in a temporary folder: clean files pass; a new debt, a grown function and an
    unlowered fixed item each fail; --update refuses new debt; a marked generated block is skipped."""
    import tempfile
    global ROOT, BASELINE
    good_py = '"""Sample module: it shows a file that meets every rule of the code standard."""\n\n\n' \
              'def add(a, b):\n    """Return a + b."""\n    return a + b\n'
    good_ps = '<#\n  Sample PowerShell file: it shows a file that meets every rule of the code standard.\n#>\n' \
              '# Returns the text in capitals.\nfunction Get-Upper([string]$T) {\n  return $T.ToUpper()\n}\n' \
              '# >>> shared: generated from src/shared.ps1 by build.py (do not edit)\n' \
              'function Get-Copy { return 1 }\n# <<< shared\n'
    with tempfile.TemporaryDirectory() as d:
        ROOT = Path(d)
        BASELINE = ROOT / 'tests' / 'code-standard-baseline.json'
        (ROOT / 'tests').mkdir()
        g = lambda *c: subprocess.run(['git', '-C', d, *c], check=True, capture_output=True)
        g('init', '-q')
        (ROOT / 'a.py').write_text(good_py)
        (ROOT / 'b.ps1').write_text(good_ps)
        config = {'caps': {'max_function_lines': 5, 'max_file_lines': 50}, 'include': ['*'], 'exclude': [], 'generated': []}
        g('add', '.')
        m = measure(config)
        assert not any(m['violations'].values()), 'clean files pass: %s' % m['violations']
        assert [f['name'] for f in m['files']['b.ps1']['functions']] == ['Get-Upper'], 'generated block skipped'
        (ROOT / 'a.py').write_text(good_py + '\n\ndef bare(x):\n    return x\n')
        new, fixed = compare(measure(config)['violations'], {}, config['caps'])
        assert len(new) == 1 and 'C2' in new[0] and 'a.py::bare' in new[0], 'a function without a comment fails: %s' % new
        long_fn = '\n\ndef long(x):\n    """Long."""\n' + '    x += 1\n' * 6 + '    return x\n'
        (ROOT / 'a.py').write_text(good_py + long_fn)
        debt = measure(config)['violations']
        assert debt['length'] == {'a.py::long': 9}, 'a long function is debt: %s' % debt['length']
        (ROOT / 'a.py').write_text(good_py + long_fn.replace('    return x', '    x += 1\n    return x'))
        new, fixed = compare(measure(config)['violations'], debt, config['caps'])
        assert len(new) == 1 and 'grew from 9 to 10' in new[0], 'a listed function that grew fails: %s' % new
        (ROOT / 'a.py').write_text(good_py)
        new, fixed = compare(measure(config)['violations'], debt, config['caps'])
        assert not new and len(fixed) == 1, 'a fixed item is reported (and fails until the baseline is lowered)'
        (ROOT / 'c.sh').write_text('echo hi\n')
        g('add', '.')
        new, _ = compare(measure(config)['violations'], {}, config['caps'])
        assert any('C1' in x and 'c.sh' in x for x in new), 'a file without a header fails: %s' % new
    print('code standard self-test: pass')
    return 0


def summary(v):
    """One line: the count of each kind of debt."""
    return ', '.join('%s %d' % (k, len(items)) for k, items in v.items())


if __name__ == '__main__':
    sys.exit(main())
