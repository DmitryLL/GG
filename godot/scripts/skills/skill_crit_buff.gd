# Баф крита — шанс крита +75% на 2 сек, self-баф (INSTANT).
# Модификации: командный бафф крита +20% (1п) / +20% pierce (2п).
class_name SkillCritBuff
extends SkillDef

func _init() -> void:
	id = "crit_buff"
	display_name = "Баф крита"
	icon_path = "res://assets/sprites/skills/skill_5.png"
	cooldown = 15.0
	server_id = 5
	requires_bow = true
	targets_ground = false  # INSTANT, не нужен таргет или точка на земле
	arrow_style = ""
