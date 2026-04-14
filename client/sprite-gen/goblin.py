from PIL import Image
import os

W, H = 32, 32
FRAMES = 2
OUT = "/gg/client/public/sprites"


def draw_goblin(img, ox, oy, walk):
    skin = (120, 160, 80, 255)
    skin_dk = (80, 120, 50, 255)
    loin = (100, 60, 40, 255)
    loin_dk = (70, 40, 25, 255)
    eye = (200, 40, 40, 255)
    outline = (30, 40, 20, 255)
    # head
    head_y = 6
    head_x = 11
    for y in range(head_y, head_y + 9):
        for x in range(head_x, head_x + 10):
            img.putpixel((ox + x, oy + y), skin)
    # ears (pointy)
    for y in range(head_y + 2, head_y + 6):
        img.putpixel((ox + head_x - 1, oy + y), skin)
        img.putpixel((ox + head_x + 10, oy + y), skin)
    img.putpixel((ox + head_x - 2, oy + head_y + 3), skin)
    img.putpixel((ox + head_x + 11, oy + head_y + 3), skin)
    # head shading
    for y in range(head_y, head_y + 9):
        img.putpixel((ox + head_x + 9, oy + y), skin_dk)
    # eyes
    img.putpixel((ox + head_x + 2, oy + head_y + 4), eye)
    img.putpixel((ox + head_x + 3, oy + head_y + 4), eye)
    img.putpixel((ox + head_x + 6, oy + head_y + 4), eye)
    img.putpixel((ox + head_x + 7, oy + head_y + 4), eye)
    # mouth / fangs
    img.putpixel((ox + head_x + 3, oy + head_y + 7), outline)
    img.putpixel((ox + head_x + 6, oy + head_y + 7), outline)
    # outline head
    for x in range(head_x - 1, head_x + 11):
        img.putpixel((ox + x, oy + head_y - 1), outline)
        img.putpixel((ox + x, oy + head_y + 9), outline)
    for y in range(head_y, head_y + 9):
        img.putpixel((ox + head_x - 1, oy + y), outline)
        img.putpixel((ox + head_x + 10, oy + y), outline)

    # body (loincloth)
    body_x = 12
    for y in range(16, 23):
        for x in range(body_x, body_x + 8):
            img.putpixel((ox + x, oy + y), skin)
    # loincloth
    for y in range(21, 25):
        for x in range(body_x, body_x + 8):
            img.putpixel((ox + x, oy + y), loin)
    for x in range(body_x, body_x + 8):
        img.putpixel((ox + x, oy + 24), loin_dk)

    # legs — shift with walk
    leg_off = 1 if walk else 0
    for y in range(24, 30):
        for x in range(body_x, body_x + 3):
            img.putpixel((ox + x, oy + y + leg_off), skin)
        for x in range(body_x + 5, body_x + 8):
            img.putpixel((ox + x, oy + y - leg_off), skin)

    # arms
    for y in range(17, 22):
        img.putpixel((ox + body_x - 1, oy + y), skin)
        img.putpixel((ox + body_x + 8, oy + y), skin)

    # outline body sides
    for y in range(16, 30):
        px = body_x - 2 if walk else body_x - 2
        if 0 <= px < W:
            img.putpixel((ox + body_x - 2, oy + y), outline)
            img.putpixel((ox + body_x + 9, oy + y), outline)


def make_sheet():
    sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
    draw_goblin(sheet, 0, 0, False)
    draw_goblin(sheet, W, 0, True)
    os.makedirs(OUT, exist_ok=True)
    path = f"{OUT}/goblin.png"
    sheet.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    make_sheet()
