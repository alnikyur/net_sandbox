extends Control

@onready var ip_input = $VBoxContainer/EnterIP
@onready var start_server_button = $VBoxContainer/RunServer
@onready var connect_button = $VBoxContainer/ConnectToServer
@onready var name_input = $VBoxContainer/NameInput

func _on_run_server_pressed():
	var player_name = name_input.text.strip_edges()
	#if player_name.empty():
		#print("Введите имя!")
		#return

	Global.player_name = player_name
	Global.is_server = true # Установим глобальную переменную для сервера
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _on_connect_to_server_pressed():
	var ip = ip_input.text.strip_edges()
	var player_name = name_input.text.strip_edges()
	#if ip.empty():
		#print("Введите IP-адрес!")
		#return
	#if player_name.empty():
		#print("Введите имя!")
		#return

	Global.server_ip = ip
	Global.player_name = player_name
	Global.is_server = false # Установим глобальную переменную для клиента
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
