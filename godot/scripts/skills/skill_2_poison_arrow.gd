# Скилл 2: Отравленная стрела — DoT + slow, стакается до 3 раз.
class_name SkillPoisonArrow
extends SkillDef

func _init() -> void:
	display_name = "Отравленная стрела"
	icon_path = "res://assets/sprites/skills/skill_4.png"
	cooldown = 6.0
	server_id = 2
	requires_bow = true
	targets_mob = true
	arrow_style = "poison"
