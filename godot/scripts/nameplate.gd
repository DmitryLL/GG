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
	sb.bg_color = Color(0, 0, 0, 0.65)
	sb.set_corner_radius_all(4)
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
	var items_tex: Texture2D = load("res://assets/sprites/items.png")
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = items_tex
	atlas_tex.region = Rect2(96, 0, 16, 16)
	class_icon.texture = atlas_tex
	class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_icon.custom_minimum_size = Vector2(20, 20)
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
	tsb.bg_color = Color(0, 0, 0, 0.65)
	tsb.set_corner_radius_all(4)
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

const MOB_NAMES := { "slime": "Слайм", "goblin": "Гоблин", "dummy": "Манекен" }

func update_target(mob) -> void:
	if mob == null or not is_instance_valid(mob):
		target_panel.visible = false
		return
	target_panel.visible = true
	target_name.text = MOB_NAMES.get(mob.kind, mob.kind.capitalize())
	target_hp_bar.max_value = mob.hp_max
	target_hp_bar.value = mob.hp
	target_hp_text.text = "%d / %d" % [int(mob.hp), int(mob.hp_max)]

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
