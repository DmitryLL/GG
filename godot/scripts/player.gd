# Local player — WASD + click-to-move + axis-separated collision.
class_name Player
extends Node2D

signal moved(pos: Vector2)

const SPEED := 200.0
const SPRITE_VARIANTS := 6
# Фундамент (pixellab walking-6-frames + cross-punch-6-frames):
# walk-атлас: 6 walk frames × 4 directions (hframes=6, vframes=4)
# punch-атлас: 6 punch frames × 4 directions (hframes=6, vframes=4)
# Row 0 DOWN (south), 1 LEFT (west), 2 RIGHT (east), 3 UP (north).
# Все варианты char_0..5 и archer_walk — копии char_base_walk.png,
# различия между персонажами только через overlay оружия/одежды.
const WALK_HFRAMES := 6
const WALK_FPS := 10.0
const PUNCH_HFRAMES := 6
const PUNCH_DURATION := 0.45
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
var _path: PackedVector2Array = PackedVector2Array()
var _path_idx: int = 0
var _remote_target: Vector2 = Vector2.ZERO
var _remote_has_target: bool = false
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
	sprite.hframes = WALK_HFRAMES
	sprite.vframes = 4
	sprite.frame = Dir.DOWN * WALK_HFRAMES
	sprite.scale = Vector2(1.0, 1.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, -24)
	add_child(sprite)
	z_index = 50  # игрок всегда поверх мобов/деревьев

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
	# Враждебные игроки — красные ники, свой — белый
	var nick_color: Color = Color(1, 1, 1) if local else Color(1.0, 0.35, 0.30)
	label.add_theme_color_override("font_color", nick_color)
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
		# Для remote игроков — плавная интерполяция к target и анимация
		if _remote_has_target:
			var to := _remote_target - position
			var dist := to.length()
			var s := SPEED * delta
			if dist <= s:
				position = _remote_target
				_remote_has_target = false
			else:
				var step := to.normalized() * s
				position += step
				_set_facing_from(step)
			moving = dist > 0.3
		else:
			moving = false
		_animate(delta)
		return

	var step := Vector2.ZERO
	var now_moving := false
	if has_target:
		var to := move_target - position
		var dist := to.length()
		var s := SPEED * delta
		if dist <= s:
			step = to
			# Дошли до waypoint'а — переходим к следующему или останавливаемся
			if _path.size() > 0 and _path_idx + 1 < _path.size():
				_path_idx += 1
				move_target = _path[_path_idx]
			else:
				has_target = false
				_path = PackedVector2Array()
				_path_idx = 0
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

func facing_vector() -> Vector2:
	match facing:
		Dir.DOWN: return Vector2(0, 1)
		Dir.UP: return Vector2(0, -1)
		Dir.LEFT: return Vector2(-1, 0)
		Dir.RIGHT: return Vector2(1, 0)
	return Vector2(0, 1)

func remote_update(new_pos: Vector2) -> void:
	# Если позиция далеко (>120px) — телепорт. Иначе плавное движение.
	if position.distance_to(new_pos) > 120.0:
		position = new_pos
		_remote_has_target = false
	else:
		_remote_target = new_pos
		_remote_has_target = true

var _has_bow := false
func set_has_bow(on: bool) -> void:
	if _has_bow == on: return
	_has_bow = on
	if bow_string: bow_string.visible = false
	if bow_arrow: bow_arrow.visible = false
	# Лучник и безоружный — один базовый rig; различие только в overlay-луке.
	sprite.texture = load("res://assets/sprites/char_%d.png" % variant)
	sprite.hframes = WALK_HFRAMES
	sprite.vframes = 4
	sprite.frame = facing * WALK_HFRAMES
	if bow_sprite:
		bow_sprite.visible = on
		if on:
			_update_bow_position()

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
var _roll_t := 0.0
const BOW_SHOT_DURATION := 0.55
const ROLL_DURATION := 0.4
const ROLL_FRAMES := 6

func play_punch() -> void:
	_punch_t = PUNCH_DURATION
	sprite.texture = load("res://assets/sprites/char_base_punch.png")
	sprite.hframes = PUNCH_HFRAMES
	sprite.vframes = 4

func play_bow_shot() -> void:
	# Пока используем punch-анимацию и для выстрела (bow overlay включён).
	# Отдельный bow-shot rig добавим в следующей итерации, если понадобится.
	if not _has_bow: return
	_bow_shot_t = BOW_SHOT_DURATION
	sprite.texture = load("res://assets/sprites/char_base_punch.png")
	sprite.hframes = PUNCH_HFRAMES
	sprite.vframes = 4

func play_roll() -> void:
	# Временно: перекат = короткий punch-sprite (пока нет отдельного rig).
	_roll_t = ROLL_DURATION
	sprite.texture = load("res://assets/sprites/char_base_punch.png")
	sprite.hframes = PUNCH_HFRAMES
	sprite.vframes = 4

func play_bow_shot_upward() -> void:
	if not _has_bow: return
	facing = Dir.UP
	play_bow_shot()

func _restore_walk_sprite() -> void:
	sprite.texture = load("res://assets/sprites/char_%d.png" % variant)
	sprite.hframes = WALK_HFRAMES
	sprite.vframes = 4
	sprite.frame = facing * WALK_HFRAMES

func _set_facing_from(delta: Vector2) -> void:
	if abs(delta.x) < 0.01 and abs(delta.y) < 0.01:
		return
	if abs(delta.x) > abs(delta.y):
		facing = Dir.RIGHT if delta.x > 0 else Dir.LEFT
	else:
		facing = Dir.DOWN if delta.y > 0 else Dir.UP
	_update_bow_position()

func _animate(delta: float) -> void:
	var base := facing * WALK_HFRAMES
	# Roll (отскок)
	if _roll_t > 0.0:
		_roll_t -= delta
		var rprog: float = 1.0 - (_roll_t / ROLL_DURATION)
		var rframe: int = clampi(int(rprog * PUNCH_HFRAMES), 0, PUNCH_HFRAMES - 1)
		sprite.frame = facing * PUNCH_HFRAMES + rframe
		sprite.offset = Vector2(0, -24)
		if _roll_t <= 0.0:
			_restore_walk_sprite()
		return
	# Bow shot: проигрываем punch-анимацию (overlay лука играет сам отдельно).
	if _bow_shot_t > 0.0:
		_bow_shot_t -= delta
		var progress: float = 1.0 - (_bow_shot_t / BOW_SHOT_DURATION)
		var frame_in_row: int = clampi(int(progress * PUNCH_HFRAMES), 0, PUNCH_HFRAMES - 1)
		sprite.frame = facing * PUNCH_HFRAMES + frame_in_row
		sprite.offset = Vector2(0, -24)
		if _bow_shot_t <= 0.0:
			_restore_walk_sprite()
		return
	# Punch: полная 6-кадровая анимация из char_base_punch.png.
	if _punch_t > 0.0:
		_punch_t -= delta
		var pprog: float = 1.0 - (_punch_t / PUNCH_DURATION)
		var pframe: int = clampi(int(pprog * PUNCH_HFRAMES), 0, PUNCH_HFRAMES - 1)
		sprite.frame = facing * PUNCH_HFRAMES + pframe
		sprite.offset = Vector2(0, -24)
		if _punch_t <= 0.0:
			_restore_walk_sprite()
		return
	sprite.offset = Vector2(0, -24)
	if bow_sprite and bow_sprite.visible:
		bow_sprite.scale = Vector2(0.6, 0.6)
		_update_bow_position()
	if not moving:
		sprite.frame = base
		anim_t = 0.0
		return
	anim_t += delta
	var cycle := int(anim_t * WALK_FPS) % WALK_HFRAMES
	sprite.frame = base + cycle

func request_move_to(world_pos: Vector2) -> void:
	if world == null:
		move_target = world_pos
		has_target = true
		return
	# Строим путь A*. Если путь пуст или из 1 точки — идём напрямую.
	var p := world.find_path(position, world_pos)
	if p.size() <= 1:
		move_target = world_pos
		_path = PackedVector2Array()
		_path_idx = 0
	else:
		_path = p
		_path_idx = 1  # 0 — текущая клетка, начинаем со следующей
		move_target = _path[_path_idx]
	has_target = true

static func variant_from(id: String) -> int:
	var h := 0
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) & 0xFFFFFFFF
	return h % SPRITE_VARIANTS
