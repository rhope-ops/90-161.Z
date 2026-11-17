#!/usr/bin/env python3
"""Build fake test seals for Task 7 (seal prep, L-007a). Never hand-edit the PNGs; change this script and rebuild.

The images are plain shapes, not real insignia. EXPECTED gives the result 90161Z-T07-seal-prep-r5.ps1 must report.

Usage:
  python3 scripts/build_test_seals.py            write samples/90161Z-T07-testseal-*-r1.png
  python3 scripts/build_test_seals.py --check    rebuild in memory and compare pixels with the committed files
  python3 scripts/build_test_seals.py --raw DIR  write DIR/<name>.bgra (raw BGRA, stride = 4 x width) and
                                                 DIR/<name>.txt ("width height left top right bottom") for the
                                                 PowerShell trim test in tests/run.sh
"""
import argparse
import os
import sys

from PIL import Image, ImageChops, ImageDraw

OUT = "samples/90161Z-T07-testseal-{}-r1.png"
WHITE_MIN, CLEAR_MAX = 245, 16   # same limits as the PowerShell script (L-007a)

EXPECTED = {
    "round": "PASS shape=round or square, emblem 501x501, dpi 417, placed 360x360",
    "tall": "PASS shape=tall, emblem 261x401, dpi 334, placed 234x360",
    "soft": "WARN shape=round or square, emblem 161x161, dpi 134, placed 360x360",
    "tiny": "FAIL emblem 101x101, dpi 84, nothing written",
}


def make(name):
    """Draw one fake test seal image (round, tall, soft or tiny). Takes the name; returns a PIL RGBA image. Raises ValueError for another name."""
    if name == "round":    # white background, round seal with white center ring
        im = Image.new("RGBA", (700, 700), (255, 255, 255, 255))
        d = ImageDraw.Draw(im)
        d.ellipse([100, 100, 600, 600], fill=(20, 50, 120, 255))
        d.ellipse([200, 200, 500, 500], fill=(250, 250, 250, 255))
    elif name == "tall":   # clear background, shield shape
        im = Image.new("RGBA", (500, 700), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.polygon([(120, 150), (380, 150), (380, 400), (250, 550), (120, 400)], fill=(140, 20, 20, 255))
    elif name == "soft":   # small source on white
        im = Image.new("RGBA", (300, 300), (255, 255, 255, 255))
        ImageDraw.Draw(im).ellipse([70, 70, 230, 230], fill=(30, 90, 30, 255))
    elif name == "tiny":   # too small on clear
        im = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
        ImageDraw.Draw(im).ellipse([20, 20, 120, 120], fill=(90, 60, 10, 255))
    else:
        raise ValueError(name)
    return im


def emblem_box(im):
    """Reference trim: inclusive (left, top, right, bottom) of pixels that are neither clear nor white."""
    w, h = im.size
    px = im.load()
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= CLEAR_MAX and not (r >= WHITE_MIN and g >= WHITE_MIN and b >= WHITE_MIN):
                xs.append(x)
                ys.append(y)
    return (min(xs), min(ys), max(xs), max(ys)) if xs else None


def main():
    """Command line: write the seal images, or with --check compare them with the committed ones, or with --raw write raw pixel data. Returns the exit code."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--raw")
    a = ap.parse_args()
    for name in EXPECTED:
        im = make(name)
        if a.raw:
            r, g, b, al = im.split()
            with open(os.path.join(a.raw, name + ".bgra"), "wb") as f:
                f.write(Image.merge("RGBA", (b, g, r, al)).tobytes())
            box = emblem_box(im)
            with open(os.path.join(a.raw, name + ".txt"), "w") as f:
                f.write("%d %d %d %d %d %d\n" % ((im.width, im.height) + box))
        elif a.check:
            path = OUT.format(name)
            if not os.path.exists(path) or ImageChops.difference(Image.open(path).convert("RGBA"), im).getbbox():
                print("test seal stale: run python3 scripts/build_test_seals.py")
                return 1
        else:
            im.save(OUT.format(name))
            print("wrote", OUT.format(name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
