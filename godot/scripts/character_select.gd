# Экран выбора/создания персонажа.
# Классы: Лучник, Маг.
extends Control

signal auth_changed  # main.gd слушает этот сигнал для переезда на Game

@onready var list_root: HBoxContainer = %CharList
@onready var play_btn: Button = %PlayBtn
@onready var logout_btn: Button = %LogoutBtn
@onready var email_label: Label = %EmailLabel

const ARCHER_PREVIEW := preload("res://assets/sprites/ui/icon_character.png")
# Для мага переиспользуем иконку персонажа — отдельный арт появится позже.
const MAGE_PREVIEW := preload("res://assets/sprites/ui/icon_character.png")

var _selected: String = "archer"
var _cards: Dictionary = {}  # { class_id: PanelContainer }

func _ready() -> void:
	if Session.auth:
		email_label.text = "Аккаунт: %s" % Session.get_saved_email()
	_build_cards()
	play_btn.pressed.connect(_on_play)
	logout_btn.pressed.connect(_on_logout)

func _build_cards() -> void:
	var chars := [
		{"id": "archer", "name": "Лучник", "desc": "Дальний бой, лук, 5 скиллов", "tex": ARCHER_PREVIEW},
		{"id": "mage",   "name": "Маг",    "desc": "Магия стихий, 5 скиллов",    "tex": MAGE_PREVIEW},
	]
	for c in chars:
		var class_id: String = c["id"]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(200, 260)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		list_root.add_child(card)
		_cards[class_id] = card

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(v)

		var icon := TextureRect.new()
		icon.texture = c["tex"]
		icon.custom_minimum_size = Vector2(96, 96)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = c["name"]
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = c["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(170, 0)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(desc_lbl)

		# Кликабельность карточки: выбираем класс.
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_set_selected(class_id)
		)
	_set_selected(_selected)

func _set_selected(class_id: String) -> void:
	_selected = class_id
	for id in _cards.keys():
		var card: PanelContainer = _cards[id]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.12, 0.08, 0.95)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(14)
		if id == class_id:
			sb.border_color = Color(0.95, 0.75, 0.35, 1)  # выделение
		else:
			sb.border_color = Color(0.4, 0.32, 0.18, 1)
		card.add_theme_stylebox_override("panel", sb)

func _on_play() -> void:
	Session.selected_character = _selected
	# Фиксируем выбор класса на сервере. Если класс уже выбран ранее —
	# сервер вернёт locked:true и текущий класс; подстраиваемся.
	if Session.auth and Session.client:
		var payload := JSON.stringify({ "class": _selected })
		var res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "set_class", payload)
		if res and not res.is_exception():
			var d: Variant = JSON.parse_string(res.payload)
			if typeof(d) == TYPE_DICTIONARY:
				var actual: String = str(d.get("class", _selected))
				Session.selected_character = actual
	auth_changed.emit()

func _on_logout() -> void:
	Session.logout()
	auth_changed.emit()
