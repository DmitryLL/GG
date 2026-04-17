# Маленькая горизонтальная полоса индикаторов эффектов.
# Зелёная рамка = баф, красная = дебаф. Иконки 10×10, всё внутри Control.
class_name EffectBar
extends Control

const POISON_ICON := preload("res://assets/sprites/skill_4.png")
const HEAL_ICON_PATH := "res://assets/sprites/ui/effect_heal.png"

const ICON_SIZE := 10
const BORDER := 1
const GAP := 2
const SLOT_W := ICON_SIZE + BORDER * 2
const SLOT_H := ICON_SIZE + BORDER * 2

var _server_offset_ms: int = 0
var _active: Array = []  # [{slot: Panel, end_at: int}]

func _init() -> void:
	custom_minimum_size = Vector2(0, SLOT_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_effects(effects: Array, server_now_ms: int) -> void:
	if server_now_ms > 0:
		_server_offset_ms = server_now_ms - Time.get_ticks_msec()
	for c in get_children():
		c.queue_free()
	_active.clear()
	var x: int = 0
	for e in effects:
		if not (e is Dictionary):
			continue
		var eff: Dictionary = e
		var slot := _make_slot(eff)
		slot.position = Vector2(x, 0)
		add_child(slot)
		_active.append({"slot": slot, "end_at": int(eff.get("endAt", 0))})
		x += SLOT_W + GAP

func _make_slot(eff: Dictionary) -> Panel:
	var is_buff := String(eff.get("kind", "")) == "buff"
	var col := Color(0.30, 0.85, 0.35, 1.0) if is_buff else Color(0.95, 0.30, 0.28, 1.0)
	var p := Panel.new()
	p.size = Vector2(SLOT_W, SLOT_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	sb.border_color = col
	sb.set_border_width_all(BORDER)
	sb.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = _icon_for(String(eff.get("type", "")))
	if tex:
		var r := TextureRect.new()
		r.texture = tex
		r.size = Vector2(ICON_SIZE, ICON_SIZE)
		r.position = Vector2(BORDER, BORDER)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(r)
	return p

func _icon_for(eff_type: String) -> Texture2D:
	match eff_type:
		"poison":
			return POISON_ICON
		"heal":
			if ResourceLoader.exists(HEAL_ICON_PATH):
				return load(HEAL_ICON_PATH)
	return null

func _process(_delta: float) -> void:
	if _active.is_empty():
		return
	var server_now: int = Time.get_ticks_msec() + _server_offset_ms
	for entry in _active:
		var slot: Panel = entry["slot"]
		if slot == null or not is_instance_valid(slot):
			continue
		var end_at: int = int(entry["end_at"])
		if end_at > 0 and end_at <= server_now:
			slot.visible = false

# Превратить mob.debuff → единый формат эффектов.
static func effects_from_mob_debuff(d) -> Array:
	if d == null or typeof(d) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	var poison_end: int = int(d.get("poisonEndAt", 0))
	if poison_end > 0:
		out.append({"kind": "debuff", "type": "poison", "endAt": poison_end})
	return out
