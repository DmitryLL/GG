# UI группы: модалка входящего приглашения + компактный список
# участников слева под nameplate. Без фона — только строки с
# иконкой класса, именем, уровнем, HP-bar, мана-bar и эффектами.
# Себя в списке не показываем — видим себя в собственной панели.
class_name PartyUI
extends CanvasLayer

signal invite_accepted(from_sid: String)
signal invite_declined(from_sid: String)
signal party_leave_requested

const ROW_BAR_WIDTH := 160

var _root: Control
# Панель участников (слева, под nameplate ≈ y=140).
var _party_panel: Control
var _party_list: VBoxContainer
# Модалка приглашения.
var _invite_modal: PanelContainer
var _invite_label: Label
var _invite_from_sid: String = ""

# Ссылки на game для чтения live-данных (HP/мана/эффекты берём из
# реального Player-ноды remotes[sid]/me, а не из snapshot-а).
var game: Node = null

func _ready() -> void:
	layer = 17
	_root = Control.new()
	_root.anchor_right = 1.0; _root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_party_panel()
	_build_invite_modal()

func _build_party_panel() -> void:
	# Без общей рамки: каждая строка участника — своя тёмная карточка
	# с зелёной обводкой. Так виджет «плавает» поверх мира, но каждый
	# участник чётко читается.
	_party_panel = Control.new()
	_party_panel.anchor_left = 0.0; _party_panel.anchor_top = 0.0
	_party_panel.offset_left = 8
	_party_panel.offset_top = 140  # под nameplate
	_party_panel.offset_right = 210
	_party_panel.offset_bottom = 600
	_party_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_party_panel.visible = false
	_root.add_child(_party_panel)

	# Без заголовка «Группа» и кнопки «Выйти» — только список карточек.
	# Каждая карточка сама по себе читается, это и есть «группа».
	_party_list = VBoxContainer.new()
	_party_list.add_theme_constant_override("separation", 4)
	_party_list.anchor_right = 1.0; _party_list.anchor_bottom = 1.0
	_party_panel.add_child(_party_list)

func _build_invite_modal() -> void:
	_invite_modal = PanelContainer.new()
	_invite_modal.anchor_left = 0.5; _invite_modal.anchor_top = 0.5
	_invite_modal.anchor_right = 0.5; _invite_modal.anchor_bottom = 0.5
	_invite_modal.offset_left = -180; _invite_modal.offset_top = -60
	_invite_modal.offset_right = 180; _invite_modal.offset_bottom = 60
	_invite_modal.mouse_filter = Control.MOUSE_FILTER_PASS
	_invite_modal.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.98)
	sb.border_color = Color(0.85, 0.65, 0.30, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	_invite_modal.add_theme_stylebox_override("panel", sb)
	_root.add_child(_invite_modal)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_invite_modal.add_child(col)

	_invite_label = Label.new()
	_invite_label.text = "…"
	_invite_label.add_theme_font_size_override("font_size", 14)
	_invite_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	_invite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_invite_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btn_row)

	var accept := Button.new()
	accept.text = "Принять"
	accept.custom_minimum_size = Vector2(110, 30)
	accept.pressed.connect(func():
		invite_accepted.emit(_invite_from_sid)
		_invite_modal.visible = false
	)
	btn_row.add_child(accept)

	var decline := Button.new()
	decline.text = "Отклонить"
	decline.custom_minimum_size = Vector2(110, 30)
	decline.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45))
	decline.pressed.connect(func():
		invite_declined.emit(_invite_from_sid)
		_invite_modal.visible = false
	)
	btn_row.add_child(decline)

# ─── Публичный API, вызываемый из game.gd при OP_PARTY_* ───

func set_game(g: Node) -> void:
	game = g

func show_invite(from_sid: String, from_name: String) -> void:
	_invite_from_sid = from_sid
	_invite_label.text = "%s приглашает в группу" % from_name
	_invite_modal.visible = true

func hide_invite() -> void:
	_invite_modal.visible = false
	_invite_from_sid = ""

# members: Array of dicts {sid, name, level, hp, hpMax, mp, mpMax, cls, effects}.
# my_sid — чтобы исключить себя из списка (я вижу себя в своей панели).
func update_party(members: Array, my_sid: String) -> void:
	for c in _party_list.get_children():
		c.queue_free()
	# Фильтруем: показываем только других участников группы.
	var others: Array = []
	for m in members:
		if str(m.get("sid", "")) != my_sid:
			others.append(m)
	if others.is_empty():
		_party_panel.visible = false
		return
	_party_panel.visible = true
	for m in others:
		_party_list.add_child(_make_member_row(m))

# Строим ряд компактно: сверху [class-icon] имя Ур.N, под ним HP-bar,
# под ним мана-bar, под ней эффекты. Обёрнуто в тёмную карточку с
# зелёной обводкой — чтобы читалось на любом фоне мира.
func _make_member_row(m: Dictionary) -> Control:
	var card := PanelContainer.new()
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.05, 0.08, 0.06, 0.78)
	card_sb.border_color = Color(0.40, 0.75, 0.45, 0.80)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(4)
	card_sb.set_content_margin_all(5)
	card.add_theme_stylebox_override("panel", card_sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)

	# Live-данные из Player-ноды, если он в remotes — там HP/мана/эффекты
	# обновляются каждый OP_POSITIONS. Snapshot из OP_PARTY_UPDATE — fallback.
	var sid := str(m.get("sid", ""))
	var live: Player = null
	if game != null and "remotes" in game:
		var rmt: Dictionary = game.remotes
		if rmt.has(sid):
			live = rmt[sid]

	var hp: float = live.hp if live != null else float(m.get("hp", 0))
	var hp_max: float = live.hp_max if live != null else float(m.get("hpMax", 1))
	var mp: int = live.mana if live != null else int(m.get("mp", 0))
	var mp_max: int = live.mana_max if live != null else int(m.get("mpMax", 1))
	var cls: String = live.char_class if live != null else String(m.get("cls", "archer"))
	var effects: Array = live.effects if live != null else Array(m.get("effects", []))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)

	var class_ic := TextureRect.new()
	var cls_path := "res://assets/sprites/skills/class_archer.png"
	if cls == "mage":
		cls_path = "res://assets/sprites/skills/class_mage.png"
	if ResourceLoader.exists(cls_path):
		class_ic.texture = load(cls_path)
	class_ic.custom_minimum_size = Vector2(16, 16)
	class_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(class_ic)

	var name_lbl := Label.new()
	name_lbl.text = str(m.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 0.90))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Ур.%d" % int(m.get("level", 1))
	lvl_lbl.add_theme_font_size_override("font_size", 10)
	lvl_lbl.add_theme_color_override("font_color", Color(0.99, 0.89, 0.51))
	lvl_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lvl_lbl.add_theme_constant_override("outline_size", 3)
	top.add_child(lvl_lbl)

	v.add_child(_build_stat_bar(
		hp, max(1.0, hp_max),
		Color(0.55, 0.85, 0.45, 1.0), Color(0.10, 0.10, 0.10, 1.0),
		9, "%d / %d" % [int(hp), int(hp_max)]
	))
	v.add_child(_build_stat_bar(
		float(mp), float(max(1, mp_max)),
		Color(0.35, 0.55, 0.95, 1.0), Color(0.08, 0.10, 0.14, 1.0),
		7, "%d / %d" % [mp, int(mp_max)]
	))

	# Эффекты показываем только если они есть — пустой ряд не занимает место.
	if not effects.is_empty():
		var eff_row := HBoxContainer.new()
		eff_row.add_theme_constant_override("separation", 1)
		eff_row.custom_minimum_size = Vector2(0, 14)
		for eff in effects:
			eff_row.add_child(_make_small_effect_icon(eff))
		v.add_child(eff_row)

	return card

func _build_stat_bar(value: float, maxv: float, fg: Color, bg: Color, height: int = 7, overlay_text: String = "") -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxv
	bar.value = clamp(value, 0.0, maxv)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(ROW_BAR_WIDTH, height)
	var fg_sb := StyleBoxFlat.new()
	fg_sb.bg_color = fg
	fg_sb.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fg_sb)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = bg
	bg_sb.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg_sb)
	if overlay_text != "":
		var lbl := Label.new()
		lbl.text = overlay_text
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(lbl)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bar

# Маленькая иконка баф/дебаф для строки группы. Fallback-символ если
# нет PNG (как в nameplate).
func _make_small_effect_icon(eff: Dictionary) -> Control:
	var kind := String(eff.get("kind", "buff"))
	var eff_type := String(eff.get("type", ""))
	var is_buff := kind == "buff"
	var col: Color = Color(0.30, 0.85, 0.35, 1.0) if is_buff else Color(0.95, 0.30, 0.28, 1.0)

	var wrap := Panel.new()
	wrap.custom_minimum_size = Vector2(12, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	wrap.add_theme_stylebox_override("panel", sb)

	var tex_path := "res://assets/sprites/ui/effect_%s.png" % eff_type
	if ResourceLoader.exists(tex_path):
		var icon := TextureRect.new()
		icon.texture = load(tex_path)
		icon.custom_minimum_size = Vector2(10, 10)
		icon.position = Vector2(1, 1)
		icon.size = Vector2(10, 10)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(icon)
	else:
		var sym_text := ""
		match eff_type:
			"empowered": sym_text = "⚔"
			"sprint":    sym_text = "»"
			"haste":     sym_text = "»"
			"regen":     sym_text = "+"
			"shield":    sym_text = "▲"
			"crit_buff": sym_text = "✧"
			"pierce":    sym_text = "↯"
			"poison":    sym_text = "☠"
			"stun":      sym_text = "✦"
			"fire":      sym_text = "✶"
			"slow":      sym_text = "▼"
		if sym_text != "":
			var sym := Label.new()
			sym.text = sym_text
			sym.add_theme_font_size_override("font_size", 9)
			sym.add_theme_color_override("font_color", col)
			sym.anchor_right = 1.0; sym.anchor_bottom = 1.0
			sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sym.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(sym)
	return wrap
