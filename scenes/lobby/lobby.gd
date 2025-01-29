extends Node2D

@export var coin_scene: PackedScene
@export var num_coins: int = 100 # Количество монеток
@export var field_size: Vector2 = Vector2(1800, 1000) # Размер поля

@export var player_scene: PackedScene # Сцена игрока
@onready var players = {} # Хранит игроков (id → узел игрока)
@onready var audio_player = $AudioPlayer
@onready var coin_label = $CanvasLayer/CoinLabel
@onready var coin_last = $CanvasLayer/CoinLast


var current_index = randf()
var coins_collected: int = 0

var audio_files = [
	preload("res://assets/sounds/bit-beats-1-168243.mp3"),
	preload("res://assets/sounds/falselyclaimed-bit-beats-3-168873.mp3"),
	preload("res://assets/sounds/that-game-arcade-medium-236110.mp3")
]

func _ready():
	multiplayer.connect("peer_connected", Callable(self, "_on_player_connected"))
	multiplayer.connect("peer_disconnected", Callable(self, "_on_player_disconnected"))
	setup_network()
	play_next()
	scatter_coins()

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
	print("Отправляем имя на сервер:", Global.player_name)
	rpc_id(1, "register_player_name", multiplayer.get_unique_id(), Global.player_name)
	# Запрашиваем состояние музыки у сервера
	rpc_id(1, "request_music_state")

func _on_player_connected(id):
	if multiplayer.is_server():
		print("Игрок подключён с ID:", id)
		spawn_player(id) # Сначала создаём игрока на сервере

		# Рассылаем всем остальным клиентам информацию о новом игроке
		for peer_id in multiplayer.get_peers():
			if peer_id != id:
				rpc_id(peer_id, "spawn_player", id)
				await get_tree().process_frame # Ждём следующий кадр, чтобы узел успел создаться
				rpc_id(peer_id, "register_player_name", id, players[id].player_name)

		# Отправляем новому игроку информацию о сервере
		for existing_id in players.keys():
			rpc_id(id, "spawn_player", existing_id)
			await get_tree().process_frame # Ждём следующий кадр
			rpc_id(id, "register_player_name", existing_id, players[existing_id].player_name)

		# Отправляем все монеты новому игроку
		for coin in coins:
			rpc_id(id, "spawn_coin", coin.position)

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
	player.position = Vector2(randf() * 400, randf() * 400)
	player.set_multiplayer_authority(id)
	add_child(player)
	players[id] = player
	print("Игрок создан с ID:", id, " Имя узла:", player.name)

	# Если это локальный игрок
	if id == multiplayer.get_unique_id():
		player.set_player_name(Global.player_name)
		print("Локальное имя игрока установлено при создании:", Global.player_name)

		# Активируем камеру
		var camera = player.get_node("Camera2D")
		if camera is Camera2D:
			camera.make_current()
			print("Камера активирована для локального игрока")
		else:
			print("Ошибка: Узел Camera2D не найден или имеет неверный тип")




@rpc("any_peer")
func register_player_name(id, name):
	if not players.has(id):
		print("Игрок с ID", id, "не найден. Создаём...")
		spawn_player(id) # Создаём игрока, если он не существует
	players[id].set_player_name(name) # Устанавливаем имя игрока
	print("Имя игрока с ID", id, "обновлено на:", name)

	# Если это локальный игрок, обновляем глобальное имя
	if id == multiplayer.get_unique_id():
		Global.player_name = name
		print("Локальный игрок обновил своё имя на:", name)


func play_next():
	if current_index < audio_files.size():
		audio_player.stream = audio_files[current_index] # Устанавливаем следующий аудиофайл
		audio_player.play() # Запускаем воспроизведение
		print("Играем файл:", audio_files[current_index])

		# Сообщаем клиентам о новом треке и времени
		rpc("start_music", current_index, 0.0)

		current_index += 1 # Увеличиваем индекс для следующего файла
	else:
		print("Все файлы воспроизведены.")
		current_index = 0 # Сбрасываем индекс, если нужно повторить цикл

@rpc("any_peer")
func request_music_state():
	if multiplayer.is_server():
		# Отправляем клиенту текущий трек и позицию воспроизведения
		rpc_id(multiplayer.get_remote_sender_id(), "start_music", current_index - 1, audio_player.get_playback_position())


func _on_audio_player_finished():
	play_next()

@rpc("any_peer")
func start_music(track_index: int, playback_position: float):
	if track_index < audio_files.size():
		audio_player.stream = audio_files[track_index]
		audio_player.play(playback_position) # Запускаем с указанного момента
		print("Музыка синхронизирована: Трек", track_index, "Время:", playback_position)

var coins = []

func scatter_coins():
	if not multiplayer.is_server():
		return  # Монеты создаются только на сервере

	for i in range(num_coins):
		var coin = coin_scene.instantiate()
		var random_x = randf() * field_size.x
		var random_y = randf() * field_size.y
		coin.position = Vector2(random_x, random_y)

		coin.connect("coin_picked", Callable(self, "_on_coin_picked").bind(coin))

		add_child(coin)
		coins.append(coin)  # Сохраняем монету в списке
		print("Монета добавлена на позицию:", coin.position)

		# Сообщаем клиентам о новой монете
		rpc("spawn_coin", coin.position)


@rpc("authority", "reliable")
func spawn_coin(position: Vector2):
	if multiplayer.is_server():
		return  # Сервер не создает монеты повторно

	var coin = coin_scene.instantiate()
	coin.position = position

	coin.connect("coin_picked", Callable(self, "_on_coin_picked").bind(coin))
	add_child(coin)
	coins.append(coin)


@rpc("any_peer", "reliable")
func _on_coin_picked(amount: int, coin_node: NodePath):
	if multiplayer.is_server():
		# Рассылаем клиентам команду удалить монету
		rpc("remove_coin", coin_node)
	
		# Удаляем монету на сервере
		var coin = get_node_or_null(coin_node)
		if coin:
			coins.erase(coin)
			coin.queue_free()

	coins_collected += amount
	num_coins -= 1
	update_coin_labels()

@rpc("authority", "reliable")
func remove_coin(coin_node: NodePath):
	var coin = get_node_or_null(coin_node)
	if coin:
		coins.erase(coin)
		coin.queue_free()


func update_coin_labels():
	coin_label.text = "Монеты: " + str(coins_collected)
	coin_last.text = "Осталось монет: " + str(num_coins)
