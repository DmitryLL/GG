# Entry router.
# - Не логин → Auth
# - Логин есть, но персонаж не выбран → CharacterSelect
# - Всё готово → Game
extends Node

const AUTH_SCENE := preload("res://scenes/core/Auth.tscn")
const CHAR_SELECT_SCENE := preload("res://scenes/core/CharacterSelect.tscn")
const GAME_SCENE := preload("res://scenes/core/Game.tscn")

func _ready() -> void:
	# Session._ready() может делать async refresh токена — дождёмся.
	await get_tree().process_frame
	_route()

func _route() -> void:
	for child in get_children():
		child.queue_free()
	var scene: PackedScene
	if not Session.is_logged_in():
		scene = AUTH_SCENE
	elif Session.selected_character == "":
		scene = CHAR_SELECT_SCENE
	else:
		scene = GAME_SCENE
	var inst = scene.instantiate()
	add_child(inst)
	if inst.has_signal("auth_changed"):
		inst.auth_changed.connect(_on_auth_changed)

func _on_auth_changed() -> void:
	_route()
