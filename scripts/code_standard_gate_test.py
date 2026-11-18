#!/usr/bin/env python3
"""Self-test of this project's own gate, scripts/code_standard_gate.py (run by
`python3 scripts/code_standard_gate.py --test`; scripts/check.sh runs it). The cases came from this project's copy of
the kit's scripts/code_standard_test.py (the same cases as rhope-ops/RADE) and now run through the kit's check with
the gate loaded, on sample repos in a temporary folder.

It proves: the strict C1 safety form (a label inside prose, in the middle of a line or with no value fails; a label
that starts a header line with a value passes in each language's header form); the owner-row decision test and the
ways a row could open it with no new decision; the line cap (only hand-written lines count, the debt value only goes
down); and, against main, that an owner row opens the gate for a raised safety level or the line cap, that rows by a
script, an agent or another person do not, that debt for a new file is refused whatever was decided, and that
--adopt lists a raised level once.
Input: the gate module. Output: one "pass" line, or an AssertionError naming the rule. Needs git.
Network: none.
Writes: temporary folders only.
Credentials: none.
"""

import contextlib
import io
import tempfile
from pathlib import Path
import subprocess

import check_settings as settings   # scripts/check_settings.py: the reader of .check and .check.state.json
import code_standard as cs           # scripts/code_standard.py: the kit's check that loads the gate
import code_standard_test as kit     # scripts/code_standard_test.py: the kit's sample-repo helpers (write, config_of, commit)

NAME = '.check'   # the settings file a decision row names


def owner_row(text, by='the Administrator'):
    """Return one DECISIONS table row (four cells) whose decision cell is `text` and names `.check`, and whose By cell
    is `by`."""
    return '| 2026-11-17 | %s %s | %s | — |\n' % (text, NAME, by)


def run(gate):
    """Run every case with the gate loaded into the kit's check; the check's repo root and gate are put back after.

    Args:
        gate: the gate module.

    Returns:
        The exit code 0 (an assert stops on a failure).
    """
    saved = cs.ROOT, cs.GATE
    try:
        cs.GATE = gate
        self_test_safety(gate)
        self_test_rows(gate)
        self_test_row_tricks(gate)
        for part in (self_test_lines, self_test_strict_main):
            with tempfile.TemporaryDirectory() as d:
                cs.ROOT = Path(d)
                g = lambda *c: subprocess.run(['git', '-C', d, *c], check=True, capture_output=True)
                g('init', '-q')
                part(gate, cs.ROOT, g)
    finally:
        cs.ROOT, cs.GATE = saved
    print('code_standard_gate self-test: pass')
    return 0


def self_test_safety(gate):
    """C1 safety, strict form: a label inside prose, in the middle of a line or with no value does not pass; a label at
    the start of a header line with a value passes in a PowerShell help block and `#` comments, a Python docstring, JS
    `//` and `*` lines, and shell `#` lines.

    Args:
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


def self_test_rows(gate):
    """The owner-row decision test: a plain line, a row by a script, a row by an agent, a row by another person and a
    row with too few cells are refused (the refusal names the rule); a row that does not name the file is no decision
    for it; an owner's row passes; `.check.lock` and `.check.state.json` are not `.check`; the owner role is read from
    AGENTS.md.

    Args:
        gate: the gate module.
    """
    plus = lambda by: owner_row('cap', by).rstrip('\n')
    ok, why = gate.owner_row('The decision names %s in prose.' % NAME, NAME, 'administrator')
    assert not ok and 'rule 1' in why[0], 'a plain non-table line is refused: %s' % why
    ok, why = gate.owner_row(plus('scripts/bump_lock.py'), NAME, 'administrator')
    assert not ok and 'rule 3' in why[0], 'a row by a script is refused: %s' % why
    ok, why = gate.owner_row(plus("agent, under the Administrator's delegation"), NAME, 'administrator')
    assert not ok and 'rule 3' in why[0], 'a row by an agent is refused: %s' % why
    ok, why = gate.owner_row(plus('someone else'), NAME, 'administrator')
    assert not ok and 'rule 4' in why[0], 'a row by another person is refused: %s' % why
    assert gate.owner_row('| 2026-11-17 | other | the Administrator | - |', NAME, 'administrator') == (False, []), \
        'a row that does not name the file is not a decision for it'
    assert not gate.owner_row('| 2026-11-17 | names %s | the Administrator |' % NAME, NAME, 'administrator')[0], \
        'a row with fewer than four cells is refused'
    assert gate.owner_row(plus('the Administrator'), NAME, 'administrator') == (True, []), 'the owner row passes'
    lock_row = '| 2026-11-17 | relock .check.lock and .check.state.json | the Administrator | - |'
    assert gate.owner_row(lock_row, NAME, 'administrator', '', gate.NAMES_SETTINGS.search) == (False, []), \
        'a row that names only .check.lock or .check.state.json is not a decision on .check'
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / 'AGENTS.md').write_text('# Rules\n- Owner: the PFM\n')
        assert gate.owner_role(d) == 'pfm', 'the owner role is read from AGENTS.md, without "the "'
        assert gate.owner_role(Path(d) / 'none') == '', 'no AGENTS.md: no owner'
    assert gate.owner_role_in('- Owner: Claude\n') == 'claude', 'odd input'


def self_test_row_tricks(gate):
    """The ways a row could open the gate with no new decision (reviews of 17 Nov 26): an old row that is moved,
    re-spaced or edited (a word, a full stop, its date, its letter case, only the file name added, an unseen character,
    cut short); a new owner row beside an old row that the change removes; a spare cell before or after the By cell;
    the owner's name beside another writer, also inside or after a bracket note. Honest forms pass: a new row, an
    indented row, an escaped | in the text, one note in brackets after the owner, a new row in the words of an old one
    that stays. The gate reads no date and compares no text for likeness.

    Args:
        gate: the gate module.
    """
    row = owner_row('the cap of the function length goes from sixty to seventy lines, see').rstrip('\n')
    short = '| 2026-11-10 | The owner is not a tenant admin. | the Administrator | archive |'
    head = '# Decisions\n| Date | Decision | By | Replaces |\n|---|---|---|---|\n'
    old = head + short + '\n' + row + '\n'

    def check(line, old_text='', gone=''):
        """Return owner_row for a file that is `old_text` with `line` added and, when `gone` is given, without that
        old line."""
        return gate.owner_row(line + '\n' + (old_text.replace(gone + '\n', '') if gone else old_text), NAME, 'administrator', old_text)
    for what, line in (('moved', row), ('re-spaced', row.replace('| the cap', '|   the cap'))):
        assert check(line, old, row) == (False, []), 'an old row %s is not a decision' % what
    edits = (('with a full stop added', row, row.replace(', see', '., see')), ('with a word changed', row, row.replace('sixty', 'fifty')),
             ('with its date changed', row, row.replace('2026-11-17', '2031-01-01')), ('in capital letters', row, row.upper().replace(NAME.upper(), NAME)),
             ('with only the file name added', short, short.replace('admin.', 'admin. ' + NAME)),
             ('with an unseen character added', row, row.replace('cap', 'ca​p')), ('cut short', row, row.replace(' goes from sixty to seventy lines', '')))
    for what, was, now in edits:
        ok, why = check(now, old, was)
        assert not ok and 'rule 5' in why[0], 'an old row %s is refused: %s' % (what, why)
    assert check(row.replace('sixty to seventy', 'seventy to eighty').replace('2026-11-17', '2026-12-01'), old)[0], \
        'a new row in the words of an old one passes when the old row stays'
    ok, why = check(owner_row('new opt-in rule for line length, cap 200, adopted in').rstrip('\n'), old, short)
    assert not ok and 'rule 5' in why[0], 'a new owner row beside a removed old row is refused: %s' % why
    assert check(owner_row('new opt-in rule for line length, cap 200, adopted in').rstrip('\n'), old)[0], 'a new row passes'
    forged = row.replace('sixty', 'fifty') + '\n' + short + '\r' + row   # a lone CR hides the old row from a tool that splits on it
    ok, why = gate.owner_row(head + forged + '\n', NAME, 'administrator', old)
    assert not ok and 'rule 5' in why[0], 'an old row edited in place with a carriage-return trick is refused: %s' % why
    for line in ('| 2026-11-17 | raise the cap in %s (`a | b`) | agent, for the owner | - |' % NAME,
                 '| 2026-11-17 | raise the cap in %s | Agent | the Administrator | - |' % NAME,
                 '| 2026-11-17 | raise the cap in %s | the Administrator | - | x |' % NAME):
        ok, why = check(line)
        assert not ok and 'rule 1' in why[0], 'a row with a spare cell is refused: %s' % why
    for by in ('Claude, for the Administrator', 'not the Administrator', 'the Administrator (2A); Claude (drafted it)',
               'the Administrator (not asked; written by Claude) and others'):
        ok, why = check(owner_row('cap', by).rstrip('\n'))
        assert not ok and 'rule 4' in why[0], 'the owner beside another writer is refused (%s): %s' % (by, why)
    assert check('  ' + row)[0], 'an indented owner row passes'
    assert check('| 2026-11-17 | a \\| b in %s | the Administrator (answer 2A) | - |' % NAME)[0], 'an escaped | and a note pass'


def self_test_lines(gate, root, g):
    """The line cap (`code-max-line-chars`): a line over the cap fails with its length; with no cap the rule is off; a
    debt value may go down but not up; a generated file and a generated block are skipped.

    Args:
        gate: the gate module.
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    head = '"""Sample module for the line-cap self-test: it shows how the longest line is measured."""\n'
    config = kit.config_of(root, 'code-max-line-chars: 200\ncode-generated: gen.py\n')
    (root / 'long.py').write_text(head + 'x = "%s"\n' % ('a' * 250))
    (root / 'short.py').write_text(head + 'x = 1\n')
    (root / 'gen.py').write_text('# GENERATED from src/x.py by build.py\nx = "%s"\n' % ('a' * 250))
    (root / 'blk.py').write_text(head + '# >>> s: generated from src/s.py by b.py\nx = "%s"\n# <<< s\n' % ('a' * 250))
    g('add', '.')
    now = cs.measure(config)['violations']['line']
    assert now == {'long.py': 256}, 'only the hand-written file over the cap fails, with its length: %s' % now
    off = kit.config_of(root, 'code-generated: gen.py\n')
    assert cs.measure(off)['violations']['line'] == {}, 'settings with no cap measure nothing'
    caps = config['caps']
    new, fixed = cs.compare({'line': {'long.py': 256}}, {'line': {'long.py': 256}}, caps)
    assert not new and not fixed, 'a debt value that is the same passes'
    new, _ = cs.compare({'line': {'long.py': 300}}, {'line': {'long.py': 256}}, caps)
    assert len(new) == 1 and 'grew from 256 to 300' in new[0], 'a debt value may not go up: %s' % new
    new, fixed = cs.compare({'line': {'long.py': 210}}, {'line': {'long.py': 256}}, caps)
    assert not new and len(fixed) == 1, 'a debt value that went down is reported as fixed: %s' % fixed


def self_test_strict_main(gate, root, g):
    """The ratchet against main with the gate's decision test: an owner row opens it for a raised safety level; a row
    by a script or an agent, a plain line or a row that does not name the file does not, and the refusal names the
    rule; debt for a file that is new in the change is refused even with an owner row; the line cap adopts with an
    owner row; --adopt lists a raised level once and is refused at main's level.

    Args:
        gate: the gate module.
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    (root / 'AGENTS.md').write_text('- Owner: the Administrator\n')
    (root / 'docs').mkdir()
    old_row = '| 2026-11-01 | The owner is not a tenant admin. | the Administrator | - |\n'
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n' + old_row)
    for f in ('a.py', 'b.py'):
        (root / f).write_text('x = 1\n')
    kit.write(root, 'code-c1-safety: on\n', {'safety': {'a.py': 1}})
    kit.commit(g, 'base')
    strict = kit.config_of(root, 'code-c1-safety: strict\n')   # a raised level: the strict form of a rule that is on
    both = {'safety': {'a.py': 1, 'b.py': 1}}

    def problems(config, debt, decisions, keep=old_row):
        """Return the problem lines of against_main, joined; the DECISIONS file gets `decisions` and then `keep`
        (main's old row as it was, unless a case changes it)."""
        (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n' + decisions + keep)
        return ' | '.join(cs.against_main(config, debt)[0])
    strict_text = 'the stricter form of the safety lines is adopted now and files that newly fail are listed once in'
    assert not problems(strict, both, owner_row(strict_text)), 'an owner row opens the gate for a raised level'
    assert 'added by hand' in problems(strict, both, 'no row\n'), 'no row: new debt fails'
    edited = old_row.replace('admin.', 'admin. ' + NAME)
    assert 'rule 5' in problems(strict, both, '', edited), "main's old row with the file name added does not open the gate"
    assert 'rule 5' in problems(strict, both, owner_row(strict_text), ''), 'a new row beside a removed old row does not either'
    for by, rule in (('scripts/x.py', 'rule 3'), ("agent, under the Administrator's delegation", 'rule 3'),
                     ('someone else', 'rule 4')):
        assert rule in problems(strict, both, owner_row(strict_text, by)), 'a row by %r is refused by %s' % (by, rule)
    assert 'rule 1' in problems(strict, both, 'Level changes %s.\n' % NAME), 'a plain line is refused'
    (root / 'AGENTS.md').write_text('- Owner: Claude\n')   # the owner line changed in the same change: main's owner still counts
    assert 'rule 4' in problems(strict, both, owner_row(strict_text, 'Claude')), 'a new owner named in this change cannot decide'
    (root / 'AGENTS.md').write_text('- Owner: the Administrator\n')
    assert 'setting' in problems(strict, both, '| 2026-11-17 | other | the Administrator | - |\n'), 'a row for another thing'
    new_file = {'safety': {'a.py': 1, 'new.py': 1}}
    assert 'new files meet the rules' in problems(strict, new_file, owner_row(strict_text)), 'debt for a new file is refused'
    on = kit.config_of(root, 'code-c1-safety: on\ncode-max-line-chars: 200\n')
    debt = {'safety': {'a.py': 1}, 'line': {'a.py': 300}}
    assert not problems(on, debt, owner_row('a new opt-in rule, the longest line of a file, is turned on with a cap of 200 characters in')), \
        'the line cap adopts with an owner row'
    assert problems(on, debt, 'no row\n'), 'the line cap needs a row'
    with contextlib.redirect_stdout(io.StringIO()):
        assert cs.adopt(strict, {'safety': {'a.py': 1}}, both) == 0, '--adopt lists debt of a raised level'
        assert set(settings.load_state(root)['code_standard']['debt']['safety']) == {'a.py', 'b.py'}, '--adopt writes it'
        same = kit.config_of(root, 'code-c1-safety: on\n')
        assert cs.adopt(same, {'safety': {'a.py': 1}}, both) == 1, 'the same level as main: --adopt is refused'
