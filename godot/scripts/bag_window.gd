# Сумка с фильтрами и карточкой выбранного предмета.
# Первый клик выбирает предмет, повторный клик или кнопка справа — действие.
class_name BagWindow
extends CanvasLayer

const UI = preload("res://scripts/ui.gd")
const Items = preload("res://scripts/items.gd")
signal use_or_equip(slot_index: int)
signal closed

const BAG_EMBLEM := preload("res://assets/sprites/ui/bag_emblem.png")
const SLOT_COUNT := 50
const GRID_COLS := 5
const FILTERS := [
	{ "key": "all", "title": "Все" },
	{ "key": "weapon", "title": "Оружие" },
	{ "key": "armor", "title": "Броня" },
	{ "key": "consumable", "title": "Расходники" },
]

var overlay: ColorRect
var card: PanelContainer
var gold_label: Label
var usage_label: Label
var result_label: Label
var action_button: Button
var empty_state: Label
var inv_buttons: Array[Button] = []
var filter_buttons: Dictionary = {}
var filtered_indices: Array[int] = []
var last_me: Dictionary = {}
var selected_inv_index: int = -1
var current_filter: String = "all"

# Правая панель
var detail_name: Label
var detail_meta: Label
var detail_desc: Label
var detail_stats: VBoxContainer
var detail_icon_host: CenterContainer
var detail_slot_hint: Label
var header_emblem: TextureRect

# Тултип
var tip: PanelContainer
var tip_name: Label
var tip_sub: Label
var tip_stats: VBoxContainer

func _ready() -> void:
	layer = 10
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
	card.offset_left = -390
	card.offset_top = -280
	card.offset_right = 390
	card.offset_bottom = 280
	card.add_theme_stylebox_override("panel", UI.panel_style(12, 2))
	overlay.add_child(card)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	card.add_child(root)

	_build_header(root)
	root.add_child(UI.divider())
	_build_toolbar(root)
	root.add_child(UI.divider())
	_build_content(root)
	_build_tip()

func _build_header(parent: Container) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	parent.add_child(top)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	top.add_child(titles)

	var title := Label.new()
	title.text = "Сумка"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", UI.MAGIC_ACCENT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	titles.add_child(title)

	usage_label = Label.new()
	usage_label.text = "0 предметов · 0 / %d ячеек" % SLOT_COUNT
	usage_label.add_theme_font_size_override("font_size", 11)
	usage_label.add_theme_color_override("font_color", UI.TEXT_DIM)
	titles.add_child(usage_label)

	var gold_panel := PanelContainer.new()
	gold_panel.add_theme_stylebox_override("panel", UI.inner_style(8))
	top.add_child(gold_panel)

	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 10)
	gold_panel.add_child(gh)
	gh.add_child(UI.coin(16))

	var gold_title := Label.new()
	gold_title.text = "Золото"
	gold_title.add_theme_font_size_override("font_size", 12)
	gold_title.add_theme_color_override("font_color", UI.TEXT_DIM)
	gh.add_child(gold_title)

	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", UI.GOLD)
	gh.add_child(gold_label)

	header_emblem = TextureRect.new()
	header_emblem.custom_minimum_size = Vector2(44, 44)
	header_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_emblem.texture = BAG_EMBLEM
	top.add_child(header_emblem)

	var close_btn := Button.new()
	UI.apply_close_button(close_btn)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

func _build_toolbar(parent: Container) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	parent.add_child(toolbar)

	result_label = Label.new()
	result_label.text = "Показано: 0"
	result_label.add_theme_font_size_override("font_size", 11)
	result_label.add_theme_color_override("font_color", UI.TEXT_DIM)
	result_label.custom_minimum_size = Vector2(120, 0)
	toolbar.add_child(result_label)

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	toolbar.add_child(flow)

	for entry in FILTERS:
		var key := String(entry["key"])
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = String(entry["title"])
		btn.custom_minimum_size = Vector2(96, 30)
		_apply_filter_button_style(btn)
		btn.pressed.connect(func(): _set_filter(key))
		filter_buttons[key] = btn
		flow.add_child(btn)

func _build_content(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(430, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", UI.inner_style(10))
	row.add_child(left_panel)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left_panel.add_child(left)

	var left_header := HBoxContainer.new()
	left_header.add_theme_constant_override("separation", 8)
	left.add_child(left_header)

	var inventory_title := Label.new()
	inventory_title.text = "Предметы"
	inventory_title.add_theme_font_size_override("font_size", 13)
	inventory_title.add_theme_color_override("font_color", UI.MAGIC_ACCENT)
	inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_header.add_child(inventory_title)

	var cap_label := Label.new()
	cap_label.text = "Лимит: %d" % SLOT_COUNT
	cap_label.add_theme_font_size_override("font_size", 11)
	cap_label.add_theme_color_override("font_color", UI.TEXT_DIM)
	left_header.add_child(cap_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	var grid_wrap := MarginContainer.new()
	grid_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_wrap)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid_wrap.add_child(grid)

	for i in range(SLOT_COUNT):
		var b := _make_slot_button()
		var display_idx := i
		b.pressed.connect(func(): _on_slot_pressed(display_idx))
		b.mouse_entered.connect(func(): _show_tip_for_display(display_idx))
		b.mouse_exited.connect(func(): tip.visible = false)
		inv_buttons.append(b)
		grid.add_child(b)

	empty_state = Label.new()
	empty_state.text = "В этой категории пока нет предметов."
	empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_state.add_theme_font_size_override("font_size", 12)
	empty_state.add_theme_color_override("font_color", UI.TEXT_MUTED)
	empty_state.visible = false
	left.add_child(empty_state)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(290, 0)
	right_panel.add_theme_stylebox_override("panel", UI.inner_style(10))
	row.add_child(right_panel)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right_panel.add_child(right)

	var right_title := Label.new()
	right_title.text = "Выбранный предмет"
	right_title.add_theme_font_size_override("font_size", 13)
	right_title.add_theme_color_override("font_color", UI.MAGIC_ACCENT)
	right.add_child(right_title)
	right.add_child(UI.divider())

	detail_icon_host = CenterContainer.new()
	detail_icon_host.custom_minimum_size = Vector2(0, 78)
	right.add_child(detail_icon_host)

	detail_name = Label.new()
	detail_name.text = "Выбери предмет"
	detail_name.add_theme_font_size_override("font_size", 18)
	detail_name.add_theme_color_override("font_color", UI.TEXT_MAIN)
	detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(detail_name)

	detail_meta = Label.new()
	detail_meta.text = "Слева появятся предметы, подходящие под фильтр"
	detail_meta.add_theme_font_size_override("font_size", 11)
	detail_meta.add_theme_color_override("font_color", UI.TEXT_DIM)
	detail_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_meta)

	detail_desc = Label.new()
	detail_desc.text = "Кликни по предмету один раз, чтобы посмотреть детали."
	detail_desc.add_theme_font_size_override("font_size", 12)
	detail_desc.add_theme_color_override("font_color", UI.TEXT_MUTED)
	detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_desc)

	detail_stats = VBoxContainer.new()
	detail_stats.add_theme_constant_override("separation", 4)
	right.add_child(detail_stats)

	detail_slot_hint = Label.new()
	detail_slot_hint.text = ""
	detail_slot_hint.add_theme_font_size_override("font_size", 11)
	detail_slot_hint.add_theme_color_override("font_color", UI.TEXT_DIM)
	detail_slot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(detail_slot_hint)

	action_button = Button.new()
	action_button.text = "Выбери предмет"
	action_button.disabled = true
	action_button.custom_minimum_size = Vector2(0, 40)
	UI.apply_primary_button(action_button)
	action_button.pressed.connect(_activate_selected_item)
	right.add_child(action_button)

	var hint := Label.new()
	hint.text = "Первый клик выбирает предмет. Повторный клик или кнопка справа применяет действие."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UI.TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(hint)

func _build_tip() -> void:
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UI.panel_style(8, 1))
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.custom_minimum_size = Vector2(220, 0)
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

func _apply_filter_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UI.BG_DEEP
	normal.border_color = UI.BORDER_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(8)
	var hover := StyleBoxFlat.new()
	hover.bg_color = UI.BG_SLOT_HOVER
	hover.border_color = UI.MAGIC_ACCENT
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(8)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", UI.TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", UI.TEXT_MAIN)
	btn.add_theme_color_override("font_pressed_color", UI.TEXT_MAIN)
	btn.add_theme_font_size_override("font_size", 11)

func _make_slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 76)
	b.add_theme_stylebox_override("normal", UI.slot_style(-1, false))
	b.add_theme_stylebox_override("hover", UI.slot_style(-1, true))
	b.add_theme_stylebox_override("pressed", UI.slot_style(-1, true))
	b.add_theme_stylebox_override("focus", UI.slot_style(-1, true))
	return b

func _set_slot_icon(btn: Button, item_id: String, qty: int, actual_index: int) -> void:
	for c in btn.get_children():
		c.queue_free()

	var rarity := Items.rarity(item_id) if item_id != "" else -1
	var is_selected := actual_index >= 0 and actual_index == selected_inv_index
	btn.add_theme_stylebox_override("normal", UI.slot_style(rarity, is_selected))
	btn.add_theme_stylebox_override("hover", UI.slot_style(rarity, true))
	btn.add_theme_stylebox_override("pressed", UI.slot_style(rarity, true))
	btn.add_theme_stylebox_override("focus", UI.slot_style(rarity, true))
	btn.disabled = item_id == ""

	if item_id == "":
		return

	var icon := TextureRect.new()
	icon.texture = Items.icon_texture(item_id)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size = Vector2(40, 40)
	icon.position = Vector2(16, 8)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	var name := Label.new()
	name.text = String(Items.def(item_id).get("name", item_id))
	name.position = Vector2(6, 50)
	name.size = Vector2(60, 20)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 9)
	name.add_theme_color_override("font_color", UI.TEXT_MAIN)
	name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	name.add_theme_constant_override("shadow_offset_x", 1)
	name.add_theme_constant_override("shadow_offset_y", 1)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.clip_text = true
	btn.add_child(name)

	if qty > 1:
		var qty_bg := Panel.new()
		qty_bg.position = Vector2(46, 6)
		qty_bg.custom_minimum_size = Vector2(20, 16)
		qty_bg.size = qty_bg.custom_minimum_size
		qty_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var qty_sb := StyleBoxFlat.new()
		qty_sb.bg_color = Color(0, 0, 0, 0.76)
		qty_sb.border_color = Items.rarity_color(rarity)
		qty_sb.set_border_width_all(1)
		qty_sb.set_corner_radius_all(4)
		qty_bg.add_theme_stylebox_override("panel", qty_sb)
		btn.add_child(qty_bg)

		var qty_label := Label.new()
		qty_label.text = str(qty)
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		qty_label.add_theme_font_size_override("font_size", 11)
		qty_label.add_theme_color_override("font_color", UI.TEXT_MAIN)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qty_bg.add_child(qty_label)

	var slot_label := Label.new()
	slot_label.text = "#%d" % (actual_index + 1)
	slot_label.position = Vector2(6, 6)
	slot_label.add_theme_font_size_override("font_size", 9)
	slot_label.add_theme_color_override("font_color", UI.TEXT_DIM)
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(slot_label)

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

	var inv: Array = me.get("inv", [])
	gold_label.text = "%d" % int(me.get("gold", 0))
	usage_label.text = "%d предметов · %d / %d ячеек" % [inv.size(), inv.size(), SLOT_COUNT]

	if selected_inv_index >= inv.size():
		selected_inv_index = -1

	_rebuild_filtered_indices(inv)
	_refresh_filter_buttons()
	result_label.text = "Показано: %d из %d" % [filtered_indices.size(), inv.size()]
	empty_state.visible = filtered_indices.is_empty()

	for display_idx in range(SLOT_COUNT):
		if display_idx < filtered_indices.size():
			var actual_idx := filtered_indices[display_idx]
			var entry: Dictionary = inv[actual_idx]
			_set_slot_icon(inv_buttons[display_idx], String(entry.get("itemId", "")), int(entry.get("qty", 1)), actual_idx)
		else:
			_set_slot_icon(inv_buttons[display_idx], "", 0, -1)

	_refresh_detail_panel()

func _rebuild_filtered_indices(inv: Array) -> void:
	filtered_indices.clear()
	for idx in range(inv.size()):
		var entry: Dictionary = inv[idx]
		var item_id := String(entry.get("itemId", ""))
		if item_id == "":
			continue
		if current_filter != "all" and Items.bag_group(item_id) != current_filter:
			continue
		filtered_indices.append(idx)

	if selected_inv_index != -1 and not filtered_indices.has(selected_inv_index):
		selected_inv_index = -1

func _set_filter(filter_key: String) -> void:
	current_filter = filter_key
	refresh(last_me)

func _reset_filters() -> void:
	current_filter = "all"
	refresh(last_me)

func _refresh_filter_buttons() -> void:
	for key in filter_buttons.keys():
		var btn: Button = filter_buttons[key]
		btn.button_pressed = key == current_filter
		var active: bool = key == current_filter
		btn.add_theme_color_override("font_color", UI.TEXT_MAIN if active else UI.TEXT_DIM)

func _on_slot_pressed(display_idx: int) -> void:
	var actual_idx := _actual_slot_index(display_idx)
	if actual_idx == -1:
		return
	if selected_inv_index == actual_idx:
		use_or_equip.emit(actual_idx)
		return
	selected_inv_index = actual_idx
	refresh(last_me)

func _activate_selected_item() -> void:
	if selected_inv_index < 0:
		return
	use_or_equip.emit(selected_inv_index)

func _actual_slot_index(display_idx: int) -> int:
	if display_idx < 0 or display_idx >= filtered_indices.size():
		return -1
	return filtered_indices[display_idx]

func _refresh_detail_panel() -> void:
	for child in detail_icon_host.get_children():
		child.queue_free()
	for child in detail_stats.get_children():
		child.queue_free()

	if selected_inv_index < 0:
		detail_name.text = "Выбери предмет"
		detail_name.add_theme_color_override("font_color", UI.TEXT_MAIN)
		detail_meta.text = "Слева появятся предметы, подходящие под фильтр"
		detail_desc.text = "Кликни по предмету один раз, чтобы посмотреть детали."
		detail_slot_hint.text = ""
		action_button.text = "Выбери предмет"
		action_button.disabled = true
		return

	var inv: Array = last_me.get("inv", [])
	if selected_inv_index >= inv.size():
		selected_inv_index = -1
		_refresh_detail_panel()
		return

	var entry: Dictionary = inv[selected_inv_index]
	var item_id := String(entry.get("itemId", ""))
	var qty := int(entry.get("qty", 1))
	var def_d := Items.def(item_id)
	var rarity := Items.rarity(item_id)

	var icon := TextureRect.new()
	icon.texture = Items.icon_texture(item_id)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon_host.add_child(icon)

	detail_name.text = String(def_d.get("name", item_id))
	detail_name.add_theme_color_override("font_color", Items.rarity_color(rarity))
	detail_meta.text = "%s · %s · x%d" % [
		Items.rarity_name(rarity),
		Items.bag_group_name(Items.bag_group(item_id)),
		qty
	]
	detail_desc.text = _item_description(item_id)
	detail_slot_hint.text = "Слот сумки: #%d" % (selected_inv_index + 1)

	for line in Items.stat_lines(item_id):
		var lbl := Label.new()
		lbl.text = String(line["text"])
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", line["color"])
		detail_stats.add_child(lbl)

	if detail_stats.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Особых бонусов нет"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", UI.TEXT_MUTED)
		detail_stats.add_child(empty)

	var action_name := Items.action_name(item_id)
	action_button.disabled = action_name == ""
	action_button.text = action_name if action_name != "" else "Без действия"

func _item_description(item_id: String) -> String:
	var group := Items.bag_group(item_id)
	match group:
		"weapon":
			return "Оружие можно быстро надеть, чтобы сменить стиль боя или усилить урон."
		"armor":
			return "Экипировка повышает живучесть и помогает держаться дольше в бою."
		"jewelry":
			return "Украшения дают компактные, но полезные бонусы к персонажу."
		"consumable":
			return "Расходник используется сразу из сумки и помогает пережить сложный бой."
		"material":
			return "Материал для продажи, обмена или будущих систем крафта."
	return "Предмет хранится в сумке и ждёт применения."

func _show_tip_for_display(display_idx: int) -> void:
	var actual_idx := _actual_slot_index(display_idx)
	if actual_idx == -1:
		tip.visible = false
		return

	var inv: Array = last_me.get("inv", [])
	if actual_idx >= inv.size():
		tip.visible = false
		return

	var entry: Dictionary = inv[actual_idx]
	var item_id := String(entry.get("itemId", ""))
	if item_id == "":
		tip.visible = false
		return

	var rarity := Items.rarity(item_id)
	tip_name.text = String(Items.def(item_id).get("name", item_id))
	tip_name.add_theme_color_override("font_color", Items.rarity_color(rarity))
	tip_sub.text = "%s · %s" % [Items.rarity_name(rarity), Items.bag_group_name(Items.bag_group(item_id))]

	for child in tip_stats.get_children():
		child.queue_free()
	for line in Items.stat_lines(item_id):
		var lbl := Label.new()
		lbl.text = String(line["text"])
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", line["color"])
		tip_stats.add_child(lbl)

	if tip_stats.get_child_count() == 0:
		var info := Label.new()
		info.text = _item_description(item_id)
		info.add_theme_font_size_override("font_size", 11)
		info.add_theme_color_override("font_color", UI.TEXT_MUTED)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_stats.add_child(info)

	var btn: Button = inv_buttons[display_idx]
	var rect: Rect2 = btn.get_global_rect()
	tip.position = Vector2(rect.position.x + rect.size.x + 10, rect.position.y)
	tip.visible = true
