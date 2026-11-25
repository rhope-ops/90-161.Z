#!/usr/bin/env python3
"""Self-test of the kit's strict code-standard rules, scripts/code_standard_strict.py (run by
`python3 scripts/code_standard_strict.py --test` and by `python3 -m unittest`; scripts/check.sh runs it). It runs the
kit check scripts/code_standard.py with the strict rules loaded, on sample repos in a temporary folder, and proves:
the safety labels at a line start with a value, the Maintainer-row gate (and the tricks that must not open it), debt for a
new file, the line cap, --adopt of a raised safety level, and that `code-strict-gate: on` loads the rules (and a
project's own gate file wins). The Maintainer is read from the sample AGENTS.md; the sample owner is an invented role.

Input: none. Output: unittest results; exit code 0 or 1.
Network: none.
Writes: temporary folders only.
Credentials: none.
Run:     python3 scripts/code_standard_strict.py --test (Python 3.8+, git).
"""

import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_settings as settings   # noqa: E402 - scripts/check_settings.py: the reader of .check and .check.state.json
import code_standard as cs   # noqa: E402 - the kit check (scripts/code_standard.py)
import code_standard_rules as rules   # noqa: E402 - LINTERS, set both ways in check_lines
import code_standard_strict as gate   # noqa: E402 - ruff_ok, the lines ruff E501 lets pass
from code_standard_test_gate import SAMPLE_GATE, commit, config_of, write   # noqa: E402 - the kit's sample-repo helpers

STRICT_FILE = Path(__file__).resolve().parent / 'code_standard_strict.py'


A45 = 'a' * 45
# Whole files, as ruff 0.17.6 sees them at a cap of 40 (2026-11-25): True = over the cap (check_lines).
RUFF_CASES = (('x = "# noqa %s"' % A45, True), ("x = '''\n%s # noqa\n'''" % A45, True), ('x = "%s"' % ('\u65e5' * 22), True),
              ('if x:\n\ty = "%s"' % ('a' * 33), True), ('x = "%s"' % ('e\u0301' * 20), False),
              ('x = 1  # type: int  # %s' % A45, False), ('x = "%s"  # noqa' % A45, False),
              ('x = "%s\u2705\ufe0f"' % ('a' * 32), False), ('x = 1  # flake8: %s' % A45, False),
              ('x = 1  # mypy: %s' % A45, True), ('x = """\n%s\n"""  # noqa: E501' % ('a b ' * 12), False),
              ('# ruff: noqa\nx = "%s"' % A45, False), ('# SPDX-License-Identifier: %s' % ('a b ' * 12), False),
              ("x = ('''\n%s\n''', '''\n%s\n''')  # noqa" % (('w ' * 25,) * 2), False),
              ('# note # ruff: noqa\nx = "%s"' % A45, False), (' ' * 60, False),
              ('x = "%s\u3164"' % ('a' * 33), False), ('#  SPDX-License-Identifier: %s' % ('a b ' * 12), False),
              ('# ruff : noqa\nx = "%s"' % A45, False), ('x = "abc\u0301\t%s"' % ('a' * 28), False),
              ('x = "\t\t%s"' % ('a' * 28), True))


def row_text(text, by='the Keeper'):
    """Return one DECISIONS table row (four cells) whose decision cell is `text` and names the settings file, and whose
    By cell is `by`."""
    return '| 2026-11-17 | %s %s | %s | — |\n' % (text, settings.CHECK, by)


def check_safety(cs, gate):
    """Self-test of C1 safety: a label inside prose, in the middle of a line or with no value does not pass; a label at
    the start of a header line with a value passes in a PowerShell help block and `#` comments, a Python docstring, JS
    `//` and `*` lines, and shell `#` lines.

    Args:
        cs: the check module.
        gate: the gate module.
    """
    lab = ['Network: none.', 'Writes: none.', 'Credentials: none.']
    what = 'Sample file: what it is for, long enough to be a header of the sample.'
    prose = 'Sample file. It has Network: none, Writes: none and Credentials: none, all in one sentence of prose.'
    assert not gate.safety_ok(prose), 'a label inside prose does not pass'
    assert not gate.safety_ok('\n'.join([what, 'Network:', lab[1], lab[2]])), 'a label with no value does not pass'
    assert not gate.safety_ok('\n'.join([what, 'Network: none. Writes: none. Credentials: none.'])), \
        'a label in the middle of a line does not pass'
    forms = {'powershell': ['<#', what] + lab + ['#>'],
             'python': ['"""' + what] + lab + ['"""', ''],
             'js': ['// ' + what] + ['// ' + x for x in lab],
             'shell': ['#!/bin/sh', '# ' + what] + ['# ' + x for x in lab],
             'powershell#': ['# ' + what] + ['#   ' + x for x in lab],
             'js*': ['/*', ' * ' + what] + [' * ' + x for x in lab] + [' */']}
    for name, lines in forms.items():
        head = cs.parse.header_block(lines, name.rstrip('#*'))[0]
        assert gate.safety_ok(head), 'a label at the start of a header line passes (%s): %r' % (name, head)


def check_rows(gate):
    """Self-test of the Maintainer-row gate on diff text: a plain line, a row by a script, a row by an agent, a row by
    another person and a row with too few cells are refused (the refusal names the rule); a row that does not name the
    file is no decision for it; an owner's row passes; the Maintainer role is read from AGENTS.md.

    Args:
        gate: the gate module.
    """
    name = settings.CHECK
    plus = lambda by: row_text('cap', by).rstrip('\n')
    ok, why = gate.owner_row('The decision names %s in prose.' % name, name, 'keeper')
    assert not ok and 'rule 1' in why[0], 'a plain non-table line is refused: %s' % why
    ok, why = gate.owner_row(plus('scripts/bump_lock.py'), name, 'keeper')
    assert not ok and 'rule 3' in why[0], 'a row by a script is refused: %s' % why
    ok, why = gate.owner_row(plus("agent, under the Keeper's delegation"), name, 'keeper')
    assert not ok and 'rule 3' in why[0], 'a row by an agent is refused: %s' % why
    ok, why = gate.owner_row(plus('someone else'), name, 'keeper')
    assert not ok and 'rule 4' in why[0], 'a row by another person is refused: %s' % why
    assert gate.owner_row('| 2026-11-17 | other | the Keeper | - |', name, 'keeper') == (False, []), \
        'a row that does not name the file is not a decision for it'
    assert not gate.owner_row('| 2026-11-17 | names %s | the Keeper |' % name, name, 'keeper')[0], \
        'a row with fewer than four cells is refused'
    assert gate.owner_row(plus('the Keeper'), name, 'keeper') == (True, []), 'the Keeper row passes'
    exact = settings.NAMES_CHECK.search   # the test the check uses: `.check` itself, not .check.lock or .check.state.json
    assert gate.owner_row(plus('the Keeper'), name, 'keeper', '', exact) == (True, []), 'it passes the exact test'
    assert gate.owner_row(plus('the Keeper').replace(name, settings.STATE), name, 'keeper', '', exact) == (False, []), \
        'a row that names only the state file is not a decision for the settings'
    check_row_tricks(gate, name)
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / 'AGENTS.md').write_text('# Rules\n- Owner: the Keeper\n')
        assert gate.owner_role(d) == 'keeper', 'the Keeper role is read from AGENTS.md, without "the "'
        assert gate.owner_role(Path(d) / 'none') == '', 'no AGENTS.md: no owner'


def check_row_tricks(gate, name):
    """Self-test of the ways a row could open the gate with no new decision (reviews of 17 Nov 26): an old row that is
    moved, re-spaced or edited (a word, a full stop, its date, its letter case, only the file name added, an unseen
    character, cut short); a new owner row beside an old row that the change removes; a spare cell before or after the By
    cell; the Maintainer's name beside another writer, also inside or after a bracket note. Honest forms pass: a new row,
    an indented row, an escaped | in the text, one note in brackets after the Maintainer, a new
    row in the words of an old one that stays. The gate reads no date and compares no text for likeness.

    Args:
        gate: the gate module.
        name: the settings file name.
    """
    row = row_text('the cap of the function length goes from sixty to seventy lines, see').rstrip('\n')
    short = '| 2026-11-10 | The Keeper is not a tenant admin. | the Keeper | archive |'
    head = '# Decisions\n| Date | Decision | By | Replaces |\n|---|---|---|---|\n'
    old = head + short + '\n' + row + '\n'

    def check(line, old_text='', gone=''):
        """Return owner_row for a file that is `old_text` with `line` added and, when `gone` is given, without that
        old line."""
        return gate.owner_row(line + '\n' + (old_text.replace(gone + '\n', '') if gone else old_text), name, 'keeper', old_text)
    for what, line in (('moved', row), ('re-spaced', row.replace('| the cap', '|   the cap'))):
        assert check(line, old, row) == (False, []), 'an old row %s is not a decision' % what
    edits = (('with a full stop added', row, row.replace(', see', '., see')), ('with a word changed', row, row.replace('sixty', 'fifty')),
             ('with its date changed', row, row.replace('2026-11-17', '2031-01-01')), ('in capital letters', row, row.upper().replace(name.upper(), name)),
             ('with only the file name added', short, short.replace('admin.', 'admin. ' + name)),
             ('with an unseen character added', row, row.replace('cap', 'ca\u200bp')), ('cut short', row, row.replace(' goes from sixty to seventy lines', '')))
    for what, was, now in edits:
        ok, why = check(now, old, was)
        assert not ok and 'rule 5' in why[0], 'an old row %s is refused: %s' % (what, why)
    assert check(row.replace('sixty to seventy', 'seventy to eighty').replace('2026-11-17', '2026-12-01'), old)[0], \
        'a new row in the words of an old one passes when the old row stays'
    ok, why = check(row_text('new opt-in rule for line length, cap 200, adopted in').rstrip('\n'), old, short)
    assert not ok and 'rule 5' in why[0], 'a new owner row beside a removed old row is refused: %s' % why
    assert check(row_text('new opt-in rule for line length, cap 200, adopted in').rstrip('\n'), old)[0], 'a new row passes'
    forged = row.replace('sixty', 'fifty') + '\n' + short + '\r' + row   # a lone CR hides the old row from a tool that splits on it
    ok, why = gate.owner_row(head + forged + '\n', name, 'keeper', old)
    assert not ok and 'rule 5' in why[0], 'an old row edited in place with a carriage-return trick is refused: %s' % why
    assert gate.owner_role_in('- Owner: Claude\n') == 'claude', 'odd input'
    for line in ('| 2026-11-17 | raise the cap in %s (`a | b`) | agent, for the Keeper | - |' % name,
                 '| 2026-11-17 | raise the cap in %s | Agent | the Keeper | - |' % name,
                 '| 2026-11-17 | raise the cap in %s | the Keeper | - | x |' % name):
        ok, why = check(line)
        assert not ok and 'rule 1' in why[0], 'a row with a spare cell is refused: %s' % why
    for by in ('Claude, for the Keeper', 'not the Keeper', 'the Keeper (2A); Claude (drafted it)',
               'the Keeper (not asked; written by Claude) and others'):
        ok, why = check(row_text('cap', by).rstrip('\n'))
        assert not ok and 'rule 4' in why[0], 'the Keeper beside another writer is refused (%s): %s' % (by, why)
    assert check('  ' + row)[0], 'an indented owner row passes'
    assert check('| 2026-11-17 | a \\| b in %s | the Keeper (answer 2A) | - |' % name)[0], 'an escaped | and a note pass'


def check_lines(cs, root, g):
    """Self-test of the line cap (caps.max_line_chars): a line over the cap fails with its length; with no cap the
    rule is off; a debt value may go down but not up; a generated file and a generated block are skipped.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    head = '"""Sample module for the line-cap self-test: it shows how the longest line is measured."""\n'
    caps = {'max_function_lines': 60, 'max_file_lines': 600, 'max_line_chars': 200}
    config = {'caps': caps, 'include': ['*'], 'exclude': [], 'generated': ['gen.py']}
    (root / 'long.py').write_text(head + 'x = "%s"\n' % ('a' * 250))   # Python lines are for ruff and pylint (scripts/check.sh)
    (root / 'long.sh').write_text('# Sample shell file for the line-cap self-test.\nx = "%s"\n' % ('a' * 250))
    (root / 'short.py').write_text(head + 'x = 1\n')
    (root / 'gen.py').write_text('# GENERATED from src/x.py by build.py\nx = "%s"\n' % ('a' * 250))
    (root / 'blk.py').write_text(head + '# >>> s: generated from src/s.py by b.py\nx = "%s"\n# <<< s\n' % ('a' * 250))
    (root / 'blk2.py').write_text(head + '# >>> s: generated from src/s.py by b.py\nx = 1\n# <<< s\nx = "%s"\n' % ('a' * 250))
    g('add', '.')
    linters = rules.LINTERS
    try:
        rules.LINTERS = True
        now = cs.measure(config)['violations']['line']
        assert now == {'long.sh': 256, 'blk2.py': 256}, 'a non-Python file, and a .py with a generated block (the linters skip it), fail on hand-written lines: %s' % now
        rules.LINTERS = False
        now = cs.measure(config)['violations']['line']
        assert now == {'long.py': 256, 'long.sh': 256, 'blk2.py': 256}, 'without ruff and pylint a long .py line is measured here: %s' % now
        ok = [('x = "%s"  # noqa: E501' % ('a b ' * 70), True), ('x = "%s"  # noqa: F401' % ('a b ' * 70), False),
              ('# see https://x.org/' + 'a' * 240, True), ('# ' + 'word ' * 45 + 'https://x.org/' + 'a' * 30, False),
              ('#' + 'a' * 250, True), ('x = "%s"' % ('a b ' * 85), False),
              ('x = "%s"  # type: ignore' % ('a b ' * 48), True), ('x = "%s"  # NOQA' % ('a b ' * 70), True),
              ('x = "%s"  # type: ignore  # noqa: F401' % ('a b ' * 48), True)]
        for line, want in ok:   # the lines that ruff E501 lets pass (checked against ruff 0.17.6, 2026-11-24)
            assert gate.ruff_ok(line, 200) == want, 'ruff_ok(%r...) should be %s' % (line[:30], want)
        start = time.monotonic()   # no backtracking blow-up; about 0.3 s, 10 s leaves room for a busy machine
        gate.ruff_ok('x = 1  ' + '# type: a ' * 1000 + '# end', 200)
        assert time.monotonic() - start < 10, 'ruff_ok is slow on a run of pragma comments (the old regex took over 120 s)'
        start = time.monotonic()   # each end line's noqa is read once: about 0.1 s (2.7 s when read again for each line)
        gate.longest_line(('x = """\n' + 'a b\n' * 20000 + '"""  # ' + 'x' * 20000 + ' noqa').split('\n'), [], 40)
        assert time.monotonic() - start < 10, 'longest_line is slow on a long multi-line string with a long noqa comment'
        for text, want in RUFF_CASES:
            assert (gate.longest_line(text.split('\n'), [], 40) > 40) == want, 'longest_line(%r...) over the cap: %s' % (text[:20], want)
    finally:
        rules.LINTERS = linters
    off = dict(config, caps={k: v for k, v in caps.items() if k != 'max_line_chars'})
    assert cs.measure(off)['violations']['line'] == {}, 'a config with no cap measures nothing'
    assert config_of(root, 'code-max-line-chars: 200\n')['caps'] == dict(settings.CODE_DEFAULTS['caps'], max_line_chars=200), 'the cap is read from its .check line'
    assert 'max_line_chars' not in config_of(root, '')['caps'], 'no line: the rule is off'
    (root / settings.CHECK).unlink()
    new, fixed = cs.compare({'line': {'long.py': 256}}, {'line': {'long.py': 256}}, caps)
    assert not new and not fixed, 'a debt value that is the same passes'
    new, _ = cs.compare({'line': {'long.py': 300}}, {'line': {'long.py': 256}}, caps)
    assert len(new) == 1 and 'grew from 256 to 300' in new[0], 'a debt value may not go up: %s' % new
    new, fixed = cs.compare({'line': {'long.py': 210}}, {'line': {'long.py': 256}}, caps)
    assert not new and len(fixed) == 1, 'a debt value that went down is reported as fixed: %s' % fixed


def check_strict_main(cs, root, g):
    """Self-test of the ratchet gate against main: an owner row opens it; a row by a script or an agent, a plain line
    or a row that does not name the file does not, and the refusal names the rule; debt for a file that is new in the
    change is refused even with an owner row; a raised safety level may list new debt (--adopt), and --adopt at the
    same level as main is refused.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    import contextlib
    import io
    (root / 'AGENTS.md').write_text('- Owner: the Keeper\n')
    (root / 'docs').mkdir()
    old_row = '| 2026-11-01 | The Keeper is not a tenant admin. | the Keeper | - |\n'
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n' + old_row)
    for f in ('a.py', 'b.py'):
        (root / f).write_text('x = 1\n')
    write(root, 'code-c1-safety: on\n', {'safety': {'a.py': 1}})
    cfg = settings.code_config(root)
    commit(g, 'base')
    strict = dict(cfg, c1_safety=settings.STRICT)   # a raised level: the stricter form of a rule that is already on
    both = {'safety': {'a.py': 1, 'b.py': 1}}

    def problems(config, debt, decisions, keep=old_row):
        """Return the problem lines of against_main for this baseline, joined; the DECISIONS file gets `decisions` and
        then `keep` (main's old row as it was, unless a case changes it)."""
        (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n' + decisions + keep)
        return ' | '.join(cs.against_main(config, debt)[0])
    strict_text = 'the stricter form of the safety lines is adopted now and files that newly fail are listed once in'
    assert not problems(strict, both, row_text(strict_text)), 'an owner row opens the gate for a raised level'
    assert 'added by hand' in problems(strict, both, 'no row\n'), 'no row: new debt fails'
    edited = old_row.replace('admin.', 'admin. ' + settings.CHECK)
    assert 'rule 5' in problems(strict, both, '', edited), 'main\'s old row with the file name added does not open the gate'
    assert 'rule 5' in problems(strict, both, row_text(strict_text), ''), 'a new row beside a removed old row does not either'
    for by, rule in (('scripts/x.py', 'rule 3'), ("agent, under the Keeper's delegation", 'rule 3'),
                     ('someone else', 'rule 4')):
        assert rule in problems(strict, both, row_text(strict_text, by)), 'a row by %r is refused by %s' % (by, rule)
    assert 'rule 1' in problems(strict, both, 'Level changes %s.\n' % settings.CHECK), 'a plain line is refused'
    (root / 'AGENTS.md').write_text('- Owner: Claude\n')   # the Keeper line changed in the same change: main's owner still counts
    assert 'rule 4' in problems(strict, both, row_text(strict_text, 'Claude')), 'a new owner named in this change cannot decide'
    (root / 'AGENTS.md').write_text('- Owner: the Keeper\n')
    assert 'setting' in problems(strict, both, '| 2026-11-17 | other | the Keeper | - |\n'), 'a row for another thing'
    new_file = {'safety': {'a.py': 1, 'new.py': 1}}
    assert 'new files meet the rules' in problems(strict, new_file, row_text(strict_text)), 'debt for a new file is refused'
    on = dict(cfg, caps=dict(cfg['caps'], max_line_chars=200))
    debt = {'safety': {'a.py': 1}, 'line': {'a.py': 300}}
    assert not problems(on, debt, row_text('a new opt-in rule, the longest line of a file, is turned on with a cap of 200 characters in')), 'the line cap adopts with an owner row'
    assert problems(on, debt, 'no row\n'), 'the line cap needs a row'
    with contextlib.redirect_stdout(io.StringIO()):
        assert cs.adopt(strict, {'safety': {'a.py': 1}}, both) == 0, '--adopt lists debt of a raised level'
        assert set(cs.load()[1]['safety']) == {'a.py', 'b.py'}, '--adopt writes it'
        write(root, 'code-c1-safety: on\n', {'safety': {'a.py': 1}})
        assert cs.adopt(cfg, {'safety': {'a.py': 1}}, both) == 1, 'the same level as main: --adopt is refused'


def sample_repo(d):
    """Return a runner of git commands in a new sample repo at folder `d`."""
    g = lambda *c: subprocess.run(['git', '-C', d, *c], check=True, capture_output=True)
    g('init', '-q')
    return g


class StrictGateTest(unittest.TestCase):
    """The cases of the strict rules; each one loads the gate file into the kit check and puts the check's state back."""

    def setUp(self):
        """Load the strict rules as the check's gate; remember the check's repo root and gate."""
        self.saved = cs.ROOT, cs.GATE
        self.gate = cs.GATE = cs.load_gate(STRICT_FILE)
        self.assertIsNotNone(self.gate, 'the strict file loads')
        self.addCleanup(self.restore)

    def restore(self):
        """Put the check's repo root and gate back."""
        cs.ROOT, cs.GATE = self.saved

    def in_repo(self, case):
        """Run `case(cs, root, g)` in a fresh sample repo; the gate is set again after it."""
        with tempfile.TemporaryDirectory() as d:
            cs.ROOT = Path(d)
            case(cs, cs.ROOT, sample_repo(d))
            cs.GATE = self.gate

    def test_safety_form(self):
        """A label inside prose, mid-line or with no value fails; a label at a header line start passes."""
        check_safety(cs, self.gate)

    def test_owner_rows(self):
        """Only a new row with the Maintainer alone in its By cell passes; the refusals name their rule."""
        check_rows(self.gate)

    def test_line_cap(self):
        """The line cap measures hand-written lines; the debt value may go down, not up."""
        self.in_repo(check_lines)

    def test_against_main(self):
        """The ratchet against main: an owner row opens it, new-file debt is refused, --adopt of a raised level."""
        self.in_repo(check_strict_main)

    def test_key_loads_the_rules(self):
        """`code-strict-gate: on` loads these rules when the project has no gate file; no key loads nothing; a project's
        own gate file wins; a setting that needs a gate (`code-max-line-chars`) then passes."""
        self.in_repo(check_key)


def check_key(cs, root, g):
    """Prove that the key `code-strict-gate` loads the strict rules into cs.load() and nothing else does.

    Args:
        cs: the check module.
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    own = cs.GATE_FILE
    cs.GATE_FILE = root / 'scripts' / 'own_gate.py'   # the project's own gate: absent first
    try:
        write(root, 'code-strict-gate: on\ncode-max-line-chars: 200\ncode-c1-safety: strict\n')
        cfg, _ = cs.load()
        assert cs.GATE is not None and cs.GATE.__file__ == str(STRICT_FILE), 'the key loads the strict rules'
        assert cfg['strict_gate'] is True, 'the setting is read'
        write(root, 'code-strict-gate: off\n')
        cs.load()
        assert cs.GATE is None, 'off loads nothing'
        write(root, 'code-max-line-chars: 200\n')
        try:
            cs.load()
            raise AssertionError('a line cap with no gate and no key fails')
        except ValueError as err:
            assert 'gate' in str(err), err
        write(root, 'code-strict-gate: maybe\n')
        try:
            cs.load()
            raise AssertionError('an invalid value fails')
        except ValueError:
            pass
        (root / 'scripts').mkdir()
        cs.GATE_FILE.write_text(SAMPLE_GATE)
        write(root, 'code-strict-gate: on\n')
        cs.load()
        assert cs.GATE.__file__ == str(cs.GATE_FILE), 'a project gate file wins over the key'
    finally:
        cs.GATE_FILE = own


if __name__ == '__main__':
    unittest.main()
