# Singleton used for local offline preview of the project.
extends Node

class DemoAuth:
	var username: String = "Demo Ranger"
	var user_id: String = "demo-local-player"
	var expired: bool = false

const DEMO_MODE := true

var client = null
var socket = null
var auth = DemoAuth.new()

# Server-time offset. Обновляется из каждого OP_ME (game._apply_me).
# ВСЕ длительности скиллов и визуальных эффектов должны считаться от
# server_now_ms(), а не от client delta — иначе при сворачивании вкладки
# таймеры замирают и анимации доигрывают после возврата.
var server_offset_ms: int = 0

func server_now_ms() -> int:
	return Time.get_ticks_msec() + server_offset_ms

func _ready() -> void:
	pass

func is_logged_in() -> bool:
	return true

func logout() -> void:
	socket = null
	auth = DemoAuth.new()
