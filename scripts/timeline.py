#!/usr/bin/env python3
"""Render one or more project logs (docs/LOG.md) as one self-contained HTML timeline page.

Usage:
    python3 scripts/timeline.py [LOG ...] [-o timeline.html] [--title TEXT]
    LOG = path, or LABEL=path, or LABEL=path@owner/repo (commit hashes in Evidence become GitHub links)
    Default: docs/LOG.md
    python3 scripts/timeline.py --outline story.md [LOG ...]   # Markdown story outline per arc, the source for a deck
    python3 scripts/timeline.py --test      # self-test; prints TIMELINE TEST PASS

The page has: a summary (counts by type and project), the arcs (narratives) with their spans, problem, turning point, outcome and lesson, and the
events newest-first grouped by day, with filters by project, type and arc. Light and dark follow the system and a
toggle. Each type has a shape and a label, not only a color (milestone square, breakthrough triangle, miss circle,
decision diamond). No scripts or fonts load from the network.
Logs are validated with scripts/log_check.py first; a log with findings is refused (fix it, or pass --force).
Public pages: the output holds everything in the log. A public repo's log is private on purpose (AGENTS.md
"Project log"), so publish a timeline from it only to a private place, or sanitize the log first.
Standard library only.
Network: none.
Writes: the output file (-o, default timeline.html; or --outline FILE).
Credentials: none.
"""
import argparse
import datetime as dt
import html
import json
import pathlib
import re
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import log_check  # noqa: E402
from build_site_html import dod_security, page_head, sha256  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent

TYPE_ORDER = ["milestone", "breakthrough", "miss", "decision"]
COMMIT_RE = re.compile(r"\b([0-9a-f]{7,40})\b")
# Only hashes in a "Commit x" / "Commits x, y" phrase link to the log's repo; "other_repo abc1234" stays text.
COMMIT_PHRASE_RE = re.compile(r"\bCommits? ((?:[0-9a-f]{7,40})(?:(?:, | and )[0-9a-f]{7,40})*)\b")


def parse_spec(spec):
    """Split a LABEL=PATH@OWNER/REPO argument into (label, path, repo); the label defaults to the log's title.

    Args:
        spec: the argument text.

    Returns:
        (label or None, path as a Path, repo or None).
    """
    label, repo, path = None, None, spec
    if "=" in path:
        label, path = path.split("=", 1)
    if "@" in path:
        path, repo = path.rsplit("@", 1)
    p = pathlib.Path(path)
    if not label:
        text = p.read_text(encoding="utf-8") if p.exists() else ""
        m = re.search(r"^# Project log: (.+?)\s*$", text, re.M)
        label = m.group(1) if m else p.parent.parent.name or p.stem
    return label, p, repo


def load(label, path, repo):
    """The (arcs, events) of one project log, each tagged with its project label.

    Args:
        label: the project label; None = the log's title.
        path: the path of the log file (a Path).
        repo: OWNER/REPO for commit links, or None.

    Returns:
        (arcs, events), each a list of dicts.
    """
    t = log_check.tables(path.read_text(encoding="utf-8"))
    arcs = [dict(zip(log_check.ARC_COLS, c)) for _, c in t.get("Arcs", (0, [], []))[2]]
    events = []
    for _, c in t["Log"][2]:
        if len(c) != len(log_check.LOG_COLS):
            continue
        e = dict(zip(["num", "when", "type", "arc", "topic", "raised", "missed", "evidence", "result"], c))
        m = log_check.WHEN_RE.match(e["when"])
        start = dt.datetime.strptime(f"{m.group(1)} {m.group(2).lstrip('~')}", "%Y-%m-%d %H:%M") if m else None
        e.update(project=label, repo=repo, sort=start.isoformat() if start else "", day=m.group(1) if m else "")
        events.append(e)
    for a in arcs:
        a["project"] = label
    return arcs, events


def link_evidence(text, repo):
    """Escape evidence text and link each hash in a "Commit x" phrase to the log's GitHub repo."""
    out = html.escape(text)
    if not repo:
        return out
    link = lambda m: f'<a href="https://github.com/{html.escape(repo)}/commit/{m.group(1)}">{m.group(1)}</a>'
    return COMMIT_PHRASE_RE.sub(lambda m: m.group(0).replace(m.group(1), COMMIT_RE.sub(link, m.group(1))), out)


CSS = """
:root{--bg:#f7f8fa;--card:#fff;--text:#16181d;--muted:#555b66;--line:#d9dde3;--chip:#eef0f3;
--milestone:#1f5fbf;--breakthrough:#1b7a3d;--miss:#a35a00;--decision:#6b3fb3;--focus:#1f5fbf}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#111317;--card:#1a1d23;--text:#eceef2;--muted:#a7adb8;
--line:#30353d;--chip:#262a31;--milestone:#7fb0ff;--breakthrough:#5fd38a;--miss:#f0a94a;--decision:#c3a2ff;--focus:#7fb0ff}}
:root[data-theme=dark]{--bg:#111317;--card:#1a1d23;--text:#eceef2;--muted:#a7adb8;--line:#30353d;--chip:#262a31;
--milestone:#7fb0ff;--breakthrough:#5fd38a;--miss:#f0a94a;--decision:#c3a2ff;--focus:#7fb0ff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);
font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif}
main{max-width:960px;margin:0 auto;padding:24px 16px 64px}
h1{font-size:28px;line-height:1.2;margin:0 0 4px}h2{font-size:20px;margin:32px 0 12px}
.sub{color:var(--muted);margin:0 0 16px}
.bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:16px 0}
button,select{font:inherit;color:var(--text);background:var(--card);border:1px solid var(--line);border-radius:8px;
min-height:44px;padding:8px 12px;cursor:pointer}
button:focus-visible,select:focus-visible,a:focus-visible{outline:3px solid var(--focus);outline-offset:2px}
button[aria-pressed=false]{opacity:.6}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:8px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px}
.stat b{display:block;font-size:24px}
.arcs{display:grid;gap:8px}.arcbox summary{cursor:pointer;min-height:44px;display:flex;align-items:center}
.arcbox summary h2{display:inline;margin:0 0 0 4px}.arcbox{margin:24px 0 0}
.arcbox summary{list-style:none}.arcbox summary::-webkit-details-marker{display:none}
.arcbox summary::before{content:'\\25B8';color:var(--muted);width:16px}.arcbox[open] summary::before{content:'\\25BE'}
.arc{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px 16px}
.arc h3{font-size:16px;margin:0}.arc p{margin:4px 0 0;color:var(--muted)}
.day{margin:24px 0 8px;font-weight:600;color:var(--muted)}
.ev{position:relative;background:var(--card);border:1px solid var(--line);border-left:4px solid var(--c);
border-radius:12px;padding:12px 16px;margin:8px 0}
.ev header{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.ev h3{font-size:16px;margin:0;flex:1 1 220px}
.type{display:inline-flex;gap:6px;align-items:center;font-weight:600;color:var(--c)}
.mark{width:12px;height:12px;background:var(--c);display:inline-block}
.milestone{--c:var(--milestone)}.milestone .mark{border-radius:2px}
.breakthrough{--c:var(--breakthrough)}.breakthrough .mark{clip-path:polygon(50% 0,100% 100%,0 100%)}
.miss{--c:var(--miss)}.miss .mark{border-radius:50%}
.decision{--c:var(--decision)}.decision .mark{transform:rotate(45deg);width:10px;height:10px}
.chip{background:var(--chip);border-radius:999px;padding:2px 10px;font-size:14px}
.meta{color:var(--muted);font-size:14px}
dl{display:grid;grid-template-columns:max-content 1fr;gap:4px 12px;margin:8px 0 0;font-size:15px}
dt{color:var(--muted)}dd{margin:0;overflow-wrap:anywhere}
a{color:var(--focus)}
.hidden{display:none}
"""

JS = """
const state={project:new Set(),type:new Set(),arc:'all'};
function apply(){let shown=0;document.querySelectorAll('.ev').forEach(e=>{const ok=state.project.has(e.dataset.project)
&&state.type.has(e.dataset.type)&&(state.arc==='all'||state.arc===e.dataset.project+'/'+e.dataset.arc);
e.classList.toggle('hidden',!ok);if(ok)shown++});document.querySelectorAll('.day').forEach(d=>{let n=d.nextElementSibling,any=false;
while(n&&!n.classList.contains('day')){if(n.classList.contains('ev')&&!n.classList.contains('hidden'))any=true;n=n.nextElementSibling}
d.classList.toggle('hidden',!any)});document.getElementById('count').textContent=shown+' shown'}
document.querySelectorAll('[data-filter]').forEach(b=>{state[b.dataset.filter].add(b.dataset.value);b.addEventListener('click',()=>{
const s=state[b.dataset.filter],v=b.dataset.value;if(s.has(v)){s.delete(v);b.setAttribute('aria-pressed','false')}else{s.add(v);
b.setAttribute('aria-pressed','true')}apply()})});
document.getElementById('arc').addEventListener('change',e=>{state.arc=e.target.value;apply()});
document.getElementById('theme').addEventListener('click',()=>{const r=document.documentElement,dark=r.dataset.theme?r.dataset.theme==='dark'
:matchMedia('(prefers-color-scheme: dark)').matches;r.dataset.theme=dark?'light':'dark'});apply();
"""


def log_zone(path):
    """The time zone a log names in its intro ("Times are <zone>."), or None."""
    try:
        m = re.search(r"Times are ([A-Za-z0-9_+/-]+)\.", pathlib.Path(path).read_text(encoding="utf-8", errors="replace"))
    except OSError:
        return None
    return m and m.group(1)


def zone_note(zones):
    """One zone for all logs: name it. Mixed zones, or a log that names none beside one that does: say so."""
    zones = set(zones)
    if zones == {None} or not zones:
        return ""
    if len(zones) == 1:
        return f" Times are {zones.pop()}."
    return " Times are each project's local time."


def render(title, arcs, events, zones=(), security=None):
    """The self-contained HTML timeline page: arcs, filters and event cards, newest first.

    Args:
        title: the page title.
        arcs: the arcs of every log.
        events: the events of every log.
        zones: the time zone names of the logs.
        security: True or False to force the DoD meta tags (CSP, referrer) on or off; None reads `dod-security:` in
            this repo's .check (default off).

    Returns:
        The page as HTML text.
    """
    e = html.escape
    security = dod_security(ROOT) if security is None else security
    events = sorted(events, key=lambda x: (x["sort"], x["project"], int(x["num"]) if x["num"].isdigit() else 0), reverse=True)
    projects = sorted({x["project"] for x in events} | {a["project"] for a in arcs})
    counts = {t: sum(1 for x in events if x["type"] == t) for t in TYPE_ORDER}
    first = min((x["day"] for x in events if x["day"]), default="")
    last = max((x["day"] for x in events if x["day"]), default="")
    out = [page_head(e(title), CSS, JS, security, theme=('#f7f8fa', '#111317')),
           f"<h1>{e(title)}</h1><p class='sub'>{len(events)} events in {len(projects)} project(s), {e(first)} to {e(last)}.{e(zone_note(zones))}</p>",
           "<div class='stats'>"]
    for t in TYPE_ORDER:
        out.append(f"<div class='stat {t}'><span class='type'><span class='mark' aria-hidden='true'></span>{t}</span><b>{counts[t]}</b></div>")
    out.append(f"</div><details class='arcbox'><summary><h2>Arcs ({len(arcs)})</h2></summary><div class='arcs'>")
    for a in arcs:
        n = sum(1 for x in events if x["project"] == a["project"] and x["arc"] == a["Arc"])
        out.append(f"<div class='arc'><h3>{e(a['Arc'])} <span class='meta'>· {e(a['project'])} · {n} event{'s' if n != 1 else ''} · {e(a['Span'])}</span></h3>"
                   f"<p>{e(a['Summary'])}</p>"
                   + "".join(f"<p><b>{k}:</b> {e(a.get(k, '-'))}</p>" for k in STORY if a.get(k, "-") not in ("", "-"))
                   + "</div>")
    out.append("</div></details><h2>Events</h2><div class='bar' role='group' aria-label='Filters'>")
    for p in projects:
        out.append(f"<button type='button' data-filter='project' data-value='{e(p)}' aria-pressed='true'>{e(p)}</button>")
    for t in TYPE_ORDER:
        out.append(f"<button type='button' class='{t}' data-filter='type' data-value='{t}' aria-pressed='true'><span class='type'><span class='mark' aria-hidden='true'></span>{t}</span></button>")
    out.append("<label><span class='meta'>Arc </span><select id='arc'><option value='all'>All arcs</option>")
    for a in arcs:
        out.append(f"<option value='{e(a['project'])}/{e(a['Arc'])}'>{e(a['project'])}: {e(a['Arc'])}</option>")
    out.append("</select></label><button type='button' id='theme'>Light / dark</button><span id='count' class='meta' aria-live='polite'></span></div>")
    day = None
    for x in events:
        if x["day"] != day:
            day = x["day"]
            out.append(f"<div class='day'>{e(day)}</div>")
        time = x["when"][len(x["day"]):].strip()
        rows = [("Raised by", e(x["raised"])), ("Missed", e(x["missed"])), ("Evidence", link_evidence(x["evidence"], x["repo"])),
                ("Result", e(x["result"]))]
        dl = "".join(f"<dt>{k}</dt><dd>{v}</dd>" for k, v in rows if v and v != "-")
        out.append(f"<article class='ev {e(x['type'])}' data-project='{e(x['project'])}' data-type='{e(x['type'])}' data-arc='{e(x['arc'])}'>"
                   f"<header><span class='type'><span class='mark' aria-hidden='true'></span>{e(x['type'])}</span><h3>{e(x['topic'])}</h3>"
                   f"<span class='meta'>{e(time)}</span><span class='chip'>{e(x['project'])}</span><span class='chip'>{e(x['arc'])}</span></header>"
                   f"<dl>{dl}</dl></article>")
    out.append(f"</main><script>{JS}</script></body></html>")  # the CSP hash covers this exact JS text
    return "".join(out)


STORY = ["Problem", "Turning point", "Outcome", "Lesson"]


def outline(arcs, events):
    """Markdown story outline: one section per arc, oldest arc first, ready to turn into 3-4 slides each.

    Args:
        arcs: the arcs of every log.
        events: the events of every log.

    Returns:
        The outline as Markdown text.
    """
    rows = {(x["project"], x["num"]): x for x in events}
    first = {}
    for x in events:
        k = (x["project"], x["arc"])
        first[k] = min(first.get(k, x["sort"]), x["sort"])
    out = ["# Story outline", "", "One section per arc, oldest first. Slides: Problem, Turning point, Outcome, Lesson.", ""]
    for a in sorted(arcs, key=lambda a: first.get((a["project"], a["Arc"]), "~")):  # an arc with no events goes last
        mine = [x for x in events if x["project"] == a["project"] and x["arc"] == a["Arc"]]
        counts = ", ".join(f"{sum(1 for x in mine if x['type'] == ty)} {ty}" for ty in sorted(log_check.TYPES))
        out += [f"## {a['project']}: {a['Arc']}", "", f"{a['Summary']} ({a['Span']}; {counts})", ""]
        for k in STORY:
            v = a.get(k, "-")
            if v in ("", "-"):
                continue
            out.append(f"- **{k}:** {v}")
            if k == "Turning point":
                for n in log_check.ROW_REF.findall(v):
                    x = rows.get((a["project"], n))
                    if x:
                        out.append(f"  - #{n} ({x['when']}, {x['type']}): {x['topic']}. Result: {x['result']}. Evidence: {x['evidence']}")
        misses = [x for x in mine if x["type"] == "miss"]
        if misses:
            out.append("- **Misses:** " + "; ".join(f"#{x['num']} {x['topic']}" for x in misses))
        out.append("")
    return "\n".join(out)


def build(specs, title, force=False, as_outline=False):
    """Load each log and return (page or outline, problems); no page when a log fails log_check without --force.

    Args:
        specs: the LABEL=PATH@OWNER/REPO arguments.
        title: the page title.
        force: True to render although a log has findings.
        as_outline: True for the Markdown outline, not the page.

    Returns:
        (the text or None, the list of problems).
    """
    arcs, events, problems, zones = [], [], [], []
    for spec in specs:
        label, path, repo = parse_spec(spec)
        _, found = log_check.check(path)
        if found and not force:
            problems += found
            continue
        a, ev = load(label, path, repo)
        zones.append(log_zone(path))
        arcs += a
        events += ev
    if problems:
        return None, problems
    return (outline(arcs, events) if as_outline else render(title, arcs, events, zones)), problems


def shell_checks(page, d):
    """Return the self-test checks of the page shell (skip link, landmarks, theme-color, reduced motion, DoD meta tags).

    Args:
        page: a page built with this repo's settings (dod-security off unless the repo turned it on).
        d: a temporary folder for sample `.check` files.
    Returns:
        A list of (name, passed).
    """
    css = re.search(r"<style>(.*?)</style>", page, re.S).group(1)
    on = page_head("T", CSS, JS, True)
    root = pathlib.Path(d, "repo")
    root.mkdir()
    modes = {None: False, "dod-security: on\n": True, "dod-security: off\n": False}
    got = {}
    for text in modes:
        (root / ".check").write_text(text or "code-c2: full\n", encoding="utf-8")
        got[text] = dod_security(root)
    (root / ".check").write_text("dod-security: yes\n", encoding="utf-8")
    try:
        dod_security(root)
        refused = False
    except ValueError:
        refused = True
    return [("page shell: skip link first in body, main#main, 2 theme-color, reduced motion",
             "<body><a class=\"skip-link\" href=\"#main\">" in page and page.count("<main id=\"main\">") == 1
             and page.count("name=\"theme-color\"") == 2 and "prefers-reduced-motion:reduce" in page),
            ("dod-security on: CSP with the style and script hashes, referrer",
             "Content-Security-Policy" in on and "name=\"referrer\" content=\"no-referrer\"" in on
             and sha256(css) in on and sha256(JS) in on and "default-src 'none'" in on and "base-uri 'none'" in on
             and "form-action 'none'" in on),
            ("dod-security reads on, off, default off; any other value is refused", got == modes and refused)]


def self_test():
    """Render a sample log and check escaping, links, order, zones, outline and refusal; print the results.

    Returns:
        The exit code: 0 pass, 1 fail.
    """
    ok = True
    with tempfile.TemporaryDirectory() as d:
        f = pathlib.Path(d, "LOG.md")
        f.write_text(log_check.GOOD.replace("| T | Owner | - | Commit abc |", "| <script>x</script> | Owner | - | other_repo 59cd968; Commits 1234567, 89abcde |"), encoding="utf-8")
        page, problems = build([f"Demo={f}@sample-org/demo"], "Test")
        checks = [
            ("renders", page is not None and not problems),
            ("all 4 rows", page and page.count("<article") == 4),
            ("html escaped", page and "<script>x</script>" not in page and "&lt;script&gt;" in page),
            ("commit linked", page and "https://github.com/sample-org/demo/commit/63ae6e2" in page),
            ("newest first", page and page.index("23:50") < page.index("22:11")),
            ("other repo hash not linked", page and "/commit/59cd968" not in page),
            ("list of commits linked", page and "/commit/1234567" in page and "/commit/89abcde" in page),
            ("zone from the log", zone_note(["Europe/Berlin", "Europe/Berlin"]) == " Times are Europe/Berlin."
             and zone_note(["Europe/Berlin", None]) == " Times are each project's local time."
             and zone_note(["UTC", "Asia/Tokyo"]) == " Times are each project's local time." and zone_note([]) == ""),
            ("no network", page and not re.search(r"(src|href)=['\"]?https?://(?!github\.com/)", page)),
        ]
        story, _ = build([f"Demo={f}"], "Test", as_outline=True)
        checks.append(("outline has story fields", story and "**Problem:** Manual import took 2 h." in story
                       and "#2 (2026-11-11 07:57–08:20, breakthrough)" in story and "**Misses:** #1" in story
                       and "setup" in story and story.index("setup") < story.index("flow-import")))
        checks.append(("arc card shows lesson", page and "Lesson:</b> Test the import first" in page))
        checks += shell_checks(page, d)
        bad = pathlib.Path(d, "BAD.md")
        bad.write_text(log_check.GOOD.replace("| miss |", "| oops |"), encoding="utf-8")
        _, probs = build([str(bad)], "Test")
        checks.append(("refuses invalid log", bool(probs)))
    for name, good in checks:
        print(("ok   " if good else "FAIL ") + name)
        ok = ok and bool(good)
    print("TIMELINE TEST " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    """Command line: write the timeline page (or outline), or run --test; return the exit code.

    Returns:
        The exit code: 0 written or passed, 1 on a problem.
    """
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("logs", nargs="*", default=["docs/LOG.md"])
    ap.add_argument("-o", "--output", default="timeline.html")
    ap.add_argument("--title", default="Project timeline")
    ap.add_argument("--force", action="store_true", help="render even when log_check finds problems")
    ap.add_argument("--outline", metavar="FILE", help="write a Markdown story outline per arc instead of the HTML page")
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    if a.test:
        return self_test()
    page, problems = build(a.logs, a.title, a.force, as_outline=bool(a.outline))
    if problems:
        print("\n".join(problems))
        print("TIMELINE: refused; fix the log or pass --force")
        return 1
    target = a.outline or a.output
    pathlib.Path(target).write_text(page, encoding="utf-8")
    print(f"TIMELINE: wrote {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
