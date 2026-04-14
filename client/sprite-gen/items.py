from PIL import Image
import os

W, H = 16, 16
COUNT = 1

OUT = "/gg/client/public/sprites"


def draw_slime_jelly(img, ox, oy):
    body = (90, 220, 120, 255)
    body_dk = (50, 160, 70, 255)
    hl = (200, 255, 210, 255)
    # blob
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
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '#':
                img.putpixel((ox + x, oy + y), body)
    # darker outline
    for y in range(H):
        for x in range(W):
            px = img.getpixel((ox + x, oy + y))
            if px == body:
                # check neighbors
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H:
                        if img.getpixel((ox + nx, oy + ny)) != body and img.getpixel((ox + nx, oy + ny)) != body_dk:
                            img.putpixel((ox + x, oy + y), body_dk)
                            break
    # highlight
    img.putpixel((ox + 5, oy + 3), hl)
    img.putpixel((ox + 6, oy + 3), hl)
    img.putpixel((ox + 4, oy + 4), hl)


def make_sheet():
    sheet = Image.new("RGBA", (W * COUNT, H), (0, 0, 0, 0))
    draw_slime_jelly(sheet, 0, 0)
    os.makedirs(OUT, exist_ok=True)
    path = f"{OUT}/items.png"
    sheet.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    make_sheet()
