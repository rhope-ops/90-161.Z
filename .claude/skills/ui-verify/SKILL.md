---
name: ui-verify
description: Use before you report a visual or UI change (a page, artifact, component, layout, colour or theme) as done or verified. Measures instead of judging by eye - screenshots at 375 and 1440 px in light and dark, WCAG AA text contrast, target sizes and horizontal scroll - and gives the report format.
---

# UI verify

AGENTS.md "Verification" points here.

## Run

```bash
node .claude/skills/ui-verify/measure.mjs <url-or-html-file> [out-dir]
```

It needs Playwright (`require('playwright')` must resolve). Without an out-dir, screenshots go to a new temp folder, never the repo; the script prints the paths. For each width (375, 1440 px) and scheme (light, dark) it saves a full-page screenshot and checks:

| Check | Pass |
|---|---|
| Text contrast (WCAG AA) | 4.5:1; 3:1 for large text (24 px, or 18.66 px bold) |
| Interactive targets | at least 24×24 px (a link inside a sentence is exempt, as in WCAG 2.5.8) |
| Horizontal page scroll | 0 px |

Exit 0 = all pass. Text on an image or a gradient is listed as "unchecked": check it by hand and say so.

## What the script does not check

Measure these yourself with `getBoundingClientRect()` in the page, and report the numbers:

- Spacing that the change touches: before and after, in px. A shift nobody asked for is a fail.
- Contrast of UI parts that are not text (input borders, focus ring, icons): 3:1 against the next colour.
- Focus: Tab reaches each control in order, and the focus is visible.
- Reduced motion: with `prefers-reduced-motion: reduce`, nothing moves that is not needed.

## Report

One line per width and scheme, from the script, plus the hand checks with their numbers. Link the screenshots. Say "verified" only when every check passed or each fail is listed with its cause.
