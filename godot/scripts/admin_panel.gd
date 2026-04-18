# Внутриигровая админ-панель (F12) — список игроков + выдача золота/предметов.
class_name AdminPanel
extends CanvasLayer

const ADMIN_USERNAMES = ["dimka4344", "v_tip"]

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

# Если не пусто — порталы создаются с targetZone (межзонный переход).
var portal_target_zone: String = ""
const KNOWN_ZONES := ["village", "forest", "dungeon"]

# Превью выбранной кисти — мини-тайл + имя.
var _brush_preview: TextureRect
var _brush_preview_name: Label
var _brushes_def: Array = []

# Пресет-высадка.
var _preset_count: int = 10

# История версий — контейнер в панели Карта.
var _history_list_vbox: VBoxContainer

# Оверлей «× выйти из режима редактора» — справа наверху экрана.
var _edit_exit_btn: Button

signal map_save_requested              # старая: скачать world.tmj в браузер
signal map_save_server_requested       # новая: записать в Nakama Storage
signal map_edit_mode_changed(on: bool) # для сетки-оверлея
signal mob_preset_spawn(type: String, count: int)
signal map_history_requested
signal map_snapshot_requested
signal map_rollback_requested(ts: int)

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

	# Шапка с title + крестиком закрытия.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	outer.add_child(header)

	var title := Label.new()
	title.text = "АДМИНКА (` или F12)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	# «?» — показать подсказки во всплывающем окне.
	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.tooltip_text = "Показать подсказки"
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.custom_minimum_size = Vector2(26, 26)
	help_btn.add_theme_font_size_override("font_size", 14)
	help_btn.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	help_btn.pressed.connect(_show_help_dialog)
	header.add_child(help_btn)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.tooltip_text = "Закрыть"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(26, 26)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	close_btn.pressed.connect(func():
		visible_now = false
		panel.visible = false
	)
	header.add_child(close_btn)

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

	# Подсказки убраны в диалог по «?» в шапке.

	var brush_row := HBoxContainer.new()
	brush_row.add_theme_constant_override("separation", 6)
	map_tab.add_child(brush_row)

	var brush_label := Label.new()
	brush_label.text = "Кисть:"
	brush_label.add_theme_font_size_override("font_size", 11)
	brush_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	brush_row.add_child(brush_label)

	# Превью выбранного тайла — кусок tiles.png размером 32×32.
	_brush_preview = TextureRect.new()
	_brush_preview.custom_minimum_size = Vector2(32, 32)
	_brush_preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_brush_preview.texture = _make_brush_preview_texture(map_edit_brush)
	brush_row.add_child(_brush_preview)

	_brush_preview_name = Label.new()
	_brush_preview_name.add_theme_font_size_override("font_size", 11)
	_brush_preview_name.add_theme_color_override("font_color", Color(1, 1, 0.85))
	brush_row.add_child(_brush_preview_name)

	_brushes_def = [
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
	for i in range(_brushes_def.size()):
		var b: Dictionary = _brushes_def[i]
		var bt := Button.new()
		bt.text = "%d. %s" % [i + 1, String(b["name"])]
		bt.toggle_mode = true
		bt.custom_minimum_size = Vector2(140, 0)
		var tid: int = b["id"]
		bt.pressed.connect(_select_brush.bind(tid, bt))
		grid.add_child(bt)
		_edit_brush_btns.append({"btn": bt, "id": tid})
		if tid == map_edit_brush:
			bt.button_pressed = true
	_update_brush_preview()

	var tools_label := Label.new()
	tools_label.text = "Размер кисти / Ведро:"
	tools_label.add_theme_font_size_override("font_size", 11)
	tools_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	map_tab.add_child(tools_label)

	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 3)
	map_tab.add_child(tools_row)
	for sz in [1, 3, 5]:
		var size_btn := Button.new()
		size_btn.text = "%dx%d" % [sz, sz]
		size_btn.toggle_mode = true
		size_btn.custom_minimum_size = Vector2(44, 0)
		var size_val: int = sz
		size_btn.pressed.connect(_select_size.bind(size_val, size_btn))
		tools_row.add_child(size_btn)
		_size_btns.append({"btn": size_btn, "size": size_val})
		if size_val == brush_size:
			size_btn.button_pressed = true

	_bucket_btn = Button.new()
	_bucket_btn.text = "🪣 Ведро"
	_bucket_btn.toggle_mode = true
	_bucket_btn.pressed.connect(_toggle_bucket)
	tools_row.add_child(_bucket_btn)


	var mob_label := Label.new()
	mob_label.text = "Мобы (клик → действие):"
	mob_label.add_theme_font_size_override("font_size", 11)
	mob_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	map_tab.add_child(mob_label)

	var mob_tools := [
		{"id": "add_slime",   "name": "+ Слизень"},
		{"id": "add_goblin",  "name": "+ Гоблин"},
		{"id": "add_dummy",   "name": "+ Манекен"},
		{"id": "move",        "name": "⇄ Двигать"},
		{"id": "delete",      "name": "✕ Удалить моба"},
		{"id": "portal_pair", "name": "🌀 Портал A↔B"},
		{"id": "chest",       "name": "📦 Сундук"},
		{"id": "obj_delete",  "name": "✕ Удалить объект"},
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


	# Выбор целевой зоны для следующего портала.
	var zone_row := HBoxContainer.new()
	zone_row.add_theme_constant_override("separation", 4)
	map_tab.add_child(zone_row)
	var zlbl := Label.new()
	zlbl.text = "Цель портала:"
	zlbl.add_theme_font_size_override("font_size", 10)
	zone_row.add_child(zlbl)
	var zopt := OptionButton.new()
	zopt.add_item("(локальный)")
	zopt.set_item_metadata(0, "")
	for zi in range(KNOWN_ZONES.size()):
		var zn: String = KNOWN_ZONES[zi]
		zopt.add_item("→ " + zn)
		zopt.set_item_metadata(zi + 1, zn)
	zopt.item_selected.connect(func(idx: int):
		portal_target_zone = String(zopt.get_item_metadata(idx))
		log_result("Портал будет в зону: %s" % (portal_target_zone if portal_target_zone != "" else "(локальный телепорт)"))
	)
	zone_row.add_child(zopt)

	# Пресеты — кнопка «+N», клик в мире высаживает стаю.
	var preset_label := Label.new()
	preset_label.text = "Пресеты (клик в мире = высадить стаю):"
	preset_label.add_theme_font_size_override("font_size", 11)
	preset_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	map_tab.add_child(preset_label)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 3)
	map_tab.add_child(preset_row)
	var preset_count := SpinBox.new()
	preset_count.min_value = 1; preset_count.max_value = 50; preset_count.value = 10
	preset_count.custom_minimum_size = Vector2(60, 0)
	preset_row.add_child(preset_count)
	for preset in [{"type":"slime","name":"слизней"},{"type":"goblin","name":"гоблинов"},{"type":"dummy","name":"манекенов"}]:
		var pb := Button.new()
		pb.text = "+N %s" % preset["name"]
		var ptype: String = preset["type"]
		pb.pressed.connect(func():
			mob_tool = "preset_" + ptype
			_preset_count = int(preset_count.value)
			log_result("Пресет активирован: %s × %d, кликай в мире" % [ptype, _preset_count])
		)
		preset_row.add_child(pb)

	# История версий.
	var hist_label := Label.new()
	hist_label.text = "История версий:"
	hist_label.add_theme_font_size_override("font_size", 11)
	hist_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	map_tab.add_child(hist_label)

	var hist_row := HBoxContainer.new()
	hist_row.add_theme_constant_override("separation", 3)
	map_tab.add_child(hist_row)
	var snap_btn := Button.new()
	snap_btn.text = "📸 Снимок"
	snap_btn.pressed.connect(func(): map_snapshot_requested.emit())
	hist_row.add_child(snap_btn)
	var hist_btn := Button.new()
	hist_btn.text = "📜 Показать"
	hist_btn.pressed.connect(func(): map_history_requested.emit())
	hist_row.add_child(hist_btn)

	_history_list_vbox = VBoxContainer.new()
	_history_list_vbox.add_theme_constant_override("separation", 2)
	map_tab.add_child(_history_list_vbox)

	var save_server_btn := Button.new()
	save_server_btn.text = "💾 Сохранить на сервере"
	save_server_btn.pressed.connect(func(): map_save_server_requested.emit())
	map_tab.add_child(save_server_btn)


	var save_btn := Button.new()
	save_btn.text = "⬇ Скачать world.tmj (локально)"
	save_btn.pressed.connect(func(): map_save_requested.emit())
	map_tab.add_child(save_btn)


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

func toggle() -> void:
	if not is_admin():
		return
	visible_now = not visible_now
	panel.visible = visible_now
	if visible_now and users_list.get_child_count() == 0:
		_refresh_users()

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
		_ensure_edit_exit_button()
		_edit_exit_btn.visible = true
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		if _edit_exit_btn:
			_edit_exit_btn.visible = false
	map_edit_mode_changed.emit(map_edit_mode)

func _ensure_edit_exit_button() -> void:
	if _edit_exit_btn and is_instance_valid(_edit_exit_btn):
		return
	_edit_exit_btn = Button.new()
	_edit_exit_btn.text = "× выйти из редактора"
	_edit_exit_btn.tooltip_text = "Выйти из режима редактирования карты"
	_edit_exit_btn.focus_mode = Control.FOCUS_NONE
	_edit_exit_btn.anchor_left = 1.0; _edit_exit_btn.anchor_right = 1.0
	_edit_exit_btn.anchor_top = 0.0; _edit_exit_btn.anchor_bottom = 0.0
	_edit_exit_btn.offset_right = -10
	_edit_exit_btn.offset_left = -210
	_edit_exit_btn.offset_top = 10
	_edit_exit_btn.offset_bottom = 44
	_edit_exit_btn.add_theme_font_size_override("font_size", 14)
	_edit_exit_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	var sbn := StyleBoxFlat.new()
	sbn.bg_color = Color(0.20, 0.08, 0.08, 0.95)
	sbn.border_color = Color(0.90, 0.50, 0.30, 1)
	sbn.set_border_width_all(2)
	sbn.set_corner_radius_all(6)
	sbn.set_content_margin_all(6)
	var sbh := sbn.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.32, 0.14, 0.14, 1)
	sbh.border_color = Color(1, 0.75, 0.35, 1)
	_edit_exit_btn.add_theme_stylebox_override("normal", sbn)
	_edit_exit_btn.add_theme_stylebox_override("hover", sbh)
	_edit_exit_btn.add_theme_stylebox_override("pressed", sbh)
	_edit_exit_btn.pressed.connect(exit_edit_mode)
	root_ctrl.add_child(_edit_exit_btn)

func _select_brush(tile_id: int, btn: Button) -> void:
	map_edit_brush = tile_id
	for entry in _edit_brush_btns:
		var b: Button = entry["btn"]
		b.button_pressed = (b == btn)
	# Выбор тайла-кисти отменяет активный mob/object-инструмент,
	# иначе клики будут уходить в _handle_mob_tool_click и тайл не нарисуется.
	mob_tool = ""
	for entry2 in _mob_tool_btns:
		var b2: Button = entry2["btn"]
		b2.button_pressed = false
	_update_brush_preview()

func select_brush_by_index(idx: int) -> void:
	if idx < 0 or idx >= _edit_brush_btns.size(): return
	var entry: Dictionary = _edit_brush_btns[idx]
	_select_brush(int(entry["id"]), entry["btn"])

func select_brush_by_id(tile_id: int) -> void:
	for entry in _edit_brush_btns:
		if int(entry["id"]) == tile_id:
			_select_brush(tile_id, entry["btn"])
			return

func toggle_bucket() -> void:
	_bucket_btn.button_pressed = not _bucket_btn.button_pressed
	_toggle_bucket()

func exit_edit_mode() -> void:
	if not map_edit_mode: return
	_edit_toggle_btn.button_pressed = false
	_toggle_map_edit()

func _update_brush_preview() -> void:
	if _brush_preview:
		_brush_preview.texture = _make_brush_preview_texture(map_edit_brush)
	if _brush_preview_name:
		var nm := ""
		for b in _brushes_def:
			if int(b["id"]) == map_edit_brush:
				nm = String(b["name"]); break
		_brush_preview_name.text = nm

func show_history_list(items: Array) -> void:
	if _history_list_vbox == null: return
	for c in _history_list_vbox.get_children():
		c.queue_free()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "(пусто — сделай снимок)"
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		empty.add_theme_font_size_override("font_size", 10)
		_history_list_vbox.add_child(empty)
		return
	for it in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_history_list_vbox.add_child(row)
		var ts: int = int(it.get("ts", 0))
		var dt := Time.get_datetime_dict_from_unix_time(ts / 1000)
		var lbl := Label.new()
		lbl.text = "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(lbl)
		var b := Button.new()
		b.text = "↶ Откатить"
		b.pressed.connect(func(): map_rollback_requested.emit(ts))
		row.add_child(b)

func _show_help_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Подсказки редактора карт"
	dlg.dialog_text = """ЛКМ — поставить выбранный тайл в клетку
ПКМ — заменить клетку на траву
Shift+ЛКМ drag — прямоугольная заливка
Alt+ЛКМ — пипетка (взять тайл под курсором в кисть)

WASD — двигать камеру
Колесо мыши — zoom (приближение/отдаление)

Хоткеи:
  1–6  выбор кисти (Трава/Песок/Вода/Дерево/Камень/Тропинка)
  G    сетка вкл/выкл
  B    ведро (flood fill)
  Ctrl+Z / Ctrl+Shift+Z  отменить / вернуть
  Esc  выход из режима редактора

Мобы:
  «Двигать» — 1-й клик: выбрать моба, 2-й клик: новая позиция
  «Удалить моба» — клик по мобу

Сохранение:
  💾 Сохранить на сервере — запишет в Nakama Storage, все увидят при следующем заходе.
     Правки летят всем онлайн мгновенно даже без сохранения.
  ⬇ Скачать world.tmj — локальный бэкап для коммита в репо."""
	add_child(dlg)
	dlg.popup_centered(Vector2i(560, 440))
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())

func _make_brush_preview_texture(tile_id: int) -> AtlasTexture:
	# Берём 32×32 регион из tiles.png — такой же как рисуется в мире.
	var base_id: int = tile_id
	if tile_id == WorldData.Tile.TREE:
		base_id = WorldData.Tile.GRASS  # дерево поверх — но для превью хватит травы
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/tiles.png")
	atlas.region = Rect2(base_id * WorldData.TILE_SIZE, 0, WorldData.TILE_SIZE, WorldData.TILE_SIZE)
	return atlas

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
