# Клиентские мета-данные предметов: имя, иконка, слот.
# Сервер — источник правды для статов и цен.
class_name Items
extends RefCounted

const DEFS := {
	"slime_jelly":    { "name": "Слизь",             "icon": 0, "kind": "material" },
	"health_potion":  { "name": "Зелье лечения",     "icon": 5, "kind": "consumable" },

	"wood_sword":     { "name": "Деревянный меч",    "icon": 1, "slot": "weapon" },
	"iron_sword":     { "name": "Железный меч",      "icon": 2, "slot": "weapon" },

	"cloth_armor":    { "name": "Тканая броня",      "icon": 3, "slot": "body" },
	"iron_armor":     { "name": "Железная броня",    "icon": 4, "slot": "body" },

	"leather_helmet": { "name": "Кожаный шлем",      "icon": 3, "slot": "head" },
	"iron_helmet":    { "name": "Железный шлем",     "icon": 4, "slot": "head" },

	"leather_boots":  { "name": "Кожаные сапоги",    "icon": 3, "slot": "boots" },
	"iron_boots":     { "name": "Железные сапоги",   "icon": 4, "slot": "boots" },

	"leather_belt":   { "name": "Кожаный пояс",      "icon": 3, "slot": "belt" },

	"wool_cloak":     { "name": "Шерстяной плащ",    "icon": 3, "slot": "cloak" },

	"silver_ring":    { "name": "Серебряное кольцо", "icon": 0, "slot": "ring" },
	"ruby_ring":      { "name": "Кольцо с рубином",  "icon": 0, "slot": "ring" },

	"bronze_amulet":  { "name": "Бронзовый амулет",  "icon": 0, "slot": "amulet" },
}

static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})
