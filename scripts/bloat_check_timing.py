#!/usr/bin/env python3
"""The timings of the bloat check: run the timed commands of .check.state.json and compare measured times with their
baselines (the "timings" part of scripts/bloat_check.py).

Part of scripts/bloat_check.py (split out to keep each file under the line cap of docs/code-standard.md C4);
bloat_check.py imports every name here and re-exports it, so `bloat_check.<name>` keeps working.
A slowdown is reported, never a failure (the Maintainer, 2026-11-16).
Prevents: a repeated process that gets slower, step by step, with nobody noticing (an unmeasured slowdown).
Inputs:  the audit settings with "timings" (scripts/check_settings.py), the timed commands, and measured seconds.
Outputs: report rows and one TIME or WARN line; save_timings writes the "timings" part of .check.state.json.
Usage:   imported by scripts/bloat_check.py (--time, --compare); it has no command line.
Network: none.
Writes: .check.state.json ("timings" only, through scripts/check_settings.py), only when asked to record.
Credentials: none.
"""
import shlex
import subprocess
import time

import check_settings  # scripts/check_settings.py: STATE and save_part (the state file)

STATE = check_settings.STATE


TIMING_DIRS = ("scripts/", "tests/")  # a timed command runs a file of the repo, from one of these folders
SHELL_CHARS = set(";|&`$()<>\n")


def timing_argv(cmd):
    """The argument list of a timed command (no shell, CWE-78): [python3|bash] <scripts/ or tests/ path> [args].

    ValueError for a shell character, another program, an absolute path or "..".
    """
    argv = shlex.split(cmd) if not SHELL_CHARS & set(cmd) else []
    path = argv[1] if argv[:1] in (["python3"], ["bash"]) and len(argv) > 1 else (argv[0] if argv else "")
    if not path.startswith(TIMING_DIRS) or ".." in path.split("/"):
        raise ValueError(f"timed command not allowed (shell character, or not a scripts/ or tests/ file): {cmd!r}")
    return argv


def run_timings(root, cfg, record):
    """Run each timed command that has a cmd; return (report rows, names slower or failed); record stores the new seconds.

    Args:
        root: the repo root (a Path).
        cfg: the audit settings, with "timings".
        record: True to store the new seconds in cfg.

    Returns:
        (report rows, names of the commands that were slower or failed).
    """
    rows, slow = [], []
    for name, t in cfg.get("timings", {}).items():
        if not t.get("cmd"):
            continue  # measured by the script that runs it (--compare)
        t0 = time.monotonic()
        rc = subprocess.run(timing_argv(t["cmd"]), cwd=root, capture_output=True).returncode
        secs = round(time.monotonic() - t0, 1)
        base = t.get("seconds")
        limit = t.get("max_slowdown", 0.25)
        verdict = "FAILED" if rc else "new" if base is None else ("SLOWER" if secs > base * (1 + limit) else "ok")
        if verdict in ("SLOWER", "FAILED"):
            slow.append(name)
        rows.append(f"  {name}: {secs} s (baseline {base or '-'} s, limit +{int(limit * 100)}%, exit {rc}) {verdict}")
        if record and not rc:
            t["seconds"] = secs
    return rows, slow


def compare_times(cfg, pairs, record=False):
    """pairs: [(name, seconds)]; name is a timings key, or "key:step" for one of its "steps". Returns (line, slow).
    Warn only: a slowdown is reported, never a failure (the Maintainer, 2026-11-16).

    Args:
        cfg: the audit settings, with "timings"; record changes it in place.
        pairs: the (name, seconds) pairs that a script measured.
        record: True to store the seconds as the new baselines.

    Returns:
        (one TIME or WARN line, the texts of the slower ones).
    """
    timings = cfg.setdefault("timings", {})
    slow, new, n = [], [], 0
    for name, secs in pairs:
        key, _, step = name.partition(":")
        entry = timings.setdefault(key, {}) if record else timings.get(key, {})
        base = entry.get("steps", {}).get(step) if step else entry.get("seconds")
        limit = entry.get("max_slowdown", 0.25)
        floor = entry.get("min_slowdown_seconds", 0.5)
        if base is None:
            new.append(name)
        elif secs > base * (1 + limit) and secs - base >= floor:
            slow.append(f"{step or key} {secs} s (baseline {base} s, +{round((secs / base - 1) * 100) if base else 999}%)")
        n += 1
        if record:
            if step:
                entry.setdefault("steps", {})[step] = secs
            else:
                entry["seconds"] = secs
    if record:
        return f"TIME  baseline recorded for {n} time(s) in {STATE}", []
    if slow:
        return ("WARN  slower than the baseline: " + "; ".join(slow) +
                ". Next: .claude/skills/audit/SKILL.md, A slow run (a measured slowdown starts it)"), slow
    tail = f"; no baseline yet for {len(new)} ({', '.join(new)}): .claude/skills/audit/SKILL.md, Record a baseline" if new else ""
    return f"TIME  baseline: {n - len(new)} of {n} within the limit{tail}", []


def save_timings(root, timings):
    """Write timings into .check.state.json and keep its other parts."""
    check_settings.save_part(root, "timings", timings)
