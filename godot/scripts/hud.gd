# HUD: только две большие кнопки в правом нижнем углу — «Сумка» и
# «Персонаж». Инвентарь и золото живут в окне сумки и под миникартой.
class_name Hud
extends CanvasLayer

signal character_button_pressed
signal bag_button_pressed
signal logout_button_pressed

var character_btn: Button
var bag_btn: Button
var logout_btn: Button

func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	bag_btn = _make_action_button("Сумка")
	bag_btn.anchor_left = 1.0
	bag_btn.anchor_right = 1.0
	bag_btn.anchor_top = 1.0
	bag_btn.anchor_bottom = 1.0
	bag_btn.offset_left = -300
	bag_btn.offset_top = -98
	bag_btn.offset_right = -160
	bag_btn.offset_bottom = -54
	bag_btn.pressed.connect(func(): bag_button_pressed.emit())
	root.add_child(bag_btn)

	character_btn = _make_action_button("Персонаж")
	character_btn.anchor_left = 1.0
	character_btn.anchor_right = 1.0
	character_btn.anchor_top = 1.0
	character_btn.anchor_bottom = 1.0
	character_btn.offset_left = -150
	character_btn.offset_top = -98
	character_btn.offset_right = -10
	character_btn.offset_bottom = -54
	character_btn.pressed.connect(func(): character_button_pressed.emit())
	root.add_child(character_btn)

	logout_btn = Button.new()
	logout_btn.text = "×"
	logout_btn.tooltip_text = "Выйти из игры"
	logout_btn.add_theme_font_size_override("font_size", 20)
	logout_btn.add_theme_color_override("font_color", Color(0.90, 0.45, 0.35, 1))
	logout_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.40, 1))
	logout_btn.anchor_left = 1.0
	logout_btn.anchor_right = 1.0
	logout_btn.anchor_top = 1.0
	logout_btn.anchor_bottom = 1.0
	logout_btn.offset_left = -50
	logout_btn.offset_top = -46
	logout_btn.offset_right = -10
	logout_btn.offset_bottom = -10
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.08, 0.07, 1.0)
	sb_n.border_color = Color(0.45, 0.20, 0.18, 1.0)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(6)
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = Color(0.32, 0.12, 0.10, 1.0)
	sb_h.border_color = Color(0.85, 0.40, 0.32, 1.0)
	sb_h.set_border_width_all(1)
	sb_h.set_corner_radius_all(6)
	logout_btn.add_theme_stylebox_override("normal", sb_n)
	logout_btn.add_theme_stylebox_override("hover", sb_h)
	logout_btn.add_theme_stylebox_override("pressed", sb_h)
	logout_btn.add_theme_stylebox_override("focus", sb_h)
	logout_btn.pressed.connect(func(): logout_button_pressed.emit())
	root.add_child(logout_btn)

func _make_action_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 44)
	b.add_theme_font_size_override("font_size", 14)
	return b

# Совместимость со старыми вызовами — теперь HUD просто прокидывает
# обновление дальше: gold под миникарту, инвентарь — в bag_window.
# Сам HUD больше ничего не отображает.
func update_me(_me: Dictionary) -> void:
	pass
