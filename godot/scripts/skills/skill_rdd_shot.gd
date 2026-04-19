# РДД-удар — основной дальний удар лучника по одиночной цели.
# Урон 150% от физ. атаки, модификации: стан (1п) / поджог (2п).
class_name SkillRddShot
extends SkillDef

func _init() -> void:
	id = "rdd_shot"
	display_name = "РДД-удар"
	icon_path = "res://assets/sprites/skills/skill_1.png"
	cooldown = 5.0
	mana_cost = 20
	server_id = 1
	requires_bow = true
	targets_mob = true
	arrow_style = "crit"
