# Окно персонажа: спрайт по центру, 9 слотов экипировки вокруг, статы.
# Полностью непрозрачное окно. Слоты подписаны и тонированы.
class_name CharacterWindow
extends CanvasLayer

signal unequip_requested(slot: String)
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
		btn.pressed.connect(func(): unequip_requested.emit(slot_name))
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
	closed.emit()

func is_open() -> bool:
	return overlay.visible

func refresh(me: Dictionary) -> void:
	if not overlay.visible:
		return
	var eq: Dictionary = me.get("eq", {})
	for entry in SLOT_LAYOUT:
		var slot: String = entry["slot"]
		_set_slot_icon(slot_buttons[slot], String(eq.get(slot, "")), entry["label"])
	stats_level.text = "%d" % int(me.get("level", 1))
	stats_hp.text = "%d / %d" % [int(me.get("hp", 0)), int(me.get("hpMax", 100))]
	stats_xp.text = "%d / %d" % [int(me.get("xp", 0)), int(me.get("xpNeed", 50))]
	stats_damage.text = "%d" % int(me.get("damage", 10))
