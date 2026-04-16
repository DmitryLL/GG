# Скилл 4: Отравленная стрела — DoT + slow, стакается до 3 раз.
class_name SkillPoisonArrow
extends SkillDef

func _init() -> void:
	display_name = "Отравленная стрела"
	icon_path = "res://assets/sprites/skill_4.png"
	cooldown = 6.0
	server_id = 4
	targets_mob = true
	arrow_style = "poison"
