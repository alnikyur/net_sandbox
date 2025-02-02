extends Node2D

@export var coin_scene: PackedScene
@export var num_coins: int = 10 # Количество монеток
@export var field_size: Vector2 = Vector2(1900, 1050) # Размер поля


@export var player_scene: PackedScene # Сцена игрока
@onready var players = {} # Хранит игроков (id → узел игрока)
@onready var audio_player = $AudioPlayer
@onready var coin_label = $CanvasLayer/CoinLabel
@onready var coin_last = $CanvasLayer/CoinLast
@onready var player_scores = {}
@onready var exit_game = $CanvasLayer/ExitGame

var local_coins_collected: int = 0
var current_index = randf()
var coins_collected: int = 0
var server_id = 1
var remaining_tracks = []  # Список оставшихся треков
var current_track = -1

var audio_files = [
	preload("res://assets/sounds/bit-beats-1-168243.mp3"),
	preload("res://assets/sounds/falselyclaimed-bit-beats-3-168873.mp3"),
	preload("res://assets/sounds/that-game-arcade-medium-236110.mp3")
]

func _ready():
	chat_ui.message_sent.connect(_on_message_sent)
	print("coin_label:", coin_label, "coin_last:", coin_last)
	multiplayer.connect("peer_connected", Callable(self, "_on_player_connected"))
	multiplayer.connect("peer_disconnected", Callable(self, "_on_player_disconnected"))
	setup_network()
	reset_playlist()
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
		player_scores[id] = 0

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
			
		# Отправляем текущие счета всем игрокам
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "update_player_score", id, player_scores[id])

		# Отправляем новому игроку текущее состояние всех счетов
		for existing_id in player_scores.keys():
			rpc_id(id, "update_player_score", existing_id, player_scores[existing_id])

		# Отправляем новому игроку количество оставшихся монет
		rpc_id(id, "update_coin_count", num_coins)

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

func reset_playlist():
	# Создаем новый список треков и перемешиваем его
	remaining_tracks = audio_files.duplicate()
	remaining_tracks.shuffle()

func play_next():
	# Если все треки были сыграны – обновляем плейлист
	if remaining_tracks.is_empty():
		reset_playlist()
	
	# Берем следующий трек
	var track = remaining_tracks.pop_front()
	current_track = audio_files.find(track)  # Запоминаем его индекс в основном списке

	audio_player.stream = track  # Устанавливаем аудиофайл
	audio_player.play()  # Воспроизводим
	print("🎵 Играем файл:", track)

	# Сообщаем клиентам о новом треке
	rpc("start_music", current_track, 0.0)

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

	var space_state = get_world_2d().direct_space_state
	var max_attempts = 10  # Количество попыток поиска свободного места

	for i in range(num_coins):
		var spawn_position = Vector2.ZERO
		var attempts = 0

		while attempts < max_attempts:
			# Генерируем случайную позицию
			var random_x = randf() * field_size.x
			var random_y = randf() * field_size.y
			spawn_position = Vector2(random_x, random_y)

			# Проверяем коллизию в этом месте
			var query = PhysicsShapeQueryParameters2D.new()
			query.shape = CircleShape2D.new()
			query.shape.radius = 8  # Радиус монеты
			query.transform = Transform2D(0, spawn_position)

			var result = space_state.intersect_shape(query)

			# Если результат пуст, значит, место свободно
			if result.is_empty():
				break

			attempts += 1

		# Если удалось найти свободное место, создаем монету
		var coin = coin_scene.instantiate()
		coin.position = spawn_position

		# Подключаем сигнал, чтобы сервер мог обработать сбор монеты
		coin.connect("coin_picked", Callable(self, "_on_coin_picked"))

		add_child(coin)
		coins.append(coin)

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

#@rpc("any_peer", "reliable")
#func _on_coin_picked(amount: int, coin_node: NodePath, player_id: int):
	#print("📩 _on_coin_picked вызвано! ID игрока:", player_id, " Локальный ID:", multiplayer.get_unique_id())
#
	## Если монету подобрал ЛОКАЛЬНЫЙ игрок, обновляем его UI
	#if player_id == multiplayer.get_unique_id():
		#print("✅ Локальный игрок подобрал монету, обновляем UI...")
		#local_coins_collected += amount
		#update_coin_labels()
#
	## Сервер обновляет общий счетчик монет и удаляет монету
	#if multiplayer.is_server():
		#num_coins -= 1
		#print("🛠 Сервер уменьшает общее количество монет. Осталось:", num_coins)
#
		## Обновляем общий счетчик у всех игроков
		#update_coin_labels()
		#rpc("update_coin_count", num_coins)  
		#
		## Удаляем монету у всех клиентов
		#rpc("remove_coin", coin_node)
#
		## Удаляем монету на сервере
		#var coin = get_node_or_null(coin_node)
		#if coin:
			#coins.erase(coin)
			#coin.queue_free()

@rpc("any_peer", "reliable")
func _on_coin_picked(amount: int, player_id: int, coin_node: NodePath):
	# Только сервер обрабатывает сбор монет
	if not multiplayer.is_server():
		return

	print("📩 Монета подобрана! ID игрока:", player_id)

	# Проверяем, есть ли запись для игрока, если нет - создаем
	if not player_scores.has(player_id):
		player_scores[player_id] = 0

	# Обновляем счет игрока
	player_scores[player_id] += amount
	print("✅ Новый счет игрока", player_id, ":", player_scores[player_id])

	# Уменьшаем общий счетчик монет
	num_coins -= 1
	print("🛠 Осталось монет:", num_coins)

	# Обновляем всех клиентов
	rpc("update_player_score", player_id, player_scores[player_id])
	rpc("update_coin_count", num_coins)

	# Проверяем, все ли монеты собраны
	if num_coins == 0:
		display_message("Все монеты собраны!")
		rpc("display_message", "Все монеты собраны!")  # Сообщение всем игрокам

	# Обновляем UI на сервере
	_update_local_ui()

	# Удаляем монету у всех клиентов
	rpc("remove_coin", coin_node)

	# Удаляем монету на сервере
	var coin = get_node_or_null(coin_node)
	if coin:
		coins.erase(coin)
		coin.queue_free()

@rpc("any_peer", "reliable")
func display_message(text: String):
	print("📢", text)  # Вывод в консоль (для отладки)
	
	# Проверяем, есть ли UI элемент для отображения сообщений
	if has_node("CanvasLayer/MessageLabel"):
		var message_label = get_node("CanvasLayer/MessageLabel")
		message_label.text = text
		message_label.visible = true  # Показываем сообщение


@rpc("authority", "reliable")
func remove_coin(coin_node: NodePath):
	var coin = get_node_or_null(coin_node)
	if coin:
		coins.erase(coin)
		coin.queue_free()

func update_coin_labels():
	print("🔄 Обновление UI: Собрано монет:", local_coins_collected, "Осталось:", num_coins)
	coin_label.text = "Собрано монет: " + str(local_coins_collected)  # У каждого игрока свой счет
	coin_last.text = "Осталось монет: " + str(num_coins)  # Общий счетчик


@rpc("authority", "reliable")
func update_player_score(id: int, score: int):
	if players.has(id):
		player_scores[id] = score
		print("🔄 Счет игрока ID:", id, " → ", score)

		# Если это локальный игрок (клиент), обновляем UI
		if id == multiplayer.get_unique_id():
			_update_local_ui()




@rpc("authority", "reliable")
func update_coin_count(count: int):
	num_coins = count
	print("🔄 Обновление общего количества монет:", num_coins)

	# Гарантируем обновление UI на клиенте и сервере
	_update_local_ui()




func _update_local_ui():
	# Если сервер — обновляем UI напрямую
	if multiplayer.is_server():
		print("🔄 Обновление UI на сервере")
		var server_score = player_scores.get(multiplayer.get_unique_id(), 0)
		coin_label.text = "Собрано монет: " + str(server_score)
		coin_last.text = "Осталось монет: " + str(num_coins)

	# Если клиент — обновляем UI только для локального игрока
	elif multiplayer.get_unique_id() in player_scores:
		var client_score = player_scores[multiplayer.get_unique_id()]
		coin_label.text = "Собрано монет: " + str(client_score)
		coin_last.text = "Осталось монет: " + str(num_coins)




@onready var chat_ui = $ChatUI

@rpc("any_peer", "reliable")
func send_chat_message(player_id: int, message: String):
	if players.has(player_id):
		var player_name = players[player_id].player_name
		chat_ui.add_message(player_name, message)  # Добавляем сообщение в локальный чат только один раз

		# Проверяем, чтобы сервер не пересылал сообщение дважды
		if not multiplayer.is_server():
			return  # Если клиент уже получил сообщение, остановить

		# Если сервер, рассылаем сообщение всем клиентам
		rpc("send_chat_message", player_id, message)


func _on_message_sent(message: String):
	var player_id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		# Если это сервер, сразу обрабатываем сообщение
		send_chat_message(player_id, message)
	else:
		# Если это клиент, отправляем сообщение серверу
		rpc_id(1, "send_chat_message", player_id, message)

func _on_exit_game_pressed():
	get_tree().quit()
