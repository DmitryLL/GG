# Скилл 5: Призрачный залп — конус из 5 голубых стрел.
class_name SkillGhostVolley
extends "res://scripts/skills/skill_def.gd"

func _init() -> void:
	display_name = "Призрачный залп"
	icon_path = "res://assets/sprites/skill_5.png"
	cooldown = 15.0
	server_id = 5
	requires_bow = true
	targets_ground = true
	arrow_style = "ghost"
