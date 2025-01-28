extends Node2D

@export var player_scene: PackedScene # Сцена игрока
@onready var players = {} # Хранит игроков (id → узел игрока)

func _ready():
	multiplayer.connect("peer_connected", Callable(self, "_on_player_connected"))
	multiplayer.connect("peer_disconnected", Callable(self, "_on_player_disconnected"))
	setup_network()

func setup_network():
	if Global.is_server:
		var server = ENetMultiplayerPeer.new()
		server.create_server(12345)
		multiplayer.multiplayer_peer = server
		print("Сервер запущен на порту 12345!")
		# Создаём игрока для сервера
		spawn_player(multiplayer.get_unique_id())
		players[multiplayer.get_unique_id()].set_player_name(Global.player_name)
	else:
		var client = ENetMultiplayerPeer.new()
		client.create_client(Global.server_ip, 12345)
		multiplayer.multiplayer_peer = client
		print("Подключение к серверу по адресу: ", Global.server_ip)
		# Ожидание подключения клиента
		await await_connection()

func await_connection():
	while multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await get_tree().process_frame # Ждём следующего кадра
	print("Успешно подключено к серверу!")
	spawn_player(multiplayer.get_unique_id())
	rpc_id(1, "register_player_name", multiplayer.get_unique_id(), Global.player_name)





func _on_player_connected(id):
	if multiplayer.is_server():
		print("Игрок подключён с ID: ", id)
		spawn_player(id)
		# Рассылаем информацию о сервере новому клиенту
		for existing_id in players.keys():
			if existing_id != id:
				rpc_id(id, "spawn_player", existing_id)
				rpc_id(id, "register_player_name", existing_id, players[existing_id].player_name)


func _on_player_disconnected(id):
	print("Игрок отключился с ID: ", id)
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

@rpc("any_peer")
func spawn_player(id):
	if players.has(id):
		return
	var player = player_scene.instantiate()
	player.name = "Player_" + str(id)
	player.position = Vector2(randf() * 400, randf() * 400) # Случайная позиция
	player.set_multiplayer_authority(id)
	add_child(player)
	players[id] = player
	print("Создан игрок с ID: ", id, " Владелец: ", player.get_multiplayer_authority())

@rpc("any_peer")
func register_player_name(id, name):
	if players.has(id):
		players[id].set_player_name(name)
		print("Имя зарегистрировано: ", name)
		if id == multiplayer.get_unique_id():
			print("Ваше имя обновлено на: ", name)

