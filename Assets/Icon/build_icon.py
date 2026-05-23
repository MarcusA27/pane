#!/usr/bin/env python3
"""Build the Pane app icon as SVG and emit Pane.icns.

Steps:
1. Generate a squircle (true superellipse) and a soft frosted-glass background.
2. Extract glyph paths for "Pane" from NewYorkItalic.ttf via fontTools so the
   icon is font-independent at render time.
3. Render the SVG to PNGs at the macOS iconset sizes with rsvg-convert.
4. Bundle the PNGs into Pane.icns with iconutil.

Run with: python3 build_icon.py
"""
from __future__ import annotations

import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.misc.transform import Transform


HERE = Path(__file__).parent.resolve()
SVG_PATH = HERE / "pane.svg"
ICONSET_DIR = HERE / "Pane.iconset"
ICNS_PATH = HERE / "Pane.icns"

FONT_PATH = "/System/Library/Fonts/NewYorkItalic.ttf"
WORD = "Pane"

CANVAS = 1024
SQUIRCLE = 880
SQUIRCLE_OFFSET = (CANVAS - SQUIRCLE) / 2   # 72


def squircle_path(diameter: float, n: float = 4.5, segments: int = 240) -> str:
    """Path for a superellipse |x/a|^n + |y/a|^n = 1, centered at origin (0,0)."""
    a = diameter / 2
    pts = []
    for i in range(segments):
        t = 2 * math.pi * i / segments
        ct = math.cos(t)
        st = math.sin(t)
        x = a * (math.copysign(1.0, ct) * (abs(ct) ** (2.0 / n)))
        y = a * (math.copysign(1.0, st) * (abs(st) ** (2.0 / n)))
        pts.append((x, y))
    d = f"M{pts[0][0]:.3f},{pts[0][1]:.3f}"
    for x, y in pts[1:]:
        d += f"L{x:.3f},{y:.3f}"
    d += "Z"
    return d


def extract_word(font_path: str, word: str, target_width: float) -> tuple[list[str], float, float]:
    """Extract glyph paths for `word`, scaled so total advance equals target_width.

    Returns (path_strings, total_visual_width, cap_height_visual).
    Each path is positioned with baseline at y=0 and starts at x=0 cumulatively.
    """
    font = TTFont(font_path)
    cmap = font.getBestCmap()
    glyph_set = font.getGlyphSet()
    units_per_em = font["head"].unitsPerEm
    hmtx = font["hmtx"]
    os2 = font["OS/2"]

    em_advance = 0
    for ch in word:
        glyph_name = cmap[ord(ch)]
        adv, _ = hmtx[glyph_name]
        em_advance += adv

    scale = target_width / em_advance

    paths: list[str] = []
    cursor_em = 0
    for ch in word:
        glyph_name = cmap[ord(ch)]
        glyph = glyph_set[glyph_name]
        adv, _ = hmtx[glyph_name]
        pen = SVGPathPen(glyph_set)
        tr = Transform()
        # Translate by accumulated x advance (post-scale), flip Y, scale.
        tr = tr.translate(cursor_em * scale, 0)
        tr = tr.scale(scale, -scale)
        tpen = TransformPen(pen, tr)
        glyph.draw(tpen)
        d = pen.getCommands()
        if d:
            paths.append(d)
        cursor_em += adv

    total_w = em_advance * scale
    cap_h_visual = os2.sCapHeight * scale
    return paths, total_w, cap_h_visual


def build_svg() -> str:
    # Squircle path centered at (0,0); we'll translate it into canvas space.
    squircle_d = squircle_path(SQUIRCLE)
    # Position the squircle centered inside the 1024 canvas.
    squircle_cx = CANVAS / 2
    squircle_cy = CANVAS / 2

    # Wordmark: aim for 56% of the squircle width.
    target_word_width = SQUIRCLE * 0.56
    paths, word_w, cap_h = extract_word(FONT_PATH, WORD, target_word_width)
    # Center horizontally; vertically center the cap height inside the canvas.
    word_x = (CANVAS - word_w) / 2
    word_baseline_y = CANVAS / 2 + cap_h / 2

    word_paths_xml = "\n".join(
        f'    <path d="{p}"/>' for p in paths
    )

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" width="{CANVAS}" height="{CANVAS}">
  <defs>
    <clipPath id="squircle-clip">
      <path d="{squircle_d}" transform="translate({squircle_cx},{squircle_cy})"/>
    </clipPath>

    <linearGradient id="glass-bg" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F2F4F7"/>
      <stop offset="1" stop-color="#F7EFE2"/>
    </linearGradient>

    <radialGradient id="upper-highlight" cx="0.78" cy="0.20" r="0.62">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.32"/>
      <stop offset="0.55" stop-color="#FFFFFF" stop-opacity="0.07"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>

    <radialGradient id="lower-shade" cx="0.22" cy="0.95" r="0.7">
      <stop offset="0" stop-color="#1A1A1A" stop-opacity="0.06"/>
      <stop offset="1" stop-color="#1A1A1A" stop-opacity="0"/>
    </radialGradient>

    <filter id="frost-noise" x="0" y="0" width="100%" height="100%" filterUnits="userSpaceOnUse">
      <feTurbulence type="fractalNoise" baseFrequency="0.55" numOctaves="3" seed="7" stitchTiles="stitch" result="noise"/>
      <feColorMatrix in="noise" type="matrix" values="
          0 0 0 0 0.16
          0 0 0 0 0.16
          0 0 0 0 0.16
          0 0 0 0.22 0
      "/>
    </filter>

    <filter id="frost-highlight" x="0" y="0" width="100%" height="100%" filterUnits="userSpaceOnUse">
      <feTurbulence type="fractalNoise" baseFrequency="0.35" numOctaves="2" seed="11" stitchTiles="stitch" result="noise"/>
      <feColorMatrix in="noise" type="matrix" values="
          0 0 0 0 1
          0 0 0 0 1
          0 0 0 0 1
          0 0 0 0.14 -0.07
      "/>
    </filter>

    <filter id="bevel" x="-5%" y="-5%" width="110%" height="110%" filterUnits="objectBoundingBox">
      <feGaussianBlur in="SourceAlpha" stdDeviation="1" result="blur"/>
      <feOffset in="blur" dx="0" dy="1" result="offset"/>
      <feMerge>
        <feMergeNode in="offset"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <g clip-path="url(#squircle-clip)">
    <rect width="{CANVAS}" height="{CANVAS}" fill="url(#glass-bg)"/>
    <rect width="{CANVAS}" height="{CANVAS}" fill="url(#lower-shade)"/>
    <rect width="{CANVAS}" height="{CANVAS}" filter="url(#frost-highlight)"/>
    <rect width="{CANVAS}" height="{CANVAS}" filter="url(#frost-noise)"/>
    <rect width="{CANVAS}" height="{CANVAS}" fill="url(#upper-highlight)"/>
  </g>

  <g fill="#1A1A1A" transform="translate({word_x:.3f},{word_baseline_y:.3f})">
{word_paths_xml}
  </g>
</svg>
"""
    return svg


def render_pngs(svg_path: Path, out_dir: Path) -> None:
    """Render the SVG into all iconset sizes using rsvg-convert."""
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    # (name, pixel size)
    targets = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for name, size in targets:
        out = out_dir / name
        subprocess.run(
            [
                "/opt/homebrew/bin/rsvg-convert",
                "-w", str(size),
                "-h", str(size),
                "-o", str(out),
                str(svg_path),
            ],
            check=True,
        )


def build_icns(iconset_dir: Path, icns_path: Path) -> None:
    if icns_path.exists():
        icns_path.unlink()
    subprocess.run(
        ["/usr/bin/iconutil", "-c", "icns", str(iconset_dir), "-o", str(icns_path)],
        check=True,
    )


def main() -> None:
    if not Path(FONT_PATH).exists():
        sys.exit(f"font not found: {FONT_PATH}")

    svg = build_svg()
    SVG_PATH.write_text(svg)
    print(f"wrote {SVG_PATH}")

    render_pngs(SVG_PATH, ICONSET_DIR)
    print(f"wrote {ICONSET_DIR}/")

    build_icns(ICONSET_DIR, ICNS_PATH)
    print(f"wrote {ICNS_PATH}")


if __name__ == "__main__":
    main()
