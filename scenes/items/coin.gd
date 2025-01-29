extends Area2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var coin_pickup_sound = $CoinPickupSound

var collected: bool = false

signal coin_picked(amount: int)


# Called when the node enters the scene tree for the first time.
func _ready():
	animated_sprite_2d.play("coin_spin")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_body_entered(body):
	if body.is_in_group("Player") and not collected:
		collected = true # Устанавливаем флаг, чтобы предотвратить повторный сбор
		emit_signal("coin_picked", 1) # Отправляем сигнал
		coin_pickup_sound.play()
		
		# Отключаем коллизию, чтобы игрок не мог снова взаимодействовать
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		animated_sprite_2d.visible = false
		
		# Ожидаем завершения звука, но не даём повторно подбирать монету
		await coin_pickup_sound.finished
		queue_free()

		
