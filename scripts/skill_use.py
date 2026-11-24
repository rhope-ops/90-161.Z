#!/usr/bin/env python3
"""Count which skills, agent types and tools a set of Claude session records really used.

Why: a skill that no session loads costs tokens in every session and gives nothing back, and nothing else records
skill loads. The audit skill (.claude/skills/audit/SKILL.md, category 19) runs this on a sample of sessions.

Input: one or more files that hold session records as JSON:
  - a saved result of the cloud tool `list_events` (JSON with note lines around it), or
  - a Claude Code session log (.jsonl, one JSON object on each line).
The script walks every JSON value and counts each `tool_use` block one time (by its id).

Output (stdout): one table with these groups:
  skill   a call of the Skill tool (the full skill was loaded)
  read    a Read of a SKILL.md file (the full file was read)
  shell   a shell command that names a SKILL.md file (often only a slice of it)
  agent   an Agent or Task call, by agent type
  tool    every other tool, by name
and `--json` prints the same counts as JSON.

Run:        python3 scripts/skill_use.py FILE [FILE ...] [--json]
Self-test:  python3 scripts/skill_use.py --test
Standard library only.
Prevents: a skill that no session loads stays in the kit and costs tokens in every session, because nothing else records skill loads
Network: none.
Writes: none (stdout only).
Credentials: none.
"""
import collections
import json
import re
import sys

SKILL_FILE = re.compile(r"(?:^|(?<=[/\s\"']))skills/([A-Za-z0-9_.-]+)/SKILL\.md")  # the skill's name: the folder after skills/ ("$f/SKILL.md" is no skill)
AGENT_TOOLS = ("Agent", "Task")  # the tools that start a subagent
SHELL_TOOLS = ("Bash",)  # the tools whose input is a shell command
GROUPS = ("skill", "read", "shell", "agent", "tool")  # the order of the report


def json_values(path):
    """Yield each JSON value in a file: every line that parses as JSON (a log has many, a saved result has one).

    Args:
        path: the file to read.

    Returns:
        A generator of the JSON objects and arrays in the file, in order: one value over many lines (a
        pretty-printed file), several values one after another, or one value on each line. Text that is not
        JSON (a note line, a wrapper tag) is skipped.
    """
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    decoder = json.JSONDecoder()
    at = 0
    while True:
        starts = [i for i in (text.find("{", at), text.find("[", at)) if i >= 0]
        if not starts:
            return
        at = min(starts)
        try:
            value, at = decoder.raw_decode(text, at)
            yield value
        except (ValueError, RecursionError):
            at += 1  # not the start of a JSON value (or nested too deep to read): look for the next one


def tool_uses(value, seen):
    """Yield each tool_use block inside a JSON value one time.

    Args:
        value: any parsed JSON value.
        seen: the set of tool_use ids already counted (changed in place).

    Returns:
        A generator of (tool name, input dict) pairs.
    """
    stack = [value]
    while stack:
        item = stack.pop()
        if isinstance(item, list):
            stack.extend(item)
        elif isinstance(item, dict):
            if item.get("type") == "tool_use" and isinstance(item.get("name"), str):
                key = item.get("id")
                if not key or key not in seen:  # a block with no id (or an empty one) cannot repeat by id: count it
                    seen.add(key)
                    yield item["name"], item.get("input") if isinstance(item.get("input"), dict) else {}
            stack.extend(item.values())


def classify(name, tool_input):
    """Give the (group, label) pairs that one tool call counts for.

    Args:
        name: the tool's name.
        tool_input: the tool's input dict.

    Returns:
        A list of (group, label) pairs; a shell command that names 2 skill files gives 2 pairs.
    """
    if name == "Skill":
        return [("skill", str(tool_input.get("skill") or "?"))]
    if name in AGENT_TOOLS:
        return [("agent", str(tool_input.get("subagent_type") or "general-purpose"))]
    if name == "Read":
        found = SKILL_FILE.search(str(tool_input.get("file_path") or ""))
        return [("read", found.group(1))] if found else [("tool", name)]
    if name in SHELL_TOOLS:
        skills = sorted(set(SKILL_FILE.findall(str(tool_input.get("command") or ""))))
        return [("shell", skill) for skill in skills] or [("tool", name)]
    return [("tool", name)]


def count_files(paths):
    """Count the tool calls in the given files.

    Args:
        paths: the files to read.

    Returns:
        A pair: a dict (group -> Counter of label -> calls) and the list of files in which no tool call was found.
    """
    counts = {group: collections.Counter() for group in GROUPS}
    seen = set()
    empty = []
    for path in paths:
        calls = 0
        for value in json_values(path):
            for name, tool_input in tool_uses(value, seen):
                calls += 1
                for group, label in classify(name, tool_input):
                    counts[group][label] += 1
        if not calls:
            empty.append(path)
    return counts, empty


def report(counts, files):
    """Build the text report: one line for each label, the most used first."""
    lines = [f"skill use in {files} file(s)"]
    for group in GROUPS:
        total = sum(counts[group].values())
        lines.append(f"{group:6} {total} call(s)")
        lines += [f"  {calls:5}  {label}" for label, calls in counts[group].most_common()]
    return "\n".join(lines)


def self_test():
    """Check the counting on invented records: both file forms, a repeated id, and each group.

    Returns:
        The process exit code: 0 when every case passed, else 1.
    """
    import os
    import tempfile

    def use(call_id, name, **tool_input):
        """One invented tool_use block."""
        return {"type": "tool_use", "id": call_id, "name": name, "input": tool_input}

    blocks = [use("a", "Skill", skill="deliver"), use("b", "Read", file_path="/r/.claude/skills/handoff/SKILL.md"),
              use("c", "Bash", command="sed -n 1,9p .claude/skills/deliver/SKILL.md; cat x/skills/audit/SKILL.md"),
              use("d", "Agent", subagent_type="reviewer"), use("e", "Agent"), use("f", "Read", file_path="/r/AGENTS.md"),
              use("g", "Bash", command="git status"),
              use("i", "Bash", command='for f in a b; do grep x "$f/SKILL.md" x/audit/SKILL.md /r/myskills/z/SKILL.md; done')]  # not under skills/: no skill
    saved = "<other-session>\nnote\n" + json.dumps({"ccr": {"data": [{"assistant": {"message": {"content": blocks}}}]}}) + "\n</other-session>\n"
    log = "\n".join(json.dumps({"message": {"content": [block]}}) for block in blocks[:2] + [use("h", "Skill", skill="verify")])
    with tempfile.TemporaryDirectory() as folder:
        paths = [os.path.join(folder, "saved.txt"), os.path.join(folder, "log.jsonl")]
        for path, text in zip(paths, (saved, log)):
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(text)
        extra = {"pretty.json": json.dumps({"content": [use("p", "Skill", skill="audit")]}, indent=2),
                 "two.json": json.dumps([use("q", "Skill", skill="a")], indent=2) + "\n[]\n" + json.dumps([use("r", "Skill", skill="b")], indent=2),
                 "no_id.json": json.dumps([use("", "Skill", skill="c"), use("", "Skill", skill="c")]),
                 "scalar.json": "null\n", "empty.txt": "", "note.txt": "see [1] for details"}
        for name, text in extra.items():
            with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                handle.write(text)
        counts, empty = count_files(paths)
        more = {name: count_files([os.path.join(folder, name)]) for name in extra}
    want = {"skill": {"deliver": 1, "verify": 1}, "read": {"handoff": 1}, "shell": {"deliver": 1, "audit": 1},
            "agent": {"reviewer": 1, "general-purpose": 1}, "tool": {"Read": 1, "Bash": 2}}
    failed = [group for group in GROUPS if dict(counts[group]) != want[group]]
    for group in failed:
        print(f"FAIL  {group}: got {dict(counts[group])}, want {want[group]}")
    want_more = {"pretty.json": {"audit": 1}, "two.json": {"a": 1, "b": 1}, "no_id.json": {"c": 2}, "scalar.json": {}, "empty.txt": {}, "note.txt": {}}
    for name, (got, no_json) in more.items():
        if dict(got["skill"]) != want_more[name] or bool(no_json) != (name in ("scalar.json", "empty.txt", "note.txt")) or empty:
            failed.append(name)
            print(f"FAIL  {name}: got {dict(got['skill'])}, no JSON: {bool(no_json)}, want {want_more[name]}")
    print("skill_use self-test:", "FAIL" if failed else "PASS (5 groups; file forms: saved result, log, pretty-printed, 2 values, no id, no JSON)")
    return 1 if failed else 0


def main(argv):
    """Run the self-test, or print the report for the files named on the command line.

    Args:
        argv: the command-line arguments after the script name.

    Returns:
        The process exit code: 0 ok, 1 a failed self-test, 2 no file named or a file that cannot be read.
    """
    if "--test" in argv:
        return self_test()
    paths = [arg for arg in argv if not arg.startswith("--")]
    if not paths:
        print(__doc__.strip().splitlines()[0] + "\nRun: python3 scripts/skill_use.py FILE [FILE ...] [--json]")
        return 2
    try:
        counts, empty = count_files(paths)
    except OSError as error:
        print(f"skill_use: cannot read a file: {error}", file=sys.stderr)
        return 2
    print(json.dumps({group: dict(counts[group]) for group in GROUPS}, indent=1) if "--json" in argv else report(counts, len(paths)))
    for path in empty:
        print(f"WARN  no tool call found in {path} (no session record, or a format this script cannot read)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
