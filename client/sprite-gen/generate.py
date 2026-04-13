from PIL import Image
import os

W, H = 32, 32  # per frame
COLS, ROWS = 3, 4  # 3 walk frames, 4 directions (down, left, right, up)

# palette — anime chibi feel
SKIN     = (255, 220, 185, 255)
SKIN_DK  = (210, 170, 140, 255)
HAIR     = (60,  40,  30,  255)
HAIR_HL  = (110, 80,  60,  255)
EYE      = (20,  20,  30,  255)
SHIRT    = (80,  150, 220, 255)
SHIRT_DK = (50,  100, 170, 255)
PANTS    = (60,  50,  90,  255)
PANTS_DK = (40,  30,  60,  255)
SHOE     = (40,  30,  25,  255)
OUTLINE  = (25,  20,  25,  255)

HAIR_VARIANTS = [
    ((60,  40,  30,  255), (110, 80,  60,  255)),   # brown
    ((230, 200, 90,  255), (255, 235, 140, 255)),   # blonde
    ((160, 40,  50,  255), (220, 80,  90,  255)),   # red
    ((60,  120, 180, 255), (120, 180, 230, 255)),   # anime blue
    ((140, 80,  180, 255), (190, 140, 220, 255)),   # purple
    ((50,  140, 80,  255), (100, 200, 130, 255)),   # green
]

SHIRT_VARIANTS = [
    ((200, 60,  60,  255), (150, 40,  40,  255)),
    ((60,  150, 220, 255), (40,  100, 170, 255)),
    ((220, 160, 60,  255), (170, 110, 30,  255)),
    ((80,  180, 120, 255), (40,  130, 80,  255)),
    ((180, 80,  180, 255), (130, 40,  130, 255)),
    ((240, 240, 245, 255), (180, 180, 190, 255)),
]


def pix(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            pix(img, xx, yy, c)


def outline_rect(img, x, y, w, h, fill, outline):
    rect(img, x, y, w, h, fill)
    for xx in range(x, x + w):
        pix(img, xx, y, outline)
        pix(img, xx, y + h - 1, outline)
    for yy in range(y, y + h):
        pix(img, x, yy, outline)
        pix(img, x + w - 1, yy, outline)


def draw_frame(img, ox, oy, direction, step, hair_pair, shirt_pair):
    """
    direction: 0=down, 1=left, 2=right, 3=up
    step: 0=idle, 1=left-step, 2=right-step
    Character layout inside 32x32 with feet at row 30:
      hair/head: y 6..14
      body:      y 15..23
      legs:      y 24..30
    """
    hair_dk, hair_hl = hair_pair
    shirt_main, shirt_dk = shirt_pair

    # center x = 16
    cx = 16

    # Head — 10 wide, 10 tall (y 5..14)
    head_y = 5
    head_h = 10
    head_x = cx - 5
    head_w = 10

    # hair back (covers entire head top + sides)
    rect(img, ox + head_x - 1, oy + head_y - 1, head_w + 2, 5, hair_dk)

    # face skin
    rect(img, ox + head_x, oy + head_y + 3, head_w, head_h - 3, SKIN)

    # face outline
    for yy in range(head_y + 2, head_y + head_h + 1):
        pix(img, ox + head_x - 1, oy + yy, OUTLINE)
        pix(img, ox + head_x + head_w, oy + yy, OUTLINE)
    for xx in range(head_x - 1, head_x + head_w + 1):
        pix(img, ox + xx, oy + head_y + head_h, OUTLINE)

    # hair highlights — top
    for xx in range(head_x, head_x + head_w, 2):
        pix(img, ox + xx, oy + head_y, hair_hl)
    # hair bangs
    rect(img, ox + head_x, oy + head_y + 3, head_w, 1, hair_dk)
    pix(img, ox + head_x + 3, oy + head_y + 3, hair_hl)
    pix(img, ox + head_x + 6, oy + head_y + 3, hair_hl)

    # eyes by direction
    if direction == 0:  # down — eyes visible
        pix(img, ox + head_x + 2, oy + head_y + 5, EYE)
        pix(img, ox + head_x + 2, oy + head_y + 6, EYE)
        pix(img, ox + head_x + 7, oy + head_y + 5, EYE)
        pix(img, ox + head_x + 7, oy + head_y + 6, EYE)
        # mouth
        pix(img, ox + cx, oy + head_y + 8, OUTLINE)
    elif direction == 1:  # left
        pix(img, ox + head_x + 1, oy + head_y + 5, EYE)
        pix(img, ox + head_x + 1, oy + head_y + 6, EYE)
        pix(img, ox + head_x + 5, oy + head_y + 5, EYE)
        pix(img, ox + head_x + 5, oy + head_y + 6, EYE)
    elif direction == 2:  # right
        pix(img, ox + head_x + 4, oy + head_y + 5, EYE)
        pix(img, ox + head_x + 4, oy + head_y + 6, EYE)
        pix(img, ox + head_x + 8, oy + head_y + 5, EYE)
        pix(img, ox + head_x + 8, oy + head_y + 6, EYE)
    else:  # up — back of head, all hair
        rect(img, ox + head_x, oy + head_y + 3, head_w, head_h - 3, hair_dk)
        for xx in range(head_x, head_x + head_w, 2):
            pix(img, ox + xx, oy + head_y + 5, hair_hl)

    # Body — shirt, y 16..22 (7 rows)
    body_y = 16
    body_h = 7
    body_x = cx - 4
    body_w = 8
    rect(img, ox + body_x, oy + body_y, body_w, body_h, shirt_main)
    # shading
    for yy in range(body_y, body_y + body_h):
        pix(img, ox + body_x + body_w - 1, oy + yy, shirt_dk)
    # outline
    for yy in range(body_y, body_y + body_h):
        pix(img, ox + body_x - 1, oy + yy, OUTLINE)
        pix(img, ox + body_x + body_w, oy + yy, OUTLINE)

    # Arms — swing with step
    arm_swing = {0: 0, 1: -1, 2: 1}[step]
    if direction == 3:  # up
        # arms at back, hidden behind body mostly
        pass
    else:
        la_y = body_y + (1 if direction != 1 else 0) + arm_swing
        ra_y = body_y + (1 if direction != 2 else 0) - arm_swing
        # left arm
        rect(img, ox + body_x - 1, oy + la_y, 1, 4, SKIN)
        pix(img, ox + body_x - 2, oy + la_y + 3, SKIN)
        # right arm
        rect(img, ox + body_x + body_w, oy + ra_y, 1, 4, SKIN)
        pix(img, ox + body_x + body_w + 1, oy + ra_y + 3, SKIN)

    # Legs — pants y 23..28
    leg_y = 23
    leg_h = 6
    # leg animation
    if step == 0:
        ll_off, rl_off = 0, 0
    elif step == 1:
        ll_off, rl_off = -1, 1
    else:
        ll_off, rl_off = 1, -1
    # left leg
    rect(img, ox + cx - 3, oy + leg_y + ll_off, 3, leg_h - ll_off, PANTS)
    # right leg
    rect(img, ox + cx, oy + leg_y + rl_off, 3, leg_h - rl_off, PANTS)
    # leg outlines + feet
    for yy in range(leg_y, leg_y + leg_h):
        pix(img, ox + cx - 4, oy + yy, OUTLINE)
        pix(img, ox + cx + 3, oy + yy, OUTLINE)
        pix(img, ox + cx - 1, oy + yy, OUTLINE)
    # shoes
    rect(img, ox + cx - 3, oy + leg_y + leg_h + ll_off - 1, 3, 1, SHOE)
    rect(img, ox + cx, oy + leg_y + leg_h + rl_off - 1, 3, 1, SHOE)


def make_sheet(hair_pair, shirt_pair, out_path):
    sheet = Image.new("RGBA", (W * COLS, H * ROWS), (0, 0, 0, 0))
    for row in range(ROWS):
        for col in range(COLS):
            draw_frame(sheet, col * W, row * H, row, col, hair_pair, shirt_pair)
    sheet.save(out_path)
    print(f"wrote {out_path}")


OUT = "/gg/client/public/sprites"
os.makedirs(OUT, exist_ok=True)

for i, (hair, shirt) in enumerate(zip(HAIR_VARIANTS, SHIRT_VARIANTS)):
    make_sheet(hair, shirt, f"{OUT}/char_{i}.png")
