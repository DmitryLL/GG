# Скилл 1: Меткий выстрел — одиночная цель, x2 урон, чёрная стрела.
class_name SkillPreciseShot
extends SkillDef

func _init() -> void:
	display_name = "Меткий выстрел"
	icon_path = "res://assets/sprites/skill_1.png"
	cooldown = 5.0
	server_id = 1
	targets_mob = true
	arrow_style = "crit"
