# Экран выбора персонажа.
# Новая модель: на аккаунте может быть несколько персонажей. Сервер
# отдаёт список через RPC `characters_list`. Игрок выбирает карточку и
# нажимает «Играть», или создаёт нового через «+ Создать».
extends Control

signal auth_changed  # main.gd слушает этот сигнал для переезда на Game

@onready var list_root: HBoxContainer = %CharList
@onready var play_btn: Button = %PlayBtn
@onready var logout_btn: Button = %LogoutBtn
@onready var email_label: Label = %EmailLabel

const ARCHER_PREVIEW: Texture2D = preload("res://assets/sprites/ui/icon_character.png")
const MAGE_PREVIEW: Texture2D = preload("res://assets/sprites/ui/icon_mage_character.png")

var _chars: Array = []           # [{id, name, charClass, level, gold}]
var _active_id: String = ""
var _selected_id: String = ""
var _card_nodes: Dictionary = {} # { char_id: PanelContainer }
var _create_btn: Button

func _ready() -> void:
	if Session.auth:
		email_label.text = "Аккаунт: %s" % Session.get_saved_email()
	play_btn.pressed.connect(_on_play)
	logout_btn.pressed.connect(_on_logout)
	play_btn.disabled = true
	await _refresh_from_server()

func _refresh_from_server() -> void:
	if Session.auth == null or Session.client == null:
		return
	var res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "characters_list", "")
	if res == null or res.is_exception():
		push_warning("characters_list failed")
		_chars = []
		_active_id = ""
	else:
		var data: Variant = JSON.parse_string(res.payload)
		if typeof(data) == TYPE_DICTIONARY:
			_chars = data.get("chars", [])
			_active_id = str(data.get("active", ""))
	_selected_id = _active_id if _active_id != "" else ""
	_rebuild_cards()
	if _chars.is_empty():
		_open_create_modal()

func _rebuild_cards() -> void:
	for ch in list_root.get_children():
		ch.queue_free()
	_card_nodes.clear()
	for c in _chars:
		_card_nodes[str(c["id"])] = _make_card(c)
	_create_btn = _make_create_card()
	list_root.add_child(_create_btn)
	_update_play_btn()

func _make_card(c: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 240)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	list_root.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)

	var cls := str(c.get("charClass", "archer"))
	var tex: Texture2D = MAGE_PREVIEW if cls == "mage" else ARCHER_PREVIEW

	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(86, 86)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(c.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)

	var meta := Label.new()
	meta.text = "%s · Ур. %d" % [_class_label(cls), int(c.get("level", 1))]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(meta)

	var del := Button.new()
	del.text = "Удалить"
	del.focus_mode = Control.FOCUS_NONE
	del.add_theme_font_size_override("font_size", 11)
	del.add_theme_color_override("font_color", Color(0.95, 0.5, 0.45))
	del.custom_minimum_size = Vector2(100, 22)
	del.pressed.connect(func(): _on_delete(str(c["id"])))
	v.add_child(del)

	var char_id := str(c["id"])
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_set_selected(char_id)
	)
	_apply_card_style(card, char_id == _selected_id)
	return card

func _apply_card_style(card: PanelContainer, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.12, 0.08, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	sb.border_color = Color(0.95, 0.75, 0.35, 1) if selected else Color(0.4, 0.32, 0.18, 1)
	card.add_theme_stylebox_override("panel", sb)

func _make_create_card() -> Button:
	var b := Button.new()
	b.text = "+ Создать"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 240)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.65))
	b.pressed.connect(_open_create_modal)
	return b

func _set_selected(id: String) -> void:
	_selected_id = id
	for k in _card_nodes.keys():
		_apply_card_style(_card_nodes[k], str(k) == id)
	_update_play_btn()

func _update_play_btn() -> void:
	play_btn.disabled = (_selected_id == "")

func _class_label(cls: String) -> String:
	return {"archer": "Лучник", "mage": "Маг"}.get(cls, cls)

func _on_play() -> void:
	if _selected_id == "":
		return
	# Переключить активного, если отличается.
	if _selected_id != _active_id:
		var res: NakamaAPI.ApiRpc = await Session.client.rpc_async(
			Session.auth, "character_select", JSON.stringify({ "id": _selected_id })
		)
		if res and not res.is_exception():
			var d: Variant = JSON.parse_string(res.payload)
			if typeof(d) == TYPE_DICTIONARY and d.get("ok", false):
				_active_id = str(d.get("active", _selected_id))
	# Класс передадим в Session — для skills_window на старте.
	for c in _chars:
		if str(c["id"]) == _selected_id:
			Session.selected_character = str(c.get("charClass", "archer"))
			break
	auth_changed.emit()

func _on_logout() -> void:
	Session.logout()
	auth_changed.emit()

func _on_delete(char_id: String) -> void:
	var res: NakamaAPI.ApiRpc = await Session.client.rpc_async(
		Session.auth, "character_delete", JSON.stringify({ "id": char_id })
	)
	if res == null or res.is_exception():
		return
	await _refresh_from_server()

# ─── Модалка создания персонажа ───

var _modal: PanelContainer
var _modal_name: LineEdit
var _modal_class := "archer"
var _modal_faction := "west"
var _modal_faction_cards: Dictionary = {}
var _modal_error: Label
var _modal_class_cards: Dictionary = {}

func _open_create_modal() -> void:
	if _modal and is_instance_valid(_modal):
		_modal.visible = true
		return
	_modal = PanelContainer.new()
	_modal.anchor_left = 0; _modal.anchor_top = 0
	_modal.anchor_right = 1; _modal.anchor_bottom = 1
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.set_content_margin_all(0)
	_modal.add_theme_stylebox_override("panel", sb)
	add_child(_modal)

	var center := CenterContainer.new()
	center.anchor_right = 1; center.anchor_bottom = 1
	_modal.add_child(center)

	var inner := PanelContainer.new()
	inner.custom_minimum_size = Vector2(440, 380)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.12, 0.09, 0.06, 1)
	sb2.border_color = Color(0.85, 0.65, 0.30, 1)
	sb2.set_border_width_all(2)
	sb2.set_corner_radius_all(10)
	sb2.set_content_margin_all(16)
	inner.add_theme_stylebox_override("panel", sb2)
	center.add_child(inner)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)

	var title := Label.new()
	title.text = "Создать персонажа"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var name_lbl := Label.new()
	name_lbl.text = "Имя (3-20 символов, буквы и цифры)"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	col.add_child(name_lbl)

	_modal_name = LineEdit.new()
	_modal_name.placeholder_text = "Имя персонажа"
	_modal_name.max_length = 20
	col.add_child(_modal_name)

	var cls_lbl := Label.new()
	cls_lbl.text = "Класс"
	cls_lbl.add_theme_font_size_override("font_size", 12)
	cls_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	col.add_child(cls_lbl)

	var cls_row := HBoxContainer.new()
	cls_row.add_theme_constant_override("separation", 8)
	cls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cls_row)
	_modal_class_cards.clear()
	for cls_id in ["archer", "mage"]:
		var card := _make_class_card(cls_id)
		cls_row.add_child(card)
		_modal_class_cards[cls_id] = card
	_modal_class = "archer"
	_refresh_modal_class_cards()

	# Фракция: запад / восток.
	var fac_lbl := Label.new()
	fac_lbl.text = "Фракция"
	fac_lbl.add_theme_font_size_override("font_size", 12)
	fac_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	col.add_child(fac_lbl)
	var fac_row := HBoxContainer.new()
	fac_row.add_theme_constant_override("separation", 8)
	fac_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(fac_row)
	_modal_faction_cards.clear()
	for fac_id in ["west", "east"]:
		var fc := _make_faction_card(fac_id)
		fac_row.add_child(fc)
		_modal_faction_cards[fac_id] = fc
	_modal_faction = "west"
	_refresh_modal_faction_cards()

	_modal_error = Label.new()
	_modal_error.text = ""
	_modal_error.add_theme_font_size_override("font_size", 12)
	_modal_error.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	_modal_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_modal_error)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btn_row)

	var ok := Button.new()
	ok.text = "Создать"
	ok.custom_minimum_size = Vector2(120, 32)
	ok.pressed.connect(_submit_create)
	btn_row.add_child(ok)

	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(100, 32)
	cancel.disabled = _chars.is_empty()  # если нет персонажей — нельзя отменить
	cancel.pressed.connect(func():
		_modal.visible = false
	)
	btn_row.add_child(cancel)

func _make_class_card(cls_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 140)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)

	var icon := TextureRect.new()
	icon.texture = MAGE_PREVIEW if cls_id == "mage" else ARCHER_PREVIEW
	icon.custom_minimum_size = Vector2(64, 64)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)

	var lbl := Label.new()
	lbl.text = _class_label(cls_id)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lbl)

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_modal_class = cls_id
			_refresh_modal_class_cards()
	)
	return card

func _refresh_modal_class_cards() -> void:
	for k in _modal_class_cards.keys():
		_apply_card_style(_modal_class_cards[k], str(k) == _modal_class)

func _make_faction_card(fac_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 60)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var lbl := Label.new()
	lbl.text = "Запад" if fac_id == "west" else "Восток"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.85, 1.0) if fac_id == "west" else Color(1.0, 0.65, 0.55))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lbl)
	var hint := Label.new()
	hint.text = "синие союзники" if fac_id == "west" else "красные союзники"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint)
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_modal_faction = fac_id
			_refresh_modal_faction_cards()
	)
	return card

func _refresh_modal_faction_cards() -> void:
	for k in _modal_faction_cards.keys():
		_apply_card_style(_modal_faction_cards[k], str(k) == _modal_faction)

func _submit_create() -> void:
	var nm := _modal_name.text.strip_edges()
	if nm.length() < 3 or nm.length() > 20:
		_modal_error.text = "Имя: 3-20 символов"
		return
	_modal_error.text = ""
	var payload := JSON.stringify({ "name": nm, "class": _modal_class, "faction": _modal_faction })
	var res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "character_create", payload)
	if res == null or res.is_exception():
		_modal_error.text = "Сеть: не получилось"
		return
	var d: Variant = JSON.parse_string(res.payload)
	if typeof(d) != TYPE_DICTIONARY:
		_modal_error.text = "Сервер вернул мусор"
		return
	if not d.get("ok", false):
		var reason := str(d.get("reason", ""))
		_modal_error.text = {
			"name_taken": "Имя занято",
			"bad_name": "Недопустимое имя",
			"unknown_class": "Неизвестный класс",
			"char_limit": "Достигнут лимит (%d)" % int(d.get("limit", 5)),
		}.get(reason, "Ошибка: " + reason)
		return
	_modal.visible = false
	_modal.queue_free()
	_modal = null
	await _refresh_from_server()
	# Если сервер сам активизировал нового — выделить его.
	if d.has("id"):
		_set_selected(str(d["id"]))
