# UI группы: модалка входящего приглашения + панель участников слева
# под nameplate-статусом.
class_name PartyUI
extends CanvasLayer

signal invite_accepted(from_sid: String)
signal invite_declined(from_sid: String)
signal party_leave_requested

var _root: Control
# Панель участников (слева, под nameplate ≈ y=110).
var _party_panel: PanelContainer
var _party_list: VBoxContainer
var _leave_btn: Button
# Модалка приглашения.
var _invite_modal: PanelContainer
var _invite_label: Label
var _invite_from_sid: String = ""

func _ready() -> void:
	layer = 17
	_root = Control.new()
	_root.anchor_right = 1.0; _root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_party_panel()
	_build_invite_modal()

func _build_party_panel() -> void:
	_party_panel = PanelContainer.new()
	_party_panel.anchor_left = 0.0; _party_panel.anchor_top = 0.0
	_party_panel.offset_left = 8
	_party_panel.offset_top = 120  # под nameplate
	_party_panel.offset_right = 248
	_party_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_party_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.08, 0.95)
	sb.border_color = Color(0.35, 0.65, 0.40, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	_party_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_party_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_party_panel.add_child(v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	v.add_child(header)
	var t := Label.new()
	t.text = "Группа"
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	_leave_btn = Button.new()
	_leave_btn.text = "Выйти"
	_leave_btn.focus_mode = Control.FOCUS_NONE
	_leave_btn.add_theme_font_size_override("font_size", 10)
	_leave_btn.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45))
	_leave_btn.custom_minimum_size = Vector2(52, 20)
	_leave_btn.pressed.connect(func(): party_leave_requested.emit())
	header.add_child(_leave_btn)

	_party_list = VBoxContainer.new()
	_party_list.add_theme_constant_override("separation", 3)
	v.add_child(_party_list)

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

func show_invite(from_sid: String, from_name: String) -> void:
	_invite_from_sid = from_sid
	_invite_label.text = "%s приглашает в группу" % from_name
	_invite_modal.visible = true

func hide_invite() -> void:
	_invite_modal.visible = false
	_invite_from_sid = ""

# members: Array of dicts {sid, name, level, hp, hpMax}. my_sid — чтобы
# подсветить себя и не показывать «выйти» если мы одни.
func update_party(members: Array, my_sid: String) -> void:
	for c in _party_list.get_children():
		c.queue_free()
	if members.is_empty():
		_party_panel.visible = false
		return
	_party_panel.visible = true
	for m in members:
		var row := _make_member_row(m, my_sid)
		_party_list.add_child(row)

func _make_member_row(m: Dictionary, my_sid: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)
	var name_lbl := Label.new()
	name_lbl.text = str(m.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 12)
	var mine := str(m.get("sid", "")) == my_sid
	name_lbl.add_theme_color_override("font_color",
		Color(1.0, 1.0, 0.6) if mine else Color(0.9, 0.95, 0.9))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var lvl_lbl := Label.new()
	lvl_lbl.text = "Ур. %d" % int(m.get("level", 1))
	lvl_lbl.add_theme_font_size_override("font_size", 10)
	lvl_lbl.add_theme_color_override("font_color", Color(0.99, 0.89, 0.51))
	top.add_child(lvl_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = max(1, int(m.get("hpMax", 1)))
	hp_bar.value = clamp(int(m.get("hp", 0)), 0, int(m.get("hpMax", 1)))
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(220, 8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.55, 0.85, 0.45, 1.0)
	fg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", fg)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.10, 1.0)
	bg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", bg)
	v.add_child(hp_bar)

	return v
