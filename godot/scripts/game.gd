# Phase 3c game scene: world + local player + mobs + drops + NPCs + shop + HUD.
extends Node2D

signal auth_changed

const WORLD_SCRIPT := preload("res://scripts/world.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const MOB_SCRIPT := preload("res://scripts/mob.gd")
const DROP_SCRIPT := preload("res://scripts/drop.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const SHOP_SCRIPT := preload("res://scripts/shop.gd")
const CHAT_SCRIPT := preload("res://scripts/chat.gd")
const MINIMAP_SCRIPT := preload("res://scripts/minimap.gd")

const OP_POSITIONS    := 1
const OP_MOVE_INTENT  := 2
const OP_MOBS         := 3
const OP_ATTACK       := 4
const OP_HIT_FLASH    := 5
const OP_PLAYER_HIT   := 6
const OP_DROPS        := 7
const OP_ME           := 8
const OP_EQUIP        := 9
const OP_UNEQUIP      := 10
const OP_USE          := 11
const OP_BUY          := 12
const OP_SELL         := 13
const OP_NPCS         := 14

const MOVE_SEND_HZ := 10.0
const PLAYER_ATTACK_RANGE := 220.0
const PLAYER_ATTACK_COOLDOWN := 0.6
const CLICK_MOB_RADIUS := 24.0
const CLICK_NPC_RADIUS := 28.0
const OP_ARROW := 15
const OP_CHAT_SEND := 16
const OP_CHAT_RELAY := 17

const ARROW_SCRIPT := preload("res://scripts/arrow.gd")

@onready var world_root: Node2D = $World
@onready var entities: Node2D = $Entities
@onready var hello_label: Label = %HelloLabel
@onready var logout_btn: Button = %LogoutBtn
@onready var status_label: Label = %StatusLabel

var world: World
var me: Player
var camera: Camera2D
var hud: Hud
var shop: Shop
var chat_panel: ChatPanel
var minimap: Minimap
var match_id: String = ""
var my_session_id: String = ""
var remotes: Dictionary = {}    # session_id -> Player
var mobs: Dictionary = {}       # mob_id -> Mob
var drops: Dictionary = {}      # drop_id -> DropSprite
var npcs: Array = []            # [{id, name, x, y, stock}]
var npc_nodes: Array = []
var last_me: Dictionary = {}
var send_accum := 0.0
var last_sent_pos: Vector2 = Vector2.INF
var attack_target: Mob = null
var attack_cooldown := 0.0

func _ready() -> void:
	logout_btn.pressed.connect(_on_logout)
	var display := Session.auth.username if Session.auth.username != "" else _short_id(Session.auth.user_id)
	hello_label.text = "Вошёл как %s" % display

	world = WORLD_SCRIPT.new()
	world_root.add_child(world)

	me = PLAYER_SCRIPT.new()
	me.setup(world, display, PLAYER_SCRIPT.variant_from(Session.auth.user_id))
	me.position = world.player_spawn()
	entities.add_child(me)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = world.data.map_cols * WorldData.TILE_SIZE
	camera.limit_bottom = world.data.map_rows * WorldData.TILE_SIZE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	me.add_child(camera)
	camera.make_current()

	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.equip_slot_clicked.connect(_on_inv_click)
	hud.unequip_slot_clicked.connect(_on_unequip)

	shop = SHOP_SCRIPT.new()
	add_child(shop)
	shop.buy_requested.connect(_on_buy)
	shop.sell_requested.connect(_on_sell)

	chat_panel = CHAT_SCRIPT.new()
	add_child(chat_panel)
	chat_panel.send_requested.connect(_on_chat_send)

	minimap = MINIMAP_SCRIPT.new()
	minimap.setup(
		world,
		Callable(self, "_mm_me"),
		Callable(self, "_mm_others"),
		Callable(self, "_mm_mobs"),
		Callable(self, "_mm_npcs"),
	)
	add_child(minimap)

	status_label.text = "Подключаюсь к real-time…"
	_connect_and_join()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := get_viewport().get_camera_2d().get_global_mouse_position()
		# NPC takes priority over mobs/move.
		var npc := _npc_at(world_pos)
		if not npc.is_empty():
			attack_target = null
			var d_n: float = me.position.distance_to(Vector2(float(npc["x"]), float(npc["y"])))
			if d_n <= 80.0:
				shop.open(String(npc["id"]), npc.get("stock", []), last_me)
				return
			me.request_move_to(Vector2(float(npc["x"]), float(npc["y"])))
			return
		var mob_hit := _mob_at(world_pos)
		if mob_hit != null:
			# Lock onto the mob — pursue + auto-attack.
			attack_target = mob_hit
			return
		# Bare-ground click → just move, drop any current target.
		attack_target = null
		me.request_move_to(world_pos)

func _process(delta: float) -> void:
	if match_id == "" or Session.socket == null:
		return

	# Auto-pursuit: keep walking toward the locked target and shoot when in range.
	if attack_target != null:
		if not is_instance_valid(attack_target) or not attack_target.alive:
			attack_target = null
		else:
			var d: float = me.position.distance_to(attack_target.position)
			if d <= PLAYER_ATTACK_RANGE:
				me.has_target = false
				if attack_cooldown <= 0.0:
					Session.socket.send_match_state_async(match_id, OP_ATTACK, JSON.stringify({"mobId": attack_target.mob_id}))
					attack_cooldown = PLAYER_ATTACK_COOLDOWN
			else:
				me.request_move_to(attack_target.position)
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

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
		OP_POSITIONS:  _apply_positions(body)
		OP_MOBS:       _apply_mobs(body)
		OP_HIT_FLASH:
			var mid: String = String(body.get("mobId", ""))
			var m: Mob = mobs.get(mid)
			if m: m.flash()
		OP_PLAYER_HIT:
			var sid: String = String(body.get("sessionId", ""))
			var p: Player = me if sid == my_session_id else remotes.get(sid)
			if p: p.flash()
		OP_DROPS:      _apply_drops(body)
		OP_ME:         _apply_me(body)
		OP_NPCS:       _apply_npcs(body)
		OP_ARROW:      _spawn_arrow(body)
		OP_CHAT_RELAY: _apply_chat(body)

func _apply_positions(body: Dictionary) -> void:
	for p in body.get("players", []):
		var sid: String = p.get("sid", "")
		if sid == "":
			continue
		var x: float = float(p.get("x", 0))
		var y: float = float(p.get("y", 0))
		var hp: float = float(p.get("hp", 100))
		var lv: int = int(p.get("lv", 1))
		if sid == my_session_id:
			# hp_max comes from OP_ME; use last known, fall back to 100.
			var max_hp: float = float(last_me.get("hpMax", 100))
			me.set_hp(hp, max_hp)
			if me.position.distance_to(Vector2(x, y)) > 64.0:
				me.position = Vector2(x, y)
				last_sent_pos = me.position
			continue
		var display: String = String(p.get("n", sid.substr(0, 6)))
		var uid: String = String(p.get("uid", sid))
		var remote: Player = remotes.get(sid)
		if remote == null:
			remote = PLAYER_SCRIPT.new()
			remote.setup(world, "%s (Ур.%d)" % [display, lv], PLAYER_SCRIPT.variant_from(uid))
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

func _apply_drops(body: Dictionary) -> void:
	if body.has("full") and bool(body.get("full")):
		for dv in drops.values():
			(dv as DropSprite).queue_free()
		drops.clear()
	if body.has("remove"):
		for id in body.get("remove", []):
			var d: DropSprite = drops.get(id)
			if d:
				d.queue_free()
				drops.erase(id)
	for d_entry in body.get("add", body.get("drops", [])):
		var id: String = String(d_entry.get("id", ""))
		if id == "":
			continue
		if drops.has(id):
			continue
		var ds: DropSprite = DROP_SCRIPT.new()
		ds.setup(id, String(d_entry.get("i", "slime_jelly")))
		ds.position = Vector2(float(d_entry.get("x", 0)), float(d_entry.get("y", 0)))
		entities.add_child(ds)
		drops[id] = ds

func _apply_me(body: Dictionary) -> void:
	last_me = body
	hud.update_me(body)
	shop.refresh(body)
	me.set_hp(float(body.get("hp", 0)), float(body.get("hpMax", 100)))

func _apply_npcs(body: Dictionary) -> void:
	for n in body.get("npcs", []):
		var entry: Dictionary = n
		var id: String = String(entry.get("id", ""))
		if id == "":
			continue
		npcs.append(entry)
		var npc_root := Node2D.new()
		npc_root.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/sprites/npc.png")
		sprite.scale = Vector2(1.2, 1.2)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		npc_root.add_child(sprite)
		var label := Label.new()
		label.text = String(entry.get("name", "?"))
		label.add_theme_color_override("font_color", Color(0.99, 0.89, 0.51, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 3)
		label.size = Vector2(120, 16)
		label.position = Vector2(-60, -32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		npc_root.add_child(label)
		entities.add_child(npc_root)
		npc_nodes.append(npc_root)

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

func _npc_at(world_pos: Vector2) -> Dictionary:
	for n in npcs:
		var entry: Dictionary = n
		var p := Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		if p.distance_to(world_pos) < CLICK_NPC_RADIUS:
			return entry
	return {}

func _on_inv_click(idx: int) -> void:
	if match_id == "":
		return
	var inv: Array = last_me.get("inv", [])
	if idx < 0 or idx >= inv.size():
		return
	var item_id := String(inv[idx].get("itemId", ""))
	var def: Dictionary = Items.def(item_id)
	var kind := String(def.get("kind", ""))
	if kind == "consumable":
		Session.socket.send_match_state_async(match_id, OP_USE, JSON.stringify({"slot": idx}))
	elif kind == "weapon" or kind == "armor":
		Session.socket.send_match_state_async(match_id, OP_EQUIP, JSON.stringify({"slot": idx}))

func _on_unequip(slot: String) -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_UNEQUIP, JSON.stringify({"slot": slot}))

func _on_buy(npc_id: String, item_id: String) -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_BUY, JSON.stringify({"npcId": npc_id, "itemId": item_id}))

func _on_sell(slot_idx: int) -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_SELL, JSON.stringify({"slot": slot_idx}))

func _apply_chat(body: Dictionary) -> void:
	var sid: String = String(body.get("sid", ""))
	var who: String = String(body.get("n", "?"))
	var text: String = String(body.get("t", ""))
	if text.is_empty():
		return
	chat_panel.append_line(who, text)
	var speaker: Player = me if sid == my_session_id else remotes.get(sid)
	if speaker:
		speaker.show_bubble(text)

func _on_chat_send(text: String) -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_CHAT_SEND, JSON.stringify({"text": text}))

func _spawn_arrow(body: Dictionary) -> void:
	var from := Vector2(float(body.get("fx", 0)), float(body.get("fy", 0)))
	var to := Vector2(float(body.get("tx", 0)), float(body.get("ty", 0)))
	var arrow: Arrow = ARROW_SCRIPT.new()
	entities.add_child(arrow)
	arrow.shoot(from, to)

func _mm_me() -> Vector2:
	return me.position if me != null else Vector2.ZERO
func _mm_others() -> Array:
	return remotes.values()
func _mm_mobs() -> Array:
	return mobs.values()
func _mm_npcs() -> Array:
	return npcs

func _short_id(uid: String) -> String:
	return uid.substr(0, 8)
