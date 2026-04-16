# HUD: три иконочные кнопки в правом нижнем углу: Сумка, Персонаж, ×.
# Хоткеи: C (сумка), I (персонаж). Логика клавиш — в game.gd.
class_name Hud
extends CanvasLayer

signal character_button_pressed
signal bag_button_pressed
signal logout_button_pressed

const ICON_BAG := preload("res://assets/sprites/icon_bag.png")
const ICON_CHAR := preload("res://assets/sprites/icon_character.png")

const BTN_SIZE := 48
const BTN_GAP := 6

var character_btn: Button
var bag_btn: Button
var logout_btn: Button

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

	logout_btn = _make_icon_button(null, "×", Color(0.90, 0.45, 0.35), "Выйти")
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
		var r := TextureRect.new()
		r.texture = icon_tex
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.anchor_right = 1.0; r.anchor_bottom = 1.0
		r.offset_left = 4; r.offset_top = 4
		r.offset_right = -4; r.offset_bottom = -4
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(r)
	else:
		b.text = fallback_text
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", tint)
		b.add_theme_color_override("font_hover_color", Color(tint.r + 0.1, tint.g + 0.1, tint.b + 0.1))
	return b

# Совместимость со старыми вызовами.
func update_me(_me: Dictionary) -> void:
	pass
