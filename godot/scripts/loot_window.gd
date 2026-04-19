# Окно лута — открывается по клику на труп моба. Список вещей, кнопка
# «Взять» рядом с каждой и «Взять всё». Закрытие — × или Esc.
class_name LootWindow
extends CanvasLayer

signal take_requested(mob_id: String, index: int)
signal take_all_requested(mob_id: String)
signal closed

const ITEMS_TEX := preload("res://assets/sprites/items/items.png")

var overlay: ColorRect
var card: PanelContainer
var title_label: Label
var list_box: VBoxContainer
var take_all_btn: Button
var current_mob_id: String = ""

func _ready() -> void:
	layer = 10
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	card = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -180
	card.offset_top = -160
	card.offset_right = 180
	card.offset_bottom = 160
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.08, 1.0)
	sb.border_color = Color(0.65, 0.50, 0.20, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	overlay.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	title_label = Label.new()
	title_label.text = "Труп"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	v.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)

	take_all_btn = Button.new()
	take_all_btn.text = "Забрать всё"
	take_all_btn.pressed.connect(func():
		if current_mob_id != "":
			take_all_requested.emit(current_mob_id))
	v.add_child(take_all_btn)

func _input(event: InputEvent) -> void:
	if not overlay.visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func open(mob_id: String, mob_kind: String, loot: Array) -> void:
	current_mob_id = mob_id
	title_label.text = "Труп " + _kind_label(mob_kind)
	overlay.visible = true
	_render(loot)

func update_loot(mob_id: String, loot: Array) -> void:
	if mob_id != current_mob_id or not overlay.visible:
		return
	_render(loot)
	if loot.is_empty():
		close()

func close() -> void:
	overlay.visible = false
	current_mob_id = ""
	closed.emit()

func is_open() -> bool:
	return overlay.visible

func _kind_label(kind: String) -> String:
	match kind:
		"slime":  return "слайма"
		"goblin": return "гоблина"
	return ""

func _render(loot: Array) -> void:
	for c in list_box.get_children():
		c.queue_free()
	if loot.is_empty():
		var msg := Label.new()
		msg.text = "Пусто"
		msg.add_theme_color_override("font_color", Color(0.55, 0.50, 0.42, 1))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_box.add_child(msg)
		take_all_btn.disabled = true
		return
	take_all_btn.disabled = false
	for i in range(loot.size()):
		var entry: Dictionary = loot[i]
		var item_id := String(entry.get("itemId", ""))
		var qty := int(entry.get("qty", 1))
		var idx := i
		var row := _make_entry_row(item_id, qty, func(): take_requested.emit(current_mob_id, idx))
		list_box.add_child(row)

func _make_entry_row(item_id: String, qty: int, on_take: Callable) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	var sb_n := _row_sb(false)
	var sb_h := _row_sb(true)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.pressed.connect(on_take)

	var hb := HBoxContainer.new()
	hb.anchor_right = 1.0
	hb.anchor_bottom = 1.0
	hb.offset_left = 6
	hb.offset_top = 4
	hb.offset_right = -8
	hb.offset_bottom = -4
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var def: Dictionary = Items.def(item_id)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	icon.texture = at
	icon.custom_minimum_size = Vector2(22, 22)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)

	var name_lbl := Label.new()
	var nm := String(def.get("name", item_id))
	name_lbl.text = nm + ("" if qty <= 1 else "  ×%d" % qty)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88, 1))
	hb.add_child(name_lbl)

	var hint := Label.new()
	hint.text = "Взять"
	hint.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1))
	hb.add_child(hint)
	return btn

func _row_sb(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.15, 0.10, 1.0) if hover else Color(0.12, 0.10, 0.08, 1.0)
	sb.border_color = Color(0.65, 0.50, 0.20, 1.0) if hover else Color(0.35, 0.28, 0.18, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb
