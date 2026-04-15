#!/usr/bin/env python3
"""Перерисовка мобов — slime и goblin, 32×32, 2 кадра горизонтально.

Формат ожидаемый клиентом (mob.gd): hframes=2, vframes=1 → 64×32.
Стиль: крупный тёмный аутлайн, 3–4 оттенка тела, одно-пиксельный
спекуляр (белый блик), лёгкая тень «лужей» под ногами.
"""
from PIL import Image

TRANSP = (0, 0, 0, 0)

def blit(dst, x, y, pix):
    w, h = pix.size
    for yy in range(h):
        for xx in range(w):
            c = pix.getpixel((xx, yy))
            if c[3] > 0:
                dst.putpixel((x + xx, y + yy), c)

def put(img, x, y, c):
    if 0 <= x < img.size[0] and 0 <= y < img.size[1]:
        img.putpixel((x, y), c)

def fill_rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


# ---------- SLIME ----------
# Палитра — голубо-зелёный «кисель»
SL_OUT = (10, 28, 30, 255)        # аутлайн
SL_DARK = (22, 74, 82, 255)        # тёмный низ
SL_MID  = (48, 130, 130, 255)      # средний
SL_LIGHT = (100, 200, 185, 255)    # верх
SL_HI = (215, 250, 240, 255)       # спекуляр
EYE_W = (250, 250, 250, 255)
EYE_B = (12, 12, 12, 255)
SHADOW = (0, 0, 0, 90)

def draw_slime(frame):
    im = Image.new("RGBA", (32, 32), TRANSP)
    squash = 0 if frame == 0 else 1  # второй кадр — чуть приплюснутый

    # Базовая «капля»: строки y от 10+squash до 25
    # Силуэт по рядам (полу-ширина от центра x=16)
    # Более округлый купол, широкая база.
    shape = [
        # y: half-width
        (10, 5), (11, 7), (12, 8),
        (13, 9), (14, 10), (15, 11), (16, 12),
        (17, 12), (18, 13), (19, 13), (20, 13),
        (21, 13), (22, 14), (23, 14), (24, 14),
        (25, 14), (26, 13),
    ]
    # Сжатие для кадра 2: срезаем верхние 1 строку
    if squash:
        shape = [(y + 1, max(w - 0, w)) for (y, w) in shape]

    # Заливка с вертикальным градиентом
    y_top = shape[0][0]
    y_bot = shape[-1][0]
    h = y_bot - y_top
    for (y, w) in shape:
        t = (y - y_top) / max(1, h)
        # Нижние → темнее; верхние → светлее
        if t < 0.25:
            body = SL_LIGHT
        elif t < 0.65:
            body = SL_MID
        else:
            body = SL_DARK
        for x in range(16 - w, 16 + w):
            put(im, x, y, body)

    # Аутлайн — обвести силуэт
    def inside(x, y):
        for (yy, ww) in shape:
            if yy == y and 16 - ww <= x < 16 + ww:
                return True
        return False

    for y in range(32):
        for x in range(32):
            if inside(x, y):
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    if not inside(x + dx, y + dy):
                        put(im, x + dx, y + dy, SL_OUT)

    # Спекуляр — 2×2 пятно в верх-лево
    for (yy, ww) in shape:
        if yy == y_top + 2:
            put(im, 16 - ww + 2, yy, SL_HI)
            put(im, 16 - ww + 3, yy, SL_HI)
            put(im, 16 - ww + 2, yy + 1, SL_HI)
        if yy == y_top + 3:
            put(im, 16 - ww + 3, yy, SL_HI)

    # Глазки — чуть выше центра, слегка врозь
    eye_y = y_top + 6
    for ex in [-4, 3]:
        # белок
        put(im, 16 + ex, eye_y, EYE_W)
        put(im, 16 + ex + 1, eye_y, EYE_W)
        put(im, 16 + ex, eye_y + 1, EYE_W)
        put(im, 16 + ex + 1, eye_y + 1, EYE_W)
        # зрачок
        put(im, 16 + ex + 1, eye_y + 1, EYE_B)
        put(im, 16 + ex, eye_y + 1, EYE_B)

    # Улыбка — одна строка
    mouth_y = y_top + 9
    for dx in [-2, -1, 0, 1, 2]:
        put(im, 16 + dx, mouth_y, SL_OUT)
    put(im, 16 - 3, mouth_y - 1, SL_OUT)
    put(im, 16 + 3, mouth_y - 1, SL_OUT)

    # Тень «лужей» под слаймом
    for dy in range(1, 3):
        for dx in range(-10, 10):
            y = 27 + dy
            a_step = 1.0 - dy * 0.4
            alpha = int(90 * (1 - abs(dx) / 10) * a_step)
            if alpha > 0:
                put(im, 16 + dx, y, (0, 0, 0, max(0, min(255, alpha))))

    return im


# ---------- GOBLIN ----------
# Зелёная кожа, красные глаза, кожаная повязка, кривой кинжал
GB_OUT = (14, 20, 12, 255)
GB_SKIN_D = (55, 88, 42, 255)
GB_SKIN_M = (90, 135, 62, 255)
GB_SKIN_H = (140, 190, 90, 255)
GB_CLOTH_D = (60, 38, 22, 255)
GB_CLOTH_M = (110, 68, 40, 255)
GB_CLOTH_H = (165, 110, 68, 255)
GB_EYE = (215, 30, 30, 255)
GB_EYE_HI = (255, 190, 100, 255)
GB_METAL_D = (90, 90, 100, 255)
GB_METAL_M = (160, 160, 170, 255)
GB_METAL_H = (230, 230, 235, 255)
GB_HAFT = (80, 50, 28, 255)
GB_TOOTH = (235, 230, 200, 255)

def draw_goblin(frame):
    im = Image.new("RGBA", (32, 32), TRANSP)
    # Кадр 0 — стоит; кадр 1 — чуть качнулся (голова/руки на 1px)
    dy = 0 if frame == 0 else -1  # подпрыгнул
    arm_y = 0 if frame == 0 else -1

    # ========== Голова ==========
    # Крупная, ушастая (шире в зоне 10..22 по X)
    head_y0 = 5 + dy
    head_y1 = 14 + dy

    # Уши (треугольники)
    ears = [
        # левое ухо
        (9, head_y0 + 2), (8, head_y0 + 3), (7, head_y0 + 4),
        (8, head_y0 + 5), (9, head_y0 + 6),
        # правое ухо (зеркально)
        (22, head_y0 + 2), (23, head_y0 + 3), (24, head_y0 + 4),
        (23, head_y0 + 5), (22, head_y0 + 6),
    ]
    # Череп — овал
    skull = []
    for y in range(head_y0, head_y1 + 1):
        t = (y - head_y0) / (head_y1 - head_y0)
        # ширина макушка → подбородок
        if t < 0.15:
            w = 4
        elif t < 0.5:
            w = 6
        elif t < 0.85:
            w = 6
        else:
            w = 5
        for x in range(16 - w, 16 + w):
            skull.append((x, y))

    for (x, y) in skull:
        put(im, x, y, GB_SKIN_M)
    for (x, y) in ears:
        put(im, x, y, GB_SKIN_M)

    # Верхний блик на лбу
    for x in range(11, 17):
        put(im, x, head_y0 + 1, GB_SKIN_H)
    put(im, 10, head_y0 + 2, GB_SKIN_H)
    put(im, 11, head_y0 + 2, GB_SKIN_H)

    # Нижняя тень (подбородок)
    for x in range(12, 21):
        put(im, x, head_y1, GB_SKIN_D)

    # Нос — крючок
    put(im, 16, head_y0 + 6, GB_SKIN_D)
    put(im, 17, head_y0 + 7, GB_SKIN_D)
    put(im, 16, head_y0 + 7, GB_SKIN_D)
    put(im, 17, head_y0 + 8, GB_SKIN_M)

    # Глаза — красные, злобные
    put(im, 13, head_y0 + 5, GB_EYE)
    put(im, 14, head_y0 + 5, GB_EYE)
    put(im, 13, head_y0 + 6, GB_EYE)
    put(im, 19, head_y0 + 5, GB_EYE)
    put(im, 20, head_y0 + 5, GB_EYE)
    put(im, 20, head_y0 + 6, GB_EYE)
    # Блик в глазу
    put(im, 14, head_y0 + 5, GB_EYE_HI)
    put(im, 20, head_y0 + 5, GB_EYE_HI)

    # Кривая пасть с клыком
    put(im, 14, head_y0 + 9, GB_OUT)
    put(im, 15, head_y0 + 9, GB_OUT)
    put(im, 16, head_y0 + 9, GB_OUT)
    put(im, 17, head_y0 + 9, GB_OUT)
    put(im, 18, head_y0 + 9, GB_OUT)
    put(im, 18, head_y0 + 8, GB_OUT)
    put(im, 17, head_y0 + 10, GB_TOOTH)  # клык

    # ========== Тело ==========
    body_y0 = 15 + dy
    body_y1 = 22 + dy
    for y in range(body_y0, body_y1 + 1):
        t = (y - body_y0) / (body_y1 - body_y0)
        w = 4 if t < 0.5 else 5
        col = GB_SKIN_M if t < 0.4 else GB_SKIN_D
        for x in range(16 - w, 16 + w):
            put(im, x, y, col)
    # Блик на груди
    for x in range(13, 16):
        put(im, x, body_y0, GB_SKIN_H)

    # ========== Повязка на поясе ==========
    belt_y = body_y1
    for x in range(12, 21):
        put(im, x, belt_y, GB_CLOTH_D)
    for x in range(13, 20):
        put(im, x, belt_y - 1, GB_CLOTH_M)
    # вариант: узелок посередине
    put(im, 16, belt_y - 1, GB_CLOTH_H)

    # ========== Ноги ==========
    for x in range(13, 15):
        put(im, x, 23, GB_SKIN_M)
        put(im, x, 24, GB_SKIN_M)
        put(im, x, 25, GB_SKIN_D)
    for x in range(17, 19):
        put(im, x, 23, GB_SKIN_M)
        put(im, x, 24, GB_SKIN_M)
        put(im, x, 25, GB_SKIN_D)
    # ступни
    for x in range(12, 15):
        put(im, x, 26, GB_OUT)
    for x in range(17, 20):
        put(im, x, 26, GB_OUT)

    # ========== Руки ==========
    # Левая рука — вдоль тела
    for y in range(body_y0 + 1 + arm_y, body_y0 + 5 + arm_y):
        put(im, 11, y, GB_SKIN_M)
        put(im, 12, y, GB_SKIN_D)
    # Правая рука — поднята, сжимает кинжал (второй кадр — выше)
    rarm_y0 = body_y0 + 1 + arm_y
    rarm_y1 = body_y0 + 4 + arm_y
    for y in range(rarm_y0, rarm_y1):
        put(im, 21, y, GB_SKIN_M)
        put(im, 22, y, GB_SKIN_D)
    # кулак
    put(im, 22, rarm_y1, GB_SKIN_H)
    put(im, 23, rarm_y1, GB_SKIN_M)
    put(im, 22, rarm_y1 + 1, GB_SKIN_D)

    # Кинжал — рукоять (коричневая) + клинок (серо-металл, блик)
    # рукоять
    for dy2 in range(2):
        put(im, 23, rarm_y1 - 1 + dy2, GB_HAFT)
    # гарда
    put(im, 22, rarm_y1 - 2, GB_METAL_D)
    put(im, 24, rarm_y1 - 2, GB_METAL_D)
    # клинок — диагональ вверх-вправо
    blade = [(24, rarm_y1 - 3), (25, rarm_y1 - 4), (25, rarm_y1 - 5),
             (26, rarm_y1 - 6), (26, rarm_y1 - 7)]
    for (bx, by) in blade:
        put(im, bx, by, GB_METAL_M)
        put(im, bx + 1, by, GB_METAL_D)
    # остриё
    put(im, 27, rarm_y1 - 7, GB_METAL_H)
    # блик на клинке
    put(im, 25, rarm_y1 - 3, GB_METAL_H)

    # ========== Аутлайн силуэта ==========
    def is_opaque(x, y):
        if 0 <= x < 32 and 0 <= y < 32:
            return im.getpixel((x, y))[3] > 0
        return False

    outline_pts = []
    for y in range(32):
        for x in range(32):
            if not is_opaque(x, y):
                for dxo, dyo in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    if is_opaque(x + dxo, y + dyo):
                        outline_pts.append((x, y))
                        break
    for (x, y) in outline_pts:
        put(im, x, y, GB_OUT)

    # Тень под ногами
    for dx in range(-6, 7):
        alpha = int(95 * (1 - abs(dx) / 6))
        if alpha > 0:
            put(im, 16 + dx, 27, (0, 0, 0, alpha))
    for dx in range(-4, 5):
        alpha = int(60 * (1 - abs(dx) / 4))
        if alpha > 0:
            put(im, 16 + dx, 28, (0, 0, 0, alpha))

    return im


def write_sheet(path, f0, f1):
    sheet = Image.new("RGBA", (64, 32), TRANSP)
    sheet.paste(f0, (0, 0), f0)
    sheet.paste(f1, (32, 0), f1)
    sheet.save(path)
    print("wrote", path)


if __name__ == "__main__":
    import os
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                           "godot", "assets", "sprites")
    out_dir = os.path.normpath(out_dir)
    write_sheet(os.path.join(out_dir, "slime.png"), draw_slime(0), draw_slime(1))
    write_sheet(os.path.join(out_dir, "goblin.png"), draw_goblin(0), draw_goblin(1))
