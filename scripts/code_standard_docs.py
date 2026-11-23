#!/usr/bin/env python3
"""Full function docs for the code standard: the opt-in rule `code-c2: full` of docs/code-standard.md (C2 full).

Why: a project that other units must inspect before they run its code asks for more than a one-line comment: each
function says what it takes and what it gives back, in the form its language's own help tools read. The kit's rule
C2 stays lean (one line); a project turns this on with the line `code-c2: full` in its .check (a DECISIONS row, as for caps).

What it checks, for a function longer than SHORT_FUNCTION lines (a shorter one keeps the lean C2 comment):
  Python      a docstring; when the function takes parameters, an "Args:" section that names each one (not self, cls);
              when it returns a value, a "Returns:" section (PEP 257 docstring, Google style sections)
  PowerShell  comment-based help (.SYNOPSIS or .DESCRIPTION) with one .PARAMETER for each parameter
              (about_Comment_Based_Help); for a script block kept in a variable, help inside the block
  JavaScript  a /** */ JSDoc block directly above, with one @param for each parameter and @returns when the function
              returns a value
  Shell       not checked here (no parameter list); the lean C2 comment applies
Inputs:  one file's text and the functions scripts/code_standard.py found in it. Outputs: the parts that are missing.
Network: none.
Writes: none.
Credentials: none.
Run:     imported by scripts/code_standard.py; proved by `python3 scripts/code_standard.py --test`.
"""

import ast
import re

SHORT_FUNCTION = 10   # lines; a function this short needs only the lean C2 comment (the Maintainer's 3B, 2026-11-17)
RETURNS_VALUE = re.compile(r'\breturn\s+[^\s;}]')   # `return x`, not a bare `return` or `return;`


def python_docs(text):
    """Map each def's line number to its doc facts, for a Python file.

    Args:
        text: the whole file.

    Returns:
        {def line: (parameter names, docstring or '', True when it returns a value)}.
    """
    facts = {}
    for node in ast.walk(ast.parse(text)):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            a = node.args
            names = [x.arg for x in a.posonlyargs + a.args + a.kwonlyargs]
            names += [x.arg for x in (a.vararg, a.kwarg) if x]
            names = [n for n in names if n not in ('self', 'cls')]
            own = [n for n in ast.walk(node) if isinstance(n, ast.Return) and n.value is not None
                   and not (isinstance(n.value, ast.Constant) and n.value.value is None)
                   and owner_of(node, n)]
            facts[node.lineno] = (names, ast.get_docstring(node) or '', bool(own))
    return facts


def owner_of(func, ret):
    """True when the return statement `ret` belongs to `func` itself, not to a function nested in it.

    Args:
        func: the function node.
        ret: a Return node somewhere inside it.

    Returns:
        True or False.
    """
    for node in ast.walk(func):
        if node is not func and isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            if any(x is ret for x in ast.walk(node)):
                return False
    return True


def python_missing(facts, def_line):
    """Return the missing parts of one Python function's docs, as short labels (an empty list when complete).

    Args:
        facts: the result of python_docs() for the file.
        def_line: the line of the `def`.

    Returns:
        A list such as ['docstring'], ['Args: x'] or ['Returns:'].
    """
    names, doc, returns = facts.get(def_line, ([], '', False))
    if not doc:
        return ['docstring']
    miss = []
    if names:
        args = re.split(r'^\s*Args:\s*$', doc, maxsplit=1, flags=re.M)
        listed = args[1] if len(args) == 2 else ''
        listed = re.split(r'^\s*(?:Returns?|Raises|Yields|Examples?|Notes?):', listed, maxsplit=1, flags=re.M)[0]
        miss += ['Args: ' + n for n in names
                 if not re.search(r'^\s*\*{0,2}%s\s*(\(.*\))?:' % re.escape(n), listed, re.M)]   # `name:` or `name (type):`
    if returns and not re.search(r'^\s*Returns?:', doc, re.M):
        miss.append('Returns:')
    return miss


def powershell_missing(doc):
    """Return the missing parts of one PowerShell function's help, from what the parser reported.

    Args:
        doc: {"params": [names], "help": [.PARAMETER names, upper case], "synopsis": bool}, or None when the parser
             gave nothing.

    Returns:
        A list such as ['help'] or ['.PARAMETER Path'].
    """
    if not doc or not doc.get('synopsis'):
        return ['help']
    known = {str(n).upper() for n in (doc.get('help') or [])}
    return ['.PARAMETER ' + p for p in (doc.get('params') or []) if p.upper() not in known]


def js_params(lines, start):
    """Return the parameter names of the JavaScript function that starts on line `start` (1-based).

    Args:
        lines: the file's lines.
        start: the line of the function's signature.

    Returns:
        Names in order; a destructured parameter ({a, b} or [a]) is returned as '' (any @param name covers it).
    """
    text = ' '.join(lines[start - 1:start + 9])
    sig = re.split(r'=>|\{', text, maxsplit=1)[0] if '(' not in text.split('=>')[0] else text
    open_at = sig.find('(')
    if open_at < 0:
        m = re.search(r'=\s*(?:async\s+)?([A-Za-z_$][\w$]*)\s*=>', text)   # `const f = x => ...`, `= async x =>`
        return [m.group(1)] if m else []
    depth, out, cur, quote = 0, [], '', None
    for c in text[open_at + 1:]:   # the text after the `(` of the parameter list
        if quote or c in '"\'`':
            quote = None if c == quote else (quote or c)
            cur += c
            continue
        if depth == 0 and c == ')':
            break
        if depth == 0 and c == ',':
            out.append(cur)
            cur = ''
            continue
        depth += (c in '([{') - (c in ')]}')
        cur += c
    out.append(cur)
    names = []
    for raw in out:
        p = raw.split('=')[0].strip().lstrip('.')
        if p:
            names.append('' if p[0] in '{[' else p)
    return names


def js_missing(lines, top, start, body):
    """Return the missing parts of one JavaScript function's JSDoc.

    Args:
        lines: the file's lines.
        top: the first line of the function (1-based).
        start: the line of its signature.
        body: the function's text.

    Returns:
        A list such as ['JSDoc'], ['@param a'] or ['@returns'].
    """
    k = top - 2
    if k < 0 or not lines[k].strip().endswith('*/'):
        return ['JSDoc']
    while k >= 0 and '/*' not in lines[k]:
        k -= 1   # the start of the comment block that ends right above the function
    if k < 0 or '/**' not in lines[k]:
        return ['JSDoc']   # a plain /* */ comment is not JSDoc
    doc = '\n'.join(lines[k:top - 1])
    tags = re.findall(r'@param\s+(?:\{(?:[^{}]|\{[^{}]*\})*\}\s*)?\[?([\w$.]+)', doc)   # a type may hold one {} level
    miss = []
    for i, name in enumerate(js_params(lines, start)):
        if (name and name not in tags) or (not name and len([t for t in tags if '.' not in t]) <= i):
            miss.append('@param ' + (name or '#%d' % (i + 1)))
    if js_returns_value(body) and not re.search(r'@returns?\b', doc):
        miss.append('@returns')
    return miss


def js_returns_value(body):
    """True when the function body returns a value itself (a `return x` at its own brace level, not in a nested callback).

    Args:
        body: the function's lines after its signature line, up to its closing brace.

    Returns:
        True or False.
    """
    lines = body.split('\n')
    depth = -1 if lines and lines[0].strip() == '{' else 0   # the body's `{` on its own line opens level 0
    quote = None
    for line in lines:
        code = line.split('//')[0]
        for k, c in enumerate(code):
            if quote:
                quote = None if c == quote else quote
            elif c in '"\'`':
                quote = c
            elif c in '{}':
                depth += 1 if c == '{' else -1
            elif depth == 0 and RETURNS_VALUE.match(code, k) and (k == 0 or not code[k - 1].isalnum()):
                return True
    return False


def missing(lang, lines, func, extra, py_facts):
    """Return the missing parts of one function's full docs, or [] when they are complete or not required.

    Args:
        lang: 'python', 'powershell', 'js' or 'shell'.
        lines: the file's lines.
        func: (name, top, first line, last line, has inner comment, body), as scripts/code_standard.py finds it.
        extra: the PowerShell parser's doc facts for this function, or None.
        py_facts: python_docs() of the file, or None for other languages.

    Returns:
        A list of short labels.
    """
    _, top, start, end, _, body = func
    if end - start + 1 <= SHORT_FUNCTION:
        return []
    if lang == 'python':
        return python_missing(py_facts or {}, start)
    if lang == 'powershell':
        return powershell_missing(extra)
    if lang == 'js':
        return js_missing(lines, top, start, body)
    return []
