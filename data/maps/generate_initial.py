#!/usr/bin/env python3
"""
Однократный скрипт: генерит world.tmj из той же процедурной логики,
что была в Godot/сервере (seed 1337). Запускать руками если хочешь
сбросить карту до стартовой; обычная редакция — в Tiled.
"""
import json
import math
import os
import random

TILE_SIZE = 32
MAP_COLS = 60
MAP_ROWS = 45
SEED = 1337

GRASS, SAND, WATER, TREE, STONE, PATH = 0, 1, 2, 3, 4, 5
BLOCKED = {WATER, TREE, STONE}


def mulberry32(seed):
    state = [seed & 0xFFFFFFFF]
    def rnd():
        state[0] = (state[0] + 0x6d2b79f5) & 0xFFFFFFFF
        t = state[0]
        t = (((t ^ (t >> 15)) & 0xFFFFFFFF) * (t | 1)) & 0xFFFFFFFF
        t = (t ^ (t + (((t ^ (t >> 7)) & 0xFFFFFFFF) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
        return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
    return rnd


def gen():
    rnd = mulberry32(SEED)
    tiles = [GRASS] * (MAP_COLS * MAP_ROWS)
    def st(c, r, v):
        if 0 <= c < MAP_COLS and 0 <= r < MAP_ROWS:
            tiles[r * MAP_COLS + c] = v
    def gt(c, r):
        if c < 0 or c >= MAP_COLS or r < 0 or r >= MAP_ROWS:
            return TREE
        return tiles[r * MAP_COLS + c]

    for c in range(MAP_COLS):
        st(c, 0, TREE); st(c, MAP_ROWS - 1, TREE)
    for r in range(MAP_ROWS):
        st(0, r, TREE); st(MAP_COLS - 1, r, TREE)

    for _ in range(5):
        cx = 6 + int(rnd() * (MAP_COLS - 12))
        cy = 6 + int(rnd() * (MAP_ROWS - 12))
        radius = 2 + int(rnd() * 3)
        for dr in range(-radius - 1, radius + 2):
            for dc in range(-radius - 1, radius + 2):
                d = math.sqrt(dc * dc + dr * dr)
                if d <= radius:
                    st(cx + dc, cy + dr, WATER)
                elif d <= radius + 1 and gt(cx + dc, cy + dr) == GRASS:
                    st(cx + dc, cy + dr, SAND)

    for _ in range(4):
        cx = 4 + int(rnd() * (MAP_COLS - 10))
        cy = 4 + int(rnd() * (MAP_ROWS - 10))
        w = 3 + int(rnd() * 3)
        h = 3 + int(rnd() * 3)
        for dy in range(h):
            for dx in range(w):
                edge = dy == 0 or dy == h - 1 or dx == 0 or dx == w - 1
                gap = dy == h - 1 and dx == w // 2
                if edge and not gap and gt(cx + dx, cy + dy) != WATER:
                    st(cx + dx, cy + dy, STONE)

    for _ in range(180):
        c = 2 + int(rnd() * (MAP_COLS - 4))
        r = 2 + int(rnd() * (MAP_ROWS - 4))
        if gt(c, r) == GRASS:
            st(c, r, TREE)

    for _ in range(3):
        c = 2 + int(rnd() * (MAP_COLS - 4))
        r = 2 + int(rnd() * (MAP_ROWS - 4))
        length = 30 + int(rnd() * 40)
        for _ in range(length):
            cur = gt(c, r)
            if cur in (GRASS, TREE):
                st(c, r, PATH)
            d = int(rnd() * 4)
            if d == 0: c += 1
            elif d == 1: c -= 1
            elif d == 2: r += 1
            else: r -= 1
            c = max(1, min(MAP_COLS - 2, c))
            r = max(1, min(MAP_ROWS - 2, r))

    spawn_x, spawn_y = MAP_COLS * TILE_SIZE / 2, MAP_ROWS * TILE_SIZE / 2
    scx = int(spawn_x // TILE_SIZE)
    scy = int(spawn_y // TILE_SIZE)
    for dr in range(-2, 3):
        for dc in range(-2, 3):
            st(scx + dc, scy + dr, GRASS)

    mob_spawns = []
    attempts = 0
    while len(mob_spawns) < 20 and attempts < 800:
        attempts += 1
        c = 2 + int(rnd() * (MAP_COLS - 4))
        r = 2 + int(rnd() * (MAP_ROWS - 4))
        cur = gt(c, r)
        if cur not in (GRASS, PATH):
            continue
        px = c * TILE_SIZE + TILE_SIZE / 2
        py = r * TILE_SIZE + TILE_SIZE / 2
        d_to_spawn = math.hypot(px - spawn_x, py - spawn_y)
        if d_to_spawn < 160:
            continue
        if any(math.hypot(s["x"] - px, s["y"] - py) < 140 for s in mob_spawns):
            continue
        mob_type = "goblin" if d_to_spawn > 500 else "slime"
        mob_spawns.append({"x": px, "y": py, "type": mob_type})

    return tiles, mob_spawns, (spawn_x, spawn_y)


def main():
    tiles, spawns, (spawn_x, spawn_y) = gen()

    # Tiled tile data — 1-based gid (0 = empty), наш firstgid = 1.
    data = [t + 1 for t in tiles]

    next_id = 1
    spawn_objects = []
    for s in spawns:
        spawn_objects.append({
            "height": TILE_SIZE, "width": TILE_SIZE,
            "id": next_id, "name": "",
            "rotation": 0, "type": s["type"],
            "visible": True, "x": s["x"] - TILE_SIZE / 2, "y": s["y"] - TILE_SIZE / 2,
        })
        next_id += 1

    # NPC берём из data/npcs.json — перенесём как объекты Tiled чтобы их
    # было видно при редактировании.
    npc_objects = []
    npc_path = os.path.join(os.path.dirname(__file__), "..", "npcs.json")
    if os.path.exists(npc_path):
        with open(npc_path) as f:
            for npc in json.load(f):
                npc_objects.append({
                    "height": TILE_SIZE, "width": TILE_SIZE,
                    "id": next_id, "name": npc["id"],
                    "rotation": 0, "type": "npc",
                    "visible": True,
                    "x": float(npc["x"]) - TILE_SIZE / 2,
                    "y": float(npc["y"]) - TILE_SIZE / 2,
                    "properties": [
                        {"name": "stock", "type": "string", "value": ",".join(npc["stock"])},
                        {"name": "name",  "type": "string", "value": npc["name"]},
                    ],
                })
                next_id += 1

    spawn_obj = {
        "height": TILE_SIZE, "width": TILE_SIZE,
        "id": next_id, "name": "player_spawn",
        "rotation": 0, "type": "spawn",
        "visible": True, "x": spawn_x - TILE_SIZE / 2, "y": spawn_y - TILE_SIZE / 2,
    }
    next_id += 1

    out = {
        "compressionlevel": -1,
        "height": MAP_ROWS, "width": MAP_COLS,
        "infinite": False,
        "tileheight": TILE_SIZE, "tilewidth": TILE_SIZE,
        "type": "map", "version": "1.10",
        "tiledversion": "1.10.2",
        "orientation": "orthogonal", "renderorder": "right-down",
        "nextlayerid": 4, "nextobjectid": next_id,
        "tilesets": [{"firstgid": 1, "source": "tiles.tsj"}],
        "layers": [
            {"id": 1, "name": "Tiles", "type": "tilelayer",
             "x": 0, "y": 0, "width": MAP_COLS, "height": MAP_ROWS,
             "opacity": 1, "visible": True, "data": data},
            {"id": 2, "name": "Mobs", "type": "objectgroup",
             "draworder": "topdown", "opacity": 1, "visible": True,
             "x": 0, "y": 0, "objects": spawn_objects},
            {"id": 3, "name": "NPCs", "type": "objectgroup",
             "draworder": "topdown", "opacity": 1, "visible": True,
             "x": 0, "y": 0, "objects": npc_objects + [spawn_obj]},
        ],
    }

    out_path = os.path.join(os.path.dirname(__file__), "world.tmj")
    with open(out_path, "w") as f:
        json.dump(out, f, indent=2)
    print(f"wrote {out_path} — {MAP_COLS}×{MAP_ROWS} тайлов, {len(spawns)} мобов, {len(npc_objects)} NPC")


if __name__ == "__main__":
    main()
