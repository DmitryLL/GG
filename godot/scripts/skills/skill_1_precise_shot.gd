# Скилл 1: Меткий выстрел — одиночная цель, x2 урон, чёрная стрела.
class_name SkillPreciseShot
extends "res://scripts/skills/skill_def.gd"

func _init() -> void:
	display_name = "Меткий выстрел"
	icon_path = "res://assets/sprites/skill_1.png"
	cooldown = 5.0
	server_id = 1
	requires_bow = true
	targets_mob = true
	arrow_style = "crit"
