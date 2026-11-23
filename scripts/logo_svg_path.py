#!/usr/bin/env python3
"""Read the path data of the 90-161.Z logo SVG for scripts/logo_svg.py (split from it, 2026-11-23, for the 450-line code
standard cap C4; no change in what it reads).

What it reads: the "d" text of a <path>: absolute M, L, H, V, Q, C, A and Z only. Curves (Q, C) are cut into fixed straight
steps, so every machine reads the same shapes. Any other command stops with a "logo_draw:" message.
Usage: import logo_svg_path; parse_path(d) and path_segments(d) return sub-paths; in_range(v) checks a number's size.
Network: none.
Writes: none.
Credentials: none.
Run target: Python 3.8+, standard library only.
"""
import math
import re

STEPS = {'Q': 8, 'C': 16}   # straight steps per curve command (fixed, so every machine cuts the same way)
LIMIT = 1e6   # the largest size of any number or matrix entry (the logo uses 0 to 512; huge values would overflow)


def in_range(v):
    """Return True when v is a finite number from -LIMIT to LIMIT (nan, inf and huge values overflow the drawing)."""
    return math.isfinite(v) and abs(v) <= LIMIT


def path_segments(d):
    """Return the sub-paths for a path's "d" text (see parse_path), with a clean stop for bad numbers.

    Args:
        d: the path text, or None.

    Returns:
        The list of sub-paths. Stops with a message, not a Python error, when a command has too few numbers or a letter
        where a number belongs.
    """
    try:
        return parse_path(d)
    except (IndexError, ValueError, TypeError):
        raise SystemExit('logo_draw: a path command has too few or bad numbers: %r' % d)


def take(tokens, k, n):
    """Return n numbers from tokens[k:] as floats; raise IndexError (turned into a message) when there are fewer."""
    vals = tokens[k:k + n]
    if len(vals) != n or any(re.fullmatch(r'[A-Za-z]', v) for v in vals):
        raise IndexError(n)
    nums = [float(v) for v in vals]
    if not all(in_range(v) for v in nums):
        raise ValueError(vals)   # nan or inf: path_segments turns this into the "too few or bad numbers" message
    return nums


def parse_path(d):
    """Return the sub-paths of a path's "d" text: a list of dicts with 'segs' (each ('line', p0, p1) or ('arc', center,
    radius, start angle, sweep angle)), 'closed' (ends with Z) and 'joins' (the count of commands, where a stroke can
    have a corner; the straight steps of one curve meet smoothly and count once). Only absolute M, L, H, V, Q, C, A
    and Z are allowed; numbers after a command repeat it (after M they are L), as SVG reads them.

    Args:
        d: the path text, or None.

    Returns:
        The list of sub-paths. Stops with a message for a path that does not start with M, or a command after Z
        that is not M.
    """
    tokens = re.findall(r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', d or '')
    if not tokens or tokens[0] != 'M':
        raise SystemExit('logo_draw: a path must start with M (found %r)' % (tokens[0] if tokens else 'nothing'))
    subs, sub, pos, start, k, cmd = [], None, None, None, 0, None
    while k < len(tokens):
        if re.fullmatch(r'[A-Za-z]', tokens[k]):
            cmd = tokens[k]; k += 1
            if sub is not None and sub['closed'] and cmd != 'M':
                raise SystemExit('logo_draw: after Z a path must go on with M (found %r)' % cmd)
        elif cmd in (None, 'Z'):
            raise IndexError(cmd)   # a number with no command before it
        elif cmd == 'M':
            cmd = 'L'   # extra pairs after M are lines
        if cmd == 'M':
            pos = start = tuple(take(tokens, k, 2)); k += 2
            sub = {'segs': [], 'closed': False, 'joins': 0}
            subs.append(sub)
        elif cmd in 'LHV':
            n = 2 if cmd == 'L' else 1
            vals = take(tokens, k, n); k += n
            new = tuple(vals) if cmd == 'L' else ((vals[0], pos[1]) if cmd == 'H' else (pos[0], vals[0]))
            sub['segs'].append(('line', pos, new)); sub['joins'] += 1; pos = new
        elif cmd in 'QC':
            n = 4 if cmd == 'Q' else 6
            vals = take(tokens, k, n); k += n
            pts = [pos] + [(vals[i], vals[i + 1]) for i in range(0, n, 2)]
            steps = STEPS[cmd]
            prev = pos
            for i in range(1, steps + 1):
                p = bezier(pts, i / steps)
                sub['segs'].append(('line', prev, p)); prev = p
            sub['joins'] += 1; pos = pts[-1]
        elif cmd == 'A':
            rx, ry, rot, large, sweep, x, y = take(tokens, k, 7); k += 7
            if rx != ry or rot != 0:
                raise SystemExit('logo_draw: only circular arcs without rotation are supported')
            sub['segs'].append(arc_segment(pos, (x, y), rx, bool(large), bool(sweep))); sub['joins'] += 1; pos = (x, y)
        elif cmd == 'Z':
            sub['segs'].append(('line', pos, start)); sub['joins'] += 1; sub['closed'] = True; pos = start
        else:
            raise SystemExit('logo_draw: path command %r is not supported (only absolute M L H V Q C A Z)' % cmd)
    return subs


def bezier(pts, t):
    """Return the point at t (0 to 1) on a quadratic (3 points) or cubic (4 points) Bezier curve."""
    u = 1 - t
    if len(pts) == 3:
        w = (u * u, 2 * u * t, t * t)
    else:
        w = (u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t)
    return (sum(wi * p[0] for wi, p in zip(w, pts)), sum(wi * p[1] for wi, p in zip(w, pts)))


def arc_segment(p0, p1, r, large, sweep):
    """Return the arc segment for an SVG arc command (the endpoint-to-center conversion of the SVG specification, for
    a circle).

    Args:
        p0: the start point (x, y).
        p1: the end point (x, y).
        r: the radius.
        large: the large-arc flag (True: the arc of more than 180 degrees).
        sweep: the sweep flag (True: the way of rising angles, clockwise on screen with y down).

    Returns:
        ('arc', center, r, start angle, sweep angle); a positive sweep angle goes the way of rising angles. Stops with
        a message for a radius of 0 or less, or an end point equal to the start point.
    """
    mx, my = (p0[0] - p1[0]) / 2, (p0[1] - p1[1]) / 2
    d2 = mx * mx + my * my
    if d2 == 0 or r <= 0:
        raise SystemExit('logo_draw: an arc needs a radius above 0 and an end point different from its start point')
    f = math.sqrt(max(0.0, r * r / d2 - 1)) * (-1 if large == sweep else 1)
    cx = (p0[0] + p1[0]) / 2 + f * my
    cy = (p0[1] + p1[1]) / 2 - f * mx
    a0 = math.atan2(p0[1] - cy, p0[0] - cx)
    da = (math.atan2(p1[1] - cy, p1[0] - cx) - a0) % (2 * math.pi)
    if not sweep:
        da -= 2 * math.pi
    return ('arc', (cx, cy), r, a0, da)
