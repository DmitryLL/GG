# Local player — WASD + click-to-move + axis-separated collision.
class_name Player
extends Node2D

const World = preload("res://scripts/world.gd")
signal moved(pos: Vector2)

const SPEED := 100.0
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
const SHOOT_HFRAMES := 4
const SHOOT_DURATION := 0.55
enum Dir { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

# Paper-doll layers. Порядок = порядок отрисовки снизу вверх. На каждый
# equipment-slot свой Sprite2D-ребёнок, который отслеживает frame базы.
# Текстуры одежды должны иметь тот же hframes/vframes, что и база, для
# соответствующего state (walk/punch/shoot). См. set_wear().
const LAYER_SLOTS := ["pants", "boots", "body", "cloak", "gloves", "head", "weapon"]

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
var layers: Dictionary = {}  # slot → Sprite2D (paper-doll overlay)
var _current_anim_state: String = "walk"
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
var _move_facing_locked: bool = false
var anim_t: float = 0.0
var _flash_t: float = 0.0
var _walk_tex: ImageTexture
var _punch_tex: ImageTexture
var _shoot_tex: ImageTexture

func setup(p_world: World, p_name: String, p_variant: int) -> void:
	world = p_world
	display_name = p_name
	variant = p_variant

func _ready() -> void:
	_walk_tex = _make_state_texture(Color.from_hsv(float(variant) / max(1.0, float(SPRITE_VARIANTS)), 0.55, 0.92), WALK_HFRAMES)
	_punch_tex = _make_state_texture(Color(0.92, 0.62, 0.48, 1.0), PUNCH_HFRAMES)
	_shoot_tex = _make_state_texture(Color(0.70, 0.82, 0.98, 1.0), SHOOT_HFRAMES)
	sprite = Sprite2D.new()
	sprite.texture = _walk_tex
	sprite.hframes = WALK_HFRAMES
	sprite.vframes = 4
	sprite.frame = Dir.DOWN * WALK_HFRAMES
	sprite.scale = Vector2(1.0, 1.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, -24)
	add_child(sprite)
	z_index = 50  # игрок всегда поверх мобов/деревьев

	_setup_layers()

	bow_sprite = Sprite2D.new()
	bow_sprite.texture = _make_bow_texture()
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
	# Server-authoritative movement: и local, и remote одинаково интерполируют
	# к _remote_target (сервер шлёт позицию через OP_POSITIONS → remote_update()).
	if _remote_has_target:
		var to := _remote_target - position
		var dist := to.length()
		var s := SPEED * delta
		if dist <= s:
			position = _remote_target
			_remote_has_target = false
			_move_facing_locked = false
		else:
			var step := to.normalized() * s
			position += step
			if not _move_facing_locked:
				_set_facing_from(step)
				_move_facing_locked = true
		moving = dist > 0.3
	else:
		moving = false
		_move_facing_locked = false
	if local:
		moved.emit(position)
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
	sprite.texture = _walk_tex
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

# Все анимационные таймеры — абсолютный server-time (мс), чтобы при
# сворачивании вкладки клиентский process не тормозил длительность.
# Проверка: if Session.server_now_ms() < _xxx_end_ms: играем.
var _punch_end_ms: int = 0
var _bow_shot_end_ms: int = 0
var _roll_end_ms: int = 0
const BOW_SHOT_DURATION := 0.55
const ROLL_DURATION := 0.4
const ROLL_FRAMES := 6

func play_punch() -> void:
	_punch_end_ms = Session.server_now_ms() + int(PUNCH_DURATION * 1000.0)
	sprite.texture = _punch_tex
	sprite.hframes = PUNCH_HFRAMES
	sprite.vframes = 4
	_apply_layer_state("punch")

func play_bow_shot() -> void:
	# Archer-rig: custom pixellab анимация «натягивание и пуск стрелы»,
	# руки пустые (лук рисуется через bow_sprite overlay).
	# 4 кадра × 4 направления. Направление «вверх» пока использует south
	# до генерации специфического ракурса.
	if not _has_bow: return
	_bow_shot_end_ms = Session.server_now_ms() + int(SHOOT_DURATION * 1000.0)
	sprite.texture = _shoot_tex
	sprite.hframes = SHOOT_HFRAMES
	sprite.vframes = 4
	_apply_layer_state("shoot")

func play_roll() -> void:
	# Временно: перекат = короткий punch-sprite (пока нет отдельного rig).
	_roll_end_ms = Session.server_now_ms() + int(ROLL_DURATION * 1000.0)
	sprite.texture = _punch_tex
	sprite.hframes = PUNCH_HFRAMES
	sprite.vframes = 4
	_apply_layer_state("punch")

func play_bow_shot_upward() -> void:
	if not _has_bow: return
	facing = Dir.UP
	play_bow_shot()

func _restore_walk_sprite() -> void:
	sprite.texture = _walk_tex
	sprite.hframes = WALK_HFRAMES
	sprite.vframes = 4
	sprite.frame = facing * WALK_HFRAMES
	_apply_layer_state("walk")

# ═══════════════════════ Paper-doll layers ═══════════════════════
# Слои наследуют state (walk/punch/shoot) от базового sprite и дублируют
# его frame. Текстура слоя — отдельный атлас в res://assets/sprites/wear/
# <slot>/<item_id>_<state>.png. Если файла для state нет, слой скрыт.

func _setup_layers() -> void:
	for slot in LAYER_SLOTS:
		var s := Sprite2D.new()
		s.hframes = WALK_HFRAMES
		s.vframes = 4
		s.scale = sprite.scale
		s.offset = sprite.offset
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.visible = false
		add_child(s)
		layers[slot] = s

# Публичный API: game.gd вызывает при приходе OP_ME с новой eq.
# item_id = "" → снять слой.
func set_wear(slot: String, item_id: String) -> void:
	var layer: Sprite2D = layers.get(slot)
	if layer == null:
		return
	if item_id == "":
		layer.visible = false
		layer.set_meta("textures", {})
		return
	layer.visible = false
	layer.set_meta("textures", {})
	return
	layer.visible = true
	_apply_layer_state_for(layer, _current_anim_state)

func _apply_layer_state(state: String) -> void:
	_current_anim_state = state
	for slot in LAYER_SLOTS:
		var l: Sprite2D = layers.get(slot)
		if l != null and l.visible:
			_apply_layer_state_for(l, state)

func _apply_layer_state_for(layer: Sprite2D, state: String) -> void:
	var texts: Dictionary = layer.get_meta("textures", {})
	if texts.is_empty():
		layer.visible = false
		return
	layer.texture = texts.get(state)
	match state:
		"walk":  layer.hframes = WALK_HFRAMES
		"punch": layer.hframes = PUNCH_HFRAMES
		"shoot": layer.hframes = SHOOT_HFRAMES
	layer.vframes = 4
	layer.frame = sprite.frame
	layer.offset = sprite.offset
	layer.scale = sprite.scale

func _sync_layers() -> void:
	for slot in LAYER_SLOTS:
		var l: Sprite2D = layers.get(slot)
		if l == null or not l.visible or l.texture == null:
			continue
		l.frame = sprite.frame
		l.offset = sprite.offset
		l.scale = sprite.scale

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
	var now_s: int = Session.server_now_ms()
	# Roll (отскок)
	if now_s < _roll_end_ms:
		var remain: int = _roll_end_ms - now_s
		var rprog: float = 1.0 - float(remain) / (ROLL_DURATION * 1000.0)
		var rframe: int = clampi(int(rprog * PUNCH_HFRAMES), 0, PUNCH_HFRAMES - 1)
		sprite.frame = facing * PUNCH_HFRAMES + rframe
		sprite.offset = Vector2(0, -24)
		_sync_layers()
		return
	elif _roll_end_ms > 0:
		_roll_end_ms = 0
		_restore_walk_sprite()
	# Bow shot: archer-rig 4 frames, overlay лука рисуется сам отдельно.
	if now_s < _bow_shot_end_ms:
		var remain2: int = _bow_shot_end_ms - now_s
		var progress: float = 1.0 - float(remain2) / (SHOOT_DURATION * 1000.0)
		var frame_in_row: int = clampi(int(progress * SHOOT_HFRAMES), 0, SHOOT_HFRAMES - 1)
		sprite.frame = facing * SHOOT_HFRAMES + frame_in_row
		sprite.offset = Vector2(0, -24)
		_sync_layers()
		return
	elif _bow_shot_end_ms > 0:
		_bow_shot_end_ms = 0
		_restore_walk_sprite()
	# Punch: полная 6-кадровая анимация из char_base_punch.png.
	if now_s < _punch_end_ms:
		var remain3: int = _punch_end_ms - now_s
		var pprog: float = 1.0 - float(remain3) / (PUNCH_DURATION * 1000.0)
		var pframe: int = clampi(int(pprog * PUNCH_HFRAMES), 0, PUNCH_HFRAMES - 1)
		sprite.frame = facing * PUNCH_HFRAMES + pframe
		sprite.offset = Vector2(0, -24)
		_sync_layers()
		return
	elif _punch_end_ms > 0:
		_punch_end_ms = 0
		_restore_walk_sprite()
	sprite.offset = Vector2(0, -24)
	if bow_sprite and bow_sprite.visible:
		bow_sprite.scale = Vector2(0.6, 0.6)
		_update_bow_position()
	if not moving:
		sprite.frame = base
		anim_t = 0.0
		_sync_layers()
		return
	anim_t += delta
	var cycle := int(anim_t * WALK_FPS) % WALK_HFRAMES
	sprite.frame = base + cycle
	_sync_layers()

func request_move_to(_world_pos: Vector2) -> void:
	# Deprecated в server-authoritative модели. Game.gd использует
	# _send_move_intent(target) и отправляет OP_MOVE_INTENT.
	# Оставлено для совместимости — no-op.
	pass

static func variant_from(id: String) -> int:
	var h := 0
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) & 0xFFFFFFFF
	return h % SPRITE_VARIANTS

func _make_state_texture(base: Color, frames: int) -> ImageTexture:
	var fw := 18
	var fh := 26
	var img := Image.create(fw * frames, fh * 4, false, Image.FORMAT_RGBA8)
	for dir in range(4):
		for frame in range(frames):
			var ox := frame * fw
			var oy := dir * fh
			var shade := 0.88 + 0.04 * frame
			var body := Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
			for y in range(6, 19):
				for x in range(5, 13):
					img.set_pixel(ox + x, oy + y, body)
			for y in range(2, 7):
				for x in range(6, 12):
					img.set_pixel(ox + x, oy + y, Color(0.97, 0.88, 0.75, 1.0))
			var leg_shift := (frame % 2) if frame > 0 else 0
			for y in range(19, 25):
				img.set_pixel(ox + 7 - leg_shift, oy + y, Color(0.22, 0.16, 0.12, 1.0))
				img.set_pixel(ox + 10 + leg_shift, oy + y, Color(0.22, 0.16, 0.12, 1.0))
	return ImageTexture.create_from_image(img)

func _make_bow_texture() -> ImageTexture:
	var img := Image.create(8, 20, false, Image.FORMAT_RGBA8)
	for y in range(20):
		img.set_pixel(2, y, Color(0.50, 0.28, 0.12, 1.0))
		if y > 1 and y < 18:
			img.set_pixel(5, y, Color(0.85, 0.82, 0.70, 1.0))
	return ImageTexture.create_from_image(img)
