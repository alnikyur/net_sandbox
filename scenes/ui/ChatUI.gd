extends CanvasLayer

@onready var chat_label = $VBoxContainer/ChatLabel
@onready var chat_input = $VBoxContainer/ChatInput
@onready var send_button = $VBoxContainer/SendButton

signal message_sent(message: String)

func _ready():
	send_button.pressed.connect(_on_send_button_pressed)

func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if chat_input.has_focus():  # Проверяем, активен ли чат
			_on_send_button_pressed()
			get_viewport().set_input_as_handled()  # Предотвращаем дублирование ввода

func add_message(player_name: String, message: String):
	chat_label.text += player_name + ": " + message + "\n"

	# Ограничиваем количество строк в UI, чтобы чат не "уходил"
	var max_lines = 10
	var lines = chat_label.text.split("\n")
	if lines.size() > max_lines:
		chat_label.text = "\n".join(lines.slice(lines.size() - max_lines, lines.size()))


func _on_send_button_pressed():
	var text = chat_input.text.strip_edges()
	if text != "":
		emit_signal("message_sent", text)
		chat_input.text = ""  # Очистка после отправки
