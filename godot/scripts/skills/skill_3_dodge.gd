# Скилл 3: Отскок — телепорт, неуязвимость, x2 атак-спид.
class_name SkillDodge
extends SkillDef

func _init() -> void:
	display_name = "Отскок"
	icon_path = "res://assets/sprites/skill_3.png"
	cooldown = 8.0
	server_id = 3
	# Не таргет-скилл: исполняется на себе (с учётом текущей цели)
	arrow_style = ""

func on_send(_game) -> void:
	# Никакой анимации лука — это прыжок. Визуал делает on_fx.
	pass

func on_fx(game, body: Dictionary) -> bool:
	if String(body.get("kind", "")) != "dodge":
		return false
	var sid := String(body.get("sid", ""))
	var px := float(body.get("fx", 0))
	var py := float(body.get("fy", 0))
	var p = game.me if sid == game.my_session_id else game.remotes.get(sid)
	if p == null:
		return true
	var dodge_target := Vector2(px, py)
	var tw := game.create_tween()
	tw.tween_property(p, "position", dodge_target, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	p.flash()
	for i in range(3):
		var ghost := Sprite2D.new()
		ghost.texture = p.sprite.texture
		ghost.hframes = p.sprite.hframes
		ghost.vframes = p.sprite.vframes
		ghost.frame = p.sprite.frame
		ghost.scale = p.sprite.scale
		ghost.offset = Vector2(0, -16)
		ghost.modulate = Color(0.5, 0.9, 1.0, 0.5 - i * 0.15)
		ghost.position = p.position
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		game.world.add_child(ghost)
		var gt := game.create_tween()
		gt.tween_property(ghost, "modulate:a", 0.0, 0.4 + i * 0.1)
		gt.finished.connect(ghost.queue_free)
	return true
