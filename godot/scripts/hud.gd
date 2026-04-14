# HUD: только две большие кнопки в правом нижнем углу — «Сумка» и
# «Персонаж». Инвентарь и золото живут в окне сумки и под миникартой.
class_name Hud
extends CanvasLayer

signal character_button_pressed
signal bag_button_pressed

var character_btn: Button
var bag_btn: Button

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
	bag_btn.offset_top = -54
	bag_btn.offset_right = -160
	bag_btn.offset_bottom = -10
	bag_btn.pressed.connect(func(): bag_button_pressed.emit())
	root.add_child(bag_btn)

	character_btn = _make_action_button("Персонаж")
	character_btn.anchor_left = 1.0
	character_btn.anchor_right = 1.0
	character_btn.anchor_top = 1.0
	character_btn.anchor_bottom = 1.0
	character_btn.offset_left = -150
	character_btn.offset_top = -54
	character_btn.offset_right = -10
	character_btn.offset_bottom = -10
	character_btn.pressed.connect(func(): character_button_pressed.emit())
	root.add_child(character_btn)

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
