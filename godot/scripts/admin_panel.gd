# Внутриигровая админ-панель (F12) — список игроков + выдача золота/предметов.
class_name AdminPanel
extends CanvasLayer

const ADMIN_USERNAMES = ["dmitryll", "admin", "prod"]

# Все предметы — берутся из Items.DEFS при первом открытии
var QUICK_ITEMS: Array = []

func _build_items_list() -> void:
	if QUICK_ITEMS.size() > 0:
		return
	# Сортировка: оружие → броня → шлемы → сапоги → пояса → плащи → кольца → амулеты → зелья → материалы
	var groups := [
		["weapon", "sword"], ["weapon", "bow"],
		["body"], ["head"], ["boots"], ["belt"],
		["cloak"], ["ring"], ["amulet"],
		["consumable"], ["material"],
	]
	var all_ids: Array = Items.DEFS.keys()
	var added: Dictionary = {}
	for group in groups:
		for id in all_ids:
			if added.has(id): continue
			var def: Dictionary = Items.DEFS[id]
			var slot: String = String(def.get("slot", ""))
			var kind: String = String(def.get("kind", ""))
			var matches := false
			if group.size() == 1:
				matches = (slot == group[0]) or (kind == group[0])
			else:
				# weapon + sword/bow — проверяем имя
				matches = (slot == group[0]) and String(id).contains(group[1])
			if matches:
				QUICK_ITEMS.append(id)
				added[id] = true
	# Остальное в конец (если что-то пропустили)
	for id in all_ids:
		if not added.has(id):
			QUICK_ITEMS.append(id)

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

# === In-game map editor state ===
var map_edit_mode: bool = false       # game.gd читает это
var map_edit_brush: int = 0           # id из WorldData.Tile
var brush_size: int = 1               # 1, 3 или 5
var bucket_mode: bool = false         # ЛКМ = flood fill
var _edit_toggle_btn: Button
var _edit_brush_btns: Array = []
var _size_btns: Array = []
var _bucket_btn: Button

# Мобы: инструмент — "" / "add_slime" / "add_goblin" / "add_dummy" / "move" / "delete".
# Когда не пустая — клик в мире НЕ рисует тайл, а работает с мобами.
var mob_tool: String = ""
var _mob_tool_btns: Array = []

signal map_save_requested              # старая: скачать world.tmj в браузер
signal map_save_server_requested       # новая: записать в Nakama Storage
signal map_edit_mode_changed(on: bool) # для сетки-оверлея

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
	title.text = "АДМИНКА (` или F12)"
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

	# --- Tab 4: Карта (in-game editor) ---
	var map_tab := VBoxContainer.new()
	map_tab.name = "Карта"
	map_tab.add_theme_constant_override("separation", 5)
	tabs.add_child(map_tab)

	_edit_toggle_btn = Button.new()
	_edit_toggle_btn.text = "Редактировать карту: ВЫКЛ"
	_edit_toggle_btn.toggle_mode = true
	_edit_toggle_btn.pressed.connect(_toggle_map_edit)
	map_tab.add_child(_edit_toggle_btn)

	var hint := Label.new()
	hint.text = "ЛКМ — поставить выбранный тайл\nПКМ — заменить на траву"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	map_tab.add_child(hint)

	var brush_label := Label.new()
	brush_label.text = "Кисть:"
	brush_label.add_theme_font_size_override("font_size", 11)
	brush_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	map_tab.add_child(brush_label)

	var brushes := [
		{"id": WorldData.Tile.GRASS,  "name": "Трава"},
		{"id": WorldData.Tile.SAND,   "name": "Песок"},
		{"id": WorldData.Tile.WATER,  "name": "Вода"},
		{"id": WorldData.Tile.TREE,   "name": "Дерево"},
		{"id": WorldData.Tile.STONE,  "name": "Камень"},
		{"id": WorldData.Tile.PATH,   "name": "Тропинка"},
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	map_tab.add_child(grid)
	for b in brushes:
		var bt := Button.new()
		bt.text = b["name"]
		bt.toggle_mode = true
		bt.custom_minimum_size = Vector2(140, 0)
		var tid: int = b["id"]
		bt.pressed.connect(_select_brush.bind(tid, bt))
		grid.add_child(bt)
		_edit_brush_btns.append({"btn": bt, "id": tid})
		if tid == map_edit_brush:
			bt.button_pressed = true

	var tools_label := Label.new()
	tools_label.text = "Размер кисти / Ведро:"
	tools_label.add_theme_font_size_override("font_size", 11)
	tools_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	map_tab.add_child(tools_label)

	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 3)
	map_tab.add_child(tools_row)
	for sz in [1, 3, 5]:
		var sb := Button.new()
		sb.text = "%dx%d" % [sz, sz]
		sb.toggle_mode = true
		sb.custom_minimum_size = Vector2(44, 0)
		var size_val: int = sz
		sb.pressed.connect(_select_size.bind(size_val, sb))
		tools_row.add_child(sb)
		_size_btns.append({"btn": sb, "size": size_val})
		if size_val == brush_size:
			sb.button_pressed = true

	_bucket_btn = Button.new()
	_bucket_btn.text = "🪣 Ведро"
	_bucket_btn.toggle_mode = true
	_bucket_btn.pressed.connect(_toggle_bucket)
	tools_row.add_child(_bucket_btn)

	var undo_hint := Label.new()
	undo_hint.text = "Ctrl+Z — отменить  /  Ctrl+Shift+Z — вернуть"
	undo_hint.add_theme_font_size_override("font_size", 9)
	undo_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	map_tab.add_child(undo_hint)

	var mob_label := Label.new()
	mob_label.text = "Мобы (клик → действие):"
	mob_label.add_theme_font_size_override("font_size", 11)
	mob_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	map_tab.add_child(mob_label)

	var mob_tools := [
		{"id": "add_slime",  "name": "+ Слизень"},
		{"id": "add_goblin", "name": "+ Гоблин"},
		{"id": "add_dummy",  "name": "+ Манекен"},
		{"id": "move",       "name": "⇄ Двигать"},
		{"id": "delete",     "name": "✕ Удалить"},
	]
	var mob_grid := GridContainer.new()
	mob_grid.columns = 2
	mob_grid.add_theme_constant_override("h_separation", 4)
	mob_grid.add_theme_constant_override("v_separation", 4)
	map_tab.add_child(mob_grid)
	for mt in mob_tools:
		var mbt := Button.new()
		mbt.text = mt["name"]
		mbt.toggle_mode = true
		mbt.custom_minimum_size = Vector2(140, 0)
		var tid: String = mt["id"]
		mbt.pressed.connect(_select_mob_tool.bind(tid, mbt))
		mob_grid.add_child(mbt)
		_mob_tool_btns.append({"btn": mbt, "id": tid})

	var mob_hint := Label.new()
	mob_hint.text = "Двигать: 1-й клик — выбрать моба, 2-й — новая позиция. Удалить: клик по мобу."
	mob_hint.add_theme_font_size_override("font_size", 9)
	mob_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mob_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mob_hint.custom_minimum_size = Vector2(280, 0)
	map_tab.add_child(mob_hint)

	var save_server_btn := Button.new()
	save_server_btn.text = "💾 Сохранить на сервере"
	save_server_btn.pressed.connect(func(): map_save_server_requested.emit())
	map_tab.add_child(save_server_btn)

	var save_server_hint := Label.new()
	save_server_hint.text = "Запишет карту в Nakama Storage — все игроки увидят изменения при следующем заходе, правки летят всем онлайн мгновенно."
	save_server_hint.add_theme_font_size_override("font_size", 9)
	save_server_hint.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	save_server_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_server_hint.custom_minimum_size = Vector2(280, 0)
	map_tab.add_child(save_server_hint)

	var save_btn := Button.new()
	save_btn.text = "⬇ Скачать world.tmj (локально)"
	save_btn.pressed.connect(func(): map_save_requested.emit())
	map_tab.add_child(save_btn)

	var save_hint := Label.new()
	save_hint.text = "Только для бэкапа/коммита в репо"
	save_hint.add_theme_font_size_override("font_size", 9)
	save_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	save_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_hint.custom_minimum_size = Vector2(280, 0)
	map_tab.add_child(save_hint)

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
	# В браузере F12 перехватывается DevTools, поэтому параллельный хоткей — backtick (`).
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12 or event.keycode == KEY_QUOTELEFT:
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
	_build_items_list()
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
		item_picker.custom_minimum_size = Vector2(200, 0)
		for it in QUICK_ITEMS:
			var def: Dictionary = Items.def(it)
			var display: String = String(def.get("name", it))
			item_picker.add_item(display)
			var idx := item_picker.item_count - 1
			item_picker.set_item_metadata(idx, it)
		v.add_child(item_picker)

		var b_item := Button.new()
		b_item.text = "Выдать выбранное"
		b_item.pressed.connect(func():
			var sel: int = item_picker.selected
			if sel < 0: sel = 0
			var it: String = String(item_picker.get_item_metadata(sel))
			action_requested.emit("give_item_to", {"target": u.get("name", ""), "itemId": it})
		)
		v.add_child(b_item)

func log_result(text: String) -> void:
	log_label.text = text

func _toggle_map_edit() -> void:
	map_edit_mode = _edit_toggle_btn.button_pressed
	_edit_toggle_btn.text = "Редактировать карту: ВКЛ" if map_edit_mode else "Редактировать карту: ВЫКЛ"
	if map_edit_mode:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	map_edit_mode_changed.emit(map_edit_mode)

func _select_brush(tile_id: int, btn: Button) -> void:
	map_edit_brush = tile_id
	for entry in _edit_brush_btns:
		var b: Button = entry["btn"]
		b.button_pressed = (b == btn)

func _select_size(size: int, btn: Button) -> void:
	brush_size = size
	for entry in _size_btns:
		var b: Button = entry["btn"]
		b.button_pressed = (b == btn)

func _toggle_bucket() -> void:
	bucket_mode = _bucket_btn.button_pressed

func _select_mob_tool(tool_id: String, btn: Button) -> void:
	# Повторный клик по активной кнопке снимает инструмент.
	if mob_tool == tool_id and not btn.button_pressed:
		mob_tool = ""
		return
	mob_tool = tool_id
	for entry in _mob_tool_btns:
		var b: Button = entry["btn"]
		b.button_pressed = (b == btn)
