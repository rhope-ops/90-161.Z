#!/usr/bin/env python3
"""Failure cases of the RADE engine download (scripts/build_paste_bundles.py). Fake files only; no network.
Prints one line per case; exit 0 = all pass. Run by tests/run.sh."""
import hashlib, importlib.util, io, json, os, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHIM = ROOT / 'scripts/build_paste_bundles.py'
spec = importlib.util.spec_from_file_location('shim', SHIM); shim = importlib.util.module_from_spec(spec); spec.loader.exec_module(shim)

GOOD = {'engine/rade_build.py': b'print("fake engine")\n', 'assets/logo/logo.png': b'\x89PNG fake'}
LOCK = {'repo': 'example-org/engine', 'commit': 'c' * 40, 'serial': 1, 'engine': 'engine/rade_build.py',
        'files': {k: hashlib.sha256(v).hexdigest() for k, v in GOOD.items()}}
fails = 0


def check(name, cond, detail=''):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name + ('' if cond else ' ' + str(detail)))
    fails += 0 if cond else 1


def opener(files, calls):
    def op(url, timeout=None):
        calls.append(url)
        rel = url.split('c' * 40 + '/', 1)[1]
        return io.BytesIO(files[rel])
    return op


def offline(url, timeout=None):
    raise OSError('network is unreachable (test)')


def stopped(fn):
    try:
        fn()
    except SystemExit as e:
        return str(e.code)
    return None


def files_in(d):
    return sorted(str(p.relative_to(d)) for p in Path(d).rglob('*') if p.is_file())


tmp = Path(tempfile.mkdtemp(prefix='radefetch'))
try:
    # 1. No network and an empty cache: a clear message, nothing in the cache.
    c = tmp / 'c1'
    msg = stopped(lambda: shim.fetch(LOCK, c, offline))
    check('offline + empty cache stops with a clear message', msg and msg.startswith('FAIL cannot download') and 'No bundle was written' in msg, msg)
    check('offline + empty cache leaves no file', files_in(c) == [], files_in(c))

    # 1b. The same through the real command line: exit not 0 and no bundle written.
    app = tmp / 'app'; (app / 'scripts').mkdir(parents=True)
    shutil.copy(SHIM, app / 'scripts'); (app / 'scripts/rade.lock.json').write_text(json.dumps(LOCK))
    env = {k: v for k, v in os.environ.items() if k.upper() not in ('RADE_DIR', 'NO_PROXY')}
    env.update(https_proxy='http://127.0.0.1:9', HTTPS_PROXY='http://127.0.0.1:9')
    r = subprocess.run([sys.executable, '-B', str(app / 'scripts/build_paste_bundles.py')], env=env, capture_output=True, text=True)
    check('command line offline: exit not 0, message, no bundle, no cache file',
          r.returncode != 0 and 'FAIL cannot download' in r.stderr and files_in(app) == ['scripts/build_paste_bundles.py', 'scripts/rade.lock.json'],
          (r.returncode, r.stderr[-300:], files_in(app)))

    # 2. A wrong hash: stop, and the bad file (and its temporary file) is gone; the good file before it stays.
    c = tmp / 'c2'; calls = []
    bad = dict(GOOD); bad['assets/logo/logo.png'] = b'tampered'
    msg = stopped(lambda: shim.fetch(LOCK, c, opener(bad, calls)))
    check('wrong hash stops', msg and 'the lock wants' in msg and 'deleted' in msg, msg)
    check('wrong hash: bad file deleted', files_in(c) == ['c' * 40 + '/engine/rade_build.py'], files_in(c))

    # 3. A good download, then no second download.
    c = tmp / 'c3'; calls = []
    home = shim.fetch(LOCK, c, opener(GOOD, calls))
    check('good download: 2 files, hashes match', len(calls) == 2 and all(shim.sha256(home / k) == v for k, v in LOCK['files'].items()), calls)
    before = {k: (home / k).stat().st_mtime_ns for k in GOOD}
    again = stopped(lambda: shim.fetch(LOCK, c, offline))
    check('full cache needs no network and stays unchanged', again is None and before == {k: (home / k).stat().st_mtime_ns for k in GOOD}, again)

    # 4. A cache file changed after download: found on the next build, replaced when online, deleted and stopped when offline.
    (home / 'engine/rade_build.py').write_bytes(b'print("changed")\n'); calls = []
    shim.fetch(LOCK, c, opener(GOOD, calls))
    check('changed cache file: found and downloaded again', len(calls) == 1 and shim.sha256(home / 'engine/rade_build.py') == LOCK['files']['engine/rade_build.py'], calls)
    (home / 'engine/rade_build.py').write_bytes(b'print("changed")\n')
    msg = stopped(lambda: shim.fetch(LOCK, c, offline))
    check('changed cache file offline: stop, changed file deleted', msg and msg.startswith('FAIL cannot download') and not (home / 'engine/rade_build.py').exists(), msg)

    # 5. A lock path that leaves the cache is refused.
    evil = dict(LOCK, files=dict({'../x': 'a' * 64}, **LOCK['files']))
    msg = stopped(lambda: shim.fetch(evil, tmp / 'c5', opener(GOOD, [])))
    check('lock path outside the cache is refused', msg and 'bad file path' in msg and not (tmp / 'x').exists(), msg)

    msg = stopped(lambda: shim.fetch(dict(LOCK, engine='engine/other.py'), tmp / 'c5', opener(GOOD, [])))
    check('engine file without a hash in the lock is refused', msg and 'has no SHA-256' in msg, msg)

    # 6. RADE_DIR override: a warning, and the lock is not used.
    over = tmp / 'over'; (over / 'engine').mkdir(parents=True); (over / 'engine/rade_build.py').write_text('print("override engine ran")\n')
    env2 = dict(env, RADE_DIR=str(over))
    r = subprocess.run([sys.executable, '-B', str(app / 'scripts/build_paste_bundles.py')], env=env2, capture_output=True, text=True)
    check('RADE_DIR: warning printed, override engine runs', r.returncode == 0 and 'WARNING RADE_DIR is set' in r.stderr and 'override engine ran' in r.stdout, (r.returncode, r.stderr[-300:]))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print('RADEFETCH fails=%d' % fails)
sys.exit(1 if fails else 0)
