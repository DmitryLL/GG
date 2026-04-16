# Логин по нику + паролю через Nakama authenticate_email.
# Email синтезируется из ника: <slug>@gg.local — для пользователя
# виден только ник, email скрыт.
extends Control

signal auth_changed

@onready var title: Label = %Title
@onready var hint: Label = %Hint
@onready var name_input: LineEdit = %NameInput
@onready var pass_input: LineEdit = %PassInput
@onready var enter_btn: Button = %EnterBtn
@onready var register_btn: Button = %RegisterBtn
@onready var error_label: Label = %ErrorLabel
@onready var busy_label: Label = %BusyLabel

const STORAGE_KEY := "gg_player_name"

func _ready() -> void:
	enter_btn.pressed.connect(func(): _login(false))
	register_btn.pressed.connect(func(): _login(true))
	pass_input.text_submitted.connect(func(_t): _login(false))
	busy_label.hide()
	error_label.text = ""
	title.text = "Вход / Регистрация"
	hint.text = "Введи ник и пароль. Если ника нет — нажми «Регистрация»."
	pass_input.secret = true
	# Подставляем сохранённый ник
	var saved := _read_storage()
	if saved != "":
		name_input.text = saved
		pass_input.grab_focus()
	else:
		name_input.grab_focus()

func _set_busy(busy: bool) -> void:
	enter_btn.disabled = busy
	register_btn.disabled = busy
	busy_label.visible = busy

func _slug(s: String) -> String:
	var lo := s.to_lower().strip_edges()
	var out := ""
	for ch in lo:
		var c := ch.unicode_at(0)
		if (c >= 0x30 and c <= 0x39) or (c >= 0x61 and c <= 0x7a):
			out += ch
		else:
			out += "_"
	while out.length() < 3:
		out += "_"
	if out.length() > 60:
		out = out.substr(0, 60)
	return out

func _make_email(nick: String) -> String:
	return "%s@gg.local" % _slug(nick)

func _login(create: bool) -> void:
	var nick := name_input.text.strip_edges()
	var pwd := pass_input.text
	if nick.length() < 2:
		error_label.text = "Имя минимум 2 символа"
		return
	if pwd.length() < 1:
		error_label.text = "Введи пароль"
		return
	error_label.text = ""
	_set_busy(true)
	var email := _make_email(nick)
	var session: NakamaSession = await Session.client.authenticate_email_async(email, pwd, nick, create)
	_set_busy(false)
	if session.is_exception():
		var err := session.get_exception()
		var msg := err.message
		# Дружелюбные сообщения
		if "exists" in msg.to_lower():
			error_label.text = "Этот ник занят (другой пароль)"
		elif "invalid" in msg.to_lower() or "credentials" in msg.to_lower():
			error_label.text = "Неверный пароль"
		elif "not found" in msg.to_lower():
			error_label.text = "Юзер не найден — нажми «Регистрация»"
		else:
			error_label.text = "Ошибка: " + msg
		return
	_write_storage(nick)
	Session.auth = session
	auth_changed.emit()

func _read_storage() -> String:
	if not OS.has_feature("web"):
		return ""
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if bridge == null:
		return ""
	var v = JavaScriptBridge.eval("window.localStorage.getItem('%s') || ''" % STORAGE_KEY, true)
	return String(v) if v != null else ""

func _write_storage(nick: String) -> void:
	if not OS.has_feature("web"):
		return
	var safe := nick.replace("'", "\\'")
	JavaScriptBridge.eval("window.localStorage.setItem('%s', '%s')" % [STORAGE_KEY, safe], true)
