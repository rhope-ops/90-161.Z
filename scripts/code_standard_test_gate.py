#!/usr/bin/env python3
"""Self-test cases of the extension point of scripts/code_standard.py (a project's own gate): a sample gate file is
loaded and called, and a gate that is broken, incomplete or missing for a setting that needs one fails the check;
and the sample repo helpers that every case file of the code standard self-test uses (write, config_of, fails,
commit, main, and the sample settings SMALL and FULL).

Part of scripts/code_standard_test.py (split out to keep each file under the line cap of docs/code-standard.md C4);
its run_cases() calls self_test_gate.
Input: the check module and the sample repo. Output: none; an AssertionError names the rule. Needs git.
Usage:   imported by scripts/code_standard_test.py (run by `python3 scripts/code_standard.py --test`); no command line.
Network: none.
Writes: temporary folders only.
Credentials: none.
"""
import shutil

import check_settings as settings   # scripts/check_settings.py: CHECK, save_part, code_config


PS = bool(shutil.which('pwsh'))   # the PowerShell cases need the real parser
SMALL = 'code-max-function-lines: 5\ncode-max-file-lines: 50\n'   # the caps of the sample repo, as .check lines
FULL = 'code-c2: full\n'                                         # the kit's caps and the opt-in C2 full rule


def write(root, lines, debt=None):
    """Write the sample repo's .check (setting lines) and, when debt is given, its code standard baseline."""
    (root / settings.CHECK).write_text(lines)
    if debt is not None:
        settings.save_part(root, 'code_standard', {'debt': debt})


def config_of(root, lines):
    """Write the sample repo's .check and return the settings the check reads from it."""
    write(root, lines)
    return settings.code_config(root)


# A sample gate for self_test_gate: a line cap, a strict safety form, its own decision test and a refusal for new.py.
SAMPLE_GATE = '''"""Sample gate of the code standard self-test (a project's own gate has this shape)."""
RULES = {'line': ('C4 line longer than %d characters', 'max_line_chars')}
OPT_IN = {'line': lambda c: 1 if c['caps'].get('max_line_chars') else 0}


def file_rules(v, path, lines, head, config, skip):
    """The sample per-file rules: the line cap, and for the strict safety form a header that starts with Network:."""
    cap = config['caps'].get('max_line_chars')
    longest = max(len(x) for x in lines)
    if cap and longest > cap:
        v['line'][path] = longest
    if config.get('c1_safety') == 'strict' and not head.startswith('Network:'):
        v['safety'][path] = 1


def decided(root, ref):
    """The sample decision test: the file OWNER-YES exists."""
    return (root / 'OWNER-YES').exists(), ['REFUSED  sample gate: no OWNER-YES file']


def new_debt_refusal(root, ref, kind, key):
    """The sample refusal: no debt for new.py, whatever was decided."""
    return 'FAIL  sample gate: no debt for new.py' if key.startswith('new.py') else None
'''


def self_test_gate(cs, root, g):
    """Self-test of the extension point: with no gate file a setting that needs one fails; a gate that cannot be
    imported, lacks an entry point or has a wrong shape fails; a good gate adds a debt kind, a per-file rule, its own
    decision test, a refusal no decision lifts, and an opt-in kind for --adopt.

    Args:
        cs: the check module (its GATE_FILE points into an empty temporary folder).
        root: the sample repo folder.
        g: runs git in the sample repo.
    """
    for name in [p.name for p in root.iterdir() if p.name != '.git']:
        g('rm', '-rqf', '--ignore-unmatch', name)
    (root / 'docs').mkdir(exist_ok=True)
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n')
    (root / 'a.py').write_text('"""Sample module of the gate self-test: one long line and nothing else in it."""\nX = "' + 'x' * 120 + '"\n')
    write(root, '', {})
    commit(g, 'gate base')
    assert main(cs) == 0 and cs.GATE is None, 'no gate file and no gate setting: the kit check runs alone'
    for line in ('code-max-line-chars: 100\n', 'code-c1-safety: strict\n'):
        write(root, line)
        assert 'own gate' in fails(cs.load), 'a setting a gate enforces fails with no gate file: ' + line
        assert main(cs) == 1, 'and the check fails: ' + line
    cs.GATE_FILE.parent.mkdir()
    for bad, why in (('import no_such_module_anywhere\n', 'cannot be loaded'), ('def f(:\n', 'cannot be loaded'),
                     ('import sys\nsys.exit(0)\n', 'cannot be loaded'), ('raise SystemExit(1)\n', 'cannot be loaded'),
                     (SAMPLE_GATE.replace('def decided', 'def undecided'), 'lacks decided'),
                     (SAMPLE_GATE.replace("OPT_IN = {'line': lambda c: 1 if c['caps'].get('max_line_chars') else 0}", 'OPT_IN = []'), 'wrong shape'),
                     (SAMPLE_GATE.replace("('C4 line longer than %d characters', 'max_line_chars')", "'C4 line'"), 'wrong shape')):
        cs.GATE_FILE.write_text(bad)
        write(root, '')
        assert why in fails(cs.load), 'a gate that is broken or incomplete fails the load (%s)' % why
        assert main(cs) == 1 and main(cs, '--update') == 1, 'and every run of the check, also with no gate setting (%s)' % why
    cs.GATE_FILE.write_text(SAMPLE_GATE)
    config = config_of(root, 'code-max-line-chars: 100\n')
    assert cs.load()[0] == config and cs.GATE is not None, 'a good gate loads'
    now = cs.measure(config)['violations']
    assert now['line'] == {'a.py': 126}, "the gate's per-file rule writes its own debt kind: %s" % now
    new, _ = cs.compare(now, {}, config['caps'])
    assert new == ['FAIL  C4 line longer than 100 characters: a.py (126)'], "the gate's label and cap are used: %s" % new
    assert cs.compare(now, {'line': {'a.py': 120}}, config['caps'])[0] == ['FAIL  C4 line longer than 100 characters: a.py grew from 120 to 126']
    assert cs.compare({'line': {'a.py': 110}}, {'line': {'a.py': 126}}, config['caps'])[1], 'a gate kind with a cap is a size: smaller is fixed'
    self_test_gate_ratchet(cs, root, config, now)
    strict = config_of(root, 'code-c1-safety: strict\n')
    assert cs.measure(strict)['violations']['safety'] == {'a.py': 1}, 'the gate enforces the strict safety form'
    assert cs.level('safety', strict) == 2 and cs.level('safety', config_of(root, 'code-c1-safety: on\n')) == 1, 'strict is a higher level'
    cs.GATE_FILE.unlink()
    write(root, '', {})
    assert main(cs) == 0 and cs.GATE is None, 'the gate file removed: the kit check runs alone again'


def self_test_gate_ratchet(cs, root, config, now):
    """Self-test of a gate in the comparison with main and in --adopt: the gate's decision test replaces the kit's,
    its refusal lines are printed with a failure, a debt key it refuses fails whatever was decided, and its opt-in
    kind is adopted once.

    Args:
        cs: the check module, with the sample gate loaded.
        root: the sample repo folder (main has no `code-` line and an empty debt list).
        config: the settings with the line cap of the sample gate.
        now: the violations measured with them.
    """
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n| cap | `.check` |\n')   # the kit's test would accept this row
    problems = cs.against_main(config, {})[0]
    assert len(problems) == 2 and 'setting' in problems[0] and problems[1] == 'REFUSED  sample gate: no OWNER-YES file', \
        "the gate's decision test replaces the kit's, and its refusal lines are printed: %s" % problems
    assert 'added by hand' in ' '.join(cs.against_main(config, now)[0]), 'not decided: the new list is refused'
    (root / 'OWNER-YES').write_text('')
    assert cs.against_main(config, {})[0] == [], 'decided by the gate: the setting change passes'
    assert cs.against_main(config, now)[0] == [], "decided, and the gate's opt-in kind is turned on now: its first list passes"
    refused = cs.against_main(config, {'line': {'a.py': 126, 'new.py': 300}})[0]
    assert refused == ['FAIL  sample gate: no debt for new.py'], 'a refused debt key fails whatever was decided: %s' % refused
    assert main(cs, '--adopt') == 0 and cs.load()[1]['line'] == {'a.py': 126}, "--adopt lists the gate's opt-in kind"
    assert main(cs, '--adopt') == 1, 'a second --adopt is refused'
    assert main(cs) == 0, 'the check passes with the adopted list and the decision'
    (root / 'OWNER-YES').unlink()
    # The gate file is removed while main still holds debt of its kind: the rule would go in silence.
    real_base, gate, decisions = cs.settings.code_base, cs.GATE, (root / 'docs' / 'DECISIONS.md')
    kept = decisions.read_text()
    cs.settings.code_base, cs.GATE = (lambda r, ref: ({}, {'line': {'a.py': 126}, 'length': {}})), None
    try:
        decisions.write_text('# Decisions\n')
        gone = cs.against_main({}, {})[0]
        assert len(gone) == 1 and 'main holds line debt, but no rule here knows that kind' in gone[0], \
            'a debt kind of main that no rule knows fails (the gate is gone): %s' % gone
        decisions.write_text('# Decisions\n| the gate is retired | `.check` |\n')
        assert cs.against_main({}, {})[0] == [], "with the Maintainer's row, removing the gate's rule passes"
    finally:
        cs.settings.code_base, cs.GATE = real_base, gate
        decisions.write_text(kept)


def fails(call, *args):
    """Return the message of the ValueError that call(*args) raises, or '' when it raises none."""
    try:
        call(*args)
    except ValueError as err:
        return str(err)
    return ''


def commit(g, message):
    """Commit everything in the sample repo and make that commit origin/main."""
    g('add', '-A')
    g('-c', 'user.email=t@example.invalid', '-c', 'user.name=t', 'commit', '-qm', message)
    g('update-ref', 'refs/remotes/origin/main', 'HEAD')


def main(cs, *args):
    """Run cs.main() with these arguments, its output hidden; return its exit code.

    Args:
        cs: the check module.
        args: the command-line arguments.

    Returns:
        The exit code of cs.main().
    """
    import contextlib
    import io
    import sys
    saved, sys.argv = sys.argv, ['code_standard.py', *args]
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            return cs.main()
    finally:
        sys.argv = saved
