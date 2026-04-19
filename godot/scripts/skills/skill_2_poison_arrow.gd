# Скилл 2: Деза — отбрасывание цели назад на 2 шага.
# Старое имя: «Отравленная стрела». Механика временно сохраняется старая
# (DoT + slow), до реализации реального knockback'а.
class_name SkillPoisonArrow
extends SkillDef

func _init() -> void:
	display_name = "Деза"
	icon_path = "res://assets/sprites/skills/skill_2.png"
	cooldown = 6.0
	server_id = 2
	requires_bow = true
	targets_mob = true
	arrow_style = "poison"
