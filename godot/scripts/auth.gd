# Вход по нику + паролю через Nakama authenticate_email.
# На мобильных браузерах отрисовываем HTML-форму поверх canvas —
# настоящая клавиатура открывается автоматически при тапе на input.
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

var _mobile_form_active := false
var _js_callback: JavaScriptObject = null

func _ready() -> void:
	enter_btn.pressed.connect(func(): _login(false))
	register_btn.pressed.connect(func(): _login(true))
	pass_input.text_submitted.connect(func(_t): _login(false))
	busy_label.hide()
	error_label.text = ""
	title.text = "Вход / Регистрация"
	hint.text = "Введи ник и пароль. Если ника нет — «Регистрация»."
	pass_input.secret = true

	var saved := _read_storage()
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

func _mount_html_form(saved_nick: String) -> void:
	# Создаём HTML-колбэк — JS → Godot. Передаётся через глобальный callback.
	_js_callback = JavaScriptBridge.create_callback(_on_html_submit)
	JavaScriptBridge.get_interface("window").__ggAuthGodotCb = _js_callback
	# Скрываем Godot форму — её заменит HTML
	var canvas_layer := Control.new()  # dummy; сама Godot-сцена просто невидима через css
	# Проще: скрываем canvas, показываем HTML overlay
	var escaped_nick := saved_nick.replace("'", "\\'").replace('"', '\\"')
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
			+ '<p style=\"color:#888;margin:0 0 18px;text-align:center;font-size:13px;\">Введи ник и пароль</p>'
			+ '<input id=\"gg-nick\" type=\"text\" autocomplete=\"username\" placeholder=\"Никнейм\" value=\"%s\" '
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
			if (n.length < 2) { err.textContent = 'Имя минимум 2 символа'; return; }
			if (p.length < 1) { err.textContent = 'Введи пароль'; return; }
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
	""" % escaped_nick
	JavaScriptBridge.eval(js, true)
	_mobile_form_active = true

func _on_html_submit(args: Array) -> void:
	var nick: String = String(args[0])
	var pwd: String = String(args[1])
	var create: bool = int(args[2]) != 0
	await _do_login(nick, pwd, create)

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

func _login(create: bool) -> void:
	await _do_login(name_input.text.strip_edges(), pass_input.text, create)

func _do_login(nick: String, pwd: String, create: bool) -> void:
	if nick.length() < 2:
		_show_error("Имя минимум 2 символа")
		return
	if pwd.length() < 1:
		_show_error("Введи пароль")
		return
	_show_error("")
	_set_busy(true)
	var email := "%s@gg.local" % _slug(nick)
	var session: NakamaSession = await Session.client.authenticate_email_async(email, pwd, nick, create)
	_set_busy(false)
	if session.is_exception():
		var err_msg: String = session.get_exception().message
		var lower := err_msg.to_lower()
		# При нажатии «Регистрация» ошибка credentials почти всегда означает,
		# что ник уже занят другим паролем: Nakama пытается залогинить и
		# получает Invalid credentials. Показываем честное сообщение.
		if create:
			if "exists" in lower or "invalid" in lower or "credentials" in lower or "password" in lower:
				_show_error("Ник уже занят — выбери другой или нажми «Войти»")
			else:
				_show_error("Ошибка регистрации: " + err_msg)
		else:
			if "exists" in lower:
				_show_error("Ник занят (другой пароль)")
			elif "invalid" in lower or "credentials" in lower or "password" in lower:
				_show_error("Неверный пароль")
			elif "not found" in lower:
				_show_error("Юзер не найден — нажми «Регистрация»")
			else:
				_show_error("Ошибка: " + err_msg)
		return
	_write_storage(nick)
	if _mobile_form_active:
		JavaScriptBridge.eval("window.__ggAuthUnmount && window.__ggAuthUnmount()", true)
		_mobile_form_active = false
	Session.auth = session
	auth_changed.emit()

func _read_storage() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("window.localStorage.getItem('%s') || ''" % STORAGE_KEY, true)
	return String(v) if v != null else ""

func _write_storage(nick: String) -> void:
	if not OS.has_feature("web"):
		return
	var safe := nick.replace("'", "\\'")
	JavaScriptBridge.eval("window.localStorage.setItem('%s', '%s')" % [STORAGE_KEY, safe], true)
