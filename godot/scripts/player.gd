# Local player — WASD + click-to-move + axis-separated collision.
class_name Player
extends Node2D

signal moved(pos: Vector2)

const SPEED := 100.0
# При активном бафе «sprint» (см. OP_ME.effects) клиент тоже должен
# успевать интерполировать — иначе серверная +50% не видна визуально.
const SPEED_SPRINT := 150.0
const SPRITE_VARIANTS := 6
# Фундамент (pixellab walking-6-frames + cross-punch-6-frames):
# walk-атлас: 6 walk frames × 4 directions (hframes=6, vframes=4)
# idle-атлас: 6 idle frames × 4 directions (hframes=6, vframes=4)
# punch-атлас: 6 punch frames × 4 directions (hframes=6, vframes=4)
# Row 0 DOWN (south), 1 LEFT (west), 2 RIGHT (east), 3 UP (north).
# Все варианты char_0..5 и archer_walk — копии char_base_walk.png,
# различия между персонажами только через overlay оружия/одежды.
const IDLE_HFRAMES := 6
const IDLE_FPS := 4.0
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
var book_sprite: Sprite2D
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
var _sprint_end_ms: int = 0  # когда активен баф sprint — локальное ms
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
	sprite.texture = load("res://assets/sprites/characters/char_%d.png" % variant)
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
	bow_sprite.texture = load("res://assets/sprites/characters/bow_hand.png")
	bow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bow_sprite.scale = Vector2(0.55, 0.55)
	bow_sprite.visible = false
	add_child(bow_sprite)

	book_sprite = Sprite2D.new()
	book_sprite.texture = load("res://assets/sprites/characters/book_hand.png")
	book_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	book_sprite.scale = Vector2(1.1, 1.1)
	book_sprite.visible = false
	add_child(book_sprite)

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
		var speed_now := SPEED_SPRINT if Time.get_ticks_msec() < _sprint_end_ms else SPEED
		var s := speed_now * delta
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

func set_sprint_remaining(ms: int) -> void:
	# Вызывается из game._apply_me / _apply_positions когда сервер
	# подтверждает активный sprint-баф. Клиент временно повышает
	# скорость интерполяции, чтобы визуально догонять серверную pos.
	if ms <= 0:
		_sprint_end_ms = 0
		return
	_sprint_end_ms = Time.get_ticks_msec() + ms

func remote_update(new_pos: Vector2) -> void:
	# Если позиция далеко (>120px) — телепорт. Иначе плавное движение.
	if position.distance_to(new_pos) > 120.0:
		position = new_pos
		_remote_has_target = false
	else:
		_remote_target = new_pos
		_remote_has_target = true

var _has_bow := false
var _weapon_kind: String = ""  # "bow" | "tome" | "sword" | "" — для overlay
var _weapon_item: String = ""  # конкретный id предмета (для индивидуальных текстур)

# Legacy API — только kind (без item id). Используем как fallback.
func set_has_bow(on: bool) -> void:
	set_weapon_kind("bow" if on else "")

func set_weapon_kind(kind: String) -> void:
	_apply_weapon(kind, "")

# Предпочтительный путь: передаём точный item id из OP_POSITIONS.eqWeapon.
# Это нужно чтобы у удалённого мага «Мистическая книга» выглядела иначе
# чем «Книга подмастерья», когда появятся отдельные текстуры.
func set_weapon_item(item_id: String) -> void:
	var kind := ""
	if item_id.find("bow") >= 0:
		kind = "bow"
	elif item_id.find("tome") >= 0:
		kind = "tome"
	elif item_id.find("sword") >= 0:
		kind = "sword"
	_apply_weapon(kind, item_id)

func _apply_weapon(kind: String, item_id: String) -> void:
	if _weapon_kind == kind and _weapon_item == item_id:
		return
	_weapon_kind = kind
	_weapon_item = item_id
	_has_bow = (kind == "bow")
	if bow_string: bow_string.visible = false
	if bow_arrow: bow_arrow.visible = false
	sprite.texture = load("res://assets/sprites/characters/char_%d.png" % variant)
	sprite.hframes = WALK_HFRAMES
	sprite.vframes = 4
	sprite.frame = facing * WALK_HFRAMES
	if bow_sprite:
		bow_sprite.visible = (kind == "bow")
		if kind == "bow":
			bow_sprite.texture = _weapon_texture("bow", item_id, "res://assets/sprites/characters/bow_hand.png")
			_update_bow_position()
	if book_sprite:
		book_sprite.visible = (kind == "tome")
		if kind == "tome":
			book_sprite.texture = _weapon_texture("tome", item_id, "res://assets/sprites/characters/book_hand.png")
			_update_book_position()

# Ищет индивидуальный спрайт по имени предмета. Пробует несколько
# раскладок (в AI_HANDOFF.md зафиксирован контракт):
#   tome: assets/sprites/characters/books/<short>_tome_open.png
#         assets/sprites/characters/book_<short>_hand.png (legacy)
#   bow:  assets/sprites/characters/bows/<short>_bow_drawn.png
#         assets/sprites/characters/bow_<short>_hand.png (legacy)
# Если ни один не найден — общий overlay (fallback).
func _weapon_texture(kind: String, item_id: String, fallback: String) -> Texture2D:
	if item_id != "":
		var short := item_id
		if kind == "bow" and short.ends_with("_bow"):
			short = short.substr(0, short.length() - 4)
		elif kind == "tome" and short.ends_with("_tome"):
			short = short.substr(0, short.length() - 5)
		var candidates: Array = []
		if kind == "tome":
			candidates.append("res://assets/sprites/characters/books/%s_tome_open.png" % short)
			candidates.append("res://assets/sprites/characters/book_%s_hand.png" % short)
		elif kind == "bow":
			candidates.append("res://assets/sprites/characters/bows/%s_bow_drawn.png" % short)
			candidates.append("res://assets/sprites/characters/bow_%s_hand.png" % short)
		elif kind == "sword":
			candidates.append("res://assets/sprites/characters/swords/%s_sword.png" % short)
		for path in candidates:
			if ResourceLoader.exists(path):
				return load(path)
	return load(fallback)

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

func _update_book_position() -> void:
	if book_sprite == null or not book_sprite.visible:
		return
	book_sprite.centered = true
	# Книга лежит в левой руке, слегка ниже центра. Просто overlay.
	match facing:
		Dir.DOWN:
			book_sprite.position = Vector2(6, -14)
			book_sprite.flip_h = false
			book_sprite.z_index = 1
		Dir.UP:
			book_sprite.position = Vector2(-6, -16)
			book_sprite.flip_h = true
			book_sprite.z_index = -1
		Dir.LEFT:
			book_sprite.position = Vector2(-6, -14)
			book_sprite.flip_h = true
			book_sprite.z_index = 1
		Dir.RIGHT:
			book_sprite.position = Vector2(6, -14)
			book_sprite.flip_h = false
			book_sprite.z_index = 1

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
	sprite.texture = load("res://assets/sprites/characters/char_base_punch.png")
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
	sprite.texture = load("res://assets/sprites/characters/char_base_shoot.png")
	sprite.hframes = SHOOT_HFRAMES
	sprite.vframes = 4
	_apply_layer_state("shoot")

func play_roll() -> void:
	# Временно: перекат = короткий punch-sprite (пока нет отдельного rig).
	_roll_end_ms = Session.server_now_ms() + int(ROLL_DURATION * 1000.0)
	sprite.texture = load("res://assets/sprites/characters/char_base_punch.png")
	sprite.hframes = PUNCH_HFRAMES
	sprite.vframes = 4
	_apply_layer_state("punch")

func play_bow_shot_upward() -> void:
	if not _has_bow: return
	facing = Dir.UP
	play_bow_shot()

func _restore_walk_sprite() -> void:
	sprite.texture = load("res://assets/sprites/characters/char_%d.png" % variant)
	sprite.hframes = WALK_HFRAMES
	sprite.vframes = 4
	sprite.frame = facing * WALK_HFRAMES
	_apply_layer_state("walk")

func _apply_idle_sprite() -> void:
	sprite.texture = load("res://assets/sprites/characters/char_base_idle.png")
	sprite.hframes = IDLE_HFRAMES
	sprite.vframes = 4
	sprite.frame = facing * IDLE_HFRAMES
	_apply_layer_state("idle")

# ═══════════════════════ Paper-doll layers ═══════════════════════
# Слои наследуют state (walk/punch/shoot) от базового sprite и дублируют
# его frame. Текстура слоя — отдельный атлас в res://assets/sprites/characters/wear/
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
	var textures := {}
	for state in ["walk", "punch", "shoot"]:
		var path := "res://assets/sprites/characters/wear/%s/%s_%s.png" % [slot, item_id, state]
		if ResourceLoader.exists(path):
			textures[state] = load(path)
	if textures.is_empty():
		# Ни одного подходящего атласа — слой остаётся невидимым.
		layer.visible = false
		layer.set_meta("textures", {})
		return
	# Если нет атласа для state — fallback на walk.
	var walk_tex = textures.get("walk", textures.values()[0])
	if not textures.has("walk"): textures["walk"] = walk_tex
	if not textures.has("punch"): textures["punch"] = walk_tex
	if not textures.has("shoot"): textures["shoot"] = walk_tex
	layer.set_meta("textures", textures)
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
	if state == "idle":
		layer.texture = texts.get("walk")
		layer.hframes = WALK_HFRAMES
		layer.vframes = 4
		layer.frame = facing * WALK_HFRAMES
		layer.offset = sprite.offset
		layer.scale = sprite.scale
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
		if _current_anim_state == "idle":
			l.frame = facing * WALK_HFRAMES
		else:
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
	_update_book_position()

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
	_update_book_position()
	if not moving:
		if _current_anim_state != "idle":
			_apply_idle_sprite()
			anim_t = 0.0
		anim_t += delta
		var idle_base := facing * IDLE_HFRAMES
		var idle_cycle := int(anim_t * IDLE_FPS) % IDLE_HFRAMES
		sprite.frame = idle_base + idle_cycle
		_sync_layers()
		return
	if _current_anim_state == "idle":
		_restore_walk_sprite()
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
