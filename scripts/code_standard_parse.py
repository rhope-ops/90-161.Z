#!/usr/bin/env python3
"""The file readers of the code standard check (scripts/code_standard.py): the header comment of a file, its marked
generated blocks, and the functions of a Python, PowerShell, JavaScript or shell file. Kept apart so the check stays
under its own file cap (docs/code-standard.md C4).

What it gives:
  header_block          the comment block at the top of a file (rule C1), one header line per text line
  generated_blocks      the marked copies of a shared source inside a file (rules C2, C3 and C5 skip them)
  is_generated_ok       rule C6: a generated file names its source
  python_functions      each def of a Python file (from its syntax tree)
  powershell_functions  each function and script block of PowerShell files (from the real parser, pwsh)
  brace_functions       each function of a JavaScript or shell file (by a line pattern and a brace count)
  has_comment_above     rule C2: a comment line directly above a function
Inputs:  the text or the lines of one file; for PowerShell, the repo root and the paths.
Outputs: lists of tuples (see each function); nothing is printed.
Prevents: the code standard misreads a file header or a function, so a missing header or comment passes the check
Network: none.
Writes: none.
Credentials: none.
Run:     imported by scripts/code_standard.py; proved by `python3 scripts/code_standard.py --test`.
         Needs pwsh 7 only for PowerShell files.
"""

import ast
import json
import os
import re
import subprocess

DIVIDER = re.compile(r'^\s*(#|//)\s*(-{4,}|={4,})')   # a section line, not a function's comment
# A block between these two marker lines is a generated copy of a shared source (for example a task script bundle):
# its functions are measured once, in the source, so C2, C3 and C5 skip them here.
BLOCK_BEGIN = re.compile(r'^\s*# >>> ([\w-]+): generated from ')
BLOCK_END = '# <<< '


# ---------------------------------------------------------------- headers (C1) and generated files (C6) ---------------

def header_block(lines, lang):
    """Return the comment block at the top of a file (rule C1), one header line per text line, so a project's gate
    can test where a label stands.

    Args:
        lines: the file's lines.
        lang: 'python', 'powershell', 'js' or 'shell'.

    Returns:
        (text, last line number); ('', 0) when there is none.
    """
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
    return '\n'.join(text), i


def block_until(lines, start, opener, closer):
    """Return a block comment or docstring that opens on line index `start` and ends at the first `closer`.

    Args:
        lines: the file's lines.
        start: the index (0-based) of the line that opens the block.
        opener: the text that opens it (for example `<#`).
        closer: the text that closes it.

    Returns:
        (text, last line number), the lines of the block joined by line feeds.
    """
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
    return '\n'.join(x.strip() for x in out), end


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
    """Return each def of a Python file. Top is the first decorator line; an inner comment is a docstring or a `#`
    comment on the def line or as the first body line (a comment above the def is checked by measure()).

    Args:
        text: the whole file.

    Returns:
        [(qualified name, top line, first line, last line, has inner comment, body text)].
    """
    lines = text.split('\n')
    tree = ast.parse(text)
    found = []

    def visit(node, prefix):
        """Add each def under `node` to `found`, named `prefix` + name; classes and nested defs add to the prefix.

        Args:
            node: a module, class or function node.
            prefix: the qualified name so far, ending in a dot (or '').
        """
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                name = prefix + child.name
                top = min([child.lineno] + [d.lineno for d in child.decorator_list])
                first = child.body[0].lineno if child.body else child.lineno + 1
                lead = [x.strip() for x in lines[child.lineno:first - 1]]   # lines before the first statement
                if child.body and isinstance(child.body[0], (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                    while lead and lead[-1].startswith(('#', '@')):
                        lead.pop()   # comment lines that touch a nested def are that def's comment
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
$full = $env:CODE_STANDARD_FULL -eq '1'   # C2 full is on: read the help of each function longer than 10 lines
# Doc facts for the opt-in C2 full rule: the parameter names and what the comment-based help documents.
function Get-DocFacts($node, $help) {
  $ps = @()
  if ($node.Parameters) { $ps = @($node.Parameters) }
  elseif ($node.Body -and $node.Body.ParamBlock) { $ps = @($node.Body.ParamBlock.Parameters) }
  elseif ($node.ParamBlock) { $ps = @($node.ParamBlock.Parameters) }
  $names = @($ps | ForEach-Object { $_.Name.VariablePath.UserPath })
  $documented = @(); if ($help -and $help.Parameters) { $documented = @($help.Parameters.Keys) }
  return @{ params = $names; help = $documented; synopsis = [bool]($help -and ($help.Synopsis -or $help.Description)) }
}
foreach ($path in [Console]::In.ReadToEnd().Split("`n")) {
  if (-not $path.Trim()) { continue }
  $tokens = $null; $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($path.Trim(), [ref]$tokens, [ref]$errors)
  $lines = @([System.IO.File]::ReadAllLines($path.Trim()))
  $help = @()   # comment-based help: <# #> blocks with .SYNOPSIS or .DESCRIPTION, by their first and last line
  foreach ($t in $tokens) {
    if ($t.Kind -eq 'Comment' -and $t.Text.StartsWith('<#') -and $t.Text -match '\.(SYNOPSIS|DESCRIPTION)') { $help += ,@($t.Extent.StartLineNumber, $t.Extent.EndLineNumber) }
  }
  $list = @(); $blocks = @()
  foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    $s = $f.Extent.StartLineNumber; $e = $f.Extent.EndLineNumber
    $brace = 0; if ($e -gt $s + 1 -and $lines[$s].Trim() -eq '{') { $brace = 1 }   # `{` on its own line after `function`
    $body = $f.Body.Extent; $first = $body.StartLineNumber + 1; $last = $body.EndLineNumber - 1   # the help is first or last in the body
    $inside = @($help | Where-Object {
      $_[0] -ge $body.StartLineNumber -and $_[1] -le $body.EndLineNumber -and ($_[0] -eq $first -or $_[1] -eq $last) }).Count -gt 0
    $inner = $inside -or (($e -gt $s + 1 + $brace) -and $lines[$s + $brace].Trim() -match '^<?#')
    $doc = $(if ($full -and $e - $s -ge 10) { Get-DocFacts $f $f.GetHelpContent() })
    $list += @{ name = $f.Name; start = $s; end = $e; inner = $inner; doc = $doc }
  }
  # A script block kept in a variable or a hashtable key ($ui.Say = { ... }) is a function too: the window code uses
  # them. Any other script block (an argument, such as $b.Add_Click({ ... })) is measured for its length only.
  foreach ($b in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true)) {
    $p = $b.Parent; if ($p -is [System.Management.Automation.Language.CommandExpressionAst]) { $p = $p.Parent }
    if ($p -is [System.Management.Automation.Language.PipelineAst]) { $p = $p.Parent }
    $s = $b.Extent.StartLineNumber; $e = $b.Extent.EndLineNumber
    if ($p -is [System.Management.Automation.Language.AssignmentStatementAst]) {
      $doc = $(if ($full -and $e - $s -ge 10) { Get-DocFacts $b.ScriptBlock $b.ScriptBlock.GetHelpContent() })
      $list += @{ name = $p.Left.Extent.Text; start = $s; end = $e; inner = ($e -gt $s + 1) -and $lines[$s].Trim() -match '^<?#'; doc = $doc }
    } elseif ($e - $s -ge 2) {
      $call = ($b.Parent.Extent.Text -split "`n")[0]; $call = $call.Substring(0, [math]::Min(40, $call.Length)).Trim()
      $blocks += @{ name = '{block in ' + $call + '}'; start = $s; end = $e }
    }
  }
  $out[$path.Trim()] = @{ functions = $list; blocks = $blocks; errors = @($errors | ForEach-Object { 'line ' + $_.Extent.StartLineNumber + ': ' + $_.Message }) }
}
$out | ConvertTo-Json -Depth 5 -Compress
'''


def powershell_functions(root, paths, full=False):
    """Return the functions of PowerShell files, from the real PowerShell parser (pwsh).
    Functions are (name, top, first line, last line, has inner comment, body text, doc facts): each function (nested
    ones too) and each script block assigned to a variable or a hashtable key (named by the left side, for example
    `$ui.Say`). Blocks are (name, first line, last line) of the other script blocks, named by the call they are in.

    Args:
        root: the repo root (a Path).
        paths: the repo-relative paths of the PowerShell files.
        full: True when rule C2 full is on: the parser also reads each function's help.

    Returns:
        {path: (functions, blocks, parse errors)}.
    """
    if not paths:
        return {}
    env = dict(os.environ, CODE_STANDARD_FULL='1' if full else '0')
    run = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', PS_SCRIPT],
                         input='\n'.join(str(root / p) for p in paths), capture_output=True, text=True, env=env)
    if run.returncode != 0:
        raise SystemExit('CODE-STANDARD fail: the PowerShell parser did not run: ' + run.stderr.strip()[:300])
    data = json.loads(run.stdout or '{}')
    result = {}
    for p in paths:
        item = data.get(str(root / p), {})
        as_list = lambda x: [x] if isinstance(x, dict) else (x or [])
        lines = (root / p).read_text(encoding='utf-8-sig', errors='replace').split('\n')
        funcs = [(f['name'], f['start'], f['start'], f['end'], f['inner'], '\n'.join(lines[f['start']:f['end']]),
                  f.get('doc')) for f in as_list(item.get('functions'))]
        blocks = [(b['name'], b['start'], b['end']) for b in as_list(item.get('blocks'))]
        errors = item.get('errors') or []
        result[p] = (funcs, blocks, [errors] if isinstance(errors, str) else errors)
    return result


JS_FUNC = re.compile(r'^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)\s*\(|'
                     r'^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:function\b|\([^)]*\)\s*=>|[A-Za-z_$][\w$]*\s*=>)|'
                     r'^\s+(?:static\s+)?(?:async\s+)?(?!(?:if|for|while|switch|catch|function|return)\b)([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*\{')
SH_FUNC = re.compile(r'^\s*(?:function\s+([A-Za-z_][\w-]*)\s*(?:\(\))?|([A-Za-z_][\w-]*)\s*\(\))\s*(?:\{|$)')


def brace_functions(text, pattern, comment_mark):
    """Return the functions of a JavaScript or shell file found by a line pattern; the end of a function is the line
    where the braces opened on its first line close again.

    Args:
        text: the whole file.
        pattern: JS_FUNC or SH_FUNC.
        comment_mark: '//' or '#'.

    Returns:
        [(name, top line, first line, last line, has inner comment, body text)].
    """
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
            if not opened and j > i + (1 if arrow else 40 if re.search(r'\bfunction\b', line) else 10):
                break   # no body opens: an arrow's opens on its line or the next, a `function` within 40 lines, others 10
            depth, opened = count_braces(lines[j], depth, opened, comment_mark)
            if opened and depth <= 0:
                end = j
                break
        if not opened:
            if arrow:   # an arrow with no braces (`const f = x => x + 1;`) is a one-line function
                found.append((name, i + 1, i + 1, i + 1, False, line))
            continue
        own = '{' not in line and i + 1 < len(lines) and lines[i + 1].strip() == '{'
        k = i + 2 if own else i + 1   # skip the body's `{` when it stands on its own line
        first = lines[k].strip() if end > k else ''   # a one-line function has no inner first line
        found.append((name, i + 1, i + 1, end + 1, first.startswith(comment_mark), '\n'.join(lines[i + 1:end + 1])))
    return found


def count_braces(line, depth, opened, comment_mark):
    """Add the `{` and `}` of one line (outside quotes and comments) to the running depth. A shell `#` starts a
    comment only at the start of a word, so `${#list[@]}` and `${name#prefix}` count as code.

    Args:
        line: one line of the file.
        depth: the brace depth before this line.
        opened: True when a `{` was seen before this line.
        comment_mark: '//' or '#'.

    Returns:
        (depth, opened) after this line.
    """
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
