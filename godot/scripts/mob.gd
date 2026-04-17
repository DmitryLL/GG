# Server-authoritative mob. Visuals + HP bar; positions/hp arrive from
# the match state.
class_name Mob
extends Node2D

var _anim_fps := 4.0
var _anim_frames := 4

var mob_id: String = ""
var kind: String = "slime"
var hp: float = 0.0
var hp_max: float = 1.0
var alive: bool = true
var loot: Array = []  # [{itemId, qty}] — содержимое трупа

var sprite: Sprite2D
var hp_bg: ColorRect
var hp_fill: ColorRect
var glow: Sprite2D
var debuff_icon: Sprite2D
var _poison_end_ms: int = 0
var _server_offset_ms: int = 0
var _anim_t := 0.0
var _flash_t := 0.0
var _glow_t := 0.0
var _highlight := false
var _highlight_ring: Sprite2D

func setup(id: String, p_kind: String) -> void:
	mob_id = id
	kind = p_kind

func _ready() -> void:
	var def := {
		"slime":  { "tex": "res://assets/sprites/slime.png",  "scale": 1.3, "frames": 8, "fps": 6.0 },
		"goblin": { "tex": "res://assets/sprites/goblin.png", "scale": 1.25, "frames": 4, "fps": 4.0 },
		"dummy":  { "tex": "res://assets/sprites/dummy.png",  "scale": 1.4, "frames": 1, "fps": 1.0 },
	}
	var info: Dictionary = def.get(kind, def["slime"])

	# Лёгкое свечение вокруг моба — виден только если есть лут.
	glow = Sprite2D.new()
	glow.texture = _make_glow_texture()
	glow.scale = Vector2(1.6, 1.6)
	glow.modulate = Color(1.0, 0.95, 0.55, 0.0)  # тёплый золотистый
	# Без z_index: порядок в дереве (glow добавлен до sprite) сам рисует
	# свечение под спрайтом, но ПОВЕРХ тайлмапа земли.
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(glow)

	sprite = Sprite2D.new()
	sprite.texture = load(info["tex"])
	sprite.hframes = int(info["frames"])
	sprite.vframes = 1
	sprite.frame = 0
	sprite.scale = Vector2(info["scale"], info["scale"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim_fps = float(info["fps"])
	_anim_frames = int(info["frames"])
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

	debuff_icon = Sprite2D.new()
	var tex: Texture2D = load("res://assets/sprites/ui/effect_poison.png")
	debuff_icon.texture = tex
	debuff_icon.position = Vector2(0, -36)
	debuff_icon.scale = Vector2(1.2, 1.2)
	debuff_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	debuff_icon.visible = true
	debuff_icon.z_index = 100
	add_child(debuff_icon)

	var debug_rect := ColorRect.new()
	debug_rect.name = "DebugRect"
	debug_rect.color = Color(1, 0, 1, 1)  # ярко-розовый
	debug_rect.size = Vector2(16, 16)
	debug_rect.position = Vector2(-8, -60)
	add_child(debug_rect)

	_highlight_ring = Sprite2D.new()
	_highlight_ring.texture = _make_ring_texture()
	_highlight_ring.scale = Vector2(1.8, 0.9)
	_highlight_ring.position.y = 20
	_highlight_ring.modulate = Color(1.0, 0.4, 0.3, 0.95)
	_highlight_ring.visible = false
	_highlight_ring.z_index = -1
	add_child(_highlight_ring)

func set_alive(v: bool) -> void:
	alive = v
	visible = true
	hp_bg.visible = v
	hp_fill.visible = v
	_update_glow()
	if v:
		sprite.rotation = 0
		sprite.modulate = Color(1, 1, 1, 1)
	else:
		# Труп — повернут на бок, серый
		sprite.rotation = deg_to_rad(90)
		sprite.modulate = Color(0.55, 0.55, 0.55, 1.0)

func set_loot(items: Array) -> void:
	loot = items
	_update_glow()

func _update_glow() -> void:
	if glow == null:
		return
	glow.visible = (not alive) and loot.size() > 0

func _make_glow_texture() -> ImageTexture:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	var r := float(size) * 0.45
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x, y).distance_to(c) / r
			var a := 0.0
			if d < 1.0:
				a = (1.0 - d) * (1.0 - d) * 0.35
			# pixel sparkle dots
			if (x + y) % 7 == 0 and d < 0.85:
				a = clamp(a + 0.5, 0.0, 1.0)
			if (x * 3 + y * 5) % 11 == 0 and d < 0.7:
				a = clamp(a + 0.7, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.95, 0.6, a))
	return ImageTexture.create_from_image(img)

func set_highlight(on: bool) -> void:
	_highlight = on
	if _highlight_ring:
		_highlight_ring.visible = on and alive

func _make_ring_texture() -> ImageTexture:
	var size := 40
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	var r_out: float = size * 0.48
	var r_in: float = size * 0.30
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x, y).distance_to(c)
			if d >= r_in and d <= r_out:
				var edge: float = minf(d - r_in, r_out - d) / 3.0
				var a: float = clampf(edge, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
			elif d < r_in:
				var a_inner: float = (r_in - d) / r_in * 0.15
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a_inner))
	return ImageTexture.create_from_image(img)

func set_hp(v: float, vmax: float) -> void:
	hp = max(0.0, v)
	hp_max = max(1.0, vmax)
	var ratio: float = clamp(hp / hp_max, 0.0, 1.0)
	hp_fill.size.x = 28.0 * ratio

func set_debuff(d, server_now_ms: int) -> void:
	if d == null or typeof(d) != TYPE_DICTIONARY:
		_poison_end_ms = 0
		if debuff_icon: debuff_icon.visible = false
		return
	_poison_end_ms = int(d.get("poisonEndAt", 0))
	if server_now_ms > 0:
		_server_offset_ms = server_now_ms - Time.get_ticks_msec()
	print("[mob ", mob_id, "] set_debuff poisonEndAt=", _poison_end_ms, " now=", server_now_ms, " offset=", _server_offset_ms)
	_update_debuff_visible()

func _update_debuff_visible() -> void:
	if debuff_icon == null or not alive:
		return
	if _poison_end_ms <= 0:
		debuff_icon.visible = false
		return
	var server_now: int = Time.get_ticks_msec() + _server_offset_ms
	debuff_icon.visible = _poison_end_ms > server_now

func flash() -> void:
	_flash_t = 0.1
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)

func _process(delta: float) -> void:
	_glow_t += delta
	# DEBUG: skip _update_debuff_visible
	if debuff_icon:
		debuff_icon.modulate.a = 0.85 + 0.15 * sin(_glow_t * 5.0)
	if glow and glow.visible:
		var g_pulse: float = 0.5 + 0.4 * sin(_glow_t * 3.0)
		glow.modulate.a = g_pulse
		glow.rotation = _glow_t * 0.5
	if _highlight_ring and _highlight_ring.visible:
		_highlight_ring.modulate.a = 0.75 + 0.25 * sin(_glow_t * 4.5)
		var h_pulse: float = 1.0 + 0.1 * sin(_glow_t * 4.5)
		_highlight_ring.scale = Vector2(1.8 * h_pulse, 0.9 * h_pulse)
	if not alive:
		return
	_anim_t += delta
	sprite.frame = int(_anim_t * _anim_fps) % _anim_frames
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			sprite.modulate = Color(1, 1, 1, 1)
