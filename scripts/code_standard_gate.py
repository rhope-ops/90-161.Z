#!/usr/bin/env python3
"""The strict parts of the code-standard check (scripts/code_standard.py): the C1 safety labels, the per-file rules, the
line-length rule, and the three gates that decide whether the ratchet baseline may take new debt.

Why: a rule that can be met with a word somewhere in a header, or with any line that names the baseline file, is met by
accident, not by work. This module holds the strict forms so the check stays under its own file cap (docs/code-standard.md C4).
What it does:
  safety_ok       a safety label starts a header line and has a value on that line
  file_rules      the per-file rules (header, safety, file size, line length) of one source file
  owner_row       a NEW docs/DECISIONS.md table row that names .code-standard.json and has the owner in its By cell
                  (only in a change that leaves every older row as it was: an edited old row is no decision)
  owner_role_in   the owner role, read from the "- Owner:" line of AGENTS.md (the check gives it main's AGENTS.md)
  exists_at       a file exists at a git ref (a debt key for a file new in this change is refused)
  level           how far an opt-in rule is adopted in a config (a higher level than on main may list new debt once)
Inputs:  header text, file lines, git diff text, a repo root and a git ref.
Outputs: yes/no answers, refusal lines, and violations written into the caller's dict.
Network: none.
Writes: none (it runs git read-only commands; the check that imports it writes .code-standard.json).
Credentials: none.
Run:     imported by scripts/code_standard.py; proved by `python3 scripts/code_standard.py --test`.
"""

import re
import subprocess
from pathlib import Path

SAFETY_LABELS = ('Network:', 'Writes:', 'Credentials:')   # C1 safety: what a reviewer must find before a run
MIN_HEADER_CHARS = 60      # a header shorter than this does not say what the file is for
# A By cell with one of these marks a script or an agent, not the owner (the owner, 2026-11-17: only the owner decides).
NOT_OWNER = ('scripts/', '.py', 'agent', 'delegation')
ROW_CELLS = 4              # a DECISIONS row: date, decision, by, last (exactly: a spare cell would move the By cell)
# The opt-in rules: the debt kind of each and its level in a config (0 = off). Level 2 of safety marks the strict form.
OPT_IN = {'docs': lambda c: 1 if c.get('c2') == 'full' else 0,
          'safety': lambda c: safety_level(c.get('c1_safety')),
          'line': lambda c: 1 if c.get('caps', {}).get('max_line_chars') else 0}


def safety_level(value):
    """Return the level of the "c1_safety" setting: 0 = off, 1 = on (true), 2 or more = a stricter form (a number, or
    digits as text). Any other value that is set counts as 1; a negative number as 0."""
    if isinstance(value, str) and re.fullmatch(r'[0-9]{1,6}', value.strip()):
        value = int(value.strip())
    if type(value) is int:
        return max(0, value)
    return 1 if value else 0


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
    """Write the per-file violations of one source file into `v`: C1 header, C1 safety, C4 file size, line length.

    Args:
        v: the violations dict {kind: {key: value}}, changed in place.
        p: the repo-relative path.
        lines: the file's lines.
        head: the header text (header_block of scripts/code_standard.py).
        config: the baseline "config".
        skip: the (first, last) line numbers of the generated blocks.

    Returns:
        None.
    """
    caps = config['caps']
    if len(head) < MIN_HEADER_CHARS:
        v['header'][p] = 1
    if config.get('c1_safety') and not safety_ok(head):
        v['safety'][p] = 1
    if len(lines) > caps['max_file_lines']:
        v['file_size'][p] = len(lines)
    longest = longest_line(lines, skip) if caps.get('max_line_chars') else 0
    if longest > caps.get('max_line_chars', longest):
        v['line'][p] = longest


def level(kind, config):
    """Return how far the opt-in rule of debt kind `kind` is adopted in `config` (0 = off or not an opt-in kind)."""
    return OPT_IN[kind](config) if kind in OPT_IN else 0


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


def row_refusal(text, name, owner):
    """Return why a DECISIONS line is not a new owner's row for file `name`, or None when it is one.

    Args:
        text: a line of docs/DECISIONS.md that main does not have.
        name: the baseline file name the decision cell must name.
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
    if name not in cells[1]:
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


def owner_row(new_text, name, owner, old_text=''):
    """Compare docs/DECISIONS.md with its text on the merge base and look for the owner's new row that opens the
    ratchet gate. The gate opens only in a change that adds rows and leaves every older row as it was: an older row
    that is edited or removed closes it, so no old decision can be turned into a new one. The two texts are compared
    line by line (lines end at a line feed only); no diff output is read, no date, and no text for likeness.

    Args:
        new_text: docs/DECISIONS.md as it is in this change.
        name: the baseline file name.
        owner: the owner role (owner_role_in).
        old_text: docs/DECISIONS.md at the merge base ('' when there is none).

    Returns:
        (True, []) when a new table row names `name` and has the owner alone in its By cell, and no older row was
        edited or removed; else (False, the refusal lines, each with the rule that refused).
    """
    table = lambda text: {squeeze(x) for x in text.split('\n') if x.strip().startswith('|')}
    old_lines = {squeeze(x) for x in old_text.split('\n')}
    refusals, found = [], False
    for line in new_text.split('\n'):
        if name not in line or squeeze(line) in old_lines:
            continue   # not about the baseline, or a line main has already (a moved or re-spaced row is no decision)
        why = row_refusal(line, name, owner)
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
