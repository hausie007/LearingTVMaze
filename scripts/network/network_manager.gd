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
signal trap_use_received(peer_id: int)
signal debug_status_changed(scope: String, message: String)
signal chaser_countdown_updated(remaining: int)
signal chaser_released()
signal remote_goal_updated(goal_text: String, role_tag: String)
signal remote_result_updated(title_text: String, character_ids: Array[String])
signal remote_trap_status_updated(trap_available: bool, confusion_moves: int)
signal nearby_players_updated(count: int)
signal connecting_players_updated(count: int)

const APP_ID := "learning_maze"
const PRESENCE_APP_ID := "learning_maze_presence"
const PROTOCOL_VERSION := 1
const HOST_PEER_ID := 1

const GAME_PORT := 42020
const DISCOVERY_PORT := 42021
const DISCOVERY_BROADCAST_IP := "255.255.255.255"
const DISCOVERY_INTERVAL_SEC := 0.75
const HOST_BURST_INTERVAL_SEC := 0.20
const HOST_BURST_PACKETS := 24
const HOST_TTL_SEC := 20.0
const HOST_BIND_IP := "0.0.0.0"
const CLIENT_PRESENCE_INTERVAL_SEC := 1.25
const CLIENT_PRESENCE_BURST_INTERVAL_SEC := 0.25
const CLIENT_PRESENCE_BURST_PACKETS := 12
const CLIENT_PRESENCE_TTL_SEC := 9.0
const HOST_VIEWER_TTL_SEC := 5.0
const DISCOVERY_TARGET_CACHE_SEC := 5.0
const MAX_DISCOVERY_TARGETS := 4

# Domain constants — aliases to MissionCatalog (single source of truth).
const STYLE_PATH = MissionCatalog.STYLE_PATH
const STYLE_NEXT_SYMBOL = MissionCatalog.STYLE_NEXT_SYMBOL
const STYLE_RACE = MissionCatalog.STYLE_RACE

const TRAINING_NONE = MissionCatalog.TRAINING_NONE
const TRAINING_NUMBERS = MissionCatalog.TRAINING_NUMBERS
const TRAINING_LETTERS = MissionCatalog.TRAINING_LETTERS
const TRAINING_WORDS = MissionCatalog.TRAINING_WORDS

const MISSION_FIND_EXIT = MissionCatalog.MISSION_FIND_EXIT
const MISSION_FOLLOW_TRAIL = MissionCatalog.MISSION_FOLLOW_TRAIL
const MISSION_FIND_NEXT = MissionCatalog.MISSION_FIND_NEXT
const MISSION_RACE_MIDDLE = MissionCatalog.MISSION_RACE_MIDDLE

const ROLE_COLLECTOR = MissionCatalog.ROLE_COLLECTOR
const ROLE_CHASER = MissionCatalog.ROLE_CHASER
const ROLE_RACER = MissionCatalog.ROLE_RACER

var host_config: Dictionary = {}
var players: Dictionary = {}
var current_session: Dictionary = {}

var _peer: ENetMultiplayerPeer = null
var _broadcast_socket: PacketPeerUDP = null
var _listen_socket: PacketPeerUDP = null
var _broadcast_timer: Timer = null
var _broadcast_burst_timer: Timer = null
var _client_presence_socket: PacketPeerUDP = null
var _client_presence_timer: Timer = null
var _client_presence_burst_timer: Timer = null

var _pending_join_character_id: String = ""
var _pending_host_ip: String = ""
var _pending_host_port: int = GAME_PORT
var _pending_host_info: Dictionary = {}
var _client_presence_target_host: Dictionary = {}

var _discovered_hosts: Dictionary = {}
var _nearby_clients: Dictionary = {}
var _host_viewers: Dictionary = {}
var _session_id: String = ""  # Unique ID generated per hosting session.
var _client_presence_id: String = ""
var _host_burst_packets_remaining: int = 0
var _client_presence_burst_packets_remaining: int = 0
var _discovery_active: bool = false
var _discovery_targets_cache := PackedStringArray()
var _discovery_targets_cache_time_sec := -9999.0

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

	_broadcast_burst_timer = Timer.new()
	_broadcast_burst_timer.wait_time = HOST_BURST_INTERVAL_SEC
	_broadcast_burst_timer.one_shot = false
	_broadcast_burst_timer.timeout.connect(_broadcast_burst_presence)
	add_child(_broadcast_burst_timer)

	_client_presence_timer = Timer.new()
	_client_presence_timer.wait_time = CLIENT_PRESENCE_INTERVAL_SEC
	_client_presence_timer.one_shot = false
	_client_presence_timer.timeout.connect(_broadcast_client_presence)
	add_child(_client_presence_timer)

	_client_presence_burst_timer = Timer.new()
	_client_presence_burst_timer.wait_time = CLIENT_PRESENCE_BURST_INTERVAL_SEC
	_client_presence_burst_timer.one_shot = false
	_client_presence_burst_timer.timeout.connect(_broadcast_client_presence_burst)
	add_child(_client_presence_burst_timer)

	set_process(true)

func _process(_delta: float) -> void:
	_poll_discovery_socket()
	_prune_stale_hosts()
	_prune_stale_nearby_clients()
	_prune_stale_host_viewers()

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
	_session_id = "%d_%d" % [randi(), Time.get_ticks_msec()]
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

func update_current_session_config(config: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	host_config = config.duplicate(true)
	_normalize_host_config()
	_recalculate_roles()
	if current_session.is_empty():
		return
	current_session["config"] = host_config.duplicate(true)
	current_session["players"] = players.duplicate(true)
	current_session["roles"] = _roles_by_peer()

func start_discovery() -> int:
	stop_discovery()
	_discovered_hosts.clear()
	_emit_discovery_updated()

	_discovery_active = true
	var err := _ensure_listen_socket()
	if err != OK:
		_discovery_active = false
		_emit_debug("join", "Discovery bind failed (%d)" % err)
		return err
	_emit_debug("join", "Scanning on UDP %d" % DISCOVERY_PORT)

	return OK

func stop_discovery() -> void:
	_discovery_active = false
	_release_listen_socket_if_unused()

	if not _discovered_hosts.is_empty():
		_discovered_hosts.clear()
		_emit_discovery_updated()

func join_host(host_ip: String, host_port: int, character_id: String) -> int:
	stop_client_presence()
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
	stop_client_presence()
	_stop_broadcasting()
	stop_discovery()

	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_peer = null
	host_config.clear()
	players.clear()
	current_session.clear()
	_session_id = ""
	_pending_join_character_id = ""
	_pending_host_ip = ""
	_pending_host_port = GAME_PORT
	_pending_host_info.clear()
	_client_presence_target_host.clear()
	if not _host_viewers.is_empty():
		_host_viewers.clear()
		_emit_connecting_players_updated()
	_emit_debug("net", "Session cleared")

func start_client_presence(target_host: Dictionary = {}) -> int:
	if _client_presence_socket != null:
		set_client_presence_target_host(target_host)
		return OK
	set_client_presence_target_host(target_host)

	_ensure_client_presence_id()
	var err := _ensure_listen_socket()
	if err != OK:
		return err

	_client_presence_socket = PacketPeerUDP.new()
	_client_presence_socket.set_broadcast_enabled(true)
	_client_presence_timer.start()
	_client_presence_burst_packets_remaining = CLIENT_PRESENCE_BURST_PACKETS
	_client_presence_burst_timer.start()
	_broadcast_client_presence()
	return OK

func set_client_presence_target_host(host_info: Dictionary) -> void:
	var old_target_session_id := _client_presence_target_session_id()
	var old_target_ip := String(_client_presence_target_host.get("ip", ""))
	var new_target := host_info.duplicate(true)
	var new_target_session_id := String(new_target.get("session_id", ""))
	var new_target_ip := String(new_target.get("ip", ""))
	var target_changed := old_target_session_id != new_target_session_id or old_target_ip != new_target_ip

	if _client_presence_socket != null and not old_target_session_id.is_empty() and target_changed:
		_broadcast_client_presence(false)

	_client_presence_target_host = new_target
	if _client_presence_socket != null and target_changed:
		_restart_client_presence_burst()
		_broadcast_client_presence()

func clear_client_presence_target_host() -> void:
	set_client_presence_target_host({})

func stop_client_presence() -> void:
	if _client_presence_timer != null:
		_client_presence_timer.stop()
	if _client_presence_burst_timer != null:
		_client_presence_burst_timer.stop()
	_client_presence_burst_packets_remaining = 0

	if _client_presence_socket != null:
		_broadcast_client_presence(false)
		_client_presence_socket.close()
		_client_presence_socket = null

	_client_presence_target_host.clear()
	_release_listen_socket_if_unused()

func get_nearby_player_count() -> int:
	return _nearby_clients.size()

func get_connecting_player_count() -> int:
	return _host_viewers.size()

func _ensure_listen_socket() -> int:
	if _listen_socket != null:
		return OK

	_listen_socket = PacketPeerUDP.new()
	var err := _listen_socket.bind(DISCOVERY_PORT, "0.0.0.0")
	if err != OK:
		_listen_socket = null
	return err

func _release_listen_socket_if_unused() -> void:
	if _discovery_active or _broadcast_socket != null or _client_presence_socket != null:
		return
	if _listen_socket != null:
		_listen_socket.close()
		_listen_socket = null
	if not _nearby_clients.is_empty():
		_nearby_clients.clear()
		_emit_nearby_players_updated()
	if not _host_viewers.is_empty():
		_host_viewers.clear()
		_emit_connecting_players_updated()

func _ensure_client_presence_id() -> void:
	if _client_presence_id.is_empty():
		_client_presence_id = "%d_%d" % [randi(), Time.get_ticks_msec()]

func _client_presence_target_session_id() -> String:
	return String(_client_presence_target_host.get("session_id", ""))

func _restart_client_presence_burst() -> void:
	if _client_presence_burst_timer == null:
		return
	_client_presence_burst_packets_remaining = CLIENT_PRESENCE_BURST_PACKETS
	_client_presence_burst_timer.start()

func send_dpad(direction: Vector2i, pressed: bool) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if not _is_valid_direction(direction):
		return

	if multiplayer.is_server():
		input_received.emit(multiplayer.get_unique_id(), direction, pressed)
		return

	rpc_id(HOST_PEER_ID, "rpc_dpad_input", direction, pressed)

func send_use_trap() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		trap_use_received.emit(multiplayer.get_unique_id())
		return
	rpc_id(HOST_PEER_ID, "rpc_use_trap")

func get_discovered_hosts() -> Array:
	var hosts: Array = []
	for value in _discovered_hosts.values():
		hosts.append((value as Dictionary).get("info", {}))
	return hosts

## Pause broadcasting — lobby calls this when all player slots are full.
## Phones will stop seeing this host in their discovery list.
func pause_broadcasting() -> void:
	_stop_broadcasting()

## Resume broadcasting — lobby calls this when a slot opens up.
func resume_broadcasting() -> void:
	if multiplayer.is_server() and _broadcast_socket == null and current_session.is_empty():
		_start_broadcasting()

## Check whether the host is currently broadcasting discovery.
func is_broadcasting() -> bool:
	return _broadcast_socket != null

func _start_broadcasting() -> void:
	if _broadcast_socket != null:
		return

	var err := _ensure_listen_socket()
	if err != OK:
		push_warning("Multiplayer presence listen failed: %d" % err)

	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)
	_broadcast_timer.start()
	_host_burst_packets_remaining = HOST_BURST_PACKETS
	_broadcast_burst_timer.start()
	_broadcast_presence()
	_emit_debug("host", "Broadcasting discovery on UDP %d" % DISCOVERY_PORT)

func _stop_broadcasting() -> void:
	_broadcast_timer.stop()
	_broadcast_burst_timer.stop()
	_host_burst_packets_remaining = 0
	if _broadcast_socket != null:
		_broadcast_socket.close()
		_broadcast_socket = null
		_emit_debug("host", "Broadcast stopped")
	_release_listen_socket_if_unused()

func _broadcast_presence() -> void:
	if not multiplayer.is_server():
		return
	if _broadcast_socket == null:
		return

	var payload := _build_discovery_payload()
	var packet := JSON.stringify(payload).to_utf8_buffer()
	_send_discovery_packet(_broadcast_socket, packet)

func _broadcast_burst_presence() -> void:
	if _host_burst_packets_remaining <= 0:
		_broadcast_burst_timer.stop()
		return

	_host_burst_packets_remaining -= 1
	_broadcast_presence()
	if _host_burst_packets_remaining <= 0:
		_broadcast_burst_timer.stop()

func _build_discovery_payload() -> Dictionary:
	var max_players: int = clampi(int(host_config.get("max_players", 2)), 2, 4)
	return {
		"app": APP_ID,
		"version": PROTOCOL_VERSION,
		"type": "host",
		"session_id": _session_id,
		"host_name": tr("app_title") + " (" + tr("mp_slot_host") + ")",
		"port": GAME_PORT,
		"theme_dir": String(host_config.get("theme_dir", "default")),
		"theme_title": String(host_config.get("theme_title", host_config.get("theme_dir", "default"))),
		"mission_id": String(host_config.get("mission_id", MISSION_FOLLOW_TRAIL)),
		"mission_title": String(host_config.get("mission_title", tr("mission_follow_trail"))),
		"mission_goal_key": String(host_config.get("mission_goal_key", "")),
		"role_summary_key": String(host_config.get("role_summary_key", MissionCatalog.role_summary_key(
			String(host_config.get("mission_id", MISSION_FOLLOW_TRAIL)),
			bool(host_config.get("chaser_enabled", false))
		))),
		"game_style": String(host_config.get("game_style", STYLE_PATH)),
		"game_style_title": String(host_config.get("game_style_title", tr("style_path"))),
		"training_type": String(host_config.get("training_type", TRAINING_WORDS)),
		"training_type_title": String(host_config.get("training_type_title", tr("training_words"))),
		"chaser_enabled": bool(host_config.get("chaser_enabled", false)),
		"traps_enabled": bool(host_config.get("traps_enabled", false)),
		"difficulty": int(host_config.get("difficulty", 1)),
		"difficulty_key": String(host_config.get("difficulty_key", "diff_easy")),
		"max_players": max_players,
		"player_count": players.size(),
		"character_id": String(host_config.get("character_id", "")),
		"taken_characters": _taken_characters(),
	}

func _broadcast_client_presence(joinable: bool = true) -> void:
	if _client_presence_socket == null:
		return
	_ensure_client_presence_id()

	var target_session_id := _client_presence_target_session_id()
	var payload := {
		"app": PRESENCE_APP_ID,
		"version": PROTOCOL_VERSION,
		"type": "client_presence",
		"presence_id": _client_presence_id,
		"joinable": joinable,
		"state": "viewing_host" if not target_session_id.is_empty() else "available",
	}
	if not target_session_id.is_empty():
		payload["target_session_id"] = target_session_id
	var packet := JSON.stringify(payload).to_utf8_buffer()
	var direct_targets := _client_presence_direct_targets()
	var include_broadcast := target_session_id.is_empty() or direct_targets.is_empty()
	_send_discovery_packet(_client_presence_socket, packet, direct_targets, include_broadcast)

func _broadcast_client_presence_burst() -> void:
	if _client_presence_burst_packets_remaining <= 0:
		_client_presence_burst_timer.stop()
		return

	_client_presence_burst_packets_remaining -= 1
	_broadcast_client_presence()
	if _client_presence_burst_packets_remaining <= 0:
		_client_presence_burst_timer.stop()

func _client_presence_direct_targets() -> PackedStringArray:
	var targets := PackedStringArray()
	var host_ip := String(_client_presence_target_host.get("ip", ""))
	if not host_ip.is_empty():
		targets.append(host_ip)
	return targets

func _send_discovery_packet(socket: PacketPeerUDP, packet: PackedByteArray, extra_targets: PackedStringArray = PackedStringArray(), include_broadcast: bool = true) -> void:
	if socket == null:
		return
	var targets := PackedStringArray()
	if include_broadcast:
		for target_ip in _discovery_target_ips():
			if not targets.has(target_ip):
				targets.append(target_ip)
	for target_ip in extra_targets:
		if not target_ip.is_empty() and not targets.has(target_ip):
			targets.append(target_ip)
	for target_ip in targets:
		socket.set_dest_address(target_ip, DISCOVERY_PORT)
		socket.put_packet(packet)

func _discovery_target_ips() -> PackedStringArray:
	var now_sec := _now_sec()
	if now_sec - _discovery_targets_cache_time_sec <= DISCOVERY_TARGET_CACHE_SEC and not _discovery_targets_cache.is_empty():
		return _discovery_targets_cache

	var targets := PackedStringArray([DISCOVERY_BROADCAST_IP])
	for address in IP.get_local_addresses():
		var directed_broadcast := _directed_broadcast_for_ipv4(address)
		if directed_broadcast.is_empty() or targets.has(directed_broadcast):
			continue
		targets.append(directed_broadcast)
		if targets.size() >= MAX_DISCOVERY_TARGETS:
			break
	_discovery_targets_cache = targets
	_discovery_targets_cache_time_sec = now_sec
	return targets

func _directed_broadcast_for_ipv4(address: String) -> String:
	var parts := address.split(".")
	if parts.size() != 4:
		return ""
	var octets: Array[int] = []
	for part in parts:
		if not part.is_valid_int():
			return ""
		var value := int(part)
		if value < 0 or value > 255:
			return ""
		octets.append(value)
	if not _is_private_ipv4(octets):
		return ""
	return "%d.%d.%d.255" % [octets[0], octets[1], octets[2]]

func _is_private_ipv4(octets: Array[int]) -> bool:
	if octets[0] == 10:
		return true
	if octets[0] == 172 and octets[1] >= 16 and octets[1] <= 31:
		return true
	if octets[0] == 192 and octets[1] == 168:
		return true
	return false

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
		var app_marker := String(info.get("app", ""))
		if app_marker != APP_ID and app_marker != PRESENCE_APP_ID:
			continue
		if int(info.get("version", -1)) != PROTOCOL_VERSION:
			continue

		var packet_type := String(info.get("type", "host"))
		if app_marker == PRESENCE_APP_ID:
			if packet_type != "client_presence":
				continue
			_handle_client_presence_packet(info)
			continue
		if packet_type == "client_presence":
			continue
		if packet_type != "host":
			continue
		if not _discovery_active:
			continue
		if multiplayer.is_server() and String(info.get("session_id", "")) == _session_id:
			continue

		var ip := _listen_socket.get_packet_ip()
		var port := int(info.get("port", GAME_PORT))
		info["ip"] = ip
		info["port"] = port

		# Use session_id as the deduplication key when available (handles
		# same-config games on different devices and same-device re-hosts).
		var sid := String(info.get("session_id", ""))
		var key := sid if not sid.is_empty() else "%s:%d" % [ip, port]
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

func _handle_client_presence_packet(info: Dictionary) -> bool:
	var presence_id := String(info.get("presence_id", ""))
	if presence_id.is_empty() or presence_id == _client_presence_id:
		return false

	var now_sec := _now_sec()
	var changed := false
	var was_known := _nearby_clients.has(presence_id)
	if not bool(info.get("joinable", true)):
		if was_known:
			_nearby_clients.erase(presence_id)
			_emit_nearby_players_updated()
			changed = true
	else:
		_nearby_clients[presence_id] = {
			"last_seen": now_sec,
		}
		if not was_known:
			_emit_nearby_players_updated()
			changed = true

	if _update_host_viewer_presence(presence_id, info, now_sec):
		changed = true
	return changed

func _update_host_viewer_presence(presence_id: String, info: Dictionary, now_sec: float) -> bool:
	var was_known := _host_viewers.has(presence_id)
	var target_session_id := String(info.get("target_session_id", ""))
	var viewing_this_host := (
		multiplayer.is_server()
		and not _session_id.is_empty()
		and bool(info.get("joinable", true))
		and target_session_id == _session_id
	)

	if viewing_this_host:
		_host_viewers[presence_id] = {
			"last_seen": now_sec,
		}
		if not was_known:
			_emit_connecting_players_updated()
			return true
		return false

	if was_known:
		_host_viewers.erase(presence_id)
		_emit_connecting_players_updated()
		return true
	return false

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

func _prune_stale_nearby_clients() -> void:
	if _nearby_clients.is_empty():
		return

	var now_sec := _now_sec()
	var changed := false
	for key in _nearby_clients.keys():
		var item := _nearby_clients[key] as Dictionary
		var last_seen: float = float(item.get("last_seen", 0.0))
		if now_sec - last_seen > CLIENT_PRESENCE_TTL_SEC:
			_nearby_clients.erase(key)
			changed = true

	if changed:
		_emit_nearby_players_updated()

func _prune_stale_host_viewers() -> void:
	if _host_viewers.is_empty():
		return

	var now_sec := _now_sec()
	var changed := false
	for key in _host_viewers.keys():
		var item := _host_viewers[key] as Dictionary
		var last_seen: float = float(item.get("last_seen", 0.0))
		if now_sec - last_seen > HOST_VIEWER_TTL_SEC:
			_host_viewers.erase(key)
			changed = true

	if changed:
		_emit_connecting_players_updated()

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

func _emit_nearby_players_updated() -> void:
	nearby_players_updated.emit(_nearby_clients.size())

func _emit_connecting_players_updated() -> void:
	connecting_players_updated.emit(_host_viewers.size())

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
		host_config["game_style_title"] = tr("style_path")
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
	var traps_requested := bool(host_config.get("traps_enabled", false))
	host_config["traps_enabled"] = traps_requested and Config.traps_allowed_for_session(
		String(host_config.get("game_style", STYLE_PATH)),
		bool(host_config.get("chaser_enabled", false)),
		mission_id
	)
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

func kick_player(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id == multiplayer.get_unique_id():
		return
	if players.has(peer_id):
		var info = players[peer_id] as Dictionary
		if info.get("is_ai", false):
			players.erase(peer_id)
			_sync_lobby_to_clients()
			lobby_updated.emit(_build_lobby_state())
			return
			
		rpc_id(peer_id, "rpc_kicked_by_host")
		var enet_peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if enet_peer != null:
			enet_peer.disconnect_peer(peer_id, true)
		
		# Immediately clean up locally since peer_disconnected might not fire for server-initiated disconnects
		players.erase(peer_id)
		_sync_lobby_to_clients()

@rpc("authority", "call_remote", "reliable")
func rpc_kicked_by_host() -> void:
	join_rejected.emit("mp_kicked_by_host")
	leave_session()

func _on_connected_to_server() -> void:
	if _pending_join_character_id.is_empty():
		join_rejected.emit("mp_join_error_character")
		leave_session()
		return

	_emit_debug("join", "Connected, requesting join")
	rpc_id(HOST_PEER_ID, "rpc_request_join", _pending_join_character_id)

func _on_connection_failed() -> void:
	join_rejected.emit("mp_join_host_unavailable")
	_emit_debug("join", "Connection failed")
	leave_session()

func _on_server_disconnected() -> void:
	join_rejected.emit("mp_join_host_unavailable")
	_emit_debug("join", "Server disconnected")
	leave_session()

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_join(character_id: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not current_session.is_empty():
		rpc_id(sender_id, "rpc_join_rejected", "mp_join_game_started")
		return

	if character_id.is_empty():
		rpc_id(sender_id, "rpc_join_rejected", "mp_join_error_character")
		return

	var max_players: int = clampi(int(host_config.get("max_players", 2)), 2, 4)
	if players.size() >= max_players:
		rpc_id(sender_id, "rpc_join_rejected", "mp_join_lobby_full")
		return

	if _is_character_taken(character_id):
		rpc_id(sender_id, "rpc_join_rejected", "mp_join_error_character_taken")
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

func emulate_remote_player_join(character_id: String) -> void:
	if not multiplayer.is_server():
		return
	
	var max_players: int = clampi(int(host_config.get("max_players", 2)), 2, 4)
	if players.size() >= max_players:
		return
		
	var fake_peer_id = randi_range(1000, 9999)
	while players.has(fake_peer_id) or fake_peer_id == HOST_PEER_ID:
		fake_peer_id = randi_range(1000, 9999)
		
	players[fake_peer_id] = {
		"peer_id": fake_peer_id,
		"character_id": character_id,
		"is_host": false,
		"role": ROLE_COLLECTOR,
		"is_ai": true
	}
	_recalculate_roles()
	_sync_lobby_to_clients()
	lobby_updated.emit(_build_lobby_state())
	_emit_debug("host", "Emulated peer %d joined" % fake_peer_id)

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

@rpc("any_peer", "call_remote", "reliable")
func rpc_use_trap() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not players.has(sender_id):
		return
	trap_use_received.emit(sender_id)

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
		"traps_enabled": bool(info.get("traps_enabled", false)),
		"max_players": int(info.get("max_players", 0)),
		"player_count": int(info.get("player_count", 0)),
		"character_id": String(info.get("character_id", "")),
		"taken_characters": taken_characters,
	}
	return JSON.stringify(normalized)

@rpc("authority", "call_remote", "reliable")
func rpc_update_remote_goal(goal_text: String, role_tag: String = "") -> void:
	if not multiplayer.is_server():
		remote_goal_updated.emit(goal_text, role_tag)

@rpc("authority", "call_remote", "reliable")
func rpc_update_remote_result(title_text: String, character_ids: Array[String]) -> void:
	if not multiplayer.is_server():
		remote_result_updated.emit(title_text, character_ids)

@rpc("authority", "call_remote", "reliable")
func rpc_update_remote_trap_status(trap_available: bool, confusion_moves: int) -> void:
	if not multiplayer.is_server():
		remote_trap_status_updated.emit(trap_available, confusion_moves)
