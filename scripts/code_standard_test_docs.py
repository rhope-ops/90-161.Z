#!/usr/bin/env python3
"""Self-test cases of the opt-in C2 full rule of scripts/code_standard.py (`code-c2: full`): a long function without
full docs fails and --report names the gaps, the doc forms of each language are read, and --adopt lists the debt of
the rule once, with the comparison with main.

Kept apart from scripts/code_standard_test.py for the line cap (docs/code-standard.md C4); its run_cases() calls
self_test_docs. The sample repo helpers come from scripts/code_standard_test_gate.py.
Input: the check module and its sample repo. Output: none (an AssertionError names the failed case). Needs git.
Usage:   no command line; `python3 scripts/code_standard.py --test` runs it through scripts/code_standard_test.py.
Network: none.
Writes: temporary folders only.
Credentials: none.
"""

import check_settings as settings   # scripts/check_settings.py: the settings files
from code_standard_test_gate import FULL, PS, commit, config_of, main, write


def self_test_docs(cs, root, g, config):
    """Self-test of the opt-in C2 full rule (`code-c2: full`): a long function without full docs fails and --report names
    the missing parts; complete Python, JavaScript and PowerShell docs pass; a short function needs only the lean
    comment; --adopt lists the new rule's debt once and refuses a second time.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
        config: the settings of the sample repo.
    """
    full = config_of(root, FULL)
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
    assert not cs.measure(config)['violations']['docs'], 'without `code-c2: full` the rule is off'
    safe = config_of(root, FULL + 'code-c1-safety: on\n')
    safety = cs.measure(safe)['violations']['safety']
    assert 'f.py' in safety and 'g.js' in safety, 'C1 safety: a header without the three lines fails: %s' % safety
    text = (root / 'f.py').read_text().replace('a short one."""', 'a short one.\n\nNetwork: none. Writes: none. Credentials: none.\n"""', 1)
    (root / 'f.py').write_text(text)
    assert 'f.py' not in cs.measure(safe)['violations']['safety'], 'C1 safety: the three lines pass'
    write(root, FULL, {})
    assert main(cs, '--adopt') == 0, '--adopt lists a rule that was just turned on'
    assert set(cs.load()[1]['docs']) == want - {'h.ps1::Get-Bad'}, '--adopt writes its debt'
    assert main(cs, '--adopt') == 1, 'a second --adopt is refused (the kind is listed now)'
    self_test_adopt_ratchet(cs, root, g, full)


def self_test_docs_forms(docs):
    """Self-test of the parsing edge cases of scripts/code_standard_docs.py (found by the first fresh review): an arrow
    function's parameter is read from its signature, not its body; a comma in a quoted default is not a separator; a
    return in a nested callback is not the function's own; a Python Args: section ends at Returns:; a plain /* */
    comment above a function is not JSDoc.

    Args:
        docs: the module scripts/code_standard_docs.py.
    """
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
    first debt list only for an opt-in rule that was off on main, with a DECISIONS row.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
        full: the settings with `code-c2: full`.
    """
    write(root, 'code-c2: lean\n', {})
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n')
    commit(g, 'baseline')
    lean = settings.code_config(root)
    (root / 'docs' / 'DECISIONS.md').write_text('| row | names %s |\n' % settings.CHECK)
    assert cs.against_main(lean, {'length': {'x.py::f': 99}})[0], 'a core rule debt added by hand fails, even with a DECISIONS row'
    on = {'docs': {'f.py::bare': 1}}
    assert not cs.against_main(full, on)[0], 'an opt-in rule turned on now: its first list passes with a DECISIONS row'
    (root / 'docs' / 'DECISIONS.md').unlink()
    assert cs.against_main(full, on)[0], 'the same list fails with no DECISIONS row'
