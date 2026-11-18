#!/usr/bin/env python3
"""This project's own gate for the kit's code-standard check (scripts/code_standard.py loads it: the extension point
in its header; the text of the rules: docs/code-standard-90-161.md). The same rules as rhope-ops/RADE.

Why: a rule that can be met with a word somewhere in a header, or with any line that names the settings file, is met by
accident, not by work (the PFM, 2026-11-17; docs/DECISIONS.md "Code-standard checker made stricter").
The five entry points (their exact form: the header of scripts/code_standard.py):
  RULES             the debt kind `line` (C4 line, measured against `code-max-line-chars`) and the label of the strict
                    C1 safety form
  OPT_IN            the kind `line`: on when `.check` has a `code-max-line-chars` line
  file_rules        C1 safety in the strict form (each label starts a header line and has a value; this project applies
                    it at `code-c1-safety: on` as before, and at `strict`) and the line length of one source file
  decided           the owner's decision: a NEW docs/DECISIONS.md table row that names `.check` and has the owner alone
                    in its By cell, in a change that leaves every older row as it was (owner_row)
  new_debt_refusal  debt for a file that is new in this change is refused, whatever was decided (new files meet the rules)
Helpers: safety_ok, longest_line, owner_role_in, owner_role, squeeze, row_refusal, owner_row, exists_at.
Inputs:  header text, file lines, the settings, docs/DECISIONS.md and AGENTS.md at a git ref and in the working tree.
Outputs: violations written into the caller's dict, yes/no answers and refusal lines.
Network: none.
Writes: none (it runs git read-only commands; the check that loads it writes .check.state.json).
Credentials: none.
Run:     loaded by scripts/code_standard.py. Self-test: python3 scripts/code_standard_gate.py --test
         (scripts/code_standard_gate_test.py; scripts/check.sh runs it).
"""

import re
import subprocess
from pathlib import Path

SAFETY_LABELS = ('Network:', 'Writes:', 'Credentials:')   # C1 safety: what a reviewer must find before a run
# A By cell with one of these marks a script or an agent, not the owner (the owner, 2026-11-17: only the owner decides).
NOT_OWNER = ('scripts/', '.py', 'agent', 'delegation')
ROW_CELLS = 4              # a DECISIONS row: date, decision, by, last (exactly: a spare cell would move the By cell)
SETTINGS = '.check'        # the settings file a decision row must name (the kit's scripts/check_settings.py CHECK)
# `.check` as a word, not `.check.lock` or `.check.state.json` (the same test as NAMES_CHECK of scripts/check_settings.py;
# kept here so this module imports nothing of the check when it is loaded).
NAMES_SETTINGS = re.compile(r"(?<![\w.])\.check(?!\.(?:lock|state)|\w)")

# The entry points of the extension point (header of scripts/code_standard.py).
RULES = {'line': ('C4 line longer than %d characters', 'max_line_chars'),
         'safety': ('C1 safety: header without a Network:, Writes: and Credentials: line, each with a value', None)}
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
    """Write this project's per-file violations of one source file into `v` (after the kit's own per-file rules):
    C1 safety in the strict form, and the line length when `.check` sets `code-max-line-chars`.

    Args:
        v: the violations dict {kind: {key: value}}, changed in place.
        p: the repo-relative path.
        lines: the file's lines.
        head: the header text (one header line per text line).
        config: the code standard settings.
        skip: the (first, last) line numbers of the generated blocks.
    """
    if config.get('c1_safety') and not safety_ok(head):
        v['safety'][p] = 1
    cap = config['caps'].get('max_line_chars')
    if cap:
        longest = longest_line(lines, skip)
        if longest > cap:
            v['line'][p] = longest


def git_show(root, ref, path):
    """Return the text of `path` at the git ref `ref` ('' when it is not there). Read as bytes, so a lone carriage
    return stays inside its line."""
    out = subprocess.run(['git', '-C', str(root), 'show', '%s:%s' % (ref, path)], capture_output=True)
    return out.stdout.decode('utf-8', 'replace') if out.returncode == 0 else ''


def decided(root, ref):
    """The owner's decision for this change: a new docs/DECISIONS.md row that names `.check`, with main's owner alone
    in its By cell (owner_row; the owner role is read from AGENTS.md at `ref`, so a change cannot name a new owner).

    Args:
        root: the repo root.
        ref: the merge base with origin/main.

    Returns:
        (True, []) when decided; else (False, the refusal lines).
    """
    here = Path(root) / 'docs' / 'DECISIONS.md'
    now = here.read_bytes().decode('utf-8', 'replace') if here.is_file() else ''
    return owner_row(now, SETTINGS, owner_role_in(git_show(root, ref, 'AGENTS.md')),
                     git_show(root, ref, 'docs/DECISIONS.md'), NAMES_SETTINGS.search)


def new_debt_refusal(root, ref, kind, key):
    """Refuse a debt key for a file that is new in this change (new files meet the rules; no decision lifts it).

    Args:
        root: the repo root.
        ref: the merge base with origin/main.
        kind: the debt kind.
        key: the debt key ("<path>" or "<path>::<function>").

    Returns:
        A FAIL line, or None when the file exists at `ref`.
    """
    if exists_at(root, ref, key.split('::')[0]):
        return None
    return 'FAIL  baseline: %s debt for a file that is new in this change: %s (new files meet the rules)' % (kind, key)


def owner_role_in(text):
    """Return the owner role from the "- Owner:" line of an AGENTS.md text, lower case, without a leading "the "
    ('' if the text has no such line)."""
    m = re.search(r'^- Owner:\s*(.+?)\s*$', text, re.M)
    return re.sub(r'^the\s+', '', m.group(1).rstrip('.').lower()) if m else ''


def owner_role(root):
    """Return the owner role from the AGENTS.md file under `root` (owner_role_in; '' when there is no file)."""
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
        names: a test that says whether a text names the file (None: the text holds `name`).
        owner: the owner role (owner_role), lower case.

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
        return 'rule 4: AGENTS.md has no "- Owner:" line to name the owner'
    if not re.fullmatch(r'(the\s+)?' + re.escape(owner) + r'(\s*\([^()]*\))?', by):
        return 'rule 4: the By cell is not the owner alone (%s; one note in brackets may follow)' % owner
    return None


def owner_row(new_text, name, owner, old_text='', names=None):
    """Compare docs/DECISIONS.md with its text on the merge base and look for the owner's new row that opens the
    ratchet gate. The gate opens only in a change that adds rows and leaves every older row as it was: an older row
    that is edited or removed closes it, so no old decision can be turned into a new one. The two texts are compared
    line by line (lines end at a line feed only); no diff output is read, no date, and no text for likeness.

    Args:
        new_text: docs/DECISIONS.md as it is in this change.
        name: the settings file name.
        owner: the owner role (owner_role_in).
        old_text: docs/DECISIONS.md at the merge base ('' when there is none).
        names: a test that says whether a text names the file (None: the text holds `name`); decided() gives the one
            that takes `.check` but not `.check.lock` or `.check.state.json`.

    Returns:
        (True, []) when a new table row names `name` and has the owner alone in its By cell, and no older row was
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


if __name__ == '__main__':
    import sys
    if '--test' in sys.argv[1:]:
        import code_standard_gate_test   # scripts/code_standard_gate_test.py: kept apart (rule C4)
        sys.exit(code_standard_gate_test.run(sys.modules[__name__]))
    print('Not run alone: scripts/code_standard.py loads it. Self-test: python3 scripts/code_standard_gate.py --test')
    sys.exit(2)
