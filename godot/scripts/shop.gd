# Merchant shop modal — Buy (left) + Sell (right) columns.
class_name Shop
extends CanvasLayer

signal buy_requested(npc_id: String, item_id: String)
signal sell_requested(slot_index: int)
signal closed

const ITEMS_TEX := preload("res://assets/sprites/items.png")

# Цены приходят с сервера через OP_NPCS (one-shot при join).
var prices: Dictionary = {}

var overlay: ColorRect
var card: PanelContainer
var title: Label
var close_btn: Button
var buy_list: VBoxContainer
var sell_list: VBoxContainer
var open_npc_id: String = ""
var last_player_state: Dictionary = {}

func _ready() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
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
	card.offset_top = -200
	card.offset_right = 260
	card.offset_bottom = 200
	overlay.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	title = Label.new()
	title.text = "Торговец"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	close_btn = Button.new()
	close_btn.text = "×"
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lh := Label.new()
	lh.text = "Купить"
	lh.add_theme_color_override("font_color", Color(0.67, 0.67, 0.67, 1))
	left.add_child(lh)
	var buy_scroll := ScrollContainer.new()
	buy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(buy_scroll)
	buy_list = VBoxContainer.new()
	buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.add_child(buy_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rh := Label.new()
	rh.text = "Продать"
	rh.add_theme_color_override("font_color", Color(0.67, 0.67, 0.67, 1))
	right.add_child(rh)
	var sell_scroll := ScrollContainer.new()
	sell_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sell_scroll)
	sell_list = VBoxContainer.new()
	sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var stock: Array = []
	for id in prices.keys():
		var entry: Dictionary = prices[id]
		if entry.get("buy", null) != null:
			stock.append(id)
	_fill_buy(stock, player)
	_fill_sell(player)

func _fill_buy(stock: Array, player: Dictionary) -> void:
	for c in buy_list.get_children():
		c.queue_free()
	var gold := int(player.get("gold", 0))
	for id in stock:
		var sid := String(id)
		var price = prices.get(sid, {}).get("buy", null)
		if price == null:
			continue
		var btn := _entry_button(sid, int(price), gold >= int(price))
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
	for i in range(inv.size()):
		var e: Dictionary = inv[i]
		var item_id := String(e.get("itemId", ""))
		var qty := int(e.get("qty", 1))
		var sell_price = prices.get(item_id, {}).get("sell", null)
		if sell_price == null:
			continue
		var btn := _entry_button(item_id, int(sell_price), true, qty)
		var index := i
		btn.pressed.connect(func(): sell_requested.emit(index))
		sell_list.add_child(btn)

func _entry_button(item_id: String, price: int, enabled: bool, qty: int = 1) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 40)
	btn.disabled = not enabled
	var hb := HBoxContainer.new()
	hb.anchor_right = 1.0
	hb.anchor_bottom = 1.0
	hb.offset_left = 6
	hb.offset_top = 6
	hb.offset_right = -6
	hb.offset_bottom = -6
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var def: Dictionary = Items.def(item_id)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	icon.texture = at
	icon.custom_minimum_size = Vector2(24, 24)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = String(def.get("name", item_id)) + ("" if qty <= 1 else "  ×%d" % qty)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%d зол." % price
	price_lbl.add_theme_color_override("font_color", Color(0.99, 0.89, 0.51, 1))
	hb.add_child(price_lbl)
	return btn
