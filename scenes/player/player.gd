extends CharacterBody2D

@export var move_speed: float = 250.0
@onready var name_label = $NameLabel # Узел для отображения имени

var player_name: String = "Player"

@export var player_id: int
@onready var coin_label = $CanvasLayer/CoinLabel

var coins_collected: int = 0  # Личный счетчик монет

@rpc("any_peer")
func set_player_name(new_name: String):
	if player_name == new_name:
		return # Если имя не изменилось, ничего не делаем
	player_name = new_name
	name_label.text = new_name
	print("set_player_name вызван. Новое имя:", new_name, " (Authority: ", get_multiplayer_authority(), ")")

@rpc("any_peer", "unreliable")
func update_state(animation: String, flip_h: bool, position: Vector2):
	# Обновляем анимацию, направление и позицию для клиентов, не являющихся владельцами
	if not is_multiplayer_authority():
		$AnimatedSprite2D.play(animation)
		$AnimatedSprite2D.flip_h = flip_h
		self.position = position

func _ready():
	if player_name != "Player":
		name_label.text = player_name
	print("Player ready. Authority: ", get_multiplayer_authority(), " Is mine: ", is_multiplayer_authority())

	# Активируем камеру только для локального игрока
	if is_multiplayer_authority():
		$Camera2D.make_current()
		print("Камера активирована для локального игрока.")

func _process(delta):
	if is_multiplayer_authority(): # Только владелец управляет узлом
		var input_direction = Vector2.ZERO
		input_direction.x += Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_direction.y += Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		input_direction.x += Input.get_action_strength("D") - Input.get_action_strength("A")
		input_direction.y += Input.get_action_strength("S") - Input.get_action_strength("W")
		input_direction = input_direction.normalized()

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


func collect_coin(amount: int):
	coins_collected += amount
	print("✅ Игрок", player_id, "подобрал монету! Счетчик:", coins_collected)
	update_coin_label()

func update_coin_label():
	if coin_label:
		coin_label.text = "Собрано монет: " + str(coins_collected)
