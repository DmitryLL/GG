# Окно сумки: 6 ячеек инвентаря + текущее золото. Клик по предмету —
# одеть/использовать (как было в HUD).
class_name BagWindow
extends CanvasLayer

signal use_or_equip(slot_index: int)
signal closed

const ITEMS_TEX := preload("res://assets/sprites/items.png")

var overlay: ColorRect
var card: PanelContainer
var gold_label: Label
var inv_buttons: Array[Button] = []
var last_me: Dictionary = {}

func _ready() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.visible = false

	card = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -210
	card.offset_top = -240
	card.offset_right = 210
	card.offset_bottom = 240
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.09, 0.08, 1.0)
	card_sb.border_color = Color(0.65, 0.50, 0.20, 1.0)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(8)
	card_sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", card_sb)
	overlay.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "Сумка"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(36, 32)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	v.add_child(HSeparator.new())

	# Золото — крупно
	var gold_row := HBoxContainer.new()
	v.add_child(gold_row)
	var gold_title := Label.new()
	gold_title.text = "Золото"
	gold_title.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50, 1))
	gold_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(gold_title)
	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", Color(0.99, 0.85, 0.45))
	gold_row.add_child(gold_label)

	v.add_child(HSeparator.new())

	# Инвентарь — 25 ячеек, 5×5
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for i in range(25):
		var b := _make_slot_button()
		var idx := i
		b.pressed.connect(func(): use_or_equip.emit(idx))
		inv_buttons.append(b)
		grid.add_child(b)

	# Подсказка
	var hint := Label.new()
	hint.text = "Клик по предмету — одеть или выпить"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.50, 0.42, 1))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

func _make_slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(50, 50)
	var sb_n := _slot_sb(false)
	var sb_h := _slot_sb(true)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.add_theme_stylebox_override("focus", sb_h)
	return b

func _slot_sb(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.05, 1.0)
	sb.border_color = Color(0.65, 0.50, 0.20, 1.0) if hover else Color(0.30, 0.24, 0.16, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	return sb

func _set_slot_icon(btn: Button, item_id: String, qty: int) -> void:
	for c in btn.get_children():
		c.queue_free()
	if item_id == "":
		btn.tooltip_text = ""
		return
	var def: Dictionary = Items.def(item_id)
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	var icon := TextureRect.new()
	icon.texture = at
	icon.custom_minimum_size = Vector2(38, 38)
	icon.size = Vector2(38, 38)
	icon.position = Vector2(6, 6)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	if qty > 1:
		var q := Label.new()
		q.text = str(qty)
		q.position = Vector2(28, 28)
		q.add_theme_color_override("font_color", Color.WHITE)
		q.add_theme_color_override("font_outline_color", Color.BLACK)
		q.add_theme_constant_override("outline_size", 3)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(q)
	btn.tooltip_text = String(def.get("name", item_id))

func open(me: Dictionary) -> void:
	overlay.visible = true
	refresh(me)

func close() -> void:
	overlay.visible = false
	closed.emit()

func is_open() -> bool:
	return overlay.visible

func refresh(me: Dictionary) -> void:
	last_me = me
	if not overlay.visible:
		return
	gold_label.text = "%d" % int(me.get("gold", 0))
	var inv: Array = me.get("inv", [])
	for i in range(25):
		if i < inv.size():
			var e: Dictionary = inv[i]
			_set_slot_icon(inv_buttons[i], String(e.get("itemId", "")), int(e.get("qty", 1)))
		else:
			_set_slot_icon(inv_buttons[i], "", 0)
