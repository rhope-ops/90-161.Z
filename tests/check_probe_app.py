#!/usr/bin/env python3
"""Check scripts/gov/90161Z-T21-probe-app-r1.txt (R26 probe app code the PFM pastes).

Checks: ASCII only; blocks 1..6 with matching END markers; each block parses as YAML;
every control has `Control:` and every property value starts with `=`; every BY HAND
formula has balanced brackets and quotes; no address, https:// or .mil.
When tests/fixtures/pa.schema.v3.0.yaml, PyYAML and jsonschema are present, each block
is also validated as the Children of a screen; else a NOTE line is printed.
Exit 0 and print `PROBE APP blocks=6 OK`.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'scripts/gov/90161Z-T21-probe-app-r1.txt'
SCHEMA = ROOT / 'tests/fixtures/pa.schema.v3.0.yaml'
errors = []


def err(msg):
    errors.append(msg)


raw = APP.read_bytes()
try:
    text = raw.decode('ascii')
except UnicodeDecodeError as e:
    print('FAIL file is not ASCII:', e)
    sys.exit(1)
lines = text.splitlines()

# forbidden content
if re.search(r'@[A-Za-z0-9-]+\.[A-Za-z]{2,}', text):
    err('an @ followed by a domain')
if 'https://' in text:
    err('contains https://')
if '.mil' in text.lower():
    err('contains .mil')

# blocks
blocks = {}
for n in range(1, 7):
    starts = [i for i, l in enumerate(lines)
              if re.match(r'=== BLOCK %d: .+ === copy from the next line$' % n, l)]
    ends = [i for i, l in enumerate(lines) if l == '=== END BLOCK %d ===' % n]
    if len(starts) != 1 or len(ends) != 1 or ends[0] <= starts[0]:
        err('block %d: need exactly one start and one later END marker' % n)
        continue
    blocks[n] = '\n'.join(lines[starts[0] + 1:ends[0]]) + '\n'

try:
    import yaml
except ImportError:
    yaml = None
    print('NOTE PyYAML not installed: using the small structure check only')

CTRL_RE = re.compile(r'^([A-Z][a-zA-Z0-9]*/)?[A-Z][a-zA-Z0-9]*(@\d+\.\d+\.\d+)?$')


def parse_small(block):
    """Fallback: list of (name, control, {prop: first value line}) from the fixed layout."""
    out = []
    for l in block.splitlines():
        m = re.match(r'^- (\w+):$', l)
        if m:
            out.append([m.group(1), None, {}])
            continue
        if not out:
            if l.strip():
                err('text before first control: %r' % l)
            continue
        m = re.match(r'^    Control: (\S+)$', l)
        if m:
            out[-1][1] = m.group(1)
            continue
        m = re.match(r'^      (\w+): (.*)$', l)
        if m:
            out[-1][2][m.group(1)] = m.group(2)
        m = re.match(r'^        (=.*)$', l)
        if m:  # first line of a block scalar value
            k = [k for k, v in out[-1][2].items() if v == '|-']
            if k and out[-1][2][k[-1]] == '|-':
                out[-1][2][k[-1]] = m.group(1)
    return [(a, b, c) for a, b, c in out]


def check_controls(n, items):
    if not items:
        err('block %d: no control' % n)
    for name, ctl, props in items:
        if not ctl or not CTRL_RE.match(ctl):
            err('block %d %s: bad or missing Control: %r' % (n, name, ctl))
        if not props:
            err('block %d %s: no Properties' % (n, name))
        for k, v in props.items():
            if not (isinstance(v, str) and v.startswith('=')):
                err('block %d %s.%s: value does not start with =' % (n, name, k))


parsed = {}
for n, b in blocks.items():
    if yaml:
        try:
            data = yaml.safe_load(b)
        except yaml.YAMLError as e:
            err('block %d: YAML does not parse: %s' % (n, str(e).splitlines()[0]))
            continue
        if not isinstance(data, list) or not data:
            err('block %d: not a YAML list' % n)
            continue
        items = []
        for it in data:
            if not isinstance(it, dict) or len(it) != 1:
                err('block %d: list item is not a single control' % n)
                continue
            (name, body), = it.items()
            items.append((name, body.get('Control'), body.get('Properties') or {}))
        parsed[n] = data
        check_controls(n, items)
    else:
        check_controls(n, parse_small(b))

# schema validation (optional)
if yaml and SCHEMA.exists():
    try:
        import jsonschema
    except ImportError:
        jsonschema = None
    if jsonschema:
        schema = yaml.safe_load(SCHEMA.read_text(encoding='ascii'))
        for n, data in parsed.items():
            doc = {'Screens': {'Screen1': {'Children': data}}}
            # no check_schema: the upstream schema holds one invalid regex (CodeComponent-ComponentName)
            for e in jsonschema.Draft7Validator(schema).iter_errors(doc):
                err('block %d: schema: %s' % (n, e.message[:200]))
        print('schema validation ran on %d blocks' % len(parsed))
    else:
        print('NOTE jsonschema not installed: schema validation skipped')
else:
    print('NOTE schema validation skipped (needs PyYAML and tests/fixtures/pa.schema.v3.0.yaml)')

# BY HAND formulas
formulas = re.findall(r'^--- formula for (.+?) ---\n(.*?)\n--- end formula ---$', text, re.M | re.S)
opens = len(re.findall(r'^--- formula for .+ ---$', text, re.M))
if opens != len(formulas) or opens < 6:
    err('formula markers: %d opened, %d closed pairs found' % (opens, len(formulas)))


def balanced(f):
    pairs = {')': '(', ']': '[', '}': '{'}
    stack, inq = [], False
    for ch in f:
        if ch == '"':
            inq = not inq
        elif not inq:
            if ch in '([{':
                stack.append(ch)
            elif ch in pairs:
                if not stack or stack.pop() != pairs[ch]:
                    return False
    return not stack and not inq


for prop, f in formulas:
    if not f.strip():
        err('empty formula for %s' % prop)
    elif not balanced(f):
        err('unbalanced brackets or quotes in formula for %s: %s' % (prop, f.splitlines()[0][:60]))

# each block has a BY HAND part with at least one formula before the next block
for n in range(1, 7):
    if not re.search(r'^BY HAND for block %d ' % n, text, re.M):
        err('block %d: no BY HAND part' % n)

if errors:
    for e in errors:
        print('FAIL', e)
    sys.exit(1)
print('PROBE APP blocks=%d OK' % len(blocks))
