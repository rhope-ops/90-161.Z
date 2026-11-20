#!/usr/bin/env python3
"""Read the 90-161.Z logo SVG into shapes for scripts/logo_draw.py (split from logo_draw.py for the Delta logo, the PFM,
2026-11-19; the code standard caps a file at 600 lines).

What it reads: the subset of SVG that the logo uses (the list is in scripts/logo_draw.py). Any other element, attribute,
path command or transform stops with a "logo_draw:" message, so a new logo design cannot be drawn wrong in silence.
Curves (Q, C) are cut into fixed straight steps, so every machine reads the same shapes.
Usage: import logo_svg; logo_svg.shapes(svg_text) -> list of shape dicts; invert() and apply() map points.
Network: none.
Writes: none.
Credentials: none.
Run target: Python 3.8+, standard library only.
"""
import math
import re
import xml.etree.ElementTree as ET

NS = '{http://www.w3.org/2000/svg}'
STEPS = {'Q': 8, 'C': 16}   # straight steps per curve command (fixed, so every machine cuts the same way)
LIMIT = 1e6   # the largest size of any number or matrix entry (the logo uses 0 to 512; huge values would overflow)
IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)   # an affine matrix (a, b, c, d, e, f) as in SVG matrix()

# Paint attributes a <g> passes on to its children, with the SVG default for each.
INHERITED = {'fill': '#000000', 'fill-opacity': '1', 'stroke': 'none', 'stroke-width': '1', 'stroke-linecap': 'butt',
             'stroke-linejoin': 'miter'}
GROUP_ATTRS = set(INHERITED) | {'transform', 'aria-hidden'}
GEOMETRY = {'circle': {'cx', 'cy', 'r'}, 'line': {'x1', 'y1', 'x2', 'y2'}, 'path': {'d'}}
SHAPE_ATTRS = set(INHERITED) | {'transform', 'stroke-dasharray', 'clip-path'}


# ---------------------------------------------------------------- reading the SVG ------------------------------------

def shapes(svg_text):
    """Read the SVG and return its painted shapes in order.

    Args:
        svg_text: the SVG file's text.

    Returns:
        A list of dicts: kind ('circle' or 'path'), the geometry in the shape's own coordinates, fill and stroke colors
        (None or (r, g, b) 0-255), fill opacity, stroke width, dash list, the clip rectangles (or None), and the matrix
        from the shape's coordinates to the viewBox. Stops with a "logo_draw:" message for anything it does not handle.
    """
    try:
        root = ET.fromstring(svg_text)
    except ET.ParseError as e:
        raise SystemExit('logo_draw: the SVG is not well-formed XML (%s)' % e)
    if root.get('viewBox') != '0 0 512 512':
        raise SystemExit('logo_draw: the viewBox must be 0 0 512 512')
    clips = {c.get('id'): [clip_rect(r) for r in c] for c in root.iter(NS + 'clipPath') if refuse_clip(c)}
    out = []
    walk(root, dict(INHERITED), IDENTITY, clips, out)
    return out


def walk(parent, paint, matrix, clips, out):
    """Add the shapes under `parent` to `out`, in document order.

    Args:
        parent: the <svg> or <g> element.
        paint: the paint attributes the children inherit (INHERITED keys).
        matrix: the matrix from the children's coordinates to the viewBox.
        clips: the clip rectangles by clipPath id.
        out: the list of shapes to add to.
    """
    for el in parent:
        tag = el.tag.replace(NS, '')
        if tag in ('title', 'defs', 'desc'):
            continue
        if tag == 'g':
            extra = set(el.attrib) - GROUP_ATTRS
            if extra:
                raise SystemExit('logo_draw: attribute(s) %s on <g> are not supported' % sorted(extra))
            inner = dict(paint, **{k: v for k, v in el.attrib.items() if k in INHERITED})
            walk(el, inner, combine(matrix, el.get('transform', '')), clips, out)
            continue
        if tag not in GEOMETRY:
            raise SystemExit('logo_draw: element <%s> is not supported' % tag)
        extra = set(el.attrib) - GEOMETRY[tag] - SHAPE_ATTRS
        if extra:
            raise SystemExit('logo_draw: attribute(s) %s on <%s> are not supported' % (sorted(extra), tag))
        out.append(make_shape(el, tag, dict(paint, **{k: v for k, v in el.attrib.items() if k in INHERITED}),
                              combine(matrix, el.get('transform', '')), clips))


def make_shape(el, tag, paint, matrix, clips):
    """Return the shape dict for one <circle>, <line> or <path> (see shapes()), after the refusal checks.

    Args:
        el: the shape element.
        tag: 'circle', 'line' or 'path'.
        paint: the shape's paint attributes after inheritance (INHERITED keys).
        matrix: the matrix from the shape's coordinates to the viewBox.
        clips: the clip rectangles by clipPath id.

    Returns:
        The shape dict. Stops with a message for anything the drawing does not handle.
    """
    s = {'kind': 'circle' if tag == 'circle' else 'path', 'fill': color(paint['fill']),
         'fill_op': opacity(paint['fill-opacity']), 'stroke': color(paint['stroke']),
         'width': number(paint['stroke-width'], 'stroke-width'),
         'dash': dash_list(el.get('stroke-dasharray', '')), 'clip': None, 'm': matrix}
    if el.get('clip-path'):
        s['clip'] = find_clip(clips, el.get('clip-path'))
    if tag == 'circle':
        s['c'] = (number(el.get('cx'), 'cx'), number(el.get('cy'), 'cy'))
        s['r'] = number(el.get('r'), 'r')
    elif tag == 'line':
        s['fill'] = None   # a line has no inside
        p0 = (number(el.get('x1', '0'), 'x1'), number(el.get('y1', '0'), 'y1'))
        p1 = (number(el.get('x2', '0'), 'x2'), number(el.get('y2', '0'), 'y2'))
        s['subs'] = [{'segs': [('line', p0, p1)], 'closed': False, 'joins': 0}]
    else:
        s['subs'] = path_segments(el.get('d'))
        if not any(sub['segs'] for sub in s['subs']):
            raise SystemExit('logo_draw: a path needs at least one segment after M (it would draw nothing)')
    refuse_unsupported(s, tag, paint)
    refuse_fill(s)
    return s


def refuse_unsupported(s, tag, paint):
    """Stop when a shape's stroke needs what this drawing does not handle: only round caps and joins (the distance
    method draws them round), and a two-value dash only on a circle.

    Args:
        s: the shape dict.
        tag: 'circle', 'line' or 'path'.
        paint: the shape's paint attributes after inheritance.
    """
    if s['stroke'] is not None:
        if tag == 'circle':
            open_end, corners = bool(s['dash']), False
        else:
            open_end = any(not sub['closed'] for sub in s['subs'])   # a stroke with free ends
            corners = any(sub['joins'] > 1 or (sub['closed'] and sub['joins']) for sub in s['subs'])
        if open_end and paint['stroke-linecap'] != 'round':
            raise SystemExit('logo_draw: a stroke with free ends needs stroke-linecap="round" (other caps are not drawn)')
        if corners and paint['stroke-linejoin'] != 'round':
            raise SystemExit('logo_draw: a stroke with corners needs stroke-linejoin="round" (other joins are not drawn)')
    if s['dash'] and (tag != 'circle' or len(s['dash']) != 2):
        raise SystemExit('logo_draw: stroke-dasharray needs two values and works on a <circle> only')


def find_clip(clips, text):
    """Return the clip rectangles for a clip-path="url(#id)" value. Stops with a message when the value is not url(#id)
    or the id is unknown.

    Args:
        clips: the clip rectangles by clipPath id.
        text: the attribute value.

    Returns:
        The list of rectangles.
    """
    m = re.fullmatch(r'url\(#([\w-]+)\)', text)
    if m is None:
        raise SystemExit('logo_draw: clip-path %r is not of the form url(#id)' % text)
    if m.group(1) not in clips:
        raise SystemExit('logo_draw: clip-path refers to #%s, which is no <clipPath> in the file' % m.group(1))
    return clips[m.group(1)]


def refuse_fill(s):
    """Stop when a filled path cannot be filled correctly. Each sub-path of a fill needs Z, or it would silently get no
    fill; the fill test handles straight steps only, not arcs.

    Args:
        s: a shape from make_shape().
    """
    if s['fill'] is None or s['kind'] != 'path':
        return
    if not all(sub['closed'] for sub in s['subs']):
        raise SystemExit('logo_draw: a filled path must end each sub-path with Z (an open path would get no fill); '
                         'use fill="none" for a line')
    if any(g[0] == 'arc' for sub in s['subs'] for g in sub['segs']):
        raise SystemExit('logo_draw: a filled path with an arc (A) is not supported; fill="none" and a stroke work')


def refuse_clip(clip):
    """Stop when a <clipPath> holds anything but plain <rect> elements or has attributes other than its id; True."""
    if not len(clip):
        raise SystemExit('logo_draw: an empty <clipPath> is not supported (it would hide the shape)')
    if set(clip.attrib) - {'id'}:
        raise SystemExit('logo_draw: <clipPath> attribute(s) %s are not supported' % sorted(set(clip.attrib) - {'id'}))
    for r in clip:
        if r.tag != NS + 'rect' or set(r.attrib) - {'x', 'y', 'width', 'height'}:
            raise SystemExit('logo_draw: a <clipPath> may hold only <rect x y width height> elements')
    return True


def clip_rect(r):
    """Return (x, y, width, height) of a clip <rect>."""
    try:
        vals = tuple(float(r.get(k)) for k in ('x', 'y', 'width', 'height'))
        if not all(in_range(v) for v in vals):
            raise ValueError(vals)
        return vals
    except (TypeError, ValueError):
        raise SystemExit('logo_draw: a clip <rect> needs x, y, width and height as plain numbers')


def number(text, name):
    """Return float(text), or stop with a message naming the attribute (also for nan and inf)."""
    try:
        v = float(text)
    except (TypeError, ValueError):
        v = math.nan
    if not in_range(v):
        raise SystemExit('logo_draw: %s=%r is not a plain number from -%g to %g' % (name, text, LIMIT, LIMIT))
    return v


def in_range(v):
    """Return True when v is a finite number from -LIMIT to LIMIT (nan, inf and huge values overflow the drawing)."""
    return math.isfinite(v) and abs(v) <= LIMIT


def dash_list(text):
    """Return the numbers of a stroke-dasharray value.

    Args:
        text: the attribute value ('' for none); numbers split by spaces or commas, as SVG allows.

    Returns:
        The list of floats ([] for none). Stops with a message for a bad number, a negative one, or a pattern whose
        sum is 0 (it would have no length).
    """
    vals = [number(x, 'stroke-dasharray') for x in re.split(r'[\s,]+', text.strip()) if x]
    if vals and (min(vals) < 0 or sum(vals) < 0.01):
        raise SystemExit('logo_draw: stroke-dasharray %r needs numbers of 0 or more with a sum of 0.01 or more' % text)
    return vals


def opacity(text):
    """Return a fill-opacity value from 0 to 1, or stop with a message."""
    v = number(text, 'fill-opacity')
    if not 0 <= v <= 1:
        raise SystemExit('logo_draw: fill-opacity %r is not from 0 to 1' % text)
    return v


def color(text):
    """Return (r, g, b) for "#RRGGBB", or None for "none"."""
    if text == 'none':
        return None
    if not re.fullmatch(r'#[0-9A-Fa-f]{6}', text):
        raise SystemExit('logo_draw: color %r is not #RRGGBB' % text)
    return tuple(int(text[k:k + 2], 16) for k in (1, 3, 5))


# ---------------------------------------------------------------- transforms -----------------------------------------

def multiply(m, n):
    """Return the matrix m x n (n is applied first, then m)."""
    a, b, c, d, e, f = m
    a2, b2, c2, d2, e2, f2 = n
    return (a * a2 + c * b2, b * a2 + d * b2, a * c2 + c * d2, b * c2 + d * d2, a * e2 + c * f2 + e, b * e2 + d * f2 + f)


def combine(matrix, text):
    """Return the parent matrix times an element's transform.

    Args:
        matrix: the parent's matrix to the viewBox.
        text: the element's transform attribute ('' for none).

    Returns:
        The product. Stops with a message when an entry grows past LIMIT (nested scales would overflow the drawing).
    """
    m = multiply(matrix, parse_transform(text))
    if not all(in_range(v) for v in m):
        raise SystemExit('logo_draw: the transforms multiply to a size past %g (%r)' % (LIMIT, text))
    return m


def parse_transform(text):
    """Return the matrix of a transform attribute: translate, rotate (with an optional centre), scale and matrix, in
    order.

    Args:
        text: the transform attribute ('' for none).

    Returns:
        The matrix (a, b, c, d, e, f). Stops with a message for any other function (skewX, skewY), bad numbers or a
        transform that flattens the shape (determinant 0).
    """
    m = IDENTITY
    pos = 0
    for f in re.finditer(r'\s*([a-zA-Z]+)\s*\(([^)]*)\)\s*,?', text):
        if f.start() != pos:
            break
        pos = f.end()
        name = f.group(1)
        try:
            v = [float(x) for x in re.split(r'[\s,]+', f.group(2).strip()) if x]
            if not all(in_range(x) for x in v):
                raise ValueError(text)
        except ValueError:
            raise SystemExit('logo_draw: transform %r has bad numbers' % text)
        if name == 'translate' and len(v) in (1, 2):
            step = (1.0, 0.0, 0.0, 1.0, v[0], v[1] if len(v) == 2 else 0.0)
        elif name == 'scale' and len(v) in (1, 2):
            step = (v[0], 0.0, 0.0, v[1] if len(v) == 2 else v[0], 0.0, 0.0)
        elif name == 'rotate' and len(v) in (1, 3):
            r = math.radians(v[0])
            step = (math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0.0, 0.0)
            if len(v) == 3:
                step = multiply(multiply((1.0, 0.0, 0.0, 1.0, v[1], v[2]), step), (1.0, 0.0, 0.0, 1.0, -v[1], -v[2]))
        elif name == 'matrix' and len(v) == 6:
            step = tuple(v)
        else:
            raise SystemExit('logo_draw: transform %s(%s) is not supported' % (name, f.group(2)))
        m = multiply(m, step)
    if text[pos:].strip():
        raise SystemExit('logo_draw: transform %r could not be read' % text)
    if abs(m[0] * m[3] - m[1] * m[2]) < 1e-12:
        raise SystemExit('logo_draw: transform %r flattens the shape to nothing' % text)
    return m


def invert(m):
    """Return the inverse of an affine matrix (its determinant is never 0: parse_transform checks it)."""
    a, b, c, d, e, f = m
    det = a * d - b * c
    return (d / det, -b / det, -c / det, a / det, (c * f - d * e) / det, (b * e - a * f) / det)


def apply(m, x, y):
    """Return the point (x, y) mapped by matrix m."""
    return m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]


# ---------------------------------------------------------------- paths ----------------------------------------------

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
