#!/usr/bin/env python3
"""
Decode sprites and background tiles from the Pac-Man ROM dumps (rom_sprites.bin / rom_tiles.bin)
and export per-palette-slot grayscale PNG layers (2-bit masks) that can be recolored later,
matching the raw layering pacman.c feeds into its render pipeline.

Usage:
1. Save the 4096-byte sprite ROM as rom_sprites.bin and the 4096-byte tile ROM as rom_tiles.bin.
2. Run the script; PNGs will be written to ../assets/sprites and ../assets/tiles (relative to this file).
"""

from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Set, Tuple
from PIL import Image

# ---------------------------------------------------------------------------
# 1) ROM data that must be provided
# ---------------------------------------------------------------------------

CURRENT_DIR = Path(__file__).resolve().parent
ROM_SPRITES_PATH = Path(f"{CURRENT_DIR}/rom_sprites.bin")
ROM_TILES_PATH = Path(f"{CURRENT_DIR}/rom_tiles.bin")
ROM_SPRITES_SIZE = 4096  # 64 sprites * 64 bytes
ROM_TILES_SIZE = 4096    # 256 tiles * 16 bytes

rom_sprites: List[int] = []
rom_tiles: List[int] = []

rom_hwcolors: Sequence[int] = [
    0x0, 0x7, 0x66, 0xef, 0x0, 0xf8, 0xea, 0x6f,
    0x0, 0x3f, 0x0, 0xc9, 0x38, 0xaa, 0xaf, 0xf6,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
]

rom_palette: Sequence[int] = [
    0x0, 0x0, 0x0, 0x0, 0x0, 0xf, 0xb, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0xf, 0xb, 0x3,
    0x0, 0x0, 0x0, 0x0, 0x0, 0xf, 0xb, 0x5, 0x0, 0x0, 0x0, 0x0, 0x0, 0xf, 0xb, 0x7,
    0x0, 0x0, 0x0, 0x0, 0x0, 0xb, 0x1, 0x9, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xf, 0x0, 0xe, 0x0, 0x1, 0xc, 0xf,
    0x0, 0xe, 0x0, 0xb, 0x0, 0xc, 0xb, 0xe, 0x0, 0xc, 0xf, 0x1, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x1, 0x2, 0xf, 0x0, 0x7, 0xc, 0x2, 0x0, 0x9, 0x6, 0xf, 0x0, 0xd, 0xc, 0xf,
    0x0, 0x5, 0x3, 0x9, 0x0, 0xf, 0xb, 0x0, 0x0, 0xe, 0x0, 0xb, 0x0, 0xe, 0x0, 0xb,
    0x0, 0x0, 0x0, 0x0, 0x0, 0xf, 0xe, 0x1, 0x0, 0xf, 0xb, 0xe, 0x0, 0xe, 0x0, 0xf,
    # Many trailing zeros; keep them unchanged
] + [0x0] * (256 - 128)  # Ensure the total length is 256

# ---------------------------------------------------------------------------
# 2) Constants and configuration
# ---------------------------------------------------------------------------

TILE_WIDTH = 8
TILE_HEIGHT = 8
BLOCK_HEIGHT = TILE_HEIGHT // 2  # 4
SPRITE_WIDTH = 16
SPRITE_HEIGHT = 16
SPRITE_STRIDE = 64               # 64 bytes per sprite
TILE_STRIDE = 16                 # 16 bytes per tile

# Arrangement of the eight 8x4 blocks, copied directly from the original C code
BLOCKS = [
    ((0,  0), 40), ((8,  0),  8),
    ((0,  4), 48), ((8,  4), 16),
    ((0,  8), 56), ((8,  8), 24),
    ((0, 12), 32), ((8, 12),  0),
]

DISPLAY_TILES_X = 28
DISPLAY_TILES_Y = 36
NUM_LIVES = 3
NUM_STATUS_FRUITS = 7

TILE_SPACE = 0x40
TILE_DOT_CODE = 0x10
TILE_PILL = 0x14
TILE_GHOST = 0xB0
TILE_LIFE = 0x20
TILE_DOOR = 0xCF

# Color codes (values assigned to the sprite/color field in the game)
COLOR_CODES: Sequence[Tuple[str, int]] = [
    ("blank",              0x00),
    ("default",            0x0F),
    ("dot",                0x10),
    ("pacman",             0x09),
    ("blinky",             0x01),
    ("pinky",              0x03),
    ("inky",               0x05),
    ("clyde",              0x07),
    ("frightened",         0x11),
    ("frightened_blink",   0x12),
    ("ghost_score",        0x18),
    ("eyes",               0x19),
    ("cherries",           0x14),
    ("strawberry",         0x0F),
    ("peach",              0x15),
    ("bell",               0x16),
    ("apple",              0x14),
    ("grapes",             0x17),
    ("galaxian",           0x09),
    ("key",                0x16),
    ("white_border",       0x1F),
    ("fruit_score",        0x03),
]

COLOR_CODE_LOOKUP = {name: code for name, code in COLOR_CODES}


FRUIT_NONE = 0
FRUIT_CHERRIES = 1
FRUIT_STRAWBERRY = 2
FRUIT_PEACH = 3
FRUIT_APPLE = 4
FRUIT_GRAPES = 5
FRUIT_GALAXIAN = 6
FRUIT_BELL = 7
FRUIT_KEY = 8
NUM_FRUITS = 9

FRUIT_TILES_COLORS: Sequence[Tuple[int, int, int]] = [
    (0x00, 0x00, 0x00),  # NONE
    (0x90, 0x00, 0x14),  # CHERRIES
    (0x94, 0x01, 0x0F),  # STRAWBERRY
    (0x98, 0x02, 0x15),  # PEACH
    (0xA0, 0x04, 0x14),  # APPLE
    (0xA4, 0x05, 0x17),  # GRAPES
    (0xA8, 0x06, 0x09),  # GALAXIAN
    (0x9C, 0x03, 0x16),  # BELL
    (0xAC, 0x07, 0x16),  # KEY
]

FRUIT_SCORE_TILES: Sequence[Tuple[int, int, int, int]] = [
    (0x40, 0x40, 0x40, 0x40),  # NONE
    (0x40, 0x81, 0x85, 0x40),  # 100
    (0x40, 0x82, 0x85, 0x40),  # 300
    (0x40, 0x83, 0x85, 0x40),  # 500
    (0x40, 0x84, 0x85, 0x40),  # 700
    (0x40, 0x86, 0x8D, 0x8E),  # 1000
    (0x87, 0x88, 0x8D, 0x8E),  # 2000
    (0x89, 0x8A, 0x8D, 0x8E),  # 3000
    (0x8B, 0x8C, 0x8D, 0x8E),  # 5000
]

PILL_POSITIONS: Sequence[Tuple[int, int]] = [
    (1, 6), (26, 6), (1, 26), (26, 26)
]

class TileState:
    def __init__(self) -> None:
        self.video = [[TILE_SPACE for _ in range(DISPLAY_TILES_X)] for _ in range(DISPLAY_TILES_Y)]
        self.color = [[0 for _ in range(DISPLAY_TILES_X)] for _ in range(DISPLAY_TILES_Y)]
        self.usage: Dict[int, Set[int]] = defaultdict(set)

    def _record(self, x: int, y: int) -> None:
        tile = self.video[y][x]
        color = self.color[y][x] & 0x1F
        self.usage[tile].add(color)

    def clear(self, tile_code: int, color_code: int) -> None:
        for y in range(DISPLAY_TILES_Y):
            for x in range(DISPLAY_TILES_X):
                self.video[y][x] = tile_code
                self.color[y][x] = color_code
                self._record(x, y)

    def color_playfield(self, color_code: int) -> None:
        for y in range(3, DISPLAY_TILES_Y - 2):
            for x in range(DISPLAY_TILES_X):
                self.color[y][x] = color_code
                self._record(x, y)

    def tile(self, pos: Tuple[int, int], tile_code: int) -> None:
        x, y = pos
        if 0 <= x < DISPLAY_TILES_X and 0 <= y < DISPLAY_TILES_Y:
            self.video[y][x] = tile_code
            self._record(x, y)

    def color_only(self, pos: Tuple[int, int], color_code: int) -> None:
        x, y = pos
        if 0 <= x < DISPLAY_TILES_X and 0 <= y < DISPLAY_TILES_Y:
            self.color[y][x] = color_code
            self._record(x, y)

    def color_tile(self, pos: Tuple[int, int], color_code: int, tile_code: int) -> None:
        x, y = pos
        if 0 <= x < DISPLAY_TILES_X and 0 <= y < DISPLAY_TILES_Y:
            self.video[y][x] = tile_code
            self.color[y][x] = color_code
            self._record(x, y)


def conv_char(c: str) -> int:
    if c == ' ':
        return TILE_SPACE
    if c == '/':
        return 58
    if c == '-':
        return 59
    if c == '"':
        return 38
    if c == '!':
        return ord('Z') + 1
    return ord(c)


def vid_color_char(state: TileState, tile_pos: Tuple[int, int], color_code: int, char: str) -> None:
    state.color_tile(tile_pos, color_code & 0x1F, conv_char(char))


def vid_char(state: TileState, tile_pos: Tuple[int, int], char: str) -> None:
    state.tile(tile_pos, conv_char(char))


def vid_color_text(state: TileState, tile_pos: Tuple[int, int], color_code: int, text: str) -> None:
    x, y = tile_pos
    for ch in text:
        if x >= DISPLAY_TILES_X:
            break
        vid_color_char(state, (x, y), color_code, ch)
        x += 1


def vid_text(state: TileState, tile_pos: Tuple[int, int], text: str) -> None:
    x, y = tile_pos
    for ch in text:
        if x >= DISPLAY_TILES_X:
            break
        vid_char(state, (x, y), ch)
        x += 1


def vid_color_score(state: TileState, tile_pos: Tuple[int, int], color_code: int, score: int) -> None:
    x, y = tile_pos
    vid_color_char(state, (x, y), color_code, '0')
    x -= 1
    tmp = score
    for _ in range(8):
        digit_char = chr((tmp % 10) + ord('0'))
        if x < 0:
            break
        vid_color_char(state, (x, y), color_code, digit_char)
        x -= 1
        tmp //= 10
        if tmp == 0:
            break


def vid_draw_tile_quad(state: TileState, tile_pos: Tuple[int, int], color_code: int, tile_code: int) -> None:
    base_x, base_y = tile_pos
    for yy in range(2):
        for xx in range(2):
            t = tile_code + yy * 2 + (1 - xx)
            state.color_tile((base_x + xx, base_y + yy), color_code, t)


def vid_fruit_score(state: TileState, fruit_type: int) -> None:
    palette_code = COLOR_CODE_LOOKUP["dot"] if fruit_type == FRUIT_NONE else COLOR_CODE_LOOKUP["fruit_score"]
    for idx, tile_code in enumerate(FRUIT_SCORE_TILES[fruit_type]):
        state.color_tile((12 + idx, 20), palette_code, tile_code)


def game_init_playfield(state: TileState) -> None:
    state.color_playfield(COLOR_CODE_LOOKUP["dot"])
    tiles = (
        "0UUUUUUUUUUUU45UUUUUUUUUUUU1"
        "L............rl............R"
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R"
        "LPr  l.r   l.rl.r   l.r  lPR"
        "L.guuh.guuuh.gh.guuuh.guuh.R"
        "L..........................R"
        "L.ebbf.ef.ebbbbbbf.ef.ebbf.R"
        "L.guuh.rl.guuyxuuh.rl.guuh.R"
        "L......rl....rl....rl......R"
        "2BBBBf.rzbbf rl ebbwl.eBBBB3"
        "     L.rxuuh gh guuyl.R     "
        "     L.rl          rl.R     "
        "     L.rl mjs--tjn rl.R     "
        "UUUUUh.gh i      q gh.gUUUUU"
        "      .   i      q   .      "
        "BBBBBf.ef i      q ef.eBBBBB"
        "     L.rl okkkkkkp rl.R     "
        "     L.rl          rl.R     "
        "     L.rl ebbbbbbf rl.R     "
        "0UUUUh.gh guuyxuuh gh.gUUUU1"
        "L............rl............R"
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R"
        "L.guyl.guuuh.gh.guuuh.rxuh.R"
        "LP..rl.......  .......rl..PR"
        "6bf.rl.ef.ebbbbbbf.ef.rl.eb8"
        "7uh.gh.rl.guuyxuuh.rl.gh.gu9"
        "L......rl....rl....rl......R"
        "L.ebbbbwzbbf.rl.ebbwzbbbbf.R"
        "L.guuuuuuuuh.gh.guuuuuuuuh.R"
        "L..........................R"
        "2BBBBBBBBBBBBBBBBBBBBBBBBBB3"
    )
    mapping = {chr(i): TILE_DOT_CODE for i in range(128)}
    mapping.update({
        ' ': TILE_SPACE, '0': 0xD1, '1': 0xD0, '2': 0xD5, '3': 0xD4, '4': 0xFB,
        '5': 0xFA, '6': 0xD7, '7': 0xD9, '8': 0xD6, '9': 0xD8, 'U': 0xDB,
        'L': 0xD3, 'R': 0xD2, 'B': 0xDC, 'b': 0xDF, 'e': 0xE7, 'f': 0xE6,
        'g': 0xEB, 'h': 0xEA, 'l': 0xE8, 'r': 0xE9, 'u': 0xE5, 'w': 0xF5,
        'x': 0xF2, 'y': 0xF3, 'z': 0xF4, 'm': 0xED, 'n': 0xEC, 'o': 0xEF,
        'p': 0xEE, 'j': 0xDD, 'i': 0xD2, 'k': 0xDB, 'q': 0xD3, 's': 0xF1,
        't': 0xF0, '-': TILE_DOOR, 'P': TILE_PILL, '.': TILE_DOT_CODE,
    })

    idx = 0
    for y in range(3, 34):
        for x in range(DISPLAY_TILES_X):
            ch = tiles[idx]
            idx += 1
            state.tile((x, y), mapping.get(ch, TILE_DOT_CODE))
    state.color_only((13, 15), 0x18)
    state.color_only((14, 15), 0x18)


def simulate_tile_usage() -> Dict[int, Set[int]]:
    state = TileState()

    state.clear(TILE_SPACE, COLOR_CODE_LOOKUP["dot"])
    vid_color_text(state, (9, 0), COLOR_CODE_LOOKUP["default"], "HIGH SCORE")
    game_init_playfield(state)
    vid_color_text(state, (9, 14), COLOR_CODE_LOOKUP["inky"], "PLAYER ONE")
    vid_color_text(state, (11, 20), COLOR_CODE_LOOKUP["pacman"], "READY!")
    vid_color_text(state, (11, 20), COLOR_CODE_LOOKUP["dot"], "      ")
    vid_color_score(state, (6, 1), COLOR_CODE_LOOKUP["default"], 98765432)
    vid_color_score(state, (16, 1), COLOR_CODE_LOOKUP["default"], 0)
    for idx, digit in enumerate("0123456789"):
        vid_color_char(state, (20 + idx, 2), COLOR_CODE_LOOKUP["default"], digit)

    for color_code in (COLOR_CODE_LOOKUP["pacman"], 0):
        vid_draw_tile_quad(state, (2, 34), color_code, TILE_LIFE)

    for tile_code, _, color_code in FRUIT_TILES_COLORS:
        if tile_code:
            vid_draw_tile_quad(state, (10, 0), color_code, tile_code)
    for fruit in range(NUM_FRUITS):
        vid_fruit_score(state, fruit)

    for pos in PILL_POSITIONS:
        state.color_only(pos, COLOR_CODE_LOOKUP["dot"])
        state.color_only(pos, 0)

    state.color_playfield(COLOR_CODE_LOOKUP["white_border"])
    state.color_playfield(COLOR_CODE_LOOKUP["dot"])

    vid_color_text(state, (9, 20), COLOR_CODE_LOOKUP["blinky"], "GAME  OVER")

    state.clear(TILE_SPACE, COLOR_CODE_LOOKUP["default"])
    vid_text(state, (3, 0), "1UP   HIGH SCORE   2UP")
    vid_color_score(state, (6, 1), COLOR_CODE_LOOKUP["default"], 0)
    vid_text(state, (7, 5), "CHARACTER / NICKNAME")
    vid_text(state, (3, 35), "CREDIT  0")

    names = ["-SHADOW", "-SPEEDY", "-BASHFUL", "-POKEY"]
    nicknames = ["BLINKY", "PINKY", "INKY", "CLYDE"]
    for i in range(4):
        color = 2 * i + 1
        y = 3 * i + 6
        offsets = [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2)]
        for dx, dy in offsets:
            tile = TILE_GHOST + dy * 2 + dx
            state.color_tile((4 + dx, y + dy), color, tile)
        vid_color_text(state, (7, y + 1), color, names[i])
        vid_color_text(state, (17, y + 1), color, nicknames[i])

    state.color_tile((10, 24), COLOR_CODE_LOOKUP["dot"], TILE_DOT_CODE)
    state.color_tile((10, 26), COLOR_CODE_LOOKUP["dot"], TILE_PILL)
    vid_text(state, (12, 24), "10 \x5D\x5E\x5F")
    vid_text(state, (12, 26), "50 \x5D\x5E\x5F")
    vid_color_text(state, (3, 31), 3, "PRESS ANY KEY TO START!")
    vid_color_text(state, (3, 31), 3, "                       ")

    usage = {tile: set(colors) for tile, colors in state.usage.items() if colors}
    ensure_default_character_usage(usage)
    return usage


DEFAULT_TEXT_CHARACTERS = tuple(chr(code) for code in range(ord('A'), ord('Z') + 1))
DEFAULT_TEXT_PUNCTUATION = ("!", "-")


def ensure_default_character_usage(tile_usage: Dict[int, Set[int]]) -> None:
    """Guarantee that plain alphabet tiles (and needed punctuation) get default palettes."""
    default_code = COLOR_CODE_LOOKUP["default"]
    for char in DEFAULT_TEXT_CHARACTERS + DEFAULT_TEXT_PUNCTUATION:
        tile_code = conv_char(char)
        tile_usage.setdefault(tile_code, set()).add(default_code)

ASSET_DIR = CURRENT_DIR.parent.parent / "assets"
SPRITE_OUTPUT_DIR = Path(f"{ASSET_DIR}/sprites")
SPRITE_OUTPUT_DIR.mkdir(exist_ok=True, parents=True)
TILE_OUTPUT_DIR = Path(f"{ASSET_DIR}/tiles")
TILE_OUTPUT_DIR.mkdir(exist_ok=True, parents=True)

SCALE_FACTOR = 2  # Scaling factor (keep pixel art sharp with nearest-neighbor)
SKIP_FULLY_TRANSPARENT = True  # Skip if the sprite image is fully transparent (all zeros)

# additional sprite-layer PNGs for palette slots (indexed colors 1..3)
SPRITE_LAYER_SUFFIX = {
    1: "layer1",
    2: "layer2",
    3: "layer3",
}

# ---------------------------------------------------------------------------
# 3) Decoder helper functions
# ---------------------------------------------------------------------------

def slot_suffix(slot_value: int) -> str:
    """Return a consistent filename suffix for the given palette slot."""
    return SPRITE_LAYER_SUFFIX.get(slot_value, f"layer{slot_value}")

def load_rom_file(path: Path, expected_size: int) -> List[int]:
    try:
        data = path.read_bytes()
    except FileNotFoundError as err:
        raise FileNotFoundError(f"Could not find {path}. Please provide the corresponding ROM binary first.") from err
    if len(data) != expected_size:
        raise ValueError(f"{path} has {len(data)} bytes, but {expected_size} bytes are required.")
    return list(data)

def ensure_rom_lengths() -> None:
    if len(rom_sprites) != ROM_SPRITES_SIZE:
        raise ValueError(f"rom_sprites must be {ROM_SPRITES_SIZE} bytes long, got {len(rom_sprites)}.")
    if len(rom_sprites) % SPRITE_STRIDE != 0:
        raise ValueError("rom_sprites length must be a multiple of 64.")
    if len(rom_tiles) != ROM_TILES_SIZE:
        raise ValueError(f"rom_tiles must be {ROM_TILES_SIZE} bytes long, got {len(rom_tiles)}.")
    if len(rom_tiles) % TILE_STRIDE != 0:
        raise ValueError("rom_tiles length must be a multiple of 16.")
    if len(rom_hwcolors) != 32:
        raise ValueError("rom_hwcolors length must be 32.")
    if len(rom_palette) != 256:
        raise ValueError("rom_palette length must be 256.")

def decode_hwcolors() -> List[Tuple[int, int, int, int]]:
    """Convert the 32 color PROM entries to RGBA using the hardware formula."""
    colors: List[Tuple[int, int, int, int]] = []
    for entry in rom_hwcolors:
        r = ((entry >> 0) & 1) * 0x21 + ((entry >> 1) & 1) * 0x47 + ((entry >> 2) & 1) * 0x97
        g = ((entry >> 3) & 1) * 0x21 + ((entry >> 4) & 1) * 0x47 + ((entry >> 5) & 1) * 0x97
        b = ((entry >> 6) & 1) * 0x47 + ((entry >> 7) & 1) * 0x97
        colors.append((r, g, b, 255))
    return colors

HW_COLORS_RGBA = decode_hwcolors()

def build_palette_rgba(color_code: int) -> List[Tuple[int, int, int, int]]:
    """
    Build a four-color palette (index 0 transparent) from the sprite color code,
    matching the gfx_decode_color_palette() logic.
    """
    base = (color_code & 0x1F) << 2
    if base + 3 >= len(rom_palette):
        raise IndexError(f"color_code {color_code:#04x} falls outside rom_palette.")

    palette = []
    for i in range(4):
        hw_index = rom_palette[base + i] & 0x0F
        r, g, b, _ = HW_COLORS_RGBA[hw_index]
        a = 0 if i == 0 else 255
        palette.append((r, g, b, a))
    return palette

def decode_sprite(sprite_index: int) -> List[List[int]]:
    """Decode the sprite at sprite_index into a 16x16 index matrix."""
    start = sprite_index * SPRITE_STRIDE
    sprite_bytes = rom_sprites[start:start + SPRITE_STRIDE]

    if len(sprite_bytes) != SPRITE_STRIDE:
        raise ValueError(f"sprite {sprite_index} data is truncated.")

    sprite = [[0] * SPRITE_WIDTH for _ in range(SPRITE_HEIGHT)]
    for (x_off, y_off), block_offset in BLOCKS:
        for tx in range(TILE_WIDTH):
            byte_val = sprite_bytes[block_offset + (7 - tx)]
            for ty in range(BLOCK_HEIGHT):
                p_hi = (byte_val >> (7 - ty)) & 1
                p_lo = (byte_val >> (3 - ty)) & 1
                sprite[y_off + ty][x_off + tx] = (p_hi << 1) | p_lo
    return sprite

def decode_tile(tile_index: int) -> List[List[int]]:
    """Decode the tile at tile_index into an 8x8 index matrix."""
    start = tile_index * TILE_STRIDE
    tile_bytes = rom_tiles[start:start + TILE_STRIDE]

    if len(tile_bytes) != TILE_STRIDE:
        raise ValueError(f"tile {tile_index} data is truncated.")

    tile = [[0] * TILE_WIDTH for _ in range(TILE_HEIGHT)]
    for block_idx, offset in enumerate((8, 0)):
        y_off = block_idx * BLOCK_HEIGHT
        for tx in range(TILE_WIDTH):
            byte_val = tile_bytes[offset + (7 - tx)]
            for ty in range(BLOCK_HEIGHT):
                p_hi = (byte_val >> (7 - ty)) & 1
                p_lo = (byte_val >> (3 - ty)) & 1
                tile[y_off + ty][tx] = (p_hi << 1) | p_lo
    return tile

def is_sprite_fully_transparent(pixels: Iterable[int]) -> bool:
    return all(p == 0 for p in pixels)

def pixels_to_slot_mask(
    pixel_rows: Sequence[Sequence[int]],
    slot_value: int,
    scale: int = 1,
) -> Image.Image:
    """Create a white mask (RGBA) where pixels == slot_value, transparent otherwise."""
    height = len(pixel_rows)
    if height == 0:
        raise ValueError("Pixel data is empty.")
    width = len(pixel_rows[0])

    flat_pixels = []
    for row in pixel_rows:
        for value in row:
            if value == slot_value:
                flat_pixels.append((0xFF, 0xFF, 0xFF, 0xFF))
            else:
                flat_pixels.append((0x00, 0x00, 0x00, 0x00))

    img = Image.new("RGBA", (width, height))
    img.putdata(flat_pixels)

    if scale > 1:
        img = img.resize((width * scale, height * scale), Image.NEAREST)
    return img

# ---------------------------------------------------------------------------
# 4) Export logic
# ---------------------------------------------------------------------------

def export_sprites() -> int:
    num_sprites = len(rom_sprites) // SPRITE_STRIDE
    exported_layers = 0
    for sprite_idx in range(num_sprites):
        sprite_pixels = decode_sprite(sprite_idx)
        flat_indices = [p for row in sprite_pixels for p in row]

        if SKIP_FULLY_TRANSPARENT and is_sprite_fully_transparent(flat_indices):
            continue

        used_slots = sorted({value for value in flat_indices if value})
        if not used_slots:
            continue

        for slot_value in used_slots:
            suffix = slot_suffix(slot_value)
            mask = pixels_to_slot_mask(sprite_pixels, slot_value, scale=SCALE_FACTOR)
            mask_filename = SPRITE_OUTPUT_DIR / f"sprite_{sprite_idx:02d}_{suffix}.png"
            mask.save(mask_filename)
            exported_layers += 1
    return exported_layers


def export_tiles(tile_usage: Dict[int, Set[int]]) -> int:
    num_tiles = len(rom_tiles) // TILE_STRIDE
    exported_layers = 0
    for tile_idx in range(num_tiles):
        if tile_idx not in tile_usage:
            continue
        tile_pixels = decode_tile(tile_idx)
        flat_indices = [p for row in tile_pixels for p in row]
        if SKIP_FULLY_TRANSPARENT and is_sprite_fully_transparent(flat_indices):
            continue

        used_slots = sorted({value for value in flat_indices if value})
        if not used_slots:
            continue

        for slot_value in used_slots:
            suffix = slot_suffix(slot_value)
            mask = pixels_to_slot_mask(tile_pixels, slot_value, scale=SCALE_FACTOR)
            mask_filename = TILE_OUTPUT_DIR / f"tile_{tile_idx:02X}_{suffix}.png"
            mask.save(mask_filename)
            exported_layers += 1
    return exported_layers


def main() -> None:
    global rom_sprites, rom_tiles
    rom_sprites = load_rom_file(ROM_SPRITES_PATH, ROM_SPRITES_SIZE)
    rom_tiles = load_rom_file(ROM_TILES_PATH, ROM_TILES_SIZE)
    ensure_rom_lengths()

    sprite_layers_written = export_sprites()
    print(f"Sprite export complete: generated {sprite_layers_written} layer PNG files at {SPRITE_OUTPUT_DIR.resolve()}")

    tile_usage = simulate_tile_usage()
    tile_layers_written = export_tiles(tile_usage)
    print(f"Tile export complete: generated {tile_layers_written} layer PNG files at {TILE_OUTPUT_DIR.resolve()}")


if __name__ == "__main__":
    main()
