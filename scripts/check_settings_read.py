#!/usr/bin/env python3
"""The reader of the `code-` and `audit-` lines of `.check`, and the reader and writer of `.check.state.json`: the
keys, their defaults and the checks of each value.

Part of scripts/check_settings.py (split out to keep each file under the line cap of docs/code-standard.md C4);
check_settings.py imports every name here and re-exports it, so `check_settings.<name>` keeps working. The keys and
their defaults are listed in the header of scripts/check_settings.py.
Inputs:  `.check` and `.check.state.json` in the working tree or at a git ref (`git show <ref>:<file>`).
Outputs: settings as dicts; `.check.state.json` on a write (save_part).
Usage:   imported by scripts/check_settings.py; it has no command line.
Network: none (it runs local git read commands).
Writes: .check.state.json, only through save_part.
Credentials: none.
"""
import json
import re
import subprocess
import unicodedata
from pathlib import Path


CHECK = ".check"
STATE = ".check.state.json"
OLD_CODE = ".code-standard.json"   # before 2026-11-18: the code standard's caps, scope and debt list
OLD_AUDIT = ".bloat-audit.json"    # before 2026-11-18: the audit's settings, last audit and time baselines
OLD_CHECK = ".pii-guard"           # before 2026-11-18: the name of .check
MIGRATE = "python3 scripts/check_settings.py --migrate"
# max_file_lines: 450 for hand-written code; max_file_lines_paste: the C4 cap of a script a person pastes into another
# tool (the `code-paste:` files), where one file is one paste, so it keeps the older cap of 600 (the Maintainer, 2026-11-23:
# docs/reviews/2026-11-23-fleet-v2-plan.md, decision 6).
CODE_DEFAULTS = {"caps": {"max_file_lines": 450, "max_function_lines": 60, "max_file_lines_paste": 600}, "include": ["*"],
                 "exclude": [], "generated": [], "paste": [], "c1_safety": False, "c2": "lean", "strict_gate": False}
OPT_IN_CAPS = ("max_line_chars",)   # caps that are off (no key in "caps") until `.check` has their line; a gate enforces them
STRICT = "strict"                   # the value of "c1_safety" for `code-c1-safety: strict` (False = off, True = on)
AUDIT_DEFAULTS = {"every_days": 14, "every_commits": 300, "start_read": [], "ignore": [], "duplicate_ignore": [],
                  "third_party": [], "instructions": [],
                  "budgets": {"session_load_tokens": 5500, "session_load_warn_tokens": 5000, "rules_file_lines": 200,
                              "third_party_tokens": 1500,
                              "handoff_lines": 40, "file_kb": 500, "duplicate_lines": 20, "rules": 28,
                              "project_rules": 15}}
# The Maintainer's caps for every repo (2026-11-18; third_party_tokens 2026-11-20; session load 5,500, warning 5,000: 2026-11-21): a project can lower one, never raise it.
KIT_CAPS = ("session_load_tokens", "session_load_warn_tokens", "rules_file_lines", "third_party_tokens")
CODE_LISTS = ("include", "exclude", "generated", "paste")
AUDIT_LISTS = ("ignore", "start_read", "duplicate_ignore", "third_party", "instructions")
SETTING_LINE = re.compile(r"(?i)^((?:code|audit)-[A-Za-z0-9_-]+)\s*:\s*(.*)$")
# A line that was meant as a setting: a known key written with `_`, with `=` in place of `:`, or with no colon.
# An allowed string that only starts with those letters ("code-name Bluebird", "code-included in price") is not one.
_KEY = (r"(?:code[-_](?:max[-_]file[-_]lines(?:[-_]paste)?|max[-_]function[-_]lines|max[-_]line[-_]chars|include|exclude|generated"
        r"|paste|c1[-_]safety|c2|strict[-_]gate)"
        r"|audit[-_](?:every[-_]days|every[-_]commits|ignore|duplicate[-_]ignore|start[-_]read|budget[-_][a-z_]+))")
LOOKS_LIKE_SETTING = re.compile(r"(?i)^" + _KEY + r"(?:\s*[:=]|\s+\S)")
# A docs/DECISIONS.md row "names .check" with the file name itself, not .check.lock or .check.state.json.
NAMES_CHECK = re.compile(r"(?<![\w.])\.check(?!\.(?:lock|state)|\w)")
STATE_PARTS = ("code_standard", "audit", "timings")



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
    "generated": [...], "paste": [...], "c1_safety": False|True|"strict", "c2": "lean"|"full",
    "strict_gate": False|True}. An opt-in cap
    (OPT_IN_CAPS) is in
    "caps" only when its line is there. Lists are sorted, so two equal settings compare equal. ValueError for a line
    that is not valid.
    Args:
        found: the (key, value) pairs.
    Returns:
        The settings dict.
    """
    caps = tuple(CODE_DEFAULTS["caps"]) + OPT_IN_CAPS
    got = collect(found, "code-", ["code-" + dash(c) for c in caps] + ["code-c1-safety", "code-c2", "code-strict-gate"],
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
    cfg["strict_gate"] = choice("code-strict-gate", got.get("code-strict-gate", "off"), ("on", "off")) == "on"
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
