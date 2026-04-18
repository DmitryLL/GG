# Магазин торговца — фэнтези-стиль, непрозрачный фон, группы по типу,
# сортировка по цене, текущее золото в шапке.
class_name Shop
extends CanvasLayer

const Items = preload("res://scripts/items.gd")
signal buy_requested(npc_id: String, item_id: String)
signal sell_requested(slot_index: int)
signal closed

const ITEMS_TEX_PATH := "res://assets/sprites/items.png"

# Цены приходят с сервера (one-shot OP_NPCS).
var prices: Dictionary = {}

const SLOT_GROUPS := [
	{ "key": "consumable", "title": "Зелья" },
	{ "key": "weapon",     "title": "Оружие" },
	{ "key": "body",       "title": "Броня" },
	{ "key": "head",       "title": "Шлемы" },
	{ "key": "boots",      "title": "Сапоги" },
	{ "key": "belt",       "title": "Пояса" },
	{ "key": "cloak",      "title": "Плащи" },
	{ "key": "ring",       "title": "Кольца" },
	{ "key": "amulet",     "title": "Амулеты" },
	{ "key": "material",   "title": "Материалы" },
]

var overlay: ColorRect
var card: PanelContainer
var title_label: Label
var gold_label: Label
var close_btn: Button
var buy_list: VBoxContainer
var sell_list: VBoxContainer
var open_npc_id: String = ""
var last_player_state: Dictionary = {}

func _ready() -> void:
	layer = 10
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
	card.offset_left = -340
	card.offset_top = -260
	card.offset_right = 340
	card.offset_bottom = 260
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.09, 0.08, 1.0)
	card_sb.border_color = Color(0.65, 0.50, 0.20, 1.0)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(8)
	card_sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", card_sb)
	overlay.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(v)

	# Шапка: название + золото игрока + ×
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	title_label = Label.new()
	title_label.text = "Торговец"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)

	var gold_panel := PanelContainer.new()
	var gp := StyleBoxFlat.new()
	gp.bg_color = Color(0.07, 0.06, 0.05, 1.0)
	gp.border_color = Color(0.65, 0.50, 0.20, 1.0)
	gp.set_border_width_all(1)
	gp.set_corner_radius_all(4)
	gp.set_content_margin_all(8)
	gold_panel.add_theme_stylebox_override("panel", gp)
	top.add_child(gold_panel)
	gold_label = Label.new()
	gold_label.text = "Золото: 0"
	gold_label.add_theme_color_override("font_color", Color(0.99, 0.85, 0.45, 1))
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_panel.add_child(gold_label)

	close_btn = Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(36, 32)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	v.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	# Купить
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lh := Label.new()
	lh.text = "Купить"
	lh.add_theme_font_size_override("font_size", 14)
	lh.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1))
	left.add_child(lh)
	var buy_scroll := ScrollContainer.new()
	buy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(buy_scroll)
	buy_list = VBoxContainer.new()
	buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_list.add_theme_constant_override("separation", 4)
	buy_scroll.add_child(buy_list)

	# Продать
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rh := Label.new()
	rh.text = "Продать"
	rh.add_theme_font_size_override("font_size", 14)
	rh.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1))
	right.add_child(rh)
	var sell_scroll := ScrollContainer.new()
	sell_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sell_scroll)
	sell_list = VBoxContainer.new()
	sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_list.add_theme_constant_override("separation", 4)
	sell_scroll.add_child(sell_list)

func open(npc_id: String, stock: Array, player: Dictionary) -> void:
	open_npc_id = npc_id
	last_player_state = player
	overlay.visible = true
	_fill_buy(stock, player)
	_fill_sell(player)

func close() -> void:
	overlay.visible = false
	open_npc_id = ""
	closed.emit()

func is_open() -> bool:
	return overlay.visible

func set_prices(p: Dictionary) -> void:
	prices = p

func refresh(player: Dictionary) -> void:
	if not overlay.visible or open_npc_id == "":
		return
	last_player_state = player
	gold_label.text = "Золото: %d" % int(player.get("gold", 0))
	var stock: Array = []
	for id in prices.keys():
		var entry: Dictionary = prices[id]
		if entry.get("buy", null) != null:
			stock.append(id)
	_fill_buy(stock, player)
	_fill_sell(player)

func _group_for(item_id: String) -> String:
	var def: Dictionary = Items.def(item_id)
	if def.has("slot"):
		return String(def["slot"])
	return String(def.get("kind", "material"))

func _fill_buy(stock: Array, player: Dictionary) -> void:
	for c in buy_list.get_children():
		c.queue_free()
	var gold := int(player.get("gold", 0))
	gold_label.text = "Золото: %d" % gold

	# Сгруппировать stock по slot/kind, потом отсортировать по цене.
	var groups: Dictionary = {}
	for id in stock:
		var sid := String(id)
		var price = prices.get(sid, {}).get("buy", null)
		if price == null:
			continue
		var g := _group_for(sid)
		if not groups.has(g):
			groups[g] = []
		groups[g].append({ "id": sid, "price": int(price) })

	for grp in SLOT_GROUPS:
		var key: String = grp["key"]
		if not groups.has(key):
			continue
		var arr: Array = groups[key]
		arr.sort_custom(func(a, b): return a["price"] < b["price"])
		_add_section_header(buy_list, grp["title"])
		for entry in arr:
			var btn := _entry_button(entry["id"], entry["price"], gold >= entry["price"])
			var sid: String = entry["id"]
			btn.pressed.connect(func(): buy_requested.emit(open_npc_id, sid))
			buy_list.add_child(btn)

func _fill_sell(player: Dictionary) -> void:
	for c in sell_list.get_children():
		c.queue_free()
	var inv: Array = player.get("inv", [])
	if inv.size() == 0:
		var msg := Label.new()
		msg.text = "Инвентарь пуст"
		msg.add_theme_color_override("font_color", Color(0.47, 0.47, 0.47, 1))
		sell_list.add_child(msg)
		return

	# Сгруппировать инвентарь, сохраняя индексы.
	var groups: Dictionary = {}
	for i in range(inv.size()):
		var e: Dictionary = inv[i]
		var item_id := String(e.get("itemId", ""))
		var qty := int(e.get("qty", 1))
		var sell_price = prices.get(item_id, {}).get("sell", null)
		if sell_price == null:
			continue
		var g := _group_for(item_id)
		if not groups.has(g):
			groups[g] = []
		groups[g].append({ "idx": i, "id": item_id, "qty": qty, "price": int(sell_price) })

	for grp in SLOT_GROUPS:
		var key: String = grp["key"]
		if not groups.has(key):
			continue
		var arr: Array = groups[key]
		arr.sort_custom(func(a, b): return a["price"] < b["price"])
		_add_section_header(sell_list, grp["title"])
		for entry in arr:
			var btn := _entry_button(entry["id"], entry["price"], true, entry["qty"])
			var idx: int = entry["idx"]
			btn.pressed.connect(func(): sell_requested.emit(idx))
			sell_list.add_child(btn)

func _add_section_header(box: VBoxContainer, text: String) -> void:
	if box.get_child_count() > 0:
		box.add_child(_thin_spacer())
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40, 1))
	lbl.add_theme_font_size_override("font_size", 12)
	box.add_child(lbl)

func _thin_spacer() -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	return sp

func _entry_button(item_id: String, price: int, enabled: bool, qty: int = 1) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 46)
	btn.disabled = not enabled
	btn.add_theme_stylebox_override("normal", _entry_sb(false, enabled))
	btn.add_theme_stylebox_override("hover", _entry_sb(true, enabled))
	btn.add_theme_stylebox_override("pressed", _entry_sb(true, enabled))
	btn.add_theme_stylebox_override("disabled", _entry_sb(false, false))

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
	var r := Items.rarity(item_id)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load(ITEMS_TEX_PATH)
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	icon.texture = at
	icon.custom_minimum_size = Vector2(24, 24)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = String(def.get("name", item_id)) + ("" if qty <= 1 else "  ×%d" % qty)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Items.rarity_color(r))
	col.add_child(name_lbl)
	var stats_line := Items.stat_inline(item_id)
	if stats_line != "":
		var sub := Label.new()
		sub.text = stats_line
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", Color(0.60, 0.55, 0.46, 1))
		col.add_child(sub)

	var price_lbl := Label.new()
	price_lbl.text = "%d з." % price
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.add_theme_color_override("font_color", Color(0.99, 0.85, 0.45, 1))
	hb.add_child(price_lbl)
	return btn

func _entry_sb(hover: bool, enabled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if not enabled:
		sb.bg_color = Color(0.08, 0.07, 0.06, 1.0)
		sb.border_color = Color(0.20, 0.17, 0.12, 1.0)
	elif hover:
		sb.bg_color = Color(0.18, 0.15, 0.10, 1.0)
		sb.border_color = Color(0.65, 0.50, 0.20, 1.0)
	else:
		sb.bg_color = Color(0.12, 0.10, 0.08, 1.0)
		sb.border_color = Color(0.35, 0.28, 0.18, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb
