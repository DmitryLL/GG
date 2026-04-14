# Загружает world.tmj (Tiled JSON map) — источник правды для тайлов и
# спавна игрока. Сервер читает тот же файл (вшитый в data.gen.ts).
class_name WorldData
extends RefCounted

const TILE_SIZE := 32
const MAP_PATH := "res://assets/world.tmj"

enum Tile { GRASS, SAND, WATER, TREE, STONE, PATH }
const BLOCKED := [Tile.WATER, Tile.TREE, Tile.STONE]

var map_cols: int = 60
var map_rows: int = 45
var tiles: PackedInt32Array
var player_spawn: Vector2 = Vector2(960, 720)

func _init() -> void:
	tiles = PackedInt32Array()
	_load()

func _load() -> void:
	var raw := FileAccess.get_file_as_string(MAP_PATH)
	if raw.is_empty():
		push_error("world.tmj не найден по %s" % MAP_PATH)
		return
	var data: Dictionary = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("world.tmj не валидный JSON")
		return

	map_cols = int(data.get("width", 60))
	map_rows = int(data.get("height", 45))
	tiles.resize(map_cols * map_rows)

	for layer in data.get("layers", []):
		var l: Dictionary = layer
		match String(l.get("type", "")):
			"tilelayer":
				if String(l.get("name", "")) == "Tiles":
					var arr: Array = l.get("data", [])
					for i in range(min(arr.size(), tiles.size())):
						# Tiled gid'ы 1-based, наш firstgid=1.
						tiles[i] = max(0, int(arr[i]) - 1)
			"objectgroup":
				if String(l.get("name", "")) == "NPCs":
					for o in l.get("objects", []):
						var obj: Dictionary = o
						if String(obj.get("type", "")) == "spawn" or String(obj.get("name", "")) == "player_spawn":
							var w: float = float(obj.get("width", TILE_SIZE))
							var h: float = float(obj.get("height", TILE_SIZE))
							player_spawn = Vector2(
								float(obj.get("x", 0)) + w / 2.0,
								float(obj.get("y", 0)) + h / 2.0,
							)

# Совместимость со старым кодом — раньше эти константы вытаскивались как
# WorldData.MAP_COLS/MAP_ROWS/MAP_WIDTH/MAP_HEIGHT, теперь это статичные
# поля синглтона который есть в World node, не статика. Прокидываем их
# через World инстанс.

func is_walkable_at(x: float, y: float) -> bool:
	var col := int(floor(x / TILE_SIZE))
	var row := int(floor(y / TILE_SIZE))
	if col < 0 or col >= map_cols or row < 0 or row >= map_rows:
		return false
	return not BLOCKED.has(tiles[row * map_cols + col])
