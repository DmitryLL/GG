# Нижняя панель 5 слотов скиллов (1-5). Клик мышкой или хоткей 1..5.
class_name SkillBar
extends CanvasLayer

const SkillRegistry = preload("res://scripts/skills/skill_registry.gd")
const SkillDef = preload("res://scripts/skills/skill_def.gd")
signal skill_activated(index: int)

var SKILLS: Array = []

func _build_skills_list() -> void:
	SKILLS.clear()
	var defs: Array = SkillRegistry.all()
	for i in range(defs.size()):
		var d: SkillDef = defs[i]
		SKILLS.append({
			"name": d.display_name,
			"key": str(i + 1),
			"icon": d.icon_path,
			"cd": d.cooldown,
			"targets_mob": d.targets_mob,
			"targets_ground": d.targets_ground,
			"def": d,
		})

const SLOT_SIZE := 72
const SLOT_GAP := 8

var slots: Array = []
var cooldowns: Array = []

func _ready() -> void:
	_build_skills_list()
	cooldowns.resize(SKILLS.size())
	for i in range(cooldowns.size()):
		cooldowns[i] = 0.0

	var root := Control.new()
	root.anchor_left = 0.0
	root.anchor_right = 1.0
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bar_width: int = SKILLS.size() * SLOT_SIZE + (SKILLS.size() - 1) * SLOT_GAP + 16
	var bar_height: int = SLOT_SIZE + 16

	# Панель-подложка (центрированная снизу)
	var bg := PanelContainer.new()
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = -bar_width / 2
	bg.offset_right = bar_width / 2
	bg.offset_top = -(bar_height + 14)
	bg.offset_bottom = -14
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	bg_sb.border_color = Color(0.55, 0.42, 0.24, 0.85)
	bg_sb.border_width_left = 2; bg_sb.border_width_top = 2
	bg_sb.border_width_right = 2; bg_sb.border_width_bottom = 2
	bg_sb.set_corner_radius_all(10)
	bg_sb.set_content_margin_all(8)
	bg.add_theme_stylebox_override("panel", bg_sb)
	root.add_child(bg)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", SLOT_GAP)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(hb)

	for i in range(SKILLS.size()):
		var slot := _make_slot(i)
		hb.add_child(slot)
		slots.append(slot)

func _make_slot(i: int) -> Control:
	var sk: Dictionary = SKILLS[i]

	# Кнопка — нативный клик без велосипеда с gui_input
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.flat = false

	# Стиль кнопки — тёмный фон с рамкой
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.18, 0.12, 0.08, 1.0)
	normal_sb.border_color = Color(0.45, 0.32, 0.18, 1.0)
	normal_sb.border_width_left = 2; normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2; normal_sb.border_width_bottom = 2
	normal_sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.border_color = Color(0.95, 0.75, 0.35, 1.0)
	btn.add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb := normal_sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = Color(0.25, 0.18, 0.10, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	var disabled_sb := normal_sb.duplicate() as StyleBoxFlat
	disabled_sb.bg_color = Color(0.10, 0.08, 0.06, 1.0)
	btn.add_theme_stylebox_override("disabled", disabled_sb)

	btn.pressed.connect(func(): skill_activated.emit(i))

	# Иконка — центрирована, пропорциональная
	var icon := ColorRect.new()
	icon.color = Color.from_hsv(float(i) / max(1.0, float(SKILLS.size())), 0.55, 0.9)
	icon.anchor_right = 1.0; icon.anchor_bottom = 1.0
	icon.offset_left = 12; icon.offset_top = 12
	icon.offset_right = -12; icon.offset_bottom = -12
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# Затемнение во время кулдауна
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(dim)
	btn.set_meta("dim", dim)

	# Цифра cooldown — крупная по центру
	var cd_label := Label.new()
	cd_label.anchor_right = 1.0; cd_label.anchor_bottom = 1.0
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.add_theme_font_size_override("font_size", 28)
	cd_label.add_theme_color_override("font_color", Color(1, 1, 1))
	cd_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cd_label.add_theme_constant_override("outline_size", 4)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_label.visible = false
	btn.add_child(cd_label)
	btn.set_meta("cd_label", cd_label)

	# Хоткей снизу справа
	var key_label := Label.new()
	key_label.text = sk["key"]
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	key_label.add_theme_constant_override("outline_size", 3)
	key_label.anchor_left = 1.0; key_label.anchor_top = 1.0
	key_label.anchor_right = 1.0; key_label.anchor_bottom = 1.0
	key_label.offset_left = -14; key_label.offset_top = -18
	key_label.offset_right = -4; key_label.offset_bottom = -2
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(key_label)

	# Тултип с названием скилла
	btn.tooltip_text = String(sk["name"])

	return btn

# Server-authoritative cooldowns. Клиент хранит absolute endAt (серверное
# ms timestamp) и пересчитывает remaining от server_time = local_ticks +
# server_offset_ms. При сворачивании вкладки tickи останавливаются, но
# возврат в таб даёт актуальное remaining благодаря server-time формуле.
var cd_ends_at: Array = []       # server-ms when each skill CD expires
var server_offset_ms: int = 0    # server_now = Time.get_ticks_msec() + this

func trigger_cooldown(index: int) -> void:
	# Локальное предсказание (мгновенный визуальный отклик до прихода OP_ME).
	# Сервер пришлёт точный skillCd через update_skill_cd().
	if index < 0 or index >= SKILLS.size(): return
	if cd_ends_at.size() < SKILLS.size():
		cd_ends_at.resize(SKILLS.size())
	var server_now: int = Time.get_ticks_msec() + server_offset_ms
	cd_ends_at[index] = server_now + int(float(SKILLS[index]["cd"]) * 1000.0)
	cooldowns[index] = float(SKILLS[index]["cd"])

func update_skill_cd(skill_cd: Dictionary, server_t: int) -> void:
	# Вызывается из game._apply_me при каждом OP_ME.
	# skill_cd: {"1": server_ms_end, "2": ...} — server_id → absolute ms.
	if cd_ends_at.size() < SKILLS.size():
		cd_ends_at.resize(SKILLS.size())
	if server_t > 0:
		server_offset_ms = server_t - Time.get_ticks_msec()
	for i in range(SKILLS.size()):
		var sid: int = i + 1  # server_id = slot index + 1
		var end_at: int = int(skill_cd.get(str(sid), skill_cd.get(sid, 0)))
		cd_ends_at[i] = end_at

func _process(_delta: float) -> void:
	var server_now: int = Time.get_ticks_msec() + server_offset_ms
	for i in range(cooldowns.size()):
		var end_at: int = 0
		if i < cd_ends_at.size():
			end_at = int(cd_ends_at[i])
		var remain_ms: int = max(0, end_at - server_now)
		cooldowns[i] = remain_ms / 1000.0
		_set_slot_cd(i, cooldowns[i])

func _set_slot_cd(i: int, remaining: float) -> void:
	var btn: Button = slots[i]
	var dim: ColorRect = btn.get_meta("dim")
	var lbl: Label = btn.get_meta("cd_label")
	if remaining > 0.01:
		dim.visible = true
		lbl.visible = true
		lbl.text = "%.0f" % ceil(remaining)
	else:
		dim.visible = false
		lbl.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		var idx := -1
		match key:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
			KEY_4: idx = 3
			KEY_5: idx = 4
		if idx >= 0:
			skill_activated.emit(idx)
