# Град стрел — AoE-зона, 30% урона × 3 сек × 5 целей (GROUND).
# Модификации: slow 5 целям (1п) / финальный оглушающий тик (2п).
class_name SkillArrowHail
extends SkillDef

func _init() -> void:
	id = "arrow_hail"
	display_name = "Град стрел"
	icon_path = "res://assets/sprites/skills/skill_2.png"
	cooldown = 12.0
	mana_cost = 40
	server_id = 4
	requires_bow = true
	targets_ground = true
	arrow_style = ""

func on_send(_game) -> void:
	# Анимация bow_shot_upward приходит от сервера через OP_PLAYER_ACTION.
	pass

func on_fx(game, body: Dictionary) -> bool:
	if String(body.get("kind", "")) != "rain_start":
		return false
	var pos := Vector2(float(body.get("x", 0)), float(body.get("y", 0)))
	var r := float(body.get("r", 80))
	var dur_ms := int(body.get("duration", 3500))
	var start_t := int(body.get("t", 0))
	game._spawn_rain_zone(pos, r, dur_ms, start_t)
	# Анимация bow_shot_upward у кастера — универсально через OP_PLAYER_ACTION.
	return true
