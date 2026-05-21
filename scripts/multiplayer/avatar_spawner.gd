# scripts/multiplayer/avatar_spawner.gd
# ─────────────────────────────────────────────────────────────────────────────
# AvatarSpawner
# Spawns and configures multiplayer player/AI avatar nodes.
# ─────────────────────────────────────────────────────────────────────────────
class_name AvatarSpawner
extends RefCounted

static func spawn_avatars(mgr: Node, session: Dictionary) -> void:
	for child in mgr.players_root.get_children():
		child.queue_free()
	mgr._avatars.clear()
	mgr._held_directions.clear()
	mgr._move_cooldowns.clear()
	mgr._previous_cells_by_peer.clear()

	var players := session.get("players", {}) as Dictionary
	var roles := session.get("roles", {}) as Dictionary
	var spawn_slots := session.get("spawn_slots", {}) as Dictionary
	var corners := [
		Vector2i(0, 0),
		Vector2i(mgr._maze.grid_size.x - 1, 0),
		Vector2i(0, mgr._maze.grid_size.y - 1),
		Vector2i(mgr._maze.grid_size.x - 1, mgr._maze.grid_size.y - 1),
	]

	var peer_ids: Array[int] = []
	for raw_key in players.keys():
		peer_ids.append(int(raw_key))
	peer_ids.sort()
	for peer_id in peer_ids:
		var info := players.get(peer_id, players.get(str(peer_id), {})) as Dictionary
		var slot := clampi(int(spawn_slots.get(peer_id, spawn_slots.get(str(peer_id), 0))), 0, 3)
		var role := String(roles.get(peer_id, roles.get(str(peer_id), info.get("role", NetworkManager.ROLE_COLLECTOR))))
		if mgr._is_roleless_next_symbol_mode():
			role = ""
		if mgr._is_maze_race_mode():
			role = NetworkManager.ROLE_RACER
		if mgr._is_race_mode():
			role = NetworkManager.ROLE_RACER
		var spawn_grid := mgr._spawn_for_mode(role, slot, corners) as Vector2i
		var avatar := mgr.avatar_scene.instantiate() as MultiplayerAvatar
		avatar.setup(peer_id, String(info.get("character_id", "")), mgr.maze_renderer, spawn_grid, role)
		if mgr._should_delay_path_chaser(role):
			avatar.visible = false
			mgr._delayed_chaser_peer_ids.append(peer_id)
			var initial_moves := int(mgr._path_chaser_trigger_moves())
			if peer_id == NetworkManager.HOST_PEER_ID:
				if mgr.hud != null:
					mgr.hud.set_mission_description(mgr.tr("mp_chaser_waiting_steps") % initial_moves, false)
			else:
				if mgr.multiplayer != null and mgr.multiplayer.multiplayer_peer != null and mgr.multiplayer.get_peers().has(peer_id):
					NetworkManager.rpc_id(peer_id, "rpc_chaser_countdown", initial_moves)
		mgr.players_root.add_child(avatar)
		mgr._avatars[peer_id] = avatar
		mgr._move_cooldowns[peer_id] = 0.0
		if mgr._is_race_mode():
			mgr._race_progress[peer_id] = 0
			mgr._race_colors_by_peer[peer_id] = mgr._distinct_race_color(peer_id, String(info.get("character_id", "")))
			mgr._race_sequences_by_peer[peer_id] = mgr._race_sequence_for_start(spawn_grid)
