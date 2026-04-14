# Entry router. If the session is live, show Game; otherwise show Auth.
extends Node

const AUTH_SCENE := preload("res://scenes/Auth.tscn")
const GAME_SCENE := preload("res://scenes/Game.tscn")

func _ready() -> void:
	_route()

func _route() -> void:
	for child in get_children():
		child.queue_free()
	var scene: PackedScene = GAME_SCENE if Session.is_logged_in() else AUTH_SCENE
	var inst = scene.instantiate()
	add_child(inst)
	if inst.has_signal("auth_changed"):
		inst.auth_changed.connect(_on_auth_changed)

func _on_auth_changed() -> void:
	_route()
