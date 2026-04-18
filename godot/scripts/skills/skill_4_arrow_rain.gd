# Скилл 4: Ливень стрел — AoE-зона с падающими стрелами и пуфами.
class_name SkillArrowRain
extends "res://scripts/skills/skill_def.gd"

func _init() -> void:
	display_name = "Ливень стрел"
	icon_path = "res://assets/sprites/skill_2.png"
	cooldown = 12.0
	server_id = 4
	requires_bow = true
	targets_ground = true
	arrow_style = ""

func on_send(game) -> void:
	# При активации играем «выстрел вверх» — анимация натяжения тетивы
	if game.me:
		game.me.play_bow_shot_upward()

func on_fx(game, body: Dictionary) -> bool:
	if String(body.get("kind", "")) != "rain_start":
		return false
	var pos := Vector2(float(body.get("x", 0)), float(body.get("y", 0)))
	var r := float(body.get("r", 80))
	var dur_ms := int(body.get("duration", 3500))
	var start_t := int(body.get("t", 0))
	game._spawn_rain_zone(pos, r, dur_ms, start_t)
	return true
