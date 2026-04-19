"""Rebuild godot/assets/sprites/world/tiles.png with fantasy pixel-art tiles.

Layout (preserved from old atlas):
  col 0 GRASS, 1 SAND, 2 WATER, 3 TREE, 4 STONE, 5 PATH — each 32x32.

GRASS / WATER come from the water_grass Wang tileset (base tiles).
STONE / PATH come from the grass_path Wang tileset (all-upper base).
SAND / TREE are kept from the original atlas.
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
GODOT_ASSETS = ROOT.parent.parent  # godot/assets
OLD_ATLAS = GODOT_ASSETS / "sprites" / "world" / "tiles.png"
OUT = GODOT_ASSETS / "sprites" / "world" / "tiles.png"

TS_GRASS_PATH = json.loads((ROOT / "grass_path.json").read_text())
TS_WATER_GRASS = json.loads((ROOT / "water_grass.json").read_text())
IMG_GRASS_PATH = Image.open(ROOT / "grass_path.png").convert("RGBA")
IMG_WATER_GRASS = Image.open(ROOT / "water_grass.png").convert("RGBA")

TILE = 32


def base_tile(ts_data, img, which):
    bid = ts_data["base_tile_ids"][which]
    for t in ts_data["tileset_data"]["tiles"]:
        if t["id"] == bid:
            bb = t["bounding_box"]
            return img.crop((bb["x"], bb["y"], bb["x"] + bb["width"], bb["y"] + bb["height"]))
    raise KeyError(bid)


old = Image.open(OLD_ATLAS).convert("RGBA")
sand = old.crop((1 * TILE, 0, 2 * TILE, TILE))
tree = old.crop((3 * TILE, 0, 4 * TILE, TILE))

grass = base_tile(TS_WATER_GRASS, IMG_WATER_GRASS, "upper")   # grass
water = base_tile(TS_WATER_GRASS, IMG_WATER_GRASS, "lower")   # water
stone = base_tile(TS_GRASS_PATH, IMG_GRASS_PATH, "upper")     # cobble
path_ = base_tile(TS_GRASS_PATH, IMG_GRASS_PATH, "upper")     # cobble (same look, walkable)

atlas = Image.new("RGBA", (6 * TILE, TILE))
for i, tile in enumerate([grass, sand, water, tree, stone, path_]):
    atlas.paste(tile, (i * TILE, 0))
atlas.save(OUT)
print(f"Wrote {atlas.size} -> {OUT}")
