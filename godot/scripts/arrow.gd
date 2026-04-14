# Fleeting bow shot visual. Spawn, call setup(from, to), it flies and self-destructs.
class_name Arrow
extends Node2D

const FLIGHT_S := 0.15

func _ready() -> void:
	pass

func shoot(from: Vector2, to: Vector2) -> void:
	position = from
	var delta := to - from
	rotation = delta.angle()
	var body := ColorRect.new()
	body.color = Color(0.98, 0.91, 0.55, 1.0)   # yellow-gold shaft
	body.size = Vector2(14, 2)
	body.position = Vector2(-7, -1)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	var head := ColorRect.new()
	head.color = Color(0.7, 0.7, 0.75, 1.0)
	head.size = Vector2(3, 3)
	head.position = Vector2(5, -1.5)
	add_child(head)
	var tween := create_tween()
	tween.tween_property(self, "position", to, FLIGHT_S)
	tween.tween_callback(queue_free)
