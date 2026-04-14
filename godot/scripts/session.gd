# Singleton (autoload as "Session") holding the Nakama client and current auth session.
# Scenes pull `Session.client` and `Session.auth` rather than reconnecting.
extends Node

const HOST := "nk.193-238-134-75.sslip.io"
const PORT := 443
const SCHEME := "https"
const SERVER_KEY := "defaultkey" # Nakama default; overridden later in config

var client: NakamaClient
var socket: NakamaSocket
var auth: NakamaSession

func _ready() -> void:
	client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME)

func is_logged_in() -> bool:
	return auth != null and not auth.expired

func logout() -> void:
	if socket and socket.is_connected_to_host():
		socket.close()
	socket = null
	auth = null
