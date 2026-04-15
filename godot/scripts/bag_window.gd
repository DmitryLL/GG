# Окно сумки в фэнтези-стиле: сетка 5×5 с рамками по редкости,
# крупный заголовок с золотом и индикатором занятости.
class_name BagWindow
extends CanvasLayer

signal use_or_equip(slot_index: int)
signal closed

const ITEMS_TEX := preload("res://assets/sprites/items.png")
const SLOT_COUNT := 25
const GRID_COLS := 5

var overlay: ColorRect
var card: PanelContainer
var gold_label: Label
var usage_label: Label
var inv_buttons: Array[Button] = []
var last_me: Dictionary = {}

# Тултип
var tip: PanelContainer
var tip_name: Label
var tip_sub: Label

func _ready() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
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
	card.offset_left = -260
	card.offset_top = -290
	card.offset_right = 260
	card.offset_bottom = 290
	card.add_theme_stylebox_override("panel", UI.panel_style(12, 2))
	overlay.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	_build_header(v)
	v.add_child(UI.divider())
	_build_gold(v)
	v.add_child(UI.divider())
	_build_grid(v)
	_build_footer(v)
	_build_tip()

func _build_header(parent: Container) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	parent.add_child(top)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	top.add_child(titles)
	var t := Label.new()
	t.text = "Сумка"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", UI.GOLD)
	titles.add_child(t)
	usage_label = Label.new()
	usage_label.text = "0 / %d ячеек" % SLOT_COUNT
	usage_label.add_theme_font_size_override("font_size", 11)
	usage_label.add_theme_color_override("font_color", UI.TEXT_DIM)
	titles.add_child(usage_label)

	var close_btn := Button.new()
	UI.apply_close_button(close_btn)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

func _build_gold(parent: Container) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.inner_style(8))
	parent.add_child(panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)

	h.add_child(UI.coin(16))
	var ttl := Label.new()
	ttl.text = "Золото"
	ttl.add_theme_color_override("font_color", UI.TEXT_DIM)
	ttl.add_theme_font_size_override("font_size", 13)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ttl)
	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.add_theme_color_override("font_color", UI.GOLD)
	h.add_child(gold_label)

func _build_grid(parent: Container) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.inner_style(10))
	parent.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)

	for i in range(SLOT_COUNT):
		var b := _make_slot_button()
		var idx := i
		b.pressed.connect(func(): use_or_equip.emit(idx))
		b.mouse_entered.connect(func(): _show_tip_for(idx))
		b.mouse_exited.connect(func(): tip.visible = false)
		inv_buttons.append(b)
		grid.add_child(b)

func _build_footer(parent: Container) -> void:
	var hint := Label.new()
	hint.text = "Клик по предмету — одеть (оружие/броня) или использовать (зелье)"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UI.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)

var tip_stats: VBoxContainer

func _build_tip() -> void:
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UI.panel_style(8, 1))
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.custom_minimum_size = Vector2(200, 0)
	overlay.add_child(tip)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	tip.add_child(v)
	tip_name = Label.new()
	tip_name.add_theme_font_size_override("font_size", 14)
	v.add_child(tip_name)
	tip_sub = Label.new()
	tip_sub.add_theme_font_size_override("font_size", 10)
	tip_sub.add_theme_color_override("font_color", UI.TEXT_MUTED)
	v.add_child(tip_sub)
	tip_stats = VBoxContainer.new()
	tip_stats.add_theme_constant_override("separation", 2)
	v.add_child(tip_stats)

func _show_tip_for(idx: int) -> void:
	var inv: Array = last_me.get("inv", [])
	if idx < 0 or idx >= inv.size():
		tip.visible = false
		return
	var e: Dictionary = inv[idx]
	var item_id := String(e.get("itemId", ""))
	if item_id == "":
		tip.visible = false
		return
	var def: Dictionary = Items.def(item_id)
	var r := Items.rarity(item_id)
	tip_name.text = String(def.get("name", item_id))
	tip_name.add_theme_color_override("font_color", Items.rarity_color(r))
	var kind := Items.kind_name(item_id)
	tip_sub.text = "%s · %s" % [Items.rarity_name(r), kind] if kind != "" else Items.rarity_name(r)

	for c in tip_stats.get_children():
		c.queue_free()
	for line in Items.stat_lines(item_id):
		var lbl := Label.new()
		lbl.text = String(line["text"])
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", line["color"])
		tip_stats.add_child(lbl)

	var btn: Button = inv_buttons[idx]
	var rect: Rect2 = btn.get_global_rect()
	tip.position = Vector2(rect.position.x + rect.size.x + 8, rect.position.y)
	tip.visible = true

func _make_slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(60, 60)
	b.add_theme_stylebox_override("normal", UI.slot_style(-1, false))
	b.add_theme_stylebox_override("hover", UI.slot_style(-1, true))
	b.add_theme_stylebox_override("pressed", UI.slot_style(-1, true))
	b.add_theme_stylebox_override("focus", UI.slot_style(-1, true))
	return b

func _set_slot_icon(btn: Button, item_id: String, qty: int) -> void:
	for c in btn.get_children():
		c.queue_free()
	var r := Items.rarity(item_id) if item_id != "" else -1
	btn.add_theme_stylebox_override("normal", UI.slot_style(r, false))
	btn.add_theme_stylebox_override("hover", UI.slot_style(r, true))
	btn.add_theme_stylebox_override("pressed", UI.slot_style(r, true))
	btn.add_theme_stylebox_override("focus", UI.slot_style(r, true))
	if item_id == "":
		btn.tooltip_text = ""
		return
	var def: Dictionary = Items.def(item_id)
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	var icon := TextureRect.new()
	icon.texture = at
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size = Vector2(44, 44)
	icon.position = Vector2(8, 8)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	if qty > 1:
		var q_bg := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.75)
		sb.border_color = Items.rarity_color(r)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		q_bg.add_theme_stylebox_override("panel", sb)
		q_bg.position = Vector2(34, 34)
		q_bg.custom_minimum_size = Vector2(22, 18)
		q_bg.size = Vector2(22, 18)
		q_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(q_bg)
		var q := Label.new()
		q.text = str(qty)
		q.add_theme_color_override("font_color", UI.TEXT_MAIN)
		q.add_theme_font_size_override("font_size", 11)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q_bg.add_child(q)
	btn.tooltip_text = ""  # используем свой тултип

func open(me: Dictionary) -> void:
	overlay.visible = true
	refresh(me)

func close() -> void:
	overlay.visible = false
	tip.visible = false
	closed.emit()

func is_open() -> bool:
	return overlay.visible

func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func refresh(me: Dictionary) -> void:
	last_me = me
	if not overlay.visible:
		return
	gold_label.text = "%d" % int(me.get("gold", 0))
	var inv: Array = me.get("inv", [])
	usage_label.text = "%d / %d ячеек" % [inv.size(), SLOT_COUNT]
	for i in range(SLOT_COUNT):
		if i < inv.size():
			var e: Dictionary = inv[i]
			_set_slot_icon(inv_buttons[i], String(e.get("itemId", "")), int(e.get("qty", 1)))
		else:
			_set_slot_icon(inv_buttons[i], "", 0)
