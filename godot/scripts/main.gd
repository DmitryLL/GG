# Local demo entry point. Boot straight into Game so the project can be viewed offline.
extends Node

const GAME_SCENE := preload("res://scenes/Game.tscn")

func _ready() -> void:
	var inst = GAME_SCENE.instantiate()
	add_child(inst)
