# Клиентские мета-данные предметов: имя, иконка, слот, статы.
# Сервер — источник правды для расчёта, клиент дублирует для отображения.
class_name Items
extends RefCounted

const DEFS := {
	"slime_jelly":     { "name": "Слизь",              "icon": 0, "kind": "material" },
	"wolf_pelt":       { "name": "Шкура волка",        "icon": 0, "kind": "material" },
	"goblin_ear":      { "name": "Ухо гоблина",        "icon": 0, "kind": "material" },

	"small_potion":    { "name": "Малое зелье",        "icon": 5, "kind": "consumable", "heal": 25 },
	"health_potion":   { "name": "Зелье лечения",      "icon": 5, "kind": "consumable", "heal": 50 },
	"great_potion":    { "name": "Большое зелье",      "icon": 5, "kind": "consumable", "heal": 120 },

	"wood_sword":      { "name": "Деревянный меч",     "icon": 1, "slot": "weapon", "physDmg": 4 },
	"bronze_sword":    { "name": "Бронзовый меч",      "icon": 1, "slot": "weapon", "physDmg": 7 },
	"iron_sword":      { "name": "Железный меч",       "icon": 2, "slot": "weapon", "physDmg": 10 },
	"steel_sword":     { "name": "Стальной меч",       "icon": 2, "slot": "weapon", "physDmg": 15 },
	"golden_sword":    { "name": "Золотой меч",        "icon": 2, "slot": "weapon", "physDmg": 22 },

	"wood_bow":        { "name": "Деревянный лук",    "icon": 6, "slot": "weapon", "physDmg": 6 },
	"iron_bow":        { "name": "Железный лук",       "icon": 6, "slot": "weapon", "physDmg": 12 },
	"golden_bow":      { "name": "Золотой лук",        "icon": 6, "slot": "weapon", "physDmg": 20 },

	"apprentice_tome": { "name": "Книга подмастерья",  "icon": 7, "slot": "weapon", "magDmg": 5 },
	"mystic_tome":     { "name": "Мистическая книга",  "icon": 7, "slot": "weapon", "magDmg": 9 },
	"arcane_tome":     { "name": "Тайная книга",       "icon": 7, "slot": "weapon", "magDmg": 14 },
	"eldritch_tome":   { "name": "Древняя книга",      "icon": 7, "slot": "weapon", "magDmg": 20 },
	"celestial_tome":  { "name": "Небесная книга",     "icon": 7, "slot": "weapon", "magDmg": 28 },

	"cloth_armor":     { "name": "Тканая броня",       "icon": 3, "slot": "body", "hp": 12 },
	"leather_armor":   { "name": "Кожаная броня",      "icon": 3, "slot": "body", "hp": 22 },
	"bronze_armor":    { "name": "Бронзовая броня",    "icon": 4, "slot": "body", "hp": 32 },
	"iron_armor":      { "name": "Железная броня",     "icon": 4, "slot": "body", "hp": 45 },
	"steel_armor":     { "name": "Стальная броня",     "icon": 4, "slot": "body", "hp": 65 },
	"golden_armor":    { "name": "Золотая броня",      "icon": 4, "slot": "body", "hp": 90, "damage": 2 },

	"leather_helmet":  { "name": "Кожаный шлем",       "icon": 3, "slot": "head", "hp": 8 },
	"bronze_helmet":   { "name": "Бронзовый шлем",     "icon": 4, "slot": "head", "hp": 12 },
	"iron_helmet":     { "name": "Железный шлем",      "icon": 4, "slot": "head", "hp": 18 },
	"steel_helmet":    { "name": "Стальной шлем",      "icon": 4, "slot": "head", "hp": 25 },
	"golden_helmet":   { "name": "Золотой шлем",       "icon": 4, "slot": "head", "hp": 35, "damage": 1 },

	"leather_boots":   { "name": "Кожаные сапоги",     "icon": 3, "slot": "boots", "hp": 6 },
	"bronze_boots":    { "name": "Бронзовые сапоги",   "icon": 4, "slot": "boots", "hp": 9 },
	"iron_boots":      { "name": "Железные сапоги",    "icon": 4, "slot": "boots", "hp": 14 },
	"steel_boots":     { "name": "Стальные сапоги",    "icon": 4, "slot": "boots", "hp": 20 },
	"golden_boots":    { "name": "Золотые сапоги",     "icon": 4, "slot": "boots", "hp": 28 },

	"leather_belt":    { "name": "Кожаный пояс",       "icon": 3, "slot": "belt", "hp": 4 },
	"iron_belt":       { "name": "Железный пояс",      "icon": 4, "slot": "belt", "hp": 8 },
	"golden_belt":     { "name": "Золотой пояс",       "icon": 4, "slot": "belt", "hp": 14, "damage": 1 },

	"wool_cloak":      { "name": "Шерстяной плащ",     "icon": 3, "slot": "cloak", "hp": 8 },
	"leather_cloak":   { "name": "Кожаный плащ",       "icon": 3, "slot": "cloak", "hp": 14 },
	"silk_cloak":      { "name": "Шёлковый плащ",      "icon": 3, "slot": "cloak", "hp": 20, "damage": 1 },
	"royal_cloak":     { "name": "Королевский плащ",   "icon": 4, "slot": "cloak", "hp": 30, "damage": 3 },

	"silver_ring":     { "name": "Серебряное кольцо",  "icon": 0, "slot": "ring", "hp": 5,  "damage": 1 },
	"sapphire_ring":   { "name": "Сапфировое кольцо",  "icon": 0, "slot": "ring", "hp": 12, "damage": 1 },
	"ruby_ring":       { "name": "Кольцо с рубином",   "icon": 0, "slot": "ring", "hp": 4,  "damage": 4 },
	"emerald_ring":    { "name": "Изумрудное кольцо",  "icon": 0, "slot": "ring", "hp": 18, "damage": 2 },
	"golden_ring":     { "name": "Золотое кольцо",     "icon": 0, "slot": "ring", "hp": 12, "damage": 6 },

	"bronze_amulet":   { "name": "Бронзовый амулет",   "icon": 0, "slot": "amulet", "hp": 5,  "damage": 2 },
	"silver_amulet":   { "name": "Серебряный амулет",  "icon": 0, "slot": "amulet", "hp": 10, "damage": 4 },
	"golden_amulet":   { "name": "Золотой амулет",     "icon": 0, "slot": "amulet", "hp": 18, "damage": 8 },
}

static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})

# Компактные строки статов — [{text, color}]. Пустой массив если нечего показать.
static func stat_lines(id: String) -> Array:
	var def_d: Dictionary = DEFS.get(id, {})
	var out: Array = []
	if def_d.has("physDmg"):
		out.append({ "text": "Физ. урон +%d" % int(def_d["physDmg"]), "color": Color(0.98, 0.55, 0.40) })
	if def_d.has("magDmg"):
		out.append({ "text": "Маг. урон +%d" % int(def_d["magDmg"]), "color": Color(0.65, 0.55, 1.00) })
	if def_d.has("damage"):  # legacy generic: украшения
		out.append({ "text": "Урон +%d" % int(def_d["damage"]), "color": Color(0.98, 0.55, 0.40) })
	if def_d.has("hp"):
		out.append({ "text": "Здоровье +%d" % int(def_d["hp"]), "color": Color(0.55, 0.85, 0.45) })
	if def_d.has("heal"):
		out.append({ "text": "Восстанавливает %d HP" % int(def_d["heal"]), "color": Color(0.55, 0.85, 0.45) })
	return out

# Короткая строка в одну линию «+5 HP · +2 урон» для списков.
static func stat_inline(id: String) -> String:
	var def_d: Dictionary = DEFS.get(id, {})
	var parts: Array = []
	if def_d.has("physDmg"):
		parts.append("+%d физ." % int(def_d["physDmg"]))
	if def_d.has("magDmg"):
		parts.append("+%d маг." % int(def_d["magDmg"]))
	if def_d.has("damage"):
		parts.append("+%d урон" % int(def_d["damage"]))
	if def_d.has("hp"):
		parts.append("+%d HP" % int(def_d["hp"]))
	if def_d.has("heal"):
		parts.append("лечит %d" % int(def_d["heal"]))
	return " · ".join(parts)

# Редкость по префиксу id: common/uncommon/rare/epic/legendary.
# 0..4 — числовой ранг для сортировки/цвета.
static func rarity(id: String) -> int:
	if id == "": return -1
	if id.begins_with("golden_") or id == "royal_cloak" or id == "celestial_tome":
		return 4
	if id.begins_with("steel_") or id == "ruby_ring" or id == "emerald_ring" or id == "eldritch_tome":
		return 3
	if id.begins_with("iron_") or id == "sapphire_ring" or id == "silk_cloak" or id == "arcane_tome":
		return 2
	if id.begins_with("bronze_") or id == "silver_ring" or id == "silver_amulet" \
			or id == "leather_armor" or id == "leather_helmet" or id == "leather_boots" \
			or id == "leather_belt" or id == "leather_cloak" or id == "wool_cloak" \
			or id == "health_potion" or id == "mystic_tome":
		return 1
	return 0

static func rarity_color(r: int) -> Color:
	match r:
		4: return Color(1.00, 0.62, 0.24)   # legendary — оранжевое золото
		3: return Color(0.70, 0.38, 0.92)   # epic — пурпур
		2: return Color(0.29, 0.63, 0.96)   # rare — синий
		1: return Color(0.36, 0.78, 0.42)   # uncommon — зелёный
		0: return Color(0.70, 0.68, 0.62)   # common — серый
	return Color(0.40, 0.34, 0.26)          # пустой слот

static func rarity_name(r: int) -> String:
	match r:
		4: return "Легендарный"
		3: return "Эпический"
		2: return "Редкий"
		1: return "Необычный"
		0: return "Обычный"
	return ""

static func kind_name(id: String) -> String:
	var d: Dictionary = DEFS.get(id, {})
	if d.has("slot"):
		return "Экипировка"
	match String(d.get("kind", "")):
		"consumable": return "Расходник"
		"material":   return "Материал"
	return ""

static func weapon_kind(id: String) -> String:
	if id.contains("bow"):
		return "bow"
	if id.contains("tome"):
		return "tome"
	if id.contains("sword"):
		return "sword"
	return ""

static func tome_visual_id(id: String) -> String:
	match id:
		"apprentice_tome":
			return "apprentice_tome"
		"mystic_tome":
			return "mystic_tome"
		"arcane_tome", "eldritch_tome", "celestial_tome":
			return "arcane_tome"
	return ""
