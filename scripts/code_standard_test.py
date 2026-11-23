#!/usr/bin/env python3
"""Self-test of scripts/code_standard.py (run by `python3 scripts/code_standard.py --test`; kept in its own file so
the check stays under the line cap of docs/code-standard.md C4).

It builds small sample repos in a temporary folder and proves each rule of the check: clean files pass; a function
without a comment, a long function, a grown function, a fixed item left in the baseline, a missing header, a shell
`${#..}` function, JS functions and methods, a parse error, a divider line above a function, a long argument script
block, a shebang file with no extension and two same bodies; the settings in `.check` (a line that is not valid
fails); the comparison with origin/main (also with the old .code-standard.json on the merge base); and the extension
point (self_test_gate): a sample gate file in a temporary folder is loaded and called, and a gate that is broken,
incomplete or missing for a setting that needs one fails the check. The cases run without the project's own gate.
Input: the check module. Output: one "pass" line, or an AssertionError naming the rule. Needs git; the PowerShell
cases run only when pwsh 7 is installed (a repo with no PowerShell files never calls it).
Network: none.
Writes: temporary folders only.
Credentials: none.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import check_settings as settings   # scripts/check_settings.py: the reader of .check and .check.state.json
# scripts/code_standard_test_gate.py and scripts/code_standard_test_docs.py: more case groups (kept apart, rule C4).
from code_standard_test_gate import (FULL, PS, SAMPLE_GATE, SMALL, commit, config_of, fails, main,  # noqa: F401
                                     self_test_gate, self_test_gate_ratchet, write)
from code_standard_test_docs import self_test_adopt_ratchet, self_test_docs, self_test_docs_forms  # noqa: F401


def run(cs):
    """Prove the check on sample repos, without the project's own gate (its file name is pointed at a path that does
    not exist while the cases run; the gate's own self-test proves the gate).

    Args:
        cs: the check module.

    Returns:
        The exit code 0 (an assert stops on a failure).
    """
    real_gate = cs.GATE_FILE
    try:
        with tempfile.TemporaryDirectory() as d:
            cs.GATE_FILE, cs.GATE = Path(d) / 'gate' / 'code_standard_gate.py', None
            run_cases(cs, Path(d) / 'repo')
    finally:
        cs.GATE_FILE, cs.GATE = real_gate, None
    print('code standard self-test: pass')
    return 0


def run_cases(cs, ROOT):
    """Prove the check on a sample repo: clean files pass; a new debt, a grown function and an unlowered fixed item
    each fail; --update refuses new debt; a marked generated block is skipped; then the other case groups.

    Args:
        cs: the check module.
        ROOT: the folder for the sample repo (made here).
    """
    good_py = '"""Sample module: it shows a file that meets every rule of the code standard."""\n\n\n' \
              'def add(a, b):\n    """Return a + b."""\n    return a + b\n'
    good_ps = '<#\n  Sample PowerShell file: it shows a file that meets every rule of the code standard.\n#>\n' \
              '# Returns the text in capitals.\nfunction Get-Upper([string]$T) {\n  return $T.ToUpper()\n}\n' \
              '# >>> shared: generated from src/shared.ps1 by build.py (do not edit)\n' \
              'function Get-Copy { return 1 }\n# <<< shared\n'
    if True:   # one sample repo for every case group
        ROOT.mkdir()
        cs.ROOT, d = ROOT, str(ROOT)
        g = lambda *c: subprocess.run(['git', '-C', d, *c], check=True, capture_output=True)
        g('init', '-q')
        (ROOT / 'a.py').write_text(good_py)
        PS and (ROOT / 'b.ps1').write_text(good_ps)
        config = config_of(ROOT, SMALL)
        assert config['caps'] == {'max_function_lines': 5, 'max_file_lines': 50, 'max_file_lines_paste': 600}, \
            'the caps come from .check: %s' % config
        g('add', '.')
        m = cs.measure(config)
        assert not any(m['violations'].values()), 'clean files pass: %s' % m['violations']
        assert not PS or [f['name'] for f in m['files']['b.ps1']['functions']] == ['Get-Upper'], 'generated block skipped'
        (ROOT / 'p.py').write_text(good_py + '#\n' * 50)   # 57 lines: over the file cap 50 of SMALL
        g('add', 'p.py')
        sizes = [cs.measure(config_of(ROOT, SMALL + extra))['violations']['file_size'] for extra in
                 ('', 'code-paste: p.py\n', 'code-paste: p.py\ncode-max-file-lines-paste: 52\n')]
        assert sizes == [{'p.py': 57}, {}, {'p.py': 57}], 'a `code-paste:` file has its own cap: %s' % sizes
        g('rm', '-qf', 'p.py')
        config = config_of(ROOT, SMALL)
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
        self_test_gate(cs, ROOT, g)


def self_test_kinds(cs, root, g, config):
    """Self-test of the finding kinds: a shell `${#..}` function is measured whole, a JS function and method are found,
    a PowerShell parse error fails, a header or divider line is not a function's comment, a long argument script block
    is measured, a shebang file with no extension is checked, and two same bodies are duplicates.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
        config: the settings of the sample repo.
    """
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
    """Self-test of the comparison with main: an item added by hand and a changed setting fail; a setting change with
    a DECISIONS row that names .check passes (a row that names only .check.state.json does not); a `code-` line that
    is not valid fails the check; the old .code-standard.json on the merge base is still compared.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    config, debt = settings.code_config(root), {'comment': {'a.py::x': 1}}
    write(root, SMALL, debt)
    (root / 'docs').mkdir()
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n')
    commit(g, 'base')
    assert cs.load() == (config, debt), 'the settings and the debt are read back'
    assert cs.against_main(config, debt)[0] == [], 'the same baseline passes'
    added = {'comment': {'a.py::x': 1, 'a.py::y': 1}}
    assert 'added by hand' in ' '.join(cs.against_main(config, added)[0]), 'an item added by hand fails'
    for lines in (SMALL.replace(': 5', ': 9'), SMALL + 'code-exclude: a.py\n', 'code-max-file-lines: 50\n'):
        raised = config_of(root, lines)
        assert 'setting' in ' '.join(cs.against_main(raised, debt)[0]), 'a setting changed, added or removed fails: ' + lines
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n| cap 9 | .check.state.json |\n')
    assert cs.against_main(raised, debt)[0], 'a row that names another file is no decision'
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n| cap 9 | `.check` |\n')
    assert cs.against_main(raised, debt)[0] == [], 'a setting change with a DECISIONS row passes'
    for bad in ('code-max-function-line: 900\n', 'code-max-function-lines: lots\n'):
        write(root, SMALL + bad)
        assert main(cs) == 1, 'an unknown code- key or a bad value fails the check: ' + bad
    self_test_transition(cs, root, g)


def self_test_transition(cs, root, g):
    """Self-test of the first change after a migration: the merge base has the old .code-standard.json and no state
    file; the same settings and debt pass, a raised cap or an added item fails.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    old = {'config': {'caps': {'max_function_lines': 5, 'max_file_lines': 50}, 'include': ['*']},
           'debt': {'comment': {'a.py::x': 1}}}
    (root / settings.STATE).unlink()
    (root / settings.CHECK).unlink()
    (root / settings.OLD_CODE).write_text(json.dumps(old))
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n')
    commit(g, 'old layout')
    assert main(cs) == 1, 'the old file in the working tree fails the check (run the migration)'
    (root / settings.OLD_CODE).unlink()
    write(root, SMALL, old['debt'])
    config = settings.code_config(root)
    assert cs.against_main(config, old['debt'])[0] == [], 'after a migration the same settings and debt pass'
    assert cs.against_main(config, {'comment': {'a.py::x': 1, 'a.py::y': 1}})[0], 'debt added in a migration fails'
    assert cs.against_main(config_of(root, SMALL.replace(': 5', ': 9')), old['debt'])[0], 'a cap raised in a migration fails'
    write(root, SMALL)


def self_test_forms(cs, root, g, config):
    """Self-test of function forms and comment places: shell `function name {` and a brace on the next line are found;
    a comment after a one-line function, or a file help header, is not that function's comment; a Python `#` line
    before the first statement counts; an arrow with no braces is not a function; bodies that differ only in their
    docstrings are duplicates; a Python parse error fails.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
        config: the settings of the sample repo.
    """
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
    own line, or at the end of the body, counts; a shell comment after a `{` on its own line counts.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
        config: the settings of the sample repo.
    """
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
    baseline once and keeps the other parts of the state file; a second --init is refused, so it cannot add debt.

    Args:
        cs: the check module.
        root: the sample repo folder.
    """
    state = root / settings.STATE
    state.unlink()
    settings.save_part(root, 'timings', {'check': {'seconds': 1.0}})
    assert main(cs) == 1, 'no baseline: the check fails'
    assert main(cs, '--init', '--report') == 0 and cs.load()[1] is None, '--report writes no baseline'
    assert main(cs, '--init') == 0 and cs.load()[1] is not None, '--init writes the first baseline'
    assert settings.load_state(root)['timings'], '--init keeps the other parts of the state file'
    assert main(cs, '--init') == 1, 'a second --init is refused'


class CodeStandardTest(unittest.TestCase):
    """The cases of `python3 scripts/code_standard.py --test`, for `python3 -m unittest` and pytest. They run in order
    in one test: they share one sample repo."""

    def test_self_test(self):
        """Every case passes on the check module; its repo root is put back after the run."""
        import code_standard  # scripts/code_standard.py: imported here, so a plain import of this file loads nothing
        root = code_standard.ROOT
        self.addCleanup(setattr, code_standard, 'ROOT', root)
        self.assertEqual(run(code_standard), 0)

