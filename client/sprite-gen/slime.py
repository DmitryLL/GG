from PIL import Image
import os

W, H = 32, 32
FRAMES = 2  # idle, squished

OUT = "/gg/client/public/sprites"


def draw_slime(img, ox, oy, squished):
    body = (90, 180, 100, 255)
    body_dk = (50, 130, 60, 255)
    hl = (160, 230, 160, 255)
    eye = (20, 20, 30, 255)

    # body shape
    if squished:
        # flatter
        top = 14
        bot = 28
    else:
        top = 10
        bot = 28

    # rough ellipse
    cx = 16
    for y in range(top, bot + 1):
        # ellipse half-width based on y
        t = (y - top) / (bot - top) if bot != top else 0
        # widest in middle-bottom
        w = 10 - int(abs(t - 0.7) * 10)
        w = max(3, w)
        for x in range(cx - w, cx + w + 1):
            img.putpixel((ox + x, oy + y), body)
    # outline
    for y in range(top, bot + 1):
        t = (y - top) / (bot - top) if bot != top else 0
        w = 10 - int(abs(t - 0.7) * 10)
        w = max(3, w)
        img.putpixel((ox + cx - w, oy + y), body_dk)
        img.putpixel((ox + cx + w, oy + y), body_dk)
    for x in range(cx - 10, cx + 11):
        if 0 <= x < W:
            img.putpixel((ox + x, oy + bot + 1), body_dk)

    # highlight
    for x in range(cx - 5, cx - 1):
        img.putpixel((ox + x, oy + top + 2), hl)

    # eyes
    eye_y = (top + bot) // 2
    img.putpixel((ox + cx - 3, oy + eye_y), eye)
    img.putpixel((ox + cx - 3, oy + eye_y + 1), eye)
    img.putpixel((ox + cx + 3, oy + eye_y), eye)
    img.putpixel((ox + cx + 3, oy + eye_y + 1), eye)


def make_sheet():
    sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
    draw_slime(sheet, 0, 0, squished=False)
    draw_slime(sheet, W, 0, squished=True)
    os.makedirs(OUT, exist_ok=True)
    path = f"{OUT}/slime.png"
    sheet.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    make_sheet()
