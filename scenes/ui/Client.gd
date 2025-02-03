extends Node

@onready var ip_input = $CanvasLayer/VBoxContainer/EnterIP
@onready var connect_button = $CanvasLayer/VBoxContainer/ConnectToServer
@onready var name_input = $CanvasLayer/VBoxContainer/NameInput
@onready var popup = $CanvasLayer/Popup
@onready var popup_label = $CanvasLayer/Popup/Label

const BROADCAST_PORT = 54545
var udp_listener = UDPServer.new()

func _ready():
	start_listening()
	
func start_listening():
	print("🔎 Клиент слушает UDP broadcast...")
	if udp_listener.listen(BROADCAST_PORT, "0.0.0.0") != OK:
		print("⚠️ Не удалось запустить UDP сервер")
		return

	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_for_server)
	add_child(timer)

func _check_for_server():
	udp_listener.poll()
	while udp_listener.is_connection_available():
		var peer = udp_listener.take_connection()
		var packet = peer.get_packet().get_string_from_utf8()
		if packet.begins_with("GODOT_SERVER_AVAILABLE:"):
			var server_ip = packet.split(":")[1]
			ip_input.text = server_ip  # Автоматически подставляем IP в поле ввода
			print("✅ Найден сервер по адресу:", server_ip)


func _on_connect_to_server_pressed():
	pass # Replace with function body.
