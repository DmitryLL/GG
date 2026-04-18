# Spawns one Sprite2D per tile. 60×45 = 2700 sprites — fine for 2D on
# any desktop/mobile GPU. When perf becomes an issue we swap for a
# TileMapLayer batched draw.
class_name World
extends Node2D

const TILES_TEX := preload("res://assets/sprites/tiles.png")
const TREE_TEX := preload("res://assets/sprites/tree.png")

var data: WorldData
var astar: AStarGrid2D

func _ready() -> void:
	data = WorldData.new()
	_build_astar()
	_render_tiles()

func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, data.map_cols, data.map_rows)
	astar.cell_size = Vector2(WorldData.TILE_SIZE, WorldData.TILE_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for r in data.map_rows:
		for c in data.map_cols:
			var id: int = data.tiles[r * data.map_cols + c]
			if WorldData.BLOCKED.has(id):
				astar.set_point_solid(Vector2i(c, r), true)

# Возвращает массив waypoint-ов (мировые координаты центров клеток).
# Пустой массив = пути нет или цель = старт.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if astar == null:
		return PackedVector2Array()
	var ts: float = float(WorldData.TILE_SIZE)
	var f := Vector2i(int(from.x / ts), int(from.y / ts))
	var t := Vector2i(int(to.x / ts), int(to.y / ts))
	# Если цель занята — найти ближайшую свободную клетку рядом
	if astar.is_in_boundsv(t) and astar.is_point_solid(t):
		t = _nearest_walkable(t)
	if not astar.is_in_boundsv(f) or not astar.is_in_boundsv(t):
		return PackedVector2Array()
	var path := astar.get_point_path(f, t)
	# Сдвигаем в центр клетки
	for i in range(path.size()):
		path[i] = Vector2(path[i].x + ts * 0.5, path[i].y + ts * 0.5)
	return path

func _nearest_walkable(p: Vector2i) -> Vector2i:
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var n := p + Vector2i(dx, dy)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					return n
	return p

func _render_tiles() -> void:
	for r in data.map_rows:
		for c in data.map_cols:
			var id: int = data.tiles[r * data.map_cols + c]
			_render_one_tile(c, r, id)

func is_walkable(pos: Vector2) -> bool:
	return data.is_walkable_at(pos.x, pos.y)

func player_spawn() -> Vector2:
	return data.player_spawn

# ══════════════════ In-game map editor ══════════════════
# Трекаем спрайты по клеткам (base + tree overlay), чтобы при правке
# одного тайла быстро найти и удалить его ноды.
var _tile_nodes: Dictionary = {}  # Vector2i(col, row) → Array[Node2D]

func _register_tile_node(col: int, row: int, node: Node2D) -> void:
	var key := Vector2i(col, row)
	if not _tile_nodes.has(key):
		_tile_nodes[key] = []
	_tile_nodes[key].append(node)

# Заменяет тайл в клетке (c, r) на new_id и обновляет A*.
func set_tile(c: int, r: int, new_id: int) -> void:
	if c < 0 or r < 0 or c >= data.map_cols or r >= data.map_rows:
		return
	data.tiles[r * data.map_cols + c] = new_id
	# Удалить старые спрайты в этой клетке.
	var key := Vector2i(c, r)
	if _tile_nodes.has(key):
		for n in _tile_nodes[key]:
			if is_instance_valid(n):
				n.queue_free()
		_tile_nodes.erase(key)
	# Отрендерить заново.
	_render_one_tile(c, r, new_id)
	# Обновить A* блокировку.
	if astar:
		astar.set_point_solid(Vector2i(c, r), WorldData.BLOCKED.has(new_id))

func _render_one_tile(c: int, r: int, id: int) -> void:
	var base_id := id
	if id == WorldData.Tile.TREE:
		base_id = WorldData.Tile.GRASS
	var sprite := Sprite2D.new()
	sprite.texture = TILES_TEX
	sprite.region_enabled = true
	sprite.region_rect = Rect2(base_id * WorldData.TILE_SIZE, 0, WorldData.TILE_SIZE, WorldData.TILE_SIZE)
	sprite.centered = false
	sprite.position = Vector2(c * WorldData.TILE_SIZE, r * WorldData.TILE_SIZE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_register_tile_node(c, r, sprite)
	if id == WorldData.Tile.TREE:
		var tree := Sprite2D.new()
		tree.texture = TREE_TEX
		tree.centered = false
		tree.position = Vector2(c * WorldData.TILE_SIZE - 16, r * WorldData.TILE_SIZE - 64)
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.z_index = r
		add_child(tree)
		_register_tile_node(c, r, tree)

# Применить полный массив тайлов (от OP_MAP_FULL при входе в мир).
func apply_full_tiles(new_tiles: Array) -> void:
	# Полная перерисовка — безопасный но дорогой путь. На карте 60×45
	# это 2700 клеток, занимает доли секунды, происходит один раз на логине.
	for key in _tile_nodes.keys():
		for n in _tile_nodes[key]:
			if is_instance_valid(n):
				n.queue_free()
	_tile_nodes.clear()
	for i in range(new_tiles.size()):
		data.tiles[i] = int(new_tiles[i])
	# A* блокировки
	if astar:
		for r in data.map_rows:
			for c in data.map_cols:
				var id: int = data.tiles[r * data.map_cols + c]
				astar.set_point_solid(Vector2i(c, r), WorldData.BLOCKED.has(id))
	_render_tiles()

# Экспорт текущего состояния в TMJ JSON (совместимо с Tiled).
# Только слой Tiles; моб/NPC слои клиент не правит.
func export_tiles_json() -> String:
	var gids: Array = []
	for t in data.tiles:
		gids.append(int(t) + 1)
	var tmj := {
		"width": data.map_cols,
		"height": data.map_rows,
		"tiles": gids,
	}
	return JSON.stringify(tmj)

# ═══════════════════ Grid overlay ═══════════════════
var _grid_overlay: Node2D = null

func set_grid_visible(on: bool) -> void:
	if on:
		if _grid_overlay == null:
			_grid_overlay = _GridOverlay.new(data.map_cols, data.map_rows, WorldData.TILE_SIZE)
			_grid_overlay.z_index = 150
			add_child(_grid_overlay)
	else:
		if _grid_overlay:
			_grid_overlay.queue_free()
			_grid_overlay = null

class _GridOverlay extends Node2D:
	var cols: int
	var rows: int
	var ts: int
	func _init(c: int, r: int, t: int) -> void:
		cols = c; rows = r; ts = t
	func _draw() -> void:
		var color := Color(1, 1, 1, 0.25)
		for x in range(cols + 1):
			draw_line(Vector2(x * ts, 0), Vector2(x * ts, rows * ts), color, 1.0)
		for y in range(rows + 1):
			draw_line(Vector2(0, y * ts), Vector2(cols * ts, y * ts), color, 1.0)
