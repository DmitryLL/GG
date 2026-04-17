# Реестр всех скиллов. Единственное место, где явно перечислены классы скиллов.
# Чтобы добавить новый — создай scripts/skills/skill_N_name.gd и впиши в SKILLS.
class_name SkillRegistry
extends RefCounted

const SKILLS: Array = [
	preload("res://scripts/skills/skill_1_precise_shot.gd"),
	preload("res://scripts/skills/skill_2_poison_arrow.gd"),
	preload("res://scripts/skills/skill_3_dodge.gd"),
	preload("res://scripts/skills/skill_4_arrow_rain.gd"),
	preload("res://scripts/skills/skill_5_ghost_volley.gd"),
]

static var _instances: Array = []

static func all() -> Array:
	if _instances.is_empty():
		for cls in SKILLS:
			_instances.append(cls.new())
	return _instances

static func by_index(i: int) -> SkillDef:
	var arr := all()
	if i < 0 or i >= arr.size():
		return null
	return arr[i]

static func count() -> int:
	return SKILLS.size()
