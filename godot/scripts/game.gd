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
const ADMIN_SCRIPT := preload("res://scripts/admin_panel.gd")
const STATS_SCRIPT := preload("res://scripts/stats_window.gd")
const SKILLS_WIN_SCRIPT := preload("res://scripts/skills_window.gd")
const PARTY_UI_SCRIPT := preload("res://scripts/party_ui.gd")
const BUTTERFLIES_SCRIPT := preload("res://scripts/butterflies.gd")

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
const PLAYER_ATTACK_RANGE := 192.0  # 6 тайлов × 32px (для лучника)
const TILE := 32.0

# Тип текущего оружия игрока ("" для безоружного). Берётся из last_me.eq.weapon.
func _my_weapon_kind() -> String:
	var w: String = String(last_me.get("eq", {}).get("weapon", ""))
	if w.contains("bow"): return "bow"
	if w.contains("tome"): return "tome"
	if w.contains("sword"): return "sword"
	return ""

# Максимальная дистанция базовой атаки, синхронизована с server.attackRangeFor.
func _my_atk_range() -> float:
	match _my_weapon_kind():
		"bow": return PLAYER_ATTACK_RANGE
		"tome": return PLAYER_ATTACK_RANGE - TILE
		_: return 36.0

func _my_has_ranged() -> bool:
	var k := _my_weapon_kind()
	return k == "bow" or k == "tome"
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
const OP_SKILL_REJECT := 22
const OP_TILE_UPDATE  := 23
const OP_MAP_SAVE     := 24
const OP_MAP_FULL     := 25
const OP_MOB_ADD      := 26
const OP_MOB_MOVE     := 27
const OP_MOB_DEL      := 28
const OP_TILE_RECT    := 29
const OP_MAP_HISTORY  := 30
const OP_MAP_SNAPSHOT := 31
const OP_MAP_ROLLBACK := 32
const OP_EDITOR_CURSOR := 33
const OP_OBJ_ADD      := 34
const OP_OBJ_DEL      := 35
const OP_OBJS         := 36
const OP_OBJ_INTERACT := 37
const OP_ZONE_SWITCH  := 38
const OP_PARTY_INVITE        := 39
const OP_PARTY_INVITE_NOTIFY := 40
const OP_PARTY_ACCEPT        := 41
const OP_PARTY_DECLINE       := 42
const OP_PARTY_UPDATE        := 43
const OP_PARTY_LEAVE         := 44
const OP_PLAYER_DEAD         := 45
const OP_RESPAWN             := 46
const OP_PLAYER_ACTION       := 47

const ARROW_SCRIPT := preload("res://scripts/arrow.gd")

@onready var world_root: Node2D = $World
@onready var entities: Node2D = $Entities
@onready var status_label: Label = %StatusLabel

var world: World
var me: Player
var camera: Camera2D
var editor_camera: Camera2D
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
var pvp_target: Player = null
var pvp_target_sid: String = ""
# Дружественная цель: клик по игроку своей фракции. Не атакуем, а
# подходим к позиции и отображаем его инфо в nameplate.
var friendly_target: Player = null
var friendly_target_sid: String = ""
# attack_ready_at_ms — абсолютное server-time (мс), когда следующий
# авто-удар станет разрешён. Заменяет старый client-side counter.
var attack_ready_at_ms: int = 0

func _attack_ready() -> bool:
	return Session.server_now_ms() >= attack_ready_at_ms

func _set_attack_cooldown(seconds: float) -> void:
	attack_ready_at_ms = Session.server_now_ms() + int(seconds * 1000.0)
var queued_skill: int = -1  # скилл ожидающий подхода к цели
var queued_ground_pos: Vector2 = Vector2.ZERO  # точка каста для ground-скилла
var queued_approach_pos: Vector2 = Vector2.ZERO  # куда идти чтобы попасть в зону каста
var _click_marker: Sprite2D
var _click_marker_t := 0.0
var _prev_highlight: Mob = null
var skillbar: SkillBar
var targeting_skill: int = -1  # -1 = нет таргетинга, иначе индекс скилла в SKILLS
var _targeting_ring: Sprite2D
var admin_panel: AdminPanel
var stats_win: StatsWindow
var skills_win: CanvasLayer
var party_ui: CanvasLayer
var party_members_cache: Array = []
var my_faction: String = "west"  # обновляется из OP_ME
var death_overlay: CanvasLayer
var _death_pos: Vector2 = Vector2.ZERO
var _am_dead: bool = false

func _ready() -> void:
	var display := Session.auth.username if Session.auth.username != "" else _short_id(Session.auth.user_id)

	world = WORLD_SCRIPT.new()
	world_root.add_child(world)

	# Декоративные летающие бабочки/пчёлки над лугами.
	var butterflies := BUTTERFLIES_SCRIPT.new()
	butterflies.setup(world)
	world.add_child(butterflies)

	# Статуя возрождения — визуальный якорь точки player_spawn, возле
	# которой появляются игроки после выбора «В городе» на экране смерти.
	_spawn_respawn_statue(world.player_spawn())

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

	_targeting_ring = _make_zone_square(160, Color(1.0, 0.6, 0.2, 0.7))
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
	character_win.set_nickname(display)
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

	stats_win = STATS_SCRIPT.new()
	add_child(stats_win)
	hud.stats_button_pressed.connect(stats_win.toggle)

	skills_win = SKILLS_WIN_SCRIPT.new()
	add_child(skills_win)
	hud.skills_button_pressed.connect(skills_win.toggle)

	party_ui = PARTY_UI_SCRIPT.new()
	add_child(party_ui)
	party_ui.invite_accepted.connect(_on_invite_accepted)
	party_ui.invite_declined.connect(_on_invite_declined)
	party_ui.party_leave_requested.connect(_on_party_leave_request)

	admin_panel = ADMIN_SCRIPT.new()
	add_child(admin_panel)
	# Показать значок гаечного ключа в HUD, если текущий юзер — админ.
	hud.set_admin_visible(admin_panel.is_admin())
	hud.admin_button_pressed.connect(admin_panel.toggle)
	admin_panel.action_requested.connect(_on_admin_action)
	admin_panel.map_save_requested.connect(_on_map_save)
	admin_panel.map_save_server_requested.connect(_save_map_on_server)
	admin_panel.map_edit_mode_changed.connect(_on_map_edit_mode_changed)
	admin_panel.map_snapshot_requested.connect(_on_map_snapshot_request)
	admin_panel.map_history_requested.connect(_on_map_history_request)
	admin_panel.map_rollback_requested.connect(_on_map_rollback_request)

	# Свободная камера для редактора — отдельная, живёт в world_root.
	editor_camera = Camera2D.new()
	editor_camera.limit_left = 0
	editor_camera.limit_top = 0
	editor_camera.limit_right = world.data.map_cols * WorldData.TILE_SIZE
	editor_camera.limit_bottom = world.data.map_rows * WorldData.TILE_SIZE
	world_root.add_child(editor_camera)

	loot_win = LOOT_SCRIPT.new()
	add_child(loot_win)
	loot_win.take_requested.connect(func(mob_id, idx):
		Session.socket.send_match_state_async(match_id, OP_LOOT_TAKE, JSON.stringify({"mobId": mob_id, "index": idx})))
	loot_win.take_all_requested.connect(func(mob_id):
		Session.socket.send_match_state_async(match_id, OP_LOOT_TAKE_ALL, JSON.stringify({"mobId": mob_id})))

	status_label.text = "Подключаюсь к real-time…"
	_connect_and_join()

func _unhandled_input(event: InputEvent) -> void:
	# Хоткеи для окон: C/С — сумка, I/Ш — персонаж.
	# Физическая клавиша одинаковая на английской и русской раскладке.
	if event is InputEventKey and event.pressed and not event.echo:
		var pk: int = event.physical_keycode
		if pk == KEY_C:
			bag_win.open(last_me) if not bag_win.is_open() else bag_win.close()
			return
		if pk == KEY_I:
			character_win.open(last_me) if not character_win.is_open() else character_win.close()
			return
		if pk == KEY_P:
			if stats_win: stats_win.toggle()
			return
		if pk == KEY_K:
			if skills_win: skills_win.toggle()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and targeting_skill >= 0:
		targeting_skill = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and targeting_skill >= 0:
		targeting_skill = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	# In-game map editor — клик шлёт OP_TILE_UPDATE на сервер (live-sync).
	if admin_panel and admin_panel.map_edit_mode and event is InputEventKey and event.pressed and not event.echo:
		# Esc — выйти из режима редактора.
		if event.keycode == KEY_ESCAPE:
			admin_panel.exit_edit_mode()
			return
		# Ctrl+Z / Ctrl+Shift+Z — undo / redo.
		if event.keycode == KEY_Z and event.ctrl_pressed:
			if event.shift_pressed: _map_redo()
			else: _map_undo()
			return
		# Хоткеи кистей тайлов: 1–6.
		var pk: int = event.physical_keycode
		if pk >= KEY_1 and pk <= KEY_6:
			admin_panel.select_brush_by_index(pk - KEY_1)
			return
		if pk == KEY_B:
			admin_panel.toggle_bucket()
			return
		if pk == KEY_G:
			world.set_grid_visible(not world.is_grid_visible())
			return
	if admin_panel and admin_panel.map_edit_mode and event is InputEventMouseButton:
		var world_pos_e := get_viewport().get_camera_2d().get_global_mouse_position()
		# Зум колёсиком.
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_editor_zoom(0.9, world_pos_e)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_editor_zoom(1.1, world_pos_e)
			return
		var c: int = int(world_pos_e.x / WorldData.TILE_SIZE)
		var r: int = int(world_pos_e.y / WorldData.TILE_SIZE)
		# Shift+ЛКМ drag → release — прямоугольная заливка.
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.shift_pressed:
				_rect_drag_start = Vector2i(c, r)
				_rect_drag_end = Vector2i(c, r)
				_rect_drag_active = true
				_ensure_rect_overlay()
				_rect_overlay.visible = true
				_rect_overlay.queue_redraw()
				return
			if not event.pressed and _rect_drag_active:
				_rect_drag_active = false
				if _rect_overlay: _rect_overlay.visible = false
				_send_tile_rect(_rect_drag_start.x, _rect_drag_start.y, _rect_drag_end.x, _rect_drag_end.y, admin_panel.map_edit_brush)
				return
		if not event.pressed:
			return
		# Alt+ЛКМ — пипетка (взять тайл в кисть).
		if event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed:
			if c >= 0 and r >= 0 and c < world.data.map_cols and r < world.data.map_rows:
				var tid: int = int(world.data.tiles[r * world.data.map_cols + c])
				admin_panel.select_brush_by_id(tid)
			return
		# Инструменты мобов перехватывают ЛКМ раньше рисования.
		if admin_panel.mob_tool != "" and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mob_tool_click(world_pos_e, admin_panel.mob_tool)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if admin_panel.bucket_mode:
				_map_bucket_fill(c, r, admin_panel.map_edit_brush)
			else:
				_map_paint(c, r, admin_panel.map_edit_brush)
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_map_paint(c, r, WorldData.Tile.GRASS)
			return
	if admin_panel and admin_panel.map_edit_mode and event is InputEventMouseMotion:
		var wp := get_viewport().get_camera_2d().get_global_mouse_position()
		if _rect_drag_active:
			_rect_drag_end = Vector2i(int(wp.x / WorldData.TILE_SIZE), int(wp.y / WorldData.TILE_SIZE))
			if _rect_overlay: _rect_overlay.queue_redraw()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := get_viewport().get_camera_2d().get_global_mouse_position()
		if targeting_skill >= 0:
			_resolve_targeting_click(targeting_skill, world_pos)
			return
		# Сундук (объект карты) — приоритет выше мобов/NPC.
		var obj_hit := _object_at(world_pos)
		if obj_hit != "":
			# Новое намерение — отменить всё предыдущее, чтобы персонаж
			# не «прыгал» обратно к прошлой цели/точке каста.
			_cancel_queued_action()
			attack_target = null; pvp_target = null
			friendly_target = null; friendly_target_sid = ""
			_set_mob_highlight(null)
			var node: Node2D = _map_objects.get(obj_hit)
			if node and node.position.distance_to(me.position) <= 60:
				Session.socket.send_match_state_async(match_id, OP_OBJ_INTERACT,
					JSON.stringify({"id": obj_hit}))
			else:
				_send_move_intent(node.position if node else world_pos)
			return
		# NPC takes priority over mobs/move.
		var npc := _npc_at(world_pos)
		if not npc.is_empty():
			_cancel_queued_action()
			attack_target = null
			pvp_target = null
			friendly_target = null; friendly_target_sid = ""
			var d_n: float = me.position.distance_to(Vector2(float(npc["x"]), float(npc["y"])))
			if d_n <= 80.0:
				shop.open(String(npc["id"]), npc.get("stock", []), last_me)
				return
			_send_move_intent(Vector2(float(npc["x"]), float(npc["y"])))
			return
		var mob_hit := _mob_at(world_pos)
		if mob_hit != null:
			if mob_hit.alive:
				# Если стоял в очереди ground-скилл (Град стрел) — клик по
				# мобу отменяет его. Target-скиллы переключаются на новую
				# цель (сохраняются намеренно).
				if queued_skill >= 0:
					var q_sk: Dictionary = skillbar.SKILLS[queued_skill]
					if bool(q_sk.get("targets_ground", false)):
						_cancel_queued_action()
				attack_target = mob_hit
				pvp_target = null
				friendly_target = null
				friendly_target_sid = ""
				_set_mob_highlight(mob_hit)
				_hide_marker()
				return
			_cancel_queued_action()
			attack_target = null
			pvp_target = null
			friendly_target = null
			friendly_target_sid = ""
			_set_mob_highlight(null)
			var d_corpse: float = me.position.distance_to(mob_hit.position)
			if d_corpse <= 60.0:
				loot_win.open(mob_hit.mob_id, mob_hit.kind, mob_hit.loot)
			else:
				_send_move_intent(mob_hit.position)
			return
		# Check for remote player click (PvP или дружественное действие).
		var sid_hit: String = _player_at(world_pos)
		if sid_hit != "":
			# Режим «Действия с игроками» → меню «ЛС / пригласить в группу».
			if hud and hud.actions_mode:
				var target_player: Player = remotes.get(sid_hit)
				var anchor: Vector2 = target_player.position if target_player != null else world_pos
				_show_action_menu(sid_hit, anchor)
				hud.reset_actions_mode()
				_hide_marker()
				return
			var clicked: Player = remotes.get(sid_hit)
			# Дружественный клик (своя фракция): не атакуем. Подходим к
			# позиции + показываем инфо/HP в nameplate. Для auto-chase-а
			# при движении цели — в _process обновляем move_intent.
			if clicked != null and clicked.is_friendly:
				_cancel_queued_action()
				friendly_target = clicked
				friendly_target_sid = sid_hit
				pvp_target = null
				pvp_target_sid = ""
				attack_target = null
				_set_mob_highlight(null)
				_hide_marker()
				_send_move_intent(clicked.position)
				return
			# Ground-скилл в очереди → отменяем. Target-скилл сохраняется
			# на нового игрока (кастанётся при входе в радиус).
			if queued_skill >= 0:
				var q_sk2: Dictionary = skillbar.SKILLS[queued_skill]
				if bool(q_sk2.get("targets_ground", false)):
					_cancel_queued_action()
			friendly_target = null
			friendly_target_sid = ""
			pvp_target = clicked
			pvp_target_sid = sid_hit
			attack_target = null
			_set_mob_highlight(null)
			_hide_marker()
			return
		# Чистый клик по земле — новое намерение двигаться. Отменяем всё:
		# queued skill, цели, highlight.
		_cancel_queued_action()
		attack_target = null
		pvp_target = null
		friendly_target = null
		friendly_target_sid = ""
		_set_mob_highlight(null)
		# Снап к центру клетки: персонаж всегда встаёт в центр тайла (A*-сетка),
		# поэтому маркер должен быть там же — иначе «кликнул сюда, а пришёл туда».
		var ts: int = WorldData.TILE_SIZE
		var snap_x: float = (floor(world_pos.x / ts) + 0.5) * ts
		var snap_y: float = (floor(world_pos.y / ts) + 0.5) * ts
		var snap_pos := Vector2(snap_x, snap_y)
		_show_marker(snap_pos)
		_send_move_intent(snap_pos)

func _process(delta: float) -> void:
	if match_id == "" or Session.socket == null:
		return

	# Свободная камера в режиме редактора: WASD-пан, скорость учитывает zoom.
	if admin_panel and admin_panel.map_edit_mode and editor_camera and editor_camera.is_current():
		var dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_W): dir.y -= 1.0
		if Input.is_key_pressed(KEY_S): dir.y += 1.0
		if Input.is_key_pressed(KEY_A): dir.x -= 1.0
		if Input.is_key_pressed(KEY_D): dir.x += 1.0
		if dir != Vector2.ZERO:
			var cam_speed: float = 600.0 * editor_camera.zoom.x
			editor_camera.position += dir.normalized() * cam_speed * delta
		_send_editor_cursor()

	# Friendly — просто держим цель для nameplate. Движение было отправлено
	# один раз при клике (snapshot позиции). За союзником не следуем: если
	# он ушёл, у меня цель в nameplate остаётся пока я сам не кликну в другое
	# место. Автоподгонка позиции нарушала бы ожидание «встать, где он был».
	if friendly_target != null and not is_instance_valid(friendly_target):
		friendly_target = null; friendly_target_sid = ""

	# PvP auto-pursuit — атаковать другого игрока (включая queued skill)
	if pvp_target != null:
		if not is_instance_valid(pvp_target):
			pvp_target = null; pvp_target_sid = ""
			queued_skill = -1
		else:
			var has_ranged_pvp: bool = _my_has_ranged()
			var has_bow_pvp: bool = (_my_weapon_kind() == "bow")
			var atk_range_pvp: float = _my_atk_range()
			var d_pvp: float = me.position.distance_to(pvp_target.position)

			# Queued skill в PvP — приоритет над авто-атакой
			if queued_skill >= 0:
				if d_pvp > atk_range_pvp:
					_send_move_intent(pvp_target.position)
					return
				_send_stop_move()
				me.has_target = false
				me.face_toward(pvp_target.position)
				if skillbar.cooldowns[queued_skill] <= 0.0:
					_send_skill(queued_skill, {"skill": _server_id_for_slot(queued_skill), "sid": pvp_target_sid})
					_set_attack_cooldown(PLAYER_ATTACK_COOLDOWN)
					queued_skill = -1
				return

			if d_pvp <= atk_range_pvp:
				_send_stop_move()
				me.has_target = false
				me.face_toward(pvp_target.position)
				if _attack_ready():
					Session.socket.send_match_state_async(match_id, OP_ATTACK, JSON.stringify({"sid": pvp_target_sid}))
					_set_attack_cooldown(PLAYER_ATTACK_COOLDOWN)
					if has_ranged_pvp:
						me.play_bow_shot()
					else:
						me.play_punch()
			else:
				_send_move_intent(pvp_target.position)

	# Queued ground skill (Ливень/Залп) — идём к цели через A*, кастуем когда в радиусе.
	if queued_skill >= 0 and attack_target == null and pvp_target == null:
		var sk: Dictionary = skillbar.SKILLS[queued_skill]
		if bool(sk["targets_ground"]):
			if skillbar.cooldowns[queued_skill] > 0.0:
				queued_skill = -1
			else:
				var d_now: float = me.position.distance_to(queued_ground_pos)
				var max_cast: float = _my_atk_range() - 20.0
				if d_now <= max_cast:
					_send_stop_move()
					me.has_target = false
					me.face_toward(queued_ground_pos)
					_send_skill(queued_skill, {"skill": _server_id_for_slot(queued_skill), "x": queued_ground_pos.x, "y": queued_ground_pos.y})
					_set_attack_cooldown(PLAYER_ATTACK_COOLDOWN)
					queued_skill = -1
					return
				# Идём НАПРЯМУЮ к цели через A* — обходя стены. Throttle в _send_move_intent
				# не шлёт повторно одну и ту же цель, так что безопасно вызывать каждый тик.
				_send_move_intent(queued_ground_pos)
				return

	# Auto-pursuit: keep walking toward the locked target and shoot/punch when in range.
	if attack_target != null:
		if not is_instance_valid(attack_target) or not attack_target.alive:
			attack_target = null
			queued_skill = -1
		else:
			var has_bow: bool = (_my_weapon_kind() == "bow")
			var has_ranged: bool = _my_has_ranged()
			var atk_range_now: float = _my_atk_range()
			# Queued skill — пока не выпустили, авто-атака НЕ работает (ждём).
			if queued_skill >= 0:
				# Дистанция каста = дальность атаки (сервер сам толерирует
				# +40px лага). Для melee — 30px. Раньше был -20 «на лаг»,
				# из-за чего лучник зря подходил ближе при Дезе, хотя
				# серверная дальность та же что у обычного выстрела.
				var q_range: float = atk_range_now if has_ranged else 30.0
				var q_d: float = me.position.distance_to(attack_target.position)
				if q_d > q_range:
					_send_move_intent(attack_target.position)
					return
				_send_stop_move()
				me.has_target = false
				me.face_toward(attack_target.position)
				if skillbar.cooldowns[queued_skill] <= 0.0:
					_send_skill(queued_skill, {"skill": _server_id_for_slot(queued_skill), "mobId": attack_target.mob_id})
					_set_attack_cooldown(PLAYER_ATTACK_COOLDOWN)
					queued_skill = -1
				return
			if has_ranged:
				var d_bow: float = me.position.distance_to(attack_target.position)
				if d_bow <= atk_range_now:
					_send_stop_move()
					me.has_target = false
					me.face_toward(attack_target.position)
					if _attack_ready():
						Session.socket.send_match_state_async(match_id, OP_ATTACK, JSON.stringify({"mobId": attack_target.mob_id}))
						_set_attack_cooldown(PLAYER_ATTACK_COOLDOWN)
						me.play_bow_shot()
				else:
					_send_move_intent(attack_target.position)
			else:
				# Melee без оружия: бьём если в радиусе PLAYER_MELEE_RANGE от моба.
				# Сервер принимает атаку при dist <= 36px (см. main.ts: atkRange = 36).
				const MELEE_RANGE := 30.0
				var d_melee: float = me.position.distance_to(attack_target.position)
				if d_melee <= MELEE_RANGE:
					_send_stop_move()
					me.has_target = false
					me.face_toward(attack_target.position)
					if _attack_ready():
						Session.socket.send_match_state_async(match_id, OP_ATTACK, JSON.stringify({"mobId": attack_target.mob_id}))
						_set_attack_cooldown(PLAYER_ATTACK_COOLDOWN)
						me.play_punch()
				else:
					_send_move_intent(attack_target.position)
	# attack cooldown теперь на server-time (_attack_ready / attack_ready_at_ms),
	# client-side декремента больше нет.

	if nameplate:
		if attack_target != null:
			nameplate.update_target(attack_target)
		elif pvp_target != null:
			nameplate.update_target(pvp_target)
		elif friendly_target != null:
			nameplate.update_target(friendly_target)
		else:
			nameplate.update_target(null)

	if _targeting_ring:
		var show_ring := false
		if targeting_skill >= 0:
			var sk_cfg: Dictionary = skillbar.SKILLS[targeting_skill]
			show_ring = bool(sk_cfg["targets_ground"])
		if show_ring:
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

	# Ливни стрел — привязка к server-time: зона исчезает по серверной
	# длительности, падающие стрелы спавнятся каждые 50мс server-time.
	_tick_rain_zones()

func _tick_rain_zones() -> void:
	if _rain_zones.is_empty():
		return
	var now_s: int = server_now_ms()
	for i in range(_rain_zones.size() - 1, -1, -1):
		var z: Dictionary = _rain_zones[i]
		if now_s >= int(z["end_at"]):
			var node: Node2D = z["node"]
			var square: Sprite2D = z["square"]
			if is_instance_valid(square) and is_instance_valid(node):
				var fade := create_tween()
				fade.tween_property(square, "modulate:a", 0.0, 0.3)
				fade.tween_callback(node.queue_free)
			_rain_zones.remove_at(i)
			continue
		if now_s >= int(z["next_arrow"]):
			z["next_arrow"] = now_s + 50
			var c: Vector2 = z["center"]
			var h: float = z["half"]
			_spawn_falling_arrow(c + Vector2(randf_range(-h, h), randf_range(-h, h)))

func _on_logout() -> void:
	# HUD «×» — выход из мира к выбору персонажа (аккаунт остаётся).
	# Закрываем сокет, чтобы сервер прокинул matchLeave и сохранил прогресс.
	_leave_to_character_select()

func _send_tile_update(c: int, r: int, id: int) -> void:
	if match_id == "" or Session.socket == null:
		return
	Session.socket.send_match_state_async(match_id, OP_TILE_UPDATE, JSON.stringify({"c": c, "r": r, "id": id}))

# ══════════════════ Map editor: undo + brush + bucket ══════════════════
const _UNDO_MAX := 100
var _map_undo_stack: Array = []  # [[{c,r,old_id,new_id}, ...], ...]
var _map_redo_stack: Array = []

func _record_edit(changes: Array) -> void:
	if changes.is_empty(): return
	_map_undo_stack.append(changes)
	if _map_undo_stack.size() > _UNDO_MAX:
		_map_undo_stack.pop_front()
	_map_redo_stack.clear()

func _map_paint(c: int, r: int, new_id: int) -> void:
	var radius: int = (admin_panel.brush_size - 1) / 2
	var changes: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nc := c + dx
			var nr := r + dy
			if nc < 0 or nr < 0 or nc >= world.data.map_cols or nr >= world.data.map_rows:
				continue
			var old_id: int = world.data.tiles[nr * world.data.map_cols + nc]
			if old_id == new_id:
				continue
			changes.append({"c": nc, "r": nr, "old_id": old_id, "new_id": new_id})
			_send_tile_update(nc, nr, new_id)
	_record_edit(changes)

func _map_bucket_fill(c: int, r: int, new_id: int) -> void:
	if c < 0 or r < 0 or c >= world.data.map_cols or r >= world.data.map_rows:
		return
	var target_id: int = world.data.tiles[r * world.data.map_cols + c]
	if target_id == new_id:
		return
	var visited: Dictionary = {}
	var queue: Array = [Vector2i(c, r)]
	var changes: Array = []
	var limit := 2000
	while queue.size() > 0 and changes.size() < limit:
		var p: Vector2i = queue.pop_front()
		var key := p.y * world.data.map_cols + p.x
		if visited.has(key): continue
		visited[key] = true
		if p.x < 0 or p.y < 0 or p.x >= world.data.map_cols or p.y >= world.data.map_rows:
			continue
		var cur: int = world.data.tiles[p.y * world.data.map_cols + p.x]
		if cur != target_id:
			continue
		changes.append({"c": p.x, "r": p.y, "old_id": cur, "new_id": new_id})
		_send_tile_update(p.x, p.y, new_id)
		queue.append(Vector2i(p.x + 1, p.y))
		queue.append(Vector2i(p.x - 1, p.y))
		queue.append(Vector2i(p.x, p.y + 1))
		queue.append(Vector2i(p.x, p.y - 1))
	_record_edit(changes)

func _map_undo() -> void:
	if _map_undo_stack.is_empty():
		admin_panel.log_result("Нечего отменять")
		return
	var group: Array = _map_undo_stack.pop_back()
	_map_redo_stack.append(group)
	for e in group:
		_send_tile_update(int(e["c"]), int(e["r"]), int(e["old_id"]))

func _map_redo() -> void:
	if _map_redo_stack.is_empty():
		admin_panel.log_result("Нечего возвращать")
		return
	var group: Array = _map_redo_stack.pop_back()
	_map_undo_stack.append(group)
	for e in group:
		_send_tile_update(int(e["c"]), int(e["r"]), int(e["new_id"]))

func _save_map_on_server() -> void:
	if match_id == "" or Session.socket == null:
		return
	Session.socket.send_match_state_async(match_id, OP_MAP_SAVE, JSON.stringify({}))
	if admin_panel:
		admin_panel.log_result("Карта сохранена на сервере (тайлы + мобы)")

func _on_map_snapshot_request() -> void:
	if match_id == "" or Session.socket == null: return
	Session.socket.send_match_state_async(match_id, OP_MAP_SNAPSHOT, JSON.stringify({}))

func _on_map_history_request() -> void:
	if match_id == "" or Session.socket == null: return
	Session.socket.send_match_state_async(match_id, OP_MAP_HISTORY, JSON.stringify({}))

func _on_map_rollback_request(ts: int) -> void:
	if match_id == "" or Session.socket == null: return
	Session.socket.send_match_state_async(match_id, OP_MAP_ROLLBACK, JSON.stringify({"ts": ts}))
	if admin_panel:
		admin_panel.log_result("Откат к ts=%d запрошен" % ts)

func _on_map_edit_mode_changed(on: bool) -> void:
	world.set_grid_visible(on)
	if skillbar:
		skillbar.hotkeys_enabled = not on
	if on:
		if editor_camera:
			# Стартуем редактор-камеру с позиции игровой, чтобы не телепортировало.
			editor_camera.position = camera.get_screen_center_position()
			editor_camera.zoom = Vector2.ONE
			editor_camera.make_current()
	else:
		if camera:
			camera.make_current()
		# Очистить курсоры других админов при выходе.
		for k in _editor_cursors.keys():
			var n: Node2D = _editor_cursors[k]
			if is_instance_valid(n): n.queue_free()
		_editor_cursors.clear()

# ══════════════════ Rect drag-fill (Shift+LMB) ══════════════════
var _rect_drag_active: bool = false
var _rect_drag_start: Vector2i = Vector2i.ZERO
var _rect_drag_end: Vector2i = Vector2i.ZERO
var _rect_overlay: Node2D = null

func _ensure_rect_overlay() -> void:
	if _rect_overlay and is_instance_valid(_rect_overlay):
		return
	_rect_overlay = _RectOverlay.new(self)
	_rect_overlay.z_index = 200
	world_root.add_child(_rect_overlay)

class _RectOverlay extends Node2D:
	var game_ref
	func _init(g) -> void:
		game_ref = g
	func _draw() -> void:
		if game_ref == null: return
		var s: Vector2i = game_ref._rect_drag_start
		var e: Vector2i = game_ref._rect_drag_end
		var c1: int = min(s.x, e.x); var c2: int = max(s.x, e.x)
		var r1: int = min(s.y, e.y); var r2: int = max(s.y, e.y)
		var ts: int = WorldData.TILE_SIZE
		var rect := Rect2(c1 * ts, r1 * ts, (c2 - c1 + 1) * ts, (r2 - r1 + 1) * ts)
		draw_rect(rect, Color(1.0, 0.85, 0.2, 0.25), true)
		draw_rect(rect, Color(1.0, 0.85, 0.2, 1.0), false, 2.0)

func _send_tile_rect(c1: int, r1: int, c2: int, r2: int, id: int) -> void:
	if match_id == "" or Session.socket == null: return
	Session.socket.send_match_state_async(match_id, OP_TILE_RECT,
		JSON.stringify({"c1": c1, "r1": r1, "c2": c2, "r2": r2, "id": id}))
	if admin_panel:
		var area: int = (max(c1,c2)-min(c1,c2)+1) * (max(r1,r2)-min(r1,r2)+1)
		admin_panel.log_result("Прямоугольник: %d тайлов" % area)

# ══════════════════ Мультикурсоры админов ══════════════════
var _editor_cursors: Dictionary = {}  # sid → Node2D
var _cursor_send_next_ms: int = 0

func _send_editor_cursor() -> void:
	if match_id == "" or Session.socket == null: return
	var now: int = Time.get_ticks_msec()
	if now < _cursor_send_next_ms: return
	_cursor_send_next_ms = now + 150  # ~6 Hz
	var wp := get_viewport().get_camera_2d().get_global_mouse_position()
	Session.socket.send_match_state_async(match_id, OP_EDITOR_CURSOR,
		JSON.stringify({"x": wp.x, "y": wp.y}))

func _update_editor_cursor(body: Dictionary) -> void:
	var sid: String = String(body.get("sid", ""))
	if sid == "": return
	var node: Node2D = _editor_cursors.get(sid)
	if node == null:
		node = _AdminCursor.new(String(body.get("name", "?")))
		node.z_index = 400
		world_root.add_child(node)
		_editor_cursors[sid] = node
	node.position = Vector2(float(body.get("x", 0)), float(body.get("y", 0)))

class _AdminCursor extends Node2D:
	var admin_name: String = ""
	func _init(nm: String) -> void:
		admin_name = nm
	func _draw() -> void:
		# Крестик + ник.
		var col := Color(0.6, 1.0, 0.6, 1.0)
		draw_line(Vector2(-8, 0), Vector2(8, 0), col, 2.0)
		draw_line(Vector2(0, -8), Vector2(0, 8), col, 2.0)
		draw_circle(Vector2.ZERO, 3.0, col)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(10, -4), admin_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

# ══════════════════ Объекты карты (порталы, сундуки) ══════════════════
var _map_objects: Dictionary = {}       # id → Node2D
var _portal_pair_source: Dictionary = {} # {x, y} при первом клике в режиме portal

func _apply_objects(body: Dictionary) -> void:
	for o in body.get("objects", []):
		var oid: String = String(o.get("id", ""))
		if oid == "":
			continue
		if bool(o.get("removed", false)):
			var nd: Node2D = _map_objects.get(oid)
			if nd: nd.queue_free()
			_map_objects.erase(oid)
			continue
		var node: Node2D = _map_objects.get(oid)
		if node == null:
			node = _MapObjectNode.new(oid, String(o.get("kind", "")), o.get("data", {}))
			node.z_index = 40
			entities.add_child(node)
			_map_objects[oid] = node
		node.position = Vector2(float(o.get("x", 0)), float(o.get("y", 0)))
		node.update_data(o.get("data", {}))

class _MapObjectNode extends Node2D:
	var obj_id: String = ""
	var kind: String = ""
	var data: Dictionary = {}
	var _t: float = 0.0
	func _init(id: String, k: String, d) -> void:
		obj_id = id; kind = k; data = d if d is Dictionary else {}
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func update_data(d) -> void:
		data = d if d is Dictionary else {}
		queue_redraw()
	func _draw() -> void:
		match kind:
			"portal":
				var base_r: float = 14.0
				var pulse: float = base_r + sin(_t * 3.0) * 3.0
				draw_circle(Vector2.ZERO, pulse + 2, Color(0.4, 0.8, 1.0, 0.25))
				draw_circle(Vector2.ZERO, pulse, Color(0.3, 0.6, 1.0, 0.55))
				draw_arc(Vector2.ZERO, pulse + 6, 0, TAU, 32, Color(0.7, 0.9, 1.0, 0.8), 2.0)
			"chest":
				var opened: bool = bool(data.get("opened", false))
				var col: Color = Color(0.5, 0.3, 0.1) if opened else Color(0.85, 0.6, 0.2)
				var rect := Rect2(Vector2(-10, -8), Vector2(20, 16))
				draw_rect(rect, col, true)
				draw_rect(rect, Color(0.3, 0.15, 0.05), false, 1.5)
				if not opened:
					draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 6)), Color(0.3, 0.15, 0.05), true)
			"spawn":
				var r2: int = int(data.get("radius", 60))
				draw_arc(Vector2.ZERO, r2, 0, TAU, 24, Color(1, 0.3, 0.3, 0.6), 1.5)

# ══════════════════ Подсветка пути игрока (точки A→B) ══════════════════
var _path_overlay: Node2D = null
var _path_points: PackedVector2Array = PackedVector2Array()
var _path_target: Vector2 = Vector2.ZERO
var _path_visible_until_ms: int = 0

func _ensure_path_overlay() -> void:
	if _path_overlay and is_instance_valid(_path_overlay):
		return
	_path_overlay = _PathDotsOverlay.new(self)
	_path_overlay.z_index = 45
	world_root.add_child(_path_overlay)

func _update_path_dots(waypoints: PackedVector2Array) -> void:
	_path_points = waypoints
	_path_target = waypoints[waypoints.size() - 1] if waypoints.size() > 0 else Vector2.ZERO
	_path_visible_until_ms = Time.get_ticks_msec() + 8000  # авто-скрытие через 8с
	_ensure_path_overlay()
	_path_overlay.queue_redraw()

class _PathDotsOverlay extends Node2D:
	var game_ref
	var _t: float = 0.0
	func _init(g) -> void:
		game_ref = g
	func _process(delta: float) -> void:
		_t += delta
		var should_show: bool = game_ref._path_points.size() > 0 and Time.get_ticks_msec() < game_ref._path_visible_until_ms
		if should_show and game_ref.me:
			# Убираем из начала пути точки, которые игрок уже прошёл — путь
			# всегда отображается от ТЕКУЩЕЙ позиции игрока (A) до цели (B).
			while game_ref._path_points.size() > 1 and game_ref.me.position.distance_to(game_ref._path_points[0]) < 18.0:
				game_ref._path_points.remove_at(0)
			# Автоскрытие когда игрок близко к финальной цели.
			if game_ref.me.position.distance_to(game_ref._path_target) < 12.0:
				game_ref._path_points = PackedVector2Array()
			queue_redraw()
		elif visible:
			queue_redraw()
	func _draw() -> void:
		var pts: PackedVector2Array = game_ref._path_points
		if pts.size() == 0 or Time.get_ticks_msec() >= game_ref._path_visible_until_ms:
			return
		# Путь уже обрезан при отправке (_send_move_intent) — просто рисуем.
		# Точка A — позиция игрока сейчас, точка B — последний waypoint.
		var start: Vector2 = game_ref.me.position if game_ref.me else pts[0]
		var dot_col := Color(1.0, 0.9, 0.3, 0.95)
		var line_col := Color(1.0, 0.9, 0.3, 0.5)
		# Статические точки на равных интервалах, без анимации фазы.
		var prev: Vector2 = start
		for i in range(pts.size()):
			var p: Vector2 = pts[i]
			draw_line(prev, p, line_col, 1.5)
			var seg: Vector2 = p - prev
			var seg_len: float = seg.length()
			if seg_len > 0.1:
				var dir: Vector2 = seg / seg_len
				var d: float = 8.0
				while d < seg_len:
					draw_circle(prev + dir * d, 2.5, dot_col)
					d += 14.0
			prev = p
		# Метка B — кольцо в конце.
		draw_arc(pts[pts.size() - 1], 8.0, 0, TAU, 20, Color(1, 0.95, 0.4, 1.0), 2.0)

func _editor_zoom(factor: float, focus_world: Vector2) -> void:
	if editor_camera == null: return
	var old_zoom: Vector2 = editor_camera.zoom
	var new_zoom: Vector2 = (old_zoom * factor).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
	if new_zoom == old_zoom: return
	# Сохраняем точку под курсором на месте: сдвигаем камеру так, чтобы focus_world остался там же на экране.
	var delta_zoom: Vector2 = new_zoom - old_zoom
	editor_camera.position += (focus_world - editor_camera.position) * (delta_zoom / new_zoom)
	editor_camera.zoom = new_zoom

# ══════════════════ Редактор мобов ══════════════════
# "Выбран" моб для перемещения (второй клик задаёт новую позицию).
var _mob_move_selected: String = ""

func _object_at(world_pos: Vector2) -> String:
	# Кликаем ТОЛЬКО по сундукам (порталы проходятся ногами).
	var best := ""
	var best_d: float = 28.0
	for id in _map_objects.keys():
		var n: Node2D = _map_objects.get(id)
		if n == null: continue
		if String(n.kind) != "chest": continue
		var d: float = n.position.distance_to(world_pos)
		if d < best_d:
			best_d = d; best = id
	return best

func _mob_at_any(world_pos: Vector2) -> Mob:
	var best: Mob = null
	var best_d: float = 9999.0
	for mob_v in mobs.values():
		var mob: Mob = mob_v
		var d: float = mob.position.distance_to(world_pos)
		if d < CLICK_MOB_RADIUS and d < best_d:
			best = mob
			best_d = d
	return best

func _handle_mob_tool_click(world_pos: Vector2, tool_id: String) -> void:
	if match_id == "" or Session.socket == null:
		return
	# Объекты карты.
	if tool_id == "portal_pair":
		# Первый клик — источник, второй — назначение, шлём OP_OBJ_ADD portal.
		# Если в admin_panel выбрана целевая зона — добавляем targetZone (межзонный портал).
		if _portal_pair_source.is_empty():
			_portal_pair_source = {"x": world_pos.x, "y": world_pos.y}
			if admin_panel: admin_panel.log_result("Источник портала — клик назначения")
		else:
			var src: Dictionary = _portal_pair_source
			var portal_data := {"tx": world_pos.x, "ty": world_pos.y}
			if admin_panel and admin_panel.portal_target_zone != "":
				portal_data["targetZone"] = admin_panel.portal_target_zone
			Session.socket.send_match_state_async(match_id, OP_OBJ_ADD,
				JSON.stringify({"kind": "portal", "x": src["x"], "y": src["y"], "data": portal_data}))
			_portal_pair_source = {}
			if admin_panel:
				var where: String = admin_panel.portal_target_zone if admin_panel.portal_target_zone != "" else "локально"
				admin_panel.log_result("Портал создан → " + where)
		return
	if tool_id == "chest":
		# Стандартный сундук с рандомным набором материалов.
		var loot := [{"itemId": "slime_jelly", "qty": 3}, {"itemId": "leather", "qty": 1}]
		Session.socket.send_match_state_async(match_id, OP_OBJ_ADD,
			JSON.stringify({"kind": "chest", "x": world_pos.x, "y": world_pos.y,
				"data": {"loot": loot, "respawnMs": 60000}}))
		if admin_panel: admin_panel.log_result("Сундук размещён")
		return
	if tool_id == "obj_delete":
		# Найти ближайший объект и удалить.
		var nearest_id := ""
		var best_d: float = 40.0
		for id in _map_objects.keys():
			var n: Node2D = _map_objects[id]
			if n == null: continue
			var d: float = n.position.distance_to(world_pos)
			if d < best_d:
				best_d = d; nearest_id = id
		if nearest_id != "":
			Session.socket.send_match_state_async(match_id, OP_OBJ_DEL, JSON.stringify({"id": nearest_id}))
			if admin_panel: admin_panel.log_result("Удалён объект: %s" % nearest_id)
		return
	# Пресет-высадка: preset_slime / preset_goblin / preset_dummy.
	if tool_id.begins_with("preset_"):
		var ptype := tool_id.substr(7)
		var n: int = admin_panel._preset_count if admin_panel else 10
		for i in range(n):
			var off := Vector2(randf_range(-80, 80), randf_range(-80, 80))
			Session.socket.send_match_state_async(match_id, OP_MOB_ADD,
				JSON.stringify({"type": ptype, "x": world_pos.x + off.x, "y": world_pos.y + off.y}))
		if admin_panel:
			admin_panel.log_result("Высажено %d × %s" % [n, ptype])
		return
	match tool_id:
		"add_slime", "add_goblin", "add_dummy":
			var mob_type := tool_id.substr(4)  # "slime" / "goblin" / "dummy"
			Session.socket.send_match_state_async(match_id, OP_MOB_ADD,
				JSON.stringify({"type": mob_type, "x": world_pos.x, "y": world_pos.y}))
			if admin_panel:
				admin_panel.log_result("Моб добавлен: %s" % mob_type)
		"move":
			if _mob_move_selected == "":
				var picked := _mob_at_any(world_pos)
				if picked == null:
					if admin_panel: admin_panel.log_result("Клик не попал в моба")
					return
				_mob_move_selected = picked.mob_id
				if admin_panel: admin_panel.log_result("Двигаем: %s — кликни цель" % _mob_move_selected)
			else:
				Session.socket.send_match_state_async(match_id, OP_MOB_MOVE,
					JSON.stringify({"mobId": _mob_move_selected, "x": world_pos.x, "y": world_pos.y}))
				if admin_panel: admin_panel.log_result("Моб перемещён: %s" % _mob_move_selected)
				_mob_move_selected = ""
		"delete":
			var target := _mob_at_any(world_pos)
			if target == null:
				if admin_panel: admin_panel.log_result("Клик не попал в моба")
				return
			Session.socket.send_match_state_async(match_id, OP_MOB_DEL,
				JSON.stringify({"mobId": target.mob_id}))
			if admin_panel: admin_panel.log_result("Моб удалён: %s" % target.mob_id)

func _on_map_save() -> void:
	# Собираем TMJ с текущими тайлами + исходными Mobs/NPCs из оригинального world.tmj.
	var src := FileAccess.open("res://assets/world.tmj", FileAccess.READ)
	if src == null:
		admin_panel.log_result("world.tmj не найден")
		return
	var src_json: Dictionary = JSON.parse_string(src.get_as_text())
	# Заменяем data слоя Tiles на текущее состояние.
	for layer in src_json.get("layers", []):
		if String(layer.get("name", "")) == "Tiles":
			var gids: Array = []
			for t in world.data.tiles:
				gids.append(int(t) + 1)
			layer["data"] = gids
			break
	var full_json: String = JSON.stringify(src_json, "\t")
	# Триггерим скачивание через JS Blob → <a download>.
	if OS.has_feature("web"):
		var escaped := full_json.replace("\\", "\\\\").replace("`", "\\`")
		JavaScriptBridge.eval("""
		(function(){
			var data = `%s`;
			var blob = new Blob([data], {type: 'application/json'});
			var url = URL.createObjectURL(blob);
			var a = document.createElement('a');
			a.href = url;
			a.download = 'world.tmj';
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
			URL.revokeObjectURL(url);
		})();
		""" % escaped, true)
		admin_panel.log_result("world.tmj скачан. Положи в data/maps/")
	else:
		# Desktop — сохраняем рядом с exe
		var out := FileAccess.open("user://world.tmj", FileAccess.WRITE)
		out.store_string(full_json)
		out.close()
		admin_panel.log_result("user://world.tmj сохранён")

func _connect_and_join() -> void:
	var socket := Nakama.create_socket_from(Session.client)
	var err: NakamaAsyncResult = await socket.connect_async(Session.auth)
	if err.is_exception():
		status_label.text = "Socket ошибка: %s" % err.get_exception().message
		return
	Session.socket = socket
	socket.received_match_state.connect(_on_match_state)
	socket.received_match_presence.connect(_on_presence)

	var payload := JSON.stringify({"zone": Session.current_zone})
	var rpc_res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "get_world_match", payload)
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
	status_label.text = "Зона: %s · игроков: %d" % [Session.current_zone, joined.presences.size() + 1]

func _handle_zone_switch(body: Dictionary) -> void:
	var new_zone: String = String(body.get("zone", ""))
	var new_match_id: String = String(body.get("matchId", ""))
	if new_zone == "" or new_match_id == "":
		return
	status_label.text = "Переход в зону: %s…" % new_zone
	# Чистый уход из текущего матча + всех локальных объектов; затем join в новый.
	if Session.socket and match_id != "":
		await Session.socket.leave_match_async(match_id)
	match_id = ""
	Session.current_zone = new_zone
	# Очистить визуальные сущности — их пришлют заново в OP_MOBS/OP_OBJS/OP_MAP_FULL.
	for mid in mobs.keys():
		var mn: Mob = mobs[mid]
		if is_instance_valid(mn): mn.queue_free()
	mobs.clear()
	for oid in _map_objects.keys():
		var on: Node2D = _map_objects[oid]
		if is_instance_valid(on): on.queue_free()
	_map_objects.clear()
	for k in remotes.keys():
		var rm: Node2D = remotes[k]
		if is_instance_valid(rm): rm.queue_free()
	remotes.clear()
	for nn in npcs:
		pass  # NPC нарисованы напрямую как Node2D — их обновим заново через OP_NPCS
	# Перейти на новый матч.
	var joined: NakamaRTAPI.Match = await Session.socket.join_match_async(new_match_id)
	if joined.is_exception():
		status_label.text = "Join zone ошибка: %s" % joined.get_exception().message
		return
	match_id = joined.match_id
	my_session_id = joined.self_user.session_id
	# Поставить игрока на позицию, присланную сервером (сервер тоже сам запомнил).
	me.position = Vector2(float(body.get("x", 0)), float(body.get("y", 0)))
	status_label.text = "Зона: %s" % new_zone

func _on_match_state(state: NakamaRTAPI.MatchData) -> void:
	var body = JSON.parse_string(state.data)
	if typeof(body) != TYPE_DICTIONARY:
		return
	match state.op_code:
		OP_POSITIONS:  _apply_positions(body)
		OP_MOBS:       _apply_mobs(body)
		OP_SKILL_FX:
			_handle_skill_fx(body)
		OP_PLAYER_DEAD:
			var dx := float(body.get("deathX", 0))
			var dy := float(body.get("deathY", 0))
			_show_death_screen(Vector2(dx, dy))
		OP_PLAYER_ACTION:
			_apply_player_action(body)
		OP_SKILL_REJECT:
			# Сервер отверг скилл — сбрасываем локальный кулдаун слота,
			# в котором стоит этот скилл. Server.skill = server_id.
			var rej_sid := int(body.get("skill", 0))
			var rej_def := SkillRegistry.by_server_id(rej_sid)
			if rej_def:
				var slot_i := SkillRegistry.all().find(rej_def)
				if slot_i >= 0 and slot_i < skillbar.cooldowns.size():
					skillbar.cooldowns[slot_i] = 0.0
					var reason := String(body.get("reason", ""))
					if reason == "no_mana":
						skillbar.flash_slot(slot_i, Color(0.4, 0.6, 1.0))
					elif reason == "no_bow":
						skillbar.flash_slot(slot_i, Color(0.95, 0.55, 0.30))
		OP_HIT_FLASH:
			var mid: String = String(body.get("mobId", ""))
			var m: Mob = mobs.get(mid)
			if m:
				m.flash()
				var dmg := int(body.get("dmg", 0))
				if dmg > 0:
					m.set_hp(max(0.0, m.hp - dmg), m.hp_max)
					var is_crit := bool(body.get("crit", false))
					var is_poison := bool(body.get("poison", false))
					var is_ghost := bool(body.get("ghost", false))
					_spawn_damage_label(m.position, dmg, is_crit, is_poison, is_ghost)
		OP_PLAYER_HIT:
			var sid: String = String(body.get("sessionId", ""))
			var p: Player = me if sid == my_session_id else remotes.get(sid)
			if p:
				p.flash()
				var dmg := int(body.get("dmg", 0))
				if dmg > 0:
					# Мгновенно уменьшаем HP локально — для быстрого UX
					p.set_hp(max(0.0, p.hp - dmg), p.hp_max)
					_spawn_damage_label(p.position, dmg, bool(body.get("crit", false)), bool(body.get("poison", false)), bool(body.get("ghost", false)))
		OP_ME:         _apply_me(body)
		OP_NPCS:       _apply_npcs(body)
		OP_ARROW:      _spawn_arrow(body)
		OP_CHAT_RELAY: _apply_chat(body)
		OP_TILE_UPDATE:
			var c := int(body.get("c", 0))
			var r := int(body.get("r", 0))
			var id := int(body.get("id", 0))
			world.set_tile(c, r, id)
		OP_MAP_FULL:
			var arr: Array = body.get("tiles", [])
			if arr.size() == world.data.map_cols * world.data.map_rows:
				world.apply_full_tiles(arr)
		OP_TILE_RECT:
			var c1 := int(body.get("c1", 0)); var r1 := int(body.get("r1", 0))
			var c2 := int(body.get("c2", 0)); var r2 := int(body.get("r2", 0))
			var rid := int(body.get("id", 0))
			for r in range(r1, r2 + 1):
				for c in range(c1, c2 + 1):
					world.set_tile(c, r, rid)
		OP_MAP_HISTORY:
			if admin_panel: admin_panel.show_history_list(body.get("list", []))
		OP_MAP_SNAPSHOT:
			if admin_panel: admin_panel.log_result("Снимок сохранён (ts=%s)" % str(body.get("ts", 0)))
		OP_EDITOR_CURSOR:
			_update_editor_cursor(body)
		OP_OBJS:
			_apply_objects(body)
		OP_ZONE_SWITCH:
			_handle_zone_switch(body)
		OP_PARTY_INVITE_NOTIFY:
			_on_party_invite_notify(body)
		OP_PARTY_UPDATE:
			_on_party_update(body)

var _last_intent_ms: int = 0

func server_now_ms() -> int:
	return Session.server_now_ms()

func _send_stop_move() -> void:
	# Обнулить moveTarget/movePath на сервере: сервер получит {x,y} в текущей
	# позиции игрока → distTarget <= step → moveTarget = null → игрок стоит.
	if match_id == "" or Session.socket == null:
		return
	Session.socket.send_match_state_async(match_id, OP_MOVE_INTENT,
		JSON.stringify({"x": me.position.x, "y": me.position.y}))
	# Сбрасываем throttle-цель, чтобы следующий настоящий клик сразу улетел.
	last_sent_pos = me.position
	_last_intent_ms = Time.get_ticks_msec()
	# Скрываем визуализацию пути.
	_path_points = PackedVector2Array()

func _send_move_intent(target: Vector2) -> void:
	# Server-authoritative: клиент считает A*-путь и шлёт полный массив
	# waypoints. Сервер сам шагает от одного к другому со скоростью PLAYER_SPEED.
	# Throttle: та же цель (±24px) в пределах 1 сек — НЕ пересылаем. При
	# движущейся цели (моб убегает, меняется на >24px) путь обновляется
	# раз в секунду. Этого достаточно, лишний спам не нужен.
	if match_id == "" or Session.socket == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if last_sent_pos.distance_to(target) < 24.0 and now_ms - _last_intent_ms < 1000:
		return
	var path: PackedVector2Array = world.find_path(me.position, target)
	# Первая точка пути — центр текущей клетки игрока; почти совпадает с
	# позицией игрока. Отбрасываем если ближе 0.6 тайла — иначе «рывок назад».
	if path.size() > 1 and me.position.distance_to(path[0]) < WorldData.TILE_SIZE * 0.6:
		path.remove_at(0)
	# Если активен ground-скилл — обрезаем хвост пути в первой точке,
	# с которой хватает дальности до цели. Сервер дойдёт туда и остановится,
	# в _process сработает каст. Линия на клиенте тоже будет заканчиваться
	# ровно там — без «расширения» когда промежуточный waypoint проходится.
	if queued_skill >= 0 and queued_ground_pos != Vector2.ZERO:
		var sk_cfg: Dictionary = skillbar.SKILLS[queued_skill]
		if bool(sk_cfg.get("targets_ground", false)) and path.size() > 0:
			var max_cast: float = _my_atk_range() - 20.0
			for i in range(path.size()):
				if Vector2(path[i]).distance_to(queued_ground_pos) <= max_cast:
					path.resize(i + 1)
					break
	if path.size() == 0:
		# Путь не найден или цель в той же клетке — шлём одну точку.
		Session.socket.send_match_state_async(match_id, OP_MOVE_INTENT,
			JSON.stringify({"x": target.x, "y": target.y}))
	else:
		var arr: Array = []
		for p in path:
			arr.append({"x": p.x, "y": p.y})
		Session.socket.send_match_state_async(match_id, OP_MOVE_INTENT,
			JSON.stringify({"path": arr}))
		_update_path_dots(path)
	last_sent_pos = target
	_last_intent_ms = now_ms

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
			var max_hp: float = float(last_me.get("hpMax", 100))
			me.set_hp(hp, max_hp)
			# Server-auth: всегда интерполируем локального игрока к server pos.
			me.remote_update(Vector2(x, y))
			continue
		var display: String = String(p.get("n", sid.substr(0, 6)))
		var uid: String = String(p.get("uid", sid))
		var has_bow_remote: bool = bool(p.get("hb", false))
		var remote: Player = remotes.get(sid)
		if remote == null:
			remote = PLAYER_SCRIPT.new()
			remote.setup(world, "%s (Ур.%d)" % [display, lv], PLAYER_SCRIPT.variant_from(uid))
			remote.local = false
			remote.position = Vector2(x, y)
			entities.add_child(remote)
			remotes[sid] = remote
		var new_pos := Vector2(x, y)
		remote.remote_update(new_pos)
		# wpn приходит от сервера ("bow"/"tome"/"sword"/""), если его нет — fallback на hb.
		var remote_wpn := String(p.get("wpn", ""))
		if remote_wpn == "" and has_bow_remote:
			remote_wpn = "bow"
		remote.set_weapon_kind(remote_wpn)
		remote.set_weapon_item(remote_wpn)
		var hp_max_remote: float = float(p.get("hpMax", 100))
		remote.set_hp(hp, hp_max_remote)
		# Поля для target-панели: уровень, класс, мана, эффекты.
		remote.level = lv
		remote.char_class = String(p.get("cls", remote.char_class))
		remote.mana = int(p.get("mp", 0))
		remote.mana_max = int(p.get("mpMax", 0))
		remote.effects = p.get("effects", [])
		# Фракция: союзник — зелёный, враг — красный.
		var remote_fac := String(p.get("faction", ""))
		if remote_fac != "":
			remote.set_friendly(remote_fac == my_faction)
		# Спринт (бафф Эскейп-sprint): remote-игрок должен интерполироваться
		# быстрее, иначе на клиенте он «отстаёт» от server-позиции.
		var server_now_pos: int = int(body.get("t", 0))
		var sprint_remain_ms := 0
		for eff in p.get("effects", []):
			if String(eff.get("type", "")) == "sprint":
				var end_at := int(eff.get("endAt", 0))
				if server_now_pos > 0 and end_at > server_now_pos:
					sprint_remain_ms = end_at - server_now_pos
				break
		remote.set_sprint_remaining(sprint_remain_ms)

func _apply_mobs(body: Dictionary) -> void:
	for m in body.get("mobs", []):
		var mid: String = String(m.get("id", ""))
		if mid == "":
			continue
		# Удаление моба админом — сервер шлёт {id, removed:true}.
		if bool(m.get("removed", false)):
			var dead_node: Mob = mobs.get(mid)
			if dead_node:
				dead_node.queue_free()
				mobs.erase(mid)
			continue
		var kind: String = String(m.get("t", "slime"))
		var ms: Mob = mobs.get(mid)
		if ms == null:
			ms = MOB_SCRIPT.new()
			ms.setup(mid, kind)
			entities.add_child(ms)
			mobs[mid] = ms
		ms.set_server_pos(Vector2(float(m.get("x", 0)), float(m.get("y", 0))))
		ms.set_hp(float(m.get("hp", 0)), float(m.get("hpMax", 30)))
		ms.set_alive(String(m.get("st", "alive")) == "alive")
		ms.set_loot(m.get("loot", []))
		ms.set_debuff(m.get("debuff"), int(m.get("now", 0)))
		ms.set_buffs(m.get("buffs", []))
		# Если открыто окно лута именно этого моба — обновим список.
		if loot_win and loot_win.is_open():
			loot_win.update_loot(mid, ms.loot)

func _apply_me(body: Dictionary) -> void:
	last_me = body
	if body.has("t"):
		Session.server_offset_ms = int(body["t"]) - Time.get_ticks_msec()
	# Если hp > 0 и мы были мертвы — сервер уже респавнил нас, убираем модалку.
	if _am_dead and int(body.get("hp", 0)) > 0:
		_hide_death_screen()
	# Класс от сервера — источник истины (может отличаться от локального выбора).
	var server_class: String = str(body.get("charClass", ""))
	if server_class != "" and server_class != Session.selected_character:
		Session.selected_character = server_class
		if skills_win and skills_win.has_method("set_class"):
			skills_win.set_class(server_class)
	# Иконка класса в nameplate.
	if server_class != "" and nameplate and nameplate.has_method("set_class"):
		nameplate.set_class(server_class)
	# Имя активного персонажа — замена email-заглушке.
	var server_name: String = str(body.get("name", ""))
	if server_name != "":
		if nameplate:
			nameplate.set_player_name(server_name)
		if me:
			me.display_name = server_name
			if me.label:
				me.label.text = server_name
		if character_win and character_win.has_method("set_nickname"):
			character_win.set_nickname(server_name)
	hud.update_me(body)
	if nameplate:
		nameplate.update_me(body)
	if character_win:
		character_win.refresh(body)
	if bag_win:
		bag_win.refresh(body)
	if stats_win:
		stats_win.refresh(body)
	if minimap:
		minimap.set_gold(int(body.get("gold", 0)))
	shop.refresh(body)
	me.set_hp(float(body.get("hp", 0)), float(body.get("hpMax", 100)))
	if skillbar:
		skillbar.update_skill_cd(body.get("skillCd", {}), int(body.get("t", 0)))
		skillbar.update_mana(int(body.get("mana", 0)), int(body.get("manaMax", 0)))
	var eq_dict: Dictionary = body.get("eq", {})
	var _wname := String(eq_dict.get("weapon", ""))
	var _kind := ""
	if _wname.contains("bow"): _kind = "bow"
	elif _wname.contains("tome"): _kind = "tome"
	elif _wname.contains("sword"): _kind = "sword"
	me.set_weapon_kind(_kind)
	me.set_weapon_item(_wname)
	# Фракция игрока (шлётся сервером в каждом OP_ME) — нужна чтобы
	# раскрашивать remote-ников: союзник зелёный, враг красный.
	var server_faction: String = str(body.get("faction", ""))
	if server_faction != "":
		my_faction = server_faction
	# Баф sprint: если активен — сообщаем Player чтобы повысил скорость
	# интерполяции клиентской позиции до SPEED_SPRINT.
	var sprint_remaining := 0
	var server_now_ms: int = int(body.get("t", 0))
	for eff in body.get("effects", []):
		if String(eff.get("type", "")) == "sprint":
			var end_at := int(eff.get("endAt", 0))
			if server_now_ms > 0 and end_at > server_now_ms:
				sprint_remaining = end_at - server_now_ms
			break
	me.set_sprint_remaining(sprint_remaining)
	# Paper-doll слои: каждый слот → wear-atlas (если существует в assets).
	const WEAR_SLOT_MAP := {
		"boots":  "boots",
		"body":   "body",
		"cloak":  "cloak",
		"head":   "head",
		"belt":   "pants",    # пояс = штаны/пояс-overlay
		"weapon": "weapon",
	}
	for eq_slot in WEAR_SLOT_MAP.keys():
		var layer_slot: String = WEAR_SLOT_MAP[eq_slot]
		me.set_wear(layer_slot, String(eq_dict.get(eq_slot, "")))

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
		sprite.texture = load("res://assets/sprites/mobs/npc.png")
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
		# Если меня кикнуло (заход с другого устройства) — показать сообщение
		if sid == my_session_id:
			_handle_kicked()
			return
		var r: Player = remotes.get(sid)
		if r:
			r.queue_free()
			remotes.erase(sid)
	if status_label:
		status_label.text = "В мире · игроков: %d" % (remotes.size() + 1)

var _kicked_shown: bool = false

func _handle_kicked() -> void:
	# Идемпотентно: если OP_LEAVE и WebSocket close прилетят оба —
	# модалку не создаём дважды.
	if _kicked_shown:
		return
	_kicked_shown = true
	if status_label:
		status_label.text = "Произведен вход с другого устройства"
	# Прячем игровой UI.
	if hud: hud.visible = false
	if skillbar: skillbar.visible = false
	if minimap: minimap.visible = false

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var card := PanelContainer.new()
	card.anchor_left = 0.5; card.anchor_top = 0.5
	card.anchor_right = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -220; card.offset_top = -100
	card.offset_right = 220; card.offset_bottom = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.98)
	sb.border_color = Color(0.85, 0.30, 0.30, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	layer.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var title := Label.new()
	title.text = "Произведен вход с другого устройства"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)

	var ok := Button.new()
	ok.text = "ОК"
	ok.focus_mode = Control.FOCUS_ALL
	ok.custom_minimum_size = Vector2(140, 38)
	ok.pressed.connect(_leave_to_character_select)
	col.add_child(ok)
	ok.grab_focus()

# Вышвырнуть игрока из игры в меню выбора персонажа (общий путь для
# «кик с другого устройства» и ручного выхода по «×»).
# Меню «Действия с игроком» — всплывает над выбранным remote-игроком
# по клику в режиме hud.actions_mode. Две кнопки: ЛС / в группу.
var _action_menu: CanvasLayer = null

func _show_action_menu(target_sid: String, anchor_world: Vector2) -> void:
	_close_action_menu()
	_action_menu = CanvasLayer.new()
	_action_menu.layer = 30
	add_child(_action_menu)

	var target_player: Player = remotes.get(target_sid)
	var target_name := target_player.display_name if target_player != null else "игрок"

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	sb.border_color = Color(0.85, 0.65, 0.30, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	# Положение: прикрепляем к экранной позиции цели через камеру.
	var cam := get_viewport().get_camera_2d()
	var screen_pos := anchor_world
	if cam:
		screen_pos = (anchor_world - cam.global_position) + get_viewport_rect().size * 0.5
	panel.position = Vector2(screen_pos.x - 90, screen_pos.y - 100)
	panel.custom_minimum_size = Vector2(180, 0)
	_action_menu.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var title := Label.new()
	title.text = target_name
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.65))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var dm_btn := Button.new()
	dm_btn.text = "Написать в ЛС"
	dm_btn.focus_mode = Control.FOCUS_NONE
	dm_btn.custom_minimum_size = Vector2(0, 32)
	dm_btn.pressed.connect(func():
		_close_action_menu()
		_show_dm_prompt(target_sid, target_name)
	)
	col.add_child(dm_btn)

	var inv_btn := Button.new()
	inv_btn.text = "Пригласить в группу"
	inv_btn.focus_mode = Control.FOCUS_NONE
	inv_btn.custom_minimum_size = Vector2(0, 32)
	inv_btn.pressed.connect(func():
		_close_action_menu()
		_send_party_invite(target_sid)
	)
	col.add_child(inv_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	cancel_btn.custom_minimum_size = Vector2(0, 28)
	cancel_btn.pressed.connect(_close_action_menu)
	col.add_child(cancel_btn)

func _close_action_menu() -> void:
	if _action_menu != null and is_instance_valid(_action_menu):
		_action_menu.queue_free()
	_action_menu = null

# Окно ввода личного сообщения. Отправляет OP_CHAT_SEND с ch="dm", to=sid.
# Сервер фильтрует получателей: только отправитель и адресат.
func _show_dm_prompt(target_sid: String, target_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var card := PanelContainer.new()
	card.anchor_left = 0.5; card.anchor_top = 0.5
	card.anchor_right = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -220; card.offset_top = -80
	card.offset_right = 220; card.offset_bottom = 80
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	sb.border_color = Color(0.55, 0.80, 1.0, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	layer.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var title := Label.new()
	title.text = "ЛС → " + target_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0))
	col.add_child(title)

	var input := LineEdit.new()
	input.placeholder_text = "Сообщение (до 140 символов)"
	input.max_length = 140
	col.add_child(input)
	input.grab_focus()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	var send := Button.new()
	send.text = "Отправить"
	send.custom_minimum_size = Vector2(120, 30)
	var send_fn := func():
		var txt := input.text.strip_edges()
		if txt != "" and match_id != "":
			Session.socket.send_match_state_async(match_id, OP_CHAT_SEND,
				JSON.stringify({"text": txt, "ch": "dm", "to": target_sid}))
		layer.queue_free()
	send.pressed.connect(send_fn)
	input.text_submitted.connect(func(_t): send_fn.call())
	row.add_child(send)

	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(100, 30)
	cancel.pressed.connect(func(): layer.queue_free())
	row.add_child(cancel)

func _leave_to_character_select() -> void:
	if Session.socket and Session.socket.is_connected_to_host():
		Session.socket.close()
	Session.socket = null
	Session.selected_character = ""
	auth_changed.emit()

func _player_at(world_pos: Vector2) -> String:
	var best_sid := ""
	var best_d: float = 56.0
	for sid in remotes.keys():
		var p: Player = remotes[sid]
		if p == null or not is_instance_valid(p):
			continue
		var d: float = world_pos.distance_to(p.position + Vector2(0, -20))
		if d < best_d:
			best_d = d
			best_sid = sid
	return best_sid

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
	var ch: String = String(body.get("ch", "global"))
	if text.is_empty():
		return
	chat_panel.append_line(who, text, ch)
	var speaker: Player = me if sid == my_session_id else remotes.get(sid)
	if speaker:
		speaker.show_bubble(text)

func _on_chat_send(text: String, channel: String = "global") -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_CHAT_SEND, JSON.stringify({"text": text, "ch": channel}))

# ─── Экран смерти ────────────────────────────────────────────────
# Сервер шлёт OP_PLAYER_DEAD → показываем модалку с двумя кнопками.
# Нажатие → OP_RESPAWN {place:"here"|"spawn"}. Сервер восстанавливает
# HP/ману и телепортирует, шлёт OP_ME с hp>0 → модалку убираем.

func _show_death_screen(death_pos: Vector2) -> void:
	_am_dead = true
	_death_pos = death_pos
	if death_overlay != null and is_instance_valid(death_overlay):
		return
	death_overlay = CanvasLayer.new()
	death_overlay.layer = 50
	add_child(death_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	death_overlay.add_child(bg)

	var card := PanelContainer.new()
	card.anchor_left = 0.5; card.anchor_top = 0.5
	card.anchor_right = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -220; card.offset_top = -110
	card.offset_right = 220; card.offset_bottom = 110
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.07, 0.98)
	sb.border_color = Color(0.85, 0.30, 0.30, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	death_overlay.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	var title := Label.new()
	title.text = "Вы погибли"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var hint := Label.new()
	hint.text = "Выберите место возрождения:"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	var here_btn := Button.new()
	here_btn.text = "Возродиться здесь"
	here_btn.custom_minimum_size = Vector2(170, 36)
	here_btn.pressed.connect(func(): _send_respawn("here"))
	row.add_child(here_btn)

	var town_btn := Button.new()
	town_btn.text = "В городе"
	town_btn.custom_minimum_size = Vector2(170, 36)
	town_btn.pressed.connect(func(): _send_respawn("spawn"))
	row.add_child(town_btn)

func _hide_death_screen() -> void:
	_am_dead = false
	if death_overlay != null and is_instance_valid(death_overlay):
		death_overlay.queue_free()
	death_overlay = null

func _send_respawn(place: String) -> void:
	if match_id == "":
		return
	Session.socket.send_match_state_async(match_id, OP_RESPAWN, JSON.stringify({"place": place}))

func _handle_skill_fx(body: Dictionary) -> void:
	# Общие эффекты (не привязаны к конкретному скиллу): обрабатываем сразу.
	var kind := String(body.get("kind", ""))
	if kind == "stun":
		var mid := String(body.get("mobId", ""))
		var m: Mob = mobs.get(mid)
		if m:
			m.apply_stun(int(body.get("duration", 1000)))
		return
	if kind == "fire":
		var mid2 := String(body.get("mobId", ""))
		var m2: Mob = mobs.get(mid2)
		if m2:
			m2.apply_fire(int(body.get("duration", 3500)))
		return
	if kind == "root":
		var mid3 := String(body.get("mobId", ""))
		var m3: Mob = mobs.get(mid3)
		if m3:
			# Root — визуально тот же знак, что stun. Игромеханика: моб не движется.
			m3.apply_stun(int(body.get("duration", 500)))
		return
	if kind == "dispel":
		var mid4 := String(body.get("mobId", ""))
		var m4: Mob = mobs.get(mid4)
		if m4:
			m4.flash_dispel()
		return
	# Скиллы сами слушают свои kind.
	for def in SkillRegistry.all():
		if def.on_fx(self, body):
			return

var _rain_zones: Array = []  # [{node, square, center, half, end_server_ms, next_arrow_ms}]

# Алтарь возрождения: пока без ассета, рисуем процедурно — подставка,
# крест, пульсирующая аура. Точка совпадает с world.player_spawn(), куда
# сервер телепортирует игроков по кнопке «В городе» на экране смерти.
func _spawn_respawn_statue(pos: Vector2) -> void:
	var root := Node2D.new()
	root.position = pos
	root.z_index = 0
	world.add_child(root)

	# Аура (полупрозрачный круг, мигающий).
	var aura := ColorRect.new()
	aura.color = Color(0.6, 0.85, 1.0, 0.16)
	aura.size = Vector2(64, 64)
	aura.position = Vector2(-32, -52)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aura_sb := StyleBoxFlat.new()
	aura_sb.bg_color = aura.color
	aura_sb.set_corner_radius_all(32)
	root.add_child(aura)
	var tw_aura := create_tween()
	tw_aura.set_loops()
	tw_aura.tween_property(aura, "modulate:a", 0.4, 1.5).set_trans(Tween.TRANS_SINE)
	tw_aura.tween_property(aura, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)

	# Подставка (тёмно-серый прямоугольник с каменной окантовкой).
	var base := ColorRect.new()
	base.color = Color(0.40, 0.36, 0.32)
	base.size = Vector2(22, 8)
	base.position = Vector2(-11, -6)
	root.add_child(base)

	# Столб статуи (светло-серый).
	var pillar := ColorRect.new()
	pillar.color = Color(0.68, 0.66, 0.62)
	pillar.size = Vector2(10, 20)
	pillar.position = Vector2(-5, -24)
	root.add_child(pillar)

	# Крест сверху (символ возрождения).
	var cross_v := ColorRect.new()
	cross_v.color = Color(0.92, 0.86, 0.55)
	cross_v.size = Vector2(3, 14)
	cross_v.position = Vector2(-1, -38)
	root.add_child(cross_v)
	var cross_h := ColorRect.new()
	cross_h.color = Color(0.92, 0.86, 0.55)
	cross_h.size = Vector2(9, 3)
	cross_h.position = Vector2(-4, -34)
	root.add_child(cross_h)

	# Подпись.
	var lbl := Label.new()
	lbl.text = "Алтарь возрождения"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.70))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(140, 14)
	lbl.position = Vector2(-70, -54)
	root.add_child(lbl)

func _spawn_rain_zone(pos: Vector2, half: float, duration_ms: int, start_server_t: int = 0) -> void:
	# half — половина стороны квадрата.
	# Длительность привязана к server-time: если вкладка неактивна, после
	# возврата ливень уже исчезнет (а не будет доигрывать с клиентского таймера).
	var node := Node2D.new()
	node.position = pos
	node.z_index = 90
	world.add_child(node)
	var square := _make_zone_square(half * 2.0, Color(1.0, 0.6, 0.25, 0.85))
	node.add_child(square)
	var now_s: int = server_now_ms()
	var start: int = start_server_t if start_server_t > 0 else now_s
	_rain_zones.append({
		"node": node,
		"square": square,
		"center": pos,
		"half": half,
		"end_at": start + duration_ms,
		"next_arrow": now_s,
	})

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

func _make_zone_square(size: float, color: Color) -> Sprite2D:
	# Квадрат с закруглёнными углами и тонкой обводкой (для тайловой сетки).
	var d := int(ceil(size))
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var radius_corner := 6.0
	var border_w := 2.5
	for y in range(d):
		for x in range(d):
			var dx := absf(x - d * 0.5)
			var dy := absf(y - d * 0.5)
			var hx: float = d * 0.5 - 1.0
			var hy: float = d * 0.5 - 1.0
			# Расстояние от внешнего края с учётом скруглённых углов
			var corner_dx: float = maxf(dx - (hx - radius_corner), 0.0)
			var corner_dy: float = maxf(dy - (hy - radius_corner), 0.0)
			var corner_d: float = sqrt(corner_dx * corner_dx + corner_dy * corner_dy)
			# Расстояние от края квадрата
			var edge_dist: float = maxf(maxf(dx, dy) - (hx - radius_corner), 0.0)
			if corner_dx > 0.0 and corner_dy > 0.0:
				# В углу — используем circle distance
				if corner_d > radius_corner:
					continue
				if corner_d > radius_corner - border_w:
					img.set_pixel(x, y, color)
				else:
					img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.18))
			else:
				if dx > hx or dy > hy:
					continue
				if edge_dist > radius_corner - border_w or maxf(dx, dy) > hx - border_w:
					img.set_pixel(x, y, color)
				else:
					img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.18))
	var tex := ImageTexture.create_from_image(img)
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s

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

func _on_admin_action(action: String, extra: Dictionary = {}) -> void:
	var my_name: String = String(Session.auth.username if Session.auth else "")
	if my_name == "":
		return
	var payload: Dictionary = {}
	match action:
		"heal_self":
			payload = {"op": "set_hp", "target": my_name, "hp": 99999}
		"heal_all":
			payload = {"op": "heal_all"}
		"give_gold_self":
			payload = {"op": "give_gold", "target": my_name, "amount": 1000}
		"give_golden_bow_self":
			payload = {"op": "give_item", "target": my_name, "itemId": "golden_bow", "qty": 1}
		"level_up":
			var cur_lvl: int = int(last_me.get("level", 1))
			payload = {"op": "set_level", "target": my_name, "level": cur_lvl + 5}
		"killall_mobs":
			payload = {"op": "killall_mobs"}
		"respawn_mobs":
			payload = {"op": "respawn_mobs"}
		"teleport_cursor":
			var cursor: Vector2 = get_viewport().get_camera_2d().get_global_mouse_position()
			payload = {"op": "teleport", "target": my_name, "x": cursor.x, "y": cursor.y}
		"list_users":
			payload = {"op": "list_users"}
		"give_gold_to":
			payload = {"op": "give_gold", "target": extra.get("target", ""), "amount": 1000}
		"give_item_to":
			payload = {"op": "give_item", "target": extra.get("target", ""), "itemId": extra.get("itemId", ""), "qty": 1}
		"level_up_to":
			# Требуется текущий уровень — фоллбек 1 + delta (не точно, но ОК для админки)
			var d: int = int(extra.get("delta", 5))
			payload = {"op": "set_level", "target": extra.get("target", ""), "level": 50 + d}  # TODO: точное значение
		_:
			return
	var rpc_res: NakamaAPI.ApiRpc = await Session.client.rpc_async(Session.auth, "admin", JSON.stringify(payload))
	if rpc_res.is_exception():
		admin_panel.log_result("ERR: " + rpc_res.get_exception().message)
		return
	# Для list_users парсим результат и заполняем UI
	if action == "list_users":
		var data: Variant = JSON.parse_string(rpc_res.payload)
		if typeof(data) == TYPE_DICTIONARY and data.has("users"):
			admin_panel.set_users(data["users"])
			admin_panel.log_result("Загружено: %d игроков" % data["users"].size())
		else:
			admin_panel.log_result("Неожиданный ответ: " + rpc_res.payload)
		return
	admin_panel.log_result(rpc_res.payload)
	# Если что-то дали/выдали — обновить список
	if action.begins_with("give_") or action.begins_with("level_up"):
		_on_admin_action("list_users", {})

# Сбросить отложенный каст (queued_skill и ground-координаты) + режим
# таргетинга. Зовётся при новом «движенческом» клике (земля / NPC /
# сундук / союзник), чтобы персонаж не «прыгал» обратно к старой точке
# каста. Для клика по живому мобу/враждебному игроку НЕ зовём — там
# queued_skill намеренно переиспользуется на новую цель.
func _cancel_queued_action() -> void:
	queued_skill = -1
	queued_ground_pos = Vector2.ZERO
	queued_approach_pos = Vector2.ZERO
	if targeting_skill >= 0:
		targeting_skill = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_skill_activated(index: int) -> void:
	# Единая точка входа для всех скиллов. Диспетчеризует по SkillDef.kind():
	#   INSTANT → срабатывает сразу (Отскок и т.п.)
	#   TARGET  → если цель уже выбрана — сразу в очередь; иначе targeting_mode
	#   GROUND  → всегда targeting_mode (нужна точка)
	# Очередь (queued_skill + позиция) обрабатывается в _process.
	if match_id == "" or Session.socket == null:
		return
	if skillbar.cooldowns[index] > 0.0:
		return
	var def: SkillDef = SkillRegistry.by_index(index)
	if def == null:
		return
	match def.kind():
		SkillDef.Kind.INSTANT:
			_cast_instant(index)
		SkillDef.Kind.TARGET:
			if _has_valid_target():
				# Цель уже выбрана — встаём в очередь без выбора
				queued_skill = index
				attack_ready_at_ms = 0
			else:
				# Нет цели — ждём клика по мобу/игроку
				targeting_skill = index
				Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		SkillDef.Kind.GROUND:
			targeting_skill = index
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func _resolve_targeting_click(index: int, world_pos: Vector2) -> void:
	# Обработка клика в режиме targeting (после активации TARGET/GROUND скилла).
	# Выход из режима происходит, только если клик попал в валидную сущность/точку.
	var def: SkillDef = SkillRegistry.by_index(index)
	if def == null:
		targeting_skill = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	match def.kind():
		SkillDef.Kind.TARGET:
			var mob_hit := _mob_at(world_pos)
			if mob_hit != null and mob_hit.alive:
				attack_target = mob_hit
				pvp_target = null
				_set_mob_highlight(mob_hit)
				queued_skill = index
				attack_ready_at_ms = 0
				targeting_skill = -1
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				return
			var sid_skill: String = _player_at(world_pos)
			if sid_skill != "":
				pvp_target = remotes.get(sid_skill)
				pvp_target_sid = sid_skill
				attack_target = null
				_set_mob_highlight(null)
				queued_skill = index
				attack_ready_at_ms = 0
				targeting_skill = -1
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				return
			# Клик мимо — отменяем targeting (чтобы не «липло» к курсору).
			targeting_skill = -1
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		SkillDef.Kind.GROUND:
			attack_target = null
			pvp_target = null
			_set_mob_highlight(null)
			queued_skill = index
			queued_ground_pos = world_pos
			# Approach: если точка в радиусе — остаёмся на месте, иначе точка
			# в радиусе каста, ближайшая к клику.
			var max_cast_init: float = _my_atk_range() - 20.0
			var d0: float = me.position.distance_to(world_pos)
			if d0 <= max_cast_init:
				queued_approach_pos = me.position
			else:
				var dir0: Vector2 = (world_pos - me.position).normalized()
				queued_approach_pos = world_pos - dir0 * max_cast_init
			attack_ready_at_ms = 0
			targeting_skill = -1
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_:
			# INSTANT не должен попадать в targeting_mode — на всякий случай
			# сбрасываем режим.
			targeting_skill = -1
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _has_valid_target() -> bool:
	if attack_target != null and is_instance_valid(attack_target) and attack_target.alive:
		return true
	if pvp_target != null and is_instance_valid(pvp_target):
		return true
	return false

func _cast_instant(index: int) -> void:
	# Сам skill-handler на сервере очищает moveTarget/movePath при телепорте
	# (см. skill_escape.ts). Клиенту НЕ нужно делать stop_move — иначе
	# сервер получит moveTarget=текущая позиция ДО Dodge и после телепорта
	# потянет игрока назад.
	var payload := {"skill": _server_id_for_slot(index)}
	var fdir: Vector2 = me.facing_vector()
	payload["dx"] = fdir.x
	payload["dy"] = fdir.y
	# INSTANT может использовать текущий таргет для контекста (Отскок
	# ориентируется на врага), но ждать/подходить не должен.
	if attack_target and is_instance_valid(attack_target):
		payload["mobId"] = attack_target.mob_id
	_send_skill(index, payload)

func _send_skill(index: int, payload: Dictionary) -> void:
	Session.socket.send_match_state_async(match_id, OP_SKILL, JSON.stringify(payload))
	skillbar.trigger_cooldown(index)
	var sk_def := SkillRegistry.by_index(index)
	if sk_def:
		sk_def.on_send(self)

# ─── Party (группы) ───

func _send_party_invite(target_sid: String) -> void:
	if match_id == "" or Session.socket == null:
		return
	Session.socket.send_match_state_async(match_id, OP_PARTY_INVITE,
		JSON.stringify({ "targetSid": target_sid }))

func _on_party_invite_notify(body: Dictionary) -> void:
	var from_sid := String(body.get("fromSid", ""))
	var from_name := String(body.get("fromName", "Игрок"))
	if party_ui:
		party_ui.show_invite(from_sid, from_name)

func _on_party_update(body: Dictionary) -> void:
	var members: Array = body.get("members", [])
	party_members_cache = members
	if party_ui:
		# my_session_id — уже хранится в my_session_id переменной game.gd
		party_ui.update_party(members, my_session_id)

func _on_invite_accepted(from_sid: String) -> void:
	if match_id == "" or Session.socket == null:
		return
	Session.socket.send_match_state_async(match_id, OP_PARTY_ACCEPT,
		JSON.stringify({ "fromSid": from_sid }))

func _on_invite_declined(from_sid: String) -> void:
	if match_id == "" or Session.socket == null:
		return
	Session.socket.send_match_state_async(match_id, OP_PARTY_DECLINE,
		JSON.stringify({ "fromSid": from_sid }))

func _on_party_leave_request() -> void:
	if match_id == "" or Session.socket == null:
		return
	Session.socket.send_match_state_async(match_id, OP_PARTY_LEAVE, "{}")

# Server id скилла в данном слоте hotbar. Пока hotbar = SkillRegistry.all()
# 1:1, но когда игрок сможет раскладывать скиллы по слотам — эта
# функция станет точкой маппинга.
func _server_id_for_slot(slot_index: int) -> int:
	var d := SkillRegistry.by_index(slot_index)
	return d.server_id if d else (slot_index + 1)

func _spawn_damage_label(pos: Vector2, dmg: int, is_crit: bool = false, is_poison: bool = false, is_ghost: bool = false) -> void:
	var lbl := Label.new()
	var size := 18
	var color := Color(1.0, 0.85, 0.2)
	var suffix := ""
	if is_crit:
		size = 24
		color = Color(1.0, 0.35, 0.25)
		suffix = "!"
	elif is_poison:
		color = Color(0.55, 0.95, 0.35)
	elif is_ghost:
		color = Color(0.72, 0.82, 1.0)
	lbl.text = "-%d%s" % [dmg, suffix]
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
	# OP_ARROW теперь — только визуал снаряда. Анимация стрелка идёт
	# через OP_PLAYER_ACTION (источник истины единый для всех классов).
	if bool(body.get("melee", false)):
		return
	var from := Vector2(float(body.get("fx", 0)), float(body.get("fy", 0)))
	var to := Vector2(float(body.get("tx", 0)), float(body.get("ty", 0)))
	var dir: Vector2 = (to - from).normalized()
	from = Vector2(from.x + dir.x * 10.0, from.y - 22.0)
	var style := "normal"
	if bool(body.get("crit", false)): style = "crit"
	elif bool(body.get("poison", false)): style = "poison"
	elif bool(body.get("ghost", false)): style = "ghost"
	var arrow: Arrow = ARROW_SCRIPT.new()
	entities.add_child(arrow)
	arrow.shoot(from, to, style)

# Универсальный обработчик OP_PLAYER_ACTION. Server шлёт {sid, kind, tx?, ty?}
# при любом действии игрока, которое имеет визуальную анимацию. Клиент
# находит нужного Player'а (свой или remote) и зовёт play_action(kind).
# Добавить новый класс/скилл = выбрать имя kind на сервере, клиент
# автоматически его проиграет.
func _apply_player_action(body: Dictionary) -> void:
	var sid := String(body.get("sid", ""))
	var kind := String(body.get("kind", ""))
	if kind == "":
		return
	var p: Player = me if sid == my_session_id else remotes.get(sid)
	if p == null or not is_instance_valid(p):
		return
	if body.has("tx") and body.has("ty"):
		var tgt := Vector2(float(body.get("tx", 0)), float(body.get("ty", 0)))
		p.face_toward(tgt)
	p.play_action(kind)

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
