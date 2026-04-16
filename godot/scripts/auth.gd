# Тестовый вход без пароля. Имя сохраняется в localStorage браузера —
# при повторном заходе предлагаем продолжить или сменить ник.
extends Control

signal auth_changed

@onready var title: Label = %Title
@onready var hint: Label = %Hint
@onready var name_input: LineEdit = %NameInput
@onready var enter_btn: Button = %EnterBtn
@onready var switch_btn: Button = %SwitchBtn
@onready var error_label: Label = %ErrorLabel
@onready var busy_label: Label = %BusyLabel

const STORAGE_KEY := "gg_player_name"
var saved_name: String = ""

func _ready() -> void:
	enter_btn.pressed.connect(_on_enter)
	switch_btn.pressed.connect(_on_switch)
	name_input.text_submitted.connect(func(_t): _on_enter())
	busy_label.hide()
	error_label.text = ""
	saved_name = _read_storage()
	_apply_mode()

func _apply_mode() -> void:
	if saved_name != "":
		title.text = "Продолжить как %s?" % saved_name
		hint.text = "Сохранённый персонаж в этом браузере"
		name_input.visible = false
		enter_btn.text = "Войти как %s" % saved_name
		switch_btn.visible = true
	else:
		title.text = "Введи имя"
		hint.text = "Тестовый режим — пароля нет"
		name_input.visible = true
		enter_btn.text = "Играть"
		switch_btn.visible = false
		name_input.grab_focus()

func _on_switch() -> void:
	saved_name = ""
	name_input.text = ""
	_apply_mode()

func _set_busy(busy: bool) -> void:
	enter_btn.disabled = busy
	switch_btn.disabled = busy
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
	while out.length() < 6:
		out += "_"
	if out.length() > 64:
		out = out.substr(0, 64)
	return out

func _on_enter() -> void:
	var raw: String = saved_name if saved_name != "" else name_input.text.strip_edges()
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
	_write_storage(raw)
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
