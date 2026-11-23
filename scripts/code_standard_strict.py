#!/usr/bin/env python3
"""The kit's strict code-standard rules, an opt-in part of scripts/code_standard.py: a project turns them on with the
line `code-strict-gate: on` in its `.check` (docs/code-standard.md "The strict gate"). The check then loads this file as
its gate (the extension point: the header of scripts/code_standard.py gives the five entry points). A project's own
scripts/code_standard_gate.py, when it exists, is loaded instead and this file stays unused.

Why: a rule that can be met with a word somewhere in a header, or with any line that names the settings file, is met by
accident, not by work. Three projects ran the same gate in a copy of their own; this file is that one rule set (the
owner, 2026-11-23: docs/reviews/2026-11-23-fleet-v2-plan.md, items B.4 and 1.4). The rules:
  RULES             'safety' relabelled (each label at a line start, with a value); 'line' (C4 line, cap
                    `code-max-line-chars` in .check; its debt value is a length that may only go down)
  OPT_IN            'line': on when .check sets `code-max-line-chars` (the kit holds the safety levels: off, on, strict)
  file_rules        the strict C1 safety form (safety_ok; at `on` and at `strict`) and the longest line of a file
  decided           the Maintainer row: a NEW docs/DECISIONS.md table row that names the settings file `.check`, with
                    main's owner alone in its By cell (the "- Owner:" line of AGENTS.md on the merge base), in a change
                    that leaves every older row as it was (owner_row)
  new_debt_refusal  debt for a file that is new in this change is refused, with or without a decision (new files
                    meet the rules)
Inputs:  header text, file lines, DECISIONS.md and AGENTS.md at a git ref and in the working tree, a repo root.
Outputs: yes/no answers, refusal lines, and violations written into the caller's dict; with --test, the self-test
         result (scripts/code_standard_strict_test.py) and exit code 0 or 1.
Network: none.
Writes: none (it runs git read-only commands; the check that loads it writes .check.state.json; --test writes
        temporary folders only).
Credentials: none.
Run:     loaded by scripts/code_standard.py; `python3 scripts/code_standard_strict.py --test` is the self-test
         (scripts/check.sh runs it).
"""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))   # the check loads this file by path, not by import
import check_settings as settings   # noqa: E402 - scripts/check_settings.py: the settings file name and its name test

SAFETY_LABELS = ('Network:', 'Writes:', 'Credentials:')   # C1 safety: what a reviewer must find before a run
# A By cell with one of these marks a script or an agent, not the Maintainer (the Maintainer, 2026-11-17: only the Maintainer decides).
NOT_OWNER = ('scripts/', '.py', 'agent', 'delegation')
ROW_CELLS = 4              # a DECISIONS row: date, decision, by, last (exactly: a spare cell would move the By cell)
# The two texts in which the three project gates differ (docs/code-standard.md "The strict gate": the open choice).
SAFETY_LABEL = 'C1 safety: header without the Network:, Writes: and Credentials: lines, each with a value'
NEW_DEBT_FORMAT = 'FAIL  baseline: debt for a file that is new in this change: %s (%s; new files meet the rules)'   # key, kind
RULES = {'safety': (SAFETY_LABEL, None), 'line': ('C4 line longer than %d characters', 'max_line_chars')}
OPT_IN = {'line': lambda c: 1 if c.get('caps', {}).get('max_line_chars') else 0}


def safety_ok(head):
    """C1 safety: each label starts a line of the header (after comment characters and spaces) and has a value.

    Args:
        head: the header text, one header line per text line.

    Returns:
        True when Network:, Writes: and Credentials: each start a line and are followed by a value on it.
    """
    lines = head.split('\n')
    return all(any(re.match(r'^[\s#/*]*' + re.escape(x) + r'\s*\S', line) for line in lines) for x in SAFETY_LABELS)


def longest_line(lines, skip):
    """Return the length in characters of the longest line outside the generated blocks `skip` (1-based first, last)."""
    return max([len(x.rstrip('\r')) for i, x in enumerate(lines, 1) if not any(a <= i <= b for a, b in skip)] or [0])


def file_rules(v, p, lines, head, config, skip):
    """Write RADE's per-file violations of one source file into `v`, after the kit's own per-file rules: the strict
    C1 safety form (each label at the start of a header line, with a value) and the longest line (C4 line).

    Args:
        v: the violations dict {kind: {key: value}}, changed in place.
        p: the repo-relative path.
        lines: the file's lines.
        head: the header text (one header line per text line).
        config: the code standard settings.
        skip: the (first, last) line numbers of the generated blocks.

    Returns:
        None.
    """
    if config.get('c1_safety') and not safety_ok(head):
        v['safety'][p] = 1
    cap = config['caps'].get('max_line_chars')
    longest = longest_line(lines, skip) if cap else 0
    if cap and longest > cap:
        v['line'][p] = longest


def owner_role_in(text):
    """Return the Maintainer role from the "- Owner:" line of an AGENTS.md text, lower case, without a leading "the "
    ('' if the text has no such line)."""
    m = re.search(r'^- Owner:\s*(.+?)\s*$', text, re.M)
    return re.sub(r'^the\s+', '', m.group(1).rstrip('.').lower()) if m else ''


def owner_role(root):
    """Return the Maintainer role from the AGENTS.md file under `root` (owner_role_in; '' when there is no file)."""
    try:
        return owner_role_in((Path(root) / 'AGENTS.md').read_text(encoding='utf-8'))
    except OSError:
        return ''


def squeeze(text):
    """Return `text` with all white space removed, so two rows that differ only in spacing are equal."""
    return re.sub(r'\s+', '', text)


def row_refusal(text, name, owner, names=None):
    """Return why a DECISIONS line is not a new owner's row for file `name`, or None when it is one.

    Args:
        text: a line of docs/DECISIONS.md that main does not have.
        name: the settings file name the decision cell must name.
        owner: the Maintainer role (owner_role), lower case.
        names: a test that says whether a text names the file (None: the text holds `name`).

    Returns:
        The refusal (which rule refused it) or None.
    """
    row = text.strip()
    if not row.startswith('|'):
        return 'rule 1: not a table row (a line that starts with |)'
    cells = [c.replace('\0', '|').strip() for c in row.replace('\\|', '\0').strip('|').split('|')]
    if len(cells) != ROW_CELLS:
        return 'rule 1: a decision row has %d cells: date, decision, by, last (write \\| for a | inside a cell)' % ROW_CELLS
    if not (names(cells[1]) if names else name in cells[1]):
        return 'rule 2: the decision cell does not name ' + name
    by = cells[2].lower()
    bad = [x for x in NOT_OWNER if x in by]
    if bad:
        return 'rule 3: the By cell names a script or an agent (%s)' % bad[0]
    if not owner:
        return 'rule 4: AGENTS.md has no "- Owner:" line to name the Maintainer'
    if not re.fullmatch(r'(the\s+)?' + re.escape(owner) + r'(\s*\([^()]*\))?', by):
        return 'rule 4: the By cell is not the Maintainer alone (%s; one note in brackets may follow)' % owner
    return None


def owner_row(new_text, name, owner, old_text='', names=None):
    """Compare docs/DECISIONS.md with its text on the merge base and look for the Maintainer's new row that opens the
    ratchet gate. The gate opens only in a change that adds rows and leaves every older row as it was: an older row
    that is edited or removed closes it, so no old decision can be turned into a new one. The two texts are compared
    line by line (lines end at a line feed only); no diff output is read, no date, and no text for likeness.

    Args:
        new_text: docs/DECISIONS.md as it is in this change.
        name: the settings file name.
        owner: the Maintainer role (owner_role_in).
        old_text: docs/DECISIONS.md at the merge base ('' when there is none).
        names: a test that says whether a text names the file (None: the text holds `name`); the check gives the
            one that takes `.check` but not `.check.lock` or `.check.state.json`.

    Returns:
        (True, []) when a new table row names `name` and has the Maintainer alone in its By cell, and no older row was
        edited or removed; else (False, the refusal lines, each with the rule that refused).
    """
    table = lambda text: {squeeze(x) for x in text.split('\n') if x.strip().startswith('|')}
    old_lines = {squeeze(x) for x in old_text.split('\n')}
    refusals, found = [], False
    for line in new_text.split('\n'):
        if not (names(line) if names else name in line) or squeeze(line) in old_lines:
            continue   # not about the settings file, or a line main has already (a moved or re-spaced row is no decision)
        why = row_refusal(line, name, owner, names)
        found = found or why is None
        if why:
            refusals.append('REFUSED  docs/DECISIONS.md line (%s): %s' % (why, line.strip()[:60]))
    touched = sorted(table(old_text) - table(new_text))
    if found and touched:
        return False, ['REFUSED  docs/DECISIONS.md (rule 5: this change also edits or removes %d older row(s), first: %s; '
                       'record the decision in a change that only adds its row)' % (len(touched), touched[0][:40])]
    return found, ([] if found else refusals)


def exists_at(root, ref, path):
    """True when `path` exists in the commit `ref` (git cat-file -e); a file that does not is new in this change."""
    return subprocess.run(['git', '-C', str(root), 'cat-file', '-e', '%s:%s' % (ref, path)],
                          capture_output=True).returncode == 0


def at_ref(root, ref, path):
    """Return the text of `path` in the commit `ref` ('' when it has none); bytes are read, so a lone CR stays in its
    line."""
    out = subprocess.run(['git', '-C', str(root), 'show', '%s:%s' % (ref, path)], capture_output=True)
    return out.stdout.decode('utf-8', 'replace') if out.returncode == 0 else ''


def decided(root, ref):
    """Return whether this change records the Maintainer's decision on the settings file `.check` (owner_row).

    Args:
        root: the repo root.
        ref: the merge base with origin/main.

    Returns:
        (True, []) for an owner row; else (False, the refusal lines). The Maintainer is read from main's AGENTS.md, so an
        owner line changed in this change does not count.
    """
    here = Path(root) / 'docs' / 'DECISIONS.md'
    text = here.read_bytes().decode('utf-8', 'replace') if here.is_file() else ''
    return owner_row(text, settings.CHECK, owner_role_in(at_ref(root, ref, 'AGENTS.md')),
                     at_ref(root, ref, 'docs/DECISIONS.md'), settings.NAMES_CHECK.search)


def new_debt_refusal(root, ref, kind, key):
    """Refuse debt for a file that is new in this change: new files meet the rules, and no decision lifts that.

    Args:
        root: the repo root.
        ref: the merge base with origin/main.
        kind: the debt kind.
        key: the debt key (a path, or path::function).

    Returns:
        A FAIL line, or None when the file exists at `ref`.
    """
    if exists_at(root, ref, key.split('::')[0]):
        return None
    return NEW_DEBT_FORMAT % (key, kind)


if __name__ == '__main__':
    if '--test' in sys.argv[1:]:
        import unittest   # scripts/code_standard_strict_test.py: the cases (kept apart, rule C4)
        sys.exit(0 if unittest.main(module='code_standard_strict_test', argv=sys.argv[:1], exit=False).result.wasSuccessful() else 1)
    print('Not run alone: scripts/code_standard.py loads it (`code-strict-gate: on` in .check). Self-test: --test')
    sys.exit(2)
