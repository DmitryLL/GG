# Реестр всех скиллов. Единственное место, где явно перечислены классы скиллов.
# Чтобы добавить новый — создай scripts/skills/skill_N_name.gd и впиши в SKILLS.
class_name SkillRegistry
extends RefCounted

const SkillDef = preload("res://scripts/skills/skill_def.gd")
static var _instances: Array = []

static func all() -> Array:
	if _instances.is_empty():
		_instances = [
			_make("Меткий выстрел", 5.0, true, false),
			_make("Отравленная стрела", 6.0, true, false),
			_make("Отскок", 8.0, false, false),
			_make("Ливень стрел", 12.0, false, true),
			_make("Призрачный залп", 15.0, false, true),
		]
	return _instances

static func by_index(i: int) -> SkillDef:
	var arr := all()
	if i < 0 or i >= arr.size():
		return null
	return arr[i]

static func count() -> int:
	return all().size()

static func _make(name: String, cooldown: float, targets_mob: bool, targets_ground: bool) -> SkillDef:
	var d := SkillDef.new()
	d.display_name = name
	d.cooldown = cooldown
	d.targets_mob = targets_mob
	d.targets_ground = targets_ground
	return d
