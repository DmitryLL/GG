# Деза — отбрасывание цели назад на 2 шага + легаси DoT/slow.
# Модификации: рут 0.5с (1п) / снятие положительного баффа (2п, stub).
class_name SkillDeza
extends SkillDef

func _init() -> void:
	id = "deza"
	display_name = "Деза"
	icon_path = "res://assets/sprites/skills/skill_4.png"
	cooldown = 6.0
	server_id = 2
	requires_bow = true
	targets_mob = true
	arrow_style = "poison"
