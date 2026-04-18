# Декоративный слой: бабочки/пчёлки, летающие над лугами.
# Чисто визуальная штука, не взаимодействует с игрой и не влияет на сервер.
# Спавнится один раз на старте мира, бабочки летают по случайным траекториям
# в пределах карты, циклически меняя цель.
class_name Butterflies
extends Node2D

const COUNT := 40
const SPEED_MIN := 18.0
const SPEED_MAX := 32.0
const WANDER_RADIUS := 180.0

var _bugs: Array = []  # каждая — Dictionary: node, target, speed, t, color

var _world: World = null
var _map_w: int = 0
var _map_h: int = 0

func setup(world: World) -> void:
	_world = world
	_map_w = world.data.map_cols * WorldData.TILE_SIZE
	_map_h = world.data.map_rows * WorldData.TILE_SIZE
	z_index = 80
	for i in range(COUNT):
		_spawn_bug()

func _spawn_bug() -> void:
	# Спавним бабочку на случайном проходимом тайле (луг).
	for _tries in range(30):
		var x := randi_range(40, _map_w - 40)
		var y := randi_range(40, _map_h - 40)
		if _world.is_walkable(Vector2(x, y)):
			var bug := Sprite2D.new()
			bug.texture = _make_bug_texture(_random_bug_color())
			bug.position = Vector2(x, y)
			bug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(bug)
			_bugs.append({
				"node": bug,
				"target": _pick_target(bug.position),
				"speed": randf_range(SPEED_MIN, SPEED_MAX),
				"flap_t": randf() * TAU,
			})
			return

func _random_bug_color() -> Color:
	# Мягкие пастельные цвета — белый, жёлтый, голубой, розовый.
	var palette := [
		Color(1.00, 1.00, 0.95),
		Color(1.00, 0.92, 0.45),
		Color(0.60, 0.80, 1.00),
		Color(1.00, 0.70, 0.85),
		Color(0.85, 1.00, 0.70),
	]
	return palette[randi() % palette.size()]

func _make_bug_texture(color: Color) -> ImageTexture:
	# Крошечный 5×3 силуэт бабочки.
	var img := Image.create(5, 3, false, Image.FORMAT_RGBA8)
	var a := Color(color.r, color.g, color.b, 1.0)
	var dark := Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 1.0)
	img.set_pixel(0, 0, a); img.set_pixel(1, 0, dark); img.set_pixel(3, 0, dark); img.set_pixel(4, 0, a)
	img.set_pixel(2, 1, dark)
	img.set_pixel(0, 2, a); img.set_pixel(1, 2, dark); img.set_pixel(3, 2, dark); img.set_pixel(4, 2, a)
	return ImageTexture.create_from_image(img)

func _pick_target(from: Vector2) -> Vector2:
	for _tries in range(10):
		var angle := randf() * TAU
		var r := randf_range(60.0, WANDER_RADIUS)
		var p := from + Vector2(cos(angle), sin(angle)) * r
		p.x = clampf(p.x, 40.0, _map_w - 40.0)
		p.y = clampf(p.y, 40.0, _map_h - 40.0)
		if _world.is_walkable(p):
			return p
	return from

func _process(delta: float) -> void:
	for b in _bugs:
		var node: Sprite2D = b["node"]
		if node == null or not is_instance_valid(node):
			continue
		var target: Vector2 = b["target"]
		var to_target := target - node.position
		var dist := to_target.length()
		if dist < 4.0:
			b["target"] = _pick_target(node.position)
			continue
		var step := to_target.normalized() * float(b["speed"]) * delta
		node.position += step
		# Флаппинг — лёгкое вертикальное «дрожание» крыльев (визуально)
		b["flap_t"] = float(b["flap_t"]) + delta * 12.0
		node.scale.y = 1.0 + 0.35 * sin(float(b["flap_t"]))
