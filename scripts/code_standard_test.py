#!/usr/bin/env python3
"""Self-test of scripts/code_standard.py (run by `python3 scripts/code_standard.py --test`; kept in its own file so
the check stays under the 600-line cap of docs/code-standard.md C4).

It builds small sample repos in a temporary folder and proves each rule of the check: clean files pass; a function
without a comment, a long function, a grown function, a fixed item left in the baseline, a missing header, a shell
`${#..}` function, JS functions and methods, a parse error, a divider line above a function, a long argument script
block, a shebang file with no extension and two same bodies; and the comparison with origin/main.
Input: the check module. Output: one "pass" line, or an AssertionError naming the rule. Needs git; the PowerShell
cases run only when pwsh 7 is installed (a repo with no PowerShell files never calls it).
"""

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

PS = bool(shutil.which('pwsh'))   # the PowerShell cases need the real parser


def run(cs):
    """Prove the check (the module `cs`) on a sample repo in a temporary folder: clean files pass; a new debt, a grown function and an
    unlowered fixed item each fail; --update refuses new debt; a marked generated block is skipped."""
    good_py = '"""Sample module: it shows a file that meets every rule of the code standard."""\n\n\n' \
              'def add(a, b):\n    """Return a + b."""\n    return a + b\n'
    good_ps = '<#\n  Sample PowerShell file: it shows a file that meets every rule of the code standard.\n#>\n' \
              '# Returns the text in capitals.\nfunction Get-Upper([string]$T) {\n  return $T.ToUpper()\n}\n' \
              '# >>> shared: generated from src/shared.ps1 by build.py (do not edit)\n' \
              'function Get-Copy { return 1 }\n# <<< shared\n'
    with tempfile.TemporaryDirectory() as d:
        cs.ROOT = ROOT = Path(d)
        cs.BASELINE = ROOT / cs.BASELINE_NAME
        g = lambda *c: subprocess.run(['git', '-C', d, *c], check=True, capture_output=True)
        g('init', '-q')
        (ROOT / 'a.py').write_text(good_py)
        PS and (ROOT / 'b.ps1').write_text(good_ps)
        config = {'caps': {'max_function_lines': 5, 'max_file_lines': 50}, 'include': ['*'], 'exclude': [], 'generated': []}
        g('add', '.')
        m = cs.measure(config)
        assert not any(m['violations'].values()), 'clean files pass: %s' % m['violations']
        assert not PS or [f['name'] for f in m['files']['b.ps1']['functions']] == ['Get-Upper'], 'generated block skipped'
        (ROOT / 'a.py').write_text(good_py + '\n\ndef bare(x):\n    return x\n')
        new, fixed = cs.compare(cs.measure(config)['violations'], {}, config['caps'])
        assert len(new) == 1 and 'C2' in new[0] and 'a.py::bare' in new[0], 'a function without a comment fails: %s' % new
        long_fn = '\n\ndef long(x):\n    """Long."""\n' + '    x += 1\n' * 6 + '    return x\n'
        (ROOT / 'a.py').write_text(good_py + long_fn)
        debt = cs.measure(config)['violations']
        assert debt['length'] == {'a.py::long': 9}, 'a long function is debt: %s' % debt['length']
        (ROOT / 'a.py').write_text(good_py + long_fn.replace('    return x', '    x += 1\n    return x'))
        new, fixed = cs.compare(cs.measure(config)['violations'], debt, config['caps'])
        assert len(new) == 1 and 'grew from 9 to 10' in new[0], 'a listed function that grew fails: %s' % new
        (ROOT / 'a.py').write_text(good_py)
        new, fixed = cs.compare(cs.measure(config)['violations'], debt, config['caps'])
        assert not new and len(fixed) == 1, 'a fixed item is reported (and fails until the baseline is lowered)'
        (ROOT / 'c.sh').write_text('echo hi\n')
        g('add', '.')
        new, _ = cs.compare(cs.measure(config)['violations'], {}, config['caps'])
        assert any('C1' in x and 'c.sh' in x for x in new), 'a file without a header fails: %s' % new
        self_test_kinds(cs, ROOT, g, config)
        self_test_forms(cs, ROOT, g, config)
        self_test_main(cs, ROOT, g)
        self_test_init(cs, ROOT)
        self_test_docs(cs, ROOT, g, config)
    print('code standard self-test: pass')
    return 0


def self_test_kinds(cs, root, g, config):
    """Self-test of the finding kinds: a shell `${#..}` function is measured whole, a JS function and method are found,
    a PowerShell parse error fails, a header or divider line is not a function's comment, a long argument script block
    is measured, a shebang file with no extension is checked, and two same bodies are duplicates."""
    sh = '#!/usr/bin/env bash\n# Sample shell file: it shows how functions are measured by the check.\n# Counts.\nf() {\n  n=${#a[@]}\n' \
         + '  x=1\n' * 6 + '}\n'
    (root / 'c.sh').write_text(sh)
    js = '// Sample JavaScript file: it shows how functions and methods are found by the check.\n' \
         'function plain(a) {\n  return a;\n}\nclass K {\n  // Adds one.\n  inc(x) {\n    return x + 1;\n  }\n}\n'
    (root / 'd.js').write_text(js)
    PS and (root / 'e.ps1').write_text('<#\n  Sample PowerShell file with a parse error, for the check self-test only.\n#>\n$x = (1 + \n')
    blk = '<#\n  Sample PowerShell file: a long script block passed to a call, for the check self-test only.\n#>\n' \
          '# ---- a divider\nfunction Get-NoDoc { return 1 }\n$b.Add_Click({\n' + '  $y = 1\n' * 6 + '})\n'
    PS and (root / 'f.ps1').write_text(blk)
    (root / 'hook').write_text('#!/bin/sh\necho no header here\n')
    dup = '"""Sample module with two same bodies, for the check self-test only (rule C5)."""\n\n\n' + ''.join(
        'def %s(x):\n    """Same body."""\n    y = x + 1\n    y = y * 2\n    y = y - 3\n    return y\n\n\n' % n for n in ('one', 'two'))
    (root / 'g.py').write_text(dup)
    g('add', '.')
    v = cs.measure(config)['violations']
    assert v['length'].get('c.sh::f') == 9, 'shell ${#..}: the whole function is measured: %s' % v['length']
    assert 'd.js::plain' in v['comment'] and 'd.js::inc' not in v['comment'], 'JS function and method: %s' % v['comment']
    assert not PS or v['parse'].get('e.ps1', 0) >= 1, 'a PowerShell parse error fails: %s' % v['parse']
    assert not PS or 'f.ps1::Get-NoDoc' in v['comment'], 'a divider line is not a comment: %s' % v['comment']
    assert not PS or any(k.startswith('f.ps1::{block in $b.Add_Click') for k in v['length']), 'a long argument block: %s' % v['length']
    assert 'hook' in v['header'], 'a shebang file with no extension is checked: %s' % v['header']
    assert set(v['duplicate']) == {'g.py::one', 'g.py::two'}, 'two same bodies are duplicates: %s' % v['duplicate']
    for f in ('c.sh', 'd.js', 'e.ps1', 'f.ps1', 'hook', 'g.py'):
        (root / f).unlink(missing_ok=True)
    g('add', '-A')


def self_test_main(cs, root, g):
    """Self-test of the comparison with main: an item added by hand and a raised cap fail; a cap change with a
    DECISIONS row that names the baseline passes."""
    cs.BASELINE = root / cs.BASELINE_NAME
    base = {'config': {'caps': {'max_function_lines': 5, 'max_file_lines': 50}}, 'debt': {'comment': {'a.py::x': 1}}}
    cs.BASELINE.write_text(json.dumps(base))
    (root / 'docs').mkdir()
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n')
    g('add', '.')
    g('-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-qm', 'base')
    g('update-ref', 'refs/remotes/origin/main', 'HEAD')
    assert cs.against_main(base)[0] == [], 'the same baseline passes'
    added = {'config': base['config'], 'debt': {'comment': {'a.py::x': 1, 'a.py::y': 1}}}
    assert 'added by hand' in ' '.join(cs.against_main(added)[0]), 'an item added by hand fails'
    raised = {'config': {'caps': {'max_function_lines': 9, 'max_file_lines': 50}}, 'debt': base['debt']}
    assert 'config' in ' '.join(cs.against_main(raised)[0]), 'a raised cap fails'
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n| cap 9 | .code-standard.json |\n')
    assert cs.against_main(raised)[0] == [], 'a cap change with a DECISIONS row passes'


def self_test_forms(cs, root, g, config):
    """Self-test of function forms and comment places: shell `function name {` and a brace on the next line are found;
    a comment after a one-line function, or a file help header, is not that function's comment; a Python `#` line
    before the first statement counts; an arrow with no braces is not a function; bodies that differ only in their
    docstrings are duplicates; a Python parse error fails."""
    (root / 'h.sh').write_text('#!/bin/sh\n# Sample shell file: two function forms, for the check self-test only.\n'
                               'function longfn {\n  a=1\n}\nnext()\n{\n  b=2\n}\n')
    PS and (root / 'i.ps1').write_text('<#\n.SYNOPSIS\n  Sample PowerShell file: a help header, for the check self-test only.\n#>\n'
                                'function Get-A { 1 }\n# Returns two.\nfunction Get-B { 2 }\n')
    (root / 'j.py').write_text('"""Sample module: comment places and duplicates, for the check self-test only."""\n\n\n'
                               'def lead(x):\n    # Returns x.\n    return x\n\n\n' + ''.join(
                                   'def %s(x):\n    """%s"""\n    y = x + 1\n    y = y * 2\n    y = y - 3\n    return y\n\n\n'
                                   % (n, doc) for n, doc in (('p', 'One.'), ('q', 'Two.'))))
    (root / 'k.js').write_text('// Sample JavaScript file: an arrow with no braces, for the check self-test only.\n\n'
                               '// Adds one.\nconst inc = x => x + 1;\n// Doubles.\nfunction dbl(x) {\n  return 2 * x;\n}\n')
    (root / 'l.py').write_text('"""Sample module that does not parse, for the check self-test only (rule C10)."""\ndef (:\n')
    g('add', '.')
    v = cs.measure(config)['violations']
    assert {'h.sh::longfn', 'h.sh::next'} <= set(v['comment']), 'shell function forms are found: %s' % v['comment']
    assert not PS or 'i.ps1::Get-A' in v['comment'] and 'i.ps1::Get-B' not in v['comment'], 'comment places: %s' % v['comment']
    assert 'j.py::lead' not in v['comment'], 'a Python lead comment counts: %s' % v['comment']
    assert {'j.py::p', 'j.py::q'} <= set(v['duplicate']), 'docstring-only difference is a duplicate: %s' % v['duplicate']
    assert not any(k.startswith('k.js::') for k in v['comment'].keys() | v['length'].keys()), 'arrow: %s' % v['length']
    assert v['parse'].get('l.py'), 'a Python parse error fails: %s' % v['parse']
    self_test_edges(cs, root, g, config)
    for f in ('h.sh', 'i.ps1', 'j.py', 'k.js', 'l.py'):
        (root / f).unlink(missing_ok=True)
    g('add', '-A')


def self_test_edges(cs, root, g, config):
    """Self-test of edge forms: a JS function whose `{` comes after long parameters is measured; a bare arrow without a
    comment fails; a comment above a nested Python def is not the outer function's; PowerShell help after a `{` on its
    own line, or at the end of the body, counts; a shell comment after a `{` on its own line counts."""
    (root / 'm.js').write_text('// Sample JavaScript file: edge forms, for the check self-test only.\n'
                               'function longParams(\n  alpha,\n  beta\n) {\n  return alpha + beta;\n}\nconst bare = x => x * 3;\n')
    (root / 'n.py').write_text('"""Sample module: a nested def, for the check self-test only."""\n\n\n'
                               'def outer(x):\n    # Helper.\n    def inner(y):\n        return y\n    return inner(x)\n')
    PS and (root / 'o.ps1').write_text('<#\n  Sample PowerShell file: help in the body, for the check self-test only.\n#>\n\n'
                                'function Get-X\n{\n  <#\n  .SYNOPSIS\n  Returns one.\n  #>\n  1\n}\n\n'
                                'function Get-Y {\n  2\n  <#\n  .SYNOPSIS\n  Returns two.\n  #>\n}\n')
    (root / 'p.sh').write_text('#!/bin/sh\n# Sample shell file: a brace on its own line, for the check self-test only.\n\n'
                               'next()\n{\n  # Does b.\n  b=2\n}\n')
    g('add', '.')
    v = cs.measure(config)['violations']
    assert 'm.js::longParams' in v['comment'] and 'm.js::bare' in v['comment'], 'JS edge forms: %s' % v['comment']
    assert 'n.py::outer' in v['comment'] and 'n.py::outer.inner' not in v['comment'], 'nested def: %s' % v['comment']
    assert not PS or not {'o.ps1::Get-X', 'o.ps1::Get-Y'} & set(v['comment']), 'help in the body counts: %s' % v['comment']
    assert 'p.sh::next' not in v['comment'], 'a shell comment after `{` counts: %s' % v['comment']
    PS and (root / 'q.ps1').write_text('<#\n  Sample PowerShell file: help that is not the function own, for the self-test only.\n#>\n\n'
                                'function Outer {\n  function Inner {\n    <#\n    .SYNOPSIS\n    Inner.\n    #>\n    1\n  }\n  Inner\n}\n\n'
                                'function Plain {\n  $x = 1  # see .DESCRIPTION of Foo\n  $x\n}\n')
    (root / 'r.py').write_text('"""Sample module: an outer comment and a nested def, for the self-test only."""\n\n\n'
                               'def outer2():\n    # Outer does X.\n\n    def inner2():\n        return 1\n    return inner2()\n')
    g('add', '.')
    v = cs.measure(config)['violations']
    assert not PS or {'q.ps1::Outer', 'q.ps1::Plain'} <= set(v['comment']), 'help must be the function own: %s' % v['comment']
    assert 'r.py::outer2' not in v['comment'], 'an outer comment before a blank line counts: %s' % v['comment']
    (root / 's.js').write_text('// Sample JavaScript file: a long signature, for the self-test only.\n\n'
                               'function k(\n' + '  a,\n' * 12 + ') {\n  return 1;\n}\n')
    PS and (root / 't.ps1').write_text('<#\n  Sample PowerShell file: a block comment first in the body, for the self-test only.\n#>\n\n'
                                'function Blk {\n  <# Does a thing. #>\n  1\n}\n')
    (root / 'u.py').write_text('"""Sample module: a decorated nested def, for the self-test only."""\n\n\n'
                               'def deco(f):\n    # Wraps f.\n    @staticmethod\n    def w():\n        return f\n    return w\n')
    g('add', '.')
    v = cs.measure(config)['violations']
    assert 's.js::k' in v['comment'], 'a long JS signature is still a function: %s' % v['comment']
    assert not PS or 't.ps1::Blk' not in v['comment'], 'a first-line block comment counts: %s' % v['comment']
    assert 'u.py::deco' in v['comment'], 'a comment above a nested decorator is not the outer one: %s' % v['comment']
    for f in ('m.js', 'n.py', 'o.ps1', 'p.sh', 'q.ps1', 'r.py', 's.js', 't.ps1', 'u.py'):
        (root / f).unlink(missing_ok=True)


def self_test_init(cs, root):
    """Self-test of adoption: with no baseline the check fails and --report writes nothing; --init writes the first
    baseline once; a second --init is refused, so it cannot add debt."""
    import contextlib
    import io
    import sys

    def main(*args):
        """Run cs.main() with these arguments; return its exit code."""
        sys.argv = ['code_standard.py', *args]
        with contextlib.redirect_stdout(io.StringIO()):
            return cs.main()
    saved = sys.argv
    try:
        cs.BASELINE.unlink()
        assert main() == 1, 'no baseline: the check fails'
        assert main('--init', '--report') == 0 and not cs.BASELINE.exists(), '--report writes no baseline'
        assert main('--init') == 0 and cs.BASELINE.exists(), '--init writes the first baseline'
        assert main('--init') == 1, 'a second --init is refused'
    finally:
        sys.argv = saved


def self_test_docs(cs, root, g, config):
    """Self-test of the opt-in C2 full rule ("c2": "full"): a long function without full docs fails and --report names
    the missing parts; complete Python, JavaScript and PowerShell docs pass; a short function needs only the lean
    comment; --adopt lists the new rule's debt once and refuses a second time."""
    full = dict(config, caps={'max_function_lines': 60, 'max_file_lines': 600}, c2='full')
    body = '    y = x\n' * 9
    (root / 'f.py').write_text('"""Sample module for the C2 full self-test: two long functions and a short one."""\n\n\n'
                               'def bare(x, *rest):\n    """Adds."""\n' + body + '    return y\n\n\n'
                               'def full(x):\n    """Adds.\n\n    Args:\n        x: a number.\n\n    Returns:\n        y.\n    """\n'
                               + body + '    return y\n\n\ndef short(x):\n    """Adds."""\n    return x\n')
    js = '// Sample JavaScript file for the C2 full self-test.\n/**\n * Adds.\n * @param {number} a first\n * @returns {number}\n */\n' \
         'function good(a) {\n' + '  let y = a;\n' * 9 + '  return y;\n}\n// Adds.\nfunction bad(a, {b}) {\n' \
         + '  let y = a;\n' * 9 + '  return y;\n}\n'
    (root / 'g.js').write_text(js)
    if PS:
        lines = '  $y = 1\n' * 9
        (root / 'h.ps1').write_text('<#\n  Sample PowerShell file for the C2 full self-test: one complete and one incomplete.\n#>\n\n'
                                    '<#\n.SYNOPSIS\n  Adds.\n.PARAMETER Path\n  A path.\n#>\nfunction Get-Good([string]$Path) {\n'
                                    + lines + '}\n# Adds.\nfunction Get-Bad([string]$Path) {\n' + lines + '}\n')
    g('add', '.')
    m = cs.measure(full)
    docs = m['violations']['docs']
    want = {'f.py::bare', 'g.js::bad'} | ({'h.ps1::Get-Bad'} if PS else set())
    assert want <= set(docs) and not {'f.py::full', 'f.py::short', 'g.js::good', 'h.ps1::Get-Good'} & set(docs), \
        'C2 full finds the long functions without full docs: %s' % docs
    gaps = {f['name']: f.get('docs_missing') for f in m['files']['f.py']['functions']}
    assert gaps['bare'] == ['Args: x', 'Args: rest', 'Returns:'], 'the report names the missing parts: %s' % gaps
    jgaps = {f['name']: f.get('docs_missing') for f in m['files']['g.js']['functions']}
    assert jgaps['bad'] == ['JSDoc'], 'a plain comment is not JSDoc: %s' % jgaps
    self_test_docs_forms(cs.docs)
    if PS:
        g('rm', '-q', '--cached', '--', '*.ps1')   # the later steps need no PowerShell: each parser run costs a second
    assert not cs.measure(config)['violations']['docs'], 'without "c2": "full" the rule is off'
    safety = cs.measure(dict(full, c1_safety=True))['violations']['safety']
    assert 'f.py' in safety and 'g.js' in safety, 'C1 safety: a header without the three lines fails: %s' % safety
    text = (root / 'f.py').read_text().replace('a short one."""', 'a short one.\n\nNetwork: none. Writes: none. Credentials: none.\n"""', 1)
    (root / 'f.py').write_text(text)
    assert 'f.py' not in cs.measure(dict(full, c1_safety=True))['violations']['safety'], 'C1 safety: the three lines pass'
    cs.BASELINE.write_text(json.dumps({'config': full, 'debt': {}}))
    import contextlib
    import io
    import sys
    saved = sys.argv
    try:
        sys.argv = ['code_standard.py', '--adopt']
        with contextlib.redirect_stdout(io.StringIO()):
            assert cs.main() == 0, '--adopt lists a rule that was just turned on'
            assert set(json.loads(cs.BASELINE.read_text())['debt']['docs']) == want - {'h.ps1::Get-Bad'}, '--adopt writes its debt'
            assert cs.main() == 1, 'a second --adopt is refused (the kind is listed now)'
        self_test_adopt_ratchet(cs, root, g, full)
    finally:
        sys.argv = saved


def self_test_docs_forms(docs):
    """Self-test of the parsing edge cases of scripts/code_standard_docs.py (found by the first fresh review): an arrow
    function's parameter is read from its signature, not its body; a comma in a quoted default is not a separator; a
    return in a nested callback is not the function's own; a Python Args: section ends at Returns:; a plain /* */
    comment above a function is not JSDoc."""
    assert docs.js_params(['const f = x => {', '  foo(q);', '};'], 1) == ['x'], 'arrow parameter from the signature'
    assert docs.js_params(['function f(a = ",", b) {', '}'], 1) == ['a', 'b'], 'a quoted comma is not a separator'
    assert not docs.js_returns_value('  a.forEach(v => {\n    return v;\n  });\n}'), 'a nested return is not counted'
    assert docs.js_returns_value('{\n  return 1;\n}'), 'a return under a `{` on its own line is counted'
    assert docs.js_params(['const h = async x => {', '};'], 1) == ['x'], 'an async arrow parameter is read'
    assert docs.js_missing(['/** K.', ' * @param {{a: number}} o', ' */', 'function k(o) {', '}'], 4, 4, '}') == [], \
        'a JSDoc type with nested braces is read'
    lead = docs.python_docs('def g(a, b):\n    """Do.\n\n    Args:\n        b: the value of\n            a value.\n    """\n    return None\n')
    assert docs.python_missing(lead, 1) == ['Args: a'], 'a word in a continuation line is not an Args entry; return None is no value'
    facts = docs.python_docs('def f(x, value):\n    """Do.\n\n    Args:\n        x: a.\n\n    Returns:\n        value: b.\n    """\n')
    assert docs.python_missing(facts, 1) == ['Args: value'], 'Args: ends at Returns:'
    lines = ['/** Other. */', 'function a() {', '}', '/* plain */', 'function b(z) {', '  return z;', '}']
    assert docs.js_missing(lines, 5, 5, '  return z;\n}') == ['JSDoc'], 'a plain /* */ comment is not JSDoc'


def self_test_adopt_ratchet(cs, root, g, full):
    """Self-test of the ratchet around --adopt: a core rule is never adopted, and the comparison with main accepts a
    first debt list only for an opt-in rule that was off on main, with a DECISIONS row."""
    g('add', '.')
    g('-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-q', '-m', 'base')
    g('update-ref', 'refs/remotes/origin/main', 'HEAD')
    base = {'config': dict(full, c2='lean'), 'debt': {}}
    cs.BASELINE.write_text(json.dumps(base))
    g('add', '.')
    g('-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-q', '-m', 'baseline')
    g('update-ref', 'refs/remotes/origin/main', 'HEAD')
    (root / 'docs').mkdir(exist_ok=True)
    (root / 'docs' / 'DECISIONS.md').write_text('| row | names %s |\n' % cs.BASELINE_NAME)
    hand = dict(base, debt={'length': {'x.py::f': 99}})
    assert cs.against_main(hand)[0], 'a core rule debt added by hand fails, even with a DECISIONS row'
    on = {'config': full, 'debt': {'docs': {'f.py::bare': 1}}}
    assert not cs.against_main(on)[0], 'an opt-in rule turned on now: its first list passes with a DECISIONS row'
    (root / 'docs' / 'DECISIONS.md').unlink()
    assert cs.against_main(on)[0], 'the same list fails with no DECISIONS row'
