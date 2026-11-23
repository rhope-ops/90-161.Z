#!/usr/bin/env python3
"""The skills check of scripts/bloat_check.py (`python3 scripts/bloat_check.py --skills`; kept in its own file so the
check stays under the line cap of docs/code-standard.md C4).

Input: the repo root; it reads each .claude/skills/*/SKILL.md and AGENTS.md. Output: FAIL lines (no frontmatter, no
name or description, a name that differs from its folder), indented WARN lines (description start or length, file
length, orphan skill) and the last line SKILLS PASS or SKILLS FAIL; exit 1 on a FAIL. Standard library only.
Network: none.
Writes: none.
Credentials: none.
"""
import fnmatch
import json
import re


def skill_frontmatter(text):
    """Returns {key: value} of the YAML frontmatter (simple `key: value`, indented continuation lines), or None.

    Args:
        text: the text of a SKILL.md file.

    Returns:
        A dict {key: value}, or None when the file has no frontmatter.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration:
        return None
    fm, key = {}, None
    for ln in lines[1:end]:
        m = re.match(r"([A-Za-z_-]+):\s*(.*)$", ln)
        if m and not ln[0].isspace():
            key = m.group(1)
            fm[key] = m.group(2).strip()
        elif key and ln.strip():
            head = "" if fm[key] in (">", "|", ">-", "|-") else fm[key]  # a block marker is not part of the text
            fm[key] = (head + " " + ln.strip()).strip()
    for k, v in fm.items():
        fm[k] = "" if v in (">", "|", ">-", "|-") else v.strip("\"'")
    return fm


def skills_report(root):
    """Returns (lines, fails, warns, count) for .claude/skills/*/SKILL.md.

    Args:
        root: the repo root (a Path).

    Returns:
        (lines to print, the number of FAIL lines, the number of WARN lines, the number of skills).
    """
    files = sorted((root / ".claude/skills").glob("*/SKILL.md"))
    texts = {f.parent.name: f.read_text(encoding="utf-8", errors="replace") for f in files}
    agents = (root / "AGENTS.md").read_text(encoding="utf-8", errors="replace") if (root / "AGENTS.md").is_file() else ""
    out, fails, warns = [], 0, 0
    for name, text in texts.items():
        rel = f".claude/skills/{name}/SKILL.md"
        fm = skill_frontmatter(text)
        if fm is None:
            out.append(f"FAIL  {rel}: no YAML frontmatter")
            fails += 1
            continue
        bad = [f"no {k}" for k in ("name", "description") if not fm.get(k)]
        if fm.get("name") and fm["name"] != name:
            bad.append(f"name \"{fm['name']}\" differs from folder \"{name}\"")
        if bad:
            out.append(f"FAIL  {rel}: {', '.join(bad)}")
            fails += 1
        desc = fm.get("description", "")
        warn = []
        if desc and not desc.startswith(("Use when", "Use before")):
            warn.append('description does not start with "Use when" or "Use before"')
        if len(desc) > 1024:
            warn.append(f"description is {len(desc)} characters (over 1024)")
        n = len(text.splitlines())
        if n > 150:
            warn.append(f"{n} lines (over 150)")
        pat = r"(?<![\w-])" + re.escape(name) + r"(?![\w-])"
        if not re.search(pat, agents) and not any(re.search(pat, t) for o, t in texts.items() if o != name):
            warn.append("orphan: name not mentioned in AGENTS.md or another SKILL.md")
        for w in warn:
            out.append(f"  WARN  {rel}: {w}")
        warns += len(warn)
    return out, fails, warns, len(texts)


def main_skills(root):
    """Print the skills report and its last line; return 1 when a skill is malformed, else 0."""
    rows, fails, warns, n = skills_report(root)
    print("\n".join(rows + [f"SKILLS FAIL: {fails} skill(s) malformed, {n} skills, {warns} warnings" if fails
                           else f"SKILLS PASS: {n} skills, {warns} warnings"]))
    return 1 if fails else 0


def kit_files(root):
    """The skill and agent files that can never count as third-party: the kit files in a project's `.check.lock`.
    It fails closed: with no lock (the kit clone itself has none), a lock that cannot be read, or a lock with no files,
    every skill and agent file there is one, so a glob cannot move the kit's own text out of the session load.

    Args:
        root: the repo root (a Path).

    Returns:
        A set of repo-relative paths.
    """
    found = sorted((root / ".claude/skills").glob("*/SKILL.md")) + sorted((root / ".claude/agents").glob("*.md"))
    every = {f.relative_to(root).as_posix() for f in found}
    try:
        files = json.loads((root / ".check.lock").read_text(encoding="utf-8")).get("files")
    except (ValueError, OSError, AttributeError):
        return every
    return set(files) if isinstance(files, dict) and files else every


def listing_bytes(root, third_party=()):
    """Bytes of the names and descriptions of .claude/skills/*/SKILL.md and .claude/agents/*.md: Claude Code puts
    them in every session's context, so they count toward the session load.

    Args:
        root: the repo root (a Path).
        third_party: the `audit-third-party` globs; a skill folder or agent file they match is counted apart,
            except a kit file (in `.check.lock`, or in the kit itself): a glob cannot move the kit's own text out.

    Returns:
        (bytes of the own skills and agents, bytes of the third-party ones).
    """
    own = third = 0
    kit = kit_files(root) if third_party else set()
    for f in sorted((root / ".claude/skills").glob("*/SKILL.md")) + sorted((root / ".claude/agents").glob("*.md")):
        fm = skill_frontmatter(f.read_text(encoding="utf-8", errors="replace")) or {}
        size = len((fm.get("name", "") + fm.get("description", "")).encode())
        rel = f.relative_to(root).as_posix()
        names = (rel, rel.rsplit("/", 1)[0]) if rel.endswith("/SKILL.md") else (rel,)
        if rel not in kit and any(fnmatch.fnmatchcase(n, g.rstrip("/")) for n in names for g in third_party):
            third += size
        else:
            own += size
    return own, third


# One home per rule (the Maintainer, 2026-11-18): a rule that AGENTS.md states must not be stated again, or the other
# way round, in a skill or an agent file; those files link to it. Each row: (the rule, a pattern that shows a
# second statement, the files that may hold it). A match in any other skill or agent file fails scripts/check.sh.
SINGLE_HOME = [
    ("who merges a pull request", r"only the Maintainer merges|the Maintainer merges\b|never merges this pull request|the Maintainer's merge is the approval", ["AGENTS.md"]),
    ("no direct push to main", r"merge to main by merge|\bPush main:|git checkout main && git merge|push to main and republish", ["AGENTS.md"]),
    ("the end-of-turn summary format", r"end-of-turn summary line:", ["AGENTS.md"]),
    # The hard rules (AGENTS.md "Hard rules", 2026-11-18). A pointer such as (AGENTS.md "Hard rules") or a description
    # of what a hook blocks has no "never ..." sentence and passes.
    ("hard rule: git history",
     r"\bnever (?:force[- ]?push|rebase\b|reset\b|stash\b|(?:git )?clean\b(?! up)|rewrite published history|discard work)"
     r"|\bnever push\b[^.\n]*(?:--no-verify|\bmain\b|default branch)", ["AGENTS.md"]),
    ("hard rule: guards and checks",
     r"\bnever (?:weaken a (?:check|hook|test|guard)|skip a (?:check|test)|repin\b|add an? (?:allow|skip|exemption)"
     r"|edit a generated report)", ["AGENTS.md"]),
    ("hard rule: rule text approval", r"\b(?:is|are) not approval\b", ["AGENTS.md"]),
    ("hard rule: the fresh review tier", r"tier no lower than|never review with a lower tier", ["AGENTS.md"]),
]


def second_homes(root, table=None):
    """Problems for each SINGLE_HOME rule found in a skill or agent file that is not its home.

    Args:
        root: the repo root (a folder path).
        table: the rules to look for, as (label, pattern, home files); None = SINGLE_HOME.

    Returns:
        One problem line for each place found.
    """
    files = sorted((root / ".claude/skills").glob("*/SKILL.md")) + sorted((root / ".claude/agents").glob("*.md"))
    out = []
    for label, pattern, homes in (SINGLE_HOME if table is None else table):
        rx = re.compile(pattern, re.IGNORECASE)
        for f in files:
            rel = f.relative_to(root).as_posix()
            if rel in homes:
                continue
            for n, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if rx.search(line):
                    out.append(f"second home of a rule: {rel}:{n} states \"{label}\"; its home is {homes[0]}: link to it")
    return out
