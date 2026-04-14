# Placeholder game scene. In phase 2 this hosts the world, camera, and networking.
extends Control

signal auth_changed

@onready var hello_label: Label = %HelloLabel
@onready var logout_btn: Button = %LogoutBtn
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	logout_btn.pressed.connect(_on_logout)
	hello_label.text = "Вошёл как %s" % Session.auth.user_id
	status_label.text = "Подключаюсь к real-time серверу…"
	_connect_socket()

func _on_logout() -> void:
	Session.logout()
	auth_changed.emit()

func _connect_socket() -> void:
	var socket := Nakama.create_socket_from(Session.client)
	var err: NakamaAsyncResult = await socket.connect_async(Session.auth)
	if err.is_exception():
		status_label.text = "Socket ошибка: %s" % err.get_exception().message
		return
	Session.socket = socket
	status_label.text = "Real-time OK. Фаза 2 — мир и движение."
