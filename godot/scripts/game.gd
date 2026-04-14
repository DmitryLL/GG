# Phase 3b game scene: world + local player + mobs + combat via Nakama match.
extends Node2D

signal auth_changed

const WORLD_SCRIPT := preload("res://scripts/world.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const MOB_SCRIPT := preload("res://scripts/mob.gd")

const OP_POSITIONS    := 1
const OP_MOVE_INTENT  := 2
const OP_MOBS         := 3
const OP_ATTACK       := 4
const OP_HIT_FLASH    := 5
const OP_PLAYER_HIT   := 6

const MOVE_SEND_HZ := 10.0
const PLAYER_ATTACK_RANGE := 48.0
const CLICK_MOB_RADIUS := 24.0

@onready var world_root: Node2D = $World
@onready var entities: Node2D = $Entities
@onready var hello_label: Label = %HelloLabel
@onready var logout_btn: Button = %LogoutBtn
@onready var status_label: Label = %StatusLabel

var world: World
var me: Player
var camera: Camera2D
var match_id: String = ""
var my_session_id: String = ""
var remotes: Dictionary = {}  # session_id -> Player
var mobs: Dictionary = {}      # mob_id -> Mob
var send_accum := 0.0
var last_sent_pos: Vector2 = Vector2.INF

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
	_connect_and_join()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := get_viewport().get_camera_2d().get_global_mouse_position()
		var hit := _mob_at(world_pos)
		if hit != null and match_id != "":
			var d := me.position.distance_to(hit.position)
			if d <= PLAYER_ATTACK_RANGE:
				Session.socket.send_match_state_async(match_id, OP_ATTACK, JSON.stringify({"mobId": hit.mob_id}))
				return
			me.request_move_to(hit.position)
			return
		me.request_move_to(world_pos)

func _process(delta: float) -> void:
	if match_id == "" or Session.socket == null:
		return
	send_accum += delta
	if send_accum < 1.0 / MOVE_SEND_HZ:
		return
	send_accum = 0.0
	if last_sent_pos.distance_to(me.position) < 0.5:
		return
	last_sent_pos = me.position
	Session.socket.send_match_state_async(match_id, OP_MOVE_INTENT, JSON.stringify({"x": me.position.x, "y": me.position.y}))

func _on_logout() -> void:
	Session.logout()
	auth_changed.emit()

func _connect_and_join() -> void:
	var socket := Nakama.create_socket_from(Session.client)
	var err: NakamaAsyncResult = await socket.connect_async(Session.auth)
	if err.is_exception():
		status_label.text = "Socket ошибка: %s" % err.get_exception().message
		return
	Session.socket = socket
	socket.received_match_state.connect(_on_match_state)
	socket.received_match_presence.connect(_on_presence)

	var rpc_res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "get_world_match", "")
	if rpc_res.is_exception():
		status_label.text = "RPC ошибка: %s" % rpc_res.get_exception().message
		return
	var data: Dictionary = JSON.parse_string(rpc_res.payload)
	var requested_id: String = data.get("match_id", "")
	if requested_id == "":
		status_label.text = "Пустой match_id"
		return

	var joined: NakamaRTAPI.Match = await socket.join_match_async(requested_id)
	if joined.is_exception():
		status_label.text = "Join ошибка: %s" % joined.get_exception().message
		return
	match_id = joined.match_id
	my_session_id = joined.self_user.session_id
	status_label.text = "В мире · игроков: %d" % (joined.presences.size() + 1)

func _on_match_state(state: NakamaRTAPI.MatchData) -> void:
	var body = JSON.parse_string(state.data)
	if typeof(body) != TYPE_DICTIONARY:
		return
	match state.op_code:
		OP_POSITIONS:
			_apply_positions(body)
		OP_MOBS:
			_apply_mobs(body)
		OP_HIT_FLASH:
			var mid: String = String(body.get("mobId", ""))
			var m: Mob = mobs.get(mid)
			if m: m.flash()
		OP_PLAYER_HIT:
			var sid: String = String(body.get("sessionId", ""))
			var p: Player = me if sid == my_session_id else remotes.get(sid)
			if p: p.flash()

func _apply_positions(body: Dictionary) -> void:
	for p in body.get("players", []):
		var sid: String = p.get("sid", "")
		if sid == "":
			continue
		var x: float = float(p.get("x", 0))
		var y: float = float(p.get("y", 0))
		var hp: float = float(p.get("hp", 100))
		if sid == my_session_id:
			me.set_hp(hp, 100.0)
			# Server teleported us (respawn) — snap if far from current.
			if me.position.distance_to(Vector2(x, y)) > 64.0:
				me.position = Vector2(x, y)
				last_sent_pos = me.position
			continue
		var display: String = String(p.get("n", sid.substr(0, 6)))
		var uid: String = String(p.get("uid", sid))
		var remote: Player = remotes.get(sid)
		if remote == null:
			remote = PLAYER_SCRIPT.new()
			remote.setup(world, display, PLAYER_SCRIPT.variant_from(uid))
			remote.local = false
			remote.position = Vector2(x, y)
			entities.add_child(remote)
			remotes[sid] = remote
		remote.position = Vector2(x, y)
		remote.set_hp(hp, 100.0)

func _apply_mobs(body: Dictionary) -> void:
	for m in body.get("mobs", []):
		var mid: String = String(m.get("id", ""))
		if mid == "":
			continue
		var kind: String = String(m.get("t", "slime"))
		var ms: Mob = mobs.get(mid)
		if ms == null:
			ms = MOB_SCRIPT.new()
			ms.setup(mid, kind)
			entities.add_child(ms)
			mobs[mid] = ms
		ms.position = Vector2(float(m.get("x", 0)), float(m.get("y", 0)))
		ms.set_hp(float(m.get("hp", 0)), float(m.get("hpMax", 30)))
		ms.set_alive(String(m.get("st", "alive")) == "alive")

func _on_presence(ev: NakamaRTAPI.MatchPresenceEvent) -> void:
	for p in ev.leaves:
		var sid: String = p.session_id
		var r: Player = remotes.get(sid)
		if r:
			r.queue_free()
			remotes.erase(sid)
	if status_label:
		status_label.text = "В мире · игроков: %d" % (remotes.size() + 1)

func _mob_at(world_pos: Vector2) -> Mob:
	var best: Mob = null
	var best_d: float = 9999.0
	for mob_v in mobs.values():
		var mob: Mob = mob_v
		if not mob.alive:
			continue
		var d: float = mob.position.distance_to(world_pos)
		if d < CLICK_MOB_RADIUS and d < best_d:
			best = mob
			best_d = d
	return best

func _short_id(uid: String) -> String:
	return uid.substr(0, 8)
