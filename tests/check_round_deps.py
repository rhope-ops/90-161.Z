#!/usr/bin/env python3
"""Round step dependencies (R44 T1; R43 finding 1: one missing hand value skipped 13 steps).

The second person is optional (the PFM, 2026-11-25: "Optional, no skips"). Only the 2 endorser answer steps may need the
step "T21 Add the second person": "Second person answers" and "Read the endorser answer". Every other step must not reach it
through its "after" chain, so a round without that person still runs the fake publication, Back up, Restore, Uninstall,
the new install and the process step.

Usage: python3 tests/check_round_deps.py    exit 0 = pass (last line ROUNDDEPS PASS), 1 = a step chains to the person step.
Network: none.
Writes: nothing.
Credentials: none.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PERSON = "T21 Add the second person"            # the start of the step name (the revision follows)
ENDORSER = ("T26 Second person answers", "T26 Read the endorser answer")   # the only steps that may need the person
PERSON_PART = "T21:Person"   # R47: the person is a part of a T30 batch step ("args": "-Run ...;T21:Person")


def is_person(step):
    """Return True when the step adds the second person: its name, or (R47) a T30 batch step with the part T21:Person.

    Args:
        step: a step of the manifest (a dict with "name" and, maybe, "args"), or None.

    Returns:
        True or False.
    """
    return bool(step) and (step["name"].startswith(PERSON) or PERSON_PART in str(step.get("args", "")).split("-Run ", 1)[-1].split(";"))


def closure(step, by_name):
    """Return the names of every step that `step` waits for, directly or through a chain of "after" lists.

    Args:
        step: a step of the manifest (a dict with "name" and, maybe, "after").
        by_name: dict of step name to step.

    Returns:
        A set of step names (not the step itself).
    """
    seen, todo = set(), list(step.get("after", []))
    while todo:
        n = todo.pop()
        if n in seen:
            continue
        seen.add(n)
        todo.extend(by_name[n].get("after", []) if n in by_name else [])
    return seen


def offenders(bundle):
    """Return the names of the steps that chain to the person step and are not an endorser answer step.

    Args:
        bundle: one bundle of the manifest (a dict with "steps").

    Returns:
        A list of step names; empty when the round is right. A name in an "after" list that is not a step is also listed.
    """
    steps = bundle["steps"]
    by_name = {s["name"]: s for s in steps}
    bad = []
    for s in steps:
        for n in s.get("after", []):
            if n not in by_name:
                bad.append(s["name"] + " (after: no step " + n + ")")
        if is_person(s) or s["name"].startswith(ENDORSER):
            continue
        if any(is_person(by_name.get(n)) for n in closure(s, by_name)):
            bad.append(s["name"])
    return bad


def main():
    """Check every bundle of the manifest and print one line for each step that chains to the person step.

    Returns:
        0 when no step chains to the person step except the endorser answer steps, else 1.
    """
    data = json.loads((ROOT / "scripts" / "paste_bundles.json").read_text(encoding="utf-8"))
    fails = 0
    for b in data["bundles"]:
        steps = b["steps"]
        names = [s["name"] for s in steps]
        assert sum(is_person(s) for s in steps) == 1, "the round needs exactly one person step"
        for e in ENDORSER:   # the endorser steps do wait for the person: the test must see them
            hit = [s for s in steps if s["name"].startswith(e)]
            by_name = {s["name"]: s for s in steps}
            assert len(hit) == 1 and any(is_person(by_name.get(n)) for n in closure(hit[0], by_name)), \
                "the endorser step " + e + " must wait for the person step"
        for n in offenders(b):
            print("FAIL " + b["round"] + ": " + n + " waits for the second person")
            fails += 1
    print("ROUNDDEPS " + ("PASS" if not fails else "FAIL (" + str(fails) + " steps)"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
