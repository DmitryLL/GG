from PIL import Image
import os

W, H = 32, 32
OUT = "/gg/client/public/sprites"


def draw_merchant(img, ox, oy):
    skin = (255, 220, 185, 255)
    beard = (180, 180, 180, 255)
    robe = (180, 80, 60, 255)
    robe_dk = (120, 40, 30, 255)
    robe_hl = (220, 120, 100, 255)
    gold = (220, 180, 40, 255)
    hat = (90, 60, 40, 255)
    outline = (30, 20, 20, 255)

    # head
    for y in range(4, 13):
        for x in range(11, 21):
            img.putpixel((ox + x, oy + y), skin)
    # hat brim
    for x in range(9, 23):
        img.putpixel((ox + x, oy + 4), hat)
    for x in range(10, 22):
        img.putpixel((ox + x, oy + 3), hat)
    for x in range(12, 20):
        img.putpixel((ox + x, oy + 2), hat)
    # hat top
    for y in range(0, 2):
        for x in range(13, 19):
            img.putpixel((ox + x, oy + y), hat)
    # eyes
    img.putpixel((ox + 13, oy + 7), outline)
    img.putpixel((ox + 18, oy + 7), outline)
    # beard
    for y in range(10, 14):
        for x in range(11, 21):
            img.putpixel((ox + x, oy + y), beard)
    # head outline
    for x in range(10, 22):
        img.putpixel((ox + x, oy + 13), outline)
    for y in range(4, 13):
        img.putpixel((ox + 10, oy + y), outline)
        img.putpixel((ox + 21, oy + y), outline)

    # robe
    for y in range(14, 28):
        for x in range(9, 23):
            img.putpixel((ox + x, oy + y), robe)
    # robe shading (right side)
    for y in range(14, 28):
        img.putpixel((ox + 21, oy + y), robe_dk)
        img.putpixel((ox + 22, oy + y), robe_dk)
    # highlight
    for y in range(16, 25):
        img.putpixel((ox + 10, oy + y), robe_hl)

    # gold trim / belt
    for x in range(9, 23):
        img.putpixel((ox + x, oy + 20), gold)

    # arms
    for y in range(15, 21):
        img.putpixel((ox + 8, oy + y), skin)
        img.putpixel((ox + 23, oy + y), skin)
    # hands
    img.putpixel((ox + 7, oy + 20), skin)
    img.putpixel((ox + 24, oy + 20), skin)

    # robe outline
    for y in range(14, 29):
        img.putpixel((ox + 8, oy + y), outline)
        img.putpixel((ox + 23, oy + y), outline)
    for x in range(8, 24):
        img.putpixel((ox + x, oy + 29), outline)


def main():
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_merchant(sheet, 0, 0)
    os.makedirs(OUT, exist_ok=True)
    path = f"{OUT}/npc.png"
    sheet.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
