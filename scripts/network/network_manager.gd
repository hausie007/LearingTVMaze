extends Node

const MissionCatalog := preload("res://scripts/mission_catalog.gd")

signal host_discovered(info: Dictionary)
signal discovery_updated(hosts: Array)
signal lobby_updated(state: Dictionary)
signal join_accepted(peer_id: int, state: Dictionary)
signal join_rejected(reason: String)
signal game_started(session: Dictionary)
signal peer_disconnected(peer_id: int)
signal input_received(peer_id: int, direction: Vector2i, pressed: bool)
signal debug_status_changed(scope: String, message: String)
signal chaser_countdown_updated(remaining: int)
signal chaser_released()
signal remote_goal_updated(goal_text: String)

const APP_ID := "learning_maze"
const PROTOCOL_VERSION := 1
const HOST_PEER_ID := 1

const GAME_PORT := 42020
const DISCOVERY_PORT := 42021
const DISCOVERY_BROADCAST_IP := "255.255.255.255"
const DISCOVERY_INTERVAL_SEC := 0.75
const HOST_TTL_SEC := 15.0
const HOST_BIND_IP := "0.0.0.0"

const STYLE_PATH := "path"
const STYLE_NEXT_SYMBOL := "next_symbol"
const STYLE_RACE := "race"

const TRAINING_NONE := "none"
const TRAINING_NUMBERS := "numbers"
const TRAINING_LETTERS := "letters"
const TRAINING_WORDS := "words"

const MISSION_FIND_EXIT := "find_exit"
const MISSION_FOLLOW_TRAIL := "follow_trail"
const MISSION_FIND_NEXT := "find_next"
const MISSION_RACE_MIDDLE := "race_middle"

const ROLE_COLLECTOR := "collector"
const ROLE_CHASER := "chaser"
const ROLE_RACER := "racer"

var host_config: Dictionary = {}
var players: Dictionary = {}
var current_session: Dictionary = {}

var _peer: ENetMultiplayerPeer = null
var _broadcast_socket: PacketPeerUDP = null
var _listen_socket: PacketPeerUDP = null
var _broadcast_timer: Timer = null

var _pending_join_character_id: String = ""
var _pending_host_ip: String = ""
var _pending_host_port: int = GAME_PORT
var _pending_host_info: Dictionary = {}

var _discovered_hosts: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_broadcast_timer = Timer.new()
	_broadcast_timer.wait_time = DISCOVERY_INTERVAL_SEC
	_broadcast_timer.one_shot = false
	_broadcast_timer.timeout.connect(_broadcast_presence)
	add_child(_broadcast_timer)

	set_process(true)

func _process(_delta: float) -> void:
	_poll_discovery_socket()
	_prune_stale_hosts()

func configure_host(config: Dictionary) -> void:
	host_config = config.duplicate(true)
	_normalize_host_config()
	_emit_debug("host", "Config updated")

func start_host() -> int:
	var saved_config := host_config.duplicate(true)
	leave_session()
	host_config = saved_config

	var max_players: int = clampi(int(host_config.get("max_players", 2)), 2, 4)
	var max_clients: int = max(1, max_players - 1)

	_peer = ENetMultiplayerPeer.new()
	_peer.set_bind_ip(HOST_BIND_IP)
	var err := _peer.create_server(GAME_PORT, max_clients)
	if err != OK:
		_peer = null
		_emit_debug("host", "Host start failed (%d)" % err)
		return err

	multiplayer.multiplayer_peer = _peer
	_emit_debug("host", "Listening on ENet %s:%d" % [HOST_BIND_IP, GAME_PORT])
	print("Learning Maze host listening on ENet %s:%d and discovery UDP %d" % [HOST_BIND_IP, GAME_PORT, DISCOVERY_PORT])

	var host_id: int = multiplayer.get_unique_id()
	players.clear()
	players[host_id] = {
		"peer_id": host_id,
		"character_id": String(host_config.get("character_id", "")),
		"is_host": true,
		"role": ROLE_COLLECTOR,
	}
	_recalculate_roles()

	current_session.clear()
	_start_broadcasting()
	_emit_lobby_snapshot_local()
	return OK

func stop_host() -> void:
	if multiplayer.is_server():
		leave_session()

func start_now() -> void:
	if multiplayer.is_server():
		_start_game()

func set_collector_peer_id(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not players.has(peer_id):
		return

	host_config["collector_peer_id"] = peer_id
	_recalculate_roles()
	_sync_lobby_to_clients()

func randomize_collector() -> void:
	if not multiplayer.is_server():
		return
	var peer_ids := _ordered_player_peer_ids()
	if peer_ids.is_empty():
		return

	var idx := randi() % peer_ids.size()
	host_config["collector_peer_id"] = peer_ids[idx]
	_recalculate_roles()
	_sync_lobby_to_clients()

func set_rotate_roles_after_round(enabled: bool) -> void:
	if not multiplayer.is_server():
		return
	host_config["rotate_roles_after_round"] = enabled
	_sync_lobby_to_clients()

func swap_collector_with_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not players.has(peer_id):
		return
	_normalize_host_config()
	if not bool(host_config.get("chaser_enabled", false)):
		return
	if String(host_config.get("game_style", STYLE_PATH)) == STYLE_RACE:
		return

	host_config["collector_peer_id"] = peer_id
	_recalculate_roles()
	if not current_session.is_empty():
		current_session["config"] = host_config.duplicate(true)
		current_session["players"] = players.duplicate(true)
		current_session["roles"] = _roles_by_peer()
	_sync_lobby_to_clients()

func start_discovery() -> int:
	stop_discovery()
	_discovered_hosts.clear()
	_emit_discovery_updated()

	_listen_socket = PacketPeerUDP.new()
	var err := _listen_socket.bind(DISCOVERY_PORT, "0.0.0.0")
	if err != OK:
		_listen_socket = null
		_emit_debug("join", "Discovery bind failed (%d)" % err)
		return err
	_emit_debug("join", "Scanning on UDP %d" % DISCOVERY_PORT)

	return OK

func stop_discovery() -> void:
	if _listen_socket != null:
		_listen_socket.close()
		_listen_socket = null

	if not _discovered_hosts.is_empty():
		_discovered_hosts.clear()
		_emit_discovery_updated()

func join_host(host_ip: String, host_port: int, character_id: String) -> int:
	leave_session()

	_pending_host_ip = host_ip
	_pending_host_port = host_port
	_pending_join_character_id = character_id

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host_ip, host_port)
	if err != OK:
		_peer = null
		_emit_debug("join", "Connect create failed (%d)" % err)
		return err

	multiplayer.multiplayer_peer = _peer
	_emit_debug("join", "Connecting to %s:%d" % [host_ip, host_port])
	return OK

func set_pending_join_host(host_info: Dictionary) -> void:
	_pending_host_info = host_info.duplicate(true)

func consume_pending_join_host() -> Dictionary:
	var host := _pending_host_info.duplicate(true)
	_pending_host_info.clear()
	return host

func leave_session() -> void:
	_stop_broadcasting()
	stop_discovery()

	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_peer = null
	host_config.clear()
	players.clear()
	current_session.clear()
	_pending_join_character_id = ""
	_pending_host_ip = ""
	_pending_host_port = GAME_PORT
	_pending_host_info.clear()
	_emit_debug("net", "Session cleared")

func send_dpad(direction: Vector2i, pressed: bool) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if not _is_valid_direction(direction):
		return

	if multiplayer.is_server():
		input_received.emit(multiplayer.get_unique_id(), direction, pressed)
		return

	rpc_id(HOST_PEER_ID, "rpc_dpad_input", direction, pressed)

func get_discovered_hosts() -> Array:
	var hosts: Array = []
	for value in _discovered_hosts.values():
		hosts.append((value as Dictionary).get("info", {}))
	return hosts

func _start_broadcasting() -> void:
	if _broadcast_socket != null:
		return

	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)
	_broadcast_socket.set_dest_address(DISCOVERY_BROADCAST_IP, DISCOVERY_PORT)
	_broadcast_timer.start()
	_broadcast_presence()
	_emit_debug("host", "Broadcasting discovery on UDP %d" % DISCOVERY_PORT)

func _stop_broadcasting() -> void:
	_broadcast_timer.stop()
	if _broadcast_socket != null:
		_broadcast_socket.close()
		_broadcast_socket = null
		_emit_debug("host", "Broadcast stopped")

func _broadcast_presence() -> void:
	if not multiplayer.is_server():
		return
	if _broadcast_socket == null:
		return

	var payload := _build_discovery_payload()
	var packet := JSON.stringify(payload).to_utf8_buffer()
	_broadcast_socket.put_packet(packet)
	print("Learning Maze discovery broadcast -> %s:%d" % [DISCOVERY_BROADCAST_IP, DISCOVERY_PORT])

func _build_discovery_payload() -> Dictionary:
	var max_players: int = clampi(int(host_config.get("max_players", 2)), 2, 4)
	return {
		"app": APP_ID,
		"version": PROTOCOL_VERSION,
		"host_name": "Learning Maze Host",
		"port": GAME_PORT,
		"theme_dir": String(host_config.get("theme_dir", "default")),
		"theme_title": String(host_config.get("theme_title", host_config.get("theme_dir", "default"))),
		"mission_id": String(host_config.get("mission_id", MISSION_FOLLOW_TRAIL)),
		"mission_title": String(host_config.get("mission_title", "Follow the Trail")),
		"mission_goal_key": String(host_config.get("mission_goal_key", "")),
		"role_summary_key": String(host_config.get("role_summary_key", MissionCatalog.role_summary_key(
			String(host_config.get("mission_id", MISSION_FOLLOW_TRAIL)),
			bool(host_config.get("chaser_enabled", false))
		))),
		"game_style": String(host_config.get("game_style", STYLE_PATH)),
		"game_style_title": String(host_config.get("game_style_title", "Path")),
		"training_type": String(host_config.get("training_type", TRAINING_WORDS)),
		"training_type_title": String(host_config.get("training_type_title", "Words")),
		"chaser_enabled": bool(host_config.get("chaser_enabled", false)),
		"difficulty": int(host_config.get("difficulty", 1)),
		"difficulty_key": String(host_config.get("difficulty_key", "diff_easy")),
		"max_players": max_players,
		"player_count": players.size(),
		"character_id": String(host_config.get("character_id", "")),
		"taken_characters": _taken_characters(),
	}

func _poll_discovery_socket() -> void:
	if _listen_socket == null:
		return

	var changed := false
	while _listen_socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = _listen_socket.get_packet()
		var text := packet.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Dictionary):
			continue

		var info := (parsed as Dictionary).duplicate(true)
		if String(info.get("app", "")) != APP_ID:
			continue
		if int(info.get("version", -1)) != PROTOCOL_VERSION:
			continue

		var ip := _listen_socket.get_packet_ip()
		var port := int(info.get("port", GAME_PORT))
		info["ip"] = ip
		info["port"] = port

		var key := "%s:%d" % [ip, port]
		var now_sec := _now_sec()
		var was_known := _discovered_hosts.has(key)
		var old_signature := ""
		if was_known:
			old_signature = String((_discovered_hosts[key] as Dictionary).get("signature", ""))
		var signature := _host_signature(info)

		_discovered_hosts[key] = {
			"info": info,
			"last_seen": now_sec,
			"signature": signature,
		}

		if not was_known:
			host_discovered.emit(info)
			_emit_debug("join", "Found host %s (%s:%d)" % [String(info.get("host_name", "Host")), ip, port])
			changed = true
		elif old_signature != signature:
			changed = true

	if changed:
		_emit_discovery_updated()

func _prune_stale_hosts() -> void:
	if _discovered_hosts.is_empty():
		return

	var now_sec := _now_sec()
	var changed := false
	for key in _discovered_hosts.keys():
		var item := _discovered_hosts[key] as Dictionary
		var last_seen: float = float(item.get("last_seen", 0.0))
		if now_sec - last_seen > HOST_TTL_SEC:
			_discovered_hosts.erase(key)
			changed = true

	if changed:
		_emit_discovery_updated()

func _emit_discovery_updated() -> void:
	var hosts: Array = []
	for item in _discovered_hosts.values():
		hosts.append((item as Dictionary).get("info", {}))

	hosts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var an := "%s %s" % [String(a.get("host_name", "")), String(a.get("ip", ""))]
		var bn := "%s %s" % [String(b.get("host_name", "")), String(b.get("ip", ""))]
		return an < bn
	)

	discovery_updated.emit(hosts)

func _emit_lobby_snapshot_local() -> void:
	lobby_updated.emit(_build_lobby_state())

func _sync_lobby_to_clients() -> void:
	if not multiplayer.is_server():
		return

	var state := _build_lobby_state()
	rpc("rpc_lobby_snapshot", state)
	lobby_updated.emit(state)
	_broadcast_presence()

func _build_lobby_state() -> Dictionary:
	if multiplayer.is_server():
		_recalculate_roles()
	return {
		"config": host_config.duplicate(true),
		"players": players.duplicate(true),
	}

func _build_session_data() -> Dictionary:
	_recalculate_roles()
	var ordered_peers: Array[int] = []
	for key in players.keys():
		ordered_peers.append(int(key))
	ordered_peers.sort()

	if ordered_peers.has(HOST_PEER_ID):
		ordered_peers.erase(HOST_PEER_ID)
		ordered_peers.push_front(HOST_PEER_ID)

	var spawn_slots: Dictionary = {}
	for i in range(min(ordered_peers.size(), 4)):
		spawn_slots[ordered_peers[i]] = i

	return {
		"config": host_config.duplicate(true),
		"players": players.duplicate(true),
		"roles": _roles_by_peer(),
		"spawn_slots": spawn_slots,
		"ordered_peers": ordered_peers,
	}

func _start_game() -> void:
	if not multiplayer.is_server():
		return
	if not current_session.is_empty():
		return
	_normalize_host_config()
	if players.size() < _minimum_players_for_host_config():
		_emit_debug("host", "Waiting for players")
		_emit_lobby_snapshot_local()
		return

	current_session = _build_session_data()
	rpc("rpc_game_start", current_session)
	game_started.emit(current_session)
	_stop_broadcasting()

func _check_auto_start() -> void:
	if not multiplayer.is_server():
		return

	var max_players: int = clampi(int(host_config.get("max_players", 2)), 2, 4)
	if players.size() >= max_players:
		_start_game()

func _is_character_taken(character_id: String) -> bool:
	for info in players.values():
		var data := info as Dictionary
		if String(data.get("character_id", "")) == character_id:
			return true
	return false

func _minimum_players_for_host_config() -> int:
	return 2

func _normalize_host_config() -> void:
	if not host_config.has("game_style"):
		host_config["game_style"] = STYLE_PATH
	if not host_config.has("game_style_title"):
		host_config["game_style_title"] = "Path"
	if not host_config.has("mission_id"):
		host_config["mission_id"] = MissionCatalog.mission_from_config(
			String(host_config.get("game_style", STYLE_PATH)),
			String(host_config.get("training_type", TRAINING_WORDS))
		)
	var mission_id := String(host_config.get("mission_id", MISSION_FOLLOW_TRAIL))
	if not MissionCatalog.mission_ids().has(mission_id):
		mission_id = MissionCatalog.mission_from_config(
			String(host_config.get("game_style", STYLE_PATH)),
			String(host_config.get("training_type", TRAINING_WORDS))
		)
	host_config["mission_id"] = mission_id
	host_config["game_style"] = MissionCatalog.style_for_mission(mission_id)
	if not host_config.has("mission_title"):
		host_config["mission_title"] = tr(MissionCatalog.mission_title_key(mission_id))
	host_config["game_style_title"] = String(host_config.get("mission_title", tr(MissionCatalog.mission_title_key(mission_id))))
	if not host_config.has("training_type"):
		host_config["training_type"] = TRAINING_WORDS
	var pickup_id := MissionCatalog.pickup_for_training(String(host_config.get("training_type", TRAINING_WORDS)))
	var allowed_pickups := MissionCatalog.allowed_pickups(mission_id)
	if not allowed_pickups.has(pickup_id):
		pickup_id = MissionCatalog.default_pickup(mission_id)
	host_config["training_type"] = MissionCatalog.training_for_pickup(pickup_id)
	host_config["training_type_title"] = tr(MissionCatalog.pickup_title_key(pickup_id))
	if not host_config.has("chaser_enabled"):
		host_config["chaser_enabled"] = false
	if not host_config.has("rotate_roles_after_round"):
		host_config["rotate_roles_after_round"] = false
	if MissionCatalog.chaser_required(mission_id, true):
		host_config["chaser_enabled"] = true
	if MissionCatalog.chaser_forced_off(mission_id) or String(host_config.get("game_style", STYLE_PATH)) == STYLE_RACE:
		host_config["chaser_enabled"] = false
	var player_options := MissionCatalog.max_players_options(mission_id, bool(host_config.get("chaser_enabled", false)))
	var max_players := int(host_config.get("max_players", player_options[0]))
	if not player_options.has(max_players):
		max_players = int(player_options[0])
	host_config["max_players"] = max_players

func _ordered_player_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for key in players.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	if peer_ids.has(HOST_PEER_ID):
		peer_ids.erase(HOST_PEER_ID)
		peer_ids.push_front(HOST_PEER_ID)
	return peer_ids

func _recalculate_roles() -> void:
	_normalize_host_config()
	if players.is_empty():
		return

	var chaser_enabled := bool(host_config.get("chaser_enabled", false))
	var game_style := String(host_config.get("game_style", STYLE_PATH))
	var default_role := ROLE_RACER if game_style == STYLE_RACE else ROLE_COLLECTOR

	if game_style == STYLE_RACE:
		for key in players.keys():
			var info := players[key] as Dictionary
			info["role"] = ROLE_RACER
			players[key] = info
		host_config["chaser_enabled"] = false
		host_config.erase("collector_peer_id")
		return

	if not chaser_enabled:
		for key in players.keys():
			var info := players[key] as Dictionary
			info["role"] = default_role
			players[key] = info
		host_config.erase("collector_peer_id")
		return

	var peer_ids := _ordered_player_peer_ids()
	var collector_peer_id := int(host_config.get("collector_peer_id", 0))
	if not peer_ids.has(collector_peer_id):
		collector_peer_id = peer_ids[randi() % peer_ids.size()]
		host_config["collector_peer_id"] = collector_peer_id

	for key in players.keys():
		var peer_id := int(key)
		var info := players[key] as Dictionary
		info["role"] = ROLE_COLLECTOR if peer_id == collector_peer_id else ROLE_CHASER
		players[key] = info

func _roles_by_peer() -> Dictionary:
	var result := {}
	for key in players.keys():
		var info := players[key] as Dictionary
		result[int(key)] = String(info.get("role", ROLE_COLLECTOR))
	return result

func _taken_characters() -> Array[String]:
	var result: Array[String] = []
	for info in players.values():
		var data := info as Dictionary
		result.append(String(data.get("character_id", "")))
	return result

func _is_valid_direction(direction: Vector2i) -> bool:
	return direction == Vector2i.UP or direction == Vector2i.DOWN or direction == Vector2i.LEFT or direction == Vector2i.RIGHT

func _now_sec() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _on_peer_connected(_peer_id: int) -> void:
	pass

func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	if multiplayer.is_server() and players.has(peer_id):
		players.erase(peer_id)
		_sync_lobby_to_clients()

func _on_connected_to_server() -> void:
	if _pending_join_character_id.is_empty():
		join_rejected.emit("Character not selected")
		leave_session()
		return

	_emit_debug("join", "Connected, requesting join")
	rpc_id(HOST_PEER_ID, "rpc_request_join", _pending_join_character_id)

func _on_connection_failed() -> void:
	join_rejected.emit("Host unavailable")
	_emit_debug("join", "Connection failed")
	leave_session()

func _on_server_disconnected() -> void:
	join_rejected.emit("Host unavailable")
	_emit_debug("join", "Server disconnected")
	leave_session()

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_join(character_id: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not current_session.is_empty():
		rpc_id(sender_id, "rpc_join_rejected", "Game already started")
		return

	if character_id.is_empty():
		rpc_id(sender_id, "rpc_join_rejected", "Character not selected")
		return

	var max_players: int = clampi(int(host_config.get("max_players", 2)), 2, 4)
	if players.size() >= max_players:
		rpc_id(sender_id, "rpc_join_rejected", "Lobby is full")
		return

	if _is_character_taken(character_id):
		rpc_id(sender_id, "rpc_join_rejected", "Character is already taken")
		return

	players[sender_id] = {
		"peer_id": sender_id,
		"character_id": character_id,
		"is_host": false,
		"role": ROLE_COLLECTOR,
	}
	_recalculate_roles()

	var state := _build_lobby_state()
	rpc_id(sender_id, "rpc_join_accepted", sender_id, state)
	_sync_lobby_to_clients()
	_emit_debug("host", "Peer %d joined" % sender_id)

@rpc("authority", "call_remote", "reliable")
func rpc_join_accepted(peer_id: int, state: Dictionary) -> void:
	host_config = (state.get("config", {}) as Dictionary).duplicate(true)
	players = (state.get("players", {}) as Dictionary).duplicate(true)
	join_accepted.emit(peer_id, state)
	lobby_updated.emit(state)
	_emit_debug("join", "Join accepted as peer %d" % peer_id)

@rpc("authority", "call_remote", "reliable")
func rpc_join_rejected(reason: String) -> void:
	join_rejected.emit(reason)
	_emit_debug("join", "Join rejected: %s" % reason)
	leave_session()

@rpc("authority", "call_remote", "reliable")
func rpc_lobby_snapshot(state: Dictionary) -> void:
	host_config = (state.get("config", {}) as Dictionary).duplicate(true)
	players = (state.get("players", {}) as Dictionary).duplicate(true)
	lobby_updated.emit(state)
	_emit_debug("join", "Lobby snapshot received (%d players)" % players.size())

@rpc("authority", "call_remote", "reliable")
func rpc_game_start(session: Dictionary) -> void:
	current_session = session.duplicate(true)
	game_started.emit(current_session)
	_emit_debug("net", "Game started")

@rpc("any_peer", "call_remote", "unreliable")
func rpc_dpad_input(direction: Vector2i, pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	if not _is_valid_direction(direction):
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not players.has(sender_id):
		return

	input_received.emit(sender_id, direction, pressed)

@rpc("authority", "call_remote", "reliable")
func rpc_chaser_countdown(remaining: int) -> void:
	chaser_countdown_updated.emit(remaining)

@rpc("authority", "call_remote", "reliable")
func rpc_chaser_released() -> void:
	chaser_released.emit()

func _emit_debug(scope: String, message: String) -> void:
	debug_status_changed.emit(scope, message)

func _host_signature(info: Dictionary) -> String:
	var taken_characters: Array = []
	var raw_taken: Variant = info.get("taken_characters", [])
	if raw_taken is Array:
		taken_characters = (raw_taken as Array).duplicate(true)

	var normalized := {
		"app": String(info.get("app", "")),
		"version": int(info.get("version", 0)),
		"host_name": String(info.get("host_name", "")),
		"port": int(info.get("port", GAME_PORT)),
		"theme_dir": String(info.get("theme_dir", "")),
		"theme_title": String(info.get("theme_title", "")),
		"mission_id": String(info.get("mission_id", "")),
		"mission_title": String(info.get("mission_title", "")),
		"mission_goal_key": String(info.get("mission_goal_key", "")),
		"role_summary_key": String(info.get("role_summary_key", "")),
		"difficulty": int(info.get("difficulty", 0)),
		"difficulty_key": String(info.get("difficulty_key", "")),
		"game_style": String(info.get("game_style", "")),
		"game_style_title": String(info.get("game_style_title", "")),
		"training_type": String(info.get("training_type", "")),
		"training_type_title": String(info.get("training_type_title", "")),
		"chaser_enabled": bool(info.get("chaser_enabled", false)),
		"max_players": int(info.get("max_players", 0)),
		"player_count": int(info.get("player_count", 0)),
		"character_id": String(info.get("character_id", "")),
		"taken_characters": taken_characters,
	}
	return JSON.stringify(normalized)

@rpc("authority", "call_remote", "reliable")
func rpc_update_remote_goal(goal_text: String) -> void:
	if not multiplayer.is_server():
		remote_goal_updated.emit(goal_text)
