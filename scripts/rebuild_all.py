#!/usr/bin/env python3
"""Rebuild, or check, every generated file of this repository in dependency order (fleet v2 Stage 3A, 2026-11-23).

Why: generated files feed other generated files (a task-script block goes into a round bundle; a flow definition goes
into a flow package). One command that runs every generator in the right order proves that nothing is stale.
Who runs it: a maintainer after a source change, and the fleet v2 gate (`--check`). tests/run.sh keeps its own
per-generator checks.

Usage:
    python3 scripts/rebuild_all.py --check   run each generator's check in dependency order; exit 1 when any is stale
    python3 scripts/rebuild_all.py           run each generator's write in dependency order (then check them all)
    python3 scripts/rebuild_all.py --list    print the order and the commands, run nothing
    python3 scripts/rebuild_all.py --test    self-test: the order keeps every dependency, and every scripts/build_* file
                                             is in the graph or in NOT_GENERATED (with its reason)
Network: the round-bundle generator reads the pinned RADE engine (cached in .rade-cache; a first run downloads it once).
Writes: with no flag, the generated files of each generator; with --check, --list or --test, nothing in the repo.
Credentials: none.
"""
import graphlib
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PY = sys.executable

# name: (write command, check command, names it depends on). A dependency writes a file that the generator reads.
GRAPH = {
    'messy_draft': ([PY, 'scripts/build_messy_draft.py'], [PY, 'scripts/build_messy_draft.py', '--check'], []),
    'test_seals': ([PY, 'scripts/build_test_seals.py'], [PY, 'scripts/build_test_seals.py', '--check'], []),
    'flow_payload': ([PY, 'scripts/build_flow_payload.py'], [PY, 'scripts/build_flow_payload.py', '--check'], []),
    'rights_probe': ([PY, 'scripts/build_rights_probe.py'], [PY, 'scripts/build_rights_probe.py', '--check'], []),
    'rights_rows': ([PY, 'scripts/build_rights_rows.py'], [PY, 'scripts/build_rights_rows.py', '--check'], []),
    # flow packages hold the flow definitions (rights probe) and the payload JSON (build_flow_package.py header).
    'flow_package': ([PY, 'scripts/build_flow_package.py'], [PY, 'scripts/build_flow_package.py', '--check'],
                     ['flow_payload', 'rights_probe']),
    'flow_solution': ([PY, 'scripts/build_flow_solution.py'], [PY, 'scripts/build_flow_solution.py', '--check'],
                      ['flow_package', 'flow_payload']),
    'probe_samples': ([PY, 'scripts/build_probe_samples.py'], [PY, 'scripts/build_probe_samples.py', '--check'], []),
    # Task scripts get the shared blocks after the generators that write other blocks into them.
    'task_scripts': ([PY, 'scripts/build_task_scripts.py'], [PY, 'scripts/build_task_scripts.py', '--check'],
                     ['probe_samples', 'rights_rows']),
    # Round bundles embed the task scripts and samples; the build also rewrites the README task part (build_readme.py) at its end.
    'paste_bundles': ([PY, 'scripts/build_paste_bundles.py'], [PY, 'scripts/build_paste_bundles.py', '--check'],
                      ['task_scripts', 'messy_draft', 'test_seals', 'flow_package', 'flow_solution']),
    'readme_tasks': ([PY, 'scripts/build_readme.py'], [PY, 'scripts/build_readme.py', '--check'], ['paste_bundles']),
    'site': ([PY, 'scripts/build_site.py', '--write'], [PY, 'scripts/build_site.py', '--check'], []),
    'go_page': ([PY, 'scripts/build_go_page.py'], [PY, 'scripts/build_go_page.py', '--check'], ['site']),
}

# scripts/build_* files that write no committed file, with the reason (the --test keeps this list honest).
NOT_GENERATED = {
    'build_list_mockup.py': 'writes the list mockup page to a temp path; it is published as an artifact, not committed',
    'build_decision_brief.js': 'writes a decision brief page outside the repo (an artifact)',
    'build_flow_solution_xml.py': 'module that scripts/build_flow_solution.py imports; not a generator of its own',
    'build_site_html.py': 'HTML helpers that scripts/build_site.py imports (a kit file); not a generator of its own',
}


def order():
    """Return the generator names in dependency order (each name after every name it depends on)."""
    return list(graphlib.TopologicalSorter({n: set(d) for n, (_, _, d) in GRAPH.items()}).static_order())


def write_cmd(name):
    """Return the write command of a generator."""
    return GRAPH[name][0]


def run(cmd):
    """Run one generator command in the repository root. Takes the argument list; returns (exit code, last output line)."""
    env = dict(os.environ)
    env.pop('RADE_DIR', None)   # always the pinned engine (tests/run.sh does the same)
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=env)
    lines = [x for x in (p.stdout + p.stderr).splitlines() if x.strip()]
    return p.returncode, (lines[-1] if lines else '')[:200]


def main(mode):
    """Run every generator in order, then print the REBUILD line.

    Args:
        mode: 'check' (each generator's check) or 'write' (each generator's write, then a full check).

    Returns:
        The exit code: 1 when any step fails, else 0.
    """
    bad = []
    for name in order():
        cmd = GRAPH[name][1] if mode == 'check' else write_cmd(name)
        code, last = run(cmd)
        print('%s %s: %s' % ('ok  ' if code == 0 else 'FAIL', name, last))
        if code:
            bad.append(name)
    if mode == 'write' and not bad:
        return main('check')
    print('REBUILD %s steps=%d fail=%d%s' % (mode.upper(), len(GRAPH), len(bad), (' (' + ', '.join(bad) + ')') if bad else ''))
    return 1 if bad else 0


def self_test():
    """Check the graph: every dependency comes first, every command names a file that exists, every build_* file is known.

    Returns: 0 when all pass, else 1 (the REBUILD TEST line is printed).
    """
    fails = []
    pos = {n: i for i, n in enumerate(order())}
    for n, (w, c, deps) in GRAPH.items():
        fails += ['%s before %s' % (d, n) for d in deps if d not in GRAPH or pos[d] > pos[n]]
        fails += ['%s: no %s' % (n, a) for a in (w[1], c[1]) if not (ROOT / a).is_file()]
    used = {Path(w[1]).name for w, _, _ in GRAPH.values()}
    for f in sorted((ROOT / 'scripts').glob('build_*')):
        if f.suffix in ('.py', '.js') and f.name not in used and f.name not in NOT_GENERATED:
            fails.append('%s is not in GRAPH or NOT_GENERATED' % f.name)
    fails += ['NOT_GENERATED %s does not exist' % n for n in NOT_GENERATED if not (ROOT / 'scripts' / n).is_file()]
    for f in fails:
        print('FAIL ' + f)
    print('REBUILD TEST cases=%d fails=%d' % (len(GRAPH) * 3 + 2, len(fails)))
    return 1 if fails else 0


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['--test']:
        sys.exit(self_test())
    if args == ['--list']:
        for n in order():
            print('%-14s write: %s | check: %s' % (n, ' '.join(GRAPH[n][0][1:]), ' '.join(GRAPH[n][1][1:])))
        sys.exit(0)
    if args not in ([], ['--check']):
        sys.exit(__doc__)
    sys.exit(main('check' if args == ['--check'] else 'write'))
