# Phase 3c+ game scene: world + local player + mobs + loot-on-corpse + NPCs + shop + HUD.
extends Node2D

signal auth_changed

const WORLD_SCRIPT := preload("res://scripts/world.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const MOB_SCRIPT := preload("res://scripts/mob.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const SHOP_SCRIPT := preload("res://scripts/shop.gd")
const CHAT_SCRIPT := preload("res://scripts/chat.gd")
const MINIMAP_SCRIPT := preload("res://scripts/minimap.gd")
const NAMEPLATE_SCRIPT := preload("res://scripts/nameplate.gd")
const CHARACTER_SCRIPT := preload("res://scripts/character_window.gd")
const BAG_SCRIPT := preload("res://scripts/bag_window.gd")
const LOOT_SCRIPT := preload("res://scripts/loot_window.gd")
const SKILLBAR_SCRIPT := preload("res://scripts/skillbar.gd")

const OP_POSITIONS    := 1
const OP_MOVE_INTENT  := 2
const OP_MOBS         := 3
const OP_ATTACK       := 4
const OP_HIT_FLASH    := 5
const OP_PLAYER_HIT   := 6
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
const CLICK_MOB_RADIUS := 60.0
const CLICK_NPC_RADIUS := 28.0
const OP_ARROW := 15
const OP_CHAT_SEND := 16
const OP_CHAT_RELAY := 17
const OP_LOOT_TAKE := 18
const OP_LOOT_TAKE_ALL := 19
const OP_SKILL        := 20
const OP_SKILL_FX     := 21

const ARROW_SCRIPT := preload("res://scripts/arrow.gd")

@onready var world_root: Node2D = $World
@onready var entities: Node2D = $Entities
@onready var status_label: Label = %StatusLabel

var world: World
var me: Player
var camera: Camera2D
var hud: Hud
var shop: Shop
var chat_panel: ChatPanel
var minimap: Minimap
var nameplate: Nameplate
var character_win: CharacterWindow
var bag_win: BagWindow
var loot_win: LootWindow
var match_id: String = ""
var my_session_id: String = ""
var remotes: Dictionary = {}    # session_id -> Player
var mobs: Dictionary = {}       # mob_id -> Mob
var npcs: Array = []            # [{id, name, x, y, stock}]
var npc_nodes: Array = []
var last_me: Dictionary = {}
var send_accum := 0.0
var last_sent_pos: Vector2 = Vector2.INF
var attack_target: Mob = null
var attack_cooldown := 0.0
var _click_marker: Sprite2D
var _click_marker_t := 0.0
var _prev_highlight: Mob = null
var skillbar: SkillBar
var targeting_skill: int = -1  # -1 = нет таргетинга, иначе индекс скилла в SKILLS
var _targeting_ring: Sprite2D

func _ready() -> void:
	var display := Session.auth.username if Session.auth.username != "" else _short_id(Session.auth.user_id)

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
	# (старая связь HUD.equip_slot_clicked → _on_inv_click убрана,
	# теперь клики идут из bag_win)

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

	_click_marker = Sprite2D.new()
	_click_marker.texture = _make_marker_texture()
	_click_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_click_marker.visible = false
	_click_marker.z_index = 100
	world.add_child(_click_marker)

	_targeting_ring = _make_circle_sprite(80, Color(1.0, 0.6, 0.2, 0.6))
	_targeting_ring.visible = false
	_targeting_ring.z_index = 95
	world.add_child(_targeting_ring)

	nameplate = NAMEPLATE_SCRIPT.new()
	add_child(nameplate)
	nameplate.set_player_name(display)
	hud.logout_button_pressed.connect(_on_logout)

	character_win = CHARACTER_SCRIPT.new()
	add_child(character_win)
	character_win.set_doll(PLAYER_SCRIPT.variant_from(Session.auth.user_id))
	character_win.set_name(display)
	character_win.unequip_requested.connect(_on_unequip)
	character_win.equip_requested.connect(_on_equip_to_slot)
	hud.character_button_pressed.connect(_on_character_button)

	bag_win = BAG_SCRIPT.new()
	add_child(bag_win)
	bag_win.use_or_equip.connect(_on_inv_click)
	hud.bag_button_pressed.connect(_on_bag_button)

	skillbar = SKILLBAR_SCRIPT.new()
	add_child(skillbar)
	skillbar.skill_activated.connect(_on_skill_activated)

	loot_win = LOOT_SCRIPT.new()
	add_child(loot_win)
	loot_win.take_requested.connect(func(mob_id, idx):
		Session.socket.send_match_state_async(match_id, OP_LOOT_TAKE, JSON.stringify({"mobId": mob_id, "index": idx})))
	loot_win.take_all_requested.connect(func(mob_id):
		Session.socket.send_match_state_async(match_id, OP_LOOT_TAKE_ALL, JSON.stringify({"mobId": mob_id})))

	status_label.text = "Подключаюсь к real-time…"
	_connect_and_join()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and targeting_skill >= 0:
		targeting_skill = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and targeting_skill >= 0:
		targeting_skill = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := get_viewport().get_camera_2d().get_global_mouse_position()
		if targeting_skill >= 0:
			var idx := targeting_skill
			var sk: Dictionary = skillbar.SKILLS[idx]
			targeting_skill = -1
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			if bool(sk["targets_mob"]):
				var mob_hit := _mob_at(world_pos)
				if mob_hit != null and mob_hit.alive:
					_send_skill(idx, {"skill": idx, "mobId": mob_hit.mob_id})
			else:
				_send_skill(idx, {"skill": idx, "x": world_pos.x, "y": world_pos.y})
			return
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
			if mob_hit.alive:
				attack_target = mob_hit
				_set_mob_highlight(mob_hit)
				_hide_marker()
				return
			attack_target = null
			_set_mob_highlight(null)
			var d_corpse: float = me.position.distance_to(mob_hit.position)
			if d_corpse <= 60.0:
				loot_win.open(mob_hit.mob_id, mob_hit.kind, mob_hit.loot)
			else:
				me.request_move_to(mob_hit.position)
			return
		attack_target = null
		_set_mob_highlight(null)
		_show_marker(world_pos)
		me.request_move_to(world_pos)

func _process(delta: float) -> void:
	if match_id == "" or Session.socket == null:
		return

	# Auto-pursuit: keep walking toward the locked target and shoot/punch when in range.
	if attack_target != null:
		if not is_instance_valid(attack_target) or not attack_target.alive:
			attack_target = null
		else:
			var has_bow: bool = String(last_me.get("eq", {}).get("weapon", "")).contains("bow")
			if has_bow:
				var d_bow: float = me.position.distance_to(attack_target.position)
				if d_bow <= PLAYER_ATTACK_RANGE:
					me.has_target = false
					me.face_toward(attack_target.position)
					if attack_cooldown <= 0.0:
						Session.socket.send_match_state_async(match_id, OP_ATTACK, JSON.stringify({"mobId": attack_target.mob_id}))
						attack_cooldown = PLAYER_ATTACK_COOLDOWN
						me.play_bow_shot()
				else:
					me.request_move_to(attack_target.position)
			else:
				# Melee: встаём кардинально относительно моба. Player.position = ноги,
				# mob.position = центр спрайта (ноги моба = mob.y + 20, голова = mob.y - 22).
				var mob_feet_y: float = attack_target.position.y + 20.0
				var mob_head_y: float = attack_target.position.y - 22.0
				var diff: Vector2 = attack_target.position - me.position
				var cardinal_spot: Vector2
				if absf(diff.x) >= absf(diff.y):
					# Сбоку: ноги игрока на уровне ног моба, сдвиг 28px по X
					cardinal_spot = Vector2(attack_target.position.x - signf(diff.x) * 28.0, mob_feet_y)
				elif diff.y > 0:
					# Моб НИЖЕ игрока (diff.y>0) → игрок стоит СВЕРХУ,
					# ноги игрока над головой моба (+2px зазор)
					cardinal_spot = Vector2(attack_target.position.x, mob_head_y - 2.0)
				else:
					# Моб ВЫШЕ игрока → игрок стоит СНИЗУ,
					# ноги игрока на 34px ниже ног моба (чтобы спрайт не налезал)
					cardinal_spot = Vector2(attack_target.position.x, mob_feet_y + 34.0)
				var at_spot: bool = me.position.distance_to(cardinal_spot) <= 3.0
				if at_spot:
					me.has_target = false
					me.position = cardinal_spot
					me.face_toward(attack_target.position)
					if attack_cooldown <= 0.0:
						Session.socket.send_match_state_async(match_id, OP_ATTACK, JSON.stringify({"mobId": attack_target.mob_id}))
						attack_cooldown = PLAYER_ATTACK_COOLDOWN
						me.play_punch()
				else:
					me.request_move_to(cardinal_spot)
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if nameplate:
		nameplate.update_target(attack_target)

	if _targeting_ring:
		if targeting_skill >= 0:
			_targeting_ring.visible = true
			_targeting_ring.position = get_viewport().get_camera_2d().get_global_mouse_position()
			_targeting_ring.modulate.a = 0.5 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
		else:
			_targeting_ring.visible = false

	if _click_marker and _click_marker.visible:
		_click_marker_t -= delta
		if _click_marker_t <= 0.0:
			_click_marker.visible = false
		else:
			_click_marker.modulate.a = clamp(_click_marker_t / 0.3, 0.0, 1.0)
			_click_marker.scale = Vector2(1.0, 1.0) * (0.8 + 0.2 * _click_marker_t)

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
		OP_SKILL_FX:
			_handle_skill_fx(body)
		OP_HIT_FLASH:
			var mid: String = String(body.get("mobId", ""))
			var m: Mob = mobs.get(mid)
			if m:
				m.flash()
				var dmg := int(body.get("dmg", 0))
				if dmg > 0:
					var is_crit := bool(body.get("crit", false))
					var is_poison := bool(body.get("poison", false))
					var is_ghost := bool(body.get("ghost", false))
					_spawn_damage_label(m.position, dmg, is_crit, is_poison, is_ghost)
		OP_PLAYER_HIT:
			var sid: String = String(body.get("sessionId", ""))
			var p: Player = me if sid == my_session_id else remotes.get(sid)
			if p: p.flash()
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
		ms.set_loot(m.get("loot", []))
		# Если открыто окно лута именно этого моба — обновим список.
		if loot_win and loot_win.is_open():
			loot_win.update_loot(mid, ms.loot)

func _apply_me(body: Dictionary) -> void:
	last_me = body
	hud.update_me(body)
	if nameplate:
		nameplate.update_me(body)
	if character_win:
		character_win.refresh(body)
	if bag_win:
		bag_win.refresh(body)
	if minimap:
		minimap.set_gold(int(body.get("gold", 0)))
	shop.refresh(body)
	me.set_hp(float(body.get("hp", 0)), float(body.get("hpMax", 100)))
	me.set_has_bow(String(body.get("eq", {}).get("weapon", "")).contains("bow"))

func _on_character_button() -> void:
	character_win.open(last_me)

func _on_bag_button() -> void:
	bag_win.open(last_me)

func _apply_npcs(body: Dictionary) -> void:
	if body.has("prices") and shop:
		shop.set_prices(body.get("prices", {}))
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
		# Трупы без лута не кликаются — клик проходит на землю.
		if not mob.alive and mob.loot.size() == 0:
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
	elif kind == "weapon":
		if not item_id.contains("bow"):
			return
		Session.socket.send_match_state_async(match_id, OP_EQUIP, JSON.stringify({"slot": idx}))
	elif kind == "armor":
		Session.socket.send_match_state_async(match_id, OP_EQUIP, JSON.stringify({"slot": idx}))

func _on_unequip(slot: String) -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_UNEQUIP, JSON.stringify({"slot": slot}))

func _on_equip_to_slot(inv_index: int, target_slot: String) -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_EQUIP, JSON.stringify({
		"slot": inv_index, "target": target_slot,
	}))

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

func _handle_skill_fx(body: Dictionary) -> void:
	var kind := String(body.get("kind", ""))
	if kind == "rain_start":
		var pos := Vector2(float(body.get("x", 0)), float(body.get("y", 0)))
		var r := float(body.get("r", 80))
		var dur_ms := int(body.get("duration", 3500))
		_spawn_rain_zone(pos, r, dur_ms)
	elif kind == "dodge":
		var sid := String(body.get("sid", ""))
		var px := float(body.get("fx", 0)); var py := float(body.get("fy", 0))
		var p: Player = me if sid == my_session_id else remotes.get(sid)
		if p:
			var dodge_target := Vector2(px, py)
			var tw := create_tween()
			tw.tween_property(p, "position", dodge_target, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			p.flash()
			# Trail effect
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
				world.add_child(ghost)
				var gt := create_tween()
				gt.tween_property(ghost, "modulate:a", 0.0, 0.4 + i * 0.1)
				gt.finished.connect(ghost.queue_free)

func _spawn_rain_zone(pos: Vector2, radius: float, duration_ms: int) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = 90
	world.add_child(node)
	var circle := _make_circle_sprite(radius, Color(1.0, 0.7, 0.3, 0.35))
	circle.modulate = Color(1.0, 0.7, 0.3, 0.45)
	node.add_child(circle)
	var spawn_t := 0.0
	var elapsed := 0.0
	node.set_meta("tick", Callable(func(delta: float):
		elapsed += delta
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = 0.05
			_spawn_falling_arrow(pos + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)))
		if elapsed * 1000.0 >= duration_ms:
			node.queue_free()))
	var timer := Timer.new()
	timer.wait_time = 0.03
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(func():
		if not is_instance_valid(node): return
		var cb: Callable = node.get_meta("tick")
		cb.call(0.03))
	node.add_child(timer)

func _spawn_falling_arrow(target: Vector2) -> void:
	var arrow := Line2D.new()
	arrow.add_point(Vector2.ZERO)
	arrow.add_point(Vector2(0, 18))
	arrow.default_color = Color(0.85, 0.55, 0.25)
	arrow.width = 2.5
	arrow.position = target + Vector2(0, -260)
	arrow.z_index = 110
	world.add_child(arrow)
	var tw := create_tween()
	tw.tween_property(arrow, "position", target + Vector2(0, -18), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _spawn_impact_puff(target))
	tw.tween_property(arrow, "modulate:a", 0.0, 0.2)
	tw.finished.connect(arrow.queue_free)

func _spawn_impact_puff(pos: Vector2) -> void:
	var puff := Sprite2D.new()
	var d := 14
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d * 0.5, d * 0.5)
	for y in range(d):
		for x in range(d):
			var dd: float = Vector2(x, y).distance_to(c)
			if dd < 6.5:
				img.set_pixel(x, y, Color(1.0, 0.85, 0.4, 0.8 - dd / 8.0))
	puff.texture = ImageTexture.create_from_image(img)
	puff.position = pos
	puff.z_index = 100
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(puff)
	var tw := create_tween()
	tw.parallel().tween_property(puff, "scale", Vector2(2.5, 2.5), 0.3)
	tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.3)
	tw.finished.connect(puff.queue_free)

func _make_circle_sprite(radius: float, color: Color) -> Sprite2D:
	var d := int(ceil(radius * 2))
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d * 0.5, d * 0.5)
	for y in range(d):
		for x in range(d):
			var dd: float = Vector2(x, y).distance_to(c)
			if dd < radius and dd > radius - 2.0:
				img.set_pixel(x, y, color)
			elif dd < radius:
				var a: float = (1.0 - dd / radius) * 0.2
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	var tex := ImageTexture.create_from_image(img)
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s

func _on_skill_activated(index: int) -> void:
	if match_id == "" or Session.socket == null:
		return
	var sk: Dictionary = skillbar.SKILLS[index]
	if skillbar.cooldowns[index] > 0.0:
		return
	if bool(sk["targets_ground"]) or bool(sk["targets_mob"]):
		targeting_skill = index
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		return
	# self / non-targeted — e.g. dodge
	var payload := {"skill": index}
	if attack_target and is_instance_valid(attack_target):
		payload["mobId"] = attack_target.mob_id
	_send_skill(index, payload)

func _send_skill(index: int, payload: Dictionary) -> void:
	Session.socket.send_match_state_async(match_id, OP_SKILL, JSON.stringify(payload))
	skillbar.trigger_cooldown(index)
	if index == 0 or index == 3:  # bow shot skills
		me.play_bow_shot()
	elif index == 4:
		me.play_bow_shot()

func _spawn_damage_label(pos: Vector2, dmg: int, is_crit: bool = false, is_poison: bool = false, is_ghost: bool = false) -> void:
	var lbl := Label.new()
	var size := 18
	var color := Color(1.0, 0.85, 0.2)
	var prefix := "-"
	if is_crit:
		size = 26
		color = Color(1.0, 0.35, 0.25)
		prefix = "КРИТ! -"
	elif is_poison:
		color = Color(0.55, 0.95, 0.35)
	elif is_ghost:
		color = Color(0.72, 0.82, 1.0)
	lbl.text = "%s%d" % [prefix, dmg]
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = pos + Vector2(randf_range(-8, 8), -32)
	lbl.z_index = 200
	world.add_child(lbl)
	var tween := create_tween()
	tween.parallel().tween_property(lbl, "position:y", lbl.position.y - 30, 0.9)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.2)
	tween.finished.connect(lbl.queue_free)

func _spawn_arrow(body: Dictionary) -> void:
	if bool(body.get("melee", false)):
		return
	var from := Vector2(float(body.get("fx", 0)), float(body.get("fy", 0)))
	var to := Vector2(float(body.get("tx", 0)), float(body.get("ty", 0)))
	var style := "normal"
	if bool(body.get("crit", false)): style = "crit"
	elif bool(body.get("poison", false)): style = "poison"
	elif bool(body.get("ghost", false)): style = "ghost"
	var arrow: Arrow = ARROW_SCRIPT.new()
	entities.add_child(arrow)
	arrow.shoot(from, to, style)

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

func _show_marker(pos: Vector2) -> void:
	if _click_marker:
		_click_marker.position = pos
		_click_marker.visible = true
		_click_marker.modulate.a = 1.0
		_click_marker.scale = Vector2.ONE
		_click_marker_t = 0.8

func _hide_marker() -> void:
	if _click_marker:
		_click_marker.visible = false

func _set_mob_highlight(mob: Mob) -> void:
	if _prev_highlight and is_instance_valid(_prev_highlight):
		_prev_highlight.set_highlight(false)
	_prev_highlight = mob
	if mob and is_instance_valid(mob):
		mob.set_highlight(true)

func _make_marker_texture() -> ImageTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5, s * 0.5)
	for y in range(s):
		for x in range(s):
			var d: float = Vector2(x, y).distance_to(c)
			if d >= 4.0 and d <= 6.5:
				img.set_pixel(x, y, Color(1.0, 1.0, 0.7, 0.9))
			elif d < 2.5:
				img.set_pixel(x, y, Color(1.0, 1.0, 0.8, 0.7))
	return ImageTexture.create_from_image(img)
