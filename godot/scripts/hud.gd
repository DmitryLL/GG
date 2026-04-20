# HUD: три иконочные кнопки в правом нижнем углу: Сумка, Персонаж, ×.
# Хоткеи: C (сумка), I (персонаж). Логика клавиш — в game.gd.
class_name Hud
extends CanvasLayer

signal character_button_pressed
signal bag_button_pressed
signal logout_button_pressed
signal admin_button_pressed
signal stats_button_pressed
signal skills_button_pressed
signal actions_button_pressed
signal actions_mode_changed(on: bool)

const ICON_BAG := preload("res://assets/sprites/ui/icon_bag.png")
const ICON_CHAR := preload("res://assets/sprites/ui/icon_character.png")
const ICON_ADMIN := preload("res://assets/sprites/ui/icon_admin.png")
const ICON_STATS := preload("res://assets/sprites/ui/icon_stats.png")

const BTN_SIZE := 48
const BTN_GAP := 6

var character_btn: Button
var bag_btn: Button
var logout_btn: Button
var admin_btn: Button
var stats_btn: Button
var skills_btn: Button
var actions_btn: Button
var actions_mode: bool = false

func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Справа налево: × (logout), персонаж, сумка
	var x_right: int = -10
	var y_top: int = -58
	var y_bottom: int = -10

	logout_btn = _make_icon_button(null, "×", Color(0.90, 0.45, 0.35), "Выйти к выбору персонажа")
	logout_btn.anchor_left = 1.0; logout_btn.anchor_right = 1.0
	logout_btn.anchor_top = 1.0; logout_btn.anchor_bottom = 1.0
	logout_btn.offset_right = x_right
	logout_btn.offset_left = x_right - BTN_SIZE
	logout_btn.offset_top = y_top
	logout_btn.offset_bottom = y_bottom
	logout_btn.pressed.connect(func(): logout_button_pressed.emit())
	root.add_child(logout_btn)

	character_btn = _make_icon_button(ICON_CHAR, "", Color(0.95, 0.85, 0.55), "Персонаж (I)")
	character_btn.anchor_left = 1.0; character_btn.anchor_right = 1.0
	character_btn.anchor_top = 1.0; character_btn.anchor_bottom = 1.0
	var char_right: int = x_right - BTN_SIZE - BTN_GAP
	character_btn.offset_right = char_right
	character_btn.offset_left = char_right - BTN_SIZE
	character_btn.offset_top = y_top
	character_btn.offset_bottom = y_bottom
	character_btn.pressed.connect(func(): character_button_pressed.emit())
	root.add_child(character_btn)

	bag_btn = _make_icon_button(ICON_BAG, "", Color(0.95, 0.75, 0.45), "Сумка (C)")
	bag_btn.anchor_left = 1.0; bag_btn.anchor_right = 1.0
	bag_btn.anchor_top = 1.0; bag_btn.anchor_bottom = 1.0
	var bag_right: int = char_right - BTN_SIZE - BTN_GAP
	bag_btn.offset_right = bag_right
	bag_btn.offset_left = bag_right - BTN_SIZE
	bag_btn.offset_top = y_top
	bag_btn.offset_bottom = y_bottom
	bag_btn.pressed.connect(func(): bag_button_pressed.emit())
	root.add_child(bag_btn)

	# «Параметры» — слева от сумки.
	stats_btn = _make_icon_button(ICON_STATS, "", Color(0.85, 0.95, 1.00), "Параметры (P)")
	stats_btn.anchor_left = 1.0; stats_btn.anchor_right = 1.0
	stats_btn.anchor_top = 1.0; stats_btn.anchor_bottom = 1.0
	var stats_right: int = bag_right - BTN_SIZE - BTN_GAP
	stats_btn.offset_right = stats_right
	stats_btn.offset_left = stats_right - BTN_SIZE
	stats_btn.offset_top = y_top
	stats_btn.offset_bottom = y_bottom
	stats_btn.pressed.connect(func(): stats_button_pressed.emit())
	root.add_child(stats_btn)

	# «Скиллы» — слева от параметров. Иконка — процедурная звезда
	# (Polygon2D), пока Вова не добавит финальный спрайт.
	skills_btn = _make_icon_button(null, "", Color(0.95, 0.90, 0.55), "Скиллы (K)")
	_decorate_skills_button(skills_btn)
	skills_btn.anchor_left = 1.0; skills_btn.anchor_right = 1.0
	skills_btn.anchor_top = 1.0; skills_btn.anchor_bottom = 1.0
	var skills_right: int = stats_right - BTN_SIZE - BTN_GAP
	skills_btn.offset_right = skills_right
	skills_btn.offset_left = skills_right - BTN_SIZE
	skills_btn.offset_top = y_top
	skills_btn.offset_bottom = y_bottom
	skills_btn.pressed.connect(func(): skills_button_pressed.emit())
	root.add_child(skills_btn)

	# «Действия с игроками» — toggle-режим; по нажатию клики в мире
	# становятся «дружественными» (пригласить в группу / ЛС).
	actions_btn = _make_icon_button(null, "", Color(0.55, 0.95, 0.70), "Действия с игроками")
	_decorate_actions_button(actions_btn)
	actions_btn.anchor_left = 1.0; actions_btn.anchor_right = 1.0
	actions_btn.anchor_top = 1.0; actions_btn.anchor_bottom = 1.0
	var actions_right: int = skills_right - BTN_SIZE - BTN_GAP
	actions_btn.offset_right = actions_right
	actions_btn.offset_left = actions_right - BTN_SIZE
	actions_btn.offset_top = y_top
	actions_btn.offset_bottom = y_bottom
	actions_btn.pressed.connect(func():
		actions_mode = not actions_mode
		_refresh_actions_style()
		actions_mode_changed.emit(actions_mode)
		actions_button_pressed.emit()
	)
	root.add_child(actions_btn)

	# Админская кнопка — над × (видна только админам).
	admin_btn = _make_icon_button(ICON_ADMIN, "", Color(0.70, 0.85, 1.00), "Админка (`)")
	admin_btn.anchor_left = 1.0; admin_btn.anchor_right = 1.0
	admin_btn.anchor_top = 1.0; admin_btn.anchor_bottom = 1.0
	var admin_y_top: int = y_top - BTN_SIZE - BTN_GAP
	var admin_y_bottom: int = y_bottom - BTN_SIZE - BTN_GAP
	admin_btn.offset_right = x_right
	admin_btn.offset_left = x_right - BTN_SIZE
	admin_btn.offset_top = admin_y_top
	admin_btn.offset_bottom = admin_y_bottom
	admin_btn.pressed.connect(func(): admin_button_pressed.emit())
	admin_btn.visible = false  # покажется если Session.is_admin(), вызывает game.gd
	root.add_child(admin_btn)

func set_admin_visible(on: bool) -> void:
	if admin_btn:
		admin_btn.visible = on

func _refresh_actions_style() -> void:
	if actions_btn == null: return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.35, 0.15, 1.0) if actions_mode else Color(0.12, 0.10, 0.07, 1.0)
	sb.border_color = Color(0.55, 1.0, 0.55, 1.0) if actions_mode else Color(0.45, 0.35, 0.20, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	actions_btn.add_theme_stylebox_override("normal", sb)
	actions_btn.add_theme_stylebox_override("hover", sb)

func reset_actions_mode() -> void:
	actions_mode = false
	_refresh_actions_style()

# Пятиконечная звезда по центру кнопки «Скиллы» — процедурный Polygon2D,
# чтобы не заводить PNG. Заменить на готовый спрайт, когда Вова сделает
# `icon_skills.png` в `godot/assets/sprites/ui/`.
func _decorate_skills_button(btn: Button) -> void:
	var holder := Control.new()
	holder.anchor_right = 1.0; holder.anchor_bottom = 1.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(holder)
	var star := Polygon2D.new()
	var cx := float(BTN_SIZE) * 0.5
	var cy := float(BTN_SIZE) * 0.5
	var rOut := 18.0
	var rIn := 7.0
	var pts := PackedVector2Array()
	for i in range(10):
		var r: float = rOut if (i % 2 == 0) else rIn
		var a: float = -PI / 2.0 + float(i) * PI / 5.0
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	star.polygon = pts
	star.color = Color(0.98, 0.85, 0.35, 1.0)
	# Мягкая обводка через второй polygon сверху чуть меньше.
	var glow := Polygon2D.new()
	var pts2 := PackedVector2Array()
	for p in pts: pts2.append((p - Vector2(cx, cy)) * 1.12 + Vector2(cx, cy))
	glow.polygon = pts2
	glow.color = Color(0.60, 0.40, 0.10, 0.35)
	holder.add_child(glow)
	holder.add_child(star)

# Две стилизованные фигуры (голова + тело) для кнопки «Действия».
# Сигнализирует «взаимодействие с игроками». Тоже Polygon2D.
func _decorate_actions_button(btn: Button) -> void:
	var holder := Control.new()
	holder.anchor_right = 1.0; holder.anchor_bottom = 1.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(holder)
	var col := Color(0.60, 0.95, 0.70, 1.0)
	var col_dim := Color(0.35, 0.75, 0.50, 1.0)
	# Правая фигура.
	_draw_person(holder, Vector2(34, 22), 7.0, col, 14.0, 14.0)
	# Левая (чуть глубже, темнее — для плоского эффекта глубины).
	_draw_person(holder, Vector2(18, 26), 6.5, col_dim, 13.0, 12.0)

func _draw_person(holder: Control, center_head: Vector2, head_r: float, col: Color, body_w: float, body_h: float) -> void:
	var head := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = float(i) * TAU / 16.0
		pts.append(center_head + Vector2(cos(a) * head_r, sin(a) * head_r))
	head.polygon = pts
	head.color = col
	holder.add_child(head)
	var body := Polygon2D.new()
	# Трапеция плеч.
	var bx: float = center_head.x
	var by: float = center_head.y + head_r
	body.polygon = PackedVector2Array([
		Vector2(bx - body_w * 0.5 - 2.0, by + body_h),
		Vector2(bx - body_w * 0.5, by + 2.0),
		Vector2(bx + body_w * 0.5, by + 2.0),
		Vector2(bx + body_w * 0.5 + 2.0, by + body_h),
	])
	body.color = col
	holder.add_child(body)

func _make_icon_button(icon_tex: Texture2D, fallback_text: String, tint: Color, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.10, 0.07, 1.0)
	sb_n.border_color = Color(0.45, 0.35, 0.20, 1.0)
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(6)
	sb_n.set_content_margin_all(0)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.22, 0.16, 0.10, 1.0)
	sb_h.border_color = Color(0.95, 0.75, 0.35, 1.0)
	var sb_p := sb_h.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.30, 0.22, 0.14, 1.0)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("focus", sb_n)

	if icon_tex:
		# CenterContainer растягивается на всю кнопку, ребёнок центрируется.
		var cc := CenterContainer.new()
		cc.anchor_right = 1.0; cc.anchor_bottom = 1.0
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cc)
		var r := TextureRect.new()
		r.texture = icon_tex
		r.custom_minimum_size = Vector2(40, 40)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(r)
	else:
		b.text = fallback_text
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", tint)
		b.add_theme_color_override("font_hover_color", Color(tint.r + 0.1, tint.g + 0.1, tint.b + 0.1))
	return b

# Совместимость со старыми вызовами.
func update_me(_me: Dictionary) -> void:
	pass
