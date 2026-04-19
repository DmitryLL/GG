# Окно «Параметры» — три вкладки статов (Персонаж / Атака / Защита).
# Значения берутся из последнего OP_ME (last_me), для ещё не реализованных
# статов показываем «—» или 0.
class_name StatsWindow
extends CanvasLayer

var root_ctrl: Control
var panel: PanelContainer
var tabs: TabContainer

# Лейблы значений по вкладкам: {name: Label}
var _char_lbl: Dictionary = {}
var _atk_lbl: Dictionary = {}
var _def_lbl: Dictionary = {}

const CHAR_ROWS := [
	["xp",        "Опыт"],
	["hp",        "Здоровье"],
	["hp_regen",  "Регенерация здоровья"],
	["mp",        "Мана"],
	["mp_regen",  "Регенерация маны"],
	["speed",     "Скорость бега"],
]
const ATK_ROWS := [
	["phys_dmg",      "Физический урон"],
	["mag_dmg",       "Магический урон"],
	["crit_chance",   "Шанс критического удара"],
	["crit_power",    "Сила критического удара"],
	["accuracy",      "Точность"],
	["penetration",   "Пробивная способность"],
	["cd_reduction",  "Перезарядка навыков"],
	["stun",          "Оглушение"],
	["pvp_bonus",     "Доп. урон в PvP"],
]
const DEF_ROWS := [
	["phys_def",     "Физическая защита"],
	["mag_def",      "Магическая защита"],
	["dodge",        "Уклонение"],
	["pvp_resist",   "Устойчивость к PvP"],
	["block",        "Блокирование"],
	["lifesteal",    "Вампиризм"],
	["reflect",      "Отражение урона"],
]

func _ready() -> void:
	layer = 18
	root_ctrl = Control.new()
	root_ctrl.anchor_right = 1.0
	root_ctrl.anchor_bottom = 1.0
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	panel = PanelContainer.new()
	panel.anchor_left = 1.0; panel.anchor_top = 1.0
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.offset_left = -380
	panel.offset_top = -460
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	outer.add_child(header)
	var title := Label.new()
	title.text = "Параметры"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(26, 26)
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	close.pressed.connect(func(): panel.visible = false)
	header.add_child(close)

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 280)
	outer.add_child(tabs)

	var char_tab := _build_tab("Персонаж", CHAR_ROWS, _char_lbl)
	tabs.add_child(char_tab)
	var atk_tab := _build_tab("Атака", ATK_ROWS, _atk_lbl)
	tabs.add_child(atk_tab)
	var def_tab := _build_tab("Защита", DEF_ROWS, _def_lbl)
	tabs.add_child(def_tab)

func _build_tab(tab_name: String, rows: Array, sink: Dictionary) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = tab_name
	v.add_theme_constant_override("separation", 3)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	for r in rows:
		var key: String = r[0]
		var caption: String = r[1]
		var name_lbl := Label.new()
		name_lbl.text = caption
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		name_lbl.add_theme_font_size_override("font_size", 12)
		grid.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = "—"
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_color_override("font_color", Color(1, 1, 0.85))
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val_lbl)
		sink[key] = val_lbl
	return v

func toggle() -> void:
	panel.visible = not panel.visible

func is_open() -> bool:
	return panel.visible

func close() -> void:
	panel.visible = false

# Обновление значений из body OP_ME.
# Нереализованные статы показываем 0 (не «—»), чтобы было видно что
# параметр есть, просто пока без накоплений.
func refresh(me: Dictionary) -> void:
	if me == null or me.is_empty():
		return
	# Персонаж — «10 / 100» (текущий опыт / для следующего уровня).
	var xp := int(me.get("xp", 0))
	var xp_need := int(me.get("xpNeed", 0))
	if xp_need > 0:
		_set_stat(_char_lbl, "xp", "%d / %d" % [xp, xp_need])
	else:
		_set_stat(_char_lbl, "xp", str(xp))
	var hp := int(me.get("hp", 0)); var hp_max := int(me.get("hpMax", 0))
	_set_stat(_char_lbl, "hp", "%d / %d" % [hp, hp_max])
	_set_stat(_char_lbl, "hp_regen", "0")
	var mp := int(me.get("mana", 0)); var mp_max := int(me.get("manaMax", 0))
	_set_stat(_char_lbl, "mp", "%d / %d" % [mp, mp_max])
	_set_stat(_char_lbl, "mp_regen", "5")
	_set_stat(_char_lbl, "speed", str(int(me.get("moveSpeed", 100))))
	# Атака — сервер шлёт два раздельных значения (physDmg, magDmg).
	var phys: int = int(me.get("physDmg", me.get("damage", 0)))
	var mag: int = int(me.get("magDmg", 0))
	_set_stat(_atk_lbl, "phys_dmg", str(phys))
	_set_stat(_atk_lbl, "mag_dmg", str(mag))
	# Crit/pierce — реальные значения с учётом активных баффов.
	var crit_ch: int = int(me.get("critChance", 0))
	var crit_pw: int = int(me.get("critPower", 0))
	var pierce: int = int(me.get("penetration", 0))
	_set_stat(_atk_lbl, "crit_chance", "%d%%" % crit_ch)
	_set_stat(_atk_lbl, "crit_power",  "%d%%" % crit_pw)
	_set_stat(_atk_lbl, "accuracy", "0")
	_set_stat(_atk_lbl, "penetration", "%d%%" % pierce)
	_set_stat(_atk_lbl, "cd_reduction", "0")
	_set_stat(_atk_lbl, "stun", "0")
	_set_stat(_atk_lbl, "pvp_bonus", "0")
	# Защита
	_set_stat(_def_lbl, "phys_def", str(int(me.get("physDef", 0))))
	_set_stat(_def_lbl, "mag_def", str(int(me.get("magDef", 0))))
	_set_stat(_def_lbl, "dodge", "0")
	_set_stat(_def_lbl, "pvp_resist", "0")
	_set_stat(_def_lbl, "block", "0")
	_set_stat(_def_lbl, "lifesteal", "0")
	_set_stat(_def_lbl, "reflect", "0")

func _set_stat(sink: Dictionary, key: String, value: String) -> void:
	var lbl: Label = sink.get(key)
	if lbl:
		lbl.text = value
