#!/usr/bin/env python3
"""The rule census of scripts/bloat_check.py (`--rules`, `--lint`): the session load, the rule lines of AGENTS.md
against their caps, the lint of rule lines, the conflict-check gate for changed rule lines, and the paths AGENTS.md
names. Kept apart so bloat_check.py stays under the line cap of docs/code-standard.md C4 (what each measure
means: the header of bloat_check.py).

What it gives:
  start_read        what every session loads, in lines, bytes and ~tokens
  rule_lines        the rule lines of an AGENTS.md text: the kit sections, "## Project rules", and every line
  lint              WARN lines: near-duplicate pairs, vague words, untested rules
  readme_report     README.md exists and opens with the "- Purpose:" line of AGENTS.md (AGENTS.md "README")
  rules_report      the lines of `--rules` and the problems that fail scripts/check.sh
  main_lint         the `--lint` mode
Inputs:  the repo root, the audit settings (scripts/check_settings.py), AGENTS.md here and on origin/main,
         .claude/rule-tests.md and docs/reviews/.
Outputs: lists of lines for the caller to print (main_lint prints its own).
Run:     imported by scripts/bloat_check.py; proved by `python3 scripts/bloat_check.py --test`.
Network: none (it runs local git read commands).
Writes: none.
Credentials: none.
"""
import re
import subprocess

START_READ = ["AGENTS.md", "CLAUDE.md", "docs/NEXT_PROMPT.md"]
RULES_FILE = "AGENTS.md"
PROJECT_RULES = "## Project rules"
NOT_RULES = {"## Commands"}  # project-owned settings, not rules
RANKED = {"## Order of authority"}  # its numbered ranking of sources is not a rule count; a bullet there is
OPTIONAL = {"scripts/check.local.sh"}  # named in AGENTS.md, present only when the project has tests
VAGUE = ["appropriate", "appropriately", "as needed", "if needed", "when needed", "where possible", "if possible",
         "when possible", "properly", "reasonable", "be careful", "try to", "consider", "etc.", "best practice",
         "as much as", "usually", "generally", "ideally", "maybe", "might", "should"]
VALUE_OPTIONS = {"-o", "--output", "--out", "--outline"}  # options whose value is a file the command writes
NEAR_DUP = 0.6        # word overlap (Jaccard) from which two rule lines are a near-duplicate pair
RULE_TESTS = ".claude/rule-tests.md"
REVIEWS = "docs/reviews"


def git(root, *args):
    """Run git in root; return its output, or None when git fails or is missing."""
    try:
        r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    except OSError:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def start_read(root, cfg):
    """Return (lines, bytes, ~tokens, [(file, bytes)] largest first) of what every session loads: the start-read
    files, and the names and descriptions of the skills and agents (one entry; Claude Code lists them at start).

    Args:
        root: the repo root (a Path).
        cfg: the audit settings (its "start_read" list adds files).

    Returns:
        (lines, bytes, ~tokens, [(file, bytes)] largest first).
    """
    import bloat_check_skills  # scripts/bloat_check_skills.py: kept apart (code standard C4)
    lines, size = 0, bloat_check_skills.listing_bytes(root, cfg.get("third_party", []))[0]
    files = [("skill and agent descriptions", size)] if size else []
    for rel in START_READ + cfg.get("start_read", []):
        p = root / rel
        if p.is_file():
            b = p.read_bytes()
            lines += b.count(b"\n")
            size += len(b)
            files.append((rel, len(b)))
    return lines, size, size // 4, sorted(files, key=lambda f: -f[1])


ITEM = re.compile(r"^\s*(?:[-*+]|(\d+)[.)])\s+(.*)$")
RULE_HR = re.compile(r"^\s*([-*_])(\s*\1){2,}\s*$")           # --- or * * *: a horizontal rule, not a rule
TABLE_SEP = re.compile(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$")  # |---|---|: the row above it is a header
HEADING = re.compile(r"^\s*#{1,6}(\s|$)")                    # "### Sub"; "#1 priority: ..." is text, not a heading
EMPTY_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s*$")         # a marker with no text


BOLD_LABEL = re.compile(r"^\s*\*\*([^*]+?)\.?\*\*")  # "**Delivery.** text": the label of a rule bullet


def bold_label(text):
    """The bold label that starts a rule bullet, without its trailing dot ("Delivery"), or None."""
    m = BOLD_LABEL.match(text)
    return m.group(1).strip() if m else None


def rule_lines(text, with_sections=False):
    """Return (kit, project, every): the rule lines of an AGENTS.md text, by where they are.
    With with_sections: [(key, text)], where key is the bold label of a bullet ("**Delivery.** ..." gives "Delivery"),
    else the "## " heading name; the lint matches it to the "Section" column of .claude/rule-tests.md.

    A rule line is a list item with any marker ("- ", "* ", "+ ", "1. ") at any indent; a line that follows it with
    no blank line between is its continuation, not a new rule. kit = items under a "## " heading above
    "## Project rules" (not the header, not NOT_RULES sections; in RANKED sections the numbered ranking is not
    counted, a bullet is); project = items under "## Project rules", and there also each paragraph and each table
    row (not the header row), so a rule that is not a bullet still counts; there a line continues the item above it
    only when it is indented (an unindented line is a new rule: a count may be too high, never too low); every = the
    items of all sections, for the list of changed lines. Not counted anywhere: blank lines, "###" sub-headings,
    horizontal rules, table separator rows (they contain "|"), markers with no text, lines in ``` or ~~~ fences,
    <!-- comments -->. In the kit itself the file marks tier text
    with <!-- starter --> blocks: those are dropped, so the count is the full tier.

    Args:
        text: the text of an AGENTS.md.
        with_sections: True to get (key, line) pairs of every rule line instead.

    Returns:
        (kit, project, every), each a list of rule lines; with with_sections a list of (key, line).
    """
    text = re.sub(r"(?ms)^<!-- starter -->\n.*?^<!-- /starter -->\n", "", text)
    text = re.sub(r"(?s)<!--.*?-->", "", text)
    rows, sec, fenced, open_item = [], None, False, False  # rows: [section, text, counted, lint key]
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            fenced, open_item = not fenced, False
        elif fenced:
            continue
        elif line.startswith("## "):
            sec, open_item = line.rstrip(), False
        elif not sec:
            continue
        elif not line.strip() or HEADING.match(line) or RULE_HR.match(line) or EMPTY_ITEM.match(line):
            open_item = False
        elif TABLE_SEP.match(line) and "-" in line and "|" in line:
            if open_item and rows and "|" in rows[-1][1]:
                rows.pop()  # the header row of a table
            open_item = False
        else:
            m = ITEM.match(line)
            indented = line[:1] in (" ", "\t")
            if m:
                counted = sec not in NOT_RULES and not (sec in RANKED and m.group(1))
                rows.append([sec, m.group(2).strip(), counted, bold_label(m.group(2)) or sec[3:].strip()])
                open_item = True
            elif open_item and not line.lstrip().startswith("|") and (indented or sec != PROJECT_RULES):
                rows[-1][1] += " " + line.strip()  # a wrapped line belongs to the item above it
            elif sec == PROJECT_RULES:
                rows.append([sec, line.strip(), True, bold_label(line) or sec[3:].strip()])
                open_item = True
    if with_sections:
        return [(key, t) for _, t, c, key in rows if c]
    kit = [t for s_, t, c, _ in rows if c and s_ != PROJECT_RULES]
    project = [t for s_, t, c, _ in rows if c and s_ == PROJECT_RULES]
    return kit, project, [r[1] for r in rows]


def words(line):
    """The set of lower-case words of 3+ characters in line (for the near-duplicate measure)."""
    return set(re.findall(r"[a-z0-9][a-z0-9'-]{2,}", line.lower()))


def tested_sections(root):
    """Rule keys that have a scenario: the "Section" column of .claude/rule-tests.md (a bold bullet label, else a heading).

    Args:
        root: the repo root (a Path).

    Returns:
        The set of rule keys, or None when there is no rule-tests file.
    """
    p = root / RULE_TESTS
    if not p.is_file():
        return None
    out, col = set(), None
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if col is None and "Section" in cells:
            col = cells.index("Section")
        elif col is not None and len(cells) > col and not TABLE_SEP.match(line):
            out |= {c.strip() for c in cells[col].split(";")}
    return out


def lint(root, rules, only=None):
    """Rule lint, warn only. rules: [(section, text)]; only: the lines to report on (None = all).
    Returns WARN lines: near-duplicate pairs, vague words, untested rules.

    Args:
        root: the repo root (a Path).
        rules: the (section, text) pairs of the rule lines.
        only: the lines to report on; None = all.

    Returns:
        A list of WARN lines.
    """
    tested = tested_sections(root)
    out = []
    for i, (_, a) in enumerate(rules):
        for _, b in rules[i + 1:]:
            if only is not None and a not in only and b not in only:
                continue
            wa, wb = words(a), words(b)
            j = len(wa & wb) / len(wa | wb) if wa | wb else 0
            if j >= NEAR_DUP:
                out.append(f"WARN  rule lint: near-duplicate ({j:.0%} same words): \"{a[:70]}\" ~ \"{b[:70]}\"")
    for sec, t in rules:
        if only is not None and t not in only:
            continue
        low = " " + re.sub(r"`[^`]*`", " ", t.lower()) + " "
        hits = [v for v in VAGUE if re.search(r"(?<![a-z])" + re.escape(v) + r"(?![a-z])", low)]
        if hits:
            out.append(f"WARN  rule lint: vague ({', '.join(hits)}): \"{t[:90]}\"")
        if tested is not None and sec not in tested and not re.search(r"`scripts/[^`]+`|Enforced by", t):
            out.append(f"WARN  rule lint: untested (no scenario for \"{sec}\" in {RULE_TESTS}, no script named): \"{t[:80]}\"")
    return out


def conflict_hash(added, removed):
    """The hash a conflict-check record names: the changed rule lines, sorted, + and - kept apart."""
    import hashlib
    text = "\n".join(sorted("+" + l for l in added) + sorted("-" + l for l in removed))
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def conflict_recorded(root, h):
    """True when a file in docs/reviews/ holds the line "rule-conflict-check: <h>"."""
    d = root / REVIEWS
    return d.is_dir() and any(f"rule-conflict-check: {h}" in f.read_text(encoding="utf-8", errors="replace")
                              for f in d.rglob("*.md"))


def missing_pointers(root, text):
    """Paths that AGENTS.md names and that do not exist: each `.claude/...`, `scripts/...` and `docs/...` path
    inside backticks (also after a command word: `python3 scripts/x.py --test`), and relative link targets. Not a
    path to check: the value of an output option (`-o docs/out.html`: a file the command makes; VALUE_OPTIONS); a line number
    (`scripts/a.py:12`) and a pipe or ; or & after a path are cut off.

    Args:
        root: the repo root (a Path).
        text: the text of AGENTS.md.

    Returns:
        The sorted list of the missing paths.
    """
    text = re.sub(r"(?ms)^<!-- starter -->\n.*?^<!-- /starter -->\n", "", text)
    names = set()
    for span in re.findall(r"`([^`\n]+)`", text):
        words = re.split(r"[\s|;&]+", span)
        for prev, w in zip([""] + words, words):
            w = re.sub(r"(:\d+)+$", "", w.rstrip(".,;:)"))
            if re.match(r"(?:\.claude|scripts|docs)/", w) and prev not in VALUE_OPTIONS:
                names.add(w)
    names -= OPTIONAL
    names |= {t.split("#")[0] for t in re.findall(r"\]\(([^)\s]+)\)", text)
              if "://" not in t and not t.startswith(("#", "mailto:"))}
    return sorted(n for n in names if n and not re.search(r"[<>*{]", n) and not (root / n).exists())


def changed_rules(root, text, parts, gate):
    """The part of the rules report on rule lines that changed against the default branch: the lines, the state of
    their conflict check, and the lint of the added ones.

    Args:
        root: the repo root (a Path).
        text: the text of AGENTS.md now.
        parts: (kit, project, every), the rule lines of that text (rule_lines).
        gate: True in the full lane: a missing conflict-check record is a problem, not a WARN line.

    Returns:
        (lines to print, problems).
    """
    out, problems, old = [], [], None
    for ref in ("origin/main", "origin/master"):
        old = git(root, "show", f"{ref}:{RULES_FILE}")
        if old is not None:
            break
    if old is None:
        return out, problems
    import check_lock  # in a synced project the kit checked the locked kit lines: only "Project rules" count here
    part = 1 if check_lock.kit_text_locked(root) else 2
    every = parts[part]
    was = set(rule_lines(old)[part])
    now = set(every)
    added, removed = [l for l in every if l not in was], sorted(was - now)
    for mark, lines in (("+", added), ("-", removed)):
        out += [f"  {mark} {l}" for l in lines]  # the whole line: a change near its end must show
    if was != now:
        out.append("  (rule lines changed against the default branch: each one needs the Maintainer's approval of its exact text)")
        h = conflict_hash(added, removed)
        if conflict_recorded(root, h):
            out.append(f"  conflict check: recorded (rule-conflict-check: {h})")
        else:
            need = (f"no fresh-context conflict check for these lines: run it (.claude/skills/rule-change/SKILL.md) "
                    f"and record the line \"rule-conflict-check: {h}\" in {REVIEWS}/")
            if gate:
                problems.append(need)
            else:
                out.append(f"WARN  {need} (the full lane fails without it)")
        out += lint(root, rule_lines(text, with_sections=True), only=set(added))
    return out, problems


def readme_opening(text):
    """The first paragraph of a README text, for the AGENTS.md "README" check.

    Skipped before it: YAML front matter, headings (ATX and setext), images, badges, HTML lines and blank lines. A
    blockquote marker is taken off. The lines of the paragraph are joined by spaces.

    Args:
        text: the README text (a leading BOM is ignored).

    Returns:
        The first paragraph, or "" when there is none.
    """
    lines = text.lstrip("\ufeff").splitlines()
    if lines and lines[0].strip() == "---":  # YAML front matter: skip to its closing line
        close = next((i for i, x in enumerate(lines[1:], 1) if x.strip() in ("---", "...")), None)
        lines = lines[close + 1:] if close else lines
    para = []
    for line in lines:
        s = re.sub(r"^(>\s?)+", "", line.strip()).strip()
        if para and re.fullmatch(r"=+|-+", s):  # setext underline: the paragraph so far was a heading
            para = []
            continue
        if not s or s.startswith(("#", "![", "[![", "<")):
            if para:
                break
            continue
        para.append(s)
    return " ".join(para)


def plain_words(s):
    """Lower-case s with Markdown emphasis and code marks removed, spaces collapsed and a trailing period dropped."""
    return " ".join(re.sub(r"[*_`]", "", s).lower().split()).rstrip(".")


def readme_report(root, text):
    """The AGENTS.md "README" default: README.md exists and opens with the "- Purpose:" value of AGENTS.md.

    Checked only when that value is filled in (empty, or the kit template's {{PURPOSE}}, is not). A missing README.md
    (any letter case) is a problem; an opening that does not start with the purpose, as whole words, is a WARN line
    (the rule is enforced in part).

    Args:
        root: the repo root (a Path).
        text: the text of AGENTS.md.

    Returns:
        (lines to print, problems).
    """
    m = re.search(r"^- Purpose:[ \t]*(\S.*?)[ \t]*$", text, re.M)
    if not m or "{{" in m.group(1):
        return [], []
    readme = next((f for f in sorted(root.iterdir()) if f.is_file() and f.name.lower() == "readme.md"), None)
    if readme is None:
        return [], ["no README.md: it opens with the AGENTS.md \"Purpose\" line (AGENTS.md \"README\")"]
    want, got = plain_words(m.group(1)), plain_words(readme_opening(readme.read_text(encoding="utf-8", errors="replace")))
    if not (got.startswith(want) and (len(got) == len(want) or not got[len(want)].isalnum())):
        return [f"WARN  {readme.name} does not open with the AGENTS.md \"Purpose\" line; update it (AGENTS.md \"README\")"], []
    return [], []


def rules_report(root, cfg, gate=False):
    """The lines of `--rules`, and the problems that fail scripts/check.sh: a cap passed, a missing path, and with
    gate (the full lane) rule lines changed against origin/main with no conflict-check record in docs/reviews/.

    Args:
        root: the repo root (a Path).
        cfg: the audit settings (its budgets are the caps).
        gate: True in the full lane.

    Returns:
        (lines to print, problems).
    """
    p = root / RULES_FILE
    if not p.is_file():
        return [f"rules:       no {RULES_FILE}"], []
    text = p.read_text(encoding="utf-8", errors="replace")
    b = cfg["budgets"]
    kit, project, every = rule_lines(text)
    n_lines, load = len(text.splitlines()), start_read(root, cfg)[2]
    out = [f"rules:       {RULES_FILE} {n_lines} lines (cap {b['rules_file_lines']}) · session load ~{load:,} tokens "
           f"(cap {b['session_load_tokens']:,}) · {len(kit)} rule bullets · Project rules {len(project)}"]
    problems = []
    if n_lines > b["rules_file_lines"]:
        problems.append(f"{RULES_FILE} over the line cap ({n_lines} > {b['rules_file_lines']})")
    if cfg.get("third_party"):
        import bloat_check_skills  # scripts/bloat_check_skills.py: kept apart (code standard C4)
        third = bloat_check_skills.listing_bytes(root, cfg["third_party"])[1] // 4
        out[0] += f" · third-party ~{third:,} tokens (cap {b['third_party_tokens']:,})"
        if third > b["third_party_tokens"]:
            problems.append(f"third-party skills and agents over their cap (~{third:,} > {b['third_party_tokens']:,} "
                            "tokens: the `audit-third-party` entries in .check)")
    if load > b["session_load_tokens"]:
        problems.append(f"session load over the cap (~{load:,} > {b['session_load_tokens']:,} tokens: the start-read files "
                        "plus the skill and agent descriptions)")
    elif load > b["session_load_warn_tokens"]:
        out.append(f"WARN  session load ~{load:,} tokens is over the warning ({b['session_load_warn_tokens']:,}); trim before the cap")
    # The bullet counts only warn (the Maintainer, 2026-11-18): the line and load caps are the limits.
    if len(kit) > b["rules"]:
        out.append(f"WARN  {len(kit)} rule bullets (guide {b['rules']})")
    if len(project) > b["project_rules"]:
        out.append(f"WARN  {len(project)} project rule bullets (guide {b['project_rules']})")
    import bloat_check_skills  # scripts/bloat_check_skills.py: kept apart (code standard C4)
    problems += bloat_check_skills.second_homes(root)
    rows, found = changed_rules(root, text, (kit, project, every), gate)
    out += rows
    problems += found
    gone = missing_pointers(root, text)
    if gone:
        problems.append("missing paths named in AGENTS.md: " + ", ".join(gone))
    rows, found = readme_report(root, text)
    out += rows
    problems += found
    for pr in problems:
        out.append(f"RULES FAIL:  {pr}")
    return out, problems


def main_lint(root):
    """--lint: print the rule lint of every rule line and a LINT count line. Always 0 (warn only)."""
    p = root / RULES_FILE
    rules = rule_lines(p.read_text(encoding="utf-8", errors="replace"), with_sections=True) if p.is_file() else []
    rows = lint(root, rules)
    print("\n".join(rows + [f"LINT: {len(rows)} flag(s) in {len(rules)} rule lines (warn only)"]))
    return 0
