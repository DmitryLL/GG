# Simple email/password auth against Nakama. Emits auth_changed on success
# so Main can swap to the Game scene.
extends Control

signal auth_changed

@onready var email_input: LineEdit = %EmailInput
@onready var password_input: LineEdit = %PasswordInput
@onready var login_btn: Button = %LoginBtn
@onready var register_btn: Button = %RegisterBtn
@onready var error_label: Label = %ErrorLabel
@onready var busy_label: Label = %BusyLabel

func _ready() -> void:
	login_btn.pressed.connect(_on_login)
	register_btn.pressed.connect(_on_register)
	busy_label.hide()
	error_label.text = ""

func _set_busy(busy: bool) -> void:
	login_btn.disabled = busy
	register_btn.disabled = busy
	busy_label.visible = busy

func _show_error(msg: String) -> void:
	error_label.text = msg

func _validate() -> bool:
	var email := email_input.text.strip_edges()
	var password := password_input.text
	if email.length() < 3 or not email.contains("@"):
		_show_error("Введите корректный email")
		return false
	if password.length() < 6:
		_show_error("Пароль минимум 6 символов")
		return false
	_show_error("")
	return true

func _on_login() -> void:
	if not _validate(): return
	_set_busy(true)
	var session: NakamaSession = await Session.client.authenticate_email_async(
		email_input.text.strip_edges(),
		password_input.text,
		null,   # username
		false   # create=false, login only
	)
	_handle_auth(session)

func _on_register() -> void:
	if not _validate(): return
	_set_busy(true)
	var session: NakamaSession = await Session.client.authenticate_email_async(
		email_input.text.strip_edges(),
		password_input.text,
		null,
		true    # create=true
	)
	_handle_auth(session)

func _handle_auth(session: NakamaSession) -> void:
	_set_busy(false)
	if session.is_exception():
		_show_error("Ошибка: " + session.get_exception().message)
		return
	Session.auth = session
	auth_changed.emit()
