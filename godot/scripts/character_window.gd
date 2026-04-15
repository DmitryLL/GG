# Окно персонажа — расширенный UI в фэнтези-стиле.
# Слева — кукла с 9 слотами экипировки, справа — характеристики.
# Клик по слоту открывает попап выбора из сумки.
class_name CharacterWindow
extends CanvasLayer

signal unequip_requested(slot: String)
signal equip_requested(inv_index: int, target_slot: String)
signal closed

const ITEMS_TEX := preload("res://assets/sprites/items.png")

const SLOT_LAYOUT := [
	{ "slot": "head",   "x":   0, "y": -150, "label": "Шлем" },
	{ "slot": "amulet", "x": -110, "y": -100, "label": "Амулет" },
	{ "slot": "cloak",  "x":  110, "y": -100, "label": "Плащ" },
	{ "slot": "weapon", "x": -110, "y":  -10, "label": "Оружие" },
	{ "slot": "body",   "x":  110, "y":  -10, "label": "Броня" },
	{ "slot": "ring1",  "x": -110, "y":   80, "label": "Кольцо I" },
	{ "slot": "ring2",  "x":  110, "y":   80, "label": "Кольцо II" },
	{ "slot": "belt",   "x":    0, "y":   85, "label": "Пояс" },
	{ "slot": "boots",  "x":    0, "y":  160, "label": "Сапоги" },
]

var overlay: ColorRect
var card: PanelContainer
var doll_root: Control
var doll_sprite: Sprite2D
var slot_buttons: Dictionary = {}

# Header
var title_level: Label
var xp_bar: Control
var xp_text: Label

# Stats
var stats_hp_bar: Control
var stats_hp_text: Label
var stats_damage: Label
var stats_level: Label
var stats_gold: Label

# Picker
var picker: PanelContainer
var picker_title: Label
var picker_list: VBoxContainer
var picker_slot: String = ""
var last_inv: Array = []
var last_eq: Dictionary = {}

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
	card.offset_left = -390
	card.offset_top = -290
	card.offset_right = 390
	card.offset_bottom = 290
	card.add_theme_stylebox_override("panel", UI.panel_style(12, 2))
	overlay.add_child(card)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	card.add_child(root)

	_build_header(root)
	root.add_child(UI.divider())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_build_doll(body)
	_build_stats(body)

	_build_picker()

func _build_header(parent: Container) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	parent.add_child(top)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	top.add_child(titles)

	var t := Label.new()
	t.text = "Персонаж"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", UI.GOLD)
	titles.add_child(t)

	title_level = Label.new()
	title_level.text = "Странник — Уровень 1"
	title_level.add_theme_font_size_override("font_size", 12)
	title_level.add_theme_color_override("font_color", UI.TEXT_DIM)
	titles.add_child(title_level)

	var close_btn := Button.new()
	UI.apply_close_button(close_btn)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

func _build_doll(parent: Container) -> void:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(360, 430)
	wrap.add_theme_stylebox_override("panel", UI.inner_style(10))
	parent.add_child(wrap)

	doll_root = Control.new()
	doll_root.custom_minimum_size = Vector2(340, 410)
	wrap.add_child(doll_root)

	# Вертикальная «ниша» под куклой — мягкая подсветка силуэта.
	var niche := Panel.new()
	niche.position = Vector2(120, 120)
	niche.custom_minimum_size = Vector2(100, 160)
	niche.size = niche.custom_minimum_size
	var niche_sb := StyleBoxFlat.new()
	niche_sb.bg_color = Color(0.160, 0.125, 0.085, 1.0)
	niche_sb.border_color = UI.BORDER_DIM
	niche_sb.set_border_width_all(1)
	niche_sb.corner_radius_top_left = 50
	niche_sb.corner_radius_top_right = 50
	niche_sb.corner_radius_bottom_left = 20
	niche_sb.corner_radius_bottom_right = 20
	niche_sb.shadow_color = Color(0.95, 0.72, 0.25, 0.10)
	niche_sb.shadow_size = 18
	niche.add_theme_stylebox_override("panel", niche_sb)
	doll_root.add_child(niche)

	doll_sprite = Sprite2D.new()
	doll_sprite.position = Vector2(170, 205)
	doll_sprite.scale = Vector2(3.2, 3.2)
	doll_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	doll_root.add_child(doll_sprite)

	for entry in SLOT_LAYOUT:
		var slot_name: String = entry["slot"]
		var btn := _make_slot_button()
		btn.position = Vector2(170 + int(entry["x"]) - 28, 205 + int(entry["y"]) - 28)
		var lbl: String = String(entry["label"])
		btn.tooltip_text = lbl
		btn.pressed.connect(func(): _open_picker(slot_name))
		doll_root.add_child(btn)
		slot_buttons[slot_name] = btn
		_fill_slot(btn, "", lbl)

func _build_stats(parent: Container) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)

	# Блок «Характеристики»
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", UI.inner_style(10))
	col.add_child(stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	stats_panel.add_child(sv)

	sv.add_child(UI.section_title("Характеристики"))
	sv.add_child(UI.divider())

	# Level
	stats_level = _stat_row(sv, "Уровень", "1", UI.GOLD)
	# HP с баром
	var hp_wrap := VBoxContainer.new()
	hp_wrap.add_theme_constant_override("separation", 4)
	sv.add_child(hp_wrap)
	var hp_head := HBoxContainer.new()
	hp_wrap.add_child(hp_head)
	var hp_ttl := Label.new()
	hp_ttl.text = "Здоровье"
	hp_ttl.add_theme_color_override("font_color", UI.TEXT_DIM)
	hp_ttl.add_theme_font_size_override("font_size", 12)
	hp_ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_head.add_child(hp_ttl)
	stats_hp_text = Label.new()
	stats_hp_text.text = "100 / 100"
	stats_hp_text.add_theme_font_size_override("font_size", 13)
	stats_hp_text.add_theme_color_override("font_color", UI.HP_RED)
	hp_head.add_child(stats_hp_text)
	stats_hp_bar = UI.progress_bar(UI.HP_BG, UI.HP_RED, 10)
	hp_wrap.add_child(stats_hp_bar)

	# XP с баром
	var xp_wrap := VBoxContainer.new()
	xp_wrap.add_theme_constant_override("separation", 4)
	sv.add_child(xp_wrap)
	var xp_head := HBoxContainer.new()
	xp_wrap.add_child(xp_head)
	var xp_ttl := Label.new()
	xp_ttl.text = "Опыт"
	xp_ttl.add_theme_color_override("font_color", UI.TEXT_DIM)
	xp_ttl.add_theme_font_size_override("font_size", 12)
	xp_ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_head.add_child(xp_ttl)
	xp_text = Label.new()
	xp_text.text = "0 / 50"
	xp_text.add_theme_font_size_override("font_size", 13)
	xp_text.add_theme_color_override("font_color", UI.XP_ORANGE)
	xp_head.add_child(xp_text)
	xp_bar = UI.progress_bar(UI.XP_BG, UI.XP_ORANGE, 10)
	xp_wrap.add_child(xp_bar)

	# Damage
	stats_damage = _stat_row(sv, "Урон", "10", Color(0.95, 0.50, 0.40))

	sv.add_child(UI.divider())

	# Gold
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	sv.add_child(gold_row)
	gold_row.add_child(UI.coin(14))
	var gold_ttl := Label.new()
	gold_ttl.text = "Золото"
	gold_ttl.add_theme_color_override("font_color", UI.TEXT_DIM)
	gold_ttl.add_theme_font_size_override("font_size", 12)
	gold_ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(gold_ttl)
	stats_gold = Label.new()
	stats_gold.text = "0"
	stats_gold.add_theme_font_size_override("font_size", 16)
	stats_gold.add_theme_color_override("font_color", UI.GOLD)
	gold_row.add_child(stats_gold)

	# Подсказка
	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", UI.inner_style(8))
	col.add_child(hint_panel)
	var hint := Label.new()
	hint.text = "Кликните по слоту, чтобы надеть вещь из сумки."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UI.TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_panel.add_child(hint)

	# Нижний spacer чтобы блок тянулся, а подсказка прижималась вверх
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

func _stat_row(parent: Container, title: String, val: String, val_color: Color) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", UI.TEXT_DIM)
	t.add_theme_font_size_override("font_size", 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var v := Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 16)
	v.add_theme_color_override("font_color", val_color)
	row.add_child(v)
	return v

func _make_slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	b.add_theme_stylebox_override("normal", UI.slot_style(-1, false))
	b.add_theme_stylebox_override("hover", UI.slot_style(-1, true))
	b.add_theme_stylebox_override("pressed", UI.slot_style(-1, true))
	b.add_theme_stylebox_override("focus", UI.slot_style(-1, true))
	return b

func _fill_slot(btn: Button, item_id: String, fallback_label: String) -> void:
	for c in btn.get_children():
		c.queue_free()
	var r := Items.rarity(item_id) if item_id != "" else -1
	btn.add_theme_stylebox_override("normal", UI.slot_style(r, false))
	btn.add_theme_stylebox_override("hover", UI.slot_style(r, true))
	btn.add_theme_stylebox_override("pressed", UI.slot_style(r, true))
	btn.add_theme_stylebox_override("focus", UI.slot_style(r, true))
	if item_id == "":
		var lbl := Label.new()
		lbl.text = fallback_label
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", UI.TEXT_MUTED)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(lbl)
		btn.tooltip_text = fallback_label
		return
	var def: Dictionary = Items.def(item_id)
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	var icon := TextureRect.new()
	icon.texture = at
	icon.custom_minimum_size = Vector2(42, 42)
	icon.size = Vector2(42, 42)
	icon.position = Vector2(7, 7)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	btn.tooltip_text = "%s\n%s" % [String(def.get("name", item_id)), Items.rarity_name(r)]

# ---------- picker ----------
func _build_picker() -> void:
	picker = PanelContainer.new()
	picker.anchor_left = 0.5
	picker.anchor_top = 0.5
	picker.anchor_right = 0.5
	picker.anchor_bottom = 0.5
	picker.offset_left = -180
	picker.offset_top = -200
	picker.offset_right = 180
	picker.offset_bottom = 200
	picker.add_theme_stylebox_override("panel", UI.panel_style(10, 2))
	picker.visible = false
	overlay.add_child(picker)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	picker.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	picker_title = Label.new()
	picker_title.add_theme_font_size_override("font_size", 16)
	picker_title.add_theme_color_override("font_color", UI.GOLD)
	picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(picker_title)
	var close_btn := Button.new()
	UI.apply_close_button(close_btn)
	close_btn.pressed.connect(_close_picker)
	top.add_child(close_btn)

	v.add_child(UI.divider())

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
		var slot_copy := picker_slot
		var unbtn := _make_picker_row(equipped_id, 1, "Снять", func():
			unequip_requested.emit(slot_copy)
			_close_picker(), true)
		picker_list.add_child(unbtn)
		var sep := UI.divider()
		sep.custom_minimum_size = Vector2(0, 6)
		picker_list.add_child(sep)

	var any := false
	for i in range(last_inv.size()):
		var entry: Dictionary = last_inv[i]
		var item_id := String(entry.get("itemId", ""))
		if not _item_fits_slot(item_id, picker_slot):
			continue
		any = true
		var idx := i
		var slot_copy2 := picker_slot
		var row := _make_picker_row(item_id, int(entry.get("qty", 1)), "Надеть", func():
			equip_requested.emit(idx, slot_copy2)
			_close_picker(), false)
		picker_list.add_child(row)

	if not any and equipped_id == "":
		var msg := Label.new()
		msg.text = "В сумке нет подходящих вещей"
		msg.add_theme_color_override("font_color", UI.TEXT_MUTED)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		picker_list.add_child(msg)

func _make_picker_row(item_id: String, qty: int, hint_text: String, on_take: Callable, is_unequip: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	var r := Items.rarity(item_id)
	btn.add_theme_stylebox_override("normal", UI.slot_style(r, false, 5))
	btn.add_theme_stylebox_override("hover", UI.slot_style(r, true, 5))
	btn.add_theme_stylebox_override("pressed", UI.slot_style(r, true, 5))
	btn.add_theme_stylebox_override("focus", UI.slot_style(r, true, 5))
	btn.pressed.connect(on_take)

	var hb := HBoxContainer.new()
	hb.anchor_right = 1.0
	hb.anchor_bottom = 1.0
	hb.offset_left = 8
	hb.offset_top = 4
	hb.offset_right = -10
	hb.offset_bottom = -4
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var def: Dictionary = Items.def(item_id)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	icon.texture = at
	icon.custom_minimum_size = Vector2(26, 26)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)

	var name_lbl := Label.new()
	var nm := String(def.get("name", item_id))
	name_lbl.text = nm + ("" if qty <= 1 else "  ×%d" % qty)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Items.rarity_color(r))
	col.add_child(name_lbl)
	var sub := Label.new()
	sub.text = Items.rarity_name(r)
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", UI.TEXT_MUTED)
	col.add_child(sub)

	var hint := Label.new()
	hint.text = hint_text
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UI.GOLD if not is_unequip else Color(0.85, 0.52, 0.40))
	hb.add_child(hint)
	return btn

# ---------- lifecycle ----------
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

func is_open() -> bool:
	return overlay.visible

func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if picker.visible:
			_close_picker()
		else:
			close()
		get_viewport().set_input_as_handled()

func refresh(me: Dictionary) -> void:
	if not overlay.visible:
		return
	var eq: Dictionary = me.get("eq", {})
	last_eq = eq
	last_inv = me.get("inv", [])

	for entry in SLOT_LAYOUT:
		var slot: String = entry["slot"]
		_fill_slot(slot_buttons[slot], String(eq.get(slot, "")), entry["label"])

	var lvl: int = int(me.get("level", 1))
	var xp: int = int(me.get("xp", 0))
	var xp_need: int = int(me.get("xpNeed", 50))
	var hp: int = int(me.get("hp", 0))
	var hp_max: int = int(me.get("hpMax", 100))
	var dmg: int = int(me.get("damage", 10))
	var gold: int = int(me.get("gold", 0))

	title_level.text = "Странник — Уровень %d" % lvl
	xp_text.text = "%d / %d" % [xp, xp_need]
	UI.progress_set(xp_bar, float(xp) / float(max(xp_need, 1)))

	stats_level.text = "%d" % lvl
	stats_hp_text.text = "%d / %d" % [hp, hp_max]
	UI.progress_set(stats_hp_bar, float(hp) / float(max(hp_max, 1)))
	stats_damage.text = "%d" % dmg
	stats_gold.text = "%d" % gold

	if picker and picker.visible:
		_render_picker()
