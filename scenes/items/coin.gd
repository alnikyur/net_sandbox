extends Area2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var coin_pickup_sound = $CoinPickupSound

var collected: bool = false

signal coin_picked(amount: int, player_id: int, coin_node: NodePath)



# Called when the node enters the scene tree for the first time.
func _ready():
	animated_sprite_2d.play("coin_spin")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_body_entered(body):
	if body.is_in_group("Player") and not collected:
		collected = true
		coin_picked.emit(1, body.get_multiplayer_authority(), get_path())
		
		# Запускаем звук
		coin_pickup_sound.play()

		# Отключаем коллизии, чтобы игрок не мог снова взаимодействовать
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)

		# Скрываем монету, но не удаляем сразу
		animated_sprite_2d.visible = false

		# Ждем завершения звука перед удалением
		await coin_pickup_sound.finished
		queue_free()

