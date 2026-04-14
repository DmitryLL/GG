from PIL import Image
import os
import random

T = 32  # tile size
TILE_COUNT = 6  # grass, sand, water, tree, stone, path

OUT = "/gg/client/public/sprites"


def rect(img, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= xx < img.width and 0 <= yy < img.height:
                img.putpixel((xx, yy), c)


def noise_fill(img, ox, oy, base, accent, density=0.15, seed=0):
    rng = random.Random(seed)
    for y in range(T):
        for x in range(T):
            img.putpixel((ox + x, oy + y), base)
    for _ in range(int(T * T * density)):
        x = rng.randrange(T)
        y = rng.randrange(T)
        img.putpixel((ox + x, oy + y), accent)


def draw_grass(img, ox, oy):
    base = (74, 124, 78, 255)
    dark = (54, 104, 58, 255)
    light = (104, 154, 88, 255)
    noise_fill(img, ox, oy, base, dark, 0.18, seed=1)
    rng = random.Random(2)
    for _ in range(int(T * T * 0.10)):
        x = rng.randrange(T)
        y = rng.randrange(T)
        img.putpixel((ox + x, oy + y), light)


def draw_sand(img, ox, oy):
    base = (218, 196, 148, 255)
    dark = (188, 162, 112, 255)
    light = (238, 220, 178, 255)
    noise_fill(img, ox, oy, base, dark, 0.12, seed=3)
    rng = random.Random(4)
    for _ in range(int(T * T * 0.08)):
        x = rng.randrange(T)
        y = rng.randrange(T)
        img.putpixel((ox + x, oy + y), light)


def draw_water(img, ox, oy):
    base = (58, 110, 168, 255)
    dark = (38, 86, 140, 255)
    light = (118, 170, 220, 255)
    rect(img, ox, oy, T, T, base)
    rng = random.Random(5)
    # wave lines
    for i in range(0, T, 6):
        y = (i + rng.randrange(3)) % T
        for x in range(T):
            if ((x + i) // 3) % 2 == 0:
                img.putpixel((ox + x, oy + y), light)
    # dark flecks
    for _ in range(int(T * T * 0.06)):
        x = rng.randrange(T)
        y = rng.randrange(T)
        img.putpixel((ox + x, oy + y), dark)


def draw_tree(img, ox, oy):
    # ground under tree
    draw_grass(img, ox, oy)
    # trunk
    trunk = (88, 58, 34, 255)
    trunk_dk = (64, 40, 22, 255)
    rect(img, ox + 14, oy + 20, 4, 10, trunk)
    for y in range(20, 30):
        img.putpixel((ox + 14, oy + y), trunk_dk)
    # foliage
    leaf = (40, 108, 52, 255)
    leaf_dk = (24, 78, 36, 255)
    leaf_hl = (88, 156, 78, 255)
    # blob shape
    blob = [
        (10, 18), (22, 18),
        (8, 14), (24, 14),
        (6, 10), (26, 10),
        (8, 6), (24, 6),
        (12, 3), (20, 3),
    ]
    rect(img, ox + 8, oy + 4, 16, 16, leaf)
    rect(img, ox + 6, oy + 8, 20, 10, leaf)
    # dark edge
    for x in range(6, 26):
        img.putpixel((ox + x, oy + 4), leaf_dk)
        img.putpixel((ox + x, oy + 19), leaf_dk)
    for y in range(4, 20):
        img.putpixel((ox + 6, oy + y), leaf_dk)
        img.putpixel((ox + 25, oy + y), leaf_dk)
    # highlights
    rng = random.Random(7)
    for _ in range(20):
        x = rng.randrange(8, 24)
        y = rng.randrange(5, 18)
        img.putpixel((ox + x, oy + y), leaf_hl)


def draw_stone(img, ox, oy):
    base = (130, 130, 140, 255)
    dark = (90, 90, 100, 255)
    light = (170, 170, 180, 255)
    rect(img, ox, oy, T, T, base)
    # brick pattern
    for by in range(0, T, 8):
        for x in range(T):
            img.putpixel((ox + x, oy + by), dark)
    for by in range(0, T, 16):
        for y in range(by, by + 8):
            img.putpixel((ox + 0, oy + y), dark)
            img.putpixel((ox + 16, oy + y), dark)
    for by in range(8, T, 16):
        for y in range(by, by + 8):
            img.putpixel((ox + 8, oy + y), dark)
            img.putpixel((ox + 24, oy + y), dark)
    rng = random.Random(9)
    for _ in range(20):
        x = rng.randrange(T)
        y = rng.randrange(T)
        img.putpixel((ox + x, oy + y), light)


def draw_path(img, ox, oy):
    base = (168, 146, 102, 255)
    dark = (128, 108, 70, 255)
    noise_fill(img, ox, oy, base, dark, 0.20, seed=11)


DRAWERS = [draw_grass, draw_sand, draw_water, draw_tree, draw_stone, draw_path]


def make_sheet():
    sheet = Image.new("RGBA", (T * TILE_COUNT, T), (0, 0, 0, 0))
    for i, fn in enumerate(DRAWERS):
        fn(sheet, i * T, 0)
    os.makedirs(OUT, exist_ok=True)
    path = f"{OUT}/tiles.png"
    sheet.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    make_sheet()
