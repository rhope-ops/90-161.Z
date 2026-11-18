#!/usr/bin/env python3
"""Draw the 90-161.Z logo (assets/logo/90161Z-logo.svg) as PNG bytes in pure Python (the PFM, 2026-11-17).

Why: the logo PNGs go into task scripts and round bundles, so every build must give the same bytes. A browser render
(the old scripts/build_logo.js) differs between Chromium builds; this code gives the same pixels on every machine.
What it draws: the subset of SVG that the logo uses, read from the SVG file itself:
  <circle> filled, stroked, or stroked with stroke-dasharray and round caps;
  <path> with absolute M, L, H, V, A and Z, filled and/or stroked (round caps and joins);
  clip-path="url(#id)" that points at a <clipPath> of <rect> elements.
Any other element or command stops with an error, so a new logo design cannot be drawn wrong in silence.
How: each pixel gets each shape's coverage from its signed distance to the shape's edge (one pixel of soft edge), and
the shapes are painted in order ("over"). Output: 8-bit RGBA PNG, transparent outside the disc, compressed by zlib.
Limit: the PNG bytes depend on the zlib build (the same with zlib 1.2 and 1.3; zlib-ng may differ); the pixels do not.
Usage: python3 scripts/logo_draw.py SIZE OUT.png   (or import: draw(svg_text, size) -> PNG bytes; pixels() -> RGBA)
Run target: Python 3.8+, standard library only.
"""
import math
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

NS = '{http://www.w3.org/2000/svg}'
VIEW = 512.0   # the SVG viewBox is 0 0 512 512 (checked in shapes())


# ---------------------------------------------------------------- reading the SVG ------------------------------------

def shapes(svg_text):
    """Read the SVG and return its painted shapes in order, as dicts: kind ('circle' or 'path'), the geometry, fill and
    stroke colors (None or (r, g, b) 0-255), stroke width, dash list and the clip rectangles (or None)."""
    root = ET.fromstring(svg_text)
    if root.get('viewBox') != '0 0 512 512':
        raise SystemExit('logo_draw: the viewBox must be 0 0 512 512')
    clips = {c.get('id'): [clip_rect(r) for r in c] for c in root.iter(NS + 'clipPath') if refuse_clip(c)}
    out = []
    for el in root:
        tag = el.tag.replace(NS, '')
        if tag in ('title', 'defs', 'desc'):
            continue
        if tag not in ('circle', 'path'):
            raise SystemExit('logo_draw: element <%s> is not supported' % tag)
        refuse_unsupported(el, tag)
        s = {'kind': tag, 'fill': color(el.get('fill', '#000000')), 'stroke': color(el.get('stroke', 'none')),
             'width': float(el.get('stroke-width', '1')), 'dash': [float(x) for x in el.get('stroke-dasharray', '').split()],
             'clip': None}
        clip = el.get('clip-path')
        if clip:
            s['clip'] = find_clip(clips, clip)
        if tag == 'circle':
            s['c'], s['r'] = (float(el.get('cx')), float(el.get('cy'))), float(el.get('r'))
        else:
            s['segs'], s['closed'] = path_segments(el.get('d'))
            refuse_fill(s)
        out.append(s)
    return out


SUPPORTED = {'cx', 'cy', 'r', 'd', 'fill', 'stroke', 'stroke-width', 'stroke-dasharray', 'stroke-linecap',
             'stroke-linejoin', 'clip-path'}


def refuse_unsupported(el, tag):
    """Stop when a shape uses an attribute or value this drawing does not handle: only round caps and joins (the
    distance method draws them round), a two-value dash and only on a circle, and no opacity or transform."""
    extra = set(el.attrib) - SUPPORTED
    if extra:
        raise SystemExit('logo_draw: attribute(s) %s on <%s> are not supported' % (sorted(extra), tag))
    d = el.get('d', '').upper()
    if d.count('M') > 1 or d.count('Z') > 1 or ('Z' in d and d.rstrip()[-1:] != 'Z'):
        raise SystemExit('logo_draw: a path must be one sub-path (one M, and Z only as the last command)')
    if el.get('stroke', 'none') != 'none':
        open_end = (tag == 'path' and 'Z' not in d) or bool(el.get('stroke-dasharray'))   # a stroke with free ends
        corners = tag == 'path' and len(re.findall(r'[LHVAZ]', d)) > 1                    # a stroke with joins (Z draws one)
        if open_end and el.get('stroke-linecap') != 'round':
            raise SystemExit('logo_draw: a stroke with free ends needs stroke-linecap="round" (other caps are not drawn)')
        if corners and el.get('stroke-linejoin') != 'round':
            raise SystemExit('logo_draw: a stroke with corners needs stroke-linejoin="round" (other joins are not drawn)')
    dash = el.get('stroke-dasharray', '').split()
    if dash and (tag != 'circle' or len(dash) != 2):
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
    """Stop when a filled path cannot be filled correctly. A fill needs a closed path (Z), or it would silently get no
    fill; the even-odd fill test handles lines only, not arcs.

    Args:
        s: a path shape from shapes().
    """
    if s['fill'] is None:
        return
    if not s['closed']:
        raise SystemExit('logo_draw: a filled path must end with Z (an open path would get no fill); use fill="none" for a line')
    if any(g[0] == 'arc' for g in s['segs']):
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
        return tuple(float(r.get(k)) for k in ('x', 'y', 'width', 'height'))
    except (TypeError, ValueError):
        raise SystemExit('logo_draw: a clip <rect> needs x, y, width and height as plain numbers')


def color(text):
    """Return (r, g, b) for "#RRGGBB", or None for "none"."""
    if text == 'none':
        return None
    if not re.fullmatch(r'#[0-9A-Fa-f]{6}', text):
        raise SystemExit('logo_draw: color %r is not #RRGGBB' % text)
    return tuple(int(text[k:k + 2], 16) for k in (1, 3, 5))


def path_segments(d):
    """Return (segments, closed) for a path's "d" text (see parse_path), with a clean stop for bad numbers.

    Args:
        d: the path text, or None.

    Returns:
        The tuple (segments, closed). Stops with a message, not a Python error, when a command has too few numbers or a
        letter where a number belongs.
    """
    try:
        return parse_path(d)
    except (IndexError, ValueError, TypeError):
        raise SystemExit('logo_draw: a path command has too few or bad numbers: %r' % d)


def parse_path(d):
    """Return (segments, closed) for a path's "d" text. A segment is ('line', p0, p1) or ('arc', center, radius,
    start angle, sweep angle). Only absolute M, L, H, V, A and Z are allowed.

    Args:
        d: the path text, or None.

    Returns:
        The tuple (segments, closed). Stops with a message for a path that does not start with M.
    """
    tokens = re.findall(r'[A-Za-z]|-?\d*\.?\d+', d or '')
    segs, pos, start, k, closed = [], None, None, 0, False
    if not tokens or tokens[0] != 'M':
        raise SystemExit('logo_draw: a path must start with M (found %r)' % (tokens[0] if tokens else 'nothing'))
    while k < len(tokens):
        cmd = tokens[k]; k += 1
        if cmd == 'M':
            pos = start = (float(tokens[k]), float(tokens[k + 1])); k += 2
        elif cmd in 'LHV':
            n = {'L': 2, 'H': 1, 'V': 1}[cmd]
            vals = [float(x) for x in tokens[k:k + n]]; k += n
            new = tuple(vals) if cmd == 'L' else ((vals[0], pos[1]) if cmd == 'H' else (pos[0], vals[0]))
            segs.append(('line', pos, new)); pos = new
        elif cmd == 'A':
            rx, ry, rot, large, sweep, x, y = [float(x) for x in tokens[k:k + 7]]; k += 7
            if rx != ry or rot != 0:
                raise SystemExit('logo_draw: only circular arcs without rotation are supported')
            segs.append(arc_segment(pos, (x, y), rx, bool(large), bool(sweep))); pos = (x, y)
        elif cmd == 'Z':
            segs.append(('line', pos, start)); pos, closed = start, True
        else:
            raise SystemExit('logo_draw: path command %r is not supported' % cmd)
    return segs, closed


def arc_segment(p0, p1, r, large, sweep):
    """Return ('arc', center, r, start angle, sweep angle) for an SVG arc from p0 to p1 (the endpoint-to-center
    conversion of the SVG specification, for a circle). A positive sweep angle goes the way of rising angles (y down)."""
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


# ---------------------------------------------------------------- distances ------------------------------------------

def seg_distance(seg, x, y):
    """Return the distance from point (x, y) to a line or arc segment."""
    if seg[0] == 'line':
        (ax, ay), (bx, by) = seg[1], seg[2]
        dx, dy = bx - ax, by - ay
        t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
        return math.hypot(x - ax - t * dx, y - ay - t * dy)
    (cx, cy), r, a0, da = seg[1], seg[2], seg[3], seg[4]
    off = (math.atan2(y - cy, x - cx) - a0) % (2 * math.pi)
    if (da >= 0 and off <= da) or (da < 0 and off - 2 * math.pi >= da):
        return abs(math.hypot(x - cx, y - cy) - r)
    ends = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in (a0, a0 + da)]
    return min(math.hypot(x - ex, y - ey) for ex, ey in ends)


def inside_polygon(segs, x, y):
    """Even-odd test: True when (x, y) is inside the closed path made of line segments."""
    inside = False
    for seg in segs:
        (ax, ay), (bx, by) = seg[1], seg[2]
        if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
            inside = not inside
    return inside


def dash_distance(s, x, y):
    """Distance from (x, y) to the dashed circle stroke of shape `s` (dashes along the circle from its rightmost point
    in the direction of rising angles, as SVG draws a circle), before the half stroke width is taken off."""
    (cx, cy), r = s['c'], s['r']
    on, off = s['dash'][0], s['dash'][1]
    period, length = on + off, 2 * math.pi * r
    pos = (math.atan2(y - cy, x - cx) % (2 * math.pi)) * r
    rho = math.hypot(x - cx, y - cy)
    best = float('inf')
    for k in (math.floor(pos / period) - 1, math.floor(pos / period), math.floor(pos / period) + 1, 0):
        k = k % max(1, math.ceil(length / period))
        a, b = k * period, min(k * period + on, length)
        for shift in (0.0, length, -length):   # a point near the end of the circle may be nearest to the first dash
            p = pos + shift
            if a <= p <= b:
                best = min(best, abs(rho - r))
            else:
                e = (a if abs(p - a) < abs(p - b) else b) / r
                best = min(best, math.hypot(x - cx - r * math.cos(e), y - cy - r * math.sin(e)))
    return best


def coverages(s, x, y, px):
    """Return (fill coverage, stroke coverage) of shape `s` at point (x, y), 0 to 1, with one pixel (`px` SVG units) of
    soft edge, after the clip rectangles."""
    cov = lambda d: max(0.0, min(1.0, 0.5 - d / px))
    half = s['width'] / 2
    if s['kind'] == 'circle':
        rho = math.hypot(x - s['c'][0], y - s['c'][1])
        fill = cov(rho - s['r'])
        stroke = cov((dash_distance(s, x, y) if s['dash'] else abs(rho - s['r'])) - half)
    else:
        edge = min(seg_distance(g, x, y) for g in s['segs'])
        fill = cov(-edge if inside_polygon(s['segs'], x, y) else edge) if s['closed'] else 0.0
        stroke = cov(edge - half)
    if s['clip']:
        clip = cov(min(max(rx - x, x - rx - rw, ry - y, y - ry - rh) for rx, ry, rw, rh in s['clip']))
        fill, stroke = fill * clip, stroke * clip
    return fill, stroke


# ---------------------------------------------------------------- pixels and PNG -------------------------------------

def bounds(s):
    """Return (x0, y0, x1, y1), the box in SVG units outside which shape `s` paints nothing."""
    pad = s['width'] / 2 + 2
    if s['kind'] == 'circle':
        (cx, cy), r = s['c'], s['r']
        return cx - r - pad, cy - r - pad, cx + r + pad, cy + r + pad
    pts = [p for g in s['segs'] for p in ((g[1], g[2]) if g[0] == 'line' else
                                         ((g[1][0] - g[2], g[1][1] - g[2]), (g[1][0] + g[2], g[1][1] + g[2])))]
    return (min(p[0] for p in pts) - pad, min(p[1] for p in pts) - pad,
            max(p[0] for p in pts) + pad, max(p[1] for p in pts) + pad)


def pixels(svg_text, size):
    """Return the logo as `size` x `size` RGBA pixels: a list of rows, each a bytearray of 4 bytes per pixel (color not
    premultiplied). Each shape is painted "over" the ones before it, fill first, then stroke."""
    px = VIEW / size
    acc = [[0.0, 0.0, 0.0, 0.0] for _ in range(size * size)]   # premultiplied r, g, b (0-1) and alpha
    for s in shapes(svg_text):
        x0, y0, x1, y1 = bounds(s)
        cols = range(max(0, int(x0 / px)), min(size, int(x1 / px) + 1))
        for j in range(max(0, int(y0 / px)), min(size, int(y1 / px) + 1)):
            y = (j + 0.5) * px
            for i in cols:
                fill, stroke = coverages(s, (i + 0.5) * px, y, px)
                cell = acc[j * size + i]
                for rgb, a in ((s['fill'], fill), (s['stroke'], stroke)):
                    if rgb and a > 0:
                        for c in range(3):
                            cell[c] = rgb[c] / 255.0 * a + cell[c] * (1 - a)
                        cell[3] = a + cell[3] * (1 - a)
    rows = []
    for j in range(size):
        row = bytearray()
        for r, g, b, a in acc[j * size:(j + 1) * size]:
            row += bytes((0, 0, 0, 0)) if a <= 0 else bytes((round(min(1.0, r / a) * 255), round(min(1.0, g / a) * 255),
                                                            round(min(1.0, b / a) * 255), round(a * 255)))
        rows.append(row)
    return rows


def png_bytes(rows):
    """Return PNG bytes for RGBA rows (8 bits a channel, no interlace, filter 0 on every row, zlib level 9)."""
    chunk = lambda kind, data: struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    head = struct.pack('>IIBBBBB', len(rows[0]) // 4, len(rows), 8, 6, 0, 0, 0)
    raw = b''.join(b'\0' + bytes(r) for r in rows)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', head) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')


def draw(svg_text, size):
    """Return the logo as PNG bytes, `size` x `size` pixels."""
    return png_bytes(pixels(svg_text, size))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: python3 scripts/logo_draw.py SIZE OUT.png')
    svg = Path(__file__).resolve().parent.parent / 'assets/logo/90161Z-logo.svg'
    with open(sys.argv[2], 'wb') as out:
        out.write(draw(svg.read_text(encoding='utf-8'), int(sys.argv[1])))
