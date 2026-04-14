# Server-authoritative mob. Visuals + HP bar; positions/hp arrive from
# the match state.
class_name Mob
extends Node2D

const ANIM_FPS := 3.0

var mob_id: String = ""
var kind: String = "slime"
var hp: float = 0.0
var hp_max: float = 1.0
var alive: bool = true
var loot: Array = []  # [{itemId, qty}] — содержимое трупа

var sprite: Sprite2D
var hp_bg: ColorRect
var hp_fill: ColorRect
var _anim_t := 0.0
var _flash_t := 0.0

func setup(id: String, p_kind: String) -> void:
	mob_id = id
	kind = p_kind

func _ready() -> void:
	var def := {
		"slime":  { "tex": "res://assets/sprites/slime.png",  "scale": 1.3 },
		"goblin": { "tex": "res://assets/sprites/goblin.png", "scale": 1.25 },
	}
	var info: Dictionary = def.get(kind, def["slime"])
	sprite = Sprite2D.new()
	sprite.texture = load(info["tex"])
	sprite.hframes = 2
	sprite.vframes = 1
	sprite.frame = 0
	sprite.scale = Vector2(info["scale"], info["scale"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	hp_bg = ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.7)
	hp_bg.size = Vector2(28, 4)
	hp_bg.position = Vector2(-14, -22)
	add_child(hp_bg)

	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.94, 0.27, 0.27, 1.0)
	hp_fill.size = Vector2(28, 4)
	hp_fill.position = Vector2(-14, -22)
	add_child(hp_fill)

func set_alive(v: bool) -> void:
	alive = v
	visible = true
	hp_bg.visible = v
	hp_fill.visible = v
	if v:
		sprite.rotation = 0
		sprite.modulate = Color(1, 1, 1, 1)
	else:
		# Труп — повернут на бок, серый
		sprite.rotation = deg_to_rad(90)
		sprite.modulate = Color(0.55, 0.55, 0.55, 1.0)

func set_loot(items: Array) -> void:
	loot = items

func set_hp(v: float, vmax: float) -> void:
	hp = max(0.0, v)
	hp_max = max(1.0, vmax)
	var ratio: float = clamp(hp / hp_max, 0.0, 1.0)
	hp_fill.size.x = 28.0 * ratio

func flash() -> void:
	_flash_t = 0.1
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)

func _process(delta: float) -> void:
	if not alive:
		return
	_anim_t += delta
	var cycle := int(_anim_t * ANIM_FPS) % 4
	sprite.frame = 1 if cycle == 3 else 0
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			sprite.modulate = Color(1, 1, 1, 1)
