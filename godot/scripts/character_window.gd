# Окно персонажа: спрайт по центру, 9 слотов экипировки вокруг, статы.
# Полностью непрозрачное окно. Слоты подписаны и тонированы.
class_name CharacterWindow
extends CanvasLayer

signal unequip_requested(slot: String)
signal equip_requested(inv_index: int, target_slot: String)
signal closed

const ITEMS_TEX := preload("res://assets/sprites/items.png")

# Цвета подсветки слотов под их тип (повышает узнаваемость).
const SLOT_TINT := {
	"head":   Color(0.55, 0.40, 0.20),  # коричневый — кожа
	"amulet": Color(0.65, 0.50, 0.20),  # золотистый
	"cloak":  Color(0.45, 0.30, 0.55),  # фиолетовый
	"weapon": Color(0.55, 0.20, 0.20),  # красный
	"body":   Color(0.20, 0.40, 0.55),  # синий
	"ring1":  Color(0.55, 0.45, 0.15),  # охра
	"ring2":  Color(0.55, 0.45, 0.15),
	"belt":   Color(0.40, 0.25, 0.10),
	"boots":  Color(0.30, 0.20, 0.10),
}

const SLOT_LAYOUT := [
	{ "slot": "head",   "x":   0, "y": -135, "label": "Шлем" },
	{ "slot": "amulet", "x": -95, "y":  -90, "label": "Амулет" },
	{ "slot": "cloak",  "x":  95, "y":  -90, "label": "Плащ" },
	{ "slot": "weapon", "x": -95, "y":  -10, "label": "Оружие" },
	{ "slot": "body",   "x":  95, "y":  -10, "label": "Броня" },
	{ "slot": "ring1",  "x": -95, "y":   70, "label": "Кольцо" },
	{ "slot": "ring2",  "x":  95, "y":   70, "label": "Кольцо" },
	{ "slot": "belt",   "x":   0, "y":   75, "label": "Пояс" },
	{ "slot": "boots",  "x":   0, "y":  140, "label": "Сапоги" },
]

var overlay: ColorRect
var card: PanelContainer
var doll_root: Control
var doll_sprite: Sprite2D
var slot_buttons: Dictionary = {}  # slot → Button
var slot_tints: Dictionary = {}    # slot → ColorRect (фоновая подсветка)

# Статы — отдельные лейблы чтобы цвета задавать по-разному.
var stats_level: Label
var stats_hp: Label
var stats_xp: Label
var stats_damage: Label

# Попап выбора вещи для слота.
var picker: PanelContainer
var picker_title: Label
var picker_list: VBoxContainer
var picker_slot: String = ""
var last_inv: Array = []
var last_eq: Dictionary = {}

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
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "Персонаж"
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

	var sep := HSeparator.new()
	v.add_child(sep)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	v.add_child(body)

	# Слева — кукла со слотами на собственном полотне.
	doll_root = Control.new()
	doll_root.custom_minimum_size = Vector2(380, 400)
	doll_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(doll_root)

	# Лёгкая виньетка вокруг куклы — отделяет от слотов.
	var doll_bg := PanelContainer.new()
	doll_bg.position = Vector2(140, 130)
	doll_bg.custom_minimum_size = Vector2(110, 130)
	var dbg := StyleBoxFlat.new()
	dbg.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	dbg.border_color = Color(0.30, 0.24, 0.16, 1.0)
	dbg.set_border_width_all(1)
	dbg.set_corner_radius_all(60)
	doll_bg.add_theme_stylebox_override("panel", dbg)
	doll_root.add_child(doll_bg)

	doll_sprite = Sprite2D.new()
	doll_sprite.position = Vector2(190, 195)
	doll_sprite.scale = Vector2(3, 3)
	doll_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	doll_root.add_child(doll_sprite)

	for entry in SLOT_LAYOUT:
		var slot_name: String = entry["slot"]
		var btn := _make_slot_button(entry["label"], slot_name)
		btn.position = Vector2(190 + entry["x"] - 26, 195 + entry["y"] - 26)
		btn.pressed.connect(func(): _open_picker(slot_name))
		doll_root.add_child(btn)
		slot_buttons[slot_name] = btn
		_show_empty_label(btn, entry["label"])

	# Справа — статы в красивом блоке.
	var stats_panel := PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(220, 0)
	var sp_sb := StyleBoxFlat.new()
	sp_sb.bg_color = Color(0.07, 0.06, 0.05, 1.0)
	sp_sb.border_color = Color(0.38, 0.30, 0.18, 1.0)
	sp_sb.set_border_width_all(1)
	sp_sb.set_corner_radius_all(6)
	sp_sb.set_content_margin_all(14)
	stats_panel.add_theme_stylebox_override("panel", sp_sb)
	body.add_child(stats_panel)

	var stats_v := VBoxContainer.new()
	stats_v.add_theme_constant_override("separation", 8)
	stats_panel.add_child(stats_v)

	var stats_title := Label.new()
	stats_title.text = "Статистика"
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1))
	stats_v.add_child(stats_title)

	stats_v.add_child(HSeparator.new())

	stats_level = _make_stat_label("Уровень", "1", Color(0.99, 0.85, 0.45))
	stats_v.add_child(stats_level.get_parent())
	stats_hp = _make_stat_label("HP", "100 / 100", Color(0.55, 0.85, 0.45))
	stats_v.add_child(stats_hp.get_parent())
	stats_xp = _make_stat_label("Опыт", "0 / 50", Color(0.99, 0.78, 0.30))
	stats_v.add_child(stats_xp.get_parent())
	stats_damage = _make_stat_label("Урон", "10", Color(0.94, 0.55, 0.40))
	stats_v.add_child(stats_damage.get_parent())

	_build_picker()

func _build_picker() -> void:
	picker = PanelContainer.new()
	picker.anchor_left = 0.5
	picker.anchor_top = 0.5
	picker.anchor_right = 0.5
	picker.anchor_bottom = 0.5
	picker.offset_left = -160
	picker.offset_top = -180
	picker.offset_right = 160
	picker.offset_bottom = 180
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.08, 1.0)
	sb.border_color = Color(0.65, 0.50, 0.20, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	picker.add_theme_stylebox_override("panel", sb)
	picker.visible = false
	overlay.add_child(picker)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	picker.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	picker_title = Label.new()
	picker_title.add_theme_font_size_override("font_size", 16)
	picker_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1))
	picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(picker_title)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(28, 26)
	close_btn.pressed.connect(_close_picker)
	top.add_child(close_btn)

	v.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	picker_list = VBoxContainer.new()
	picker_list.add_theme_constant_override("separation", 4)
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(picker_list)

func _open_picker(slot: String) -> void:
	picker_slot = slot
	picker_title.text = _slot_title(slot)
	_render_picker()
	picker.visible = true

func _close_picker() -> void:
	picker.visible = false
	picker_slot = ""

func _slot_title(slot: String) -> String:
	for entry in SLOT_LAYOUT:
		if entry["slot"] == slot:
			return String(entry["label"])
	return slot

func _item_fits_slot(item_id: String, slot: String) -> bool:
	var def: Dictionary = Items.def(item_id)
	var s := String(def.get("slot", ""))
	if s == "":
		return false
	if s == slot:
		return true
	if s == "ring" and (slot == "ring1" or slot == "ring2"):
		return true
	return false

func _render_picker() -> void:
	for c in picker_list.get_children():
		c.queue_free()
	var equipped_id := String(last_eq.get(picker_slot, ""))
	if equipped_id != "":
		var def_eq: Dictionary = Items.def(equipped_id)
		var nm := String(def_eq.get("name", equipped_id))
		var unbtn := Button.new()
		unbtn.text = "Снять: " + nm
		unbtn.custom_minimum_size = Vector2(0, 32)
		var slot_copy := picker_slot
		unbtn.pressed.connect(func():
			unequip_requested.emit(slot_copy)
			_close_picker())
		picker_list.add_child(unbtn)
		picker_list.add_child(HSeparator.new())

	var any := false
	for i in range(last_inv.size()):
		var entry: Dictionary = last_inv[i]
		var item_id := String(entry.get("itemId", ""))
		if not _item_fits_slot(item_id, picker_slot):
			continue
		any = true
		var idx := i
		var slot_copy2 := picker_slot
		var row := _make_picker_row(item_id, int(entry.get("qty", 1)), func():
			equip_requested.emit(idx, slot_copy2)
			_close_picker())
		picker_list.add_child(row)

	if not any:
		var msg := Label.new()
		msg.text = "В сумке нет подходящих вещей"
		msg.add_theme_color_override("font_color", Color(0.55, 0.50, 0.42, 1))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		picker_list.add_child(msg)

func _make_picker_row(item_id: String, qty: int, on_take: Callable) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
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
	hint.text = "Надеть"
	hint.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1))
	hb.add_child(hint)
	return btn

func _make_stat_label(title: String, val: String, val_color: Color) -> Label:
	# Возвращает значение-лейбл; row уже добавлен в Vbox через get_parent().
	var row := HBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50, 1))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var v := Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", val_color)
	row.add_child(v)
	return v

func _make_slot_button(label: String, slot_key: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.tooltip_text = label
	b.add_theme_stylebox_override("normal", _slot_sb(false, slot_key))
	b.add_theme_stylebox_override("hover", _slot_sb(true, slot_key))
	b.add_theme_stylebox_override("pressed", _slot_sb(true, slot_key))
	b.add_theme_stylebox_override("focus", _slot_sb(true, slot_key))
	return b

func _slot_sb(hover: bool, slot_key: String) -> StyleBoxFlat:
	var tint: Color = SLOT_TINT.get(slot_key, Color(0.4, 0.4, 0.4))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.18, tint.g * 0.18, tint.b * 0.18, 1.0)
	sb.border_color = tint if hover else Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	return sb

func _show_empty_label(btn: Button, label: String) -> void:
	for c in btn.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.50, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(lbl)
	btn.tooltip_text = label

func _set_slot_icon(btn: Button, item_id: String, fallback_label: String) -> void:
	if item_id == "":
		_show_empty_label(btn, fallback_label)
		return
	for c in btn.get_children():
		c.queue_free()
	var def: Dictionary = Items.def(item_id)
	if def.is_empty():
		_show_empty_label(btn, fallback_label)
		return
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	var icon := TextureRect.new()
	icon.texture = at
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size = Vector2(40, 40)
	icon.position = Vector2(6, 6)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	btn.tooltip_text = String(def.get("name", item_id))

func set_doll(variant: int) -> void:
	doll_sprite.texture = load("res://assets/sprites/char_%d.png" % variant)
	doll_sprite.hframes = 3
	doll_sprite.vframes = 4
	doll_sprite.frame = 0

func open(me: Dictionary) -> void:
	overlay.visible = true
	refresh(me)

func close() -> void:
	overlay.visible = false
	_close_picker()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if picker.visible:
			_close_picker()
		else:
			close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return overlay.visible

func refresh(me: Dictionary) -> void:
	if not overlay.visible:
		return
	var eq: Dictionary = me.get("eq", {})
	last_eq = eq
	last_inv = me.get("inv", [])
	for entry in SLOT_LAYOUT:
		var slot: String = entry["slot"]
		_set_slot_icon(slot_buttons[slot], String(eq.get(slot, "")), entry["label"])
	stats_level.text = "%d" % int(me.get("level", 1))
	stats_hp.text = "%d / %d" % [int(me.get("hp", 0)), int(me.get("hpMax", 100))]
	stats_xp.text = "%d / %d" % [int(me.get("xp", 0)), int(me.get("xpNeed", 50))]
	stats_damage.text = "%d" % int(me.get("damage", 10))
	if picker and picker.visible:
		_render_picker()
