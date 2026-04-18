# Вход/регистрация по e-mail + паролю через Nakama authenticate_email.
# Без верификации почты (Nakama её и не требует).
# При «Войти» — единое сообщение об ошибке без раскрытия, существует ли юзер.
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

const MIN_PASSWORD_LEN := 6

var _mobile_form_active := false
var _js_callback: JavaScriptObject = null

func _ready() -> void:
	enter_btn.pressed.connect(func(): _do_login_action())
	register_btn.pressed.connect(func(): _do_register_action())
	pass_input.text_submitted.connect(func(_t): _do_login_action())
	busy_label.hide()
	error_label.text = ""
	title.text = "Вход / Регистрация"
	hint.text = "E-mail и пароль (мин %d символов)" % MIN_PASSWORD_LEN
	name_input.placeholder_text = "E-mail"
	pass_input.secret = true

	var saved := Session.get_saved_email()
	if saved != "":
		name_input.text = saved

	if _is_mobile_web():
		_mount_html_form(saved)
	else:
		name_input.grab_focus() if saved == "" else pass_input.grab_focus()

func _exit_tree() -> void:
	if _mobile_form_active:
		JavaScriptBridge.eval("window.__ggAuthUnmount && window.__ggAuthUnmount()", true)

func _is_mobile_web() -> bool:
	if not OS.has_feature("web"):
		return false
	var code := """(function(){
		var ua = (navigator.userAgent || '').toLowerCase();
		var isMobileUA = /android|iphone|ipad|ipod|mobile|tablet/.test(ua);
		var hasTouch = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0);
		var isSmall = Math.min(window.innerWidth, window.innerHeight) < 900;
		return isMobileUA || (hasTouch && isSmall);
	})()"""
	var r: Variant = JavaScriptBridge.eval(code, true)
	return bool(r)

func _mount_html_form(saved_email: String) -> void:
	_js_callback = JavaScriptBridge.create_callback(_on_html_submit)
	JavaScriptBridge.get_interface("window").__ggAuthGodotCb = _js_callback
	var escaped := saved_email.replace("'", "\\'").replace('"', '\\"')
	var js := """
	(function(){
		if (window.__ggAuthMounted) return;
		window.__ggAuthMounted = true;
		var c = document.getElementById('canvas');
		if (c) c.style.display = 'none';
		var overlay = document.createElement('div');
		overlay.id = 'gg-auth-overlay';
		overlay.style.cssText = 'position:fixed;inset:0;background:#0f0f0f;display:flex;align-items:center;justify-content:center;z-index:1000;font-family:system-ui,sans-serif;';
		overlay.innerHTML = ''
			+ '<div style=\"background:#1a1a1a;padding:24px;border-radius:10px;width:min(90vw,340px);\">'
			+ '<h2 style=\"color:#eee;margin:0 0 4px;text-align:center;\">Вход / Регистрация</h2>'
			+ '<p style=\"color:#888;margin:0 0 18px;text-align:center;font-size:13px;\">E-mail и пароль (мин 6 символов)</p>'
			+ '<input id=\"gg-nick\" type=\"email\" autocomplete=\"email\" placeholder=\"E-mail\" value=\"%s\" '
			+ 'style=\"display:block;width:100%%;box-sizing:border-box;padding:12px;margin-bottom:10px;font-size:16px;background:#2a2a2a;color:#eee;border:1px solid #444;border-radius:6px;\">'
			+ '<input id=\"gg-pwd\" type=\"password\" autocomplete=\"current-password\" placeholder=\"Пароль\" '
			+ 'style=\"display:block;width:100%%;box-sizing:border-box;padding:12px;margin-bottom:14px;font-size:16px;background:#2a2a2a;color:#eee;border:1px solid #444;border-radius:6px;\">'
			+ '<button id=\"gg-login\" style=\"display:block;width:100%%;padding:12px;font-size:16px;background:#3a5a8a;color:#fff;border:none;border-radius:6px;margin-bottom:8px;cursor:pointer;\">Войти</button>'
			+ '<button id=\"gg-register\" style=\"display:block;width:100%%;padding:12px;font-size:16px;background:#2a6a3a;color:#fff;border:none;border-radius:6px;margin-bottom:10px;cursor:pointer;\">Регистрация</button>'
			+ '<div id=\"gg-err\" style=\"color:#f77;text-align:center;font-size:13px;min-height:18px;\"></div>'
			+ '</div>';
		document.body.appendChild(overlay);
		var nick = document.getElementById('gg-nick');
		var pwd = document.getElementById('gg-pwd');
		var err = document.getElementById('gg-err');
		function submit(create){
			err.textContent = '';
			var n = (nick.value || '').trim();
			var p = pwd.value || '';
			if (window.__ggAuthGodotCb) window.__ggAuthGodotCb(n, p, create ? 1 : 0);
		}
		document.getElementById('gg-login').addEventListener('click', function(){ submit(false); });
		document.getElementById('gg-register').addEventListener('click', function(){ submit(true); });
		pwd.addEventListener('keydown', function(e){ if (e.key === 'Enter') submit(false); });
		window.__ggAuthSetError = function(m){ err.textContent = m; };
		window.__ggAuthSetBusy = function(b){
			document.getElementById('gg-login').disabled = b;
			document.getElementById('gg-register').disabled = b;
		};
		window.__ggAuthUnmount = function(){
			if (window.__ggAuthMounted !== true) return;
			overlay.remove();
			if (c) c.style.display = 'block';
			window.__ggAuthMounted = false;
		};
		(n ? pwd : nick).focus();
	})();
	""" % escaped
	JavaScriptBridge.eval(js, true)
	_mobile_form_active = true

func _on_html_submit(args: Array) -> void:
	var email: String = String(args[0])
	var pwd: String = String(args[1])
	var create: bool = int(args[2]) != 0
	if create:
		await _do_register(email, pwd)
	else:
		await _do_login(email, pwd)

func _set_busy(busy: bool) -> void:
	enter_btn.disabled = busy
	register_btn.disabled = busy
	busy_label.visible = busy
	if _mobile_form_active:
		JavaScriptBridge.eval("window.__ggAuthSetBusy && window.__ggAuthSetBusy(%s)" % ("true" if busy else "false"), true)

func _show_error(msg: String) -> void:
	error_label.text = msg
	if _mobile_form_active:
		var escaped := msg.replace("'", "\\'")
		JavaScriptBridge.eval("window.__ggAuthSetError && window.__ggAuthSetError('%s')" % escaped, true)

# ─── Валидация ───
func _valid_email(e: String) -> bool:
	# Минимальная проверка: есть @ и точка после него.
	var at := e.find("@")
	if at <= 0: return false
	var dot := e.find(".", at)
	return dot > at + 1 and dot < e.length() - 1

func _username_from_email(email: String) -> String:
	# Префикс до @ → в нижнем регистре → только буквы/цифры/подчёркивания.
	var prefix := email.substr(0, email.find("@")).to_lower()
	var out := ""
	for ch in prefix:
		var c := ch.unicode_at(0)
		if (c >= 0x30 and c <= 0x39) or (c >= 0x61 and c <= 0x7a):
			out += ch
		else:
			out += "_"
	while out.length() < 3: out += "_"
	if out.length() > 60: out = out.substr(0, 60)
	return out

# ─── Действия ───
func _do_login_action() -> void:
	await _do_login(name_input.text.strip_edges(), pass_input.text)

func _do_register_action() -> void:
	await _do_register(name_input.text.strip_edges(), pass_input.text)

func _do_login(email: String, pwd: String) -> void:
	# При «Войти» любая ошибка = единое сообщение без раскрытия существования юзера.
	if not _valid_email(email) or pwd.length() < MIN_PASSWORD_LEN:
		_show_error("Неверный логин или пароль")
		return
	_show_error("")
	_set_busy(true)
	var username := _username_from_email(email)
	var session: NakamaSession = await Session.client.authenticate_email_async(email, pwd, username, false)
	_set_busy(false)
	if session.is_exception():
		_show_error("Неверный логин или пароль")
		return
	_finalize(session, email)

func _do_register(email: String, pwd: String) -> void:
	if not _valid_email(email):
		_show_error("Неверный e-mail")
		return
	if pwd.length() < MIN_PASSWORD_LEN:
		_show_error("Пароль минимум %d символов" % MIN_PASSWORD_LEN)
		return
	_show_error("")
	_set_busy(true)
	var username := _username_from_email(email)
	var session: NakamaSession = await Session.client.authenticate_email_async(email, pwd, username, true)
	_set_busy(false)
	if session.is_exception():
		var lower := session.get_exception().message.to_lower()
		if "exists" in lower or "credentials" in lower or "invalid" in lower:
			_show_error("Такой e-mail уже зарегистрирован")
		else:
			_show_error("Ошибка регистрации")
		return
	_finalize(session, email)

func _finalize(session: NakamaSession, email: String) -> void:
	Session.auth = session
	Session.save_auth_to_storage(session)
	Session.save_email(email)
	if _mobile_form_active:
		JavaScriptBridge.eval("window.__ggAuthUnmount && window.__ggAuthUnmount()", true)
		_mobile_form_active = false
	auth_changed.emit()
