extends CharacterBody2D

@export var move_speed: float = 250.0
@onready var name_label = $NameLabel # Узел для отображения имени

var player_name: String = "Player"

@rpc("any_peer")
func set_player_name(new_name: String):
	player_name = new_name
	name_label.text = new_name
	print("Установлено имя для игрока: ", player_name, " (Authority: ", get_multiplayer_authority(), ")")


@rpc("any_peer", "unreliable")
func update_state(animation: String, flip_h: bool, position: Vector2):
	# Обновляем анимацию, направление и позицию для клиентов, не являющихся владельцами
	if not is_multiplayer_authority():
		$AnimatedSprite2D.play(animation)
		$AnimatedSprite2D.flip_h = flip_h
		self.position = position

func _ready():
	name_label.text = player_name
	print("Player ready. Authority: ", get_multiplayer_authority(), " Is mine: ", is_multiplayer_authority())

func _process(delta):
	if is_multiplayer_authority(): # Только владелец управляет узлом
		var input_direction = Vector2.ZERO
		input_direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		input_direction = input_direction.normalized()

		velocity = input_direction * move_speed
		move_and_slide()

		# Управляем анимацией
		if input_direction != Vector2.ZERO:
			$AnimatedSprite2D.play("walk")
			$AnimatedSprite2D.flip_h = input_direction.x < 0
		else:
			$AnimatedSprite2D.play("idle")

		# Рассылаем состояние другим клиентам
		rpc("update_state", $AnimatedSprite2D.animation, $AnimatedSprite2D.flip_h, position)
