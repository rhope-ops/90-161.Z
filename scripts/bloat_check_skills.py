#!/usr/bin/env python3
"""The skills check of scripts/bloat_check.py (`python3 scripts/bloat_check.py --skills`; kept in its own file so the
check stays under the 600-line cap of docs/code-standard.md C4).

Input: the repo root; it reads each .claude/skills/*/SKILL.md and AGENTS.md. Output: FAIL lines (no frontmatter, no
name or description, a name that differs from its folder), indented WARN lines (description start or length, file
length, orphan skill) and the last line SKILLS PASS or SKILLS FAIL; exit 1 on a FAIL. Standard library only.
"""
import re


def skill_frontmatter(text):
    """Returns {key: value} of the YAML frontmatter (simple `key: value`, indented continuation lines), or None."""
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
    """Returns (lines, fails, warns, count) for .claude/skills/*/SKILL.md."""
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
