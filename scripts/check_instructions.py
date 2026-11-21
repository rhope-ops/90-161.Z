#!/usr/bin/env python3
"""Check the steps that a person reads and acts on (AGENTS.md "Instructions people follow"; the steps to write them:
.claude/skills/instructions/SKILL.md). It checks only what a script can measure; the fresh-reader test checks the rest.

Inputs:  the files that the `.check` lines `audit-instructions: <glob>` name (git-tracked files; `**` matches any
         folders), or the files named on the command line; a project's own module scripts/check_instructions_local.py.
What a step is: an item of a numbered list (Markdown `1.` or `1)`, HTML `<ol><li>`) in a list where at least half the
         items start with an action verb or a condition word (a numbered list of facts is not a procedure). A step
         with its own numbered list is a lead-in: its sub-items are the actions on one screen.
Findings (FILE:LINE: message; each one fails the check):
    long       a step over STEP_WORDS words, or a sentence over SENTENCE_WORDS words (ASD-STE100: 20 in a procedure)
    actions    two or more actions in one step (a lead-in with numbered actions on one screen is allowed)
    pointer    a pointer to another file, step or section ("see step 3", "as above", a link to a local file)
    vague      a vague word ("appropriate", "as needed", "should", "some", ...)
    wait       the step names a wait but not the state to wait for ("Wait until <what the person sees>")
    next       the step does not say what the person sees next ("You see ...", "The window ... opens")
    cue        the step does not say whether to wait, go on or note a value
Text in `code`, **bold** or "quotes" (the exact thing on the screen, or the exact text to type) counts as one word
and is not read for verbs, vague words or pointers.
A project's own module (optional; a module that cannot be loaded fails the check) can define:
    ACTION_VERBS, VAGUE, POINTERS   more verbs, and more regular expressions (lower-case text) for the two lists
    LIMITS                          {"step_words": n, "sentence_words": n}: only lower than the kit's values
    steps(path, text)               the steps of a file type the kit does not read: [(line, text, kind)], kind is
                                    "step", "lead" or "action"; None = the kit's parser
    extra_checks(path, line, text)  more findings for one step, as a list of messages
Usage:   python3 scripts/check_instructions.py [FILE ...]   check the files (default: the `.check` globs)
         python3 scripts/check_instructions.py --hook       Claude Code PreToolUse hook (.claude/settings.json): blocks a
                                                            Write or Edit of a matched file until this session loaded
                                                            the instructions skill (read from the transcript)
         python3 scripts/check_instructions.py --test       self-test (cases: scripts/check_instructions_test.py)
Exit 0 and "INSTRUCTIONS PASS" when there is no finding; 1 with the findings; 2 from --hook to block.
Network: none (it runs local git read commands).
Writes:  none; --hook without a readable transcript writes one marker file per session in .git/ (then it blocks
         only the first write of that session: a host with no transcript gets a reminder, not a proof).
Credentials: none.
"""
import argparse
import html
import html.parser
import importlib.util
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_settings  # noqa: E402 - the one reader of `.check` settings

STEP_WORDS = 60       # a step: one action, the thing on the screen, the next state and the cue (kit, 2026-11-21)
SENTENCE_WORDS = 20   # ASD-STE100 rule 5.1: a sentence in a procedure has at most 20 words
LOCAL = "scripts/check_instructions_local.py"
SKILL = ".claude/skills/instructions/SKILL.md"
SUFFIXES_HTML = (".html", ".htm")
ACTION_VERBS = frozenset({
    "accept", "add", "allow", "approve", "attach", "change", "check", "choose", "clear", "click", "close", "collapse",
    "connect", "copy", "delete", "deny", "disconnect", "double-click", "download", "drag", "drop", "edit", "enter",
    "expand", "fill", "find", "go", "insert", "install", "log", "look", "move", "open", "paste", "plug", "press", "pull",
    "push", "put", "read", "refresh", "reject", "reload", "remove", "rename", "replace", "restart", "restore",
    "right-click", "run", "save", "scroll", "select", "send", "set", "sign", "start", "stop", "submit", "switch", "tap",
    "turn", "type", "unplug", "upload", "use"})
LEAD_WORDS = {"if", "when", "after", "before", "once", "in", "on", "from", "at", "while", "wait", "do", "make"}
NOT_ACTION = re.compile(r"(?i)^(?:go on|go to the next step|stop here)\b")
VAGUE = [r"\bappropriate(?:ly)?\b", r"\bas (?:needed|necessary|required|applicable)\b", r"\bif (?:needed|necessary|possible)\b",
         r"\bwhere possible\b", r"\bproperly\b", r"\bcorrectly\b", r"\bsuitable\b", r"\brelevant\b", r"\bvarious\b",
         r"\bseveral\b", r"\bsome\b", r"\ba few\b", r"\ba while\b", r"\bsoon\b", r"\bshortly\b", r"\bquickly\b",
         r"\bsimply\b", r"\bjust\b", r"\beasily\b", r"\betc\b", r"\band so on\b", r"\bsomewhere\b", r"\bsomething\b",
         r"\bstuff\b", r"\bthings?\b", r"\bshould\b", r"\bmight\b", r"\bmaybe\b", r"\bperhaps\b",
         r"\bprobably\b", r"\busually\b", r"\bnormally\b", r"\btypically\b", r"\blikely\b", r"\btry to\b"]
POINTERS = [r"\bsee (?:step|section|chapter|above|below|page|the (?:previous|next|following|section|file|table|list|readme|docs?|guide))\b",
            r"\bsteps? \d+\b", r"\b(?:as|shown|described|listed|mentioned|explained|given) (?:above|below|earlier|before|previously)\b",
            r"\b(?:previous|preceding|earlier) (?:steps?|sections?|instructions?|list|chapters?)\b",
            r"\b(?:next|following|this|that|other) (?:steps?|sections?|instructions?|chapters?)\b", r"\bsections?\b", r"\breadme\b",
            r"\bgo back to\b", r"\brepeat (?:the |these |this )?steps?\b", r"\b[\w./-]+\.md\b"]
LOCAL_LINK = re.compile(r"\]\((?!https?://|mailto:)[^)\s]+\)")
WAIT_WORDS = re.compile(r"\b(?:wait|waiting|loading|takes|for (?:about )?(?:\d+|one|two|three|four|five|ten|fifteen|twenty|thirty) "
                        r"(?:secs?|seconds?|mins?|minutes?|hrs?|hours?)\b|for (?:about )?(?:a minute|an hour)\b|restarts?|restarting|reboots?|processing|"
                        r"syncing|in progress|spinner|progress bar)\b")
WAIT_STATE = re.compile(r"\bwait until\b|\bwait for\b[^.]*\b(?:to|until)\b|\bdo not [^.]*\buntil\b|\buntil you see\b")
NEXT_STATE = re.compile(r"\byou (?:now |will )?(?:see|get|hear)\b|\b(?:shows|opens|appears|closes|changes|turns|loads|"
                        r"starts|stops|ends|displays|disappears|goes away|comes up|is shown|are shown|is open|is closed)\b")
CUE = re.compile(r"\bwait\b|\bgo on\b|\bcontinue\b|\bnext step\b|\bwrite down\b|\bnote (?:the|down|this|it)\b|"
                 r"\bdone\b|\bfinished\b|\bcomplete\b|\bstop\b|\bdo not go on\b")
ITEM = re.compile(r"^(\s*)(\d+)[.)]\s+(.*)$")
FENCE = re.compile(r"^\s*(?:```|~~~)")
WORD = re.compile(r"[A-Za-z0-9][A-Za-z0-9'’-]*")
CLAUSES = re.compile(r"\s*[,;]?\s*(?:and\s+)?then\s+|;\s*|,\s+and\s+|\s+and\s+", re.IGNORECASE)
SENTENCES = re.compile(r"(?<=[.!?])\s+")
# A next-state span ("you see <the thing>", up to the next "and", "then" or mark): it names what is on the screen,
# so it is not read for pointers or wait words; the rest of the sentence is.
SEEN = re.compile(r"\byou (?:now |will )?see\b.*?(?=\s+(?:and|then)\s+|[,;:.!?]|$)")
TOKEN = " X "  # what code, bold and quoted text become: one word, no verb, no vague word
LEAD_SEP = "\n\x1e\n"  # between a lead-in's own text and the text of its actions (procedure_steps)


def glob_regex(pattern):
    """A regular expression for a path glob: `**/` any folders (or none), `**` anything, `*` and `?` inside a name.

    Args:
        pattern: the glob, relative to the repo root, with `/` between folders.

    Returns:
        A compiled regular expression that matches a whole path.
    """
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


def globs_of(root):
    """The `audit-instructions:` globs of the repo's `.check` (ValueError when a setting line is not valid)."""
    return check_settings.audit_settings(check_settings.pairs(check_settings.read(root, check_settings.CHECK)))["instructions"]


def matches(rel, globs):
    """True when the repo-relative path `rel` matches one of the globs."""
    return any(glob_regex(g).match(rel) for g in globs)


def tracked(root, globs):
    """The git-tracked files of the repo that match the globs, sorted.

    Args:
        root: the repo root.
        globs: the `audit-instructions:` globs.

    Returns:
        Repo-relative paths.
    """
    out = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], capture_output=True, text=True, check=True).stdout
    return sorted(p for p in out.split("\0") if p and matches(p, globs))


def plain(raw):
    """The text of a step with code, bold and quoted text as one word each and other markup removed (lower case)."""
    text = html.unescape(raw)
    text = re.sub(r"`[^`]*`|\*\*[^*]+\*\*|__[^_]+__|\"[^\"]*\"|“[^”]*”|‘[^’]*’", TOKEN, text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    return re.sub(r"[*_]", "", text).lower()


def count_actions(sentence, verbs=ACTION_VERBS):
    """The number of actions in one sentence: clauses (split on "then", "and", ";") whose first word, after a
    leading condition up to its comma, is one of `verbs`.

    Args:
        sentence: one sentence of a step, in plain text (plain()).
        verbs: the action verbs in force.

    Returns:
        The count of actions.
    """
    n = 0
    for clause in CLAUSES.split(sentence.strip()):
        clause = clause.strip(" ,.")
        if NOT_ACTION.match(clause):
            continue
        words = WORD.findall(clause)
        if words and words[0] in LEAD_WORDS and "," in clause:
            words = WORD.findall(clause.rsplit(",", 1)[1])
        n += bool(words) and words[0] in verbs
    return n


def markdown_items(text):
    """The numbered list items of a Markdown text, with their parents. Lines inside a fenced code block become one
    word of the item they are in; a bullet or a plain line indented under an item joins that item.

    Args:
        text: the Markdown text.

    Returns:
        Items as dicts: line (1-based), indent, parts (text pieces), parent (index or None), kids (count).
    """
    items, stack, fenced, blank = [], [], False, False
    for n, line in enumerate(text.expandtabs(4).splitlines(), 1):
        if FENCE.match(line):
            fenced = not fenced
            if stack:
                items[stack[-1]]["parts"].append(TOKEN)
            continue
        if fenced:
            continue
        m = ITEM.match(line)
        indent = len(line) - len(line.lstrip(" "))
        if m:
            while stack and items[stack[-1]]["indent"] >= indent:
                stack.pop()
            parent = stack[-1] if stack else None
            if parent is not None:
                items[parent]["kids"] += 1
            items.append({"line": n, "indent": indent, "parts": [m.group(3)], "parent": parent, "kids": 0})
            stack.append(len(items) - 1)
        elif not line.strip():
            blank = True
            continue
        elif stack and (indent > 0 or not blank):
            while len(stack) > 1 and items[stack[-1]]["indent"] >= indent:
                stack.pop()
            items[stack[-1]]["parts"].append(line.strip())
        else:
            stack = []
        blank = False
    return items


class _ListParser(html.parser.HTMLParser):
    """Collects the `<li>` items of `<ol>` lists in an HTML text, in the same form as markdown_items."""

    TOKEN_TAGS = {"code", "kbd", "samp", "b", "strong"}
    SKIP_TAGS = {"script", "style"}

    def __init__(self):
        """An empty parser: no items, no open list."""
        super().__init__(convert_charrefs=True)
        self.items, self.stack, self.ols, self.token, self.skip = [], [], [], 0, 0

    def handle_starttag(self, tag, attrs):
        """Open a list, an item, or a span whose text counts as one word.

        Args:
            tag: the tag name.
            attrs: the attributes, as (name, value) pairs.
        """
        if tag in ("ol", "ul"):
            self.ols.append((tag, len(self.stack)))
        elif tag == "li" and self.ols and self.ols[-1][0] == "ol":
            del self.stack[self.ols[-1][1]:]  # an <li> with no end tag ends here
            parent = self.stack[-1] if self.stack else None
            if parent is not None:
                self.items[parent]["kids"] += 1
            self.items.append({"line": self.getpos()[0], "indent": len(self.stack), "parts": [], "parent": parent, "kids": 0})
            self.stack.append(len(self.items) - 1)
        elif tag in self.TOKEN_TAGS:
            self.token += 1
        elif tag in self.SKIP_TAGS:
            self.skip += 1
        elif tag == "a" and self.stack:
            href = dict(attrs).get("href") or ""
            self.items[self.stack[-1]]["parts"].append(f"[link]({href})")

    def handle_endtag(self, tag):
        """Close the list, item or span that `tag` ends.

        Args:
            tag: the tag name.
        """
        if tag in ("ol", "ul") and self.ols:
            del self.stack[self.ols.pop()[1]:]
        elif tag == "li" and self.stack and self.ols and self.ols[-1][0] == "ol" and len(self.stack) > self.ols[-1][1]:
            self.stack.pop()
        elif tag in self.TOKEN_TAGS and self.token:
            self.token -= 1
            if self.stack:
                self.items[self.stack[-1]]["parts"].append(TOKEN)
        elif tag in self.SKIP_TAGS and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        """Add text to the open item (text in a code or bold span is one word, added when the span ends)."""
        if self.stack and not self.token and not self.skip:
            self.items[self.stack[-1]]["parts"].append(data)


def html_items(text):
    """The `<ol>` list items of an HTML text, in the form of markdown_items."""
    parser = _ListParser()
    parser.feed(text)
    parser.close()
    return parser.items


def first_word(raw):
    """The first word of a step's plain text, or "" when it has none."""
    words = WORD.findall(plain(raw))
    return words[0] if words else ""


def procedure_steps(items, verbs=ACTION_VERBS):
    """The steps of the items: (line, text, kind) for each item of a list that is a procedure. A list (the items
    that share a parent) is a procedure when at least half its items start with an action verb or a condition word;
    the sub-items of a step in a procedure are its actions on one screen.

    Args:
        items: the items, as markdown_items or html_items gives them.
        verbs: the action verbs in force.

    Returns:
        A list of (line, text, kind); kind is "step", "lead" (a step with numbered actions) or "action".
    """
    groups = {}
    for i, item in enumerate(items):
        groups.setdefault(item["parent"], []).append(i)
    in_procedure = set()
    for parent, members in groups.items():
        starts = sum(first_word(" ".join(items[i]["parts"])) in verbs | LEAD_WORDS for i in members)
        if parent in in_procedure or 2 * starts >= len(members):
            in_procedure.update(members)
    out = []
    for i, item in enumerate(items):
        if i not in in_procedure:
            continue
        kind = "lead" if item["kids"] else ("action" if item["parent"] in in_procedure else "step")
        text = " ".join(item["parts"])
        if kind == "lead":  # the next state and the cue can follow the actions: read them with the lead-in
            text += LEAD_SEP + " ".join(" ".join(items[k]["parts"]) for k in range(len(items)) if items[k]["parent"] == i)
        out.append((item["line"], text, kind))
    return out


def step_findings(raw, kind, rules):
    """The findings of one step.

    Args:
        raw: the step text as written (markup kept).
        kind: "step", "lead" or "action" (procedure_steps).
        rules: the lists and limits in force (load_rules).

    Returns:
        A list of messages.
    """
    own_raw = raw.split(LEAD_SEP, 1)[0]
    own, text, out = plain(own_raw), plain(raw), []
    sentences = [s for s in SENTENCES.split(own) if WORD.search(s)]
    words = len(WORD.findall(own))
    if words > rules["step_words"]:
        out.append(f"long: the step has {words} words (at most {rules['step_words']}): split it into steps")
    for s in sentences:
        if len(WORD.findall(s)) > rules["sentence_words"]:
            out.append(f"long: a sentence has {len(WORD.findall(s))} words (at most {rules['sentence_words']}): \"{s.strip()[:60]}\"")
    acts = sum(count_actions(s, rules["verbs"]) for s in sentences)
    if acts > 1:
        out.append(f"actions: {acts} actions in one step: give each action its own step, or number the actions on one screen")
    told = SEEN.sub(" ", own)
    pointers = [p for p in rules["pointers"] if re.search(p, told)] + (["a link to a local file or section"] if LOCAL_LINK.search(own_raw) else [])
    if pointers:
        out.append(f"pointer: the step points to another file, step or section ({pointers[0]}): put the words here")
    vague = sorted({m.group(0) for p in rules["vague"] for m in re.finditer(p, own)})
    if vague:
        out.append(f"vague: {', '.join(vague)}: name the exact thing, number or condition")
    if kind == "action":
        return out
    if WAIT_WORDS.search(SEEN.sub(" ", text)) and not WAIT_STATE.search(text):
        out.append("wait: the step names a wait but not the state to wait for: write \"Wait until <what the person sees>.\"")
    if not NEXT_STATE.search(text):
        out.append("next: the step does not say what the person sees next: write \"You see <the thing on the screen>.\"")
    if not CUE.search(text):
        out.append("cue: the step does not say whether to wait, go on or note a value: end with \"Wait until ...\", \"Go on.\" or \"Write down ...\"")
    return out


def load_local(root):
    """The project's own module (LOCAL), or None when it does not exist. An error in the module goes up: it fails."""
    path = root / LOCAL
    if not path.is_file():
        return None
    spec = importlib.util.spec_from_file_location("check_instructions_local", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_rules(local):
    """The lists and limits in force: the kit's, with the project's additions and lower limits.

    Args:
        local: the project's module, or None.

    Returns:
        A dict: verbs, vague, pointers, step_words, sentence_words, steps (a function or None), extra (a function or None).
    """
    limits = dict(getattr(local, "LIMITS", {}) or {})
    unknown = set(limits) - {"step_words", "sentence_words"}
    if unknown:
        raise ValueError(f"{LOCAL}: LIMITS has unknown keys: {', '.join(sorted(unknown))}")
    return {"verbs": ACTION_VERBS | set(getattr(local, "ACTION_VERBS", ())),
            "vague": VAGUE + list(getattr(local, "VAGUE", ())), "pointers": POINTERS + list(getattr(local, "POINTERS", ())),
            "step_words": min(STEP_WORDS, int(limits.get("step_words", STEP_WORDS))),
            "sentence_words": min(SENTENCE_WORDS, int(limits.get("sentence_words", SENTENCE_WORDS))),
            "steps": getattr(local, "steps", None), "extra": getattr(local, "extra_checks", None)}


def check_file(path, text, rules):
    """The findings of one file, as "PATH:LINE: message" lines.

    Args:
        path: the path to print (repo-relative).
        text: the file's text.
        rules: the lists and limits in force (load_rules).

    Returns:
        A list of finding lines.
    """
    steps = rules["steps"](path, text) if rules["steps"] else None
    if steps is None:
        items = html_items(text) if path.lower().endswith(SUFFIXES_HTML) else markdown_items(text)
        steps = procedure_steps(items, rules["verbs"])
    out = []
    for line, raw, kind in steps:
        found = step_findings(raw, kind, rules) + (list(rules["extra"](path, line, raw)) if rules["extra"] else [])
        out += [f"{path}:{line}: {msg}" for msg in found]
    return out


def run_check(root, names):
    """Check the named files, or the files the `.check` globs match. Prints the findings and a last line.

    Args:
        root: the repo root.
        names: file paths from the command line (may be empty).

    Returns:
        The exit code: 0 with no finding, 1 otherwise.
    """
    try:
        local = load_local(root)
        rules = load_rules(local)
        files = list(names) or tracked(root, globs_of(root))
    except Exception as err:  # noqa: BLE001 - a broken setting or module fails the check, never skips it
        print(f"INSTRUCTIONS FAIL: {err}")
        return 1
    if not files:
        print("INSTRUCTIONS PASS: no instruction files (name them with `audit-instructions: <glob>` lines in .check)")
        return 0
    findings = []
    for rel in files:
        findings += check_file(rel, (root / rel).read_text(encoding="utf-8", errors="replace"), rules)
    print("\n".join(findings + [f"INSTRUCTIONS {'FAIL' if findings else 'PASS'}: {len(findings)} findings in {len(files)} files"]))
    return 1 if findings else 0


def skill_loaded(transcript):
    """True when the session transcript (Claude Code JSONL) shows a load of the instructions skill after its last
    compaction: a Skill tool call for "instructions", or a Read of SKILL with no line limit.

    Args:
        transcript: the path of the transcript file.

    Returns:
        True or False; OSError when the file cannot be read.
    """
    loaded = False
    with open(transcript, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "compact_boundary" in line and '"subtype"' in line:
                loaded = False
                continue
            if "instructions" not in line or '"tool_use"' not in line:
                continue
            try:
                content = json.loads(line).get("message", {}).get("content", [])
            except (ValueError, AttributeError):
                continue
            for part in content if isinstance(content, list) else []:
                if not isinstance(part, dict) or part.get("type") != "tool_use":
                    continue
                args = part.get("input") or {}
                if part.get("name") == "Skill" and str(args.get("skill", "")).split(":")[-1] == "instructions":
                    loaded = True
                elif (part.get("name") == "Read" and str(args.get("file_path", "")).endswith(SKILL)
                      and not args.get("limit") and not args.get("offset")):
                    loaded = True
    return loaded


def hook_target(event):
    """The file that a Write, Edit, MultiEdit or NotebookEdit call changes.

    Args:
        event: the hook event (tool_name, cwd, tool_input).

    Returns:
        (repo root, repo-relative path), or None for another tool or a file outside a repo.
    """
    args = event.get("tool_input") or {}
    target = args.get("file_path") or args.get("notebook_path")
    if event.get("tool_name") not in ("Write", "Edit", "MultiEdit", "NotebookEdit") or not target:
        return None
    cwd = Path(event.get("cwd") or ".")
    top = subprocess.run(["git", "-C", str(cwd), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if top.returncode != 0:
        return None
    root = Path(top.stdout.strip()).resolve()
    path = (cwd / target).resolve()
    try:
        return root, path.relative_to(root).as_posix()
    except ValueError:
        return None


def run_hook(stream):
    """The PreToolUse hook: exit 2 (block) for a change to a matched file before the skill is loaded.

    Args:
        stream: the hook input (JSON).

    Returns:
        The exit code: 0 lets the call run, 2 blocks it (the reason goes to stderr).
    """
    try:
        event = json.load(stream)
        found = hook_target(event)
        if found is None or found[1] == check_settings.CHECK:
            return 0  # `.check` itself is never blocked here, so a broken setting line can be fixed
        root, rel = found
    except Exception as err:  # noqa: BLE001 - any error blocks: the hook fails closed
        print(f"BLOCKED by scripts/check_instructions.py --hook: {err}", file=sys.stderr)
        return 2
    try:
        globs = globs_of(root)
    except ValueError as err:  # a broken `.check` line, or a `.check` that is not UTF-8: scripts/check.sh fails on it; it must not block every write
        print(f"WARN scripts/check_instructions.py --hook: {err}", file=sys.stderr)
        return 0
    except Exception as err:  # noqa: BLE001 - `.check` cannot be read: block (fail closed)
        print(f"BLOCKED by scripts/check_instructions.py --hook: {err}", file=sys.stderr)
        return 2
    if not matches(rel, globs):
        return 0
    try:
        if skill_loaded(event.get("transcript_path") or ""):
            return 0
    except OSError:  # no transcript: block the first write of this session only, and leave a marker
        marker = root / ".git" / f"instructions-hook-{re.sub(r'[^A-Za-z0-9_-]', '', str(event.get('session_id', ''))) or 'none'}"
        if marker.exists():
            return 0
        marker.touch()
    print(f"BLOCKED: {rel} holds instructions that a person follows (.check: audit-instructions). Load the skill "
          f"`instructions` in full first: the Skill tool with skill \"instructions\", or Read {SKILL} with no line limit. "
          "Then write the text again.", file=sys.stderr)
    return 2


def main():
    """Parse the command line and run the check, the hook or the self-test.

    Returns:
        The exit code.
    """
    ap = argparse.ArgumentParser(description="Check the steps that a person follows (AGENTS.md \"Instructions people follow\").")
    ap.add_argument("files", nargs="*", help="files to check (default: the audit-instructions globs of .check)")
    ap.add_argument("--hook", action="store_true", help="the Claude Code PreToolUse hook (reads the event on stdin)")
    ap.add_argument("--test", action="store_true", help="self-test")
    args = ap.parse_args()
    if args.hook:
        return run_hook(sys.stdin)
    if args.test:
        import check_instructions_test
        return check_instructions_test.run()
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    root = Path(top.stdout.strip() or ".").resolve()
    return run_check(root, [os.path.relpath(Path(n).resolve(), root) for n in args.files])


if __name__ == "__main__":
    sys.exit(main())
