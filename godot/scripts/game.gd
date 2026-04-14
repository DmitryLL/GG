# Phase 2 game scene: renders the world, spawns the local player, follows
# the camera, connects to Nakama realtime socket. No mobs / shop yet —
# those land in phase 3.
extends Node2D

signal auth_changed

const WORLD_SCRIPT := preload("res://scripts/world.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")

@onready var world_root: Node2D = $World
@onready var entities: Node2D = $Entities
@onready var hello_label: Label = %HelloLabel
@onready var logout_btn: Button = %LogoutBtn
@onready var status_label: Label = %StatusLabel

var world: World
var me: Player
var camera: Camera2D

func _ready() -> void:
	logout_btn.pressed.connect(_on_logout)
	hello_label.text = "Вошёл как %s" % _short_id(Session.auth.user_id)

	world = WORLD_SCRIPT.new()
	world_root.add_child(world)

	me = PLAYER_SCRIPT.new()
	me.setup(world, _short_id(Session.auth.user_id), PLAYER_SCRIPT.variant_from(Session.auth.user_id))
	me.position = world.player_spawn()
	entities.add_child(me)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WorldData.MAP_WIDTH
	camera.limit_bottom = WorldData.MAP_HEIGHT
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	me.add_child(camera)
	camera.make_current()

	status_label.text = "Подключаюсь к real-time…"
	_connect_socket()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := get_viewport().get_camera_2d().get_global_mouse_position()
		me.request_move_to(world_pos)

func _on_logout() -> void:
	Session.logout()
	auth_changed.emit()

func _connect_socket() -> void:
	var socket := Nakama.create_socket_from(Session.client)
	var err: NakamaAsyncResult = await socket.connect_async(Session.auth)
	if err.is_exception():
		status_label.text = "Socket ошибка: %s" % err.get_exception().message
		return
	Session.socket = socket
	status_label.text = "Real-time OK · фаза 3 — мобы, бой, sync"

func _short_id(uid: String) -> String:
	return uid.substr(0, 8)
