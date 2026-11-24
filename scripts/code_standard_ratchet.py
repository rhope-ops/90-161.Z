#!/usr/bin/env python3
"""The comparison of the code standard baseline with main: the Maintainer's decision test, the check of the settings and
the debt against the merge base with origin/main, and --adopt (docs/code-standard.md "The ratchet").

Part of scripts/code_standard.py (split out to keep each file under the line cap of docs/code-standard.md C4).
code_standard.py keeps decided_at, against_main and adopt with their old signatures; each passes the check module
itself as `cs`, so the repo root, the gate and the helpers that a self-test sets on that module are the ones in force.
Inputs:  the settings and debt list of the working tree, and those at the merge base (git; scripts/check_settings.py).
Outputs: problem lines and notes; adopt prints its result line.
Usage:   imported by scripts/code_standard.py; it has no command line.
Prevents: code-standard debt rises, or a cap or rule in `.check` changes without the Maintainer's decision, so the ratchet is quietly loosened
Network: none (it runs local git read commands).
Writes: .check.state.json, only through adopt (--adopt).
Credentials: none.
"""
import os

import check_settings as settings   # scripts/check_settings.py: code_base, NAMES_CHECK, CHECK


def decided_at(cs, ref):
    """Return (True when this change records the Maintainer's decision on `.check`, refusal lines). The kit's test: a line
    that docs/DECISIONS.md gained against `ref` names `.check`. A project's own gate replaces the test."""
    if cs.GATE:
        return cs.GATE.decided(cs.ROOT, ref)
    return any(x.startswith('+') and settings.NAMES_CHECK.search(x)
               for x in cs.git('diff', ref, '--', 'docs/DECISIONS.md').stdout.split('\n')), []


def against_main(cs, config, debt):
    """Compare the settings and the debt with those on the merge base with origin/main. An item added to the debt, a
    value raised, or a changed `code-` setting is a problem, unless the same change records the Maintainer's decision
    (decided_at). An opt-in rule turned on or raised above main's level (--adopt) may list its debt with that
    decision. A debt key that a project's gate refuses (new_debt_refusal) is a problem that no decision lifts.

    Args:
        cs: the check module (scripts/code_standard.py): its ROOT, GATE, git(), rules() and level().
        config: the code standard settings of the working tree.
        debt: the debt list of the working tree.

    Returns:
        (problem lines, note).
    """
    mb = cs.git('merge-base', 'HEAD', 'origin/main')
    if mb.returncode != 0:
        if os.environ.get('CI'):
            return ['FAIL  baseline: no merge base with origin/main, so the baseline cannot be compared'], ''
        return [], 'WARN  baseline not compared with main (no origin/main here)'
    ref = mb.stdout.strip()
    try:
        old = settings.code_base(cs.ROOT, ref)
    except ValueError as err:
        return ['FAIL  baseline: the settings or the baseline on the merge base cannot be read (%s)' % err], ''
    if old is None:
        return [], 'NOTE  no baseline on main yet: this change starts it'
    old_config, old_debt = old
    decided, refusals = decided_at(cs, ref)
    # A debt kind that main holds and no rule here knows: the gate that owned it is gone, and its rule with it.
    orphans = sorted(k for k, items in old_debt.items() if items and k not in cs.rules())
    problems = ['FAIL  baseline: main holds %s debt, but no rule here knows that kind (is %s missing?); removing a '
                'rule needs a docs/DECISIONS.md row that names %s' % (k, cs.GATE_FILE.name, settings.CHECK)
                for k in orphans if not decided]
    for kind, items in debt.items():
        adopting = cs.level(kind, config) > cs.level(kind, old_config)
        was = old_debt.get(kind, {})
        for key, value in sorted(items.items()):
            refused = cs.GATE.new_debt_refusal(cs.ROOT, ref, kind, key) if cs.GATE and key not in was else None
            if refused:
                problems.append(refused)
            elif adopting and decided:
                continue   # an opt-in rule turned on or raised now (--adopt): its list is the Maintainer's decision
            elif key not in was:
                problems.append('FAIL  baseline: %s item added by hand: %s' % (kind, key))
            elif value > was[key]:
                problems.append('FAIL  baseline: %s value raised: %s (%d to %d)' % (kind, key, was[key], value))
    if config != old_config and not decided:
        problems.append('FAIL  baseline: a `code-` setting of %s (caps, scope or an opt-in rule) changed with no '
                        'docs/DECISIONS.md row that names %s (a cap or scope change is the Maintainer\'s decision)'
                        % (settings.CHECK, settings.CHECK))
    return problems + (list(refusals) if problems and not decided else []), ''


def adopt(cs, config, debt, now):
    """Write the debt list of each opt-in rule that the settings turn on and the baseline holds no debt for yet, or
    whose level the settings raised above the level on main (a stricter form of a rule that is on); refuse when there
    is none. A core rule is never adopted, and the comparison with main accepts the list only for such a rule, so this
    cannot add debt to a rule the ratchet already holds.

    Args:
        cs: the check module (scripts/code_standard.py): its ROOT, GATE, git(), rules() and level().
        config: the code standard settings.
        debt: the baseline's debt list.
        now: the violations measured now.

    Returns:
        The exit code: 0 written, 1 refused.
    """
    mb = cs.git('merge-base', 'HEAD', 'origin/main')
    try:
        old = settings.code_base(cs.ROOT, mb.stdout.strip()) if mb.returncode == 0 else None
    except ValueError:
        old = None
    main_config = old[0] if old else None   # the settings on the merge base, or None when there are none to read
    raised = lambda k: main_config is not None and cs.level(k, config) > cs.level(k, main_config) >= 1   # on at main, stricter now
    kinds = [k for k in cs.rules() if cs.level(k, config) and now.get(k) and (not debt.get(k) or raised(k))]
    if not kinds:
        print('CODE-STANDARD fail: no opt-in rule to adopt; use --update (it can only lower the baseline)')
        return 1
    cs.save(dict(debt, **{k: now[k] for k in kinds}))
    print('CODE-STANDARD adopted: %s (add a docs/DECISIONS.md row that names %s)' % (
        ', '.join('%s %d' % (k, len(now[k])) for k in kinds), settings.CHECK))
    return 0
