extends Node

@onready var online := true

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
#@onready var hud = $CanvasLayer/HUD
#@onready var health_bar = $CanvasLayer/HUD/HealthBar

@onready var environment = $Environment3
@onready var spawn_points = $Environment3/Spawn_Points

@onready var weapon_folder = $Weapons
@onready var server_weapon_folder = $ServerWeapons
@onready var body_folder = $Bodies
@onready var weapon_spawn_timer = $WeaponSpawnTimer

signal server_spawn_weapon()

#var rifle_scene = preload("res://Spawnable Weapons/rifle_spawn.tscn")
var text_to_show: String
var address = "127.0.0.1"
#const Player = preload("res://Scenes/player.tscn")
const Player = preload("res://Scenes/player_2.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	main_menu.hide()
	#hud.show()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	
	if online:
		upnp_setup()

func _on_join_button_pressed():
	main_menu.hide()
	#hud.show()
	
	if not (address_entry.text == null or address_entry.text == ""):
		address = address_entry.text
	enet_peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	
	if player.name == "1":
		server_spawn_weapon.connect(player.weapon_manager.server_spawn_weapon)
	
	if player.is_multiplayer_authority():
		#connect_signals(player)
		#print($CanvasLayer/MainMenu/MarginContainer/VBoxContainer/OptionButton.selected)
		player.rpc("set_gamertag", $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/Gamertag.text)
		player.rpc("set_skin", $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/OptionButton.selected)
		player.set_skin_transparent()
		await get_tree().create_timer(.1).timeout
		player.show_text.call_deferred(text_to_show)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

#s

#func update_scope(scoping):
	#$CanvasLayer/HUD/CrosshairsCircle.visible = scoping

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		#connect_signals(node)
		#print($CanvasLayer/MainMenu/MarginContainer/VBoxContainer/OptionButton.selected)
		node.rpc("set_gamertag", $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/Gamertag.text)
		node.rpc("set_skin", $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/OptionButton.selected)
		node.set_skin_transparent()

#func connect_signals(node: Node):
	#node.health_changed.connect(update_health_bar)
	#node.scope_changed.connect(update_scope)
	#node.weapon_changed.connect(weapon_changed)
	#node.ammo_changed.connect(ammo_changed)
	#node.reserve_changed.connect(reserve_changed)

#func _process(delta: float) -> void:
	#if weapon_folder.get_child_count() == 0:
		#rpc("spawn_rifle", randi_range(0, 1), randi_range(0, 1))

#@rpc("call_local")
#func spawn_rifle(rand1, rand2):
	#if !is_multiplayer_authority(): return
	#var rifle = rifle_scene.instantiate()
	#weapon_folder.add_child(rifle)
	#rifle.global_position = Vector3(rand1 * 25, 0, rand2 * 25)

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover(2000, 2, "")
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		push_warning("UPNP Discover Failed! Error: %s" % discover_result)
		text_to_show = str("UPNP Discover Failed! Error: %s" % discover_result)
		return

	var gateway = upnp.get_gateway()
	if not gateway or not gateway.is_valid_gateway():
		push_warning("UPNP Invalid Gateway!")
		text_to_show = "UPNP Invalid Gateway!"
		return
	
	var map_result = upnp.add_port_mapping(PORT)
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		push_warning("UPNP Port Mapping Failed! Error: %s" % map_result)
		push_warning("UPNP Port Mapping Failed! Defaulting to LAN mode.")
		text_to_show = "UPNP Port Mapping Failed! Defaulting to LAN mode."
		online = false
		return

	var external_ip = upnp.query_external_address()
	print("UPNP Setup Success! Join Address: %s" % external_ip)
	text_to_show = str(external_ip)

func _on_weapon_spawn_timer_timeout() -> void:
	#print("this many children: " + str(server_weapon_folder.get_child_count()))
	if server_weapon_folder.get_child_count() <= 1:
		emit_signal("server_spawn_weapon")
		#print("emiting server weapon spawn signal")


func _on_server_weapons_child_exiting_tree(_node: Node) -> void:
	#print("child exiting tree")
	#print("this many children: " + str(server_weapon_folder.get_child_count()))
	if server_weapon_folder.get_child_count() <= 1:
		#print("no childrend")
		#_on_weapon_spawn_timer_timeout()
		weapon_spawn_timer.start()
