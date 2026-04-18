# Singleton (autoload as "Session") holding the Nakama client and current auth session.
# Scenes pull `Session.client` and `Session.auth` rather than reconnecting.
#
# Сессия хранится в localStorage (Web), при следующем заходе восстанавливается,
# пока refresh_token не истёк — пользователь сразу попадает на выбор персонажа,
# минуя экран логина.
extends Node

const NAKAMA_SCRIPT = preload("res://addons/com.heroiclabs.nakama/Nakama.gd")

const HOST := "nk.193-238-134-75.sslip.io"
const PORT := 443
const SCHEME := "https"
const SERVER_KEY := "defaultkey"

const STORAGE_TOKEN_KEY := "gg_session_token"
const STORAGE_REFRESH_KEY := "gg_session_refresh"
const STORAGE_EMAIL_KEY := "gg_last_email"

var client: NakamaClient
var socket: NakamaSocket
var auth: NakamaSession
var nakama: Node

# Выбранный персонаж текущей сессии. Пока есть только "archer".
# Пустая строка = ещё не выбрал, показать экран выбора.
var selected_character: String = ""

# Текущая зона (village/forest/dungeon). Меняется при межзонном переходе.
var current_zone: String = "village"

# Server-time offset. Обновляется из каждого OP_ME (game._apply_me).
var server_offset_ms: int = 0

func server_now_ms() -> int:
	return Time.get_ticks_msec() + server_offset_ms

func _ready() -> void:
	nakama = NAKAMA_SCRIPT.new()
	nakama.name = "Nakama"
	add_child(nakama)
	client = nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME)
	# Попытаться восстановить сессию из localStorage (Web).
	var tok := _ls_get(STORAGE_TOKEN_KEY)
	if tok != "":
		var s: NakamaSession = NakamaClient.restore_session(tok)
		if s != null and not s.expired:
			auth = s
		else:
			# Попробуем refresh_token если токен истёк но refresh ещё жив.
			var rtok := _ls_get(STORAGE_REFRESH_KEY)
			if rtok != "" and s != null:
				var refreshed: NakamaSession = await client.session_refresh_async(s)
				if not refreshed.is_exception() and not refreshed.expired:
					auth = refreshed
					save_auth_to_storage(refreshed)
				else:
					clear_storage()
			else:
				clear_storage()

func is_logged_in() -> bool:
	return auth != null and not auth.expired

func save_auth_to_storage(s: NakamaSession) -> void:
	if s == null:
		return
	_ls_set(STORAGE_TOKEN_KEY, s.token)
	_ls_set(STORAGE_REFRESH_KEY, s.refresh_token if s.refresh_token else "")

func save_email(email: String) -> void:
	_ls_set(STORAGE_EMAIL_KEY, email)

func get_saved_email() -> String:
	return _ls_get(STORAGE_EMAIL_KEY)

func clear_storage() -> void:
	_ls_del(STORAGE_TOKEN_KEY)
	_ls_del(STORAGE_REFRESH_KEY)

func logout() -> void:
	if socket and socket.is_connected_to_host():
		socket.close()
	socket = null
	auth = null
	selected_character = ""
	clear_storage()

# ─── localStorage helpers (no-op на не-Web платформах) ───
func _ls_get(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("window.localStorage.getItem('%s') || ''" % key, true)
	return String(v) if v != null else ""

func _ls_set(key: String, value: String) -> void:
	if not OS.has_feature("web"):
		return
	var safe := value.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("window.localStorage.setItem('%s', '%s')" % [key, safe], true)

func _ls_del(key: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.localStorage.removeItem('%s')" % key, true)
