# Sprite generator

Pixel anime character spritesheets used by the client.
Output: 32×32 frames, 3 cols (walk animation) × 4 rows (directions: down/left/right/up).

## Regenerate

```bash
python3 generate.py
```

Writes PNGs into `../public/sprites/char_{i}.png` (6 color variants).
Spritesheets are committed to git — only regenerate when editing `generate.py`.
