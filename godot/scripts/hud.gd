# Right-side HUD: gold, level/XP bar, equipment slots, inventory grid.
# Built imperatively so there's no .tscn wiring to maintain.
class_name Hud
extends CanvasLayer

signal equip_slot_clicked(index: int)
signal unequip_slot_clicked(slot: String)           # "weapon" | "armor"

const ITEMS_TEX := preload("res://assets/sprites/items.png")

var gold_label: Label
var level_label: Label
var hp_label: Label
var xp_bar: ProgressBar
var eq_weapon_box: Button
var eq_armor_box: Button
var inv_buttons: Array[Button] = []

func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -260
	panel.offset_top = 170     # ниже миникарты (8 + 135 + padding)
	panel.offset_right = -6
	panel.offset_bottom = 410
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	gold_label = Label.new()
	gold_label.text = "0 зол."
	gold_label.add_theme_color_override("font_color", Color(0.99, 0.89, 0.51, 1))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(gold_label)

	# Уровень/HP/XP теперь в nameplate (top-left). Здесь оставляем только
	# золото, экипировку и инвентарь.
	level_label = Label.new()
	level_label.visible = false
	xp_bar = ProgressBar.new()
	xp_bar.visible = false
	hp_label = Label.new()
	hp_label.visible = false

	var eq_row := HBoxContainer.new()
	eq_row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(eq_row)
	var wlab := Label.new()
	wlab.text = "Оруж."
	wlab.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	eq_row.add_child(wlab)
	eq_weapon_box = _make_slot_button()
	eq_row.add_child(eq_weapon_box)
	var alab := Label.new()
	alab.text = "Броня"
	alab.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	eq_row.add_child(alab)
	eq_armor_box = _make_slot_button()
	eq_row.add_child(eq_armor_box)

	eq_weapon_box.pressed.connect(func(): unequip_slot_clicked.emit("weapon"))
	eq_armor_box.pressed.connect(func(): unequip_slot_clicked.emit("armor"))

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for i in range(6):
		var b := _make_slot_button()
		var index := i
		b.pressed.connect(func(): equip_slot_clicked.emit(index))
		inv_buttons.append(b)
		grid.add_child(b)

func _make_slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(36, 36)
	b.flat = true
	b.add_theme_stylebox_override("normal", _slot_sb(false))
	b.add_theme_stylebox_override("hover", _slot_sb(true))
	b.add_theme_stylebox_override("pressed", _slot_sb(true))
	return b

func _slot_sb(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(0.54, 0.55, 0.6, 1) if hover else Color(0.2, 0.2, 0.23, 1)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb

func _set_slot_icon(btn: Button, item_id: String, qty: int = 0) -> void:
	for c in btn.get_children():
		c.queue_free()
	if item_id == "":
		btn.tooltip_text = ""
		return
	var def: Dictionary = Items.def(item_id)
	var icon := TextureRect.new()
	icon.texture = ITEMS_TEX
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.position = Vector2(4, 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Region crop via atlas texture for single frame.
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = Rect2(int(def.get("icon", 0)) * 16, 0, 16, 16)
	icon.texture = at
	btn.add_child(icon)
	if qty > 1:
		var q := Label.new()
		q.text = str(qty)
		q.position = Vector2(18, 18)
		q.add_theme_color_override("font_color", Color.WHITE)
		q.add_theme_color_override("font_outline_color", Color.BLACK)
		q.add_theme_constant_override("outline_size", 3)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(q)
	btn.tooltip_text = String(def.get("name", item_id))

func update_me(me: Dictionary) -> void:
	gold_label.text = "%d зол." % int(me.get("gold", 0))
	level_label.text = "Ур. %d" % int(me.get("level", 1))
	xp_bar.max_value = float(me.get("xpNeed", 50))
	xp_bar.value = float(me.get("xp", 0))
	hp_label.text = "HP %d/%d" % [int(me.get("hp", 0)), int(me.get("hpMax", 0))]

	_set_slot_icon(eq_weapon_box, String(me.get("eqW", "")))
	_set_slot_icon(eq_armor_box, String(me.get("eqA", "")))

	var inv: Array = me.get("inv", [])
	for i in range(6):
		if i < inv.size():
			var e: Dictionary = inv[i]
			_set_slot_icon(inv_buttons[i], String(e.get("itemId", "")), int(e.get("qty", 1)))
		else:
			_set_slot_icon(inv_buttons[i], "")
