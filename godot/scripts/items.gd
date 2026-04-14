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
