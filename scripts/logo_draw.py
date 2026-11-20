#!/usr/bin/env python3
"""Draw the 90-161.Z logo (assets/logo/90161Z-logo.svg) as PNG bytes in pure Python (the PFM, 2026-11-17).

Why: the logo PNGs go into task scripts and round bundles, so every build must give the same bytes. A browser render
(the old scripts/build_logo.js) differs between Chromium builds; this code gives the same pixels on every machine.
What it draws: the subset of SVG that the logo uses, read from the SVG file itself (Delta logo, the PFM, 2026-11-19):
  <g> with transform and the paint attributes below, which its children inherit;
  <circle> filled, stroked, or stroked with stroke-dasharray and round caps;
  <line> stroked with round caps;
  <path> with absolute M, L, H, V, Q, C, A and Z, one or more sub-paths, filled (nonzero rule) and/or stroked (round
    caps and joins); Q and C are cut into fixed straight steps (8 and 16), so the result is the same on every machine;
  transform with translate, rotate, scale and matrix; fill-opacity; clip-path="url(#id)" to a <clipPath> of <rect>.
Any other element, attribute or command stops with an error, so a new logo design cannot be drawn wrong in silence.
How: each pixel centre is mapped back into the shape's own coordinates (so a stroke under scale(1 1.7) gets the right
width), and gets the shape's coverage from its signed distance to the shape's edge (one pixel of soft edge). The
shapes are painted in order ("over"). Output: 8-bit RGBA PNG, transparent outside the disc, compressed by zlib.
Limit: under a scale that differs in x and y the edge sits exactly right, but its one pixel of soft edge uses the
average scale (the square root of the determinant), so it is a little wider or narrower in one direction.
Reading the SVG (elements, transforms, paths) is in scripts/logo_svg.py; this file draws.
Speed: a grid of the segments near each point, and bands of rows for the fill test, keep a 512 px drawing short.
Limit: the PNG bytes depend on the zlib build (the same with zlib 1.2 and 1.3; zlib-ng may differ); the pixels do not.
Usage: python3 scripts/logo_draw.py SIZE OUT.png   (or import: draw(svg_text, size) -> PNG bytes; pixels() -> RGBA)
Run target: Python 3.8+, standard library only.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

from logo_svg import apply, invert, shapes

VIEW = 512.0   # the SVG viewBox is 0 0 512 512 (logo_svg.shapes checks it)
MAX_CELLS = 2000000   # the most grid cells one path may fill (the Delta logo needs about 20 000 at 512 px)


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


def seg_box(seg):
    """Return the box of a line or arc segment.

    Args:
        seg: a ('line', p0, p1) or ('arc', center, radius, start angle, sweep angle) segment.

    Returns:
        (x0, y0, x1, y1). An arc's box holds its end points and each axis point (0, 90, 180, 270 degrees) it passes.
    """
    if seg[0] == 'line':
        (ax, ay), (bx, by) = seg[1], seg[2]
        return min(ax, bx), min(ay, by), max(ax, bx), max(ay, by)
    (cx, cy), r, a0, da = seg[1], seg[2], seg[3], seg[4]
    angles = [a0, a0 + da] + [a0 + t for t in (k * math.pi / 2 - a0 for k in range(-8, 9))
                              if (0 <= t <= da if da >= 0 else da <= t <= 0)]
    xs = [cx + r * math.cos(a) for a in angles]
    ys = [cy + r * math.sin(a) for a in angles]
    return min(xs), min(ys), max(xs), max(ys)


class Index:
    """The segments of one path, sorted into a square grid (for the nearest-edge distance) and into bands of rows
    (for the fill test), so each pixel looks only at the segments near it."""

    def __init__(self, segs, reach):
        """Build the grid with cells `reach` units wide: a point needs the exact distance only up to `reach` (beyond
        it the coverage is 0 or 1), so the 3 x 3 cells around it hold every segment that matters.

        Args:
            segs: the path's segments (all sub-paths together), in the shape's own coordinates.
            reach: the largest distance that changes the coverage (half the stroke width plus one pixel).
        """
        self.cell = max(reach, 1e-6)
        self.reach = reach
        self.grid, self.bands = {}, {}
        cells = 0
        for seg in segs:   # count first: a huge shape on a fine grid would take hours (review, 20 Nov 26)
            x0, y0, x1, y1 = seg_box(seg)
            cells += (math.floor(x1 / self.cell) - math.floor(x0 / self.cell) + 1) * \
                (math.floor(y1 / self.cell) - math.floor(y0 / self.cell) + 1)
            if cells > MAX_CELLS:
                raise SystemExit('logo_draw: a path is too large for its stroke width (more than %d grid cells)' % MAX_CELLS)
        for n, seg in enumerate(segs):
            x0, y0, x1, y1 = seg_box(seg)
            for i in range(int(math.floor(x0 / self.cell)), int(math.floor(x1 / self.cell)) + 1):
                for j in range(int(math.floor(y0 / self.cell)), int(math.floor(y1 / self.cell)) + 1):
                    self.grid.setdefault((i, j), []).append(n)
            if seg[0] == 'line':
                for j in range(int(math.floor(y0 / self.cell)), int(math.floor(y1 / self.cell)) + 1):
                    self.bands.setdefault(j, []).append(seg)
        self.segs = segs

    def distance(self, x, y):
        """Return the distance from a point to the nearest segment.

        Args:
            x: the point's x in the shape's own coordinates.
            y: the point's y.

        Returns:
            The distance, or a value above `reach` when no segment is that near (the coverage is then 0 or 1).
        """
        i, j = int(math.floor(x / self.cell)), int(math.floor(y / self.cell))
        best = self.reach * 2 + 1
        seen = set()
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                for n in self.grid.get((i + di, j + dj), ()):
                    if n not in seen:
                        seen.add(n)
                        best = min(best, seg_distance(self.segs[n], x, y))
        return best

    def inside(self, x, y):
        """Nonzero rule: True when the closed line segments wind around (x, y) (a ray to the right, SVG's default)."""
        wind = 0
        for seg in self.bands.get(int(math.floor(y / self.cell)), ()):
            (ax, ay), (bx, by) = seg[1], seg[2]
            if (ay <= y) != (by <= y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
                wind += 1 if by > ay else -1
        return wind != 0


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


def coverages(s, x, y, px, index):
    """Return (fill coverage, stroke coverage) of shape `s` at point (x, y) in the shape's own coordinates, 0 to 1,
    with one pixel (`px` units of the shape) of soft edge, after the clip rectangles. `index` is the path's Index."""
    cov = lambda d: max(0.0, min(1.0, 0.5 - d / px))
    half = s['width'] / 2
    if s['kind'] == 'circle':
        rho = math.hypot(x - s['c'][0], y - s['c'][1])
        fill = cov(rho - s['r'])
        stroke = cov((dash_distance(s, x, y) if s['dash'] else abs(rho - s['r'])) - half)
    else:
        edge = index.distance(x, y)
        fill = cov(-edge if index.inside(x, y) else edge) if s['fill'] else 0.0
        stroke = cov(edge - half) if s['stroke'] else 0.0
    if s['clip']:
        clip = cov(min(max(rx - x, x - rx - rw, ry - y, y - ry - rh) for rx, ry, rw, rh in s['clip']))
        fill, stroke = fill * clip, stroke * clip
    return fill, stroke


# ---------------------------------------------------------------- pixels and PNG -------------------------------------

def bounds(s):
    """Return the box outside which a shape paints nothing.

    Args:
        s: a shape from shapes().

    Returns:
        (x0, y0, x1, y1) in viewBox units: the shape's own box, padded by half the stroke width and 2 units, mapped by
        its matrix.
    """
    pad = s['width'] / 2 + 2
    if s['kind'] == 'circle':
        (cx, cy), r = s['c'], s['r']
        box = (cx - r - pad, cy - r - pad, cx + r + pad, cy + r + pad)
    else:
        boxes = [seg_box(g) for sub in s['subs'] for g in sub['segs']]
        box = (min(b[0] for b in boxes) - pad, min(b[1] for b in boxes) - pad,
               max(b[2] for b in boxes) + pad, max(b[3] for b in boxes) + pad)
    corners = [apply(s['m'], x, y) for x in (box[0], box[2]) for y in (box[1], box[3])]
    return (min(c[0] for c in corners), min(c[1] for c in corners), max(c[0] for c in corners), max(c[1] for c in corners))


def pixels(svg_text, size):
    """Return the logo as `size` x `size` RGBA pixels: a list of rows, each a bytearray of 4 bytes per pixel (color not
    premultiplied). Each shape is painted "over" the ones before it, fill first, then stroke."""
    px = VIEW / size
    acc = [[0.0, 0.0, 0.0, 0.0] for _ in range(size * size)]   # premultiplied r, g, b (0-1) and alpha
    for s in shapes(svg_text):
        inv = invert(s['m'])
        px_local = px / math.sqrt(abs(s['m'][0] * s['m'][3] - s['m'][1] * s['m'][2]))   # one pixel in shape units
        index = None
        if s['kind'] == 'path':
            reach = (s['width'] / 2 if s['stroke'] else 0.0) + px_local
            index = Index([g for sub in s['subs'] for g in sub['segs']], reach)
        x0, y0, x1, y1 = bounds(s)
        cols = range(max(0, int(x0 / px)), min(size, int(x1 / px) + 1))
        for j in range(max(0, int(y0 / px)), min(size, int(y1 / px) + 1)):
            y = (j + 0.5) * px
            for i in cols:
                lx, ly = apply(inv, (i + 0.5) * px, y)
                fill, stroke = coverages(s, lx, ly, px_local, index)
                cell = acc[j * size + i]
                for rgb, a in ((s['fill'], fill * s['fill_op']), (s['stroke'], stroke)):
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
    """Return the logo as PNG bytes.

    Args:
        svg_text: the SVG file's text.
        size: the width and height in pixels.

    Returns:
        The PNG bytes. Any number error the refusals did not foresee (an overflow, a nan, a division by 0 from extreme
        but legal values) stops with a "logo_draw:" message too, never a Python traceback (review, 20 Nov 26).
    """
    try:
        return png_bytes(pixels(svg_text, size))
    except (ArithmeticError, ValueError) as e:
        raise SystemExit('logo_draw: the drawing failed on extreme numbers (%s: %s)' % (type(e).__name__, e))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: python3 scripts/logo_draw.py SIZE OUT.png')
    svg = Path(__file__).resolve().parent.parent / 'assets/logo/90161Z-logo.svg'
    with open(sys.argv[2], 'wb') as out:
        out.write(draw(svg.read_text(encoding='utf-8'), int(sys.argv[1])))
