# Клиентские мета-данные предметов: имя, иконка, слот.
# Сервер — источник правды для статов и цен.
class_name Items
extends RefCounted

const DEFS := {
	"slime_jelly":     { "name": "Слизь",              "icon": 0, "kind": "material" },
	"wolf_pelt":       { "name": "Шкура волка",        "icon": 0, "kind": "material" },
	"goblin_ear":      { "name": "Ухо гоблина",        "icon": 0, "kind": "material" },

	"small_potion":    { "name": "Малое зелье",        "icon": 5, "kind": "consumable" },
	"health_potion":   { "name": "Зелье лечения",      "icon": 5, "kind": "consumable" },
	"great_potion":    { "name": "Большое зелье",      "icon": 5, "kind": "consumable" },

	"wood_sword":      { "name": "Деревянный меч",     "icon": 1, "slot": "weapon" },
	"bronze_sword":    { "name": "Бронзовый меч",      "icon": 1, "slot": "weapon" },
	"iron_sword":      { "name": "Железный меч",       "icon": 2, "slot": "weapon" },
	"steel_sword":     { "name": "Стальной меч",       "icon": 2, "slot": "weapon" },
	"golden_sword":    { "name": "Золотой меч",        "icon": 2, "slot": "weapon" },

	"cloth_armor":     { "name": "Тканая броня",       "icon": 3, "slot": "body" },
	"leather_armor":   { "name": "Кожаная броня",      "icon": 3, "slot": "body" },
	"bronze_armor":    { "name": "Бронзовая броня",    "icon": 4, "slot": "body" },
	"iron_armor":      { "name": "Железная броня",     "icon": 4, "slot": "body" },
	"steel_armor":     { "name": "Стальная броня",     "icon": 4, "slot": "body" },
	"golden_armor":    { "name": "Золотая броня",      "icon": 4, "slot": "body" },

	"leather_helmet":  { "name": "Кожаный шлем",       "icon": 3, "slot": "head" },
	"bronze_helmet":   { "name": "Бронзовый шлем",     "icon": 4, "slot": "head" },
	"iron_helmet":     { "name": "Железный шлем",      "icon": 4, "slot": "head" },
	"steel_helmet":    { "name": "Стальной шлем",      "icon": 4, "slot": "head" },
	"golden_helmet":   { "name": "Золотой шлем",       "icon": 4, "slot": "head" },

	"leather_boots":   { "name": "Кожаные сапоги",     "icon": 3, "slot": "boots" },
	"bronze_boots":    { "name": "Бронзовые сапоги",   "icon": 4, "slot": "boots" },
	"iron_boots":      { "name": "Железные сапоги",    "icon": 4, "slot": "boots" },
	"steel_boots":     { "name": "Стальные сапоги",    "icon": 4, "slot": "boots" },
	"golden_boots":    { "name": "Золотые сапоги",     "icon": 4, "slot": "boots" },

	"leather_belt":    { "name": "Кожаный пояс",       "icon": 3, "slot": "belt" },
	"iron_belt":       { "name": "Железный пояс",      "icon": 4, "slot": "belt" },
	"golden_belt":     { "name": "Золотой пояс",       "icon": 4, "slot": "belt" },

	"wool_cloak":      { "name": "Шерстяной плащ",     "icon": 3, "slot": "cloak" },
	"leather_cloak":   { "name": "Кожаный плащ",       "icon": 3, "slot": "cloak" },
	"silk_cloak":      { "name": "Шёлковый плащ",      "icon": 3, "slot": "cloak" },
	"royal_cloak":     { "name": "Королевский плащ",   "icon": 4, "slot": "cloak" },

	"silver_ring":     { "name": "Серебряное кольцо",  "icon": 0, "slot": "ring" },
	"sapphire_ring":   { "name": "Сапфировое кольцо",  "icon": 0, "slot": "ring" },
	"ruby_ring":       { "name": "Кольцо с рубином",   "icon": 0, "slot": "ring" },
	"emerald_ring":    { "name": "Изумрудное кольцо",  "icon": 0, "slot": "ring" },
	"golden_ring":     { "name": "Золотое кольцо",     "icon": 0, "slot": "ring" },

	"bronze_amulet":   { "name": "Бронзовый амулет",   "icon": 0, "slot": "amulet" },
	"silver_amulet":   { "name": "Серебряный амулет",  "icon": 0, "slot": "amulet" },
	"golden_amulet":   { "name": "Золотой амулет",     "icon": 0, "slot": "amulet" },
}

static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})

# Редкость по префиксу id: common/uncommon/rare/epic/legendary.
# 0..4 — числовой ранг для сортировки/цвета.
static func rarity(id: String) -> int:
	if id == "": return -1
	if id.begins_with("golden_") or id == "royal_cloak":
		return 4
	if id.begins_with("steel_") or id == "ruby_ring" or id == "emerald_ring":
		return 3
	if id.begins_with("iron_") or id == "sapphire_ring" or id == "silk_cloak":
		return 2
	if id.begins_with("bronze_") or id == "silver_ring" or id == "silver_amulet" \
			or id == "leather_armor" or id == "leather_helmet" or id == "leather_boots" \
			or id == "leather_belt" or id == "leather_cloak" or id == "wool_cloak" \
			or id == "health_potion":
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
