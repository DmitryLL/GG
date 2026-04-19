# Экран выбора/создания персонажа.
# Пока один вариант — Лучник. Позже сюда добавятся классы (мечник, маг и т.д.).
extends Control

signal auth_changed  # main.gd слушает этот сигнал для переезда на Game

@onready var list_root: HBoxContainer = %CharList
@onready var play_btn: Button = %PlayBtn
@onready var logout_btn: Button = %LogoutBtn
@onready var email_label: Label = %EmailLabel

const ARCHER_PREVIEW := preload("res://assets/sprites/ui/icon_character.png")

var _selected: String = "archer"

func _ready() -> void:
	if Session.auth:
		email_label.text = "Аккаунт: %s" % Session.get_saved_email()
	_build_cards()
	play_btn.pressed.connect(_on_play)
	logout_btn.pressed.connect(_on_logout)

func _build_cards() -> void:
	var chars := [
		{"id": "archer", "name": "Лучник", "desc": "Дальний бой, лук, 5 скиллов", "tex": ARCHER_PREVIEW},
	]
	for c in chars:
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.12, 0.08, 0.95)
		sb.border_color = Color(0.95, 0.75, 0.35, 1)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(200, 260)
		list_root.add_child(card)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(v)

		var icon := TextureRect.new()
		icon.texture = c["tex"]
		icon.custom_minimum_size = Vector2(96, 96)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = c["name"]
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = c["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(170, 0)
		v.add_child(desc_lbl)

func _on_play() -> void:
	Session.selected_character = _selected
	auth_changed.emit()

func _on_logout() -> void:
	Session.logout()
	auth_changed.emit()
