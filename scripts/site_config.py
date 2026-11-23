#!/usr/bin/env python3
"""Read site.config.json, the one home of this repository's account values (fleet v2 DEC 7), and give the URLs built from it.

Who runs it: other scripts import it (scripts/build_readme.py, tests/check_names.py); `python3 scripts/site_config.py`
prints the values and the URLs, for a check by hand.
Network: none.
Writes: none.
Credentials: none.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / 'site.config.json'


def load():
    """Read site.config.json. Takes nothing; returns a dict with owner, repo, branch and teamsChannel."""
    with open(CONFIG, encoding='utf-8') as f:
        return json.load(f)


def urls(cfg=None):
    """Build the URLs the scripts use from the config.

    Args:
        cfg: a dict from load(), or None to read the file.

    Returns:
        A dict: raw (raw file base, ends in /), blob (GitHub file view base, ends in /), pages (the github.io page),
        pages_host (the github.io host name), and re_owner, re_repo (the two names escaped for a regular expression).
    """
    c = cfg or load()
    o, r, b = c['owner'], c['repo'], c['branch']
    return {
        'raw': 'https://raw.githubusercontent.com/%s/%s/%s/' % (o, r, b),
        'blob': 'https://github.com/%s/%s/blob/%s/' % (o, r, b),
        'pages': 'https://%s.github.io/%s' % (o, r),
        'pages_host': '%s.github.io' % o,
        're_owner': re.escape(o),
        're_repo': re.escape(r),
        're_branch': re.escape(b),
    }


if __name__ == '__main__':
    for k, v in sorted(dict(load(), **urls()).items()):
        if not k.startswith('_'):
            print('%s = %s' % (k, v))
