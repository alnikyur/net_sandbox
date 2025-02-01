extends CharacterBody2D

@export var move_speed: float = 200.0
@onready var name_label = $NameLabel

var player_name: String = "Player"
var is_rolling = false

@export var player_id: int
@onready var coin_label = $CanvasLayer/CoinLabel

var coins_collected: int = 0

@rpc("any_peer")
func set_player_name(new_name: String):
	if player_name == new_name:
		return
	player_name = new_name
	name_label.text = new_name
	print("set_player_name вызван. Новое имя:", new_name, " (Authority: ", get_multiplayer_authority(), ")")

@rpc("any_peer", "unreliable")
func update_state(animation: String, flip_h: bool, position: Vector2):
	if not is_multiplayer_authority():
		$AnimatedSprite2D.play(animation)
		$AnimatedSprite2D.flip_h = flip_h
		self.position = position

func _ready():
	if player_name != "Player":
		name_label.text = player_name
	print("Player ready. Authority: ", get_multiplayer_authority(), " Is mine: ", is_multiplayer_authority())

	if is_multiplayer_authority():
		$Camera2D.make_current()
		print("Камера активирована для локального игрока.")

func _process(delta):
	if is_multiplayer_authority():
		if is_rolling:
			return

		var input_direction = Vector2.ZERO
		input_direction.x += Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_direction.y += Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		input_direction.x += Input.get_action_strength("D") - Input.get_action_strength("A")
		input_direction.y += Input.get_action_strength("S") - Input.get_action_strength("W")
		input_direction = input_direction.normalized()

		if Input.is_action_just_pressed("ui_accept"):
			roll()
			return

		velocity = input_direction * move_speed
		move_and_slide()

		# Управляем анимацией
		if input_direction != Vector2.ZERO:
			$AnimatedSprite2D.play("walk")
			# Меняем flip_h только при движении влево или вправо
			if input_direction.x != 0:
				$AnimatedSprite2D.flip_h = input_direction.x < 0
		else:
			$AnimatedSprite2D.play("idle")

		# Рассылаем состояние другим клиентам
		rpc("update_state", $AnimatedSprite2D.animation, $AnimatedSprite2D.flip_h, position)

func roll():
	if is_rolling:
		return  # Если уже в перекате, не запускаем второй раз

	is_rolling = true  # Блокируем управление
	var roll_direction = velocity.normalized()  # Используем текущее направление

	if roll_direction == Vector2.ZERO:
		roll_direction = Vector2.RIGHT if not $AnimatedSprite2D.flip_h else Vector2.LEFT  # Если стоим - катимся вправо/влево

	$AnimatedSprite2D.play("roll")  # Запускаем анимацию

	# Ускоряем персонажа на время переката
	var roll_speed = move_speed * 1.5  # Можно настроить множитель скорости
	var roll_time = 0.5  # Длительность переката (сек)

	var timer = Timer.new()
	timer.wait_time = roll_time
	timer.one_shot = true
	add_child(timer)
	timer.start()

	# Двигаем персонажа во время переката
	while timer.time_left > 0:
		velocity = roll_direction * roll_speed
		move_and_slide()
		await get_tree().process_frame  # Ждем один кадр

	# После завершения таймера возвращаем управление
	is_rolling = false
	timer.queue_free()

func collect_coin(amount: int):
	coins_collected += amount
	print("✅ Игрок", player_id, "подобрал монету! Счетчик:", coins_collected)
	update_coin_label()

func update_coin_label():
	if coin_label:
		coin_label.text = "Собрано монет: " + str(coins_collected)
