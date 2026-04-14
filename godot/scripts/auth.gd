# Тестовый вход без пароля. Ввёл имя — получил персонаж 1 уровня.
# Используем authenticateCustom: id = слаг от имени, username = имя.
extends Control

signal auth_changed

@onready var name_input: LineEdit = %NameInput
@onready var enter_btn: Button = %EnterBtn
@onready var error_label: Label = %ErrorLabel
@onready var busy_label: Label = %BusyLabel

func _ready() -> void:
	enter_btn.pressed.connect(_on_enter)
	name_input.text_submitted.connect(func(_t): _on_enter())
	busy_label.hide()
	error_label.text = ""
	name_input.grab_focus()

func _set_busy(busy: bool) -> void:
	enter_btn.disabled = busy
	busy_label.visible = busy

func _slug(s: String) -> String:
	# Кастомный id Nakama: 6-128 символов, ASCII. Берём lower+латиницу/цифры/_,
	# остальное — заменяем нижним подчёркиванием. Дополняем "_test" чтобы было ≥6.
	var lo := s.to_lower().strip_edges()
	var out := ""
	for ch in lo:
		var c := ch.unicode_at(0)
		if (c >= 0x30 and c <= 0x39) or (c >= 0x61 and c <= 0x7a):
			out += ch
		else:
			out += "_"
	while out.length() < 6:
		out += "_"
	if out.length() > 64:
		out = out.substr(0, 64)
	return out

func _on_enter() -> void:
	var raw := name_input.text.strip_edges()
	if raw.length() < 2:
		error_label.text = "Минимум 2 символа"
		return
	error_label.text = ""
	_set_busy(true)
	var session: NakamaSession = await Session.client.authenticate_custom_async(_slug(raw), raw, true)
	_set_busy(false)
	if session.is_exception():
		error_label.text = "Ошибка: " + session.get_exception().message
		return
	Session.auth = session
	auth_changed.emit()
