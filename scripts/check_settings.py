#!/usr/bin/env python3
"""The one reader of the code standard and audit settings in `.check`, and the one reader and writer of
`.check.state.json` (the PFM, 2026-11-18: one config layout in every repo).

The three files at the top of a repo:
    .check             every setting a person edits: one entry per line, `#` comments. The content check reads its
                       own lines, `content-max-bytes` included (scripts/check_content_scan.py); this module reads the `code-` and
                       `audit-` lines.
    .check.lock        written by a sync (scripts/check_lock.py); not read here.
    .check.state.json  everything tools write: {"code_standard": {"debt": {...}}, "audit": {"last_audit": {...}},
                       "timings": {...}}, with sorted keys and indent 1, so the same state gives the same bytes.

The setting lines (a missing key means the default; a key marked * may appear on several lines):
    code-max-file-lines: 600        code-max-function-lines: 60
    code-include: <glob> *          code-exclude: <glob> *          code-generated: <glob> *
    code-c1-safety: on|off|strict   code-c2: full|lean
    code-max-line-chars: <number>   no line = off. This line and `code-c1-safety: strict` are for a project's own
                                    gate (scripts/code_standard_gate.py; docs/code-standard.md "A project's own gate"):
                                    the kit reads them, the gate enforces them, and the check fails without a gate.
    audit-every-days: 14            audit-every-commits: 300
    audit-ignore: <glob> *          audit-start-read: <path> *
    audit-duplicate-ignore: <glob> *  a file it matches is not read by the duplicate count (the other audit measures
                                    still read it); --migrate moves the old .bloat-audit.json "duplicate_ignore"
    audit-third-party: <glob> *     a third-party skill folder or agent file (`.claude/skills/<name>`, `.claude/agents/<name>.md`):
                                    its name and description count against `third_party_tokens`, not the session load
    audit-instructions: <glob> *    a file whose steps a person follows (AGENTS.md "Instructions people follow"):
                                    scripts/check_instructions.py checks its steps, and its hook asks for the skill first
    audit-budget-<name>: <number>   names: the keys of AUDIT_DEFAULTS["budgets"]; the KIT_CAPS may only be lowered
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
import unicodedata
from pathlib import Path

CHECK = ".check"
STATE = ".check.state.json"
OLD_CODE = ".code-standard.json"   # before 2026-11-18: the code standard's caps, scope and debt list
OLD_AUDIT = ".bloat-audit.json"    # before 2026-11-18: the audit's settings, last audit and time baselines
OLD_CHECK = ".pii-guard"           # before 2026-11-18: the name of .check
MIGRATE = "python3 scripts/check_settings.py --migrate"
CODE_DEFAULTS = {"caps": {"max_file_lines": 600, "max_function_lines": 60}, "include": ["*"], "exclude": [],
                 "generated": [], "c1_safety": False, "c2": "lean"}
OPT_IN_CAPS = ("max_line_chars",)   # caps that are off (no key in "caps") until `.check` has their line; a gate enforces them
STRICT = "strict"                   # the value of "c1_safety" for `code-c1-safety: strict` (False = off, True = on)
AUDIT_DEFAULTS = {"every_days": 14, "every_commits": 300, "start_read": [], "ignore": [], "duplicate_ignore": [],
                  "third_party": [], "instructions": [],
                  "budgets": {"session_load_tokens": 5500, "session_load_warn_tokens": 5000, "rules_file_lines": 200,
                              "third_party_tokens": 1500,
                              "handoff_lines": 40, "file_kb": 500, "duplicate_lines": 20, "rules": 28,
                              "project_rules": 15}}
# The PFM's caps for every repo (2026-11-18; third_party_tokens 2026-11-20; session load 5,500, warning 5,000: 2026-11-21): a project can lower one, never raise it.
KIT_CAPS = ("session_load_tokens", "session_load_warn_tokens", "rules_file_lines", "third_party_tokens")
CODE_LISTS = ("include", "exclude", "generated")
AUDIT_LISTS = ("ignore", "start_read", "duplicate_ignore", "third_party", "instructions")
SETTING_LINE = re.compile(r"(?i)^((?:code|audit)-[A-Za-z0-9_-]+)\s*:\s*(.*)$")
# A line that was meant as a setting: a known key written with `_`, with `=` in place of `:`, or with no colon.
# An allowed string that only starts with those letters ("code-name Bluebird", "code-included in price") is not one.
_KEY = (r"(?:code[-_](?:max[-_]file[-_]lines|max[-_]function[-_]lines|max[-_]line[-_]chars|include|exclude|generated|c1[-_]safety|c2)"
        r"|audit[-_](?:every[-_]days|every[-_]commits|ignore|duplicate[-_]ignore|start[-_]read|budget[-_][a-z_]+))")
LOOKS_LIKE_SETTING = re.compile(r"(?i)^" + _KEY + r"(?:\s*[:=]|\s+\S)")
# A docs/DECISIONS.md row "names .check" with the file name itself, not .check.lock or .check.state.json.
NAMES_CHECK = re.compile(r"(?<![\w.])\.check(?!\.(?:lock|state)|\w)")
STATE_PARTS = ("code_standard", "audit", "timings")
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
    "# An allowed string or a skip line is added only on the PFM's request, never by an agent to get past a block"
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
    '# Only the PFM adds entries. Agents never add one to get past a block (AGENTS.md "Personal data").',
    '# Only the PFM adds an allowed string or a skip line. Agents never add one to get past a block (AGENTS.md'
    ' "Personal data").',
    "# An allowed string or a skip line is added only on the PFM's request, never by an agent to get past a block"
    ' (AGENTS.md "Personal data").',
))


def read(root, name, ref=None):
    """The bytes of a top-level file in the working tree, or at a git ref; None when it does not exist there."""
    if ref:
        r = subprocess.run(["git", "-C", str(root), "show", f"{ref}:{name}"], capture_output=True)
        return r.stdout if r.returncode == 0 else None
    p = Path(root) / name
    return p.read_bytes() if p.is_file() else None


def pairs(data):
    """[(key, value)] of the `code-` and `audit-` lines in the bytes of a .check file (None: no file), in file
    order. Comments and invisible characters are dropped the way the content check drops them.
    Args:
        data: the bytes of a .check file, or None.
    Returns:
        A list of (key, value).
    """
    if data is None:
        return []
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise ValueError(f"{CHECK} is not UTF-8 text: save it as UTF-8") from None
    out = []
    for raw in text.splitlines():
        line = "".join(c for c in raw if unicodedata.category(c) != "Cf")
        body = re.split(r"(?:^|\s)#", line, maxsplit=1)[0].strip()
        m = SETTING_LINE.match(body)
        if m:
            out.append((m.group(1), m.group(2).strip()))
        elif LOOKS_LIKE_SETTING.match(body):  # code_exclude: x, code-exclude x, code-max-file-lines = 5
            raise ValueError(f"{CHECK}: `{body[:60]}` looks like a setting but is not `code-<key>: <value>` or "
                             "`audit-<key>: <value>` (the keys: the header of scripts/check_settings.py)")
    return out


def collect(found, prefix, single, multi):
    """{key: value, or [values] for a key in multi} of the pairs whose key starts with prefix. ValueError for an
    unknown key (also a known key in capitals), a key with no value, and a single key on two lines.
    Args:
        found: the (key, value) pairs.
        prefix: "code-" or "audit-".
        single: the keys that may be on one line only.
        multi: the keys that may be on several lines.
    Returns:
        A dict {key: value or list of values}.
    """
    out = {}
    for key, value in found:
        if not key.lower().startswith(prefix):
            continue
        if key not in single and key not in multi:
            raise ValueError(f"{CHECK}: unknown setting `{key}:` (the keys: the header of scripts/check_settings.py)")
        if not value:
            raise ValueError(f"{CHECK}: `{key}:` has no value")
        if key in multi:
            out.setdefault(key, []).append(value)
        elif key in out:
            raise ValueError(f"{CHECK}: `{key}:` is on two lines; keep one")
        else:
            out[key] = value
    return out


def number(key, value, least):
    """The whole number of a setting line; ValueError when it is not one, or is under `least`."""
    if not re.fullmatch(r"[0-9]{1,9}", value) or int(value) < least:
        raise ValueError(f"{CHECK}: `{key}: {value}` is not valid: use a whole number of {least} or more")
    return int(value)


def choice(key, value, options):
    """The value of a setting line that takes one of a few words; ValueError for any other word."""
    if value not in options:
        raise ValueError(f"{CHECK}: `{key}: {value}` is not valid: use {' or '.join(options)}")
    return value


def dash(name):
    """The key form of a settings name: max_file_lines -> max-file-lines."""
    return name.replace("_", "-")


def not_migrated(root, name):
    """ValueError when the working tree still has an old settings file: its limits must not be dropped in silence."""
    if (Path(root) / name).is_file():
        raise ValueError(f"{name} is the old layout: run `{MIGRATE}` (it moves the settings into {CHECK} and the "
                         f"state into {STATE})")


def code_settings(found):
    """The code standard settings from setting pairs: {"caps": {...}, "include": [...], "exclude": [...],
    "generated": [...], "c1_safety": False|True|"strict", "c2": "lean"|"full"}. An opt-in cap (OPT_IN_CAPS) is in
    "caps" only when its line is there. Lists are sorted, so two equal settings compare equal. ValueError for a line
    that is not valid.
    Args:
        found: the (key, value) pairs.
    Returns:
        The settings dict.
    """
    caps = tuple(CODE_DEFAULTS["caps"]) + OPT_IN_CAPS
    got = collect(found, "code-", ["code-" + dash(c) for c in caps] + ["code-c1-safety", "code-c2"],
                  ["code-" + n for n in CODE_LISTS])
    cfg = json.loads(json.dumps(CODE_DEFAULTS))
    for cap in caps:
        if "code-" + dash(cap) in got:
            cfg["caps"][cap] = number("code-" + dash(cap), got["code-" + dash(cap)], 1)
    for name in CODE_LISTS:
        if "code-" + name in got:
            cfg[name] = sorted(set(got["code-" + name]))
    safety = choice("code-c1-safety", got.get("code-c1-safety", "off"), ("on", "off", STRICT))
    cfg["c1_safety"] = STRICT if safety == STRICT else safety == "on"
    cfg["c2"] = choice("code-c2", got.get("code-c2", "lean"), ("full", "lean"))
    return cfg


def code_config(root, ref=None):
    """The code standard settings of `.check` in the working tree, or at a git ref (shape: code_settings)."""
    if ref is None:
        not_migrated(root, OLD_CODE)
    return code_settings(pairs(read(root, CHECK, ref)))


def code_from_old(old, dropped=None):
    """The settings dict (the shape of code_config) of the "config" of an old .code-standard.json. A key or a cap
    that this layout does not have is left out. A "c1_safety" level of 2 or more (the old strict form) is "strict".
    Args:
        old: the "config" object of the old file.
        dropped: a list that gets (key, value, reason) for each key that is left out; None = not wanted.
    Returns:
        The settings dict.
    """
    dropped = [] if dropped is None else dropped
    cfg = json.loads(json.dumps(CODE_DEFAULTS))
    for cap, value in old.get("caps", {}).items():
        if cap in cfg["caps"] or cap in OPT_IN_CAPS:
            cfg["caps"][cap] = value
        else:
            dropped.append(("caps." + cap, value, "the code standard has no such cap"))
    for name in CODE_LISTS:
        if name in old:
            cfg[name] = sorted(set(old[name]))
    level = old.get("c1_safety")
    cfg["c1_safety"] = STRICT if level == STRICT or (type(level) is int and level >= 2) else bool(level)
    cfg["c2"] = "full" if old.get("c2") == "full" else "lean"
    known = ("caps", "c1_safety", "c2") + CODE_LISTS
    dropped += [(k, old[k], "the code standard has no such setting") for k in sorted(old) if k not in known]
    return cfg


def code_base(root, ref):
    """(settings, debt) of the code standard at a git ref, or None when that commit has no baseline. Transition: a
    commit with no code standard part in `.check.state.json` but with the old .code-standard.json is read from that
    file, so the first change after a migration is still compared with what main had.
    Args:
        root: the repo root (a folder path).
        ref: the git ref (a commit).
    Returns:
        (settings, debt), or None.
    """
    part = load_state(root, ref).get("code_standard")
    if part is not None:
        return code_config(root, ref), part.get("debt", {})
    old = read(root, OLD_CODE, ref)
    if old is None:
        return None
    data = json.loads(old)
    return code_from_old(data.get("config", {})), data.get("debt", {})


def audit_settings(found):
    """The audit settings from setting pairs: AUDIT_DEFAULTS with each `audit-` line applied. ValueError for a line
    that is not valid, and for a KIT_CAPS budget set above the kit's value.
    Args:
        found: the (key, value) pairs.
    Returns:
        The settings dict.
    """
    budgets = AUDIT_DEFAULTS["budgets"]
    single = ["audit-every-days", "audit-every-commits"] + ["audit-budget-" + b for b in budgets]
    got = collect(found, "audit-", single, ["audit-" + dash(n) for n in AUDIT_LISTS])
    cfg = json.loads(json.dumps(AUDIT_DEFAULTS))
    for name in ("every_days", "every_commits"):
        if "audit-" + dash(name) in got:
            cfg[name] = number("audit-" + dash(name), got["audit-" + dash(name)], 1)
    for name in budgets:
        key = "audit-budget-" + name
        if key in got:
            cfg["budgets"][name] = number(key, got[key], 0)
            if name in KIT_CAPS and cfg["budgets"][name] > budgets[name]:
                raise ValueError(f"{CHECK}: `{key}: {got[key]}` is not valid: this is a kit cap, a project can lower "
                                 f"it, never raise it (at most {budgets[name]})")
    for name in AUDIT_LISTS:
        cfg[name] = got.get("audit-" + dash(name), [])
    return cfg


def audit_config(root):
    """What scripts/bloat_check.py works with: the audit settings of `.check`, plus "last_audit" and "timings" from
    `.check.state.json`. ValueError when a file cannot be read or a line is not valid."""
    not_migrated(root, OLD_AUDIT)
    cfg = audit_settings(pairs(read(root, CHECK)))
    state = load_state(root)
    cfg["last_audit"] = state.get("audit", {}).get("last_audit")
    cfg["timings"] = state.get("timings", {})
    return cfg


def audit_from_old(old, dropped=None):
    """The audit settings dict of an old .bloat-audit.json. Left out: a budget or a top-level key that this layout
    does not have, and a KIT_CAPS budget above the kit's value (the kit's value applies; a lower one is kept).
    Args:
        old: the object in the old file.
        dropped: a list that gets (key, value, reason) for each key that is left out; None = not wanted.
    Returns:
        The settings dict.
    """
    dropped = [] if dropped is None else dropped
    cfg = json.loads(json.dumps(AUDIT_DEFAULTS))
    for name in ("every_days", "every_commits") + AUDIT_LISTS:
        if name in old:
            cfg[name] = old[name]
    for name, value in old.get("budgets", {}).items():
        kit = AUDIT_DEFAULTS["budgets"].get(name)
        if kit is None:
            dropped.append(("budgets." + name, value, "the audit has no such budget (the kit's caps are "
                            + ", ".join(KIT_CAPS) + ")"))
        elif name in KIT_CAPS and isinstance(value, (int, float)) and value > kit:
            dropped.append(("budgets." + name, value, f"a kit cap cannot be raised: the kit's value {kit} applies"))
        else:
            cfg["budgets"][name] = value
    known = tuple(AUDIT_DEFAULTS) + ("last_audit", "timings")
    dropped += [(k, old[k], "the audit has no such setting") for k in sorted(old) if k not in known]
    return cfg


def load_state(root, ref=None):
    """The dict in `.check.state.json` (working tree, or at a git ref); {} when the file does not exist.
    ValueError when it is not JSON, not an object, or one of its parts is not an object.
    Args:
        root: the repo root (a folder path).
        ref: a git ref to read the file from; None = the working tree.
    Returns:
        The state dict.
    """
    data = read(root, STATE, ref)
    if data is None:
        return {}
    try:
        state = json.loads(data.decode("utf-8"))
    except ValueError as e:
        raise ValueError(f"{STATE} is not JSON ({e})") from None
    if not isinstance(state, dict) or any(not isinstance(state.get(p, {}), dict) for p in STATE_PARTS):
        raise ValueError(f"{STATE}: the top level and each of its parts must be an object")
    return state


def state_text(state):
    """The file text of a state dict: sorted keys and indent 1, so the same state gives the same bytes."""
    return json.dumps(state, indent=1, sort_keys=True) + "\n"


def save_part(root, part, value):
    """Write one part ("code_standard", "audit" or "timings") into `.check.state.json`; the file is read again
    first, so the parts of the other tools stay as they are."""
    state = load_state(root)
    state[part] = value
    (Path(root) / STATE).write_text(state_text(state), encoding="utf-8")


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
    own = [l for l in lines[:end] if l.rstrip(b"\r").decode("utf-8", "replace") not in OLD_HEADER_LINES]
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


def main():
    """Parse the options and run the chosen mode; return its exit code.
    Returns:
        The exit code: 0 pass, 1 fail.
    """
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0], allow_abbrev=False)
    ap.add_argument("--migrate", action="store_true", help="move the old settings files into .check and .check.state.json")
    ap.add_argument("--test", action="store_true", help="self-test in temporary repos")
    args = ap.parse_args()
    if args.test:
        import check_settings_test   # scripts/check_settings_test.py: kept apart (docs/code-standard.md C4)
        return check_settings_test.run()
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    root = Path(top.stdout.strip() if top.returncode == 0 else ".")
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
