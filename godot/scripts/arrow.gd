# Fleeting bow shot visual. Spawn, call shoot(from, to, style), self-destructs.
class_name Arrow
extends Node2D

const FLIGHT_S := 0.15

func shoot(from: Vector2, to: Vector2, style: String = "normal") -> void:
	position = from
	var delta := to - from
	rotation = delta.angle()

	var shaft_color := Color(0.98, 0.91, 0.55, 1.0)
	var head_color := Color(0.7, 0.7, 0.75, 1.0)
	var glow_color := Color(0, 0, 0, 0)
	var glow_radius := 0.0
	match style:
		"crit":
			# Чёрная светящаяся стрела для «Меткого выстрела»
			shaft_color = Color(0.08, 0.05, 0.12, 1.0)
			head_color = Color(1.0, 0.25, 0.25, 1.0)
			glow_color = Color(1.0, 0.3, 0.2, 0.8)
			glow_radius = 14.0
		"poison":
			shaft_color = Color(0.3, 0.85, 0.25, 1.0)
			head_color = Color(0.55, 1.0, 0.4, 1.0)
			glow_color = Color(0.4, 1.0, 0.3, 0.6)
			glow_radius = 10.0
		"ghost":
			shaft_color = Color(0.75, 0.85, 1.0, 0.85)
			head_color = Color(0.6, 0.8, 1.0, 1.0)
			glow_color = Color(0.6, 0.8, 1.0, 0.7)
			glow_radius = 10.0

	if glow_radius > 0.0:
		var glow := Sprite2D.new()
		glow.texture = _make_glow(glow_radius, glow_color)
		glow.modulate = glow_color
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.scale = Vector2(1.2, 1.0)
		add_child(glow)

	var body := ColorRect.new()
	body.color = shaft_color
	body.size = Vector2(16, 2)
	body.position = Vector2(-8, -1)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	var head := ColorRect.new()
	head.color = head_color
	head.size = Vector2(4, 4)
	head.position = Vector2(6, -2)
	add_child(head)

	# Fletching (оперение у хвоста)
	var fletch := ColorRect.new()
	fletch.color = head_color
	fletch.color.a = 0.8
	fletch.size = Vector2(3, 5)
	fletch.position = Vector2(-10, -2.5)
	add_child(fletch)

	var tween := create_tween()
	tween.tween_property(self, "position", to, FLIGHT_S)
	tween.tween_callback(queue_free)

func _make_glow(r: float, c: Color) -> ImageTexture:
	var size: int = int(ceil(r * 2.5))
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x, y).distance_to(cx)
			if d < r:
				var a: float = (1.0 - d / r)
				a = a * a
				img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)
