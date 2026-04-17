"""Generate the GG world map (60x45).

Концепция:
- Огромные зелёные луга.
- Центр карты — большие каменные врата (крепость 12×10) с проходами
  на 4 стороны света; spawn и торговец внутри.
- Два ручья (речки) — с запада на восток и с севера на юг, в низинах.
- Широкие каменные тропинки веером от врат ко всем сторонам карты.
- Редкие кластеры деревьев по краям (не перегружают пейзаж).
- Летающие декорации (птицы/бабочки) — спавнит клиент отдельно, не часть
  тайлов.
"""
import json, math, random
from pathlib import Path

random.seed(42)

W, H = 60, 45
TILE = 32

GRASS = 0
SAND  = 1
WATER = 2
TREE  = 3
STONE = 4
PATH  = 5

tiles = [GRASS] * (W * H)

def set_tile(x, y, t):
    if 0 <= x < W and 0 <= y < H:
        tiles[y * W + x] = t

def get_tile(x, y):
    if 0 <= x < W and 0 <= y < H:
        return tiles[y * W + x]
    return -1

def dist(x1, y1, x2, y2):
    return math.hypot(x1-x2, y1-y2)

# --- Внешняя каменная рамка ---
for x in range(W):
    set_tile(x, 0, STONE)
    set_tile(x, H-1, STONE)
for y in range(H):
    set_tile(0, y, STONE)
    set_tile(W-1, y, STONE)

# --- Большие центральные врата-крепость ---
# Прямоугольное каменное укрепление 14×10 в самом центре карты.
# Проходы по центру каждой стены (2 тайла шириной).
cx, cy = W // 2, H // 2            # 30, 22
gate_w, gate_h = 14, 10            # ширина/высота крепости
gx0, gy0 = cx - gate_w // 2, cy - gate_h // 2
gx1, gy1 = gx0 + gate_w - 1, gy0 + gate_h - 1

for y in range(gy0, gy1 + 1):
    for x in range(gx0, gx1 + 1):
        on_border = (x in (gx0, gx1)) or (y in (gy0, gy1))
        if on_border:
            set_tile(x, y, STONE)
        else:
            set_tile(x, y, PATH)  # внутренний двор — каменная площадь

# Проходы во врата (двухклеточные ворота на каждой стене)
def carve_gate(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            set_tile(x, y, PATH)

carve_gate(cx - 1, gy0, cx,     gy0)      # северные врата
carve_gate(cx - 1, gy1, cx,     gy1)      # южные врата
carve_gate(gx0, cy - 1, gx0,    cy)       # западные врата
carve_gate(gx1, cy - 1, gx1,    cy)       # восточные врата

# Декоративные башенки по углам — +1 тайл STONE наружу
for cxr, cyr in [(gx0, gy0), (gx1, gy0), (gx0, gy1), (gx1, gy1)]:
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            nx, ny = cxr + dx, cyr + dy
            if 0 < nx < W - 1 and 0 < ny < H - 1:
                set_tile(nx, ny, STONE)

# --- Узкие тропинки от врат (классический RPG-стиль, 1 тайл) ---
def carve_path(x0, y0, x1, y1, width=1):
    # Прямая тропинка толщиной `width` между двумя точками.
    steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
    if steps == 0:
        return
    for i in range(steps + 1):
        t = i / steps
        px = int(round(x0 + (x1 - x0) * t))
        py = int(round(y0 + (y1 - y0) * t))
        for dx in range(-(width // 2), width // 2 + 1):
            for dy in range(-(width // 2), width // 2 + 1):
                nx, ny = px + dx, py + dy
                if 0 < nx < W - 1 and 0 < ny < H - 1:
                    if get_tile(nx, ny) in (GRASS, SAND):
                        set_tile(nx, ny, PATH)

# 4 главные тропинки к сторонам света + 4 диагональные к углам
carve_path(cx, gy0 - 1, cx,    2,      width=2)   # север
carve_path(cx, gy1 + 1, cx,    H - 2,  width=2)   # юг
carve_path(gx0 - 1, cy, 2,     cy,     width=2)   # запад
carve_path(gx1 + 1, cy, W - 3, cy,     width=2)   # восток
carve_path(cx - 3, gy0 - 1, 6,     6,         width=1)   # NW
carve_path(cx + 3, gy0 - 1, W - 6, 6,         width=1)   # NE
carve_path(cx - 3, gy1 + 1, 6,     H - 6,     width=1)   # SW
carve_path(cx + 3, gy1 + 1, W - 6, H - 6,     width=1)   # SE

# --- Ручьи ---
def carve_river(points, width=2):
    for i in range(len(points) - 1):
        x0, y0 = points[i]
        x1, y1 = points[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
        if steps == 0:
            continue
        for j in range(steps + 1):
            t = j / steps
            px = int(round(x0 + (x1 - x0) * t))
            py = int(round(y0 + (y1 - y0) * t))
            for dx in range(-(width // 2), width // 2 + 1):
                for dy in range(-(width // 2), width // 2 + 1):
                    nx, ny = px + dx, py + dy
                    if 0 < nx < W - 1 and 0 < ny < H - 1:
                        # Ручей не сносит крепость и её проходы
                        cur = get_tile(nx, ny)
                        if cur in (GRASS, SAND, TREE):
                            set_tile(nx, ny, WATER)

# Западно-восточный ручей (огибает крепость снизу)
carve_river([(2, 35), (15, 34), (25, 36), (35, 36), (45, 34), (W - 3, 33)], width=2)
# Северо-южный ручей в западной части карты (подальше от крепости)
carve_river([(10, 2), (8, 10), (10, 18), (8, 25), (10, 35)], width=2)

# Песок по берегам воды
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if get_tile(x, y) == GRASS:
            has_water = any(
                get_tile(x + dx, y + dy) == WATER
                for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy)
            )
            if has_water and random.random() < 0.55:
                set_tile(x, y, SAND)

# --- Мостики: только там, где тропинка реально пересекает воду ---
# Алгоритм: ищем WATER-тайл, у которого PATH есть и с одной стороны, и с
# противоположной (N–S или E–W). Только тогда ставим мостик.
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if get_tile(x, y) != WATER:
            continue
        horizontal_bridge = get_tile(x - 1, y) == PATH and get_tile(x + 1, y) == PATH
        vertical_bridge   = get_tile(x, y - 1) == PATH and get_tile(x, y + 1) == PATH
        if horizontal_bridge or vertical_bridge:
            set_tile(x, y, PATH)

# --- Кластеры деревьев по окраинам (не перегружаем пейзаж) ---
forest_centers = [
    (6,  6,  3),
    (8,  38, 4),
    (52, 6,  4),
    (54, 38, 3),
    (4,  22, 2),
    (55, 22, 2),
]
for fcx, fcy, fr in forest_centers:
    for y in range(max(1, fcy-fr-2), min(H-1, fcy+fr+2)):
        for x in range(max(1, fcx-fr-2), min(W-1, fcx+fr+2)):
            if dist(x, y, fcx, fcy) < fr + random.uniform(-1.0, 0.5):
                if get_tile(x, y) == GRASS:
                    set_tile(x, y, TREE)

# Редкие одиночные деревья по всему полю — оживляют луга
for _ in range(40):
    x, y = random.randint(2, W-3), random.randint(2, H-3)
    if get_tile(x, y) == GRASS:
        # Не ставим деревья впритык к тропинке — чтобы не зажимали обзор
        near_path = any(
            get_tile(x + dx, y + dy) == PATH
            for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy)
        )
        if not near_path:
            set_tile(x, y, TREE)

# --- Mobs / NPCs ---
mobs = []
mob_id = 1

def find_tiles(cond_fn, limit=None):
    out = []
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if cond_fn(x, y):
                out.append((x, y))
    random.shuffle(out)
    return out[:limit] if limit else out

# Слаймы около воды
water_edges = find_tiles(lambda x, y: get_tile(x, y) in (SAND, GRASS) and any(
    get_tile(x + dx, y + dy) == WATER
    for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy)
), limit=8)
for ex, ey in water_edges:
    mobs.append({"id": mob_id, "name": "", "type": "slime",
                 "x": ex*TILE, "y": ey*TILE, "width": TILE, "height": TILE,
                 "rotation": 0, "visible": True})
    mob_id += 1

# Гоблины у лесов
forest_edges = find_tiles(lambda x, y: get_tile(x, y) == GRASS and any(
    get_tile(x + dx, y + dy) == TREE
    for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy)
), limit=12)
for ex, ey in forest_edges:
    mobs.append({"id": mob_id, "name": "", "type": "goblin",
                 "x": ex*TILE, "y": ey*TILE, "width": TILE, "height": TILE,
                 "rotation": 0, "visible": True})
    mob_id += 1

# Тренировочные манекены внутри крепости (по углам двора)
yard_corners = [
    (gx0 + 2, gy0 + 2),
    (gx1 - 2, gy0 + 2),
    (gx0 + 2, gy1 - 2),
]
for dx, dy in yard_corners:
    if get_tile(dx, dy) == PATH:
        mobs.append({"id": mob_id, "name": "", "type": "dummy",
                     "x": dx*TILE, "y": dy*TILE, "width": TILE, "height": TILE,
                     "rotation": 0, "visible": True})
        mob_id += 1

# Spawn игрока — у южных врат внутри крепости
spawn_x, spawn_y = cx, gy1 - 2
npcs = [
    {"id": mob_id+1, "name": "player_spawn", "type": "spawn",
     "x": spawn_x*TILE, "y": spawn_y*TILE, "width": TILE, "height": TILE,
     "rotation": 0, "visible": True},
    {"id": mob_id+2, "name": "merchant", "type": "npc",
     "x": (cx + 2)*TILE, "y": (gy0 + 3)*TILE, "width": TILE, "height": TILE,
     "rotation": 0, "visible": True},
]

tmj = {
    "compressionlevel": -1,
    "height": H, "width": W,
    "infinite": False,
    "tileheight": TILE, "tilewidth": TILE,
    "type": "map", "version": "1.10", "tiledversion": "1.10.2",
    "orientation": "orthogonal", "renderorder": "right-down",
    "nextlayerid": 4, "nextobjectid": mob_id + 10,
    "tilesets": [{"firstgid": 1, "source": "tiles.tsj"}],
    "layers": [
        {
            "id": 1, "name": "Tiles", "type": "tilelayer",
            "x": 0, "y": 0, "width": W, "height": H,
            "opacity": 1, "visible": True,
            "data": [t + 1 for t in tiles]
        },
        {
            "id": 2, "name": "Mobs", "type": "objectgroup",
            "x": 0, "y": 0, "opacity": 1, "visible": True,
            "draworder": "topdown",
            "objects": mobs
        },
        {
            "id": 3, "name": "NPCs", "type": "objectgroup",
            "x": 0, "y": 0, "opacity": 1, "visible": True,
            "draworder": "topdown",
            "objects": npcs
        },
    ]
}

out = Path(__file__).parent / "world.tmj"
out.write_text(json.dumps(tmj, indent=2))
print(f"Generated {out} ({W}x{H}, {len(mobs)} mobs, {len(npcs)} NPCs)")

from collections import Counter
c = Counter(tiles)
names = {GRASS:"grass", SAND:"sand", WATER:"water", TREE:"tree", STONE:"stone", PATH:"path"}
for tid, cnt in sorted(c.items()):
    pct = cnt / (W*H) * 100
    print(f"  {names.get(tid, tid)}: {cnt} ({pct:.1f}%)")
