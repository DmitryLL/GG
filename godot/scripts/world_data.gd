# World generation — port of shared/src/index.ts to GDScript.
# Uses the same mulberry32 seed (1337) so the Godot client and the Phaser
# client produce identical maps while they coexist.
class_name WorldData
extends RefCounted

const TILE_SIZE := 32
const MAP_COLS := 60
const MAP_ROWS := 45
const MAP_WIDTH := TILE_SIZE * MAP_COLS     # 1920
const MAP_HEIGHT := TILE_SIZE * MAP_ROWS    # 1440

const WORLD_SEED := 1337

enum Tile { GRASS, SAND, WATER, TREE, STONE, PATH }
const BLOCKED := [Tile.WATER, Tile.TREE, Tile.STONE]

var tiles: PackedInt32Array
var mob_spawns: Array  # [{x, y, type}]
var player_spawn: Vector2

# mulberry32 PRNG — 32-bit unsigned math in GDScript requires masking.
var _rng_state: int

func _init(seed: int = WORLD_SEED) -> void:
	_rng_state = seed
	tiles = PackedInt32Array()
	tiles.resize(MAP_COLS * MAP_ROWS)
	_generate()

func _rand() -> float:
	_rng_state = (_rng_state + 0x6d2b79f5) & 0xFFFFFFFF
	var t: int = _rng_state
	# Math.imul(t ^ t>>15, t|1)
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ (t + _imul(t ^ (t >> 7), t | 61))) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

# Math.imul equivalent — signed 32-bit multiplication
func _imul(a: int, b: int) -> int:
	a = a & 0xFFFFFFFF
	b = b & 0xFFFFFFFF
	var ah := (a >> 16) & 0xFFFF
	var al := a & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	return ((al * bl) + (((ah * bl + al * bh) << 16) & 0xFFFFFFFF)) & 0xFFFFFFFF

func _set(c: int, r: int, id: int) -> void:
	if c >= 0 and c < MAP_COLS and r >= 0 and r < MAP_ROWS:
		tiles[r * MAP_COLS + c] = id

func _get(c: int, r: int) -> int:
	if c < 0 or c >= MAP_COLS or r < 0 or r >= MAP_ROWS:
		return Tile.TREE
	return tiles[r * MAP_COLS + c]

func tile_at(col: int, row: int) -> int:
	return _get(col, row)

func is_walkable_at(x: float, y: float) -> bool:
	var col := int(floor(x / TILE_SIZE))
	var row := int(floor(y / TILE_SIZE))
	return not BLOCKED.has(_get(col, row))

func _generate() -> void:
	for i in tiles.size():
		tiles[i] = Tile.GRASS

	# Border forest
	for c in MAP_COLS:
		_set(c, 0, Tile.TREE)
		_set(c, MAP_ROWS - 1, Tile.TREE)
	for r in MAP_ROWS:
		_set(0, r, Tile.TREE)
		_set(MAP_COLS - 1, r, Tile.TREE)

	# Water ponds
	for i in 5:
		var cx := 6 + int(_rand() * (MAP_COLS - 12))
		var cy := 6 + int(_rand() * (MAP_ROWS - 12))
		var radius := 2 + int(_rand() * 3)
		for dr in range(-radius - 1, radius + 2):
			for dc in range(-radius - 1, radius + 2):
				var d := sqrt(dc * dc + dr * dr)
				if d <= radius:
					_set(cx + dc, cy + dr, Tile.WATER)
				elif d <= radius + 1 and _get(cx + dc, cy + dr) == Tile.GRASS:
					_set(cx + dc, cy + dr, Tile.SAND)

	# Stone ruins
	for i in 4:
		var cx := 4 + int(_rand() * (MAP_COLS - 10))
		var cy := 4 + int(_rand() * (MAP_ROWS - 10))
		var w := 3 + int(_rand() * 3)
		var h := 3 + int(_rand() * 3)
		for dy in h:
			for dx in w:
				var edge := dy == 0 or dy == h - 1 or dx == 0 or dx == w - 1
				var gap_bottom := dy == h - 1 and dx == int(floor(w / 2.0))
				if edge and not gap_bottom and _get(cx + dx, cy + dy) != Tile.WATER:
					_set(cx + dx, cy + dy, Tile.STONE)

	# Scattered trees
	for i in 180:
		var c := 2 + int(_rand() * (MAP_COLS - 4))
		var r := 2 + int(_rand() * (MAP_ROWS - 4))
		if _get(c, r) == Tile.GRASS:
			_set(c, r, Tile.TREE)

	# Meandering paths
	for i in 3:
		var c := 2 + int(_rand() * (MAP_COLS - 4))
		var r := 2 + int(_rand() * (MAP_ROWS - 4))
		var length := 30 + int(_rand() * 40)
		for s in length:
			var cur := _get(c, r)
			if cur == Tile.GRASS or cur == Tile.TREE:
				_set(c, r, Tile.PATH)
			var dir := int(_rand() * 4)
			if dir == 0: c += 1
			elif dir == 1: c -= 1
			elif dir == 2: r += 1
			else: r -= 1
			c = clampi(c, 1, MAP_COLS - 2)
			r = clampi(r, 1, MAP_ROWS - 2)

	# Player spawn — clear plaza at center
	player_spawn = Vector2(MAP_WIDTH / 2.0, MAP_HEIGHT / 2.0)
	var scx := int(floor(player_spawn.x / TILE_SIZE))
	var scy := int(floor(player_spawn.y / TILE_SIZE))
	for dr in range(-2, 3):
		for dc in range(-2, 3):
			_set(scx + dc, scy + dr, Tile.GRASS)

	# Mob spawns (for future phase)
	mob_spawns = []
	var attempts := 0
	while mob_spawns.size() < 20 and attempts < 800:
		attempts += 1
		var c := 2 + int(_rand() * (MAP_COLS - 4))
		var r := 2 + int(_rand() * (MAP_ROWS - 4))
		var cur := _get(c, r)
		if cur != Tile.GRASS and cur != Tile.PATH:
			continue
		var px := c * TILE_SIZE + TILE_SIZE / 2.0
		var py := r * TILE_SIZE + TILE_SIZE / 2.0
		var dist_to_spawn := Vector2(px, py).distance_to(player_spawn)
		if dist_to_spawn < 160.0:
			continue
		var too_close := false
		for s in mob_spawns:
			if Vector2(s.x, s.y).distance_to(Vector2(px, py)) < 140.0:
				too_close = true
				break
		if too_close:
			continue
		var mob_type := "goblin" if dist_to_spawn > 500.0 else "slime"
		mob_spawns.append({"x": px, "y": py, "type": mob_type})
