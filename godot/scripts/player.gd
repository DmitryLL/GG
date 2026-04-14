# Local player — WASD + click-to-move + axis-separated collision.
class_name Player
extends Node2D

signal moved(pos: Vector2)

const SPEED := 200.0
const ANIM_FPS := 8.0
const SPRITE_VARIANTS := 6
# Sprite layout: 3 walk frames × 4 directions. hframes=3, vframes=4.
# Row 0 down, Row 1 left, Row 2 right, Row 3 up. Col 0 idle, 1/2 steps.
enum Dir { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

@export var display_name: String = ""
@export var variant: int = 0
@export var local: bool = true

var world: World
var sprite: Sprite2D
var label: Label
var hp_bg: ColorRect
var hp_fill: ColorRect
var hp: float = 100.0
var hp_max: float = 100.0
var move_target: Vector2 = Vector2.ZERO
var has_target: bool = false
var facing: int = Dir.DOWN
var moving: bool = false
var anim_t: float = 0.0
var _flash_t: float = 0.0

func setup(p_world: World, p_name: String, p_variant: int) -> void:
	world = p_world
	display_name = p_name
	variant = p_variant

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/char_%d.png" % variant)
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.frame = Dir.DOWN * 3
	sprite.scale = Vector2(1.5, 1.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	label = Label.new()
	label.text = display_name
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, 16)
	label.position = Vector2(-60, -42)
	add_child(label)

	hp_bg = ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.7)
	hp_bg.size = Vector2(28, 4)
	hp_bg.position = Vector2(-14, -26)
	add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.29, 0.87, 0.5, 1.0)
	hp_fill.size = Vector2(28, 4)
	hp_fill.position = Vector2(-14, -26)
	add_child(hp_fill)

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			sprite.modulate = Color(1, 1, 1, 1)
	if not local:
		return
	var input := Vector2.ZERO
	if Input.is_action_pressed("move_left"): input.x -= 1
	if Input.is_action_pressed("move_right"): input.x += 1
	if Input.is_action_pressed("move_up"): input.y -= 1
	if Input.is_action_pressed("move_down"): input.y += 1

	var step := Vector2.ZERO
	var now_moving := false
	if input != Vector2.ZERO:
		has_target = false
		step = input.normalized() * SPEED * delta
		now_moving = true
	elif has_target:
		var to := move_target - position
		var dist := to.length()
		var s := SPEED * delta
		if dist <= s:
			step = to
			has_target = false
		else:
			step = to.normalized() * s
		now_moving = dist > 0.3

	if now_moving:
		var next := position + step
		# Axis-separated collision against world tiles
		if world.is_walkable(Vector2(next.x, position.y)):
			position.x = next.x
		if world.is_walkable(Vector2(position.x, next.y)):
			position.y = next.y
		_set_facing_from(step)
		moved.emit(position)
	moving = now_moving
	_animate(delta)

func set_hp(v: float, vmax: float) -> void:
	hp = max(0.0, v)
	hp_max = max(1.0, vmax)
	var ratio: float = clamp(hp / hp_max, 0.0, 1.0)
	hp_fill.size.x = 28.0 * ratio

func flash() -> void:
	_flash_t = 0.1
	sprite.modulate = Color(1.5, 0.8, 0.8, 1.0)

func _set_facing_from(delta: Vector2) -> void:
	if abs(delta.x) < 0.01 and abs(delta.y) < 0.01:
		return
	if abs(delta.x) > abs(delta.y):
		facing = Dir.RIGHT if delta.x > 0 else Dir.LEFT
	else:
		facing = Dir.DOWN if delta.y > 0 else Dir.UP

func _animate(delta: float) -> void:
	var base := facing * 3
	if not moving:
		sprite.frame = base
		anim_t = 0.0
		return
	anim_t += delta
	var cycle := int(anim_t * ANIM_FPS) % 4
	var offsets := [1, 0, 2, 0]
	sprite.frame = base + offsets[cycle]

func request_move_to(world_pos: Vector2) -> void:
	move_target = world_pos
	has_target = true

static func variant_from(id: String) -> int:
	var h := 0
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) & 0xFFFFFFFF
	return h % SPRITE_VARIANTS
