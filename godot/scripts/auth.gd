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
	_build_game_title()
	_spawn_ether_particles()
	_apply_card_style()
	enter_btn.pressed.connect(func(): _do_login_action())
	register_btn.pressed.connect(func(): _do_register_action())
	pass_input.text_submitted.connect(func(_t): _do_login_action())
	busy_label.hide()
	error_label.text = ""
	title.text = "Вход / Регистрация"
	hint.text = "E-mail и пароль (мин %d символов)" % MIN_PASSWORD_LEN
	name_input.placeholder_text = "E-mail"
	pass_input.secret = true

# Большой титул «Aetherlands» — градиентный текст с золотистой обводкой,
# плюс подзаголовок. Кладём отдельным Control-ом, чтобы не трогать Card.
func _build_game_title() -> void:
	var holder := Control.new()
	holder.name = "GameTitle"
	holder.anchor_left = 0.5; holder.anchor_top = 0.0
	holder.anchor_right = 0.5; holder.anchor_bottom = 0.0
	holder.offset_left = -260; holder.offset_top = 30
	holder.offset_right = 260; holder.offset_bottom = 130
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var game_title := Label.new()
	game_title.text = "Aetherlands"
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	game_title.anchor_right = 1.0; game_title.anchor_bottom = 1.0
	game_title.add_theme_font_size_override("font_size", 56)
	game_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	game_title.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.15, 1.0))
	game_title.add_theme_constant_override("outline_size", 8)
	holder.add_child(game_title)

	var subtitle := Label.new()
	subtitle.text = "земли эфира"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.anchor_right = 1.0; subtitle.anchor_bottom = 1.0
	subtitle.offset_top = 70
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0, 0.95))
	subtitle.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.12, 0.9))
	subtitle.add_theme_constant_override("outline_size", 3)
	holder.add_child(subtitle)

# Лёгкий эфирный шум: 40 медленно плывущих точек поверх фона. Чистый
# процедурный визуал, без новых ассетов — даёт ощущение тумана/частиц
# пока Вова не подменит auth_bg.png на тематическую картинку.
func _spawn_ether_particles() -> void:
	var layer := Control.new()
	layer.name = "EtherParticles"
	layer.anchor_right = 1.0; layer.anchor_bottom = 1.0
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = -5  # под картой ввода, но над фоном
	add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(40):
		var dot := ColorRect.new()
		var size: float = rng.randf_range(2.0, 6.0)
		dot.size = Vector2(size, size)
		dot.color = Color(0.55, 0.80, 1.0, rng.randf_range(0.25, 0.55))
		var sx: float = rng.randf_range(0.0, 800.0)
		var sy: float = rng.randf_range(0.0, 608.0)
		dot.position = Vector2(sx, sy)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(dot)
		var tw := create_tween()
		tw.set_loops()
		var dur := rng.randf_range(3.5, 7.0)
		tw.tween_property(dot, "position:y", sy - 80.0, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(dot, "position:y", sy, dur).set_trans(Tween.TRANS_SINE)
		var tw2 := create_tween()
		tw2.set_loops()
		tw2.tween_property(dot, "modulate:a", 0.15, dur * 0.6).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(dot, "modulate:a", 1.0, dur * 0.6).set_trans(Tween.TRANS_SINE)

	var saved := Session.get_saved_email()
	if saved != "":
		name_input.text = saved

	if _is_mobile_web():
		_mount_html_form(saved)
	else:
		name_input.grab_focus() if saved == "" else pass_input.grab_focus()

func _apply_card_style() -> void:
	# Карточка — без фона, без рамки: чтобы не перекрывать красивый фон.
	# Остаются только поля ввода и кнопки (у них свои стили для читаемости).
	var card := get_node_or_null("Card")
	if card == null: return
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	# Тексту (заголовок/подсказка/ошибка) добавим чёрный outline,
	# чтобы читались поверх любой части фона.
	if title:
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		title.add_theme_constant_override("outline_size", 4)
	if hint:
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		hint.add_theme_constant_override("outline_size", 3)
	if error_label:
		error_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		error_label.add_theme_constant_override("outline_size", 3)
	if busy_label:
		busy_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		busy_label.add_theme_constant_override("outline_size", 3)
	# Поля ввода: тёмный фон + золотая обводка.
	var inputs := [name_input, pass_input]
	for inp in inputs:
		var ib := StyleBoxFlat.new()
		ib.bg_color = Color(0.07, 0.06, 0.04, 1)
		ib.border_color = Color(0.55, 0.40, 0.20, 1)
		ib.set_border_width_all(1)
		ib.set_corner_radius_all(4)
		ib.set_content_margin_all(8)
		var ib_focus := ib.duplicate() as StyleBoxFlat
		ib_focus.border_color = Color(0.95, 0.75, 0.35, 1)
		ib_focus.set_border_width_all(2)
		inp.add_theme_stylebox_override("normal", ib)
		inp.add_theme_stylebox_override("focus", ib_focus)
		inp.add_theme_color_override("font_color", Color(1, 0.96, 0.88, 1))
		inp.add_theme_color_override("font_placeholder_color", Color(0.6, 0.55, 0.45, 1))
		inp.add_theme_font_size_override("font_size", 14)
	# Кнопки: деревянная тема.
	_style_button(enter_btn, Color(0.28, 0.50, 0.76), Color(0.38, 0.62, 0.90), Color(1, 1, 1))
	_style_button(register_btn, Color(0.24, 0.48, 0.22), Color(0.34, 0.62, 0.30), Color(0.85, 1, 0.85))

func _style_button(btn: Button, bg: Color, hover: Color, text_col: Color) -> void:
	var s_n := StyleBoxFlat.new()
	s_n.bg_color = bg
	s_n.border_color = Color(0.25, 0.18, 0.10, 1)
	s_n.set_border_width_all(1)
	s_n.set_corner_radius_all(6)
	s_n.set_content_margin_all(8)
	var s_h := s_n.duplicate() as StyleBoxFlat
	s_h.bg_color = hover
	var s_p := s_n.duplicate() as StyleBoxFlat
	s_p.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("normal", s_n)
	btn.add_theme_stylebox_override("hover", s_h)
	btn.add_theme_stylebox_override("pressed", s_p)
	btn.add_theme_stylebox_override("focus", s_h)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)

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
