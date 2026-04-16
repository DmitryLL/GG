"""Generate a beautiful fantasy world.tmj map (60x45).

Landscape:
- Large grassy meadows with scattered tree clusters (forest feel)
- Winding stone path from spawn clearing through forest to pond
- Small enchanted pond (not too much water!)
- Stone ruins/boulders dotted around
- Sand patches near water
"""
import json, math, random
from pathlib import Path

random.seed(42)

W, H = 60, 45
TILE = 32

# Tile IDs matching WorldData.Tile enum
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
    return math.sqrt((x1-x2)**2 + (y1-y2)**2)

def ellipse(cx, cy, rx, ry, tile):
    for y in range(H):
        for x in range(W):
            if ((x-cx)/rx)**2 + ((y-cy)/ry)**2 < 1.0:
                set_tile(x, y, tile)

def circle(cx, cy, r, tile):
    ellipse(cx, cy, r, r, tile)

def noisy_circle(cx, cy, r, tile, noise=1.5):
    for y in range(H):
        for x in range(W):
            d = dist(x, y, cx, cy)
            threshold = r + random.uniform(-noise, noise)
            if d < threshold:
                set_tile(x, y, tile)

# --- Border: stone walls ---
for x in range(W):
    set_tile(x, 0, STONE)
    set_tile(x, H-1, STONE)
for y in range(H):
    set_tile(0, y, STONE)
    set_tile(W-1, y, STONE)

# --- Enchanted pond (small, top-left area) ---
pond_cx, pond_cy = 12, 10
noisy_circle(pond_cx, pond_cy, 4, WATER, 1.2)
# Sand shore around pond
for y in range(H):
    for x in range(W):
        if get_tile(x, y) == GRASS and any(
            get_tile(x+dx, y+dy) == WATER
            for dx in (-1,0,1) for dy in (-1,0,1) if (dx or dy)
        ):
            if random.random() < 0.7:
                set_tile(x, y, SAND)

# --- Second tiny pond (bottom-right) ---
pond2_cx, pond2_cy = 48, 35
noisy_circle(pond2_cx, pond2_cy, 2.5, WATER, 0.8)
for y in range(H):
    for x in range(W):
        if get_tile(x, y) == GRASS and any(
            get_tile(x+dx, y+dy) == WATER
            for dx in (-1,0,1) for dy in (-1,0,1) if (dx or dy)
        ):
            if random.random() < 0.6:
                set_tile(x, y, SAND)

# --- Winding stone path ---
# Main path: S-curve from spawn (30,22) going left to pond area, then south, then east
path_points = []
# Segment 1: spawn clearing east-west
for x in range(18, 45):
    yy = 22 + int(2.5 * math.sin(x * 0.2))
    path_points.append((x, yy))
# Segment 2: north from path to near top-left pond
for y in range(8, 23):
    xx = 18 + int(2 * math.sin(y * 0.3))
    path_points.append((xx, y))
# Segment 3: south branch from spawn down
for y in range(22, 38):
    xx = 30 + int(3 * math.sin(y * 0.25))
    path_points.append((xx, y))
# Segment 4: east branch to bottom-right pond
for x in range(30, 50):
    yy = 37 + int(1.5 * math.sin(x * 0.3))
    path_points.append((x, yy))

for px, py in path_points:
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            nx, ny = px+dx, py+dy
            if get_tile(nx, ny) == GRASS:
                set_tile(nx, ny, PATH)

# --- Tree clusters (forests) ---
forest_centers = [
    (6, 28, 6),   # southwest forest
    (8, 4, 5),    # northwest forest
    (50, 8, 7),   # northeast forest
    (52, 25, 5),  # east forest
    (25, 40, 5),  # south forest
    (40, 18, 4),  # central-east grove
    (3, 18, 3),   # west grove
    (55, 40, 4),  # southeast grove
]

for fcx, fcy, fr in forest_centers:
    for y in range(max(1, fcy-fr-2), min(H-1, fcy+fr+2)):
        for x in range(max(1, fcx-fr-2), min(W-1, fcx+fr+2)):
            d = dist(x, y, fcx, fcy)
            if d < fr + random.uniform(-1.5, 0.5):
                if get_tile(x, y) == GRASS:
                    set_tile(x, y, TREE)

# Scatter individual trees for natural feel
for _ in range(80):
    x, y = random.randint(2, W-3), random.randint(2, H-3)
    if get_tile(x, y) == GRASS:
        set_tile(x, y, TREE)

# --- Stone ruins/boulders ---
ruins = [(35, 12), (22, 30), (45, 42), (10, 38), (53, 15)]
for rx, ry in ruins:
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            if random.random() < 0.6:
                nx, ny = rx+dx, ry+dy
                if get_tile(nx, ny) in (GRASS, PATH):
                    set_tile(nx, ny, STONE)

# --- Clearings (make sure spawn area is clean) ---
# Clear spawn zone
spawn_cx, spawn_cy = 30, 22
for y in range(spawn_cy-3, spawn_cy+4):
    for x in range(spawn_cx-4, spawn_cx+5):
        if get_tile(x, y) in (TREE, STONE, WATER):
            set_tile(x, y, GRASS)
# Re-place path through spawn
for dx in range(-1, 2):
    for x in range(spawn_cx-3, spawn_cx+4):
        set_tile(x, spawn_cy+dx, PATH)

# --- Build TMJ ---
mobs = []
mob_id = 1

# Slimes near water (on walkable tiles adjacent to water)
def find_water_edge(wcx, wcy, radius=8):
    candidates = []
    for y in range(max(1, wcy-radius), min(H-1, wcy+radius)):
        for x in range(max(1, wcx-radius), min(W-1, wcx+radius)):
            if get_tile(x, y) in (GRASS, SAND, PATH):
                has_water_neighbor = any(
                    get_tile(x+dx, y+dy) == WATER
                    for dx in (-1,0,1) for dy in (-1,0,1) if (dx or dy)
                )
                if has_water_neighbor:
                    candidates.append((x, y, dist(x, y, wcx, wcy)))
    candidates.sort(key=lambda c: c[2])
    return candidates

slime_targets = [
    (pond_cx, pond_cy, 4),
    (pond2_cx, pond2_cy, 4),
]
for wcx, wcy, count in slime_targets:
    edges = find_water_edge(wcx, wcy)
    placed = 0
    used = set()
    for ex, ey, _ in edges:
        if placed >= count:
            break
        if (ex, ey) in used:
            continue
        too_close = any(abs(ex-ux) + abs(ey-uy) < 3 for ux, uy in used)
        if too_close:
            continue
        used.add((ex, ey))
        mobs.append({"id": mob_id, "name": "", "type": "slime",
                     "x": ex*TILE, "y": ey*TILE, "width": TILE, "height": TILE,
                     "rotation": 0, "visible": True})
        mob_id += 1
        placed += 1

# Goblins near forest edges (on walkable tiles adjacent to trees)
def find_forest_edge(fcx, fcy, radius=10):
    """Find walkable tiles next to trees near a forest center."""
    candidates = []
    for y in range(max(1, fcy-radius), min(H-1, fcy+radius)):
        for x in range(max(1, fcx-radius), min(W-1, fcx+radius)):
            if get_tile(x, y) in (GRASS, PATH):
                has_tree_neighbor = any(
                    get_tile(x+dx, y+dy) == TREE
                    for dx in (-1,0,1) for dy in (-1,0,1) if (dx or dy)
                )
                if has_tree_neighbor:
                    candidates.append((x, y, dist(x, y, fcx, fcy)))
    candidates.sort(key=lambda c: c[2])
    return candidates

# Training dummies near spawn
dummy_positions = [
    (spawn_cx - 6, spawn_cy - 2),
    (spawn_cx - 6, spawn_cy),
    (spawn_cx - 6, spawn_cy + 2),
]
for dx, dy in dummy_positions:
    if get_tile(dx, dy) in (GRASS, PATH):
        mobs.append({"id": mob_id, "name": "", "type": "dummy",
                     "x": dx*TILE, "y": dy*TILE, "width": TILE, "height": TILE,
                     "rotation": 0, "visible": True})
        mob_id += 1

goblin_forest_targets = [
    (6, 28, 2),   # southwest forest, 2 goblins
    (50, 8, 3),   # northeast forest, 3 goblins
    (52, 25, 2),  # east forest
    (40, 18, 2),  # central grove
    (25, 40, 2),  # south forest
    (55, 40, 1),  # southeast
]
for fcx, fcy, count in goblin_forest_targets:
    edges = find_forest_edge(fcx, fcy)
    placed = 0
    used = set()
    for ex, ey, _ in edges:
        if placed >= count:
            break
        if (ex, ey) in used:
            continue
        too_close = any(abs(ex-ux) + abs(ey-uy) < 3 for ux, uy in used)
        if too_close:
            continue
        used.add((ex, ey))
        mobs.append({"id": mob_id, "name": "", "type": "goblin",
                     "x": ex*TILE, "y": ey*TILE, "width": TILE, "height": TILE,
                     "rotation": 0, "visible": True})
        mob_id += 1
        placed += 1

# NPCs
npcs = [
    {"id": mob_id+1, "name": "player_spawn", "type": "spawn",
     "x": spawn_cx*TILE, "y": spawn_cy*TILE, "width": TILE, "height": TILE,
     "rotation": 0, "visible": True},
    {"id": mob_id+2, "name": "merchant", "type": "npc",
     "x": (spawn_cx+2)*TILE, "y": (spawn_cy-1)*TILE, "width": TILE, "height": TILE,
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
            "data": [t + 1 for t in tiles]  # 1-based gid
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

# Stats
from collections import Counter
c = Counter(tiles)
names = {GRASS:"grass", SAND:"sand", WATER:"water", TREE:"tree", STONE:"stone", PATH:"path"}
for tid, cnt in sorted(c.items()):
    pct = cnt / (W*H) * 100
    print(f"  {names.get(tid, tid)}: {cnt} ({pct:.1f}%)")
