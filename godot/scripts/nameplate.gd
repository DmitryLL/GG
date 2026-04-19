# Левый верхний угол: ник, HP-полоска, XP-полоска. Обновляется из OP_ME.
class_name Nameplate
extends CanvasLayer

signal logout_requested

var name_label: Label
var level_label: Label
var hp_text: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar

var target_panel: PanelContainer
var target_name: Label
var target_hp_bar: ProgressBar
var target_hp_text: Label

var effects_row: HBoxContainer
var target_effects: HBoxContainer
var server_time_offset_ms: int = 0
var current_effects: Array = []

const POISON_ICON := preload("res://assets/sprites/skills/skill_4.png")

func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 8
	panel.offset_top = 8
	panel.offset_right = 248
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.10, 1.0)
	sb.border_color = Color(0.35, 0.30, 0.20, 1.0)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)

	var class_icon := TextureRect.new()
	class_icon.texture = load("res://assets/sprites/skills/class_archer.png")
	class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_icon.custom_minimum_size = Vector2(24, 24)
	class_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(class_icon)

	name_label = Label.new()
	name_label.text = "—"
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	level_label = Label.new()
	level_label.text = "Ур. 1"
	level_label.add_theme_color_override("font_color", Color(0.99, 0.89, 0.51, 1))
	top.add_child(level_label)

	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(220, 14)
	var hp_fg := StyleBoxFlat.new()
	hp_fg.bg_color = Color(0.55, 0.85, 0.45, 1.0)
	hp_fg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", hp_fg)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.10, 0.10, 0.10, 1.0)
	hp_bg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	v.add_child(hp_bar)

	hp_text = Label.new()
	hp_text.text = "100 / 100"
	hp_text.add_theme_font_size_override("font_size", 10)
	hp_text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_text.add_theme_constant_override("outline_size", 3)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(hp_text)
	hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	xp_bar = ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = 50
	xp_bar.value = 0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(220, 6)
	var xp_fg := StyleBoxFlat.new()
	xp_fg.bg_color = Color(0.99, 0.78, 0.30, 1.0)
	xp_fg.set_corner_radius_all(2)
	xp_bar.add_theme_stylebox_override("fill", xp_fg)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.10, 0.10, 0.10, 1.0)
	xp_bg.set_corner_radius_all(2)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	v.add_child(xp_bar)

	effects_row = HBoxContainer.new()
	effects_row.add_theme_constant_override("separation", 2)
	effects_row.custom_minimum_size = Vector2(0, 26)
	effects_row.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(effects_row)

	# --- Target panel (right next to player panel) ---
	target_panel = PanelContainer.new()
	target_panel.anchor_left = 0.0
	target_panel.anchor_top = 0.0
	target_panel.offset_left = 256
	target_panel.offset_top = 8
	target_panel.offset_right = 496
	target_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	target_panel.visible = false
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.08, 0.08, 0.10, 1.0)
	tsb.border_color = Color(0.55, 0.22, 0.22, 1.0)
	tsb.border_width_left = 2; tsb.border_width_top = 2
	tsb.border_width_right = 2; tsb.border_width_bottom = 2
	tsb.set_corner_radius_all(6)
	tsb.set_content_margin_all(8)
	target_panel.add_theme_stylebox_override("panel", tsb)
	root.add_child(target_panel)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	target_panel.add_child(tv)

	target_name = Label.new()
	target_name.text = ""
	target_name.add_theme_font_size_override("font_size", 18)
	target_name.add_theme_color_override("font_color", Color(0.95, 0.65, 0.65))
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(target_name)

	target_hp_bar = ProgressBar.new()
	target_hp_bar.min_value = 0
	target_hp_bar.max_value = 100
	target_hp_bar.value = 100
	target_hp_bar.show_percentage = false
	target_hp_bar.custom_minimum_size = Vector2(220, 14)
	var thp_fg := StyleBoxFlat.new()
	thp_fg.bg_color = Color(0.85, 0.30, 0.30, 1.0)
	thp_fg.set_corner_radius_all(2)
	target_hp_bar.add_theme_stylebox_override("fill", thp_fg)
	var thp_bg := StyleBoxFlat.new()
	thp_bg.bg_color = Color(0.10, 0.10, 0.10, 1.0)
	thp_bg.set_corner_radius_all(2)
	target_hp_bar.add_theme_stylebox_override("background", thp_bg)
	tv.add_child(target_hp_bar)

	target_hp_text = Label.new()
	target_hp_text.text = ""
	target_hp_text.add_theme_font_size_override("font_size", 10)
	target_hp_text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	target_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	target_hp_text.add_theme_constant_override("outline_size", 3)
	target_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_hp_bar.add_child(target_hp_text)
	target_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	target_effects = HBoxContainer.new()
	target_effects.add_theme_constant_override("separation", 2)
	target_effects.custom_minimum_size = Vector2(0, 26)
	tv.add_child(target_effects)

const MOB_NAMES := { "slime": "Слайм", "goblin": "Гоблин", "dummy": "Манекен" }

func update_target(target) -> void:
	if target == null or not is_instance_valid(target):
		target_panel.visible = false
		return
	target_panel.visible = true
	_clear_target_effects()
	# Mob или Player — у обоих есть kind или display_name
	if "kind" in target:
		# Mob
		target_name.text = MOB_NAMES.get(target.kind, target.kind.capitalize())
		target_name.add_theme_color_override("font_color", Color(0.95, 0.65, 0.65))
		target_hp_bar.max_value = target.hp_max
		target_hp_bar.value = target.hp
		target_hp_text.text = "%d / %d" % [int(target.hp), int(target.hp_max)]
		if target.has_method("poison_active") and target.poison_active():
			var remain_ms: int = target.poison_remaining_ms()
			target_effects.add_child(_make_target_effect_icon("poison", remain_ms))
	elif "display_name" in target:
		# Player (PvP)
		target_name.text = target.display_name
		target_name.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		target_hp_bar.max_value = target.hp_max
		target_hp_bar.value = target.hp
		target_hp_text.text = "%d / %d" % [int(target.hp), int(target.hp_max)]

func _clear_target_effects() -> void:
	if target_effects == null: return
	for c in target_effects.get_children():
		c.queue_free()

func _make_target_effect_icon(eff_type: String, remain_ms: int) -> Control:
	var col := Color(0.95, 0.30, 0.28, 1.0)  # debuff red
	var wrap := Panel.new()
	wrap.custom_minimum_size = Vector2(20, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	wrap.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = POISON_ICON if eff_type == "poison" else null
	icon.custom_minimum_size = Vector2(16, 16)
	icon.position = Vector2(2, 1)
	icon.size = Vector2(16, 16)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(icon)
	var timer_lbl := Label.new()
	timer_lbl.text = ("%.1fс" % (remain_ms / 1000.0)) if remain_ms < 10000 else ("%dс" % int(remain_ms / 1000))
	timer_lbl.add_theme_font_size_override("font_size", 7)
	timer_lbl.add_theme_color_override("font_color", col)
	timer_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	timer_lbl.add_theme_constant_override("outline_size", 2)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.position = Vector2(0, 17)
	timer_lbl.size = Vector2(20, 9)
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(timer_lbl)
	return wrap

func set_player_name(n: String) -> void:
	name_label.text = n

func update_me(me: Dictionary) -> void:
	level_label.text = "Ур. %d" % int(me.get("level", 1))
	var hp: int = int(me.get("hp", 0))
	var hp_max: int = int(me.get("hpMax", 100))
	hp_bar.max_value = float(hp_max)
	hp_bar.value = float(hp)
	hp_text.text = "%d / %d" % [hp, hp_max]
	xp_bar.max_value = float(me.get("xpNeed", 50))
	xp_bar.value = float(me.get("xp", 0))
	if me.has("t"):
		server_time_offset_ms = int(me["t"]) - Time.get_ticks_msec()
	current_effects = me.get("effects", [])
	_rebuild_effects()

const _EFFECT_META := {
	"poison": { "name": "Яд", "desc": "Урон со временем" },
	"heal":   { "name": "Лечение", "desc": "Восстановление здоровья" },
}

func _rebuild_effects() -> void:
	if effects_row == null:
		return
	for c in effects_row.get_children():
		c.queue_free()
	for eff in current_effects:
		effects_row.add_child(_make_effect_icon(eff))

func _make_effect_icon(eff: Dictionary) -> Control:
	var kind := String(eff.get("kind", "buff"))
	var eff_type := String(eff.get("type", ""))
	var is_buff := kind == "buff"
	var col: Color = Color(0.30, 0.85, 0.35, 1.0) if is_buff else Color(0.95, 0.30, 0.28, 1.0)

	var wrap := Panel.new()
	wrap.custom_minimum_size = Vector2(20, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	wrap.add_theme_stylebox_override("panel", sb)

	var tex_path := "res://assets/sprites/ui/effect_%s.png" % eff_type
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)

	var icon := TextureRect.new()
	if tex:
		icon.texture = tex
	icon.custom_minimum_size = Vector2(16, 16)
	icon.position = Vector2(2, 1)
	icon.size = Vector2(16, 16)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(icon)

	var timer_lbl := Label.new()
	timer_lbl.name = "Timer"
	timer_lbl.text = ""
	timer_lbl.add_theme_font_size_override("font_size", 7)
	timer_lbl.add_theme_color_override("font_color", col)
	timer_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	timer_lbl.add_theme_constant_override("outline_size", 2)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.position = Vector2(0, 17)
	timer_lbl.size = Vector2(20, 9)
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(timer_lbl)

	var stacks := int(eff.get("stacks", 0))
	if stacks > 1:
		var stack_lbl := Label.new()
		stack_lbl.text = "×%d" % stacks
		stack_lbl.add_theme_font_size_override("font_size", 7)
		stack_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		stack_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		stack_lbl.add_theme_constant_override("outline_size", 2)
		stack_lbl.position = Vector2(11, -1)
		stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(stack_lbl)

	wrap.set_meta("end_at", int(eff.get("endAt", 0)))
	var meta: Dictionary = _EFFECT_META.get(eff_type, {"name": eff_type, "desc": ""})
	wrap.tooltip_text = "%s — %s" % [meta.get("name", eff_type), meta.get("desc", "")]
	return wrap

func _process(_delta: float) -> void:
	if effects_row == null:
		return
	var server_now: int = Time.get_ticks_msec() + server_time_offset_ms
	var need_rebuild := false
	for child in effects_row.get_children():
		if not (child is Panel):
			continue
		var end_at: int = int(child.get_meta("end_at", 0))
		var remain_ms: int = end_at - server_now
		if remain_ms <= 0:
			need_rebuild = true
			continue
		var timer_lbl: Label = child.get_node_or_null("Timer")
		if timer_lbl:
			var secs: float = remain_ms / 1000.0
			timer_lbl.text = ("%.1fс" % secs) if secs < 10.0 else ("%dс" % int(secs))
	if need_rebuild:
		var filtered: Array = []
		for eff in current_effects:
			if int(eff.get("endAt", 0)) > server_now:
				filtered.append(eff)
		current_effects = filtered
		_rebuild_effects()
