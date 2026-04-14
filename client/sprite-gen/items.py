from PIL import Image
import os

W, H = 16, 16

OUT = "/gg/client/public/sprites"


def put(img, ox, oy, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((ox + x, oy + y), c)


def rect(img, ox, oy, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(img, ox, oy, xx, yy, c)


def draw_slime_jelly(img, ox, oy):
    body = (90, 220, 120, 255)
    body_dk = (40, 150, 60, 255)
    hl = (200, 255, 210, 255)
    rows = [
        "....######......",
        "...########.....",
        "..##########....",
        ".############...",
        ".############...",
        ".############...",
        "..##########....",
        "...########.....",
        "....######......",
    ]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '#':
                put(img, ox, oy, x, y, body)
    for y in range(H):
        for x in range(W):
            if img.getpixel((ox + x, oy + y)) == body:
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    c = img.getpixel((ox + nx, oy + ny)) if 0 <= nx < W and 0 <= ny < H else (0, 0, 0, 0)
                    if c == (0, 0, 0, 0):
                        put(img, ox, oy, x, y, body_dk)
                        break
    put(img, ox, oy, 5, 3, hl)
    put(img, ox, oy, 6, 3, hl)


def draw_wood_sword(img, ox, oy):
    hilt = (100, 60, 30, 255)
    pommel = (180, 130, 60, 255)
    blade = (200, 200, 210, 255)
    blade_dk = (120, 120, 140, 255)
    # Blade diagonal top-left to bottom-right-ish
    points = [(3, 2), (4, 3), (5, 4), (6, 5), (7, 6), (8, 7), (9, 8)]
    for (x, y) in points:
        put(img, ox, oy, x, y, blade)
        put(img, ox, oy, x + 1, y, blade)
        put(img, ox, oy, x, y + 1, blade_dk)
    # Guard
    rect(img, ox, oy, 9, 8, 3, 2, hilt)
    # Hilt
    rect(img, ox, oy, 10, 9, 3, 4, hilt)
    # Pommel
    put(img, ox, oy, 11, 13, pommel)
    put(img, ox, oy, 12, 13, pommel)


def draw_iron_sword(img, ox, oy):
    hilt = (60, 50, 80, 255)
    pommel = (200, 180, 80, 255)
    blade = (220, 230, 240, 255)
    blade_dk = (140, 150, 170, 255)
    points = [(2, 1), (3, 2), (4, 3), (5, 4), (6, 5), (7, 6), (8, 7), (9, 8)]
    for (x, y) in points:
        put(img, ox, oy, x, y, blade)
        put(img, ox, oy, x + 1, y, blade)
        put(img, ox, oy, x, y + 1, blade_dk)
    rect(img, ox, oy, 9, 8, 4, 2, hilt)
    rect(img, ox, oy, 10, 9, 3, 5, hilt)
    put(img, ox, oy, 11, 14, pommel)
    put(img, ox, oy, 12, 14, pommel)


def draw_cloth_armor(img, ox, oy):
    cloth = (120, 100, 170, 255)
    cloth_dk = (80, 60, 120, 255)
    belt = (80, 50, 30, 255)
    # body
    rect(img, ox, oy, 4, 3, 8, 9, cloth)
    # shoulders
    rect(img, ox, oy, 3, 4, 1, 4, cloth_dk)
    rect(img, ox, oy, 12, 4, 1, 4, cloth_dk)
    # neck
    rect(img, ox, oy, 7, 2, 2, 2, cloth_dk)
    # belt
    rect(img, ox, oy, 4, 9, 8, 1, belt)
    # outline
    for y in range(3, 12):
        put(img, ox, oy, 3, y, cloth_dk)
        put(img, ox, oy, 12, y, cloth_dk)
    rect(img, ox, oy, 4, 12, 8, 1, cloth_dk)


def draw_iron_armor(img, ox, oy):
    plate = (160, 170, 190, 255)
    plate_dk = (90, 100, 120, 255)
    plate_hl = (220, 225, 235, 255)
    rect(img, ox, oy, 4, 3, 8, 9, plate)
    rect(img, ox, oy, 3, 4, 1, 4, plate_dk)
    rect(img, ox, oy, 12, 4, 1, 4, plate_dk)
    rect(img, ox, oy, 7, 2, 2, 2, plate_dk)
    # rivets
    put(img, ox, oy, 5, 5, plate_dk)
    put(img, ox, oy, 10, 5, plate_dk)
    put(img, ox, oy, 5, 9, plate_dk)
    put(img, ox, oy, 10, 9, plate_dk)
    # highlight
    rect(img, ox, oy, 5, 4, 1, 4, plate_hl)
    for y in range(3, 12):
        put(img, ox, oy, 3, y, plate_dk)
        put(img, ox, oy, 12, y, plate_dk)
    rect(img, ox, oy, 4, 12, 8, 1, plate_dk)


DRAWERS = [draw_slime_jelly, draw_wood_sword, draw_iron_sword, draw_cloth_armor, draw_iron_armor]


def make_sheet():
    sheet = Image.new("RGBA", (W * len(DRAWERS), H), (0, 0, 0, 0))
    for i, fn in enumerate(DRAWERS):
        fn(sheet, i * W, 0)
    os.makedirs(OUT, exist_ok=True)
    path = f"{OUT}/items.png"
    sheet.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    make_sheet()
