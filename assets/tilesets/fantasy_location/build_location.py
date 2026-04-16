"""Compose a fantasy location demo image from two Wang tilesets."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
TS_GRASS_PATH = json.loads((ROOT / "grass_path.json").read_text())
TS_WATER_GRASS = json.loads((ROOT / "water_grass.json").read_text())
IMG_GRASS_PATH = Image.open(ROOT / "grass_path.png").convert("RGBA")
IMG_WATER_GRASS = Image.open(ROOT / "water_grass.png").convert("RGBA")

TILE = 32
W, H = 24, 16  # cells


def lookup(tileset_data, corners):
    # corners: dict NW/NE/SW/SE -> "lower"/"upper"
    for t in tileset_data["tileset_data"]["tiles"]:
        if t["corners"] == corners:
            return t["bounding_box"]
    raise KeyError(corners)


def tile_from(img, bb):
    return img.crop((bb["x"], bb["y"], bb["x"] + bb["width"], bb["y"] + bb["height"]))


# Vertex grids (W+1) x (H+1).
# Water: 0=water, 1=grass. Pond in top-left curved shape.
def in_pond(vx, vy):
    # ellipse centered at (5, 4) radius (5, 3.5)
    dx = (vx - 5) / 5.0
    dy = (vy - 4) / 3.5
    return dx * dx + dy * dy < 1.0


# Path: 0=grass, 1=stone. Curving from top-right to bottom-right through middle.
def on_path(vx, vy):
    # two connected strokes forming an S-curve
    import math
    # main curve: x = 16 + 4*sin(y*0.45)
    cx = 16 + 4 * math.sin(vy * 0.45)
    if abs(vx - cx) < 2.2:
        return True
    # horizontal branch near middle going left to a clearing
    if 7 <= vy <= 9 and 9 <= vx <= 16:
        return True
    # small clearing (roundish) around (9, 8)
    dx, dy = vx - 9, vy - 8
    if dx * dx + dy * dy < 6:
        return True
    return False


# No overlap between pond and path: pond is top-left, path is right+middle.
water_grid = [[0 if in_pond(x, y) else 1 for y in range(H + 1)] for x in range(W + 1)]
path_grid = [[1 if on_path(x, y) else 0 for y in range(H + 1)] for x in range(W + 1)]

out = Image.new("RGBA", (W * TILE, H * TILE))

NAMES = ("NW", "NE", "SW", "SE")


def corners_of(grid, x, y):
    # cell (x,y) -> vertex corners
    v = [grid[x][y], grid[x + 1][y], grid[x][y + 1], grid[x + 1][y + 1]]
    labels = ["lower" if s == 0 else "upper" for s in v]
    return dict(zip(NAMES, labels))


# Pass 1: water/grass base
for cx in range(W):
    for cy in range(H):
        c = corners_of(water_grid, cx, cy)
        bb = lookup(TS_WATER_GRASS, c)
        out.paste(tile_from(IMG_WATER_GRASS, bb), (cx * TILE, cy * TILE))

# Pass 2: stone path over grass (skip if no path touches this cell; else overlay)
for cx in range(W):
    for cy in range(H):
        c = corners_of(path_grid, cx, cy)
        if all(v == "lower" for v in c.values()):
            continue  # pure grass — keep pass-1 result
        # Skip path tiles that would land on water (any water corner)
        wc = corners_of(water_grid, cx, cy)
        if any(v == "lower" for v in wc.values()):
            continue
        bb = lookup(TS_GRASS_PATH, c)
        out.paste(tile_from(IMG_GRASS_PATH, bb), (cx * TILE, cy * TILE))

out.save(ROOT / "location.png")
# Also a 2x scale for nicer preview
out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(ROOT / "location_2x.png")
print(f"Wrote {out.size} -> location.png")
