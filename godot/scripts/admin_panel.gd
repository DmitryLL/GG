# Внутриигровая админ-панель (F12) — список игроков + выдача золота/предметов.
class_name AdminPanel
extends CanvasLayer

const ADMIN_USERNAMES = ["dmitryll", "admin"]

# Популярные предметы для быстрой выдачи
const QUICK_ITEMS := [
	"golden_sword", "golden_bow", "iron_bow", "wood_bow",
	"golden_armor", "golden_helmet", "golden_boots", "golden_belt",
	"royal_cloak", "golden_amulet", "golden_ring",
	"great_potion", "health_potion",
]

var root_ctrl: Control
var panel: PanelContainer
var tabs: TabContainer
var self_tab: VBoxContainer
var users_tab: VBoxContainer
var users_list: VBoxContainer
var refresh_btn: Button
var log_label: Label
var visible_now := false

signal action_requested(action: String, payload: Dictionary)

func _ready() -> void:
	layer = 20
	root_ctrl = Control.new()
	root_ctrl.anchor_right = 1.0
	root_ctrl.anchor_bottom = 1.0
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.offset_left = -360
	panel.offset_top = 90
	panel.offset_right = -10
	panel.offset_bottom = 540
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.06, 0.06, 0.95)
	sb.border_color = Color(0.85, 0.25, 0.25, 1)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	root_ctrl.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "АДМИНКА (F12)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 360)
	outer.add_child(tabs)

	# --- Tab 1: Себе ---
	self_tab = VBoxContainer.new()
	self_tab.name = "Себе"
	self_tab.add_theme_constant_override("separation", 5)
	tabs.add_child(self_tab)
	_add_self_button("Полное лечение", "heal_self")
	_add_self_button("+1000 золота", "give_gold_self")
	_add_self_button("Выдать Золотой лук", "give_golden_bow_self")
	_add_self_button("+5 уровней", "level_up")
	_add_self_button("Телепорт под курсор", "teleport_cursor")

	# --- Tab 2: Игроки ---
	users_tab = VBoxContainer.new()
	users_tab.name = "Игроки"
	users_tab.add_theme_constant_override("separation", 4)
	tabs.add_child(users_tab)

	refresh_btn = Button.new()
	refresh_btn.text = "↻ Обновить список"
	refresh_btn.pressed.connect(_refresh_users)
	users_tab.add_child(refresh_btn)

	var users_scroll := ScrollContainer.new()
	users_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	users_tab.add_child(users_scroll)
	users_list = VBoxContainer.new()
	users_list.add_theme_constant_override("separation", 2)
	users_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	users_scroll.add_child(users_list)

	# --- Tab 3: Моб/мир ---
	var world_tab := VBoxContainer.new()
	world_tab.name = "Мир"
	world_tab.add_theme_constant_override("separation", 5)
	tabs.add_child(world_tab)
	var wb1 := Button.new(); wb1.text = "Лечить всех онлайн"
	wb1.pressed.connect(_emit_simple.bind("heal_all"))
	world_tab.add_child(wb1)
	var wb2 := Button.new(); wb2.text = "Убить всех мобов"
	wb2.pressed.connect(_emit_simple.bind("killall_mobs"))
	world_tab.add_child(wb2)
	var wb3 := Button.new(); wb3.text = "Мгновенный респавн"
	wb3.pressed.connect(_emit_simple.bind("respawn_mobs"))
	world_tab.add_child(wb3)

	log_label = Label.new()
	log_label.text = ""
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(340, 0)
	outer.add_child(log_label)

func _add_self_button(text: String, action: String) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(_emit_simple.bind(action))
	self_tab.add_child(b)

func _emit_simple(action: String) -> void:
	action_requested.emit(action, {})

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		if not is_admin():
			return
		visible_now = not visible_now
		panel.visible = visible_now
		if visible_now and users_list.get_child_count() == 0:
			_refresh_users()

func is_admin() -> bool:
	var name: String = String(Session.auth.username if Session.auth else "").to_lower()
	return ADMIN_USERNAMES.has(name)

func _refresh_users() -> void:
	for c in users_list.get_children():
		c.queue_free()
	action_requested.emit("list_users", {})

func set_users(users: Array) -> void:
	for c in users_list.get_children():
		c.queue_free()
	for u in users:
		var row := PanelContainer.new()
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.2, 0.1, 0.1, 0.9)
		rsb.set_content_margin_all(6)
		rsb.set_corner_radius_all(3)
		row.add_theme_stylebox_override("panel", rsb)
		users_list.add_child(row)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		row.add_child(v)

		var lbl := Label.new()
		lbl.text = "%s  lv%d  gold=%d" % [u.get("name", "?"), int(u.get("level", 1)), int(u.get("gold", 0))]
		lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		v.add_child(lbl)

		var row_btns := HBoxContainer.new()
		row_btns.add_theme_constant_override("separation", 3)
		v.add_child(row_btns)

		var b_gold := Button.new()
		b_gold.text = "+1000 gold"
		b_gold.pressed.connect(func(): action_requested.emit("give_gold_to", {"target": u.get("name", "")}))
		row_btns.add_child(b_gold)

		var b_lvl := Button.new()
		b_lvl.text = "+5 lv"
		b_lvl.pressed.connect(func(): action_requested.emit("level_up_to", {"target": u.get("name", ""), "delta": 5}))
		row_btns.add_child(b_lvl)

		var item_picker := OptionButton.new()
		item_picker.custom_minimum_size = Vector2(130, 0)
		for it in QUICK_ITEMS:
			item_picker.add_item(it)
		v.add_child(item_picker)

		var b_item := Button.new()
		b_item.text = "Выдать выбранное"
		b_item.pressed.connect(func():
			var idx := item_picker.get_selected_id()
			if idx < 0: idx = item_picker.selected
			var it: String = QUICK_ITEMS[clamp(idx, 0, QUICK_ITEMS.size() - 1)]
			action_requested.emit("give_item_to", {"target": u.get("name", ""), "itemId": it})
		)
		v.add_child(b_item)

func log_result(text: String) -> void:
	log_label.text = text
