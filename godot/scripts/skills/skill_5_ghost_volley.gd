# Скилл 5: Баф крита — шанс крита +75% на 2 сек.
# Старое имя: «Призрачный залп». Механика временно сохраняется старая
# (конус стрел), до реализации реального бафа на крит.
class_name SkillGhostVolley
extends SkillDef

func _init() -> void:
	display_name = "Баф крита"
	icon_path = "res://assets/sprites/skills/skill_5.png"
	cooldown = 15.0
	server_id = 5
	requires_bow = true
	targets_ground = true
	arrow_style = "ghost"
