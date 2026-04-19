# Реестр всех скиллов. Единственное место, где явно перечислены классы скиллов.
# Чтобы добавить новый — создай scripts/skills/skill_<name>.gd и впиши в SKILLS.
# Порядок в массиве — это дефолтный порядок слотов hotbar (0..4), позже
# игрок сможет перетащить скиллы местами. Server_id и id — стабильны.
class_name SkillRegistry
extends RefCounted

const SKILLS: Array = [
	preload("res://scripts/skills/skill_rdd_shot.gd"),
	preload("res://scripts/skills/skill_deza.gd"),
	preload("res://scripts/skills/skill_escape.gd"),
	preload("res://scripts/skills/skill_arrow_hail.gd"),
	preload("res://scripts/skills/skill_crit_buff.gd"),
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

# Поиск скилла по стабильному строковому id (например "rdd_shot").
# Будет нужен когда hotbar станет конфигурируемым.
static func by_id(skill_id: String) -> SkillDef:
	for d in all():
		if d.id == skill_id:
			return d
	return null

# Поиск по server_id — для маппинга OP_ME.skillCd (ключи — number/string
# чисел) и OP_SKILL_REJECT.
static func by_server_id(sid: int) -> SkillDef:
	for d in all():
		if d.server_id == sid:
			return d
	return null
