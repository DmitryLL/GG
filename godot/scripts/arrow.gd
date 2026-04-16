# Летящая стрела — спрайт PixelLab + свечение для вариантов скиллов.
class_name Arrow
extends Node2D

const FLIGHT_S := 0.18
const ARROW_TEX := preload("res://assets/sprites/arrow.png")
const ARROW_CRIT_TEX := preload("res://assets/sprites/arrow_crit.png")

func shoot(from: Vector2, to: Vector2, style: String = "normal") -> void:
	position = from
	var delta := to - from
	rotation = delta.angle()

	var modulate_color := Color(1, 1, 1, 1)
	var glow_color := Color(0, 0, 0, 0)
	var glow_radius := 0.0
	var texture := ARROW_TEX
	var scale_v := Vector2(0.55, 0.55)
	match style:
		"crit":
			texture = ARROW_CRIT_TEX
			scale_v = Vector2(0.75, 0.75)
			glow_color = Color(1.0, 0.2, 0.15, 0.95)
			glow_radius = 26.0
		"poison":
			modulate_color = Color(0.55, 1.0, 0.45, 1.0)
			glow_color = Color(0.4, 1.0, 0.3, 0.7)
			glow_radius = 14.0
		"ghost":
			modulate_color = Color(0.82, 0.9, 1.0, 0.85)
			glow_color = Color(0.65, 0.85, 1.0, 0.7)
			glow_radius = 12.0

	if glow_radius > 0.0:
		var glow := Sprite2D.new()
		glow.texture = _make_glow(glow_radius, glow_color)
		glow.modulate = glow_color
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.scale = Vector2(1.3, 1.0)
		add_child(glow)

	var spr := Sprite2D.new()
	spr.texture = texture
	spr.scale = scale_v
	spr.modulate = modulate_color
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)

	var tween := create_tween()
	tween.tween_property(self, "position", to, FLIGHT_S).set_trans(Tween.TRANS_LINEAR)
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
