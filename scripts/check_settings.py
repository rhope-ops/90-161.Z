#!/usr/bin/env python3
"""The one reader of the code standard and audit settings in `.check`, and the one reader and writer of
`.check.state.json` (the Maintainer, 2026-11-18: one config layout in every repo).

The three files at the top of a repo:
    .check             every setting a person edits: one entry per line, `#` comments. The content check reads its
                       own lines, `content-max-bytes` included (scripts/check_content_scan.py); this module reads the `code-` and
                       `audit-` lines.
    .check.lock        written by a sync (scripts/check_lock.py); not read here.
    .check.state.json  everything tools write: {"code_standard": {"debt": {...}}, "audit": {"last_audit": {...}},
                       "timings": {...}}, with sorted keys and indent 1, so the same state gives the same bytes.

The setting lines (a missing key means the default; a key marked * may appear on several lines):
    code-max-file-lines: 450        code-max-function-lines: 60
    code-include: <glob> *          code-exclude: <glob> *          code-generated: <glob> *
    code-paste: <glob> *            a script a person pastes into another tool (one file is one paste): its C4 cap is
    code-max-file-lines-paste: 600  this one, not code-max-file-lines (docs/code-standard.md C4)
    code-c1-safety: on|off|strict   code-c2: full|lean
    code-max-line-chars: <number>   no line = off. This line and `code-c1-safety: strict` need a gate: the kit's
                                    (`code-strict-gate: on`, scripts/code_standard_strict.py) or a project's own
                                    (scripts/code_standard_gate.py, which wins); the check fails without one.
    code-strict-gate: on|off        default off; docs/code-standard.md "The strict gate"
    audit-every-days: 14            audit-every-commits: 300
    audit-ignore: <glob> *          audit-start-read: <path> *
    audit-duplicate-ignore: <glob> *  a file it matches is not read by the duplicate count (the other audit measures
                                    still read it); --migrate moves the old .bloat-audit.json "duplicate_ignore"
    audit-third-party: <glob> *     a third-party skill folder or agent file (`.claude/skills/<name>`, `.claude/agents/<name>.md`):
                                    its name and description count against `third_party_tokens`, not the session load
    audit-instructions: <glob> *    a file whose steps a person follows (AGENTS.md "Instructions people follow"):
                                    scripts/check_instructions.py checks its steps, and its hook asks for the skill first
    audit-budget-<name>: <number>   names: the keys of AUDIT_DEFAULTS["budgets"]; the KIT_CAPS may only be lowered
    dod-security: on|off            a page the kit builds (scripts/build_site_html.py) gets a Content-Security-Policy and a
                                    no-referrer meta tag only when `on` (default off); read there; the sync adds
                                    the DoD group (sync_baseline.DOD_FILES) only when `on`
An unknown `code-` or `audit-` key, a key in capitals, a single key on two lines, or a value that is not valid raises
ValueError: the check that reads it fails with that message (a typo must not relax a limit in silence).

Inputs:  `.check` and `.check.state.json` in the working tree or at a git ref (`git show <ref>:<file>`); for --migrate
         also the old files `.code-standard.json`, `.bloat-audit.json` and `.pii-guard`.
Outputs: settings as dicts for scripts/code_standard.py and scripts/bloat_check.py; `.check.state.json` on a write.
Usage:   python3 scripts/check_settings.py            print the settings and the state that the checks read (JSON)
         python3 scripts/check_settings.py --migrate  move the old files of this repo into the three files: append
                                                      the settings that are not defaults to `.check` (existing lines
                                                      stay as they are), write `.check.state.json`, delete the old
                                                      files; prints each step; a second run changes nothing.
                                                      An old key with no place in this layout is not moved: one
                                                      `NOTE  dropped <file> <key>=<value>: <reason>` line each, and
                                                      the last line lists them. The kit header lines at the top
                                                      of `.check` become the current block (HEADER_BLOCK).
         python3 scripts/check_settings.py --test     self-test in temporary repos; prints SETTINGS TEST PASS
                                                      (the cases: scripts/check_settings_test.py)
Parts:   scripts/check_settings_read.py (the keys, the readers and the state file; every name is re-exported here).
Needs:   Python 3.8+ and git. Standard library only.
Network: none (it runs local git read commands).
Writes:  .check.state.json; with --migrate also .check, and it deletes the old settings files.
Credentials: none.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

from build_site_html import dod_security  # noqa: E402 - scripts/build_site_html.py: the reader of `dod-security:`
from check_content_scan_settings import UNKNOWN_PROFILE, load_allow, profile_of  # noqa: E402 - the content-check tier

# scripts/check_settings_read.py: the keys, the readers and the state file (kept apart, docs/code-standard.md C4).
from check_settings_read import (  # noqa: F401 - every name is re-exported: other scripts import them from here
    _KEY, AUDIT_DEFAULTS, AUDIT_LISTS, CHECK, CODE_DEFAULTS, CODE_LISTS, KIT_CAPS, LOOKS_LIKE_SETTING, MIGRATE,
    NAMES_CHECK, OLD_AUDIT, OLD_CHECK, OLD_CODE, OPT_IN_CAPS, SETTING_LINE, STATE, STATE_PARTS, STRICT, audit_config,
    audit_from_old, audit_settings, choice, code_base, code_config, code_from_old, code_settings, collect, dash,
    load_state, not_migrated, number, pairs, read, save_part, state_text)

# The comment block at the top of the kit's `.check` (HEADER is its first line), and the first lines of older kit
# versions that named the old scanner. When the first line of a `.check` is one of these, --migrate replaces every
# kit header line of any version (OLD_HEADER_LINES) in the leading comment block with HEADER_BLOCK.
HEADER_BLOCK = (
    '# Settings of the content check (scripts/check.sh --content; the pre-push hook and the "checks" GitHub Action).',
    "# One entry per line:",
    "#   <exact string>          allowed although it looks like personal data",
    "#   skip: <path or glob>    not scanned",
    "#   block: <path or glob>   must not be committed or sent (for example `block: *.xlsx`)",
    "#   profile: dod            the DoD tier; `denylist: warn` lets a push pass with no name denylist",
    "#   content-max-bytes: <n>  scan text files up to n bytes (default 2000000, at most 50000000; larger ones block"
    " in the DoD tier)",
    "#   code-<key>: <value>     a setting of the code standard, for example `code-max-function-lines: 60`",
    "#   audit-<key>: <value>    a setting of the audit, for example `audit-ignore: ref/**`",
    "#                           (the keys and their defaults: the header of scripts/check_settings.py; a `code-` change",
    "#                           needs a docs/DECISIONS.md row that names this file)",
    "# An allowed string or a skip line is added only on the Maintainer's request, never by an agent to get past a block"
    ' (AGENTS.md "Guards and checks").',
)
HEADER = HEADER_BLOCK[0]
OLD_HEADERS = (
    "# Opt-in file for scripts/pii_guard.py (pre-push hook and the pii-guard GitHub Action).",
    '# Opt-in file for scripts/pii_guard.py (pre-push hook, the merge check in AGENTS.md "Delivery" and the pii-guard Action).',
)
OLD_HEADER_LINES = frozenset(HEADER_BLOCK + OLD_HEADERS + (   # the other lines of older kit header blocks
    "# Below: exact strings that are allowed although they look like personal data, one per line.",
    "# `skip: <path or glob>` excludes a path.",
    '# Only the Maintainer adds entries. Agents never add one to get past a block (AGENTS.md "Personal data").',
    '# Only the Maintainer adds an allowed string or a skip line. Agents never add one to get past a block (AGENTS.md'
    ' "Personal data").',
    "# An allowed string or a skip line is added only on the Maintainer's request, never by an agent to get past a block"
    ' (AGENTS.md "Personal data").',
))

# ---------------------------------------------------------------- migration ------------------------------------------

def code_lines(cfg):
    """The `.check` lines for the code standard settings that differ from the defaults."""
    out = [f"code-{dash(c)}: {v}" for c, v in cfg["caps"].items() if v != CODE_DEFAULTS["caps"].get(c)]
    for name in CODE_LISTS:
        if cfg[name] != CODE_DEFAULTS[name]:
            out += [f"code-{name}: {g}" for g in cfg[name]]
    safety = cfg["c1_safety"]   # False, True or "strict"
    return out + ([f"code-c1-safety: {STRICT if safety == STRICT else 'on'}"] if safety else []) \
        + (["code-c2: full"] if cfg["c2"] == "full" else [])


def audit_lines(cfg):
    """The `.check` lines for the audit settings that differ from the defaults."""
    out = [f"audit-{dash(n)}: {cfg[n]}" for n in ("every_days", "every_commits") if cfg[n] != AUDIT_DEFAULTS[n]]
    out += [f"audit-budget-{b}: {v}" for b, v in cfg["budgets"].items() if v != AUDIT_DEFAULTS["budgets"].get(b)]
    for name in AUDIT_LISTS:
        out += [f"audit-{dash(name)}: {g}" for g in cfg[name]]
    return out


def old_json(root, name):
    """The object in an old JSON settings file, or None when the file does not exist."""
    data = read(root, name)
    if data is None:
        return None
    obj = json.loads(data.decode("utf-8"))
    if not isinstance(obj, dict):
        raise ValueError(f"{name}: top level is not an object")
    return obj


ROLE_IN_LINE = re.compile(r"\b([Tt])he [A-Za-z][A-Za-z ._-]*?(?='s request\b| adds )")  # "the Maintainer's request", "the PFM adds"


def role_free(line):
    """A header line with its role word made neutral, so an old kit line matches in any repo (kit fix 0(a): a sync
    puts each repo's role word, for example "the PFM", into the lines a project's `.check` holds).

    Args:
        line: one line of a `.check` header block.
    Returns:
        The line with "the <role>" before "'s request" or " adds " written as "the Maintainer".
    """
    return ROLE_IN_LINE.sub(lambda m: m.group(1) + "he owner", line)


def new_header(data):
    """The bytes of a `.check` file with its kit header block renewed: when the first line is a kit header line
    (HEADER or OLD_HEADERS), each kit header line of any version (OLD_HEADER_LINES) in the leading comment block
    (the `#` lines before the first other line) is dropped and HEADER_BLOCK goes on top. A project comment in that
    block stays, in its order, below HEADER_BLOCK; every line after the block stays as it is. Another first line:
    no change.
    Args:
        data: the bytes of the file, or None.
    Returns:
        (the bytes, True when the header block changed).
    """
    lines = (data or b"").split(b"\n")
    if lines[0].rstrip(b"\r").decode("utf-8", "replace") not in OLD_HEADERS + (HEADER,):
        return data, False
    end = next((i for i, l in enumerate(lines) if not l.startswith(b"#")), len(lines))
    cr = b"\r" if lines[0].endswith(b"\r") else b""
    old = {role_free(h) for h in OLD_HEADER_LINES}
    own = [l for l in lines[:end] if role_free(l.rstrip(b"\r").decode("utf-8", "replace")) not in old]
    text = b"\n".join([h.encode() + cr for h in HEADER_BLOCK] + own + lines[end:])
    return (text, True) if text != data else (data, False)


def old_settings(code, audit):
    """The settings of the old files in this layout, and what has no place in it.
    Args:
        code: the object of the old .code-standard.json, or None.
        audit: the object of the old .bloat-audit.json, or None.
    Returns:
        (want, dropped): want is a list of (old file name, settings dict, its line writer, its line reader);
        dropped is a list of (old file name, key, value, reason).
    """
    want, dropped = [], []
    for name, obj, top in ((OLD_CODE, code, ("config", "debt")), (OLD_AUDIT, audit, None)):
        if obj is None:
            continue
        part = []
        if name == OLD_CODE:
            want.append((name, code_from_old(obj.get("config", {}), part), code_lines, code_settings))
            part = [("config." + k, v, why) for k, v, why in part]
            part += [(k, obj[k], "the code standard has no such part") for k in sorted(obj) if k not in top]
        else:
            want.append((name, audit_from_old(obj, part), audit_lines, audit_settings))
        dropped += [(name, k, v, why) for k, v, why in part]
    return want, dropped


def migrate_plan(root):
    """Work out the migration and change nothing. A key of an old file that has no place in this layout is not moved
    (it is returned in `dropped`). ValueError when the new `.check` would not give the same settings as the rest of
    the old files (for example a key that is already there with another value), so no setting that has a place
    changes its meaning in silence.
    Args:
        root: the repo root (a folder path).
    Returns:
        The tuple (new .check bytes or None, new state or None, old files to delete, lines to print, dropped keys
        as "<file> <key>" texts).
    """
    root = Path(root)
    code, audit = old_json(root, OLD_CODE), old_json(root, OLD_AUDIT)
    data, renamed = read(root, CHECK), False
    if data is None and (root / OLD_CHECK).is_file():
        data, renamed = read(root, OLD_CHECK), True
    notes = []
    if not renamed and (root / OLD_CHECK).is_file():
        notes.append(f"NOTE  both {CHECK} and {OLD_CHECK} exist: move the lines of {OLD_CHECK} into {CHECK} by hand, "
                     "then delete it")
    text, header = new_header(data)
    head_note = [f"{CHECK}: the kit header lines at the top were an old kit header; they are now the kit's current "
                 "header block (project comments stay)"] if header else []
    if code is None and audit is None and not renamed:
        return (text if header else None), None, [], notes + (head_note or ["nothing to migrate: no old settings file here"]), []
    want, dropped = old_settings(code, audit)
    have = {l.strip() for l in (data or b"").decode("utf-8", "replace").splitlines()}
    add = [l for _, cfg, lines, _ in want for l in lines(cfg) if l not in have]
    text = text or b""
    if add:
        text += b"" if not text or text.endswith(b"\n") else b"\n"
        text += ("# Code standard and audit settings (the keys: the header of scripts/check_settings.py).\n"
                 + "\n".join(add) + "\n").encode()
    for name, cfg, _, parse in want:
        if parse(pairs(text)) != cfg:
            raise ValueError(f"the settings of {name} cannot be written into {CHECK} as they are (a value with no "
                             "line form, or a line that is already there with another value)")
    state = load_state(root)
    if code is not None:
        state["code_standard"] = {"debt": code.get("debt", {})}
    if audit is not None and audit.get("last_audit"):
        state["audit"] = {"last_audit": audit["last_audit"]}
    if audit is not None and audit.get("timings"):
        state["timings"] = audit["timings"]
    notes += [f"NOTE  dropped {name} {key}={json.dumps(value)}: {why}" for name, key, value, why in dropped]
    notes += [f"{CHECK}: started from the lines of {OLD_CHECK}"] if renamed else []
    notes += head_note
    notes += [f"{CHECK}: added `{l}`" for l in add] or (
        [f"{CHECK}: no setting line to add (the old settings are the defaults, or the lines are there)"] if want else [])
    gone = [n for n, there in ((OLD_CODE, code is not None), (OLD_AUDIT, audit is not None), (OLD_CHECK, renamed)) if there]
    return (text if add or renamed or header else None), (state if want else None), gone, notes, \
        [f"{name} {key}" for name, key, _, _ in dropped]


def migrate(root):
    """--migrate: move the old settings files of this repo into `.check` and `.check.state.json`, delete them, and
    print each step. Returns 0, or 1 with nothing changed when a setting that has a place in this layout cannot be
    moved as it is.
    Args:
        root: the repo root (a folder path).
    Returns:
        The exit code: 0, or 1 with nothing changed.
    """
    root = Path(root)
    try:
        text, state, gone, notes, dropped = migrate_plan(root)
    except ValueError as e:
        print(f"SETTINGS MIGRATE FAIL: {e}. Nothing changed.")
        return 1
    if text is not None:
        new = not (root / CHECK).is_file()
        (root / CHECK).write_bytes(text)
        if new and OLD_CHECK not in gone:
            notes.append(f"NOTE  {CHECK} is new here: the content check of tracked files is now on "
                         "(.claude/skills/personal-data/SKILL.md)")
    if state is not None:
        (root / STATE).write_text(state_text(state), encoding="utf-8")
        notes.append(f"{STATE}: written ({', '.join(p for p in STATE_PARTS if p in state)})")
    for name in gone:
        (root / name).unlink()
        notes.append(f"{name}: deleted")
    print("\n".join(notes))
    if gone:
        print(f"SETTINGS MIGRATED: review with git diff, then commit {CHECK}, {STATE} and the deleted files"
              + (f". Dropped, not moved ({len(dropped)}): {', '.join(dropped)}" if dropped else ""))
    return 0


def validate_config(root):
    """Read every key group of `.check` and `.check.state.json` in root; print one line per error (fleet v2 1.4).

    Args:
        root: the repository folder that holds `.check`.
    Returns:
        The exit code: 0 when every group reads, 1 when any group raises ValueError or the tier line is unknown.
    """
    errors = []
    for name, read in (("code", code_config), ("audit", audit_config), ("state", load_state),
                       ("dod-security", dod_security)):
        try:
            read(root)
        except ValueError as e:
            errors.append(f"{name}: {e}")
    if profile_of(load_allow(root)) == "unknown":
        errors.append("profile: " + UNKNOWN_PROFILE)
    for line in errors:
        print(f"CONFIG FAIL  {line}")
    print(f"CONFIG {'FAIL' if errors else 'PASS'}: {root / CHECK} ({len(errors)} error(s))")
    return 1 if errors else 0


def main():
    """Parse the options and run the chosen mode; return its exit code.
    Returns:
        The exit code: 0 pass, 1 fail.
    """
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0], allow_abbrev=False)
    ap.add_argument("--migrate", action="store_true", help="move the old settings files into .check and .check.state.json")
    ap.add_argument("--test", action="store_true", help="self-test in temporary repos")
    ap.add_argument("--validate-config", nargs="?", const="", metavar="FOLDER",
                    help="read every key of .check in FOLDER (default: this repo); exit 1 on any error")
    args = ap.parse_args()
    if args.test:
        import check_settings_test   # scripts/check_settings_test.py: kept apart (docs/code-standard.md C4)
        return check_settings_test.run()
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    root = Path(top.stdout.strip() if top.returncode == 0 else ".")
    if args.validate_config is not None:
        return validate_config(Path(args.validate_config) if args.validate_config else root)
    if args.migrate:
        return migrate(root)
    try:
        print(json.dumps({"code": code_config(root), "audit": audit_config(root)}, indent=1, sort_keys=True))
    except ValueError as e:
        print(f"SETTINGS FAIL: {e}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
