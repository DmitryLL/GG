# Spawns one Sprite2D per tile. 60×45 = 2700 sprites — fine for 2D on
# any desktop/mobile GPU. When perf becomes an issue we swap for a
# TileMapLayer batched draw.
class_name World
extends Node2D

const TILES_TEX := preload("res://assets/sprites/tiles.png")
const TREE_TEX := preload("res://assets/sprites/tree.png")

var data: WorldData

func _ready() -> void:
	data = WorldData.new()
	_render_tiles()

func _render_tiles() -> void:
	for r in data.map_rows:
		for c in data.map_cols:
			var id: int = data.tiles[r * data.map_cols + c]
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
			if id == WorldData.Tile.TREE:
				var tree := Sprite2D.new()
				tree.texture = TREE_TEX
				tree.centered = false
				tree.position = Vector2(c * WorldData.TILE_SIZE - 16, r * WorldData.TILE_SIZE - 64)
				tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tree.z_index = r
				add_child(tree)

func is_walkable(pos: Vector2) -> bool:
	return data.is_walkable_at(pos.x, pos.y)

func player_spawn() -> Vector2:
	return data.player_spawn
