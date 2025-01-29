extends Control

@onready var ip_input = $VBoxContainer/EnterIP
@onready var start_server_button = $VBoxContainer/RunServer
@onready var connect_button = $VBoxContainer/ConnectToServer
@onready var name_input = $VBoxContainer/NameInput
@onready var popup = $Popup
@onready var popup_label = $Popup/Label



func show_popup_message(text: String, position: Vector2):
	popup_label.text = text
	popup.position = position
	popup.popup()
	

func _on_run_server_pressed():
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		print("Введите имя!")
		show_popup_message("Enter player name!", Vector2(800, 300))
		return

	Global.player_name = player_name
	Global.is_server = true # Установим глобальную переменную для сервера
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _on_connect_to_server_pressed():
	var ip = ip_input.text.strip_edges()
	var player_name = name_input.text.strip_edges()
	if ip.is_empty():
		print("Введите IP-адрес!")
		show_popup_message("Enter IP-address!", Vector2(800, 300))
		return
	if player_name.is_empty():
		print("Введите имя!")
		show_popup_message("Enter player name!", Vector2(800, 300))
		return

	Global.server_ip = ip
	Global.player_name = player_name
	Global.is_server = false # Установим глобальную переменную для клиента
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _on_exit_pressed():
	get_tree().quit()
