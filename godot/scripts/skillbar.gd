# Нижняя панель из 5 слотов скиллов (1-5) с иконками, кулдаунами и подсветкой.
class_name SkillBar
extends CanvasLayer

signal skill_activated(index: int)

const SKILLS := [
	{ "name": "Меткий выстрел", "key": "1", "icon": "res://assets/sprites/skill_1.png", "cd": 5.0, "targets_mob": true,  "targets_ground": false },
	{ "name": "Ливень стрел",   "key": "2", "icon": "res://assets/sprites/skill_2.png", "cd": 12.0,"targets_mob": false, "targets_ground": true  },
	{ "name": "Отскок",         "key": "3", "icon": "res://assets/sprites/skill_3.png", "cd": 8.0, "targets_mob": false, "targets_ground": false },
	{ "name": "Отравленная стрела", "key": "4", "icon": "res://assets/sprites/skill_4.png", "cd": 6.0, "targets_mob": true,  "targets_ground": false },
	{ "name": "Призрачный залп","key": "5", "icon": "res://assets/sprites/skill_5.png", "cd": 15.0,"targets_mob": false, "targets_ground": true  },
]

var slots: Array = []
var cooldowns: Array = [0.0, 0.0, 0.0, 0.0, 0.0]

func _ready() -> void:
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -260
	root.offset_right = 260
	root.offset_top = -88
	root.offset_bottom = -16
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.anchor_right = 1.0
	hb.anchor_bottom = 1.0
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hb)

	for i in range(SKILLS.size()):
		var slot := _make_slot(i)
		hb.add_child(slot)
		slots.append(slot)

func _make_slot(i: int) -> Control:
	var sk: Dictionary = SKILLS[i]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(64, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.border_color = Color(0.45, 0.35, 0.20, 1.0)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)

	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(60, 60)
	panel.add_child(ctrl)

	var icon := TextureRect.new()
	var tex: Resource = load(sk["icon"])
	if tex:
		icon.texture = tex
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.anchor_right = 1.0; icon.anchor_bottom = 1.0
	icon.offset_left = 4; icon.offset_top = 4
	icon.offset_right = -4; icon.offset_bottom = -4
	ctrl.add_child(icon)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(dim)
	ctrl.set_meta("dim", dim)

	var cd_label := Label.new()
	cd_label.anchor_right = 1.0; cd_label.anchor_bottom = 1.0
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.add_theme_font_size_override("font_size", 22)
	cd_label.add_theme_color_override("font_color", Color(1, 1, 1))
	cd_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cd_label.add_theme_constant_override("outline_size", 4)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_label.visible = false
	ctrl.add_child(cd_label)
	ctrl.set_meta("cd_label", cd_label)

	var key_label := Label.new()
	key_label.text = sk["key"]
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	key_label.add_theme_constant_override("outline_size", 3)
	key_label.position = Vector2(4, 2)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(key_label)

	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			skill_activated.emit(i))
	return panel

func trigger_cooldown(index: int) -> void:
	if index < 0 or index >= SKILLS.size(): return
	cooldowns[index] = float(SKILLS[index]["cd"])

func _process(delta: float) -> void:
	for i in range(cooldowns.size()):
		if cooldowns[i] <= 0:
			_set_slot_cd(i, 0.0)
			continue
		cooldowns[i] = max(0.0, cooldowns[i] - delta)
		_set_slot_cd(i, cooldowns[i])

func _set_slot_cd(i: int, remaining: float) -> void:
	var slot: Control = slots[i]
	var ctrl := slot.get_child(0)
	var dim: ColorRect = ctrl.get_meta("dim")
	var lbl: Label = ctrl.get_meta("cd_label")
	if remaining > 0.01:
		dim.visible = true
		lbl.visible = true
		lbl.text = "%.0f" % ceil(remaining)
	else:
		dim.visible = false
		lbl.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event.keycode
		var idx := -1
		match key:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
			KEY_4: idx = 3
			KEY_5: idx = 4
		if idx >= 0:
			skill_activated.emit(idx)
