# Скилл 1: РДД-удар — основной дальний удар по одиночной цели, 150% от силы атаки.
# Старое имя: «Меткий выстрел». Механика временно сохраняется старая (x2),
# до переработки под точный коэффициент 1.5× и привязку мод (стан/поджог).
class_name SkillPreciseShot
extends SkillDef

func _init() -> void:
	display_name = "РДД-удар"
	icon_path = "res://assets/sprites/skills/skill_1.png"
	cooldown = 5.0
	server_id = 1
	requires_bow = true
	targets_mob = true
	arrow_style = "crit"
