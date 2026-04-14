# HUD: золото + 6 ячеек инвентаря + кнопка «Персонаж» (открывает окно с
# куклой и слотами экипировки). Equip-слоты live в окне персонажа,
# здесь их нет.
class_name Hud
extends CanvasLayer

signal equip_slot_clicked(index: int)
signal character_button_pressed

const ITEMS_TEX := preload("res://assets/sprites/items.png")

var gold_label: Label
var inv_buttons: Array[Button] = []
var character_btn: Button

func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -260
	panel.offset_top = 170
	panel.offset_right = -6
	panel.offset_bottom = 320
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	gold_label = Label.new()
	gold_label.text = "0 зол."
	gold_label.add_theme_color_override("font_color", Color(0.99, 0.89, 0.51, 1))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(gold_label)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for i in range(6):
		var b := _make_slot_button()
		var index := i
		b.pressed.connect(func(): equip_slot_clicked.emit(index))
		inv_buttons.append(b)
		grid.add_child(b)

	# Большая кнопка «Персонаж» в правом нижнем углу.
	character_btn = Button.new()
	character_btn.text = "Персонаж"
	character_btn.custom_minimum_size = Vector2(140, 44)
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

func _make_slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(36, 36)
	b.flat = true
	b.add_theme_stylebox_override("normal", _slot_sb(false))
	b.add_theme_stylebox_override("hover", _slot_sb(true))
	b.add_theme_stylebox_override("pressed", _slot_sb(true))
	return b

func _slot_sb(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(0.54, 0.55, 0.6, 1) if hover else Color(0.2, 0.2, 0.23, 1)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb

func _set_slot_icon(btn: Button, item_id: String, qty: int = 0) -> void:
	for c in btn.get_children():
		c.queue_free()
	if item_id == "":
		btn.tooltip_text = ""
		return
	var def: Dictionary = Items.def(item_id)
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.position = Vector2(4, 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	icon.texture = at
	btn.add_child(icon)
	if qty > 1:
		var q := Label.new()
		q.text = str(qty)
		q.position = Vector2(18, 18)
		q.add_theme_color_override("font_color", Color.WHITE)
		q.add_theme_color_override("font_outline_color", Color.BLACK)
		q.add_theme_constant_override("outline_size", 3)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(q)
	btn.tooltip_text = String(def.get("name", item_id))

func update_me(me: Dictionary) -> void:
	gold_label.text = "%d зол." % int(me.get("gold", 0))
	var inv: Array = me.get("inv", [])
	for i in range(6):
		if i < inv.size():
			var e: Dictionary = inv[i]
			_set_slot_icon(inv_buttons[i], String(e.get("itemId", "")), int(e.get("qty", 1)))
		else:
			_set_slot_icon(inv_buttons[i], "")
