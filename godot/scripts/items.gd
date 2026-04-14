# Client-side item definitions mirroring nakama-server/src/main.ts ITEMS.
# Used for display (icon, name, kind). Server is source of truth for prices
# and behaviour.
class_name Items
extends RefCounted

const DEFS := {
	"slime_jelly":   { "name": "Слизь",           "icon": 0, "kind": "material" },
	"wood_sword":    { "name": "Деревянный меч",  "icon": 1, "kind": "weapon" },
	"iron_sword":    { "name": "Железный меч",    "icon": 2, "kind": "weapon" },
	"cloth_armor":   { "name": "Тканая броня",    "icon": 3, "kind": "armor" },
	"iron_armor":    { "name": "Железная броня",  "icon": 4, "kind": "armor" },
	"health_potion": { "name": "Зелье лечения",   "icon": 5, "kind": "consumable" },
}

static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})
