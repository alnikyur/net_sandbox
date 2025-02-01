extends Area2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var coin_pickup_sound = $CoinPickupSound

var collected: bool = false

signal coin_picked(amount: int, player_id: int, coin_node: NodePath)

func _ready():
	animated_sprite_2d.play("coin_spin")

func _on_body_entered(body):
	if body.is_in_group("Player") and not collected:
		collected = true
		var player_id = body.get_multiplayer_authority()
		coin_picked.emit(1, player_id, get_path())

		# ✅ Локально воспроизводим звук, даже если сервер один
		play_coin_sound()

		# ✅ Если сервер - отправляем RPC клиентам (если они есть)
		if multiplayer.is_server():
			rpc("play_coin_sound")

		# Отключаем коллизии
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)

		# Скрываем монету
		animated_sprite_2d.visible = false

		# Ждем завершения звука перед удалением
		await coin_pickup_sound.finished
		queue_free()

@rpc("any_peer", "reliable")
func play_coin_sound():
	if coin_pickup_sound and coin_pickup_sound.stream:
		print("🔊 Воспроизведение звука подбора монеты")
		coin_pickup_sound.play()
	else:
		print("⚠ Ошибка: У CoinPickupSound нет аудиофайла!")
