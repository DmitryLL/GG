# A world-drop visual: floating item icon with a gentle bob tween.
class_name DropSprite
extends Node2D

const ITEMS_TEX := preload("res://assets/sprites/items.png")

var drop_id: String = ""
var item_id: String = ""

func setup(id: String, p_item: String) -> void:
	drop_id = id
	item_id = p_item

func _ready() -> void:
	var def: Dictionary = Items.def(item_id)
	var sprite := Sprite2D.new()
	sprite.texture = ITEMS_TEX
	sprite.region_enabled = true
	sprite.region_rect = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	sprite.scale = Vector2(1.2, 1.2)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.9)
	tween.tween_property(sprite, "position:y", 2.0, 0.9)
