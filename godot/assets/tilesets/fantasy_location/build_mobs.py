"""Build 64x32 mob atlases (2 frames of 32x32) from PixelLab rotations.

Frame 0 = south view, Frame 1 = east view (for subtle variation).
Output: godot/assets/sprites/{slime,goblin}.png
"""
import io
import subprocess
from pathlib import Path
from PIL import Image

OUT_DIR = Path(__file__).resolve().parent.parent.parent / "sprites"
TILE = 32

MOBS = {
    "goblin": "9be3b92d-5646-474c-80d3-b3e31fd5c739",
    "slime": "a7ef43d5-68c1-4315-aafc-9c44c359d4b8",
}


def fetch(url):
    data = subprocess.check_output(["curl", "-sSL", "--fail", "-A", "Mozilla/5.0", url])
    return Image.open(io.BytesIO(data)).convert("RGBA")


def fit_32(img):
    """Trim transparent borders, scale longest side to 32, center on 32x32 canvas."""
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    s = TILE / max(w, h)
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    img = img.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    canvas.paste(img, ((TILE - nw) // 2, TILE - nh), img)  # bottom-aligned
    return canvas


for name, cid in MOBS.items():
    base = f"https://backblaze.pixellab.ai/file/pixellab-characters/5a6e8e29-5e69-4715-8c8d-67679f236361/{cid}/rotations"
    south = fit_32(fetch(f"{base}/south.png"))
    east = fit_32(fetch(f"{base}/east.png"))
    atlas = Image.new("RGBA", (TILE * 2, TILE), (0, 0, 0, 0))
    atlas.paste(south, (0, 0))
    atlas.paste(east, (TILE, 0))
    path = OUT_DIR / f"{name}.png"
    atlas.save(path)
    print(f"{name}: {path}")
