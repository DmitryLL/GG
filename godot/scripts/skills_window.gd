# Окно «Скиллы» — список скиллов класса + выбор модификаций.
# Данные читаются из data/skills_archer.json (пока только лучник).
# Правила: одна мода на скилл, бюджет 5 поинтов.
#
# Модификации пока хранятся только на клиенте (локально в сессии) —
# серверную синхронизацию добавим позже. Реальных эффектов в бою
# тоже пока нет: это UI-каркас.
class_name SkillsWindow
extends CanvasLayer

const SKILLS_DATA_BY_CLASS := {
	"archer": "res://data/skills_archer.json",
	"mage":   "res://data/skills_mage.json",
}
var _class_id: String = "archer"
var _mods_rpc_prefix: String = "archer_mods"  # archer_mods_get / mage_mods_get

var root_ctrl: Control
var panel: PanelContainer
var scroll: ScrollContainer
var list: VBoxContainer
var points_label: Label

var _skills_data: Dictionary = {}
var _points_budget: int = 5
var _selected_mods: Dictionary = {}  # { skill_id(int): mod_id(String) }
var _skill_cards: Array = []         # [ { id:int, card:PanelContainer, current_mod_lbl:Label, mods_panel:VBoxContainer } ]
var _synced_once: bool = false       # сервер опрашиваем лениво — при первом открытии

func _ready() -> void:
	layer = 19
	# Класс берём из Session; позже сервер уточнит через OP_ME.
	if Session and Session.selected_character != "":
		_class_id = Session.selected_character
	_mods_rpc_prefix = "%s_mods" % _class_id
	_load_data()
	_build_ui()

# Вызывается game.gd при получении класса от сервера (например, в OP_ME).
# Если класс изменился — перестраиваем окно и синкаемся заново.
func set_class(class_id: String) -> void:
	if class_id == "" or class_id == _class_id:
		return
	if not SKILLS_DATA_BY_CLASS.has(class_id):
		push_warning("skills_window: unknown class %s" % class_id)
		return
	_class_id = class_id
	_mods_rpc_prefix = "%s_mods" % _class_id
	_synced_once = false
	_selected_mods.clear()
	_skill_cards.clear()
	if list:
		for ch in list.get_children():
			ch.queue_free()
	_load_data()
	var skills: Array = _skills_data.get("skills", [])
	for s in skills:
		_skill_cards.append(_build_skill_card(s))
	_refresh_points()

func _load_data() -> void:
	var path: String = SKILLS_DATA_BY_CLASS.get(_class_id, SKILLS_DATA_BY_CLASS["archer"])
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("skills data not found at %s" % path)
		_skills_data = {"skills": [], "points_budget": 5}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("skills data not JSON object: %s" % path)
		_skills_data = {"skills": [], "points_budget": 5}
		return
	_skills_data = parsed
	_points_budget = int(_skills_data.get("points_budget", 5))

func _build_ui() -> void:
	root_ctrl = Control.new()
	root_ctrl.anchor_right = 1.0
	root_ctrl.anchor_bottom = 1.0
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	panel = PanelContainer.new()
	panel.anchor_left = 1.0; panel.anchor_top = 1.0
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.offset_left = -440
	panel.offset_top = -560
	panel.offset_right = -10
	panel.offset_bottom = -120
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.96)
	sb.border_color = Color(0.85, 0.65, 0.30, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	root_ctrl.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)

	# Шапка: заголовок + поинты + крестик.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	outer.add_child(header)

	var title := Label.new()
	title.text = "Скиллы"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	points_label = Label.new()
	points_label.add_theme_font_size_override("font_size", 13)
	points_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7))
	header.add_child(points_label)

	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(26, 26)
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	close.pressed.connect(func(): panel.visible = false)
	header.add_child(close)

	# Прокручиваемый список скиллов.
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var skills: Array = _skills_data.get("skills", [])
	for s in skills:
		_skill_cards.append(_build_skill_card(s))

	_refresh_points()

func _build_skill_card(s: Dictionary) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.13, 0.09, 0.95)
	sb.border_color = Color(0.55, 0.40, 0.20, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)
	list.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	# Верхняя строка: иконка + имя + кнопка.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var icon_path: String = s.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	top.add_child(icon)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 1)
	top.add_child(name_col)

	var name_lbl := Label.new()
	name_lbl.text = str(s.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.70))
	name_col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(s.get("description", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	name_col.add_child(desc_lbl)

	# Строка «Откат: X с · Мана: Y» — берём из SkillDef (единый источник
	# истины), JSON хранит только текстовое описание для игрока.
	var stat_def: SkillDef = SkillRegistry.by_server_id(int(s.get("id", -1)))
	if stat_def != null:
		var stats_lbl := Label.new()
		var parts: Array = []
		parts.append("Откат: %.0f с" % stat_def.cooldown)
		if stat_def.mana_cost > 0:
			parts.append("Мана: %d" % stat_def.mana_cost)
		stats_lbl.text = " · ".join(parts)
		stats_lbl.add_theme_font_size_override("font_size", 10)
		stats_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		name_col.add_child(stats_lbl)

	# Кнопка «Модифицировать» — раскрывает блок с вариантами.
	var modify_btn := Button.new()
	modify_btn.text = "Модифицировать"
	modify_btn.focus_mode = Control.FOCUS_NONE
	modify_btn.add_theme_font_size_override("font_size", 12)
	modify_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	modify_btn.custom_minimum_size = Vector2(130, 28)
	modify_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(modify_btn)

	# Строка текущей выбранной модификации.
	var current_mod_lbl := Label.new()
	current_mod_lbl.text = "Мод: —"
	current_mod_lbl.add_theme_font_size_override("font_size", 11)
	current_mod_lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
	col.add_child(current_mod_lbl)

	# Панель с вариантами (скрыта по умолчанию).
	var mods_panel := VBoxContainer.new()
	mods_panel.visible = false
	mods_panel.add_theme_constant_override("separation", 4)
	col.add_child(mods_panel)

	var skill_id: int = int(s.get("id", -1))
	for m in s.get("modifications", []):
		var row := _build_mod_row(skill_id, m)
		mods_panel.add_child(row)

	# Кнопка «Снять мод» в блоке вариантов — только если есть выбор.
	var clear_btn := Button.new()
	clear_btn.text = "Снять модификацию"
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.add_theme_font_size_override("font_size", 11)
	clear_btn.add_theme_color_override("font_color", Color(0.95, 0.70, 0.65))
	clear_btn.pressed.connect(func(): _clear_mod(skill_id))
	mods_panel.add_child(clear_btn)

	modify_btn.pressed.connect(func():
		mods_panel.visible = not mods_panel.visible
	)

	return {
		"id": skill_id,
		"card": card,
		"current_mod_lbl": current_mod_lbl,
		"mods_panel": mods_panel,
		"clear_btn": clear_btn,
		"data": s,
	}

func _build_mod_row(skill_id: int, m: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)

	var title := Label.new()
	title.text = "[%dп] %s" % [int(m.get("cost", 0)), str(m.get("name", "?"))]
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	info.add_child(title)

	var desc := Label.new()
	desc.text = str(m.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70))
	info.add_child(desc)

	row.add_child(info)

	var pick_btn := Button.new()
	pick_btn.text = "Выбрать"
	pick_btn.focus_mode = Control.FOCUS_NONE
	pick_btn.add_theme_font_size_override("font_size", 11)
	pick_btn.custom_minimum_size = Vector2(80, 26)
	pick_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mod_id: String = str(m.get("id", ""))
	var cost: int = int(m.get("cost", 0))
	pick_btn.pressed.connect(func(): _pick_mod(skill_id, mod_id, cost))
	row.add_child(pick_btn)

	return row

func _points_used() -> int:
	var used := 0
	for skill_id_variant in _selected_mods.keys():
		var skill_id: int = int(skill_id_variant)
		var mod_id: String = _selected_mods[skill_id]
		used += _cost_of(skill_id, mod_id)
	return used

func _points_available() -> int:
	return _points_budget - _points_used()

func _cost_of(skill_id: int, mod_id: String) -> int:
	for s in _skills_data.get("skills", []):
		if int(s.get("id", -1)) != skill_id:
			continue
		for m in s.get("modifications", []):
			if str(m.get("id", "")) == mod_id:
				return int(m.get("cost", 0))
	return 0

func _name_of(skill_id: int, mod_id: String) -> String:
	for s in _skills_data.get("skills", []):
		if int(s.get("id", -1)) != skill_id:
			continue
		for m in s.get("modifications", []):
			if str(m.get("id", "")) == mod_id:
				return "[%dп] %s" % [int(m.get("cost", 0)), str(m.get("name", "?"))]
	return "—"

func _pick_mod(skill_id: int, mod_id: String, cost: int) -> void:
	# Если эта мода уже выбрана — ничего не делаем.
	var current: String = _selected_mods.get(skill_id, "")
	if current == mod_id:
		return
	# Высвобождаем очки от текущей моды на этом скилле (если была другая).
	var freed: int = _cost_of(skill_id, current) if current != "" else 0
	var net_change: int = cost - freed
	if net_change > _points_available():
		# Недостаточно поинтов — сигнализируем красным цветом заголовка на секунду.
		_flash_points_warning()
		return
	_selected_mods[skill_id] = mod_id
	_refresh_card(skill_id)
	_refresh_points()
	_push_to_server()  # fire-and-forget

func _clear_mod(skill_id: int) -> void:
	if not _selected_mods.has(skill_id):
		return
	_selected_mods.erase(skill_id)
	_refresh_card(skill_id)
	_refresh_points()
	_push_to_server()  # fire-and-forget

func _refresh_card(skill_id: int) -> void:
	for c in _skill_cards:
		if int(c["id"]) != skill_id:
			continue
		var lbl: Label = c["current_mod_lbl"]
		var mod_id: String = _selected_mods.get(skill_id, "")
		if mod_id == "":
			lbl.text = "Мод: —"
			lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
		else:
			lbl.text = "Мод: %s" % _name_of(skill_id, mod_id)
			lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
		return

func _refresh_points() -> void:
	if points_label == null:
		return
	points_label.text = "Поинты: %d / %d" % [_points_used(), _points_budget]

func _flash_points_warning() -> void:
	if points_label == null:
		return
	points_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.40))
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func():
		points_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7))
	)

func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible and not _synced_once:
		_synced_once = true
		_sync_from_server()

func is_open() -> bool:
	return panel.visible

func close() -> void:
	panel.visible = false

# Возвращает копию выбранных мод — для чтения другими системами.
func get_selected_mods() -> Dictionary:
	return _selected_mods.duplicate(true)

# ─── Серверная синхронизация через Nakama RPC ───

func _sync_from_server() -> void:
	if Session == null or Session.client == null or Session.auth == null:
		return
	var rpc_res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "%s_get" % _mods_rpc_prefix, "")
	if rpc_res == null or rpc_res.is_exception():
		push_warning("archer_mods_get failed: %s" % (rpc_res.get_exception().message if rpc_res else "null"))
		return
	var data: Variant = JSON.parse_string(rpc_res.payload)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var loaded: Dictionary = data.get("selected", {})
	_selected_mods.clear()
	for k in loaded.keys():
		_selected_mods[int(k)] = str(loaded[k])
	# Обновить UI всех карточек.
	for c in _skill_cards:
		_refresh_card(int(c["id"]))
	_refresh_points()

func _push_to_server() -> void:
	if Session == null or Session.client == null or Session.auth == null:
		return
	var sel := {}
	for k in _selected_mods.keys():
		sel[str(k)] = _selected_mods[k]
	var payload := JSON.stringify({ "selected": sel })
	var rpc_res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "%s_set" % _mods_rpc_prefix, payload)
	if rpc_res == null or rpc_res.is_exception():
		push_warning("archer_mods_set failed: %s" % (rpc_res.get_exception().message if rpc_res else "null"))
		return
	# Если сервер отреджектил (например, бюджет) — откатываем к серверному состоянию.
	var data: Variant = JSON.parse_string(rpc_res.payload)
	if typeof(data) == TYPE_DICTIONARY and data.get("ok", true) == false:
		push_warning("server rejected mods: %s" % str(data.get("reason", "?")))
		_sync_from_server()
