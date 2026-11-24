#!/usr/bin/env python3
"""The step reader and the step measures of scripts/check_instructions.py: the word lists and patterns, the numbered
list readers (Markdown and HTML), what counts as a procedure step, and the findings of one step.

Part of scripts/check_instructions.py (split out to keep each file under the line cap of docs/code-standard.md C4);
check_instructions.py imports every name here and re-exports it, so `check_instructions.<name>` keeps working. The
findings and the limits are described in the header of scripts/check_instructions.py.
Inputs:  the text of one file, or of one step. Outputs: steps as (line, text, kind) and finding messages.
Usage:   imported by scripts/check_instructions.py; it has no command line.
Prevents: a step that a person follows is read wrongly, so a too-long, vague or multi-action step passes the instructions check
Network: none.
Writes: none.
Credentials: none.
"""
import html
import html.parser
import re


STEP_WORDS = 60       # a step: one action, the thing on the screen, the next state and the cue (kit, 2026-11-21)
SENTENCE_WORDS = 20   # ASD-STE100 rule 5.1: a sentence in a procedure has at most 20 words


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
