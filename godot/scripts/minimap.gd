# Миникарта в правом верхнем углу канваса. Фон — тайлы пересчитанные в
# 3px-квадратики (180×135). Каждые 200мс поверх рисуются точки: зелёная
# — я, белые — другие игроки, красные — живые мобы, жёлтая — NPC.
class_name Minimap
extends CanvasLayer

const TILE_PX := 3
var world: World
var get_me: Callable
var get_others: Callable
var get_mobs: Callable
var get_npcs: Callable

var tex_rect: TextureRect
var tiles_image: Image
var tiles_tex: ImageTexture
var frame_image: Image
var frame_tex: ImageTexture
var last_update := 0.0
var gold_label: Label

var _scale: float
var _width: int
var _height: int

const TILE_COLORS := {
	0: Color(0.29, 0.49, 0.31),   # grass
	1: Color(0.85, 0.77, 0.58),   # sand
	2: Color(0.23, 0.43, 0.66),   # water
	3: Color(0.16, 0.35, 0.20),   # tree
	4: Color(0.52, 0.52, 0.63),   # stone
	5: Color(0.66, 0.57, 0.42),   # path
}

func setup(p_world: World, me_cb: Callable, others_cb: Callable, mobs_cb: Callable, npcs_cb: Callable) -> void:
	world = p_world
	get_me = me_cb
	get_others = others_cb
	get_mobs = mobs_cb
	get_npcs = npcs_cb

func _ready() -> void:
	_width = world.data.map_cols * TILE_PX
	_height = world.data.map_rows * TILE_PX
	_scale = float(TILE_PX) / float(WorldData.TILE_SIZE)

	tiles_image = Image.create(_width, _height, false, Image.FORMAT_RGBA8)
	for r in world.data.map_rows:
		for c in world.data.map_cols:
			var id: int = world.data.tiles[r * world.data.map_cols + c]
			var col: Color = TILE_COLORS.get(id, Color(0, 0, 0, 1))
			for dy in TILE_PX:
				for dx in TILE_PX:
					tiles_image.set_pixel(c * TILE_PX + dx, r * TILE_PX + dy, col)
	tiles_tex = ImageTexture.create_from_image(tiles_image)
	frame_image = tiles_image.duplicate()
	frame_tex = ImageTexture.create_from_image(frame_image)

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var v := VBoxContainer.new()
	v.anchor_left = 1.0
	v.anchor_right = 1.0
	v.anchor_top = 0.0
	v.offset_left = -(_width + 16)
	v.offset_right = -8
	v.offset_top = 8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	root.add_child(v)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(panel)

	tex_rect = TextureRect.new()
	tex_rect.texture = frame_tex
	tex_rect.custom_minimum_size = Vector2(_width, _height)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(tex_rect)

	# Маленький бейдж золота под миникартой.
	var gold_panel := PanelContainer.new()
	var gp_sb := StyleBoxFlat.new()
	gp_sb.bg_color = Color(0.07, 0.06, 0.05, 0.85)
	gp_sb.border_color = Color(0.65, 0.50, 0.20, 1.0)
	gp_sb.set_border_width_all(1)
	gp_sb.set_corner_radius_all(4)
	gp_sb.set_content_margin_all(6)
	gold_panel.add_theme_stylebox_override("panel", gp_sb)
	gold_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gold_panel)
	gold_label = Label.new()
	gold_label.text = "0 зол."
	gold_label.add_theme_color_override("font_color", Color(0.99, 0.85, 0.45, 1))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_panel.add_child(gold_label)

func set_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = "%d зол." % amount

func _process(delta: float) -> void:
	last_update += delta
	if last_update < 0.2:
		return
	last_update = 0.0
	_redraw()

func _dot(img: Image, wx: float, wy: float, size: int, color: Color) -> void:
	var px := int(wx * _scale)
	var py := int(wy * _scale)
	var half := size / 2
	for dy in range(-half, size - half):
		for dx in range(-half, size - half):
			var x := px + dx
			var y := py + dy
			if x < 0 or y < 0 or x >= _width or y >= _height:
				continue
			img.set_pixel(x, y, color)

func _redraw() -> void:
	frame_image.copy_from(tiles_image)
	if get_npcs.is_valid():
		for n in get_npcs.call():
			var entry: Dictionary = n
			_dot(frame_image, float(entry.get("x", 0)), float(entry.get("y", 0)), 4, Color(0.99, 0.89, 0.29))
	if get_mobs.is_valid():
		for mob_v in get_mobs.call():
			var mob: Mob = mob_v
			if not is_instance_valid(mob) or not mob.alive:
				continue
			_dot(frame_image, mob.position.x, mob.position.y, 3, Color(0.94, 0.27, 0.27))
	if get_others.is_valid():
		for p_v in get_others.call():
			var p: Player = p_v
			if not is_instance_valid(p):
				continue
			_dot(frame_image, p.position.x, p.position.y, 3, Color.WHITE)
	if get_me.is_valid():
		var m_pos: Vector2 = get_me.call()
		_dot(frame_image, m_pos.x, m_pos.y, 5, Color(0.29, 0.87, 0.5))
	frame_tex.update(frame_image)
