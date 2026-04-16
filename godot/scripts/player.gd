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
var bow_sprite: Sprite2D
var bow_string: Line2D
var bow_arrow: Line2D
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
	sprite.offset = Vector2(0, -16)
	add_child(sprite)

	bow_sprite = Sprite2D.new()
	bow_sprite.texture = load("res://assets/sprites/bow_hand.png")
	bow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bow_sprite.scale = Vector2(0.55, 0.55)
	bow_sprite.visible = false
	add_child(bow_sprite)

	# Видимая тетива и стрела, появляются во время выстрела
	bow_string = Line2D.new()
	bow_string.default_color = Color(0.95, 0.95, 0.85, 0.9)
	bow_string.width = 1.0
	bow_string.add_point(Vector2.ZERO)
	bow_string.add_point(Vector2(0, -12))
	bow_string.add_point(Vector2(0, 12))
	bow_string.visible = false
	add_child(bow_string)

	bow_arrow = Line2D.new()
	bow_arrow.default_color = Color(0.08, 0.05, 0.12, 1.0)
	bow_arrow.width = 1.5
	bow_arrow.add_point(Vector2.ZERO)
	bow_arrow.add_point(Vector2(12, 0))
	bow_arrow.visible = false
	add_child(bow_arrow)

	label = Label.new()
	label.text = display_name
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, 16)
	label.position = Vector2(-60, -58)
	add_child(label)

	hp_bg = ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.7)
	hp_bg.size = Vector2(28, 4)
	hp_bg.position = Vector2(-14, -42)
	add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.29, 0.87, 0.5, 1.0)
	hp_fill.size = Vector2(28, 4)
	hp_fill.position = Vector2(-14, -42)
	add_child(hp_fill)

	if local:
		label.visible = false
		hp_bg.visible = false
		hp_fill.visible = false

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			sprite.modulate = Color(1, 1, 1, 1)
	if not local:
		return

	var step := Vector2.ZERO
	var now_moving := false
	if has_target:
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

# Всплывающий пузырь с чатом над головой, 4 сек.
var _bubble: Node = null
var _bubble_timer: SceneTreeTimer = null
func show_bubble(text: String) -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	panel.position = Vector2(-80, -88)
	add_child(panel)
	_bubble = panel
	_bubble_timer = get_tree().create_timer(4.0)
	_bubble_timer.timeout.connect(func():
		if is_instance_valid(panel): panel.queue_free()
	)

func face_toward(target: Vector2) -> void:
	_set_facing_from(target - position)

func set_has_bow(on: bool) -> void:
	if bow_sprite:
		bow_sprite.visible = on

func _update_bow_position() -> void:
	if bow_sprite == null or not bow_sprite.visible:
		return
	bow_sprite.centered = true
	# Лук держится вертикально в руке (как долгий лук). Персонаж поворачивается —
	# лук остаётся вертикальным сбоку от него.
	match facing:
		Dir.DOWN:
			bow_sprite.position = Vector2(8, -18)
			bow_sprite.rotation = 0
			bow_sprite.flip_h = false
			bow_sprite.z_index = 1
		Dir.UP:
			bow_sprite.position = Vector2(-8, -20)
			bow_sprite.rotation = 0
			bow_sprite.flip_h = true
			bow_sprite.z_index = -1
		Dir.LEFT:
			bow_sprite.position = Vector2(-6, -20)
			bow_sprite.rotation = 0
			bow_sprite.flip_h = true
			bow_sprite.z_index = 1
		Dir.RIGHT:
			bow_sprite.position = Vector2(6, -20)
			bow_sprite.rotation = 0
			bow_sprite.flip_h = false
			bow_sprite.z_index = 1

var _punch_t := 0.0
var _bow_shot_t := 0.0
func play_punch() -> void:
	_punch_t = 0.25

func play_bow_shot() -> void:
	_bow_shot_t = 0.55

func _set_facing_from(delta: Vector2) -> void:
	if abs(delta.x) < 0.01 and abs(delta.y) < 0.01:
		return
	if abs(delta.x) > abs(delta.y):
		facing = Dir.RIGHT if delta.x > 0 else Dir.LEFT
	else:
		facing = Dir.DOWN if delta.y > 0 else Dir.UP
	_update_bow_position()

func _animate(delta: float) -> void:
	var base := facing * 3
	# Bow shot: 3 phases — aim (0-0.2) → draw string (0.2-0.45) → release recoil (0.45-0.55)
	if _bow_shot_t > 0.0:
		_bow_shot_t -= delta
		var elapsed: float = 0.55 - _bow_shot_t
		var forward_dir := Vector2.ZERO  # from character toward target
		match facing:
			Dir.DOWN:  forward_dir = Vector2(0, 1)
			Dir.UP:    forward_dir = Vector2(0, -1)
			Dir.LEFT:  forward_dir = Vector2(-1, 0)
			Dir.RIGHT: forward_dir = Vector2(1, 0)
		var back_dir := -forward_dir
		var body_off := Vector2.ZERO
		var draw_amount := 0.0  # 0..1 how far string is pulled
		if elapsed < 0.2:
			var k: float = elapsed / 0.2
			body_off = back_dir * (1.5 * k)
		elif elapsed < 0.45:
			var k: float = (elapsed - 0.2) / 0.25
			body_off = back_dir * (1.5 + 2.5 * k)
			draw_amount = k
		else:
			var k: float = (elapsed - 0.45) / 0.1
			body_off = back_dir * (4.0 * (1.0 - k)) + forward_dir * (1.0 * k)
			draw_amount = 1.0 - k
		if bow_sprite and bow_sprite.visible:
			_update_bow_position()
		# Видимая тетива + стрела только во время выстрела
		if bow_sprite and bow_sprite.visible and draw_amount > 0.01:
			bow_string.visible = true
			bow_arrow.visible = true
			# Тетива: треугольник, вершина смещается назад относительно лука
			var bow_pos: Vector2 = bow_sprite.position
			var pull_offset: Vector2 = back_dir * (8.0 * draw_amount)
			bow_string.clear_points()
			bow_string.add_point(bow_pos + Vector2(0, -14))
			bow_string.add_point(bow_pos + pull_offset)
			bow_string.add_point(bow_pos + Vector2(0, 14))
			# Стрела — от натянутой вершины вперёд
			bow_arrow.clear_points()
			bow_arrow.add_point(bow_pos + pull_offset)
			bow_arrow.add_point(bow_pos + pull_offset + forward_dir * 16.0)
		else:
			bow_string.visible = false
			bow_arrow.visible = false
		sprite.offset = Vector2(0, -16) + body_off
		sprite.frame = base
		return
	else:
		if bow_string: bow_string.visible = false
		if bow_arrow: bow_arrow.visible = false
	# Punch visual: lunge sprite toward facing direction briefly.
	if _punch_t > 0.0:
		_punch_t -= delta
		var lunge_dir := Vector2.ZERO
		match facing:
			Dir.DOWN: lunge_dir = Vector2(0, 6)
			Dir.UP: lunge_dir = Vector2(0, -6)
			Dir.LEFT: lunge_dir = Vector2(-6, 0)
			Dir.RIGHT: lunge_dir = Vector2(6, 0)
		sprite.offset = Vector2(0, -16) + lunge_dir
		sprite.frame = base + 2
		return
	else:
		sprite.offset = Vector2(0, -16)
		if bow_sprite and bow_sprite.visible:
			bow_sprite.scale = Vector2(0.6, 0.6)
			_update_bow_position()
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
