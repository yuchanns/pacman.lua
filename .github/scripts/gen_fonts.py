#!/usr/bin/env python3
"""
Generate a simple monochrome TrueType font from the Pac-Man tile PNGs.

The script mirrors the `conv_char` lookup used in src/main.lua so the same
character set can be rendered either as sprites or via Soluna's text system.

Requirements:
    pip install fonttools pillow

Usage example:
    python font_from_tiles.py --charset 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-/"! ' \
        --output ../../assets/fonts/pacman.ttf

By default only the HUD string characters are generated.  Use --charset to add
more characters or --charset-file to read them from a text file.
"""

from __future__ import annotations

import argparse
import logging
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from PIL import Image, ImageFilter


ROOT_DIR = Path(__file__).resolve().parents[1]
TILES_DIR = ROOT_DIR.parent / "assets" / "tiles"
DEFAULT_CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ!"
FALLBACK_TILE_SIZE = (16, 16)


def _conv_char(c: str) -> str:
    """Replicate src/main.lua conv_char -> tile code mapping."""
    if c == " ":
        return "40"
    if c == "/":
        return "3A"
    if c == "-":
        return "3B"
    if c == "\"":
        return "38"
    if c == "!":
        return f"{ord('Z') + 1:02X}"
    return f"{ord(c):02X}"


def _tile_path(code: str) -> Path:
    return TILES_DIR / f"tile_{code}_layer3.png"


def _load_bitmap(code: str, dilate: int) -> Tuple[int, int, List[Tuple[int, int]]]:
    path = _tile_path(code)
    if not path.exists():
        fallback = TILES_DIR / f"tile_{code}_layer1.png"
        if fallback.exists():
            path = fallback
    if path.exists():
        img = Image.open(path).convert("L")
        if dilate > 1:
            size = dilate if dilate % 2 == 1 else dilate + 1
            img = img.filter(ImageFilter.MaxFilter(size=size))
        width, height = img.size
        on_pixels = [
            (x, y)
            for y in range(height)
            for x in range(width)
            if img.getpixel((x, y)) > 0
        ]
        if not on_pixels:
            logging.warning("Glyph %s is empty", path.name)
        return width, height, on_pixels

    logging.warning("Tile image tile_%s_layer[13].png is missing, using blank glyph", code)
    width, height = FALLBACK_TILE_SIZE
    return width, height, []


Point = Tuple[int, int]
Edge = Tuple[int, int, int, int]


def _pixels_to_polygons(width: int, height: int, pixels: Sequence[Point]) -> List[List[Point]]:
    if not pixels:
        return []

    filled = [[0] * width for _ in range(height)]
    for x, y in pixels:
        if 0 <= x < width and 0 <= y < height:
            filled[y][x] = 1

    edges: set[Edge] = set()

    def add_edge(sx: int, sy: int, ex: int, ey: int) -> None:
        key = (sx, sy, ex, ey)
        rev = (ex, ey, sx, sy)
        if rev in edges:
            edges.remove(rev)
        elif key in edges:
            edges.remove(key)
        else:
            edges.add(key)

    for y in range(height):
        for x in range(width):
            if not filled[y][x]:
                continue
            add_edge(x, y, x + 1, y)
            add_edge(x + 1, y, x + 1, y + 1)
            add_edge(x + 1, y + 1, x, y + 1)
            add_edge(x, y + 1, x, y)

    if not edges:
        return []

    adjacency: defaultdict[Point, set[Point]] = defaultdict(set)
    for sx, sy, ex, ey in edges:
        adjacency[(sx, sy)].add((ex, ey))

    def remove_edge(start: Point, end: Point) -> None:
        key = (start[0], start[1], end[0], end[1])
        if key in edges:
            edges.remove(key)
        neighbors = adjacency.get(start)
        if neighbors:
            neighbors.discard(end)
            if not neighbors:
                adjacency.pop(start, None)

    polygons: List[List[Point]] = []
    while edges:
        sx, sy, ex, ey = next(iter(edges))
        start = (sx, sy)
        current = (ex, ey)
        polygon: List[Point] = [start]
        remove_edge(start, current)
        while True:
            polygon.append(current)
            if current == start:
                break
            neighbors = adjacency.get(current)
            if not neighbors:
                break
            next_point = next(iter(neighbors))
            remove_edge(current, next_point)
            current = next_point
        if len(polygon) >= 4 and polygon[0] == polygon[-1]:
            polygons.append(polygon)
    return polygons


def _signed_area(points: Sequence[Point]) -> float:
    area = 0.0
    n = len(points)
    if n < 3:
        return 0.0
    for i in range(n):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % n]
        area += x1 * y2 - x2 * y1
    return area * 0.5


def _signed_area_float(points: Sequence[Tuple[float, float]]) -> float:
    area = 0.0
    n = len(points)
    if n < 3:
        return 0.0
    for i in range(n):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % n]
        area += x1 * y2 - x2 * y1
    return area * 0.5


def _glyph_from_polygons(
    width: int, height: int, polygons: Sequence[Sequence[Point]], upem: int
):
    pen = TTGlyphPen(None)
    scale = upem / height if height else 1.0
    any_contour = False
    for polygon in polygons:
        if len(polygon) < 4:
            continue
        raw_points = polygon[:-1]
        area = _signed_area(raw_points)
        points = raw_points if area >= 0 else list(reversed(raw_points))
        is_outer = area < 0
        transformed = [(x * scale, (height - y) * scale) for x, y in points]
        final_area = _signed_area_float(transformed)
        if is_outer and final_area > 0:
            transformed = list(reversed(transformed))
        elif not is_outer and final_area < 0:
            transformed = list(reversed(transformed))
        if not transformed:
            continue
        pen.moveTo(transformed[0])
        for pt in transformed[1:]:
            pen.lineTo(pt)
        pen.closePath()
        any_contour = True

    glyph = pen.glyph()
    glyph.width = int(round(width * scale))
    if not any_contour:
        glyph._glyph = None
    return glyph


def build_font(
    charset: Iterable[str],
    output: Path,
    family: str,
    style: str,
    upem: int,
    dilate: int,
) -> None:
    glyph_order = [".notdef"]
    glyphs: Dict[str, object] = {}
    h_metrics: Dict[str, Tuple[int, int]] = {}
    cmap: Dict[int, str] = {}

    notdef_pen = TTGlyphPen(None)
    glyphs[".notdef"] = notdef_pen.glyph()
    h_metrics[".notdef"] = (upem, 0)

    seen = set()
    for ch in charset:
        if ch in ("\n",):
            continue
        if ch in seen:
            continue
        seen.add(ch)
        tile_code = _conv_char(ch)
        width, height, on_pixels = _load_bitmap(tile_code, dilate)
        polygons = _pixels_to_polygons(width, height, on_pixels)
        glyph = _glyph_from_polygons(width, height, polygons, upem)
        glyph_name = f"uni{ord(ch):04X}"
        glyph_order.append(glyph_name)
        glyphs[glyph_name] = glyph
        h_metrics[glyph_name] = (glyph.width, 0)
        cmap[ord(ch)] = glyph_name

    if len(glyph_order) == 1:
        raise SystemExit("No glyphs generated; check charset and tile PNGs.")

    fb = FontBuilder(upem, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(h_metrics)

    ascent = upem
    descent = 0
    fb.setupHorizontalHeader(ascent=ascent, descent=descent)
    fb.setupOS2(
        sTypoAscender=ascent,
        sTypoDescender=descent,
        sTypoLineGap=0,
        usWinAscent=ascent,
        usWinDescent=-descent,
        usWeightClass=400,
        usWidthClass=5,
        fsType=0,
    )
    fb.setupNameTable(
        {
            "familyName": family,
            "styleName": style,
            "fullName": f"{family} {style}",
            "uniqueFontIdentifier": f"{family}-{style}",
            "psName": f"{family}-{style}".replace(" ", ""),
        }
    )
    fb.setupPost()
    fb.setupMaxp()

    output.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(output))
    logging.info("Saved %s", output)


def _read_charset(args: argparse.Namespace) -> str:
    if args.charset_file:
        text = Path(args.charset_file).read_text(encoding="utf-8")
    else:
        text = args.charset
    # Remove newlines but keep spaces
    return "".join(ch for ch in text if ch != "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert Pac-Man tiles to a TTF font.")
    parser.add_argument(
        "--charset",
        default=DEFAULT_CHARSET,
        help="Characters to include (default: %(default)r).",
    )
    parser.add_argument(
        "--charset-file",
        help="Read characters from file (newline characters are ignored).",
    )
    parser.add_argument(
        "--family",
        default="Pacman Tiles",
        help="Font family name (default: %(default)s).",
    )
    parser.add_argument(
        "--style",
        default="Regular",
        help="Font style name (default: %(default)s).",
    )
    parser.add_argument(
        "--upem",
        type=int,
        default=1024,
        help="Units per EM (default: %(default)d).",
    )
    parser.add_argument(
        "--dilate",
        type=int,
        default=1,
        help="Odd MaxFilter kernel size for expanding pixels before tracing (default: %(default)d).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT_DIR.parent / "assets" / "fonts" / "pacman.ttf",
        help="Output TTF path.",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Enable verbose logging."
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO, format="%(levelname)s: %(message)s")
    charset = _read_charset(args)
    if not charset:
        raise SystemExit("Charset is empty.")
    dilate = args.dilate if args.dilate % 2 == 1 else args.dilate + 1
    if dilate < 1:
        dilate = 1
    build_font(charset, args.output, args.family, args.style, args.upem, dilate)


if __name__ == "__main__":
    main()
