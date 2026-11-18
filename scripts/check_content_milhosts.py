"""This project's military-host pattern and its linear-time finder for the content check (scripts/check_content_local.py
gives find_milhost to the kit's scanner; decision 2A, 2026-11-16, the same code as rhope-ops/RADE). The kit keeps its
own pattern and has no finder (kit decision of 2026-11-17), so this part is the project's own and lives in its own file.

What it does: MILHOST is the pattern for a host name in the US military top-level domain and for the DoD cloud tenant
hosts; milhosts(line) gives the matches of MILHOST.finditer(line) in linear time, from a model of the pattern, and
falls back to the pattern when the model and the pattern disagree.
Inputs:  one line of text. Outputs: the match objects of MILHOST, leftmost first; nothing is printed.
Network: none.
Writes: none.
Credentials: none.
Run:     not run alone; proved by `python3 scripts/check_content_local.py --test` (scripts/check_content_test_milhosts.py).
         Target: Python 3.8+.
"""
import bisect
import itertools
import re

MILHOST = re.compile(
    r"(?i)(?<![A-Za-z0-9])(?:(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+mil(?![A-Za-z0-9-]|\.[A-Za-z0-9])"   # any host under the military domain
    r"|(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*sharepoint-mil\.us\b|dod\.teams\.microsoft\.us\b)")    # DoD cloud tenant hosts
# A DNS label is 1-63 letters, digits or inside hyphens, so "word-" + ".mil" is not a host (the length cap stops runaway backtracking on long "a-a-a-" runs).

# MILHOST is the pattern; milhosts() finds its matches. A plain MILHOST.finditer tries every start after a "." or
# "-" and reads to the end of the run of labels, so its time grows with the square of the run ("a." * 5,000 took
# 1.2 s, 20,000 took 17.6 s). The pattern itself stays as it is (owner decision 2A, 2026-11-16).
_MIL_REGION = re.compile(r"(?i)[a-z0-9.-]+")  # a match holds only these characters, so it lies inside one run of them
_MIL_ANY = re.compile(r"(?i)mil|sharepoint-mil\.us|dod\.teams\.microsoft\.us")  # every match holds one of these
_MIL_END = re.compile(r"(?i)(?<=\.)mil(?![A-Za-z0-9-]|\.[A-Za-z0-9])")  # where the first branch can end
_MIL_SPM = re.compile(r"(?i)sharepoint-mil\.us\b")  # where the second branch can end
_MIL_DOD = re.compile(r"(?i)dod\.teams\.microsoft\.us\b")  # the third branch
_MIL_SHORT = 24  # a run this short goes to the pattern: its cost per run is small and fixed, below the model's set-up


def _milhost_model(line, r0, r1):
    """The anchors of one run of label characters (line[r0:r1]) for _milhost_walk: the segments between dots, their
    starts, the segments that stop a chain of labels, the segments where the first and second branch can end, and the
    starts and ends of matches with no label. Returns them as a tuple.

    Args:
        line: the line of text.
        r0: the start of the run in the line.
        r1: the end of the run in the line.

    Returns:
        The tuple (segs, pos, stops, end1, end2, zero_end, zero, chain).
    """
    segs = line[r0:r1].split(".")
    n = len(segs)
    pos = list(itertools.accumulate(map((1).__add__, map(len, segs)), initial=r0))  # pos[j]: start of segment j
    # stops: the segments that are not a whole label followed by "." (the last segment never is one)
    stops = [j for j, g in enumerate(segs) if not (0 < len(g) <= 63 and g[0] != "-" and g[-1] != "-")]
    if stops[-1:] != [n - 1]:
        stops.append(n - 1)
    end1 = {bisect.bisect_right(pos, m.start()) - 1 for m in _MIL_END.finditer(line, r0, r1 + 2)}
    end2, zero_end = [], {}  # end2: segments that are "sharepoint-mil" ("us" follows); zero_end: start -> end of a match with no label
    for rx in (_MIL_SPM, _MIL_DOD):
        for m in rx.finditer(line, r0, r1 + 2):
            s = m.start()
            if s == r0 or line[s - 1] in ".-":
                zero_end[s] = m.end()
                if rx is _MIL_SPM and (s == r0 or line[s - 1] == "."):
                    end2.append(bisect.bisect_right(pos, s) - 1)
    zero = sorted(zero_end)
    chain = sorted(end1.union(end2))  # anchors a chain of labels can reach
    return segs, pos, stops, end1, end2, zero_end, zero, chain


def _milhost_walk(line, r0, model):
    """Yield the (start, end) of each match in one run, leftmost first, from the anchors _milhost_model gives.

    Args:
        line: the line of text.
        r0: the start of the run in the line.
        model: the tuple _milhost_model gives.
    """
    segs, pos, stops, end1, end2, zero_end, zero, chain = model
    p, ci, zi = r0, 0, 0
    while True:
        best = None
        while ci < len(chain):  # the first chain anchor after p with a start at or after p gives the leftmost start
            k = chain[ci]
            if pos[k] > p:
                j = bisect.bisect_left(stops, k)  # segments stops[j - 1] .. k - 1 reach k; stops[j] ends their run
                i = max(stops[j - 1] if j else 0, bisect.bisect_right(pos, p) - 1)
                while i < k and best is None:  # at most 3 segments: the one at p, a run start, a whole label
                    g = segs[i]
                    if g and g[-1] != "-":
                        for x in range(max(0, len(g) - 63, p - pos[i]), len(g)):
                            if g[x] != "-" and (x == 0 or g[x - 1] == "-"):
                                best = pos[i] + x
                                break
                    i += 1
                if best is not None:  # the farthest end in the run: first branch, else second branch
                    stop = stops[j]
                    if stop in end1:
                        e = pos[stop] + 3
                    elif stop - 1 in end1:
                        e = pos[stop - 1] + 3
                    else:
                        e = pos[end2[bisect.bisect_left(end2, stop) - 1] + 1] + 2
                    break
            ci += 1
        while zi < len(zero) and zero[zi] < p:
            zi += 1
        if zi < len(zero) and (best is None or zero[zi] < best):  # it starts no chain, else best would be <= it
            best = zero[zi]
            e = zero_end[best]
        if best is None:
            break
        yield best, e
        p = e


def _milhost_spans(line):
    """The spans of MILHOST.finditer(line), from a model of the pattern. A match lies in one run of label characters.
    Split the run at its dots into segments. A match starts where the look-behind allows (at a segment start or after
    a "-"); its first label is the rest of that segment, each later label is a whole segment (1-63 characters, no "-"
    at either end) followed by "."; it ends at the farthest end of the first branch it reaches (_MIL_END), else of the
    second (_MIL_SPM), else it is the third branch (_MIL_DOD). finditer takes the leftmost start at or after the end of
    the last match. Only anchors (ends) and segment indices are visited, so the time is linear in the line.

    Args:
        line: the line of text.
    """
    for region in _MIL_REGION.finditer(line):
        r0, r1 = region.span()
        if r1 - r0 <= _MIL_SHORT:
            yield from (m.span() for m in MILHOST.finditer(line, r0, r1 + 2))  # it sees the 2 characters after the run
            continue
        if _MIL_ANY.search(line, r0, r1):
            yield from _milhost_walk(line, r0, _milhost_model(line, r0, r1))


def milhosts(line):
    """The matches of MILHOST.finditer(line) in linear time: each span of _milhost_spans, confirmed by the pattern in
    a window of the span and the 2 characters its look-aheads read. If the pattern does not confirm a span, or a span
    starts before the end of the last confirmed match (no real or random line in the tests does either), the plain
    pattern finds the rest of the line from that end. It does not recover a match before that end, and it catches no
    model error that every later span passes (a skipped match, a match that starts too late, a missed last match);
    the differential tests prove the model.

    Args:
        line: the line of text.
    """
    done = 0  # the end of the last confirmed match
    for s, e in _milhost_spans(line):
        m = MILHOST.match(line, s, e + 2)
        if s < done or m is None or m.end() != e:
            yield from MILHOST.finditer(line, done)
            return
        yield m
        done = e
