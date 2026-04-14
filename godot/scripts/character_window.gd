# Полноэкранное окно персонажа: спрайт по центру, слоты экипировки
# по сторонам, статы.
class_name CharacterWindow
extends CanvasLayer

signal unequip_requested(slot: String)
signal closed

const ITEMS_TEX := preload("res://assets/sprites/items.png")

const SLOT_LAYOUT := [
	# slot, dx, dy относительно центра спрайта
	{ "slot": "head",   "x":   0, "y": -120, "label": "Шлем" },
	{ "slot": "amulet", "x": -90, "y":  -90, "label": "Амулет" },
	{ "slot": "cloak",  "x":  90, "y":  -90, "label": "Плащ" },
	{ "slot": "weapon", "x": -90, "y":  -10, "label": "Оружие" },
	{ "slot": "body",   "x":  90, "y":  -10, "label": "Броня" },
	{ "slot": "ring1",  "x": -90, "y":   70, "label": "Кольцо" },
	{ "slot": "ring2",  "x":  90, "y":   70, "label": "Кольцо" },
	{ "slot": "belt",   "x":   0, "y":   70, "label": "Пояс" },
	{ "slot": "boots",  "x":   0, "y":  130, "label": "Сапоги" },
]

var overlay: ColorRect
var card: PanelContainer
var doll_root: Control
var doll_sprite: Sprite2D
var slot_buttons: Dictionary = {}  # slot → Button
var stats_label: Label

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
	card.offset_left = -300
	card.offset_top = -240
	card.offset_right = 300
	card.offset_bottom = 240
	overlay.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "Персонаж"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)

	# Слева — кукла со слотами
	doll_root = Control.new()
	doll_root.custom_minimum_size = Vector2(360, 380)
	doll_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(doll_root)

	doll_sprite = Sprite2D.new()
	doll_sprite.position = Vector2(180, 190)
	doll_sprite.scale = Vector2(3, 3)
	doll_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	doll_root.add_child(doll_sprite)

	for entry in SLOT_LAYOUT:
		var btn := _make_slot_button(entry["label"])
		btn.position = Vector2(180 + entry["x"] - 22, 190 + entry["y"] - 22)
		var slot_name: String = entry["slot"]
		btn.pressed.connect(func(): unequip_requested.emit(slot_name))
		doll_root.add_child(btn)
		slot_buttons[slot_name] = btn

	# Справа — статы
	stats_label = Label.new()
	stats_label.text = ""
	stats_label.custom_minimum_size = Vector2(180, 0)
	stats_label.add_theme_font_size_override("font_size", 13)
	body.add_child(stats_label)

func _make_slot_button(label: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(44, 44)
	b.tooltip_text = label
	b.flat = true
	b.add_theme_stylebox_override("normal", _slot_sb(false))
	b.add_theme_stylebox_override("hover", _slot_sb(true))
	b.add_theme_stylebox_override("pressed", _slot_sb(true))
	return b

func _slot_sb(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	sb.border_color = Color(0.6, 0.55, 0.4, 1.0) if hover else Color(0.25, 0.22, 0.16, 1.0)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

func _set_slot_icon(btn: Button, item_id: String) -> void:
	for c in btn.get_children():
		c.queue_free()
	if item_id == "":
		return
	var def: Dictionary = Items.def(item_id)
	if def.is_empty():
		return
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	var icon := TextureRect.new()
	icon.texture = at
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size = Vector2(36, 36)
	icon.position = Vector2(4, 4)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	btn.tooltip_text = String(def.get("name", item_id))

func set_doll(variant: int) -> void:
	# Спрайт-лист персонажа: 32×32, hframes=3, vframes=4. Кадр idle вниз (frame 0).
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
	for slot in slot_buttons.keys():
		_set_slot_icon(slot_buttons[slot], String(eq.get(slot, "")))
	stats_label.text = "Уровень: %d\nHP: %d / %d\nXP: %d / %d\nУрон: %d\nЗолото: %d" % [
		int(me.get("level", 1)),
		int(me.get("hp", 0)), int(me.get("hpMax", 100)),
		int(me.get("xp", 0)), int(me.get("xpNeed", 50)),
		int(me.get("damage", 10)),
		int(me.get("gold", 0)),
	]
